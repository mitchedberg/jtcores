/*  This file is part of JT_CORES.
    JT_CORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_CORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_CORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: jotego
    Version: 1.0
    Date: 27-March-2026

*/

module jtwwfwfest_game(
    `include "jtframe_game_ports.inc"
);

localparam CHARW=8, CHARH=8;

// Clocks
wire clk_cpu, clk_snd;
wire clk12 = clk24 >> 1;

// From CPU
wire [15:0] cpu_dout;
wire [23:0] cpu_addr;
wire        cpu_we;

// Video
wire vblank, hblank;
wire [8:0]  vdump;
wire [8:0]  hdump;

// Clock dividers
jtframe_frac_cen #(.WN(4)) u_div(
    .clk    ( clk24        ),
    .cen    ( 1'b1         ),
    .div    ( 4'd1         ),  // 12 MHz for 68000
    .cen_out( clk_cpu      )
);

jtframe_frac_cen #(.WN(4)) u_div_snd(
    .clk    ( clk24        ),
    .cen    ( 1'b1         ),
    .div    ( 4'd2         ),  // 8 MHz for Z80
    .cen_out( clk_snd      )
);

// Video timing
jtframe_vtimer #(.VDUMP_LEN(10),.HDUMP_LEN(10)) u_vtimer(
    .clk       ( clk24       ),
    .pxl_cen   ( pxl_cen     ),
    .vdump     ( vdump       ),
    .hdump     ( hdump       ),
    .vblank    ( vblank      ),
    .hblank    ( hblank      ),
    .vs        ( vs          ),
    .hs        ( hs          ),
    .vrender   ( vrender     ),
    .hrender   ( hrender     )
);

// CPU module
jtwwfwfest_main u_main(
    .clk        ( clk24        ),
    .clk_cpu    ( clk_cpu      ),
    .rst        ( rst          ),
    .cpu_addr   ( cpu_addr     ),
    .cpu_dout   ( cpu_dout     ),
    .cpu_we     ( cpu_we       ),

    .pal_we     ( pal_we       ),
    .vram_we    ( vram_we      ),
    .spr_we     ( spr_we       ),
    .pal_dout   ( pal_dout     ),
    .vram_dout  ( vram_dout    ),
    .spr_dout   ( spr_dout     ),

    .vblank     ( vblank       ),
    .vdump      ( vdump        ),

    .sdram_req  ( sdram_req    ),
    .sdram_ack  ( sdram_ack    ),
    .sdram_addr ( sdram_addr   ),
    .sdram_dout ( sdram_dout   ),

    .snd_latch  ( snd_latch    ),

    .input_data ( input_data   ),
    .dipsw      ( dipsw        )
);

// Sound module
jtwwfwfest_snd u_snd(
    .clk        ( clk24        ),
    .clk_snd    ( clk_snd      ),
    .rst        ( rst          ),

    .snd_latch  ( snd_latch    ),

    .sdram_req  ( sdram_req    ),
    .sdram_ack  ( sdram_ack    ),
    .sdram_addr ( sdram_addr   ),
    .sdram_dout ( sdram_dout   ),

    .snd        ( snd          )
);

// Placeholder for graphics output
always @(posedge clk24) begin
    // TODO: Implement graphics pipeline
    red   <= 0;
    green <= 0;
    blue  <= 0;
end

endmodule
