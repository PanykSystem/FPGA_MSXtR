;
; bootrom.asm
;   BOOT ROM
;   Revision 1.00
;
; Copyright (c) 2026 Takayuki Hara.
; All rights reserved.
;
; Redistribution and use of this source code or any derivative works, are
; permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice,
;    this list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright
;    notice, this list of conditions and the following disclaimer in the
;    documentation and/or other materials provided with the distribution.
; 3. Redistributions may not be sold, nor may they be used in a commercial
;    product or activity without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
; TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
; PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
; OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; ----------------------------------------------------------------------------
; 8KB の BOOT ROM (RAM) で動作するコードです。

; I/O ポートの定義
UART								:= 0x10
BUTTON								:= 0x10

EXTIO_MANUFACTURE					:= 0x40
EXTIO_DEVICE						:= 0x41
CROM_COMMAND						:= 0x42
CROM_DATA							:= 0x43

S2026_REG_IDX						:= 0xE4
S2026_REG_VAL						:= 0xE5
S2026_FR_TIMER_L					:= 0xE6
S2026_FR_TIMER_H					:= 0xE7

; FPGA ConfigROM コマンド
FPGA_CONFIG_ROM_SET_ADDRESS			:= 0x00
FPGA_CONFIG_ROM_SINGLE_READ			:= 0x01
FPGA_CONFIG_ROM_BURST_READ			:= 0x02
FPGA_CONFIG_ROM_BURST_WRITE			:= 0x03
FPGA_CONFIG_ROM_CHIP_ERASE			:= 0x04
FPGA_CONFIG_ROM_READ_STATUS			:= 0x05
FPGA_CONFIG_ROM_SELECT_SROM			:= 0x06
FPGA_CONFIG_ROM_ACCESS_END			:= 0x07
FPGA_CONFIG_ROM_WRITE_ENABLE		:= 0x08
FPGA_CONFIG_ROM_BLOCK_ERASE			:= 0x09
FPGA_CONFIG_ROM_READ_STATUS2		:= 0x0A

				org		0x0000
; ----------------------------------------------------------------------------
;	Initialization
; ----------------------------------------------------------------------------
				di
				ld		sp, 8192 - 2

; ----------------------------------------------------------------------------
;	Wait press the button
; ----------------------------------------------------------------------------
wait_press_button:
				in		a, [BUTTON]
				and		a, 1
				jr		z, wait_press_button
wait_release_button:
				in		a, [BUTTON]
				and		a, 1
				jr		nz, wait_release_button

; ----------------------------------------------------------------------------
;	Send prompt message
; ----------------------------------------------------------------------------
				; Z80/R800 のどちらで動作しているかを調べる
				ld		a, 6
				out		[S2026_REG_IDX], a
				in		a, [S2026_REG_VAL]
				and		a, 0b0010_0000			; bit5: 0=R800, 1=Z80
				jr		z, r800_message
				ld		de, s_z80_message
				jr		skip
	r800_message:
				ld		de, s_r800_message
	skip:
				call	puts

				; ConfigROM へのアクセスポートを出現させる
				ld		a, 0x40
				out		[EXTIO_MANUFACTURE], a
				ld		a, 0x02					; CPU side ConfigROM
				out		[EXTIO_DEVICE], a
				ld		a, FPGA_CONFIG_ROM_SELECT_SROM
				out		[CROM_COMMAND], a
				ld		a, 1
				out		[CROM_DATA], a

				; 000000h - 0000FFh をダンプする
				ld		de, s_dump_process
				call	puts

				ld		e, 0
				call	set_config_rom_address
				ld		l, 0
	dump_loop:
				ld		a, FPGA_CONFIG_ROM_SINGLE_READ
				out		[CROM_COMMAND], a
				in		a, [CROM_DATA]
				call	put_hex8
				ld		a, ' '
				out		[UART], a
				inc		l
				ld		a, l
				and		a, 0x0F
				jr		nz, dump_loop
				ld		de, crlf
				call	puts
				ld		a, l
				or		a, a
				jr		nz, dump_loop
				ld		a, FPGA_CONFIG_ROM_ACCESS_END
				out		[CROM_COMMAND], a

				; 400000h - 40FFFFh に FF 以外があれば消去する
				ld		de, s_erase_process
				call	puts

				ld		hl, 0x0000				; 下位 16bit
				ld		e, 0x40					; 上位 8bit
				call	set_config_rom_address
	erase_check_loop:
				ld		a, FPGA_CONFIG_ROM_SINGLE_READ
				out		[CROM_COMMAND], a
				in		a, [CROM_DATA]
				inc		a						; 0xFF か？
				call	nz, config_rom_block_erase
				inc		hl
				ld		a, h
				or		a, l
				jr		nz, erase_check_loop

				; 400000h - 40FFFFh にインクリメント値を書き込む
				ld		de, s_write_process
				call	puts

				ld		hl, 0x0000				; 下位 16bit
				ld		c, CROM_DATA
	write_loop:
				ld		de, s_write_block
				call	puts
				call	put_hex
				ld		e, 0x40					; 上位 8bit
				call	set_config_rom_address
				call	set_config_rom_write_enable
				ld		a, FPGA_CONFIG_ROM_BURST_WRITE
				out		[CROM_COMMAND], a
	byte_write_loop:
				out		[c], l
				inc		l
				jr		nz, byte_write_loop

				ld		de, s_ok
				call	puts
				inc		h
				jr		nz, write_loop

				; 400000h - 40FFFFh の内容を確認する
				ld		de, s_verify_process
				call	puts

				ld		hl, 0x0000				; 下位 16bit
				ld		c, CROM_DATA
	verify_loop:
				ld		de, s_verify_block
				call	puts
				call	put_hex
				ld		e, 0x40					; 上位 8bit
				call	set_config_rom_address
				ld		a, FPGA_CONFIG_ROM_BURST_READ
				out		[CROM_COMMAND], a
	byte_verify_loop:
				in		a, [c]
				cp		l
				jr		nz, verify_fail
				inc		l
				jr		nz, byte_verify_loop

				ld		de, s_ok
				call	puts
				inc		h
				jr		nz, verify_loop
				jp		finish
	verify_fail:
				ld		de, s_fail
				call	puts
	finish:
				ld		de, s_finish
				call	puts
				jp		change_cpu

; ----------------------------------------------------------------------------
;	ConfigROM のアクセスアドレスをセットする
; ----------------------------------------------------------------------------
				scope	set_config_rom_address
set_config_rom_address::
				ld		a, FPGA_CONFIG_ROM_SET_ADDRESS
				out		[CROM_COMMAND], a
				ld		a, l
				out		[CROM_DATA], a
				ld		a, h
				out		[CROM_DATA], a
				ld		a, e
				out		[CROM_DATA], a
				ret
				endscope

; ----------------------------------------------------------------------------
;	ConfigROM に書き込み許可フラグを設定する
; ----------------------------------------------------------------------------
				scope	set_config_rom_write_enable
set_config_rom_write_enable::
				ld		a, FPGA_CONFIG_ROM_WRITE_ENABLE
				out		[CROM_COMMAND], a
				; 書き込み許可モードに切り替わるのを待つ
				ld		a, FPGA_CONFIG_ROM_READ_STATUS
				out		[CROM_COMMAND], a
	wait_write_enable:
				in		a, [CROM_DATA]
				and		a, 2						; bit1: 1=WRITE_ENABLE, 0=WRITE_DISABLE
				jr		z, wait_write_enable
				ld		a, FPGA_CONFIG_ROM_ACCESS_END
				out		[CROM_COMMAND], a
				ret
				endscope

; ----------------------------------------------------------------------------
;	ConfigROM の指定のアドレスを消去する
; ----------------------------------------------------------------------------
				scope	config_rom_block_erase
config_rom_block_erase::
				; 対象アドレスをセットする
				call	set_config_rom_address
				; 消去許可コマンド
				call	set_config_rom_write_enable
				; ブロック消去コマンド
				ld		a, FPGA_CONFIG_ROM_BLOCK_ERASE
				out		[CROM_COMMAND], a
				; ブロック消去コマンドが完了するのを待つ
				ld		a, FPGA_CONFIG_ROM_READ_STATUS
				out		[CROM_COMMAND], a
	wait_erase:
				in		a, [CROM_DATA]
				and		a, 1						; bit0: 1=BUSY, 0=READY
				jr		nz, wait_erase
				ld		a, FPGA_CONFIG_ROM_ACCESS_END
				out		[CROM_COMMAND], a
				; 消去したアドレスを表示する
				push	hl
				ld		de, s_block_erase_done
				call	puts
				call	put_hex
				ld		de, crlf
				call	puts
				pop		hl
				; 次のアドレスをセットする
				inc		hl
				call	set_config_rom_address
				dec		hl
				ret
				endscope

; ----------------------------------------------------------------------------
;	Change CPU
; ----------------------------------------------------------------------------
change_cpu:
				ld		a, 6
				out		[S2026_REG_IDX], a
				in		a, [S2026_REG_VAL]
				xor		a, 0b0010_0000			; bit5: 0=R800, 1=Z80
				out		[S2026_REG_VAL], a
				nop
				nop
				jp		wait_press_button

; ----------------------------------------------------------------------------
;	Puts message
;	input:
;		de .... message address (ZERO terminated)
;	break:
;		af, de
; ----------------------------------------------------------------------------
				scope	puts
puts::
				ld		a, [de]
				inc		de
				or		a, a
				ret		z
				out		[UART], a
				jr		puts
				endscope

; ----------------------------------------------------------------------------
;	input:
;		hl .... hex number
;	break:
;		af, de
; ----------------------------------------------------------------------------
				scope	put_hex
put_hex::
				ld		a, h
				call	put_hex8
				ld		a, l
				endscope

; ----------------------------------------------------------------------------
;	input:
;		a .... hex number
;	break:
;		af, de
; ----------------------------------------------------------------------------
				scope	put_hex8
put_hex8::
				push	af
				rrca
				rrca
				rrca
				rrca
				call	put_hex8_sub
				pop		af
	put_hex8_sub:
				and		a, 0x0F
				add		a, '0'
				cp		a, '9' + 1
				jr		c, skip1
				add		a, 'A' - '0' - 10
	skip1:
				out		[UART], a
				ret
				endscope

; ----------------------------------------------------------------------------
;	work area
; ----------------------------------------------------------------------------
s_z80_message:
				db		"[Z80]", 0x0D, 0x0A, 0
s_r800_message:
				db		"[R800]", 0x0D, 0x0A, 0
s_dump_process:
				db		"Dump:", 0x0D, 0x0A, 0
s_erase_process:
				db		"Erase:", 0x0D, 0x0A, 0
s_block_erase_done:
				db		"-Erase 0x40", 0
s_write_process:
				db		"Write:", 0x0D, 0x0A, 0
s_write_block:
				db		"-Write 0x40", 0
s_verify_process:
				db		"Verify:", 0x0D, 0x0A, 0
s_verify_block:
				db		"-Verify 0x40", 0
crlf:
				db		0x0D, 0x0A, 0
s_ok:
				db		"-OK", 0x0D, 0x0A, 0
s_fail:
				db		"-NG", 0x0D, 0x0A, 0
s_finish:
				db		"FIN", 0x0D, 0x0A, 0
