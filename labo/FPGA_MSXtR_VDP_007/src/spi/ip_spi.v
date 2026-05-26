//
// ip_spi.v
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

module ip_spi (
	input			reset_n,
	input			clk,					//	System Clock
	input			clk_serial,				//	Serial Clock
	//	Bus (Master)
	output			bus_io,
	output			bus_write,
	output			bus_valid,
	input			bus_ready,
	output	[7:0]	bus_wdata,
	output	[15:0]	bus_address,
	input	[7:0]	bus_rdata,
	input			bus_rdata_en,
	//	SPI
	input			spi_cs_n,
	input			spi_clk,
	input			spi_mosi,
	output			spi_miso,
	output			spi_intr
);
	localparam		ST_IDLE			= 3'd0;
	localparam		ST_COMMAND		= 3'd1;
	localparam		ST_3OPERANDS	= 3'd2;
	localparam		ST_2OPERANDS	= 3'd3;
	localparam		ST_1OPERAND		= 3'd4;
	localparam		ST_DO			= 3'd5;
	reg		[2:0]	ff_state;
	wire			spi_ready;
	wire	[7:0]	spi_rdata;
	wire			spi_rdata_en;
	reg		[15:0]	ff_bus_address;
	reg		[7:0]	ff_bus_wdata;
	reg				ff_bus_io;
	reg				ff_bus_valid;

	// ---------------------------------------------------------
	//	State machine
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_state		<= ST_IDLE;
			ff_bus_address	<= 16'd0;
			ff_bus_wdata	<= 8'd0;
			ff_bus_io		<= 1'b0;
			ff_bus_valid	<= 1'b0;
		end
		else if( ff_state == ST_DO ) begin
			if( bus_ready ) begin
				ff_bus_valid	<= 1'b0;
				ff_state		<= spi_cs_n ? ST_IDLE: ST_COMMAND;
			end
		end
		else if( spi_cs_n ) begin
			ff_state <= ST_IDLE;
		end
		else begin
			case( ff_state )
			ST_IDLE: begin
				ff_state <= ST_COMMAND;
			end
			// -------------------------------------------------
			// COMMAND:
			//   01h, io#, data (3bytes) ... I/O write
			//   02h, address_h#, address_l#, data (4bytes) ... address write
			ST_COMMAND: begin
				if( spi_rdata_en ) begin
					case( spi_rdata )
					8'h01: begin
						ff_state	<= ST_2OPERANDS;
						ff_bus_io	<= 1'b1;
					end
					default: begin
						// unknown command --> ignore
					end
					endcase
				end
				else begin
					//	hold
				end
			end
			ST_3OPERANDS: begin
				if( spi_rdata_en ) begin
					ff_bus_address[15:8]	<= spi_rdata;
					ff_state				<= ST_2OPERANDS;
				end
			end
			ST_2OPERANDS: begin
				if( spi_rdata_en ) begin
					ff_bus_address[ 7:0]	<= spi_rdata;
					ff_state				<= ST_1OPERAND;
				end
			end
			ST_1OPERAND: begin
				if( spi_rdata_en ) begin
					ff_bus_wdata	<= spi_rdata;
					ff_state		<= ST_DO;
					ff_bus_valid	<= 1'b1;
				end
			end
			default: begin
				// unknown state
				ff_state <= ST_COMMAND;
			end
			endcase
		end
	end

	// ---------------------------------------------------------
	//	SPI slave module for connect the micro controller.
	// ---------------------------------------------------------
	spi u_spi (
	.reset_n		( reset_n		),
	.clk			( clk			),
	.clk_serial		( clk_serial	),
	.spi_valid		( 1'b0			),
	.spi_ready		( spi_ready		),
	.spi_write		( 1'b0			),
	.spi_wdata		( 8'd0			),
	.spi_rdata		( spi_rdata		),
	.spi_rdata_en	( spi_rdata_en	),
	.spi_cs_n		( spi_cs_n		),
	.spi_clk		( spi_clk		),
	.spi_mosi		( spi_mosi		),
	.spi_miso		( spi_miso		)
	);

	assign spi_intr		= 1'b0;

	// ---------------------------------------------------------
	//	BUS access
	// ---------------------------------------------------------
	assign bus_io			= ff_bus_io;
	assign bus_write		= 1'b1;
	assign bus_address		= ff_bus_address;
	assign bus_wdata		= ff_bus_wdata;
	assign bus_valid		= ff_bus_valid;
endmodule
