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
    output        [13:1] cpu_addr,
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
    output reg           snd_stb,

    // Tilebank
    output reg           tilebank
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
reg         sprite_fix;
assign main_addr  = A[17:1];
assign ram_addr   = A[15:1];
assign ram_din    = cpu_dout;
assign cpu_rnw    = RnW;
assign cpu_addr   = A[13:1];
assign cpu_dout_o = cpu_dout;
assign ram_dsn   = {UDSn, LDSn};
assign ram_we    = ram_cs & ~RnW;
assign BUSn      = ASn | (LDSn & UDSn);
assign IPLn      = intn ? 3'b111 : 3'b110;   // IRQ1 (vblank)
assign VPAn      = ~(!ASn && FC == 3'b111);
wire mapped_cs  = main_cs | ram_cs | pal_cs | bgvram_cs | fgvram_cs | scroll_cs | io_cs | sprite_fix;
wire unmapped_cs = !BUSn & ~mapped_cs;  // catch-all: any bus cycle not matching a known region
assign bus_cs    = mapped_cs | unmapped_cs;   // always generate DTACK for any bus cycle
assign bus_busy  = (main_cs & ~main_ok) | (ram_cs & ~ram_ok);

// Address decode — combinational
// All comparisons use byte address bits [23:N] (A[23:1] = byte addr with bit 0 omitted,
// so A[k] == byte addr bit k for k>=1).
// Verification: correct constant = target_byte_addr >> N
always @* begin
    main_cs    = !ASn  && A[23:18] == 6'h00;    // 0x000000-0x03FFFF (0>>18=0x00)
    ram_cs     = !BUSn && A[23:16] == 8'h0B;    // 0x0B0000-0x0BFFFF (0x0B0000>>16=0x0B)
    io_cs      = !BUSn && A[23:5]  == 19'h06000; // 0x0C0000-0x0C001F (0x0C0000>>5=0x6000)
    sprite_fix = !BUSn && A[23:1] == 23'h022011;  // byte 0x044022-0x044023
    scroll_cs  = !BUSn && A[23:3]  == 21'h018800; // 0x0C4000-0x0C4007 (0x0C4000>>3=0x18800)
    pal_cs     = !BUSn && A[23:11] == 13'h0190;  // 0x0C8000-0x0C87FF (0x0C8000>>11=0x190)
    bgvram_cs  = !BUSn && A[23:14] == 10'h033;   // 0x0CC000-0x0CFFFF (0x0CC000>>14=0x33)
    fgvram_cs  = !BUSn && A[23:11] == 13'h01A0;  // 0x0D0000-0x0D07FF (0x0D0000>>11=0x1A0)
    clr_int    = !ASn && FC == 3'b111;   // IACK cycle clears interrupt
end

// Tilebank and sound latch capture (at io_cs)
always @(posedge clk) begin
    if (rst) begin
        snd_latch <= 8'h0;
        snd_stb   <= 0;
        tilebank  <= 0;
    end else begin
        snd_stb <= io_cs & ~RnW;
        if (io_cs & ~RnW) begin
            if (A[4])
                tilebank <= cpu_dout[0];  // 0x0C0018: tilebank select
            else
                snd_latch <= cpu_dout[7:0];  // 0x0C0000-0x0C000F: sound/other writes
        end
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
              sprite_fix ? 16'h0003 :
              io_cs    ? (A[4:1]==4'd0 ? {8'hFF, 2'b11, joystick1[5:0]} :  // 0xC0000: IN0 (P1)
                          A[4:1]==4'd1 ? 16'hFFFF                       :  // 0xC0002: IN1/system
                          A[4:1]==4'd4 ? {8'hFF, dipsw[7:0]}            :  // 0xC0008: DSW1
                          A[4:1]==4'd5 ? {8'hFF, dipsw[15:8]}           :  // 0xC000A: DSW2
                          A[4:1]==4'd7 ? {8'hFF, 8'h00}                 :  // 0xC000E: NMK004 sound status (idle)
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


`ifdef SIMULATION
reg [31:0] diag_cnt;
reg [15:0] last_page;
reg        past_rst;
always @(posedge clk) begin
    past_rst <= rst;
    if(cpu_cen) begin
        diag_cnt <= diag_cnt + 1;
        // Trace exception vector reads (byte addr 0x00-0xFF)
        if(!rst && RnW && !ASn && {A,1'b0} < 24'h000100)
            $display("NMK16 VECTOR: A=%06X (vector %0d)", {A,1'b0}, {A[6:1],1'b0}>>2);
        // Trace CPU entering new 512-byte page
        if(!rst && !ASn && A[23:9] != last_page[14:0]) begin
            last_page <= {1'b0, A[23:9]};
            $display("NMK16 PAGE: A=%06X RnW=%b", {A,1'b0}, RnW);
        end
        // Periodic status (more frequent)
        if(diag_cnt[15:0]==0)
            $display("NMK16: A=%06X RnW=%b cs:m=%b r=%b bg=%b pal=%b io=%b", {A,1'b0}, RnW, main_cs, ram_cs, bgvram_cs, pal_cs, io_cs);
        // Catch instruction fetch at RTE return address (0x9324)
        if(!rst && !ASn && RnW && {A,1'b0} == 24'h009324)
            $display("NMK16 RTE_FETCH: A=%06X data=%04X main_cs=%b main_ok=%b", {A,1'b0}, main_data, main_cs, main_ok);
        // Catch any illegal instruction exception vector read
        if(!rst && !ASn && RnW && {A,1'b0} == 24'h000010)
            $display("NMK16 ILLEGAL_VEC: reading illegal instruction vector! SP probably at %06X", {A,1'b0});
        // Catch when CPU reaches error halt
        if(!rst && !ASn && RnW && {A,1'b0} == 24'h0096CC)
            $display("NMK16 ERROR_HALT: CPU at error halt 0x96CC");
    end
end
`endif`else
initial begin
    main_cs = 0; ram_cs = 0;
    pal_cs = 0; bgvram_cs = 0; fgvram_cs = 0; scroll_cs = 0; io_cs = 0; sprite_fix = 0;
    snd_latch = 0;
    snd_stb = 0;
    tilebank = 0;
end
assign main_addr = 0; assign ram_addr = 0;
assign ram_din = 0; assign ram_dsn = 0; assign ram_we = 0;
assign cpu_rnw = 1; assign cpu_addr = 0; assign cpu_dout_o = 0;
`endif
endmodule
