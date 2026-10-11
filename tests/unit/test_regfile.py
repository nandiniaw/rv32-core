import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer


async def setup(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.we.value = 0
    dut.waddr.value = 0
    dut.wdata.value = 0
    dut.raddr1.value = 0
    dut.raddr2.value = 0
    await FallingEdge(dut.clk)


async def write(dut, addr, data):
    dut.we.value = 1
    dut.waddr.value = addr
    dut.wdata.value = data
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.we.value = 0


async def read(dut, a1, a2=0):
    dut.raddr1.value = a1
    dut.raddr2.value = a2
    await Timer(1, unit="ns")
    return dut.rdata1.value, dut.rdata2.value


@cocotb.test()
async def write_then_read_both_ports(dut):
    await setup(dut)
    await write(dut, 5, 0xDEADBEEF)
    await write(dut, 6, 0x12345678)
    r1, r2 = await read(dut, 5, 6)
    assert r1 == 0xDEADBEEF, f"port1 got {r1}"
    assert r2 == 0x12345678, f"port2 got {r2}"
    r1, r2 = await read(dut, 6, 5)
    assert r1 == 0x12345678 and r2 == 0xDEADBEEF


@cocotb.test()
async def x0_reads_zero_and_ignores_writes(dut):
    await setup(dut)
    await write(dut, 0, 0xFFFFFFFF)
    r1, r2 = await read(dut, 0, 0)
    assert r1 == 0 and r2 == 0


@cocotb.test()
async def write_enable_low_does_not_write(dut):
    await setup(dut)
    await write(dut, 7, 0x11)
    dut.we.value = 0
    dut.waddr.value = 7
    dut.wdata.value = 0x22
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    r1, _ = await read(dut, 7)
    assert r1 == 0x11, f"we=0 changed x7 to {r1}"


@cocotb.test()
async def all_registers_independent(dut):
    await setup(dut)
    for i in range(1, 32):
        await write(dut, i, 0x01010101 * i)
    for i in range(1, 32):
        r1, r2 = await read(dut, i, 32 - i)
        assert r1 == (0x01010101 * i) & 0xFFFFFFFF, f"x{i} port1 got {r1}"
        assert r2 == (0x01010101 * (32 - i)) & 0xFFFFFFFF, f"x{32 - i} port2 got {r2}"


@cocotb.test()
async def read_during_write_sees_old_value(dut):
    """Documents the no-bypass decision: the new value appears only after the clock edge."""
    await setup(dut)
    await write(dut, 9, 0x1)
    dut.we.value = 1
    dut.waddr.value = 9
    dut.wdata.value = 0x2
    r1, _ = await read(dut, 9)
    assert r1 == 0x1, f"read-during-write returned {r1}, expected old value 1"
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    r1, _ = await read(dut, 9)
    assert r1 == 0x2
