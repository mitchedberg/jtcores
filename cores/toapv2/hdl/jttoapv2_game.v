module jttoapv2_game(
    `include "jtframe_game_ports.inc"
);

wire        gp_cs;
wire        pal_cs;
wire        txt_cs;
wire        cpu_rnw;
wire        ym_cs;
wire        ym_we;
wire        io_cs;
wire [ 7:0] ym_data;
wire [18:0] gp_addr;
wire [15:0] gp_dout;
wire [15:0] pal_dout;
wire [15:0] txt_dout;

// Pixel clock: 6.75 MHz from 48 MHz (27/4 MHz; use 48*9/64 ≈ 6.75)
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk    ( clk              ),
    .n      ( 10'd9            ),
    .m      ( 10'd64           ),
    .cen    ( {pxl_cen, pxl2_cen} ),
    .cenb   (                  )
);

jtframe_vtimer #(
    .VB_START   ( 9'd239       ),
    .VB_END     ( 9'd261       ),
    .VS_START   ( 9'd247       ),
    .HCNT_END   ( 9'd431       ),
    .HB_START   ( 9'd319       ),
    .HB_END     ( 9'd431       ),
    .HS_START   ( 9'd360       )
) u_vtimer(
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .vdump      (              ),
    .vrender    (              ),
    .vrender1   (              ),
    .H          (              ),
    .Hinit      (              ),
    .Vinit      (              ),
    .LHBL       ( LHBL         ),
    .LVBL       ( LVBL         ),
    .HS         ( HS           ),
    .VS         ( VS           )
);

`ifndef NOMAIN
jttoapv2_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),
    
    // SDRAM ROM
    .main_addr  ( main_addr     ),
    .main_cs    ( main_cs       ),
    .main_data  ( main_data     ),
    .main_ok    ( main_ok       ),
    
    // SDRAM Work RAM
    .ram_addr   ( ram_addr      ),
    .ram_we     ( ram_we        ),
    .ram_dsn    ( ram_dsn       ),
    .ram_din    ( ram_din       ),
    .cpu_rnw    ( cpu_rnw       ),
    .ram_cs     ( ram_cs        ),
    .ram_data   ( ram_data      ),
    .ram_ok     ( ram_ok        ),
    
    // GP9001 VDP
    .gp_cs      ( gp_cs         ),
    .gp_addr    ( gp_addr       ),
    .gp_data    ( {16'h0,gp_dout} ),
    .gp_ok      ( 1'b1          ),
    
    // Palette RAM (BRAM)
    .pal_cs     ( pal_cs        ),
    .pal_dout   ( pal_dout      ),
    
    // Extra text ROM
    .txtrom_cs  (               ),
    .txtrom_addr(               ),
    .txtrom_data( 16'h0         ),
    .txtrom_ok  ( 1'b1          ),
    
    // Extra text RAM
    .txt_cs     ( txt_cs        ),
    .txt_dout   ( txt_dout      ),
    
    // YM2151 sound
    .ym_cs      ( ym_cs         ),
    .ym_data    ( ym_data       ),
    .ym_we      ( ym_we         ),
    
    // I/O + OKI
    .io_cs      ( io_cs         ),
    .oki_data   ( oki_data      ),
    .oki_cs     ( oki_cs        ),
    .oki_addr   ( oki_addr      ),
    .oki_ok     ( oki_ok        ),
    
    // Control
    .joystick1  ( joystick1[5:0] ),
    .joystick2  ( joystick2[5:0] ),
    .dipsw      ( dipsw[15:0]   ),
    .dip_pause  ( dip_pause     )
);
`endif

`ifndef NOSOUND
jttoapv2_snd u_snd(
    .rst        ( rst           ),
    .clk        ( clk           ),
    
    // YM2151 interface (from 68000)
    .ym_din     ( ym_data       ),
    .ym_cs      ( ym_cs         ),
    .ym_wr      ( ym_we         ),
    .ym_a0      ( 1'b0          ),
    .ym_dout    (               ),
    .ym_irq_n   (               ),
    
    // OKI interface (from 68000)
    .oki_wrdata ( 8'h0          ),
    .oki_wr     ( 1'b0          ),
    
    // OKI ROM (SDRAM)
    .oki_addr   ( oki_addr      ),
    .oki_cs     ( oki_cs        ),
    .oki_data   ( oki_data      ),
    .oki_ok     ( oki_ok        ),
    
    // Audio output
    .snd        ( snd           ),
    .sample     ( sample        )
);
`endif

jttoapv2_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .cpu_dout   ( ram_din       ),
    .gp_cs      ( gp_cs         ),
    .gp_addr    ( gp_addr[2:1]  ),
    .cpu_rnw    ( cpu_rnw       ),
    .gp_dout    ( gp_dout       ),
    .pal_cs     ( pal_cs        ),
    .pal_addr   ( ram_addr[11:1] ),
    .pal_dout   ( pal_dout      ),
    .txt_cs     ( txt_cs        ),
    .txt_addr   ( ram_addr[12:1] ),
    .txt_dout   ( txt_dout      ),
    .gfx_addr   ( gfx_addr      ),
    .gfx_cs     ( gfx_cs        ),
    .gfx_data   ( gfx_data      ),
    .gfx_ok     ( gfx_ok        ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

assign dip_flip     = 1'b0;
assign debug_view   = 8'h0;

endmodule
