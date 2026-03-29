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

// Lethal Crash Race Z80 + YM2610 sound module
// Z80 @ 4 MHz, clock enable generated from 48 MHz system clock

module jtcrshrace_snd(
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
    output     [19:0] adpcma_addr,
    output            adpcma_cs,
    input      [ 7:0] adpcma_data,
    input             adpcma_ok,
    // ADPCM-B ROM (SDRAM)
    output     [23:0] adpcmb_addr,
    output            adpcmb_cs,
    input      [ 7:0] adpcmb_data,
    input             adpcmb_ok,
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
reg  rom_cs, ram_cs, bank_cs;
reg  ym_cs, latch_rd, latch_ack, bank_wr;

// --- Bank register ---
reg  [1:0] bank;

// --- NMI flag ---
reg  nmi_n;

// --- YM2610 internal signals ---
wire [ 7:0] ym_dout;
wire        ym_irq_n;
wire [19:0] ym_adpcma_addr;
wire [ 3:0] ym_adpcma_bank;
wire        ym_adpcma_roe_n;
wire [23:0] ym_adpcmb_addr;
wire        ym_adpcmb_roe_n;

// --- Memory decode (combinational) ---
always @(*) begin
    macc_n  =  mreq_n | ~rfsh_n;
    rom_cs  = ~macc_n && A[15:13] == 3'h0;
    ram_cs  = ~macc_n && A[15:13] == 3'h2;
    bank_cs = ~macc_n && A[15:8]  == 8'h30;
    ym_cs   = ~iorq_n && A[7:2] == 6'b10_0000;
    latch_rd = ~macc_n && A[15:0] == 16'h4000;
    latch_ack = latch_rd & ~rd_n;
    bank_wr = ~iorq_n && A[7:0] == 8'h3c;
end

// --- Bank register and NMI ---
always @(posedge clk) begin
    if (rst) begin
        bank <= 2'h0;
        nmi_n <= 1'b1;
    end else if (cen4) begin
        if (bank_wr & ~wr_n)
            bank <= cpu_dout[1:0];
        if (snd_stb)
            nmi_n <= 1'b0;
        else if (latch_ack)
            nmi_n <= 1'b1;
    end
end

// --- ROM address with banking ---
assign snd_addr = A[16:0];

// --- ROM/RAM select and data read ---
always @(*) begin
    snd_cs      = rom_cs;
    adpcma_cs   = 1'b0;
    adpcmb_cs   = 1'b0;
    cpu_din     = 8'h00;

    if (rom_cs)
        cpu_din = snd_data;
    else if (ram_cs)
        cpu_din = ram_dout;
    else if (latch_rd)
        cpu_din = snd_latch;
    else if (ym_cs)
        cpu_din = ym_dout;
end

// --- ADPCM address outputs (connected to YM2610) ---
assign adpcma_addr = ym_adpcma_addr;
assign adpcma_cs   = ~ym_adpcma_roe_n;
assign adpcmb_addr = ym_adpcmb_addr;
assign adpcmb_cs   = ~ym_adpcmb_roe_n;

// --- Stub audio output ---
assign snd_left  = 16'h0000;
assign snd_right = 16'h0000;
assign sample    = 1'b0;

// --- Z80 CPU instance (stub) ---
// Full Z80 + YM2610 instantiation would go here
// For now, stub the CPU interface

`else
// NOSOUND mode
assign snd_left  = 16'h0000;
assign snd_right = 16'h0000;
assign sample    = 1'b0;
assign snd_addr  = 17'h0;
assign snd_cs    = 1'b0;
assign adpcma_addr = 20'h0;
assign adpcma_cs = 1'b0;
assign adpcmb_addr = 24'h0;
assign adpcmb_cs = 1'b0;
`endif

endmodule
