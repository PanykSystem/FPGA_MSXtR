// -----------------------------------------------------------------------------
// msx_slot_decode.v
// MSX cartridge slot decoder
// Revision 1.00
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

module msx_slot_decode (
	input			reset_n,
	input			clk_42m,				//	42.95454MHz
	input			clk_215m,				//	214.7727MHz
	//	Internal bus interface
	input	[15:0]	bus_address,			//	Z80 address
	input			bus_io,					//	1: I/O access, 0: Memory access
	input			bus_write,				//	0: read, 1: write
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	input	[7:0]	primary_slot,
	input	[7:0]	secondary_slot0,
	input	[7:0]	secondary_slot3,
	input			high_speed_mode,
	//	Device interface
	input	[15:0]	device_address,			//	Z80 address
	input			device_io,				//	1: I/O access, 0: Memory access
	input			device_write,			//	0: read, 1: write
	input			device_valid,
	output			device_ready,
	input	[7:0]	device_wdata,
	output	[7:0]	device_rdata,
	output			device_rdata_en,
	//	flash ROM interface
	output	[18:14]	rom_upper_address,
	output			rom_upper_en,
	output			rom0_ce_n,
	output			rom1_ce_n
);
	wire	[1:0]	w_page;
	wire	[1:0]	w_primary_slot;
	wire	[1:0]	w_secondary_slot0;
	wire	[1:0]	w_secondary_slot3;
	wire	[1:0]	w_secondary_slot;
	reg		[18:0]	ff_rom_address;
	reg				ff_rom_upper_en;
	reg				ff_rom0_ce_n;
	reg				ff_rom1_ce_n;
	reg		[1:0]	ff_dos_bank;
	reg		[16:0]	ff_jis1_address;
	reg		[16:0]	ff_jis2_address;

	// ---------------------------------------------------------
	//	Slot decode
	// ---------------------------------------------------------
	function [1:0] f_page_slot(
		input	[7:0]		slot,
		input	[15:14]		page
	);
		case( page )
			2'd0:		f_page_slot = slot[1:0];		// Page#0
			2'd1:		f_page_slot = slot[3:2];		// Page#1
			2'd2:		f_page_slot = slot[5:4];		// Page#2
			2'd3:		f_page_slot = slot[7:6];		// Page#3
			default: begin
				//	hold
			end
		endcase
	endfunction

	assign w_page				= bus_address[15:14];
	assign w_primary_slot		= f_page_slot( primary_slot		, w_page );
	assign w_secondary_slot0	= f_page_slot( secondary_slot0	, w_page );
	assign w_secondary_slot3	= f_page_slot( secondary_slot3	, w_page );
	assign w_secondary_slot		= ( w_primary_slot == 2'd0 ) ? w_secondary_slot0 : w_secondary_slot3;

	always @( posedge clk_42m ) begin
		if( !reset_n ) begin
			ff_rom_address			<= { 3'd0, 16'd0 };
			ff_rom_upper_en			<= 1'b0;
			ff_rom0_ce_n			<= 1'b1;
			ff_rom1_ce_n			<= 1'b1;
		end
		else if( !bus_io && bus_valid ) begin
			case( { w_primary_slot, w_secondary_slot, w_page } )
				{ 2'd0, 2'd0, 2'd0 }: begin
					//	SLOT#0-0 page#0: MAIN-ROM (lower)
					ff_rom_address			<= { 3'd0, 2'b00, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd0, 2'd0, 2'd1 }: begin
					//	SLOT#0-0 page#1: MAIN-ROM (upper)
					ff_rom_address			<= { 3'd0, 2'b01, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd0, 2'd1, 2'd0 }: begin
					//	SLOT#0-1 page#0: Option-ROM0
					ff_rom_address			<= { 3'd0, 2'b10, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd0, 2'd1, 2'd1 }: begin
					//	SLOT#0-1 page#1: Option-ROM1
					ff_rom_address			<= { 3'd0, 2'b11, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd0, 2'd2, 2'd0 }: begin
					//	SLOT#0-2 page#0: Option-ROM2
					ff_rom_address			<= { 3'd1, 2'b00, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd0, 2'd2, 2'd1 }: begin
					//	SLOT#0-2 page#1: MSX-MUSIC
					ff_rom_address			<= { 3'd1, 2'b01, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd0, 2'd3, 2'd0 }: begin
					//	SLOT#0-3 page#0: Option-ROM3
					ff_rom_address			<= { 3'd1, 2'b10, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd0, 2'd3, 2'd1 }: begin
					//	SLOT#0-3 page#1: Boot Logo
					ff_rom_address			<= { 3'd1, 2'b11, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd3, 2'd1, 2'd0 }: begin
					//	SLOT#3-1 page#0: EXT-ROM
					ff_rom_address			<= { 3'd2, 2'b00, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd3, 2'd1, 2'd1 }: begin
					//	SLOT#3-1 page#1: KanjiDriver (Lower)
					ff_rom_address			<= { 3'd2, 2'b01, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd3, 2'd1, 2'd2 }: begin
					//	SLOT#3-1 page#2: KanjiDriver (Upper)
					ff_rom_address			<= { 3'd2, 2'b10, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd3, 2'd1, 2'd3 }: begin
					//	SLOT#3-1 page#3: Option-ROM4
					ff_rom_address			<= { 3'd2, 2'b11, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				{ 2'd3, 2'd3, 2'd0 }: begin
					//	SLOT#3-2 page#1: MSX-DOS2
					ff_rom_address			<= { 3'd3, ff_dos_bank, bus_address[13:0] };
					ff_rom_upper_en			<= 1'b1;
					ff_rom0_ce_n			<= 1'b0;
				end
				default: begin
					ff_rom_upper_en			<= 1'b0;
					ff_rom0_ce_n			<= 1'b1;
					ff_rom1_ce_n			<= 1'b1;
				end
			endcase
		end
		else if( bus_io && bus_valid && { bus_address[7:2], 2'd0 } == 8'hD8 ) begin
			if( bus_address[1] == 1'b0 ) begin
				if( bus_write ) begin
					if( bus_address[0] == 1'b0 ) begin
						//	D8h: KanjiROM JIS1: write address low
						ff_jis1_address[10:0]	<= { bus_wdata[5:0], 5'd0 };
					end
					else begin
						//	D9h: KanjiROM JIS1: write address high
						ff_jis1_address[16:11]	<= bus_wdata[5:0];
					end
				end
				else begin
					//	D8h, D9h: KanjiROM JIS1: read address
					ff_rom_address			<= { 2'd0, ff_jis1_address };
					ff_rom_upper_en			<= 1'b1;
					ff_rom1_ce_n			<= 1'b0;
				end
			end
			else begin
				if( bus_write ) begin
					if( bus_address[0] == 1'b0 ) begin
						//	DAh: KanjiROM JIS2: write address low
						ff_jis2_address[10:0]	<= { bus_wdata[5:0], 5'd0 };
					end
					else begin
						//	DBh: KanjiROM JIS2: write address high
						ff_jis2_address[16:11]	<= bus_wdata[5:0];
					end
				end
				else begin
					//	DAh, DBh: KanjiROM JIS2: read address
					ff_rom_address			<= { 2'd0, ff_jis2_address };
					ff_rom_upper_en			<= 1'b1;
					ff_rom1_ce_n			<= 1'b0;
				end
			end
		end
	end
endmodule
