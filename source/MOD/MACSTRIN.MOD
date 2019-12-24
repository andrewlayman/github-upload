IMPLEMENTATION MODULE MacStrings;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)




FROM Dialog       IMPORT
                         WarningBox, ADialogOption;

FROM LStrings     IMPORT
                         SetString, Procustes, TStringToLString,
                         LengthOf, Insert, Remove, ConcatS;

FROM MacrosRc     IMPORT GetMacroLength;

FROM MacStack     IMPORT
                         MacStack, GetACardinal;

FROM MacVars      IMPORT
                         Interlock;





(*------------------------------------------------------------------------

Reads strings from the macro during playback.  Used for messages and menus.
The strings are delineated by terminators.  The terminators can be any
cardinal value, but the ones used are the ORD of "|", and the EndMsg,
EndMenu sentinals.

-------------------------------------------------------------------------*)



PROCEDURE RemoveMultipleSpaces (VAR str : ARRAY OF CHAR);

VAR
    i : CARDINAL;
    
BEGIN
  i := 1;
  IF (LengthOf (str) < 46) THEN RETURN; END;
  WHILE (i < LengthOf (str)) DO
    WHILE (str[i] <> " ") DO
      INC (i);
      IF (i = LengthOf (str)) THEN RETURN; END;
    END;
    INC (i); IF (i = LengthOf (str)) THEN RETURN; END;
    WHILE ((str[i] = " ") AND (i <= LengthOf (str))) DO
      Remove (str, i, 1);
    END;
  END;
END RemoveMultipleSpaces;



PROCEDURE InsertHardBreaksAsNeeded (VAR str : ARRAY OF CHAR);

VAR
    i, j  : CARDINAL;
    hardbreak : ARRAY [0..1] OF CHAR;
    
BEGIN

  IF (LengthOf (str) < 46) THEN RETURN; END;

  i := 1;
  j := 1;
  SetString (hardbreak, "ü");

  LOOP
    IF (i >= LengthOf (str)) THEN RETURN; END;
    WHILE ((str [i] <> " ") AND (j < 46)) DO
      INC (i);
      INC (j);
      IF (i >= LengthOf (str)) THEN RETURN; END;
    END;
    j := 1;
    IF NOT (str[i] = " ") THEN
      Insert (str, hardbreak, i);
    END;
    INC (i);
  END;
END InsertHardBreaksAsNeeded;
      


PROCEDURE ReadMacString (VAR str    : ARRAY OF CHAR;
                         terminator : CARDINAL);

VAR
     i,
     len,
     C  : CARDINAL;

BEGIN
  i := 0;
  GetACardinal (C);
  IF C = terminator THEN
    SetString (str, " ");
    Procustes (str, 0);
    RETURN;
  END;    (* no string *)
  LOOP
    str[i] := CHR(C);
    INC(i);
    IF i = HIGH(str) THEN         (* eat the remainder *)
      WHILE (C <> terminator) DO
        len := GetMacroLength (MacStack^.macro);
        IF (MacStack^.pos > (*MacStack^.macro^.card*)len) THEN EXIT; END;
        GetACardinal (C);
      END;
      EXIT;
    END;
    GetACardinal (C);
    IF C = terminator THEN EXIT; END;
  END;
  str[i] := 0C;
  TStringToLString (str, str);
END ReadMacString;



(*------------------------------------------------------------------------

Pops up messages on screen that are inside of macros during playback.

-------------------------------------------------------------------------*)

PROCEDURE DoMessage;

CONST
      Separator   = 124;
      MessageCode = 2000;
VAR
    title : ARRAY [0..30] OF CHAR;
    str   : ARRAY [0..255] OF CHAR;

BEGIN
  ReadMacString (title, Separator);
  ReadMacString (str, MessageCode);
  RemoveMultipleSpaces (str);
  InsertHardBreaksAsNeeded (str);
  INC(Interlock);
  WarningBox (str, title, NoHelp);
  DEC(Interlock);
END DoMessage;




BEGIN

  MacMessagePtr := NIL;
  MacMenuPtr := NIL;

END MacStrings.
