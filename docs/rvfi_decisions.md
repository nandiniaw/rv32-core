# RVFI decisions (spec read 2026-10: https://yosyshq.readthedocs.io/projects/riscv-formal/en/latest/rvfi.html)
- NRET = 1. rvfi_order is an instruction counter from 0, no gaps, no repeats.
- rvfi_trap = illegal instruction | misaligned load/store | taken jump to a misaligned target.
- Phase 2 (no trap handler): a trapping instruction retires once with rvfi_trap = rvfi_halt = 1, has no architectural
  effect, rvfi_pc_wdata = its own PC, then the core stops retiring. Phase 4 replaces this with trap entry.
- rvfi_mode = 3 (M-mode), rvfi_ixl = 1 (32-bit), rvfi_intr = 0.
- rvfi_rd_addr is 0 whenever the instruction writes no register; rvfi_rd_wdata is 0 when rd_addr is 0.
- Memory: "aligned" style (RISCV_FORMAL_ALIGNED_MEM): rvfi_mem_addr is the word address, rmask/wmask are byte lanes,
  rdata/wdata are word-lane data. Misaligned accesses are not supported (they trap).
- Comparator maps this to Sail's byte-address trace: byte address = mem_addr + index of lowest set mask bit.
