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
	reg		[3:0]	ff_reset_cnt = 4'd0;
	wire			w_msx_reset_n;
	reg		[3:0]	ff_3_579m = 4'd0;
	wire			w_3_579m;
	reg		[21:0]	ff_counter;
	reg				ff_led;

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
		if( ff_reset_cnt != 4'b1111 ) begin
			ff_reset_cnt <= ff_reset_cnt + 4'd1;
		end
	end

	assign w_msx_reset_n = (ff_reset_cnt == 4'b1111) ? 1'b1: 1'b0;

	// --------------------------------------------------------------------
	//	TEST LOGIC
	// --------------------------------------------------------------------
	reg		[2:0]	ff_state;
	reg		[7:0]	ff_wdata;
	reg				ff_valid;

	always @( posedge clk42m ) begin
		if( !w_msx_reset_n ) begin
			ff_state <= 3'd0;
			ff_wdata <= "-";
			ff_valid <= 1'b0;
		end
		else begin
			case( ff_state )
			3'd0: begin
				if( button[0] == 1'b1 ) begin
					ff_state <= ff_state + 3'd1;
				end
			end
			3'd1: begin
				if( button[0] == 1'b0 ) begin
					ff_state <= ff_state + 3'd1;
				end
			end
			3'd2: begin
				if( ff_valid && w_bus_uart_ready ) begin
					ff_wdata <= "T";
					ff_state <= ff_state + 3'd1;
					ff_valid <= 1'b0;
				end
				else begin
					ff_valid <= 1'b1;
				end
			end
			3'd3: begin
				if( ff_valid && w_bus_uart_ready ) begin
					ff_wdata <= "E";
					ff_state <= ff_state + 3'd1;
					ff_valid <= 1'b0;
				end
				else begin
					ff_valid <= 1'b1;
				end
			end
			3'd4: begin
				if( ff_valid && w_bus_uart_ready ) begin
					ff_wdata <= "S";
					ff_state <= ff_state + 3'd1;
					ff_valid <= 1'b0;
				end
				else begin
					ff_valid <= 1'b1;
				end
			end
			3'd5: begin
				if( ff_valid && w_bus_uart_ready ) begin
					ff_wdata <= "T";
					ff_state <= ff_state + 3'd1;
					ff_valid <= 1'b0;
				end
				else begin
					ff_valid <= 1'b1;
				end
			end
			3'd6: begin
				if( ff_valid && w_bus_uart_ready ) begin
					ff_wdata <= " ";
					ff_state <= ff_state + 3'd1;
					ff_valid <= 1'b0;
				end
				else begin
					ff_valid <= 1'b1;
				end
			end
			3'd7: begin
				if( ff_valid && w_bus_uart_ready ) begin
					ff_wdata <= " ";
					ff_state <= 'd0;
					ff_valid <= 1'b0;
				end
				else begin
					ff_valid <= 1'b1;
				end
			end
			default: begin
				ff_wdata <= " ";
				ff_state <= 'd0;
				ff_valid <= 1'b0;
			end
			endcase
		end
	end

	// --------------------------------------------------------------------
	//	UART
	// --------------------------------------------------------------------
	wire			w_uart_tx;

	uart u_uart (
		.reset_n				( w_msx_reset_n				),
		.clk					( clk42m					),
		.clk_uart				( clk27m					),
		.bus_uart_cs			( 1'b1						),
		.bus_valid				( ff_valid					),
		.bus_write				( 1'b1						),
		.bus_ready				( w_bus_uart_ready			),
		.bus_wdata				( ff_wdata					),
		.bus_rdata				( w_bus_uart_rdata			),
		.bus_rdata_en			( w_bus_uart_rdata_en		),
		.uart_tx				( w_uart_tx					),
		.button					( button					)
	);

	assign uart_tx	= w_uart_tx;
	assign led		= { w_uart_tx, ff_led, ~ff_led, 1'd0, button };

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
