#!/usr/bin/env bash
# MUT-002: swap the sources of imm[12] and imm[11] in the B-type immediate. The unit tests must fail.
cd "$(dirname "$0")/.." || exit 2
source .venv/bin/activate
mut=/tmp/imm_gen_mut002.sv
sed 's/insn\[31\], insn\[7\], insn\[30:25\]/insn[7], insn[31], insn[30:25]/' rtl/imm_gen.sv > "$mut"
if cmp -s rtl/imm_gen.sv "$mut"; then echo "MUT-002: mutation did not apply"; exit 2; fi
cd tests/unit || exit 2
rm -rf sim_build_mut results.xml
make TOP=imm_gen SIM_BUILD=sim_build_mut VERILOG_SOURCES="$mut" > /tmp/mut002.log 2>&1
rc=$?
fails=$(grep -c "<failure" results.xml 2>/dev/null)
fails=${fails:-0}
echo "MUT-002: make exit=$rc, failing tests in results.xml=$fails"
if [ "$fails" -gt 0 ] || [ "$rc" -ne 0 ]; then echo "MUT-002: CAUGHT"; exit 0; fi
echo "MUT-002: NOT CAUGHT (testbench is too weak)"; exit 1
