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

module jttoaplan_kb_snd(
    input   rst,
    input   clk,
    input   cen4,

    // Sound CPU
    output [14:0] snd_addr,
    input  [ 7:0] snd_din,
    output [ 7:0] snd_dout,
    output        snd_rnw,
    output        snd_cs,

    // ROM
    input  [14:0] rom_addr,
    input  [ 7:0] rom_data,
    input         rom_we,

    // Sound communication
    input  [ 7:0] snd_latch,
    output        snd_flag,

    // Audio
    output signed [15:0] dac_l,
    output signed [15:0] dac_r
);

assign snd_addr = 15'h0000;
assign snd_dout = 8'h00;
assign snd_rnw  = 1'b1;
assign snd_cs   = 1'b0;
assign snd_flag = 1'b0;
assign dac_l    = 16'h0000;
assign dac_r    = 16'h0000;

endmodule
