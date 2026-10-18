# RVFI trap reporting: Phase 4 decisions
Source: riscv-formal docs/source/rvfi.rst and procedure.rst (clone at commit c992aa61). Only what that text states is listed as verified.

## Verified from the spec text
- rvfi_trap is set for: an undecodable instruction, a misaligned memory read/write where misaligned access is not allowed (and other access violations), and a jump to a misaligned target.
- A trapping instruction has no register update and no memory write (procedure.rst, data bus fault check).
- rvfi_halt is set only for the last instruction before the core stops; it must NOT be set for an instruction that traps if the core then runs a trap handler.
- rvfi_intr is set on the first instruction of a trap handler (its rvfi_pc_rdata differs from the previous rvfi_pc_wdata).
- rvfi_mode 3 = M-mode, rvfi_ixl 1 = 32 bit.
- CSRs: four ports per CSR (rmask, wmask, rdata, wdata) and the define RISCV_FORMAL_CSR_<NAME>; semantics are in csrs.rst (not yet read).

## Decisions for this core
- D1: illegal instruction, misaligned load/store and misaligned jump each retire exactly once with rvfi_trap = 1, no rd write and no memory write. Sail's cause/mtval/mepc values are in docs/sail_trap_behaviour.md.
- D2: once handlers run, rvfi_halt = 0 always (the Phase 2 placeholder, halt = trap, is replaced).
- D3: the first handler instruction has rvfi_intr = 1 and pc_rdata = mtvec base.

## Open (not stated in the text read)
- O1: rvfi_pc_wdata of the trapping instruction (handler address or the non-trap next pc).
- O2: whether ecall/ebreak set rvfi_trap.
- O3: CSR rdata/wdata/mask semantics (csrs.rst) for mstatus, mtvec, mepc, mcause, mtval, mscratch.
- O4: how the instruction after mret is reported.
