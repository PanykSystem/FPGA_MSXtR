// -----------------------------------------------------------------------------
//	fpga_connect_slave.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
//	
//	 Permission is hereby granted, free of charge, to any person obtaining a 
//	copy of this software and associated documentation files (the "Software"), 
//	to deal in the Software without restriction, including without limitation 
//	the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//	and/or sell copies of the Software, and to permit persons to whom the 
//	Software is furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//	
//	The Software is provided "as is", without warranty of any kind, express or 
//	implied, including but not limited to the warranties of merchantability, 
//	fitness for a particular purpose and noninfringement. In no event shall the 
//	authors or copyright holders be liable for any claim, damages or other 
//	liability, whether in an action of contract, tort or otherwise, arising 
//	from, out of or in connection with the Software or the use or other dealings 
//	in the Software.
// -----------------------------------------------------------------------------
//	Description:
//		2つの FPGA間で情報のやり取りをするモジュール。こちらは slave 側。
//		2bit シリアル通信で、1byte のデータを送受信する。
// -----------------------------------------------------------------------------

module fpga_connect_slave (
	input			reset_n,
	input			clk,				//	85.90908MHz
	input			clk_serial,			//	214.7727MHz
	//	バス制御
	output	[7:0]	bus_address,
	output			bus_write,
	output	[7:0]	bus_wdata,
	output			bus_valid,
	input			bus_ready,
	input	[7:0]	bus_rdata,
	input			bus_rdata_en,
	//	Soundバス(output)
	output	[31:0]	sound_l,
	output	[31:0]	sound_r,
	output			sound_valid,
	input			sound_ready,
	//	FPGA通信バス
	input			fpga_si_clk,
	inout	[1:0]	fpga_si
);
	// ---------------------------------------------------------
	//	clk_serial		1010101010101010 214.7727MHz
	//	fpga_so_clk		1100110011001100  53.693175MHz
	// ---------------------------------------------------------
	localparam	[1:0]	c_mode_io_write		= 2'b00;
	localparam	[1:0]	c_mode_io_read		= 2'b01;
	localparam	[1:0]	c_mode_sound_send	= 2'b10;

	reg		[5:0]	ff_rx_bit_index;
	reg		[1:0]	ff_rx_mode;
	reg		[7:0]	ff_rx_address;
	reg		[7:0]	ff_rx_wdata;
	reg		[31:0]	ff_rx_sound_l;
	reg		[31:0]	ff_rx_sound_r;

	reg				ff_ev_io_write_toggle;
	reg				ff_ev_io_read_toggle;
	reg				ff_ev_sound_toggle;

	reg				ff_ev_io_write_sync0;
	reg				ff_ev_io_write_sync1;
	reg				ff_ev_io_write_sync2;
	reg				ff_ev_io_read_sync0;
	reg				ff_ev_io_read_sync1;
	reg				ff_ev_io_read_sync2;
	reg				ff_ev_sound_sync0;
	reg				ff_ev_sound_sync1;
	reg				ff_ev_sound_sync2;

	reg		[7:0]	ff_rx_address_sync0;
	reg		[7:0]	ff_rx_address_sync1;
	reg		[7:0]	ff_rx_wdata_sync0;
	reg		[7:0]	ff_rx_wdata_sync1;
	reg		[31:0]	ff_rx_sound_l_sync0;
	reg		[31:0]	ff_rx_sound_l_sync1;
	reg		[31:0]	ff_rx_sound_r_sync0;
	reg		[31:0]	ff_rx_sound_r_sync1;

	reg				ff_bus_valid;
	reg				ff_bus_write;
	reg		[7:0]	ff_bus_address;
	reg		[7:0]	ff_bus_wdata;
	reg				ff_bus_read_busy;

	reg		[31:0]	ff_sound_l;
	reg		[31:0]	ff_sound_r;
	reg				ff_sound_valid;
	reg				ff_sound_pending;
	reg		[31:0]	ff_sound_pending_l;
	reg		[31:0]	ff_sound_pending_r;

	reg		[7:0]	ff_read_reply_data;
	reg				ff_read_reply_toggle;
	reg		[7:0]	ff_read_reply_data_sync0;
	reg		[7:0]	ff_read_reply_data_sync1;
	reg				ff_read_reply_toggle_sync0;
	reg				ff_read_reply_toggle_sync1;
	reg				ff_read_reply_toggle_sync2;

	reg				ff_si_clk_sync0;
	reg				ff_si_clk_sync1;
	reg		[1:0]	ff_si_sync0;
	reg		[1:0]	ff_tx_pair;

	reg				ff_read_ready;
	reg				ff_read_ready_seen;

	wire	[1:0]	w_si_in;
	wire			w_ev_io_write;
	wire			w_ev_io_read;
	wire			w_ev_sound;
	wire			w_read_reply_event;
	wire			w_read_drive;
	wire			w_si_clk_rise;
	wire			w_si_clk_fall;

	function [1:0] f_get_pair8;
		input [7:0] data;
		input [1:0] index;
		begin
			case( index )
			2'd0:		f_get_pair8 = data[7:6];
			2'd1:		f_get_pair8 = data[5:4];
			2'd2:		f_get_pair8 = data[3:2];
			default:	f_get_pair8 = data[1:0];
			endcase
		end
	endfunction

	assign w_ev_io_write		= ff_ev_io_write_sync1 ^ ff_ev_io_write_sync2;
	assign w_ev_io_read			= ff_ev_io_read_sync1 ^ ff_ev_io_read_sync2;
	assign w_ev_sound			= ff_ev_sound_sync1 ^ ff_ev_sound_sync2;
	assign w_read_reply_event	= ff_read_reply_toggle_sync1 ^ ff_read_reply_toggle_sync2;
	assign w_read_drive			= (ff_rx_mode == c_mode_io_read) && (ff_rx_bit_index >= 6'd5) && (ff_rx_bit_index <= 6'd9);
	assign w_si_clk_rise		= ff_si_clk_sync0 && !ff_si_clk_sync1;
	assign w_si_clk_fall		= !ff_si_clk_sync0 && ff_si_clk_sync1;

	assign w_si_in				= ff_si_sync0;

	//	clk_serial domain: synchronize GPIO serial clock/data inputs
	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_si_clk_sync0 <= 1'b0;
			ff_si_clk_sync1 <= 1'b0;
			ff_si_sync0 <= 2'b00;
			ff_tx_pair <= 2'b00;
			ff_read_reply_data_sync0 <= 8'hFF;
			ff_read_reply_data_sync1 <= 8'hFF;
			ff_read_reply_toggle_sync0 <= 1'b0;
			ff_read_reply_toggle_sync1 <= 1'b0;
			ff_read_reply_toggle_sync2 <= 1'b0;
		end
		else begin
			ff_si_clk_sync0 <= fpga_si_clk;
			ff_si_clk_sync1 <= ff_si_clk_sync0;
			ff_si_sync0 <= fpga_si;
			ff_read_reply_data_sync0 <= ff_read_reply_data;
			ff_read_reply_data_sync1 <= ff_read_reply_data_sync0;
			ff_read_reply_toggle_sync0 <= ff_read_reply_toggle;
			ff_read_reply_toggle_sync1 <= ff_read_reply_toggle_sync0;
			ff_read_reply_toggle_sync2 <= ff_read_reply_toggle_sync1;

			if( w_si_clk_fall ) begin
				if( (ff_rx_mode == c_mode_io_read) && (ff_rx_bit_index >= 6'd5) && (ff_rx_bit_index <= 6'd9) ) begin
					if( ff_rx_bit_index == 6'd5 ) begin
						ff_tx_pair <= ff_read_ready ? 2'b11: 2'b00;
					end
					else begin
						ff_tx_pair <= f_get_pair8( ff_read_reply_data_sync1, ff_rx_bit_index[1:0] - 2'd2 );
					end
				end
				else begin
					ff_tx_pair <= 2'b00;
				end
			end
		end
	end

	//	clk_serial domain: receive serial stream (triggered by synchronized fpga_si_clk rising edge)
	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_rx_bit_index			<= 6'd0;
			ff_rx_mode				<= c_mode_io_write;
			ff_rx_address			<= 8'd0;
			ff_rx_wdata				<= 8'd0;
			ff_rx_sound_l			<= 32'd0;
			ff_rx_sound_r			<= 32'd0;
			ff_ev_io_write_toggle	<= 1'b0;
			ff_ev_io_read_toggle	<= 1'b0;
			ff_ev_sound_toggle		<= 1'b0;
			ff_read_ready			<= 1'b0;
			ff_read_ready_seen		<= 1'b0;
		end
		else begin
			if( w_read_reply_event && (ff_rx_mode == c_mode_io_read) && (ff_rx_bit_index >= 6'd5) && (ff_rx_bit_index <= 6'd9) ) begin
				ff_read_ready <= 1'b1;
			end

			if( w_si_clk_rise ) begin
				if( ff_rx_bit_index == 6'd0 ) begin
				if( (w_si_in === c_mode_io_write) || (w_si_in === c_mode_io_read) || (w_si_in === c_mode_sound_send) ) begin
					ff_rx_mode		<= w_si_in;
					if( w_si_in === c_mode_sound_send ) begin
						ff_rx_sound_l <= 32'd0;
						ff_rx_sound_r <= 32'd0;
					end
					ff_rx_bit_index	<= 6'd1;
				end
				else begin
					ff_rx_bit_index	<= 6'd0;
				end
				end
				else begin
					case( ff_rx_mode )
					c_mode_io_write: begin
						case( ff_rx_bit_index )
						6'd1: ff_rx_address[7:6] <= w_si_in;
						6'd2: ff_rx_address[5:4] <= w_si_in;
						6'd3: ff_rx_address[3:2] <= w_si_in;
						6'd4: ff_rx_address[1:0] <= w_si_in;
						6'd5: ff_rx_wdata[7:6] <= w_si_in;
						6'd6: ff_rx_wdata[5:4] <= w_si_in;
						6'd7: ff_rx_wdata[3:2] <= w_si_in;
						6'd8: ff_rx_wdata[1:0] <= w_si_in;
						default: begin end
						endcase

						if( ff_rx_bit_index == 6'd8 ) begin
							ff_ev_io_write_toggle	<= ~ff_ev_io_write_toggle;
							ff_rx_bit_index			<= 6'd0;
						end
						else begin
							ff_rx_bit_index <= ff_rx_bit_index + 6'd1;
						end
					end

					c_mode_io_read: begin
						case( ff_rx_bit_index )
						6'd1: ff_rx_address[7:6] <= w_si_in;
						6'd2: ff_rx_address[5:4] <= w_si_in;
						6'd3: ff_rx_address[3:2] <= w_si_in;
						6'd4: ff_rx_address[1:0] <= w_si_in;
						default: begin end
						endcase

						if( ff_rx_bit_index == 6'd4 ) begin
							ff_ev_io_read_toggle	<= ~ff_ev_io_read_toggle;
							ff_read_ready			<= 1'b0;
							ff_read_ready_seen	<= 1'b0;
							ff_rx_bit_index			<= 6'd5;
						end
						else if( ff_rx_bit_index == 6'd5 ) begin
							if( ff_read_ready ) begin
								if( ff_read_ready_seen ) begin
									ff_rx_bit_index <= 6'd6;
								end
								else begin
									ff_read_ready_seen <= 1'b1;
									ff_rx_bit_index <= 6'd5;
								end
							end
							else begin
								ff_rx_bit_index <= 6'd5;
							end
						end
						else if( ff_rx_bit_index == 6'd9 ) begin
							ff_rx_bit_index		<= 6'd0;
							ff_read_ready		<= 1'b0;
							ff_read_ready_seen	<= 1'b0;
						end
						else begin
							ff_rx_bit_index <= ff_rx_bit_index + 6'd1;
						end
					end

					c_mode_sound_send: begin
						if( ff_rx_bit_index <= 6'd16 ) begin
							ff_rx_sound_l <= { ff_rx_sound_l[29:0], w_si_in };
						end
						else if( ff_rx_bit_index <= 6'd32 ) begin
							ff_rx_sound_r <= { ff_rx_sound_r[29:0], w_si_in };
						end

						if( ff_rx_bit_index == 6'd32 ) begin
							ff_ev_sound_toggle	<= ~ff_ev_sound_toggle;
							ff_rx_bit_index		<= 6'd0;
						end
						else begin
							ff_rx_bit_index <= ff_rx_bit_index + 6'd1;
						end
					end

					default: begin
						ff_rx_bit_index <= 6'd0;
					end
					endcase
				end
			end
		end
	end

	//	clk domain: synchronize receive payload and events
	always @( posedge clk ) begin
		ff_ev_io_write_sync0	<= ff_ev_io_write_toggle;
		ff_ev_io_write_sync1	<= ff_ev_io_write_sync0;
		ff_ev_io_write_sync2	<= ff_ev_io_write_sync1;

		ff_ev_io_read_sync0		<= ff_ev_io_read_toggle;
		ff_ev_io_read_sync1		<= ff_ev_io_read_sync0;
		ff_ev_io_read_sync2		<= ff_ev_io_read_sync1;

		ff_ev_sound_sync0		<= ff_ev_sound_toggle;
		ff_ev_sound_sync1		<= ff_ev_sound_sync0;
		ff_ev_sound_sync2		<= ff_ev_sound_sync1;

		ff_rx_address_sync0		<= ff_rx_address;
		ff_rx_address_sync1		<= ff_rx_address_sync0;
		ff_rx_wdata_sync0		<= ff_rx_wdata;
		ff_rx_wdata_sync1		<= ff_rx_wdata_sync0;
		ff_rx_sound_l_sync0		<= ff_rx_sound_l;
		ff_rx_sound_l_sync1		<= ff_rx_sound_l_sync0;
		ff_rx_sound_r_sync0		<= ff_rx_sound_r;
		ff_rx_sound_r_sync1		<= ff_rx_sound_r_sync0;
	end

	//	clk domain: bus request engine
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_valid		<= 1'b0;
			ff_bus_write		<= 1'b0;
			ff_bus_address		<= 8'd0;
			ff_bus_wdata		<= 8'd0;
			ff_bus_read_busy	<= 1'b0;
			ff_read_reply_data	<= 8'hFF;
			ff_read_reply_toggle	<= 1'b0;
		end
		else begin
			if( !ff_bus_valid && !ff_bus_read_busy && w_ev_io_write ) begin
				ff_bus_valid	<= 1'b1;
				ff_bus_write	<= 1'b1;
				ff_bus_address	<= ff_rx_address_sync1;
				ff_bus_wdata	<= ff_rx_wdata_sync1;
			end
			else if( !ff_bus_valid && !ff_bus_read_busy && w_ev_io_read ) begin
				ff_bus_valid		<= 1'b1;
				ff_bus_write		<= 1'b0;
				ff_bus_address		<= ff_rx_address_sync1;
				ff_bus_wdata		<= 8'd0;
				ff_bus_read_busy	<= 1'b1;
			end

			if( ff_bus_valid ) begin
				if( ff_bus_write ) begin
					if( bus_ready ) begin
						ff_bus_valid <= 1'b0;
					end
				end
				else if( bus_rdata_en ) begin
					ff_bus_valid			<= 1'b0;
					ff_bus_read_busy		<= 1'b0;
					ff_read_reply_data		<= bus_rdata;
					ff_read_reply_toggle	<= ~ff_read_reply_toggle;
				end
			end
			else if( ff_bus_read_busy && bus_rdata_en ) begin
				ff_bus_read_busy		<= 1'b0;
				ff_read_reply_data		<= bus_rdata;
				ff_read_reply_toggle	<= ~ff_read_reply_toggle;
			end
		end
	end

	//	clk domain: sound output engine
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_sound_l			<= 32'd0;
			ff_sound_r			<= 32'd0;
			ff_sound_valid		<= 1'b0;
			ff_sound_pending	<= 1'b0;
			ff_sound_pending_l	<= 32'd0;
			ff_sound_pending_r	<= 32'd0;
		end
		else begin
			ff_sound_valid <= 1'b0;

			if( w_ev_sound ) begin
				ff_sound_pending	<= 1'b1;
				ff_sound_pending_l	<= ff_rx_sound_l_sync1;
				ff_sound_pending_r	<= ff_rx_sound_r_sync1;
			end

			if( ff_sound_pending && sound_ready ) begin
				ff_sound_pending	<= 1'b0;
				ff_sound_l			<= ff_sound_pending_l;
				ff_sound_r			<= ff_sound_pending_r;
				ff_sound_valid		<= 1'b1;
			end
		end
	end

	assign bus_address	= ff_bus_address;
	assign bus_write	= ff_bus_write;
	assign bus_wdata	= ff_bus_wdata;
	assign bus_valid	= ff_bus_valid;
	assign sound_l		= ff_sound_l;
	assign sound_r		= ff_sound_r;
	assign sound_valid	= ff_sound_valid;
	assign fpga_si		= w_read_drive ? ff_tx_pair : 2'bzz;

endmodule
