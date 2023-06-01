/* 
 * File:   main.c
 * Author: Edgar Chen
 * Proyecto_2_f (servos, EEPROM, Adafruit, and the interface works)
 * EVERYTHING WORKS
 * Created on 1 jun of 2023, 01:47
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


//LIBRARIES AND DEFINE
//------------------------------------------------------------------------
#include <xc.h>
#include <stdint.h>

#define _XTAL_FREQ 8000000

//FUNCION DECLARATIONS
//------------------------------------------------------------------------
void setup(void);
unsigned short map(int val, int inMin, int inMax, short ouMin, short ouMax);
void writeToEEPROM(uint8_t data, uint8_t addres);
uint8_t readFromEEPROM(uint8_t address);

//VARIABLES
//------------------------------------------------------------------------
int x, x0, x1;
unsigned short y0, y1;

uint8_t valTmr0 = 250;
uint8_t pot3, pot4, pot5, pot6;
uint8_t counter1, counter2, counter3, counter4, tempCounter;
uint8_t flag, state;
uint8_t dirEEPROM = 0x01;
int valuePot1, valuePot2, valuePot3, valuePot4, valuePot5, valuePot6;
int potValue = 0, servo = 0;
int toggle = 1;


//INTERRUPTIONS
//------------------------------------------------------------------------
void __interrupt() isr() {
        //Interruption of the RCIF (if data is received via USART)
        if(PIR1bits.RCIF){
            
        PORTDbits.RD7 = toggle;
        toggle = ~toggle;  
        
        if(RCREG == '1'){ //Data received (indicates the potentiometer)
            servo = 1; //Value for the port of the potentiometer
        }
        else if(RCREG == '2'){
            servo = 2;
        }
        else if(RCREG == '3'){
            servo = 3;
        }
        else if(RCREG == '4'){
            servo = 4;
        }
        else if(RCREG == '5'){
            servo = 5;
        }
        else if(RCREG == '6'){
            servo = 6;
        }
    //Cleaning the flag
    PIR1bits.RCIF = 0;
    
    }
    //ADC conversion interruption
    if (ADIF) {
        //Using CCP
        if (flag == 0) { //flag indicates the potentiometer
            CCPR1L = (ADRESH>>1) + 124; //Value for the CCP
            CCP1CONbits.DC1B1 = ADRESH && 0b1; //Improving the precision with other 2 bits
            CCP1CONbits.DC1B0 = (ADRESL>>7);   
        }
        else if (flag == 1) {
            CCPR2L = (ADRESH>>1) + 124; 
            CCP2CONbits.DC2B1 = ADRESH && 0b1;
            CCP2CONbits.DC2B0 = (ADRESL>>7);
        }
        else if (flag == 2) { //mapping for the values used to generate the waves in manual PWM's
            pot3 = map(ADRESH, 0, 255, 1, 11);
        }
        else if (flag == 3) {
            pot4 = map(ADRESH, 0, 255, 1, 11);
        }   
        else if (flag == 4) {
            pot5 = map(ADRESH, 0, 255, 1, 11);
        }
        else if (flag == 5) {
            pot6 = map(ADRESH, 0, 255, 1, 11);
        }  
    //Cleaning the flag   
    ADIF = 0;      
    }
    //Interruption of Timer 0
    if (T0IF) {
        //Counter for waves of each servo motor
        counter1++;
        
        if(counter1 < pot3) { //Generating the up side
            PORTDbits.RD0 = 1;
        }
        else if (counter1 == 180) {
            counter1 = 0;
        }
        else {
            PORTDbits.RD0 = 0; //Generating the down side
        }
        
        counter2++;
        
        if(counter2 < pot4) {
            PORTDbits.RD1 = 1;
        }
        else if (counter2 == 180) {
            counter2 = 0;
        }
        else {
            PORTDbits.RD1 = 0;
        }
        
        counter3++;
         
        if(counter3 < pot5) {
            PORTDbits.RD2 = 1;
        }
        else if (counter3 == 180) {
            counter3 = 0;
        }
        else {
            PORTDbits.RD2 = 0;
        }
         
        counter4++;
        
        if(counter4 < pot6) {
            PORTDbits.RD3 = 1;
        }
        else if (counter4 == 180) {
            counter4 = 0;
        }
        else {
            PORTDbits.RD3 = 0;
        }
        //Cleaning the flag and reseting the value of TMR0
        TMR0 = valTmr0;
        T0IF = 0;
    }
    //If there is interruptions in the portB
    if (INTCONbits.RBIF) { 
        
        if (PORTBbits.RB0 == 0) { //Manual mode
            ADCON0bits.ADON = 1; //Enabling the ADC conversion
            PIE1bits.RCIE = 0;   //Disabling receptions via USART
            state = 0;          //Change of state
            while(PORTBbits.RB0 == 0);
        }
        if (PORTBbits.RB1 == 0) { //EEPROM mode
            state = 1;
            PIE1bits.RCIE = 0;
            ADCON0bits.ADON = 0;
            while(PORTBbits.RB1 == 0);
        }
        if(PORTBbits.RB2 == 0) { //UART mode (Interface)
            state = 2;
            PIE1bits.RCIE = 1;
            ADCON0bits.ADON = 0;
            while(PORTBbits.RB2 == 0);
        }
        if(PORTBbits.RB3 == 0) { //Adafruit mode
            state = 3;
            PIE1bits.RCIE = 1;
            ADCON0bits.ADON = 0;
            while(PORTBbits.RB3 == 0);
        }
        if(PORTBbits.RB4 == 0) { //Save data in EEPROM
            state = 4;
            PIE1bits.RCIE = 0;
            while(PORTBbits.RB4 == 0);
        }
        //Cleaning the flag
        INTCONbits.RBIF = 0;
    }
    
}


//MAIN
//------------------------------------------------------------------------
void main(void) {
    //Calling the setup
    setup();
    //Infinite loop
    while(1) {     
        //If we are in state 1
        if (state == 0) {
            //Indicating the state with LEDs
            PORTDbits.RD4 = 1;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 0;
            //Making conversions and assigning them to each potentiometer
            if(ADCON0bits.GO == 0) {
                if(ADCON0bits.CHS == 0b0000) {
                    flag = 1;
                    ADCON0bits.CHS = 0b0001;
            }
            else if(ADCON0bits.CHS == 0b0001) {
                flag = 2;
                ADCON0bits.CHS = 0b0010;
            }
            else if(ADCON0bits.CHS == 0b0010) {
                flag = 3;
                ADCON0bits.CHS = 0b0011;
            }
            else if(ADCON0bits.CHS == 0b0011) {
                flag = 4;
                ADCON0bits.CHS = 0b0100;
            }
            else if(ADCON0bits.CHS == 0b0100) {
                flag = 5;
                ADCON0bits.CHS = 0b0101;
            }
            else if(ADCON0bits.CHS == 0b0101) {
                flag = 0;
                ADCON0bits.CHS = 0b0000;
            }
            //Delay and enabling the conversion again
            __delay_ms(50);
            ADCON0bits.GO = 1;
            }   
        }
        //state 1
        else if (state == 1) {
            
            PORTDbits.RD4 = 0;
            PORTDbits.RD5 = 1;
            PORTDbits.RD6 = 0;
            
            //Reading the value of each potentiometer in the EEPROM
            CCPR1L = readFromEEPROM(0x01);
            CCPR2L = readFromEEPROM(0x02);
            pot3 = readFromEEPROM(0x03);
            pot4 = readFromEEPROM(0x04);
            pot5 = readFromEEPROM(0x05);
            pot6 = readFromEEPROM(0x06);
            //Waiting in the mode (we go out in a PORTB interruption)
            while(state == 1);            
        }
        //state 2
        else if (state == 2) {  
            
            PORTDbits.RD4 = 1;
            PORTDbits.RD5 = 1;
            PORTDbits.RD6 = 0;
            //Placing the values to each servo motor with corresponding to the flag received via USART from the interface
            if(servo == 1) {
                CCPR1L = 250;
            }
            else if(servo == 2) {
                CCPR2L = 130;
            }
            else if(servo == 3) {
                pot3 = 7;
            }
            else if(servo == 4) {
                pot4 = 7;
            }
            else if(servo == 5) {
                pot5 = 4;
            }
            else if(servo == 6) {
                pot6 = 10;
            }  
        }
        //state 3
        else if (state == 3) {
            
            PORTDbits.RD4 = 0;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 1;
            //Placing the values to each servo motor with corresponding to the flag received via Adafruit      
            if(servo == 1) {
                CCPR1L = 200;
            }
            else if(servo == 2) {
                CCPR2L = 185;
            }
            else if(servo == 3) {
                pot3 = 9;
            }
            else if(servo == 4) {
                pot4 = 1;
            }
            else if(servo == 5) {
                pot5 = 8;
            }
            else if(servo == 6) {
                pot6 = 8;
            }
        }
        //state 4
        else if (state == 4){
            
            PORTDbits.RD4 = 1;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 1;
            //Writing the values of the potentiometers in the EEPROM
            writeToEEPROM(CCPR1L, 0x01);
            writeToEEPROM(CCPR2L, 0x02);
            writeToEEPROM(pot3, 0x03);
            writeToEEPROM(pot4, 0x04);
            writeToEEPROM(pot5, 0x05);
            writeToEEPROM(pot6, 0x06);
        }
    }
}


//SETUP
//------------------------------------------------------------------------
void setup(void) {
    //Ports
    //1 are analog and 0 are digital
    ANSEL = 0b00111111;
    ANSELH = 0;
    //1 are inputs and 0 outputs
    TRISA = 0b00101111;
    TRISB = 0b00011111; 
    TRISC = 0;
    TRISD = 0; 
    TRISE = 0b0001;
    //Cleaning all ports
    PORTA = 0;
    PORTB = 0;
    PORTC = 0;
    PORTD = 0;
    PORTE = 0;
    
    //Configuring pull ups
    OPTION_REGbits.nRBPU = 0; //enabling individual pull ups
    WPUBbits.WPUB0 = 1; //enabling pull ups in B0, B1 and B2
    WPUBbits.WPUB1 = 1;
    WPUBbits.WPUB2 = 1;
    WPUBbits.WPUB3 = 1; //enabling pull ups in B3, B4 and B5
    WPUBbits.WPUB4 = 1;
    WPUBbits.WPUB5 = 1;
    WPUBbits.WPUB6 = 1; //enabling pull ups in B6 and B7
    WPUBbits.WPUB7 = 1;    
    
    //Oscillator
    OSCCONbits.IRCF = 0b111; //8MHz
    OSCCONbits.SCS = 1;
    
    //ADC    
    ADCON0bits.ADCS = 0b10; //FOSC/32
    ADCON1bits.VCFG0 = 0;   //Reference voltages
    ADCON1bits.VCFG1 = 0;
    ADCON1bits.ADFM = 0;     //Justify to the left
    ADCON0bits.ADON = 1;     //Enabling ADC

    ADCON0bits.CHS = 0b0000;     //Enabling channels
    ADCON0bits.CHS = 0b0001;
    ADCON0bits.CHS = 0b0010;
    ADCON0bits.CHS = 0b0011;
    
    ADCON0bits.ADON = 1;
    __delay_ms(10);
    
    OPTION_REGbits.T0CS = 0; //Timer
    OPTION_REGbits.PSA = 0;  //Enabling preescaler for TMR0 1:32
    OPTION_REGbits.PS2 = 1; 
    OPTION_REGbits.PS1 = 0;
    OPTION_REGbits.PS0 = 1;
    INTCONbits.T0IF = 0;
    
    //CCP
    CCP1CON = 0;
    CCP2CON = 0;
    CCP1CONbits.P1M = 0;        //Single output mode
    CCP1CONbits.CCP1M = 0b1100; //PWM
    CCP2CONbits.CCP2M = 0b1100; //PWM
    
    CCPR1L = 250 >> 2;
    CCP1CONbits.DC1B = 250 & 0b11;
    CCPR2L = 250 >> 2;
    CCP2CONbits.DC2B0 = 250 & 0b01;
    CCP2CONbits.DC2B1 = 250 & 0b10;
    
    PIR1bits.TMR2IF = 0;        //TMR2 flag off
    T2CONbits.T2CKPS = 0b11;    //Preescaler 1:16
    T2CONbits.TMR2ON = 1;       //Turning on TMR2
    while (!PIR1bits.TMR2IF);   //Waiting a cycle
    PIR1bits.TMR2IF = 0;
    
    TRISCbits.TRISC2 = 0;
    TRISCbits.TRISC1 = 0;
    TRISCbits.TRISC3 = 0;
    
    //Configuration of TX and RX
     TXSTAbits.SYNC = 0;  //0 and 0 for the table 
    TXSTAbits.BRGH = 0;
    
    BAUDCTLbits.BRG16 = 0;
    
    SPBRG = 12;  //12 and 0 for the table 
    SPBRGH = 0;  
    
    RCSTAbits.SPEN = 1; //Enabling serial communication
    RCSTAbits.RX9 = 0;  //Disabling the direction bit (8 bits instead of 9)
    RCSTAbits.CREN = 1; //Enabling reception
    
    TXSTAbits.TXEN = 1; //Enabling transmission
    
    //Interruptions and flags
    //Peripheral and global
    INTCONbits.GIE = 1;
    INTCONbits.PEIE= 1;

    //portB
    INTCONbits.RBIE = 1;
    INTCONbits.RBIF = 0;
    
    IOCBbits.IOCB0 = 1;
    IOCBbits.IOCB1 = 1;
    IOCBbits.IOCB2 = 1;
    IOCBbits.IOCB3 = 1;
    IOCBbits.IOCB4 = 1;
    IOCBbits.IOCB5 = 1;
    IOCBbits.IOCB6 = 1;
    IOCBbits.IOCB7 = 1;
    
    //ADC
    PIE1bits.ADIE = 1;
    PIR1bits.ADIF = 0;   
    
    //Timer0
    INTCONbits.TMR0IE = 1;
    INTCONbits.T0IF = 0;
    
    //Serial communication
    PIR1bits.RCIF = 0; //Flag of reception in 0 (still no reception)
    PIE1bits.RCIE = 1; //Reception (enable)
    
    //Initial values
    TMR0 = valTmr0;
    T0IE = 1;
    GIE = 1;
    counter1 = 0;
    counter2 = 0; 
    counter3 = 0;
    counter4 = 0;
}


//FUNCTIONS
//------------------------------------------------------------------------
//mapping
unsigned short map(int x, int x0, int x1, short y0, short y1) {
    return (unsigned short) (y0 + ((float) (y1 - y0) / (x1 - x0)) * (x - x0));
}

//Getting data from EEPROM
uint8_t readFromEEPROM(uint8_t address) {
    while (RD); //wait while reading the last data
    EEADR = address;
    EECON1bits.EEPGD = 0; //getting the data from the EEPROM
    EECON1bits.RD = 1;    
    return EEDAT; 
}

//Write to EEPROM
void writeToEEPROM(uint8_t data, uint8_t address) {
    while (WR); //wait for the last writing to finish
    EEADR = address;
    EEDAT = data;
    
    EECON1bits.WREN = 1; //Enabling writing 
    EECON1bits.EEPGD = 0; //writing in data memory
    
    INTCONbits.GIE = 0; //Disabling interruptions
    
    EECON2 = 0x55; //Security sequence
    EECON2 = 0xAA; 
    EECON1bits.WR = 1; //Writing
    
    EECON1bits.WREN = 0; //Disabling EEPROM writing
    INTCONbits.RBIF = 0;
    INTCONbits.GIE = 1; //Enabling interruptions
    while (WR);  //wait for the last writing to finish
}
