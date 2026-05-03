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
	localparam		ST_IDLE		= 3'd0;
	localparam		ST_COMMAND	= 3'd1;
	reg		[2:0]	ff_state;
	reg				ff_spi_valid;
	reg				ff_spi_write;
	reg		[7:0]	ff_spi_wdata;

	// ---------------------------------------------------------
	//	State machine
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_state <= ST_IDLE;
		end
		else if( spi_cs_n ) begin
			ff_state <= ST_IDLE;
		end
		else begin
			case( ff_state )
			ST_IDLE: begin
				ff_state <= ST_COMMAND;
			end
			ST_COMMAND: begin
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
	.spi_valid		( ff_spi_valid	),
	.spi_ready		( spi_ready		),
	.spi_write		( ff_spi_write	),
	.spi_wdata		( spi_wdata		),
	.spi_rdata		( spi_rdata		),
	.spi_rdata_en	( spi_rdata_en	),
	.spi_cs_n		( spi_cs_n		),
	.spi_clk		( spi_clk		),
	.spi_mosi		( spi_mosi		),
	.spi_miso		( spi_miso		)
	);

	assign spi_intr		= 1'b0;
endmodule
