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

module s2026a (
	input			reset_n,
	input			clk,
	input			enable_z80,
	input			sdram_init_busy,
	input			z80_m1,
	input			z80_mreq,
	input			z80_iorq,
	input			z80_rd,
	input			z80_wr,
	input	[15:0]	z80_a,
	input	[7:0]	z80_wdata,
	output	[7:0]	z80_rdata,
	output			bus_m1,
	output			bus_io,
	output			bus_write,
	output			bus_valid,
	output	[7:0]	bus_wdata,
	output	[15:0]	bus_address,
	output			bus_uart_cs,
	input	[7:0]	bus_uart_rdata,
	input			bus_uart_rdata_en,
	input			bus_uart_ready,
	output			bus_bootrom_cs,
	input	[7:0]	bus_bootrom_rdata,
	input			bus_bootrom_rdata_en,
	input			bus_bootrom_ready,
	output			bus_vdp_cs,
	input	[7:0]	bus_vdp_rdata,
	input			bus_vdp_rdata_en,
	input			bus_vdp_ready,
	output			z80_active
);
	reg				ff_bootrom_mode;
	reg		[ 3:0]	ff_register_index;
	reg				ff_rom_mode;					//	ROM mode                        0:DRAM, 1:ROM
	reg		[ 8:0]	ff_div_counter;
	reg		[15:0]	ff_freerun_counter;
	reg				ff_bus_io;
	reg				ff_bus_m1;
	reg				ff_bus_write;
	reg				ff_bus_valid;
	reg		[7:0]	ff_bus_rdata;
	reg				ff_bus_rdata_en;
	wire			w_uart_cs;
	wire			w_bootrom_cs;
	wire			w_sysctl_cs;
	wire			w_vdp_cs;
	reg				ff_uart_cs;
	reg				ff_bootrom_cs;
	reg				ff_vdp_cs;
	reg		[7:0]	ff_f4;
	reg		[1:0]	ff_f5;
	wire			w_bus_ready;
	wire			w_cpu_pause;

	//	CPU select outputs
	wire	[15:0]	w_bus_address;
	wire			w_bus_m1;
	wire			w_bus_io;
	wire			w_bus_mem;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire	[7:0]	w_bus_wdata;

	// ---------------------------------------------------------
	//	CPU select instance
	// ---------------------------------------------------------
	s2026a_cpu_select u_cpu_select (
		.reset_n			( reset_n				),
		.clk				( clk					),
		.enable_z80			( enable_z80			),
		.sdram_init_busy	( sdram_init_busy		),
		.z80_m1				( z80_m1				),
		.z80_mreq			( z80_mreq				),
		.z80_iorq			( z80_iorq				),
		.z80_rd				( z80_rd				),
		.z80_wr				( z80_wr				),
		.z80_a				( z80_a					),
		.z80_wdata			( z80_wdata				),
		.z80_rdata			( z80_rdata				),
		.cpu_pause			( w_cpu_pause			),
		.rdata				( ff_bus_rdata			),
		.rdata_en			( ff_bus_rdata_en		),
		.z80_active			( z80_active			),
		.address			( w_bus_address			),
		.bus_m1				( w_bus_m1				),
		.bus_io				( w_bus_io				),
		.bus_mem			( w_bus_mem				),
		.bus_write			( w_bus_write			),
		.bus_valid			( w_bus_valid			),
		.bus_wdata			( w_bus_wdata			),
		.bus_ready			( w_bus_ready			)
	);

	// ---------------------------------------------------------
	//	Slot
	// ---------------------------------------------------------
	function [1:0] func_page_select(
		input	[1:0]	address,
		input	[7:0]	slot_select
	);
		case( address )
			2'd0:		func_page_select = slot_select[1:0];
			2'd1:		func_page_select = slot_select[3:2];
			2'd2:		func_page_select = slot_select[5:4];
			2'd3:		func_page_select = slot_select[7:6];
			default:	func_page_select = slot_select[1:0];
		endcase
	endfunction

	// ---------------------------------------------------------
	//	Chip select
	// ---------------------------------------------------------
	assign w_uart_cs				= (w_bus_io  && ( {w_bus_address[7:2], 2'd0} == 8'h10 ));
	assign w_bootrom_cs				= (w_bus_mem &&  ff_bootrom_mode);
	assign w_vdp_cs					= (w_bus_io  && ( {w_bus_address[7:3], 3'd0} == 8'h98 ));
	assign w_sysctl_cs				= (w_bus_io  && ( {w_bus_address[7:1], 1'd0} == 8'hF4 ));

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_uart_cs				<= 1'b0;
			ff_bootrom_cs			<= 1'b0;
			ff_vdp_cs				<= 1'b0;
			ff_bus_write			<= 1'b0;
			ff_bus_m1				<= 1'b0;
			ff_bus_io				<= 1'b0;
		end
		else if( w_bus_valid ) begin
			ff_uart_cs				<= w_uart_cs;
			ff_bootrom_cs			<= w_bootrom_cs;
			ff_vdp_cs				<= w_vdp_cs;
			ff_bus_write			<= w_bus_write;
			ff_bus_m1				<= w_bus_m1;
			ff_bus_io				<= w_bus_io;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_valid			<= 1'b0;
		end
		else if( w_bus_ready & ff_bus_valid ) begin
			ff_bus_valid			<= 1'b0;
		end
		else begin
			ff_bus_valid			<= w_bus_valid;
		end
	end

	// ---------------------------------------------------------
	//	Read data MUX
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_rdata	<= 8'hF3;			//	DI
			ff_bus_rdata_en	<= 1'b0;
		end
		else if( bus_uart_rdata_en ) begin
			ff_bus_rdata	<= bus_uart_rdata;
			ff_bus_rdata_en	<= 1'b1;
		end
		else if( bus_bootrom_rdata_en ) begin
			ff_bus_rdata	<= bus_bootrom_rdata;
			ff_bus_rdata_en	<= 1'b1;
		end
		else if( bus_vdp_rdata_en ) begin
			ff_bus_rdata	<= bus_vdp_rdata;
			ff_bus_rdata_en	<= 1'b1;
		end
		else begin
			ff_bus_rdata_en	<= 1'b0;
		end
	end

	assign w_s2026_ready	= 1'b1;

	// ---------------------------------------------------------
	//	Wait / Ready
	// ---------------------------------------------------------
	assign w_bus_ready	= (!w_uart_cs           | bus_uart_ready      ) &
						  (!w_bootrom_cs        | bus_bootrom_ready   );
	assign w_cpu_pause	= w_bus_valid & ~w_bus_ready;

	//--------------------------------------------------------------
	//	out assignment
	//--------------------------------------------------------------
	assign bus_uart_cs		= ff_uart_cs;
	assign bus_bootrom_cs	= ff_bootrom_cs;
	assign bus_vdp_cs		= ff_vdp_cs;

	assign bus_m1			= ff_bus_m1;
	assign bus_io			= ff_bus_io;
	assign bus_write		= ff_bus_write;
	assign bus_valid		= ff_bus_valid;
	assign bus_wdata		= w_bus_wdata;
	assign bus_address		= w_bus_address;

	//--------------------------------------------------------------
	//	System control
	//--------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_f4	<= 8'd0;
			ff_f5	<= 2'd0;
		end
		else if( w_sysctl_cs && w_bus_write && w_bus_address[0] == 1'b0 ) begin
			ff_f4	<= w_bus_wdata;
		end
		else if( w_sysctl_cs && w_bus_write && w_bus_address[0] == 1'b1 ) begin
			ff_f5	<= w_bus_wdata[1:0];
		end
	end

	assign kanji1_en	= ff_f5[0];
	assign kanji2_en	= ff_f5[1];

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bootrom_mode	<= 1'b1;
		end
	end
endmodule
