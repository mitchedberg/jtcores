module jtraizing_game(
    `include "jtframe_game_ports.inc"
);

// Pixel clock generation: 27.164 MHz from 96 MHz system clock
// Divider: 96 / 27.164 ≈ 3.536, use frac_cen with n=9, m=64
// This generates pxl2_cen (half-clock) and pxl_cen (full clock)
jtframe_frac_cen #(.W(2), .WC(10)) u_pxlcen(
    .clk  ( clk ), .n ( 10'd9 ), .m ( 10'd64 ),
    .cen  ( {pxl_cen, pxl2_cen} ), .cenb ()
);

// Video timing: 320x224 display, 27.164 MHz pixel clock
// Horizontal: 431 total, HBlank 319-431, HSync 360-431
// Vertical: 262 total, VBlank 239-261, VSync 247-261
jtframe_vtimer #(
    .VB_START(9'd239), .VB_END(9'd261), .VS_START(9'd247),
    .HCNT_END(9'd431), .HB_START(9'd319), .HB_END(9'd431), .HS_START(9'd360)
) u_vtimer(
    .clk(clk), .pxl_cen(pxl_cen),
    .vdump(), .vrender(), .vrender1(), .H(), .Hinit(), .Vinit(),
    .LHBL(LHBL), .LVBL(LVBL), .HS(HS), .VS(VS)
);

// Video output stubs (no graphics yet)
assign red=0; assign green=0; assign blue=0;

// Audio output stubs (NOMAIN/NOSOUND handled in main and snd modules)
`ifdef JTFRAME_STEREO
assign snd_left=0; assign snd_right=0;
`else
assign snd=0;
`endif
assign sample=0;

// DIP/debug stubs
assign dip_flip=0; assign debug_view=0;

// Instantiate main CPU module with NOMAIN guard
`ifndef NOMAIN
jtraizing_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .main_addr  ( main_addr ),
    .main_cs    ( main_cs   ),
    .main_data  ( main_data ),
    .main_ok    ( main_ok   ),
    .ram_addr   ( ram_addr  ),
    .ram_we     ( ram_we    ),
    .ram_dsn    ( ram_dsn   ),
    .ram_din    ( ram_din   ),
    .cpu_rnw    ( /* unused */ ),
    .ram_cs     ( ram_cs    ),
    .ram_data   ( ram_data  ),
    .ram_ok     ( ram_ok    ),
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .dipsw      ( dipsw     ),
    .dip_pause  ( dip_pause ),
    .snd_latch  ( /* to snd */ ),
    .snd_stb    ( /* to snd */ )
);
`else
// NOMAIN stub: drive all outputs to safe defaults
assign main_addr = 19'h0;
assign main_cs   = 1'b0;
assign ram_addr  = 15'h0;
assign ram_we    = 1'b0;
assign ram_dsn   = 2'b11;
assign ram_din   = 16'h0;
assign ram_cs    = 1'b0;
`endif

// Instantiate sound module with NOSOUND guard
`ifndef NOSOUND
jtraizing_snd u_snd(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .snd_latch  ( 8'h0      ), // TODO: wire from main CPU
    .snd_stb    ( 1'b0      ), // TODO: wire from main CPU
    .snd_addr   ( snd_addr  ),
    .snd_cs     ( snd_cs    ),
    .snd_data   ( snd_data  ),
    .snd_ok     ( snd_ok    ),
    .oki_addr   ( oki_addr  ),
    .oki_cs     ( oki_cs    ),
    .oki_data   ( oki_data  ),
    .oki_ok     ( oki_ok    ),
    .snd        ( /* output to audio */ ),
    .sample     ( /* sample strobe */ ),
    .debug_bus  ( debug_bus )
);
`else
// NOSOUND stub: drive all outputs to safe defaults
assign snd_addr = 16'h0;
assign snd_cs   = 1'b0;
assign oki_addr = 20'h0;
assign oki_cs   = 1'b0;
`endif

endmodule
