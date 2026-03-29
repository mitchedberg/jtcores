module jttaitox_video(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL, LVBL,
    input  [12:1] cpu_addr,
    input  [15:0] cpu_dout,
    input         cpu_rnw,
    input         pal_cs, spry_cs, sprobj_cs,
    output [15:0] pal_dout, spry_dout, sprobj_dout,
    output [18:0] gfx_addr,
    output        gfx_cs,
    input  [31:0] gfx_data,
    input         gfx_ok,
    output [4:0]  red, green, blue
);
assign red=0; assign green=0; assign blue=0;
assign gfx_cs=0; assign gfx_addr=0;
assign pal_dout=16'hFFFF; assign spry_dout=16'hFFFF; assign sprobj_dout=16'hFFFF;
endmodule
