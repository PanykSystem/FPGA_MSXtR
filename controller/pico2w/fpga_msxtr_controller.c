#include <stdio.h>
#include "pico/stdlib.h"
#include "pico/multicore.h"
#include "hardware/i2c.h"
#include "hardware/spi.h"
#include "keyboard.h"

// I2C (キーボードコントローラー)
#define I2C_PORT     i2c0
#define I2C_SDA_PIN  20
#define I2C_SCL_PIN  21
#define I2C_BAUDRATE (400 * 1000)  // 400 kHz (Fast mode)
#define I2C_ADDR     0x08

// SPI0 (FPGAモジュール)
#define SPI0_PORT     spi0
#define SPI0_RX_PIN   4
#define SPI0_CSN_PIN  5
#define SPI0_SCK_PIN  6
#define SPI0_TX_PIN   7
#define SPI0_BAUDRATE (1000 * 1000)  // 1 MHz

// SPI1 (SDカード)
#define SPI1_PORT     spi1
#define SPI1_RX_PIN   8
#define SPI1_CSN_PIN  9
#define SPI1_SCK_PIN  10
#define SPI1_TX_PIN   11
#define SPI1_BAUDRATE (1000 * 1000)  // 1 MHz

static void i2c0_init(void) {
    i2c_init(I2C_PORT, I2C_BAUDRATE);
    gpio_set_function(I2C_SDA_PIN, GPIO_FUNC_I2C);
    gpio_set_function(I2C_SCL_PIN, GPIO_FUNC_I2C);
    gpio_pull_up(I2C_SDA_PIN);
    gpio_pull_up(I2C_SCL_PIN);
}

static void spi0_init(void) {
    spi_init(SPI0_PORT, SPI0_BAUDRATE);
    gpio_set_function(SPI0_RX_PIN,  GPIO_FUNC_SPI);
    gpio_set_function(SPI0_SCK_PIN, GPIO_FUNC_SPI);
    gpio_set_function(SPI0_TX_PIN,  GPIO_FUNC_SPI);
    // CSn はソフトウェア制御
    gpio_init(SPI0_CSN_PIN);
    gpio_set_dir(SPI0_CSN_PIN, GPIO_OUT);
    gpio_put(SPI0_CSN_PIN, 1);
}

static void spi1_init(void) {
    spi_init(SPI1_PORT, SPI1_BAUDRATE);
    gpio_set_function(SPI1_RX_PIN,  GPIO_FUNC_SPI);
    gpio_set_function(SPI1_SCK_PIN, GPIO_FUNC_SPI);
    gpio_set_function(SPI1_TX_PIN,  GPIO_FUNC_SPI);
    // CSn はソフトウェア制御
    gpio_init(SPI1_CSN_PIN);
    gpio_set_dir(SPI1_CSN_PIN, GPIO_OUT);
    gpio_put(SPI1_CSN_PIN, 1);
}

// Core 1: I2C通信（キーボード）+ printf
static void core1_entry(void) {
    keyboard_init(I2C_PORT, I2C_ADDR);

    uint8_t led_state = 0;
    while (true) {
        keyboard_update(led_state);

        printf("Send 0x%02X\n", led_state);
        const uint8_t *matrix = keyboard_get_matrix();
        for (int i = 0; i < KEYBOARD_KEY_MATRIX_SIZE; i++) {
            printf("Recv[%d] = 0x%02X\n", i, matrix[i]);
        }

        led_state++;
        sleep_ms(100);
    }
}

// Core 0: SPI通信（FPGAモジュール・SDカード）
int main() {
    stdio_init_all();
    i2c0_init();
    spi0_init();
    spi1_init();

    multicore_launch_core1(core1_entry);

    while (true) {
        // SPI0: FPGAモジュールとの通信
        // SPI1: SDカードとの通信
        sleep_ms(100);
    }
    return 0;
}
