# Sail 0.15 trap behaviour, M-only RV32I+Zicsr config
Config: `sail_riscv_sim --rv32 --config-override config/sail_rv32i_m_only_override.json` (ISA string rv32i_zicsr_zvl32b_zvl64b_zvl128b_zvl256b).
Misaligned load/store trapping is enabled via `memory.misaligned.exceptions.load_store = {"Some": "AlignmentException"}`.
Without that setting Sail completes misaligned loads and stores (observed with the first override).
Source: sw/probes/*.S, run with --trace-instr --trace-gpr --trace-csr --trace-exception. Every line below was observed.

| Probe | mcause | mtval | mepc |
|---|---|---|---|
| illegal (.word 0xffffffff) | 2 | the instruction word (0xFFFFFFFF) | pc of the instruction |
| csr_illegal (csrr from CSR 0x123) | 2 | the instruction word (0x12302373) | pc of the instruction |
| ebreak | 3 | pc of the ebreak | pc of the ebreak |
| ecall | 0xB | 0 | pc of the ecall |
| misaligned jalr target | 0 | the target address | pc of the jalr |
| misaligned lw / lh | 4 | the effective address | pc of the access |
| misaligned sw / sh | 6 | the effective address | pc of the access |

- Trap entry writes mstatus <- 0x1800 (MPP = M). mret writes mstatus <- 0x1880 (MPP stays M, MPIE = 1) because U-mode is off.
- The trace shows the CSR writes in the order mstatus, mcause, mtval, mepc.
- Misaligned fetch traps on the jump instruction itself.
- Not yet observed: the next pc after mret (mret_flow output was cut off), mstatush/mtval2/mtinst lines under this config, vectored mtvec, CSR read-only/write behaviour of each ID CSR.
