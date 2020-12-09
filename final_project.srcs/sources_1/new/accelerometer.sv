`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Willie Zhu <zhuw@mit.edu>
//
// Create Date: 12/03/2020 09:20:26 PM
// Design Name:
// Module Name: accelerometer
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

package accel;
    typedef enum logic[2:0] { center, top, bottom, left, right } e_orientation;
endpackage

// High-level abstraction for the built-in accelerometer.
// Outputs the current orientation 
module accelerometer(
    input clk_in,
    input reset_in,
    input acl_miso,
    output acl_mosi,
    output acl_sclk,
    output acl_csn,
    
    output accel::e_orientation orientation
    );

    // -------------------------------------------------------------------------------------
    // Process data from the ADXL
    //
    logic [11:0] accel_x, accel_y, accel_z, accel_temp;
    logic [11:0] accel_x_latch, accel_y_latch;
    logic [11:0] x_mag, x_mag_filtered, y_mag, y_mag_filtered;
    logic [3:0] x_sign, y_sign;

    logic data_ready;

    always_ff @(posedge clk_in) begin
        accel_x_latch <= data_ready ? accel_x : accel_x_latch;
        accel_y_latch <= data_ready ? accel_y : accel_y_latch;
    end

    // this section displays twos complement in + - format
    assign x_mag = accel_x_latch[11] ? (~accel_x_latch +1)  : accel_x_latch;
    assign y_mag = accel_y_latch[11] ? (~accel_y_latch +1)  : accel_y_latch;

    assign x_sign = accel_x_latch[11] ? 4'hF : 4'h0;
    assign y_sign = accel_y_latch[11] ? 4'hF : 4'h0;

    // average samples
    iir_filter x_filter(.clk(clk_in), .data_ready(data_ready), .data_in(x_mag), .data_filtered(x_mag_filtered));
    iir_filter y_filter(.clk(clk_in), .data_ready(data_ready), .data_in(y_mag), .data_filtered(y_mag_filtered));

    // if the tilt of the board in any x/y direction exceeds this number, output that orientation;
    // otherwise, output accel::center (i.e. the board is flat on the table)
    localparam BOARD_ORIENTATION_THRESHOLD = 12'h140;

//    logic [31:0] data2;
//    assign data2 = {x_sign, x_mag_filtered, y_sign, y_mag_filtered};
    always_ff @(posedge clk_in) begin
        if (reset_in) begin
            orientation <= accel::center;
        end else begin
            if (x_sign == 4'hF && x_mag_filtered > BOARD_ORIENTATION_THRESHOLD) begin
                orientation <= accel::bottom;
            end else if (x_sign == 4'h0 && x_mag_filtered > BOARD_ORIENTATION_THRESHOLD) begin
                orientation <= accel::top;
            end else if (y_sign == 4'hF && y_mag_filtered > BOARD_ORIENTATION_THRESHOLD) begin
                orientation <= accel::left;
            end else if (y_sign == 4'h0 && y_mag_filtered > BOARD_ORIENTATION_THRESHOLD) begin
                orientation <= accel::right;
            end else begin
                orientation <= accel::center;
            end
        end
    end

    // acl_miso  acl_mosi  acl_sclk  acl_csn

    ADXL362Ctrl my_accel(
        .SYSCLK     (clk_in),   // in
        .RESET      (reset_in),        // in

        .ACCEL_X    (accel_x),      // out STD_LOGIC_VECTOR (11 downto 0);
        .ACCEL_Y    (accel_y),      // out STD_LOGIC_VECTOR (11 downto 0);
        .ACCEL_Z    (accel_z),      // out STD_LOGIC_VECTOR (11 downto 0);
        .ACCEL_TMP  (accel_temp),   // out STD_LOGIC_VECTOR (11 downto 0);
        .Data_Ready (data_ready),   // out STD_LOGIC;

        .SCLK       (acl_sclk),     // out
        .MOSI       (acl_mosi),     // out
        .MISO       (acl_miso),     // in
        .SS         (acl_csn)       // out STD_LOGIC
    );
endmodule
