module jtnmk16_sprite(
    input         rst,
    input         clk,
    input         pxl_cen,
    input   [8:0] vdump,
    input   [8:0] hdump,
    input         LHBL,
    input         LVBL,
    input         HS,
    output reg [11:1] spr_ram_addr,
    output [15:0] spr_ram_q,
    input  [12:1] cpu_spr_addr,
    input  [15:0] cpu_dout,
    input         spr_we,
    output reg [21:2] spr_addr,
    output reg       spr_cs,
    input  [31:0] spr_data,
    input         spr_ok,
    output reg [7:0]  spr_pxl
);

localparam [3:0]
    ST_IDLE       = 4'd0,
    ST_RD0        = 4'd1,
    ST_CAP0       = 4'd2,
    ST_CAP1       = 4'd3,
    ST_CAP3       = 4'd4,
    ST_CAP4       = 4'd5,
    ST_CAP6       = 4'd6,
    ST_CAP7       = 4'd7,
    ST_EVAL       = 4'd8,
    ST_FETCH_REQ  = 4'd9,
    ST_FETCH_WAIT = 4'd10,
    ST_EMIT       = 4'd11;

localparam [21:2] SPR_BASE = 20'h00000;

reg  [3:0]  state;
reg         lhbl_l;
reg  [8:0]  target_line;
reg  [7:0]  sprite_idx;
reg  [15:0] attr1;
reg  [15:0] tile_code_r;
reg  [15:0] xpos_r;
reg  [15:0] ypos_r;
reg  [15:0] pal_r;
reg         enabled_r;

reg  [4:0]  width_tiles_r;
reg  [4:0]  height_tiles_r;
reg         flipx_r;
reg         flipy_r;
reg  [11:0] base_code_r;
reg  [4:0]  tile_row_code_r;
reg  [3:0]  row_in_tile_r;
reg  [3:0]  palette_r;
reg  [4:0]  tile_col_r;
reg         half_r;
reg  [2:0]  pixel_idx_r;
reg  [31:0] fetch_planar_r;
reg         line_sel;
reg  [7:0]  linebuf0 [0:511];
reg  [7:0]  linebuf1 [0:511];

reg  [7:0]  line_din;
reg  [8:0]  line_addr;
reg         line_we;
wire [15:0] spr_ram_qi;
wire [31:0] spr_planar;
wire [3:0]  emit_pixel;
wire [4:0]  disp_tile_col;
wire [3:0]  disp_local_col;
wire signed [10:0] base_x_signed;
wire signed [11:0] emit_x_signed;
wire        emit_visible;
wire [4:0]  attr_width_tiles;
wire [4:0]  attr_height_tiles;
wire [7:0]  tile_row_offset;
wire [11:0] cur_tile_code;
wire [21:2] cur_word_addr;
wire        start_line;
wire signed [10:0] line_diff;
wire [8:0]  sprite_height_px;
wire        hs_unused = HS;
integer     li;

function signed [10:0] wrap9s;
    input [8:0] val;
    begin
        wrap9s = $signed({1'b0, val}) - (val[8] ? 11'sd512 : 11'sd0);
    end
endfunction

function [3:0] planar_pixel;
    input [31:0] data;
    input [2:0]  idx;
    begin
        planar_pixel = {
            data[5'd31-{2'd0, idx}],
            data[5'd23-{2'd0, idx}],
            data[5'd15-{2'd0, idx}],
            data[5'd7 -{2'd0, idx}]
        };
    end
endfunction

assign start_line   = ~LHBL & lhbl_l;
assign spr_ram_q    = spr_ram_qi;
assign emit_pixel   = planar_pixel(fetch_planar_r, pixel_idx_r);
assign attr_width_tiles  = {1'b0, attr1[3:0]} + 5'd1;
assign attr_height_tiles = {1'b0, attr1[7:4]} + 5'd1;
assign disp_tile_col = flipx_r ? (width_tiles_r - 5'd1 - tile_col_r) : tile_col_r;
assign disp_local_col = flipx_r ? (4'd15 - {half_r, pixel_idx_r}) : {half_r, pixel_idx_r};
assign base_x_signed = wrap9s(xpos_r[8:0]);
assign line_diff     = $signed({1'b0, target_line}) - wrap9s(ypos_r[8:0]);
assign sprite_height_px = { attr_height_tiles, 4'b0000 };
assign emit_x_signed = $signed({base_x_signed[10], base_x_signed}) +
                       $signed({3'b000, disp_tile_col, 4'b0000}) +
                       $signed({8'd0, disp_local_col});
assign emit_visible = LVBL && emit_x_signed >= 12'sd0 && emit_x_signed < 12'sd256;
assign tile_row_offset = tile_row_code_r * width_tiles_r;
assign cur_tile_code = base_code_r + {7'd0, tile_col_r} + {4'd0, tile_row_offset};
assign cur_word_addr = SPR_BASE + {3'd0, cur_tile_code, 5'd0} + {15'd0, row_in_tile_r, half_r};

jtframe_dual_ram #(.DW(16), .AW(12)) u_sprram(
    .clk0   ( clk                    ),
    .data0  ( cpu_dout               ),
    .addr0  ( cpu_spr_addr           ),
    .we0    ( spr_we                 ),
    .q0     (                        ),
    .clk1   ( clk                    ),
    .data1  ( 16'd0                  ),
    .addr1  ( {1'b0, spr_ram_addr}   ),
    .we1    ( 1'b0                   ),
    .q1     ( spr_ram_qi             )
);

generate
    genvar gi;
    for (gi = 0; gi < 8; gi = gi + 1) begin : chunky2planar
        assign spr_planar[7-gi]  = spr_data[gi*4+0];
        assign spr_planar[15-gi] = spr_data[gi*4+1];
        assign spr_planar[23-gi] = spr_data[gi*4+2];
        assign spr_planar[31-gi] = spr_data[gi*4+3];
    end
endgenerate

always @(posedge clk) begin
    lhbl_l <= LHBL;
end

always @(posedge clk) begin
    if (rst) begin
        state          <= ST_IDLE;
        target_line    <= 9'd0;
        sprite_idx     <= 8'd0;
        spr_ram_addr   <= 11'd0;
        spr_addr       <= 20'd0;
        spr_cs         <= 1'b0;
        line_din       <= 8'hFF;
        line_addr      <= 9'd0;
        line_we        <= 1'b0;
        attr1          <= 16'd0;
        tile_code_r    <= 16'd0;
        xpos_r         <= 16'd0;
        ypos_r         <= 16'd0;
        pal_r          <= 16'd0;
        enabled_r      <= 1'b0;
        width_tiles_r  <= 5'd0;
        height_tiles_r <= 5'd0;
        flipx_r        <= 1'b0;
        flipy_r        <= 1'b0;
        base_code_r    <= 12'd0;
        tile_row_code_r<= 5'd0;
        row_in_tile_r  <= 4'd0;
        palette_r      <= 4'd0;
        tile_col_r     <= 5'd0;
        half_r         <= 1'b0;
        pixel_idx_r    <= 3'd0;
        fetch_planar_r <= 32'd0;
        line_sel       <= 1'b0;
        spr_pxl        <= 8'hFF;
        for (li = 0; li < 512; li = li + 1) begin
            linebuf0[li] <= 8'hFF;
            linebuf1[li] <= 8'hFF;
        end
    end else begin
        line_we <= 1'b0;

        if (pxl_cen) begin
            if (line_sel) begin
                spr_pxl <= linebuf1[hdump];
                linebuf1[hdump] <= 8'hFF;
            end else begin
                spr_pxl <= linebuf0[hdump];
                linebuf0[hdump] <= 8'hFF;
            end
        end

        if (line_we) begin
            if (line_sel)
                linebuf0[line_addr] <= line_din;
            else
                linebuf1[line_addr] <= line_din;
        end

        if (start_line) begin
            line_sel     <= ~line_sel;
            target_line  <= vdump + 9'd1;
            sprite_idx   <= 8'd0;
            spr_ram_addr <= 11'd0;
            spr_cs       <= 1'b0;
            state        <= ST_RD0;
        end else begin
            case (state)
                ST_IDLE: begin
                    spr_cs <= 1'b0;
                end

                ST_RD0: begin
                    spr_ram_addr <= { sprite_idx, 3'b000 };
                    state        <= ST_CAP0;
                end

                ST_CAP0: begin
                    enabled_r    <= spr_ram_qi[0];
                    spr_ram_addr <= { sprite_idx, 3'b001 };
                    state        <= ST_CAP1;
                end

                ST_CAP1: begin
                    attr1        <= spr_ram_qi;
                    spr_ram_addr <= { sprite_idx, 3'b011 };
                    state        <= ST_CAP3;
                end

                ST_CAP3: begin
                    tile_code_r  <= spr_ram_qi;
                    spr_ram_addr <= { sprite_idx, 3'b100 };
                    state        <= ST_CAP4;
                end

                ST_CAP4: begin
                    xpos_r       <= spr_ram_qi;
                    spr_ram_addr <= { sprite_idx, 3'b110 };
                    state        <= ST_CAP6;
                end

                ST_CAP6: begin
                    ypos_r       <= spr_ram_qi;
                    spr_ram_addr <= { sprite_idx, 3'b111 };
                    state        <= ST_CAP7;
                end

                ST_CAP7: begin
                    pal_r        <= spr_ram_qi;
                    state        <= ST_EVAL;
                end

                ST_EVAL: begin
                    width_tiles_r   <= attr_width_tiles;
                    height_tiles_r  <= attr_height_tiles;
                    flipx_r         <= attr1[8];
                    flipy_r         <= attr1[9];
                    base_code_r     <= tile_code_r[11:0];
                    palette_r       <= pal_r[3:0];
                    tile_col_r      <= 5'd0;
                    half_r          <= 1'b0;
                    pixel_idx_r     <= 3'd0;
                    spr_cs          <= 1'b0;
                    if (
                        enabled_r &&
                        line_diff >= 11'sd0 &&
                        line_diff < $signed({2'b00, sprite_height_px})
                    ) begin
                        if (attr1[9]) begin
                            tile_row_code_r <= attr_height_tiles - 5'd1 - line_diff[8:4];
                            row_in_tile_r   <= 4'hF - line_diff[3:0];
                        end else begin
                            tile_row_code_r <= line_diff[8:4];
                            row_in_tile_r   <= line_diff[3:0];
                        end
                        state <= ST_FETCH_REQ;
                    end else if (sprite_idx == 8'hFF) begin
                        state <= ST_IDLE;
                    end else begin
                        sprite_idx <= sprite_idx + 8'd1;
                        state      <= ST_RD0;
                    end
                end

                ST_FETCH_REQ: begin
                    spr_addr <= cur_word_addr;
                    spr_cs   <= 1'b1;
                    state    <= ST_FETCH_WAIT;
                end

                ST_FETCH_WAIT: begin
                    if (spr_ok) begin
                        fetch_planar_r <= spr_planar;
                        pixel_idx_r    <= 3'd0;
                        spr_cs         <= 1'b0;
                        state          <= ST_EMIT;
                    end
                end

                ST_EMIT: begin
                    line_din  <= { palette_r, emit_pixel };
                    line_addr <= emit_x_signed[8:0];
                    line_we   <= emit_visible && emit_pixel != 4'hF;
                    if (pixel_idx_r == 3'd7) begin
                        pixel_idx_r <= 3'd0;
                        if (!half_r) begin
                            half_r <= 1'b1;
                            state  <= ST_FETCH_REQ;
                        end else begin
                            half_r <= 1'b0;
                            if (tile_col_r + 5'd1 < width_tiles_r) begin
                                tile_col_r <= tile_col_r + 5'd1;
                                state      <= ST_FETCH_REQ;
                            end else if (sprite_idx == 8'hFF) begin
                                state <= ST_IDLE;
                            end else begin
                                sprite_idx <= sprite_idx + 8'd1;
                                state      <= ST_RD0;
                            end
                        end
                    end else begin
                        pixel_idx_r <= pixel_idx_r + 3'd1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
end

endmodule
