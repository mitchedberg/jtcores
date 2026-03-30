# Agent Status Board

| Agent | Core | Task | Updated |
|-------|------|------|---------|
| Claude (orchestrator) | All | Taitob Quartus timeout fixed (120min), build re-triggered. Psikyo video.v done+lint. Inboxes pre-loaded with research. | 2026-03-29 23:50 |
| Claude subagent | Psikyo | DONE: jtpsikyo_video.v created + wired into game.v, lint clean. Next: sim test in inbox_psikyo.md | 2026-03-29 |
| Claude (NMK16-video) | NMK16 | DONE: FG renderer, sprite LVBL fix, FG bandwidth fix. 300 frames visible (sprites animating on red bg). | 2026-03-29 |
| Codex (nmk16-sprites) | NMK16 | DONE: sprite renderer, BA2 spr bus, lint clean | 2026-03-29 14:45 |
| Codex (nmk16-fg) | NMK16 | DONE: FG BA2 bus, FG VRAM, 3-way palette mux, lint clean | 2026-03-29 15:25 |
| Subagent (taitob-overlay) | Taito B | DONE: TX tile 0 fix + COLORW=5 — full Tetris gameplay renders at frame ~1100 | 2026-03-29 13:10 |
| Codex (taitob-quartus) | Taito B | FAILED x2: 60-min timeout. Workflow bumped to 120min, build re-triggered. | 2026-03-29 23:50 |

## Inboxes ready for Codex (pick one):
- `inbox_psikyo.md` — **HIGH**: sim-test jtpsikyo_video.v, check BG tile frames
- `inbox_toapv2.md` — **HIGH**: implement GP9001 sprite VRAM + renderer FSM (full spec pre-loaded)
- `inbox_raizing.md` — **MEDIUM**: lint + address decode verify + 30-frame sim for Raizing scaffold
- `inbox_nmk16.md` — **LOW**: analyze existing 300 frames (quick task)
