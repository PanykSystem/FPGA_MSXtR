// -----------------------------------------------------------------------------
//	fpga_connect_master_sub.v
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
//		fpga_connect_master の 2bit シリアル送受信サブモジュール
//		mode:
//			00: モードビット送信
//				tx_data[1:0] = 00: I/O write
//				tx_data[1:0] = 01: I/O read
//				tx_data[1:0] = 10: Sound Send
//				tx_data[1:0] = 11: Sound Receive
//			01: 1byte 送信
//				tx_data[7:0] = 送信するデータ
//			10: 1byte 受信
//				rx_data[7:0] = 受信したデータ
//			11: 2bit受信(相手側ステータス取得)
// -----------------------------------------------------------------------------

module fpga_connect_master_sub (
	input			reset_n,
	input			clk_serial,
	input			tx_cs,
	input			start,
	input	[1:0]	mode,
	input	[7:0]	tx_data,
	inout	[1:0]	so,
	output			so_clk,
	output			busy,
	output			done,
	output			wait_read,
	output	[7:0]	rx_data,
	output			so_oe,
	output			rx_data_en
);
	localparam	[1:0]	c_mode_tx_mode		= 2'b00;
	localparam	[1:0]	c_mode_tx_byte		= 2'b01;
	localparam	[1:0]	c_mode_rx_byte		= 2'b10;
	localparam	[1:0]	c_mode_rx_status	= 2'b11;

	reg				ff_busy;
	reg				ff_done;
	reg				ff_wait_read;
	reg		[1:0]	ff_mode;
	reg		[7:0]	ff_tx_data;
	reg		[7:0]	ff_rx_data;
	reg		[1:0]	ff_pair_index;
	reg		[1:0]	ff_so_out;
	reg				ff_so_oe;
	reg				ff_rx_data_en;
	reg		[1:0]	ff_div_counter;
	wire	[1:0]	w_so_in;

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

	//	serial timing generator (moved from parent module)
	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_div_counter <= 2'd0;
		end
		else if( start ) begin
			ff_div_counter <= 2'd0;
		end
		else if( tx_cs && ff_busy ) begin
			ff_div_counter <= ff_div_counter + 2'd1;
		end
		else begin
			ff_div_counter <= 2'd0;
		end
	end

	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_busy			<= 1'b0;
			ff_done			<= 1'b0;
			ff_wait_read	<= 1'b0;
			ff_mode			<= c_mode_tx_mode;
			ff_tx_data		<= 8'd0;
			ff_rx_data		<= 8'd0;
			ff_pair_index	<= 2'd0;
			ff_so_out		<= 2'b00;
			ff_so_oe		<= 1'b0;
			ff_rx_data_en	<= 1'b0;
		end
		else begin
			ff_wait_read	<= 1'b0;
			ff_done			<= 1'b0;

			if( start && !ff_busy ) begin
				ff_busy			<= 1'b1;
				ff_rx_data_en	<= 1'b0;
				ff_mode			<= mode;
				ff_tx_data		<= tx_data;
				if( mode == c_mode_tx_mode ) begin
					ff_pair_index	<= 2'd0;
					ff_so_oe		<= 1'b1;
					ff_so_out		<= tx_data[1:0];
				end
				else if( mode == c_mode_tx_byte ) begin
					ff_pair_index	<= 2'd0;
					ff_so_oe		<= 1'b1;
					ff_so_out		<= tx_data[7:6];
				end
				else begin
					ff_pair_index	<= 2'd0;
					ff_so_oe		<= 1'b0;
					ff_so_out		<= 2'b00;
				end
			end
			else if( ff_busy && (ff_div_counter == 2'd2) ) begin
				case( ff_mode )
					c_mode_tx_mode: begin
						ff_done		<= 1'b1;
					end

					c_mode_tx_byte: begin
						if( ff_pair_index == 2'd3 ) begin
							ff_done		<= 1'b1;
						end
					end

					c_mode_rx_byte: begin
						ff_rx_data			<= { ff_rx_data[5:0], w_so_in };

						if( ff_pair_index == 2'd3 ) begin
							ff_done			<= 1'b1;
							ff_rx_data_en	<= 1'b1;
						end
					end

					default: begin
						ff_done		<= 1'b1;
					end
				endcase
			end
			else if( ff_busy && (ff_div_counter == 2'd3) ) begin
				ff_done		<= 1'b0;

				case( ff_mode )
					c_mode_tx_mode: begin
						ff_so_oe	<= 1'b0;
						ff_busy		<= 1'b0;
					end

					c_mode_tx_byte: begin
						if( ff_pair_index == 2'd3 ) begin
							ff_so_oe	<= 1'b0;
							ff_busy		<= 1'b0;
						end
						else begin
							ff_pair_index	<= ff_pair_index + 2'd1;
							ff_so_out		<= {  ff_tx_data[5:0], 2'd0 };
						end
					end

					c_mode_rx_byte: begin
						if( ff_pair_index == 2'd3 ) begin
							ff_busy			<= 1'b0;
							ff_rx_data_en	<= 1'b0;
						end
						else begin
							ff_pair_index	<= ff_pair_index + 2'd1;
						end
					end

					default: begin
						ff_rx_data[7:2]	<= 6'd0;
						ff_rx_data[1:0]	<= w_so_in;
						ff_busy			<= 1'b0;
						ff_done			<= 1'b0;
						ff_rx_data_en	<= 1'b1;
					end
				endcase
			end
			else if( !tx_cs && !ff_busy ) begin
				ff_so_oe	<= 1'b0;
			end
		end
	end

	assign busy			= ff_busy;
	assign done			= ff_done;
	assign wait_read	= ff_wait_read;
	assign rx_data		= ff_rx_data;
	assign so_oe		= ff_so_oe;
	assign rx_data_en	= ff_rx_data_en;
	assign so_clk		= (tx_cs && ff_busy) ? ~ff_div_counter[1] : 1'b0;
	assign so			= ff_so_oe ? ff_so_out : 2'bzz;
	assign w_so_in		= so;
endmodule
