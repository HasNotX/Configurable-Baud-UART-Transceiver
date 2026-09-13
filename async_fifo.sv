module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4  // FIFO Depth = 2^ADDR_WIDTH (e.g., 4 = 16 words)
)(
    // Write Domain
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,
    
    // Read Domain
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    // Memory array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // N+1 bit pointers (extra bit used for wrap-around detection)
    logic [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray;
    logic [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_gray;

    // Synchronizer registers
    logic [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
    logic [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;

    
    // Write data to memory and increment binary pointer
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr_bin <= wr_ptr_bin + 1'b1;
        end
    end

    // Convert Write Binary pointer to Gray code pointer
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_gray <= '0;
        end else begin
            // Binary to Gray conversion logic
            wr_ptr_gray <= (wr_ptr_bin >> 1) ^ wr_ptr_bin;
        end
    end

    // Synchronize Read Gray pointer into Write Clock Domain
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync1 <= '0;
            rd_ptr_gray_sync2 <= '0;
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    
    // Read data from memory and increment binary pointer
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin <= '0;
            rd_data    <= '0;
        end else if (rd_en && !empty) begin
            rd_data    <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
            rd_ptr_bin <= rd_ptr_bin + 1'b1;
        end
    end

    // Convert Read Binary pointer to Gray code pointer
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_gray <= '0;
        end else begin
            // Binary to Gray conversion logic
            rd_ptr_gray <= (rd_ptr_bin >> 1) ^ rd_ptr_bin;
        end
    end

    // Synchronize Write Gray pointer into Read Clock Domain
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync1 <= '0;
            wr_ptr_gray_sync2 <= '0;
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

    
    // Empty: Read pointer caught up to Write pointer exactly
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync2);

    // Full: Write pointer wrapped around and caught up to Read pointer.
    // In Gray code, a wrap-around inverts the top two MSBs while the rest match.
    assign full = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], 
                                    rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});

endmodule