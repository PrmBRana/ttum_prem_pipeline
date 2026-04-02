`default_nettype none

module imm (
    input  wire [2:0]  ImmSrc,      // Immediate selector
    input  wire [31:0] instruction, // Full instruction
    output reg  [31:0] ImmExt
);


    wire _unused = &{1'b0, instruction[6:0]}; // silence unused bits warning

    always @(*) begin
        case (ImmSrc)

            // I-type (addi, load, jalr)
            3'b000: begin
                ImmExt = {{20{instruction[31]}}, instruction[31:20]};
            end

            // S-type (store)
            3'b001: begin
                ImmExt = {{20{instruction[31]}},
                          instruction[31:25],
                          instruction[11:7]};
            end

            // B-type (branch)  ✅ FIXED
            3'b010: begin
                ImmExt = {{19{instruction[31]}},
                          instruction[31],   // <<<<<< MISSING BEFORE
                          instruction[7],
                          instruction[30:25],
                          instruction[11:8],
                          1'b0};
            end

            // J-type (jal)  ✅ FIXED
            3'b011: begin
                ImmExt = {{11{instruction[31]}},
                          instruction[31],   // <<<<<< MISSING BEFORE
                          instruction[19:12],
                          instruction[20],
                          instruction[30:21],
                          1'b0};
            end

            // U-type (lui, auipc)
            3'b100: begin
                ImmExt = {instruction[31:12], 12'b0};
            end

            default: begin
                ImmExt = 32'b0;
            end
        endcase
    end
endmodule


