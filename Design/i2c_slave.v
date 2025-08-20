`timescale 1ns / 1ps

module i2c_slave #(parameter ADDRESS= 7'b1010001)
    (
    input clk,
    input reset,
    input [15:0] divisor,
    input [7:0] data_in_slave,
    input scl,
    inout tri  sda,
    output [7:0] data_out_slave
    );
    
          
       // the states
       localparam idle             = 5'd0;
       localparam hold             = 5'd1;
       localparam start1           = 5'd2;
       localparam start2           = 5'd3;
       localparam addr1            = 5'd4;
       localparam addr2            = 5'd5;
       localparam addr3            = 5'd6;
       localparam addr4            = 5'd7;
       localparam addr_end         = 5'd8;
       localparam data1_read       = 5'd9;
       localparam data2_read       = 5'd10;
       localparam data3_read       = 5'd11;
       localparam data4_read       = 5'd12;
       localparam data_read_end    = 5'd13;
       localparam data1_write      = 5'd14;
       localparam data2_write      = 5'd15;
       localparam data3_write      = 5'd16;
       localparam data4_write      = 5'd17;
       localparam data_write_end   = 5'd18;
       localparam stop1            = 5'd19;
       localparam stop2            = 5'd20;

       
           reg [4:0]  state_reg_slave , state_next_slave;
           reg [7:0]  tx_reg_slave, tx_next_slave; //to hold data to be transimtted 
           reg [7:0]  rx_reg_slave, rx_next_slave; // to hold data recieved from the master
           reg [3:0]  bit_reg_slave, bit_next_slave; // to count the number of bits transmitted or recieved 
           reg done_tick_i, ready_i;
           reg wr_bit;
           reg data_phase;
           reg [15:0] count_reg_slave, count_next_slave; //counter register for time
           reg sda_next , sda_reg;
           wire [15:0] quarter, half;  // timing control quarter for data bits and half for stop and start
           reg [6:0] address_sent;

           
              always @(posedge clk or posedge reset)
                 begin
                    if (reset) begin
                      sda_reg <= 1'bz;
                    end
                    else begin
                       sda_reg <= sda_next;
                    end
                 end
         
           assign sda =  sda_reg;
           assign quarter = divisor;
           assign half = {quarter [14:0] , 1'b0}; 
         always @(posedge clk , posedge reset)
             begin
                   if (reset) begin
                      state_reg_slave <= idle;
                      count_reg_slave     <= 0;
                      bit_reg_slave   <= 0;
                      address_sent <=0;
                      tx_reg_slave    <= 0;
                      rx_reg_slave    <= 0;
                   end
                   else begin
                      state_reg_slave <= state_next_slave;
                      count_reg_slave     <= count_next_slave;
                      bit_reg_slave   <= bit_next_slave;
                      tx_reg_slave    <= tx_next_slave;
                      rx_reg_slave    <= rx_next_slave;
                   end
             end
               
                always@(*)
                   begin
                   state_next_slave = state_reg_slave;
                   count_next_slave = count_next_slave+1; 
                   bit_next_slave = bit_reg_slave;
                   tx_next_slave = tx_reg_slave;
                   rx_next_slave = rx_reg_slave;
                   done_tick_i = 1'b0;
                   ready_i = 1'b0;
                   data_phase = 1'b0;
                   
                   case (state_reg_slave)
                   idle: begin
                   sda_next <=1'bz;
                     if (sda==0 && scl ==1)begin  
                       state_next_slave  = start1;
                       count_next_slave  = 0;
                     end
                   end
                   
                   start1: begin
                     if (scl == 1'b0) begin                
                       state_next_slave  = start2;
                       count_next_slave  = 0;
                     end
                   end
                   
                   start2: begin
                     bit_next_slave      = 0;
                     rx_next_slave       = 0;
                     if (count_reg_slave == quarter) begin
                       count_next_slave  = 0;
                       state_next_slave  = addr1;
                     end
                   end
                   
                   addr1: begin
                     if (count_reg_slave == quarter) begin
                       count_next_slave  = 0;
                       state_next_slave  = addr2;
                     end
                   end
                 
                   addr2: begin
                     if (count_reg_slave == quarter) begin
                       count_next_slave  = 0;
                       state_next_slave  = addr3;
                     end
                   end
                   
                   addr3: begin
                     if (count_reg_slave == quarter) begin
                       count_next_slave  = 0;
                       if (scl == 1'b1) begin
                         rx_next_slave   = {rx_reg_slave[6:0], sda};
                       end
                       state_next_slave  = addr4;
                     end
                   end
                   
                   addr4: begin
                     if (count_reg_slave == half) begin
                       count_next_slave  = 0;
                       if (bit_reg_slave == 7) begin
                         state_next_slave = addr_end;        
                         address_sent = rx_reg_slave[7:1];        
                       end else begin
                         bit_next_slave   = bit_reg_slave + 1;
                         state_next_slave = addr1;
                       end
                     end
                   end
                   
                   addr_end: begin
                     if (rx_reg_slave[7:1] == ADDRESS) begin
                       sda_next = 1'b1;
                     end else begin
                       sda_next = 1'bz;  
                       state_next_slave = idle;
                     end
                   
                     if (count_reg_slave == half) begin
                       count_next_slave  = 0;
                       bit_next_slave    = 0;
                       if (rx_reg_slave[0] == 1'b0) begin
                       end else begin
                         state_next_slave = data1_write;
                         tx_next_slave =data_in_slave;
                       end
                       sda_next = 1'bz;
                     end
                   end

                     data1_write: begin
                     sda_next = tx_reg_slave[7]; 
                    
                     data_phase = 1'b1; 
                     if (count_reg_slave==quarter) begin 
                        count_next_slave     = 0;  
                        state_next_slave = data2_write; 
                       end 
                       end
                       
                       data2_write: begin
                       sda_next = tx_reg_slave[7];
                       data_phase = 1'b1; 
                       if (count_reg_slave==quarter) begin
                          count_next_slave = 0;
                          state_next_slave = data3_write;
                           end
                           end
                           
                           data3_write: begin
                           sda_next = tx_reg_slave[7]; 
                           data_phase = 1'b1; 
                           if (count_reg_slave==quarter) begin
                              count_next_slave     = 0;
                              state_next_slave = data4_write;
                           end
                        end
                        
                        data4_write: begin
                                sda_next = tx_reg_slave[7];
                                data_phase = 1'b1;
                                if (count_reg_slave==half) begin
                                   count_next_slave = 0;
                                   if (bit_reg_slave==7) begin     
                                      state_next_slave = data_write_end; 
                                   end 
                                   else begin
                                      tx_next_slave = {tx_reg_slave[7:0], 1'b0};
                                      bit_next_slave = bit_reg_slave + 1;
                                      state_next_slave = data1_write;
                                   end
                                end
                          end
                          data_write_end: begin
                          sda_next = 1'b1;

                          if (count_reg_slave==half) begin
                             count_next_slave = 0;
                             state_next_slave = stop1;
                          end
                       end
                     data1_read: begin
                     sda_next=1'bz;
                     sda_reg=1'bz;
                    
                     data_phase = 1'b1; 
                     if (count_reg_slave==quarter) begin 
                        count_next_slave     = 0;  
                        state_next_slave = data2_read; 
                       end 
                       end
            
                       data2_read:begin
                        sda_next=1'bz;
                        sda_reg=1'bz;
                        rx_next_slave[7-bit_reg_slave] = sda;
                         data_phase = 1'b1; 
                         if (count_reg_slave==quarter) begin 
                        count_next_slave     = 0;  
                        state_next_slave = data3_read; 
                       end 
                       end
            
            
                     data3_read: begin
                      sda_next=1'bz;
                      sda_reg=1'bz;
                     rx_next_slave[7-bit_reg_slave] = sda;
                     data_phase = 1'b1; 
                           if (count_reg_slave==quarter) begin
                              count_next_slave     = 0;
                              state_next_slave = data4_read;
                       end
                        end
                        data4_read: begin
                                sda_next=1'bz;
                                sda_reg=1'bz;
                                rx_next_slave[7-bit_reg_slave] = sda;
                              
                                data_phase = 1'b1;
                                if (count_reg_slave==quarter) begin
                                   count_next_slave = 0;
                                   if (bit_reg_slave==8) begin     
                                      state_next_slave = data_read_end; 
       
             
                                   end 
                                   else begin
                                      bit_next_slave = bit_reg_slave + 1;
                                      state_next_slave = data1_read;
                              end
                              end
                              end
                        data_read_end: begin
                          sda_next = 1;
                          if (count_reg_slave==half) begin
                             count_next_slave = 0;
                             state_next_slave = stop1;     
                                   end
                                end
                          
                       
                    stop1: begin           
                       sda_next = 1'bz;
                       if (count_reg_slave==half) begin
                          count_next_slave = 0;
                          state_next_slave = stop2;
                       end
                    end
                    stop2:                
                       if (count_reg_slave==half) 
                          state_next_slave = idle;
            
                      endcase
                  
                  end
               
                         
      endmodule