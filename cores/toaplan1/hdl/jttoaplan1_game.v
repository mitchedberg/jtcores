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

    Author: (community) jotego
    Date: 2026-03-28 */

`timescale 1ns/1ps

module jttoaplan1_game(
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,

    // Buttons and DIP switches
    input   [ 1:0]  button,
    input   [ 1:0]  start_button,
    input   [15:0]  dipsw_a,
    input   [15:0]  dipsw_b,

    // Video output
    output  [ 1:0]  red,
    output  [ 1:0]  green,
    output  [ 1:0]  blue,
    output          hs,
    output          vs,
    output          blank_n,
    output          sync_n,

    // Audio output
    output  signed [15:0]  snd,

    // SDRAM interface
    input           sdram_ack,
    input           sdram_valid,
    input   [31:0]  sdram_dout,
    output  [22:0]  sdram_addr,
    output  [ 3:0]  sdram_be,
    output          sdram_wr,
    output          sdram_req,
    input           sdram_rdy,

    // ROM LOAD interface
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,

    input           ioctl_upload,
    input           ioctl_download,
    output          downloading,

    // Status lines
    output          game_led,
    output          debug_view
);

    // Stub implementation
    reg [7:0] dummy;

    assign red       = 2'b00;
    assign green     = 2'b00;
    assign blue      = 2'b00;
    assign hs        = 1'b1;
    assign vs        = 1'b1;
    assign blank_n   = 1'b0;
    assign sync_n    = 1'b1;
    assign snd       = 16'd0;

    assign sdram_addr = 23'd0;
    assign sdram_be   = 4'hf;
    assign sdram_wr   = 1'b0;
    assign sdram_req  = 1'b0;

    assign prog_addr  = 22'd0;
    assign prog_data  = 8'd0;
    assign prog_mask  = 2'b00;
    assign prog_we    = 1'b0;
    assign prog_rd    = 1'b0;

    assign downloading = 1'b0;
    assign game_led    = 1'b0;
    assign debug_view  = 1'b0;

endmodule
