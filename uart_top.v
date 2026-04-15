module uart_top (
    input  wire CLOCK_50,     // 50 MHz clock
    input  wire [1:0] KEY,    // push buttons
    input  wire [3:0] SW,     // switches
    output wire [7:0] LED,    // LEDs
    input  wire GPIO_0_D0,    // UART RX
    output wire GPIO_0_D1     // UART TX
);

    wire reset;
    assign reset = ~KEY[0];   // button is active LOW

    wire tx_active;
    wire tx_done;
    wire rx_dv;
    wire [7:0] rx_byte;

    reg tx_dv;
    reg btn_d1, btn_d2;
    reg [7:0] rx_led_reg;

    // Button edge detection for KEY[1]
    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            btn_d1 <= 0;
            btn_d2 <= 0;
            tx_dv  <= 0;
        end else begin
            btn_d1 <= ~KEY[1];
            btn_d2 <= btn_d1;
            tx_dv  <= btn_d1 & ~btn_d2;
        end
    end

    // Latch received byte onto LEDs
    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            rx_led_reg <= 8'h00;
        end else if (rx_dv) begin
            rx_led_reg <= rx_byte;
        end
    end

    // UART instance
    uart_transceiver #(
        .CLKS_PER_BIT(5208)
    ) uart_inst (
        .i_clk(CLOCK_50),
        .i_reset(reset),
        .i_tx_dv(tx_dv),
        .i_tx_byte(8'hA5),    // fixed test byte
        .o_tx_active(tx_active),
        .o_tx_serial(GPIO_0_D1),
        .o_tx_done(tx_done),
        .i_rx_serial(GPIO_0_D0),
        .o_rx_dv(rx_dv),
        .o_rx_byte(rx_byte)
    );

    // Show received byte on LEDs
    assign LED = rx_led_reg;

endmodule