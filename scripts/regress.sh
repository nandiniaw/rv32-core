#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
source .venv/bin/activate
mkdir -p build logs
status=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got $2, want $3)"; status=1; fi; }

for t in pass fail ls_edge; do
  riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
    -T sw/link.ld sw/$t.S -o build/$t.elf || status=1
done
timeout 20 sail_riscv_sim --rv32 build/pass.elf > logs/sail_pass.log 2>&1; check "sail: pass.elf exits 0" $? 0
timeout 20 sail_riscv_sim --rv32 build/fail.elf > logs/sail_fail.log 2>&1; check "sail: fail.elf exits 1 (harness detects failure)" $? 1

make -C smoke clean > /dev/null 2>&1
make -C smoke > logs/smoke.log 2>&1; check "smoke: make exit status" $? 0
grep -qE "TESTS=[0-9]+ PASS=[0-9]+ FAIL=0" logs/smoke.log; check "smoke: no failing cocotb tests" $? 0

./scripts/rv32ui_sail.sh > logs/rv32ui_sail.log 2>&1; check "sail: rv32ui oracle run" $? 0
tail -n 1 logs/rv32ui_sail.log
./scripts/unit.sh > logs/unit.log 2>&1; check "unit tests (all modules)" $? 0
./scripts/lint.sh > logs/lint.log 2>&1; check "lint (all modules)" $? 0
./scripts/mutations.sh > logs/mutations.log 2>&1; check "mutations all caught" $? 0

timeout 20 sail_riscv_sim --rv32 build/ls_edge.elf > logs/sail_ls_edge.log 2>&1; check "sail: ls_edge.elf exits 0" $? 0
./scripts/cosim_rv32ui.sh > logs/cosim_rv32ui.log 2>&1; check "cosim: rv32ui, RTL vs Sail" $? 0
./scripts/cosim_elf.sh build/ls_edge.elf > logs/cosim_ls_edge.log 2>&1; check "cosim: ls_edge, RTL vs Sail" $? 0
if ./scripts/run_core_elf.sh build/fail.elf > logs/core_fail.log 2>&1; then check "core: fail.elf is rejected" accepted rejected; else check "core: fail.elf is rejected" rejected rejected; fi
./scripts/core_mutations.sh > logs/core_mutations.log 2>&1; check "core mutants all caught by cosim" $? 0

[ $status -eq 0 ] && echo "ALL PASS" || echo "REGRESSION FAILED"
exit $status
