#!/usr/bin/env python3
"""Formal-only derived copy of the RTL.
Yosys's built-in SystemVerilog frontend rejects `import pkg::*;`, so the package's localparam lines are
pasted in place of each import line. Usage: inline_pkg.py <rtl_dir> <out_dir>"""
import pathlib
import re
import sys

rtl, out = (pathlib.Path(a) for a in sys.argv[1:3])
out.mkdir(parents=True, exist_ok=True)
consts = [l for l in (rtl / "rv32_pkg.sv").read_text().splitlines() if l.strip().startswith("localparam")]
assert consts, "no localparam lines found in rv32_pkg.sv"
IMPORT = re.compile(r"^\s*import\s+rv32_pkg::\*;\s*$")
for f in sorted(rtl.glob("*.sv")):
    if f.name == "rv32_pkg.sv":
        continue
    new, n = [], 0
    for line in f.read_text().splitlines():
        if IMPORT.match(line):
            new += ["    // inlined from rv32_pkg.sv (formal copy)"] + consts
            n += 1
        else:
            new.append(line)
    (out / f.name).write_text("\n".join(new) + "\n")
    print(f"{f.name}: {n} import(s) inlined")
left = [f.name for f in out.glob("*.sv") if "rv32_pkg::" in f.read_text()]
assert not left, f"rv32_pkg:: still referenced in {left}"
