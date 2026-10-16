// riscv-formal wrapper: core + free (unconstrained) memories.
// Memory read data is random every cycle; each retired instruction reports its own insn and data via RVFI.
module rvfi_wrapper (
        input         clock,
        input         reset,
        `RVFI_OUTPUTS
);
        (* keep *) wire [31:0] imem_addr;
        (* keep *) `rvformal_rand_reg [31:0] imem_rdata;
        (* keep *) wire [31:0] dmem_addr;
        (* keep *) wire [3:0]  dmem_wmask;
        (* keep *) wire [31:0] dmem_wdata;
        (* keep *) `rvformal_rand_reg [31:0] dmem_rdata;

        core uut (
                .clk        (clock),
                .rst        (reset),
                .imem_addr  (imem_addr),
                .imem_rdata (imem_rdata),
                .dmem_addr  (dmem_addr),
                .dmem_wmask (dmem_wmask),
                .dmem_wdata (dmem_wdata),
                .dmem_rdata (dmem_rdata),
                `RVFI_CONN
        );
endmodule
