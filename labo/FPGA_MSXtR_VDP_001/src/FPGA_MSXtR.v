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
	//	Connect CPU
	output			vdp_so_clk,				//	vdp_so_clk	PIN73
	output	[1:0]	vdp_so,					//	vdp_so		PIN75, PIN74
	input			vdp_si_clk,				//	vdp_si_clk	PIN85
	input	[1:0]	vdp_si,					//	vdp_si		PIN16, PIN15
	//	Connect Micom
	input			spi_cs_n,				//	spi_cs_n	PIN17
	input			spi_clk,				//	spi_clk		PIN20
	input			spi_mosi,				//	spi_mosi	PIN19
	output			spi_miso,				//	spi_miso	PIN18
	output			spi_intr,				//	spi_intr	PIN80
	//	I2S input
	output			pa_en,					//	pa_en		PIN51
	input			i2s_bclk,				//	i2s_bclk	PIN56
	input			i2s_lrck,				//	i2s_lrck	PIN55
	input			i2s_din,				//	i2s_din		PIN54
	//	INTR
	output			intr,					//	intr		PIN86
	//	WS2812 LED
	output			ws2812,					//	ws2812		PIN79
	//	UART
	output			uart_tx,				//	uart_tx		PIN69
	//	DIPSW
	input			dipsw,					//	dipsw		PIN72
	//	LED
	output			led,					//	led			PIN71
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
	reg		[3:0]	ff_reset_cnt = 4'd0;
	wire			w_msx_reset_n;
	reg		[3:0]	ff_3_579m = 4'd0;
	wire			w_3_579m;
	reg		[24:0]	ff_counter;
	reg				ff_led;

	wire	[7:0]	w_bus_uart_rdata;
	wire			w_bus_uart_rdata_en;
	wire			w_bus_uart_ready;

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
	wire			w_z80_active;
	wire			w_bus_m1;
	wire			w_bus_io;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire	[7:0]	w_bus_wdata;
	wire	[15:0]	w_bus_address;

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
		if( !w_msx_reset_n ) begin
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
			ff_counter <= 25'd14318180;
			ff_led <= 1'b0;
		end
		else if( ff_counter == 25'd0 ) begin
			ff_counter <= 25'd14318180;
			ff_led <= ~ff_led;
		end
		else begin
			ff_counter <= ff_counter - 25'd1;
		end
	end

	// --------------------------------------------------------------------
	//	Reset
	// --------------------------------------------------------------------
	always @( posedge clk42m ) begin
		if( ff_reset_cnt != 4'b1111 ) begin
			ff_reset_cnt <= ff_reset_cnt + 4'd1;
		end
	end

	assign w_msx_reset_n = (ff_reset_cnt == 4'b1111) ? 1'b1: 1'b0;

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

	assign w_int_p			= 1'b0;

	// --------------------------------------------------------------------
	//	System Controller
	// --------------------------------------------------------------------
	s2026a u_s2026a (
		.reset_n				( w_msx_reset_n				),
		.clk					( clk42m					),
		.enable_z80				( w_3_579m					),
		.z80_m1					( w_z80_m1					),
		.z80_mreq				( w_z80_mreq				),
		.z80_iorq				( w_z80_iorq				),
		.z80_rd					( w_z80_rd					),
		.z80_wr					( w_z80_wr					),
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
		.bus_address			( w_bus_address				),
		.z80_active				( w_z80_active				)
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
		.button					( button					)
	);

	assign uart_tx	= w_uart_tx;
	assign led		= ff_led;	// & dipsw;

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

	// --------------------------------------------------------------------
	//	SDRAM (Invalid)
	// --------------------------------------------------------------------
	assign vdp_so_clk		= 1'b1;
	assign vdp_so			= 2'd1;
	assign spi_miso			= 1'b1;
	assign spi_intr			= 1'b1;
	//	I2S input
	assign pa_en			= 1'b0;
	//	INTR
	assign intr				= 1'b0;
	//	WS2812 LED
	assign ws2812			= 1'b1;
endmodule
