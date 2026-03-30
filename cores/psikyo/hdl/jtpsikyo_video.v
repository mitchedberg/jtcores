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
    Date: 29-3-2026 */

// Psikyo Gunbird video renderer
// 2 BG layers, 16x16 tiles, 4bpp packed_msb (same as NMK16)
// BG VRAM 0: 4096 x 16-bit, entry = {color[15:13], tile_code[12:0]}
// BG VRAM 1: 4096 x 16-bit, same format
// Scroll regs inside vregs BRAM at specific word offsets
// Palette RAM: 4096 x 16-bit, xRGB_555
//   Tile pens start at pen 0x800: pen = 0x800 + (color + layer*0x40)*16 + pixel_nibble

module jtpsikyo_video(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL,
    input         LVBL,
    input   [8:0] hdump,
    input   [8:0] vdump,
    input         HS,
    // VRAM port B — driven by video, data comes back from BRAM
    output [12:1] vram0_addr,
    input  [15:0] vram0_dout,
    output [12:1] vram1_addr,
    input  [15:0] vram1_dout,
    // Palette port B
    output [12:1] pal_addr,
    input  [15:0] pal_dout,
    // Scroll registers port B (vregs BRAM)
    output [13:1] vregs_addr,
    input  [15:0] vregs_dout,
    // GFX ROM (SDRAM bank 2, 32-bit = tile bus)
    output [20:2] tile_addr,
    output        tile_cs,
    input  [31:0] tile_data,
    input         tile_ok,
    // Pixel output (5 bits per channel, COLORW=5)
    output [4:0]  red,
    output [4:0]  green,
    output [4:0]  blue
);

// -------------------------------------------------------
// Scroll registers — read from vregs BRAM
// Layer 0 Y scroll at word offset 0x402 → byte addr 0x804804
// Layer 0 X scroll at word offset 0x406 → byte addr 0x80480C
// Layer 1 Y scroll at word offset 0x40A → byte addr 0x804814
// Layer 1 X scroll at word offset 0x40E → byte addr 0x80481C
// vregs_addr is [13:1] (word address into 8KB vregs BRAM)
// The vregs region starts at 0x804000 (word offset 0x402 = internal offset)
// vregs BRAM addr_width=14 → AW=13 → 8192-word BRAM
// Within vregs, offsets are relative to base 0x804000:
//   word offset 0x402 = addr[12:1] = 13'h0402
//   word offset 0x406 = addr[12:1] = 13'h0406
//   word offset 0x40A = addr[12:1] = 13'h040A
//   word offset 0x40E = addr[12:1] = 13'h040E
// -------------------------------------------------------
reg [15:0] scroll0_x, scroll0_y, scroll1_x, scroll1_y;
reg  [2:0] vreg_rd_state;

// Read scroll regs from BRAM at vblank start (simple sequential fetch)
// We use a small state machine to fetch 4 scroll values
reg  [13:1] vreg_fetch_addr;
reg         vreg_fetch_en;
reg  [2:0]  vreg_fetch_step;

always @(posedge clk) begin
    if (rst) begin
        scroll0_y <= 16'd0;
        scroll0_x <= 16'd0;
        scroll1_y <= 16'd0;
        scroll1_x <= 16'd0;
        vreg_fetch_step <= 3'd0;
        vreg_fetch_en   <= 1'b0;
        vreg_fetch_addr <= 13'h0402;
    end else begin
        // Latch scroll regs each time we fetch a step
        case (vreg_fetch_step)
            3'd1: scroll0_y <= vregs_dout;   // was reading offset 0x402
            3'd2: scroll0_x <= vregs_dout;   // was reading offset 0x406
            3'd3: scroll1_y <= vregs_dout;   // was reading offset 0x40A
            3'd4: scroll1_x <= vregs_dout;   // was reading offset 0x40E
            default: ;
        endcase

        if (!LVBL && pxl_cen && vreg_fetch_step == 3'd0) begin
            // Start fetch sequence at vblank
            vreg_fetch_en   <= 1'b1;
            vreg_fetch_step <= 3'd1;
            vreg_fetch_addr <= 13'h0402;
        end else if (vreg_fetch_en && pxl_cen) begin
            if (vreg_fetch_step == 3'd4) begin
                vreg_fetch_en   <= 1'b0;
                vreg_fetch_step <= 3'd0;
            end else begin
                vreg_fetch_step <= vreg_fetch_step + 3'd1;
                case (vreg_fetch_step)
                    3'd1: vreg_fetch_addr <= 13'h0406;
                    3'd2: vreg_fetch_addr <= 13'h040A;
                    3'd3: vreg_fetch_addr <= 13'h040E;
                    default: vreg_fetch_addr <= 13'h0402;
                endcase
            end
        end
    end
end

assign vregs_addr = {vreg_fetch_addr};

// -------------------------------------------------------
// VRAM address arbitration
// jtframe_scroll outputs 11-bit vram_addr: {row[4:0], col[5:0]}
// Psikyo swizzle (same as NMK16): {row[4], col[5:0], row[3:0]}
// BRAM is 4096 words (12-bit word addr [12:1])
// We use 1 upper bit = 0 (no tilebank for BG layers)
// -------------------------------------------------------
wire [10:0] bg0_vram_raw;
wire [10:0] bg1_vram_raw;

// Same swizzle as NMK16
wire [10:0] bg0_vram_swiz = { bg0_vram_raw[10], bg0_vram_raw[5:0], bg0_vram_raw[9:6] };
wire [10:0] bg1_vram_swiz = { bg1_vram_raw[10], bg1_vram_raw[5:0], bg1_vram_raw[9:6] };

// Drive BRAM port B addresses — mux between scroll fetch needs
// (jtframe_scroll drives these during active video)
// The 12-bit word addr for a 4096-word BRAM: {1'b0, bg_vram_swiz}
assign vram0_addr = { 1'b0, bg0_vram_swiz };
assign vram1_addr = { 1'b0, bg1_vram_swiz };

// -------------------------------------------------------
// Convert chunky GFX format to jtframe planar format
// (EXACT COPY from jtnmk16_video.v)
// Chunky: gfx_data[4*px+plane] for px=0..7, plane=0..3
// Planar: rom[8*plane+(7-px)] where MSB=leftmost pixel
// -------------------------------------------------------
wire [31:0] gfx_planar;
generate
    genvar gi;
    for (gi = 0; gi < 8; gi = gi + 1) begin : chunky2planar
        assign gfx_planar[7-gi]    = tile_data[gi*4+0]; // plane 0
        assign gfx_planar[15-gi]   = tile_data[gi*4+1]; // plane 1
        assign gfx_planar[23-gi]   = tile_data[gi*4+2]; // plane 2
        assign gfx_planar[31-gi]   = tile_data[gi*4+3]; // plane 3
    end
endgenerate

// -------------------------------------------------------
// jtframe_scroll — Layer 0 (BG0)
// SIZE=16, VA=11, CW=13, PW=8, MAP_HW=10, MAP_VW=9, HJUMP=1
// VR = CW+5 = 18  → rom_addr is 18 bits [17:0]
// -------------------------------------------------------
wire [17:0] bg0_rom_addr;
wire        bg0_rom_cs;
wire  [7:0] bg0_pxl;    // {color[2:0], pixel[3:0]} but PW=8 → {pal[3:0], pxl[3:0]}
wire  [9:0] scrx0 = scroll0_x[9:0];
wire  [8:0] scry0 = scroll0_y[8:0];

jtframe_scroll #(
    .SIZE   ( 16 ),
    .VA     ( 11 ),
    .CW     ( 13 ),
    .PW     (  8 ),
    .MAP_HW ( 10 ),
    .MAP_VW (  9 ),
    .HJUMP  (  1 )
) u_bg0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( HS            ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .blankn     ( LHBL & LVBL   ),
    .flip       ( 1'b0          ),
    .scrx       ( scrx0         ),
    .scry       ( scry0         ),
    .vram_addr  ( bg0_vram_raw  ),
    .code       ( vram0_dout[12:0] ),
    .pal        ( {1'b0, vram0_dout[15:13]} ),  // 3-bit color zero-extended to 4-bit pal port
    .hflip      ( 1'b0          ),
    .vflip      ( 1'b0          ),
    .rom_addr   ( bg0_rom_addr  ),
    .rom_data   ( gfx_planar    ),
    .rom_cs     ( bg0_rom_cs    ),
    .rom_ok     ( 1'b1          ),
    .pxl        ( bg0_pxl       )
);

// -------------------------------------------------------
// jtframe_scroll — Layer 1 (BG1)
// Same parameters as BG0
// -------------------------------------------------------
wire [17:0] bg1_rom_addr;
wire        bg1_rom_cs;
wire  [7:0] bg1_pxl;
wire  [9:0] scrx1 = scroll1_x[9:0];
wire  [8:0] scry1 = scroll1_y[8:0];

// BG1 shares tile ROM; arbitrate: bg0 has priority when both request
// (simple: always drive bg0 addr, bg1 only when bg0 not requesting)
wire        tile_req = bg0_rom_cs | bg1_rom_cs;
wire [17:0] tile_rom_addr = bg0_rom_cs ? bg0_rom_addr : bg1_rom_addr;

assign tile_cs   = tile_req;
assign tile_addr = { 1'b0, tile_rom_addr };  // [20:2] = 19 bits; 1+18=19

// BG1 uses the same planar data (both layers share the tile SDRAM bus)
jtframe_scroll #(
    .SIZE   ( 16 ),
    .VA     ( 11 ),
    .CW     ( 13 ),
    .PW     (  8 ),
    .MAP_HW ( 10 ),
    .MAP_VW (  9 ),
    .HJUMP  (  1 )
) u_bg1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( HS            ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .blankn     ( LHBL & LVBL   ),
    .flip       ( 1'b0          ),
    .scrx       ( scrx1         ),
    .scry       ( scry1         ),
    .vram_addr  ( bg1_vram_raw  ),
    .code       ( vram1_dout[12:0] ),
    .pal        ( {1'b0, vram1_dout[15:13]} ),  // 3-bit color zero-extended to 4-bit pal port
    .hflip      ( 1'b0          ),
    .vflip      ( 1'b0          ),
    .rom_addr   ( bg1_rom_addr  ),
    .rom_data   ( gfx_planar    ),
    .rom_cs     ( bg1_rom_cs    ),
    .rom_ok     ( 1'b1          ),
    .pxl        ( bg1_pxl       )
);

// -------------------------------------------------------
// Palette address calculation
// Tile palettes start at pen 0x800:
//   pen = 0x800 + (color + layer*0x40)*16 + pixel_nibble
// Palette RAM is 4096 entries x 16-bit → addr [12:1]
// -------------------------------------------------------
wire [3:0] bg0_nibble = bg0_pxl[3:0];
wire [3:0] bg0_color  = bg0_pxl[7:4];  // Note: PW=8 → pal field = PW-5 = 3 bits, but pxl = 8 bits
wire [3:0] bg1_nibble = bg1_pxl[3:0];
wire [3:0] bg1_color  = bg1_pxl[7:4];

wire        bg0_opaque = (bg0_nibble != 4'd0) & LHBL & LVBL;
wire        bg1_opaque = (bg1_nibble != 4'd0) & LHBL & LVBL;

// pen = 0x800 + (color + layer*0x40)*16 + pixel_nibble
// layer 0: pen = 0x800 + color[3:0]*16 + nibble  (since layer*0x40 with layer=0)
// layer 1: pen = 0x800 + (color + 0x40)*16 + nibble = 0x800 + 0x400 + color*16 + nibble
//        = 0xC00 + color*16 + nibble
// Full 12-bit palette address:
wire [11:0] bg0_pen = 12'h800 + {4'd0, bg0_color, 4'd0} + {8'd0, bg0_nibble};
wire [11:0] bg1_pen = 12'hC00 + {4'd0, bg1_color, 4'd0} + {8'd0, bg1_nibble};

// Priority mux: BG0 over BG1, transparent falls through to black
wire [11:0] pal_rd_addr = bg0_opaque ? bg0_pen :
                          bg1_opaque ? bg1_pen :
                                       12'd0;

assign pal_addr = pal_rd_addr;  // [12:1] is 12 bits, matches pal_rd_addr[11:0]

// -------------------------------------------------------
// Pixel output — xRGB_555 palette format
// Bit layout: x[15], R[14:10], G[9:5], B[4:0]
// (same as Toaplan V2: pal_red_5 = pal_word[14:10], etc.)
// -------------------------------------------------------
assign red   = (LHBL & LVBL) ? pal_dout[14:10] : 5'd0;
assign green = (LHBL & LVBL) ? pal_dout[ 9: 5] : 5'd0;
assign blue  = (LHBL & LVBL) ? pal_dout[ 4: 0] : 5'd0;

endmodule
