/*
 * File:   main.c
 * Author: Edgar Chen
 *Postlab 6
 * Created on 24 de marzo de 2023, 08:29 AM
 */

// CONFIG1
#pragma config FOSC = INTRC_NOCLKOUT// Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
#pragma config WDTE = OFF       // Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
#pragma config PWRTE = OFF      // Power-up Timer Enable bit (PWRT disabled)
#pragma config MCLRE = OFF      // RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
#pragma config CP = OFF         // Code Protection bit (Program memory code protection is disabled)
#pragma config CPD = OFF        // Data Code Protection bit (Data memory code protection is disabled)
#pragma config BOREN = OFF      // Brown Out Reset Selection bits (BOR disabled)
#pragma config IESO = OFF       // Internal External Switchover bit (Internal/External Switchover mode is disabled)
#pragma config FCMEN = OFF      // Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
#pragma config LVP = OFF        // Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

// CONFIG2
#pragma config BOR4V = BOR40V   // Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
#pragma config WRT = OFF        // Flash Program Memory Self Write Enable bits (Write protection off)

// #pragma config statements should precede project file includes.
// Use project enums instead of #define for ON and OFF.
    
#include <xc.h>
#define _tmr0_value 200
#define _XTAL_FREQ 8000000    

void setup(void);
char table(int digit);
void getDigits(int num);

int value_display, adc1, adc2;
int unit, tens, hundreds; 
int *pUnit = &unit;
int *pTens = &tens;
int *pHundreds = &hundreds;

//Table for a 7 segment display anode
const int table_display[] = {
    0b01000000, //0 
    0b01111001, //1 
    0b00100100, //2 
    0b00110000, //3 
    0b00011001, //4 
    0b00010010, //5 
    0b00000010, //6 
    0b01111000, //7 
    0b00000000, //8 
    0b00010000, //9 
    0b00001000, //A 
    0b00000011, //B 
    0b01000110, //C 
    0b00100001, //D 
    0b00000110, //E 
    0b00001110  //F
};

void __interrupt() isr (void) {
    if (T0IF) {
    getDigits(adc2);  
    PORTB = 0b000;
    value_display = table(hundreds);
    PORTD = value_display;
    PORTB = 0b100;
    __delay_ms(10);
    PORTB = 0b000;
    value_display = table(tens);
    PORTD = value_display;
    PORTB = 0b010;
    __delay_ms(10);
    PORTB = 0b000;
    value_display = table(unit);
    PORTD = value_display;
    PORTB = 0b001;
    __delay_ms(10);

	T0IF = 0;
    }
}

void main(void) {
    
    setup();
    while(1){
       
    // Se obtiene el valor ADC del pin A0
    ADCON0bits.CHS = 0;
    ADCON0bits.GO = 1;
    while(ADCON0bits.GO);
    adc1 = (ADRESH << 8) | ADRESL;
    PORTC = (char)(adc1 >> 2); // Se muestra el valor en el pin RC0
    __delay_ms(10);

    // Se obtiene el valor ADC del pin A7
    ADCON0bits.CHS = 4; // Se selecciona de canal del ADC para A7
    ADCON0bits.GO = 1;
    while(ADCON0bits.GO);
    adc2 = (ADRESH << 8) | ADRESL;
    __delay_ms(10);
     
    }
    return;
}

void setup(void) {
    //Configuring ports
    ANSEL = 0;
    ANSELH = 0;
    TRISB = 0;
    TRISC = 0;
    TRISD = 0;
    
    //Configuring clock
    OSCCONbits.IRCF = 0b111;
    OSCCONbits.SCS  = 1;
    
    //Configuring clock source and preescaler
    OPTION_REGbits.T0CS = 0;
    OPTION_REGbits.PSA = 0;
    OPTION_REGbits.PS = 0b111;
    TMR0 = _tmr0_value;
    
    //Configuring interruptions
    INTCONbits.T0IF = 0;
    INTCONbits.T0IE = 1;
    INTCONbits.GIE = 1;
        
    //Configuration ADC
    TRISAbits.TRISA0 = 1;
    ANSELbits.ANS0 = 1;
    ADCON0bits.CHS = 0; // Selección de canal del ADC para A0
    __delay_ms(1);
    TRISAbits.TRISA5 = 1;
    ANSELbits.ANS4 = 1;
    ADCON0bits.CHS = 4; // Selección de canal del ADC para A7
    __delay_ms(1);
    ADCON1bits.ADFM = 1;
    ADCON1bits.VCFG0 = 0;
    ADCON1bits.VCFG1 = 1;
    ADCON0bits.ADON = 1;
    ADIF = 0;
}

char table(int digit) {
    return table_display[digit];
}

void getDigits(int num) {
    //float num2 = (float)(5/1023)* (float)(num*100);  
    int num2 = num/2;    
    *pHundreds = (int) (num2 / 100); //Getting hundreds
    num2 = (int) (num2 - (*pHundreds)*100);
    *pTens = (int) (num2 / 10); //Getting tens
    num2 = (int) (num2 - (*pTens)*10);
    *pUnit =(int) (num2); //Getting units 
}
