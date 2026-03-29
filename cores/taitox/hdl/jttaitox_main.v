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

module jttaitox_main(
    input                rst,
    input                clk,
    input                LVBL,

    // SDRAM ROM (0x000000-0x07FFFF)
    output        [18:1] main_addr,
    output reg           main_cs,
    input         [15:0] main_data,
    input                main_ok,

    // SDRAM Work RAM (0xF00000-0xF03FFF)
    output        [15:1] ram_addr,
    output               ram_we,
    output        [ 1:0] ram_dsn,
    output        [15:0] ram_dout,
    output               cpu_rnw,
    output reg           ram_cs,
    input         [15:0] ram_data,
    input                ram_ok,

    // Video BRAMs (palettes, sprites)
    output reg           pal_cs,      // 0xB00000-0xB00FFF
    output reg           spry_cs,     // 0xD00000-0xD005FF
    output reg           sprobj_cs,   // 0xE00000-0xE03FFF

    // BRAM read-back
    input         [15:0] pal_dout,
    input         [15:0] spry_dout,
    input         [15:0] sprobj_dout,

    // I/O
    input         [ 5:0] joystick1,
    input         [ 5:0] joystick2,
    input         [15:0] dipsw,
    input                dip_pause
);

`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, BUSn;
wire [ 2:0] FC, IPLn;
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
reg         io_cs, clr_int;
wire        intn, bus_cs, bus_busy;

assign main_addr  = A[18:1];
assign ram_addr   = A[15:1];
assign ram_dout   = cpu_dout;
assign cpu_rnw    = RnW;
assign ram_dsn    = {UDSn, LDSn};
assign ram_we     = ram_cs & ~RnW;
assign BUSn       = ASn | (LDSn & UDSn);
assign IPLn       = intn ? 3'b111 : 3'b101;   // level 5 when active
assign VPAn       = ~(!ASn && FC == 3'b111);
assign bus_cs     = main_cs | ram_cs;
assign bus_busy   = (main_cs & ~main_ok) | (ram_cs & ~ram_ok);

// Address decode — combinational
always @* begin
    main_cs     = !ASn && A[23:19] == 5'b0;      // 0x000000-0x07FFFF
    pal_cs      = !BUSn && A[23:12] == 12'b1011_0000_0000;  // 0xB00000-0xB00FFF
    spry_cs     = !BUSn && A[23:9]  == 15'b1101_0000_0000_00;  // 0xD00000-0xD005FF
    sprobj_cs   = !BUSn && A[23:14] == 10'b1110_0000_00;    // 0xE00000-0xE03FFF
    ram_cs      = !BUSn && A[23:14] == 10'b1111_1111_00;    // 0xF00000-0xF03FFF
    io_cs       = !BUSn && A[23:4]  == 20'hC0000;
    clr_int     = io_cs && !RnW;   // any IO write clears interrupt
end

// Data input mux
always @(posedge clk) begin
    cpu_din <= main_cs    ? main_data :
              ram_cs     ? ram_data  :
              pal_cs     ? pal_dout  :
              spry_cs    ? spry_dout :
              sprobj_cs  ? sprobj_dout :
              io_cs      ? (A[3:1]==3'd0 ? {8'hFF, joystick1}             :
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

// 8 MHz clock enable from 48 MHz: num=4'd1, den=5'd6
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
    .den        ( 5'd6          ),
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
    pal_cs = 0; spry_cs = 0; sprobj_cs = 0;
end
assign main_addr = 0; assign ram_addr = 0;
assign ram_dout = 0; assign ram_dsn = 0; assign ram_we = 0;
assign cpu_rnw = 1;
`endif
endmodule
