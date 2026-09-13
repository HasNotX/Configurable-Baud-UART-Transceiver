module baud_rate_gen (
    input  logic        clk_sys,
    input  logic        rst_n,
    input  logic [15:0] baud_divisor,
    input  logic        enable,      // Master enable (tie to 1 if always running)
    output logic        baud_tick
);

    logic [15:0] counter;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            counter   <= 16'd0;
            baud_tick <= 1'b0;
        end else begin
            // Default state for the tick (ensures it only stays high for 1 cycle)
            baud_tick <= 1'b0;

            if (enable) begin
                // Count from 0 up to (divisor - 1)
                if (counter >= (baud_divisor - 1'b1)) begin
                    counter   <= 16'd0;
                    baud_tick <= 1'b1;
                end else begin
                    counter   <= counter + 1'b1;
                end
            end else begin
                counter <= 16'd0;
            end
        end
    end

endmodule