#include "pico/stdlib.h"
#include "hardware/spi.h"
#include "vdp_control.h"
#include "fpga_uart.h"

// ---------------------------------------------------------
// FPGAのUARTから送信
void fpga_uart_putc(char c) {
	uint8_t buf;

	gpio_put(SPI0_CSN_PIN, 0);
	buf = 0x01;
	spi_write_blocking(SPI0_PORT, &buf, 1);
	buf = 0x10;
	spi_write_blocking(SPI0_PORT, &buf, 1);
	buf = (uint8_t) c;
	spi_write_blocking(SPI0_PORT, &buf, 1);
	gpio_put(SPI0_CSN_PIN, 1);
}

// ---------------------------------------------------------
// FPGAのUARTから文字列を送信
void fpga_uart_puts(const char *s) {

	while( *s ) {
		fpga_uart_putc( *s );
		s++;
		sleep_ms( 5 );
	}
}
