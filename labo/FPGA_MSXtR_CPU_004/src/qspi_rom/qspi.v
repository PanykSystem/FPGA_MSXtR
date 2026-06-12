// -----------------------------------------------------------------------------
//	qspi.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
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
//		Quad SPI controller (mode0 only)
// -----------------------------------------------------------------------------

module qspi (
	input			reset,
	input			clk,				//	System Clock
	input			clk_serial,			//	Serial Clock (High speed)
	//	internal interface
	input	[2:0]	serial_mode,
	input	[7:0]	serial_wdata,
	input			serial_write,
	input			serial_valid,
	output			serial_ready,
	output	[7:0]	serial_rdata,
	output			serial_rdata_en,
	//	QSPI interface
	output			qspi_clk,
	inout	[3:0]	qspi_sio
);
	// ---------------------------------------------------------
	//	serial_mode
	//		0: Standard SPI write
	//		1: Standard SPI read
	//		2: Quad SPI write
	//		3: Quad SPI read
	//		4: Quad SPI dummy clock
	//		5-7: Reserved
	//	note:
	//		Don't support Dual SPI read/write.
	// ---------------------------------------------------------
	reg 			ff_qspi_clk;
	reg 			ff_active;

	// ---------------------------------------------------------
	//	Serial Clock
	// ---------------------------------------------------------
	always @( posedge clk_serial ) begin
		if( reset ) begin
			ff_qspi_clk <= 1'b0;
		end
		else if( !ff_active ) begin
			ff_qspi_clk <= 1'b0;
		end
		else begin
			ff_qspi_clk <= ~ff_qspi_clk;
		end
	end
endmodule
