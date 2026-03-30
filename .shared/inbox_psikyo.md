# Psikyo Task: Sim-Test BG Tile Rendering (Gunbird)

**From:** Claude orchestrator
**Date:** 2026-03-29 (updated — video.v exists, now sim it)
**Priority:** High

## Status

`jtpsikyo_video.v` was created and lint-checked clean. It is already wired into
`jtpsikyo_game.v` and listed in `files.yaml`.

**Your task: run a sim and verify BG tiles actually render.**

## Step 1: Check what ROM files exist

```bash
ls cores/psikyo/ver/gunbird/
ls cores/psikyo/ver/game/
```

If `rom.bin` and `sdram_bank*.bin` exist → run with real ROMs.
If not → run with `-skipROM` for a compile-only check.

## Step 2: Run sim

```bash
cd cores/psikyo/ver/gunbird
export JTROOT=/Volumes/2TB_20260220/Projects/jtcores
export JTFRAME=$JTROOT/modules/jtframe
export MODULES=$JTROOT/modules
export CORES=$JTROOT/cores
export JTBIN=$JTROOT/release
export PATH=$PATH:$JTFRAME/bin

# With real ROMs (preferred):
jtsim -frame 60 2>&1 | tee /tmp/psikyo_sim.log

# If no ROMs:
jtsim -frame 30 -skipROM 2>&1 | tee /tmp/psikyo_sim.log
```

After running, always link fx68k microcode (required for 68000 cores):
```bash
ln -sf $JTROOT/modules/fx68k/hdl/*.mem .
```
Then re-run if you needed microcode.

## Step 3: Check frames

```bash
ls cores/psikyo/ver/gunbird/frames/
```

View frame_00001.jpg, frame_00010.jpg, frame_00030.jpg (or whichever exist).
Describe what you see: colors? tile patterns? sprites? blank?

## Step 4: Check log for CPU activity

```bash
grep -i "cpu\|PAGE\|A=\|pc=" /tmp/psikyo_sim.log | head -20
grep -i "error\|halt\|bus error\|exception" /tmp/psikyo_sim.log | head -10
```

## What to return

- Did sim compile clean? (Y/N, any errors)
- How many frames saved?
- Frame content description (colors, patterns, anything visible?)
- Any CPU errors or halts in log?
- Any unexpected lint warnings from the new video module?

## Known context (from findings.md)

- Psikyo CPU already boots (verified in prior session — CPU executes, sound active)
- BG VRAM at 0x800000–0x803FFF, written by CPU at boot during attract mode
- Palette at 0x600000–0x601FFF, xRGB_555 format
- COLORW=5 (5-bit per channel output)
- GFX ROM for BG tiles should be in SDRAM bank (check `cores/psikyo/cfg/mem.yaml`)

Read `.shared/findings.md` before starting.
Update `.shared/status.md` when you begin.
Append findings to `.shared/findings.md`.
