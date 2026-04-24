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
VDP_PORT0			:= 0x98
VDP_PORT1			:= 0x99
VDP_PORT2			:= 0x9A
VDP_PORT3			:= 0x9B
VDP_PORT4			:= 0x9C

				org		0x0000
; ----------------------------------------------------------------------------
;	Initialization
; ----------------------------------------------------------------------------
				di
				ld		sp, 8192 - 2

; ----------------------------------------------------------------------------
;	INITIALIZE SCREEN MODE
; ----------------------------------------------------------------------------
				scope	set_screen1
set_screen1::
				ld		hl, vdp_registers
				ld		c, VDP_PORT1
	loop:
				ld		a, [hl]
				inc		a
				jr		z, exit_loop
				dec		a
				or		a, 0x80
				inc		hl
				ld		b, [hl]
				inc		hl
				out		[c], b
				out		[c], a
				jr		loop
	exit_loop:
				endscope

; ----------------------------------------------------------------------------
;	SETUP VRAM
; ----------------------------------------------------------------------------
				scope	setup_vram
setup_vram::
				; set font data
				ld		hl, font_data
				ld		de, 0x0000 + 0x20 * 8
				ld		bc, (0x80-0x20) * 8
				call	write_vram_block
				; set others
				ld		hl, 0x1800
				ld		de, 0x4000-0x1800
				ld		b, 0
				call	fill_vram
				; set sprite attribute
				ld		hl, 0x1C00
				ld		de, 32 * 4
				ld		b, 208
				call	fill_vram
				; set color
				ld		hl, 0x2000
				ld		de, 32
				ld		b, 0xF4
				call	fill_vram
				endscope

; ----------------------------------------------------------------------------
;	MAIN LOOP
; ----------------------------------------------------------------------------
				scope	main
main::
				halt
				endscope

; ----------------------------------------------------------------------------
;	FILL VRAM
;	input:
;		hl .... target VRAM address
;		de .... length
;		b ..... fill data
;	break:
;		hl, bc, de, af
; ----------------------------------------------------------------------------
				scope	fill_vram
fill_vram::
				ld		c, VDP_PORT1
				ld		a, l
				out		[c], a
				ld		a, h
				and		a, 0x3F
				or		a, 0x40
				out		[c], a
				dec		c
	loop:
				out		[c], b
				dec		de
				ld		a, e
				or		a, d
				jr		nz, loop
				ret
				endscope

; ----------------------------------------------------------------------------
;	WRITE VRAM BLOCK
;	input:
;		hl .... target CPU MEMORY address
;		de .... target VRAM address
;		bc .... length
;	break:
;		hl, bc, de, af
; ----------------------------------------------------------------------------
				scope	write_vram_block
write_vram_block::
				ld		a, e
				out		[VDP_PORT1], a
				ld		a, d
				and		a, 0x3F
				or		a, 0x40
				out		[VDP_PORT1], a
	loop:
				ld		a, [hl]
				inc		hl
				out		[VDP_PORT0], a
				dec		bc
				ld		a, c
				or		a, b
				jr		nz, loop
				ret
				endscope

; ----------------------------------------------------------------------------
;	REGISTERS
; ----------------------------------------------------------------------------
vdp_registers::
				; mode registers
				db		0 , 0x00
				db		1 , 0x40
				db		8 , 0x08
				db		9 , 0x00
				db		20, 0x00
				db		21, 0x3b
				db		22, 0x05
				; table base registers
				db		2 , 0x06
				db		3 , 0x80
				db		10, 0x00
				db		4 , 0x00
				db		5 , 0x36
				db		11, 0x00
				db		6 , 0x07
				; color registers
				db		7 , 0x07
				db		12, 0x07
				db		13, 0x07
				; display registers
				db		18, 0x00
				db		19, 0x00
				db		23, 0x00
				; access registers
				db		14, 0x00
				db		15, 0x00
				db		16, 0x00
				db		17, 0x1c
				; v9958 registers
				db		25, 0x00
				db		26, 0x00
				db		27, 0x00
				; terminator
				db		255
				include	"zg6x8_font.asm"
