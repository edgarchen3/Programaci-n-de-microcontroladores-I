; Archivo: Principal.s
; Dispositivo: PIC16F887
; Autor:       Edgar Chen
; Compilador:  pic-as (v2.30), MPLABX V5.40
;
; Programa:    Proyecto I
; Hardware:    LEDs, pushbuttons, display y DAC
;
; Creado:      4 de marzo de 2023
; Última modificación:   marzo de 2023
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements
  
;TODO, SOLAMENTE FALTA EL OFFSET    
    
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
PROCESSOR 16F887
#include <xc.inc>
  

//Variables
PSECT udata_bank0 ; common memory
    STATUS_TEMP:	DS  1
    W_TEMP:		DS  1
    trian_var:		DS  1
    sine_var:		DS  1
    cont_small:		DS  2
    cont_big:		DS  4
    signal:		DS  1
    flag_func:		DS  1
    amplitude_var:	DS  1 ;1 - 5
    limit_leds:		DS  1
    limit_leds_down:	DS  1
    temp_var1:		DS  1
    temp_var2:		DS  1
    temp_var3:		DS  1
    var_sine:		DS  1
    N_delay:		DS  2 ;N value (gotten from table)
    N_delay_Hz:		DS  2 ;position (table)
    N_delay_kHz:	DS  2 ;position (table)
    frecuency_value:	DS  2
    N_delay_trian:	DS  2
    spy_var:		DS  1
    Hz_kHz:		DS  1
    N_value:		DS  2
    LEDS_var:		DS  1
    thousand:		DS  1
    hundred:		DS  1
    ten:		DS  1 
    unit:		DS  1
    dividend:		DS  1
    display:		DS  4
    flags:		DS  1
    anti_bounce:	DS  1
  
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
    
isr:   
    call    waves
    
    btfsc   RBIF    ;flag of the portb
    call    int_portb
        
    btfsc   T0IF    
    call    int_tmr0
        
pop:
    swapf   STATUS_TEMP, W
    movwf   STATUS
    swapf   W_TEMP, F
    swapf   W_TEMP, W
    retfie		;return from the interuption
 
;----------ISR SUBROUTINES-------- 
waves:    
    btfsc   signal, 0
    goto    square_signal
    btfsc   signal, 1
    goto    triangular_signal	;subroutine that oraganizes all the delays of the wave
    btfsc   signal, 2
    goto    sine_signal		;subroutine that oraganizes all the delays of the wave
    
int_portb:
    call    delay_anti_bounce
    clrf    temp_var1
    call    int_amplitude
    call    int_signal   
    call    int_hz_khz
    call    int_frecuency
    call    int_offset

int_signal:
    btfss   PORTB, 2
    call    change_flag
    clrf    flag_func
    bcf     RBIF
    return
  
int_amplitude:
    btfss   PORTB, 4
    call    incr_amp
    btfss   PORTB, 3
    call    decr_amp	
    bcf	    RBIF
    bcf	    STATUS, 2
    return
    
int_frecuency:
    bcf	    PORTD, 2
    bcf	    PORTD, 3
    btfss   PORTB, 6
    call    increment_f
    btfss   PORTB, 5
    call    decrement_f
    bcf	    STATUS, 2
    bcf     RBIF
    return 
    
int_hz_khz:
    btfss   PORTB, 7
    call    toggle_Hz_kHz ;Hz (0) default
    return
    
toggle_Hz_kHz:
    call    delay_anti_bounce
    btfss   PORTB, 7
    movlw   0x01
    xorwf   Hz_kHz, F
    bcf     RBIF
    btfss   Hz_kHz, 0
    goto    red_Hz
    goto    red_kHz
 
red_Hz:
    bsf	    PORTD, 0
    bcf	    PORTD, 1
    return
    
red_kHz:
    bcf	    PORTD, 0
    bsf	    PORTD, 1
    return

delay_anti_bounce:
    movlw 250	   
    movwf anti_bounce
    decfsz anti_bounce, 1    ;decrementar el contador
    goto $-1		    ;ejecutar la linea anterior
    return
 
;Calling the function for displaying the waves
int_tmr0:
    call    prepare_displays
    call    displays
    call    show_displays
     
int_offset:
    bsf	    PORTD, 6
    bsf	    PORTD, 7
    bcf     RBIF
    btfss   PORTB, 1
    goto    inc_offset
    btfss   PORTB, 0
    goto    dec_offset
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
    ;Table for a cathode
    retlw 10111111B ;0 
    retlw 10000110B ;1 
    retlw 11011011B;2 
    retlw 11001111B ;3 
    retlw 11100110B ;4 
    retlw 11101101B ;5 
    retlw 11111101B ;6 
    retlw 10000111B ;7 
    retlw 11111111B ;8 
    retlw 11101111B ;9 
    retlw 11110111B ;A 
    retlw 11111100B ;B 
    retlw 10111001B ;C 
    retlw 11011110B ;D 
    retlw 11111001B ;E 
    retlw 11110001B ;F
    

table_for_sine:
    clrf    PCLATH
    bsf	    PCLATH, 0	;PCLATH in 01
    andwf   0xFF
    addwf   PCL ;PC = PCLATH + PCL
    ;Table for a cathode
    retlw	01110011B
    retlw	10000011B
    retlw	10000111B
    retlw	10001010B
    retlw	10001110B
    retlw	10010010B
    retlw	10010101B
    retlw	10011001B
    retlw	10011100B
    retlw	10100000B
    retlw	10100011B
    retlw	10100111B
    retlw	10101010B
    retlw	10101101B
    retlw	10110001B
    retlw	10110100B
    retlw	10110111B
    retlw	10111010B
    retlw	10111101B
    retlw	11000000B
    retlw	11000011B
    retlw	11000110B
    retlw	11001001B
    retlw	11001100B
    retlw	11001110B
    retlw	11010001B
    retlw	11010011B
    retlw	11010110B
    retlw	11011000B
    retlw	11011010B
    retlw	11011101B
    retlw	11011111B
    retlw	11100001B
    retlw	11100011B
    retlw	11100100B
    retlw	11100110B
    retlw	11101000B
    retlw	11101001B
    retlw	11101010B
    retlw	11101100B
    retlw	11101101B
    retlw	11101110B
    retlw	11101111B
    retlw	11110000B
    retlw	11110000B
    retlw	11110001B
    retlw	11110001B
    retlw	11110010B
    retlw	11110010B
    retlw	11110010B
    retlw	11110010B
    retlw	11110010B
    retlw	11110010B
    retlw	11110010B
    retlw	11110001B
    retlw	11110001B
    retlw	11110000B
    retlw	11101111B
    retlw	11101110B
    retlw	11101101B
    retlw	11101100B
    retlw	11101011B
    retlw	11101010B
    retlw	11101000B
    retlw	11100111B
    retlw	11100101B
    retlw	11100011B
    retlw	11100010B
    retlw	11100000B
    retlw	11011110B
    retlw	11011100B
    retlw	11011001B
    retlw	11010111B
    retlw	11010101B
    retlw	11010010B
    retlw	11010000B
    retlw	11001101B
    retlw	11001010B
    retlw	11001000B
    retlw	11000101B
    retlw	11000010B
    retlw	10111111B
    retlw	10111100B
    retlw	10111001B
    retlw	10110101B
    retlw	10110010B
    retlw	10101111B
    retlw	10101100B
    retlw	10101000B
    retlw	10100101B
    retlw	10100001B
    retlw	10011110B
    retlw	10011010B
    retlw	10010111B
    retlw	10010011B
    retlw	10010000B
    retlw	10001100B
    retlw	10001001B
    retlw	10000101B
    retlw	10000001B
    retlw	01111110B
    retlw	01111010B
    retlw	01110110B
    retlw	01110011B
    retlw	01101111B
    retlw	01101100B
    retlw	01101000B
    retlw	01100101B
    retlw	01100001B
    retlw	01011110B
    retlw	01011010B
    retlw	01010111B
    retlw	01010011B
    retlw	01010000B
    retlw	01001101B
    retlw	01001010B
    retlw	01000110B
    retlw	01000011B
    retlw	01000000B
    retlw	00111101B
    retlw	00111010B
    retlw	00110111B
    retlw	00110101B
    retlw	00110010B
    retlw	00101111B
    retlw	00101101B
    retlw	00101010B
    retlw	00101000B
    retlw	00100110B
    retlw	00100011B
    retlw	00100001B
    retlw	00011111B
    retlw	00011101B
    retlw	00011100B
    retlw	00011010B
    retlw	00011000B
    retlw	00010111B
    retlw	00010101B
    retlw	00010100B
    retlw	00010011B
    retlw	00010010B
    retlw	00010001B
    retlw	00010000B
    retlw	00001111B
    retlw	00001110B
    retlw	00001110B
    retlw	00001101B
    retlw	00001101B
    retlw	00001101B
    retlw	00001101B
    retlw	00001101B
    retlw	00001101B
    retlw	00001101B
    retlw	00001110B
    retlw	00001110B
    retlw	00001111B
    retlw	00001111B
    retlw	00010000B
    retlw	00010001B
    retlw	00010010B
    retlw	00010011B
    retlw	00010101B
    retlw	00010110B
    retlw	00010111B
    retlw	00011001B
    retlw	00011011B
    retlw	00011100B
    retlw	00011110B
    retlw	00100000B
    retlw	00100010B
    retlw	00100101B
    retlw	00100111B
    retlw	00101001B
    retlw	00101100B
    retlw	00101110B
    retlw	00110001B
    retlw	00110011B
    retlw	00110110B
    retlw	00111001B
    retlw	00111100B
    retlw	00111111B
    retlw	01000010B
    retlw	01000101B
    retlw	01001000B
    retlw	01001011B
    retlw	01001110B
    retlw	01010010B
    retlw	01010101B
    retlw	01011000B
    retlw	01011100B
    retlw	01011111B
    retlw	01100011B
    retlw	01100110B
    retlw	01101010B
    retlw	01101101B
    retlw	01110001B
    retlw	01110101B
    retlw	01111000B
    retlw	01111100B
    retlw	10000000B

;----------MAIN--------
main:
   
    bsf	    signal, 0
    bcf	    signal, 1
    bcf	    signal, 2	
    
    bcf	    Hz_kHz, 0
    
    bcf	    flag_func, 0
           
    movlw   255
    movwf   limit_leds
    
    movlw   0
    movwf   limit_leds_down
    
    movlw   1
    movwf   N_delay_Hz
    movlw   5
    movwf   N_delay_kHz

    call    setup_io
    call    conf_intcon
    call    setup_iocb
    call    setup_osc
    call    conf_tmr0
    call    reset_tmr0
    
    bsf	    PORTD, 0
    bsf	    PORTD, 6
    
    BANKSEL PORTA
    
;----------LOOP--------
loop:  
    nop
    goto    loop
    
 
;----------SUBRUTINES--------

;Configuring the ports ans digital inputs/ouputs
setup_io:
;All digital
    BANKSEL ANSEL
    clrf    ANSEL
    clrf    ANSELH
    
;All outputs, except port B
    BANKSEL TRISA
    clrf    TRISA
    clrf    TRISB
    clrf    TRISC
    clrf    TRISD
    clrf    TRISE
    bsf	    TRISB, 0 
    bsf	    TRISB, 1
    bsf	    TRISB, 2
    bsf	    TRISB, 3
    bsf	    TRISB, 4
    bsf	    TRISB, 5
    bsf	    TRISB, 6
    bsf	    TRISB, 7

 ;Enabling pull ups
    bcf	    OPTION_REG, 7   ;RBPU
    bsf	    WPUB, 0 
    bsf	    WPUB, 1
    bsf	    WPUB, 2
    bsf	    WPUB, 3
    bsf	    WPUB, 4
    bsf	    WPUB, 5
    bsf	    WPUB, 6
    bsf	    WPUB, 7
    
 ;Cleaning all ports
    BANKSEL PORTA
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    clrf    PORTE
    return
 
;Enabling interruptions for tmr0
conf_intcon:
    BANKSEL INTCON
    bsf	    INTCON, 7	;Enabling the flag of TMR0IF (timer0 have completed a cycle)
    bsf	    INTCON, 5	;Enabling the timer0 interrupt
    bsf	    INTCON, 4	;Enabling the timer1 interrupt
    bsf	    INTCON, 3	;Enabling the portB interrupt
    bcf	    INTCON, 0	;Enabling High Priority Interrupt
    return
 
;Interruptions for PORTB and global
setup_iocb: ;enabling GIE, RBIE, and individual pin of IOCB
    BANKSEL TRISA	
    bsf	    IOCB, 0	;enabling the interruption in the pins	
    bsf	    IOCB, 1
    bsf	    IOCB, 2
    bsf	    IOCB, 3
    bsf	    IOCB, 4
    bsf	    IOCB, 5
    bsf	    IOCB, 6
    bsf	    IOCB, 7
    bsf	    RBIE	;enabling interruptions in the port B
    bsf	    GIE		;enabling general interrupts
    return
   
;Configuration of clock
setup_osc:
    BANKSEL OSCCON ;Declaring a internal clock of 8MHz
    bsf	    SCS	    
    bsf	    IRCF2
    bsf	    IRCF1
    bcf	    IRCF0
    return

;Configuring the timer0
conf_tmr0:
    BANKSEL OPTION_REG
    bcf	    OPTION_REG, 5   ;Using the internal cycle clock (Fosc/4)
    bcf	    OPTION_REG, 3   ;Assigning preescaler to the timer0
    bcf	    OPTION_REG, 2   ;Timer0 Rate of 1:64 (preescaler)
    bsf	    OPTION_REG, 1
    bcf	    OPTION_REG, 0
    return

;turn on and turn off LEDs for Hz or kHz

    
;Reseting timer0
reset_tmr0:
    BANKSEL TMR0
    bcf	    T0IF
    movlw   230
    movwf   TMR0
    return 

;Square signal
square_signal:
    bsf	    PORTD, 4
    bcf	    PORTD, 5
    movf    limit_leds, W
    movwf   PORTA
    movlw   7
    movwf   temp_var1
    call    delay_small
    decfsz  temp_var1
    goto    $-2
    movf    limit_leds_down, W
    movwf   PORTA
    call    delay_small      
    return
    
;Triangular signal
triangular_signal:
    bcf	    PORTD, 4
    bsf	    PORTD, 5
    movf    limit_leds, W
    movwf   trian_var
    movf    limit_leds_down, W
    subwf   trian_var
    movf    limit_leds_down, W
    movwf   PORTA
    call    delay_small
    incf    PORTA
    decfsz  trian_var
    goto    $-3
    movf    limit_leds, W
    movwf   trian_var
    movf    limit_leds_down, W
    subwf   trian_var
    movf    limit_leds, W
    call    delay_small
    decf    PORTA
    decfsz  trian_var
    goto    $-3
    return
    
;Sine signal  
sine_signal:
    bsf	    PORTD, 4
    bsf	    PORTD, 5
    clrf    sine_var
    movlw   199
    movwf   sine_var
    movf    sine_var, W
    call    table_for_sine
    movwf   PORTA
    decfsz  sine_var
    goto    $-4
    return 

;selecting Hz or kHz of frecuency for triangular wave
delay_triangular:  
   BANKSEL TMR0
    bcf	    T0IF
    movf    N_delay_kHz, W
    movwf   TMR0
    return 
    
delay_small:
    btfsc   Hz_kHz, 0
    goto    delay_Hz
    goto    delay_kHz
    
delay_Hz:
    movf    N_delay_Hz, W
    movwf cont_small
    decfsz cont_small, 1    ;decrementar el contador
    goto $-1		    ;ejecutar la linea anterior
    return
 
delay_kHz:
    movf    N_delay_kHz, W
    movwf cont_small
    decfsz cont_small, 1    ;decrementar el contador
    goto $-1		    ;ejecutar la linea anterior
    return

;selecting Hz or kHz of frecuency for square wave
delay_square:
   btfss    Hz_kHz, 0
   goto	    Hz_s
   goto     kHz_s
    
;frecuency for square wave in Hz
Hz_s:
   BANKSEL TMR0
    bcf	    T0IF
    movf    N_delay_Hz, W
    movwf   TMR0
    return 

;frecuency for square wave in kHz
kHz_s:
    BANKSEL TMR0
    bcf	    T0IF
    movf    N_delay_kHz, W
    movwf   TMR0
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
 
;************************** code of int_tmr0 **************
;Changing between ports (displays)
show_displays:
    movlw   0x0F
    movwf   PORTE
    btfsc   flags, 0
    goto    display_0
    btfsc   flags, 1 
    goto    display_1
    btfsc   flags, 2
    goto    display_2
    
display_0:
    bcf	    flags, 0	    ;Clearing the flag of this display (to continue with the others)
    movf    display, W	    ;Moving the value to represent units in the display to W
    movwf   PORTC	    ;Moving W to PORTC (where are the displays)
    bcf	    PORTE, 0	    ;Turning on the display
    bsf	    flags, 1	    ;Setting the flag of the next display
    bcf	    flags, 2	    ;Turning of the flag of the last display (for security)
    return
    
;Display of tens
display_1:
    bcf	    flags, 1
    movf    display+1, W
    movwf   PORTC
    bcf	    PORTE, 1
    bsf	    flags, 2
    bcf	    flags, 0
    return

;Display of hundreds
display_2:
    bcf	    flags, 2
    movf    display+2, W
    movwf   PORTC
    bcf	    PORTE, 2
    bsf	    flags, 0
    bcf	    flags, 1
    return    
 
;dividing the values for each displays
    
displays:
    call    divide_100
    call    divide_10
    call    divide_1 
    
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
    
prepare_displays:
    btfss   Hz_kHz, 0
    goto    display_Hz
    goto    display_kHz
    
display_Hz:
    clrf    temp_var3
    movlw   9
    movwf   temp_var2
    movf    N_delay_Hz, W
    movwf   temp_var3
    movf    N_delay_Hz, W
    addwf   temp_var3
    decfsz  temp_var2
    goto $-3
    movf   temp_var3, W
    movwf   dividend
    return
 
display_kHz:
    movf    N_delay_kHz, W
    movwf   dividend
    return
    
;************************** code of int_flag **************  
change_flag:
    btfss   PORTB, 2
    btfsc   signal, 0
    call    flag_0
    btfsc   flag_func, 0
    return
    btfsc   signal, 1
    call    flag_1
    btfsc   flag_func, 0
    return
    btfsc   signal, 2
    call    flag_2
    btfsc   flag_func, 0
    return
    
flag_0:
    bcf	    signal, 0
    bsf	    signal, 1
    bcf	    signal, 2
    incf    flag_func
    return
    
flag_1:
    bcf	    signal, 0
    bcf	    signal, 1
    bsf	    signal, 2
    incf    flag_func
    return

flag_2:
    bsf	    signal, 0
    bcf	    signal, 1
    bcf	    signal, 2
    incf    flag_func
    return  
    
;*********************** code of int_amplitude ***********      
incr_amp:
    bsf	    PORTD, 7
    bcf	    PORTD, 6
    btfss   PORTB, 4
    movf    limit_leds, W
    movwf   temp_var1
    movlw   255
    subwf   temp_var1
    btfss   STATUS, 2
    call    plus_51
    return
    
plus_51:
    movlw   51
    addwf   limit_leds
    return
    
decr_amp:
    bsf	    PORTD, 7
    bcf	    PORTD, 6
    btfss   PORTB, 3
    movf    limit_leds, W
    movwf   temp_var1
    movlw   51
    subwf   temp_var1
    btfss   STATUS, 2
    call    minus_51
    return

minus_51:
    movlw   51
    subwf   limit_leds
    return    
    
;******************* code for int_frecuency *********
increment_f:
    bsf	    PORTD, 6
    bcf	    PORTD, 7
    bsf	    PORTD, 2
    btfss   PORTB, 6
    btfss  Hz_kHz, 0
    goto   inc_Hz
    goto   inc_kHz
    
    
decrement_f:
    bsf	    PORTD, 6
    bcf	    PORTD, 7
    bsf	    PORTD, 3
    btfss   PORTB, 5
    btfss  Hz_kHz, 0
    goto   dec_Hz
    goto   dec_kHz
    
inc_Hz:
    movf    N_delay_Hz, W
    movwf   temp_var1
    movlw   99
    subwf   temp_var1
    btfss   STATUS, 2
    call    plus_Hz
    return
    
plus_Hz:
    movlw   1
    addwf   N_delay_Hz
    return
    
dec_Hz:
    movf    N_delay_Hz, W
    movwf   temp_var1
    movlw   0
    subwf   temp_var1
    btfss   STATUS, 2
    call    minus_Hz
    return
    
minus_Hz:
    movlw   1
    subwf   N_delay_Hz
    return

inc_kHz:
    movf    N_delay_kHz, W
    movwf   temp_var1
    movlw   100
    subwf   temp_var1
    btfss   STATUS, 2
    call    plus_kHz
    return
    
plus_kHz:
    movlw   5
    addwf   N_delay_kHz
    return
    
dec_kHz:
    movf    N_delay_kHz, W
    movwf   temp_var1
    movlw   100
    subwf   temp_var1
    btfss   STATUS, 2
    call    minus_kHz
    return

minus_kHz:
    movlw   5
    subwf   N_delay_kHz
    return
   
;***************** int_offset *************
inc_offset: 
    movf    limit_leds, W
    movwf   temp_var1
    movlw   255
    subwf   temp_var1
    btfss   STATUS, 2
    call    offset_plus
    return
    
offset_plus:
    movlw   51
    addwf   limit_leds
    movlw   51
    addwf   limit_leds_down
    return
    
dec_offset: 
    movf    limit_leds_down, W
    movwf   temp_var1
    movlw   0
    subwf   temp_var1
    btfss   STATUS, 2
    call    offset_minus
    return
    
 offset_minus:
    movlw   51
    subwf   limit_leds
    movlw   51
    subwf   limit_leds_down
    return  
        
END

    
    


    