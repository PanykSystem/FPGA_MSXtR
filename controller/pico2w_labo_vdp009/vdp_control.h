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
#define SPI0_INTR_PIN 3
#define SPI0_BAUDRATE (80 * 1000 * 1000)	// 80 MHz

void vdp_write_register(uint8_t reg, uint8_t data);
void vdp_ll_set_screen1(void);
void vdp_set_screen1_font(void);
void vdp_set_screen1_message(void);

#define vdp_ll_begin() gpio_put(SPI0_CSN_PIN, 0)
#define vdp_ll_end() gpio_put(SPI0_CSN_PIN, 1)

void vdp_ll_fill_vram(uint16_t addr, uint8_t value, uint16_t size);
void vdp_ll_write_vram(uint8_t* data, uint16_t size);
void vdp_ll_set_vram_address(uint16_t addr);

#endif
