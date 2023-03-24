/********************************************************************************
* main.asm Demostration av timer
********************************************************************************/
.EQU LED1 = PORTB0 ; Lysdiod ansluten till pin 8 (PORTB0)
.EQU LED2 = PORTB1 ; Lysdiod ansluten till pin 9 (PORTB1)

.EQU BUTTON1 = PORTB5
.EQU BUTTON2 = PORTB4
.EQU BUTTON3 = PORTB3

.EQU TIMER1_MAX_COUNT = 6   ; Uppräkning för 100 ms.
.EQU TIMER2_MAX_COUNT = 12  ; Uppräkning för 200 ms.
.EQU TIMER0_MAX_COUNT = 18  ; Uppräkning för 300 ms.

.EQU RESET_vect      = 0x00 ; Reset-vektor, utgör programmets startpunkt.
.EQU PCINT0_vect     = 0x06 ; Avbrottsvektor för PCI-avbrott på I/O-port B.

.EQU TIMER0_OVF_vect = 0x20 ; Avbrottsvektor för Timer 0 i Normal Mode
.EQU TIMER2_OVF_vect = 0x12 ; Avbrottsvektor för Timer 2 i Normal Mode
.EQU TIMER1_COMPA_vect = 0x16 ; Avbrottsvektor för Timer 2 i Normal Mode
;/********************************************************************************
;* DSEG: Dataminnet, här lagras statiska variabler i enlighet med följande syntax
;*
;*
;*       Variabelnamn: .datatyp antal_byte 
;********************************************************************************/
.DSEG
.ORG SRAM_START  ; Allokerar variabler i början av det statiska RAM-minnet
timer0_counter: .byte 1 ; statisk uint8_t counter0 = 0
timer1_counter: .byte 1 ; statisk uint8_t counter0 = 0
timer2_counter: .byte 1 ; statisk uint8_t counter0 = 0

;/********************************************************************************
;* CSEG: Programminnet, här lagras programkod.
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
;* ISR_PCINT0: Avbrottsrutin för hantering av PCI-avbrott på I/O-port B, som
;*             äger rum vid nedtryckning eller uppsläppning av någon av 
;*             tryckknapparna. Om nedtryckning av en tryckknapp orsakade 
;*             avbrottet togglas motsvarande lysdiod, annars görs ingenting.
;********************************************************************************/
ISR_PCINT0:
   CLR R26
   STS PCICR, R26 ; stänger pciavbrott temporärt
   LDI R16, (1 << LED1)
   STS TIMSK0, R16 ; Ettställer OV timer0
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
	STS PCICR, R16 ; eTTSTÄLLER BITEN
	CLR R24
	STS TIMSK0, R24

ISR_TIMER0_OVF_end:
	STS timer0_counter, R24
	RETI 

;********************************************************************************
; main: Initierar systemet vid start. Programmet hålls sedan igång så länge
;       matningsspänning tillförs.
;********************************************************************************
main:

;********************************************************************************
; init_ports: Sätter lysdiodens pin till utport och aktiverar den interna
;             pullup-resistorn på tryckknappens pin.
;********************************************************************************
init_ports:
   LDI R16, (1 << LED1) | (1 << LED2)
   OUT DDRB, R16
   LDI R17, (1 << BUTTON1) | (1 << BUTTON2) | (1 << BUTTON3)
   OUT PORTB, R17

;********************************************************************************
; init_interrupts: Aktiverar PCI-avbrott på tryckknappens pin och konfigurerar
;                  Timer 0 för overflow-avbrott var 16.384:e ms i Normal Mode.
;********************************************************************************
init_interrupts:
   STS PCICR, R16
   STS PCMSK0, R17

init_timer0:
   LDI R16, (1 << CS02) | (1 << CS00)                ; Sätter prescaler till 1024.
   OUT TCCR0B, R16                                   ; Aktiverar Timer 0 i Normal Mode.
   LDI R18, (1 << TOIE0)                             ; Ettställer bit för avbrott i Normal Mode.
   STS TIMSK0, R18                                   ; Aktiverar OVF-avbrott för Timer 0.

init_timer1:
   LDI R16, (1 << CS12) | (1 << CS10) | (1 << WGM12) ; Sätter prescaler till 1024.
   STS TCCR1B, R16                                   ; Aktiverar Timer 1 i CTC Mode.
   LDI R17, 0x01                                     ; Lagrar 0000 0001 i R17.
   LDI R16, 0x00                                     ; Lagrar 0000 0000 i R16.
   STS OCR1AH, R17                                   ; Tilldelar åtta mest signifikanta bitar av 256.
   STS OCR1AL, R16                                   ; Tilldelar åtta minst signifikanta bitar av 256.
   LDI R16, (1 << OCIE1A)                            ; Ettställer bit för avbrott i CTC Mode.
   ;STS TIMSK1, R16                                   ; Aktiverar CTC-avbrott för Timer 1.

init_timer2:
   LDI R16, (1 << CS22) | (1 << CS21) | (1 << CS20)  ; Sätter prescaler till 1024.
   STS TCCR2B, R16                                   ; Aktiverar Timer 2 i Normal Mode.
   SEI                                               ; Nu sätts avbrott på.

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
   STS TIMSK0, R24							; Stänger av Timer 0.
   STS TIMSK1, R24							; Stänger av Timer 1.
   STS TIMSK2, R24							; Stänger av Timer 2.
   STS timer0_counter, R24					; Stänger av Timer0_counter 0.
   STS timer1_counter, R24					; Stänger av Timer1_counter 0.
   STS timer2_counter, R24					; Stänger av Timer2_counter 0.
   RET