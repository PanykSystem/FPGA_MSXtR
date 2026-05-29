`timescale 1ps/1ps

module tb;
	localparam real CLK14M_PERIOD_PS = 1_000_000.0 / 14.318_180;
	localparam real CLK27M_PERIOD_PS = 1_000_000.0 / 27.000_000;
	localparam real SPI_HALF_PS      = 500_000.0;				//	1MHz SPI: 半周期 500ns = 500_000ps

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
	wire			tmds_clk_p;
	wire			tmds_clk_n;
	wire	[2:0]	tmds_d_p;
	wire	[2:0]	tmds_d_n;
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

	// --------------------------------------------------------------------
	//	SDRAM モデル
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
	tangnano20k_vdp_cartridge u_dut (
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
		.tmds_clk_p		( tmds_clk_p	),
		.tmds_clk_n		( tmds_clk_n	),
		.tmds_d_p		( tmds_d_p		),
		.tmds_d_n		( tmds_d_n		),
		.O_sdram_clk	( O_sdram_clk	),
		.O_sdram_cke	( O_sdram_cke	),
		.O_sdram_cs_n	( O_sdram_cs_n	),
		.O_sdram_cas_n	( O_sdram_cas_n	),
		.O_sdram_ras_n	( O_sdram_ras_n	),
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

	// --------------------------------------------------------------------
	//	SPI タスク: 1バイト送信 (MSB first, SPI Mode 0)
	//	  立ち上がりエッジでスレーブが MOSI をサンプル
	//	  立ち下がりエッジでスレーブが MISO をシフト
	// --------------------------------------------------------------------
	task automatic spi_send_byte;
		input [7:0]	data;
		integer i;
		begin
			for( i = 7; i >= 0; i = i - 1 ) begin
				spi_mosi = data[i];			//	MOSI を立ち上がり前にセット
				#(SPI_HALF_PS);
				spi_clk  = 1'b1;			//	立ち上がり: スレーブが MOSI サンプル
				#(SPI_HALF_PS);
				spi_clk  = 1'b0;			//	立ち下がり: スレーブが MISO シフト
			end
		end
	endtask

	// --------------------------------------------------------------------
	//	SPI タスク: CS_N フレーミング付きで複数バイト送信
	// --------------------------------------------------------------------
	task automatic spi_write;
		input [7:0]	b0;
		input [7:0]	b1;
		input [7:0]	b2;
		begin
			spi_cs_n = 1'b0;
			#(SPI_HALF_PS);
			spi_send_byte( b0 );
			spi_send_byte( b1 );
			spi_send_byte( b2 );
			#(SPI_HALF_PS);
			spi_cs_n = 1'b1;
			spi_mosi = 1'b0;
		end
	endtask

	initial begin
		clk27m = 1'b0;
		clk14m = 1'b0;
		button = 2'd0;
		vdp_si_clk = 1'b0;
		vdp_si = 2'd0;
		spi_cs_n = 1'b1;
		spi_clk = 1'b0;
		spi_mosi = 1'b0;
		i2s_bclk = 1'b0;
		i2s_lrck = 1'b0;
		i2s_din = 1'b0;
		dipsw = 1'b0;

		repeat(5000) @(posedge clk14m);

		spi_write( 8'h01, 8'h99, 8'h00 );			//	アドレス下位 8bit
		spi_write( 8'h01, 8'h99, 8'h40 + 8'h20 );	//	アドレス上位 6bit
		spi_write( 8'h01, 8'h98, 8'hF4 );			//	フォントの色 (前景：白、背景：青 )

		repeat(5000) @(posedge clk14m);
		$finish;
	end
endmodule
