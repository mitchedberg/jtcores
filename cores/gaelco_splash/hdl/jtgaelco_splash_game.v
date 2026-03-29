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

module jtgaelco_splash_game(
    `include "jtframe_game_ports.inc"
);

// Inter-module wires
wire [ 7:0] snd_latch;
wire snd_stb;

// CS signals and RnW from main.v

// BRAM write enables: active when CPU writes and BRAM is selected
wire [1:0] bram_we = {2{~cpu_rnw}} & ~ram_dsn;
assign pal_we   = pal_cs   ? bram_we : 2'b00;
assign spr_we   = spr_cs   ? bram_we : 2'b00;

// Video-side BRAM addresses (no video module yet — stub to zero)
assign pal_addr = 0;
assign spr_addr = 0;

// Stub assignments — modules not yet instantiated
assign red        = 0;
assign green      = 0;
assign blue       = 0;
assign dip_flip   = 0;
assign debug_view = 0;

// Pixel clock and timing (stub for now)
assign pxl_cen    = 0;
assign pxl2_cen   = 0;
assign LHBL       = 0;
assign LVBL       = 0;
assign HS         = 0;
assign VS         = 0;

// Unused SDRAM buses
assign tile_cs     = 0;
assign tile_addr   = 0;
assign obj_cs      = 0;
assign obj_addr    = 0;

`ifndef NOMAIN
jtgaelco_splash_main u_main(
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
    .cpu_rnw    ( cpu_rnw       ),
    .ram_cs     ( ram_cs        ),
    .ram_data   ( ram_data      ),
    .ram_ok     ( ram_ok        ),

    // CPU bus → video BRAMs (CS signals; address driven by generated wrapper)
    .pal_cs     ( pal_cs        ),
    .spr_cs     ( spr_cs        ),
    .vram_we    ( vram_we       ),

    // Video RAM CPU-side read-back (from generated BRAM ports)
    .mp_dout    ( mp_dout       ),
    .ms_dout    ( ms_dout       ),
    .mv_dout    ( mv_dout       ),

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
jtgaelco_splash_snd u_snd(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .snd_latch  ( snd_latch         ),
    .snd_stb    ( snd_stb           ),
    .snd_addr   ( snd_addr          ),
    .snd_cs     ( snd_cs            ),
    .snd_data   ( snd_data          ),
    .snd_ok     ( snd_ok            ),
    .snd        ( snd_left          ),
    .sample     ( sample            ),
    .debug_bus  ( debug_bus         )
);
assign snd_right = snd_left;
`else
assign snd_left    = 0;
assign snd_right   = 0;
assign sample      = 0;
assign snd_cs      = 0;
assign snd_addr    = 0;
`endif

endmodule
