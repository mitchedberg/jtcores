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

module jtdeco32_main(
    input                rst,
    input                clk,
    input                LVBL,

    // SDRAM ROM
    output        [19:1] main_addr,
    output reg           rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,

    // SDRAM Work RAM
    output        [16:1] ram_addr,
    output               ram_we,
    output        [ 1:0] dsn,
    output        [15:0] main_dout,
    output               cpu_rnw,
    output reg           wram_cs,
    input         [15:0] ram_dout,
    input                ram_ok,

    // CPU bus (for video BRAMs in game.v)
    output reg           pal_cs,

    // Video RAM read-back (stub: game.v returns 0)
    input         [15:0] mp_dout,    // CPU-side palette read

    // I/O
    input         [ 5:0] joystick1,
    input         [ 5:0] joystick2,
    input         [15:0] dipsw,
    input                dip_pause,

    // Sound
    output reg    [ 7:0] snd_latch,
    output reg           snd_stb
);

`ifndef NOMAIN
// ARM CPU stub - placeholder for HPS register interface
// Deco32 uses ARM7 @ ~14MHz as main CPU

// Stub signals for now
wire [23:1] arm_addr;
wire        arm_rnw;
wire [15:0] arm_dout;
reg  [15:0] arm_din;

assign main_addr = arm_addr;
assign main_dout = arm_dout;
assign cpu_rnw   = arm_rnw;
assign ram_addr  = arm_addr[16:1];

// Simple chip-selects
always @* begin
    rom_cs      = arm_addr[19:17] == 3'b000;
    pal_cs      = arm_addr[19:16] == 4'h4;
    wram_cs     = arm_addr[19:16] == 4'h2;
end

// Data read-back stub
always @* begin
    arm_din = 16'h0000;
    if (pal_cs)
        arm_din = mp_dout;
    else if (rom_cs)
        arm_din = rom_data;
    else if (wram_cs)
        arm_din = ram_dout;
end

// Sound latch write stub
always @(posedge clk) begin
    if (rst) begin
        snd_latch <= 8'h00;
        snd_stb   <= 1'b0;
    end else begin
        snd_stb <= 1'b0;
        // Stub: no actual Z80 write path yet
    end
end

`endif
endmodule
