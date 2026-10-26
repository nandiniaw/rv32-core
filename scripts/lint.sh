#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
status=0
lint() { echo "== $1"; verilator --lint-only -Wall --top-module "$1" "${@:2}" || status=1; }
lint regfile rtl/regfile.sv
lint alu rtl/rv32_pkg.sv rtl/alu.sv
lint imm_gen rtl/rv32_pkg.sv rtl/imm_gen.sv
lint decoder rtl/rv32_pkg.sv rtl/decoder.sv
lint branch_cmp rtl/branch_cmp.sv
lint lsu rtl/lsu.sv
lint sys_decoder rtl/sys_decoder.sv
lint csr_file rtl/csr_file.sv
lint core rtl/rv32_pkg.sv rtl/alu.sv rtl/imm_gen.sv rtl/decoder.sv rtl/sys_decoder.sv rtl/branch_cmp.sv rtl/lsu.sv rtl/regfile.sv rtl/core.sv
lint tb_top rtl/rv32_pkg.sv rtl/alu.sv rtl/imm_gen.sv rtl/decoder.sv rtl/sys_decoder.sv rtl/branch_cmp.sv rtl/lsu.sv rtl/regfile.sv rtl/core.sv tb/tb_top.sv
exit $status
