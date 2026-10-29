"""System test: run one ELF on the RTL core (tb_top) and check the HTIF tohost result.

Env: ELF (path), MAX_INSTR (default 200000), TRACE_OUT (retire trace file).
The hex image is loaded by tb_top through +HEX (see scripts/run_core_elf.sh).
tohost is a 64-bit location written as two 32-bit stores; the exit code is value >> 1 when bit 0 is set.
"""
import os
import re
import subprocess

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge


def symbol(elf, name):
    out = subprocess.run(["riscv64-unknown-elf-nm", elf], capture_output=True, text=True, check=True).stdout
    for line in out.splitlines():
        p = line.split()
        if len(p) == 3 and p[2] == name:
            return int(p[0], 16)
    raise AssertionError(f"symbol {name} not found in {elf}")


def val(sig):
    return int(sig.value)


@cocotb.test()
async def run_elf(dut):
    elf = os.environ["ELF"]
    max_instr = int(os.environ.get("MAX_INSTR", "200000"))
    trace_path = os.environ.get("TRACE_OUT", "/tmp/core.trace")
    tohost = symbol(elf, "tohost")

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst.value = 0  # released right after a rising edge, so the first sample below is instruction 0

    seen = {}
    console = []
    retired = 0
    idle = 0
    with open(trace_path, "w") as trace:
        while retired < max_instr:
            await FallingEdge(dut.clk)  # signals are stable here; each cycle retires one instruction
            if val(dut.rvfi_valid) != 1:
                idle += 1
                if idle > 16:
                    raise AssertionError(f"core stopped retiring after {retired} instructions")
                continue
            idle = 0
            pc, insn = val(dut.rvfi_pc_rdata), val(dut.rvfi_insn)
            trace.write(
                f"{val(dut.rvfi_order):d} {pc:08x} {insn:08x} {val(dut.rvfi_pc_wdata):08x} {val(dut.rvfi_trap):d} "
                f"{val(dut.rvfi_rd_addr):02d} {val(dut.rvfi_rd_wdata):08x} {val(dut.rvfi_mem_addr):08x} "
                f"{val(dut.rvfi_mem_rmask):x} {val(dut.rvfi_mem_wmask):x} "
                f"{val(dut.rvfi_mem_rdata):08x} {val(dut.rvfi_mem_wdata):08x} {val(dut.rvfi_intr):d} "
                f"{val(dut.snap_mstatus):08x} {val(dut.snap_mie):08x} {val(dut.snap_mtvec):08x} {val(dut.snap_mscratch):08x} {val(dut.snap_mepc):08x} {val(dut.snap_mcause):08x} {val(dut.snap_mtval):08x}\n"
            )
            if val(dut.mem_oob):
                raise AssertionError(f"access outside RAM near instruction {retired} (pc=0x{pc:08x})")
            wmask = val(dut.rvfi_mem_wmask)
            if wmask:
                addr = val(dut.rvfi_mem_addr)
                if addr in (tohost, tohost + 4):
                    assert wmask == 0xF, f"partial store to tohost, wmask={wmask:x}"
                    seen[addr - tohost] = val(dut.rvfi_mem_wdata)
                    if addr == tohost + 4 and 0 in seen:
                        hi, lo = seen[4], seen[0]
                        if (hi >> 24) == 1 and ((hi >> 16) & 0xFF) == 1:  # HTIF device 1 (terminal), cmd 1 (putc)
                            console.append(chr(lo & 0xFF))
                            seen.clear()
            retired += 1
            if 0 in seen and 4 in seen:
                break
        else:
            raise AssertionError(f"timeout: no tohost result after {max_instr} instructions")

    value = (seen[4] << 32) | seen[0]
    text = "".join(console)
    summary = re.findall(r"RVCP-SUMMARY: TEST (PASSED|FAILED|SIGRUN)", text)
    dut._log.info(f"tohost = 0x{value:x} after {retired} instructions, RVCP-SUMMARY {summary}")
    if text:
        dut._log.info("console output:\n" + text)
    if summary:
        assert summary[0] == "PASSED", f"RVCP-SUMMARY reports {summary[0]}"
    assert value & 1, f"tohost 0x{value:x}: bit 0 not set, not an exit request"
    assert (value >> 1) == 0, f"test reported failure, exit code {value >> 1}"
