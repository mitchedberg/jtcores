#!/usr/bin/env python3
"""Pack tdragonb2 (bootleg, NO NMK004 MCU needed) ROMs for JTFRAME.
JTFRAME downloader byte-swaps 16-bit words, so we pre-swap."""
import os

basedir = os.path.dirname(__file__)
rom = bytearray()

# BA0: 68000 program - a3 (even bytes) + a4 (odd bytes) interleaved
a3 = open(os.path.join(basedir, 'tdragonb2/a3'), 'rb').read()
a4 = open(os.path.join(basedir, 'tdragonb2/a4'), 'rb').read()
prog = bytearray()
for i in range(len(a3)):
    prog.append(a3[i])  # even
    prog.append(a4[i])  # odd
print(f"BA0 program: {len(prog)} bytes (a3+a4 interleaved)")
rom.extend(prog)

# Pad to BA1_START (0x40000)
while len(rom) < 0x40000:
    rom.extend(b'\xFF')

# BA1: tdragonb2 has NO sound ROMs (bootleg removed sound CPU)
# Pad to BA2_START (0x60000)
while len(rom) < 0x60000:
    rom.extend(b'\xFF')

# BA2: GFX - shinea2a2-01 (512KB sprites/tiles)
# tdragonb2 shares char/tile/sprite ROMs from parent tdragon set
# But the bootleg ZIP only has shinea2a2-01
# We also need the parent's tile/char ROMs
gfx = open(os.path.join(basedir, 'tdragonb2/shinea2a2-01'), 'rb').read()
print(f"BA2 GFX (shinea2a2-01): {len(gfx)} bytes")
rom.extend(gfx)

# Also add parent's GFX ROMs if available
for name in ['91070.6', '91070.5', '91070.4']:
    fpath = os.path.join(basedir, name)
    if os.path.exists(fpath):
        data = open(fpath, 'rb').read()
        print(f"BA2 GFX ({name}): {len(data)} bytes")
        rom.extend(data)

outpath = os.path.join(basedir, 'rom.bin')
with open(outpath, 'wb') as f:
    f.write(rom)

print(f"\nTotal: {len(rom)} bytes ({len(rom)/1024/1024:.1f} MB)")
# After JTFRAME download byte-swap:
ssp = (rom[1]<<24)|(rom[0]<<16)|(rom[3]<<8)|rom[2]
pc  = (rom[5]<<24)|(rom[4]<<16)|(rom[7]<<8)|rom[6]
print(f"After download swap: SSP=0x{ssp:08X} PC=0x{pc:08X}")
