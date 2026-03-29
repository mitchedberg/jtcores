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

// Hyper Duel 68000 main CPU module

module jthyprduel_main(
    input                rst,
    input                clk,
    input                LVBL,

    // SDRAM ROM
    output        [20:1] main_addr,
    output reg           rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,

    // SDRAM Work RAM
    output reg           wram_cs,
    input         [15:0] ram_dout,
    input                ram_ok,

    // CPU bus (for video BRAMs in game.v)
    output reg           vram_cs,
    output reg           pal_cs,

    // Video RAM read-back
    input         [15:0] vram_dout,    // CPU-side vram read
    input         [15:0] pal_dout,     // CPU-side palette read

    // I/O
    input         [ 5:0] joystick1,
    input         [ 5:0] joystick2,
    input         [15:0] dipsw,
    input                dip_pause,

    // Sound
    output reg    [ 7:0] snd_latch,
    output reg           snd_stb
);

`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, BUSn;
wire [ 2:0] FC, IPLn;
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
reg         io_cs;
wire        intn, bus_cs, bus_busy;

assign main_addr = A[20:1];
assign BUSn      = ASn | (LDSn & UDSn);
assign IPLn      = intn ? 3'b111 : 3'b011;
assign VPAn      = ~(!ASn && FC == 3'b111);
assign bus_cs    = rom_cs | wram_cs;
assign bus_busy  = (rom_cs & ~rom_ok) | (wram_cs & ~ram_ok);

// CPU instantiation
jtframe_m68k cpu(
    .rst(rst),
    .clk(clk),
    .cpu_cen(cpu_cen),
    .cpu_cenb(cpu_cenb),
    .A(A),
    .AS_n(ASn),
    .UDS_n(UDSn),
    .LDS_n(LDSn),
    .RW(RnW),
    .E(1'b0),
    .VPA_n(VPAn),
    .DTACK_n(DTACKn),
    .FC(FC),
    .oRESET_n(),
    .oHALT_n(),
    .oDout(cpu_dout),
    .iDin(cpu_din),
    .IPL_n(IPLn),
    .busack_n(1'b1)
);

assign DTACKn    = ~bus_busy & ~BUSn;
assign intn      = LVBL;

// Clock enable (12 MHz from 48 MHz)
jtframe_68kdtack_cen #(.W(3)) u_cen(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 3'd1      ),  // 12 MHz
    .den        ( 3'd4      ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .DTACKn     ( DTACKn    ),
    .fave       (           ),
    .fworst     (           )
);

// Address decode
always @* begin
    rom_cs      = !ASn && A[23:21] == 3'b000;
    wram_cs     = !BUSn && A[23:16] == 8'h20;
    vram_cs     = !BUSn && A[23:16] == 8'h30;
    pal_cs      = !BUSn && A[23:16] == 8'h40;
    io_cs       = !BUSn && A[23:16] == 8'h50;
end

// CPU data input mux
always @* begin
    if ( rom_cs )
        cpu_din = rom_data;
    else if ( wram_cs )
        cpu_din = ram_dout;
    else if ( vram_cs )
        cpu_din = vram_dout;
    else if ( pal_cs )
        cpu_din = pal_dout;
    else
        cpu_din = 16'hFFFF;
end

// Sound latch
always @(posedge clk) begin
    if (rst) begin
        snd_latch <= 8'h00;
        snd_stb   <= 1'b0;
    end else begin
        snd_stb <= 1'b0;
        if (io_cs && !RnW && !LDSn) begin
            snd_latch <= cpu_dout[7:0];
            snd_stb   <= 1'b1;
        end
    end
end

`else
assign main_addr = 20'h0;
assign rom_cs = 1'b0;
assign wram_cs = 1'b0;
assign vram_cs = 1'b0;
assign pal_cs = 1'b0;
assign snd_latch = 8'h0;
assign snd_stb = 1'b0;
`endif

endmodule
