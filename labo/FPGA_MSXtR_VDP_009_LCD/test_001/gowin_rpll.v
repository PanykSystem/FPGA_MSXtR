// -----------------------------------------------------------------------------
//	Gowin rPLL replacement models for simulation
//	These modules replace the Gowin FPGA hard macro PLLs with
//	simple clock generators for ModelSIM.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

// ====================================================================
//	Gowin_PLL: 214.7727MHz from 14.31818MHz
// ====================================================================
module Gowin_rPLL (
	output			clkout,
	output			lock,
	input			clkin
);
	reg		r_clkout	= 0;
	reg		r_clkoutd	= 0;

	//	214.7727MHz
	always #(1_000_000_000.0 / 214_772_700.0 / 2.0)  r_clkout  = ~r_clkout;

	assign clkout	= r_clkout;
	assign clkoutd	= r_clkoutd;
	assign lock		= 1'b1;
endmodule

// ====================================================================
//	Gowin_PLL2: 85.90908MHz from 14.31818MHz
// ====================================================================
module Gowin_rPLL2 (
	output			clkout,
	output			lock,
	output			clkoutp,
	input			clkin
);
	reg		r_clkout = 0;

	//	85.90908MHz
	always #(1_000_000_000.0 / 85_909_080.0 / 2.0) begin
		r_clkout = ~r_clkout;
	end

	assign clkout	= r_clkout;
	assign clkoutp	= ~r_clkout;
	assign lock		= 1'b1;
endmodule

// ====================================================================
//	Gowin_CLKDIV: 42.95454MHz from 85.90908MHz
// ====================================================================
module Gowin_CLKDIV (
	output			clkout,
	input			hclkin,
	input			resetn
);
	reg		r_clkout = 0;

	always @( posedge hclkin ) begin
		r_clkout = ~r_clkout;
	end

	assign clkout = r_clkout;
endmodule
