# Raizing Task: Scaffold + CPU Boot Verification

**From:** Claude orchestrator
**Date:** 2026-03-29
**Priority:** Medium

## Context

The `cores/raizing/` directory exists with a README but no HDL. Raizing games (Battle Garegga,
Sorcer Striker, etc.) use a 68000 + custom MCU + GP9001 VDP — similar hardware to Toaplan V2
but with Raizing-specific chips. This task is to scaffold the core and get the CPU booting.

## Task

1. **Read the README first:** `cores/raizing/README.md`
2. **Read a reference scaffold:** Read `cores/toapv2/hdl/jttoapv2_game.v` and `cores/toapv2/hdl/jttoapv2_main.v`
   as the primary reference (same GP9001 VDP, similar architecture).
3. **Research MAME source:** The Raizing 68000 games are in `src/mame/raizing/` or `src/mame/toaplan/`.
   Find the CPU address map for `bgaregga` (Battle Garegga) — extract:
   - ROM size and address range
   - Work RAM address range
   - I/O port addresses
   - Interrupt source (VBLANK level)
4. **Check ROM files:** Look at `cores/raizing/ver/` for any existing simulation artifacts.
   Check if ROM packing config exists at `cores/raizing/cfg/`.
5. **DO NOT scaffold yet** if any of the following are missing:
   - MAME address map confirmed
   - ROM region sizes confirmed
   - Reference scaffold fully read

**If all research is complete:** Create a minimal scaffold following the Toaplan V2 pattern:
- `cores/raizing/hdl/jtraizing_game.v` (top-level, `include "jtframe_game_ports.inc"`)
- `cores/raizing/hdl/jtraizing_main.v` (68000 CPU + address decode + DTACK)
- `cores/raizing/cfg/macros.def` (based on toapv2 macros)
- `cores/raizing/cfg/mem.yaml` (ROM + Work RAM, no video ROMs yet)

After writing each file, run `verilator --lint-only` before proceeding to the next.

## Constraints
- One file at a time, compile between each
- Grep every signal name before using it
- Return: what was created, compile results, any issues found

Read `.shared/findings.md` before starting.
Update `.shared/status.md` when you begin.
