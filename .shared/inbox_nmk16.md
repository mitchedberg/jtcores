# NMK16 Task: Sprite Format & Scroll Register Verification

**From:** Claude orchestrator
**Date:** 2026-03-29
**Priority:** High

## Context

NMK16 (Thunder Dragon / tdragonb2) simulation now produces visible video output at frame 17+.
Sprites and background pixels are visible. We need to verify two things:

## Task 1: Verify Sprite Attribute Layout

Our current sprite renderer (`cores/nmk16/hdl/jtnmk16_sprite.v`) reads sprite attributes from
sprite RAM at 0x0B8000. The current attribute layout:

- Word 0 (offset 0): enabled bit = `spr_ram_qi[0]`
- Word 1 (offset 1): attr1 — `[3:0]`=width_tiles-1, `[7:4]`=height_tiles-1, `[8]`=flipX, `[9]`=flipY
- Word 3 (offset 3): tile_code (12-bit base code)
- Word 4 (offset 4): xpos
- Word 6 (offset 6): ypos
- Word 7 (offset 7): palette (4-bit in `[3:0]`)

**Your job:**
1. Fetch the MAME source for NMK16/Thunder Dragon: search GitHub at `https://github.com/mamedev/mame/blob/master/src/mame/nmk/nmk16.cpp` for the sprite rendering function. Look for `nmk16_state::draw_sprites` or similar.
2. Extract the exact attribute word layout (offsets, bit fields) from MAME's draw_sprites function.
3. Compare against our implementation in `jtnmk16_sprite.v` (read the file first).
4. Report any discrepancies. DO NOT modify any code — just report findings.

## Task 2: Verify Scroll Register Decode for tdragonb2

The scroll registers in `jtnmk16_video.v` are decoded as:
- `cpu_addr[2:1]==0` → scrollX (0xC4000)
- `cpu_addr[2:1]==2` → scrollY (0xC4004)

But tdragonb2 is a bootleg. Check MAME source:
1. Search `nmk16.cpp` for `tdragonb2` device definition and its address map.
2. Check if the bootleg uses the same scroll register addresses as the original tdragon.
3. Also check palette RAM format: does tdragonb2 use the same RGB format as the original?
   Our current decode: `red={pal_q[15:12],pal_q[3]}`, `green={pal_q[11:8],pal_q[2]}`, `blue={pal_q[7:4],pal_q[1]}`
4. Report findings. DO NOT modify any code.

## What to return

Return a concise markdown report with:
- Sprite attribute layout: MAME vs ours (table format, note any discrepancies)
- Scroll register map: bootleg vs original (any differences?)
- Palette RGB decode: correct or wrong?
- Recommended fixes if any discrepancies found

Read `.shared/findings.md` before starting to avoid duplicating known issues.
After completing, append your findings to `.shared/findings.md`.
