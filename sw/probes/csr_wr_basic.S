    .section .text.init
    .globl _start
_start:
    li   t0, 0x12345678
    csrw mscratch, t0
    csrr a0, mscratch
    li   t0, 0x80000100
    csrw mtvec, t0
    csrr a1, mtvec
    li   t0, 0x88
    csrw mstatus, t0
    csrr a3, mstatus
    li   t0, 0x80
    csrw mstatus, t0
    csrr a7, mstatus
    li   t0, 0x888
    csrw mie, t0
    csrr a2, mie
    csrw mscratch, zero
    csrr a4, mscratch
    csrrs a5, mscratch, zero
    li   t0, 0x80000000
    csrw mepc, t0
    csrr a6, mepc
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
