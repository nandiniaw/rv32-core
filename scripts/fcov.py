#!/usr/bin/env python3
"""Functional coverage from core retire traces (/tmp/*.core.trace). Retire-distance bins, not RTL selectors.
usage: fcov.py trace [trace ...]"""
import sys
from collections import Counter

LD = {0x0, 0x1, 0x2, 0x4, 0x5}
c = Counter()
for path in sys.argv[1:]:
    hist = []  # (rd, is_load)
    for ln in open(path):
        f = ln.split()
        if len(f) < 20:
            continue
        insn = int(f[2], 16); trap = int(f[4]); rd = int(f[5])
        pc, npc = int(f[1], 16), int(f[3], 16)
        cause = int(f[18], 16)
        op = insn & 0x7F; rs1 = (insn >> 15) & 31; rs2 = (insn >> 20) & 31
        uses1 = op in (0x33, 0x13, 0x03, 0x23, 0x63, 0x67, 0x73)
        uses2 = op in (0x33, 0x23, 0x63)
        for nm, r, u in (("rs1", rs1, uses1), ("rs2", rs2, uses2)):
            if not u or r == 0:
                continue
            for d in (1, 2):
                if len(hist) >= d and hist[-d][0] == r:
                    c["fwd_%s_dist%d" % (nm, d)] += 1
                    break
            else:
                c["fwd_%s_none" % nm] += 1
            if hist and hist[-1][0] == r and hist[-1][1]:
                c["loaduse_%s" % nm] += 1
        if op == 0x63:
            c["branch_taken" if npc != pc + 4 else "branch_nottaken"] += 1
        if op == 0x73 and (insn >> 12) & 7:
            c["csr_f3_%d_addr_%03x" % ((insn >> 12) & 7, insn >> 20)] += 1
        if rd == 0 and op in (0x33, 0x13, 0x03):
            c["rd_x0"] += 1
        if trap:
            c["trap_cause_%d" % cause] += 1
        hist.append((rd, op == 0x03))
want = ["fwd_rs1_dist1", "fwd_rs1_dist2", "fwd_rs1_none", "fwd_rs2_dist1", "fwd_rs2_dist2",
        "fwd_rs2_none", "loaduse_rs1", "loaduse_rs2", "branch_taken", "branch_nottaken", "rd_x0"]
want += ["trap_cause_%d" % x for x in (0, 2, 3, 4, 6, 11)]
want += ["csr_f3_%d_addr_340" % x for x in (1, 2, 3, 5, 6, 7)]
hit = 0
for k in want:
    print("%-18s %d" % (k, c[k])); hit += c[k] > 0
for k in sorted(c):
    if k not in want:
        print("%-18s %d" % (k, c[k]))
print("listed bins hit: %d/%d" % (hit, len(want)))
print("unreached:", [k for k in want if c[k] == 0] or "none")
