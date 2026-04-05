`default_nettype none
`timescale 1ns / 1ps

module mem1KB_32bit #(
    parameter DEPTH = 32
)(
    input  wire                     clk,
    input  wire                     reset,
    input  wire                     we,
    input  wire [$clog2(DEPTH)-1:0] addr,
    input  wire [31:0]              wdata,
    input  wire [31:0]              read_Address,
    output wire [31:0]              Instruction_out
);
    localparam ADDR_W = $clog2(DEPTH); // = 5 for DEPTH=32
    localparam NOP    = 32'h0000_0013;

    /* verilator lint_off UNUSEDSIGNAL */
    wire _unused_pc = &{1'b0, read_Address[31:ADDR_W+2], read_Address[1:0]};
    /* verilator lint_on UNUSEDSIGNAL */

    // ── 32 scalar regs — no $mem, no Yosys crash ──────────────
    reg [31:0] m00,m01,m02,m03,m04,m05,m06,m07;
    reg [31:0] m08,m09,m10,m11,m12,m13,m14,m15;
    reg [31:0] m16,m17,m18,m19,m20,m21,m22,m23;
    reg [31:0] m24,m25,m26,m27,m28,m29,m30,m31;

    always @(posedge clk) if(reset) m00<=NOP; else if(we&&addr==5'd0)  m00<=wdata;
    always @(posedge clk) if(reset) m01<=NOP; else if(we&&addr==5'd1)  m01<=wdata;
    always @(posedge clk) if(reset) m02<=NOP; else if(we&&addr==5'd2)  m02<=wdata;
    always @(posedge clk) if(reset) m03<=NOP; else if(we&&addr==5'd3)  m03<=wdata;
    always @(posedge clk) if(reset) m04<=NOP; else if(we&&addr==5'd4)  m04<=wdata;
    always @(posedge clk) if(reset) m05<=NOP; else if(we&&addr==5'd5)  m05<=wdata;
    always @(posedge clk) if(reset) m06<=NOP; else if(we&&addr==5'd6)  m06<=wdata;
    always @(posedge clk) if(reset) m07<=NOP; else if(we&&addr==5'd7)  m07<=wdata;
    always @(posedge clk) if(reset) m08<=NOP; else if(we&&addr==5'd8)  m08<=wdata;
    always @(posedge clk) if(reset) m09<=NOP; else if(we&&addr==5'd9)  m09<=wdata;
    always @(posedge clk) if(reset) m10<=NOP; else if(we&&addr==5'd10) m10<=wdata;
    always @(posedge clk) if(reset) m11<=NOP; else if(we&&addr==5'd11) m11<=wdata;
    always @(posedge clk) if(reset) m12<=NOP; else if(we&&addr==5'd12) m12<=wdata;
    always @(posedge clk) if(reset) m13<=NOP; else if(we&&addr==5'd13) m13<=wdata;
    always @(posedge clk) if(reset) m14<=NOP; else if(we&&addr==5'd14) m14<=wdata;
    always @(posedge clk) if(reset) m15<=NOP; else if(we&&addr==5'd15) m15<=wdata;
    always @(posedge clk) if(reset) m16<=NOP; else if(we&&addr==5'd16) m16<=wdata;
    always @(posedge clk) if(reset) m17<=NOP; else if(we&&addr==5'd17) m17<=wdata;
    always @(posedge clk) if(reset) m18<=NOP; else if(we&&addr==5'd18) m18<=wdata;
    always @(posedge clk) if(reset) m19<=NOP; else if(we&&addr==5'd19) m19<=wdata;
    always @(posedge clk) if(reset) m20<=NOP; else if(we&&addr==5'd20) m20<=wdata;
    always @(posedge clk) if(reset) m21<=NOP; else if(we&&addr==5'd21) m21<=wdata;
    always @(posedge clk) if(reset) m22<=NOP; else if(we&&addr==5'd22) m22<=wdata;
    always @(posedge clk) if(reset) m23<=NOP; else if(we&&addr==5'd23) m23<=wdata;
    always @(posedge clk) if(reset) m24<=NOP; else if(we&&addr==5'd24) m24<=wdata;
    always @(posedge clk) if(reset) m25<=NOP; else if(we&&addr==5'd25) m25<=wdata;
    always @(posedge clk) if(reset) m26<=NOP; else if(we&&addr==5'd26) m26<=wdata;
    always @(posedge clk) if(reset) m27<=NOP; else if(we&&addr==5'd27) m27<=wdata;
    always @(posedge clk) if(reset) m28<=NOP; else if(we&&addr==5'd28) m28<=wdata;
    always @(posedge clk) if(reset) m29<=NOP; else if(we&&addr==5'd29) m29<=wdata;
    always @(posedge clk) if(reset) m30<=NOP; else if(we&&addr==5'd30) m30<=wdata;
    always @(posedge clk) if(reset) m31<=NOP; else if(we&&addr==5'd31) m31<=wdata;

    wire [4:0] pc_word = read_Address[ADDR_W+1:2];

    assign Instruction_out =
        (pc_word==5'd0)  ? m00 : (pc_word==5'd1)  ? m01 :
        (pc_word==5'd2)  ? m02 : (pc_word==5'd3)  ? m03 :
        (pc_word==5'd4)  ? m04 : (pc_word==5'd5)  ? m05 :
        (pc_word==5'd6)  ? m06 : (pc_word==5'd7)  ? m07 :
        (pc_word==5'd8)  ? m08 : (pc_word==5'd9)  ? m09 :
        (pc_word==5'd10) ? m10 : (pc_word==5'd11) ? m11 :
        (pc_word==5'd12) ? m12 : (pc_word==5'd13) ? m13 :
        (pc_word==5'd14) ? m14 : (pc_word==5'd15) ? m15 :
        (pc_word==5'd16) ? m16 : (pc_word==5'd17) ? m17 :
        (pc_word==5'd18) ? m18 : (pc_word==5'd19) ? m19 :
        (pc_word==5'd20) ? m20 : (pc_word==5'd21) ? m21 :
        (pc_word==5'd22) ? m22 : (pc_word==5'd23) ? m23 :
        (pc_word==5'd24) ? m24 : (pc_word==5'd25) ? m25 :
        (pc_word==5'd26) ? m26 : (pc_word==5'd27) ? m27 :
        (pc_word==5'd28) ? m28 : (pc_word==5'd29) ? m29 :
        (pc_word==5'd30) ? m30 : m31;
endmodule

