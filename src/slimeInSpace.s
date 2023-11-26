PPUCTRL               = $2000
PPUMASK               = $2001
PPUSTATUS             = $2002
PPUDATA               = $2007
OAMADDR               = $2003
OAMDMA                = $4014
BTN_RIGHT             = %00000001
BTN_LEFT              = %00000010
BTN_DOWN              = %00000100
BTN_UP                = %00001000
BTN_START             = %00010000
BTN_SELECT            = %00100000
BTN_B                 = %01000000
BTN_A                 = %10000000

controller1           = $4016
controller2           = $4017
tmp                   = $07
Pressing              = $06 

NumberOfSprites       = $09 
TotalSprites          = 9   

SpriteRAM             = $0200 
CollisionRAM          = $0700

PlayerRam1            = $0201
PlayerRam2            = $0205
PlayerRam3            = $0209
PlayerRam4            = $020d
delay                 = $0f
DelayTime             = 60
IsWalking             = $12 
WalkCycleFrame        = $10
WalkCycleCounter      = $11
WalkCycleTimePerFrame = 60

idleState             = $3d
idleTimer             = $3e

motionState           = $3a 

.enum IdleState
  Still = 0
  Breathe = 1
.endenum

.enum MotionState
  Still = 0
  Walk = 1
  Airborne = 2
.endenum

.segment "HEADER"
.byte $4e, $45, $53, $1a ; String that begins an iNES header
.byte $02         ; Number of 16KB PRG-ROM banks
.byte $01         ; Number of 8KB CHR-ROM banks
.byte %00000000   ; Horizontal mirroring, no save RAM, no mapper
.byte %00000000   ; No special-case flags set, no mapper
.byte $00         ; No PRG-RAM present
.byte $00         ; NTSC format
                  ; mapper 0, vertical mirroring

.segment "ZEROPAGE"
  PlayerXPos: .res 1
  PlayerYPos: .res 1
  player_dir: .res 1
  pad1: .res 1
  
.segment "VECTORS"
  .addr nmi
  .addr reset
  .addr 0

.segment "STARTUP"

.segment "CODE"


nmi:
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA
  LDA #$00
  STA $2005
  ;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000
  STA $2000    ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  LDA #%00011110
  STA $2001 

  JSR DrawPlayer
  JSR CheckWalkCycle
  JSR CheckController 



   ; enable sprites, enable background, no clipping on left side

RTI           ; return from interrupt

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

ClearRAM:
	LDA #$00
	STA $0000, x
	STA $0100, x
	STA $0200, x
	STA $0300, x
	STA $0400, x
	STA $0500, x
	STA $0600, x
	STA $0700, x
	LDA #$FE
	STA SpriteRAM, x                ; Moving sprites off the screen 
	INX
	BNE ClearRAM

ClearOam:
	STA $0200,X ; set sprite y-positions off the screen
	INX
	INX
	INX
	INX
	BNE ClearOam

vblankwait2:
	BIT PPUSTATUS
	BPL vblankwait2

  ; initialize zero-page values
	LDA #$80
	STA PlayerXPos
	LDA #$9f
	STA PlayerYPos

  JMP main

main:


LoadSprites:
  LDA #TotalSprites
  ASL 
  ASL 
  STA NumberOfSprites
  LDX #$00
LoadSpritesLoop:
  LDA sprites, x 
  STA SpriteRAM, x 
  INX
  CPX NumberOfSprites
  BNE LoadSpritesLoop

LoadPalettes:
  LDA $2002
  LDA #$3f
  STA $2006
  LDA #$00
  STA $2006
  LDX #$00

@loop:
  LDA palettes, x
  STA $2007
  inx
  CPX #$20
  BNE @loop

LoadBackground:
  LDA $2002               ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006               ; write the high byte ($20) of $2000 address
  LDA #$00
  STA $2006               ; write the low byte ($00) of $2000 address
  LDX #$00                ; start out at 0

LoadBackgroundLoop:
  LDA background, x       ; load data from address (background + the value in x)
  STA $2007               ; write to PPU
  INX                     ; X++
  BNE LoadBackgroundLoop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                          ; if compare was equal to 0, keep going down
  LDX #$00                ; start out at 0

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

enable_rendering:
  LDA #%10000000	; Enable NMI
  STA $2000
  LDA #%00010000	; Enable Sprites
  STA $2001

forever:
  JMP forever

CheckController:
	LDA #$01 
	STA $4016             ; Strobing thew controller 
	LDX #$00
	STX $4016             ; Latching controller state 
ConLoop:
	LDA $4016  
	LSR 
	ROR Pressing          ; RLDUsSBA 
	INX
	CPX #$08
	BNE ConLoop
CheckRight:
	LDA #%10000000
	AND Pressing
	BEQ CheckLeft
	JSR MovePlayerRight 
CheckLeft:
	LDA #%01000000
	AND Pressing 
	BEQ CheckDown
	JSR MovePlayerLeft
CheckDown:
	LDA #%00100000
	AND Pressing
	BEQ CheckUp
	JSR MovePlayerDown
CheckUp:
	LDA #%00010000
	AND Pressing
	BEQ EndController
	JSR MovePlayerUp
EndController:
	RTS 



MovePlayerRight:
LookRight:
  LDA #$17
  STA PlayerRam1
  LDA #18
  STA PlayerRam2
  LDA #$27
  STA PlayerRam3
  LDA #$28
  STA PlayerRam4
  LDA #%00000001
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  INC PlayerXPos
  LDX PlayerXPos
  LDY PlayerYPos
  JSR CheckCollision
  BEQ :+
  DEC PlayerXPos

:
  LDA #$01
  STA IsWalking

  RTS


MovePlayerLeft:

LookLeft:
  LDA #$17
  STA PlayerRam2
  LDA #$18
  STA PlayerRam1
  LDA #$27
  STA PlayerRam4
  LDA #$28
  STA PlayerRam3

  LDA #%01000001
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  DEC PlayerXPos
  LDX PlayerXPos
  LDY PlayerYPos
  JSR CheckCollision
  BEQ :+
  INC PlayerXPos
:
  LDA #$01
  STA IsWalking

  RTS


MovePlayerDown:

  INC PlayerYPos
  LDX PlayerXPos
  LDY PlayerYPos
  JSR CheckCollision
  BEQ :+
  DEC PlayerYPos
:
  LDA #$01
  STA IsWalking

  RTS


MovePlayerUp:

  DEC PlayerYPos
  LDX PlayerXPos
  LDY PlayerYPos
  JSR CheckCollision
  BEQ :+
  INC PlayerYPos
:
  LDA #$01
  STA IsWalking

  RTS

CheckWalkCycle:
  LDA IsWalking
  BEQ NotWalking
  DEC IsWalking

  ; INC WalkCycleCounter
  ; LDA WalkCycleCounter

  ; CMP #WalkCycleTimePerFrame

  ; BNE :+ 
  ; LDA #$00
  ; STA WalkCycleCounter

  ; LDA #$13
  ; STA PlayerRam2
  ; LDA #$14
  ; STA PlayerRam1
  ; LDA #$23
  ; STA PlayerRam4
  ; LDA #$24
  ; STA PlayerRam3

;   INC WalkCycleFrame
;  :
 NotWalking: 
  ; LDA #$00
	; STA WalkCycleFrame
	; STA WalkCycleCounter
  LDA WalkCycleCounter
  INC WalkCycleCounter
  CMP #WalkCycleTimePerFrame
  BNE :+
  LDA #$00
  STA WalkCycleCounter

  LDA #$13
  STA PlayerRam1
  LDA #$14
  STA PlayerRam2
  LDA #$23
  STA PlayerRam3
  LDA #$24
  STA PlayerRam4

:
  RTS


.proc UpdateIdleState
  LDA motionState
  CMP #MotionState::Still
  BEQ @update_timer
  LDA timers
  STA idleTimer
  LDA #IdleState::Still
  STA idleState
  RTS
@update_timer:
  DEC idleTimer
  BEQ @update_state
  RTS
@update_state:
  LDX idleState
  inx
  CPX #4
  BNE @set_state
  LDX #0
@set_state:
  STX idleState
  LDA timers, x
  STA idleTimer
  RTS
timers:
  .byte 245, 10, 10, 10
.endproc

; ; X/64 + (Y/8 * 4)
CheckCollision:
  TXA
  LSR
  LSR
  LSR
  LSR
  LSR
  LSR
  STA tmp
  TYA 
  LSR
  LSR
  LSR
  ASL
  ASL 
  CLC
  ADC tmp
  TAY
  TXA 
  LSR
  LSR
  LSR
  AND #%0111
  TAX 
  LDA ColissionMap, y 
  AND bitMask, x 
  RTS
 
DrawPlayer:
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; write player tile numbers
  LDA #$11
  STA PlayerRam1
  LDA #$12
  STA PlayerRam2
  LDA #$21
  STA PlayerRam3
  LDA #$22
  STA PlayerRam4

  LDA #%00000001
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  ; store tile locations
  ; top left tile:
  LDA PlayerYPos
  STA $0200
  LDA PlayerXPos
  STA $0203

  ; top right tile (x + 8):
  LDA PlayerYPos
  STA $0204
  LDA PlayerXPos
  CLC
  ADC #$08
  STA $0207

  ; bottom left tile (y + 8):
  LDA PlayerYPos
  CLC
  ADC #$08
  STA $0208
  LDA PlayerXPos
  STA $020b

  ; bottom right tile (x + 8, y + 8)
  LDA PlayerYPos
  CLC
  ADC #$08
  STA $020c
  LDA PlayerXPos
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

  .byte $80, $11, $1, $80 ; idle sprite 
  .byte $80, $12, $1, $88
  .byte $88, $21, $1, $80
  .byte $88, $22, $1, $88

  ; .byte $55, $13, $01, $24 ; idle movement
  ; .byte $55, $14, $01, $2c
  ; .byte $5d, $23, $01, $24
  ; .byte $5d, $24, $01, $2c

  ; .byte $55, $15, $01, $34 ; jump 
  ; .byte $55, $16, $01, $3c
  ; .byte $5d, $25, $01, $34
  ; .byte $5d, $26, $01, $3c

  ; .byte $55, $17, $41, $4c ; looking left
  ; .byte $55, $18, $41, $44
  ; .byte $5d, $27, $41, $4c
  ; .byte $5d, $28, $41, $44

  ; .byte $45, $31, $01, $44 ; dead
  ; .byte $45, $32, $01, $4c
  ; .byte $4d, $41, $01, $44
  ; .byte $4d, $42, $01, $4c

  ; .byte $45, $17, $01, $54 ; looking right
  ; .byte $45, $18, $01, $5c
  ; .byte $4d, $27, $01, $54
  ; .byte $4d, $28, $01, $5c

ColissionMap:
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000

  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00001111, %11111111, %11111111, %00000000
  .byte %00001111, %11111111, %11111111, %00000000
  .byte %00001111, %11111111, %11111111, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000

  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111
  .byte %11111111, %11111111, %11111111, %11111111


bitMask:
  .byte %10000000
  .byte %01000000
  .byte %00100000
  .byte %00010000
  .byte %00001000
  .byte %00000100
  .byte %00000010
  .byte %00000001

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

