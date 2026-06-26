`timescale 1ns / 1ns

module tb;
	reg				reset_n;
	reg				clk;
	reg				clk_serial;
	reg				bus_cs;
	reg		[3:0]	bus_address;
	reg				bus_write;
	reg				bus_valid;
	wire			bus_ready;
	reg		[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;

	wire			flash_spi_cs_n;
	wire			flash_spi_ck;
	tri				flash_spi_hold_n;
	tri				flash_spi_wp_n;
	tri				flash_spi_do;
	tri				flash_spi_di;

	reg		[7:0]	read_data;
	reg		[7:0]	status_data;
	integer			poll_count;
	integer			test_number;

	pullup u_pu_hold( flash_spi_hold_n );
	pullup u_pu_wp( flash_spi_wp_n );

	always #10 clk = ~clk;
	always #4 clk_serial = ~clk_serial;

	config_rom u_dut (
		.reset_n			( reset_n				),
		.clk				( clk					),
		.clk_serial			( clk_serial			),
		.bus_cs				( bus_cs				),
		.bus_address		( bus_address			),
		.bus_write			( bus_write				),
		.bus_valid			( bus_valid				),
		.bus_ready			( bus_ready				),
		.bus_wdata			( bus_wdata				),
		.bus_rdata			( bus_rdata				),
		.bus_rdata_en		( bus_rdata_en			),
		.flash_spi_cs_n		( flash_spi_cs_n		),
		.flash_spi_ck		( flash_spi_ck			),
		.flash_spi_hold_n	( flash_spi_hold_n		),
		.flash_spi_wp_n		( flash_spi_wp_n		),
		.flash_spi_do		( flash_spi_do			),
		.flash_spi_di		( flash_spi_di			)
	);

	W25Q32JVxxIM u_flash (
		.CSn				( flash_spi_cs_n		),
		.CLK				( flash_spi_ck			),
		.DIO				( flash_spi_di			),
		.DO					( flash_spi_do			),
		.WPn				( flash_spi_wp_n		),
		.HOLDn				( flash_spi_hold_n		),
		.RESETn				( reset_n				)
	);

	task bus_write8;
		input [3:0] addr;
		input [7:0] data;
		integer timeout_count;
		begin
			@(posedge clk);
			bus_cs			<= 1'b1;
			bus_valid		<= 1'b1;
			bus_write		<= 1'b1;
			bus_address		<= addr;
			bus_wdata		<= data;
			timeout_count = 0;
			while( (bus_ready !== 1'b1) && (timeout_count < 20000) ) begin
				@(posedge clk);
				timeout_count = timeout_count + 1;
			end
			if( timeout_count >= 20000 ) begin
				$display("[TB][ERROR] bus_write8 timeout. addr=%02x data=%02x time=%0t", addr, data, $time);
				$finish;
			end

			@(posedge clk);
			bus_cs			<= 1'b0;
			bus_valid		<= 1'b0;
			bus_write		<= 1'b0;
			bus_address		<= 4'd0;
			bus_wdata		<= 8'd0;
		end
	endtask

	task bus_read8;
		input [3:0] addr;
		output [7:0] data;
		integer timeout_count;
		begin
			data = 8'h00;

			@(posedge clk);
			bus_cs			<= 1'b1;
			bus_valid		<= 1'b1;
			bus_write		<= 1'b0;
			bus_address		<= addr;

			timeout_count = 0;
			while( (bus_ready !== 1'b1) && (timeout_count < 20000) ) begin
				@(posedge clk);
				timeout_count = timeout_count + 1;
			end
			if( timeout_count >= 20000 ) begin
				$display("[TB][ERROR] bus_read8 accept timeout. addr=%02x time=%0t", addr, $time);
				$finish;
			end

			@(posedge clk);
			bus_cs			<= 1'b0;
			bus_valid		<= 1'b0;
			bus_address		<= 4'd0;

			timeout_count = 0;
			while( (bus_rdata_en !== 1'b1) && (timeout_count < 20000) ) begin
				@(posedge clk);
				timeout_count = timeout_count + 1;
			end
			if( timeout_count >= 20000 ) begin
				$display("[TB][ERROR] bus_read8 data timeout. addr=%02x time=%0t", addr, $time);
				$finish;
			end
			data = bus_rdata;
		end
	endtask

	initial begin
		reset_n			= 1'b0;
		clk				= 1'b0;
		clk_serial		= 1'b0;
		bus_cs			= 1'b0;
		bus_address		= 4'd0;
		bus_write		= 1'b0;
		bus_valid		= 1'b0;
		bus_wdata		= 8'd0;
		read_data		= 8'd0;
		status_data		= 8'd0;
		test_number		= 0;

		repeat( 20 ) @(posedge clk);
		reset_n = 1'b1;
		repeat( 20 ) @(posedge clk);

		test_number = test_number + 1;
		$display("[TB][TEST %0d] Enable ConfigROM access", test_number);
		bus_write8( 4'd0, 8'd64 );
		bus_write8( 4'd1, 8'd64 );
		bus_read8( 4'd0, read_data );
		$display("[TB] read 0x40 = %02x", read_data);
		bus_read8( 4'd1, read_data );
		$display("[TB] read 0x41 = %02x", read_data);

		test_number = test_number + 1;
		$display("[TB][TEST %0d] Select Serial ROM #1", test_number);
		bus_write8( 4'd2, 8'h06 );
		bus_write8( 4'd3, 8'h01 );

		test_number = test_number + 1;
		$display("[TB][TEST %0d] Set QE bit", test_number);
		bus_write8( 4'd2, 8'h08 );

		test_number = test_number + 1;
		$display("[TB][TEST %0d] Poll status busy bit", test_number);
		bus_write8( 4'd2, 8'h05 );
		poll_count = 0;
		while( poll_count < 200 ) begin
			bus_read8( 4'd3, status_data );
			if( status_data[0] == 1'b0 ) begin
				$display("[TB] busy cleared at poll=%0d", poll_count);
				poll_count = 200;
			end
			else begin
				poll_count = poll_count + 1;
			end
		end
		bus_write8( 4'd2, 8'h07 );

		test_number = test_number + 1;
		$display("[TB][TEST %0d] Single read @0x000000", test_number);
		bus_write8( 4'd2, 8'h00 );
		bus_write8( 4'd3, 8'h00 );
		bus_write8( 4'd3, 8'h00 );
		bus_write8( 4'd3, 8'h00 );
		bus_write8( 4'd2, 8'h01 );
		bus_read8( 4'd3, read_data );
		$display("[TB] data @0x000000 = %02x", read_data);
		bus_write8( 4'd2, 8'h07 );

		$display("[TB] PASS");
		#200;
		$finish;
	end
endmodule
