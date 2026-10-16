#!/usr/bin/env bash
# Core-level mutants: each must be caught by the cosim (RTL vs Sail) on the listed ELF.
cd "$(dirname "$0")/.." || exit 2
status=0
run() { # name rtl-file sed-expr elf
  if ./scripts/cosim_mut.sh "$2" "$3" "$4" > "/tmp/coremut_$1.out" 2>&1; then echo "$1: CAUGHT (elf $4)"; else echo "$1: NOT CAUGHT (elf $4)"; status=1; fi
}
run CMUT-001 lsu.sv 's/{24{ld_byte\[7\]}}/{24{ld_byte[6]}}/' build/ls_edge.elf
run CMUT-002 core.sv 's/WB_PC4:  wb_data = pc4;/WB_PC4:  wb_data = pc4 + 32'"'"'d4;/' build/rv32ui/jal.elf
run CMUT-003 lsu.sv "s/addr_lo\[1\] ? 4'b1100 : 4'b0011/addr_lo[1] ? 4'b0011 : 4'b1100/" build/rv32ui/sh.elf
exit $status
