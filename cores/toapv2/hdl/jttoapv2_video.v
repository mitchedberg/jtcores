module jttoapv2_video(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL,
    input         LVBL,
    // GP9001 indirect interface (from CPU)
    input  [15:0] cpu_dout,
    input         gp_cs,
    input  [ 2:1] gp_addr,
    input         cpu_rnw,
    output [15:0] gp_dout,
    // Palette
    input         pal_cs,
    input  [11:1] pal_addr,
    output [15:0] pal_dout,
    // Text layer
    input         txt_cs,
    input  [12:1] txt_addr,
    output [15:0] txt_dout,
    // GFX ROM (SDRAM)
    output [20:2] gfx_addr,
    output        gfx_cs,
    input  [31:0] gfx_data,
    input         gfx_ok,
    // Pixel output
    output [3:0]  red,
    output [3:0]  green,
    output [3:0]  blue
);

reg  [15:0] gp_voffs;
reg  [ 3:0] gp_regsel;
reg  [15:0] scroll_reg[0:15];
reg  [15:0] bg_vram[0:1023];
reg  [15:0] spr_ram[0:1023];  // 256 sprites × 4 words = 1024 words (GP9001 offsets 0x1800-0x1BFF)
reg  [15:0] pal_ram[0:2047];
reg  [15:0] txt_ram[0:4095];
reg         lhbl_l;
reg         lvbl_l;
reg  [ 8:0] pix_x;
reg  [ 8:0] pix_y;
reg  [31:0] gfx_latch;

integer i;

wire line_start  = ~lhbl_l &  LHBL;
wire frame_start = ~lvbl_l &  LVBL;
wire [8:0] src_x = pix_x + scroll_reg[0][8:0];
wire [8:0] src_y = pix_y + scroll_reg[1][8:0];
wire [4:0] tile_x = src_x[8:4];
wire [4:0] tile_y = src_y[8:4];
wire [3:0] fine_x = src_x[3:0];
wire [3:0] fine_y = src_y[3:0];
wire [9:0] tilemap_addr = { tile_y, tile_x };
wire [15:0] tile_entry = bg_vram[tilemap_addr];
wire [1:0] tile_pal_bank = tile_entry[15:14];
wire [13:0] tile_code = tile_entry[13:0];
wire [20:2] gfx_req_addr = { tile_code, 5'd0 } +
                           { 14'd0, fine_y, 1'b0 } +
                           { 18'd0, fine_x[3] };
wire [31:0] gfx_word = gfx_ok ? gfx_data : gfx_latch;
wire [3:0] pixel_nibble = pick_nibble(gfx_word, fine_x[2:0]);
wire [10:0] pal_rd_addr = { 5'd0, tile_pal_bank, pixel_nibble };
wire [15:0] pal_word = pal_ram[pal_rd_addr];
wire [4:0] pal_red_5 = pal_word[4:0];
wire [4:0] pal_green_5 = pal_word[9:5];
wire [4:0] pal_blue_5 = pal_word[14:10];

function [3:0] pick_nibble;
    input [31:0] data;
    input [ 2:0] idx;
    begin
        case(idx)
            3'd0: pick_nibble = data[31:28];
            3'd1: pick_nibble = data[27:24];
            3'd2: pick_nibble = data[23:20];
            3'd3: pick_nibble = data[19:16];
            3'd4: pick_nibble = data[15:12];
            3'd5: pick_nibble = data[11: 8];
            3'd6: pick_nibble = data[ 7: 4];
            default: pick_nibble = data[ 3: 0];
        endcase
    end
endfunction

always @(posedge clk) begin
    if (rst) begin
        gp_voffs <= 16'd0;
        gp_regsel <= 4'd0;
        lhbl_l <= 1'b0;
        lvbl_l <= 1'b0;
        pix_x <= 9'd0;
        pix_y <= 9'd0;
        gfx_latch <= 32'd0;
        for (i = 0; i < 16; i = i + 1)
            scroll_reg[i] <= 16'd0;
    end else begin
        if (gp_cs && !cpu_rnw) begin
            case (gp_addr)
                2'b00: begin
                    if (gp_voffs[15:10] == 6'd0)
                        bg_vram[gp_voffs[9:0]] <= cpu_dout;
                    else if (gp_voffs >= 16'h1800 && gp_voffs <= 16'h1BFF)
                        spr_ram[gp_voffs[9:0]] <= cpu_dout;
                    gp_voffs <= gp_voffs + 16'd1;
                end
                2'b01: gp_voffs <= cpu_dout;
                2'b10: scroll_reg[gp_regsel] <= cpu_dout;
                2'b11: gp_regsel <= cpu_dout[3:0];
            endcase
        end else if (gp_cs && cpu_rnw && gp_addr == 2'b00) begin
            gp_voffs <= gp_voffs + 16'd1;
        end

        if (pal_cs && !cpu_rnw)
            pal_ram[pal_addr] <= cpu_dout;

        if (txt_cs && !cpu_rnw)
            txt_ram[txt_addr] <= cpu_dout;

        if (pxl_cen) begin
            lhbl_l <= LHBL;
            lvbl_l <= LVBL;

            if (gfx_ok)
                gfx_latch <= gfx_data;

            if (frame_start)
                pix_y <= 9'd0;

            if (line_start) begin
                pix_x <= 9'd0;
                if (LVBL && !frame_start)
                    pix_y <= pix_y + 9'd1;
            end else if (LHBL && LVBL) begin
                pix_x <= pix_x + 9'd1;
            end
        end
    end
end

assign gp_dout = gp_addr == 2'b00 ? (gp_voffs[15:10] == 6'd0 ? bg_vram[gp_voffs[9:0]] : 16'hFFFF) :
                 gp_addr == 2'b01 ? gp_voffs :
                 gp_addr == 2'b10 ? scroll_reg[gp_regsel] :
                                    { 12'd0, gp_regsel };
assign pal_dout = pal_ram[pal_addr];
assign txt_dout = txt_ram[txt_addr];

assign gfx_cs   = LHBL & LVBL;
assign gfx_addr = gfx_req_addr;

assign red   = (LHBL && LVBL && pixel_nibble != 4'd0) ? pal_red_5[4:1] : 4'd0;
assign green = (LHBL && LVBL && pixel_nibble != 4'd0) ? pal_green_5[4:1] : 4'd0;
assign blue  = (LHBL && LVBL && pixel_nibble != 4'd0) ? pal_blue_5[4:1] : 4'd0;

endmodule
