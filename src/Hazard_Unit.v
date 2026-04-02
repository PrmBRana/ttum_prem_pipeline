`default_nettype none
`timescale 1ns / 1ps

// ============================================================
//  Hazard Unit
//
//  No FlushM needed — EX_stage fix handles null byte issue:
//    flushE zeros RD1,RD2,MemWrite in EX register
//    → bubble passes through MEM with MemWrite=0
//    → UART never receives null write
//
//  FlushE added to load-use hazard (existing fix):
//    prevents stale register read after lw
// ============================================================
module Hazard_Unit (
    input  wire [4:0]  Rs1D,
    input  wire [4:0]  Rs2D,
    input  wire [4:0]  Rs1E,
    input  wire [4:0]  Rs2E,
    input  wire [4:0]  RdE,
    input  wire        RegWriteE,
    input  wire [1:0]  ResultSrcE_in,
    input  wire [4:0]  RdM,
    input  wire        RegWriteM,
    input  wire [4:0]  RdW,
    input  wire        RegWriteW,
    input  wire        PCSRCE,
    output reg         StallF,
    output reg         StallD,
    output reg         FlushD,
    output reg         FlushE,
    output reg  [1:0]  Forward_AE,
    output reg  [1:0]  Forward_BE
);


    // Load-use hazard: lw in EX, dependent instr in DE
    wire load_use_hazard = (ResultSrcE_in == 2'b01) &&
                            RegWriteE                &&
                           (RdE != 5'b0)             &&
                           ((Rs1D == RdE) || (Rs2D == RdE));

    always @(*) begin
        // Defaults
        Forward_AE = 2'b00;
        Forward_BE = 2'b00;
        StallF     = 1'b0;
        StallD     = 1'b0;
        FlushD     = 1'b0;
        FlushE     = 1'b0;

        // 1. Forwarding
        if      ((Rs1E == RdM) && RegWriteM && (Rs1E != 5'b0)) Forward_AE = 2'b10;
        else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 5'b0)) Forward_AE = 2'b01;

        if      ((Rs2E == RdM) && RegWriteM && (Rs2E != 5'b0)) Forward_BE = 2'b10;
        else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 5'b0)) Forward_BE = 2'b01;

        // 2. Load-use hazard — stall + bubble
        if (load_use_hazard) begin
            StallF = 1'b1;
            StallD = 1'b1;
            FlushE = 1'b1;
        end

        // 3. Branch/jump — higher priority
        if (PCSRCE) begin
            FlushD = 1'b1;
            FlushE = 1'b1;   // zeros EX register → safe bubble to MEM
            StallF = 1'b0;
            StallD = 1'b0;
        end
    end

endmodule

