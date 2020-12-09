`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2020 02:32:36 PM
// Design Name: 
// Module Name: picture_blob_fpga
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


module picture_blob_fpga
   #(parameter WIDTH = 250,     // default picture width
               HEIGHT = 154)    // default picture height
   (input pixel_clk_in,
    input [10:0] x_in,hcount_in,
    input [9:0] y_in,vcount_in,
    output logic [11:0] pixel_out);

   logic [15:0] image_addr;   // num of bits for 400*248 ROM
   logic [7:0] image_bits, red_mapped, green_mapped, blue_mapped;
   // calculate rom address and read the location
   assign image_addr = (hcount_in-x_in) + (vcount_in-y_in) * WIDTH;
   fpga_rom fpga (.clka(pixel_clk_in), .addra(image_addr), .douta(image_bits));

   // use color map to create 4 bits R, 4 bits G, 4 bits B
   // since the image is greyscale, just replicate the red pixels
   // and not bother with the other two color maps.
   fpga_red fgpar_rom (.clka(pixel_clk_in), .addra(image_bits), .douta(red_mapped));
   fpga_green fpgag_rom (.clka(pixel_clk_in), .addra(image_bits), .douta(green_mapped));
   fpga_blue fpgab_rom (.clka(pixel_clk_in), .addra(image_bits), .douta(blue_mapped));
   // note the one clock cycle delay in pixel!
   always_ff @ (posedge pixel_clk_in) begin
     if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
          (vcount_in >= y_in && vcount_in < (y_in+HEIGHT)))
        // use MSB 4 bits
       
        
        
        pixel_out <= {red_mapped[7:4], green_mapped[7:4], blue_mapped[7:4]}; // greyscale
        //pixel_out <= {red_mapped[7:4], 8h'0}; // only red hues
        else pixel_out <= 0;
   end
endmodule
