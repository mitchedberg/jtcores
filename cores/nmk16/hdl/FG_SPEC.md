# NMK16 FG (Foreground/Text) Layer Specification
## Target: Thunder Dragon / tdragonb2

**Research sources used:** MAME nmk16.cpp, nmk16_v.cpp, nmk16.h (verbatim via GitHub raw).
**Date:** 2026-03-29

---

## CRITICAL FINDING: FG ROM Is DIFFERENT Format From BG/Sprites

The FG layer uses **`gfx_8x8x4_packed_msb`** — 8×8 tiles, NOT the 16×16
`gfx_8x8x4_col_2x2_group_packed_msb` used by BG and sprites. This is important:
the FG pixel extraction logic is simpler than BG/sprite logic.

---

## 1. FG VRAM Layout

### Address in 68000 memory map
- **Both tdragon and tdragonb2:** `0x0D0000–0x0D07FF`
- Size: 0x800 bytes = 1024 × 16-bit words

```
tdragon_map:
  map(0x0d0000, 0x0d07ff).ram().w(FUNC(nmk16_state::txvideoram_w)).share(m_txvideoram);

tdragonb2_map:
  map(0x0d0000, 0x0d07ff).ram().w(FUNC(nmk16_state::txvideoram_w)).share(m_txvideoram);
```

### Tile entry format (one 16-bit word per tile)
```
Bits [11:0]  — Tile code (12-bit GFX ROM index, range 0x000–0xFFF)
Bits [15:12] — Palette index (4-bit, range 0x0–0xF)
```

From MAME `common_get_tx_tile_info`:
```cpp
const u16 code = m_txvideoram[tile_index];
tileinfo.set(0, code & 0xfff, code >> 12, 0);
```

- `code & 0xfff` → tile code (gfx[0] = fgtile region)
- `code >> 12` → palette (upper 4 bits)
- No flip bits in tdragon/tdragonb2 (third argument = 0 = no flip)

### Tilemap dimensions
- **32 columns × 32 rows** of 8×8 tiles
- Virtual map size: 256×256 pixels
- Screen size: 256×224 pixels → 32 columns × 28 rows visible
- Scan order: **TILEMAP_SCAN_COLS** (column-major: tile_index = col*32 + row)

From `VIDEO_START_MEMBER(nmk16_state, manybloc)`:
```cpp
m_tx_tilemap = &machine().tilemap().create(*m_gfxdecode,
    tilemap_get_info_delegate(*this, FUNC(nmk16_state::common_get_tx_tile_info)),
    TILEMAP_SCAN_COLS, 8, 8, 32, 32);
m_tx_tilemap->set_transparent_pen(15);
```

Both `tdragon` and `tdragonb2` use `MCFG_VIDEO_START_OVERRIDE(nmk16_state, macross)`
which calls `VIDEO_START_CALL_MEMBER(manybloc)` → 32×32 tile dimensions.

### VRAM address decode (column-major)
```
tile_index = col * 32 + row
  where col = pixel_x / 8  (0–31)
        row = pixel_y / 8  (0–31)

CPU address = 0x0D0000 + tile_index * 2
```

For a pixel at screen position (hx, vy):
```
col = (hx) / 8
row = (vy) / 8
tile_index = col * 32 + row          ← column-major
cpu_addr = 0x0D0000 + tile_index * 2
```

---

## 2. GFX ROM: Tile Format

### ROM files
- **tdragon:** `91070.6` — 128KB (0x20000 bytes)
- **tdragonb2:** `1` (CRC fe365920 — same as 91070.6)

### MAME GFXDECODE entry for FG (gfx[0] in gfx_macross)
```cpp
static GFXDECODE_START( gfx_macross )
    GFXDECODE_ENTRY( "fgtile",  0, gfx_8x8x4_packed_msb,               0x200, 16 ) // gfx[0]
    GFXDECODE_ENTRY( "bgtile",  0, gfx_8x8x4_col_2x2_group_packed_msb, 0x000, 16 ) // gfx[1]
    GFXDECODE_ENTRY( "sprites", 0, gfx_8x8x4_col_2x2_group_packed_msb, 0x100, 16 ) // gfx[2]
GFXDECODE_END
```

### gfx_8x8x4_packed_msb layout
- **Tile size:** 8×8 pixels
- **Bits per pixel:** 4 (values 0–15)
- **Bytes per tile:** 8 × 8 × 4 / 8 = **32 bytes per tile**
- **Total tiles in ROM:** 128KB / 32 = **4096 tiles**

**Pixel extraction for gfx_8x8x4_packed_msb:**
Each byte holds 2 pixels packed as nibbles, MSB-first:
- High nibble (bits [7:4]) = pixel at even column
- Low nibble (bits [3:0]) = pixel at odd column

Each 8-pixel row = 4 bytes:
```
byte 0: pixel(0) in bits[7:4], pixel(1) in bits[3:0]
byte 1: pixel(2) in bits[7:4], pixel(3) in bits[3:0]
byte 2: pixel(4) in bits[7:4], pixel(5) in bits[3:0]
byte 3: pixel(6) in bits[7:4], pixel(7) in bits[3:0]
```

For pixel at (col, row) within a tile:
```
tile_byte_base = tile_code * 32
byte_offset    = row * 4 + (col >> 1)
nibble_sel     = ~col[0]          // col even → high nibble; col odd → low nibble
rom_byte       = ROM[tile_byte_base + byte_offset]
pixel_4bit     = nibble_sel ? rom_byte[7:4] : rom_byte[3:0]
```

**Key difference from BG/sprite format:** This is a flat 8×8 layout, NOT the
two-half 16×16 `col_2x2_group` format. No left/right half split; it is simply
row-major nibble-packed.

### Tile code to SDRAM byte address
```
SDRAM layout in BA2 (BA2_START = 0xC0000):
  Offset 0x000000: BG tiles  (91070.5, 1MB)
  Offset 0x100000: Sprites   (91070.4, 1MB)
  Offset 0x200000: FG text   (91070.6, 128KB)  ← FG starts here

FG tile code T → SDRAM byte address:
  sdram_byte = 0x0C0000 + 0x200000 + T * 32
             = 0x2C0000 + T * 32

FG tile code T → SDRAM 32-bit word address (for mem.yaml bus):
  sdram_word = (0x2C0000 + T * 32) >> 2
             = 0xB0000 + T * 8

In 22-bit word address form:
  fg_word_addr[21:0] = 22'hB0000 + tile_code * 8 + word_within_tile
  where word_within_tile = row * 1 + 0   (each row = 4 bytes = 1 32-bit word)
  i.e., fg_word_addr = 22'hB0000 + {tile_code[11:0], 3'b000} + {row[2:0]}
```

Each 32-bit SDRAM read delivers one full row (8 pixels × 4 bits = 32 bits).

---

## 3. Palette

### Palette RAM address
- **Palette RAM:** 1024 entries × 16-bit (same as BG, already implemented)
- **FG palette region starts at offset 0x200** (per gfx_macross: `0x200, 16`)
- 16 palettes × 16 colors = 256 entries covering 0x200–0x2FF

```
FG final palette RAM address:
  pal_addr = 0x200 + (palette[3:0] * 16) + coloridx[3:0]
           = {2'b10, palette[3:0], coloridx[3:0]}
```

### Transparency
- Transparent pen = **15** (coloridx == 4'hF → pixel is transparent, show layer below)
- From `m_tx_tilemap->set_transparent_pen(15)`

---

## 4. Scroll Registers

### Does the FG layer scroll?
**No.** The FG/text layer does **NOT scroll** for tdragonb2.

Evidence from tdragonb2 memory map: there is no FG scroll register mapped.
The BG scroll registers at 0xC4000–0xC4007 only set `m_bg_tilemap[0]` scroll.
The tx_tilemap scroll position is fixed at its default (0,0) after `set_scrolldx(92,92)`.

For tdragon (original), the `scroll_w<0>` handler at 0x0C4000–0x0C4007 also
only sets `m_bg_tilemap[layer]` scroll, NOT the tx_tilemap.

`set_scrolldx(92, 92)` is a display offset correction (shifts the visible window
by 92 pixels to compensate for the overscan region), not a scroll register.

**FPGA implementation:** The FG layer is always fixed at scroll (0,0). No scroll
registers need to be tracked for FG. Use `scrx=0, scry=0` in jtframe_scroll.

---

## 5. Priority Rules

From `screen_update_macross`:
```cpp
screen.priority().fill(0, cliprect);
bg_update(screen, bitmap, cliprect, 0);   // BG drawn first   (priority 1)
tx_update(screen, bitmap, cliprect);       // FG drawn second  (priority 2)
draw_sprites(screen, bitmap, cliprect, m_spriteram_old2.get()); // sprites LAST
```

**Rendering order (back to front):**
1. BG (16×16 tiles, scrolling)
2. FG text (8×8 tiles, fixed position) — draws over BG
3. Sprites — draw over BOTH BG and FG

**For FPGA pixel pipeline:**
```
Priority mux (highest wins):
  sprite pixel non-transparent → output sprite pixel
  else FG pixel non-transparent → output FG pixel
  else → output BG pixel
```

Palette lookup:
- sprite pixel: pal_addr = {2'b01, spr_pal[3:0], spr_coloridx[3:0]}
- FG pixel:     pal_addr = {2'b10, fg_pal[3:0], fg_coloridx[3:0]}
- BG pixel:     pal_addr = {2'b00, bg_pal[3:0], bg_coloridx[3:0]}

---

## 6. ROM Location Confirmation

**Confirmed via MAME ROM_START and pack_tdragonb2.py:**

| Region | ROM (tdragon) | ROM (tdragonb2) | Size   | BA2 byte offset |
|--------|---------------|-----------------|--------|-----------------|
| fgtile | 91070.6       | 1               | 128KB  | **0x200000**    |
| bgtile | 91070.5       | a2a205          | 1MB    | 0x000000        |
| sprites| 91070.4       | shinea2a2-04    | 1MB    | 0x100000        |

**FG ROM confirmed at BA2 byte offset 0x200000.**

The pack_tdragonb2.py layout:
```
BA2 (0x0C0000):
  +0x000000: 91070.5 BG tiles (1MB)
  +0x100000: 91070.4 sprites  (1MB)
  +0x200000: 91070.6 FG text  (128KB)
```

**No byte-swap needed for FG ROM:** 91070.6 is loaded with plain `ROM_LOAD`
(not `ROM_LOAD16_WORD_SWAP`). JTFRAME downloader swaps 16-bit words.
Since MAME uses plain `ROM_LOAD` (no hardware swap), the downloader swap
introduces a single swap. The FG renderer must account for this.

Actually — re-checking: `ROM_LOAD` in MAME does no byte manipulation. JTFRAME
downloader swaps every pair of bytes in 16-bit mode. For the FG renderer,
each 32-bit read delivers bytes [B3,B2,B1,B0] in positions [31:24,23:16,15:8,7:0]
after the downloader swap. The nibble extraction formula below accounts for this.

**Byte order after JTFRAME download (for a 4-byte tile row):**
SDRAM word = {original_byte3, original_byte2, original_byte1, original_byte0}
where byte0 is the first byte from the ROM file.

---

## 7. jtframe_scroll Usage for FG

The FG layer can use `jtframe_scroll` with SIZE=8:

```verilog
jtframe_scroll #(
    .SIZE   ( 8  ),    // 8×8 tiles
    .VA     ( 10 ),    // VRAM address bits: 32cols × 32rows = 1024 entries = 10 bits
    .CW     ( 12 ),    // tile code width (12 bits: code & 0xfff)
    .PW     (  8 ),    // pixel output width: {pal[3:0], coloridx[3:0]}
    .MAP_HW (  5 ),    // log2(32 tile columns) = 5
    .MAP_VW (  5 )     // log2(32 tile rows) = 5
) u_fg(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( HS            ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .blankn     ( LHBL & LVBL   ),
    .flip       ( 1'b0          ),
    .scrx       ( 10'd0         ),   // FG does not scroll
    .scry       ( 9'd0          ),   // FG does not scroll
    .vram_addr  ( fg_vram_raw   ),
    .code       ( fg_vram_q[11:0] ),
    .pal        ( fg_vram_q[15:12] ),
    .hflip      ( 1'b0          ),   // no flip for tdragon/tdragonb2
    .vflip      ( 1'b0          ),
    .rom_addr   ( fg_rom_addr   ),   // output: tile row address
    .rom_data   ( fg_planar     ),   // input: converted planar pixel data
    .rom_cs     ( fg_rom_cs     ),
    .rom_ok     ( fg_ok         ),
    .pxl        ( fg_pxl        )    // output: {pal[3:0], coloridx[3:0]}
);
```

**VRAM address from jtframe_scroll (column-major):**
jtframe_scroll with TILEMAP_SCAN_COLS equivalent: the framework outputs
`vram_addr = {col[4:0], row[4:0]}` (10 bits for 32×32 map).

The NMK16 column-major VRAM layout stores tile (col, row) at index `col*32 + row`,
which in binary is `{col[4:0], row[4:0]}` — this matches jtframe_scroll's
natural output directly. **No address swizzle needed for FG** (unlike BG which
needs the NMK16 bank swizzle).

---

## 8. mem.yaml: FG Bus Entry

Add a third bus to BA2 for FG tile fetches:

```yaml
params:
  - { name: SPR_OFFSET, value: "22'h10_0000 >> 2" }
  - { name: FG_OFFSET,  value: "22'h20_0000 >> 2" }

sdram:
  banks:
    - buses:
      - name: main
        addr_width: 18
        data_width: 16
    - buses:
      - name: oki
        addr_width: 17
        data_width: 8
    - buses:
      - name: gfx
        addr_width: 22
        data_width: 32
      - name: spr
        addr_width: 22
        data_width: 32
        offset: SPR_OFFSET
      - name: fg
        addr_width: 17
        data_width: 32
        offset: FG_OFFSET
    - buses:
      - name: ram
        addr_width: 16
        data_width: 16
        rw: true
```

**addr_width for fg bus:** FG ROM is 128KB = 32768 × 32-bit words.
32768 = 2^15, but addr_width is byte address bits = 15 + 2 = 17.
So `addr_width: 17` gives word address range 0–32767.

The JTFRAME generator computes: AW = addr_width - 1 = 16, so the internal
word address is 16 bits, covering 65536 entries. The actual FG ROM uses
only the lower 15 bits (32K words). This is correct — oversized is fine.

**FG ROM word address within the fg bus:**
```
tile code T, tile row R (0–7):
  fg_bus_addr = T * 8 + R          (each tile = 32 bytes = 8 words)
  fg_word_addr[14:0] = {T[11:0], R[2:0]}
```

---

## 9. GFX Data Conversion for FG

The FG uses `gfx_8x8x4_packed_msb`. Each 32-bit SDRAM word holds 8 pixels
(one full 8-pixel row). After the JTFRAME download byte-swap, each word is:

```
SDRAM word [31:0] = { pix7_hi, pix7_lo,  pix6_hi, pix6_lo,
                      pix5_hi, pix5_lo,  pix4_hi, pix4_lo,  ...  pix0 }
```

Wait — more carefully: after JTFRAME 16-bit byte-swap, bytes in SDRAM word are:
`[31:24]=byte1, [23:16]=byte0, [15:8]=byte3, [7:0]=byte2`
where byte0..3 are the original ROM file bytes in order.

For `gfx_8x8x4_packed_msb`, ROM byte 0 of a row holds pixels 0 and 1:
- byte0[7:4] = pixel 0 color
- byte0[3:0] = pixel 1 color

After the JTFRAME 16-bit byte-swap, these bytes land at:
- ROM byte0 → SDRAM bits [23:16]
- ROM byte1 → SDRAM bits [31:24]
- ROM byte2 → SDRAM bits [7:0]
- ROM byte3 → SDRAM bits [15:8]

Pixel extraction from SDRAM word `fg_data[31:0]` (pixels left to right = 0..7):
```verilog
// After JTFRAME 16-bit word byte-swap:
// ROM_byte0 is at fg_data[23:16], ROM_byte1 at fg_data[31:24]
// ROM_byte2 is at fg_data[7:0],   ROM_byte3 at fg_data[15:8]

pixel[0] = fg_data[23:20]   // byte0[7:4]
pixel[1] = fg_data[19:16]   // byte0[3:0]
pixel[2] = fg_data[31:28]   // byte1[7:4]
pixel[3] = fg_data[27:24]   // byte1[3:0]
pixel[4] = fg_data[7:4]     // byte2[7:4]
pixel[5] = fg_data[3:0]     // byte2[3:0]
pixel[6] = fg_data[15:12]   // byte3[7:4]
pixel[7] = fg_data[11:8]    // byte3[3:0]
```

Convert to jtframe_scroll planar format (MSB of plane3 = leftmost pixel):
```verilog
// jtframe_scroll expects planar: rom_data[8*(3-plane) + (7-px)] = bit plane_px
// For PW=8 output {pal,pxl}: the 4 planes must be in bits [31:0] as:
// plane3[7:0] in [31:24], plane2[7:0] in [23:16], plane1[7:0] in [15:8], plane0[7:0] in [7:0]
// where bit 7 of each plane = leftmost pixel, bit 0 = rightmost pixel.

wire [31:0] fg_planar;
genvar gi;
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : fg_chunky2planar
        // pixel[gi] = 4-bit value from extraction above
        // assign to planar format
        wire [3:0] fg_pixel_i = ... ; // extracted pixel gi
        assign fg_planar[7-gi]  = fg_pixel_i[0]; // plane 0
        assign fg_planar[15-gi] = fg_pixel_i[1]; // plane 1
        assign fg_planar[23-gi] = fg_pixel_i[2]; // plane 2
        assign fg_planar[31-gi] = fg_pixel_i[3]; // plane 3
    end
endgenerate
```

**Simplified implementation:** Extract pixels 0–7 as nibbles from the byte-swapped
SDRAM word, then repack into jtframe_scroll planar format (same structure as BG
chunky2planar, but simpler — 8 pixels from one word, not 8 pixels from one half
of a 16-pixel tile).

---

## 10. Key Constants Summary

| Parameter             | Value                    | Source                    |
|-----------------------|--------------------------|---------------------------|
| Tile size             | 8×8 pixels               | gfx_macross gfx[0]        |
| Bits per pixel        | 4 (values 0–15)          | gfx_8x8x4_packed_msb      |
| Bytes per tile        | 32                       | 8×8×4/8                   |
| Total tiles in ROM    | 4096                     | 128KB / 32                |
| Tile code bits        | 12 (0x000–0xFFF)         | code & 0xfff              |
| Palette bits          | 4 (upper 4 bits of word) | code >> 12                |
| Palette offset        | 0x200                    | gfx_macross entry         |
| Palette entries       | 256 (16 pal × 16 color)  | 16 palettes               |
| Transparent pen       | 15 (4'hF)                | set_transparent_pen(15)   |
| VRAM range            | 0x0D0000–0x0D07FF        | tdragonb2_map             |
| VRAM size             | 1024 × 16-bit words      | 0x800 bytes               |
| Tilemap dimensions    | 32 cols × 32 rows        | manybloc VIDEO_START      |
| Scan order            | Column-major             | TILEMAP_SCAN_COLS         |
| FG scroll             | None (fixed at 0,0)      | no scroll register mapped |
| FG ROM BA2 offset     | 0x200000 (byte)          | pack_tdragonb2.py         |
| FG ROM SDRAM word base| 0xB0000 (22-bit)         | (0xC0000+0x200000)>>2     |
| FG bus offset param   | FG_OFFSET = 22'h20_0000>>2 | mem.yaml                |
| ROM load type         | ROM_LOAD (plain, no swap)| tdragon ROM_START         |

---

## 11. Priority Pixel Mux (Updated for 3-Layer)

Current video.v has a 2-layer mux (sprite over BG). This must become 3-layer:

```verilog
// Current (2-layer):
assign pal_rd_addr = spr_opaque ? {2'b01, spr_pxl[7:4], spr_pxl[3:0]}
                                : {2'b00, bg_pxl[7:4],  bg_pxl[3:0]};

// New (3-layer, sprites top, FG middle, BG bottom):
wire fg_opaque = fg_pxl[3:0] != 4'hF;
wire spr_opaque = spr_pxl[3:0] != 4'hF;

assign pal_rd_addr =
    spr_opaque ? {2'b01, spr_pxl[7:4], spr_pxl[3:0]}   // sprites over all
  : fg_opaque  ? {2'b10, fg_pxl[7:4],  fg_pxl[3:0]}    // FG over BG
  :              {2'b00, bg_pxl[7:4],  bg_pxl[3:0]};   // BG fallback
```

---

## 12. tdragonb2-Specific Notes

1. **No FG scroll:** tdragonb2_map has no FG scroll register. FG is always at (0,0).
2. **Same FG VRAM address as tdragon:** 0x0D0000–0x0D07FF (confirmed in both maps).
3. **Same ROM (CRC fe365920):** tdragonb2 uses file named "1" with same CRC as
   tdragon's 91070.6.
4. **No tile flip:** tdragon/tdragonb2 do not set ext_callback for sprite flipping,
   and the FG tile_info always passes 0 for flags (no flip). Implement flip=0 always.
5. **Palette format:** RRRRGGGGBBBBRGBx (same 16-bit format, 1024 entries total).
6. **gfx_macross used by both:** Both tdragon and tdragonb2 use
   `GFXDECODE(config, m_gfxdecode, m_palette, gfx_macross)` — identical decode.

---

## 13. Implementation Checklist for Codex

Implement in this exact order, compiling after each step:

- [ ] **Step 1:** Add FG VRAM BRAM (1024 × 16-bit) to `jtnmk16_video.v`
  - Write port: CPU writes via `fgvram_cs` (currently stubbed as `assign fgvram_dout = 16'hFFFF`)
  - Read port: fed to jtframe_scroll u_fg
  - Compile with `verilator --lint-only` before proceeding

- [ ] **Step 2:** Add `fg` bus to `cores/nmk16/cfg/mem.yaml`
  - Add `FG_OFFSET` param (`22'h20_0000 >> 2`)
  - Add `fg` bus entry under BA2 with `addr_width: 17, data_width: 32, offset: FG_OFFSET`
  - Verify game.v compiles after mem.yaml regeneration

- [ ] **Step 3:** Add `fg_chunky2planar` conversion block in `jtnmk16_video.v`
  - 8 pixels per 32-bit word; account for JTFRAME 16-bit byte-swap
  - Byte layout: byte0→[23:16], byte1→[31:24], byte2→[7:0], byte3→[15:8]
  - Compile with `verilator --lint-only`

- [ ] **Step 4:** Instantiate `jtframe_scroll` for FG (`u_fg`) in `jtnmk16_video.v`
  - SIZE=8, VA=10, CW=12, PW=8, MAP_HW=5, MAP_VW=5
  - scrx=0, scry=0 (no scroll)
  - hflip=0, vflip=0
  - Connect fg bus signals (fg_addr, fg_cs, fg_data, fg_ok)
  - Compile with `verilator --lint-only`

- [ ] **Step 5:** Update priority mux in `jtnmk16_video.v`
  - Change 2-way (spr/bg) mux to 3-way (spr/fg/bg)
  - fg palette address: `{2'b10, fg_pxl[7:4], fg_pxl[3:0]}`
  - Compile with `verilator --lint-only`

- [ ] **Step 6:** Wire fg bus ports through `jtnmk16_game.v`
  - Add fg_addr, fg_cs, fg_data, fg_ok ports to jtnmk16_video port list
  - Connect to corresponding ports in jtnmk16_game.v
  - Compile with `verilator --lint-only`

- [ ] **Step 7:** Run jtsim and verify FG text appears over BG in tdragonb2

**Compile gate:** After EACH step, run `verilator --lint-only` on the modified file.
Do NOT proceed to the next step if there are any lint errors or warnings.

---

## 14. Reference: gfx_8x8x4_packed_msb vs gfx_8x8x4_col_2x2_group_packed_msb

| Property          | FG (packed_msb)           | BG/Sprite (col_2x2_group_packed_msb) |
|-------------------|---------------------------|--------------------------------------|
| Tile size         | 8×8 pixels                | 16×16 pixels                         |
| Bytes per tile    | 32                        | 128                                  |
| Pixels per word   | 8 (one row)               | 8 (one half-column)                  |
| Halves per tile   | None (single block)       | Two 8-column halves (left + right)   |
| SDRAM reads/row   | 1                         | 2 (left half, right half)            |
| Address formula   | base + tile*8 + row       | base + tile*32 + row*2 + half        |
