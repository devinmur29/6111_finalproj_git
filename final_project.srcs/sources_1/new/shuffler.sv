`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Willie Zhu <zhuw@mit.edu>
// 
// Create Date: 12/04/2020 10:04:32 AM
// Design Name: 
// Module Name: shuffler
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// This implements the modern Fisher-Yates shuffle.
// It uses an un-pipelined divider, which means you can't shuffle large datasets, but
// shuffling 2^4 (16) items seems to work pretty well @ 100 MHz.

// Change these widths; default is for shuffling 8 4-bit wide items packed into data_in.
// random_in should be connected to the output of a random number generator that 
// **changes every cycle**
module shuffler
    #(parameter NUM_SHUFFLED_ITEMS = 8,
      parameter SHUFFLED_ITEM_BITS = 4
    )
    (
        input clk_in,
        input reset_in,
        input [NUM_SHUFFLED_ITEMS * SHUFFLED_ITEM_BITS - 1:0] data_in,
        input [SHUFFLED_ITEM_BITS - 1:0]  random_in,
        input should_shuffle_in,
        output logic [NUM_SHUFFLED_ITEMS * SHUFFLED_ITEM_BITS - 1:0] data_out,
        output logic valid_out
    );

    logic [SHUFFLED_ITEM_BITS - 1:0] a, b, rem;

    divfunc #(.XLEN(SHUFFLED_ITEM_BITS)) divider (.clk(clk_in), .rst(reset_in), 
                                 .a, .b, .vld(1'b1), .quo(), .rem, .ack());

    always_ff @(posedge clk_in) begin
        if (reset_in) begin
            a <= 0;
            b <= 0;

            data_out <= 0;
        end else if (should_shuffle_in && b == 0) begin
            a <= random_in;
            b <= NUM_SHUFFLED_ITEMS;

            data_out <= data_in;
            valid_out <= 1'b0;
        end else begin
            // shuffle
            if (b) begin
                a <= random_in;
                b <= b - 1;
                if (rem <= (b - 1)) begin
                    data_out[rem * SHUFFLED_ITEM_BITS +: SHUFFLED_ITEM_BITS] <= data_out[(b - 1) * SHUFFLED_ITEM_BITS +: SHUFFLED_ITEM_BITS];
                    data_out[(b - 1) * SHUFFLED_ITEM_BITS +: SHUFFLED_ITEM_BITS] <= data_out[rem * SHUFFLED_ITEM_BITS +: SHUFFLED_ITEM_BITS];
                end
            end else begin
                valid_out <= 1'b1;
            end
        end
    end

endmodule
