`timescale 1ns / 1ps

module i2c_master

    (
    input clk,reset,
    input [7:0] data_in,
    input [15:0] divisor, // which divides the bit period to 4 dvsr = Fsys/4Fi2c
    input [6:0] address_slave,
    input [2:0] order,
    input wr_enable,
    inout tri sda,
    output tri scl,
    output finish,
    output ready , done 
  
    );
    
    // the orders 
    localparam START   = 3'b000;
    localparam WR      = 3'b001;
    localparam RD      = 3'b010;
    localparam STOP    = 3'b011;
    localparam RESTART = 3'b100;
    
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
    localparam data1_write      = 5'd9;
    localparam data2_write      = 5'd10;
    localparam data3_write      = 5'd11;
    localparam data4_write      = 5'd12;
    localparam data_end_write   = 5'd13;
    localparam stop1            = 5'd14;
    localparam stop2            = 5'd15;
    localparam data1_read       = 5'd16;
    localparam data2_read       = 5'd17;
    localparam data3_read       = 5'd18;
    localparam data4_read       = 5'd19;
    localparam data_end_read    = 5'd20;
    localparam restart          = 5'd21;
      


    
    // declarations
    
     reg [4:0]  state_reg, state_next;  // to hold current or next value of state
     reg [15:0] count_reg, count_next; //counter register for time
     wire [15:0] quarter, half;  // timing control quarter for data bits and half for stop and start
     reg [8:0]  tx_reg, tx_next; //to hold data to be transimtted 
     reg [8:0]  rx_reg, rx_next; // to hold data recieved from the slave
     reg [2:0]  order_reg, order_next; // to hold the order
     reg [3:0]  bit_reg, bit_next; // to count the number of bits transmitted or recieved 
     reg [7:0] data_received;
     reg sda_next, scl_next, sda_reg, scl_reg, data_phase;
     reg done_tick_i, ready_i;
     wire into_master;
     reg wr_bit;
  
     
     always @(posedge clk or posedge reset)
        begin
           if (reset) begin
              sda_reg <= 1'b1;
              scl_reg <= 1'b1;
           end
           else begin
              sda_reg <= sda_next;
              scl_reg <= scl_next;
           end
        end
        
        assign scl = (scl_reg) ? 1'b1 : 1'b0; 
      assign into_master = (data_phase && order_reg==RD && bit_reg<8 && state_reg>8) ||  
                         (data_phase && order_reg==WR && bit_reg==8);  
                         
      assign sda =  sda_reg; 
     
      
      always @(posedge clk , posedge reset)
      begin
            if (reset) begin
               state_reg <= idle;
               count_reg     <= 0;
               bit_reg   <= 0;
               order_reg   <= 0;
               tx_reg    <= 0;
               rx_reg    <= 0;
               data_received <=0;
            end
            else begin
               state_reg <= state_next;
               count_reg     <= count_next;
               bit_reg   <= bit_next;
               order_reg   <= order_next;
               tx_reg    <= tx_next;
               rx_reg    <= rx_next;
            end
      end
              
        assign quarter = divisor;
       assign half = {quarter [14:0] , 1'b0}; // hald = quarter * 2
                      
       always@(*)
       begin
       state_next = state_reg;
       count_next = count_reg +1;
       bit_next = bit_reg;
       tx_next = tx_reg;
       rx_next = rx_reg;
       order_next = order_reg;
       done_tick_i = 1'b0;
       ready_i = 1'b0;
       scl_next = 1'b1;
       sda_next = 1'b1;
       data_phase = 1'b0;
       
       case (state_reg)
       idle: begin
       ready_i=1'b1;
       if (wr_enable && order==START) begin  
           state_next = start1;
           count_next = 0;
           end
           end
           start1: begin           
                   sda_next = 1'b0;
                   if (count_reg==half) begin
                      count_next = 0;
                      state_next = start2;
               end
               end
             start2: begin
             sda_next = 1'b0;
             scl_next = 1'b0;
             if (count_reg==quarter) begin
                count_next = 0;
                state_next = hold;
             end
             end  
              hold: begin            
            ready_i = 1'b1;
            sda_next = 1'b0;
            scl_next = 1'b0;
            if (wr_enable) begin
               order_next = order;
               count_next = 0;
               case (order) 
                  RESTART, START:   
                     state_next = restart;
                  STOP:                 
                     state_next = stop1;
                  default: begin 
                  if(order==RD)
                  wr_bit=1;
                  else if(order==WR)
                  wr_bit=0;           
                     bit_next   = 0;
                     state_next = addr1;
                      tx_next    = {1'b0 , address_slave, wr_bit};  
                  end               
               endcase
            end
         end 
         addr1: begin
            sda_next   = tx_reg[7];
            scl_next   = 1'b0;
            data_phase = 1'b1;
            if (count_reg==quarter) begin
               count_next = 0;
               state_next = addr2;
            end
         end
         addr2: begin
            sda_next   = tx_reg[7];
            data_phase = 1'b1;
            if (count_reg==quarter) begin
               count_next = 0;
               state_next = addr3;
            end
         end
        addr3: begin
            sda_next   = tx_reg[7];
            data_phase = 1'b1;
            if (count_reg==quarter) begin
               count_next = 0;
               state_next = addr4;
            end
         end
         addr4: begin
            sda_next   = tx_reg[7];
            scl_next   = 1'b0;
            data_phase = 1'b1;
            if (count_reg==half) begin
               count_next = 0;
               if (bit_reg==7) begin
                  state_next = addr_end; 
                tx_next    = { data_in,1'b0 }; 
               end else begin
                  tx_next  = {tx_reg[7:0],1'b0};
                  bit_next = bit_reg+1;
                  state_next = addr1;
                  
               end
            end
         end
         addr_end: begin
     
            sda_next=1'bz;
            if (count_reg==half) begin
               count_next = 0;
               bit_next   = 0;
               if(wr_bit==0)
               state_next = data1_write;
               else if(wr_bit==1'b1) begin
               state_next = data1_read;
               rx_next=0;
               end
            end
         end
         data1_write: begin
         sda_next = tx_reg[8]; 
         scl_next = 1'b0;   
         data_phase = 1'b1; 
         if (count_reg==quarter) begin 
            count_next     = 0;  
            state_next = data2_write; 
           end 
           end
           
           data2_write: begin
           sda_next = tx_reg[8];
           data_phase = 1'b1; 
           if (count_reg==quarter) begin
              count_next = 0;
              state_next = data3_write;
          
               end
               end
               
               data3_write: begin
               sda_next = tx_reg[8]; 
               data_phase = 1'b1; 
               if (count_reg==quarter) begin
                  count_next     = 0;
                  state_next = data4_write;
               end
            end
            
            data4_write: begin
                    sda_next = tx_reg[8];
                    scl_next = 1'b0;
                    data_phase = 1'b1;
                    if (count_reg==quarter) begin
                       count_next = 0;
                       if (bit_reg==7) begin     
                          state_next = data_end_write; 
                          done_tick_i = 1'b1;
                       end 
                       else begin
                          tx_next = {tx_reg[7:0], 1'b0};
                          bit_next = bit_reg + 1;
                          state_next = data1_write;
                       end
                    end
              end
              data_end_write: begin
              sda_next = 1'b0;
              scl_next = 1'b0;
              if (count_reg==half) begin
                 count_next = 0;
                 state_next = stop1;
              end
           end
         data1_read: begin
         sda_next=1'bz;
         sda_reg=1'bz;
         rx_next[0] = sda;
         scl_next = 1'b0;   
         data_phase = 1'b1; 
         if (count_reg==quarter) begin 
            count_next     = 0;  
            state_next = data2_read; 
           end 
           end

           data2_read:begin
            sda_next=1'bz;
            sda_reg=1'bz;
            rx_next[0] = sda;
            scl_next = 1'b1;  
             data_phase = 1'b1; 
             if (count_reg==quarter) begin 
            count_next     = 0;  
            state_next = data3_read; 
           end 
           end


         data3_read: begin
          sda_next=1'bz;
          sda_reg=1'bz;
         rx_next[0] = sda;
         data_phase = 1'b1; 
               if (count_reg==quarter) begin
                  count_next     = 0;
                  state_next = data4_read;
           end
            end
            data4_read: begin
                    sda_next=1'bz;
                    sda_reg=1'bz;
                    scl_next = 1'b0;
                    data_phase = 1'b1;
                    if (count_reg==half) begin
                       count_next = 0;
                       if (bit_reg==7) begin   
                         data_received =rx_reg[7:0]; 
                          state_next = data_end_read; 
                          done_tick_i = 1'b1;
                       end 
                       else begin
                          
                          bit_next = bit_reg + 1;
                          state_next = data1_read;
                          rx_next = {rx_reg[7:0],1'b0};
                  end
                  end
                  end
            data_end_read: begin
              sda_next = 1'bz;
              scl_next = 1'b0;
              done_tick_i=1;
              if (count_reg==half) begin
                 count_next = 0;
                 state_next = stop1;     
                       end
                    end
              

           restart:               
           if (count_reg==half) begin
              count_next= 0;
              state_next = start1;
           end
        stop1: begin           
           sda_next = 1'b0;
           if (count_reg==half) begin
              count_next = 0;
              state_next = stop2;
           end
        end
        stop2:                
           if (count_reg==half) begin
             done_tick_i=1;
              state_next = idle;
              end

            endcase
      
       end
       assign finish =  ( done_tick_i && state_reg==stop2 )  ; 
       assign done = done_tick_i;
       assign ready = ready_i;            

endmodule