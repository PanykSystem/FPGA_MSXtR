`timescale 1ns/1ps

module tb;
	reg			reset_n;
	reg			clk_42m;
	reg			clk_215m;
	reg			bus_m1;
	reg	[15:0]	bus_address;
	reg			bus_io;
	reg			bus_write;
	reg			bus_valid;
	wire			bus_ready;
	reg	[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;
	reg	[7:0]	primary_slot;
	reg	[7:0]	secondary_slot;
	reg			high_speed_mode;
	wire			int_n;
	wire			slot_m1_n;
	wire			slot_oe_n;
	wire			slot_clock_n;
	wire			slot_sltsl0_n;
	wire			slot_sltsl1_n;
	wire			slot_sltsl2_n;
	wire			slot_sltsl3_n;
	wire			slot_cs1_n;
	wire			slot_cs2_n;
	wire			slot_cs12_n;
	wire	[18:0]	slot_a;
	reg			slot_int_n;
	reg			slot_wait_n;
	wire			slot_reset_n;
	reg			slot_busdir;
	wire			slot_data_dir;
	wire			slot_wr_n;
	wire			slot_rd_n;
	wire			slot_rom0_ce_n;
	wire			slot_rom1_ce_n;
	wire			slot_rfsh_n;
	wire			slot_iorq_n;
	wire			slot_merq_n;
	wire	[7:0]	slot_d;
	reg			slot_d_drive;
	reg	[7:0]	slot_d_rdata;
	reg	[18:0]	frozen_a;
	reg			frozen_sltsl2_n;
	reg			frozen_cs2_n;
	real		clock_period;
	real		clock_t_prev;
	integer		clock_idle_i;
	reg	[15:0]	frozen_snapshot;
	integer		long_wait_toggle_count;
	reg	[7:0]	refresh_addr_1;
	reg	[7:0]	refresh_addr_2;
	reg	[7:0]	refresh_addr_3;
	real		m1_time_start;
	real		m1_time_normal;
	real		m1_time_highspeed;

	assign slot_d = slot_d_drive ? slot_d_rdata : 8'hzz;

	msx_slot u_msx_slot (
		.reset_n				( reset_n			),
		.clk_42m				( clk_42m			),
		.clk_215m				( clk_215m			),
		.bus_m1					( bus_m1			),
		.bus_address			( bus_address		),
		.bus_io					( bus_io				),
		.bus_write				( bus_write			),
		.bus_valid				( bus_valid			),
		.bus_ready				( bus_ready			),
		.bus_wdata				( bus_wdata			),
		.bus_rdata				( bus_rdata			),
		.bus_rdata_en			( bus_rdata_en		),
		.primary_slot			( primary_slot		),
		.secondary_slot			( secondary_slot	),
		.high_speed_mode		( high_speed_mode	),
		.int_n					( int_n				),
		.slot_m1_n				( slot_m1_n			),
		.slot_oe_n				( slot_oe_n			),
		.slot_clock_n			( slot_clock_n		),
		.slot_sltsl0_n			( slot_sltsl0_n		),
		.slot_sltsl1_n			( slot_sltsl1_n		),
		.slot_sltsl2_n			( slot_sltsl2_n		),
		.slot_sltsl3_n			( slot_sltsl3_n		),
		.slot_cs1_n				( slot_cs1_n		),
		.slot_cs2_n				( slot_cs2_n		),
		.slot_cs12_n			( slot_cs12_n		),
		.slot_a					( slot_a			),
		.slot_int_n				( slot_int_n		),
		.slot_wait_n			( slot_wait_n		),
		.slot_reset_n			( slot_reset_n		),
		.slot_busdir			( slot_busdir		),
		.slot_data_dir			( slot_data_dir		),
		.slot_wr_n				( slot_wr_n			),
		.slot_rd_n				( slot_rd_n			),
		.slot_rom0_ce_n			( slot_rom0_ce_n	),
		.slot_rom1_ce_n			( slot_rom1_ce_n	),
		.slot_rfsh_n			( slot_rfsh_n		),
		.slot_iorq_n			( slot_iorq_n		),
		.slot_merq_n			( slot_merq_n		),
		.slot_d					( slot_d			)
	);

	initial begin
		clk_42m = 1'b0;
		forever #11.641 clk_42m = ~clk_42m;
	end

	initial begin
		clk_215m = 1'b0;
		forever #2.328 clk_215m = ~clk_215m;
	end

	task check;
		input		condition;
		input [255:0]	message;
		begin
			if( !condition ) begin
				$display("ERROR: %0s", message);
				$stop;
			end
		end
	endtask

	task issue_access;
		input			access_m1;
		input			access_io;
		input			access_write;
		input [15:0]	access_address;
		input [7:0]	access_wdata;
		begin
			@( posedge clk_42m );
			bus_m1			<= access_m1;
			bus_io			<= access_io;
			bus_write		<= access_write;
			bus_address		<= access_address;
			bus_wdata		<= access_wdata;
			bus_valid		<= 1'b1;
			@( posedge clk_42m );
			@( negedge clk_42m );
			check( bus_ready == 1'b0, "bus_ready did not drop after request acceptance" );
			bus_valid		<= 1'b0;
		end
	endtask

	task wait_ready;
		begin
			while( bus_ready == 1'b0 ) begin
				@( posedge clk_42m );
			end
		end
	endtask

	initial begin
		reset_n				= 1'b0;
		bus_m1				= 1'b0;
		bus_address			= 16'd0;
		bus_io				= 1'b0;
		bus_write			= 1'b0;
		bus_valid			= 1'b0;
		bus_wdata			= 8'd0;
		primary_slot		= 8'he4;	//	page0->slot0, page1->slot1, page2->slot2, page3->slot3
		secondary_slot		= 8'h00;
		high_speed_mode		= 1'b0;
		slot_int_n			= 1'b1;
		slot_wait_n			= 1'b1;
		slot_busdir			= 1'b0;
		slot_d_drive		= 1'b0;
		slot_d_rdata		= 8'h00;
		repeat( 8 ) @( posedge clk_42m );
		reset_n				= 1'b1;
		repeat( 8 ) @( posedge clk_42m );

		check( bus_ready == 1'b1, "bus_ready was not idle high" );
		check( slot_reset_n == 1'b1, "slot_reset_n did not follow reset_n" );
		check( slot_oe_n == 1'b0, "slot_oe_n is not fixed low" );

		//	bus_valid=0 を 約3us 継続しても slot_clock_n (3.579545MHz 相当) が乱れずに出ることを確認
		check( bus_valid == 1'b0, "bus_valid must stay low for clock idle check" );
		@( posedge slot_clock_n );
		clock_t_prev	= $realtime;
		for( clock_idle_i = 0; clock_idle_i < 12; clock_idle_i = clock_idle_i + 1 ) begin
			@( posedge slot_clock_n );
			clock_period	= $realtime - clock_t_prev;
			check( (clock_period > 278.0) && (clock_period < 281.0), "slot_clock_n period disturbed while bus_valid=0" );
			check( bus_ready == 1'b1, "bus_ready dropped while bus_valid=0" );
			clock_t_prev	= $realtime;
		end

		slot_d_drive	= 1'b1;
		slot_d_rdata	= 8'ha5;
		issue_access( 1'b0, 1'b0, 1'b0, 16'h4000, 8'h00 );
		@( negedge slot_rd_n );
		check( slot_a == 19'h04000, "memory read address mismatch" );
		check( slot_merq_n == 1'b0, "memory read did not assert MERQ" );
		check( slot_iorq_n == 1'b1, "memory read asserted IORQ" );
		check( slot_sltsl1_n == 1'b0, "memory read did not assert SLTSL1" );
		check( slot_cs1_n == 1'b0, "memory read did not assert CS1" );
		check( slot_cs12_n == 1'b0, "memory read did not assert CS12" );
		@( posedge bus_rdata_en );
		check( bus_rdata == 8'ha5, "memory read data mismatch" );
		wait_ready();
		slot_d_drive	= 1'b0;

		//	SLOT#0/SLOT#3 の ROM マッピング(readme.md の ROM マップに準拠)
		primary_slot	= 8'h00;		//	全ページを SLOT#0 に
		secondary_slot	= 8'h00;		//	全ページを SLOT#0-0 に
		slot_d_drive	= 1'b1;
		slot_d_rdata	= 8'hd1;
		issue_access( 1'b0, 1'b0, 1'b0, 16'h0000, 8'h00 );
		@( negedge slot_rd_n );
		check( slot_rom0_ce_n == 1'b0, "SLOT#0-0 page0 did not assert ROM0 CE" );
		check( slot_rom1_ce_n == 1'b1, "SLOT#0-0 page0 asserted ROM1 CE" );
		check( slot_a == 19'h00000, "SLOT#0-0 page0 (MAIN-ROM前半) address mismatch" );
		@( posedge bus_rdata_en );
		check( bus_rdata == 8'hd1, "SLOT#0-0 page0 read data mismatch" );
		wait_ready();

		issue_access( 1'b0, 1'b0, 1'b0, 16'h4000, 8'h00 );
		@( negedge slot_rd_n );
		check( slot_rom0_ce_n == 1'b0, "SLOT#0-0 page1 did not assert ROM0 CE" );
		check( slot_a == 19'h04000, "SLOT#0-0 page1 (MAIN-ROM後半) address mismatch" );
		wait_ready();

		secondary_slot	= 8'b00_00_00_01;	//	page0 のみ SLOT#0-1 に
		issue_access( 1'b0, 1'b0, 1'b0, 16'h0000, 8'h00 );
		@( negedge slot_rd_n );
		check( slot_rom0_ce_n == 1'b0, "SLOT#0-1 page0 did not assert ROM0 CE" );
		check( slot_a == 19'h08000, "SLOT#0-1 page0 (Option-ROM0) address mismatch" );
		wait_ready();
		slot_d_drive	= 1'b0;

		primary_slot	= 8'b00_00_11_00;	//	page1 のみ SLOT#3 に
		secondary_slot	= 8'b00_00_01_00;	//	page1 の SLOT#3-1
		slot_d_drive	= 1'b1;
		slot_d_rdata	= 8'he2;
		issue_access( 1'b0, 1'b0, 1'b0, 16'h4000, 8'h00 );
		@( negedge slot_rd_n );
		check( slot_rom0_ce_n == 1'b0, "SLOT#3-1 page1 did not assert ROM0 CE" );
		check( slot_a == 19'h24000, "SLOT#3-1 page1 (KanjiDriver0) address mismatch" );
		@( posedge bus_rdata_en );
		check( bus_rdata == 8'he2, "SLOT#3-1 page1 read data mismatch" );
		wait_ready();
		slot_d_drive	= 1'b0;

		//	元のリモートスロット構成に戻す
		primary_slot	= 8'he4;
		secondary_slot	= 8'h00;

		//	bus_io=1 write
		issue_access( 1'b0, 1'b1, 1'b1, 16'h00a8, 8'hc3 );
		@( negedge slot_wr_n );
		check( slot_iorq_n == 1'b0, "I/O write did not assert IORQ" );
		check( slot_merq_n == 1'b1, "I/O write asserted MERQ" );
		check( slot_m1_n == 1'b1, "I/O write asserted M1" );
		check( slot_sltsl0_n == 1'b1, "I/O write asserted SLTSL0" );
		check( slot_cs1_n == 1'b1, "I/O write asserted CS1" );
		check( slot_cs2_n == 1'b1, "I/O write asserted CS2" );
		wait_ready();

		//	bus_io=1 read
		slot_d_drive	= 1'b1;
		slot_d_rdata	= 8'h7e;
		issue_access( 1'b0, 1'b1, 1'b0, 16'h00a8, 8'h00 );
		@( negedge slot_rd_n );
		check( slot_iorq_n == 1'b0, "I/O read did not assert IORQ" );
		check( slot_merq_n == 1'b1, "I/O read asserted MERQ" );
		check( slot_m1_n == 1'b1, "I/O read asserted M1" );
		@( posedge bus_rdata_en );
		check( bus_rdata == 8'h7e, "I/O read data mismatch" );
		wait_ready();
		slot_d_drive	= 1'b0;

		//	bus_m1=1 (命令フェッチ) は必ず bus_io=0, bus_write=0 のメモリ読み出し
		slot_d_drive	= 1'b1;
		slot_d_rdata	= 8'h3e;
		m1_time_start	= $realtime;
		issue_access( 1'b1, 1'b0, 1'b0, 16'h0000, 8'h00 );
		@( negedge slot_m1_n );
		check( slot_iorq_n == 1'b1, "M1 access asserted IORQ" );
		check( slot_merq_n == 1'b0, "M1 access did not assert MERQ" );
		check( slot_rfsh_n == 1'b0, "M1 access did not assert RFSH" );
		@( negedge slot_rd_n );
		check( slot_a == 19'h00000, "M1 access address mismatch" );
		@( posedge bus_rdata_en );
		check( bus_rdata == 8'h3e, "M1 access data mismatch" );
		m1_time_normal	= $realtime - m1_time_start;
		wait_ready();
		slot_d_drive	= 1'b0;

		//	内部/外部 /WAIT 中は bus_ready=0 と slot_* 出力が固定されることを確認
		slot_d_drive	= 1'b1;
		slot_d_rdata	= 8'h81;
		slot_wait_n		= 1'b0;
		issue_access( 1'b0, 1'b0, 1'b0, 16'h8000, 8'h00 );
		repeat( 40 ) @( posedge clk_215m );
		check( bus_ready == 1'b0, "bus_ready released during external WAIT" );
		frozen_a		= slot_a;
		frozen_sltsl2_n	= slot_sltsl2_n;
		frozen_cs2_n	= slot_cs2_n;
		repeat( 40 ) @( posedge clk_215m );
		check( bus_ready == 1'b0, "bus_ready released while WAIT still held" );
		check( slot_a == frozen_a, "slot_a changed while frozen" );
		check( slot_sltsl2_n == frozen_sltsl2_n, "slot_sltsl2_n changed while frozen" );
		check( slot_cs2_n == frozen_cs2_n, "slot_cs2_n changed while frozen" );
		slot_wait_n		= 1'b1;
		@( posedge bus_rdata_en );
		check( bus_rdata == 8'h81, "external WAIT read data mismatch" );
		wait_ready();
		slot_d_drive	= 1'b0;

		//	slot_wait_n が約1us継続してLになっても、slot_clock_n 以外の全信号が停止し続けることを確認
		slot_d_drive	= 1'b1;
		slot_d_rdata	= 8'h5b;
		slot_wait_n		= 1'b0;
		long_wait_toggle_count	= 0;
		issue_access( 1'b0, 1'b0, 1'b0, 16'h4000, 8'h00 );
		@( posedge u_msx_slot.ff_busy_215m );
		@( posedge clk_215m );
		check( bus_ready == 1'b0, "bus_ready released before long external WAIT check" );
		frozen_a		= slot_a;
		frozen_snapshot	= { slot_sltsl0_n, slot_sltsl1_n, slot_sltsl2_n, slot_sltsl3_n,
							slot_cs1_n, slot_cs2_n, slot_cs12_n, slot_rd_n, slot_wr_n,
							slot_merq_n, slot_iorq_n, slot_rfsh_n, slot_m1_n,
							slot_data_dir, slot_rom0_ce_n, slot_rom1_ce_n };
		fork
			begin : long_wait_clock_count
				forever begin
					@( posedge slot_clock_n );
					long_wait_toggle_count = long_wait_toggle_count + 1;
				end
			end
		join_none
		#1000;
		disable long_wait_clock_count;
		check( bus_ready == 1'b0, "bus_ready released during long external WAIT" );
		check( slot_a == frozen_a, "slot_a changed during long external WAIT" );
		check( { slot_sltsl0_n, slot_sltsl1_n, slot_sltsl2_n, slot_sltsl3_n,
				 slot_cs1_n, slot_cs2_n, slot_cs12_n, slot_rd_n, slot_wr_n,
				 slot_merq_n, slot_iorq_n, slot_rfsh_n, slot_m1_n,
				 slot_data_dir, slot_rom0_ce_n, slot_rom1_ce_n } == frozen_snapshot,
			   "slot_* outputs changed during long external WAIT" );
		check( long_wait_toggle_count >= 3, "slot_clock_n stopped toggling during long external WAIT" );
		slot_wait_n		= 1'b1;
		@( posedge bus_rdata_en );
		check( bus_rdata == 8'h5b, "long external WAIT read data mismatch" );
		wait_ready();
		slot_d_drive	= 1'b0;

		//	high_speed_mode=0: bus_valid が来ないまま約1ms経過したら、リフレッシュ専用の slot_rfsh_n パルスが自動で出ることを確認
		@( negedge slot_rfsh_n );
		check( slot_merq_n == 1'b0, "idle refresh did not assert MERQ" );
		check( slot_m1_n == 1'b1, "idle refresh incorrectly asserted M1" );
		check( slot_iorq_n == 1'b1, "idle refresh incorrectly asserted IORQ" );
		check( slot_sltsl1_n == 1'b1, "idle refresh incorrectly asserted SLTSL1" );
		check( slot_a[15:8] == 8'h00, "idle refresh upper address not fixed to 0" );
		check( bus_ready == 1'b1, "bus_ready dropped during idle refresh" );
		refresh_addr_1	= slot_a[7:0];
		@( posedge slot_rfsh_n );
		check( bus_ready == 1'b1, "bus_ready dropped after idle refresh completed" );

		//	2回目のリフレッシュでアドレスカウンタがインクリメントされることを確認
		@( negedge slot_rfsh_n );
		refresh_addr_2	= slot_a[7:0];
		check( refresh_addr_2 == (refresh_addr_1 + 8'd1), "refresh counter did not increment" );
		@( posedge slot_rfsh_n );

		//	high_speed_mode=1: 内部 /WAIT を常に1のままにして M1 の TW ステート挿入を行わない
		high_speed_mode	= 1'b1;
		slot_d_drive	= 1'b1;
		slot_d_rdata	= 8'h6c;
		m1_time_start	= $realtime;
		issue_access( 1'b1, 1'b0, 1'b0, 16'h0000, 8'h00 );
		@( negedge slot_m1_n );
		check( slot_rfsh_n == 1'b1, "high_speed_mode asserted RFSH on M1 access" );
		@( negedge slot_rd_n );
		check( slot_rfsh_n == 1'b1, "high_speed_mode asserted RFSH during M1 strobe" );
		@( posedge bus_rdata_en );
		check( bus_rdata == 8'h6c, "high_speed_mode M1 access data mismatch" );
		m1_time_highspeed	= $realtime - m1_time_start;
		wait_ready();
		slot_d_drive	= 1'b0;
		check( m1_time_highspeed < (m1_time_normal - 200.0), "high_speed_mode did not skip the internal M1 wait" );

		//	high_speed_mode=1 でも約1ms経過したらリフレッシュカウンタが継続してインクリメントされることを確認
		@( negedge slot_rfsh_n );
		check( slot_merq_n == 1'b0, "high_speed_mode idle refresh did not assert MERQ" );
		check( slot_m1_n == 1'b1, "high_speed_mode idle refresh incorrectly asserted M1" );
		check( slot_a[15:8] == 8'h00, "high_speed_mode idle refresh upper address not fixed to 0" );
		refresh_addr_3	= slot_a[7:0];
		check( refresh_addr_3 == (refresh_addr_2 + 8'd1), "high_speed_mode refresh counter did not continue incrementing" );
		check( bus_ready == 1'b1, "bus_ready dropped during high_speed_mode idle refresh" );
		@( posedge slot_rfsh_n );

		$display("OK");
		$finish;
	end
endmodule