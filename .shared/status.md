# Agent Status Board

| Agent | Core | Task | Updated |
|-------|------|------|---------|
| Claude (orchestrator) | All | Taitob Quartus build in progress (run 23720685357). NMK16 600-frame sim done — video visible at frame 17+. Codex inboxes written. | 2026-03-29 22:35 |
| Claude (NMK16-video) | NMK16 | DONE: FG renderer, sprite LVBL fix, FG bandwidth fix. Video visible in sim (frame 17+). | 2026-03-29 |
| Codex (nmk16-sprites) | NMK16 | DONE: sprite renderer, BA2 spr bus, lint clean | 2026-03-29 14:45 |
| Codex (nmk16-fg) | NMK16 | DONE: FG BA2 bus, FG VRAM, 3-way palette mux, lint clean | 2026-03-29 15:25 |
| Subagent (taitob-overlay) | Taito B | DONE: TX tile 0 fix + COLORW=5 — full Tetris gameplay renders at frame ~1100 | 2026-03-29 13:10 |
| Codex (taitob-quartus) | Taito B | IN PROGRESS: run 23720685357 — joystick concat fix applied, build retried | 2026-03-29 22:35 |

## Next tasks available (in .shared/inbox_*.md):
- inbox_nmk16.md — verify sprite attrs + scroll regs vs MAME tdragonb2
- inbox_toapv2.md — research GP9001 sprite format
- inbox_raizing.md — scaffold jtraizing core (Battle Garegga)
