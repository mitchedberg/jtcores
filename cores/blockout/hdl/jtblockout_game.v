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

    Author: JTCORES Team
    Date: 2025-03-28
*/

module jtblockout_game(
    `include "jtframe_game_ports.inc"
);

// Write enable for BRAMs (derived from CPU write and SDRAM dsn)
wire [1:0] bram_we = {2{~cpu_rnw}} & ~ram_dsn;

// Palette BRAM write enable
assign pal_we = pal_cs ? bram_we : 2'b00;

// Video-side BRAM addresses (no video module yet — stub to zero)
assign pal_addr = 0;

// Stub assignments — modules not yet instantiated
assign red      = 0;
assign green    = 0;
assign blue     = 0;

// Unused SDRAM buses
assign main_cs = 0;
assign snd_cs = 0;
assign adpcm_cs = 0;

endmodule
