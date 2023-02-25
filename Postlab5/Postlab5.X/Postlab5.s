; Archivo: Principal.s
; Dispositivo: PIC16F887
; Autor:       Edgar Chen
; Compilador:  pic-as (v2.30), MPLABX V5.40
;
; Programa:    Postlab 5
; Hardware:    LEDs en el puerto
;
; Creado:      23 de febrero, 2023
; Última modificación:  23 de febrero, 2023
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
  
//Variables
PSECT udata_bank0 ; common memory
   STATUS_TEMP:  DS 1
   W_TEMP:	 DS 1
   var:		 DS 1
   nibble:	 DS 2
   display:	 DS 3
   flags:	 DS 1
   unit:	 DS 1
   ten:		 DS 1
   hundred:	 DS 1
   dividend:	 DS 1
  
   UP	    EQU 0 ;1 byte
   DOWN	    EQU 1
   
   
PSECT resVect, class=CODE, abs, delta=2
;--------------vector reset---------------
ORG 00h ;posición 0000h para el reset
resetVec:
    PAGESEL main
    goto main

;----------ISR--------
;Code for the interruption
PSECT code, delta=2, abs
ORG 004h ; posición para el código

push:
    movwf   W_TEMP
    swapf   STATUS, W
    movwf   STATUS_TEMP

;Calling the interruption subrutines
isr:
    btfsc   RBIF    ;flag of the portb
    call    int_rb
    
    btfsc   T0IF    ;flag of the portb
    call    int_tmr0
    
pop:
    swapf   STATUS_TEMP, W
    movwf   STATUS
    swapf   W_TEMP, F
    swapf   W_TEMP, W
    retfie		;return from the interuption

;----------ISR SUBROUTINES--------
;Incrementing or decrementing the value of the PORTA
int_rb:
    btfss   PORTB, UP
    incf    PORTA
    btfss   PORTB, DOWN
    decf    PORTA	
    bcf	    RBIF
    return

;Changing between ports (displays)
int_tmr0:
    call    reset_tmr0
    clrf    PORTD
    btfsc   flags, 0
    goto    display_0
    btfsc   flags, 1
    goto    display_1
    btfsc   flags, 2
    goto    display_2
 
;Display of units
display_0:
    bcf	    flags, 0	    ;Clearing the flag of this display (to continue with the others)
    movf    display, W	    ;Moving the value to represent units in the display to W
    movwf   PORTC	    ;Moving W to PORTC (where are the displays)
    bsf	    PORTD, 0	    ;Turning on the display
    bsf	    flags, 1	    ;Setting the flag of the next display
    bcf	    flags, 2	    ;Turning of the flag of the last display (for security)
    return
    
;Display of tens
display_1:
    bcf	    flags, 1
    movf    display+1, W
    movwf   PORTC
    bsf	    PORTD, 1
    bsf	    flags, 2
    bcf	    flags, 0
    return

;Display of hundreds
display_2:
    bcf	    flags, 2
    movf    display+2, W
    movwf   PORTC
    bsf	    PORTD, 2
    bsf	    flags, 0
    bcf	    flags, 1
    return
	
    
;----------Configuración--------
;Table for converting values to images in the display
PSECT code, delta=2, abs
ORG 100h ; posición para el código
table:
    clrf    PCLATH
    bsf	    PCLATH, 0	;PCLATH in 01
    andwf   0x0F
    addwf   PCL ;PC = PCLATH + PCL
    ;DT	    3FH, 06H, ...
    retlw   01000000B    ;0
    retlw   01111001B 	 ;1
    retlw   00100100B	 ;2
    retlw   00110000B	 ;3
    retlw   00011001B    ;4
    retlw   00010010B	 ;5
    retlw   00000010B	 ;6
    retlw   01111000B	 ;7
    retlw   00000000B    ;8
    retlw   00010000B	 ;9
    retlw   00001000B	 ;A
    retlw   00000011B	 ;B
    retlw   01000110B	 ;C
    retlw   00100001B    ;D
    retlw   00000110B	 ;E
    retlw   00001110B	 ;F 

    
;----------MAIN--------
;Calling all the configurations and setting the value of flags
main:
    call setup_io
    call setup_rbpu
    call setup_osc
    call setup_iocb
    call conf_tmr0
    call reset_tmr0
    call conf_intcon
    bsf	 flags, 0
    bcf	 flags, 1
    bcf	 flags, 2
    BANKSEL PORTA
    
;----------LOOP--------
loop:    
    ;Saving in dividend the value of the portA
    movf    PORTA, W
    movwf   dividend
    
    ;Getting the number of units, tens and hundreds
    call    divide_100
    call    divide_10
    call    divide_1  
    
    ;Getting the values for each display
    call    displays
    
    goto loop

;----------SUBRUTINES--------
;Setting the pins, PORTA, PORTC, PORTD as a outputs and PORTB as an input
setup_io:
    BANKSEL ANSEL
    clrf    ANSEL
    clrf    ANSELH
    
    BANKSEL TRISA
    clrf    TRISA
    clrf    TRISB
    clrf    TRISC
    clrf    TRISD
    bsf	    TRISB, UP
    bsf	    TRISB, DOWN
    
    BANKSEL PORTA
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    return
    
;Setting the pull ups in portB
setup_rbpu:  
    BANKSEL TRISA
    bcf	    OPTION_REG, 7   ;RBPU
    bsf	    WPUB, DOWN
    bsf	    WPUB, UP   
    return 

;Declaring a internal clock of 1MHz
setup_osc:
    BANKSEL OSCCON 
    bsf	    SCS	    ;Internal clock
    bsf	    IRCF2
    bcf	    IRCF1
    bcf	    IRCF0   ;1 MHz
    return

;Reseting the timer
reset_tmr0:
    BANKSEL TMR0
    bcf	    T0IF
    movlw   230
    movwf   TMR0
    return   

;Configuring the timer0
conf_tmr0:
    BANKSEL OPTION_REG
    bcf	    OPTION_REG, 5   ;Using the internal clock
    bcf	    OPTION_REG, 3   ;Assigning preescaler to the timer0
    bcf	    OPTION_REG, 2   ;Timer0 Rate of 1:64
    bsf	    OPTION_REG, 1
    bcf	    OPTION_REG, 0
    return
    
setup_iocb: ;enabling GIE, RBIE, and individual pin of IOCB
    BANKSEL TRISA	;enabling the interruption in the pins
    bsf	    IOCB, UP 
    bsf	    IOCB, DOWN
    bsf	    RBIE	;enabling interruptions in the port B
    bsf	    GIE		;enabling general interruots
    return
    
;Enabling interruptions
conf_intcon:
    BANKSEL INTCON
    bsf	    INTCON, 7	;Enabling Global Interrupt Enable 
    bsf	    INTCON, 5	;Enabling the timer0 interrupt
    bsf	    INTCON, 3	;Enabling the portB interrupt
    bcf	    INTCON, 0	;When none of the pins have changed state
    return

;Subrutine that translates the value of hundred, ten and unit to a value for each display
displays:
    movf   unit, W
    call   table
    movwf  display
    
    movf   ten, W
    call   table
    movwf  display+1
    
    movf   hundred, W
    call   table
    movwf  display+2
    
    return

;Finding the value of the port of units
divide_1:
    clrf    unit
    movlw   1
    subwf   dividend, F
    btfsc   CARRY
    incf    unit	   ;Incrementing the unit variable
    btfsc   CARRY
    goto    $-5
    movlw   1
    addwf   dividend, F
    return

;Finding the value of the port of tens
divide_10:
    clrf    ten
    movlw   10
    subwf   dividend, F
    btfsc   CARRY
    incf    ten		   ;Incrementing the ten variable
    btfsc   CARRY
    goto    $-5
    movlw   10
    addwf   dividend, F
    return
    
;Finding the value of the port of hundreds
divide_100:
    clrf    hundred	
    movlw   100
    subwf   dividend, F
    btfsc   CARRY	    ;Carry turn on when the exist a residue in the diference
    incf    hundred	    ;Incrementing the hundred variable
    btfsc   CARRY
    goto    $-5		    ;If there is a residue we make again the diference
    movlw   100
    addwf   dividend, F	
    return
    
END
 