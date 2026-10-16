# ls_edge: load/store edge cases with NO self-check. The Sail comparison is the only oracle.
# Covers lb/lbu/lh/lhu/lw at every legal offset, values whose bit 7 and bit 6 differ, negative
# offsets, and sb/sh/sw at every legal offset followed by reloads of the stored bytes.
    .section .text.init
    .globl _start
_start:
    la   t0, buf

    # byte loads at every offset
    .irp off,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    lb   t2, \off(t0)
    lbu  t3, \off(t0)
    .endr
    # halfword loads at every even offset
    .irp off,0,2,4,6,8,10,12,14
    lh   t2, \off(t0)
    lhu  t3, \off(t0)
    .endr
    # word loads
    .irp off,0,4,8,12
    lw   t2, \off(t0)
    .endr
    # negative offsets from a base in the middle of the buffer
    addi t4, t0, 8
    lb   t2, -8(t4)
    lb   t2, -1(t4)
    lbu  t3, -2(t4)
    lh   t2, -4(t4)
    lhu  t3, -2(t4)
    lw   t2, -8(t4)

    # stores with varying values, then reload them
    la   t1, scratch
    li   t5, 0xA5C3E17F
    sw   t5, 0(t1)
    sb   t5, 4(t1)
    srli t5, t5, 8
    sb   t5, 5(t1)
    srli t5, t5, 8
    sb   t5, 6(t1)
    srli t5, t5, 8
    sb   t5, 7(t1)
    li   t5, 0x8001C2F3
    sh   t5, 8(t1)
    srli t5, t5, 16
    sh   t5, 10(t1)
    li   t5, 0x40BF7F80
    sh   t5, 12(t1)
    srli t5, t5, 16
    sh   t5, 14(t1)
    sw   t5, 16(t1)
    .irp off,0,4,8,12,16
    lw   t2, \off(t1)
    .endr
    .irp off,0,2,4,6,8,10,12,14
    lh   t2, \off(t1)
    lhu  t3, \off(t1)
    .endr
    .irp off,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    lb   t2, \off(t1)
    lbu  t3, \off(t1)
    .endr

    # finish: tohost = 1 (exit code 0), same sequence as pass.S
    la   t0, tohost
    li   t1, 1
    sw   t1, 0(t0)
    sw   zero, 4(t0)
1:  j    1b

    .section .data
    .align 4
buf:     .byte 0x00, 0x01, 0x40, 0x7f, 0x80, 0x81, 0xbf, 0xc0, 0xff, 0xfe, 0x55, 0xaa, 0x3f, 0xc1, 0x12, 0xed
    .align 4
scratch: .space 32

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost:   .dword 0
    .globl fromhost
fromhost: .dword 0
