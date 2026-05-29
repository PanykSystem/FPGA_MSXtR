#include <stdio.h>
#include "pico/stdlib.h"
#include "pico/multicore.h"
#include "hardware/i2c.h"
#include "ff.h"
#include "hw_config.h"
#include "keyboard.h"
#include "vdp_control.h"
#include "fpga_uart.h"

// I2C (キーボードコントローラー)
#define I2C_PORT	 i2c0
#define I2C_SDA_PIN	 20
#define I2C_SCL_PIN	 21
#define I2C_BAUDRATE (400 * 1000)  // 400 kHz (Fast mode)
#define I2C_ADDR	 0x08

// SPI1 (SDカード) -- ピン設定は hw_config.c で管理
// RX=8, CSN=9, SCK=10, TX=11, BAUDRATE=12.5MHz (no-OS-FatFS ライブラリが初期化)

// ---------------------------------------------------------
static void i2c0_init(void) {
	i2c_init(I2C_PORT, I2C_BAUDRATE);
	gpio_set_function(I2C_SDA_PIN, GPIO_FUNC_I2C);
	gpio_set_function(I2C_SCL_PIN, GPIO_FUNC_I2C);
	gpio_pull_up(I2C_SDA_PIN);
	gpio_pull_up(I2C_SCL_PIN);
}

// ---------------------------------------------------------
static void spi0_init(void) {
	spi_init(SPI0_PORT, SPI0_BAUDRATE);
	gpio_set_function(SPI0_RX_PIN,	GPIO_FUNC_SPI);
	gpio_set_function(SPI0_SCK_PIN, GPIO_FUNC_SPI);
	gpio_set_function(SPI0_TX_PIN,	GPIO_FUNC_SPI);
	// CSn はソフトウェア制御
	gpio_init(SPI0_CSN_PIN);
	gpio_set_dir(SPI0_CSN_PIN, GPIO_OUT);
	gpio_put(SPI0_CSN_PIN, 1);
}

// ---------------------------------------------------------------
// ファイルサイズをカンマ区切り文字列に変換
// 例: 1234567 -> "1,234,567"
static void format_comma(char *buf, size_t buf_size,
						 unsigned long long n) {
	char tmp[22];
	int len = snprintf(tmp, sizeof(tmp), "%llu", n);
	int out = 0;
	for (int i = 0; i < len && out < (int)buf_size - 1; i++) {
		if (i > 0 && (len - i) % 3 == 0) {
			buf[out++] = ',';
		}
		buf[out++] = tmp[i];
	}
	buf[out] = '\0';
}

// SDカード ルートディレクトリ一覧 (MS-DOS DIR 形式)
static void dir_sd_root(void) {
	FATFS fs;
	FRESULT fr;
	DIR dir;
	FILINFO finfo;

	fr = f_mount(&fs, "0:", 1);
	if (fr != FR_OK) {
		printf("f_mount 失敗: %d\n", (int)fr);
		return;
	}

	printf(" Directory of 0:\\*\n\n");

	fr = f_opendir(&dir, "0:/");
	if (fr != FR_OK) {
		printf("f_opendir 失敗: %d\n", (int)fr);
		f_unmount("0:");
		return;
	}

	int file_count = 0;
	int dir_count  = 0;
	unsigned long long total_bytes = 0;

	for (;;) {
		fr = f_readdir(&dir, &finfo);
		if (fr != FR_OK || finfo.fname[0] == '\0') break;

		// 日付デコード (FatFs: bits[15:9]=year-1980, [8:5]=month, [4:0]=day)
		int year   = ((finfo.fdate >>  9) & 0x7F) + 1980;
		int month  =  (finfo.fdate >>  5) & 0x0F;
		int day	   =   finfo.fdate		  & 0x1F;
		// 時刻デコード (FatFs: bits[15:11]=hour, [10:5]=min, [4:0]=sec/2)
		int hour   =  (finfo.ftime >> 11) & 0x1F;
		int min	   =  (finfo.ftime >>  5) & 0x3F;
		// 12時間表示
		const char *ampm  = (hour < 12) ? "AM" : "PM";
		int hour12 = hour % 12;
		if (hour12 == 0) hour12 = 12;

		if (finfo.fattrib & AM_DIR) {
			printf("%02d/%02d/%04d	%2d:%02d %s	   <DIR>		  %s\n",
				   month, day, year, hour12, min, ampm, finfo.fname);
			dir_count++;
		} else {
			char size_str[20];
			format_comma(size_str, sizeof(size_str),
						 (unsigned long long)finfo.fsize);
			printf("%02d/%02d/%04d	%2d:%02d %s	   %14s %s\n",
				   month, day, year, hour12, min, ampm,
				   size_str, finfo.fname);
			file_count++;
			total_bytes += (unsigned long long)finfo.fsize;
		}
	}
	f_closedir(&dir);

	// 集計行
	char total_str[20];
	format_comma(total_str, sizeof(total_str), total_bytes);
	printf("%16d File(s)  %14s bytes\n", file_count, total_str);

	// 空き容量
	DWORD fre_clust;
	FATFS *pfs;
	if (f_getfree("0:", &fre_clust, &pfs) == FR_OK) {
		unsigned long long free_bytes =
			(unsigned long long)fre_clust * pfs->csize * 512ULL;
		char free_str[20];
		format_comma(free_str, sizeof(free_str), free_bytes);
		printf("%16d Dir(s)	  %14s bytes free\n", dir_count, free_str);
	}

	f_unmount("0:");
}

// Core 1: I2C通信（キーボード）+ printf
static void core1_entry(void) {
	keyboard_init(I2C_PORT, I2C_ADDR);
	sd_init_driver();  // SPI1 + SDカードドライバ初期化

	uint8_t led_state  = 0;
	uint8_t prev_mat11 = 0xFF;	// 前回の matrix[11] (初期値: 全ビット High)

	while (true) {
		keyboard_update(led_state);

//		  printf("Send 0x%02X\n", led_state);
		const uint8_t *matrix = keyboard_get_matrix();
//		  for (int i = 0; i < KEYBOARD_KEY_MATRIX_SIZE; i++) {
//			  printf("Recv[%d] = 0x%02X\n", i, matrix[i]);
//		  }

		// matrix[11] bit0: 1→0 の立ち下がり検出 (キー押下)
		if ((prev_mat11 & 0x01) && !(matrix[11] & 0x01)) {
			dir_sd_root();
		}
		prev_mat11 = matrix[11];

		led_state++;
		sleep_ms(100);
	}
}

// Core 0: SPI通信（FPGAモジュール・SDカード）
int main(void) {

	stdio_init_all();
	i2c0_init();
	spi0_init();
	// SPI1 は sd_init_driver() (Core 1 内) が初期化するため spi1_init() 不要

	multicore_launch_core1(core1_entry);

	// FPGAが起動するまでは取りこぼすのでしばらく待つ
	sleep_ms(500);

	vdp_set_screen1();
	vdp_set_screen1_font();
	vdp_set_screen1_message();
	while (true) {
		fpga_uart_puts("Hello from Pico2W FPGA MSX-TR Controller!\r\n");
		sleep_ms(500);
	}
	return 0;
}
