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

    Author: (community)
    Date: 2026-03-28
*/

module jtdeco_funky_game(
    `include "jtframe_game_ports.inc"
);

// Stub implementation
assign rgb = 16'h0;
assign hsync = 1'b1;
assign vsync = 1'b1;
assign hblank = 1'b0;
assign vblank = 1'b0;

assign sdram_req = 1'b0;
assign sdram_wt = 1'b0;
assign sdram_ds = 2'b11;
assign sdram_addr = 23'h0;

assign rom_addr = 22'h0;
assign rom_cs = 1'b0;
assign rom_ok = 1'b1;

endmodule
