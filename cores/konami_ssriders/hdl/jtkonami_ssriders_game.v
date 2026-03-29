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

module jtkonami_ssriders_game(
    `include "jtframe_game_ports.inc"
);

// Inter-module wires
wire [ 7:0] snd_latch;
wire snd_stb;

// CS signals and RnW from main.v
wire spr_cs, pal_cs, vram0_cs, vram1_cs, vregs_cs;
wire cpu_rnw;

// BRAM write enables: active when CPU writes and BRAM is selected
wire [1:0] bram_we = {2{~cpu_rnw}};
assign spr_we   = spr_cs   ? bram_we : 2'b00;
assign pal_we   = pal_cs   ? bram_we : 2'b00;
assign vram0_we = vram0_cs ? bram_we : 2'b00;
assign vram1_we = vram1_cs ? bram_we : 2'b00;
assign vregs_we = vregs_cs ? bram_we : 2'b00;

// Video-side BRAM addresses (no video module yet — stub to zero)
assign spr_addr   = 0;
assign pal_addr   = 0;
assign vram0_addr = 0;
assign vram1_addr = 0;
assign vregs_addr = 0;

// Stub assignments — modules not yet instantiated
assign red        = 0;
assign green      = 0;
assign blue       = 0;
assign dip_flip   = 0;
assign debug_view = 0;

// Pixel clock: 48 MHz * 105 / 352 = 14.318181 MHz (pxl2_cen)
// pxl_cen = half of pxl2_cen = 7.159 MHz
// cen[0] = base rate (pxl2_cen), cen[1] = half rate (pxl_cen)
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk    ( clk                    ),
    .n      ( 10'd105                ),
    .m      ( 10'd352                ),
    .cen    ( {pxl_cen, pxl2_cen}   ),
    .cenb   (                        )
);

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

// Unused SDRAM buses
assign tile_cs     = 0;
assign tile_addr   = 0;
assign obj_cs      = 0;
assign obj_addr    = 0;

`ifndef NOMAIN
jtkonami_ssriders_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),

    // SDRAM ROM
    .main_addr  ( main_addr     ),
    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),

    // CPU bus → video BRAMs (CS signals; address driven by generated wrapper)
    .spr_cs     ( spr_cs        ),
    .pal_cs     ( pal_cs        ),
    .vram0_cs   ( vram0_cs      ),
    .vram1_cs   ( vram1_cs      ),
    .vregs_cs   ( vregs_cs      ),

    // Video RAM CPU-side read-back (from generated BRAM ports)
    .ms_dout    ( ms_dout       ),
    .mp_dout    ( mp_dout       ),
    .m0_dout    ( m0_dout       ),
    .m1_dout    ( m1_dout       ),
    .mr_dout    ( mr_dout       ),

    // I/O
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .dipsw      ( dipsw[15:0]   ),
    .dip_pause  ( dip_pause     ),

    // Sound latch
    .snd_latch  ( snd_latch     ),
    .snd_stb    ( snd_stb       )
);
`endif

`ifndef NOSOUND
jtkonami_ssriders_snd u_snd(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .snd_latch  ( snd_latch         ),
    .snd_stb    ( snd_stb           ),
    .snd_addr   ( snd_addr          ),
    .snd_cs     ( snd_cs            ),
    .snd_data   ( snd_data          ),
    .snd_ok     ( snd_ok            ),
    .adpcma_addr( adpcma_addr       ),
    .adpcma_cs  ( adpcma_cs         ),
    .adpcma_data( adpcma_data       ),
    .adpcma_ok  ( adpcma_ok         ),
    .snd_left   ( snd_left          ),
    .snd_right  ( snd_right         ),
    .sample     ( sample            ),
    .debug_bus  ( debug_bus         )
);
`else
assign snd_left    = 0;
assign snd_right   = 0;
assign sample      = 0;
assign snd_cs      = 0;
assign snd_addr    = 0;
assign adpcma_cs   = 0;
assign adpcma_addr = 0;
`endif

endmodule
