    .section .text.init
    .globl _start
_start:
    la   t0, handler
    csrw mtvec, t0
    la   s0, buf
    li   t1, 0x11223344
    sw   t1, 0(s0)
    sw   t1, 4(s0)
    lw   t1, 1(s0)
done:
    la   t0, tohost
    li   t1, 1
    sw   t1, 0(t0)
    sw   zero, 4(t0)
1:  j    1b
    .balign 4
handler:
    csrr t2, mcause
    csrr t3, mepc
    csrr t4, mtval
    csrr t5, mstatus
    la   t0, tohost
    li   t1, 1
    sw   t1, 0(t0)
    sw   zero, 4(t0)
2:  j    2b
    .balign 16
buf:
    .space 16

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost:   .dword 0
    .globl fromhost
fromhost: .dword 0
