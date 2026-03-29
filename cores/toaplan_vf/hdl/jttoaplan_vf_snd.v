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

// V-Five: Z80 @ 4 MHz + YM2151

module jttoaplan_vf_snd(
    input             rst,
    input             clk,
    // Sound latch from main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    // Z80 ROM (SDRAM)
    output     [13:0] snd_addr,
    output            snd_cs,
    input      [ 7:0] snd_data,
    input             snd_ok,
    // Audio output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    // Debug
    input      [ 7:0] debug_bus
);

`ifndef NOSOUND

// --- Clock enable: 48 MHz / 12 = 4 MHz ---
reg [3:0] cen_cnt;
reg       cen4;

always @(posedge clk) begin
    if (rst) begin
        cen_cnt <= 0;
        cen4    <= 0;
    end else begin
        cen4 <= 0;
        if (cen_cnt == 4'd11) begin
            cen_cnt <= 0;
            cen4    <= 1;
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
reg  ym_cs, latch_rd, latch_ack;

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
    ym_cs     = !iorq_n && (!rd_n || !wr_n) && A[7:1] == 7'b0000_000; // 0x00-0x01
    latch_rd  = !iorq_n && !rd_n  && A[7:0] == 8'h02;
    latch_ack = !iorq_n && !wr_n  && A[7:0] == 8'h02;
end

// --- ROM address ---
assign snd_addr = rom_cs ? A[13:0] : 14'd0;
assign snd_cs   = rom_cs;

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
jtframe_sysz80 #(.RAM_AW(14), .RECOVERY(0)) u_cpu(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen4      ),
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
    .cen      ( cen4         ),
    .din      ( cpu_dout     ),
    .a0       ( A[0]         ),
    .cs_n     ( ~ym_cs       ),
    .wr_n     ( wr_n         ),
    .dout     ( ym_dout      ),
    .irq_n    ( ym_irq_n     ),
    .left     ( snd_left     ),
    .right    ( snd_right    ),
    .sample   ( sample       )
);

`else
// NOSOUND stub — all outputs driven to safe defaults
assign snd_left    = 16'd0;
assign snd_right   = 16'd0;
assign sample      = 1'b0;
assign snd_cs      = 1'b0;
assign snd_addr    = 14'd0;
`endif

endmodule
