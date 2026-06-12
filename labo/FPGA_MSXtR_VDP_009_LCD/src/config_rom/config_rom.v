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
	//	internal bus interface
	input			bus_cs,				//	chip select
	input			bus_address,		//	0: register addresss port, 1: register data port
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
	wire			w_hclk;
	wire			w_hresetn;
	wire	[31:0]	w_haddr_reg;
	wire	[31:0]	w_hrdata_reg;
	wire			w_hreadyin_reg;
	wire			w_hreadyout_reg;
	wire	[1:0]	w_hresp_reg;
	wire			w_hsel_reg;
	wire			w_hvalid_reg;
	wire			w_hsel_ip;
	wire	[1:0]	w_htrans_reg;
	wire	[2:0]	w_hsize_reg;
	wire	[31:0]	w_hwdata_reg;
	wire			w_hwrite_reg;

	assign w_hclk			= clk;
	assign w_hresetn		= reset_n;
	assign w_hreadyin_reg	= 1'b1;
	assign w_hsel_ip		= w_hsel_reg & w_hvalid_reg;


	bus_to_ahb_bridge u_bus_to_ahb_bridge (
		.reset_n			( reset_n			),
		.clk				( clk				),
		.bus_cs				( bus_cs			),
		.bus_address		( bus_address		),
		.bus_write			( bus_write			),
		.bus_valid			( bus_valid			),
		.bus_ready			( bus_ready			),
		.bus_wdata			( bus_wdata			),
		.bus_rdata			( bus_rdata			),
		.bus_rdata_en		( bus_rdata_en		),
		.ahb_mst_valid		( w_hvalid_reg		),
		.ahb_mst_ready		( w_hreadyout_reg	),
		.ahb_mst_sel		( w_hsel_reg		),
		.ahb_mst_trans		( w_htrans_reg		),
		.ahb_mst_size		( w_hsize_reg		),
		.ahb_mst_write		( w_hwrite_reg		),
		.ahb_mst_addr		( w_haddr_reg		),
		.ahb_mst_wdata		( w_hwdata_reg		),
		.ahb_mst_rdata		( w_hrdata_reg		),
		.ahb_mst_resp		( w_hresp_reg		)
	);

	SPI_Flash_Interface_Lite_Top u_spi_flash_if (
		.I_hclk				( w_hclk			),		//	input I_hclk
		.I_hresetn			( w_hresetn			),		//	input I_hresetn
		.I_haddr_reg		( w_haddr_reg		),		//	input [31:0] I_haddr_reg
		.O_hrdata_reg		( w_hrdata_reg		),		//	output [31:0] O_hrdata_reg
		.I_hreadyin_reg		( w_hreadyin_reg	),		//	input I_hreadyin_reg
		.O_hreadyout_reg	( w_hreadyout_reg	),		//	output O_hreadyout_reg
		.O_hresp_reg		( w_hresp_reg		),		//	output [1:0] O_hresp_reg
		.I_hsel_reg			( w_hsel_ip			),		//	input I_hsel_reg
		.I_htrans_reg		( w_htrans_reg		),		//	input [1:0] I_htrans_reg
		.I_hwdata_reg		( w_hwdata_reg		),		//	input [31:0] I_hwdata_reg
		.I_hwrite_reg		( w_hwrite_reg		),		//	input I_hwrite_reg
		.O_flash_ck			( flash_spi_ck		),		//	output O_flash_ck
		.O_flash_cs_n		( flash_spi_cs_n	),		//	output O_flash_cs_n
		.IO_flash_hold_n	( flash_spi_hold_n	),		//	inout IO_flash_hold_n
		.IO_flash_wp_n		( flash_spi_wp_n	),		//	inout IO_flash_wp_n
		.IO_flash_do		( flash_spi_do		),		//	inout IO_flash_do
		.IO_flash_di		( flash_spi_di		)		//	inout IO_flash_di
	);
endmodule
