#include "pico/stdlib.h"
#include "pico/time.h"
#include "hardware/spi.h"
#include "vdp_control.h"
#include "fpga_config.h"

static void fpga_config_rom_set_address(uint8_t base, uint32_t address) {
	fpga_config_write(base | FPGA_CONFIG_ROM_PORT_ADDR, (uint8_t)(address & 0xFF));
	fpga_config_write(base | FPGA_CONFIG_ROM_PORT_ADDR, (uint8_t)((address >> 8) & 0xFF));
	fpga_config_write(base | FPGA_CONFIG_ROM_PORT_ADDR, (uint8_t)((address >> 16) & 0xFF));
	fpga_config_write(base | FPGA_CONFIG_ROM_PORT_ADDR, (uint8_t)((address >> 24) & 0xFF));
}

// ---------------------------------------------------------
void fpga_config_write(uint8_t io_address, uint8_t data) {
	uint8_t buf;

	gpio_put(SPI0_CSN_PIN, 0);

	buf = 0x01;
	spi_write_blocking(SPI0_PORT, &buf, 1);

	buf = io_address;
	spi_write_blocking(SPI0_PORT, &buf, 1);

	buf = data;
	spi_write_blocking(SPI0_PORT, &buf, 1);

	gpio_put(SPI0_CSN_PIN, 1);
}

// ---------------------------------------------------------
uint8_t fpga_config_read(uint8_t io_address) {
	uint8_t cmd;
	uint8_t dummy;
	uint8_t data;
	absolute_time_t timeout_time;
	bool intr_ready;

	gpio_put(SPI0_CSN_PIN, 0);

	cmd = 0x02;
	spi_write_blocking(SPI0_PORT, &cmd, 1);

	cmd = io_address;
	spi_write_blocking(SPI0_PORT, &cmd, 1);

	// INTR ピンが 1 になるまで待つ（500ms タイムアウト）
	timeout_time = make_timeout_time_ms(500);
	intr_ready = false;

	while( !time_reached(timeout_time) ) {
		if( gpio_get(SPI0_INTR_PIN) ) {
			intr_ready = true;
			break;
		}
		sleep_us(10);
	}

	// タイムアウトした場合は CSn = 1, 0xAA を返す
	if( !intr_ready ) {
		gpio_put(SPI0_CSN_PIN, 1);
		return 0xAA;
	}

	dummy = 0x00;
	spi_write_read_blocking(SPI0_PORT, &dummy, &data, 1);

	gpio_put(SPI0_CSN_PIN, 1);

	return data;
}

// ---------------------------------------------------------
void fpga_config_rom_write_vdp(uint8_t port_offset, uint8_t data) {
	uint8_t io_address;

	io_address = FPGA_CONFIG_ROM_BASE_VDP | (port_offset & 0x01);
	fpga_config_write(io_address, data);
}

// ---------------------------------------------------------
uint8_t fpga_config_rom_read_vdp(uint8_t port_offset) {
	uint8_t io_address;

	io_address = FPGA_CONFIG_ROM_BASE_VDP | (port_offset & 0x01);
	return fpga_config_read(io_address);
}

// ---------------------------------------------------------
void fpga_config_rom_set_address_vdp(uint32_t address) {
	fpga_config_rom_set_address(FPGA_CONFIG_ROM_BASE_VDP, address);
}

// ---------------------------------------------------------
void fpga_config_rom_write_cpu(uint8_t port_offset, uint8_t data) {
	uint8_t io_address;

	io_address = FPGA_CONFIG_ROM_BASE_CPU | (port_offset & 0x01);
	fpga_config_write(io_address, data);
}

// ---------------------------------------------------------
uint8_t fpga_config_rom_read_cpu(uint8_t port_offset) {
	uint8_t io_address;

	io_address = FPGA_CONFIG_ROM_BASE_CPU | (port_offset & 0x01);
	return fpga_config_read(io_address);
}

// ---------------------------------------------------------
void fpga_config_rom_set_address_cpu(uint32_t address) {
	fpga_config_rom_set_address(FPGA_CONFIG_ROM_BASE_CPU, address);
}
