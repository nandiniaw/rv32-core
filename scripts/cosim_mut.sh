#!/usr/bin/env bash
# usage: scripts/cosim_mut.sh <rtl-file> '<sed expression>' <elf>
# Applies a deliberate bug to a copy of rtl/ and runs the cosim on the mutant. The cosim must FAIL.
cd "$(dirname "$0")/.." || exit 2
[ $# -eq 3 ] || { echo "usage: $0 <rtl-file> '<sed expr>' <elf>"; exit 2; }
rm -rf /tmp/rtl_mut && cp -r rtl /tmp/rtl_mut
sed -i "$2" "/tmp/rtl_mut/$1"
if diff -q "rtl/$1" "/tmp/rtl_mut/$1" > /dev/null; then echo "MUTANT: mutation did not apply"; exit 2; fi
export MAKE_ARGS="RTL=/tmp/rtl_mut SIM_BUILD=sim_build_mut"
./scripts/cosim_elf.sh "$3"; rc=$?
if [ $rc -ne 0 ] && grep -q MISMATCH "/tmp/$(basename "$3").cmp.out"; then echo "MUTANT CAUGHT"; exit 0; else echo "MUTANT NOT CAUGHT"; exit 1; fi
