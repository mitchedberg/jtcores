#!/usr/bin/env python3
"""Pack tdragonb2 (bootleg, NO NMK004 MCU needed) ROMs for JTFRAME.

SDRAM layout:
  BA0 (0x000000): 68000 program (a3+a4 interleaved, 256KB), padded to 0x40000
  BA1 (0x040000): OKI sound ROM (shinea2a2-01, 512KB)
  BA2 (0x0C0000): GFX tiles - 91070.4 BG (1MB) + 91070.5 sprites (1MB) + 91070.6 text (128KB)
  BA3 (0x2E0000): RAM only, no ROM data
"""
import os

basedir = os.path.dirname(__file__)
romdir  = os.path.join(basedir, 'tdragonb2')
rom = bytearray()

# BA0: 68000 program - a3 (even bytes) + a4 (odd bytes) interleaved
a3 = open(os.path.join(romdir, 'a3'), 'rb').read()
a4 = open(os.path.join(romdir, 'a4'), 'rb').read()
prog = bytearray()
for i in range(len(a3)):
    prog.append(a3[i])  # even byte
    prog.append(a4[i])  # odd byte
print(f"BA0 program: {len(prog)} bytes (a3+a4 interleaved)")
rom.extend(prog)

# Pad to BA1_START (0x40000)
BA1_START = 0x40000
while len(rom) < BA1_START:
    rom.extend(b'\xFF')

# BA1: OKI sound ROM (shinea2a2-01 is the sound ROM, not a GFX ROM)
oki = open(os.path.join(romdir, 'shinea2a2-01'), 'rb').read()
print(f"BA1 OKI sound (shinea2a2-01): {len(oki)} bytes = {len(oki)//1024}KB")
rom.extend(oki)

# Pad to BA2_START (BA1_START + OKI size = 0x40000 + 0x80000 = 0xC0000)
BA2_START = BA1_START + len(oki)
assert BA2_START == 0xC0000, f"BA2_START mismatch: 0x{BA2_START:X}"
while len(rom) < BA2_START:
    rom.extend(b'\xFF')

# BA2: GFX tiles
# 91070.4 = BG tiles (16x16), 1MB
bg = open(os.path.join(romdir, '91070.4'), 'rb').read()
print(f"BA2 BG tiles (91070.4): {len(bg)} bytes = {len(bg)//1024}KB")
rom.extend(bg)

# 91070.5 = sprites (16x16), 1MB; MAME uses ROM_LOAD16_WORD_SWAP.
# JTFRAME downloader also byte-swaps 16-bit words, so the two swaps cancel.
# Load raw — rendering will handle any remaining byte-order differences.
spr = open(os.path.join(romdir, '91070.5'), 'rb').read()
print(f"BA2 sprites  (91070.5): {len(spr)} bytes = {len(spr)//1024}KB")
rom.extend(spr)

# 91070.6 = text/fg tiles (8x8), 128KB
txt = open(os.path.join(romdir, '91070.6'), 'rb').read()
print(f"BA2 text     (91070.6): {len(txt)} bytes = {len(txt)//1024}KB")
rom.extend(txt)

BA3_START = BA2_START + len(bg) + len(spr) + len(txt)
print(f"\nBA3_START would be: 0x{BA3_START:X}")

outpath = os.path.join(basedir, 'rom.bin')
with open(outpath, 'wb') as f:
    f.write(rom)

print(f"\nTotal: {len(rom)} bytes ({len(rom)/1024/1024:.1f} MB)")
# After JTFRAME download byte-swap (16-bit words are swapped by downloader):
ssp = (rom[1]<<24)|(rom[0]<<16)|(rom[3]<<8)|rom[2]
pc  = (rom[5]<<24)|(rom[4]<<16)|(rom[7]<<8)|rom[6]
print(f"After download swap: SSP=0x{ssp:08X} PC=0x{pc:08X}")
