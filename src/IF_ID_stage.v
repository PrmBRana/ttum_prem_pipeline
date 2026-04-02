`default_nettype none
`timescale 1ns / 1ps

// ============================================================
//  IF_ID_stage — IF/ID Pipeline Register
//
//  FIX: flushD must clear PC values too
//
//  Old (wrong):
//    flushD → instruction=NOP, but PC_out = retained (old SW pc)
//    → decode stage computes branch from wrong PC
//
//  New (correct):
//    flushD → instruction=NOP, PC=0, PCplus4=0
//    → clean bubble passes through pipeline
//
//  Priority:
//    1. reset  — clear everything
//    2. flushD — insert NOP bubble, clear PC
//    3. !stallD — normal advance
//    4. stallD  — hold (retain all)
// ============================================================
module IF_ID_stage (
    input wire        clk,
    input wire        reset,
    input wire        stallD,
    input wire        flushD,
    input wire [31:0] PC_in,
    input wire [31:0] PCplus4_in,
    input wire [31:0] instruction_in,
    output reg [31:0] instruction_out,
    output reg [31:0] PCplus4_out,
    output reg [31:0] PC_out
);

    always @(posedge clk) begin
        if (reset) begin
            instruction_out <= 32'b0;
            PCplus4_out     <= 32'b0;
            PC_out          <= 32'b0;
        end
        else if (flushD) begin
            // Insert NOP bubble — clear everything
            instruction_out <= 32'h00000013;  // addi x0,x0,0
            PCplus4_out     <= 32'b0;         // FIX: clear, not retain
            PC_out          <= 32'b0;         // FIX: clear, not retain
        end
        else if (!stallD) begin
            // Normal pipeline advance
            instruction_out <= instruction_in;
            PCplus4_out     <= PCplus4_in;
            PC_out          <= PC_in;
        end
        // else: stallD=1 → retain all (implicit, reg holds value)
    end
endmodule

