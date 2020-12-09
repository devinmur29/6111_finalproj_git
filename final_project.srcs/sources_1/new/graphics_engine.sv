`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Willie Zhu <zhuw@mit.edu>
// 
// Create Date: 12/07/2020 03:04:47 PM
// Design Name: 
// Module Name: graphics_engine
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

module graphics_engine(
    input clk,
    input reset,

    // TODO should we have hsync, vsync as inputs?
    // only start on a blanking period?

    input [10:0] hcount, // horizontal index of current pixel
    input [9:0]  vcount, // vertical index of current pixel

    output logic [11:0] pixel_out,

    input logic should_render,
    input logic render_dirty,
    input logic [7:0] num_objects,
    input logic [7:0] new_object_waddr,
    input logic new_object_we,
    // TODO: add a bitmask for writing? if it's zero, keep the old; otherwise keep the new.
    // We can do this by ANDING together (and ANDING the previous with the INVERSE of the bitmask)
    // TODO add a way to only clear **part** of the framebuffer?
    input logic [35:0] new_object_properties,
    output logic render_ack,

    // actually loads in texturemaps
    input logic [7:0] texturemap_id,
    input logic should_load_texturemap,
    output logic texturemap_load_ack,

    output logic graphics_req,
    output logic [31:0] graphics_req_addr,
    input graphics_req_ack,
    input graphics_req_we,
    input [7:0] graphics_req_dout
);

    parameter FRAMEBUFFER_WIDTH = 640;
    parameter FRAMEBUFFER_HEIGHT = 480;

    logic [9:0] framebuffer_wx;
    logic [8:0] framebuffer_wy;
    logic [18:0] framebuffer_waddr;
    assign framebuffer_waddr = framebuffer_wy * FRAMEBUFFER_WIDTH + framebuffer_wx;
    logic framebuffer_we;
    logic [5:0] framebuffer_din;

    logic [5:0] framebuffer_dout;

    // TODO add a bit that turns framebuffer output off? so we can wait until it's fully rendered
    blk_mem_framebuffer framebuffer(
        .addra(framebuffer_waddr),
        .clka(clk),
        .dina(framebuffer_din),
        .wea(framebuffer_we),
        .clkb(clk),
        .addrb(hcount + vcount * FRAMEBUFFER_WIDTH),
        .doutb(framebuffer_dout)
    );

    logic [7:0] object_index;   // currently rendering object

    // object_x, object_y: location relative to framebuffer
    // object_flags: RESERVED
    // object_id: index into texturemap properties
    // new_object_properties is an input to the engine
    logic [35:0] object_properties;
    logic [9:0] object_x;
    logic [9:0] object_y;
    // flags[7] controls visibility
    logic [9:0] object_flags;
    logic [5:0] object_id;

    assign object_x = object_properties[35:26];
    assign object_y = object_properties[25:16];
    assign object_flags = object_properties[15:6];
    assign object_id = object_properties[5:0];

    blk_mem_object_memory object_memory(
        .addra(new_object_waddr),
        .clka(clk),
        .dina(new_object_properties),
        .wea(new_object_we),
        .clkb(clk),
        .addrb(object_index),
        .doutb(object_properties)
    );

    logic [15:0] object_texturemap_x;
    logic [15:0] object_texturemap_y;
    logic [15:0] object_width;
    logic [15:0] object_height;

    localparam TEXTUREMAP_WIDTH = 512;
    localparam TEXTUREMAP_HEIGHT = 256;

    // always relative to the top left of the texture
    logic [9:0] texturemap_x;
    logic [8:0] texturemap_y;
    logic [16:0] texturemap_raddr;
    assign texturemap_raddr = (object_texturemap_y + texturemap_y) * TEXTUREMAP_WIDTH + (object_texturemap_x + texturemap_x);
    logic [5:0] texturemap_dout;

    // TODO we should also make a signal that is HIGH when we're done rendering
    // we would also read the colormap from the SD card
    logic [16:0] texturemap_waddr;
    logic [5:0] texturemap_din;
    logic texturemap_is_writing;    // HIGH if the texturemap is currently being written to; do not render if HIGH
    logic texturemap_we;

    logic texturemap_is_writing_last;
    always_ff @(posedge clk) begin
        texturemap_is_writing_last <= texturemap_is_writing;
    end

    assign texturemap_load_ack = texturemap_is_writing_last && !texturemap_is_writing;

    blk_mem_texturemap texturemap(
        .addra(texturemap_waddr),     // turn writing off; connect to SD card
        .clka(clk),
        .dina(texturemap_din),
        .wea(texturemap_we),
        .clkb(clk),
        .addrb(texturemap_raddr),
        .doutb(texturemap_dout)
    );

    logic [9:0] texturemap_properties_waddr;
    logic [7:0] texturemap_properties_din;
    logic texturemap_properties_we;
    logic [63:0] texturemap_properties;

    blk_mem_texturemap_properties texturemap_properties_mem(
        .addra(texturemap_properties_waddr),     // turn writing off; connect to SD card
        .clka(clk),
        .dina(texturemap_properties_din),
        .wea(texturemap_properties_we),
        .clkb(clk),
        .addrb(object_id),
        .doutb(texturemap_properties)
    );

    assign object_texturemap_x = texturemap_properties[15:0];
    assign object_texturemap_y = texturemap_properties[31:16];
    assign object_width = texturemap_properties[47:32];
    assign object_height = texturemap_properties[63:48];

    texturemap_loader loader(
        .clk,
        .reset,

        .texturemap_id,
        .should_load_texturemap,

        .graphics_req,
        .graphics_req_addr,
        .graphics_req_ack,
        .graphics_req_we,
        .graphics_req_dout,

        .texturemap_waddr,
        .texturemap_din,
        .texturemap_is_writing,
        .texturemap_we,

        .texturemap_properties_waddr,
        .texturemap_properties_din,
        .texturemap_properties_we
    );

    localparam STATE_IDLE = 3'b000;
    localparam STATE_RENDER_START = 3'b001;
    localparam STATE_PREPARE_OBJECT_RENDER = 3'b010;
    localparam STATE_RENDER = 3'b011;
    localparam STATE_CLEAR_FRAMEBUFFER_START = 3'b100;
    localparam STATE_CLEAR_FRAMEBUFFER = 3'b101;
    localparam STATE_WAIT = 3'b111;  // waiting for a memory read
    logic [2:0] state, next_state;  // next-state is used when we must enter a waiting state

    logic [7:0] wait_counter;

    // render to framebuffer
    always_ff @(posedge clk) begin
        if (render_ack) render_ack <= 0;

        if (reset) begin
            state <= STATE_IDLE;
            framebuffer_wx <= 0;
            framebuffer_wy <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    framebuffer_we <= 0;

                    if (should_render) begin
                        if (render_dirty) begin
                            state <= STATE_RENDER_START;
                        end else begin
                            state <= STATE_CLEAR_FRAMEBUFFER_START;
                        end
                    end
                end

                STATE_RENDER_START: begin
                    framebuffer_we <= 0;

                    object_index <= 0;

                    // TODO this should be done every time we access this
                    wait_counter <= 4'd8;
                    state <= STATE_WAIT;
                    next_state <= STATE_PREPARE_OBJECT_RENDER;
                end

                STATE_PREPARE_OBJECT_RENDER: begin
                    if (object_index >= num_objects) begin
                        state <= STATE_IDLE;
                        render_ack <= 1;
                    end else if (object_flags[9]) begin
                        texturemap_x <= 0;
                        texturemap_y <= 0;

                        framebuffer_wx <= object_x;
                        framebuffer_wy <= object_y;

                        state <= STATE_RENDER;
                    end else begin
                        object_index <= object_index + 1;

                        wait_counter <= 4'd8;
                        state <= STATE_WAIT;
                        next_state <= STATE_PREPARE_OBJECT_RENDER;
                    end
                end

                STATE_RENDER: begin
                    framebuffer_we <= 1;
                    framebuffer_din <= texturemap_dout;
                    // If we go off the bottom-right of the object (i.e. we're done)
                    // TODO off by 1 error?
                    if (texturemap_x >= object_width - 1|| framebuffer_wx >= FRAMEBUFFER_WIDTH - 1) begin
                        if (texturemap_y >= object_height - 1 || framebuffer_wy >= FRAMEBUFFER_HEIGHT - 1) begin
                            wait_counter <= 4'd8;
                            state <= STATE_WAIT;
                            next_state <= STATE_PREPARE_OBJECT_RENDER;
                            object_index <= object_index + 1;
                        end else begin
                            texturemap_x <= 0;
                            framebuffer_wx <= object_x;

                            texturemap_y <= texturemap_y + 1;
                            framebuffer_wy <= framebuffer_wy + 1;
                        end
                    end else begin
                        texturemap_x <= texturemap_x + 1;
                        framebuffer_wx <= framebuffer_wx + 1;
                    end
                end

                STATE_CLEAR_FRAMEBUFFER_START: begin
                    framebuffer_wx <= 0;
                    framebuffer_wy <= 0;
                    framebuffer_din <= 0;
                    framebuffer_we <= 1;
                    state <= STATE_CLEAR_FRAMEBUFFER;
                end

                STATE_CLEAR_FRAMEBUFFER: begin
                    if (framebuffer_wx >= FRAMEBUFFER_WIDTH - 1) begin
                        if (framebuffer_wy >= FRAMEBUFFER_HEIGHT - 1) begin
                            state <= STATE_RENDER_START;
                        end else begin
                            framebuffer_wx <= 0;
                            framebuffer_wy <= framebuffer_wy + 1;
                        end
                    end else begin
                        framebuffer_wx <= framebuffer_wx + 1;
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

    // TODO use color mapping; this should pull from the local colormap
    // Mask out the first pixel on each line, since it's usually buggy (do we need to do this for two pixels?)
    always_comb begin
        if (hcount == 0) begin
            pixel_out = 0;
        end else begin
            pixel_out = {framebuffer_dout[5:4], 2'b0, framebuffer_dout[3:2], 2'b0, framebuffer_dout[1:0], 2'b00};
        end
    end
endmodule
