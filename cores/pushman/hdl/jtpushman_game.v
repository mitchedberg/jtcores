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

    Author: (JTCORES)
    Date: 2026-03-28

*/

module jtpushman_game(
    `include "jtframe_game_ports.svh"
    /* jtframe_mem_ports */
);
`include "mem_ports.inc"

    // Placeholder for PUSHMAN game logic
    assign video_rgb = 16'h0;
    assign video_en = 1'b0;
    assign game_led = 1'b0;

endmodule
