#!/usr/bin/env bash
# usage: formal/formal_mut.sh <label> <rtl-file> '<sed expr>' [cfg-name]
# Applies a deliberate bug to a COPY of rtl/, runs the formal config on it, and reports which checks FAIL.
# CAUGHT only if at least one check reports FAIL (an ERROR is a setup problem, not a catch).
cd "$(dirname "$0")/.." || exit 2
label=${1:?label}; file=${2:?rtl-file}; expr=${3:?sed expr}; cfg=${4:-full}
d="/tmp/rtl_fmut_$label"
rm -rf "$d" && cp -r rtl "$d"
sed -i "$expr" "$d/$file"
if diff -q "rtl/$file" "$d/$file" > /dev/null; then echo "$label: mutation did not apply"; exit 2; fi
cp "formal/$cfg.cfg" formal/fmut.cfg
SECONDS=0
RTL_DIR="$d" ./formal/run.sh fmut 3 > "logs/formal_mut_$label.log" 2>&1
./formal/summary.sh fmut > "logs/formal_mut_$label.summary"
caught=$(grep -E ' FAIL' "logs/formal_mut_$label.summary" | awk '{print $1}' | tr '\n' ' ')
if [ -n "$caught" ]; then echo "$label: CAUGHT by $caught(${SECONDS}s)"; exit 0
elif [ ! -s "logs/formal_mut_$label.summary" ] || grep -q ' ERROR' "logs/formal_mut_$label.summary"; then
  echo "$label: ERROR (setup problem, see logs/formal_mut_$label.log)"; exit 2
else echo "$label: NOT CAUGHT (all checks PASS within the bound) (${SECONDS}s)"; exit 1; fi
