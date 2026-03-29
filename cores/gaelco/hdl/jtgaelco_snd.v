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

// Gaelco: DS5002FP (MCS-51) @ 1 MHz + OKI MSM6295

module jtgaelco_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // OKI ROM (SDRAM)
    output     [16:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // Audio output
    output signed [15:0] snd,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// --- Clock enable: 48 MHz / 48 = 1 MHz ---
reg [5:0] cen_cnt;
reg       cen1;

always @(posedge clk) begin
    if (rst) begin
        cen_cnt <= 0;
        cen1    <= 0;
    end else begin
        cen1 <= 0;
        if (cen_cnt == 6'd47) begin
            cen_cnt <= 0;
            cen1    <= 1;
        end else begin
            cen_cnt <= cen_cnt + 6'd1;
        end
    end
end

// --- Latch register ---
reg [7:0] latch_q;

always @(posedge clk) begin
    if (rst)
        latch_q <= 8'h0;
    else if (snd_stb)
        latch_q <= snd_latch;
end

// --- OKI banking (simplified stub) ---
// Address = bank:offset format
// For now, direct passthrough to SDRAM

assign snd_addr = {9'b0, latch_q[7:0]};  // Stub: latch drives lower 8 bits
assign snd_cs   = 1'b1;                   // Always enabled

// --- OKI MSM6295 (stub — audio synthesis not implemented) ---
assign snd      = 16'd0;
assign sample   = 1'b0;

`else
// NOSOUND stub — all outputs driven to safe defaults
assign snd        = 16'd0;
assign sample     = 1'b0;
assign snd_cs     = 1'b0;
assign snd_addr   = 17'd0;
`endif

endmodule
