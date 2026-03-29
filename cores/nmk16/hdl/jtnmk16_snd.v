module jtnmk16_snd(
    input         rst,
    input         clk,
    // OKI interface (directly from 68000)
    input  [ 7:0] oki_wrdata,
    input         oki_wr,
    // OKI ROM (SDRAM)
    output [16:0] oki_addr,
    output        oki_cs,
    input  [ 7:0] oki_data,
    input         oki_ok,
    // Audio output
    output signed [15:0] snd,
    output        sample
);

`ifndef NOSOUND
// OKI6295 instantiation will go here
// For now, stub outputs
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
