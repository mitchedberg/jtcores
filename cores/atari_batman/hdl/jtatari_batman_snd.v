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
    Date: 29-3-2026 */

// Atari Batman sound module - NOSOUND stub

module jtatari_batman_snd(
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
    // ADPCM ROM (SDRAM)
    output     [20:0] adpcm_addr,
    output            adpcm_cs,
    input      [ 7:0] adpcm_data,
    input             adpcm_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// This is a placeholder for the actual sound implementation
// TODO: Add Z80 + YM2151 + OKI MSM6295 implementation

assign snd_left    = 16'd0;
assign snd_right   = 16'd0;
assign sample      = 1'b0;
assign snd_cs      = 1'b0;
assign snd_addr    = 16'd0;
assign adpcm_cs    = 1'b0;
assign adpcm_addr  = 21'd0;

`else
// NOSOUND stub — all outputs driven to safe defaults
assign snd_left    = 16'd0;
assign snd_right   = 16'd0;
assign sample      = 1'b0;
assign snd_cs      = 1'b0;
assign snd_addr    = 16'd0;
assign adpcm_cs    = 1'b0;
assign adpcm_addr  = 21'd0;
`endif

endmodule
