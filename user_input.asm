  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

; Constants
PPU_CTRL    = $2000
PPU_MASK    = $2001
PPU_STATUS  = $2002
PPU_SCROLL  = $2005
PPU_ADDRESS = $2006
PPU_DATA    = $2007

; global variables to be used as parameters for functions
  .rsset $0000
variable1 .rs 1
variable2 .rs 1
variable3 .rs 1
variable4 .rs 1
variable5 .rs 2

buttons_pressed .rs 8

  .bank 0
  .org $C000

; Starting point of the program, ie kinda like main()
START:
  SEI           ; Set interrupt disabled
  CLD           ; Clear Decimal Mode even though the NES doesn't support it
  LDX #$40
  STX $4017
  LDX #$FF
  TXS           ; Sets the stack to FF. The stack address will start at $01FF
                ; and grow down to $0100 when pushes are done onto the stack.
  INX           ; Since X is FF, incrementing X by one will roll over X to 0
  STX PPU_CTRL  ; Set PPU_CTRL to 0
  STX PPU_MASK  ; Set PPU_MASK to 0
  STX $4010

  JSR vBlank    ; wait for Vertical Blank

; Set memory values between $0100 through $0700 to 0.
; X is set to 0 in START: because after transferring FF to the stack, X is
; incremented by one which rolls the byte to 0
; The addresses between $0200 - $02FF are set to #$FE
MEMCLEAR:
  LDA #$00
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE MEMCLEAR

  JSR vBlank ; wait for Vertical Blank again

LoadPalettes:
  ; It is necessary to call PPU_ADDRESS twice so we can pass the high low
  ; bytes for the address. In this case the address where we are sending
  ; data is $3F00 for palette data
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$3F
  STA PPU_ADDRESS       ; write the high byte of $3F00 address
  LDA #$00
  STA PPU_ADDRESS       ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA PALETTES, x       ; load data from address (palette + the value in x)
                        ; 1st time through loop it will load palette+0
                        ; 2nd time through loop it will load palette+1
                        ; 3rd time through loop it will load palette+2
                        ; etc
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $20, decimal 32
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal
                        ; to zero. If compare was equal to 32, continue forward

  ; Load 8 sprites worth of data
  ; The first sprite data is between $0200-$0203, then the second sprite is
  ; $0204-$0208, etc. Every sprite is 4 bytes long.
  ; The byte order is...
  ; X (Vertical positioning), Tile, Sprite Palette, Y (Horizontal positioning)
  LDX #$00
LoadSpritesLoop:
  LDA SPRITES, x
  STA $0200, x
  INX
  CPX #$20                ; Compare to 32 bytes
  BNE LoadSpritesLoop     ; If X is not 32, then loop back to the label

  ; Load the texts to display. These are the parameters for
  ; loading 'Input Text Demo'
  ; For a better explanation on which parameters we are setting up, check out
  ; the function Display_Text for a detailed explanation
  LDA #$EA
  STA variable2
  LDA #$20
  STA variable1
  LDA #$0F
  STA variable3
  LDA #LOW(TEXT_INPUT_TEST)
  STA variable5
  LDA #HIGH(TEXT_INPUT_TEST)
  STA variable5+1
  JSR Display_Text

  LDA #$0A
  STA variable2
  LDA #$21
  STA variable1
  LDA #01
  STA variable3
  LDA #LOW(TEXT_A)
  STA variable5
  LDA #HIGH(TEXT_A)
  STA variable5+1
  JSR Display_Text

  LDA #$2A
  STA variable2
  LDA #$21
  STA variable1
  LDA #01
  STA variable3
  LDA #LOW(TEXT_B)
  STA variable5
  LDA #HIGH(TEXT_B)
  STA variable5+1
  JSR Display_Text

  LDA #$4A
  STA variable2
  LDA #$21
  STA variable1
  LDA #06
  STA variable3
  LDA #LOW(TEXT_SELECT)
  STA variable5
  LDA #HIGH(TEXT_SELECT)
  STA variable5+1
  JSR Display_Text

  LDA #$6A
  STA variable2
  LDA #$21
  STA variable1
  LDA #05
  STA variable3
  LDA #LOW(TEXT_START)
  STA variable5
  LDA #HIGH(TEXT_START)
  STA variable5+1
  JSR Display_Text

  LDA #$8A
  STA variable2
  LDA #$21
  STA variable1
  LDA #02
  STA variable3
  LDA #LOW(TEXT_UP)
  STA variable5
  LDA #HIGH(TEXT_UP)
  STA variable5+1
  JSR Display_Text

  LDA #$AA
  STA variable2
  LDA #$21
  STA variable1
  LDA #04
  STA variable3
  LDA #LOW(TEXT_DOWN)
  STA variable5
  LDA #HIGH(TEXT_DOWN)
  STA variable5+1
  JSR Display_Text

  LDA #$CA
  STA variable2
  LDA #$21
  STA variable1
  LDA #04
  STA variable3
  LDA #LOW(TEXT_LEFT)
  STA variable5
  LDA #HIGH(TEXT_LEFT)
  STA variable5+1
  JSR Display_Text

  LDA #$EA
  STA variable2
  LDA #$21
  STA variable1
  LDA #05
  STA variable3
  LDA #LOW(TEXT_RIGHT)
  STA variable5
  LDA #HIGH(TEXT_RIGHT)
  STA variable5+1
  JSR Display_Text

  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA PPU_MASK

INFINITY:

;; Read the input from the user to change state of the buttons_pressed
;; array so that when NMI gets called the sprite data will be updated
  JSR ReadControllerInput

  JMP INFINITY

NMI:
  ; Save the state of A, X, Y
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

  ; Update the graphics using the buttons_pressed variable
  LDX #$00
  LDY #$00
ButtonGraphics_loop:
  LDA buttons_pressed, y
  STA $0202, x
  TXA
  CLC
  ADC #$04
  TAX
  INY
  CPY #$08
  BNE ButtonGraphics_loop

  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA PPU_MASK
  LDA #$00        ;;tell the ppu there is no background scrolling
  STA PPU_SCROLL
  STA PPU_SCROLL

;; Restore the states for A, X, Y (in the reverse order because the last item
;; pushed on stack was in the order Y,X,A)
  PLA
  TAY
  PLA
  TAX
  PLA

  RTI

; Function to display text on screen
; Parameters
;   * variable 1 & 2 - First and second bytes are the screen position.
;     The addresses available are from $2000 to $2400
;   * variable 3 - Length of the string
;   * varaible 4 - NOT USED
;   * variable 5 - The starting address for the string. If the text label
;     is STRING_LABEL, you can use the LDA #LOW(STRING_LABEL) and
;     LDA #HIGH(STRING_LABEL) to store the high/low byte address of a label
Display_Text:
  LDA PPU_STATUS
  LDA variable1
  STA PPU_ADDRESS
  LDA variable2
  STA PPU_ADDRESS
  LDY #$00
Display_Text_Loop:
  LDA [variable5], y
  STA PPU_DATA
  INY
  CPY variable3
  BNE Display_Text_Loop
  RTS

; Check player one input and store the states of the button in buttons_pressed
; which is an array of 8 bytes
; Order of button reading is.. A, B, Select, Start, Up, Down, Left, Right
ReadControllerInput:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$00
  LDY #$00
ReadControllerInputLoop:
  LDA $4016
  AND #$01
  BEQ ButtonNotPressed ; Branch when eqaul to 0
  LDA #$01
  STA buttons_pressed, y
  JMP CheckNextButtonIfAny
ButtonNotPressed:
  LDA #$00
  STA buttons_pressed, y
CheckNextButtonIfAny:
  INY
  INX
  CPX #$08
  BNE ReadControllerInputLoop
  RTS

  .bank 1
  .org $E000
PALETTES:
  ; background palette
  .db $3D,$1C,$2B,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F
  ; sprite palette
  .db $3D,$0F,$2B,$0F,  $3D,$16,$05,$27,  $22,$1C,$15,$14,  $22,$02,$38,$3C

TEXT_INPUT_TEST:
  .db "Input Test Demo"
TEXT_UP:
  .db "UP"
TEXT_DOWN:
  .db "DOWN"
TEXT_LEFT:
  .db "LEFT"
TEXT_RIGHT:
  .db "RIGHT"
TEXT_A:
  .db "A"
TEXT_B:
  .db "B"
TEXT_SELECT:
  .db "SELECT"
TEXT_START:
  .db "START"

SPRITES:
  ; X (Vertical positioning), Tile, Sprite Palette, Y (Horizontal positioning)
  .db 62, $00, $00, 72  ; UP
  .db 70, $00, $00, 72  ; Down
  .db 78, $00, $00, 72  ; Left
  .db 86, $00, $00, 72  ; Right
  .db 94, $00, $00, 72  ; Select
  .db 102, $00, $00, 72 ; Start
  .db 110, $00, $00, 72 ; A
  .db 118, $00, $00, 72 ; B

vBlank:
  BIT PPU_STATUS
  BPL vBlank
  RTS

  ; It is necessary to specify where the labels for where NMI START can be found
  .org $FFFA
  .dw NMI
  .dw START
  .dw 0

  .bank 2
  .org $0000
  .incbin "demo.chr"
