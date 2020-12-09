`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/09/2020 11:54:17 AM
// Design Name: 
// Module Name: serial_tx
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


module serial_tx(   input           clk_in,
                    input           rst_in,
                    input           trigger_in,
                    input [7:0]     val_in,
                    output logic    data_out);
    parameter   DIVISOR = 800;

    logic [9:0]         shift_buffer; //10 bits...interesting
    logic [15:0]        count;  // counts up to DIVISOR, then sends a bit
    logic [7:0]         bits_left_to_send;
    logic [7:0]         val_in_little_endian;
 
    assign val_in_little_endian = {<<{ val_in }};   // UART sends bit 0 first, so we need to flip endianness.

    always @(posedge clk_in)begin
        count <= count + 1;
        
        if (rst_in) begin   // Reset timer counter and shift buffer. Note: sets data_out to LOW by default.
            count <= 32'd0;
            shift_buffer <= 10'b0;
            bits_left_to_send <= 8'd0;

            data_out <= 1'b1;
        end else if (trigger_in) begin  // capture `val_in`. Note: UART is 1 start bit + 8 data bits + 1 stop bit.
            count <= 32'd0;
            shift_buffer <= {1'b0, val_in_little_endian, 1'b1};
            bits_left_to_send <= 8'd10;
        end else if (bits_left_to_send && count == DIVISOR) begin
            count <= 32'd0;
            bits_left_to_send <= bits_left_to_send - 1;
            
            // shift out bits, MSB first
            shift_buffer <= {shift_buffer[8:0], 1'b0};
            data_out <= shift_buffer[9];
        end
    end              
endmodule