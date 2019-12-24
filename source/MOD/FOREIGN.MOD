IMPLEMENTATION MODULE Foreign;

(*$S+*)

    (* MODIFICATION HISTORY:

       26 Jun 86  AJL - Phrase "Too long" in English.
       19 Feb 88  RSC - minor speed/size improvements.
       22-Feb-88 LAA  - Force stack checking on for this module.
       28-Jun-89  LAA - Commented out the new assembler in ConvertString, and
                        put back in the Modula to solve a bug that kept Time
                        Line from coming up.
       18-Aug-89  MWP   Cause DecodeString to interpret at most 3 decimal
                        digits from Escape sequences.
       05-Sep-89  LAA   Fixed some problems in the assembler of ConvertString,
                        and re-enabled it.
    *)

FROM LStrings IMPORT  TrimRear, ConcatLS;
FROM Dialog   IMPORT  Error, FatalError;
FROM MsgFile  IMPORT  GetMessage;
FROM SYSTEM   IMPORT  CODE;





CONST ModuleNumber = 22400;  (* For GetMessage *)




PROCEDURE ConvertedCharacter (     C        : CHAR;
                               VAR Table    : ACharacterConversionTable
                             ) : CHAR;
BEGIN
    RETURN Table[ORD(C)];
END ConvertedCharacter;





PROCEDURE ConvertString      ( VAR S        : ARRAY OF CHAR;
                               VAR Table    : ACharacterConversionTable
                             );
VAR
    L : CARDINAL;
    i : CARDINAL;

BEGIN
    L := ORD(S[0]);
    IF (L > HIGH(S)) THEN
        FatalError();
    END;

(*                                                                (* 05-Sep-89 LAA *)
    i := 1;
    WHILE (i <= L) DO
        S[i] := Table[ ORD(S[i]) ];
        INC(i);
    END;
*)

(*
      ArrayParam      struc
      ArrayPtr        dd      ?
      ArraySize       dw      ?
      ArrayParam      ends
      ArrayParamSize          equ     size ArrayParam

      FixSizeArrayParam       struc
      FixSizeArrayPtr         dd      ?
      FixSizeArrayParam       ends
      FixSizeArrayParamSize   equ     size FixSizeArrayParam

      CStParams       struc
      CStOldBP            dw      ?
      CStReturnAddr       dd      ?
      CStTable            db      FixSizeArrayParamSize dup (?)
      CStString           db      ArrayParamSize dup (?)
      CStParams       ends
*)

    CODE(
       01EH,            (*        push    ds                               *)
       0C5H, 05EH, 006H,(*        lds     bx, [bp].CStTable.ArrayPtr       *)
       0C4H, 07EH, 00AH,(*        les     di, [bp].CStString.ArrayPtr      *)
       033H, 0C9H,      (*        xor     cx, cx                           *)
       026H, 08AH, 00DH,(*        mov     cl, es:[di]                      *)
       0E3H, 009H,      (*        jcxz    ConvertStringExit                *)
       047H,            (*        inc     di                               *)
       0FCH,            (*        cld                                      *)
                        (*                                                 *)
                        (*ConvertStringLoop:                               *)
       026H, 08AH, 005H,(*        mov     al, es:[di]                      *)
       0D7H,            (*        xlat                                     *)
       0AAH,            (*        stosb                                    *)
       0E2H, 0F9H,      (*        loop    ConvertStringLoop                *)
                        (*                                                 *)
                        (*ConvertStringExit:                               *)
       01FH);           (*        pop     ds                               *)

END ConvertString;





     (*------ Module Decoder:  Decode a readable string. -----*)

MODULE Decoder;

      IMPORT  ModuleNumber, TrimRear, GetMessage, ConcatLS, Error, FatalError;

      EXPORT  DecodeString;

    (*  Decode the ascii string into a string of control characters.
        The string is copied, character for character, except:

            ^  causes the next character to be interpreted as a
               control character (range 0C..37C).

            \  causes the next 1, 2 or 3 digits to be interpreted
               as the decimal representation of a character.

      *)

PROCEDURE DecodeString (VAR From, To: ARRAY OF CHAR);
CONST
    Null = 0C;
TYPE
    AState = (normal,control,numeric);
VAR
    i,
    FromLen,
    Seen,
    j        : CARDINAL;
    number   : CARDINAL;
    state    : AState;
    c        : CHAR;
    s        : ARRAY [0..255] OF CHAR;
BEGIN
    state := normal;
    i := 1;
    TrimRear(From);
    FromLen := ORD(From[0]);
    j := 0;

    LOOP
        IF (i <= FromLen) THEN
            c := From[i];
        ELSE
            c := Null;
        END;
        CASE state OF
            normal:   CASE c OF
                          Null:  EXIT;
                        | "^":   state := control;
                        | "\":   state := numeric; number := 0;
                                 Seen := 0;                        (* 18-Aug-89 MWP *)
                          ELSE;
                      END;
          | control:      c := CHR(ORD(c) MOD 32);
                          state := normal;

          | numeric:
                          IF ( Seen < 3 ) AND                      (* 18-Aug-89 MWP *)
                             ( c >= "0" ) AND ( c <= "9" ) THEN
                              INC(Seen);                           (* 18-Aug-89 MWP *)
                              number := (number * 10) + ORD(c) - ORD("0");
                          ELSE
                              c := CHR(number);
                              DEC(i);
                              state := normal;
                          END;
            ELSE FatalError;
        END;
        IF (state = normal) THEN
            IF (j < HIGH(To)) THEN
                INC(j);
                To[j] := c;
            ELSE
                GetMessage( ModuleNumber + 0, s ); (* "Too Long" *)
                ConcatLS(s,From);
                Error(s);
                EXIT;
            END;
        END;
        INC(i);
    END;
    To[0] := CHR(j);
END DecodeString;

END Decoder;


    (*------------- End Decoder Module ---------------------*)


MODULE Expansion;


EXPORT DoDash;

CONST
    DOT     = ".";

    (* All of this expand string stuff is the DoDash procedure from
       Kernigan and Plauger, Software Tools in Pascal.  The basic
       modifications are to allow all characters to be legal, take
       an LString as input, and not use special symbols for NEWLINE
       and TAB.

       A late-breaking change: require elipses ("..") instead of a
       DASH. *)


PROCEDURE AddStr(          C        : CHAR;
                     VAR   OutSet   : ARRAY OF CHAR;
                     VAR   j        : CARDINAL       );
BEGIN
    IF (j <= HIGH(OutSet)) THEN
        OutSet[j] := C;
        INC(j);
    END;
END AddStr;


    (* DoDash -- Translate source LString to a series of characters
                 beginning at position j of Dest.  Update j. *)

PROCEDURE DoDash(VAR Source   : ARRAY OF CHAR;
                 VAR Dest     : ARRAY OF CHAR;
                 VAR j        : CARDINAL       );
VAR
    Len            : CARDINAL;
    i,k            : CARDINAL;
    CL, CH         : CARDINAL;
    C              : CHAR;
BEGIN
    Len := ORD(Source[0]);
    i := 1;
    WHILE (i <= Len) DO
        C := Source[i];
        IF (C <> DOT) THEN
            AddStr(C, Dest, j);                  (* Copy literally.       *)
        ELSIF (i <= 1) OR (i >= Len-1) THEN
            AddStr(DOT, Dest, j);                (* Elipses don't count at start or end. *)
        ELSE
            CL := ORD(Source[i-1]);
            C  := Source[i+1];
            CH := ORD(Source[i+2]);
            IF (C = DOT) AND (CL <= CH) THEN     (* Check valid order. *)
                    (* A subtle gotcha: CH+1 must always be a valid
                       number (provided CH is a valid character) or else
                       the loop may not terminate.   That is why CL and
                       CH are CARDINALs and not CHARs. *)
                INC(CL);
                WHILE (CL <= CH) DO
                    AddStr(CHR(CL), Dest, j);
                    INC(CL);
                END;
                INC(i,2);
            ELSE
                AddStr(DOT, Dest, j);
            END;
        END;
        INC(i);
    END;
END DoDash;


BEGIN
END Expansion;



  (* -------------- End Expansion Module ------------*)



PROCEDURE ExpandStringToXLAT( VAR Source    : ARRAY OF CHAR;
                              VAR XLAT      : ARRAY OF CHAR   );
VAR
    j     : CARDINAL;
    S     : ARRAY [0..255] OF CHAR;
BEGIN
    j := 0;
    WHILE( j < HIGH(XLAT)) DO
        XLAT[j] := CHR(j);
        INC(j);
    END;
    DecodeString(Source,S);
    j := 0;
    DoDash(S,XLAT,j);
END ExpandStringToXLAT;




PROCEDURE InitializeForeign();
VAR
    i : CARDINAL;
BEGIN
    FOR i := 0 TO HIGH(UpshiftTable) DO
        UpshiftTable[i] := CAP(CHR(i));
    END;
    FOR i := 0 TO HIGH(SortOrderTable) DO
        SortOrderTable[i] := CHR(i);
    END;
END InitializeForeign;




BEGIN
    InitializeForeign();
END Foreign.
