;------------------------------------------------------------------------------------------------------------
;|	Name: 				Luftfeuchtigkeitssensor und Temperatursensor Wetterstation
;|	Funktion:			Senden der Roh-Daten vom Temperatur Sensor und Luftfeuchtigkeitssensor					
;|	Beschreibung:		Im Manuellmodus soll es einzeln Daten über die UART Schnittstelle schicken und im 
;|						Automatikbetrieb automatisch bist ein Interrupt eintrifft
;|	Autor:				Huu Duong Nguyen		
;|	Programm:			AVR Studio 4
;|	Programm Sprache:	Assambler
;|	Datum beginn:		16.03.2022
;|	Datum beendet:		16.03.2022 (Weitere änderungen wurden an Komentaren vorgenommen)
;|	Anchlüsse:			Port C0 = Temperatur Sensor
;|						Port D5 = Luftfeuchtigkeit Sensor
;------------------------------------------------------------------------------------------------------------
.include "m8def.inc"			;Importiert die Bibliothek zum einfacheren Programmieren
;------------------------------------------------------------------------------------------------------------
;	Interrupts
;------------------------------------------------------------------------------------------------------------
			rjmp conf					; Sprung Konfiguration
			reti						; 2 INT0-Interrupt (1. externer Interrupt)
			reti 						; 3 INT1-Interrupt (2. externer Interrupt)
			reti 						; 4 TC2 Compare Match
			reti 						; 5 TC2 Overflow
			reti 						; 6 TC1 Capure
			reti 						; 7 TC1 Compare Match A
			reti 						; 8 TC1 Compare Match B
			reti 						; 9 TC1 Overflow
			reti 						; 10 TC0 Overflow
			reti 						; 11 SPI, STC Serial Transfer Complete
			rjmp MainEmpfangen			; 12 UART Rx Complete
			reti 						; 13 UART Data Register Empty
			reti 						; 14 UART Tx Complete
			reti 						; 15 ADC Conversion Complete
			reti 						; 16 EEPROM Ready
			reti 						; 17 Analog Comparator
			reti 						; 18 TWI (PC) Serial Interface
			reti 						; 19 Store Program Memory Ready
;------------------------------------------------------------------------------------------------------------
;|	Konfiguration
;------------------------------------------------------------------------------------------------------------
			conf:						; Sprungmarke zur einmalligen Konfiguration
			cli							; Interrupt Deaktivieren, um die Konfiguration ohne Unterbrechungen 
										; durchzuführen 
			ldi r16,0x04				; Stackpointer Initialisieren
			out SPL,r16					; 
			ldi r16,0x5f				; 
			out SPH,r16					; 
;|	Allgemeine ADWandler Einstellungen 
			ldi r16,0b10000101			; Bit7/ADEN (Funktion: AD Wandler einschalten)
										; Bit6/ADSC (Start Conservation auf 0 = aus um noch keine Daten aufzunehmen)
										; Bit2/ADPS2 + Bit0/ADPS0 Teiler für Wandlerfequenz auf 32 einstellen)
										; ACHTUNG: Wandlerfequenz = Taktfrequenz / Teiler
										; f = 3,6864 MHz / 32 = 115KHz
										; Die Wandlerfrequenz sollte immer zwischen 50KHz und 200KHz liegen.
										; Beachten Sie die Tabelle zur Bestimmung des Teilers (ADPS2 - ADPS0)
			out ADCSRA, r16				; Kofiguration ins Register ADCSRA laden
;|	Interrupt Einstellungen 
			ldi r16, 0b00001010 		; Negative/fallende Flanke an Port D2 (Bit0 = 0, Bit1 = 1 (ISC))
										; Negative/fallende Flanke an Port D3 (Bit2 = 0, Bit3 = 1 (ISC))
			out MCUCR, r16 				; Konfiguration ins Register MCUCR laden

			ldi r16, 0b11000000 		; INT1/INT0 aktiv (Bit7(INT1) = 1, Bit6(INT0) = 1)
			out GICR, r16 				; Konfiguration ins Register GICR laden 
;|	UART Schnittstelle Einstellen 
			ldi r16, 23					; Einstellen der Baurate auf 9600 Bauds 
			out UBRRL, r16				; Konfiguration ins Register UBRRL laden

			ldi r16, 0b10000110			; Maske zur Konfiguration des UART Ports
										; Bit7/URSEL = 1 Wahl des Registers UCSRC statt UBRRH
										; Bit6/UMSEL = 0 asynchron Betrieb (Standard UART)
										; Bit5/UPM1  = Bit 4/UPM0 = 0 Parityscheck gesperrt
										; Bit3/USBS  = 0 => 1 Stoppbit (Wichtig muss die Gleiche sein wie die 
										; des Computers)
										; Bit2/UCSZ1 & Bit1/UCSZ0 = 11 => 8 Datenbits übertragen
										; Bit0/UCPOL = 0 bei asynchron Modus
			out UCSRC, r16				; Konfiguration ins Register UCSRC laden
			
			ldi r16, 0b10011000 		; Maske TxD (Sender) und RxD (Empfänger) über UART frei schalten
										; Bit7/RXCIE USART RX Complete Interrupt Enable, Löst einen Interrupt
										; Nach erfolgreichen Empfangen aus
										; Bit4/RXEN UART-Empfänger (RxD, receiver enable) frei schalten
										; Bit3/TXEN UART-Sender (TxD, transmitter enable) frei schalten
			out UCSRB, r16		 		; Konfiguration ins Register UCSRB laden
;|	Timer 1	(16 Bit) Einstellen
			ldi r16,0b00000000			; Normaler Modus (Zähler)
			out TCCR1A,r16				; Konfiguration ins Register TCCR1A laden

			ldi r16,0b00000110			; 0 = keine Geräuschunterdrückung 
										; 0 = Fallendeflancke  
										; 0 = 110 extern
			out TCCR1B,r16				; Konfiguration ins Register TCCR1B laden
;| 	Timer0 (8 Bit ) Einstellen
			ldi r16, 0b00000110			; Fallende Flanke an Counter einstellen. Counter wird standardgemäß eingeschaltet
										; Bit2-0/CS02-00: Clock Select
			out TCCR0, r16 				; Konfiguration ins Register TCCR0 laden
;| 	Reset der Werte
			ldi r19,0					; Alle Register die Variablen enthalten Reseten (auf 0 setzten)
			ldi r16,0
			ldi r17,0
			ldi r18,0
			ldi r20,0
;|	Interrupts Aktivieren
			sei							; Interrupts Aktiviern, da die Konfiguration Fertig ist
;------------------------------------------------------------------------------------------------------------
;|	Hauptprogramm
;------------------------------------------------------------------------------------------------------------
;| Überprüfen, was der PC Sendet um mit bestimmten Programm Fortzufahlern	
			Main: 	  					
			cpi r16,1					; Wenn der Wert 1 gesendet wurde
			breq Temperatur				; Sprung zu Temperatur um die Werte für die Temperatur zu Übertragen 
			cpi r16,2					; Wenn der Wert 2 gesendet wurde
			breq Luft					; Sprung zu Luft um die Werte für den Luftfeuchtigkeit zu Übertragen
			rjmp Main 					; Wenn nicht Sprung zu Main
;|	Messen der Temperatur
			Temperatur:					
			ldi r16,0b01000000			; ADMUX Konfigurieren C0 als eingang
			out ADMUX,r16				; Interne Refferenzspannung und Rechtsbündig 
				sbi ADCSRA,ADSC 		; Starten der Wandlung um die Spannung abzurufen 
			rcall Messung				; Sprung zu Temperatur zum messen und Übermitteln
			rcall Senden				; Aufruf des Unterprogramms Senden
			rjmp Main					; Sprung zu Main
;|	Messen der Luftfeuchtigkeit
			Luft:						
			out TCNT1H,r18				; TCNT1H auf 0 setzten
			out TCNT1L,r18				; TCNT1L auf 0 setzten
			rcall Zeit					; Sprung zu Zeit um eine Sekunde zu Warten
			in r17,TCNT1L				; Speichern von TCNT1H in r17
			in r16,TCNT1H				; Speichern von TCNT1L in r16
			rcall Senden				; Sprung zum Senden
			rjmp Main					; Sprung zu Main
;------------------------------------------------------------------------------------------------------------
;|	Unterprogramm
;------------------------------------------------------------------------------------------------------------
;|	Senden der Mess Daten an den PC
			Senden:						
			sbis UCSRA,UDRE				; Überprüft ob etwas gesendet wurde
					rjmp Senden 		; Wenn das Register voll ist (noch gesendet wird) Sprung zu Senden
			out UDR,r16					; Sendet r16 an den PC
			rcall Zeit					; Sekunde Pause um die Daten zusenden
			SendenL:					; Senden von Register an den Computer
			sbis UCSRA,UDRE				; Überprüft ob etwas gesendet wurde
					rjmp SendenL 		; Wenn das Register voll ist (noch gesendet wird) Sprung zu Senden
			out UDR,r17					; Sendet r17 an den PC
			rcall Zeit					; Sekunde Pause um die Daten zusenden
			ret							; Rücksprung aus dem Unterprogramm 
;|	Messung des ADWandlers auf die zuforherigen Konfig 
			Messung:					
				sbic ADCSRA,ADSC		; Überprüft ob die Wandlung abgeschlossen ist
			rjmp Messung				; Wenn nicht sprung zu Messung
			in r17,ADCL					; Laden der Untersten 8 werte in r17
			in r16,ADCH					; Laden der oberen beiden werte in r16
			ret							; Rücksprung aus dem Unterprogramm
;|	Zeitschleife für 1s
			Zeit:						
			.DEF a = r21				; Definiert r21 als Variable a
			.DEF m = r22				; Definiert r22 als Variable m
			.DEF i = r23				; Definiert r23 als Variable i
			ldi a,20					; Lädt den Wert 20 in Variable a 
			aloop:						 
			ldi m,240					; Lädt den Wert 240 in Variable m
			mloop:						; 
			ldi i,255					; Lädt den Wert 255 in Variable i
			iloop:						 
			dec i						; -1 bei Variable i
			brne iloop					; Wenn der Wert nicht 0 beträgt, sprung zu iloop
			dec m 						; -1 bei Variable m
			brne mloop					; Wenn der Wert nicht 0 beträgt, sprung zu mloop
			dec a						; -1 bei Variable a
			brne aloop					; Wenn der Wert nicht 0 beträgt, sprung zu aloop
			ret							; Rücksprung aus dem Unterprogramm
;|	MainEmpfangen
			MainEmpfangen:				
			in r16,UDR					; Übernehmen des Wertes vom PC in r16
			reti						; Zurück zur unterbrehung
