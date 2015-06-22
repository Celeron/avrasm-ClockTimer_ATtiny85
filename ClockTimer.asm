
	.NOLIST				; Disable listfile generation.
	.include "tn85def.inc"		; Используем HAL Микроконтроллера.
	.include "macrobaselib.inc"	; Библиотека базовых Макроопределений.
	.include "macroapp.inc"		; Прикладные Макроопределения, используемые при реализации логики приложения.
	.LIST				; Reenable listfile generation.
	;.LISTMAC			; Turn macro expansion on?	(При отладке, отображать тела внедрённых Макросов в дизассемблированном коде - обычно, не следует включать, т.к. генерирует много мусора.)

	.include "data.inc"		; Данные программы: 
					;	Константы и псевдонимы Регистров; 
					;	Сегмент SRAM и Переменные; 
					;	Сегмент EEPROM.


;***************************************************************************
;*
;*  FLASH (сегмент кода)
;*
;***************************************************************************
			.CSEG

		.ORG	0x0000		; (RESET) 
		RJMP	RESET
		.include "ivectors.inc"	; Таблица векторов на обработчики прерываний


;***** BEGIN Interrupt handlers section ************************************

;---------------------------------------------------------------------------
;
; Прерывание: отсчёт полусекунд
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

; Памятка: обработчик не портит содержимое РОН - поскольку защищает используемые регистры Стеком...

;----- Code

TIMER0_OVERFLOW_HANDLER:
		; Сохранить в Стеке регистры, которые используются в данном обработчике:
		PUSHF		; сохраняет часто используемые регистры: SREG и TEMP (TEMP1)
		PUSH	temp2	; регистр используется в INVB и др.
		PUSH	temp3	; регистр используется в DISPLAY_REFRESH, DISPLAY_PREPARE, KEY_ENHANCE_TIME_FOR_ALL_BUTTONS
		PUSH	temp4	; регистр используется в DISPLAY_REFRESH, DISPLAY_PREPARE
		PUSH	R25	; регистр используется в INC_TIME_SECONDS, CODE2SYMBOL, DISPLAY_PRINT_TIMER_MODE
		PUSH	R26	; (XL)	регистр используется в INC_TIME_SECONDS, DISPLAY_PRINT_DIGITS
		PUSH	R27	; (XH)	регистр используется в INC_TIME_SECONDS, DISPLAY_PRINT_DIGITS
		PUSH	R28	; (YL)	регистр используется в HandleTimerX__SECOND_ELAPSED_HELPER, DISPLAY_REFRESH, DISPLAY_PRINT_DIGITS, KEY_ENHANCE_TIME_FOR_ALL_BUTTONS
		PUSH	R29	; (YH)	регистр используется в HandleTimerX__SECOND_ELAPSED_HELPER, DISPLAY_REFRESH, DISPLAY_PRINT_DIGITS, KEY_ENHANCE_TIME_FOR_ALL_BUTTONS
		PUSH	R30	; (ZL)	регистр используется в CODE2SYMBOL
		PUSH	R31	; (ZH)	регистр используется в CODE2SYMBOL


		STOREB	DMain_Mode,	MODE_SECONDSIGN			; Флаг "зажигания на индикаторе мигающей чёрточки" -> T
		BRTS	HalfSecond__TIMER0_OVERFLOW_HANDLER		; Если отсчитана только первая половина секунды? пропусти манипуляцию счётчиками...


		; Арифметика наращивания счётчиков и Контроль срабатывания "звонков":
		RCALL	SECOND_ELAPSED_HANDLER_RTC

		LDI	TimerModeAddressLow,	Low(DTimer1_Mode)	; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	TimerModeAddressHigh,	High(DTimer1_Mode)	;
		RCALL	SECOND_ELAPSED_HANDLER_TIMER

		LDI	TimerModeAddressLow,	Low(DTimer2_Mode)	; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	TimerModeAddressHigh,	High(DTimer2_Mode)	;
		RCALL	SECOND_ELAPSED_HANDLER_TIMER

		; Отработка рабочего цикла шарманки "Спящего режима" (запускать каждую секунду)
		RCALL	SLEEPER_SECOND_ELAPSED


HalfSecond__TIMER0_OVERFLOW_HANDLER:
		INVB	DMain_Mode,	MODE_SECONDSIGN			; Инвертировать "Секундную чёрточку"
		
		; Обновить дисплей (каждые полсекунды)
		RCALL	DISPLAY_PREPARE
		RCALL	DISPLAY_REFRESH

		; Головная процедура конвеера обработки кнопок:	Наращивает таймеры для удерживаемых кнопок (запускать каждые полсекунды)
		RCALL	KEY_ENHANCE_TIME_FOR_ALL_BUTTONS


		; Выход из обработчика
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

; Примечание: Часы и Будильник у нас одни - поэтому их данные не требуется параметризировать...

; Памятка: также использует/портит содержимое регистров: TEMP1, TEMP2,
;	X(R27:R26), R25 (опосредованно в INC_TIME_SECONDS).

;----- Code

SECOND_ELAPSED_HANDLER_RTC:

		; Наращиваем Часы:

		STOREB	DClock_Mode,	MODE_ENABLED			; Флаг "режим активности" -> T:	=1 бежит (обычно),	=0 приостановлен
		BRTC	EndRTC__SECOND_ELAPSED_HANDLER_RTC		; часы остановлены?
		LDI	ExtendTimeInAddressLow,	Low(DClock_Seconds)	; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	ExtendTimeInAddressHigh,High(DClock_Seconds)	;
		LDI	ExtendTimeByValue,	1			; величина приращения
		CLT							; T=0 (параметр процедуры)	разрешает перенос/заём из старшего разряда (по умолчанию, при естественной работе счётчиков)
		RCALL	INC_TIME_SECONDS				; +1сек
	EndRTC__SECOND_ELAPSED_HANDLER_RTC:


		; Проверить: не сработал ли Будильник? (если он активирован, и время пришло)

		STOREB	DAlarm_Mode,	MODE_ENABLED			; Флаг "режим активности" -> T:	=0 выключен,	=1 включён (будет звонить)
		BRTC	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; состояние: деактивирован?
		STOREB	DAlarm_Mode,	MODE_BELLRINGING		; Флаг "гудок звонит" -> T:	=0 молчит,	=1 пищит прямо сейчас (время пришло)!
		BRTS	RingingNowAlarm__SECOND_ELAPSED_HANDLER_RTC	; состояние: уже звонит?

		; (состояние: активен, но ещё не звонит)
		; Надо проверить: может настало время "включить звонок"?
		LDS	temp1,	DClock_Seconds
		TST	temp1
		BRNE	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; сейчас, не начало минуты: секунды!=0	(Примечание: будильник включается только на первой секунде заданного "Времени Будильника"! Данная проверка позволяет устанавливать "Продолжительность звонка будильника" меньше минуты.)
		LDS	temp1,	DAlarm_Minutes
		LDS	temp2,	DClock_Minutes
		CP	temp1,	temp2
		BRNE	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; минуты не совпадают
		LDS	temp1,	DAlarm_Hours
		LDS	temp2,	DClock_Hours
		CP	temp1,	temp2
		BRNE	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; часы не совпадают

		; Время пришло - включить звонок!
		SETB	DAlarm_Mode,		MODE_BELLRINGING	; состояние: включить звонок
		OUTI	DAlarm_RingTimeout,	CAlarmRingDuration	; взвести звонок на столько секунд
		RCALL	SLEEPER_RESET					; "просыпаемся" при alarm-е
		; И, если не нахожусь в "режиме подстройки" (MODE_SETTINGS==0), то показательно переключить текущий режим интерфейса, на функцию, которая бузит: MODE_CURRENT_FUNCTION = FunctionRTC.
		STOREB	DMain_Mode,	MODE_SETTINGS			; Загружаем:  DMain_Mode -> temp;  MODE_SETTINGS -> T
		BRTS	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; Если T==1 (значит, нахожусь в "режиме подстройки") - не переключаемся...
		SWITCH_CURRENT_FUNCTION		FunctionRTC
		RJMP	EndAlarm__SECOND_ELAPSED_HANDLER_RTC

	RingingNowAlarm__SECOND_ELAPSED_HANDLER_RTC:
		; Включен и уже звонит - надо проверить: может уже хватит звонить?
		DEC8M	DAlarm_RingTimeout
		BRNE	EndAlarm__SECOND_ELAPSED_HANDLER_RTC		; ещё не досчитал до нуля?
		CLRB	DAlarm_Mode,	MODE_BELLRINGING		; состояние: заглушим гудок

	EndAlarm__SECOND_ELAPSED_HANDLER_RTC:

		RET



;----- Subroutine Register Variables

.def	TimerModeAddressLow	= R28	; YL
.def	TimerModeAddressHigh	= R29	; YH

; Памятка: также использует/портит содержимое регистров: TEMP1, TEMP2,
;	X(R27:R26), R25 (опосредованно в INC_TIME_SECONDS).

;----- Code

SECOND_ELAPSED_HANDLER_TIMER:

		LD	temp,	Y					; загрузить байт "Режим" из адреса: DTimerX_Mode = (DTimerX+0)
		BST	temp,	MODE_ENABLED				; Флаг "режим активности" -> T:		=0 остановлен,	=1 бежит
		BRTC	StoppedTimer__SECOND_ELAPSED_HANDLER_TIMER	; состояние: таймерX остановлен?


		; Наращиваем Таймер:
		MOV	ExtendTimeInAddressLow,	TimerModeAddressLow	; здесь, загружаем в регистр: адрес DTimerX
		MOV	ExtendTimeInAddressHigh,TimerModeAddressHigh	;
		SUBI	ExtendTimeInAddressLow,	(-1)			; и инкрементируем, поскольку: адрес DTimerX_Seconds = (DTimerX+1)
		SBCI	ExtendTimeInAddressHigh,(-1)
		LDI	ExtendTimeByValue,	1			; величина приращения
		
		;LD	temp,	Y					; загрузить байт "Режим" из адреса: DTimerX_Mode = (DTimerX+0)
		BST	temp,	MODE_UPDOWN				; Флаг "режим направления" -> T:	=0 прямой счёт,	=1 обратный счёт
		BRTS	DownTimer__SECOND_ELAPSED_HANDLER_TIMER
		CLT							; T=0 (параметр процедуры)	разрешает перенос/заём из старшего разряда (по умолчанию, при естественной работе счётчиков)
		RCALL	INC_TIME_SECONDS				; +1сек
		RJMP	EndTimer__SECOND_ELAPSED_HANDLER_TIMER
	DownTimer__SECOND_ELAPSED_HANDLER_TIMER:
		CLT							; T=0 (параметр процедуры)	разрешает перенос/заём из старшего разряда (по умолчанию, при естественной работе счётчиков)
		RCALL	DEC_TIME_SECONDS				; -1сек


		; Проверить: не сработал ли Таймер? (если он активирован, в обратном ходе, и досчитал до нуля)
		LDD	temp,	Y+1					; загрузить байт из адреса: DTimerX_Seconds = (DTimerX+1)
		TST	temp
		BRNE	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; секунды != 0
		LDD	temp,	Y+2					; загрузить байт из адреса: DTimerX_Minutes = (DTimerX+2)
		TST	temp
		BRNE	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; минуты != 0
		LDD	temp,	Y+3					; загрузить байт из адреса: DTimerX_Hours = (DTimerX+3)
		TST	temp
		BRNE	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; часы != 0

		; Время пришло - включить звонок!
		LD	temp,	Y					; загрузить байт "Режим" из адреса: DTimerX_Mode = (DTimerX+0)
		ANDI	temp,	~(1<<MODE_ENABLED)			; состояние: остановить таймер
		ORI	temp,	1<<MODE_BELLRINGING			; состояние: включить звонок
		ST	Y,	temp
		LDI	temp,	CTimerRingDuration			; взвести звонок на столько секунд
		STD	Y+4,	temp					; сохранить байт в адрес: DTimerX_RingTimeout = (DTimerX+4)
		RCALL	SLEEPER_RESET					; "просыпаемся" при alarm-е
		; И, если не нахожусь в "режиме подстройки", то показательно переключить текущий режим интерфейса, на функцию, которая бузит: MODE_CURRENT_FUNCTION = FunctionTIMER.
		STOREB	DMain_Mode,	MODE_SETTINGS			; Загружаем DMain_Mode -> temp; MODE_SETTINGS -> T
		BRTS	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; Если T==1, значит нахожусь в "режиме подстройки" - не переключаемся.
		LDD	temp2,	Y+5					; загрузить байт "режим интерфейса" из адреса: DTimerX_FunctionID = (DTimerX+5)
		ANDI	temp,	~(0b111<<MODE_CURRENT_FUNCTION)		; 1) обнуляем текущий режим интерфейса
		OR	temp,	temp2					; 2) устанавливаем требуемый режим интерфейса
		STS	DMain_Mode,	temp				; Сохраняем DMain_Mode <- temp
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS		; (обнулить события всех Кнопок, при переходе в другую Подсистему интерфейса)
		RJMP	EndTimer__SECOND_ELAPSED_HANDLER_TIMER

	StoppedTimer__SECOND_ELAPSED_HANDLER_TIMER:
		; надо проверить: может уже хватит звонить? (если звонит)
		LDD	temp,	Y+4					; загрузить байт из адреса: DTimerX_RingTimeout = (DTimerX+4)
		SUBI	temp,	(1)					; декрементировать таймаут звонка
		STD	Y+4,	temp
		BRNE	EndTimer__SECOND_ELAPSED_HANDLER_TIMER		; ещё не досчитал до нуля?
		LD	temp,	Y					; загрузить байт "Режим" из адреса: DTimerX_Mode = (DTimerX+0)
		ANDI	temp,	~(1<<MODE_BELLRINGING)			; состояние: заглушим гудок
		ST	Y,	temp

	EndTimer__SECOND_ELAPSED_HANDLER_TIMER:

		RET


;***** END Interrupt handlers section 


;***** ИНИЦИАЛИЗАЦИЯ *******************************************************
RESET:
		WDTOFF		; Disable Watchdog timer permanently (ensure)
		STACKINIT	; Инициализация стека
		RAMFLUSH	; Очистка памяти
		GPRFLUSH	; Очистка РОН


;***** BEGIN Internal Hardware Init ****************************************

; Инициализация Портов:

		OUTI	PORTB,	0				; обнулить регистр выходных данных ПортаB (начальное положение)
		OUTI	DDRB,	(1<<PinClock1)|(1<<PinClock2)	; выводы Clock1, Clock2 - на "выход" (OUT)
		SETB	PORTB,	PinClock2			; Установить сигнал PinClock2="1": нормальное положение - индикатор включен/отображает	(функционал обработки задержек, для приручения внешней RC-цепочки, управляющей ключом, гасящим дисплей, на время обновления данных)


; Инициализация Timer/Counter0, который считает секунды:

		SETB	TIMSK,	TOIE0	; Разрешаем прерывания таймера: Overflow Interrupt Enable 
		OUTI	TCCR0B,	(0<<CS02)|(1<<CS01)|(1<<CS00)	; Запустить таймер: Предделитель = clkIO/64 (Источник = From prescaler, от Тактовой частоты)
								; Примечание: Значение Предделителя:
								;	CLK_XTAL = 32768 Hz
								;	TIMER1_PERIOD  = 0.5sec (итого, два переполнения в секунду)
								;	TIMER1_DIVIDER = CLK_XTAL * TIMER0_PERIOD / 256	= 64	(Результат должен получиться целым, степенью двойки, причём, значением поддерживаемым Предделителем Таймера!)
		RCALL	RESET_TIMER0	; Сбросить таймер

;***** END Internal Hardware Init 


;***** BEGIN External Hardware Init ****************************************
;***** END External Hardware Init 


;***** BEGIN "Run once" section (запуск фоновых процессов) *****************

; Инициализация "Режима интерфейса"

		OUTI	DMain_Mode,		(1<<MODE_SECONDSIGN)|(FunctionRTC<<MODE_CURRENT_FUNCTION)	; Текущий Режим = "Часы реального времени"
														; Секундная чёрточка: отображается в первую половину секунды (так эргономичнее: чёрточка зажигается вместе с переключением цифр на индикаторе)


; Инициализация "Часов реального времени"

		OUTI	DClock_Mode,		(1<<MODE_ENABLED)|(0<<MODE_AUTOHOURS)|(0<<MODE_INPUTSECONDS)	; Запускаем "Часы реального времени"
		;OUTI	DClock_Seconds,		55					; DEBUG: секунды
		;OUTI	DClock_Minutes, 	59					; DEBUG: минуты
		;OUTI	DClock_Hours,   	6					; DEBUG: часы


; Инициализация "Будильника"
		.equ	CAlarm_DefaultMode   =	(0<<MODE_ENABLED)|(0<<MODE_AUTOHOURS)|(0<<MODE_INPUTSECONDS)	; по умолчанию, Будильник: остановлен
		; подгрузить начальные настройки будильника из EEPROM (DAlarm <- EAlarm)
		LDI	EepromAddressLow,	Low(EAlarm_SavedSettings)		; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	EepromAddressHigh,	High(EAlarm_SavedSettings)		; 
		LDI	SramAddressLow,		Low(DAlarm_Mode)			; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	SramAddressHigh,	High(DAlarm_Mode)			; 
		LDI	PumpBytesCount,		EAlarm_size				; количество данных (в байтах)
		RCALL	EEPROM_READ_SEQUENCE
		;SETB	DAlarm_Mode,		MODE_ENABLED				; DEBUG: Включить Будильник


; Инициализация "Таймера1"

		OUTI	DTimer1_Mode,		(0<<MODE_ENABLED)|(0<<MODE_UPDOWN)|(1<<MODE_AUTOHOURS)|(1<<MODE_INPUTSECONDS)	; начальный режим Таймера: остановлен
		OUTI	DTimer1_Seconds,	0					; секунды
		OUTI	DTimer1_Minutes,	0					; минуты
		OUTI	DTimer1_Hours,		0					; часы
		OUTI	DTimer1_FunctionID,	(FunctionTIMER1<<MODE_CURRENT_FUNCTION)	; соответствующий ему "режим интерфейса"


; Инициализация "Таймера2"

		OUTI	DTimer2_Mode,		(0<<MODE_ENABLED)|(0<<MODE_UPDOWN)|(1<<MODE_AUTOHOURS)|(1<<MODE_INPUTSECONDS)
		OUTI	DTimer2_Seconds,	0
		OUTI	DTimer2_Minutes,	0
		OUTI	DTimer2_Hours,		0
		OUTI	DTimer2_FunctionID,	(FunctionTIMER2<<MODE_CURRENT_FUNCTION)


; Инициализация "Таблицы символов"
		; подгрузить содержимое из EEPROM (DSymbolsTable  <- ESymbolsTable)
		LDI	EepromAddressLow,	Low(ESymbolsTable)			; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	EepromAddressHigh,	High(ESymbolsTable)			; 
		LDI	SramAddressLow,		Low(DSymbolsTable)			; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	SramAddressHigh,	High(DSymbolsTable)			; 
		LDI	PumpBytesCount,		SymbolsTable_size			; количество данных (в байтах)
		RCALL	EEPROM_READ_SEQUENCE


; Инициализация "Спящего режима"
		RCALL	SLEEPER_RESET


		SEI  ; Разрешаем глобальные прерывания

;***** END "Run once" section 

;***** BEGIN "Main" section ************************************************

MAIN:
		; (Суперцикл: реализующий сканирование Кнопок и переключение Режимов)

		; Сканирование Кнопок
		OUTI	DKeyScanCnt,	20				; DKeyScanCnt = количество циклов "сканирования кнопок".	(а затем будет один цикл "реакции на события")
	LoopKeyScan__MAIN:
		RCALL	KEY_SCAN_INPUT					; Головная процедура конвеера обработки кнопок: Сканирует физические кнопки и устанавливает их статус-регистры (запускать часто)
		DEC8M	DKeyScanCnt
		BRNE	LoopKeyScan__MAIN
		
		; Переключение Режимов ("реакция на события")
		RCALL	SWITCH_MODES					; Важно: DKeyScanCnt, выше, следует подбирать так, чтобы "SWITCH_MODES" выполнялся ~10-20раз/сек. Тогда будет эргономичная "инерционность" реакции кнопок (что особенно важно: для работы кнопки "DButtonStartStatus", при вводе значения Параметра, в режиме Настройки)...
		
		RJMP	MAIN						

		; (обработка событий завершена)


;***** END "Main" section 

;***** BEGIN Procedures section ********************************************

	; Внимание! В отличие от Макросов, Код процедур, всегда и полностью, 
	; включается в сегмент данных программы - занимает место! 
	; Поэтому, здесь должны быть включены только те процедуры, которые 
	; реально используются. (Остальные - следует /* закомментировать */.)

	.include "proclib.inc"			; Библиотека стандартных Подпрограмм.
	.include "avr204.inc"			; Библиотека процедур Арифметики ДДК от Atmel. (AVR204 AppNote)
	.include "procDisplayOutput.inc"	; Блок отлаженных и функционально обособленных процедур, предназначенных для поддержки ВЫВОДА: на семисегментные индикаторы, статическим способом, через сдвиговые регистры.	(выделено в отдельный файл, для удобства)
	.include "celeronkeyinputlib.inc"	; Библиотека процедур для интеллектуальной обработки ВВОДА: сканирование Кнопок и Энкодеров.



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;
; Универсальная процедура: "Модифицировать значение Счётчика Времени в памяти"
;
; 
; позволяет модифицировать: Увеличить (CALL INC_*) или Уменьшить (CALL DEC_*),
; "счётчик времени" расположенный в памяти с адреса: ExtendTimeInAddress,
; на любое указанное количество (ExtendTimeByValue)... и каких единиц:
; 	секунд (CALL *_TIME_SECONDS) или
; 	минут  (CALL *_TIME_MINUTES) или
; 	часов  (CALL *_TIME_HOURS).
;
; Примечание: Код данной процедуры создана по типу "горыныч-мутант" (с шестью "головами"-входами и двумя кхм-выходами) - 
; поэтому, в зависимости от требуемой функции, следует вызывать соответствующую точку входа...
;
; Соглашение: формат "счётчика времени", в памяти, предполагается следующим (little-endian): [сначала, 1байт секунды /] затем, 1байт минуты / наконец, 1байт часы.
; Параметр ExtendTimeInAddress следует инициализировать на адрес той ячейки, единицы измерения которой модифицируются, и через которую точку входа вызываем процедуру - например:
; 	чтобы прибавить/отнять несколько секунд: ExtendTimeInAddress = адрес [начального] байта секунд;	и вызвать точку входа (CALL *_TIME_SECONDS).
; 	чтобы прибавить/отнять несколько минут:  ExtendTimeInAddress = адрес [среднего]   байта минут;	и вызвать точку входа (CALL *_TIME_MINUTES).
; 	чтобы прибавить/отнять несколько часов:  ExtendTimeInAddress = адрес [последнего] байта часов;	и вызвать точку входа (CALL *_TIME_HOURS).
;
;
; Примечание: Конечно, в "счётчике времени", разряды часов/минут/секунд связаны между собой: "часы" - это "старший разряд" для "минут", а "минуты" - старший для "секунд"... 
; И существует явление переноса единиц в старшие разряды (например, когда 59мин +1мин), или заём единиц из старшего разряда (например, если 0мин -1мин)...
;
; Соглашение: По умолчанию, и для поддержки естественной работы счётчиков: при их модификации, величины разрядов автоматически нормализуются до разрешённых значений (до 60сек, 60мин, 24ч), и также производятся переносы/заёмы к старшему разряду.
; Но в режиме "ручной аддитивной подстройки" значений счётчиков: естественнее заблокировать перенос разряда, чтобы уменьшить путаницу - так уже сложилась традиция и привык пользователь (раздельно настраивать значения часов/минут/секунд).
; Поэтому, существует ещё параметр функции - status bit "T":
; 	T=0	разрешает перенос/заём из старшего разряда (по умолчанию, при естественной работе счётчиков)
; 	T=1	запрещает перенос/заём из старшего разряда (используется в функциях "ручной настройки" значений времени)
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

.def	ExtendTimeInAddressLow	= R26	; XL
.def	ExtendTimeInAddressHigh	= R27	; XH
.def	ExtendTimeByValue	= R25

; Также, параметром является status bit "T": 
; 	T=0	разрешает перенос/заём из старшего разряда (по умолчанию, при естественной работе счётчиков)
; 	T=1	запрещает перенос/заём из старшего разряда (используется в функциях "ручной настройки" значений времени)

; Памятка: также использует/портит содержимое регистров TEMP1, TEMP2.

;----- Code


INC_TIME_SECONDS:
		LDI	temp2,	60	; параметр: разрядность поля
		RCALL	INC_TIME_HELPER

INC_TIME_MINUTES:
		LDI	temp2,	60
		RCALL	INC_TIME_HELPER
		
INC_TIME_HOURS:
		LDI	temp2,	24
		RCALL	INC_TIME_HELPER

		RET


; Арифметически, Минутное поле наращиваются абсолютно по тем же законам, что и Секундное.
; Да и Часовое поле, за исключением его разрядности (TEMP2 = 24часа vs. 60мин/сек), - также сходным образом.
; Поэтому "код модификации одного Поля" вынесен в отдельную вспомогательную Процедуру:

INC_TIME_HELPER:
		; Для начала проверим: а следует ли вообще продолжать этот громоздкий конвеер - задано ли приращение, или оно нулевое?
		; (такая ситуация может возникать и сама, впоследствии, при отсутствии переноса в старший разряд)
		TST	ExtendTimeByValue
		BREQ	Exit__INC_TIME_HELPER			; если ExtendTimeByValue == 0, то RET.

		; Начало обработки разряда:
		LD	temp1,	X				; Загружаем значение секунд/минут/часов из памяти, по адресу ExtendTimeInAddress.
		ADD	temp1,	ExtendTimeByValue		; Прибавляем требуемое число. (Заметим, что в худшем случае получим: Rd=59+255=314, т.е. Rd=314-256=58 и "флаг заёма" C=1)
		CLR	ExtendTimeByValue			; Теперь здесь будет значение переноса в старший разряд... (Примечание: данная инструкция не сбрасывает "флаг заёма" C, от предыдущей операции)

		; Если был зафиксирован перенос сверх разрядности байта, то вносим коррекцию:
		BRCC	SkipCorrection__INC_TIME_HELPER
		; (Определим величину коррекции)
		CPI	temp2,	60				; Распознаём: текущее поле - это "Минуты"/"Секунды"?
		BRNE	CorrectHours__INC_TIME_HELPER		; нет "Часы"...
CorrectSecMin__INC_TIME_HELPER:
		; (+256сек = +4мин +16сек) или также (+256мин = +4ч +16мин)
		SUBI	ExtendTimeByValue,	(-4)
		SUBI	temp1,			(-16)
		RJMP	SkipCorrection__INC_TIME_HELPER
CorrectHours__INC_TIME_HELPER:
		; (+256ч = +10суток +16ч)
		SUBI	ExtendTimeByValue,	(-10)
		SUBI	temp1,			(-16)
SkipCorrection__INC_TIME_HELPER:

		; Нормализуем значение Поля до пределов его разрядности TEMP2	(примечание: данный алгоритм подобен процедуре "bin2bcd8" в AVR204)
Normalization__INC_TIME_HELPER:
		SUB	temp1,	temp2				; уменьшить значение корректируемого Поля на "вес разряда"
		BRCS	EndNormalization__INC_TIME_HELPER	; если заступил меньше нуля (C=1), то хватит...
		INC	ExtendTimeByValue			; если не заступил, то засчитываем это в +1 старший разряд
		RJMP	Normalization__INC_TIME_HELPER		; loop again
EndNormalization__INC_TIME_HELPER:
		ADD	temp1,	temp2				; ...коррекция последнего заступа: вернуть +один "вес разряда"

		ST	X+,	temp1				; Сохраняем итоговое значение секунд/минут/часов в память. И наращиваем адрес текущей ячейки ExtendTimeInAddress на +1 байт.
		BRTC	Exit__INC_TIME_HELPER			; Если T==0	-> разрешает перенос/заём из старшего разряда (по умолчанию, при естественной работе счётчиков)
		CLR	ExtendTimeByValue			; Если T==1	-> запрещает перенос/заём из старшего разряда (используется в функциях "ручной настройки" значений времени)

Exit__INC_TIME_HELPER:
		RET						; Выход из вспомогательной процедуры



;----- Code


DEC_TIME_SECONDS:
		LDI	temp2,	60	; параметр: разрядность поля
		RCALL	DEC_TIME_HELPER

DEC_TIME_MINUTES:
		LDI	temp2,	60
		RCALL	DEC_TIME_HELPER
		
DEC_TIME_HOURS:
		LDI	temp2,	24
		RCALL	DEC_TIME_HELPER

		RET


; Арифметически, Минутное поле уменьшается абсолютно по тем же законам, что и Секундное.
; Да и Часовое поле, за исключением его разрядности (TEMP2 = 24часа vs. 60мин/сек), - также сходным образом.
; Поэтому "код модификации одного Поля" вынесен в отдельную вспомогательную Процедуру:

DEC_TIME_HELPER:
		; Для начала проверим: а следует ли вообще продолжать этот громоздкий конвеер - задано ли приращение, или оно нулевое?
		; (такая ситуация может возникать и сама, впоследствии, при отсутствии переноса в старший разряд)
		TST	ExtendTimeByValue
		BREQ	Exit__DEC_TIME_HELPER			; если ExtendTimeByValue == 0, то RET.

		; Начало обработки разряда:
		LD	temp1,	X				; Загружаем значение секунд/минут/часов из памяти, по адресу ExtendTimeInAddress.
		SUB	temp1,	ExtendTimeByValue		; Отнимаем требуемое число. (Заметим, что в худшем случае получим: Rd=0-255=-255, т.е. Rd=256-255=1 и "флаг заёма" C=1) где (-255сек = -4мин -15сек)
		CLR	ExtendTimeByValue			; Теперь здесь будет значение заёма из старшего разряда... (Примечание: данная инструкция не сбрасывает "флаг заёма" C, от предыдущей операции)

		; Если был зафиксирован перенос меньше нуля, то вносим коррекцию:
		BRCC	EndNormalization__DEC_TIME_HELPER
		; (Примечание: здесь проще - для коррекции используется только алгоритм Нормализации)

		; Нормальзуем значение Поля до пределов его разрядности TEMP2	(примечание: данный алгоритм подобен процедуре "bin2bcd8" в AVR204)
Normalization__DEC_TIME_HELPER:
		ADD	temp1,	temp2				; увеличить значение корректируемого Поля на "вес разряда"
		INC	ExtendTimeByValue			; и засчитываем это в -1 старший разряд
		BRCS	EndNormalization__DEC_TIME_HELPER	; если заступил больше 0xFF (C=1), то хватит...
		RJMP	Normalization__DEC_TIME_HELPER		; loop again
EndNormalization__DEC_TIME_HELPER:

		ST	X+,	temp1				; Сохраняем итоговое значение секунд/минут/часов в память. И наращиваем адрес текущей ячейки ExtendTimeInAddress на +1 байт.
		BRTC	Exit__DEC_TIME_HELPER			; Если T==0	-> разрешает перенос/заём из старшего разряда (по умолчанию, при естественной работе счётчиков)
		CLR	ExtendTimeByValue			; Если T==1	-> запрещает перенос/заём из старшего разряда (используется в функциях "ручной настройки" значений времени)

Exit__DEC_TIME_HELPER:
		RET						; Выход из вспомогательной процедуры



;----- "Индексная таблица" точек входа в процедуру "Модифицировать значение Счётчика Времени в памяти" (для автоматизации вызовов):

IndexTable__CALL_MOD_TIME:
		.DW	INC_TIME_SECONDS	; прибавить несколько секунд
		.DW	INC_TIME_MINUTES	; прибавить несколько минут
		.DW	INC_TIME_HOURS		; прибавить несколько часов
		.DW	DEC_TIME_SECONDS	; отнять несколько секунд
		.DW	DEC_TIME_MINUTES	; отнять несколько минут
		.DW	DEC_TIME_HOURS		; отнять несколько часов



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;
; Процедура переключения режимов интерфейса ("реакция на события")
; 
; 	SWITCH_MODES
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

; Без параметров.

; Памятка: также использует/портит содержимое регистров TEMP1, TEMP2, 
; 	Y(R29:R28),			(опосредованно в SWITCH_TIMER_MODES, SWITCH_MODE_SETTINGS)
; 	R25, X(R27:R26), Z(R31:R30).	(опосредованно в "Модифицировать значение Счётчика Времени в памяти")

;----- Code


; Примечание: здесь можно было построить код по универсальной модели, как в DISPLAY_PREPARE: сперва большой переключатель, в зависимости от текущего "режима интерфейса", на подпрограмму соответствующего обработчика.
; И описать отдельные обработчики на все состояния интерфейса, и в каждом из них - описать полный набор возможных переходов из данного состояния в другие... Это универсальный подход, но несколько избыточный (кода много). 
; А с учётом прикладной модели данной программы, возможна оптимизация и мультиплексирование кода в разных состояниях (выделены подсистемы: "работа в режиме Настройки", "переключение Функций" и т.п.) - таким образом, здесь, использована традиционная модель кодирования (ветвления, подпрограммы)...


SWITCH_MODES:

		;** Подсистема: "Выход из Спящего режима"
		STOREB	DSleep,	SLEEPMODE_ON					; Флаг "активирован режим экономии электроэнергии (спящий режим)":	=0, нормальный режим	=1, активирован "спящий режим"
		BRTC	WakefulMode__SWITCH_MODES				; если не спим, то отрабатываем все события от пользовательского интерфейса...
		; (состояние: уже вошёл в спящий режим)
		STOREB	DSleep,	WAKEUP_BUTTONS_HAVE_PREPARED			; Флаг "события всех Кнопок обнулены, готов проснуться по любой следующей кнопке"
		BRTS	WhileSleeping__SWITCH_MODES
		; (состояние: заснул, но ещё не обнулил кнопки)
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (обнулить события всех Кнопок, чтобы приготовиться проснуться по любому СЛЕДУЮЩЕМУ событию
		SETB	DSleep,	WAKEUP_BUTTONS_HAVE_PREPARED			; и поднять соответствующий флаг)
	JustExit__SWITCH_MODES:
		RJMP	Exit__SWITCH_MODES					; ничего не делать, переход на следующую итерацию...
	WhileSleeping__SWITCH_MODES:
		; (состояние: уже сплю и обнулил статусы кнопок - теперь внимательно слежу за ними, по следующему событию проснусь)
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortHold	; (здесь: перечисляем все кнопки, по нажатию на которые хотим просыпаться)
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortHold	; (причём: событие определяем как BSC_ShortHold - "достаточно лёгкого прикосновения")
		OR_BUTTON_HAVE_STATUS	DButtonRTCStatus,	BSC_ShortHold
		OR_BUTTON_HAVE_STATUS	DButtonTimer1Status,	BSC_ShortHold
		OR_BUTTON_HAVE_STATUS	DButtonTimer2Status,	BSC_ShortHold
		BRTC	JustExit__SWITCH_MODES					; если кнопки не были нажаты...
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.	
										; 	(Примечание: здесь, чтобы не морочиться с отдельными кнопками - стрельнём из пушки сразу по всем!)
										; 	(таким образом, подавляем побочные эффекты от кнопок, нажатых пользователем "вслепую")
		RJMP	EventButtonHavePressed__SWITCH_MODES			; Разбудить "соню"...	(сразу после пробуждения - другие события мы не обрабатываем)
	WakefulMode__SWITCH_MODES:



		;** Подсистема: "работа в режиме Настройки"
	;SettingsMode__SWITCH_MODES:
		STOREB	DMain_Mode,	MODE_SETTINGS				; Флаг "находимся в режиме настройки" - для всех функций (часов, будильника, таймеров):	=0, нормальный режим	=1, вошёл в режим подстройки
		BRTC	NormalMode__SWITCH_MODES
		RCALL	SWITCH_MODE_SETTINGS
		BRTC	EndSettingsMode__SWITCH_MODES				; если кнопки не были нажаты...
		RJMP	EventButtonHavePressed__SWITCH_MODES
	EndSettingsMode__SWITCH_MODES:
		RJMP	Exit__SWITCH_MODES					; если мы всё же находимся в "режиме Настройки", то обработка всех других событий - безусловно блокирована, пока не выйдем из "режима Настройки"...
	NormalMode__SWITCH_MODES:



		;** Подсистема: "переключение Функций"
	;SwitchFunc_RTC_Alarm__SWITCH_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonRTCStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonRTCStatus,	BSC_LongHold
		BRTC	SwitchFunc_Timer1__SWITCH_MODES				; если кнопки не были нажаты...
		;OUTI	DButtonRTCStatus,	0b00000000			; После обработки состояния кнопки - сделать "НЕМЕДЛЕННЫЙ СБРОС" её статусного регистра.	(Примечание: здесь используется вариант "СБРОС в ноль" - вследствие чего, статус-регистр кнопки будет обнулён НЕМЕДЛЕННО, даже если кнопка ещё удерживается в BSC_LongHold.	Пояснение: Здесь отсутствует "триггер защёлка-состояния", заставляющий пользователя отпускать кнопку, перед следующим нажатием - хотя, обычно, это полезно: ибо предотвращает серии ошибочных повторных срабатываний кнопки!) 
										; 	Пусть, здесь, Я УМЫШЛЕННО ХОЧУ ОСОБОЕ ПОВЕДЕНИЕ: когда пользователь просто удерживает долго кнопку DButtonRTCStatus, чтобы функция автоматически периодически переключалась RTC<->Alarm, каждые CShortButtonTouchDuration полусекунд - Использовал вариант: "НЕМЕДЛЕННЫЙ СБРОС"...	Протестировал "user experience": Нет, неудобно и глючно! Когда я удерживаю некую кнопку, то функции циклически переключаются F1->F2->F1->... Причём, когда я попадаю в нужную мне функцию, скажем F2, то я отпускаю удерживаемую кнопку - однако, тут же срабатывает событие "BSC_ShortPress", и функция лишний раз переключается в F1 (неудобно, нужно вводить коррекцию-откат)! 
										; 	В итоге, решил всё-таки отказаться, здесь, от варианта ""НЕМЕДЛЕННЫЙ СБРОС", в пользу концептуально-правильному "ОТЛОЖЕННОМУ СБРОСУ".
		OUTI	DButtonRTCStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.		(Примечание: это другой вариант поведения, "с триггером защёлкой-состояния": заставлять пользователя отпускать кнопку, перед следующим нажатием - что обычно полезно, ибо предотвращает серии ошибочных повторных срабатываний кнопки...)

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
		BRTC	SwitchFunc_Timer2__SWITCH_MODES				; если кнопки не были нажаты...
		OUTI	DButtonTimer1Status,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.

		IF_CURRENT_FUNCTION	FunctionTIMER1
		BREQ	SwitchTimer1Direction__SWITCH_MODES
		SWITCH_CURRENT_FUNCTION		FunctionTIMER1			; Переключиться на функцию Таймер1 с каких-то других функций.
		RJMP	EventButtonHavePressed__SWITCH_MODES
	SwitchTimer1Direction__SWITCH_MODES:
		; Проверить: остановлен ли таймер?
		STOREB	DTimer1_Mode,	MODE_ENABLED				; Флаг "режим активности":	=0 остановлен,		=1 бежит
		BRTC	SwitchTimer1DirectionEnabled__SWITCH_MODES
		RJMP	Exit__SWITCH_MODES					; если данный Таймер не остановлен, то переключение Направления запрещено!
	SwitchTimer1DirectionEnabled__SWITCH_MODES:
		; (состояние: этот таймер сейчас остановлен)
		INVB	DTimer1_Mode,	MODE_UPDOWN				; Флаг "режим направления":	=0 прямой счёт,		=1 обратный счёт
		RJMP	EventButtonHavePressed__SWITCH_MODES


	SwitchFunc_Timer2__SWITCH_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonTimer2Status,	BSC_ShortPress		
		OR_BUTTON_HAVE_STATUS	DButtonTimer2Status,	BSC_LongHold		
		BRTC	SwitchFunc_End__SWITCH_MODES				; если кнопки не были нажаты...
		OUTI	DButtonTimer2Status,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.

		IF_CURRENT_FUNCTION	FunctionTIMER2
		BREQ	SwitchTimer2Direction__SWITCH_MODES
		SWITCH_CURRENT_FUNCTION		FunctionTIMER2			; Переключиться на функцию Таймер1 с каких-то других функций.
		RJMP	EventButtonHavePressed__SWITCH_MODES
	SwitchTimer2Direction__SWITCH_MODES:
		; Проверить: остановлен ли таймер?
		STOREB	DTimer2_Mode,	MODE_ENABLED				; Флаг "режим активности":	=0 остановлен,		=1 бежит
		BRTC	SwitchTimer2DirectionEnabled__SWITCH_MODES
		RJMP	Exit__SWITCH_MODES					; если данный Таймер не остановлен, то переключение Направления запрещено!
	SwitchTimer2DirectionEnabled__SWITCH_MODES:
		; (состояние: этот таймер сейчас остановлен)
		INVB	DTimer2_Mode,	MODE_UPDOWN				; Флаг "режим направления":	=0 прямой счёт,		=1 обратный счёт
		RJMP	EventButtonHavePressed__SWITCH_MODES

	SwitchFunc_End__SWITCH_MODES:




		;** Управление функцией "RTC":
	;ControlRTC__SWITCH_MODES:
		IF_CURRENT_FUNCTION	FunctionRTC
		BRNE	EndControlRTC__SWITCH_MODES

		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		AND_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	ControlRTC2__SWITCH_MODES				; если кнопки не были нажаты...
		OUTI	DButtonSetStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.
		OUTI	DButtonStartStatus,	0b11111111
		SETB	DMain_Mode,	MODE_SETTINGS				; Прикладная реакция: войти в "режим настройки",
		OUTI	DSettings_Mode,	1<<SETTING_HOURS			; 	начиная с настройки "счётчика Часов",
		CLRB	DClock_Mode,	MODE_ENABLED				; 	приостановить ход часов,
		OUTI	DClock_Seconds,	0					; 	и обнулить счётчик Секунд.
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (обнулить события всех Кнопок, при переходе в другую Подсистему интерфейса)
		RJMP	EventMuteAlarm__SWITCH_MODES

	ControlRTC2__SWITCH_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		BRTC	EndControlRTC__SWITCH_MODES				; если кнопки не были нажаты...
		OUTI	DButtonStartStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.
		OUTI	DButtonSetStatus,	0b11111111
		RJMP	EventMuteAlarm__SWITCH_MODES				; Прикладной реакции здесь нет! Смысл: глушить "зуммер" большой кнопкой.

	EndControlRTC__SWITCH_MODES:
		
		
		;** Управление функцией "ALARM":
	ControlAlarm__SWITCH_MODES:
		IF_CURRENT_FUNCTION	FunctionALARM
		BREQ	ControlAlarm1__SWITCH_MODES
		RJMP	EndControlAlarm__SWITCH_MODES
	ControlAlarm1__SWITCH_MODES:

		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		OR_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	ControlAlarm2__SWITCH_MODES				; если кнопки не были нажаты...
		OUTI	DButtonSetStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.
		OUTI	DButtonStartStatus,	0b11111111
		SETB	DMain_Mode,	MODE_SETTINGS				; Прикладная реакция: войти в "режим настройки",
		OUTI	DSettings_Mode,	1<<SETTING_HOURS			; 	начиная с настройки "счётчика Часов".
		;OUTI	DAlarm_Seconds,	0					; 	и обнулить счётчик Секунд.	(здесь, не используется)
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (обнулить события всех Кнопок, при переходе в другую Подсистему интерфейса)
		RJMP	EventMuteAlarm__SWITCH_MODES
		
	ControlAlarm2__SWITCH_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		BRTC	EndControlAlarm__SWITCH_MODES				; если кнопки не были нажаты...
		OUTI	DButtonStartStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.
		OUTI	DButtonSetStatus,	0b11111111
		STOREB	DAlarm_Mode,	MODE_BELLRINGING			; Флаг "гудок будильника звонит" -> T
		BRTS	EventMuteAlarm__SWITCH_MODES				; Если гудок звонит, то особой прикладной реакции нет - только заглушить "зуммер"...
		INVB	DAlarm_Mode,	MODE_ENABLED				; Прикладная реакция: переключить режим Будильника = вкл./выкл.
		RJMP	EventMuteAlarm__SWITCH_MODES

	EndControlAlarm__SWITCH_MODES:


		;** Управление функцией "TIMER1":
	ControlTimer1__SWITCH_MODES:
		IF_CURRENT_FUNCTION	FunctionTIMER1
		BRNE	EndControlTimer1__SWITCH_MODES

		LDI	TimerModeAddressLow,	Low(DTimer1_Mode)		; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	TimerModeAddressHigh,	High(DTimer1_Mode)		;
		RCALL	SWITCH_TIMER_MODES
		BRTC	EndControlTimer1__SWITCH_MODES				; если кнопки не были нажаты...
		RJMP	EventMuteAlarm__SWITCH_MODES

	EndControlTimer1__SWITCH_MODES:


		;** Управление функцией "TIMER2":
	ControlTimer2__SWITCH_MODES:
		IF_CURRENT_FUNCTION	FunctionTIMER2
		BRNE	EndControlTimer2__SWITCH_MODES

		LDI	TimerModeAddressLow,	Low(DTimer2_Mode)		; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	TimerModeAddressHigh,	High(DTimer2_Mode)		;
		RCALL	SWITCH_TIMER_MODES
		BRTC	EndControlTimer2__SWITCH_MODES				; если кнопки не были нажаты...
		RJMP	EventMuteAlarm__SWITCH_MODES

	EndControlTimer2__SWITCH_MODES:




		;** (обработка событий кнопок завершена)
		RJMP	Exit__SWITCH_MODES
EventMuteAlarm__SWITCH_MODES:
		; заглушим все гудки, при нажатии некоторых кнопочных комбинаций
		CLRB	DAlarm_Mode,	MODE_BELLRINGING
		CLRB	DTimer1_Mode,	MODE_BELLRINGING
		CLRB	DTimer2_Mode,	MODE_BELLRINGING
EventButtonHavePressed__SWITCH_MODES:
		; "просыпаемся" от нажатия любой кнопки
		RCALL	SLEEPER_RESET
Exit__SWITCH_MODES:
		; если нажатий кнопок не было зафиксировано, то просто выход
		RET



;---------------------------------------------------------------------------
;
; Вспомогательная процедура переключения режимов интерфейса:
; 
; 	SWITCH_TIMER_MODES
; (подсистема: работа "Таймера/Секундомера")
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

;.def	TimerModeAddressLow	= R28	; YL
;.def	TimerModeAddressHigh	= R29	; YH

; Также, ВЫХОДНЫМ параметром является status bit "T": 
; 	T=0	событий от кнопок не зафиксировано...
; 	T=1	были зафиксированы нажатия кнопок!

; Памятка: также использует/портит содержимое регистров: TEMP1, TEMP2.

;----- Code


SWITCH_TIMER_MODES:

		; Реализация "Старт/Стоп" (одинакова и в Таймере, и в Секундомере).
	;StartStop__SWITCH_TIMER_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongPress
		BRTC	EndStartStop__SWITCH_TIMER_MODES			; если кнопки не были нажаты...
		OUTI	DButtonStartStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.
		
		; Проверим дополнительные условия: разрешено ли переключать режим хода?
		; (например, запрещено включать остановленный Таймер обратного счёта, если он уже досчитал до нуля!)
		LD	temp1,	Y						; загрузить байт "Режим" из адреса: DTimerX_Mode = (DTimerX+0)
		BST	temp1,	MODE_ENABLED					; Флаг "режим активности" -> T:		=0 остановлен,	=1 бежит
		BRTS	AllowStartStop__SWITCH_TIMER_MODES
		BST	temp,	MODE_UPDOWN					; Флаг "режим направления" -> T:	=0 прямой счёт,	=1 обратный счёт
		BRTC	AllowStartStop__SWITCH_TIMER_MODES
		LDD	temp1,	Y+1						; загрузить байт "Секунды"
		LDD	temp2,	Y+2						; загрузить байт "Минуты"
		OR	temp1,	temp2
		LDD	temp2,	Y+3						; загрузить байт "Часы"
		OR	temp1,	temp2
		BRNE	AllowStartStop__SWITCH_TIMER_MODES			; если "счётчик времени" <> 0?	то разрешить...
		SET								; T=1 (выходной параметр процедуры)
		RJMP	Exit__SWITCH_TIMER_MODES				; запретить переключение...

	AllowStartStop__SWITCH_TIMER_MODES:
		;INVB	DTimerX_Mode,	MODE_ENABLED				; Прикладная реакция: переключить режим хода = "Старт/Стоп":
		LD	temp1,	Y						; 	загрузить байт "Режим" из адреса: DTimerX_Mode = (DTimerX+0),
		LDI	temp2,	1<<MODE_ENABLED					; 	взять бит,
		EOR	temp1,	temp2						; 	инвертировать,
		ST	Y,	temp1						; 	сохранить.
		
		SET								; T=1 (выходной параметр процедуры)
		RJMP	Exit__SWITCH_TIMER_MODES
	EndStartStop__SWITCH_TIMER_MODES:
		
		
		
		; (Примечание: Остальные реакции - только при остановленном ходе!)
		LD	temp,	Y						; загрузить байт "Режим" из адреса: DTimerX_Mode = (DTimerX+0)
		BST	temp,	MODE_ENABLED					; Флаг "режим активности" -> T:		=0 остановлен,	=1 бежит
		BRTC	TimerIsStopped__SWITCH_TIMER_MODES
		RJMP	NoEvent__SWITCH_TIMER_MODES
		
		
		; (состояние: сейчас, ход остановлен)
	TimerIsStopped__SWITCH_TIMER_MODES:
		BST	temp,	MODE_UPDOWN					; Флаг "режим направления" -> T:	=0 прямой счёт,	=1 обратный счёт
		BRTS	DownTimer__SWITCH_TIMER_MODES
		
	;UpTimer__SWITCH_TIMER_MODES:
		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		OR_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	NoEvent__SWITCH_TIMER_MODES				; если кнопки не были нажаты...
		OUTI	DButtonSetStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.
		OUTI	DButtonStartStatus,	0b11111111
		CLR	temp							; Прикладная реакция: сбросить "счётчик времени" в ноль:
		STD	Y+1,	temp						; 	сохранить байт в адрес: DTimerX_Seconds = (DTimerX+1)
		STD	Y+2,	temp						; 	сохранить байт в адрес: DTimerX_Minutes = (DTimerX+2)
		STD	Y+3,	temp						; 	сохранить байт в адрес: DTimerX_Hours = (DTimerX+3)
		SET								; T=1 (выходной параметр процедуры)
		RJMP	Exit__SWITCH_TIMER_MODES
		
	DownTimer__SWITCH_TIMER_MODES:
		
		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		OR_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	NoEvent__SWITCH_TIMER_MODES				; если кнопки не были нажаты...
		OUTI	DButtonSetStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.
		OUTI	DButtonStartStatus,	0b11111111
		SETB	DMain_Mode,	MODE_SETTINGS				; Прикладная реакция: войти в "режим настройки",
		OUTI	DSettings_Mode,	1<<SETTING_MINUTES			; 	начиная с настройки "счётчика Минут".
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (обнулить события всех Кнопок, при переходе в другую Подсистему интерфейса)
		SET								; T=1 (выходной параметр процедуры)
		RJMP	Exit__SWITCH_TIMER_MODES
		
		
		
	NoEvent__SWITCH_TIMER_MODES:
		CLT								; T=0 (выходной параметр процедуры)
	Exit__SWITCH_TIMER_MODES:
		RET



;---------------------------------------------------------------------------
;
; Вспомогательная процедура переключения режимов интерфейса:
; 
; 	SWITCH_MODE_SETTINGS
; (подсистема: работа в "режиме Настройки")
;
;
; Текущая Функция, параметры которой настраиваются - определяется из значения глобальной переменной DMain_Mode...
; Текущий Параметр, который настраивается - определяется из значения глобальной переменной DSettings_Mode...
; 
; Переключение к очередному "настраиваемому Параметру" управляется "data-driven" параметром - битом MODE_INPUTSECONDS, в байте "Режим", соответствующей Функции:
; 	Флаг "настраивать параметр Секунды":
; 	=0, настраивать два показателя: только Часы и Минуты, а Секунды просто обнуляются	(для Часов и Будильника)
; 	=1, настраивать три показателя: Часы, Минуты, Секунды					(для Таймеров)
;
;---------------------------------------------------------------------------

;----- Subroutine Register Variables

; Без параметров.

; Также, ВЫХОДНЫМ параметром является status bit "T": 
; 	T=0	событий от кнопок не зафиксировано...
; 	T=1	были зафиксированы нажатия кнопок!

; Памятка: также использует/портит содержимое регистров TEMP1, TEMP2, Y(R29:R28),
; 	R25, X(R27:R26), Z(R31:R30).	(опосредованно в "Модифицировать значение Счётчика Времени в памяти")

;----- Code


SWITCH_MODE_SETTINGS:

		; Определить текущую Функцию, параметры которой настраиваются:
		; Определить адрес "счётчика времени", который настраивается:
	;IfRTC__SWITCH_MODE_SETTINGS:
		IF_CURRENT_FUNCTION	FunctionRTC
		BRNE	IfAlarm__SWITCH_MODE_SETTINGS
		LDI	YL,	Low(DClock_Mode)				; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	YH,	High(DClock_Mode)				;
		RJMP	EndIf__SWITCH_MODE_SETTINGS
	
	IfAlarm__SWITCH_MODE_SETTINGS:
		IF_CURRENT_FUNCTION	FunctionALARM
		BRNE	IfTimer1__SWITCH_MODE_SETTINGS
		LDI	YL,	Low(DAlarm_Mode)				; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	YH,	High(DAlarm_Mode)				;
		RJMP	EndIf__SWITCH_MODE_SETTINGS
		
	IfTimer1__SWITCH_MODE_SETTINGS:
		IF_CURRENT_FUNCTION	FunctionTIMER1
		BRNE	IfTimer2__SWITCH_MODE_SETTINGS
		LDI	YL,	Low(DTimer1_Mode)				; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	YH,	High(DTimer1_Mode)				;
		RJMP	EndIf__SWITCH_MODE_SETTINGS

	IfTimer2__SWITCH_MODE_SETTINGS:
		IF_CURRENT_FUNCTION	FunctionTIMER2
		BRNE	ElseIf__SWITCH_MODE_SETTINGS
		LDI	YL,	Low(DTimer2_Mode)				; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	YH,	High(DTimer2_Mode)				;
		RJMP	EndIf__SWITCH_MODE_SETTINGS

	ElseIf__SWITCH_MODE_SETTINGS:
		RJMP	NoEvent__SWITCH_MODE_SETTINGS				; Обнаружена Функция, для которой не предусмотрен "режим Настройки" (Ошибка в значении DMain_Mode?). Идём на выход...
	EndIf__SWITCH_MODE_SETTINGS:



		;** Переключения к очередному "настраиваемому Параметру"
		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortPress
		BRTC	EndNextParameter__SWITCH_MODE_SETTINGS			; если кнопки не были нажаты...
		OUTI	DButtonSetStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.

		LD	temp1,	Y						; загрузить байт "Режим", соответствующей отображаемой текущей функции
		BST	temp1,	MODE_INPUTSECONDS				; Флаг "настраивать параметр Секунды" -> T
		LDS	temp1,	DSettings_Mode					; загрузить байт, параметризующий текущий подрежим режима "Настройки"
		LSL	temp1							; Прикладная реакция: переключить настраиваемый Параметр: Часы -> Минуты -> Секунды -> C
										; 	причём, заодно: Флаг "находимся в режиме настройки счётчика Секунд" -> N
		; коррекция: пропуск Секунд, если надо
		BRTS	SecondsParameterHaveFixed__SWITCH_MODE_SETTINGS		; Если, для этой Функции, требуется настраивать все три показателя (T==1), то пропускаем коррекцию...
		BRPL	SecondsParameterHaveFixed__SWITCH_MODE_SETTINGS		; Если текущий Параметр, на который переключились - это ещё не Секунды (N==0), то пропускаем коррекцию...
		LSL	temp1							; коррекция: ещё раз переключить текущий параметр, чтобы пропустить: Секунды -> C
	SecondsParameterHaveFixed__SWITCH_MODE_SETTINGS:
		; зациклить сдвиг: C -> Часы
		BRCC	NoCarryYet__SWITCH_MODE_SETTINGS
		ORI	temp1,	1<<SETTING_HOURS
	NoCarryYet__SWITCH_MODE_SETTINGS:
		STS	DSettings_Mode,	temp1					; сохранить модифицированный байт, параметризующий текущий подрежим режима "Настройки"
		
		SET								; T=1 (выходной параметр процедуры)
		RJMP	Exit__SWITCH_MODE_SETTINGS
	EndNextParameter__SWITCH_MODE_SETTINGS:



		;** Выход из "режима Настройки"
		IF_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_ShortHold
		AND_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortHold
		OR_BUTTON_HAVE_STATUS	DButtonSetStatus,	BSC_LongHold
		BRTC	EndSettingsMode__SWITCH_MODE_SETTINGS			; если кнопки не были нажаты...
		OUTI	DButtonSetStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.
		OUTI	DButtonStartStatus,	0b11111111
		CLRB	DMain_Mode,	MODE_SETTINGS				; Прикладная реакция: выйти из "режима настройки".
		RCALL	KEY_RESET_STATUS_FOR_ALL_BUTTONS			; (обнулить события всех Кнопок, при переходе в другую Подсистему интерфейса)
		
		; Для Функции "RTC": вновь запустить ход Часов (который был приостановлен, для синхронизации, при входе в "режим Настройки")
		IF_CURRENT_FUNCTION	FunctionRTC
		BRNE	EndControlRTC__SWITCH_MODE_SETTINGS
		SETB	DClock_Mode,	MODE_ENABLED				; Прикладная реакция: запустить ход часов.
	EndControlRTC__SWITCH_MODE_SETTINGS:

		; Для Функции "ALARM": сохранить настройки будильника в EEPROM (DAlarm -> EAlarm)
		IF_CURRENT_FUNCTION	FunctionALARM
		BRNE	EndControlAlarm__SWITCH_MODE_SETTINGS
		LDI	EepromAddressLow,	Low(EAlarm_SavedSettings)		; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	EepromAddressHigh,	High(EAlarm_SavedSettings)		; 
		LDI	SramAddressLow,		Low(DAlarm_Mode)			; (примечание: здесь загружаем в регистр адрес, а не значение)
		LDI	SramAddressHigh,	High(DAlarm_Mode)			; 
		LDI	PumpBytesCount,		EAlarm_size				; количество данных (в байтах)
		CLI									; запрещаем прерывания	(!не используйте внутри обработчика прерывания!)
		RCALL	EEPROM_WRITE_SEQUENCE
		SEI 									; разрешаем прерывания	(!не используйте внутри обработчика прерывания!)
	EndControlAlarm__SWITCH_MODE_SETTINGS:
		
		SET								; T=1 (выходной параметр процедуры)
		RJMP	Exit__SWITCH_MODE_SETTINGS
	EndSettingsMode__SWITCH_MODE_SETTINGS:



		;** Модификация значения текущего Параметра

		; ИНИЦИАЛИЗАЦИЯ: определить текущий Параметр, который настраивается?
		MOVW	ExtendTimeInAddressHigh:ExtendTimeInAddressLow,	YH:YL	; (подготовим параметр процедуры: адрес ячейки, которая модифицируется)
		LDI	ZL,	Low (IndexTable__CALL_MOD_TIME)			; (подготовим точку входа в процедуру: пока только из первой половины индексной таблицы INC_TIME_* - потом внесём коррекцию, если нужно)
		LDI	ZH,	High(IndexTable__CALL_MOD_TIME)

		LDS	temp1,	DSettings_Mode					; загрузить байт, параметризующий текущий подрежим режима "Настройки"
		LD	temp2,	X+						; коррекция: увеличиваем значение указателя +1
		LSL	temp1
		BRCS	EndSelectParameter__SWITCH_MODE_SETTINGS		; если Секунды...
		LD	temp2,	X+						; коррекция: увеличиваем значение указателя +1
		LD	temp2,	Z+						; коррекция: увеличиваем значение указателя +1
		LSL	temp1
		BRCS	EndSelectParameter__SWITCH_MODE_SETTINGS		; если Минуты...
		LD	temp2,	X+						; коррекция: увеличиваем значение указателя +1
		LD	temp2,	Z+						; коррекция: увеличиваем значение указателя +1
		LSL	temp1
		;BRCS	EndSelectParameter__SWITCH_MODE_SETTINGS		; если Часы...
	EndSelectParameter__SWITCH_MODE_SETTINGS:



		; ОБРАБОТКА СОБЫТИЙ ВВОДА: определиться на сколько единиц модифицируем?

		; Обработка ввода Энкодером
		LDS	ExtendTimeByValue,	DEncoder0Counter
		TST	ExtendTimeByValue
		BREQ	NotEncoder__SWITCH_MODE_SETTINGS
		OUTI	DEncoder0Counter,	0				; замечу: после прибавления к "счётчику времени" этой аддитивной добавки, регистр "счётчика тиков" энкодера обнуляется.
		RJMP	ModifyTime__SWITCH_MODE_SETTINGS
	NotEncoder__SWITCH_MODE_SETTINGS:


		; Обработка ввода Кнопкой
		; (однократное нажатие)
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_ShortPress
		BRTC	Button2__SWITCH_MODE_SETTINGS				; если кнопки не были нажаты...
		OUTI	DButtonStartStatus,	0b11111111			; После обработки состояния кнопки - сделать "ОТЛОЖЕННЫЙ СБРОС" её статусного регистра.
		LDI	ExtendTimeByValue,	1
		RJMP	ModifyTime__SWITCH_MODE_SETTINGS
		; (инерционный ввод, при удержании)
	Button2__SWITCH_MODE_SETTINGS:
		IF_BUTTON_HAVE_STATUS	DButtonStartStatus,	BSC_LongHold
		BRTC	NotButton__SWITCH_MODE_SETTINGS				; если кнопки не были нажаты...
		;OUTI	DButtonStartStatus,	0b11111111			; Внимание: в этом случае, статус кнопки не сбрасываем - пусть продолжает считаться "нажатой" и набегает "таймер удержания"...
		LDI	ExtendTimeByValue,	1
		; (хочу различать также ситуации "очень длительных" удерживаний кнопки)
		LDS	temp1,	DButtonStartStatus
		ANDI	temp1,	0b11111<<BUTTON_HOLDING_TIME			; выделить "счётчик времени удержания кнопки"
		CPI	temp1,	8						; при удержании кнопки свыше >=4сек, показания набегают в 2 раза бытрее.
		BRLO	SlowSpeedYet__SWITCH_MODE_SETTINGS
		LSL	ExtendTimeByValue
		CPI	temp1,	16						; при удержании кнопки свыше >=8сек, показания набегают ещё в 2 раза бытрее.
		BRLO	SlowSpeedYet__SWITCH_MODE_SETTINGS
		LSL	ExtendTimeByValue
	SlowSpeedYet__SWITCH_MODE_SETTINGS:
		RJMP	ModifyTime__SWITCH_MODE_SETTINGS
	NotButton__SWITCH_MODE_SETTINGS:
		RJMP	NoEvent__SWITCH_MODE_SETTINGS



		; МОДИФИКАЦИЯ: готовим параметры и вызываем процедуру модификации "счётчика времени"
	ModifyTime__SWITCH_MODE_SETTINGS:
		; коррекция: определиться как (+/-) модифицируем?
		TST	ExtendTimeByValue
		BRPL	SkipCorrectionWhenIncrementation__SWITCH_MODE_SETTINGS
		NEG	ExtendTimeByValue					; константу прироста инвертируем (получаем абсолютное значение)
		LDI	temp1,	3						; увеличиваем значение указателя на точку входа на +3 слова	(для перехода во вторую половину индексной таблицы)
		CLR	temp2
		ADD	ZL,	temp1						; Z += temp1
		ADC	ZH,	temp2
	SkipCorrectionWhenIncrementation__SWITCH_MODE_SETTINGS:
		; Примечание: Вызов процедуры реализован на "индексных переходах" - см. объяснение в "AVR. Учебный курс. Ветвления на индексных переходах" (с) http://easyelectronics.ru/avr-uchebnyj-kurs-vetvleniya.html
		LSL	ZL							; (Примечание: Адреса меток из CSEG выражены в Словах, поэтому их нужно увеличить в 2 раза, чтобы можно было использовать в инструкциях LPM/SPM...)
		ROL	ZH
		LPM	temp1,	Z+						; загрузить адрес перехода из индексной таблицы -> [temp2:temp1]
		LPM	temp2,	Z
		MOVW	ZH:ZL,	temp2:temp1					; забросить адрес перехода на прикладную функцию -> в Z 	(Примечание: поскольку для переходов IJMP/ICALL используется Адрес выраженный в Словах - то его предварительно НЕ увеличиваем в 2 раза, оставляем таким как был загружен из таблицы...)
		SET								; T=1 (параметр: запрещает перенос/заём из старшего разряда)
		ICALL								; переход на заданную "индексной таблицей" метку

		SET								; T=1 (выходной параметр процедуры)
		RJMP	Exit__SWITCH_MODE_SETTINGS



	NoEvent__SWITCH_MODE_SETTINGS:
		CLT								; T=0 (выходной параметр процедуры)
	Exit__SWITCH_MODE_SETTINGS:
		RET




;***** END Procedures section 
; coded by (c) Celeron, 2013 @ http://we.easyelectronics.ru/my/Celeron/
