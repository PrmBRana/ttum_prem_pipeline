`default_nettype none
`timescale 1ns/1ps

module tt_um_prem_pipeline_test (
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
);

  // --------------------------------------------------
  // Internal wires
  // --------------------------------------------------
  wire reset;

  // UART signals
  wire uart1_tx, uart1_rx;
  wire uart2_tx, uart2_rx;

  // SPI1 signals
  wire spi1_clk, spi1_mosi, spi1_miso, spi1_cs_n;

  // SPI2 signals
  wire spi2_clk, spi2_mosi, spi2_miso, spi2_cs_n;
  
  // Reset logic - active high reset
  assign reset = ~rst_n;

  // --------------------------------------------------
  // Input assignments
  // --------------------------------------------------
  assign uart1_rx = ui_in[3];      // UART1 RX from dedicated input
  assign uart2_rx = ui_in[4];      // UART2 RX from dedicated input
  assign spi1_miso = uio_in[0];    // SPI1 MISO
  assign spi2_miso = uio_in[7];    // SPI2 MISO

  // --------------------------------------------------
  // Output assignments
  // --------------------------------------------------
  assign uo_out[0] = uart1_tx;     // UART1 TX
  assign uo_out[1] = uart2_tx;     // UART2 TX
  assign uo_out[7:2] = 6'b000000;  // Unused dedicated outputs

  // Bidirectional SPI outputs
  assign uio_out[0] = 1'b0;        // SPI MISO input only
  assign uio_out[1] = spi1_mosi;   // SPI1 MOSI
  assign uio_out[2] = spi1_clk;    // SPI1 SCLK
  assign uio_out[3] = spi1_cs_n;   // SPI1 CS
  assign uio_out[4] = spi2_mosi;   // SPI2 MOSI
  assign uio_out[5] = spi2_clk;    // SPI2 SCLK
  assign uio_out[6] = spi2_cs_n;   // SPI2 CS
  assign uio_out[7] = 1'b0;        // SPI2 MISO input only

  // SPI directions
  assign uio_oe[0] = 1'b0;  // MISO is input
  assign uio_oe[1] = 1'b1;  // MOSI output
  assign uio_oe[2] = 1'b1;  // SCLK output
  assign uio_oe[3] = 1'b1;  // CS output
  assign uio_oe[4] = 1'b1;  // SPI2 MOSI output
  assign uio_oe[5] = 1'b1;  // SPI2 SCLK output
  assign uio_oe[6] = 1'b1;  // SPI2 CS output
  assign uio_oe[7] = 1'b0;  // SPI2 MISO input

  // --------------------------------------------------
  // Instantiate the main pipeline module
  // --------------------------------------------------
  pipeline Top_inst (
      .clk(clk),
      .reset(reset),

      // UART bootloader
      .rx(uart1_rx),
      .tx(uart1_tx),

      // UART peripheral
      .UART_tx(uart2_tx),
      .UART_rx_line(uart2_rx),

      // SPI1
      .spi1_sclk(spi1_clk),
      .spi1_mosi(spi1_mosi),
      .spi1_miso(spi1_miso),
      .spi1_cs_n(spi1_cs_n),

      // SPI2
      .spi2_cs_n(spi2_cs_n),
      .spi2_sclk(spi2_clk),
      .spi2_mosi(spi2_mosi),
      .spi2_miso(spi2_miso)
  );

endmodule