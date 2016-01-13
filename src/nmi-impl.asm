;
; nmi-impl - NMI (vertical retrace) handler
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

.section zeropage
nmi_addr	.word ?	; scratch space
.send

.section prg
nmi_table
	; On entry: cmd_off loaded into Y
	; Handler must update cmd_off
	.word nmi_poke - 1
	.word nmi_copy - 1
	.word nmi_string - 1
	.word nmi_oam - 1
	.word reset - 1		; must be last!

nmi	.proc
	pha		; push A
	txa		; <- X
	pha		; push X
	tya		; <- Y
	pha		; push Y

	; see if we should run
	lda nmi_ready	; get ready flag
	beq done	; test
	.cp #0, nmi_ready ; clear ready flag

	; walk command buffer
	ldy #0		; load new command offset
	sty cmd_off	; and store it
	beq next	; start loop
-	cmp #NUM_CMDS	; out-of-bounds command?
	bcc +		; no; jump
	lda #NUM_CMDS	; reset handler
+	jsr cmd_dispatch; dispatch
	ldy cmd_off	; load offset into buffer
next	lda cmd_buf,y	; get command
	bne -		; continue until command 0

	; reset scroll after update
	bit PPUSTATUS	; clear address latch
	lda #0
	sta PPUSCROLL
	sta PPUSCROLL

	; return
done	pla		; pop Y
	tay		; -> Y
	pla		; pop X
	tax		; -> X
	pla		; pop A
	rti
	.pend

; dispatch a command
; A - command byte
cmd_dispatch .proc
	asl		; double command for table offset
	tax		; copy to X
	lda nmi_table - 1,x ; get high byte of subroutine addr
	pha		; push it
	lda nmi_table - 2,x ; get low byte
	pha		; push it
	rts		; call
	.pend

nmi_poke .proc
	; get addr + data and store it
	lda cmd_buf + 1,y ; address low byte
	sta nmi_addr	; store it
	lda cmd_buf + 2,y ; address high byte
	sta nmi_addr + 1 ; store it
	lda cmd_buf + 3,y ; data byte
	ldx #0		; offset for indirect addressing
	sta (nmi_addr,x) ; store the byte

	; update offset
	tya		; get offset
	clc		; clear carry
	adc #4		; add command size
	sta cmd_off	; store offset
	rts
	.pend

nmi_copy .proc
	; set nametable address
	bit PPUSTATUS	; clear address latch
	lda cmd_buf + 1,y ; get nametable.H
	sta PPUADDR	; write it
	lda cmd_buf + 2,y ; get nametable.L
	sta PPUADDR	; write it

	; get counter
	lda cmd_buf + 3,y ; get counter
	tax		; put in X

	; write data until multiple of 16 bytes remaining
	tya		; get offset
	clc		; clear carry
	adc #4		; add size of header
	tay		; put back in Y
	bne +		; start loop
-	lda cmd_buf,y	; load byte
	sta PPUDATA	; write it
	dex		; decrement remaining count
	iny		; increment offset
	txa		; copy counter to A
+	and #$0f	; continue until a multiple of 16 bytes
	bne -		; repeat until done

	; write data 16 bytes at a time
	txa		; get remaining count
	beq done	; skip if already done
	lsr		; divide by 16
	lsr
	lsr
	lsr
	tax		; and put it back
-	lda cmd_buf,y	; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 1,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 2,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 3,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 4,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 5,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 6,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 7,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 8,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 9,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 10,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 11,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 12,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 13,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 14,y ; load byte
	sta PPUDATA	; write it
	lda cmd_buf + 15,y ; load byte
	sta PPUDATA	; write it
	tya		; get offset
	adc #16		; increment (assumes carry clear)
	tay		; put back in Y
	dex		; decrement count of remaining blocks
	bne -		; repeat until done

	; update cmd_off
done	sty cmd_off	; store offset
	rts
	.pend

nmi_string .proc
	; get arguments
	bit PPUSTATUS	; clear latch
	lda cmd_buf + 1,y ; PPU address high byte
	sta PPUADDR	; store it
	lda cmd_buf + 2,y ; PPU address low byte
	sta PPUADDR	; store it
	lda cmd_buf + 3,y ; string address low byte
	sta nmi_addr ; store it
	lda cmd_buf + 4,y ; string address high byte
	sta nmi_addr + 1 ; store it

	; update offset
	tya		; get offset
	clc		; clear carry
	adc #5		; add command size
	sta cmd_off	; store offset

	; print line
	ldy #0		; initialize index
	jmp +		; start loop
-	sta PPUDATA	; store character
	iny		; increment index
+	lda (nmi_addr),y ; load character
	bne -		; continue until NUL
	rts
	.pend

nmi_oam .proc
	.cp #0, OAMADDR	; start at bottom of OAM
	.cp #>oam, OAMDMA ; DMA OAM buffer to OAM
	iny		; increment counter for command byte
	sty cmd_off	; update offset
	rts
	.pend
.send
