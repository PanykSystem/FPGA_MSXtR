@echo off
if exist work rmdir /s /q work
if exist log.txt del /q log.txt
if exist transcript del /q transcript
if exist display_controller.wlf del /q display_controller.wlf
vlib work
vlog ..\display_controller.v
vlog tb.sv
vsim -c -t 1ps -wlf display_controller.wlf -do run.do tb
move transcript log.txt