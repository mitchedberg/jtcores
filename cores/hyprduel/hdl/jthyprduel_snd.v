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
    Date: 28-3-2026 */

// Hyper Duel Z80 + YM2151 + OKI M6295 sound module
// Z80 @ 4 MHz, clock enable generated from 48 MHz system clock

module jthyprduel_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // Z80 ROM (SDRAM)
    output     [15:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// --- Clock enable: 48 MHz / 12 = 4 MHz ---
reg [3:0] cen_cnt;
reg       cen4;

always @(posedge clk) begin
    if (rst) begin
        cen_cnt <= 0;
        cen4    <= 0;
    end else begin
        cen4 <= 0;
        if (cen_cnt == 4'd11) begin
            cen_cnt <= 0;
            cen4    <= 1;
        end else begin
            cen_cnt <= cen_cnt + 4'd1;
        end
    end
end

// --- CPU signals ---
wire [15:0] A;
wire        mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire [ 7:0] cpu_dout, ram_dout;
reg  [ 7:0] cpu_din;

// --- Chip-select signals ---
reg  macc_n;
reg  rom_cs, ram_cs, ym2151_cs, oki_cs;
reg  latch_rd, latch_ack;

// --- NMI flag ---
reg  nmi_n;

// --- YM2151 internal signals ---
wire [ 7:0] ym2151_dout;
wire        ym2151_irq_n;

// --- OKI internal signals ---
wire [ 7:0] oki_dout;

// --- Memory decode (combinational) ---
always @(*) begin
    macc_n      =  mreq_n | ~rfsh_n;
    rom_cs      = !macc_n && !A[15];
    ram_cs      = !macc_n &&  A[15] && A[14:9] == 6'b000000; // 0x8000-0x81FF
    ym2151_cs   = !iorq_n && !rfsh_n && A[7:0] >= 8'h00 && A[7:0] < 8'h04;
    oki_cs      = !iorq_n && !rfsh_n && A[7:0] >= 8'h04 && A[7:0] < 8'h08;
    latch_rd    = !iorq_n && !rd_n  && A[7:0] == 8'h08;
end

// --- ROM address mux ---
assign snd_addr = rom_cs ? A[15:0] : 16'd0;
assign snd_cs   = rom_cs;

// --- CPU data mux (registered, matching psikyo pattern) ---
always @(posedge clk) begin
    case (1'b1)
        rom_cs:     cpu_din <= snd_data;
        ym2151_cs:  cpu_din <= ym2151_dout;
        oki_cs:     cpu_din <= oki_dout;
        latch_rd:   cpu_din <= snd_latch;
        ram_cs:     cpu_din <= ram_dout;
        default:    cpu_din <= 8'hff;
    endcase
end

// --- NMI: set on snd_stb, clear on latch_rd ---
always @(posedge clk) begin
    if (rst)
        nmi_n <= 1'b1;
    else if (snd_stb)
        nmi_n <= 1'b0;
    else if (latch_rd)
        nmi_n <= 1'b1;
end

// --- Z80 CPU ---
jtframe_sysz80 #(.RAM_AW(9), .RECOVERY(0)) u_cpu(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen4      ),
    .cpu_cen (           ),
    .int_n   ( ym2151_irq_n ),
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

// --- Dummy YM2151 output ---
assign ym2151_dout = 8'h00;
assign ym2151_irq_n = 1'b1;

// --- Dummy OKI output ---
assign oki_dout = 8'h00;

// --- Audio output (stub) ---
assign snd_left    = 16'h0000;
assign snd_right   = 16'h0000;
assign sample      = 1'b0;

`else
// NOSOUND stub — all outputs driven to safe defaults
assign snd_left    = 16'd0;
assign snd_right   = 16'd0;
assign sample      = 1'b0;
assign snd_cs      = 1'b0;
assign snd_addr    = 16'd0;
`endif

endmodule
