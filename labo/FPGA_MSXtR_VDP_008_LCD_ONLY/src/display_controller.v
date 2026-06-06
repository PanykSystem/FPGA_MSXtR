//
// display_controller.v
//
//	Copyright (C) 2025 Takayuki Hara
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

module display_controller (
	input			clk,					//	85.90908MHz
	input			reset_n,				//	active low
	output			lcd_clk,				//	PIN77
	output			lcd_de,					//	PIN48
	output			lcd_hsync,				//	PIN25
	output			lcd_vsync,				//	PIN26
	output	[4:0]	lcd_red,				//	PIN38, PIN39, PIN40, PIN41, PIN42
	output	[5:0]	lcd_green,				//	PIN32, PIN33, PIN34, PIN35, PIN36, PIN37
	output	[4:0]	lcd_blue,				//	PIN27, PIN28, PIN29, PIN30, PIN31
	output			lcd_bl					//	PIN49
);
	localparam integer H_ACTIVE			= 800;
	localparam integer H_FRONT_PORCH	= 40;
	localparam integer H_SYNC_WIDTH		= 128;
	localparam integer H_BACK_PORCH		= 400;
	localparam integer H_TOTAL			= H_ACTIVE + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;	//	1368

	localparam integer V_ACTIVE			= 480;
	localparam integer V_FRONT_PORCH	= 13;
	localparam integer V_SYNC_WIDTH		= 2;
	localparam integer V_BACK_PORCH		= 30;
	localparam integer V_TOTAL			= V_ACTIVE + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH;	//	525

	reg				ff_lcd_clk;
	reg		[10:0]	ff_h_count;
	reg		[9:0]	ff_v_count;
	reg				ff_de;
	reg				ff_hsync;
	reg				ff_vsync;
	reg		[4:0]	ff_red;
	reg		[5:0]	ff_green;
	reg		[4:0]	ff_blue;

	wire			h_active_area;
	wire			v_active_area;
	wire			active_area;

	assign h_active_area = ( ff_h_count < H_ACTIVE );
	assign v_active_area = ( ff_v_count < V_ACTIVE );
	assign active_area = h_active_area & v_active_area;

	// ---------------------------------------------------------
	//	LCD timing and simple gradient generation
	//	Pixel clock: clk/2 = 42.95454MHz
	//	Frame rate: 42.95454MHz / (1368 * 525) = about 59.79Hz
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_lcd_clk	<= 1'b0;
			ff_h_count	<= 11'd0;
			ff_v_count	<= 10'd0;
			ff_de		<= 1'b0;
			ff_hsync	<= 1'b1;
			ff_vsync	<= 1'b1;
			ff_red		<= 5'd0;
			ff_green	<= 6'd0;
			ff_blue		<= 5'd0;
		end
		else begin
			ff_lcd_clk <= ~ff_lcd_clk;

			if( ~ff_lcd_clk ) begin
				if( ff_h_count == (H_TOTAL - 1) ) begin
					ff_h_count <= 11'd0;
					if( ff_v_count == (V_TOTAL - 1) ) begin
						ff_v_count <= 10'd0;
					end
					else begin
						ff_v_count <= ff_v_count + 10'd1;
					end
				end
				else begin
					ff_h_count <= ff_h_count + 11'd1;
				end

				ff_de <= active_area;

				if( (ff_h_count >= (H_ACTIVE + H_FRONT_PORCH)) && (ff_h_count < (H_ACTIVE + H_FRONT_PORCH + H_SYNC_WIDTH)) ) begin
					ff_hsync <= 1'b0;
				end
				else begin
					ff_hsync <= 1'b1;
				end

				if( (ff_v_count >= (V_ACTIVE + V_FRONT_PORCH)) && (ff_v_count < (V_ACTIVE + V_FRONT_PORCH + V_SYNC_WIDTH)) ) begin
					ff_vsync <= 1'b0;
				end
				else begin
					ff_vsync <= 1'b1;
				end

				if( active_area ) begin
					ff_red		<= ff_h_count[4:0];
					ff_green	<= ff_v_count[5:0];
					ff_blue		<= ff_h_count[9:5];
				end
				else begin
					ff_red		<= 5'd0;
					ff_green	<= 6'd0;
					ff_blue		<= 5'd0;
				end
			end
		end
	end

	assign lcd_clk		= ff_lcd_clk;
	assign lcd_de		= ff_de;
	assign lcd_hsync	= ff_hsync;
	assign lcd_vsync	= ff_vsync;
	assign lcd_red		= ff_red;
	assign lcd_green	= ff_green;
	assign lcd_blue		= ff_blue;
	assign lcd_bl		= 1'b1;
endmodule
