// Taito B System — Sound subsystem
// Z80 @ 4MHz + YM2610 @ 8MHz
// Sources: MAME taito_b.cpp sound memory map, gaiden/wwfss sound.v patterns

module jttaitob_sound(
    input             rst,
    input             clk,
    input             cen4,      // 4 MHz Z80 clock enable
    // TC0140SYT interface
    input      [ 1:0] syt_addr,
    input      [ 7:0] syt_din,
    output     [ 7:0] syt_dout,
    input             syt_we,
    input             syt_rd,
    // ROM
    output     [15:0] rom_addr,
    output reg        rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,
    // ADPCM ROM
    output     [18:0] pcm_addr,
    output            pcm_cs,
    input      [ 7:0] pcm_data,
    input             pcm_ok,
    // Sound output
    output signed [15:0] fm_l, fm_r,
    output        [ 9:0] psg,
    input         [ 7:0] debug_bus
);

wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout;
wire        nmi_n;
reg         sub_rst;

// Address decode
wire        rom_area = ~A[15] | (~A[14] & ~A[13]); // 0000-5FFF (could extend)
wire        ram_cs   = A[15:13] == 3'b110;          // C000-DFFF
wire        ym_cs    = A[15:13] == 3'b111 & A[12:2] == 0; // E000-E003
wire        syt_cs   = A[15:0] == 16'hE200 | A[15:0] == 16'hE201;
wire        bank_cs  = A[15:0] == 16'hF200;

// ROM banking
reg [2:0] rom_bank;
assign rom_addr = A[15] ? { rom_bank, A[13:0] } : { 2'b0, A[13:0] };

always @(posedge clk) begin
    if( rst ) rom_bank <= 0;
    else if( bank_cs & ~wr_n ) rom_bank <= cpu_dout[2:0];
end

always @(*) begin
    rom_cs = rom_area & ~mreq_n & rfsh_n;
end

// Data bus mux
reg [7:0] din;
always @(*) begin
    din = 8'hff;
    if( rom_cs  ) din = rom_data;
    if( ram_cs  ) din = ram_dout;
    if( ym_cs   ) din = fm_dout;
    if( syt_cs  ) din = syt_dout;
end

// Z80 CPU with built-in RAM and ROM wait
jtframe_sysz80 #(.RAM_AW(13)) u_cpu(
    .rst_n    ( ~rst       ),
    .clk      ( clk        ),
    .cen      ( cen4       ),
    .cpu_cen  (            ),
    .int_n    ( int_n      ),
    .nmi_n    ( nmi_n      ),
    .busrq_n  ( 1'b1       ),
    .m1_n     ( m1_n       ),
    .mreq_n   ( mreq_n     ),
    .iorq_n   ( iorq_n     ),
    .rd_n     ( rd_n       ),
    .wr_n     ( wr_n       ),
    .rfsh_n   ( rfsh_n     ),
    .halt_n   (            ),
    .busak_n  (            ),
    .A        ( A          ),
    .cpu_din  ( din        ),
    .cpu_dout ( cpu_dout   ),
    .ram_dout ( ram_dout   ),
    .ram_cs   ( ram_cs     ),
    .rom_cs   ( rom_cs     ),
    .rom_ok   ( rom_ok     )
);

// TC0140SYT slave side
wire [7:0] syt_dout;
tc0140syt u_syt(
    .clk      ( clk        ),
    .rst      ( rst        ),
    .main_addr( syt_addr   ),
    .main_din ( syt_din    ),
    .main_dout( /* main reads handled externally */ ),
    .main_we  ( syt_we     ),
    .main_rd  ( syt_rd     ),
    .sub_addr ( { 1'b0, A[0] } ),
    .sub_din  ( cpu_dout   ),
    .sub_dout ( syt_dout   ),
    .sub_we   ( syt_cs & ~wr_n ),
    .sub_rd   ( syt_cs & ~rd_n ),
    .nmi_n    ( nmi_n      ),
    .sub_rst  ( sub_rst    )
);

// YM2610 (jt10)
wire [7:0] fm_dout;
wire       int_n;

jt10 u_fm(
    .rst      ( rst | sub_rst ),
    .clk      ( clk        ),
    .cen      ( cen4       ),  // YM2610 at 8MHz would need cen8, using cen4 for now
    .din      ( cpu_dout   ),
    .addr     ( A[1:0]     ),
    .cs_n     ( ~ym_cs     ),
    .wr_n     ( wr_n       ),
    .dout     ( fm_dout    ),
    .irq_n    ( int_n      ),
    .snd_left ( fm_l       ),
    .snd_right( fm_r       ),
    // ADPCM ROM interface
    .adpcma_addr( pcm_addr ),
    .adpcma_cs  ( pcm_cs   ),
    .adpcma_data( pcm_data ),
    .adpcma_ok  ( pcm_ok   ),
    // Unused ports
    .adpcmb_addr(          ),
    .adpcmb_cs  (          ),
    .adpcmb_data( 8'd0     ),
    .adpcmb_ok  ( 1'b1     ),
    .psg_snd  ( psg        ),
    .debug_view(           )
);

endmodule
