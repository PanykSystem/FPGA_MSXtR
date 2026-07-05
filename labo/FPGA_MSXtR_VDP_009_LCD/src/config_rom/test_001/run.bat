@echo off
setlocal

cd /d "%~dp0"

if exist work rd /s /q work
vlib work
if errorlevel 1 goto :error

vlog ..\config_rom.v ^
	..\..\qspi_rom\ip_qspi_rom.v ^
	..\..\qspi_rom\qspi.v ^
	.\W25Q32JVxxIM.v
vlog tb.sv
if errorlevel 1 goto :error

vsim -c work.tb -l log.txt -do "add wave -r *; run -all; quit -f"
if errorlevel 1 goto :error

findstr /c:"[TB][ERROR]" log.txt >nul
if not errorlevel 1 goto :error

echo.
echo ModelSim simulation completed successfully.
exit /b 0

:error
echo.
echo ModelSim simulation failed.
exit /b 1
