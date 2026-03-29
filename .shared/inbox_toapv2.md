# Toaplan V2 Task: GP9001 Sprite Engine Implementation

**From:** Claude orchestrator
**Date:** 2026-03-29
**Priority:** High

## Context

The Toaplan V2 core (`cores/toapv2/`) has a working BG tile layer (Truxton II renders correctly).
The next major feature is sprite rendering via the GP9001 VDP chip.

**Current state:**
- `cores/toapv2/hdl/jttoapv2_video.v` has BG rendering (jtframe_scroll)
- No sprite layer exists yet
- SDRAM BA2 is used for BG tiles (`gfx_addr/gfx_cs`); sprites may need a separate slot or shared bus

## Task: Research GP9001 Sprite Format (Research Only — No Code Yet)

1. **Read the current video module first:** `cores/toapv2/hdl/jttoapv2_video.v`
2. **Read MAME GP9001 source:** Search `https://github.com/mamedev/mame` for `gp9001.cpp` or `gp9001.h`.
   The GP9001 is the VDP used in Truxton II, Flying Shark, etc.
3. **Extract sprite format:**
   - How many sprites max?
   - Sprite attribute layout (tile code, X, Y, palette, flags)
   - Sprite RAM address in the CPU address map
   - Sprite ROM format (chunky? planar? bits per pixel?)
   - Sprite priority vs BG priority
4. **Check SDRAM bandwidth:**
   - BG tiles are at BA2 (`gfx_addr`)
   - Where should sprite tiles go? Same bank (needs arbitration) or different bank?
   - Read `cores/toapv2/cfg/mem.yaml` to understand current SDRAM config
5. **Reference the working sprite engine:** Read `cores/nmk16/hdl/jtnmk16_sprite.v` to understand
   the pattern we use (double linebuf, per-line DMA scan, FSM-based fetcher).

## What to return

Concise report with:
- GP9001 sprite count, attribute layout (offsets, bit fields)
- Sprite ROM format (bpp, chunky vs planar)
- CPU address map: where is sprite RAM?
- SDRAM plan: which bank/slot for sprite tiles?
- Recommended implementation approach (linebuf FSM like NMK16? Or different?)

DO NOT write any code yet. Research and report only.
Read `.shared/findings.md` before starting.
After completing, append findings to `.shared/findings.md`.
