// -----------------------------------------------------------------------------
//	tangnano20k_vdp_cartridge.v
//	Copyright (C)2025 Takayuki Hara (HRA!)
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

module tangnano20k_vdp_cartridge (
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
	//	HDMI
	output			tmds_clk_p,				//	(PIN33/34)
	output			tmds_clk_n,				//	dummy
	output	[2:0]	tmds_d_p,				//	(PIN39/40), (PIN37/38), (PIN35/36)
	output	[2:0]	tmds_d_n,				//	dummy
	//	SDRAM
	output			O_sdram_clk,
	output			O_sdram_cke,
	output			O_sdram_cs_n,			// chip select
	output			O_sdram_ras_n,			// row address select
	output			O_sdram_cas_n,			// columns address select
	output			O_sdram_wen_n,			// write enable
	inout	[31:0]	IO_sdram_dq,			// 32 bit bidirectional data bus
	output	[10:0]	O_sdram_addr,			// 11 bit multiplexed address bus
	output	[ 1:0]	O_sdram_ba,				// two banks
	output	[ 3:0]	O_sdram_dqm				// data mask
);
	wire			pll_lock215;
	wire			pll_lock85;
	wire			clk42m;				//	42.95454MHz
	wire			clk85m;				//	85.90908MHz
	wire			clk85m_n;			//	85.90908MHz (180deg phase shift)
	wire			clk215m;			//	214.7727MHz

	reg		[3:0]	ff_3_579m = 4'd0;
	wire			w_3_579m;
	reg		[24:0]	ff_counter;
	reg				ff_led;
	wire			w_int_p;

	reg				ff_reset_n0 = 1'b0;
	reg				ff_reset_n1 = 1'b0;
	reg				ff_reset_n2 = 1'b0;
	wire			reset_n;

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

	wire			w_bus_vdp_cs;
	wire			w_bus_vdp_ready;
	wire	[7:0]	w_bus_vdp_rdata;
	wire			w_bus_vdp_rdata_en;

	wire			w_sdram_init_busy;

	wire	[22:2]	w_sdram_address;
	wire			w_sdram_write;
	wire			w_sdram_valid;
	wire			w_sdram_refresh;
	wire	[31:0]	w_sdram_wdata;
	wire	[3:0]	w_sdram_wdata_mask;
	wire	[31:0]	w_sdram_rdata;
	wire			w_sdram_rdata_en;

	wire			w_video_de;
	wire			w_video_hs;
	wire			w_video_vs;
	wire	[7:0]	w_video_r;
	wire	[7:0]	w_video_g;
	wire	[7:0]	w_video_b;

	wire			w_pulse0;
	wire			w_pulse1;
	wire			w_pulse2;
	wire			w_pulse3;
	wire			w_pulse4;
	wire			w_pulse5;
	wire			w_pulse6;
	wire			w_pulse7;
	wire			w_wr;
	wire			w_sending;
	wire	[7:0]	w_red;
	wire	[7:0]	w_green;
	wire	[7:0]	w_blue;
	wire			w_int_n;

	assign slot_wait		= w_sdram_init_busy;
	assign oe_n				= 1'b0;

	always @( posedge clk85m ) begin
		ff_reset_n0		<= 1'b1;
		ff_reset_n1		<= ff_reset_n0;
		ff_reset_n2		<= ff_reset_n1;
	end

	assign reset_n		= ff_reset_n2;

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	Gowin_rPLL u_pll (
		.clkout			( clk215m			),		//	output clkout	214.7727MHz
		.lock			( pll_lock215		),
		.clkin			( clk14m			)		//	input clkin		14.31818MHz
	);

	Gowin_rPLL2 u_pll2 (
		.clkout			( clk85m			),		//	output clkout	85.90908MHz
		.lock			( pll_lock85		),
		.clkoutp		( clk85m_n			),		//	output clkoutp	85.90908MHz (180deg phase shift)
		.clkin			( clk14m			)		//	input clkin		14.31818MHz
    );

	Gowin_CLKDIV u_clkdiv (
		.clkout			( clk42m			),		//	output clkout	42.95454MHz
		.hclkin			( clk85m			),		//	input hclkin	85.90908MHz
		.resetn			( pll_lock85		)		//	input resetn
	);

	always @( posedge clk42m ) begin
		if( !reset_n ) begin
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
		if( !reset_n ) begin
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
	//	Access interface
	// --------------------------------------------------------------------
	assign w_bus_rdata		= ( w_bus_vdp_rdata_en		) ? w_bus_vdp_rdata: 8'hFF;
	assign w_bus_rdata_en	= w_bus_vdp_rdata_en;
	assign w_bus_ready		= w_bus_vdp_ready;

	// --------------------------------------------------------------------
	//	Z80 core
	// --------------------------------------------------------------------

	//	Legasy compatible CPU core
	cz80_inst u_z80 (
		.reset_n				( reset_n					),
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

	assign w_int_p			= ~w_int_n;

	// --------------------------------------------------------------------
	//	System Controller
	// --------------------------------------------------------------------
	s2026a u_s2026a (
		.reset_n				( reset_n					),
		.clk					( clk85m					),
		.enable_z80				( w_3_579m					),
		.sdram_init_busy		( w_sdram_init_busy			),
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
		.bus_vdp_cs				( w_bus_vdp_cs				),
		.bus_vdp_rdata			( w_bus_vdp_rdata			),
		.bus_vdp_rdata_en		( w_bus_vdp_rdata_en		),
		.bus_vdp_ready			( w_bus_vdp_ready			),
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
		.reset_n				( reset_n					),
		.clk					( clk85m					),
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
		.reset_n				( reset_n					),
		.clk					( clk85m					),
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
	assign led		= ff_led;

	// --------------------------------------------------------------------
	//	V9958 clone
	// --------------------------------------------------------------------
	vdp u_v9958 (
		.reset_n			( reset_n					),
		.clk				( clk85m					),
		.initial_busy		( w_sdram_init_busy			),
		.bus_address		( w_bus_address[2:0]		),
		.bus_cs				( w_bus_vdp_cs				),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid				),
		.bus_ready			( w_bus_vdp_ready			),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_vdp_rdata			),
		.bus_rdata_en		( w_bus_vdp_rdata_en		),
		.int_n				( w_int_n					),
		.vram_address		( w_sdram_address[17:2]		),
		.vram_write			( w_sdram_write				),
		.vram_valid			( w_sdram_valid				),
		.vram_wdata			( w_sdram_wdata				),
		.vram_wdata_mask	( w_sdram_wdata_mask		),
		.vram_rdata			( w_sdram_rdata				),
		.vram_rdata_en		( w_sdram_rdata_en			),
		.vram_refresh		( w_sdram_refresh			),
		.display_hs			( w_video_hs				),
		.display_vs			( w_video_vs				),
		.display_en			( w_video_de				),
		.display_r			( w_video_r					),
		.display_g			( w_video_g					),
		.display_b			( w_video_b					),
		.force_highspeed	( dipsw						),
		.button				( button					),
		.pulse0				( w_pulse0					),
		.pulse1				( w_pulse1					),
		.pulse2				( w_pulse2					),
		.pulse3				( w_pulse3					),
		.pulse4				( w_pulse4					),
		.pulse5				( w_pulse5					),
		.pulse6				( w_pulse6					),
		.pulse7				( w_pulse7					)
	);

	assign w_sdram_address[22:18]	= 5'd0;

	// --------------------------------------------------------------------
	//	HDMI
	// --------------------------------------------------------------------
	DVI_TX_Top u_dvi (
		.I_rst_n			( reset_n					),		//input I_rst_n
		.I_serial_clk		( clk215m					),		//input I_serial_clk
		.I_rgb_clk			( clk42m					),		//input I_rgb_clk
		.I_rgb_vs			( w_video_vs				),		//input I_rgb_vs
		.I_rgb_hs			( w_video_hs				),		//input I_rgb_hs
		.I_rgb_de			( w_video_de				),		//input I_rgb_de
		.I_rgb_r			( w_video_r					),		//input [7:0] I_rgb_r
		.I_rgb_g			( w_video_g					),		//input [7:0] I_rgb_g
		.I_rgb_b			( w_video_b					),		//input [7:0] I_rgb_b
		.O_tmds_clk_p		( tmds_clk_p				),		//output O_tmds_clk_p
		.O_tmds_clk_n		( tmds_clk_n				),		//output O_tmds_clk_n
		.O_tmds_data_p		( tmds_d_p					),		//output [2:0] O_tmds_data_p
		.O_tmds_data_n		( tmds_d_n					)		//output [2:0] O_tmds_data_n
	);

	// --------------------------------------------------------------------
	//	SDRAM
	// --------------------------------------------------------------------
	ip_sdram #(
		.FREQ				( 85_909_080				)		//	Hz
	) u_sdram (
		.reset_n			( reset_n					),
		.clk				( clk85m					),		//	85.90908MHz
		.clk_sdram			( clk85m_n					),
		.sdram_init_busy	( w_sdram_init_busy			),
		.bus_address		( w_sdram_address			),
		.bus_valid			( w_sdram_valid				),
		.bus_write			( w_sdram_write				),
		.bus_refresh		( w_sdram_refresh			),
		.bus_wdata			( w_sdram_wdata				),
		.bus_wdata_mask		( w_sdram_wdata_mask		),
		.bus_rdata			( w_sdram_rdata				),
		.bus_rdata_en		( w_sdram_rdata_en			),
		.O_sdram_clk		( O_sdram_clk				),
		.O_sdram_cke		( O_sdram_cke				),
		.O_sdram_cs_n		( O_sdram_cs_n				),		// chip select
		.O_sdram_ras_n		( O_sdram_ras_n				),		// row address select
		.O_sdram_cas_n		( O_sdram_cas_n				),		// columns address select
		.O_sdram_wen_n		( O_sdram_wen_n				),		// write enable
		.IO_sdram_dq		( IO_sdram_dq				),		// 32 bit bidirectional data bus
		.O_sdram_addr		( O_sdram_addr				),		// 11 bit multiplexed address bus
		.O_sdram_ba			( O_sdram_ba				),		// two banks
		.O_sdram_dqm		( O_sdram_dqm				)		// data mask
	);

	// --------------------------------------------------------------------
	//	Debug—p LED
	// --------------------------------------------------------------------
	ip_ws2812_led u_led (
		.reset_n			( reset_n					),
		.clk				( clk85m					),
		.wr					( w_wr						),
		.sending			( w_sending					),
		.red				( w_red						),
		.green				( w_green					),
		.blue				( w_blue					),
		.ws2812_led			( ws2812					)
	);

	// --------------------------------------------------------------------
	//	Debugger
	// --------------------------------------------------------------------
	ip_debugger u_debugger (
		.reset_n			( reset_n					),
		.clk				( clk85m					),
		.pulse0				( w_pulse0					),
		.pulse1				( w_pulse1					),
		.pulse2				( w_pulse2					),
		.pulse3				( w_pulse3					),
		.pulse4				( w_pulse4					),
		.pulse5				( w_pulse5					),
		.pulse6				( w_pulse6					),
		.pulse7				( w_pulse7					),
		.wr					( w_wr						),
		.sending			( w_sending					),
		.red				( w_red						),
		.green				( w_green					),
		.blue				( w_blue					)
	);
endmodule
