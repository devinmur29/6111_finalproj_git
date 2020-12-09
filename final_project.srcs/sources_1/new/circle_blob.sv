`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/04/2020 03:09:48 PM
// Design Name: 
// Module Name: circle_blob
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


module circle_blob

   #(parameter RADIUS = 64)  // default color: 
   (input [10:0] x_in,hcount_in,
    input [9:0] y_in,vcount_in,
    input vclock_in,
    output logic [11:0] pixel_out,
    input [11:0] color);
    
    logic[21:0] radiussquared, radiussquared2;
    logic[21:0] deltax, deltax2;
    logic[21:0] deltay, deltay2;
    
    always_comb begin // generate round puck
	// compute x-xcenter and y-ycenter
	radiussquared = RADIUS*RADIUS; // RADIUS is a paramater
	deltax = (hcount_in > (x_in+RADIUS)) ? (hcount_in-(x_in+RADIUS)) : ((x_in+RADIUS)-hcount_in);
	deltay = (vcount_in > (y_in+RADIUS)) ? (vcount_in-(y_in+RADIUS)) : ((y_in+RADIUS)-vcount_in);
	// check if distance is less than radius squared
	if(deltax2*deltax2+deltay2*deltay2 <= radiussquared2)
		pixel_out = color;
 	else 
 		pixel_out = 0;
 end
 
 always_ff @(posedge vclock_in) begin
        radiussquared2 <= radiussquared;
        deltax2 <= deltax;
        deltay2 <= deltay;
        end

        
    
    
    
endmodule
