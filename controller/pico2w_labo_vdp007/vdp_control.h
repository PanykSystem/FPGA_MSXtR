#ifndef VDP_CONTROL_H
#define VDP_CONTROL_H

#include <stdint.h>
#include "hardware/spi.h"

// SPI0 (FPGAモジュール)
#define SPI0_PORT	  spi0
#define SPI0_RX_PIN	  4
#define SPI0_CSN_PIN  5
#define SPI0_SCK_PIN  6
#define SPI0_TX_PIN	  7
#define SPI0_BAUDRATE (80 * 1000 * 1000)	// 80 MHz

void vdp_write_register(uint8_t reg, uint8_t data);
void vdp_set_screen1(void);
void vdp_set_screen1_font(void);
void vdp_set_screen1_message(void);

#endif
