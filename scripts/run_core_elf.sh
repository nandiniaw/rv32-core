#!/usr/bin/env bash
# usage: scripts/run_core_elf.sh <elf> [max_instr]
# Runs one ELF on the RTL core (tb_top) and checks the HTIF tohost result.
set -u
[ $# -ge 1 ] || { echo "usage: $0 <elf> [max_instr]"; exit 2; }
root=$(cd "$(dirname "$0")/.." && pwd)
elf=$(realpath "$1")
max=${2:-200000}
name=$(basename "$elf")
hex=/tmp/$name.hex
trace=/tmp/$name.core.trace
python3 "$root/scripts/elf2hex.py" "$elf" "$hex" 65536 || exit 2
cd "$root/tests/system" || exit 2
rm -f results.xml
ELF="$elf" MAX_INSTR="$max" TRACE_OUT="$trace" make ${MAKE_ARGS:-} COCOTB_PLUSARGS="+HEX=$hex" > "/tmp/$name.sim.log" 2>&1
rc=$?
fails=$(grep -c "<failure" results.xml 2>/dev/null)
fails=${fails:-0}
tail -n 12 "/tmp/$name.sim.log"
if [ $rc -eq 0 ] && [ "$fails" -eq 0 ] && grep -q "PASS=1" "/tmp/$name.sim.log"; then
  echo "CORE RUN PASS: $name ($(wc -l < "$trace") instructions, trace $trace)"
else
  echo "CORE RUN FAIL: $name (make exit=$rc, failures=$fails)"; exit 1
fi
