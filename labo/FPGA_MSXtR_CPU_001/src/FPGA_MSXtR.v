// -----------------------------------------------------------------------------
//	FPGA_MSXtR.v
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

module fpga_msxtr (
	input			clk27m,					//	clk27m		PIN04_SYS_CLK		(27MHz)
	input			clk14m,					//	clk14m		PIN76				(14.31818MHz)
	input	[1:0]	button,					//	button[0]	PIN88_MODE0_KEY1
											//	button[1]	PIN87_MODE1_KEY2
	//	UART
	output			uart_tx,				//	uart_tx		PIN69
	//	LED
	output	[5:0]	led,					//	PIN20, 19, 18, 17, 16, 15
	//	SDRAM
	output			O_sdram_clk,			//	Internal
	output			O_sdram_cke,			//	Internal
	output			O_sdram_cs_n,			//	Internal
	output			O_sdram_cas_n,			//	Internal
	output			O_sdram_ras_n,			//	Internal
	output			O_sdram_wen_n,			//	Internal
	inout	[31:0]	IO_sdram_dq,			//	Internal
	output	[10:0]	O_sdram_addr,			//	Internal
	output	[1:0]	O_sdram_ba,				//	Internal
	output	[3:0]	O_sdram_dqm				//	Internal
);
	wire			clk42m;
	wire 			clk85m;
	wire			clk135m;
	wire			clk257m;
	reg		[4:0]	ff_reset_cnt = 5'd0;
	wire			w_msx_reset_pre_n;
	wire			w_msx_reset_n;
	reg		[3:0]	ff_3_579m = 4'd0;
	wire			w_3_579m;
	reg		[21:0]	ff_counter;
	reg				ff_led;
	reg		[1:0]	ff_button_d0;
	reg		[1:0]	ff_button_d1;

	wire			w_wait_n;
	wire			w_int_n;

	wire 			w_z80_busrq_n;
	wire 			w_z80_m1_n;
	wire 			w_z80_mreq_n;
	wire 			w_z80_iorq_n;
	wire 			w_z80_rd_n;
	wire 			w_z80_wr_n;
	wire 			w_z80_rfsh_n;
	wire 			w_z80_halt_n;
	wire 			w_z80_busak_n;
	wire	[15:0]	w_z80_a;
	wire	[7:0]	w_z80_wdata;
	wire	[7:0]	w_z80_rdata;
	wire			w_processor_mode;
	wire			w_bus_m1;
	wire			w_bus_io;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire	[7:0]	w_bus_wdata;
	wire	[15:0]	w_bus_address;
	wire			w_sdram_mreq_n;
	wire			w_sdram_wr_n;
	wire			w_sdram_rd_n;
	wire			w_sdram_init_busy;
	wire	[22:0]	w_sdram_address;
	wire	[7:0]	w_sdram_q;
	wire			w_sdram_q_en;
	wire	[7:0]	w_sdram_d;
	wire			w_sdram_bus_valid;
	wire			w_sdram_bus_write;
	wire			w_sdram_bus_refresh;
	wire	[31:0]	w_sdram_bus_wdata;
	wire	[3:0]	w_sdram_bus_wdata_mask;
	wire	[31:0]	w_sdram_bus_rdata;
	wire			w_bus_bootrom_cs;
	wire	[7:0]	w_bus_bootrom_rdata;
	wire			w_bus_bootrom_rdata_en;
	wire			w_bus_bootrom_ready;
	wire			w_bus_uart_cs;
	wire	[7:0]	w_bus_uart_rdata;
	wire			w_bus_uart_rdata_en;
	wire			w_bus_uart_ready;

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	Gowin_rPLL u_pll (
		.clkout					( clk85m					),		//	output clkout	85.90908MHz
		.clkoutd				( clk42m					),		//	output clkoutd	42.95454MHz
		.clkin					( clk14m					)		//	input clkin		14.31818MHz
	);

	Gowin_rPLL2 u_pll2 (
		.clkout					( clk257m					),		//	output clkout	257.72724MHz
		.clkin					( clk14m					)		//	input clkin		14.31818MHz
	);

	Gowin_rPLL3 u_pll3 (
		.clkout					( clk135m					),		//	output clkout	135MHz
		.clkin					( clk27m					)		//	input clkin		27MHz
	);

	always @( posedge clk42m ) begin
		if( !w_msx_reset_pre_n ) begin
			ff_3_579m <= 4'd0;
		end
		else if( w_3_579m ) begin
			ff_3_579m <= 4'd0;
		end
		else begin
			ff_3_579m <= ff_3_579m + 4'd1;
		end
	end

	assign w_3_579m	= (ff_3_579m == 4'd11) ? 1'b1: 1'b0;

	always @( posedge clk42m ) begin
		if( !w_msx_reset_n ) begin
			ff_counter <= 22'd2147726;
			ff_led <= 1'b0;
		end
		else if( ff_counter == 22'd0 ) begin
			ff_counter <= 22'd2147726;
			ff_led <= ~ff_led;
		end
		else begin
			ff_counter <= ff_counter - 22'd1;
		end
	end

	// --------------------------------------------------------------------
	//	Reset
	// --------------------------------------------------------------------
	always @( posedge clk42m ) begin
		if( ff_reset_cnt != 5'b11111 ) begin
			ff_reset_cnt <= ff_reset_cnt + 5'd1;
		end
	end

	assign w_msx_reset_pre_n	= (ff_reset_cnt[4:2] != 3'b000  ) ? 1'b1: 1'b0;
	assign w_msx_reset_n		= (ff_reset_cnt      == 5'b11111) ? 1'b1: 1'b0;

	// --------------------------------------------------------------------
	//	Button
	// --------------------------------------------------------------------
	always @( posedge clk42m ) begin
		ff_button_d0 <= button;
		ff_button_d1 <= ff_button_d0;
	end

	// --------------------------------------------------------------------
	//	Z80 core
	// --------------------------------------------------------------------

	//	Legasy compatible CPU core
	cz80_inst u_z80 (
		.reset_n				( w_msx_reset_n				),
		.clk					( clk42m					),
		.enable					( w_3_579m					),
		.wait_n					( w_wait_n					),
		.int_n					( w_int_n					),
		.nmi_n					( 1'b1						),
		.busrq_n				( w_z80_busrq_n				),
		.m1_n					( w_z80_m1_n				),
		.mreq_n					( w_z80_mreq_n				),
		.iorq_n					( w_z80_iorq_n				),
		.rd_n					( w_z80_rd_n				),
		.wr_n					( w_z80_wr_n				),
		.rfsh_n					( w_z80_rfsh_n				),
		.halt_n					( 							),
		.busak_n				( w_z80_busak_n				),
		.a						( w_z80_a					),
		.wdata					( w_z80_wdata				),
		.rdata					( w_z80_rdata				)
	);

	assign w_int_n = 1'b1;

	// --------------------------------------------------------------------
	//	System Controller
	// --------------------------------------------------------------------
	s2026a u_s2026a (
		.reset_n				( w_msx_reset_n				),
		.clk					( clk42m					),
		.wait_n					( w_wait_n					),
		.z80_busrq_n			( w_z80_busrq_n				),
		.z80_m1_n				( w_z80_m1_n				),
		.z80_mreq_n				( w_z80_mreq_n				),
		.z80_iorq_n				( w_z80_iorq_n				),
		.z80_rd_n				( w_z80_rd_n				),
		.z80_wr_n				( w_z80_wr_n				),
		.z80_busak_n			( w_z80_busak_n				),
		.z80_a					( w_z80_a					),
		.z80_wdata				( w_z80_wdata				),
		.z80_rdata				( w_z80_rdata				),
		.bus_bootrom_cs			( w_bus_bootrom_cs			),
		.bus_bootrom_rdata		( w_bus_bootrom_rdata		),
		.bus_bootrom_rdata_en	( w_bus_bootrom_rdata_en	),
		.bus_bootrom_ready		( w_bus_bootrom_ready		),
		.bus_uart_cs			( w_bus_uart_cs				),
		.bus_uart_rdata			( w_bus_uart_rdata			),
		.bus_uart_rdata_en		( w_bus_uart_rdata_en		),
		.bus_uart_ready			( w_bus_uart_ready			),
		.bus_m1					( w_bus_m1					),
		.bus_io					( w_bus_io					),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_wdata				( w_bus_wdata				),
		.bus_address			( w_bus_address				)
	);

	// --------------------------------------------------------------------
	//	BOOT ROM
	// --------------------------------------------------------------------
	bootrom u_bootrom (
		.reset_n				( w_msx_reset_n				),
		.clk					( clk42m					),
		.bootrom_cs				( w_bus_bootrom_cs			),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_wdata				( w_bus_wdata				),
		.bus_address			( w_bus_address				),
		.bus_rdata				( w_bus_bootrom_rdata		),
		.bus_rdata_en			( w_bus_bootrom_rdata_en	),
		.bus_ready				( w_bus_bootrom_ready		)
	);

	// --------------------------------------------------------------------
	//	UART
	// --------------------------------------------------------------------
	wire			w_uart_tx;

	uart u_uart (
		.reset_n				( w_msx_reset_n				),
		.clk					( clk42m					),
		.clk_uart				( clk27m					),
		.bus_uart_cs			( w_bus_uart_cs				),
		.bus_valid				( w_bus_valid				),
		.bus_write				( w_bus_write				),
		.bus_ready				( w_bus_uart_ready			),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_uart_rdata			),
		.bus_rdata_en			( w_bus_uart_rdata_en		),
		.uart_tx				( w_uart_tx					),
		.button					( ff_button_d1				)
	);

	assign uart_tx	= w_uart_tx;
	assign led[5]	= 1'b1;					//	V9968カートリッジでは、OE_N なので 1 にしておくこと。
	assign led[4:0]	= { w_z80_a[4:0] };		//{ w_uart_tx, ff_led, ~ff_led, ff_button_d1 };

	// --------------------------------------------------------------------
	//	SDRAM (Invalid)
	// --------------------------------------------------------------------
	assign O_sdram_clk		= 1'b1;
	assign O_sdram_cke		= 1'b0;
	assign O_sdram_cs_n		= 1'b1;
	assign O_sdram_cas_n	= 1'b1;
	assign O_sdram_ras_n	= 1'b1;
	assign O_sdram_wen_n	= 1'b1;
	assign O_sdram_addr		= 11'd0;
	assign O_sdram_ba		= 2'd0;
	assign O_sdram_dqm		= 4'd0;
endmodule
