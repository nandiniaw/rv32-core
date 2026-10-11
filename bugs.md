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
