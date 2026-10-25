#!/usr/bin/env python3
"""Self-test for compare_trace.py, trace format v2. Hand-made traces, no simulator needed."""
import os, subprocess, sys, tempfile

CMP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "compare_trace.py")
TRAP = ["trapping from M to M to handle software-breakpoint",
        "handling exc#software-breakpoint at priv M | tval=0x80000010 | tval2=0x00000000 | tinst=0x00000000",
        "CSR mstatus (0x300) <- 0x00001800", "CSR mstatush (0x310) <- 0x00000000",
        "CSR mcause (0x342) <- 0x00000003", "CSR mtval (0x343) <- 0x80000010",
        "CSR mepc (0x341) <- 0x80000010"]
PROG = [
    (0x80000000, 0x00000297, "auipc x5, 0x0", ["x5 <- 0x80000000"]),
    (0x80000004, 0x04028293, "addi x5, x5, 0x40", ["x5 <- 0x80000040"]),
    (0x80000008, 0x30529073, "csrrw x0, mtvec, x5", ["CSR mtvec (0x305) <- 0x80000040"]),
    (0x8000000C, 0x34029073, "csrrw x0, mscratch, x5", ["CSR mscratch (0x340) <- 0x80000040"]),
    (0x80000010, 0x00100073, "ebreak", TRAP),
    (0x80000040, 0x342023F3, "csrrs x7, mcause, x0", ["CSR mcause (0x342) -> 0x00000003", "x7 <- 0x00000003"]),
]
Z = [0] * 7                                   # mstatus mie mtvec mscratch mepc mcause mtval
C2 = [0, 0, 0x80000040, 0, 0, 0, 0]
C3 = [0, 0, 0x80000040, 0x80000040, 0, 0, 0]
C4 = [0x1800, 0, 0x80000040, 0x80000040, 0x80000010, 3, 0x80000010]


def good_rows():  # pc insn npc trap rd rdv intr csr
    return [[0x80000000, 0x297, 0x80000004, 0, 5, 0x80000000, 0, Z],
            [0x80000004, 0x04028293, 0x80000008, 0, 5, 0x80000040, 0, Z],
            [0x80000008, 0x30529073, 0x8000000C, 0, 0, 0, 0, C2],
            [0x8000000C, 0x34029073, 0x80000010, 0, 0, 0, 0, C3],
            [0x80000010, 0x00100073, 0x80000040, 1, 0, 0, 0, C4],
            [0x80000040, 0x342023F3, 0x80000044, 0, 7, 3, 1, C4]]


def rtl_text(rows):
    out = []
    for n, (pc, insn, npc, trap, rd, rdv, intr, csr) in enumerate(rows):
        f = [str(n), f"{pc:08x}", f"{insn:08x}", f"{npc:08x}", str(trap), f"{rd:02d}", f"{rdv:08x}",
             "00000000", "0", "0", "00000000", "00000000", str(intr)] + [f"{v:08x}" for v in csr]
        out.append(" ".join(f))
    return "\n".join(out) + "\n"


def sail_text(prog):
    out = ["CSR mip (0x344) <- 0x00000080", ""]
    for n, (pc, insn, text, extra) in enumerate(prog):
        out.append(f"[{n}] [M]: 0x{pc:08X} (0x{insn:08X}) {text}    _start+{n}")
        out += extra + [""]
    return "\n".join(out) + "\n"


def run(rows, prog):
    with tempfile.TemporaryDirectory() as d:
        r, s = os.path.join(d, "rtl"), os.path.join(d, "sail")
        open(r, "w").write(rtl_text(rows))
        open(s, "w").write(sail_text(prog))
        p = subprocess.run([sys.executable, CMP, r, s], capture_output=True, text=True)
    return p.returncode, (p.stdout + p.stderr)


cases = []
cases.append(("clean trap + CSR trace", good_rows(), PROG, 0, ["COMPARE PASS"]))
rows = good_rows(); rows[4][3] = 0
cases.append(("RTL misses the trap", rows, PROG, 1, ["MISMATCH", "trap"]))
rows = good_rows(); rows[1][3] = 1
cases.append(("RTL traps without a Sail exception", rows, PROG, 1, ["MISMATCH", "trap"]))
rows = good_rows(); rows[3][7] = [0, 0, 0x80000040, 0x12345678, 0, 0, 0]
cases.append(("wrong mscratch snapshot", rows, PROG, 1, ["MISMATCH", "mscratch"]))
rows = good_rows(); rows[5][6] = 0
cases.append(("missing intr on handler entry", rows, PROG, 1, ["MISMATCH", "intr"]))
prog = list(PROG)
prog[3] = (0x8000000C, 0x3A029073, "csrrw x0, pmpcfg0, x5", ["CSR pmpcfg0 (0x3A0) <- 0x00000000"])
cases.append(("CSR outside implemented set", good_rows(), prog, 1, ["MISMATCH", "unsupported CSR touched"]))

bad = 0
for name, rows, prog, rc_want, needles in cases:
    rc, out = run(rows, prog)
    ok = rc == rc_want and all(n.lower() in out.lower() for n in needles)
    print(("PASS  " if ok else "FAIL  ") + name)
    if not ok:
        bad += 1
        print("      rc=%d, first output line: %s" % (rc, out.strip().splitlines()[0] if out.strip() else "(none)"))
print("SELFTEST " + ("ALL PASS" if bad == 0 else f"{bad} of {len(cases)} FAILED"))
sys.exit(1 if bad else 0)
