// -----------------------------------------------------------------------------
//	Gowin rPLL replacement models for simulation
//	These modules replace the Gowin FPGA hard macro PLLs with
//	simple clock generators for ModelSIM.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

// ====================================================================
//	Gowin_PLL: 85.90908MHz + 42.95454MHz from 14.31818MHz
// ====================================================================
module Gowin_rPLL (
	output			clkout,
	output			clkoutd,
	input			clkin
);
	reg		r_clkout	= 0;
	reg		r_clkoutd	= 0;

	//	85.90908MHz: period = 11.640ns, half = 5.820ns = 5820ps
	always #(1_000_000_000_000.0 / 85_909_080.0 / 2.0)  r_clkout  = ~r_clkout;

	//	42.95454MHz: period = 23.281ns, half = 11.640ns = 11640ps
	always #(1_000_000_000_000.0 / 42_954_540.0 / 2.0)  r_clkoutd = ~r_clkoutd;

	assign clkout  = r_clkout;
	assign clkoutd = r_clkoutd;
endmodule

// ====================================================================
//	Gowin_PLL2: 257.72724MHz from 14.31818MHz
// ====================================================================
module Gowin_rPLL2 (
	output			clkout,
	input			clkin
);
	reg		r_clkout = 0;

	//	257.72724MHz: period = 3.880ns, half = 1.940ns = 1940ps
	always #(1_000_000_000_000.0 / 257_727_240.0 / 2.0)  r_clkout = ~r_clkout;

	assign clkout = r_clkout;
endmodule

// ====================================================================
//	Gowin_PLL3: 135MHz from 27MHz
// ====================================================================
module Gowin_rPLL3 (
	output			clkout,
	input			clkin
);
	reg		r_clkout = 0;

	//	135MHz: period = 7.407ns, half = 3.703ns = 3703ps
	always #(1_000_000_000_000.0 / 135_000_000.0 / 2.0)  r_clkout = ~r_clkout;

	assign clkout = r_clkout;
endmodule
