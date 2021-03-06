.IFNDEF	_MACROAPP__INCLUDED_
.EQU	_MACROAPP__INCLUDED_ = 1
.MESSAGE "Note: <macroapp.inc> have included!" 
;=== BEGIN "macroapp.inc" ==================================================
; ���������� ����������������, ������������ ��� ���������� ������ ����������.


; (����������: ��� ������� - "������������������"!)


;***************************************************************************
;*
;*  ���������� ���������� ������
;*
;***************************************************************************


; ���������� status bit "Z" = � �������� �������� ���������: (���� ������� ����� ���������� ���������� �� ������� == @0 ?)
; ������ ������:  IF_CURRENT_FUNCTION  FunctionRTC
; �������: ������ ���������� �������� TEMP.
	.MACRO	IF_CURRENT_FUNCTION
		LDS	temp,	DMain_Mode				; ��������� �� ������ DMain_Mode -> temp
		ANDI	temp,	(0b111<<MODE_CURRENT_FUNCTION)		; 1) �������� ��, ����� �������� ������ ����������
		CPI	temp,	(@0<<MODE_CURRENT_FUNCTION)		; 2) ���������� � ��������� ���� ������ ����������
		; (���������: ���� ���� ���� �����, �� ������ Z==1)
	.ENDMACRO


; ����������� ������� ����� ���������� �� ������� @0.
; ������ ������:  SWITCH_CURRENT_FUNCTION  FunctionRTC
; �������: ������ ���������� ��������� TEMP1, TEMP2.
	.MACRO	SWITCH_CURRENT_FUNCTION
		LDS	temp,	DMain_Mode				; ��������� �� ������ DMain_Mode -> temp
		ANDI	temp,	~(0b111<<MODE_CURRENT_FUNCTION)		; 1) �������� ������� ����� ����������
		ORI	temp,	(@0<<MODE_CURRENT_FUNCTION)		; 2) ������������� ��������� ��� ������ ����������
		STS	DMain_Mode,	temp				; ��������� � ������ DMain_Mode <- temp
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS		; (�������� ������� ���� ������, ��� �������� � ������ ���������� ����������)
	.ENDMACRO



;***************************************************************************
;*
;*  ������ ���������...
;*
;***************************************************************************


; ��������� �������� �������� Timer/Counter0, � �������������� ���������� @0 � ������ (�� ������ @0 - ��.����, little-endian)
; �������: ������ ���������� �������� TEMP.
	.MACRO	CLRTCNT0
		CLR	temp		; ��� ��� ����� ����...
		OUT	TCNT0,	temp	; ���� � ������� ������� �������
		STS	@0,	temp	; ���� � ������ ���� �������� � RAM
		STS	@0+1,	temp	; ���� � ������ ���� �������� � RAM
		STS	@0+2,	temp	; ���� � ������ ���� �������� � RAM
		STS	@0+3,	temp	; ���� � �������� ���� �������� � RAM
	.ENDM


/*
; �������� ����������� ����: ������ ������ �� ����������������� �����, � ����� ����������� ��������� ���������� (���� DI HALT)...
	.MACRO	DEB_CMD
		PUSH	R16		; ��������� ������� � ����� � ����
		IN	R16,SREG
		PUSH	R16

		SBIS	UCSRA,RXC
		RJMP	PC-1
		IN	R16,UDR		; ������ UDR, ����� �������� RXC ����

					; ���������� ��� ��� ������
		CPI	R16,'R'
		BREQ	PC+0x07		; BREQ REGISTER

		CPI	R16,'M'
		BREQ	PC+0x07		; BREQ MEMORY

		CPI	R16,'I'
		BREQ	PC+0x09		; BREQ IO

		CPI	R16,'G'
		BREQ	PC+0x0A		; BREQ GONEXT


		OUT	UDR,@0		;REGISTER
		RJMP	PC+0x0008

		LDS	R16,@1		;MEMORY
		OUT	UDR,R16
		RJMP	PC+0x0004

		IN	R16,@2		;IO
		OUT	UDR,R16

		POP	R16		;GONEXT - ������� ��� ����������� �� ����� � ���� ������
		OUT	SREG,R16
		POP	R16
	.ENDM


	.MACRO	BUFF_SEND 
		LDI	R19,@0
		RCALL	Buff_Push
	.ENDM


	.MACRO	TX_RUN
		LDI	R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(1<<UDRIE)
		OUT	UCSRB, R16
	.ENDM
*/



;=== END "macroapp.inc" ====================================================
; coded by (c) Celeron, 2013  http://inventproject.info/
.ENDIF
