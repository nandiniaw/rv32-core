// lsu: load/store alignment, byte mask and extension (combinational).
// funct3[1:0] = size (00 byte, 01 half, 10 word), funct3[2] = unsigned load.
// Misaligned and invalid-size accesses are inert: mask, mem_wdata and load_data are 0.
// mask and mem_wdata are meaningful for stores; mask and load_data for loads.
module lsu (
    input  logic [2:0]  funct3,
    input  logic [1:0]  addr_lo,      // byte address bits [1:0]
    input  logic        is_load,
    input  logic        is_store,
    input  logic [31:0] store_data,   // rs2
    input  logic [31:0] mem_rdata,    // aligned word read from memory
    output logic [3:0]  mask,         // byte lanes accessed
    output logic [31:0] mem_wdata,    // store data in its byte lanes, other lanes 0
    output logic [31:0] load_data,    // loaded value, sign- or zero-extended
    output logic        misaligned
);
    logic [1:0]  size;
    logic        bad_align;
    logic [7:0]  ld_byte;
    logic [15:0] ld_half;

    assign size = funct3[1:0];

    always_comb begin
        case (size)
            2'b01:   bad_align = addr_lo[0];
            2'b10:   bad_align = (addr_lo != 2'b00);
            default: bad_align = 1'b0;
        endcase
    end
    assign misaligned = (is_load | is_store) & bad_align;

    always_comb begin
        mask = 4'b0000;
        if (!bad_align) begin
            case (size)
                2'b00: begin
                    case (addr_lo)
                        2'd0:    mask = 4'b0001;
                        2'd1:    mask = 4'b0010;
                        2'd2:    mask = 4'b0100;
                        default: mask = 4'b1000;
                    endcase
                end
                2'b01:   mask = addr_lo[1] ? 4'b1100 : 4'b0011;
                2'b10:   mask = 4'b1111;
                default: mask = 4'b0000;
            endcase
        end
    end

    always_comb begin
        mem_wdata = 32'd0;
        if (!bad_align) begin
            case (size)
                2'b00: begin
                    case (addr_lo)
                        2'd0:    mem_wdata = {24'd0, store_data[7:0]};
                        2'd1:    mem_wdata = {16'd0, store_data[7:0], 8'd0};
                        2'd2:    mem_wdata = {8'd0, store_data[7:0], 16'd0};
                        default: mem_wdata = {store_data[7:0], 24'd0};
                    endcase
                end
                2'b01:   mem_wdata = addr_lo[1] ? {store_data[15:0], 16'd0} : {16'd0, store_data[15:0]};
                2'b10:   mem_wdata = store_data;
                default: mem_wdata = 32'd0;
            endcase
        end
    end

    always_comb begin
        case (addr_lo)
            2'd0:    ld_byte = mem_rdata[7:0];
            2'd1:    ld_byte = mem_rdata[15:8];
            2'd2:    ld_byte = mem_rdata[23:16];
            default: ld_byte = mem_rdata[31:24];
        endcase
        ld_half = addr_lo[1] ? mem_rdata[31:16] : mem_rdata[15:0];

        load_data = 32'd0;
        if (!bad_align) begin
            case (size)
                2'b00:   load_data = funct3[2] ? {24'd0, ld_byte} : {{24{ld_byte[7]}}, ld_byte};
                2'b01:   load_data = funct3[2] ? {16'd0, ld_half} : {{16{ld_half[15]}}, ld_half};
                2'b10:   load_data = mem_rdata;
                default: load_data = 32'd0;
            endcase
        end
    end
endmodule
