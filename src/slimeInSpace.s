PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
PPUADDR   = $2006
PPUDATA   = $2007
OAMADDR   = $2003
OAMDMA    = $4014


.segment "HEADER"
.byte $4e, $45, $53, $1a ; Magic string that always begins an iNES header
.byte $02        ; Number of 16KB PRG-ROM banks
.byte $01        ; Number of 8KB CHR-ROM banks
.byte %00000000  ; Horizontal mirroring, no save RAM, no mapper
.byte %00000000  ; No special-case flags set, no mapper
.byte $00        ; No PRG-RAM present
.byte $00        ; NTSC format
      ; mapper 0, vertical mirroring

.segment "ZEROPAGE"
  player_x: .res 1
  player_y: .res 1
  player_dir: .res 1
  pad1: .res 1
  
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

LDA #$80
STA player_x
LDA #$a0
STA player_y


.proc read_controller1
  PHA
  TXA
  PHA
  PHP

  ; write a 1, then a 0, to CONTROLLER1
  ; to latch button states
  LDA #$01
  STA CONTROLLER1
  LDA #$00
  STA CONTROLLER1

  LDA #%00000001
  STA pad1

get_buttons:
  LDA CONTROLLER1 ; Read next button's state
  LSR A           ; Shift button state right, into carry flag
  ROL pad1        ; Rotate button state from carry flag
                  ; onto right side of pad1
                  ; and leftmost 0 of pad1 into carry flag
  BCC get_buttons ; Continue until original "1" is in carry flag

  PLP
  PLA
  TAX
  PLA
  RTS
.endproc


nmi:
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA
  LDA #$00

; update tiles *after* DMA transfer
JSR update_player
JSR draw_player

STA $2005
STA $2005
;This is the PPU clean up section, so rendering the next frame starts properly.
LDA #%10010000
STA $2000    ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
LDA #%00011110
STA $2001    ; enable sprites, enable background, no clipping on left side

RTI           ; return from interrupt

; RTI

reset:
    SEI
  CLD
  LDX #$00
  STX PPUCTRL
  STX PPUMASK

vblankwait:
  BIT PPUSTATUS
  BPL vblankwait

	LDX #$00
	LDA #$ff
clear_oam:
	STA $0200,X ; set sprite y-positions off the screen
	INX
	INX
	INX
	INX
	BNE clear_oam

vblankwait2:
	BIT PPUSTATUS
	BPL vblankwait2

	; initialize zero-page values
	LDA #$80
	STA player_x
	LDA #$a0
	STA player_y

  JMP main

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


.proc update_player
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA player_x
  CMP #$e0
  BCC not_at_right_edge
  ; if BCC is not taken, we are greater than $e0
  LDA #$00
  STA player_dir    ; start moving left
  JMP direction_set ; we already chose a direction,
                    ; so we can skip the left side check
not_at_right_edge:
  LDA player_x
  CMP #$10
  BCS direction_set
  ; if BCS not taken, we are less than $10
  LDA #$01
  STA player_dir   ; start moving right
direction_set:
  ; now, actually update player_x
  LDA player_dir
  CMP #$01
  BEQ move_right
  ; if player_dir minus $01 is not zero,
  ; that means player_dir was $00 and
  ; we need to move left
  DEC player_x
  JMP exit_subroutine
move_right:
  INC player_x
exit_subroutine:
  ; all done, clean up and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_player
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; write player ship tile numbers
  LDA #$11
  STA $0201
  LDA #$12
  STA $0205
  LDA #$21
  STA $0209
  LDA #$22
  STA $020d

  ; write player ship tile attributes
  ; use palette 0
  LDA #$01
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  ; store tile locations
  ; top left tile:
  LDA player_y
  STA $0200
  LDA player_x
  STA $0203

  ; top right tile (x + 8):
  LDA player_y
  STA $0204
  LDA player_x
  CLC
  ADC #$08
  STA $0207

  ; bottom left tile (y + 8):
  LDA player_y
  CLC
  ADC #$08
  STA $0208
  LDA player_x
  STA $020b

  ; bottom right tile (x + 8, y + 8)
  LDA player_y
  CLC
  ADC #$08
  STA $020c
  LDA player_x
  CLC
  ADC #$08
  STA $020f




  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

palettes:
  ; Background Palette
  .byte $0f, $1A, $16, $2D
  .byte $0f, $27, $30, $30
  .byte $0f, $0C, $19, $3D
  .byte $0f, $15, $15, $15

  ; Sprite Palette
  .byte $0f, $00, $10, $30
  .byte $0f, $01, $21, $31
  .byte $0f, $06, $16, $26
  .byte $0f, $09, $19, $29
  
sprites: ; pos_Y, Tile, attr, pos_X
.byte $55, $11, $1, $14 ; idle
.byte $55, $12, $1, $1c
.byte $5d, $21, $1, $14
.byte $5d, $22, $1, $1c

.byte $55, $13, $01, $24 ; idle movement
.byte $55, $14, $01, $2c
.byte $5d, $23, $01, $24
.byte $5d, $24, $01, $2c

.byte $55, $15, $01, $34 ; jump 
.byte $55, $16, $01, $3c
.byte $5d, $25, $01, $34
.byte $5d, $26, $01, $3c

.byte $55, $17, $41, $4c ; looking left
.byte $55, $18, $41, $44
.byte $5d, $27, $41, $4c
.byte $5d, $28, $41, $44

.byte $45, $17, $01, $54 ; looking right
.byte $45, $18, $01, $5c
.byte $4d, $27, $01, $54
.byte $4d, $28, $01, $5c

.byte $45, $31, $01, $44 ; dead
.byte $45, $32, $01, $4c
.byte $4d, $41, $01, $44
.byte $4d, $42, $01, $4c

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
.incbin "../chr/spriteAndBg.chr"

