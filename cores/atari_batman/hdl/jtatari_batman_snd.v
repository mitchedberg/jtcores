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

module jtatari_batman_snd(
    input           clk,
    input           rst,
    output          snd_cen,

    // Z80 CPU interface
    input    [15:0] cpu_addr,
    input    [7:0]  cpu_din,
    output   [7:0]  cpu_dout,
    input           cpu_rnw,
    output          cpu_irq,

    // YM2151 sound chip
    output          ym_a0,
    output   [7:0]  ym_dout,
    output          ym_we,
    input    [7:0]  ym_din,

    // MSM6295 ADPCM
    output   [15:0] adpcm_addr,
    output          adpcm_cen,
    input    [7:0]  adpcm_data,

    // Latch from main CPU
    input    [7:0]  snd_latch,
    input           snd_stb,
    output          snd_flag,

    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right
);

// TODO: Implement Z80 sound CPU logic with YM2151 and MSM6295

endmodule
