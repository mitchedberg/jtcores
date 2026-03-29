// TC0220IOC — Taito I/O Controller
// Sources: MAME taito/tc0220ioc.cpp, FBNeo tc0220ioc.cpp, MiSTer F2 tc0220ioc.sv
// 8 registers, active on upper byte of 68000 bus

module tc0220ioc(
    input             clk,
    input             rst,
    // CPU interface (active on upper byte, accent[2:0] selects register)
    input      [ 2:0] addr,
    input      [ 7:0] din,
    output reg [ 7:0] dout,
    input             we,
    // Cabinet inputs
    input      [ 7:0] joystick1,
    input      [ 7:0] joystick2,
    input      [ 1:0] start_button,
    input      [ 1:0] coin_input,
    input             service,
    input             tilt,
    input      [ 7:0] dipsw_a,
    input      [ 7:0] dipsw_b,
    // Outputs
    output reg        watchdog
);

reg [7:0] coin_ctrl;

always @(posedge clk) begin
    if( rst ) begin
        watchdog  <= 0;
        coin_ctrl <= 0;
    end else begin
        watchdog <= 0;
        if( we ) begin
            case( addr )
                3'd0: watchdog <= 1; // any write resets watchdog
                3'd4: coin_ctrl <= din;
                default: ;
            endcase
        end
    end
end

always @(*) begin
    case( addr )
        3'd0: dout = dipsw_a;
        3'd1: dout = dipsw_b;
        3'd2: dout = ~joystick1;  // active LOW (JTFRAME provides active HIGH)
        3'd3: dout = ~joystick2;
        3'd4: dout = { 4'hf, coin_ctrl[3:2], ~coin_input };
        3'd7: dout = { 4'hf, tilt, service, start_button };
        default: dout = 8'hff;
    endcase
end

endmodule
