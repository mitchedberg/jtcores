module jtseta_snd(
    input         rst,
    input         clk,
    // X1-010 interface (memory-mapped from 68000)
    input  [ 7:0] snd_din,
    input  [11:0] snd_addr_in,
    input         snd_wr,
    output [ 7:0] snd_dout,
    // PCM ROM (SDRAM)
    output [18:0] pcm_addr,
    output        pcm_cs,
    input  [ 7:0] pcm_data,
    input         pcm_ok,
    // Audio output
    output signed [15:0] snd,
    output        sample
);

`ifndef NOSOUND
assign snd = 0; assign sample = 0;
assign pcm_cs = 0; assign pcm_addr = 0;
assign snd_dout = 8'h0;
`else
assign snd = 0; assign sample = 0;
assign pcm_cs = 0; assign pcm_addr = 0;
assign snd_dout = 8'h0;
`endif

endmodule
