`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Willie Zhu <zhuw@mit.edu>
// 
// Create Date: 12/07/2020 06:53:21 PM
// Design Name: 
// Module Name: minigame_morse
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


module minigame_morse(
    input clk,
    input reset,

    output logic play,
    output logic stop,
    output logic [4:0] sound_id,

    output logic should_render,
    output logic render_dirty,
    output logic [7:0] num_objects,
    output logic [7:0] new_object_waddr,
    output logic new_object_we,
    output logic [35:0] new_object_properties,
    input logic render_ack,

    output logic [7:0] texturemap_id,
    output logic should_load_texturemap,
    input logic texturemap_load_ack,

    input [3:0] random,
    input [3:0] sw,
    input btnc,

    output logic success,
    output logic failure
);

    // 16 possible answers
    logic [3:0] solution;
    logic led;

    localparam DOT = 2'b10;
    localparam DASH = 2'b11;

    logic [1:0] morse_next_character;
    logic [1:0] morse_character;
    logic [7:0] morse_current;
    logic [7:0] morse;
    logic [7:0] morse_prev;

    logic [7:0] word_next_character;
    logic [7:0] word_character;
    logic [63:0] word_current;
    logic [63:0] word;

    morse_code_lut morse_code_lut(
        .letter(word_next_character),
        .morse
    );

    // this is kind of a hack, but we need this to make the first character work
    morse_code_lut morse_code_lut_prev(
        .letter(word_character),
        .morse(morse_prev)
    );

    blk_mem_morse_words morse_words(
        .addra(solution),
        .clka(clk),
        .douta(word)
    );

    assign morse_character = morse_current[7:6];
    assign word_character = word_current[63:56];

    assign morse_next_character = morse_current[5:4];
    assign word_next_character = word_current[55:48];

    logic [2:0] state;
    localparam STATE_DOT_DASH_SPACE = 3'b100;
    localparam STATE_CHARACTER_SPACE = 3'b101;
    localparam STATE_WORD_SPACE = 3'b110;
    localparam STATE_DOT = 3'b010;
    localparam STATE_DASH = 3'b011;
    localparam STATE_IDLE = 3'b000;

    // GRAPHICS CODE
    // TODO add to this
    // {draw_module, draw_blinking_light}
    logic [1:0] to_draw;
    logic texturemap_loaded;    // have we loaded the texturemap yet?
    logic texturemap_ready;    // has the texturemap been fully loaded?

    localparam FIRST_BACKGROUND_TEXTUREMAP = 2;

    logic led_last;

    always_comb begin
        led = state == STATE_DOT || state == STATE_DASH;
    end

    always_ff @(posedge clk) begin
        led_last <= led;
    end

    logic [2:0] backgrounds_loaded;
    logic [1:0] background_state, background_state_last;

    always_ff @(posedge clk) begin
        background_state_last <= background_state;
    end

    localparam BACKGROUND_STATE_WAITING = 2'b00;
    localparam BACKGROUND_STATE_LOADING_TEXTUREMAP = 2'b01;
    localparam BACKGROUND_STATE_RENDERING = 2'b10;
    // we need to load the bg, then wait for an ack
    logic background_should_render;
    logic background_should_load_texturemap;

    logic texturemap_loaded;    // have we loaded the texturemap yet?
    logic texturemap_ready;    // has the texturemap been fully loaded?
    localparam TEXTUREMAP_ID = 1;

    // handle background state
    always_ff @(posedge clk) begin
        if (reset) begin
            backgrounds_loaded <= 3'd0;
            background_state <= BACKGROUND_STATE_WAITING;
        end else if (backgrounds_loaded < 4) begin
            // load backgrounds
            case (background_state)
                BACKGROUND_STATE_WAITING: begin
                    background_state <= BACKGROUND_STATE_LOADING_TEXTUREMAP;
                end

                BACKGROUND_STATE_LOADING_TEXTUREMAP: begin
                    if (texturemap_load_ack) begin
                        background_state <= BACKGROUND_STATE_RENDERING;
                    end
                end

                BACKGROUND_STATE_RENDERING: begin
                    if (render_ack) begin
                        backgrounds_loaded <= backgrounds_loaded + 1;
                        background_state <= BACKGROUND_STATE_LOADING_TEXTUREMAP;
                    end
                end
            endcase
        end
    end

    // load the right texturemap!
    always_ff @(posedge clk) begin
        if (should_load_texturemap) should_load_texturemap <= 0;    // should be a pulse

        if (reset) begin
            texturemap_loaded <= 1'b0;
            texturemap_ready <= 1'b0;

            should_load_texturemap <= 1'b0;
        end else if (backgrounds_loaded < 4) begin
            if (background_state == BACKGROUND_STATE_LOADING_TEXTUREMAP &&
                background_state != background_state_last) begin
                texturemap_id <= FIRST_BACKGROUND_TEXTUREMAP + backgrounds_loaded;
                should_load_texturemap <= 1'b1;
            end
        end else begin
            if (!texturemap_loaded) begin
                // TODO THIS SHOULD BE THE TEXTUREMAP YOU WANT
                texturemap_id <= TEXTUREMAP_ID;
                texturemap_loaded <= 1'b1;
                texturemap_ready <= 1'b0;

                should_load_texturemap <= 1'b1;
            end else if (texturemap_load_ack) begin
                texturemap_ready <= 1'b1;
            end
        end
    end

    // configuration stuff
//    assign render_dirty = 1'b0;
    assign render_dirty = 1'b1;
//    assign num_objects = 8'd2;

    // draw things!
    always_ff @(posedge clk) begin
        if (new_object_we) new_object_we <= 0;
        if (should_render) should_render <= 0;

        if (reset) begin
            to_draw <= 2'b11;
        end else if (backgrounds_loaded < 4) begin
            num_objects <= 1;

            if (background_state == BACKGROUND_STATE_RENDERING &&
                background_state != background_state_last) begin
                new_object_we <= 1;
                new_object_waddr <= 0;
                new_object_properties <= {backgrounds_loaded[0] ? 10'd320 : 10'd0, backgrounds_loaded[1] ? 10'd240 : 10'd0, 10'h2FF, 4'h00, backgrounds_loaded[1:0]};
                should_render <= 1'b1;
            end
        end else begin
            num_objects <= 2;

            if (led_last != led) begin
                to_draw <= to_draw | 2'b01;
            end

            if (to_draw != 0 && texturemap_ready) begin
                new_object_we <= 1;
                should_render <= 1'b1;

                casex (to_draw)
                    2'b1X: begin
                        new_object_waddr <= 0;
                        new_object_properties <= {10'd128, 10'd162, 10'h2FF, 6'h00};
                        to_draw <= to_draw ^ 2'b10;
                    end

                    2'b01: begin
                        new_object_waddr <= 1;
                        new_object_properties <= {10'd478, 10'd176, led ? 10'h2FF : 10'h1FF, 6'h01};
                        to_draw <= to_draw ^ 2'b01;
                    end
                endcase
            end
        end
    end

    // are we guaranteed to be reset every time?
    always_ff @(posedge clk) begin
        if (reset) begin
            success <= 1'b0;
            failure <= 1'b0;
        end else begin
            if (btnc && sw == solution) begin
                success <= 1'b1;
            end else if (btnc) begin
                failure <= 1'b1;
            end
        end
    end

    // timing values, for counter
    // one DIT is equal to the length of one dot
    localparam DIT = 32'd6_000_000;
    localparam DOT_DASH_SPACE_TIMING = 1;
    localparam CHARACTER_SPACE_TIMING = 3;
    localparam WORD_SPACE_TIMING = 7;
    localparam DOT_TIMING = 1;
    localparam DASH_TIMING = 3;

    // FIXME the morse code isn't quite right
    logic [31:0] counter;
    always_ff @(posedge clk) begin
        if (reset) begin
            counter <= 0;
            state <= STATE_IDLE;
            solution <= random;
        end else if (state == STATE_IDLE) begin
            counter <= 1;
            state <= STATE_WORD_SPACE;
            word_current <= word;
        end else if (counter == 0) begin
            casex (state)
                3'b1XX: begin
                    if (state == STATE_WORD_SPACE) begin
                        morse_current <= morse_prev;
                        counter <= 1;
                        state <= STATE_CHARACTER_SPACE;
                    end else begin
                        counter <= (morse_character == DOT ? DOT_TIMING : DASH_TIMING) * DIT;
                        state   <= (morse_character == DOT ? STATE_DOT : STATE_DASH);
                    end
                end

                // we can either be at the end of a morse dit, a character, or a word
                3'b01X: begin
                    if (morse_next_character) begin
                        state <= STATE_DOT_DASH_SPACE;
                        counter <= DOT_DASH_SPACE_TIMING * DIT;

                        morse_current <= {morse_current[5:0], 2'd0};
                    end else if (word_next_character) begin
                        state <= STATE_CHARACTER_SPACE;
                        counter <= CHARACTER_SPACE_TIMING * DIT;

                        word_current <= {word_current[55:0], 8'd0};
                        morse_current <= morse;
                    end else begin
                        state <= STATE_WORD_SPACE;
                        counter <= WORD_SPACE_TIMING * DIT;

                        word_current <= word;
                    end
                end
            endcase
        end else begin
            counter <= counter - 1;
        end
    end

    assign play = 1'b1;
    assign stop = 1'b0;
    assign sound_id = 5'd4;
endmodule

// morse code LUT; uses ASCII values, so we could potentially use this in conjunction with a font renderer
module morse_code_lut(
    input [7:0] letter,

    // encoded in 2-bit increments, where b11 = dash, b10 = dot, and anything else is end of character
    output logic [7:0] morse
);

    always_comb begin
        casex (letter)
            8'b01X00001: morse = 8'b10_11_00_00;
            8'b01X00010: morse = 8'b11_10_10_10;
            8'b01X00011: morse = 8'b11_10_11_10;
            8'b01X00100: morse = 8'b11_10_10_00;
            8'b01X00101: morse = 8'b10_00_00_00;
            8'b01X00110: morse = 8'b10_10_11_10;
            8'b01X00111: morse = 8'b11_11_10_00;
            8'b01X01000: morse = 8'b10_10_10_10;
            8'b01X01001: morse = 8'b10_10_00_00;
            8'b01X01010: morse = 8'b10_11_11_11;
            8'b01X01011: morse = 8'b11_10_11_00;
            8'b01X01100: morse = 8'b10_11_10_10;
            8'b01X01101: morse = 8'b11_11_00_00;
            8'b01X01110: morse = 8'b11_10_00_00;
            8'b01X01111: morse = 8'b11_11_11_00;
            8'b01X10000: morse = 8'b10_11_11_10;
            8'b01X10001: morse = 8'b11_11_10_11;
            8'b01X10010: morse = 8'b10_11_10_00;
            8'b01X10011: morse = 8'b10_10_10_00;
            8'b01X10100: morse = 8'b11_00_00_00;
            8'b01X10101: morse = 8'b10_10_11_00;
            8'b01X10110: morse = 8'b10_10_10_11;
            8'b01X10111: morse = 8'b10_11_11_00;
            8'b01X11000: morse = 8'b11_10_10_11;
            8'b01X11001: morse = 8'b11_10_11_11;
            8'b01X11010: morse = 8'b11_11_10_10;
        endcase
    end
endmodule
