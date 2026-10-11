#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source .venv/bin/activate
{
  grep PRETTY_NAME /etc/os-release
  riscv64-unknown-elf-gcc --version | head -n 1
  riscv64-unknown-elf-as --version | head -n 1
  echo "sail $(sail_riscv_sim --version)"
  echo "sail tarball sha256 $(sha256sum downloads/sail-0.15.tar.gz | cut -d' ' -f1)"
  verilator --version
  echo "verilator source $(git -C ~/verilator describe --tags)"
  echo "riscv-gnu-toolchain $(git -C ~/riscv-gnu-toolchain rev-parse HEAD)"
  echo "riscv-tests $(git -C ~/riscv-tests rev-parse HEAD)"
  python --version
  pip freeze
} > versions.txt
cat versions.txt
