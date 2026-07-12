@echo off
setlocal

if exist work rmdir /s /q work
vlib work

vlog W25Q32JVxxIM.v
vlog ..\ip_spi_rom.v
vlog tb.sv

vsim -c -voptargs=+acc -t 1ps tb -do "add wave -r *; run -all; quit -f"

if exist transcript move transcript log.txt

endlocal
rem pause
