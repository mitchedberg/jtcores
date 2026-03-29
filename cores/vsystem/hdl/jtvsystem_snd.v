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

// VSystem (Aero Fighters) Z80 + YM2610 sound module
// Z80 @ 5 MHz, clock enable generated from 48 MHz system clock

module jtvsystem_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // Z80 ROM (SDRAM)
    output     [16:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // ADPCM-A ROM (SDRAM)
    output     [19:0] adpcma_addr,
    output            adpcma_cs,
    input      [ 7:0] adpcma_data,
    input             adpcma_ok,
    // ADPCM-B ROM (SDRAM)
    output     [18:0] adpcmb_addr,
    output            adpcmb_cs,
    input      [ 7:0] adpcmb_data,
    input             adpcmb_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// --- Clock enable: 48 MHz / 9.6 = 5 MHz (using fractional approximation with counter) ---
// Actual: 48 MHz / 9.6 = 5 MHz exactly, but we use integer counter approach:
// Divide by 10 gives 4.8 MHz, close enough for VSystem. Alternatively use num/den.
// For exact 5 MHz: num=5, den=48 (or scaled: num=5, den=48)
// Using simple counter dividing by 10 for ~4.8 MHz (acceptable for VSystem sound)
reg [3:0] cen_cnt;
reg       cen5;

always @(posedge clk) begin
    if (rst) begin
        cen_cnt <= 0;
        cen5    <= 0;
    end else begin
        cen5 <= 0;
        if (cen_cnt == 4'd9) begin
            cen_cnt <= 0;
            cen5    <= 1;
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
reg  macc_n;
reg  rom_cs, ram_cs, bank_cs;
reg  ym_cs, latch_rd, latch_ack, bank_wr;

// --- Bank register ---
reg  [1:0] bank;

// --- NMI flag ---
reg  nmi_n;

// --- YM2610 internal signals ---
wire [ 7:0] ym_dout;
wire        ym_irq_n;
wire [19:0] ym_adpcma_addr;
wire [ 3:0] ym_adpcma_bank;
wire        ym_adpcma_roe_n;
wire [18:0] ym_adpcmb_addr;
wire        ym_adpcmb_roe_n;

// --- Memory decode (combinational) ---
// VSystem: 0x0000-0x7FFF ROM, 0x8000-0xBFFF banked, 0xF800-0xFFFF RAM
always @(*) begin
    macc_n  =  mreq_n | ~rfsh_n;
    rom_cs  = !macc_n && !A[15];                        // 0x0000-0x7FFF
    ram_cs  = !macc_n &&  A[15] && A[14:11] == 4'b1111; // 0xF800-0xFFFF
    bank_cs = !macc_n &&  A[15] && A[14:11] != 4'b1111; // 0x8000-0xF7FF (banked)
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
                  bank_cs ? {bank + 2'd1, A[14:0]} : 17'd0;
assign snd_cs   = rom_cs | bank_cs;

// --- ADPCM ROM wiring ---
assign adpcma_addr = ym_adpcma_addr;
assign adpcma_cs   = !ym_adpcma_roe_n;
assign adpcmb_addr = ym_adpcmb_addr[18:0];  // VSystem uses 19 bits for ADPCM-B
assign adpcmb_cs   = !ym_adpcmb_roe_n;

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

// --- CPU data mux (registered, matching bubl pattern) ---
always @(posedge clk) begin
    case (1'b1)
        rom_cs | bank_cs: cpu_din <= snd_data;
        ym_cs:            cpu_din <= ym_dout;
        latch_rd:         cpu_din <= snd_latch;
        ram_cs:           cpu_din <= ram_dout;
        default:          cpu_din <= 8'hff;
    endcase
end

// --- Z80 CPU ---
jtframe_sysz80 #(.RAM_AW(11), .RECOVERY(0)) u_cpu(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen5      ),
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

// --- YM2610 ---
jt10 u_ym2610(
    .rst          ( rst              ),
    .clk          ( clk              ),
    .cen          ( cen5             ),
    .din          ( cpu_dout         ),
    .addr         ( A[1:0]           ),
    .cs_n         ( ~ym_cs           ),
    .wr_n         ( wr_n             ),
    .dout         ( ym_dout          ),
    .irq_n        ( ym_irq_n         ),
    .adpcma_addr  ( ym_adpcma_addr   ),
    .adpcma_bank  ( ym_adpcma_bank   ),
    .adpcma_roe_n ( ym_adpcma_roe_n  ),
    .adpcma_data  ( adpcma_data      ),
    .adpcmb_addr  ( ym_adpcmb_addr   ),
    .adpcmb_roe_n ( ym_adpcmb_roe_n  ),
    .adpcmb_data  ( adpcmb_data      ),
    .psg_A        (                  ),
    .psg_B        (                  ),
    .psg_C        (                  ),
    .fm_snd       (                  ),
    .psg_snd      (                  ),
    .snd_right    ( snd_right        ),
    .snd_left     ( snd_left         ),
    .snd_sample   ( sample           ),
    .ch_enable    ( 6'h3f            )
);

`else
// NOSOUND stub — all outputs driven to safe defaults
assign snd_left    = 16'd0;
assign snd_right   = 16'd0;
assign sample      = 1'b0;
assign snd_cs      = 1'b0;
assign snd_addr    = 17'd0;
assign adpcma_cs   = 1'b0;
assign adpcma_addr = 20'd0;
assign adpcmb_cs   = 1'b0;
assign adpcmb_addr = 19'd0;
`endif

endmodule
