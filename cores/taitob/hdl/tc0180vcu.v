// TC0180VCU — Taito B System combined tilemap + sprite video chip
// Target: Tetris (1988) — simplest TC0180VCU usage
//
// Architecture:
//   - VRAM, sprite RAM, scroll RAM are in JTFRAME-managed external BRAMs
//     (defined in mem.yaml), accessed via address/data ports
//   - Three tilemap layers rendered scanline-by-scanline:
//       BG (16x16 tiles, 64x64 map), FG (16x16, 64x64), TX (8x8, 64x32)
//   - Sprite engine scans sprite RAM during HBLANK, draws to internal
//     double-buffered line buffer
//   - Priority compositing: BG -> FG -> sprites -> TX (back to front)
//   - GFX tile ROMs accessed via SDRAM ports (rom_cs/rom_ok handshake)
//
// Tetris simplifications:
//   - No per-block scrolling (ctrl[2]=ctrl[3]=0, single global scroll)
//   - No sprite zoom, no big sprites
//   - Simple priority mode (ctrl[7] bit3=1)
//   - Framebuffer not implemented (CPU writes accepted, reads return 0)
//
// JTFRAME SDRAM protocol:
//   - Hold addr stable while cs is high; wait for ok
//   - Toggle cs low then high to issue a new request
//   - romrq_bcache caches data; ok fires when cached or fresh data ready
//
// MAME reference: src/mame/taito/tc0180vcu.cpp
// JTFRAME patterns: jtgaiden_scroll.v, jtgaiden_obj.v, jtframe_tilemap.v

`default_nettype none

module tc0180vcu(
    input             rst,
    input             clk,
    input             pxl_cen,    // pixel clock enable (~6.7MHz)
    // CPU interface (directly connected, address decode done in main)
    input      [18:1] cpu_addr,   // word address within VCU space
    input      [15:0] cpu_din,
    output reg [15:0] cpu_dout,
    input             cpu_cs,
    input             cpu_we,
    input      [ 1:0] cpu_dsn,
    // Screen timing (directly from JTFRAME vtimer)
    input             LHBL,
    input             LVBL,
    input      [ 8:0] hdump,
    input      [ 8:0] vdump,
    // VRAM BRAM port (video-side read, 32K x 16)
    output reg [14:0] vram_addr,
    input      [15:0] vram_dout,
    // Sprite RAM BRAM port (video-side read, 4K x 16)
    output reg [11:0] spram_addr,
    input      [15:0] spram_dout,
    // Scroll RAM BRAM port (video-side read, 1K x 16)
    output reg [ 9:0] scram_addr,
    input      [15:0] scram_dout,
    // GFX ROM interface — BG/FG tiles (SDRAM bank 2)
    output reg [19:0] gfx_addr,
    input      [31:0] gfx_data,
    input             gfx_ok,
    output reg        gfx_cs,
    // Text tile ROM interface (SDRAM bank 2)
    output reg [16:0] txt_addr,
    input      [31:0] txt_data,
    input             txt_ok,
    output reg        txt_cs,
    // Sprite GFX ROM interface (SDRAM bank 3)
    output reg [19:0] obj_addr,
    input      [31:0] obj_data,
    input             obj_ok,
    output reg        obj_cs,
    // Interrupts
    output reg        inth,       // IRQ4 — vblank
    output reg        intl,       // IRQ2 — delayed vblank
    // Pixel output to colmix
    output reg [11:0] col_addr,   // palette address (12-bit)
    output reg        col_valid   // non-transparent pixel
);

// =====================================================================
// Control registers — 16 x 8-bit (only upper byte of each word)
// MAME: ctrl regs at byte 0x418000 = VCU word offset 0x0C000
// cpu_addr[18:16]==001, cpu_addr[15:14]==10
// =====================================================================
reg [7:0] ctrl [0:15];

// CPU write to control registers
wire ctrl_sel = cpu_cs & cpu_we &
                (cpu_addr[18:16] == 3'b001) &
                (cpu_addr[15:14] == 2'b10);

always @(posedge clk) begin
    if (rst) begin : ctrl_rst
        integer i;
        for (i = 0; i < 16; i = i + 1) ctrl[i] <= 8'd0;
    end else if (ctrl_sel && !cpu_dsn[1]) begin
        ctrl[cpu_addr[4:1]] <= cpu_din[15:8];
        `ifdef SIMULATION
        $display("VCU_CTRL: reg[%0d] <= 0x%02X  addr=%05X cs=%b we=%b dsn=%b din=%04X",
                 cpu_addr[4:1], cpu_din[15:8], cpu_addr, cpu_cs, cpu_we, cpu_dsn, cpu_din);
        `endif
    end
end

// CPU read — control regs return upper byte, lower byte = 0
// Framebuffer at cpu_addr[18]=1 returns actual pixel pair
wire ctrl_rd_sel = cpu_cs & !cpu_we &
                   (cpu_addr[18:16] == 3'b001) &
                   (cpu_addr[15:14] == 2'b10);
wire fb_rd_sel   = cpu_cs & !cpu_we & cpu_addr[18];

// FB read address wires (fb_mem declared below with storage)
// Address: {page(1), Y[7:0](8 bits = cpu_addr[16:9]), X_pair[7:0](8 bits = cpu_addr[8:1])}
// cpu_addr[17] is the page select bit within the FB (VCU word addr bit 17 = 2^17 = page boundary).
wire [17:0] fb_rd_addr_hi = {cpu_addr[17], cpu_addr[16:9], cpu_addr[8:1], 1'b0};
wire [17:0] fb_rd_addr_lo = {cpu_addr[17], cpu_addr[16:9], cpu_addr[8:1], 1'b1};

always @(posedge clk) begin
    if (ctrl_rd_sel)
        cpu_dout <= { ctrl[cpu_addr[4:1]], 8'h00 };
    else if (fb_rd_sel)
        cpu_dout <= {fb_mem[fb_rd_addr_hi], fb_mem[fb_rd_addr_lo]};
    else
        cpu_dout <= 16'hFFFF; // open bus default
end

// Control register decode (per FBNeo: ctrl[0]=FG banks, ctrl[1]=BG banks)
// MAME: bank = (ctrl[N]>>8 & 0x0F) << 12, using 4-bit bank select (not 3!)
wire [3:0] fg_bank0 = ctrl[0][3:0]; // FG tile code VRAM bank (4 bits)
wire [3:0] fg_bank1 = ctrl[0][7:4]; // FG tile attribute VRAM bank
wire [3:0] bg_bank0 = ctrl[1][3:0]; // BG tile code VRAM bank
wire [3:0] bg_bank1 = ctrl[1][7:4]; // BG tile attribute VRAM bank
// ctrl[2]/[3]: scroll block height (Tetris=0 => 256 lines per block)
wire [5:0] tx_bank0_sel = ctrl[4][5:0]; // TX tile ROM bank 0
wire [5:0] tx_bank1_sel = ctrl[5][5:0]; // TX tile ROM bank 1
// MAME: tx_rambank = ((ctrl[6]>>8) & 0x0F) << 11  (4-bit, 2K pages)
wire [3:0] tx_page      = ctrl[6][3:0]; // TX VRAM page select (4 bits)
// ctrl[7]: bit0=fb_clear_inhibit, bit3=priority_mode, bit4=flip, bit7=page_lock
// ctrl[7] framebuffer page control bits
wire fb_manual   = ctrl[7][7]; // 1 = manual page select, 0 = auto-flip
wire fb_pagesel  = ctrl[7][6]; // manual page select value
wire fb_no_erase = ctrl[7][0]; // 1 = inhibit framebuffer clear on vblank

// =====================================================================
// Interrupt generation
// =====================================================================
reg        lvbl_prev;
reg  [3:0] intl_cnt;
reg        intl_armed;
reg        fb_page; // write page (CPU and sprites write here); display = ~fb_page

always @(posedge clk) begin
    if (rst) begin
        inth       <= 0;
        intl       <= 0;
        lvbl_prev  <= 1;
        intl_cnt   <= 0;
        intl_armed <= 0;
        fb_page    <= 0;
    end else begin
        lvbl_prev <= LVBL;
        // HOLD_LINE: assert INTH for entire VBLANK period
        // FX68K needs stable IPL for 2 CPU cycles to take interrupt
        // After handler entry, the handler sets mask=7 preventing re-entry
        inth <= ~LVBL;
        if (!LVBL && lvbl_prev) begin
            intl_cnt   <= 4'd8;
            intl_armed <= 1;
            // Flip or manually select framebuffer write page at vblank start
            if (!fb_manual)
                fb_page <= ~fb_page;
            else
                fb_page <= ~fb_pagesel; // inverted per MAME
        end
        if (intl_armed && pxl_cen && hdump == 9'd0) begin
            if (intl_cnt != 0)
                intl_cnt <= intl_cnt - 4'd1;
            else begin
                intl       <= 1;
                intl_armed <= 0;
            end
        end
        if (LVBL && !lvbl_prev)
            intl <= 0;
    end
end

// =====================================================================
// Scroll values — latched from scroll RAM at vblank
// =====================================================================
reg [9:0] bg_scrollx, bg_scrolly;
reg [9:0] fg_scrollx, fg_scrolly;

reg [2:0] sc_st;
always @(posedge clk) begin
    if (rst) begin
        sc_st <= 0;
        bg_scrollx <= 0; bg_scrolly <= 0;
        fg_scrollx <= 0; fg_scrolly <= 0;
    end else if (!LVBL && lvbl_prev) begin
        sc_st <= 3'd1;
    end else case (sc_st)
        3'd1: begin scram_addr <= 10'h000; sc_st <= 3'd2; end
        3'd2: begin scram_addr <= 10'h100; fg_scrollx <= scram_dout[9:0]; sc_st <= 3'd3; end
        3'd3: begin scram_addr <= 10'h200; fg_scrolly <= scram_dout[9:0]; sc_st <= 3'd4; end
        3'd4: begin scram_addr <= 10'h300; bg_scrollx <= scram_dout[9:0]; sc_st <= 3'd5; end
        3'd5: begin bg_scrolly <= scram_dout[9:0]; sc_st <= 3'd0; end
        default: sc_st <= 0;
    endcase
end

// =====================================================================
// Effective pixel coordinates with scroll
// =====================================================================
wire [9:0] bg_px = {1'b0, hdump} + bg_scrollx;
wire [9:0] bg_py = {1'b0, vdump} + bg_scrolly;
wire [9:0] fg_px = {1'b0, hdump} + fg_scrollx;
wire [9:0] fg_py = {1'b0, vdump} + fg_scrolly;

// =====================================================================
// VRAM prefetch pipeline
// =====================================================================
// For each tile layer, we need to read tile code + attributes from VRAM
// ONCE per tile boundary, then hold that data stable for the entire tile.
//
// BG/FG: 16x16 tiles => need code+attr every 16 pixels (actually every
//   8 pixels because each 16x16 tile is split into two 8-pixel halves).
//   But code+attr don't change between the two halves (same tile).
//   So we fetch code+attr when bg_px[3:0]==0 (start of tile).
//
// TX: 8x8 tiles => need code every 8 pixels when hdump[2:0]==0.
//
// Strategy: Use a multi-step VRAM read sequence triggered at tile
// boundaries. Between boundaries, VRAM port is idle.
//
// For simplicity with the 4-clock pixel period, we pipeline:
//   - BG code+attr reads happen near the BG tile boundary
//   - FG code+attr reads happen near the FG tile boundary
//   - TX code reads happen near the TX tile boundary
//
// Since BG/FG/TX tile boundaries may not align, we use a simple
// round-robin scheduler: each pxl_cen, check which layer needs
// data and issue the reads over the next 4 system clocks.

// Latched tile data — stable for the duration of the tile
reg [15:0] bg_code_lat, bg_attr_lat;
reg [15:0] fg_code_lat, fg_attr_lat;
reg [15:0] tx_code_lat;

// Flags: needs_fetch goes high at tile boundary, cleared after fetch
reg bg_needs_fetch, fg_needs_fetch, tx_needs_fetch;

// Previous pixel positions to detect tile boundary crossings
reg [3:0] bg_px_prev_lo;
reg [3:0] fg_px_prev_lo;
reg [2:0] hdump_prev_lo;

always @(posedge clk) begin
    if (rst) begin
        bg_px_prev_lo <= 0;
        fg_px_prev_lo <= 0;
        hdump_prev_lo <= 0;
        bg_needs_fetch <= 1; // fetch at start
        fg_needs_fetch <= 1;
        tx_needs_fetch <= 1;
    end else if (pxl_cen) begin
        bg_px_prev_lo <= bg_px[3:0];
        fg_px_prev_lo <= fg_px[3:0];
        hdump_prev_lo <= hdump[2:0];

        // Detect 16-pixel tile boundary for BG (when px[3:0] wraps to 0)
        if (bg_px[3:0] == 4'd0 && bg_px_prev_lo != 4'd0)
            bg_needs_fetch <= 1;
        // Also fetch at start of each scanline
        if (!LHBL && LVBL)
            bg_needs_fetch <= 1;

        // Same for FG
        if (fg_px[3:0] == 4'd0 && fg_px_prev_lo != 4'd0)
            fg_needs_fetch <= 1;
        if (!LHBL && LVBL)
            fg_needs_fetch <= 1;

        // TX: 8-pixel boundary
        if (hdump[2:0] == 3'd0 && hdump_prev_lo != 3'd0)
            tx_needs_fetch <= 1;
        if (!LHBL && LVBL)
            tx_needs_fetch <= 1;
    end
end

// VRAM read FSM — sequences through needed reads
// Each read takes 2 system clocks (addr on clk N, data valid on clk N+1)
localparam [3:0]
    VR_IDLE   = 0,
    VR_BG0_A  = 1,  // issue BG code addr
    VR_BG0_D  = 2,  // latch BG code data, issue BG attr addr
    VR_BG1_D  = 3,  // latch BG attr data
    VR_FG0_A  = 4,  // issue FG code addr
    VR_FG0_D  = 5,  // latch FG code data, issue FG attr addr
    VR_FG1_D  = 6,  // latch FG attr data
    VR_TX_A   = 7,  // issue TX addr
    VR_TX_D   = 8;  // latch TX data

reg [3:0] vr_st;
reg       vram_sprite_mode; // reserved for sprite engine

// VRAM addresses — 32K words (addr_width=16, AW=15)
// BG/FG: 4-bit bank (<<12) + 6-bit row + 6-bit col = 16 bits, take low 15 bits (VRAM range)
// Intermediate 16-bit wires; vram_addr port is [14:0] so assignments truncate the MSB
wire [15:0] bg_code_vaddr_w = {bg_bank0, bg_py[9:4], bg_px[9:4]};
wire [15:0] bg_attr_vaddr_w = {bg_bank1, bg_py[9:4], bg_px[9:4]};
wire [15:0] fg_code_vaddr_w = {fg_bank0, fg_py[9:4], fg_px[9:4]};
wire [15:0] fg_attr_vaddr_w = {fg_bank1, fg_py[9:4], fg_px[9:4]};
wire [14:0] bg_code_vaddr = bg_code_vaddr_w[14:0];
wire [14:0] bg_attr_vaddr = bg_attr_vaddr_w[14:0];
wire [14:0] fg_code_vaddr = fg_code_vaddr_w[14:0];
wire [14:0] fg_attr_vaddr = fg_attr_vaddr_w[14:0];
// TX: 64x32 tilemap, 2K entries per page. addr = page*2048 + row*64 + col
wire [14:0] tx_vaddr      = {tx_page, vdump[7:3], hdump[8:3]};

always @(posedge clk) begin
    if (rst) begin
        vr_st <= VR_IDLE;
    end else if (!vram_sprite_mode) begin
        case (vr_st)
            VR_IDLE: begin
                // Priority: BG > FG > TX
                if (bg_needs_fetch) begin
                    vram_addr <= bg_code_vaddr;
                    vr_st     <= VR_BG0_A;
                end else if (fg_needs_fetch) begin
                    vram_addr <= fg_code_vaddr;
                    vr_st     <= VR_FG0_A;
                end else if (tx_needs_fetch) begin
                    vram_addr <= tx_vaddr;
                    vr_st     <= VR_TX_A;
                end
            end
            VR_BG0_A: begin
                // addr was set, wait one clock for BRAM data
                vr_st <= VR_BG0_D;
            end
            VR_BG0_D: begin
                bg_code_lat <= vram_dout;
                `ifdef SIMULATION
                if (vram_dout != 0 && vdump < 9'd5)
                    $display("VCU_TILE: bg_code=%04X addr=%04X px=%0d py=%0d cyc=%0t",
                             vram_dout, bg_code_vaddr, bg_px, bg_py, $time);
                `endif
                vram_addr   <= bg_attr_vaddr;
                vr_st       <= VR_BG1_D;
            end
            VR_BG1_D: begin
                bg_attr_lat    <= vram_dout;
                bg_needs_fetch <= 0;
                // Chain to FG if needed
                if (fg_needs_fetch) begin
                    vram_addr <= fg_code_vaddr;
                    vr_st     <= VR_FG0_A;
                end else if (tx_needs_fetch) begin
                    vram_addr <= tx_vaddr;
                    vr_st     <= VR_TX_A;
                end else begin
                    vr_st <= VR_IDLE;
                end
            end
            VR_FG0_A: begin
                vr_st <= VR_FG0_D;
            end
            VR_FG0_D: begin
                fg_code_lat <= vram_dout;
                vram_addr   <= fg_attr_vaddr;
                vr_st       <= VR_FG1_D;
            end
            VR_FG1_D: begin
                fg_attr_lat    <= vram_dout;
                fg_needs_fetch <= 0;
                if (tx_needs_fetch) begin
                    vram_addr <= tx_vaddr;
                    vr_st     <= VR_TX_A;
                end else begin
                    vr_st <= VR_IDLE;
                end
            end
            VR_TX_A: begin
                vr_st <= VR_TX_D;
            end
            VR_TX_D: begin
                tx_code_lat    <= vram_dout;
                tx_needs_fetch <= 0;
                vr_st          <= VR_IDLE;
            end
            default: vr_st <= VR_IDLE;
        endcase
    end
end

// =====================================================================
// BG tile pixel pipeline
// =====================================================================
// JTFRAME SDRAM protocol: hold addr stable while cs is high.
// When data arrives (gfx_ok), latch it and drop cs.
// For a new request, toggle cs low for 1 cycle then high with new addr.

wire [14:0] bg_tile_code  = bg_code_lat[14:0];
wire [ 5:0] bg_tile_color = bg_attr_lat[5:0];
wire        bg_tile_flipx = bg_attr_lat[6];
wire        bg_tile_flipy = bg_attr_lat[7];

wire [3:0] bg_eff_suby = bg_py[3:0] ^ {4{bg_tile_flipy}};

// Shift register and palette cache — double-buffered (current + next)
reg [31:0] bg_shift, bg_shift_nxt;
reg [ 5:0] bg_pal,   bg_pal_nxt;
reg        bg_hf,    bg_hf_nxt;

// ROM request state
reg        bg_rom_pending;    // ROM data not yet received
reg [19:0] bg_rom_addr_lat;   // latched ROM address for the pending request
reg [ 5:0] bg_color_lat;      // latched color for when ROM data arrives
reg        bg_flipx_lat;      // latched flipx for when ROM data arrives

wire bg_8px_edge = (bg_px[2:0] == 3'd0);

always @(posedge clk) begin
    if (rst) begin
        bg_shift     <= 0; bg_shift_nxt <= 0;
        bg_pal       <= 0; bg_pal_nxt   <= 0;
        bg_hf        <= 0; bg_hf_nxt    <= 0;
        bg_rom_pending <= 0;
    end else if (pxl_cen) begin
        if (bg_8px_edge) begin
            // Swap: next -> current
            bg_shift <= bg_shift_nxt;
            bg_pal   <= bg_pal_nxt;
            bg_hf    <= bg_hf_nxt;
            // Request ROM data for the next 8 pixels
            // Tile code 0 = transparent sentinel (empty/blank tile); skip ROM fetch
            if (LHBL & LVBL && bg_tile_code != 15'd0) begin
                bg_rom_pending <= 1;
                bg_rom_addr_lat <= {bg_tile_code, bg_px[3] ^ bg_tile_flipx, bg_eff_suby};
                bg_color_lat    <= bg_tile_color;
                bg_flipx_lat    <= bg_tile_flipx;
            end else begin
                bg_shift_nxt <= 32'd0; // tile 0 = transparent; clear next shift reg
            end
        end else begin
            // Shift out pixel
            bg_shift <= bg_hf ? (bg_shift >> 1) : (bg_shift << 1);
        end
    end
end

// Latch ROM data when GFX port delivers it (see arbiter below)
reg bg_rom_served;
always @(posedge clk) begin
    if (rst) begin
        bg_rom_served <= 0;
    end else begin
        bg_rom_served <= 0;
        if (bg_rom_pending && gfx_ok && gfx_cs && !bg_rom_served) begin
            // Check that the port is serving our address
            if (gfx_addr == bg_rom_addr_lat) begin
                bg_shift_nxt  <= gfx_data;
                bg_pal_nxt    <= bg_color_lat;
                bg_hf_nxt     <= bg_flipx_lat;
                bg_rom_pending <= 0;
                bg_rom_served <= 1;
            end
        end
    end
end

// BG pixel extraction
wire [3:0] bg_pix = bg_hf ?
    { bg_shift[24], bg_shift[16], bg_shift[8], bg_shift[0] } :
    { bg_shift[31], bg_shift[23], bg_shift[15], bg_shift[7] };

// =====================================================================
// FG tile pixel pipeline — mirrors BG
// =====================================================================

wire [14:0] fg_tile_code  = fg_code_lat[14:0];
wire [ 5:0] fg_tile_color = fg_attr_lat[5:0];
wire        fg_tile_flipx = fg_attr_lat[6];
wire        fg_tile_flipy = fg_attr_lat[7];

wire [3:0] fg_eff_suby = fg_py[3:0] ^ {4{fg_tile_flipy}};

reg [31:0] fg_shift, fg_shift_nxt;
reg [ 5:0] fg_pal,   fg_pal_nxt;
reg        fg_hf,    fg_hf_nxt;

reg        fg_rom_pending;
reg [19:0] fg_rom_addr_lat;
reg [ 5:0] fg_color_lat;
reg        fg_flipx_lat;

wire fg_8px_edge = (fg_px[2:0] == 3'd0);

always @(posedge clk) begin
    if (rst) begin
        fg_shift     <= 0; fg_shift_nxt <= 0;
        fg_pal       <= 0; fg_pal_nxt   <= 0;
        fg_hf        <= 0; fg_hf_nxt    <= 0;
        fg_rom_pending <= 0;
    end else if (pxl_cen) begin
        if (fg_8px_edge) begin
            fg_shift <= fg_shift_nxt;
            fg_pal   <= fg_pal_nxt;
            fg_hf    <= fg_hf_nxt;
            // Tile code 0 = transparent sentinel (empty/blank tile); skip ROM fetch
            if (LHBL & LVBL && fg_tile_code != 15'd0) begin
                fg_rom_pending <= 1;
                fg_rom_addr_lat <= {fg_tile_code, fg_px[3] ^ fg_tile_flipx, fg_eff_suby};
                fg_color_lat    <= fg_tile_color;
                fg_flipx_lat    <= fg_tile_flipx;
            end else begin
                fg_shift_nxt <= 32'd0; // tile 0 = transparent; clear next shift reg
            end
        end else begin
            fg_shift <= fg_hf ? (fg_shift >> 1) : (fg_shift << 1);
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        /* nothing extra */
    end else begin
        if (fg_rom_pending && gfx_ok && gfx_cs && !bg_rom_served) begin
            if (gfx_addr == fg_rom_addr_lat) begin
                fg_shift_nxt   <= gfx_data;
                fg_pal_nxt     <= fg_color_lat;
                fg_hf_nxt      <= fg_flipx_lat;
                fg_rom_pending <= 0;
            end
        end
    end
end

wire [3:0] fg_pix = fg_hf ?
    { fg_shift[24], fg_shift[16], fg_shift[8], fg_shift[0] } :
    { fg_shift[31], fg_shift[23], fg_shift[15], fg_shift[7] };

// =====================================================================
// GFX ROM port — arbiter for BG and FG
// =====================================================================
// JTFRAME romrq protocol: hold addr+cs stable until ok fires.
// To issue a new request, toggle cs low for 1 clock then reassert.
//
// Arbiter states:
//   IDLE: cs=0, check for pending requests
//   BG_REQ: cs=1, addr=bg_rom_addr_lat, wait for gfx_ok
//   BG_GAP: cs=0 for 1 cycle after BG served (allow cache update)
//   FG_REQ: cs=1, addr=fg_rom_addr_lat, wait for gfx_ok
//   FG_GAP: cs=0 for 1 cycle after FG served

localparam [2:0]
    GA_IDLE   = 0,
    GA_BG_REQ = 1,
    GA_BG_GAP = 2,
    GA_FG_REQ = 3,
    GA_FG_GAP = 4;

reg [2:0] ga_st;

always @(posedge clk) begin
    if (rst) begin
        gfx_cs   <= 0;
        gfx_addr <= 0;
        ga_st    <= GA_IDLE;
    end else begin
        case (ga_st)
            GA_IDLE: begin
                gfx_cs <= 0;
                if (bg_rom_pending) begin
                    gfx_addr <= bg_rom_addr_lat;
                    gfx_cs   <= 1;
                    ga_st    <= GA_BG_REQ;
                end else if (fg_rom_pending) begin
                    gfx_addr <= fg_rom_addr_lat;
                    gfx_cs   <= 1;
                    ga_st    <= GA_FG_REQ;
                end
            end
            GA_BG_REQ: begin
                if (gfx_ok) begin
                    // BG data received (bg_rom_served set by latch above)
                    gfx_cs <= 0;
                    ga_st  <= GA_BG_GAP;
                end
                // If bg_rom_pending cleared externally (by pxl_cen edge re-requesting),
                // just move on
                if (!bg_rom_pending) begin
                    gfx_cs <= 0;
                    ga_st  <= GA_BG_GAP;
                end
            end
            GA_BG_GAP: begin
                gfx_cs <= 0;
                // Check for FG, then back to idle
                if (fg_rom_pending) begin
                    gfx_addr <= fg_rom_addr_lat;
                    gfx_cs   <= 1;
                    ga_st    <= GA_FG_REQ;
                end else if (bg_rom_pending) begin
                    gfx_addr <= bg_rom_addr_lat;
                    gfx_cs   <= 1;
                    ga_st    <= GA_BG_REQ;
                end else begin
                    ga_st <= GA_IDLE;
                end
            end
            GA_FG_REQ: begin
                if (gfx_ok) begin
                    gfx_cs <= 0;
                    ga_st  <= GA_FG_GAP;
                end
                if (!fg_rom_pending) begin
                    gfx_cs <= 0;
                    ga_st  <= GA_FG_GAP;
                end
            end
            GA_FG_GAP: begin
                gfx_cs <= 0;
                if (bg_rom_pending) begin
                    gfx_addr <= bg_rom_addr_lat;
                    gfx_cs   <= 1;
                    ga_st    <= GA_BG_REQ;
                end else if (fg_rom_pending) begin
                    gfx_addr <= fg_rom_addr_lat;
                    gfx_cs   <= 1;
                    ga_st    <= GA_FG_REQ;
                end else begin
                    ga_st <= GA_IDLE;
                end
            end
            default: begin
                gfx_cs <= 0;
                ga_st  <= GA_IDLE;
            end
        endcase
    end
end

// =====================================================================
// TX tile pixel pipeline — 8x8 tiles, own ROM port
// =====================================================================

wire [10:0] tx_tile_code = tx_code_lat[10:0];
wire        tx_tile_bank = tx_code_lat[11];
wire [ 3:0] tx_tile_pal  = tx_code_lat[15:12];

wire [5:0] tx_bank_val = tx_tile_bank ? tx_bank1_sel : tx_bank0_sel;

reg [31:0] tx_shift, tx_shift_nxt;
reg [ 3:0] tx_pal,   tx_pal_nxt;

// TX ROM request: latched addr held stable while txt_cs is high
reg        tx_rom_pending;
reg [16:0] tx_rom_addr_lat;
reg [ 3:0] tx_pal_lat;

wire tx_8px_edge = (hdump[2:0] == 3'd0);

always @(posedge clk) begin
    if (rst) begin
        tx_shift     <= 0; tx_shift_nxt <= 0;
        tx_pal       <= 0; tx_pal_nxt   <= 0;
        tx_rom_pending <= 0;
    end else if (pxl_cen) begin
        if (tx_8px_edge) begin
            tx_shift <= tx_shift_nxt;
            tx_pal   <= tx_pal_nxt;
            if (LHBL & LVBL) begin
                tx_rom_pending  <= 1;
                tx_rom_addr_lat <= {tx_bank_val[0], tx_tile_code[10:0], vdump[2:0], 2'b00};
                tx_pal_lat      <= tx_tile_pal;
            end
        end else begin
            // tx_shift holds full 32-bit tile word; nibble selected by hdump[2:0]
        end
    end
end

// Latch TX ROM data when ready
always @(posedge clk) begin
    if (!rst && tx_rom_pending && txt_ok) begin
        tx_shift_nxt   <= txt_data;
        tx_pal_nxt     <= tx_pal_lat;
        tx_rom_pending <= 0;
    end
end

// TXT SDRAM port: hold addr stable while cs is high
always @(posedge clk) begin
    if (rst) begin
        txt_cs   <= 0;
        txt_addr <= 0;
    end else begin
        if (tx_rom_pending && !txt_cs) begin
            // New request: assert cs with latched addr
            txt_cs   <= 1;
            txt_addr <= tx_rom_addr_lat;
        end else if (txt_cs && txt_ok) begin
            // Data received, drop cs
            txt_cs <= 0;
        end else if (!tx_rom_pending) begin
            txt_cs <= 0;
        end
    end
end

reg [3:0] tx_pix;
always @(*) begin
    case (hdump[2:0])
        3'd0: tx_pix = tx_shift[ 3: 0];
        3'd1: tx_pix = tx_shift[ 7: 4];
        3'd2: tx_pix = tx_shift[11: 8];
        3'd3: tx_pix = tx_shift[15:12];
        3'd4: tx_pix = tx_shift[19:16];
        3'd5: tx_pix = tx_shift[23:20];
        3'd6: tx_pix = tx_shift[27:24];
        default: tx_pix = tx_shift[31:28];
    endcase
end

// =====================================================================
// Sprite engine — scan + draw to double-buffered line buffer
// =====================================================================
// jtframe_obj_buffer provides a JTFRAME-standard double line buffer.
// DW=10: bits [9:4]=palette(6), [3:0]=pixel(4).  AW=9: 512 positions.
// ALPHAW=4, ALPHA=0: pixel==0 is transparent (not written).
// The buffer auto-erases each entry after it is read (on rd pulse).
// Line flip happens on falling edge of LHBL (start of HBLANK).

reg [ 8:0] obj_wr_addr;
reg [ 9:0] obj_wr_data;
reg        obj_wr_en;

wire [ 9:0] obj_rd_data;
wire        obj_lbuf_rd = pxl_cen & LHBL;

jtframe_obj_buffer #(
    .DW      ( 10 ),
    .AW      (  9 ),
    .ALPHAW  (  4 ),
    .ALPHA   ( 32'h0 ),
    .BLANK   ( 32'h0 ),
    .BLANK_DLY( 2 )
) u_obj_lbuf (
    .clk     ( clk           ),
    .LHBL    ( LHBL          ),
    .flip    ( 1'b0          ),   // no global flip in sprite X mapping
    // Write port (sprite scan during HBLANK)
    .wr_data ( obj_wr_data   ),
    .wr_addr ( obj_wr_addr   ),
    .we      ( obj_wr_en     ),
    // Read port (pixel output during active line)
    .rd_addr ( hdump[8:0]    ),
    .rd      ( obj_lbuf_rd   ),
    .rd_data ( obj_rd_data   )
);

wire [3:0] obj_pix     = obj_rd_data[3:0];
wire [5:0] obj_pix_pal = obj_rd_data[9:4];

// Sprite scan FSM
reg [ 8:0] spr_idx;
reg        spr_scanning;
reg        spr_drawing;
reg        LHBL_prev;

reg [14:0] spr_code;
reg [ 5:0] spr_color;
reg        spr_flipx, spr_flipy;
reg [ 8:0] spr_x;
reg [ 8:0] spr_ydiff;
reg [ 3:0] spr_ysub;

reg [31:0] spr_shift;
reg [ 3:0] spr_draw_cnt;
reg        spr_half;
reg        spr_rom_wait;

wire [3:0] spr_cur_pix = (spr_flipx ^ spr_half) ?
    { spr_shift[24], spr_shift[16], spr_shift[8], spr_shift[0] } :
    { spr_shift[31], spr_shift[23], spr_shift[15], spr_shift[7] };

localparam [2:0]
    SR_IDLE  = 0,
    SR_RD0   = 1,
    SR_RD1   = 2,
    SR_RD2   = 3,
    SR_RD3   = 4,
    SR_CHECK = 5,
    SR_DRAW  = 6;

reg [2:0] spr_st;

always @(posedge clk) LHBL_prev <= LHBL;

always @(posedge clk) begin
    if (rst) begin
        spr_scanning  <= 0;
        spr_drawing   <= 0;
        spr_idx       <= 0;
        spr_st        <= SR_IDLE;
        obj_wr_en     <= 0;
        obj_cs        <= 0;
        spr_rom_wait  <= 0;
        vram_sprite_mode <= 0;
    end else begin
        obj_wr_en <= 0;

        if (!LHBL && LHBL_prev) begin
            spr_scanning <= 1;
            spr_drawing  <= 0;
            spr_idx      <= 0;
            spr_st       <= SR_RD0;
        end

        if (LHBL && !LHBL_prev) begin
            spr_scanning <= 0;
            spr_drawing  <= 0;
            spr_st       <= SR_IDLE;
            obj_cs       <= 0;
        end

        if (spr_scanning && !spr_drawing) begin
            case (spr_st)
                SR_RD0: begin
                    spram_addr <= {spr_idx, 3'd0};
                    spr_st     <= SR_RD1;
                end
                SR_RD1: begin
                    spr_code   <= spram_dout[14:0];
                    spram_addr <= {spr_idx, 3'd1};
                    spr_st     <= SR_RD2;
                end
                SR_RD2: begin
                    spr_color  <= spram_dout[5:0];
                    spr_flipx  <= spram_dout[14];
                    spr_flipy  <= spram_dout[15];
                    spram_addr <= {spr_idx, 3'd2};
                    spr_st     <= SR_RD3;
                end
                SR_RD3: begin
                    spr_x      <= spram_dout[8:0];
                    spram_addr <= {spr_idx, 3'd3};
                    spr_st     <= SR_CHECK;
                end
                SR_CHECK: begin
                    spr_ydiff <= vdump[8:0] - spram_dout[8:0];
                    spr_st    <= SR_DRAW;
                end
                SR_DRAW: begin
                    if (spr_ydiff[8:4] == 5'd0) begin
                        spr_ysub     <= spr_ydiff[3:0] ^ {4{spr_flipy}};
                        spr_drawing  <= 1;
                        spr_half     <= 0;
                        spr_draw_cnt <= 0;
                        spr_rom_wait <= 1;
                        obj_wr_addr  <= spr_x;
                        // Hold addr stable for JTFRAME romrq
                        obj_addr <= {spr_code, spr_flipx, spr_ydiff[3:0] ^ {4{spr_flipy}}};
                        obj_cs   <= 1;
                    end else begin
                        if (spr_idx == 9'd407) begin
                            spr_scanning <= 0;
                            spr_st       <= SR_IDLE;
                        end else begin
                            spr_idx <= spr_idx + 9'd1;
                            spr_st  <= SR_RD0;
                        end
                    end
                end
                default: spr_st <= SR_IDLE;
            endcase
        end

        if (spr_drawing) begin
            if (spr_rom_wait) begin
                if (obj_ok) begin
                    spr_shift    <= obj_data;
                    spr_rom_wait <= 0;
                    obj_cs       <= 0;
                end
            end else begin
                if (spr_cur_pix != 4'd0) begin
                    obj_wr_en   <= 1;
                    obj_wr_data <= {spr_color, spr_cur_pix};
                end

                obj_wr_addr <= obj_wr_addr + 9'd1;

                if (spr_flipx ^ spr_half)
                    spr_shift <= spr_shift >> 1;
                else
                    spr_shift <= spr_shift << 1;

                spr_draw_cnt <= spr_draw_cnt + 4'd1;

                if (spr_draw_cnt == 4'd7) begin
                    if (!spr_half) begin
                        spr_half     <= 1;
                        spr_draw_cnt <= 0;
                        spr_rom_wait <= 1;
                        obj_addr     <= {spr_code, ~spr_flipx, spr_ysub};
                        obj_cs       <= 1;
                    end else begin
                        spr_drawing <= 0;
                        obj_cs      <= 0;
                        if (spr_idx == 9'd407) begin
                            spr_scanning <= 0;
                            spr_st       <= SR_IDLE;
                        end else begin
                            spr_idx <= spr_idx + 9'd1;
                            spr_st  <= SR_RD0;
                        end
                    end
                end
            end
        end
    end
end

// =====================================================================
// Priority compositing
// =====================================================================
localparam [11:0]
    PAL_TX  = 12'h000,
    PAL_OBJ = 12'h400,
    PAL_FG  = 12'h800,
    PAL_BG  = 12'hC00;

wire bg_opaque  = (bg_pix  != 4'd0);
wire fg_opaque  = (fg_pix  != 4'd0);
wire obj_opaque = (obj_pix != 4'd0);
wire tx_opaque  = (tx_pix  != 4'd0);
// fb_pix declared below (after fb_mem storage); wire forward-referenced but fb_mem
// is a reg array — Verilog allows this since fb_pix is a wire driven by the array.
// fb_pix non-zero means an opaque framebuffer pixel
// fb_color_base = 0x40*16 = palette entry 0x400 in 12-bit space
// actual: col_addr[11:8] = 4'h4, col_addr[7:0] = fb_pix
// sprite_priority mode (ctrl[7][3]=1): TX > FB > FG > BG (MAME priority_mode 1)
wire sprite_priority = ctrl[7][3];

always @(posedge clk) begin
    if (pxl_cen) begin
        if (!LHBL || !LVBL) begin
            col_addr  <= 12'd0;
            col_valid <= 0;
        end else if (sprite_priority) begin
            // Priority mode 1 (Tetris): TX > FB > OBJ > FG > BG
            col_addr  <= 12'd0;
            col_valid <= 0;
            if (bg_opaque) begin
                col_addr  <= PAL_BG | {2'b00, bg_pal, bg_pix};
                col_valid <= 1;
            end
            if (fg_opaque) begin
                col_addr  <= PAL_FG | {2'b00, fg_pal, fg_pix};
                col_valid <= 1;
            end
            if (obj_opaque) begin
                col_addr  <= PAL_OBJ | {2'b00, obj_pix_pal, obj_pix};
                col_valid <= 1;
            end
            if (fb_pix != 8'h00) begin
                // FB pixel is 8-bit index into palette bank starting at 0x400
                col_addr  <= {4'h4, fb_pix[7:0]};
                col_valid <= 1;
            end
            if (tx_opaque) begin
                col_addr  <= PAL_TX | {4'b0000, tx_pal, tx_pix};
                col_valid <= 1;
            end
        end else begin
            // Default priority: TX > OBJ > FG > BG
            col_addr  <= 12'd0;
            col_valid <= 0;
            if (bg_opaque) begin
                col_addr  <= PAL_BG | {2'b00, bg_pal, bg_pix};
                col_valid <= 1;
            end
            if (fg_opaque) begin
                col_addr  <= PAL_FG | {2'b00, fg_pal, fg_pix};
                col_valid <= 1;
            end
            if (obj_opaque) begin
                col_addr  <= PAL_OBJ | {2'b00, obj_pix_pal, obj_pix};
                col_valid <= 1;
            end
            if (tx_opaque) begin
                col_addr  <= PAL_TX | {4'b0000, tx_pal, tx_pix};
                col_valid <= 1;
            end
        end
    end
end

// =====================================================================
// Framebuffer — 2 pages of 512x256 8-bit pixels (262144 bytes total)
// Address = {page[0], y[7:0], x[8:0]} = 18 bits
// =====================================================================
reg [7:0] fb_mem [0:262143];

// CPU write path — writes pairs of pixels as a 16-bit word
wire fb_wr_sel = cpu_cs & cpu_we & cpu_addr[18];
// Address: {cpu_addr[17](page), Y[7:0](cpu_addr[16:9]), X_pair[7:0](cpu_addr[8:1]), pixel_bit}
wire [17:0] fb_wr_addr_hi = {cpu_addr[17], cpu_addr[16:9], cpu_addr[8:1], 1'b0};
wire [17:0] fb_wr_addr_lo = {cpu_addr[17], cpu_addr[16:9], cpu_addr[8:1], 1'b1};

always @(posedge clk) begin
    if (fb_wr_sel) begin
        if (!cpu_dsn[1]) fb_mem[fb_wr_addr_hi] <= cpu_din[15:8]; // upper byte = left pixel
        if (!cpu_dsn[0]) fb_mem[fb_wr_addr_lo] <= cpu_din[7:0];  // lower byte = right pixel
        `ifdef SIMULATION
        if (fb_wr_sel && cpu_din != 16'h0000 && diag_cycle > 60_000_000)
            $display("FB_WRITE: addr=%05X data=%04X page=%b dsn=%b cyc=%0d",
                     cpu_addr, cpu_din, fb_page, cpu_dsn, diag_cycle);
        `endif
    end
end

// Framebuffer clear engine — clears the write page at vblank start (unless inhibited)
reg [17:0] fb_clr_addr;
reg        fb_clearing;

always @(posedge clk) begin
    if (rst) begin
        fb_clearing <= 0;
        fb_clr_addr <= 0;
    end else begin
        if (!LVBL && lvbl_prev && !fb_no_erase) begin
            fb_clearing <= 1;
            fb_clr_addr <= {fb_page, 17'd0}; // start of write page
        end
        if (fb_clearing) begin
            fb_mem[fb_clr_addr] <= 8'h00;
            if (fb_clr_addr[16:0] == 17'h1FFFF)
                fb_clearing <= 0;
            else
                fb_clr_addr <= fb_clr_addr + 18'd1;
        end
    end
end

// Scanout — combinational read of the display page (opposite of write page)
wire [7:0] fb_pix = fb_mem[{fb_page, vdump[7:0], hdump[8:0]}];

// =====================================================================
// Simulation diagnostics
// =====================================================================
`ifdef SIMULATION
integer sim_i;
initial begin
    for (sim_i = 0; sim_i < 16; sim_i = sim_i + 1) ctrl[sim_i] = 0;
end

// Diagnostic counters
reg [31:0] diag_cycle;
reg [31:0] diag_gfx_req_cnt, diag_gfx_ok_cnt;
reg [31:0] diag_txt_req_cnt, diag_txt_ok_cnt;
reg [31:0] diag_obj_req_cnt, diag_obj_ok_cnt;
reg [31:0] diag_col_valid_cnt;
reg [31:0] diag_vram_nonzero_cnt;
reg        diag_first_col_valid;
reg [31:0] diag_bg_fetch_cnt, diag_fg_fetch_cnt, diag_tx_fetch_cnt;
reg [31:0] diag_bg_rom_req_cnt, diag_bg_rom_served_cnt;
reg [31:0] diag_fg_rom_req_cnt, diag_fg_rom_served_cnt;
reg [31:0] diag_tx_rom_req_cnt, diag_tx_rom_served_cnt;
reg [31:0] diag_bg_shift_load_cnt;
reg [31:0] diag_bg_pix_nonzero_cnt;

always @(posedge clk) begin
    if (rst) begin
        diag_cycle <= 0;
        diag_gfx_req_cnt <= 0;
        diag_gfx_ok_cnt  <= 0;
        diag_txt_req_cnt <= 0;
        diag_txt_ok_cnt  <= 0;
        diag_obj_req_cnt <= 0;
        diag_obj_ok_cnt  <= 0;
        diag_col_valid_cnt <= 0;
        diag_vram_nonzero_cnt <= 0;
        diag_first_col_valid <= 0;
        diag_bg_fetch_cnt <= 0;
        diag_fg_fetch_cnt <= 0;
        diag_tx_fetch_cnt <= 0;
        diag_bg_rom_req_cnt <= 0;
        diag_bg_rom_served_cnt <= 0;
        diag_fg_rom_req_cnt <= 0;
        diag_fg_rom_served_cnt <= 0;
        diag_tx_rom_req_cnt <= 0;
        diag_tx_rom_served_cnt <= 0;
        diag_bg_shift_load_cnt <= 0;
        diag_bg_pix_nonzero_cnt <= 0;
    end else begin
        diag_cycle <= diag_cycle + 1;

        // Trace first CPU accesses to VCU (up to 2M cycles after reset)
        if (cpu_cs && diag_cycle < 32'd2_000_000 && diag_cycle > 32'd1_200) begin
            $display("VCU_CPU: addr=%05X we=%b dsn=%b din=%04X dout=%04X ctrl_sel=%b cyc=%0d",
                     cpu_addr, cpu_we, cpu_dsn, cpu_din, cpu_dout, ctrl_sel, diag_cycle);
        end

        // Count GFX ROM requests and responses
        if (gfx_cs && !gfx_ok) diag_gfx_req_cnt <= diag_gfx_req_cnt + 1;
        if (gfx_cs && gfx_ok)  diag_gfx_ok_cnt  <= diag_gfx_ok_cnt + 1;

        // Count TXT ROM requests and responses
        if (txt_cs && !txt_ok) diag_txt_req_cnt <= diag_txt_req_cnt + 1;
        if (txt_cs && txt_ok)  diag_txt_ok_cnt  <= diag_txt_ok_cnt + 1;

        // Count OBJ ROM requests and responses
        if (obj_cs && !obj_ok) diag_obj_req_cnt <= diag_obj_req_cnt + 1;
        if (obj_cs && obj_ok)  diag_obj_ok_cnt  <= diag_obj_ok_cnt + 1;

        // Track VRAM fetch triggers
        if (vr_st == VR_BG0_A) diag_bg_fetch_cnt <= diag_bg_fetch_cnt + 1;
        if (vr_st == VR_FG0_A) diag_fg_fetch_cnt <= diag_fg_fetch_cnt + 1;
        if (vr_st == VR_TX_A)  diag_tx_fetch_cnt <= diag_tx_fetch_cnt + 1;

        // Track BG ROM requests
        if (pxl_cen && bg_8px_edge && LHBL && LVBL)
            diag_bg_rom_req_cnt <= diag_bg_rom_req_cnt + 1;

        // Track BG ROM served
        if (bg_rom_served)
            diag_bg_rom_served_cnt <= diag_bg_rom_served_cnt + 1;

        // Track TX ROM served
        if (tx_rom_pending == 0 && txt_ok)
            ; // not interesting
        if (!rst && tx_rom_pending && txt_ok)
            diag_tx_rom_served_cnt <= diag_tx_rom_served_cnt + 1;

        // Track BG shift register load (when bg_shift gets non-zero data)
        if (pxl_cen && bg_8px_edge && bg_shift_nxt != 0)
            diag_bg_shift_load_cnt <= diag_bg_shift_load_cnt + 1;

        // Track non-zero bg_pix
        if (pxl_cen && LHBL && LVBL && bg_pix != 0)
            diag_bg_pix_nonzero_cnt <= diag_bg_pix_nonzero_cnt + 1;

        // Count non-transparent pixels
        if (pxl_cen && col_valid) begin
            diag_col_valid_cnt <= diag_col_valid_cnt + 1;
            if (!diag_first_col_valid) begin
                diag_first_col_valid <= 1;
                $display("VCU_DIAG: first non-transparent pixel! col_addr=%03X cyc=%0d", col_addr, diag_cycle);
            end
        end

        // Sample VRAM reads — first 5 non-zero
        if (vr_st == VR_BG0_D && vram_dout != 16'h0000 && diag_vram_nonzero_cnt < 5) begin
            diag_vram_nonzero_cnt <= diag_vram_nonzero_cnt + 1;
            $display("VCU_DIAG: VRAM non-zero read: addr=%04X data=%04X (BG code) cyc=%0d",
                     vram_addr, vram_dout, diag_cycle);
        end

        // CRITICAL: trace first few BG ROM requests and responses
        if (ga_st == GA_IDLE && bg_rom_pending && diag_bg_rom_req_cnt < 3) begin
            $display("VCU_GFX_ARB: issuing BG req addr=%05X (bg_code=%04X) cyc=%0d",
                     bg_rom_addr_lat, bg_code_lat, diag_cycle);
        end
        if (ga_st == GA_BG_REQ && gfx_ok && diag_bg_rom_served_cnt < 3) begin
            $display("VCU_GFX_ARB: BG gfx_ok! addr=%05X data=%08X cyc=%0d",
                     gfx_addr, gfx_data, diag_cycle);
        end
        if (bg_rom_served && diag_bg_rom_served_cnt < 3) begin
            $display("VCU_GFX_LATCH: BG data latched! shift_nxt=%08X pal_nxt=%02X cyc=%0d",
                     bg_shift_nxt, bg_pal_nxt, diag_cycle);
        end

        // CRITICAL: trace first few TX ROM requests and responses
        if (tx_rom_pending && !txt_cs && diag_tx_rom_req_cnt < 5) begin
            diag_tx_rom_req_cnt <= diag_tx_rom_req_cnt + 1;
            $display("VCU_TXT: issuing TX req addr=%05X (tile_code=%04X bank_val=%02X vdump=%0d) cyc=%0d",
                     tx_rom_addr_lat, tx_code_lat, tx_bank_val, vdump, diag_cycle);
        end
        if (txt_cs && txt_ok && diag_tx_rom_served_cnt < 5) begin
            $display("VCU_TXT: TX txt_ok! addr=%05X data=%08X cyc=%0d",
                     txt_addr, txt_data, diag_cycle);
        end

        // TX VRAM read trace: first N non-zero tile codes
        if (vr_st == VR_TX_D && vram_dout != 16'h0000 && diag_tx_rom_req_cnt < 10) begin
            $display("VCU_TX_VRAM: non-zero tile code=%04X from vram_addr=%04X (tx_vaddr=%04X) hdump=%0d vdump=%0d cyc=%0d",
                     vram_dout, vram_addr, tx_vaddr, hdump, vdump, diag_cycle);
        end

        // TX shift register load trace
        if (pxl_cen && tx_8px_edge && LHBL && LVBL && tx_shift_nxt != 0 && diag_tx_rom_served_cnt < 10) begin
            $display("VCU_TX_SHIFT: loading non-zero shift=%08X pal=%X at hdump=%0d vdump=%0d cyc=%0d",
                     tx_shift_nxt, tx_pal_nxt, hdump, vdump, diag_cycle);
        end

        // TX pixel output trace (first N non-zero)
        if (pxl_cen && LHBL && LVBL && tx_opaque && diag_col_valid_cnt < 10) begin
            $display("VCU_TX_PIX: tx_pix=%X tx_pal=%X tx_shift=%08X col_addr=%03X hdump=%0d vdump=%0d cyc=%0d",
                     tx_pix, tx_pal, tx_shift, col_addr, hdump, vdump, diag_cycle);
        end

        // Trace blanking signals
        if (diag_cycle == 32'd100_000) begin
            $display("VCU_BLANK: LHBL=%b LVBL=%b hdump=%0d vdump=%0d cyc=%0d",
                     LHBL, LVBL, hdump, vdump, diag_cycle);
        end

        // Sample bg_pix every 10M cycles to see if it's ever nonzero
        if (diag_cycle == 32'd10_000_000 || diag_cycle == 32'd50_000_000 ||
            diag_cycle == 32'd100_000_000 || diag_cycle == 32'd200_000_000) begin
            $display("VCU_PIX: bg_pix=%X fg_pix=%X tx_pix=%X obj_pix=%X bg_shift=%08X fg_shift=%08X tx_shift=%08X bg_pal=%02X",
                     bg_pix, fg_pix, tx_pix, obj_pix, bg_shift, fg_shift, tx_shift, bg_pal);
        end

        // Periodic status dump
        if (diag_cycle == 32'd10_000_000 || diag_cycle == 32'd50_000_000 ||
            diag_cycle == 32'd100_000_000 || diag_cycle == 32'd200_000_000 ||
            diag_cycle == 32'd400_000_000 || diag_cycle == 32'd700_000_000) begin
            $display("VCU_DIAG: cyc=%0d gfx_req=%0d gfx_ok=%0d txt_req=%0d txt_ok=%0d obj_req=%0d obj_ok=%0d col_valid=%0d",
                     diag_cycle, diag_gfx_req_cnt, diag_gfx_ok_cnt,
                     diag_txt_req_cnt, diag_txt_ok_cnt,
                     diag_obj_req_cnt, diag_obj_ok_cnt, diag_col_valid_cnt);
            $display("VCU_DIAG: bg_fetch=%0d fg_fetch=%0d tx_fetch=%0d bg_rom_req=%0d bg_rom_served=%0d tx_rom_served=%0d",
                     diag_bg_fetch_cnt, diag_fg_fetch_cnt, diag_tx_fetch_cnt,
                     diag_bg_rom_req_cnt, diag_bg_rom_served_cnt, diag_tx_rom_served_cnt);
            $display("VCU_DIAG: bg_shift_loads=%0d bg_pix_nonzero=%0d ga_st=%0d vr_st=%0d",
                     diag_bg_shift_load_cnt, diag_bg_pix_nonzero_cnt, ga_st, vr_st);
            $display("VCU_DIAG: bg_rom_pending=%b fg_rom_pending=%b tx_rom_pending=%b",
                     bg_rom_pending, fg_rom_pending, tx_rom_pending);
            $display("VCU_DIAG: ctrl[0]=%02X ctrl[1]=%02X ctrl[4]=%02X ctrl[5]=%02X ctrl[6]=%02X ctrl[7]=%02X",
                     ctrl[0], ctrl[1], ctrl[4], ctrl[5], ctrl[6], ctrl[7]);
            $display("VCU_DIAG: bg_scroll=(%0d,%0d) fg_scroll=(%0d,%0d)",
                     bg_scrollx, bg_scrolly, fg_scrollx, fg_scrolly);
            $display("VCU_DIAG: bg_code_lat=%04X bg_attr_lat=%04X fg_code_lat=%04X tx_code_lat=%04X",
                     bg_code_lat, bg_attr_lat, fg_code_lat, tx_code_lat);
            $display("VCU_DIAG: LHBL=%b LVBL=%b hdump=%0d vdump=%0d",
                     LHBL, LVBL, hdump, vdump);
        end
    end
end
`endif

endmodule
