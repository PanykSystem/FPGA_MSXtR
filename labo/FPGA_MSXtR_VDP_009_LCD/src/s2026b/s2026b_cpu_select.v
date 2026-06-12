//
// s2026a_cpu_select.v
//   CPU select (Z80 / R800)
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

module s2026b_cpu_select (
	input			reset_n,
	input			clk,
	input			sdram_init_busy,
	//	Bus ctrl0 I/F (MSX CPU)
	input			bus_ctrl0_io,
	input			bus_ctrl0_valid,
	output			bus_ctrl0_ready,
	input			bus_ctrl0_write,
	input	[15:0]	bus_ctrl0_address,
	input	[7:0]	bus_ctrl0_wdata,
	output	[7:0]	bus_ctrl0_rdata,
	output			bus_ctrl0_rdata_en,
	//	Bus ctrl1 I/F (Controller)
	input			bus_ctrl1_io,
	input			bus_ctrl1_valid,
	output			bus_ctrl1_ready,
	input			bus_ctrl1_write,
	input	[15:0]	bus_ctrl1_address,
	input	[7:0]	bus_ctrl1_wdata,
	output	[7:0]	bus_ctrl1_rdata,
	output			bus_ctrl1_rdata_en,
	//	Internal bus outputs
	output			bus_io,
	output			bus_valid,
	input			bus_ready,
	output			bus_write,
	output	[15:0]	bus_address,
	output	[7:0]	bus_wdata,
	input	[7:0]	bus_rdata,
	input			bus_rdata_en
);
	reg				ff_bus_id;
	reg				ff_bus_io;
	reg				ff_bus_valid;
	reg				ff_bus_write;
	reg		[15:0]	ff_bus_address;
	reg		[7:0]	ff_bus_wdata;
	reg				ff_ready;
	wire 			w_bus_io;
	wire			w_bus_valid;
	wire			w_bus_write;
	wire	[15:0]	w_bus_address;
	wire	[7:0]	w_bus_wdata;

	// ---------------------------------------------------------
	//	BUS signal selector
	// ---------------------------------------------------------
	assign w_bus_valid		= bus_ctrl0_valid | bus_ctrl1_valid;
	assign w_bus_io			= bus_ctrl0_valid ? bus_ctrl0_io		: bus_ctrl1_io;
	assign w_bus_write		= bus_ctrl0_valid ? bus_ctrl0_write 	: bus_ctrl1_write;
	assign w_bus_address	= bus_ctrl0_valid ? bus_ctrl0_address	: bus_ctrl1_address;
	assign w_bus_wdata		= bus_ctrl0_valid ? bus_ctrl0_wdata		: bus_ctrl1_wdata;
	assign bus_ctrl0_ready	= ff_ready;
	assign bus_ctrl1_ready	= ff_ready & ~bus_ctrl0_valid;

	// ---------------------------------------------------------
	//	Write data MUX
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( w_bus_valid ) begin
			ff_bus_address	<= w_bus_address;
			ff_bus_wdata	<= w_bus_wdata;
		end
	end

	// ---------------------------------------------------------
	//	Valid/Ready protocol 制御
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_valid	<= 1'b0;
		end
		else begin
			ff_bus_valid	<= w_bus_valid;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_id		<= 1'b0;
			ff_bus_io		<= 1'b0;
			ff_bus_write	<= 1'b0;
		end
		else if( w_bus_valid && ff_ready ) begin
			ff_bus_id		<= bus_ctrl0_valid ? 1'b0 : 1'b1;
			ff_bus_io		<= w_bus_io;
			ff_bus_write	<= w_bus_write;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ready	<= 1'b1;
		end
		else if( w_bus_valid && ff_ready ) begin
			//	Read/Write 問わず、要求を受理したタイミングでいったん busy に入る
			ff_ready	<= 1'b0;
		end
		else if( ff_bus_write && !ff_ready && bus_ready ) begin
			//	Write の場合は、要求を受理した次のサイクルで busy を解除する
			ff_ready	<= 1'b1;
		end
		else if( !ff_bus_write && bus_rdata_en ) begin
			//	Read の場合は、データが返ってきたタイミングで busy を解除する
			ff_ready	<= 1'b1;
		end
	end

	// ---------------------------------------------------------
	//	Output assignments
	// ---------------------------------------------------------
	assign bus_io				= ff_bus_io;
	assign bus_write			= ff_bus_write;
	assign bus_address			= ff_bus_address;
	assign bus_valid			= ff_bus_valid;
	assign bus_wdata			= ff_bus_wdata;
	assign bus_ctrl0_rdata		= bus_rdata;
	assign bus_ctrl0_rdata_en	= bus_rdata_en & (ff_bus_id == 1'b0);
	assign bus_ctrl1_rdata		= bus_rdata;
	assign bus_ctrl1_rdata_en	= bus_rdata_en & (ff_bus_id == 1'b1);

endmodule
