import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge


@cocotb.test()
async def counts_when_enabled(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Reset for one rising edge.
    dut.rst.value = 1
    dut.en.value = 0
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    assert dut.count.value == 0

    # Enable counting; sample at each falling edge (signals are stable there).
    dut.rst.value = 0
    dut.en.value = 1
    for expected in range(1, 6):
        await FallingEdge(dut.clk)
        assert dut.count.value == expected, f"expected {expected}, got {dut.count.value}"

    # Disable: the count must hold.
    dut.en.value = 0
    for _ in range(2):
        await FallingEdge(dut.clk)
        assert dut.count.value == 5
