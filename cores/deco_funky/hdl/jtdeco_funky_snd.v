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

// Deco Funky Jet HuC6280 + YM2151 + OKI sound module

module jtdeco_funky_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // Sound ROM (SDRAM)
    output     [16:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // Audio output
    output signed [15:0] left,
    output signed [15:0] right
);

`ifndef NOSOUND

// Stub implementation - just drive outputs to safe defaults
assign snd_addr = 17'd0;
assign snd_cs   = 1'b0;
assign left     = 16'd0;
assign right    = 16'd0;

`else
// NOSOUND stub
assign snd_addr = 17'd0;
assign snd_cs   = 1'b0;
assign left     = 16'd0;
assign right    = 16'd0;
`endif

endmodule
