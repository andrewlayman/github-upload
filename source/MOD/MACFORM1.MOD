(*<BIND IMPLEMENTATION BIND>*) MODULE MacForm1;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)



(* Modification History :

    3/20/88 LVK : Macro names upshifted to caps.
    4/27/89 LVK : Form moved to separate file.
              Continue to use DoFormByHandle for CheckCodeSet in order
              to exclude macro hotkeys from available set.
    
    10-Aug-89 KKC - Add copyright message.
    01-Oct-89 WKH - ReSynch code btwn Cybersoft & Symantec.
    13-Nov-89 RSC - Import from Space rather than Storage.
    20-Dec-89 LVK - Replaced macros are no longer deleted. They are
                    assigned to new VAR MacVars.ReplacedMacro, used
                    to keep the node and replace contents.

    04-Jan-90 LVK - Use MacVars.StealHotkeyNode in order to reassign
                    confilcting hotkey used in other macro.
    23-Sep-90 TGS - Blank out hotkey field on entry to prevent assigning
                    it to more than one macro when copying. If we ever 
                    change things to allow hotkey and description to be
                    directly editable after the macro has been created,
                    this will have to change or it would blank the hotkey
                    during edit. 
    20-Oct-90 RSC - Added BIND toggles.
                    Made minor tweaks to put things on the stack
                    rather than in globals.
    12-Nov-90 TGS - Merge changes made to 4.03.
     2-Aug-91 PFG - A call to ParseBal was clobbering the string that was
                    being built to report the "...hotkey is in use by
                    another macro..." error.  Added another string for
                    temporary storage.
*)


FROM Codes                  IMPORT ACode, SetCodeBits;

FROM Dialog                 IMPORT Error, Burp;
                                   
FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

FROM FormHand               IMPORT
    (* TYPE *)                  AFormHandle,
    (* PROC *)                  AttachHandleToRecord, DiscardFormHandle;


FROM FormRead               IMPORT
                                GetFormRecordByNumber;
                                    
FROM FormRec                IMPORT
    (* TYPE *)                  AFormRecord;

FROM Forms                  IMPORT
    (* TYPE *)                  AForm, AFieldValue, ACheckReason,
    (* PROC *)                  DoFormByHandle, ShowValue;

FROM Kbio                   IMPORT maxrow;

FROM Keys                   IMPORT CancelKey;

FROM LStrings               IMPORT SetString, Compare,
                                   ConcatLS, SetLengthOf,
                                   Fill, TrimRear,
                                   Copy, Procustes;

FROM MacCodes               IMPORT
                                   CToStr, ExtendedCharStr;

FROM MacHeader              IMPORT
                                   MacHeaderStack;

FROM MacrosRc               IMPORT
                                   FindMacroByName,
                                   FindMacroByHotkey,
                                   GetMacroHotKey,
                                   GetMacroName,
                                   GetMacroHotKeyStr,
                                   GetMacroDescription;

FROM MacSetUp               IMPORT
                                   StartRecordKey, StopRecordKey,
                                   ListKey, MenuKey, MacInsertKey;


FROM MacTalk                IMPORT MacDeath;

FROM MacVars                IMPORT 
                                   DoRecord, PlaybackOK,
                                   FormAccepted,
                                   ReplacedMacro,
                                   StealHotkeyNode,
                                   ReplacedKeySet;

FROM Menus                  IMPORT NoYes;

FROM MsgFile                IMPORT GetMessage, DisplayMessage;

FROM Overlays               IMPORT OverlayContext;
                                   
FROM Space                  IMPORT Available;

FROM Space                  IMPORT ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT TSIZE, SIZE;

FROM TreeObjects            IMPORT ATreeNode;

FROM Words                  IMPORT ParseBal;



CONST NameLength = 40;
      HotkeyStrLength = 10;

VAR
     NameNode,
     HotkeyNode    : ATreeNode;

(*-------------------------------------------------------------------
Used to track confirmation, so user is only prompted once about
the action to be taken, i.e. "Replace Macro?" & "Steal Hotkey?".
 - ReplacementOKRecord.Name is the last name ok'd to replace.
 - ReplacementOKRecord.HotkeyStr is the last hotkey ok'd for theft.
 - Used for both FieldExit & FormExit.
--------------------------------------------------------------------- *)
        ReplacementOKRecord : RECORD
                                Name      : ARRAY [0..NameLength] OF CHAR;
                                HotkeyStr : ARRAY [0..HotkeyStrLength] OF CHAR;
                              END;









  PROCEDURE OurCheckProc (form            : AForm;
                          fieldno         : AFieldNo;
                          VAR FormValue   : ARRAY OF AFieldValue;
                          checkreason     : ACheckReason;
                          VAR code        : CARDINAL):BOOLEAN;

  CONST jump       = 8000H;

  VAR
        i                   : CARDINAL;
        MacroNode           : ATreeNode;
        title               : ARRAY [0..31] OF CHAR;
        MacroName           : ARRAY [0..40] OF CHAR;
        phrase              : ARRAY [0..80] OF CHAR;
        S                   : ARRAY [0..255] OF CHAR;
        str                 : ARRAY [0..80] OF CHAR;
        SStart              : ARRAY [0..80] OF CHAR;

  BEGIN
    IF checkreason = CheckFormEntry THEN
      MacroNode := OverlayContext();
      IF NOT (MacroNode = NIL) THEN
        GetMacroName (MacroNode, FormValue[0].CharValue^);
        SetLengthOf (FormValue[1].CharValue^, 0);  (* 23-Sep-90 TGS *)
(*      GetMacroHotKeyStr (MacroNode, FormValue[1].CharValue^); *)
        GetMacroDescription (MacroNode, FormValue[2].CharValue^);
        FormValue[1].CardValue := GetMacroHotKey (MacroNode);
        ShowValue (form, 0, FormValue);
        ShowValue (form, 1, FormValue);
        ShowValue (form, 2, FormValue);
      END;
    END;
    IF NOT ((checkreason = CheckFieldKey) OR
            (checkreason = CheckFieldEntry) OR
            (checkreason = CheckFieldExit) OR
            (checkreason = CheckFormExit)) THEN
      code := 0;
      RETURN TRUE;
    END;
    IF checkreason = CheckFormExit THEN
      Copy (FormValue[0].CharValue^, str);
      TrimRear (str);
      IF ((FormValue[1].CardValue = 0) AND (ORD(str[0]) = 0)) THEN
        Burp;
        code := 0;
        RETURN FALSE;
      END;
    END;
    CASE fieldno OF
      0 : IF checkreason = CheckFieldEntry THEN
            code := 0;
            RETURN TRUE;
          ELSIF ((checkreason = CheckFieldExit) OR
                 (checkreason = CheckFormExit)) THEN
            Copy (FormValue[0].CharValue^, str);
            TrimRear (str);

            IF ORD(str[0]) <> 0 THEN

              IF Compare (FormValue[0].CharValue^,
                        ReplacementOKRecord.Name) <> 0 THEN
                Procustes (str, 40);
                Copy (str, ReplacementOKRecord.Name);
                MacroNode := FindMacroByName (str);
                IF MacroNode <> NIL THEN
                  NameNode := MacroNode;
                  GetMessage (26300, S);
                  IF NoYes (S) THEN
                    ReplacedMacro := MacroNode;
                    code := jump + 1;   (* jumps to next field, field #2 *)
                    RETURN TRUE;
                  ELSE
                    ReplacedMacro := NIL;
                    NameNode := NIL;
                    Fill (ReplacementOKRecord.Name, ' ', NameLength);
                    code := 0;
                    RETURN FALSE;
                  END;
                END;
              END;
            ELSE
              DisplayMessage (26302);
              code := 0;
              ReplacedMacro := NIL;
              NameNode := NIL;
              Fill (ReplacementOKRecord.Name, ' ', NameLength);
              RETURN FALSE;
            END;
          ELSIF ((checkreason = CheckFieldKey) AND (code = 32)) THEN
            code := CARDINAL(BITSET(ORD("_")) + {14});
            RETURN TRUE;
          END|

      1 : IF checkreason = CheckFieldEntry THEN
            code := 0;
            RETURN TRUE;
          ELSIF ((checkreason = CheckFieldExit) OR 
                 (checkreason = CheckFormExit)) THEN
            Copy (FormValue[1].CharValue^, str);
            TrimRear (str);
            IF ORD (str[0]) = 0 THEN
              FormValue[1].CardValue := 0;
              StealHotkeyNode := NIL;
              HotkeyNode := NIL;
              Fill(ReplacementOKRecord.HotkeyStr, ' ', HotkeyStrLength);
            ELSE
              IF NOT (ExtendedCharStr (str, code)) THEN
                GetMessage (26303, S);
                Error (S);
                code := 0;
                RETURN FALSE;
              END;
            END;  
            code := 0;
            RETURN TRUE;
          ELSIF ((checkreason = CheckFieldKey) AND (code <> 32)) THEN
              CToStr (code, str);
              FormValue[1].CardValue := code;
              Copy (str, FormValue[1].CharValue^);
              ShowValue (form, fieldno, FormValue);
              Copy (str, ReplacementOKRecord.HotkeyStr);

              IF ((code MOD 16) IN ReplacedKeySet[code DIV 16]) THEN
                HotkeyNode := FindMacroByHotkey (code);
                IF HotkeyNode <> NameNode THEN
                  GetMacroName (HotkeyNode, MacroName);
                  GetMessage (26304, S);
                  i := 1;
                  ParseBal (S, i, SStart);          (* 2-Aug-91 PFG  Use SStart, not S. *)
                  ParseBal (S, i, phrase);
                  Copy(SStart, S);                  (* 2-Aug-91 PFG *)
                  ConcatLS (S, MacroName);
                  TrimRear (S);
                  ConcatLS (S, phrase); 
                  GetMessage (26301, title);
                  IF NoYes (S) THEN
                    (* steal the hotkey *)
                    StealHotkeyNode := HotkeyNode;
                  ELSE
                    SetString (FormValue[1].CharValue^, "          ");
                    ShowValue (form, fieldno, FormValue);
                    code := 0;
                    FormValue[1].CardValue := code;
                    RETURN FALSE;
                  END;
                  code := jump + 2;   (* jumps to next field, field #2 *)
                  RETURN TRUE;
                END;
                code := jump + 2;   (* jumps to next field, field #2 *)
                RETURN TRUE;
              END;
              IF FormValue[1].CardValue <> 0 THEN
                code := jump + 2;
              ELSE
                code := jump + 1;
              END;

              RETURN TRUE;
            (*END;*)
          END;|

      2 : IF checkreason  = CheckFieldEntry THEN
            code := 0;
            RETURN TRUE;
          ELSIF code = 32 THEN
            code := CARDINAL(BITSET(ORD(" ")) + {14});
            RETURN TRUE;
          END;
    ELSE ;
    END;
    code := 0;
    RETURN TRUE;
  END OurCheckProc;




PROCEDURE GetOptions(): BOOLEAN;

CONST
    cThisForm               = 1;
    cULX                    = 4;
    cLRX                    = 75;
    
VAR
    FormRecord              : POINTER TO AFormRecord;
    FormHandle              : AFormHandle;
    code                    : ACode;
    LRY                     : CARDINAL;
    i, j                    : CARDINAL;
    FormValue               : ARRAY [0..2] OF AFieldValue;
    S                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* GetFileName *)

    S := "Program Copyright (c) 1989 Symantec Corporation.";

    IF Available (TSIZE(AFormRecord)) THEN
      NEW(FormRecord);
    ELSE
      GetMessage (26305, S);
      Error (S);
      RETURN FALSE;
    END;
    
    ReplacedMacro := NIL;
    StealHotkeyNode := NIL;
    NameNode := NIL;
    HotkeyNode := NIL;
    Fill (ReplacementOKRecord.Name, ' ', NameLength);
    Fill (ReplacementOKRecord.HotkeyStr, ' ', HotkeyStrLength);
    
        (* allocate memory  *)
    i := 0; j := 0;
    LOOP
      IF Available (SIZE(FormValue[i].CharValue^)) THEN 
        NEW(FormValue[i].CharValue);
      ELSE
        GetMessage (26306, S);
        Error (S);
        FOR i := 0 TO j-1 DO
           DISPOSE (FormValue[i].CharValue);
           DISPOSE (FormRecord);
        END;
        RETURN FALSE;
      END;
      INC (i); INC (j);
      IF i > 2 THEN EXIT; END;
    END;
          
    (* name *)
    Fill (FormValue[0].CharValue^, ' ', 40);
    FormValue[1].CardValue := 0;
     (* hotkey string *)
    Fill (FormValue[1].CharValue^, ' ', 10);
     (* description *)
    Fill (FormValue[2].CharValue^, ' ', 49);

    IF NOT GetFormRecordByNumber (110, FormRecord^) THEN
      MacDeath;
    END;

    WITH FormRecord^ DO
        (* Remove Macro Hotkeys *)
      SetCodeBits(CheckCodeSet, StartRecordKey, StartRecordKey, FALSE);
      SetCodeBits(CheckCodeSet, StopRecordKey, StopRecordKey, FALSE);
      SetCodeBits(CheckCodeSet, MenuKey, MenuKey, FALSE);
      SetCodeBits(CheckCodeSet, ListKey, ListKey, FALSE);
      SetCodeBits(CheckCodeSet, MacInsertKey, MacInsertKey, FALSE);
    END;

 
    code := CancelKey;
    
    IF (AttachHandleToRecord(FormHandle,FormRecord^)) THEN

        LRY := maxrow - 9 + FormRecord^.MaxLine + 2;

        DISPOSE(FormRecord);   (* We no longer need our copy. *)

        code := DoFormByHandle(cULX, maxrow - 9, cLRX, LRY,
                               FormHandle,
                               TRUE, FormValue, OurCheckProc);

        DiscardFormHandle(FormHandle);

    ELSE
        DISPOSE(FormRecord);
    END;

    IF code <> CancelKey THEN
      Copy (FormValue[0].CharValue^, MacHeaderStack^.record.name);
      MacHeaderStack^.record.hotkey := FormValue[1].CardValue;
      Copy (FormValue[1].CharValue^, MacHeaderStack^.record.hotkeystr);
      Copy (FormValue[2].CharValue^, MacHeaderStack^.record.description);
    END;

    DISPOSE(FormValue[0].CharValue);
    DISPOSE(FormValue[1].CharValue);
    DISPOSE(FormValue[2].CharValue);

    RETURN code <> CancelKey;

END GetOptions;



PROCEDURE DoMacForm1();
VAR
    WasPlaybackOK : BOOLEAN;

BEGIN

  WasPlaybackOK  := PlaybackOK;
  FormAccepted   := FALSE;
  PlaybackOK     := FALSE;
  DoRecord       := FALSE;
  IF GetOptions() THEN 
    DoRecord     := TRUE;
    FormAccepted := TRUE;
  END;
  PlaybackOK     := WasPlaybackOK;

END DoMacForm1;



(*<BIND
PROCEDURE MacForm1Bind();
BIND>*)

BEGIN

    DoMacForm1();

(*<BIND
END MacForm1Bind;
BIND>*) 

END MacForm1.

