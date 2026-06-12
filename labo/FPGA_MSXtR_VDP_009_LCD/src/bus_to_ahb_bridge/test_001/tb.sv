`timescale 1ns/1ps

module tb;
	localparam real CLK_PERIOD = 10.0;

	reg			reset_n;
	reg			clk;

	reg			bus_cs;
	reg			bus_address;
	reg			bus_write;
	reg			bus_valid;
	wire			bus_ready;
	reg	[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;

	wire			ahb_mst_valid;
	reg			ahb_mst_ready;
	wire			ahb_mst_sel;
	wire	[1:0]	ahb_mst_trans;
	wire	[2:0]	ahb_mst_size;
	wire			ahb_mst_write;
	wire	[31:0]	ahb_mst_addr;
	wire	[31:0]	ahb_mst_wdata;
	reg	[31:0]	ahb_mst_rdata;
	reg	[1:0]	ahb_mst_resp;

	int	pass_count;
	int	fail_count;

	always #(CLK_PERIOD / 2.0) begin
		clk <= ~clk;
	end

	bus_to_ahb_bridge u_dut (
		.reset_n		( reset_n		),
		.clk			( clk			),
		.bus_cs			( bus_cs		),
		.bus_address	( bus_address	),
		.bus_write		( bus_write		),
		.bus_valid		( bus_valid		),
		.bus_ready		( bus_ready		),
		.bus_wdata		( bus_wdata		),
		.bus_rdata		( bus_rdata		),
		.bus_rdata_en	( bus_rdata_en	),
		.ahb_mst_valid	( ahb_mst_valid	),
		.ahb_mst_ready	( ahb_mst_ready	),
		.ahb_mst_sel	( ahb_mst_sel	),
		.ahb_mst_trans	( ahb_mst_trans	),
		.ahb_mst_size	( ahb_mst_size	),
		.ahb_mst_write	( ahb_mst_write	),
		.ahb_mst_addr	( ahb_mst_addr	),
		.ahb_mst_wdata	( ahb_mst_wdata	),
		.ahb_mst_rdata	( ahb_mst_rdata	),
		.ahb_mst_resp	( ahb_mst_resp	)
	);

	task automatic check_equal32;
		input [31:0] actual;
		input [31:0] expected;
		input [255:0] name;
		begin
			if( actual === expected ) begin
				pass_count = pass_count + 1;
				$display( "[PASS] %0s : actual=0x%08X expected=0x%08X", name, actual, expected );
			end
			else begin
				fail_count = fail_count + 1;
				$display( "[FAIL] %0s : actual=0x%08X expected=0x%08X", name, actual, expected );
			end
		end
	endtask

	task automatic check_equal8;
		input [7:0] actual;
		input [7:0] expected;
		input [255:0] name;
		begin
			if( actual === expected ) begin
				pass_count = pass_count + 1;
				$display( "[PASS] %0s : actual=0x%02X expected=0x%02X", name, actual, expected );
			end
			else begin
				fail_count = fail_count + 1;
				$display( "[FAIL] %0s : actual=0x%02X expected=0x%02X", name, actual, expected );
			end
		end
	endtask

	task automatic check_equal1;
		input actual;
		input expected;
		input [255:0] name;
		begin
			if( actual === expected ) begin
				pass_count = pass_count + 1;
				$display( "[PASS] %0s : actual=%0d expected=%0d", name, actual, expected );
			end
			else begin
				fail_count = fail_count + 1;
				$display( "[FAIL] %0s : actual=%0d expected=%0d", name, actual, expected );
			end
		end
	endtask

	task automatic bus_access;
		input addr_sel;
		input wr;
		input [7:0] wdata;
		begin
			@( posedge clk );
			while( !bus_ready ) begin
				@( posedge clk );
			end
			bus_cs		= 1'b1;
			bus_address	= addr_sel;
			bus_write	= wr;
			bus_valid	= 1'b1;
			bus_wdata	= wdata;
			@( posedge clk );
			bus_cs		= 1'b0;
			bus_address	= 1'b0;
			bus_write	= 1'b0;
			bus_valid	= 1'b0;
			bus_wdata	= 8'h00;
		end
	endtask

	task automatic read_address_port;
		output [7:0] rdata;
		integer timeout;
		begin
			rdata = 8'h00;
			bus_access( 1'b0, 1'b0, 8'h00 );
			timeout = 0;
			while( !bus_rdata_en && timeout < 20 ) begin
				timeout = timeout + 1;
				@( posedge clk );
			end
			if( !bus_rdata_en ) begin
				fail_count = fail_count + 1;
				$display( "[FAIL] read_address_port : timeout waiting bus_rdata_en" );
			end
			else begin
				rdata = bus_rdata;
			end
		end
	endtask

	task automatic issue_ahb_done;
		input [31:0] rdata;
		input [1:0] resp;
		begin
			ahb_mst_rdata = rdata;
			ahb_mst_resp	= resp;
			@( posedge clk );
			ahb_mst_ready = 1'b1;
			@( posedge clk );
			ahb_mst_ready = 1'b0;
		end
	endtask

	initial begin
		reg [7:0] tmp;
		reset_n			= 1'b0;
		clk				= 1'b0;
		bus_cs			= 1'b0;
		bus_address		= 1'b0;
		bus_write		= 1'b0;
		bus_valid		= 1'b0;
		bus_wdata		= 8'h00;
		ahb_mst_ready	= 1'b0;
		ahb_mst_rdata	= 32'h00000000;
		ahb_mst_resp	= 2'b00;
		pass_count		= 0;
		fail_count		= 0;

		$display( "============================================================" );
		$display( "bus_to_ahb_bridge test_001 start" );

		repeat( 5 ) @( posedge clk );
		reset_n = 1'b1;
		repeat( 2 ) @( posedge clk );

		check_equal1( bus_ready, 1'b1, "reset: bus_ready" );
		check_equal1( ahb_mst_valid, 1'b0, "reset: ahb_mst_valid" );
		check_equal32( ahb_mst_addr, 32'h00000000, "reset: ahb_mst_addr" );

		$display( "[TEST] set address 0x11223344" );
		bus_access( 1'b0, 1'b1, 8'h44 );
		bus_access( 1'b0, 1'b1, 8'h33 );
		bus_access( 1'b0, 1'b1, 8'h22 );
		bus_access( 1'b0, 1'b1, 8'h11 );

		$display( "[TEST] read back address bytes" );
		read_address_port( tmp );
		check_equal8( tmp, 8'h44, "address byte 0" );
		read_address_port( tmp );
		check_equal8( tmp, 8'h33, "address byte 1" );
		read_address_port( tmp );
		check_equal8( tmp, 8'h22, "address byte 2" );
		read_address_port( tmp );
		check_equal8( tmp, 8'h11, "address byte 3" );

		$display( "[TEST] AHB write request at address 0x11223344" );
		bus_access( 1'b1, 1'b1, 8'hAB );
		@( posedge clk );
		check_equal1( ahb_mst_valid, 1'b1, "write: ahb_mst_valid asserted" );
		check_equal1( ahb_mst_sel, 1'b1, "write: ahb_mst_sel asserted" );
		check_equal32( {30'd0, ahb_mst_trans}, 32'h00000002, "write: ahb_mst_trans NONSEQ" );
		check_equal32( {29'd0, ahb_mst_size}, 32'h00000000, "write: ahb_mst_size BYTE" );
		check_equal1( ahb_mst_write, 1'b1, "write: ahb_mst_write" );
		check_equal32( ahb_mst_addr, 32'h11223344, "write: ahb_mst_addr" );
		check_equal32( ahb_mst_wdata, 32'h000000AB, "write: ahb_mst_wdata lane0" );
		check_equal1( bus_ready, 1'b0, "write: bus_ready during busy" );
		issue_ahb_done( 32'h00000000, 2'b00 );
		@( posedge clk );
		check_equal1( bus_ready, 1'b1, "write done: bus_ready" );

		$display( "[TEST] AHB read request at address 0x11223345" );
		bus_access( 1'b1, 1'b0, 8'h00 );
		@( posedge clk );
		check_equal1( ahb_mst_valid, 1'b1, "read: ahb_mst_valid asserted" );
		check_equal1( ahb_mst_write, 1'b0, "read: ahb_mst_write" );
		check_equal32( ahb_mst_addr, 32'h11223345, "read: ahb_mst_addr" );
		issue_ahb_done( 32'hA1B2C3D4, 2'b00 );
		@( posedge clk );
		check_equal1( bus_rdata_en, 1'b1, "read: bus_rdata_en pulse" );
		check_equal8( bus_rdata, 8'hC3, "read: bus_rdata lane1" );
		@( posedge clk );
		check_equal1( bus_rdata_en, 1'b0, "read: bus_rdata_en deassert" );

		$display( "[TEST] AHB read error response should not assert bus_rdata_en" );
		bus_access( 1'b1, 1'b0, 8'h00 );
		@( posedge clk );
		check_equal32( ahb_mst_addr, 32'h11223346, "read err: ahb_mst_addr" );
		issue_ahb_done( 32'h55667788, 2'b01 );
		@( posedge clk );
		check_equal1( bus_rdata_en, 1'b0, "read err: bus_rdata_en stays low" );

		$display( "============================================================" );
		$display( "RESULT: pass=%0d fail=%0d", pass_count, fail_count );
		if( fail_count != 0 ) begin
			$fatal( 1, "Test failed" );
		end
		$finish;
	end
endmodule
