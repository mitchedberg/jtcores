# JTCORES Project Rules — For All AI Agents (Claude, Codex, etc.)

Read this file before doing any work. These rules are mandatory.

## Rule 1: One Change, One Verification
Never make two changes before verifying the first one works. After writing any .v file, run `verilator --lint-only` or `jtsim` to confirm it compiles. Do not write the next file until the current one passes.

## Rule 2: Reference First
Before writing or modifying any Verilog, read how a working JTFRAME core does it.
- Primary reference: `cores/psikyo/hdl/` (Gunbird — most complete)
- Secondary: `cores/bubl/hdl/` (Bubble Bobble — simplest)
- MAME source is ground truth for hardware behavior

## Rule 3: Verify Every Signal Name
Before writing code that references signals from another module, grep for each signal name to confirm it exists and get the exact spelling. Do not guess. `grep -n "signal_name" target_file.v` before using it.

## Rule 4: No Speculation
Every change must have a traceable rationale — a MAME source line, a reference core pattern, or a Verilator error message. "Maybe this will fix it" is not a rationale.

## Rule 5: Known Foot-Guns
- `addr_width` in mem.yaml = BYTE address bits. Generator computes AW = addr_width - 1.
- Undersized BRAMs cause silent boot failure (arcade ROMs run hardware self-tests).
- JTFRAME BRAM port 1 defaults to main_addr — must wire explicitly for non-SDRAM BRAMs.
- JTFRAME tilt/service/cab_1p are active-LOW (1 = not asserted).
- ROM packing: JTFRAME downloader handles byte order. Manual packing must NOT byte-swap.
- After jtsim, run `ln -sf $JTROOT/modules/fx68k/hdl/*.mem .` (microcode symlinks).
- Need 100+ sim frames to see full 68000 boot sequence.

## Project Context
- Repository: Fork of jotego/jtcores (JTFRAME-based MiSTer FPGA arcade cores)
- 49 arcade cores scaffolded, 8 with full CPU boot confirmed
- Active video rendering work on: NMK16 (Thunder Dragon), Taito B (Tetris), Psikyo (Gunbird)
- Framework: JTFRAME provides CPU wrappers, SDRAM, MiSTer sys integration
- All work on branch `psikyo-gunbird`

## Agent Communication
Multiple agents work in this repo. Check `.shared/` at session start:
- `.shared/inbox_<corename>.md` — messages for you
- `.shared/findings.md` — read before debugging, append when you discover something
- `.shared/status.md` — write your current status so others know what you're working on

## Pending Tasks (pick one up if you have no inbox)
- `.shared/inbox_nmk16.md` — NMK16: verify sprite attribute layout + scroll register vs MAME
- `.shared/inbox_toapv2.md` — Toaplan V2: research GP9001 sprite format for implementation
- `.shared/inbox_raizing.md` — Raizing: scaffold jtraizing core + CPU boot (battle garegga)

## Key Paths
- `cores/*/hdl/` — per-core HDL modules
- `cores/*/cfg/` — per-core JTFRAME config (mem.yaml, macros.def, files.yaml)
- `cores/*/ver/*/` — simulation directories
- `modules/jtframe/` — framework (DO NOT MODIFY)
- `doc/pipeline_reference/` — research docs from previous pipeline work
