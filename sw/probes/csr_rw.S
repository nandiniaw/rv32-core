    .macro PROBE csr
    csrr t1, \csr
    li   t0, -1
    csrw \csr, t0
    csrr t2, \csr
    csrw \csr, x0
    csrr t3, \csr
    csrw \csr, t1
    .endm
    .section .text.init
    .globl _start
_start:
    la   t0, handler
    csrw mtvec, t0
    j    body
    .balign 4
handler:
    csrr t4, mepc
    addi t4, t4, 4
    csrw mepc, t4
    mret
body:
    PROBE 0x340
    PROBE 0x341
    PROBE 0x342
    PROBE 0x343
    PROBE 0x300
    PROBE 0x301
    PROBE 0x344
    PROBE 0x304
    PROBE 0xF11
    PROBE 0xF12
    PROBE 0xF13
    PROBE 0xF14
    PROBE 0xF15
    PROBE 0x305
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
