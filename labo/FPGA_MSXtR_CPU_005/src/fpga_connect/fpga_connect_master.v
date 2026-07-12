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
//		2つの FPGA間で情報のやり取りをするモジュール。こちらは master 側。
//		2bit シリアル通信で、1byte のデータを送受信する。
// -----------------------------------------------------------------------------

module fpga_connect_master (
	input			reset_n,
	input			clk,				//	85.90908MHz
	input			clk_serial,			//	214.7727MHz
	//	内部バス
	input			bus_cs,
	input	[7:0]	bus_address,
	input			bus_write,
	input	[7:0]	bus_wdata,
	input			bus_valid,
	output			bus_ready,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	//	Soundバス(input)
	input	[31:0]	sound_l,
	input	[31:0]	sound_r,
	input			sound_valid,
	output			sound_ready,
	//	FPGA通信バス
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

	localparam	[1:0]	c_sub_mode_tx_mode	= 2'b00;
	localparam	[1:0]	c_sub_mode_tx_byte	= 2'b01;
	localparam	[1:0]	c_sub_mode_rx_byte	= 2'b10;
	localparam	[1:0]	c_sub_mode_rx_status	= 2'b11;

	localparam	[3:0]	c_st_idle			= 4'd0;
	localparam	[3:0]	c_st_iow_mode		= 4'd1;
	localparam	[3:0]	c_st_iow_addr		= 4'd2;
	localparam	[3:0]	c_st_iow_data		= 4'd3;
	localparam	[3:0]	c_st_ior_mode		= 4'd4;
	localparam	[3:0]	c_st_ior_addr		= 4'd5;
	localparam	[3:0]	c_st_ior_stat		= 4'd6;
	localparam	[3:0]	c_st_ior_data		= 4'd7;
	localparam	[3:0]	c_st_snd_mode		= 4'd8;
	localparam	[3:0]	c_st_snd_byte		= 4'd9;
	localparam	[3:0]	c_st_wait_done		= 4'd10;

	reg				ff_priority;
	reg				ff_serial_busy;

	reg		[3:0]	ff_state;
	reg				ff_done;

	reg				ff_sub_tx_active;
	reg				ff_sub_start;
	reg		[1:0]	ff_sub_mode;
	reg		[7:0]	ff_sub_tx_data;

	wire			w_sub_tx_active;
	wire			w_sub_start;
	wire	[1:0]	w_sub_mode;
	wire	[7:0]	w_sub_tx_data;
	wire			w_sub_busy;
	wire			w_sub_done;
	wire			w_sub_wait_read;
	wire	[7:0]	w_sub_rx_data;
	wire			w_sub_so_oe;
	wire			w_sub_rx_data_en;
	wire			w_sub_so_clk;

	reg		[1:0]	ff_req_mode;
	reg		[7:0]	ff_req_bus_address;
	reg		[7:0]	ff_req_bus_wdata;
	reg		[31:0]	ff_req_sound_l;
	reg		[31:0]	ff_req_sound_r;
	reg		[2:0]	ff_sound_index;

	reg		[7:0]	ff_bus_rdata;
	reg				ff_bus_rdata_en;

	wire			w_idle;

	function [7:0] f_sound_tx_byte;
		input [31:0] sound_l_data;
		input [31:0] sound_r_data;
		input [2:0] index;
		begin
			case( index )
			3'd0:		f_sound_tx_byte = sound_l_data[31:24];
			3'd1:		f_sound_tx_byte = sound_l_data[23:16];
			3'd2:		f_sound_tx_byte = sound_l_data[15:8];
			3'd3:		f_sound_tx_byte = sound_l_data[7:0];
			3'd4:		f_sound_tx_byte = sound_r_data[31:24];
			3'd5:		f_sound_tx_byte = sound_r_data[23:16];
			3'd6:		f_sound_tx_byte = sound_r_data[15:8];
			default:	f_sound_tx_byte = sound_r_data[7:0];
			endcase
		end
	endfunction

	assign w_sub_tx_active	= ff_sub_tx_active;
	assign w_sub_start		= ff_sub_start;
	assign w_sub_mode		= ff_sub_mode;
	assign w_sub_tx_data	= ff_sub_tx_data;

	assign w_idle			= (ff_state == c_st_idle);

	assign bus_rdata		= ff_bus_rdata;
	assign bus_rdata_en		= ff_bus_rdata_en;
	assign fpga_so_clk		= w_sub_so_clk;

	// ---------------------------------------------------------
	//	bus信号を扱うブロック (クロックドメイン: clk)
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_priority			<= 1'b0;
			ff_serial_busy		<= 1'b0;
			ff_bus_rdata_en		<= 1'b0;
		end
		else begin
			if( ff_bus_rdata_en ) begin
				ff_bus_rdata_en		<= 1'b0;
			end
			else if( ff_serial_busy ) begin
				//	通信が完了するのを待つ
				if( ff_done ) begin
					ff_serial_busy		<= 1'b0;
					if( ff_req_mode == c_mode_io_read ) begin
						ff_bus_rdata_en		<= 1'b1;
					end
					else begin
						ff_bus_rdata_en		<= 1'b0;
					end
				end
			end
			else begin
				//	要求が来るのを待つ
				if( bus_valid || sound_valid ) begin
					//	両方の要求が来た場合は、優先順位を入れ替える
					ff_priority			<= ~ff_priority;
					ff_serial_busy		<= 1'b1;
					if( bus_valid && (!ff_priority || !sound_valid) ) begin
						//	内部バス優先の場合
						ff_req_bus_address	<= bus_address;
						ff_req_bus_wdata	<= bus_wdata;
						ff_req_mode			<= bus_write ? c_mode_io_write: c_mode_io_read;
					end
					else if( sound_valid && (ff_priority || !bus_valid) ) begin
						//	Soundバス優先の場合
						ff_req_sound_l		<= sound_l;
						ff_req_sound_r		<= sound_r;
						ff_req_mode			<= c_mode_sound_send;
					end
				end
			end
		end
	end

	assign bus_ready		= ff_serial_busy ? 1'b0: (!ff_priority || !sound_valid);
	assign sound_ready		= ff_serial_busy ? 1'b0: ( ff_priority || !bus_valid  );

	// ---------------------------------------------------------
	//	制御用ステートマシン（クロックドメイン：clk_serial）
	// ---------------------------------------------------------
	always @( posedge clk_serial ) begin
		if( !reset_n ) begin
			ff_state				<= c_st_idle;
			ff_sub_tx_active		<= 1'b0;
			ff_sub_start			<= 1'b0;
			ff_sub_mode				<= c_sub_mode_tx_mode;
			ff_sub_tx_data			<= 8'd0;
			ff_sound_index			<= 3'd0;
			ff_done					<= 1'b0;
			ff_bus_rdata			<= 8'd0;
		end
		else if( ff_sub_start ) begin
			ff_sub_start			<= 1'b0;
		end
		else begin
			if( w_sub_rx_data_en ) begin
				ff_bus_rdata			<= w_sub_rx_data;
			end

			case( ff_state )
				c_st_idle: begin
					ff_sub_tx_active		<= 1'b0;

					if( ff_serial_busy ) begin
						//	通信開始の要求が来た場合
						case( ff_req_mode )
							c_mode_io_write: begin
								//	I/O Write モードの開始
								ff_sub_tx_active		<= 1'b1;
								ff_sub_start			<= 1'b1;
								ff_sub_mode				<= c_sub_mode_tx_mode;
								ff_sub_tx_data			<= { 6'd0, c_mode_io_write };
								ff_state				<= c_st_iow_mode;
							end
							c_mode_io_read: begin
								//	I/O Read モードの開始
								ff_sub_tx_active		<= 1'b1;
								ff_sub_start			<= 1'b1;
								ff_sub_mode				<= c_sub_mode_tx_mode;
								ff_sub_tx_data			<= { 6'd0, c_mode_io_read };
								ff_state				<= c_st_ior_mode;
							end
							c_mode_sound_send: begin
								//	Sound Send モードの開始
								ff_sub_tx_active		<= 1'b1;
								ff_sub_start			<= 1'b1;
								ff_sub_mode				<= c_sub_mode_tx_mode;
								ff_sub_tx_data			<= { 6'd0, c_mode_sound_send };
								ff_state				<= c_st_snd_mode;
							end
						endcase
					end
				end
				// ---------------------------------------------------------
				c_st_iow_mode: begin
					if( w_sub_done ) begin
						//	I/O Write モード: アドレス送信要求
						ff_sub_start			<= 1'b1;
						ff_sub_mode				<= c_sub_mode_tx_byte;
						ff_sub_tx_data			<= ff_req_bus_address;
						ff_state				<= c_st_iow_addr;
					end
				end

				c_st_iow_addr: begin
					if( w_sub_done ) begin
						//	I/O Write モード: データ送信要求
						ff_sub_start			<= 1'b1;
						ff_sub_mode				<= c_sub_mode_tx_byte;
						ff_sub_tx_data			<= ff_req_bus_wdata;
						ff_state				<= c_st_iow_data;
					end
				end

				c_st_iow_data: begin
					if( w_sub_done ) begin
						//	I/O Write モード: データ送信完了
						ff_sub_tx_active		<= 1'b0;
						ff_done					<= 1'b1;
						ff_state				<= c_st_wait_done;
					end
				end
				// ---------------------------------------------------------
				c_st_ior_mode: begin
					if( w_sub_done ) begin
						//	I/O Read モード: アドレス送信要求
						ff_sub_start			<= 1'b1;
						ff_sub_mode				<= c_sub_mode_tx_byte;
						ff_sub_tx_data			<= ff_req_bus_address;
						ff_state				<= c_st_ior_addr;
					end
				end

				c_st_ior_addr: begin
					if( w_sub_done ) begin
						//	I/O Read モード: ステータス受信要求
						ff_sub_start			<= 1'b1;
						ff_sub_mode				<= c_sub_mode_rx_status;
						ff_sub_tx_data			<= 8'd0;
						ff_state				<= c_st_ior_stat;
					end
				end

				c_st_ior_stat: begin
					if( w_sub_done ) begin
						if( w_sub_rx_data[1:0] == 2'b11 ) begin
							//	I/O Read モード: データ受信要求
							ff_sub_start			<= 1'b1;
							ff_sub_mode				<= c_sub_mode_rx_byte;
							ff_sub_tx_data			<= 8'd0;
							ff_state				<= c_st_ior_data;
						end
						else begin
							//	I/O Read モード: ステータス受信要求
							ff_sub_start			<= 1'b1;
							ff_sub_mode				<= c_sub_mode_rx_status;
							ff_sub_tx_data			<= 8'd0;
							ff_state				<= c_st_ior_stat;
						end
					end
				end

				c_st_ior_data: begin
					if( w_sub_done ) begin
						//	I/O Read モード: データ受信完了
						ff_bus_rdata			<= w_sub_rx_data;
						ff_sub_tx_active		<= 1'b0;
						ff_done					<= 1'b1;
						ff_state				<= c_st_wait_done;
					end
				end
				// ---------------------------------------------------------
				c_st_snd_mode: begin
					if( w_sub_done ) begin
						//	Sound Send モード: データ送信要求
						ff_sound_index			<= 3'd0;
						ff_sub_start			<= 1'b1;
						ff_sub_mode				<= c_sub_mode_tx_byte;
						ff_sub_tx_data			<= f_sound_tx_byte( ff_req_sound_l, ff_req_sound_r, 3'd0 );
						ff_state				<= c_st_snd_byte;
					end
				end

				c_st_snd_byte: begin
					if( w_sub_done ) begin
						if( ff_sound_index == 3'd7 ) begin
							ff_sub_tx_active	<= 1'b0;
							ff_done				<= 1'b1;
							ff_state			<= c_st_wait_done;
						end
						else begin
							ff_sound_index		<= ff_sound_index + 3'd1;
							ff_sub_start		<= 1'b1;
							ff_sub_mode			<= c_sub_mode_tx_byte;
							ff_sub_tx_data		<= f_sound_tx_byte( ff_req_sound_l, ff_req_sound_r, ff_sound_index + 3'd1 );
							ff_state			<= c_st_snd_byte;
						end
					end
				end
				// ---------------------------------------------------------
				c_st_wait_done: begin
					if( ff_serial_busy == 1'b0 ) begin
						ff_done				<= 1'b0;
						ff_state			<= c_st_idle;
					end
				end
				default: begin
					ff_sub_tx_active		<= 1'b0;
					ff_state				<= c_st_idle;
				end
			endcase
		end
	end

	// ---------------------------------------------------------
	//	通信モジュール（クロックドメイン：clk_serial）
	// ---------------------------------------------------------
	fpga_connect_master_sub u_fpga_connect_master_sub (
		.reset_n		( reset_n			),
		.clk_serial		( clk_serial		),
		.tx_cs			( w_sub_tx_active	),
		.use_tick		( 1'b0				),
		.start			( w_sub_start		),
		.mode			( w_sub_mode		),
		.tx_data		( w_sub_tx_data		),
		.so				( fpga_so			),
		.so_clk			( w_sub_so_clk		),
		.busy			( w_sub_busy		),
		.done			( w_sub_done		),
		.wait_read		( w_sub_wait_read	),
		.rx_data		( w_sub_rx_data		),
		.so_oe			( w_sub_so_oe		),
		.rx_data_en		( w_sub_rx_data_en	)
	);

endmodule
