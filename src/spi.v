`timescale 1ns/1ps
`default_nettype none

module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CPOL       = 0,
    parameter CPHA       = 0,
    parameter CLK_DIV    = 4    // 50MHz → 12.5MHz
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

    reg [DATA_WIDTH-1:0]           tx_shift, rx_shift;
    reg [$clog2(DATA_WIDTH+1)-1:0] bit_cnt;
    reg [$clog2(CLK_DIV)-1:0]      clk_div;
    reg                            sclk_en, sclk_d;

    // FIX WIDTHTRUNC: cast localparam to exact register width
    localparam [$clog2(CLK_DIV)-1:0] HALF_DIV = CLK_DIV/2 - 1;
    localparam [$clog2(CLK_DIV)-1:0] FULL_DIV = CLK_DIV   - 1;

    localparam IDLE     = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam FINISH   = 2'b10;

    reg [1:0] state;

    // ── Clock generation ──────────────────────────────────────
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div <= 0;
            sclk    <= CPOL;
        end else if (sclk_en) begin
            clk_div <= clk_div + 1;
            if (clk_div == HALF_DIV || clk_div == FULL_DIV)
                sclk <= ~sclk;
        end else begin
            clk_div <= 0;
            sclk    <= CPOL;
        end
    end

    // ── Edge detect ───────────────────────────────────────────
    always @(posedge clk or posedge reset)
        sclk_d <= reset ? CPOL : sclk;

    wire sclk_rise   = ( sclk & ~sclk_d);
    wire sclk_fall   = (~sclk &  sclk_d);
    wire sample_edge = (CPHA == 0) ? sclk_rise : sclk_fall;
    wire shift_edge  = (CPHA == 0) ? sclk_fall : sclk_rise;

    // ── FSM ───────────────────────────────────────────────────
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= IDLE;
            busy     <= 0; done    <= 0; sclk_en <= 0;
            mosi     <= 0; rx_data <= 0;
            tx_shift <= 0; rx_shift <= 0; bit_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0; busy <= 0; sclk_en <= 0;
                    if (start) begin
                        busy     <= 1;
                        sclk_en  <= 1;
                        tx_shift <= tx_data;
                        rx_shift <= 0;
                        bit_cnt  <= DATA_WIDTH;
                        mosi     <= tx_data[DATA_WIDTH-1];
                        state    <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (sample_edge)
                        rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                    if (shift_edge) begin
                        bit_cnt <= bit_cnt - 1;
                        if (bit_cnt == 1) begin
                            sclk_en <= 0;
                            state   <= FINISH;
                        end else begin
                            tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                            mosi     <= tx_shift[DATA_WIDTH-2];
                        end
                    end
                end

                FINISH: begin
                    done    <= 1;
                    busy    <= 0;
                    rx_data <= rx_shift;
                    mosi    <= 0;
                    state   <= IDLE;
                end

                // FIX: prevents latch in synthesis (state=2'b11 undefined)
                default: state <= IDLE;

            endcase
        end
    end
endmodule

