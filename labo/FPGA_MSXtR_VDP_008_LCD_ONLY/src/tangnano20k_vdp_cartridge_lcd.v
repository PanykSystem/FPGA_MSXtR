// -----------------------------------------------------------------------------
//	tangnano20k_vdp_cartridge_lcd.v
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

module tangnano20k_vdp_cartridge_lcd (
	input			clk27m,					//	clk27m		PIN04_SYS_CLK		(27MHz)
	input			clk14m,					//	clk14m		PIN76				(14.31818MHz)
	input	[1:0]	button,					//	button[0]	PIN88_MODE0_KEY1
											//	button[1]	PIN87_MODE1_KEY2
	// LCD output
	output			lcd_clk,				//	PIN77
	output			lcd_de,					//	PIN48
	output			lcd_hsync,				//	PIN25
	output			lcd_vsync,				//	PIN26
	output	[4:0]	lcd_red,				//	PIN38, PIN39, PIN40, PIN41, PIN42
	output	[5:0]	lcd_green,				//	PIN32, PIN33, PIN34, PIN35, PIN36, PIN37
	output	[4:0]	lcd_blue,				//	PIN27, PIN28, PIN29, PIN30, PIN31
	output			lcd_bl,					//	PIN49
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

	reg		[24:0]	ff_counter;
	reg				ff_led;

	reg				ff_reset_n0 = 1'b0;
	reg				ff_reset_n1 = 1'b0;
	reg				ff_reset_n2 = 1'b0;
	wire			reset_n;

	wire			w_bus_write;
	wire			w_bus_valid;
	wire	[7:0]	w_bus_wdata;
	wire	[15:0]	w_bus_address;

	wire			bus_ctrl0_io;
	wire			bus_ctrl0_write;
	wire			bus_ctrl0_valid;
	wire			bus_ctrl0_ready;
	wire	[7:0]	bus_ctrl0_wdata;
	wire	[15:0]	bus_ctrl0_address;
	wire	[7:0]	bus_ctrl0_rdata;
	wire			bus_ctrl0_rdata_en;

	wire			bus_ctrl1_io;
	wire			bus_ctrl1_write;
	wire			bus_ctrl1_valid;
	wire			bus_ctrl1_ready;
	wire	[7:0]	bus_ctrl1_wdata;
	wire	[15:0]	bus_ctrl1_address;
	wire	[7:0]	bus_ctrl1_rdata;
	wire			bus_ctrl1_rdata_en;

	wire	[7:0]	w_bus_rdata;
	wire			w_bus_rdata_en;
	wire			w_bus_ready;

	wire			w_bus_vdp_cs;
	wire			w_bus_vdp_ready;
	wire	[7:0]	w_bus_vdp_rdata;
	wire			w_bus_vdp_rdata_en;

	wire			w_bus_uart_cs;
	wire			w_bus_uart_ready;
	wire	[7:0]	w_bus_uart_rdata;
	wire			w_bus_uart_rdata_en;

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

	assign led		= ff_led;

	// --------------------------------------------------------------------
	//	Access interface
	// --------------------------------------------------------------------
	assign bus_ctrl0_io			= 1'b0;
	assign bus_ctrl0_write		= 1'b1;
	assign bus_ctrl0_valid		= 1'b0;
	assign bus_ctrl0_wdata		= 8'd0;
	assign bus_ctrl0_address	= 16'd0;

	assign w_bus_rdata		= ( w_bus_vdp_rdata_en		) ? w_bus_vdp_rdata: 8'hFF;
	assign w_bus_rdata_en	= w_bus_vdp_rdata_en;
	assign w_bus_ready		= w_bus_vdp_ready;

	assign w_sdram_address[22:18]	= 5'd0;

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
	//	LCD display controller
	// --------------------------------------------------------------------
	display_controller u_display_controller (
		.clk				( clk85m					),
		.reset_n			( reset_n					),
		.lcd_clk			( lcd_clk					),
		.lcd_de				( lcd_de					),
		.lcd_hsync			( lcd_hsync					),
		.lcd_vsync			( lcd_vsync					),
		.lcd_red			( lcd_red					),
		.lcd_green			( lcd_green					),
		.lcd_blue			( lcd_blue					),
		.lcd_bl				( lcd_bl					)
	);
endmodule
