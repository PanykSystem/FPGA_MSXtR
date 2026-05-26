// -----------------------------------------------------------------------------
//	Test of ip_spi
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
//	Description:
//		ip_spi SPI slave controller test.
//		Simulates an SPI master sending multi-byte command packets and verifies
//		that ip_spi asserts the correct bus_* access signals.
//
//	Tested commands:
//		0x01: I/O write  [cmd=0x01][io_addr][data]  (3 bytes)
//			  → bus_io=1, bus_address[7:0]=io_addr, bus_wdata=data, bus_valid=1
//
//	SPI timing note (same convention as test_001/tb.sv):
//		The edge-detection naming inside spi.v is reversed from convention:
//		  w_spi_clk_falling_edge  fires on actual SPI RISING  edge → shifts MISO
//		  w_spi_clk_rising_edge   fires on actual SPI FALLING edge → samples MOSI
//		Master behaviour reproduced here:
//		  - Drive MOSI before the rising edge of spi_clk.
//		  - DUT latches MOSI on the falling edge.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module tb ();
	localparam real	CLK_PERIOD			= 1000.0 / 85.0;		//	~11.76 ns  (85 MHz)
	localparam real	CLK_SERIAL_PERIOD	= 1000.0 / 214.0;		//	~4.67 ns   (214 MHz)
	localparam real	SPI_HALF			= 1000.0 / 42.0 / 2.0;	//	~11.9 ns   (42 MHz SPI)

	int			test_no;
	int			pass_count;
	int			fail_count;

	//	System signals
	reg				reset_n;
	reg				clk;
	reg				clk_serial;

	//	Bus interface (ip_spi outputs / TB inputs)
	wire			bus_io;
	wire			bus_write;
	wire			bus_valid;
	reg				bus_ready;
	wire	[7:0]	bus_wdata;
	wire	[15:0]	bus_address;
	reg		[7:0]	bus_rdata;
	reg				bus_rdata_en;

	//	SPI bus (TB acts as SPI master)
	reg				spi_cs_n;
	reg				spi_clk;
	reg				spi_mosi;
	wire			spi_miso;
	wire			spi_intr;

	//	--------------------------------------------------------------------
	//	Monitor: count bus_valid pulses and capture last transaction values
	//	  bus_valid_count : increments on every bus_valid posedge in clk domain
	//	  captured_*      : updated on every bus_valid pulse
	//	--------------------------------------------------------------------
	int				bus_valid_count;
	reg		[7:0]	captured_wdata;
	reg		[15:0]	captured_address;
	reg				captured_io;
	reg				bus_valid_d;		//	1-cycle delayed bus_valid for edge detection

	//	 bus_valid is held high until bus_ready acknowledges (multi-cycle).
	//	 Count only the rising edge (0→1) so each transaction is counted once.
	always @( posedge clk ) begin
		if ( !reset_n ) begin
			bus_valid_d      <= 1'b0;
			bus_valid_count  <= 0;
			captured_wdata   <= 8'h00;
			captured_address <= 16'h0000;
			captured_io      <= 1'b0;
		end else begin
			bus_valid_d <= bus_valid;
			if ( bus_valid && !bus_valid_d ) begin
				bus_valid_count  <= bus_valid_count + 1;
				captured_wdata   <= bus_wdata;
				captured_address <= bus_address;
				captured_io      <= bus_io;
			end
		end
	end

	//	Automatically acknowledge bus transactions (ready on the next cycle)
	always @( posedge clk ) begin
		if ( !reset_n ) bus_ready <= 1'b0;
		else            bus_ready <= bus_valid;
	end

	// --------------------------------------------------------------------
	//	Clock generators
	// --------------------------------------------------------------------
	always #( CLK_PERIOD / 2.0 ) begin
		clk <= ~clk;
	end

	always #( CLK_SERIAL_PERIOD / 2.0 ) begin
		clk_serial <= ~clk_serial;
	end

	// --------------------------------------------------------------------
	//	DUT: ip_spi (instantiates spi.v internally)
	// --------------------------------------------------------------------
	ip_spi u_dut (
		.reset_n		( reset_n		),
		.clk			( clk			),
		.clk_serial		( clk_serial	),
		.bus_io			( bus_io		),
		.bus_write		( bus_write		),
		.bus_valid		( bus_valid		),
		.bus_ready		( bus_ready		),
		.bus_wdata		( bus_wdata		),
		.bus_address	( bus_address	),
		.bus_rdata		( bus_rdata		),
		.bus_rdata_en	( bus_rdata_en	),
		.spi_cs_n		( spi_cs_n		),
		.spi_clk		( spi_clk		),
		.spi_mosi		( spi_mosi		),
		.spi_miso		( spi_miso		),
		.spi_intr		( spi_intr		)
	);

	// --------------------------------------------------------------------
	//	Task: spi_send_byte
	//	  Sends one byte MSB-first on the SPI bus.
	//	  Precondition : spi_cs_n = 0, spi_clk = 0
	//	  Postcondition: spi_clk = 0; spi_rdata_en propagated after 20 clk cycles
	// --------------------------------------------------------------------
	task automatic spi_send_byte(
		input	[7:0]	data
	);
		int		i;
		//	Clock out 8 bits MSB first
		for ( i = 7; i >= 0; i-- ) begin
			//	Drive MOSI before the rising edge
			spi_mosi = data[i];
			#( SPI_HALF );
			//	Rising edge → DUT shifts MISO to next bit
			spi_clk = 1'b1;
			#( SPI_HALF );
			//	Falling edge → DUT samples MOSI
			spi_clk = 1'b0;
		end
		//	Allow the byte-done toggle to propagate through spi.v's 3-stage
		//	clk_serial→clk synchronizer and be seen by ip_spi's state machine.
		repeat( 20 ) @( posedge clk );
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		reset_n		= 1'b0;
		clk			= 1'b0;
		clk_serial	= 1'b0;
		bus_ready	= 1'b0;
		bus_rdata	= 8'h00;
		bus_rdata_en = 1'b0;
		spi_cs_n	= 1'b1;
		spi_clk		= 1'b0;
		spi_mosi	= 1'b0;
		test_no		= 0;
		pass_count	= 0;
		fail_count	= 0;

		//	Apply reset for 5 clock cycles then release
		repeat( 5 ) @( posedge clk );
		reset_n = 1'b1;
		repeat( 5 ) @( posedge clk );

		// ================================================================
		//	Test 1: I/O Write (command 0x01)
		//	  Packet  : [0x01][0xAB][0xCD]
		//	  Expected: bus_valid=1, bus_io=1, bus_address=0x00AB, bus_wdata=0xCD
		// ================================================================
		test_no = 1;
		$display( "------------------------------------------------------------" );
		$display( "[TEST %0d] I/O Write: cmd=0x01, addr=0xAB, data=0xCD", test_no );

		begin
			int cnt_before;
			cnt_before = bus_valid_count;

			//	Assert CS
			spi_cs_n = 1'b0;
			repeat( 3 ) @( posedge clk );

			//	Byte 1: command byte → ip_spi: ST_COMMAND → ST_2OPERANDS
			$display( "[TEST %0d]   Sending command byte 0x01 ...", test_no );
			spi_send_byte( 8'h01 );

			//	Byte 2: I/O address → ip_spi: ST_2OPERANDS → ST_1OPERAND
			$display( "[TEST %0d]   Sending address byte 0xAB ...", test_no );
			spi_send_byte( 8'hAB );

			//	Byte 3: data → ip_spi: ST_1OPERAND → ST_DO, bus_valid asserts
			$display( "[TEST %0d]   Sending data byte 0xCD ...", test_no );
			spi_send_byte( 8'hCD );

			//	Wait for bus_valid → bus_ready handshake to complete
			repeat( 10 ) @( posedge clk );

			//	Deassert CS
			spi_cs_n = 1'b1;
			spi_mosi = 1'b0;
			repeat( 10 ) @( posedge clk );

			//	Check: bus_valid pulsed exactly once
			if ( bus_valid_count === cnt_before + 1 ) begin
				$display( "[TEST %0d] PASS: bus_valid pulsed once (count=%0d)", test_no, bus_valid_count );
				pass_count = pass_count + 1;
			end else begin
				$display( "[TEST %0d] FAIL: bus_valid pulse count=%0d (expected %0d)", test_no, bus_valid_count, cnt_before + 1 );
				fail_count = fail_count + 1;
			end

			//	Check: bus_io
			if ( captured_io === 1'b1 ) begin
				$display( "[TEST %0d] PASS: bus_io = 1", test_no );
				pass_count = pass_count + 1;
			end else begin
				$display( "[TEST %0d] FAIL: bus_io = %b (expected 1)", test_no, captured_io );
				fail_count = fail_count + 1;
			end

			//	Check: bus_address
			if ( captured_address === 16'h00AB ) begin
				$display( "[TEST %0d] PASS: bus_address = 0x%04X", test_no, captured_address );
				pass_count = pass_count + 1;
			end else begin
				$display( "[TEST %0d] FAIL: bus_address = 0x%04X (expected 0x00AB)", test_no, captured_address );
				fail_count = fail_count + 1;
			end

			//	Check: bus_wdata
			if ( captured_wdata === 8'hCD ) begin
				$display( "[TEST %0d] PASS: bus_wdata = 0x%02X", test_no, captured_wdata );
				pass_count = pass_count + 1;
			end else begin
				$display( "[TEST %0d] FAIL: bus_wdata = 0x%02X (expected 0xCD)", test_no, captured_wdata );
				fail_count = fail_count + 1;
			end
		end

		// ================================================================
		//	Test 2: CS abort after the command byte only
		//	  Send 0x01 then deassert CS before remaining operands.
		//	  Expected: bus_valid does NOT pulse (state returns to ST_IDLE).
		// ================================================================
		test_no = 2;
		$display( "------------------------------------------------------------" );
		$display( "[TEST %0d] CS abort after command byte", test_no );

		begin
			int cnt_before;
			cnt_before = bus_valid_count;

			spi_cs_n = 1'b0;
			repeat( 3 ) @( posedge clk );

			$display( "[TEST %0d]   Sending command byte 0x01 ...", test_no );
			spi_send_byte( 8'h01 );

			//	Abort: deassert CS without sending remaining bytes
			spi_cs_n = 1'b1;
			spi_mosi = 1'b0;
			spi_clk  = 1'b0;
			repeat( 20 ) @( posedge clk );

			if ( bus_valid_count === cnt_before ) begin
				$display( "[TEST %0d] PASS: bus_valid did not pulse after CS abort (count=%0d)", test_no, bus_valid_count );
				pass_count = pass_count + 1;
			end else begin
				$display( "[TEST %0d] FAIL: bus_valid pulsed unexpectedly after CS abort (count=%0d)", test_no, bus_valid_count );
				fail_count = fail_count + 1;
			end
		end

		// ================================================================
		//	Test 3: Unknown command byte (no action defined in ip_spi)
		//	  Send 0x55.
		//	  Expected: command ignored, bus_valid does NOT pulse.
		// ================================================================
		test_no = 3;
		$display( "------------------------------------------------------------" );
		$display( "[TEST %0d] Unknown command 0x55 (should be ignored)", test_no );

		begin
			int cnt_before;
			cnt_before = bus_valid_count;

			spi_cs_n = 1'b0;
			repeat( 3 ) @( posedge clk );

			$display( "[TEST %0d]   Sending unknown command byte 0x55 ...", test_no );
			spi_send_byte( 8'h55 );

			//	Send extra bytes to confirm nothing happens
			spi_send_byte( 8'h12 );
			spi_send_byte( 8'h34 );

			spi_cs_n = 1'b1;
			spi_mosi = 1'b0;
			repeat( 20 ) @( posedge clk );

			if ( bus_valid_count === cnt_before ) begin
				$display( "[TEST %0d] PASS: bus_valid did not pulse for unknown command (count=%0d)", test_no, bus_valid_count );
				pass_count = pass_count + 1;
			end else begin
				$display( "[TEST %0d] FAIL: bus_valid pulsed for unknown command (count=%0d)", test_no, bus_valid_count );
				fail_count = fail_count + 1;
			end
		end

		// ================================================================
		//	Test 4: Second I/O Write (new CS assertion, different values)
		//	  Packet  : [0x01][0x34][0x56]
		//	  Expected: bus_valid=1, bus_io=1, bus_address=0x0034, bus_wdata=0x56
		// ================================================================
		test_no = 4;
		$display( "------------------------------------------------------------" );
		$display( "[TEST %0d] Second I/O Write: cmd=0x01, addr=0x34, data=0x56", test_no );

		//	Brief reset to clear captured values and counter for clean checking
		reset_n = 1'b0;
		repeat( 3 ) @( posedge clk );
		reset_n = 1'b1;
		repeat( 5 ) @( posedge clk );

		begin
			int cnt_before;
			cnt_before = bus_valid_count;		//	should be 0 after reset

			spi_cs_n = 1'b0;
			repeat( 3 ) @( posedge clk );

			$display( "[TEST %0d]   Sending command byte 0x01 ...", test_no );
			spi_send_byte( 8'h01 );

			$display( "[TEST %0d]   Sending address byte 0x34 ...", test_no );
			spi_send_byte( 8'h34 );

			$display( "[TEST %0d]   Sending data byte 0x56 ...", test_no );
			spi_send_byte( 8'h56 );

			repeat( 10 ) @( posedge clk );
			spi_cs_n = 1'b1;
			spi_mosi = 1'b0;
			repeat( 10 ) @( posedge clk );

			//	Check: bus_valid pulsed exactly once
			if ( bus_valid_count === cnt_before + 1 ) begin
				$display( "[TEST %0d] PASS: bus_valid pulsed once (count=%0d)", test_no, bus_valid_count );
				pass_count = pass_count + 1;
			end else begin
				$display( "[TEST %0d] FAIL: bus_valid pulse count=%0d (expected %0d)", test_no, bus_valid_count, cnt_before + 1 );
				fail_count = fail_count + 1;
			end

			//	Check: bus_address
			if ( captured_address === 16'h0034 ) begin
				$display( "[TEST %0d] PASS: bus_address = 0x%04X", test_no, captured_address );
				pass_count = pass_count + 1;
			end else begin
				$display( "[TEST %0d] FAIL: bus_address = 0x%04X (expected 0x0034)", test_no, captured_address );
				fail_count = fail_count + 1;
			end

			//	Check: bus_wdata
			if ( captured_wdata === 8'h56 ) begin
				$display( "[TEST %0d] PASS: bus_wdata = 0x%02X", test_no, captured_wdata );
				pass_count = pass_count + 1;
			end else begin
				$display( "[TEST %0d] FAIL: bus_wdata = 0x%02X (expected 0x56)", test_no, captured_wdata );
				fail_count = fail_count + 1;
			end
		end

		// ================================================================
		//	Summary
		// ================================================================
		$display( "============================================================" );
		$display( "Results: PASS = %0d, FAIL = %0d", pass_count, fail_count );
		if ( fail_count == 0 ) $display( "All tests PASSED." );
		else                   $display( "Some tests FAILED." );
		$finish;
	end
endmodule
