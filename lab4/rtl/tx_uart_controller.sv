/**
 * tx_uart_controller.sv - Top-Level UART TX Controller
 *
 * Integrates the UART TX FSM, baud generator, button latch, byte/row counters
 * and the 8-digit 7-segment display controller. Bound to the Nexys A7 board
 * via Nexys-A7-100T-Master.xdc.
 */

`timescale 1ns / 1ps

module tx_uart_controller (
    input  logic clk,              // 100 MHz system clock
    input  logic rst_n,            // CPU_RESETN (active-low)

    input  logic [14:0] sw,        // SW[14:13]=num bytes, SW[9:8]=speed, SW[7:0]=data
    input  logic center_btn,       // BTNC - configuration latch (1 s hold)

    output logic uart_tx,          // UART TX serial line
    output logic [0:0] led,        // LED[0] toggles on every data byte

    output logic [7:0] an,         // 7-seg anode enables (active low)
    output logic [6:0] segment,    // 7-seg cathodes a..g (active low)
    output logic       dp          // 7-seg decimal point (active low)
);

    // --------------------------------------------------------------
    // Internal signals
    // --------------------------------------------------------------
    logic baud_pulse;
    logic [14:0] latched_config;
    logic latch_triggered;

    logic        start_transmission;
    logic [7:0]  tx_byte;
    logic [1:0]  speed_mode;
    logic [16:0] num_bytes_to_send;   // up to 256*256 = 65536
    logic [8:0]  bytes_per_row_mask;

    logic        data_byte_sent;
    logic        delimiter_sent;
    logic        row_done;
    logic        led_toggle;
    logic        transmission_done;
    logic        transmission_in_progress;

    logic [16:0] transmitted_count;   // total data bytes transmitted (up to 65536)
    logic [7:0]  row_count;
    logic        led_state;

    // 7-seg field bytes (high nibble = left digit, low nibble = right digit)
    logic [7:0] t0_data;  // selected data byte
    logic [7:0] t1_data;  // speed config with implicit DP (0.0/0.5/1.0/2.0)
    logic [7:0] t2_data;  // configured num bytes per row
    logic [7:0] t3_data;  // transmitted row count
    logic [7:0] dp_enable;

    // --------------------------------------------------------------
    // Configuration decoding from latched switches
    // --------------------------------------------------------------
    assign speed_mode = latched_config[9:8];
    assign tx_byte    = latched_config[7:0];

    // N x N matrix transmission per the spec: each mode sends an N-by-N square,
    // so the total byte count is N^2 and one row is N bytes (CR/LF every N).
    assign num_bytes_to_send = (latched_config[14:13] == 2'b00) ? 17'd1     :  // 1 x 1
                               (latched_config[14:13] == 2'b01) ? 17'd1024  :  // 32 x 32
                               (latched_config[14:13] == 2'b10) ? 17'd16384 :  // 128 x 128
                                                                  17'd65536;   // 256 x 256

    assign bytes_per_row_mask = (latched_config[14:13] == 2'b00) ? 9'd0   :
                                (latched_config[14:13] == 2'b01) ? 9'd31  :
                                (latched_config[14:13] == 2'b10) ? 9'd127 :
                                                                   9'd255;

    // --------------------------------------------------------------
    // 7-segment field byte composition
    // --------------------------------------------------------------
    // T0: the full data byte (high nibble on left digit, low nibble on right)
    assign t0_data = tx_byte;

    // T1: speed display. The DP belongs to the left (high) digit so the
    // displayed text reads as "0.0", "0.5", "1.0", "2.0".
    always_comb begin
        unique case (speed_mode)
            2'b00: t1_data = 8'h00;   // 0.0
            2'b01: t1_data = 8'h05;   // 0.5
            2'b10: t1_data = 8'h10;   // 1.0
            2'b11: t1_data = 8'h20;   // 2.0
        endcase
    end

    // T2: row width N in hex (1/32/128/256 -> 0x01/0x20/0x80/0x00). 256 wraps
    // to 0x00 in 8 bits; the spec's "Notice the range limit!" acknowledges this.
    always_comb begin
        unique case (latched_config[14:13])
            2'b00: t2_data = 8'h01;   //   1 byte/row
            2'b01: t2_data = 8'h20;   //  32 bytes/row
            2'b10: t2_data = 8'h80;   // 128 bytes/row
            2'b11: t2_data = 8'h00;   // 256 bytes/row (truncated)
        endcase
    end

    // T3: transmitted row count (held by row_counter)
    assign t3_data = row_count;

    // Decimal point only on T1's left digit (an[3]) - always lit so the speed
    // field reads as a fixed-point number.
    assign dp_enable = 8'b0000_1000;

    // --------------------------------------------------------------
    // Submodules
    // --------------------------------------------------------------
    uart_phy #(
        .DIVISOR(1736)
    ) uart_phy_inst (
        .clk(clk),
        .rst_n(rst_n),
        .baud_pulse(baud_pulse)
    );

    button_latch #(
        .DEBOUNCE_CYCLES(2_000_000),    // 20 ms
        .LATCH_CYCLES(100_000_000)      // 1 s
    ) button_latch_inst (
        .clk(clk),
        .rst_n(rst_n),
        .button(center_btn),
        .sw_config(sw),
        .latched_config(latched_config),
        .latch_triggered(latch_triggered)
    );

    tx_fsm #(
        .DELAY_0_CYCLES(0),
        .DELAY_1_CYCLES(5_000_000),
        .DELAY_2_CYCLES(10_000_000),
        .DELAY_3_CYCLES(20_000_000)
    ) tx_fsm_inst (
        .clk(clk),
        .rst_n(rst_n),
        .baud_pulse(baud_pulse),
        .start(start_transmission),
        .data_byte(tx_byte),
        .speed_config(speed_mode),
        .num_bytes(num_bytes_to_send),
        .bytes_per_row_mask(bytes_per_row_mask),
        .tx_line(uart_tx),
        .tx_data(),
        .data_byte_sent(data_byte_sent),
        .delimiter_sent(delimiter_sent),
        .row_done(row_done),
        .led_toggle(led_toggle),
        .transmission_done(transmission_done),
        .current_state(),
        .fsm_active(transmission_in_progress)
    );

    byte_counter byte_counter_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_transmission),
        .data_byte_sent(data_byte_sent),
        .num_bytes(num_bytes_to_send),
        .count(transmitted_count),
        .done()
    );

    row_counter row_counter_inst (
        .clk(clk),
        .rst_n(rst_n),
        .frame_start(start_transmission),
        .row_done(row_done),
        .count(row_count)
    );

    seven_segment_controller #(
        .DIGIT_PERIOD(25_000)            // 100 MHz / (500 Hz * 8 digits)
    ) seven_seg_inst (
        .clk(clk),
        .rst_n(rst_n),
        .t0_data(t0_data),
        .t1_data(t1_data),
        .t2_data(t2_data),
        .t3_data(t3_data),
        .dp_enable(dp_enable),
        .an(an),
        .segment(segment),
        .dp(dp)
    );

    // --------------------------------------------------------------
    // Misc control
    // --------------------------------------------------------------
    assign start_transmission = latch_triggered;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n)            led_state <= 1'b0;
        else if (led_toggle)   led_state <= ~led_state;
    end

    assign led[0] = led_state;

endmodule
