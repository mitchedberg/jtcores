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

module jtdeco_cninja_game(
    `include "jtframe_game_ports.inc"
);

// Inter-module wires
wire [ 7:0] snd_latch;
wire snd_stb;

// CS signals and RnW from main.v
wire pal_cs, vram0_cs, vram1_cs, vram2_cs, vram3_cs, spr_cs;
wire cpu_rnw;

// BRAM write enables: active when CPU writes and BRAM is selected
wire [1:0] bram_we = {2{~cpu_rnw}} & ~dsn;
assign pal_we   = pal_cs   ? bram_we : 2'b00;
assign vram0_we = vram0_cs ? bram_we : 2'b00;
assign vram1_we = vram1_cs ? bram_we : 2'b00;
assign vram2_we = vram2_cs ? bram_we : 2'b00;
assign vram3_we = vram3_cs ? bram_we : 2'b00;
assign spr_we   = spr_cs   ? bram_we : 2'b00;

// Video-side BRAM addresses (no video module yet — stub to zero)
assign pal_addr   = 0;
assign vram0_addr = 0;
assign vram1_addr = 0;
assign vram2_addr = 0;
assign vram3_addr = 0;
assign spr_addr   = 0;

// Stub assignments — modules not yet instantiated
assign red        = 0;
assign green      = 0;
assign blue       = 0;
assign dip_flip   = 0;
assign debug_view = 0;

// Pixel clock: 48 MHz * 44 / 39 = 27.03 MHz
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk    ( clk                    ),
    .n      ( 10'd44                 ),
    .m      ( 10'd39                 ),
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
jtdeco_cninja_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),

    // SDRAM ROM
    .main_addr  ( main_addr     ),
    .rom_cs     ( rom_cs        ),
    .rom_data   ( rom_data      ),
    .rom_ok     ( rom_ok        ),

    // SDRAM Work RAM
    .ram_addr   ( ram_addr      ),
    .ram_we     ( ram_we        ),
    .dsn        ( dsn           ),
    .main_dout  ( main_dout     ),
    .cpu_rnw    ( cpu_rnw       ),
    .wram_cs    ( wram_cs       ),
    .ram_dout   ( ram_dout      ),
    .ram_ok     ( ram_ok        ),

    // CPU bus → video BRAMs (CS signals)
    .pal_cs     ( pal_cs        ),
    .vram0_cs   ( vram0_cs      ),
    .vram1_cs   ( vram1_cs      ),
    .vram2_cs   ( vram2_cs      ),
    .vram3_cs   ( vram3_cs      ),
    .spr_cs     ( spr_cs        ),

    // Video RAM CPU-side read-back (from generated BRAM ports)
    .mp_dout    ( mp_dout       ),
    .m0_dout    ( m0_dout       ),
    .m1_dout    ( m1_dout       ),
    .m2_dout    ( m2_dout       ),
    .m3_dout    ( m3_dout       ),
    .ms_dout    ( ms_dout       ),

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
jtdeco_cninja_snd u_snd(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .snd_latch  ( snd_latch         ),
    .snd_stb    ( snd_stb           ),
    .snd_addr   ( snd_addr          ),
    .snd_cs     ( snd_cs            ),
    .snd_data   ( snd_data          ),
    .snd_ok     ( snd_ok            ),
    .left       ( snd_left          ),
    .right      ( snd_right         )
);
`else
assign snd_left    = 0;
assign snd_right   = 0;
assign snd_cs      = 0;
assign snd_addr    = 0;
`endif

endmodule
