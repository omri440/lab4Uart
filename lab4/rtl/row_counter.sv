/**
 * row_counter.sv - Counts completed rows within the current transmission frame.
 *
 * Resets to zero each time a new frame starts (button-latch pulse) and
 * increments once per row_done pulse from the FSM (asserted at the end of LF).
 * Saturates at 8'hFF so the display always reflects a real value.
 */

`timescale 1ns / 1ps

module row_counter (
    input  logic clk,
    input  logic rst_n,
    input  logic frame_start,   // pulses on new transmission start
    input  logic row_done,      // pulses at end of every LF
    output logic [7:0] count
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            count <= 8'd0;
        end
        else if (frame_start) begin
            count <= 8'd0;
        end
        else if (row_done && count != 8'hFF) begin
            count <= count + 1'b1;
        end
    end

endmodule
