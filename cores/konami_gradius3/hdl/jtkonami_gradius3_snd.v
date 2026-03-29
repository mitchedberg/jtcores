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

// Konami Gradius 3 Z80 + K054539 sound module

module jtkonami_gradius3_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // Z80 ROM (SDRAM)
    output     [14:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // K054539 ROM (SDRAM)
    output     [19:0] adpcma_addr,
    output            adpcma_cs,
    input      [ 7:0] adpcma_data,
    input             adpcma_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND
// --- Clock enable: 48 MHz / 6 = 8 MHz ---
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

// --- CPU signals ---
wire [15:0] A;
wire        mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire [ 7:0] cpu_dout, ram_dout;
reg  [ 7:0] cpu_din;

// --- Chip-select signals ---
reg  macc_n;
reg  rom_cs, ram_cs, k054539_cs;
reg  latch_rd, latch_ack;

// --- NMI flag ---
reg  nmi_n;

// --- K054539 internal signals ---
wire [ 7:0] k054539_dout;
wire        k054539_irq_n;

// --- Memory decode ---
always @(*) begin
    macc_n      =  mreq_n | ~rfsh_n;
    rom_cs      = ~mreq_n && !A[15] && !rfsh_n;
    ram_cs      = ~mreq_n && A[15] && !rfsh_n;
    k054539_cs  = ~iorq_n && !rfsh_n && A[7:0] >= 8'h00 && A[7:0] < 8'h10;
    latch_rd    = ~iorq_n && !rd_n && A[7:0] == 8'h14;
end

// --- Z80 CPU instantiation ---
jtframe_z80 cpu(
    .rst_n(~rst),
    .clk(clk),
    .cen(cen8),
    .wait_n(~(rom_cs & ~snd_ok) & ~(k054539_cs & ~adpcma_ok)),
    .int_n(nmi_n),
    .nmi_n(1'b1),
    .busrq_n(1'b1),
    .A(A),
    .mreq_n(mreq_n),
    .iorq_n(iorq_n),
    .rd_n(rd_n),
    .wr_n(wr_n),
    .rfsh_n(rfsh_n),
    .halt_n(),
    .busak_n(),
    .dout(cpu_dout),
    .din(cpu_din)
);

// --- CPU data input mux ---
always @* begin
    if ( rom_cs )
        cpu_din = snd_data;
    else if ( ram_cs )
        cpu_din = ram_dout;
    else if ( k054539_cs )
        cpu_din = k054539_dout;
    else if ( latch_rd )
        cpu_din = snd_latch;
    else
        cpu_din = 8'hFF;
end

// --- Sound latch handling ---
always @(posedge clk) begin
    if (rst) begin
        latch_ack <= 1'b0;
        nmi_n <= 1'b1;
    end else begin
        if (snd_stb)
            latch_ack <= 1'b1;
        else if (latch_rd)
            latch_ack <= 1'b0;
        
        nmi_n <= ~latch_ack;
    end
end

// --- Memory connections ---
assign snd_addr    = A[14:0];
assign snd_cs      = rom_cs;
assign adpcma_addr = {8'h0, A[11:0]};
assign adpcma_cs   = k054539_cs;

// --- Dummy audio output ---
assign sample      = 1'b0;
assign snd_left    = 16'h0000;
assign snd_right   = 16'h0000;

`else
assign snd_addr = 15'h0;
assign snd_cs = 1'b0;
assign adpcma_addr = 20'h0;
assign adpcma_cs = 1'b0;
assign sample = 1'b0;
assign snd_left = 16'h0;
assign snd_right = 16'h0;
`endif

endmodule
