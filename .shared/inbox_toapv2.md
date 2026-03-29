# Toaplan V2 Task: Implement GP9001 Sprite Engine

**From:** Claude orchestrator
**Date:** 2026-03-29 (research pre-loaded — no web access needed)
**Priority:** High

## Context

The Toaplan V2 core has working BG tile rendering (Truxton II renders). Next: sprite layer.

Current state of `cores/toapv2/hdl/jttoapv2_video.v`:
- GP9001 register interface already implemented (`gp_cs`, `gp_addr[2:1]`, `gp_voffs`)
- BG0 tilemap: written to `bg_vram[0x000–0x3FF]` when `gp_voffs[15:10]==0`
- NO sprite RAM, NO sprite renderer yet

## GP9001 Hardware Spec — MAME-Verified (No Research Needed)

### VRAM Layout (word addresses via auto-increment interface)

| Region | Word offset | Size |
|--------|-------------|------|
| BG0 tilemap | 0x0000–0x07FF | 0x1000 bytes |
| BG1 tilemap | 0x0800–0x0FFF | 0x1000 bytes |
| TOP tilemap | 0x1000–0x17FF | 0x1000 bytes |
| **Sprite RAM** | **0x1800–0x1BFF** | **0x800 bytes = 256 sprites** |

CPU writes sprites by: set voffs=0x1800, then burst-write sprite words.

### Sprite Attribute Format — 4 words per sprite

| Word | Bits | Field |
|------|------|-------|
| 0 | [15] | Show (enable) |
| 0 | [13] | Flip Y |
| 0 | [12] | Flip X |
| 0 | [11:8] | Priority (0–15) |
| 0 | [7:2] | Color palette (6-bit, 0–63) |
| 0 | [1:0] | Tile number bits [17:16] |
| 1 | [15:0] | Tile number bits [15:0] → 18-bit combined index |
| 2 | [15:7] | X position (9-bit) |
| 2 | [3:0] | X size: (val+1)×8 pixels wide |
| 3 | [15:7] | Y position (9-bit) |
| 3 | [3:0] | Y size: (val+1)×8 pixels tall |

- 256 sprite slots total (0x400 words / 4 words each)
- Skip if word0[15]=0 (inactive)
- Sprites rendered in order; later entries overwrite earlier at equal priority

### GFX ROM Format — NOT standard planar

GP9001 uses a custom 4bpp interleaved format (2 ROM halves, 8×8 base tile, 16×16 multi-tile):
- ROM is split into two halves (RGN_FRAC(1,2) and RGN_FRAC(1,2)+8)
- Per 8-pixel row: 2 bytes total across both ROM halves
- Low-half byte: plane 0 (bit 0) and plane 1 (bit 8)
- High-half byte: plane 2 (bit 0) and plane 3 (bit 8)
- **Consequence:** The packed ROM in SDRAM must be re-decoded or a custom pixel extractor is needed — cannot use jtframe_scroll's standard planar input directly

**Reference for sprite engine FSM pattern:** `cores/nmk16/hdl/jtnmk16_sprite.v`
(double linebuf, per-line DMA scan, transparent pen = 0)

## Current Address Map (from jttoapv2_main.v)

- ROM: 0x000000–0x07FFFF
- RAM: 0x100000–0x10FFFF
- GP9001 VDP regs: 0x200000–0x20000D (`gp_cs`, `gp_addr[2:1]`)
- Palette RAM: 0x300000–0x300FFF
- Text VRAM: 0x400000–0x401FFF
- Text GFX ROM: 0x500000–0x50FFFF

## Task

### Step 1: Extend sprite VRAM in video.v

In `jttoapv2_video.v`, when `gp_voffs` is in range 0x1800–0x1BFF, write to a 256×4-word sprite
RAM BRAM instead of `bg_vram`. Add:
```verilog
reg [15:0] spr_ram [0:1023]; // 256 sprites × 4 words
```
Write condition: `gp_voffs[15:11] == 5'b00011` (i.e., word addr 0x1800–0x1BFF → bits [15:11] = 0b00011)

### Step 2: Add sprite renderer FSM

Model after `cores/nmk16/hdl/jtnmk16_sprite.v`:
- Per-line scan: iterate 256 sprite slots at HBLANK
- For each active sprite (word0[15]=1), enqueue tile fetch
- Decode X/Y from word2/word3, flip from word0[13:12]
- Write pixels to double linebuffer
- Output linebuf pixel on active scan, skip pen=0 (transparent)
- Palette index: `{color[5:0], pixel_nibble}` → 10-bit palette address

### Step 3: Blend sprite layer with BG

In the priority mux, sprite pixels with priority≥BG priority win.

### Compile gate

After each step, run:
```bash
cd cores/toapv2/ver/truxton2
export JTROOT=/Volumes/2TB_20260220/Projects/jtcores JTFRAME=$JTROOT/modules/jtframe MODULES=$JTROOT/modules CORES=$JTROOT/cores JTBIN=$JTROOT/release PATH=$PATH:$JTFRAME/bin
jtsim -lint 2>&1
```

## Signal names to verify first (grep before using)

```bash
grep -n "gp_voffs\|gp_cs\|gp_addr\|gp_dout\|cpu_dout\|cpu_rnw\|LHBL\|LVBL\|hdump\|vdump" cores/toapv2/hdl/jttoapv2_video.v
grep -n "spr_addr\|spr_cs\|spr_data\|spr_ok\|gfx2" cores/toapv2/hdl/jttoapv2_game.v
```

Read `.shared/findings.md` before starting.
Update `.shared/status.md` when you begin.
Append any new findings to `.shared/findings.md`.
