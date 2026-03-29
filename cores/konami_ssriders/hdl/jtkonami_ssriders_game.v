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

    Author: Claude Code
    Date: 2026-03-28
*/

module jtkonami_ssriders_game(
    `include "jtframe_game_ports.inc"
);

// Stub assignments for memory buses
assign main_cs     = 0;
assign main_addr   = 0;
assign snd_cs      = 0;
assign snd_addr    = 0;
assign gfx_cs      = 0;
assign gfx_addr    = 0;
assign obj_cs      = 0;
assign obj_addr    = 0;

// Stub assignments for BRAM
assign spr_we   = 0;
assign pal_we   = 0;
assign vram0_we = 0;
assign vram1_we = 0;
assign vregs_we = 0;

assign spr_addr   = 0;
assign pal_addr   = 0;
assign vram0_addr = 0;
assign vram1_addr = 0;
assign vregs_addr = 0;

// Video stubs
assign red        = 0;
assign green      = 0;
assign blue       = 0;
assign LHBL       = 1;
assign LVBL       = 1;
assign HS         = 1;
assign VS         = 1;
assign dip_flip   = 0;
assign debug_view = 0;

// Sound stubs
assign snd_left   = 0;
assign snd_right  = 0;

endmodule
