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

UART				:= 0x10
BUTTON				:= 0x10
S2026_REG_IDX		:= 0xE4
S2026_REG_VAL		:= 0xE5
S2026_FR_TIMER_L	:= 0xE6
S2026_FR_TIMER_H	:= 0xE7

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
;	SRAM TEST
; ----------------------------------------------------------------------------
;				ld		bc, 0x1000		; RAM TOP ADDRESS
;	loop_address:
;				ld		l, c
;				ld		h, b
;				jp		put_hex
;	ret_address1:
;				xor		a, a
;	loop_data:
;				ld		[hl], a
;				cp		a, [hl]
;				jp		nz, fail
;				inc		a
;				jr		nz, loop_data
;	ok:
;				ld		hl, ret_address2
;				ld		de, s_ok
;				jp		puts
;	fail:
;				ld		hl, ret_address2
;				ld		de, s_fail
;				jp		puts
;	ret_address2:
;				inc		bc
;				ld		a, c
;				cp		a, 0x00
;				jr		nz, loop_address
;				ld		a, b
;				cp		a, 0x20
;				jr		nz, loop_address
;				halt

; ----------------------------------------------------------------------------
;	Send prompt message
; ----------------------------------------------------------------------------
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
				; puts "*"
				ld		b, 1
	loop:
				ld		de, asterisk
				call	puts
				ld		hl, 650
	wait_loop:
				nop
				nop
				nop
				nop
				dec		hl
				ld		a, l
				or		a, h
				jr		nz, wait_loop
				djnz	loop
				ld		de, crlf
				call	puts
; ----------------------------------------------------------------------------
;	Change CPU
; ----------------------------------------------------------------------------
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
;		hl .... return address
;	break:
;		af, de
; ----------------------------------------------------------------------------
				scope	puts
puts::
				ld		a, [de]
				inc		de
				or		a, a
				jp		z, _skip
				out		[UART], a
				jr		puts
	_skip:
				ret
				endscope

; ----------------------------------------------------------------------------
;	input:
;		hl .... hex number
;	break:
;		af, de, hl
; ----------------------------------------------------------------------------
				scope	put_hex
put_hex::
				ld		a, h
				rrca
				rrca
				rrca
				rrca
				and		a, 0x0F
				add		a, '0'
				cp		a, '9' + 1
				jr		c, skip1
				add		a, 'A' - '0' - 10
	skip1:
				out		[UART], a

				ld		a, h
				and		a, 0x0F
				add		a, '0'
				cp		a, '9' + 1
				jr		c, skip2
				add		a, 'A' - '0' - 10
	skip2:
				out		[UART], a

				ld		a, l
				rrca
				rrca
				rrca
				rrca
				and		a, 0x0F
				add		a, '0'
				cp		a, '9' + 1
				jr		c, skip3
				add		a, 'A' - '0' - 10
	skip3:
				out		[UART], a

				ld		a, l
				and		a, 0x0F
				add		a, '0'
				cp		a, '9' + 1
				jr		c, skip4
				add		a, 'A' - '0' - 10
	skip4:
				out		[UART], a
				ret
				endscope

; ----------------------------------------------------------------------------
;	work area
; ----------------------------------------------------------------------------
s_z80_message:
				db		"THIS IS Z80", 0x0D, 0x0A, 0
s_r800_message:
				db		"THIS IS R800", 0x0D, 0x0A, 0
asterisk:
				db		"*", 0
crlf:
				db		0x0D, 0x0A, 0
s_ok:
				db		"-OK", 0x0D, 0x0A, 0
s_fail:
				db		"-FAILED", 0x0D, 0x0A, 0
