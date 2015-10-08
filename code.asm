org 0000h
LJMP main
org 0030h
main:
SDAPin bit P0.0 ; I2C serial data line.
SCLPin P0.1 ;I2C serial clock line.
bit
mode bit P0.2
; mode switch is for selecting brightness/contrast.
down bit P0.3 up bit P0.4 ; increasing brightness/contrast.
0Ah ;Bit counter for I2C routines.
BitCnt data
ByteCnt data
SlvAdr data
; decreasing brightness/contrast.
0Bh
;Byte counter for I2C routines.
0Ch
;Slave address for I2C routines.
Moff_adr data
Moff_val
;local brightness memory locations.
data 0Eh
Mgain_adr data 0Fh
;local contrast memory locations.
Mgain_val data 10h
MOV Moff_adr, #08h
;storing default values in assigned locations
MOV Moff_val, #39h
MOV Mgain_adr, #07h
MOV Mgain_val, # 81h
MOV SlvAdr, #52h
I2CFlags
data
NoAck
;slave address
22h ;Location for bit flags( Status flags to check i2c routine).
bit
I2CFlags.0
;I2C no acknowledge flag.
BusFault bit I2CFlags.1 ;I2C bus fault flag.
I2CBusy bit I2CFlags.2 ;I2C busy flag.look1: DB 07H, 81H, 08H, 39H, 09H, 4AH, 0AH, 10H, 0BH, 00H, 0CH, 02H, 0DH, 00H,
0EH, 80H, 0FH, 0AEH, 10H, 13H, 11H, 07H, 12H, 00H, 13H, 90H, 14H, 0FH, 15H, 0D8H,
16H, 0CH, 17H, 71H, 18H, 80H, 19H, 00H, 1AH ,08H
look2: DB 07H, 81H, 08H, 39H
SETB SCLPin
; making scl,sda high as default
SETB SDAPin
SETB up
SETB down
LCALL oled_initial
MOV R2, #5 ;counter for brightness
MOV R3, #5 ; counter for contrast
here: JNB mode, loop1
loop2: JNB up, contrast_inc
JNB down , contrast_dec
JMP here
contrast_inc: JNB down, here
CJNE R3, #16, here_c_1
JMP here
here_c_1: MOV A, Mgain_val
; already saved value in reg
ADD A, #16
MOV Mgain_val, A
;save current value
INC R3
send_new_c_1: MOV R0, #Mgain_adr ; start of data to be send along with subaddress
MOV ByteCnt, #2
CALL SendData
JMP here
contrast_dec: CJNE R3, #00, here_c_2JMP here
here_c_2: CLR C
MOV A, Mgain_val
SUBB A, #16
MOV Mgain_val, A
DEC R3
send_new_c_2: MOV R0, #Mgain_adr ; start of data to be send along with subaddress
MOV ByteCnt, #2
CALL SendData
JMP here
loop1: JNB up, bright_inc
JNB down, bright_dec
reset:
MOV R0,#look2 ; resetting the oled brightness and contrast register values
MOV ByteCnt, #4
CALL SendData
JMP here
bright_inc: JNB down, here
CJNE R2, #17, here_1
JMP here
here_1: MOV A, Moff_val
; already saved value in reg
ADD A, #8
MOV Moff_val, A
;save current value
INC R2
send_new_b_1:
MOV R0, #Moff_adr ; start of data to be send along with subaddress
MOV ByteCnt, #2
CALL SendData
JMP herebright_dec:
CJNE R2, #00, here_2
JMP here
here_2:
CLR C
MOV A, Moff_val
SUBB A, #8
MOV Moff_val, A
DEC R2
send_new_b_2:
MOV R0,#Moff_adr ; start of data to be send along with subaddress
MOV ByteCnt, #2
CALL SendData
JMP here
JMP finish
;-------------------------------------------------------------
; I2C Routines
;-------------------------------------------------------------
;
; BitDly - insures minimum high and low clock times on I2C bus.
; This routine must be tuned for the actual oscillator frequency used, shown
; here tuned for a 12MHz clock. Note that the CALL instruction that invokes
; BitDly already uses 2 machine cycles.
org 0400h
BitDly:
NOP
;NOPs to delay 5 microseconds (minus 4
; machine cycles for CALL and RET).
RET
; SCLHigh - sends SCL pin high and waits for any clock stretching peripherals.
org 0410h
SCLHigh:
SETB
JNB
SCLPin
SCLPin, $
;Set SCL from our end.
;Wait for pin to actually go high.RET
; SendStop - sends an I2C stop, releasing the bus.
org 0430h
SendStop:
CLR SDAPin ;Get SDA ready for stop.
CALL SCLHigh ;Set clock for stop.
CALL BitDly SETB SDAPin CALL BitDly CLR I2CBusy
RET
;Send I2C stop.
;Clear I2C busy status.
;Bus should now be released.
; SendByte - sends one byte of data to an I2C slave device.
; Enter with:
;
ACC = data byte to be sent.
org 0300h
SendByte: MOV BitCnt, #8 SBLoop: A ;Send one data bit.
MOV SDAPin, C ;Put data bit on pin.
CALL SCLHigh ;Send clock.
CALL BitDly CLR SCLPin CALL BitDly DJNZ BitCnt, SBloop SETB SDAPin ;Release data line for acknowledge.
CALL SCLHigh ;Send clock for acknowledge.
CALL BitDly JNB SDAPin, SBEX ;Check for valid acknowledge bit.
NoAck ;Set status for no acknowledge.
RLC
SETB
SBEX:
CLR
CALL
SCLPin
BitDly
;Set bit count.
;Repeat until all bits sent.
;Finish acknowledge bit.RET
; GoMaster - sends an I2C start and slave address.
; Enter with:
;
SlvAdr = slave address.
org 0200h
GoMaster:
SETB
I2CBusy
;Indicate that I2C frame is in progress.
CLR NoAck
;Clear error status flags.
CLR BusFault
JNB SCLPin, Fault
JNB SDAPin, Fault
;Check for bus clear.
CLR SDAPin
;Begin I2C start.
CALL BitDly CLR SCLPin CALL BitDly ;Complete I2C start.
MOV A, SlvAdr ;Get slave address.
CALL SendByte
;Send slave address.
RET
Fault:
SETB
BusFault
RET
;Set fault status
; and exit.
; SendData - sends one or more bytes of data to an I2C slave device.
; Enter with:
; ByteCnt = count of bytes to be sent.
; SlvAdr = slave address.
; @R0
;
= data to be sent (the first data byte will be the
subaddress, if the I2C device expects one).
org 0130h
SendData: CALL
JB
SDLoop:
GoMaster
NoAck,SDEX
;Acquire bus and send slave address.
;Check for slave not responding.
MOV A, @R0 CALL SendByte ;Send next data byte.
INC R0 ;Advance buffer pointer.
JB
NoAck, SDEX
;Get data byte from buffer.
;Check for slave not responding.DJNZ
SDEX:
CALL
ByteCnt, SDLoop ;All bytes sent?
SendStop
;Done, send an I2C stop.
RET
org 0100h
oled_initial:
MOV
SlvAdr , #052
; arbitary address
MOV R0,#look1 ; start of data to be send along with subaddresses
MOV ByteCnt, #40
CALL SendData
RET
finish:
END
