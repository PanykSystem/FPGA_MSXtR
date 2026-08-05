//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.02 (64-bit) 
//Created Time: 2026-04-10 22:02:39

# 入力クロック
create_clock -name clk27m -period 37.03 -waveform {0 18.515} [get_ports {clk27m}]
create_clock -name clk14m -period 69.84 -waveform {0 34.92} [get_ports {clk14m}]

# PLL 出力クロック
create_generated_clock -name clk215m  -source [get_ports {clk14m}] -master_clock clk14m -multiply_by 15 [get_nets {clk215m}]
# create_generated_clock -name clk85m   -source [get_ports {clk14m}] -master_clock clk14m -multiply_by 6 [get_nets {clk85m}]
create_generated_clock -name clk42m   -source [get_nets {clk14m}] -master_clock clk14m -multiply_by 3 [get_nets {clk42m}]

# 非同期クロックグループ宣言 → clk1とclk2間の全パスをタイミング除外
set_clock_groups -asynchronous -group [get_clocks {clk215m}] -group [get_clocks {clk42m}]
set_clock_groups -asynchronous -group [get_clocks {clk27m}] -group [get_clocks {clk42m}]

# set_clock_groups -asynchronous -group [get_clocks {clk215m}] -group [get_clocks {clk85m}]
# set_clock_groups -asynchronous -group [get_clocks {clk27m}] -group [get_clocks {clk85m}]
# set_clock_groups -asynchronous -group [get_clocks {clk42m}] -group [get_clocks {clk85m}]
