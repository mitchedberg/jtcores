/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: community
    Version: 1.0
    Date: 2026-03-28

*/

module jtkonami_xexex_game(
    `include "jtframe_game_ports.inc"
);

// CPU interface signals (will be connected from main module)
wire        cpu_rnw;
wire [1:0]  ram_dsn;

// CS signals from main module
wire pal_cs, spr_cs;

// BRAM write enables
wire [1:0] bram_we = {2{~cpu_rnw}} & ~ram_dsn;

assign pal_we = pal_cs ? bram_we : 2'b00;
assign spr_we = spr_cs ? bram_we : 2'b00;

// BRAM addresses (stub - no video module yet)
assign pal_addr = 13'h0;
assign spr_addr = 14'h0;

// Video stub - outputs
assign red   = 4'h0;
assign green = 4'h0;
assign blue  = 4'h0;

assign dip_flip   = 1'b0;
assign debug_view = 8'h0;

// SDRAM stub
assign ram_cs   = 1'b0;
assign ram_addr = 22'h0;
assign ram_dout = 16'h0000;
assign ram_we   = 1'b0;

assign rom_cs   = 1'b0;
assign rom_addr = 24'h0;

// Pixel clock - 48 MHz clock with fractional divider
// 48 MHz * 105 / 352 = 14.318181 MHz
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk    ( clk                   ),
    .n      ( 10'd105               ),
    .m      ( 10'd352               ),
    .cen    ( {pxl_cen, pxl2_cen}  ),
    .cenb   (                       )
);

// Video timing
jtframe_vtimer #(
    .VB_START   ( 9'd223            ),  // 224 visible lines
    .VB_END     ( 9'd261            ),  // 262 total lines
    .VS_START   ( 9'd231            ),  // vsync pulse
    .HCNT_END   ( 9'd455            ),  // 456 total pixels
    .HB_START   ( 9'd319            ),  // 320 visible pixels
    .HB_END     ( 9'd455            ),  // hblank to end
    .HS_START   ( 9'd360            )   // hsync pulse
) u_vtimer(
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .vdump      (                   ),
    .vrender    (                   ),
    .vrender1   (                   ),
    .H          (                   ),
    .Hinit      (                   ),
    .Vinit      (                   ),
    .LHBL       ( LHBL              ),
    .LVBL       ( LVBL              ),
    .HS         ( HS                ),
    .VS         ( VS                )
);

endmodule
