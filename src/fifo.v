`default_nettype none
`timescale 1ns / 1ps

// ============================================================
//  CircularBuffer — 8-bit Ring Buffer (FIFO)
//
//  WHAT IS A RING BUFFER:
//    Fixed-size memory used as a queue.
//    Write pointer (wr_ptr) and read pointer (rd_ptr) move
//    forward in a circle — when they reach DEPTH-1, wrap to 0.
//
//    Example (DEPTH=8):
//    Slot:  [ 0 ][ 1 ][ 2 ][ 3 ][ 4 ][ 5 ][ 6 ][ 7 ]
//    Data:    'R'  'I'  'S'  'C'   -    -    -    -
//              ↑rd_ptr              ↑wr_ptr
//
//    Read  → rd_ptr advances → 'R' consumed
//    Write → wr_ptr advances → new byte stored
//    Full  → wr_ptr caught up to rd_ptr (count==DEPTH)
//    Empty → rd_ptr == wr_ptr (count==0)
//
//  WHY 8-BIT PER SLOT:
//    UART frame = always 8-bit (protocol fixed, no choice)
//    SPI  frame = 8-bit (standard devices: sensors, flash)
//    I2C  frame = always 8-bit (protocol fixed)
//
//    CPU is 32-bit but that is the memory BUS width.
//    Serial wire carries 8 bits per frame.
//    Ring buffer stores what goes on/comes off the wire = 8-bit.
//
//    32-bit slot would waste 24 bits per entry and make
//    FIFO 4x larger for no benefit.
//
//  MEMORY SIZE:
//    DATA_WIDTH=8, DEPTH=16 → 8×16 = 128 bits = 16 bytes
//    (same as STM32 UART FIFO size)
//
//  RULES FOR CALLER:
//    wr_en must be 1-cycle pulse (DataMem handles one-shot)
//    rd_en must be 1-cycle pulse (DataMem handles one-shot)
//    Check !full before wr_en
//    Check !empty before rd_en
//    rd_data is always valid (async) when !empty
//
//  SIMULTANEOUS READ + WRITE (same cycle):
//    Both allowed — count stays same, pointers both advance
// ============================================================
module CircularBuffer #(
    parameter DATA_WIDTH = 8,    // always 8 for serial peripherals
    parameter DEPTH      = 16    // 16 bytes — adjustable
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


    localparam PTR_W = $clog2(DEPTH);
    /* verilator lint_off WIDTHTRUNC */
    localparam [PTR_W-1:0] MAX_PTR = DEPTH - 1;
    /* verilator lint_on WIDTHTRUNC */

    // ── Memory array ──────────────────────────────────────────
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ── Pointers ──────────────────────────────────────────────
    reg [PTR_W-1:0] wr_ptr;   // points to next empty slot
    reg [PTR_W-1:0] rd_ptr;   // points to oldest valid slot
    reg [PTR_W:0]   count;    // number of valid bytes (0..DEPTH)

    // ── Status ────────────────────────────────────────────────
    assign full    = (count == DEPTH);
    assign empty   = (count == 0);

    // ── Async read ────────────────────────────────────────────
    // rd_data always reflects mem[rd_ptr]
    // No clock needed — DataMem reads this combinationally
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
                wr_ptr      <= (wr_ptr == MAX_PTR)
                               ? {PTR_W{1'b0}}
                               : wr_ptr + 1'b1;
            end

            // ── Read ──────────────────────────────────────────
            if (rd_en && !empty) begin
                rd_ptr <= (rd_ptr == MAX_PTR)
                          ? {PTR_W{1'b0}}
                          : rd_ptr + 1'b1;
            end

            // ── Count update ──────────────────────────────────
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   count <= count + 1'b1;  // write only
                2'b01:   count <= count - 1'b1;  // read only
                default: count <= count;           // both or neither
            endcase

        end
    end

endmodule


