`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2020 08:13:34 PM
// Design Name: 
// Module Name: strike_graphics
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


module strike_graphics(
   input vclock_in,        // 65MHz clock
   input reset_in,         // 1 to initialize module 
   input [10:0] hcount_in, // horizontal index of current pixel (0..1023)
   input [9:0]  vcount_in, // vertical index of current pixel (0..767)
   input hsync_in,         // XVGA horizontal sync signal (active low)
   input vsync_in,         // XVGA vertical sync signal (active low)
   input blank_in,         // XVGA blanking (1 means output black pixel)
   input [1:0] num_strikes,
   
   output logic [26:0] new_one_hz,
   output logic phsync_out,       // pong game's horizontal sync
   output logic pvsync_out,       // pong game's vertical sync
   output logic pblank_out,       // pong game's blanking
   output logic [11:0] pixel_out 

    );
    
    assign phsync_out = hsync_in;
    assign pvsync_out = vsync_in;
    assign pblank_out = blank_in;
    
    logic [11:0] strike1_pixel;
    circle_blob  #(.RADIUS(8)) circle1 (.x_in(540), .y_in(440), .vclock_in(vclock_in), 
                .vcount_in(vcount_in), .hcount_in(hcount_in), .color(12'hF00), .pixel_out(strike1_pixel));
    
    logic [11:0] strike2_pixel;
    circle_blob  #(.RADIUS(8)) circle2 (.x_in(564), .y_in(440), .vclock_in(vclock_in), 
                .vcount_in(vcount_in), .hcount_in(hcount_in), .color(12'hF00), .pixel_out(strike2_pixel));
                
    logic [11:0] strike3_pixel;
    circle_blob  #(.RADIUS(8)) circle3 (.x_in(588), .y_in(440), .vclock_in(vclock_in), 
                .vcount_in(vcount_in), .hcount_in(hcount_in), .color(12'hF00), .pixel_out(strike3_pixel));
    
    logic [11:0] blank;
    circle_blob  #(.RADIUS(8)) circle4 (.x_in(612), .y_in(440), .vclock_in(vclock_in), 
                .vcount_in(vcount_in), .hcount_in(hcount_in), .color(12'h000), .pixel_out(blank_pixel));
    
    always_comb begin
        if (num_strikes == 2'b01) begin
            pixel_out = strike1_pixel;
            new_one_hz = 20_000_000;
        end else if (num_strikes == 2'b10) begin
            pixel_out = strike2_pixel + strike1_pixel;
            new_one_hz = 10_000_000;
        end else if (num_strikes == 2'b11) begin
            pixel_out = strike3_pixel + strike2_pixel + strike1_pixel;
            new_one_hz = 25_000_000;
        end
    end
            
            
    
endmodule
