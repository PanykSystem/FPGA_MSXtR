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

	function [7:0] f_sound_tx_byte;
		input [31:0] lch;
		input [31:0] rch;
		input [2:0] index;
		begin
			case( index )
			3'd0:		f_sound_tx_byte = lch[31:24];
			3'd1:		f_sound_tx_byte = lch[23:16];
			3'd2:		f_sound_tx_byte = lch[15:8];
			3'd3:		f_sound_tx_byte = lch[7:0];
			3'd4:		f_sound_tx_byte = rch[31:24];
			3'd5:		f_sound_tx_byte = rch[23:16];
			3'd6:		f_sound_tx_byte = rch[15:8];
			default:	f_sound_tx_byte = rch[7:0];
			endcase
		end
	endfunction

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
		.bus_cs			( 1'b1			),
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

	task automatic wait_sub_start;
		input [1:0] exp_mode;
		input [7:0] exp_tx_data;
		input check_tx_data;
		input [255:0] msg;
		integer i;
		reg found;
		begin
			found = 1'b0;
			begin : u_wait_sub_start
				for( i = 0; i < 512; i = i + 1 ) begin
					@( posedge clk_serial );
					if( u_dut.w_sub_start && (u_dut.w_sub_mode == exp_mode) ) begin
						found = 1'b1;
						disable u_wait_sub_start;
					end
				end
			end
			if( !found ) begin
				$display( "FAIL: %0s sub start timeout", msg );
				fail_count = fail_count + 1;
			end
			else begin
				pass_count = pass_count + 1;
				if( check_tx_data ) begin
					check_equal8( u_dut.w_sub_tx_data, exp_tx_data, msg );
				end
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
			wait_sub_start( 2'b00, 8'h00, 1'b1, "io_write mode" );
			wait_sub_start( 2'b01, exp_addr, 1'b1, "io_write addr" );
			wait_sub_start( 2'b01, exp_data, 1'b1, "io_write data" );
		end
	endtask

	task automatic expect_sound_frame;
		input [31:0] exp_l;
		input [31:0] exp_r;
		integer i;
		begin
			wait_sub_start( 2'b00, 8'h02, 1'b1, "sound_send mode" );
			for( i = 0; i < 8; i = i + 1 ) begin
				wait_sub_start( 2'b01, f_sound_tx_byte( exp_l, exp_r, i[2:0] ), 1'b1, "sound_send byte" );
			end
		end
	endtask

	task automatic respond_io_read_frame;
		input [7:0] exp_addr;
		input [7:0] ret_data;
		integer i;
		reg found;
		begin
			wait_sub_start( 2'b00, 8'h01, 1'b1, "io_read mode" );
			wait_sub_start( 2'b01, exp_addr, 1'b1, "io_read addr" );
			wait_sub_start( 2'b11, 8'h00, 1'b1, "io_read status" );

			// Status read is sampled in RX_STATUS mode.
			tb_so_oe = 1'b1;
			tb_so_drive = 2'b11;

			wait_sub_start( 2'b10, 8'h00, 1'b1, "io_read data" );
			// RX_BYTE captures one pair per so_clk cycle.
			tb_so_drive = ret_data[7:6];
			for( i = 0; i < 3; i = i + 1 ) begin
				wait_so_clk_posedge( found );
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

			// Keep driving until RX_BYTE sub-transaction is completed.
			found = 1'b0;
			for( i = 0; i < 128; i = i + 1 ) begin
				@( posedge clk_serial );
				if( u_dut.w_sub_done ) begin
					found = 1'b1;
					i = 128;
				end
			end
			if( !found ) begin
				$display( "FAIL: io_read final done timeout" );
				fail_count = fail_count + 1;
			end
			@( posedge clk_serial );
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
