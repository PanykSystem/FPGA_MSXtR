//
// spi.v
//   SPI Slave Controller
//   Revision 1.00
//
// Copyright (c) 2026 Takayuki Hara.
// All rights reserved.
//
// Redistribution and use of this source code or any derivative works, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Redistributions may not be sold, nor may they be used in a commercial
//    product or activity without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ----------------------------------------------------------------------------

module spi (
	input			reset_n,
	input			clk,					//	System Clock
	input			clk_serial,				//	Serial Clock
	//	Request from controller
	input			spi_valid,
	output			spi_ready,
	input			spi_write,
	input	[7:0]	spi_wdata,
	output	[7:0]	spi_rdata,
	output			spi_rdata_en,
	//	SPI
	input			spi_cs_n,
	input			spi_clk,
	input			spi_mosi,
	output			spi_miso
);
	//	clk domain crossing registers
	reg				ff_write;
	reg		[7:0]	ff_wdata;
	reg				ff_spi_ready;
	reg				ff_spi_mosi_data_en0;
	reg				ff_spi_mosi_data_en1;
	reg				ff_spi_mosi_data_en;
	reg 			ff_request;
	wire			w_done_pulse;
	reg				ff_done_toggle;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_write <= 1'b0;
			ff_wdata <= 8'd0;
		end
		else if( spi_cs_n ) begin
			//	Reset SPI transaction when CS is deasserted 
			ff_write <= 1'b0;
			ff_wdata <= 8'd0;
		end
		else if( spi_valid && ff_spi_ready ) begin
			ff_write <= spi_write;
			ff_wdata <= spi_wdata;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_request <= 1'b0;
		end
		else if( spi_cs_n ) begin
			ff_request <= 1'b0;
		end
		else begin
			ff_request <= spi_valid && ff_spi_ready;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_spi_ready <= 1'b0;
		end
		else if( spi_cs_n ) begin
			ff_spi_ready <= 1'b1;
		end
		else if( spi_valid && ff_spi_ready ) begin
			ff_spi_ready <= 1'b0;
		end
		else if( w_done_pulse ) begin
			//	Set ready after 8-bit transfer is complete (clk_serial -> clk domain crossing)
			ff_spi_ready <= 1'b1;
		end
	end

	//	Synchronize ff_done_toggle from clk_serial domain to clk domain (3-stage)
	//	  Stage 0 (ff_spi_mosi_data_en0) may be metastable;
	//	  Stage 1 (ff_spi_mosi_data_en1) is metastability-resolved;
	//	  Stage 2 (ff_spi_mosi_data_en)  is used for XOR edge detection.
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_spi_mosi_data_en0 <= 1'b0;
			ff_spi_mosi_data_en1 <= 1'b0;
			ff_spi_mosi_data_en  <= 1'b0;
		end
		else begin
			ff_spi_mosi_data_en0 <= ff_done_toggle;
			ff_spi_mosi_data_en1 <= ff_spi_mosi_data_en0;
			ff_spi_mosi_data_en  <= ff_spi_mosi_data_en1;
		end
	end

	assign w_done_pulse = ff_spi_mosi_data_en1 ^ ff_spi_mosi_data_en;

	//	clk_serial domain crossing registers
	reg 			ff_request_ms0;
	reg 			ff_request_ms1;
	reg 			ff_request_ms2;
	reg 			ff_spi_mosi_ms0;
	reg 			ff_spi_mosi_ms1;
	reg 			ff_spi_mosi_ms2;
	reg 			ff_clk_ms0;
	reg 			ff_clk_ms1;
	reg 			ff_clk_ms2;
	wire 			w_spi_request;
	wire			w_spi_clk_falling_edge;
	wire			w_spi_clk_rising_edge;
	reg		[7:0]	ff_spi_mosi_data;
	reg		[7:0]	ff_spi_miso_data;
	reg		[2:0]	ff_bit_cnt;

	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_request_ms0 <= 1'b0;
			ff_request_ms1 <= 1'b0;
			ff_request_ms2 <= 1'b0;
			ff_spi_mosi_ms0 <= 1'b0;
			ff_spi_mosi_ms1 <= 1'b0;
			ff_spi_mosi_ms2 <= 1'b0;
			ff_clk_ms0 <= 1'b0;
			ff_clk_ms1 <= 1'b0;
			ff_clk_ms2 <= 1'b0;
		end
		else begin
			//	Detect request signal in clk_serial domain
			ff_request_ms0 <= ff_request;
			ff_request_ms1 <= ff_request_ms0;
			ff_request_ms2 <= ff_request_ms1;
			ff_spi_mosi_ms0 <= spi_mosi;
			ff_spi_mosi_ms1 <= ff_spi_mosi_ms0;
			ff_spi_mosi_ms2 <= ff_spi_mosi_ms1;
			ff_clk_ms0 <= spi_clk;
			ff_clk_ms1 <= ff_clk_ms0;
			ff_clk_ms2 <= ff_clk_ms1;
		end
	end

	assign w_spi_request			= ff_request_ms1 & ~ff_request_ms2;
	assign w_spi_clk_falling_edge	=  ff_clk_ms1 & ~ff_clk_ms2;
	assign w_spi_clk_rising_edge	= ~ff_clk_ms1 &  ff_clk_ms2;

	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_spi_miso_data <= 8'd0;
		end
		else if( spi_cs_n ) begin
			ff_spi_miso_data <= 8'd0;
		end
		else if( w_spi_request ) begin
			ff_spi_miso_data <= ff_write ? ff_wdata: 8'd0;
		end
		else if( w_spi_clk_falling_edge ) begin
			//	Shift out data to MISO on the falling edge of SPI clock
			ff_spi_miso_data <= { ff_spi_miso_data[6:0], 1'b0 };
		end
	end

	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_spi_mosi_data <= 8'd0;
		end
		else if( spi_cs_n ) begin
			ff_spi_mosi_data <= 8'd0;
		end
		else if( w_spi_request ) begin
			ff_spi_mosi_data <= 8'd0;
		end
		else if( w_spi_clk_rising_edge ) begin
			//	Shift in data from MOSI on the rising edge of SPI clock
			ff_spi_mosi_data <= { ff_spi_mosi_data[6:0], ff_spi_mosi_ms2 };
		end
	end

	//	Bit counter and done toggle (clk_serial domain)
	//	Counts MOSI sample events (w_spi_clk_rising_edge); toggles ff_done_toggle
	//	on the 8th event to signal byte completion to the clk domain.
	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_bit_cnt     <= 3'd0;
			ff_done_toggle <= 1'b0;
		end
		else if( spi_cs_n ) begin
			ff_bit_cnt     <= 3'd0;
			ff_done_toggle <= 1'b0;
		end
		else if( w_spi_request ) begin
			ff_bit_cnt <= 3'd0;
		end
		else if( w_spi_clk_rising_edge ) begin
			if( ff_bit_cnt == 3'd7 ) begin
				ff_bit_cnt     <= 3'd0;
				ff_done_toggle <= ~ff_done_toggle;
			end
			else begin
				ff_bit_cnt <= ff_bit_cnt + 3'd1;
			end
		end
	end

	assign spi_ready	= ff_spi_ready;
	assign spi_rdata	= ff_spi_mosi_data;
	assign spi_rdata_en = w_done_pulse & ~ff_write;
	assign spi_miso		= ff_spi_miso_data[7];
endmodule