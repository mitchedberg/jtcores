#!/usr/bin/env python3
"""
ROM packer for NMK16 Thunder Dragon (tdragonb2 variant)
Combines program ROM, OKI sample ROM, and graphics ROM into rom.bin

JTFRAME memory layout (from macros.def):
  BA0 (Program): 0x000000
  BA1 (OKI):     0x040000
  BA2 (GFX):     0x060000
  BA3:           0x2E0000
"""

import os
import sys
from pathlib import Path

def read_file(path):
    """Read a binary file."""
    with open(path, 'rb') as f:
        return f.read()

def write_file(path, data):
    """Write binary data to a file."""
    with open(path, 'wb') as f:
        f.write(data)

def interleave_program_roms(low_file, high_file):
    """
    Interleave two 128KB program ROM files (even/odd bytes).

    tdragonb2 uses:
      a3: even bytes (or low byte)
      a4: odd bytes (or high byte)

    Interleaving produces a 256KB ROM with both bytes per address.
    """
    low_data = read_file(low_file)
    high_data = read_file(high_file)

    if len(low_data) != len(high_data):
        print(f"ERROR: ROM file sizes don't match. {low_file}={len(low_data)}, {high_file}={len(high_data)}")
        sys.exit(1)

    # Interleave byte-by-byte: each pair of bytes forms a 16-bit word
    interleaved = bytearray()
    for i in range(len(low_data)):
        interleaved.append(low_data[i])
        interleaved.append(high_data[i])

    return bytes(interleaved)

def pad_section(data, target_size):
    """Pad data with zeros to reach target size."""
    if len(data) > target_size:
        print(f"ERROR: Data size {len(data)} exceeds target {target_size}")
        sys.exit(1)
    return data + b'\x00' * (target_size - len(data))

def main():
    script_dir = Path(__file__).parent
    os.chdir(script_dir)

    # Define memory layout (from macros.def)
    BA0_START = 0x000000
    BA1_START = 0x040000
    BA2_START = 0x060000

    # BA0 (Program): 0x000000 - 0x03FFFF (256KB)
    program_size = BA1_START - BA0_START

    # BA1 (OKI): 0x040000 - 0x05FFFF (128KB)
    oki_size = BA2_START - BA1_START

    # BA2 (GFX): 0x060000 onwards (up to BA3_START at 0x2E0000)
    gfx_size = 0x2E0000 - BA2_START  # 2.625 MB

    print(f"Memory layout:")
    print(f"  BA0 (Program): 0x{BA0_START:06X} - 0x{BA1_START-1:06X} ({program_size} bytes)")
    print(f"  BA1 (OKI):     0x{BA1_START:06X} - 0x{BA2_START-1:06X} ({oki_size} bytes)")
    print(f"  BA2 (GFX):     0x{BA2_START:06X} - 0x{BA2_START+gfx_size-1:06X} ({gfx_size} bytes)")
    print()

    # Verify files exist
    rom_dir = Path('tdragonb2')
    program_low = rom_dir / 'a3'
    program_high = rom_dir / 'a4'
    gfx = rom_dir / 'shinea2a2-01'

    if not program_low.exists():
        print(f"ERROR: {program_low} not found")
        sys.exit(1)
    if not program_high.exists():
        print(f"ERROR: {program_high} not found")
        sys.exit(1)
    if not gfx.exists():
        print(f"ERROR: {gfx} not found")
        sys.exit(1)

    # Build rom.bin sections
    rom_data = bytearray()

    # BA0: Interleave program ROMs
    print(f"Packing program ROM from {program_low} and {program_high}...")
    program = interleave_program_roms(program_low, program_high)
    program = pad_section(program, program_size)
    print(f"  Program ROM: {len(program)} bytes")
    rom_data.extend(program)

    # BA1: OKI ROM (typically not present in tdragonb2, pad with zeros)
    print(f"Packing OKI ROM (not present in tdragonb2, padding)...")
    oki = b'\x00' * oki_size
    print(f"  OKI ROM: {len(oki)} bytes (padded)")
    rom_data.extend(oki)

    # BA2: GFX ROM
    print(f"Packing GFX ROM from {gfx}...")
    gfx_data = read_file(gfx)
    gfx_data = pad_section(gfx_data, gfx_size)
    print(f"  GFX ROM: {len(gfx_data)} bytes")
    rom_data.extend(gfx_data)

    # Write rom.bin
    output_file = Path('rom.bin')
    write_file(output_file, rom_data)
    print()
    print(f"Wrote {output_file}: {len(rom_data)} bytes")

    # Display vector table (first 16 bytes)
    print()
    print("Vector table (first 16 bytes):")
    for i in range(0, 16, 2):
        val = (rom_data[i] << 8) | rom_data[i+1]
        print(f"  [{i:02X}] = 0x{val:04X}")

if __name__ == '__main__':
    main()
