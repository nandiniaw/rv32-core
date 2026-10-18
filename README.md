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

## Formal verification (bounded)
- Tools: riscv-formal @ c992aa6, Yosys 0.70+145 from OSS CAD Suite 2026-10-16, SymbiYosys with smtbmc/boolector.
- Run: `./formal/run.sh full 3`. Config `formal/full.cfg`: isa rv32i, insn/ill depth 12, reg/pc_fwd/pc_bwd/causal 1 reset cycle then depth 15,
  unique/liveness 1/8/15. 45 checks generated; all PASS, i.e. no counterexample within that bound (one run, 1m12s wall time).
  This is bounded model checking, not an unbounded proof.
- Deviation: Yosys's native frontend rejects SystemVerilog package imports, so formal runs on a derived copy of rtl/ with the package constants
  inlined. `formal/check_derived.py` checks each derived file equals rtl/ apart from those constants.
- Reset length: `formal/reset5.cfg` (5 reset cycles; reg/pc_fwd/pc_bwd/causal/cover depth 19; unique/liveness 5/12/19): 45 checks, all PASS within the bound. Only reset lengths 1 and 5 were tried. `formal/run.sh <cfg> 3 45` fails if fewer checks are generated than expected.
- Sensitivity: each of 12 deliberate core bugs (CMUT-001..012) makes at least one check FAIL (`formal/formal_mutations.sh`, about 14 minutes). See bugs.md.
- Not covered: FENCE/ECALL/EBREAK (not among the 37 instruction checks; the decoder treats them as illegal until Phase 4), CSRs, memory ordering
  (wrapper memory is free every cycle), real trap handling (placeholder), non-vacuity of individual checks (not established).
