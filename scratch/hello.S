    .section .text.init
    .globl _start
_start:
    la   t0, tohost
    li   t1, 1
    sw   t1, 0(t0)
1:  j    1b

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost:   .dword 0
    .globl fromhost
fromhost: .dword 0
