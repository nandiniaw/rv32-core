# RV32I 5-stage core (work in progress)

Portfolio project: 5-stage in-order RV32I (+Zicsr M-mode) core in SystemVerilog, verified with Verilator + cocotb against the Sail RISC-V reference model.

## AI assistance
Design guidance, RTL drafts, scripts and tests are written with an AI assistant (Claude) and reviewed by the author. AI-written RTL and tests are treated as unverified until they pass an independent oracle (Sail comparison, riscv-tests, ACT4, formal).

## Status
Phase 4 step B complete: Zicsr CSRs and M-mode traps match Sail instruction by instruction, on the Phase 3 5-stage pipeline (WB->ID bypass, EX forwarding, one-cycle load-use stall, branch/jump resolved in EX). Traps covered: ecall, ebreak, mret, illegal instruction, illegal CSR access, fence (a nop), misaligned jalr/load/store (mcause 0/4/6). All 40 rv32ui ELFs, ls_edge, haz and 16 CSR/trap probes match Sail (pc, insn, next pc, trap, intr, rd, loads, stores, 7 CSRs). 20 core-level mutants (CMUT-001..020, see bugs.md) are caught by the cosim. Performance results are not done.

## Known deviations (to keep honest)
- rv32ui tests run with a custom CSR-free `sw/env/riscv_test.h`, not the stock `env/p` startup. `fence_i` and `ma_data` are skipped.
- Compiler is GCC 16.1.0 / binutils 2.47 (ACT4 officially tests GCC 15 / binutils 2.44).
- Test memory is 16 KiB at 0x80000000 (largest rv32ui extent seen: 0x80002050).
- Memory is ideal: combinational instruction and data reads, so there is no memory wait state. A real SRAM or cache interface is not modelled.
- The load-use stall is conservative (it matches rs1/rs2 instruction fields even when the instruction does not use them), so some stalls are unnecessary. Correctness is not affected.
- Traps: M-mode only, no interrupts, direct-mode mtvec only, unimplemented CSRs trap as illegal, mstatush is constant, MPP resets to 0, the mcause test sweeps a subset of causes.
- Cosim covers what rv32ui, ls_edge, haz and the 16 probes exercise. Not observed: vectored mtvec, mret with MPP reset 0, wfi, fence.i. The comparator and the tests are written by the same author. The last instruction's next pc is not checked. No coverage percentages are measured. One mutant (removing `!mem_trap` from wmask_m) is equivalent because lsu.sv already zeroes the mask; see bugs.md.

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
- Not covered: ECALL/EBREAK/MRET/FENCE and CSRs (formal checks isa rv32i with no CSRs, so the trap path is tested by cosim, not formal; CMUT-013..020 were not run through formal), memory ordering
  (wrapper memory is free every cycle), non-vacuity of individual checks (not established).
