module timer(clock, start_timer,  value, counting, 
	 expired_pulse, one_hz, count_out, ones, tens, minutes);

	//use parameter below for generating one_hz_enable signal
	parameter ONE_HZ_PERIOD = 65_000_000;

    input clock, start_timer;
    input [11:0] value;
    output logic counting; 
    output logic expired_pulse; 
    output logic one_hz;
    output logic [11:0] count_out;
    output logic [11:0] ones;
    output logic [11:0] tens;
    output logic [3:0] minutes;
    
//    always_comb begin
//        minutes = count_out/60;
//        tens = (count_out-minutes*60)/10;
//        ones = (count_out-minutes*60-tens*10);
//    end
    
    

    // Verilog
    
    //keep track of count for one_hz
    logic [26:0] clock_count;
    logic [11:0] tens_reg;
    
    always_ff @(posedge clock) begin
        minutes <= count_out/60;
        tens_reg <= (count_out-minutes*60);
        tens <= tens_reg/10;
        ones <= (count_out-minutes*60-tens*10);
    end 
    
    
    always_ff @(posedge clock) begin
        if(start_timer) begin //set initial vals
            count_out <= value;
            one_hz <= 0;
            counting <= 1;
            expired_pulse <= 0;
            clock_count <= 0;
         end else begin
          if (counting) begin 
          //If I'm couting and the count_out is 0, expire the pulse and stop counting
            
            if(count_out == 12'b0) begin
                counting <= 0;
                expired_pulse <= 1;
            end
            if(one_hz) begin
            //If a second has passed, decrement count and reset the one_hz signal
                count_out <= count_out -1;
                one_hz <= 0;
            end
   
            
            end //else expired_pulse <= 0; //if im not counting restore expired pulse to 0
            if(clock_count == ONE_HZ_PERIOD-1) begin //logic to control the one_hz signal
                one_hz <= 1;
                clock_count <= 0;
            end else begin
             clock_count <= clock_count + 1;
             if (!counting) one_hz <= 0;
             end
         end
     end

endmodule
