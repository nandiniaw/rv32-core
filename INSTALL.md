# Install and run

This file covers what the ACT4 run needs. Versions of the other tools are in `versions.txt`.

## Tools
- Sail RISC-V simulator `sail_riscv_sim` 0.15 on PATH.
- RISC-V GNU toolchain `riscv64-unknown-elf-*`, GCC 16.1.0 / binutils 2.47. ACT4 officially tests GCC 15 / binutils 2.44, so this is newer than the tested pair.
- Ubuntu 26.04.1 LTS, Python 3.14.4.
- The repo's `.venv`: cocotb 2.1.0 and pytest 9.1.1 (full `pip freeze` in `versions.txt`). There is no requirements.txt or pyproject.toml at the repo root, so recreating the venv is not scripted.
- Verilator 5.052, built from source (tag v5.052). The build steps for the toolchain, Sail and Verilator are not written down here; the commits and the Sail tarball hash are in `versions.txt`.
- ACT4 tooling from mise: Ruby 3.4.11, uv 0.12.23, Bundler 4.0.22.
- riscv-arch-test pinned at commit 7f7d735a8649f4486b1727f99d638ada38d50e51 (`git describe`: cert-docs-2026-10-09-22-20-4f2263e-10-g7f7d735a8). Its Makefile runs through `uv`, or through `mise exec -- uv run` when `uv` is not on PATH. On the author's machine `uv` is not on PATH and mise 2026.10.7 provides it.

## Run
```
source .venv/bin/activate
git clone https://github.com/riscv/riscv-arch-test ~/riscv-arch-test
git -C ~/riscv-arch-test checkout 7f7d735a8649f4486b1727f99d638ada38d50e51
./act4/run_all.sh
```
Expected end of output: `All 45 tests passed` from the Sail step, then `TOTAL: 45 passed, 0 failed` from the RTL step.

Environment overrides: `RISCV_ARCH_TEST` (default `~/riscv-arch-test`), `ACT4_WORK` (default `~/act4_work`), `ACT4_EXTENSIONS` (default `I,Zicsr`).

Output is in `$ACT4_WORK/rv32-core-sail/`. A failing RTL run leaves `/tmp/act4_dut_<elf>.out` and `/tmp/<elf>.sim.log`.

`act4/run_cmd.txt` holds an absolute path from the author's machine. It is only used for running `run_tests.py` by hand. `run_all.sh` builds its own command.
