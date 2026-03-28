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

    Author: AI-rebuilt module (Phase 2 validation)
    Based on: MAME bublbobl_v.cpp + JTFRAME patterns
    Date: 2026-03-27 */

// Bubble Bobble GFX engine
//
// Architecture mirrors the original PCB hardware:
//
// VRAM is 8KB split into four 2KB banks. The CPU address mapping is:
//   bank select = {cpu_addr[12], cpu_addr[0]}
//   bank address = cpu_addr[11:1]
// This interleaving means consecutive bytes alternate between bank 0/1
// (within the lower 4KB) or bank 2/3 (within the upper 4KB).
//
// The GFX engine scans through objects during the active display period
// (not HBLANK -- the original hardware renders continuously). Objects
// live at the top of VRAM (oa starts at 0x80 in bank address space,
// which corresponds to objectram at 0xDD00 in CPU address space).
//
// A shared VRAM address bus (cbus) alternates between reading object
// attributes (ch=0) and reading tile character data (ch=1). The 4-phase
// cycle {ch,oa[0]} = 00,01,10,11 reads:
//   00: Y offset (bank2) + tile base/sa_base (bank3)
//   01: X position (bank2) + attributes (bank3)
//   10: tile code+attr for left half (from vrmux = {bank1,bank0} or {bank3,bank2})
//   11: tile code+attr for right half
//
// The PROM (a71-25.41) is addressed by {LVBL, sa_base[7:5], vsub[7:4]}
// and provides: bit3=skip(next), bit2=load_enable_n, bits1:0=row_group.
//
// After collecting tile data for both halves, the engine fetches GFX ROM
// pixels from SDRAM and writes them into a jtframe_obj_buffer line buffer.
// The pixel data is extracted from the 32-bit ROM word in planar format
// and written with palette+pixel color into the line buffer.

module jtbubl_gfx(
    input               rst,
    input               clk,
    input               clk_cpu,
    input               pxl2_cen,
    input               pxl_cen,
    // PROMs
    input      [ 7:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,
    // Screen
    input               flip,
    input               LHBL,
    input               LVBL,
    input      [8:0]    hdump,
    input      [7:0]    vdump,
    // CPU interface
    input               vram_cs,
    output reg [ 7:0]   vram_dout,
    input               cpu_rnw,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    // SDRAM interface
    output     [18:2]   rom_addr,
    input      [31:0]   rom_data,
    input               rom_ok,
    output reg          rom_cs,
    // Color address to palette
    output     [ 7:0]   col_addr
);

// ============================================================
// VRAM: four 2KB banks
// CPU port uses {cpu_addr[12], cpu_addr[0]} as bank select
// and cpu_addr[11:1] as the bank address (11 bits = 2048 entries)
// GFX port reads via shared address bus cbus[10:0]
// ============================================================
wire [ 7:0] scan0_data, scan1_data, scan2_data, scan3_data;
wire [ 7:0] vram0_dout, vram1_dout, vram2_dout, vram3_dout;
wire [10:0] vram_addr = cpu_addr[11:1];
reg  [ 3:0] vram_we, cpu_cc;
reg  [ 7:0] line_din;
reg  [ 8:0] line_addr;
reg         line_we;
wire [ 3:0] dec_dout;
wire [ 7:0] dec_addr;

// CPU bank select decode
always @(*) begin
    cpu_cc = 4'd0;
    cpu_cc[{cpu_addr[12],cpu_addr[0]}] = 1;
    vram_we = cpu_cc & {4{~cpu_rnw & vram_cs}};
end

// CPU read mux
always @(*) begin
    case( cpu_cc )
        4'b0001: vram_dout = vram0_dout;
        4'b0010: vram_dout = vram1_dout;
        4'b0100: vram_dout = vram2_dout;
        4'b1000: vram_dout = vram3_dout;
        default: vram_dout = 8'hff;
    endcase
end

localparam [10:0] OBJ_START = 11'h140;

// ============================================================
// Object scan and tile collection
// ============================================================
reg  [ 9:0] code0, code1, code_mux;
reg  [ 8:0] oa;        // VRAM address counter for object scan
reg         oatop;      // selects upper/lower VRAM half for tile reads
wire [11:0] sa;         // computed tile VRAM address
reg  [ 7:0] vsub, sa_base, hotpxl;
reg  [31:0] pxl_data;
reg  [ 8:0] hpos;
reg  [ 3:0] bank, pal0, pal1, pal_mux;
wire [10:0] cbus;       // shared VRAM address bus
reg         ch;         // 0=object read phase, 1=character/tile read phase
reg  [ 1:0] hflip, vflip;
reg         hf_mux, vf_mux;
reg  [ 1:0] waitok;
reg         busy, idle;
wire [15:0] vrmux;
wire        lden_b, next;
reg         half, newdata;

// Shared VRAM address bus: alternates between object attributes and tile data
assign cbus      = ch ? { sa[10:6],oa[0],sa[4:0] } : {1'b1, oatop, oa };

// ROM address: {bank, tile_code, row}
assign rom_addr  = { bank, code_mux, vsub[2:0]^{3{vf_mux}} };

// Tile address computation from PROM output and object data
assign sa        = { sa_base[7]&sa_base[5], sa_base[4:0], 1'b1 /*unused*/,
                     dec_dout[1:0], vsub[5:3] };

// PROM address: uses LVBL, upper bits of sa_base, and upper bits of vsub
assign dec_addr  = { LVBL, sa_base[7:5], vsub[7:4] };

// Mux between lower and upper VRAM bank pairs based on sa[11]
assign vrmux     = sa[11] ? {scan3_data, scan2_data} : {scan1_data, scan0_data};

// PROM output: bit2 = load enable (active low), bit3 = next/skip
assign lden_b    = dec_dout[2];
assign next      = dec_dout[3];

`ifdef SIMULATION
wire [1:0] phase = { ch, oa[0] };
`endif

// ============================================================
// Object scanning state machine
// Runs during the active display period (not during HBLANK).
// Scans through object entries using the oa counter. The
// {ch, oa[0], idle} triple sequences through:
//   Phase 00: read object Y + tile base from banks 2,3
//   Phase 01: read object X + attributes from banks 2,3
//   Phase 10: read left tile code+color from appropriate banks
//   Phase 11: read right tile code+color from appropriate banks
// After phase 11, if the PROM says this object row is valid,
// newdata triggers the tile drawing engine.
// ============================================================
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        oa      <= 9'd0;
        ch      <= 0;
        idle    <= 0;
        code0   <= 10'd0;
        code1   <= 10'd0;
        bank    <= 4'd0;
        vsub    <= 8'd0;
        hflip   <= 2'b0;
        vflip   <= 2'b0;
        sa_base <= 8'd0;
        newdata <= 0;
    end else begin
        // Reset scan position at the start of active display
        if( hdump[8] && hdump<9'h12B ) begin
            oa      <= 9'h80;
            ch      <= 0;
            idle    <= 0;
            oatop   <= 1;
            newdata <= 0;
        end else begin
            // Advance the scan counter when not busy drawing
            if( !busy && oa[8:1]!=8'hE0 ) begin
                { oa[8:1], ch, oa[0], idle } <= { oa[8:1], ch, oa[0], idle } + 10'd1;
            end
            // Latch data from VRAM on idle cycles (data is ready)
            if(idle) begin
                case( {ch, oa[0]} )
                    2'd0: begin
                        // Phase 00: Y offset and tile base
                        vsub    <= scan2_data+(vdump^{8{flip}});
                        sa_base <= scan3_data;
                    end
                    2'd1: begin
                        // Phase 01: X position and attributes
                        oatop   <= ~scan3_data[7];
                        hpos    <= {scan3_data[6], scan2_data };
                        bank    <= scan3_data[3:0];
                    end
                    2'd2: begin
                        // Phase 10: left tile code and attributes
                        code0   <= vrmux[9:0];
                        pal0    <= vrmux[13:10];
                        hflip[0]<= vrmux[14];
                        vflip[0]<= vrmux[15];
                    end
                    2'd3: begin
                        // Phase 11: right tile code and attributes
                        code1   <= vrmux[9:0];
                        pal1    <= vrmux[13:10];
                        hflip[1]<= vrmux[14];
                        vflip[1]<= vrmux[15];
                    end
                endcase
            end
            // Trigger drawing when phase 10 data is ready and PROM says to draw
            newdata <= {ch, oa[0],idle}==3'b110;
        end
    end
end

// ============================================================
// Pixel extraction function
// ROM data is organized in planar format. After MRA byte
// interleaving, the 32-bit word contains pixel data that
// needs to be unpacked. The bit ordering after repack:
//   Planes are interleaved within the 32-bit word
// ============================================================
function [3:0] get_pxl;
    input [31:0] pd;
    input        hf;

    get_pxl = hf ?
        { pd[7], pd[15], pd[23], pd[31] } :
        { pd[0], pd[ 8], pd[16], pd[24] };
endfunction

// ============================================================
// Tile drawing engine
// Triggered by newdata when the PROM indicates a valid row.
// Fetches ROM data for the left half (code0), draws 8 pixels,
// then fetches ROM data for the right half (code1), draws 8
// more pixels. Pixels are written to the line buffer with
// {palette, ~pixel} format (inverted because ROMREGION_INVERT).
// ============================================================
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busy    <= 0;
        rom_cs  <= 0;
        line_we <= 0;
        waitok  <= 2'b11;
    end else begin
        if( newdata & ~next) begin
            // Start drawing: load parameters for left tile
            busy        <= 1;
            rom_cs      <= 1;
            waitok      <= 2'b11;
            if(!lden_b) line_addr <= hpos;
            line_we     <= 0;
            code_mux    <= code0;
            hf_mux      <= hflip[0];
            vf_mux      <= vflip[0];
            pal_mux     <= pal0;
            half        <= 0;
        end else if(busy) begin
            waitok[0] <= 0;
            if( waitok[1] && rom_ok ) begin
                // ROM data arrived: repack planes into drawing format
                pxl_data <= {
                    rom_data[19:16], rom_data[ 3: 0], // plane 0
                    rom_data[23:20], rom_data[ 7: 4], // plane 1
                    rom_data[27:24], rom_data[11: 8], // plane 2
                    rom_data[31:28], rom_data[15:12]  // plane 3
                 };
                hotpxl    <= 8'h0;
                waitok[1] <= 0;
                rom_cs    <= 0;
            end else if(!waitok[1]) begin
                // Draw pixels one by one
                if( hotpxl[0])
                    line_addr <= line_addr + 9'd1;
                line_din  <= {pal_mux, ~get_pxl(pxl_data, hf_mux) };
                line_we   <= 1;
                pxl_data  <= hf_mux ? pxl_data<<1 : pxl_data>>1;
                hotpxl    <= { hotpxl[6:0], 1'b1 };
                if( hotpxl[7] ) begin
                    // Done with 8 pixels
                    line_we <= 0;
                    if( half ) begin
                        busy    <= 0; // both halves done
                    end else begin
                        // Switch to right tile
                        waitok <= 2'b11;
                        code_mux <= code1;
                        hf_mux   <= hflip[1];
                        vf_mux   <= vflip[1];
                        pal_mux  <= pal1;
                        half     <= 1;
                        rom_cs   <= 1;
                    end
                end
            end
        end
    end
end

// ============================================================
// VRAM bank instantiation
// Four 2KB banks with dual-port access
// Port 0: CPU read/write
// Port 1: GFX engine read via cbus
// ============================================================
jtframe_dual_ram #(.AW(11),.SIMHEXFILE("vram0.hex")) u_ram0(
    .clk0   ( clk_cpu   ),
    .clk1   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[0]),
    .q0     ( vram0_dout),
    .data1  (           ),
    .addr1  ( cbus      ),
    .we1    ( 1'b0      ),
    .q1     ( scan0_data)
);

jtframe_dual_ram #(.AW(11),.SIMHEXFILE("vram1.hex")) u_ram1(
    .clk0   ( clk_cpu   ),
    .clk1   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[1]),
    .q0     ( vram1_dout),
    .data1  (           ),
    .addr1  ( cbus      ),
    .we1    ( 1'b0      ),
    .q1     ( scan1_data)
);

jtframe_dual_ram #(.AW(11),.SIMHEXFILE("vram2.hex")) u_ram2(
    .clk0   ( clk_cpu     ),
    .clk1   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[2]),
    .q0     ( vram2_dout),
    .data1  (           ),
    .addr1  ( cbus      ),
    .we1    ( 1'b0      ),
    .q1     ( scan2_data)
);

jtframe_dual_ram #(.AW(11),.SIMHEXFILE("vram3.hex")) u_ram3(
    .clk0   ( clk_cpu     ),
    .clk1   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[3]),
    .q0     ( vram3_dout),
    .data1  (           ),
    .addr1  ( cbus      ),
    .we1    ( 1'b0      ),
    .q1     ( scan3_data)
);

// ============================================================
// PROM: 256 x 4 bits
// Controls object rendering: skip, load enable, row group
// ============================================================
jtframe_prom #(.DW(4),.AW(8), .SIMFILE("a71-25.41")) u_prom(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .rd_addr( dec_addr  ),
    .wr_addr( prog_addr ),
    .we     ( prom_we   ),
    .q      ( dec_dout  )
);

// ============================================================
// Line buffer: double-buffered via jtframe_obj_buffer
// Handles line alternation, pixel output, and auto-clear
// ============================================================
jtframe_obj_buffer #(.FLIP_OFFSET(9'h100)) u_line(
    .clk    ( clk           ),
    .LHBL   ( LHBL          ),
    .flip   ( flip          ),
    // New data writes
    .wr_data( line_din      ),
    .wr_addr( line_addr     ),
    .we     ( line_we       ),
    // Old data reads (and erases)
    .rd_addr( hdump         ),
    .rd     ( pxl_cen       ),
    .rd_data( col_addr      )
);

endmodule
