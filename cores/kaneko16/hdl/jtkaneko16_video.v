module jtkaneko16_video(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL, LVBL,
    input  [12:1] cpu_addr,
    input  [15:0] cpu_dout,
    input         cpu_rnw,
    input         spr_cs, pal_cs, bgvram_cs, sprreg_cs,
    output [15:0] spr_dout, pal_dout, bgvram_dout, sprreg_dout,
    output [19:0] gfx_addr,
    output        gfx_cs,
    input  [31:0] gfx_data,
    input         gfx_ok,
    output [4:0]  red, green, blue
);
assign red=0; assign green=0; assign blue=0;
assign gfx_cs=0; assign gfx_addr=0;
assign spr_dout=16'hFFFF; assign pal_dout=16'hFFFF;
assign bgvram_dout=16'hFFFF; assign sprreg_dout=16'hFFFF;
endmodule
