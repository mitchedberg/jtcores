/*  This file is part of JTBUBL.
    JTBUBL program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTBUBL program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTBUBL.  If not, see <http://www.gnu.org/licenses/>.

    Author: AI-rebuilt module (Phase 2 validation)
    Based on: MAME bublbobl.cpp palette documentation + JTFRAME patterns */

// Bubble Bobble color mixer / palette lookup
// Palette RAM: 256 entries x 16 bits, stored as two 256x8 banks
// Format: RGBx_444 big-endian
//   Even byte (cpu_addr[0]=0): RRRR GGGG
//   Odd byte  (cpu_addr[0]=1): BBBB xxxx

module jtbubl_colmix(
    input               clk,
    input               clk_cpu,
    input               pxl_cen,
    // Screen
    input               preLHBL,
    input               preLVBL,
    output              LHBL,
    output              LVBL,
    input      [ 7:0]   col_addr,
    // CPU interface
    input               pal_cs,
    output     [ 7:0]   pal_dout,
    input               cpu_rnw,
    input      [ 8:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    input               black_n,
    // Colours
    output     [ 3:0]   red,
    output     [ 3:0]   green,
    output     [ 3:0]   blue
);

wire        pal_we  = pal_cs & ~cpu_rnw;
wire [ 7:0] cpu_idx = cpu_addr[8:1]; // palette entry index (0-255)
wire        byte_sel = cpu_addr[0];   // 0=even (RG), 1=odd (Bx)

// Even bank: high byte of each palette entry (RRRR GGGG)
wire [7:0] even_cpu_q, even_vid_q;

jtframe_dual_ram #(.AW(8), .DW(8)) u_ram0(
    .clk0   ( clk_cpu            ),
    .data0  ( cpu_dout           ),
    .addr0  ( cpu_idx            ),
    .we0    ( pal_we & ~byte_sel ),
    .q0     ( even_cpu_q         ),
    .clk1   ( clk                ),
    .data1  ( 8'd0               ),
    .addr1  ( col_addr           ),
    .we1    ( 1'b0               ),
    .q1     ( even_vid_q         )
);

// Odd bank: low byte of each palette entry (BBBB xxxx)
wire [7:0] odd_cpu_q, odd_vid_q;

jtframe_dual_ram #(.AW(8), .DW(8)) u_ram1(
    .clk0   ( clk_cpu           ),
    .data0  ( cpu_dout          ),
    .addr0  ( cpu_idx           ),
    .we0    ( pal_we & byte_sel ),
    .q0     ( odd_cpu_q         ),
    .clk1   ( clk               ),
    .data1  ( 8'd0              ),
    .addr1  ( col_addr          ),
    .we1    ( 1'b0              ),
    .q1     ( odd_vid_q         )
);

// CPU read-back: select bank based on byte address
assign pal_dout = byte_sel ? odd_cpu_q : even_cpu_q;

// RGB from palette, gated by game blanking control
wire [11:0] rgb_in = black_n ?
    { even_vid_q[7:4], even_vid_q[3:0], odd_vid_q[7:4] } : 12'd0;

// Blanking delay and RGB output
jtframe_blank #(.DLY(1), .DW(12)) u_blank(
    .clk      ( clk     ),
    .pxl_cen  ( pxl_cen ),
    .preLHBL  ( preLHBL ),
    .preLVBL  ( preLVBL ),
    .LHBL     ( LHBL    ),
    .LVBL     ( LVBL    ),
    .preLBL   (         ),
    .rgb_in   ( rgb_in  ),
    .rgb_out  ( {red, green, blue} )
);

endmodule
