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

## Decisions D4/D5 (project decisions)
- D4: CSRs that Sail accepts but the core does not implement (PMP, counters, mhpm*, mstatush pending check) trap as illegal. Implemented set: mstatus 0x300, misa 0x301, mie 0x304, mtvec 0x305, mscratch 0x340, mepc 0x341, mcause 0x342, mtval 0x343, mip 0x344, ID CSRs 0xF11-0xF15. Enforcement: compare_trace.py fails with "unsupported CSR touched" when Sail logs a CSR access outside this set. mcycle/minstret (0xB00/0xB02) are deferred to the benchmark phase.
- D5: no interrupts in Phase 4. mip reads the constant 0x80 (as Sail); test programs never enable mstatus.MIE together with a mie bit; the comparator will stop on an interrupt entry in Sail's trace (format not yet observed). Optional machine timer interrupt is a later stretch.
- Open: mstatush (0x310) vs riscv-formal isa_mods; check when wiring the formal CSR checks.

## Decisions D6/D7 (project decisions)
- D6 (trap rule): RTL trap = 1 iff Sail logged "handling exc#" on that instruction, checked in both directions. After a trap the next retired instruction has intr = 1, all others intr = 0. The next pc after a trap equals the next Sail instruction pc. rvfi_halt = 0 once handlers run.
- D7 (CSR checking): trace format v2 has 20 fields: order pc insn npc trap rd rdv maddr rm wm rdata wdata intr mstatus mie mtvec mscratch mepc mcause mtval. The last 7 are the CSR values AFTER the retired instruction. The comparator applies Sail's "CSR x <- v" lines (observed to log the stored, legalized value) to a state table and compares after every instruction. mstatush, mtval2 and mtinst lines are ignored. CSR reads are checked through rd.
- Open: CSR write/read timing in the pipeline (all CSR access at WB, or stall csrr behind older CSR writes). RTL reset values must equal Sail's (measured with sw/probes/csr_init.S).

## Decisions D8/D9 (project decisions)
- D8: mcause is implemented with Sail's measured write rule (sw/probes/mcause_all.S, docs/sail_csr_behaviour.md). Accepted exception codes: 0-9, 0xB, 0xC, 0xD, 0xF, 0x13. Accepted interrupt codes (bit 31 set): 1, 3, 5, 7, 9, 0xB. Every other value is ignored and mcause keeps its old value. Only 138 values were swept, not all 2^32; the rest is inferred from legalize_cause in sail-riscv 0.15 (model/core/sys_regs.sail) and is a stated risk.
- D9: mstatush (0x310) reads 0 and ignores writes (measured: 0 initially, after -1, after 0). The comparator already skips mstatush lines (SKIP_CSR); the RTL value is checked through rd.
- D4 amendment: mstatush no longer traps. All other D4 items stand.
