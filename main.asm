/********************************************************************************
* main.asm Demostration av timer
********************************************************************************/
.EQU LED1 = PORTB0 ; Lysdiod ansluten till pin 8 (PORTB0)
.EQU LED2 = PORTB1 ; Lysdiod ansluten till pin 9 (PORTB1)

.EQU BUTTON1 = PORTB5
.EQU BUTTON2 = PORTB4
.EQU BUTTON3 = PORTB3

.EQU TIMER1_MAX_COUNT = 6   ; Uppr�kning f�r 100 ms.
.EQU TIMER2_MAX_COUNT = 12  ; Uppr�kning f�r 200 ms.
.EQU TIMER0_MAX_COUNT = 18  ; Uppr�kning f�r 300 ms.

.EQU RESET_vect      = 0x00 ; Reset-vektor, utg�r programmets startpunkt.
.EQU PCINT0_vect     = 0x06 ; Avbrottsvektor f�r PCI-avbrott p� I/O-port B.

.EQU TIMER0_OVF_vect = 0x20 ; Avbrottsvektor f�r Timer 0 i Normal Mode
.EQU TIMER2_OVF_vect = 0x12 ; Avbrottsvektor f�r Timer 2 i Normal Mode
.EQU TIMER1_COMPA_vect = 0x16 ; Avbrottsvektor f�r Timer 2 i Normal Mode
;/********************************************************************************
;* DSEG: Dataminnet, h�r lagras statiska variabler i enlighet med f�ljande syntax
;*
;*
;*       Variabelnamn: .datatyp antal_byte 
;********************************************************************************/
.DSEG
.ORG SRAM_START  ; Allokerar variabler i b�rjan av det statiska RAM-minnet
timer0_counter: .byte 1 ; statisk uint8_t counter0 = 0
timer1_counter: .byte 1 ; statisk uint8_t counter0 = 0
timer2_counter: .byte 1 ; statisk uint8_t counter0 = 0

;/********************************************************************************
;* CSEG: Programminnet, h�r lagras programkod.
;********************************************************************************/

.CSEG
.ORG RESET_vect
   RJMP main


.ORG PCINT0_vect
RJMP ISR_PCINT0

.ORG TIMER2_OVF_vect
   RJMP ISR_TIMER2_OVF

.ORG TIMER1_COMPA_vect
   RJMP ISR_TIMER1_COMPA

.ORG TIMER0_OVF_vect
   RJMP ISR_TIMER0_OVF

;/********************************************************************************
;* ISR_PCINT0: Avbrottsrutin f�r hantering av PCI-avbrott p� I/O-port B, som
;*             �ger rum vid nedtryckning eller uppsl�ppning av n�gon av 
;*             tryckknapparna. Om nedtryckning av en tryckknapp orsakade 
;*             avbrottet togglas motsvarande lysdiod, annars g�rs ingenting.
;********************************************************************************/
ISR_PCINT0:
   CLR R26
   STS PCICR, R26 ; st�nger pciavbrott tempor�rt
   LDI R16, (1 << LED1)
   STS TIMSK0, R16 ; Ettst�ller OV timer0
check_button1:
   IN R24, PINB
   ANDI R24, (1 << BUTTON1)
   BREQ check_button2
   CALL timer1_toggle
   RETI
check_button2:
   IN R24, PINB
   ANDI R24, (1 << BUTTON2)
   BREQ check_button3
   CALL timer2_toggle
   RETI
check_button3:
   IN R24, PINB
   ANDI R24, (1 << BUTTON3)
   BREQ ISR_PCINT0_end
   CALL system_reset
ISR_PCINT0_end:
   RETI

;/********************************************************************************
;* Timer 2
;********************************************************************************/


ISR_TIMER2_OVF:
	LDS R24, timer2_counter
	INC R24
	CPI R24, TIMER2_MAX_COUNT
	BRLO ISR_TIMER2_OVF_end
	LDI R18, (1 << LED2)
	OUT PINB, R18
	CLR R24

ISR_TIMER2_OVF_end:
	STS timer2_counter, R24
	RETI 

;/********************************************************************************
;* Timer 1
;********************************************************************************/
ISR_TIMER1_COMPA:
	LDS R24, timer1_counter
	INC R24
	CPI R24, TIMER1_MAX_COUNT
	BRLO ISR_TIMER1_COMPA_end
	LDI R17, (1 << LED1)
	OUT PINB, R17
	CLR R24

ISR_TIMER1_COMPA_end:
	STS timer1_counter, R24
	RETI 

;/********************************************************************************
;* Timer 0
;********************************************************************************/
ISR_TIMER0_OVF: ; Debounce 
	LDS R24, timer0_counter
	INC R24
	CPI R24, TIMER0_MAX_COUNT
	BRLO ISR_TIMER0_OVF_end
	STS PCICR, R16 ; eTTST�LLER BITEN
	CLR R24
	STS TIMSK0, R24

ISR_TIMER0_OVF_end:
	STS timer0_counter, R24
	RETI 

;********************************************************************************
; main: Initierar systemet vid start. Programmet h�lls sedan ig�ng s� l�nge
;       matningssp�nning tillf�rs.
;********************************************************************************
main:

;********************************************************************************
; init_ports: S�tter lysdiodens pin till utport och aktiverar den interna
;             pullup-resistorn p� tryckknappens pin.
;********************************************************************************
init_ports:
   LDI R16, (1 << LED1) | (1 << LED2)
   OUT DDRB, R16
   LDI R17, (1 << BUTTON1) | (1 << BUTTON2) | (1 << BUTTON3)
   OUT PORTB, R17

;********************************************************************************
; init_interrupts: Aktiverar PCI-avbrott p� tryckknappens pin och konfigurerar
;                  Timer 0 f�r overflow-avbrott var 16.384:e ms i Normal Mode.
;********************************************************************************
init_interrupts:
   STS PCICR, R16
   STS PCMSK0, R17

init_timer0:
   LDI R16, (1 << CS02) | (1 << CS00)                ; S�tter prescaler till 1024.
   OUT TCCR0B, R16                                   ; Aktiverar Timer 0 i Normal Mode.
   LDI R18, (1 << TOIE0)                             ; Ettst�ller bit f�r avbrott i Normal Mode.
   STS TIMSK0, R18                                   ; Aktiverar OVF-avbrott f�r Timer 0.

init_timer1:
   LDI R16, (1 << CS12) | (1 << CS10) | (1 << WGM12) ; S�tter prescaler till 1024.
   STS TCCR1B, R16                                   ; Aktiverar Timer 1 i CTC Mode.
   LDI R17, 0x01                                     ; Lagrar 0000 0001 i R17.
   LDI R16, 0x00                                     ; Lagrar 0000 0000 i R16.
   STS OCR1AH, R17                                   ; Tilldelar �tta mest signifikanta bitar av 256.
   STS OCR1AL, R16                                   ; Tilldelar �tta minst signifikanta bitar av 256.
   LDI R16, (1 << OCIE1A)                            ; Ettst�ller bit f�r avbrott i CTC Mode.
   ;STS TIMSK1, R16                                   ; Aktiverar CTC-avbrott f�r Timer 1.

init_timer2:
   LDI R16, (1 << CS22) | (1 << CS21) | (1 << CS20)  ; S�tter prescaler till 1024.
   STS TCCR2B, R16                                   ; Aktiverar Timer 2 i Normal Mode.
   SEI                                               ; Nu s�tts avbrott p�.

   main_loop:
	RJMP main_loop

timer0_toggle:
   LDS R24, TIMSK0
   ANDI R24, (1 << TOIE0)
   BREQ timer0_toggle_enable
timer0_toggle_disable:
   IN R24, PORTB
   ANDI R24, ~(1 << LED1)
   OUT PORTB, R24
   CLR R24
   RJMP timer0_toggle_end
timer0_toggle_enable:
   LDI R24, (1 << TOIE0)
timer0_toggle_end:
   STS TIMSK0, R24
   RET

timer1_toggle:
   LDS R24, TIMSK1
   ANDI R24, (1 << OCIE1A)
   BREQ timer1_toggle_enable
timer1_toggle_disable:
   IN R24, PORTB
   ANDI R24, ~(1 << LED1)
   OUT PORTB, R24
   CLR R24
   RJMP timer1_toggle_end
timer1_toggle_enable:
   LDI R24, (1 << OCIE1A)
timer1_toggle_end:
   STS TIMSK1, R24
   RET

timer2_toggle:
   LDS R24, TIMSK2
   ANDI R24, (1 << TOIE2)
   BREQ timer2_toggle_enable
timer2_toggle_disable:
   IN R24, PORTB
   ANDI R24, ~(1 << LED2)
   OUT PORTB, R24
   CLR R24
   RJMP timer2_toggle_end
timer2_toggle_enable:
   LDI R24, (1 << TOIE2)
timer2_toggle_end:
   STS TIMSK2, R24
   RET

system_reset:
   IN R24, PORTB
   ANDI R24, ~((1 << LED1) | (1 << LED2))
   OUT PORTB, R24
   CLR R24 
   STS TIMSK0, R24							; St�nger av Timer 0.
   STS TIMSK1, R24							; St�nger av Timer 1.
   STS TIMSK2, R24							; St�nger av Timer 2.
   STS timer0_counter, R24					; St�nger av Timer0_counter 0.
   STS timer1_counter, R24					; St�nger av Timer1_counter 0.
   STS timer2_counter, R24					; St�nger av Timer2_counter 0.
   RET