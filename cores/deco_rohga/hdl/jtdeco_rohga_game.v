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

    Author: JTCORES team.

*/

module jtdeco_rohga_game(
    `include "jtframe_game_ports.inc"
);

assign gg_red   = 12'h0;
assign gg_green = 12'h0;
assign gg_blue  = 12'h0;
assign gg_en    = 1'b0;
assign gg_hs    = 1'b0;
assign gg_vs    = 1'b0;
assign gg_f1    = 1'b0;

assign snd_left  = 16'h0;
assign snd_right = 16'h0;
assign snd_sample = 1'b0;

assign led      = 1'b0;
assign dip_flip = 8'h0;

endmodule
/* jtframe_mem_ports */
