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

module jtgalpanic_main(
    input   rst,
    input   clk,
    input   LVBL,

    // SDRAM ROM
    output reg [19:0] main_addr,
    output reg        rom_cs,
    input      [15:0] rom_data,
    input             rom_ok,

    // SDRAM Work RAM
    output reg [19:0] ram_addr,
    output reg [ 1:0] ram_we,
    output reg [ 1:0] dsn,
    output reg [15:0] main_dout,
    output            cpu_rnw,
    output reg        wram_cs,
    input      [15:0] ram_data,
    input             ram_ok,

    // Video BRAMs
    output reg        pal_cs,
    input      [15:0] mp_dout,

    // I/O
    input [15:0] joystick1,
    input [15:0] joystick2,
    input [15:0] dipsw,
    input        dip_pause,

    // Sound
    output reg [ 7:0] snd_latch,
    output reg        snd_stb
);

endmodule
