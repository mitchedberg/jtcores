// Taito B System — Color mixer / palette output
// Sources: MAME taito_b.cpp (palette_device RRRRGGGGBBBBRGBx), jtbubl_colmix pattern
// 4096 palette entries x 16 bits at 0xA00000
// Format: RRRR GGGG BBBB RGBx (4+1 bits per channel, we use 4-bit output)

module jttaitob_colmix(
    input               clk,
    input               pxl_cen,
    // Screen
    input               preLHBL,
    input               preLVBL,
    output              LHBL,
    output              LVBL,
    // Pixel input from TC0180VCU
    input      [11:0]   col_addr,  // {layer_base[3:0], color[5:0], pixel[3:0]} or similar
    input               col_valid, // pixel is non-transparent
    // Colours
    output     [ 3:0]   red,
    output     [ 3:0]   green,
    output     [ 3:0]   blue,
    // Palette RAM interface (directly from BRAM)
    output     [11:0]   pal_addr,
    input      [15:0]   pal_dout
);

// Palette address = col_addr (12 bits = 4096 entries)
assign pal_addr = col_addr;

// Palette format: RRRR GGGG BBBB RGBx
// Bits [15:12] = R[7:4], [11:8] = G[7:4], [7:4] = B[7:4]
// Bits [3:1] = R[0],G[0],B[0] (LSBs for 5-bit color)
// Bit [0] = unused
// For 4-bit output, use upper nibbles only

// Real palette lookup: read palette BRAM and extract RGB nibbles
wire [11:0] rgb_in = col_valid ?
    { pal_dout[15:12], pal_dout[11:8], pal_dout[7:4] } : 12'd0;

jtframe_blank #(.DLY(2), .DW(12)) u_blank(
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
