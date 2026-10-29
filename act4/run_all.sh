#!/usr/bin/env bash
# usage: act4/run_all.sh  (rv32-core venv active; needs riscv64-unknown-elf-*, sail_riscv_sim, a riscv-arch-test checkout)
# Env overrides: RISCV_ARCH_TEST (default ~/riscv-arch-test), ACT4_WORK (default ~/act4_work), ACT4_EXTENSIONS (default I,Zicsr)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
act=${RISCV_ARCH_TEST:-$HOME/riscv-arch-test}
work=${ACT4_WORK:-$HOME/act4_work}
ext=${ACT4_EXTENSIONS:-I,Zicsr}
(cd "$act" && CONFIG_FILES="$here/test_config.yaml" EXTENSIONS="$ext" FAST=True WORKDIR="$work" JOBS=4 make)
(cd "$act" && ./run_tests.py --timeout 60 "sail_riscv_sim --config $here/sail.json" "$work/rv32-core-sail/elfs")
"$here/run_dut.sh" "$work/rv32-core-sail/elfs"
