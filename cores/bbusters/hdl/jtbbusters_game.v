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

    Author: jotego
    Version: 1.0
    Date: 28-Mar-2026

*/

module jtbbusters_game (
    input           rst,
    input           clk,
    input           clk24,
    input           clk48,
    // video
    output          pxl_cen,
    output          pxl2_cen,
    output   [7:0]  red,
    output   [7:0]  green,
    output   [7:0]  blue,
    output          hs,
    output          vs,
    output          blank,
    output          blankn,
    // cabinet I/O
    input   [ 3:0]  cab_1p,
    input   [ 3:0]  cab_2p,
    input   [ 3:0]  cab_3p,
    input   [ 3:0]  cab_4p,
    output  [ 3:0]  cab_led,
    input           coin_left,
    input           coin_right,
    input           service,
    // SDRAM interface
    output          sdram_req,
    output  [22:0]  sdram_addr,
    input   [31:0]  sdram_data,
    input           sdram_ack,
    output  [ 3:0]  sdram_we,
    output  [31:0]  sdram_wdata,
    // ROM LOAD
    inout   [15:0]  rom_data,
    output  [21:0]  rom_addr,
    output          rom_cs,
    output          rom_ok,
    // Palette BRAM
    output  [10:0]  pal_addr,
    output  [15:0]  pal_dout,
    output          pal_we,
    input   [15:0]  pal_din,
    // Sprite BRAM
    output  [12:0]  spr_addr,
    output  [15:0]  spr_dout,
    output          spr_we,
    input   [15:0]  spr_din,
    // VRAM0 BRAM
    output  [12:0]  vram0_addr,
    output  [15:0]  vram0_dout,
    output          vram0_we,
    input   [15:0]  vram0_din,
    // VRAM1 BRAM
    output  [12:0]  vram1_addr,
    output  [15:0]  vram1_dout,
    output          vram1_we,
    input   [15:0]  vram1_din,
    // Video regs BRAM
    output  [13:0]  vregs_addr,
    output  [15:0]  vregs_dout,
    output          vregs_we,
    input   [15:0]  vregs_din,
    // Audio
    output  [15:0]  snd_left,
    output  [15:0]  snd_right,
    // Debug
    input   [ 3:0]  gfx_en
    /* jtframe_mem_ports */
);
`include "mem_ports.inc"

wire clk_cpu, clk_snd;

// Clock dividers
jtframe_frac_cen #(.WD(4)) u_frac_12(
    .clk        ( clk24         ),
    .cen        ( clk_cpu       ),  // 12 MHz for 68k
    .n          ( 4'd2          ),
    .m          ( 4'd0          )
);

jtframe_frac_cen #(.WD(4)) u_frac_4(
    .clk        ( clk24         ),
    .cen        ( clk_snd       ),  // 4 MHz for Z80
    .n          ( 4'd6          ),
    .m          ( 4'd0          )
);

// Stubs for now - all outputs tied to safe defaults
assign pxl_cen  = 1'b0;
assign pxl2_cen = 1'b0;
assign red      = 8'd0;
assign green    = 8'd0;
assign blue     = 8'd0;
assign hs       = 1'b0;
assign vs       = 1'b0;
assign blank    = 1'b1;
assign blankn   = 1'b0;

assign cab_led  = 4'h0;

assign sdram_req    = 1'b0;
assign sdram_addr   = 23'd0;
assign sdram_we     = 4'h0;
assign sdram_wdata  = 32'd0;

assign rom_cs   = 1'b0;
assign rom_ok   = 1'b0;
assign rom_addr = 22'd0;
assign rom_data = 16'hzzzz;

assign pal_addr   = 11'd0;
assign pal_dout   = 16'd0;
assign pal_we     = 1'b0;

assign spr_addr   = 13'd0;
assign spr_dout   = 16'd0;
assign spr_we     = 1'b0;

assign vram0_addr  = 13'd0;
assign vram0_dout  = 16'd0;
assign vram0_we    = 1'b0;

assign vram1_addr  = 13'd0;
assign vram1_dout  = 16'd0;
assign vram1_we    = 1'b0;

assign vregs_addr  = 14'd0;
assign vregs_dout  = 16'd0;
assign vregs_we    = 1'b0;

assign snd_left   = 16'd0;
assign snd_right  = 16'd0;

endmodule
