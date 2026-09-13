module uart_tx (
    input  logic       clk_sys,
    input  logic       rst_n,
    input  logic       baud_tick,
    input  logic [7:0] tx_data_in,
    input  logic       tx_empty,
    
    output logic       tx_rd_en,
    output logic       uart_tx
);

    // Added WAIT_FIFO state
    typedef enum logic [2:0] {
        IDLE      = 3'd0,
        WAIT_FIFO = 3'd1,
        POP       = 3'd2,
        START     = 3'd3,
        DATA      = 3'd4,
        STOP      = 3'd5
    } state_t;

    state_t state;
    
    logic [7:0] shift_reg;
    logic [3:0] tick_cnt;
    logic [2:0] bit_cnt;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            uart_tx   <= 1'b1;
            tx_rd_en  <= 1'b0;
            shift_reg <= 8'd0;
            tick_cnt  <= 4'd0;
            bit_cnt   <= 3'd0;
        end else begin
            // Default tx_rd_en to 0 ensures it pulses for exactly 1 cycle
            tx_rd_en <= 1'b0; 

            case (state)
                IDLE: begin
                    uart_tx <= 1'b1;
                    if (!tx_empty) begin
                        tx_rd_en <= 1'b1;      // Request data from FIFO
                        state    <= WAIT_FIFO; // Wait for memory to respond
                    end
                end

                WAIT_FIFO: begin
                    // tx_rd_en falls back to 0 here due to the default assignment.
                    // The FIFO sees tx_rd_en=1 on this clock edge and starts fetching.
                    state <= POP;
                end

                POP: begin
                    // The 1-cycle latency has passed. tx_data_in is now valid.
                    shift_reg <= tx_data_in;
                    tick_cnt  <= 4'd0;
                    state     <= START;
                end

                START: begin
                    uart_tx <= 1'b0;
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            bit_cnt  <= 3'd0;
                            state    <= DATA;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                DATA: begin
                    uart_tx <= shift_reg[0];
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt  <= 4'd0;
                            shift_reg <= {1'b0, shift_reg[7:1]};
                            
                            if (bit_cnt == 3'd7) begin
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
                    uart_tx <= 1'b1;
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin
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