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

module jtkaneko16_main(
    input                rst,
    input                clk,
    input                LVBL,

    // SDRAM ROM
    output        [18:1] main_addr,
    output reg           main_cs,
    input         [15:0] main_data,
    input                main_ok,

    // SDRAM Work RAM
    output        [15:1] ram_addr,
    output               ram_we,
    output        [ 1:0] ram_dsn,
    output        [15:0] ram_din,
    output               cpu_rnw,
    output reg           ram_cs,
    input         [15:0] ram_data,
    input                ram_ok,

    // CPU bus (for BRAMs in game.v)
    output reg           spr_cs,
    output reg           pal_cs,
    output reg           bgvram_cs,
    output reg           sprreg_cs,
    output reg           io_cs,
    output reg           psg0_cs,
    output reg           psg1_cs,
    output reg           oki_cs,

    // BRAM read-back
    input         [15:0] spr_dout,
    input         [15:0] pal_dout,
    input         [15:0] bgvram_dout,
    input         [15:0] sprreg_dout,

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
reg         clr_int;
wire        intn, bus_cs, bus_busy;

`ifdef SIMULATION
wire [23:0] A_full = {A, 1'b0};
`endif

assign main_addr = A[18:1];
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

// Address decode — combinational
always @* begin
    main_cs     = !ASn && A[23:18] == 6'h00;  // 0x000000-0x03FFFF
    ram_cs      = !BUSn && A[23:16] == 8'h20; // 0x200000-0x20FFFF
    spr_cs      = !BUSn && A[23:16] == 8'h30 && A[15:12] == 4'hE; // 0x30E000-0x30FFFF
    pal_cs      = !BUSn && A[23:12] == 12'h400; // 0x400000-0x400FFF
    sprreg_cs   = !BUSn && A[23:6]  == 18'h18000; // 0x600000-0x60003F
    io_cs       = !BUSn && A[23:7]  == 17'h0D00; // 0x680000-0x680007 (note: A is word addr)
    psg0_cs     = !BUSn && A[23:6]  == 18'h20000; // 0x800000-0x80001F
    psg1_cs     = !BUSn && A[23:6]  == 18'h20008; // 0x800200-0x80021F
    oki_cs      = !BUSn && A[23:10] == 14'h2001; // 0x800400-0x800401
    bgvram_cs   = !BUSn && A[23:6]  == 18'h30000; // 0xC00000-0xC0001F
    clr_int     = io_cs && !RnW;
end

// Data input mux
always @(posedge clk) begin
    cpu_din <= main_cs   ? main_data   :
              ram_cs    ? ram_data    :
              spr_cs    ? spr_dout    :
              pal_cs    ? pal_dout    :
              bgvram_cs ? bgvram_dout :
              sprreg_cs ? sprreg_dout :
              io_cs     ? (A[3:1]==3'd0 ? {8'hFF, joystick1}             :
                          A[3:1]==3'd1 ? {8'hFF, joystick2}             :
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
    main_cs = 0; ram_cs = 0;
    spr_cs = 0; pal_cs = 0; bgvram_cs = 0; sprreg_cs = 0; io_cs = 0;
    psg0_cs = 0; psg1_cs = 0; oki_cs = 0;
    snd_latch = 0;
    snd_stb = 0;
end
assign main_addr = 0; assign ram_addr = 0;
assign ram_din = 0; assign ram_dsn = 0; assign ram_we = 0;
assign cpu_rnw = 1;
`endif
endmodule
