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
// 16x16 tiles, 4bpp, 256-col x 32-row tile map (4096x512 pixel virtual space)
// Palette: 1024 entries, 16-bit custom format (5 bits per channel)
// GFX ROM: 32-bit SDRAM bus, 17-bit word address
//
// Framework constraint: jtframe_scroll_offset has HDW=10 hardcoded, so
// MAP_HW must be <= 10. We use MAP_HW=10, MAP_VW=9.
// jtframe_scroll VA=11: {row[4:0], col[5:0]}
// NMK16 VRAM swizzle: ofst = ((row>>4)<<12)|(row&0x0f)|(col<<4)
//   With MAP_HW=10: col only 6 bits (0-63), wraps in 64-col window (first pass).
//   Full 256-col requires MAP_HW=12 which exceeds framework HDW=10 limit.
//   VRAM swizzle for 11-bit output: {row[4], col[5:0], row[3:0]}

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
    input  [13:1] cpu_addr,
    input  [15:0] cpu_dout,
    input         cpu_rnw,
    // VRAM chip selects
    input         bgvram_cs,
    input         fgvram_cs,
    input         pal_cs,
    input         scroll_cs,
    input         sprite_cs,
    input         tilebank,
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
    output [21:2] spr_addr,
    output        spr_cs,
    input  [31:0] spr_data,
    input         spr_ok,
    output reg [16:2] fg_addr,
    output reg        fg_cs,
    input      [31:0] fg_data,
    input             fg_ok,
    // Pixel output (5 bits per channel)
    output [4:0]  red,
    output [4:0]  green,
    output [4:0]  blue
);

// -------------------------------------------------------
// BG VRAM  — 8192 x 16-bit words (13-bit address)
// CPU: full 13-bit address (0x0CC000-0x0CFFFF = 16 KB)
// Video: jtframe_scroll outputs 11-bit addr (MAP_HW=10, MAP_VW=9)
//        {row[4:0], col[5:0]} where row=veff[8:4], col=heff[9:4]
// NMK16 swizzle: {row[4], col[5:0], row[3:0]} = 11 bits
// -------------------------------------------------------
wire [10:0] bg_vram_raw;   // jtframe_scroll vram_addr: {row[4:0], col[5:0]}
// NMK16 swizzle: (row[4]<<10) | (col<<4) | row[3:0]
wire [10:0] bg_vram_addr = { bg_vram_raw[10], bg_vram_raw[5:0], bg_vram_raw[9:6] };

wire [15:0] bg_vram_q;
wire        bg_we = bgvram_cs & ~cpu_rnw;

jtframe_dual_ram #(.DW(16),.AW(13)) u_bgvram(
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr[13:1]),
    .we0    ( bg_we         ),
    .q0     ( bgvram_dout   ),
    .clk1   ( clk           ),
    .data1  ( 16'd0         ),
    .addr1  ( {1'b0, tilebank, bg_vram_addr} ),
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
// Scroll registers — tdragonb2 direct 16-bit values
// 0xC4000 (cpu_addr[2:1]==0): scrollX — direct 16-bit word
// 0xC4002 (cpu_addr[2:1]==1): ignored (nop write)
// 0xC4004 (cpu_addr[2:1]==2): scrollY — direct 16-bit word
// 0xC4006 (cpu_addr[2:1]==3): ignored (nop write)
// scrx truncated to MAP_HW=10 bits for jtframe_scroll
// -------------------------------------------------------
reg [15:0] scroll_x, scroll_y;
always @(posedge clk) begin
    if (rst) begin
        scroll_x <= 0;
        scroll_y <= 0;
    end else if (scroll_cs & ~cpu_rnw) begin
        case (cpu_addr[2:1])
            2'd0: scroll_x <= cpu_dout;  // 0xC4000: scrollX
            2'd2: scroll_y <= cpu_dout;  // 0xC4004: scrollY
            default: ;                   // 0xC4002, 0xC4006: ignored
        endcase
    end
end
assign scroll_dout = (cpu_addr[2:1] == 2'd2) ? scroll_y : scroll_x;

// MAP_HW=10: pass lower 10 bits of scrollX; scrY is 9 bits
wire  [9:0] scrx = scroll_x[9:0];
wire  [8:0] scry = scroll_y[8:0];

// -------------------------------------------------------
// FG VRAM — 1024 x 16-bit words (10-bit address)
// CPU: 0x0D0000-0x0D07FF -> cpu_addr[10:1]
// Video: fixed 32x32 tilemap, column-major {col[4:0], row[4:0]}
// -------------------------------------------------------
wire  [9:0] fg_vram_addr = { hdump[7:3], vdump[7:3] };
wire [15:0] fg_vram_q;
wire        fg_we = fgvram_cs & ~cpu_rnw;

jtframe_dual_ram #(.DW(16),.AW(10)) u_fgvram(
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr[10:1]),
    .we0    ( fg_we         ),
    .q0     ( fgvram_dout   ),
    .clk1   ( clk           ),
    .data1  ( 16'd0         ),
    .addr1  ( fg_vram_addr  ),
    .we1    ( 1'b0          ),
    .q1     ( fg_vram_q     )
);

// -------------------------------------------------------
// Convert NMK16 chunky GFX format to jtframe planar format
// Chunky: gfx_data[4*px+plane] for px=0..7, plane=0..3
// Planar: rom[8*plane+(7-px)] where MSB=leftmost pixel
wire [31:0] gfx_planar;
generate
    genvar gi;
    for (gi = 0; gi < 8; gi = gi + 1) begin : chunky2planar
        assign gfx_planar[7-gi]    = gfx_data[gi*4+0]; // plane 0
        assign gfx_planar[15-gi]   = gfx_data[gi*4+1]; // plane 1
        assign gfx_planar[23-gi]   = gfx_data[gi*4+2]; // plane 2
        assign gfx_planar[31-gi]   = gfx_data[gi*4+3]; // plane 3
    end
endgenerate

// -------------------------------------------------------
// jtframe_scroll — SIZE=16, MAP_HW=10, MAP_VW=9
// HDW=10 hardcoded in jtframe_scroll_offset, so MAP_HW <= 10
// VA = (MAP_HW-4) + (MAP_VW-4) = 6 + 5 = 11
// VR = CW+5 = 17
// vram_addr = {veff[8:4], heff[9:4]} = {row[4:0], col[5:0]} = 11 bits
// -------------------------------------------------------
wire [16:0] bg_rom_addr;
wire        bg_rom_cs;
wire  [7:0] bg_pxl;       // {pal[3:0], pixel[3:0]}
wire [11:1] spr_ram_addr;
wire [15:0] spr_ram_q;
wire  [7:0] spr_pxl;
wire        spr_opaque = spr_pxl[3:0] != 4'hF;
wire [12:1] cpu_spr_addr = cpu_addr[12:1];
wire        spr_we = sprite_cs & ~cpu_rnw;
// FG renderer state — fire ROM once per tile (every 8 pixels)
reg  [31:0] fg_row_latch;    // latched 32-bit row from FG ROM (8 pixels × 4 bits)
reg   [3:0] fg_palette_r;    // palette for in-flight request
reg   [3:0] fg_palette_latch;// palette for displayed tile (committed on fg_ok)
// Pixel extraction: col=0→bits[31:28], col=1→[27:24], ..., col=7→[3:0]
wire  [4:0] fg_nibble = { hdump[2:0], 2'b00 }; // 0,4,8,..,28
wire  [3:0] fg_pen    = fg_row_latch[5'd31 - fg_nibble -: 4];
wire  [7:0] fg_pxl    = { fg_palette_latch, fg_pen };
wire        fg_opaque = fg_pen != 4'd0 && LVBL && LHBL;

jtframe_scroll #(
    .SIZE   ( 16 ),
    .VA     ( 11 ),
    .CW     ( 12 ),
    .PW     (  8 ),
    .MAP_HW ( 10 ),
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
    .rom_data   ( gfx_planar    ),
    .rom_cs     ( bg_rom_cs     ),
    .rom_ok     ( gfx_ok        ),
    .pxl        ( bg_pxl        )
);

// GFX ROM address mapping: 17-bit word addr → [21:2] bus
assign gfx_cs   = bg_rom_cs;
assign gfx_addr = { 3'b0, bg_rom_addr };

// FG ROM request: fire once per 8-pixel tile column at hdump[2:0]==1
// (VRAM output fg_vram_q is valid 1 cycle after address changes, so pixel 1
//  is the earliest we have stable tile-entry data for the current tile column)
always @(posedge clk) begin
    if (rst) begin
        fg_addr         <= 15'd0;
        fg_cs           <= 1'b0;
        fg_row_latch    <= 32'd0;
        fg_palette_r    <= 4'd0;
        fg_palette_latch <= 4'd0;
    end else begin
        fg_cs <= 1'b0;

        if (pxl_cen && hdump[2:0] == 3'd1 && LVBL) begin
            fg_addr      <= { fg_vram_q[11:0], vdump[2:0] };
            fg_palette_r <= fg_vram_q[15:12];
            fg_cs        <= 1'b1;
        end

        if (fg_ok) begin
            fg_row_latch    <= fg_data;
            fg_palette_latch <= fg_palette_r;
        end
    end
end

jtnmk16_sprite u_sprite(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .pxl_cen      ( pxl_cen      ),
    .vdump        ( vdump        ),
    .hdump        ( hdump        ),
    .LHBL         ( LHBL         ),
    .LVBL         ( LVBL         ),
    .HS           ( HS           ),
    .spr_ram_addr ( spr_ram_addr ),
    .spr_ram_q    ( spr_ram_q    ),
    .cpu_spr_addr ( cpu_spr_addr ),
    .cpu_dout     ( cpu_dout     ),
    .spr_we       ( spr_we       ),
    .spr_addr     ( spr_addr     ),
    .spr_cs       ( spr_cs       ),
    .spr_data     ( spr_data     ),
    .spr_ok       ( spr_ok       ),
    .spr_pxl      ( spr_pxl      )
);

// -------------------------------------------------------
// Palette lookup
// Format: R[4:1]=bits[15:12], G[4:1]=bits[11:8],
//         B[4:1]=bits[7:4],   R[0]=bit[3], G[0]=bit[2], B[0]=bit[1]
// -------------------------------------------------------
assign pal_rd_addr = spr_opaque ? { 2'b01, spr_pxl[7:4], spr_pxl[3:0] } :
                     fg_opaque  ? { 2'b10, fg_pxl[7:4], fg_pxl[3:0] }   :
                                  { 2'b00, bg_pxl[7:4], bg_pxl[3:0] };

assign red   = { pal_q[15:12], pal_q[3]   };
assign green = { pal_q[11:8],  pal_q[2]   };
assign blue  = { pal_q[7:4],   pal_q[1]   };

`ifdef SIMULATION
reg [31:0] vid_cnt;
reg        gfx_seen;
always @(posedge clk) if(pxl_cen) begin
    vid_cnt <= vid_cnt + 1;
    // Report first GFX ROM access ever
    if(bg_rom_cs && !gfx_seen) begin
        $display("VID GFX_FIRST: addr=%05X at vid_cnt=%0d", bg_rom_addr, vid_cnt);
        gfx_seen <= 1;
    end
    // Periodically check rom_cs and rom_ok status
    if(vid_cnt[18:0]==0)
        $display("VID STATUS: rom_cs=%b rom_ok=%b code=%03X pal=%01X pxl=%02X tilebank=%b scrx=%03X scry=%03X blankn=%b vram_addr=%03X",
                 bg_rom_cs, gfx_ok, bg_vram_q[11:0], bg_vram_q[15:12], bg_pxl, tilebank, scrx, scry, LHBL&LVBL, bg_vram_addr);
end
`endif

endmodule
