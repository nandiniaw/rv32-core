#!/usr/bin/env bash
# usage: scripts/rand_regress.sh START COUNT [--traps]
cd "$(dirname "$0")/.." || exit 2
s0=${1:?start}; cnt=${2:?count}; tr=${3:-}
mkdir -p build/rand logs; bad=0; fails=""
for ((s=s0; s<s0+cnt; s++)); do
  python3 tests/gen/gen_prog.py --seed $s $tr --out build/rand/r$s.S 2>/dev/null || { echo "GEN FAIL $s"; bad=$((bad+1)); continue; }
  riscv64-unknown-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles -T sw/link.ld build/rand/r$s.S -o build/rand/r$s.elf > logs/rand_$s.build 2>&1 || { echo "BUILD FAIL $s"; bad=$((bad+1)); continue; }
  if ./scripts/cosim_elf.sh build/rand/r$s.elf > logs/rand_$s.log 2>&1; then :; else fails="$fails $s"; bad=$((bad+1)); fi
done
echo "random: seeds $s0..$((s0+cnt-1)) $tr  failed=$bad  seeds:${fails:- none}"
[ $bad -eq 0 ]
