// -----------------------------------------------------------------------------
//	fpga_connect_master.v
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
//		2縺､縺ｮ FPGA髢薙〒諠・ｱ縺ｮ繧・ｊ蜿悶ｊ繧偵☆繧九Δ繧ｸ繝･繝ｼ繝ｫ縲ょ曙譁ｹ縺ｫ蜷後§繧ゅ・繧呈政霈峨・// -----------------------------------------------------------------------------

module fpga_connect_master (
	input			reset_n,
	input			clk,				//	85.90908MHz
	input			clk_serial,			//	214.7727MHz
	//	蜀・Κ繝舌せ
	input	[7:0]	bus_address,
	input			bus_write,
	input	[7:0]	bus_wdata,
	input			bus_valid,
	output			bus_ready,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	//	Sound繝舌せ(input)
	input	[31:0]	sound_l,
	input	[31:0]	sound_r,
	input			sound_valid,
	output			sound_ready,
	//	FPGA騾壻ｿ｡繝舌せ
	output			fpga_so_clk,
	inout	[1:0]	fpga_so
);
	// ---------------------------------------------------------
	//	clk_serial		1010101010101010 214.7727MHz
	//	fpga_so_clk		1100110011001100  53.693175MHz
	// ---------------------------------------------------------
	localparam	[1:0]	c_mode_io_write		= 2'b00;
	localparam	[1:0]	c_mode_io_read		= 2'b01;
	localparam	[1:0]	c_mode_sound_send	= 2'b10;

	reg				ff_req_busy;
	reg		[1:0]	ff_req_mode;
	reg		[7:0]	ff_req_address;
	reg		[7:0]	ff_req_wdata;
	reg		[31:0]	ff_req_sound_l;
	reg		[31:0]	ff_req_sound_r;
	reg				ff_req_toggle;

	reg				ff_ack_toggle_sync0;
	reg				ff_ack_toggle_sync1;
	reg				ff_ack_toggle_sync2;

	reg				ff_rsp_toggle_sync0;
	reg				ff_rsp_toggle_sync1;
	reg				ff_rsp_toggle_sync2;
	reg		[7:0]	ff_rsp_rdata_sync0;
	reg		[7:0]	ff_rsp_rdata_sync1;

	reg		[7:0]	ff_bus_rdata;
	reg				ff_bus_rdata_en;
	reg		[4:0]	ff_read_wait_count;
	reg				ff_abort_toggle;

	reg				ff_req_toggle_sync0;
	reg				ff_req_toggle_sync1;
	reg				ff_req_toggle_sync2;
	reg				ff_read_wait_sync0;
	reg				ff_read_wait_sync1;
	reg				ff_read_wait_sync2;

	reg		[1:0]	ff_req_mode_sync0;
	reg		[1:0]	ff_req_mode_sync1;
	reg		[7:0]	ff_req_address_sync0;
	reg		[7:0]	ff_req_address_sync1;
	reg		[7:0]	ff_req_wdata_sync0;
	reg		[7:0]	ff_req_wdata_sync1;
	reg		[31:0]	ff_req_sound_l_sync0;
	reg		[31:0]	ff_req_sound_l_sync1;
	reg		[31:0]	ff_req_sound_r_sync0;
	reg		[31:0]	ff_req_sound_r_sync1;

	reg		[1:0]	ff_div_counter;
	reg				ff_tx_busy;
	reg		[1:0]	ff_tx_mode;
	reg		[7:0]	ff_tx_address;
	reg		[7:0]	ff_tx_wdata;
	reg		[31:0]	ff_tx_sound_l;
	reg		[31:0]	ff_tx_sound_r;
	reg				ff_tx_pending;
	reg		[1:0]	ff_tx_pending_mode;
	reg		[7:0]	ff_tx_pending_address;
	reg		[7:0]	ff_tx_pending_wdata;
	reg		[31:0]	ff_tx_pending_sound_l;
	reg		[31:0]	ff_tx_pending_sound_r;
	reg		[5:0]	ff_tx_bit_index;
	reg				ff_tx_first_rise;
	reg				ff_tx_wait_read;
	reg		[1:0]	ff_so_out;
	reg				ff_so_oe;
	reg		[7:0]	ff_rx_rdata;
	reg				ff_ack_toggle;
	reg				ff_rsp_toggle;
	reg				ff_abort_toggle_sync0;
	reg				ff_abort_toggle_sync1;
	reg				ff_abort_toggle_sync2;

	wire			w_clk_rise;
	wire		[1:0]	w_so_in;
	wire			w_req_event;
	wire			w_ack_event;
	wire			w_rsp_event;
	wire			w_read_wait;
	wire			w_abort_event;

	function [1:0] f_get_pair8;
		input [7:0] data;
		input [1:0] index;
		begin
			case( index )
			2'd0: f_get_pair8 = data[7:6];
			2'd1: f_get_pair8 = data[5:4];
			2'd2: f_get_pair8 = data[3:2];
			default: f_get_pair8 = data[1:0];
			endcase
		end
	endfunction

	function [1:0] f_get_pair32;
		input [31:0] data;
		input [3:0] index;
		begin
			case( index )
			4'd0: f_get_pair32 = data[31:30];
			4'd1: f_get_pair32 = data[29:28];
			4'd2: f_get_pair32 = data[27:26];
			4'd3: f_get_pair32 = data[25:24];
			4'd4: f_get_pair32 = data[23:22];
			4'd5: f_get_pair32 = data[21:20];
			4'd6: f_get_pair32 = data[19:18];
			4'd7: f_get_pair32 = data[17:16];
			4'd8: f_get_pair32 = data[15:14];
			4'd9: f_get_pair32 = data[13:12];
			4'd10: f_get_pair32 = data[11:10];
			4'd11: f_get_pair32 = data[9:8];
			4'd12: f_get_pair32 = data[7:6];
			4'd13: f_get_pair32 = data[5:4];
			4'd14: f_get_pair32 = data[3:2];
			default: f_get_pair32 = data[1:0];
			endcase
		end
	endfunction

	task t_set_output;
		input [1:0] mode;
		input [5:0] bit_index;
		begin
			ff_so_oe	<= 1'b1;
			case( mode )
			c_mode_io_write: begin
				if( bit_index == 6'd0 ) begin
					ff_so_out <= mode;
				end
				else if( bit_index <= 6'd4 ) begin
					ff_so_out <= f_get_pair8( ff_tx_address, bit_index[1:0] - 2'd1 );
				end
				else begin
					ff_so_out <= f_get_pair8( ff_tx_wdata, bit_index[1:0] - 2'd1 );
				end
			end
			c_mode_io_read: begin
				if( bit_index == 6'd0 ) begin
					ff_so_out <= mode;
					ff_so_oe	<= 1'b1;
				end
				else if( bit_index <= 6'd4 ) begin
					ff_so_out <= f_get_pair8( ff_tx_address, bit_index[1:0] - 2'd1 );
					ff_so_oe	<= 1'b1;
				end
				else begin
					ff_so_out <= 2'b00;
					ff_so_oe	<= 1'b0;
				end
			end
			default: begin
				if( bit_index == 6'd0 ) begin
					ff_so_out <= mode;
				end
				else if( bit_index <= 6'd16 ) begin
					ff_so_out <= f_get_pair32( ff_tx_sound_l, bit_index[3:0] - 4'd1 );
				end
				else begin
					ff_so_out <= f_get_pair32( ff_tx_sound_r, bit_index[3:0] - 4'd1 );
				end
			end
			endcase
		end
	endtask

	assign w_clk_rise	= (ff_div_counter == 2'd3);
	assign w_so_in		= fpga_so;
	assign w_req_event	= ff_req_toggle_sync1 ^ ff_req_toggle_sync2;
	assign w_ack_event	= ff_ack_toggle_sync1 ^ ff_ack_toggle_sync2;
	assign w_rsp_event	= ff_rsp_toggle_sync1 ^ ff_rsp_toggle_sync2;
	assign w_read_wait	= ff_read_wait_sync1;
	assign w_abort_event	= ff_abort_toggle_sync1 ^ ff_abort_toggle_sync2;

	//	clk domain: transaction request generation
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_req_busy		<= 1'b0;
			ff_req_mode		<= c_mode_io_write;
			ff_req_address	<= 8'd0;
			ff_req_wdata	<= 8'd0;
			ff_req_sound_l	<= 32'd0;
			ff_req_sound_r	<= 32'd0;
			ff_req_toggle	<= 1'b0;
		end
		else if( w_ack_event ) begin
			ff_req_busy <= 1'b0;
		end
		else if( !ff_req_busy && bus_valid ) begin
			ff_req_busy		<= 1'b1;
			ff_req_mode		<= bus_write ? c_mode_io_write : c_mode_io_read;
			ff_req_address	<= bus_address;
			ff_req_wdata	<= bus_wdata;
			ff_req_toggle	<= ~ff_req_toggle;
		end
		else if( !ff_req_busy && sound_valid ) begin
			ff_req_busy		<= 1'b1;
			ff_req_mode		<= c_mode_sound_send;
			ff_req_sound_l	<= sound_l;
			ff_req_sound_r	<= sound_r;
			ff_req_toggle	<= ~ff_req_toggle;
		end
	end

	//	clk domain: response capture
	always @( posedge clk ) begin
		ff_ack_toggle_sync0	<= ff_ack_toggle;
		ff_ack_toggle_sync1	<= ff_ack_toggle_sync0;
		ff_ack_toggle_sync2	<= ff_ack_toggle_sync1;

		ff_rsp_toggle_sync0	<= ff_rsp_toggle;
		ff_rsp_toggle_sync1	<= ff_rsp_toggle_sync0;
		ff_rsp_toggle_sync2	<= ff_rsp_toggle_sync1;
		ff_rsp_rdata_sync0	<= ff_rx_rdata;
		ff_rsp_rdata_sync1	<= ff_rsp_rdata_sync0;
		ff_read_wait_sync0	<= ff_tx_wait_read;
		ff_read_wait_sync1	<= ff_read_wait_sync0;
		ff_read_wait_sync2	<= ff_read_wait_sync1;
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_rdata		<= 8'd0;
			ff_bus_rdata_en	<= 1'b0;
			ff_read_wait_count	<= 5'd0;
			ff_abort_toggle	<= 1'b0;
		end
		else if( w_rsp_event ) begin
			ff_bus_rdata		<= ff_rsp_rdata_sync1;
			ff_bus_rdata_en	<= 1'b1;
			ff_read_wait_count	<= 5'd0;
		end
		else if( w_ack_event ) begin
			ff_bus_rdata_en	<= 1'b0;
			ff_read_wait_count	<= 5'd0;
		end
		else if( w_read_wait ) begin
			ff_bus_rdata_en	<= 1'b0;
			if( ff_read_wait_count == 5'd15 ) begin
				ff_read_wait_count	<= 5'd0;
				ff_abort_toggle	<= ~ff_abort_toggle;
			end
			else begin
				ff_read_wait_count	<= ff_read_wait_count + 5'd1;
			end
		end
		else begin
			ff_bus_rdata_en	<= 1'b0;
			ff_read_wait_count	<= 5'd0;
		end
	end

	//	clk_serial domain: synchronize request payload
	always @( posedge clk_serial ) begin
		ff_req_toggle_sync0	<= ff_req_toggle;
		ff_req_toggle_sync1	<= ff_req_toggle_sync0;
		ff_req_toggle_sync2	<= ff_req_toggle_sync1;

		ff_req_mode_sync0		<= ff_req_mode;
		ff_req_mode_sync1		<= ff_req_mode_sync0;
		ff_req_address_sync0	<= ff_req_address;
		ff_req_address_sync1	<= ff_req_address_sync0;
		ff_req_wdata_sync0		<= ff_req_wdata;
		ff_req_wdata_sync1		<= ff_req_wdata_sync0;
		ff_req_sound_l_sync0	<= ff_req_sound_l;
		ff_req_sound_l_sync1	<= ff_req_sound_l_sync0;
		ff_req_sound_r_sync0	<= ff_req_sound_r;
		ff_req_sound_r_sync1	<= ff_req_sound_r_sync0;

		ff_abort_toggle_sync0	<= ff_abort_toggle;
		ff_abort_toggle_sync1	<= ff_abort_toggle_sync0;
		ff_abort_toggle_sync2	<= ff_abort_toggle_sync1;
	end

	//	clk_serial domain: serial transfer engine
	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_div_counter	<= 2'd0;
			ff_tx_busy		<= 1'b0;
			ff_tx_pending	<= 1'b0;
			ff_tx_mode		<= c_mode_io_write;
			ff_tx_address	<= 8'd0;
			ff_tx_wdata		<= 8'd0;
			ff_tx_sound_l	<= 32'd0;
			ff_tx_sound_r	<= 32'd0;
			ff_tx_pending_mode		<= c_mode_io_write;
			ff_tx_pending_address	<= 8'd0;
			ff_tx_pending_wdata		<= 8'd0;
			ff_tx_pending_sound_l	<= 32'd0;
			ff_tx_pending_sound_r	<= 32'd0;
			ff_tx_bit_index	<= 6'd0;
			ff_tx_first_rise	<= 1'b0;
			ff_tx_wait_read	<= 1'b0;
			ff_so_out		<= 2'b00;
			ff_so_oe		<= 1'b0;
			ff_rx_rdata		<= 8'd0;
			ff_ack_toggle	<= 1'b0;
			ff_rsp_toggle	<= 1'b0;
		end
		else begin
			ff_div_counter <= ff_div_counter + 2'd1;
			ff_tx_wait_read <= 1'b0;

			if( w_req_event ) begin
				ff_tx_pending			<= 1'b1;
				ff_tx_pending_mode	<= ff_req_mode_sync1;
				ff_tx_pending_address	<= ff_req_address_sync1;
				ff_tx_pending_wdata	<= ff_req_wdata_sync1;
				ff_tx_pending_sound_l	<= ff_req_sound_l_sync1;
				ff_tx_pending_sound_r	<= ff_req_sound_r_sync1;
			end

			if( !ff_tx_busy && ff_tx_pending ) begin
				ff_div_counter	<= 2'd2;
				ff_tx_busy		<= 1'b1;
				ff_tx_pending	<= 1'b0;
				ff_tx_mode		<= ff_tx_pending_mode;
				ff_tx_address	<= ff_tx_pending_address;
				ff_tx_wdata		<= ff_tx_pending_wdata;
				ff_tx_sound_l	<= ff_tx_pending_sound_l;
				ff_tx_sound_r	<= ff_tx_pending_sound_r;
				ff_tx_bit_index	<= 6'd0;
				ff_tx_first_rise	<= 1'b1;
				t_set_output( ff_tx_pending_mode, 6'd0 );
			end
			else if( ff_tx_busy && w_abort_event ) begin
				ff_tx_busy	<= 1'b0;
				ff_tx_first_rise	<= 1'b0;
				ff_tx_wait_read	<= 1'b0;
				ff_so_oe		<= 1'b0;
				ff_ack_toggle	<= ~ff_ack_toggle;
			end
			else if( ff_tx_busy && w_clk_rise ) begin
				if( ff_tx_first_rise ) begin
					ff_tx_first_rise <= 1'b0;
					t_set_output( ff_tx_mode, 6'd0 );
				end
				else begin
				if( ff_tx_mode == c_mode_io_read ) begin
					case( ff_tx_bit_index )
					6'd6: ff_rx_rdata[7:6] <= w_so_in;
					6'd7: ff_rx_rdata[5:4] <= w_so_in;
					6'd8: ff_rx_rdata[3:2] <= w_so_in;
					6'd9: ff_rx_rdata[1:0] <= w_so_in;
					default: begin end
					endcase
				end

				if( (ff_tx_mode == c_mode_sound_send && ff_tx_bit_index == 6'd32) ||
					(ff_tx_mode == c_mode_io_write && ff_tx_bit_index == 6'd8) ||
					(ff_tx_mode == c_mode_io_read && ff_tx_bit_index == 6'd9) ) begin
					ff_tx_busy	<= 1'b0;
					ff_tx_first_rise	<= 1'b0;
					ff_so_oe		<= 1'b0;
					ff_ack_toggle	<= ~ff_ack_toggle;
					if( ff_tx_mode == c_mode_io_read ) begin
						ff_rsp_toggle <= ~ff_rsp_toggle;
					end
				end
				else if( ff_tx_mode == c_mode_io_read && ff_tx_bit_index == 6'd5 && w_so_in != 2'b11 ) begin
					ff_tx_wait_read <= 1'b1;
					ff_tx_bit_index <= 6'd5;
					t_set_output( ff_tx_mode, 6'd5 );
				end
				else begin
					ff_tx_bit_index <= ff_tx_bit_index + 6'd1;
					t_set_output( ff_tx_mode, ff_tx_bit_index + 6'd1 );
				end
				end
			end
		end
	end

	assign bus_ready		= ~ff_req_busy;
	assign bus_rdata		= ff_bus_rdata;
	assign bus_rdata_en		= ff_bus_rdata_en;
	assign sound_ready		= ~ff_req_busy & ~bus_valid;
	assign fpga_so_clk		= ff_tx_busy ? ~ff_div_counter[1] : 1'b1;
	assign fpga_so			= ff_so_oe ? ff_so_out : 2'bzz;

endmodule
