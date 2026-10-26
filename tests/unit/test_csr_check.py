"""cocotb test for csr_check: legal CSR addresses per decision D4/D9, all 4096 addresses, both do_write values."""
import cocotb
from cocotb.triggers import Timer

IMPL = {0x300, 0x301, 0x304, 0x305, 0x310, 0x340, 0x341, 0x342, 0x343, 0x344, 0xF11, 0xF12, 0xF13, 0xF14, 0xF15}
RO = {0xF11, 0xF12, 0xF13, 0xF14, 0xF15}


@cocotb.test()
async def test_all_addresses(dut):
    for a in range(4096):
        for w in (0, 1):
            dut.addr.value = a
            dut.do_write.value = w
            await Timer(1, "ns")
            exp = int(a not in IMPL or (a in RO and w == 1))
            assert int(dut.illegal.value) == exp, f"addr 0x{a:03x} do_write={w}: illegal expected {exp}"
