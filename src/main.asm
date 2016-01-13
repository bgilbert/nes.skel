;
; main - NES main program
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

.include "nes.asm"
.include "nmi-cmd.asm"
.include "nmi-impl.asm"

.section chr
.include "../chr/chr.asm"
.send

.section prg
palette
	; background
	.byte $0f, $20, $20, $20
	.byte $0f, $20, $20, $20
	.byte $0f, $20, $20, $20
	.byte $0f, $20, $20, $20
	; sprites
	.byte $0f, $20, $20, $20
	.byte $0f, $20, $20, $20
	.byte $0f, $20, $20, $20
	.byte $0f, $20, $20, $20

hello	.null "Hello world."

start	.proc
	.cp #0, nmi_ready ; disable NMI handler (for soft reset)
	.cp #0, cmd_off	; init cmd_buf offset
	.cp #$80, PPUCTRL ; configure PPU; enable NMI

	; copy background and sprite palettes
	; (not via NMI, since rendering isn't enabled yet)
	bit PPUSTATUS	; clear address latch
	.cp #>PALETTE_BG, PPUADDR ; address high
	.cp #<PALETTE_BG, PPUADDR ; address low
	ldx #0		; loop counter
-	lda palette,x	; get palette value
	sta PPUDATA	; write it
	inx		; increment
	cpx #$20	; are we done?
	bne -		; no; continue

	; initialize OAM buffer and OAM
	ldx #0		; counter
	clc		; clear carry
-	lda #$ff	; Y coordinate (off-screen)
	sta oam,x	; store
	lda #0
	sta oam + 1,x	; store glyph 0
	sta oam + 2,x	; store no attributes
	sta oam + 3,x	; store X coordinate
	txa		; get counter
	adc #4		; increment for next sprite
	tax		; put back
	bne -		; continue until done
	ldy cmd_buf	; get cmd_buf offset
	.ccmd #CMD_OAM	; copy OAM buf to OAM

	; copy message to PPU nametable
	hello_ppu_addr = NAMETABLE_0 + 14 * 32 + 10
	.ccmd #CMD_STRING ; string command
	.ccmd #>hello_ppu_addr ; PPU address high
	.ccmd #<hello_ppu_addr ; PPU address low
	.ccmd #<hello	; string address low
	.ccmd #>hello	; string address high

	; enable render via NMI to ensure we don't do it mid-frame
	.ccmd #CMD_POKE	; command
	.ccmd #<PPUMASK	; addr low byte
	.ccmd #>PPUMASK	; addr high byte
	.ccmd #PPUMASK_NORMAL ; enable rendering
	sty cmd_off	; update offset

main	jsr run_nmi	; wait for NMI
	jmp main	; continue main loop
	.pend

irq	.proc
	jmp reset	; can't happen, so give up
	.pend
.send
