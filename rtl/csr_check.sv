// Shared CSR legality rule (decision D4). Used by EX (trap check) and csr_file (WB).
module csr_check (
    input  logic [11:0] addr,
    input  logic        do_write,
    output logic        illegal
);
    logic implemented, read_only;

    always_comb begin
        implemented = 1'b0;
        case (addr)
            12'h300, 12'h301, 12'h304, 12'h305, 12'h310,
            12'h340, 12'h341, 12'h342, 12'h343, 12'h344,
            12'hF11, 12'hF12, 12'hF13, 12'hF14, 12'hF15: implemented = 1'b1;
            default: implemented = 1'b0;
        endcase
        read_only = (addr >= 12'hF11) && (addr <= 12'hF15);
        illegal   = !implemented || (do_write && read_only);
    end
endmodule
