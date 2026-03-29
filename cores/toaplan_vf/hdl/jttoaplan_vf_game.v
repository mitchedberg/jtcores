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

    Author: Arcade builder
    Date: 28-03-2026 */

module jttoaplan_vf_game(
    `include "jtframe_game_ports.inc"
);

wire        snd_rst;
wire [ 7:0] snd_latch;
wire        main_flag, main_stb, snd_stb;

wire [15:0] cpu_addr;
wire        cpu_rnw, cpu_irqn, cpu_nmi;
wire [ 7:0] cpu_dout, cpu_din;
wire        ram_we, rom_cs, snd_cs;

assign snd_rst      = ~rst;
assign dip_flip     = 1'b0;
assign debug_view   = 8'h00;

jttoaplan_vf_main u_main(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_din    ( cpu_din       ),
    .cpu_irqn   ( cpu_irqn      ),
    .cpu_nmi    ( cpu_nmi       ),
    // SDRAM
    .rom_addr   ( rom_addr      ),
    .rom_dout   ( rom_data      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    // Sound
    .snd_latch  ( snd_latch     ),
    .snd_flag   ( snd_flag      ),
    // BRAM
    .ram_addr   ( ram_addr      ),
    .ram_dout   ( ram_dout      ),
    .ram_din    ( ram_din       ),
    .ram_we     ( ram_we        )
);

endmodule
