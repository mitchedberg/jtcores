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

// Konami Bishi Bashi YMZ280B sound module

module jtbishi_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // ROM (SDRAM) - for future expansion
    output     [14:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // Secondary ROM for sound effects
    output     [11:0] snd2_addr,
    output            snd2_cs,
    input      [ 7:0] snd2_data,
    input             snd2_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// --- Dummy implementation ---
// The YMZ280B is typically on-board in Bishi systems
// This stub handles basic ROM access if needed

reg [11:0] rom_addr;

// Simple ROM address counter for testing
always @(posedge clk) begin
    if (rst) begin
        rom_addr <= 12'h0;
    end else if (snd_stb) begin
        rom_addr <= {snd_latch[3:0], 8'h0};
    end
end

// --- Memory connections ---
assign snd_addr    = rom_addr[14:0];
assign snd_cs      = 1'b0;  // ROM not used in this stub
assign snd2_addr   = rom_addr;
assign snd2_cs     = 1'b0;  // ROM not used in this stub

// --- Dummy audio output ---
assign sample      = 1'b0;
assign snd_left    = 16'h0000;
assign snd_right   = 16'h0000;

`else
assign snd_addr = 15'h0;
assign snd_cs = 1'b0;
assign snd2_addr = 12'h0;
assign snd2_cs = 1'b0;
assign sample = 1'b0;
assign snd_left = 16'h0;
assign snd_right = 16'h0;
`endif

endmodule
