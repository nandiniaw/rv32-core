    .section .text.init
    .globl _start
_start:
    la   t0, tohost
    la   t2, dat
    li   t1, 7
    addi x0, t1, 5
    lui  x0, 0x12345
    add  x0, t1, t1
    lw   x0, 0(t2)
    jal  x0, 1f
    nop
1:  li   t1, 1
    sw   t1, 0(t0)
    sw   zero, 4(t0)
2:  j    2b
    .align 2
dat: .word 0x1234abcd
    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost:   .dword 0
    .globl fromhost
fromhost: .dword 0
