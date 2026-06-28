@echo off
setlocal

if exist work rmdir /s /q work
vlib work

vlog ..\fpga_connect_master.v
vlog ..\fpga_connect_slave.v
vlog tb.sv

vsim -c -t 1ps tb -do "add wave -r *; run -all; quit -f"

if exist transcript move /y transcript log.txt
endlocal

