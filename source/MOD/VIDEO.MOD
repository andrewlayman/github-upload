(*V1=OS2 OS2 code changes.    *)
(*V2=DOS Regular DOS TL code. *)

(*----------------------------------------------------------------------------
    UPDATE HISTORY
    
    07/21/86 LAA    Saved and restore the cursor type along with the cursor
                    position in PutStringWithAttributeClean in order to 
                    prevent the cursor showing up when this was used.
    6/15/87  AJL    Changed the scan lines used when disabling the cursor
                    to make it work on the IBM PS/2 mod 30.
    7/16/87  AJL    PutAttribute (fast and clean) works.
    24-Sep-87 LAA   Imported register names from SYSTEM instead of System 
                    for Logitech Version 3 compiler.
    16-Dec-87 LAA   Created local variables for use by GETREG and SETREG.
                    This is required by version 3.0 of Logitech compiler.
    18-Aug-88 AJL   Incorporated a BIOS call to enable or disable blinking.
    19-Apr-89 WKH   Stop calls to StopBlinking every time we reset cursor.  Was
                    causing annoying screen flashes on VGA displays.
    29-May-89 WKH   Implemented the ResetVideo proc
    10-Jun-89 WKH   Added support for varible screen rows
    12-Jun-89 WKH   Added QueryAdapterType routine.
                    Also added PrepareVideoForExit.
    13-Jun-89 WKH   Added CheckForCompressedMode routine.
    13-Jun-89 WKH   Moved CheckForCompressedMode and PrepareVideoForExit from
                    here to KBIO
    05-Aug-89 WKH   Initial edits for OS/2.  Mapped video routines to 
                    corresponding OS/2 API routines.
----------------------------------------------------------------------------*)

IMPLEMENTATION MODULE Video;


(*<DOS*)
FROM SYSTEM IMPORT WORD, CODE, ADDRESS, ADR, GETREG, SETREG, SWI, AX, BX, CX, 
                   DX, ES, BYTE;
(*DOS>*)


(*<OS2
FROM SYSTEM IMPORT WORD, ADDRESS, ADR, SIZE, TSIZE;

IMPORT VideoIO;

FROM VideoIO                IMPORT
                                VioReadCellStr,
                                VioWrtCellStr,
                                VioWrtCharStrAtt,
                                VioWrtNAttr,
                                VioGetCurPos,
                                VioSetCurPos,
                                DisplayAttributeSet,
                                BlueFG, 
                                GreenFG, 
                                RedFG,
                                VioGetCurType, 
                                VioSetCurType, 
                                CursorType,
                                VioGetMode, 
                                ModeDataType,
                                VioGetConfig,
                                ConfigData,
                                MonoPrtAdap,
                                EGA,
                                VGAIBMPS2DA,
                                IBMPS28514A,
                                MonoPrtDisp,
                                ColorDisp,
                                EnhColorDisp,
                                IBMPS2MD8503,
                                IBMPS2CD8512x13,
                                IBMPS2CD8514;

FROM Misc                   IMPORT
                                DosBeep;
OS2>*)

CONST
    BlinkOn     = 1;
    BlinkOff    = 0;
    maxcol      = 79;
    ScreenWidth = 80;    (* Physical offset in words from one line to next. *)


(*$S-*)  (* No stack check. *)
(*$R-*)  (* No range check. *)
(*$T-*)  (* No pointer? check. *)


    (* WARNING -- These routines all assume that VideoAddress.OFFSET = 0. *)



CONST
    BIOSSetCursorType        =  0100H;
    BIOSSetCursorPosition    =  0200H;
    BIOSGetCursorPosition    =  0300H;
    BIOSVideoInterrupt       =  10H;

VAR
    Reprogrammed6845        : BOOLEAN;
    CurrentCursorType       : CARDINAL;

(*<OS2
    err                     : CARDINAL;

    trick                   : RECORD
	                            CASE Dummy : INTEGER OF
		                            0: AttrView   : ARRAY [0..1] OF DisplayAttributeSet;
		                        |   1: BitSetView : BITSET;
	                            END;
	                          END;

    ScreenMode              : ModeDataType;
    PermCursorState         : CursorType;
OS2>*)



(*<DOS*)
PROCEDURE GetImageLineFast(x:CARDINAL; y:CARDINAL; Count:CARDINAL;
                           Line : ADDRESS);
VAR
    m, yx, i, len : CARDINAL;

BEGIN
    len := Count;
    IF (len = 0) THEN RETURN; END;

    yx := ((ScreenWidth*y) + x) * 2;           (*  Offset on screen. *)


        (* AX <- Screen segment, DX <- I/O Port. *)

    i := VideoAddress.SEGMENT;                                    (* 16-Dec-87 LAA *)
    m := VideoPort;
    SETREG(AX, i );
    SETREG(DX, m ); 

        (* Push the DS Register for safety. *)

    CODE( 01EH );            (* PUSH DS                               *)

        (*  ES:DI -----points to------> Line.
            DS:SI -----points to------> Screen.  *)

    CODE( 8BH, 4EH, 0FEH,    (* MOV  CX, [BP-2]   Length              *)
          8BH, 76H, 0FAH,    (* MOV  SI, [BP-6]   Screen offset       *)
          8BH, 7EH, 06H,     (* MOV  DI, [BP+6]   Dest   offset       *)
          8BH, 5EH, 08H,     (* MOV  BX, [BP+8]   Dest   segment      *)
          8EH, 0C3H,         (* MOV  ES, BX                           *)
          8EH, 0D8H );       (* MOV  DS, AX       Source segment      *)

        (*  Copy from screen to Line during retrace intervals. *)

    CODE( 0FCH,              (* CLD               Clear direction.    *)
          0ECH,              (* IN AL, DX         Check video status  *)
          0D0H, 0C8H,        (* ROR AL, 1                             *)
          72H, 0FBH,         (* JB -4                                 *)
          0FAH,              (* CLI               Interrupts off      *)
          0ECH,              (* IN AL, DX         Check video status  *)
          0D0H, 0C8H,        (* ROR AL, 1          wait until retrace *)
          73H, 0FBH,         (* JNB -4             starts.            *)
          0ADH,              (* LODSW             Load word.          *)
          0ABH,              (* STOSW             Store word.         *)
          0FBH,              (* STI               Interrupts on.      *)
          0E2H, 0F0H );      (* LOOP -16          Loop back for next. *)

    CODE (1FH );             (* POP  DS                               *)

END GetImageLineFast;
(*DOS>*)

(*<OS2
PROCEDURE GetImageLineFast(x	 : CARDINAL;
			               y	 : CARDINAL;
			               Count : CARDINAL;
			               Line  : ADDRESS);

VAR
    m, yx, i, len           : CARDINAL;

BEGIN
    len := Count * 2;

    IF (len = 0) THEN
        RETURN;
    END;

    err := VioReadCellStr(Line, len, y, x, 0);

END GetImageLineFast;
OS2>*)




(*<DOS*)
PROCEDURE PutImageLineFast(x:CARDINAL; y:CARDINAL; Count:CARDINAL;
                           Line : ADDRESS);
VAR
    m, yx, i, len : CARDINAL;

BEGIN
    len := Count;
    IF (len = 0) THEN RETURN; END;

    yx := ((ScreenWidth*y) + x) * 2;            (*  Offset on screen. *)


        (* AX <- Screen segment, DX <- I/O Port. *)

    i := VideoAddress.SEGMENT;                                    (* 16-Dec-87 LAA *)
    m := VideoPort;
    SETREG(AX, i );
    SETREG(DX, m ); 

        (* Push the DS Register for safety. *)

    CODE( 01EH );            (* PUSH DS                               *)

        (*  ES:DI -----points to------> Screen.
            DS:SI -----points to------> Line.    *)

    CODE( 8BH, 4EH, 0FEH,    (* MOV  CX, [BP-2]   Length              *)
          8BH, 7EH, 0FAH,    (* MOV  DI, [BP-6]   Screen offset       *)
          8BH, 76H, 06H,     (* MOV  SI, [BP+6]   Dest   offset       *)
          8BH, 5EH, 08H,     (* MOV  BX, [BP+8]   Dest   segment      *)
          8EH, 0DBH,         (* MOV  DS, BX                           *)
          8EH, 0C0H );       (* MOV  ES, AX       Source segment      *)

        (*  Copy from Line to screen during retrace intervals. *)

    CODE( 0FCH,              (* CLD               Clear direction.    *)
          0ECH,              (* IN AL, DX         Check video status  *)
          0D0H, 0C8H,        (* ROR AL, 1                             *)
          72H, 0FBH,         (* JB -4                                 *)
          0FAH,              (* CLI               Interrupts off      *)
          0ECH,              (* IN AL, DX         Check video status  *)
          0D0H, 0C8H,        (* ROR AL, 1          wait until retrace *)
          73H, 0FBH,         (* JNB -4             starts.            *)
          0ADH,              (* LODSW             Load word.          *)
          0ABH,              (* STOSW             Store word.         *)
          0FBH,              (* STI               Interrupts on.      *)
          0E2H, 0F0H );      (* LOOP -16          Loop back for next. *)

    CODE (1FH );             (* POP  DS                               *)

END PutImageLineFast;
(*DOS>*)


(*<OS2
PROCEDURE PutImageLineFast(x     : CARDINAL;
                           y     : CARDINAL;
                           Count : CARDINAL;
			               Line  : ADDRESS);

VAR
    m, yx, i, len           : CARDINAL;

BEGIN
    len := Count * 2;

    IF (len = 0) THEN
        RETURN;
    END;

    err := VioWrtCellStr(Line, len, y, x, 0);

END PutImageLineFast;
OS2>*)







    (* PutStringWithAttribute -- Display the string on the screen with the
                                 absolute attribute indicated by "a".  This
                                 is specific to IBM PC type computers, and 
                                 avoids use of the vidctrl array. *)


(*<DOS*)
PROCEDURE PutStringWithAttributeFast  ( VAR s : ARRAY OF CHAR;
                                            x : CARDINAL;
                                            y : CARDINAL;
                                            a : BITSET );
VAR
    m, yx, i, len : CARDINAL;

BEGIN
    len := ORD(s[0]);
    IF (len = 0) THEN RETURN
    ELSIF (len > HIGH(s)) OR (x > maxcol) OR (y > VidMaxRow) THEN HALT;
    END;

    m := maxcol + 1 - x;
    IF (len > m) THEN len := m; END;              (*  Maximum length   *)
    yx := ((ScreenWidth*y) + x) * 2;              (*  Offset on screen. *)
    m := CARDINAL(a);                             (*  Video Attribute. *)



        (* ES <- Screen segment, DX <- I/O Port. *)

    i := VideoAddress.SEGMENT;                                    (* 16-Dec-87 LAA *)
    x := VideoPort;
    SETREG(ES, i );
    SETREG(DX, x ); 

        (*  Push DS.
            SI <-- Offset for source.
            Push Source segment.
        *)


    CODE( 01EH );            (* PUSH DS                               *)

    CODE( 8AH, 66H, 0F8H,    (* MOV  AH, [BP-8]   Video Attr.         *)
          8BH, 4EH, 0FEH,    (* MOV  CX, [BP-2]   Length              *)
          8BH, 7EH, 0FAH,    (* MOV  DI, [BP-6]   Screen offset       *)
          8BH, 76H, 0CH,     (* MOV  SI, [BP+0C]  Source offset       *)
          46H,               (* INC  SI             (Skip count)      *)
          8BH, 5EH, 0EH,     (* MOV  BX, [BP+0E]  Source segment      *)
          8EH, 0DBH      );  (* MOV  DS, BX                           *)

(*  This is the original code;  what follows should be faster, if larger.

          (* Move the characters to the screen.  This may cause a
             little hash on the left edge since we do three memory
             accesses after the retrace starts.  Doing only 1 byte
             move per retrace would reduce the hash on IBM PC's
             with Color Graphics cards. *)

    CODE( 0FCH,              (* CLD               Clear direction.    *)
          0ECH,              (* IN AL, DX         Check video status  *)
          0D0H, 0C8H,        (* ROR AL, 1                             *)
          72H, 0FBH,         (* JB -4                                 *)
          0FAH,              (* CLI               Interrupts off      *)
          0ECH,              (* IN AL, DX         Check video status  *)
          0D0H, 0C8H,        (* ROR AL, 1          wait until retrace *)
          73H, 0FBH,         (* JNB -4             starts.            *)
          0ACH,              (* LODSB             Load character.     *)
          0ABH,              (* STOSW             Store it. (2 bytes) *)
          0FBH,              (* STI               Interrupts on.      *)
          0E2H, 0F0H );      (* LOOP -16          Loop back for next. *)
*)

     CODE(
     0FCH,             (*                CLD                      ;Autoincrement for LODSB, STOSW *)
     083H, 0F9H, 001H, (*WriteLoop:      CMP      CX, 1           ;Is CX > 1                      *)
     076H, 01BH,       (*                JNA      WriteOneByte    ;Jump if No                     *)
                          
                       (*WriteTwoBytes:                                                           *)
     0ACH,             (*                LODSB                    ;Get char to write              *)
     08AH, 0F8H,       (*                MOV      BH, AL          ;Save it in BH                  *)
     0ACH,             (*                LODSB                    ;Second char to write           *)
     08AH, 0D8H,       (*                MOV      BL, AL          ;Save it in BL                  *)
     0ECH,             (*LoopInRetrace2: IN       AL, DX          ;Loop while in H-Retrace        *)
     0D0H, 0C8H,       (*                ROR      AL, 1                                           *)
     072H, 0FBH,       (*                JB       LoopInRetrace2                                  *)
     0FAH,             (*                CLI                      ;Can't afford interrupts here   *)
     0ECH,             (*AwaitRetrace2:  IN       AL, DX          ;Find start of H-Retrace        *)
     0D0H, 0C8H,       (*                ROR      AL, 1                                           *)
     073H, 0FBH,       (*                JNB      AwaitRetrace2                                   *)
     08AH, 0C7H,       (*                MOV      AL, BH          ;Get char to write              *)
     0ABH,             (*                STOSW                    ;Write it, attribute in AH      *)
     08AH, 0C3H,       (*                MOV      AL, BL          ;Get second char to write       *)
     0ABH,             (*                STOSW                    ;Write it                       *)
     049H,             (*                DEC      CX              ;Adjust for two bytes           *)
     0EBH, 012H, 090H, (*                JMP      TestForExit                                     *)

                       (*WriteOneByte:                                                            *)
     0ACH,             (*                LODSB                    ;Get char to write              *)
     08AH, 0F8H,       (*                MOV      BH, AL          ;Save it in BH                  *)
     0ECH,             (*LoopInRetrace1: IN       AL, DX          ;Loop while in H-Retrace        *)
     0D0H, 0C8H,       (*                ROR      AL, 1                                           *)
     072H, 0FBH,       (*                JB       LoopInRetrace1                                  *)
     0FAH,             (*                CLI                      ;Can't afford interrupts here   *)
     0ECH,             (*AwaitRetrace1:  IN       AL, DX          ;Find start of H-Retrace        *)
     0D0H, 0C8H,       (*                ROR      AL, 1                                           *)
     073H, 0FBH,       (*                JNB      AwaitRetrace1                                   *)
     08AH, 0C7H,       (*                MOV      AL, BH          ;Get char to write              *)
     0ABH,             (*                STOSW                    ;Write it, attribute in AH      *)

     0FBH,             (*TestForExit:    STI                      ;Interrupts ok now              *)
     0E2H, 0CCH        (*                LOOP     WriteLoop                                       *)
     );

    CODE (1FH );             (* POP  DS                               *)


END PutStringWithAttributeFast;
(*DOS>*)


(*<OS2
PROCEDURE PutStringWithAttributeFast(VAR s : ARRAY OF CHAR;
					                     x : CARDINAL;
					                     y : CARDINAL;
					                     a : BITSET );

VAR
    m, yx, i, len           : CARDINAL;
    attr                    : DisplayAttributeSet;

BEGIN
    len := ORD(s[0]);

    IF (len = 0) THEN
        RETURN;
    ELSIF (len > HIGH(s)) OR (x > maxcol) OR (y > VidMaxRow) THEN
        HALT;
    END;

    m := maxcol + 1 - x;

    IF (len > m) THEN
        len := m;
    END;	      (*  Maximum length   *)

    trick.BitSetView := a;

    attr := trick.AttrView[0];

    err  := VioWrtCharStrAtt(ADR(s[1]), len, y, x, attr, 0);

END PutStringWithAttributeFast;
OS2>*)









    (* PutStringWithAttribute -- Display the string on the screen with the
                                 absolute attribute indicated by "a".  This
                                 is specific to IBM PC type computers, and 
                                 avoids use of the vidctrl array. *)


(*<DOS*)
PROCEDURE PutStringWithAttributeClean ( VAR s : ARRAY OF CHAR;
                                            x : CARDINAL;
                                            y : CARDINAL;
                                            a : BITSET );
VAR
    m, yx, i, len : CARDINAL;
    OldX, OldY    : CARDINAL;
    OldCursor     : CARDINAL;
BEGIN
    len := ORD(s[0]);
    IF (len = 0) THEN RETURN
    ELSIF (len > HIGH(s)) OR (x > maxcol) OR (y > VidMaxRow) THEN HALT;
    END;

    GetCursorLocation(OldX,OldY);
    XGetCursorType(OldCursor);
    
    m := maxcol + 1 - x;
    IF (len > m) THEN len := m; END;              (*  Maximum length   *)

    yx := ((y*0100H) + x);                        (*  (y,x) position. *)

        (* Write the characters. *)

    i := 1;
    WHILE (i <= len) DO

            (* Set cursor position. *)

        SETREG(DX,yx);           (* Row, Column *)
        SETREG(BX,0);            (* Page        *)
        SETREG(AX,0200H);        (* SetCursorPosition *)
        SWI(BIOSVideoInterrupt);    (* Call the ROM BIOS *)

            (* Write a character. *)

        m := 0900H  + ORD(s[i]);       (* Function 9 (write), char *)
        SETREG(CX,1); 
        SETREG(BX,a);               (* Page 0, attribute *) 
        SETREG(AX,m); 
        SWI(BIOSVideoInterrupt);

        INC(i);
        INC(yx);
    END;

    SetCursorLocation(OldX,OldY);
    XSetCursorType(OldCursor);

END PutStringWithAttributeClean;
(*DOS>*)


(*<OS2
PROCEDURE PutStringWithAttributeClean(VAR s : ARRAY OF CHAR;
					                      x : CARDINAL;
					                      y : CARDINAL;
					                      a : BITSET );

VAR
    m, yx, i, len           : CARDINAL;
    attr                    : DisplayAttributeSet;

BEGIN
    len := ORD(s[0]);

    IF (len = 0) THEN
        RETURN;
    ELSIF (len > HIGH(s)) OR (x > maxcol) OR (y > VidMaxRow) THEN
        HALT;
    END;

    m := maxcol + 1 - x;

    IF (len > m) THEN
        len := m;
    END;	      (*  Maximum length   *)


    trick.BitSetView := a;

    attr := trick.AttrView[0];

    err  := VioWrtCharStrAtt(ADR(s[1]), len, y, x, attr, 0);

END PutStringWithAttributeClean;
OS2>*)



(*<DOS*)
PROCEDURE GetImageLineClean(x:CARDINAL; y:CARDINAL; Count:CARDINAL;
                            Line : ADDRESS);
VAR
    m, yx, i, len, AttrChar : CARDINAL;
    TargetArray : POINTER TO ARRAY [0..79] OF CARDINAL;
    OldX, OldY : CARDINAL;
BEGIN
    len := Count;
    IF (len = 0) THEN RETURN; END;

    XGetCursorLocation(OldX,OldY);

    yx := ((y*0100H) + x);                        (*  (y,x) position. *)


    TargetArray := Line;

    i := 0;
    WHILE (i < len) DO

            (* Set cursor position. *)

        SETREG(DX,yx);           (* Row, Column *)
        SETREG(BX,0);            (* Page        *)
        SETREG(AX,0200H);        (* SetCursorPosition *)
        SWI(BIOSVideoInterrupt);    (* Call the ROM BIOS *)

            (* Read a character. *)

        SETREG(BX,0);               (* Page 0 *)
        SETREG(AX,0800H);           (* Function 8, (write) *) 
        SWI(BIOSVideoInterrupt);
        GETREG(AX,AttrChar);

        TargetArray^[i] := AttrChar;

        INC(i);
        INC(yx);
    END;

    XSetCursorLocation(OldX,OldY);

END GetImageLineClean;
(*DOS>*)



(*<OS2
PROCEDURE GetImageLineClean(x     :CARDINAL; 
                            y     :CARDINAL; 
                            Count : CARDINAL;
			                Line  : ADDRESS);

VAR
    m, yx, i, len, AttrChar : CARDINAL;
    TargetArray             : POINTER TO ARRAY [0..79] OF CARDINAL;
    OldX, OldY              : CARDINAL;

BEGIN
    len := Count * 2;

    IF (len = 0) THEN
        RETURN;
    END;

    err := VioReadCellStr(Line, len, y, x, 0);

END GetImageLineClean;
OS2>*)






(*<DOS*)
PROCEDURE PutImageLineClean(x:CARDINAL; y:CARDINAL; Count:CARDINAL;
                            Line : ADDRESS);
VAR
    m, yx, i, len, AttrChar, Attr, Char : CARDINAL;
    TargetArray : POINTER TO ARRAY [0..79] OF CARDINAL;
    OldX, OldY : CARDINAL;
BEGIN
    len := Count;
    IF (len = 0) THEN RETURN; END;

    XGetCursorLocation(OldX,OldY);

    yx := ((y*0100H) + x);                        (*  (y,x) position. *)

    TargetArray := Line;

    i := 0;
    WHILE (i < len) DO

            (* Set cursor position. *)

        SETREG(DX,yx);           (* Row, Column *)
        SETREG(BX,0);            (* Page 0      *)
        SETREG(AX,0200H);        (* SetCursorPosition *)
        SWI(BIOSVideoInterrupt);    (* Call the ROM BIOS *)

            (* Write an attribute and character. *)

        AttrChar := TargetArray^[i];
        Attr     := AttrChar DIV 100H;
        Char     := AttrChar MOD 100H;

        m := 0900H  + Char;            (* Function 9 (write), char *)
        SETREG(CX,1);               (* Count of chars to write. *)
        SETREG(BX,Attr);            (* Page 0, attribute *) 
        SETREG(AX,m);               (* Function 9 (write), char *)
        SWI(BIOSVideoInterrupt);

        INC(i);
        INC(yx);
    END;

    XSetCursorLocation(OldX,OldY);

END PutImageLineClean;
(*DOS>*)


(*<OS2
PROCEDURE PutImageLineClean(x     : CARDINAL; 
                            y     : CARDINAL; 
                            Count : CARDINAL;
			                Line  : ADDRESS);

VAR
    m, yx, i, len, 
    AttrChar, Attr, Char     : CARDINAL;
    TargetArray              : POINTER TO ARRAY [0..79] OF CARDINAL;
    OldX, OldY               : CARDINAL;

BEGIN
    len := Count * 2;

    IF (len = 0) THEN
        RETURN;
    END;

    err := VioWrtCellStr(Line, len, y, x, 0);
END PutImageLineClean;
OS2>*)


(*<DOS*)
PROCEDURE PutAttributeFast ( x     : CARDINAL;
                             y     : CARDINAL;
                             Count : CARDINAL;
                             a     : BITSET );
VAR
    m, yx, i, len : CARDINAL;

BEGIN
    len := Count;
    IF (len = 0) THEN RETURN
    ELSIF (x > maxcol) OR (y > VidMaxRow) THEN HALT
    END;

    m := maxcol + 1 - x;
    IF (len > m) THEN len := m; END;              (*  Maximum length   *)
    yx := ((ScreenWidth*y) + x) * 2;              (*  Offset on screen. *)
    m := CARDINAL(a);                             (*  Video Attribute. *)



        (* ES <- Screen segment, DX <- I/O Port. *)

    i := VideoAddress.SEGMENT;                                    (* 16-Dec-87 LAA *)
    x := VideoPort;
    SETREG(ES, i );
    SETREG(DX, x ); 

        (*  Push DS.
            SI <-- Offset for source.
            Push Source segment.
        *)


    CODE( 01EH );            (* PUSH DS                               *)

    CODE( 8AH, 66H, 0F8H,    (* MOV  AH, [BP-8]   Video Attr.         *)
          8BH, 4EH, 0FEH,    (* MOV  CX, [BP-2]   Length              *)
          8BH, 7EH, 0FAH );  (* MOV  DI, [BP-6]   Screen offset       *)

          (* Move the characters to the screen.  This may cause a
             little hash on the left edge since we do three memory
             accesses after the retrace starts.  Doing only 1 byte
             move per retrace would reduce the hash on IBM PC's
             with Color Graphics cards. *)

    CODE( 0FCH,              (* CLD               Clear direction.    *)
          0ECH,              (* IN AL, DX         Check video status  *)
          0D0H, 0C8H,        (* ROR AL, 1                             *)
          72H, 0FBH,         (* JB -4                                 *)
          0FAH,              (* CLI               Interrupts off      *)
          0ECH,              (* IN AL, DX         Check video status  *)
          0D0H, 0C8H,        (* ROR AL, 1          wait until retrace *)
          73H, 0FBH,         (* JNB -4             starts.            *)
          88H, 0E0H,         (* MOV AL, AH        Get attribute       *)
          47H,               (* INC DI            Advance screen ptr. *)
          0AAH,              (* STOSB             Move attr to screen *)
          0FBH,              (* STI               Interrupts on.      *)
          0E2H, 0EEH );      (* LOOP -18          Loop back for next. *)

    CODE (1FH );             (* POP  DS                               *)


END PutAttributeFast;
(*DOS>*)


(*<OS2
PROCEDURE PutAttributeFast ( x	   : CARDINAL;
            			     y	   : CARDINAL;
			                 Count : CARDINAL;
            			     a	   : BITSET );

VAR
    m, yx, i, len           : CARDINAL;
    attr                    : DisplayAttributeSet;

BEGIN
    len := Count;

    IF (len = 0) THEN
        RETURN;
    ELSIF (x > maxcol) OR (y > VidMaxRow) THEN
        HALT;
    END;

    m := maxcol + 1 - x;

    IF (len > m) THEN
        len := m;
    END;	      (*  Maximum length   *)


    trick.BitSetView := a;

    attr := trick.AttrView[0];

    err  := VioWrtNAttr(attr, len, y, x, 0);

END PutAttributeFast;
OS2>*)



(*<DOS*)
PROCEDURE PutAttributeClean( x     : CARDINAL;
                             y     : CARDINAL;
                             Count : CARDINAL;
                             a     : BITSET );
VAR
    ImageLine : ARRAY [1..ScreenWidth] OF BITSET;
    i         : CARDINAL;
BEGIN
    GetImageLineClean(x,y,Count,ADR(ImageLine));
    FOR i := 1 TO Count DO
        ImageLine[i] :=   (ImageLine[i] * {0..7})
                          +
                          BITSET(CARDINAL(a)*100H);
    END;
    PutImageLineClean(x,y,Count,ADR(ImageLine));
END PutAttributeClean;
(*DOS>*)


(*<OS2
PROCEDURE PutAttributeClean( x	   : CARDINAL;
            			     y	   : CARDINAL;
			                 Count : CARDINAL;
            			     a	   : BITSET );

VAR
    m, yx, i, len           : CARDINAL;
    attr                    : DisplayAttributeSet;

BEGIN
    len := Count;

    IF (len = 0) THEN
        RETURN;
    ELSIF (x > maxcol) OR (y > VidMaxRow) THEN
        HALT;
    END;

    m := maxcol + 1 - x;

    IF (len > m) THEN
        len := m;
    END;	      (*  Maximum length   *)


    trick.BitSetView := a;

    attr := trick.AttrView[0];

    err  := VioWrtNAttr(attr, len, y, x, 0);

END PutAttributeClean;
OS2>*)



    (*  MakeTone  -- Make a noise on the speaker. *)

(*<DOS*)
PROCEDURE XMakeTone  ( Pitch, Duration : CARDINAL );
BEGIN
    SETREG(DX, Pitch);
    SETREG(BX, Duration); 
    CODE( 0E4H, 061H,        (*  IN  AL, 61H  ;Input Control from speaker port. *)
          050H,              (*  PUSH AX      ;Save on stack                    *)
                             (*TONEMORE:                                        *)
          024H, 0FCH,        (*  AND AL, 0FCH ;Turn off bits 0 and 1.           *)
          0E6H, 061H,        (*  OUT 61H, AL  ;Speaker off pulse.               *)
          08BH, 0CAH,        (*  MOV CX,  DX  ;Time for tone half cycle         *)
                             (*TONE1:                                           *)
          0E2H, 0FEH,        (*  LOOP TONE1   ;Kill time                        *)
          00CH, 002H,        (*  OR  AL, 2    ;Turn on bit 1.                   *)
          0E6H, 061H,        (*  OUT 61H, AL  ;Speaker on pulse.                *)
          08BH, 0CAH,        (*  MOV CX,  DX  ;Time for tone half cycle         *)
                             (*TONE2:                                           *)
          0E2H, 0FEH,        (*  LOOP TONE2   ;Kill time                        *)
          04BH,              (*  DEC BX       ;Count down the duration.         *)
          075H, 0EDH,        (*  JNZ TONEMORE ;If BX <> 0, keep cycling         *)
          058H,              (*  POP AX       ;Restore speaker/KB port value.   *)
          0E6H, 061H );      (*  OUT 61H, AL  ;Send value out.                  *)
END XMakeTone;
(*DOS>*)


(*<OS2
PROCEDURE XMakeTone(Pitch, Duration : CARDINAL);

BEGIN
    err := DosBeep (Pitch, Duration);
END XMakeTone;
OS2>*)


PROCEDURE SetBIOSBlinking(N:CARDINAL);
BEGIN
(*<DOS*)
        (* Only do this for color systems.  We do not trust that all
           Hercules mono cards work with this interrupt.   Bail out if
           monochrome. *)
    IF (VideoAddress.SEGMENT = 0B000H) THEN
        RETURN;
    END;
        (* See "Programmer's guide to PC and PS/2 video systems"
           Richard Wilton, Microsoft Press, page 55.
           According to Bob Bierman, this is safe on all IBM video
           systems; they either honor it or ignore it.   Works on
           EGA, MCGA, VGA, PS/2's and PC Jr.  *)
    SETREG(BX,N);
    SETREG(AX,1003H);
    SWI(10H);
(*DOS>*)
END SetBIOSBlinking;





    (*  StopBlinking  --   Alter the setting of the Motorola 6845 video
                           controller so that the high order bit of the
                           video attribute byte controls the intensity
                           of the background instead of blinking.  This
                           only works on the color controller card. *)


PROCEDURE StopBlinking;
BEGIN
(*<DOS*)
    Reprogrammed6845 := TRUE;

        (* One of the following methods, either reprogramming the card
           or using the BIOS will work on all color adapters.  The other
           is documented by IBM as benign. *) 

    CODE ( 1EH,            (* PUSH DS         Save Data Segment       *)
           0B8H, 40H, 00,  (* MOV AX,  0040   Get BIOS Data Segment   *)
           08EH, 0D8H,     (* MOV DS,  AX                             *)
           8BH, 3EH,10H, 0,(* MOV  DI, EQUIP FLAG  Read DIP switches  *)
           81H,0E7H,30H, 0,(* AND  DI, 30H         Isolate CRT        *)
           83H, 0FFH, 30H, (* CMP  DI, 30H         Skip if Mono Card  *)
           74H, 0CH,       (* JE   +12                                *)
           0A0H, 65H, 00H, (* MOV AL, [65]    Load the video attr.byte*)
           24H,  0DFH,     (* AND AL, DF      Remove blink bit        *)
           0BAH, 0D8H, 3,  (* MOV DX, 3D8     Output port address     *)
           0EEH,           (* OUT DX, AL      Output the new vid.attr.*)
           0A2H, 65H, 00H, (* MOV [65], AL    Save vid. attr. byte    *)
           1FH   );        (* POP DS          Restore data segment    *)

     SetBIOSBlinking(BlinkOff);
(*DOS>*)
END StopBlinking;










PROCEDURE XGetCursorType ( VAR CursorType : CARDINAL );
BEGIN
    CursorType := CurrentCursorType;
END XGetCursorType;










(*<DOS*)
PROCEDURE XSetCursorType ( CursorType : CARDINAL );
BEGIN
    CASE CursorType OF
        0:   (* Off *)
                    SETREG(CX, 2006H );     (* Scan lines 32 - 6 *) 
                    SETREG(AX, WORD(BIOSSetCursorType) ); 
                    SWI( BIOSVideoInterrupt );
      | 1:   (* Underline *)
                            (*  Turn cursor so that it shows as an underline. *)
                            (*  This code looks into the memory used by the IBM ROM
                                BIOS to determine the type of video interface card that
                                is installed.  The correct cursor scan lines depend on
                                the type of card.  See the IBM Technical Reference
                                Manual, interrupt 10.  Incidently, early model PCs
                                have an error in the BIOS that prevents us from merely
                                reading the original scan line values from location
                                40:60--it isn't always there!
                            *)
                    CODE( 01EH,              (* PUSH DS                               *)
                          0B8H, 40H, 00H,    (* MOV  AX, DATA                         *)
                          8EH, 0D8H,         (* MOV  DS, AX                           *)
                          0B8H, 07H, 06H,    (* MOV  AX, COLOR CURSOR                 *)
                          8BH, 3EH, 10H, 00H,(* MOV  DI, EQUIP FLAG                   *)
                          81H, 0E7H, 30H, 0H,(* AND  DI, 30H                          *)
                          83H, 0FFH, 30H,    (* CMP  DI, 30H                          *)
                          75H, 03H,          (* JNE  +3                               *)
                          0B8H, 0CH, 0BH,    (* MOV  AX, B & W CURSOR                 *)
                          1FH,               (* POP  DS                               *)
                          8BH, 0C8H,         (* MOV  CX, AX                           *)
                          0B8H, 00H, 01H );  (* MOV  AX, SET CURSOR TYPE              *)
                    SWI( BIOSVideoInterrupt );
      | 2:  (* Block *)
                            (*  Turn cursor so that it shows as a block. *)
                            (*  This code looks into the memory used by the IBM ROM
                                BIOS to determine the type of video interface card that
                                is installed.  The correct cursor scan lines depend on
                                the type of card.  See the IBM Technical Reference
                                Manual, interrupt 10.
                            *)
                    CODE( 01EH,              (* PUSH DS                               *)
                          0B8H, 40H, 00H,    (* MOV  AX, DATA                         *)
                          8EH, 0D8H,         (* MOV  DS, AX                           *)
                          0B8H, 05H, 01H,    (* MOV  AX, COLOR CURSOR                 *)
                          8BH, 3EH, 10H, 00H,(* MOV  DI, EQUIP FLAG                   *)
                          81H, 0E7H, 30H, 0H,(* AND  DI, 30H                          *)
                          83H, 0FFH, 30H,    (* CMP  DI, 30H                          *)
                          75H, 03H,          (* JNE  +3                               *)
                          0B8H, 09H, 02H,    (* MOV  AX, B & W CURSOR                 *)
                          1FH,               (* POP  DS                               *)
                          8BH, 0C8H,         (* MOV  CX, AX                           *)
                          0B8H, 00H, 01H );  (* MOV  AX, SET CURSOR TYPE              *)
                    SWI( BIOSVideoInterrupt );
        ELSE HALT;
    END;

        (* Record it. *)

    CurrentCursorType := CursorType;

        (* If the 6845 is supposed to be non-blinking, make sure that
           it still is non-blinking.  Sometimes DOS or other memory-
           resident programs reset it. *)

(*    IF (Reprogrammed6845) THEN (* 4/19/89 WKH *)
        StopBlinking;
    END;*)

END XSetCursorType;
(*DOS>*)






(*<OS2
PROCEDURE XSetCursorType(ChangeCursorType : CARDINAL);

VAR 
    OffState                : CursorType;
    Ret                     : CARDINAL;

BEGIN
    CASE ChangeCursorType OF
	    0:   (* Off *)
	     Ret                      := VioGetCurType(OffState, 0);
	     OffState.cursorAttribute := -1;
	     Ret                      := VioSetCurType(OffState, 0);

      | 1:   (* Underline *)
         WITH PermCursorState DO
	        cursorStartLine := (ScreenMode.vertRes DIV ScreenMode.textRows) - 2;
	        cursorEndLine   := (ScreenMode.vertRes DIV ScreenMode.textRows) - 1;
	        cursorAttribute := 0;
	        Ret             := VioSetCurType(PermCursorState , 0);
         END;

      | 2:  (* Block *)
         WITH PermCursorState DO
	        cursorStartLine := 1;
	        cursorEndLine   := (ScreenMode.vertRes DIV ScreenMode.textRows) - 1;
	        cursorAttribute := 0;
	        Ret             := VioSetCurType(PermCursorState , 0);
         END;

	ELSE 
        HALT;
    END;

    CurrentCursorType := ChangeCursorType;
END XSetCursorType;
OS2>*)




(*<DOS*)
PROCEDURE XGetCursorLocation ( VAR X, Y : CARDINAL );
VAR
    CursorYX : CARDINAL;
BEGIN
    SETREG(BX, WORD(0)     ); 
    SETREG(AX, WORD(BIOSGetCursorPosition) ); 
    SWI( BIOSVideoInterrupt );
    GETREG(DX,CursorYX);
    X := CursorYX MOD 100H;
    Y := CursorYX DIV 100H;
END XGetCursorLocation;
(*DOS>*)



(*<OS2
PROCEDURE XGetCursorLocation(VAR X, Y : CARDINAL);

BEGIN
    err := VioGetCurPos(Y, X, 0);
END XGetCursorLocation;
OS2>*)





(*<DOS*)
PROCEDURE XSetCursorLocation ( X, Y : CARDINAL );
VAR
    CursorYX : WORD;
BEGIN
    CursorYX :=  WORD( ( Y * 100H ) + X );
    SETREG(DX, CursorYX    ); 
    SETREG(BX, WORD(0)     ); 
    SETREG(AX, WORD(BIOSSetCursorPosition) ); 
    SWI( BIOSVideoInterrupt );
    (* SetCursorType(CurrentCursorType); *)
END XSetCursorLocation;
(*DOS>*)

(*<OS2
PROCEDURE XSetCursorLocation(X, Y : CARDINAL);

BEGIN
    err := VioSetCurPos(Y, X, 0);
END XSetCursorLocation;
OS2>*)


PROCEDURE XGetScreenSize( VAR Columns, Rows : CARDINAL );
BEGIN
    Columns := maxcol;
    Rows    := VidMaxRow;
END XGetScreenSize;


(*<DOS*)
PROCEDURE XInitializeVideoHardware(     Blink : BOOLEAN;
                                       Clean : BOOLEAN  );
VAR
    ESValue, DXValue        : CARDINAL;


BEGIN
        (* Turn off any of our video tricks. *)

    TerminateVideoHardware;

        (* ES <- Screen segment, DX <- I/O Port. *)
    CODE( 01EH,              (* PUSH DS                               *)
          0B8H, 40H, 00H,    (* MOV  AX, DATA                         *)
          8EH, 0D8H,         (* MOV  DS, AX                           *)
          0B8H, 00H, 0B8H,   (* MOV  AX, COLOR CARD ADDRESS           *)
          8BH, 3EH, 10H, 00H,(* MOV  DI, EQUIP FLAG                   *)
          81H, 0E7H, 30H, 0H,(* AND  DI, 30H                          *)
          83H, 0FFH, 30H,    (* CMP  DI, 30H                          *)
          75H, 03H,          (* JNE  +3                               *)
          0B8H, 00H, 0B0H,   (* MOV  AX, B & W CARD ADDRESS           *)
          08BH, 16H, 63H, 0H,(* MOV  DX, ADDR_6845                    *)
          83H, 0C2H, 06H,    (* ADD  DX, 6                            *)
          1FH,               (* POP  DS                               *)
          8EH, 0C0H  );      (* MOV  ES, AX                           *)
    GETREG(ES,ESValue); 
    GETREG(DX,DXValue); 
    VideoAddress.SEGMENT := ESValue;
    VideoAddress.OFFSET  := 0;
    VideoPort            := DXValue;

    IF (Clean) THEN
        PutStringWithAttribute := PutStringWithAttributeClean;
        GetImageLine := GetImageLineClean;
        PutImageLine := PutImageLineClean;
        PutAttribute := PutAttributeClean;
    ELSE
        PutStringWithAttribute := PutStringWithAttributeFast;
        GetImageLine := GetImageLineFast;
        PutImageLine := PutImageLineFast;
        PutAttribute := PutAttributeFast;
        IF (NOT Blink) THEN
            StopBlinking;
        END;
    END;

    SetCursorType(CurrentCursorType);
    SetCursorLocation(0,0);

END XInitializeVideoHardware;
(*DOS>*)


(*<OS2
PROCEDURE XInitializeVideoHardware(Blink : BOOLEAN;
				                   Clean : BOOLEAN);

VAR
    Ret                     : CARDINAL;

BEGIN
    ScreenMode.length := SIZE(ModeDataType);
    Ret               := VioGetMode(ScreenMode, 0);
    Ret               := VioGetCurType(PermCursorState, 0);

    TerminateVideoHardware;

    PutStringWithAttribute := PutStringWithAttributeClean;
    GetImageLine := GetImageLineClean;
    PutImageLine := PutImageLineClean;
    PutAttribute := PutAttributeClean;

    SetCursorType(CurrentCursorType);
    SetCursorLocation(0,0);

END XInitializeVideoHardware;
OS2>*)


(*<DOS*)
PROCEDURE XTerminateVideoHardware;
BEGIN
    SetCursorType(1);   (* Turn the cursor back on. *)

    IF (NOT Reprogrammed6845) THEN
        RETURN;
    END;

        (*  Enable the blink function of the 6845 controller chip. *)
    CODE ( 1EH,            (* PUSH DS         Save Data Segment       *)
           0B8H, 40H, 00,  (* MOV AX,  0040   Get BIOS Data Segment   *)
           08EH, 0D8H,     (* MOV DS,  AX                             *)
           8BH, 3EH,10H, 0,(* MOV  DI, EQUIP FLAG  Read DIP switches  *)
           81H,0E7H,30H, 0,(* AND  DI, 30H         Isolate CRT        *)
           83H, 0FFH, 30H, (* CMP  DI, 30H         Skip if Mono Card  *)
           74H, 0CH,       (* JE   +12                                *)
           0A0H, 65H, 00H, (* MOV AL, [65]    Load the video attr.byte*)
           0CH,  020H,     (* OR  AL, 20      Set blink bit           *)
           0BAH, 0D8H, 3,  (* MOV DX, 3D8     Output port address     *)
           0EEH,           (* OUT DX, AL      Output the new vid.attr.*)
           0A2H, 65H, 00H, (* MOV [65], AL    Save vid. attr. byte    *)
           1FH   );        (* POP DS          Restore data segment    *)

    SetBIOSBlinking(BlinkOn);

    Reprogrammed6845 := FALSE;

END XTerminateVideoHardware;
(*DOS>*)

(*<OS2
PROCEDURE XTerminateVideoHardware;

BEGIN
    SetCursorType(1);	(* Turn the cursor back on. *)
END XTerminateVideoHardware;
OS2>*)

PROCEDURE XResetVideo;

BEGIN
(*<DOS*)
    IF (Reprogrammed6845) THEN
        StopBlinking;
    END;

    SetCursorType(CurrentCursorType);
(*DOS>*)
END XResetVideo;


    (*
        QueryAdapterType - Determine what type of adapter and display we're
                           using.

                           Adapted from a routine in the 2/89 issue of 
                           Dr. Dobb's Journal
    *)
(*<DOS*)
PROCEDURE QueryAdapterType() : AnAdapterType;
    
VAR
    BL                      : BYTE;
    AL                      : BYTE;
    AdapterFound            : AnAdapterType;
    BXValue                 : WORD;
    TempCard                : CARDINAL;

BEGIN
    AdapterFound := None;

    SETREG(AX, 01A00H);

    CODE(55H);
    SWI(10H);                (* Let's first check for VGA BIOS *)
    CODE(5DH);

    GETREG(AX, AL);
    GETREG(BX, BL);

    IF (ORD(AL) = 1AH) THEN  (* Well, guess we've got a VGA Adapter *)
        CASE ORD(BL) OF      (* Let's see what it's masquerading as *)
            00H : AdapterFound := None;
        |   01H : AdapterFound := MDA;
        |   02H : AdapterFound := CGA;
        |   04H : AdapterFound := EGAColor;
        |   05H : AdapterFound := EGAMono;
        |   07H : AdapterFound := VGAMono;
        |   08H : AdapterFound := VGAColor;
        |   0AH,
            0CH : AdapterFound := MCGAColor;
        |   0BH : AdapterFound := MCGAMono;

        ELSE
            AdapterFound := CGA;
        END;
    ELSE                     (* No VGA, let's see if we have EGA    *)
        SETREG(AX, 01200H);
        SETREG(BX, 00010H);

        CODE(55H);
        SWI(10H);
        CODE(5DH);
        
        GETREG(BX, BXValue);

        IF (ORD(BXValue) <> 010H) THEN  (* BX unchanged means no EGA *)
            (* Alright!!  If we get here, we've got EGA *)
            (* Let's see if it's color or mono *)
            
            SETREG(AX, 01200H);
            SETREG(BX, 010H);

            CODE(55H);
            SWI(10H);
            CODE(5DH);

            GETREG(BX, BXValue);

            BXValue := WORD(CARDINAL(BXValue) DIV 256);

            IF (ORD(BXValue) = 0) THEN
                AdapterFound := EGAColor;
            ELSE
                AdapterFound := EGAMono;
            END;
        ELSE
            (* Well, guess we've got a lowly CGA or MDA, let's see which *)

            CODE(55H);
            SWI(11H);
            CODE(5DH);

            GETREG(AX, TempCard);

            TempCard := CARDINAL(BITSET(TempCard) * BITSET{4..5}) DIV 16;

            CASE TempCard OF
                1,
                2 : AdapterFound := CGA;
            |   3 : AdapterFound := MDA;
            ELSE
                AdapterFound := None;
            END;
                    
        END;

    END;

    RETURN(AdapterFound);

END QueryAdapterType;
(*DOS>*)

(*<OS2
PROCEDURE QueryAdapterType() : AnAdapterType;
    
VAR
    AdapterFound            : AnAdapterType;
    VideoConfig             : ConfigData;
    err                     : CARDINAL;

BEGIN
    AdapterFound := None;
    VideoConfig.length := TSIZE(ConfigData);

    err := VioGetConfig(0, VideoConfig, 0);

    CASE VideoConfig.adapterType OF
        MonoPrtAdap : AdapterFound := MDA;
    |   VideoIO.CGA : AdapterFound := CGA;
    |   EGA         : CASE VideoConfig.displayType OF
                          MonoPrtDisp  : AdapterFound := EGAMono;
                      |   ColorDisp,
                          EnhColorDisp : AdapterFound := EGAColor;
                      ELSE
                      END;
    |   VGAIBMPS2DA,
        IBMPS28514A : CASE VideoConfig.displayType OF
                          IBMPS2MD8503     : AdapterFound := VGAMono;
                      |   IBMPS2CD8512x13,
                          IBMPS2CD8514     : AdapterFound := VGAColor;
                      ELSE
                      END;
    ELSE
    END;

END QueryAdapterType;
OS2>*)

BEGIN
(*<DOS*)
    Reprogrammed6845  := FALSE;
(*DOS>*)
    CurrentCursorType := 1; (* Underline *)

    SetCursorType           := XSetCursorType           ;
    GetCursorType           := XGetCursorType           ;
    SetCursorLocation       := XSetCursorLocation       ;
    GetCursorLocation       := XGetCursorLocation       ;
    MakeTone                := XMakeTone                ;
    GetScreenSize           := XGetScreenSize           ;
    InitializeVideoHardware := XInitializeVideoHardware ;
    TerminateVideoHardware  := XTerminateVideoHardware  ; 
    ResetVideo              := XResetVideo              ; (* 5/29/89 WKH *)

    VidMaxRow               := 24;  (* 10-Jun-89 WKH *)
    XInitializeVideoHardware(TRUE,TRUE);
END Video.
