`default_nettype none
`timescale 1ns / 1ps

// ============================================================
//  Reg_file — 32x32 Register File
//
//  CRITICAL FIX: Write-then-read forwarding
//
//  Problem:
//    Write is sequential (posedge clk) — data enters Register
//    on the NEXT clock edge.
//    Read is combinational — reads Register immediately.
//
//    When lw WB and sw ID are in the same cycle:
//      lw  WB: Regwrite=1, rd_addr=x5, Write_data=0x52
//      sw  ID: rs2_addr=x5
//              Read_data2 = Register[x5] = 0x00  ← OLD!
//              (0x52 not yet written — happens at next posedge)
//
//    Result: sw gets 0x00 → UART sends null byte
//    This happens even with NOPs because Hazard Unit forwards
//    from ResultW (combinational), but RegFile read still
//    returns stale value on same-cycle write.
//
//  Fix: combinational bypass — if read address matches write
//  address and write is enabled, return Write_data directly.
//  This is standard "write-first" register file behavior.
// ============================================================
module Reg_file (
    input  wire        clk,
    input  wire        reset,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire        Regwrite,
    input  wire [31:0] Write_data,
    output wire [31:0] Read_data1,
    output wire [31:0] Read_data2
);

    integer k;
    reg [31:0] Register [0:31];

    // Sequential write
    always @(posedge clk) begin
        if (reset) begin
            for (k = 0; k < 32; k = k + 1)
                Register[k] <= 32'd0;
        end
        else if (Regwrite && rd_addr != 5'd0) begin
            Register[rd_addr] <= Write_data;
        end
    end

    // Combinational read with write-then-read forwarding
    //
    // If the address being read matches the address being written
    // this cycle, return Write_data directly instead of the
    // (not-yet-updated) Register value.
    //
    // x0 is always 0 — never forward to x0.
    assign Read_data1 = (rs1_addr == 5'd0)                    ? 32'd0      :
                        (Regwrite && rd_addr == rs1_addr)      ? Write_data :
                        Register[rs1_addr];

    assign Read_data2 = (rs2_addr == 5'd0)                    ? 32'd0      :
                        (Regwrite && rd_addr == rs2_addr)      ? Write_data :
                        Register[rs2_addr];

endmodule
