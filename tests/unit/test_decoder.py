"""cocotb tests for decoder.

Positive checks use words produced by the real assembler, so the opcode/funct fields do not
come from this file. The reserved-encoding sweep uses a hand-written rule table (same author
as the RTL), so Sail comparison later is what cross-checks it.
"""
import os
import subprocess
import tempfile

import cocotb
from cocotb.triggers import Timer

# Keep in sync with rtl/rv32_pkg.sv
(ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
 ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND) = range(10)
A_RS1, A_PC, A_ZERO = 0, 1, 2
WB_ALU, WB_MEM, WB_PC4 = 0, 1, 2
IMM_I, IMM_S, IMM_B, IMM_U, IMM_J = range(5)
OPC_LUI, OPC_AUIPC, OPC_JAL, OPC_JALR = 0x37, 0x17, 0x6F, 0x67
OPC_BRANCH, OPC_LOAD, OPC_STORE, OPC_OP_IMM, OPC_OP = 0x63, 0x03, 0x23, 0x13, 0x33

CTRL_FIELDS = ["alu_op", "a_sel", "b_sel_imm", "imm_type", "reg_we", "wb_sel",
               "mem_re", "mem_we", "is_branch", "is_jal", "is_jalr"]
SIDE_EFFECTS = ["reg_we", "mem_re", "mem_we", "is_branch", "is_jal", "is_jalr"]


def r_type(op):
    return (op, A_RS1, 0, None, 1, WB_ALU, 0, 0, 0, 0, 0)


def i_type(op):
    return (op, A_RS1, 1, IMM_I, 1, WB_ALU, 0, 0, 0, 0, 0)


LOAD = (ALU_ADD, A_RS1, 1, IMM_I, 1, WB_MEM, 1, 0, 0, 0, 0)
STORE = (ALU_ADD, A_RS1, 1, IMM_S, 0, None, 0, 1, 0, 0, 0)
BRANCH = (None, None, None, IMM_B, 0, None, 0, 0, 1, 0, 0)

PROGRAM = []  # (mnemonic, assembly line, expected control tuple; None = don't care)
for m, op in [("add", ALU_ADD), ("sub", ALU_SUB), ("sll", ALU_SLL), ("slt", ALU_SLT),
              ("sltu", ALU_SLTU), ("xor", ALU_XOR), ("srl", ALU_SRL), ("sra", ALU_SRA),
              ("or", ALU_OR), ("and", ALU_AND)]:
    PROGRAM.append((m, f"{m} x5,x6,x7", r_type(op)))
for m, op in [("addi", ALU_ADD), ("slti", ALU_SLT), ("sltiu", ALU_SLTU),
              ("xori", ALU_XOR), ("ori", ALU_OR), ("andi", ALU_AND)]:
    PROGRAM.append((m, f"{m} x5,x6,-9", i_type(op)))
PROGRAM.append(("addi-pos", "addi x5,x6,9", i_type(ALU_ADD)))
for m, op in [("slli", ALU_SLL), ("srli", ALU_SRL), ("srai", ALU_SRA)]:
    PROGRAM.append((m, f"{m} x5,x6,3", i_type(op)))
for m in ["lb", "lh", "lw", "lbu", "lhu"]:
    PROGRAM.append((m, f"{m} x5,8(x6)", LOAD))
for m in ["sb", "sh", "sw"]:
    PROGRAM.append((m, f"{m} x7,8(x6)", STORE))
for m in ["beq", "bne", "blt", "bge", "bltu", "bgeu"]:
    PROGRAM.append((m, f"{m} x5,x6,end", BRANCH))
PROGRAM.append(("jal", "jal x1,end", (None, None, None, IMM_J, 1, WB_PC4, 0, 0, 0, 1, 0)))
PROGRAM.append(("jalr", "jalr x1,8(x6)", (ALU_ADD, A_RS1, 1, IMM_I, 1, WB_PC4, 0, 0, 0, 0, 1)))
PROGRAM.append(("lui", "lui x5,0x12345", (ALU_ADD, A_ZERO, 1, IMM_U, 1, WB_ALU, 0, 0, 0, 0, 0)))
PROGRAM.append(("auipc", "auipc x5,0x12345", (ALU_ADD, A_PC, 1, IMM_U, 1, WB_ALU, 0, 0, 0, 0, 0)))


def assemble(lines):
    src = ".option norvc\n" + "\n".join(lines) + "\nend: nop\n"
    with tempfile.TemporaryDirectory() as d:
        s, o, b = (os.path.join(d, n) for n in ("a.s", "a.o", "a.bin"))
        with open(s, "w") as f:
            f.write(src)
        subprocess.run(["riscv64-unknown-elf-as", "-march=rv32i", "-mabi=ilp32", s, "-o", o], check=True)
        subprocess.run(["riscv64-unknown-elf-objcopy", "-O", "binary", "-j", ".text", o, b], check=True)
        with open(b, "rb") as f:
            data = f.read()
    return [int.from_bytes(data[k:k + 4], "little") for k in range(0, 4 * len(lines), 4)]


async def decode(dut, opcode, funct3, funct7):
    dut.opcode.value = opcode
    dut.funct3.value = funct3
    dut.funct7.value = funct7
    await Timer(1, "ns")
    return {f: int(getattr(dut, f).value) for f in CTRL_FIELDS + ["illegal"]}


async def decode_word(dut, word):
    return await decode(dut, word & 0x7F, (word >> 12) & 7, (word >> 25) & 0x7F)


@cocotb.test()
async def test_every_rv32i_instruction_from_assembler(dut):
    words = assemble([asm for _, asm, _ in PROGRAM])
    for (name, asm, expected), word in zip(PROGRAM, words):
        got = await decode_word(dut, word)
        assert got["illegal"] == 0, f"{name} ({asm}, 0x{word:08x}) flagged illegal"
        for field, exp in zip(CTRL_FIELDS, expected):
            if exp is not None:
                assert got[field] == exp, (
                    f"{name} ({asm}, 0x{word:08x}): {field} expected {exp}, got {got[field]}")


@cocotb.test()
async def test_fence_ecall_ebreak_are_illegal_for_now(dut):
    names = ["fence", "ecall", "ebreak"]
    for name, word in zip(names, assemble(names)):
        got = await decode_word(dut, word)
        assert got["illegal"] == 1, f"{name} (0x{word:08x}) should be illegal until Phase 4"


def ref_illegal(opcode, f3, f7):
    if opcode in (OPC_LUI, OPC_AUIPC, OPC_JAL):
        return False
    if opcode == OPC_JALR:
        return f3 != 0
    if opcode == OPC_BRANCH:
        return f3 in (2, 3)
    if opcode == OPC_LOAD:
        return f3 not in (0, 1, 2, 4, 5)
    if opcode == OPC_STORE:
        return f3 not in (0, 1, 2)
    if opcode == OPC_OP_IMM:
        if f3 == 1:
            return f7 != 0x00
        if f3 == 5:
            return f7 not in (0x00, 0x20)
        return False
    if opcode == OPC_OP:
        if f3 in (0, 5):
            return f7 not in (0x00, 0x20)
        return f7 != 0x00
    return True


def ref_alu(opcode, f3, f7):
    if f3 == 0:
        return ALU_SUB if (opcode == OPC_OP and f7 == 0x20) else ALU_ADD
    return {1: ALU_SLL, 2: ALU_SLT, 3: ALU_SLTU, 4: ALU_XOR,
            5: ALU_SRA if f7 == 0x20 else ALU_SRL, 6: ALU_OR, 7: ALU_AND}[f3]


async def check_encoding(dut, opcode, f3, f7):
    got = await decode(dut, opcode, f3, f7)
    tag = f"opcode=0x{opcode:02x} funct3={f3} funct7=0x{f7:02x}"
    exp_illegal = ref_illegal(opcode, f3, f7)
    assert got["illegal"] == int(exp_illegal), f"{tag}: illegal expected {int(exp_illegal)}, got {got['illegal']}"
    if exp_illegal:
        for field in SIDE_EFFECTS:
            assert got[field] == 0, f"{tag}: illegal instruction has {field}={got[field]}"
    elif opcode in (OPC_OP, OPC_OP_IMM):
        assert got["alu_op"] == ref_alu(opcode, f3, f7), (
            f"{tag}: alu_op expected {ref_alu(opcode, f3, f7)}, got {got['alu_op']}")


F7_SET = [0x00, 0x20, 0x01, 0x40, 0x7F, 0x02, 0x10, 0x21]


@cocotb.test()
async def test_reserved_encodings_and_illegal_side_effects(dut):
    for opcode in range(128):
        for f3 in range(8):
            for f7 in F7_SET:
                await check_encoding(dut, opcode, f3, f7)
    for opcode in (OPC_OP, OPC_OP_IMM):
        for f3 in range(8):
            for f7 in range(128):
                await check_encoding(dut, opcode, f3, f7)
