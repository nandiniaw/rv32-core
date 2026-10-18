# csr_probe: CSR read/write and one ecall trap, observed on Sail only (no self-check).
    .section .text.init
    .globl _start
_start:
    la   t0, handler
    csrw mtvec, t0
    li   t1, 0x5a5a5a5a
    csrw mscratch, t1
    csrr t2, mscratch
    ecall
    li   t5, 7
    la   t0, tohost
    li   t1, 1
    sw   t1, 0(t0)
    sw   zero, 4(t0)
1:  j    1b

    .align 2
handler:
    csrr t3, mcause
    csrr t4, mepc
    addi t4, t4, 4
    csrw mepc, t4
    mret

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost:   .dword 0
    .globl fromhost
fromhost: .dword 0
