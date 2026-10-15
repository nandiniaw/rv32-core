#!/usr/bin/env python3
"""elf2hex.py <in.elf> <out.hex> [mem_bytes]
Flat image starting at 0x80000000, one 32-bit little-endian word per line (hex), for $readmemh."""
import os
import re
import struct
import subprocess
import sys
import tempfile

BASE = 0x8000_0000
RV = "riscv64-unknown-elf-"


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    elf, out = sys.argv[1], sys.argv[2]
    mem_bytes = int(sys.argv[3], 0) if len(sys.argv) > 3 else 64 * 1024
    hdr = run([RV + "readelf", "-lW", elf])
    loads = [l.split() for l in hdr.splitlines() if l.split()[:1] == ["LOAD"]]
    if not loads:
        sys.exit("no LOAD segments in " + elf)
    lo = min(int(l[2], 16) for l in loads)
    hi = max(int(l[2], 16) + int(l[5], 16) for l in loads)
    m = re.search(r"Entry point (0x[0-9a-fA-F]+)", hdr)
    entry = int(m.group(1), 16) if m else None
    if lo != BASE:
        sys.exit(f"lowest LOAD address 0x{lo:08x} is not 0x{BASE:08x}")
    if entry != BASE:
        sys.exit(f"entry point {entry} is not 0x{BASE:08x}")
    if hi - BASE > mem_bytes:
        sys.exit(f"image extent {hi - BASE} bytes exceeds memory {mem_bytes}")
    with tempfile.TemporaryDirectory() as d:
        binf = os.path.join(d, "img.bin")
        run([RV + "objcopy", "-O", "binary", elf, binf])
        data = open(binf, "rb").read()
    data += b"\x00" * (-len(data) % 4)
    words = struct.unpack("<%dI" % (len(data) // 4), data)
    with open(out, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")
    print(f"elf2hex: {len(words)} words, extent 0x{BASE:08x}..0x{hi:08x}, entry 0x{entry:08x}")


main()
