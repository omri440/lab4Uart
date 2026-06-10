`timescale 1ns / 1ps

module tx_uart_controller_tb;

    localparam int CLK_PERIOD_NS = 10;
    localparam int SIM_BAUD_DIVISOR = 8;
    localparam int SIM_DEBOUNCE_CYCLES = 4;
    localparam int SIM_LATCH_CYCLES = 16;
    localparam int SIM_DELAY_1_CYCLES = 6;
    localparam int SIM_DELAY_2_CYCLES = 10;
    localparam int SIM_DELAY_3_CYCLES = 14;
    localparam int SIM_DIGIT_PERIOD = 8;

    logic clk;
    logic rst_n;
    logic [14:0] sw;
    logic center_btn;
    logic uart_tx;
    logic [0:0] led;
    logic [7:0] an;
    logic [6:0] segment;
    logic       dp;

    byte rx_byte;
    byte delimiter_byte;

    tx_uart_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .sw(sw),
        .center_btn(center_btn),
        .uart_tx(uart_tx),
        .led(led),
        .an(an),
        .segment(segment),
        .dp(dp)
    );

    defparam dut.uart_phy_inst.DIVISOR = SIM_BAUD_DIVISOR;
    defparam dut.button_latch_inst.DEBOUNCE_CYCLES = SIM_DEBOUNCE_CYCLES;
    defparam dut.button_latch_inst.LATCH_CYCLES = SIM_LATCH_CYCLES;
    defparam dut.tx_fsm_inst.DELAY_1_CYCLES = SIM_DELAY_1_CYCLES;
    defparam dut.tx_fsm_inst.DELAY_2_CYCLES = SIM_DELAY_2_CYCLES;
    defparam dut.tx_fsm_inst.DELAY_3_CYCLES = SIM_DELAY_3_CYCLES;
    defparam dut.seven_seg_inst.DIGIT_PERIOD = SIM_DIGIT_PERIOD;

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task automatic reset_dut();
        begin
            clk = 1'b0;
            rst_n = 1'b0;
            sw = '0;
            center_btn = 1'b0;
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic latch_configuration(input logic [14:0] new_sw);
        begin
            sw = new_sw;
            @(posedge clk);
            center_btn = 1'b1;
            // Hold the button until LATCH actually fires, then release.
            // This avoids the race where the latch pulse would already be
            // back to 0 by the time the wait statement runs.
            wait (dut.latch_triggered === 1'b1);
            @(posedge clk);
            center_btn = 1'b0;
            // Give the button_latch FSM a few cycles to return to IDLE so
            // the next call sees a clean rising edge on center_btn.
            repeat (SIM_DEBOUNCE_CYCLES + 4) @(posedge clk);
        end
    endtask

    task automatic receive_uart_byte(output byte value);
        begin
            value = 8'h00;
            @(negedge uart_tx);
            for (int bit_index = 0; bit_index < 8; bit_index++) begin
                @(posedge dut.baud_pulse);
                value[bit_index] = uart_tx;
            end
            @(posedge dut.baud_pulse);
            if (uart_tx !== 1'b1) begin
                $error("UART stop bit was not high");
            end
        end
    endtask

    task automatic expect_equal_byte(
        input byte actual_value,
        input byte expected_value,
        input string label
    );
        begin
            if (actual_value !== expected_value) begin
                $error("%s mismatch. expected=0x%02h actual=0x%02h", label, expected_value, actual_value);
            end
            else begin
                $display("[TB] %s ok: 0x%02h", label, actual_value);
            end
        end
    endtask

    // Quiet variant: only complain on mismatch. Used for the 32x32 stream
    // where logging every byte would produce thousands of lines.
    task automatic expect_equal_byte_quiet(
        input byte actual_value,
        input byte expected_value,
        input string label,
        input int   index
    );
        begin
            if (actual_value !== expected_value) begin
                $error("%s[%0d] mismatch. expected=0x%02h actual=0x%02h",
                       label, index, expected_value, actual_value);
            end
        end
    endtask

    initial begin
        $dumpfile("tx_uart_controller_tb.vcd");
        $dumpvars(0, tx_uart_controller_tb);

        reset_dut();

        latch_configuration({2'b00, 3'b000, 2'b00, 8'hA5});

        if (dut.latched_config !== {2'b00, 3'b000, 2'b00, 8'hA5}) begin
            $error("Latched configuration mismatch");
        end

        if (dut.num_bytes_to_send !== 17'd1) begin
            $error("Expected 1x1 matrix mode after latching");
        end

        receive_uart_byte(rx_byte);
        expect_equal_byte(rx_byte, 8'hA5, "data byte");

        receive_uart_byte(delimiter_byte);
        expect_equal_byte(delimiter_byte, 8'h20, "delimiter byte");

        if (led[0] !== 1'b1) begin
            $error("LED did not toggle after first data byte");
        end

        // Wait for CR + LF + DONE so the row counter has incremented.
        wait (dut.transmission_done === 1'b1);
        @(posedge clk);

        if (dut.transmitted_count !== 17'd1) begin
            $error("Transmitted byte counter mismatch. expected=1 actual=%0d", dut.transmitted_count);
        end

        if (dut.t0_data !== 8'hA5) begin
            $error("Expected T0 to show full byte 0xA5, got 0x%02h", dut.t0_data);
        end

        if (dut.t1_data !== 8'h00) begin
            $error("Expected T1 to show 0x00 (speed 0.0), got 0x%02h", dut.t1_data);
        end

        if (dut.t2_data !== 8'h01) begin
            $error("Expected T2 to show 0x01 (1-byte mode), got 0x%02h", dut.t2_data);
        end

        if (dut.t3_data !== 8'h01) begin
            $error("Expected T3 to show 0x01 (one row sent), got 0x%02h", dut.t3_data);
        end

        // ============================================================
        // 32 x 32 matrix test - exercises row CR/LF boundary and the
        // row counter. Data byte 0x5A, speed 0, mode SW[14:13]=01.
        // Expect 1024 data bytes, 1024 delimiters, 32 CR, 32 LF.
        // ============================================================
        $display("[TB] -- starting 32x32 matrix test --");

        latch_configuration({2'b01, 3'b000, 2'b00, 8'h5A});

        if (dut.num_bytes_to_send !== 17'd1024) begin
            $error("Expected 32x32 matrix mode (1024 bytes), got %0d", dut.num_bytes_to_send);
        end

        if (dut.bytes_per_row_mask !== 9'd31) begin
            $error("Expected bytes_per_row_mask=31, got %0d", dut.bytes_per_row_mask);
        end

        for (int row = 0; row < 32; row++) begin
            for (int col = 0; col < 32; col++) begin
                receive_uart_byte(rx_byte);
                expect_equal_byte_quiet(rx_byte, 8'h5A, "data", row * 32 + col);

                receive_uart_byte(rx_byte);
                expect_equal_byte_quiet(rx_byte, 8'h20, "delim", row * 32 + col);
            end

            receive_uart_byte(rx_byte);
            expect_equal_byte_quiet(rx_byte, 8'h0D, "cr", row);

            receive_uart_byte(rx_byte);
            expect_equal_byte_quiet(rx_byte, 8'h0A, "lf", row);
        end

        wait (dut.transmission_done === 1'b1);
        @(posedge clk);

        if (dut.transmitted_count !== 17'd1024) begin
            $error("Expected transmitted_count=1024, got %0d", dut.transmitted_count);
        end

        if (dut.row_count !== 8'd32) begin
            $error("Expected row_count=32, got %0d", dut.row_count);
        end

        if (dut.t0_data !== 8'h5A) begin
            $error("Expected T0=0x5A, got 0x%02h", dut.t0_data);
        end

        if (dut.t2_data !== 8'h20) begin
            $error("Expected T2=0x20 (32 bytes/row), got 0x%02h", dut.t2_data);
        end

        if (dut.t3_data !== 8'h20) begin
            $error("Expected T3=0x20 (32 rows sent), got 0x%02h", dut.t3_data);
        end

        $display("[TB] 32x32 matrix test passed");
        $display("[TB] Simulation finished");
        $finish;
    end

endmodule