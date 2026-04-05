`default_nettype none
`timescale 1ns/1ps

module uart_bootloader (
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    output reg  [7:0]  tx_data,
    output reg         tx_start,
    output reg         mem_we,
    output reg  [7:0]  mem_addr,
    output reg  [31:0] mem_wdata,
    output reg         stall_pro
);
    localparam HANDSHAKE_BYTE = 8'h25;
    localparam ACK            = 8'h55;
    localparam NACK           = 8'hFF;
    localparam SENTINEL       = 32'h00000073;

    reg handshake_done, boot_done, boot_done_d, rx_valid_d;
    wire rx_strobe = rx_valid && !rx_valid_d;
    reg [1:0]  byte_count;
    reg        buffer_sel;
    reg [31:0] buffer0, buffer1;
    reg        buffer_full0, buffer_full1;
    reg [7:0]  addr_count;

    always @(posedge clk) begin
        if (reset) begin
            rx_valid_d     <= 1'b0;
            tx_data        <= 8'd0;
            tx_start       <= 1'b0;
            mem_we         <= 1'b0;
            mem_addr       <= 8'd0;
            mem_wdata      <= 32'd0;
            handshake_done <= 1'b0;
            boot_done      <= 1'b0;
            boot_done_d    <= 1'b0;
            buffer0        <= 32'd0;
            buffer1        <= 32'd0;
            buffer_full0   <= 1'b0;
            buffer_full1   <= 1'b0;
            buffer_sel     <= 1'b0;
            byte_count     <= 2'd0;
            addr_count     <= 8'd0;
            stall_pro      <= 1'b1;
        end else begin
            rx_valid_d  <= rx_valid;
            tx_start    <= 1'b0;
            mem_we      <= 1'b0;
            boot_done_d <= boot_done;
            stall_pro   <= !boot_done_d;

            if (!handshake_done && rx_strobe) begin
                if (rx_data == HANDSHAKE_BYTE) begin
                    tx_data <= ACK; tx_start <= 1'b1;
                    handshake_done <= 1'b1;
                end else begin
                    tx_data <= NACK; tx_start <= 1'b1;
                end
            end else if (handshake_done && rx_strobe && !boot_done) begin
                if (buffer_sel == 1'b0 && !buffer_full0) begin
                    case (byte_count)
                        2'd0: buffer0[7:0]   <= rx_data;
                        2'd1: buffer0[15:8]  <= rx_data;
                        2'd2: buffer0[23:16] <= rx_data;
                        2'd3: buffer0[31:24] <= rx_data;
                    endcase
                    if (byte_count == 2'd3) buffer_full0 <= 1'b1;
                end else if (buffer_sel == 1'b1 && !buffer_full1) begin
                    case (byte_count)
                        2'd0: buffer1[7:0]   <= rx_data;
                        2'd1: buffer1[15:8]  <= rx_data;
                        2'd2: buffer1[23:16] <= rx_data;
                        2'd3: buffer1[31:24] <= rx_data;
                    endcase
                    if (byte_count == 2'd3) buffer_full1 <= 1'b1;
                end
                if (byte_count == 2'd3) begin
                    byte_count <= 2'd0;
                    buffer_sel <= !buffer_sel;
                end else begin
                    byte_count <= byte_count + 1'b1;
                end
            end

            if (buffer_full0) begin
                mem_wdata <= buffer0; mem_addr <= addr_count;
                mem_we    <= 1'b1;   addr_count <= addr_count + 1'b1;
                buffer0   <= 32'd0;  buffer_full0 <= 1'b0;
                if (buffer0 == SENTINEL) boot_done <= 1'b1;
            end else if (buffer_full1) begin
                mem_wdata <= buffer1; mem_addr <= addr_count;
                mem_we    <= 1'b1;   addr_count <= addr_count + 1'b1;
                buffer1   <= 32'd0;  buffer_full1 <= 1'b0;
                if (buffer1 == SENTINEL) boot_done <= 1'b1;
            end
        end
    end
endmodule

