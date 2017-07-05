`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: XRD
// Engineer: Rakesh Gehalot
// 
// Create Date:    15:31:23 11/04/2015 
// Design Name: 
// Module Name:    AC97ctr 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module AC97ctr(clock, reset, sdout, synch, bitclk, rstbt, led, bit_count);

	parameter rstlow_time = 7'd500; //150 clock cycles
	parameter frame0 = {256'h0};
	parameter frame1 = {256'h0};
	parameter frame2 = {16'hF800, 20'h02000, 20'h00000, 20'hFFFAA, 20'hFFFFF, 160'h0};
	parameter frame3 = {16'hF800, 20'h04000, 20'h00000, 20'hFFFAA, 20'hFFFFF, 160'h0};
	parameter frame4 = {16'hF800, 20'h06000, 20'h00000, 20'hFFFFF, 20'hFAAFF, 160'h0};
	

   integer rstlow;
   
	input clock, rstbt;
   output reset, bit_count;
   output sdout;
   output synch;
   input bitclk;
   output led;
	reg led;
   reg reset;
   reg sdout;
   reg synch;
   reg [3:0]  frcount;
   reg [0:7] bit_count;
	
   reg [0:255] frame;
   reg [19:0] pcm_data;
	reg [5:0] index;


initial 
		begin
		led=0;
		pcm_data=0;
		synch = 0;
		sdout = 0;
      rstlow = 0;
      reset = 1'b0;
      bit_count = 8'h00;
		frcount = 0;
		frame  = {16'hF800, 20'hAAAAA, 20'h00000, 20'hFFFFF, 20'hFFFFF, 160'h0};
		index = 0;
      
		end


always@(posedge clock) 		//reseting codec first time if reset button is presssed
		begin 
			if(rstbt)
				begin
				rstlow = 0;
				reset = 0;
				led=1;
				end
			else if (rstlow == rstlow_time)
				begin
				reset = 1;
				rstlow = rstlow_time;
				end
			else
				rstlow = rstlow + 1'd1;
		end	



always @(posedge bitclk) 
      begin
				if (reset == 0)
					frcount <= 0;
					
		
				if(bit_count == 255 && frcount == 5)
					begin
				
					frame <= {16'hF800, 20'h0A0A0, 20'h00000, pcm_data, pcm_data, 160'h0};
					frcount <= 5;
					index <= index+1;
					end
				if(bit_count == 255 && frcount < 5)
					frcount <= frcount+1;
				if(bit_count == 255 && frcount == 0)
					frame <= frame0;
				else if(bit_count == 255 && frcount == 1)
					frame <= frame1;	
				else if(bit_count == 255 && frcount == 2)
					frame <= frame2;	
				else if(bit_count == 255 && frcount == 3)
					frame <= frame3;
				else if(bit_count == 255 && frcount == 4)
					frame <= frame4;	
				
				
		
		end		
		
   
	
   
	
always @(posedge bitclk) 
      begin 
				if (bit_count == 0)
				synch <= 1'b1;
				if (bit_count == 16)
				synch <= 1'b0;
				sdout <= frame[bit_count];
				if(reset==0)
				begin
				bit_count <= 0;
				sdout <= 0;
				end
				else
				bit_count <= bit_count+1;
		end		

