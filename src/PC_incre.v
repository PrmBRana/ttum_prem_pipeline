`default_nettype none
module PC_incre (
    input  wire [31:0] pc,      // Current program counter
    output wire [31:0] PCPlus4  // Next sequential PC (pc + 4)
);
    assign PCPlus4 = pc + 32'd4; // Increment PC by 4 (word-aligned)
endmodule
