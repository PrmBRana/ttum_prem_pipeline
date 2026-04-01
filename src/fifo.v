`default_nettype none
`timescale 1ns / 1ps

// ============================================================
//  CircularBuffer — 8-bit Ring Buffer (FIFO) ASIC-safe
// ============================================================
module CircularBuffer #(
    parameter DATA_WIDTH = 8,    // always 8 for serial peripherals
    parameter DEPTH      = 4    // 16 bytes — adjustable
)(
    input  wire                  clk,
    input  wire                  reset,

    // Write port
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,

    // Read port
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,

    // Status
    output wire                  full,
    output wire                  empty
);
    localparam PTR_W = $clog2(DEPTH);   // 4 bits for DEPTH=16
    localparam [PTR_W-1:0] MAX_PTR = DEPTH-1; // Maximum pointer value

    // ── Memory array ──────────────────────────────────────────
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ── Pointers ──────────────────────────────────────────────
    reg [PTR_W-1:0] wr_ptr;   // points to next empty slot
    reg [PTR_W-1:0] rd_ptr;   // points to oldest valid slot
    reg [PTR_W:0]   count;    // number of valid bytes (0..DEPTH)

    // ── Status ────────────────────────────────────────────────
    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // ── Async read ────────────────────────────────────────────
    assign rd_data = mem[rd_ptr];

    // ── Sequential logic ──────────────────────────────────────
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            wr_ptr <= {PTR_W{1'b0}};
            rd_ptr <= {PTR_W{1'b0}};
            count  <= {(PTR_W+1){1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {DATA_WIDTH{1'b0}};
        end else begin

            // ── Write ─────────────────────────────────────────
            if (wr_en && !full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= (wr_ptr == MAX_PTR) ? {PTR_W{1'b0}} : wr_ptr + 1'b1;
            end

            // ── Read ──────────────────────────────────────────
            if (rd_en && !empty) begin
                rd_ptr <= (rd_ptr == MAX_PTR) ? {PTR_W{1'b0}} : rd_ptr + 1'b1;
            end

            // ── Count update ──────────────────────────────────
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   count <= count + 1'b1;  // write only
                2'b01:   count <= count - 1'b1;  // read only
                default: count <= count;          // both or neither
            endcase
        end
    end

endmodule
