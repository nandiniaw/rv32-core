#!/usr/bin/env bash
# MUT-002: swap the sources of imm[12] and imm[11] in the B-type immediate. The unit tests must fail.
exec "$(dirname "$0")/mutate.sh" MUT-002 imm_gen 's/insn\[31\], insn\[7\], insn\[30:25\]/insn[7], insn[31], insn[30:25]/'
