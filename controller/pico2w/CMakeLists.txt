cmake_minimum_required(VERSION 3.13...3.27)

# initialize the SDK based on PICO_SDK_PATH
# note: this must happen before project()
include(pico_sdk_import.cmake)

project(fpga_msxtr_controller)

# initialize the Raspberry Pi Pico SDK
pico_sdk_init()

# ----------------------------------------------------------------
# Additional sections specific to the fpga_msxtr_controller
add_executable(fpga_msxtr_controller
    fpga_msxtr_controller.c
)

# Add pico_stdlib library which aggregates commonly used features
target_link_libraries(fpga_msxtr_controller pico_stdlib hardware_i2c)

# enable usb output, disable uart output
pico_enable_stdio_usb(fpga_msxtr_controller 1)
pico_enable_stdio_uart(fpga_msxtr_controller 0)

# create map/bin/hex/uf2 file in addition to ELF.
pico_add_extra_outputs(fpga_msxtr_controller)
