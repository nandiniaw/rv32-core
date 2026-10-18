# Sail 0.15 CSR and trap trace (observed with: sail_riscv_sim --rv32 --trace-instr --trace-gpr --trace-csr --trace-exception, program sw/csr_probe.S)
Every line below was seen in this project's own run. Default --rv32 config.
- Before instruction 0: `CSR mip (0x344) <- 0x00000080` (initial state; skip lines before the first instruction).
- CSR write: `CSR <name> (0x<addr>) <- 0x<value>` after the instruction line. csrrw with rd=x0 prints no register line.
- CSR read: `CSR <name> (0x<addr>) -> 0x<value>` then `xN <- value`. csrrs with rs1=x0 prints no write line.
- ecall: instruction line, then `trapping from M to M to handle m-call`, `handling exc#m-call at priv M | tval=... | tval2=... | tinst=...`,
  then CSR writes: mstatus <- 0x1800, mstatush, mcause <- 0xB, mtval <- 0, mepc <- pc of ecall, mtval2, mtinst.
  The next instruction line is at the mtvec base (handler).
- mret: instruction line, `CSR mstatus <- 0x00000080`, `CSR mstatush <- 0`, `ret-ing from M to M`; next instruction is at mepc.
- mstatus after mret is 0x80 (MPP = user) in the default config, which has U-mode. An M-only core would keep MPP = 3 (not yet checked on Sail).
- mstatush, mtval2 and mtinst lines are hypervisor/RV32 extras a comparator for our core must ignore or the config must remove.
- Open: how RVFI should report ecall/ebreak/mret and trap entry (not yet read from the RVFI spec).
