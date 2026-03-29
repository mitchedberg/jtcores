module jtraizing_video(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL, LVBL,
    input  [15:0] cpu_dout,
    input         gp_cs, pal_cs, txt_cs,
    input  [ 2:1] gp_addr,
    input  [11:1] pal_addr,
    input  [12:1] txt_addr,
    input         cpu_rnw,
    output [15:0] gp_dout, pal_dout, txt_dout,
    output [20:0] gfx_addr,
    output        gfx_cs,
    input  [31:0] gfx_data,
    input         gfx_ok,
    output [3:0]  red, green, blue
);
assign red=0; assign green=0; assign blue=0;
assign gfx_cs=0; assign gfx_addr=0;
assign gp_dout=16'h0; assign pal_dout=16'h0; assign txt_dout=16'h0;
endmodule
