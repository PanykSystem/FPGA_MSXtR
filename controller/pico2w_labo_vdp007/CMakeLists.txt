cmake_minimum_required(VERSION 3.13...3.27)

# initialize the SDK based on PICO_SDK_PATH
# note: this must happen before project()
include(pico_sdk_import.cmake)

project(fpga_msxtr_controller)

# initialize the Raspberry Pi Pico SDK
pico_sdk_init()

# ----------------------------------------------------------------
# FatFS / SDカードライブラリ (no-OS-FatFS-SD-SPI-RPi-Pico)
# デフォルトブランチは master、最新リリースタグ v1.0.8 を使用
# ディレクトリ構造: <repo>/FatFs_SPI/CMakeLists.txt
include(FetchContent)
FetchContent_Declare(
    no_os_fatfs
    GIT_REPOSITORY https://github.com/carlk3/no-OS-FatFS-SD-SPI-RPi-Pico.git
    GIT_TAG        v1.0.8
    GIT_SHALLOW    TRUE
    SOURCE_SUBDIR  FatFs_SPI
)
FetchContent_MakeAvailable(no_os_fatfs)

# rp2350 (Pico2/Pico2W) には hardware RTC がないため対処する。
# (1) rtc.c をスタブに置き換え
# (2) FatFs_SPI の INTERFACE_LINK_LIBRARIES から hardware_rtc を削除
FetchContent_GetProperties(no_os_fatfs)
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/rtc_stub.c
    ${no_os_fatfs_SOURCE_DIR}/FatFs_SPI/src/rtc.c
    COPYONLY
)
get_target_property(_fatfs_libs FatFs_SPI INTERFACE_LINK_LIBRARIES)
list(REMOVE_ITEM _fatfs_libs "hardware_rtc")
set_target_properties(FatFs_SPI PROPERTIES INTERFACE_LINK_LIBRARIES "${_fatfs_libs}")

# ----------------------------------------------------------------
# Additional sections specific to the fpga_msxtr_controller
add_executable(fpga_msxtr_controller
    fpga_msxtr_controller.c
    keyboard.c
    hw_config.c
)

# Add pico_stdlib library which aggregates commonly used features
target_link_libraries(fpga_msxtr_controller
    pico_stdlib
    hardware_i2c
    hardware_spi
    pico_multicore
    FatFs_SPI
)

# enable usb output, disable uart output
pico_enable_stdio_usb(fpga_msxtr_controller 1)
pico_enable_stdio_uart(fpga_msxtr_controller 0)

# create map/bin/hex/uf2 file in addition to ELF.
pico_add_extra_outputs(fpga_msxtr_controller)
