MODULE MacMenu;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

    (*  MODIFICATION HISTORY
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
       12-Dec-89  LVK - Menu items MaxLength is now a function of the
                        prefix length.
                        Added CONST MacPrefix, MaxTitle, MaxMessage
       23-Aug-91  PFG - AdjustMenuItems was getting one too many characters
                        from the menu item strings, often leaving a garbage
                        char at the end.
    *)



FROM Codes          IMPORT
                            ACode;

FROM Dialog         IMPORT
                            Error, ADialogOption, MultipleChoiceBox;

FROM LStrings       IMPORT
                            SetString, ConcatLS, ConcatS, TStringToLString,
                            LengthOf, SetLengthOf;

FROM MacNodes       IMPORT
                            MacroNode;

FROM MacrosRc       IMPORT
                            FindMacro;

FROM MacStack       IMPORT
                            PushMacro, GetACardinal, GetName, MacStack;

FROM MacStrings     IMPORT
                            ReadMacString;

FROM MacVars        IMPORT
                            Interlock, FormAccepted;

FROM MacTalk        IMPORT
                            MacDeath;

FROM MsgFile        IMPORT
                            GetMessage, ConcatMessage;

FROM TreeObjects    IMPORT
                            ATreeNode;

CONST
       NameCode    = 1000;
       Separator   = 124;
       MacMenuCode = 3000;
       MaxPrefix   = 20;
       MaxTitle    = 25;
       MaxMessage  = 120;


(*------------------------------------------------------------------------

Pops up menus from macros during playback.  Processes user's choice, and
initiates playback of the corresponding macro.  After the choice has been
played back, the original macro is resumed.

-------------------------------------------------------------------------*)

PROCEDURE DoMacMenu():BOOLEAN;
VAR
    title  : ARRAY [0..MaxTitle] OF CHAR;
    prefix : ARRAY [0..MaxPrefix] OF CHAR;
    menu   : ARRAY [0..255] OF CHAR;
    str    : ARRAY [0..MaxMessage] OF CHAR;
    select : CARDINAL;
    choice : ACode;



  (*------------------------------------------------------------------------

  Gets the choice made by the user in the macro's menu box.

  -------------------------------------------------------------------------*)

PROCEDURE GetChoice (VAR MacroNode : ATreeNode;
                         choice    : CARDINAL);

VAR str     : ARRAY [0..127] OF CHAR;
    C,
    i       : CARDINAL;
    MacName : ARRAY [0..40] OF CHAR;

BEGIN
  i := 0;

    (* for cleared playback with Ctrl-Break *)
  IF MacStack = NIL THEN MacroNode := NIL; RETURN; END;

  IF choice > 0 THEN
  (* get the macro *)
    FOR i := 1 TO choice DO 
      GetACardinal (C);
      IF CARDINAL(C) = NameCode THEN
        GetName (CARDINAL(C), MacName);
      END;
    END;
    MacroNode := FindMacro (C, MacName);
    IF MacroNode = NIL THEN
      GetMessage (26424, str);
      ConcatLS (str, MacName);
      ConcatMessage (str, 26425);
      Error (str);
    END;
  END;

  (* eat the remainder *)
  WHILE C <> MacMenuCode DO
    GetACardinal (C);
  END;

END GetChoice;




(* Makes sure that a menu item is not too long for MultipleChoiceBox *)

PROCEDURE AdjustMenuItems (VAR str : ARRAY OF CHAR);

(*CONST MaxItemLength = 34;*)

VAR
    i,j,k         : CARDINAL;
    S,
    tempstr       : ARRAY [0..255] OF CHAR;
    truncated     : BOOLEAN;
    Copyright     : ARRAY[0..50] OF CHAR;
    MaxItemLength : CARDINAL;



PROCEDURE DetermineMaxItemLength (VAR OurMaxItemLength : CARDINAL);
CONST MaxMenuSize = 44;
BEGIN
  OurMaxItemLength := MaxMenuSize - ORD(prefix[0]);
END DetermineMaxItemLength;

    
BEGIN
  Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  i := 0;
  j := 1;
  k := 0;
  truncated := FALSE;
  DetermineMaxItemLength (MaxItemLength);
  
  REPEAT
    IF j <= MaxItemLength THEN
      tempstr[k] := str[i+1]; INC (k);
      IF str[i+1] = "," THEN j := 0; END;
    ELSE
      IF str[i+1] = "," THEN
        j := 0; DEC (i);
      ELSE
        truncated := TRUE;
      END;
    END;
    INC (i);
    INC (j);
  UNTIL i >= (ORD(str[0]));

  tempstr [k] := 0C;
  TStringToLString (tempstr, str);

  IF truncated THEN
    GetMessage (26426, S);
    Error (S);
  END;
  
END AdjustMenuItems;




BEGIN

  ReadMacString (title, Separator);
  ReadMacString (str, Separator);
  ReadMacString (prefix, Separator);
  ReadMacString (menu, Separator);
  AdjustMenuItems (menu);

  INC(Interlock);

  IF MultipleChoiceBox (str, title, NoHelp, prefix, menu, select) THEN
    GetChoice (MacroNode, select);
    IF MacroNode = NIL THEN
      DEC(Interlock);
      RETURN FALSE;
    END;
    PushMacro (MacroNode);
    DEC(Interlock);
    RETURN TRUE;
  ELSE
    GetChoice (MacroNode, 0);
    DEC(Interlock);
    RETURN FALSE;
  END;


END DoMacMenu;


BEGIN

  FormAccepted := FALSE;

  IF DoMacMenu() THEN
    FormAccepted := TRUE;
  END;

END MacMenu.
