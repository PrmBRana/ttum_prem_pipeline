`default_nettype none
`timescale 1ns / 1ps

// ============================================================
//  Control Unit
//
//  KEY FIX: halt uses blocking assignment (=) not non-blocking
//  (<=) inside always @(*) combinational block.
// ============================================================
module Control (
    input  wire [6:0]  Opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    input  wire [11:0] imm,
    output reg         halt,
    output reg         RegWriteD,
    output reg  [1:0]  ResultSrcD,
    output reg         MemWriteD,
    output reg         jumpD,
    output reg         jumpR,
    output reg         BranchD,
    output reg  [3:0]  ALUControlD,
    output reg         ALUSrcD,
    output reg  [2:0]  ImmSrc,
    output reg  [1:0]  ALUType
);


    always @(*) begin
        // ── Safe defaults ────────────────────────────────
        RegWriteD   = 1'b0;
        ResultSrcD  = 2'b00;
        MemWriteD   = 1'b0;
        jumpD       = 1'b0;
        jumpR       = 1'b0;
        BranchD     = 1'b0;
        ALUControlD = 4'b0000;
        ALUSrcD     = 1'b0;
        ImmSrc      = 3'b000;
        ALUType     = 2'b00;
        halt        = 1'b0;   // ✅ blocking assignment

        case (Opcode)

            // ── R-type ───────────────────────────────────
            7'b0110011: begin
                RegWriteD = 1'b1;
                ALUSrcD   = 1'b0;
                ALUType   = 2'b00;
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: ALUControlD = 4'b0010; // ADD
                    {7'b0100000, 3'b000}: ALUControlD = 4'b0011; // SUB
                    {7'b0000000, 3'b110}: ALUControlD = 4'b0001; // OR
                    {7'b0000000, 3'b111}: ALUControlD = 4'b0000; // AND
                    {7'b0000000, 3'b100}: ALUControlD = 4'b0100; // XOR
                    {7'b0000000, 3'b001}: ALUControlD = 4'b0101; // SLL
                    {7'b0000000, 3'b101}: ALUControlD = 4'b0110; // SRL
                    {7'b0100000, 3'b101}: ALUControlD = 4'b0111; // SRA
                    {7'b0000000, 3'b010}: ALUControlD = 4'b1000; // SLT
                    {7'b0000000, 3'b011}: ALUControlD = 4'b1001; // SLTU
                    default:              ALUControlD = 4'b0000;
                endcase
            end

            // ── I-type ALU ───────────────────────────────
            7'b0010011: begin
                RegWriteD = 1'b1;
                ALUSrcD   = 1'b1;
                ImmSrc    = 3'b000;
                ALUType   = 2'b00;
                case (funct3)
                    3'b000: ALUControlD = 4'b0010; // ADDI
                    3'b100: ALUControlD = 4'b0100; // XORI
                    3'b110: ALUControlD = 4'b0001; // ORI
                    3'b111: ALUControlD = 4'b0000; // ANDI
                    3'b001: ALUControlD = 4'b0101; // SLLI
                    3'b101: ALUControlD = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // SRAI:SRLI
                    3'b010: ALUControlD = 4'b1000; // SLTI
                    3'b011: ALUControlD = 4'b1001; // SLTIU
                    default: ALUControlD = 4'b0000;
                endcase
            end

            // ── LOAD ─────────────────────────────────────
            7'b0000011: begin
                RegWriteD   = 1'b1;
                ResultSrcD  = 2'b01;   // data from memory
                ALUSrcD     = 1'b1;
                ImmSrc      = 3'b000;
                ALUControlD = 4'b0010; // ADD (address calc)
                ALUType     = 2'b00;
            end

            // ── STORE ────────────────────────────────────
            7'b0100011: begin
                MemWriteD   = 1'b1;
                ALUSrcD     = 1'b1;
                ImmSrc      = 3'b001;  // S-type
                ALUControlD = 4'b0010; // ADD (address calc)
                ALUType     = 2'b01;
            end

            // ── BRANCH ───────────────────────────────────
            7'b1100011: begin
                BranchD = 1'b1;
                ALUSrcD = 1'b0;
                ImmSrc  = 3'b010;      // B-type
                ALUType = 2'b10;
                case (funct3)
                    3'b000: ALUControlD = 4'b0000; // BEQ
                    3'b001: ALUControlD = 4'b0001; // BNE
                    3'b100: ALUControlD = 4'b0010; // BLT
                    3'b101: ALUControlD = 4'b0011; // BGE
                    3'b110: ALUControlD = 4'b0100; // BLTU
                    3'b111: ALUControlD = 4'b0101; // BGEU
                    default: ALUControlD = 4'b0000;
                endcase
            end

            // ── JAL ──────────────────────────────────────
            7'b1101111: begin
                RegWriteD   = 1'b1;
                ResultSrcD  = 2'b10;   // PC+4
                jumpD       = 1'b1;
                jumpR       = 1'b0;
                ImmSrc      = 3'b011;  // J-type
                ALUSrcD     = 1'b1;
                ALUControlD = 4'b0010;
                ALUType     = 2'b11;
            end

            // ── JALR ─────────────────────────────────────
            7'b1100111: begin
                RegWriteD   = 1'b1;
                ResultSrcD  = 2'b10;
                jumpD       = 1'b1;
                jumpR       = 1'b1;
                ALUSrcD     = 1'b1;
                ImmSrc      = 3'b000;
                ALUControlD = 4'b0010;
                ALUType     = 2'b11;
            end

            // ── LUI ──────────────────────────────────────
            7'b0110111: begin
                RegWriteD   = 1'b1;
                ResultSrcD  = 2'b00;
                ALUSrcD     = 1'b1;
                ImmSrc      = 3'b100;  // U-type
                ALUControlD = 4'b0010;
                ALUType     = 2'b00;
            end

            // ── AUIPC ────────────────────────────────────
            7'b0010111: begin
                RegWriteD   = 1'b1;
                ResultSrcD  = 2'b00;
                ALUSrcD     = 1'b1;
                ImmSrc      = 3'b100;
                ALUControlD = 4'b0010;
                ALUType     = 2'b00;
            end

            // ── ECALL / EBREAK ───────────────────────────
            7'b1110011: begin
                if (funct3 == 3'b000) begin
                    // ✅ blocking assignment in combinational block
                    halt = (imm == 12'h000 || imm == 12'h001) ? 1'b1 : 1'b0;
                end
            end

            default: begin
                // All signals already defaulted above
            end

        endcase
    end

endmodule

