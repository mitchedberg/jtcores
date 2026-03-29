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

module jtseta_main(
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

    // CPU bus (for video BRAMs in game.v)
    output reg           pal_cs,
    output reg           io_cs,
    output reg           spr_cs,
    output reg           bg0_cs,
    output reg           bg1_cs,
    output reg           snd_cs,
    output reg           sndbank_cs,

    // Video RAM read-back
    input         [15:0] mp_dout,    // CPU-side palette read
    input         [15:0] m_io_dout,  // CPU-side io read
    input         [15:0] ms_dout,    // CPU-side sprite read
    input         [15:0] m0_dout,    // CPU-side bg0 read
    input         [15:0] m1_dout,    // CPU-side bg1 read
    input         [15:0] m_snd_dout, // CPU-side sound read

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

assign main_addr = A[18:1];
assign ram_addr  = A[15:1];
assign ram_din   = cpu_dout;
assign cpu_rnw   = RnW;
assign ram_dsn   = {UDSn, LDSn};
assign ram_we    = ram_cs & ~RnW;
assign BUSn      = ASn | (LDSn & UDSn);
assign IPLn      = intn ? 3'b111 : 3'b101;   // level 3 when active
assign VPAn      = ~(!ASn && FC == 3'b111);
assign bus_cs    = main_cs | ram_cs;
assign bus_busy  = (main_cs & ~main_ok) | (ram_cs & ~ram_ok);

// Address decode — combinational
always @* begin
    main_cs     = !ASn  && A[23:19] == 5'h0;
    ram_cs      = !BUSn && A[23:17] == 7'd1;
    pal_cs      = !BUSn && A[23:12] == 12'h200;
    io_cs       = !BUSn && A[23:3]  == 21'h600_00;
    spr_cs      = !BUSn && A[23:10] == 14'b0111_0000_0000;
    bg0_cs      = !BUSn && A[23:12] == 12'h800;
    bg1_cs      = !BUSn && A[23:12] == 12'h880;
    snd_cs      = !BUSn && A[23:10] == 14'b1010_0000_0000;
    sndbank_cs  = !BUSn && A[23:1]  == 23'b1011_0000_0000_0000_0000_000;
    clr_int     = io_cs && !RnW;
end

// Sound latch capture
always @(posedge clk) begin
    if (rst) begin
        snd_latch <= 8'h0;
        snd_stb   <= 0;
    end else begin
        snd_stb <= sndbank_cs;
        if (sndbank_cs)
            snd_latch <= cpu_dout[7:0];
    end
end

// Data input mux
always @(posedge clk) begin
    cpu_din <= main_cs   ? main_data :
              ram_cs    ? ram_data :
              pal_cs    ? mp_dout :
              io_cs     ? m_io_dout :
              spr_cs    ? ms_dout :
              bg0_cs    ? m0_dout :
              bg1_cs    ? m1_dout :
              snd_cs    ? m_snd_dout :
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

// 8 MHz clock enable from 48 MHz: num=1, den=6
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
    pal_cs = 0; io_cs = 0; spr_cs = 0;
    bg0_cs = 0; bg1_cs = 0; snd_cs = 0; sndbank_cs = 0;
    snd_latch = 0; snd_stb = 0;
end
assign main_addr = 0; assign ram_addr = 0;
assign ram_din = 0; assign ram_dsn = 0; assign ram_we = 0;
assign cpu_rnw = 1;
`endif
endmodule
