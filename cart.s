.segment "HEADER"
    .byte "NES"
    .byte $1a
    .byte $02
    .byte $01
    .byte %00000001
    .byte $00
    .byte $00
    .byte $00
    .byte $00
    .byte $00, $00, $00, $00, $00

.segment "ZEROPAGE"
    ;; Variables
    gamestate:      .res 1  
    ballx:          .res 1  
    bally:          .res 1
    ballup:         .res 1  ; 1 = ball going up
    balldown:       .res 1  ; 1 = ball going down
    ballleft:       .res 1  ; 1 = ball going left
    ballright:      .res 1  ; 1 = ball going right
    ballspeedx:     .res 1
    ballspeedy:     .res 1
    paddle1ytop:    .res 1
    paddle1ybottom: .res 1
    paddle2ytop:    .res 1
    paddle2ybottom: .res 1
    score1:         .res 1  ; reserve 1 byte of RAM for score1 variable
    score2:         .res 1  ; reserve 1 byte of RAM for score2 variable
    buttons1:       .res 1  ; put controller data for player 1
    buttons2:       .res 1  ; put controller data for player 2 
    paddlespeed:    .res 1
    score1Ones:      .res 1
    score1Tens:      .res 1
    score1Hundreds:  .res 1
    score2Ones:      .res 1
    score2Tens:      .res 1
    score2Hundreds:  .res 1
    
    ;; Constants
    STATETITLE      = $00   ; is on title screen
    STATEPLAYING    = $01   ; is playing game
    STATEGAMEOVER   = $02   ; is gameover

    RIGHTWALL       = $E5   ; when the ball reaches one of these we'll do some bounce logic
    TOPWALL         = $20
    BOTTOMWALL      = $E0
    LEFTWALL        = $04

    PADDLE1X        = $15 
    PADDLE2X        = $D4
    ;;;;;;;;;;; 
    BALLSTARTX      = $80
    BALLSTARTY      = $50

.segment "STARTUP"
.segment "CODE"
.include "controllers.s"
.include "play.s"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Subroutines ;;;
vblankwait: 
    BIT $2002
    BPL vblankwait
    RTS 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup code ;;;
RESET:
    SEI         ; disable IRQs
    CLD         ; disable decimal mode
    LDX #$40
    STX $4017   ; disable APU frame counter 
    LDX #$ff    ; setup the stack
    TXS 
    INX 
    STX $2000   ; disable NMI
    STX $2001   ; disable rendering
    STX $4010   ; disable DMC IRQs

    JSR vblankwait

    TXA         ; make A $00 
clearmem:
    STA $0000,X
    STA $0100,X
    STA $0300,X
    STA $0400,X
    STA $0500,X
    STA $0600,X
    STA $0700,X
    LDA #$FE
    STA $0200,X   ; set aside area in RAM for sprite memory
    LDA #$00
    INX 
    BNE clearmem

    JSR vblankwait

    LDA #$02    ; load A with the high byte for sprite memory
    STA $4014   ; this uploads 256 bytes of data from the CPU page $XX00 - $XXFF (XX is 02 here) to the internal PPU OAM
    NOP    

    JSR init_apu

clearnametables:
    LDA $2002   ; reset PPU status high/low latch
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006
    LDX #$08    ; prepare to fill 8 pages ($800 bytes)
    LDY #$00    ; X/Y is 16-bit counter, high byte in X
    LDA #$24    ; fill with tile $24 (sky block)
:
    STA $2007
    DEY 
    BNE :-
    DEX 
    BNE :-

loadpalette:
    LDA $2002 
    LDA #$3f
    STA $2006
    LDA #$00
    STA $2006

    LDX #$00
loadpaletteloop:
    LDA palettedata,X
    STA $2007
    INX 
    CPX #$20
    BNE loadpaletteloop

;;; set intial ball values
    LDA #$01
    STA ballright
    STA ballup
    LDA #$00
    STA balldown
    STA ballleft

    LDA #BALLSTARTY
    STA bally

    LDA #BALLSTARTX
    STA ballx

    LDA #$01
    STA ballspeedx
    STA ballspeedy

;;; set paddle speed + start position
    LDA #$02
    STA paddlespeed
    LDA #$10
    STA paddle1ytop
    LDA #$18
    STA paddle1ybottom

    LDA #$10
    STA paddle2ytop
    LDA #$18
    STA paddle2ybottom
    
;;; Set starting game state
    LDA #STATETITLE
    STA gamestate

    CLI             ; clear interrupt flag
    LDA #%10010000  ; enable NMI, sprites from pattern table 0, background from pattern table 1
    STA $2000

    LDA #%00011110  ; background and sprites enable, no clipping on left
    STA $2001

forever:
    JMP forever

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; VBLANK loop - called every frame ;;;
VBLANK:
    LDA #$00
    STA $2003   ; low byte of RAM address
    LDA #$02
    STA $4014   ; high byte of RAM address, start transfer

    JSR drawscore

    ;; PPU clean up section, so rendering the next frame starts properly
    LDA #%10010000  ; enable NMI, sprites from pattern table 0, background from pattern table 1
    STA $2000
    LDA #%00011110  ; enable sprites, background, no left side clipping
    STA $2001
    LDA #$00
    STA $2005       ; no X scrolling
    STA $2005       ; no Y scrolling

    ;;;; all graphics updates run by now, so run game engine
    JSR readcontroller_1 ; get current button data for player 1
    JSR readcontroller_2 ; get current button data for player 2

GAMEENGINE:
    LDA gamestate
    CMP #STATETITLE
    BEQ enginetitle ; is it on title screen?
    
    LDA gamestate
    CMP #STATEGAMEOVER
    BEQ enginegameover ; is it on gameover screen?
    
    LDA gamestate
    CMP #STATEPLAYING
    BEQ engineplaying ; is it on playing screen?
GAMEENGINEDONE:
    JSR updatesprites   ; set ball/paddle sprites
    RTI 

enginetitle:
    LDA #STATEPLAYING
    CMP gamestate
    BEQ enginetitledone

    LDA buttons1
    AND #%00010000      ; check if start button is pressed (bit 4)
    BEQ enginetitledone ; if not pressed, skip to end

    jsr vblankwait
    JSR cleartitlesprites

    LDA #STATEPLAYING   ; set game state to playing
    STA gamestate

enginetitledone:
    JMP GAMEENGINEDONE

enginegameover:
    ;;  if start button pressed
    ;;      turn screen off
    ;;      load title screen
    ;;      go to title screen
    ;;      turn screen on
    JMP GAMEENGINEDONE

engineplaying:
    JSR engine_playing
    JMP GAMEENGINEDONE

updatesprites:
    LDA gamestate
    CMP #STATETITLE
    BEQ updatetitlesprites
    LDA gamestate
    CMP #STATEPLAYING
    BEQ updategamesprites
    RTS

updategamesprites:
    ;; ball sprites
    LDA bally 
    STA $0200

    LDA #$75    ; tile
    STA $0201

    LDA #$00
    STA $0202

    LDA ballx
    STA $0203

    ;; paddle 1 sprites
    LDA paddle1ytop
    STA $0204
    LDA #$80
    STA $0205
    LDA #%10000000
    STA $0206
    LDA #PADDLE1X
    STA $0207

    LDA paddle1ybottom
    STA $0208
    LDA #$81
    STA $0209
    LDA #$00
    STA $020A
    LDA #PADDLE1X
    STA $020B

    ;; paddle 2 sprites
    LDA paddle2ytop
    STA $020C
    LDA #$82
    STA $020D
    LDA #$00
    STA $020E
    LDA #PADDLE2X
    STA $020F
    
    LDA paddle2ybottom
    STA $0210
    LDA #$82
    STA $0211
    LDA #$00
    STA $0212
    LDA #PADDLE2X
    STA $0213
    rts

updatetitlesprites:
    LDA #%10011000  ; enable NMI, sprites from pattern table 0, background from pattern table 1
    STA $2000
    ldx #$00
    @spriteloop:
        lda titlesprite, x
        sta $0200, X
        INX
        cpx #$64
        bne @spriteloop
    RTS

cleartitlesprites:
    ldx #$00
    @spriteloop:
        lda #$00
        sta $0200, X
        INX
        cpx #$64
        bne @spriteloop
    LDA #%10010000  ; enable NMI, sprites from pattern table 0, background from pattern table 1
    STA $2000
    rts

; playhitsound:
;     ldx #$00
;     lda periodTableHi, x
;     sta $4002

;     ldx #$00
;     lda periodTableLo, x
;     sta $4003

;     lda #%10111111
;     sta $400F

;     RTS

init_apu:
        ; Init $4000-4013
        ldy #$13
@loop:  lda @regs,y
        sta $4000,y
        dey
        bpl @loop
        ; We have to skip over $4014 (OAMDMA)
        lda #$0f
        sta $4015
        lda #$40
        sta $4017
        rts
@regs:
        .byte $30,$08,$00,$00
        .byte $30,$08,$00,$00
        .byte $80,$00,$00,$00
        .byte $30,$00,$00,$00
        .byte $00,$00,$00,$00

drawscore:
;;; Player 1 ;;;
    LDA $2002           ; clear PPU high/low latch
    LDA #$20
    STA $2006
    LDA #$20
    STA $2006           ; draw score at PPu $2020 - position in nametable

    LDA score1Hundreds   ; get first digit
;   CLC 
;   ADC #$30            ; add ascii offset (this is UNUSED in this example as in this .chr digits start at tile 0)
    STA $2007           ; write to PPU address $2020
    LDA score1Tens       ; next digit
;   CLC
;   ADC #$30            ; add ascii offset
    STA $2007
    LDA score1Ones       ; last digit
;   CLC
;   ADC #$30            ; add ascii offset
    STA $2007

;;; Player 2 ;;;
    LDA $2002           ; clear PPU high/low latch
    LDA #$20
    STA $2006
    LDA #$3D
    STA $2006           ; draw score at PPu $202D - position in nametable

    LDA score2Hundreds   ; get first digit
;   CLC 
;   ADC #$30            ; add ascii offset (this is UNUSED in this example as in this .chr digits start at tile 0)
    STA $2007           ; write to PPU address $202D
    LDA score2Tens       ; next digit
;   CLC
;   ADC #$30            ; add ascii offset
    STA $2007
    LDA score2Ones       ; last digit
;   CLC
;   ADC #$30            ; add ascii offset
    STA $2007
    RTS 

increment1score:
inc1ones:
    LDA score1Ones       ; load the lowest digit of the number
    CLC 
    ADC #$01            ; add one
    STA score1Ones 
    CMP #$0A            ; check for overflow, now equal 10
    BNE inc1done 
inct1ens:
    LDA #$00
    STA score1Ones       ; reset ones digit from 9 to 0
    LDA score1Tens       ; load second digit
    CLC 
    ADC #$01            ; add one, the carry from the previous digit
    STA score1Tens
    CMP #$0A            ; check if overflowed
    BNE inc1done
inc1hundreds:
    LDA #$00
    STA score1Tens       ; reset tens to 0 for overflow
    LDA score1Hundreds   ; load the last digit
    CLC 
    ADC #$01            ; add 1, the carry from the last digit
    STA score1Hundreds 
inc1done:
    rts

increment2score:
inc2ones:
    LDA score2Ones       ; load the lowest digit of the number
    CLC 
    ADC #$01            ; add one
    STA score2Ones 
    CMP #$0A            ; check for overflow, now equal 10
    BNE inc2done 
inct2ens:
    LDA #$00
    STA score2Ones       ; reset ones digit from 9 to 0
    LDA score2Tens       ; load second digit
    CLC 
    ADC #$01            ; add one, the carry from the previous digit
    STA score2Tens
    CMP #$0A            ; check if overflowed
    BNE inc2done
inc2hundreds:
    LDA #$00
    STA score2Tens       ; reset tens to 0 for overflow
    LDA score2Hundreds   ; load the last digit
    CLC 
    ADC #$01            ; add 1, the carry from the last digit
    STA score2Hundreds 
inc2done:
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Sprite / palette / nametable / attributes ;;;
palettedata:
    .byte $10,$29,$1A,$0F,   $22,$36,$17,$0F,   $22,$30,$21,$0F,   $22,$27,$17,$0F  ; background palette data
    .byte $0F,$16,$27,$18,   $22,$1A,$30,$27,   $22,$16,$21,$27,   $22,$30,$36,$17  ; sprite palette data

titlesprite:
    .byte $60, $17, $03, $64
    .byte $60, $0E, $03, $6C
    .byte $60, $1C, $03, $74
    .byte $60, $00, $03, $7C
    .byte $60, $19, $03, $84
    .byte $60, $18, $03, $8C
    .byte $60, $17, $03, $94
    .byte $60, $10, $03, $9C

    .byte $80, $0A, $03, $6C
    .byte $80, $00, $03, $74
    .byte $80, $10, $03, $7C
    .byte $80, $0A, $03, $84
    .byte $80, $16, $03, $8C
    .byte $80, $0E, $03, $94

    .byte $8C, $0B, $03, $7C
    .byte $8C, $22, $03, $84

    .byte $98, $14, $03, $74
    .byte $98, $22, $03, $7C
    .byte $98, $15, $03, $84
    .byte $98, $0E, $03, $8C

    .byte $A6, $20, $03, $70
    .byte $A6, $0A, $03, $78
    .byte $A6, $0D, $03, $80
    .byte $A6, $0A, $03, $88
    .byte $A6, $1C, $03, $90 ; 100 bytes in total

periodTableLo:
    .byte $f1,$7f,$13,$ad,$4d,$f3,$9d,$4c,$00,$b8,$74,$34
    .byte $f8,$bf,$89,$56,$26,$f9,$ce,$a6,$80,$5c,$3a,$1a
    .byte $fb,$df,$c4,$ab,$93,$7c,$67,$52,$3f,$2d,$1c,$0c
    .byte $fd,$ef,$e1,$d5,$c9,$bd,$b3,$a9,$9f,$96,$8e,$86
    .byte $7e,$77,$70,$6a,$64,$5e,$59,$54,$4f,$4b,$46,$42
    .byte $3f,$3b,$38,$34,$31,$2f,$2c,$29,$27,$25,$23,$21
    .byte $1f,$1d,$1b,$1a,$18,$17,$15,$14

periodTableHi:
    .byte $07,$07,$07,$06,$06,$05,$05,$05,$05,$04,$04,$04
    .byte $03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$02
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00

.segment "VECTORS"
    .word VBLANK
    .word RESET
    .word 0
.segment "CHARS"
    .incbin "sprites.chr"