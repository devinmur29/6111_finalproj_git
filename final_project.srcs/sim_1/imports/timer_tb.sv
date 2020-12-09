`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////

module timer_tb;

   // Inputs
   logic clock;
   logic start_timer;
   logic [11:0] value;

   // Outputs
 

   logic expired_pulse;
   logic counting;
   logic one_hz;
   logic [11:0] count_out;
   logic [3:0] minutes;
   logic [3:0] tens;
   logic [3:0] ones;
   logic [3:0] tens_reg;
   

   // Instantiate the Unit Under Test (UUT)
   //one_hz_period changed to 4 cycles so simulations don't take forever.
   timer #(.ONE_HZ_PERIOD(8)) uut (
      .clock(clock), 
      .start_timer(start_timer), 
      .value(value), 
      .counting(counting), 
      .expired_pulse(expired_pulse), 
      .one_hz(one_hz), 
      .count_out(count_out),
      .ones(ones),
      .tens(tens),
      .minutes(minutes),
      .tens_reg(tens_reg)
   );

   always #5 clock = !clock;
   
   initial begin
      // Initialize Inputs
      clock = 0;
      start_timer = 0;
      value = 0;

      // Wait 100 ns for global reset to finish
      #100;
      #15;
      value = 150;
      #15;
      start_timer =1;
      #10;
      start_timer = 0;
      #65 start_timer =1;
      #10 start_timer = 0;
      #300;
      start_timer =1;
      #10;
      start_timer = 0;
      #300;
      value = 0;
      #5
      start_timer =1;
      #10;
      start_timer = 0;

   end
      
endmodule
