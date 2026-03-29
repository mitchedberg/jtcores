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

    Author: Jose Tejada Gomez. Date: 28-3-2026 */

module jtraizing_main(
    input                rst, clk, LVBL,
    output        [19:1] main_addr, output reg main_cs,
    input         [15:0] main_data, input main_ok,
    output        [15:1] ram_addr, output ram_we, output [1:0] ram_dsn,
    output        [15:0] ram_din, output cpu_rnw, output reg ram_cs,
    input         [15:0] ram_data, input ram_ok,
    input         [ 5:0] joystick1, joystick2, input [15:0] dipsw, input dip_pause,
    output reg    [ 7:0] snd_latch, output reg snd_stb);

`ifndef NOMAIN
wire [23:1] A;
wire cpu_cen, cpu_cenb, UDSn, LDSn, RnW, ASn, VPAn, DTACKn, BUSn;
wire [2:0] FC, IPLn;
wire [15:0] cpu_dout;
reg [15:0] cpu_din;
reg io_cs, sndlatch_cs, clr_int;
wire intn, bus_cs, bus_busy;

assign main_addr = A[19:1];
assign ram_addr  = A[15:1];
assign ram_din   = cpu_dout;
assign cpu_rnw   = RnW;
assign ram_dsn   = {UDSn, LDSn};
assign ram_we    = ram_cs & ~RnW;
assign BUSn      = ASn | (LDSn & UDSn);
assign IPLn      = intn ? 3'b111 : 3'b011;
assign VPAn      = ~(!ASn && FC == 3'b111);
assign bus_cs    = main_cs | ram_cs;
assign bus_busy  = (main_cs & ~main_ok) | (ram_cs & ~ram_ok);

always @* begin
    main_cs = !ASn && A[23:20] == 4'h0;
    ram_cs = !BUSn && A[23:17] == 7'b0001_000;
    io_cs = !BUSn && A[23:6] == 18'b0010_0001_1100_0000;
    sndlatch_cs = !BUSn && A[23:1] == 23'h10C000 && !RnW;
    clr_int = io_cs && !RnW;
end

always @(posedge clk)
    if (rst) snd_latch <= 0; else if (sndlatch_cs) snd_latch <= cpu_dout[7:0];

always @(posedge clk) snd_stb <= sndlatch_cs;

always @(posedge clk)
    cpu_din <= main_cs ? main_data : ram_cs ? ram_data :
               io_cs ? (A[3:1]==3'd0 ? {8'hFF, joystick1} :
                        A[3:1]==3'd1 ? {8'hFF, joystick2} :
                        A[3:1]==3'd2 ? {dipsw[14:8], LVBL, dipsw[7:0]} : 16'hFFFF) : 16'hFFFF;

jtframe_edge #(.QSET(0)) u_vbl(.rst(rst), .clk(clk), .edgeof(~LVBL), .clr(clr_int), .q(intn));

jtframe_68kdtack_cen #(.W(5)) u_dtack(
    .rst(rst), .clk(clk), .cpu_cen(cpu_cen), .cpu_cenb(cpu_cenb),
    .bus_cs(bus_cs), .bus_busy(bus_busy), .bus_legit(1'b0), .bus_ack(1'b0),
    .ASn(ASn), .DSn({UDSn, LDSn}), .num(4'd1), .den(5'd3),
    .DTACKn(DTACKn), .wait2(1'b0), .wait3(1'b0), .fave(), .fworst());

jtframe_m68k u_cpu(
    .clk(clk), .rst(rst), .cpu_cen(cpu_cen), .cpu_cenb(cpu_cenb),
    .eab(A), .iEdb(cpu_din), .oEdb(cpu_dout),
    .eRWn(RnW), .LDSn(LDSn), .UDSn(UDSn), .ASn(ASn), .VPAn(VPAn), .FC(FC),
    .BERRn(1'b1), .HALTn(dip_pause), .BRn(1'b1), .BGACKn(1'b1),
    .DTACKn(DTACKn), .IPLn(IPLn));
`else
initial begin
    main_cs = 0; ram_cs = 0; snd_latch = 0; snd_stb = 0;
end
assign main_addr = 0; assign ram_addr = 0; assign ram_din = 0;
assign ram_dsn = 2'b11; assign ram_we = 0; assign cpu_rnw = 1;
`endif
endmodule
