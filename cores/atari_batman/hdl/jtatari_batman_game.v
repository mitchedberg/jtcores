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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 28-03-2026 */

module jtatari_batman_game(
    `include "jtframe_game_ports.inc"
);

wire        snd_rst;
wire [7:0]  snd_latch;

// Stub wires for memory ports
wire [11:0] spr_addr;
wire [15:0] spr_dout, main_dout, main_ram_din, main_ram_dout, ram_din, pal_dout;
wire [ 1:0] main_ram_we, pal_we, spr_we;
wire [11:0] pal_addr;
wire        sample, mute;

assign snd_rst          = ~rst;
assign debug_view       = 8'd0;
assign dip_flip         = 1'b0;

endmodule
