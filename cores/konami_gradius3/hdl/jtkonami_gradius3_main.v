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

// Konami Gradius 3 68000 main CPU module

module jtkonami_gradius3_main(
    input                rst,
    input                clk,
    input                LVBL,

    // SDRAM ROM
    output        [19:1] main_addr,
    output reg           rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,

    // SDRAM Sub ROM
    output        [19:1] sub_addr,
    output reg           sub_cs,
    input         [15:0] sub_data,
    input                sub_ok,

    // CPU bus (for video BRAMs in game.v)
    output reg           tile_cs,
    output reg           work_cs,

    // Video RAM read-back
    input         [15:0] tile_dout,   // CPU-side tile read
    input         [15:0] work_dout,   // CPU-side work RAM read

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

assign main_addr = A[19:1];
assign sub_addr  = A[19:1];
assign BUSn      = ASn | (LDSn & UDSn);
assign IPLn      = intn ? 3'b111 : 3'b011;
assign VPAn      = ~(!ASn && FC == 3'b111);
assign bus_cs    = rom_cs | sub_cs;
assign bus_busy  = (rom_cs & ~rom_ok) | (sub_cs & ~sub_ok);

// CPU instantiation
jtframe_m68k cpu(
    .rst(rst),
    .clk(clk),
    .cpu_cen(cpu_cen),
    .cpu_cenb(cpu_cenb),
    .eab(A),
    .ASn(ASn),
    .UDSn(UDSn),
    .LDSn(LDSn),
    .eRWn(RnW),
    .VPAn(VPAn),
    .DTACKn(DTACKn),
    .FC(FC),
    .RESETn(),
    .oEdb(cpu_dout),
    .iEdb(cpu_din),
    .IPLn(IPLn),
    .HALTn(1'b1),
    .BERRn(1'b1),
    .BRn(1'b1),
    .BGn()
);

assign DTACKn    = ~bus_busy & ~BUSn;
assign intn      = LVBL;

// Address decode
always @* begin
    rom_cs      = !ASn && A[23:19] == 5'b0_0000;
    sub_cs      = !ASn && A[23:19] == 5'b0_0001;
    tile_cs     = !BUSn && A[23:16] == 8'h20;
    work_cs     = !BUSn && A[23:16] == 8'h30;
    io_cs       = !BUSn && A[23:16] == 8'h40;
end

// CPU data input mux
always @* begin
    if ( rom_cs )
        cpu_din = rom_data;
    else if ( sub_cs )
        cpu_din = sub_data;
    else if ( tile_cs )
        cpu_din = tile_dout;
    else if ( work_cs )
        cpu_din = work_dout;
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
assign main_addr = 19'h0;
assign sub_addr = 19'h0;
assign rom_cs = 1'b0;
assign sub_cs = 1'b0;
assign tile_cs = 1'b0;
assign work_cs = 1'b0;
assign snd_latch = 8'h0;
assign snd_stb = 1'b0;
`endif

endmodule
