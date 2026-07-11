#include "pico/stdlib.h"
#include "vdp_control.h"
#include "fpga_config.h"

// ---------------------------------------------------------
static void fpga_config_rom_ensure_device(uint8_t device_id) {

	fpga_outport(FPGA_CONFIG_PORT_MANUFACTURER_ID, FPGA_CONFIG_MANUFACTURER_ID);
	fpga_outport(FPGA_CONFIG_PORT_DEVICE_ID, device_id);
}

// ---------------------------------------------------------
static void fpga_config_rom_set_address( uint8_t device_id, uint32_t address ) {
	fpga_config_rom_ensure_device(FPGA_CONFIG_DEVICE_ID_VDP);

	// ConfigROM を選択する
	fpga_outport( FPGA_CONFIG_ROM_COMMAND_PORT, FPGA_CONFIG_ROM_SELECT_SROM );
	fpga_outport( FPGA_CONFIG_ROM_DATA_PORT, device_id );

	// ConfigROM のアドレスを設定する
	fpga_outport( FPGA_CONFIG_ROM_COMMAND_PORT, FPGA_CONFIG_ROM_SET_ADDRESS );
	fpga_outport( FPGA_CONFIG_ROM_DATA_PORT, (uint8_t)((address >> 16) & 0xFF));
	fpga_outport( FPGA_CONFIG_ROM_DATA_PORT, (uint8_t)((address >> 8) & 0xFF));
	fpga_outport( FPGA_CONFIG_ROM_DATA_PORT, (uint8_t)(address & 0xFF));
}

// ---------------------------------------------------------
void fpga_config_rom_write_start( uint32_t address ) {

	fpga_outport( FPGA_CONFIG_ROM_COMMAND_PORT, FPGA_CONFIG_ROM_BURST_WRITE );
}

// ---------------------------------------------------------
void fpga_config_rom_write_end( void ) {

	fpga_outport( FPGA_CONFIG_ROM_COMMAND_PORT, FPGA_CONFIG_ROM_ACCESS_END );
}

// ---------------------------------------------------------
void fpga_config_rom_write_vdp( uint8_t data ) {

	fpga_outport( FPGA_CONFIG_ROM_DATA_PORT, data );
}

// ---------------------------------------------------------
uint8_t fpga_config_rom_read_vdp( void ) {

	fpga_outport( FPGA_CONFIG_ROM_COMMAND_PORT, FPGA_CONFIG_ROM_SINGLE_READ );
	return fpga_inport( FPGA_CONFIG_ROM_DATA_PORT );
}

// ---------------------------------------------------------
void fpga_config_rom_set_address_vdp( uint32_t address ) {
	fpga_config_rom_set_address( FPGA_CONFIG_ROM_ID_VDP, address );
}
