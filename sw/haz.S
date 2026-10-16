# haz: pipeline hazard test, NO self-check. The Sail comparison is the oracle.
# Covers: RAW forwarding at distance 1/2/3/4 on rs1 and rs2, x0 as destination, two writers of one
# register, load-use (rs1, rs2, address base, store data, branch operand, jalr target), load data used
# after 1 and 2 independent instructions, store data/address forwarding, taken/not-taken branches with
# just-computed operands, wrong-path shadows, jal/jalr link used immediately, lui/auipc forwarding.
    .section .text.init
    .globl _start
_start:
    la   s0, buf
    li   t0, 5
    li   t1, 9
    # ---- 1. RAW, ALU to ALU
    add  t2, t0, t1
    add  t3, t2, t1
    add  t4, t1, t3
    add  t5, t4, t4
    sub  t6, t5, t4
    xor  a0, t5, t6
    or   a1, t4, a0
    and  a2, t3, a1
    addi a3, x0, 7
    add  a4, a3, x0
    add  a4, x0, a3
    addi a3, x0, 8
    nop
    add  a4, a3, x0
    add  a4, x0, a3
    addi a3, x0, 9
    nop
    nop
    add  a4, a3, a3
    addi a3, x0, 10
    nop
    nop
    nop
    add  a4, a3, a3
    # ---- 2. x0 as destination must never forward
    addi x0, x0, 5
    add  a5, x0, x0
    addi x0, t0, 1
    add  a5, x0, t0
    add  a5, t0, x0
    lw   x0, 0(s0)
    add  a5, x0, t0
    jal  x0, 1f
1:  add  a5, x0, t0
    # ---- 3. two writers of one register: the younger one must win
    addi a6, x0, 1
    addi a6, x0, 2
    add  a7, a6, a6
    addi a6, x0, 3
    addi a6, x0, 4
    nop
    add  a7, a6, a6
    addi a6, x0, 5
    addi a6, x0, 6
    addi a6, a6, 1
    add  a7, a6, a6
    # ---- 4. lui/auipc results used immediately
    lui  a0, 0x12345
    add  a1, a0, a0
    auipc a2, 1
    add  a3, a2, a2
    # ---- 5. data setup in memory
    li   t0, 0x11223344
    sw   t0, 0(s0)
    sw   s0, 4(s0)
    la   t1, tgt1
    sw   t1, 8(s0)
    # ---- 6. load-use
    lw   a0, 0(s0)
    add  a1, a0, a0
    lw   a0, 0(s0)
    add  a1, x0, a0
    lw   a0, 0(s0)
    add  a1, a0, x0
    lw   a0, 4(s0)
    lw   a2, 0(a0)
    lw   a0, 0(s0)
    sw   a0, 12(s0)
    lw   a0, 4(s0)
    sw   a2, 16(a0)
    lw   a3, 12(s0)
    add  a4, a3, a3
    lw   a0, 0(s0)
    beq  a0, a0, 2f
    addi a5, x0, 99
    sw   a5, 20(s0)
2:  lw   a0, 0(s0)
    bne  a0, a0, 3f
    addi a5, x0, 1
3:  lw   a0, 8(s0)
    jalr ra, 0(a0)
    j    4f
tgt1:
    add  a7, ra, ra
    jalr x0, 0(ra)
    addi a7, x0, 97
4:  # load data used after 1 and 2 independent instructions, load into x0
    lw   a0, 0(s0)
    addi a1, x0, 1
    add  a2, a0, a1
    lw   a0, 0(s0)
    addi a1, x0, 1
    addi a1, a1, 1
    add  a2, a0, a1
    lw   x0, 0(s0)
    add  a2, x0, a0
    # ---- 7. store data and store address forwarding, store then load same address
    addi a0, x0, 0x55
    sb   a0, 24(s0)
    addi a0, a0, 1
    nop
    sb   a0, 25(s0)
    addi a0, a0, 1
    nop
    nop
    sb   a0, 26(s0)
    addi s1, s0, 28
    sw   a0, 0(s1)
    lw   a1, 24(s0)
    lw   a2, 28(s0)
    sw   a0, 36(s0)
    lw   a1, 36(s0)
    sh   a0, 40(s0)
    lhu  a1, 40(s0)
    # ---- 8. branches with just-computed operands, wrong-path shadows
    li   t0, 3
loop:
    addi t0, t0, -1
    bne  t0, x0, loop
    addi t1, x0, 5
    beq  t1, t1, 5f
    addi t2, x0, 99
    sw   t2, 44(s0)
5:  addi t1, x0, 6
    blt  x0, t1, 6f
    addi t2, x0, 98
    sw   t2, 44(s0)
6:  bge  x0, t1, 7f
    addi t2, x0, 1
7:  bltu t1, x0, 8f
    addi t2, x0, 2
8:  bgeu x0, t1, 9f
    addi t2, x0, 3
9:  lw   a0, 44(s0)
    # ---- 9. jal and jalr, link used immediately, target forwarded from the instruction before
    jal  ra, f1
    j    after_f1
f1: add  a4, ra, ra
    jalr x0, 0(ra)
    addi a4, x0, 97
after_f1:
    la   t5, f2
    jalr ra, 0(t5)
    j    after_f2
f2: addi a6, ra, 4
    jalr x0, 0(ra)
    addi a6, x0, 96
after_f2:
    la   t0, tohost
    li   t1, 1
    sw   t1, 0(t0)
    sw   zero, 4(t0)
fin: j   fin
    .align 4
buf:
    .space 64

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost:   .dword 0
    .globl fromhost
fromhost: .dword 0
