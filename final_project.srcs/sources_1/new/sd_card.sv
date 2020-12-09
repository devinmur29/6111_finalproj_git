`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Willie Zhu <zhuw@mit.edu>
// 
// Create Date: 12/04/2020 01:22:01 AM
// Design Name: 
// Module Name: sd_card_fsm
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

// This module is an abstraction on top of the SD card controller.
// It presents an FSM that streams out blocks of audio/graphics data to the appropriate BRAM.

module sd_card_fsm(
    input clk_in,
    input reset_in,

    input miso,
    output logic mosi,
    output logic cs,
    output logic sclk,

    input reg [5:0] graphics_header_raddr,
    input reg [5:0] audio_header_raddr,
    
    output logic [31:0] graphics_header_dout,
    output logic [31:0] audio_header_dout,

    input audio_req,               // are we requesting an audio block?
    input [31:0] audio_req_addr,   // audio request address; MUST BE MULTIPLE OF 512
    output logic audio_req_ack,          // acks on request served
    output logic audio_req_we,           // write enable
    output logic [7:0] audio_req_dout,

    input graphics_req,               // are we requesting a graphics block?
    input [31:0] graphics_req_addr,   // graphics request address; MUST BE MULTIPLE OF 512
    output logic graphics_req_ack,          // acks on request served
    output logic graphics_req_we,           // write enable
    output logic [7:0] graphics_req_dout
);

    // sd_controller inputs
    logic rd;                   // read enable
    logic wr;                   // write enable
    logic [7:0] din;            // data to sd card
    logic [31:0] address;       // starting address for read/write operation

    // sd_controller outputs
    logic ready;                // high when ready for new read/write operation
    logic [7:0] dout;           // data from sd card
    logic byte_available;       // high when byte available for read
    logic ready_for_next_byte;  // high when ready for new byte to be written

    sd_controller sd(.reset(reset_in), .clk(clk_in), .cs, .mosi,
                     .miso, .sclk, .ready, .address,
                     .rd, .dout, .byte_available,
                     .wr, .din, .ready_for_next_byte);

    logic byte_available_last;

    always_ff @(posedge clk_in) begin
        byte_available_last <= byte_available;
    end

    // write address for initial header fill
    // TODO we use blk_mem_audio_header, but we might want to use something else
    // TODO we don't need graphics_header!!!!!
    logic [15:0]  init_waddr;
    logic        graphics_header_we;
    blk_mem_audio_header graphics_header(.addra(init_waddr[7:0]), .clka(clk_in), .dina(dout), .wea(graphics_header_we && byte_available),
                                  .addrb(graphics_header_raddr), .clkb(clk_in), .doutb(graphics_header_dout));

    logic        audio_header_we;
    blk_mem_audio_header audio_header(.addra(init_waddr[7:0]), .clka(clk_in), .dina(dout), .wea(audio_header_we && byte_available),
                               .addrb(audio_header_raddr), .clkb(clk_in), .doutb(audio_header_dout));

    localparam STATE_INIT_GRAPHICS = 3'b000;
    localparam STATE_INIT_AUDIO = 3'b001;
    localparam STATE_IDLE = 3'b010;
    localparam STATE_BLOCK_READ_AUDIO = 3'b100;
    localparam STATE_BLOCK_READ_GRAPHICS = 3'b101;

    logic [2:0] state;
    logic [15:0] req_bytes_read;

    always_ff @(posedge clk_in) begin
        if (rd) rd <= 0;    // must use single pulse
        if (wr) wr <= 0;

        if (reset_in) begin
            state <= STATE_INIT_GRAPHICS;
            rd <= 1'b0;
            wr <= 1'b0;
            din <= 8'd0;
            address <= 32'd0;

            init_waddr <= 16'd0;

            graphics_header_we <= 1'b0;
            audio_header_we <= 1'b0;

            audio_req_we <= 1'b0;
            audio_req_ack <= 1'b0;

            graphics_req_we <= 1'b0;
            graphics_req_ack <= 1'b0;
        end else begin
            case (state)
                STATE_INIT_GRAPHICS: begin
                    if (ready) begin
                        rd <= 1'b1;
                        graphics_header_we <= 1'b1;
                    end else if (byte_available && !byte_available_last) begin
                        init_waddr <= init_waddr + 1;

                        if (init_waddr >= 255) begin
                            state <= STATE_INIT_AUDIO;
                            graphics_header_we <= 1'b0;
                            audio_header_we <= 1'b1;
                        end
                    end
                end

                STATE_INIT_AUDIO: begin
                    if (init_waddr >= 512) begin
                        state <= STATE_IDLE;
                        audio_header_we <= 1'b0;
                    end else if (byte_available && !byte_available_last) begin
                        init_waddr <= init_waddr + 1;
                    end
                end

                // Note that we should never write to the graphics/audio headers after this initial write.
                // TODO add in functionality for block write; set aside the third (block[2] in zero-index) right after audio
                // header for the saved hiscores
                STATE_IDLE: begin
                    audio_req_we <= 1'b0;
                    audio_req_ack <= 1'b0;

                    graphics_req_we <= 1'b0;
                    graphics_req_ack <= 1'b0;
                    req_bytes_read <= 0;

                    if (audio_req) begin
                        state <= STATE_BLOCK_READ_AUDIO;

                        address <= audio_req_addr;
                    end else if (graphics_req) begin
                        state <= STATE_BLOCK_READ_GRAPHICS;

                        address <= graphics_req_addr;
                    end
                end

                STATE_BLOCK_READ_AUDIO: begin
                    if (audio_req_we) audio_req_we <= 1'b0;

                    if (req_bytes_read >= 512) begin
                        state <= STATE_IDLE;
                        audio_req_ack <= 1'b1;
                    end else if (ready) begin
                        rd <= 1;
                    end else if (byte_available && !byte_available_last) begin
                        audio_req_dout <= dout;
                        audio_req_we <= 1'b1;
                        req_bytes_read <= req_bytes_read + 1;
                    end
                end

                STATE_BLOCK_READ_GRAPHICS: begin
                    if (graphics_req_we) graphics_req_we <= 1'b0;

                    if (req_bytes_read >= 512) begin
                        state <= STATE_IDLE;
                        graphics_req_ack <= 1'b1;
                    end else if (ready) begin
                        rd <= 1;
                    end else if (byte_available && !byte_available_last) begin
                        graphics_req_dout <= dout;
                        graphics_req_we <= 1'b1;
                        req_bytes_read <= req_bytes_read + 1;
                    end
                end
            endcase
        end
    end
endmodule
