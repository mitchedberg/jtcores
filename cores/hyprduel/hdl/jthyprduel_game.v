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

module jthyprduel_game(
    `include "jtframe_game_ports.inc"
);

// Inter-module wires
wire [ 7:0] snd_latch;
wire snd_stb;

// CS signals and RnW from main.v
wire pal_cs, vram_cs;
wire cpu_rnw;

// BRAM write enables: active when CPU writes and BRAM is selected
wire [1:0] bram_we = {2{~cpu_rnw}} & ~ram_dsn;
assign pal_we  = pal_cs  ? bram_we : 2'b00;
assign vram_we = vram_cs ? bram_we : 2'b00;

// Video-side BRAM addresses (no video module yet — stub to zero)
assign pal_addr   = 0;
assign vram_addr  = 0;

// Stub assignments — modules not yet instantiated
assign red        = 0;
assign green      = 0;
assign blue       = 0;
assign dip_flip   = 0;

// Instantiate main CPU module
jthyprduel_main main(
    .rst        ( rst ),
    .clk        ( clk ),
    .cen12      ( cen12 ),
    .cen6       ( cen6 ),
    .cen3       ( cen3 ),

    // ROM/RAM
    .rom_addr   ( rom_addr ),
    .rom_data   ( rom_data ),
    .rom_cs     ( rom_cs ),
    .rom_ok     ( rom_ok ),

    // RAM
    .ram_addr   ( ram_addr ),
    .ram_data   ( ram_din ),
    .ram_rnw    ( cpu_rnw ),
    .ram_dsn    ( ram_dsn ),

    // Outputs
    .pal_cs     ( pal_cs ),
    .pal_addr   ( pal_dma_addr ),
    .pal_din    ( ram_din ),
    .vram_cs    ( vram_cs ),
    .vram_addr  ( vram_dma_addr ),
    .vram_din   ( ram_din ),

    // Sound
    .snd_latch  ( snd_latch ),
    .snd_stb    ( snd_stb ),

    // Cabinet
    .cab_1p     ( cab_1p ),
    .cab_2p     ( cab_2p ),
    .coin       ( coin ),
    .dipsw      ( dipsw ),

    // Debug
    .debug      ( debug_bus )
);

// Instantiate sound module
jthyprduel_snd snd(
    .rst        ( rst ),
    .clk        ( clk ),
    .cen_z80    ( cen_z80 ),
    .cen_fm     ( cen_fm ),
    .cen_oki    ( cen_oki ),

    .snd_latch  ( snd_latch ),
    .snd_stb    ( snd_stb ),

    .snd_rom_addr ( snd_rom_addr ),
    .snd_rom_data ( snd_rom_data ),
    .snd_rom_ok   ( snd_rom_ok ),

    .oki_rom_addr ( oki_rom_addr ),
    .oki_rom_data ( oki_rom_data ),
    .oki_rom_ok   ( oki_rom_ok ),

    .snd          ( snd ),
    .sample       ( sample )
);

endmodule
