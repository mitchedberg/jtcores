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

module jtnmk16_main(
    input                rst,
    input                clk,
    input                LVBL,

    // SDRAM ROM
    output        [17:1] main_addr,
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
    output reg           bgvram_cs,
    output reg           fgvram_cs,
    output reg           scroll_cs,
    output reg           io_cs,

    // CPU address for video BRAM writes
    output        [12:1] cpu_addr,
    output        [15:0] cpu_dout_o,

    // Video RAM read-back (stub: game.v returns 0)
    input         [15:0] mp_dout,    // CPU-side palette read
    input         [15:0] mbg_dout,   // CPU-side bgvram read
    input         [15:0] mfg_dout,   // CPU-side fgvram read
    input         [15:0] mscroll_dout, // CPU-side scroll read

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

assign main_addr  = A[17:1];
assign ram_addr   = A[15:1];
assign ram_din    = cpu_dout;
assign cpu_rnw    = RnW;
assign cpu_addr   = A[12:1];
assign cpu_dout_o = cpu_dout;
assign ram_dsn   = {UDSn, LDSn};
assign ram_we    = ram_cs & ~RnW;
assign BUSn      = ASn | (LDSn & UDSn);
assign IPLn      = intn ? 3'b111 : 3'b110;   // IRQ1 (vblank)
assign VPAn      = ~(!ASn && FC == 3'b111);
assign bus_cs    = main_cs | ram_cs;
assign bus_busy  = (main_cs & ~main_ok) | (ram_cs & ~ram_ok);

// Address decode — combinational
always @* begin
    main_cs    = !ASn  && A[23:18] == 6'h00;   // 0x000000-0x03FFFF
    ram_cs     = !BUSn && A[23:16] == 8'h0B;   // 0x0B0000-0x0BFFFF
    io_cs      = !BUSn && A[23:5]  == 19'h0601_80;  // 0x0C0000-0x0C001F
    scroll_cs  = !BUSn && A[23:3]  == 20'h0C204;    // 0x0C4000-0x0C4007
    pal_cs     = !BUSn && A[23:11] == 13'b0110_0100_0000;  // 0x0C8000-0x0C87FF
    bgvram_cs  = !BUSn && A[23:16] == 8'h0CC;  // 0x0CC000-0x0CFFFF
    fgvram_cs  = !BUSn && A[23:11] == 13'b0110_1000_0000;  // 0x0D0000-0x0D07FF
    clr_int    = io_cs && !RnW;   // any IO write clears interrupt
end

// Sound latch capture (at io_cs)
always @(posedge clk) begin
    if (rst) begin
        snd_latch <= 8'h0;
        snd_stb   <= 0;
    end else begin
        snd_stb <= io_cs & ~RnW;
        if (io_cs & ~RnW)
            snd_latch <= cpu_dout[7:0];
    end
end

// Data input mux
always @(posedge clk) begin
    cpu_din <= main_cs  ? main_data  :
              ram_cs   ? ram_data   :
              pal_cs   ? mp_dout    :
              bgvram_cs ? mbg_dout  :
              fgvram_cs ? mfg_dout  :
              scroll_cs ? mscroll_dout :
              io_cs    ? (A[3:1]==3'd0 ? {8'hFF, joystick1}             :
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

// 10 MHz clock enable from 48 MHz: num=5, den=24
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
    .num        ( 5'd5          ),
    .den        ( 5'd24         ),
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
    pal_cs = 0; bgvram_cs = 0; fgvram_cs = 0; scroll_cs = 0; io_cs = 0;
    snd_latch = 0;
    snd_stb = 0;
end
assign main_addr = 0; assign ram_addr = 0;
assign ram_din = 0; assign ram_dsn = 0; assign ram_we = 0;
assign cpu_rnw = 1; assign cpu_addr = 0; assign cpu_dout_o = 0;
`endif
endmodule
