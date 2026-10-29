#!/usr/bin/env bash
# usage: scripts/rand_mutants.sh MAXSEEDS [--traps]
# For each CMUT: apply it to a copy of rtl/, run random seeds 1..MAX, stop at first MISMATCH.
cd "$(dirname "$0")/.." || exit 2
max=${1:?maxseeds}; tr=${2:-}
tag=m; [ -n "$tr" ] && tag=t
mkdir -p build/randmut logs
out=logs/rand_mutants_${tag}.txt; : > "$out"
run() { # name rtl-file sed-expr (elf ignored)
  rm -rf /tmp/rtl_mut tests/system/sim_build_mut; cp -r rtl /tmp/rtl_mut
  sed -i "$3" "/tmp/rtl_mut/$2"
  if diff -q "rtl/$2" "/tmp/rtl_mut/$2" > /dev/null; then echo "$1: MUTATION DID NOT APPLY" | tee -a "$out"; return; fi
  export MAKE_ARGS="RTL=/tmp/rtl_mut SIM_BUILD=sim_build_mut"
  for ((s=1; s<=max; s++)); do
    f=build/randmut/$tag$s
    if [ ! -f $f.elf ]; then
      python3 tests/gen/gen_prog.py --seed $s $tr --out $f.S 2>/dev/null || continue
      riscv64-unknown-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles -T sw/link.ld $f.S -o $f.elf > /dev/null 2>&1 || continue
    fi
    ./scripts/cosim_elf.sh $f.elf > /dev/null 2>&1; rc=$?
    if [ $rc -ne 0 ] && grep -q MISMATCH /tmp/$tag$s.elf.cmp.out; then
      echo "$1: CAUGHT at seed $s ($tag)" | tee -a "$out"; unset MAKE_ARGS; return
    fi
  done
  echo "$1: NOT caught in $max seeds ($tag)" | tee -a "$out"; unset MAKE_ARGS
}
grep '^run CMUT' scripts/core_mutations.sh > /tmp/muts.inc
source /tmp/muts.inc
rm -rf tests/system/sim_build_mut
echo "caught: $(grep -c CAUGHT "$out" | head -n1) lines; see $out"
