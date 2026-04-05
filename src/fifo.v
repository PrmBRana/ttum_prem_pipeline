`default_nettype none
`timescale 1ns / 1ps

module CircularBuffer #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 4
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  full,
    output wire                  empty
);
    // ── Flattened to 4 scalar regs — no $mem inference ────────
    reg [DATA_WIDTH-1:0] mem0, mem1, mem2, mem3;
    reg [1:0] wr_ptr, rd_ptr;
    reg [2:0] count;

    assign full   = (count == 3'd4);
    assign empty  = (count == 3'd0);
    assign rd_data = (rd_ptr == 2'd0) ? mem0 :
                     (rd_ptr == 2'd1) ? mem1 :
                     (rd_ptr == 2'd2) ? mem2 : mem3;

    always @(posedge clk) begin
        if (reset) wr_ptr <= 2'd0;
        else if (wr_en && !full)
            wr_ptr <= (wr_ptr == 2'd3) ? 2'd0 : wr_ptr + 2'd1;
    end

    always @(posedge clk) begin
        if (reset) rd_ptr <= 2'd0;
        else if (rd_en && !empty)
            rd_ptr <= (rd_ptr == 2'd3) ? 2'd0 : rd_ptr + 2'd1;
    end

    always @(posedge clk) begin
        if (reset) count <= 3'd0;
        else case ({wr_en && !full, rd_en && !empty})
            2'b10: count <= count + 3'd1;
            2'b01: count <= count - 3'd1;
            default: ;
        endcase
    end

    always @(posedge clk) begin
        if (reset) mem0 <= {DATA_WIDTH{1'b0}};
        else if (wr_en && !full && wr_ptr == 2'd0) mem0 <= wr_data;
    end

    always @(posedge clk) begin
        if (reset) mem1 <= {DATA_WIDTH{1'b0}};
        else if (wr_en && !full && wr_ptr == 2'd1) mem1 <= wr_data;
    end

    always @(posedge clk) begin
        if (reset) mem2 <= {DATA_WIDTH{1'b0}};
        else if (wr_en && !full && wr_ptr == 2'd2) mem2 <= wr_data;
    end

    always @(posedge clk) begin
        if (reset) mem3 <= {DATA_WIDTH{1'b0}};
        else if (wr_en && !full && wr_ptr == 2'd3) mem3 <= wr_data;
    end
endmodule

