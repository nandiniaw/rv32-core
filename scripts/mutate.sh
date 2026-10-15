#!/usr/bin/env bash
# usage: mutate.sh <label> <module> <sed-expression>
# Applies the sed expression to rtl/<module>.sv in a temp copy and runs that module's unit tests.
# CAUGHT means at least one test failed (or make failed). Prints the failing tests.
label=$1; top=$2; expr=$3
cd "$(dirname "$0")/.." || exit 2
root=$(pwd)
source .venv/bin/activate
mut=/tmp/${top}_${label}.sv
sed "$expr" "rtl/$top.sv" > "$mut"
if cmp -s "rtl/$top.sv" "$mut"; then echo "$label: mutation did not apply"; exit 2; fi
cd tests/unit || exit 2
rm -rf sim_build_mut results.xml
make TOP="$top" SIM_BUILD=sim_build_mut VERILOG_SOURCES="$root/rtl/rv32_pkg.sv $mut" > "/tmp/$label.log" 2>&1
rc=$?
fails=$(grep -c "<failure" results.xml 2>/dev/null)
fails=${fails:-0}
echo "$label: make exit=$rc, failing tests in results.xml=$fails"
grep -E "^ +\*\* .* FAIL " "/tmp/$label.log" | sed 's/ \+/ /g'
if [ "$fails" -gt 0 ] || [ "$rc" -ne 0 ]; then echo "$label: CAUGHT"; exit 0; fi
echo "$label: NOT CAUGHT (testbench is too weak)"; exit 1
