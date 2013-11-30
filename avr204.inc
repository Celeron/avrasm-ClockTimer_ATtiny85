;**** A P P L I C A T I O N   N O T E   A V R 2 0 4 ************************
;* Atmel Corporation
;*
;* Title:		BCD Arithmetics
;* Version:		1.4
;* Last updated:	2004.02.02
;* Target:		AT90Sxxxx (All AVR Devices)
;*
;* Support E-mail:	avr@atmel.com
;*
;* DESCRIPTION
;* This Application Note lists subroutines for the following Binary Coded
;* Decimal arithmetic applications:
;*
;* Binary 16 to BCD Conversion (special considerations for AT90Sxx0x)
;* Binary 8 to BCD Conversion
;* BCD to Binary 16 Conversion
;* BCD to Binary 8 Conversion
;* 2-Digit BCD Addition
;* 2-Digit BCD Subtraction
;*
;* VERSION HISTORY
;* 1.1 Original version
;* 1.2 Fixed error in BCDADD routine	see http://www.ustr.net/avrfiles/avr204f.htm 
;* 1.3 Fixed error in BCD2BIN8 routine (packed version)
;* 1.4 Fixed missing Carrige Returns for windows
;***************************************************************************

;.include "..\8515def.inc"
;	rjmp	RESET	;reset handle


/*
;***************************************************************************
;*
;* "bin2BCD16" - 16-bit Binary to BCD conversion
;*
;* This subroutine converts a 16-bit number (fbinH:fbinL) to a 5-digit
;* packed BCD number represented by 3 bytes (tBCD2:tBCD1:tBCD0).
;* MSD of the 5-digit number is placed in the lowermost nibble of tBCD2.
;*
;* Number of words	:25
;* Number of cycles	:751/768 (Min/Max)
;* Low registers used	:3 (tBCD0,tBCD1,tBCD2)
;* High registers used  :4(fbinL,fbinH,cnt16a,tmp16a)	
;* Pointers used	:Z
;*
;***************************************************************************

;***** Subroutine Register Variables

.equ	AtBCD0	=13		;address of tBCD0
.equ	AtBCD2	=15		;address of tBCD1

.def	tBCD0	=r13	;BCD value digits 1 and 0
.def	tBCD1	=r14	;BCD value digits 3 and 2
.def	tBCD2	=r15	;BCD value digit 4
.def	fbinL	=r16	;binary value Low byte
.def	fbinH	=r17	;binary value High byte
.def	cnt16a	=r18	;loop counter
.def	tmp16a	=r19	;temporary value

;***** Code

bin2BCD16:
	ldi	cnt16a,16	;Init loop counter	
	clr	tBCD2		;clear result (3 bytes)
	clr	tBCD1		
	clr	tBCD0		
	clr	ZH			;clear ZH (not needed for AT90Sxx0x)
bBCDx_1:lsl	fbinL	;shift input value
	rol	fbinH		;through all bytes
	rol	tBCD0		;
	rol	tBCD1
	rol	tBCD2
	dec	cnt16a		;decrement loop counter
	brne	bBCDx_2	;if counter not zero
	ret				;   return

bBCDx_2:ldi	r30,AtBCD2+1	;Z points to result MSB + 1
bBCDx_3:
	ld	tmp16a,-Z	;get (Z) with pre-decrement
;----------------------------------------------------------------
;For AT90Sxx0x, substitute the above line with:
;
;	dec	ZL
;	ld	tmp16a,Z
;
;----------------------------------------------------------------
	subi	tmp16a,-$03	;add 0x03
	sbrc	tmp16a,3	;if bit 3 not clear
	st	Z,tmp16a		;	store back
	ld	tmp16a,Z		;get (Z)
	subi	tmp16a,-$30	;add 0x30
	sbrc	tmp16a,7	;if bit 7 not clear
	st	Z,tmp16a		;	store back
	cpi	ZL,AtBCD0		;done all three?
	brne	bBCDx_3		;loop again if not
	rjmp	bBCDx_1		
*/


;***************************************************************************
;*
;* "bin2BCD8" - 8-bit Binary to BCD conversion
;*
;* This subroutine converts an 8-bit number (fbin) to a 2-digit
;* BCD number (tBCDH:tBCDL).
;*
;* Number of words	:6 + return
;* Number of cycles	:5/50 (Min/Max) + return
;* Low registers used	:None
;* High registers used  :2 (fbin/tBCDL,tBCDH)
;*
;* Included in the code are lines to add/replace for packed BCD output.	
;*
;***************************************************************************

;***** Subroutine Register Variables

.def	fbin	=r16		;8-bit binary value
.def	tBCDL	=r16		;BCD result LSD
.def	tBCDH	=r17		;BCD result MSD

;***** Code

bin2bcd8:
	clr	tBCDH		;clear result MSD
bBCD8_1:
	subi	fbin,10		;input = input - 10
	brcs	bBCD8_2		;abort if carry set
	inc	tBCDH		;inc MSD
;---------------------------------------------------------------------------
;				;Replace the above line with this one
;				;for packed BCD output				
;	subi	tBCDH,-$10 	;tBCDH = tBCDH + 10
;---------------------------------------------------------------------------
	rjmp	bBCD8_1		;loop again
bBCD8_2:
	subi	fbin,-10	;compensate extra subtraction
;---------------------------------------------------------------------------
;				;Add this line for packed BCD output
;	add	fbin,tBCDH	
;---------------------------------------------------------------------------	
	ret


/*
;***************************************************************************
;*
;* "BCD2bin16" - BCD to 16-Bit Binary Conversion
;*
;* This subroutine converts a 5-digit packed BCD number represented by
;* 3 bytes (fBCD2:fBCD1:fBCD0) to a 16-bit number (tbinH:tbinL).
;* MSD of the 5-digit number must be placed in the lowermost nibble of fBCD2.
;*
;* Let "abcde" denote the 5-digit number. The conversion is done by
;* computing the formula: 10(10(10(10a+b)+c)+d)+e.
;* The subroutine "mul10a"/"mul10b" does the multiply-and-add operation
;* which is repeated four times during the computation.
;*
;* Number of words	:30
;* Number of cycles	:108
;* Low registers used	:4 (copyL,copyH,mp10L/tbinL,mp10H/tbinH)
;* High registers used  :4 (fBCD0,fBCD1,fBCD2,adder)	
;*
;***************************************************************************

;***** "mul10a"/"mul10b" Subroutine Register Variables

.def	copyL	=r12		;temporary register
.def	copyH	=r13		;temporary register
.def	mp10L	=r14		;Low byte of number to be multiplied by 10
.def	mp10H	=r15		;High byte of number to be multiplied by 10
.def	adder	=r19		;value to add after multiplication	

;***** Code

mul10a:	;***** multiplies "mp10H:mp10L" with 10 and adds "adder" high nibble
	swap	adder
mul10b:	;***** multiplies "mp10H:mp10L" with 10 and adds "adder" low nibble
	mov	copyL,mp10L	;make copy
	mov	copyH,mp10H
	lsl	mp10L		;multiply original by 2
	rol	mp10H
	lsl	copyL		;multiply copy by 2
	rol	copyH		
	lsl	copyL		;multiply copy by 2 (4)
	rol	copyH		
	lsl	copyL		;multiply copy by 2 (8)
	rol	copyH		
	add	mp10L,copyL	;add copy to original
	adc	mp10H,copyH	
	andi	adder,0x0f	;mask away upper nibble of adder
	add	mp10L,adder	;add lower nibble of adder
	brcc	m10_1		;if carry not cleared
	inc	mp10H		;	inc high byte
m10_1:	ret	

;***** Main Routine Register Variables

.def	tbinL	=r14		;Low byte of binary result (same as mp10L)
.def	tbinH	=r15		;High byte of binary result (same as mp10H)
.def	fBCD0	=r16		;BCD value digits 1 and 0
.def	fBCD1	=r17		;BCD value digits 2 and 3
.def	fBCD2	=r18		;BCD value digit 5

;***** Code

BCD2bin16:
	andi	fBCD2,0x0f	;mask away upper nibble of fBCD2
	clr	mp10H		
	mov	mp10L,fBCD2	;mp10H:mp10L = a
	mov	adder,fBCD1
	rcall	mul10a		;mp10H:mp10L = 10a+b
	mov	adder,fBCD1
	rcall	mul10b		;mp10H:mp10L = 10(10a+b)+c
	mov	adder,fBCD0		
	rcall	mul10a		;mp10H:mp10L = 10(10(10a+b)+c)+d
	mov	adder,fBCD0
	rcall	mul10b		;mp10H:mp10L = 10(10(10(10a+b)+c)+d)+e
	ret
*/


/*
;***************************************************************************
;*
;* "BCD2bin8" - BCD to 8-bit binary conversion
;*
;* This subroutine converts a 2-digit BCD number (fBCDH:fBCDL) to an
;* 8-bit number (tbin).
;*
;* Number of words	:4 + return
;* Number of cycles	:3/48 (Min/Max) + return
;* Low registers used	:None
;* High registers used  :2 (tbin/fBCDL,fBCDH)	
;*
;* Modifications to make the routine accept a packed BCD number is indicated
;* as comments in the code. If the modifications are used, fBCDH shall be
;* loaded with the BCD number to convert prior to calling the routine.
;*
;***************************************************************************

;***** Subroutine Register Variables

.def	tbin	=r16		;binary result
.def	fBCDL	=r16		;lower digit of BCD input
.def	fBCDH	=r17		;higher digit of BCD input

;***** Code

BCD2bin8:
;--------------------------------------------------------------------------
;|				;For packed BCD input, add these two lines
;|	mov	tbin,fBCDH	;copy input to result
;|	andi	tbin,$0f	;clear higher nibble of result
;--------------------------------------------------------------------------

BCDb8_0:
	subi	fBCDH,1		;fBCDH = fBCDH - 1
;--------------------------------------------------------------------------
;|				;For packed BCD input, replace the above
;|				;line with this
;|	subi	fBCDH,$10	;MSD = MSD - 1
;--------------------------------------------------------------------------

	brcs	BCDb8_1		;if carry not set

	subi	tbin,-10	;    result = result + 10
	rjmp	BCDb8_0		;    loop again
BCDb8_1:
	ret			;else return
*/


/*
;***************************************************************************
;*
;* "BCDadd" - 2-digit packed BCD addition
;*
;* This subroutine adds the two unsigned 2-digit BCD numbers
;* "BCD1" and "BCD2". The result is returned in "BCD1", and the overflow
;* carry in "BCD2".
;*
;* Number of words	:21
;* Number of cycles	:23/25 (Min/Max)
;* Low registers used	:None
;* High registers used  :3 (BCD1,BCD2,tmpadd)	
;*
;***************************************************************************

;***** Subroutine Register Variables

.def	BCD1	=r16		;BCD input value #1
.def	BCD2	=r17		;BCD input value #2
.def	tmpadd	=r18		;temporary register

;***** Code

BCDadd:
	ldi	tmpadd,6	;value to be added later
	add	BCD1,BCD2	;add the numbers binary
	clr	BCD2		;clear BCD carry
	brcc	add_0		;if carry not clear
	ldi	BCD2,1		;    set BCD carry
add_0:	brhs	add_1		;if half carry not set
	add	BCD1,tmpadd	;    add 6 to LSD
	brhs	add_2		;    if half carry not set (LSD <= 9)
	subi	BCD1,6		;        restore value
	rjmp	add_2		;else
add_1:	add	BCD1,tmpadd	;    add 6 to LSD
add_2:	brcc	add_2a
	ldi	BCD2,1	
add_2a:	swap	tmpadd
	add	BCD1,tmpadd	;add 6 to MSD
	brcs	add_4		;if carry not set (MSD <= 9)
	sbrs	BCD2,0		;    if previous carry not set
	subi	BCD1,$60	;	restore value
add_3:	ret			;else
add_4:	ldi	BCD2,1		;    set BCD carry
	ret

;***************************************************************************
;*
;* "BCDsub" - 2-digit packed BCD subtraction
;*
;* This subroutine subtracts the two unsigned 2-digit BCD numbers
;* "BCDa" and "BCDb" (BCDa - BCDb). The result is returned in "BCDa", and
;* the underflow carry in "BCDb".
;*
;* Number of words	:13
;* Number of cycles	:12/17 (Min/Max)
;* Low registers used	:None
;* High registers used  :2 (BCDa,BCDb)	
;*
;***************************************************************************

;***** Subroutine Register Variables

.def	BCDa	=r16		;BCD input value #1
.def	BCDb	=r17		;BCD input value #2

;***** Code

BCDsub:
	sub	BCDa,BCDb	;subtract the numbers binary
	clr	BCDb
	brcc	sub_0		;if carry not clear
	ldi	BCDb,1		;    store carry in BCDB1, bit 0
sub_0:	brhc	sub_1		;if half carry not clear
	subi	BCDa,$06	;    LSD = LSD - 6
sub_1:	sbrs	BCDb,0		;if previous carry not set
	ret			;    return
	subi	BCDa,$60	;subtract 6 from MSD
	ldi	BCDb,1		;set underflow carry
	brcc	sub_2		;if carry not clear
	ldi	BCDb,1		;    clear underflow carry	
sub_2:	ret			
*/


/*
;****************************************************************************
;*
;* Test Program
;*
;* This program calls all the subroutines as an example of usage and to
;* verify correct operation.
;*
;****************************************************************************

;***** Main Program Register variables

.def	temp	=r16		;temporary storage variable

;***** Code

RESET:
	ldi	temp,low(RAMEND)
	out	SPL,temp
	ldi	temp,high(RAMEND)
	out	SPH,temp	;init Stack Pointer (remove for AT90Sxx0x)

;***** Convert 54,321 to 2.5-byte packed BCD format

	ldi	fbinL,low(54321)
	ldi	fbinH,high(54321)
	rcall	bin2BCD16	;result: tBCD2:tBCD1:tBCD0 = $054321

;***** Convert 55 to 2-byte BCD

	ldi	fbin,55
	rcall	bin2BCD8	;result: tBCDH:tBCDL = 0505

;***** Convert $065535 to a 16-bit binary number
	ldi	fBCD2,$06
	ldi	fBCD1,$55
	ldi	fBCD0,$35
	rcall	BCD2bin16	;result: tbinH:tbinL = $ffff (65,535)

;***** Convert $0403 (43) to an 8-bit binary number
	ldi	fBCDL,3
	ldi	fBCDH,4
	rcall	BCD2bin8	;result: tbin = $2b (43)

;***** Add BCD numbers 51 and 79

	ldi	r20,$00
	ldi	r21,$00
l1:	mov	BCD1,r20
	mov	BCD2,r21
	rcall	BCDadd		;result: BCD2:BCD1=$0130
	inc 	r20
	inc 	r21
	brcc	l1

;***** Subtract BCD numbers 72 - 28
	ldi	BCDa,$72
	ldi	BCDb,$28
	rcall	BCDsub		;result: BCDb=$00 (positive result), BCDa=44

;***** Subtract BCD numbers 0 - 90
	ldi	BCDa,$00
	ldi	BCDb,$90
	rcall	BCDsub		;result: BCDb=$01 (negative result), BCDa=10	



forever:rjmp	forever
*/
