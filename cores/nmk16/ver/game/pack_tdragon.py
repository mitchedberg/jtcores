#!/usr/bin/env python3
"""Pack original tdragon ROMs into rom.bin for JTFRAME simulation.
NO byte swapping — JTFRAME handles byte ordering.
ROM_LOAD16_BYTE: interleave two files byte-by-byte."""

import zipfile, os, sys

zippath = os.path.join(os.path.dirname(__file__), 'tdragon.zip')
zf = zipfile.ZipFile(zippath)

def find(name):
    for n in zf.namelist():
        if n.endswith(name):
            return n
    raise FileNotFoundError(f"{name} not in zip")

def interleave_bytes(even_data, odd_data):
    """ROM_LOAD16_BYTE: even bytes at offset 0, odd bytes at offset 1"""
    out = bytearray(len(even_data) + len(odd_data))
    for i in range(len(even_data)):
        out[2*i]   = even_data[i]   # even byte
        out[2*i+1] = odd_data[i]    # odd byte
    return bytes(out)

rom = bytearray()

# BA0: 68000 program (ROM_LOAD16_BYTE)
# 91070_68k.7 at even, 91070_68k.8 at odd
even = zf.read(find("91070_68k.7"))  # 128 KB, even bytes
odd  = zf.read(find("91070_68k.8"))  # 128 KB, odd bytes
prog = interleave_bytes(even, odd)   # 256 KB interleaved
print(f"BA0 program: {len(prog)} bytes ({len(even)} + {len(odd)} interleaved)")
rom.extend(prog)

# Pad to BA1_START (0x40000 = 256 KB) — already exact size
while len(rom) < 0x40000:
    rom.extend(b'\xFF')

# BA1: Sound ROMs
# NMK004 data: 91070.1 (64 KB)
snd = zf.read(find('91070.1'))
print(f"BA1 sound: {len(snd)} bytes")
rom.extend(snd)

# OKI samples: 91070.3 (512 KB) + 91070.2 (512 KB)
oki1 = zf.read(find('91070.3'))
oki2 = zf.read(find('91070.2'))
rom.extend(oki1)
rom.extend(oki2)
print(f"BA1 OKI: {len(oki1)} + {len(oki2)} bytes")

# Pad to BA2_START (0x60000)
# Actually BA2 = chars + tiles + sprites
# BA1_START=0x40000, so BA1 section = sound ROMs starting at 0x40000
# BA2_START=0x60000, so pad BA1 to 0x20000 (128 KB)
while len(rom) < 0x60000:
    rom.extend(b'\xFF')

# BA2: GFX ROMs
# Characters: 91070.6 (128 KB)
chars = zf.read(find('91070.6'))
print(f"BA2 chars: {len(chars)} bytes")
rom.extend(chars)

# Tiles: 91070.5 (1 MB)
tiles = zf.read(find('91070.5'))
print(f"BA2 tiles: {len(tiles)} bytes")
rom.extend(tiles)

# Sprites: 91070.4 (1 MB)
sprites = zf.read(find('91070.4'))
print(f"BA2 sprites: {len(sprites)} bytes")
rom.extend(sprites)

outpath = os.path.join(os.path.dirname(__file__), 'rom.bin')
with open(outpath, 'wb') as f:
    f.write(rom)

print(f"\nTotal: {len(rom)} bytes ({len(rom)/1024/1024:.1f} MB)")
print(f"Written to {outpath}")

# Verify vectors
print(f"\nReset SSP: 0x{rom[0]:02X}{rom[1]:02X}{rom[2]:02X}{rom[3]:02X}")
print(f"Reset PC:  0x{rom[4]:02X}{rom[5]:02X}{rom[6]:02X}{rom[7]:02X}")
