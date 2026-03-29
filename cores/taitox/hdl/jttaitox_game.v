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
    Date: 28-3-2026 */

module jttaitox_game(
    `include "jtframe_game_ports.inc"
);

// Pixel clock generation: 48MHz / 8 = 6MHz, with 2x clock
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk  ( clk ), .n ( 10'd1 ), .m ( 10'd8 ),
    .cen  ( {pxl_cen, pxl2_cen} ), .cenb ()
);

// Video timing generator
jtframe_vtimer #(
    .VB_START(9'd239), .VB_END(9'd261), .VS_START(9'd247),
    .HCNT_END(9'd511), .HB_START(9'd383), .HB_END(9'd511), .HS_START(9'd400)
) u_vtimer(
    .clk(clk), .pxl_cen(pxl_cen),
    .vdump(), .vrender(), .vrender1(), .H(), .Hinit(), .Vinit(),
    .LHBL(LHBL), .LVBL(LVBL), .HS(HS), .VS(VS)
);

// Main CPU (68000) - signals declared in jtframe_game_ports.inc

wire [15:0] pal_dout, spry_dout, sprobj_dout;

`ifndef NOMAIN
jttaitox_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .LVBL           ( LVBL          ),

    .main_addr      ( main_addr     ),
    .main_cs        ( main_cs       ),
    .main_data      ( main_data     ),
    .main_ok        ( main_ok       ),

    .ram_addr       ( ram_addr      ),
    .ram_we         ( ram_we        ),
    .ram_dsn        ( ram_dsn       ),
    .ram_dout       ( ram_din       ),
    .cpu_rnw        (               ),
    .ram_cs         ( ram_cs        ),
    .ram_data       ( ram_data      ),
    .ram_ok         ( ram_ok        ),

    .pal_cs         (               ),
    .spry_cs        (               ),
    .sprobj_cs      (               ),

    .pal_dout       ( pal_dout      ),
    .spry_dout      ( spry_dout     ),
    .sprobj_dout    ( sprobj_dout   ),

    .joystick1      ( joystick1[5:0]),
    .joystick2      ( joystick2[5:0]),
    .dipsw          ( dipsw[15:0]   ),
    .dip_pause      ( dip_pause     )
);
`endif

// Sound CPU (Z80 + YM2610) - signals declared in jtframe_game_ports.inc

`ifndef NOSOUND
jttaitox_snd u_snd(
    .rst            ( rst           ),
    .clk            ( clk           ),

    .snd_latch      ( 8'h0          ),
    .snd_stb        ( 1'b0          ),

    .snd_addr       ( snd_addr      ),
    .snd_cs         ( snd_cs        ),
    .snd_data       ( snd_data      ),
    .snd_ok         ( snd_ok        ),

    .adpcma_addr    ( adpcma_addr   ),
    .adpcma_cs      ( adpcma_cs     ),
    .adpcma_data    ( adpcma_data   ),
    .adpcma_ok      ( adpcma_ok     ),

    .adpcmb_addr    ( adpcmb_addr   ),
    .adpcmb_cs      ( adpcmb_cs     ),
    .adpcmb_data    ( adpcmb_data   ),
    .adpcmb_ok      ( adpcmb_ok     ),

    .snd_left       ( snd_left      ),
    .snd_right      ( snd_right     ),
    .sample         ( sample        ),

    .debug_bus      ( debug_bus     )
);
`endif

// Graphics (stub for now) - signals declared in jtframe_game_ports.inc

// Video output (black)
assign red      = 5'h0;
assign green    = 5'h0;
assign blue     = 5'h0;

// DIP switches
assign dip_flip = 1'b0;

// Debug
assign debug_view = 8'h0;

endmodule
