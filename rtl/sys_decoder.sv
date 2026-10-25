// sys_decoder: SYSTEM (0x73) and MISC-MEM/FENCE (0x0F, funct3=0) decoder, combinational.
// valid = 1 only for the encodings the core implements: CSR instructions (funct3 1,2,3,5,6,7), exact ecall,
// ebreak and mret words, and fence. Everything else (wfi, sret, fence.i, reserved funct3) gives valid = 0.
// csr_write = 0 for csrrs/csrrc with rs1 = x0 and csrrsi/csrrci with uimm = 0 (no CSR write side effect).
module sys_decoder (
    input  logic [31:0] insn,
    output logic        valid,
    output logic        is_csr,
    output logic        csr_write,
    output logic        csr_imm,
    output logic        is_ecall,
    output logic        is_ebreak,
    output logic        is_mret,
    output logic        is_fence
);
    logic [2:0] f3;
    logic [4:0] rs1, rd;
    logic [11:0] f12;
    assign f3  = insn[14:12];
    assign rs1 = insn[19:15];
    assign rd  = insn[11:7];
    assign f12 = insn[31:20];

    always_comb begin
        valid = 1'b0; is_csr = 1'b0; csr_write = 1'b0; csr_imm = 1'b0;
        is_ecall = 1'b0; is_ebreak = 1'b0; is_mret = 1'b0; is_fence = 1'b0;
        if (insn[6:0] == 7'b1110011) begin
            case (f3)
                3'b000: begin
                    if (rs1 == 5'd0 && rd == 5'd0) begin
                        if (f12 == 12'h000) begin is_ecall = 1'b1; valid = 1'b1; end
                        else if (f12 == 12'h001) begin is_ebreak = 1'b1; valid = 1'b1; end
                        else if (f12 == 12'h302) begin is_mret = 1'b1; valid = 1'b1; end
                    end
                end
                3'b001, 3'b101: begin is_csr = 1'b1; valid = 1'b1; csr_write = 1'b1; csr_imm = f3[2]; end
                3'b010, 3'b011, 3'b110, 3'b111: begin
                    is_csr = 1'b1; valid = 1'b1; csr_imm = f3[2]; csr_write = (rs1 != 5'd0);
                end
                default: ;
            endcase
        end else if (insn[6:0] == 7'b0001111 && f3 == 3'b000) begin
            is_fence = 1'b1; valid = 1'b1;
        end
    end
endmodule
