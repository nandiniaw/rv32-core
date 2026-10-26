"""cocotb tests for csr_file (Phase 4 step A). Expected values come from docs/sail_csr_behaviour.md (measured on Sail 0.15)
and decisions D8/D9. op: 1=write, 2=set, 3=clear. do_write=0 models csrrs/csrrc with rs1=x0 (read only)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

MSTATUS, MISA, MIE, MTVEC, MSCRATCH, MEPC, MCAUSE, MTVAL, MIP, MSTATUSH = 0x300, 0x301, 0x304, 0x305, 0x340, 0x341, 0x342, 0x343, 0x344, 0x310
SNAPS = ["mstatus", "mie", "mtvec", "mscratch", "mepc", "mcause", "mtval"]


async def setup(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.en.value = 0; dut.addr.value = 0; dut.op.value = 1; dut.src.value = 0; dut.do_write.value = 0
    dut.rst.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.rst.value = 0


async def access(dut, addr, op, src, do_write=1):
    dut.addr.value, dut.op.value, dut.src.value, dut.do_write.value, dut.en.value = addr, op, src, do_write, 1
    await Timer(1, "ns")
    rd, ill = int(dut.rdata.value), int(dut.illegal.value)
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.en.value = 0
    return rd, ill


async def rd(dut, addr):
    r, ill = await access(dut, addr, 2, 0, 0)
    assert ill == 0, f"read of 0x{addr:03x} flagged illegal"
    return r


@cocotb.test()
async def test_reset_and_constants(dut):
    await setup(dut)
    for n in SNAPS:
        assert int(getattr(dut, "snap_" + n).value) == 0, f"snap_{n} not 0 at reset"
    assert await rd(dut, MISA) == 0x40000100
    assert await rd(dut, MIP) == 0x80
    assert await rd(dut, MSTATUSH) == 0
    for a in range(0xF11, 0xF16):
        assert await rd(dut, a) == 0


@cocotb.test()
async def test_ignored_writes(dut):
    await setup(dut)
    for a in (MISA, MIP, MSTATUSH):
        _, ill = await access(dut, a, 1, 0xFFFFFFFF)
        assert ill == 0, f"write to 0x{a:03x} must not trap"
    assert await rd(dut, MISA) == 0x40000100
    assert await rd(dut, MIP) == 0x80
    assert await rd(dut, MSTATUSH) == 0


@cocotb.test()
async def test_mscratch_mtval_set_clear(dut):
    await setup(dut)
    for a in (MSCRATCH, MTVAL):
        await access(dut, a, 1, 0xF0)
        old, _ = await access(dut, a, 2, 0x0F)
        assert old == 0xF0
        assert await rd(dut, a) == 0xFF
        await access(dut, a, 3, 0xF0)
        assert await rd(dut, a) == 0x0F
        await access(dut, a, 2, 0xFFFFFFFF, 0)       # read only: no write
        assert await rd(dut, a) == 0x0F


@cocotb.test()
async def test_mepc_mie(dut):
    await setup(dut)
    await access(dut, MEPC, 1, 0xFFFFFFFF)
    assert await rd(dut, MEPC) == 0xFFFFFFFC
    await access(dut, MIE, 1, 0xFFFFFFFF)
    assert await rd(dut, MIE) == 0x888


@cocotb.test()
async def test_mtvec(dut):
    await setup(dut)
    await access(dut, MTVEC, 1, 0x80000011)
    assert await rd(dut, MTVEC) == 0x80000011            # measured: mode 1 accepted, bit 4 kept
    await access(dut, MTVEC, 1, 0xFFFFFFFF)              # reserved mode 3: keep old mode (1)
    assert await rd(dut, MTVEC) == 0xFFFFFFFD
    await access(dut, MTVEC, 1, 0x80000100)              # mode 0
    await access(dut, MTVEC, 1, 0xFFFFFFFF)              # reserved mode: keep mode 0 (measured 0xFFFFFFFC)
    assert await rd(dut, MTVEC) == 0xFFFFFFFC


@cocotb.test()
async def test_mstatus(dut):
    await setup(dut)
    assert await rd(dut, MSTATUS) == 0                   # reset value 0 (measured)
    await access(dut, MSTATUS, 1, 0)
    assert await rd(dut, MSTATUS) == 0x1800              # MPP reads 3 after the first write
    await access(dut, MSTATUS, 1, 0xFFFFFFFF)
    assert await rd(dut, MSTATUS) == 0x1888
    await access(dut, MSTATUS, 1, 0x80)
    assert await rd(dut, MSTATUS) == 0x1880
    await access(dut, MSTATUS, 3, 0x80)                  # csrrc clears MPIE
    assert await rd(dut, MSTATUS) == 0x1800


@cocotb.test()
async def test_mcause_rule_D8(dut):
    await setup(dut)
    accepted = list(range(10)) + [0xB, 0xC, 0xD, 0xF, 0x13] + [0x80000000 | c for c in (1, 3, 5, 7, 9, 0xB)]
    rejected = [0xA, 0xE, 0x10, 0x11, 0x12, 0x14, 0x3F, 0x40, 0x80, 0x100, 0x7FFFFFFF, 0xFFFFFFFF,
                0x80000000, 0x80000002, 0x80000004, 0x8000000D]   # last four: Sail source reading (legalize_cause), not all measured
    for v in accepted:
        await access(dut, MCAUSE, 1, v)
        assert await rd(dut, MCAUSE) == v, f"mcause 0x{v:x} should be accepted"
    for v in rejected:
        await access(dut, MCAUSE, 1, 0xB)
        await access(dut, MCAUSE, 1, v)
        assert await rd(dut, MCAUSE) == 0xB, f"mcause 0x{v:x} should be ignored"


@cocotb.test()
async def test_illegal_accesses(dut):
    await setup(dut)
    for a in (0x000, 0x3A0, 0xB00, 0x7C0, 0x320, 0xC00, 0x100):
        _, ill = await access(dut, a, 2, 0, 0)
        assert ill == 1, f"read of unimplemented CSR 0x{a:03x} must be illegal (D4)"
    for a in range(0xF11, 0xF16):
        _, ill = await access(dut, a, 1, 5)
        assert ill == 1, f"write to read-only 0x{a:03x} must be illegal"
    before = [int(getattr(dut, "snap_" + n).value) for n in SNAPS]
    await access(dut, 0x3A0, 1, 0xFFFFFFFF)              # illegal access must not write anything
    assert before == [int(getattr(dut, "snap_" + n).value) for n in SNAPS]


async def trap(dut, pc, cause, tval):
    dut.trap_en.value, dut.trap_pc.value, dut.trap_cause.value, dut.trap_tval.value = 1, pc, cause, tval
    await Timer(1, "ns")
    snap = {n: int(getattr(dut, "snap_" + n).value) for n in SNAPS}   # post-trap state, before the clock edge
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.trap_en.value = 0
    return snap


@cocotb.test()
async def test_trap_entry(dut):
    await setup(dut)
    dut.trap_en.value = 0
    # MIE = 0 at reset: Sail ecall probe gives mstatus 0x1800
    s = await trap(dut, 0x80000024, 0xB, 0)
    assert s["mstatus"] == 0x1800 and s["mepc"] == 0x80000024 and s["mcause"] == 0xB and s["mtval"] == 0
    assert await rd(dut, MEPC) == 0x80000024 and await rd(dut, MCAUSE) == 0xB
    assert await rd(dut, MSTATUS) == 0x1800
    # MIE = 1: MPIE <- 1, MIE <- 0, MPP = 3
    await access(dut, MSTATUS, 2, 0x8)
    s = await trap(dut, 0x80000100, 0x2, 0xFFFFFFFF)
    assert s["mstatus"] == 0x1880 and s["mtval"] == 0xFFFFFFFF and s["mepc"] == 0x80000100
    assert await rd(dut, MSTATUS) == 0x1880


@cocotb.test()
async def test_mret(dut):
    await setup(dut)
    dut.trap_en.value = 0
    dut.mret_en.value = 0
    await access(dut, MEPC, 1, 0x80000028)
    await access(dut, MSTATUS, 2, 0x8)             # MIE = 1
    await trap(dut, 0x80000024, 0xB, 0)            # MPIE <- 1, MIE <- 0
    assert await rd(dut, MSTATUS) == 0x1880
    await access(dut, MSTATUS, 3, 0x80)            # clear MPIE
    assert await rd(dut, MSTATUS) == 0x1800
    dut.mret_en.value = 1
    await Timer(1, "ns")
    assert int(dut.snap_mstatus.value) == 0x1880   # MIE <- MPIE (0), MPIE <- 1, MPP stays 3
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.mret_en.value = 0
    assert await rd(dut, MSTATUS) == 0x1880
