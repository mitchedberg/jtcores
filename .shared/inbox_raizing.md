# Raizing Task: Verify Scaffold + Run Sim

**From:** Claude orchestrator
**Date:** 2026-03-29
**Updated:** Scaffold already exists from factory session

## Current State

The raizing scaffold already exists:
- `cores/raizing/hdl/jtraizing_game.v` (102 lines)
- `cores/raizing/hdl/jtraizing_main.v` (88 lines) — 68000 CPU + address decode
- `cores/raizing/hdl/jtraizing_snd.v` (67 lines)
- `cores/raizing/hdl/jtraizing_video.v` (22 lines — STUB, outputs 0)
- `cores/raizing/ver/bgaregga/` and `cores/raizing/ver/game/` exist

## Task 1: Lint Check

Verify the scaffold compiles clean:
```bash
cd cores/raizing/ver/bgaregga   # or ver/game
JTROOT=/Volumes/2TB_20260220/Projects/jtcores JTFRAME=$JTROOT/modules/jtframe MODULES=$JTROOT/modules CORES=$JTROOT/cores JTBIN=$JTROOT/release PATH=$PATH:$JTFRAME/bin jtsim -lint
```

Report any lint errors or warnings.

## Task 2: Verify Address Decode Against MAME Spec

Read `cores/raizing/hdl/jtraizing_main.v`. The MAME-verified spec (from `.shared/findings.md`) says:
- ROM: 0x000000-0x0FFFFF (A[23:20]==0)
- RAM: 0x100000-0x10FFFF (A[23:16]==0x10)
- I/O: 0x21C020-0x21C035
- GP9001 regs: 0x300000-0x30000D
- Palette: 0x400000-0x400FFF
- Text VRAM: 0x500000-0x501FFF
- Sound latch: 0x600001
- VBLANK: IPL level 4

Check each decode in main.v against this spec. Report any discrepancies.

## Task 3: If Lint Passes, Run a 30-Frame Sim

```bash
cd cores/raizing/ver/bgaregga
JTROOT=... jtsim -frame 30 -skipROM
```

If ROM files exist (check `cores/raizing/ver/bgaregga/` for `rom.bin`, `sdram_bank*.bin`), use them.
If not, run with `-skipROM` to get at least a compile check.

Report: lint result, address decode verification, sim result (CPU PAGE trace if available).

## What to return
- Lint: pass/fail + warnings
- Address decode: correct or discrepancies (table)
- Sim frames: how many saved, any CPU activity visible
- Recommended next steps

Read `.shared/findings.md` (Raizing/Battle Garegga section) before starting.
Update `.shared/status.md` when you begin.
