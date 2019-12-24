    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE LStrings;




    (******************************************************************)
    (*                                                                *)
    (*     Special implementation for the i8086 instruction set.      *)
    (*                                                                *)
    (*     Author: Andrew Layman                                      *)
    (*     Many of the conversions to 8086 code by Larry Azlin,       *)
    (*     Mount Davidson Software, San Francisco, CA.                *)
    (*                                                                *)
    (******************************************************************)

    (* MODIFICATION History --

        1/3/86    AJL  -- Modified Upshift to use Foreign.ConvertString

        1/5/86    AJL  -- Compare now uses SortOrderTable.

        4/29/86   AJL  -- Now has TooLong procedure.

        31-Mar-87 LAA   Added new procedures Copy, LengthOf, and SetLengthOf.
                        Also put in compiler directive A+ because without it,
                        Search doesn't work.
        03-Jul-87 LAA   Changed Overlay so it will lengthen its destination
                        to the size of the variable, if necessary.
        17-Sep-87 LAA   Ken Colby found a bug in LStringToTString, which 
                        would hang the system for an LString of length 0.
        21-Sep-87 LAA   Removed call to TooLong for the Addend from ConcatS.
        25-Sep-87 LAA   Logitech version 3 compiler returns function values 
                        in different registers than version 2.  Only Search 
                        was a problem here.  Also found that Search never 
                        restored the value of the DS register.
        06-Oct-87 LAA   Force the optimization flag off for this module.
        18-Jan-88 LAA   Assemblerized ConcatLS to improve Gantt speed.
        22-Feb-88 LAA - Force stack checking on for this module.
        29-Feb-88 AJL - Modify TooLong so that we adapt to the size of the 
                        "too long: " phrase in GaGa.
                      - Instead of calling FatalError after TooLong, modified
                        various procedures to fail in a softer manner.  Note
                        that they will fail, though they will not call FatalError
                        as they previously did.
        20-Dec-88 RSC - Added StringsEqual().  Needs to be assemblerized.
                        Optimized procs with no assembler.
        04-Jan-89 LAA - Fixed bug in StringsEqual.  It was comparing using <>
                        instead of =.
        04-Apr-89 EGK   In SubStr, call TooLong instead of FatalError.
        14-Jun-89 KKC   Assemblerize StringsEqual, Procustes, Rjust, 
                        TrimFront, TrimRear, Remove, LStringToTString, 
                        TStringToLString, StoC
        28-Jun-89 LAA   Put a CLD into SetString to be sure the direction
                        flag is cleared and the REP MOVSB will auto-increment
                        the addresses it's using.  Commented out all the new
                        assemblerization because of problems that we've had
                        with the assemblerized version of ConvertString in
                        Foreign.
        05-Aug-89 WKH - Initial edits for OS/2.  Had to modify assembler 
                        that referenced local procedure variables(not
                        parameters) due to new procedure activation record
                        structure of 80286.

        10-Aug-89 RSC   Added InsertWithOverflow.
        04-Sep-89 LAA   Un-commented the assembler code for LStringToTString,
                        and cleaned up some places where a PUSH DS was being
                        done via MOV AX,DS and PUSH AX.  Also reenabled the
                        assembler on StringsEqual after changing a REPE to a
                        REPNE, and on TrimRear.
        06-Sep-89 LAA   Well, the manual was, at best, confusing.  The REPE 
                        in StringsEqual was really correct after all.  
        26-Jul-91 LAA       Added special call to DOSAvail to check for
                            corrupted DOS memory.  This should help localize
                            a startup bug that's occasionally happening.
                            This code MUST be removed once we've found the
                            bug!
    *)


FROM Dialog  IMPORT Error, FatalError;

FROM DOSMemory IMPORT DOSAvail;

FROM Foreign IMPORT ConvertString, ConvertedCharacter, UpshiftTable,
                    SortOrderTable;

FROM GaGa    IMPORT GetGaGaMessage;

FROM SYSTEM  IMPORT CODE, ADR, AX, GETREG, SETREG, CX;



CONST
    ModuleNumber = 22300;      (* For GetGaGaMessage *)


    MAXCARDINAL  = 65535;      (* Biggest damn number this processor has ever seen! *)



    (* Don't mess with these toggles or the CODE may not work. *)
(*$R-*)
(*$T-*)
(*$S-*)
(*$A+*)
(*$O-*) 


     (* CheckLength -- Make sure that the string S is a valid LString *)

(*$S+*)   (* Stack check *)
(*$O+*) 
PROCEDURE CheckLength(VAR S:ARRAY OF CHAR);
BEGIN
(*    IF (DOSAvail() > 0) THEN END;           (* DEBUGGING ONLY!!! *) *)
    IF (ORD(S[0]) > HIGH(S)) THEN FatalError END;
END CheckLength;
(*$O=*) 
(*$S=*)




(*$O+*) 
PROCEDURE TooLong( S : ARRAY OF CHAR );
VAR
    S2 : ARRAY [0..255] OF CHAR;
BEGIN
    GetGaGaMessage( ModuleNumber + 0, S2 ); (* "Too long: " *)
    IF (ORD(S[0]) > HIGH(S2)-ORD(S2[0])) THEN     (* AJL 2/29/88 *)
        S[0] := CHR(HIGH(S2)-ORD(S2[0]));         (* AJL 2/29/88 *)
    END;
    ConcatLS(S2,S);
    Error(S2);
END TooLong;
(*$O=*) 





PROCEDURE SetString (VAR Target:ARRAY OF CHAR; Source:ARRAY OF CHAR);
VAR
    i : CARDINAL;
BEGIN
    IF (HIGH(Source) >= HIGH(Target)) THEN
        FOR i := 1 TO HIGH(Target) DO
            Target[i] := Source[i-1];
            Target[0] := CHR(i);
        END;
        TooLong(Target);
        RETURN;                   (* AJL 2/29/88 *)
    END;


(*
    FOR i := 0 TO HIGH(Source) DO
            Target[i+1] := Source[i];
    END;
*)
        CODE (1EH,              (* PUSH DS              SAVE THE DS REG.    *)
              0FCH,             (* CLD                  Make MOVSB increment*)
              8BH,4EH,0AH,      (* MOV  CX,[BP+0A]      GET HIGH(SOURCE)    *)
              41H,              (* INC  CX              HIGH IS ZERO ORIGIN *)
              0C4H,7EH,0CH,     (* LES  DI,[BP+0C]      TARGET ADDRESS      *)
              0C5H,76H,06H,     (* LDS  SI,[BP+06]      SOURCE ADDRESS      *)
              47H,              (* INC  DI              SKIP PAST LENGTH    *)
              0F3H,0A4H,        (* REP  MOVSB           MOVE THE STRING     *)
              1FH);             (* POP  DS              POP THE DS REGISTER *)
    Target[0] := CHR(HIGH(Source)+1);
END SetString;





PROCEDURE ConcatLS (VAR Target:ARRAY OF CHAR; Addend: ARRAY OF CHAR);
VAR
    ti,ai : CARDINAL;
BEGIN
    (*
    Insert(Target,Addend,ORD(Target[0])+1);
    *)

    CheckLength(Target);
    CheckLength(Addend);
    IF (ORD(Target[0]) + ORD(Addend[0]) > HIGH(Target)) THEN
        TooLong(Target);
        TooLong(Addend);
        ai := HIGH(Target)-ORD(Target[0]);               (* AJL 2/29/88 *)
        IF (ai > 255) THEN ai := 255; END;               (* AJL 2/29/88 *)
        Addend[0] := CHR(ai);                            (* AJL 2/29/88 *)
    END;

    CODE(0FCH,              (* CLD                                              *)
         01EH,              (* PUSH    DS                                       *)
         0C5H, 076H, 006H,  (* LDS     SI,[BP+06]   ; Addend[0]                 *)
         02BH, 0C9H,        (* SUB     CX,CX                                    *)
         08AH, 00CH,        (* MOV     CL,[SI]      ; Length to CX              *)
         046H,              (* INC     SI           ; Skip lstring length       *)
         0C4H, 07EH, 00CH,  (* LES     DI,[BP+0CH]  ; Target[0]                 *)
         02BH, 0C0H,        (* SUB     AX,AX                                    *)
         026H, 08AH, 005H,  (* MOV     AL,ES:[DI]   ; Length of Target          *)
         08BH, 0D8H,        (* MOV     BX,AX                                    *)
         003H, 0D9H,        (* ADD     BX,CX        ; Compute new length        *)
         026H, 088H, 01DH,  (* MOV     ES:[DI],BL                               *)
         047H,              (* INC     DI           ; Skip length               *)
         003H, 0F8H,        (* ADD     DI,AX        ; Position to end of Target *)
         0F3H, 0A4H,        (* REP     MOVSB        ; Move characters           *)
         01FH);             (* POP     DS                                       *)
END ConcatLS;





PROCEDURE ConcatS  (VAR Target:ARRAY OF CHAR; Addend: ARRAY OF CHAR);
VAR
    ti,ai : CARDINAL;
BEGIN
    CheckLength(Target);
    IF (HIGH(Addend)+ORD(Target[0]) >= HIGH(Target)) THEN
        TooLong(Target);                                          (* 21-Sep-87 LAA *)
        RETURN;                   (* AJL 2/29/88 *)
    END;

    ti := ORD(Target[0]);
(*
    FOR ai := 0 TO HIGH(Addend) DO
        INC(ti);
        Target[ti] := Addend[ai];
    END;
*)

    CODE(01EH,          (* PUSH   DS          SAVE THE DS CONTENTS           *)
         0C4H,7EH,0CH,  (* LES    DI,[BP+0C]  ADDRESS OF TARGET TO ES:DI     *)
(*<DOS*)
         8BH,46H,0FCH,  (* MOV    AX,[BP-4]   GET THE VALUE OF ti            *)
(*DOS>*)
(*<OS2
         8BH,46H,0FAH,  (* MOV    AX,[BP-6]   GET THE VALUE OF ti            *)
OS2>*)
         01H,0C7H,      (* ADD    DI,AX       ES:DI = ADDR. OF TARGET[ti]    *)
         0C5H,76H,06H,  (* LDS    SI,[BP+06]  ADDRESS OF ADDEND TO DS:SI     *)
         8BH,4EH,0AH,   (* MOV    CX,[BP+0A]  HIGH(ADDEND) TO CX             *)
         41H,           (* INC    CX          ACCOUNT FOR THE ZERO ORIGIN    *)
         47H,           (* INC    DI          MOVE PAST LAST CHAR IN TARGET  *)
         0F3H,0A4H,     (* REP    MOVSB       APPEND ADDEND TO TARGET        *)
(*<DOS*)
         8BH,46H,0FCH,  (* MOV    AX,[BP-04]  GET THE VALUE OF ti            *)
(*DOS>*)
(*<OS2
         8BH,46H,0FAH,  (* MOV    AX,[BP-06]  GET THE VALUE OF ti            *)
OS2>*)
         03H,46H,0AH,   (* ADD    AX,[BP+0A]  ADD HIGH(ADDEND)               *)
         40H,           (* INC    AX          ADJUST FOR ZERO ORIGIN OF HIGH *)
(*<DOS*)
         89H,46H,0FCH,  (* MOV    [BP-04],AX  PUT RESULT BACK IN ti          *)
(*DOS>*)
(*<OS2
         89H,46H,0FAH,  (* MOV    [BP-06],AX  PUT RESULT BACK IN ti          *)
OS2>*)
         01FH);         (* POP    DS          RESTORE VALUE OF DS            *)

    Target[0] := CHR(ti);
END ConcatS;





PROCEDURE LJust    (VAR Target:ARRAY OF CHAR);
VAR
    si, di : CARDINAL;
BEGIN
    CheckLength(Target);

(*
    si := 1;
    di := 1;
    WHILE (si <= ORD(Target[0])) AND (Target[si]=" ") DO INC(si) END;
    WHILE (si <= ORD(Target[0])) DO
        Target[di] := Target[si];
        INC(si);
        INC(di);
    END;
    WHILE (di <= ORD(Target[0])) DO
        Target[di] := " ";
        INC(di)
    END;
*)

(**)
    CODE(01EH,          (* PUSH   DS       SAVE THE VALUE OF DS              *)
         0C5H,76H,06H,  (* LDS    SI,[BP+06]  GET ADDRESS OF TARGET          *)
         8AH,0CH,       (* MOV    CL,[SI]     GET LENGTH FROM TARGET[0]      *)
         0B5H,00H,      (* MOV    CH,00H      ALLOWS CX TO BE USED AS COUNTER*)
         0E3H,021H,     (* JCXZ   #5          NULL STRING                    *)
         89H,0CAH,      (* MOV    DX,CX       SAVE IN DX FOR LATER USE       *)
         46H,           (* INC    SI          ADJUST TO TARGET[1]            *)
         (* LABEL #1 *)
         80H,3CH,20H,   (* CMP    BYTE PTR [SI],20  COMPARE TO A BLANK       *)
         75H,05H,       (* JNZ    #2          JUMP IF NOT A BLANK            *)
         46H,           (* INC    SI          LOOK AT NEXT CHARACTER         *)
         0E2H,0F8H,     (* LOOP   #1          DEC CX AND DO IT AGAIN IF <> 0 *)
         0EBH,14H,      (* JMP    #5          ALL BLANKS HERE, EXIT LJUST    *)
         (* LABEL #2 *)
         0C4H,7EH,06H,  (* LES    DI,[BP+06]  GET ADDRESS OF TARGET          *)
         47H,           (* INC    DI          SKIP THE LENGTH                *)
         (* LABEL #3 *)
         0A4H,          (* MOVSB              MOVE A BYTE FROM SOURCE TO DEST*)
         4AH,           (* DEC    DX          COUNT DOWN DEST LENGTH         *)
         0E2H,0FCH,     (* LOOP   #3          MOVE UNTIL SOURCE IS EXHAUSTED *)
         (* LABEL #4 *)
         83H,0FAH,00H,  (* CMP    DX,00H      WHILE DEST COUNT NOT FINISHED  *)
         74H,07H,       (* JZ     #5          FINISHED                       *)
         0C6H,05H,20H,  (* MOV    BYTE PTR [DI],20H  PUT BLANK AT DEST       *)
         47H,           (* INC    DI          NEXT CHAR IN DEST              *)
         4AH,           (* DEC    DX          COUNT DOWN THE DEST LENGTH     *)
         0EBH,0F4H,     (* JMP    #4                                         *)
         (* LABEL #5 *)
         01FH);         (* POP    DS          RESTORE THE VALUE OF DS        *)
(**)
END LJust;



PROCEDURE RJust    (VAR Target:ARRAY OF CHAR);
VAR
    si                      : CARDINAL;
    di                      : CARDINAL;

BEGIN
    CheckLength(Target);

    si := ORD(Target[0]);
    di := si;
    WHILE (si > 0) AND (Target[si]=" ") DO DEC(si) END;
    WHILE (si > 0) DO
        Target[di] := Target[si];
        DEC(si);
        DEC(di);
    END;
    WHILE (di > 0) DO
        Target[di] := " ";
        DEC(di)
    END;

(* 
    RJtParams       struc                             
    RJtOldBP            dw      ?                     
    RJtReturnAddr       dd      ?                     
    RJtString           db      ArrayParamSize dup (?)
    RJtParams       ends                              
*)
(*
  CODE(
      09CH,                      (*     pushf                                              *)
      0C5H, 076H, 006H,          (*     lds     si, [bp].RJtString.ArrayPtr                *)
      08CH, 0D8H,                (*     mov     ax, ds                                     *)
      08EH, 0C0H,                (*     mov     es, ax                                     *)
      08AH, 00CH,                (*     mov     cl, [si]                                   *)
      0B5H, 000H,                (*     mov     ch, 0                                      *)
      0E3H, 023H,                (*     jcxz    RJustRet                                   *)
      08BH, 0D1H,                (*     mov     dx, cx                                     *)
      08BH, 0FEH,                (*     mov     di, si                                     *)
      003H, 0F9H,                (*     add     di, cx                                     *)
      0B0H, 020H,                (*     mov     al, ' '                                    *)
      038H, 005H,                (*     cmp     [di], al                                   *)
      075H, 017H,                (*     jne     RJustRet                                   *)
      0FDH,                      (*     std                                                *)
      0F3H, 0AEH,                (*     rep     scasb                                      *)
      074H, 012H,                (*     je      RJustRet            ; jmp if blank line.   *)
      041H,                      (*     inc     cx                                         *)
      047H,                      (*     inc     di                                         *)
      087H, 0F7H,                (*     xchg    si, di                                     *)
      003H, 0FAH,                (*     add     di, dx                                     *)
      08AH, 0F1H,                (*     mov     dh, cl                                     *)
      0F3H, 0A4H,                (*     rep     movsb                                      *)
      02AH, 0D6H,                (*     sub     dl, dh                                     *)
      08AH, 0CAH,                (*     mov     cl, dl                                     *)
      0B0H, 020H,                (*     mov     al, ' '                                    *)
      0F3H, 0AAH,                (*     rep     stosb                                      *)
                                 (* RJustRet:                                              *)
      09DH                       (*     popf                                               *)
      );
*)
END RJust;




PROCEDURE TrimFront (VAR Target:ARRAY OF CHAR);
VAR
    si                      : CARDINAL;
    di                      : CARDINAL;

BEGIN
    CheckLength(Target);

    si := 1;
    di := 0;
    WHILE (si <= ORD(Target[0])) AND (Target[si]=" ") DO INC(si) END;
    WHILE (si <= ORD(Target[0])) DO
        INC(di);
        Target[di] := Target[si];
        INC(si);
    END;
    Target[0] := CHR(di);

(*
    TFtParams       struc
    TFtOldBP            dw      ?
    TFtReturnAddr       dd      ?
    TFtString           db      ArrayParamSize dup (?)
    TFtParams       ends
*)
(*
  CODE(
      09CH,                      (*     pushf                                  *)
      0FCH,                      (*     cld                                    *)
      0C5H, 076H, 006H,          (*     lds     si, [bp].TFtString.ArrayPtr    *)
      08AH, 00CH,                (*     mov     cl, [si]                       *)
      0B5H, 000H,                (*     mov     ch, 0                          *)
      0E3H, 01EH,                (*     jcxz    TrimFrontRet                   *)
      046H,                      (*     inc     si                             *)
      0B0H, 020H,                (*     mov     al, ' '                        *)
      038H, 004H,                (*     cmp     [si], al                       *)
      075H, 017H,                (*     jne     TrimFrontRet                   *)
      0C6H, 044H, 0FFH, 00H,     (*     mov     byte ptr [si - 1], 0           *)
      08CH, 0DFH,                (*     mov     di, ds                         *)
      08EH, 0C7H,                (*     mov     es, di                         *)
      08BH, 0FEH,                (*     mov     di, si                         *)
      0F3H, 0AEH,                (*     rep     scasb                          *)
      074H, 009H,                (*     je      TrimFrontRet                   *)
      041H,                      (*     inc     cx                             *)
      088H, 04CH, 0FFH,          (*     mov     [si - 1], cl                   *)
      04FH,                      (*     dec     di                             *)
      087H, 0F7H,                (*     xchg    si, di                         *)
      0F3H, 0A4H,                (*     rep     movsb                          *)
                                 (* TrimFrontRet:                              *)
      09DH                       (*     popf                                   *)
      );
*)
END TrimFront;




PROCEDURE TrimRear (VAR Target:ARRAY OF CHAR);
VAR
    si                      : CARDINAL;

BEGIN
    CheckLength(Target);

(*
    si := ORD(Target[0]);
    WHILE (si > 0) AND (Target[si]=" ") DO DEC(si) END;
    Target[0] := CHR(si);
*)

(*
    TRrParams       struc
    TRrOldBP            dw      ?
    TRrReturnAddr       dd      ?
    TRrString           db      ArrayParamSize dup (?)
    TRrParams       ends
*)
    CODE(
         01EH,            (*          push    ds                           *)
         0C5H, 076H, 006H,(*          lds     si, [bp].TRrString.ArrayPtr  *)
         033H, 0C9H,      (*          xor     cx,cx                        *)
         08AH, 00CH,      (*          mov     cl, [si]                     *)
         0E3H, 017H,      (*          jcxz    TrimRearRet                  *)
         08CH, 0D8H,      (*          mov     ax, ds                       *)
         08EH, 0C0H,      (*          mov     es, ax                       *)
         08BH, 0FEH,      (*          mov     di, si                       *)
         003H, 0F9H,      (*          add     di, cx                       *)
         0B0H, 020H,      (*          mov     al, ' '                      *)
         038H, 005H,      (*          cmp     [di], al                     *)
         075H, 009H,      (*          jne     TrimRearRet                  *)
         0FDH,            (*          std                                  *)
         0F3H, 0AEH,      (*          repe    scasb                        *)
         0FCH,            (*          cld                                  *)
         074H, 001H,      (*          je      TrimRearOver1                *)
         041H,            (*          inc     cx                           *)
                          (*TrimRearOver1:                                 *)
         088H, 00CH,      (*          mov     [si], cl                     *)
                          (*TrimRearRet:                                   *)
         01FH);           (*          pop     ds                           *)

END TrimRear;




PROCEDURE Procustes(VAR Target:ARRAY OF CHAR; Length:CARDINAL);
VAR
    l                       : CARDINAL;

BEGIN
    CheckLength(Target);
    IF (Length > HIGH(Target)) THEN FatalError END;

    IF (ORD(Target[0]) > Length) THEN
        LJust(Target);
        Target[0] := CHR(Length);
    END;
    l := ORD(Target[0]);
    WHILE (l < Length) DO
        INC(l);
        Target[l] := " ";
    END;
    Target[0] := CHR(Length);

(*
    PctParams       struc
    PctOldBP            dw      ?
    PctReturnAddr       dd      ?
    PctLength           db      CardValueParamSize dup (?)
    PctString           db      ArrayParamSize dup (?)
    PctParams       ends
*)
(*
  CODE(
      09CH,                      (*     pushf                                              *)
      0FCH,                      (*     cld                                                *)
      0C5H, 076H, 008H,          (*     lds     si, [bp].PctString.ArrayPtr                *)
      08CH, 0DAH,                (*     mov     dx, ds                                     *)
      08EH, 0C2H,                (*     mov     es, dx                                     *)
      08BH, 056H, 006H,          (*     mov     dx, [bp].PctLength.CardValue               *)
      08AH, 00CH,                (*     mov     cl, [si]                                   *)
      088H, 014H,                (*     mov     [si], dl                                   *)
      0B5H, 000H,                (*     mov     ch, 0                                      *)
      03BH, 0CAH,                (*     cmp     cx, dx                                     *)
      074H, 02EH,                (*     je      ProcustesRet                               *)
      072H, 01FH,                (*     jb      ProcustesOver1                             *)
      08BH, 0D1H,                (*     mov     dx, cx                                     *)
      046H,                      (*     inc     si                                         *)
      0B0H, 020H,                (*     mov     al, ' '                                    *)
      038H, 004H,                (*     cmp     [si], al                                   *)
      075H, 023H,                (*     jne     ProcustesRet                               *)
      08BH, 0FEH,                (*     mov     di, si                                     *)
      0F3H, 0AEH,                (*     rep     scasb                                      *)
      074H, 01DH,                (*     je      ProcustesRet    ; jmp if blank line.       *)
      041H,                      (*     inc     cx                                         *)
      04FH,                      (*     dec     di                                         *)
      087H, 0F7H,                (*     xchg    si, di                                     *)
      02BH, 0D1H,                (*     sub     dx, cx                                     *)
      0F3H, 0A4H,                (*     rep     movsb                                      *)
      08BH, 0CAH,                (*     mov     cx, dx                                     *)
      0B0H, 020H,                (*     mov     al, ' '                                    *)
      0F3H, 0AAH,                (*     rep     stosb                                      *)
      0EBH, 00DH,                (*     jmp     short ProcustesRet                         *)
                                 (* ProcustesOver1:                                        *)
      08BH, 0FEH,                (*     mov     di, si                                     *)
      003H, 0F9H,                (*     add     di, cx                                     *)
      047H,                      (*     inc     di                                         *)
      02BH, 0D1H,                (*     sub     dx, cx                                     *)
      08BH, 0CAH,                (*     mov     cx, dx                                     *)
      0B0H, 020H,                (*     mov     al, ' '                                    *)
      0F3H, 0AAH,                (*     rep     stosb                                      *)
                                 (* ProcustesRet:                                          *)
      09DH                       (*     popf                                               *)
      );
*)
END Procustes;






PROCEDURE Fill     (VAR Target:ARRAY OF CHAR; Char:CHAR; Length:CARDINAL);
VAR
    i : CARDINAL;
BEGIN
    IF (Length > HIGH(Target)) THEN FatalError END;

(*
        Target[0] := CHR(Length);
        FOR i := 1 TO Length DO Target[i] := Char END;
*)
    CODE ( 8BH, 4EH, 06H,    (*  MOV  CX,[BP+06]    cx <- length      *)
           8AH, 46H, 08H,    (*  MOV  AL,[BP+08]    al <- Char        *)
           0C4H, 5EH, 0AH,   (*  LES  BX,[BP+0A]    Target            *)
           26H,              (*  ES:                                  *)
           88H, 0FH,         (*  MOV  [BX],CL    Target[0] <- Length  *)
           89H, 0DFH,        (*  MOV  DI, BX        Target            *)
           47H,              (*  INC  DI            Target[1]         *)
           0FCH,             (*  CLD                Auto-increment    *)
           0E3H, 02H,        (*  JCXZ Label 1       Skip if Len = 0   *)
           0F3H,             (*  REPZ               Repeat            *)
           0AAH,             (*  STOSB              Store bytes.      *)
                        (*     Label 1:                               *)
           090H    );        (*  NOP                                  *)
END Fill;







PROCEDURE SubStr   (VAR Source, Dest:ARRAY OF CHAR;
                    Index, Length:CARDINAL);
VAR
    i : CARDINAL;
BEGIN
    IF (Index < 1) THEN FatalError END;
    CheckLength(Source);
    i := ORD(Source[0]);
    IF (Index <= i) THEN
        DEC(i,Index-1);
        IF (Length > i) THEN Length := i END;
    ELSE
        Dest[0] := 0C;
        RETURN;
    END;

    IF (Length > HIGH(Dest)) THEN
        Length := HIGH(Dest);
        TooLong (Source);               (* 4/5/89 EGK *)
    END;

    Dest[0] := CHR(Length);


(*
    FOR i := 1 TO Length DO
        Dest[i] := Source[Index+i-1]
    END;
*)

    CODE(
      1EH,               (* PUSH DS          ; Save Data Segment Reg. *)
      8BH, 4EH, 06H,     (* MOV  CX,[BP+06]  ; Length                 *)
      0C4H, 7EH, 0AH,    (* LES  DI,[BP+0A]  ; ES:DI-->Dest           *)
      47H,               (* INC  DI          ; ES:DI-->Dest[1]        *)
      8BH, 5EH, 08H,     (* MOV  BX,[BP+8]   ; BX := Index            *)
      0C5H, 76H, 10H,    (* LDS  SI,[BP+10]  ; DS:SI-->Source         *)
      01H, 0DEH,         (* ADD  SI,BX       ; DS:SI-->Source[Index]  *)
      0FCH,              (* CLD              ; Auto-increment         *)
      0F3H,              (* REP              ; Repeat the following   *)
      0A4H,              (* MOVSB            ; Move DS:SI-->ES:DI     *)
      1FH   );           (* POP  DS          ; Restore Data Segment   *)

END SubStr;





PROCEDURE Upshift  (VAR Target:ARRAY OF CHAR);
VAR
    i : CARDINAL;
BEGIN
    CheckLength(Target);
    ConvertString(Target,UpshiftTable);
(*
    FOR i := 1 TO ORD(Target[0]) DO
        Target[i] := CAP(Target[i])
    END;
*)
(*
    CODE (01EH,        (* PUSH     DS          SAVE THE DS REGISTER          *)
          0C5H,76H,06H,(* LDS      SI,[BP+6]   GET ADDRESS OF TARGET         *)
          29H,0C9H,    (* SUB      CX,CX       CLEAR THE CX REGISTER         *)
          8AH,0CH,     (* MOV      CL,[SI]     GET TARGET[0], THE LENGTH     *)
          0E3H, 13H,   (* JCXZ #3              Jump to exit.                 *)
                       (* LABEL #2:                                          *)
          46H,         (* INC      SI          MOVE TO NEXT CHAR OF TARGET   *)
          8AH,04H,     (* MOV      AL,[SI]     GET THAT ELEMENT OF TARGET    *)
          3CH,61H,     (* CMP      AL,61H      COMPARE CHARACTER TO 'a'      *)
          7CH,06H,     (* JL       #1          JUMP IF LESS THAN 'a'         *)
          3CH,7AH,     (* CMP      7AH         COMPARE CHARACTER TO 'z'      *)
          7FH,02H,     (* JG       #1          JUMP IF GREATER THAN 'z'      *)
          24H,5FH,     (* AND      AL,5F       CONVERT TO UPPER CASE         *)
                       (* LABEL #1:                                          *)
          88H,04H,     (* MOV      [SI],AL     PUT IT BACK INTO TARGET       *)
          0FEH,0C9H,   (* DEC      CL          COUNT THE LENGTH DOWN TO ZERO *)
          7FH,0EDH,    (* JG       #2          JUMP IF GREATER THAN ZERO     *)
                       (*  Label #3                                          *)
          01FH);       (* POP      DS          RESTORE THE VALUE OF DS       *)
    *)
END Upshift;





PROCEDURE StoC     (VAR Source:ARRAY OF CHAR; VAR Index: CARDINAL):CARDINAL;
VAR
        Card    :   CARDINAL;           (* It is used in inline assemble *)
    n           : CARDINAL;

BEGIN
    CheckLength(Source);

    Card := 0;
    WHILE (Index <= ORD(Source[0])) AND
          (Source[Index] = " ") DO        INC(Index)
    END;
    WHILE (Index <= ORD(Source[0])) AND
          (Source[Index] >= "0")    AND
          (Source[Index] <= "9")         DO
        n := ORD(Source[Index]) - ORD("0");
        IF (Card > 6553) OR ((Card = 6553) AND (n > 5)) THEN
            RETURN 65535;
        END;
        Card := (Card * 10) + n;
        INC(Index)
    END;
    RETURN Card;

(*
    STCParams       struc
    STCOldBP            dw      ?
    STCReturnAddr       dd      ?
    STCIndex            db      CardReferneceParamSize dup (?)
    STCString           db      ArrayParamSize dup (?)
    STCParams       ends
*)
(*
  CODE(
      09CH,             (*     pushf                                               *)
      0FCH,             (*     cld                                                 *)
      0C5H, 076H, 00AH, (*     lds     si, [bp].STCString.ArrayPtr                 *)
      0C4H, 07EH, 006H, (*     les     di, [bp].STCIndex.CardPtr                   *)
      026H, 08BH, 03DH, (*     mov     di, es:[di]                                 *)
      0B5H, 000H,       (*     mov     ch, 0                                       *)
      08AH, 00CH,       (*     mov     cl, [si]                                    *)
      089H, 04EH, 0FEH, (*     mov     [bp - 2], cx                                *)
      003H, 0F7H,       (*     add     si, di                                      *)
                        (* StoCLoop2:                                              *)
      08AH, 00CH,       (*         mov     cl, [si]                                *)
      080H, 0F9H, 020H, (*         cmp     cl, ' '                                 *)
      075H, 014H,       (*         jne     StoCOver2                               *)
      046H,             (*         inc     si                                      *)
      047H,             (*         inc     di                                      *)
      039H, 07EH, 0FEH, (*         cmp     [bp - 2], di                            *)
      073H, 0F2H,       (*     jae     short StoCLoop2                             *)
      08BH, 0CFH,       (*     mov     cx, di                                      *)
      0C4H, 07EH, 006H, (*     les     di, [bp].STCIndex.CardPtr                   *)
      026H, 089H, 00DH, (*     mov     es:[di], cx                                 *)
      0B8H, 000H, 000H, (*     mov     ax, 0                                       *)
      0EBH, 041H,       (*     jmp     short StoCRet                               *)
                        (* StoCOver2:                                              *)
      0B8H, 000H, 000H, (*     mov     ax, 0                                       *)
      0B5H, 000H,       (*     mov     ch, 0                                       *)
      0BBH, 00AH, 000H, (*     mov     bx, 10                                      *)
                        (* StoCLoop:                                               *)
      08AH, 00CH,       (*         mov     cl, [si]                                *)
      080H, 0F9H, 039H, (*         cmp     cl, '9'                                 *)
      077H, 02AH,       (*         ja      StoCOver1                               *)
      080H, 0F9H, 030H, (*         cmp     cl, '0'                                 *)
      072H, 025H,       (*         jb      StoCOver1                               *)
      080H, 0E9H, 030H, (*         sub     cl, '0'                                 *)
      0F7H, 0E3H,       (*         mul     bx                                      *)
      003H, 0C1H,       (*         add     ax, cx                                  *)
      083H, 0D2H, 000H, (*         adc     dx, 0                                   *)
      083H, 0FAH, 000H, (*         cmp     dx, 0                                   *)
      075H, 009H,       (*         jne     StoCOver3                               *)
      046H,             (*         inc     si                                      *)
      047H,             (*         inc     di                                      *)
      039H, 07EH, 0FEH, (*         cmp     [bp - 2], di                            *)
      073H, 0DEH,       (*     jae     StoCLoop                                    *)
      0EBH, 00DH,       (*     jmp     short StoCOver1                             *)
                        (* StoCOver3:                                              *)
      08BH, 0CFH,       (*     mov     cx, di                                      *)
      0C4H, 07EH, 006H, (*     les     di, [bp].STCIndex.CardPtr                   *)
      026H, 089H, 00DH, (*     mov     es:[di], cx                                 *)
      0B8H, 0FFH, 0FFH, (*     mov     ax, -1                                      *)
      0EBH, 08H,        (*     jmp     short StoCRet                               *)
                        (* StoCOver1:                                              *)
      08BH, 0CFH,       (*     mov     cx, di                                      *)
      0C4H, 07EH, 006H, (*     les     di, [bp].STCIndex.CardPtr                   *)
      026H, 089H, 00DH, (*     mov     es:[di], cx                                 *)
                        (* StoCRet:                                                *)
      09DH              (*     popf                                                *)
      );
    GETREG(AX, Card);
    RETURN Card;
*)
END StoC;




PROCEDURE CtoS     (Card:CARDINAL; VAR String:ARRAY OF CHAR);
VAR
    i,j : CARDINAL;
    digits : ARRAY [0..5] OF CHAR;    (* Assume max. is 65535 *)
BEGIN
(*
    j := 0;
    REPEAT
        digits[j] := CHR(ORD("0")+(Card MOD 10));
        Card := Card DIV 10;
        INC(j);
    UNTIL (Card = 0);
*)
    (*  New version inspired by code from Symantec, Cupertino is below 
    CODE(29H,0F6H,      (* SUB     SI,SI       SI = 0 FOR TARGET[0]          *)
         8BH,46H,0CH,   (* MOV     AX,[BP+0C]  VALUE OF CARD TO AX           *)
         0BFH,0AH,00H,  (* MOV     DI,0AH      WE WILL BE DIVIDING BY 10     *)
         (* LABEL #1 *)
         29H,0D2H,      (* SUB     DX,DX       MUST BE ZERO FOR THE DIVIDE   *)
         0F7H,0F7H,     (* DIV     DI          DIVIDE BY 10, DX = REMAINDER  *)
         83H,0C2H,30H,  (* ADD     DX,30H      ADD ORD("0")                  *)
         88H,52H,0FAH,  (* MOV     [BP-6][SI],DL     SAVE CHAR. IN DIGITS    *)
         46H,           (* INC     SI          MOVE TO NEXT ELEMENT OF DIGIT *)
         09H,0C0H,      (* OR      AX,AX       THE QUOTIENT IS LEFT IN AX,   *)
         75H,0F1H,      (* JNZ     #1          LOOP UNTIL IT IS ZERO         *)
         89H,76H,0F8H); (* MOV     [BP-08],SI  SAVE THE NUMBER OF CHAR. IN J *)

    IF (j > HIGH(String)) THEN FatalError END;

(*
    FOR i := 1 TO j DO
        String[i] := digits[j-i]
    END;
    String[0] := CHR(j);
*)

    CODE(0C4H,7EH,06H,  (* LES     DI,[BP+06]  ADDRESS OF STRING[0]          *)
         8BH,4EH,0F8H,  (* MOV     CX,[BP-08]  VALUE OF J                    *)
         26H,           (* ES:                                               *)
         88H,0DH,       (* MOV     [DI],CL     SAVE J IN STRING[0]           *)
         89H,0CEH,      (* MOV     SI,CX       USE j AS INDEX INTO DIGITS    *)
         (* LABEL #2 *)
         47H,           (* INC     DI          NEXT POSITION IN STRING       *)
         4EH,           (* DEC     SI          PREVIOUS POSITION IN DIGITS   *)
         8AH,42H,0FAH,  (* MOV     AL,[BP-6][SI]  MOVE A CHARACTER AT A TIME *)
         26H,           (* ES:                                               *)
         88H,05H,       (* MOV     [DI],AL     FROM DIGITS TO STRING         *)
         0E2H,0F6H);    (* LOOP    #2          LOOP UNTIL ALL DIGITS COPIED  *)

    Here comes the new Cupertino-inspired code *)

    CODE(
    0FCH,             (*                CLD                   ;So STOSB autoincrements        *)
    08BH, 046H, 00CH, (*                MOV   AX, [BP+0CH]    ;Cardinal into AX               *)
    02BH, 0C9H,       (*                SUB   CX, CX          ;CX counts # of digits          *)
    0BEH, 00AH, 000H, (*                MOV   SI, 10          ;Base 10                        *)
    
    041H,             (*DivisionLoop:   INC   CX              ;There will be > 1 digit        *)
    02BH, 0D2H,       (*                SUB   DX, DX          ;Prepare to divide AX           *)
    0F7H, 0F6H,       (*                DIV   SI              ;Divide AX by 10                *)
    080H, 0C2H, 030H, (*                ADD   DL, '0'         ;Remainder in DX                *)
    052H,             (*                PUSH  DX              ;Save in reverse of final order *)
    00BH, 0C0H,       (*                OR    AX, AX          ;Quotient stays in AX           *)
    075H, 0F3H,       (*                JNZ   DivisionLoop    ;Loop until zero                *)
    
    0C4H, 07EH, 006H, (*                LES   DI, [BP+06]     ;Address of String[0]           *)
    08BH, 0C1H,       (*                MOV   AX, CX                                          *)
    0AAH,             (*                STOSB                 ;Save string length             *)
                                 
    058H,             (*SaveString:     POP   AX              ;Get string in final order      *)
    0AAH,             (*                STOSB                 ;Put into String                *)
    0E2H, 0FCH        (*                LOOP  SaveString                                      *)
    );

END CtoS;




PROCEDURE Remove(VAR Target: ARRAY OF CHAR; Index, Length:CARDINAL);
VAR
    i, j                    : CARDINAL;

BEGIN
    IF (Index < 1) OR
       (Index > HIGH(Target)) OR
       (Length > MAXCARDINAL - Index) THEN FatalError END;
    CheckLength(Target);


    i := Index;
    j := i + Length;
    WHILE (j <= ORD(Target[0]) ) DO
        Target[i] := Target[j];
        INC(i);
        INC(j);
    END;

        (* j = ORD(Target[0])+1
           i = Index +   ORD(Target[0]) - Index - Length + 1
             = ORD(Target[0]) - Length + 1
         *)

    Target[0] := CHR(i-1);


(*
    RmvParams       struc
    RmvOldBP            dw      ?
    RmvReturnAddr       dd      ?
    RmvLength           db      CardValueParamSize dup (?)
    RmvIndex            db      CardValueParamSize dup (?)
    RmvString           db      ArrayParamSize dup (?)
    RmvParams       ends
*)
(*
  CODE(
      09CH,                      (*     pushf                                                          *)
      0FCH,                      (*     cld                                                            *)
      0C5H, 05EH, 00AH,          (*     lds     bx, [bp].RmvString.ArrayPtr                            *)
      08BH, 056H, 008H,          (*     mov     dx, [bp].RmvIndex.CardValue                            *)
      03AH, 017H,                (*     cmp     dl, [bx]                                               *)
      077H, 029H,                (*     ja      RemoveRet                                              *)
      08BH, 0FBH,                (*     mov     di, bx                                                 *)
      003H, 0FAH,                (*     add     di, dx                                                 *)
      08BH, 04EH, 006H,          (*     mov     cx, [bp].RmvLength.CardValue                           *)
      003H, 0CAH,                (*     add     cx, dx                                                 *)
      080H, 0FDH, 000H,          (*     cmp     ch, 0                                                  *)
      075H, 017H,                (*     jne     RemoveOver1         ; jmp if pass end of string.       *)
      03AH, 00FH,                (*     cmp     cl, [bx]                                               *)
      077H, 013H,                (*     ja      RemoveOver1         ; jmp if pass end of string.       *)
      08BH, 0F3H,                (*     mov     si, bx                                                 *)
      003H, 0F1H,                (*     add     si, cx                                                 *)
      08AH, 007H,                (*     mov     al, [bx]                                               *)
      02AH, 0C1H,                (*     sub     al, cl                                                 *)
      08AH, 0C8H,                (*     mov     cl, al                                                 *)
      002H, 0C2H,                (*     add     al, dl                                                 *)
      088H, 007H,                (*     mov     [bx], al                                               *)
      041H,                      (*     inc     cx                                                     *)
      0F3H, 0A4H,                (*     rep     movsb                                                  *)
      0EBH, 004H,                (*     jmp     short RemoveRet                                        *)
                                 (* RemoveOver1:                                                       *)
      0FEH, 0CAH,                (*     dec     dl                                                     *)
      088H, 017H,                (*     mov     [bx], dl                                               *)
                                 (* RemoveRet:                                                         *)
      09DH                       (*     popf                                                           *)
      );
*)
END Remove;




PROCEDURE Insert(VAR Target, Addend: ARRAY OF CHAR; Index:CARDINAL);
VAR
    i,AddendLength, TargetLength : CARDINAL;
BEGIN
    CheckLength(Target);
    CheckLength(Addend);
    AddendLength := ORD(Addend[0]);
    TargetLength := ORD(Target[0]);
    IF (AddendLength+TargetLength > HIGH(Target)) THEN
        TooLong(Target);
        TooLong(Addend);
        RETURN;                  (* AJL 2/29/88 *)
    END;
    IF (Index < 1) OR (Index > TargetLength+1) THEN FatalError END;

(*
    FOR i := TargetLength TO Index BY -1 DO
         Target[i+AddendLength] := Target[i];
    END;
    FOR i := 1 TO AddendLength DO
        Target[Index] := Addend[i];
        INC(Index);
    END;

    Target[0] := CHR(TargetLength + AddendLength);
*)


(*<DOS*)
    CODE(01EH,          (* PUSH    DS       SAVE THE DS VALUE                *)
         8BH,4EH,0FEH,  (* MOV     CX,[BP-02]  TARGETLENGTH - INDEX + 1 IS   *)
         2BH,4EH,06H,   (* SUB     CX,[BP+06]  THE COUNT FOR MAKING SPACE IN *)
         41H,           (* INC     CX          THE TARGET STRING             *)
         0C5H,76H,0EH,  (* LDS     SI,[BP+0E]  GET THE ADDR. OF TARGET AND   *)
         03H,76H,0FEH,  (* ADD     SI,[BP-02]  GO TO THE END OF IT.          *)
         0C4H,7EH,0EH,  (* LES     DI,[BP+0E]  NOW POINT PAST THE END OF     *)
         03H,7EH,0FEH,  (* ADD     DI,[BP-02]  TARGET BY THE LENGTH OF THE   *)
         03H,7EH,0FCH,  (* ADD     DI,[BP-04]  ADDEND.                       *)
         0FDH,          (* STD                 SET   DIR. FOR REVERSE MOVE   *)
         0F3H,0A4H,     (* REP     MOVSB       OPEN UP SPACE IN TARGET       *)
         0FCH,          (* CLD                 CLR DIR. FOR FORWARD MOVE     *)
         0C5H,76H,08H,  (* LDS     SI,[BP+08]  POINT SI TO THE START OF      *)
         46H,           (* INC     SI          ADDEND.                       *)
         0C4H,7EH,0EH,  (* LES     DI,[BP+0E]  START OFF AT TARGET[INDEX]    *)
         03H,7EH,06H,   (* ADD     DI,[BP+06]                                *)
         8BH,4EH,0FCH,  (* MOV     CX,[BP-04]  MOVE ADDENDLENGTH BYTES       *)
         0F3H,0A4H,     (* REP     MOVSB       APPEND ADDEND TO TARGET       *)
         8BH,46H,0FEH,  (* MOV     AX,[BP-02]  PUT TARGETLENGTH+ADDENDLENGTH *)
         03H,46H,0FCH,  (* ADD     AX,[BP-04]  INTO TARGET[0]                *)
         0C5H,7EH,0EH,  (* LDS     DI,[BP+0E]                                *)
         88H,05H,       (* MOV     [DI],AL                                   *)
         01FH);         (* POP     DS          RESTORE THE VALUE OF DS       *)
(*DOS>*)

(*<OS2
    CODE(8CH,0D8H,	    (* MOV	   AX,DS       SAVE THE DS VALUE	     *)
	     50H,		    (* PUSH    AX					     *)
	     8BH,4EH,0FCH,	(* MOV	   CX,[BP-04]  TARGETLENGTH - INDEX + 1 IS   *)
	     2BH,4EH,06H,	(* SUB	   CX,[BP+06]  THE COUNT FOR MAKING SPACE IN *)
	     41H,		    (* INC	   CX	       THE TARGET STRING	         *)
	     0C5H,76H,0EH,	(* LDS	   SI,[BP+0E]  GET THE ADDR. OF TARGET AND   *)
	     03H,76H,0FCH,	(* ADD	   SI,[BP-04]  GO TO THE END OF IT.	         *)
	     0C4H,7EH,0EH,	(* LES	   DI,[BP+0E]  NOW POINT PAST THE END OF     *)
	     03H,7EH,0FCH,	(* ADD	   DI,[BP-04]  TARGET BY THE LENGTH OF THE   *)
	     03H,7EH,0FAH,	(* ADD	   DI,[BP-06]  ADDEND.			             *)
	     0FDH,		    (* STD		       SET   DIR. FOR REVERSE MOVE       *)
	     0F3H,0A4H,	    (* REP	   MOVSB       OPEN UP SPACE IN TARGET	     *)
	     0FCH,		    (* CLD		       CLR DIR. FOR FORWARD MOVE         *)
	     0C5H,76H,08H,	(* LDS	   SI,[BP+08]  POINT SI TO THE START OF      *)
	     46H,		    (* INC	   SI	       ADDEND.			             *)
	     0C4H,7EH,0EH,	(* LES	   DI,[BP+0E]  START OFF AT TARGET[INDEX]    *)
	     03H,7EH,06H,	(* ADD	   DI,[BP+06]				                 *)
	     8BH,4EH,0FAH,	(* MOV	   CX,[BP-06]  MOVE ADDENDLENGTH BYTES	     *)
	     0F3H,0A4H,	    (* REP	   MOVSB       APPEND ADDEND TO TARGET	     *)
	     8BH,46H,0FCH,	(* MOV	   AX,[BP-04]  PUT TARGETLENGTH+ADDENDLENGTH *)
	     03H,46H,0FAH,	(* ADD	   AX,[BP-06]  INTO TARGET[0]		         *)
	     0C5H,7EH,0EH,	(* LDS	   DI,[BP+0E]				                 *)
	     88H,05H,	    (* MOV	   [DI],AL				                     *)
	     58H,		    (* POP	   AX	       RESTORE THE VALUE OF DS	     *)
	     8EH,0D8H);	    (* MOV	   DS,AX				                     *)
OS2>*)

END Insert;




    (*$S-*)    (* No stack check.  Speed!!!! *)
(*$O+*) 
PROCEDURE Compare (VAR First, Second: ARRAY OF CHAR) : INTEGER;
VAR
    L1, L2, i:  INTEGER;
BEGIN
    L1 := ORD(First[0]);
    L2 := ORD(Second[0]);

    i := 1;
    LOOP
        IF (i > L1) THEN
            IF (i > L2) THEN RETURN 0
            ELSE RETURN -i
            END
        ELSIF (i > L2) THEN
            RETURN i
        ELSIF (First[i] = Second[i]) THEN
        ELSIF (ConvertedCharacter(First[i],SortOrderTable) <
               ConvertedCharacter(Second[i],SortOrderTable)) THEN RETURN -i
        ELSE RETURN i
        END;
        INC(i);
    END;



(*
    CODE(1EH,           (* PUSH    DS          SAVE THE VALUE OF DS          *)
         29H,0DBH,      (* SUB     BX,BX       DEFAULT RETURN CODE OF 0      *)
         8BH,4EH,0FAH,  (* MOV     CX,[BP-06]  COMPARE L1 TO L2 AND CHOOSE   *)
         3BH,4EH,0FCH,  (* CMP     CX,[BP-04]  THE SMALLEST.                 *)
         7EH,03H,       (* JLE     #1                                        *)
         8BH,4EH,0FCH,  (* MOV     CX,[BP-04]                                *)
         (* LABEL #1 *)
         0C5H,76H,0CH,  (* LDS     SI,[BP+0C]  POINT SI TO FIRST             *)
         0C4H,7EH,06H,  (* LES     DI,[BP+06]  POINT DI TO SECOND            *)
         29H,0D2H,      (* SUB     DX,DX       USE DX AS I, THE COUNTER      *)
         0E3H, 0FH,     (* JCXZ    #3          Check for a null string.      *)
         0FCH,          (* CLD                 CLEAR THE DIRECTION FLAG      *)
         46H,           (* INC     SI          POINT TO FIRST[1]             *)
         47H,           (* INC     DI          POINT TO SECOND[1]            *)
         (* LABEL #2 *)
         42H,           (* INC     DX          THIS KEEPS THE COUNT OF I     *)
         0A6H,          (* CMPSB               COMPARE BYTES AND SET FLAGS   *)
         0E1H,0FCH,     (* LOOPZ   #2          LOOP UNTIL NOT EQUAL          *)
         074H,06H,      (* JZ      #3          JUMP IF STRINGS ARE EQUAL     *)
         7FH,0FH,       (* JG      #4          JUMP IF FIRST > SECOND        *)
         (* LABEL #5 *)
         0F7H,0DAH,     (* NEG     DX          PREPARE TO RETURN -I          *)
         0EBH,0BH,      (* JMP     #4          GO TO EXIT                    *)
         (* LABEL #3 *)
         42H,           (* INC     DX          STRINGS EQUAL, BUT LENGTHS?   *)
         8BH,46H,0FAH,  (* MOV     AX,[BP-06]  COMPARE L1 TO L2.  IF THEY'RE *)
         3BH,46H,0FCH,  (* CMP     AX,[BP-04]  EQUAL, THE WHOLE STRINGS MATCH*)
         74H,04H,       (* JZ      #7          EXIT, RETURN DEFAULT OF 0     *)
         7CH,0F1H,      (* JL      #5          L1 < L2, RETURN -I            *)
         (* LABEL #4 *)
         89H,0D0H,      (* MOV     AX,DX       RETURNS I OR -I IN AX         *) 
         (* LABEL #7 *)
         1FH);          (* POP     DS          RESTORE VALUE OF DX           *) 
*)
END Compare;
(*$O=*) 

    (*$S=*)



PROCEDURE LStringToTString (VAR LString, TString: ARRAY OF CHAR);
VAR
    i,j : CARDINAL;
BEGIN
    CheckLength(LString);
    j := ORD(LString[0]);
    IF (j > HIGH(TString)) THEN
        TooLong(LString);
        j := HIGH(TString);    (* AJL 2/29/88 *)
    END;
(*                                                                (* 04-Sep-89 LAA *)
    IF (j > 0) THEN                                               (* 17-Sep-87 LAA *)
        FOR i := 0 TO j-1 DO TString[i] := LString[i+1] END;
    END;
    TString[j] := CHR(0);
*)

(*
    LTTParams       struc
    LTTOldBP            dw      ?
    LTTReturnAddr       dd      ?
    LTTTString          db      ArrayParamSize dup (?)
    LTTLString          db      ArrayParamSize dup (?)
    LTTParams       ends
*)

    SETREG(CX, j);       (* Pick up the (possibly modified) length to move *)

    CODE(
      01EH,                    (*     push    DS                                 *)
      0C5H, 076H, 0CH,         (*     lds     si, [bp].LTTLString.ArrayPtr       *)
      0C4H, 07EH, 06H,         (*     les     di, [bp].LTTTString.ArrayPtr       *)
      046H,                    (*     inc     si                                 *)
      0FCH,                    (*     cld                                        *)
      0F3H, 0A4H,              (*     rep     movsb                              *)
      026H, 0C6H, 05H, 00H,    (*     mov     byte ptr es:[di], NULL             *)
      01FH);                   (*     pop     DS                                 *)

END LStringToTString;





PROCEDURE TStringToLString(VAR TString, LString : ARRAY OF CHAR);
VAR
    i, Len : CARDINAL;
BEGIN
    Len := 0;
    WHILE (Len <= HIGH(TString)) AND (TString[Len] <> 0C) DO
        INC(Len);
    END;
    IF (Len > HIGH(LString)) THEN FatalError; END;

    i := Len;
    FOR i := Len TO 1 BY -1 DO
        LString[i] := TString[i-1];
    END;
    LString[0] := CHR(Len);

(*
    TTLParams       struc
    TTLOldBP            dw      ?
    TTLReturnAddr       dd      ?
    TTLLString          db      ArrayParamSize dup (?)
    TTLTString          db      ArrayParamSize dup (?)
    TTLParams       ends
*)
(*
  CODE(
      09CH,                (*      pushf                                    *)
      0FCH,                (*      cld                                      *)
      0C4H, 07EH, 00CH,    (*      les     di, [bp].TTLTString.ArrayPtr     *)
      0B0H, 000H,          (*      mov     al, NULL                         *)
      0B9H, 0FFH, 0FFH,    (*      mov     cx, -1                           *)
      0F2H, 0AEH,          (*      repnz   scasb                            *)
      0F7H, 0D9H,          (*      neg     cx                               *)
      049H,                (*      dec     cx                               *)
      049H,                (*      dec     cx                               *)
      0C5H, 076H, 00CH,    (*      lds     si, [bp].TTLTString.ArrayPtr     *)
      0C4H, 07EH, 006H,    (*      les     di, [bp].TTLLString.ArrayPtr     *)
      08BH, 0D1H,          (*      mov     dx, cx                           *)
      003H, 0F1H,          (*      add     si, cx                           *)
      003H, 0F9H,          (*      add     di, cx                           *)
      04EH,                (*      dec     si                               *)
      0FDH,                (*      std                                      *)
      0F3H, 0A4H,          (*      rep     movsb                            *)
      0C4H, 07EH, 006H,    (*      les     di, [bp].TTLLString.ArrayPtr     *)
      026H, 088H, 015H,    (*      mov     es:[di], dl                      *)
                           (*  TStringToLStringRet:                         *)
      09DH                 (*      popf                                     *)
      );
*)
END TStringToLString;





PROCEDURE Overlay (VAR Dest, Source : ARRAY OF CHAR; Index, Len : CARDINAL);
VAR
    i, j : CARDINAL;
    s                   : ARRAY [0..255] OF CHAR;

BEGIN
    i := HIGH(Dest);                      (* used to be ORD(Dest[0]) 03-Jul-87 LAA *)
    j := ORD(Source[0]);
    IF (Index < 1) OR
    (* (i > HIGH(Dest)) OR *)                                     (* 03-Jul-87 LAA *)
       (j > HIGH(Source)) THEN FatalError END;

    IF (Index <= i) THEN
        IF (Index > LengthOf(Dest)) THEN                          (* 03-Jul-87 LAA *)
            Fill(s, " ", Index - LengthOf(Dest) - 1);
            ConcatLS(Dest, s);
        END;
        DEC(i,Index-1);
        IF (Len > i) THEN Len := i END;
        IF (Len > j) THEN Len := j END;
        IF (Index + Len - 1 > LengthOf(Dest)) THEN                (* 03-Jul-87 LAA *)
            SetLengthOf(Dest, Index + Len - 1);                   
        END;
    ELSE
        Len := 0
    END;
(*
    FOR i := 1 TO Len DO
        Dest[Index] := Source[i];
        INC(Index);
    END
*)
    CODE(
      1EH,               (* PUSH DS          ; Save Data Segment Reg. *)
      8BH, 4EH, 06H,     (* MOV  CX,[BP+06]  ; Length                 *)
      8BH, 5EH, 08H,     (* MOV  BX,[BP+8]   ; BX := Index            *)
      0C4H, 7EH, 10H,    (* LES  DI,[BP+10]  ; ES:DI-->Dest           *)
      01H, 0DFH,         (* ADD  DI,BX       ; ES:DI-->Dest[Index]    *)
      0C5H, 76H, 0AH,    (* LDS  SI,[BP+0A]  ; DS:SI-->Source         *)
      46H,               (* INC  SI          ; DS:SI-->Source[1]      *)
      0FCH,              (* CLD              ; Auto-increment         *)
      0F3H,              (* REP              ; Repeat the following   *)
      0A4H,              (* MOVSB            ; Move Source to Dest    *)
      1FH   );           (* POP  DS          ; Restore Data Segment   *)


END Overlay;




    (*  Search the LString s for the pattern.  Return the index of the
        position within s that the first occurrance of pattern appears,
        or 0 if pattern is not within s.  Searching starts at index
        "Start" within s.  If "pattern" is of zero length, a 0 is
        returned. *)

PROCEDURE Search (VAR s, pattern : ARRAY OF CHAR; Start:CARDINAL) : CARDINAL;
VAR
    c : CHAR;
    i, j : CARDINAL;
    lens, lenp : CARDINAL;
BEGIN
    lens := ORD(s[0]);
    lenp := ORD(pattern[0]);
    IF (lens > HIGH(s)) OR (lenp > HIGH(pattern)) THEN FatalError END;
        (* Must check lenp > lens because both are CARDINAL numbers and
           "lens - lenp" in the loop below may not be valid otherwise. *)
    IF (lenp = 0) OR (lenp > lens) THEN RETURN 0; END;
        (*  The invarient for this loop is "pattern does not match
            for any position < i in s." *)
    IF lens = 0 THEN RETURN 0; END;

(*
    c := pattern[1];
    FOR i := Start TO lens - lenp + 1 DO
        IF (c = s[i]) THEN
            j := 1;
                (*  The invarient for this loop is that pattern matches
                    string at s[i] for at least j characters. *)
            REPEAT
                INC(j);
                IF (j > lenp) THEN RETURN i END;
            UNTIL (pattern[j] <> s[i+j-1]);
        END;
    END;
    RETURN 0;
*)  

(*<OS2
    CODE(1EH,		    (* PUSH    DS	       SAVE THE DS VALUE	         *)
	     8BH,56H,06H,	(* MOV	   DX,[BP+06]  USE DX AS I, THE CHAR INDEX   *)
	     8BH,5EH,0FAH,	(* MOV	   BX,[BP-06]  PUT LENS-LENP+1 INTO BX	     *)
	     2BH,5EH,0FCH,	(* SUB	   BX,[BP-04]				                 *)
	     43H,		    (* INC	   BX					                     *)
	     (* LABEL #4 *)
	     39H,0DAH,	    (* CMP	   DX,BX       I > LENS-LENP+1?  FINISHED!   *)
	     7FH,14H,	    (* JG	   #1					                     *)
	     0C5H,76H,0EH,	(* LDS	   SI,[BP+0E]  SI POINTS TO S		         *)
	     0C4H,7EH,08H,	(* LES	   DI,[BP+08]  DI POINTS TO PATTERN	         *)
	     8BH,4EH,0FCH,	(* MOV	   CX,[BP-04]  COMPARE LENP BYTES	         *)
	     01H,0D6H,	    (* ADD	   SI,DX       THIS ADDRESSES S[I]	         *)
	     47H,		    (* INC	   DI	       ADDRESS PATTERN[1]	         *)
	     (* LABEL #2 *)
	     0A6H,		    (* CMPSB	       COMPARE S TO PATTERN UNTIL        *)
	     0E1H,0FDH,	    (* LOOPZ   #2	       UNEQUAL OR PATTERN EXHAUSTED  *)
	     074H,05H,	    (* JE	   #3	       Pattern Exhausted, but still =*)
	     42H,		    (* INC	   DX	       NEXT I			             *)
	     0EBH,0E8H,	    (* JMP	   #4	       BACK TO BEGINNING OF LOOP     *)
	     (* LABEL #1 *)
	     29H,0D2H,	    (* SUB	   DX,DX       I = 0 FOR RETURN OF 0	     *)
	     (* LABEL #3 *)
	     89H,56H,0F6H,	(* MOV	   [BP-0A],DX	MOVE RETURN VALUE INTO I     *)
	     1FH);		    (* POP	   DS	       RESTORE VALUE OF DS REG.      *)
OS2>*)

(*<DOS*)
    CODE(1EH,           (* PUSH    DS          SAVE THE DS VALUE             *)
         8BH,56H,06H,   (* MOV     DX,[BP+06]  USE DX AS I, THE CHAR INDEX   *)
         8BH,5EH,0FCH,  (* MOV     BX,[BP-04]  PUT LENS-LENP+1 INTO BX       *)
         2BH,5EH,0FEH,  (* SUB     BX,[BP-02]                                *)
         43H,           (* INC     BX                                        *)
         (* LABEL #4 *)
         39H,0DAH,      (* CMP     DX,BX       I > LENS-LENP+1?  FINISHED!   *)
         7FH,14H,       (* JG      #1                                        *)
         0C5H,76H,0EH,  (* LDS     SI,[BP+0E]  SI POINTS TO S                *)
         0C4H,7EH,08H,  (* LES     DI,[BP+08]  DI POINTS TO PATTERN          *)
         8BH,4EH,0FEH,  (* MOV     CX,[BP-02]  COMPARE LENP BYTES            *)
         01H,0D6H,      (* ADD     SI,DX       THIS ADDRESSES S[I]           *)
         47H,           (* INC     DI          ADDRESS PATTERN[1]            *)
         (* LABEL #2 *)
         0A6H,          (* CMPSB               COMPARE S TO PATTERN UNTIL    *)
         0E1H,0FDH,     (* LOOPZ   #2          UNEQUAL OR PATTERN EXHAUSTED  *)
         074H,05H,      (* JE      #3          Pattern Exhausted, but still =*)
         42H,           (* INC     DX          NEXT I                        *)
         0EBH,0E8H,     (* JMP     #4          BACK TO BEGINNING OF LOOP     *)
         (* LABEL #1 *)
         29H,0D2H,      (* SUB     DX,DX       I = 0 FOR RETURN OF 0         *)
         (* LABEL #3 *)
         89H,56H,0F8H,  (* MOV     [BP-8],DX   MOVE RETURN VALUE INTO I      *) 
         1FH);          (* POP     DS          RESTORE VALUE OF DS REG.      *) 
(*DOS>*)

    RETURN i; 

END Search;




(*----------------------------------------------------------------------------
    Copy --

    Copy one LString into another, truncating whatever won't fit.

    Preconditions:
        The source must be an LString.

    Postconditions:
        The destination will contain as much of the beginning of the source as
        will fit.
----------------------------------------------------------------------------*)
(*$O+*) 
PROCEDURE Copy(VAR Source       : ARRAY OF CHAR;
               VAR Destination  : ARRAY OF CHAR);

BEGIN                       (* Copy *)

    SubStr(Source, Destination, 1, HIGH(Destination));

END Copy;
(*$O=*) 



(*----------------------------------------------------------------------------
    LengthOf --

    Return the length of the given LString.

    Preconditions:
        The given string must be an LString.

    Postconditions:
        The length of the LString will be returned.
----------------------------------------------------------------------------*)

(*$O+*) 
PROCEDURE LengthOf(VAR LString              : ARRAY OF CHAR): CARDINAL;

BEGIN                       (* LengthOf *)

    RETURN ORD(LString[0]);

END LengthOf;
(*$O=*) 



(*----------------------------------------------------------------------------
    SetLengthOf --

    Force the length of the given LString to be as indicated.

    Preconditions:
        The given string must be an LString.

    Postconditions:
        The length of the LString will be set to the value given.
----------------------------------------------------------------------------*)

(*$O+*) 
PROCEDURE SetLengthOf(VAR LString           : ARRAY OF CHAR;
                          Length            : CARDINAL);

BEGIN                       (* SetLengthOf *)

    LString[0] := CHR(Length);

END SetLengthOf;
(*$O=*) 


(*----------------------------------------------------------------------------
    StringsEqual --

    Compare two strings for an EXACT match.

    Preconditions:
        The given strings must be LStrings.

    Postconditions:
        Return is TRUE if LStrings EXACTLY match eatch other, FALSE otherwise
----------------------------------------------------------------------------*)
PROCEDURE StringsEqual( VAR First, Second : ARRAY OF CHAR ) : BOOLEAN;
VAR
    SaveAX          :       CARDINAL;
    Len, i          : CARDINAL;

BEGIN

(*
    Len := ORD(First[0]);
    i   := 0;             (* Compare starting with the length byte. *)
    WHILE (i <= Len) AND (First[i] = Second[i]) DO                (* 04-Jan-89 LAA *)
        INC( i );
    END;

    RETURN (i > Len);  (* If > len, then the strings are equal. *)
*)

(*
    SEqParams       struc
    SEqOldBP            dw      ?
    SEqReturnAddr       dd      ?
    SEqSecond           db      ArrayParamSize dup (?)
    SEqFirst            db      ArrayParamSize dup (?)
    SEqParams       ends
*)
    
  CODE(
      01EH,          (*     PUSH    DS                                     *)
      0C5H, 76H, 0CH,(*     LDS     si, [bp].SEqFirst.ArrayPtr             *)
      0C4H, 7EH, 06H,(*     LES     di, [bp].SEqSecond.ArrayPtr            *)
      031H, 0C9H,    (*     XOR     CX, CX           ; set CX to zero      *)
      08AH, 0CH,     (*     MOV     cl, [si]                               *)
      041H,          (*     INC     cx               ; one more for length *)
      031H, 0C0H,    (*     XOR     ax, ax           ; preset AX for False *)
      0FCH,          (*     CLD                                            *)
      0F3H, 0A6H,    (*     REPE    cmpsb                                  *)
      075H, 01H,     (*     JNE     StringsEqualRet  ; jmp if not equal    *)
      040H,          (*     INC     ax               ; make AX True        *)
                     (* StringsEqualRet:                                   *)
      01FH           (*     POP     DS                                     *)
      );

    GETREG(AX, SaveAX);

    RETURN ( SaveAX <> 0 );

END StringsEqual;







    (* ----------------------------------------------------------------

       InsertWithOverflow

       Inserts a substring into a target string at a given position.
       If that would make the result longer than MaxSize, the result
       is truncated to MaxSize.

       The index is updated to reflect the inserted string.



       Preconditions: 
                      Target and Source are LStrings.
                      MaxSize <= HIGH(Target).
                      Index > 0, <= HIGH(Target).

       Postconditions: 
                      Target is changed to Target' so that each character 
                      at position "i" in Target' is

                      = Target[i] if i < Index.
                      = undefined if i > MaxSize
                      = Source[i-Index] if i > Index and i-Index <= 
                                        LengthOf(Source)
                      else = Target[i-LengthOf(Source)]

                      LengthOf(Target') <= MaxSize provided that
                      LengthOf(Target) were <= MaxSize.

       -------------------------------------------------------------- *)





PROCEDURE InsertWithOverflow( VAR Target,
                                  Source  : ARRAY OF CHAR;
                              VAR Index   : CARDINAL;
                                  MaxSize : CARDINAL);
VAR
    i,
    SSize   : CARDINAL;
    S2      : ARRAY [0..1] OF CHAR;
BEGIN
    SSize := LengthOf(Source);

    i := 1;
    WHILE ( i <= SSize ) AND (Index <= MaxSize) DO
        Fill(S2,Source[i],1);
        Remove(Target,MaxSize,1);
        Insert(Target,S2,Index);
        INC(Index);
        INC(i);
    END;

END InsertWithOverflow;





BEGIN
END LStrings.
