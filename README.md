# RV32I 5-stage core (work in progress)

Portfolio project: 5-stage in-order RV32I (+Zicsr M-mode) core in SystemVerilog, verified with Verilator + cocotb against the Sail RISC-V reference model.

## Status
Phase 4 and Phase 5 complete. Phase 5: random tests (200 seeds pass; 12/20 plain and 18/20 trap-mode mutants caught), Verilator coverage (line 98.8%), trace-based functional coverage (22/23 listed bins), and ACT4 (45/45 ELFs, I and Zicsr, on Sail and the RTL; one config, one test set, not a compliance claim). Phase 4 detail follows.

Phase 4 step B complete: Zicsr CSRs and M-mode traps match Sail instruction by instruction, on the Phase 3 5-stage pipeline (WB->ID bypass, EX forwarding, one-cycle load-use stall, branch/jump resolved in EX). Traps covered: ecall, ebreak, mret, illegal instruction, illegal CSR access, fence (a nop), misaligned jalr/load/store (mcause 0/4/6). All 40 rv32ui ELFs, ls_edge, haz and 16 CSR/trap probes match Sail (pc, insn, next pc, trap, intr, rd, loads, stores, 7 CSRs). 20 core-level mutants (CMUT-001..020, see bugs.md) are caught by the cosim. Performance results are not done. Phase 5 also ran the RISC-V architectural tests (ACT4): 45 of 45 ELFs (I, Zicsr) pass on Sail and on the RTL, see the Phase 5a section.

## Known deviations (to keep honest)
- rv32ui tests run with a custom CSR-free `sw/env/riscv_test.h`, not the stock `env/p` startup. `fence_i` and `ma_data` are skipped.
- Compiler is GCC 16.1.0 / binutils 2.47 (ACT4 officially tests GCC 15 / binutils 2.44). GCC 16.1 builds and passes the ACT4 tests used here; equivalence with GCC 15 not shown.
- Test memory is 64 KiB at 0x80000000 (scripts/run_core_elf.sh passes 65536 unless MEM_BYTES is set). The ACT4 tests are bigger (I-add-00 has a 74,496-byte image extent), so `act4/run_dut.sh` sets MEM_BYTES=262144 (256 KiB) and builds a separate Verilator model in `tests/system/sim_build_act`. The default in `tb/tb_top.sv` is unchanged.
- Memory is ideal: combinational instruction and data reads, so there is no memory wait state. A real SRAM or cache interface is not modelled.
- The load-use stall is conservative (it matches rs1/rs2 instruction fields even when the instruction does not use them), so some stalls are unnecessary. Correctness is not affected.
- Traps: M-mode only, no interrupts, direct-mode mtvec only, unimplemented CSRs trap as illegal, mstatush is constant, MPP resets to 0, the mcause test sweeps a subset of causes.
- Cosim covers what rv32ui, ls_edge, haz and the 16 probes exercise. Not observed: vectored mtvec, mret with MPP reset 0, wfi, fence.i. The comparator and the tests are written by the same author. The last instruction's next pc is not checked. One mutant (removing `!mem_trap` from wmask_m) is equivalent because lsu.sv already zeroes the mask; see bugs.md.

## Phase 5: random tests and coverage
- Random tests: `tests/gen/gen_prog.py` (seeded), `scripts/rand_regress.sh`. 200 seeds passed against Sail (100 plain, 100 with traps). `regress.sh` runs 20 plain and 20 trap seeds.
- Mutants caught by random seeds (first 30 seeds, `scripts/rand_mutants.sh`, tables in docs/): plain 12/20, with traps 18/20. Survivors CMUT-017 (fence) and CMUT-018 (misaligned jalr mtval): the generator has no fence or misaligned-jalr template. Directed probes `fence` and `ma_jalr` catch both.
- Functional coverage (`scripts/fcov.py`, `docs/fcov_report.txt`): 22 of 23 bins I listed are hit over 200 traces. `trap_cause_0` is not reached. Bins are retire-distance bins from RVFI traces, not RTL selectors, and the bin list is my own, so this does not measure completeness.
- Verilator coverage (`scripts/vcov.sh`, `docs/vcov_summary.txt`, 38 runs mixing random seeds and directed tests): line 98.8%, toggle 79.7%, branch 95.0%, expr 92.9%. Most missed toggles are upper bits of wide signals and constant signals. Not a proof of correctness.
- Probe `illegal2` covers decoder illegal encodings that no other test hit.

## Phase 5a: ACT4 (riscv-arch-test)
- Result: 45 of 45 ELFs pass on Sail and on the RTL. They are the 39 `I` tests and the 6 `Zicsr` tests, one `-00` file per instruction. `act4/run_all.sh` builds them, runs them on Sail, then on the RTL. This is one config and one test set. It is not a compliance certification.
- Versions: riscv-arch-test 7f7d735a8649f4486b1727f99d638ada38d50e51, Sail 0.15, GCC 16.1.0. The config is in `act4/` (yaml extensions I, Zicsr, Sm; M-mode only; C off; misaligned load/store raises an exception). `FAST=True` only skips objdump.
- RTL run: `act4/run_dut.sh` runs each ELF through `scripts/run_core_elf.sh`. The tests print through HTIF (a `tohost` write with device 1, command 1), and `tests/system/test_core_elf.py` decodes those writes. A test passes if tohost reports exit code 0 and, when a summary was printed, it says `RVCP-SUMMARY: TEST PASSED`. This does not use the framework's `run_tests.py` and does not compare signature files. The verdict is the test's own self-check.
- Reference config bug: the framework's signature run passes only `--config <dir>/sail.json`, so it never saw `--config-override`. With C on, `mepc[1]` is writable and the expected values assumed that. All six Zicsr tests then failed on Sail itself. The RTL masks `mepc[1:0]` (IALIGN=32), so it was not an RTL bug. `act4/sail.json` is now the stock template merged with `config/sail_rv32i_m_only_override.json`; the unmerged template is `act4/sail.base.json`.
- Not covered by ACT4: no trap tests apply to this config. Every priv directory needs Sv or PMP, and the `Misalign` tests need `MISALIGNED_LDST: true` while the yaml says false. Traps are covered only by my own cosim probes above (ecall, mret, ebreak, illegal, csr_illegal, `ma_*`), which are not ACT4 tests. The yaml's `Sm` selects no tests.
- Deviations from the reference: the Sail config's ISA string still contains zmmul, zaamo, zalrsc, za128rs and za64rs, which the RTL does not have. All 45 pass, so no built test needed them. One Sail trace showed `mip` bit 7 (MTIP) being set while the yaml says `MTI_INTR_IMPL false`. No result depends on it, and I did not look into why. No "unimplemented CSR" deviation came up.

## Reproduce
`./scripts/versions.sh`, `./scripts/regress.sh`, `./scripts/unit.sh`, `./act4/run_all.sh` (ACT4, needs a riscv-arch-test checkout, see INSTALL.md). Versions are in `versions.txt`.

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
