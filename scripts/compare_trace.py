#!/usr/bin/env python3
"""compare_trace.py <rtl.trace> <sail.trace>

Compares the RTL retire trace (written by tests/system/test_core_elf.py) with Sail's text trace
(sail_riscv_sim --trace). Per instruction it checks: pc, instruction word, next pc, rd write,
load and store (byte address, size, data). CSR activity in Sail's trace is reported as unsupported.
Exit 0 only if every instruction matches and both traces have the same length.
"""
import re
import sys

M32 = 0xFFFFFFFF
INSN = re.compile(r"^\[(\d+)\] \[(\w)\]: 0x([0-9A-Fa-f]+) \(0x([0-9A-Fa-f]+)\)\s*(.*)$")
XWR = re.compile(r"^x(\d+) <- 0x([0-9A-Fa-f]+)\s*$")
LOAD = re.compile(r"^mem\[R,0x([0-9A-Fa-f]+)\] -> 0x([0-9A-Fa-f]+)\s*$")
STORE = re.compile(r"^mem\[W,0x([0-9A-Fa-f]+)\] <- 0x([0-9A-Fa-f]+)\s*$")
IGNORED = re.compile(r"^(mem\[X,|htif)")


def parse_sail(path):
    recs, cur, unknown = [], None, []
    for raw in open(path):
        line = raw.rstrip("\n")
        m = INSN.match(line)
        if m:
            cur = {"n": int(m.group(1)), "pc": int(m.group(3), 16) & M32, "insn": int(m.group(4), 16),
                   "text": " ".join(m.group(5).split()), "wr": [], "loads": [], "stores": [], "csr": []}
            recs.append(cur)
            continue
        if cur is None or not line.strip():
            continue  # preamble before the first instruction, or blank separator
        m = XWR.match(line)
        if m:
            cur["wr"].append((int(m.group(1)), int(m.group(2), 16) & M32))
            continue
        m = LOAD.match(line)
        if m:
            cur["loads"].append((int(m.group(1), 16) & M32, len(m.group(2)) // 2, int(m.group(2), 16)))
            continue
        m = STORE.match(line)
        if m:
            cur["stores"].append((int(m.group(1), 16) & M32, len(m.group(2)) // 2, int(m.group(2), 16)))
            continue
        if line.startswith("CSR "):
            cur["csr"].append(line.strip())
            continue
        if not IGNORED.match(line):
            unknown.append(line.strip())
    return recs, unknown


def parse_rtl(path):
    recs = []
    for raw in open(path):
        p = raw.split()
        if len(p) != 12:
            sys.exit(f"bad RTL trace line (expected 12 fields): {raw!r}")
        recs.append({"order": int(p[0]), "pc": int(p[1], 16), "insn": int(p[2], 16), "npc": int(p[3], 16),
                     "trap": int(p[4]), "rd": int(p[5], 10), "rdv": int(p[6], 16), "maddr": int(p[7], 16),
                     "rm": int(p[8], 16), "wm": int(p[9], 16), "rdata": int(p[10], 16), "wdata": int(p[11], 16)})
    return recs


def rtl_mem(addr, mask, data):
    """Aligned-style RVFI (word address, byte-lane mask, word-lane data) -> Sail style (byte address, size, data)."""
    lanes = [i for i in range(4) if (mask >> i) & 1]
    if not lanes:
        return []
    lo, size = lanes[0], len(lanes)
    if lanes != list(range(lo, lo + size)) or size not in (1, 2, 4) or lo % size:
        return [("invalid-mask", mask)]
    return [((addr + lo) & M32, size, (data >> (8 * lo)) & ((1 << (8 * size)) - 1))]


def hx(item):
    return "(" + ", ".join(f"0x{v:x}" if isinstance(v, int) else str(v) for v in item) + ")"


def compare(rtl, sail):
    base = sail[0]["n"] if sail else 0
    for i in range(min(len(rtl), len(sail))):
        r, s = rtl[i], sail[i]
        errs = []
        if r["order"] != i:
            errs.append(f"rvfi_order {r['order']} != {i}")
        if s["n"] - base != i:
            errs.append(f"Sail instruction counter {s['n']} not consecutive")
        if r["trap"]:
            errs.append("RTL reported a trap (traps are not modelled in Phase 2)")
        if r["pc"] != s["pc"]:
            errs.append(f"pc: RTL 0x{r['pc']:08x} vs Sail 0x{s['pc']:08x}")
        if r["insn"] != s["insn"]:
            errs.append(f"insn: RTL 0x{r['insn']:08x} vs Sail 0x{s['insn']:08x}")
        if i + 1 < len(sail) and r["npc"] != sail[i + 1]["pc"]:
            errs.append(f"next pc: RTL 0x{r['npc']:08x} vs Sail 0x{sail[i + 1]['pc']:08x}")
        if len(s["wr"]) > 1:
            errs.append(f"Sail wrote more than one register: {s['wr']}")
        elif s["wr"]:
            n, v = s["wr"][0]
            if (r["rd"], r["rdv"]) != (n, v):
                errs.append(f"rd write: RTL x{r['rd']}=0x{r['rdv']:08x} vs Sail x{n}=0x{v:08x}")
        elif (r["rd"], r["rdv"]) != (0, 0):
            errs.append(f"rd write: RTL x{r['rd']}=0x{r['rdv']:08x} but Sail wrote no register")
        rl, rs = rtl_mem(r["maddr"], r["rm"], r["rdata"]), rtl_mem(r["maddr"], r["wm"], r["wdata"])
        if rl != s["loads"]:
            errs.append(f"load: RTL {[hx(x) for x in rl]} vs Sail {[hx(x) for x in s['loads']]}")
        if rs != s["stores"]:
            errs.append(f"store: RTL {[hx(x) for x in rs]} vs Sail {[hx(x) for x in s['stores']]}")
        if s["csr"]:
            errs.append(f"Sail logged CSR activity (not modelled yet): {s['csr'][0]}")
        if errs:
            print(f"MISMATCH at instruction {i}")
            print(f"  Sail: [{s['n']}] 0x{s['pc']:08x} (0x{s['insn']:08x}) {s['text']}")
            print(f"  RTL : order={r['order']} pc=0x{r['pc']:08x} insn=0x{r['insn']:08x} npc=0x{r['npc']:08x} "
                  f"rd=x{r['rd']} rdv=0x{r['rdv']:08x} mem=0x{r['maddr']:08x} rm={r['rm']:x} wm={r['wm']:x}")
            for e in errs:
                print("  - " + e)
            return False
    if len(rtl) != len(sail):
        print(f"LENGTH MISMATCH: RTL {len(rtl)} instructions vs Sail {len(sail)} "
              f"(the first {min(len(rtl), len(sail))} match)")
        return False
    return True


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    rtl = parse_rtl(sys.argv[1])
    sail, unknown = parse_sail(sys.argv[2])
    if not rtl or not sail:
        sys.exit(f"empty trace (RTL {len(rtl)} records, Sail {len(sail)} records)")
    ok = compare(rtl, sail)
    if unknown:
        print(f"note: {len(unknown)} unrecognised Sail line(s) ignored; first: {unknown[0]!r}")
    if ok:
        print(f"COMPARE PASS: {len(rtl)} instructions match (pc, insn, next pc, rd, loads, stores)")
    sys.exit(0 if ok else 1)


main()
