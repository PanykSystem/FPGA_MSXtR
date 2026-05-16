#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/i2c.h"

#define I2C_PORT     i2c0
#define I2C_SDA_PIN  20
#define I2C_SCL_PIN  21
#define I2C_BAUDRATE (400 * 1000)  // 400 kHz (Fast mode)
#define I2C_ADDR     0x08

static void i2c0_init(void) {
    i2c_init(I2C_PORT, I2C_BAUDRATE);
    gpio_set_function(I2C_SDA_PIN, GPIO_FUNC_I2C);
    gpio_set_function(I2C_SCL_PIN, GPIO_FUNC_I2C);
    gpio_pull_up(I2C_SDA_PIN);
    gpio_pull_up(I2C_SCL_PIN);
}

int main() {
	stdio_init_all();
	i2c0_init();
	uint8_t data = 0;
	uint8_t recv[12];
	while( true ) {
		i2c_write_blocking(I2C_PORT, I2C_ADDR, &data, 1, false);
		printf("Send 0x%02X\n", data);
		i2c_read_blocking(I2C_PORT, I2C_ADDR, recv, 12, false);
		for (int i = 0; i < 12; i++) {
			printf("Recv[%d] = 0x%02X\n", i, recv[i]);
		}
		data++;
		sleep_ms( 100 );
	}
	return 0;
}
