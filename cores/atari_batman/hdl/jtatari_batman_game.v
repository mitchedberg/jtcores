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

assign snd_rst          = ~rst;
assign debug_view       = 8'd0;
assign dip_flip         = 1'b0;
assign gfx_en           = ~debug_bus[0];

endmodule
