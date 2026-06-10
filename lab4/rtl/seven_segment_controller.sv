/**
 * seven_segment_controller.sv - 8-Digit 7-Segment Display Controller
 *
 * Drives the Nexys A7 8-digit common-anode display. Each Ti view occupies two
 * digits (high nibble on the left, low nibble on the right):
 *
 *   an[7] an[6]   an[5] an[4]   an[3] an[2]   an[1] an[0]
 *   <-- T3 -->    <-- T2 -->    <-- T1 -->    <-- T0 -->
 *
 * Multiplexed at 500 Hz per-digit refresh (each digit lit for 250 us).
 * Cathodes and anodes are driven active-low to match the board hardware.
 */

`timescale 1ns / 1ps

module seven_segment_controller #(
    parameter int DIGIT_PERIOD = 25_000   // 100 MHz / (500 Hz * 8 digits)
) (
    input  logic clk,
    input  logic rst_n,

    input  logic [7:0] t0_data,   // T0: full byte
    input  logic [7:0] t1_data,   // T1: full byte
    input  logic [7:0] t2_data,   // T2: full byte
    input  logic [7:0] t3_data,   // T3: full byte

    input  logic [7:0] dp_enable, // active-high mask: bit i lights DP on an[i]

    output logic [7:0] an,        // anode enables (active low, one-cold)
    output logic [6:0] segment,   // {g,f,e,d,c,b,a} (active low)
    output logic       dp         // decimal point (active low)
);

    logic [$clog2(DIGIT_PERIOD):0] refresh_counter;
    logic [2:0] digit_select;
    logic [3:0] current_nibble;
    logic [6:0] decoded_segments;

    // Refresh sweep: bump digit_select once per DIGIT_PERIOD cycles.
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            refresh_counter <= '0;
            digit_select    <= 3'd0;
        end
        else if (refresh_counter == (DIGIT_PERIOD - 1)) begin
            refresh_counter <= '0;
            digit_select    <= digit_select + 1'b1;
        end
        else begin
            refresh_counter <= refresh_counter + 1'b1;
        end
    end

    // Map each digit position to the nibble it should show.
    // Even positions display the low nibble, odd positions the high nibble
    // of the corresponding Ti.
    always_comb begin
        unique case (digit_select)
            3'd0: current_nibble = t0_data[3:0];
            3'd1: current_nibble = t0_data[7:4];
            3'd2: current_nibble = t1_data[3:0];
            3'd3: current_nibble = t1_data[7:4];
            3'd4: current_nibble = t2_data[3:0];
            3'd5: current_nibble = t2_data[7:4];
            3'd6: current_nibble = t3_data[3:0];
            3'd7: current_nibble = t3_data[7:4];
        endcase
    end

    seven_segment_decoder decoder (
        .digit(current_nibble),
        .segments(decoded_segments)
    );

    // One-cold anode (active low, only the selected digit driven low).
    assign an = ~(8'b0000_0001 << digit_select);

    // Invert the decoder's active-high pattern for the common-anode pads.
    assign segment = ~decoded_segments;

    // DP is active low. Light it when the per-digit enable bit is set for the
    // digit currently being scanned.
    assign dp = ~dp_enable[digit_select];

endmodule
