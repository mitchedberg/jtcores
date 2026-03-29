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

// Xenophobe 68000 DAC sound module
// 68000 @ 12MHz, clock enable generated from 48 MHz system clock

module jtxenophob_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // 68K ROM (SDRAM)
    output     [16:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // Audio output (DAC stub)
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// --- Clock enable: 48 MHz / 4 = 12 MHz ---
reg [1:0] cen_cnt;
reg       cen12;

always @(posedge clk) begin
    if (rst) begin
        cen_cnt <= 0;
        cen12   <= 0;
    end else begin
        cen12 <= 0;
        if (cen_cnt == 2'd3) begin
            cen_cnt <= 0;
            cen12   <= 1;
        end else begin
            cen_cnt <= cen_cnt + 2'd1;
        end
    end
end

// --- Stub audio output ---
assign snd_left  = 16'h0000;
assign snd_right = 16'h0000;
assign sample    = 1'b0;
assign snd_addr  = 17'h0;
assign snd_cs    = 1'b0;

`else
// NOSOUND mode
assign snd_left  = 16'h0000;
assign snd_right = 16'h0000;
assign sample    = 1'b0;
`endif

endmodule
