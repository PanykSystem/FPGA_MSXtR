`timescale 1ns / 1ps

module tb;
	reg			clk;
	reg			reset_n;
	wire			lcd_clk;
	wire			lcd_de;
	wire			lcd_hsync;
	wire			lcd_vsync;
	wire	[4:0]	lcd_red;
	wire	[5:0]	lcd_green;
	wire	[4:0]	lcd_blue;
	wire			lcd_bl;

	display_controller u_display_controller (
		.clk		( clk ),
		.reset_n	( reset_n ),
		.lcd_clk	( lcd_clk ),
		.lcd_de		( lcd_de ),
		.lcd_hsync	( lcd_hsync ),
		.lcd_vsync	( lcd_vsync ),
		.lcd_red	( lcd_red ),
		.lcd_green	( lcd_green ),
		.lcd_blue	( lcd_blue ),
		.lcd_bl		( lcd_bl )
	);

	initial begin
		clk = 1'b0;
		forever begin
			#5.82;
			clk = ~clk;
		end
	end

	initial begin
		reset_n = 1'b0;
		#100;
		reset_n = 1'b1;
	end
endmodule
