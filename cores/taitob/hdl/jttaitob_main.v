// Taito B System — Main CPU (68000 @ 12MHz)
// Sources: MAME taito_b.cpp tetrist_map, wwfss/gaiden main.v patterns
// Memory map:
//   000000-07FFFF  ROM (512KB)
//   200000-200003  TC0140SYT (sound comm)
//   400000-47FFFF  TC0180VCU (video)
//   600000-60000F  TC0220IOC (I/O)
//   800000-807FFF  Work RAM (32KB)
//   A00000-A01FFF  Palette RAM (8KB)

module jttaitob_main(
    input             rst,
    input             clk,
    // 68000 ROM interface
    output     [18:1] main_addr,
    output            main_cs,
    input      [15:0] main_data,
    input             main_ok,
    input             ram_ok,
    // Work RAM (SDRAM)
    output     [14:1] ram_addr,
    output            ram_cs,
    output     [15:0] ram_din,
    input      [15:0] ram_dout,
    output     [ 1:0] ram_dsn,
    output            ram_we,
    // TC0180VCU bus
    output     [18:1] vcu_addr,
    output     [15:0] vcu_dout,
    input      [15:0] vcu_din,
    output            vcu_cs,
    output            vcu_we,
    output     [ 1:0] vcu_dsn,
    // TC0220IOC
    output     [ 2:0] ioc_addr,
    output     [ 7:0] ioc_dout,
    input      [ 7:0] ioc_din,
    output            ioc_we,
    // TC0140SYT master side
    output     [ 1:0] syt_addr,
    output     [ 7:0] syt_dout,
    input      [ 7:0] syt_din,
    output            syt_we,
    output            syt_rd,
    // Palette RAM
    output     [12:1] pal_addr,
    output     [15:0] pal_dout,
    output     [ 1:0] pal_we,
    output     [ 1:0] pal_dsn,
    input      [15:0] pal_din,
    output     [12:1] cpu_addr_o,
    // Interrupts from TC0180VCU
    input             vcu_inth, // IRQ4
    input             vcu_intl, // IRQ2
    // Screen
    input             LVBL
);

wire [23:1] A;
wire [15:0] cpu_dout;
wire [ 1:0] dsn;
wire [ 2:0] FC;
wire        rnw, as_n;
wire        cpu_cen, cpu_cenb;

// Address decode (active during valid bus cycle)
wire mem_acc  = ~as_n;
wire rom_area = mem_acc & A[23:19] == 5'b00000;           // 000000-07FFFF
// MAME tetrist: 0x200000 = palette, NOT TC0140SYT (sound is at 0x800000 for rastsag2)
wire syt_area  = mem_acc & A[23:20] == 4'h2;               // 200000-2FFFFF = TC0140SYT
wire pal2_area = 1'b0;
wire vcu_area = mem_acc & A[23:20] == 4'h4;               // 400000-4FFFFF
wire ioc_area = mem_acc & A[23:20] == 4'h6;               // 600000-6FFFFF
wire ram_area = mem_acc & A[23:20] == 4'h8;               // 800000-8FFFFF
wire pal_area = mem_acc & A[23:20] == 4'hA;               // A00000-AFFFFF

assign main_cs  = rom_area;
assign main_addr = A[18:1];

assign ram_cs   = ram_area;
assign ram_addr = A[14:1];
assign ram_din  = cpu_dout;
assign ram_dsn  = dsn;
assign ram_we   = ram_area & ~rnw;

assign vcu_cs   = vcu_area;
assign vcu_addr = A[18:1];
assign vcu_dout = cpu_dout;
assign vcu_we   = vcu_area & ~rnw;
assign vcu_dsn  = dsn;

assign ioc_addr = A[3:1];
assign ioc_dout = cpu_dout[15:8]; // upper byte only (umask 0xFF00)
assign ioc_we   = ioc_area & ~rnw;

assign syt_addr = A[1];
assign syt_dout = cpu_dout[7:0];
assign syt_we   = syt_area & ~rnw;
assign syt_rd   = syt_area & rnw;

assign pal_addr = A[12:1];
assign cpu_addr_o = A[12:1];
assign pal_dout = cpu_dout;
assign pal_we   = ((pal_area) & ~rnw) ? ~dsn : 2'b00;
assign pal_dsn  = dsn;

// CPU data bus mux
reg [15:0] cpu_din;
always @(*) begin
    cpu_din = 16'hffff;
    if( rom_area ) cpu_din = main_data;
    if( ram_area ) cpu_din = ram_dout;
    if( vcu_area ) cpu_din = vcu_din;
    if( ioc_area ) cpu_din = { ioc_din, 8'hff }; // upper byte only
    if( pal_area ) cpu_din = pal_din;
end

// Interrupts: HOLD_LINE — latch on edge, clear on IACK cycle
// FC=7 && !ASn && RnW = interrupt acknowledge cycle (from gaiden pattern)
wire iack = (FC == 3'd7) & ~as_n & rnw;

// Tetris ROM vector table (verified from ROM $60-$7F):
//   Level 2 ($68): $0000_0616 — delayed VBL handler (vcu_intl)
//   Level 3 ($6C): $0000_0000 — NULL, not used
//   Level 4 ($70): $0000_05FA — main VBL handler (vcu_inth)
//   Level 5 ($74): $0000_0000 — NULL, not used
// 68000 autovector formula: Level N → (N+24)*4. Level 4→0x70, Level 2→0x68.
reg int4_held, int2_held;
reg vcu_inth_prev, vcu_intl_prev;

always @(posedge clk) begin
    if( rst ) begin
        int4_held <= 0;
        int2_held <= 0;
        vcu_inth_prev <= 0;
        vcu_intl_prev <= 0;
    end else begin
        vcu_inth_prev <= vcu_inth;
        vcu_intl_prev <= vcu_intl;
        if( vcu_inth & ~vcu_inth_prev ) int4_held <= 1;
        if( vcu_intl & ~vcu_intl_prev ) int2_held <= 1;
        if( iack ) begin
            int4_held <= 0;
            int2_held <= 0;
        end
    end
end

wire [2:0] ipln = int4_held ? ~3'd4 : int2_held ? ~3'd2 : 3'b111;

// DTACK generation
wire dtack_n;

wire bus_cs   = rom_area | ram_area;
wire bus_busy = (rom_area & ~main_ok) | (ram_area & ~ram_ok);

jtframe_68kdtack_cen #(.W(8), .WAIT1(1)) u_dtack(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .cpu_cen  ( cpu_cen   ),
    .cpu_cenb ( cpu_cenb  ),
    .bus_cs   ( bus_cs    ),
    .bus_busy ( bus_busy  ),
    .bus_legit( 1'b0      ),
    .bus_ack  ( 1'b0      ),
    .ASn      ( as_n      ),
    .DSn      ( dsn       ),
    .num      ( 7'd12     ), // 12MHz = 12/48
    .den      ( 8'd48     ),
    .DTACKn   ( dtack_n   ),
    .wait2    ( bus_cs    ),  // extra wait state when accessing SDRAM
    .wait3    ( 1'b0      ),
    .fave     (           ),
    .fworst   (           )
);

`ifdef SIMULATION
reg [31:0] main_diag_cycle;
reg [31:0] main_cen_cnt;
reg [31:0] main_rom_cnt, main_ram_cnt, main_vcu_cnt, main_ioc_cnt, main_pal_cnt, main_syt_cnt;
reg [31:0] main_vcu_rd_cnt, main_vcu_wrx_cnt;
reg [31:0] main_boot_cnt;
reg [31:0] main_periph_cnt;
reg [31:0] main_vram_rd_cnt, main_vram_wr_cnt, main_spram_wr_cnt;
reg [31:0] main_wr_cnt;
always @(posedge clk) begin
    if (rst) begin
        main_diag_cycle <= 0;
        main_cen_cnt <= 0;
        main_rom_cnt <= 0; main_ram_cnt <= 0; main_vcu_cnt <= 0;
        main_ioc_cnt <= 0; main_pal_cnt <= 0; main_syt_cnt <= 0;
        main_wr_cnt  <= 0;
        main_vcu_rd_cnt <= 0; main_vcu_wrx_cnt <= 0;
        main_boot_cnt <= 0;
        main_periph_cnt <= 0;
        main_vram_rd_cnt <= 0; main_vram_wr_cnt <= 0; main_spram_wr_cnt <= 0;
    end else begin
        main_diag_cycle <= main_diag_cycle + 1;
        if (cpu_cen) main_cen_cnt <= main_cen_cnt + 1;
        if (rom_area && cpu_cen) main_rom_cnt <= main_rom_cnt + 1;
        if (ram_area && cpu_cen) main_ram_cnt <= main_ram_cnt + 1;
        if (vcu_area && cpu_cen) main_vcu_cnt <= main_vcu_cnt + 1;
        if (ioc_area && cpu_cen) main_ioc_cnt <= main_ioc_cnt + 1;
        if (pal_area && cpu_cen) begin
            main_pal_cnt <= main_pal_cnt + 1;
            if (!rnw && main_pal_cnt < 3)
                $display("MAIN_PAL_WRITE! addr=%03X data=%04X dsn=%b cyc=%0d",
                         A[12:1], cpu_dout, dsn, main_diag_cycle);
        end
        if (syt_area && cpu_cen) main_syt_cnt <= main_syt_cnt + 1;
        if (!rnw && mem_acc && cpu_cen) main_wr_cnt <= main_wr_cnt + 1;

        // Track palette writes from main (writes only)
        if (pal_area && !rnw && mem_acc && cpu_cen && main_pal_cnt < 10)
            $display("MAIN_PAL_WR: addr=%03X data=%04X dsn=%b pal_we=%b cyc=%0d",
                     A[12:1], cpu_dout, dsn, pal_we, main_diag_cycle);
        // Also count palette writes separately
        if (pal_area && !rnw && mem_acc && cpu_cen && main_diag_cycle == 32'd200_000_000)
            $display("MAIN_PAL_WR_LATE: found a palette write at 200M!");

        // Track VCU writes after ROM load (cycle > 55M)
        if (vcu_area && !rnw && mem_acc && cpu_cen && main_diag_cycle > 32'd55_000_000 && main_vcu_cnt < 350)
            $display("MAIN_VCU_WR: A=%06X A18_1=%05X data=%04X dsn=%b cyc=%0d",
                     A, A[18:1], cpu_dout, dsn, main_diag_cycle);

        // Track peripheral writes (after any reset, first 200)
        if (!rnw && mem_acc && cpu_cen && !rom_area && !ram_area) begin
            if (main_pal_cnt == 0 || main_vcu_cnt < 20) // early in boot
                $display("MAIN_PERIPH_WR: A=%06X area:vcu=%b ioc=%b pal=%b syt=%b cyc=%0d data=%04X",
                         A, vcu_area, ioc_area, pal_area, syt_area, main_diag_cycle, cpu_dout);
        end

        // Track VCU reads in main.v
        if (vcu_area && rnw && mem_acc && cpu_cen && main_vcu_rd_cnt < 20) begin
            main_vcu_rd_cnt <= main_vcu_rd_cnt + 1;
            $display("MAIN_VCU_READ: A=%06X A18_1=%05X data=%04X dsn=%b cyc=%0d",
                     A, A[18:1], cpu_din, dsn, main_diag_cycle);
        end
        if (vcu_area && !rnw && mem_acc && cpu_cen && main_vcu_wrx_cnt < 20) begin
            main_vcu_wrx_cnt <= main_vcu_wrx_cnt + 1;
            $display("MAIN_VCU_WRITE_X: A=%06X A18_1=%05X data=%04X dsn=%b cyc=%0d",
                     A, A[18:1], cpu_dout, dsn, main_diag_cycle);
        end
        // Track FIRST 100 bus accesses after reset to see boot sequence
        if (mem_acc && cpu_cen && !rom_area && main_periph_cnt < 200) begin
            main_periph_cnt <= main_periph_cnt + 1;
            $display("MAIN_PERIPH: #%0d A=%06X rnw=%b area=R%bV%bI%bP%bS%b data_in=%04X data_out=%04X dsn=%b cyc=%0d",
                     main_periph_cnt, A, rnw, ram_area, vcu_area, ioc_area, pal_area, syt_area,
                     cpu_din, cpu_dout, dsn, main_diag_cycle);
        end
        // Track PC at periodic intervals
        // VRAM-specific read tracker (A[18:16]==000 = $400000-$40FFFF, separate from SPRAM)
        if (vcu_area && rnw && mem_acc && cpu_cen && A[18:16] == 3'b000 && main_vram_rd_cnt < 50) begin
            main_vram_rd_cnt <= main_vram_rd_cnt + 1;
            $display("VRAM_RD: #%0d A=%06X vcu_addr=%05X data=%04X dsn=%b cyc=%0d",
                     main_vram_rd_cnt, A, A[18:1], cpu_din, dsn, main_diag_cycle);
        end
        // VRAM write tracker (A[18:16]==000)
        if (vcu_area && ~rnw && mem_acc && cpu_cen && A[18:16] == 3'b000 && main_vram_wr_cnt < 10) begin
            main_vram_wr_cnt <= main_vram_wr_cnt + 1;
            $display("VRAM_WR: #%0d A=%06X vcu_addr=%05X data=%04X dsn=%b cyc=%0d",
                     main_vram_wr_cnt, A, A[18:1], cpu_dout, dsn, main_diag_cycle);
        end
        // SPRAM write tracker (A[18:16]==001 = $410000-$41FFFF)
        if (vcu_area && ~rnw && mem_acc && cpu_cen && A[18:16] == 3'b001 && main_spram_wr_cnt < 10) begin
            main_spram_wr_cnt <= main_spram_wr_cnt + 1;
            $display("SPRAM_WR: #%0d A=%06X vcu_addr=%05X data=%04X dsn=%b cyc=%0d",
                     main_spram_wr_cnt, A, A[18:1], cpu_dout, dsn, main_diag_cycle);
        end
        // Summary at cycle boundaries for VRAM diagnostics
        if (main_diag_cycle == 32'd45_000_000 || main_diag_cycle == 32'd55_000_000)
            $display("VRAM_DIAG: cyc=%0d vram_rd=%0d vram_wr=%0d spram_wr=%0d vcu_total=%0d",
                     main_diag_cycle, main_vram_rd_cnt, main_vram_wr_cnt, main_spram_wr_cnt, main_vcu_cnt);

        if (main_diag_cycle == 32'd30_000_000 || main_diag_cycle == 32'd40_000_000 ||
            main_diag_cycle == 32'd50_000_000)
            $display("MAIN_PC: A=%06X rnw=%b as_n=%b cyc=%0d", A, rnw, as_n, main_diag_cycle);
        // Log first 50 unique-ish PC values after download (cycle > 55M)
        // Trace VCU writes AFTER download (cyc>55M), show first 10
        if (vcu_area && !rnw && mem_acc && cpu_cen && main_diag_cycle > 32'd55_000_000 && main_boot_cnt < 10) begin
            main_boot_cnt <= main_boot_cnt + 1;
            $display("VCU_WR_POST: A18_1=%05X byte=%06X data=%04X dsn=%b cyc=%0d",
                     A[18:1], {A,1'b0}, cpu_dout, dsn, main_diag_cycle);
        end
        // Also track palette writes
        if (pal_area && !rnw && mem_acc && cpu_cen && main_diag_cycle > 32'd55_000_000 && main_pal_cnt < 10) begin
            $display("PAL_WR_POST: byte=%06X data=%04X dsn=%b cyc=%0d",
                     {A,1'b0}, cpu_dout, dsn, main_diag_cycle);
        end

        if (main_diag_cycle == 32'd100_000 || main_diag_cycle == 32'd1_000_000 ||
            main_diag_cycle == 32'd10_000_000 || main_diag_cycle == 32'd60_000_000 ||
            main_diag_cycle == 32'd100_000_000 || main_diag_cycle == 32'd200_000_000)
            $display("MAIN_DIAG: cyc=%0d cen=%0d as_n=%b A=%06X rnw=%b dtack=%b rst=%b ipln=%b rom=%0d ram=%0d vcu=%0d ioc=%0d pal=%0d syt=%0d wr=%0d",
                     main_diag_cycle, main_cen_cnt, as_n, A, rnw, dtack_n, rst, ipln,
                     main_rom_cnt, main_ram_cnt, main_vcu_cnt, main_ioc_cnt, main_pal_cnt, main_syt_cnt, main_wr_cnt);
    end
end

reg [7:0] pal_diag_cnt;
initial pal_diag_cnt = 0;
always @(posedge clk) begin
    if (pal_area && ~rnw && cpu_cen && main_diag_cycle > 54_000_000 && pal_diag_cnt < 200) begin
        $display("PAL_DATA: addr=%03X data=%04X cyc=%0d", A[12:1], cpu_dout, main_diag_cycle);
        pal_diag_cnt <= pal_diag_cnt + 1;
    end
end
`endif

jtframe_m68k u_cpu(
    .clk      ( clk       ),
    .rst      ( rst       ),
    .cpu_cen  ( cpu_cen   ),
    .cpu_cenb ( cpu_cenb  ),
    .oEdb     ( cpu_dout  ),
    .eab      ( A         ),
    .iEdb     ( cpu_din   ),
    .ASn      ( as_n      ),
    .LDSn     ( dsn[0]    ),
    .UDSn     ( dsn[1]    ),
    .eRWn     ( rnw       ),
    .DTACKn   ( dtack_n   ),
    .VPAn     ( 1'b0      ),  // autovector mode — all interrupts use autovectors
    .HALTn    ( 1'b1      ),
    .BERRn    ( 1'b1      ),
    .BRn      ( 1'b1      ),
    .BGACKn   ( 1'b1      ),
    .IPLn     ( ipln      ),
    .FC       ( FC        )
);

endmodule
