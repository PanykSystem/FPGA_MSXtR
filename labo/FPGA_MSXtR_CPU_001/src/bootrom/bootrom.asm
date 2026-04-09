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

UART		:= 0x10
BUTTON		:= 0x10

				org		0x0000
; ----------------------------------------------------------------------------
;	Initialization
; ----------------------------------------------------------------------------
				di
				ld		sp, 8192
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
				ld		de, prompt_message
				call	puts
				jr		wait_press_button

; ----------------------------------------------------------------------------
;	Puts message
;	input:
;		de .... message address (ZERO terminated)
;	break:
;		all
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
;	work area
; ----------------------------------------------------------------------------
prompt_message:
				db		"TEST MESSAGE", 0x0D, 0x0A, 0
