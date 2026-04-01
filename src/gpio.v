`default_nettype none
`timescale 1ns/1ps

// ============================================================
//  gpio1_io — CS for SPI1 (fast, CLK_DIV=4, 12.5MHz)
// ============================================================
module gpio1_io (
    input  wire clk,
    input  wire reset,
    input  wire wr_en1,
    input  wire wdata1,
    input  wire spi_busy,
    input  wire spi_pending,
    output wire gpio_out1
);
    reg gpio_out_reg;
    reg deassert_pending;
    wire spi_idle = !spi_busy && !spi_pending;

    always @(posedge clk) begin
        if (reset) begin
            gpio_out_reg     <= 1'b1;
            deassert_pending <= 1'b0;
        end else begin
            if (wr_en1) begin
                if (wdata1 == 1'b0) begin
                    gpio_out_reg     <= 1'b0;
                    deassert_pending <= 1'b0;
                end else begin
                    if (spi_idle) begin
                        gpio_out_reg     <= 1'b1;
                        deassert_pending <= 1'b0;
                    end else begin
                        deassert_pending <= 1'b1;
                    end
                end
            end
            if (deassert_pending && spi_idle) begin
                gpio_out_reg     <= 1'b1;
                deassert_pending <= 1'b0;
            end
        end
    end
    assign gpio_out1 = gpio_out_reg;
endmodule



// ============================================================
//  gpio2_io — CS for SPI2 (slow, CLK_DIV=8, 6.25MHz)
// ============================================================
module gpio2_io (
    input  wire clk,
    input  wire reset,
    input  wire wr_en2,
    input  wire wdata2,
    input  wire spi_busy,
    input  wire spi_pending,
    output wire gpio_out2
);
    reg gpio_out_reg;
    reg deassert_pending;
    wire spi_idle = !spi_busy && !spi_pending;

    always @(posedge clk) begin
        if (reset) begin
            gpio_out_reg     <= 1'b1;
            deassert_pending <= 1'b0;
        end else begin
            if (wr_en2) begin
                if (wdata2 == 1'b0) begin
                    gpio_out_reg     <= 1'b0;
                    deassert_pending <= 1'b0;
                end else begin
                    if (spi_idle) begin
                        gpio_out_reg     <= 1'b1;
                        deassert_pending <= 1'b0;
                    end else begin
                        deassert_pending <= 1'b1;
                    end
                end
            end
            if (deassert_pending && spi_idle) begin
                gpio_out_reg     <= 1'b1;
                deassert_pending <= 1'b0;
            end
        end
    end
    assign gpio_out2 = gpio_out_reg;
endmodule
