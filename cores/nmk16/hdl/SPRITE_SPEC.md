# NMK16 Sprite System Specification
## Target: Thunder Dragon / tdragonb2

**Research sources used:** MAME nmk16spr.cpp, nmk16_v.cpp, nmk16.cpp, nmk16.h (all verbatim via GitHub API).
**Date:** 2026-03-29

---

## CRITICAL FINDING: GFX ROM Assignment Mismatch

The existing pack scripts have BG and sprite ROMs **labelled in opposite order** from what MAME
assigns them to their GFX regions. Per MAME `nmk16.cpp`:

| ROM file (tdragon) | ROM file (tdragonb2) | MAME region tag | Purpose        |
|--------------------|----------------------|-----------------|----------------|
| 91070.6            | 1 (or shinea2a2-06)  | `"fgtile"`      | 8x8 FG/text    |
| **91070.5**        | **a2a205**           | **`"bgtile"`**  | **16x16 BG**   |
| **91070.4**        | **shinea2a2-04**     | **`"sprites"`** | **Sprites**    |

The existing `pack_tdragonb2.py` puts 91070.4 first as "BG tiles" and 91070.5 as "sprites" —
this is backwards from MAME. In `pack_tdragon.py` the order is correct (91070.4 is sprites
and goes last in BA2). Codex must implement the sprite renderer to read from the correct offset.

---

## 1. Sprite RAM Layout

### Address in 68000 memory map
- **tdragonb / tdragonb2:** mainram at `0x0B0000–0x0BFFFF` (64 KB SDRAM)
- **tdragon (original):** mainram at `0x080000–0x08FFFF` mirrored to `0x0B0000–0x0BFFFF`
- Our JTFRAME core maps mainram to SDRAM BA3 starting at `0x0B0000`

### DMA mechanism
MAME performs a sprite DMA at vblank-out (2 lines after VBOUT scanline) that copies 0x1000 bytes
(4096 bytes = 2048 16-bit words = 256 sprite slots) from mainram starting at offset `m_sprdma_base`.

`m_sprdma_base` defaults to **`0x8000`** (the initializer in `nmk16_state` constructor at line 52
of `nmk16.h`). This is an **offset within mainram**, not an absolute address.

- tdragon mainram starts at 0x080000, so sprite DMA reads from `0x080000 + 0x8000 = 0x088000`
- tdragonb/tdragonb2 mainram starts at 0x0B0000, so sprite DMA reads from `0x0B0000 + 0x8000 = 0x0B8000`

The double-buffered DMA copies 0x1000 bytes per frame into `spriteram_old2` (2 frames latency for
most games). The sprite renderer reads from `spriteram_old2`.

### Sprite count
`draw_sprites` iterates: `for (int offs = 0; offs < size; offs += 8)` where `size = 0x1000 / 2 = 2048 words`.
Each sprite entry is **8 words (16 bytes)**. So: `2048 / 8 = 256 sprite slots maximum`.

Hardware enforces a clock budget: max `384 * 263 = 101,112` cycles. Each sprite costs 16 + 128*w*h
cycles, so a 1x1 single-tile sprite = 144 cycles, limiting real-world sprite count.

---

## 2. Sprite Entry Format (16 bytes = 8 x 16-bit words per entry)

All indices are **word** (u16) offsets from the start of the sprite entry.

```
Word  Byte  Bits             Field
----  ----  ---------------  -------------------------------------------
 +0   0x00  bit 0            ENABLE: 1 = sprite visible, 0 = skip
 +1   0x02  bits [3:0]       WIDTH_MINUS1: number of tiles wide minus 1 (range 0..15, actual tiles 1..16)
            bits [7:4]       HEIGHT_MINUS1: number of tiles tall minus 1 (range 0..15, actual tiles 1..16)
            bit  8           FLIPX: 1 = flip horizontally (get_sprite_flip callback)
            bit  9           FLIPY: 1 = flip vertically   (get_sprite_flip callback)
            bits [15:10]     unused (for standard tdragon; powerins uses bit 12 for extra flip)
 +2   0x04  (unused, all bits)
 +3   0x06  bits [15:0]      TILE_CODE: full 16-bit sprite code (GFX ROM tile index)
 +4   0x08  bits [8:0]       X_POS: X screen position (9-bit, masked with 0x1FF)
            bits [15:9]      unused (for standard tdragon)
 +5   0x0A  (unused, all bits)
 +6   0x0C  bits [8:0]       Y_POS: Y screen position (9-bit, masked with 0x1FF)
            bits [15:9]      unused
 +7   0x0E  bits [3:0]       PALETTE: 4-bit palette index (masked to 0xF by get_colour_4bit)
            bits [15:4]      unused
```

### Key field details
- **ENABLE** (word+0 bit 0): If clear, the entire sprite is skipped. No other bits matter.
- **WIDTH/HEIGHT** (word+1 bits 7:0): These are tile counts, not pixel sizes. A value of 0
  means 1 tile wide/tall. A multi-tile sprite draws tiles left-to-right then top-to-bottom,
  with tile code incrementing by 1 per column and by (w+1) per row. (See tile sequencing below.)
- **FLIPX/FLIPY** (word+1 bits 9:8): These are in the same word as width/height. The callback
  `get_sprite_flip` extracts: `flipy = BIT(attr, 9); flipx = BIT(attr, 8)`.
- **TILE_CODE** (word+3 all 16 bits): Full GFX ROM tile index. For tdragon, all 16 bits are used.
  For powerins variant, only lower 15 bits are used with bit 8 extending the code; do not
  implement the powerins variant.
- **X_POS** (word+4 bits 8:0): Screen X coordinate in pixels, `0x000`–`0x1FF`. Subject to
  wraparound (see section 3). `m_videoshift` is 0 for tdragon (no horizontal video shift).
- **Y_POS** (word+6 bits 8:0): Screen Y coordinate in pixels, `0x000`–`0x1FF`. Subject to
  wraparound.
- **PALETTE** (word+7 bits 3:0): Selects one of 16 palettes. The sprite GFX region starts at
  palette offset 0x100 in the global palette (see gfx_macross: `0x100, 16`), so the final
  palette RAM index for a pixel with color value N and palette P is:
  `pal_addr = 0x100 + (P * 16) + N`

---

## 3. GFX ROM: Tile Format

### ROM file
- **tdragon:** `91070.4` loaded as `ROM_LOAD16_WORD_SWAP` into MAME region `"sprites"`, 1 MB
- **tdragonb2:** `shinea2a2-04` (same CRC), also `ROM_LOAD16_WORD_SWAP`

### MAME gfx_macross decode entry for sprites (gfx[2])
```cpp
static GFXDECODE_START( gfx_macross )
    GFXDECODE_ENTRY( "fgtile",  0, gfx_8x8x4_packed_msb,               0x200, 16 ) // gfx[0]
    GFXDECODE_ENTRY( "bgtile",  0, gfx_8x8x4_col_2x2_group_packed_msb, 0x000, 16 ) // gfx[1]
    GFXDECODE_ENTRY( "sprites", 0, gfx_8x8x4_col_2x2_group_packed_msb, 0x100, 16 ) // gfx[2]
GFXDECODE_END
```

Sprites use **`gfx_8x8x4_col_2x2_group_packed_msb`** — exactly the same format as BG tiles.

### gfx_8x8x4_col_2x2_group_packed_msb layout (verbatim from generic.cpp)
```cpp
const gfx_layout gfx_8x8x4_col_2x2_group_packed_msb =
{
    16,16,
    RGN_FRAC(1,1),
    4,
    { STEP4(0,1) },
    { STEP8(0,4), STEP8(4*8*16,4) },  // x order: hi nibble first, low nibble second
    { STEP16(0,4*8) },
    16*16*4
};
```

This means:
- **Tile size:** 16×16 pixels
- **Bits per pixel:** 4 (values 0–15)
- **Bytes per tile:** 16 * 16 * 4 bits / 8 = 128 bytes

### Pixel extraction formula
The format stores a 16×16 tile as TWO 8×16 half-tiles packed together:

- **Left half** (columns 0–7): bytes 0–63 of the tile
- **Right half** (columns 8–15): bytes 64–127 of the tile (at offset `4*8*16` bits = 64 bytes)

Within each half:
- Each row is 8 pixels × 4 bits = 32 bits = 4 bytes
- Row 0 = bytes 0–3, row 1 = bytes 4–7, … row 15 = bytes 60–63
- Within each 4-byte row, pixels are packed MSB-first as nibbles:
  - Byte 0: pixel 1 (bits [7:4]) then pixel 0 (bits [3:0])
  - Byte 1: pixel 3 (bits [7:4]) then pixel 2 (bits [3:0])
  - Byte 2: pixel 5 (bits [7:4]) then pixel 4 (bits [3:0])
  - Byte 3: pixel 7 (bits [7:4]) then pixel 6 (bits [3:0])

Wait — the `{ STEP4(0,1) }` means bit planes 0,1,2,3 are at bit positions 0,1,2,3 within a
word (4 bits packed = 1 nibble per pixel). Reading more carefully:

**Actual MAME expansion for gfx_8x8x4_col_2x2_group_packed_msb:**
- 4 bit planes at bit offsets 0,1,2,3 (all within same byte — interleaved nibble format)
- X step: `STEP8(0,4)` = pixel columns 0–7 at bit positions 0,4,8,12,16,20,24,28
  then `STEP8(4*8*16,4)` = pixel columns 8–15 at bit positions 512,516,...,540
  (offset 512 bits = 64 bytes into tile data)
- Y step: `STEP16(0,4*8)` = each row is 32 bits = 4 bytes apart

**In plain terms — how to read a pixel at (col, row) from tile_code T:**

```
tile_base_byte = tile_code * 128   (128 bytes per tile)

if (col < 8):
    byte_within_tile = row * 4 + (col >> 1)        # half col in bytes
    nibble_select = 1 - (col & 1)                  # col 0 => high nibble, col 1 => low nibble
else:
    byte_within_tile = 64 + row * 4 + ((col-8) >> 1)
    nibble_select = 1 - ((col-8) & 1)

rom_byte = ROM[tile_base_byte + byte_within_tile]
pixel_4bit = (nibble_select ? (rom_byte >> 4) : (rom_byte & 0xF))
```

This is identical to the BG tile format already implemented in `jtnmk16_video.v`.
The existing `chunky2planar` conversion logic used for BG applies equally to sprites.

### Verification
The current BG renderer reads from SDRAM with `gfx_data[31:0]` (32-bit bus, 4 bytes at once)
and converts chunky nibbles to planar format via the `chunky2planar` generate block.
The same format applies to sprites: 4bpp chunky, MSB-first nibble per pixel, two 8-column
halves stored sequentially.

### Tile code to SDRAM byte address
In the current JTFRAME mem.yaml:
- BA2 starts at `JTFRAME_BA2_START = 0xC0000`
- BA2 layout in `pack_tdragonb2.py`: [BG 1MB at offset 0] + [sprites 1MB at offset 0x100000] + [FG 128KB at offset 0x200000]
- So **sprite tiles start at BA2 byte offset 0x100000**
- BA2 SDRAM word address 0 = byte 0x0C0000 in SDRAM space
- Sprite tile_code T → SDRAM byte address = `0x0C0000 + 0x100000 + T * 128`
  = `0x1C0000 + T * 128`
- SDRAM 32-bit word address = `(0x1C0000 + T * 128 + row_byte_offset) >> 2`

**In the gfx_addr bus format** (22-bit `gfx_addr[21:2]` = 32-bit word address):
```
sprite_word_addr[21:0] = (22'h70000 + tile_code * 32 + word_offset_within_tile)
```
where `word_offset_within_tile` ranges from 0 to 31 (128 bytes / 4 bytes per word = 32 words).

Note: `0x1C0000 >> 2 = 0x70000`. Each tile is 128 bytes = 32 32-bit words.

**IMPORTANT:** The BG renderer currently uses the full 22-bit `gfx_addr` bus (`gfx_addr[21:2]`).
The sprite renderer will need to share or arbitrate this bus. (See section 6.)

---

## 4. Rendering Behavior

### Priority
From `screen_update_macross`:
```cpp
screen.priority().fill(0, cliprect);
bg_update(screen, bitmap, cliprect, 0);   // BG drawn first
tx_update(screen, bitmap, cliprect);       // FG text drawn second
draw_sprites(screen, bitmap, cliprect, m_spriteram_old2.get()); // sprites drawn LAST
```

Sprites are drawn **on top of** both BG and FG text. There is **no per-sprite priority bit** for
tdragon — `get_colour_4bit` sets `pri_mask |= GFX_PMASK_2` meaning sprites go under foreground
priority layer 2. However, in `screen_update_macross`, sprites are drawn last, after FG text.

**For FPGA implementation:** sprites overlay both BG and FG. Use a line buffer where sprite
pixels (non-transparent) overwrite BG pixels. FG text vs sprite layering is a secondary concern;
for initial implementation, draw sprites above everything.

### Transparency
From `transpen` call in nmk16spr.cpp: transparency pen = **15** (color index 15 is transparent).
Do NOT output a pixel when the 4-bit color index == 4'hF.

### Flip
- `FLIPX` (word+1 bit 8): mirror tile horizontally (reverse column order within tile)
- `FLIPY` (word+1 bit 9): mirror tile vertically (reverse row order within tile)
- Both can be active simultaneously
- For a multi-tile sprite, flip reverses the entire multi-tile grid, not individual tiles:
  - With FLIPX: columns of tiles are drawn right-to-left, and each tile is also h-mirrored
  - With FLIPY: rows of tiles are drawn bottom-to-top, and each tile is also v-mirrored
  - The tile CODE sequence still increments left-to-right, top-to-bottom before flip is applied

### Clip / Wraparound
- Screen is 256×224 pixels (JTFRAME_WIDTH=256, JTFRAME_HEIGHT=224)
- X position mask = `0x1FF` (9-bit), Y position mask = `0x1FF` (9-bit)
- Wraparound: if `sx > max_x` then `sx -= 0x200`; if `sx < min_x - 15` similarly
- In practice for FPGA: sprites that go partially off screen should be clipped at screen edges
- X coordinate range 0–255 is on-screen; 0x100–0x1FF wraps to -256 to -1 (sprite off left edge)

### Zoom / Scaling
**No zoom or scaling.** The NMK16 hardware does not support sprite scaling. All sprites are
rendered at 1:1 pixel scale. The tile size is always 16×16.

### Multi-tile sprites
A sprite with WIDTH_MINUS1=W and HEIGHT_MINUS1=H draws (W+1)*(H+1) tiles arranged in a grid:
- Grid is (W+1) tiles wide, (H+1) tiles tall
- Top-left tile uses TILE_CODE
- Tiles increment by 1 per column (left-to-right)
- Tiles increment by (W+1) per row (top-to-bottom)
- Screen position of tile at grid (col, row) = (sx + col*16, sy + row*16) [before flip]
- After flip: if FLIPX, X position = sx + (W - col)*16; if FLIPY, Y = sy + (H - row)*16

### Rendering order
Sprites are rendered in order of ascending word offset (sprite 0 first, sprite 255 last).
Later sprites in RAM overwrite earlier ones (no sprite-vs-sprite depth sorting).
The clock budget check means high-slot sprites may be culled if earlier sprites are complex.

---

## 5. Verilog Implementation Guide

### Existing video.v signals available for sprite renderer

From `jtnmk16_video.v` module ports (all signals available as wires):

```verilog
// Timing
input         clk          // 48 MHz system clock
input         pxl_cen      // ~6 MHz pixel clock enable
input         LHBL         // active-high horizontal blank (low = display, LHBL=1 during hblank)
input         LVBL         // active-high vertical blank
input   [8:0] hdump         // horizontal counter 0..395
input   [8:0] vdump         // vertical counter

// Palette RAM port 2 (currently driven by bg_pxl)
// To share: pal_rd_addr must mux between BG and sprite pixel
wire  [9:0] pal_rd_addr   // drives palette RAM addr port 1

// GFX ROM bus (shared with BG renderer)
output [21:2] gfx_addr    // currently = {3'b0, bg_rom_addr}
output        gfx_cs      // currently = bg_rom_cs
input  [31:0] gfx_data    // 32-bit SDRAM read data
input         gfx_ok      // SDRAM read valid

// Pixel output (driven from palette lookup)
output [4:0]  red, green, blue
```

**Missing signals needed for sprite renderer (must be added to game.v + video.v):**

The sprite renderer needs access to sprite RAM. Since sprite data lives in the SDRAM work RAM
(BA3), and that RAM is shared with the CPU, there are two options:

**Option A (recommended): Sprite line buffer in BRAM, sprite scan during hblank**
- CPU writes sprite attributes to SDRAM work RAM during game logic
- At hblank: sprite renderer scans sprite RAM from SDRAM, fills a line buffer
- During active display: sprite line buffer pixels mixed with BG pixels

**Option B: Shadow copy in BRAM**
- Add a 0x1000-byte BRAM mirror of sprite RAM that gets DMA-updated each vblank
- Simpler access but requires an extra 4 KB BRAM

### Suggested implementation: Line buffer approach

```verilog
// jtnmk16_sprite.v — suggested module interface
module jtnmk16_sprite(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         LHBL,
    input         LVBL,
    input   [8:0] hdump,
    input   [8:0] vdump,

    // Sprite RAM access (read-only, from shadow BRAM)
    // Shadow BRAM is updated at vblank from SDRAM work RAM
    output  [9:1] spr_ram_addr,    // 512 16-bit words (covers 256 sprites × 8 words)
    input  [15:0] spr_ram_q,

    // GFX ROM (sprite tiles — shared bus, arbited with BG renderer)
    output [21:2] spr_rom_addr,
    output        spr_rom_cs,
    input  [31:0] spr_rom_data,
    input         spr_rom_ok,

    // Pixel output (line buffer → composite)
    output  [7:0] spr_pxl,         // {palette[3:0], coloridx[3:0]}; coloridx==4'hF => transparent
    output        spr_pxl_valid    // 1 when spr_pxl is non-transparent
);
```

### Sprite RAM shadow BRAM
Add a 4 KB (2 KB × 16-bit) BRAM inside `jtnmk16_video.v`:
- Write port: CPU writes via `ram_cs` when address maps to sprite area
  (`0x0B8000–0x0B8FFF`)
- Read port: sprite scanner reads during hblank/vblank

This avoids needing SDRAM bandwidth for sprite RAM access.

**Alternatively:** expose sprite RAM as a new chip select from `jtnmk16_main.v`:
```verilog
// In jtnmk16_main.v address decode:
spr_cs = !BUSn && A[23:12] == 12'h0B8;  // 0x0B8000-0x0B8FFF
```
Then route the BRAM into `jtnmk16_video.v`.

### Line buffer architecture
1. **During hblank** (when `~LHBL`): scan all 256 sprite slots, for each visible sprite
   on the current scan line, write pixels into a 256-entry line buffer (`linebuf[0:255]`)
2. **During active scan** (when `LHBL`): read `linebuf[hdump]` and output the pixel
3. Line buffer is 8 bits wide: `{palette[3:0], coloridx[3:0]}`; entry 0 = transparent (coloridx = 4'hF)
4. Clear line buffer at start of each hblank

**CRITICAL GOTCHA:** The sprite scan must complete within the hblank period.
- Hblank width: 395 - 255 = 140 pixel clocks (at 6 MHz ≈ 23 µs)
- At 48 MHz with pxl_cen, 140 pixel periods = 140 × 8 = 1120 clk cycles
- Each sprite slot: 1 read (enable word) + up to 7 more reads + GFX ROM fetches
- For a full 256-slot scan: 256 × 8 word reads = 2048 reads minimum
- This CANNOT complete in hblank at pixel clock rate

**Solution:** Run the sprite scanner at full 48 MHz (not pixel clock rate). At 48 MHz,
1120 cycles is sufficient for 256 sprite attribute reads (4-5 cycles each). GFX ROM
fetches require SDRAM bandwidth sharing with BG renderer.

**Alternative:** Pre-scan during vblank (54 lines × 384 pixels = ~20,736 pixel clocks worth of
time). This is the preferred approach: at start of each scanline during vblank or hblank of the
PREVIOUS line, build the line buffer for the NEXT scanline.

### GFX ROM address for sprites
```verilog
// tile_code is 16 bits from spriteram[offs+3]
// Each tile is 128 bytes = 32 32-bit words
// Sprite ROM starts at byte offset 0x100000 within BA2
// BA2 starts at 0x0C0000 in SDRAM space
// So sprite byte 0 is at SDRAM byte addr 0x1C0000
// 32-bit word addr = 0x1C0000 >> 2 = 0x70000

// Within a tile, word address for (row, half_col):
// half_col 0 = left 8 columns (bytes 0..63, words 0..15)
// half_col 1 = right 8 columns (bytes 64..127, words 16..31)
// word_in_tile = row * 2 + half_col_word_offset
// For full row (32 bits = 8 pixels per half): word_in_tile = {half_col, row[3:0], pixel_word[?]}

// Simplified: each 4-byte word holds 8 pixels of one half (col<8 or col>=8)
// For a full 16-pixel-wide row, need 2 reads: one for left half, one for right half
// word addr = 22'h70000 + tile_code * 32 + row * 2 + half

assign spr_rom_addr = 22'h70000 + {tile_code, 5'b00000} + {row[3:0], half[0]};
// where tile_code[15:0], row[3:0]=scanline within tile, half=0 for left, 1 for right
```

### Palette address for sprites
```verilog
// Sprite palette region starts at palette offset 0x100 (256)
// palette[3:0] is 4-bit value from spriteram[offs+7] & 0xF
// coloridx[3:0] is pixel from GFX ROM
// Final palette RAM address:
pal_rd_addr = {2'b01, palette[3:0], coloridx[3:0]};
// = 10'h100 + palette * 16 + coloridx
// Range: 0x100–0x1FF (256 palette entries for sprites, 16 per palette × 16 palettes)
```

This must be muxed with the BG palette address. When outputting a sprite pixel, use the sprite
palette address; otherwise use the BG palette address.

---

## 6. SDRAM Bus Arbitration (IMPORTANT)

The current implementation assigns the full `gfx_addr/gfx_cs/gfx_data/gfx_ok` bus exclusively
to the BG renderer. Sprites need the same bus.

**mem.yaml** allocates SDRAM BA2 as a single 32-bit bus named `gfx`:
```yaml
- buses:
  - name: gfx
    addr_width: 22
    data_width: 32
```

This single bus cannot be driven from two sources simultaneously. Options:

**Option A (simplest for initial implementation):** Time-multiplex the bus.
- BG renderer uses it during active display (continuous tile fetches for scroll)
- Sprite renderer uses it during hblank to pre-fetch sprite tile data into a tile cache BRAM
- Requires careful arbitration logic in game.v

**Option B:** Request a second SDRAM bank for sprites.
- Add a second `gfx` bus (e.g., `spr`) in mem.yaml pointing to BA2 with a different address range
- JTFRAME SDRAM controller can handle multiple banks; however BA2 is already a single bank

**Option C (recommended for correctness):** Use a sprite tile cache.
- During active display, when the BG is not fetching (during hblank of current line), pre-fetch
  sprite tile rows for the next scanline into a line BRAM
- One tile fetch per sprite per scanline (for a 1×1 sprite): 2 SDRAM reads (left+right halves)
- Store fetched pixel data in a small tile row cache
- This avoids needing two concurrent SDRAM buses

For **first implementation**, the simplest approach: add a second named bus `spr_gfx` in mem.yaml
identical to `gfx` but with a different name. JTFRAME will map both to BA2 SDRAM with independent
request/ok handshaking. Then arbitrate in game.v so BG and sprite requests don't conflict.

---

## 7. Summary of Key Constants

| Parameter | Value | Source |
|-----------|-------|--------|
| Sprite entry size | 8 words (16 bytes) | nmk16spr.cpp |
| Max sprite slots | 256 | 0x1000/0x10 |
| Tile size | 16×16 pixels | gfx layout |
| Bits per pixel | 4 (values 0–15) | gfx layout |
| Bytes per tile | 128 | 16×16×4/8 |
| Transparent pen | 15 (4'hF) | transpen call |
| X/Y position mask | 0x1FF (9-bit) | m_xmask default |
| Palette offset | 0x100 | gfx_macross |
| Palette bits | 4 (0xF mask) | get_colour_4bit |
| Sprite ROM start (BA2 offset) | 0x100000 | pack_tdragonb2.py |
| Sprite ROM SDRAM word base | 0x70000 (22-bit word addr) | calculated |
| Video shift | 0 | m_videoshift=0 default |
| Flip in word+1 | bit9=flipy, bit8=flipx | get_sprite_flip |
| Clock budget | 384×263 = 101,112 | nmk16spr.h default |

---

## 8. Gotchas and Special Cases

1. **ROM byte swap**: 91070.4 (sprites) is loaded with `ROM_LOAD16_WORD_SWAP` in MAME. JTFRAME
   downloader also byte-swaps 16-bit words. The two swaps cancel — ROM is stored as-is in SDRAM.
   Do NOT add manual byte swapping in the sprite renderer.

2. **Double-buffered sprite RAM**: MAME uses `spriteram_old2` (2-frame lag). This prevents
   sprite tearing. For FPGA, using a single BRAM snapshot updated at vblank-out is sufficient
   for initial implementation. Match timing more closely later.

3. **Multi-tile tile code sequence**: Code increments left-to-right, top-to-bottom regardless
   of flip. Flip only affects rendering position, not code order. From nmk16spr.cpp:
   ```cpp
   codecol++;          // after each X step
   code += (w + 1);   // after each Y step
   ```
   With flip, the starting position changes but iteration direction reverses.

4. **Clock budget culling**: Hardware stops rendering sprites when the clock budget is exceeded.
   For FPGA, implementing a cycle counter and stopping sprite scan when budget is reached will
   improve accuracy but is not required for basic functionality.

5. **tdragonb2 uses NO ext_cb**: Looking at tdragonb2 machine config, it calls
   `m_spritegen->set_colpri_callback(FUNC(nmk16_state::get_colour_4bit))` but does NOT call
   `set_ext_callback` — meaning `m_ext_cb.isnull()` is true, so flip bits are NOT decoded for
   tdragonb2! Only `get_colour_4bit` runs, masking palette to 4 bits. **This means flipping
   may not be used in tdragonb2 at all.** Implement flip anyway for completeness, but do not
   expect flipped sprites in tdragonb2 gameplay.

   The original tdragon also does NOT set ext_callback (looking at line 4980-4992:
   `tdragon` config only calls `set_colpri_callback`). So **no flip for tdragon either**.
   get_sprite_flip is only set for tharrier (line 4552) and some other variants.

   **Revised flip status:** For tdragon and tdragonb2, word+1 bits [9:8] are irrelevant —
   sprites are never flipped. Implement flip support in the spec but note it will not be
   exercised by these two game variants.

6. **Sprite rendering order in screen_update_macross**: sprites are drawn AFTER BG and FG text.
   In JTFRAME pixel pipeline, this means sprite pixels should take priority over BG pixels in
   the final color mux.

7. **GFX rom decode format is identical to BG tiles**: The `chunky2planar` logic already in
   `jtnmk16_video.v` applies directly to sprite GFX data. Reuse the same bit extraction.

8. **Y coordinate**: The NMK16 screen has 224 active lines (vdump 0–223). Y=0 places the top
   of a 16×16 sprite at the first visible scanline. Sprites at Y=224 or higher wrap around
   (Y & 0x1FF >= 224 means off-screen below). For tdragon's 256×224 display, the active Y
   range is 0–223.

9. **Sprite scan timing with vdump**: The line buffer for scanline N should be filled during
   scanline N-1's hblank (or during the vblank period for the first line). vdump increments
   once per line.

---

## 9. Implementation Checklist for Codex

In order, implement:

- [ ] Add sprite RAM shadow BRAM (2 KB × 16-bit) to `jtnmk16_video.v`, written by CPU at `0x0B8000`
- [ ] Create `jtnmk16_sprite.v` module with interface defined in section 5
- [ ] Implement sprite attribute scan loop (256 slots, check enable bit, extract fields)
- [ ] For each enabled sprite, determine which scanline rows are visible on current vdump
- [ ] Fetch GFX ROM tile data for visible rows (reuse chunky2planar from BG renderer)
- [ ] Fill line buffer with sprite pixels for non-transparent colors
- [ ] Handle GFX ROM bus arbitration between BG and sprite renderers in `jtnmk16_video.v`
- [ ] Mux sprite pixels over BG pixels in color output (sprite non-transparent takes priority)
- [ ] Mux palette RAM address between BG and sprite renderers
- [ ] Wire new module into `jtnmk16_game.v`
- [ ] Verify with `verilator --lint-only` after each step

**Compile gate:** After adding sprite BRAM to video.v, run lint before proceeding.
After creating sprite.v module stub, run lint before filling in logic.
After connecting to game.v, run lint before simulation.
