module mem1KB_32bit (
    input  wire        clk,
    input  wire        we,
    input  wire [7:0]  addr,
    input  wire [31:0] wdata,
    input  wire [31:0] read_Address,
    output wire [31:0] Instruction_out
);

    localparam integer DEPTH = 128;  // ✅ plain integer, no width limit
    reg [31:0] mem [0:DEPTH-1];      // [0:255] = 256 entries = 1KB

    // Write
    always @(posedge clk) begin
        if (we && addr != 8'hFF)     // ✅ addr is 8-bit, max index is 255
            mem[addr] <= wdata;
    end
    

    // Read
    assign Instruction_out = mem[read_Address[8:2]];

endmodule

