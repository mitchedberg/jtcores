module jttoapv2_game(
    `include "jtframe_game_ports.inc"
);

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
    .gp_cs      ( gfx_cs        ),
    .gp_addr    ( gfx_addr      ),
    .gp_data    ( gfx_data      ),
    .gp_ok      ( gfx_ok        ),
    
    // Palette RAM (BRAM)
    .pal_cs     (               ),
    .pal_dout   ( 16'h0         ),
    
    // Extra text ROM
    .txtrom_cs  (               ),
    .txtrom_addr(               ),
    .txtrom_data( 16'h0         ),
    .txtrom_ok  ( 1'b1          ),
    
    // Extra text RAM
    .txt_cs     (               ),
    .txt_dout   ( 16'h0         ),
    
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
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .dipsw      ( dipsw         ),
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

// Video outputs stubbed to 0
assign red          = 4'h0;
assign green        = 4'h0;
assign blue         = 4'h0;
assign dip_flip     = 1'b0;
assign debug_view   = 8'h0;

endmodule
