# Bug log

## BUG-001 (tooling): `make -C smoke` could not find counter.sv
- Found by: scripts/regress.sh smoke check (make exit 2); logs/smoke.log showed "No rule to make target '/home/no_one/rv32-core/counter.sv'".
- Root cause: smoke/Makefile used $(PWD), which is the shell's directory. `make -C` changes make's directory, not $PWD.
- Fix: use $(CURDIR).
- Caught now by: scripts/regress.sh, which runs smoke from the repo root.

## Deliberate mutations (injected to prove tests catch bugs; not real bugs)

### MUT-001: ALU SRA implemented as logical shift
- Injected: rtl/alu.sv `$signed(a) >>> shamt` changed to `$signed(a) >> shamt`.
- Caught by: tests/unit/test_alu.py (3 of 4 tests failed), e.g. `op=7 a=0x80000000 b=0x00000001: expected 0xc0000000, got 0x40000000`.
- Restored with git checkout; unit tests pass again.

### MUT-002: B-type immediate bits [12] and [11] sourced from swapped instruction bits
- Injected: rtl/imm_gen.sv B case `{insn[31], insn[7], ...}` swapped to `{insn[7], insn[31], ...}` (scripts/mut002.sh).
- Caught by: tests/unit/test_imm_gen.py: test_b_roundtrip and test_raw_words_against_arithmetic_reference (TESTS=8 PASS=6 FAIL=2 on Verilator 5.052 / cocotb 2.1.0).
- Injected, not found.

### MUT-003: decoder selects SUB from funct7[4] instead of funct7[5]
- Injected: rtl/decoder.sv OP funct3=000 case (scripts/mutations.sh).
- Caught by: test_every_rv32i_instruction_from_assembler and test_reserved_encodings_and_illegal_side_effects.
- Injected, not found.

### MUT-004: decoder accepts reserved load funct3 = 011
- Injected: rtl/decoder.sv LOAD case (scripts/mutations.sh).
- Caught by: test_reserved_encodings_and_illegal_side_effects only. Shows why the reserved sweep exists.
- Injected, not found.

### MUT-005: BLT compares unsigned
- Injected: rtl/branch_cmp.sv `3'b100: taken = lt` changed to `taken = ltu` (scripts/mutations.sh).
- Caught by: all three tests in tests/unit/test_branch_cmp.py.
- Injected, not found.

### MUT-006: reserved funct3 (010/011) branches when operands are equal
- Injected: rtl/branch_cmp.sv default case changed from `taken = 0` to `taken = eq`.
- Caught by: test_corner_pairs_all_funct3 and test_equal_and_adjacent_values. NOT caught by test_random_pairs (random operands are almost never equal), so the directed equal-value tests are needed.
- Injected, not found.

### MUT-007: byte load sign-extends from bit 6 instead of bit 7
- Injected: rtl/lsu.sv (scripts/mutations.sh). Caught by: test_load_selection_and_extension only.
- Injected, not found.

### MUT-008: half-word store/load mask lanes swapped between low and high half
- Injected: rtl/lsu.sv (scripts/mutations.sh). Caught by: test_store_lanes_and_resulting_memory and test_load_selection_and_extension.
- Injected, not found.

### MUT-009: word access at offset 1 not flagged misaligned (check looks only at addr bit 1)
- Injected: rtl/lsu.sv (scripts/mutations.sh). Caught by: test_store_lanes_and_resulting_memory and test_load_selection_and_extension.
- Injected, not found.

### CMUT-001: core byte load sign-extends from bit 6 instead of bit 7
- Injected: rtl/lsu.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on build/ls_edge.elf (rd write mismatch).
- Injected, not found.

### CMUT-002: JAL/JALR link value is pc+8 instead of pc+4
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on build/rv32ui/jal.elf (rd write mismatch).
- Injected, not found.

### CMUT-003: half-word store lane mask swapped between low and high half
- Injected: rtl/lsu.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on build/rv32ui/sh.elf (store mismatch).
- Injected, not found.

### CMUT-004: MEM->EX forwarding disabled for rs1
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on 41 of 41 ELFs (run via cosim_mut_all.sh).
- Injected, not found.

### CMUT-005: WB->EX forwarding disabled for rs2
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on 10 of 41 ELFs (and, ld_st, sb, sh, sll, sra, srl, sw, xor, ls_edge).
- Injected, not found.

### CMUT-006: load-use stall disabled
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on 6 of 41 ELFs (load tests only).
- Injected, not found.

### CMUT-007: WB->ID register-file bypass disabled for rs1
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on 34 of 41 ELFs.
- Injected, not found.

### CMUT-008: instruction in ID not squashed on a taken branch/jump
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on 39 of 41 ELFs.
- Injected, not found.

### CMUT-009: store data not forwarded (uses the value read in ID)
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on 6 of 41 ELFs (ld_st, sb, sh, st_ld, sw, ls_edge).
- Injected, not found.

### CMUT-010: MEM->EX forwarding to rs2 also forwards writes to x0
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on build/haz.elf.
- Injected, not found.

### CMUT-011: older writer (WB) wins over younger writer (MEM) when both match rs1
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on build/haz.elf.
- Injected, not found.

### CMUT-012: load-use stall ignores rs2
- Injected: rtl/core.sv (scripts/core_mutations.sh). Caught by: cosim RTL vs Sail on build/haz.elf.
- Injected, not found.

## Formal sensitivity: core mutants through riscv-formal (injected, not found)
Same patterns as scripts/core_mutations.sh, applied to a copy of rtl/ and run through formal/full.cfg (formal/formal_mutations.sh, 13m53s).
CAUGHT means at least one check reported FAIL.
| Mutant | Failing checks (formal) | Time |
|---|---|---|
| CMUT-001 | insn_lb | 78 s |
| CMUT-002 | insn_jal, insn_jalr | 91 s |
| CMUT-003 | insn_lh, insn_lhu, insn_sh | 83 s |
| CMUT-004 | reg | 66 s |
| CMUT-005 | reg | 60 s |
| CMUT-006 | reg | 60 s |
| CMUT-007 | reg | 61 s |
| CMUT-008 | pc_fwd | 71 s |
| CMUT-009 | 16 insn checks (alu register ops, branches) + reg | 65 s |
| CMUT-010 | all 37 insn checks + reg | 84 s |
| CMUT-011 | reg | 58 s |
| CMUT-012 | reg | 56 s |
Counterexample inspected for CMUT-008 only (formal/vcd_table.py on pc_fwd_ch0/engine_0/trace.vcd): a taken bne (0xf70a94e3) at 0x80000014 retires with pc_wdata 0x7fffff7c, then the wrong-path sb (0x7d180823) at 0x80000018 (branch pc + 4) retires next, so pc_fwd fails. That is the intended failure: the instruction behind a taken branch is not squashed. The other 11 traces were not inspected.
