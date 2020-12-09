`timescale 1ns / 1ps

// Miscellaneous math helper modules

module iir_filter(
    input clk, data_ready,
    input[11:0] data_in,
    output [11:0] data_filtered
    );

    logic old_ready;
    logic [14:0] data_average;

    assign data_filtered = data_average[12:1]; // scale it

    always_ff @(posedge clk) begin
        old_ready <= data_ready;
        data_average <= !(old_ready && data_ready) ?
          ((data_in >> 3) + ((7*data_average)>>3)) : data_average;
        end
endmodule
