#!/usr/bin/env python3
"""Prints RVFI signals per time step from a SymbiYosys VCD. Usage: vcd_table.py <trace.vcd> [max_rows]"""
import collections
import sys

WANT = ["rvfi_valid", "rvfi_order", "rvfi_insn", "rvfi_trap", "rvfi_pc_rdata", "rvfi_pc_wdata"]
scope, ids, cand = [], {}, collections.defaultdict(dict)
lines = open(sys.argv[1]).read().splitlines()
i = 0
while i < len(lines) and "$enddefinitions" not in lines[i]:
    p = lines[i].split()
    if p[:1] == ["$scope"]:
        scope.append(p[2])
    elif p[:1] == ["$upscope"]:
        scope.pop()
    elif p[:1] == ["$var"] and p[4] in WANT:
        cand[".".join(scope)][p[4]] = p[3]
    i += 1
best = max(cand, key=lambda s: (len(cand[s]), -len(s)))
print("scope used:", best, "| signals:", sorted(cand[best]))
sel = {v: k for k, v in cand[best].items()}
cur = {k: "?" for k in WANT}
rows, t = [], None
for ln in lines[i + 1:]:
    if ln.startswith("#"):
        if t is not None:
            rows.append((t, dict(cur)))
        t = int(ln[1:])
    elif ln and ln[0] in "01xz":
        if ln[1:] in sel:
            cur[sel[ln[1:]]] = ln[0]
    elif ln.startswith("b"):
        v, idc = ln[1:].split()
        if idc in sel:
            cur[sel[idc]] = v
if t is not None:
    rows.append((t, dict(cur)))
fmt = lambda v: v if len(v) < 2 or "x" in v else hex(int(v, 2))
print("time | " + " | ".join(WANT))
seen = None
for t, r in rows[: int(sys.argv[2]) if len(sys.argv) > 2 else 60]:
    line = " | ".join(fmt(r[k]) for k in WANT)
    if line != seen:
        print(f"{t} | {line}")
        seen = line
