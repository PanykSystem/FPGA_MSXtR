`timescale 1ps/1ps

module tb;
	localparam real CLK14M_PERIOD_PS = 1_000_000.0 / 14.318_180;
	localparam real CLK27M_PERIOD_PS = 1_000_000.0 / 27.000_000;
	localparam real SPI_HALF_PS      = (1_000_000.0 / 70.000_000) / 2.0;	//	70MHz SPI: 半周期 約7.142857ns = 約7_142.857ps
	localparam time SPI_INTR_TIMEOUT_PS = 64'd100_000_000;	//	100us timeout

	reg				clk27m;
	reg				clk14m;
	reg		[1:0]	button;
	wire			vdp_so_clk;
	wire	[1:0]	vdp_so;
	reg				vdp_si_clk;
	tri		[1:0]	vdp_si;
	reg				spi_cs_n;
	reg				spi_clk;
	reg				spi_mosi;
	wire			spi_miso;
	wire			spi_intr;
	wire			flash_spi_cs_n;
	wire			flash_spi_clk;
	tri				flash_spi_hold_n;
	tri				flash_spi_wp_n;
	tri				flash_spi_do;
	tri				flash_spi_di;
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
	reg		[7:0]	read_data;

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
	tangnano20k_vdp_cartridge_lcd u_dut (
		.clk27m				( clk27m			),
		.clk14m				( clk14m			),
		.button				( button			),
		.fpga_so_clk		( vdp_so_clk		),
		.fpga_so			( vdp_so			),
		.fpga_si_clk		( vdp_si_clk		),
		.fpga_si			( vdp_si			),
		.spi_cs_n			( spi_cs_n			),
		.spi_clk			( spi_clk			),
		.spi_mosi			( spi_mosi			),
		.spi_miso			( spi_miso			),
		.spi_intr			( spi_intr			),
		.flash_spi_cs_n		( flash_spi_cs_n	),
		.flash_spi_clk		( flash_spi_clk		),
		.flash_spi_hold_n	( flash_spi_hold_n	),
		.flash_spi_wp_n		( flash_spi_wp_n	),
		.flash_spi_do		( flash_spi_do		),
		.flash_spi_di		( flash_spi_di		),
		.ws2812				( ws2812			),
		.uart_tx			( uart_tx			),
		.dipsw				( dipsw				),
		.led				( led				),
		.lcd_clk			( lcd_clk			),
		.lcd_de				( lcd_de			),
		.lcd_hsync			( lcd_hsync			),
		.lcd_vsync			( lcd_vsync			),
		.lcd_red			( lcd_red			),
		.lcd_green			( lcd_green			),
		.lcd_blue			( lcd_blue			),
		.lcd_bl				( lcd_bl			),
		.O_sdram_clk		( O_sdram_clk		),
		.O_sdram_cke		( O_sdram_cke		),
		.O_sdram_cs_n		( O_sdram_cs_n		),
		.O_sdram_cas_n		( O_sdram_cas_n		),
		.O_sdram_ras_n		( O_sdram_ras_n		),
		.O_sdram_wen_n		( O_sdram_wen_n		),
		.IO_sdram_dq		( IO_sdram_dq		),
		.O_sdram_addr		( O_sdram_addr		),
		.O_sdram_ba			( O_sdram_ba		),
		.O_sdram_dqm		( O_sdram_dqm		)
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
			//	1byte 通信ごとに少し待つ
			repeat( 4 ) begin
				#(SPI_HALF_PS);
				#(SPI_HALF_PS);
			end
		end
	endtask

	// --------------------------------------------------------------------
	//	SPI タスク: CS_N フレーミング付きで複数バイト送信
	// --------------------------------------------------------------------
	task automatic spi_write;
		input [7:0]	address;
		input [7:0]	data;
		begin
			spi_cs_n = 1'b0;
			repeat( 8 ) begin
				#(SPI_HALF_PS);
				#(SPI_HALF_PS);
			end
			spi_send_byte( 8'h01 );		//	write
			spi_send_byte( address );
			spi_send_byte( data );
			repeat( 8 ) begin
				#(SPI_HALF_PS);
				#(SPI_HALF_PS);
			end
			spi_cs_n = 1'b1;
			spi_mosi = 1'b0;
		end
	endtask

	// --------------------------------------------------------------------
	//	SPI タスク: 1バイト読み出し
	//	0x02(read) -> address 送信後、spi_intr を待って 1byte 受信
	// --------------------------------------------------------------------
	task automatic spi_read;
		input  [7:0]	address;
		output [7:0]	data;
		integer			i;
		reg    [7:0]	rcv;
		reg			intr_detected;
		begin
			spi_cs_n = 1'b0;
			repeat( 8 ) begin
				#(SPI_HALF_PS);
				#(SPI_HALF_PS);
			end
			spi_send_byte( 8'h02 );		//	read
			spi_send_byte( address );

			intr_detected = 1'b0;
			fork
				begin
					wait( spi_intr == 1'b1 );
					intr_detected = 1'b1;
				end
				begin
					#(SPI_INTR_TIMEOUT_PS);
				end
			join_any
			disable fork;

			if( !intr_detected ) begin
				$display( "[%0t] WARN: spi_read timeout waiting spi_intr (address=0x%02h), continue dummy read", $time, address );
			end

			for( i = 7; i >= 0; i = i - 1 ) begin
				spi_mosi = 1'b0;			//	ダミー送信
				#(SPI_HALF_PS / 2.0);
				rcv[i] = spi_miso;
				#(SPI_HALF_PS / 2.0);
				spi_clk = 1'b1;
				#(SPI_HALF_PS);
				spi_clk = 1'b0;
			end

			repeat( 8 ) begin
				#(SPI_HALF_PS);
				#(SPI_HALF_PS);
			end
			spi_cs_n = 1'b1;
			spi_mosi = 1'b0;
			data = rcv;
		end
	endtask



	initial begin
		clk27m = 1'b0;
		clk14m = 1'b0;
		button = 2'd0;
		vdp_si_clk = 1'b0;
		spi_cs_n = 1'b1;
		spi_clk = 1'b0;
		spi_mosi = 1'b0;
		dipsw = 1'b0;

		repeat(100) @(posedge clk14m);

		spi_write( 8'h99, 8'h00 );			//	アドレス下位 8bit
		spi_write( 8'h99, 8'h40 + 8'h20 );	//	アドレス上位 6bit
		spi_write( 8'h98, 8'hF4 );			//	フォントの色 (前景：白、背景：青 )

		repeat(100) @(posedge clk14m);

		//	43h へのアクセス調査は保留。
		//	まずは実機で確認済みの 40h write/read を検証する。
		spi_write( 8'h40, 8'h40 );
		repeat(10) @(posedge clk14m);
		spi_read( 8'h40, read_data );
		$display( "[%0t] INFO: read_data(port 0x40)=0x%02h", $time, read_data );
		if( read_data !== 8'hBF ) begin
			$error( "port 0x40 read mismatch: actual=0x%02h expected=0xBF", read_data );
		end

		$finish;
	end
endmodule
