"""cocotb tests for sys_decoder (SYSTEM 0x73 and MISC-MEM 0x0F). Words come from the real assembler."""
import os, subprocess, tempfile
import cocotb
from cocotb.triggers import Timer

OUTS = ["is_csr", "csr_write", "csr_imm", "is_ecall", "is_ebreak", "is_mret", "is_fence", "valid"]


def assemble(lines):
    src = ".option norvc\n" + "\n".join(lines) + "\n"
    with tempfile.TemporaryDirectory() as d:
        s, o, b = (os.path.join(d, n) for n in ("a.s", "a.o", "a.bin"))
        open(s, "w").write(src)
        subprocess.run(["riscv64-unknown-elf-as", "-march=rv32i_zicsr", "-mabi=ilp32", s, "-o", o], check=True)
        subprocess.run(["riscv64-unknown-elf-objcopy", "-O", "binary", "-j", ".text", o, b], check=True)
        data = open(b, "rb").read()
    return [int.from_bytes(data[k:k + 4], "little") for k in range(0, 4 * len(lines), 4)]


async def dec(dut, word):
    dut.insn.value = word
    await Timer(1, "ns")
    return {f: int(getattr(dut, f).value) for f in OUTS}


# name, asm, expected dict (unlisted outputs must be 0)
CASES = [
    ("csrrw", "csrrw x5, mscratch, x6", dict(valid=1, is_csr=1, csr_write=1)),
    ("csrrs", "csrrs x5, mscratch, x6", dict(valid=1, is_csr=1, csr_write=1)),
    ("csrrc", "csrrc x5, mscratch, x6", dict(valid=1, is_csr=1, csr_write=1)),
    ("csrrs-x0 (read only)", "csrrs x5, mscratch, x0", dict(valid=1, is_csr=1, csr_write=0)),
    ("csrrc-x0 (read only)", "csrrc x5, mscratch, x0", dict(valid=1, is_csr=1, csr_write=0)),
    ("csrrw-x0 still writes", "csrrw x5, mscratch, x0", dict(valid=1, is_csr=1, csr_write=1)),
    ("csrrwi", "csrrwi x5, mscratch, 3", dict(valid=1, is_csr=1, csr_imm=1, csr_write=1)),
    ("csrrsi uimm=0 (read only)", "csrrsi x5, mscratch, 0", dict(valid=1, is_csr=1, csr_imm=1, csr_write=0)),
    ("csrrci uimm=3", "csrrci x5, mscratch, 3", dict(valid=1, is_csr=1, csr_imm=1, csr_write=1)),
    ("ecall", "ecall", dict(valid=1, is_ecall=1)),
    ("ebreak", "ebreak", dict(valid=1, is_ebreak=1)),
    ("mret", "mret", dict(valid=1, is_mret=1)),
    ("fence", "fence", dict(valid=1, is_fence=1)),
]


@cocotb.test()
async def test_system_instructions_from_assembler(dut):
    words = assemble([a for _, a, _ in CASES])
    for (name, asm, exp), w in zip(CASES, words):
        got = await dec(dut, w)
        for f in OUTS:
            assert got[f] == exp.get(f, 0), f"{name} (0x{w:08x}): {f} expected {exp.get(f, 0)}, got {got[f]}"


@cocotb.test()
async def test_not_valid_outside_system_and_fence(dut):
    base = assemble(["add x5,x6,x7", "lw x5,0(x6)", "jal x1,.", "lui x5,1"])
    for w in base:
        got = await dec(dut, w)
        assert got["valid"] == 0, f"0x{w:08x} must not be a SYSTEM/FENCE instruction"


@cocotb.test()
async def test_reserved_system_encodings_invalid(dut):
    ecall = assemble(["ecall"])[0]
    mret = assemble(["mret"])[0]
    bad = [
        ecall | (5 << 7),             # ecall with rd != 0
        ecall | (5 << 15),            # ecall with rs1 != 0
        ecall | (0x105 << 20),        # wfi encoding: not supported here
        mret | (5 << 7),              # mret with rd != 0
        (0x73 | (4 << 12)),           # SYSTEM funct3 = 4 is reserved
        (0x73 | (4 << 12) | (0x340 << 20)),
    ]
    for w in bad:
        got = await dec(dut, w)
        assert got["valid"] == 0, f"reserved SYSTEM word 0x{w:08x} accepted"
