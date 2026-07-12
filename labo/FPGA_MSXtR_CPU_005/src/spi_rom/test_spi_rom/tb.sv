// ============================================================================
//	tb.sv - Testbench for spi_rom.v
//	Test SerialROM
// ============================================================================

`timescale 1ns/1ps

module tb();

	// 85.90908MHz clock half period [ns] = 1000 / (2 * 85.90908)
	localparam	real	CLK_HALF_PERIOD_NS			= (1000.0 / (2.0 * 85.90908));
	// 214.7727MHz clock half period [ns] = 1000 / (2 * 214.7727)
	localparam	real	CLK_SERIAL_HALF_PERIOD_NS	= (1000.0 / (2.0 * 214.7727));

	reg				reset;
	reg				clk;
	reg				clk_serial;
	reg				bus_cs;
	reg				bus_address;
	reg				bus_write;
	reg				bus_valid;
	reg		[7:0]	bus_wdata;
	integer			test_number;
	logic	[7:0]	burst_write_pattern [0:255];
	wire			bus_ready;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;
	wire			srom0_cs_n;
	wire			srom1_cs_n;
	wire			srom_clk;
	tri			srom_hold_n;
	tri			srom_wp_n;
	tri			srom_do;
	tri			srom_di;

	localparam	[7:0]	CMD_SET_ADDRESS					= 8'd0;
	localparam	[7:0]	CMD_SINGLE_READ					= 8'd1;
	localparam	[7:0]	CMD_BURST_READ					= 8'd2;
	localparam	[7:0]	CMD_BURST_WRITE					= 8'd3;
	localparam	[7:0]	CMD_CHIP_ERASE					= 8'd4;
	localparam	[7:0]	CMD_READ_STATUS					= 8'd5;
	localparam	[7:0]	CMD_SELECT_SROM					= 8'd6;
	localparam	[7:0]	CMD_ACCESS_END					= 8'd7;
	localparam	[7:0]	CMD_WRITE_ENABLE				= 8'd8;
	localparam	[7:0]	CMD_BLOCK_ERASE					= 8'd9;

	// ---------------------------------------------------------
	//	Clock generation
	// ---------------------------------------------------------
	always begin
		#(CLK_HALF_PERIOD_NS) clk = ~clk;
	end

	always begin
		#(CLK_SERIAL_HALF_PERIOD_NS) clk_serial = ~clk_serial;
	end

	// ---------------------------------------------------------
	//	BUS access tasks
	// ---------------------------------------------------------
	task write_data(
		input			address,
		input 	[7:0]	data
	);
		bus_address	<= address;
		bus_wdata	<= data;
		bus_cs		<= 1'b1;
		bus_write	<= 1'b1;
		bus_valid	<= 1'b1;
		@( posedge clk );
		while( !bus_ready ) begin
			@( posedge clk );
		end
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
	endtask

	task read_data(
		input			address,
		output [7:0]	data
	);
		bus_address	<= address;
		bus_wdata	<= 8'h00;
		bus_cs		<= 1'b1;
		bus_write	<= 1'b0;
		bus_valid	<= 1'b1;
		@( posedge clk );
		while( !bus_ready ) begin
			@( posedge clk );
		end
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		while( !bus_rdata_en ) begin
			@( posedge clk );
		end
		data = bus_rdata;
	endtask

	// ---------------------------------------------------------
	//	Serial ROM model
	// ---------------------------------------------------------
	W25Q32JVxxIM u_srom0 (
		.CSn		( srom0_cs_n	), 
		.CLK		( srom_clk		), 
		.DIO		( srom_di		), 
		.DO			( srom_do		), 
		.WPn		( srom_wp_n		), 
		.HOLDn		( srom_hold_n	), 
		.RESETn		( ~reset		)
	);

	W25Q32JVxxIM u_srom1 (
		.CSn		( srom1_cs_n	), 
		.CLK		( srom_clk		), 
		.DIO		( srom_di		), 
		.DO			( srom_do		), 
		.WPn		( srom_wp_n		), 
		.HOLDn		( srom_hold_n	), 
		.RESETn		( ~reset		)
	);

	// ---------------------------------------------------------
	//	DUT
	// ---------------------------------------------------------
	ip_spi_rom u_spi_rom (
		.reset			( reset			),
		.clk			( clk			),
		.clk_serial		( clk_serial	),
		.bus_cs			( bus_cs		),
		.bus_address	( bus_address	),
		.bus_write		( bus_write		),
		.bus_valid		( bus_valid		),
		.bus_ready		( bus_ready		),
		.bus_wdata		( bus_wdata		),
		.bus_rdata		( bus_rdata		),
		.bus_rdata_en	( bus_rdata_en	),
		.srom0_cs_n		( srom0_cs_n	),
		.srom1_cs_n		( srom1_cs_n	),
		.srom_clk		( srom_clk		),
		.srom_hold_n	( srom_hold_n	),
		.srom_wp_n		( srom_wp_n		),
		.srom_do		( srom_do		),
		.srom_di		( srom_di		)
	);

	// ---------------------------------------------------------
	//	Test sequence
	// ---------------------------------------------------------
	initial begin
		logic [7:0]	data;
		int i;
		int read_address;

		reset		= 1'b1;
		clk			= 1'b0;
		clk_serial	= 1'b0;
		bus_cs		= 1'b0;
		bus_address	= 1'b0;
		bus_write	= 1'b0;
		bus_valid	= 1'b0;
		bus_wdata	= 8'h00;
		test_number	= 0;
		repeat( 8 ) begin
			@( posedge clk );
		end

		reset = 1'b0;
		repeat( 10 ) begin
			@( posedge clk );
		end

		// ---------------------------------------------------------
		//	テスト開始
		// ---------------------------------------------------------

		// ---------------------------------------------------------
		//	アドレスセットテスト
		// ---------------------------------------------------------
		test_number = 1;
		$display( "Test %0d: cmd set address", test_number );
		write_data( 1'b0, CMD_SET_ADDRESS );
		write_data( 1'b1, 8'h56 );
		write_data( 1'b1, 8'h34 );
		write_data( 1'b1, 8'h12 );
		@( posedge clk );
		if( u_spi_rom.ff_rom_address !== 24'h123456 ) begin
			$display( "Test %0d: NG ff_rom_address=%06h expected=%06h", test_number, u_spi_rom.ff_rom_address, 24'h123456 );
		end
		else begin
			$display( "Test %0d: OK ff_rom_address=%06h", test_number, u_spi_rom.ff_rom_address );
		end

		// ---------------------------------------------------------
		//	SROM0選択テスト
		// ---------------------------------------------------------
		test_number = 2;
		$display( "Test %0d: cmd select srom0", test_number );
		write_data( 1'b0, CMD_SELECT_SROM );
		write_data( 1'b1, 8'h00 );
		@( posedge clk );
		if( (u_spi_rom.ff_srom0_cs_n !== 1'b0) || (u_spi_rom.ff_srom1_cs_n !== 1'b1) ) begin
			$display( "Test %0d: NG srom0_cs_n=%b srom1_cs_n=%b expected=0,1", test_number, u_spi_rom.ff_srom0_cs_n, u_spi_rom.ff_srom1_cs_n );
		end
		else begin
			$display( "Test %0d: OK srom0_cs_n=%b srom1_cs_n=%b", test_number, u_spi_rom.ff_srom0_cs_n, u_spi_rom.ff_srom1_cs_n );
		end
		
		// ---------------------------------------------------------
		//	SROM1選択テスト
		// ---------------------------------------------------------
		test_number = 3;
		$display( "Test %0d: cmd select srom1", test_number );
		write_data( 1'b0, CMD_SELECT_SROM );
		write_data( 1'b1, 8'h01 );
		@( posedge clk );
		if( (u_spi_rom.ff_srom0_cs_n !== 1'b1) || (u_spi_rom.ff_srom1_cs_n !== 1'b0) ) begin
			$display( "Test %0d: NG srom0_cs_n=%b srom1_cs_n=%b expected=1,0", test_number, u_spi_rom.ff_srom0_cs_n, u_spi_rom.ff_srom1_cs_n );
		end
		else begin
			$display( "Test %0d: OK srom0_cs_n=%b srom1_cs_n=%b", test_number, u_spi_rom.ff_srom0_cs_n, u_spi_rom.ff_srom1_cs_n );
		end

		// ---------------------------------------------------------
		//	WRITE_ENABLE コマンド送信
		// ---------------------------------------------------------
		test_number = 4;
		$display( "Test %0d: cmd write enable(06h)", test_number );
		write_data( 1'b0, CMD_WRITE_ENABLE );

		//	WEL(bit1) が立つまで STATUS READ でポーリングする。
		write_data( 1'b0, CMD_READ_STATUS );
		for( i = 0; i < 500; i++ ) begin
			read_data( 1'b1, data );
			//	bus_rdata は busy(bit0) のみなので、内部の生SR1を参照して WEL(bit1) を確認する。
			data = u_spi_rom.w_serial_rdata;
			if( data[1] == 1'b1 ) begin
				break;
			end
			repeat( 80 ) @( posedge clk );
		end
		if( i >= 500 ) begin
			$display( "Test %0d: NG timeout waiting WEL=1 (500us)", test_number );
		end
		else begin
			$display( "Test %0d: OK WEL=1 status=%02x", test_number, data );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		// ---------------------------------------------------------
		//	SROM1消去テスト
		// ---------------------------------------------------------
//		test_number = 5;
//		$display( "Test %0d: cmd erase srom1", test_number );
//		write_data( 1'b0, CMD_CHIP_ERASE );
//		write_data( 1'b1, 8'h00 );
//
//		write_data( 1'b0, CMD_READ_STATUS );
//		for( i = 0; i < 100; i++ ) begin
//			read_data( 1'b1, data );
//			if( data[0] == 1'b0 ) begin
//				break;
//			end
//			@( posedge clk );
//			ff_clock_active = 1'b0;
//			# 1000_000_000;
//			ff_clock_active = 1'b1;
//			@( posedge clk );
//		end
//		if( i >= 100) begin
//			$display( "Test %0d: NG timeout", test_number );
//		end
//		else begin
//			$display( "Test %0d: OK srom1 erased", test_number );
//		end
//		write_data( 1'b0, CMD_ACCESS_END );

		// ---------------------------------------------------------
		//	連続書き込みテスト1
		// ---------------------------------------------------------
		test_number = 6;
		$display( "Test %0d: burst write 256 bytes to address 0", test_number );

		for( i = 0; i < 256; i++ ) begin
			burst_write_pattern[i] = $urandom();
		end

		write_data( 1'b0, CMD_SET_ADDRESS );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b1, 8'h00 );

		write_data( 1'b0, CMD_BURST_WRITE );
		for( i = 0; i < 256; i++ ) begin
			$display( "  Write [%06x] = %02x;", i, burst_write_pattern[i] );
			write_data( 1'b1, burst_write_pattern[i] );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		write_data( 1'b0, CMD_READ_STATUS );
		for( i = 0; i < 1000; i++ ) begin
			read_data( 1'b1, data );
			if( data[0] == 1'b0 ) begin
				break;
			end
			repeat( 100 ) @( posedge clk );
		end
		if( i >= 1000) begin
			$display( "Test %0d: NG timeout", test_number );
		end
		else begin
			$display( "Test %0d: OK burst write completed", test_number );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		$display( "Test %0d: burst write pattern queued", test_number );
		
		// ---------------------------------------------------------
		//	読み出しテスト1
		// ---------------------------------------------------------
		test_number = 7;
		$display( "Test %0d: sequential read verify address 0-255", test_number );
		write_data( 1'b0, CMD_SET_ADDRESS );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b0, CMD_BURST_READ );
		for( i = 0; i < 256; i++ ) begin
			read_data( 1'b1, data );
			if( data !== burst_write_pattern[i] ) begin
				$display( "Test %0d: NG address=%06x read=%02x expected=%02x", test_number, i, data, burst_write_pattern[i] );
			end
		end
		write_data( 1'b0, CMD_ACCESS_END );
		$display( "Test %0d: sequential read verify finished", test_number );


		// ---------------------------------------------------------
		//	読み出しテスト2
		// ---------------------------------------------------------
		test_number = 8;
		$display( "Test %0d: random address read verify 256 times", test_number );
		for( i = 0; i < 256; i++ ) begin
			read_address = $urandom_range( 255, 0 );
			write_data( 1'b0, CMD_SET_ADDRESS );
			write_data( 1'b1, read_address[7:0] );
			write_data( 1'b1, 8'h00 );
			write_data( 1'b1, 8'h00 );
			write_data( 1'b0, CMD_SINGLE_READ );
			read_data( 1'b1, data );
			if( data !== burst_write_pattern[read_address] ) begin
				$display( "Test %0d: NG address=%06x read=%02x expected=%02x", test_number, read_address, data, burst_write_pattern[read_address] );
			end
		end
		$display( "Test %0d: random read verify finished", test_number );

		// ---------------------------------------------------------
		//	連続書き込みテスト2
		// ---------------------------------------------------------
		test_number = 9;
		$display( "Test %0d: burst write 256 bytes to address 123400", test_number );

		for( i = 0; i < 256; i++ ) begin
			burst_write_pattern[i] = $urandom();
		end

		write_data( 1'b0, CMD_SET_ADDRESS );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b1, 8'h34 );
		write_data( 1'b1, 8'h12 );

		write_data( 1'b0, CMD_BURST_WRITE );
		for( i = 0; i < 256; i++ ) begin
			$display( "  Write [%06x] = %02x;", 24'h123400 + i, burst_write_pattern[i] );
			write_data( 1'b1, burst_write_pattern[i] );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		write_data( 1'b0, CMD_READ_STATUS );
		for( i = 0; i < 1000; i++ ) begin
			read_data( 1'b1, data );
			if( data[0] == 1'b0 ) begin
				break;
			end
			repeat( 100 ) @( posedge clk );
		end
		if( i >= 1000) begin
			$display( "Test %0d: NG timeout", test_number );
		end
		else begin
			$display( "Test %0d: OK burst write completed", test_number );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		$display( "Test %0d: burst write pattern queued", test_number );
		
		// ---------------------------------------------------------
		//	読み出しテスト1
		// ---------------------------------------------------------
		test_number = 10;
		$display( "Test %0d: sequential read verify address 123400-1234FF", test_number );
		write_data( 1'b0, CMD_SET_ADDRESS );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b1, 8'h34 );
		write_data( 1'b1, 8'h12 );
		write_data( 1'b0, CMD_BURST_READ );
		for( i = 0; i < 256; i++ ) begin
			read_data( 1'b1, data );
			if( data !== burst_write_pattern[i] ) begin
				$display( "Test %0d: NG address=%06x read=%02x expected=%02x", test_number, 24'h123400 + i, data, burst_write_pattern[i] );
			end
		end
		write_data( 1'b0, CMD_ACCESS_END );
		$display( "Test %0d: sequential read verify finished", test_number );


		// ---------------------------------------------------------
		//	読み出しテスト2
		// ---------------------------------------------------------
		test_number = 11;
		$display( "Test %0d: random address read verify 256 times", test_number );
		for( i = 0; i < 256; i++ ) begin
			read_address = $urandom_range( 255, 0 );
			write_data( 1'b0, CMD_SET_ADDRESS );
			write_data( 1'b1, read_address[7:0] );
			write_data( 1'b1, 8'h34 );
			write_data( 1'b1, 8'h12 );
			write_data( 1'b0, CMD_SINGLE_READ );
			read_data( 1'b1, data );
			if( data !== burst_write_pattern[read_address] ) begin
				$display( "Test %0d: NG address=%06x read=%02x expected=%02x", test_number, 24'h123400 + read_address, data, burst_write_pattern[read_address] );
			end
		end
		$display( "Test %0d: random read verify finished", test_number );

		// ---------------------------------------------------------
		//	ブロック消去テスト
		// ---------------------------------------------------------
		test_number = 12;
		$display( "Test %0d: block erase at address 123400", test_number );
		write_data( 1'b0, CMD_SET_ADDRESS );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b1, 8'h34 );
		write_data( 1'b1, 8'h12 );
		write_data( 1'b0, CMD_WRITE_ENABLE );

		write_data( 1'b0, CMD_READ_STATUS );
		for( i = 0; i < 500; i++ ) begin
			read_data( 1'b1, data );
			data = u_spi_rom.w_serial_rdata;
			if( data[1] == 1'b1 ) begin
				break;
			end
			repeat( 80 ) @( posedge clk );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		if( i >= 500 ) begin
			$display( "Test %0d: NG timeout waiting WEL=1 before block erase", test_number );
		end

		write_data( 1'b0, CMD_BLOCK_ERASE );

		write_data( 1'b0, CMD_READ_STATUS );
		for( i = 0; i < 10000; i++ ) begin
			read_data( 1'b1, data );
			if( data[0] == 1'b0 ) begin
				break;
			end
			repeat( 5000 ) @( posedge clk );
		end
		if( i >= 10000 ) begin
			$display( "Test %0d: NG timeout waiting block erase done", test_number );
		end
		else begin
			$display( "Test %0d: OK block erase completed", test_number );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		// ---------------------------------------------------------
		//	WRITE_ENABLE + WELポーリング
		// ---------------------------------------------------------
		test_number = 13;
		$display( "Test %0d: cmd write enable + poll WEL", test_number );
		write_data( 1'b0, CMD_READ_STATUS );
		read_data( 1'b1, data );
		write_data( 1'b0, CMD_ACCESS_END );
		$display( "-- Status : %02x", data );

		write_data( 1'b0, CMD_WRITE_ENABLE );
		$display( "-- Send write enable command" );

		write_data( 1'b0, CMD_READ_STATUS );
		for( i = 0; i < 500; i++ ) begin
			read_data( 1'b1, data );
			data = u_spi_rom.w_serial_rdata;
			if( data[1] == 1'b1 ) begin
				break;
			end
			repeat( 80 ) @( posedge clk );
		end
		if( i >= 500 ) begin
			$display( "Test %0d: NG timeout waiting WEL=1 (500us)", test_number );
		end
		else begin
			$display( "Test %0d: OK WEL=1 status=%02x", test_number, data );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		// ---------------------------------------------------------
		//	連続書き込みテスト3
		// ---------------------------------------------------------
		test_number = 14;
		$display( "Test %0d: burst write 256 random bytes to address 123400", test_number );

		for( i = 0; i < 256; i++ ) begin
			burst_write_pattern[i] = $urandom();
		end

		write_data( 1'b0, CMD_SET_ADDRESS );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b1, 8'h34 );
		write_data( 1'b1, 8'h12 );

		write_data( 1'b0, CMD_BURST_WRITE );
		for( i = 0; i < 256; i++ ) begin
			write_data( 1'b1, burst_write_pattern[i] );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		write_data( 1'b0, CMD_READ_STATUS );
		for( i = 0; i < 5000; i++ ) begin
			read_data( 1'b1, data );
			if( data[0] == 1'b0 ) begin
				break;
			end
			repeat( 200 ) @( posedge clk );
		end
		if( i >= 5000 ) begin
			$display( "Test %0d: NG timeout", test_number );
		end
		else begin
			$display( "Test %0d: OK burst write completed", test_number );
		end
		write_data( 1'b0, CMD_ACCESS_END );

		// ---------------------------------------------------------
		//	読み出しチェックテスト3
		// ---------------------------------------------------------
		test_number = 15;
		$display( "Test %0d: sequential read verify address 123400-1234FF", test_number );
		write_data( 1'b0, CMD_SET_ADDRESS );
		write_data( 1'b1, 8'h00 );
		write_data( 1'b1, 8'h34 );
		write_data( 1'b1, 8'h12 );
		write_data( 1'b0, CMD_BURST_READ );
		for( i = 0; i < 256; i++ ) begin
			read_data( 1'b1, data );
			if( data !== burst_write_pattern[i] ) begin
				$display( "Test %0d: NG address=%06x read=%02x expected=%02x", test_number, 24'h123400 + i, data, burst_write_pattern[i] );
			end
		end
		write_data( 1'b0, CMD_ACCESS_END );
		$display( "Test %0d: sequential read verify finished", test_number );

		// ---------------------------------------------------------
		//	終了
		// ---------------------------------------------------------
		repeat( 100 ) begin
			@( posedge clk );
		end
		$finish;
	end
endmodule
