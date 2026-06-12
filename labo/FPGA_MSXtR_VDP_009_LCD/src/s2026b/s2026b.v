//
// s2026a.v
//   s2026a device
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

module s2026b (
	input			reset_n,
	input			clk,
	input			sdram_init_busy,
	input			bus_ctrl0_io,
	input			bus_ctrl0_write,
	input			bus_ctrl0_valid,
	output			bus_ctrl0_ready,
	input	[15:0]	bus_ctrl0_address,
	input	[7:0]	bus_ctrl0_wdata,
	output	[7:0]	bus_ctrl0_rdata,
	output			bus_ctrl0_rdata_en,
	input			bus_ctrl1_io,
	input			bus_ctrl1_write,
	input			bus_ctrl1_valid,
	output			bus_ctrl1_ready,
	input	[15:0]	bus_ctrl1_address,
	input	[7:0]	bus_ctrl1_wdata,
	output	[7:0]	bus_ctrl1_rdata,
	output			bus_ctrl1_rdata_en,
	output			bus_write,
	output			bus_valid,
	output	[7:0]	bus_wdata,
	output	[15:0]	bus_address,
	output			bus_vdp_cs,
	input	[7:0]	bus_vdp_rdata,
	input			bus_vdp_rdata_en,
	input			bus_vdp_ready,
	output			bus_uart_cs,
	input	[7:0]	bus_uart_rdata,
	input			bus_uart_rdata_en,
	input			bus_uart_ready,
	output			bus_crom_cs,
	input	[7:0]	bus_crom_rdata,
	input			bus_crom_rdata_en,
	input			bus_crom_ready
);
	wire			w_vdp_cs;
	wire			w_uart_cs;
	wire			w_crom_cs;

	//	CPU select outputs
	wire	[15:0]	w_bus_address;
	wire			w_bus_io;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire	[7:0]	w_bus_wdata;
	reg		[7:0]	ff_bus_rdata;
	reg				ff_bus_rdata_en;

	// ---------------------------------------------------------
	//	CPU select instance
	// ---------------------------------------------------------
	s2026b_cpu_select u_cpu_select (
		.reset_n			( reset_n				),
		.clk				( clk					),
		.sdram_init_busy	( sdram_init_busy		),
		.bus_ctrl0_io		( bus_ctrl0_io			),
		.bus_ctrl0_valid	( bus_ctrl0_valid		),
		.bus_ctrl0_ready	( bus_ctrl0_ready		),
		.bus_ctrl0_write	( bus_ctrl0_write		),
		.bus_ctrl0_address	( bus_ctrl0_address		),
		.bus_ctrl0_wdata	( bus_ctrl0_wdata		),
		.bus_ctrl0_rdata	( bus_ctrl0_rdata		),
		.bus_ctrl0_rdata_en	( bus_ctrl0_rdata_en	),
		.bus_ctrl1_io		( bus_ctrl1_io			),
		.bus_ctrl1_valid	( bus_ctrl1_valid		),
		.bus_ctrl1_ready	( bus_ctrl1_ready		),
		.bus_ctrl1_write	( bus_ctrl1_write		),
		.bus_ctrl1_address	( bus_ctrl1_address		),
		.bus_ctrl1_wdata	( bus_ctrl1_wdata		),
		.bus_ctrl1_rdata	( bus_ctrl1_rdata		),
		.bus_ctrl1_rdata_en	( bus_ctrl1_rdata_en	),
		.bus_io				( w_bus_io				),
		.bus_valid			( w_bus_valid			),
		.bus_ready			( w_bus_ready			),
		.bus_write			( w_bus_write			),
		.bus_address		( w_bus_address			),
		.bus_wdata			( w_bus_wdata			),
		.bus_rdata			( ff_bus_rdata			),
		.bus_rdata_en		( ff_bus_rdata_en		)
	);

	// ---------------------------------------------------------
	//	Chip select
	// ---------------------------------------------------------
	assign w_vdp_cs			= (w_bus_io  && ( {w_bus_address[7:3], 3'd0} == 8'h98 ));
	assign w_uart_cs		= (w_bus_io  && ( {w_bus_address[7:3], 3'd0} == 8'h10 ));
	assign w_crom_cs		= (w_bus_io  && ( {w_bus_address[7:3], 3'd0} == 8'h20 ));
	always @( posedge clk ) begin
		if( w_vdp_cs && bus_vdp_rdata_en ) begin
			ff_bus_rdata		<= bus_vdp_rdata;
			ff_bus_rdata_en		<= 1'b1;
		end
		else if( w_uart_cs && bus_uart_rdata_en ) begin
			ff_bus_rdata		<= bus_uart_rdata;
			ff_bus_rdata_en		<= 1'b1;
		end
		else if( w_crom_cs && bus_crom_rdata_en ) begin
			ff_bus_rdata		<= bus_crom_rdata;
			ff_bus_rdata_en		<= 1'b1;
		end
		else begin
			ff_bus_rdata		<= 8'h00;
			ff_bus_rdata_en		<= 1'b0;
		end
	end

	// ---------------------------------------------------------
	//	Wait / Ready
	// ---------------------------------------------------------
	assign w_bus_ready		= w_vdp_cs  ? bus_vdp_ready  :
							w_uart_cs ? bus_uart_ready : 
							w_crom_cs ? bus_crom_ready : 1'b1;

	//--------------------------------------------------------------
	//	out assignment
	//--------------------------------------------------------------
	assign bus_vdp_cs		= w_vdp_cs;
	assign bus_uart_cs		= w_uart_cs;
	assign bus_crom_cs		= w_crom_cs;
	assign bus_write		= w_bus_write;
	assign bus_valid		= w_bus_valid;
	assign bus_wdata		= w_bus_wdata;
	assign bus_address		= w_bus_address;
endmodule
