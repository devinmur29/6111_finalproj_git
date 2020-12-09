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

module sound_engine(
    input clk,
    input reset,

    input play,
    input stop,
    input [4:0] sound_id,

    output logic [5:0] audio_header_raddr,
    input logic [31:0] audio_header_dout,

    output logic audio_req,
    output logic [31:0] audio_req_addr,
    input audio_req_ack,
    input audio_req_we,
    input [7:0] audio_req_dout,

    output reg audio_out  // PWM output. Connect this to ampPWM.
    );

    parameter COUNTER_PER_AUDIO_BYTE = 567;
    logic [15:0] counter;
    logic [31:0] audio_req_end_addr;     // when audio_req_addr equals this, we've reached the end of the sound

    logic [7:0] fifo_dout;
    logic fifo_rd_en;
    logic fifo_should_fill;     // once FIFO reaches empty threshold (about half), refill it
    logic [11:0] fifo_count;

    logic sd_byte_available_last;

    fifo_generator_0 fifo(.din(audio_req_dout), .wr_en(audio_req_we),
                                 .dout(fifo_dout), .rd_en(fifo_rd_en),
                                 .clk, .rst(reset), .prog_empty(fifo_should_fill));

    localparam STATE_IDLE = 2'b00;
    localparam STATE_FETCH_ADDRESS = 2'b01;
    localparam STATE_FETCH_LENGTH = 2'b10;
    localparam STATE_PLAYING = 2'b11;

    logic [1:0] state;

    // This is kinda hacky, but we need to wait for BRAM sometimes
    logic [3:0] wait_counter;
    localparam WAIT_CYCLES = 4'd8;     // wait 4 cycles for BRAM to settle

    always_ff @(posedge clk) begin
        if (reset || stop) begin
            state <= STATE_IDLE;
            audio_req <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (play) begin
                        state <= STATE_FETCH_ADDRESS;
                        audio_header_raddr <= sound_id * 2;
                        wait_counter <= WAIT_CYCLES;
                    end
                end

                STATE_FETCH_ADDRESS: begin
                    if (wait_counter == 0) begin
                        audio_req_addr <= audio_header_dout;
                        audio_header_raddr <= audio_header_raddr + 1;
                        state <= STATE_FETCH_LENGTH;
                        wait_counter <= WAIT_CYCLES;
                    end else begin
                        wait_counter <= wait_counter - 1;
                    end
                end

                STATE_FETCH_LENGTH: begin
                    if (wait_counter == 0) begin
                        audio_req_end_addr <= audio_header_dout;
                        state <= STATE_PLAYING;
                    end else begin
                        wait_counter <= wait_counter - 1;
                    end
                end

                STATE_PLAYING: begin
                    if (audio_req_addr >= audio_req_end_addr) begin
                        state <= STATE_IDLE;
                        audio_req <= 1'b0;
                    end else begin
                        audio_req <= fifo_should_fill;

                        if (audio_req_ack) begin
                            audio_req_addr <= audio_req_addr + 512;
                        end
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (fifo_rd_en) fifo_rd_en <= 0;

        if (reset) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
            if (counter >= COUNTER_PER_AUDIO_BYTE) begin
                counter <= 0;
                fifo_rd_en <= 1;
            end
        end
    end

    logic pwm_out;

    audio_PWM(.clk, .reset, .music_data(fifo_dout), .PWM_out(pwm_out));

    assign audio_out = pwm_out && (state == STATE_PLAYING);
endmodule

// Audio PWM module.

module audio_PWM(
    input clk,    // 100MHz clock.
    input reset,  // Reset assertion.
    input [7:0] music_data, // 8-bit music sample
    output reg PWM_out  // PWM output. Connect this to ampPWM.
    );

    reg [7:0] pwm_counter = 8'd0;           // counts up to 255 clock cycles per pwm period

    always @(posedge clk) begin
        if(reset) begin
            pwm_counter <= 0;
            PWM_out <= 0;
        end
        else begin
            pwm_counter <= pwm_counter + 1;
            
            if(pwm_counter >= music_data) PWM_out <= 0;
            else PWM_out <= 1;
        end
    end
endmodule

