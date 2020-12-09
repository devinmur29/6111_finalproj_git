`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Willie Zhu <zhuw@mit.edu>
// 
// Create Date: 12/06/2020 06:49:59 PM
// Design Name: 
// Module Name: texturemap_loader
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


module texturemap_loader(
    input logic clk,
    input logic reset,

    // controls
    input logic [7:0] texturemap_id,
    input logic should_load_texturemap,

    // interface to SD card
    // raddr is just the same as texturemap_id
    output logic graphics_req,
    output logic [31:0] graphics_req_addr,
    input graphics_req_ack,
    input graphics_req_we,
    input [7:0] graphics_req_dout,

    // interface to graphics engine
    output logic [16:0] texturemap_waddr,
    output logic [5:0] texturemap_din,
    output logic texturemap_we,

    output logic [9:0] texturemap_properties_waddr,
    output logic [7:0] texturemap_properties_din,
    output logic texturemap_properties_we,

    output logic texturemap_is_writing    // HIGH if the texturemap is currently being written to; do not render if HIGH
    );

    localparam STATE_IDLE = 2'b00;
    localparam STATE_WAIT = 2'b01;
    localparam STATE_COPY_TEXTUREMAP_PROPERTIES = 2'b10;
    localparam STATE_COPY_TEXTUREMAP = 2'b11;

    // first texturemap starts at 0x1000
    // TODO the size of TEXTUREMAP_PROPERTIES_OFFSET only allows us 248 unique texturemaps
    localparam TEXTUREMAP_OFFSET = 32'h20000;   // we start at this address for simplicity, so the texturemap_waddr is just the lowest 17 bits
    localparam TEXTUREMAP_PROPERTIES_OFFSET = 32'h1000;
    localparam TEXTUREMAP_SIZE = 512 * 256;     // height * width; each is 8 bytes. TODO change this to account for header info and stuff
    localparam BLOCK_SIZE = 512;

    logic [1:0] state, next_state;

    // This is kinda hacky, but we need to wait for BRAM sometimes
    logic [7:0] wait_counter;
    localparam WAIT_CYCLES = 8'd200;     // wait 16 cycles to clear SD pipeline

    assign texturemap_din = {graphics_req_dout[7:6], graphics_req_dout[4:3], graphics_req_dout[1:0]};
    assign texturemap_properties_din = graphics_req_dout;
    assign texturemap_we = graphics_req_we && (state == STATE_COPY_TEXTUREMAP);
    assign texturemap_properties_we = graphics_req_we && (state == STATE_COPY_TEXTUREMAP_PROPERTIES);

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            graphics_req <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (should_load_texturemap) begin
                        state <= STATE_WAIT;
                        wait_counter <= 200;
                        next_state <= STATE_COPY_TEXTUREMAP;
                        graphics_req_addr <= texturemap_id * TEXTUREMAP_SIZE + TEXTUREMAP_OFFSET;
                        texturemap_waddr <= 0;
                        texturemap_properties_waddr <= 0;

                        texturemap_is_writing <= 1'b1;
                        graphics_req <= 1'b1;
                    end else begin
                        texturemap_is_writing <= 1'b0;
                        graphics_req <= 1'b0;
                    end
                end

                STATE_COPY_TEXTUREMAP: begin
                    if (texturemap_waddr >= TEXTUREMAP_SIZE - 1) begin
                        // what the fuck?
                        // FIXME for some reason we need to delay by ~200 cycles, or we read from the SD card too early
                        // HACK I have no idea how accurate this number is
                        state <= STATE_WAIT;
                        next_state <= STATE_COPY_TEXTUREMAP_PROPERTIES;
                        wait_counter <= 200;
                        graphics_req_addr <= texturemap_id * BLOCK_SIZE + TEXTUREMAP_PROPERTIES_OFFSET;
                    end else begin
                        if (graphics_req_ack) begin
                            graphics_req_addr <= graphics_req_addr + BLOCK_SIZE;
                        end

                        if (graphics_req_we) begin
                            texturemap_waddr <= texturemap_waddr + 1;
                        end
                    end
                end

                STATE_COPY_TEXTUREMAP_PROPERTIES: begin
                    if (texturemap_properties_waddr >= BLOCK_SIZE - 1) begin
                        state <= STATE_WAIT;
                        next_state <= STATE_IDLE;
                        wait_counter <= WAIT_CYCLES;
                    end else if (graphics_req_we) begin
                        texturemap_properties_waddr <= texturemap_properties_waddr + 1;
                    end
                end

                STATE_WAIT: begin
                    if (wait_counter) begin
                        wait_counter <= wait_counter - 1;
                    end else begin
                        state <= next_state;
                    end
                end
            endcase
        end
    end

endmodule
