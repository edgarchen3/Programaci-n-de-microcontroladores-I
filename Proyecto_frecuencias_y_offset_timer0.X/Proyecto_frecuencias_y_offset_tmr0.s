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
    STATUS_TEMP:    DS  1
    W_TEMP:	    DS  1
    trian_var:	    DS  1
    sine_var:	    DS	1
    cont_small:	    DS  2
    cont_big:	    DS	4
    signal:	    DS	1
    flag_func:	    DS  1
    amplitude_var:  DS	1 ;1 - 5
    limit_leds:	    DS	1
    temp_var1:	    DS	1
    var_sine:	    DS  1
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
int_portb:
    clrf    temp_var1
    call    int_amplitude
    call    int_signal   
    call    int_hz_khz
    call    int_frecuency
    ;call    int_offset

int_signal:
    btfss   PORTB, 2
    call    change_flag
    clrf    flag_func
    bcf     RBIF
    return
    
change_flag:
    call    delay_anti_bounce
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
   
int_amplitude:
    btfss   PORTB, 4
    call    incr_amp
    btfss   PORTB, 3
    call    decr_amp	
    bcf	    RBIF
    bcf	    STATUS, 2
    return
    
incr_amp:
    call    delay_anti_bounce
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
    call    delay_anti_bounce
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
   
int_frecuency:
    bcf	    PORTD, 2
    bcf	    PORTD, 3
    btfss   PORTB, 6
    call    increment_f
    btfss   PORTB, 5
    call    decrement_f
    bcf	    STATUS, 2
    return 
   
increment_f:
    bsf	    PORTD, 2
    call    delay_anti_bounce
    btfss   PORTB, 6
    btfss  Hz_kHz, 0
    goto   inc_Hz
    goto   inc_kHz
    
    
decrement_f:
    bsf	    PORTD, 3
    call    delay_anti_bounce
    btfss   PORTB, 5
    btfss  Hz_kHz, 0
    goto   dec_Hz
    goto   dec_kHz
    
inc_Hz:
    movf    N_delay_Hz, W
    movwf   temp_var1
    movlw   255
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
    movlw   255
    subwf   temp_var1
    btfss   STATUS, 2
    call    plus_kHz
    return
    
plus_kHz:
    movlw   1
    addwf   N_delay_kHz
    return
    
dec_kHz:
    movf    N_delay_kHz, W
    movwf   temp_var1
    movlw   0
    subwf   temp_var1
    btfss   STATUS, 2
    call    minus_kHz
    return

minus_kHz:
    movlw   1
    subwf   N_delay_kHz
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
    return  
    
delay_anti_bounce:
    movlw 150	   
    movwf anti_bounce
    decfsz anti_bounce, 1    ;decrementar el contador
    goto $-1		    ;ejecutar la linea anterior
    return

;Calling the function for displaying the waves
int_tmr0:
    call    show_displays
    btfsc   signal, 0
    goto    square_signal
    btfsc   signal, 1
    goto    triangular_signal	;subroutine that oraganizes all the delays of the wave
    btfsc   signal, 2
    goto    sine_signal		;subroutine that oraganizes all the delays of the wave

;Changing between ports (displays)
show_displays:
    movlw   0x00
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
    bsf	    PORTE, 0	    ;Turning on the display
    bsf	    flags, 1	    ;Setting the flag of the next display
    bcf	    flags, 2	    ;Turning of the flag of the last display (for security)
    return
    
;Display of tens
display_1:
    bcf	    flags, 1
    movf    display+1, W
    movwf   PORTC
    bsf	    PORTE, 1
    bsf	    flags, 2
    bcf	    flags, 0
    return

;Display of hundreds
display_2:
    bcf	    flags, 2
    movf    display+2, W
    movwf   PORTC
    bsf	    PORTE, 2
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
    ;Table for a cathode
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

table_for_sine:
    clrf    PCLATH
    bsf	    PCLATH, 0	;PCLATH in 01
    andwf   0xFF
    addwf   PCL ;PC = PCLATH + PCL
    ;Table for a cathode
    retlw	01110100B   
    retlw	01110111B
    retlw	01111010B
    retlw	01111101B
    retlw	10000000B
    retlw	10000011B
    retlw	10000110B
    retlw	10001001B
    retlw	10001101B
    retlw	10010000B
    retlw	10010011B
    retlw	10010110B
    retlw	10011001B
    retlw	10011100B
    retlw	10011111B
    retlw	10100010B
    retlw	10100100B
    retlw	10100111B
    retlw	10101010B
    retlw	10101101B
    retlw	10110000B
    retlw	10110010B
    retlw	10110101B
    retlw	10110111B
    retlw	10111010B
    retlw	10111100B
    retlw	10111111B
    retlw	11000001B
    retlw	11000011B
    retlw	11000110B
    retlw	11001000B
    retlw	11001010B
    retlw	11001100B
    retlw	11001110B
    retlw	11010000B
    retlw	11010010B
    retlw	11010100B
    retlw	11010101B
    retlw	11010111B
    retlw	11011001B
    retlw	11011010B
    retlw	11011011B
    retlw	11011101B
    retlw	11011110B
    retlw	11011111B
    retlw	11100000B
    retlw	11100001B
    retlw	11100010B
    retlw	11100011B
    retlw	11100100B
    retlw	11100101B
    retlw	11100101B
    retlw	11100110B
    retlw	11100110B
    retlw	11100110B
    retlw	11100111B
    retlw	11100111B
    retlw	11100111B
    retlw	11100111B
    retlw	11100111B
    retlw	11100111B
    retlw	11100110B
    retlw	11100110B
    retlw	11100110B
    retlw	11100101B
    retlw	11100101B
    retlw	11100100B
    retlw	11100011B
    retlw	11100010B
    retlw	11100001B
    retlw	11100000B
    retlw	11011111B
    retlw	11011110B
    retlw	11011101B
    retlw	11011011B
    retlw	11011010B
    retlw	11011001B
    retlw	11010111B
    retlw	11010101B
    retlw	11010100B
    retlw	11010010B
    retlw	11010000B
    retlw	11001110B
    retlw	11001100B
    retlw	11001010B
    retlw	11001000B
    retlw	11000110B
    retlw	11000011B
    retlw	11000001B
    retlw	10111111B
    retlw	10111100B
    retlw	10111010B
    retlw	10110111B
    retlw	10110101B
    retlw	10110010B
    retlw	10110000B
    retlw	10101101B
    retlw	10101010B
    retlw	10100111B
    retlw	10100100B
    retlw	10100010B
    retlw	10011111B
    retlw	10011100B
    retlw	10011001B
    retlw	10010110B
    retlw	10010011B
    retlw	10010000B
    retlw	10001101B
    retlw	10001001B
    retlw	10000110B
    retlw	10000011B
    retlw	10000000B
    retlw	01111101B
    retlw	01111010B
    retlw	01110111B
    retlw	01110011B
    retlw	01110000B
    retlw	01101101B
    retlw	01101010B
    retlw	01100111B
    retlw	01100100B
    retlw	01100001B
    retlw	01011110B
    retlw	01011010B
    retlw	01010111B
    retlw	01010100B
    retlw	01010001B
    retlw	01001110B
    retlw	01001011B
    retlw	01001000B
    retlw	01000101B
    retlw	01000011B
    retlw	01000000B
    retlw	00111101B
    retlw	00111010B
    retlw	00110111B
    retlw	00110101B
    retlw	00110010B
    retlw	00110000B
    retlw	00101101B
    retlw	00101011B
    retlw	00101000B
    retlw	00100110B
    retlw	00100100B
    retlw	00100001B
    retlw	00011111B
    retlw	00011101B
    retlw	00011011B
    retlw	00011001B
    retlw	00010111B
    retlw	00010101B
    retlw	00010011B
    retlw	00010010B
    retlw	00010000B
    retlw	00001110B
    retlw	00001101B
    retlw	00001100B
    retlw	00001010B
    retlw	00001001B
    retlw	00001000B
    retlw	00000111B
    retlw	00000110B
    retlw	00000101B
    retlw	00000100B
    retlw	00000011B
    retlw	00000010B
    retlw	00000010B
    retlw	00000001B
    retlw	00000001B
    retlw	00000001B
    retlw	00000000B
    retlw	00000000B
    retlw	00000000B
    retlw	00000000B
    retlw	00000000B
    retlw	00000000B
    retlw	00000001B
    retlw	00000001B
    retlw	00000001B
    retlw	00000010B
    retlw	00000010B
    retlw	00000011B
    retlw	00000100B
    retlw	00000101B
    retlw	00000110B
    retlw	00000111B
    retlw	00001000B
    retlw	00001001B
    retlw	00001010B
    retlw	00001100B
    retlw	00001101B
    retlw	00001110B
    retlw	00010000B
    retlw	00010010B
    retlw	00010011B
    retlw	00010101B
    retlw	00010111B
    retlw	00011001B
    retlw	00011011B
    retlw	00011101B
    retlw	00011111B
    retlw	00100001B
    retlw	00100100B
    retlw	00100110B
    retlw	00101000B
    retlw	00101011B
    retlw	00101101B
    retlw	00110000B
    retlw	00110010B
    retlw	00110101B
    retlw	00110111B
    retlw	00111010B
    retlw	00111101B
    retlw	01000000B
    retlw	01000011B
    retlw	01000101B
    retlw	01001000B
    retlw	01001011B
    retlw	01001110B
    retlw	01010001B
    retlw	01010100B
    retlw	01010111B
    retlw	01011010B
    retlw	01011110B
    retlw	01100001B
    retlw	01100100B
    retlw	01100111B
    retlw	01101010B
    retlw	01101101B
    retlw	01110000B
    retlw	01110100B

table_frecuencies_values_s:
    clrf    PCLATH
    bsf	    PCLATH, 0	;PCLATH in 01
    andwf   0xFF
    addwf   PCL ;PC = PCLATH + PCL
    ;255 values
    retlw 0000000000000000B
    retlw 0000110000110100B
    retlw 0000001000001001B
    retlw 0000001100000111B
    retlw 0000001001111001B
    retlw 0000000100000100B
    retlw 0000000011011111B
    retlw 0000000011000011B
    retlw 0000000010101110B
    retlw 0000000010011100B
    retlw 0000000010001110B
    retlw 0000000001000010B
    retlw 0000000000111100B
    retlw 0000000000110000B
    retlw 0000000000101000B
    retlw 0000001111010001B
    retlw 0000001110010111B
    retlw 0000001101100100B
    retlw 0000001100110110B
    retlw 0000001100001101B
    retlw 0000001011101000B
    retlw 0000001011000110B
    retlw 0000001010100111B
    retlw 0000001010001011B
    retlw 0000001001110001B
    retlw 0000001001011001B
    retlw 0000001001011001B
    retlw 0000001001000011B
    retlw 0000001000101110B
    retlw 0000001000011011B
    retlw 0000001000001001B
    retlw 0000000111111000B
    retlw 0000000111101000B
    retlw 0000000111011001B
    retlw 0000000111001100B
    retlw 0000000110111110B
    retlw 0000000110110010B
    retlw 0000000110100110B
    retlw 0000000110011011B
    retlw 0000000110010001B
    retlw 0000000110000111B
    retlw 0000000101111101B
    retlw 0000000101110100B
    retlw 0000000101101011B
    retlw 0000000101100011B
    retlw 0000000101011011B
    retlw 0000000101010100B
    retlw 0000000101001100B
    retlw 0000000101000110B
    retlw 0000000100111111B
    retlw 0000000100111111B
    retlw 0000000100111001B
    retlw 0000000100110010B
    retlw 0000000100101100B
    retlw 0000000100100111B
    retlw 0000000100100001B
    retlw 0000000100011100B
    retlw 0000000100010111B
    retlw 0000000100010010B
    retlw 0000000100010010B
    retlw 0000000100001101B
    retlw 0000000100001101B
    retlw 0000000100001001B
    retlw 0000000100000100B
    retlw 0000000100000000B
    retlw 0000000011111100B
    retlw 0000000011111000B
    retlw 0000000011110100B
    retlw 0000000011110000B
    retlw 0000000011101101B
    retlw 0000000011101001B
    retlw 0000000011100110B
    retlw 0000000011100010B
    retlw 0000000011011111B
    retlw 0000000011011100B
    retlw 0000000011011001B
    retlw 0000000011011001B
    retlw 0000000011010110B
    retlw 0000000011010011B
    retlw 0000000011010000B
    retlw 0000000011001110B
    retlw 0000000011001011B
    retlw 0000000011001000B
    retlw 0000000011000110B
    retlw 0000000011000011B
    retlw 0000000011000001B
    retlw 0000000011000001B
    retlw 0000000010111111B
    retlw 0000000010111100B
    retlw 0000000010111010B
    retlw 0000000010111000B
    retlw 0000000010111000B
    retlw 0000000010110110B
    retlw 0000000010110100B
    retlw 0000000010110010B
    retlw 0000000010110000B
    retlw 0000000011001110B
    retlw 0000000011001011B
    retlw 0000000011001000B
    retlw 0000000011000110B
    retlw 0000000011000110B
    retlw 0000000011000011B
    retlw 0000000011000001B
    retlw 0000000010111111B
    retlw 0000000010111100B
    retlw 0000000010111010B
    retlw 0000000010111000B
    retlw 0000000010110110B
    retlw 0000000010110100B
    retlw 0000000010110100B
    retlw 0000000010110010B
    retlw 0000000010110000B
    retlw 0000000010101110B
    retlw 0000000010101100B
    retlw 0000000010101010B
    retlw 0000000010101000B
    retlw 0000000010100110B
    retlw 0000000010100100B
    retlw 0000000010100100B
    retlw 0000000010100011B
    retlw 0000000010100001B
    retlw 0000000010011111B
    retlw 0100111100001110B
    retlw 0100111000001100B
    retlw 0100110110001011B
    retlw 0100110010001001B
    retlw 0100110010001001B
    retlw 0100110000001000B
    retlw 0100101100001010B
    retlw 0100101010000101B
    retlw 0100100110000011B
    retlw 0100100100000010B
    retlw 0100100010000001B
    retlw 0100011110001111B
    retlw 0100011100001110B
    retlw 0100011010001101B
    retlw 0100011000001100B
    retlw 0100010100001010B
    retlw 0100010100001010B
    retlw 0100010010001001B
    retlw 0100010000001000B
    retlw 0100001110000111B
    retlw 0100001100000110B
    retlw 0100001000000100B
    retlw 0100000110000011B
    retlw 0100000100000010B
    retlw 0100000010000001B
    retlw 0100000000000000B
    retlw 0011111110000000B
    retlw 0011111110000000B
    retlw 0011111100000000B
    retlw 0011111010000000B
    retlw 0011111000000000B
    retlw 0011110110000000B
    retlw 0011110100000000B
    retlw 0011110010000000B
    retlw 0011110010000000B
    retlw 0011110000000000B
    retlw 0011101110000000B
    retlw 0011101100000000B
    retlw 0011101010000000B
    retlw 0011101010000000B
    retlw 0011101000000000B
    retlw 0011100110000000B
    retlw 0011100100000000B
    retlw 0011100010000000B
    retlw 0011100010000000B
    retlw 0011100000000000B   
    retlw 0011100000000000B
    retlw 0011011110000000B
    retlw 0011011100000000B
    retlw 0011011010000000B
    retlw 0011011010000000B
    retlw 0011011000000000B
    retlw 0011010110000000B
    retlw 0011010100000000B
    retlw 0011010100000000B
    retlw 0011010010000000B
    retlw 0011010010000000B
    retlw 0011010000000000B
    retlw 0011001110000000B
    retlw 0011001110000000B
    retlw 0011001100000000B
    retlw 0011001010000000B
    retlw 0011001010000000B
    retlw 0011001000000000B
    retlw 0011001000000000B
    retlw 0011000110000000B
    retlw 0011000100000000B
    retlw 0011000100000000B
    retlw 0011000010000000B
    retlw 0011000000000000B
    retlw 0011000000000000B
    retlw 0010111110000000B
    retlw 0010111110000000B
    retlw 0010111110000000B
    retlw 0010111100000000B
    retlw 0010111100000000B
    retlw 0010111010000000B
    retlw 0010111000000000B
    retlw 0010111000000000B
    retlw 0010110110000000B
    retlw 0010110110000000B  
    retlw 0000100101010111B
    retlw 0000100101010111B
    retlw 0000100101010111B
    retlw 0000100101010111B
    retlw 0000100101010010B
    retlw 0000100101010010B
    retlw 0000100101010010B
    retlw 0000100100101001B
    retlw 0000100100101001B
    retlw 0000100100101001B
    retlw 0000100100101001B
    retlw 0000100100100000B
    retlw 0000100100100000B
    retlw 0000100100100000B
    retlw 0000100011100111B
    retlw 0000100011100111B
    retlw 0000100011100111B
    retlw 0000100011100110B
    retlw 0000100011100110B
    retlw 0000100011100110B
    retlw 0000100010110101B
    retlw 0000100010110101B
    retlw 0000100010110101B
    retlw 0000100010110101B
    retlw 0000100010000100B
    retlw 0000100010000100B
    retlw 0000100010000100B
    retlw 0000100010000100B
    retlw 0000100001110011B
    retlw 0000100001110011B
    retlw 0000100001110010B
    retlw 0000100001110010B
    retlw 0000100001110010B
    retlw 0000100001010001B
    retlw 0000100001010001B
    retlw 0000100001010001B
    retlw 0000100001010001B
    retlw 0000100000000000B
    retlw 0000100000000000B
    retlw 0000100000000000B
    retlw 0000100000000000B
    retlw 0000100000000000B
    retlw 0000011111111111B
    retlw 0000011111111111B
    retlw 0000011111111111B
    retlw 0000011111111111B
    retlw 0000011111011110B
    retlw 0000011111011110B
    retlw 0000011111011110B
    retlw 0000011111011110B
    retlw 0000011111011110B
    retlw 0000011110111101B
    retlw 0000011110111101B
    
;----------MAIN--------
main:
    bsf	    signal, 0
    bcf	    signal, 1
    bcf	    signal, 2	
    
    bcf	 Hz_kHz, 0
    
    bcf	 flag_func, 0
           
    movlw   255
    movwf   limit_leds
    
    movlw   255
    movwf   N_delay_Hz
    movlw   255
    movwf   N_delay_kHz

    call    setup_io
    call    conf_intcon
    call    setup_iocb
    call    setup_osc
    call    conf_tmr0
    call    reset_tmr0
    BANKSEL PORTA
    
;----------LOOP--------
loop:
    ;Getting the number of units, tens and hundreds
    call    divide_100
    call    divide_10
    call    divide_1 
    
    ;Getting the values for each display
    call    displays
    
    call    red_LED
        
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
    bsf	    IRCF0
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
red_LED:
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
    call    delay_square
    movlw   0
    movwf   PORTA
    call    delay_square       
    return
    
;Triangular signal
triangular_signal:
    bcf	    PORTD, 4
    bsf	    PORTD, 5
    movf    limit_leds, W
    movwf   trian_var
    incf    PORTA
    call    delay_triangular
    decfsz  trian_var
    goto    $-3
    movf    limit_leds, W
    movwf   trian_var
    decf    PORTA
    call    delay_triangular
    decfsz  trian_var
    return
    
;Sine signal  
sine_signal:
    bsf	    PORTD, 4
    bsf	    PORTD, 5
    clrf    sine_var
    movlw   230
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
 
;dividing the values for each displays
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
    
;selecting value for passing to the displays
value_of_displays:
    btfss    Hz_kHz, 0
    goto     pass_value_Hz
    goto     pass_value_kHz
    
;passing vaues of frecuency kHz to displays    
pass_value_Hz:
    movf    N_delay_Hz, W 
    call    table_frecuencies_values_s
    movwf   dividend
    return
  
;passing vaues of frecuency kHz to displays
pass_value_kHz:
    movf    N_delay_kHz, W
    call    table_frecuencies_values_s
    movwf   dividend
    return
    
END

    
    


    