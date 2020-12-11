`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2020 12:01:28 AM
// Design Name: 
// Module Name: FPGA_graphics
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


module FPGA_graphics( input vclock_in,
                      input reset_in,
                      input [10:0] hcount_in,
                      input [9:0] vcount_in,
                      input [2:0] mg_completed,
                      input [1:0] strikes,
                      output logic [11:0] pixel_out

    );
    logic [11:0] fpga_pixel, pixel_out1, pixel_out2, pixel_out3, pixel_out4, pixel_out5, pixel_out6;
    logic [11:0] s1_out, s2_out;
    
    logic [11:0] color_1, color_2, color_3, color_4, color_5, color_6;
    logic [11:0] s_color1, s_color2;
    picture_blob_fpga fpga_inst (.pixel_clk_in(vclock_in), .x_in(11'd15), .y_in(10'd15), .hcount_in(hcount_in),
                        .vcount_in(vcount_in), .pixel_out(fpga_pixel));
    
    circle_blob  #(.RADIUS(4)) c1 (.x_in(11'd30), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_1), .pixel_out(pixel_out1));
    circle_blob  #(.RADIUS(4)) c2 (.x_in(11'd42), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_2), .pixel_out(pixel_out2));
    circle_blob  #(.RADIUS(4)) c3 (.x_in(11'd54), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_3), .pixel_out(pixel_out3));
    circle_blob  #(.RADIUS(4)) c4 (.x_in(11'd66), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_4), .pixel_out(pixel_out4));
    circle_blob  #(.RADIUS(4)) c5 (.x_in(11'd78), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_5), .pixel_out(pixel_out5));
    circle_blob  #(.RADIUS(4)) c6 (.x_in(11'd90), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_6), .pixel_out(pixel_out6));
    
    ///////////////strikes/////////////////////////////////////
    circle_blob  #(.RADIUS(16)) s1 (.x_in(11'd496), .y_in(10'd432), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(s_color1), .pixel_out(s1_out));
    circle_blob  #(.RADIUS(16)) s2 (.x_in(11'd544), .y_in(10'd432), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(s_color2), .pixel_out(s2_out));
    
    
    
    
    
    always_comb begin
    
        if ((pixel_out1!=0)|(pixel_out2!=0)|(pixel_out3!=0)|(pixel_out4!=0)|(pixel_out5!=0)|(pixel_out6!=0)) begin
            pixel_out = pixel_out1 + pixel_out2 + pixel_out3 + pixel_out4 +pixel_out5+pixel_out6 + s1_out + s2_out;
        end else pixel_out = fpga_pixel+s1_out+s2_out;
    end
    
    always_ff @(posedge vclock_in) begin
        if(reset_in) begin
            color_1 <= 12'hF00;
            color_2 <= 12'hF00;
            color_3 <= 12'hF00;
            color_4 <= 12'hF00;
            color_5 <= 12'hF00;
            color_6 <= 12'hF00;
            
            s_color1 <= 12'h000;
            s_color2 <=12'h000;
            
            
         end else begin
            case(mg_completed)
                3'b001  : color_1 <= 12'h0F0;
                3'b010  : color_2 <= 12'h0F0;
                3'b011  : color_3 <= 12'h0F0;
                3'b100  : color_4 <= 12'h0F0;
                3'b101  : color_5 <= 12'h0F0;
                3'b110  : color_5 <= 12'h0F0;
            endcase 
            
            case (strikes)
                2'b01   :   s_color1 <= 12'hF00;
                2'b10   :   s_color2 <= 12'hF00;
                default :   begin end
            endcase
         end
       end   
endmodule

module FPGA_graphics_op( input vclock_in,
                      input reset_in,
                      input [10:0] hcount_in,
                      input [9:0] vcount_in,
                      input [2:0] mg_completed,
                      output logic [11:0] pixel_out

    );
    logic [11:0] fpga_pixel, pixel_out1, pixel_out2, pixel_out3, pixel_out4, pixel_out5, pixel_out6;
    logic [11:0] color_1, color_2, color_3, color_4, color_5, color_6;
    picture_blob_fpga fpga_inst_op (.pixel_clk_in(vclock_in), .x_in(11'd371), .y_in(10'd15), .hcount_in(hcount_in),
                        .vcount_in(vcount_in), .pixel_out(fpga_pixel));
    
    circle_blob  #(.RADIUS(4)) c1 (.x_in(11'd386), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_1), .pixel_out(pixel_out1));
    circle_blob  #(.RADIUS(4)) c2 (.x_in(11'd398), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_2), .pixel_out(pixel_out2));
    circle_blob  #(.RADIUS(4)) c3 (.x_in(11'd410), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_3), .pixel_out(pixel_out3));
    circle_blob  #(.RADIUS(4)) c4 (.x_in(11'd422), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_4), .pixel_out(pixel_out4));
    circle_blob  #(.RADIUS(4)) c5 (.x_in(11'd432), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_5), .pixel_out(pixel_out5));
    circle_blob  #(.RADIUS(4)) c6 (.x_in(11'd444), .y_in(10'd50), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_6), .pixel_out(pixel_out6));
    always_comb begin
    
        if ((pixel_out1!=0)|(pixel_out2!=0)|(pixel_out3!=0)|(pixel_out4!=0)|(pixel_out5!=0)|(pixel_out6!=0)) begin
            pixel_out = pixel_out1 + pixel_out2 + pixel_out3 + pixel_out4 +pixel_out5+pixel_out6;
        end else pixel_out = fpga_pixel;
    end
    
    always_ff @(posedge vclock_in) begin
        if(reset_in) begin
            color_1 <= 12'hF00;
            color_2 <= 12'hF00;
            color_3 <= 12'hF00;
            color_4 <= 12'hF00;
            color_5 <= 12'hF00;
            color_6 <= 12'hF00;
         end else begin
            case(mg_completed)
                3'b001  : color_1 <= 12'h0F0;
                3'b010  : color_2 <= 12'h0F0;
                3'b011  : color_3 <= 12'h0F0;
                3'b100  : color_4 <= 12'h0F0;
                3'b101  : color_5 <= 12'h0F0;
                3'b110  : color_6 <= 12'h0F0;
            endcase 
         end
       end   
endmodule
