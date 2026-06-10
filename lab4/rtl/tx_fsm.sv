/**
 * tx_fsm.sv - UART TX Finite State Machine
 * 
 * Purpose: Manage transmission of data bytes with special characters
 * and inter-byte delays.
 * 
 * FSM States:
 *  IDLE     - Waiting for start signal
 *  DELAY    - Inter-byte delay (configurable)
 *  DATA     - Send data byte (LSB first through 8 bits)
 *  DELIM    - Send delimiter (0x20)
 *  CR       - Send CR (0x0D) at end of row
 *  LF       - Send LF (0x0A) at end of row
 *  DONE     - Transmission complete
 * 
 * Implementation: always_comb + always_ff for clean SV style
 */

`timescale 1ns / 1ps

module tx_fsm #(
    parameter int DELAY_0_CYCLES = 0,
    parameter int DELAY_1_CYCLES = 5_000_000,    // 50ms
    parameter int DELAY_2_CYCLES = 10_000_000,   // 100ms
    parameter int DELAY_3_CYCLES = 20_000_000    // 200ms
) (
    input  logic clk,                  // System clock (100 MHz)
    input  logic rst_n,                // Active-low reset
    input  logic baud_pulse,           // Baud rate pulse (57,600 Hz)
    
    // Control signals
    input  logic start,                // Start transmission
    input  logic [7:0] data_byte,      // Data byte to send
    input  logic [1:0] speed_config,   // Delay mode (0-3)
    input  logic [16:0] num_bytes,     // Total bytes to send (up to 256*256)
    input  logic [8:0] bytes_per_row_mask, // Row-end mask (N-1): 0/31/127/255
    
    // Output signals
    output logic tx_line,              // UART TX output (idle high)
    output logic [7:0] tx_data,        // Current data byte on TX
    output logic data_byte_sent,       // Pulse when data byte sent
    output logic delimiter_sent,       // Pulse when delimiter sent
    output logic row_done,             // Pulse at end of LF (one row finished)
    output logic led_toggle,           // LED toggle on each data byte
    output logic transmission_done,    // Asserted when all bytes sent
    
    // Debug/Status
    output logic [2:0] current_state,  // FSM state for debugging
    output logic fsm_active            // High when FSM is active (not idle)
);

    // State definitions using typedef
    typedef enum logic [2:0] {
        IDLE   = 3'b000,
        DELAY  = 3'b001,
        DATA   = 3'b010,
        DELIM  = 3'b011,
        CR     = 3'b100,
        LF     = 3'b101,
        DONE   = 3'b110
    } state_t;

    state_t state, state_next;
    
    // Internal registers
    logic [16:0] byte_count;           // Count of bytes sent (up to 65536)
    logic [3:0] bit_count;             // Count of bits sent in current byte
    logic [25:0] delay_counter;        // Counter for inter-byte delays
    logic [7:0] data_reg;              // Register to hold data byte
    logic led_state;                   // Toggle state for LED

    // Status outputs
    assign current_state = logic'(state);
    assign fsm_active = (state != IDLE);

    // =================================================================
    // State Update Logic (sequential always_ff)
    // =================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= state_next;
        end
    end

    // =================================================================
    // Next State Logic (combinational always_comb)
    // =================================================================
    always_comb begin
        state_next = state;

        case (state)
            IDLE: begin
                if (start) begin
                    state_next = DELAY;
                end
            end

            DELAY: begin
                if (delay_counter == 0) begin
                    state_next = DATA;
                end
            end

            DATA: begin
                if (baud_pulse && bit_count == 9) begin
                    state_next = DELIM;
                end
            end

            DELIM: begin
                // Wait for full delimiter byte (start + 8 data + stop) before advancing.
                // End-of-row when the low bits of byte_count are all zero. With mask = N-1
                // for power-of-2 row widths, this is equivalent to byte_count % N == 0
                // but synthesizes to a row of ANDs instead of a divider.
                if (baud_pulse && bit_count == 9) begin
                    if ((byte_count[8:0] & bytes_per_row_mask) == 9'd0) begin
                        state_next = CR;
                    end
                    else begin
                        state_next = DELAY;
                    end
                end
            end

            CR: begin
                // CR is always followed by LF, even on the final row.
                if (baud_pulse && bit_count == 9) begin
                    state_next = LF;
                end
            end

            LF: begin
                if (baud_pulse && bit_count == 9) begin
                    if (byte_count == num_bytes) begin
                        state_next = DONE;
                    end
                    else begin
                        state_next = DELAY;
                    end
                end
            end

            DONE: begin
                state_next = IDLE;
            end

            default: begin
                state_next = IDLE;
            end
        endcase
    end

    // =================================================================
    // Output Logic and Counter Updates (sequential always_ff)
    // =================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            byte_count <= 0;
            bit_count <= 0;
            delay_counter <= 0;
            data_reg <= 0;
            led_state <= 0;
            tx_line <= 1;
            tx_data <= 0;
            data_byte_sent <= 0;
            delimiter_sent <= 0;
            row_done <= 0;
            led_toggle <= 0;
            transmission_done <= 0;
        end
        else begin
            // Default: single-cycle pulses
            data_byte_sent <= 0;
            delimiter_sent <= 0;
            row_done <= 0;
            led_toggle <= 0;
            transmission_done <= 0;

            // Delay counter: load on entry to DELAY, decrement while inside DELAY.
            // Also (re)latch the data byte so DATA always shifts fresh data,
            // since DELIM/CR/LF overwrite data_reg with their literals.
            if (state != DELAY && state_next == DELAY) begin
                case (speed_config)
                    2'b00: delay_counter <= 26'd0;
                    2'b01: delay_counter <= DELAY_1_CYCLES - 1;
                    2'b10: delay_counter <= DELAY_2_CYCLES - 1;
                    2'b11: delay_counter <= DELAY_3_CYCLES - 1;
                endcase
                data_reg <= data_byte;
            end
            else if (state == DELAY && delay_counter > 0) begin
                delay_counter <= delay_counter - 1;
            end

            case (state)
                IDLE: begin
                    tx_line <= 1;
                    byte_count <= 0;
                    bit_count <= 0;
                    led_state <= 0;
                end

                DELAY: begin
                    // Counter management handled by the transition-based block above.
                    tx_line <= 1;
                end

                DATA: begin
                    if (baud_pulse) begin
                        if (bit_count == 0) begin
                            tx_line <= 0;  // Start bit
                            bit_count <= bit_count + 1;
                        end
                        else if (bit_count <= 8) begin
                            tx_line <= data_reg[bit_count - 1];  // LSB first
                            bit_count <= bit_count + 1;
                        end
                        else begin
                            tx_line <= 1;  // Stop bit
                        end
                    end
                    
                    if (state_next == DELIM) begin
                        byte_count <= byte_count + 1;
                        data_byte_sent <= 1;
                        led_state <= ~led_state;
                        led_toggle <= 1;
                        bit_count <= 0;
                    end
                end

                DELIM: begin
                    if (baud_pulse) begin
                        if (bit_count == 0) begin
                            tx_line <= 0;
                            data_reg <= 8'h20;  // Delimiter
                            bit_count <= bit_count + 1;
                        end
                        else if (bit_count <= 8) begin
                            tx_line <= data_reg[bit_count - 1];
                            bit_count <= bit_count + 1;
                        end
                        else begin
                            tx_line <= 1;
                            bit_count <= 0;
                            delimiter_sent <= 1;
                        end
                    end
                end

                CR: begin
                    if (baud_pulse) begin
                        if (bit_count == 0) begin
                            tx_line <= 0;
                            data_reg <= 8'h0D;  // CR
                            bit_count <= bit_count + 1;
                        end
                        else if (bit_count <= 8) begin
                            tx_line <= data_reg[bit_count - 1];
                            bit_count <= bit_count + 1;
                        end
                        else begin
                            tx_line <= 1;
                            bit_count <= 0;
                        end
                    end
                end

                LF: begin
                    if (baud_pulse) begin
                        if (bit_count == 0) begin
                            tx_line <= 0;
                            data_reg <= 8'h0A;  // LF
                            bit_count <= bit_count + 1;
                        end
                        else if (bit_count <= 8) begin
                            tx_line <= data_reg[bit_count - 1];
                            bit_count <= bit_count + 1;
                        end
                        else begin
                            tx_line <= 1;
                            bit_count <= 0;
                            row_done <= 1;
                        end
                    end
                end

                DONE: begin
                    transmission_done <= 1;
                    tx_line <= 1;
                end

                default: begin
                    tx_line <= 1;
                end
            endcase
        end
    end

endmodule
