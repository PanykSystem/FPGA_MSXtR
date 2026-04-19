`timescale 1ns/1ps

module tb;
	localparam real CLK14M_PERIOD_PS = 1_000_000_000_000.0 / 14_318_180.0;
	localparam real CLK27M_PERIOD_PS = 1_000_000_000_000.0 / 27_000_000.0;

	reg				clk27m;
	reg				clk14m;
	reg		[1:0]	button;
	wire			vdp_so_clk;
	wire	[1:0]	vdp_so;
	reg				vdp_si_clk;
	reg		[1:0]	vdp_si;
	wire			srom_cs_n;
	wire			srom2_cs_n;
	wire			srom_clk;
	wire	[3:0]	srom_sio;
	wire			pa_en;
	wire			i2s_bclk;
	wire			i2s_lrck;
	wire			i2s_dout;
	wire			uart_tx;
	reg				dipsw;
	wire			ws2812;
	wire	[2:0]	io_sel;
	wire			io_clk;
	wire			reset_n;
	wire	[7:0]	dio;
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
		.vdp_so_clk		( vdp_so_clk	),
		.vdp_so			( vdp_so		),
		.vdp_si_clk		( vdp_si_clk	),
		.vdp_si			( vdp_si		),
		.srom_cs_n		( srom_cs_n		),
		.srom2_cs_n		( srom2_cs_n	),
		.srom_clk		( srom_clk		),
		.srom_sio		( srom_sio		),
		.pa_en			( pa_en			),
		.i2s_bclk		( i2s_bclk		),
		.i2s_lrck		( i2s_lrck		),
		.i2s_dout		( i2s_dout		),
		.uart_tx		( uart_tx		),
		.dipsw			( dipsw			),
		.ws2812			( ws2812		),
		.io_sel			( io_sel		),
		.io_clk			( io_clk		),
		.reset_n		( reset_n		),
		.dio			( dio			),
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
		vdp_si_clk = 1'b0;
		vdp_si = 2'd0;
		dipsw = 1'b0;

		repeat(5000) @(posedge clk14m);
		repeat( 2 ) begin
			button = 2'd1;
			repeat(1000) @(posedge clk14m);
			button = 2'd0;
			repeat(1000000) @(posedge clk14m);
		end
		$finish;
	end
endmodule
