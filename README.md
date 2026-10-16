# RV32I 5-stage core (work in progress)

Portfolio project: 5-stage in-order RV32I (+Zicsr M-mode) core in SystemVerilog, verified with Verilator + cocotb against the Sail RISC-V reference model.

## AI assistance
Design guidance, RTL drafts, scripts and tests are written with an AI assistant (Claude) and reviewed by the author. AI-written RTL and tests are treated as unverified until they pass an independent oracle (Sail comparison, riscv-tests, ACT4, formal).

## Status
Phase 2 complete (single-cycle core): all 40 rv32ui ELFs match Sail instruction by instruction (pc, insn, next pc, rd, loads, stores), plus ls_edge. Comparator self-tested; core mutants CMUT-001..003 caught (see bugs.md). Pipeline, CSRs and traps not started. No performance results yet.

## Known deviations (to keep honest)
- rv32ui tests run with a custom CSR-free `sw/env/riscv_test.h`, not the stock `env/p` startup. `fence_i` and `ma_data` are skipped.
- Compiler is GCC 16.1.0 / binutils 2.47 (ACT4 officially tests GCC 15 / binutils 2.44).
- Test memory is 16 KiB at 0x80000000 (largest rv32ui extent seen: 0x80002050).
- Cosim covers only what rv32ui and ls_edge exercise: traps, CSR activity and misaligned accesses are rejected or unmodelled by the comparator. Only 3 core-level mutants so far; the last instruction's next pc is not checked.

## Reproduce
`./scripts/versions.sh`, `./scripts/regress.sh`, `./scripts/unit.sh`. Versions are in `versions.txt`.
