"""cocotb tests for imm_gen.

The reference is deliberately built a different way from the RTL:
- round trip: encode a chosen immediate into an instruction word, expect the DUT to
  return the sign-extended immediate;
- raw words: compare against arithmetic field assembly (no bit-slice copying).
"""
import random

import cocotb
from cocotb.triggers import Timer

IMM_I, IMM_S, IMM_B, IMM_U, IMM_J = 0, 1, 2, 3, 4
MASK32 = 0xFFFFFFFF


def sext(value, bits):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def u32(value):
    return value & MASK32


def enc_i(imm, low20):
    return u32(((imm & 0xFFF) << 20) | (low20 & 0xFFFFF))


def enc_s(imm, other):
    word = other & 0x01FFF07F
    word |= ((imm >> 5) & 0x7F) << 25
    word |= (imm & 0x1F) << 7
    return u32(word)


def enc_b(imm, other):
    word = other & 0x01FFF07F
    word |= ((imm >> 12) & 1) << 31
    word |= ((imm >> 5) & 0x3F) << 25
    word |= ((imm >> 1) & 0xF) << 8
    word |= ((imm >> 11) & 1) << 7
    return u32(word)


def enc_u(imm20, low12):
    return u32(((imm20 & 0xFFFFF) << 12) | (low12 & 0xFFF))


def enc_j(imm, low12):
    word = low12 & 0xFFF
    word |= ((imm >> 20) & 1) << 31
    word |= ((imm >> 1) & 0x3FF) << 21
    word |= ((imm >> 11) & 1) << 20
    word |= ((imm >> 12) & 0xFF) << 12
    return u32(word)


def ref_imm(insn, kind):
    bit = lambda n: (insn >> n) & 1
    if kind == IMM_I:
        return u32(sext(insn >> 20, 12))
    if kind == IMM_S:
        return u32(sext(((insn >> 25) << 5) | ((insn >> 7) & 0x1F), 12))
    if kind == IMM_B:
        v = (bit(31) << 12) | (bit(7) << 11) | (((insn >> 25) & 0x3F) << 5) | (((insn >> 8) & 0xF) << 1)
        return u32(sext(v, 13))
    if kind == IMM_U:
        return insn & 0xFFFFF000
    if kind == IMM_J:
        v = (bit(31) << 20) | (((insn >> 12) & 0xFF) << 12) | (bit(20) << 11) | (((insn >> 21) & 0x3FF) << 1)
        return u32(sext(v, 21))
    return 0


async def drive(dut, insn, kind):
    dut.insn.value = insn
    dut.imm_type.value = kind
    await Timer(1, "ns")
    return int(dut.imm.value)


def check(got, exp, insn, kind):
    assert got == exp, f"type {kind} insn=0x{insn:08x}: expected 0x{exp:08x}, got 0x{got:08x}"


RNG_SEED = 20261011


def edge_values(bits, step):
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - step
    pats = {lo, hi, 0, step, -step,
            sext(0x5555555, bits) & ~(step - 1), sext(0xAAAAAAA, bits) & ~(step - 1)}
    return sorted(v for v in pats if lo <= v <= hi and v % step == 0)


@cocotb.test()
async def test_i_roundtrip(dut):
    rng = random.Random(RNG_SEED)
    for imm in edge_values(12, 1) + [rng.randrange(-2048, 2048) for _ in range(2000)]:
        insn = enc_i(imm, rng.getrandbits(20))
        check(await drive(dut, insn, IMM_I), u32(imm), insn, IMM_I)


@cocotb.test()
async def test_s_roundtrip(dut):
    rng = random.Random(RNG_SEED + 1)
    for imm in edge_values(12, 1) + [rng.randrange(-2048, 2048) for _ in range(2000)]:
        insn = enc_s(imm, rng.getrandbits(32))
        check(await drive(dut, insn, IMM_S), u32(imm), insn, IMM_S)


@cocotb.test()
async def test_b_roundtrip(dut):
    rng = random.Random(RNG_SEED + 2)
    for imm in edge_values(13, 2) + [rng.randrange(-2048, 2048) * 2 for _ in range(2000)]:
        insn = enc_b(imm, rng.getrandbits(32))
        got = await drive(dut, insn, IMM_B)
        check(got, u32(imm), insn, IMM_B)
        assert got & 1 == 0, f"B immediate bit 0 must be 0 (insn=0x{insn:08x})"


@cocotb.test()
async def test_u_roundtrip(dut):
    rng = random.Random(RNG_SEED + 3)
    vals = [0, 0xFFFFF, 0x80000, 0x7FFFF, 0x55555, 0xAAAAA] + [rng.getrandbits(20) for _ in range(2000)]
    for imm20 in vals:
        insn = enc_u(imm20, rng.getrandbits(12))
        got = await drive(dut, insn, IMM_U)
        check(got, u32(imm20 << 12), insn, IMM_U)
        assert got & 0xFFF == 0, f"U immediate low 12 bits must be 0 (insn=0x{insn:08x})"


@cocotb.test()
async def test_j_roundtrip(dut):
    rng = random.Random(RNG_SEED + 4)
    for imm in edge_values(21, 2) + [rng.randrange(-(1 << 19), 1 << 19) * 2 for _ in range(2000)]:
        insn = enc_j(imm, rng.getrandbits(12))
        got = await drive(dut, insn, IMM_J)
        check(got, u32(imm), insn, IMM_J)
        assert got & 1 == 0, f"J immediate bit 0 must be 0 (insn=0x{insn:08x})"


@cocotb.test()
async def test_raw_words_against_arithmetic_reference(dut):
    rng = random.Random(RNG_SEED + 5)
    words = [0, MASK32, 0x80000000, 0x7FFFFFFF, 0xAAAAAAAA, 0x55555555] + [rng.getrandbits(32) for _ in range(3000)]
    for insn in words:
        for kind in (IMM_I, IMM_S, IMM_B, IMM_U, IMM_J):
            check(await drive(dut, insn, kind), ref_imm(insn, kind), insn, kind)


# Hand-derived anchors from standard encodings. Cross-check them once with the real
# assembler before relying on them.
ANCHORS = [
    (0xFF010113, IMM_I, -16),         # addi sp,sp,-16
    (0x00112623, IMM_S, 12),          # sw ra,12(sp)
    (0xFE000EE3, IMM_B, -4),          # beq zero,zero,-4
    (0x123452B7, IMM_U, 0x12345000),  # lui t0,0x12345
    (0xFFDFF06F, IMM_J, -4),          # jal zero,-4
]


@cocotb.test()
async def test_known_encodings(dut):
    for insn, kind, expected in ANCHORS:
        check(await drive(dut, insn, kind), u32(expected), insn, kind)


@cocotb.test()
async def test_unused_types_give_zero(dut):
    rng = random.Random(RNG_SEED + 6)
    for kind in (5, 6, 7):
        for _ in range(50):
            insn = rng.getrandbits(32)
            check(await drive(dut, insn, kind), 0, insn, kind)
