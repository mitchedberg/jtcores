module jttoapv2_snd(
    input         rst,
    input         clk,
    // YM2151 interface (from 68000)
    input  [ 7:0] ym_din,
    input         ym_cs,
    input         ym_wr,
    input         ym_a0,
    output [ 7:0] ym_dout,
    output        ym_irq_n,
    // OKI interface (from 68000)
    input  [ 7:0] oki_wrdata,
    input         oki_wr,
    // OKI ROM (SDRAM)
    output [18:0] oki_addr,
    output        oki_cs,
    input  [ 7:0] oki_data,
    input         oki_ok,
    // Audio output
    output signed [15:0] snd,
    output        sample
);

`ifndef NOSOUND
assign snd = 0;
assign sample = 0;
assign oki_cs = 0;
assign oki_addr = 0;
assign ym_dout = 8'h0;
assign ym_irq_n = 1'b1;
`else
assign snd = 0;
assign sample = 0;
assign oki_cs = 0;
assign oki_addr = 0;
assign ym_dout = 8'h0;
assign ym_irq_n = 1'b1;
`endif

endmodule
