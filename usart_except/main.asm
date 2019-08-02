.org 0x000
	jmp reset
.org 0x0006 
	jmp handle_INT0
.org 0x000A
	jmp handle_INT2
.org OC1Aaddr
	jmp OC1A_Interrupt
.org 0x0028
    jmp USART_TX_Complete

;A do BCD = PD2 ; PCINT18
;B do BCD = PD3 ; PCINT19
;0 do Elevador = PD4 ; PCINT20
;1 do Elevador = PD5 ; PCINT21
;2 do Elevador = PD6 ; PCINT22
;Abrir do Elevador = PD7; PCINT23

; Fechar do Elevador = PB0; PCINT0
; Buzzer = PB1;  PCINT1
; Chamar 0 = PB2; PCINT2
; Chamar 1 = PB3; PCINT3 
; Chamar 2  = PB4; PCINT4
; LED = PB5




frase1: .db "A",'\n'
.equ sizeFrase1 = 2 
 
frase2: .db "F",'\n'
.equ sizeFrase2 = 2 

frase3: .db "ESTA PARADO'\n'"
.equ sizeFrase3 = 5 

; TODO: Escrever todas frases.

.def andar = r17
.def temp = r16
.def temp2 = r22
.def temp3 = r24
.def temp4 = r25
.def contadorSerial = r23
.def botoes = r18  ;0b  0-E0-E1-E2 0-I0-I1-I2
.equ botoesE0 = 6
.equ botoesE1 = 5
.equ botoesE2 = 4
.equ botoesI0 = 2
.equ botoesI1 = 1
.equ botoesI2 = 0
.equ B = 2
.equ A = 3
.def contador = r19

.def flags = r20  ;  0000  0-0-Estado-Porta
.equ flagsPortaFechada = 0   ; 1 - Fechada, 0 - Aberta
.equ flagsEstado = 1 ;  0 - Parado; 1 Em movimento

.def destino = r21


escreve_frase: ; assume frase em Z e size em r28, usa temp4
  pop r1
  pop r2
  sub zl, temp4
  sbci zh, 0
  do:
  dec r28
  wait:
	lpm temp4, z
	sbiw ZH:ZL, 1
	sts UDR0, temp4;
	cpi r28,0
	brne do

  push r2
  push r1

ret 


atualiza_display:
	in temp, PORTD
	cpi andar, 0
	breq atualiza_0
	cpi andar, 1
	breq atualiza_1
	cpi andar, 2
	breq atualiza_2
	jmp end_atualiza
	atualiza_0:
		cbr temp, (1 << A) | (1 << B)
		jmp end_atualiza
	atualiza_1:
		cbr temp, (1 << B)
		sbr temp, (1 << A)
		jmp end_atualiza
	atualiza_2:
		cbr temp, (1 << A)
		sbr temp, (1 << B)
		jmp end_atualiza

	; PORTD = xxxxABxx
	end_atualiza:
	out PORTD, temp
	ret
	; A = 3 PD3
	; B = 2 PD2

liga_led:
	in temp, PORTB
	sbr temp, ( 1<<5) ; Seta pino do led ON
	out PORTB, temp
	ret

apaga_led:
	in temp, PORTB
	cbr temp, ( 1<<5 ) ; Seta pino do led OFF
	out PORTB, temp
	ret

liga_buzzer:
	in temp, PORTB
	sbr temp, (1<< 1) ;Buzzer ON
	out PORTB, temp
	ret
apaga_buzzer:
	in temp, PORTB
	cbr temp, (1<< 1) ;Buzzer OFF
	out PORTB, temp
	ret

abre:
	ldi r28, sizeFrase1
	ldi zl,low(frase1*2)
	ldi zh,high(frase1*2)
	call escreve_frase
	call resetTimer
	cbr flags, (1 <<flagsPortaFechada)
	call liga_led
	call startTimer
	ret

fecha:

	sbr flags, (1 <<flagsPortaFechada)
	call apaga_buzzer
	call apaga_led
	call stopTimer
	call resetTimer
	ret

startTimer:
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	sts TCCR1B, temp ;start counter
	ret

resetTimer:
	ldi temp, 0
	sts TCNT1H, temp
	sts TCNT1L, temp
	ldi contador, 0
	ret

stopTimer:
	ldi temp, 0
	sts TCCR1B, temp ;stop counter
	ret

delay20ms:
	push r22
	push r21
	push r20
	ldi r22,byte3(16*1000*20 / 5)
	ldi r21, high(16*1000*20 / 5)
	ldi r20, low(16*1000*20 / 5)
	subi r20,1
	sbci r21,0
	sbci r22,0
	brcc pc-3
	pop r20
	pop r21
	pop r22
	ret


disable_transmit_interrupt:
	push temp
	ldi temp, 0
	sts UCSR0B, temp; 
	pop temp
	ret
enable_transmit_interrupt:
	push temp
	ldi temp, (1<<TXCIE0)|(1 << TXEN0)
	sts UCSR0B, temp; enable transmit and transmit interrupt
	pop temp
	ret
USART_TX_Complete:
	reti
	cli
	cpi contadorSerial,0
	breq tx_0 ; IF ==0
	
	;Getting PC
	pop temp   
	pop temp2

	pop temp3 ;Getting data
	sts UDR0, temp3;
	dec contadorSerial ; contadorSerial--
	;Putting PC back on the stack
	push temp
	push temp2
	tx_0:
		;call disable_transmit_interrupt
	end_tx:
	sei
	reti


handle_INT0:
	cli ; TODO: Só desligar essa interrupção
	; Fechar do Elevador = PB0; PCINT0
	; Chamar 0 = PB2; PCINT2
	; Chamar 1 = PB3; PCINT3 
	; Chamar 2  = PB4; PCINT4
	in temp2, PINB
	call delay20ms;Debouncing
	sbrc temp2,0
	jmp botao_fechar_pressionado
	sbrc temp2,2
	jmp botao_chamar0_ext_pressionado
	sbrc temp2,3
	jmp botao_chamar1_ext_pressionado
	sbrc temp2,4
	jmp botao_chamar2_ext_pressionado
	jmp end_handle_int0
	botao_chamar0_ext_pressionado:
		call liga_led
		sbr botoes, ( 1<<botoesE0)
		jmp end_handle_int0
	botao_chamar1_ext_pressionado:
		sbr botoes, ( 1<<botoesE1)
		jmp end_handle_int0
	botao_chamar2_ext_pressionado:
		sbr botoes, ( 1<<botoesE2)
		jmp end_handle_int0
	botao_fechar_pressionado:
		;TODO apagar
		ldi temp3,0x0F
		sts UDR0, temp3;
	
		sbrc flags, flagsPortaFechada
		jmp end_handle_int0
		sbrs flags, flagsEstado
		call fecha
		jmp end_handle_int0

	end_handle_int0:
	sei
	reti


handle_INT2:
	cli 
	call delay20ms;Debouncing
	;call delay20ms;
	;0 do Elevador = PD4 ; PCINT20
	;1 do Elevador = PD5 ; PCINT21
	;2 do Elevador = PD6 ; PCINT22
	;Abrir do Elevador = PD7; PCINT23

;	ldi temp, sizeFrase1
;	ldi zl,low(frase1*2)
;	ldi zh,high(frase1*2)
;	do:
;	dec temp
;	wait:
;	lds temp2, UCSR0A
;	sbrs temp2, UDRE0
;	rjmp wait 
;	lpm temp3, Z+
;	sts UDR0, temp3;
;	cpi temp,0
;	brne do

	in temp2, PIND
	
	
	sbrc temp2,4 
	jmp botao_chamar_I0_pressionado
	
	sbrc temp2,5
	jmp botao_chamar1_in_pressionado
	
	sbrc temp2,6
	jmp botao_chamar2_in_pressionado
	
	sbrc temp2,7
	jmp botao_abrir_pressionado
	
	jmp end_handle_int1
	botao_chamar_I0_pressionado:
		sbr botoes, ( 1<<botoesI0)
		jmp end_handle_int1
	botao_chamar1_in_pressionado:
		sbr botoes, ( 1<<botoesI1)
		jmp end_handle_int1
	botao_chamar2_in_pressionado:
		sbr botoes, ( 1<<botoesI2)
		jmp end_handle_int1
	botao_abrir_pressionado:
		sbrs flags, flagsEstado
		call abre
		jmp end_handle_int1

	end_handle_int1:
	sei
	reti


OC1A_Interrupt:
	cli
	;TODO
	subi contador, -1
	sbrc flags, flagsEstado
	jmp timer_estado_em_movimento
	timer_estado_parado:
		sbrc flags, flagsPortaFechada
		jmp timer_end
		cpi contador, 5
		breq contador_5
		cpi contador, 10
		breq contador_10
		jmp timer_end
    contador_5:
		call liga_buzzer
		jmp timer_end
	contador_10:
		call fecha
		jmp timer_end
	timer_estado_em_movimento:
		cpi contador, 3
		breq contador_3
		jmp timer_end
	contador_3:
		mov andar, destino
		cbr flags, (1 << flagsEstado)
		call stopTimer
		call resetTimer
		jmp timer_end



	; if Estado (em movimento == 1)
	;		contador == 3
			;	ANDAR = DESTINO
			;	ESTADO = PARADO
			;	stopTimer()
			;	resetTimer()
	; if Estado parado == 0
	;		if porta == aberta == 0
		;		if contador == 5
					;BUZZER == 1
		;		if contador == 10
					;BUZZER =  0;
					;PORTA = FECHADA;
					;stopTimer();
					;resetTimer();
	timer_end:
	sei
	reti


reset: 
cli

;CONFIG PORTB E PORTD como entrada(0) e saida(1)
ldi temp, 0b00100010
out DDRB, temp
ldi temp, 0b00001100
out DDRD, temp


;Teste da USART
ldi zl,low(frase1*2)
ldi zh,high(frase1*2)
lpm temp, Z

.equ UBRRvalue = 103
;USART_INIT

;;;

;initialize USART
ldi temp, high (UBRRvalue) ;baud rate
sts UBRR0H, temp
ldi temp, low (UBRRvalue)
sts UBRR0L, temp

;URSEL 0 = UBRRH, 1 = UCSRC (shared port address)
;UMSEL 0 = Asynchronous, 1 = Synchronous
;USBS 0 = One stop bit, 1 = Two stop bits
;UCSZ0:1 Character Size: 0 = 5, 1 = 6, 2 = 7, 3 = 8
;UPM0:1 0 = none, 1 = reserved, 2 = Even, 3 = Odd

;8data, 1 stop, no parity
ldi temp, (3<<UCSZ00)
sts UCSR0C, temp


ldi temp, (1<<RXEN0)|(1<<TXEN0)|(1<<RXCIE0)
sts UCSR0B, temp; enable receive and transmit and interrupt on rx

;;;


;baud rate
ldi temp, high (UBRRvalue) 
sts UBRR0H, temp
ldi temp, low (UBRRvalue)
sts UBRR0L, temp


;8data, 1 stop, no parity
ldi temp, (3<<UCSZ00)
sts UCSR0C, temp

call enable_transmit_interrupt
;Pin change Interrupt (23:16) and (0:7)
ldi temp, 0b00000101;
sts PCICR, temp
 
; Enables PCINT 4 TO 0, but 1 (the buzzer).
ldi temp, 0b00011101;
;out PCMSK0, temp
sts PCMSK0, temp 


; Enables PCINT 23 TO 20
ldi temp, 0b11110000
sts PCMSK2, temp 

#define CLOCK 16.0e6 ;clock speed
.equ PRESCALE = 0b100 ;/256 prescale
.equ PRESCALE_DIV = 256

#define DELAY 0.005 ;seconds
.equ WGM = 0b0100 ;Waveform generation mode: CTC
;you must ensure this value is between 0 and 65535
.equ TOP = int(0.005 + ((CLOCK/PRESCALE_DIV)*DELAY))
.if TOP > 65535
.error "TOP is out of range"
.endif

;On MEGA series, write high byte of 16-bit timer registers first
ldi temp, high(TOP) ;initialize compare value (TOP)
sts OCR1AH, temp
ldi temp, low(TOP)
sts OCR1AL, temp
ldi temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM 
sts TCCR1A, temp
;upper 2 bits of WGM and clock select

lds r16, TIMSK1
sbr r16, 1 <<OCIE1A
sts TIMSK1, r16


;Stack initialization
ldi temp, low(RAMEND)
out SPL, temp
ldi temp, high(RAMEND)
out SPH, temp




call stopTimer    ; Timer 
call resetTimer   ; Timer = Resetado
ldi andar, 0        ; Andar = 0
ldi flags, 0b00000001 ; Porta fechada e Parado.
call fecha
ldi contadorSerial,0
;TODO DELETA

sts UDR0, r30;
sei ;Enable Interrupts
main:
call atualiza_display
;TODO: Ficar printando andar no display usando PIND/B  e PORTD/B
	; IF flagEstado==1 (Em movimento)
	sbrc flags, flagsEstado
	rjmp estado_em_movimento
		estado_parado:
			sbrs flags, flagsPortaFechada ; 
			rjmp if_porta_aberta
			if_porta_fechada:
				cp destino, andar
				breq if_parado_porta_aberta_ou_fechada
				if_porta_fechada_destino_diff_atual:
					sbr flags, (1 << flagsEstado) ; Ativa Estado em Movimento
					rcall startTimer
					rjmp if_parado_porta_aberta_ou_fechada	

	rjmp main
		estado_em_movimento:
			rjmp main;
		if_porta_aberta:
		if_parado_porta_aberta_ou_fechada:
			; Switch(andar)
			cpi andar, 0
			breq andar_0
			cpi andar, 1
			breq andar_1
			cpi andar, 2
			breq andar_2
			rjmp main;

andar_0:
	; if (I0 | E0)
	; botoes = r18  ;0b  0-E0-E1-E2 0-I0-I1-I2
	sbrc botoes, botoesI0  ; IF I0==1
	rjmp andar_0_I0_E0
	sbrc botoes, botoesE0
	rjmp andar_0_I0_E0
 
	sbrc botoes, botoesI2  ; IF I2==1
	rjmp andar_0_I2_E2
	sbrc botoes, botoesE2
	rjmp andar_0_I2_E2

	sbrc botoes, botoesI1  ; IF I1==1
	rjmp andar_0_I1_E1
	sbrc botoes, botoesE1
	rjmp andar_0_I1_E1
	rjmp main
	andar_0_I0_E0:
		call abre
		cbr botoes, (1 << botoesE0)|(1<<botoesI0) ; Dá Clear nos botões E0(bit6) e I0(bit2). 
		;Produz uma máscara
		; Fazendo shift em cada posição de BIT.  Depois zera onde é 1.		
		rjmp main
	andar_0_I1_E1:
	andar_0_I2_E2:
		ldi destino, 1
		rjmp main
	
andar_1:
	; botoes = r18  ;0b  0-E0-E1-E2 0-I0-I1-I2
	sbrc botoes, botoesI1  ; IF I1==1
	rjmp andar_1_I1_E1
	sbrc botoes, botoesE1
	rjmp andar_1_I1_E1
 
	sbrc botoes, botoesI2  ; IF I2==1
	rjmp andar_1_I2_E2
	sbrc botoes, botoesE2
	rjmp andar_1_I2_E2

	sbrc botoes, botoesI0  ; IF I0==1
	rjmp andar_1_I0_E0
	sbrc botoes, botoesE0
	rjmp andar_1_I0_E0
	rjmp main
	andar_1_I1_E1:
		call abre
		ldi temp3, (1 << botoesE1)|(1<<botoesI1)
		cbr botoes, (1 << botoesE1)|(1<<botoesI1) ; Dá Clear nos botões E1 e I1. 
		;Produz uma máscara
		; Fazendo shift em cada posição de BIT.  Depois zera onde é 1.		
		rjmp main
	andar_1_I2_E2:
		ldi destino, 2
		rjmp main
	andar_1_I0_E0:
		ldi destino, 0
		rjmp main


andar_2:
	; botoes = r18  ;0b  0-E0-E1-E2 0-I0-I1-I2
	sbrc botoes, botoesI2  ; IF I2==1
	rjmp andar_2_I2_E2
	sbrc botoes, botoesE2
	rjmp andar_2_I2_E2
 
	sbrc botoes, botoesI1  ; IF I2==1
	rjmp andar_2_I1_E1
	sbrc botoes, botoesE1
	rjmp andar_2_I1_E1

	sbrc botoes, botoesI0  ; IF I1==1
	rjmp andar_2_I0_E0
	sbrc botoes, botoesE0
	rjmp andar_2_I0_E0
	rjmp main
	andar_2_I2_E2:
		call abre
		cbr botoes, (1 << botoesE2)|(1<<botoesI2) ; Dá Clear nos botões E1 e I1. 
		;Produz uma máscara
		; Fazendo shift em cada posição de BIT.  Depois zera onde é 1.		
		rjmp main
	andar_2_I1_E1:
	andar_2_I0_E0:
		ldi destino, 1
		rjmp main
