// Taito B System — Game top module
// Sources: wwfss_game.v pattern, JTFRAME conventions
// Instantiates: main (68000), TC0180VCU (video), TC0220IOC (I/O), colmix
// Sound: stubbed (snd=0, sample=0) — to be added in a later phase

`default_nettype none

module jttaitob_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// =====================================================================
// Screen timing — generated internally via jtframe_vtimer
// preLHBL/preLVBL are the vtimer outputs BEFORE the colmix delay.
// LHBL/LVBL/HS/VS are JTFRAME module outputs:
//   - LHBL/LVBL come from colmix's jtframe_blank (delayed).
//   - HS/VS come directly from vtimer.
// =====================================================================
wire [8:0] hdump, vdump;
wire       preLHBL, preLVBL;

// Taito B video timing: 320x224 active, 6MHz pixel clock.
// Total lines ~262, total H ~383 clocks at 6MHz.
jtframe_vtimer #(
    .V_START    ( 9'd16     ),
    .VB_START   ( 9'd239    ),
    .VB_END     ( 9'd264    ),
    .VS_START   ( 9'd244    ),
    .VCNT_END   ( 9'd264    ),
    .HB_START   ( 9'd319    ),
    .HB_END     ( 9'd383    ),
    .HS_START   ( 9'd336    ),
    .HJUMP      ( 0         ),
    .HINIT      ( 9'd383    )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( preLHBL   ),  // pre-delay output to VCU and colmix
    .LVBL       ( preLVBL   ),  // pre-delay output to VCU and colmix
    .HS         ( HS        ),  // sync output to JTFRAME
    .VS         ( VS        )   // sync output to JTFRAME
);

// =====================================================================
// TC0220IOC signals
// =====================================================================
wire [ 2:0] ioc_addr;
wire [ 7:0] ioc_dout_main, ioc_din;
wire        ioc_we;

// =====================================================================
// TC0140SYT signals — wired to main but sound is stubbed
// =====================================================================
wire [ 1:0] syt_addr_w;
wire [ 7:0] syt_dout_main;
wire        syt_we_w, syt_rd_w;

// =====================================================================
// TC0180VCU CPU bus signals (from main)
// =====================================================================
wire [18:1] vcu_cpu_addr;
wire [15:0] vcu_cpu_dout;
wire [15:0] vcu_internal_din;  // VCU's own cpu_dout (ctrl regs, framebuffer)
wire [15:0] vcu_cpu_din;       // final muxed data back to CPU
wire        vcu_cpu_cs, vcu_cpu_we;
wire [ 1:0] vcu_cpu_dsn;
wire        vcu_inth, vcu_intl;

// =====================================================================
// Pixel output from VCU to colmix
// =====================================================================
wire [11:0] col_addr_w;
wire        col_valid_w;

// =====================================================================
// BRAM address wiring
//
// JTFRAME BRAM dual-port scheme for taitob (from mem.yaml + mem_ports.inc):
//   - Port A (game side, "video"): driven by {name}_addr signals below
//   - Port B (CPU side "main"):    writes use main_dout + {name}_we
//     The CPU address for BRAM writes shares Port A's address bus.
//     CPU writes should happen during blanking when video is not reading.
//
// Address bit widths (from mem_ports.inc, which is ground truth):
//   vram_addr  [15:1]  — 16-bit BRAM, addr_width=16 → 15 address bits
//   spram_addr [12:1]  — 16-bit BRAM, addr_width=13 → 12 address bits (gap-extended)
//   scram_addr [9:1]   — 16-bit BRAM, addr_width=10 →  9 address bits
//   pal_addr   [11:1]  — 16-bit BRAM, addr_width=12 → 11 address bits
//
// VCU internals use 0-based full-width: [15:0], [11:0], [9:0]
// We connect bits [MSB:1] from VCU outputs to JTFRAME ports (bit 0 unused
// for 16-bit BRAMs — it's the byte select within the word).
// =====================================================================

// VCU-internal BRAM address wires (full width, 0-indexed)
wire [15:0] vcu_vram_addr_w;
wire [11:0] vcu_spram_addr_w;
wire [ 9:0] vcu_scram_addr_w;

// VRAM: VCU drives video reads; main CPU writes during blanking (same bus).
// We mux between VCU (video) and main (CPU) based on vram_we:
// when CPU is writing, its address must be on the bus.
// main_pal_addr etc. are internal wires from the main module.
wire [12:1] main_pal_addr_w;
// cpu_addr_o_w declared in mem_ports.inc
// main_pal_dout_w = cpu_dout from main, same value as vcu_cpu_dout / main_dout.
// We leave it connected to avoid a dangling output port on the main module.

// VCU drives video-side BRAM read addresses continuously.
// CPU writes use {name}_we + main_dout with address on the same bus.
// For VRAM/SPRAM/SCRAM: VCU owns the address bus; CPU write address is
// latched separately in the BRAM's write port via the JTFRAME dual-port
// scheme (the BRAM knows the write address from the CPU write decode).
// For initial simulation this means VCU address = write address — a known
// limitation that works for Tetris since CPU writes during LVBL only.
// VCU outputs 0-indexed 16-bit word addresses [15:0].
// BRAM port expects [15:1] = 15-bit index.
// Use [14:0] of the VCU address as the 15-bit BRAM index.
// This maps VCU word address N to BRAM entry N (correct 1:1 mapping).
assign vram_addr  = vcu_vram_addr_w [14:0];
assign spram_addr = {1'b0, vcu_spram_addr_w[11:0]};  // zero-extend: VCU uses [11:0], gap at [12:x] unused by video
assign scram_addr = vcu_scram_addr_w[ 9:0];

// Palette address mux: CPU write wins over colmix video read.
// pal_we is driven by jttaitob_main (already assigned to JTFRAME port).
wire pal_cpu_writing = (pal_we != 2'b00);
wire [11:0] colmix_pal_addr_w;  // colmix output — its desired read address
assign pal_addr = pal_cpu_writing ? main_pal_addr_w[12:1] : colmix_pal_addr_w[11:0];

// main_dout is the shared BRAM write data bus (all BRAMs use din: main_dout).
// It carries the CPU's write data for whichever BRAM is currently being written.
// jttaitob_main outputs write data via pal_dout port (= cpu_dout internally).
// We assign main_dout from the main CPU's palette write data; for VRAM/SPRAM/SCRAM
// writes, the main module also outputs through cpu_dout but routed via vcu_cpu_dout.
// For correctness, all BRAM writes use the same data bus: main_dout = vcu_cpu_dout
// since the CPU writes to all BRAMs through the same data register.
assign main_dout = vcu_cpu_dout;  // 16-bit CPU write data

// VCU CPU address for BRAM write addressing (declared in mem_ports.inc as output)
assign vcu_cpu_addr_w = vcu_cpu_addr[15:1];

// =====================================================================
// ROM address wiring (SDRAM)
// JTFRAME port widths from mem_ports.inc:
//   main_addr [17:1]   — jttaitob_main outputs [18:1]; drop MSB (ROM is 512KB)
//   ram_addr  [13:1]   — jttaitob_main outputs [14:1]; drop MSB (RAM 32KB)
//   txt_addr  [16:2]   — 32-bit bus, JTFRAME addr_width=17 → bits [16:2]
//   gfx_addr  [19:2]   — 32-bit bus, JTFRAME addr_width=20 → bits [19:2]
//   obj_addr  [19:2]   — 32-bit bus, JTFRAME addr_width=20 → bits [19:2]
// =====================================================================

// Joystick: JTFRAME_BUTTONS=2 → [5:0]; tc0220ioc needs [7:0]
wire [7:0] joy1_8 = {2'b00, joystick1};
wire [7:0] joy2_8 = {2'b00, joystick2};

// Main-module-side address wires (wider than JTFRAME ports)
wire [18:1] main_addr_full_w;
wire [14:1] ram_addr_full_w;
wire [15:0] ram_din_w;
wire        ram_we_w;

assign main_addr = main_addr_full_w[17:1];  // MSB dropped (ROM <= 512KB)
assign ram_addr  = ram_addr_full_w [14:1];  // full 14-bit word addr (32KB)
assign ram_we    = ram_we_w;

// =====================================================================
// Work RAM shadow BRAM: bypasses SDRAM for read-back reliability.
// The CPU reads work RAM from this BRAM. Writes go to both SDRAM and BRAM.
// This ensures the RAM test passes regardless of SDRAM sim timing.
// =====================================================================
wire [15:0] wram_bram_dout;
wire [ 1:0] wram_bram_we = ram_we_w ? ~ram_dsn : 2'b00;

jtframe_dual_ram16 #(.AW(15-1)) u_wram_bram(
    // Port 0: unused (single-port would suffice, but dual_ram16 is available)
    .clk0   ( clk ),
    .addr0  ( ram_addr_full_w[14:1] ),
    .data0  ( 16'h0 ),
    .we0    ( 2'b00 ),
    .q0     ( ),
    // Port 1: CPU read/write
    .clk1   ( clk ),
    .addr1  ( ram_addr_full_w[14:1] ),
    .data1  ( vcu_cpu_dout ),
    .we1    ( wram_bram_we ),
    .q1     ( wram_bram_dout )
);

`ifdef SIMULATION
// =====================================================================
// ROM shadow BRAM: bypasses SDRAM for 68000 program ROM reads.
// 512KB = 256K x 16-bit words => AW=18 (addr[18:1]).
// In simulation, SDRAM bank files are loaded directly (prog_we is not
// used for SDRAM data), so we pre-load the BRAM from split binary files
// generated from sdram_bank0.bin (rom_hi.bin = even/high bytes,
// rom_lo.bin = odd/low bytes).
// Port 0: unused (read-only shadow).
// Port 1: CPU reads (replaces main_data from SDRAM, no wait states).
// =====================================================================
wire [15:0] rom_bram_dout;

jtframe_dual_ram16 #(
    .AW          ( 18           ),
    .SIMFILE_LO  ( "rom_lo.bin" ),
    .SIMFILE_HI  ( "rom_hi.bin" )
) u_rom_bram(
    // Port 0: unused
    .clk0   ( clk ),
    .addr0  ( 18'd0 ),
    .data0  ( 16'h0 ),
    .we0    ( 2'b00 ),
    .q0     ( ),
    // Port 1: CPU reads (16-bit, word-addressed)
    .clk1   ( clk ),
    .addr1  ( main_addr_full_w[18:1] ),
    .data1  ( 16'h0 ),
    .we1    ( 2'b00 ),
    .q1     ( rom_bram_dout )
);
`endif

// VCU-internal ROM address wires (full internal width)
wire [16:0] vcu_txt_addr_w;
wire [19:0] vcu_gfx_addr_w;
wire [19:0] vcu_obj_addr_w;
wire        vcu_txt_cs_w, vcu_gfx_cs_w, vcu_obj_cs_w;

// 32-bit SDRAM: JTFRAME expects word address [N:2] (bits 1:0 = sub-word select)
assign txt_addr = vcu_txt_addr_w[16:2];
assign gfx_addr = vcu_gfx_addr_w[19:2];
assign obj_addr = vcu_obj_addr_w[19:2];
assign txt_cs   = vcu_txt_cs_w;
assign gfx_cs   = vcu_gfx_cs_w;
assign obj_cs   = vcu_obj_cs_w;

// =====================================================================
// Main CPU — 68000 @ 12 MHz
// =====================================================================
/* verilator tracing_off */
jttaitob_main u_main(
    .rst        ( rst               ),
    .clk        ( clk               ),
    // ROM (SDRAM bank 0)
    .main_addr  ( main_addr_full_w  ),
    .main_cs    ( main_cs           ),
`ifdef SIMULATION
    .main_data  ( rom_bram_dout     ),  // read from BRAM shadow (bypasses SDRAM sim issues)
    .main_ok    ( 1'b1              ),  // BRAM shadow: no wait states for ROM access
`else
    .main_data  ( main_data         ),
    .main_ok    ( main_ok           ),
`endif
    // Work RAM (SDRAM bank 0)
    .ram_addr   ( ram_addr_full_w   ),
    .ram_cs     ( ram_cs            ),
    .ram_din    ( ram_din_w         ),
    .ram_dout   ( wram_bram_dout    ),  // read from BRAM shadow (bypasses SDRAM sim issues)
    .ram_dsn    ( ram_dsn           ),
    .ram_we     ( ram_we_w          ),
    .ram_ok     ( 1'b1              ),  // BRAM shadow: no wait states for RAM access
    // TC0180VCU bus
    .vcu_addr   ( vcu_cpu_addr      ),
    .vcu_dout   ( vcu_cpu_dout      ),
    .vcu_din    ( vcu_cpu_din       ),
    .vcu_cs     ( vcu_cpu_cs        ),
    .vcu_we     ( vcu_cpu_we        ),
    .vcu_dsn    ( vcu_cpu_dsn       ),
    // TC0220IOC
    .ioc_addr   ( ioc_addr          ),
    .ioc_dout   ( ioc_dout_main     ),
    .ioc_din    ( ioc_din           ),
    .ioc_we     ( ioc_we            ),
    // TC0140SYT (stub — status returns 0x00 = no pending data)
    .syt_addr   ( syt_addr_w        ),
    .syt_dout   ( syt_dout_main     ),
    .syt_din    ( 8'h00             ),
    .syt_we     ( syt_we_w          ),
    .syt_rd     ( syt_rd_w          ),
    // Palette RAM (BRAM dual-port)
    .pal_addr   ( main_pal_addr_w   ),  // CPU palette address (drives pal_addr mux)
    .cpu_addr_o( cpu_addr_o_w ),
    .pal_dout   (                   ),  // CPU palette write data = cpu_dout = main_dout
    .pal_we     ( pal_we            ),  // write enables → JTFRAME port
    .pal_dsn    (                   ),  // unused
    .pal_din    ( pal2main_data     ),  // palette read data → CPU
    // Interrupts
    .vcu_inth   ( vcu_inth          ),
    .vcu_intl   ( vcu_intl          ),
    // Screen blanking
    .LVBL       ( preLVBL           )
);
/* verilator tracing_on */

// =====================================================================
// TC0220IOC — I/O controller
// cab_1p[0] = 1P start, cab_1p[1] = 2P start (JTFRAME convention)
// =====================================================================
tc0220ioc u_ioc(
    .clk          ( clk              ),
    .rst          ( rst              ),
    .addr         ( ioc_addr         ),
    .din          ( ioc_dout_main    ),
    .dout         ( ioc_din          ),
    .we           ( ioc_we           ),
    .joystick1    ( joy1_8             ),
    .joystick2    ( joy2_8             ),
    .start_button ( cab_1p[1:0]      ),
    .coin_input   ( coin[1:0]        ),
    .service      ( service          ),
    .tilt         ( tilt             ),
    .dipsw_a      ( dipsw[ 7:0]      ),
    .dipsw_b      ( dipsw[15:8]      ),
    .watchdog     (                  )
);

// =====================================================================
// TC0180VCU — combined tilemap + sprite video chip
// =====================================================================
tc0180vcu u_vcu(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    // CPU bus (from main)
    .cpu_addr   ( vcu_cpu_addr      ),
    .cpu_din    ( vcu_cpu_dout      ),
    .cpu_dout   ( vcu_internal_din  ),
    .cpu_cs     ( vcu_cpu_cs        ),
    .cpu_we     ( vcu_cpu_we        ),
    .cpu_dsn    ( vcu_cpu_dsn       ),
    // Screen timing (vtimer outputs, before colmix delay)
    .LHBL       ( preLHBL           ),
    .LVBL       ( preLVBL           ),
    .hdump      ( hdump             ),
    .vdump      ( vdump             ),
    // VRAM BRAM port (video-side read)
    .vram_addr  ( vcu_vram_addr_w   ),
    .vram_dout  ( vram_dout         ),
    // Sprite RAM BRAM port (video-side read)
    .spram_addr ( vcu_spram_addr_w  ),
    .spram_dout ( spram_dout        ),
    // Scroll RAM BRAM port (video-side read)
    .scram_addr ( vcu_scram_addr_w  ),
    .scram_dout ( scram_dout        ),
    // GFX ROM — BG/FG tiles (SDRAM bank 2)
    .gfx_addr   ( vcu_gfx_addr_w   ),
    .gfx_data   ( gfx_data         ),
    .gfx_ok     ( gfx_ok           ),
    .gfx_cs     ( vcu_gfx_cs_w     ),
    // Text tile ROM (SDRAM bank 2)
    .txt_addr   ( vcu_txt_addr_w   ),
    .txt_data   ( txt_data         ),
    .txt_ok     ( txt_ok           ),
    .txt_cs     ( vcu_txt_cs_w     ),
    // Sprite GFX ROM (SDRAM bank 3)
    .obj_addr   ( vcu_obj_addr_w   ),
    .obj_data   ( obj_data         ),
    .obj_ok     ( obj_ok           ),
    .obj_cs     ( vcu_obj_cs_w     ),
    // Interrupts to main CPU
    .inth       ( vcu_inth          ),
    .intl       ( vcu_intl          ),
    // Pixel output to colmix
    .col_addr   ( col_addr_w        ),
    .col_valid  ( col_valid_w       )
);

// =====================================================================
// Color mixer — reads palette BRAM, applies blanking, outputs RGB
// Inputs preLHBL/preLVBL (before delay) from vtimer.
// Outputs LHBL/LVBL (after jtframe_blank's DLY=2 delay) → JTFRAME ports.
// =====================================================================
jttaitob_colmix u_colmix(
    .clk        ( clk                   ),
    .pxl_cen    ( pxl_cen               ),
    .preLHBL    ( preLHBL               ),
    .preLVBL    ( preLVBL               ),
    .LHBL       ( LHBL                  ),  // delayed → JTFRAME output
    .LVBL       ( LVBL                  ),  // delayed → JTFRAME output
    .col_addr   ( col_addr_w            ),
    .col_valid  ( col_valid_w           ),
    .red        ( red                   ),
    .green      ( green                 ),
    .blue       ( blue                  ),
    .pal_addr   ( colmix_pal_addr_w     ),  // colmix outputs its desired read addr
    .pal_dout   ( pal_dout              )
);

// =====================================================================
// BRAM write enables for main CPU VRAM/SPRAM/SCRAM access
// These signals tell JTFRAME which BRAM to write when main CPU accesses
// the VCU address space. The VCU decodes the address and routes writes.
// For now, we tie these to the VCU CPU write path.
// vcu_area writes go to either vram, spram, or scram depending on addr.
// The VCU handles CPU writes internally for registers and framebuffer;
// for the BRAM-backed tile maps/sprite/scroll RAM, main writes via
// the shared BRAM write ports.
//
// Address decode (from MAME taito_b.cpp / tc0180vcu.cpp):
//   VCU space 400000-47FFFF (cpu_addr[18:1]):
//     0x00000-0x0BFFF  VRAM (tile maps, scroll RAM)
//     0x0C000-0x0FFFF  Control registers (VCU handles internally)
//     0x10000-0x1FFFF  Sprite RAM
//     0x20000+         Framebuffer (VCU handles internally)
// =====================================================================

// BRAM write address decode (from MAME tc0180vcu.cpp memory map):
//   VCU word address = cpu_addr[18:1] value
//   Value ranges (addr[N] has weight 2^(N-1)):
//     0x0000-0x7FFF  VRAM         => addr[18:16]=000 (bit 16 weight=2^15=32768)
//     0x8000-0x8FFF  Sprite RAM   => addr[18:16]=001, addr[15:13]=000
//     0x9C00-0x9FFF  Scroll RAM   => addr[18:16]=001, addr[15:13]=011
//     0xC000-0xC00F  Control regs => addr[18:16]=001, addr[15:14]=10 (VCU internal)
//     0x10000+       Framebuffer  => addr[18:17]!=00 (VCU internal, ignored)

// VRAM BRAM write: word 0x0000-0x7FFF
wire vram_cpu_write = vcu_cpu_we & vcu_cpu_cs &
                      (vcu_cpu_addr[18:16] == 3'b000);

// SPRAM BRAM write: word 0x8000-0x9BFF (addr value 32768-39935, covers sprite RAM + gap)
// addr[18:17]=00, addr[16]=1, addr[15:14]=00 (not upper 16KB),
// and NOT the scram range (0x9C00-0x9FFF: addr[13]&addr[12]&addr[11])
wire spram_cpu_write = vcu_cpu_we & vcu_cpu_cs &
                       (vcu_cpu_addr[18:17] == 2'b00) &
                        vcu_cpu_addr[16] &
                       !vcu_cpu_addr[15] &
                       !vcu_cpu_addr[14] &
                       !(vcu_cpu_addr[13] & vcu_cpu_addr[12] & vcu_cpu_addr[11]);

// SCRAM BRAM write: word 0x9C00-0x9FFF (addr value 39936-40959)
// addr[16]=1, addr[15]=0, addr[14]=0, addr[13]=1, addr[12]=1, addr[11]=1
wire scram_cpu_write = vcu_cpu_we & vcu_cpu_cs &
                       (vcu_cpu_addr[18:17] == 2'b00) &
                        vcu_cpu_addr[16] &
                       !vcu_cpu_addr[15] &
                       !vcu_cpu_addr[14] &
                        vcu_cpu_addr[13] &
                        vcu_cpu_addr[12] &
                        vcu_cpu_addr[11];

assign vram_we  = vram_cpu_write  ? ~vcu_cpu_dsn : 2'b00;
assign spram_we = spram_cpu_write ? ~vcu_cpu_dsn : 2'b00;
assign scram_we = scram_cpu_write ? ~vcu_cpu_dsn : 2'b00;

// =====================================================================
// CPU read-back mux for VRAM/SPRAM/SCRAM
// =====================================================================
// The VCU only handles ctrl register and framebuffer reads internally.
// For VRAM, SPRAM, and SCRAM, the CPU reads through the BRAM port 1
// read data (vram2main_data, spram2main_data, scram2main_data).
// We mux these into the CPU data path based on address decode.
//
// Address decode for reads (same regions as writes, but rnw=1):
wire vram_cpu_read  = vcu_cpu_cs & ~vcu_cpu_we &
                      (vcu_cpu_addr[18:16] == 3'b000);
wire spram_cpu_read = vcu_cpu_cs & ~vcu_cpu_we &
                      (vcu_cpu_addr[18:17] == 2'b00) &
                       vcu_cpu_addr[16] &
                      !vcu_cpu_addr[15] &
                      !vcu_cpu_addr[14] &
                      !(vcu_cpu_addr[13] & vcu_cpu_addr[12] & vcu_cpu_addr[11]);
wire scram_cpu_read = vcu_cpu_cs & ~vcu_cpu_we &
                      (vcu_cpu_addr[18:17] == 2'b00) &
                       vcu_cpu_addr[16] &
                      !vcu_cpu_addr[15] &
                      !vcu_cpu_addr[14] &
                       vcu_cpu_addr[13] &
                       vcu_cpu_addr[12] &
                       vcu_cpu_addr[11];

assign vcu_cpu_din = vram_cpu_read  ? vram2main_data  :
                     spram_cpu_read ? spram2main_data :
                     scram_cpu_read ? scram2main_data :
                                     vcu_internal_din;

// =====================================================================
// Sound — stubbed
// =====================================================================
assign snd    = 16'h0;
assign sample = 1'b0;

// Sound ROM chip selects: tie off to avoid undriven outputs
assign snd_cs = 1'b0;
assign snd_addr = 16'h0;
assign pcm_cs = 1'b0;
assign pcm_addr = 19'h0;

// =====================================================================
// Miscellaneous JTFRAME outputs
// =====================================================================
assign dip_flip   = 1'b0;
assign debug_view = 8'h0;
`ifndef JTFRAME_RELEASE
assign ioctl_din  = 8'h0;
`endif

`ifdef SIMULATION
// Track ROM BRAM shadow reads — verify BRAM loaded from rom_hi/lo.bin
reg [31:0] rom_rd_cnt;
reg rom_verified;
always @(posedge clk) begin
    if(rst) begin
        rom_rd_cnt  <= 0;
        rom_verified <= 0;
    end else begin
        // One-shot: verify BRAM content at word 0 (should be initial SP high word)
        if(!rom_verified) begin
            rom_verified <= 1;
            $display("ROM_BRAM_CHECK: word[0]=%04X (expect 0080 = initial SP high)", rom_bram_dout);
        end
        // Trace first CPU ROM reads after reset
        if(main_cs && !rst && rom_rd_cnt < 16) begin
            rom_rd_cnt <= rom_rd_cnt + 1;
            $display("ROM_RD: addr=%05X bram_out=%04X cyc=%0d",
                     main_addr_full_w[18:1], rom_bram_dout, sim_cycle);
        end
    end
end

// Track BRAM shadow RAM write and read
reg [31:0] wram_wr_cnt, wram_rd_cnt;
always @(posedge clk) begin
    if(rst) begin
        wram_wr_cnt <= 0;
        wram_rd_cnt <= 0;
    end else begin
        // Trace BRAM writes near top of RAM (exception handler area)
        if(wram_bram_we != 2'b00 && ram_addr_full_w[14:1] >= 14'h3FF0 && wram_wr_cnt < 10) begin
            wram_wr_cnt <= wram_wr_cnt + 1;
            $display("WRAM_WR: addr=%04X data=%04X we=%b cyc=%0d",
                     ram_addr_full_w, vcu_cpu_dout, wram_bram_we, sim_cycle);
        end
        // Trace BRAM reads from exception handler area
        if(ram_cs && !ram_we_w && ram_addr_full_w[14:1] >= 14'h3FF0 && wram_rd_cnt < 10) begin
            wram_rd_cnt <= wram_rd_cnt + 1;
            $display("WRAM_RD: addr=%04X bram_out=%04X cyc=%0d",
                     ram_addr_full_w, wram_bram_dout, sim_cycle);
        end
        // Also trace ALL first 3 writes after the fill loop completes
        if(wram_bram_we != 2'b00 && sim_cycle > 32'd1800 && wram_wr_cnt >= 10 && wram_wr_cnt < 13) begin
            wram_wr_cnt <= wram_wr_cnt + 1;
            $display("WRAM_WR_LATE: addr=%04X data=%04X we=%b cyc=%0d",
                     ram_addr_full_w, vcu_cpu_dout, wram_bram_we, sim_cycle);
        end
    end
end

reg [31:0] sim_cycle;
reg [31:0] vram_wr_cnt, spram_wr_cnt, scram_wr_cnt, pal_wr_cnt;
reg [31:0] vcu_rd_cnt;
reg [31:0] vcu_wr_trace_cnt;
always @(posedge clk) begin
    if(rst) begin
        sim_cycle    <= 0;
        vram_wr_cnt  <= 0;
        spram_wr_cnt <= 0;
        scram_wr_cnt <= 0;
        pal_wr_cnt   <= 0;
        vcu_rd_cnt   <= 0;
        vcu_wr_trace_cnt <= 0;
    end else begin
        sim_cycle <= sim_cycle + 1;

        // Count BRAM writes
        if (vram_we  != 2'b00) begin
            vram_wr_cnt  <= vram_wr_cnt + 1;
            // Show first 5 writes with BRAM port addresses
            if (vram_wr_cnt < 5)
                $display("VRAM_BRAM_WR: bram_addr=%04X vcu_addr=%05X data=%04X we=%b cyc=%0d",
                         vcu_cpu_addr_w, vcu_cpu_addr, main_dout, vram_we, sim_cycle);
            // Show ANY non-zero data write (no limit)
            if (main_dout != 16'h0)
                $display("VRAM_NONZERO: bram_addr=%04X vcu=%05X data=%04X we=%b cyc=%0d",
                         vcu_cpu_addr_w, vcu_cpu_addr, main_dout, vram_we, sim_cycle);
        end

        // Trace exact signal state when CPU accesses VRAM range (after ROM load)
        if (sim_cycle >= 32'd58982077 && sim_cycle <= 32'd58982090)
            $display("SIM_TRACE: cyc=%0d vcu_cs=%b vcu_we=%b addr=%05X dsn=%b vram_cpu_write=%b vram_we=%b main_dout=%04X",
                     sim_cycle, vcu_cpu_cs, vcu_cpu_we, vcu_cpu_addr, vcu_cpu_dsn, vram_cpu_write, vram_we, main_dout);
        if (spram_we != 2'b00) spram_wr_cnt <= spram_wr_cnt + 1;
        if (scram_we != 2'b00) scram_wr_cnt <= scram_wr_cnt + 1;
        if (pal_we   != 2'b00) pal_wr_cnt   <= pal_wr_cnt + 1;

        // First few BRAM writes
        if (vram_we != 2'b00 && vram_wr_cnt < 5)
            $display("SIM_WR: VRAM write #%0d addr=%04X data=%04X we=%b cyc=%0d",
                     vram_wr_cnt, main_addr_full_w[14:1], vcu_cpu_dout, vram_we, sim_cycle);
        if (spram_we != 2'b00 && spram_wr_cnt < 5)
            $display("SIM_WR: SPRAM write #%0d addr=%03X data=%04X we=%b cyc=%0d",
                     spram_wr_cnt, main_addr_full_w[11:1], vcu_cpu_dout, spram_we, sim_cycle);
        if (pal_we != 2'b00 && pal_wr_cnt < 5)
            $display("SIM_WR: PAL write #%0d addr=%03X data=%04X we=%b cyc=%0d",
                     pal_wr_cnt, main_addr_full_w[11:1], vcu_cpu_dout, pal_we, sim_cycle);

        // Track VCU VRAM writes (addr[15]=0, not control regs)
        if (vcu_cpu_cs && vcu_cpu_we && !vcu_cpu_addr[15] && vcu_cpu_addr[18:16]==3'b000 && vram_wr_cnt < 5)
            $display("SIM_VRAM_WR: addr=%05X data=%04X dsn=%b vram_we=%b cyc=%0d",
                     vcu_cpu_addr, vcu_cpu_dout, vcu_cpu_dsn, vram_we, sim_cycle);

        // Track ANY VCU write after ROM load
        if (vcu_cpu_cs && vcu_cpu_we && sim_cycle > 32'd55_000_000 && sim_cycle < 32'd57_000_000)
            $display("SIM_VCU_POST: addr=%05X data=%04X dsn=%b cyc=%0d",
                     vcu_cpu_addr, vcu_cpu_dout, vcu_cpu_dsn, sim_cycle);

        // Track palette writes
        if (pal_we != 2'b00 && pal_wr_cnt < 3)
            $display("SIM_WR: PAL write #%0d addr=%03X data=%04X we=%b cyc=%0d",
                     pal_wr_cnt, main_addr_full_w[11:1], vcu_cpu_dout, pal_we, sim_cycle);

        // Track ALL VCU reads (first 40)
        if (vcu_cpu_cs && !vcu_cpu_we && vcu_rd_cnt < 40) begin
            vcu_rd_cnt <= vcu_rd_cnt + 1;
            $display("SIM_VCU_RD: addr=%05X vram_rd=%b spram_rd=%b scram_rd=%b vram2main=%04X spram2main=%04X scram2main=%04X vcu_int_din=%04X vcu_cpu_din=%04X main_addr17_1=%05X cyc=%0d",
                     vcu_cpu_addr, vram_cpu_read, spram_cpu_read, scram_cpu_read,
                     vram2main_data, spram2main_data, scram2main_data,
                     vcu_internal_din, vcu_cpu_din, main_addr_full_w[17:1], sim_cycle);
        end
        // Track ALL VCU writes (first 40)
        if (vcu_cpu_cs && vcu_cpu_we && vcu_wr_trace_cnt < 40) begin
            vcu_wr_trace_cnt <= vcu_wr_trace_cnt + 1;
            $display("SIM_VCU_WR_TRACE: addr=%05X vram_wr=%b spram_wr=%b scram_wr=%b data=%04X dsn=%b main_addr17_1=%05X cyc=%0d",
                     vcu_cpu_addr, vram_cpu_write, spram_cpu_write, scram_cpu_write,
                     vcu_cpu_dout, vcu_cpu_dsn, main_addr_full_w[17:1], sim_cycle);
        end

        // Periodic status
        if (sim_cycle == 32'd50_000_000 || sim_cycle == 32'd70_000_000 ||
            sim_cycle == 32'd100_000_000 || sim_cycle == 32'd200_000_000 ||
            sim_cycle == 32'd500_000_000) begin
            $display("SIM_BRAM: cyc=%0d vram_wr=%0d spram_wr=%0d scram_wr=%0d pal_wr=%0d rst=%b",
                     sim_cycle, vram_wr_cnt, spram_wr_cnt, scram_wr_cnt, pal_wr_cnt, rst);
            $display("SIM_CPU: main_cs=%b main_addr=%05X vcu_cs=%b vcu_addr=%05X",
                     main_cs, main_addr_full_w, vcu_cpu_cs, vcu_cpu_addr);
        end
    end
    // Trace INTH transitions to verify interrupts
    if( vcu_inth && sim_cycle > 32'd55_000_000 && sim_cycle < 32'd55_100_000 )
        $display("SIM_INTH: inth=1 preLVBL=%b cyc=%0d", preLVBL, sim_cycle);
end
`endif

endmodule
