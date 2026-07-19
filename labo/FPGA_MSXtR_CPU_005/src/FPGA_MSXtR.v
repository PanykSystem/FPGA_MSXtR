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
	input			clk27m,					//	clk27m				PIN04_SYS_CLK		(27MHz)
	input			clk14m,					//	clk14m				PIN76				(14.31818MHz)
	input	[1:0]	button,					//	button[0]			PIN88_MODE0_KEY1
											//	button[1]			PIN87_MODE1_KEY2
	//	Connect VDP
	output			fpga_so_clk,			//	fpga_so_clk			PIN73
	output	[1:0]	fpga_so,				//	fpga_so				PIN75, PIN74
	input			fpga_si_clk,			//	fpga_si_clk			PIN85
	input	[1:0]	fpga_si,				//	fpga_si				PIN16, PIN15
	//	SerialROM
	output			srom0_spi_cs_n,			//	srom0_spi_cs_n		PIN29
	output			srom1_spi_cs_n,			//	srom1_spi_cs_n		PIN30
	output			srom_spi_clk,			//	srom_spi_clk		PIN26
	inout			srom_spi_di,			//	srom_spi_di			PIN16
	inout			srom_spi_do,			//	srom_spi_do			PIN27
	inout			srom_spi_wp_n,			//	srom_spi_wp_n		PIN28
	inout			srom_spi_hold_n,		//	srom_spi_hold_n		PIN25
	//	config ROM
	output			flash_spi_cs_n,			//	flash_spi_cs_n		PIN60
	output			flash_spi_clk,			//	flash_spi_clk		PIN59
	inout			flash_spi_hold_n,		//	flash_spi_hold_n	PIN63
	inout			flash_spi_wp_n,			//	flash_spi_wp_n		PIN57
	inout			flash_spi_do,			//	flash_spi_do		PIN62
	inout			flash_spi_di,			//	flash_spi_di		PIN61
	//	I2S output
	output			pa_en,					//	pa_en				PIN51
	output			i2s_bclk,				//	i2s_bclk			PIN56
	output			i2s_lrck,				//	i2s_lrck			PIN55
	output			i2s_dout,				//	i2s_dout			PIN54
	//	UART
	output			uart_tx,				//	uart_tx				PIN69
	//	DIPSW
	input			dipsw,					//	dipsw				PIN48
	//	WS2812 LED
	output			ws2812,					//	ws2812				PIN79
	//	I/O Expander
	output	[2:0]	io_sel,					//	io_sel[0]			PIN41
											//	io_sel[1]			PIN42
											//	io_sel[2]			PIN80
	output			io_clk,					//	io_clk				PIN86
	output			reset_n,				//	reset_n				PIN49
	output	[7:0]	dio,					//	dio[0]				PIN30
											//	dio[1]				PIN31
											//	dio[2]				PIN17
											//	dio[3]				PIN20
											//	dio[4]				PIN19
											//	dio[5]				PIN18
											//	dio[6]				PIN72
											//	dio[7]				PIN71
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
	wire			clk215m;
	reg		[4:0]	ff_reset_cnt = 5'd0;
	wire			w_msx_reset_pre_n;
	wire			w_msx_reset_n;

	reg				ff_z80_pre_reset_n = 1'b0;				/* synthesis syn_preserve = 1 */
	reg				ff_r800_pre_reset_n = 1'b0;				/* synthesis syn_preserve = 1 */
	reg				ff_s2026a_pre_reset_n = 1'b0;			/* synthesis syn_preserve = 1 */
	reg				ff_extio_pre_reset_n = 1'b0;			/* synthesis syn_preserve = 1 */
	reg				ff_config_rom_pre_reset_n = 1'b0;		/* synthesis syn_preserve = 1 */
	reg				ff_ext_rom_pre_reset_n = 1'b0;			/* synthesis syn_preserve = 1 */
	reg				ff_bootrom_pre_reset_n = 1'b0;			/* synthesis syn_preserve = 1 */
	reg				ff_uart_pre_reset_n = 1'b0;				/* synthesis syn_preserve = 1 */
	reg				ff_z80_reset_n = 1'b0;					/* synthesis syn_preserve = 1 */
	reg				ff_r800_reset_n = 1'b0;					/* synthesis syn_preserve = 1 */
	reg				ff_s2026a_reset_n = 1'b0;				/* synthesis syn_preserve = 1 */
	reg				ff_extio_reset_n = 1'b0;				/* synthesis syn_preserve = 1 */
	reg				ff_config_rom_reset_n = 1'b0;			/* synthesis syn_preserve = 1 */
	reg				ff_ext_rom_reset_n = 1'b0;				/* synthesis syn_preserve = 1 */
	reg				ff_bootrom_reset_n = 1'b0;				/* synthesis syn_preserve = 1 */
	reg				ff_uart_reset_n = 1'b0;					/* synthesis syn_preserve = 1 */
	wire			w_z80_pre_reset_n;
	wire			w_r800_pre_reset_n;
	wire			w_z80_reset_n;
	wire			w_r800_reset_n;
	wire			w_s2026a_pre_reset_n;
	wire			w_s2026a_reset_n;
	wire			w_extio_pre_reset_n;
	wire			w_extio_reset_n;
	wire			w_config_rom_pre_reset_n;
	wire			w_config_rom_reset_n;
	wire			w_ext_rom_pre_reset_n;
	wire			w_ext_rom_reset_n;
	wire			w_bootrom_pre_reset_n;
	wire			w_bootrom_reset_n;
	wire			w_uart_pre_reset_n;
	wire			w_uart_reset_n;

	reg		[3:0]	ff_3_579m = 4'd0;
	wire			w_3_579m;
	reg		[3:0]	ff_21m = 4'd0;
	wire			w_21m;
	reg		[21:0]	ff_counter;
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

	wire			w_bus_extio_cs;
	wire	[7:0]	w_bus_extio_rdata;
	wire			w_bus_extio_rdata_en;
	wire			w_bus_extio_ready;

	wire			w_bus_crom_cs;
	wire	[7:0]	w_bus_crom_rdata;
	wire			w_bus_crom_rdata_en;
	wire			w_bus_crom_ready;

	wire			w_bus_erom_cs;
	wire	[7:0]	w_bus_erom_rdata;
	wire			w_bus_erom_rdata_en;
	wire			w_bus_erom_ready;

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
		.clkout					( clk215m					),		//	output clkout	214.7727MHz
		.clkin					( clk14m					)		//	input clkin		14.31818MHz
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
			ff_21m <= 2'd0;
		end
		else if( w_21m ) begin
			ff_21m <= 2'd0;
		end
		else begin
			ff_21m <= ff_21m + 2'd1;
		end
	end

	assign w_21m	= (ff_21m == 2'd3) ? 1'b1 : 1'b0;

	// --------------------------------------------------------------------
	//	Reset
	// --------------------------------------------------------------------
	always @( posedge clk42m ) begin
		if( ff_reset_cnt != 5'b11111 ) begin
			ff_reset_cnt <= ff_reset_cnt + 5'd1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_msx_reset_pre_n ) begin
			ff_z80_pre_reset_n <= 1'b0;
		end
		else begin
			ff_z80_pre_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_msx_reset_pre_n ) begin
			ff_r800_pre_reset_n <= 1'b0;
		end
		else begin
			ff_r800_pre_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_msx_reset_pre_n ) begin
			ff_s2026a_pre_reset_n <= 1'b0;
		end
		else begin
			ff_s2026a_pre_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_msx_reset_pre_n ) begin
			ff_extio_pre_reset_n <= 1'b0;
		end
		else begin
			ff_extio_pre_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_msx_reset_pre_n ) begin
			ff_config_rom_pre_reset_n <= 1'b0;
		end
		else begin
			ff_config_rom_pre_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_msx_reset_pre_n ) begin
			ff_ext_rom_pre_reset_n <= 1'b0;
		end
		else begin
			ff_ext_rom_pre_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_msx_reset_pre_n ) begin
			ff_bootrom_pre_reset_n <= 1'b0;
		end
		else begin
			ff_bootrom_pre_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_msx_reset_pre_n ) begin
			ff_uart_pre_reset_n <= 1'b0;
		end
		else begin
			ff_uart_pre_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_z80_pre_reset_n ) begin
			ff_z80_reset_n <= 1'b0;
		end
		else begin
			ff_z80_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_r800_pre_reset_n ) begin
			ff_r800_reset_n <= 1'b0;
		end
		else begin
			ff_r800_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_s2026a_pre_reset_n ) begin
			ff_s2026a_reset_n <= 1'b0;
		end
		else begin
			ff_s2026a_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_extio_pre_reset_n ) begin
			ff_extio_reset_n <= 1'b0;
		end
		else begin
			ff_extio_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_config_rom_pre_reset_n ) begin
			ff_config_rom_reset_n <= 1'b0;
		end
		else begin
			ff_config_rom_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_ext_rom_pre_reset_n ) begin
			ff_ext_rom_reset_n <= 1'b0;
		end
		else begin
			ff_ext_rom_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_bootrom_pre_reset_n ) begin
			ff_bootrom_reset_n <= 1'b0;
		end
		else begin
			ff_bootrom_reset_n <= 1'b1;
		end
	end

	always @( posedge clk42m ) begin
		if( !w_uart_pre_reset_n ) begin
			ff_uart_reset_n <= 1'b0;
		end
		else begin
			ff_uart_reset_n <= 1'b1;
		end
	end

	assign w_msx_reset_pre_n		= (ff_reset_cnt[4:2] != 3'b000  ) ? 1'b1: 1'b0;
	assign w_msx_reset_n			= (ff_reset_cnt      == 5'b11111) ? 1'b1: 1'b0;
	assign w_z80_pre_reset_n		= ff_z80_pre_reset_n;
	assign w_z80_reset_n			= ff_z80_reset_n;
	assign w_r800_pre_reset_n		= ff_r800_pre_reset_n;
	assign w_r800_reset_n			= ff_r800_reset_n;
	assign w_s2026a_pre_reset_n		= ff_s2026a_pre_reset_n;
	assign w_s2026a_reset_n			= ff_s2026a_reset_n;
	assign w_extio_pre_reset_n		= ff_extio_pre_reset_n;
	assign w_extio_reset_n			= ff_extio_reset_n;
	assign w_config_rom_pre_reset_n	= ff_config_rom_pre_reset_n;
	assign w_config_rom_reset_n		= ff_config_rom_reset_n;
	assign w_ext_rom_pre_reset_n	= ff_ext_rom_pre_reset_n;
	assign w_ext_rom_reset_n		= ff_ext_rom_reset_n;
	assign w_bootrom_pre_reset_n	= ff_bootrom_pre_reset_n;
	assign w_bootrom_reset_n		= ff_bootrom_reset_n;
	assign w_uart_pre_reset_n		= ff_uart_pre_reset_n;
	assign w_uart_reset_n			= ff_uart_reset_n;

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
		.reset_n				( w_z80_reset_n				),
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
		.reset_n				( w_r800_reset_n			),
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
		.reset_n				( w_s2026a_reset_n			),
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
		.bus_extio_cs			( w_bus_extio_cs			),
		.bus_extio_rdata		( w_bus_extio_rdata			),
		.bus_extio_rdata_en		( w_bus_extio_rdata_en		),
		.bus_extio_ready		( w_bus_extio_ready			),
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
	//	FPGA (VDP) connection
	// --------------------------------------------------------------------
//	fpga_connect_master u_fpga_connect_master (
//		.reset_n				( w_fpga_reset_n			),
//		.clk					( clk42m					),
//		.clk_serial				( clk215m					),
//		.bus_cs					( w_bus_fpga_cs				),
//		.bus_address			( w_bus_address[7:0]		),
//		.bus_write				( w_bus_write				),
//		.bus_wdata				( w_bus_wdata				),
//		.bus_valid				( w_bus_valid				),
//		.bus_ready				( w_bus_fpga_ready			),
//		.bus_rdata				( w_bus_fpga_rdata			),
//		.bus_rdata_en			( w_bus_fpga_rdata_en		),
//		.sound_l				( 32'd0						),
//		.sound_r				( 32'd0						),
//		.sound_valid			( 1'b0						),
//		.sound_ready			( 							),
//		.fpga_so_clk			( fpga_so_clk				),
//		.fpga_so				( fpga_so					)
//	);
//
//	fpga_connect_slave u_fpga_connect_slave (
//		.reset_n				( w_fpga_reset_n			),
//		.clk					( clk42m					),
//		.clk_serial				( clk215m					),
//		.bus_address			( bus_ctrl0_address[7:0]	),
//		.bus_write				( bus_ctrl0_write			),
//		.bus_wdata				( bus_ctrl0_wdata			),
//		.bus_valid				( bus_ctrl0_valid			),
//		.bus_ready				( bus_ctrl0_ready			),
//		.bus_rdata				( bus_ctrl0_rdata			),
//		.bus_rdata_en			( bus_ctrl0_rdata_en		),
//		.sound_l				( sound_l					),
//		.sound_r				( sound_r					),
//		.sound_valid			( sound_valid				),
//		.sound_ready			( sound_ready				),
//		.fpga_si_clk			( fpga_si_clk				),
//		.fpga_si				( fpga_si					)
//	);
//
//	assign sound_ready = 1'b1;

	// --------------------------------------------------------------------
	//	Extended I/O
	// --------------------------------------------------------------------
	extio_a u_extio (
		.reset_n				( w_extio_reset_n			),
		.clk					( clk42m					),
		.bus_cs					( w_bus_extio_cs			),
		.bus_address			( w_bus_address[3:0]		),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_extio_ready			),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_extio_rdata			),
		.bus_rdata_en			( w_bus_extio_rdata_en		),
		.bus_crom_cs			( w_bus_crom_cs				),
		.bus_erom_cs			( w_bus_erom_cs				)
	);

	// --------------------------------------------------------------------
	//	config SPI ROM
	// --------------------------------------------------------------------
	ip_spi_rom u_config_rom (
		.reset					( ~w_config_rom_reset_n		),
		.clk					( clk42m					),
		.clk_serial				( clk215m					),
		.bus_cs					( w_bus_crom_cs				),
		.bus_address			( w_bus_address[0]			),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_crom_ready			),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_crom_rdata			),
		.bus_rdata_en			( w_bus_crom_rdata_en		),
		.srom0_cs_n				( 							),
		.srom1_cs_n				( flash_spi_cs_n			),
		.srom_clk				( flash_spi_ck				),
		.srom_hold_n			( flash_spi_hold_n			),
		.srom_wp_n				( flash_spi_wp_n			),
		.srom_do				( flash_spi_do				),
		.srom_di				( flash_spi_di				)
	);

	// --------------------------------------------------------------------
	//	ExtROM
	// --------------------------------------------------------------------
	ip_spi_rom u_ext_rom (
		.reset					( ~w_ext_rom_reset_n		),
		.clk					( clk42m					),
		.clk_serial				( clk215m					),
		.bus_cs					( w_bus_erom_cs				),
		.bus_address			( w_bus_address[0]			),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_erom_ready			),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_erom_rdata			),
		.bus_rdata_en			( w_bus_erom_rdata_en		),
		.srom0_cs_n				( srom0_spi_cs_n			),
		.srom1_cs_n				( srom1_spi_cs_n			),
		.srom_clk				( srom_spi_ck				),
		.srom_hold_n			( srom_spi_hold_n			),
		.srom_wp_n				( srom_spi_wp_n				),
		.srom_do				( srom_spi_do				),
		.srom_di				( srom_spi_di				)
	);

	// --------------------------------------------------------------------
	//	BOOT ROM
	// --------------------------------------------------------------------
	bootrom u_bootrom (
		.reset_n				( w_bootrom_reset_n			),
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
	uart u_uart (
		.reset_n				( w_uart_reset_n			),
		.clk					( clk42m					),
		.clk_uart				( clk27m					),
		.bus_uart_cs			( w_bus_uart_cs				),
		.bus_valid				( w_bus_valid				),
		.bus_write				( w_bus_write				),
		.bus_ready				( w_bus_uart_ready			),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_uart_rdata			),
		.bus_rdata_en			( w_bus_uart_rdata_en		),
		.uart_tx				( uart_tx					),
		.button					( ff_button_d1				)
	);

	// --------------------------------------------------------------------
	//	SDRAM
	// --------------------------------------------------------------------
//	ip_sdram #(
//		.FREQ					( 85_909_080				)		//	Hz
//	) u_sdram (
//		.reset_n				( w_sdram_reset_n			),
//		.clk					( clk85m					),		//	85.90908MHz
//		.clk_sdram				( clk85m_n					),
//		.sdram_init_busy		( w_sdram_init_busy			),
//		.bus_address			( w_sdram_address			),
//		.bus_valid				( w_sdram_valid				),
//		.bus_write				( w_sdram_write				),
//		.bus_refresh			( w_sdram_refresh			),
//		.bus_wdata				( w_sdram_wdata				),
//		.bus_wdata_mask			( w_sdram_wdata_mask		),
//		.bus_rdata				( w_sdram_rdata				),
//		.bus_rdata_en			( w_sdram_rdata_en			),
//		.O_sdram_clk			( O_sdram_clk				),
//		.O_sdram_cke			( O_sdram_cke				),
//		.O_sdram_cs_n			( O_sdram_cs_n				),		// chip select
//		.O_sdram_ras_n			( O_sdram_ras_n				),		// row address select
//		.O_sdram_cas_n			( O_sdram_cas_n				),		// columns address select
//		.O_sdram_wen_n			( O_sdram_wen_n				),		// write enable
//		.IO_sdram_dq			( IO_sdram_dq				),		// 32 bit bidirectional data bus
//		.O_sdram_addr			( O_sdram_addr				),		// 11 bit multiplexed address bus
//		.O_sdram_ba				( O_sdram_ba				),		// two banks
//		.O_sdram_dqm			( O_sdram_dqm				)		// data mask
//	);

	// --------------------------------------------------------------------
	//	Port assign
	// --------------------------------------------------------------------
	assign vdp_so_clk		= 1'b0;
	assign vdp_so			= 2'b00;
	assign pa_en			= 1'b0;
	assign i2s_bclk			= 1'b0;
	assign i2s_lrck			= 1'b0;
	assign i2s_dout			= 1'b0;
	assign ws2812			= 1'b0;
	assign io_sel			= 3'b000;
	assign io_clk			= 1'b0;
	
	assign O_sdram_clk		= 1'b0;
	assign O_sdram_cke		= 1'b0;
	assign O_sdram_cs_n		= 1'b1;
	assign O_sdram_cas_n	= 1'b1;
	assign O_sdram_ras_n	= 1'b1;
	assign O_sdram_wen_n	= 1'b1;
	assign O_sdram_addr		= 11'd0;
	assign O_sdram_ba		= 2'd0;
	assign O_sdram_dqm		= 4'b1111;
	assign IO_sdram_dq		= 32'hZZZZ_ZZZZ;
	assign reset_n			= w_z80_reset_n;
	assign dio				= { 3'd0, ff_button_d1, dipsw, 2'd0};
endmodule
