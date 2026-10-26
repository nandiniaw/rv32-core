#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
source .venv/bin/activate
mkdir -p build logs
status=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got $2, want $3)"; status=1; fi; }

for t in pass fail ls_edge haz; do
  riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
    -T sw/link.ld sw/$t.S -o build/$t.elf || status=1
done
timeout 20 sail_riscv_sim --rv32 --config-override config/sail_rv32i_m_only_override.json build/pass.elf > logs/sail_pass.log 2>&1; check "sail: pass.elf exits 0" $? 0
timeout 20 sail_riscv_sim --rv32 --config-override config/sail_rv32i_m_only_override.json build/fail.elf > logs/sail_fail.log 2>&1; check "sail: fail.elf exits 1 (harness detects failure)" $? 1

make -C smoke clean > /dev/null 2>&1
make -C smoke > logs/smoke.log 2>&1; check "smoke: make exit status" $? 0
grep -qE "TESTS=[0-9]+ PASS=[0-9]+ FAIL=0" logs/smoke.log; check "smoke: no failing cocotb tests" $? 0

./scripts/rv32ui_sail.sh > logs/rv32ui_sail.log 2>&1; check "sail: rv32ui oracle run" $? 0
tail -n 1 logs/rv32ui_sail.log
./scripts/unit.sh > logs/unit.log 2>&1; check "unit tests (all modules)" $? 0
./scripts/lint.sh > logs/lint.log 2>&1; check "lint (all modules)" $? 0
./scripts/mutations.sh > logs/mutations.log 2>&1; check "mutations all caught" $? 0

timeout 20 sail_riscv_sim --rv32 --config-override config/sail_rv32i_m_only_override.json build/ls_edge.elf > logs/sail_ls_edge.log 2>&1; check "sail: ls_edge.elf exits 0" $? 0
isa=$(sail_riscv_sim --rv32 --config-override config/sail_rv32i_m_only_override.json --print-isa-string 2>&1); check "sail: M-only ISA string" "$isa" "rv32i_zicsr_zvl32b_zvl64b_zvl128b_zvl256b"
./scripts/cosim_rv32ui.sh > logs/cosim_rv32ui.log 2>&1; check "cosim: rv32ui, RTL vs Sail" $? 0
./scripts/cosim_elf.sh build/ls_edge.elf > logs/cosim_ls_edge.log 2>&1; check "cosim: ls_edge, RTL vs Sail" $? 0
./scripts/cosim_elf.sh build/haz.elf > logs/cosim_haz.log 2>&1; check "cosim: haz, RTL vs Sail" $? 0
if ./scripts/run_core_elf.sh build/fail.elf > logs/core_fail.log 2>&1; then check "core: fail.elf is rejected" accepted rejected; else check "core: fail.elf is rejected" rejected rejected; fi
./scripts/core_mutations.sh > logs/core_mutations.log 2>&1; check "core mutants all caught by cosim" $? 0

python3 scripts/test_compare_trace.py > logs/selftest_compare.log 2>&1; check "comparator self-test (v2)" $? 0

# Phase 4 probes: expected to FAIL with a MISMATCH (XFAIL) until the feature exists; XPASS = promote to a real check
mkdir -p build/probes
for p in sw/probes/*.S; do n=$(basename $p .S)
  riscv64-unknown-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles -T sw/link.ld $p -o build/probes/$n.elf || { echo "FAIL  probe build $n"; status=1; continue; }
  case " csr_init csr_rw2 csr_wr_basic mcause_all ecall mret_flow ebreak " in *" $n "*)
    if ./scripts/cosim_elf.sh build/probes/$n.elf > logs/probe_$n.log 2>&1; then echo "PASS  probe $n (real check)"; else echo "FAIL  probe $n (real check)"; status=1; fi
    continue;; esac
  if ./scripts/cosim_elf.sh build/probes/$n.elf > logs/probe_$n.log 2>&1; then echo "XPASS probe $n (promote to a real check)"; status=1
  elif grep -q MISMATCH /tmp/$n.elf.cmp.out 2>/dev/null; then echo "XFAIL probe $n"
  else echo "FAIL  probe $n failed without a MISMATCH (see logs/probe_$n.log)"; status=1; fi
done

[ $status -eq 0 ] && echo "ALL PASS" || echo "REGRESSION FAILED"
exit $status
