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

module jtdeco_tumble_game(
    `include "jtframe_game_ports.inc"
);

// Stub: minimal implementation to allow jtframe mem to generate memory ports
wire [ 7:0] red, green, blue;
wire        dip_flip, debug_view;

// Video timing stub (required but not functional yet)
jtframe_vtimer #(
    .VB_START   ( 9'd223          ),  // 224 visible lines (0-223)
    .VB_END     ( 9'd261          ),  // 262 total lines (0-261)
    .VS_START   ( 9'd231          ),  // vsync pulse
    .HCNT_END   ( 9'd455          ),  // 456 total pixels (0-455)
    .HB_START   ( 9'd319          ),  // 320 visible pixels (0-319)
    .HB_END     ( 9'd455          ),  // hblank to end of line
    .HS_START   ( 9'd360          )   // hsync pulse
) u_vtimer(
    .clk        ( clk             ),
    .pxl_cen    ( pxl_cen         ),
    .vdump      (                 ),
    .vrender    (                 ),
    .vrender1   (                 ),
    .H          (                 ),
    .Hinit      (                 ),
    .Vinit      (                 ),
    .LHBL       ( LHBL            ),
    .LVBL       ( LVBL            ),
    .HS         ( HS              ),
    .VS         ( VS              )
);

// BRAM write enables stub
wire [1:0] bram_we = 2'b00;
assign pal_we   = 2'b00;
assign spr_we   = 2'b00;
assign vram0_we = 2'b00;
assign vram1_we = 2'b00;
assign vscr0_we = 2'b00;
assign vscr1_we = 2'b00;

// BRAM address stubs
assign pal_addr   = 0;
assign spr_addr   = 0;
assign vram0_addr = 0;
assign vram1_addr = 0;
assign vscr0_addr = 0;
assign vscr1_addr = 0;

// Video output stub
assign red      = 0;
assign green    = 0;
assign blue     = 0;
assign dip_flip = 0;
assign debug_view = 0;

// SDRAM stubs (no video chips yet)
assign tile_cs  = 0;
assign tile_addr = 0;
assign obj_cs   = 0;
assign obj_addr = 0;

// Main CPU stub (disabled for now)
// Later: jtdeco_tumble_main instantiation

endmodule
/* jtframe_mem_ports */
