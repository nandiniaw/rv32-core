"""cocotb tests for branch_cmp. The reference is Python's own signed/unsigned comparison."""
import random

import cocotb
from cocotb.triggers import Timer

M32 = 0xFFFFFFFF
CORNERS = [0, 1, 2, 0x7FFFFFFF, 0x80000000, 0x80000001, 0xFFFFFFFE, 0xFFFFFFFF]


def s32(x):
    return x - (1 << 32) if x & 0x80000000 else x


def ref(a, b, f3):
    table = {0: a == b, 1: a != b, 4: s32(a) < s32(b), 5: s32(a) >= s32(b), 6: a < b, 7: a >= b}
    return int(table.get(f3, False))   # funct3 2 and 3 are reserved: not taken


async def check(dut, a, b, f3):
    dut.a.value = a
    dut.b.value = b
    dut.funct3.value = f3
    await Timer(1, "ns")
    got = int(dut.taken.value)
    assert got == ref(a, b, f3), f"funct3={f3} a=0x{a:08x} b=0x{b:08x}: expected {ref(a, b, f3)}, got {got}"


@cocotb.test()
async def test_corner_pairs_all_funct3(dut):
    for f3 in range(8):
        for a in CORNERS:
            for b in CORNERS:
                await check(dut, a, b, f3)


@cocotb.test()
async def test_equal_and_adjacent_values(dut):
    rng = random.Random(20261012)
    for _ in range(400):
        a = rng.getrandbits(32)
        for b in (a, (a + 1) & M32, (a - 1) & M32, a ^ 0x80000000):
            for f3 in range(8):
                await check(dut, a, b, f3)


@cocotb.test()
async def test_random_pairs(dut):
    rng = random.Random(20261013)
    for _ in range(1500):
        a, b = rng.getrandbits(32), rng.getrandbits(32)
        for f3 in range(8):
            await check(dut, a, b, f3)
