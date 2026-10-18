#!/usr/bin/env bash
# Build every rv32ui test against sw/env and run it on Sail (the oracle).
set -uo pipefail
cd "$(dirname "$0")/.."
RT=${RISCV_TESTS:-$HOME/riscv-tests}
SKIP=" fence_i ma_data "
mkdir -p build/rv32ui logs/rv32ui
pass=0; fail=0
for src in "$RT"/isa/rv32ui/*.S; do
  t=$(basename "$src" .S)
  case "$SKIP" in *" $t "*) echo "SKIP  $t"; continue;; esac
  elf=build/rv32ui/$t.elf
  if ! riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -static -mcmodel=medany \
        -fvisibility=hidden -nostdlib -nostartfiles \
        -I sw/env -I "$RT/isa/macros/scalar" -T "$RT/env/p/link.ld" \
        "$src" -o "$elf" > logs/rv32ui/$t.build.log 2>&1; then
    echo "BUILD-FAIL  $t"; fail=$((fail+1)); continue
  fi
  timeout 20 sail_riscv_sim --rv32 --config-override config/sail_rv32i_m_only_override.json "$elf" > logs/rv32ui/$t.sail.log 2>&1; rc=$?
  if [ $rc -eq 0 ] && grep -q SUCCESS logs/rv32ui/$t.sail.log; then
    echo "PASS  $t"; pass=$((pass+1))
  else
    echo "FAIL  $t (sail exit $rc)"; fail=$((fail+1))
  fi
done
echo "rv32ui on Sail: PASS=$pass FAIL=$fail"
[ $fail -eq 0 ]
