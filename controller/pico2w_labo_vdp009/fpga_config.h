#ifndef FPGA_CONFIG_H
#define FPGA_CONFIG_H

#include <stdint.h>

#define FPGA_CONFIG_PORT_MANUFACTURER_ID 0x40
#define FPGA_CONFIG_PORT_DEVICE_ID       0x41
#define FPGA_CONFIG_ROM_BASE_VDP         0x42
#define FPGA_CONFIG_ROM_BASE_CPU         0x42

#define FPGA_CONFIG_MANUFACTURER_ID      0x40
#define FPGA_CONFIG_DEVICE_ID_VDP        0x01
#define FPGA_CONFIG_DEVICE_ID_CPU        0x01

#define FPGA_CONFIG_ROM_PORT_ADDR 0x00
#define FPGA_CONFIG_ROM_PORT_DATA 0x01

void fpga_config_write(uint8_t io_address, uint8_t data);
uint8_t fpga_config_read(uint8_t io_address);

void fpga_config_rom_write_vdp(uint8_t port_offset, uint8_t data);
uint8_t fpga_config_rom_read_vdp(uint8_t port_offset);
void fpga_config_rom_set_address_vdp(uint32_t address);

void fpga_config_rom_write_cpu(uint8_t port_offset, uint8_t data);
uint8_t fpga_config_rom_read_cpu(uint8_t port_offset);
void fpga_config_rom_set_address_cpu(uint32_t address);

#endif
