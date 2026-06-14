// -----------------------------------------------------------------------------
//	qspi.v
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
//		Quad SPI controller (mode0 only)
// -----------------------------------------------------------------------------

module qspi (
	input			reset,
	input			clk,				//	System Clock
	input			clk_serial,			//	Serial Clock source (2x of qspi_clk)
	//	internal interface (clk domain)
	input	[2:0]	serial_mode,
	input	[7:0]	serial_wdata,
	input			serial_write,
	input			serial_valid,
	output			serial_ready,
	output	[7:0]	serial_rdata,
	output			serial_rdata_en,
	//	QSPI interface
	output			qspi_clk,
	inout	[3:0]	qspi_sio
);
	// ---------------------------------------------------------
	//	serial_mode
	//		0: Standard SPI write
	//		1: Standard SPI read
	//		2: Quad SPI write
	//		3: Quad SPI read
	//		4: Quad SPI dummy clock
	//		5-7: Reserved
	//	note:
	//		Don't support Dual SPI read/write.
	// ---------------------------------------------------------
	localparam [2:0]	MODE_STD_WRITE	= 3'd0;
	localparam [2:0]	MODE_STD_READ	= 3'd1;
	localparam [2:0]	MODE_QUAD_WRITE	= 3'd2;
	localparam [2:0]	MODE_QUAD_READ	= 3'd3;
	localparam [2:0]	MODE_QUAD_DUMMY	= 3'd4;
	//	clk domain
	reg		[2:0]	ff_fifo_mode;
	reg		[7:0]	ff_fifo_wdata;
	reg				ff_fifo_write;
	reg				ff_fifo_valid;		//	要求が溜まっている場合に 1
	reg		[2:0]	ff_serial_mode;
	reg		[7:0]	ff_serial_wdata;
	reg				ff_serial_write;
	reg				ff_serial_valid;	//	すぐ通信する内容がある場合に 1
	reg				ff_serial_ready;	//	次に通信する内容を受けられる場合に 1
	reg		[7:0]	ff_serial_rdata;
	reg				ff_serial_rdata_en;	//	受信データが有効なタイミングで 1
	reg				ff_serial_processing;
	reg				ff_serial_qspi_accepted;
	//	clk_serial domain
	localparam	[5:0]	ST_IDLE				= 6'd0;
	localparam	[5:0]	ST_STD_WRITE		= 6'd1;
	localparam	[5:0]	ST_STD_WRITE_B7RE	= 6'd2;		//	bit7 rise edge
	localparam	[5:0]	ST_STD_WRITE_B7FE	= 6'd3;		//	bit7 fall edge
	localparam	[5:0]	ST_STD_WRITE_B6RE	= 6'd4;		//	bit6 rise edge
	localparam	[5:0]	ST_STD_WRITE_B6FE	= 6'd5;		//	bit6 fall edge
	localparam	[5:0]	ST_STD_WRITE_B5RE	= 6'd6;		//	bit5 rise edge
	localparam	[5:0]	ST_STD_WRITE_B5FE	= 6'd7;		//	bit5 fall edge
	localparam	[5:0]	ST_STD_WRITE_B4RE	= 6'd8;		//	bit4 rise edge
	localparam	[5:0]	ST_STD_WRITE_B4FE	= 6'd9;		//	bit4 fall edge
	localparam	[5:0]	ST_STD_WRITE_B3RE	= 6'd10;	//	bit3 rise edge
	localparam	[5:0]	ST_STD_WRITE_B3FE	= 6'd11;	//	bit3 fall edge
	localparam	[5:0]	ST_STD_WRITE_B2RE	= 6'd12;	//	bit2 rise edge
	localparam	[5:0]	ST_STD_WRITE_B2FE	= 6'd13;	//	bit2 fall edge
	localparam	[5:0]	ST_STD_WRITE_B1RE	= 6'd14;	//	bit1 rise edge
	localparam	[5:0]	ST_STD_WRITE_B1FE	= 6'd15;	//	bit1 fall edge
	localparam	[5:0]	ST_STD_WRITE_B0RE	= 6'd16;	//	bit0 rise edge
	localparam	[5:0]	ST_STD_WRITE_B0FE	= 6'd17;	//	bit0 fall edge
	localparam	[5:0]	ST_STD_READ			= 6'd18;
	localparam	[5:0]	ST_STD_READ_B7RE	= 6'd19;	//	bit7 rise edge
	localparam	[5:0]	ST_STD_READ_B7FE	= 6'd20;	//	bit7 fall edge
	localparam	[5:0]	ST_STD_READ_B6RE	= 6'd21;	//	bit6 rise edge
	localparam	[5:0]	ST_STD_READ_B6FE	= 6'd22;	//	bit6 fall edge
	localparam	[5:0]	ST_STD_READ_B5RE	= 6'd23;	//	bit5 rise edge
	localparam	[5:0]	ST_STD_READ_B5FE	= 6'd24;	//	bit5 fall edge
	localparam	[5:0]	ST_STD_READ_B4RE	= 6'd25;	//	bit4 rise edge
	localparam	[5:0]	ST_STD_READ_B4FE	= 6'd26;	//	bit4 fall edge
	localparam	[5:0]	ST_STD_READ_B3RE	= 6'd27;	//	bit3 rise edge
	localparam	[5:0]	ST_STD_READ_B3FE	= 6'd28;	//	bit3 fall edge
	localparam	[5:0]	ST_STD_READ_B2RE	= 6'd29;	//	bit2 rise edge
	localparam	[5:0]	ST_STD_READ_B2FE	= 6'd30;	//	bit2 fall edge
	localparam	[5:0]	ST_STD_READ_B1RE	= 6'd31;	//	bit1 rise edge
	localparam	[5:0]	ST_STD_READ_B1FE	= 6'd32;	//	bit1 fall edge
	localparam	[5:0]	ST_STD_READ_B0RE	= 6'd33;	//	bit0 rise edge
	localparam	[5:0]	ST_STD_READ_B0FE	= 6'd34;	//	bit0 fall edge
	localparam	[5:0]	ST_QUAD_WRITE		= 6'd35;	//	Quad SPI write (1クロックで4bit送信)
	localparam	[5:0]	ST_QUAD_WRITE_B74RE	= 6'd36;	//	bit7-4 rise edge
	localparam	[5:0]	ST_QUAD_WRITE_B74FE	= 6'd37;	//	bit7-4 fall edge
	localparam	[5:0]	ST_QUAD_WRITE_B30RE	= 6'd38;	//	bit3-0 rise edge
	localparam	[5:0]	ST_QUAD_WRITE_B30FE	= 6'd39;	//	bit3-0 fall edge
	localparam	[5:0]	ST_QUAD_READ		= 6'd40;	//	Quad SPI read (1クロックで4bit受信)
	localparam	[5:0]	ST_QUAD_READ_B74RE	= 6'd41;	//	bit7-4 rise edge
	localparam	[5:0]	ST_QUAD_READ_B74FE	= 6'd42;	//	bit7-4 fall edge
	localparam	[5:0]	ST_QUAD_READ_B30RE	= 6'd43;	//	bit3-0 rise edge
	localparam	[5:0]	ST_QUAD_READ_B30FE	= 6'd44;	//	bit3-0 fall edge
	localparam	[5:0]	ST_QUAD_DUMMY		= 6'd45;	//	Quad SPI dummy clock (1クロックで4bit dummy clock)
	localparam	[5:0]	ST_QUAD_DUMMY_1RE	= 6'd41;	//	1st rise edge
	localparam	[5:0]	ST_QUAD_DUMMY_1FE	= 6'd42;	//	1st fall edge
	localparam	[5:0]	ST_QUAD_DUMMY_2RE	= 6'd43;	//	2nd rise edge
	localparam	[5:0]	ST_QUAD_DUMMY_2FE	= 6'd44;	//	2nd fall edge
	localparam	[5:0]	ST_QUAD_DUMMY_3RE	= 6'd45;	//	3rd rise edge
	localparam	[5:0]	ST_QUAD_DUMMY_3FE	= 6'd46;	//	3rd fall edge
	localparam	[5:0]	ST_QUAD_DUMMY_4RE	= 6'd47;	//	4th rise edge
	localparam	[5:0]	ST_QUAD_DUMMY_4FE	= 6'd48;	//	4th fall edge
	localparam	[5:0]	ST_FINISH			= 6'd49;	//	通信処理完了
	reg					ff_qspi_serial_valid0;			//	ff_serial_valid を clk_serial ドメインに載せ替え用
	reg					ff_qspi_serial_valid1;			//	ff_serial_valid を clk_serial ドメインに載せ替え用
	reg					ff_qspi_processing;
	reg			[5:0]	ff_qspi_state;
	reg					ff_qspi_clk;
	reg			[7:0]	ff_qspi_data;
	reg			[3:0]	ff_qspi_hiz;					//	qspi_sio を Hi-Z にするか (1: Hi-Z, 0: ドライブ)
	reg			[3:0]	ff_qspi_sio;
	reg			[7:0]	ff_qspi_rdata;

	// ---------------------------------------------------------
	//	要求を受け付ける処理 (1要求分貯めておくバッファ)
	// ---------------------------------------------------------
	always @(posedge clk) begin
		if( reset ) begin
			ff_fifo_mode	<= 3'd0;
			ff_fifo_wdata	<= 8'd0;
			ff_fifo_write	<= 1'b0;
			ff_fifo_valid	<= 1'b0;
		end 
		else if( !ff_fifo_valid ) begin
			if( serial_valid ) begin
				//	要求された内容を記憶する
				ff_fifo_mode	<= serial_mode;
				ff_fifo_wdata	<= serial_wdata;
				ff_fifo_write	<= serial_write;
				ff_fifo_valid	<= 1'b1;
			end 
		end
		else begin
			if( !ff_serial_valid && ff_serial_ready ) begin
				//	要求がなくなったら、次の要求を受け付ける準備をする
				ff_fifo_valid <= 1'b0;
			end
		end
	end

	always @(posedge clk) begin
		if( reset ) begin
			ff_serial_mode	<= 3'd0;
			ff_serial_wdata	<= 8'd0;
			ff_serial_write	<= 1'b0;
			ff_serial_valid	<= 1'b0;
		end 
		else if( !ff_serial_valid ) begin
			if( ff_fifo_valid && ff_serial_ready ) begin
				//	要求された内容を記憶する
				ff_serial_mode	<= ff_fifo_mode;
				ff_serial_wdata	<= ff_fifo_wdata;
				ff_serial_write	<= ff_fifo_write;
				ff_serial_valid	<= 1'b1;
			end 
		end
		else begin
			if( ff_serial_qspi_accepted ) begin
				//	通信要求が受理されたら、受理された要求を消去する
				ff_serial_valid <= 1'b0;
			end
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_serial_ready <= 1'b1;
		end
		else if( ff_serial_ready ) begin
			if( ff_fifo_valid ) begin
				//	要求があって、通信可能な状態であれば、通信要求を受け付ける
				ff_serial_ready <= 1'b0;
			end
		end
		else begin
			//	通信完了したタイミングで、ready に戻す
			if( !ff_serial_valid && !ff_serial_qspi_accepted ) begin
				ff_serial_ready <= 1'b1;
			end
		end
	end

	always @(posedge clk) begin
		if( reset ) begin
			ff_serial_processing		<= 1'b0;
			ff_serial_qspi_accepted		<= 1'b0;
		end
		else begin
			//	クロック載せ替え
			ff_serial_processing		<= ff_qspi_processing;
			ff_serial_qspi_accepted		<= ff_serial_processing;
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_serial_rdata		<= 8'd0;
			ff_serial_rdata_en	<= 1'b0;
		end
		else if( !ff_serial_processing && ff_serial_qspi_accepted ) begin
			//	通信要求が受理されたタイミングで、受信データを出力する
			ff_serial_rdata		<= ff_qspi_rdata;
			ff_serial_rdata_en	<= ~ff_serial_write;
		end
		else begin
			ff_serial_rdata_en	<= 1'b0;
		end
	end

	assign serial_ready		= !ff_fifo_valid;
	assign serial_rdata		= ff_serial_rdata;
	assign serial_rdata_en	= ff_serial_rdata_en;

	// ---------------------------------------------------------
	//	QSPI 通信の要求受付（クロック載せ替え）
	// ---------------------------------------------------------
	always @( posedge clk_serial ) begin
		if( reset ) begin
			ff_qspi_serial_valid0 <= 1'b0;
			ff_qspi_serial_valid1 <= 1'b0;
		end
		else begin
			ff_qspi_serial_valid0 <= ff_serial_valid;
			ff_qspi_serial_valid1 <= ff_qspi_serial_valid0;
		end
	end

	always @( posedge clk_serial ) begin
		if( reset ) begin
			ff_qspi_processing <= 1'b0;
		end
		else if( !ff_qspi_processing ) begin
			//	通信停止中であれば、要求があるか調べる
			if( ff_qspi_serial_valid1 ) begin
				//	要求があれば通信開始する
				ff_qspi_processing <= 1'b1;
			end
		end
		else begin
			//	通信中であれば、通信処理が完了したか調べる
			if( ff_qspi_state == ST_FINISH ) begin
				//	通信が完了したら、通信停止状態に戻る
				ff_qspi_processing <= 1'b0;
			end
		end
	end

	// ---------------------------------------------------------
	//	QSPI 通信の処理
	// ---------------------------------------------------------
	always @( posedge clk_serial ) begin
		if( reset ) begin
			ff_qspi_state	<= ST_IDLE;
			ff_qspi_clk		<= 1'b0;		//	SPI mode0 only
			ff_qspi_data	<= 8'd0;
			ff_qspi_hiz		<= 4'b1111;		//	全て Hi-Z
			ff_qspi_sio		<= 4'b0000;
		end
		else if( ff_qspi_processing ) begin
			case( ff_qspi_state )
				ST_IDLE: begin
					case( ff_serial_mode )
						MODE_STD_WRITE: begin
							//	Standard SPI write
							ff_qspi_state	<= ST_STD_WRITE;
							ff_qspi_clk		<= 1'b0;
							ff_qspi_data	<= ff_serial_wdata;
						end
						MODE_STD_READ: begin
							//	Standard SPI read
							ff_qspi_state	<= ST_STD_READ;
							ff_qspi_clk		<= 1'b0;
						end
						MODE_QUAD_WRITE: begin
							//	Quad SPI write
							ff_qspi_state	<= ST_QUAD_WRITE;
							ff_qspi_clk		<= 1'b0;
							ff_qspi_data	<= ff_serial_wdata;
						end
						MODE_QUAD_READ: begin
							//	Quad SPI read
							ff_qspi_state	<= ST_QUAD_READ;
							ff_qspi_clk		<= 1'b0;
						end
						MODE_QUAD_DUMMY: begin
							//	Quad SPI dummy clock
							ff_qspi_state	<= ST_QUAD_DUMMY;
							ff_qspi_clk		<= 1'b0;
						end
						default: begin
							//	Reserved
							ff_qspi_state	<= ST_FINISH;
							ff_qspi_clk		<= 1'b0;
						end
					endcase
				end
				// ---------------------------------------------------------
				//	standard SPI write の処理
				// ---------------------------------------------------------
				ST_STD_WRITE: begin
					//	bit7
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= ff_qspi_data[7];
					ff_qspi_hiz		<= 4'b1110;		//	ドライブ
					ff_qspi_state	<= ST_STD_WRITE_B7RE;
				end
				ST_STD_WRITE_B7RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_WRITE_B7FE;
				end
				ST_STD_WRITE_B7FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= ff_qspi_data[6];
					ff_qspi_hiz		<= 4'b1110;		//	ドライブ
					ff_qspi_state	<= ST_STD_WRITE_B6RE;
				end
				ST_STD_WRITE_B6RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_WRITE_B6FE;
				end
				ST_STD_WRITE_B6FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= ff_qspi_data[5];
					ff_qspi_hiz		<= 4'b1110;		//	ドライブ
					ff_qspi_state	<= ST_STD_WRITE_B5RE;
				end
				ST_STD_WRITE_B5RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_WRITE_B5FE;
				end
				ST_STD_WRITE_B5FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= ff_qspi_data[4];
					ff_qspi_hiz		<= 4'b1110;		//	ドライブ
					ff_qspi_state	<= ST_STD_WRITE_B4RE;
				end
				ST_STD_WRITE_B4RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_WRITE_B4FE;
				end
				ST_STD_WRITE_B4FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= ff_qspi_data[3];
					ff_qspi_hiz		<= 4'b1110;		//	ドライブ
					ff_qspi_state	<= ST_STD_WRITE_B3RE;
				end
				ST_STD_WRITE_B3RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_WRITE_B3FE;
				end
				ST_STD_WRITE_B3FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= ff_qspi_data[2];
					ff_qspi_hiz		<= 4'b1110;		//	ドライブ
					ff_qspi_state	<= ST_STD_WRITE_B2RE;
				end
				ST_STD_WRITE_B2RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_WRITE_B2FE;
				end
				ST_STD_WRITE_B2FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= ff_qspi_data[1];
					ff_qspi_hiz		<= 4'b1110;		//	ドライブ
					ff_qspi_state	<= ST_STD_WRITE_B1RE;
				end
				ST_STD_WRITE_B1RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_WRITE_B1FE;
				end
				ST_STD_WRITE_B1FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= ff_qspi_data[0];
					ff_qspi_hiz		<= 4'b1110;		//	ドライブ
					ff_qspi_state	<= ST_STD_WRITE_B0RE;
				end
				ST_STD_WRITE_B0RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_WRITE_B0FE;
				end
				ST_STD_WRITE_B0FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= 1'b0;
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_FINISH;
				end
				// ---------------------------------------------------------
				//	standard SPI read の処理
				// ---------------------------------------------------------
				ST_STD_READ: begin
					//	bit7
					ff_qspi_clk		<= 1'b0;
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_STD_READ_B7RE;
				end
				ST_STD_READ_B7RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_READ_B7FE;
				end
				ST_STD_READ_B7FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_data[7] <= qspi_sio[1];
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_STD_READ_B6RE;
				end
				ST_STD_READ_B6RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_READ_B6FE;
				end
				ST_STD_READ_B6FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_data[6] <= qspi_sio[1];
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_STD_READ_B5RE;
				end
				ST_STD_READ_B5RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_READ_B5FE;
				end
				ST_STD_READ_B5FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_data[5] <= qspi_sio[1];
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_STD_READ_B4RE;
				end
				ST_STD_READ_B4RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_READ_B4FE;
				end
				ST_STD_READ_B4FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_data[4] <= qspi_sio[1];
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_STD_READ_B3RE;
				end
				ST_STD_READ_B3RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_READ_B3FE;
				end
				ST_STD_READ_B3FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_data[3] <= qspi_sio[1];
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_STD_READ_B2RE;
				end
				ST_STD_READ_B2RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_READ_B2FE;
				end
				ST_STD_READ_B2FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_data[2] <= qspi_sio[1];
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_STD_READ_B1RE;
				end
				ST_STD_READ_B1RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_READ_B1FE;
				end
				ST_STD_READ_B1FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_data[1] <= qspi_sio[1];
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_STD_READ_B0RE;
				end
				ST_STD_READ_B0RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_READ_B0FE;
				end
				ST_STD_READ_B0FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_data[0] <= qspi_sio[1];
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_FINISH;
				end
				// ---------------------------------------------------------
				//	Quad SPI write の処理
				// ---------------------------------------------------------
				ST_QUAD_WRITE: begin
					//	bit7-4
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio		<= ff_qspi_data[7:4];
					ff_qspi_hiz		<= 4'b0000;		//	ドライブ
					ff_qspi_state	<= ST_QUAD_WRITE_B74RE;
				end
				ST_QUAD_WRITE_B74RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_QUAD_WRITE_B74FE;
				end
				ST_QUAD_WRITE_B74FE: begin
					ff_qspi_sio		<= ff_qspi_data[3:0];
					ff_qspi_clk		<= 1'b0;
					ff_qspi_state	<= ST_QUAD_WRITE_B30RE;
				end
				ST_QUAD_WRITE_B30RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_QUAD_WRITE_B30FE;
				end
				ST_QUAD_WRITE_B30FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_FINISH;
				end
				// ---------------------------------------------------------
				//	Quad SPI read の処理
				// ---------------------------------------------------------
				ST_QUAD_READ: begin
					//	bit7-4
					ff_qspi_clk			<= 1'b0;
					ff_qspi_hiz			<= 4'b1111;		//	Hi-Z
					ff_qspi_state		<= ST_QUAD_READ_B74RE;
				end
				ST_QUAD_READ_B74RE: begin
					ff_qspi_clk			<= 1'b1;
					ff_qspi_state		<= ST_QUAD_READ_B74FE;
				end
				ST_QUAD_READ_B74FE: begin
					ff_qspi_clk			<= 1'b0;
					ff_qspi_data[7:4]	<= qspi_sio;
					ff_qspi_state		<= ST_QUAD_READ_B30RE;
				end
				ST_QUAD_READ_B30RE: begin
					ff_qspi_clk			<= 1'b1;
					ff_qspi_state		<= ST_QUAD_READ_B30FE;
				end
				ST_QUAD_READ_B30FE: begin
					ff_qspi_clk			<= 1'b0;
					ff_qspi_data[3:0]	<= qspi_sio;
					ff_qspi_hiz			<= 4'b1111;		//	Hi-Z
					ff_qspi_state		<= ST_FINISH;
				end
				// ---------------------------------------------------------
				//	Quad SPI dummy の処理
				// ---------------------------------------------------------
				ST_QUAD_DUMMY: begin
					//	bit7-4
					ff_qspi_clk			<= 1'b0;
					ff_qspi_hiz			<= 4'b1111;		//	Hi-Z
					ff_qspi_state		<= ST_QUAD_DUMMY_1RE;
				end
				ST_QUAD_DUMMY_1RE: begin
					ff_qspi_clk			<= 1'b1;
					ff_qspi_state		<= ST_QUAD_DUMMY_1FE;
				end
				ST_QUAD_DUMMY_1FE: begin
					ff_qspi_clk			<= 1'b0;
					ff_qspi_state		<= ST_QUAD_DUMMY_2RE;
				end
				ST_QUAD_DUMMY_2RE: begin
					ff_qspi_clk			<= 1'b1;
					ff_qspi_state		<= ST_QUAD_DUMMY_2FE;
				end
				ST_QUAD_DUMMY_2FE: begin
					ff_qspi_clk			<= 1'b0;
					ff_qspi_state		<= ST_QUAD_DUMMY_3RE;
				end
				ST_QUAD_DUMMY_3RE: begin
					ff_qspi_clk			<= 1'b1;
					ff_qspi_state		<= ST_QUAD_DUMMY_3FE;
				end
				ST_QUAD_DUMMY_3FE: begin
					ff_qspi_clk			<= 1'b0;
					ff_qspi_state		<= ST_QUAD_DUMMY_4RE;
				end
				ST_QUAD_DUMMY_4RE: begin
					ff_qspi_clk			<= 1'b1;
					ff_qspi_state		<= ST_QUAD_DUMMY_4FE;
				end
				ST_QUAD_DUMMY_4FE: begin
					ff_qspi_clk			<= 1'b0;
					ff_qspi_state		<= ST_FINISH;
				end
				// ---------------------------------------------------------
				//	通信完了処理
				// ---------------------------------------------------------
				ST_FINISH: begin
					//	通信完了処理 (次の通信要求を受け付けるための状態に遷移するなど)
					ff_qspi_state	<= ST_IDLE;
				end
				default: begin
				end
			endcase
		end
		else begin
			ff_qspi_state		<= ST_IDLE;
			ff_qspi_clk			<= 1'b0;		//	SPI mode0 only
		end
	end

	always @( posedge clk_serial ) begin
		if( reset ) begin
			ff_qspi_rdata	<= 8'd0;
		end
		else if( ff_qspi_processing ) begin
			if( ff_qspi_state == ST_FINISH ) begin
				//	通信が完了したタイミングで、受信データを clk ドメインに渡す
				ff_qspi_rdata	<= ff_qspi_data;
			end
		end
	end

	assign qspi_clk		= ff_qspi_clk;
	assign qspi_sio[0]	= ff_qspi_hiz[0] ? 1'bz : ff_qspi_sio[0];
	assign qspi_sio[1]	= ff_qspi_hiz[1] ? 1'bz : ff_qspi_sio[1];
	assign qspi_sio[2]	= ff_qspi_hiz[2] ? 1'bz : ff_qspi_sio[2];
	assign qspi_sio[3]	= ff_qspi_hiz[3] ? 1'bz : ff_qspi_sio[3];
endmodule
