/**
 * uart_phy.sv - UART Physical Layer - Baud Rate Generator
 * 
 * Purpose: Generate baud rate clock for UART TX/RX
 * Baud Rate: 57,600 bps
 * System Clock: 100 MHz
 * Divisor: 1736
 * 
 * This module counts clock cycles and generates a pulse each time
 * the divisor count is reached. This pulse is used to clock the
 * UART state machine at the baud rate.
 */

`timescale 1ns / 1ps

module uart_phy #(
    parameter int DIVISOR = 1736
) (
    input  logic clk,           // System clock (100 MHz)
    input  logic rst_n,         // Active-low reset
    
    output logic baud_pulse     // Baud rate pulse (57,600 Hz)
);

    // Counter to divide the system clock
    // For 57,600 bps: 100MHz / 57,600 = 1736 cycles
    logic [$clog2(DIVISOR)-1:0] baud_counter;
    
    // Baud pulse generation (combinational)
    assign baud_pulse = (baud_counter == 0);
    
    // Counter logic (sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            baud_counter <= 0;
        end
        else begin
            if (baud_counter == (DIVISOR - 1)) begin
                baud_counter <= 0;
            end
            else begin
                baud_counter <= baud_counter + 1;
            end
        end
    end

endmodule
