# illegal2: decoder illegal paths. Each bad word traps; handler skips it. Sail is the oracle.
    .section .text.init
    .globl _start
_start:
    la   t0, handler
    csrw mtvec, t0
    la   s0, buf
    li   t1, 0x11223344
    sw   t1, 0(s0)
    li   x6, 5
    .word 0x00043283   # load f3=011
    .word 0x00046283   # load f3=110
    .word 0x00047283   # load f3=111
    .word 0x00643023   # store f3=011
    .word 0x00644023   # store f3=100
    .word 0x00647023   # store f3=111
    .word 0xFE6302B3   # add funct7=0x7f
    .word 0x40131293   # slli funct7=0x20
    .word 0x000042F3   # system f3=100
    addi x7, x0, 1
done:
    la   t0, tohost
    li   t1, 1
    sw   t1, 0(t0)
    sw   zero, 4(t0)
1:  j    1b
    .balign 4
handler:
    csrr x31, mepc
    addi x31, x31, 4
    csrw mepc, x31
    mret
    .section .data
    .balign 4
buf: .word 0, 0
    .section .tohost, "aw", @progbits
    .balign 64
    .globl tohost
tohost:   .dword 0
    .globl fromhost
fromhost: .dword 0
