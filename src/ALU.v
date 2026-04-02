`default_nettype none
`timescale 1ns / 1ps

// ============================================================
//  ALU
//
//  ALUType encoding:
//    2'b00 = R/I-type  (arithmetic/logic)
//    2'b01 = S-type    (store address = ScrA + ScrB)
//    2'b10 = B-type    (branch comparison → Zero flag)
//    2'b11 = J-type    (jump target = ScrA + ScrB)
//
//  KEY NOTE on LUI:
//    LUI sets ScrA=0 via the register file (x0 forwarded),
//    ScrB = upper immediate. ALU computes 0 + imm = imm. ✅
//    This works correctly as long as MUX_A selects x0 for LUI.
// ============================================================
module ALU (
    input  wire [31:0] ScrA,
    input  wire [31:0] ScrB,
    input  wire [3:0]  ALUControl,
    input  wire [1:0]  ALUType,
    output reg  [31:0] ALUResult,
    output reg         Zero
);


    always @(*) begin
        ALUResult = 32'd0;
        Zero      = 1'b0;

        case (ALUType)

            // ── R/I-type: arithmetic and logic ───────────
            2'b00: begin
                case (ALUControl)
                    4'b0010: ALUResult = ScrA + ScrB;                           // ADD / ADDI / LUI(0+imm)
                    4'b0011: ALUResult = ScrA - ScrB;                           // SUB
                    4'b0000: ALUResult = ScrA & ScrB;                           // AND / ANDI
                    4'b0001: ALUResult = ScrA | ScrB;                           // OR  / ORI
                    4'b0100: ALUResult = ScrA ^ ScrB;                           // XOR / XORI
                    4'b0101: ALUResult = ScrA << ScrB[4:0];                     // SLL / SLLI
                    4'b0110: ALUResult = ScrA >> ScrB[4:0];                     // SRL / SRLI
                    4'b0111: ALUResult = $signed(ScrA) >>> ScrB[4:0];           // SRA / SRAI
                    4'b1000: ALUResult = ($signed(ScrA) < $signed(ScrB)) ? 32'd1 : 32'd0; // SLT
                    4'b1001: ALUResult = (ScrA < ScrB) ? 32'd1 : 32'd0;        // SLTU
                    default: ALUResult = 32'd0;
                endcase
            end

            // ── S-type: store address ─────────────────────
            2'b01: begin
                ALUResult = ScrA + ScrB;
            end

            // ── B-type: branch comparison ─────────────────
            //    Zero=1 → branch taken
            2'b10: begin
                ALUResult = 32'd0;
                case (ALUControl)
                    4'b0000: Zero = (ScrA == ScrB);                             // BEQ
                    4'b0001: Zero = (ScrA != ScrB);                             // BNE
                    4'b0010: Zero = ($signed(ScrA) <  $signed(ScrB));           // BLT
                    4'b0011: Zero = ($signed(ScrA) >= $signed(ScrB));           // BGE ✅
                    4'b0100: Zero = (ScrA <  ScrB);                             // BLTU
                    4'b0101: Zero = (ScrA >= ScrB);                             // BGEU
                    default: Zero = 1'b0;
                endcase
            end

            // ── J-type: jump target ───────────────────────
            2'b11: begin
                ALUResult = ScrA + ScrB;
            end

            default: begin
                ALUResult = 32'd0;
                Zero      = 1'b0;
            end

        endcase
    end

endmodule

