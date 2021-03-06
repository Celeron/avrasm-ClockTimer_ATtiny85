;=== BEGIN "ivectors.inc" ==================================================

; ��� ������������� "������� �������� �� ����������� ����������" - ��������� ����! 
; ���� ��� ��� ������, �� ����� ������� ����� ������������ �����, ��� ������ �����. ��� ��� �� ��������...
; (�������� �� ������ ���� � ��������� ���� - ��� ���������� ������������ ��������� �� ������ ������...)
;
; ��� �������: 
; ����������� ������ "INTERRUPT VECTORS" �� HAL-����� ���������������� (��������, "tn85def.inc"),
; �������� ��� ".equ" �� ".org"... � �������� �� ���� ������ ����� ������� RETI.
; (��� �� ��� ������, ���� ���������� �������� ������� - ����� ������� ���������� ����, ������ ����������.)


; ***** INTERRUPT VECTORS ************************************************
		.ORG	INT0addr	; External Interrupt 0
		RETI
		.ORG	PCI0addr	; Pin change Interrupt Request 0
		RETI
		.ORG	OC1Aaddr	; Timer/Counter1 Compare Match 1A
		RETI
		.ORG	OVF1addr	; Timer/Counter1 Overflow
		RETI
		.ORG	OVF0addr	; Timer/Counter0 Overflow
		RJMP	TIMER0_OVERFLOW_HANDLER
		.ORG	ERDYaddr	; EEPROM Ready
		RETI
		.ORG	ACIaddr		; Analog comparator
		RETI
		.ORG	ADCCaddr	; ADC Conversion ready
		RETI
		.ORG	OC1Baddr	; Timer/Counter1 Compare Match B
		RETI
		.ORG	OC0Aaddr	; Timer/Counter0 Compare Match A
		RETI
		.ORG	OC0Baddr	; Timer/Counter0 Compare Match B
		RETI
		.ORG	WDTaddr		; Watchdog Time-out
		RETI
		.ORG	USI_STARTaddr	; USI START
		RETI
		.ORG	USI_OVFaddr	; USI Overflow
		RETI

		.ORG	INT_VECTORS_SIZE	; ����� ������� ����������


;=== END "ivectors.inc" ====================================================
