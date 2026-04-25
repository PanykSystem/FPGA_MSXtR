@echo off
setlocal

if exist work rmdir /s /q work
vlib work

vlog gowin_rpll.v
vlog dvi_tx.v
for %%F in (..\bootrom\*.v) do vlog "%%F"
for %%F in (..\cz80\*.v) do vlog "%%F"
vlog ..\debugger\ip_debugger.v
for %%F in (..\s2026a\*.v) do vlog "%%F"
vlog ..\sdram\ip_sdram_tangnano20k_c.v
vlog ..\uart\ip_uart.v
vlog ..\uart\uart.v
for %%F in (..\v9968\*.v) do vlog "%%F"
vlog ..\ws2812_led\ip_ws2812_led.v
vlog ..\FPGA_MSXtR.v
vlog tb.sv

vsim -c -t 1ps tb -do "add wave -r *; run -all; quit -f"

endlocal
pause
