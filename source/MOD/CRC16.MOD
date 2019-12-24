IMPLEMENTATION MODULE CRC16;
(*
        MODIFICATION History -

        30-Nov-89 KKC Initialize return value to 0

*)

FROM SYSTEM IMPORT ADDRESS, CODE, GETREG, SETREG, BX; 



(*
        ; Code to checksum an area of memory.  Basic algorithm taken
        ; from a letter by George Dinwiddie of Columbia MD to PC Tech
        ; Journal, July 1985, page 16.
        ;
        ; Registers AX,BX,CX,DX and ES are altered.
        ;
        ; Andrew Layman, July 29, 1985
        ;
CODE    SEGMENT PARA 'code'
        ASSUME  CS:CODE
        ;  Assume that the byte array to be checksummed is pointed
        ;  to by an address located at [BP+8] (double word) and that
        ;  the count of bytes to be summed is at [BP+6].  Further
        ;  assume that the array does not cross a segment boundary.
        MOV     AX,0            ; Initislize return value to 0
        MOV     BX,0            ; initialize BX (sum) to 0
        LES     DI,DWORD PTR [BP+08]    ; ES:DI <-- Addr(Area to sum)
        MOV     DX,[BP+6]       ; DX <-- Count
        OR      DX,DX           ; Abort if count = 0.
        JZ      OUT
NEXT:   MOV     AL,ES:[DI]      ; AL <-- Next character to sum
    ; Compute checksum.  BX has sum so far, AL has next char.
    ; This is Mr. Dinwiddie's algorithm.
CRC16:  XOR     AX,BX           ; AL contains (X7-0 xor Y7-0)
        XOR     AH,AH           ; clear AH
        MOV     CL,8
        SHR     BX,CL           ; BL contains (X15-8), Clear BH
        OR      AX,AX           ; Set parity flag
        JPE     CRC16X          ; If (X7-0 xor Y7-0) has odd parity
        XOR     BX,0C001H       ; then adjust crc bits 15, 14, and 0
CRC16X: MOV     CL,6
        ROL     AX,CL
        XOR     BX,AX
        ROL     AX,1
        XOR     BX,AX
    ; BX now has new checksum.
    ; Prepare for next character.
        INC     DI              ; Ready to point to next character
        DEC     DX              ; Decrease count to go
        JNZ     NEXT            ; Loop back if > 0
OUT:    NOP
CODE    ENDS
*)


    (* CheckSum -- Compute a checksum of "Size" bytes beginning
                   at address "A".   *)

PROCEDURE CheckSum (     A    : ADDRESS;
                         Size : CARDINAL  ) : CARDINAL;
VAR
    Sum : CARDINAL;
BEGIN
    CODE(  
           0B8H, 00H, 00H,
           0BBH, 00H, 00H,
           0C4H, 7EH, 08H,
           08BH, 56H, 06H,
           00BH, 0D2H,
           074H, 21H,
           026H,
           08AH, 05H,
           033H, 0C3H,
           032H, 0E4H,
           0B1H, 08H,
           0D3H, 0EBH,
           00BH, 0C0H,
           07AH, 04H,
           081H, 0F3H, 01H, 0C0H,
           0B1H, 06H,
           0D3H, 0C0H,
           033H, 0D8H,
           0D1H, 0C0H,
           033H, 0D8H,
           047H,
           04AH,
           075H, 0DFH   );
    GETREG(BX,Sum); 
    RETURN Sum;
END CheckSum;





BEGIN
END CRC16.
