#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
source .venv/bin/activate
mkdir -p logs
status=0
cd tests/unit
for top in regfile alu imm_gen decoder branch_cmp lsu sys_decoder csr_check csr_file; do
  make clean > /dev/null 2>&1
  make TOP=$top EXTRA_SRC="$([ $top = csr_file ] && echo $PWD/../../rtl/csr_check.sv)" > ../../logs/unit_$top.log 2>&1; rc=$?
  if [ $rc -eq 0 ] && grep -qE "TESTS=[0-9]+ PASS=[0-9]+ FAIL=0" ../../logs/unit_$top.log; then
    echo "PASS  unit: $top"; grep -E "TESTS=" ../../logs/unit_$top.log
  else
    echo "FAIL  unit: $top (see logs/unit_$top.log)"; status=1
  fi
done
exit $status
