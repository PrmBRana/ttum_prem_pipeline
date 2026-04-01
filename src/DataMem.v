`default_nettype none
`timescale 1ns / 1ps

// ============================================================
//  DataMem — Memory-mapped peripheral controller
//
//  ADDRESS MAP:
//  ─────────────────────────────────────────────────────────
//  UART  base 0x10000000
//    0x10000000  TX data      sw
//    0x10000004  RX data      lw
//    0x10000008  TX status    lw  {30b0, tx_busy, tx_full}
//    0x1000000C  RX status    lw  {30b0, rx_full, rx_not_empty}
//
//  SPI1  base 0x20000000  (CLK_DIV=4, 12.5MHz)
//    0x20000000  TX data      sw
//    0x20000004  TX status    lw  {30b0, pending, busy}
//    0x20000008  RX data      lw
//    0x2000000C  RX status    lw  {30b0, full, not_empty}
//
//  SPI2  base 0x40000000  (CLK_DIV=8, 6.25MHz)
//    0x40000000  TX data      sw
//    0x40000004  TX status    lw  {30b0, pending, busy}
//    0x40000008  RX data      lw
//    0x4000000C  RX status    lw  {30b0, full, not_empty}
//
//  GPIO1 = 0x30000000  → SPI1 CS
//  GPIO2 = 0x30000004  → SPI2 CS
// ============================================================
module DataMem #(
    parameter UART_FIFO_DEPTH = 4,
    parameter SPI_RX_DEPTH    = 4
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] aluAddress_in,
    input  wire [31:0] DataWriteM_in,
    input  wire        memwriteM_in,
    output reg  [31:0] DataMem_out,

    // UART
    output reg  [7:0] uart_out_data,
    output reg         uart_tx_start,
    input  wire        uart_tx_busy,
    input  wire [7:0] uart_in_data,
    input  wire        uart_rx_ready,

    // SPI1 (fast, CLK_DIV=4, 12.5MHz)
    output reg  [7:0]  spi1_tx_data,
    output reg         spi1_start,
    output wire        spi1_pending_out,
    input  wire [7:0]  spi1_rx_data,
    input  wire        spi1_busy,
    input  wire        spi1_done,

    // SPI2 (slow, CLK_DIV=8, 6.25MHz)
    output reg  [7:0]  spi2_tx_data,
    output reg         spi2_start,
    output wire        spi2_pending_out,
    input  wire [7:0]  spi2_rx_data,
    input  wire        spi2_busy,
    input  wire        spi2_done,

    // GPIO1 → SPI1 CS
    output reg         gpio1_wr_en,
    output reg         gpio1_wdata,

    // GPIO2 → SPI2 CS
    output reg         gpio2_wr_en,
    output reg         gpio2_wdata
);

    // ── Address decode ────────────────────────────────────────
    // UART
    wire sel_uart_tx   = (aluAddress_in == 32'h1000_0000);
    wire sel_uart_rx   = (aluAddress_in == 32'h1000_0004);
    wire sel_uart_txst = (aluAddress_in == 32'h1000_0008);
    wire sel_uart_rxst = (aluAddress_in == 32'h1000_000C);

    // SPI1
    wire sel_spi1_tx   = (aluAddress_in == 32'h2000_0000);
    wire sel_spi1_txst = (aluAddress_in == 32'h2000_0004);
    wire sel_spi1_rx   = (aluAddress_in == 32'h2000_0008);
    wire sel_spi1_rxst = (aluAddress_in == 32'h2000_000C);

    // SPI2
    wire sel_spi2_tx   = (aluAddress_in == 32'h4000_0000);
    wire sel_spi2_txst = (aluAddress_in == 32'h4000_0004);
    wire sel_spi2_rx   = (aluAddress_in == 32'h4000_0008);
    wire sel_spi2_rxst = (aluAddress_in == 32'h4000_000C);

    // GPIO
    wire sel_gpio1     = (aluAddress_in == 32'h3000_0000);
    wire sel_gpio2     = (aluAddress_in == 32'h3000_0004);

    // ── UART TX FIFO ──────────────────────────────────────────
    wire       uart_tx_full, uart_tx_empty;
    wire [7:0] uart_tx_rd_data;

    reg uart_tx_wr_lock;
    always @(posedge clk) begin
        if (reset)
            uart_tx_wr_lock <= 1'b0;
        else if (!sel_uart_tx)
            uart_tx_wr_lock <= 1'b0;
        else if (memwriteM_in && sel_uart_tx && !uart_tx_wr_lock)
            uart_tx_wr_lock <= 1'b1;
    end
    wire uart_tx_wr = memwriteM_in && sel_uart_tx
                      && !uart_tx_wr_lock && !uart_tx_full;

    // FIX: uart_tx_rd_level does NOT use uart_tx_start
    // to avoid combinational feedback into the same always block.
    // uart_tx_rd_prev generates a clean 1-cycle read pulse.
    reg  uart_tx_rd_prev;
    wire uart_tx_rd_level = !uart_tx_busy && !uart_tx_empty;
    wire uart_tx_rd       = uart_tx_rd_level && !uart_tx_rd_prev;

    always @(posedge clk) begin
        if (reset) begin
            uart_tx_rd_prev <= 1'b0;
            uart_tx_start   <= 1'b0;
            uart_out_data   <= 32'd0;
        end else begin
            uart_tx_rd_prev <= uart_tx_rd_level;
            uart_tx_start   <= 1'b0;
            if (uart_tx_rd) begin
                uart_out_data <= {24'b0, uart_tx_rd_data};
                uart_tx_start <= 1'b1;
            end
        end
    end

    CircularBuffer #(.DATA_WIDTH(8), .DEPTH(UART_FIFO_DEPTH)) UART_TX_FIFO (
        .clk(clk),           .reset(reset),
        .wr_en(uart_tx_wr),  .wr_data(DataWriteM_in[7:0]),
        .rd_en(uart_tx_rd),  .rd_data(uart_tx_rd_data),
        .full(uart_tx_full), .empty(uart_tx_empty)
    );

    // ── UART RX FIFO ──────────────────────────────────────────
    wire       uart_rx_full, uart_rx_empty;
    wire [7:0] uart_rx_rd_data;

    reg uart_rx_rd_lock;
    always @(posedge clk) begin
        if (reset)
            uart_rx_rd_lock <= 1'b0;
        else if (!sel_uart_rx)
            uart_rx_rd_lock <= 1'b0;
        else if (!memwriteM_in && sel_uart_rx && !uart_rx_rd_lock)
            uart_rx_rd_lock <= 1'b1;
    end
    wire uart_rx_rd = !memwriteM_in && sel_uart_rx
                      && !uart_rx_rd_lock && !uart_rx_empty;

    CircularBuffer #(.DATA_WIDTH(8), .DEPTH(UART_FIFO_DEPTH)) UART_RX_FIFO (
        .clk(clk),              .reset(reset),
        .wr_en(uart_rx_ready),  .wr_data(uart_in_data[7:0]),
        .rd_en(uart_rx_rd),     .rd_data(uart_rx_rd_data),
        .full(uart_rx_full),    .empty(uart_rx_empty)
    );

    // ── SPI1 TX ───────────────────────────────────────────────
    reg       spi1_pending;
    reg [7:0] spi1_tx_buf;
    reg       spi1_tx_wr_lock;

    always @(posedge clk) begin
        if (reset)
            spi1_tx_wr_lock <= 1'b0;
        else if (!sel_spi1_tx)
            spi1_tx_wr_lock <= 1'b0;
        else if (memwriteM_in && sel_spi1_tx && !spi1_tx_wr_lock)
            spi1_tx_wr_lock <= 1'b1;
    end
    wire spi1_tx_wr = memwriteM_in && sel_spi1_tx && !spi1_tx_wr_lock;
    assign spi1_pending_out = spi1_pending;

    always @(posedge clk) begin
        if (reset) begin
            spi1_start   <= 1'b0;
            spi1_tx_data <= 8'd0;
            spi1_pending <= 1'b0;
            spi1_tx_buf  <= 8'd0;
        end else begin
            spi1_start <= 1'b0;
            if (spi1_tx_wr && !spi1_pending) begin
                spi1_tx_buf  <= DataWriteM_in[7:0];
                spi1_pending <= 1'b1;
            end
            if (spi1_pending && !spi1_busy && !spi1_done) begin
                spi1_tx_data <= spi1_tx_buf;
                spi1_start   <= 1'b1;
                spi1_pending <= 1'b0;
            end
        end
    end

    // ── SPI1 RX FIFO ──────────────────────────────────────────
    reg spi1_done_r;
    always @(posedge clk) begin
        if (reset) spi1_done_r <= 1'b0;
        else       spi1_done_r <= spi1_done;
    end
    wire spi1_done_rise = spi1_done & ~spi1_done_r;

    wire       spi1_rx_full, spi1_rx_empty;
    wire [7:0] spi1_rx_rd_data;
    reg        spi1_rx_rd_lock;

    always @(posedge clk) begin
        if (reset)
            spi1_rx_rd_lock <= 1'b0;
        else if (!sel_spi1_rx)
            spi1_rx_rd_lock <= 1'b0;
        else if (!memwriteM_in && sel_spi1_rx && !spi1_rx_rd_lock)
            spi1_rx_rd_lock <= 1'b1;
    end
    wire spi1_rx_rd = !memwriteM_in && sel_spi1_rx
                      && !spi1_rx_rd_lock && !spi1_rx_empty;

    CircularBuffer #(.DATA_WIDTH(8), .DEPTH(SPI_RX_DEPTH)) SPI1_RX_FIFO (
        .clk(clk),               .reset(reset),
        .wr_en(spi1_done_rise),  .wr_data(spi1_rx_data),
        .rd_en(spi1_rx_rd),      .rd_data(spi1_rx_rd_data),
        .full(spi1_rx_full),     .empty(spi1_rx_empty)
    );

    // ── SPI2 TX ───────────────────────────────────────────────
    reg       spi2_pending;
    reg [7:0] spi2_tx_buf;
    reg       spi2_tx_wr_lock;

    always @(posedge clk) begin
        if (reset)
            spi2_tx_wr_lock <= 1'b0;
        else if (!sel_spi2_tx)
            spi2_tx_wr_lock <= 1'b0;
        else if (memwriteM_in && sel_spi2_tx && !spi2_tx_wr_lock)
            spi2_tx_wr_lock <= 1'b1;
    end
    wire spi2_tx_wr = memwriteM_in && sel_spi2_tx && !spi2_tx_wr_lock;
    assign spi2_pending_out = spi2_pending;

    always @(posedge clk) begin
        if (reset) begin
            spi2_start   <= 1'b0;
            spi2_tx_data <= 8'd0;
            spi2_pending <= 1'b0;
            spi2_tx_buf  <= 8'd0;
        end else begin
            spi2_start <= 1'b0;
            if (spi2_tx_wr && !spi2_pending) begin
                spi2_tx_buf  <= DataWriteM_in[7:0];
                spi2_pending <= 1'b1;
            end
            if (spi2_pending && !spi2_busy && !spi2_done) begin
                spi2_tx_data <= spi2_tx_buf;
                spi2_start   <= 1'b1;
                spi2_pending <= 1'b0;
            end
        end
    end

    // ── SPI2 RX FIFO ──────────────────────────────────────────
    reg spi2_done_r;
    always @(posedge clk) begin
        if (reset) spi2_done_r <= 1'b0;
        else       spi2_done_r <= spi2_done;
    end
    wire spi2_done_rise = spi2_done & ~spi2_done_r;

    wire       spi2_rx_full, spi2_rx_empty;
    wire [7:0] spi2_rx_rd_data;
    reg        spi2_rx_rd_lock;

    always @(posedge clk) begin
        if (reset)
            spi2_rx_rd_lock <= 1'b0;
        else if (!sel_spi2_rx)
            spi2_rx_rd_lock <= 1'b0;
        else if (!memwriteM_in && sel_spi2_rx && !spi2_rx_rd_lock)
            spi2_rx_rd_lock <= 1'b1;
    end
    wire spi2_rx_rd = !memwriteM_in && sel_spi2_rx
                      && !spi2_rx_rd_lock && !spi2_rx_empty;

    CircularBuffer #(.DATA_WIDTH(8), .DEPTH(SPI_RX_DEPTH)) SPI2_RX_FIFO (
        .clk(clk),               .reset(reset),
        .wr_en(spi2_done_rise),  .wr_data(spi2_rx_data),
        .rd_en(spi2_rx_rd),      .rd_data(spi2_rx_rd_data),
        .full(spi2_rx_full),     .empty(spi2_rx_empty)
    );

    // ── GPIO ──────────────────────────────────────────────────
    always @(posedge clk) begin
        if (reset) begin
            gpio1_wr_en <= 1'b0;
            gpio1_wdata <= 1'b1;
        end else begin
            gpio1_wr_en <= 1'b0;
            if (memwriteM_in && sel_gpio1) begin
                gpio1_wdata <= DataWriteM_in[0];
                gpio1_wr_en <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            gpio2_wr_en <= 1'b0;
            gpio2_wdata <= 1'b1;
        end else begin
            gpio2_wr_en <= 1'b0;
            if (memwriteM_in && sel_gpio2) begin
                gpio2_wdata <= DataWriteM_in[0];
                gpio2_wr_en <= 1'b1;
            end
        end
    end

    // ── Read MUX ──────────────────────────────────────────────
    always @(*) begin
        DataMem_out = 32'hDEAD_BADD;
        if (!memwriteM_in) begin
            // UART
            if      (sel_uart_tx)   DataMem_out = {24'b0, uart_tx_rd_data};
            else if (sel_uart_rx)   DataMem_out = {24'b0, uart_rx_rd_data};
            else if (sel_uart_txst) DataMem_out = {30'b0, uart_tx_busy,  uart_tx_full};
            else if (sel_uart_rxst) DataMem_out = {30'b0, uart_rx_full, ~uart_rx_empty};
            // SPI1
            else if (sel_spi1_tx)   DataMem_out = {24'b0, spi1_tx_buf};
            else if (sel_spi1_txst) DataMem_out = {30'b0, spi1_pending,  spi1_busy};
            else if (sel_spi1_rx)   DataMem_out = {24'b0, spi1_rx_rd_data};
            else if (sel_spi1_rxst) DataMem_out = {30'b0, spi1_rx_full, ~spi1_rx_empty};
            // SPI2
            else if (sel_spi2_tx)   DataMem_out = {24'b0, spi2_tx_buf};
            else if (sel_spi2_txst) DataMem_out = {30'b0, spi2_pending,  spi2_busy};
            else if (sel_spi2_rx)   DataMem_out = {24'b0, spi2_rx_rd_data};
            else if (sel_spi2_rxst) DataMem_out = {30'b0, spi2_rx_full, ~spi2_rx_empty};
        end
    end

endmodule
