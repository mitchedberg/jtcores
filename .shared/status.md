# Agent Status Board

| Agent | Core | Task | Updated |
|-------|------|------|---------|
| Claude (orchestrator) | All | Coordinating, waiting on sim/lint results | 2026-03-29 |
| Claude (NMK16-video) | NMK16 | First BG tiles visible! CPU boots, pixel format fixed, ROM repacked | 2026-03-29 12:45 |
| Codex (nmk16-sprites) | NMK16 | DONE: fixed tdragonb2 pack order, added BA2 `spr` bus, wired sprite renderer, `jtsim -lint` clean | 2026-03-29 14:45 |
| Codex (nmk16-fg) | NMK16 | DONE: added BA2 `fg` bus, FG VRAM, inline FG pixel path, 3-way palette mux, and `jtsim -lint` clean for tdragonb2 | 2026-03-29 15:25 |
| Subagent (taitob-overlay) | Taito B | DONE: TX tile 0 fix + COLORW=5 — full Tetris gameplay + sprites render at frame ~1100. Lint clean. | 2026-03-29 13:10 |
| Codex (gp9001-sim) | Toaplan V2 | `truxton2` sim folder exists; exact `-setname` blocked by stale `doc/mame.xml`, `-skipROM -frame 10` compiles/runs | 2026-03-29 |
| Codex (gp9001-palette) | Toaplan V2 | Fixing `jttoapv2_video.v` palette RGB decode and tile palette-bank address, then linting | 2026-03-29 13:00 |
