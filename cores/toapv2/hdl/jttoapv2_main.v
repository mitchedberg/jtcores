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

module jttoapv2_main(
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

    // GP9001 VDP
    output reg           gp_cs,
    output        [18:0] gp_addr,
    input         [31:0] gp_data,
    input                gp_ok,

    // Palette RAM (BRAM via game.v)
    output reg           pal_cs,
    input         [15:0] pal_dout,

    // Extra text ROM
    output reg           txtrom_cs,
    output        [18:0] txtrom_addr,
    input         [15:0] txtrom_data,
    input                txtrom_ok,

    // Extra text RAM
    output reg           txt_cs,
    input         [15:0] txt_dout,

    // YM2151 sound
    output reg           ym_cs,
    output reg    [ 7:0] ym_data,
    output reg           ym_we,

    // I/O + OKI
    output reg           io_cs,
    input         [ 7:0] oki_data,
    output reg           oki_cs,
    output        [18:0] oki_addr,
    input                oki_ok,

    // Control
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
wire        intn, bus_cs, bus_busy;
reg         clr_int;

assign main_addr  = A[18:1];
assign ram_addr   = A[15:1];
assign ram_din    = cpu_dout;
assign cpu_rnw    = RnW;
assign ram_dsn    = {UDSn, LDSn};
assign ram_we     = ram_cs & ~RnW;
assign gp_addr    = { A[18:1], 1'b0 };
assign txtrom_addr= { A[18:1], 1'b0 };
assign oki_addr   = { A[18:1], 1'b0 };
assign BUSn       = ASn | (LDSn & UDSn);
assign IPLn       = intn ? 3'b111 : 3'b101;   // level 3 on vblank
assign VPAn       = ~(!ASn && FC == 3'b111);
assign bus_cs     = main_cs | ram_cs;
assign bus_busy   = (main_cs & ~main_ok) | (ram_cs & ~ram_ok) |
                    (gp_cs & ~gp_ok) | (txtrom_cs & ~txtrom_ok) | (oki_cs & ~oki_ok);

// Address decode — combinational (Truxton II memory map)
always @* begin
    main_cs   = !ASn && A[23:19] == 5'h00;          // 0x000000-0x07FFFF
    ram_cs    = !BUSn && A[23:20] == 4'h1;          // 0x100000-0x10FFFF
    gp_cs     = !BUSn && A[23:21] == 3'b001 && A[20:16]==5'h0; // 0x200000-0x20000D
    pal_cs    = !BUSn && A[23:20] == 4'h3;          // 0x300000-0x300FFF
    txt_cs    = !BUSn && A[23:20] == 4'h4;          // 0x400000-0x401FFF
    txtrom_cs = !BUSn && A[23:20] == 4'h5;          // 0x500000-0x50FFFF
    ym_cs     = !BUSn && A[23:21] == 3'b011 && A[20:19]==2'b00; // 0x600000-0x600001
    io_cs     = !BUSn && A[23:21] == 3'b011 && A[20:19]==2'b10; // 0x700000-0x70001F
    oki_cs    = !BUSn && A[23:21] == 3'b011 && A[20:19]==2'b10; // 0x700000-0x70001F
    clr_int   = io_cs && !RnW;   // any IO write clears interrupt
end

// Data input mux
always @(posedge clk) begin
    cpu_din <= main_cs   ? main_data :
               ram_cs    ? ram_data :
               gp_cs     ? gp_data[15:0] :
               pal_cs    ? pal_dout :
               txt_cs    ? txt_dout :
               txtrom_cs ? txtrom_data :
               ym_cs     ? 16'hFFFF :
               io_cs     ? (A[3:1]==3'd0 ? {10'h3FF, joystick1}           :
                            A[3:1]==3'd1 ? {10'h3FF, joystick2}           :
                            A[3:1]==3'd2 ? {dipsw[14:8], LVBL, dipsw[7:0]} :
                                           16'hFFFF) :
               oki_cs    ? {8'hFF, oki_data} :
                          16'hFFFF;
end

// YM2151 write
always @(posedge clk) begin
    if (rst) begin
        ym_data <= 8'h0;
        ym_we   <= 0;
    end else begin
        ym_we   <= ym_cs & ~RnW;
        if (ym_cs & ~RnW)
            ym_data <= cpu_dout[7:0];
    end
end

// VBLANK falling-edge interrupt
jtframe_edge #(.QSET(0)) u_vbl(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .edgeof ( ~LVBL    ),
    .clr    ( clr_int  ),
    .q      ( intn     )
);

// 16 MHz clock enable from 48 MHz: num=1, den=3
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
    .den        ( 5'd3          ),
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
    gp_cs = 0; pal_cs = 0; txt_cs = 0; txtrom_cs = 0;
    ym_cs = 0; ym_data = 0; ym_we = 0;
    io_cs = 0; oki_cs = 0;
end
assign main_addr = 0; assign ram_addr = 0; assign ram_din = 0;
assign ram_dsn = 0; assign ram_we = 0; assign cpu_rnw = 1;
assign gp_addr = 0; assign txtrom_addr = 0; assign oki_addr = 0;
`endif
endmodule
