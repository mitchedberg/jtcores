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
    Date: 28-03-2026 */

module jtatari_batman_main(
    input           clk,
    input           rst,
    output          cpu_cen,
    input    [23:1] cpu_addr,
    input    [15:0] cpu_din,
    output   [15:0] cpu_dout,
    input           cpu_rnw,
    input           cpu_dtack,
    output          cpu_irq,

    // ROM interface
    output          rom_cs,
    output   [19:0] rom_addr,
    input    [15:0] rom_data,

    // RAM interface
    output          ram_cs,
    output   [17:0] ram_addr,
    output   [15:0] ram_din,
    output          ram_we,
    input    [15:0] ram_dout,

    // Palette interface
    output          pal_cs,
    output   [11:0] pal_addr,
    output          pal_we,
    output   [15:0] pal_din,
    input    [15:0] pal_dout,

    // Sprite interface
    output          spr_cs,
    output   [11:0] spr_addr,
    output          spr_we,
    output   [15:0] spr_din,
    input    [15:0] spr_dout,

    // Sound interface
    output          snd_cs,
    output   [7:0]  snd_latch,
    output          snd_stb,
    input           snd_flag
);

// TODO: Implement 68000 main CPU logic

endmodule
