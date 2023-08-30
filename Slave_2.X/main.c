/*
 * File:   main.c
 * Author: Edgar Chen
 * Ultra., DC y SPI
 * Created on 17 de agosto de 2023, 09:09 AM
 */

// CONFIG1
#pragma config FOSC = INTRC_NOCLKOUT// Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/C LKOUT pin, I/O function on RA7/OSC1/CLKIN)
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

//Libraries 
#include <xc.h>
#include <stdint.h>
#include <stdio.h>
#include "LCD.h"
#include "FLOAT_STR.h"
#include "i2c.h"

//Variables
float time;
int distanceF, received, z;
char distanceLCD[20], writeInLCD[20];
int RDC, LDC, toggle = 1, Ultra;
unsigned char receive;

//Definitions of variables
#define _XTAL_FREQ 8000000
#define trig RA0
#define echo RA1

//Definition of functions
int ultrasonic_measure_distance(void); 
void setup(void);

//Interruptions
void __interrupt() isr(void){ 
    
    //Turn on and off DC motor
    if (INTCONbits.RBIF == 1){
        
        if (PORTBbits.RB1 == 0){    
        PORTDbits.RD1 = toggle;
        while(PORTBbits.RB1 == 0);
        }
        INTCONbits.RBIF = 0;
        toggle = ~toggle;
    }   
    //Sending data to the master via I2C
    if (PIR1bits.SSPIF == 1){ 
        SSPCONbits.CKP = 0;
       
        if ((SSPCONbits.SSPOV) || (SSPCONbits.WCOL)){
            z = SSPBUF;                 // Read the previous value to clear the buffer
            SSPCONbits.SSPOV = 0;       // Clear the overflow flag
            SSPCONbits.WCOL = 0;        // Clear the collision bit
            SSPCONbits.CKP = 1;         // Enables SCL (Clock)
        }

        if(!SSPSTATbits.D_nA && !SSPSTATbits.R_nW) {
            z = SSPBUF;                 //SSBUF lecture
            PIR1bits.SSPIF = 0;         // Cleans the reception/transmition flag
            SSPCONbits.CKP = 1;         // Enables clock pulse input
            while(!SSPSTATbits.BF);     // Wait for the reception to be completed
            received = SSPBUF;             // Saving the value of the buffer in a variable
            __delay_us(250);
            
        }else if(!SSPSTATbits.D_nA && SSPSTATbits.R_nW){
            z = SSPBUF; //Temporal variable
            BF = 0;
            SSPBUF = ultrasonic_measure_distance(); //Send distance
            SSPCONbits.CKP = 1; //Enables SCL
            __delay_us(250); 
            while(SSPSTATbits.BF);
        }
        
        PIR1bits.SSPIF = 0; //Cleaning flag
        }  
}
//Main
void main(void) {
    setup();
    Lcd_Init(); 
    while(1){
            //Saving the measured distance
            distanceF = ultrasonic_measure_distance();
            
            PORTD = distanceF; //Showing the values in the PORTD
            //Indicating the states with LEDs
            if(distanceF < 15) {
                PORTDbits.RD2 = 1;
                PORTDbits.RD3 = 0;
            }
            else{
                PORTDbits.RD2 = 0;
                PORTDbits.RD3 = 1;
            }
            __delay_ms(1500);
    }
}

void setup(void){

    ANSEL = 0b00000000;
    ANSELH = 0;
    
    TRISA  = 0b00000010;
    TRISB =  0b00000011;
    TRISC = 0;
    TRISD = 0;
    TRISE = 0;
    
    PORTA = 0;
    PORTB = 0;
    PORTC = 0;
    PORTD = 0;
    PORTE = 0;
    
//------------Interruptions-----------------
    INTCONbits.RBIE = 1; //PORTB
    INTCONbits.PEIE = 1; //Peripherial
    INTCONbits.GIE = 1;  //Global
    INTCONbits.RBIF = 0; //Flag In. PORTB
    
    OPTION_REGbits.T0CS = 0; //Fosc/4
    OPTION_REGbits.PSA = 0; //Prescaler enabled
    OPTION_REGbits.PS2 = 1; //Prescaler of 256
    OPTION_REGbits.PS1 = 1;
    OPTION_REGbits.PS0 = 1;
    
    OPTION_REGbits.nRBPU = 0; //enabling individual pull ups
    WPUBbits.WPUB0 = 1; //enabling pull ups in B0, B1 
    WPUBbits.WPUB1 = 1;
    
    IOCBbits.IOCB1 = 1; //Interrupt on change
    IOCBbits.IOCB0 = 1;

// --------------- Oscillator --------------- 
    OSCCONbits.IRCF = 0b111; // 8 MHz
    OSCCONbits.SCS = 1; // Internal
    
    T1CON = 0b00000000;
    
    I2C_Slave_Init(0xC0);
}

int ultrasonic_measure_distance(void){
    uint16_t pulse_duration; 
    int distance; 
    
    // Sending the trigger
    trig = 1; 
    __delay_us(10); 
    trig = 0; 

    while (echo == 0); //While there is no response

    TMR1L = 0x00; //Timer1 en 0
    TMR1H = 0X00;
    
    T1CONbits.TMR1ON = 1; //Initializing timer1
    while (echo == 1); //While receiving the signals
    pulse_duration = (TMR1H << 8) + TMR1L; 
    T1CONbits.TMR1ON = 0; //Turning off timer0
    distance = (pulse_duration*0.5*1)/58;

    return distance; 
}


    