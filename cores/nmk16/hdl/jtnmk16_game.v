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

module jtnmk16_game(
    `include "jtframe_game_ports.inc"
);

// Pixel clock: ~6 MHz from 48 MHz (48/8=6)
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk    ( clk              ),
    .n      ( 10'd1            ),
    .m      ( 10'd8            ),
    .cen    ( {pxl_cen, pxl2_cen} ),
    .cenb   (                  )
);

jtframe_vtimer #(
    .VB_START   ( 9'd223       ),
    .VB_END     ( 9'd261       ),
    .VS_START   ( 9'd231       ),
    .HCNT_END   ( 9'd395       ),
    .HB_START   ( 9'd255       ),
    .HB_END     ( 9'd395       ),
    .HS_START   ( 9'd280       )
) u_vtimer(
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .vdump      (              ),
    .vrender    (              ),
    .vrender1   (              ),
    .H          (              ),
    .Hinit      (              ),
    .Vinit      (              ),
    .LHBL       ( LHBL         ),
    .LVBL       ( LVBL         ),
    .HS         ( HS           ),
    .VS         ( VS           )
);

// Stub assignments for unimplemented modules
assign red        = 0;
assign green      = 0;
assign blue       = 0;
assign dip_flip   = 0;
assign debug_view = 0;

// Unused SDRAM buses
assign tile_cs    = 0;
assign tile_addr  = 0;
assign obj_cs     = 0;
assign obj_addr   = 0;
assign gfx_cs     = 0;
assign gfx_addr   = 0;

`ifndef NOMAIN
jtnmk16_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),

    // SDRAM ROM
    .main_addr  ( main_addr     ),
    .main_cs    ( main_cs       ),
    .main_data  ( main_data     ),
    .main_ok    ( main_ok       ),

    // SDRAM Work RAM
    .ram_addr   ( ram_addr      ),
    .ram_we     ( ram_we        ),
    .ram_dsn    ( ram_dsn       ),
    .ram_din    ( ram_din       ),
    .ram_cs     ( ram_cs        ),
    .ram_data   ( ram_data      ),
    .ram_ok     ( ram_ok        )
);
`else
assign main_cs    = 0;
assign main_addr  = 0;
assign ram_cs     = 0;
assign ram_addr   = 0;
assign ram_we     = 0;
assign ram_dsn    = 2'b11;
assign ram_din    = 0;
`endif

`ifndef NOSOUND
jtnmk16_snd u_snd(
    .rst        ( rst           ),
    .clk        ( clk           ),

    // OKI interface
    .oki_wrdata ( ram_din[7:0]  ),
    .oki_wr     ( 1'b0          ),

    // OKI ROM (SDRAM)
    .oki_addr   ( oki_addr      ),
    .oki_cs     ( oki_cs        ),
    .oki_data   ( oki_data      ),
    .oki_ok     ( oki_ok        ),

    // Audio output
    .snd        ( snd           ),
    .sample     ( sample        )
);
`else
assign snd        = 0;
assign sample     = 0;
assign oki_cs     = 0;
assign oki_addr   = 0;
`endif

endmodule
