module jtatari_blstroid_game(
    `include "jtframe_game_ports.inc"
);

assign pal_we = pal_cs ? {2{~cpu_rnw}} & ~ram_dsn : 2'b00;
assign pal_addr = 0;
assign red = 0;
assign green = 0;
assign blue = 0;
assign dip_flip = 0;
assign debug_view = 0;

jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk    ( clk                    ),
    .n      ( 10'd336             ),
    .m      ( 10'd1024               ),
    .cen    ( {pxl_cen, pxl2_cen}   ),
    .cenb   (                        )
);

jtframe_vtimer #(
    .VB_START   ( 9'd239   ),
    .VB_END     ( 9'd256  ),
    .VS_START   ( 9'd248   ),
    .HCNT_END   ( 9'd455             ),
    .HB_START   ( 9'd335    ),
    .HB_END     ( 9'd455             ),
    .HS_START   ( 9'd360             )
) u_vtimer(
    .clk        ( clk             ),
    .pxl_cen    ( pxl_cen         ),
    .vdump      (                 ),
    .vrender    (                 ),
    .vrender1   (                 ),
    .H          (                 ),
    .Hinit      (                 ),
    .Vinit      (                 ),
    .vs         ( vs              ),
    .hs         ( hs              ),
    .vb         ( vb              ),
    .hb         ( hb              )
);

endmodule
