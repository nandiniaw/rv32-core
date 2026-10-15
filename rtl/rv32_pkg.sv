// Shared encodings: the single source of truth for every module.
// Each consumer uses only some constants, so unused-parameter warnings are waived here on purpose.
/* verilator lint_off UNUSEDPARAM */
package rv32_pkg;
  // ALU operations
  localparam logic [3:0] ALU_ADD  = 4'd0;
  localparam logic [3:0] ALU_SUB  = 4'd1;
  localparam logic [3:0] ALU_SLL  = 4'd2;
  localparam logic [3:0] ALU_SLT  = 4'd3;
  localparam logic [3:0] ALU_SLTU = 4'd4;
  localparam logic [3:0] ALU_XOR  = 4'd5;
  localparam logic [3:0] ALU_SRL  = 4'd6;
  localparam logic [3:0] ALU_SRA  = 4'd7;
  localparam logic [3:0] ALU_OR   = 4'd8;
  localparam logic [3:0] ALU_AND  = 4'd9;

  // Immediate formats (imm_gen)
  localparam logic [2:0] IMM_I = 3'd0;
  localparam logic [2:0] IMM_S = 3'd1;
  localparam logic [2:0] IMM_B = 3'd2;
  localparam logic [2:0] IMM_U = 3'd3;
  localparam logic [2:0] IMM_J = 3'd4;

  // ALU operand A select
  localparam logic [1:0] A_RS1  = 2'd0;
  localparam logic [1:0] A_PC   = 2'd1;
  localparam logic [1:0] A_ZERO = 2'd2;

  // Register write-back select
  localparam logic [1:0] WB_ALU = 2'd0;
  localparam logic [1:0] WB_MEM = 2'd1;
  localparam logic [1:0] WB_PC4 = 2'd2;

  // Base opcodes (insn[6:0])
  localparam logic [6:0] OPC_LUI    = 7'b0110111;
  localparam logic [6:0] OPC_AUIPC  = 7'b0010111;
  localparam logic [6:0] OPC_JAL    = 7'b1101111;
  localparam logic [6:0] OPC_JALR   = 7'b1100111;
  localparam logic [6:0] OPC_BRANCH = 7'b1100011;
  localparam logic [6:0] OPC_LOAD   = 7'b0000011;
  localparam logic [6:0] OPC_STORE  = 7'b0100011;
  localparam logic [6:0] OPC_OP_IMM = 7'b0010011;
  localparam logic [6:0] OPC_OP     = 7'b0110011;
endpackage
