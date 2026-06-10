/**
 * seven_segment_decoder.sv - 7-Segment Display Decoder
 * 
 * Purpose: Convert a 4-bit hex value to 7-segment display signals
 * for one digit.
 * 
 * Segment layout (active high):
 *   aaa
 *  f   b
 *   ggg
 *  e   c
 *   ddd
 * 
 * Output: {a, b, c, d, e, f, g} for common-anode display
 */

`timescale 1ns / 1ps

module seven_segment_decoder (
    input  logic [3:0] digit,        // 4-bit hex value (0-F)
    output logic [6:0] segments      // 7-segment output {a, b, c, d, e, f, g}
);

    always_comb begin
        case (digit)
            // {a, b, c, d, e, f, g}
            4'h0: segments = 7'b0111111;  // 0
            4'h1: segments = 7'b0000110;  // 1
            4'h2: segments = 7'b1011011;  // 2
            4'h3: segments = 7'b1001111;  // 3
            4'h4: segments = 7'b1100110;  // 4
            4'h5: segments = 7'b1101101;  // 5
            4'h6: segments = 7'b1111101;  // 6
            4'h7: segments = 7'b0000111;  // 7
            4'h8: segments = 7'b1111111;  // 8
            4'h9: segments = 7'b1101111;  // 9
            4'hA: segments = 7'b1110111;  // A
            4'hB: segments = 7'b1111100;  // b
            4'hC: segments = 7'b0111001;  // C
            4'hD: segments = 7'b1011110;  // d
            4'hE: segments = 7'b1111001;  // E
            4'hF: segments = 7'b1110001;  // F
            default: segments = 7'b0000000; // All off
        endcase
    end

endmodule
