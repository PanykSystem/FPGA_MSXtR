`timescale 1ns/1ps

module tb;
	localparam real CLK_PERIOD_NS = 1000.0 / 85.90908;
	localparam real CLK_SERIAL_PERIOD_NS = 1000.0 / 214.7727;

	integer			pass_count;
	integer			fail_count;
	integer			test_number;

	reg				reset_n;
	reg				clk;
	reg				clk_serial;

	// ------------------------------------------------------------
	// master side bus/sound stimulus
	// ------------------------------------------------------------
	reg		[7:0]	m_bus_address;
	reg				m_bus_write;
	reg		[7:0]	m_bus_wdata;
	reg				m_bus_valid;
	wire			m_bus_ready;
	wire	[7:0]	m_bus_rdata;
	wire			m_bus_rdata_en;

	reg		[31:0]	m_sound_l;
	reg		[31:0]	m_sound_r;
	reg				m_sound_valid;
	wire			m_sound_ready;

	// ------------------------------------------------------------
	// interconnect between master and slave
	// ------------------------------------------------------------
	wire			link_clk;
	wire			link_clk_slave;
	tri		[1:0]	link_data;

	assign link_clk_slave = link_clk;

	// ------------------------------------------------------------
	// slave side bus/sound observation/response
	// ------------------------------------------------------------
	wire	[7:0]	s_bus_address;
	wire			s_bus_write;
	wire	[7:0]	s_bus_wdata;
	wire			s_bus_valid;
	reg				s_bus_ready;
	reg		[7:0]	s_bus_rdata;
	reg				s_bus_rdata_en;

	wire	[31:0]	s_sound_l;
	wire	[31:0]	s_sound_r;
	wire			s_sound_valid;
	reg				s_sound_ready;

	reg				seen_slave_write;
	reg		[7:0]	cap_slave_write_addr;
	reg		[7:0]	cap_slave_write_data;
	reg				seen_slave_sound;
	reg		[31:0]	cap_slave_sound_l;
	reg		[31:0]	cap_slave_sound_r;

	always #(CLK_PERIOD_NS / 2.0) begin
		clk <= ~clk;
	end

	always #(CLK_SERIAL_PERIOD_NS / 2.0) begin
		clk_serial <= ~clk_serial;
	end

	fpga_connect_master u_master (
		.reset_n		( reset_n		),
		.clk			( clk			),
		.clk_serial		( clk_serial	),
		.bus_address	( m_bus_address	),
		.bus_write		( m_bus_write	),
		.bus_wdata		( m_bus_wdata	),
		.bus_valid		( m_bus_valid	),
		.bus_ready		( m_bus_ready	),
		.bus_rdata		( m_bus_rdata	),
		.bus_rdata_en	( m_bus_rdata_en),
		.sound_l		( m_sound_l		),
		.sound_r		( m_sound_r		),
		.sound_valid	( m_sound_valid	),
		.sound_ready	( m_sound_ready	),
		.fpga_so_clk	( link_clk		),
		.fpga_so		( link_data		)
	);

	fpga_connect_slave u_slave (
		.reset_n		( reset_n		),
		.clk			( clk			),
		.clk_serial		( clk_serial	),
		.bus_address	( s_bus_address	),
		.bus_write		( s_bus_write	),
		.bus_wdata		( s_bus_wdata	),
		.bus_valid		( s_bus_valid	),
		.bus_ready		( s_bus_ready	),
		.bus_rdata		( s_bus_rdata	),
		.bus_rdata_en	( s_bus_rdata_en),
		.sound_l		( s_sound_l		),
		.sound_r		( s_sound_r		),
		.sound_valid	( s_sound_valid	),
		.sound_ready	( s_sound_ready	),
		.fpga_si_clk	( link_clk_slave	),
		.fpga_si		( link_data		)
	);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			seen_slave_write	<= 1'b0;
			cap_slave_write_addr	<= 8'd0;
			cap_slave_write_data	<= 8'd0;
			seen_slave_sound	<= 1'b0;
			cap_slave_sound_l	<= 32'd0;
			cap_slave_sound_r	<= 32'd0;
		end
		else begin
			if( s_bus_valid && s_bus_write ) begin
				seen_slave_write	<= 1'b1;
				cap_slave_write_addr	<= s_bus_address;
				cap_slave_write_data	<= s_bus_wdata;
			end
			if( s_sound_valid ) begin
				seen_slave_sound	<= 1'b1;
				cap_slave_sound_l	<= s_sound_l;
				cap_slave_sound_r	<= s_sound_r;
			end
		end
	end

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

	task automatic wait_master_bus_ready;
		output reg ok;
		integer i;
		begin
			ok = 1'b0;
			for( i = 0; i < 512; i = i + 1 ) begin
				@( posedge clk );
				if( m_bus_ready ) begin
					ok = 1'b1;
					i = 512;
				end
			end
		end
	endtask

	task automatic wait_master_sound_ready;
		output reg ok;
		integer i;
		begin
			ok = 1'b0;
			for( i = 0; i < 512; i = i + 1 ) begin
				@( posedge clk );
				if( m_sound_ready ) begin
					ok = 1'b1;
					i = 512;
				end
			end
		end
	endtask

	task automatic master_io_write;
		input [7:0] addr;
		input [7:0] data;
		reg ok;
		begin
			wait_master_bus_ready( ok );
			if( !ok ) begin
				$display( "FAIL: master bus_ready timeout before write" );
				fail_count = fail_count + 1;
				disable master_io_write;
			end
			m_bus_address	= addr;
			m_bus_wdata	= data;
			m_bus_write	= 1'b1;
			m_bus_valid	= 1'b1;
			@( posedge clk );
			m_bus_valid	= 1'b0;
			m_bus_write	= 1'b0;
		end
	endtask

	task automatic master_io_read;
		input [7:0] addr;
		reg ok;
		begin
			wait_master_bus_ready( ok );
			if( !ok ) begin
				$display( "FAIL: master bus_ready timeout before read" );
				fail_count = fail_count + 1;
				disable master_io_read;
			end
			m_bus_address	= addr;
			m_bus_write	= 1'b0;
			m_bus_valid	= 1'b1;
			@( posedge clk );
			m_bus_valid	= 1'b0;
		end
	endtask

	task automatic master_sound_send;
		input [31:0] lch;
		input [31:0] rch;
		reg ok;
		begin
			wait_master_sound_ready( ok );
			if( !ok ) begin
				$display( "FAIL: master sound_ready timeout before send" );
				fail_count = fail_count + 1;
				disable master_sound_send;
			end
			m_sound_l		= lch;
			m_sound_r		= rch;
			m_sound_valid	= 1'b1;
			@( posedge clk );
			m_sound_valid	= 1'b0;
		end
	endtask

	task automatic slave_respond_read_once;
		input [7:0] exp_addr;
		input [7:0] ret_data;
		reg found;
		integer i;
		begin
			found = 1'b0;
			for( i = 0; i < 512; i = i + 1 ) begin
				@( posedge clk );
				if( s_bus_valid && !s_bus_write ) begin
					found = 1'b1;
					i = 512;
				end
			end
			if( !found ) begin
				$display( "FAIL: slave read request timeout" );
				fail_count = fail_count + 1;
				disable slave_respond_read_once;
			end
			check_equal8( s_bus_address, exp_addr, "slave read address" );
			repeat( 2 ) @( posedge clk );
			s_bus_rdata		= ret_data;
			s_bus_rdata_en	= 1'b1;
			@( posedge clk );
			s_bus_rdata_en	= 1'b0;
		end
	endtask

	task automatic wait_master_rdata;
		output reg ok;
		integer i;
		begin
			ok = 1'b0;
			for( i = 0; i < 512; i = i + 1 ) begin
				@( posedge clk );
				if( m_bus_rdata_en ) begin
					ok = 1'b1;
					i = 512;
				end
			end
		end
	endtask

	task automatic wait_slave_write_exact;
		input [7:0] exp_addr;
		input [7:0] exp_data;
		output reg ok;
		integer i;
		begin
			ok = 1'b0;
			for( i = 0; i < 1024; i = i + 1 ) begin
				@( posedge clk );
				if( s_bus_valid && s_bus_write && s_bus_address == exp_addr && s_bus_wdata == exp_data ) begin
					ok = 1'b1;
					i = 1024;
				end
			end
		end
	endtask

	task automatic wait_slave_sound_exact;
		input [31:0] exp_l;
		input [31:0] exp_r;
		output reg ok;
		integer i;
		begin
			ok = 1'b0;
			for( i = 0; i < 2048; i = i + 1 ) begin
				@( posedge clk );
				if( s_sound_valid && s_sound_l == exp_l && s_sound_r == exp_r ) begin
					ok = 1'b1;
					i = 2048;
				end
			end
		end
	endtask

	task automatic reset_dut;
		begin
			reset_n = 1'b0;
			m_bus_valid = 1'b0;
			m_bus_write = 1'b0;
			m_sound_valid = 1'b0;
			s_bus_rdata_en = 1'b0;
			seen_slave_write = 1'b0;
			seen_slave_sound = 1'b0;
			repeat( 8 ) @( posedge clk );
			reset_n = 1'b1;
			repeat( 8 ) @( posedge clk );
		end
	endtask

	initial begin
		reset_n				= 1'b0;
		clk					= 1'b0;
		clk_serial			= 1'b0;
		m_bus_address		= 8'd0;
		m_bus_write			= 1'b0;
		m_bus_wdata			= 8'd0;
		m_bus_valid			= 1'b0;
		m_sound_l			= 32'd0;
		m_sound_r			= 32'd0;
		m_sound_valid		= 1'b0;
		s_bus_ready			= 1'b1;
		s_bus_rdata			= 8'h00;
		s_bus_rdata_en		= 1'b0;
		s_sound_ready		= 1'b1;
		seen_slave_write	= 1'b0;
		cap_slave_write_addr	= 8'd0;
		cap_slave_write_data	= 8'd0;
		seen_slave_sound	= 1'b0;
		cap_slave_sound_l	= 32'd0;
		cap_slave_sound_r	= 32'd0;
		pass_count			= 0;
		fail_count			= 0;
		test_number			= 0;

		reset_dut();

		test_number = test_number + 1;
		$display( "[TEST%0d] master->slave io_write", test_number );
		reset_dut();
		seen_slave_write = 1'b0;
		master_io_write( 8'h98, 8'hA5 );
		begin
			reg got;
			wait_slave_write_exact( 8'h98, 8'hA5, got );
			if( !got ) begin
				$display( "FAIL: expected slave write not observed" );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
			end
		end

		test_number = test_number + 1;
		$display( "[TEST%0d] master->slave sound_send", test_number );
		reset_dut();
		seen_slave_sound = 1'b0;
		master_sound_send( 32'h1122_3344, 32'hA5A5_5A5A );
		begin
			reg got;
			wait_slave_sound_exact( 32'h1122_3344, 32'hA5A5_5A5A, got );
			if( !got ) begin
				$display( "FAIL: expected slave sound frame not observed" );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
			end
		end

		test_number = test_number + 1;
		$display( "[TEST%0d] master<-slave io_read (current impl delay)", test_number );
		reset_dut();
		// Integration test here checks end-to-end read completion.
		// Exact returned value timing/bit-alignment is covered in unit tests.
		fork
			master_io_read( 8'h20 );
			slave_respond_read_once( 8'h20, 8'h3C );
		join
		begin
			reg ok;
			wait_master_rdata( ok );
			if( !ok ) begin
				$display( "FAIL: master read1 timeout" );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
			end
		end

		fork
			master_io_read( 8'h21 );
			slave_respond_read_once( 8'h21, 8'hA5 );
		join
		begin
			reg ok;
			wait_master_rdata( ok );
			if( !ok ) begin
				$display( "FAIL: master read2 timeout" );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
			end
		end

		fork
			master_io_read( 8'h22 );
			slave_respond_read_once( 8'h22, 8'h5A );
		join
		begin
			reg ok;
			wait_master_rdata( ok );
			if( !ok ) begin
				$display( "FAIL: master read3 timeout" );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
			end
		end

		$display( "----------------------------------------" );
		$display( "RESULT: PASS=%0d FAIL=%0d", pass_count, fail_count );
		if( fail_count != 0 ) begin
			$fatal( 1, "fpga_connect integration test_001 failed" );
		end
		$finish;
	end
endmodule
