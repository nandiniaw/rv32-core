import importlib.util, os, re, unittest
HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.environ.get("GEN_PATH", os.path.join(HERE, "gen_prog.py"))
spec = importlib.util.spec_from_file_location("gen_prog", PATH)
G = importlib.util.module_from_spec(spec)
spec.loader.exec_module(G)
SEEDS = range(1, 41)
ALU = set(G.RR + G.RI + G.SH)


def parse(text):
    lines = text.split("\n")
    ins = {}
    for k, l in enumerate(lines):
        m = re.match(r"^L(\d+):$", l)
        nxt = lines[k + 1] if k + 1 < len(lines) else ""
        if m and nxt.startswith("    ") and \
                not nxt.startswith("    la x5, tohost"):
            ins[int(m.group(1))] = nxt.strip()
    assert sorted(ins) == list(range(len(ins))), "label gap"
    return [ins[i] for i in sorted(ins)]


def gen(seed, traps=False, n=150):
    text, mix = G.build(seed, n, traps)
    return text, mix, parse(text)


def mn(t):
    return t.split()[0]


def regs(t):
    return re.findall(r"x\d+", t)


def off(t):
    return int(re.search(r"(\d+)\(x28\)", t).group(1))


class GenTest(unittest.TestCase):
    def all_ins(self, traps=False):
        for s in SEEDS:
            yield gen(s, traps)[2]

    def test_tags_plain(self):
        tags = set()
        for s in SEEDS:
            tags |= set(gen(s)[1])
        want = {"alu", "load", "store", "br", "upper", "jal", "csr"}
        self.assertEqual(tags, want)

    def test_trap_mode(self):
        tags, ins = set(), []
        for s in SEEDS:
            _, m, i = gen(s, True)
            tags |= set(m)
            ins += i
        self.assertIn("trap", tags)
        self.assertIn("ecall", ins)
        self.assertIn("ebreak", ins)
        self.assertIn(".word 0", ins)
        odd = [t for t in ins
               if mn(t) in ("lw", "sw") and "(x28)" in t and off(t) % 2]
        self.assertTrue(odd, "no misaligned lw/sw")

    def test_forward_only(self):
        n = 0
        for ins in self.all_ins(True):
            for i, t in enumerate(ins):
                if mn(t) in G.BR or mn(t) == "jal":
                    n += 1
                    self.assertGreater(int(re.search(r"L(\d+)$", t).group(1)), i)
        self.assertGreater(n, 0)

    def test_plain_aligned_in_buffer(self):
        n = 0
        for ins in self.all_ins():
            for t in ins:
                w = G.LD.get(mn(t)) or G.ST.get(mn(t))
                if w and "(x28)" in t:
                    n += 1
                    self.assertEqual(off(t) % w, 0, t)
                    self.assertLessEqual(off(t) + w, 256, t)
        self.assertGreater(n, 0)

    def test_load_use(self):
        n = 0
        for ins in self.all_ins():
            for a, b in zip(ins, ins[1:]):
                if mn(a) in G.LD and regs(a)[0] != "x0" and mn(b) in ALU \
                        and regs(a)[0] in regs(b)[1:]:
                    n += 1
        print("load-use pairs:", n)
        self.assertGreaterEqual(n, 100)

    def test_store_then_load_same_addr(self):
        ok = False
        for ins in self.all_ins():
            for a, b in zip(ins, ins[1:]):
                if mn(a) in G.ST and mn(b) in G.LD and "(x28)" in a \
                        and "(x28)" in b and off(a) == off(b):
                    ok = True
        self.assertTrue(ok)

    def test_x0_write_then_read(self):
        n = 0
        for ins in self.all_ins():
            for a, b in zip(ins, ins[1:]):
                if mn(a) in ALU and regs(a)[0] == "x0" and mn(b) in ALU \
                        and "x0" in regs(b)[1:]:
                    n += 1
        print("x0 pairs:", n)
        self.assertGreaterEqual(n, 100)

    def test_deterministic_and_seeded(self):
        self.assertEqual(gen(7)[0], gen(7)[0])
        self.assertNotEqual(gen(7)[0], gen(8)[0])

    def test_ends_with_tohost(self):
        for s in (1, 2, 3):
            for tr in (False, True):
                self.assertIn("sw x6, 0(x5)\n    sw zero, 4(x5)", gen(s, tr)[0])


if __name__ == "__main__":
    unittest.main()
