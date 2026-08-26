// -----------------------------------------------------------------------------
// msx_slot.v
// MSX cartridge slot timing controller
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

module msx_slot (
	input			reset_n,
	input			clk_42m,				//	42.95454MHz
	input			clk_215m,				//	214.7727MHz
	//	Internal bus interface
	input			bus_m1,
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
	//	Other signals
	output			int_n,
	//	MSX slot interface
	output			slot_m1_n,
	output			slot_oe_n,
	output			slot_clock_n,
	output			slot_sltsl0_n,
	output			slot_sltsl1_n,
	output			slot_sltsl2_n,
	output			slot_sltsl3_n,
	output			slot_cs1_n,
	output			slot_cs2_n,
	output			slot_cs12_n,
	output	[18:0]	slot_a,
	input			slot_int_n,
	input			slot_wait_n,
	output			slot_reset_n,
	input			slot_busdir,
	output			slot_data_dir,
	output			slot_wr_n,
	output			slot_rd_n,
	output			slot_rom0_ce_n,
	output			slot_rom1_ce_n,
	output			slot_rfsh_n,
	output			slot_iorq_n,
	output			slot_merq_n,
	inout	[7:0]	slot_d,
	//	Device interface
	input	[15:0]	device_address,			//	Z80 address
	input			device_io,				//	1: I/O access, 0: Memory access
	input			device_write,			//	0: read, 1: write
	input			device_valid,
	output			device_ready,
	input	[7:0]	device_wdata,
	output	[7:0]	device_rdata,
	output			device_rdata_en
);
	localparam		c_timing_start			= 8'd0;
	localparam		c_timing_command		= 8'd31;
	localparam		c_timing_select			= 8'd34;
	localparam		c_timing_strobe			= 8'd60;
	localparam		c_timing_read_sample	= 8'd165;
	localparam		c_timing_finish			= 8'd179;
	localparam		c_refresh_timeout		= 18'd214773;	//	約1ms(214.7727MHz基準)

	reg				ff_bus_busy;
	reg				ff_req_m1;
	reg				ff_req_io;
	reg				ff_req_write;
	reg	[15:0]		ff_req_address;
	reg	[7:0]		ff_req_wdata;
	reg				ff_req_toggle;
	reg				ff_done_toggle_sync0;
	reg				ff_done_toggle_sync1;
	reg				ff_done_toggle_sync2;
	reg	[7:0]		ff_bus_rdata;
	reg				ff_bus_rdata_en;

	reg				ff_req_toggle_sync0;
	reg				ff_req_toggle_sync1;
	reg				ff_req_toggle_sync2;
	reg				ff_done_toggle;
	reg				ff_req_pending_215m;
	reg				ff_busy_215m;
	reg				ff_req_m1_215m;
	reg				ff_req_io_215m;
	reg				ff_req_write_215m;
	reg	[15:0]		ff_req_address_215m;
	reg	[7:0]		ff_req_wdata_215m;
	reg	[7:0]		ff_access_count;
	reg	[5:0]		ff_slot_clock_count;
	reg				ff_slot_clock;
	reg	[7:0]		ff_slot_rdata;
	reg				ff_slot_read_done;
	reg	[7:0]		ff_primary_slot_215m;
	reg	[7:0]		ff_secondary_slot_215m;
	reg				ff_m1_wait_active;
	reg	[5:0]		ff_m1_wait_count;
	reg				ff_m1_wait_done;
	reg				ff_req_refresh_215m;
	reg	[7:0]		ff_refresh_addr;
	reg	[17:0]		ff_idle_timer;

	wire				w_accept;
	wire				w_done_event_42m;
	wire				w_req_event_215m;
	wire				w_m1_wait_n;
	wire				w_freeze;
	wire				w_access_memory;
	wire				w_real_access_memory;
	wire				w_access_io;
	wire				w_command_active;
	wire				w_select_active;
	wire				w_strobe_active;
	wire				w_read_active;
	wire				w_write_active;
	wire	[1:0]		w_page;
	wire	[1:0]		w_selected_slot;
	wire	[1:0]		w_selected_secondary_slot;
	wire				w_rom0_sel;
	wire	[4:0]		w_rom0_bank;
	wire				w_cs1;
	wire				w_cs2;
	wire				w_cs12;
	wire				w_rom0_ce;
	wire				w_rom1_ce;
	wire	[18:0]		w_slot_address;

	assign w_accept			= bus_valid & ~ff_bus_busy;
	assign w_done_event_42m	= ff_done_toggle_sync1 ^ ff_done_toggle_sync2;
	assign bus_ready		= ~ff_bus_busy;
	assign bus_rdata		= ff_bus_rdata;
	assign bus_rdata_en		= ff_bus_rdata_en;
	assign int_n			= slot_int_n;

	always @( posedge clk_42m ) begin
		if( !reset_n ) begin
			ff_bus_busy				<= 1'b0;
			ff_req_m1				<= 1'b0;
			ff_req_io				<= 1'b0;
			ff_req_write			<= 1'b0;
			ff_req_address			<= 16'd0;
			ff_req_wdata			<= 8'd0;
			ff_req_toggle			<= 1'b0;
		end
		else if( w_accept ) begin
			ff_bus_busy				<= 1'b1;
			ff_req_m1				<= bus_m1;
			ff_req_io				<= bus_io;
			ff_req_write			<= bus_write;
			ff_req_address			<= bus_address;
			ff_req_wdata			<= bus_wdata;
			ff_req_toggle			<= ~ff_req_toggle;
		end
		else if( w_done_event_42m ) begin
			ff_bus_busy			<= 1'b0;
		end
	end

	always @( posedge clk_42m ) begin
		if( !reset_n ) begin
			ff_done_toggle_sync0	<= 1'b0;
			ff_done_toggle_sync1	<= 1'b0;
			ff_done_toggle_sync2	<= 1'b0;
			ff_bus_rdata			<= 8'd0;
			ff_bus_rdata_en			<= 1'b0;
		end
		else begin
			ff_done_toggle_sync0	<= ff_done_toggle;
			ff_done_toggle_sync1	<= ff_done_toggle_sync0;
			ff_done_toggle_sync2	<= ff_done_toggle_sync1;
			ff_bus_rdata_en			<= 1'b0;
			if( w_done_event_42m && !ff_req_write ) begin
				ff_bus_rdata		<= ff_slot_rdata;
				ff_bus_rdata_en		<= 1'b1;
			end
		end
	end

	assign w_req_event_215m	= ff_req_toggle_sync1 ^ ff_req_toggle_sync2;
	//	M1サイクルの TW ステートで内部 /WAIT を 1回だけ主張する(カウンタで自動解除)
	assign w_m1_wait_n		= ~ff_m1_wait_active;
	assign w_freeze			= ff_busy_215m & ~( w_m1_wait_n & slot_wait_n );

	always @( posedge clk_215m ) begin
		if( !reset_n ) begin
			ff_req_toggle_sync0	<= 1'b0;
			ff_req_toggle_sync1	<= 1'b0;
			ff_req_toggle_sync2	<= 1'b0;
		end
		else begin
			ff_req_toggle_sync0	<= ff_req_toggle;
			ff_req_toggle_sync1	<= ff_req_toggle_sync0;
			ff_req_toggle_sync2	<= ff_req_toggle_sync1;
		end
	end

	//	clk_42m ドメインの primary_slot / secondary_slot を clk_215m で受ける
	always @( posedge clk_215m ) begin
		if( !reset_n ) begin
			ff_primary_slot_215m	<= 8'd0;
			ff_secondary_slot_215m	<= 8'd0;
		end
		else begin
			ff_primary_slot_215m	<= primary_slot;
			ff_secondary_slot_215m	<= secondary_slot;
		end
	end

	//	M1サイクルの TW ステートを SLTSL/CS 確定直後に 1回だけ挿入する
	always @( posedge clk_215m ) begin
		if( !reset_n ) begin
			ff_m1_wait_active	<= 1'b0;
			ff_m1_wait_count	<= 6'd0;
			ff_m1_wait_done		<= 1'b0;
		end
		else if( !ff_busy_215m ) begin
			ff_m1_wait_active	<= 1'b0;
			ff_m1_wait_done		<= 1'b0;
		end
		else if( ff_m1_wait_active ) begin
			if( ff_m1_wait_count == 6'd0 ) begin
				ff_m1_wait_active	<= 1'b0;
				ff_m1_wait_done		<= 1'b1;
			end
			else begin
				ff_m1_wait_count	<= ff_m1_wait_count - 6'd1;
			end
		end
		else if( ~high_speed_mode & ff_req_m1_215m & ~ff_m1_wait_done & (ff_access_count == c_timing_select) ) begin
			ff_m1_wait_active	<= 1'b1;
			ff_m1_wait_count	<= 6'd59;
		end
	end

	//	リフレッシュタイマア: 最後のリフレッシュ(または通常速度M1)から c_refresh_timeout 経過したらリフレッシュを要求する
	always @( posedge clk_215m ) begin
		if( !reset_n ) begin
			ff_idle_timer		<= 18'd0;
		end
		else if( ff_busy_215m & ff_req_refresh_215m ) begin
			ff_idle_timer		<= 18'd0;
		end
		else if( ff_busy_215m & ff_req_m1_215m & ~high_speed_mode & w_command_active ) begin
			ff_idle_timer		<= 18'd0;
		end
		else if( ff_idle_timer != c_refresh_timeout ) begin
			ff_idle_timer		<= ff_idle_timer + 18'd1;
		end
	end

	always @( posedge clk_215m ) begin
		if( !reset_n ) begin
			ff_slot_clock_count	<= 6'd0;
			ff_slot_clock		<= 1'b0;
		end
		else if( ff_slot_clock_count == 6'd59 ) begin
			ff_slot_clock_count	<= 6'd0;
			ff_slot_clock		<= 1'b0;
		end
		else begin
			ff_slot_clock_count	<= ff_slot_clock_count + 6'd1;
			if( ff_slot_clock_count == 6'd29 ) begin
				ff_slot_clock	<= 1'b1;
			end
		end
	end

	always @( posedge clk_215m ) begin
		if( !reset_n ) begin
			ff_req_pending_215m			<= 1'b0;
			ff_busy_215m				<= 1'b0;
			ff_req_m1_215m				<= 1'b0;
			ff_req_io_215m				<= 1'b0;
			ff_req_write_215m			<= 1'b0;
			ff_req_address_215m			<= 16'd0;
			ff_req_wdata_215m			<= 8'd0;
			ff_req_refresh_215m			<= 1'b0;
			ff_refresh_addr				<= 8'd0;
			ff_access_count				<= 8'd0;
			ff_slot_rdata				<= 8'd0;
			ff_slot_read_done			<= 1'b0;
			ff_done_toggle				<= 1'b0;
		end
		else if( !ff_busy_215m ) begin
			ff_access_count				<= c_timing_start;
			ff_slot_read_done			<= 1'b0;
			if( w_req_event_215m ) begin
				ff_req_pending_215m		<= 1'b1;
			end
			if( (ff_idle_timer == c_refresh_timeout) & (ff_slot_clock_count == 6'd0) ) begin
				ff_busy_215m				<= 1'b1;
				ff_req_refresh_215m			<= 1'b1;
				ff_req_m1_215m				<= 1'b0;
				ff_req_io_215m				<= 1'b0;
				ff_req_write_215m			<= 1'b0;
			end
			else if( (ff_req_pending_215m | w_req_event_215m) & (ff_slot_clock_count == 6'd0) ) begin
				ff_req_pending_215m			<= 1'b0;
				ff_busy_215m				<= 1'b1;
				ff_req_refresh_215m			<= 1'b0;
				ff_req_m1_215m				<= ff_req_m1;
				ff_req_io_215m				<= ff_req_io;
				ff_req_write_215m			<= ff_req_write;
				ff_req_address_215m			<= ff_req_address;
				ff_req_wdata_215m			<= ff_req_wdata;
			end
		end
		else if( w_freeze ) begin
			ff_access_count		<= ff_access_count;
		end
		else if( ff_access_count == c_timing_finish ) begin
			ff_busy_215m		<= 1'b0;
			ff_access_count		<= c_timing_start;
			if( ff_req_refresh_215m ) begin
				ff_refresh_addr		<= ff_refresh_addr + 8'd1;
			end
			else begin
				ff_done_toggle		<= ~ff_done_toggle;
			end
		end
		else begin
			ff_access_count		<= ff_access_count + 8'd1;
			if( (ff_access_count == c_timing_read_sample) & !ff_req_write_215m & !ff_slot_read_done & !ff_req_refresh_215m ) begin
				ff_slot_rdata		<= slot_d;
				ff_slot_read_done	<= 1'b1;
			end
		end
	end

	assign w_access_memory	= ff_busy_215m & ~ff_req_io_215m;
	assign w_real_access_memory	= w_access_memory & ~ff_req_refresh_215m;
	assign w_access_io		= ff_busy_215m &  ff_req_io_215m;
	assign w_command_active	= ff_busy_215m & (ff_access_count >= c_timing_command);
	assign w_select_active	= ff_busy_215m & (ff_access_count >= c_timing_select);
	assign w_strobe_active	= ff_busy_215m & (ff_access_count >= c_timing_strobe);
	assign w_read_active	= w_strobe_active & ~ff_req_write_215m;
	assign w_write_active	= w_strobe_active &  ff_req_write_215m;
	assign w_page			= ff_req_address_215m[15:14];
	assign w_selected_slot	= (w_page == 2'd0) ? ff_primary_slot_215m[1:0] :
							  (w_page == 2'd1) ? ff_primary_slot_215m[3:2] :
							  (w_page == 2'd2) ? ff_primary_slot_215m[5:4] :
											  ff_primary_slot_215m[7:6];
	assign w_cs1			= w_read_active & w_real_access_memory & (w_page == 2'd1);
	assign w_cs2			= w_read_active & w_real_access_memory & (w_page == 2'd2);
	assign w_cs12			= w_cs1 | w_cs2;
	//	SLOT#0(任意の拡張スロット) と SLOT#3-1/3-2 page1 は内部 FlashROM(ROM0) にマッピングされる
	assign w_selected_secondary_slot	= (w_page == 2'd0) ? ff_secondary_slot_215m[1:0] :
										  (w_page == 2'd1) ? ff_secondary_slot_215m[3:2] :
										  (w_page == 2'd2) ? ff_secondary_slot_215m[5:4] :
															  ff_secondary_slot_215m[7:6];
	assign w_rom0_sel		= (w_selected_slot == 2'd0) ||
							  ((w_selected_slot == 2'd3) & (w_selected_secondary_slot == 2'd1)) ||
							  ((w_selected_slot == 2'd3) & (w_selected_secondary_slot == 2'd2) & (w_page == 2'd1));
	//	SLOT#0-x は32KB(page0/1のみ)を bank 0-7 にマッピングする
	assign w_rom0_bank		= (w_selected_slot == 2'd0) ? { 2'd0, w_selected_secondary_slot, w_page[0] } :
							  ((w_selected_slot == 2'd3) & (w_selected_secondary_slot == 2'd1)) ? (5'd8 + { 3'd0, w_page }) :
							  5'd12;	//	SLOT#3-2 page1 (DiskROM): バンク切替レジスタは未実装のため BANK#0 固定
	assign w_rom0_ce		= w_select_active & w_real_access_memory & w_rom0_sel;
	assign w_rom1_ce		= 1'b0;		//	漢字ROM(ROM1)は未対応
	assign w_slot_address	= ff_req_refresh_215m ? { 11'd0, ff_refresh_addr } :
							  w_rom0_sel ? { w_rom0_bank, ff_req_address_215m[13:0] } : { 3'd0, ff_req_address_215m };

	assign slot_m1_n		= (w_command_active & ff_req_m1_215m) ? 1'b0 : 1'b1;
	assign slot_oe_n		= 1'b0;
	assign slot_clock_n		= ff_slot_clock;
	assign slot_sltsl0_n	= (w_select_active & w_real_access_memory & (w_selected_slot == 2'd0)) ? 1'b0 : 1'b1;
	assign slot_sltsl1_n	= (w_select_active & w_real_access_memory & (w_selected_slot == 2'd1)) ? 1'b0 : 1'b1;
	assign slot_sltsl2_n	= (w_select_active & w_real_access_memory & (w_selected_slot == 2'd2)) ? 1'b0 : 1'b1;
	assign slot_sltsl3_n	= (w_select_active & w_real_access_memory & (w_selected_slot == 2'd3)) ? 1'b0 : 1'b1;
	assign slot_cs1_n		= w_cs1 ? 1'b0 : 1'b1;
	assign slot_cs2_n		= w_cs2 ? 1'b0 : 1'b1;
	assign slot_cs12_n		= w_cs12 ? 1'b0 : 1'b1;
	assign slot_a			= w_slot_address;
	assign slot_reset_n		= reset_n;
	assign slot_data_dir	= (ff_busy_215m & ff_req_write_215m) ? 1'b1 : slot_busdir;
	assign slot_wr_n		= (w_write_active & (w_real_access_memory | w_access_io)) ? 1'b0 : 1'b1;
	assign slot_rd_n		= (w_read_active  & (w_real_access_memory | w_access_io)) ? 1'b0 : 1'b1;
	assign slot_rom0_ce_n	= w_rom0_ce ? 1'b0 : 1'b1;
	assign slot_rom1_ce_n	= w_rom1_ce ? 1'b0 : 1'b1;
	assign slot_rfsh_n		= (w_command_active & w_access_memory & ( (~high_speed_mode & ff_req_m1_215m) | ff_req_refresh_215m )) ? 1'b0 : 1'b1;
	assign slot_iorq_n		= (w_command_active & w_access_io) ? 1'b0 : 1'b1;
	assign slot_merq_n		= (w_command_active & w_access_memory) ? 1'b0 : 1'b1;
	assign slot_d			= (ff_busy_215m & ff_req_write_215m) ? ff_req_wdata_215m : 8'hzz;
endmodule
