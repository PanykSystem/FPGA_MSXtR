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

module bus_to_ahb_bridge (
	input			reset_n,
	input			clk,
	//	internal bus interface
	input			bus_cs,				//	chip select
	input			bus_address,		//	0: register addresss port, 1: register data port
	input			bus_write,			//	read write direction (0: read, 1: write)
	input			bus_valid,			//	access valid signal
	output			bus_ready,			//	access ready signal
	input	[7:0]	bus_wdata,			//	write data
	output	[7:0]	bus_rdata,			//	read data
	output			bus_rdata_en,		//	read enable signal
	//	AHB-Lite master interface
	output			ahb_mst_valid,		//	master access valid signal
	input			ahb_mst_ready,		//	master access ready signal
	output			ahb_mst_sel,		//	AHB HSEL
	output	[1:0]	ahb_mst_trans,		//	AHB HTRANS
	output	[2:0]	ahb_mst_size,		//	AHB HSIZE (byte)
	output			ahb_mst_write,		//	AHB HWRITE
	output	[31:0]	ahb_mst_addr,		//	AHB HADDR
	output	[31:0]	ahb_mst_wdata,		//	AHB HWDATA
	input	[31:0]	ahb_mst_rdata,		//	AHB HRDATA
	input	[1:0]	ahb_mst_resp		//	AHB HRESP (reserved)
);
	localparam	[1:0]	c_htrans_idle		= 2'b00;
	localparam	[1:0]	c_htrans_nonseq		= 2'b10;

	reg				ff_busy;
	reg				ff_hwrite;
	reg				ff_is_read;
	reg		[31:0]	ff_haddr;
	reg		[31:0]	ff_hwdata;
	reg		[31:0]	ff_address;
	reg		[1:0]	ff_address_byte_index;
	reg		[7:0]	ff_bus_rdata;
	reg				ff_bus_rdata_en;

	wire			w_bus_accept;
	wire			w_ahb_done;

	function [31:0] f_pack_wdata;
		input [1:0] lane;
		input [7:0] data8;
		begin
			case( lane )
			2'd0: f_pack_wdata	= {24'd0, data8};
			2'd1: f_pack_wdata	= {16'd0, data8, 8'd0};
			2'd2: f_pack_wdata	= {8'd0, data8, 16'd0};
			2'd3: f_pack_wdata	= {data8, 24'd0};
			endcase
		end
	endfunction

	function [7:0] f_unpack_rdata;
		input [1:0] lane;
		input [31:0] data32;
		begin
			case( lane )
			2'd0: f_unpack_rdata	= data32[7:0];
			2'd1: f_unpack_rdata	= data32[15:8];
			2'd2: f_unpack_rdata	= data32[23:16];
			2'd3: f_unpack_rdata	= data32[31:24];
			endcase
		end
	endfunction

	assign w_bus_accept		= bus_cs && bus_valid && bus_ready;
	assign w_ahb_done		= ff_busy && ahb_mst_ready;

	assign bus_ready		= ~ff_busy;
	assign bus_rdata		= ff_bus_rdata;
	assign bus_rdata_en		= ff_bus_rdata_en;

	assign ahb_mst_valid	= ff_busy;
	assign ahb_mst_sel		= ff_busy;
	assign ahb_mst_trans	= ff_busy ? c_htrans_nonseq : c_htrans_idle;
	assign ahb_mst_size		= 3'b000;			//	byte access
	assign ahb_mst_write	= ff_hwrite;
	assign ahb_mst_addr		= ff_haddr;
	assign ahb_mst_wdata	= ff_hwdata;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_busy					<= 1'b0;
			ff_hwrite				<= 1'b0;
			ff_is_read				<= 1'b0;
			ff_haddr				<= 32'd0;
			ff_hwdata				<= 32'd0;
			ff_address				<= 32'd0;
			ff_address_byte_index	<= 2'd0;
			ff_bus_rdata			<= 8'd0;
			ff_bus_rdata_en			<= 1'b0;
		end
		else begin
			ff_bus_rdata_en	<= 1'b0;

			if( w_bus_accept ) begin
				if( bus_write ) begin
					if( !bus_address ) begin
						case( ff_address_byte_index )
						2'd0: ff_address[7:0]	<= bus_wdata;
						2'd1: ff_address[15:8]	<= bus_wdata;
						2'd2: ff_address[23:16]	<= bus_wdata;
						2'd3: ff_address[31:24]	<= bus_wdata;
						endcase
						ff_address_byte_index	<= ff_address_byte_index + 2'd1;
					end
					else begin
						ff_busy		<= 1'b1;
						ff_hwrite	<= 1'b1;
						ff_is_read	<= 1'b0;
						ff_haddr	<= ff_address;
						ff_hwdata	<= f_pack_wdata( ff_address[1:0], bus_wdata );
					end
				end
				else begin
					if( !bus_address ) begin
						case( ff_address_byte_index )
						2'd0: ff_bus_rdata	<= ff_address[7:0];
						2'd1: ff_bus_rdata	<= ff_address[15:8];
						2'd2: ff_bus_rdata	<= ff_address[23:16];
						2'd3: ff_bus_rdata	<= ff_address[31:24];
						endcase
						ff_bus_rdata_en			<= 1'b1;
						ff_address_byte_index	<= ff_address_byte_index + 2'd1;
					end
					else begin
						ff_busy		<= 1'b1;
						ff_hwrite	<= 1'b0;
						ff_is_read	<= 1'b1;
						ff_haddr	<= ff_address;
						ff_hwdata	<= 32'd0;
					end
				end
			end

			if( w_ahb_done ) begin
				ff_busy	<= 1'b0;

				if( ff_is_read && (ahb_mst_resp == 2'b00) ) begin
					ff_bus_rdata	<= 8'h12;	//f_unpack_rdata( ff_haddr[1:0], ahb_mst_rdata );
					ff_bus_rdata_en	<= 1'b1;
				end

				ff_address	<= ff_haddr + 32'd1;
			end
		end
	end
endmodule
