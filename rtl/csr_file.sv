// csr_file: M-mode CSR file (Phase 4 step A). Combinational read/illegal, write at posedge when en && !illegal && do_write.
// op: 1 = write, 2 = set, 3 = clear. Rules follow docs/sail_csr_behaviour.md (measured on Sail 0.15) and decisions D4, D8, D9.
// Trap entry / mret ports are added in step B.
module csr_file (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,
    input  logic [11:0] addr,
    input  logic [1:0]  op,
    input  logic [31:0] src,
    input  logic        do_write,
    output logic [31:0] rdata,
    output logic        illegal,
    output logic [31:0] snap_mstatus,
    output logic [31:0] snap_mie,
    output logic [31:0] snap_mtvec,
    output logic [31:0] snap_mscratch,
    output logic [31:0] snap_mepc,
    output logic [31:0] snap_mcause,
    output logic [31:0] snap_mtval
);
    localparam logic [11:0] A_MSTATUS = 12'h300, A_MISA = 12'h301, A_MIE = 12'h304, A_MTVEC = 12'h305,
                            A_MSTATUSH = 12'h310, A_MSCRATCH = 12'h340, A_MEPC = 12'h341,
                            A_MCAUSE = 12'h342, A_MTVAL = 12'h343, A_MIP = 12'h344;

    logic        mie_q, mpie_q, mpp_set;
    logic [31:0] mie_r, mtvec_r, mscratch_r, mepc_r, mcause_r, mtval_r;

    logic is_id, implemented;
    assign is_id = (addr >= 12'hF11) && (addr <= 12'hF15);
    always_comb begin
        case (addr)
            A_MSTATUS, A_MISA, A_MIE, A_MTVEC, A_MSTATUSH, A_MSCRATCH, A_MEPC, A_MCAUSE, A_MTVAL, A_MIP: implemented = 1'b1;
            default: implemented = is_id;
        endcase
    end
    assign illegal = !implemented || (is_id && do_write);

    assign snap_mstatus  = {19'd0, {2{mpp_set}}, 3'd0, mpie_q, 3'd0, mie_q, 3'd0};
    assign snap_mie      = mie_r;
    assign snap_mtvec    = mtvec_r;
    assign snap_mscratch = mscratch_r;
    assign snap_mepc     = mepc_r;
    assign snap_mcause   = mcause_r;
    assign snap_mtval    = mtval_r;

    always_comb begin
        case (addr)
            A_MSTATUS: rdata = snap_mstatus;
            A_MISA:    rdata = 32'h4000_0100;
            A_MIE:     rdata = mie_r;
            A_MTVEC:   rdata = mtvec_r;
            A_MSCRATCH: rdata = mscratch_r;
            A_MEPC:    rdata = mepc_r;
            A_MCAUSE:  rdata = mcause_r;
            A_MTVAL:   rdata = mtval_r;
            A_MIP:     rdata = 32'h0000_0080;
            default:   rdata = 32'd0;    // mstatush and the ID CSRs read 0
        endcase
    end

    // value after applying op to the current register value
    logic [31:0] cur, nxt;
    always_comb begin
        case (addr)
            A_MSTATUS:  cur = snap_mstatus;
            A_MIE:      cur = mie_r;
            A_MTVEC:    cur = mtvec_r;
            A_MSCRATCH: cur = mscratch_r;
            A_MEPC:     cur = mepc_r;
            A_MCAUSE:   cur = mcause_r;
            A_MTVAL:    cur = mtval_r;
            default:    cur = 32'd0;
        endcase
        case (op)
            2'd2:    nxt = cur | src;
            2'd3:    nxt = cur & ~src;
            default: nxt = src;
        endcase
    end

    // mcause write rule (D8): exception codes 0-9, 0xB, 0xC, 0xD, 0xF, 0x13; interrupt codes 1, 3, 5, 7, 9, 0xB
    logic cause_ok;
    always_comb begin
        cause_ok = 1'b0;
        if (nxt[30:6] == 25'd0) begin
            if (!nxt[31]) begin
                case (nxt[5:0])
                    6'd0, 6'd1, 6'd2, 6'd3, 6'd4, 6'd5, 6'd6, 6'd7, 6'd8, 6'd9,
                    6'd11, 6'd12, 6'd13, 6'd15, 6'd19: cause_ok = 1'b1;
                    default: ;
                endcase
            end else begin
                case (nxt[5:0])
                    6'd1, 6'd3, 6'd5, 6'd7, 6'd9, 6'd11: cause_ok = 1'b1;
                    default: ;
                endcase
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            mie_q <= 1'b0; mpie_q <= 1'b0; mpp_set <= 1'b0;
            mie_r <= 32'd0; mtvec_r <= 32'd0; mscratch_r <= 32'd0;
            mepc_r <= 32'd0; mcause_r <= 32'd0; mtval_r <= 32'd0;
        end else if (en && !illegal && do_write) begin
            case (addr)
                A_MSTATUS: begin mie_q <= nxt[3]; mpie_q <= nxt[7]; mpp_set <= 1'b1; end
                A_MIE:      mie_r <= nxt & 32'h0000_0888;
                A_MTVEC:    mtvec_r <= {nxt[31:2], (nxt[1] ? mtvec_r[1:0] : nxt[1:0])};
                A_MSCRATCH: mscratch_r <= nxt;
                A_MEPC:     mepc_r <= {nxt[31:2], 2'b00};
                A_MCAUSE:   if (cause_ok) mcause_r <= nxt;
                A_MTVAL:    mtval_r <= nxt;
                default: ;
            endcase
        end
    end
endmodule
