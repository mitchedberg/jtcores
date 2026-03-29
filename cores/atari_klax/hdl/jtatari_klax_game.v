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

`default_nettype none

`default_nettype none

module jtatari_klax_game #(
    parameter CORENAME="JTATARI_KLAX",
    parameter CLK96=1
) (
    `include "jtframe_game_ports.inc"
);

// Placeholder: connect outputs to 0 to prevent linting errors
assign pxl_cen      = 1'b0;
assign pxl2_cen     = 1'b0;
assign red          = 4'h0;
assign green        = 4'h0;
assign blue         = 4'h0;
`ifdef JTFRAME_STEREO
assign snd_left     = 16'h0;
assign snd_right    = 16'h0;
`else
assign snd           = 1'b0;
`endif
assign sample       = 1'b0;

endmodule
