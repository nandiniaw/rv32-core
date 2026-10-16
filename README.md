# RV32I 5-stage core (work in progress)

Portfolio project: 5-stage in-order RV32I (+Zicsr M-mode) core in SystemVerilog, verified with Verilator + cocotb against the Sail RISC-V reference model.

## AI assistance
Design guidance, RTL drafts, scripts and tests are written with an AI assistant (Claude) and reviewed by the author. AI-written RTL and tests are treated as unverified until they pass an independent oracle (Sail comparison, riscv-tests, ACT4, formal).

## Status
Phase 3 complete (5-stage pipeline: WB->ID bypass, EX forwarding from MEM/WB, one-cycle load-use stall, branch/jump resolved in EX). All 40 rv32ui ELFs, ls_edge and the directed hazard test haz.S match Sail instruction by instruction (pc, insn, next pc, rd, loads, stores). 12 core-level mutants (CMUT-001..012, see bugs.md) are caught by the cosim. CSRs, traps and performance results are not done yet.

## Known deviations (to keep honest)
- rv32ui tests run with a custom CSR-free `sw/env/riscv_test.h`, not the stock `env/p` startup. `fence_i` and `ma_data` are skipped.
- Compiler is GCC 16.1.0 / binutils 2.47 (ACT4 officially tests GCC 15 / binutils 2.44).
- Test memory is 16 KiB at 0x80000000 (largest rv32ui extent seen: 0x80002050).
- Memory is ideal: combinational instruction and data reads, so there is no memory wait state. A real SRAM or cache interface is not modelled.
- The load-use stall is conservative (it matches rs1/rs2 instruction fields even when the instruction does not use them), so some stalls are unnecessary. Correctness is not affected.
- Traps are a placeholder: a trapping instruction retires once with trap/halt set and the core stops; the cosim rejects traps.
- Cosim covers only what rv32ui, ls_edge and haz exercise: traps, CSR activity and misaligned accesses are rejected or unmodelled by the comparator. 12 core-level mutants so far; the last instruction's next pc is not checked. No coverage percentages are measured.

## Reproduce
`./scripts/versions.sh`, `./scripts/regress.sh`, `./scripts/unit.sh`. Versions are in `versions.txt`.
