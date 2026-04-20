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
	//	Connect VDP
	output			vdp_so_clk,				//	vdp_so_clk	PIN73
	output	[1:0]	vdp_so,					//	vdp_so		PIN75, PIN74
	input			vdp_si_clk,				//	vdp_si_clk	PIN85
	input	[1:0]	vdp_si,					//	vdp_si		PIN16, PIN15
	//	SerialROM
	output			srom_cs_n,				//	srom_cs_n	PIN29
	output			srom2_cs_n,				//	srom2_cs_n	PIN30
	output			srom_clk,				//	srom_clk	PIN26
	output	[3:0]	srom_sio,				//	srom_sio[0]	PIN16
											//	srom_sio[1]	PIN27
											//	srom_sio[2]	PIN28
											//	srom_sio[3]	PIN25
	//	I2S output
	output			pa_en,					//	pa_en		PIN51
	output			i2s_bclk,				//	i2s_bclk	PIN56
	output			i2s_lrck,				//	i2s_lrck	PIN55
	output			i2s_dout,				//	i2s_dout	PIN54
	//	UART
	output			uart_tx,				//	uart_tx		PIN69
	//	DIPSW
	input			dipsw,					//	dipsw		PIN48
	//	WS2812 LED
	output			ws2812,					//	ws2812		PIN79
	//	I/O Expander
	output	[2:0]	io_sel,					//	io_sel[0]	PIN41
											//	io_sel[1]	PIN42
											//	io_sel[2]	PIN80
	output			io_clk,					//	io_clk		PIN86
	output			reset_n,				//	reset_n		PIN49
	output	[7:0]	dio,					//	dio[0]		PIN30
											//	dio[1]		PIN31
											//	dio[2]		PIN17
											//	dio[3]		PIN20
											//	dio[4]		PIN19
											//	dio[5]		PIN18
											//	dio[6]		PIN72
											//	dio[7]		PIN71
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
	reg		[3:0]	ff_21m = 4'd0;
	wire			w_21m;
	reg		[21:0]	ff_counter;
	reg				ff_led;
	reg		[1:0]	ff_button_d0;
	reg		[1:0]	ff_button_d1;

	wire			w_int_p;

	wire 			w_z80_m1;
	wire 			w_z80_mreq;
	wire 			w_z80_iorq;
	wire 			w_z80_rd;
	wire 			w_z80_wr;
	wire 			w_z80_rfsh;
	wire	[15:0]	w_z80_a;
	wire	[7:0]	w_z80_wdata;
	wire	[7:0]	w_z80_rdata;
	wire 			w_r800_m1;
	wire 			w_r800_mreq;
	wire 			w_r800_iorq;
	wire 			w_r800_rd;
	wire 			w_r800_wr;
	wire 			w_r800_rfsh;
	wire	[15:0]	w_r800_a;
	wire	[7:0]	w_r800_wdata;
	wire	[7:0]	w_r800_rdata;
	wire			w_processor_mode;
	wire			w_bus_m1;
	wire			w_bus_io;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire	[7:0]	w_bus_wdata;
	wire	[15:0]	w_bus_address;

//	wire			w_sdram_mreq_n;
//	wire			w_sdram_wr_n;
//	wire			w_sdram_rd_n;
//	wire			w_sdram_init_busy;
//	wire	[22:0]	w_sdram_address;
//	wire	[7:0]	w_sdram_q;
//	wire			w_sdram_q_en;
//	wire	[7:0]	w_sdram_d;
//	wire			w_sdram_bus_valid;
//	wire			w_sdram_bus_write;
//	wire			w_sdram_bus_refresh;
//	wire	[31:0]	w_sdram_bus_wdata;
//	wire	[3:0]	w_sdram_bus_wdata_mask;
//	wire	[31:0]	w_sdram_bus_rdata;

	wire			w_bus_bootrom_cs;
	wire	[7:0]	w_bus_bootrom_rdata;
	wire			w_bus_bootrom_rdata_en;
	wire			w_bus_bootrom_ready;
	wire			w_bus_uart_cs;
	wire	[7:0]	w_bus_uart_rdata;
	wire			w_bus_uart_rdata_en;
	wire			w_bus_uart_ready;
	wire			w_z80_active;
	wire			w_r800_active;

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
		if( !w_msx_reset_pre_n ) begin
			ff_21m <= 4'd0;
		end
		else if( w_21m ) begin
			ff_21m <= 4'd0;
		end
		else begin
			ff_21m <= ff_21m + 4'd1;
		end
	end

	assign w_21m	= (ff_21m == 4'd3) ? 1'b1 : 1'b0;

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
	always @( posedge clk27m ) begin
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
		.enable					( w_z80_active				),
		.wait_p					( 1'b0						),
		.int_p					( w_int_p					),
		.nmi_n					( 1'b1						),
		.busrq					( 1'b0						),
		.m1						( w_z80_m1					),
		.mreq					( w_z80_mreq				),
		.iorq					( w_z80_iorq				),
		.rd						( w_z80_rd					),
		.wr						( w_z80_wr					),
		.rfsh					( w_z80_rfsh				),
		.halt_n					( 							),
		.busak					( 							),
		.a						( w_z80_a					),
		.wdata					( w_z80_wdata				),
		.rdata					( w_z80_rdata				)
	);

	//	Highspeed CPU core
	cz80_inst u_r800 (
		.reset_n				( w_msx_reset_n				),
		.clk					( clk42m					),
		.enable					( w_r800_active				),
		.wait_p					( 1'b0						),
		.int_p					( w_int_p					),
		.nmi_n					( 1'b1						),
		.busrq					( 1'b0						),
		.m1						( w_r800_m1					),
		.mreq					( w_r800_mreq				),
		.iorq					( w_r800_iorq				),
		.rd						( w_r800_rd					),
		.wr						( w_r800_wr					),
		.rfsh					( w_r800_rfsh				),
		.halt_n					( 							),
		.busak					( 							),
		.a						( w_r800_a					),
		.wdata					( w_r800_wdata				),
		.rdata					( w_r800_rdata				)
	);

	assign w_int_p			= 1'b0;

	// --------------------------------------------------------------------
	//	System Controller
	// --------------------------------------------------------------------
	s2026a u_s2026a (
		.reset_n				( w_msx_reset_n				),
		.clk					( clk42m					),
		.enable_z80				( w_3_579m					),
		.enable_r800			( w_21m						),
		.z80_m1					( w_z80_m1					),
		.z80_mreq				( w_z80_mreq				),
		.z80_iorq				( w_z80_iorq				),
		.z80_rd					( w_z80_rd					),
		.z80_wr					( w_z80_wr					),
		.z80_a					( w_z80_a					),
		.z80_wdata				( w_z80_wdata				),
		.z80_rdata				( w_z80_rdata				),
		.r800_m1				( w_r800_m1					),
		.r800_mreq				( w_r800_mreq				),
		.r800_iorq				( w_r800_iorq				),
		.r800_rd				( w_r800_rd					),
		.r800_wr				( w_r800_wr					),
		.r800_a					( w_r800_a					),
		.r800_wdata				( w_r800_wdata				),
		.r800_rdata				( w_r800_rdata				),
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
		.bus_address			( w_bus_address				),
		.z80_active				( w_z80_active				),
		.r800_active			( w_r800_active				),
		.processor_mode			( w_processor_mode			)		//	0: R800, 1: Z80
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
	assign IO_sdram_dq		= 32'dz;

	// --------------------------------------------------------------------
	//	Port assign
	// --------------------------------------------------------------------
	assign vdp_so_clk		= 1'b0;
	assign vdp_so			= 2'b00;
	assign srom_cs_n		= 1'b1;
	assign srom2_cs_n		= 1'b1;
	assign srom_clk			= 1'b0;
	assign srom_sio			= 4'b0000;
	assign pa_en			= 1'b0;
	assign i2s_bclk			= 1'b0;
	assign i2s_lrck			= 1'b0;
	assign i2s_dout			= 1'b0;
	assign ws2812			= 1'b0;
	assign io_sel			= 3'b000;
	assign io_clk			= 1'b0;
	assign reset_n			= 1'b0;
	assign dio				= { 3'd0, ff_button_d1, dipsw, 2'd0};
endmodule
