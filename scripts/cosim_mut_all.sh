#!/usr/bin/env bash
# usage: scripts/cosim_mut_all.sh <rtl-file> '<sed expression>' [elf-glob]
# Builds one mutant of rtl/, runs the cosim on every ELF matching the glob (default build/rv32ui/*.elf)
# and lists the ELFs that catch it. Exits 0 if at least one ELF catches the mutant.
cd "$(dirname "$0")/.." || exit 2
[ $# -ge 2 ] || { echo "usage: $0 <rtl-file> '<sed expr>' [glob]"; exit 2; }
glob=${3:-build/rv32ui/*.elf}
rm -rf /tmp/rtl_mut && cp -r rtl /tmp/rtl_mut
sed -i "$2" "/tmp/rtl_mut/$1"
if diff -q "rtl/$1" "/tmp/rtl_mut/$1" > /dev/null; then echo "MUTANT: mutation did not apply"; exit 2; fi
export MAKE_ARGS="RTL=/tmp/rtl_mut SIM_BUILD=sim_build_mut"
caught=(); total=0
for f in $glob; do
  total=$((total+1))
  if ! ./scripts/cosim_elf.sh "$f" > "/tmp/mut_$(basename "$f").out" 2>&1; then grep -q MISMATCH "/tmp/$(basename "$f").cmp.out" && caught+=("$(basename "$f" .elf)"); fi
done
echo "mutant run: ${#caught[@]} of $total ELFs fail: ${caught[*]:-none}"
[ ${#caught[@]} -gt 0 ]
