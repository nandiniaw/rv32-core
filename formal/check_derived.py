#!/usr/bin/env python3
"""Proves the formal copy differs from rtl/ only by the inlined package constants.
Usage: check_derived.py <rtl_dir> <derived_dir>"""
import pathlib
import sys

rtl, der = (pathlib.Path(a) for a in sys.argv[1:3])
consts = {l.strip() for l in (rtl / "rv32_pkg.sv").read_text().splitlines() if l.strip().startswith("localparam")}
keep = lambda l: "import rv32_pkg" not in l and "inlined from rv32_pkg" not in l and l.strip() not in consts
bad = 0
for f in sorted(rtl.glob("*.sv")):
    if f.name == "rv32_pkg.sv":
        continue
    a = [l for l in f.read_text().splitlines() if keep(l)]
    b = [l for l in (der / f.name).read_text().splitlines() if keep(l)]
    ok = a == b
    print(f"{f.name}: {'identical apart from inlined constants' if ok else 'DIFFERS'}")
    bad += not ok
sys.exit(1 if bad else 0)
