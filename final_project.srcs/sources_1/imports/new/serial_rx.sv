`timescale 1ns / 1ps

module serial_rx(input                clk_in,
                 input                rst_in,
                 input                data_in,
                 output logic [7:0]   data_out,
                 output logic         valid_out);
    parameter   DIVISOR = 800;    // 6768 is approx. 9600 baud at 65MHz
    
    logic [15:0] counter;  // counts up to DIVISOR, then reads a bit
    logic data_in_sync;         // data_in but synchronized
    
    logic supersampler_reset;   // we need to supersample 16x every bit
    logic supersampler_output;
    logic supersampler_valid;

    logic reading;              // are we currently reading?
    logic [8:0] read_buffer;    // start, 8 data; stop bit should be in supersampler_output

    // data needs to be synchronized
    synchronize synchronizer(.clk(clk_in), .in(data_in), .out(data_in_sync));

    supersampler supersample(.clk_in(clk_in), .rst_in(supersampler_reset), .divisor_in(DIVISOR), .data_in(data_in_sync),
                             .data_out(supersampler_output), .valid_out(supersampler_valid));

    always @(posedge clk_in) begin
        if (valid_out) valid_out <= 0;
        if (supersampler_reset) supersampler_reset <= 0;
        
        if (rst_in) begin   // initialize vars
            reading <= 0;
            supersampler_reset <= 1;
            counter <= 0;
            data_out <= 0;
            valid_out <= 0;
            read_buffer <= 0;
        end else begin
            if (reading) begin  // take in 10 bits
                if (supersampler_valid) begin
                    counter <= counter - 1;

                    if (counter == 1) begin
                        // check validity of packet
                        if (read_buffer[8] == 0 && supersampler_output == 1) begin
                            valid_out <= 1;
                            data_out <= {<<{ read_buffer[7:0] }};   // if it's good, spit it out
                        end

                        reading <= 0;
                    end else begin
                        read_buffer <= {read_buffer[7:0], supersampler_output};
                    end
                end
            end else if (!data_in_sync) begin   // begin reading on falling edge
                reading <= 1;
                counter <= 16'd10;
                supersampler_reset <= 1;
            end
        end
    end              
endmodule

module supersampler #(parameter SAMPLES = 16)
                    (input        clk_in,
                    input         rst_in,
                    input [15:0]  divisor_in,
                    input         data_in,
                    output logic  data_out,
                    output logic  valid_out);
    logic [15:0] counter;
    logic [15:0] buffer_counter;
    logic [15:0]  buffer;
    
    localparam UART_DIVISOR = 50;    // divisor for UART timing
    
    majority16 majority(.data_in(buffer), .majority_out(data_out));

    always_ff @(posedge clk_in) begin
        if (valid_out) valid_out <= 0;  // make sure valid is only high for one clock cycle

        if (rst_in) begin   // reset values
            valid_out <= 1'b0;
            counter <= 8'd1;
            buffer_counter <= 8'd1;
            buffer <= 0;
        end else begin
            if (counter >= UART_DIVISOR) begin
                counter <= 1;   // read in a bit
                if (buffer_counter >= SAMPLES) begin
                    buffer_counter <= 1;
                    valid_out <= 1'b1;
                end else begin
                    buffer = {buffer[14:0], data_in};
                    buffer_counter <= buffer_counter + 1;   // return the correct value
                end
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule

// outputs majority vote of data_in
module majority16(
    input [15:0]  data_in,
    output logic  majority_out
    );
    
    assign majority_out = (data_in[0] + data_in[1] + data_in[2] + data_in[3] + 
                           data_in[4] + data_in[5] + data_in[6] + data_in[7] +
                           data_in[8] + data_in[9] + data_in[10] + data_in[11] + 
                           data_in[12] + data_in[13] + data_in[14] + data_in[15]) >= 8;
endmodule