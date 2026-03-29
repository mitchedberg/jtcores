# Caliber 50 — SETA 1 Hardware Profile

*Generated from MAME seta.cpp driver, Arcade Database, and ROM analysis*
*Date: 2026-03-28*

## Game Overview
- **Title:** Caliber 50 (Cal.50)
- **Developer:** SETA / Romstar Inc.
- **Year:** 1989
- **Genre:** Multi-directional scrolling shooter (Vietnam War theme)
- **Players:** 2 concurrent (Joystick 8-way + Dial rotary input, 2 buttons)
- **Cabinet:** Vertical (270° rotation)

## Display
| Parameter | Value |
|-----------|-------|
| **Resolution** | 384 × 240 pixels |
| **Aspect Ratio** | 16:10 (letterboxed 4:3 arcade) |
| **Refresh Rate** | 57.42 Hz (15 kHz CRT) |
| **Pixel Clock** | ~7.16 MHz (estimated from 384×240@57.42Hz) |
| **Color Depth** | 4096 colors (12-bit palette) from RGB 444 |

## CPUs
| Type | Tag | Clock | ROM | RAM | Notes |
|------|-----|-------|-----|-----|-------|
| **Motorola MC68000** | maincpu | 8.0 MHz | See ROM section | 64 KB | Primary game logic |
| **WDC W65C02** | audiocpu | 2.0 MHz | See ROM section | 2 KB | Sound CPU (sub) |

## Sound
| Type | Tag | Clock | Status | Notes |
|------|-----|-------|--------|-------|
| **SETA X1-010** | x1snd | 16.0 MHz | HAVE | 16-channel wavetable + 8-bit sample playback (up to 128 KB ADPCM) |
| **Mono Output** | — | — | HAVE | Single audio channel to amplifier |

**X1-010 Details:**
- 16 independent wavetable channels
- 32 waveform + envelope slots in memory
- Sample rate: 31.25 kHz (16 MHz / 512)
- ADPCM sample storage: up to 128 KB
- Address space: typically 0x100000–0x13FFFF (256 KB window on 68000)

## Memory Map — MC68000 (8.0 MHz)
| Start | End | Size | Access | Function |
|-------|-----|------|--------|----------|
| 0x000000 | 0x02FFFF | 256 KB | R | Program ROM (68000) |
| 0x040000 | 0x04FFFF | 64 KB | RW | Main Work RAM |
| 0x050000 | 0x050001 | 2 B | W | Sound CPU control (trigger) |
| 0x060000 | 0x060001 | 2 B | W | Watchdog reset |
| 0x070000 | 0x0701FF | 512 B | RW | I/O registers (joystick, coin, controls) |
| 0x080000 | 0x0DFFFF | 384 KB | RW | Sprite/background VRAM (dynamic) |
| 0x0E0000 | 0x0E07FF | 2 KB | RW | Palette RAM (512 × 16-bit, 4096 colors) |
| 0x100000 | 0x13FFFF | 256 KB | RW | X1-010 sound chip address space |

**Notes:**
- ROM window 0x000000–0x02FFFF = 256 KB max (actual size smaller, aliased)
- Work RAM mirrored in upper range if needed
- VRAM layout: sprite list, background tiles, scroll registers (per SETA 1 standard)
- Palette format: xRRRRGGGGBBBBxx (12-bit RGB, 16-bit entry, 4096 colors)

## ROM Layout (68000)
| File | Location | Size | Purpose | Notes |
|------|----------|------|---------|-------|
| uh-001-005.17e | ROM 1 | 256 KB | Program ROM bank 0 | 68000 code |
| uh-001-006.2m | ROM 2 | 512 KB | Sprite GFX bank 0 | Sprite sheet, 4-bit indexed |
| uh-001-007.4m | ROM 3 | 512 KB | Sprite GFX bank 1 | Sprite sheet, 4-bit indexed |
| uh-001-008.5m | ROM 4 | 512 KB | Background GFX bank 0 | Tilemap, 4-bit indexed |
| uh-001-009.6m | ROM 5 | 512 KB | Background GFX bank 1 | Tilemap, 4-bit indexed |
| uh-001-010.8m | ROM 6 | 512 KB | Background GFX bank 2 | Tilemap, 4-bit indexed |
| uh-001-011.9m | ROM 7 | 512 KB | X1-010 sample bank 0 | ADPCM wavetables |
| uh-001-012.11m | ROM 8 | 512 KB | X1-010 sample bank 1 | ADPCM wavetables |
| uh-001-013.12m | ROM 9 | 512 KB | X1-010 sample bank 2 | ADPCM wavetables |
| uh-002-001.3b | ROM 10 | 256 KB | Program ROM bank 1 (alt) | 68000 code alternate |
| uh-002-004.11b | ROM 11 | 256 KB | Program ROM bank 2 (alt) | 68000 code alternate |
| uh_001_002.7b | ROM 12 | 64 KB | Z80 / 65C02 code | Audio CPU |
| uh_001_003.9b | ROM 13 | 64 KB | Z80 / 65C02 code alt | Audio CPU alternate |

**Total ROM:** ~5.1 MB (typical for SETA 1)

## Graphics
| Component | Details |
|-----------|---------|
| **Sprite Engine** | X1-001A / X1-002A (custom SETA chips) |
| **Tilemap Engine** | X1-011 / X1-012 (custom SETA chips) |
| **Sprite Format** | 16×16 tiles, 4-bit indexed color (16 colors per sprite) |
| **Tilemap Format** | 16×16 tiles, 4-bit indexed color |
| **Max Sprites** | Hardware-dependent, SETA 1 typically 128–384 on-screen |
| **Layers** | Background (scrolling) + Sprites + Text overlay |
| **Scroll** | Multi-directional (horizontal + vertical per gameplay) |

## Interrupts
| IRQ | Level | Trigger | Notes |
|-----|-------|---------|-------|
| **VBL** | 1 | Vertical blank | Frame timing, game loop |
| **(Optional)** | 3 | X1-010 sound | If X1-010 IRQ enabled (typically polled, not IRQ) |

**Typical operation:** VBL-only, running at 57.42 Hz.

## Input
| Port | Address | Function | Input Type |
|------|---------|----------|-----------|
| **P1 Joystick** | 0x070000+ | 8-way digital | Digital (up/down/left/right) |
| **P1 Dial/Rotary** | 0x070002+ | Aim rotation | Analog dial (0–255 or similar) |
| **P1 Button A** | 0x070004+ | Fire | Digital |
| **P1 Button B** | 0x070006+ | Secondary fire | Digital |
| **P2** | Mirrored | Same as P1 | 2P simultaneous |
| **Coin/Credits** | 0x070008+ | Coin detect, start | Digital |

## Clocking
| Signal | Frequency | Derivation | Notes |
|--------|-----------|-----------|-------|
| **Master Clock** | ~28.636 MHz (typical) | Unknown source | Crystal or oscillator |
| **68000 Clock** | 8.0 MHz | Master / 3.58 (estimated) | Synchronous to master |
| **65C02 Clock** | 2.0 MHz | Master / 14.32 (estimated) | Sub-audio CPU |
| **X1-010 Clock** | 16.0 MHz | Master / 1.79 (estimated) | Wavetable sample generation |
| **Pixel Clock** | ~7.16 MHz | Derived from master | 384 × 240 @ 57.42 Hz |

## NVRAM / Backup RAM
| Address | Size | Purpose | Notes |
|---------|------|---------|-------|
| **0x060000** | 2 B | Watchdog timer register | Hardware heartbeat |
| **On-cartridge NVRAM** | Variable | High scores, game settings | SETA 1 typically uses battery-backed RAM or EEPROM |

## Chip Status Summary
- **HAVE (FPGA cores exist):** MC68000 (fx68k), X1-010, X1-001/X1-002 (sprites), X1-011/X1-012 (tilemap)
- **NEED (must build):** X1-010 sound emulation (if not available), full SETA 1 sprite + tilemap controllers
- **INFEASIBLE:** None identified

## Historical Notes
- Caliber 50 was ported to Sega Genesis in 1991 (with reduced graphics)
- PCB revision: "Ver. 1.01" is known, likely there are earlier revisions
- Known quirk: Some SETA 1 games have non-standard timing or palette handling; Caliber 50 reported as stable

## References
1. MAME `src/mame/seta/seta.cpp` — Primary hardware emulation reference
2. MAME `src/devices/sound/x1_010.cpp` — X1-010 sound chip emulation
3. Arcade Database (adb.arcadeitalia.net) — Game metadata + specs
4. System 16 (system16.com) — SETA hardware comprehensive reference
5. VGMRips X1-010 documentation — Sound chip deep dive

