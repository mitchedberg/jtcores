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

// Shadfrce Sound Module (Z80 + YM2610)
// Placeholder: NOSOUND stub

module jtshadfrce_snd(
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

// TODO: Implement YM2610 sound module for Shadfrce hardware
// This is a placeholder for future sound implementation

`else
// NOSOUND stub — all outputs driven to safe defaults
assign snd_left    = 16'd0;
assign snd_right   = 16'd0;
assign sample      = 1'b0;
assign snd_cs      = 1'b0;
assign snd_addr    = 17'd0;
assign adpcma_cs   = 1'b0;
assign adpcma_addr = 20'd0;
assign adpcmb_cs   = 1'b0;
assign adpcmb_addr = 24'd0;
`endif

endmodule
