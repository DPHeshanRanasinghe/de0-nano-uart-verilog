module uart_tx #(
    parameter CLKS_PER_BIT = 5208  // 50 MHz / 9600 baud ≈ 5208
)(
    input  wire       i_clk,
    input  wire       i_reset,
    input  wire       i_tx_dv,       // pulse high for 1 clk to start transmit
    input  wire [7:0] i_tx_byte,
    output reg        o_tx_active,
    output reg        o_tx_serial,
    output reg        o_tx_done
);

    localparam IDLE       = 3'd0;
    localparam START_BIT  = 3'd1;
    localparam DATA_BITS  = 3'd2;
    localparam STOP_BIT   = 3'd3;
    localparam CLEANUP    = 3'd4;

    reg [2:0]  r_state;
    reg [12:0] r_clk_count;
    reg [2:0]  r_bit_index;
    reg [7:0]  r_tx_data;

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            r_state      <= IDLE;
            r_clk_count  <= 13'd0;
            r_bit_index  <= 3'd0;
            r_tx_data    <= 8'd0;
            o_tx_active  <= 1'b0;
            o_tx_serial  <= 1'b1;  // UART idle is high
            o_tx_done    <= 1'b0;
        end else begin
            o_tx_done <= 1'b0;  // default

            case (r_state)
                IDLE: begin
                    o_tx_serial <= 1'b1;
                    o_tx_active <= 1'b0;
                    r_clk_count <= 13'd0;
                    r_bit_index <= 3'd0;

                    if (i_tx_dv) begin
                        o_tx_active <= 1'b1;
                        r_tx_data   <= i_tx_byte;
                        r_state     <= START_BIT;
                    end
                end

                START_BIT: begin
                    o_tx_serial <= 1'b0;  // start bit

                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 1'b1;
                    end else begin
                        r_clk_count <= 13'd0;
                        r_state     <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    o_tx_serial <= r_tx_data[r_bit_index];

                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 1'b1;
                    end else begin
                        r_clk_count <= 13'd0;

                        if (r_bit_index < 3'd7) begin
                            r_bit_index <= r_bit_index + 1'b1;
                        end else begin
                            r_bit_index <= 3'd0;
                            r_state     <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    o_tx_serial <= 1'b1;  // stop bit

                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 1'b1;
                    end else begin
                        r_clk_count <= 13'd0;
                        o_tx_done   <= 1'b1;
                        o_tx_active <= 1'b0;
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