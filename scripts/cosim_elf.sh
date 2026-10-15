#!/usr/bin/env bash
# usage: scripts/cosim_elf.sh <elf>
# Runs the ELF on Sail (text trace) and on the RTL core, then compares the two retire traces.
cd "$(dirname "$0")/.." || exit 2
elf=${1:-}
[ -f "$elf" ] || { echo "usage: $0 <elf>"; exit 2; }
name=$(basename "$elf")
sail_trace=/tmp/$name.sail.trace
timeout 60 sail_riscv_sim --rv32 --trace --trace-output "$sail_trace" "$elf" > "/tmp/$name.sail.out" 2>&1
sail_rc=$?
./scripts/run_core_elf.sh "$elf" > "/tmp/$name.core.out" 2>&1
core_rc=$?
python3 scripts/compare_trace.py "/tmp/$name.core.trace" "$sail_trace"
cmp_rc=$?
echo "cosim $name: sail exit=$sail_rc, core run exit=$core_rc, compare exit=$cmp_rc"
[ $sail_rc -eq 0 ] && [ $core_rc -eq 0 ] && [ $cmp_rc -eq 0 ]
