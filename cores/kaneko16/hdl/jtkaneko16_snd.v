module jtkaneko16_snd(
    input         rst,
    input         clk,
    // OKI ROM (SDRAM)
    output [17:0] oki_addr,
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
`else
assign snd = 0;
assign sample = 0;
assign oki_cs = 0;
assign oki_addr = 0;
`endif

endmodule
