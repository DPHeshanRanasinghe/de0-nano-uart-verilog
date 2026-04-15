module uart_rx #(
    parameter CLKS_PER_BIT = 5208  // 50 MHz / 9600 baud ≈ 5208
)(
    input  wire       i_clk,
    input  wire       i_reset,
    input  wire       i_rx_serial,
    output reg        o_rx_dv,      // pulse high for 1 clk when byte is valid
    output reg [7:0]  o_rx_byte
);

    localparam IDLE         = 3'd0;
    localparam START_BIT    = 3'd1;
    localparam DATA_BITS    = 3'd2;
    localparam STOP_BIT     = 3'd3;
    localparam CLEANUP      = 3'd4;

    reg        r_rx_1;
    reg        r_rx_2;
    reg [2:0]  r_state;
    reg [12:0] r_clk_count;
    reg [2:0]  r_bit_index;
    reg [7:0]  r_rx_byte;

    // Double-register input to reduce metastability risk
    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            r_rx_1 <= 1'b1;
            r_rx_2 <= 1'b1;
        end else begin
            r_rx_1 <= i_rx_serial;
            r_rx_2 <= r_rx_1;
        end
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            r_state     <= IDLE;
            r_clk_count <= 13'd0;
            r_bit_index <= 3'd0;
            r_rx_byte   <= 8'd0;
            o_rx_dv     <= 1'b0;
            o_rx_byte   <= 8'd0;
        end else begin
            o_rx_dv <= 1'b0;  // default

            case (r_state)
                IDLE: begin
                    r_clk_count <= 13'd0;
                    r_bit_index <= 3'd0;

                    if (r_rx_2 == 1'b0) begin
                        // possible start bit detected
                        r_state <= START_BIT;
                    end
                end

                START_BIT: begin
                    // Check the middle of start bit
                    if (r_clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (r_rx_2 == 1'b0) begin
                            r_clk_count <= 13'd0;
                            r_state     <= DATA_BITS;
                        end else begin
                            // false start bit
                            r_state <= IDLE;
                        end
                    end else begin
                        r_clk_count <= r_clk_count + 1'b1;
                    end
                end

                DATA_BITS: begin
                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 1'b1;
                    end else begin
                        r_clk_count <= 13'd0;
                        r_rx_byte[r_bit_index] <= r_rx_2;

                        if (r_bit_index < 3'd7) begin
                            r_bit_index <= r_bit_index + 1'b1;
                        end else begin
                            r_bit_index <= 3'd0;
                            r_state     <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 1'b1;
                    end else begin
                        o_rx_dv     <= 1'b1;
                        o_rx_byte   <= r_rx_byte;
                        r_clk_count <= 13'd0;
                        r_state     <= CLEANUP;
                    end
                end

                CLEANUP: begin
                    r_state <= IDLE;
                end

                default: begin
                    r_state <= IDLE;
                end
            endcase
        end
    end

endmodule