IMPLEMENTATION MODULE GeldedLStrings;

(*$S+*)


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
        26-May-88 LAA   Created this Gelded version from LStrings by removing
                        imports of other parts of Time Line.
    *)



FROM SYSTEM  IMPORT CODE;



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
PROCEDURE CheckLength(VAR S:ARRAY OF CHAR);
BEGIN
    IF (ORD(S[0]) > HIGH(S)) THEN HALT END;
END CheckLength;
(*$S=*)




PROCEDURE TooLong( S : ARRAY OF CHAR );
VAR
    S2 : ARRAY [0..255] OF CHAR;
BEGIN
    HALT;
END TooLong;





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
        CODE (8CH,0D8H,         (* MOV  AX,DS           SAVE THE DS REG.    *)
              50H,              (* PUSH AX                                  *)
              8BH,4EH,0AH,      (* MOV  CX,[BP+0A]      GET HIGH(SOURCE)    *)
              41H,              (* INC  CX              HIGH IS ZERO ORIGIN *)
              0C4H,7EH,0CH,     (* LES  DI,[BP+0C]      TARGET ADDRESS      *)
              0C5H,76H,06H,     (* LDS  SI,[BP+06]      SOURCE ADDRESS      *)
              47H,              (* INC  DI              SKIP PAST LENGTH    *)
              0F3H,0A4H,        (* REP  MOVSB           MOVE THE STRING     *)
              58H,              (* POP  AX              POP THE DS REGISTER *)
              8EH,0D8H);        (* MOV  DS,AX                               *)
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
         0F3H, 0A4H);       (* REP     MOVSB        ; Move characters           *)

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

    CODE(8CH,0D8H,      (* MOV    AX,DS       SAVE THE DS CONTENTS           *)
         50H,           (* PUSH   AX                                         *)
         0C4H,7EH,0CH,  (* LES    DI,[BP+0C]  ADDRESS OF TARGET TO ES:DI     *)
         8BH,46H,0FCH,  (* MOV    AX,[BP-4]   GET THE VALUE OF ti            *)
         01H,0C7H,      (* ADD    DI,AX       ES:DI = ADDR. OF TARGET[ti]    *)
         0C5H,76H,06H,  (* LDS    SI,[BP+06]  ADDRESS OF ADDEND TO DS:SI     *)
         8BH,4EH,0AH,   (* MOV    CX,[BP+0A]  HIGH(ADDEND) TO CX             *)
         41H,           (* INC    CX          ACCOUNT FOR THE ZERO ORIGIN    *)
         47H,           (* INC    DI          MOVE PAST LAST CHAR IN TARGET  *)
         0F3H,0A4H,     (* REP    MOVSB       APPEND ADDEND TO TARGET        *)
         8BH,46H,0FCH,  (* MOV    AX,[BP-04]  GET THE VALUE OF ti            *)
         03H,46H,0AH,   (* ADD    AX,[BP+0A]  ADD HIGH(ADDEND)               *)
         40H,           (* INC    AX          ADJUST FOR ZERO ORIGIN OF HIGH *)
         89H,46H,0FCH,  (* MOV    [BP-04],AX  PUT RESULT BACK IN ti          *)
         58H,           (* POP    AX          RESTORE VALUE OF DS            *)
         8EH,0D8H);     (* MOV    DS,AX                                      *)

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
    CODE(8CH,0D8H,      (* MOV    AX,DS       SAVE THE VALUE OF DS           *)
         50H,           (* PUSH   AX                                         *)
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
         58H,           (* POP    AX          RESTORE THE VALUE OF DS        *)
         8EH,0D8H);     (* MOV    DS,AX                                      *)
(**)
END LJust;



PROCEDURE RJust    (VAR Target:ARRAY OF CHAR);
VAR
    si, di : CARDINAL;
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
END RJust;




PROCEDURE TrimFront (VAR Target:ARRAY OF CHAR);
VAR
    si, di : CARDINAL;
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
END TrimFront;




PROCEDURE TrimRear (VAR Target:ARRAY OF CHAR);
VAR
    si : CARDINAL;
BEGIN
    CheckLength(Target);
    si := ORD(Target[0]);
    WHILE (si > 0) AND (Target[si]=" ") DO DEC(si) END;
    Target[0] := CHR(si);
END TrimRear;




PROCEDURE Procustes(VAR Target:ARRAY OF CHAR; Length:CARDINAL);
VAR
    l : CARDINAL;
BEGIN
    CheckLength(Target);
    IF (Length > HIGH(Target)) THEN HALT END;
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
END Procustes;






PROCEDURE Fill     (VAR Target:ARRAY OF CHAR; Char:CHAR; Length:CARDINAL);
VAR
    i : CARDINAL;
BEGIN
    IF (Length > HIGH(Target)) THEN HALT END;

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
    IF (Index < 1) THEN HALT END;
    CheckLength(Source);
    i := ORD(Source[0]);
    IF (Index <= i) THEN
        DEC(i,Index-1);
        IF (Length > i) THEN Length := i END;
    ELSE
        Dest[0] := 0C;
        RETURN;
    END;

    IF (Length > HIGH(Dest)) THEN HALT END;

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

    FOR i := 1 TO ORD(Target[0]) DO
        Target[i] := CAP(Target[i])
    END;

(*
    CODE (8CH,0D8H,    (* MOV      AX,DS       SAVE THE DS REGISTER          *)
          50H,         (* PUSH     AX                                        *)
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
          58H,         (* POP      AX          RESTORE THE VALUE OF DS       *)
          8EH,0D8H);   (* MOV      DS,AX                                     *)
    *)
END Upshift;





PROCEDURE StoC     (VAR Source:ARRAY OF CHAR; VAR Index: CARDINAL):CARDINAL;
VAR
    Card, n : CARDINAL;
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

    IF (j > HIGH(String)) THEN HALT END;

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
    i,j : CARDINAL;
BEGIN
    IF (Index < 1) OR
       (Index > HIGH(Target)) OR
       (Length > MAXCARDINAL - Index) THEN HALT END;
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
    IF (Index < 1) OR (Index > TargetLength+1) THEN HALT END;

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


    CODE(8CH,0D8H,      (* MOV     AX,DS       SAVE THE DS VALUE             *)
         50H,           (* PUSH    AX                                        *)
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
         58H,           (* POP     AX          RESTORE THE VALUE OF DS       *)
         8EH,0D8H);     (* MOV     DS,AX                                     *)

END Insert;




    (*$S-*)    (* No stack check.  Speed!!!! *)

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
        ELSIF (First[i] < Second[i]) THEN RETURN -i
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
    IF (j > 0) THEN                                               (* 17-Sep-87 LAA *)
        FOR i := 0 TO j-1 DO TString[i] := LString[i+1] END;
    END;
    TString[j] := CHR(0);
END LStringToTString;





PROCEDURE TStringToLString(VAR TString, LString : ARRAY OF CHAR);
VAR
    i, Len : CARDINAL;
BEGIN
    Len := 0;
    WHILE (Len <= HIGH(TString)) AND (TString[Len] <> 0C) DO
        INC(Len);
    END;
    IF (Len > HIGH(LString)) THEN HALT; END;
    i := Len;
    FOR i := Len TO 1 BY -1 DO
        LString[i] := TString[i-1];
    END;
    LString[0] := CHR(Len);
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
       (j > HIGH(Source)) THEN HALT END;

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
    IF (lens > HIGH(s)) OR (lenp > HIGH(pattern)) THEN HALT END;
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

PROCEDURE Copy(VAR Source       : ARRAY OF CHAR;
               VAR Destination  : ARRAY OF CHAR);

BEGIN                       (* Copy *)

    SubStr(Source, Destination, 1, HIGH(Destination));

END Copy;



(*----------------------------------------------------------------------------
    LengthOf --

    Return the length of the given LString.

    Preconditions:
        The given string must be an LString.

    Postconditions:
        The length of the LString will be returned.
----------------------------------------------------------------------------*)

PROCEDURE LengthOf(VAR LString              : ARRAY OF CHAR): CARDINAL;

BEGIN                       (* LengthOf *)

    RETURN ORD(LString[0]);

END LengthOf;



(*----------------------------------------------------------------------------
    SetLengthOf --

    Force the length of the given LString to be as indicated.

    Preconditions:
        The given string must be an LString.

    Postconditions:
        The length of the LString will be set to the value given.
----------------------------------------------------------------------------*)

PROCEDURE SetLengthOf(VAR LString           : ARRAY OF CHAR;
                          Length            : CARDINAL);

BEGIN                       (* SetLengthOf *)

    LString[0] := CHR(Length);

END SetLengthOf;


BEGIN
END GeldedLStrings.
