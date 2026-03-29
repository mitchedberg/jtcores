module jtnmk16_video(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL,
    input         LVBL,
    // CPU interface
    input  [12:1] cpu_addr,
    input  [15:0] cpu_dout,
    input         cpu_rnw,
    // Tilemap VRAM
    input         bgvram_cs,
    input         fgvram_cs,
    input         pal_cs,
    input         scroll_cs,
    output [15:0] bgvram_dout,
    output [15:0] fgvram_dout,
    output [15:0] pal_dout,
    output [15:0] scroll_dout,
    // GFX ROM (SDRAM)
    output [19:0] gfx_addr,
    output        gfx_cs,
    input  [31:0] gfx_data,
    input         gfx_ok,
    // Pixel output
    output [3:0]  red,
    output [3:0]  green,
    output [3:0]  blue
);

assign red = 4'd0;
assign green = 4'd0;
assign blue = 4'd0;
assign gfx_cs = 1'b0;
assign gfx_addr = 20'd0;
assign bgvram_dout = 16'hFFFF;
assign fgvram_dout = 16'hFFFF;
assign pal_dout = 16'hFFFF;
assign scroll_dout = 16'hFFFF;

endmodule
