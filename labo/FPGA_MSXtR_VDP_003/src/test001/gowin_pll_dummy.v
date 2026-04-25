// --------------------------------------------------------------------
//	PLL dummy
// ====================================================================
//	t.hara
// --------------------------------------------------------------------
module Gowin_rPLL (
	output			clkout,			//	214.7727MHz
	output			lock,
	input			clkin			//	14.31818MHz
);
	localparam	clk_base	= 1_000_000.0/214.7727;		//	ps
	reg				ff_clk = 1'b0;

	always #(clk_base/2) begin
		ff_clk <= ~ff_clk;
	end

	assign clkout	= ff_clk;
endmodule

// --------------------------------------------------------------------
module Gowin_rPLL2 (
	output			clkout,			//	85.90908MHz
	input			clkin			//	214.7727MHz
);
	reg		[2:0]	ff_count = 3'd0;
	reg				ff_clkout = 1'b0;

	always @( posedge clkin or negedge clkin ) begin
		if( ff_count == 3'd4 ) begin
			ff_count	<= 3'd0;
			ff_clkout	<= ~ff_clkout;
		end
		else begin
			ff_count	<= ff_count + 3'd1;
		end
	end

	assign clkout	= ff_clkout;
endmodule


// --------------------------------------------------------------------
module Gowin_CLKDIV (
	output			clkout,			//	42.95454MHz
	input			hclkin,			//	214.7727MHz
	input			resetn
);
	reg	[2:0]	ff_divider = 3'd0;
	reg			ff_clkout = 1'b0;

	always @( edge hclkin ) begin
		if( !resetn ) begin
			ff_divider	<= 3'd0;
			ff_clkout	<= 1'b0;
		end
		else if( ff_divider == 3'd5 ) begin
			ff_divider	<= 3'd0;
			ff_clkout	<= ~ff_clkout;
		end
		else begin
			ff_divider	<= ff_divider + 3'd1;
		end
	end

	assign clkout	= ff_clkout;
endmodule
