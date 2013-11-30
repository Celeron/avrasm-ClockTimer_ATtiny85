.IFNDEF	_MACROAPP__INCLUDED_
.EQU	_MACROAPP__INCLUDED_ = 1
.MESSAGE "Note: <macroapp.inc> have included!" 
;=== BEGIN "macroapp.inc" ==================================================
; Прикладные Макроопределения, используемые при реализации логики приложения.


; (Примечание: эти макросы - "ПриложениеЗависимы"!)


;***************************************************************************
;*
;*  Реализация Прикладной логики
;*
;***************************************************************************


; Установить status bit "Z" = в значение булевого выражения: (Если текущий режим интерфейса переключен на функцию == @0 ?)
; Пример вызова:  IF_CURRENT_FUNCTION  FunctionRTC
; Памятка: портит содержимое регистра TEMP.
	.MACRO	IF_CURRENT_FUNCTION
		LDS	temp,	DMain_Mode				; Загружаем из памяти DMain_Mode -> temp
		ANDI	temp,	(0b111<<MODE_CURRENT_FUNCTION)		; 1) обнуляем всё, кроме текущего режима интерфейса
		CPI	temp,	(@0<<MODE_CURRENT_FUNCTION)		; 2) сравниваем с паттерном кода режима интерфейса
		; (состояние: если коды были равны, то сейчас Z==1)
	.ENDMACRO


; Переключить текущий режим интерфейса на функцию @0.
; Пример вызова:  SWITCH_CURRENT_FUNCTION  FunctionRTC
; Памятка: портит содержимое регистров TEMP1, TEMP2.
	.MACRO	SWITCH_CURRENT_FUNCTION
		LDS	temp,	DMain_Mode				; Загружаем из памяти DMain_Mode -> temp
		ANDI	temp,	~(0b111<<MODE_CURRENT_FUNCTION)		; 1) обнуляем текущий режим интерфейса
		ORI	temp,	(@0<<MODE_CURRENT_FUNCTION)		; 2) устанавливаем требуемый код режима интерфейса
		STS	DMain_Mode,	temp				; Сохраняем в память DMain_Mode <- temp
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS		; (обнулить события всех Кнопок, при переходе в другую Подсистему интерфейса)
	.ENDMACRO



;***************************************************************************
;*
;*  Другие сервисные...
;*
;***************************************************************************


; Обнуление счётного регистра Timer/Counter0, и четырехбайтной переменной @0 в памяти (по адресу @0 - мл.байт, little-endian)
; Памятка: портит содержимое регистра TEMP.
	.MACRO	CLRTCNT0
		CLR	temp		; Тут нам нужен ноль...
		OUT	TCNT0,	temp	; Ноль в счетный регистр таймера
		STS	@0,	temp	; Ноль в первый байт счетчика в RAM
		STS	@0+1,	temp	; Ноль в второй байт счетчика в RAM
		STS	@0+2,	temp	; Ноль в третий байт счетчика в RAM
		STS	@0+3,	temp	; Ноль в четвёртый байт счетчика в RAM
	.ENDM


/*
; Заглушка отладочного кода: чтение команд из последовательного порта, и ответ запрошенной служебной информации (идея DI HALT)...
	.MACRO	DEB_CMD
		PUSH	R16		; Сохраняем регистр и флаги в стек
		IN	R16,SREG
		PUSH	R16

		SBIS	UCSRA,RXC
		RJMP	PC-1
		IN	R16,UDR		; Читаем UDR, чтобы сбросить RXC флаг

					; Определяем что там пришло
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

		POP	R16		;GONEXT - достаем все сохраненное из стека и идем дальше
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
; coded by (c) Celeron, 2013 @ http://we.easyelectronics.ru/my/Celeron/
.ENDIF
