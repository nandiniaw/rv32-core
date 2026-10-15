"""cocotb tests for lsu.

The reference models memory as a 4-byte little-endian array and uses Python slicing, so it is
built differently from the RTL's lane muxing.
"""
import random

import cocotb
from cocotb.triggers import Timer

M32 = 0xFFFFFFFF
NBYTES = {0: 1, 1: 2, 2: 4}   # funct3[1:0] -> access size in bytes
CORNERS = [0, M32, 0x80, 0x7F, 0x8000, 0x7FFF, 0x80808080, 0x7F7F7F7F,
           0x12345678, 0xDEADBEEF, 0xFF00FF00, 0x00FF00FF]


def sext(value, bits):
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def words(rng, n):
    return CORNERS + [rng.getrandbits(32) for _ in range(n)]


async def drive(dut, f3, lo, is_load, is_store, store_data=0, mem_rdata=0):
    dut.funct3.value = f3
    dut.addr_lo.value = lo
    dut.is_load.value = is_load
    dut.is_store.value = is_store
    dut.store_data.value = store_data
    dut.mem_rdata.value = mem_rdata
    await Timer(1, "ns")
    return {k: int(getattr(dut, k).value) for k in ("mask", "mem_wdata", "load_data", "misaligned")}


@cocotb.test()
async def test_store_lanes_and_resulting_memory(dut):
    rng = random.Random(20261014)
    for f3 in (0, 1, 2):
        n = NBYTES[f3]
        for lo in range(4):
            for sdata in words(rng, 40):
                old = rng.getrandbits(32)
                got = await drive(dut, f3, lo, 0, 1, store_data=sdata)
                tag = f"store f3={f3} lo={lo} data=0x{sdata:08x}"
                if lo % n:
                    assert got["misaligned"] == 1, f"{tag}: misaligned flag not set"
                    assert got["mask"] == 0 and got["mem_wdata"] == 0, f"{tag}: misaligned store not inert"
                    continue
                assert got["misaligned"] == 0, f"{tag}: aligned store flagged misaligned"
                exp_mask = ((1 << n) - 1) << lo
                assert got["mask"] == exp_mask, f"{tag}: mask expected {exp_mask:04b}, got {got['mask']:04b}"
                mem = bytearray(old.to_bytes(4, "little"))
                mem[lo:lo + n] = (sdata & ((1 << (8 * n)) - 1)).to_bytes(n, "little")
                lanes = 0
                for i in range(4):
                    if got["mask"] & (1 << i):
                        lanes |= 0xFF << (8 * i)
                merged = (old & ~lanes & M32) | (got["mem_wdata"] & lanes)
                assert merged == int.from_bytes(mem, "little"), (
                    f"{tag}: memory would hold 0x{merged:08x}, expected 0x{int.from_bytes(mem, 'little'):08x}")
                assert got["mem_wdata"] & ~lanes & M32 == 0, f"{tag}: unused lanes are not zero"


@cocotb.test()
async def test_load_selection_and_extension(dut):
    rng = random.Random(20261015)
    for f3 in (0, 1, 2, 4, 5):
        n = NBYTES[f3 & 3]
        unsigned = bool(f3 & 4)
        for lo in range(4):
            for rdata in words(rng, 40):
                got = await drive(dut, f3, lo, 1, 0, mem_rdata=rdata)
                tag = f"load f3={f3} lo={lo} word=0x{rdata:08x}"
                if lo % n:
                    assert got["misaligned"] == 1, f"{tag}: misaligned flag not set"
                    assert got["mask"] == 0 and got["load_data"] == 0, f"{tag}: misaligned load not inert"
                    continue
                assert got["misaligned"] == 0, f"{tag}: aligned load flagged misaligned"
                exp_mask = ((1 << n) - 1) << lo
                assert got["mask"] == exp_mask, f"{tag}: mask expected {exp_mask:04b}, got {got['mask']:04b}"
                raw = int.from_bytes(rdata.to_bytes(4, "little")[lo:lo + n], "little")
                exp = raw if (unsigned or n == 4) else sext(raw, 8 * n) & M32
                assert got["load_data"] == exp, f"{tag}: expected 0x{exp:08x}, got 0x{got['load_data']:08x}"


@cocotb.test()
async def test_no_memory_op_means_no_misaligned_flag(dut):
    for f3 in range(8):
        for lo in range(4):
            got = await drive(dut, f3, lo, 0, 0)
            assert got["misaligned"] == 0, f"f3={f3} lo={lo}: flagged misaligned with no load or store"


@cocotb.test()
async def test_invalid_size_is_inert(dut):
    for f3 in (3, 7):
        for lo in range(4):
            for is_load, is_store in ((1, 0), (0, 1)):
                got = await drive(dut, f3, lo, is_load, is_store, store_data=M32, mem_rdata=M32)
                assert got["mask"] == 0 and got["mem_wdata"] == 0 and got["load_data"] == 0, (
                    f"f3={f3} lo={lo}: invalid size not inert: {got}")
                assert got["misaligned"] == 0, f"f3={f3} lo={lo}: invalid size flagged misaligned"
