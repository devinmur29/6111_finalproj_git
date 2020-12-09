`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2020 01:27:14 AM
// Design Name: 
// Module Name: count_num
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


module count_num (input [11:0] comparecolor1, input [11:0] comparecolor2, output logic count);
    
    always_comb begin
        if (comparecolor1 == comparecolor2) begin
            count = 1;
        end else begin
            count = 0;
        end
    end
endmodule
