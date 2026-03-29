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

module jtwwfwfest_main(
    input           clk,
    input           clk_cpu,
    input           rst,

    // CPU interface
    output  [23:0]  cpu_addr,
    input   [15:0]  cpu_dout,
    output          cpu_we,

    // BRAM interface
    output          pal_we, vram_we, spr_we,
    input   [15:0]  pal_dout, vram_dout, spr_dout,

    // Video
    input           vblank,
    input   [9:0]   vdump,

    // SDRAM
    output          sdram_req,
    input           sdram_ack,
    output  [22:0]  sdram_addr,
    input   [15:0]  sdram_dout,

    // Sound
    output  [7:0]   snd_latch,

    // I/O
    input   [31:0]  input_data,
    input   [15:0]  dipsw
);

// TODO: Implement main CPU controller

endmodule
