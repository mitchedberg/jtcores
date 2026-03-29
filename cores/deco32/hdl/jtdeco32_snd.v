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
    Date: 2026-03-28 */

// Data East Deco32 sound module
// Features: YM2151 + OKI M6295 (or alternate sound chip)
// Main CPU is ARM7, sound CPU is H6280

module jtdeco32_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // H6280 ROM (SDRAM)
    output     [16:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // OKI M6295 ROM (SDRAM) or other ADPCM
    output     [19:0] adpcm_addr,
    output            adpcm_cs,
    input      [ 7:0] adpcm_data,
    input             adpcm_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// --- Clock enable: 48 MHz / 3 = 16 MHz for H6280 ---
// (H6280 nominally runs at 1.789 MHz on real hardware, but scaled here)
reg [1:0] cen_cnt;
reg       cen16;

always @(posedge clk) begin
    if (rst) begin
        cen_cnt <= 0;
        cen16   <= 0;
    end else begin
        cen16 <= 0;
        if (cen_cnt == 2'd2) begin
            cen_cnt <= 0;
            cen16   <= 1;
        end else begin
            cen_cnt <= cen_cnt + 2'd1;
        end
    end
end

// --- H6280 sound CPU interface (stub) ---
// Full H6280 + YM2151 + OKI instantiation would go here
// For now, stub the sound output

assign snd_left  = 16'h0000;
assign snd_right = 16'h0000;
assign sample    = 1'b0;
assign snd_addr  = 17'h0;
assign snd_cs    = 1'b0;
assign adpcm_addr = 20'h0;
assign adpcm_cs  = 1'b0;

`else
// NOSOUND mode
assign snd_left  = 16'h0000;
assign snd_right = 16'h0000;
assign sample    = 1'b0;
`endif

endmodule
