# Raizing Task: Scaffold jtraizing Core (Battle Garegga)

**From:** Claude orchestrator
**Date:** 2026-03-29
**Priority:** Medium — full hardware spec already researched

## Hardware Spec (Battle Garegga / bgaregga)

All from MAME `src/mame/toaplan/raizing.cpp` (confirmed):
- **CPU:** MC68000 @ 16 MHz (32 MHz XTAL / 2)
- **ROM:** 0x000000–0x0FFFFF (1 MB)
- **Work RAM:** 0x100000–0x10FFFF (64 KB)
- **Video:** GP9001 VDP @ 27 MHz
  - GP9001 regs: 0x300000–0x30000D
  - Palette RAM: 0x400000–0x400FFF (4KB, xBGR_555 format, COLORW=5)
  - Text VRAM: 0x500000–0x501FFF
- **I/O:** 0x21C020–0x21C035 (joystick/system/DIP inputs)
- **Sound latch:** 0x600001 (68K → Z80 mailbox)
- **Shared RAM:** 0x218000–0x21BFFF (68K ↔ Z80)
- **VBLANK:** M68K_IRQ_4 (IPL level 4)
- **Sound CPU:** Z80 @ 4 MHz + YM2151 + OKI M6295

## Reference Cores to Read First

1. `cores/toapv2/hdl/jttoapv2_game.v` — same GP9001 VDP, same architecture; primary reference
2. `cores/toapv2/hdl/jttoapv2_main.v` — 68000 + address decode pattern
3. `cores/toapv2/cfg/mem.yaml` — SDRAM config pattern to follow
4. `cores/toapv2/cfg/macros.def` — macros pattern

## Task

Create a minimal scaffold (CPU boots, no video yet):

### File 1: `cores/raizing/cfg/macros.def`
Base on toapv2 macros.def. Key settings:
- `JTFRAME_BUTTONS=2` (like toapv2, adjust if needed)
- `JTFRAME_COLORW=5` (palette is xBGR_555)
- NO_SOUND stub if jtraizing_snd.v doesn't exist yet
- Core name: `CORENAME=raizing`

Compile check: N/A (macros.def doesn't compile alone)

### File 2: `cores/raizing/cfg/mem.yaml`
Base on toapv2 mem.yaml. Needs:
- BA0: main ROM 0x000000–0x0FFFFF (1 MB = addr_width: 21)
- BA1: work RAM 0x100000–0x10FFFF (64 KB, writable, addr_width: 17)
- No video ROMs yet (stub `gfx_cs = 0`)

Write to `cores/raizing/cfg/mem.yaml`. No compile check for yaml.

### File 3: `cores/raizing/hdl/jtraizing_game.v`
Minimal top-level. Template from jttoapv2_game.v, adapted for raizing:
- Include `jtframe_game_ports.inc`
- Instantiate jtraizing_main (stub all video/sound outputs as 0 initially)
- Pixel clock, vtimer (use same settings as toapv2: 320×224)
- `assign red=0; assign green=0; assign blue=0;` (no video yet)
- `assign snd=0; assign sample=0;` (no sound yet)
- `assign dip_flip=0; assign debug_view=0;`

After writing: `verilator --lint-only` using existing jtsim infrastructure. Use:
```
cd cores/raizing/ver/game 2>/dev/null || mkdir -p cores/raizing/ver/game && cd cores/raizing/ver/game
JTROOT=/Volumes/2TB_20260220/Projects/jtcores JTFRAME=$JTROOT/modules/jtframe MODULES=$JTROOT/modules CORES=$JTROOT/cores JTBIN=$JTROOT/release PATH=$PATH:$JTFRAME/bin jtsim -lint
```
If the ver directory doesn't exist, create it and a minimal jtsim.f and game_test.v.

### File 4: `cores/raizing/hdl/jtraizing_main.v`
68000 CPU stub with correct address decode for bgaregga:
```
main_cs  = 0x000000-0x0FFFFF (A[23:20]==4'h0)
ram_cs   = 0x100000-0x10FFFF (A[23:16]==8'h10)
io_cs    = 0x21C020-0x21C035 (A[23:5]==19'hXXXXX)
gp9001_cs= 0x300000-0x30000D (A[23:4]==...)
pal_cs   = 0x400000-0x400FFF (A[23:12]==12'hXXX)
```
Use `jtframe_68kdtack_cen` for CPU clock. VBLANK IPL=4 (IPLn = ~4'b0100 when vblank).
Read jttoapv2_main.v carefully before writing — use the same DTACK/interrupt pattern.

After writing: compile check again.

## Rules
- One file at a time, compile between each
- Grep every signal name before using it
- DO NOT fabricate signal names — read the reference files
- Return: what was created, compile results, any warnings

Read `.shared/findings.md` before starting (has full hardware spec).
Update `.shared/status.md` when you begin work.
Append any new discoveries to `.shared/findings.md`.
