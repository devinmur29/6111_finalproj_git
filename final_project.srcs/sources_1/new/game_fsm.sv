`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/11/2020 01:37:41 PM
// Design Name: 
// Module Name: game_fsm
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


module game_fsm( input clk_25mhz, system_reset, done_shuffle, my_sync, other_sync, mg_fail, mg_success, expired,
 play_again, input[2:0] i_op, input[1:0] strike_count_op, input [5:0][3:0] minigame_order_out, input[1:0] multiplayer, 
output logic [2:0] i, output logic [1:0] strike_count, output logic timer_start, start_shuffle, multiplayer_reset, mg_start, 
lose_start, win_start, output logic[4:0] minigame);
    
    
    parameter HOME = 4'd0;
    parameter WIN = 4'd1;
    parameter LOSE = 4'd2;
    parameter SHUFFLE =4'd3;
    parameter MG_S=4'd4;
    parameter START = 4'd5;
    parameter SYNC = 4'd6;
    parameter MG_M = 4'd7;
    
    logic [3:0] game_state;
    
    
   
    
    always_ff @(posedge clk_25mhz) begin
        if(system_reset) begin
            game_state <= SHUFFLE;
            minigame <= 4'b0000;
            
        end else begin
            case(game_state)
                SHUFFLE :   begin start_shuffle <=1; game_state <= HOME; 
                                  i <= 3'b000;
                                  strike_count <= 2'b00;end
                HOME    :   begin  game_state <= (multiplayer!=2'b00 &done_shuffle)? multiplayer[1]?SYNC:  START : HOME;
                                    start_shuffle <= 0;
                                    if(multiplayer[1] & done_shuffle) multiplayer_reset <= 1;
                                    if(multiplayer==2'b01 & done_shuffle) begin timer_start <=1;end end//multiplayer/singleplayer stuff
                                    
                SYNC    :   begin   multiplayer_reset <= 0; game_state <= (my_sync & other_sync)?START:SYNC; 
                                    if(my_sync & other_sync) timer_start <= 1;end
                START   :   begin mg_start <=1; minigame <= minigame_order_out[i]; multiplayer_reset <=0; 
                                    game_state <=(mg_fail|mg_success)?START: multiplayer[1]?MG_M:MG_S; timer_start<=0; end
                
                MG_M      :   begin  mg_start <= 0;
                                   game_state <= (expired|i_op==6)?LOSE:(strike_count_op==2'b11)?WIN:(mg_fail)?((strike_count==2)?LOSE:START):(mg_success)?((i==3'd5)?WIN:START):MG_M;
                                   strike_count <= expired? 2'b11:mg_fail?strike_count+1:strike_count;
                                   if (mg_success) i<=i+1;
                                   if(expired| i_op ==6|(strike_count_op !=2'b11&mg_fail&strike_count==2)) lose_start <=1;
                                   else if(strike_count_op==2'b11|(mg_success&i==3'd5)) win_start <=1;   end
                MG_S      :   begin  mg_start <= 0;
                                   game_state <= (expired)?LOSE:(mg_fail)?((strike_count==2)?LOSE:START):(mg_success)?((i==3'd5)?WIN:START):MG_S;
                                   strike_count <= expired? 2'b11:mg_fail?strike_count+1:strike_count;
                                   if (mg_success) i<=i+1;
                                   if(expired|(mg_fail&strike_count==2)) lose_start <=1;
                                   else if(mg_success&i==3'd5) win_start <=1;   end
                LOSE    :   begin lose_start<=0; 
                                    minigame <= (play_again)?4'b0000: 4'b0111;
                                    game_state <= (play_again)?SHUFFLE:LOSE;
                                    //if(play_again) homescreen_start <=1;
                                   end
                WIN     :   begin win_start <= 0; 
                                   minigame <= (play_again)?4'b0000:4'b1000;
                                   game_state <= (play_again)?SHUFFLE:WIN; end
                                   //if(play_again) homescreen_start <=1;end
                
            endcase
         end
     end
endmodule
