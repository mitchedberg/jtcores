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

module jtshadfrce_game(
    `include "jtframe_game_ports.inc"
);

// Inter-module wires
wire [ 7:0] snd_latch;
wire snd_stb;

// CS signals and RnW from main.v
wire spr_cs, pal_cs, vram0_cs, vram1_cs;
wire cpu_rnw;

// BRAM write enables: active when CPU writes and BRAM is selected
wire [1:0] bram_we = {2{~cpu_rnw}} & ~ram_dsn;
assign spr_we   = spr_cs   ? bram_we : 2'b00;
assign pal_we   = pal_cs   ? bram_we : 2'b00;
assign vram0_we = vram0_cs ? bram_we : 2'b00;
assign vram1_we = vram1_cs ? bram_we : 2'b00;

// Video-side BRAM addresses (no video module yet — stub to zero)
assign spr_addr   = 0;
assign pal_addr   = 0;
assign vram0_addr = 0;
assign vram1_addr = 0;

// Stub assignments — modules not yet instantiated
assign red        = 0;
assign green      = 0;
assign blue       = 0;
assign dip_flip   = 0;

// Main CPU and sound CPU
jtshadfrce_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),

    // Interprocessor comm
    .snd_latch  ( snd_latch     ),
    .snd_stb    ( snd_stb       ),

    // ROM access
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),

    // SDRAM RAM access
    .ram_addr   ( ram_addr      ),
    .ram_data   ( ram_data      ),
    .ram_we     ( ram_we        ),
    .ram_dsn    ( ram_dsn       ),
    .ram_ok     ( ram_ok        ),

    // BRAM write controls
    .spr_cs     ( spr_cs        ),
    .spr_we     ( spr_we        ),
    .pal_cs     ( pal_cs        ),
    .pal_we     ( pal_we        ),
    .vram0_cs   ( vram0_cs      ),
    .vram0_we   ( vram0_we      ),
    .vram1_cs   ( vram1_cs      ),
    .vram1_we   ( vram1_we      ),

    // Inputs
    .joy1       ( joy1          ),
    .joy2       ( joy2          ),
    .start_btn  ( start_btn     ),
    .coin_input ( coin_input    ),
    .service    ( service       ),
    .tilt       ( tilt          ),
    .dipsw      ( dipsw         )
);

// Sound CPU and audio
jtshadfrce_snd u_snd(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_z80    ( cen_z80       ),
    .cen_fm     ( cen_fm        ),
    .cen_pcm    ( cen_pcm       ),

    .snd_latch  ( snd_latch     ),
    .snd_stb    ( snd_stb       ),

    // ROM access
    .rom_addr   ( rom_addr_snd  ),
    .rom_data   ( rom_data_snd  ),
    .rom_cs     ( rom_cs_snd    ),
    .rom_ok     ( rom_ok_snd    ),

    // Audio output
    .fm_left    ( fm_left       ),
    .fm_right   ( fm_right      ),
    .pcm_left   ( pcm_left      ),
    .pcm_right  ( pcm_right     )
);

endmodule
