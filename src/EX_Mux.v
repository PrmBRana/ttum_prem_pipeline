`default_nettype none
`timescale 1ns/1ps
// ============================================================
//  EX_Mux.v — Execute stage combinational logic
// ── Merged forwarding muxes ───────────────────────────────────
module EX_Mux(
    input  wire [31:0] RD1,
    input  wire [31:0] resultW,
    input  wire [31:0] ALUres,
    input  wire [1:0]  ForwardAE,
    output wire [31:0] ScrA,

    input  wire [31:0] RD2,
    input  wire [31:0] ResWrite,
    input  wire [31:0] ALURes,
    input  wire [1:0]  ForwardBE,
    output wire [31:0] outB,

    input  wire [31:0] ImmEx,
    input  wire        ALUSCRE,
    output wire [31:0] SCRB
);
    assign ScrA = (ForwardAE == 2'b10) ? ALUres   :
                  (ForwardAE == 2'b01) ? resultW  : RD1;

    assign outB = (ForwardBE == 2'b10) ? ALURes   :
                  (ForwardBE == 2'b01) ? ResWrite : RD2;

    assign SCRB = ALUSCRE ? ImmEx : outB;
endmodule


// ── PC target adder ───────────────────────────────────────────
module Adder(
    input  wire [31:0] pc_E,
    input  wire [31:0] rd1_E,
    input  wire [31:0] imm_2,
    input  wire        JumpR,
    output wire [31:0] PCTarget
);
    wire [31:0] base_addr = JumpR ? rd1_E : pc_E;
    assign PCTarget = JumpR ? ((base_addr + imm_2) & 32'hFFFF_FFFE)
                            :  (base_addr + imm_2);
endmodule


