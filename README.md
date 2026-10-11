# RV32I 5-stage core (work in progress)

Portfolio project: 5-stage in-order RV32I (+Zicsr M-mode) core in SystemVerilog, verified with Verilator + cocotb against the Sail RISC-V reference model.

## AI assistance
Design guidance, RTL drafts, scripts and tests are written with an AI assistant (Claude) and reviewed by the author. AI-written RTL and tests are treated as unverified until they pass an independent oracle (Sail comparison, riscv-tests, ACT4, formal).

## Status
Phase 2 in progress (single-cycle core). No results are reported yet.

## Known deviations (to keep honest)
- rv32ui tests run with a custom CSR-free `sw/env/riscv_test.h`, not the stock `env/p` startup. `fence_i` and `ma_data` are skipped.
- Compiler is GCC 16.1.0 / binutils 2.47 (ACT4 officially tests GCC 15 / binutils 2.44).
- Test memory is 16 KiB at 0x80000000 (largest rv32ui extent seen: 0x80002050).

## Reproduce
`./scripts/versions.sh`, `./scripts/regress.sh`, `./scripts/unit.sh`. Versions are in `versions.txt`.
