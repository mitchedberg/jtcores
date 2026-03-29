module jtvsystem_video(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL, LVBL,
    input  [12:1] cpu_addr,
    input  [15:0] cpu_dout,
    input         cpu_rnw,
    input         pal_cs, spr_cs, bg0_cs, bg1_cs, scroll_cs,
    output [15:0] pal_dout, spr_dout, bg0_dout, bg1_dout, scroll_dout,
    output [19:0] gfx_addr,
    output        gfx_cs,
    input  [31:0] gfx_data,
    input         gfx_ok,
    output [4:0]  red, green, blue
);
assign red=0; assign green=0; assign blue=0;
assign gfx_cs=0; assign gfx_addr=0;
assign pal_dout=16'hFFFF; assign spr_dout=16'hFFFF;
assign bg0_dout=16'hFFFF; assign bg1_dout=16'hFFFF; assign scroll_dout=16'hFFFF;
endmodule
