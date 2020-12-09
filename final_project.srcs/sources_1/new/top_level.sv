`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/10/2020 08:25:02 PM
// Design Name: 
// Module Name: top_level
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


module top_level( input clk_100mhz,
                  input[15:0] sw,
                  input btnc, btnu, btnl, btnr, btnd,
                  ////mic inputs
                  input vauxp3,
                  input vauxn3,
                  input vn_in,
                  input vp_in, 
                  
                  input serial_rx,
                  output serial_tx,
                  output logic[3:0] vga_r,
                  output logic[3:0] vga_b,
                  output logic[3:0] vga_g,
                  output logic vga_hs,
                  output logic vga_vs,
                  output logic led16_b, led16_g, led16_r,
                  output logic led17_b, led17_g, led17_r,
                  output logic [15:0] led,
                  output logic ca, cb, cc, cd, ce, cf, cg, dp,  // segments a-g, dp
                  output logic[7:0] an,    // Display location 0-8
                  inout tmp_scl,
                  inout tmp_sda,

                  input acl_miso,
                  output acl_mosi,
                  output acl_sclk,
                  output acl_csn,

                  inout [3:0] sd_dat,

                  output logic sd_reset,
                  output logic sd_sck,
                  output logic sd_cmd,

                  output logic aud_pwm,
                  output logic aud_sd
    );

    assign sd_dat[2:1] = 2'b11;
    assign sd_reset = 0;

    logic system_reset;
    assign system_reset = sw[15];

    parameter ONE_HZ_PERIOD = 25_000_000;
    parameter DEBOUNCE_COUNT = 1_000_000;
    
    //SCENE AND MINIGAME STATES
    parameter HOME = 4'd0;
    parameter WIN = 4'd1;
    parameter LOSE = 4'd2;
    parameter SHUFFLE =4'd3;
    parameter MG_S=4'd4;
    parameter START = 4'd5;
    parameter SYNC = 4'd6;
    parameter MG_M = 4'd7;
     
    logic timer_start, counting, expired, one_hz_enable; //Game timer signals
    logic mg_start, win_start, lose_start; //start signals for the minigame, win, and lose screens
    logic mg_fail1, mg_fail2, mg_fail3, mg_fail4, mg_fail5, mg_fail6;
    logic mg_success1, mg_success2, mg_success3, mg_success4, mg_success5, mg_success6;
    logic mg_fail, mg_success; //Minigame start, fail, success, signals
    logic start_shuffle, done_shuffle; //signal to control start of shuffler, and to know when the shuffler is done
    logic [3:0] game_state;
    logic [11:0] count, tens, ones;
	logic [3:0] minutes;
	logic [10:0] hcount;    // pixel on current line
    logic [9:0] vcount;     // line number
    logic hsync, vsync;
    logic [11:0] pixel;
    logic [11:0] pixel_out1, pixel_out2, pixel_out3, pixel_out4, pixel_out5, pixel_out6;
    logic [11:0] pixel_out_fpga, pixel_out_fpgaop, pixel_out_win, pixel_out_lose, pixel_out_home, pixel_out_sync; //pixel_out minigame_1
    logic [11:0] rgb;
    logic [4:0] minigame; //which minigame is being played/displayed
    logic up, down, left, right, center;
    logic [5:0][3:0] minigame_order_in ; //6 array of 4 bits each.
    logic [5:0][3:0] minigame_order_out;
    logic [1:0] multiplayer; //is the game in multiplayer mode or single mode
    logic[2:0] i;//index for minigames
    logic[2:0] i_op; //opponents' index for minigames
    logic[1:0] strike_count; //your strikes
    logic[1:0] strike_count_op; //opponents' strikes
    logic btnc_op; //other player's sync button
    logic play_again; //output of win/lose modules
    logic play_sound; //play a sound
    logic stop_sound; //stop a sound
    logic [4:0] sound_id; //sound to be played or stopped
    
 /////////////////////////////MICROPHONE WILL BE INCORPORATED BEFORE CHECKOFF///////////////////////////////////////////////////////////
    
    ///////////////////MIC AND FFT VARIABLES//////////////////////
    parameter SAMPLE_COUNT = 4164; //2082;//gets approximately (will generate audio at approx 21 kHz sample rate.
    
    logic [15:0] sample_counter;
    logic [11:0] adc_data;
    logic [11:0] sampled_adc_data;
    logic sample_trigger;
    logic adc_ready;
    logic enable;
    logic [7:0] recorder_data;             
    logic [7:0] vol_out;
    logic pwm_val; //pwm signal (HI/LO)
    logic [15:0] scaled_adc_data;
    logic [15:0] scaled_signed_adc_data;
    logic [15:0] fft_data;
    logic       fft_ready;
    logic       fft_valid;
    logic       fft_last;
    logic [9:0] fft_data_counter;
    
    logic fft_out_ready;
    logic fft_out_valid;
    logic fft_out_last;
    logic [31:0] fft_out_data;
    
    logic sqsum_valid;
    logic sqsum_last;
    logic sqsum_ready;
    logic [31:0] sqsum_data;
    
    logic fifo_valid;
    logic fifo_last;
    logic fifo_ready;
    logic [31:0] fifo_data;
    
    logic [23:0] sqrt_data;
    logic sqrt_valid;
    logic sqrt_last;
    
    logic pixel_clk;
    ///////////////////////////////////////////////////////////////////////
    
    assign sample_trigger = (sample_counter == SAMPLE_COUNT);

    always_ff @(posedge clk_100mhz)begin
        if (sample_counter == SAMPLE_COUNT)begin
            sample_counter <= 16'b0;
        end else begin
            sample_counter <= sample_counter + 16'b1;
        end
        if (sample_trigger) begin
            scaled_adc_data <= 16*adc_data;
            scaled_signed_adc_data <= {~scaled_adc_data[15],scaled_adc_data[14:0]};
            sampled_adc_data <= {~adc_data[11],adc_data[10:0]}; //convert to signed. incoming data is offset binary
            if (fft_ready)begin
                fft_data_counter <= fft_data_counter +1;
                fft_last <= fft_data_counter==1023;
                fft_valid <= 1'b1;
                fft_data <= {~scaled_adc_data[15],scaled_adc_data[14:0]}; //set the FFT DATA here!
            end
            //https://en.wikipedia.org/wiki/Offset_binary
        end else begin
            fft_data <= 0;
            fft_last <= 0;
            fft_valid <= 0;
        end
    end

    //ADC uncomment when activating!
    xadc_wiz_0 my_adc ( .dclk_in(clk_100mhz), .daddr_in(8'h13), //read from 0x13 for a
                        .vauxn3(vauxn3),.vauxp3(vauxp3),
                        .vp_in(1),.vn_in(1),
                        .di_in(16'b0),
                        .do_out(adc_data),.drdy_out(adc_ready),
                        .den_in(1), .dwe_in(0));
 
 
    
    
//    FFT module:
//    CONFIGURATION:
//    1 channel
//    transform length: 1024
//    target clock frequency: 100 MHz
//    target Data throughput: 50 Msps
//    Auto-select architecture
//    IMPLEMENTATION:
//    Fixed Point, Scaled, Truncation
//    MAKE SURE TO SET NATURAL ORDER FOR OUTPUT ORDERING
//    Input Data Width, Phase Factor Width: Both 16 bits
//    Result uses 12 DSP48 Slices and 6 Block RAMs (under Impl Details)
    xfft_0 my_fft (.aclk(clk_100mhz), .s_axis_data_tdata(fft_data), 
                    .s_axis_data_tvalid(fft_valid),
                    .s_axis_data_tlast(fft_last), .s_axis_data_tready(fft_ready),
                    .s_axis_config_tdata(0), 
                     .s_axis_config_tvalid(0),
                     .s_axis_config_tready(),
                    .m_axis_data_tdata(fft_out_data), .m_axis_data_tvalid(fft_out_valid),
                    .m_axis_data_tlast(fft_out_last), .m_axis_data_tready(fft_out_ready));
    
//    for debugging commented out, make this whatever size,detail you want:
//    ila_0 myila (.clk(clk_100mhz), .probe0(fifo_data), .probe1(sqrt_data), .probe2(sqsum_data), .probe3(fft_out_data));
    
//    custom module (was written with a Vivado AXI-Streaming Wizard so format looks inhuman
//    this is because it was a template I customized.
    square_and_sum_v1_0 mysq(.s00_axis_aclk(clk_100mhz), .s00_axis_aresetn(1'b1),
                            .s00_axis_tready(fft_out_ready),
                            .s00_axis_tdata(fft_out_data),.s00_axis_tlast(fft_out_last),
                            .s00_axis_tvalid(fft_out_valid),.m00_axis_aclk(clk_100mhz),
                            .m00_axis_aresetn(1'b1),. m00_axis_tvalid(sqsum_valid),
                            .m00_axis_tdata(sqsum_data),.m00_axis_tlast(sqsum_last),
                            .m00_axis_tready(sqsum_ready));
    
    //Didn't really need this fifo but put it in for because I felt like it and for practice:
    //This is an AXI4-Stream Data FIFO
    //FIFO Depth: 1024
    //No packet mode, no async clock, 2 sycn stages for clock domain crossing
    //no aclken conversion
    //TDATA Width: 4 bytes
    //Enable TSTRB: No...isn't needed
    //Enable TKEEP: No...isn't needed
    //Enable TLAST: Yes...use this for frame alignment
    //TID Width, TDEST Width, and TUSER width: all 0
    axis_data_fifo_0 myfifo (.s_axis_aclk(clk_100mhz), .s_axis_aresetn(1'b1),
                             .s_axis_tvalid(sqsum_valid), .s_axis_tready(sqsum_ready),
                             .s_axis_tdata(sqsum_data), .s_axis_tlast(sqsum_last),
                             .m_axis_tvalid(fifo_valid), .m_axis_tdata(fifo_data),
                             .m_axis_tready(fifo_ready), .m_axis_tlast(fifo_last));    
//    AXI4-STREAMING Square Root Calculator:
//    CONFIGUATION OPTIONS:
//     Functional Selection: Square Root
//    Architec Config: Parallel (can't change anyways)
//    Pipelining: Max
//    Data Format: UnsignedInteger
//    Phase Format: Radians, the way God intended.
//    Input Width: 32
//    Output Width: 17
//    Round Mode: Truncate
//    0 on the others, and no scale compensation
//    AXI4 STREAM OPTIONS:
//    Has TLAST!!! need to propagate that
//    Don't need a TUSER
//    Flow Control: Blocking
    //optimize Goal: Performance
    //leave other things unchecked.
    cordic_0 mysqrt (.aclk(clk_100mhz), .s_axis_cartesian_tdata(fifo_data),
                     .s_axis_cartesian_tvalid(fifo_valid), .s_axis_cartesian_tlast(fifo_last),
                     .s_axis_cartesian_tready(fifo_ready),.m_axis_dout_tdata(sqrt_data),
                     .m_axis_dout_tvalid(sqrt_valid), .m_axis_dout_tlast(sqrt_last));
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    

   
   
   
   
    
 //   assign minigame_order_in = {4'b0010, 4'b0100, 4'b0101, 4'b0001, 4'b0101, 4'b0100};
//    assign minigame_order_in = {4'b0010, 4'b0010, 4'b0001, 4'b0001, 4'b0010, 4'b0001};
    assign minigame_order_in = {4'b0010, 4'b0100, 4'b0001, 4'b0010, 4'b0101, 4'b0110};
    
    always_comb begin
        case(minigame)
            4'b0001 :  begin mg_fail = mg_fail1; mg_success = mg_success1; end
            4'b0010 :  begin mg_fail = mg_fail2; mg_success = mg_success2; end
            4'b0011 :  begin mg_fail = mg_fail3; mg_success = mg_success3; end
            4'b0100 :  begin mg_fail = mg_fail4; mg_success = mg_success4; end
            4'b0101 :  begin mg_fail = mg_fail5; mg_success = mg_success5; end
            4'b0110 :  begin mg_fail = mg_fail6; mg_success = mg_success6; end
            default :  begin mg_fail = 0;   mg_success=0; end
         endcase
     end
            
                        
    
    
    
    
    
    
    
    //create 65 MHz clock for 1024 x 768 VGA graphics
    //clk_wiz_lab3 clkdivider(.clk_in1(clk_100mhz), .clk_out1(clk_65mhz));
    // generate 25 mhz clock for sd_controller
    logic clk_25mhz;
    clk_wiz_0 clocks(.clk_in1(clk_100mhz), .clk_out1(clk_25mhz));
    
    
    
    
 /////////Debounce Inputs/////////////////////
	
	
	debounce #(.DEBOUNCE_COUNT(DEBOUNCE_COUNT)) db1 (.reset_in(sw[15]), .clock_in(clk_25mhz), .noisy_in(btnc),.clean_out(center));
	debounce #(.DEBOUNCE_COUNT(DEBOUNCE_COUNT)) db2 (.reset_in(sw[15]), .clock_in(clk_25mhz), .noisy_in(btnu),.clean_out(up));
	debounce #(.DEBOUNCE_COUNT(DEBOUNCE_COUNT)) db3 (.reset_in(sw[15]), .clock_in(clk_25mhz), .noisy_in(btnd),.clean_out(down));
	debounce #(.DEBOUNCE_COUNT(DEBOUNCE_COUNT)) db4 (.reset_in(sw[15]), .clock_in(clk_25mhz), .noisy_in(btnl),.clean_out(left));
	debounce #(.DEBOUNCE_COUNT(DEBOUNCE_COUNT)) db5 (.reset_in(sw[15]), .clock_in(clk_25mhz), .noisy_in(btnr),.clean_out(right));
	
	
	
	///////////////////timer demo, value is in seconds////////////////////
	
	
	timer #(.ONE_HZ_PERIOD(ONE_HZ_PERIOD)) t1 (.clock(clk_25mhz), .start_timer(timer_start),  .value(12'd300), .counting(counting), 
	 .expired_pulse(expired), .one_hz(one_hz_enable), .count_out(count), .ones(ones), .tens(tens), .minutes(minutes));
	 
	 
	 
	 
	 
	 //pseudorandom number generator, clock the ouput in order to select a random number
	 wire data_rand;
	 logic[15:0] rand_out;
	 random_num random (.clock(clk_25mhz),.data(data_rand), .random_number(rand_out));
	 
	 //temperature sensor data
	 wire [12:0] temp_o;
     reg [12:0] temp_valid;
    
     always @(posedge clk_25mhz)
         temp_valid <= rdy_o ?  temp_o : temp_valid;  // each bit is 0.0625 deg centigrade
    
     TempSensorCtl temp_sense(
         .TMP_SCL        (tmp_scl),
         .TMP_SDA        (tmp_sda),
         .TEMP_O         (temp_o),  // 13bit msb = sign
         .RDY_O          (rdy_o),   // data valid
         .ERR_O          (err_o),
         .CLK_I          (clk_25mhz),
         .SRST_I         (1'b0)
        );
        
        
     // ila_0 myila (.clk(clk_65mhz), .probe0(temp_valid)); 
     
     //Minigames
	 
	 minigame_1 mgame1 (.vclock_in(clk_25mhz), .reset_in(mg_start), .hcount_in(hcount), .vcount_in(vcount), 
	 .pixel_out(pixel_out1), .vsync_in(vsync), .temp_in(temp_valid), .btnu(up), .btnd(down), .btnl(left), .btnr(right), 
	 .sw(sw[3:0]), .random(rand_out[1:0]), .success(mg_success1), .fail(mg_fail1));
	 
	 logic [11:0] count_mg2;
	 logic [3:0] mg2_state;
	 logic [2:0] ledout_mg2;//{r,g,b} output for leds
	 
	 // version of minigame2 that uses accelerometer
     accel::e_orientation orientation;
     minigame_2 mgame2 (.vclock_in(clk_25mhz), .reset_in(mg_start), .hcount_in(hcount), .vcount_in(vcount), 
	 .pixel_out(pixel_out2), .vsync_in(vsync),  .btnu(orientation == accel::top), .btnd(orientation == accel::bottom), .btnl(orientation == accel::left), 
	 .btnr(orientation == accel::right),  .random(rand_out[1:0]), .led_r(ledout_mg2[2]), .led_b(ledout_mg2[0]), 
	 .led_g(ledout_mg2[1]), .timer_count(count_mg2), .state(mg2_state), .fail(mg_fail2), .success(mg_success2));

	 
//	 minigame_2 mgame2 (.vclock_in(clk_25mhz), .reset_in(mg_start), .hcount_in(hcount), .vcount_in(vcount), 
//	 .pixel_out(pixel_out2), .vsync_in(vsync),  .btnu(up), .btnd(down), .btnl(left), 
//	 .btnr(right),  .random(rand_out[1:0]), .led_r(ledout_mg2[2]), .led_b(ledout_mg2[0]), 
//	 .led_g(ledout_mg2[1]), .timer_count(count_mg2), .state(mg2_state), .fail(mg_fail2), .success(mg_success2));
//	 /*
	 /////////////////////minigame 3/////////////////////////////////////////////////
//	 logic [9:0] led_minigame3;
	 
//	     micr_minigame minigame_3 (.vclock_in(clk_25mhz), .reset_in(mg_start), .hcount_in(hcount), .vcount_in(vcount), .hsync_in(hsync),
//            .vsync_in(vsync), .blank_in(blanking), .button(center), .sqrt_data(sqrt_data), 
//            .sqrt_valid(sqrt_valid), .sqrt_last(sqrt_last), .minigame_number(minigame),
//            .completed(mg_success3), .phsync_out(phsync), .pvsync_out(pvsync), 
//            .pblank_out(pblank), .pixel_out(pixel_out3), .cool_led(led_minigame3));
   /////////////////////////////////////////////////////////////////////////////////////////////////////
 
   
   ////////////////////minigame_4////////////////////////////////////////////////
   
   logic hsync_mg4, vsync_mg4, blank_mg4;
   
	 wire_cutting minigame_4 (.vclock_in(clk_25mhz),.reset_in(mg_start), 
                .incolor1(rand_out[2:0]), .incolor2(rand_out[5:3]), .incolor3(rand_out[8:6]), .incolor4(rand_out[11:9]), .incolor5(rand_out[14:12]), .incolor6(rand_out[3:1]),
                .hcount_in(hcount),.vcount_in(vcount), .cut_switch(sw[9:4]), .completed(mg_success4), .failed(mg_fail4),
                .hsync_in(hsync),.vsync_in(vsync),.blank_in(blank), 
                .phsync_out(hsync_mg4),.pvsync_out(vsync_mg4),.pblank_out(blank_mg4),.pixel_out(pixel_out4));
                
                
     ///////////////////////////////////////////minigame_5//////////////////////////////////////////////////////////////
     button_game bg(.vclock_in(clk_25mhz),.reset_in(mg_start), .ones(ones[3:0]), .tens(tens[3:0]), .minutes(minutes),
                .hcount_in(hcount),.vcount_in(vcount), .pushed_button(up), .rand_has_text(rand_out[0]),
                .rand_button_color(rand_out[2:1]), .rand_strip_color(rand_out[3]), .completed(mg_success5), .failed(mg_fail5),
                .hsync_in(hsync),.vsync_in(vsync),.blank_in(blank), 
                .phsync_out(phsync),.pvsync_out(pvsync),.pblank_out(pblank),.pixel_out(pixel_out5));
     

	FPGA_graphics fpga_s (.vclock_in(clk_25mhz), .reset_in(system_reset), .hcount_in(hcount), .vcount_in(vcount),
	 .mg_completed(i), .pixel_out(pixel_out_fpga));

	FPGA_graphics_op fpga_m (.vclock_in(clk_25mhz), .reset_in(system_reset), .hcount_in(hcount), .vcount_in(vcount),
	 .mg_completed(i_op), .pixel_out(pixel_out_fpgaop));
	 
	 //////////////////////////////////////////////////////////////////////////////////////////////////
//	 logic [11:0] pixel_strikes;
//	 strike_graphics strikes (.vclock_in(clock_25mhz), .hcount_in(hcount), .vcount_in(vcount), .num_strikes(strike_count),
//	 .pixel_out(pixel_strikes));
/*
 logic [11:0] homescreen_out;
 logic homescreen_start;
 homescreen_graphics home (.vclock_in(clock_25mhz), .reset_in(homescreen_start), .hcount_in(hcount), .vcount_in(vcount), .up_in(up), 
 .down_in(down), .confirm(center), .mode(multiplayer), .pixel_out(homescreen_out));
 
	 logic [11:0] win_pixel;
	 logic play_again_win;
	 win_graphics win_screen (.vclock_in(clock_25mhz), .reset_in(win_start), .hcount_in(hcount), .vcount_in(vcount), .confirm(center), 
	 .pixel_out(win_pixel), .confirmed(play_again_win));
	 
	 logic [11:0] lose_pixel;
	 logic play_again_lose;
	 
	 lose_graphics lose_screen (.vclock_in(clock_25mhz), .reset_in(lose_start), .hcount_in(hcount), .vcount_in(vcount), .confirm(center), 
	 .pixel_out(lose_pixel), .confirmed(play_again_lose));
*/
	 
	 
	
	////////////////////////MULTIPLAYER FUNCTIONALITY//////////////////////////////////////////////
	logic multiplayer_reset;
	logic[31:0] mult_out;
	multiplayer_data multi (.vclock_in(clk_25mhz), .reset_in(multiplayer_reset), .uart_in(serial_rx), 
	.i(i), .strike_count(strike_count), .btnc(sw[10]), .game_state(game_state), .data_out(mult_out), .uart_out(serial_tx));
	assign i_op = mult_out[2:0];
	assign strike_count_op = mult_out[4:3];
	assign btnc_op = mult_out[5];
	
	 
	 //Handle Graphics
	 xvga xvga1(.vclock_in(clk_25mhz),.hcount_out(hcount),.vcount_out(vcount),
          .hsync_out(hsync),.vsync_out(vsync),.blank_out(blank));
     
     logic border = (hcount==0 | hcount==1023 | vcount==0 | vcount==767 |
                   hcount == 512 | vcount == 384);
     logic b,hs,vs;
     
     ////////////////////////////////////////////////////////GAMEPLAY FSM///////////////////////////////////////////////
     assign reset = sw[15];
     assign multiplayer = sw[13:12];
     //assign minigame = 3'b010; //choose which minigame is playing
     assign play_again = sw[11];
 
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
                                    
                SYNC    :   begin   multiplayer_reset <= 0; game_state <= (sw[10] & btnc_op)?START:SYNC; 
                                    if(sw[10] & btnc_op) timer_start <= 1;end
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
     //Graphics based on the minigame being played
 
     logic prev_onehz;
     logic [11:0] gengine_pixel_out;

     localparam TITLE_SCREEN = 4'b0000;
     localparam LOSE_SCREEN = 4'b0111;
     localparam WIN_SCREEN = 4'b1000;
     localparam MORSE_MINIGAME = 4'b0110;
     logic stop_sound_between_minigames;

    always_ff @(posedge clk_25mhz) begin
         hs <= hsync;
         vs <= vsync;
         b <= blank;
         prev_onehz <= one_hz_enable;
         if(one_hz_enable & !prev_onehz)begin 
            led = rand_out;
         end

          case(minigame)
            4'b0000      :   begin rgb <= gengine_pixel_out; //home, change to pixel_out_home
                            {led16_r, led16_g, led16_b} <= 3'b0; end 
            //4'b0000      :   begin rgb <= gengine_pixel_out; //home, change to pixel_out_home
              //              {led16_r, led16_g, led16_b} <= 3'b0; end 
            4'b0001      :   begin rgb <= multiplayer[1]? pixel_out1+pixel_out_fpga+pixel_out_fpgaop : pixel_out1+pixel_out_fpga;
                            {led16_r, led16_g, led16_b} <= 3'b0; 
                           end
            4'b0010      :   begin rgb <= multiplayer[1]? pixel_out2+pixel_out_fpga+pixel_out_fpgaop  : pixel_out2+pixel_out_fpga;
                                  {led16_r, led16_g, led16_b} <= ledout_mg2; 
                                  ; end
            4'b0011      :   begin rgb <= multiplayer[1]? pixel_out3+pixel_out_fpga+pixel_out_fpgaop: pixel_out3+pixel_out_fpga;
                                  {led16_r, led16_g, led16_b} <= 0;
                                   end
            4'b0100      :  begin rgb <= multiplayer[1]? pixel_out4+pixel_out_fpga+pixel_out_fpgaop : pixel_out4+pixel_out_fpga;
                                  {led16_r, led16_g, led16_b} <= 0;
                                  end
            4'b0101      :  begin rgb <= multiplayer[1]? pixel_out5+pixel_out_fpga+pixel_out_fpgaop : pixel_out5+pixel_out_fpga;
                                  {led16_r, led16_g, led16_b} <= 0;
                                  end
            4'b0110      : begin rgb <= multiplayer[1]? gengine_pixel_out+pixel_out_fpga+pixel_out_fpgaop : gengine_pixel_out +pixel_out_fpga;
                                  {led16_r, led16_g, led16_b} <= 0;
                                  end
            4'b0111      :   begin rgb <= gengine_pixel_out; //LOSE, change to pixel_out_lose
                            {led16_r, led16_g, led16_b} <= 3'b100; end 
            4'b1000      :   begin rgb <= gengine_pixel_out; //WIN, change to pixel_out_win
                            {led16_r, led16_g, led16_b} <= 3'b111; end 
            4'b1001      :  begin rgb <= pixel_out_sync;
                                  {led16_r, led16_g, led16_b} <= 3'b000;end //SYNC STATE
            default     :   rgb <= rgb <= {12{border}};
        
          endcase
 
    end
    
    assign vga_r = ~b ? rgb[11:8]: 0;
    assign vga_g = ~b ? rgb[7:4] : 0;
    assign vga_b = ~b ? rgb[3:0] : 0;

    assign vga_hs = ~hs;
    assign vga_vs = ~vs;

	   //  instantiate 7-segment display; display (8) 4-bit hex
    logic [31:0] data;      
    logic [6:0] segments;
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
    assign data[3:0] = ones[3:0];
    assign data[7:4] = tens[3:0];
    assign data[11:8] = minutes;
    assign data[31:12] = {7'b0, btnc_op,2'b0, strike_count, 4'b0};
    
    display_8hex display_mod (.clk_in(clk_25mhz), .data_in(data),
	.seg_out({cg, cf, ce, cd, cc, cb, ca}), .strobe_out(an));

//    accel::e_orientation orientation;

    accelerometer accelerometer_builtin(
        .clk_in(clk_25mhz),
        .reset_in(reset),
        .acl_miso,
        .acl_mosi,
        .acl_sclk,
        .acl_csn,

        .orientation
    );

    // Change NUM_SHUFFLED_ITEMS and SHUFFLED_ITEM_BITS, data_in should be whatever you want shuffled (packed array of bits)
    // pulse should_shuffle_in when you want to shuffle; set data_out and valid_out accordingly
    shuffler #(.NUM_SHUFFLED_ITEMS(6), .SHUFFLED_ITEM_BITS(4)) 
              (.clk_in(clk_25mhz), .reset_in(system_reset), .data_in(minigame_order_in), .random_in(rand_out[3:0]), 
               .should_shuffle_in(start_shuffle), .data_out(minigame_order_out), .valid_out(done_shuffle));


    logic system_clock;
    assign system_clock = clk_25mhz;

    logic should_render;
    logic render_dirty;
    logic [7:0] num_objects;    // TODO do we need num_objects if we have flags?
    logic [7:0] new_object_waddr;
    logic new_object_we;
    logic [35:0] new_object_properties;
    logic render_ack;

    logic [7:0] texturemap_id;
    logic should_load_texturemap;
    logic texturemap_load_ack;
    
    logic play;
    logic stop;

    logic graphics_req;
    logic [31:0] graphics_req_addr;
    logic graphics_req_ack;
    logic graphics_req_we;
    logic [7:0] graphics_req_dout;

    logic [5:0] audio_header_raddr;
    logic [31:0] audio_header_dout;
    logic [5:0] graphics_header_raddr;
    logic [31:0] graphics_header_dout;

    logic audio_req;
    logic [31:0] audio_req_addr;
    logic audio_req_ack;
    logic audio_req_we;
    logic [7:0] audio_req_dout;

    logic audio_out;

    sd_card_fsm sd_controller(
        .clk_in(system_clock),
        .reset_in(system_reset),

        .cs(sd_dat[3]),
        .mosi(sd_cmd),
        .miso(sd_dat[0]),
        .sclk(sd_sck),

        .graphics_header_raddr(),
        .audio_header_raddr,
        .graphics_header_dout(),
        .audio_header_dout,

        .audio_req,
        .audio_req_addr,
        .audio_req_ack,
        .audio_req_we,
        .audio_req_dout,

        .graphics_req,
        .graphics_req_addr,
        .graphics_req_ack,
        .graphics_req_we,
        .graphics_req_dout
    );

    graphics_engine gengine(
        .clk(system_clock),
        .reset(system_reset),

        .hcount,
        .vcount,

        .pixel_out(gengine_pixel_out),

        .should_render,
        .render_dirty,
        .num_objects,
        .new_object_waddr,
        .new_object_we,
        .new_object_properties,
        .render_ack,

        .texturemap_id,
        .should_load_texturemap,
        .texturemap_load_ack,

        .graphics_req,
        .graphics_req_addr,
        .graphics_req_ack,
        .graphics_req_we,
        .graphics_req_dout
    );

    sound_engine sengine(
        .clk(system_clock),
        .reset(system_reset),

        .play(play_sound),
        .stop(stop_sound || stop_sound_between_minigames),
        .sound_id,

        .audio_header_raddr,
        .audio_header_dout,
        .audio_req, 
        .audio_req_addr,
        .audio_req_ack,
        .audio_req_we,
        .audio_req_dout,
        .audio_out
    );
    
   

    assign aud_sd = 1'b1;
//    assign aud_pwm = pwm_val?1'bZ:1'b0; 
    assign aud_pwm = (minigame==3)?(pwm_val?1'bZ:1'b0):audio_out ? 1'bZ : 1'b0;
/*

confirm is button to press to confirm single/multiplayer
up down toggles between single / multiplayer
mode is just 2 bit output telling whether single/multi chosen -- single = 01 multi = 10 i believe
homescreen_graphics pg(.vclock_in(clk_65mhz),.reset_in(left), .confirm(center),
                .up_in(up),.down_in(down), .hcount_in(hcount),.vcount_in(vcount),
                .hsync_in(hsync),.vsync_in(vsync),.blank_in(blank), .mode(led[1:0]),
                .phsync_out(phsync),.pvsync_out(pvsync),.pblank_out(pblank),.pixel_out(pixel));
   
    starting here is winning
    confirm is just to try again
    win_graphics winning(.vclock_in(clk_65mhz),.reset_in(left), .confirm(center),
                .hcount_in(hcount),.vcount_in(vcount),
                .hsync_in(hsync),.vsync_in(vsync),.blank_in(blank), .confirmed(led[15]),
                .phsync_out(phsync),.pvsync_out(pvsync),.pblank_out(pblank),.pixel_out(win_pixel));
    
    starting here is losing
    confirm to try again
    lose_graphics losing(.vclock_in(clk_65mhz),.reset_in(left), .confirm(center),
                .hcount_in(hcount),.vcount_in(vcount),
                .hsync_in(hsync),.vsync_in(vsync),.blank_in(blank), .confirmed(led[7]),
                .phsync_out(phsync),.pvsync_out(pvsync),.pblank_out(pblank),.pixel_out(lose_pixel));

button game
ones, tens, minutes from timer module
pushed button is the 'button' in the game, so the one you need to push following the rules to win
rand has text is a 1 bit entry from the random module, the button can be either blank or say 'hold', so 
this chooses one
rand button color, 2 bit random -- chooses button color based on rules in module
rand strip color chooses strip color 1 bit from random module, this will also be explained in rules
completed means they did it correctly, failed means they didnt


wire cutting game
color1-6 are 3 bit random entry numbers that choose colors for each wire
switches 15-10 are used to cut the wires atm, 15 corresponding to leftmost on screen and 10 to rightmost
again completed if they did it correctly, failed if not (i added a slight delay to these signals from when the
player cuts a wire because i wanted them to see that the cut wire turns black lol this was how i could best 
simulate cutting :,) )
wire_cutting wc(.vclock_in(clk_65mhz),.reset_in(left), 
                .incolor1(color1), .incolor2(color2), .incolor3(color3), .incolor4(color4), .incolor5(color5), .incolor6(color6),
                .hcount_in(hcount),.vcount_in(vcount), .cut_switch(sw[15:10]), .completed(led16_g), .failed(led16_r),
                .hsync_in(hsync),.vsync_in(vsync),.blank_in(blank), 
                .phsync_out(phsync),.pvsync_out(pvsync),.pblank_out(pblank),.pixel_out(wire_pixel));
*/
//     This is a horrible, giant multiplexer to resolve conflicts between different modules that use gengine/sengine
//     the sight of this is actually truly awful

    logic morse_should_render;
    logic morse_render_dirty;
    logic [7:0] morse_num_objects;
    logic [7:0] morse_new_object_waddr;
    logic morse_new_object_we;
    logic [35:0] morse_new_object_properties;

    logic [7:0] morse_texturemap_id;
    logic morse_should_load_texturemap;

    logic title_screen_should_render;
    logic title_screen_render_dirty;
    logic [7:0] title_screen_num_objects;
    logic [7:0] title_screen_new_object_waddr;
    logic title_screen_new_object_we;
    logic [35:0] title_screen_new_object_properties;

    logic [7:0] title_screen_texturemap_id;
    logic title_screen_should_load_texturemap;

    logic lose_screen_should_render;
    logic lose_screen_render_dirty;
    logic [7:0] lose_screen_num_objects;
    logic [7:0] lose_screen_new_object_waddr;
    logic lose_screen_new_object_we;
    logic [35:0] lose_screen_new_object_properties;

    logic [7:0] lose_screen_texturemap_id;
    logic lose_screen_should_load_texturemap;

    logic win_screen_should_render;
    logic win_screen_render_dirty;
    logic [7:0] win_screen_num_objects;
    logic [7:0] win_screen_new_object_waddr;
    logic win_screen_new_object_we;
    logic [35:0] win_screen_new_object_properties;

    logic [7:0] win_screen_texturemap_id;
    logic win_screen_should_load_texturemap;

    logic minigame_reset;
    logic [3:0] minigame_last;

    always_ff @(posedge system_clock) begin
        minigame_last <= minigame;
        if (minigame_reset) minigame_reset <= 1'b0;
        if (stop_sound_between_minigames) stop_sound_between_minigames <= 1'b0;

        if (minigame_last != minigame) begin
            minigame_reset <= 1'b1;
            stop_sound_between_minigames <= 1'b1;
        end

        case (minigame)
            MORSE_MINIGAME: begin
                should_render <= morse_should_render;
                render_dirty <= morse_render_dirty;
                num_objects <= morse_num_objects;
                new_object_waddr <= morse_new_object_waddr;
                new_object_we <= morse_new_object_we;
                new_object_properties <= morse_new_object_properties;
        
                texturemap_id <= morse_texturemap_id;
                should_load_texturemap <= morse_should_load_texturemap;
            end

            TITLE_SCREEN: begin
                should_render <= title_screen_should_render;
                render_dirty <= title_screen_render_dirty;
                num_objects <= title_screen_num_objects;
                new_object_waddr <= title_screen_new_object_waddr;
                new_object_we <= title_screen_new_object_we;
                new_object_properties <= title_screen_new_object_properties;
        
                texturemap_id <= title_screen_texturemap_id;
                should_load_texturemap <= title_screen_should_load_texturemap;
            end

            WIN_SCREEN: begin
                should_render <= win_screen_should_render;
                render_dirty <= win_screen_render_dirty;
                num_objects <= win_screen_num_objects;
                new_object_waddr <= win_screen_new_object_waddr;
                new_object_we <= win_screen_new_object_we;
                new_object_properties <= win_screen_new_object_properties;
        
                texturemap_id <= win_screen_texturemap_id;
                should_load_texturemap <= win_screen_should_load_texturemap;
            end

            LOSE_SCREEN: begin
                should_render <= lose_screen_should_render;
                render_dirty <= lose_screen_render_dirty;
                num_objects <= lose_screen_num_objects;
                new_object_waddr <= lose_screen_new_object_waddr;
                new_object_we <= lose_screen_new_object_we;
                new_object_properties <= lose_screen_new_object_properties;
        
                texturemap_id <= lose_screen_texturemap_id;
                should_load_texturemap <= lose_screen_should_load_texturemap;
            end
        endcase
    end

    logic morse_play_sound;
    logic morse_stop_sound;
    logic [4:0] morse_sound_id;

    logic title_screen_play_sound;
    logic title_screen_stop_sound;
    logic [4:0] title_screen_sound_id;

    always_ff @(posedge system_clock) begin
        case (minigame)
            MORSE_MINIGAME: begin
                play_sound <= morse_play_sound;
                stop_sound <= morse_stop_sound;
                sound_id <= morse_sound_id;
            end

            TITLE_SCREEN: begin
                play_sound <= title_screen_play_sound;
                stop_sound <= title_screen_stop_sound;
                sound_id <= title_screen_sound_id;
            end
        endcase
    end

    minigame_morse minigame_morse_inst(
        .clk(system_clock),
        .reset(minigame_reset || system_reset),

        .play(morse_play_sound),
        .stop(morse_stop_sound),
        .sound_id(morse_sound_id),

        .should_render(morse_should_render),
        .render_dirty(morse_render_dirty),
        .num_objects(morse_num_objects),
        .new_object_waddr(morse_new_object_waddr),
        .new_object_we(morse_new_object_we),
        .new_object_properties(morse_new_object_properties),
        .render_ack,

        .texturemap_id(morse_texturemap_id),
        .should_load_texturemap(morse_should_load_texturemap),
        .texturemap_load_ack,

        .failure(mg_fail6),
        .success(mg_success6),

        .random(rand_out[3:0]),
        .sw(sw[3:0]),
        .btnc(center)
    );

    title_screen_graphics title_screen(
        .clk(system_clock),
        
        .reset(minigame_reset || system_reset),

        .play(title_screen_play_sound),
        .stop(title_screen_stop_sound),
        .sound_id(title_screen_sound_id),

        
        .should_render(title_screen_should_render),
        .render_dirty(title_screen_render_dirty),
        .num_objects(title_screen_num_objects),
        .new_object_waddr(title_screen_new_object_waddr),
        .new_object_we(title_screen_new_object_we),
        .new_object_properties(title_screen_new_object_properties),
        .render_ack,

        .texturemap_id(title_screen_texturemap_id),
        .should_load_texturemap(title_screen_should_load_texturemap),
        .texturemap_load_ack,

        .up,
        .down,
        .confirm(center),
        .mode()
    );

    lose_graphics lose_screen(
        .clk(system_clock),
        .reset(minigame_reset || system_reset),

//        .play,
//        .stop,
//        .sound_id,

        .should_render(lose_screen_should_render),
        .render_dirty(lose_screen_render_dirty),
        .num_objects(lose_screen_num_objects),
        .new_object_waddr(lose_screen_new_object_waddr),
        .new_object_we(lose_screen_new_object_we),
        .new_object_properties(lose_screen_new_object_properties),
        .render_ack,

        .texturemap_id(lose_screen_texturemap_id),
        .should_load_texturemap(lose_screen_should_load_texturemap),
        .texturemap_load_ack,

        .confirm(down),
        .confirmed()
    );

    win_graphics win_screen(
        .clk(system_clock),
        .reset(minigame_reset || system_reset),

//        .play,
//        .stop,
//        .sound_id,

        .should_render(win_screen_should_render),
        .render_dirty(win_screen_render_dirty),
        .num_objects(win_screen_num_objects),
        .new_object_waddr(win_screen_new_object_waddr),
        .new_object_we(win_screen_new_object_we),
        .new_object_properties(win_screen_new_object_properties),
        .render_ack,

        .texturemap_id(win_screen_texturemap_id),
        .should_load_texturemap(win_screen_should_load_texturemap),
        .texturemap_load_ack,

        .confirm(down),
        .confirmed()
    );


endmodule


///////////////8 hex Display///////////////////////
module display_8hex(
    input clk_in,                 // system clock
    input [31:0] data_in,         // 8 hex numbers, msb first
    output logic [6:0] seg_out,     // seven segment display output
    output logic [7:0] strobe_out   // digit strobe
    );

    localparam bits = 13;
     
    logic [bits:0] counter = 0;  // clear on power up
     
    logic [6:0] segments[15:0]; // 16 7 bit memorys
    assign segments[0]  = 7'b100_0000;  // inverted logic
    assign segments[1]  = 7'b111_1001;  // gfedcba
    assign segments[2]  = 7'b010_0100;
    assign segments[3]  = 7'b011_0000;
    assign segments[4]  = 7'b001_1001;
    assign segments[5]  = 7'b001_0010;
    assign segments[6]  = 7'b000_0010;
    assign segments[7]  = 7'b111_1000;
    assign segments[8]  = 7'b000_0000;
    assign segments[9]  = 7'b001_1000;
    assign segments[10] = 7'b000_1000;
    assign segments[11] = 7'b000_0011;
    assign segments[12] = 7'b010_0111;
    assign segments[13] = 7'b010_0001;
    assign segments[14] = 7'b000_0110;
    assign segments[15] = 7'b000_1110;
     
    always_ff @(posedge clk_in) begin
      // Here I am using a counter and select 3 bits which provides
      // a reasonable refresh rate starting the left most digit
      // and moving left.
      counter <= counter + 1;
      case (counter[bits:bits-2])
          3'b000: begin  // use the MSB 4 bits
                  seg_out <= segments[data_in[31:28]];
                  strobe_out <= 8'b0111_1111 ;
                 end

          3'b001: begin
                  seg_out <= segments[data_in[27:24]];
                  strobe_out <= 8'b1011_1111 ;
                 end

          3'b010: begin
                   seg_out <= segments[data_in[23:20]];
                   strobe_out <= 8'b1101_1111 ;
                  end
          3'b011: begin
                  seg_out <= segments[data_in[19:16]];
                  strobe_out <= 8'b1110_1111;        
                 end
          3'b100: begin
                  seg_out <= segments[data_in[15:12]];
                  strobe_out <= 8'b1111_0111;
                 end

          3'b101: begin
                  seg_out <= segments[data_in[11:8]];
                  strobe_out <= 8'b1111_1011;
                 end

          3'b110: begin
                   seg_out <= segments[data_in[7:4]];
                   strobe_out <= 8'b1111_1101;
                  end
          3'b111: begin
                  seg_out <= segments[data_in[3:0]];
                  strobe_out <= 8'b1111_1110;
                 end

       endcase
      end

endmodule

////////////////////////// XVGA Module //////////////////////

module xvga(input vclock_in,
            output logic [10:0] hcount_out,    // pixel number on current line
            output logic [9:0] vcount_out,     // line number
            output logic vsync_out, hsync_out,
            output logic blank_out);

   parameter DISPLAY_WIDTH  = 640;      // display width
   parameter DISPLAY_HEIGHT = 480;       // number of lines

   parameter  H_FP = 16;                 // horizontal front porch
   parameter  H_SYNC_PULSE = 96;        // horizontal sync
   parameter  H_BP = 48;                // horizontal back porch

   parameter  V_FP = 11;                  // vertical front porch
   parameter  V_SYNC_PULSE = 2;          // vertical sync
   parameter  V_BP = 31;                 // vertical back porch

   // horizontal: 1344 pixels total
   // display 1024 pixels per line
   logic hblank,vblank;
   logic hsyncon,hsyncoff,hreset,hblankon;
   assign hblankon = (hcount_out == (DISPLAY_WIDTH -1));
   assign hsyncon = (hcount_out == (DISPLAY_WIDTH + H_FP - 1));  //1047
   assign hsyncoff = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE - 1));  // 1183
   assign hreset = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE + H_BP - 1));  //1343

   // vertical: 806 lines total
   // display 768 lines
   logic vsyncon,vsyncoff,vreset,vblankon;
   assign vblankon = hreset & (vcount_out == (DISPLAY_HEIGHT - 1));   // 767
   assign vsyncon = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP - 1));  // 771
   assign vsyncoff = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE - 1));  // 777
   assign vreset = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE + V_BP - 1)); // 805

   // sync and blanking
   logic next_hblank,next_vblank;
   assign next_hblank = hreset ? 0 : hblankon ? 1 : hblank;
   assign next_vblank = vreset ? 0 : vblankon ? 1 : vblank;
   always_ff @(posedge vclock_in) begin
      hcount_out <= hreset ? 0 : hcount_out + 1;
      hblank <= next_hblank;
      hsync_out <= hsyncon ? 0 : hsyncoff ? 1 : hsync_out;  // active low

      vcount_out <= hreset ? (vreset ? 0 : vcount_out + 1) : vcount_out;
      vblank <= next_vblank;
      vsync_out <= vsyncon ? 0 : vsyncoff ? 1 : vsync_out;  // active low

      blank_out <= next_vblank | (next_hblank & ~hreset);
   end
endmodule

/////////////////////////////////////////////////////////////////////
//////////////// Minigame 1-FINGERPRINT SCAN ////////////////////////
/////////////////////////////////////////////////////////////////////


module minigame_1( input vclock_in,
                   input reset_in,
                   input [10:0] hcount_in,
                   input [9:0] vcount_in,
                   input [1:0] random,
                   input [3:0] sw,
                   input btnu, btnl, btnd, btnr,
                   input vsync_in,
                   input [12:0] temp_in,
                   
                   output logic [11:0] pixel_out,
                   output logic success, fail
               
                   
                   );
                   parameter START = 3'b000;
                   parameter FIRST_SQUARE = 3'b001;
                   parameter SECOND_SQUARE = 3'b010;
                   parameter THIRD_SQUARE = 3'b011;
                   parameter DECODE = 3'b100;
                   parameter DONE = 3'b101;
                   parameter FAILED = 3'b110;
                   
                   
                   logic [11:0] pixel_ll, pixel_lr, pixel_lc, pixel_f;
                   logic[11:0] color_sq1, col_start_sq1;
                   logic[11:0] color_sq2, col_start_sq2;
                   logic[11:0] color_sq3, col_start_sq3;
                   logic [11:0] final_col;
                   logic [2:0] state;
                   logic [12:0] start_temp;
                   logic[1:0] chosen_rand;
                   
                   blob_D #(.WIDTH(40), .HEIGHT(40)) square_1(.x_in(11'd220), .hcount_in(hcount_in), .y_in(10'd400), .vcount_in(vcount_in), .pixel_out(pixel_ll), .color(color_sq1));
                   blob_D #(.WIDTH(40), .HEIGHT(40)) square_2(.x_in(11'd300), .hcount_in(hcount_in), .y_in(10'd400), .vcount_in(vcount_in), .pixel_out(pixel_lc), .color(color_sq2));
                   blob_D #(.WIDTH(40), .HEIGHT(40)) square_3(.x_in(11'd380), .hcount_in(hcount_in), .y_in(10'd400), .vcount_in(vcount_in), .pixel_out(pixel_lr), .color(color_sq3));
                  //fingerprint(.pixel_clk_in(vclock_in), .x_in(11'd386), .y_in(10'd351), .hcount_in(hcount_in), .vcount_in(vcount_in), .pixel_out(pixel_f));
                   
                   logic[11:0] diff1;
                   logic[11:0] diff2;
                   assign pixel_out = pixel_ll + pixel_lr + pixel_lc + pixel_f;
                   assign diff1 = temp_in - start_temp;
                   assign diff2 = start_temp - temp_in;
                   
                   Lut_mg1 lut1 (.clock(vclock_in), .rn(chosen_rand), .sq_1(col_start_sq1), .sq_2(col_start_sq2), .sq_3(col_start_sq3), .final_color(final_col));
                   
                   
                   
                   logic vsync_prev;
                   
                   always_ff @(posedge vclock_in) begin
                        vsync_prev <= vsync_in;
                   end
                   
                   always_ff @(posedge vclock_in) begin
                        if (reset_in) begin
                            state <= 3'b000;
                            start_temp <= temp_in;
                            chosen_rand <= random;
                            success <= 0;
                            fail <= 0;
                        end 
                            
                        else if (vsync_prev & !vsync_in) begin
                        //diff_out <= temp_in[11:0] - start_temp
                        case(state)
                            START           :      begin color_sq1<= col_start_sq1; color_sq2 <= col_start_sq2; color_sq3 <= col_start_sq3; state <= FIRST_SQUARE; end
                            FIRST_SQUARE    :      begin if ((diff1 > 12'h004 || diff1==12'h004) & !diff1[11]) begin
                                                                color_sq1 <= col_start_sq2;
                                                                state <= SECOND_SQUARE;
                                                                start_temp <= temp_in;
                                                          end else begin
                                                                color_sq1 <= col_start_sq1;
                                                                state <= FIRST_SQUARE;
                                                          end
                                                    end
                                                    
                             SECOND_SQUARE  :     begin if ((diff2 > 12'h004 || diff2==12'h004) & !diff2[11]) begin
                                                                color_sq2 <= col_start_sq3;
                                                                state <= THIRD_SQUARE;
                                                                start_temp <= temp_in;
                                                          end else begin
                                                                color_sq2 <= col_start_sq2;
                                                                state <= SECOND_SQUARE;
                                                          end
                                                    end
                             THIRD_SQUARE   :     begin if ((diff1 > 12'h004 || diff1==12'h004) & !diff1[11]) begin
                                                                color_sq3 <= final_col;
                                                                state <= DECODE;
                                                          end else begin
                                                                color_sq3 <= col_start_sq3;
                                                                state <= THIRD_SQUARE;
                                                          end
                                                    end
                             DECODE           :     begin case(chosen_rand) 
                                                                2'b00   :   begin state <= (sw[2]& btnu & btnr)? DONE: (sw[0]|sw[1]|sw[3]|btnl|btnd)? FAILED :DECODE;  end
                                                                2'b01   :   begin state <= (sw[0]& btnu & btnd)? DONE: (sw[2]|sw[1]|sw[3]|btnl|btnr)? FAILED :DECODE;  end
                                                                2'b10   :   begin state <= (sw[1]& btnl & btnr)? DONE: (sw[0]|sw[2]|sw[3]|btnd|btnu)? FAILED :DECODE;  end
                                                                2'b11   :   begin state <= (sw[3]& btnl & btnd)? DONE: (sw[0]|sw[1]|sw[2]|btnr|btnu)? FAILED :DECODE;  end
                                                                
                                                                
                                                           endcase
                                                    end
                             DONE             :     begin color_sq1 <= 12'h0F0; color_sq2 <= 12'h0F0; color_sq3 <= 12'h0F0; success <= 1; end
                             
                             FAILED           :     fail <= 1;
                                                    
                        endcase
                      end
                   end
                    
                   
endmodule


///////////////////////////////////////////////////////

/////////////////////////////////LUT for Minigame 1////////////////////////////
module Lut_mg1(         input clock,
                        input [1:0] rn,
                        output logic [11:0] sq_1,
                        output logic [11:0] sq_2,
                        output logic [11:0] sq_3,
                        output logic [11:0] final_color                      
);

    always_ff @(posedge clock) begin
        case(rn)
            2'b00       :   begin  sq_1 <= 12'h00F; sq_2<= 12'hF0F; sq_3 <= 12'hF00; final_color <= 12'hFF0; end
            2'b01       :   begin  sq_1 <= 12'hF0F; sq_2<= 12'hF00; sq_3 <= 12'hFF0; final_color <= 12'h0F0; end
            2'b10       :   begin  sq_1 <= 12'hF00; sq_2<= 12'hFF0; sq_3 <= 12'h0F0; final_color <= 12'h0FF; end
            2'b11       :   begin  sq_1 <= 12'hFF0; sq_2<= 12'h0F0; sq_3 <= 12'h0FF; final_color <= 12'h00F; end
        endcase
     end

endmodule


/////////////////////////////////////////////////////////////////////////////
///////////////////// MINIGAME 2- SIMON SAYS/////////////////////////////////
/////////////////////////////////////////////////////////////////////////////


module minigame_2( input vclock_in,
                   input reset_in,
                   input [10:0] hcount_in,
                   input [9:0] vcount_in,
                   input [1:0] random,
                   input btnu, btnl, btnd, btnr,
                   //input hsync_in,
                   input vsync_in,
                   //input blank_in,
                   
                   output logic [11:0] pixel_out,
                   output logic [11:0] timer_count,
                   output logic led_r,
                   output logic  led_g,
                   output logic  led_b,
                   output logic [3:0] state,
                   output logic success, fail
                   
                   );
                   
                   parameter  INIT = 4'b0000;
                   parameter FLASH_1 = 4'b0001;
                   parameter SEQ_1 = 4'b0010;
                   parameter FLASH_2 = 4'b0011;
                   parameter SEQ_2 = 4'b0100;
                   parameter FLASH_3 = 4'b0101;
                   parameter SEQ_3 = 4'b0110;
                   parameter FLASH_4 = 4'b0111;
                   parameter SEQ_4 = 4'b1000;
                   parameter FAILED = 4'b1001;
                   parameter SUCCESS = 4'b1010;
                   parameter WAIT_FLASH1 = 4'b1011;
                   parameter WAIT_FLASH2 = 4'b1100;
                   parameter WAIT_FLASH3 = 4'b1101;
                   parameter WAIT_FLASH4 = 4'b1110;
                   
                   
//   assign checkerboard = hcount_in[8:6] + vcount_in[8:6];
                   
                   //logic [3:0] state;
                   logic [1:0] chosen_rand;
     
                   logic timer_start;
                   logic [26:0] clock_count;
                   logic [26:0] color_count;
                   logic [3:0] state_count;
                   logic expired;
                   logic [2:0] lut_out, light_1, light_2, light_3, light_4;
                   logic prev_btnu, prev_btnd, prev_btnl, prev_btnr, btnu1, btnd1, btnr1, btnl1;
                   logic [11:0] color_1, color_2, color_3, color_4, pixel_out1, pixel_out2, pixel_out3, pixel_out4;
                   logic [1:0] color_rand;
                   
                   circle_blob  #(.RADIUS(16)) circle1 (.x_in(11'd320), .y_in(10'd216), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_1), .pixel_out(pixel_out1));
                   circle_blob  #(.RADIUS(16)) circle2 (.x_in(11'd344), .y_in(10'd240), .vclock_in(vclock_in),.vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_2), .pixel_out(pixel_out2));
                   circle_blob  #(.RADIUS(16)) circle3 (.x_in(11'd320), .y_in(11'd264), .vclock_in(vclock_in),.vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_3), .pixel_out(pixel_out3));
                   circle_blob  #(.RADIUS(16)) circle4 (.x_in(11'd296), .y_in(10'd240), .vclock_in(vclock_in), .vcount_in(vcount_in), .hcount_in(hcount_in), .color(color_4), .pixel_out(pixel_out4));
                   
                   assign pixel_out = pixel_out1 + pixel_out2 + pixel_out3 + pixel_out4;
                   assign btnu1 = btnu & !prev_btnu;
                   assign btnd1 = btnd & !prev_btnd;
                   assign btnr1 = btnr & !prev_btnr;
                   assign btnl1 = btnl & !prev_btnl;
                   
                   
                   
                   timer #(.ONE_HZ_PERIOD(25_000_000)) timer_mg2(.clock(vclock_in), .start_timer(timer_start), .value(12'd2), .count_out(timer_count), .expired_pulse(expired));
                   Lut_mg2 lutmg2 (.rn(chosen_rand), .led_col(lut_out));
                   logic vsync_prev;
                   
                   
                    always_ff @(posedge vclock_in) begin
                        vsync_prev <= vsync_in;
                   end
                   
                   
                   ////////////////////Fun color graphics///////////////////////////////////////////////////////
                   
                   always_ff @(posedge vclock_in) begin
                        if (reset_in) begin
                            color_1 <= 12'h00F;
                            color_2 <= 12'h0F0;
                            color_3 <= 12'hFF0;
                            color_4 <= 12'hF00;
                            color_rand <= random;
                            clock_count <= 0;
                            color_count <=0;
                        end else begin
                        
                        if(color_count == 27'd25_000_00) begin
                            color_rand <= random;
                            color_count <= 0;
                        end else color_count <= color_count + 1;
                            
                         if(clock_count == 27'd2_500_000) begin
                            case(color_rand)
                                2'b00   : begin color_1<=(state_count>4'b0000 & state != INIT)?color_1:{color_1[11:8], color_1[7:4], color_1[3:0]+1}; 
                                                color_2<= (state_count>4'b0010 & state != INIT)? color_2: {color_2[11:8], color_2[7:4], color_2[3:0]+1};
                                                color_3<= (state_count>4'b0101 & state != INIT)? color_3: {color_3[11:8], color_3[7:4], color_3[3:0]+1};
                                                color_4<= (state==SUCCESS)? color_4:{color_4[11:8], color_4[7:4], color_4[3:0]+1};
                                          end
                                2'b01   : begin color_1<=(state_count>4'b0000 & state != INIT)?color_1:{color_1[11:8], color_1[7:4]+1, color_1[3:0]}; 
                                                color_2<= (state_count>4'b0010 & state != INIT)? color_2: {color_2[11:8], color_2[7:4]+1, color_2[3:0]};
                                                color_3<= (state_count>4'b0101 & state != INIT)? color_3: {color_3[11:8], color_3[7:4]+1, color_3[3:0]};
                                                color_4<= (state==SUCCESS)? color_4:{color_4[11:8], color_4[7:4]+1, color_4[3:0]};
                                          end
                                                
                                2'b10   : begin color_1<=(state_count>4'b0000 & state != INIT)?color_1:{color_1[11:8]+1, color_1[7:4], color_1[3:0]}; 
                                                color_2<= (state_count>4'b0010 & state != INIT)? color_2: {color_2[11:8]+1, color_2[7:4], color_2[3:0]};
                                                color_3<= (state_count>4'b0101 & state != INIT)? color_3: {color_3[11:8]+1, color_3[7:4], color_3[3:0]};
                                                color_4<= (state==SUCCESS)? color_4:{color_4[11:8]+1, color_4[7:4], color_4[3:0]};
                                          end
                      
                                2'b11   : begin color_1<=(state_count>4'b0000 & state != INIT)?color_1:{color_1[11:8], color_1[7:4]+1, color_1[3:0]-1}; 
                                                color_2<= (state_count>4'b0010 & state != INIT)? color_2: {color_2[11:8], color_2[7:4]+1, color_2[3:0]-1};
                                                color_3<= (state_count>4'b0101 & state != INIT)? color_3: {color_3[11:8], color_3[7:4]+1, color_3[3:0]-1};
                                                color_4<= (state==SUCCESS)? color_4:{color_4[11:8]-1, color_4[7:4], color_4[3:0]};
                                          end
                               
                         
                            endcase
                         clock_count <= 0;
                         end else clock_count <= clock_count + 1;
                         
                         
                         
                        end
                     
                   end
                   
                   
                  
 /////////////////////////////////////////////Game logic////////////////////////////////////////////////
                   always_ff @(posedge vclock_in) begin
                        if (reset_in) begin
                            state <= 4'b0000;
                            chosen_rand <= random;
                            state_count <= 4'b0000;
                            success <= 0;
                            fail <= 0;
                            {led_r, led_g, led_b} <= 3'b000;
                            
                        end 
                            
                        else if (vsync_prev & !vsync_in) begin
                            case(state)
                                INIT    :   begin chosen_rand <= random;
                                                  case(state_count) 
                                                        4'b0000  : begin light_1 <= lut_out; state_count <= state_count +1; state <= INIT; end
                                                        4'b0001  : begin light_2 <= lut_out; state_count <= state_count +1; state <= INIT; end
                                                        4'b0010  : begin light_3 <= lut_out; state_count <= state_count +1; state <= INIT;end
                                                        4'b0011  : begin light_4 <= lut_out; state_count <= 4'b0000; state <= FLASH_1;end
                                                   endcase   
                                            end
                                FLASH_1 :   begin state <= WAIT_FLASH1;
                                                  {led_r, led_g, led_b} <= light_1;
                                                  timer_start <= 1;
                                            end
                                WAIT_FLASH1  : begin timer_start <= 0;
                                                    state <= expired? ((state_count==4'b0000)? SEQ_1 : FLASH_2) : WAIT_FLASH1;
                                                    if(timer_count==12'b1) {led_r, led_g, led_b} <= 3'b000;
                                                end
                                SEQ_1   :   begin case(light_1) 
                                             3'b100   :   begin state <= (btnu)? ((state_count==0)? FLASH_1:SEQ_2):(btnr | btnd | btnl)?FAILED: SEQ_1; if(btnu) state_count <= state_count + 1;  end
                                             3'b010   :   begin state <= (btnr)? ((state_count==0)? FLASH_1:SEQ_2): (btnu | btnd | btnl)?FAILED: SEQ_1; if(btnr) state_count <= state_count +1;  end
                                             3'b001   :   begin state <= (btnd)? ((state_count==0)? FLASH_1:SEQ_2): (btnr | btnu | btnl)?FAILED: SEQ_1; if(btnd) state_count <= state_count + 1;  end
                                             3'b101   :   begin state <= (btnl)? ((state_count==0)? FLASH_1:SEQ_2): (btnr | btnd | btnu)?FAILED: SEQ_1; if(btnl) state_count <= state_count + 1;  end                   
                                            endcase end
                                FLASH_2 :   begin state <= WAIT_FLASH2;
                                                  {led_r, led_g, led_b} <= light_2;
                                                  timer_start <= 1;
                                            end
                                WAIT_FLASH2  : begin timer_start <= 0;
                                                    state <= expired? ((state_count==4'b0001 || state_count==4'b0010)? SEQ_2 : FLASH_3) : WAIT_FLASH2;
                                                    if(timer_count==12'b1) {led_r, led_g, led_b} <= 3'b000;
                                                end
                                SEQ_2   :   begin case(light_2) 
                                             3'b100   :   begin state <= (state_count==1)? SEQ_1 :(btnu1? ((state_count==2)? FLASH_1:SEQ_3):(btnl1 | btnr1 | btnd1)?FAILED: SEQ_2);
                                                                            if(btnu1) state_count <= state_count + 1;  end
                                             3'b010   :   begin state <= (state_count==1)?SEQ_1:(btnr1? ((state_count==2)? FLASH_1:SEQ_3): (btnl1 | btnu1 | btnd1)?FAILED: SEQ_2); 
                                                                            if(btnr1) state_count <= state_count + 1;  end
                                             3'b001   :   begin state <= (state_count==1)?SEQ_1:(btnd1? ((state_count==2)? FLASH_1:SEQ_3): (btnl1 | btnr1 | btnu1)?FAILED: SEQ_2); 
                                                                            if(btnd1) state_count <= state_count + 1;  end
                                             3'b101   :   begin state <= (state_count==1)?SEQ_1:(btnl1? ((state_count==2)? FLASH_1:SEQ_3): (btnu1 | btnr1 | btnd1)?FAILED: SEQ_2); 
                                                                            if(btnl1) state_count <= state_count + 1;  end                   
                                            endcase end
                                FLASH_3 :   begin state <= WAIT_FLASH3;
                                                  {led_r, led_g, led_b} <= light_3;
                                                  timer_start <= 1;
                                            end
                                WAIT_FLASH3  : begin timer_start <= 0;
                                                    state <= expired? ((state_count==4'b0011|| state_count==4'b0101)? SEQ_3 : FLASH_4) : WAIT_FLASH3;
                                                    if(timer_count==12'b1) {led_r, led_g, led_b} <= 3'b000;
                                                end
                                SEQ_3   :   begin case(light_3) 
                                             3'b100   :   begin state <= (state_count==3)? SEQ_1 :(btnu1? ((state_count==5)? FLASH_1:SEQ_4): (btnl1 | btnr1 | btnd1)?FAILED: SEQ_3); 
                                                            if(btnu1) state_count <= state_count + 1;  end
                                             3'b010   :   begin state <= (state_count==3)? SEQ_1 :(btnr1? ((state_count==5)? FLASH_1:SEQ_4): (btnl1 | btnu1 | btnd1)?FAILED: SEQ_3); 
                                                            if(btnr1) state_count <= state_count + 1;  end
                                             3'b001   :   begin state <= (state_count==3)? SEQ_1 :((btnd1)? ((state_count==5)? FLASH_1:SEQ_4):(btnl1 | btnr1 | btnu1)?FAILED: SEQ_3); 
                                                            if(btnd1) state_count <= state_count + 1;  end
                                             3'b101   :   begin state <= (state_count==3)? SEQ_1 :(btnl1? ((state_count==5)? FLASH_1:SEQ_4): (btnu1 | btnr1 | btnd1)?FAILED: SEQ_3); 
                                                            if(btnl1) state_count <= state_count + 1;  end                   
                                            endcase end
                                FLASH_4 :   begin state <= WAIT_FLASH4;
                                                  {led_r, led_g, led_b} <= light_4;
                                                  timer_start <= 1;
                                            end
                                WAIT_FLASH4  : begin timer_start <= 0;
                                                    state <= expired? SEQ_4 : WAIT_FLASH4;
                                                    if(timer_count==12'b1) {led_r, led_g, led_b} <= 3'b000;
                                                end
                                SEQ_4   :   begin case(light_4) 
                                             3'b100   :   begin state <= (state_count==6)?SEQ_1:((btnu1)? SUCCESS:(btnd1 | btnl1 | btnr1)?FAILED: SEQ_4);   end
                                             3'b010   :   begin state <= (state_count==6)?SEQ_1:((btnr1)? SUCCESS: (btnd1 | btnl1 | btnu1)?FAILED: SEQ_4);   end
                                             3'b001   :   begin state <= (state_count==6)?SEQ_1:((btnd1)? SUCCESS: (btnu1 | btnl1 | btnr1)?FAILED: SEQ_4);   end
                                             3'b101   :   begin state <= (state_count==6)?SEQ_1:((btnl1)? SUCCESS: (btnd1 | btnu1 | btnr1)?FAILED: SEQ_4);   end                   
                                            endcase end
                               SUCCESS  :   begin {led_r, led_g, led_b} <= 3'b111; success <=1; end
                               
                               FAILED   :   fail <=1;
                               
                             
                             
                             
                             endcase
                             prev_btnu <= btnu;
                             prev_btnd <= btnd;
                             prev_btnr <= btnr;
                             prev_btnl <= btnl;                 
                        
                        end
                  end
                                                    
endmodule

/////////////////////////////////LUT for Minigame 2////////////////////////////
module Lut_mg2(     
                        input [1:0] rn,
                        output logic [2:0] led_col                 
);

always_comb begin
        case(rn)
            2'b00       :   begin led_col = 3'b100 ; end
            2'b01       :   begin led_col = 3'b010 ; end
            2'b10       :  begin led_col = 3'b001 ; end
            2'b11       :   begin led_col = 3'b101 ; end
        endcase
end

endmodule


