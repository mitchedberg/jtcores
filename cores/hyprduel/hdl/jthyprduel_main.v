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
    output        [15:1] ram_addr,
    output               ram_we,
    output        [ 1:0] dsn,
    output        [15:0] main_dout,
    output               cpu_rnw,
    output reg           wram_cs,
    input         [15:0] ram_dout,
    input                ram_ok,

    // CPU bus (for video BRAMs in game.v)
    output reg           pal_cs,
    output reg           vram_cs,

    // Video RAM read-back (from generated BRAM ports)
    input         [15:0] mp_dout,    // CPU-side palette read
    input         [15:0] m0_dout,    // CPU-side vram read

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

`ifdef SIMULATION
wire [23:0] A_full = {A, 1'b0};
`endif

assign main_addr = A[20:1];
assign ram_addr  = A[15:1];
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
    rom_cs      = !ASn  && A[23:21] == 3'b000;
    wram_cs     = !BUSn && A[23:16] == 8'h20;
    vram_cs     = !BUSn && A[23:16] == 8'h30;
    pal_cs      = !BUSn && A[23:16] == 8'h40;
    io_cs       = !BUSn && A[23:16] == 8'h50;
end

// CPU data input mux (registered, matching psikyo pattern)
always @(posedge clk) begin
    case (1'b1)
        rom_cs:   cpu_din <= rom_data;
        wram_cs:  cpu_din <= ram_dout;
        vram_cs:  cpu_din <= m0_dout;
        pal_cs:   cpu_din <= mp_dout;
        default:  cpu_din <= 16'hffff;
    endcase
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
    //.E(1'b0),
    .VPAn(VPAn),
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

`else
assign main_addr = 20'h0;
assign ram_addr  = 15'h0;
assign main_dout = 16'h0;
assign cpu_rnw   = 1'b1;
assign dsn       = 2'b11;
assign ram_we    = 1'b0;
assign rom_cs    = 1'b0;
assign wram_cs   = 1'b0;
assign vram_cs   = 1'b0;
assign pal_cs    = 1'b0;
assign snd_latch = 8'h0;
assign snd_stb   = 1'b0;
`endif

endmodule
