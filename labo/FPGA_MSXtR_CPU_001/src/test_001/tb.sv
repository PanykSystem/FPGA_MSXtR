`timescale 1ns/1ps

module tb;
	localparam real CLK14M_PERIOD_PS = 1_000_000_000_000.0 / 14_318_180.0;
	localparam real CLK27M_PERIOD_PS = 1_000_000_000_000.0 / 27_000_000.0;

	reg				clk27m;
	reg				clk14m;
	reg		[1:0]	button;
	wire			uart_tx;
	wire	[5:0]	led;
	wire			O_sdram_clk;
	wire			O_sdram_cke;
	wire			O_sdram_cs_n;
	wire			O_sdram_cas_n;
	wire			O_sdram_ras_n;
	wire			O_sdram_wen_n;
	wire	[31:0]	IO_sdram_dq;
	wire	[10:0]	O_sdram_addr;
	wire	[1:0]	O_sdram_ba;
	wire	[3:0]	O_sdram_dqm;

	fpga_msxtr u_dut (
		.clk27m			( clk27m		),
		.clk14m			( clk14m		),
		.button			( button		),
		.uart_tx		( uart_tx		),
		.led			( led			),
		.O_sdram_clk	( O_sdram_clk	),
		.O_sdram_cke	( O_sdram_cke	),
		.O_sdram_cs_n	( O_sdram_cs_n	),
		.O_sdram_cas_n	( O_sdram_cas_n	),
		.O_sdram_ras_n	( O_sdram_ras_n	),
		.O_sdram_wen_n	( O_sdram_wen_n	),
		.IO_sdram_dq	( IO_sdram_dq	),
		.O_sdram_addr	( O_sdram_addr	),
		.O_sdram_ba		( O_sdram_ba	),
		.O_sdram_dqm	( O_sdram_dqm	)
	);

	always #(CLK14M_PERIOD_PS / 2.0) begin
		clk14m <= ~clk14m;
	end

	always #(CLK27M_PERIOD_PS / 2.0) begin
		clk27m <= ~clk27m;
	end

	initial begin
		clk27m = 1'b0;
		clk14m = 1'b0;
		button = 2'd0;

		repeat(5000) @(posedge clk14m);
		button = 2'd1;
		repeat(1000) @(posedge clk14m);
		button = 2'd0;
		repeat(100000) @(posedge clk14m);

		$finish;
	end
endmodule
