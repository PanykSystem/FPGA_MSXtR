//
// config_rom.v
//
//	Copyright (C) 2026 Takayuki Hara
//
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
//-----------------------------------------------------------------------------

module config_rom (
	input			reset_n,
	input			clk,
	input			clk_serial,
	//	internal bus interface
	input			bus_cs,				//	chip select
	input	[3:0]	bus_address,		//	0: register addresss port, 1: register data port
	input			bus_write,			//	read write direction (0: read, 1: write)
	input			bus_valid,			//	access valid signal
	output			bus_ready,			//	access ready signal
	input	[7:0]	bus_wdata,			//	write data
	output	[7:0]	bus_rdata,			//	read data
	output			bus_rdata_en,		//	read enable signal
	//	serial ROM interface
	output			flash_spi_cs_n,		//	MSPI_CS
	output			flash_spi_ck,		//	MSPI_CLK
	inout			flash_spi_hold_n,	//	MSPI_HOLD
	inout			flash_spi_wp_n,		//	MSPI_WP
	inout			flash_spi_do,		//	MSPI_DO
	inout			flash_spi_di		//	MSPI_DI
);
	reg				ff_extio_en;
	reg				ff_device_en;
	reg		[7:0]	ff_rdata;
	reg				ff_rdata_en;
	reg				ff_bus_ready;
	wire			w_bus_ready;
	wire			w_bus_cs;
	wire	[7:0]	w_bus_rdata;
	wire			w_bus_rdata_en;

	always @( posedge clk ) begin
		if ( ~reset_n ) begin
			ff_extio_en		<= 1'b0;
			ff_device_en	<= 1'b0;
			ff_rdata		<= 8'd0;
			ff_rdata_en		<= 1'b0;
			ff_bus_ready	<= 1'b1;
		end
		else begin
			if ( bus_cs && bus_valid ) begin
				if( bus_write ) begin
					//	書き込みアクセス
					case ( bus_address )
						4'd0: begin
							//	40h: external I/O enable
							if( bus_wdata == 8'd64 ) begin
								ff_extio_en	<= 1'b1;
							end
							else begin
								ff_extio_en	<= 1'b0;
							end
							ff_bus_ready	<= 1'b1;
						end
						4'd1: begin
							//	41h: device enable
							if( ff_extio_en ) begin
								if( bus_wdata == 8'd01 ) begin
									ff_device_en	<= 1'b1;
								end
								else begin
									ff_device_en	<= 1'b0;
								end
							end
							else begin
								//	hold
							end
							ff_bus_ready	<= 1'b1;
						end
						4'd2, 4'd3: begin
							//	42h, 43h: QPI ROM access
							if( ff_extio_en && ff_device_en ) begin
								ff_bus_ready	<= 1'b1;
							end
							else begin
								ff_bus_ready	<= 1'b1;
							end
						end
					default: begin
						end
					endcase
					ff_rdata_en		<= 1'b0;
				end
				else begin
					//	読み込みアクセス
					case( bus_address )
						4'd0: begin
							//	40h: external I/O enable
							if( ff_extio_en ) begin
								ff_rdata		<= ~8'd64;
								ff_rdata_en		<= 1'b1;
								ff_bus_ready	<= 1'b0;
							end
							else begin
								ff_rdata		<= 8'hFF;
								ff_rdata_en		<= 1'b0;		//	invalid
								ff_bus_ready	<= 1'b1;
							end
						end
						4'd1: begin
							//	41h: device enable
							if( ff_device_en ) begin
								ff_rdata		<= ~8'd01;
								ff_rdata_en		<= 1'b1;
								ff_bus_ready	<= 1'b0;
							end
							else begin
								ff_rdata		<= 8'hFF;
								ff_rdata_en		<= 1'b0;		//	invalid
								ff_bus_ready	<= 1'b1;
							end
						end
						default: begin
							ff_rdata		<= 8'hFF;
							ff_rdata_en		<= 1'b0;		//	invalid
							ff_bus_ready	<= 1'b1;
						end
					endcase
				end
			end
			else begin
				ff_rdata_en		<= 1'b0;
				ff_bus_ready	<= 1'b1;
			end
		end
	end

	ip_qspi_rom u_config_rom (
		.reset				( ~reset_n															),		//	System Reset (Active High)
		.clk				( clk																),		//	System Clock
		.clk_serial			( clk_serial														),		//	Serial Clock (High speed)
		.bus_cs				( w_bus_cs															),
		.bus_address		( bus_address[0]													),
		.bus_write			( bus_write															),
		.bus_valid			( bus_valid															),
		.bus_ready			( w_bus_ready														),
		.bus_wdata			( bus_wdata															),
		.bus_rdata			( w_bus_rdata														),
		.bus_rdata_en		( w_bus_rdata_en													),
		.srom0_cs_n			( 																	),
		.srom1_cs_n			( flash_spi_cs_n													),
		.srom_clk			( flash_spi_ck														),
		.srom_sio			( {flash_spi_hold_n, flash_spi_wp_n, flash_spi_do, flash_spi_di}	)
	);

	assign w_bus_cs		= bus_cs & ff_extio_en & ff_device_en;
	assign bus_ready	= ff_bus_ready & w_bus_ready;
	assign bus_rdata	= w_bus_rdata_en ? w_bus_rdata : ff_rdata;
	assign bus_rdata_en	= ff_rdata_en | w_bus_rdata_en;
endmodule
