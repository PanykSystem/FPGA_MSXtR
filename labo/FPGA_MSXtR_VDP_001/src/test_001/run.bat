@echo off
setlocal

if exist work rmdir /s /q work
vlib work

vlog gowin_rpll.v
vlog ..\uart\ip_uart.v
vlog ..\uart\uart.v
vlog ..\FPGA_MSXtR.v
vlog tb.sv

vsim -c -t 1ps tb -do "add wave -r *; run -all; quit -f"

endlocal
pause
