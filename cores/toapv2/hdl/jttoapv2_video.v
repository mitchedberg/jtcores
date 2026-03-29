module jttoapv2_video(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL,
    input         LVBL,
    // GP9001 indirect interface (from CPU)
    input  [15:0] cpu_dout,
    input         gp_cs,
    input  [ 2:1] gp_addr,
    input         cpu_rnw,
    output [15:0] gp_dout,
    // Palette
    input         pal_cs,
    input  [11:1] pal_addr,
    output [15:0] pal_dout,
    // Text layer
    input         txt_cs,
    input  [12:1] txt_addr,
    output [15:0] txt_dout,
    // GFX ROM (SDRAM)
    output [18:0] gfx_addr,
    output        gfx_cs,
    input  [31:0] gfx_data,
    input         gfx_ok,
    // Pixel output
    output [3:0]  red,
    output [3:0]  green,
    output [3:0]  blue
);

assign red = 0; assign green = 0; assign blue = 0;
assign gfx_cs = 0; assign gfx_addr = 0;
assign gp_dout = 16'h0;
assign pal_dout = 16'h0;
assign txt_dout = 16'h0;

endmodule
