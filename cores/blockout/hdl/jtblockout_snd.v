/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2026-03-28 */

// Block Out: Z80 @ 3.58 MHz + YM2151 + OKI MSM6295

module jtblockout_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // Z80 ROM (SDRAM)
    output     [14:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // OKI ROM (SDRAM)
    output     [18:0] adpcm_addr,
    output            adpcm_cs,
    input      [ 7:0] adpcm_data,
    input             adpcm_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// --- Clock enable: 48 MHz / 13 = 3.69 MHz (close to 3.58 MHz) ---
reg [3:0] cen_cnt;
reg       cen_snd;

always @(posedge clk) begin
    if (rst) begin
        cen_cnt <= 0;
        cen_snd <= 0;
    end else begin
        cen_snd <= 0;
        if (cen_cnt == 4'd12) begin
            cen_cnt <= 0;
            cen_snd <= 1;
        end else begin
            cen_cnt <= cen_cnt + 4'd1;
        end
    end
end

// --- CPU signals ---
wire [15:0] A;
wire        mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire [ 7:0] cpu_dout, ram_dout;
reg  [ 7:0] cpu_din;

// --- Chip-select signals ---
reg  rom_cs, ram_cs;
reg  ym_cs, latch_rd, latch_ack, bank_wr;

// --- Bank register ---
reg  [1:0] bank;

// --- NMI flag ---
reg  nmi_n;

// --- YM2151 internal signals ---
wire [ 7:0] ym_dout;
wire        ym_irq_n;

// --- Memory decode (combinational) ---
always @(*) begin
    rom_cs  = !mreq_n && !A[15];                          // 0x0000-0x7FFF
    ram_cs  = !mreq_n &&  A[15] && !A[14];                // 0x8000-0xBFFF
end

// --- I/O decode ---
always @(*) begin
    ym_cs     = !iorq_n && (!rd_n || !wr_n) && A[7:2] == 6'b000001; // 0x04-0x07
    latch_rd  = !iorq_n && !rd_n  && A[7:0] == 8'h08;
    latch_ack = !iorq_n && !wr_n  && A[7:0] == 8'h0C;
    bank_wr   = !iorq_n && !wr_n  && A[7:0] == 8'h00;
end

// --- ROM address mux ---
// Fixed  (A[15]=0): bank 0          -> snd_addr = {2'b00, A[14:0]}
// Banked (A[15]=1): bank 1-3        -> snd_addr = {bank+1, A[14:0]}
assign snd_addr = rom_cs  ? {2'b00,       A[14:0]} :
                  bank_wr ? {bank + 2'd1, A[14:0]} : 15'd0;
assign snd_cs   = rom_cs | bank_wr;

// --- ADPCM ROM wiring ---
assign adpcm_addr = {10'b0, A[8:0]};  // Stub: simplified mapping
assign adpcm_cs   = 1'b0;             // TBD: OKI chip enable logic

// --- Bank register update ---
always @(posedge clk) begin
    if (rst)
        bank <= 2'd0;
    else if (bank_wr)
        bank <= cpu_dout[5:4];
end

// --- NMI: set on snd_stb, clear on latch_ack ---
always @(posedge clk) begin
    if (rst)
        nmi_n <= 1'b1;
    else if (snd_stb)
        nmi_n <= 1'b0;
    else if (latch_ack)
        nmi_n <= 1'b1;
end

// --- CPU data mux (registered) ---
always @(posedge clk) begin
    case (1'b1)
        rom_cs:        cpu_din <= snd_data;
        ym_cs:         cpu_din <= ym_dout;
        latch_rd:      cpu_din <= snd_latch;
        ram_cs:        cpu_din <= ram_dout;
        default:       cpu_din <= 8'hff;
    endcase
end

// --- Z80 CPU ---
jtframe_sysz80 #(.RAM_AW(13), .RECOVERY(0)) u_cpu(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen_snd   ),
    .cpu_cen (           ),
    .int_n   ( ym_irq_n  ),
    .nmi_n   ( nmi_n     ),
    .busrq_n ( 1'b1      ),
    .m1_n    (           ),
    .mreq_n  ( mreq_n    ),
    .iorq_n  ( iorq_n    ),
    .rd_n    ( rd_n      ),
    .wr_n    ( wr_n      ),
    .rfsh_n  ( rfsh_n    ),
    .halt_n  (           ),
    .busak_n (           ),
    .A       ( A         ),
    .cpu_din ( cpu_din   ),
    .cpu_dout( cpu_dout  ),
    .ram_dout( ram_dout  ),
    .ram_cs  ( ram_cs    ),
    .rom_cs  ( snd_cs    ),
    .rom_ok  ( snd_ok    )
);

// --- YM2151 ---
jt51 u_ym2151(
    .rst      ( rst          ),
    .clk      ( clk          ),
    .cen      ( cen_snd      ),
    .din      ( cpu_dout     ),
    .a0       ( A[0]         ),
    .cs_n     ( ~ym_cs       ),
    .wr_n     ( wr_n         ),
    .dout     ( ym_dout      ),
    .irq_n    ( ym_irq_n     ),
    .xleft ( snd_left     ),
    .xright( snd_right    ),
    .sample   ( sample       )
);

`else
// NOSOUND stub — all outputs driven to safe defaults
assign snd_left    = 16'd0;
assign snd_right   = 16'd0;
assign sample      = 1'b0;
assign snd_cs      = 1'b0;
assign snd_addr    = 15'd0;
assign adpcm_cs    = 1'b0;
assign adpcm_addr  = 19'd0;
`endif

endmodule
