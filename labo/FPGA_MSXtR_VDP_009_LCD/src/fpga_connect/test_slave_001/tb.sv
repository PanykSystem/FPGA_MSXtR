`timescale 1ns/1ps

module tb;
	localparam real CLK_PERIOD_NS = 1000.0 / 85.90908;
	localparam real CLK_SERIAL_PERIOD_NS = 1000.0 / 214.7727;
	localparam real SI_CLK_PERIOD_NS = 1000.0 / 53.693175;

	integer			pass_count;
	integer			fail_count;
	integer			test_number;

	reg				reset_n;
	reg				clk;
	reg				clk_serial;
	reg				fpga_si_clk;

	wire	[7:0]	bus_address;
	wire			bus_write;
	wire	[7:0]	bus_wdata;
	wire			bus_valid;
	reg				bus_ready;
	reg		[7:0]	bus_rdata;
	reg				bus_rdata_en;

	wire	[31:0]	sound_l;
	wire	[31:0]	sound_r;
	wire			sound_valid;
	reg				sound_ready;

	tri		[1:0]	fpga_si;
	reg		[1:0]	master_si_drive;
	reg				master_si_oe;
	reg		[7:0]	read_data_capture;
	reg				seen_bus_write;
	reg				seen_sound_valid;
	reg		[7:0]	cap_bus_address;
	reg		[7:0]	cap_bus_wdata;
	reg		[31:0]	cap_sound_l;
	reg		[31:0]	cap_sound_r;

	assign fpga_si = master_si_oe ? master_si_drive : 2'bzz;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			seen_bus_write	<= 1'b0;
			seen_sound_valid	<= 1'b0;
			cap_bus_address	<= 8'd0;
			cap_bus_wdata	<= 8'd0;
			cap_sound_l		<= 32'd0;
			cap_sound_r		<= 32'd0;
		end
		else begin
			if( bus_valid && bus_write ) begin
				seen_bus_write	<= 1'b1;
				cap_bus_address	<= bus_address;
				cap_bus_wdata	<= bus_wdata;
			end
			if( sound_valid ) begin
				seen_sound_valid	<= 1'b1;
				cap_sound_l		<= sound_l;
				cap_sound_r		<= sound_r;
			end
		end
	end

	always #(CLK_PERIOD_NS / 2.0) begin
		clk <= ~clk;
	end

	always #(CLK_SERIAL_PERIOD_NS / 2.0) begin
		clk_serial <= ~clk_serial;
	end

	fpga_connect_slave u_dut (
		.reset_n		( reset_n		),
		.clk			( clk			),
		.clk_serial		( clk_serial	),
		.bus_address	( bus_address	),
		.bus_write		( bus_write		),
		.bus_wdata		( bus_wdata		),
		.bus_valid		( bus_valid		),
		.bus_ready		( bus_ready		),
		.bus_rdata		( bus_rdata		),
		.bus_rdata_en	( bus_rdata_en	),
		.sound_l		( sound_l		),
		.sound_r		( sound_r		),
		.sound_valid	( sound_valid	),
		.sound_ready	( sound_ready	),
		.fpga_si_clk	( fpga_si_clk	),
		.fpga_si		( fpga_si		)
	);

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

	task automatic check_equal32;
		input [31:0] actual;
		input [31:0] expected;
		input [255:0] msg;
		begin
			if( actual === expected ) begin
				pass_count = pass_count + 1;
			end
			else begin
				$display( "FAIL: %0s actual=%08h expected=%08h", msg, actual, expected );
				fail_count = fail_count + 1;
			end
		end
	endtask

	task automatic send_pair;
		input [1:0] pair;
		begin
			master_si_oe	= 1'b1;
			master_si_drive	= pair;
			#(SI_CLK_PERIOD_NS / 2.0);
			fpga_si_clk		= 1'b1;
			#(SI_CLK_PERIOD_NS / 2.0);
			fpga_si_clk		= 1'b0;
		end
	endtask

	task automatic receive_pair;
		output [1:0] pair;
		begin
			#(SI_CLK_PERIOD_NS / 2.0);
			fpga_si_clk	= 1'b1;
			pair			= fpga_si;
			#(SI_CLK_PERIOD_NS / 2.0);
			fpga_si_clk	= 1'b0;
		end
	endtask

	task automatic reset_dut;
		begin
			reset_n = 1'b0;
			master_si_oe = 1'b0;
			master_si_drive = 2'b00;
			bus_rdata_en = 1'b0;
			fpga_si_clk = 1'b0;
			repeat( 6 ) @( posedge clk );
			reset_n = 1'b1;
			repeat( 10 ) @( posedge clk );
		end
	endtask

	task automatic send_io_write_frame;
		input [7:0] addr;
		input [7:0] data;
		begin
			send_pair( 2'b00 );
			send_pair( addr[7:6] );
			send_pair( addr[5:4] );
			send_pair( addr[3:2] );
			send_pair( addr[1:0] );
			send_pair( data[7:6] );
			send_pair( data[5:4] );
			send_pair( data[3:2] );
			send_pair( data[1:0] );
			master_si_oe <= 1'b0;
		end
	endtask

	task automatic send_sound_frame;
		input [31:0] lch;
		input [31:0] rch;
		integer i;
		begin
			send_pair( 2'b10 );
			for( i = 0; i < 16; i = i + 1 ) begin
				send_pair( lch[31 - (i*2) -: 2] );
			end
			for( i = 0; i < 16; i = i + 1 ) begin
				send_pair( rch[31 - (i*2) -: 2] );
			end
			master_si_oe <= 1'b0;
		end
	endtask

	task automatic send_io_read_and_capture;
		input [7:0] addr;
		output [7:0] captured;
		integer i;
		reg [1:0] pair;
		begin
			send_pair( 2'b01 );
			send_pair( addr[7:6] );
			send_pair( addr[5:4] );
			send_pair( addr[3:2] );
			send_pair( addr[1:0] );
			master_si_oe <= 1'b0;
			pair = 2'b00;
			for( i = 0; i < 256; i = i + 1 ) begin
				receive_pair( pair );
				if( pair === 2'b11 ) begin
					i = 256;
				end
			end
			for( i = 0; i < 256; i = i + 1 ) begin
				receive_pair( pair );
				if( pair !== 2'b11 ) begin
					captured[7:6] = pair;
					i = 256;
				end
			end
			for( i = 1; i < 4; i = i + 1 ) begin
				receive_pair( pair );
				captured[7 - (i*2) -: 2] = pair;
			end
			fpga_si_clk = 1'b0;
		end
	endtask

	task automatic respond_read_request;
		input [7:0] exp_addr;
		input [7:0] ret_data;
		integer t;
		reg found;
		begin
			found = 1'b0;
			for( t = 0; t < 256; t = t + 1 ) begin
				@( posedge clk );
				if( bus_valid && !bus_write ) begin
					found = 1'b1;
					t = 256;
				end
			end
			if( !found ) begin
				$display( "FAIL: read request timeout" );
				fail_count = fail_count + 1;
				disable respond_read_request;
			end
			if( bus_address !== exp_addr ) begin
				$display( "FAIL: read addr mismatch actual=%02h expected=%02h", bus_address, exp_addr );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
			end
			repeat( 2 ) @( posedge clk );
			bus_rdata		<= ret_data;
			bus_rdata_en	<= 1'b1;
			@( posedge clk );
			bus_rdata_en	<= 1'b0;
		end
	endtask

	initial begin
		reset_n				= 1'b0;
		clk					= 1'b0;
		clk_serial			= 1'b0;
		fpga_si_clk			= 1'b0;
		bus_ready			= 1'b1;
		bus_rdata			= 8'h00;
		bus_rdata_en		= 1'b0;
		sound_ready			= 1'b1;
		master_si_drive		= 2'b00;
		master_si_oe		= 1'b0;
		read_data_capture	= 8'h00;
		seen_bus_write		= 1'b0;
		seen_sound_valid	= 1'b0;
		cap_bus_address		= 8'd0;
		cap_bus_wdata		= 8'd0;
		cap_sound_l			= 32'd0;
		cap_sound_r			= 32'd0;
		pass_count			= 0;
		fail_count			= 0;
		test_number			= 0;

		reset_dut();

		test_number = test_number + 1;
		$display( "[TEST%0d] io_write decode", test_number );
		reset_dut();
		seen_bus_write = 1'b0;
		send_io_write_frame( 8'h98, 8'hA5 );
		begin : u_wait_write
			integer w;
			reg got;
			got = 1'b0;
			for( w = 0; w < 256; w = w + 1 ) begin
				@( posedge clk );
				if( seen_bus_write ) begin
					got = 1'b1;
					disable u_wait_write;
				end
			end
			if( !got ) begin
				$display( "FAIL: io_write request timeout" );
				fail_count = fail_count + 1;
			end
		end
		check_equal8( cap_bus_address, 8'h98, "io_write bus_address" );
		check_equal8( cap_bus_wdata, 8'hA5, "io_write bus_wdata" );
		@( posedge clk );
		if( bus_valid ) begin
			$display( "FAIL: bus_valid should clear after write ack" );
			fail_count = fail_count + 1;
		end
		else begin
			pass_count = pass_count + 1;
		end

		test_number = test_number + 1;
		$display( "[TEST%0d] sound_send decode", test_number );
		reset_dut();
		seen_sound_valid = 1'b0;
		send_sound_frame( 32'h1122_3344, 32'hA5A5_5A5A );
		begin : u_wait_sound
			integer s;
			reg got_s;
			got_s = 1'b0;
			for( s = 0; s < 256; s = s + 1 ) begin
				@( posedge clk );
				if( seen_sound_valid ) begin
					got_s = 1'b1;
					disable u_wait_sound;
				end
			end
			if( !got_s ) begin
				$display( "FAIL: sound_valid timeout" );
				fail_count = fail_count + 1;
			end
		end
		check_equal32( cap_sound_l, 32'h1122_3344, "sound_l" );
		check_equal32( cap_sound_r, 32'hA5A5_5A5A, "sound_r" );
		@( posedge clk );
		if( sound_valid ) begin
			$display( "FAIL: sound_valid should be 1clk pulse" );
			fail_count = fail_count + 1;
		end
		else begin
			pass_count = pass_count + 1;
		end

		test_number = test_number + 1;
		$display( "[TEST%0d] io_read response path", test_number );
		reset_dut();
		fork
			send_io_read_and_capture( 8'h20, read_data_capture );
			respond_read_request( 8'h20, 8'h3C );
		join
		check_equal8( read_data_capture, 8'h3C, "first read captured reply" );

		fork
			send_io_read_and_capture( 8'h21, read_data_capture );
			respond_read_request( 8'h21, 8'hA5 );
		join
		check_equal8( read_data_capture, 8'hA5, "second read captured reply" );

		fork
			send_io_read_and_capture( 8'h22, read_data_capture );
			respond_read_request( 8'h22, 8'h5A );
		join
		check_equal8( read_data_capture, 8'h5A, "third read captured reply" );

		$display( "----------------------------------------" );
		$display( "RESULT: PASS=%0d FAIL=%0d", pass_count, fail_count );
		if( fail_count != 0 ) begin
			$fatal( 1, "test_slave_001 failed" );
		end
		$finish;
	end
endmodule
