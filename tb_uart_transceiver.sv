`timescale 1ns/1ps

module tb_uart_transceiver;

    // ==========================================
    // Parameters & Clock Frequencies
    // ==========================================
    // System clock: 100 MHz (10 ns period)
    localparam SYS_CLK_PERIOD = 10;
    
    // UART base clock: 50 MHz (20 ns period)
    // Purposely misaligned from system clock to test CDC robustness
    localparam UART_CLK_PERIOD = 20; 

    // ==========================================
    // Signals
    // ==========================================
    logic        clk_sys    = 0;
    logic        rst_sys_n  = 0;
    logic        clk_uart   = 0;
    logic        rst_uart_n = 0;
    
    logic [7:0]  tx_data_in;
    logic        tx_wr_en   = 0;
    logic        tx_full;
    
    logic [7:0]  rx_data_out;
    logic        rx_rd_en   = 0;
    logic        rx_empty;
    
    logic [15:0] baud_divisor;
    
    logic        uart_tx;
    logic        uart_rx;

    // ------------------------------------------
    // THE LOOPBACK
    // ------------------------------------------
    // Connect transmit pin directly to receive pin
    assign uart_rx = uart_tx;

    // ==========================================
    // Clock Generators
    // ==========================================
    always #(SYS_CLK_PERIOD/2)  clk_sys  = ~clk_sys;
    always #(UART_CLK_PERIOD/2) clk_uart = ~clk_uart;

    // ==========================================
    // Device Under Test (DUT)
    // ==========================================
    uart_transceiver_top #(
        .DATA_WIDTH(8),
        .FIFO_DEPTH(4) // 16 words
    ) DUT (
        .clk_sys      (clk_sys),
        .rst_sys_n    (rst_sys_n),
        .tx_data_in   (tx_data_in),
        .tx_wr_en     (tx_wr_en),
        .tx_full      (tx_full),
        
        .rx_data_out  (rx_data_out),
        .rx_rd_en     (rx_rd_en),
        .rx_empty     (rx_empty),
        
        .clk_uart     (clk_uart),
        .rst_uart_n   (rst_uart_n),
        .baud_divisor (baud_divisor),
        .uart_rx      (uart_rx),
        .uart_tx      (uart_tx)
    );

    // ==========================================
    // BFM Tasks (Bus Functional Models)
    // ==========================================
    
    // Task to write a byte into the TX FIFO safely
    task write_tx(input [7:0] data);
        @(posedge clk_sys);
        wait(!tx_full);       // Stall if FIFO is full
        tx_data_in <= data;
        tx_wr_en   <= 1'b1;
        
        @(posedge clk_sys);
        tx_wr_en   <= 1'b0;   // Assert for exactly 1 cycle
    endtask
    
    // Task to read a byte from the RX FIFO safely
    task read_rx(output [7:0] data);
        @(posedge clk_sys);
        wait(!rx_empty);      // Stall until data is available
        rx_rd_en <= 1'b1;
        
        @(posedge clk_sys);
        rx_rd_en <= 1'b0;     // Deassert
        
        // Wait for the Async FIFO's 1-cycle read latency
        @(posedge clk_sys);
        data = rx_data_out;
    endtask

    // ==========================================
    // Main Stimulus
    // ==========================================
    logic [7:0] read_byte;
    
    initial begin
        $display("Starting UART CDC Loopback Test...");
        
        // 1. Initialize
        // Divisor = 2. 
        // 50MHz / (2 * 16) = 1,562,500 baud (Fast for simulation)
        baud_divisor = 16'd2; 
        
        // 2. Assert Resets
        #100;
        rst_sys_n  = 1'b1;
        rst_uart_n = 1'b1;
        #100;
        
        // 3. Write a burst of data to the TX FIFO
        $display("Writing burst to TX FIFO...");
        write_tx(8'hA5); // 10100101 (Good mix of alternating bits)
        write_tx(8'h3C);
        write_tx(8'hFF);
        
        // 4. Wait and verify they pop out of the RX FIFO
        $display("Waiting for data to loop back...");
        
        read_rx(read_byte);
        if (read_byte == 8'hA5) $display("SUCCESS: Read 8'hA5");
        else                    $error("FAIL: Expected 8'hA5, got %h", read_byte);
        
        read_rx(read_byte);
        if (read_byte == 8'h3C) $display("SUCCESS: Read 8'h3C");
        else                    $error("FAIL: Expected 8'h3C, got %h", read_byte);
        
        read_rx(read_byte);
        if (read_byte == 8'hFF) $display("SUCCESS: Read 8'hFF");
        else                    $error("FAIL: Expected 8'hFF, got %h", read_byte);
        
        $display("Simulation Complete!");
        $finish;
    end

endmodule