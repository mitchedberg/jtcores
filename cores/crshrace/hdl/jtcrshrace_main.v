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
    Date: 28-3-2026 */

module jtcrshrace_main(
    input                rst,
    input                clk,
    input                LVBL,

    // SDRAM ROM
    output        [19:1] main_addr,
    output reg           rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,

    // SDRAM Work RAM
    output        [16:1] ram_addr,
    output               ram_we,
    output        [ 1:0] dsn,
    output        [15:0] main_dout,
    output               cpu_rnw,
    output reg           wram_cs,
    input         [15:0] ram_dout,
    input                ram_ok,

    // CPU bus (for video BRAMs in game.v)
    output reg           vram0_cs,
    output reg           vram1_cs,
    output reg           pal_cs,
    output reg           vregs_cs,

    // Video RAM read-back (from generated BRAM ports)
    input         [15:0] m0_dout,    // CPU-side vram0 read
    input         [15:0] m1_dout,    // CPU-side vram1 read
    input         [15:0] mp_dout,    // CPU-side palette read
    input         [15:0] mr_dout,    // CPU-side vregs read

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
reg         io_cs, sndlatch_cs, clr_int;
wire        intn, bus_cs, bus_busy;

`ifdef SIMULATION
wire [23:0] A_full = {A, 1'b0};
`endif

assign main_addr = A[19:1];
assign ram_addr  = A[16:1];
assign main_dout = cpu_dout;
assign cpu_rnw   = RnW;
assign dsn       = {UDSn, LDSn};
assign ram_we    = wram_cs & ~RnW;
assign BUSn      = ASn | (LDSn & UDSn);
assign IPLn      = intn ? 3'b111 : 3'b011;   // level 4 when active
assign VPAn      = ~(!ASn && FC == 3'b111);
assign bus_cs    = rom_cs | wram_cs;
assign bus_busy  = (rom_cs & ~rom_ok) | (wram_cs & ~ram_ok);

// Address decode — combinational
always @* begin
    rom_cs      = !ASn  && A[23:20] == 4'h0;
    vram0_cs    = !BUSn && A[23:13] == 11'b0100_0000_000;
    vram1_cs    = !BUSn && A[23:13] == 11'b0100_0000_001;
    pal_cs      = !BUSn && A[23:13] == 11'b0110_0000_000;
    vregs_cs    = !BUSn && A[23:14] == 10'b1000_0000_01;
    io_cs       = !BUSn && A[23:4]  == 20'hC0000;
    sndlatch_cs = !BUSn && A[23:2]  == 22'h300004 && !RnW;
    wram_cs     = !ASn  && A[23:17] == 7'h10;
    clr_int     = io_cs && !RnW;   // any IO write clears interrupt
end

// Sound latch capture
always @(posedge clk) begin
    if (rst) begin
        snd_latch <= 8'h0;
        snd_stb   <= 0;
    end else begin
        snd_stb <= sndlatch_cs;
        if (sndlatch_cs)
            snd_latch <= cpu_dout[7:0];
    end
end

// Data input mux
always @(posedge clk) begin
    cpu_din <= rom_cs    ? rom_data :
               wram_cs   ? ram_dout :
               vram0_cs  ? m0_dout  :
               vram1_cs  ? m1_dout  :
               pal_cs    ? mp_dout  :
               vregs_cs  ? mr_dout  :
               io_cs     ? (A[3:1]==3'd0 ? {8'hFF, joystick1}              :
                            A[3:1]==3'd1 ? {8'hFF, joystick2}              :
                            A[3:1]==3'd2 ? {dipsw[14:8], LVBL, dipsw[7:0]} :
                                           16'hFFFF) :
                           16'hFFFF;
end

// VBLANK falling-edge interrupt
jtframe_edge #(.QSET(0)) u_vbl(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .edgeof ( ~LVBL    ),
    .clr    ( clr_int  ),
    .q      ( intn     )
);

// 12 MHz clock enable from 48 MHz: num=1, den=4
jtframe_68kdtack_cen #(.W(5)) u_dtack(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_cenb   ( cpu_cenb      ),
    .bus_cs     ( bus_cs        ),
    .bus_busy   ( bus_busy      ),
    .bus_legit  ( 1'b0          ),
    .bus_ack    ( 1'b0          ),
    .ASn        ( ASn           ),
    .DSn        ( {UDSn, LDSn}  ),
    .num        ( 4'd1          ),
    .den        ( 5'd4          ),
    .DTACKn     ( DTACKn        ),
    .wait2      ( 1'b0          ),
    .wait3      ( 1'b0          ),
    .fave       (               ),
    .fworst     (               )
);

jtframe_m68k u_cpu(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .RESETn     (               ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_cenb   ( cpu_cenb      ),

    .eab        ( A             ),
    .iEdb       ( cpu_din       ),
    .oEdb       ( cpu_dout      ),

    .eRWn       ( RnW           ),
    .LDSn       ( LDSn          ),
    .UDSn       ( UDSn          ),
    .ASn        ( ASn           ),
    .VPAn       ( VPAn          ),
    .FC         ( FC            ),

    .BERRn      ( 1'b1          ),
    .HALTn      ( dip_pause     ),
    .BRn        ( 1'b1          ),
    .BGACKn     ( 1'b1          ),
    .BGn        (               ),

    .DTACKn     ( DTACKn        ),
    .IPLn       ( IPLn          )
);
`else
initial begin
    rom_cs = 0; wram_cs = 0;
    vram0_cs = 0; vram1_cs = 0;
    pal_cs = 0; vregs_cs = 0;
    snd_latch = 0;
    snd_stb = 0;
end
assign main_addr = 0; assign ram_addr = 0;
assign main_dout = 0; assign dsn = 0; assign ram_we = 0;
assign cpu_rnw = 1;
`endif
endmodule
