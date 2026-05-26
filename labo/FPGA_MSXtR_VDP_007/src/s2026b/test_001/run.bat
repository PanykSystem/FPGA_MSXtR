@echo off
setlocal

if exist work rmdir /s /q work
vlib work

vlog ..\s2026b_cpu_select.v
vlog ..\s2026b.v
vlog tb.sv

vsim -c -t 1ps tb -do "add wave -r *; run -all; quit -f"

endlocal
pause
