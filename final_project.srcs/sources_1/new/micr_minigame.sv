`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/07/2020 02:06:59 PM
// Design Name: 
// Module Name: micr_minigame
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


module micr_minigame(
    input  vclock_in,
    input reset_in,
    input [10:0] hcount_in,
    input [9:0] vcount_in,
    input hsync_in,
    input vsync_in,
    input blank_in,
    input button,
    input [23:0] sqrt_data,
    input sqrt_valid,
    input sqrt_last,
    input [3:0] minigame_number,
    input [2:0] rand_addr_num,
    
    output logic completed,
    output logic phsync_out,
    output logic pvsync_out,
    output logic pblank_out,
    output logic [11:0] pixel_out,
    output logic [9:0] cool_led
    );
    
    assign phsync_out = hsync_in;
    assign pvsync_out = vsync_in;
    assign pblank_out = blank_in;
    
    logic [11:0] lower_color;
    logic [11:0] correct_color;
    logic [11:0] higher_color;

    always_comb begin
        case(minigame_number)
            3'b000  : begin
                        lower_color = 12'b1111_0000_0000; //red
                        correct_color = 12'b0000_1111_0000; //green
                        higher_color = 12'b0000_0000_1111; //blue
                      end
            3'b001  : begin
                        lower_color = 12'b1111_1111_0000; //yellow
                        correct_color = 12'b000_1111_1111; //cyan
                        higher_color = 12'b1111_0000_0000; //red
                      end
            3'b010  : begin
                        lower_color = 12'b0000_1111_0000; //green
                        correct_color = 12'b000_0000_1111; //blue
                        higher_color = 12'b1111_1111_0000; //yellow
                      end
            3'b011  : begin
                        lower_color = 12'b0100_0000_0100; //purple
                        correct_color = 12'b1011_0100_0000; //orange
                        higher_color = 12'b0000_1111_1111; //cyan
                      end
            3'b100  : begin
                        lower_color = 12'b1111_1111_1111; //white
                        correct_color = 12'b1111_0000_0000; //red
                        higher_color = 12'b0100_0000_0100; //purple
                      end
            3'b101  : begin
                        lower_color = 12'b1011_0100_0000; //orange
                        correct_color = 12'b1111_1111_1111; //white
                        higher_color = 12'b0000_1111_0000; //green
                      end
            default : begin
                        lower_color = 12'b1011_0100_0000; //orange
                        correct_color = 12'b1111_1111_1111; //white
                        higher_color = 12'b0000_1111_0000; //green
                      end
        endcase
    end
    
    logic [9:0] addr_count;
    logic [9:0] highest_addr_output;
    assign cool_led = highest_addr_output;
    logic [9:0] highest_addr;
    logic [23:0] max_peak;
    
    

    always_ff @(posedge vclock_in)begin
        if (sqrt_valid)begin
            if (sqrt_last)begin
                addr_count <= 0;
                highest_addr_output <= highest_addr;
                highest_addr <= 0;
                max_peak <= 0;
            end else begin
                addr_count <= addr_count + 1'b1;
                if (sqrt_data > max_peak && addr_count > 5 && addr_count < 512) begin
                    max_peak <= sqrt_data;
                    highest_addr <= addr_count;
                end
            end
        end 
    end 
    
    logic [4:0] desired_addr;
    assign desired_addr = 12;

    logic [11:0] color;
    
    always_ff @(posedge vclock_in) begin
        if (highest_addr_output > desired_addr + 1) begin
            color <= higher_color;
        end else begin
            if (highest_addr_output < desired_addr - 1) begin
                color <= lower_color;
            end else begin
                color <= correct_color;
            end
        end
    end
    
    logic [31:0] counter;
    
    always_ff @(posedge vclock_in) begin
        if (color == correct_color) begin
            counter <= counter + 1;
        end else begin
            if (counter >= 200000000) begin
                counter <= counter + 1;
            end else begin
                counter <= 0;
            end
        end
    end
    
    logic [11:0] pixel;
    
    always_comb begin
        if  ((hcount_in >= 580 && hcount_in < (610)) &&
          (vcount_in >= 200 && vcount_in < (300)))
            pixel = color;
        else 
            pixel = 0;
     end
   
     logic [11:0] covered_pixel;
     logic [11:0] cracked_pixel;
     logic [11:0] uncovered_pixel;
     
     picture_blob covered (.pixel_clk_in(vclock_in),.x_in(244),.hcount_in(hcount_in), 
           .y_in(200), .vcount_in(vcount_in), .pixel_out(covered_pixel));
                 
     cracked_blob cracked (.pixel_clk_in(vclock_in),.x_in(244),.hcount_in(hcount_in), 
           .y_in(200), .vcount_in(vcount_in), .pixel_out(cracked_pixel));
   
     uncovered_blob uncovered (.pixel_clk_in(vclock_in),.x_in(244),.hcount_in(hcount_in), 
           .y_in(200), .vcount_in(vcount_in), .pixel_out(uncovered_pixel));
           
     always_comb begin
        if (counter >= 200_000_000) begin
            //finished_color = 12'b0000_1111_0000;
            //switch_images = 1'b1;
            if (counter >= 300_000_000) begin
                pixel_out = pixel | uncovered_pixel;
                if (button) begin
                    completed = 1'b1;
                end else begin
                    completed = 1'b0;
                end
            end else begin
                pixel_out = pixel | cracked_pixel;
                completed = 1'b0;
                //start_new_count = 1'b1;
            end
        end else begin
            //finished_color = 12'b1111_0000_0000;
            pixel_out = pixel | covered_pixel;
            completed = 1'b0;
            //start_new_count = 1'b0;
        end
    end
    
endmodule
