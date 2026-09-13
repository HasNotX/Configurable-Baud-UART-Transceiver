module uart_transceiver_top #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 4  // 2^4 = 16 words depth for both FIFOs
)(
    // ==========================================
    // SYSTEM CLOCK DOMAIN (Interface to CPU/Bus)
    // ==========================================
    input  logic                  clk_sys,
    input  logic                  rst_sys_n,
    
    // TX Interface (System writes to UART)
    input  logic [DATA_WIDTH-1:0] tx_data_in,
    input  logic                  tx_wr_en,
    output logic                  tx_full,
    
    // RX Interface (System reads from UART)
    output logic [DATA_WIDTH-1:0] rx_data_out,
    input  logic                  rx_rd_en,
    output logic                  rx_empty,

    // ==========================================
    // UART CLOCK DOMAIN (Internal Logic & Pins)
    // ==========================================
    input  logic                  clk_uart,
    input  logic                  rst_uart_n,
    
    // Configuration
    input  logic [15:0]           baud_divisor, // Assumed to be stable before operation
    
    // Physical Pins
    input  logic                  uart_rx,
    output logic                  uart_tx
);

    // ------------------------------------------
    // Internal Interconnect Wires
    // ------------------------------------------
    
    // Baud Rate Tick
    logic w_baud_tick;
    
    // TX FIFO to TX FSM wires
    logic [DATA_WIDTH-1:0] w_tx_fifo_data_out;
    logic                  w_tx_fifo_empty;
    logic                  w_tx_rd_en;
    
    // RX FSM to RX FIFO wires
    logic [DATA_WIDTH-1:0] w_rx_fsm_data_out;
    logic                  w_rx_wr_en;
    logic                  w_rx_fifo_full; // Can be used to trigger an overflow interrupt

    // ------------------------------------------
    // 1. Baud Rate Generator
    // ------------------------------------------
    baud_rate_gen u_baud_gen (
        .clk_sys      (clk_uart),     // Driven by UART base clock
        .rst_n        (rst_uart_n),
        .baud_divisor (baud_divisor),
        .enable       (1'b1),         // Always enabled
        .baud_tick    (w_baud_tick)
    );

    // ------------------------------------------
    // 2. TX Asynchronous FIFO
    // ------------------------------------------
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (FIFO_DEPTH)
    ) u_tx_fifo (
        // Write side (System Domain)
        .wr_clk     (clk_sys),
        .wr_rst_n   (rst_sys_n),
        .wr_en      (tx_wr_en),
        .wr_data    (tx_data_in),
        .full       (tx_full),
        
        // Read side (UART Domain)
        .rd_clk     (clk_uart),
        .rd_rst_n   (rst_uart_n),
        .rd_en      (w_tx_rd_en),
        .rd_data    (w_tx_fifo_data_out),
        .empty      (w_tx_fifo_empty)
    );

    // ------------------------------------------
    // 3. UART Transmitter FSM
    // ------------------------------------------
    uart_tx u_tx_fsm (
        .clk_sys    (clk_uart),       // Driven by UART base clock
        .rst_n      (rst_uart_n),
        .baud_tick  (w_baud_tick),
        .tx_data_in (w_tx_fifo_data_out),
        .tx_empty   (w_tx_fifo_empty),
        .tx_rd_en   (w_tx_rd_en),
        .uart_tx    (uart_tx)
    );

    // ------------------------------------------
    // 4. UART Receiver FSM
    // ------------------------------------------
    uart_rx u_rx_fsm (
        .clk_sys    (clk_uart),       // Driven by UART base clock
        .rst_n      (rst_uart_n),
        .baud_tick  (w_baud_tick),
        .uart_rx    (uart_rx),
        .rx_data_out(w_rx_fsm_data_out),
        .rx_wr_en   (w_rx_wr_en)
    );

    // ------------------------------------------
    // 5. RX Asynchronous FIFO
    // ------------------------------------------
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (FIFO_DEPTH)
    ) u_rx_fifo (
        // Write side (UART Domain)
        .wr_clk     (clk_uart),
        .wr_rst_n   (rst_uart_n),
        .wr_en      (w_rx_wr_en),
        .wr_data    (w_rx_fsm_data_out),
        .full       (w_rx_fifo_full), 
        
        // Read side (System Domain)
        .rd_clk     (clk_sys),
        .rd_rst_n   (rst_sys_n),
        .rd_en      (rx_rd_en),
        .rd_data    (rx_data_out),
        .empty      (rx_empty)
    );

endmodule