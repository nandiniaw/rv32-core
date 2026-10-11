# ACT4 spike (Sail-only), Oct 2026

Setup: riscv-arch-test branch act4 @ 7f7d735; mise: Ruby 3.4.11, uv 0.12.23, Bundler 4.0.22.
Command: FAST=True EXTENSIONS=I CONFIG_FILES=config/sail/sail-RVI20U32/test_config.yaml make
Toolchain: GCC 16.1.0 / binutils 2.47.20260726 (ACT4 officially tests GCC 15 / binutils 2.44).

Evidence:
- 39 self-checking ELFs built; all 39 print "RVCP-SUMMARY: TEST PASSED" and exit 0 on Sail 0.15.
- Compile flags (logs/act4_spike_verbose.log line 11): -march=rv32i -Xassembler -march=rv32i_zicsr_zifencei -mabi=ilp32 -O0 -mcmodel=medany -nostdlib, __stack_size=128.
- ELF arch attribute: rv32i2p1_zicsr2p0_zifencei2p0. All 270848 disassembled lines are 32-bit encodings.
- Largest memory extent across ELFs: 0x800233a0 (140.9 KiB above 0x80000000).

Not shown:
- Equivalence with GCC 15.
- Anything about our DUT. Privileged tests were not generated (include_priv_tests False).


Update (objdump + Sail trace of I-nop-00 and I-xori-00):
- CSR use per ELF: csrrs mstatus and csrrw fcsr in .text.rvmodel (boot code at rvmodel_boot), csrrs fflags in the test/framework code. This gives 2 csrrs + 1 csrrw per test, matching the totals (78 / 39).
- fmv.w.x: 32 per ELF, all in .text.rvmodel; 32 Sail trace lines mention fmv, so Sail executes them (probably FP register initialisation). An earlier guess that this was data decoded as code was wrong.
- All of this F-related code may depend on the Sail config declaring F. Whether a DUT config without F produces the same code is not yet verified.

Update 2:
- config/sail/sail-RVI20U32/rvmodel_macros.h contains no fmv/fcsr/mstatus/fflags text.
- fflags appears in tests/env/rvtest_failure_code.h (failure-path routines), so the fflags CSR read in each ELF is probably not executed in a passing run (unconfirmed).
- sail-RVI20U32.yaml declares I, M, Zmmul, A, F, D, C, Zicntr, Zihpm, Zicsr, Zifencei, Zaamo, Zalrsc, Zca, Zcf, Zcd, Sm; the F/D boot code likely follows from that. Whether an I+Zicsr DUT config avoids it is not verified.
