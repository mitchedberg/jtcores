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
    Date: 29-3-2026 */

module jttoaplan_ghox_game(
    `include "jtframe_game_ports.svh"
    /* jtframe_mem_ports */
);
`include "mem_ports.inc"

// Inter-module wires
wire [ 7:0] snd_latch;
wire snd_stb;

// CS signals from main.v
wire pal_cs;
wire cpu_rnw;

// BRAM write enables
wire [1:0] bram_we = {2{~cpu_rnw}} & ~ram_dsn;
assign pal_we = pal_cs ? bram_we : 2'b00;

// Video-side BRAM addresses (stub to zero)
assign pal_addr = 0;

// Stub video output
assign red   = 0;
assign green = 0;
assign blue  = 0;
assign dip_flip   = 0;
assign debug_view = 0;

// Pixel clock
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk    ( clk                    ),
    .n      ( 10'd105                ),
    .m      ( 10'd352                ),
    .cen    ( {pxl_cen, pxl2_cen}   ),
    .cenb   (                        )
);

jtframe_vtimer #(
    .VB_START   ( 9'd239          ),
    .VB_END     ( 9'd261          ),
    .VS_START   ( 9'd231          ),
    .HCNT_END   ( 9'd455          ),
    .HB_START   ( 9'd319          ),
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

// Stub sound ROM buses
assign snd2_cs = 0;
assign snd2_addr = 0;

`ifndef NOMAIN
jttoaplan_ghox_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),

    // SDRAM ROM
    .main_addr  ( main_addr     ),
    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),

    // SDRAM Work RAM
    .ram_addr   ( ram_addr      ),
    .ram_we     ( ram_we        ),
    .dsn        ( ram_dsn       ),
    .main_dout  ( ram_din       ),
    .cpu_rnw    ( cpu_rnw       ),
    .wram_cs    ( ram_cs        ),
    .ram_dout   ( ram_data      ),
    .ram_ok     ( ram_ok        ),

    // CPU bus → video BRAMs
    .pal_cs     ( pal_cs        ),

    // Video RAM read-back
    .mp_dout    ( 16'h0         ),

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
jttoaplan_ghox_snd u_snd(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .snd_latch  ( snd_latch     ),
    .snd_stb    ( snd_stb       ),
    .snd_addr   ( snd_addr      ),
    .snd_cs     ( snd_cs        ),
    .snd_data   ( snd_data      ),
    .snd_ok     ( snd_ok        ),
    .snd2_addr  ( snd2_addr     ),
    .snd2_cs    ( snd2_cs       ),
    .snd2_data  ( snd2_data     ),
    .snd2_ok    ( snd2_ok       ),
    .snd_left   ( snd_left      ),
    .snd_right  ( snd_right     ),
    .sample     ( sample        ),
    .debug_bus  ( debug_bus     )
);
`endif

endmodule
