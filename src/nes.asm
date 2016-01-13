;
; nes - Generic NES support
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

.cpu "6502i"

prg_banks = (prg_end - prg_start) / 16384
chr_banks = (chr_end - chr_start) / 8192

; iNES header
.byte	$4e, $45, $53, $1a	; Magic
.byte	prg_banks		; PRG ROM size, 16 KB units
.byte	chr_banks		; CHR ROM size, 8 KB units
.fill	10

; PRG ROM
prg_start =	*
.logical $8000
.dsection prg
.cerror	* < $8000 || * >= $fffa, "Incorrect PRG ROM size"
* =	$fffa
.word	nmi, reset, irq		; interrupt vectors
.here
prg_end =	*

; BSS (zeroed CPU RAM)
.logical 0
.dsection zeropage
.cerror	* > $100
.here
.logical $200
.dsection bss
.cerror * > $7ff
.here

; CHR ROM
* =		prg_end		; don't include BSS in object file
chr_start =	*
.logical 0
.dsection chr
.align	$2000, 0
.cerror * != $2000, "Incorrect CHR ROM size"
.here
chr_end =	*

; I/O registers in CPU address space
PPUCTRL =	$2000
PPUMASK =	$2001
PPUSTATUS =	$2002
OAMADDR =	$2003
OAMDATA =	$2004
PPUSCROLL =	$2005
PPUADDR =	$2006
PPUDATA =	$2007
OAMDMA =	$4014

; Buffers in PPU address space
NAMETABLE_0 =	$2000
NAMETABLE_1 =	$2400
NAMETABLE_2 =	$2800
NAMETABLE_3 =	$2c00
PALETTE_BG =	$3f00
PALETTE_SPRITE = $3f10

; Useful constants
PPUMASK_NORMAL = $1e

; Game controller bit numbers
BTN_A =		7
BTN_B =		6
BTN_SELECT =	5
BTN_START =	4
BTN_UP =	3
BTN_DOWN =	2
BTN_LEFT =	1
BTN_RIGHT =	0

; Init
.section zeropage
temp_addr	.word ?
.send

.section prg
reset	.proc
	; Force interrupts off (for soft reset)
	sei		; Disable CPU interrupts if enabled
	lda #0
	sta PPUCTRL	; Disable PPU NMI (if PPU already warm)
	sta $4015	; Disable APU channels
	sta $4010	; Disable APU DMC interrupt
	.cp #$40, $4017 ; Disable APU frame interrupt
	cli		; Re-enable interrupts

	; Set up CPU
	cld		; disable BCD (inert but recommended)
	ldx #$ff
	txs		; set stack pointer

	; Wait for first half of PPU warmup
	bit PPUSTATUS	; clear PPUSTATUS VBL
-	bit PPUSTATUS	; check PPUSTATUS VBL
	bpl -		; loop until set

	; Now that we're in vblank, disable rendering if PPU is already warm
	lda #0
	sta PPUMASK	; disable rendering

	; Clear CPU RAM
	sta temp_addr	; low byte of base address
	sta temp_addr + 1 ; high byte of base address
	ldx #0		; high byte of base address (reg)
	ldy #0		; index
-	sta (temp_addr),y ; write byte
	iny		; increment index
	bne -		; loop until Y overflows
	inx		; increment base address (high byte)
	stx temp_addr + 1 ; and store it
	cpx #8		; we're done at $0800
	bne -		; loop if not done

	; Wait for rest of PPU warmup
-	bit PPUSTATUS	; check PPUSTATUS VBL
	bpl -		; loop until set

	; Clear palette RAM
	bit PPUSTATUS	; clear address latch
	.cp #>PALETTE_BG, PPUADDR ; palette RAM address high byte
	.cp #<PALETTE_BG, PPUADDR ; palette RAM address low byte
	ldx #$20	; size of palette RAM
	lda #0		; data value
-	sta PPUDATA	; write byte
	dex		; decrement counter
	bne -		; continue until done

	jmp start
	.pend

; Copy value to location, clobbering A
; args: value, location
cp	.macro
	lda \1
	sta \2
	.endm

.send
