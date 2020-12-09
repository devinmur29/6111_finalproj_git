`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2020 01:24:11 AM
// Design Name: 
// Module Name: homescreen_graphics
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


module homescreen_graphics (
   input vclock_in,        // 65MHz clock
   input reset_in,         // 1 to initialize module
   input up_in,            // 1 when paddle should move up
   input down_in,          // 1 when paddle should move down 
   input [10:0] hcount_in, // horizontal index of current pixel (0..1023)
   input [9:0]  vcount_in, // vertical index of current pixel (0..767)
   input hsync_in,         // XVGA horizontal sync signal (active low)
   input vsync_in,         // XVGA vertical sync signal (active low)
   input blank_in,         // XVGA blanking (1 means output black pixel)
   input confirm,
   
   output logic [1:0] mode,
   output logic phsync_out,       // pong game's horizontal sync
   output logic pvsync_out,       // pong game's vertical sync
   output logic pblank_out,       // pong game's blanking
   output logic [11:0] pixel_out  // pong game's pixel  // r=11:8, g=7:4, b=3:0
   );
   
//   assign phsync_out = hsync_in;
//   assign pvsync_out = vsync_in;
//   assign pblank_out = blank_in;
   
//   logic [9:0] select;
//   logic [9:0] xval;
   
//   always_comb begin
//    if (select == 253) begin
//        xval = 470;
//    end else begin
//        xval = 468;
//    end
//   end
   
//   logic prev_confirm;
//   logic prev_up;
//   logic prev_down;
   
//   always_ff @(posedge vclock_in) begin
//        prev_confirm <= confirm;
//        prev_up <= up_in;
//        prev_down <= down_in;
   
//   end
   
//   always_ff @(posedge vclock_in)begin
//        if (reset_in) begin
//            select <= 253;
//        end else begin
//            if (down_in ) begin
//                if (select == 253) begin
//                    select <= 353;
//                end else begin
//                    select <= select;
//                end
//            end else begin
//                if (up_in ) begin
//                    if (select == 353) begin
//                        select <= 253;
//                    end else begin
//                        select <= select;
//                    end
//                end
//            end
//        end
//    end
    
//    always_ff @(posedge vclock_in)begin
//    if(reset_in) begin mode <= 2'b00; end
//    else begin
//        if (confirm ) begin
//            if (select == 253) begin
//                mode <= 2'b01;
//            end else begin
//                mode <= 2'b10;
//            end
//       end else begin
//            mode <= 2'b00;
//       end
//    end
//   end
  
//   logic color_switch;
//   logic [11:0] chosen_color;
//   logic [31:0] counter;
//   always_ff @(posedge vclock_in)begin
//        if (reset_in) begin
//            color_switch <= 0;
//            counter <= 0;
//        end else begin                
//            if (counter > 20_000_000)begin
//                color_switch <= ~color_switch;
//                counter <= 0;
//            end else begin
//                counter <= counter + 1;
//            end
//        end
//    end
        
   logic [11:0] paddle_pixel;
   blob #(.WIDTH(32),.HEIGHT(45),.COLOR(12'b0100_1111_0000))   
          paddle1(.x_in(xval),.y_in(select),.hcount_in(hcount_in),.vcount_in(vcount_in),
          .pixel_out(paddle_pixel));
          
   //logic [11:0] kaboom_pixel;
   logic [11:0] kaboom_pixel;
   kaboom_blob kb (.pixel_clk_in(vclock_in),.x_in(140),.hcount_in(hcount_in), 
           .y_in(50), .vcount_in(vcount_in), .pixel_out(kaboom_pixel));
           
   logic [11:0] sing_pixel;
   sing_blob sb (.pixel_clk_in(vclock_in),.x_in(183),.hcount_in(hcount_in), 
           .y_in(250), .vcount_in(vcount_in), .pixel_out(sing_pixel));
   
   logic [11:0] mult_pixel;
   mult_blob mb (.pixel_clk_in(vclock_in),.x_in(180),.hcount_in(hcount_in), 
           .y_in(350), .vcount_in(vcount_in), .pixel_out(mult_pixel));
           
    assign pixel_out = mult_pixel + sing_pixel +kaboom_pixel + paddle_pixel;
   
//   always_comb begin
//        if (color_switch == 0) begin
//            pixel_out = paddle_pixel + kaboom_pixel + sing_pixel + mult_pixel;
//        end else begin
//            pixel_out = kaboom_pixel + sing_pixel + mult_pixel;
//        end
//   end
     
endmodule
