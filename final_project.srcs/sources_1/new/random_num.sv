`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2020 05:55:21 PM
// Design Name: 
// Module Name: random_num
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


module random_num( input clock,
                  input data,
                  output logic[15:0] random_number
    );
    
    logic[15:0] r = 16'hFFFF;
    always_ff @(posedge clock) begin
                r[0] <= data + r[15];
                r[1] <= r[0];
                r[2] <= r[1]+r[15]+data;
                r[14:3] <= r[13:2];
                r[15] <= r[14]+r[15]+data;
                
         end        
     assign random_number = r;
endmodule
