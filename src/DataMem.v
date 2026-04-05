`default_nettype none
`timescale 1ns / 1ps

module DataMem #(
    parameter UART_FIFO_DEPTH = 4,
    parameter SPI_RX_DEPTH    = 4
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] aluAddress_in,
    input  wire [31:0] DataWriteM_in,
    input  wire        memwriteM_in,
    output reg  [31:0] DataMem_out, // Reverted to Combinational

    // UART
    output reg  [7:0]  uart_out_data,
    output reg         uart_tx_start,
    input  wire        uart_tx_busy,
    input  wire [7:0]  uart_in_data,
    input  wire        uart_rx_ready,

    // SPI1
    output reg  [7:0]  spi1_tx_data,
    output reg         spi1_start,
    output wire        spi1_pending_out,
    input  wire [7:0]  spi1_rx_data,
    input  wire        spi1_busy,
    input  wire        spi1_done,

    // SPI2
    output reg  [7:0]  spi2_tx_data,
    output reg         spi2_start,
    output wire        spi2_pending_out,
    input  wire [7:0]  spi2_rx_data,
    input  wire        spi2_busy,
    input  wire        spi2_done,

    // GPIO
    output reg         gpio1_wr_en,
    output reg         gpio1_wdata,
    output reg         gpio2_wr_en,
    output reg         gpio2_wdata
);

    // --- Address Decode ---
    wire sel_uart_tx   = (aluAddress_in == 32'h1000_0000);
    wire sel_uart_rx   = (aluAddress_in == 32'h1000_0004);
    wire sel_uart_txst = (aluAddress_in == 32'h1000_0008);
    wire sel_uart_rxst = (aluAddress_in == 32'h1000_000C);

    wire sel_spi1_tx   = (aluAddress_in == 32'h2000_0000);
    wire sel_spi1_txst = (aluAddress_in == 32'h2000_0004);
    wire sel_spi1_rx   = (aluAddress_in == 32'h2000_0008);
    wire sel_spi1_rxst = (aluAddress_in == 32'h2000_000C);

    wire sel_spi2_tx   = (aluAddress_in == 32'h4000_0000);
    wire sel_spi2_txst = (aluAddress_in == 32'h4000_0004);
    wire sel_spi2_rx   = (aluAddress_in == 32'h4000_0008);
    wire sel_spi2_rxst = (aluAddress_in == 32'h4000_000C);

    wire sel_gpio1     = (aluAddress_in == 32'h3000_0000);
    wire sel_gpio2     = (aluAddress_in == 32'h3000_0004);

    // --- Internal FIFO Wires (Fixing the Elaboration Errors) ---
    wire uart_tx_full, uart_tx_empty;
    wire [7:0] uart_tx_rd_data;
    wire uart_rx_full, uart_rx_empty;
    wire [7:0] uart_rx_rd_data;
    wire spi1_rx_full, spi1_rx_empty;
    wire [7:0] spi1_rx_fifo_data;
    wire spi2_rx_full, spi2_rx_empty;
    wire [7:0] spi2_rx_fifo_data;

    // --- UART TX Logic ---
    reg uart_tx_wr_lock;
    always @(posedge clk or posedge reset) begin
        if (reset) uart_tx_wr_lock <= 1'b0;
        else uart_tx_wr_lock <= (memwriteM_in && sel_uart_tx);
    end
    wire uart_tx_wr = memwriteM_in && sel_uart_tx && !uart_tx_wr_lock && !uart_tx_full;
    reg uart_tx_rd_prev;
    wire uart_tx_rd_level = !uart_tx_busy && !uart_tx_empty;
    wire uart_tx_rd = uart_tx_rd_level && !uart_tx_rd_prev;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_tx_rd_prev <= 1'b0; uart_tx_start <= 1'b0; uart_out_data <= 8'd0;
        end else begin
            uart_tx_rd_prev <= uart_tx_rd_level;
            uart_tx_start <= 1'b0;
            if (uart_tx_rd) begin uart_out_data <= uart_tx_rd_data; uart_tx_start <= 1'b1; end
        end
    end

    CircularBuffer #(.DATA_WIDTH(8), .DEPTH(UART_FIFO_DEPTH)) UART_TX_FIFO (
        .clk(clk), .reset(reset), .wr_en(uart_tx_wr), .wr_data(DataWriteM_in[7:0]),
        .rd_en(uart_tx_rd), .rd_data(uart_tx_rd_data), .full(uart_tx_full), .empty(uart_tx_empty)
    );

    // --- UART RX Logic ---
    reg uart_rx_rd_lock;
    always @(posedge clk or posedge reset) begin
        if (reset) uart_rx_rd_lock <= 1'b0;
        else uart_rx_rd_lock <= (!memwriteM_in && sel_uart_rx);
    end
    wire uart_rx_rd = !memwriteM_in && sel_uart_rx && !uart_rx_rd_lock && !uart_rx_empty;

    CircularBuffer #(.DATA_WIDTH(8), .DEPTH(UART_FIFO_DEPTH)) UART_RX_FIFO (
        .clk(clk), .reset(reset), .wr_en(uart_rx_ready), .wr_data(uart_in_data),
        .rd_en(uart_rx_rd), .rd_data(uart_rx_rd_data), .full(uart_rx_full), .empty(uart_rx_empty)
    );

    // --- SPI 1 Logic ---
    reg spi1_pending, spi1_tx_wr_lock;
    reg [7:0] spi1_tx_buf;
    assign spi1_pending_out = spi1_pending;
    wire spi1_tx_wr = memwriteM_in && sel_spi1_tx && !spi1_tx_wr_lock;
    always @(posedge clk or posedge reset) begin
        if (reset) begin spi1_start <= 1'b0; spi1_pending <= 1'b0; spi1_tx_wr_lock <= 1'b0; end
        else begin
            spi1_start <= 1'b0;
            spi1_tx_wr_lock <= (memwriteM_in && sel_spi1_tx);
            if (spi1_tx_wr && !spi1_pending) begin spi1_tx_buf <= DataWriteM_in[7:0]; spi1_pending <= 1'b1; end
            if (spi1_pending && !spi1_busy) begin spi1_tx_data <= spi1_tx_buf; spi1_start <= 1'b1; spi1_pending <= 1'b0; end
        end
    end

    reg spi1_done_r;
    always @(posedge clk or posedge reset) spi1_done_r <= spi1_done;
    wire spi1_rx_wr = spi1_done & !spi1_done_r;

    CircularBuffer #(.DATA_WIDTH(8), .DEPTH(SPI_RX_DEPTH)) SPI1_RX_FIFO (
        .clk(clk), .reset(reset), .wr_en(spi1_rx_wr), .wr_data(spi1_rx_data),
        .rd_en(!memwriteM_in && sel_spi1_rx && !spi1_rx_empty), .rd_data(spi1_rx_fifo_data),
        .full(spi1_rx_full), .empty(spi1_rx_empty)
    );

    // --- SPI 2 Logic ---
    reg spi2_pending, spi2_tx_wr_lock;
    reg [7:0] spi2_tx_buf;
    assign spi2_pending_out = spi2_pending;
    wire spi2_tx_wr = memwriteM_in && sel_spi2_tx && !spi2_tx_wr_lock;
    always @(posedge clk or posedge reset) begin
        if (reset) begin spi2_start <= 1'b0; spi2_pending <= 1'b0; spi2_tx_wr_lock <= 1'b0; end
        else begin
            spi2_start <= 1'b0;
            spi2_tx_wr_lock <= (memwriteM_in && sel_spi2_tx);
            if (spi2_tx_wr && !spi2_pending) begin spi2_tx_buf <= DataWriteM_in[7:0]; spi2_pending <= 1'b1; end
            if (spi2_pending && !spi2_busy) begin spi2_tx_data <= spi2_tx_buf; spi2_start <= 1'b1; spi2_pending <= 1'b0; end
        end
    end

    reg spi2_done_r;
    always @(posedge clk or posedge reset) spi2_done_r <= spi2_done;
    wire spi2_rx_wr = spi2_done & !spi2_done_r;

    CircularBuffer #(.DATA_WIDTH(8), .DEPTH(SPI_RX_DEPTH)) SPI2_RX_FIFO (
        .clk(clk), .reset(reset), .wr_en(spi2_rx_wr), .wr_data(spi2_rx_data),
        .rd_en(!memwriteM_in && sel_spi2_rx && !spi2_rx_empty), .rd_data(spi2_rx_fifo_data),
        .full(spi2_rx_full), .empty(spi2_rx_empty)
    );

    // --- GPIO Logic ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin gpio1_wdata <= 1'b1; gpio2_wdata <= 1'b1; gpio1_wr_en <= 1'b0; gpio2_wr_en <= 1'b0; end
        else begin
            gpio1_wr_en <= 1'b0; gpio2_wr_en <= 1'b0;
            if (memwriteM_in && sel_gpio1) begin gpio1_wdata <= DataWriteM_in[0]; gpio1_wr_en <= 1'b1; end
            if (memwriteM_in && sel_gpio2) begin gpio2_wdata <= DataWriteM_in[0]; gpio2_wr_en <= 1'b1; end
        end
    end

    // --- COMBINATIONAL READ MUX (Passes Simulation) ---
    always @(*) begin
        DataMem_out = 32'hDEAD_BADD;
        if (!memwriteM_in) begin
            case (1'b1)
                sel_uart_rx:   DataMem_out = {24'b0, uart_rx_rd_data};
                sel_uart_txst: DataMem_out = {30'b0, uart_tx_busy,  uart_tx_full};
                sel_uart_rxst: DataMem_out = {30'b0, uart_rx_full, ~uart_rx_empty};
                sel_spi1_rx:   DataMem_out = {24'b0, spi1_rx_fifo_data};
                sel_spi1_txst: DataMem_out = {30'b0, spi1_pending,  spi1_busy};
                sel_spi1_rxst: DataMem_out = {30'b0, spi1_rx_full, ~spi1_rx_empty};
                sel_spi2_rx:   DataMem_out = {24'b0, spi2_rx_fifo_data};
                sel_spi2_txst: DataMem_out = {30'b0, spi2_pending,  spi2_busy};
                sel_spi2_rxst: DataMem_out = {30'b0, spi2_rx_full, ~spi2_rx_empty};
                sel_gpio1:     DataMem_out = {31'b0, gpio1_wdata};
                sel_gpio2:     DataMem_out = {31'b0, gpio2_wdata};
                default:       DataMem_out = 32'hDEAD_BADD;
            endcase
        end
    end

endmodule

