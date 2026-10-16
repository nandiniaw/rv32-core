#!/usr/bin/env bash
# Core-level mutants: each must be caught by the cosim (RTL vs Sail) on the listed ELF.
cd "$(dirname "$0")/.." || exit 2
status=0
run() { # name rtl-file sed-expr elf
  if ./scripts/cosim_mut.sh "$2" "$3" "$4" > "/tmp/coremut_$1.out" 2>&1; then echo "$1: CAUGHT (elf $4)"; else echo "$1: NOT CAUGHT (elf $4)"; status=1; fi
}
run CMUT-001 lsu.sv 's/{24{ld_byte\[7\]}}/{24{ld_byte[6]}}/' build/ls_edge.elf
run CMUT-002 core.sv 's/WB_PC4:  mem_value = mem_pc4;/WB_PC4:  mem_value = mem_pc4 + 32'"'"'d4;/' build/rv32ui/jal.elf
run CMUT-003 lsu.sv "s/addr_lo\[1\] ? 4'b1100 : 4'b0011/addr_lo[1] ? 4'b0011 : 4'b1100/" build/rv32ui/sh.elf
run CMUT-004 core.sv 's/if (mem_wr && mem_rd != 5.d0 && mem_rd == ex_rs1)/if (1 == 0)/' build/rv32ui/add.elf
run CMUT-005 core.sv 's/if (wb_rf_we && wb_rd != 5.d0 && wb_rd == ex_rs2)/if (1 == 0)/' build/rv32ui/xor.elf
run CMUT-006 core.sv 's/assign load_use = id_valid/assign load_use = 1 == 0 \&\& id_valid/' build/rv32ui/lw.elf
run CMUT-007 core.sv 's/assign id_rs1_data = (wb_rf_we && wb_rd != 5.d0 && wb_rd == id_rs1)/assign id_rs1_data = (1 == 0)/' build/rv32ui/sub.elf
run CMUT-008 core.sv 's/if (kill_younger || load_use) ex_valid/if (mem_trap || ex_trap || load_use) ex_valid/' build/rv32ui/beq.elf
run CMUT-009 core.sv 's/mem_rs2_val <= fwd2;/mem_rs2_val <= ex_rs2_data;/' build/rv32ui/sw.elf
exit $status
