/*  This file is part of JT_CORES.
    JT_CORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_CORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_CORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: jotego
    Version: 1.0
    Date: 27-March-2026

*/

module jtwwfwfest_snd(
    input           clk,
    input           clk_snd,
    input           rst,

    // From main CPU
    input   [7:0]   snd_latch,

    // SDRAM
    output          sdram_req,
    input           sdram_ack,
    output  [22:0]  sdram_addr,
    input   [15:0]  sdram_dout,

    // Audio output (mono summed)
    output  signed [15:0] snd
);

// TODO: Implement sound controller (Z80 + YM2151 + MSM6295)

endmodule
