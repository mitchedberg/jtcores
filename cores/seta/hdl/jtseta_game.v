module jtseta_game(
    `include "jtframe_game_ports.inc"
);

jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk  ( clk ), .n ( 10'd1 ), .m ( 10'd8 ),
    .cen  ( {pxl_cen, pxl2_cen} ), .cenb ()
);

jtframe_vtimer #(
    .VB_START(9'd239), .VB_END(9'd261), .VS_START(9'd247),
    .HCNT_END(9'd511), .HB_START(9'd383), .HB_END(9'd511), .HS_START(9'd400)
) u_vtimer(
    .clk(clk), .pxl_cen(pxl_cen),
    .vdump(), .vrender(), .vrender1(), .H(), .Hinit(), .Vinit(),
    .LHBL(LHBL), .LVBL(LVBL), .HS(HS), .VS(VS)
);

assign red=0; assign green=0; assign blue=0;
assign snd=0; assign sample=0;
assign dip_flip=0; assign debug_view=0;
assign main_cs=0; assign main_addr=0;
assign ram_cs=0; assign ram_addr=0; assign ram_we=0; assign ram_dsn=2'b11; assign ram_din=0;
assign pcm_cs=0; assign pcm_addr=0;
assign gfx_cs=0; assign gfx_addr=0;

endmodule
