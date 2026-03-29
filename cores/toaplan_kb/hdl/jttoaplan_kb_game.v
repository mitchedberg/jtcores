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
    Date: 28-03-2026 */

module jttoaplan_kb_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        snd_rst;
reg  [ 7:0] debug_mux;

wire [ 7:0] dipsw_a, dipsw_b;
wire        main_flag, main_stb, snd_stb;

wire [ 7:0] snd_latch;
wire        snd_flag;

wire [15:0] dac_l, dac_r;

wire        cen12, cen4;
wire        cpu_irqn;
wire [15:0] cpu_addr;

assign debug_view           = debug_mux;
assign { dipsw_b, dipsw_a } = dipsw[15:0];

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= { 4'd0, snd_rst, 3'd0};
        1: debug_mux <= 0;
        2: debug_mux <= 0;
        default: debug_mux <= 0;
    endcase
end

/* verilator tracing_off */
`ifndef NOMAIN
jttoaplan_kb_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen12          ( cen12         ),

    .main_addr      ( main_addr     ),
    .main_dout      ( main_dout     ),
    .main_din       ( main_din      ),
    .main_rnw       ( main_rnw      ),
    .main_cs        ( main_cs       ),

    .rom_addr       ( ioctl_addr[15:0] ),
    .rom_data       ( prog_data[7:0] ),
    .rom_we         ( prog_we       ),

    .snd_latch      ( snd_latch     ),
    .snd_flag       ( snd_flag      ),

    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),

    .irq            ( cpu_irqn      )
);
`else
assign main_dout = 0;
assign cpu_irqn = 1;
assign snd_flag = 0;
`endif

`ifndef NOSND
jttoaplan_kb_snd u_snd(
    .rst            ( snd_rst       ),
    .clk            ( clk           ),
    .cen4           ( cen4          ),

    .snd_addr       ( snd_addr      ),
    .snd_dout       ( snd_dout      ),
    .snd_din        ( snd_din       ),
    .snd_rnw        ( snd_rnw       ),
    .snd_cs         ( snd_cs        ),

    .rom_addr       ( ioctl_addr[14:0] ),
    .rom_data       ( prog_data[7:0] ),
    .rom_we         ( prog_we       ),

    .snd_latch      ( snd_latch     ),
    .snd_flag       ( snd_flag      ),

    .dac_l          ( dac_l         ),
    .dac_r          ( dac_r         )
);
`else
assign snd_dout = 0;
assign dac_l = 0;
assign dac_r = 0;
`endif

endmodule
