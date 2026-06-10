/**
 * button_latch.sv - Debouncer and Switch Configuration Latch
 * 
 * Purpose: Debounce the center push-button and latch switch configuration
 * when button is held for > 1 second.
 * 
 * Behavior:
 * 1. Debounce button input (20ms stable period)
 * 2. Detect when button held for > 1 second
 * 3. Latch SW[14:0] configuration on trigger
 * 4. Hold latched values until next trigger
 */

`timescale 1ns / 1ps

module button_latch #(
    parameter int DEBOUNCE_CYCLES = 2_000_000,   // 20 ms at 100 MHz
    parameter int LATCH_CYCLES = 100_000_000     // 1 second at 100 MHz
) (
    input  logic clk,                    // System clock (100 MHz)
    input  logic rst_n,                  // Active-low reset
    input  logic button,                 // Raw button input (active high)
    input  logic [14:0] sw_config,       // Switch configuration inputs
    
    output logic [14:0] latched_config,  // Latched switch values
    output logic latch_triggered         // One-cycle pulse when latch occurs
);

    // State machine states
    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        DEBOUNCE = 2'b01,
        WAIT     = 2'b10,
        LATCH    = 2'b11
    } state_t;

    state_t state, state_next;
    logic [26:0] counter;            // Counter for debounce and latch timing
    logic button_debounced;          // Debounced button signal

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            counter <= 0;
            button_debounced <= 0;
            latched_config <= 0;
            latch_triggered <= 0;
        end
        else begin
            // Default: latch_triggered is not asserted
            latch_triggered <= 0;

            case (state)
                IDLE: begin
                    if (button) begin
                        state <= DEBOUNCE;
                        counter <= 0;
                    end
                end

                DEBOUNCE: begin
                    if (button) begin
                        counter <= counter + 1;
                        if (counter == (DEBOUNCE_CYCLES - 1)) begin
                            button_debounced <= 1;
                            state <= WAIT;
                            counter <= 0;
                        end
                    end
                    else begin
                        state <= IDLE;
                        counter <= 0;
                    end
                end

                WAIT: begin
                    if (button) begin
                        counter <= counter + 1;
                        if (counter == (LATCH_CYCLES - 1)) begin
                            state <= LATCH;
                            counter <= 0;
                        end
                    end
                    else begin
                        state <= IDLE;
                        button_debounced <= 0;
                        counter <= 0;
                    end
                end

                LATCH: begin
                    latched_config <= sw_config;
                    latch_triggered <= 1;
                    
                    if (button) begin
                        state <= WAIT;
                        counter <= 0;
                    end
                    else begin
                        state <= IDLE;
                        button_debounced <= 0;
                        counter <= 0;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
