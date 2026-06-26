// -----------------------------------------------------------------------------
//	qdpi.v
//	Compatibility wrapper for qspi.v
// -----------------------------------------------------------------------------

module qdpi (
	input			reset,
	input			clk,
	input			clk_serial,
	input	[2:0]	serial_mode,
	input	[7:0]	serial_wdata,
	input			serial_write,
	input			serial_valid,
	output			serial_ready,
	output	[7:0]	serial_rdata,
	output			serial_rdata_en,
	output			serial_idle,
	output			qspi_clk,
	inout	[3:0]	qspi_sio
);
	qspi u_qspi (
		.reset				( reset				),
		.clk				( clk					),
		.clk_serial			( clk_serial			),
		.serial_mode		( serial_mode			),
		.serial_wdata		( serial_wdata			),
		.serial_write		( serial_write			),
		.serial_valid		( serial_valid			),
		.serial_ready		( serial_ready			),
		.serial_rdata		( serial_rdata			),
		.serial_rdata_en	( serial_rdata_en		),
		.serial_idle		( serial_idle			),
		.qspi_clk			( qspi_clk				),
		.qspi_sio			( qspi_sio				)
	);
endmodule
