#!/usr/bin/env python3
"""Seeded random RV32I+Zicsr program generator. Oracle = Sail cosim.
usage: gen_prog.py --seed N [--n 150] [--traps] --out file.S"""
import argparse, random, sys
from collections import Counter

POOL = [5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17]
RR = ['add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and']
RI = ['addi', 'slti', 'sltiu', 'xori', 'ori', 'andi']
SH = ['slli', 'srli', 'srai']
BR = ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu']
LD = {'lw': 4, 'lh': 2, 'lhu': 2, 'lb': 1, 'lbu': 1}
ST = {'sw': 4, 'sh': 2, 'sb': 1}


def build(seed, n, traps):
    rng = random.Random(seed)
    ins = []

    def src():
        return "x%d" % rng.choice(POOL + [0])

    def dst():
        return "x0" if rng.random() < 0.08 else "x%d" % rng.choice(POOL)

    def reg():
        return "x%d" % rng.choice(POOL)

    def off(w):
        return rng.randrange(0, 256, w)

    def alu(d, a, b):
        k = rng.random()
        if k < 0.5:
            return ("alu", "%s %s, %s, %s" % (rng.choice(RR), d, a, b))
        if k < 0.85:
            return ("alu", "%s %s, %s, %d" % (rng.choice(RI), d, a, rng.randrange(-2048, 2048)))
        return ("alu", "%s %s, %s, %d" % (rng.choice(SH), d, a, rng.randrange(32)))

    def skip():
        return rng.randrange(2, 5)

    def t_alu():
        return [alu(dst(), src(), src())]

    def t_dep():
        a = reg()
        x = [alu(a, src(), src())]
        for _ in range(rng.randrange(1, 3)):
            b = reg()
            x.append(alu(b, a, src()) if rng.random() < .5 else alu(b, src(), a))
            a = b
        return x

    def t_loaduse():
        a = reg()
        op = rng.choice(list(LD))
        x = [("load", "%s %s, %d(x28)" % (op, a, off(LD[op])))]
        k = rng.random()
        if k < .5:
            x.append(alu(reg(), a, src()) if rng.random() < .5 else alu(reg(), src(), a))
        elif k < .75:
            s = rng.choice(list(ST))
            x.append(("store", "%s %s, %d(x28)" % (s, a, off(ST[s]))))
        else:
            x.append(("br", rng.choice(BR), a, src(), skip()))
        return x

    def t_stld():
        s = rng.choice(list(ST))
        w = ST[s]
        o = off(w)
        lop = rng.choice([l for l in LD if LD[l] <= w])
        return [("store", "%s %s, %d(x28)" % (s, src(), o)),
                ("load", "%s %s, %d(x28)" % (lop, dst(), o))]

    def t_x0():
        if rng.random() < .3:
            return [("load", "lw x0, %d(x28)" % off(4)), alu(reg(), "x0", src())]
        return [alu("x0", src(), src()), alu(reg(), "x0", src())]

    def t_br():
        return [("br", rng.choice(BR), src(), src(), skip())]

    def t_up():
        return [("upper", "%s %s, %d" % (rng.choice(['lui', 'auipc']), dst(), rng.randrange(1 << 20)))]

    def t_jal():
        return [("jal", dst(), rng.randrange(2, 4))]

    def t_csr():
        a = reg()
        k = rng.choice(['csrrw', 'csrrs', 'csrrc'])
        if rng.random() < .25:
            return [("csr", "%si %s, 0x340, %d" % (k, dst(), rng.randrange(32)))]
        return [("csr", "%s %s, 0x340, %s" % (k, dst(), a))]

    def t_trap():
        k = rng.randrange(4)
        if k == 0:
            return [("trap", "ecall")]
        if k == 1:
            return [("trap", "ebreak")]
        if k == 2:
            return [("trap", ".word 0")]
        o = rng.randrange(0, 252) | 1
        return [("trap", "%s %s, %d(x28)" % (rng.choice(['lw', 'sw']), reg(), o))]

    tmpl = [(t_alu, 25), (t_dep, 20), (t_loaduse, 15), (t_stld, 10), (t_x0, 5),
            (t_br, 8), (t_up, 4), (t_jal, 4), (t_csr, 4)]
    if traps:
        tmpl.append((t_trap, 5))
    fns = [f for f, w in tmpl]
    wts = [w for f, w in tmpl]
    while len(ins) < n:
        ins += rng.choices(fns, wts)[0]()
    N = len(ins)

    L = []
    L.append("# seed=%d n=%d traps=%s (generated, do not edit)" % (seed, n, traps))
    L.append("    .section .text.init\n    .globl _start\n_start:")
    L.append("    la x31, handler\n    csrw mtvec, x31\n    la x28, buf")
    for r in POOL:
        L.append("    li x%d, 0x%08x" % (r, rng.getrandbits(32)))
    mix = Counter()
    for i, it in enumerate(ins):
        L.append("L%d:" % i)
        t = it[0]
        mix[t] += 1
        if t == "br":
            L.append("    %s %s, %s, L%d" % (it[1], it[2], it[3], min(i + it[4], N)))
        elif t == "jal":
            L.append("    jal %s, L%d" % (it[1], min(i + it[2], N)))
        else:
            L.append("    " + it[1])
    L.append("L%d:" % N)
    L.append("    la x5, tohost\n    li x6, 1\n    sw x6, 0(x5)\n    sw zero, 4(x5)\n1:  j 1b")
    L.append("    .align 2\nhandler:\n    csrr x31, mepc\n    addi x31, x31, 4\n    csrw mepc, x31\n    mret")
    L.append('    .section .text.buf, "aw", @progbits\n    .align 4\nbuf:')
    for _ in range(64):
        L.append("    .word 0x%08x" % rng.getrandbits(32))
    L.append('    .section .tohost, "aw", @progbits\n    .align 6')
    L.append("    .globl tohost\ntohost:   .dword 0\n    .globl fromhost\nfromhost: .dword 0")
    return "\n".join(L) + "\n", mix


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--seed", type=int, required=True)
    p.add_argument("--n", type=int, default=150)
    p.add_argument("--traps", action="store_true")
    p.add_argument("--out", required=True)
    a = p.parse_args()
    text, mix = build(a.seed, a.n, a.traps)
    open(a.out, "w").write(text)
    print("seed %d mix: %s" % (a.seed, dict(mix)), file=sys.stderr)
