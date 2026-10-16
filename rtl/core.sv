// core: 5-stage pipelined RV32I core (Phase 3) with full RVFI output (NRET = 1), RVFI emitted from WB.
// IF -> ID -> EX -> MEM -> WB. Memories are external and unchanged from Phase 2: instruction read and
// data read are combinational, data writes happen at posedge clk (in MEM).
// Hazards: WB->ID register-file bypass, EX forwarding from MEM and WB, one-cycle load-use stall,
// branch/jump resolved in EX (younger instructions squashed).
// Traps are still the Phase 2 placeholder: a trapping instruction retires once with trap = halt = 1,
// has no architectural effect, younger instructions are squashed, and nothing retires afterwards.
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
    // ---------------- pipeline state ----------------
    logic [31:0] pc;
    logic        fetch_stop, halted;
    logic [63:0] order;
    // IF/ID
    logic        id_valid;
    logic [31:0] id_pc, id_insn;
    // ID/EX
    logic        ex_valid, ex_b_sel_imm, ex_reg_we, ex_mem_re, ex_mem_we, ex_is_branch, ex_is_jal, ex_is_jalr, ex_illegal;
    logic [31:0] ex_pc, ex_insn, ex_rs1_data, ex_rs2_data, ex_imm;
    logic [3:0]  ex_alu_op;
    logic [1:0]  ex_a_sel, ex_wb_sel;
    // EX/MEM
    logic        mem_valid, mem_reg_we, mem_re, mem_we, mem_trap_q, mem_trap;
    logic [31:0] mem_pc, mem_insn, mem_rs1_val, mem_rs2_val, mem_alu, mem_pc4, mem_next_pc;
    logic [1:0]  mem_wb_sel;
    // MEM/WB
    logic        wb_valid, wb_reg_we, wb_trap;
    logic [31:0] wb_pc, wb_insn, wb_rs1_val, wb_rs2_val, wb_value, wb_next_pc, wb_mem_addr, wb_mem_rdata, wb_mem_wdata;
    logic [3:0]  wb_rmask, wb_wmask;

    // ---------------- IF ----------------
    assign imem_addr = pc;

    // ---------------- ID ----------------
    logic [4:0] id_rs1, id_rs2;
    assign id_rs1 = id_insn[19:15];
    assign id_rs2 = id_insn[24:20];

    logic [3:0] d_alu_op;
    logic [1:0] d_a_sel, d_wb_sel;
    logic [2:0] d_imm_type;
    logic       d_b_sel_imm, d_reg_we, d_mem_re, d_mem_we, d_is_branch, d_is_jal, d_is_jalr, d_illegal;
    decoder u_decoder (
        .opcode(id_insn[6:0]), .funct3(id_insn[14:12]), .funct7(id_insn[31:25]),
        .alu_op(d_alu_op), .a_sel(d_a_sel), .b_sel_imm(d_b_sel_imm), .imm_type(d_imm_type),
        .reg_we(d_reg_we), .wb_sel(d_wb_sel), .mem_re(d_mem_re), .mem_we(d_mem_we),
        .is_branch(d_is_branch), .is_jal(d_is_jal), .is_jalr(d_is_jalr), .illegal(d_illegal)
    );
    logic [31:0] d_imm;
    imm_gen u_imm (.insn(id_insn), .imm_type(d_imm_type), .imm(d_imm));

    logic [4:0]  wb_rd;
    logic        wb_rf_we;
    logic [31:0] rf_rdata1, rf_rdata2, id_rs1_data, id_rs2_data;
    assign wb_rd    = wb_insn[11:7];
    assign wb_rf_we = wb_valid && wb_reg_we && !wb_trap;
    regfile u_rf (
        .clk(clk), .we(wb_rf_we), .waddr(wb_rd), .wdata(wb_value),
        .raddr1(id_rs1), .raddr2(id_rs2), .rdata1(rf_rdata1), .rdata2(rf_rdata2)
    );
    // WB->ID bypass: the register file is written at the clock edge, so an instruction in WB must be bypassed.
    assign id_rs1_data = (wb_rf_we && wb_rd != 5'd0 && wb_rd == id_rs1) ? wb_value : rf_rdata1;
    assign id_rs2_data = (wb_rf_we && wb_rd != 5'd0 && wb_rd == id_rs2) ? wb_value : rf_rdata2;

    // load-use hazard: the instruction in EX is a load whose rd feeds the instruction in ID -> stall one cycle
    logic [4:0] ex_rs1, ex_rs2, ex_rd, mem_rd;
    assign ex_rs1 = ex_insn[19:15];
    assign ex_rs2 = ex_insn[24:20];
    assign ex_rd  = ex_insn[11:7];
    assign mem_rd = mem_insn[11:7];
    logic load_use;
    assign load_use = id_valid && ex_valid && ex_mem_re && (ex_rd != 5'd0) && ((ex_rd == id_rs1) || (ex_rd == id_rs2));

    // ---------------- EX ----------------
    logic        mem_wr;
    logic [31:0] mem_fwd, fwd1, fwd2;
    assign mem_wr  = mem_valid && mem_reg_we && !mem_trap;
    assign mem_fwd = (mem_wb_sel == WB_PC4) ? mem_pc4 : mem_alu;   // a load in MEM is never forwarded: the stall prevents it
    always_comb begin
        fwd1 = ex_rs1_data;
        fwd2 = ex_rs2_data;
        if (wb_rf_we && wb_rd != 5'd0 && wb_rd == ex_rs1) fwd1 = wb_value;
        if (wb_rf_we && wb_rd != 5'd0 && wb_rd == ex_rs2) fwd2 = wb_value;
        if (mem_wr && mem_rd != 5'd0 && mem_rd == ex_rs1) fwd1 = mem_fwd;   // MEM is newer than WB, so it wins
        if (mem_wr && mem_rd != 5'd0 && mem_rd == ex_rs2) fwd2 = mem_fwd;
    end

    logic [31:0] alu_a, alu_b, alu_result, ex_pc4, ex_pc_plus_imm, ex_next_pc;
    logic        taken;
    always_comb begin
        case (ex_a_sel)
            A_PC:    alu_a = ex_pc;
            A_ZERO:  alu_a = 32'd0;
            default: alu_a = fwd1;
        endcase
    end
    assign alu_b = ex_b_sel_imm ? ex_imm : fwd2;
    alu u_alu (.a(alu_a), .b(alu_b), .op(ex_alu_op), .result(alu_result));
    branch_cmp u_br (.a(fwd1), .b(fwd2), .funct3(ex_insn[14:12]), .taken(taken));

    assign ex_pc4         = ex_pc + 32'd4;
    assign ex_pc_plus_imm = ex_pc + ex_imm;
    always_comb begin
        if (ex_is_jal)                  ex_next_pc = ex_pc_plus_imm;
        else if (ex_is_jalr)            ex_next_pc = {alu_result[31:1], 1'b0};
        else if (ex_is_branch && taken) ex_next_pc = ex_pc_plus_imm;
        else                            ex_next_pc = ex_pc4;
    end

    logic jump_misaligned, ctrl_taken, ex_trap, redirect, kill_younger;
    assign ctrl_taken      = ex_is_jal || ex_is_jalr || (ex_is_branch && taken);
    assign jump_misaligned = ctrl_taken && ex_next_pc[1];
    assign ex_trap         = ex_valid && (ex_illegal || jump_misaligned);
    assign redirect        = ex_valid && !ex_trap && ctrl_taken && !mem_trap;
    assign kill_younger    = mem_trap || ex_trap || redirect;

    // ---------------- MEM ----------------
    logic [3:0]  lsu_mask, rmask_m, wmask_m;
    logic [31:0] lsu_wdata, load_data, mem_value;
    logic        lsu_misaligned;
    lsu u_lsu (
        .funct3(mem_insn[14:12]), .addr_lo(mem_alu[1:0]), .is_load(mem_re), .is_store(mem_we),
        .store_data(mem_rs2_val), .mem_rdata(dmem_rdata), .mask(lsu_mask), .mem_wdata(lsu_wdata),
        .load_data(load_data), .misaligned(lsu_misaligned)
    );
    assign mem_trap   = mem_valid && (mem_trap_q || lsu_misaligned);
    assign dmem_addr  = {mem_alu[31:2], 2'b00};
    assign dmem_wdata = lsu_wdata;
    assign rmask_m    = (mem_valid && mem_re && !mem_trap) ? lsu_mask : 4'b0000;
    assign wmask_m    = (mem_valid && mem_we && !mem_trap) ? lsu_mask : 4'b0000;
    assign dmem_wmask = wmask_m;     // a trapping instruction must not write memory
    always_comb begin
        case (mem_wb_sel)
            WB_MEM:  mem_value = load_data;
            WB_PC4:  mem_value = mem_pc4;
            default: mem_value = mem_alu;
        endcase
    end

    // ---------------- pipeline registers ----------------
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= RESET_PC;
            fetch_stop <= 1'b0;
            halted <= 1'b0;
            order <= 64'd0;
            id_valid <= 1'b0;
            ex_valid <= 1'b0;
            mem_valid <= 1'b0;
            wb_valid <= 1'b0;
        end else begin
            // IF -> ID
            if (kill_younger) begin
                id_valid <= 1'b0;
                if (redirect) pc <= ex_next_pc;
                if (mem_trap || ex_trap) fetch_stop <= 1'b1;
            end else if (!load_use) begin
                id_valid <= !fetch_stop;
                id_pc    <= pc;
                id_insn  <= imem_rdata;
                if (!fetch_stop) pc <= pc + 32'd4;
            end
            // ID -> EX
            if (kill_younger || load_use) ex_valid <= 1'b0;
            else begin
                ex_valid     <= id_valid;
                ex_pc        <= id_pc;
                ex_insn      <= id_insn;
                ex_rs1_data  <= id_rs1_data;
                ex_rs2_data  <= id_rs2_data;
                ex_imm       <= d_imm;
                ex_alu_op    <= d_alu_op;
                ex_a_sel     <= d_a_sel;
                ex_wb_sel    <= d_wb_sel;
                ex_b_sel_imm <= d_b_sel_imm;
                ex_reg_we    <= d_reg_we;
                ex_mem_re    <= d_mem_re;
                ex_mem_we    <= d_mem_we;
                ex_is_branch <= d_is_branch;
                ex_is_jal    <= d_is_jal;
                ex_is_jalr   <= d_is_jalr;
                ex_illegal   <= d_illegal;
            end
            // EX -> MEM (an older trap in MEM squashes the instruction in EX)
            if (mem_trap) mem_valid <= 1'b0;
            else begin
                mem_valid   <= ex_valid;
                mem_pc      <= ex_pc;
                mem_insn    <= ex_insn;
                mem_rs1_val <= fwd1;
                mem_rs2_val <= fwd2;
                mem_alu     <= alu_result;
                mem_pc4     <= ex_pc4;
                mem_next_pc <= ex_next_pc;
                mem_wb_sel  <= ex_wb_sel;
                mem_reg_we  <= ex_reg_we;
                mem_re      <= ex_mem_re;
                mem_we      <= ex_mem_we;
                mem_trap_q  <= ex_trap;
            end
            // MEM -> WB
            wb_valid     <= mem_valid;
            wb_pc        <= mem_pc;
            wb_insn      <= mem_insn;
            wb_rs1_val   <= mem_rs1_val;
            wb_rs2_val   <= mem_rs2_val;
            wb_value     <= mem_value;
            wb_next_pc   <= mem_next_pc;
            wb_reg_we    <= mem_reg_we;
            wb_trap      <= mem_trap;
            wb_mem_addr  <= dmem_addr;
            wb_mem_rdata <= dmem_rdata;
            wb_mem_wdata <= lsu_wdata;
            wb_rmask     <= rmask_m;
            wb_wmask     <= wmask_m;
            // retire counter
            if (wb_valid && !halted) begin
                order <= order + 64'd1;
                if (wb_trap) halted <= 1'b1;
            end
        end
    end

    // ---------------- RVFI (from WB) ----------------
    assign rvfi_valid     = wb_valid && !halted;
    assign rvfi_order     = order;
    assign rvfi_insn      = wb_insn;
    assign rvfi_trap      = wb_trap;
    assign rvfi_halt      = wb_trap;
    assign rvfi_intr      = 1'b0;
    assign rvfi_mode      = 2'd3;
    assign rvfi_ixl       = 2'd1;
    assign rvfi_rs1_addr  = wb_insn[19:15];
    assign rvfi_rs2_addr  = wb_insn[24:20];
    assign rvfi_rs1_rdata = wb_rs1_val;
    assign rvfi_rs2_rdata = wb_rs2_val;
    assign rvfi_rd_addr   = (wb_reg_we && !wb_trap) ? wb_rd : 5'd0;
    assign rvfi_rd_wdata  = (rvfi_rd_addr == 5'd0) ? 32'd0 : wb_value;
    assign rvfi_pc_rdata  = wb_pc;
    assign rvfi_pc_wdata  = wb_trap ? wb_pc : wb_next_pc;
    assign rvfi_mem_addr  = wb_mem_addr;
    assign rvfi_mem_rmask = wb_rmask;
    assign rvfi_mem_wmask = wb_wmask;
    assign rvfi_mem_rdata = wb_mem_rdata;
    assign rvfi_mem_wdata = wb_mem_wdata;
endmodule
