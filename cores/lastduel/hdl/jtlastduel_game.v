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

module jtlastduel_game(
    `include "jtframe_game_ports.inc"
);

// Inter-module wires
wire [ 7:0] snd_latch;
wire snd_stb;

// CS signals and RnW from main.v
wire spr_cs, pal_cs, vram0_cs, vram1_cs, vregs_cs;
wire cpu_rnw;

// BRAM write enables: active when CPU writes and BRAM is selected
wire [1:0] bram_we = {2{~cpu_rnw}} & ~ram_dsn;
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

endmodule
