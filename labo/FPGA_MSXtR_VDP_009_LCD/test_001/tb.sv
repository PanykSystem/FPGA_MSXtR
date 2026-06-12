`timescale 1ps/1ps

module tb;
	localparam real CLK14M_PERIOD_PS = 1_000_000.0 / 14.318_180;
	localparam real CLK27M_PERIOD_PS = 1_000_000.0 / 27.000_000;
	localparam time POST_INIT_RUN_PS = 64'd35_000_000_000;

	reg				clk27m;
	reg				clk14m;
	reg		[1:0]	button;
	wire			vdp_so_clk;
	wire	[1:0]	vdp_so;
	reg				vdp_si_clk;
	reg		[1:0]	vdp_si;
	reg				spi_cs_n;
	reg				spi_clk;
	reg				spi_mosi;
	wire			spi_miso;
	wire			spi_intr;
	wire			pa_en;
	reg				i2s_bclk;
	reg				i2s_lrck;
	reg				i2s_din;
	wire			intr;
	wire			ws2812;
	wire			uart_tx;
	reg				dipsw;
	wire			led;
	wire			lcd_clk;
	wire			lcd_de;
	wire			lcd_hsync;
	wire			lcd_vsync;
	wire	[4:0]	lcd_red;
	wire	[5:0]	lcd_green;
	wire	[4:0]	lcd_blue;
	wire			lcd_bl;
	wire			O_sdram_clk;
	wire			O_sdram_cke;
	wire			O_sdram_cs_n;
	wire			O_sdram_cas_n;
	wire			O_sdram_ras_n;
	wire			O_sdram_wen_n;
	wire	[31:0]	IO_sdram_dq;
	wire	[10:0]	O_sdram_addr;
	wire	[1:0]	O_sdram_ba;
	wire	[3:0]	O_sdram_dqm;

	reg				measure_enable;
	reg				prev_lcd_vsync;
	reg				prev_lcd_hsync;
	reg				prev_lcd_de;
	integer			vsync_rise_count;
	integer			hsync_rise_count;
	integer			de_rise_count;
	integer			active_pixel_count;
	time				busy_low_time_ps;
	time				first_vsync_ps;
	time				last_vsync_ps;
	time				first_hsync_ps;
	time				last_hsync_ps;

	// --------------------------------------------------------------------
	//	SDRAM model
	// --------------------------------------------------------------------
	mt48lc2m32b2 u_sdram (
		.Dq				( IO_sdram_dq	),
		.Addr			( O_sdram_addr	),
		.Ba				( O_sdram_ba	),
		.Clk			( O_sdram_clk	),
		.Cke			( O_sdram_cke	),
		.Cs_n			( O_sdram_cs_n	),
		.Ras_n			( O_sdram_ras_n	),
		.Cas_n			( O_sdram_cas_n	),
		.We_n			( O_sdram_wen_n	),
		.Dqm			( O_sdram_dqm	)
	);

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	tangnano20k_vdp_cartridge_lcd u_dut (
		.clk27m			( clk27m		),
		.clk14m			( clk14m		),
		.button			( button		),
		.vdp_so_clk		( vdp_so_clk	),
		.vdp_so			( vdp_so		),
		.vdp_si_clk		( vdp_si_clk	),
		.vdp_si			( vdp_si		),
		.spi_cs_n		( spi_cs_n		),
		.spi_clk		( spi_clk		),
		.spi_mosi		( spi_mosi		),
		.spi_miso		( spi_miso		),
		.spi_intr		( spi_intr		),
		.pa_en			( pa_en			),
		.i2s_bclk		( i2s_bclk		),
		.i2s_lrck		( i2s_lrck		),
		.i2s_din		( i2s_din		),
		.intr			( intr			),
		.ws2812			( ws2812		),
		.uart_tx		( uart_tx		),
		.dipsw			( dipsw			),
		.led			( led			),
		.lcd_clk		( lcd_clk		),
		.lcd_de			( lcd_de		),
		.lcd_hsync		( lcd_hsync		),
		.lcd_vsync		( lcd_vsync		),
		.lcd_red		( lcd_red		),
		.lcd_green		( lcd_green		),
		.lcd_blue		( lcd_blue		),
		.lcd_bl			( lcd_bl		),
		.O_sdram_clk	( O_sdram_clk	),
		.O_sdram_cke	( O_sdram_cke	),
		.O_sdram_cs_n	( O_sdram_cs_n	),
		.O_sdram_ras_n	( O_sdram_ras_n	),
		.O_sdram_cas_n	( O_sdram_cas_n	),
		.O_sdram_wen_n	( O_sdram_wen_n	),
		.IO_sdram_dq	( IO_sdram_dq	),
		.O_sdram_addr	( O_sdram_addr	),
		.O_sdram_ba		( O_sdram_ba	),
		.O_sdram_dqm	( O_sdram_dqm	)
	);

	always #(CLK14M_PERIOD_PS / 2.0) begin
		clk14m <= ~clk14m;
	end

	always #(CLK27M_PERIOD_PS / 2.0) begin
		clk27m <= ~clk27m;
	end

	task automatic spi_send_byte;
		input [7:0] data;
		integer i;
		begin
			for( i = 7; i >= 0; i = i - 1 ) begin
				spi_mosi = data[i];
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b1;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b0;
			end
		end
	endtask

	task automatic write_port;
		input [7:0] address;
		input [7:0] data;
		begin
			spi_cs_n = 1'b0;
			spi_clk = 1'b0;
			spi_mosi = 1'b0;
			#(CLK27M_PERIOD_PS * 2);
			spi_send_byte( 8'h01 );
			#(CLK27M_PERIOD_PS * 2);
			spi_send_byte( address );
			#(CLK27M_PERIOD_PS * 2);
			spi_send_byte( data );
			#(CLK27M_PERIOD_PS * 2);
			spi_cs_n = 1'b1;
		end
	endtask

	task automatic read_port;
		input [7:0] address;
		output [7:0] result;
		time timeout_time;
		time current_time;
		reg intr_ready;
		begin
			spi_cs_n = 1'b0;
			spi_clk = 1'b0;
			spi_mosi = 1'b0;
			#(CLK27M_PERIOD_PS * 2);
			spi_send_byte( 8'h02 );
			#(CLK27M_PERIOD_PS * 2);
			spi_send_byte( address );
			#(CLK27M_PERIOD_PS * 2);

			// spi_intr が 1 になるまで待つ（500ms タイムアウト）
			timeout_time = $time + 500_000_000_000;
			intr_ready = 1'b0;

			while( $time < timeout_time ) begin
				if( spi_intr ) begin
					intr_ready = 1'b1;
					break;
				end
				#(CLK27M_PERIOD_PS * 4);
			end

			// タイムアウトした場合は CSn = 1, 0xAA を返す
			if( !intr_ready ) begin
				spi_cs_n = 1'b1;
				result = 8'hAA;
			end
			else begin
				// spi_intr が 1 になったらダミーバイトを送信してデータを受信
				spi_mosi = 1'b0;
				spi_clk = 1'b0;
				#(CLK27M_PERIOD_PS / 4.0);
				// MSB から受信開始
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b1;
				result[7] = spi_miso;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b0;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b1;
				result[6] = spi_miso;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b0;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b1;
				result[5] = spi_miso;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b0;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b1;
				result[4] = spi_miso;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b0;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b1;
				result[3] = spi_miso;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b0;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b1;
				result[2] = spi_miso;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b0;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b1;
				result[1] = spi_miso;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b0;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b1;
				result[0] = spi_miso;
				#(CLK27M_PERIOD_PS / 4.0);
				spi_clk = 1'b0;
				#(CLK27M_PERIOD_PS * 2);
				spi_cs_n = 1'b1;
			end
		end
	endtask

	always @( posedge lcd_clk ) begin
		prev_lcd_vsync <= lcd_vsync;
		prev_lcd_hsync <= lcd_hsync;
		prev_lcd_de <= lcd_de;

		if( measure_enable ) begin
			if( !prev_lcd_vsync && lcd_vsync ) begin
				vsync_rise_count <= vsync_rise_count + 1;
				if( first_vsync_ps == 0 ) begin
					first_vsync_ps <= $time;
				end
				last_vsync_ps <= $time;
			end

			if( !prev_lcd_hsync && lcd_hsync ) begin
				hsync_rise_count <= hsync_rise_count + 1;
				if( first_hsync_ps == 0 ) begin
					first_hsync_ps <= $time;
				end
				last_hsync_ps <= $time;
			end

			if( !prev_lcd_de && lcd_de ) begin
				de_rise_count <= de_rise_count + 1;
			end

			if( lcd_de ) begin
				active_pixel_count <= active_pixel_count + 1;
			end
		end
	end

	initial begin
		clk27m = 1'b0;
		clk14m = 1'b0;
		button = 2'b11;
		vdp_si_clk = 1'b0;
		vdp_si = 2'b11;
		spi_cs_n = 1'b1;
		spi_clk = 1'b1;
		spi_mosi = 1'b1;
		i2s_bclk = 1'b0;
		i2s_lrck = 1'b0;
		i2s_din = 1'b0;
		dipsw = 1'b0;
		measure_enable = 1'b0;
		prev_lcd_vsync = 1'b0;
		prev_lcd_hsync = 1'b0;
		prev_lcd_de = 1'b0;
		vsync_rise_count = 0;
		hsync_rise_count = 0;
		de_rise_count = 0;
		active_pixel_count = 0;
		busy_low_time_ps = 0;
		first_vsync_ps = 0;
		last_vsync_ps = 0;
		first_hsync_ps = 0;
		last_hsync_ps = 0;

		$display( "[%0t] waiting for SDRAM initialization to complete", $time );
		wait( u_dut.w_sdram_init_busy === 1'b1 );
		wait( u_dut.w_sdram_init_busy === 1'b0 );

		$display( "[%0t] write 0x07 to VDP register#7", $time );
		write_port( 8'h99, 8'h07 );		// Data 0x07
		write_port( 8'h99, 8'h87 );		// Register#7 + 0x80

		$display( "[%0t] read 0x20 from ConfigROM data", $time );
		read_port( 8'h20, result );
		$display( "[%0t] -- read data is 0x%0h", $time, result );

		busy_low_time_ps = $time;
		measure_enable = 1'b1;
		$display( "[%0t] initial_busy deasserted, starting LCD observation window", busy_low_time_ps );

		#(POST_INIT_RUN_PS);

		$display( "[%0t] observation finished", $time );
		$display( "    lcd_bl=%0b vsync_edges=%0d hsync_edges=%0d de_edges=%0d active_pixels=%0d",
			lcd_bl,
			vsync_rise_count,
			hsync_rise_count,
			de_rise_count,
			active_pixel_count );

		if( first_vsync_ps != 0 && last_vsync_ps > first_vsync_ps ) begin
			$display( "    vsync period estimate = %0.3f ms",
				(last_vsync_ps - first_vsync_ps) / 1_000_000_000.0 / (vsync_rise_count - 1) );
		end

		if( first_hsync_ps != 0 && last_hsync_ps > first_hsync_ps ) begin
			$display( "    hsync period estimate = %0.3f us",
				(last_hsync_ps - first_hsync_ps) / 1_000_000.0 / (hsync_rise_count - 1) );
		end

		if( vsync_rise_count == 0 || hsync_rise_count == 0 || active_pixel_count == 0 ) begin
			$error( "LCD output activity was not observed after initial_busy deassertion" );
		end

		$finish;
	end
endmodule
