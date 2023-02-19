; Archivo: Principal.s
; Dispositivo: PIC16F887
; Autor:       Edgar Chen
; Compilador:  pic-as (v2.30), MPLABX V5.40
;
; Programa:    Contador con interrupciones
; Hardware:    LEDs en el puerto
;
; Creado:      18 de febrero, 2023
; Última modificación:  18 de febrero, 2023
    
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
   STATUS_TEMP: DS 1	;1 byte
   W_TEMP:	DS 1
   cont:	DS 1
   cont_tmr0:	DS 1
   offset:	DS 1
   sixty_sec:	DS 1
  
   UP	    EQU 0 ;1 byte
   DOWN	    EQU 1
   
PSECT resVect, class=CODE, abs, delta=2
;--------------vector reset---------------
ORG 00h ;posición 0000h para el reset
resetVec:
    PAGESEL main
    goto main

;----------ISR--------
PSECT code, delta=2, abs
ORG 004h ; posición para el código

 ;Interruption flow
push:
    movwf   W_TEMP
    swapf   STATUS, W
    movwf   STATUS_TEMP
    
isr:	;cheking the interruptions
    btfsc   RBIF    ;flag of the portb
    call    int_rb    
    
    btfsc   T0IF
    call    int_tmr0
   
pop:	;returning from the interruption
    swapf   STATUS_TEMP, W
    movwf   STATUS
    swapf   W_TEMP, F
    swapf   W_TEMP, W
    retfie		;return from the interuption
 
;----------ISR SUBROUTINES--------
int_rb:	    ;interruption of LEDs
    btfss   PORTB, UP
    incf    PORTA
    btfss   PORTB, DOWN
    decf    PORTA	
    bcf	    RBIF
    return

int_tmr0:    ;interruption of timer0    
    call    reset_tmr0	;8 ms
    incf    cont
    movf    cont, W
    sublw   120    
    btfss   ZERO
    return
    clrf    cont
    incf    offset
    movf    offset, W
    sublw   10
    btfsc   ZERO
    movwf   offset
    btfsc   ZERO
    incf    sixty_sec
    BANKSEL STATUS
    bcf     STATUS, 2
    return    

;----------Configuración--------
PSECT code, delta=2, abs
ORG 100h ; posición para el código    
    
;Mapping the values of the 7 segments display
table:
    clrf    PCLATH
    bsf	    PCLATH, 0	;PCLATH in 01
    andwf   0x0F
    addwf   PCL		;PC = PCLATH + PCL
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
;Calling the configurations (they will execute once)
main:
    call setup_io
    call setup_rbpu
    call setup_osc
    call setup_iocb
    call conf_tmr0
    call reset_tmr0
    call conf_intcon
    BANKSEL PORTA
    
;----------LOOP--------
;Calling the subrutines of the 2 7 segments display
loop:
    call display_sec
    call display_tmr0
    
    goto loop

;----------SUBRUTINES--------
setup_io:   ;Setting the pins as digital inputs/outputs
    BANKSEL ANSEL
    clrf    ANSEL
    clrf    ANSELH
    
    BANKSEL TRISA
    clrf    TRISA
    clrf    TRISB
    clrf    TRISC
    clrf    PORTD
    bsf	    TRISB, UP
    bsf	    TRISB, DOWN
    
    BANKSEL PORTA
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    return

;Enabling the inner pull up in B
setup_rbpu:  
    BANKSEL TRISA
    bcf	    OPTION_REG, 7   ;RBPU
    bsf	    WPUB, DOWN
    bsf	    WPUB, UP   
    return 

;Declaring a internal clock of 1MHz
setup_osc:
    BANKSEL OSCCON 
    bsf	    SCS
    bsf	    IRCF2
    bcf	    IRCF1
    bcf	    IRCF0
    return

setup_iocb: ;enabling GIE, RBIE, and individual pin of IOCB
    BANKSEL TRISA	;enabling the interruption in the pins
    bsf	    IOCB, UP 
    bsf	    IOCB, DOWN
    bsf	    RBIE	;enabling interruptions in the port B
    bsf	    GIE		;enabling general interrupts
    return

conf_tmr0:
    BANKSEL OPTION_REG
    bcf	    OPTION_REG, 5   ;Using the internal clock
    bcf	    OPTION_REG, 3   ;Assigning preescaler to the timer0
    bcf	    OPTION_REG, 2   ;Timer0 Rate of 1:64
    bsf	    OPTION_REG, 1
    bcf	    OPTION_REG, 0
    return

;Reseting the timer0
reset_tmr0:
    BANKSEL TMR0
    bcf	    T0IF
    movlw   6	    
    movwf   TMR0
    return   
    
;Enabling interruptions
conf_intcon:
    BANKSEL INTCON
    bsf	    INTCON, 7	;Enabling Global Interrupt Enable 
    bsf	    INTCON, 5	;Enabling the timer0 interrupt
    bsf	    INTCON, 3	;Enabling the portB interrupt
    bcf	    INTCON, 0	;When none of the pins have changed state
    return

;Display of the tens
display_sec:
    movf   sixty_sec, W
    sublw   6
    btfsc   ZERO
    movwf   sixty_sec
    movf    sixty_sec, W
    call    table
    movwf   PORTD
    BANKSEL STATUS
    bcf     STATUS, 2
    return

;Display of the values of the timer0
display_tmr0:  
    movf    offset, W
    call    table
    movwf   PORTC
    return
    
END
 