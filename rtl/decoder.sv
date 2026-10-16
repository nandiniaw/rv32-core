// decoder: RV32I base-ISA instruction decoder (combinational).
// FENCE, ECALL, EBREAK and CSR instructions are illegal for now (Phase 4 adds them).
// When illegal is set, every side-effect output is forced to 0.
module decoder (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    output logic [3:0] alu_op,
    output logic [1:0] a_sel,       // A_RS1, A_PC, A_ZERO
    output logic       b_sel_imm,   // 0: rs2, 1: immediate
    output logic [2:0] imm_type,    // IMM_*
    output logic       reg_we,
    output logic [1:0] wb_sel,      // WB_ALU, WB_MEM, WB_PC4
    output logic       mem_re,
    output logic       mem_we,
    output logic       is_branch,
    output logic       is_jal,
    output logic       is_jalr,
    output logic       illegal
);
    import rv32_pkg::*;
    logic f7_zero, f7_alt;
    assign f7_zero = (funct7 == 7'b0000000);
    assign f7_alt  = (funct7 == 7'b0100000);

    always_comb begin
        alu_op = ALU_ADD; a_sel = A_RS1; b_sel_imm = 1'b0; imm_type = IMM_I;
        reg_we = 1'b0; wb_sel = WB_ALU; mem_re = 1'b0; mem_we = 1'b0;
        is_branch = 1'b0; is_jal = 1'b0; is_jalr = 1'b0; illegal = 1'b0;

        case (opcode)
            OPC_LUI: begin
                a_sel = A_ZERO; b_sel_imm = 1'b1; imm_type = IMM_U; reg_we = 1'b1;
            end
            OPC_AUIPC: begin
                a_sel = A_PC; b_sel_imm = 1'b1; imm_type = IMM_U; reg_we = 1'b1;
            end
            OPC_JAL: begin
                imm_type = IMM_J; is_jal = 1'b1; reg_we = 1'b1; wb_sel = WB_PC4;
            end
            OPC_JALR: begin
                b_sel_imm = 1'b1; imm_type = IMM_I; is_jalr = 1'b1; reg_we = 1'b1; wb_sel = WB_PC4;
                if (funct3 != 3'b000) illegal = 1'b1;
            end
            OPC_BRANCH: begin
                imm_type = IMM_B; is_branch = 1'b1;
                if (funct3 == 3'b010 || funct3 == 3'b011) illegal = 1'b1;
            end
            OPC_LOAD: begin
                b_sel_imm = 1'b1; imm_type = IMM_I; mem_re = 1'b1; reg_we = 1'b1; wb_sel = WB_MEM;
                case (funct3)
                    3'b000, 3'b001, 3'b010, 3'b100, 3'b101: ;
                    default: illegal = 1'b1;
                endcase
            end
            OPC_STORE: begin
                b_sel_imm = 1'b1; imm_type = IMM_S; mem_we = 1'b1;
                case (funct3)
                    3'b000, 3'b001, 3'b010: ;
                    default: illegal = 1'b1;
                endcase
            end
            OPC_OP_IMM: begin
                b_sel_imm = 1'b1; imm_type = IMM_I; reg_we = 1'b1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    3'b001: begin
                        alu_op = ALU_SLL;
                        illegal = !f7_zero;
                    end
                    3'b101: begin
                        alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                        illegal = !(f7_zero || f7_alt);
                    end
                endcase
            end
            OPC_OP: begin
                reg_we = 1'b1;
                case (funct3)
                    3'b000: begin
                        alu_op = funct7[5] ? ALU_SUB : ALU_ADD;
                        illegal = !(f7_zero || f7_alt);
                    end
                    3'b001: begin alu_op = ALU_SLL;  illegal = !f7_zero; end
                    3'b010: begin alu_op = ALU_SLT;  illegal = !f7_zero; end
                    3'b011: begin alu_op = ALU_SLTU; illegal = !f7_zero; end
                    3'b100: begin alu_op = ALU_XOR;  illegal = !f7_zero; end
                    3'b101: begin
                        alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                        illegal = !(f7_zero || f7_alt);
                    end
                    3'b110: begin alu_op = ALU_OR;   illegal = !f7_zero; end
                    3'b111: begin alu_op = ALU_AND;  illegal = !f7_zero; end
                endcase
            end
            default: illegal = 1'b1;
        endcase

        if (illegal) begin
            reg_we = 1'b0; mem_re = 1'b0; mem_we = 1'b0;
            is_branch = 1'b0; is_jal = 1'b0; is_jalr = 1'b0;
        end
    end
endmodule
