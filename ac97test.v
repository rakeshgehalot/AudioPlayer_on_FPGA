`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:        rakesh
// Create Date:     19:29:04 04/17/2011  
// Module Name:     ac97test 
// Project Name:    AC-97 Controller Test
// Description:     Top Module for AC-97 controller test project.
//////////////////////////////////////////////////////////////////////////////////
module ac97test(
	input CCLK,
	input RST,
	input BITCLK,
	
	output AUDSDO,
	output AUDSYNC,
	output AUDRST,
	input ap,
	output reg ut
    );

	wire ready, frame_done, AUD_SDO, AUD_SYNC, AUD_RST, reset, CLKFX_OUT;
	wire [7:0] cmd_addr;
	wire [15:0] cmd_data;
	wire [19:0] leftadc, rightadc, reg_status, status_data; 
	wire [19:0] leftdac, rightdac;
	
	assign AUDSDO = AUD_SDO;
	assign AUDSYNC = AUD_SYNC;
	assign AUDRST = AUD_RST;
	
 always
 begin 
 if(ap==1)
 ut<=1;
 end
 
 
	s6ac97 M0(CCLK, RST, cmd_vd, left_vd, right_vd, BITCLK,  AUD_SDO, AUD_SYNC,
			 AUD_RST, leftdac, rightdac, cmd_addr, cmd_data, ready, frame_done, leftadc,
			 rightadc, reg_status, status_data);
	genac97 M1(CCLK, RST, ready, frame_done, leftadc, rightadc, reg_status, status_data,
			  cmd_vd, left_vd, right_vd, leftdac, rightdac, cmd_addr, cmd_data);
	
endmodule




//////////////////////////////////////////////////////////////////////////////////
// Engineer:       John Ruddy
// Create Date:    20:25:25 04/16/2011  
// Module Name:    genac97  
// 
// Description: Test module for AC97 controller
//////////////////////////////////////////////////////////////////////////////////
module genac97(
		input CCLK,
		input rst,
		input ready,
		input frame_done,
		input [19:0] leftadc,
		input [19:0] rightadc,
		input [19:0] reg_status,
		input [19:0] status_data,
		output reg cmd_vd,
		output reg left_vd,
		output reg right_vd,
		output reg [19:0] leftdac,
		output reg [19:0] rightdac,
		output reg [7:0] cmd_addr,
		output reg [15:0] cmd_data
    );

	reg set;
	reg [4:0] state;
	//reg rst = 0;
	
	
	always@(posedge CCLK) begin
		if(rst) begin
			//reset registers
			state = 0;
			cmd_vd = 0;
			left_vd = 0;
			right_vd = 0;
			leftdac = 0;
			rightdac = 0;
			cmd_addr = 0;
			cmd_data = 0;
			set = 0;
			//rst = 1;
		end
		else begin
			case(state)
				0:begin //Init State
					//Check codec status after reset or power-on
					if(ready) begin
						cmd_addr = 8'h80 + 8'h26;//read + addr
						cmd_vd = 1;
						if(status_data[7:4] == 4'hF)//status = ready
							state = 1;
					end
					else
						state = 0;
				end
				1:begin //master volume
					if(ready) begin
						cmd_addr = 8'h02;
						cmd_data = 16'h0000;
						set = 1;
					end
					else
						state = 1;
					if(frame_done && set) begin
						state = 2;
						set = 0;
					end
				end
				2:begin //Line-in gain
					if(ready) begin
						cmd_addr = 8'h10;
						cmd_data = 16'h0000;
						set = 1;
					end
					else
						state = 2;
					if(frame_done && set) begin
						state = 3;
						set = 0;
					end
				end
				3:begin //Record Select
					if(ready) begin
						cmd_addr = 8'h1A;
						cmd_data = 16'h0404;
						set = 1;
					end
					else
						state = 3;
					if(frame_done && set) begin
						state = 4;
						set = 0;
					end
				end
				4:begin //Record gain
					if(ready) begin
						cmd_addr = 8'h1C;
						cmd_data = 16'h0000;
						set = 1;
					end
					else
						state = 4;
					if(frame_done && set)begin
						state = 5;
						set = 0;
					end
				end
				5:begin //Send ADC input data directly to DAC
					if(ready)begin
						cmd_addr = 8'h80;
						cmd_vd = 0;
						leftdac = leftadc;
						rightdac = rightadc;
						left_vd = 1;
						right_vd = 1;
						set = 1;
					end
					
					if(frame_done && set) begin
						set = 0;
					end
				end
			endcase
		end
	end


endmodule





//////////////////////////////////////////////////////////////////////////////////
// Engineer:        John Ruddy
// Create Date:     22:28:38 04/13/2011 
// Module Name:     s6ac97 
// Project Name:    AC-97 Controller 
// Description:     Controller for the AC-97 Codec
//////////////////////////////////////////////////////////////////////////////////

module s6ac97(
	  input sys_clk,  //100MHz max(timing parameters designed for 100MHz)
	  input rst,    //reset
	  input cmd_vd,   //command data is valid (1 or 0)
	  input left_vd,  //left data is valid
	  input right_vd, //right data is valid
	  input BIT_CLK,    //From Codec
	 // input SDATA_IN,   //From Codec
	  output reg SDATA_OUT, //To Codec
	  output reg SYNC,      //To Codec
	  output reg RESET,     //To Codec
	  input [17:0] leftdac,   //left output data
	  input [19:0] rightdac,  //right output data
	  input [7:0] cmd_addr,   //command register address
	  input [15:0] cmd_data,  //command register data
	  output reg ready,       //rdy for new input data (high for 1 bitclk cycle)
	  output reg frame_done,  //current frame complete (high for 1 bitclk cycle)
	  output reg [19:0] leftadc, //left input data
	  output reg [19:0] rightadc, //right input data
	  output reg [19:0] reg_status, //status address
	  output reg [19:0] status_data //status data
	  );

	parameter rstlow_time = 8'd150; //150 clock cycles(1.5us on 100MHz sys_clk)
	parameter rst2clk = 5'd18; //18 clock cycles (100MHz Atlys sys_clk)
	
	reg [8:0] bitcount = 0;
	reg [7:0] rstlow;
	reg [15:0] status;
	reg [19:0] slot1_in, slot2_in, left_in, right_in, cmdaddr, cmddata, left_dac ;
	//reg rst = 0;

	//Reset Circuit
	always@(posedge sys_clk) begin
		if(rst) begin
			rstlow = 0;
			RESET = 0;
			//rst = 1;
		end
		else if (rstlow == rstlow_time)begin
			RESET = 1;
			rstlow = rstlow_time;
		end
		else
			rstlow = rstlow + 1'd1;
	end


	always@(posedge BIT_CLK) begin
		//Assert SYNC 1 bit before frame start
		//Deassert SYNC on last bit of slot 0
		//Prepare frame data
		if(bitcount == 255) begin
			SYNC = 1;
			frame_done = 1;
			cmdaddr = {cmd_addr, 12'h000};
			cmddata = {cmd_data, 4'h0}; 
			left_dac = {leftdac, 2'b00};
		end
		else if(bitcount == 215)//Signify ready at an idle bit count
			ready = 1;
		else if(bitcount == 15) //Sync goes low after 16-bit tag slot
			SYNC = 0;
		else begin
			frame_done = 0;
			ready = 0;
		end
		
		///AC Output Frame///
		//Slot 0: Tag Phase
		if(bitcount>=0 && bitcount<=15) begin
			case(bitcount[3:0])
				0: SDATA_OUT = (cmd_vd || left_vd || right_vd); //Valid Frame Bit
				1: SDATA_OUT = cmd_vd;   //Command addr valid
				2: SDATA_OUT = cmd_vd;   //Command data valid
				3: SDATA_OUT = left_vd;  //Left Data Valid
				4: SDATA_OUT = right_vd; //Right Data Valid
				default: SDATA_OUT = 0;
			endcase
		end
		//Slot 1: Command Address
		else if(bitcount>=16 && bitcount<=35) begin
			if(cmd_vd)
				SDATA_OUT = cmdaddr[35-bitcount];
			else
				SDATA_OUT = 0;
		end
		//Slot 2: Command Data
		else if(bitcount>=36 && bitcount<=55) begin
			if(cmd_vd)
				SDATA_OUT = cmddata[55-bitcount];
			else
				SDATA_OUT = 0;
		end
		//Slot 3: Left PCM DAC Data
		else if(bitcount >= 56 && bitcount <= 75) begin
			if(right_vd)
				SDATA_OUT = rightdac[75-bitcount];
			else
				SDATA_OUT = 0;
		end
		//Slot 4: Right PCM DAC Data
		else if(bitcount >= 76 && bitcount <= 95) begin
			if(left_vd)
				SDATA_OUT = left_dac[95-bitcount];
			else
				SDATA_OUT = 0;
		end
		else
			SDATA_OUT = 0;
			
			
		//Count bits/Reset at end of frame
		if(bitcount == 255)
			bitcount = 0;
		else
			bitcount = bitcount + 1'd1;
		
	end
	
	

	///AC Link Input Frame///
	always@(negedge BIT_CLK) begin
		//Slot 0: Codec/Slot Status Bits
		if((bitcount >= 1) && (bitcount <= 16)) begin
			status = {status[14:0], SDATA_IN};
		end
		//Slot 1: Status Registers
		else if((bitcount >= 17) && (bitcount <= 36)) begin
			slot1_in = {slot1_in[18:0], SDATA_IN};
		end
		//Slot 2: Status Data (Requested data)
		else if((bitcount >= 37) && (bitcount <= 56)) begin
			slot2_in = {slot2_in[18:0], SDATA_IN};
		end
		//Slot 3: Left PCM ADC Data
		else if((bitcount >= 57) && (bitcount <= 76)) begin
			left_in = {left_in[18:0], SDATA_IN};
		end
		//Slot 4: Right PCM ADC Data
		else if((bitcount >= 77) && (bitcount <= 96)) begin
			right_in = {right_in[18:0], SDATA_IN};
		end
		else begin
			//Latch data during idle period
			leftadc = left_in;
			rightadc = right_in;
			reg_status = slot1_in;
			status_data = slot2_in;
		end
	end
endmodule
