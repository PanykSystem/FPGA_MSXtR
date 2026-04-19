// -----------------------------------------------------------------------------
//	Test of t80.v
//	Copyright (C)2024 Takayuki Hara (HRA!)
//	
//	 Permission is hereby granted, free of charge, to any person obtaining a 
//	copy of this software and associated documentation files (the "Software"), 
//	to deal in the Software without restriction, including without limitation 
//	the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//	and/or sell copies of the Software, and to permit persons to whom the 
//	Software is furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//	
//	The Software is provided "as is", without warranty of any kind, express or 
//	implied, including but not limited to the warranties of merchantability, 
//	fitness for a particular purpose and noninfringement. In no event shall the 
//	authors or copyright holders be liable for any claim, damages or other 
//	liability, whether in an action of contract, tort or otherwise, arising 
//	from, out of or in connection with the Software or the use or other dealings 
//	in the Software.
// -----------------------------------------------------------------------------
//	Description:
//		Pulse wave modulation
// -----------------------------------------------------------------------------

module tb ();
	localparam		clk_base	= 1_000_000_000/85_909;	//	ps
	reg				reset_n		;
	reg				clk_n		;
	reg				enable		;
	reg			wait_p		;
	reg			int_p		;
	reg				nmi_n		;
	reg				busrq		;
	wire			m1			;
	wire			mreq		;
	wire			iorq		;
	wire			rd			;
	wire			wr			;
	wire			rfsh		;
	wire			halt_n		;
	wire			busak		;
	wire	[15:0]	a			;
	wire	[7:0]	d			;
	wire	[7:0]	rdata		;
	reg		[7:0]	ff_d		;
	reg		[7:0]	ff_ram [0:15];

	reg		[4:0]	ff_clock;
	reg		[4:0]	ff_clock_speed;

	// --------------------------------------------------------------------
	//	dut
	// --------------------------------------------------------------------
	cz80_inst u_z80 (
		.reset_n	( reset_n		),
		.clk		( clk_n			),
		.enable		( enable		),
		.wait_p		( wait_p			),
		.int_p		( int_p			),
		.nmi_n		( nmi_n			),
		.busrq		( busrq			),
		.m1			( m1			),
		.mreq		( mreq			),
		.iorq		( iorq			),
		.rd			( rd			),
		.wr			( wr			),
		.rfsh		( rfsh			),
		.halt_n		( halt_n		),
		.busak		( busak			),
		.a			( a				),
		.wdata		( d				),
		.rdata		( rdata			)
	);

	assign rdata	= ff_d;

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk_n <= ~clk_n;
	end

	// --------------------------------------------------------------------
	//	clock divider
	// --------------------------------------------------------------------
	always @( posedge clk_n ) begin
		if( !reset_n ) begin
			ff_clock <= 5'd1;
		end
		else if( ff_clock == 5'd0 ) begin
			ff_clock <= ff_clock_speed;
		end
		else begin
			ff_clock <= ff_clock - 5'd1;
		end
	end

	assign enable = (ff_clock == 5'd0 );

	// --------------------------------------------------------------------
	//	tasks
	// --------------------------------------------------------------------
	always @( posedge clk_n ) begin
		if( !reset_n ) begin
			ff_d <= 8'd0;
		end
		else begin
			case( a[4:0] )
			4'd0:		ff_d <= 8'hdd;	//	ld  ix, 0010h
			4'd1:		ff_d <= 8'h21;
			4'd2:		ff_d <= 8'h10;
			4'd3:		ff_d <= 8'h00;
			4'd4:		ff_d <= 8'h3e;	//	ld  a, 12h
			4'd5:		ff_d <= 8'h12;
			4'd6:		ff_d <= 8'h32;	//	ld  (0010h), a
			4'd7:		ff_d <= 8'h10;
			4'd8:		ff_d <= 8'h00;
			4'd9:		ff_d <= 8'hdd;	//	bit 0, (ix + 0)
			4'd10:		ff_d <= 8'hcb;
			4'd11:		ff_d <= 8'h00;
			4'd12:		ff_d <= 8'h46;
			4'd13:		ff_d <= 8'hc3;	//	jp  0000h
			4'd14:		ff_d <= 8'h00;
			4'd15:		ff_d <= 8'h00;
			default:	ff_d <= ff_ram[ a[3:0] ];
			endcase
		end
	end

	always @( posedge clk_n ) begin
		if( mreq && wr && a[4] == 1'b1 ) begin
			ff_ram[ a[3:0] ] <= d;
		end
	end

	// --------------------------------------------------------------------
	//	test bench
	// --------------------------------------------------------------------
	initial begin
		reset_n		= 0;
		clk_n		= 1;
		wait_p		= 0;
		int_p		= 0;
		nmi_n		= 1;
		busrq		= 0;
		ff_clock_speed	= 5'd24;

		@( negedge clk_n );
		@( negedge clk_n );
		@( posedge clk_n );

		reset_n		= 1;
		@( posedge clk_n );

		// --------------------------------------------------------------------
		//	3.579545mhz相当 
		// --------------------------------------------------------------------
		ff_clock_speed	= 5'd24;
		repeat( 1000 ) @( posedge clk_n );

		// --------------------------------------------------------------------
		//	7.15909mhz相当 
		// --------------------------------------------------------------------
		ff_clock_speed	= 5'd12;
		repeat( 1000 ) @( posedge clk_n );

		// --------------------------------------------------------------------
		//	14.31818mhz相当 
		// --------------------------------------------------------------------
		ff_clock_speed	= 5'd6;
		repeat( 1000 ) @( posedge clk_n );

		// --------------------------------------------------------------------
		//	21.47727mhz相当 
		// --------------------------------------------------------------------
		ff_clock_speed	= 5'd4;
		repeat( 1000 ) @( posedge clk_n );

		$finish;
	end
endmodule
