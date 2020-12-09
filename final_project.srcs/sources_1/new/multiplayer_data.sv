`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2020 05:23:26 PM
// Design Name: 
// Module Name: multiplayer_data
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


module multiplayer_data (
    input vclock_in,        // 65MHz clock
    input reset_in,         // 1 to initialize module
    input uart_in,          // UART input
    input [2:0] i,  
    input [1:0] strike_count, 
    input btnc,
    input game_state,   
        
    output logic [31:0] data_out,
    output logic uart_out
    );

    

   
    logic uart_in_sync;
   
    // inputs must be synchronzied
    synchronize my_synchronizer(.clk(vclock_in), .in(uart_in), .out(uart_in_sync));
   
    parameter STATE_WAITING = 2'b01;
    parameter STATE_READING = 2'b10;
    parameter UART_IDLE_THRESHOLD = 50_000; // threshold for UART begin HIGH and we can start reading data
    
    logic[20:0] transmit_count;

    logic [1:0] state;               // FSM state
    logic [31:0] counter;            // counts bits of serial
    logic [15:0] serial_counter;     // counts bytes of serial data received
    logic serial_rx_reset;
    logic [47:0] serial_data;        // buffer for rx
    logic [7:0] rx_data;             // single byte of rx
    logic rx_valid;                  // high on each byte read
    
    logic       tx_trigger;
    logic [7:0] tx_data;
    
    serial_rx rx(.clk_in(vclock_in), .rst_in(serial_rx_reset), .data_in(uart_in_sync), .data_out(rx_data), .valid_out(rx_valid));
    serial_tx tx(.clk_in(vclock_in), .rst_in(reset_in), .trigger_in(tx_trigger), .val_in(tx_data), .data_out(uart_out));

   
    logic [2:0] last_i;
    logic [1:0] last_strike_count;
    logic prev_btnc;

    // pushbutton FSM
    // When we push a button, we should update the button counter
    always_ff @(posedge vclock_in) begin
        if (reset_in) begin
            tx_trigger <= 0;
            last_i <= 0;
            last_strike_count <=0;
            prev_btnc <= 0;
            transmit_count <= 0;
        end else begin
         
            if (tx_trigger) tx_trigger <= 0;
            last_i <= i;
            last_strike_count <= strike_count;
            prev_btnc <= btnc;
            if (last_i!=i | last_strike_count!=strike_count |(btnc & !prev_btnc)) begin
                tx_data <= {2'd0,btnc,strike_count,i};
                tx_trigger <= 1;
            end
        end
    end

    // UART reading; should update LED lights with how many modules the OTHER person has completed
    always_ff @(posedge vclock_in) begin
        if (serial_rx_reset) serial_rx_reset <= 0;
        
        if (reset_in) begin  // initialize all variables
           state <= STATE_WAITING;
           counter <= 0;
           serial_rx_reset <= 0;
           serial_data <= 0;
        end else begin
            if (state == STATE_WAITING) begin
                if (counter > UART_IDLE_THRESHOLD) begin // reset serial reader module
                    state <= STATE_READING;
                    serial_rx_reset <= 1;
                //                   serial_counter <= 16'd6; // need 6 bytes of data
                    serial_counter <= 16'd1; // need 1 bytes of data
                    counter <= 0;
                end else if (uart_in_sync) begin
                    counter <= counter + 1;
                end else begin
                    counter <= 0;
                end
            end else begin   // state == READING
                if (rx_valid) begin      // take in eacy byte from serial
                    serial_data <= {serial_data[39:0], rx_data};
            
                    if (serial_counter == 1) begin
                        state <= STATE_WAITING;
//                        data_out <= {24'd0, serial_data[7:0]};
                        data_out <= rx_data;
                    end else begin
                        serial_counter <= serial_counter - 1;
                    end
                end
            end
        end
    end
endmodule


////////////////////////Synchronizer/////////////////////////////////
module synchronize #(parameter NSYNC = 3)  // number of sync flops.  must be >= 2
                   (input clk,in,
                    output logic out);

  logic [NSYNC-2:0] sync;

  always_ff @ (posedge clk) begin
    {out,sync} <= {sync[NSYNC-2:0],in};
  end
endmodule
