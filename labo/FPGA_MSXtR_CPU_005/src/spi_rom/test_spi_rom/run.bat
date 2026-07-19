@echo off
setlocal

if exist work rmdir /s /q work
vlib work

vlog W25Q32JVxxIM.v
vlog ..\ip_spi_rom.v
vlog tb.sv

vsim -c -voptargs=+acc -t 1ps -l log.txt tb -do "add wave -r *; run -all; quit -f"

endlocal
rem pause
