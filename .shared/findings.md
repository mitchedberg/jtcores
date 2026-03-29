# Cross-Agent Findings

Append new findings at the top. Read before debugging any issue.

---

## 2026-03-29: NMK16 tdragonb2 sprite format + address map verified vs MAME

**Sprite attribute layout CONFIRMED CORRECT** vs `src/mame/nmk/nmk16spr.cpp`:
- Word 0 [0]: enabled
- Word 1 [3:0]/[7:4]/[8]/[9]: width_tiles-1 / height_tiles-1 / flipX / flipY
- Word 3: tile_code (full 16-bit; our impl uses [11:0] but MAME passes full 16-bit — tile codes >4095 are possible for large games)
- Word 4 [8:0]: xpos (9-bit, mask 0x1FF)
- Word 6 [8:0]: ypos (9-bit, mask 0x1FF)
- Word 7 [3:0]: palette (4-bit)

**tdragonb2 address map vs tdragonb differences (MAME source):**
- Sprite RAM: 0x0B8000-0x0B8FFF (mainram base 0x0B0000 + 0x8000 offset) ✓ correct
- Video regs (palette=0xC8000, BGVRAM=0xCC000, TXVRAM=0xD0000, scroll=0xC4000) — IDENTICAL to tdragonb ✓
- tdragonb2 does NOT have the 0x044022 protection read (tdragonb does). Our `sprite_fix` at 0x044022 is harmless but unnecessary for tdragonb2.
- tdragonb2 scroll: 0xC4000=scrollX, 0xC4002=nop, 0xC4004=scrollY, 0xC4006=nop ✓ correct
- tdragonb2 has OKI M6295 only (no NMK004 sound chip) ✓ matches our stub

**NMK16 video output at frame 600:** Sprites animating on red background = CORRECT attract mode behavior. BG tiles (BGVRAM) intentionally empty during attract mode; red = palette[0] (background color the CPU writes). Not a bug.

---

## 2026-03-29: Battle Garegga (Raizing) hardware spec — MAME verified

Source: `src/mame/toaplan/raizing.cpp` (no raizing/ subdir; lives under toaplan/).

- CPU: 68000 @ 16MHz (32MHz XTAL / 2)
- ROM: 0x000000–0x0FFFFF (1MB)
- Work RAM: 0x100000–0x10FFFF (64KB)
- Video: GP9001 VDP @ 27MHz
  - GP9001 regs: 0x300000–0x30000D
  - Palette RAM: 0x400000–0x400FFF (4KB, xBGR_555 format)
  - Text VRAM: 0x500000–0x501FFF; linescroll: 0x502000–0x5031FF
- I/O: 0x21C020–0x21C035 (inputs/DIPs)
- Sound latch: 0x600001 (main→Z80); shared RAM: 0x218000–0x21BFFF
- VBLANK: M68K IPL level 4
- Sound CPU: Z80 @ 4MHz + YM2151 @ 4MHz + OKI M6295

---

## 2026-03-29: NMK16 BA2 `fg` bus with `addr_width: 17` generates `fg_addr[16:2]` and `SLOT2_AW(16)`

For JTFRAME `mem.yaml`, `addr_width` is still the byte-address width. After adding NMK16 FG as
`addr_width: 17, data_width: 32, offset: FG_OFFSET`, the generated local wrapper exposes
`fg_addr[16:2]`, adds `.SLOT2_OFFSET(FG_OFFSET[SDRAMW-2:0])`, and instantiates bank 2 as
`.SLOT2_AW(16), .SLOT2_DW(32)` with `.slot2_addr({fg_addr,1'b0})`.

Practical consequence: the FG renderer should drive only the local tile word address
`{tile_code[11:0], row[2:0]}` and must not add the BA2 base again; `FG_OFFSET` already handles it.

---

## 2026-03-29: JTFRAME `mem.yaml` multi-slot SDRAM offsets should use named params, not raw shifted literals

When adding a second ROM bus to the same SDRAM bank, a raw literal offset like `"22'h10_0000 >> 2"`
can generate invalid Verilog in `*_game_sdram.v` as `.SLOT1_OFFSET(22'h10_0000 >> 2[SDRAMW-2:0])`.
Use a named `params:` entry instead, then reference it from `offset:`. Example:
`params: [{ name: SPR_OFFSET, value: "22'h10_0000 >> 2" }]` plus `offset: SPR_OFFSET`.

---

## 2026-03-29: Taito B COLORW=5 fix + TX tile 0 sentinel = full gameplay renders

**COLORW=5 change:** `jttaitob_colmix.v` updated from 4-bit to 5-bit RGB output.
Palette format RRRR GGGG BBBB RGBx has 5-bit channels: R={[15:12],[3]}, G={[11:8],[2]}, B={[7:4],[1]}.
Updated: macros.def JTFRAME_COLORW=4→5, colmix port [3:0]→[4:0], DW=12→15 in jtframe_blank,
rgb_in wire 12→15 bits. Colors noticeably richer after the fix. Lint clean.

**Result at frame ~1100 (300-frame jtsim):** Full Tetris attract mode gameplay board rendering:
colored blocks (red/blue/yellow), NEXT piece preview, TX text layer, bear+circle sprites.
This is the core working for all 4 layers simultaneously.

## 2026-03-29: Taito B TX tile 0 = transparent fix; copyright screen renders

**Bug:** TC0180VCU TX (text) tile pipeline was fetching ROM data for tile code 0 (transparent/blank).
BG and FG pipelines already had `tile_code != 0` sentinel guards; TX was missing it.
Result: ROM tile 0 data (0xb1939309 = dotted pattern) rendered everywhere TX VRAM was uninitialized.

**Fix (tc0180vcu.v line 675):** Added `tx_tile_code != 11'd0` guard + `tx_shift_nxt <= 32'd0` clear,
mirroring the BG/FG pattern.

**Result:** Tetris copyright/warning screen renders correctly at ~frame 150. TX text is fully readable.
BG layer also active at 50M+ cycles (bg_pix_nonzero>0), but GFX arbiter stalls later — separate issue.

**Next:** BG GFX arbiter stall (gfx_ok stops growing at 100M+ cycles). Also check if COLORW=5 helps color fidelity.

---

## 2026-03-29: Toaplan V2 `jttoapv2_video.v` palette address must include tile bank
`jttoapv2_video.v` was indexing palette RAM as `{ 7'd0, pixel_nibble }`, which forced every non-zero tile pixel through entries 0-15. Fixed by decoding `tile_entry[15:14]` as the tile palette bank and using `pal_rd_addr = { 5'd0, tile_pal_bank, pixel_nibble }`. Palette channel decode is now explicit as `R=pal_word[4:0]`, `G=pal_word[9:5]`, `B=pal_word[14:10]`, with 4-bit video output taken from each channel's `[4:1]` bits.

## 2026-03-29: NMK16 BG tiles rendering — key fixes for any new core
Multiple bugs fixed in NMK16 that apply broadly:
1. **VBLANK interrupt must clear on IACK** (FC==111, ASn=0), not on I/O writes. If handler writes scroll regs but not I/O, interrupt re-fires infinitely → stack overflow.
2. **Catch-all DTACK required** for bootleg hardware. Unmapped addresses cause bus error → CPU reset if no DTACK generated. Add `unmapped_cs = !BUSn & ~mapped_cs` to bus_cs.
3. **GFX pixel format**: NMK16 uses chunky 4bpp (each 4 bits = one pixel). jtframe_scroll expects planar (each byte = one bitplane). Must convert: `planar[8*plane+(7-px)] = chunky[4*px+plane]`.
4. **ROM packing**: ALWAYS verify ROM file→SDRAM bank mapping against MAME ROM_REGION definitions. shinea2a2-01 was OKI sound, NOT GFX tiles — loading wrong ROM into GFX bank = invisible tiles.
5. **Shared SDRAM bank contention**: ROM+RAM in same bank can cause wrong data during RTE. Moving RAM to separate bank fixes it (add JTFRAME_BA3_WEN for writable bank 3).

## 2026-03-29: NMK16 first pixels + Z80 sound ACK blocker
NMK16/Thunder Dragon produces first video output (frame 00046: purple tilemap grid; frame 00115: text fragments). CPU executes full ROM space including palette writes at 0x0C85xx. Remaining blocker: CPU stalls polling RAM[0x0B9008] waiting for Z80 to acknowledge sound commands. Fix: Z80 stub must read the 68000→Z80 mailbox at 0x0B9008 and write 0 back. This is SDRAM space (not I/O), so the stub belongs in the Z80 core (jtnmk16_snd.v or equivalent Z80 wrapper), not in main.v. MAME reference: NMK004 sound CPU polls sound_command register and clears it after processing.

## 2026-03-29: Toaplan V2 `jtsim -setname truxton2` blocked by stale `doc/mame.xml`
`cores/toapv2/ver/truxton2` already exists and contains working sim artifacts (`rom.bin`, `sdram_bank*.bin`, `obj_dir/sim`). The exact command `jtsim -setname truxton2 -frame 10` fails before HDL compile because `jtframe mra toapv2` finds `0 games`; repo `doc/mame.xml` has no `truxton2` entry and no `sourcefile="toaplan/toaplan2.cpp"` matches. Useful workaround for local smoke testing: from `cores/toapv2/ver/truxton2`, run `jtsim -skipROM -frame 10` after sourcing `modules/jtframe/bin/setprj.sh`; that compiles and runs 10 frames using existing `rom.bin`/SDRAM dumps.

## 2026-03-29: NMK16 sound status address (from Codex/MAME)
NMK004 sound status read is at 0x0C000E. I/O decode needs A[4:1] not A[3:1] to reach it. Return {8'hFF, 8'h00} for idle. Verified against MAME tdragon_map.

## 2026-03-28: addr_width = byte bits (from Taito B debugging)
JTFRAME mem.yaml addr_width is BYTE address bits. Generator computes AW = addr_width - 1. For a 4096-word 16-bit BRAM, you need addr_width: 13, not 12. Getting this wrong causes address aliasing that breaks boot self-tests.

## 2026-03-28: BRAM port 1 defaults to main_addr (from Taito B)
JTFRAME dual-port BRAMs default port 1 address to main_addr (SDRAM ROM address). For CPU-written BRAMs (palette, VRAM), you MUST add explicit addr field in mem.yaml pointing to the actual CPU bus address.

## 2026-03-28: IOC active-LOW polarity (from Taito B)
JTFRAME tilt/service/cab_1p are active-LOW (1 = not asserted). Do not invert them in the I/O handler.

## 2026-03-28: ROM packing no swap (from Psikyo)
JTFRAME downloader handles byte order. Manual ROM packing must NOT byte-swap.
