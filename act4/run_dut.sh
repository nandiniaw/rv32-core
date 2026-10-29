#!/usr/bin/env bash
# usage: act4/run_dut.sh [elf_dir]  (venv must be active)
# Runs every ELF in elf_dir on the RTL core. Per-ELF PASS/FAIL, then a total.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
dir=${1:-$HOME/act4_work/rv32-core-sail/elfs/rv32i/I}
pass=0; fail=0
while read -r elf; do
  n=$(basename "$elf")
  if MEM_BYTES=262144 MAKE_ARGS="SIM_BUILD=sim_build_act EXTRA_ARGS=-GMEM_BYTES=262144" \
       "$root/scripts/run_core_elf.sh" "$elf" > "/tmp/act4_dut_$n.out" 2>&1; then
    pass=$((pass+1)); echo "PASS $n"
  else
    fail=$((fail+1)); echo "FAIL $n (see /tmp/act4_dut_$n.out and /tmp/$n.sim.log)"
  fi
done < <(find "$dir" -name '*.elf' | sort)
echo "TOTAL: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
