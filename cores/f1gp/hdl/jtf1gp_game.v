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

    Author: jotego
    Version: 1.0
    Date: 28.3.2026

*/

module jtf1gp_game(
    `include "jtframe_game_ports.inc"
);

    // Stub assignments - modules not yet instantiated
    assign red        = 0;
    assign green      = 0;
    assign blue       = 0;
    assign dip_flip   = 0;
    assign debug_view = 0;

    // BRAM write enables
    wire [1:0] bram_we = {2{~cpu_rnw}} & ~ram_dsn;
    assign pal_we   = pal_cs   ? bram_we : 2'b00;
    assign vram0_we = vram0_cs ? bram_we : 2'b00;
    assign vram1_we = vram1_cs ? bram_we : 2'b00;

    // BRAM read addresses (video-side, stub to zero)
    assign pal_addr   = 0;
    assign vram0_addr = 0;
    assign vram1_addr = 0;

endmodule
