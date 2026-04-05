`default_nettype none
`timescale 1ns / 1ps

module Reg_file (
    input  wire        clk,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire        Regwrite,
    input  wire [31:0] Write_data,
    output wire [31:0] Read_data1,
    output wire [31:0] Read_data2
);
    reg [31:0] r1,  r2,  r3,  r4,  r5,  r6,  r7,  r8,
               r9,  r10, r11, r12, r13, r14, r15, r16,
               r17, r18, r19, r20, r21, r22, r23, r24,
               r25, r26, r27, r28, r29, r30, r31;

    // ── Explicit fanout buffers for Write_data ────────────────
    // Write_data fans out to 31×32=992 FF inputs.
    // Split into 4 groups of ~8 regs to keep fanout ≤ 256.
    (* keep *) wire [31:0] wdata_a = Write_data; // r1–r8
    (* keep *) wire [31:0] wdata_b = Write_data; // r9–r16
    (* keep *) wire [31:0] wdata_c = Write_data; // r17–r24
    (* keep *) wire [31:0] wdata_d = Write_data; // r25–r31

    // ── One always per register — one $proc per reg in Yosys ──
    always @(posedge clk) if (Regwrite && rd_addr==5'd1)  r1  <= wdata_a;
    always @(posedge clk) if (Regwrite && rd_addr==5'd2)  r2  <= wdata_a;
    always @(posedge clk) if (Regwrite && rd_addr==5'd3)  r3  <= wdata_a;
    always @(posedge clk) if (Regwrite && rd_addr==5'd4)  r4  <= wdata_a;
    always @(posedge clk) if (Regwrite && rd_addr==5'd5)  r5  <= wdata_a;
    always @(posedge clk) if (Regwrite && rd_addr==5'd6)  r6  <= wdata_a;
    always @(posedge clk) if (Regwrite && rd_addr==5'd7)  r7  <= wdata_a;
    always @(posedge clk) if (Regwrite && rd_addr==5'd8)  r8  <= wdata_a;

    always @(posedge clk) if (Regwrite && rd_addr==5'd9)  r9  <= wdata_b;
    always @(posedge clk) if (Regwrite && rd_addr==5'd10) r10 <= wdata_b;
    always @(posedge clk) if (Regwrite && rd_addr==5'd11) r11 <= wdata_b;
    always @(posedge clk) if (Regwrite && rd_addr==5'd12) r12 <= wdata_b;
    always @(posedge clk) if (Regwrite && rd_addr==5'd13) r13 <= wdata_b;
    always @(posedge clk) if (Regwrite && rd_addr==5'd14) r14 <= wdata_b;
    always @(posedge clk) if (Regwrite && rd_addr==5'd15) r15 <= wdata_b;
    always @(posedge clk) if (Regwrite && rd_addr==5'd16) r16 <= wdata_b;

    always @(posedge clk) if (Regwrite && rd_addr==5'd17) r17 <= wdata_c;
    always @(posedge clk) if (Regwrite && rd_addr==5'd18) r18 <= wdata_c;
    always @(posedge clk) if (Regwrite && rd_addr==5'd19) r19 <= wdata_c;
    always @(posedge clk) if (Regwrite && rd_addr==5'd20) r20 <= wdata_c;
    always @(posedge clk) if (Regwrite && rd_addr==5'd21) r21 <= wdata_c;
    always @(posedge clk) if (Regwrite && rd_addr==5'd22) r22 <= wdata_c;
    always @(posedge clk) if (Regwrite && rd_addr==5'd23) r23 <= wdata_c;
    always @(posedge clk) if (Regwrite && rd_addr==5'd24) r24 <= wdata_c;

    always @(posedge clk) if (Regwrite && rd_addr==5'd25) r25 <= wdata_d;
    always @(posedge clk) if (Regwrite && rd_addr==5'd26) r26 <= wdata_d;
    always @(posedge clk) if (Regwrite && rd_addr==5'd27) r27 <= wdata_d;
    always @(posedge clk) if (Regwrite && rd_addr==5'd28) r28 <= wdata_d;
    always @(posedge clk) if (Regwrite && rd_addr==5'd29) r29 <= wdata_d;
    always @(posedge clk) if (Regwrite && rd_addr==5'd30) r30 <= wdata_d;
    always @(posedge clk) if (Regwrite && rd_addr==5'd31) r31 <= wdata_d;

    // ── Read mux port 1 ───────────────────────────────────────
    wire [31:0] rs1_stored =
        (rs1_addr==5'd1)  ? r1  : (rs1_addr==5'd2)  ? r2  :
        (rs1_addr==5'd3)  ? r3  : (rs1_addr==5'd4)  ? r4  :
        (rs1_addr==5'd5)  ? r5  : (rs1_addr==5'd6)  ? r6  :
        (rs1_addr==5'd7)  ? r7  : (rs1_addr==5'd8)  ? r8  :
        (rs1_addr==5'd9)  ? r9  : (rs1_addr==5'd10) ? r10 :
        (rs1_addr==5'd11) ? r11 : (rs1_addr==5'd12) ? r12 :
        (rs1_addr==5'd13) ? r13 : (rs1_addr==5'd14) ? r14 :
        (rs1_addr==5'd15) ? r15 : (rs1_addr==5'd16) ? r16 :
        (rs1_addr==5'd17) ? r17 : (rs1_addr==5'd18) ? r18 :
        (rs1_addr==5'd19) ? r19 : (rs1_addr==5'd20) ? r20 :
        (rs1_addr==5'd21) ? r21 : (rs1_addr==5'd22) ? r22 :
        (rs1_addr==5'd23) ? r23 : (rs1_addr==5'd24) ? r24 :
        (rs1_addr==5'd25) ? r25 : (rs1_addr==5'd26) ? r26 :
        (rs1_addr==5'd27) ? r27 : (rs1_addr==5'd28) ? r28 :
        (rs1_addr==5'd29) ? r29 : (rs1_addr==5'd30) ? r30 :
        (rs1_addr==5'd31) ? r31 : 32'd0;

    // ── Read mux port 2 ───────────────────────────────────────
    wire [31:0] rs2_stored =
        (rs2_addr==5'd1)  ? r1  : (rs2_addr==5'd2)  ? r2  :
        (rs2_addr==5'd3)  ? r3  : (rs2_addr==5'd4)  ? r4  :
        (rs2_addr==5'd5)  ? r5  : (rs2_addr==5'd6)  ? r6  :
        (rs2_addr==5'd7)  ? r7  : (rs2_addr==5'd8)  ? r8  :
        (rs2_addr==5'd9)  ? r9  : (rs2_addr==5'd10) ? r10 :
        (rs2_addr==5'd11) ? r11 : (rs2_addr==5'd12) ? r12 :
        (rs2_addr==5'd13) ? r13 : (rs2_addr==5'd14) ? r14 :
        (rs2_addr==5'd15) ? r15 : (rs2_addr==5'd16) ? r16 :
        (rs2_addr==5'd17) ? r17 : (rs2_addr==5'd18) ? r18 :
        (rs2_addr==5'd19) ? r19 : (rs2_addr==5'd20) ? r20 :
        (rs2_addr==5'd21) ? r21 : (rs2_addr==5'd22) ? r22 :
        (rs2_addr==5'd23) ? r23 : (rs2_addr==5'd24) ? r24 :
        (rs2_addr==5'd25) ? r25 : (rs2_addr==5'd26) ? r26 :
        (rs2_addr==5'd27) ? r27 : (rs2_addr==5'd28) ? r28 :
        (rs2_addr==5'd29) ? r29 : (rs2_addr==5'd30) ? r30 :
        (rs2_addr==5'd31) ? r31 : 32'd0;

    assign Read_data1 = (Regwrite && rd_addr != 5'd0 && rd_addr == rs1_addr)
                        ? Write_data : rs1_stored;
    assign Read_data2 = (Regwrite && rd_addr != 5'd0 && rd_addr == rs2_addr)
                        ? Write_data : rs2_stored;
endmodule


