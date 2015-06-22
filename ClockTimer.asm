
	.NOLIST				; Disable listfile generation.
	.include "tn85def.inc"		; ���������� HAL ����������������.
	.include "macrobaselib.inc"	; ���������� ������� ����������������.
	.include "macroapp.inc"		; ���������� ����������������, ������������ ��� ���������� ������ ����������.
	.LIST				; Reenable listfile generation.
	;.LISTMAC			; Turn macro expansion on?	(��� �������, ���������� ���� ��������� �������� � ������������������� ���� - ������, �� ������� ��������, �.�. ���������� ����� ������.)

	.include "data.inc"		; ������ ���������: 
					;	��������� � ���������� ���������; 
					;	������� SRAM � ����������; 
					;	������� EEPROM.


;***************************************************************************
;*
;*  FLASH (������� ����)
;*
;***************************************************************************
			.CSEG

		.ORG	0x0000		; (RESET) 
		RJMP	RESET
		.include "ivectors.inc"	; ������� �������� �� ����������� ����������


;***** BEGIN Interrupt handlers section ************************************

;---------------------------------------------------------------------------
;
; ����������: ������ ����������
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

; �������: ���������� �� ������ ���������� ��� - ��������� �������� ������������ �������� ������...

;----- Code

TIMER0_OVERFLOW_HANDLER:
		; ��������� � ����� ��������, ������� ������������ � ������ �����������:
		PUSHF		; ��������� ����� ������������ ��������: SREG � TEMP (TEMP1)
		PUSH	temp2	; ������� ������������ � INVB � ��.
		PUSH	temp3	; ������� ������������ � DISPLAY_REFRESH, DISPLAY_PREPARE, KEY_ENHANCE_TIME_FOR_ALL_BUTTONS
		PUSH	temp4	; ������� ������������ � DISPLAY_REFRESH, DISPLAY_PREPARE
		PUSH	R25	; ������� ������������ � INC_TIME_SECONDS, CODE2SYMBOL, DISPLAY_PRINT_TIMER_MODE
		PUSH	R26	; (XL)	������� ������������ � INC_TIME_SECONDS, DISPLAY_PRINT_DIGITS
		PUSH	R27	; (XH)	������� ������������ � INC_TIME_SECONDS, DISPLAY_PRINT_DIGITS
		PUSH	R28	; (YL)	������� ������������ � HandleTimerX__SECOND_ELAPSED_HELPER, DISPLAY_REFRESH, DISPLAY_PRINT_DIGITS, KEY_ENHANCE_TIME_FOR_ALL_BUTTONS
		PUSH	R29	; (YH)	������� ������������ � HandleTimerX__SECOND_ELAPSED_HELPER, DISPLAY_REFRESH, DISPLAY_PRINT_DIGITS, KEY_ENHANCE_TIME_FOR_ALL_BUTTONS
		PUSH	R30	; (ZL)	������� ������������ � CODE2SYMBOL
		PUSH	R31	; (ZH)	������� ������������ � CODE2SYMBOL


		STOREB	DMain_Mode,	MODE_SECONDSIGN			; ���� "��������� �� ���������� �������� ��������" -> T
		BRTS	HalfSecond__TIMER0_OVERFLOW_HANDLER		; ���� ��������� ������ ������ �������� �������? �������� ����������� ����������...


		; ���������� ����������� ��������� � �������� ������������ "�������":
		RCALL	SECOND_ELAPSED_HANDLER_RTC

		LDI	TimerModeAddressLow,	Low(DTimer1_Mode)	; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	TimerModeAddressHigh,	High(DTimer1_Mode)	;
		RCALL	SECOND_ELAPSED_HANDLER_TIMER

		LDI	TimerModeAddressLow,	Low(DTimer2_Mode)	; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	TimerModeAddressHigh,	High(DTimer2_Mode)	;
		RCALL	SECOND_ELAPSED_HANDLER_TIMER

		; ��������� �������� ����� �������� "������� ������" (��������� ������ �������)
		RCALL	SLEEPER_SECOND_ELAPSED


HalfSecond__TIMER0_OVERFLOW_HANDLER:
		INVB	DMain_Mode,	MODE_SECONDSIGN			; ������������� "��������� ��������"
		
		; �������� ������� (������ ����������)
		RCALL	DISPLAY_PREPARE
		RCALL	DISPLAY_REFRESH

		; �������� ��������� �������� ��������� ������:	���������� ������� ��� ������������ ������ (��������� ������ ����������)
		RCALL	KEY_ENHANCE_TIME_FOR_ALL_BUTTONS


		; ����� �� �����������
		POP	R31
		POP	R30
		POP	R29
		POP	R28
		POP	R27
		POP	R26
		POP	R25
		POP	temp4
		POP	temp3
		POP	temp2
		POPF
		RETI	



;----- Subroutine Register Variables

; ����������: ���� � ��������� � ��� ���� - ������� �� ������ �� ��������� �����������������...

; �������: ����� ����������/������ ���������� ���������: TEMP1, TEMP2,
;	X(R27:R26), R25 (������������� � INC_TIME_SECONDS).

;----- Code

SECOND_ELAPSED_HANDLER_RTC:

		; ���������� ����:

		STOREB	DClock_Mode,	MODE_ENABLED			; ���� "����� ����������" -> T:	=1 ����� (������),	=0 �������������
		BRTC	EndRTC__SECOND_ELAPSED_HANDLER_RTC		; ���� �����������?
		LDI	ExtendTimeInAddressLow,	Low(DClock_Seconds)	; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	ExtendTimeInAddressHigh,High(DClock_Seconds)	;
		LDI	ExtendTimeByValue,	1			; �������� ����������
		CLT							; T=0 (�������� ���������)	��������� �������/��� �� �������� ������� (�� ���������, ��� ������������ ������ ���������)
		RCALL	INC_TIME_SECONDS				; +1���
	EndRTC__SECOND_ELAPSED_HANDLER_RTC:


		; ���������: �� �������� �� ���������? (���� �� �����������, � ����� ������)

		STOREB	DAlarm_Mode,	MODE_ENABLED			; ���� "����� ����������" -> T:	=0 ��������,	=1 ������� (����� �������)
		BRTC	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; ���������: �������������?
		STOREB	DAlarm_Mode,	MODE_BELLRINGING		; ���� "����� ������" -> T:	=0 ������,	=1 ����� ����� ������ (����� ������)!
		BRTS	RingingNowAlarm__SECOND_ELAPSED_HANDLER_RTC	; ���������: ��� ������?

		; (���������: �������, �� ��� �� ������)
		; ���� ���������: ����� ������� ����� "�������� ������"?
		LDS	temp1,	DClock_Seconds
		TST	temp1
		BRNE	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; ������, �� ������ ������: �������!=0	(����������: ��������� ���������� ������ �� ������ ������� ��������� "������� ����������"! ������ �������� ��������� ������������� "����������������� ������ ����������" ������ ������.)
		LDS	temp1,	DAlarm_Minutes
		LDS	temp2,	DClock_Minutes
		CP	temp1,	temp2
		BRNE	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; ������ �� ���������
		LDS	temp1,	DAlarm_Hours
		LDS	temp2,	DClock_Hours
		CP	temp1,	temp2
		BRNE	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; ���� �� ���������

		; ����� ������ - �������� ������!
		SETB	DAlarm_Mode,		MODE_BELLRINGING	; ���������: �������� ������
		OUTI	DAlarm_RingTimeout,	CAlarmRingDuration	; ������� ������ �� ������� ������
		RCALL	SLEEPER_RESET					; "�����������" ��� alarm-�
		; �, ���� �� �������� � "������ ����������" (MODE_SETTINGS==0), �� ������������ ����������� ������� ����� ����������, �� �������, ������� �����: MODE_CURRENT_FUNCTION = FunctionRTC.
		STOREB	DMain_Mode,	MODE_SETTINGS			; ���������:  DMain_Mode -> temp;  MODE_SETTINGS -> T
		BRTS	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; ���� T==1 (������, �������� � "������ ����������") - �� �������������...
		SWITCH_CURRENT_FUNCTION		FunctionRTC
		RJMP	EndAlarm__SECOND_ELAPSED_HANDLER_RTC

	RingingNowAlarm__SECOND_ELAPSED_HANDLER_RTC:
		; ������� � ��� ������ - ���� ���������: ����� ��� ������ �������?
		DEC8M	DAlarm_RingTimeout
		BRNE	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; ��� �� �������� �� ����?
		CLRB	DAlarm_Mode,	MODE_BELLRINGING		; ���������: �������� �����

	EndAlarm__SECOND_ELAPSED_HANDLER_RTC:

		RET



;----- Subroutine Register Variables

.def	TimerModeAddressLow	= R28	; YL
.def	TimerModeAddressHigh	= R29	; YH

; �������: ����� ����������/������ ���������� ���������: TEMP1, TEMP2,
;	X(R27:R26), R25 (������������� � INC_TIME_SECONDS).

;----- Code

SECOND_ELAPSED_HANDLER_TIMER:

		LD	temp,	Y					; ��������� ���� "�����" �� ������: DTimerX_Mode = (DTimerX+0)
		BST	temp,	MODE_ENABLED				; ���� "����� ����������" -> T:		=0 ����������,	=1 �����
		BRTC	StoppedTimer__SECOND_ELAPSED_HANDLER_TIMER	; ���������: ������X ����������?


		; ���������� ������:
		MOV	ExtendTimeInAddressLow,	TimerModeAddressLow	; �����, ��������� � �������: ����� DTimerX
		MOV	ExtendTimeInAddressHigh,TimerModeAddressHigh	;
		SUBI	ExtendTimeInAddressLow,	(-1)			; � ��������������, ���������: ����� DTimerX_Seconds = (DTimerX+1)
		SBCI	ExtendTimeInAddressHigh,(-1)
		LDI	ExtendTimeByValue,	1			; �������� ����������
		
		;LD	temp,	Y					; ��������� ���� "�����" �� ������: DTimerX_Mode = (DTimerX+0)
		BST	temp,	MODE_UPDOWN				; ���� "����� �����������" -> T:	=0 ������ ����,	=1 �������� ����
		BRTS	DownTimer__SECOND_ELAPSED_HANDLER_TIMER
		CLT							; T=0 (�������� ���������)	��������� �������/��� �� �������� ������� (�� ���������, ��� ������������ ������ ���������)
		RCALL	INC_TIME_SECONDS				; +1���
		RJMP	EndTimer__SECOND_ELAPSED_HANDLER_TIMER
	DownTimer__SECOND_ELAPSED_HANDLER_TIMER:
		CLT							; T=0 (�������� ���������)	��������� �������/��� �� �������� ������� (�� ���������, ��� ������������ ������ ���������)
		RCALL	DEC_TIME_SECONDS				; -1���


		; ���������: �� �������� �� ������? (���� �� �����������, � �������� ����, � �������� �� ����)
		LDD	temp,	Y+1					; ��������� ���� �� ������: DTimerX_Seconds = (DTimerX+1)
		TST	temp
		BRNE	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; ������� != 0
		LDD	temp,	Y+2					; ��������� ���� �� ������: DTimerX_Minutes = (DTimerX+2)
		TST	temp
		BRNE	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; ������ != 0
		LDD	temp,	Y+3					; ��������� ���� �� ������: DTimerX_Hours = (DTimerX+3)
		TST	temp
		BRNE	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; ���� != 0

		; ����� ������ - �������� ������!
		LD	temp,	Y					; ��������� ���� "�����" �� ������: DTimerX_Mode = (DTimerX+0)
		ANDI	temp,	~(1<<MODE_ENABLED)			; ���������: ���������� ������
		ORI	temp,	1<<MODE_BELLRINGING			; ���������: �������� ������
		ST	Y,	temp
		LDI	temp,	CTimerRingDuration			; ������� ������ �� ������� ������
		STD	Y+4,	temp					; ��������� ���� � �����: DTimerX_RingTimeout = (DTimerX+4)
		RCALL	SLEEPER_RESET					; "�����������" ��� alarm-�
		; �, ���� �� �������� � "������ ����������", �� ������������ ����������� ������� ����� ����������, �� �������, ������� �����: MODE_CURRENT_FUNCTION = FunctionTIMER.
		STOREB	DMain_Mode,	MODE_SETTINGS			; ��������� DMain_Mode -> temp; MODE_SETTINGS -> T
		BRTS	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; ���� T==1, ������ �������� � "������ ����������" - �� �������������.
		LDD	temp2,	Y+5					; ��������� ���� "����� ����������" �� ������: DTimerX_FunctionID = (DTimerX+5)
		ANDI	temp,	~(0b111<<MODE_CURRENT_FUNCTION)		; 1) �������� ������� ����� ����������
		OR	temp,	temp2					; 2) ������������� ��������� ����� ����������
		STS	DMain_Mode,	temp				; ��������� DMain_Mode <- temp
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS		; (�������� ������� ���� ������, ��� �������� � ������ ���������� ����������)
		RJMP	EndTimer__SECOND_ELAPSED_HANDLER_TIMER

	StoppedTimer__SECOND_ELAPSED_HANDLER_TIMER:
		; ���� ���������: ����� ��� ������ �������? (���� ������)
		LDD	temp,	Y+4					; ��������� ���� �� ������: DTimerX_RingTimeout = (DTimerX+4)
		SUBI	temp,	(1)					; ���������������� ������� ������
		STD	Y+4,	temp
		BRNE	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; ��� �� �������� �� ����?
		LD	temp,	Y					; ��������� ���� "�����" �� ������: DTimerX_Mode = (DTimerX+0)
		ANDI	temp,	~(1<<MODE_BELLRINGING)			; ���������: �������� �����
		ST	Y,	temp

	EndTimer__SECOND_ELAPSED_HANDLER_TIMER:

		RET


;***** END Interrupt handlers section 


;***** ������������� *******************************************************
RESET:
		WDTOFF		; Disable Watchdog timer permanently (ensure)
		STACKINIT	; ������������� �����
		RAMFLUSH	; ������� ������
		GPRFLUSH	; ������� ���


;***** BEGIN Internal Hardware Init ****************************************

; ������������� ������:

		OUTI	PORTB,	0				; �������� ������� �������� ������ �����B (��������� ���������)
		OUTI	DDRB,	(1<<PinClock1)|(1<<PinClock2)	; ������ Clock1, Clock2 - �� "�����" (OUT)
		SETB	PORTB,	PinClock2			; ���������� ������ PinClock2="1": ���������� ��������� - ��������� �������/����������	(���������� ��������� ��������, ��� ���������� ������� RC-�������, ����������� ������, ������� �������, �� ����� ���������� ������)


; ������������� Timer/Counter0, ������� ������� �������:

		SETB	TIMSK,	TOIE0	; ��������� ���������� �������: Overflow Interrupt Enable 
		OUTI	TCCR0B,	(0<<CS02)|(1<<CS01)|(1<<CS00)	; ��������� ������: ������������ = clkIO/64 (�������� = From prescaler, �� �������� �������)
								; ����������: �������� ������������:
								;	CLK_XTAL = 32768 Hz
								;	TIMER1_PERIOD  = 0.5sec (�����, ��� ������������ � �������)
								;	TIMER1_DIVIDER = CLK_XTAL * TIMER0_PERIOD / 256	= 64	(��������� ������ ���������� �����, �������� ������, ������, ��������� �������������� ������������� �������!)
		RCALL	RESET_TIMER0	; �������� ������

;***** END Internal Hardware Init 


;***** BEGIN External Hardware Init ****************************************
;***** END External Hardware Init 


;***** BEGIN "Run once" section (������ ������� ���������) *****************

; ������������� "������ ����������"

		OUTI	DMain_Mode,		(1<<MODE_SECONDSIGN)|(FunctionRTC<<MODE_CURRENT_FUNCTION)	; ������� ����� = "���� ��������� �������"
														; ��������� ��������: ������������ � ������ �������� ������� (��� ������������: �������� ���������� ������ � ������������� ���� �� ����������)


; ������������� "����� ��������� �������"

		OUTI	DClock_Mode,		(1<<MODE_ENABLED)|(0<<MODE_AUTOHOURS)|(0<<MODE_INPUTSECONDS)	; ��������� "���� ��������� �������"
		;OUTI	DClock_Seconds,		55					; DEBUG: �������
		;OUTI	DClock_Minutes, 	59					; DEBUG: ������
		;OUTI	DClock_Hours,   	6					; DEBUG: ����


; ������������� "����������"
		.equ	CAlarm_DefaultMode   =	(0<<MODE_ENABLED)|(0<<MODE_AUTOHOURS)|(0<<MODE_INPUTSECONDS)	; �� ���������, ���������: ����������
		; ���������� ��������� ��������� ���������� �� EEPROM (DAlarm <- EAlarm)
		LDI	EepromAddressLow,	Low(EAlarm_SavedSettings)		; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	EepromAddressHigh,	High(EAlarm_SavedSettings)		; 
		LDI	SramAddressLow,		Low(DAlarm_Mode)			; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	SramAddressHigh,	High(DAlarm_Mode)			; 
		LDI	PumpBytesCount,		EAlarm_size				; ���������� ������ (� ������)
		RCALL	EEPROM_READ_SEQUENCE
		;SETB	DAlarm_Mode,		MODE_ENABLED				; DEBUG: �������� ���������


; ������������� "�������1"

		OUTI	DTimer1_Mode,		(0<<MODE_ENABLED)|(0<<MODE_UPDOWN)|(1<<MODE_AUTOHOURS)|(1<<MODE_INPUTSECONDS)	; ��������� ����� �������: ����������
		OUTI	DTimer1_Seconds,	0					; �������
		OUTI	DTimer1_Minutes,	0					; ������
		OUTI	DTimer1_Hours,		0					; ����
		OUTI	DTimer1_FunctionID,	(FunctionTIMER1<<MODE_CURRENT_FUNCTION)	; ��������������� ��� "����� ����������"


; ������������� "�������2"

		OUTI	DTimer2_Mode,		(0<<MODE_ENABLED)|(0<<MODE_UPDOWN)|(1<<MODE_AUTOHOURS)|(1<<MODE_INPUTSECONDS)
		OUTI	DTimer2_Seconds,	0
		OUTI	DTimer2_Minutes,	0
		OUTI	DTimer2_Hours,		0
		OUTI	DTimer2_FunctionID,	(FunctionTIMER2<<MODE_CURRENT_FUNCTION)


; ������������� "������� ��������"
		; ���������� ���������� �� EEPROM (DSymbolsTable  <- ESymbolsTable)
		LDI	EepromAddressLow,	Low(ESymbolsTable)			; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	EepromAddressHigh,	High(ESymbolsTable)			; 
		LDI	SramAddressLow,		Low(DSymbolsTable)			; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	SramAddressHigh,	High(DSymbolsTable)			; 
		LDI	PumpBytesCount,		SymbolsTable_size			; ���������� ������ (� ������)
		RCALL	EEPROM_READ_SEQUENCE


; ������������� "������� ������"
		RCALL	SLEEPER_RESET


		SEI  ; ��������� ���������� ����������

;***** END "Run once" section 

;***** BEGIN "Main" section ************************************************

MAIN:
		; (���������: ����������� ������������ ������ � ������������ �������)

		; ������������ ������
		OUTI	DKeyScanCnt,	20				; DKeyScanCnt = ���������� ������ "������������ ������".	(� ����� ����� ���� ���� "������� �� �������")
	LoopKeyScan__MAIN:
		RCALL	KEY_SCAN_INPUT					; �������� ��������� �������� ��������� ������: ��������� ���������� ������ � ������������� �� ������-�������� (��������� �����)
		DEC8M	DKeyScanCnt
		BRNE	LoopKeyScan__MAIN
		
		; ������������ ������� ("������� �� �������")
		RCALL	SWITCH_MODES					; �����: DKeyScanCnt, ����, ������� ��������� ���, ����� "SWITCH_MODES" ���������� ~10-20���/���. ����� ����� ������������ "�������������" ������� ������ (��� �������� �����: ��� ������ ������ "DButtonStartStatus", ��� ����� �������� ���������, � ������ ���������)...
		
		RJMP	MAIN						

		; (��������� ������� ���������)


;***** END "Main" section 

;***** BEGIN Procedures section ********************************************

	; ��������! � ������� �� ��������, ��� ��������, ������ � ���������, 
	; ���������� � ������� ������ ��������� - �������� �����! 
	; �������, ����� ������ ���� �������� ������ �� ���������, ������� 
	; ������� ������������. (��������� - ������� /* ���������������� */.)

	.include "proclib.inc"			; ���������� ����������� �����������.
	.include "avr204.inc"			; ���������� �������� ���������� ��� �� Atmel. (AVR204 AppNote)
	.include "procDisplayOutput.inc"	; ���� ���������� � ������������� ������������ ��������, ��������������� ��� ��������� ������: �� �������������� ����������, ����������� ��������, ����� ��������� ��������.	(�������� � ��������� ����, ��� ��������)
	.include "celeronkeyinputlib.inc"	; ���������� �������� ��� ���������������� ��������� �����: ������������ ������ � ���������.



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;
; ������������� ���������: "�������������� �������� �������� ������� � ������"
;
; 
; ��������� ��������������: ��������� (CALL INC_*) ��� ��������� (CALL DEC_*),
; "������� �������" ������������� � ������ � ������: ExtendTimeInAddress,
; �� ����� ��������� ���������� (ExtendTimeByValue)... � ����� ������:
; 	������ (CALL *_TIME_SECONDS) ���
; 	�����  (CALL *_TIME_MINUTES) ���
; 	�����  (CALL *_TIME_HOURS).
;
; ����������: ��� ������ ��������� ������� �� ���� "�������-������" (� ������ "��������"-������� � ����� ���-��������) - 
; �������, � ����������� �� ��������� �������, ������� �������� ��������������� ����� �����...
;
; ����������: ������ "�������� �������", � ������, �������������� ��������� (little-endian): [�������, 1���� ������� /] �����, 1���� ������ / �������, 1���� ����.
; �������� ExtendTimeInAddress ������� ���������������� �� ����� ��� ������, ������� ��������� ������� ��������������, � ����� ������� ����� ����� �������� ��������� - ��������:
; 	����� ���������/������ ��������� ������: ExtendTimeInAddress = ����� [����������] ����� ������;	� ������� ����� ����� (CALL *_TIME_SECONDS).
; 	����� ���������/������ ��������� �����:  ExtendTimeInAddress = ����� [��������]   ����� �����;	� ������� ����� ����� (CALL *_TIME_MINUTES).
; 	����� ���������/������ ��������� �����:  ExtendTimeInAddress = ����� [����������] ����� �����;	� ������� ����� ����� (CALL *_TIME_HOURS).
;
;
; ����������: �������, � "�������� �������", ������� �����/�����/������ ������� ����� �����: "����" - ��� "������� ������" ��� "�����", � "������" - ������� ��� "������"... 
; � ���������� ������� �������� ������ � ������� ������� (��������, ����� 59��� +1���), ��� ��� ������ �� �������� ������� (��������, ���� 0��� -1���)...
;
; ����������: �� ���������, � ��� ��������� ������������ ������ ���������: ��� �� �����������, �������� �������� ������������� ������������� �� ����������� �������� (�� 60���, 60���, 24�), � ����� ������������ ��������/���� � �������� �������.
; �� � ������ "������ ���������� ����������" �������� ���������: ������������ ������������� ������� �������, ����� ��������� �������� - ��� ��� ��������� �������� � ������ ������������ (��������� ����������� �������� �����/�����/������).
; �������, ���������� ��� �������� ������� - status bit "T":
; 	T=0	��������� �������/��� �� �������� ������� (�� ���������, ��� ������������ ������ ���������)
; 	T=1	��������� �������/��� �� �������� ������� (������������ � �������� "������ ���������" �������� �������)
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

.def	ExtendTimeInAddressLow	= R26	; XL
.def	ExtendTimeInAddressHigh	= R27	; XH
.def	ExtendTimeByValue	= R25

; �����, ���������� �������� status bit "T": 
; 	T=0	��������� �������/��� �� �������� ������� (�� ���������, ��� ������������ ������ ���������)
; 	T=1	��������� �������/��� �� �������� ������� (������������ � �������� "������ ���������" �������� �������)

; �������: ����� ����������/������ ���������� ��������� TEMP1, TEMP2.

;----- Code


INC_TIME_SECONDS:
		LDI	temp2,	60	; ��������: ����������� ����
		RCALL	INC_TIME_HELPER

INC_TIME_MINUTES:
		LDI	temp2,	60
		RCALL	INC_TIME_HELPER
		
INC_TIME_HOURS:
		LDI	temp2,	24
		RCALL	INC_TIME_HELPER

		RET


; �������������, �������� ���� ������������ ��������� �� ��� �� �������, ��� � ���������.
; �� � ������� ����, �� ����������� ��� ����������� (TEMP2 = 24���� vs. 60���/���), - ����� ������� �������.
; ������� "��� ����������� ������ ����" ������� � ��������� ��������������� ���������:

INC_TIME_HELPER:
		; ��� ������ ��������: � ������� �� ������ ���������� ���� ���������� ������� - ������ �� ����������, ��� ��� �������?
		; (����� �������� ����� ��������� � ����, ������������, ��� ���������� �������� � ������� ������)
		TST	ExtendTimeByValue
		BREQ	Exit__INC_TIME_HELPER			; ���� ExtendTimeByValue == 0, �� RET.

		; ������ ��������� �������:
		LD	temp1,	X				; ��������� �������� ������/�����/����� �� ������, �� ������ ExtendTimeInAddress.
		ADD	temp1,	ExtendTimeByValue		; ���������� ��������� �����. (�������, ��� � ������ ������ �������: Rd=59+255=314, �.�. Rd=314-256=58 � "���� ����" C=1)
		CLR	ExtendTimeByValue			; ������ ����� ����� �������� �������� � ������� ������... (����������: ������ ���������� �� ���������� "���� ����" C, �� ���������� ��������)

		; ���� ��� ������������ ������� ����� ����������� �����, �� ������ ���������:
		BRCC	SkipCorrection__INC_TIME_HELPER
		; (��������� �������� ���������)
		CPI	temp2,	60				; ���������: ������� ���� - ��� "������"/"�������"?
		BRNE	CorrectHours__INC_TIME_HELPER		; ��� "����"...
CorrectSecMin__INC_TIME_HELPER:
		; (+256��� = +4��� +16���) ��� ����� (+256��� = +4� +16���)
		SUBI	ExtendTimeByValue,	(-4)
		SUBI	temp1,			(-16)
		RJMP	SkipCorrection__INC_TIME_HELPER
CorrectHours__INC_TIME_HELPER:
		; (+256� = +10����� +16�)
		SUBI	ExtendTimeByValue,	(-10)
		SUBI	temp1,			(-16)
SkipCorrection__INC_TIME_HELPER:

		; ����������� �������� ���� �� �������� ��� ����������� TEMP2	(����������: ������ �������� ������� ��������� "bin2bcd8" � AVR204)
Normalization__INC_TIME_HELPER:
		SUB	temp1,	temp2				; ��������� �������� ��������������� ���� �� "��� �������"
		BRCS	EndNormalization__INC_TIME_HELPER	; ���� �������� ������ ���� (C=1), �� ������...
		INC	ExtendTimeByValue			; ���� �� ��������, �� ����������� ��� � +1 ������� ������
		RJMP	Normalization__INC_TIME_HELPER		; loop again
EndNormalization__INC_TIME_HELPER:
		ADD	temp1,	temp2				; ...��������� ���������� �������: ������� +���� "��� �������"

		ST	X+,	temp1				; ��������� �������� �������� ������/�����/����� � ������. � ���������� ����� ������� ������ ExtendTimeInAddress �� +1 ����.
		BRTC	Exit__INC_TIME_HELPER			; ���� T==0	-> ��������� �������/��� �� �������� ������� (�� ���������, ��� ������������ ������ ���������)
		CLR	ExtendTimeByValue			; ���� T==1	-> ��������� �������/��� �� �������� ������� (������������ � �������� "������ ���������" �������� �������)

Exit__INC_TIME_HELPER:
		RET						; ����� �� ��������������� ���������



;----- Code


DEC_TIME_SECONDS:
		LDI	temp2,	60	; ��������: ����������� ����
		RCALL	DEC_TIME_HELPER

DEC_TIME_MINUTES:
		LDI	temp2,	60
		RCALL	DEC_TIME_HELPER
		
DEC_TIME_HOURS:
		LDI	temp2,	24
		RCALL	DEC_TIME_HELPER

		RET


; �������������, �������� ���� ����������� ��������� �� ��� �� �������, ��� � ���������.
; �� � ������� ����, �� ����������� ��� ����������� (TEMP2 = 24���� vs. 60���/���), - ����� ������� �������.
; ������� "��� ����������� ������ ����" ������� � ��������� ��������������� ���������:

DEC_TIME_HELPER:
		; ��� ������ ��������: � ������� �� ������ ���������� ���� ���������� ������� - ������ �� ����������, ��� ��� �������?
		; (����� �������� ����� ��������� � ����, ������������, ��� ���������� �������� � ������� ������)
		TST	ExtendTimeByValue
		BREQ	Exit__DEC_TIME_HELPER			; ���� ExtendTimeByValue == 0, �� RET.

		; ������ ��������� �������:
		LD	temp1,	X				; ��������� �������� ������/�����/����� �� ������, �� ������ ExtendTimeInAddress.
		SUB	temp1,	ExtendTimeByValue		; �������� ��������� �����. (�������, ��� � ������ ������ �������: Rd=0-255=-255, �.�. Rd=256-255=1 � "���� ����" C=1) ��� (-255��� = -4��� -15���)
		CLR	ExtendTimeByValue			; ������ ����� ����� �������� ���� �� �������� �������... (����������: ������ ���������� �� ���������� "���� ����" C, �� ���������� ��������)

		; ���� ��� ������������ ������� ������ ����, �� ������ ���������:
		BRCC	EndNormalization__DEC_TIME_HELPER
		; (����������: ����� ����� - ��� ��������� ������������ ������ �������� ������������)

		; ����������� �������� ���� �� �������� ��� ����������� TEMP2	(����������: ������ �������� ������� ��������� "bin2bcd8" � AVR204)
Normalization__DEC_TIME_HELPER:
		ADD	temp1,	temp2				; ��������� �������� ��������������� ���� �� "��� �������"
		INC	ExtendTimeByValue			; � ����������� ��� � -1 ������� ������
		BRCS	EndNormalization__DEC_TIME_HELPER	; ���� �������� ������ 0xFF (C=1), �� ������...
		RJMP	Normalization__DEC_TIME_HELPER		; loop again
EndNormalization__DEC_TIME_HELPER:

		ST	X+,	temp1				; ��������� �������� �������� ������/�����/����� � ������. � ���������� ����� ������� ������ ExtendTimeInAddress �� +1 ����.
		BRTC	Exit__DEC_TIME_HELPER			; ���� T==0	-> ��������� �������/��� �� �������� ������� (�� ���������, ��� ������������ ������ ���������)
		CLR	ExtendTimeByValue			; ���� T==1	-> ��������� �������/��� �� �������� ������� (������������ � �������� "������ ���������" �������� �������)

Exit__DEC_TIME_HELPER:
		RET						; ����� �� ��������������� ���������



;----- "��������� �������" ����� ����� � ��������� "�������������� �������� �������� ������� � ������" (��� ������������� �������):

IndexTable__CALL_MOD_TIME:
		.DW	INC_TIME_SECONDS	; ��������� ��������� ������
		.DW	INC_TIME_MINUTES	; ��������� ��������� �����
		.DW	INC_TIME_HOURS		; ��������� ��������� �����
		.DW	DEC_TIME_SECONDS	; ������ ��������� ������
		.DW	DEC_TIME_MINUTES	; ������ ��������� �����
		.DW	DEC_TIME_HOURS		; ������ ��������� �����



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;
; ��������� ������������ ������� ���������� ("������� �� �������")
; 
; 	SWITCH_MODES
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

; ��� ����������.

; �������: ����� ����������/������ ���������� ��������� TEMP1, TEMP2, 
; 	Y(R29:R28),			(������������� � SWITCH_TIMER_MODES, SWITCH_MODE_SETTINGS)
; 	R25, X(R27:R26), Z(R31:R30).	(������������� � "�������������� �������� �������� ������� � ������")

;----- Code


; ����������: ����� ����� ���� ��������� ��� �� ������������� ������, ��� � DISPLAY_PREPARE: ������ ������� �������������, � ����������� �� �������� "������ ����������", �� ������������ ���������������� �����������.
; � ������� ��������� ����������� �� ��� ��������� ����������, � � ������ �� ��� - ������� ������ ����� ��������� ��������� �� ������� ��������� � ������... ��� ������������� ������, �� ��������� ���������� (���� �����). 
; � � ������ ���������� ������ ������ ���������, �������� ����������� � ������������������� ���� � ������ ���������� (�������� ����������: "������ � ������ ���������", "������������ �������" � �.�.) - ����� �������, �����, ������������ ������������ ������ ����������� (���������, ������������)...


SWITCH_MODES:

		;** ����������: "����� �� ������� ������"
		STOREB	DSleep,	SLEEPMODE_ON					; ���� "����������� ����� �������� �������������� (������ �����)":	=0, ���������� �����	=1, ����������� "������ �����"
		BRTC	WakefulMode__SWITCH_MODES				; ���� �� ����, �� ������������ ��� ������� �� ����������������� ����������...
		; (���������: ��� ����� � ������ �����)
		STOREB	DSleep,	WAKEUP_BUTTONS_HAVE_PREPARED			; ���� "������� ���� ������ ��������, ����� ���������� �� ����� ��������� ������"
		BRTS	WhileSleeping__SWITCH_MODES
		; (���������: ������, �� ��� �� ������� ������)
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (�������� ������� ���� ������, ����� ������������� ���������� �� ������ ���������� �������
		SETB	DSleep,	WAKEUP_BUTTONS_HAVE_PREPARED			; � ������� ��������������� ����)
	JustExit__SWITCH_MODES:
		RJMP	Exit__SWITCH_MODES					; ������ �� ������, ������� �� ��������� ��������...
	WhileSleeping__SWITCH_MODES:
		; (���������: ��� ���� � ������� ������� ������ - ������ ����������� ����� �� ����, �� ���������� ������� ��������)
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortHold	; (�����: ����������� ��� ������, �� ������� �� ������� ����� �����������)
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortHold	; (������: ������� ���������� ��� BSC_ShortHold - "���������� ������ �������������")
		OR_BUTTON_HAVE_STATUS	DButtonRTCStatus,	BSC_ShortHold
		OR_BUTTON_HAVE_STATUS	DButtonTimer1Status,	BSC_ShortHold
		OR_BUTTON_HAVE_STATUS	DButtonTimer2Status,	BSC_ShortHold
		BRTC	JustExit__SWITCH_MODES					; ���� ������ �� ���� ������...
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.	
										; 	(����������: �����, ����� �� ���������� � ���������� �������� - �������� �� ����� ����� �� ����!)
										; 	(����� �������, ��������� �������� ������� �� ������, ������� ������������� "�������")
		RJMP	EventButtonHavePressed__SWITCH_MODES			; ��������� "����"...	(����� ����� ����������� - ������ ������� �� �� ������������)
	WakefulMode__SWITCH_MODES:



		;** ����������: "������ � ������ ���������"
	;SettingsMode__SWITCH_MODES:
		STOREB	DMain_Mode,	MODE_SETTINGS				; ���� "��������� � ������ ���������" - ��� ���� ������� (�����, ����������, ��������):	=0, ���������� �����	=1, ����� � ����� ����������
		BRTC	NormalMode__SWITCH_MODES
		RCALL	SWITCH_MODE_SETTINGS
		BRTC	EndSettingsMode__SWITCH_MODES				; ���� ������ �� ���� ������...
		RJMP	EventButtonHavePressed__SWITCH_MODES
	EndSettingsMode__SWITCH_MODES:
		RJMP	Exit__SWITCH_MODES					; ���� �� �� �� ��������� � "������ ���������", �� ��������� ���� ������ ������� - ���������� �����������, ���� �� ������ �� "������ ���������"...
	NormalMode__SWITCH_MODES:



		;** ����������: "������������ �������"
	;SwitchFunc_RTC_Alarm__SWITCH_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonRTCStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonRTCStatus,	BSC_LongHold
		BRTC	SwitchFunc_Timer1__SWITCH_MODES				; ���� ������ �� ���� ������...
		;OUTI	DButtonRTCStatus,	0b00000000			; ����� ��������� ��������� ������ - ������� "����������� �����" � ���������� ��������.	(����������: ����� ������������ ������� "����� � ����" - ���������� ����, ������-������� ������ ����� ������ ����������, ���� ���� ������ ��� ������������ � BSC_LongHold.	���������: ����� ����������� "������� �������-���������", ������������ ������������ ��������� ������, ����� ��������� �������� - ����, ������, ��� �������: ��� ������������� ����� ��������� ��������� ������������ ������!) 
										; 	�����, �����, � ��������� ���� ������ ���������: ����� ������������ ������ ���������� ����� ������ DButtonRTCStatus, ����� ������� ������������� ������������ ������������� RTC<->Alarm, ������ CShortButtonTouchDuration ���������� - ����������� �������: "����������� �����"...	������������� "user experience": ���, �������� � ������! ����� � ��������� ����� ������, �� ������� ���������� ������������� F1->F2->F1->... ������, ����� � ������� � ������ ��� �������, ������ F2, �� � �������� ������������ ������ - ������, ��� �� ����������� ������� "BSC_ShortPress", � ������� ������ ��� ������������� � F1 (��������, ����� ������� ���������-�����)! 
										; 	� �����, ����� ��-���� ����������, �����, �� �������� ""����������� �����", � ������ �������������-����������� "����������� ������".
		OUTI	DButtonRTCStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.		(����������: ��� ������ ������� ���������, "� ��������� ��������-���������": ���������� ������������ ��������� ������, ����� ��������� �������� - ��� ������ �������, ��� ������������� ����� ��������� ��������� ������������ ������...)

		IF_CURRENT_FUNCTION	FunctionRTC
		BREQ	SwitchRTCtoAlarm__SWITCH_MODES
	;SwitchAlarmToRTC__SWITCH_MODES:
		SWITCH_CURRENT_FUNCTION		FunctionRTC
		RJMP	EventButtonHavePressed__SWITCH_MODES
	SwitchRTCtoAlarm__SWITCH_MODES:
		SWITCH_CURRENT_FUNCTION		FunctionALARM		
		RJMP	EventButtonHavePressed__SWITCH_MODES


	SwitchFunc_Timer1__SWITCH_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonTimer1Status,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonTimer1Status,	BSC_LongHold
		BRTC	SwitchFunc_Timer2__SWITCH_MODES				; ���� ������ �� ���� ������...
		OUTI	DButtonTimer1Status,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.

		IF_CURRENT_FUNCTION	FunctionTIMER1
		BREQ	SwitchTimer1Direction__SWITCH_MODES
		SWITCH_CURRENT_FUNCTION		FunctionTIMER1			; ������������� �� ������� ������1 � �����-�� ������ �������.
		RJMP	EventButtonHavePressed__SWITCH_MODES
	SwitchTimer1Direction__SWITCH_MODES:
		; ���������: ���������� �� ������?
		STOREB	DTimer1_Mode,	MODE_ENABLED				; ���� "����� ����������":	=0 ����������,		=1 �����
		BRTC	SwitchTimer1DirectionEnabled__SWITCH_MODES
		RJMP	Exit__SWITCH_MODES					; ���� ������ ������ �� ����������, �� ������������ ����������� ���������!
	SwitchTimer1DirectionEnabled__SWITCH_MODES:
		; (���������: ���� ������ ������ ����������)
		INVB	DTimer1_Mode,	MODE_UPDOWN				; ���� "����� �����������":	=0 ������ ����,		=1 �������� ����
		RJMP	EventButtonHavePressed__SWITCH_MODES


	SwitchFunc_Timer2__SWITCH_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonTimer2Status,	BSC_ShortPress		
		OR_BUTTON_HAVE_STATUS	DButtonTimer2Status,	BSC_LongHold		
		BRTC	SwitchFunc_End__SWITCH_MODES				; ���� ������ �� ���� ������...
		OUTI	DButtonTimer2Status,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.

		IF_CURRENT_FUNCTION	FunctionTIMER2
		BREQ	SwitchTimer2Direction__SWITCH_MODES
		SWITCH_CURRENT_FUNCTION		FunctionTIMER2			; ������������� �� ������� ������1 � �����-�� ������ �������.
		RJMP	EventButtonHavePressed__SWITCH_MODES
	SwitchTimer2Direction__SWITCH_MODES:
		; ���������: ���������� �� ������?
		STOREB	DTimer2_Mode,	MODE_ENABLED				; ���� "����� ����������":	=0 ����������,		=1 �����
		BRTC	SwitchTimer2DirectionEnabled__SWITCH_MODES
		RJMP	Exit__SWITCH_MODES					; ���� ������ ������ �� ����������, �� ������������ ����������� ���������!
	SwitchTimer2DirectionEnabled__SWITCH_MODES:
		; (���������: ���� ������ ������ ����������)
		INVB	DTimer2_Mode,	MODE_UPDOWN				; ���� "����� �����������":	=0 ������ ����,		=1 �������� ����
		RJMP	EventButtonHavePressed__SWITCH_MODES

	SwitchFunc_End__SWITCH_MODES:




		;** ���������� �������� "RTC":
	;ControlRTC__SWITCH_MODES:
		IF_CURRENT_FUNCTION	FunctionRTC
		BRNE	EndControlRTC__SWITCH_MODES

		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		AND_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	ControlRTC2__SWITCH_MODES				; ���� ������ �� ���� ������...
		OUTI	DButtonSetStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.
		OUTI	DButtonStartStatus,	0b11111111
		SETB	DMain_Mode,	MODE_SETTINGS				; ���������� �������: ����� � "����� ���������",
		OUTI	DSettings_Mode,	1<<SETTING_HOURS			; 	������� � ��������� "�������� �����",
		CLRB	DClock_Mode,	MODE_ENABLED				; 	������������� ��� �����,
		OUTI	DClock_Seconds,	0					; 	� �������� ������� ������.
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (�������� ������� ���� ������, ��� �������� � ������ ���������� ����������)
		RJMP	EventMuteAlarm__SWITCH_MODES

	ControlRTC2__SWITCH_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		BRTC	EndControlRTC__SWITCH_MODES				; ���� ������ �� ���� ������...
		OUTI	DButtonStartStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.
		OUTI	DButtonSetStatus,	0b11111111
		RJMP	EventMuteAlarm__SWITCH_MODES				; ���������� ������� ����� ���! �����: ������� "������" ������� �������.

	EndControlRTC__SWITCH_MODES:
		
		
		;** ���������� �������� "ALARM":
	ControlAlarm__SWITCH_MODES:
		IF_CURRENT_FUNCTION	FunctionALARM
		BREQ	ControlAlarm1__SWITCH_MODES
		RJMP	EndControlAlarm__SWITCH_MODES
	ControlAlarm1__SWITCH_MODES:

		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		OR_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	ControlAlarm2__SWITCH_MODES				; ���� ������ �� ���� ������...
		OUTI	DButtonSetStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.
		OUTI	DButtonStartStatus,	0b11111111
		SETB	DMain_Mode,	MODE_SETTINGS				; ���������� �������: ����� � "����� ���������",
		OUTI	DSettings_Mode,	1<<SETTING_HOURS			; 	������� � ��������� "�������� �����".
		;OUTI	DAlarm_Seconds,	0					; 	� �������� ������� ������.	(�����, �� ������������)
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (�������� ������� ���� ������, ��� �������� � ������ ���������� ����������)
		RJMP	EventMuteAlarm__SWITCH_MODES
		
	ControlAlarm2__SWITCH_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		BRTC	EndControlAlarm__SWITCH_MODES				; ���� ������ �� ���� ������...
		OUTI	DButtonStartStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.
		OUTI	DButtonSetStatus,	0b11111111
		STOREB	DAlarm_Mode,	MODE_BELLRINGING			; ���� "����� ���������� ������" -> T
		BRTS	EventMuteAlarm__SWITCH_MODES				; ���� ����� ������, �� ������ ���������� ������� ��� - ������ ��������� "������"...
		INVB	DAlarm_Mode,	MODE_ENABLED				; ���������� �������: ����������� ����� ���������� = ���./����.
		RJMP	EventMuteAlarm__SWITCH_MODES

	EndControlAlarm__SWITCH_MODES:


		;** ���������� �������� "TIMER1":
	ControlTimer1__SWITCH_MODES:
		IF_CURRENT_FUNCTION	FunctionTIMER1
		BRNE	EndControlTimer1__SWITCH_MODES

		LDI	TimerModeAddressLow,	Low(DTimer1_Mode)		; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	TimerModeAddressHigh,	High(DTimer1_Mode)		;
		RCALL	SWITCH_TIMER_MODES
		BRTC	EndControlTimer1__SWITCH_MODES				; ���� ������ �� ���� ������...
		RJMP	EventMuteAlarm__SWITCH_MODES

	EndControlTimer1__SWITCH_MODES:


		;** ���������� �������� "TIMER2":
	ControlTimer2__SWITCH_MODES:
		IF_CURRENT_FUNCTION	FunctionTIMER2
		BRNE	EndControlTimer2__SWITCH_MODES

		LDI	TimerModeAddressLow,	Low(DTimer2_Mode)		; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	TimerModeAddressHigh,	High(DTimer2_Mode)		;
		RCALL	SWITCH_TIMER_MODES
		BRTC	EndControlTimer2__SWITCH_MODES				; ���� ������ �� ���� ������...
		RJMP	EventMuteAlarm__SWITCH_MODES

	EndControlTimer2__SWITCH_MODES:




		;** (��������� ������� ������ ���������)
		RJMP	Exit__SWITCH_MODES
EventMuteAlarm__SWITCH_MODES:
		; �������� ��� �����, ��� ������� ��������� ��������� ����������
		CLRB	DAlarm_Mode,	MODE_BELLRINGING
		CLRB	DTimer1_Mode,	MODE_BELLRINGING
		CLRB	DTimer2_Mode,	MODE_BELLRINGING
EventButtonHavePressed__SWITCH_MODES:
		; "�����������" �� ������� ����� ������
		RCALL	SLEEPER_RESET
Exit__SWITCH_MODES:
		; ���� ������� ������ �� ���� �������������, �� ������ �����
		RET



;---------------------------------------------------------------------------
;
; ��������������� ��������� ������������ ������� ����������:
; 
; 	SWITCH_TIMER_MODES
; (����������: ������ "�������/�����������")
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

;.def	TimerModeAddressLow	= R28	; YL
;.def	TimerModeAddressHigh	= R29	; YH

; �����, �������� ���������� �������� status bit "T": 
; 	T=0	������� �� ������ �� �������������...
; 	T=1	���� ������������� ������� ������!

; �������: ����� ����������/������ ���������� ���������: TEMP1, TEMP2.

;----- Code


SWITCH_TIMER_MODES:

		; ���������� "�����/����" (��������� � � �������, � � �����������).
	;StartStop__SWITCH_TIMER_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongPress
		BRTC	EndStartStop__SWITCH_TIMER_MODES			; ���� ������ �� ���� ������...
		OUTI	DButtonStartStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.
		
		; �������� �������������� �������: ��������� �� ����������� ����� ����?
		; (��������, ��������� �������� ������������� ������ ��������� �����, ���� �� ��� �������� �� ����!)
		LD	temp1,	Y						; ��������� ���� "�����" �� ������: DTimerX_Mode = (DTimerX+0)
		BST	temp1,	MODE_ENABLED					; ���� "����� ����������" -> T:		=0 ����������,	=1 �����
		BRTS	AllowStartStop__SWITCH_TIMER_MODES
		BST	temp,	MODE_UPDOWN					; ���� "����� �����������" -> T:	=0 ������ ����,	=1 �������� ����
		BRTC	AllowStartStop__SWITCH_TIMER_MODES
		LDD	temp1,	Y+1						; ��������� ���� "�������"
		LDD	temp2,	Y+2						; ��������� ���� "������"
		OR	temp1,	temp2
		LDD	temp2,	Y+3						; ��������� ���� "����"
		OR	temp1,	temp2
		BRNE	AllowStartStop__SWITCH_TIMER_MODES			; ���� "������� �������" <> 0?	�� ���������...
		SET								; T=1 (�������� �������� ���������)
		RJMP	Exit__SWITCH_TIMER_MODES				; ��������� ������������...

	AllowStartStop__SWITCH_TIMER_MODES:
		;INVB	DTimerX_Mode,	MODE_ENABLED				; ���������� �������: ����������� ����� ���� = "�����/����":
		LD	temp1,	Y						; 	��������� ���� "�����" �� ������: DTimerX_Mode = (DTimerX+0),
		LDI	temp2,	1<<MODE_ENABLED					; 	����� ���,
		EOR	temp1,	temp2						; 	�������������,
		ST	Y,	temp1						; 	���������.
		
		SET								; T=1 (�������� �������� ���������)
		RJMP	Exit__SWITCH_TIMER_MODES
	EndStartStop__SWITCH_TIMER_MODES:
		
		
		
		; (����������: ��������� ������� - ������ ��� ������������� ����!)
		LD	temp,	Y						; ��������� ���� "�����" �� ������: DTimerX_Mode = (DTimerX+0)
		BST	temp,	MODE_ENABLED					; ���� "����� ����������" -> T:		=0 ����������,	=1 �����
		BRTC	TimerIsStopped__SWITCH_TIMER_MODES
		RJMP	NoEvent__SWITCH_TIMER_MODES
		
		
		; (���������: ������, ��� ����������)
	TimerIsStopped__SWITCH_TIMER_MODES:
		BST	temp,	MODE_UPDOWN					; ���� "����� �����������" -> T:	=0 ������ ����,	=1 �������� ����
		BRTS	DownTimer__SWITCH_TIMER_MODES
		
	;UpTimer__SWITCH_TIMER_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		OR_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	NoEvent__SWITCH_TIMER_MODES				; ���� ������ �� ���� ������...
		OUTI	DButtonSetStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.
		OUTI	DButtonStartStatus,	0b11111111
		CLR	temp							; ���������� �������: �������� "������� �������" � ����:
		STD	Y+1,	temp						; 	��������� ���� � �����: DTimerX_Seconds = (DTimerX+1)
		STD	Y+2,	temp						; 	��������� ���� � �����: DTimerX_Minutes = (DTimerX+2)
		STD	Y+3,	temp						; 	��������� ���� � �����: DTimerX_Hours = (DTimerX+3)
		SET								; T=1 (�������� �������� ���������)
		RJMP	Exit__SWITCH_TIMER_MODES
		
	DownTimer__SWITCH_TIMER_MODES:
		
		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		OR_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	NoEvent__SWITCH_TIMER_MODES				; ���� ������ �� ���� ������...
		OUTI	DButtonSetStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.
		OUTI	DButtonStartStatus,	0b11111111
		SETB	DMain_Mode,	MODE_SETTINGS				; ���������� �������: ����� � "����� ���������",
		OUTI	DSettings_Mode,	1<<SETTING_MINUTES			; 	������� � ��������� "�������� �����".
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (�������� ������� ���� ������, ��� �������� � ������ ���������� ����������)
		SET								; T=1 (�������� �������� ���������)
		RJMP	Exit__SWITCH_TIMER_MODES
		
		
		
	NoEvent__SWITCH_TIMER_MODES:
		CLT								; T=0 (�������� �������� ���������)
	Exit__SWITCH_TIMER_MODES:
		RET



;---------------------------------------------------------------------------
;
; ��������������� ��������� ������������ ������� ����������:
; 
; 	SWITCH_MODE_SETTINGS
; (����������: ������ � "������ ���������")
;
;
; ������� �������, ��������� ������� ������������� - ������������ �� �������� ���������� ���������� DMain_Mode...
; ������� ��������, ������� ������������� - ������������ �� �������� ���������� ���������� DSettings_Mode...
; 
; ������������ � ���������� "�������������� ���������" ����������� "data-driven" ���������� - ����� MODE_INPUTSECONDS, � ����� "�����", ��������������� �������:
; 	���� "����������� �������� �������":
; 	=0, ����������� ��� ����������: ������ ���� � ������, � ������� ������ ����������	(��� ����� � ����������)
; 	=1, ����������� ��� ����������: ����, ������, �������					(��� ��������)
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

; ��� ����������.

; �����, �������� ���������� �������� status bit "T": 
; 	T=0	������� �� ������ �� �������������...
; 	T=1	���� ������������� ������� ������!

; �������: ����� ����������/������ ���������� ��������� TEMP1, TEMP2, Y(R29:R28),
; 	R25, X(R27:R26), Z(R31:R30).	(������������� � "�������������� �������� �������� ������� � ������")

;----- Code


SWITCH_MODE_SETTINGS:

		; ���������� ������� �������, ��������� ������� �������������:
		; ���������� ����� "�������� �������", ������� �������������:
	;IfRTC__SWITCH_MODE_SETTINGS:
		IF_CURRENT_FUNCTION	FunctionRTC
		BRNE	IfAlarm__SWITCH_MODE_SETTINGS
		LDI	YL,	Low(DClock_Mode)				; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	YH,	High(DClock_Mode)				;
		RJMP	EndIf__SWITCH_MODE_SETTINGS
	
	IfAlarm__SWITCH_MODE_SETTINGS:
		IF_CURRENT_FUNCTION	FunctionALARM
		BRNE	IfTimer1__SWITCH_MODE_SETTINGS
		LDI	YL,	Low(DAlarm_Mode)				; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	YH,	High(DAlarm_Mode)				;
		RJMP	EndIf__SWITCH_MODE_SETTINGS
		
	IfTimer1__SWITCH_MODE_SETTINGS:
		IF_CURRENT_FUNCTION	FunctionTIMER1
		BRNE	IfTimer2__SWITCH_MODE_SETTINGS
		LDI	YL,	Low(DTimer1_Mode)				; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	YH,	High(DTimer1_Mode)				;
		RJMP	EndIf__SWITCH_MODE_SETTINGS

	IfTimer2__SWITCH_MODE_SETTINGS:
		IF_CURRENT_FUNCTION	FunctionTIMER2
		BRNE	ElseIf__SWITCH_MODE_SETTINGS
		LDI	YL,	Low(DTimer2_Mode)				; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	YH,	High(DTimer2_Mode)				;
		RJMP	EndIf__SWITCH_MODE_SETTINGS

	ElseIf__SWITCH_MODE_SETTINGS:
		RJMP	NoEvent__SWITCH_MODE_SETTINGS				; ���������� �������, ��� ������� �� ������������ "����� ���������" (������ � �������� DMain_Mode?). ��� �� �����...
	EndIf__SWITCH_MODE_SETTINGS:



		;** ������������ � ���������� "�������������� ���������"
		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		BRTC	EndNextParameter__SWITCH_MODE_SETTINGS			; ���� ������ �� ���� ������...
		OUTI	DButtonSetStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.

		LD	temp1,	Y						; ��������� ���� "�����", ��������������� ������������ ������� �������
		BST	temp1,	MODE_INPUTSECONDS				; ���� "����������� �������� �������" -> T
		LDS	temp1,	DSettings_Mode					; ��������� ����, ��������������� ������� �������� ������ "���������"
		LSL	temp1							; ���������� �������: ����������� ������������� ��������: ���� -> ������ -> ������� -> C
										; 	������, ������: ���� "��������� � ������ ��������� �������� ������" -> N
		; ���������: ������� ������, ���� ����
		BRTS	SecondsParameterHaveFixed__SWITCH_MODE_SETTINGS		; ����, ��� ���� �������, ��������� ����������� ��� ��� ���������� (T==1), �� ���������� ���������...
		BRPL	SecondsParameterHaveFixed__SWITCH_MODE_SETTINGS		; ���� ������� ��������, �� ������� ������������� - ��� ��� �� ������� (N==0), �� ���������� ���������...
		LSL	temp1							; ���������: ��� ��� ����������� ������� ��������, ����� ����������: ������� -> C
	SecondsParameterHaveFixed__SWITCH_MODE_SETTINGS:
		; ��������� �����: C -> ����
		BRCC	NoCarryYet__SWITCH_MODE_SETTINGS
		ORI	temp1,	1<<SETTING_HOURS
	NoCarryYet__SWITCH_MODE_SETTINGS:
		STS	DSettings_Mode,	temp1					; ��������� ���������������� ����, ��������������� ������� �������� ������ "���������"
		
		SET								; T=1 (�������� �������� ���������)
		RJMP	Exit__SWITCH_MODE_SETTINGS
	EndNextParameter__SWITCH_MODE_SETTINGS:



		;** ����� �� "������ ���������"
		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortHold
		AND_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortHold
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		BRTC	EndSettingsMode__SWITCH_MODE_SETTINGS			; ���� ������ �� ���� ������...
		OUTI	DButtonSetStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.
		OUTI	DButtonStartStatus,	0b11111111
		CLRB	DMain_Mode,	MODE_SETTINGS				; ���������� �������: ����� �� "������ ���������".
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (�������� ������� ���� ������, ��� �������� � ������ ���������� ����������)
		
		; ��� ������� "RTC": ����� ��������� ��� ����� (������� ��� �������������, ��� �������������, ��� ����� � "����� ���������")
		IF_CURRENT_FUNCTION	FunctionRTC
		BRNE	EndControlRTC__SWITCH_MODE_SETTINGS
		SETB	DClock_Mode,	MODE_ENABLED				; ���������� �������: ��������� ��� �����.
	EndControlRTC__SWITCH_MODE_SETTINGS:

		; ��� ������� "ALARM": ��������� ��������� ���������� � EEPROM (DAlarm -> EAlarm)
		IF_CURRENT_FUNCTION	FunctionALARM
		BRNE	EndControlAlarm__SWITCH_MODE_SETTINGS
		LDI	EepromAddressLow,	Low(EAlarm_SavedSettings)		; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	EepromAddressHigh,	High(EAlarm_SavedSettings)		; 
		LDI	SramAddressLow,		Low(DAlarm_Mode)			; (����������: ����� ��������� � ������� �����, � �� ��������)
		LDI	SramAddressHigh,	High(DAlarm_Mode)			; 
		LDI	PumpBytesCount,		EAlarm_size				; ���������� ������ (� ������)
		CLI									; ��������� ����������	(!�� ����������� ������ ����������� ����������!)
		RCALL	EEPROM_WRITE_SEQUENCE
		SEI 									; ��������� ����������	(!�� ����������� ������ ����������� ����������!)
	EndControlAlarm__SWITCH_MODE_SETTINGS:
		
		SET								; T=1 (�������� �������� ���������)
		RJMP	Exit__SWITCH_MODE_SETTINGS
	EndSettingsMode__SWITCH_MODE_SETTINGS:



		;** ����������� �������� �������� ���������

		; �������������: ���������� ������� ��������, ������� �������������?
		MOVW	ExtendTimeInAddressHigh:ExtendTimeInAddressLow,	YH:YL	; (���������� �������� ���������: ����� ������, ������� ��������������)
		LDI	ZL,	Low (IndexTable__CALL_MOD_TIME)			; (���������� ����� ����� � ���������: ���� ������ �� ������ �������� ��������� ������� INC_TIME_* - ����� ����� ���������, ���� �����)
		LDI	ZH,	High(IndexTable__CALL_MOD_TIME)

		LDS	temp1,	DSettings_Mode					; ��������� ����, ��������������� ������� �������� ������ "���������"
		LD	temp2,	X+						; ���������: ����������� �������� ��������� +1
		LSL	temp1
		BRCS	EndSelectParameter__SWITCH_MODE_SETTINGS		; ���� �������...
		LD	temp2,	X+						; ���������: ����������� �������� ��������� +1
		LD	temp2,	Z+						; ���������: ����������� �������� ��������� +1
		LSL	temp1
		BRCS	EndSelectParameter__SWITCH_MODE_SETTINGS		; ���� ������...
		LD	temp2,	X+						; ���������: ����������� �������� ��������� +1
		LD	temp2,	Z+						; ���������: ����������� �������� ��������� +1
		LSL	temp1
		;BRCS	EndSelectParameter__SWITCH_MODE_SETTINGS		; ���� ����...
	EndSelectParameter__SWITCH_MODE_SETTINGS:



		; ��������� ������� �����: ������������ �� ������� ������ ������������?

		; ��������� ����� ���������
		LDS	ExtendTimeByValue,	DEncoder0Counter
		TST	ExtendTimeByValue
		BREQ	NotEncoder__SWITCH_MODE_SETTINGS
		OUTI	DEncoder0Counter,	0				; ������: ����� ����������� � "�������� �������" ���� ���������� �������, ������� "�������� �����" �������� ����������.
		RJMP	ModifyTime__SWITCH_MODE_SETTINGS
	NotEncoder__SWITCH_MODE_SETTINGS:


		; ��������� ����� �������
		; (����������� �������)
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortPress
		BRTC	Button2__SWITCH_MODE_SETTINGS				; ���� ������ �� ���� ������...
		OUTI	DButtonStartStatus,	0b11111111			; ����� ��������� ��������� ������ - ������� "���������� �����" � ���������� ��������.
		LDI	ExtendTimeByValue,	1
		RJMP	ModifyTime__SWITCH_MODE_SETTINGS
		; (����������� ����, ��� ���������)
	Button2__SWITCH_MODE_SETTINGS:
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	NotButton__SWITCH_MODE_SETTINGS				; ���� ������ �� ���� ������...
		;OUTI	DButtonStartStatus,	0b11111111			; ��������: � ���� ������, ������ ������ �� ���������� - ����� ���������� ��������� "�������" � �������� "������ ���������"...
		LDI	ExtendTimeByValue,	1
		; (���� ��������� ����� �������� "����� ����������" ����������� ������)
		LDS	temp1,	DButtonStartStatus
		ANDI	temp1,	0b11111<<BUTTON_HOLDING_TIME			; �������� "������� ������� ��������� ������"
		CPI	temp1,	8						; ��� ��������� ������ ����� >=4���, ��������� �������� � 2 ���� ������.
		BRLO	SlowSpeedYet__SWITCH_MODE_SETTINGS
		LSL	ExtendTimeByValue
		CPI	temp1,	16						; ��� ��������� ������ ����� >=8���, ��������� �������� ��� � 2 ���� ������.
		BRLO	SlowSpeedYet__SWITCH_MODE_SETTINGS
		LSL	ExtendTimeByValue
	SlowSpeedYet__SWITCH_MODE_SETTINGS:
		RJMP	ModifyTime__SWITCH_MODE_SETTINGS
	NotButton__SWITCH_MODE_SETTINGS:
		RJMP	NoEvent__SWITCH_MODE_SETTINGS



		; �����������: ������� ��������� � �������� ��������� ����������� "�������� �������"
	ModifyTime__SWITCH_MODE_SETTINGS:
		; ���������: ������������ ��� (+/-) ������������?
		TST	ExtendTimeByValue
		BRPL	SkipCorrectionWhenIncrementation__SWITCH_MODE_SETTINGS
		NEG	ExtendTimeByValue					; ��������� �������� ����������� (�������� ���������� ��������)
		LDI	temp1,	3						; ����������� �������� ��������� �� ����� ����� �� +3 �����	(��� �������� �� ������ �������� ��������� �������)
		CLR	temp2
		ADD	ZL,	temp1						; Z += temp1
		ADC	ZH,	temp2
	SkipCorrectionWhenIncrementation__SWITCH_MODE_SETTINGS:
		; ����������: ����� ��������� ���������� �� "��������� ���������" - ��. ���������� � "AVR. ������� ����. ��������� �� ��������� ���������" (�) http://easyelectronics.ru/avr-uchebnyj-kurs-vetvleniya.html
		LSL	ZL							; (����������: ������ ����� �� CSEG �������� � ������, ������� �� ����� ��������� � 2 ����, ����� ����� ���� ������������ � ����������� LPM/SPM...)
		ROL	ZH
		LPM	temp1,	Z+						; ��������� ����� �������� �� ��������� ������� -> [temp2:temp1]
		LPM	temp2,	Z
		MOVW	ZH:ZL,	temp2:temp1					; ��������� ����� �������� �� ���������� ������� -> � Z 	(����������: ��������� ��� ��������� IJMP/ICALL ������������ ����� ���������� � ������ - �� ��� �������������� �� ����������� � 2 ����, ��������� ����� ��� ��� �������� �� �������...)
		SET								; T=1 (��������: ��������� �������/��� �� �������� �������)
		ICALL								; ������� �� �������� "��������� ��������" �����

		SET								; T=1 (�������� �������� ���������)
		RJMP	Exit__SWITCH_MODE_SETTINGS



	NoEvent__SWITCH_MODE_SETTINGS:
		CLT								; T=0 (�������� �������� ���������)
	Exit__SWITCH_MODE_SETTINGS:
		RET




;***** END Procedures section 
; coded by (c) Celeron, 2013 @ http://we.easyelectronics.ru/my/Celeron/
