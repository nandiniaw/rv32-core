// tb_top: core + ideal RAM for simulation. RAM base 0x8000_0000, size MEM_BYTES (multiple of 4).
// Load a program with +HEX=<file>: one 32-bit hex word per line, starting at the RAM base.
// Reads are combinational; writes happen at posedge clk. mem_oob latches any retired instruction whose
// fetch, or whose load/store, falls outside the RAM.
module tb_top #(
    parameter int unsigned MEM_BYTES = 64 * 1024
) (
    input  logic        clk,
    input  logic        rst,
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
    output logic [31:0] rvfi_mem_wdata,
    output logic        mem_oob
);
    localparam logic [31:0] BASE  = 32'h8000_0000;
    localparam int unsigned WORDS = MEM_BYTES / 4;
    localparam int unsigned AW    = $clog2(WORDS);

    logic [31:0] mem [WORDS];

    logic [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_wmask;

    // Address decode. The low 2 bits and the bits above the index are intentionally unused.
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] i_off, d_off;
    /* verilator lint_on UNUSEDSIGNAL */
    logic        i_ok, d_ok;
    logic [AW-1:0] i_idx, d_idx;
    assign i_off = imem_addr - BASE;
    assign d_off = dmem_addr - BASE;
    assign i_ok  = (i_off < MEM_BYTES);
    assign d_ok  = (d_off < MEM_BYTES);
    assign i_idx = i_off[AW+1:2];
    assign d_idx = d_off[AW+1:2];
    // mem_oob is judged on the retiring instruction (RVFI), not on the current fetch/data address.
    logic [31:0] r_pc_off, r_d_off;
    assign r_pc_off = rvfi_pc_rdata - BASE;
    assign r_d_off  = rvfi_mem_addr - BASE;

    assign imem_rdata = i_ok ? mem[i_idx] : 32'd0;
    assign dmem_rdata = d_ok ? mem[d_idx] : 32'd0;

    always_ff @(posedge clk) begin
        if (d_ok) begin
            if (dmem_wmask[0]) mem[d_idx][7:0]   <= dmem_wdata[7:0];
            if (dmem_wmask[1]) mem[d_idx][15:8]  <= dmem_wdata[15:8];
            if (dmem_wmask[2]) mem[d_idx][23:16] <= dmem_wdata[23:16];
            if (dmem_wmask[3]) mem[d_idx][31:24] <= dmem_wdata[31:24];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) mem_oob <= 1'b0;
        else if (rvfi_valid && (!(r_pc_off < MEM_BYTES) || (((rvfi_mem_rmask != 4'd0) || (rvfi_mem_wmask != 4'd0)) && !(r_d_off < MEM_BYTES))))
            mem_oob <= 1'b1;
    end

    string hexfile;
    initial begin
        for (int i = 0; i < WORDS; i++) mem[i] = 32'd0;
        if ($value$plusargs("HEX=%s", hexfile)) $readmemh(hexfile, mem);
    end

    core u_core (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wmask(dmem_wmask), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
        .rvfi_valid(rvfi_valid), .rvfi_order(rvfi_order), .rvfi_insn(rvfi_insn),
        .rvfi_trap(rvfi_trap), .rvfi_halt(rvfi_halt), .rvfi_intr(rvfi_intr),
        .rvfi_mode(rvfi_mode), .rvfi_ixl(rvfi_ixl),
        .rvfi_rs1_addr(rvfi_rs1_addr), .rvfi_rs2_addr(rvfi_rs2_addr),
        .rvfi_rs1_rdata(rvfi_rs1_rdata), .rvfi_rs2_rdata(rvfi_rs2_rdata),
        .rvfi_rd_addr(rvfi_rd_addr), .rvfi_rd_wdata(rvfi_rd_wdata),
        .rvfi_pc_rdata(rvfi_pc_rdata), .rvfi_pc_wdata(rvfi_pc_wdata),
        .rvfi_mem_addr(rvfi_mem_addr), .rvfi_mem_rmask(rvfi_mem_rmask), .rvfi_mem_wmask(rvfi_mem_wmask),
        .rvfi_mem_rdata(rvfi_mem_rdata), .rvfi_mem_wdata(rvfi_mem_wdata)
    );
endmodule
