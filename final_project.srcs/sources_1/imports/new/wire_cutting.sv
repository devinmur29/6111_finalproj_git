`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2020 01:29:09 AM
// Design Name: 
// Module Name: wire_cutting
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


module wire_cutting (
   input vclock_in,        // 65MHz clock
   input reset_in,         // 1 to initialize module
   input up_in,            // 1 when paddle should move up
   input down_in,          // 1 when paddle should move down
   input [3:0] pspeed_in,  // puck speed in pixels/tick 
   input [10:0] hcount_in, // horizontal index of current pixel (0..1023)
   input [9:0]  vcount_in, // vertical index of current pixel (0..767)
   input hsync_in,         // XVGA horizontal sync signal (active low)
   input vsync_in,         // XVGA vertical sync signal (active low)
   input blank_in,         // XVGA blanking (1 means output black pixel)
   input confirm,
   input [5:0] cut_switch,
   input [2:0] incolor1,
   input [2:0] incolor2,
   input [2:0] incolor3,
   input [2:0] incolor4,
   input [2:0] incolor5,
   input [2:0] incolor6,
   
   output logic completed,
   output logic failed,
   output logic phsync_out,       // pong game's horizontal sync
   output logic pvsync_out,       // pong game's vertical sync
   output logic pblank_out,       // pong game's blanking
   output logic [11:0] pixel_out  // pong game's pixel  // r=11:8, g=7:4, b=3:0
   );

   assign phsync_out = hsync_in;
   assign pvsync_out = vsync_in;
   assign pblank_out = blank_in;
   
   logic [2:0] incolor1_c, incolor2_c, incolor3_c, incolor4_c, incolor5_c, incolor6_c;
   logic [11:0] color1;
   logic [11:0] color2;
   logic [11:0] color3;
   logic [11:0] color4;
   logic [11:0] color5;
   logic [11:0] color6;
   
   always_comb begin
       case(incolor1_c)
           3'b000 : color1 = 12'hF00;
           3'b001 : color1 = 12'h0F0;
           3'b010 : color1 = 12'h00F;
           3'b011 : color1 = 12'hFF0;
           3'b100 : color1 = 12'b0100_0000_0100;
           3'b101 : color1 = 12'b0100_0100_0100;
           3'b110 : color1 = 12'hF00;
           3'b111 : color1 = 12'h0F0;
           default : color1 = 12'hF00;
       endcase
   end
   
   always_comb begin
       case(incolor2_c)
           3'b000 : color2 = 12'hF00;
           3'b001 : color2 = 12'h0F0;
           3'b010 : color2 = 12'h00F;
           3'b011 : color2 = 12'hFF0;
           3'b100 : color2 = 12'b0100_0000_0100;
           3'b101 : color2 = 12'b0100_0100_0100;
           3'b110 : color2 = 12'hF00;
           3'b111 : color2 = 12'h00F;
           default : color2 = 12'hFF0;
       endcase
   end
   
   always_comb begin
       case(incolor3_c)
           3'b000 : color3 = 12'hF00;
           3'b001 : color3 = 12'h0F0;
           3'b010 : color3 = 12'h00F;
           3'b011 : color3 = 12'hFF0;
           3'b100 : color3 = 12'b0100_0000_0100;
           3'b101 : color3 = 12'b0100_0100_0100;
           3'b110 : color3 = 12'b0100_0000_0100;
           3'b111 : color3 = 12'b0100_0100_0100;
           default : color3 = 12'b0100_0100_0100;
       endcase
   end
   
   always_comb begin
       case(incolor4_c)
           3'b000 : color4 = 12'hF00;
           3'b001 : color4 = 12'h0F0;
           3'b010 : color4 = 12'h00F;
           3'b011 : color4 = 12'hFF0;
           3'b100 : color4 = 12'b0100_0000_0100;
           3'b101 : color4 = 12'b0100_0100_0100;
           3'b110 : color4 = 12'hF00;
           3'b111 : color4 = 12'h0F0;
           default : color4 = 12'hF00;
       endcase
   end
   
   always_comb begin
       case(incolor5_c)
           3'b000 : color5 = 12'hF00;
           3'b001 : color5 = 12'h0F0;
           3'b010 : color5 = 12'h00F;
           3'b011 : color5 = 12'hFF0;
           3'b100 : color5 = 12'b0100_0000_0100;
           3'b101 : color5 = 12'b0100_0100_0100;
           3'b110 : color5 = 12'hF00;
           3'b111 : color5 = 12'h00F;
           default : color5 = 12'hFF0;
       endcase
   end
   
   always_comb begin
       case(incolor6_c)
           3'b000 : color6 = 12'hF00;
           3'b001 : color6 = 12'h0F0;
           3'b010 : color6 = 12'h00F;
           3'b011 : color6 = 12'hFF0;
           3'b100 : color6 = 12'b0100_0000_0100;
           3'b101 : color6 = 12'b0100_0100_0100;
           3'b110 : color6 = 12'b0100_0000_0100;
           3'b111 : color6 = 12'b0100_0100_0100;
           default : color6 = 12'b0100_0100_0100;
       endcase
   end

   logic [5:0] need_to_cut_wire;
   logic [2:0] correct_cut;
  
   logic count1;
   logic count2;
   logic count3;
   logic count4;
   logic count5;
   
   logic [3:0] total_count;

   count_num w12 (.comparecolor1(color1), .comparecolor2(color2), .count(count1));
   count_num w13 (.comparecolor1(color1), .comparecolor2(color3), .count(count2));
   count_num w14 (.comparecolor1(color1), .comparecolor2(color4), .count(count3));
   count_num w15 (.comparecolor1(color1), .comparecolor2(color5), .count(count4));
   count_num w16 (.comparecolor1(color1), .comparecolor2(color6), .count(count5));
   
   assign total_count = count1 + count2 + count3 + count4 + count5 + 1;
   
   always_comb begin
       if (color1 == 12'b1111_0000_0000) begin
            if (total_count == 1) begin
                need_to_cut_wire = 6'b000001;
            end 
            if (total_count == 2) begin
                need_to_cut_wire = 6'b000010;
            end
            if (total_count == 3) begin
                need_to_cut_wire = 6'b000100;
            end
            if (total_count == 4) begin
                need_to_cut_wire = 6'b001000;
            end
            if (total_count == 5) begin
                need_to_cut_wire = 6'b010000;
            end
            if (total_count == 6) begin
                need_to_cut_wire = 6'b100000;
            end
       end
       if (color1 == 12'b0000_1111_0000) begin
            if (total_count == 1) begin
                need_to_cut_wire = 6'b100000;
            end 
            if (total_count == 2) begin
                need_to_cut_wire = 6'b000100;
            end
            if (total_count == 3) begin
                need_to_cut_wire = 6'b010000;
            end
            if (total_count == 4) begin
                need_to_cut_wire = 6'b000010;
            end
            if (total_count == 5) begin
                need_to_cut_wire = 6'b001000;
            end
            if (total_count == 6) begin
                need_to_cut_wire = 6'b000001;
            end
       end
       if (color1 == 12'b0000_0000_1111) begin
            if (total_count == 1) begin
                need_to_cut_wire = 6'b001000;
            end 
            if (total_count == 2) begin
                need_to_cut_wire = 6'b000100;
            end
            if (total_count == 3) begin
                need_to_cut_wire = 6'b100000;
            end
            if (total_count == 4) begin
                need_to_cut_wire = 6'b000001;
            end
            if (total_count == 5) begin
                need_to_cut_wire = 6'b010000;
            end
            if (total_count == 6) begin
                need_to_cut_wire = 6'b000010;
            end
       end
       if (color1 == 12'b1111_1111_0000) begin
            if (total_count == 1) begin
                need_to_cut_wire = 6'b000001;
            end 
            if (total_count == 2) begin
                need_to_cut_wire = 6'b000010;
            end
            if (total_count == 3) begin
                need_to_cut_wire = 6'b001000;
            end
            if (total_count == 4) begin
                need_to_cut_wire = 6'b000100;
            end
            if (total_count == 5) begin
                need_to_cut_wire = 6'b100000;
            end
            if (total_count == 6) begin
                need_to_cut_wire = 6'b010000;
            end
       end
       if (color1 == 12'b0100_0000_0100) begin
            if (total_count == 1) begin
                need_to_cut_wire = 6'b000010;
            end 
            if (total_count == 2) begin
                need_to_cut_wire = 6'b100000;
            end
            if (total_count == 3) begin
                need_to_cut_wire = 6'b000001;
            end
            if (total_count == 4) begin
                need_to_cut_wire = 6'b010000;
            end
            if (total_count == 5) begin
                need_to_cut_wire = 6'b000100;
            end
            if (total_count == 6) begin
                need_to_cut_wire = 6'b001000;
            end
       end
       if (color1 == 12'b0100_0100_0100) begin
            if (total_count == 1) begin
                need_to_cut_wire = 6'b000100;
            end 
            if (total_count == 2) begin
                need_to_cut_wire = 6'b000001;
            end
            if (total_count == 3) begin
                need_to_cut_wire = 6'b000010;
            end
            if (total_count == 4) begin
                need_to_cut_wire = 6'b001000;
            end
            if (total_count == 5) begin
                need_to_cut_wire = 6'b010000;
            end
            if (total_count == 6) begin
                need_to_cut_wire = 6'b100000;
            end
       end
   end
   
   logic [31:0] delay;
   
   always_ff @(posedge vclock_in)begin
        if(reset_in) begin
            delay <= 0;
            completed <= 0;
            failed <= 0;
        end else begin
        if (correct_cut != 3'b110)begin
            delay <= delay + 1;
        end else begin
            delay <= 0;
        end 
        if (delay >= 24_000_000) begin
            if (correct_cut == 3'b010)begin
                completed <= 1;
                failed <= 0;
            end else begin
                completed = 0;
                failed <= 1;
            end 
        end else begin
            completed <= 0;
            failed <= 0;
        end
    end
   end
   always_ff@(posedge vclock_in) begin
        if(reset_in) begin
                incolor1_c <= incolor1;
                incolor2_c <= incolor2;
                incolor3_c <= incolor3;
                incolor4_c <= incolor4;
                incolor5_c <= incolor5;
                incolor6_c <= incolor6;
            
        end else begin
        if (cut_switch == need_to_cut_wire)begin
            correct_cut <= 3'b010;
        end else begin
            if (cut_switch == 6'b000000)begin
                correct_cut <= 3'b110;
            end else begin
                if ((need_to_cut_wire != cut_switch) && (cut_switch[0] + cut_switch[1] + cut_switch[2] + cut_switch[3] + cut_switch[4]
                    + cut_switch[5] >= 1)) begin
                    correct_cut <= 3'b100;
                end
            end
        end
      end
   end
   
   logic [11:0] blobcolor1;
   logic [11:0] blobcolor2;
   logic [11:0] blobcolor3;
   logic [11:0] blobcolor4;
   logic [11:0] blobcolor5;
   logic [11:0] blobcolor6;
   
   assign blobcolor1 = cut_switch[5] == 1? 12'h000 : color1;
   assign blobcolor2 = cut_switch[4] == 1? 12'h000 : color2;
   assign blobcolor3 = cut_switch[3] == 1? 12'h000 : color3;
   assign blobcolor4 = cut_switch[2] == 1? 12'h000 : color4;
   assign blobcolor5 = cut_switch[1] == 1? 12'h000 : color5;
   assign blobcolor6 = cut_switch[0] == 1? 12'h000 : color6;
   
   logic [11:0] wire_pixel;
//   logic [11:0] color1;
//   assign color1 = 12'b1111_0000_0000;
   
   wire_blob wb (.pixel_clk_in(vclock_in),.x_in(173),.hcount_in(hcount_in), .color(blobcolor1), 
           .y_in(200), .vcount_in(vcount_in), .pixel_out(wire_pixel));
   
   logic [11:0] wire_pixel2;
   //logic [11:0] color2;
//   assign color2 = 12'b0000_1111_0000;
   
   wire_blob wb2 (.pixel_clk_in(vclock_in),.x_in(213),.hcount_in(hcount_in), .color(blobcolor2), 
           .y_in(200), .vcount_in(vcount_in), .pixel_out(wire_pixel2));
   
   logic [11:0] wire_pixel3;
   //logic [11:0] color3;
//   assign color3 = 12'b0000_0000_1111;
   
   wire_blob wb3 (.pixel_clk_in(vclock_in),.x_in(253),.hcount_in(hcount_in), .color(blobcolor3), 
           .y_in(200), .vcount_in(vcount_in), .pixel_out(wire_pixel3));
   
   logic [11:0] wire_pixel4;
   //logic [11:0] color4;
//   assign color4 = 12'b1111_1111_0000;
   
   wire_blob wb4 (.pixel_clk_in(vclock_in),.x_in(293),.hcount_in(hcount_in), .color(blobcolor4), 
           .y_in(200), .vcount_in(vcount_in), .pixel_out(wire_pixel4));
   
   logic [11:0] wire_pixel5;
   //logic [11:0] color5;
//   assign color5 = 12'b0100_0000_0100;
   
   wire_blob wb5 (.pixel_clk_in(vclock_in),.x_in(333),.hcount_in(hcount_in), .color(blobcolor5), 
           .y_in(200), .vcount_in(vcount_in), .pixel_out(wire_pixel5));
   
   logic [11:0] wire_pixel6;
   //logic [11:0] color6;
//   assign color6 = 12'b0100_0100_0100;
   
   wire_blob wb6 (.pixel_clk_in(vclock_in),.x_in(373),.hcount_in(hcount_in), .color(blobcolor6), 
           .y_in(200), .vcount_in(vcount_in), .pixel_out(wire_pixel6));
   
   assign pixel_out = wire_pixel | wire_pixel | wire_pixel2 | wire_pixel3 | wire_pixel4
                        | wire_pixel5 | wire_pixel6;
   
     
endmodule