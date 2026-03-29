# NMK16 Task: Sim Diagnostics + Video Quality Check

**From:** Claude orchestrator
**Date:** 2026-03-29 (updated)

## Status: Sprite format VERIFIED — new task below

Previous task (sprite format verification) is DONE. See findings.md.
Result: our sprite attribute layout EXACTLY matches MAME nmk16spr.cpp. No changes needed.
Also confirmed: sprite transparency = pen 15. Correct.

## New Task: NMK16 300-Frame Sim with Enhanced Video Diagnostics

The 600-frame sim produced visible video at frame 17+. Now we need to verify video quality.

### Step 1: Run a 100-frame sim with enhanced diagnostics

From `cores/nmk16/ver/tdragon/`:
```bash
JTROOT=/Volumes/2TB_20260220/Projects/jtcores JTFRAME=$JTROOT/modules/jtframe MODULES=$JTROOT/modules CORES=$JTROOT/cores JTBIN=$JTROOT/release PATH=$PATH:$JTFRAME/bin jtsim -frame 100 2>&1 | tee /tmp/nmk16_100f_v2.log
```

### Step 2: Analyze the output

From the log, extract:
1. All `VID STATUS` lines — are any showing non-zero `code`, `scrx`, or `scry`?
2. Are there any `bg=1` or `pal=1` entries in the `NMK16: A=...` periodic prints?
3. How many frames were saved? (check `frames/` directory)

### Step 3: View frame content

Read frames 17, 18, 20, 50, 100 from `cores/nmk16/ver/tdragon/frames/` and describe what you see:
- Colors present?
- Any recognizable patterns (text, sprites, solid areas)?
- Changes between frames?

### Step 4: Check BG VRAM write issue

The CPU appears to never write to BG VRAM (0x0CC000-0x0CFFFF) in 600 frames.
Verify this by searching the sim log for any CPU access with `A` in range 0x0CC000-0x0CFFFF.
Also check: does MAME's tdragonb2 ever write to 0x0CC000 during the attract mode?
  Hint: look at MAME's debugger memory map for tdragonb2 (`tdragonb2_map`) — is BG VRAM
  used during attract mode or only during gameplay?

### What to return

Concise report:
- VID STATUS summary (non-zero values seen?)
- Frame count and description of visual content
- BG VRAM write analysis: does tdragonb2 use BG VRAM during attract mode?
- Any unexpected findings

Read `.shared/findings.md` before starting.
Update `.shared/status.md` when you begin.
Append any new findings to `.shared/findings.md`.
