// TC0140SYT — Taito Sound Communication Controller
// Sources: MAME taito/tc0140syt.cpp, FBNeo tc0140syt.cpp
// 68000 writes sound commands via 4-bit nibble protocol
// Z80 receives NMI when data is pending

module tc0140syt(
    input             clk,
    input             rst,
    // 68000 side (master)
    input      [ 1:0] main_addr,   // 0=port_w, 1=comm_rw
    input      [ 7:0] main_din,
    output reg [ 7:0] main_dout,
    input             main_we,
    input             main_rd,
    // Z80 side (slave)
    input      [ 1:0] sub_addr,    // 0=port_w, 1=comm_rw
    input      [ 7:0] sub_din,
    output reg [ 7:0] sub_dout,
    input             sub_we,
    input             sub_rd,
    // Z80 NMI output
    output            nmi_n,
    // Z80 reset
    output reg        sub_rst
);

// Internal registers
reg [3:0] slave_data [0:3];  // 68000 -> Z80
reg [3:0] master_data[0:3];  // Z80 -> 68000
reg [3:0] main_mode, sub_mode;
reg [3:0] status;
reg       nmi_enabled;

// Status bits
localparam PORT01_FULL        = 0; // 68000 wrote ports 0+1
localparam PORT23_FULL        = 1; // 68000 wrote ports 2+3
localparam PORT01_FULL_MASTER = 2; // Z80 wrote ports 0+1
localparam PORT23_FULL_MASTER = 3; // Z80 wrote ports 2+3

// NMI fires when data pending AND enabled
assign nmi_n = ~(nmi_enabled & (status[PORT01_FULL] | status[PORT23_FULL]));

// 68000 side
always @(posedge clk) begin
    if( rst ) begin
        main_mode <= 0;
        status    <= 0;
        sub_rst   <= 1;
        nmi_enabled <= 0;
        slave_data[0] <= 0; slave_data[1] <= 0;
        slave_data[2] <= 0; slave_data[3] <= 0;
        master_data[0] <= 0; master_data[1] <= 0;
        master_data[2] <= 0; master_data[3] <= 0;
    end else begin
        // Master port write (address 0)
        if( main_we && main_addr == 2'd0 )
            main_mode <= main_din[3:0];

        // Master comm write (address 1)
        if( main_we && main_addr == 2'd1 ) begin
            case( main_mode )
                4'd0: slave_data[0] <= main_din[3:0];
                4'd1: begin slave_data[1] <= main_din[3:0]; status[PORT01_FULL] <= 1; end
                4'd2: slave_data[2] <= main_din[3:0];
                4'd3: begin slave_data[3] <= main_din[3:0]; status[PORT23_FULL] <= 1; end
                4'd4: sub_rst <= |main_din; // nonzero = assert reset
                default: ;
            endcase
        end

        // Master comm read (address 1)
        if( main_rd && main_addr == 2'd1 ) begin
            case( main_mode )
                4'd1: status[PORT01_FULL_MASTER] <= 0;
                4'd3: status[PORT23_FULL_MASTER] <= 0;
                default: ;
            endcase
        end

        // Slave port write
        if( sub_we && sub_addr == 2'd0 )
            sub_mode <= sub_din[3:0];

        // Slave comm write
        if( sub_we && sub_addr == 2'd1 ) begin
            case( sub_mode )
                4'd0: master_data[0] <= sub_din[3:0];
                4'd1: begin master_data[1] <= sub_din[3:0]; status[PORT01_FULL_MASTER] <= 1; end
                4'd2: master_data[2] <= sub_din[3:0];
                4'd3: begin master_data[3] <= sub_din[3:0]; status[PORT23_FULL_MASTER] <= 1; end
                4'd5: nmi_enabled <= 0;
                4'd6: nmi_enabled <= 1;
                default: ;
            endcase
        end

        // Slave comm read
        if( sub_rd && sub_addr == 2'd1 ) begin
            case( sub_mode )
                4'd1: status[PORT01_FULL] <= 0;
                4'd3: status[PORT23_FULL] <= 0;
                default: ;
            endcase
        end
    end
end

// Read muxes
always @(*) begin
    case( main_mode )
        4'd0: main_dout = { 4'd0, master_data[0] };
        4'd1: main_dout = { 4'd0, master_data[1] };
        4'd2: main_dout = { 4'd0, master_data[2] };
        4'd3: main_dout = { 4'd0, master_data[3] };
        4'd4: main_dout = { 4'd0, status };
        default: main_dout = 8'hff;
    endcase

    case( sub_mode )
        4'd0: sub_dout = { 4'd0, slave_data[0] };
        4'd1: sub_dout = { 4'd0, slave_data[1] };
        4'd2: sub_dout = { 4'd0, slave_data[2] };
        4'd3: sub_dout = { 4'd0, slave_data[3] };
        4'd4: sub_dout = { 4'd0, status };
        default: sub_dout = 8'hff;
    endcase
end

endmodule
