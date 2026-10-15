// core: single-cycle RV32I core (Phase 2) with full RVFI output (NRET = 1).
// Memories are external: instruction read is combinational; data memory is addressed by an aligned
// word address with byte-lane write mask and writes at posedge clk.
// Phase 2 has no trap handling: a trapping instruction retires once with rvfi_trap = rvfi_halt = 1,
// has no architectural effect, and the core then stops retiring. Phase 4 replaces this.
module core import rv32_pkg::*; #(
    parameter logic [31:0] RESET_PC = 32'h8000_0000
) (
    input  logic        clk,
    input  logic        rst,            // synchronous, active high
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,
    output logic [31:0] dmem_addr,      // word-aligned
    output logic [3:0]  dmem_wmask,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,
    output logic        rvfi_valid,
    output logic [63:0] rvfi_order,
    output logic [31:0] rvfi_insn,
    output logic        rvfi_trap,
    output logic        rvfi_halt,
    output logic        rvfi_intr,
    output logic [1:0]  rvfi_mode,
    output logic [1:0]  rvfi_ixl,
    output logic [4:0]  rvfi_rs1_addr,
    output logic [4:0]  rvfi_rs2_addr,
    output logic [31:0] rvfi_rs1_rdata,
    output logic [31:0] rvfi_rs2_rdata,
    output logic [4:0]  rvfi_rd_addr,
    output logic [31:0] rvfi_rd_wdata,
    output logic [31:0] rvfi_pc_rdata,
    output logic [31:0] rvfi_pc_wdata,
    output logic [31:0] rvfi_mem_addr,
    output logic [3:0]  rvfi_mem_rmask,
    output logic [3:0]  rvfi_mem_wmask,
    output logic [31:0] rvfi_mem_rdata,
    output logic [31:0] rvfi_mem_wdata
);
    // ---- state ----
    logic [31:0] pc;
    logic        halted;
    logic [63:0] order;
    logic        active;
    assign active = !rst && !halted;

    // ---- instruction fields ----
    logic [31:0] insn;
    logic [4:0]  rs1, rs2, rd;
    assign insn = imem_rdata;
    assign rs1  = insn[19:15];
    assign rs2  = insn[24:20];
    assign rd   = insn[11:7];
    assign imem_addr = pc;

    // ---- decode ----
    logic [3:0] alu_op;
    logic [1:0] a_sel, wb_sel;
    logic [2:0] imm_type;
    logic       b_sel_imm, reg_we, mem_re, mem_we, is_branch, is_jal, is_jalr, illegal;
    decoder u_decoder (
        .opcode(insn[6:0]), .funct3(insn[14:12]), .funct7(insn[31:25]),
        .alu_op(alu_op), .a_sel(a_sel), .b_sel_imm(b_sel_imm), .imm_type(imm_type),
        .reg_we(reg_we), .wb_sel(wb_sel), .mem_re(mem_re), .mem_we(mem_we),
        .is_branch(is_branch), .is_jal(is_jal), .is_jalr(is_jalr), .illegal(illegal)
    );

    // ---- datapath ----
    logic [31:0] imm, rs1_data, rs2_data, alu_a, alu_b, alu_result, wb_data;
    logic        rf_we;

    imm_gen u_imm (.insn(insn), .imm_type(imm_type), .imm(imm));

    regfile u_rf (
        .clk(clk), .we(rf_we), .waddr(rd), .wdata(wb_data),
        .raddr1(rs1), .raddr2(rs2), .rdata1(rs1_data), .rdata2(rs2_data)
    );

    always_comb begin
        case (a_sel)
            A_PC:    alu_a = pc;
            A_ZERO:  alu_a = 32'd0;
            default: alu_a = rs1_data;
        endcase
    end
    assign alu_b = b_sel_imm ? imm : rs2_data;

    alu u_alu (.a(alu_a), .b(alu_b), .op(alu_op), .result(alu_result));

    // ---- branches and next PC ----
    logic        taken;
    logic [31:0] pc4, pc_plus_imm, next_pc;
    branch_cmp u_br (.a(rs1_data), .b(rs2_data), .funct3(insn[14:12]), .taken(taken));

    assign pc4         = pc + 32'd4;
    assign pc_plus_imm = pc + imm;
    always_comb begin
        if (is_jal)                   next_pc = pc_plus_imm;
        else if (is_jalr)             next_pc = {alu_result[31:1], 1'b0};
        else if (is_branch && taken)  next_pc = pc_plus_imm;
        else                          next_pc = pc4;
    end

    // ---- load/store ----
    logic [3:0]  lsu_mask;
    logic [31:0] lsu_wdata, load_data;
    logic        lsu_misaligned;
    lsu u_lsu (
        .funct3(insn[14:12]), .addr_lo(alu_result[1:0]), .is_load(mem_re), .is_store(mem_we),
        .store_data(rs2_data), .mem_rdata(dmem_rdata), .mask(lsu_mask), .mem_wdata(lsu_wdata),
        .load_data(load_data), .misaligned(lsu_misaligned)
    );
    assign dmem_addr  = {alu_result[31:2], 2'b00};
    assign dmem_wdata = lsu_wdata;

    // ---- trap (placeholder until Phase 4) ----
    logic jump_misaligned, trap;
    assign jump_misaligned = (is_jal || is_jalr || (is_branch && taken)) && next_pc[1];
    assign trap            = illegal || lsu_misaligned || jump_misaligned;
    // A trapping instruction must not write memory.
    assign dmem_wmask = (mem_we && active && !trap) ? lsu_mask : 4'b0000;

    // ---- write back ----
    always_comb begin
        case (wb_sel)
            WB_MEM:  wb_data = load_data;
            WB_PC4:  wb_data = pc4;
            default: wb_data = alu_result;
        endcase
    end
    assign rf_we = reg_we && !trap && active;

    // ---- sequential state ----
    always_ff @(posedge clk) begin
        if (rst) begin
            pc     <= RESET_PC;
            halted <= 1'b0;
            order  <= 64'd0;
        end else if (active) begin
            order <= order + 64'd1;
            if (trap) halted <= 1'b1;
            else      pc <= next_pc;
        end
    end

    // ---- RVFI ----
    assign rvfi_valid     = active;
    assign rvfi_order     = order;
    assign rvfi_insn      = insn;
    assign rvfi_trap      = trap;
    assign rvfi_halt      = trap;
    assign rvfi_intr      = 1'b0;
    assign rvfi_mode      = 2'd3;
    assign rvfi_ixl       = 2'd1;
    assign rvfi_rs1_addr  = rs1;
    assign rvfi_rs2_addr  = rs2;
    assign rvfi_rs1_rdata = rs1_data;
    assign rvfi_rs2_rdata = rs2_data;
    assign rvfi_rd_addr   = (reg_we && !trap) ? rd : 5'd0;
    assign rvfi_rd_wdata  = (rvfi_rd_addr == 5'd0) ? 32'd0 : wb_data;
    assign rvfi_pc_rdata  = pc;
    assign rvfi_pc_wdata  = trap ? pc : next_pc;
    assign rvfi_mem_addr  = dmem_addr;
    assign rvfi_mem_rmask = (mem_re && !trap) ? lsu_mask : 4'b0000;
    assign rvfi_mem_wmask = (mem_we && !trap) ? lsu_mask : 4'b0000;
    assign rvfi_mem_rdata = dmem_rdata;
    assign rvfi_mem_wdata = lsu_wdata;
endmodule
