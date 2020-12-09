`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2020 01:31:57 AM
// Design Name: 
// Module Name: button_game
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


module button_game (
   input vclock_in,        // 65MHz clock
   input reset_in,         // 1 to initialize module 
   input [10:0] hcount_in, // horizontal index of current pixel (0..1023)
   input [9:0]  vcount_in, // vertical index of current pixel (0..767)
   input hsync_in,         // XVGA horizontal sync signal (active low)
   input vsync_in,         // XVGA vertical sync signal (active low)
   input blank_in,         // XVGA blanking (1 means output black pixel)
   input confirm,
   input [1:0] rand_button_color,
   input rand_strip_color,
   input rand_has_text,
   input pushed_button,
   input [3:0] ones,
   input [3:0] tens,
   input [3:0] minutes,
   
   output logic failed,
   output logic completed,
   output logic phsync_out,       // pong game's horizontal sync
   output logic pvsync_out,       // pong game's vertical sync
   output logic pblank_out,       // pong game's blanking
   output logic [11:0] pixel_out  // pong game's pixel  // r=11:8, g=7:4, b=3:0
   );

   logic [11:0] button_color;
   logic released;
   logic [1:0] rand_button_color1;
   logic rand_strip_color1;
   logic rand_has_text1;
   
   
   always_comb begin
       case (rand_button_color1)
           2'b00 : button_color = 12'hF00;
           2'b01 : button_color = 12'h0F0;
           2'b10 : button_color = 12'h00F;
           2'b11 : button_color = 12'hFFF;
           default : button_color = 12'hFFF;
       endcase
   end
   logic [11:0] strip_color;
   always_comb begin
       case (rand_strip_color1)
           1'b0 : strip_color = 12'hFF0;
           1'b1 : strip_color = 12'h0FF;
           default : strip_color = 12'hFF0;
       endcase
   end
   logic has_text;
   assign has_text = rand_has_text1;
         
   assign phsync_out = hsync_in;
   assign pvsync_out = vsync_in;
   assign pblank_out = blank_in;
   
   logic [11:0] strip_pixel;
   always_comb begin
      if  (((hcount_in >= 260 && hcount_in < 380)) &&
            ((vcount_in >= 400 && vcount_in < 420))&& pushed_button)
        strip_pixel = strip_color;
      else 
        strip_pixel = 0;
   end
   
   logic prev_push;
   logic [31:0] counter;
   logic just_pushed;
   logic [31:0] counter1;
   logic prev_push1;
   logic [3:0] push_min;
   logic [3:0] push_tens;
   logic [3:0] push_ones;
   
   always_ff @(posedge vclock_in)begin
      if (reset_in) begin
          prev_push1 <= pushed_button;
          just_pushed <= 0;
          counter1 <= 0;
          push_min <= 0;
          push_tens <= 0;
          push_ones <= 0;
          rand_button_color1 <= rand_button_color;
          rand_strip_color1 <= rand_strip_color;
          rand_has_text1 <= rand_has_text;
          
          
      end else begin
          if (counter1 == 1_000_000)begin
               if ((pushed_button == 1) && (prev_push1 == 0))begin
                   just_pushed <= 1;
                   push_min <= minutes;
                   push_tens <= tens;
                   push_ones <= ones;
               end else begin
                   just_pushed <= 0;
               end
               counter1 <= 0;
               prev_push1 <= pushed_button;
           end else begin
               counter1 <= counter1 + 1;
           end 
       end
   end
   
   logic [3:0] rel_min;
   logic [3:0] rel_tens;
   logic [3:0] rel_ones;
   
   always_ff @(posedge vclock_in)begin
       if (reset_in) begin
           prev_push <= pushed_button;
           released <= 0;
           counter <= 0;
           rel_min <= 0;
           rel_tens <= 0;
           rel_ones <= 0;
       end else begin
           if (counter == 1_000_000)begin
               if ((pushed_button == 0) && (prev_push == 1))begin
                   released <= 1;
                   rel_min <= minutes;
                   rel_tens <= tens;
                   rel_ones <= ones;
               end else begin
                   released <= 0;
               end
               counter <= 0;
               prev_push <= pushed_button;
           end else begin
               counter <= counter + 1;
           end 
       end
   end
   
   always_comb begin
       if (has_text == 0) begin
           if (button_color == 12'hFFF) begin
               if ((push_min == 7) | (push_ones == 7) | (push_tens == 7))begin
                   if ((rel_min == 2) | (rel_ones == 2) | (rel_tens == 2))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                           failed = 0;
                           completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end else begin
                   if ((push_min == 0) && (push_ones == 0) && (push_tens == 0))begin
                       failed = 0;
                       completed = 0;
                   end else begin
                       failed = 1;
                       completed = 0;
                   end
               end
           end
           if (button_color == 12'h00F) begin
               if (strip_color == 12'hFF0)begin
                   if ((rel_min == 1) | (rel_ones == 1) | (rel_tens == 1))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                            failed = 0;
                            completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end
               if (strip_color == 12'h0FF)begin
                   if ((rel_min == 5) | (rel_ones == 5) | (rel_tens == 5))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                            failed = 0;
                            completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end
           end
           if (button_color == 12'h0F0) begin
               if ((push_min == 9) | (push_ones == 9) | (push_tens == 9))begin
                   if ((rel_min == 5) | (rel_ones == 5) | (rel_tens == 5))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                           failed = 0;
                           completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end else begin
                   if ((push_min == 0) && (push_ones == 0) && (push_tens == 0))begin
                       failed = 0;
                       completed = 0;
                   end else begin
                       failed = 1;
                       completed = 0;
                   end
               end
           end
           if (button_color == 12'hF00) begin
               if (strip_color == 12'hFF0)begin
                   if ((rel_min == 4) | (rel_ones == 4) | (rel_tens == 4))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                            failed = 0;
                            completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end
               if (strip_color == 12'h0FF)begin
                   if ((rel_min == 2) | (rel_ones == 2) | (rel_tens == 2))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                            failed = 0;
                            completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end
           end
       end else begin
       if (button_color == 12'h00F) begin
               if ((push_min == 8) | (push_ones == 8) | (push_tens == 8))begin
                   if ((rel_min == 4) | (rel_ones == 4) | (rel_tens == 4))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                           failed = 0;
                           completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end else begin
                   if ((push_min == 0) && (push_ones == 0) && (push_tens == 0))begin
                       failed = 0;
                       completed = 0;
                   end else begin
                       failed = 1;
                       completed = 0;
                   end
               end
           end
           if (button_color == 12'hFFF) begin
               if (strip_color == 12'hFF0)begin
                   if ((rel_min == 3) | (rel_ones == 3) | (rel_tens == 3))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                            failed = 0;
                            completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end
               if (strip_color == 12'h0FF)begin
                   if ((rel_min == 7) | (rel_ones == 7) | (rel_tens == 7))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                            failed = 0;
                            completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end
           end
           if (button_color == 12'hF00) begin
               if ((push_min == 6) | (push_ones == 6) | (push_tens == 6))begin
                   if ((rel_min == 3) | (rel_ones == 3) | (rel_tens == 3))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                           failed = 0;
                           completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end else begin
                   if ((push_min == 0) && (push_ones == 0) && (push_tens == 0))begin
                       failed = 0;
                       completed = 0;
                   end else begin
                       failed = 1;
                       completed = 0;
                   end
               end
           end
           if (button_color == 12'h0F0) begin
               if (strip_color == 12'hFF0)begin
                   if ((rel_min == 5) | (rel_ones == 5) | (rel_tens == 5))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                            failed = 0;
                            completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end
               if (strip_color == 12'h0FF)begin
                   if ((rel_min == 2) | (rel_ones == 2) | (rel_tens == 2))begin
                       completed = 1;
                       failed = 0;
                   end else begin
                       if ((rel_min == 0) && (rel_ones == 0) && (rel_tens == 0))begin
                            failed = 0;
                            completed = 0;
                       end else begin
                           failed = 1;
                           completed = 0;
                       end
                   end
               end
           end
       end
   end
              
   
   logic [11:0] blbutton_pixel;
   circle_blob  #(.RADIUS(60)) blankbutton (.x_in(260), .y_in(200), .vclock_in(vclock_in), 
                .vcount_in(vcount_in), .hcount_in(hcount_in), .color(button_color), .pixel_out(blbutton_pixel));
   
   logic [11:0] button_pixel;
   textbutton_blob buttonblob (.pixel_clk_in(vclock_in),.x_in(260),.hcount_in(hcount_in), 
           .y_in(200), .vcount_in(vcount_in), .color(button_color), .pixel_out(button_pixel));
   
   always_comb begin
    if (has_text) begin
        pixel_out = button_pixel | strip_pixel;
    end else begin
        pixel_out = blbutton_pixel | strip_pixel;
    end
   end
     
endmodule