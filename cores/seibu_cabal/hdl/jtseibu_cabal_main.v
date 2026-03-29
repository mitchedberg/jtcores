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

    Author: JTCORES team.
    Date: 2026-03-28

*/

module jtseibu_cabal_main(
    input         clk,
    input         rst,
    input         cpu_cen,
    // ROM
    output [18:0] rom_addr,
    input  [15:0] rom_dout,
    // RAM
    output [13:0] ram_addr,
    output [15:0] ram_din,
    input  [15:0] ram_dout,
    output        ram_we,
    output        ram_cs,
    // BRAM
    output [10:0] pal_addr,
    output [15:0] pal_din,
    input  [15:0] pal_dout,
    output        pal_we,
    output [11:0] vram_addr,
    output [15:0] vram_din,
    input  [15:0] vram_dout,
    output        vram_we,
    // I/O
    input  [1:0]  buttons,
    input  [1:0]  coin,
    input  [1:0]  joystick1,
    input  [1:0]  joystick2,
    input  [1:0]  start_button,
    input  [1:0]  dipsw,
    // IRQ
    output        irq
);

    // Stub - all outputs disabled
    assign rom_addr  = 19'h0;
    assign ram_addr  = 14'h0;
    assign ram_din   = 16'h0;
    assign ram_we    = 1'b0;
    assign ram_cs    = 1'b0;

    assign pal_addr  = 11'h0;
    assign pal_din   = 16'h0;
    assign pal_we    = 1'b0;

    assign vram_addr = 12'h0;
    assign vram_din  = 16'h0;
    assign vram_we   = 1'b0;

    assign irq       = 1'b0;

endmodule
