module jtkaneko16_game(
    `include "jtframe_game_ports.inc"
);

// Pixel clock division: 27.164MHz -> 3.396MHz (8x divisor)
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk  ( clk ), .n ( 10'd1 ), .m ( 10'd8 ),
    .cen  ( {pxl_cen, pxl2_cen} ), .cenb ()
);

// Vertical/Horizontal timing generator
jtframe_vtimer #(
    .VB_START(9'd223), .VB_END(9'd261), .VS_START(9'd231),
    .HCNT_END(9'd395), .HB_START(9'd255), .HB_END(9'd395), .HS_START(9'd280)
) u_vtimer(
    .clk(clk), .pxl_cen(pxl_cen),
    .vdump(), .vrender(), .vrender1(), .H(), .Hinit(), .Vinit(),
    .LHBL(LHBL), .LVBL(LVBL), .HS(HS), .VS(VS)
);

// Video output stub
assign red=0;
assign green=0;
assign blue=0;

// Sound output
assign snd=0;
assign sample=0;

// I/O
assign dip_flip=0;
assign debug_view=0;

// SDRAM control signals
`ifndef NOMAIN
    // Main CPU ROM access (stub)
    assign main_cs=0;
    assign main_addr=0;
`else
    assign main_cs=0;
    assign main_addr=0;
`endif

`ifndef NOMAIN
    // Work RAM (stub)
    assign ram_cs=0;
    assign ram_addr=0;
    assign ram_we=0;
    assign ram_dsn=2'b11;
    assign ram_din=0;
`else
    assign ram_cs=0;
    assign ram_addr=0;
    assign ram_we=0;
    assign ram_dsn=2'b11;
    assign ram_din=0;
`endif

`ifndef NOSOUND
    // OKI sound ROM (stub)
    assign oki_cs=0;
    assign oki_addr=0;
`else
    assign oki_cs=0;
    assign oki_addr=0;
`endif

// Graphics ROM (stub)
assign gfx_cs=0;
assign gfx_addr=0;

endmodule
