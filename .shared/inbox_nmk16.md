# NMK16 Task: 300-Frame Sim Analysis + BG VRAM Status

**From:** Claude orchestrator
**Date:** 2026-03-29 (updated — research pre-loaded)

## Status: Sprite format VERIFIED — sim already complete

Previous task (sprite format verification) is DONE. See findings.md.
Result: sprite attribute layout EXACTLY matches MAME nmk16spr.cpp. No changes needed.

A 300-frame sim already ran. Frames are saved in `cores/nmk16/ver/tdragon/frames/`.
You do NOT need to re-run the sim.

## Task: Analyze Existing Sim Frames + Log

### Step 1: View frames 17, 50, 100, 200, 300

Read frames from `cores/nmk16/ver/tdragon/frames/`:
- `frame_00017.jpg`
- `frame_00050.jpg`
- `frame_00100.jpg`
- `frame_00200.jpg`
- `frame_00300.jpg`

Describe each: colors, sprite shapes visible, changes between frames.

### Step 2: Check existing log for VID STATUS

Check `/tmp/nmk16_600f.log` for VID STATUS entries:
```bash
grep "VID STATUS" /tmp/nmk16_600f.log | grep -v "code=000\|scrx=000\|scry=000" | head -20
grep -c "VID STATUS" /tmp/nmk16_600f.log
```

Report: Are any VID STATUS entries showing non-zero `code`, `scrx`, or `scry` values?

### Step 3: Check BG VRAM write activity

BG VRAM is at 0x0CC000–0x0CFFFF. From the existing log, check if the CPU ever writes there:
```bash
grep "A=0CC\|A=0CD\|A=0CE\|A=0CF" /tmp/nmk16_600f.log | head -10
```

## MAME-Verified Context (no MAME research needed)

From findings.md (already confirmed):
- BG VRAM (0x0CC000–0x0CFFFF) is intentionally zero during tdragonb2 attract mode
- Red background = palette[0] = red, which the CPU writes at boot
- Sprites animate from right to left during attract mode = correct behavior
- BG tiles only populate during gameplay, not attract mode

So if BG VRAM writes are zero, that is EXPECTED — not a bug.

## What to return

Concise report:
- Frame content: what's visible at frames 17, 50, 100, 200, 300?
- VID STATUS summary: any non-zero code/scrx/scry?
- BG VRAM writes: zero (expected) or any seen?
- Overall: does the video output look correct for tdragonb2 attract mode?

Read `.shared/findings.md` before starting.
Update `.shared/status.md` when you begin.
