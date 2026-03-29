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

wire [8:0] hdump, vdump;

// CPU interface wires (game.v ↔ main.v ↔ video.v)
wire [13:1] cpu_addr;
wire [15:0] cpu_dout;
wire        cpu_rnw;
wire        pal_cs, bgvram_cs, fgvram_cs, scroll_cs, sprite_cs, io_cs_unused;
wire [15:0] mp_dout, mbg_dout, mfg_dout, mscroll_dout;
wire        tilebank;

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
    .vdump      ( vdump        ),
    .vrender    (              ),
    .vrender1   (              ),
    .H          ( hdump        ),
    .Hinit      (              ),
    .Vinit      (              ),
    .LHBL       ( LHBL         ),
    .LVBL       ( LVBL         ),
    .HS         ( HS           ),
    .VS         ( VS           )
);

assign dip_flip   = 0;
assign debug_view = 0;

`ifndef NOMAIN
jtnmk16_main u_main(
    .rst            ( rst               ),
    .clk            ( clk               ),
    .LVBL           ( LVBL              ),

    // SDRAM ROM
    .main_addr      ( main_addr         ),
    .main_cs        ( main_cs           ),
    .main_data      ( main_data         ),
    .main_ok        ( main_ok           ),

    // SDRAM Work RAM
    .ram_addr       ( ram_addr          ),
    .ram_we         ( ram_we            ),
    .ram_dsn        ( ram_dsn           ),
    .ram_din        ( ram_din           ),
    .ram_cs         ( ram_cs            ),
    .ram_data       ( ram_data          ),
    .ram_ok         ( ram_ok            ),

    // CPU address/data for video BRAM writes
    .cpu_addr       ( cpu_addr          ),
    .cpu_dout_o     ( cpu_dout          ),
    .cpu_rnw        ( cpu_rnw           ),

    // Video chip selects
    .pal_cs         ( pal_cs            ),
    .bgvram_cs      ( bgvram_cs         ),
    .fgvram_cs      ( fgvram_cs         ),
    .scroll_cs      ( scroll_cs         ),
    .sprite_cs      ( sprite_cs         ),
    .io_cs          ( io_cs_unused      ),

    // Video BRAM read-back
    .mp_dout        ( mp_dout           ),
    .mbg_dout       ( mbg_dout          ),
    .mfg_dout       ( mfg_dout          ),
    .mscroll_dout   ( mscroll_dout      ),

    // I/O
    .joystick1      ( joystick1         ),
    .joystick2      ( joystick2         ),
    .dipsw          ( dipsw[15:0]       ),
    .dip_pause      ( dip_pause         ),

    // Sound
    .snd_latch      (                   ),
    .snd_stb        (                   ),

    // Tilebank
    .tilebank       ( tilebank          )
);
`else
assign main_cs    = 0;
assign main_addr  = 0;
assign ram_cs     = 0;
assign ram_addr   = 0;
assign ram_we     = 0;
assign ram_dsn    = 2'b11;
assign ram_din    = 0;
assign cpu_addr   = 0;
assign cpu_dout   = 0;
assign cpu_rnw    = 1;
assign pal_cs     = 0;
assign bgvram_cs  = 0;
assign fgvram_cs  = 0;
assign scroll_cs  = 0;
`endif

jtnmk16_video u_video(
    .rst            ( rst               ),
    .clk            ( clk               ),
    .pxl_cen        ( pxl_cen           ),
    .LHBL           ( LHBL              ),
    .LVBL           ( LVBL              ),
    .hdump          ( hdump             ),
    .vdump          ( vdump             ),
    .HS             ( HS                ),
    // CPU interface
    .cpu_addr       ( cpu_addr          ),
    .cpu_dout       ( cpu_dout          ),
    .cpu_rnw        ( cpu_rnw           ),
    // VRAM chip selects
    .bgvram_cs      ( bgvram_cs         ),
    .fgvram_cs      ( fgvram_cs         ),
    .pal_cs         ( pal_cs            ),
    .scroll_cs      ( scroll_cs         ),
    .sprite_cs      ( sprite_cs         ),
    .tilebank       ( tilebank          ),
    // CPU read-back
    .bgvram_dout    ( mbg_dout          ),
    .fgvram_dout    ( mfg_dout          ),
    .pal_dout       ( mp_dout           ),
    .scroll_dout    ( mscroll_dout      ),
    // GFX ROM
    .gfx_addr       ( gfx_addr          ),
    .gfx_cs         ( gfx_cs            ),
    .gfx_data       ( gfx_data          ),
    .gfx_ok         ( gfx_ok            ),
    .spr_addr       ( spr_addr          ),
    .spr_cs         ( spr_cs            ),
    .spr_data       ( spr_data          ),
    .spr_ok         ( spr_ok            ),
    .fg_addr        ( fg_addr           ),
    .fg_cs          ( fg_cs             ),
    .fg_data        ( fg_data           ),
    .fg_ok          ( fg_ok             ),
    // Pixel output
    .red            ( red               ),
    .green          ( green             ),
    .blue           ( blue              )
);

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
