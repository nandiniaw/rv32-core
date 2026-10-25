    .section .text.init
    .globl _start
_start:
    csrr a0, mstatus
    csrr a1, mie
    csrr a2, mtvec
    csrr a3, mscratch
    csrr a4, mepc
    csrr a5, mcause
    csrr a6, mtval
    la   t0, tohost
    li   t1, 1
    sw   t1, 0(t0)
    sw   zero, 4(t0)
1:  j    1b
    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost:   .dword 0
    .globl fromhost
fromhost: .dword 0
