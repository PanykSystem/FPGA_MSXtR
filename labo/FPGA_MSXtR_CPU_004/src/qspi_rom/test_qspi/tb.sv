// ============================================================================
//	tb.sv - Testbench for qspi.v
//	Test Quad SPI Controller
// ============================================================================

`timescale 1ns/1ps

module tb();
	// Clock and reset signals
	reg				reset;
	reg				clk;
	reg				clk_serial;

	// Serial interface signals
	reg	[2:0]		serial_mode;
	reg	[7:0]		serial_wdata;
	reg				serial_write;
	reg				serial_valid;
	wire			serial_ready;
	wire	[7:0]	serial_rdata;
	wire			serial_rdata_en;

	// QSPI interface signals
	wire			qspi_clk;
	wire	[3:0]	qspi_sio;

	// Simulation signals
	reg	[3:0]	qspi_sio_slave;	// Slave device side
	reg			ff_write;		// Latched command direction (1: write, 0: read)
	reg	[7:0]	test_number;	// Current test number for waveform observation
	reg			std_read_drive_en;
	reg	[7:0]	std_read_expect_data;

	// =====================================================================
	//	Module instantiation
	// =====================================================================
	qspi u_qspi (
		.reset				( reset				),
		.clk				( clk				),
		.clk_serial			( clk_serial		),
		.serial_mode		( serial_mode		),
		.serial_wdata		( serial_wdata		),
		.serial_write		( serial_write		),
		.serial_valid		( serial_valid		),
		.serial_ready		( serial_ready		),
		.serial_rdata		( serial_rdata		),
		.serial_rdata_en	( serial_rdata_en	),
		.qspi_clk			( qspi_clk			),
		.qspi_sio			( qspi_sio			)
	);

	// Drive only during read. During write, slave side releases the bus.
	assign qspi_sio = ff_write ? 4'bzzzz : qspi_sio_slave;

	// =====================================================================
	//	Clock generation
	// =====================================================================
	localparam CLK_PERIOD = 100;			// 10 MHz system clock
	localparam CLK_SERIAL_PERIOD = 50;		// 20 MHz serial clock

	initial begin
		clk = 1'b0;
		forever #(CLK_PERIOD/2) clk = ~clk;
	end

	initial begin
		clk_serial = 1'b0;
		forever #(CLK_SERIAL_PERIOD/2) clk_serial = ~clk_serial;
	end

	// =====================================================================
	//	Task definitions
	// =====================================================================
	task initialize();
	begin
		reset = 1'b0;
		serial_mode = 3'd0;
		serial_wdata = 8'd0;
		serial_write = 1'b0;
		serial_valid = 1'b0;
		qspi_sio_slave = 4'd0;
		std_read_drive_en = 1'b0;
		std_read_expect_data = 8'd0;
		ff_write = 1'b0;
		test_number = 8'd0;
		#(CLK_PERIOD*10) reset = 1'b1;
		#(CLK_PERIOD*10) reset = 1'b0;
		$display( "[%0t] Initialize complete", $time );
	end
	endtask

	task wait_ready();
	begin
		while( !serial_ready ) begin
			@( posedge clk );
		end
	end
	endtask

	task wait_rdata_valid();
	begin
		while( !serial_rdata_en ) begin
			@( posedge clk );
		end
	end
	endtask

	task serial_write_byte(
		input [2:0] mode,
		input [7:0] wdata
	);
	begin
		wait_ready();
		@( posedge clk );
		serial_mode		<= mode;
		serial_wdata	<= wdata;
		serial_write	<= 1'b1;
		serial_valid	<= 1'b1;
		@( posedge clk );
		while( !serial_ready ) begin
			@( posedge clk );
		end
		serial_valid	<= 1'b0;
		@( posedge clk );
		$display( "[%0t] Write command: mode=%0d, data=0x%02x", $time, mode, wdata );
	end
	endtask

	task serial_read_byte(
		input [2:0] mode,
		input [7:0] expect_data,
		output [7:0] rdata
	);
	begin
		std_read_expect_data	<= expect_data;
		std_read_drive_en	<= 1'b1;
		wait_ready();
		@( posedge clk );
		serial_mode		<= 3'd1;
		serial_write	<= 1'b0;
		serial_valid	<= 1'b1;
		@( posedge clk );
		while( !serial_ready ) begin
			@( posedge clk );
		end
		serial_valid	<= 1'b0;
		@( posedge clk );
		wait_rdata_valid();
		rdata = serial_rdata;
		std_read_drive_en	<= 1'b0;
		$display( "[%0t] Read command(STD): req_mode=%0d, received data=0x%02x", $time, mode, rdata );
	end
	endtask

	task dummy_clock(
		input [2:0] mode
	);
	begin
		wait_ready();
		@( posedge clk );
		serial_mode		<= mode;
		serial_write	<= 1'b0;
		serial_valid	<= 1'b1;
		@( posedge clk );
		serial_valid	<= 1'b0;
		#(CLK_SERIAL_PERIOD*100);	// Wait for operation to complete
		$display( "[%0t] Dummy clock: mode=%0d", $time, mode );
	end
	endtask

	// =====================================================================
	//	Slave simulation: respond to read commands
	// =====================================================================
	reg	[7:0]	slave_tx_data;
	reg	[3:0]	slave_bit_count;
	reg	[3:0]	slave_quad_bit_count;
	reg	[7:0]	temp_rdata;	// Temporary storage for read data

	always @( posedge qspi_clk ) begin
		if( reset ) begin
			qspi_sio_slave <= 4'd0;
			slave_tx_data <= 8'd0;
			slave_bit_count <= 4'd0;
			slave_quad_bit_count <= 4'd0;
		end
		else begin
			// For standard SPI read (SIO[1] is MISO)
			if( std_read_drive_en ) begin
				if( slave_bit_count == 4'd0 ) begin
					qspi_sio_slave[1] <= std_read_expect_data[7];
					slave_tx_data <= {std_read_expect_data[6:0], 1'b0};
					slave_bit_count <= 4'd1;
				end
				else if( slave_bit_count == 4'd7 ) begin
					qspi_sio_slave[1] <= slave_tx_data[7];
					slave_tx_data <= {slave_tx_data[6:0], 1'b0};
					slave_bit_count <= 4'd0;
				end
				else begin
					qspi_sio_slave[1] <= slave_tx_data[7];
					slave_bit_count <= slave_bit_count + 4'd1;
					slave_tx_data <= {slave_tx_data[6:0], 1'b0};
				end
			end
			// For quad SPI read (SIO[3:0])
			else if( serial_mode == 3'd3 ) begin
				qspi_sio_slave[3:0] <= slave_tx_data[7:4];

				if( slave_quad_bit_count == 4'd0 ) begin
					slave_tx_data <= 8'h5A;	// Test pattern
				end
				else if( slave_quad_bit_count == 4'd1 ) begin
					slave_quad_bit_count <= 4'd0;
				end
				else begin
					slave_quad_bit_count <= slave_quad_bit_count + 4'd1;
					slave_tx_data <= {slave_tx_data[3:0], 4'b0000};
				end
			end
			else begin
				qspi_sio_slave <= 4'd0;
				slave_bit_count <= 4'd0;
				slave_quad_bit_count <= 4'd0;
			end
		end
	end

	// =====================================================================
	//	Test procedures
	// =====================================================================
	initial begin
		initialize();

		test_number = 8'd1;
		$display( "\n========== Test %0d: Standard SPI Write (0x42) ==========" , test_number );
		$display( "[%0t] Before write: serial_ready=%b, serial_valid=%b", $time, serial_ready, serial_valid );
		serial_write_byte( 3'd0, 8'h42 );	// Write 0x42
		$display( "[%0t] After write command issued: qspi_sio=%b, qspi_clk=%b", $time, qspi_sio, qspi_clk );
		$display( "[%0t] Waiting for data transmission...", $time );
		// Standard SPI: 8 bits, each takes 2 clk_serial cycles (up and down), so 16 cycles needed
		// Plus some margin for synchronization delays
		#(CLK_SERIAL_PERIOD*300);
		$display( "[%0t] After transmission wait: qspi_sio=%b, qspi_clk=%b", $time, qspi_sio, qspi_clk );

		test_number = 8'd2;
		$display( "\n========== Test %0d: Standard SPI Write 4-byte Sequence ==========" , test_number );
		serial_write_byte( 3'd0, 8'h12 );
		serial_write_byte( 3'd0, 8'h34 );
		serial_write_byte( 3'd0, 8'h56 );
		serial_write_byte( 3'd0, 8'h78 );
		#(CLK_SERIAL_PERIOD*200);

		test_number = 8'd3;
		$display( "\n========== Test %0d: Standard SPI Read ==========" , test_number );
		serial_read_byte( 3'd1, 8'hA3, temp_rdata );
		if( temp_rdata !== 8'hA3 ) begin
			$error( "[%0t] Test 3 FAILED: expected=0xA3 actual=0x%02x", $time, temp_rdata );
		end
		else begin
			$display( "[%0t] Test 3 PASSED: expected=0xA3 actual=0x%02x", $time, temp_rdata );
		end
		#(CLK_SERIAL_PERIOD*200);

		test_number = 8'd4;
		$display( "\n========== Test %0d: Quad SPI Write ==========" , test_number );
		serial_write_byte( 3'd2, 8'h5C );	// Write 0x5C via quad
		#(CLK_SERIAL_PERIOD*200);

		test_number = 8'd5;
		$display( "\n========== Test %0d: Quad SPI Read ==========" , test_number );
		serial_read_byte( 3'd3, 8'h3A, temp_rdata );
		#(CLK_SERIAL_PERIOD*200);

		test_number = 8'd6;
		$display( "\n========== Test %0d: Quad SPI Dummy Clock ==========" , test_number );
		dummy_clock( 3'd4 );
		#(CLK_SERIAL_PERIOD*200);

		test_number = 8'd7;
		$display( "\n========== Test %0d: Sequential operations ==========" , test_number );
		serial_write_byte( 3'd0, 8'h12 );	// Write command
		#(CLK_SERIAL_PERIOD*200);
		serial_write_byte( 3'd0, 8'h34 );	// Write data
		#(CLK_SERIAL_PERIOD*200);
		serial_read_byte( 3'd1, 8'hA5, temp_rdata );
		#(CLK_SERIAL_PERIOD*200);

		test_number = 8'd0;
		$display( "\n========== All tests completed ==========" );
		#(CLK_PERIOD*100) $finish;
	end

	// =====================================================================
	//	Monitoring
	// =====================================================================
	always @( posedge serial_rdata_en ) begin
		$display( "[%0t] Read data received: 0x%02x", $time, serial_rdata );
	end

	always @( serial_ready ) begin
		$display( "[%0t] serial_ready = %b", $time, serial_ready );
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_write <= 1'b0;
		end
		else if( serial_valid && serial_ready ) begin
			ff_write <= serial_write;
		end

		if( serial_valid && serial_ready ) begin
			$display( "[%0t] [CLK] Command accepted: mode=%0d, write=%b, wdata=0x%02x", 
				$time, serial_mode, serial_write, serial_wdata );
		end
	end



endmodule
