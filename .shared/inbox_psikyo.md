# Psikyo Task: Implement BG Tile Rendering (Gunbird)

**From:** Claude orchestrator
**Date:** 2026-03-29
**Priority:** High — CPU already boots, this is the next milestone

## Context

The Psikyo core (`cores/psikyo/`) has a working 68000 CPU (verified simulating) but NO video
output — the current `jtpsikyo_game.v` outputs `red=0, green=0, blue=0`. This task implements
the two BG tile layers.

The full hardware spec is in `.shared/findings.md` (Psikyo section). Summary of what you need:

## Hardware Spec

**BG Layers:** 2 independent scroll layers
- Tile size: 16×16 pixels, 4bpp packed_msb format (SAME as NMK16 — reuse the chunky2planar logic)
- VRAM: Layer 0 at 0x800000–0x801FFF, Layer 1 at 0x802000–0x803FFF (each 8KB = 4096 entries)
- Each VRAM entry (16 bits): bits[12:0] = tile code (13-bit), bits[15:13] = color (3 bits)
- Scroll regs inside 0x804000 region:
  - Layer 0 Y scroll: offset +0x402 (word addr)
  - Layer 0 X scroll: offset +0x406
  - Layer 1 Y scroll: offset +0x40A
  - Layer 1 X scroll: offset +0x40E

**Palette:** 0x600000–0x601FFF (4096 × 16-bit, xRGB_555 = same as Toaplan V2)
- Sprite palettes: pens 0x000–0x7FF (but sprites are NOT in this task)
- Tile palettes start at pen 0x800; pen = `0x800 + (color + layer * 0x40) * 16 + pixel_nibble`

**Pixel output:** COLORW=5 (5 bits per channel)

## Before Writing Any Code

1. **Read the primary reference:** `cores/nmk16/hdl/jtnmk16_video.v` — it already implements:
   - `jtframe_scroll` for BG tiles (16×16, 4bpp, chunky2planar)
   - Palette RAM (jtframe_dual_ram)
   - Pixel output
2. **Read the reference palette:** `cores/toapv2/hdl/jttoapv2_video.v` — for xRGB_555 decode
3. **Grep all signal names** before using them: `grep -n "gfx_addr\|gfx_cs\|gfx_data\|gfx_ok" jtpsikyo_game.v`
4. **Read the current stub:** `cores/psikyo/hdl/jtpsikyo_game.v` and `jtnmk16_video.v` before writing anything

## Implementation Plan (in order, one at a time)

### Step 1: Create `cores/psikyo/hdl/jtpsikyo_video.v`

Minimal module with:
- BG VRAM 0: `jtframe_dual_ram #(.DW(16), .AW(12))` (4096 entries)
- BG VRAM 1: `jtframe_dual_ram #(.DW(16), .AW(12))` (4096 entries)
- Palette RAM: `jtframe_dual_ram #(.DW(16), .AW(12))` (4096 entries)
- Scroll registers for both layers
- `jtframe_scroll` for layer 0 (SIZE=16, VA=11, CW=13, PW=8, MAP_HW=10, MAP_VW=9, HJUMP=1)
- `jtframe_scroll` for layer 1 (same parameters)
- Chunky2planar conversion (reuse from NMK16 exactly)
- 2-layer + palette priority mux (layer 0 over layer 1, transparent = 0)
- Pixel output: `red = {pal_q[14:10]}`, `green = {pal_q[9:5]}`, `blue = {pal_q[4:0]}`

Port list: same pattern as jtnmk16_video.v but with 2 scroll inputs, 2 VRAM write enables.

After writing: run `jtsim -lint` from `cores/psikyo/ver/gunbird` (or game/).

### Step 2: Wire it up in `jtpsikyo_game.v`

Connect the new jtpsikyo_video module, providing:
- CPU VRAM write data (cpu_dout, rnw, cs signals)
- GFX ROM interface (gfx_addr, gfx_cs, gfx_data, gfx_ok) from JTFRAME ports
- Pixel output (red, green, blue) to JTFRAME ports

### Step 3: Add to `cores/psikyo/cfg/mem.yaml`

Add BG GFX ROM to BA2 (check what's already there first).

## Constraints
- One file at a time, compile between each
- Grep every signal name before using it
- Start from Step 1 only — do not modify game.v until video.v lints clean
- Return: files created, compile results, warnings

Read `.shared/findings.md` Psikyo section before starting.
Update `.shared/status.md` when you begin.
