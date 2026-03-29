// Taito B System — Color mixer / palette output
// Sources: MAME taito_b.cpp (palette_device RRRRGGGGBBBBRGBx), jtbubl_colmix pattern
// 4096 palette entries x 16 bits at 0xA00000
// Format: RRRR GGGG BBBB RGBx (5 bits per channel: upper 4 + LSB at bits[3:1])

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
    // Colours (5-bit per channel, JTFRAME_COLORW=5)
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,
    // Palette RAM interface (directly from BRAM)
    output     [11:0]   pal_addr,
    input      [15:0]   pal_dout
);

// Palette address = col_addr (12 bits = 4096 entries)
assign pal_addr = col_addr;

// Palette format: RRRR GGGG BBBB RGBx
// Bits [15:12] = R[4:1], [11:8] = G[4:1], [7:4] = B[4:1]
// Bits [3:1]   = R[0],  G[0],   B[0]     (LSBs for 5-bit color)
// Bit [0]      = unused
// 5-bit channels: R={[15:12],[3]}, G={[11:8],[2]}, B={[7:4],[1]}

// Real palette lookup: read palette BRAM and extract 5-bit RGB channels
wire [14:0] rgb_in = col_valid ?
    { pal_dout[15:12], pal_dout[3],
      pal_dout[11:8],  pal_dout[2],
      pal_dout[7:4],   pal_dout[1] } : 15'd0;

jtframe_blank #(.DLY(2), .DW(15)) u_blank(
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
