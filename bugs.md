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
- Caught by: tests/unit/test_imm_gen.py (2 tests failed in the first run on the pinned stack; the test names are in /tmp/mut002.log).
- Injected, not found.

### MUT-002: B-type immediate bits [12] and [11] sourced from swapped instruction bits
- Injected: rtl/imm_gen.sv B case `{insn[31], insn[7], ...}` swapped to `{insn[7], insn[31], ...}` (scripts/mut002.sh).
- Caught by: tests/unit/test_imm_gen.py: test_b_roundtrip and test_raw_words_against_arithmetic_reference (TESTS=8 PASS=6 FAIL=2 on Verilator 5.052 / cocotb 2.1.0).
- Injected, not found.
