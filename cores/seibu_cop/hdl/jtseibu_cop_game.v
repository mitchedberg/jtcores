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

module jtseibu_cop_game(
    `include "jtframe_game_ports.inc"
);

// Pixel clock divider for Seibu COP (27.164 MHz nominal)
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk    ( clk                    ),
    .n      ( 10'd44                 ),  // 24MHz * 44 / 39 = 27.03 MHz
    .m      ( 10'd39                 ),
    .cen    ( {pxl_cen, pxl2_cen}   ),
    .cenb   (                        )
);

jtframe_vtimer #(
    .VB_START   ( 9'd223          ),  // 224 visible lines
    .VB_END     ( 9'd261          ),  // 262 total lines
    .VS_START   ( 9'd231          ),  // vsync pulse
    .HCNT_END   ( 9'd455          ),  // 456 total pixels
    .HB_START   ( 9'd319          ),  // 320 visible pixels
    .HB_END     ( 9'd455          ),
    .HS_START   ( 9'd360          )
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

// BRAM write enables - will be driven by main CPU
wire [1:0] bram_we = {2{~cpu_rnw}} & ~ram_dsn;
assign pal_we   = pal_cs   ? bram_we : 2'b00;
assign vram_we  = vram_cs  ? bram_we : 2'b00;
assign obj_we   = obj_cs   ? bram_we : 2'b00;

// Stubs: video module not yet implemented
assign red      = 0;
assign green    = 0;
assign blue     = 0;
assign dip_flip = 0;
assign debug_view = 0;

// BRAM addresses from video module (stub)
assign pal_addr  = 0;
assign vram_addr = 0;
assign obj_addr  = 0;

// SDRAM bus stubs
assign gfx_cs    = 0;
assign gfx_addr  = 0;

`ifndef NOMAIN
jtseibu_cop_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),

    // SDRAM ROM
    .main_addr  ( main_addr     ),
    .main_dout  ( main_dout     ),

    // Sound interface
    .snd_latch  (               ),
    .snd_stb    (               ),

    // CPU RAM
    .ram_addr   ( ram_addr      ),
    .ram_din    ( ram_din       ),
    .ram_dout   ( ram_dout      ),
    .ram_we     ( ram_we        ),
    .ram_dsn    ( ram_dsn       ),

    // BRAM: Palette, VRAM, OBJ
    .pal_addr   ( pal_addr      ),
    .pal_cs     ( pal_cs        ),
    .vram_addr  ( vram_addr     ),
    .vram_cs    ( vram_cs       ),
    .obj_addr   ( obj_addr      ),
    .obj_cs     ( obj_cs        ),

    // BRAM read port
    .mp_dout    ( mp_dout       ),
    .mv_dout    ( mv_dout       ),
    .mo_dout    ( mo_dout       ),

    // Input
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .buttons    ( buttons       ),
    .coin_input ( coin_input    ),
    .service    ( service       ),

    // Debug
    .debug      ( debug[7:0]    )
);
`endif

`ifndef NOSND
jtseibu_cop_snd u_snd(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk6       ( clk6          ),

    // Sound ROM
    .snd_addr   ( snd_addr      ),
    .snd_dout   ( snd_dout      ),

    // Left/Right audio
    .left       ( left          ),
    .right      ( right         )
);
`endif

endmodule
