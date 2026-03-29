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

// Equites Z80 + Discrete sound module
// Z80 @ 3 MHz, clock enable generated from 48 MHz system clock

module jtequites_snd(
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
    // Sample ROM (SDRAM)
    output     [11:0] snd2_addr,
    output            snd2_cs,
    input      [ 7:0] snd2_data,
    input             snd2_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// Clock enable: 48 MHz / 16 = 3 MHz
reg [3:0] cen_cnt;
reg       cen3;

always @(posedge clk) begin
    if (rst) begin
        cen_cnt <= 0;
        cen3    <= 0;
    end else begin
        cen3 <= 0;
        if (cen_cnt == 4'd15) begin
            cen_cnt <= 0;
            cen3    <= 1;
        end else begin
            cen_cnt <= cen_cnt + 4'd1;
        end
    end
end

// CPU signals
wire [15:0] A;
wire        mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire [ 7:0] cpu_dout, ram_dout;
reg  [ 7:0] cpu_din;

// Chip-select signals
reg  macc_n;
reg  rom_cs, ram_cs;
reg  latch_rd, latch_ack, sample_cs;

// NMI flag
reg  nmi_n;

// Memory decode
always @(*) begin
    macc_n    =  mreq_n | ~rfsh_n;
    rom_cs    = !macc_n && !A[15];
    ram_cs    = !macc_n &&  A[15] && A[14:9] == 6'b000000;
end

// I/O decode
always @(*) begin
    latch_rd  = !iorq_n && !rd_n  && A[7:0] == 8'h08;
    latch_ack = !iorq_n && !wr_n  && A[7:0] == 8'h0C;
    sample_cs = !iorq_n && (!rd_n || !wr_n) && A[7:2] == 6'b000000;
end

// ROM address
assign snd_addr = rom_cs ? A[14:0] : 15'd0;
assign snd_cs   = rom_cs;

// Sample ROM (discrete sample playback)
assign snd2_addr = sample_cs ? A[11:0] : 12'd0;
assign snd2_cs   = sample_cs & !rd_n;

// NMI: set on snd_stb, clear on latch_ack
always @(posedge clk) begin
    if (rst)
        nmi_n <= 1'b1;
    else if (snd_stb)
        nmi_n <= 1'b0;
    else if (latch_ack)
        nmi_n <= 1'b1;
end

// CPU data mux
always @(posedge clk) begin
    case (1'b1)
        rom_cs:           cpu_din <= snd_data;
        sample_cs:        cpu_din <= snd2_data;
        latch_rd:         cpu_din <= snd_latch;
        ram_cs:           cpu_din <= ram_dout;
        default:          cpu_din <= 8'hff;
    endcase
end

// Z80 CPU
jtframe_sysz80 #(.RAM_AW(9), .RECOVERY(0)) u_cpu(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen3      ),
    .cpu_cen (           ),
    .int_n   ( 1'b1      ),
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

// Discrete sound synthesis stub (not implemented)
// For now, output silence. Full implementation would involve
// discrete TTL logic emulation based on CPU outputs.
assign snd_left  = 16'd0;
assign snd_right = 16'd0;
assign sample    = 1'b0;

`else
// NOSOUND stub
assign snd_left    = 16'd0;
assign snd_right   = 16'd0;
assign sample      = 1'b0;
assign snd_cs      = 1'b0;
assign snd_addr    = 15'd0;
assign snd2_cs     = 1'b0;
assign snd2_addr   = 12'd0;
`endif

endmodule
