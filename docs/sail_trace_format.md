# Sail 0.15 text trace format (observed, flags: --trace-instr --trace-gpr --trace-mem)
Every line below was seen in this project's own runs.
- Instruction: `[N] [M]: 0xPC (0xINSN) disassembly  symbol+offset`
- Fetch: `mem[X,0xADDR] -> 0xINSN` precedes each instruction line.
- Register write: `xN <- 0xVALUE` after the instruction line. Zero values are printed too.
- No register line after writes to x0 (seen for addi, lui, add, lw, jal; CSR ops untested).
- Load: `mem[R,0xADDR] -> 0xDATA` (digit count = access size), then `xN <- sign/zero-extended value`. Printed even when rd is x0.
- Store: `mem[W,0xADDR] <- 0xDATA` (digit count = access size; sh at +2 prints 0xAA00, not a shifted word).
- Branches: no register line; taken or not is visible only from the next PC.
- jal/jalr with rd != x0: `xN <- link address`.
- `--trace-rvfi` (with and without --trace-output) wrote an empty file on an ordinary ELF run.
