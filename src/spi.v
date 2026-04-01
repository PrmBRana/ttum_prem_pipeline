`default_nettype none
`timescale 1ns/1ps

module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CPOL       = 0,
    parameter CPHA       = 0,
    parameter CLK_DIV    = 4
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] tx_data,
    output reg  [DATA_WIDTH-1:0] rx_data,
    output reg                   busy,
    output reg                   done,
    output reg                   sclk,
    output reg                   mosi,
    input  wire                  miso
);

    localparam PTR_W   = $clog2(CLK_DIV);
    localparam [PTR_W-1:0] HALF_DIV = CLK_DIV/2 - 1;
    localparam [PTR_W-1:0] FULL_DIV = CLK_DIV - 1;

    localparam [1:0] IDLE     = 2'b00,
                     TRANSFER = 2'b01,
                     FINISH   = 2'b10;

    reg [DATA_WIDTH-1:0]           tx_shift, rx_shift;
    reg [$clog2(DATA_WIDTH+1)-1:0] bit_cnt;
    reg [PTR_W-1:0]                clk_div;
    reg [1:0]                      state;
    reg                            sclk_en;
    reg                            sclk_last;  // previous cycle sclk value

    // ── Single always block — everything on posedge clk ──────
    always @(posedge clk) begin
        if (reset) begin
            state     <= IDLE;
            busy      <= 1'b0;
            done      <= 1'b0;
            sclk_en   <= 1'b0;
            sclk      <= CPOL[0];
            sclk_last <= CPOL[0];
            mosi      <= 1'b0;
            rx_data   <= {DATA_WIDTH{1'b0}};
            tx_shift  <= {DATA_WIDTH{1'b0}};
            rx_shift  <= {DATA_WIDTH{1'b0}};
            bit_cnt   <= {$clog2(DATA_WIDTH+1){1'b0}};
            clk_div   <= {PTR_W{1'b0}};
        end else begin

            // ── SCLK generation ──────────────────────────────
            sclk_last <= sclk;   // capture previous sclk every cycle

            if (sclk_en) begin
                if (clk_div == FULL_DIV)
                    clk_div <= {PTR_W{1'b0}};
                else
                    clk_div <= clk_div + 1'b1;

                if (clk_div == HALF_DIV || clk_div == FULL_DIV)
                    sclk <= ~sclk;
            end else begin
                clk_div <= {PTR_W{1'b0}};
                sclk    <= CPOL[0];
            end

            // ── Edge detect (uses registered sclk_last) ──────
            // Both sclk and sclk_last updated this cycle,
            // so we use last cycle's values for edge detection
            // by reading sclk_last (old) vs sclk (new after toggle)

            // ── FSM ──────────────────────────────────────────
            case (state)

                IDLE: begin
                    done    <= 1'b0;
                    busy    <= 1'b0;
                    sclk_en <= 1'b0;
                    if (start) begin
                        busy     <= 1'b1;
                        sclk_en  <= 1'b1;
                        tx_shift <= tx_data;
                        rx_shift <= {DATA_WIDTH{1'b0}};
                        bit_cnt  <= DATA_WIDTH;
                        mosi     <= tx_data[DATA_WIDTH-1];
                        state    <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    // sample_edge: CPHA=0 uses rise, CPHA=1 uses fall
                    // shift_edge:  CPHA=0 uses fall, CPHA=1 uses rise
                    // sclk_last is previous cycle, sclk is current
                    if (CPHA == 0) begin
                        // sample on rise
                        if (!sclk_last && sclk)
                            rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                        // shift on fall
                        if (sclk_last && !sclk) begin
                            bit_cnt <= bit_cnt - 1'b1;
                            if (bit_cnt == 1) begin
                                sclk_en <= 1'b0;
                                state   <= FINISH;
                            end else begin
                                tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                                mosi     <= tx_shift[DATA_WIDTH-2];
                            end
                        end
                    end else begin
                        // sample on fall
                        if (sclk_last && !sclk)
                            rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                        // shift on rise
                        if (!sclk_last && sclk) begin
                            bit_cnt <= bit_cnt - 1'b1;
                            if (bit_cnt == 1) begin
                                sclk_en <= 1'b0;
                                state   <= FINISH;
                            end else begin
                                tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                                mosi     <= tx_shift[DATA_WIDTH-2];
                            end
                        end
                    end
                end

                FINISH: begin
                    done    <= 1'b1;
                    busy    <= 1'b0;
                    rx_data <= rx_shift;
                    mosi    <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
