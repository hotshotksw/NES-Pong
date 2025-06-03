.proc engine_playing
moveballright:
    LDA ballright   ; is ball moving right?
    BEQ moveballrightdone   ; if ballright = 0 then skip

    LDA ballx 
    CLC     ; clear carry cos we adding 
    ADC ballspeedx 
    STA ballx 

    LDA ballx 
    CMP #RIGHTWALL  ; if ball x < right wall, still on screen, then skip next section - CMP sets Carry if >=
    BCC moveballrightdone 
    LDA #$00 
    STA ballright 
    LDA #$01
    STA ballleft    ; set moving right to falase, and bounce
    
    JSR increment1score  ; increase player 1 score
    ;;; reset ball location
    LDA score1 
    CLC 
    ADC #$01
    STA score1 

    LDA #BALLSTARTY
    STA bally
    LDA #BALLSTARTX
    STA ballx
    
moveballrightdone:

moveballleft:
    LDA ballleft   ; is ball moving left?
    BEQ moveballleftdone   ; if ballleft = 0 then skip

    LDA ballx 
    SEC     ; set carry cos we subtracting 
    SBC ballspeedx 
    STA ballx 

    LDA ballx 
    CMP #LEFTWALL  ; if ball x > left wall, still on screen, then skip next section - CMP sets Carry if >=
    BCS moveballleftdone   ; branch if carry
    LDA #$00 
    STA ballleft 
    LDA #$01
    STA ballright    ; set moving left to falase, and bounce
    
    JSR increment2score  ; increase player 1 score
    LDA score2
    CLC 
    ADC #$01
    STA score2 

    ;;; reset ball location
    LDA #BALLSTARTY
    STA bally
    LDA #BALLSTARTX
    STA ballx

moveballleftdone:

moveballup:
    LDA ballup   ; is ball moving up?
    BEQ moveballupdone   ; if ballup = 0 then skip

    LDA bally 
    SEC     ; set carry cos we subtracting 
    SBC ballspeedy 
    STA bally 

    LDA bally 
    CMP #TOPWALL  ; if ball y > top wall, still on screen, then skip next section - CMP sets Carry if >=
    BCS moveballupdone   ; branch if carry
    LDA #$00 
    STA ballup 
    LDA #$01
    STA balldown    ; set moving up to falase, and bounce
moveballupdone:

moveballdown:
    LDA balldown   ; is ball moving down?
    BEQ moveballdowndone   ; if balldown = 0 then skip

    LDA bally 
    CLC     ; clear carry cos we adding 
    ADC ballspeedy 
    STA bally 

    LDA bally 
    CMP #BOTTOMWALL  ; if ball y < bottom wall, still on screen, then skip next section - CMP sets Carry if >=
    BCC moveballdowndone   ; branch if carry

    LDA #$00 
    STA balldown 
    LDA #$01
    STA ballup    ; set moving down to falase, and bounce
moveballdowndone:

movepaddle1up:
    ;;  if up pressed
    ;;      if paddle top > top wall
    ;;          move paddle top and bottom up
    LDA buttons1
    CMP #%00001000          ; up in buttons1 is at bit4
    BNE movepaddle1updone   ; is up being pressed

    LDA paddle1ytop 
    CMP #TOPWALL        ; if paddle < topwall, skip movement code
    BCC movepaddle1updone

    LDA paddle1ytop
    SEC 
    SBC paddlespeed
    STA paddle1ytop

    LDA paddle1ybottom
    SEC 
    SBC paddlespeed
    STA paddle1ybottom


movepaddle1updone:

movepaddle1down:
    ;;  if down pressed
    ;;      if paddle bottom < bottom wall
    ;;          move paddle top and bottom down

    LDA buttons1
    CMP #%00000100          ; up in buttons1 is at bit4
    BNE movepaddle1downdone   ; is up being pressed

    LDA paddle1ybottom 
    CMP #BOTTOMWALL        ; if paddle > bottomwall, skip movement code
    BCS movepaddle1downdone

    LDA paddle1ytop
    CLC 
    ADC paddlespeed
    STA paddle1ytop

    LDA paddle1ybottom
    CLC 
    ADC paddlespeed
    STA paddle1ybottom

movepaddle1downdone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
movepaddle2up:
    ;;  if up pressed
    ;;      if paddle top > top wall
    ;;          move paddle top and bottom up
    LDA buttons2
    CMP #%00001000          ; up in buttons1 is at bit4
    BNE movepaddle2updone   ; is up being pressed

    LDA paddle2ytop 
    CMP #TOPWALL        ; if paddle < topwall, skip movement code
    BCC movepaddle2updone

    LDA paddle2ytop
    SEC 
    SBC paddlespeed
    STA paddle2ytop

    LDA paddle2ybottom
    SEC 
    SBC paddlespeed
    STA paddle2ybottom


movepaddle2updone:

movepaddle2down:
    ;;  if down pressed
    ;;      if paddle bottom < bottom wall
    ;;          move paddle top and bottom down

    LDA buttons2
    CMP #%00000100          ; up in buttons1 is at bit4
    BNE movepaddle2downdone   ; is up being pressed

    LDA paddle2ybottom 
    CMP #BOTTOMWALL        ; if paddle > bottomwall, skip movement code
    BCS movepaddle2downdone

    LDA paddle2ytop
    CLC 
    ADC paddlespeed
    STA paddle2ytop

    LDA paddle2ybottom
    CLC 
    ADC paddlespeed
    STA paddle2ybottom

movepaddle2downdone:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

checkpaddle1collision:
    ;;  if ball x < paddle 1 x
    ;;      if ball y > paddle y top
    ;;          if ball y < paddle y bottom
    ;;              bounce, ball move left now
    LDA ballx 
    CMP #PADDLE1X                    ; sets Clear if ballx >= PADDLE1X
    BCS checkpaddle1collisiondone   ; if ballx < paddle 1 x, skip
    
    LDA bally 
    CMP paddle1ytop 
    BCC checkpaddle1collisiondone 
    
    LDA bally
    CMP paddle1ybottom 
    BCS checkpaddle1collisiondone 

    ;JSR playhitsound
    LDA #$00
    STA ballleft
    LDA #$01
    STA ballright
checkpaddle1collisiondone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
checkpaddle2collision:
    ;;  if ball x > paddle 2 x
    ;;      if ball y > paddle y top
    ;;          if ball y < paddle y bottom
    ;;              bounce, ball move left now
    LDA ballx 
    CMP #PADDLE2X                    ; sets Clear if ballx >= PADDLE1X
    BCC checkpaddle2collisiondone   ; if ballx < paddle 1 x, skip
    
    LDA bally 
    CMP paddle2ytop 
    BCC checkpaddle2collisiondone 
    
    LDA bally
    CMP paddle2ybottom 
    BCS checkpaddle2collisiondone 

    ;JSR playhitsound
    LDA #$00
    STA ballright
    LDA #$01
    STA ballleft
checkpaddle2collisiondone:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    rts
.endproc