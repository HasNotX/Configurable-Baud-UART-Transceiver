module uart_rx (
    input  logic       clk_sys,
    input  logic       rst_n,
    input  logic       baud_tick,   // The 16x tick from the Baud Rate Generator
    input  logic       uart_rx,     // The physical asynchronous serial receive pin
    
    output logic [7:0] rx_data_out, // Data going to the RX Async FIFO
    output logic       rx_wr_en     // Write enable to push to the RX Async FIFO
);

    // State encoding
    typedef enum logic [1:0] {
        IDLE  = 2'd0,
        START = 2'd1,
        DATA  = 2'd2,
        STOP  = 2'd3
    } state_t;

    state_t state;
    
    // CDC Synchronizer registers
    logic rx_sync_1, rx_sync_2, rx_sync_3;

    logic [7:0] shift_reg;
    logic [3:0] tick_cnt;   // Counts 0-15 (16 ticks per bit)
    logic [2:0] bit_cnt;    // Counts 0-7  (8 bits per payload)


    // Clock Domain Crossing (CDC) & Edge Detection
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;
            rx_sync_3 <= 1'b1;
        end else begin
            rx_sync_1 <= uart_rx;
            rx_sync_2 <= rx_sync_1; // Safely synchronized rx signal
            rx_sync_3 <= rx_sync_2; // Delayed by 1 cycle for edge detection
        end
    end

    logic falling_edge;
    assign falling_edge = (~rx_sync_2 & rx_sync_3);

    // Receiver FSM
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            rx_wr_en    <= 1'b0;
            rx_data_out <= 8'd0;
            shift_reg   <= 8'd0;
            tick_cnt    <= 4'd0;
            bit_cnt     <= 3'd0;
        end else begin
            // Default write enable to 0 so it pulses for exactly 1 cycle
            rx_wr_en <= 1'b0;

            case (state)
                IDLE: begin
                    if (falling_edge) begin
                        tick_cnt <= 4'd0;
                        state    <= START;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd7) begin // Middle of the Start bit
                            if (rx_sync_2 == 1'b0) begin 
                                // Valid start bit confirmed
                                tick_cnt <= 4'd0;
                                bit_cnt  <= 3'd0;
                                state    <= DATA;
                            end else begin
                                // False alarm (glitch), return to IDLE
                                state <= IDLE;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin // Middle of the Data bit
                            tick_cnt  <= 4'd0;
                            // Shift incoming bit into the MSB, shift rest right
                            shift_reg <= {rx_sync_2, shift_reg[7:1]};
                            
                            if (bit_cnt == 3'd7) begin // Received all 8 bits?
                                state <= STOP;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin // Middle of the Stop bit
                            if (rx_sync_2 == 1'b1) begin 
                                // Valid stop bit received, push to FIFO
                                rx_wr_en    <= 1'b1;
                                rx_data_out <= shift_reg;
                            end
                            // Return to IDLE regardless (drop corrupted byte if not 1)
                            state <= IDLE;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule