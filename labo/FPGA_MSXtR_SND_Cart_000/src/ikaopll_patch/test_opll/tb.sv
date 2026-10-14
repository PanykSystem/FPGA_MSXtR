`timescale 1ns/1ps

module tb;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg slot_reset_n = 1'b0;
	reg iorq_n = 1'b1;
	reg wr_n = 1'b1;
	reg [15:0] address = 16'd0;
	reg [7:0] data = 8'd0;
	tri [7:0] slot_data;
	wire [15:0] bus_address;
	wire [7:0] bus_data;
	wire bus_io;
	wire bus_write;
	wire bus_valid;
	wire bus_ready;
	wire opll_cs;
	wire opll_ready;
	wire [15:0] sound0;
	wire [15:0] sound1;
	reg [3:0] divider = 4'd0;
	reg enable = 1'b0;
	integer accepted = 0;
	integer samples = 0;

	always #11.64 clk = ~clk;
	assign slot_data = !wr_n ? data : 8'hZZ;
	always @( posedge clk ) begin
		if( !reset_n && $test$plusargs("legacy_reset") ) begin
			divider <= 4'd0;
			enable <= 1'b0;
		end
		else if( divider == 4'd11 ) begin
			divider <= 4'd0;
			enable <= 1'b1;
		end
		else begin
			divider <= divider + 1'b1;
			enable <= 1'b0;
		end
		if( bus_valid && bus_ready ) begin
			accepted = accepted + 1;
			$display("WRITE port=%04h data=%02h", bus_address, bus_data);
		end
		if( sound0 != 16'd0 && !$isunknown(sound0) ) samples = samples + 1;
	end

	msx_slot u_slot (
		.clk(clk), .reset_n(), .p_slot_reset_n(slot_reset_n),
		.p_slot_sltsl_n(1'b1), .p_slot_memreq_n(1'b1),
		.p_slot_ioreq_n(iorq_n), .p_slot_wr_n(wr_n), .p_slot_rd_n(1'b1),
		.p_slot_address(address), .p_slot_data(slot_data),
		.p_slot_int(), .p_slot_data_dir(), .int_n(1'b1),
		.bus_address(bus_address), .bus_io(bus_io), .bus_write(bus_write),
		.bus_valid(bus_valid), .bus_ready(bus_ready), .bus_wdata(bus_data)
	);
	y8960_address_decode u_decode (
		.clk(clk), .reset_n(reset_n), .bus_address(bus_address), .bus_io(bus_io),
		.bus_write(bus_write), .bus_valid(bus_valid), .bus_ready(bus_ready),
		.bus_wdata(bus_data), .bus_opll_cs(opll_cs), .bus_ssg_cs(),
		.bus_opll_ready(opll_ready), .bus_ssg_ready(1'b1), .led()
	);
	dual_opll u_opll (
		.clk(clk), .reset_n(reset_n), .enable(enable), .bus_cs(opll_cs),
		.bus_address(bus_address[1:0]), .bus_write(bus_write), .bus_valid(bus_valid),
		.bus_ready(opll_ready), .bus_wdata(bus_data), .sound_out0(sound0), .sound_out1(sound1)
	);

	task automatic out_port(input [7:0] port, input [7:0] value);
		begin
			@( posedge clk ); #1;
			address = {8'd0, port};
			data = value;
			wr_n = 1'b0;
			repeat(3) @( posedge clk );
			#1;
			iorq_n = 1'b0;
			repeat(25) @( posedge clk );
			#1;
			iorq_n = 1'b1;
			wr_n = 1'b1;
			repeat(1200) @( posedge clk );
		end
	endtask
	task automatic write_register(input [7:0] register_address, input [7:0] value);
		begin
			out_port(8'h7C, register_address);
			out_port(8'h7D, value);
		end
	endtask

	initial begin
		repeat($test$plusargs("short_reset") ? 1 : 200) @( posedge clk );
		#1;
		reset_n = 1'b1;
		slot_reset_n = 1'b1;
		repeat(10000) @( posedge clk );
		write_register(8'h30, 8'h10);
		write_register(8'h10, 8'h80);
		write_register(8'h20, 8'h15);
		repeat(100000) @( posedge clk );
		$display("OPLL addr=%02h samples=%0d accepted=%0d sound=%04h", u_opll.u_ikaopll0.u_REG.d1reg_addr, samples, accepted, sound0);
		if( accepted != 6 || samples == 0 ) $fatal(1, "OPLL tone not generated through cartridge slot");
		$display("PASS: 7Ch/7Dh slot writes generate nonzero OPLL audio");
		$finish;
	end
endmodule