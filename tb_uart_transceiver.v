`timescale 1ns/1ps

module tb_uart_transceiver;

    // 50 MHz clock => 20 ns period
    localparam CLK_PERIOD   = 20;
    localparam CLKS_PER_BIT = 5208;   // for 9600 baud with 50 MHz clock
    localparam TEST_BYTE    = 8'hA5;

    reg        i_clk;
    reg        i_reset;
    reg        i_tx_dv;
    reg [7:0]  i_tx_byte;
    wire       o_tx_active;
    wire       o_tx_serial;
    wire       o_tx_done;

    wire       o_rx_dv;
    wire [7:0] o_rx_byte;

    wire uart_line;

    reg        rx_seen;
    reg [7:0]  rx_captured;

    assign uart_line = o_tx_serial;

    uart_transceiver #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .i_clk(i_clk),
        .i_reset(i_reset),

        .i_tx_dv(i_tx_dv),
        .i_tx_byte(i_tx_byte),
        .o_tx_active(o_tx_active),
        .o_tx_serial(o_tx_serial),
        .o_tx_done(o_tx_done),

        .i_rx_serial(uart_line),
        .o_rx_dv(o_rx_dv),
        .o_rx_byte(o_rx_byte)
    );

    // Clock generation
    initial begin
        i_clk = 1'b0;
        forever #(CLK_PERIOD/2) i_clk = ~i_clk;
    end

    // Capture received byte
    always @(posedge i_clk) begin
        if (i_reset) begin
            rx_seen     <= 1'b0;
            rx_captured <= 8'h00;
        end else if (o_rx_dv) begin
            rx_seen     <= 1'b1;
            rx_captured <= o_rx_byte;
            $display("RX byte received = 0x%h at time %0t", o_rx_byte, $time);
        end
    end

    // Main stimulus
    initial begin
        i_reset   = 1'b1;
        i_tx_dv   = 1'b0;
        i_tx_byte = 8'h00;

        #(10*CLK_PERIOD);
        i_reset = 1'b0;

        #(10*CLK_PERIOD);

        // Send one byte
        @(posedge i_clk);
        i_tx_byte = TEST_BYTE;
        i_tx_dv   = 1'b1;

        @(posedge i_clk);
        i_tx_dv   = 1'b0;

        // Wait for transmission and reception
        wait (rx_seen == 1'b1);

        if (rx_captured == TEST_BYTE) begin
            $display("PASS: Expected = 0x%h, Received = 0x%h", TEST_BYTE, rx_captured);
        end else begin
            $display("FAIL: Expected = 0x%h, Received = 0x%h", TEST_BYTE, rx_captured);
        end

        #(20*CLK_PERIOD);
        $stop;
    end

endmodule