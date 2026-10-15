#!/usr/bin/env bash
# Runs scripts/cosim_elf.sh on every build/rv32ui/*.elf.
cd "$(dirname "$0")/.." || exit 2
pass=0; fail=0
for f in build/rv32ui/*.elf; do
  n=$(basename "$f" .elf)
  if ./scripts/cosim_elf.sh "$f" > "/tmp/cosim_$n.out" 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $n"; fi
done
echo "cosim rv32ui: PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]
