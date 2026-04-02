`default_nettype none
`timescale 1ns/1ps

// ============================================================
//  pipeline — RISC-V 5-stage + UART + SPI1(÷4) + SPI2(÷8) + GPIO
//
//  Reset buffer tree (fanout fix):
//    rst_core   → pc_register, IF_ID, EX, MEM, WB, DataMem  (6 loads)
//    rst_mem    → Reg_file, halt_latch                        (2 loads)
//    rst_periph → uart_inst0, spi1, spi2, gpio1, gpio2        (5 loads)
//    rst_boot   → uart_boot_inst, uart_bootloader             (2 loads)
//  Each group ≤6 loads, within MAX_FANOUT_CONSTRAINT=10 ✓
//  OpenLane inserts sky130_fd_sc_hd__buf_4 on each wire
// ============================================================
module pipeline(
    input  wire clk,
    input  wire reset,

    // Bootloader UART
    input  wire rx,
    output wire tx,

    // Peripheral UART
    output wire UART_tx,
    input  wire UART_rx_line,

    // SPI1 (CLK_DIV=4 → 12.5MHz)
    output wire spi1_sclk,
    output wire spi1_mosi,
    input  wire spi1_miso,
    output wire spi1_cs_n,

    // SPI2 (CLK_DIV=8 → 6.25MHz)
    output wire spi2_sclk,
    output wire spi2_mosi,
    input  wire spi2_miso,
    output wire spi2_cs_n
);


    // ── Reset buffer groups ───────────────────────────────────
    wire rst_core;    // pipeline core stages
    wire rst_mem;     // register file + halt
    wire rst_periph;  // all peripherals
    wire rst_boot;    // bootloader

    assign rst_core   = reset;
    assign rst_mem    = reset;
    assign rst_periph = reset;
    assign rst_boot   = reset;

    // ── Internal pipeline wires ───────────────────────────────
    wire [31:0] PCPLUS4_top, PC_top, PCF, Instruction1_out, INSTRUCTION;
    wire [31:0] RD1_top, RD2_top, PCD_top, PCE_top, PCPLUS4D_TOP;
    wire [31:0] RD1E_top, RD2E_top;
    // SrcA_top, outB_top, ScrB_top, PCTarget_top driven by assign below
    wire [31:0] SrcA_top, outB_top, ScrB_top;
    wire [31:0] ALUResultE_top, PCPlus4E_top, ALUResultM_top, WriteDataM_top, PCPlus4M_top;
    wire [31:0] Datamem_top, ALUResultW_top, ReadDataW_top, PCPlus4W_top, ResultW_top;
    wire [31:0] PCTarget_top;
    wire [31:0] ImmExtD_top, ImmExtE_top;

    wire RegWrite_top, ALUSrcD_top, memWriteD_top, jumpD_top, BranchD_top;
    wire JumpE_top, BranchE_top, zero_top, PCSCR_top;
    wire jumpRD_top, JumpRE_top;
    wire RegWriteE_top, MemWriteE_top, ALUSrcE_top;
    wire MemWriteM_top, RegWriteM_top, RegWriteW_top;
    wire StallF_top, StallD_top, FlushD_top, FlushE_top;

    wire [1:0] ResultSrcD_top, ALUtyp_top, ALUTypE_top;
    wire [1:0] ResultSrcE_top, ResultSrcM_top, ResultSrcW_top;
    wire [1:0] ForwardAE_top, ForwardBE_top;
    wire [3:0] ALUControlD_top, ALUControlE_top;
    wire [4:0] RdE_top, RdM_top, Rs1E_top, Rs2E_top, RdW_top;
    wire [2:0] ImmSrc_top;

    // ── Bootloader wires ──────────────────────────────────────
    wire [7:0]  uart_rx_data_boot, boot_tx_data;
    wire        uart_rx_ready_boot, boot_tx_start;
    wire        Write_enable;
    wire [7:0]  mem_addr;
    wire [31:0] mem_wdata;
    wire        stall_Pro;
    wire        halt_top;

    // ── Halt latch ────────────────────────────────────────────
    // Gate halt against: stall (bootloader uploading) and flushes
    // (flush injects 0x00 which would decode as halt without gating)
    wire halt_active = halt_top & ~stall_Pro & ~FlushD_top & ~FlushE_top;
    reg  halt_latch;
    always @(posedge clk) begin
        if (rst_mem)          halt_latch <= 1'b0;
        else if (stall_Pro)   halt_latch <= 1'b0;
        else if (halt_active) halt_latch <= 1'b1;
    end
    wire halt_final = halt_latch | halt_active;

    // ── Stall/flush signals ───────────────────────────────────
    wire StallF_net = PCSCR_top ? 1'b0 : (stall_Pro | StallF_top | halt_final);
    wire StallD_net = PCSCR_top ? 1'b0 : (stall_Pro | StallD_top | halt_final);

    // =========================================================
    // FETCH
    // =========================================================
    PC_incre PC(
        .pc(PCF),
        .PCPlus4(PCPLUS4_top));

    PCSelect_MUX PCSelect_top(
        .PCScr(PCSCR_top),
        .PCSequential(PCPLUS4_top),
        .PCBranch(PCTarget_top),
        .Mux3_PC(PC_top));

    pc_register Register_top(
        .clk(clk), .reset(rst_core),
        .PCF_in(PC_top), .stallF(StallF_net),
        .PCF_out(PCF));

    // =========================================================
    // BOOTLOADER
    // =========================================================
    uart_Tx_fixed #(.CLK_FREQ(50_000_000), .BAUD_RATE(115_200), .OVERSAMPLE(16))
    uart_boot_inst(
        .clk(clk), .reset(rst_boot),
        .tx_Start(boot_tx_start), .tx_Data(boot_tx_data),
        .tx(tx), .rx(rx),
        .rx_Data(uart_rx_data_boot), .rx_ready(uart_rx_ready_boot));

    uart_bootloader uart_bootloader(
        .clk(clk), .reset(rst_boot),
        .rx_data(uart_rx_data_boot), .rx_valid(uart_rx_ready_boot),
        .tx_data(boot_tx_data),      .tx_start(boot_tx_start),
        .mem_we(Write_enable), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .stall_pro(stall_Pro));

    mem1KB_32bit flipflop(
        .clk(clk),
        .we(Write_enable), .addr(mem_addr), .wdata(mem_wdata),
        .read_Address(PCF), .Instruction_out(Instruction1_out));

    // =========================================================
    // DECODE
    // =========================================================
    IF_ID_stage IF_DF_top(
        .clk(clk), .reset(rst_core),
        .stallD(StallD_net), .flushD(FlushD_top),
        .PC_in(PCF), .PCplus4_in(PCPLUS4_top),
        .instruction_in(Instruction1_out),
        .instruction_out(INSTRUCTION),
        .PCplus4_out(PCPLUS4D_TOP), .PC_out(PCD_top));

    Control control(
        .Opcode(INSTRUCTION[6:0]), .funct3(INSTRUCTION[14:12]),
        .funct7(INSTRUCTION[31:25]), .imm(INSTRUCTION[31:20]),
        .halt(halt_top),
        .RegWriteD(RegWrite_top),   .ResultSrcD(ResultSrcD_top),
        .MemWriteD(memWriteD_top),  .jumpD(jumpD_top),
        .jumpR(jumpRD_top),         .BranchD(BranchD_top),
        .ALUControlD(ALUControlD_top), .ALUSrcD(ALUSrcD_top),
        .ImmSrc(ImmSrc_top),        .ALUType(ALUtyp_top));

    Reg_file Reg_file_top(
        .clk(clk), .reset(rst_mem),
        .rs1_addr(INSTRUCTION[19:15]), .rs2_addr(INSTRUCTION[24:20]),
        .rd_addr(RdW_top), .Regwrite(RegWriteW_top),
        .Write_data(ResultW_top),
        .Read_data1(RD1_top), .Read_data2(RD2_top));

    imm imm_top(
        .ImmSrc(ImmSrc_top),
        .instruction(INSTRUCTION),
        .ImmExt(ImmExtD_top));

    // =========================================================
    // EXECUTE
    // =========================================================
    EX_stage ex_stage(
        .clk(clk), .reset(rst_core), .flushE(FlushE_top),
        .RD1D_in(RD1_top),         .RD2D_in(RD2_top),
        .ImmExtD_in(ImmExtD_top),  .PCPlus4D_in(PCPLUS4D_TOP),
        .PC_D_in(PCD_top),
        .Rs1D_in(INSTRUCTION[19:15]), .Rs2D_in(INSTRUCTION[24:20]),
        .RdD_in(INSTRUCTION[11:7]),
        .ALUControlD_in(ALUControlD_top), .ALUSrcD_in(ALUSrcD_top),
        .RegWriteD_in(RegWrite_top),   .ResultSrcD_in(ResultSrcD_top),
        .MemWriteD_in(memWriteD_top),  .BranchD_in(BranchD_top),
        .JumpD_in(jumpD_top),          .JumpR_in(jumpRD_top),
        .ALUType_in(ALUtyp_top),
        .RD1E_out(RD1E_top),           .RD2E_out(RD2E_top),
        .ImmExtD_out(ImmExtE_top),     .PCPlus4D_out(PCPlus4E_top),
        .PC_D_out(PCE_top),
        .Rs1D_out(Rs1E_top),           .Rs2D_out(Rs2E_top),
        .RdD_out(RdE_top),
        .ALUControlD_out(ALUControlE_top), .ALUSrcD_out(ALUSrcE_top),
        .RegWriteD_out(RegWriteE_top), .ResultSrcD_out(ResultSrcE_top),
        .MemWriteD_out(MemWriteE_top), .BranchD_out(BranchE_top),
        .JumpD_out(JumpE_top),         .JumpR_out(JumpRE_top),
        .ALUType_out(ALUTypE_top));

    // ── Fanout buffer wires ───────────────────────────────────
    // ResultW: drives Reg_file + MUX_A + MUX_B (3 loads, 32-bit)
    wire [31:0] ResultW_muxa = ResultW_top;  // → forwarding MUX A
    wire [31:0] ResultW_muxb = ResultW_top;  // → forwarding MUX B

    // ALUResultM: drives MUX_A + MUX_B + DataMem + WriteBack (4 loads)
    wire [31:0] ALUResM_muxa = ALUResultM_top;  // → forwarding MUX A
    wire [31:0] ALUResM_muxb = ALUResultM_top;  // → forwarding MUX B
    wire [31:0] ALUResM_dmem = ALUResultM_top;  // → DataMem address
    wire [31:0] ALUResM_wb   = ALUResultM_top;  // → WriteBack stage

    // ── Inline: Forwarding MUX A ──────────────────────────────
    assign SrcA_top = (ForwardAE_top == 2'b10) ? ALUResM_muxa :
                      (ForwardAE_top == 2'b01) ? ResultW_muxa :
                                                  RD1E_top;

    // ── Inline: Forwarding MUX B ──────────────────────────────
    assign outB_top = (ForwardBE_top == 2'b10) ? ALUResM_muxb :
                      (ForwardBE_top == 2'b01) ? ResultW_muxb :
                                                  RD2E_top;

    // ── Inline: ALU source B MUX ──────────────────────────────
    assign ScrB_top = ALUSrcE_top ? ImmExtE_top : outB_top;

    // ── Inline: PC Target Adder ───────────────────────────────
    wire [31:0] _base_addr = JumpRE_top ? RD1E_top : PCE_top;
    assign PCTarget_top = JumpRE_top ?
                          ((_base_addr + ImmExtE_top) & 32'hFFFFFFFE) :
                           (_base_addr + ImmExtE_top);

    // ── Inline: Branch/Jump → PCSCR ──────────────────────────
    assign PCSCR_top = (zero_top & BranchE_top) | JumpE_top;

    ALU alu(
        .ScrA(SrcA_top),  .ScrB(ScrB_top),
        .ALUControl(ALUControlE_top), .ALUType(ALUTypE_top),
        .ALUResult(ALUResultE_top),   .Zero(zero_top));

    // =========================================================
    // MEMORY STAGE
    // =========================================================
    MEM_stage mem_stage(
        .clk(clk), .reset(rst_core),
        .ALUResult_in(ALUResultE_top),  .WriteData_in(outB_top),
        .RdM_in(RdE_top),               .PCPlus4M_in(PCPlus4E_top),
        .RegWriteM_in(RegWriteE_top),   .ResultSrcM_in(ResultSrcE_top),
        .MemWriteM_in(MemWriteE_top),
        .ALUResult_out(ALUResultM_top), .WriteData_out(WriteDataM_top),
        .RdM_out(RdM_top),              .PCPlus4M_out(PCPlus4M_top),
        .RegWriteM_out(RegWriteM_top),  .ResultSrcM_out(ResultSrcM_top),
        .MemWriteM_out(MemWriteM_top));

    // =========================================================
    // WRITEBACK
    // =========================================================
    WriteBack_stage writeback_stage(
        .clk(clk), .reset(rst_core),
        .ALUResultW_in(ALUResM_wb), .ReadDataW_in(Datamem_top),
        .RdW_in(RdM_top),               .PCPlus4W_in(PCPlus4M_top),
        .RegWriteW_in(RegWriteM_top),   .ResultSrcW_in(ResultSrcM_top),
        .ALUResultW_out(ALUResultW_top), .ReadDataW_out(ReadDataW_top),
        .RdW_out(RdW_top),              .PCPlus4W_out(PCPlus4W_top),
        .RegWriteW_out(RegWriteW_top),  .ResultSrcW_out(ResultSrcW_top));

    Write_back write_back(
        .ALUResultW_in(ALUResultW_top), .ReadDataW_in(ReadDataW_top),
        .PCPlus4W_in(PCPlus4W_top),     .ResultSrcW_in(ResultSrcW_top),
        .ResultW(ResultW_top));

    // =========================================================
    // HAZARD UNIT
    // =========================================================
    Hazard_Unit hazard(
        .Rs1D(INSTRUCTION[19:15]), .Rs2D(INSTRUCTION[24:20]),
        .Rs1E(Rs1E_top),  .Rs2E(Rs2E_top), .RdE(RdE_top),
        .RegWriteE(RegWriteE_top), .PCSRCE(PCSCR_top),
        .ResultSrcE_in(ResultSrcE_top),
        .RdM(RdM_top),    .RdW(RdW_top),
        .RegWriteM(RegWriteM_top), .RegWriteW(RegWriteW_top),
        .StallF(StallF_top),  .StallD(StallD_top),
        .FlushD(FlushD_top),  .FlushE(FlushE_top),
        .Forward_AE(ForwardAE_top), .Forward_BE(ForwardBE_top));

    // =========================================================
    // PERIPHERALS
    // =========================================================
    wire        spi1_start_w, spi1_busy_w, spi1_done_w, spi1_pending_w;
    wire [7:0]  spi1_tx_data_w, spi1_rx_data_w;
    wire        spi2_start_w, spi2_busy_w, spi2_done_w, spi2_pending_w;
    wire [7:0]  spi2_tx_data_w, spi2_rx_data_w;
    wire        gpio1_wr_en_w, gpio1_wdata_w;
    wire        gpio2_wr_en_w, gpio2_wdata_w;
    wire        UART_tx_start_w, UART_tx_busy_w, UART_rx_ready_w;
    wire [7:0] UART_tx_data_w, UART_rx_data_w;

    // Data memory + peripheral bus
    DataMem databus_inst(
        .clk(clk), .reset(rst_core),
        .aluAddress_in(ALUResM_dmem),
        .DataWriteM_in(WriteDataM_top),
        .memwriteM_in(MemWriteM_top),
        .DataMem_out(Datamem_top),
        // UART
        .uart_tx_start(UART_tx_start_w),
        .uart_out_data(UART_tx_data_w),
        .uart_tx_busy(UART_tx_busy_w),
        .uart_in_data(UART_rx_data_w),
        .uart_rx_ready(UART_rx_ready_w),
        // SPI1
        .spi1_tx_data(spi1_tx_data_w),
        .spi1_start(spi1_start_w),
        .spi1_pending_out(spi1_pending_w),
        .spi1_rx_data(spi1_rx_data_w),
        .spi1_busy(spi1_busy_w),
        .spi1_done(spi1_done_w),
        // SPI2
        .spi2_tx_data(spi2_tx_data_w),
        .spi2_start(spi2_start_w),
        .spi2_pending_out(spi2_pending_w),
        .spi2_rx_data(spi2_rx_data_w),
        .spi2_busy(spi2_busy_w),
        .spi2_done(spi2_done_w),
        // GPIO
        .gpio1_wr_en(gpio1_wr_en_w), .gpio1_wdata(gpio1_wdata_w),
        .gpio2_wr_en(gpio2_wr_en_w), .gpio2_wdata(gpio2_wdata_w));

    // Peripheral UART
    uart_Tx_fixed0 #(.CLK_FREQ(50_000_000), .BAUD_RATE(115_200), .OVERSAMPLE(16))
    uart_inst0(
        .clk(clk), .reset(rst_periph),
        .tx_Start(UART_tx_start_w), .tx_Data(UART_tx_data_w),
        .tx(UART_tx),               .tx_busy(UART_tx_busy_w),
        .rx(UART_rx_line),          .rx_Data(UART_rx_data_w),
        .rx_ready(UART_rx_ready_w));

    // SPI1 — fast (CLK_DIV=4, 12.5MHz)
    spi_master #(.DATA_WIDTH(8), .CPOL(0), .CPHA(0), .CLK_DIV(4)) spi1_inst(
        .clk(clk), .reset(rst_periph),
        .start(spi1_start_w),     .tx_data(spi1_tx_data_w),
        .rx_data(spi1_rx_data_w), .busy(spi1_busy_w), .done(spi1_done_w),
        .sclk(spi1_sclk), .mosi(spi1_mosi), .miso(spi1_miso));

    // SPI2 — slow (CLK_DIV=8, 6.25MHz)
    spi_master #(.DATA_WIDTH(8), .CPOL(0), .CPHA(0), .CLK_DIV(8)) spi2_inst(
        .clk(clk), .reset(rst_periph),
        .start(spi2_start_w),     .tx_data(spi2_tx_data_w),
        .rx_data(spi2_rx_data_w), .busy(spi2_busy_w), .done(spi2_done_w),
        .sclk(spi2_sclk), .mosi(spi2_mosi), .miso(spi2_miso));

    // GPIO1 → SPI1 CS
    gpio1_io gpio1(
        .clk(clk), .reset(rst_periph),
        .wr_en1(gpio1_wr_en_w), .wdata1(gpio1_wdata_w),
        .spi_busy(spi1_busy_w), .spi_pending(spi1_pending_w),
        .gpio_out1(spi1_cs_n));

    // GPIO2 → SPI2 CS
    gpio2_io gpio2(
        .clk(clk), .reset(rst_periph),
        .wr_en2(gpio2_wr_en_w), .wdata2(gpio2_wdata_w),
        .spi_busy(spi2_busy_w), .spi_pending(spi2_pending_w),
        .gpio_out2(spi2_cs_n));

endmodule


