#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
status=0
lint() { echo "== $1"; verilator --lint-only -Wall --top-module "$1" "${@:2}" || status=1; }
lint regfile rtl/regfile.sv
lint alu rtl/rv32_pkg.sv rtl/alu.sv
exit $status
