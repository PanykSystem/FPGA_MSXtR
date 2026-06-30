@echo off
setlocal

if exist work rmdir /s /q work
vlib work

vlog gowin_rpll.v
vlog dvi_tx.v
vlog MT48LC2M32B2.v
for %%F in (..\bootrom\*.v) do vlog "%%F"
vlog ..\debugger\ip_debugger.v
vlog ..\sdram\ip_sdram_tangnano20k_c.v
for %%F in (..\uart\*.v) do vlog "%%F"
for %%F in (..\s2026b\*.v) do vlog "%%F"
for %%F in (..\spi\*.v) do vlog "%%F"
for %%F in (..\fpga_connect\*.v) do vlog "%%F"
for %%F in (..\qspi_rom\*.v) do vlog "%%F"
vlog ..\config_rom\config_rom.v
for %%F in (..\v9968\*.v) do vlog "%%F"
vlog ..\ws2812_led\ip_ws2812_led.v
vlog ..\tangnano20k_vdp_cartridge_lcd.v
vlog tb.sv

vsim -c -t 1ps tb -do "add wave -r *; run -all; quit -f"
if exist transcript move transcript log.txt
endlocal

