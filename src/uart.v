`default_nettype none
`timescale 1ns / 1ps

module uart_Tx_fixed #(
    parameter CLK_FREQ    = 50_000_000,
    parameter BAUD_RATE   = 115_200,
    parameter OVERSAMPLE  = 16
)(
    input  wire       clk,
    input  wire       reset,

    input  wire       tx_Start,
    input  wire [7:0] tx_Data,
    output reg        tx,

    input  wire       rx,
    output reg  [7:0] rx_Data,
    output reg        rx_ready
);

    // ── Baud generator ────────────────────────────────────────
    localparam integer         BAUD_DIV  = CLK_FREQ / (BAUD_RATE * OVERSAMPLE);
    localparam integer         CNT_WIDTH = $clog2(BAUD_DIV + 1);

    // Sized localparams — suppress WIDTHTRUNC (values fit, truncation intentional)
    /* verilator lint_off WIDTHTRUNC */
    localparam [CNT_WIDTH-1:0] BAUD_LAST = BAUD_DIV - 1;
    localparam [3:0]           OS_LAST   = OVERSAMPLE - 1;
    /* verilator lint_on WIDTHTRUNC */

    reg [CNT_WIDTH-1:0] baud_cnt;
    reg baud_tick;

    always @(posedge clk) begin
        if (reset) begin
            baud_cnt  <= 0;
            baud_tick <= 1'b0;
        end else begin
            if (baud_cnt == BAUD_LAST) begin
                baud_cnt  <= 0;
                baud_tick <= 1'b1;
            end else begin
                baud_cnt  <= baud_cnt + 1'b1;
                baud_tick <= 1'b0;
            end
        end
    end

    // ── TX ────────────────────────────────────────────────────
    localparam [1:0] TX_IDLE=2'b00, TX_START=2'b01, TX_DATA=2'b10, TX_STOP=2'b11;

    reg [1:0] tx_state;
    reg [7:0] tx_shift_reg;
    reg [2:0] tx_bit_cnt;
    reg [3:0] tx_oversample_cnt;
    reg       tx_pending;

    always @(posedge clk) begin
        if (reset) tx_pending <= 1'b0;
        else begin
            if (tx_Start)               tx_pending <= 1'b1;
            else if (tx_state==TX_START) tx_pending <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            tx <= 1'b1; tx_state <= TX_IDLE;
            tx_shift_reg <= 0; tx_bit_cnt <= 0; tx_oversample_cnt <= 0;
        end else if (baud_tick) begin
            case (tx_state)
                TX_IDLE: begin
                    tx <= 1'b1; tx_oversample_cnt <= 0;
                    if (tx_pending) begin
                        tx_shift_reg <= tx_Data;
                        tx_state     <= TX_START;
                    end
                end
                TX_START: begin
                    tx <= 1'b0;
                    if (tx_oversample_cnt == OS_LAST) begin
                        tx_state <= TX_DATA; tx_bit_cnt <= 0; tx_oversample_cnt <= 0;
                    end else tx_oversample_cnt <= tx_oversample_cnt + 1'b1;
                end
                TX_DATA: begin
                    tx <= tx_shift_reg[tx_bit_cnt];
                    if (tx_oversample_cnt == OS_LAST) begin
                        tx_oversample_cnt <= 0;
                        if (tx_bit_cnt == 3'd7) tx_state <= TX_STOP;
                        else tx_bit_cnt <= tx_bit_cnt + 1'b1;
                    end else tx_oversample_cnt <= tx_oversample_cnt + 1'b1;
                end
                TX_STOP: begin
                    tx <= 1'b1;
                    if (tx_oversample_cnt == OS_LAST) begin
                        tx_state <= TX_IDLE; tx_oversample_cnt <= 0;
                    end else tx_oversample_cnt <= tx_oversample_cnt + 1'b1;
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    // ── RX ────────────────────────────────────────────────────
    localparam [1:0] RX_IDLE=2'b00, RX_START=2'b01, RX_DATA=2'b10, RX_STOP=2'b11;

    reg [1:0] rx_state;
    reg [7:0] rx_shift_reg;
    reg [2:0] rx_bit_cnt;
    reg [3:0] rx_sample_cnt;
    reg [4:0] one_counts;

    always @(posedge clk) begin
        if (reset) begin
            rx_state <= RX_IDLE; rx_shift_reg <= 0;
            rx_bit_cnt <= 0; rx_sample_cnt <= 0;
            one_counts <= 0; rx_Data <= 0; rx_ready <= 0;
        end else if (baud_tick) begin
            case (rx_state)
                RX_IDLE: begin
                    rx_ready <= 0; rx_sample_cnt <= 0; one_counts <= 0;
                    if (!rx) rx_state <= RX_START;
                end
                RX_START: begin
                    // FIX: {4'b0,~rx} zero-extends 1-bit to 5-bit
                    one_counts <= one_counts + {4'b0, ~rx};
                    if (rx_sample_cnt == OS_LAST) begin
                        if (one_counts >= OVERSAMPLE/2) begin
                            rx_state <= RX_DATA; rx_bit_cnt <= 0;
                        end else rx_state <= RX_IDLE;
                        rx_sample_cnt <= 0; one_counts <= 0;
                    end else rx_sample_cnt <= rx_sample_cnt + 1'b1;
                end
                RX_DATA: begin
                    // FIX: {4'b0,rx} zero-extends 1-bit to 5-bit
                    one_counts <= one_counts + {4'b0, rx};
                    if (rx_sample_cnt == OS_LAST) begin
                        rx_shift_reg  <= {(one_counts >= OVERSAMPLE/2), rx_shift_reg[7:1]};
                        rx_sample_cnt <= 0; one_counts <= 0;
                        if (rx_bit_cnt == 3'd7) rx_state <= RX_STOP;
                        else rx_bit_cnt <= rx_bit_cnt + 1'b1;
                    end else rx_sample_cnt <= rx_sample_cnt + 1'b1;
                end
                RX_STOP: begin
                    one_counts <= one_counts + {4'b0, rx};
                    if (rx_sample_cnt == OS_LAST) begin
                        if (one_counts >= OVERSAMPLE/2) begin
                            rx_Data  <= rx_shift_reg;
                            rx_ready <= 1'b1;
                        end
                        rx_state <= RX_IDLE; rx_sample_cnt <= 0; one_counts <= 0;
                    end else rx_sample_cnt <= rx_sample_cnt + 1'b1;
                end
            endcase
        end
    end

endmodule


