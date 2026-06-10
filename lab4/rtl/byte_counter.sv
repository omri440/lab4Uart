/**
 * byte_counter.sv - Transmitted Bytes Counter
 * 
 * Purpose: Count the number of data bytes transmitted (not including
 * delimiter and special characters). Display on T3 7-segment display.
 * 
 * Counts only DATA bytes, not:
 * - Delimiter characters (0x20)
 * - Row end characters (0x0D, 0x0A)
 */

`timescale 1ns / 1ps

module byte_counter (
    input  logic clk,              // System clock
    input  logic rst_n,            // Active-low reset
    input  logic start,            // Start transmission signal
    input  logic data_byte_sent,   // Pulse when a DATA byte is sent
    input  logic [16:0] num_bytes, // Total bytes to send (up to 256*256)

    output logic [16:0] count,     // Current transmission count
    output logic done              // Asserted when all bytes sent
);

    logic [16:0] byte_count;
    
    assign count = byte_count;
    assign done = (byte_count >= num_bytes) && (num_bytes > 0);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            byte_count <= 0;
        end
        else if (start) begin
            byte_count <= 0;
        end
        else if (data_byte_sent && ~done) begin
            byte_count <= byte_count + 1;
        end
    end

endmodule
