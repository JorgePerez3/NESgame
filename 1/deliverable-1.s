.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr 0

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segment for the program
.segment "CODE"

reset:
  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx $4017	; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs		;  .
  inx		; now X = 0
  stx $2000	; disable NMI
  stx $2001 	; disable rendering
  stx $4010 	; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit $2002
  bpl vblankwait1

clear_memory:
  lda #$00
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne clear_memory

;; second wait for vblank, PPU is ready after this
vblankwait2:
  bit $2002
  bpl vblankwait2

main:
load_palettes:
  lda $2002
  lda #$3f
  sta $2006
  lda #$00
  sta $2006
  ldx #$00

@loop:
  lda palettes, x
  sta $2007
  inx
  cpx #$20
  bne @loop

LoadBackground:
  LDA $2002           ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006           ; write the high byte ($20) of $2000 address
  LDA #$00
  STA $2006           ; write the low byte ($00) of $2000 address
  LDX #$00            ; start out at 0

LoadBackgroundLoop:
  LDA background, x   ; load data from address (background + the value in x)
  STA $2007           ; write to PPU
  INX                 ; X++
  BNE LoadBackgroundLoop ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                          ; if compare was equal to 0, keep going down
  LDX #$00            ; start out at 0

LoadBackgroundLoop2:
  LDA background+256, x
  STA $2007
  INX
  BNE LoadBackgroundLoop2
  LDX #$00

LoadBackgroundLoop3:
  LDA background+512, x
  STA $2007
  INX
  BNE LoadBackgroundLoop3
  LDX #$00

LoadBackgroundLoop4:
  LDA background+768, x
  STA $2007
  INX
  BNE LoadBackgroundLoop4



LoadAttribute:
  LDA $2002
  LDA #$23
  STA $2006
  LDA #$C2
  STA $2006
  LDA #$00
LoadAttributeLoop:
  LDA attributes, x
  STA $2007
  INX
  CPX #$08
  BNE LoadAttributeLoop



enable_rendering:
  lda #%10000000	; Enable NMI
  sta $2000
  lda #%00010000	; Enable Sprites
  sta $2001

forever:
  jmp forever

nmi:
  LDA #$00
  STA $2003    ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014    ; set the high byte (02) of the RAM address, start the transfer
  LDA #$00
  STA $2005
  STA $2005

;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000
  STA $2000    ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  LDA #%00011110
  STA $2001    ; enable sprites, enable background, no clipping on left side

  RTI           ; return from interrupt


palettes:
  ; Background Palette
  .byte $0f, $1A, $16, $2D
  .byte $0f, $27, $30, $30
  .byte $0f, $0C, $19, $3D
  .byte $0f, $15, $15, $15

  ; Sprite Palette
  .byte $0f, $20, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  


background:
	.byte $16,$26,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$26,$26,$00,$00,$00,$3c,$3d,$00,$00,$16,$00,$26,$16,$26,$16
	.byte $00,$00,$00,$00,$16,$26,$16,$16,$26,$00,$00,$1a,$1b,$00,$00,$00
	.byte $00,$26,$00,$00,$00,$3c,$1c,$1c,$3d,$00,$00,$00,$00,$00,$00,$26
	.byte $26,$26,$16,$ee,$26,$00,$26,$00,$16,$30,$00,$2a,$2b,$16,$26,$00
	.byte $16,$00,$16,$00,$00,$4c,$1c,$1c,$4d,$00,$26,$00,$00,$00,$16,$26
	.byte $00,$26,$26,$26,$16,$00,$16,$00,$16,$00,$00,$16,$00,$00,$00,$00
	.byte $00,$00,$16,$26,$16,$00,$4c,$4d,$00,$00,$00,$16,$16,$26,$00,$00
	.byte $00,$26,$26,$16,$26,$00,$00,$00,$16,$31,$32,$00,$16,$26,$00,$00
	.byte $00,$26,$00,$26,$26,$00,$00,$00,$00,$26,$00,$26,$26,$16,$16,$16
	.byte $00,$26,$00,$26,$00,$26,$16,$26,$00,$41,$26,$00,$26,$00,$16,$00
	.byte $00,$16,$16,$00,$26,$26,$26,$16,$00,$26,$00,$00,$00,$00,$17,$18
	.byte $00,$00,$26,$00,$00,$16,$00,$26,$00,$00,$26,$26,$00,$16,$26,$00
	.byte $00,$26,$26,$00,$00,$00,$26,$00,$16,$26,$26,$16,$00,$16,$27,$28
	.byte $00,$16,$26,$00,$16,$00,$00,$26,$26,$00,$00,$26,$26,$26,$00,$00
	.byte $16,$00,$00,$00,$26,$16,$00,$00,$00,$00,$00,$16,$00,$26,$00,$16
	.byte $62,$63,$00,$16,$26,$00,$16,$00,$00,$00,$00,$26,$26,$26,$16,$00
	.byte $00,$00,$00,$16,$00,$16,$16,$26,$26,$26,$00,$16,$16,$16,$26,$00
	.byte $26,$73,$26,$00,$00,$16,$26,$16,$26,$00,$16,$00,$00,$26,$00,$00
	.byte $26,$16,$26,$00,$00,$00,$00,$16,$00,$00,$00,$26,$16,$26,$00,$26
	.byte $26,$00,$26,$26,$00,$26,$16,$00,$00,$26,$16,$26,$00,$26,$00,$00
	.byte $00,$00,$26,$26,$00,$26,$00,$26,$26,$00,$26,$16,$16,$26,$26,$00
	.byte $16,$00,$26,$26,$26,$26,$00,$00,$00,$00,$00,$00,$00,$26,$00,$00
	.byte $00,$00,$26,$16,$16,$00,$26,$16,$16,$26,$16,$00,$00,$00,$26,$00
	.byte $00,$26,$00,$16,$16,$00,$00,$16,$16,$26,$00,$16,$26,$26,$00,$00
	.byte $16,$00,$16,$26,$16,$00,$00,$00,$00,$00,$16,$00,$00,$00,$16,$00
	.byte $16,$00,$16,$00,$00,$00,$00,$26,$26,$00,$00,$16,$00,$16,$00,$00
	.byte $00,$26,$00,$26,$16,$00,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$00,$16,$00,$26,$26,$00,$00,$00
	.byte $00,$16,$00,$26,$00,$00,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$00,$00,$00,$26,$00,$00,$26,$00
	.byte $00,$26,$16,$16,$16,$00,$00,$4c,$4d,$4c,$4d,$4c,$4d,$4c,$4d,$4c
	.byte $4d,$4c,$4d,$4c,$4d,$4c,$4d,$00,$00,$16,$00,$16,$16,$26,$26,$00
	.byte $26,$16,$00,$00,$16,$26,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$26,$26,$00,$16,$00,$26,$26,$00
	.byte $00,$26,$26,$00,$26,$00,$16,$26,$00,$26,$00,$00,$26,$16,$16,$00
	.byte $26,$00,$26,$26,$26,$00,$16,$00,$00,$26,$00,$00,$26,$00,$26,$00
	.byte $00,$26,$00,$16,$16,$00,$26,$26,$16,$26,$26,$00,$16,$26,$00,$00
	.byte $26,$26,$00,$00,$26,$26,$26,$26,$00,$26,$00,$26,$26,$16,$26,$00
	.byte $00,$16,$26,$00,$16,$16,$26,$00,$00,$00,$26,$00,$16,$26,$16,$00
	.byte $00,$26,$16,$16,$00,$16,$00,$16,$00,$26,$16,$16,$16,$26,$16,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$16,$00,$00,$16,$00
	.byte $00,$26,$26,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte $55,$54,$54,$55,$55,$55,$55,$51,$55,$55,$55,$95,$55,$55,$55,$55
	.byte $55,$55,$55,$55,$55,$55,$55,$15,$55,$15,$05,$05,$05,$05,$55,$51
	.byte $55,$51,$50,$50,$50,$50,$55,$55,$05,$05,$05,$05,$05,$05,$05,$05
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00








attributes:
.byte $55,$55,$55,$55,$55,$55,$55,$55  ;%01010101
.byte $55,$55,$55,$15,$55,$55,$55,$55
.byte $55,$55,$55,$55,$55,$55,$55,$55



.segment "CHARS"
.incbin "../chr/newBackground.chr"

