@echo off
setlocal

if exist work rmdir /s /q work
vlib work

vlog gowin_rpll.v
vlog ..\bootrom\bootrom.v
vlog ..\uart\ip_uart.v
vlog ..\uart\uart.v
vlog ..\s2026a\s2026a_cpu_select.v
vlog ..\s2026a\s2026a.v
vlog ..\cz80\cz80_reg.v
vlog ..\cz80\cz80_mcode.v
vlog ..\cz80\cz80_alu.v
vlog ..\cz80\cz80.v
vlog ..\cz80\cz80_inst.v
vlog ..\FPGA_MSXtR.v
vlog tb.sv

vsim -c -t 1ps tb -do "add wave -r *; run -all; quit -f"

endlocal
pause
