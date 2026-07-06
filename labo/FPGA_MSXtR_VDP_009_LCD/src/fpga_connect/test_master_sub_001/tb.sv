`timescale 1ns/1ps

module tb;
	localparam real CLK_PERIOD_NS = 1000.0 / 85.90908;
	localparam real CLK_SERIAL_PERIOD_NS = 1000.0 / 214.7727;

	localparam [1:0] C_MODE_TX_MODEBIT = 2'b00;
	localparam [1:0] C_MODE_TX_BYTE = 2'b01;
	localparam [1:0] C_MODE_RX_BYTE = 2'b10;
	localparam [1:0] C_MODE_RX_STATUS = 2'b11;

	integer pass_count;
	integer fail_count;
	integer test_number;

	reg				reset_n;
	reg				clk;
	reg				clk_serial;
	reg				tx_cs;
	reg				start;
	reg		[1:0]	mode;
	reg		[7:0]	tx_data;
	tri		[1:0]	so;
	reg		[1:0]	tb_so_drive;
	reg				tb_so_oe;

	wire			so_clk;
	wire			busy;
	wire			done;
	wire			wait_read;
	wire	[7:0]	rx_data;
	wire			rx_data_en;
	wire			so_oe;

	assign so = tb_so_oe ? tb_so_drive : 2'bzz;

	always #(CLK_PERIOD_NS / 2.0) begin
		clk <= ~clk;
	end

	always #(CLK_SERIAL_PERIOD_NS / 2.0) begin
		clk_serial <= ~clk_serial;
	end

	fpga_connect_master_sub u_dut (
		.reset_n	( reset_n		),
		.clk_serial	( clk_serial	),
		.tx_cs		( tx_cs			),
		.start		( start			),
		.mode		( mode			),
		.tx_data	( tx_data		),
		.so			( so			),
		.so_clk		( so_clk		),
		.busy		( busy			),
		.done		( done			),
		.wait_read	( wait_read		),
		.rx_data	( rx_data		),
		.rx_data_en	( rx_data_en	),
		.so_oe		( so_oe			)
	);

	task automatic check_equal1;
		input actual;
		input expected;
		input [255:0] msg;
		begin
			if( actual === expected ) begin
				pass_count = pass_count + 1;
			end
			else begin
				$display( "FAIL: %0s actual=%b expected=%b", msg, actual, expected );
				fail_count = fail_count + 1;
			end
		end
	endtask

	task automatic check_equal2;
		input [1:0] actual;
		input [1:0] expected;
		input [255:0] msg;
		begin
			if( actual === expected ) begin
				pass_count = pass_count + 1;
			end
			else begin
				$display( "FAIL: %0s actual=%b expected=%b", msg, actual, expected );
				fail_count = fail_count + 1;
			end
		end
	endtask

	task automatic check_equal8;
		input [7:0] actual;
		input [7:0] expected;
		input [255:0] msg;
		begin
			if( actual === expected ) begin
				pass_count = pass_count + 1;
			end
			else begin
				$display( "FAIL: %0s actual=%02h expected=%02h", msg, actual, expected );
				fail_count = fail_count + 1;
			end
		end
	endtask

	task automatic wait_clk_rise;
		input [255:0] msg;
		output found;
		integer i;
		reg prev_clk;
		begin
			found = 1'b0;
			prev_clk = so_clk;
			for( i = 0; i < 128; i = i + 1 ) begin
				@( posedge clk_serial );
				#1ps;
				if( prev_clk === 1'b0 && so_clk === 1'b1 ) begin
					found = 1'b1;
					i = 128;
				end
				prev_clk = so_clk;
			end
			if( !found ) begin
				$display( "FAIL: %0s timeout", msg );
				fail_count = fail_count + 1;
			end
		end
	endtask

	task automatic wait_done_pulse;
		input [255:0] msg;
		output found;
		integer i;
		begin
			found = 1'b0;
			for( i = 0; i < 128; i = i + 1 ) begin
				@( posedge clk_serial );
				#1ps;
				if( done ) begin
					found = 1'b1;
					i = 128;
				end
			end
			if( !found ) begin
				$display( "FAIL: %0s timeout", msg );
				fail_count = fail_count + 1;
			end
		end
	endtask

	task automatic wait_rx_data_en_pulse;
		input [255:0] msg;
		output found;
		integer i;
		begin
			found = 1'b0;
			for( i = 0; i < 16; i = i + 1 ) begin
				@( posedge clk_serial );
				if( rx_data_en ) begin
					found = 1'b1;
					i = 16;
				end
			end
			if( !found ) begin
				$display( "FAIL: %0s timeout", msg );
				fail_count = fail_count + 1;
			end
		end
	endtask

	task automatic pulse_start;
		input [1:0] i_mode;
		input [7:0] i_tx_data;
		begin
			mode	<= i_mode;
			tx_data	<= i_tx_data;
			start	<= 1'b1;
			@( posedge clk_serial );
			start	<= 1'b0;
		end
	endtask

	task automatic reset_dut;
		begin
			reset_n		= 1'b0;
			tx_cs		= 1'b0;
			start		= 1'b0;
			mode		= C_MODE_TX_MODEBIT;
			tx_data		= 8'd0;
			tb_so_drive	= 2'b00;
			tb_so_oe	= 1'b0;
			repeat( 6 ) @( posedge clk_serial );
			reset_n		= 1'b1;
			repeat( 3 ) @( posedge clk_serial );
		end
	endtask

	task automatic test_clock_generator;
		integer i;
		reg prev_so_clk;
		reg toggled;
		reg found;
		begin
			reset_dut();
			tx_cs = 1'b1;
			pulse_start( C_MODE_TX_MODEBIT, 8'h00 );
			toggled = 1'b0;
			prev_so_clk = so_clk;
			for( i = 0; i < 24; i = i + 1 ) begin
				@( posedge clk_serial );
				if( so_clk !== prev_so_clk ) begin
					toggled = 1'b1;
				end
				prev_so_clk = so_clk;
			end
			check_equal1( toggled, 1'b1, "so_clk toggles while tx_cs" );

			tx_cs = 1'b0;
			repeat( 4 ) @( posedge clk_serial );
			check_equal1( so_clk, 1'b0, "so_clk idles low" );
		end
	endtask

	task automatic test_tx_modebit;
		reg found;
		begin
			reset_dut();
			tx_cs = 1'b1;
			pulse_start( C_MODE_TX_MODEBIT, 8'h02 );
			@( posedge clk_serial );
			check_equal1( so_oe, 1'b1, "modebit: so_oe asserted" );
			check_equal2( so, 2'b10, "modebit: tx_data[1:0] output" );
			wait_done_pulse( "modebit done", found );
			check_equal1( done, 1'b1, "modebit done asserted" );
			@( posedge clk_serial );
			#1ps;
			check_equal1( busy, 1'b0, "modebit busy deasserted" );
			check_equal1( so_oe, 1'b0, "modebit: so_oe released after done" );
			check_equal2( so, 2'bzz, "modebit: so released after done" );
			repeat( 4 ) begin
				@( posedge clk_serial );
				check_equal1( so_oe, 1'b0, "modebit: so_oe remains released" );
				check_equal2( so, 2'bzz, "modebit: so remains released" );
			end
			tx_cs = 1'b0;
		end
	endtask

	task automatic test_tx_byte;
		reg found;
		begin
			reset_dut();
			tx_cs = 1'b1;
			pulse_start( C_MODE_TX_BYTE, 8'h36 );
			@( posedge clk_serial );
			check_equal1( so_oe, 1'b1, "tx_byte: so_oe asserted at start" );

			check_equal2( so, 2'b00, "tx_byte first pair" );
			wait_clk_rise( "tx_byte step0", found );
			check_equal2( so, 2'b00, "tx_byte second pair" );
			wait_clk_rise( "tx_byte step1", found );
			check_equal2( so, 2'b00, "tx_byte third pair" );
			wait_clk_rise( "tx_byte step2", found );
			check_equal2( so, 2'b00, "tx_byte fourth pair" );

			wait_done_pulse( "tx_byte done", found );
			check_equal1( done, 1'b1, "tx_byte done asserted" );
			@( posedge clk_serial );
			#1ps;
			check_equal1( busy, 1'b0, "tx_byte busy deasserted" );
			tx_cs = 1'b0;
		end
	endtask

	task automatic test_rx_byte;
		reg found;
		begin
			reset_dut();
			tx_cs = 1'b1;
			tb_so_oe = 1'b1;
			tb_so_drive = 2'b11;
			pulse_start( C_MODE_RX_BYTE, 8'h00 );
			@( posedge clk_serial );
			check_equal1( so_oe, 1'b0, "rx_byte: so_oe low" );

			tb_so_drive = 2'b11;
			wait_clk_rise( "rx_byte pair0", found );
			tb_so_drive = 2'b00;
			wait_clk_rise( "rx_byte pair1", found );
			tb_so_drive = 2'b10;
			wait_clk_rise( "rx_byte pair2", found );
			tb_so_drive = 2'b01;

			wait_done_pulse( "rx_byte done", found );
			check_equal1( done, 1'b1, "rx_byte done asserted" );
			check_equal1( rx_data_en, 1'b1, "rx_byte rx_data_en asserted" );
			check_equal8( rx_data, 8'hC9, "rx_byte data" );
			@( posedge clk_serial );
			#1ps;
			check_equal1( busy, 1'b0, "rx_byte busy deasserted" );
			tb_so_oe = 1'b0;
			tx_cs = 1'b0;
		end
	endtask

	task automatic test_rx_status;
		reg found;
		reg found_en;
		begin
			reset_dut();
			tx_cs = 1'b1;
			tb_so_oe = 1'b1;
			tb_so_drive = 2'b00;
			pulse_start( C_MODE_RX_STATUS, 8'h00 );
			wait_done_pulse( "rx_status done", found );
			check_equal1( done, 1'b1, "rx_status done asserted" );
			@( posedge clk_serial );
			#1ps;
			check_equal1( busy, 1'b0, "rx_status busy deasserted" );
			wait_rx_data_en_pulse( "rx_status rx_data_en pulse", found_en );
			if( found_en ) begin
				pass_count = pass_count + 1;
			end
			check_equal2( rx_data[1:0], 2'b00, "rx_status reads 00" );

			reset_dut();
			tx_cs = 1'b1;
			tb_so_oe = 1'b1;
			tb_so_drive = 2'b11;
			pulse_start( C_MODE_RX_STATUS, 8'h00 );
			wait_done_pulse( "rx_status done (11)", found );
			check_equal1( done, 1'b1, "rx_status done asserted (11)" );
			wait_rx_data_en_pulse( "rx_status rx_data_en pulse (11)", found_en );
			if( found_en ) begin
				pass_count = pass_count + 1;
			end
			check_equal2( rx_data[1:0], 2'b11, "rx_status reads 11" );
			tb_so_oe = 1'b0;
			tx_cs = 1'b0;
		end
	endtask

	initial begin
		reset_n		= 1'b0;
		clk			= 1'b0;
		clk_serial	= 1'b0;
		tx_cs		= 1'b0;
		start		= 1'b0;
		mode		= C_MODE_TX_BYTE;
		tx_data		= 8'd0;
		tb_so_drive	= 2'b00;
		tb_so_oe	= 1'b0;
		pass_count	= 0;
		fail_count	= 0;
		test_number	= 0;

		reset_dut();

		test_number = test_number + 1;
		$display( "[TEST%0d] clock generator", test_number );
		test_clock_generator();

		test_number = test_number + 1;
		$display( "[TEST%0d] modebit tx", test_number );
		test_tx_modebit();

		test_number = test_number + 1;
		$display( "[TEST%0d] 1byte tx", test_number );
		test_tx_byte();

		test_number = test_number + 1;
		$display( "[TEST%0d] 1byte rx", test_number );
		test_rx_byte();

		test_number = test_number + 1;
		$display( "[TEST%0d] status rx(2bit)", test_number );
		test_rx_status();

		$display( "----------------------------------------" );
		$display( "RESULT: PASS=%0d FAIL=%0d", pass_count, fail_count );
		if( fail_count != 0 ) begin
			$fatal( 1, "test_master_sub_001 failed" );
		end
		$finish;
	end
endmodule
