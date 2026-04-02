`default_nettype none
`timescale 1ns/1ps

// ============================================================
//  pc_register — Program Counter register
//
//  FIX SYNCASYNCNET:
//    Original: always @(posedge clk) if (reset) ← SYNC reset
//    Other modules use: always @(posedge clk or posedge reset) ← ASYNC
//    Mixed sync/async on same reset → Verilator SYNCASYNCNET warning
//    Fix: add posedge reset to sensitivity list → consistent async reset
// ============================================================
module pc_register (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] PCF_in,
    input  wire        stallF,
    output reg  [31:0] PCF_out
);
    // FIX: async reset — matches all other pipeline stages
    always @(posedge clk or posedge reset) begin
        if (reset)
            PCF_out <= 32'd0;
        else if (!stallF)
            PCF_out <= PCF_in;
    end

endmodule

