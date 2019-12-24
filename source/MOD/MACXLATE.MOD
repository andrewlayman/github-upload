IMPLEMENTATION MODULE MacXlate;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
      8-Jan-90  RSC - Expand the range of extended keys to allow for mice.
     19-Jan-90  WKH - Import GetMessageWord from MsgFileAux instead of
                      RptCommon.

---------------------------------------------------------------------------*)



(* Translates macro from cardinal-based memory to character-based disk file.
   Also used to translate from cardinal-based memory to character-based for
   editting of the macro.

   Translates macro from character-based disk file to cardinal-based memory.
   Also translates from character-based memory to cardinal-based after
   editting of the macro.

    - Uses CHR and ORD function for printable characters.
    - Uses translation table for non-printable characters.
      - Table is named "Keys", indexed from 0-182;
      - Offset used to get index; ie. ORD(C)-KeyOffset = index, where
        C is the cardinal returned by GetCode for any character.  Keys
        and KeyOffset are only used for extended characters (C > 255).

  Modification History :
  
    3/20/88 - PutNameInBuffer now upshifts names to capitals.
            - Added call to FindMacroByName to check for valid names in
              PutNameInBuffer.
    3/14/89 - CToStr now ignores characters above C = 255 that are not
              in the Extended Character set.

   30-Nov-89  MWP - Placed hard coded literals into the phrases file.
*)


FROM Codes      IMPORT ASetOfCodes, MaxCode;

FROM Dialog     IMPORT Error, FatalError, ContinuationBox, ADialogOption;

FROM FlexStor   IMPORT AnExtHandle, LockObjectArray, ReleaseObject;

FROM LStrings   IMPORT TStringToLString, SetString, ConcatLS, Procustes,
                       Upshift, Compare, Copy, ConcatS, CtoS, TrimRear,
                       Remove, Search;

FROM MacBuffs   IMPORT MaxKeystrokes;

FROM MacCodes   IMPORT BeginCode, EndCode,
                       NameCode, MenuCode, MessageCode,
                       PauseCode, ChainCode, ExtendedCharStr,
                       GetCodeString;

FROM MacVars    IMPORT KeyOffset, XKey, NormKey, Command,
                       SpecialCharSet, ExtendedCharSet, Interlock,
                       OurEditRecord;

FROM MacNodes   IMPORT MacroTree, AMacroRecordPointer;

FROM MacrosRc   IMPORT FindMacroByName;

FROM MsgFile    IMPORT GetMessage, ConcatMessage;

FROM MsgFileAux IMPORT
                            GetMessageWord;

FROM Text       IMPORT AText, Compress, AppendLine, CopyLine, LineExists;

FROM SYSTEM     IMPORT ADDRESS, ADR;

FROM TreeObjects IMPORT ATreeNode;


CONST MaxStrLen     = 74;
      leftbracket   = 123;
      rightbracket  = 125;
      LastSpecKey   = 31;
      MaxNameLen    = 40;
      Terminator    = 124;
      Sentinal      = 65432;

      ModuleNumber  = 9700;

VAR
    S               : ARRAY [0..80] OF CHAR;

    AllOK,
    InMessage,
    InMenu,
    InChain,
    InChainStr,
    TerminatorFound,
    lastAdded,
    InName          : BOOLEAN;

    TermCount       : CARDINAL;


   PROCEDURE InCodeSet (VAR codeset : ASetOfCodes;
                        code        : CARDINAL):BOOLEAN;
   BEGIN
     RETURN ((code MOD 16) IN codeset[code DIV 16]);
   END InCodeSet;




(* CToStr translates cardinals of extended characters to string equivalents,
   using SetUpKeys, Keys and KeyOffset.
*)
PROCEDURE CToStr (C           : CARDINAL;
                  VAR Str     : ARRAY OF CHAR;
                  VAR InName  : BOOLEAN);

TYPE
     name            = ARRAY [0..10] OF CHAR;
     XKeyArray       = ARRAY [0..182] OF name;
     NormKeyArray    = ARRAY [0..31] OF name;

VAR
     recordsize,
     numrecs         : CARDINAL;
     address         : ADDRESS;
     NormKeyArrayPtr : POINTER TO NormKeyArray;
     XKeyArrayPtr    : POINTER TO XKeyArray;
                  
  PROCEDURE DoBoolean (VAR bool : BOOLEAN);
  BEGIN
    IF NOT lastAdded THEN
      bool := NOT bool;
    END;
  END DoBoolean;
  
BEGIN

  IF C <= MaxCode THEN
    recordsize := 11;
    IF (InCodeSet (SpecialCharSet, C) OR
        InCodeSet (ExtendedCharSet, C)) THEN
        GetCodeString (C, Str);
    ELSIF C <= 255 THEN
      Str[0] := CHR(C);
      Str[1] := 0C;
      TStringToLString (Str, Str);
    ELSE (* added 3/14/89 due to TL4 and Compaq keyboards *)
      GetMessage (26475, S);
      Error (S);
      Str[0] := CHR(0);
      Str[1] := 0C;
    END;
  ELSIF C = MessageCode THEN
    DoBoolean (InMessage);
    IF NOT InMessage THEN
      Copy (Command[0], Str);
      TerminatorFound := FALSE;
    ELSE
      Copy (Command[1], Str);
    END;
    InMessage := NOT InMessage;
  ELSIF C = MenuCode THEN
    DoBoolean (InMenu);
    IF NOT InMenu THEN                       (* need to count terminators *)
      Copy (Command[2], Str);
    ELSE
      Copy (Command[3], Str);
    END;
    InMenu := NOT InMenu;

  ELSIF C = ChainCode THEN
    DoBoolean (InChain);
    IF NOT InChain THEN                       (* need to count terminators *)
      Copy (Command[7], Str);
    ELSE
      Copy (Command[8], Str);
    END;
    InChain := NOT InChain;

  ELSIF C = PauseCode THEN
    Copy (Command[4], Str);

  ELSIF C = NameCode THEN
    DoBoolean (InName);
    IF NOT InName THEN
      Str[0] := "{";
      Str[1] := 0C;
      TStringToLString (Str, Str);
      InName := NOT InName;
    ELSE
      Str[0] := "}";
      Str[1] := 0C;
      TStringToLString (Str, Str);
      InName := NOT InName;
    END;
  END;
  lastAdded := TRUE;
END CToStr;


(* StrToC translates string equivalents of extended characters to cardinals.
   using SetUpKeys, Keys and KeyOffset.
   Anything that does not map to a table and is not a standard key is considered]
   a name.

   RETURNS name as boolean value.
*)






PROCEDURE StrToC (Str   : ARRAY OF CHAR;
                  VAR C : CARDINAL):BOOLEAN;

VAR
    begdef,
    enddef,
    pause,
    begchain,
    endchain
               : ARRAY [0..10] OF CHAR;

BEGIN

    GetMessageWord ( ModuleNumber + 22, 0, begdef );       (* 30-Nov-89 MWP *)
    GetMessageWord ( ModuleNumber + 22, 1, enddef );       (* 30-Nov-89 MWP *)
    GetMessageWord ( ModuleNumber + 22, 2, pause );       (* 30-Nov-89 MWP *)
    GetMessageWord ( ModuleNumber + 22, 3, begchain );       (* 30-Nov-89 MWP *)
    GetMessageWord ( ModuleNumber + 22, 4, endchain );       (* 30-Nov-89 MWP *)

(*
  SetString (begdef, "{beginput}");
  SetString (enddef, "{endinput}");
  SetString (pause, "{pause}");
  SetString (begchain, "{beglink}");
  SetString (endchain, "{endlink}");
*)
  IF Compare (Str, begdef) = 0 THEN
    C := BeginCode;
    RETURN TRUE;
  ELSIF Compare (Str, enddef) = 0 THEN
    C := EndCode;
    RETURN TRUE;
  ELSIF Compare (Str, begchain) = 0 THEN
    C := ChainCode;
    RETURN TRUE;
  ELSIF Compare (Str, endchain) = 0 THEN
    C := ChainCode;
    RETURN TRUE;
  ELSIF Compare (Str, pause) = 0 THEN
    C := PauseCode;
    RETURN TRUE;
  ELSIF ExtendedCharStr (Str, C) THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END;
END StrToC;



(* 
Searches to the end of the text for a right bracket.  If TRUE then
VARs LineNumber and CharNumber indicate where in the text the right
bracket was found.
*)

PROCEDURE RightBracketFound (VAR MacText    : AText;
                             CurrentLine    : CARDINAL;
                             CurrentChar    : CARDINAL;
                             VAR LineNumber : CARDINAL;
                             VAR CharNumber : CARDINAL):BOOLEAN;
VAR
    str : ARRAY [0..80] OF CHAR;

BEGIN
  LineNumber := CurrentLine;
  CharNumber := CurrentChar+1;
  WHILE LineExists (MacText, LineNumber) DO
    CopyLine (MacText, LineNumber, str);
    WHILE CharNumber <= ORD(str[0]) DO
      IF ORD(str[CharNumber]) = rightbracket THEN RETURN TRUE; END;
      IF ORD(str[CharNumber]) = leftbracket THEN RETURN FALSE; END;
      INC(CharNumber);
    END;
    INC(LineNumber);
    CharNumber := 1;
  END;
  RETURN FALSE;
END RightBracketFound;



(* Removes any spaces in the string *)

PROCEDURE RemoveSpaces (VAR str : ARRAY OF CHAR);

VAR
    i,j  : CARDINAL;
    str2 : ARRAY [0..255] OF CHAR;
    
BEGIN
  j := 0;
  FOR i := 1 TO ORD (str[0]) DO
    IF str[i] <> " " THEN
      INC (j);
      str2[j] := str[i];
    END;
  END;
  str2[0] := CHR(j);
  Copy (str2, str);
END RemoveSpaces;



(*
Gets the bracket string, and set LineNumber and CharNumber to indicate
where the end of the bracket string was found.
*)

PROCEDURE GetBracketString (VAR MacText     : AText;          (* in *)
                            VAR str         : ARRAY OF CHAR;  (* out *)
                            VAR CurrentLine : CARDINAL;       (* in/out *)
                            VAR CurrentChar : CARDINAL;       (* in/out *)
                            VAR LineNumber  : CARDINAL;        (* in *)
                            VAR CharNumber  : CARDINAL);      (* in *)
VAR
    i               : CARDINAL;
    textstr         : ARRAY [0..80] OF CHAR;

BEGIN
  i := 0;
  CopyLine (MacText, CurrentLine, textstr);
  REPEAT
    str[i] := textstr[CurrentChar];
    IF ((CurrentChar = ORD(textstr[0])) AND (CurrentLine < LineNumber)) THEN
      INC(CurrentLine);
      CopyLine (MacText, CurrentLine, textstr);    (* get next line *)
      CurrentChar := 0;
    END;
    INC(i);
    INC(CurrentChar);
  UNTIL ((CurrentLine = LineNumber) AND (CurrentChar > CharNumber));
  str[i] := 0C;                                    (* terminate the line *)
  TStringToLString (str, str);
  RemoveSpaces (str);
END GetBracketString;





PROCEDURE MacMessage (VAR str : ARRAY OF CHAR):BOOLEAN;

BEGIN
  AllOK := TRUE;
  IF (Compare (str, Command[0]) = 0) THEN
    TermCount := 0;                         (* initialize *)
    RETURN TRUE;
  ELSIF (Compare (str, Command[1]) = 0) THEN
    IF TermCount = 1 THEN
      RETURN TRUE;
    ELSE
      GetMessage (26476, S);
      Error (S);
      AllOK := FALSE;
      RETURN TRUE;
    END;
  ELSE
    RETURN FALSE;
  END;
END MacMessage;





PROCEDURE MacMenu (VAR str : ARRAY OF CHAR):BOOLEAN;

BEGIN
  AllOK := TRUE;
  IF (Compare (str, Command[2]) = 0) THEN
    TermCount := 0;                         (* initialize *)
    RETURN TRUE;
  ELSIF (Compare (str, Command[3]) = 0) THEN
    IF TermCount = 4 THEN
      RETURN TRUE;
    ELSE
      GetMessage (26477, S);
      Error (S);
      AllOK := FALSE;
      RETURN TRUE;
    END;
  ELSE
    RETURN FALSE;
  END;
END MacMenu;



(*
Puts the bracket string in the buffer. Assumes it is a name.
Upshifts lower case to caps.
Added BOOLEAN function return, 3/20/88.
*)

PROCEDURE PutNameInBuffer (VAR str      : ARRAY OF CHAR;
                           VAR Buffer   : ARRAY OF CARDINAL;
                           VAR bufcount : CARDINAL):BOOLEAN;
VAR
    count : CARDINAL;
    S     : ARRAY [0..255] OF CHAR;
    title : ARRAY [0..30] OF CHAR;

BEGIN
  Buffer[bufcount] := NameCode;
  INC(bufcount);
  FOR count := 2 TO ORD(str[0])-1 DO
    str[count] := CAP(str[count]);
    Buffer[bufcount] := ORD(str[count]);
    INC(bufcount);
  END;
  Buffer[bufcount] := NameCode;

  (* check for valid name *)
  Remove (str, ORD(str[0]), 1);
  Remove (str, 1, 1);
  Procustes (str, 40);
  IF FindMacroByName (str) = NIL THEN
    GetMessage (26478, S);
    TrimRear (str);
    ConcatLS (S, str);
    ConcatMessage (S, 26479);
    GetMessage (26481, title);
    IF NOT ContinuationBox (S, title, NoHelp) THEN RETURN FALSE; END;
  ELSIF Compare (str, OurEditRecord^.macName) = 0 THEN
    TrimRear (str);
    IF bufcount = (ORD(str[0]) + 1) THEN
      GetMessage (26482, S);
      Error (S);
      RETURN FALSE;
    END;
  END;    
  INC(bufcount);
  RETURN TRUE;
END PutNameInBuffer;




(*
translates the character based text to a cardinal based macro
*)

PROCEDURE TextToMac (    MacText : AText;
                     VAR Buffer  : ARRAY OF CARDINAL;
                     VAR CardLen : CARDINAL):BOOLEAN;
VAR
    textstr         : ARRAY [0..80] OF CHAR;
    str             : ARRAY [0..255] OF CHAR;
    i,
    bufcount,
    CurrentLine,
    CurrentChar,
    LineNumber,
    CharNumber      : CARDINAL;





  (* initialize *)

PROCEDURE Initialize;

BEGIN
  bufcount    := 0;
  CurrentLine := 0;
  CurrentChar := 1;
  LineNumber  := 0;
  CharNumber  := 1;
  InChainStr  := FALSE;
END Initialize;
  (* xlate character or bracket string, put in buffer *)





  (* test for text, set first line *)

PROCEDURE GetFirstLine():BOOLEAN;

BEGIN;
  IF LineExists (MacText, CurrentLine) THEN
    CopyLine (MacText, CurrentLine, textstr);
    RETURN TRUE;
  ELSE
    SetString (textstr, "");
    RETURN FALSE;
  END;
END GetFirstLine;




(*
translates the text, 1 character/bracket-string at a time
*)

PROCEDURE Xlate():BOOLEAN;

VAR
    C             : CARDINAL;
    linenumber    : CARDINAL;
    linenumberstr : ARRAY [0..5] OF CHAR;

BEGIN

  (* What about case when right bracket is found with no preceding
     left bracket? *)

  IF ORD(textstr[0]) = 0 THEN RETURN TRUE; END;

  IF ORD(textstr[CurrentChar]) = rightbracket THEN
    linenumber := LineNumber;
    INC (linenumber);
    GetMessage (26483, S);
    CtoS (linenumber, linenumberstr);
    ConcatLS (S, linenumberstr);
    ConcatS (S, ".");
    Error (S);
    RETURN FALSE;
  END;

  IF ORD(textstr[CurrentChar]) = leftbracket THEN
    IF RightBracketFound (MacText, CurrentLine, CurrentChar,
                                   LineNumber, CharNumber) THEN
      GetBracketString (MacText, str, CurrentLine, CurrentChar,
                                      LineNumber, CharNumber);
    ELSE ;
      linenumber := LineNumber;
      INC (linenumber);
      GetMessage (26484, S);
      CtoS (linenumber, linenumberstr);
      ConcatLS (S, linenumberstr);
      ConcatS (S, ".");
      Error (S);
      RETURN FALSE;  
    END;

    (* process bracket string *)

    IF StrToC (str, C) THEN
      Buffer[bufcount] := C;
      INC(bufcount);
      IF C = ChainCode THEN InChainStr := NOT InChainStr; END;

    ELSIF MacMessage(str) THEN
      IF NOT AllOK THEN RETURN FALSE; END;
      Buffer[bufcount] := MessageCode;
      INC(bufcount);

    ELSIF MacMenu(str) THEN
      IF NOT AllOK THEN RETURN FALSE; END;
      Buffer[bufcount] := MenuCode;
      INC(bufcount);

    ELSE
      IF NOT PutNameInBuffer (str, Buffer, bufcount) THEN
        RETURN FALSE;
      END;

    END;
    CurrentLine := LineNumber;
    CurrentChar := CharNumber;
    CopyLine (MacText, LineNumber, textstr);
    INC(CurrentChar);

  ELSE

        (* Here we need to track terminators. *)
    IF textstr[CurrentChar] = CHR(Terminator) THEN INC(TermCount); END;

        (* Here we check for chain call so we can upshift *)
    IF InChainStr THEN
      textstr[CurrentChar] := CAP(textstr[CurrentChar]);
    END;

    (* we skip spaces *)
    IF ORD(textstr[CurrentChar]) <> 32 THEN
      Buffer[bufcount] := ORD(textstr[CurrentChar]);
      IF Buffer[bufcount] = 249 THEN Buffer[bufcount] := 32; END;
      INC(bufcount);
    END;
    INC(CurrentChar);

  END;

    IF bufcount >= MaxKeystrokes THEN
      INC (Interlock);
      GetMessage (26485, S);
      Error (S);
      DEC (Interlock);
      RETURN FALSE;
    END;
    
  RETURN TRUE;

END Xlate;




  (* if end of the line then get next line if it exists. *)

PROCEDURE GetNextLine():BOOLEAN;

BEGIN
  IF CurrentChar > ORD(textstr[0]) THEN
    INC(CurrentLine);
    IF LineExists (MacText, CurrentLine) THEN
      CopyLine (MacText, CurrentLine, textstr);
      CurrentChar := 1;
      RETURN TRUE;
    ELSE
      RETURN FALSE;                                 (* end of the line & text *)
    END;
  END;
  RETURN TRUE;
END GetNextLine;


PROCEDURE TerminateMacro;

BEGIN
      FOR i := 0 TO 1 DO         (* add two sentinals to the end *)
        Buffer[bufcount] := Sentinal;
        INC(bufcount);
      END;
      CardLen := bufcount;
END TerminateMacro;




BEGIN  (* TextToMac *)

  Initialize;

  IF NOT GetFirstLine() THEN
    CardLen := 0;
    RETURN TRUE;
  END;

  LOOP
    IF NOT Xlate() THEN RETURN FALSE; END;
    IF NOT GetNextLine() THEN
      TerminateMacro;
      RETURN TRUE;
    END;
  END;

  RETURN TRUE;

END TextToMac;







PROCEDURE MacToText (VAR MacroRecordPointer   : AMacroRecordPointer;
                     VAR MacText : AText);
VAR
    cardnum,                           (* macro progress *)
    recordsize           : CARDINAL;
    str                  : ARRAY [0..11] OF CHAR;
    TextStr              : ARRAY [0..MaxStrLen] OF CHAR;
    done                 : BOOLEAN;

    (* Gets a macro cardinal from ExtStorage *)

    PROCEDURE GetACardinal (handle     : AnExtHandle;
                            which      : CARDINAL;
                            VAR Card   : CARDINAL);

    TYPE datarec = RECORD
                     data : ARRAY [0..MaxKeystrokes] OF CARDINAL;
                   END;
         dataptr = POINTER TO datarec;

    VAR data     : dataptr;
        reccount : CARDINAL;
        address  : ADDRESS;


    BEGIN
      reccount := LockObjectArray (handle, data, recordsize);
      Card := data^.data[which];
      ReleaseObject (handle);
    END GetACardinal;


    (* Gets a macro cardinal and translates it to character format.
       Returns a multiple character string if cardinal is a special character,
       ie. <F10>, else it returns a 1 character string. *)

    PROCEDURE GetNextStr (VAR str : ARRAY OF CHAR):BOOLEAN;
    VAR
        code : CARDINAL;

    BEGIN
      GetACardinal (MacroRecordPointer^.handle, cardnum, code);

      CASE code OF
        Sentinal  : RETURN FALSE;
      | 32        : code := 249; CToStr (code, str, InName);
      | BeginCode : SetString (str, "{beginput}");
                    IF NOT lastAdded THEN
                      lastAdded := TRUE;
                    END;
      | EndCode   : SetString (str, "{endinput}");
                    IF NOT lastAdded THEN
                      lastAdded := TRUE;
                    END;
      
      ELSE
        CToStr (code, str, InName);
      END;
      
      RETURN TRUE;
    END GetNextStr;


BEGIN

  cardnum           := 0;
  InName            := FALSE;
  InMessage         := FALSE;
  InMenu            := FALSE;
  InChain           := FALSE;
  TerminatorFound   := FALSE;
  lastAdded         := TRUE; 
  done := FALSE;

  recordsize := MacroRecordPointer^.cardlen;
  recordsize := recordsize*2;          (* cardinal size to byte size *)

  LOOP                                 (* == create a text == *)
    IF MacroRecordPointer^.cardlen = 0 THEN EXIT; END;
    SetString (TextStr, " ");
    Procustes (TextStr, 0);
    LOOP                               (* == create a Text string == *)

      IF NOT GetNextStr (str) THEN done := TRUE; EXIT; END;  (* we're done *)

      IF ((ORD(TextStr[0])+ORD(str[0])) > (MaxStrLen)) THEN
        lastAdded := FALSE;
        EXIT;
      END;

      (* formatting - this doesn't work! 
      IF (str[1] = "{") THEN
        lastAdded := FALSE;
        EXIT;
      END;*)

      ConcatLS (TextStr, str);
      INC (cardnum);

    END;      (* we now have a Text string *)

               (* add string to Text *)
    IF NOT AppendLine (TextStr, MacText) THEN done := TRUE; EXIT; END; 

    IF done THEN 
      EXIT;
    END;   (* we're done *)

  END;

  Compress (MacText);

END MacToText;



END MacXlate.
