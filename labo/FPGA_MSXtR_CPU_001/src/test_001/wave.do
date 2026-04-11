onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider Z80
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/clk
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/z80_m1_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/z80_mreq_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/z80_iorq_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/z80_rd_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/z80_wr_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/z80_a
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/z80_wdata
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/z80_rdata
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/wait_n
add wave -noupdate -divider S2026A(D1)
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/ff_bus_address_pre
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/ff_m1_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/ff_mreq_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/ff_iorq_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/ff_rd_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/ff_wr_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/ff_wdata
add wave -noupdate -divider S2026A(D2)
add wave -noupdate /tb/u_dut/u_s2026a/w_uart_cs
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/ff_bus_address
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/w_bus_address
add wave -noupdate /tb/u_dut/u_s2026a/u_cpu_select/ff_bus_m1
add wave -noupdate /tb/u_dut/u_s2026a/u_cpu_select/ff_bus_mem
add wave -noupdate /tb/u_dut/u_s2026a/u_cpu_select/ff_bus_io
add wave -noupdate /tb/u_dut/u_s2026a/w_bus_io
add wave -noupdate /tb/u_dut/u_s2026a/u_cpu_select/ff_bus_write
add wave -noupdate /tb/u_dut/u_s2026a/u_cpu_select/ff_bus_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_s2026a/u_cpu_select/ff_bus_wdata
add wave -noupdate /tb/u_dut/u_s2026a/w_bus_ready
add wave -noupdate -divider UART
add wave -noupdate /tb/u_dut/u_s2026a/bus_uart_cs
add wave -noupdate -radix hexadecimal /tb/u_dut/u_uart/bus_uart_cs
add wave -noupdate -radix hexadecimal /tb/u_dut/u_uart/bus_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_uart/bus_write
add wave -noupdate -radix hexadecimal /tb/u_dut/u_uart/bus_ready
add wave -noupdate -radix hexadecimal /tb/u_dut/u_uart/bus_wdata
add wave -noupdate -radix hexadecimal /tb/u_dut/u_uart/bus_rdata
add wave -noupdate -radix hexadecimal /tb/u_dut/u_uart/bus_rdata_en
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {458792567859 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 231
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 2
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {458320880585 ps} {458864945023 ps}
