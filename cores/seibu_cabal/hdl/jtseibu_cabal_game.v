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
    Date: 2026-03-28

*/

module jtseibu_cabal_game(
    `include "jtframe_game_ports.inc"
);

// Video output stubs
assign red      = 4'h0;
assign green    = 4'h0;
assign blue     = 4'h0;
assign dip_flip = 1'b0;
assign debug_view = 1'b0;

// Pixel clock: 48 MHz * some divider (standard Cabal: 27.164 MHz pixel clock / 2)
// For simplicity, use a standard frac_cen divider
jtframe_frac_cen #(.W(1), .WC(10)) u_pxlcen(
    .clk    ( clk           ),
    .n      ( 10'd27        ),
    .m      ( 10'd48        ),
    .cen    ( pxl2_cen      ),
    .cenb   (               )
);

jtframe_vtimer #(
    .VB_START   ( 9'd223         ),
    .VB_END     ( 9'd262         ),
    .VS_START   ( 9'd232         ),
    .HCNT_END   ( 9'd383         ),
    .HB_START   ( 9'd255         ),
    .HB_END     ( 9'd383         ),
    .HS_START   ( 9'd328         )
) u_vtimer(
    .clk        ( clk            ),
    .pxl_cen    ( pxl2_cen       ),
    .vdump      (                ),
    .vrender    (                ),
    .vrender1   (                ),
    .H          (                ),
    .Hinit      (                ),
    .Vinit      (                ),
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    .HS         ( HS             ),
    .VS         ( VS             )
);

// Stub: disable all memory access
assign main_addr  = 19'h0;
assign ram_addr   = 14'h0;
assign ram_we     = 1'b0;
assign ram_din    = 16'h0;
assign ram_dsn    = 2'b11;
assign ram_cs     = 1'b0;

assign pal_addr   = 11'h0;
assign pal_we     = 1'b0;
assign pal_din    = 16'h0;

assign vram_addr  = 12'h0;
assign vram_we    = 1'b0;
assign vram_din   = 16'h0;

assign obj_addr   = 20'h0;
assign obj_cs     = 1'b0;
assign tile_addr  = 20'h0;
assign tile_cs    = 1'b0;

endmodule
