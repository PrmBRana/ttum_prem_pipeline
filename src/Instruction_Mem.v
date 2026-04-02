module mem1KB_32bit (
    input  wire        clk,
    input  wire        we,
    input  wire [7:0]  addr,
    input  wire [31:0] wdata,
    input  wire [31:0] read_Address,
    output wire [31:0] Instruction_out
);

    wire _unused = &{1'b0, read_Address[31:8], read_Address[1:0]}; // silence unused bits warning
    localparam integer DEPTH = 64;  // ✅ plain integer, no width limit
    reg [31:0] mem [0:DEPTH-1];      // [0:63] = 64 entries = 1KB

    // Write
    always @(posedge clk) begin
        if (we && addr != 8'hFF)     // ✅ addr is 8-bit, max index is 63
            mem[addr[5:0]] <= wdata;
    end
    

    // Read
    assign Instruction_out = mem[read_Address[7:2]];

endmodule



