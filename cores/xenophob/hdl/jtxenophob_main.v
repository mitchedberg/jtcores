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

module jtxenophob_main(
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
    output reg           pal_cs,

    // Video RAM read-back (from generated BRAM ports)
    input         [15:0] mp_dout,    // CPU-side palette read

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
    wram_cs     = !ASn  && A[23:17] == 7'h10;
    pal_cs      = !BUSn && A[23:16] == 8'h40;
    io_cs       = !BUSn && A[23:16] == 8'h50;
    sndlatch_cs = !BUSn && A[23:2]  == 22'h300004 && !RnW;
end

// CPU data mux (registered, matching psikyo pattern)
always @(posedge clk) begin
    case (1'b1)
        rom_cs:   cpu_din <= rom_data;
        wram_cs:  cpu_din <= ram_dout;
        pal_cs:   cpu_din <= mp_dout;
        default:  cpu_din <= 16'hffff;
    endcase
end

// Interrupt control
reg intn_r;
always @(posedge clk) begin
    if (rst)
        intn_r <= 1'b0;
    else if (clr_int)
        intn_r <= 1'b0;
    else if (!LVBL)
        intn_r <= 1'b1;
end
assign intn = intn_r;

// Sound latch write
always @(posedge clk) begin
    if (rst) begin
        snd_latch <= 8'h00;
        snd_stb   <= 1'b0;
    end else begin
        snd_stb <= 1'b0;
        if (sndlatch_cs) begin
            snd_latch <= cpu_dout[7:0];
            snd_stb   <= 1'b1;
        end
    end
end

// Clock enable generator (12 MHz from 48 MHz)
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

// 68000 CPU instance
jtframe_m68k #(.FASTCPU(1)) cpu (
    .clk        ( clk        ),
    .cpu_cen    ( cpu_cen    ),
    .cpu_cenb   ( cpu_cenb   ),
    .rst        ( rst        ),
    .DTACKn     ( ~bus_busy  ),
    .FC( FC         ),
    .eab(A),
    .as_n       ( ASn        ),
    .lds_n      ( LDSn       ),
    .uds_n      ( UDSn       ),
    .eRWn( RnW        ),
    .pal_n      ( 1'b1       ),
    .halt_n     ( 1'b1       ),
    .br_n       ( 1'b1       ),
    .bg_n       (            ),
    .ba_n       (            ),
    .vpa_n      ( VPAn       ),
    .vma_n      (            ),
    .e          (            ),
    .ipl_n      ( IPLn       ),
    .din        ( cpu_din    ),
    .dout       ( cpu_dout   )
);

`else
assign main_addr = 19'h0;
assign ram_addr  = 16'h0;
assign main_dout = 16'h0;
assign cpu_rnw   = 1'b1;
assign dsn       = 2'b11;
assign ram_we    = 1'b0;
assign rom_cs    = 1'b0;
assign wram_cs   = 1'b0;
assign pal_cs    = 1'b0;
assign snd_latch = 8'h0;
assign snd_stb   = 1'b0;
`endif

endmodule
