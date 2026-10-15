// branch_cmp: RV32I branch condition evaluator (combinational).
// funct3: 000 beq, 001 bne, 100 blt, 101 bge, 110 bltu, 111 bgeu. 010 and 011 are reserved: not taken.
module branch_cmp (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [2:0]  funct3,
    output logic        taken
);
    logic eq, lt, ltu;
    assign eq  = (a == b);
    assign lt  = ($signed(a) < $signed(b));
    assign ltu = (a < b);

    always_comb begin
        case (funct3)
            3'b000:  taken = eq;
            3'b001:  taken = !eq;
            3'b100:  taken = lt;
            3'b101:  taken = !lt;
            3'b110:  taken = ltu;
            3'b111:  taken = !ltu;
            default: taken = 1'b0;
        endcase
    end
endmodule
