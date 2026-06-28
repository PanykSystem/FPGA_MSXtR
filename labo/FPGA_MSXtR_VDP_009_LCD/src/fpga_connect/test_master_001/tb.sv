`timescale 1ns/1ps

module tb;
	localparam real CLK_PERIOD_NS = 1000.0 / 85.90908;
	localparam real CLK_SERIAL_PERIOD_NS = 1000.0 / 214.7727;

	integer pass_count;
	integer fail_count;

	reg				reset_n;
	reg				clk;
	reg				clk_serial;

	reg		[7:0]	bus_address;
	reg				bus_write;
	reg		[7:0]	bus_wdata;
	reg				bus_valid;
	wire			bus_ready;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;

	reg		[31:0]	sound_l;
	reg		[31:0]	sound_r;
	reg				sound_valid;
	wire			sound_ready;

	wire			fpga_so_clk;
	tri		[1:0]	fpga_so;
	reg		[1:0]	tb_so_drive;
	reg				tb_so_oe;
	integer			test_number;

	assign fpga_so = tb_so_oe ? tb_so_drive : 2'bzz;

	always #(CLK_PERIOD_NS / 2.0) begin
		clk <= ~clk;
	end

	always #(CLK_SERIAL_PERIOD_NS / 2.0) begin
		clk_serial <= ~clk_serial;
	end

	fpga_connect_master u_dut (
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
		.fpga_so_clk	( fpga_so_clk	),
		.fpga_so		( fpga_so		)
	);

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

	task automatic wait_so_clk_posedge;
		output found;
		integer i;
		reg prev_clk;
		begin
			found = 1'b0;
			prev_clk = fpga_so_clk;
			for( i = 0; i < 512; i = i + 1 ) begin
				@( posedge clk_serial );
				if( prev_clk === 1'b0 && fpga_so_clk === 1'b1 ) begin
					found = 1'b1;
					i = 512;
				end
				prev_clk = fpga_so_clk;
			end
		end
	endtask

	task automatic wait_so_clk_negedge;
		output found;
		integer i;
		reg prev_clk;
		begin
			found = 1'b0;
			prev_clk = fpga_so_clk;
			for( i = 0; i < 512; i = i + 1 ) begin
				@( posedge clk_serial );
				if( prev_clk === 1'b1 && fpga_so_clk === 1'b0 ) begin
					found = 1'b1;
					i = 512;
				end
				prev_clk = fpga_so_clk;
			end
		end
	endtask

	task automatic check_so_pair;
		input [1:0] expected;
		input [255:0] msg;
		reg found;
		reg [1:0] actual;
		begin
			wait_so_clk_posedge( found );
			if( !found ) begin
				$display( "FAIL: %0s timeout", msg );
				fail_count = fail_count + 1;
			end
			else begin
				#1;
				actual = fpga_so;
				check_equal2( actual, expected, msg );
			end
		end
	endtask

	task automatic wait_ready_before_request;
		input is_sound;
		input [255:0] msg;
		integer i;
		reg found;
		begin
			found = 1'b0;
			for( i = 0; i < 256; i = i + 1 ) begin
				@( posedge clk );
				if( is_sound ? sound_ready : bus_ready ) begin
					found = 1'b1;
					i = 256;
				end
			end
			if( !found ) begin
				$display( "FAIL: %0s", msg );
				fail_count = fail_count + 1;
			end
		end
	endtask

	task automatic wait_mode_start;
		input [1:0] mode;
		input [255:0] msg;
		integer i;
		reg found;
		begin
			found = 1'b0;
			begin : u_wait_mode
				for( i = 0; i < 512; i = i + 1 ) begin
					@( posedge fpga_so_clk );
					#1;
					if( fpga_so === mode ) begin
						found = 1'b1;
						disable u_wait_mode;
					end
				end
			end
			if( !found ) begin
				$display( "FAIL: %0s mode start timeout", msg );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
			end
		end
	endtask

	task automatic wait_ready_high;
		input is_sound;
		input [255:0] msg;
		integer i;
		reg found;
		begin
			found = 1'b0;
			for( i = 0; i < 256; i = i + 1 ) begin
				@( posedge clk );
				if( is_sound ? sound_ready : bus_ready ) begin
					found = 1'b1;
					i = 256;
				end
			end
			if( !found ) begin
				$display( "FAIL: %0s", msg );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
			end
		end
	endtask

	task automatic wait_rdata_high;
		input [255:0] msg;
		integer i;
		reg found;
		begin
			found = 1'b0;
			for( i = 0; i < 256; i = i + 1 ) begin
				@( posedge clk );
				if( bus_rdata_en ) begin
					found = 1'b1;
					i = 256;
				end
			end
			if( !found ) begin
				$display( "FAIL: %0s", msg );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
			end
		end
	endtask

	task automatic send_io_write;
		input [7:0] addr;
		input [7:0] data;
		begin
			wait_ready_before_request( 1'b0, "bus_ready timeout before io_write" );
			if( !bus_ready ) begin
				disable send_io_write;
			end
			bus_address	<= addr;
			bus_wdata	<= data;
			bus_write	<= 1'b1;
			bus_valid	<= 1'b1;
			@( posedge clk );
			bus_valid	<= 1'b0;
			bus_write	<= 1'b0;
		end
	endtask

	task automatic send_io_read;
		input [7:0] addr;
		begin
			wait_ready_before_request( 1'b0, "bus_ready timeout before io_read" );
			if( !bus_ready ) begin
				disable send_io_read;
			end
			bus_address	<= addr;
			bus_write	<= 1'b0;
			bus_valid	<= 1'b1;
			@( posedge clk );
			bus_valid	<= 1'b0;
		end
	endtask

	task automatic send_sound;
		input [31:0] lch;
		input [31:0] rch;
		begin
			wait_ready_before_request( 1'b1, "sound_ready timeout before sound_send" );
			if( !sound_ready ) begin
				disable send_sound;
			end
			sound_l		<= lch;
			sound_r		<= rch;
			sound_valid	<= 1'b1;
			@( posedge clk );
			sound_valid	<= 1'b0;
		end
	endtask

	task automatic expect_io_write_frame;
		input [7:0] exp_addr;
		input [7:0] exp_data;
		begin
			wait_mode_start( 2'b00, "io_write" );
			check_so_pair( exp_addr[7:6], "io_write addr[7:6]" );
			check_so_pair( exp_addr[5:4], "io_write addr[5:4]" );
			check_so_pair( exp_addr[3:2], "io_write addr[3:2]" );
			check_so_pair( exp_addr[1:0], "io_write addr[1:0]" );
			check_so_pair( exp_data[7:6], "io_write data[7:6]" );
			check_so_pair( exp_data[5:4], "io_write data[5:4]" );
			check_so_pair( exp_data[3:2], "io_write data[3:2]" );
			check_so_pair( exp_data[1:0], "io_write data[1:0]" );
		end
	endtask

	task automatic expect_sound_frame;
		input [31:0] exp_l;
		input [31:0] exp_r;
		integer i;
		reg found;
		begin
			wait_mode_start( 2'b10, "sound_send" );
			for( i = 0; i < 16; i = i + 1 ) begin
				wait_so_clk_posedge( found );
				if( !found ) begin
					$display( "FAIL: sound L pair timeout" );
					fail_count = fail_count + 1;
					disable expect_sound_frame;
				end
				#1;
				check_equal2( fpga_so, exp_l[31 - (i*2) -: 2], "sound L pair" );
			end
			for( i = 0; i < 16; i = i + 1 ) begin
				wait_so_clk_posedge( found );
				if( !found ) begin
					$display( "FAIL: sound R pair timeout" );
					fail_count = fail_count + 1;
					disable expect_sound_frame;
				end
				#1;
				check_equal2( fpga_so, exp_r[31 - (i*2) -: 2], "sound R pair" );
			end
		end
	endtask

	task automatic respond_io_read_frame;
		input [7:0] exp_addr;
		input [7:0] ret_data;
		integer i;
		reg found;
		begin
			wait_mode_start( 2'b01, "io_read" );
			check_so_pair( exp_addr[7:6], "io_read addr[7:6]" );
			check_so_pair( exp_addr[5:4], "io_read addr[5:4]" );
			check_so_pair( exp_addr[3:2], "io_read addr[3:2]" );
			check_so_pair( exp_addr[1:0], "io_read addr[1:0]" );

			// Wait until master advances to #5 and releases the line.
			wait_so_clk_posedge( found );
			if( !found ) begin
				$display( "FAIL: io_read release timeout" );
				fail_count = fail_count + 1;
				disable respond_io_read_frame;
			end

			// #5: ready flag, #6-#9: data pairs.
			tb_so_oe = 1'b1;
			tb_so_drive = 2'b11;
			wait_so_clk_posedge( found );
			if( !found ) begin
				$display( "FAIL: io_read ready flag sample timeout" );
				fail_count = fail_count + 1;
				tb_so_oe = 1'b0;
				disable respond_io_read_frame;
			end
			wait_so_clk_negedge( found );
			if( !found ) begin
				$display( "FAIL: io_read ready flag drive timeout" );
				fail_count = fail_count + 1;
				tb_so_oe = 1'b0;
				disable respond_io_read_frame;
			end
			tb_so_drive = ret_data[7:6];
			for( i = 0; i < 3; i = i + 1 ) begin
				wait_so_clk_negedge( found );
				if( !found ) begin
					$display( "FAIL: io_read response drive timeout" );
					fail_count = fail_count + 1;
					tb_so_oe = 1'b0;
					disable respond_io_read_frame;
				end
				case( i )
				0: tb_so_drive = ret_data[5:4];
				1: tb_so_drive = ret_data[3:2];
				default: tb_so_drive = ret_data[1:0];
				endcase
			end
			wait_so_clk_posedge( found );
			if( !found ) begin
				$display( "FAIL: io_read final data sample timeout" );
				fail_count = fail_count + 1;
			end
			tb_so_oe = 1'b0;
		end
	endtask

	initial begin
		reset_n			= 1'b0;
		clk				= 1'b0;
		clk_serial		= 1'b0;
		bus_address		= 8'd0;
		bus_write		= 1'b0;
		bus_wdata		= 8'd0;
		bus_valid		= 1'b0;
		sound_l			= 32'd0;
		sound_r			= 32'd0;
		sound_valid		= 1'b0;
		tb_so_drive		= 2'b00;
		tb_so_oe		= 1'b0;
		pass_count		= 0;
		fail_count		= 0;
		test_number		= 0;

		repeat( 10 ) @( posedge clk );
		reset_n = 1'b1;
		repeat( 10 ) @( posedge clk );

		test_number = test_number + 1;
		$display( "[TEST%0d] io_write frame", test_number );
		fork
			send_io_write( 8'h98, 8'hA5 );
			expect_io_write_frame( 8'h98, 8'hA5 );
		join
		wait_ready_high( 1'b0, "bus_ready did not return high after io_write" );

		test_number = test_number + 1;
		$display( "[TEST%0d] io_read frame + response", test_number );
		fork
			send_io_read( 8'h9A );
			respond_io_read_frame( 8'h9A, 8'h00 );
		join
		wait_rdata_high( "bus_rdata_en did not assert after io_read" );
		check_equal8( bus_rdata, 8'h00, "io_read bus_rdata" );
		wait_ready_high( 1'b0, "bus_ready did not return high after io_read" );

		test_number = test_number + 1;
		$display( "[TEST%0d] sound_send frame", test_number );
		fork
			send_sound( 32'h1122_3344, 32'hA5A5_5A5A );
			expect_sound_frame( 32'h1122_3344, 32'hA5A5_5A5A );
		join
		wait_ready_high( 1'b1, "sound_ready did not return high after sound_send" );

		$display( "----------------------------------------" );
		$display( "RESULT: PASS=%0d FAIL=%0d", pass_count, fail_count );
		if( fail_count != 0 ) begin
			$fatal( 1, "test_master_001 failed" );
		end
		$finish;
	end
endmodule
