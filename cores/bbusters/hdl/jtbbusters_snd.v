/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2026-03-28 */

// Bbusters Z80 + YM2610 sound module
// Z80 @ 8 MHz, clock enable generated from 48 MHz system clock

module jtbbusters_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // Z80 ROM (SDRAM)
    output     [16:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // ADPCM-A ROM (SDRAM)
    output     [19:0] ym2610a_addr,
    output            ym2610a_cs,
    input      [ 7:0] ym2610a_data,
    input             ym2610a_ok,
    // ADPCM-B ROM (SDRAM)
    output     [19:0] ym2610b_addr,
    output            ym2610b_cs,
    input      [ 7:0] ym2610b_data,
    input             ym2610b_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// Clock enable: 48 MHz / 6 = 8 MHz
reg [2:0] cen_cnt;
reg       cen8;

always @(posedge clk) begin
    if (rst) begin
        cen_cnt <= 0;
        cen8    <= 0;
    end else begin
        cen8 <= 0;
        if (cen_cnt == 3'd5) begin
            cen_cnt <= 0;
            cen8    <= 1;
        end else begin
            cen_cnt <= cen_cnt + 3'd1;
        end
    end
end

// CPU signals
wire [15:0] A;
wire        mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire [ 7:0] cpu_dout, ram_dout;
reg  [ 7:0] cpu_din;

// Chip-select signals
reg  macc_n;
reg  rom_cs, ram_cs, bank_cs;
reg  ym_cs, latch_rd, latch_ack, bank_wr;

// Bank register
reg  [1:0] bank;

// NMI flag
reg  nmi_n;

// YM2610 internal signals
wire [ 7:0] ym_dout;
wire        ym_irq_n;
wire [19:0] ym_adpcma_addr;
wire [ 3:0] ym_adpcma_bank;
wire        ym_adpcma_roe_n;
wire [19:0] ym_adpcmb_addr;
wire        ym_adpcmb_roe_n;

// Memory decode
always @(*) begin
    macc_n  =  mreq_n | ~rfsh_n;
    rom_cs  = !macc_n && !A[15];
    ram_cs  = !macc_n &&  A[15] && A[14:9] == 6'b000000;
    bank_cs = !macc_n &&  A[15] && A[14:9] != 6'b000000;
end

// I/O decode
always @(*) begin
    ym_cs     = !iorq_n && (!rd_n || !wr_n) && A[7:2] == 6'b000001;
    latch_rd  = !iorq_n && !rd_n  && A[7:0] == 8'h08;
    latch_ack = !iorq_n && !wr_n  && A[7:0] == 8'h0C;
    bank_wr   = !iorq_n && !wr_n  && A[7:0] == 8'h00;
end

// ROM address mux
assign snd_addr = rom_cs  ? {2'b00,       A[14:0]} :
                  bank_cs ? {bank + 2'd1, A[14:0]} : 17'd0;
assign snd_cs   = rom_cs | bank_cs;

// ADPCM ROM wiring (A and B are both 20-bit for Bbusters)
assign ym2610a_addr = ym_adpcma_addr;
assign ym2610a_cs   = !ym_adpcma_roe_n;
assign ym2610b_addr = ym_adpcmb_addr;
assign ym2610b_cs   = !ym_adpcmb_roe_n;

// Bank register update
always @(posedge clk) begin
    if (rst)
        bank <= 2'd0;
    else if (bank_wr)
        bank <= cpu_dout[5:4];
end

// NMI: set on snd_stb, clear on latch_ack
always @(posedge clk) begin
    if (rst)
        nmi_n <= 1'b1;
    else if (snd_stb)
        nmi_n <= 1'b0;
    else if (latch_ack)
        nmi_n <= 1'b1;
end

// CPU data mux
always @(posedge clk) begin
    case (1'b1)
        rom_cs | bank_cs: cpu_din <= snd_data;
        ym_cs:            cpu_din <= ym_dout;
        latch_rd:         cpu_din <= snd_latch;
        ram_cs:           cpu_din <= ram_dout;
        default:          cpu_din <= 8'hff;
    endcase
end

// Z80 CPU
jtframe_sysz80 #(.RAM_AW(9), .RECOVERY(0)) u_cpu(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen8      ),
    .cpu_cen (           ),
    .int_n   ( ym_irq_n  ),
    .nmi_n   ( nmi_n     ),
    .busrq_n ( 1'b1      ),
    .m1_n    (           ),
    .mreq_n  ( mreq_n    ),
    .iorq_n  ( iorq_n    ),
    .rd_n    ( rd_n      ),
    .wr_n    ( wr_n      ),
    .rfsh_n  ( rfsh_n    ),
    .halt_n  (           ),
    .busak_n (           ),
    .A       ( A         ),
    .cpu_din ( cpu_din   ),
    .cpu_dout( cpu_dout  ),
    .ram_dout( ram_dout  ),
    .ram_cs  ( ram_cs    ),
    .rom_cs  ( snd_cs    ),
    .rom_ok  ( snd_ok    )
);

// YM2610 (11-bit ADPCM-B address -> 19-bit via bank)
jt10 u_ym2610(
    .rst          ( rst              ),
    .clk          ( clk              ),
    .cen          ( cen8             ),
    .din          ( cpu_dout         ),
    .addr         ( A[1:0]           ),
    .cs_n         ( ~ym_cs           ),
    .wr_n         ( wr_n             ),
    .dout         ( ym_dout          ),
    .irq_n        ( ym_irq_n         ),
    .adpcma_addr  ( ym_adpcma_addr   ),
    .adpcma_bank  ( ym_adpcma_bank   ),
    .adpcma_roe_n ( ym_adpcma_roe_n  ),
    .adpcma_data  ( ym2610a_data     ),
    .adpcmb_addr  ( ym_adpcmb_addr   ),
    .adpcmb_roe_n ( ym_adpcmb_roe_n  ),
    .adpcmb_data  ( ym2610b_data     ),
    .psg_A        (                  ),
    .psg_B        (                  ),
    .psg_C        (                  ),
    .fm_snd       (                  ),
    .psg_snd      (                  ),
    .snd_right    ( snd_right        ),
    .snd_left     ( snd_left         ),
    .snd_sample   ( sample           ),
    .ch_enable    ( 6'h3f            )
);

`else
// NOSOUND stub
assign snd_left    = 16'd0;
assign snd_right   = 16'd0;
assign sample      = 1'b0;
assign snd_cs      = 1'b0;
assign snd_addr    = 17'd0;
assign ym2610a_cs  = 1'b0;
assign ym2610a_addr = 20'd0;
assign ym2610b_cs  = 1'b0;
assign ym2610b_addr = 20'd0;
`endif

endmodule
