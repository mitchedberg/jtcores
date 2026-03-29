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

// Raizing Z80 + YM2151 + OKI6295 sound module
// Z80 @ 4 MHz, clock enable generated from 48 MHz system clock
// YM2151 at 0xE000-0xE001, OKI6295 at 0xE010-0xE01D
// Z80 memory: 0x0000-0x7FFF ROM (32KB fixed), 0x8000-0xBFFF banked ROM, 0xC000-0xDFFF shared RAM

module jtraizing_snd(
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
    // OKI6295 ROM (SDRAM)
    output     [19:0] oki_addr,
    output            oki_cs,
    input      [ 7:0] oki_data,
    input             oki_ok,
    // Audio output
    output signed [15:0] snd,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// --- Stub implementation (TODO) ---
assign snd    = 16'd0;
assign sample = 1'b0;
assign snd_cs = 1'b0;
assign snd_addr = 16'd0;
assign oki_cs = 1'b0;
assign oki_addr = 20'd0;

`else
// NOSOUND stub — all outputs driven to safe defaults
assign snd      = 16'd0;
assign sample   = 1'b0;
assign snd_cs   = 1'b0;
assign snd_addr = 16'd0;
assign oki_cs   = 1'b0;
assign oki_addr = 20'd0;
`endif

endmodule
