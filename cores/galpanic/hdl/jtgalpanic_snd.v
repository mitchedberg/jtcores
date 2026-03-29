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

module jtgalpanic_snd(
    input   rst,
    input   clk,

    input   [ 7:0] snd_latch,
    input          snd_stb,

    output reg [16:0] snd_addr,
    output reg        snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,

    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    input          sample,
    output reg    [ 7:0] debug_bus
);

assign snd_left  = 0;
assign snd_right = 0;

endmodule
