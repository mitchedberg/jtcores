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
    Date: 2026-03-28

*/

module jttaito_othunder_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// Stub module - minimal implementation for compilation
assign rgb = 16'h0;
assign hs = ~hs;
assign vs_o = vs;

assign snd = 1'b0;
assign snd_l = 1'b0;
assign snd_r = 1'b0;

assign rom_data = 16'h0;
assign rom_ok = 1'b1;

// SDRAM port stubs
assign ba0_dout = 16'h0;
assign ba0_dst = 1'b0;
assign ba0_ack = 1'b1;

assign ba1_dout = 16'h0;
assign ba1_dst = 1'b0;
assign ba1_ack = 1'b1;

assign ba2_dout = 16'h0;
assign ba2_dst = 1'b0;
assign ba2_ack = 1'b1;

assign ba3_dout = 16'h0;
assign ba3_dst = 1'b0;
assign ba3_ack = 1'b1;

endmodule
