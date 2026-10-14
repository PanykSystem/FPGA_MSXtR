@echo off
setlocal
cd /d "%~dp0"
if not exist work vlib work
if errorlevel 1 exit /b 1
vlog -work work ..\..\ikaopll\src\IKAOPLL.v ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_dac.v ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_eg.v ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_lfo.v ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_op.v ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_pg.v ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_primitives.v ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_timinggen.v ..\IKAOPLL_reg.v ..\opll.v ..\..\msx_slot\msx_slot.v ..\..\y8960_address_decode\y8960_address_decode.v tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -l log.txt tb -do "run -all; quit -f"
if errorlevel 1 exit /b 1
findstr /C:"** Fatal:" /C:"** Error:" log.txt >nul
if not errorlevel 1 exit /b 1
findstr /C:"PASS: 7Ch/7Dh slot writes generate nonzero OPLL audio" log.txt >nul
if errorlevel 1 exit /b 1
exit /b 0