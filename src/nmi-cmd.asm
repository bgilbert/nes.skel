;
; nmi-cmd - Commands for NMI (vertical retrace) handler
;
; Copyright (c) 2015-2016 Benjamin Gilbert
;
; Permission is hereby granted, free of charge, to any person obtaining a
; copy of this software and associated documentation files (the "Software"),
; to deal in the Software without restriction, including without limitation
; the rights to use, copy, modify, merge, publish, distribute, sublicense,
; and/or sell copies of the Software, and to permit persons to whom the
; Software is furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
; THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
; DEALINGS IN THE SOFTWARE.
;

; NMI commands
CMD_EOF			= 0	; end of buffer (for run_nmi)
				; args: none
CMD_POKE		= 1	; write value to CPU RAM
				; args: CPU address (2, low byte first), byte
CMD_COPY		= 2	; copy data to PPU
				; args: PPU address (2, high byte first),
				; count (1), data
CMD_STRING		= 3	; copy null-terminated string to PPU
				; args: PPU address (2, high byte first),
				; string address (2, low byte first)
CMD_OAM			= 4	; DMA OAM buffer to OAM
				; args: none
NUM_CMDS		= 5	; number of commands

.section zeropage
cmd_off		.byte ?		; current offset into cmd_buf
nmi_ready	.byte ?		; only for run_nmi and NMI handler
.send

.section bss
.align $100
oam		.fill $100	; OAM buffer copied by CMD_OAM
cmd_buf		.fill $100	; command buffer populated by .cmd/.ccmd
.send

.section prg
; Tell NMI handler we're ready, then wait for it to complete
; Clobbers: A, Y
run_nmi .proc
	; terminate buffer
	ldy cmd_off	; buffer index
	.ccmd #CMD_EOF	; write command

	; enable NMI and wait for it
	.cp #1, nmi_ready ; tell NMI handler to proceed
-	lda nmi_ready	; wait until after NMI
	bne -		; or loop
	.cp #0, cmd_off	; reset cmd_buf offset
	rts
	.pend
.send

; Store A to command buffer indexed by Y; increment Y
cmd	.macro
	sta cmd_buf,y
	iny
	.endm

; Copy value to command buffer indexed by Y; increment Y
; args: value
; Clobbers: A
ccmd	.macro
	lda \1
	.cmd
	.endm
