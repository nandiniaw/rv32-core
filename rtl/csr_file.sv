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
    input  logic        mret_en,      // mret: MIE <- MPIE, MPIE <- 1, MPP stays
    input  logic        trap_en,      // trap entry: overrides any CSR write
    input  logic [31:0] trap_pc,
    input  logic [31:0] trap_cause,
    input  logic [31:0] trap_tval,
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
                            A_MSCRATCH = 12'h340, A_MEPC = 12'h341,
                            A_MCAUSE = 12'h342, A_MTVAL = 12'h343, A_MIP = 12'h344;

    logic        mie_q, mpie_q, mpp_set;
    logic [31:0] mie_r, mtvec_r, mscratch_r, mepc_r, mcause_r, mtval_r;

    csr_check u_check (.addr(addr), .do_write(do_write), .illegal(illegal));

    logic [31:0] cur_mstatus;
    assign cur_mstatus = {19'd0, {2{mpp_set}}, 3'd0, mpie_q, 3'd0, mie_q, 3'd0};

    always_comb begin
        case (addr)
            A_MSTATUS: rdata = cur_mstatus;
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
            A_MSTATUS:  cur = cur_mstatus;
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

    // snapshots show the state AFTER the instruction in WB (trace v2), so they use the next-state values
    logic        wr_fire, n_mie_q, n_mpie_q, n_mpp_set;
    logic [31:0] n_mie_r, n_mtvec_r, n_mscratch_r, n_mepc_r, n_mcause_r, n_mtval_r;
    assign wr_fire = en && !illegal && do_write;
    assign n_mie_q      = (wr_fire && addr == A_MSTATUS) ? nxt[3] : mie_q;
    assign n_mpie_q     = (wr_fire && addr == A_MSTATUS) ? nxt[7] : mpie_q;
    assign n_mpp_set    = (wr_fire && addr == A_MSTATUS) ? 1'b1   : mpp_set;
    assign n_mie_r      = (wr_fire && addr == A_MIE)      ? (nxt & 32'h0000_0888) : mie_r;
    assign n_mtvec_r    = (wr_fire && addr == A_MTVEC)    ? {nxt[31:2], (nxt[1] ? mtvec_r[1:0] : nxt[1:0])} : mtvec_r;
    assign n_mscratch_r = (wr_fire && addr == A_MSCRATCH) ? nxt : mscratch_r;
    assign n_mepc_r     = (wr_fire && addr == A_MEPC)     ? {nxt[31:2], 2'b00} : mepc_r;
    assign n_mcause_r   = (wr_fire && addr == A_MCAUSE && cause_ok) ? nxt : mcause_r;
    assign n_mtval_r    = (wr_fire && addr == A_MTVAL)    ? nxt : mtval_r;
    assign snap_mstatus  = trap_en ? {19'd0, 2'b11, 3'd0, mie_q, 3'd0, 1'b0, 3'd0}
                                   : mret_en ? {19'd0, {2{mpp_set}}, 3'd0, 1'b1, 3'd0, mpie_q, 3'd0}
                                   : {19'd0, {2{n_mpp_set}}, 3'd0, n_mpie_q, 3'd0, n_mie_q, 3'd0};
    assign snap_mie      = n_mie_r;
    assign snap_mtvec    = n_mtvec_r;
    assign snap_mscratch = n_mscratch_r;
    assign snap_mepc     = trap_en ? (trap_pc & 32'hFFFF_FFFC) : n_mepc_r;
    assign snap_mcause   = trap_en ? trap_cause : n_mcause_r;
    assign snap_mtval    = trap_en ? trap_tval : n_mtval_r;

    always_ff @(posedge clk) begin
        if (rst) begin
            mie_q <= 1'b0; mpie_q <= 1'b0; mpp_set <= 1'b0;
            mie_r <= 32'd0; mtvec_r <= 32'd0; mscratch_r <= 32'd0;
            mepc_r <= 32'd0; mcause_r <= 32'd0; mtval_r <= 32'd0;
        end else if (trap_en) begin
            mpie_q <= mie_q; mie_q <= 1'b0; mpp_set <= 1'b1;
            mepc_r <= trap_pc & 32'hFFFF_FFFC; mcause_r <= trap_cause; mtval_r <= trap_tval;
        end else if (mret_en) begin
            mie_q <= mpie_q; mpie_q <= 1'b1;
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
