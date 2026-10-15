#!/usr/bin/env bash
# Runs every build/rv32ui/*.elf on the RTL core, plus a must-fail control (build/fail.elf).
cd "$(dirname "$0")/.." || exit 2
pass=0; fail=0
for f in build/rv32ui/*.elf; do
  n=$(basename "$f" .elf)
  if ./scripts/run_core_elf.sh "$f" > "/tmp/core_$n.out" 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $n"; fi
done
echo "core rv32ui: PASS=$pass FAIL=$fail"
./scripts/run_core_elf.sh build/fail.elf > /tmp/core_fail_control.out 2>&1
if [ $? -ne 0 ] && grep -q "test reported failure" /tmp/fail.elf.sim.log; then
  echo "control: build/fail.elf correctly rejected"; ctl=0
else
  echo "control: build/fail.elf NOT rejected (harness too weak)"; ctl=1
fi
[ "$pass" -gt 0 ] && [ "$fail" -eq 0 ] && [ "$ctl" -eq 0 ]
