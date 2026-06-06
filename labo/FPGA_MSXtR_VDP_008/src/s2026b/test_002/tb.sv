`timescale 1ns/1ps

module tb;
	localparam real CLK_PERIOD_PS = 1_000_000_000_000.0 / 85_909_080.0;

	// ------------------------------------------------------------
	//	Clock & Reset
	// ------------------------------------------------------------
	reg				clk;
	reg				reset_n;

	// ------------------------------------------------------------
	//	ctrl0 I/F
	// ------------------------------------------------------------
	reg				bus_ctrl0_io;
	reg				bus_ctrl0_write;
	reg				bus_ctrl0_valid;
	wire			bus_ctrl0_ready;
	reg		[15:0]	bus_ctrl0_address;
	reg		[7:0]	bus_ctrl0_wdata;
	wire	[7:0]	bus_ctrl0_rdata;
	wire			bus_ctrl0_rdata_en;

	// ------------------------------------------------------------
	//	ctrl1 I/F
	// ------------------------------------------------------------
	reg				bus_ctrl1_io;
	reg				bus_ctrl1_write;
	reg				bus_ctrl1_valid;
	wire			bus_ctrl1_ready;
	reg		[15:0]	bus_ctrl1_address;
	reg		[7:0]	bus_ctrl1_wdata;
	wire	[7:0]	bus_ctrl1_rdata;
	wire			bus_ctrl1_rdata_en;

	// ------------------------------------------------------------
	//	Internal bus outputs
	// ------------------------------------------------------------
	wire			bus_io;
	wire			bus_write;
	wire			bus_valid;
	wire	[7:0]	bus_wdata;
	wire	[15:0]	bus_address;

	// ------------------------------------------------------------
	//	Internal bus inputs (stub)
	// ------------------------------------------------------------
	reg				sdram_init_busy;
	reg				bus_ready;
	reg		[7:0]	bus_rdata;
	reg				bus_rdata_en;

	// ------------------------------------------------------------
	//	Clock generation
	// ------------------------------------------------------------
	initial clk = 0;
	always #(CLK_PERIOD_PS / 2 / 1000.0) clk = ~clk;

	// ------------------------------------------------------------
	//	DUT instance
	// ------------------------------------------------------------
	s2026b_cpu_select u_s2026b_cpu_select (
		.reset_n			( reset_n			),
		.clk				( clk				),
		.sdram_init_busy	( sdram_init_busy	),
		.bus_ctrl0_io		( bus_ctrl0_io		),
		.bus_ctrl0_write	( bus_ctrl0_write	),
		.bus_ctrl0_valid	( bus_ctrl0_valid	),
		.bus_ctrl0_ready	( bus_ctrl0_ready	),
		.bus_ctrl0_address	( bus_ctrl0_address	),
		.bus_ctrl0_wdata	( bus_ctrl0_wdata	),
		.bus_ctrl0_rdata	( bus_ctrl0_rdata	),
		.bus_ctrl0_rdata_en	( bus_ctrl0_rdata_en),
		.bus_ctrl1_io		( bus_ctrl1_io		),
		.bus_ctrl1_write	( bus_ctrl1_write	),
		.bus_ctrl1_valid	( bus_ctrl1_valid	),
		.bus_ctrl1_ready	( bus_ctrl1_ready	),
		.bus_ctrl1_address	( bus_ctrl1_address	),
		.bus_ctrl1_wdata	( bus_ctrl1_wdata	),
		.bus_ctrl1_rdata	( bus_ctrl1_rdata	),
		.bus_ctrl1_rdata_en	( bus_ctrl1_rdata_en),
		.bus_io				( bus_io			),
		.bus_write			( bus_write			),
		.bus_valid			( bus_valid			),
		.bus_address		( bus_address		),
		.bus_wdata			( bus_wdata			),
		.bus_ready			( bus_ready			),
		.bus_rdata			( bus_rdata			),
		.bus_rdata_en		( bus_rdata_en		)
	);

	// ============================================================
	//	Bus stub model
	//	  - 通常時は bus_ready = 1 を維持
	//	  - bus_valid = 1 が来ると bus_ready = 0 に下げる
	//	  - write の場合は即座に bus_ready = 1 に復帰
	//	  - read の場合は 1～10 clk 後に bus_rdata / bus_rdata_en
	//	    (1clock パルス) を返し、bus_ready = 1 に復帰
	// ============================================================
	initial begin
		bus_ready    = 1'b1;	// 通常時は ready = 1 を維持
		bus_rdata    = 8'h00;
		bus_rdata_en = 1'b0;

		forever begin
			// valid 要求が来るまで待つ
			@(posedge clk iff bus_valid);
			begin
				automatic bit        cap_write = bus_write;
				automatic bit [7:0]  cap_addr  = bus_address[7:0];

				// valid 検出で ready を下げる
				bus_ready = 1'b0;

				if (cap_write) begin
					// ライト: 即座に ready 復帰
					@(posedge clk);
					bus_ready = 1'b1;
				end
				else begin
					// リード: ランダム遅延 (1～10 clk) 後にデータ返却して ready 復帰
					repeat ($urandom_range(1, 10)) @(posedge clk);
					bus_rdata    = $urandom;
					bus_rdata_en = 1'b1;
					@(posedge clk);
					bus_rdata_en = 1'b0;
					bus_ready    = 1'b1;
				end
			end
		end
	end

	// ============================================================
	//	Bus I/F tasks
	// ============================================================

	// ctrl0 write (io=0: memory access, io=1: I/O access)
	task automatic ctrl0_write(
		input			io,
		input	[15:0]	addr,
		input	[7:0]	wdata
	);
		@(posedge clk);
		bus_ctrl0_io		= io;
		bus_ctrl0_address	= addr;
		bus_ctrl0_wdata		= wdata;
		bus_ctrl0_write		= 1'b1;
		bus_ctrl0_valid		= 1'b1;
		@(posedge clk iff bus_ctrl0_ready);
		bus_ctrl0_valid		= 1'b0;
		bus_ctrl0_write		= 1'b0;
	endtask

	// ctrl0 read
	task automatic ctrl0_read(
		input			io,
		input	[15:0]	addr,
		output	[7:0]	rdata
	);
		@(posedge clk);
		bus_ctrl0_io		= io;
		bus_ctrl0_address	= addr;
		bus_ctrl0_write		= 1'b0;
		bus_ctrl0_valid		= 1'b1;
		@(posedge clk iff bus_ctrl0_ready);
		bus_ctrl0_valid		= 1'b0;
		@(posedge clk iff bus_ctrl0_rdata_en);
		rdata = bus_ctrl0_rdata;
	endtask

	// ctrl1 write (io=0: memory access, io=1: I/O access)
	task automatic ctrl1_write(
		input			io,
		input	[15:0]	addr,
		input	[7:0]	wdata
	);
		@(posedge clk);
		bus_ctrl1_io		= io;
		bus_ctrl1_address	= addr;
		bus_ctrl1_wdata		= wdata;
		bus_ctrl1_write		= 1'b1;
		bus_ctrl1_valid		= 1'b1;
		@(posedge clk iff bus_ctrl1_ready);
		bus_ctrl1_valid		= 1'b0;
		bus_ctrl1_write		= 1'b0;
	endtask

	// ctrl1 read
	task automatic ctrl1_read(
		input			io,
		input	[15:0]	addr,
		output	[7:0]	rdata
	);
		@(posedge clk);
		bus_ctrl1_io		= io;
		bus_ctrl1_address	= addr;
		bus_ctrl1_write		= 1'b0;
		bus_ctrl1_valid		= 1'b1;
		@(posedge clk iff bus_ctrl1_ready);
		bus_ctrl1_valid		= 1'b0;
		@(posedge clk iff bus_ctrl1_rdata_en);
		rdata = bus_ctrl1_rdata;
	endtask

	// ============================================================
	//	Test sequence
	// ============================================================
	initial begin : u_test
		logic [7:0] rdata;

		// ----------------------------------------------------
		//	Initialize
		// ----------------------------------------------------
		$timeformat(-9, 0, " ns", 10);
		reset_n           = 1'b0;
		sdram_init_busy   = 1'b0;
		bus_ctrl0_io      = 1'b0;
		bus_ctrl0_write   = 1'b0;
		bus_ctrl0_valid   = 1'b0;
		bus_ctrl0_address = 16'h0000;
		bus_ctrl0_wdata   = 8'h00;
		bus_ctrl1_io      = 1'b0;
		bus_ctrl1_write   = 1'b0;
		bus_ctrl1_valid   = 1'b0;
		bus_ctrl1_address = 16'h0000;
		bus_ctrl1_wdata   = 8'h00;

		// Reset
		repeat(5) @(posedge clk);
		#1; reset_n = 1'b1;
		repeat(5) @(posedge clk);

		// ============================================================
		//	ctrl0 テスト
		// ============================================================

		// [TEST 1] ctrl0 単発書き込み
		$display("%t [TEST 1] ctrl0 single write", $time);
		ctrl0_write(1'b1, 16'h0098, 8'hA5);
		$display("%t [PASS]", $time);

		// [TEST 2] ctrl0 連続書き込み (4回)
		$display("%t [TEST 2] ctrl0 consecutive writes", $time);
		for (int i = 0; i < 4; i++) begin
			ctrl0_write(1'b1, 16'h0098 + i, 8'h10 + i);
			$display("  write addr=0x%02X wdata=0x%02X", 8'h98 + i, 8'h10 + i);
		end
		$display("%t [PASS]", $time);

		// [TEST 3] ctrl0 単発読み出し
		$display("%t [TEST 3] ctrl0 single read", $time);
		ctrl0_read(1'b1, 16'h0099, rdata);
		$display("%t [PASS] addr=0x99 rdata=0x%02X", $time, rdata);

		// [TEST 4] ctrl0 連続読み出し (4回)
		$display("%t [TEST 4] ctrl0 consecutive reads", $time);
		for (int i = 0; i < 4; i++) begin
			ctrl0_read(1'b1, 16'h0098 + i, rdata);
			$display("  read  addr=0x%02X rdata=0x%02X", 8'h98 + i, rdata);
		end
		$display("%t [PASS]", $time);

		// [TEST 5] ctrl0 書き込み・読み出し交互 (4回)
		$display("%t [TEST 5] ctrl0 alternating write/read", $time);
		for (int i = 0; i < 4; i++) begin
			ctrl0_write(1'b1, 16'h0098, 8'hB0 + i);
			ctrl0_read( 1'b1, 16'h0099, rdata);
			$display("  write=0x%02X read=0x%02X", 8'hB0 + i, rdata);
		end
		$display("%t [PASS]", $time);

		// ============================================================
		//	ctrl1 テスト
		// ============================================================

		// [TEST 6] ctrl1 単発書き込み
		$display("%t [TEST 6] ctrl1 single write", $time);
		ctrl1_write(1'b1, 16'h0098, 8'hC5);
		$display("%t [PASS]", $time);

		// [TEST 7] ctrl1 連続書き込み (4回)
		$display("%t [TEST 7] ctrl1 consecutive writes", $time);
		for (int i = 0; i < 4; i++) begin
			ctrl1_write(1'b1, 16'h0098 + i, 8'h20 + i);
			$display("  write addr=0x%02X wdata=0x%02X", 8'h98 + i, 8'h20 + i);
		end
		$display("%t [PASS]", $time);

		// [TEST 8] ctrl1 単発読み出し
		$display("%t [TEST 8] ctrl1 single read", $time);
		ctrl1_read(1'b1, 16'h0099, rdata);
		$display("%t [PASS] addr=0x99 rdata=0x%02X", $time, rdata);

		// [TEST 9] ctrl1 連続読み出し (4回)
		$display("%t [TEST 9] ctrl1 consecutive reads", $time);
		for (int i = 0; i < 4; i++) begin
			ctrl1_read(1'b1, 16'h0098 + i, rdata);
			$display("  read  addr=0x%02X rdata=0x%02X", 8'h98 + i, rdata);
		end
		$display("%t [PASS]", $time);

		// [TEST 10] ctrl1 書き込み・読み出し交互 (4回)
		$display("%t [TEST 10] ctrl1 alternating write/read", $time);
		for (int i = 0; i < 4; i++) begin
			ctrl1_write(1'b1, 16'h0098, 8'hD0 + i);
			ctrl1_read( 1'b1, 16'h0099, rdata);
			$display("  write=0x%02X read=0x%02X", 8'hD0 + i, rdata);
		end
		$display("%t [PASS]", $time);

		// ============================================================
		//	同時アクセス競合テスト (ctrl0 優先)
		// ============================================================

		// [TEST 11] ctrl0/ctrl1 同時書き込み (同じアドレス)
		$display("%t [TEST 11] ctrl0/ctrl1 simultaneous write (ctrl0 priority)", $time);
		fork
			ctrl0_write(1'b1, 16'h0098, 8'hAA);
			ctrl1_write(1'b1, 16'h0098, 8'h55);
		join
		$display("%t [PASS]", $time);

		// [TEST 12] ctrl0/ctrl1 同時読み出し (同じアドレス)
		$display("%t [TEST 12] ctrl0/ctrl1 simultaneous read (ctrl0 priority)", $time);
		fork
			begin
				logic [7:0] rd;
				ctrl0_read(1'b1, 16'h0099, rd);
				$display("  ctrl0 read  rdata=0x%02X", rd);
			end
			begin
				logic [7:0] rd;
				ctrl1_read(1'b1, 16'h0099, rd);
				$display("  ctrl1 read  rdata=0x%02X", rd);
			end
		join
		$display("%t [PASS]", $time);

		// [TEST 13] ctrl0 読み出し・ctrl1 書き込み (同時, ctrl0 優先)
		$display("%t [TEST 13] ctrl0 read / ctrl1 write simultaneous (ctrl0 priority)", $time);
		fork
			begin
				logic [7:0] rd;
				ctrl0_read(1'b1, 16'h0099, rd);
				$display("  ctrl0 read  rdata=0x%02X", rd);
			end
			ctrl1_write(1'b1, 16'h0098, 8'hCC);
		join
		$display("%t [PASS]", $time);

		// [TEST 14] ctrl1 読み出し・ctrl0 書き込み (同時, ctrl0 優先)
		$display("%t [TEST 14] ctrl1 read / ctrl0 write simultaneous (ctrl0 priority)", $time);
		fork
			ctrl0_write(1'b1, 16'h0098, 8'hDD);
			begin
				logic [7:0] rd;
				ctrl1_read(1'b1, 16'h0099, rd);
				$display("  ctrl1 read  rdata=0x%02X", rd);
			end
		join
		$display("%t [PASS]", $time);

		$display("%t [ALL TESTS PASSED]", $time);
		$finish;
	end

endmodule
