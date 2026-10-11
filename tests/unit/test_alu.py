import random
import cocotb
from cocotb.triggers import Timer

# Keep in sync with rtl/rv32_pkg.sv
ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU = 0, 1, 2, 3, 4
ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND = 5, 6, 7, 8, 9
M32 = 0xFFFFFFFF


def s32(x):
    return x - (1 << 32) if x & 0x80000000 else x


REF = {
    ALU_ADD:  lambda a, b: (a + b) & M32,
    ALU_SUB:  lambda a, b: (a - b) & M32,
    ALU_SLL:  lambda a, b: (a << (b & 31)) & M32,
    ALU_SLT:  lambda a, b: int(s32(a) < s32(b)),
    ALU_SLTU: lambda a, b: int(a < b),
    ALU_XOR:  lambda a, b: a ^ b,
    ALU_SRL:  lambda a, b: a >> (b & 31),
    ALU_SRA:  lambda a, b: (s32(a) >> (b & 31)) & M32,
    ALU_OR:   lambda a, b: a | b,
    ALU_AND:  lambda a, b: a & b,
}

CORNERS = [0, 1, 2, 0x7FFFFFFF, 0x80000000, 0x80000001, 0xFFFFFFFF, 0x0000FFFF, 0xFFFF0000]


async def check(dut, op, a, b):
    dut.a.value = a
    dut.b.value = b
    dut.op.value = op
    await Timer(1, unit="ns")
    exp = REF[op](a, b) if op in REF else 0
    assert dut.result.value == exp, (
        f"op={op} a={a:#010x} b={b:#010x}: expected {exp:#010x}, got {dut.result.value}")


@cocotb.test()
async def corner_pairs_all_ops(dut):
    for op in REF:
        for a in CORNERS:
            for b in CORNERS:
                await check(dut, op, a, b)


@cocotb.test()
async def every_shift_amount(dut):
    for op in (ALU_SLL, ALU_SRL, ALU_SRA):
        for a in (0x80000001, 0x7FFFFFFE, 0xFFFFFFFF):
            for sh in range(32):
                await check(dut, op, a, sh)
                await check(dut, op, a, 0xABCDE000 | sh)  # upper bits of b must be ignored


@cocotb.test()
async def random_vectors(dut):
    rng = random.Random(12345)
    for op in REF:
        for _ in range(300):
            await check(dut, op, rng.getrandbits(32), rng.getrandbits(32))


@cocotb.test()
async def invalid_op_gives_zero(dut):
    for op in range(10, 16):
        await check(dut, op, 0x12345678, 0x9ABCDEF0)
