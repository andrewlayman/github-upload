MODULE MacMenuForm;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)



(* 
   Puts up form for user to fill out and create a menu for use in macros.

   Modifications:
   5/2/89 LVK : Moved form to separate file "MACMENFO.MOD" for
                addition to TLFORMS file.
   10-Aug-89  KKC - Add copyright message.
   01-Oct-89  WKh - ReSynched code btwn Cybersoft & Symantec
   13-Nov-89  RSC - Import from Space rather than Storage.
*)


FROM Codes                  IMPORT ACode;

FROM Dialog                 IMPORT
                                   Error, WarningBox,
                                   ADialogOption;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

FROM Forms                  IMPORT
    (* TYPE *)                  AForm, AFieldValue, ACheckReason, DoForm,
    (* PROC *)                  ShowValue;

FROM Kbio           IMPORT maxrow;

FROM Keys           IMPORT CancelKey;

FROM LStrings       IMPORT SetString, Fill, Copy, ConcatLS,
                           ConcatS, TrimRear, Procustes, LengthOf;

FROM MacroSelect    IMPORT SelectMacroName;

FROM MacrosRc       IMPORT FindMacroByName;

FROM MacStrings     IMPORT MacMenuPtr;

FROM MacVars        IMPORT Editing, FormAccepted;

FROM Menus          IMPORT NoYes;

FROM MsgFile        IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM Space          IMPORT ALLOCATE, DEALLOCATE;

FROM Space          IMPORT Available;

FROM SYSTEM         IMPORT SIZE;

FROM TreeObjects    IMPORT ATreeNode;




  CONST
      SelectKey = 316;   (* f2 *)
      Separator = "|";

  VAR
      S                  : ARRAY [0..255] OF CHAR;



PROCEDURE Replace (VAR str  : ARRAY OF CHAR;
                       with : CHAR;
                       by   : CHAR);
VAR
    i : CARDINAL;

BEGIN
  FOR i := 1 TO ORD(str[0]) DO
    IF str[i] = with THEN
      str[i] := by;
    END;
  END;
END Replace;




  PROCEDURE OurCheckProc (form            : AForm;
                          fieldno         : AFieldNo;
                          VAR FormValue   : ARRAY OF AFieldValue;
                          checkreason     : ACheckReason;
                          VAR code        : CARDINAL):BOOLEAN;


  CONST jump       = 8000H;

  VAR   title      : ARRAY [0..31] OF CHAR;
        MacName    : ARRAY [0..40] OF CHAR;


(* new  6/11/88 *)

    PROCEDURE CheckFields (S     : ARRAY OF CHAR):BOOLEAN;

    VAR
        tempstr    : ARRAY [0..40] OF CHAR;
        
    BEGIN
      IF (fieldno < 4) THEN RETURN TRUE; END;
      Copy (FormValue[fieldno].CharValue^, tempstr);
      TrimRear (tempstr);
        IF LengthOf (tempstr) > 0 THEN
          IF NOT ODD(fieldno) THEN  (* it's a Choice *)
            Copy (FormValue[fieldno+1].CharValue^, tempstr);
          ELSE                      (* it's a Macro *)
            Copy (FormValue[fieldno-1].CharValue^, tempstr);
          END;
          TrimRear (tempstr);
          IF LengthOf (tempstr) = 0 THEN
            GetMessage (26334, title);
            WarningBox (S, title, NoHelp);
            IF NOT ODD(fieldno) THEN
              code := jump + fieldno + 1;
            ELSE
              code := jump + fieldno - 1;
            END;
            RETURN FALSE;
          END;
        END;
      RETURN TRUE;
    END CheckFields;


    (* MultipleChoiceBox requires more than one choice.  *)

    PROCEDURE MoreThanOneChoice():BOOLEAN;
    
    VAR 
        i, j    : CARDINAL;
        tempstr : ARRAY [0..40] OF CHAR;
        
    BEGIN
      j := 0;
      FOR i := 5 TO 15 BY 2 DO
        Copy (FormValue[i].CharValue^, tempstr);
        TrimRear (tempstr);
        IF LengthOf (tempstr) > 0 THEN INC (j); END;
        IF j > 1 THEN RETURN TRUE; END;
      END;
      RETURN FALSE;
    END MoreThanOneChoice;


PROCEDURE AcceptTheMacros ():BOOLEAN;

VAR
    name      : ARRAY [0..40] OF CHAR;
    macronode : ATreeNode;

BEGIN
  IF (ODD(fieldno) AND (fieldno > 4)) THEN
    Copy (FormValue[fieldno].CharValue^, name);
    TrimRear (name);
    IF ORD(name[0]) > 0 THEN
      macronode := FindMacroByName (FormValue[fieldno].CharValue^);
      IF (macronode = NIL) THEN
        TrimRear (name);
        GetMessage (26335, S);
        ConcatLS (S, name);
        ConcatMessage (S, 26336);
        IF NOT NoYes (S) THEN code := jump + fieldno; RETURN FALSE; END; 
      END;
    END;
  END;
  code := 0;
  RETURN TRUE;
END AcceptTheMacros;



  BEGIN

    IF NOT ((checkreason = CheckFieldKey) OR
            (checkreason = CheckFieldEntry) OR
            (checkreason = CheckFieldExit) OR
            (checkreason = CheckFormExit)) THEN
      code := 0;
      RETURN TRUE;
    END;

    IF ((checkreason = CheckFieldEntry) AND (fieldno > 3)) THEN
      IF NOT (ODD(fieldno)) THEN         (* choice name field *)
        DisplayMessage (26337);
      ELSE                                (* macro name field  *)
        DisplayMessage (26338);
      END;
    END;

    IF checkreason = CheckFormExit THEN

      IF ODD(fieldno) THEN
        GetMessage (26339, S);
      ELSE
        GetMessage (26340, S);
      END;

      IF NOT CheckFields (S) THEN RETURN FALSE; END;

      IF NOT MoreThanOneChoice() THEN
        GetMessage (26343, S);
        Error (S);
        code := 0;
        RETURN FALSE;
      END;

      IF NOT AcceptTheMacros() THEN
        RETURN FALSE;
      ELSE
        RETURN TRUE;
      END;

    END;


    IF ((fieldno > 4) AND ODD(fieldno)) THEN
      IF code = SelectKey THEN
        Fill (MacName, " ", 0);
	GetMessage (26341, title);
        IF SelectMacroName (5, 5, 47, maxrow - 6, title, MacName) THEN
          Copy (MacName, FormValue[fieldno].CharValue^);
          ShowValue (form, fieldno, FormValue);
          code := 0;
          RETURN TRUE;
        END;
      END;
    END;

    code := 0;
    RETURN TRUE;

END OurCheckProc;










PROCEDURE DoMenu(): BOOLEAN;

CONST
    cULX                    = 1;
    (*cULY                    = 9;*)
    cLRX                    = 76;
    MaxLine                 = 11;
    
VAR
    FormValue               : ARRAY [0..15] OF AFieldValue;
    code                    : ACode;
    i,j,
    LRY                     : CARDINAL;
    tempstr                 : ARRAY [0..40] OF CHAR;
    Copyright               : ARRAY[0..50] OF CHAR;


BEGIN                       (* GetFileName *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    
(*      Allocate memory...  *)

    FOR i := 0 TO 15 DO
      IF Available (SIZE(FormValue[i].CharValue)) THEN
        NEW(FormValue[i].CharValue);
      ELSE
        GetMessage (26342, S);
        Error(S);
        FOR j := 0 TO i-1 DO
          DISPOSE (FormValue[j].CharValue);
        END;
        RETURN FALSE;
      END;
    END;
     (* Title *)
    Fill (FormValue[0].CharValue^, " ", 25);
     (* Message *)
    Fill (FormValue[1].CharValue^, " ", 60);
    Fill (FormValue[2].CharValue^, " ", 60);
     (* Prefix *)
    Fill (FormValue[3].CharValue^, " ", 20);
     (* Choices and Macros *)
    FOR i := 4 TO 14 BY 2 DO
      Fill (FormValue[i].CharValue^, " ", 24);
    END;
        
    FOR i := 5 TO 15 BY 2 DO
      Fill (FormValue[i].CharValue^, " ", 40);
    END;

    code := CancelKey;
    LRY := maxrow-16 + MaxLine + 2;

    code := DoForm(cULX, maxrow-16, cLRX, LRY,
                               114,
                               TRUE, FormValue, OurCheckProc);

    IF code <> CancelKey THEN

      NEW (MacMenuPtr);

      (* Title *)
      TrimRear (FormValue[0].CharValue^);
         (* add a space front and back to the title *)
      SetString (tempstr, " ");
      ConcatLS (tempstr, FormValue[0].CharValue^);
      ConcatS (tempstr, " ");
      Copy (tempstr, FormValue[0].CharValue^);
      ConcatS (FormValue[0].CharValue^, Separator);
      Copy (FormValue[0].CharValue^, MacMenuPtr^.Title);

      (* Message *)
      IF (FormValue[1].CharValue^[60] = " ") THEN
        TrimRear (FormValue[1].CharValue^);
        ConcatS (FormValue[1].CharValue^, " ");
      ELSE
        TrimRear (FormValue[1].CharValue^);
      END;
      TrimRear (FormValue[2].CharValue^);
      Copy (FormValue[1].CharValue^, MacMenuPtr^.Message);
      ConcatLS (MacMenuPtr^.Message, FormValue[2].CharValue^);
      IF LengthOf (MacMenuPtr^.Message) = 0 THEN
        ConcatS (MacMenuPtr^.Message, " ");
      END;
      ConcatS (MacMenuPtr^.Message, Separator);

      (* Prefix *)
      TrimRear (FormValue[3].CharValue^);
      Copy (FormValue[3].CharValue^, MacMenuPtr^.Prefix);
      IF LengthOf (MacMenuPtr^.Prefix) = 0 THEN
        ConcatS (MacMenuPtr^.Prefix, " ");
      END;
      ConcatS (MacMenuPtr^.Prefix, Separator);


      (* Choices *)
      Procustes (MacMenuPtr^.Choices, 0);
      FOR i := 4 TO 14 BY 2 DO
        TrimRear (FormValue[i].CharValue^);
        IF LengthOf (FormValue[i].CharValue^) > 0 THEN
          ConcatLS (MacMenuPtr^.Choices, FormValue[i].CharValue^);
          ConcatS (MacMenuPtr^.Choices, ",");
        END;
      END;

      Procustes (MacMenuPtr^.Choices, (ORD(MacMenuPtr^.Choices[0])-1));
      ConcatS (MacMenuPtr^.Choices, Separator);

      (* Macros *)
      Procustes (MacMenuPtr^.Macros, 0);
      FOR i := 5 TO 15 BY 2 DO
        TrimRear (FormValue[i].CharValue^);
        IF LengthOf (FormValue[i].CharValue^) > 0 THEN
          ConcatS (MacMenuPtr^.Macros, "{");
          ConcatLS (MacMenuPtr^.Macros, FormValue[i].CharValue^);      (* Macros *)
          ConcatS (MacMenuPtr^.Macros, "}");
        END;
      END;


    ELSE
      MacMenuPtr := NIL;
    END;

    FOR i := 0 TO 15 DO
      DISPOSE(FormValue[i].CharValue);
    END;

    RETURN code <> CancelKey;

END DoMenu;

BEGIN
  FormAccepted := FALSE;
  IF DoMenu() THEN FormAccepted := TRUE; END;

  IF (FormAccepted AND Editing) THEN
    Replace (MacMenuPtr^.Title, " ", "ù");
    Replace (MacMenuPtr^.Message, " ", "ù");
    Replace (MacMenuPtr^.Prefix, " ", "ù");
    Replace (MacMenuPtr^.Choices, " ", "ù");
  END;

END MacMenuForm.
