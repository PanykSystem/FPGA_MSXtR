# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/mnt/c/Users/hra/Documents/github/HRA_product/FPGA_MSXtR/controller/pico2w_labo_vdp007/build/_deps/no_os_fatfs-src"
  "/mnt/c/Users/hra/Documents/github/HRA_product/FPGA_MSXtR/controller/pico2w_labo_vdp007/build/_deps/no_os_fatfs-build"
  "/mnt/c/Users/hra/Documents/github/HRA_product/FPGA_MSXtR/controller/pico2w_labo_vdp007/build/_deps/no_os_fatfs-subbuild/no_os_fatfs-populate-prefix"
  "/mnt/c/Users/hra/Documents/github/HRA_product/FPGA_MSXtR/controller/pico2w_labo_vdp007/build/_deps/no_os_fatfs-subbuild/no_os_fatfs-populate-prefix/tmp"
  "/mnt/c/Users/hra/Documents/github/HRA_product/FPGA_MSXtR/controller/pico2w_labo_vdp007/build/_deps/no_os_fatfs-subbuild/no_os_fatfs-populate-prefix/src/no_os_fatfs-populate-stamp"
  "/mnt/c/Users/hra/Documents/github/HRA_product/FPGA_MSXtR/controller/pico2w_labo_vdp007/build/_deps/no_os_fatfs-subbuild/no_os_fatfs-populate-prefix/src"
  "/mnt/c/Users/hra/Documents/github/HRA_product/FPGA_MSXtR/controller/pico2w_labo_vdp007/build/_deps/no_os_fatfs-subbuild/no_os_fatfs-populate-prefix/src/no_os_fatfs-populate-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/mnt/c/Users/hra/Documents/github/HRA_product/FPGA_MSXtR/controller/pico2w_labo_vdp007/build/_deps/no_os_fatfs-subbuild/no_os_fatfs-populate-prefix/src/no_os_fatfs-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/mnt/c/Users/hra/Documents/github/HRA_product/FPGA_MSXtR/controller/pico2w_labo_vdp007/build/_deps/no_os_fatfs-subbuild/no_os_fatfs-populate-prefix/src/no_os_fatfs-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()
