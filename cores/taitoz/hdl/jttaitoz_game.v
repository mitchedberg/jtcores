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

    Author: (c) 2025 JTCORES
*/

module jttaitoz_game(
    `include "jtframe_game_ports.inc"
);

// TODO: Implement Taito Z System core
// - TC0220IOC input/output controller
// - TC0140SYT sound bridge
// - 68000 main CPU at 12MHz
// - Z80 sound CPU at 4MHz
// - YM2610 @ 8MHz

assign red = 8'd0;
assign green = 8'd0;
assign blue = 8'd0;
assign HS = 1'b0;
assign VS = 1'b0;
assign LHBL = 1'b1;
assign LVBL = 1'b1;

assign main_addr = 17'd0;
assign main_dout = 16'd0;
assign main_cs = 1'b0;
assign main_rnw = 1'b1;

assign snd_addr = 17'd0;
assign snd_cs = 1'b0;

assign scr_addr = 19'd0;
assign scr_cs = 1'b0;

assign obj_addr = 20'd0;
assign obj_cs = 1'b0;

endmodule
