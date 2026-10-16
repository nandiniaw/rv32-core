// imm_gen: RV32I immediate generator (combinational).
// imm_type selects the instruction format (constants in rv32_pkg). Values 5..7 are unused and give 0.
module imm_gen (
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] insn,      // bits [6:0] (opcode) are not used here
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [2:0]  imm_type,
    output logic [31:0] imm
);
    import rv32_pkg::*;
    always_comb begin
        case (imm_type)
            IMM_I:   imm = {{20{insn[31]}}, insn[31:20]};
            IMM_S:   imm = {{20{insn[31]}}, insn[31:25], insn[11:7]};
            IMM_B:   imm = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
            IMM_U:   imm = {insn[31:12], 12'b0};
            IMM_J:   imm = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};
            default: imm = 32'b0;
        endcase
    end
endmodule
