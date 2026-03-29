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

// NMK16 BG tile renderer
// 16x16 tiles, 4bpp, 512x512 map, scroll
// Palette: 1024 entries, 16-bit custom format (5 bits per channel)
// GFX ROM: 32-bit SDRAM bus, 17-bit word address

module jtnmk16_video(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL,
    input         LVBL,
    input   [8:0] hdump,
    input   [8:0] vdump,
    input         HS,
    // CPU interface
    input  [12:1] cpu_addr,
    input  [15:0] cpu_dout,
    input         cpu_rnw,
    // VRAM chip selects
    input         bgvram_cs,
    input         fgvram_cs,   // unused this step
    input         pal_cs,
    input         scroll_cs,
    // CPU read-back
    output [15:0] bgvram_dout,
    output [15:0] fgvram_dout,
    output [15:0] pal_dout,
    output [15:0] scroll_dout,
    // GFX ROM (SDRAM bank 2, 32-bit)
    output [21:2] gfx_addr,
    output        gfx_cs,
    input  [31:0] gfx_data,
    input         gfx_ok,
    // Pixel output (5 bits per channel)
    output [4:0]  red,
    output [4:0]  green,
    output [4:0]  blue
);

// -------------------------------------------------------
// BG VRAM  — 1024 x 16-bit words (10-bit address)
// CPU writes; video side reads via swizzled addr from jtframe_scroll
// -------------------------------------------------------
wire  [9:0] bg_vram_raw;   // jtframe_scroll output: {row[4:0], col[4:0]}
// NMK16 swizzle: ofst = {row[4], col[4:0], row[3:0]}
wire  [9:0] bg_vram_addr = { bg_vram_raw[9], bg_vram_raw[4:0], bg_vram_raw[8:5] };

wire [15:0] bg_vram_q;
wire        bg_we = bgvram_cs & ~cpu_rnw;

jtframe_dual_ram #(.DW(16),.AW(10)) u_bgvram(
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr[10:1]),
    .we0    ( bg_we         ),
    .q0     ( bgvram_dout   ),
    .clk1   ( clk           ),
    .data1  ( 16'd0         ),
    .addr1  ( bg_vram_addr  ),
    .we1    ( 1'b0          ),
    .q1     ( bg_vram_q     )
);

// -------------------------------------------------------
// Palette RAM — 1024 x 16-bit words (10-bit address)
// -------------------------------------------------------
wire  [9:0] pal_rd_addr;   // driven by pixel output below
wire [15:0] pal_q;
wire        pal_we = pal_cs & ~cpu_rnw;

jtframe_dual_ram #(.DW(16),.AW(10)) u_palram(
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr[10:1]),
    .we0    ( pal_we        ),
    .q0     ( pal_dout      ),
    .clk1   ( clk           ),
    .data1  ( 16'd0         ),
    .addr1  ( pal_rd_addr   ),
    .we1    ( 1'b0          ),
    .q1     ( pal_q         )
);

// -------------------------------------------------------
// Scroll registers — 4 x 16-bit (cpu_addr[2:1] = 00..11)
// scrollX = {scroll[0][3:0], scroll[1][7:0]}  (12 bits)
// scrollY = {scroll[2][0],   scroll[3][7:0]}  (9 bits)
// -------------------------------------------------------
reg [15:0] scroll_r[0:3];
always @(posedge clk) begin
    if (rst) begin
        scroll_r[0] <= 0; scroll_r[1] <= 0;
        scroll_r[2] <= 0; scroll_r[3] <= 0;
    end else if (scroll_cs & ~cpu_rnw) begin
        scroll_r[cpu_addr[2:1]] <= cpu_dout;
    end
end
assign scroll_dout = scroll_r[cpu_addr[2:1]];

wire [8:0] scrx = { scroll_r[0][3:0], scroll_r[1][7:0] }[8:0];
wire [8:0] scry = { scroll_r[2][0],   scroll_r[3][7:0] };

// -------------------------------------------------------
// FG VRAM stub (not rendered in step 1)
// -------------------------------------------------------
assign fgvram_dout = 16'hFFFF;

// -------------------------------------------------------
// jtframe_scroll — SIZE=16, 512x512 map, 12-bit code, 8-bit pixel
// VA = (MAP_VW-4) + (MAP_HW-4) = 5+5 = 10
// VR = CW+5 = 17
// -------------------------------------------------------
wire [16:0] bg_rom_addr;
wire        bg_rom_cs;
wire  [7:0] bg_pxl;       // {pal[3:0], pixel[3:0]}

jtframe_scroll #(
    .SIZE   ( 16 ),
    .VA     ( 10 ),
    .CW     ( 12 ),
    .PW     (  8 ),
    .MAP_HW (  9 ),
    .MAP_VW (  9 ),
    .HJUMP  (  1 )
) u_bg(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( HS            ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .blankn     ( LHBL & LVBL   ),
    .flip       ( 1'b0          ),
    .scrx       ( scrx          ),
    .scry       ( scry          ),
    .vram_addr  ( bg_vram_raw   ),
    .code       ( bg_vram_q[11:0] ),
    .pal        ( bg_vram_q[15:12] ),
    .hflip      ( 1'b0          ),
    .vflip      ( 1'b0          ),
    .rom_addr   ( bg_rom_addr   ),
    .rom_data   ( gfx_data      ),
    .rom_cs     ( bg_rom_cs     ),
    .rom_ok     ( gfx_ok        ),
    .pxl        ( bg_pxl        )
);

// GFX ROM address mapping: 17-bit word addr → [21:2] bus
assign gfx_cs   = bg_rom_cs;
assign gfx_addr = { 3'b0, bg_rom_addr };

// -------------------------------------------------------
// Palette lookup
// Format: R[4:1]=bits[15:12], G[4:1]=bits[11:8],
//         B[4:1]=bits[7:4],   R[0]=bit[3], G[0]=bit[2], B[0]=bit[1]
// -------------------------------------------------------
assign pal_rd_addr = { 2'b0, bg_pxl[7:4], bg_pxl[3:0] };

assign red   = { pal_q[15:12], pal_q[3]   };
assign green = { pal_q[11:8],  pal_q[2]   };
assign blue  = { pal_q[7:4],   pal_q[1]   };

endmodule
