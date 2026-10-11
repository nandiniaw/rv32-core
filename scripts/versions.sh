#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source .venv/bin/activate
{
  grep PRETTY_NAME /etc/os-release
  riscv64-unknown-elf-gcc --version | head -n 1
  riscv64-unknown-elf-as --version | head -n 1
  echo "sail $(sail_riscv_sim --version)"
  verilator --version
  python --version
  pip freeze
} > versions.txt
cat versions.txt
