#!/usr/bin/env bash
# Runs every deliberate mutation; each one must be CAUGHT by its module's unit tests.
cd "$(dirname "$0")/.." || exit 2
status=0
run() { ./scripts/mutate.sh "$@"; [ $? -eq 0 ] || status=1; }
run MUT-001 alu 's/>>>/>>/'
run MUT-002 imm_gen 's/insn\[31\], insn\[7\], insn\[30:25\]/insn[7], insn[31], insn[30:25]/'
run MUT-003 decoder 's/alu_op = funct7\[5\] ? ALU_SUB : ALU_ADD/alu_op = funct7[4] ? ALU_SUB : ALU_ADD/'
run MUT-004 decoder "s/3'b100, 3'b101: ;/3'b100, 3'b101, 3'b011: ;/"
run MUT-005 branch_cmp "s/3'b100:  taken = lt;/3'b100:  taken = ltu;/"
run MUT-006 branch_cmp "s/default: taken = 1'b0;/default: taken = eq;/"
[ $status -eq 0 ] && echo "ALL MUTATIONS CAUGHT" || echo "A MUTATION ESCAPED OR DID NOT APPLY"
exit $status
