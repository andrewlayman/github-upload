MODULE MacSec;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

(*

Mods - 5/25/88 LVK : Inserts only by name
       5/2/89 LVK  : Moved form to sepat\rate file "MACSECF.MOD" for
                     addition to TLFORMS file.
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
       13-Nov-89  RSC - Import from Space rather than Storage.
       22-Nov-89  RSC - Changed size of secondary macro name from 40 to 42.
       20-Dec-89  LVK - ReplacedMacros are no longer deleted. They are
                        assigned to new VAR MacVars.ReplacedMacro.
*)


FROM Codes                  IMPORT ACode, SetCodeBits;

FROM Dialog                 IMPORT ADialogOption, ContinuationBox,
                                   Error;

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
                                DoFormByHandle,
    (* PROC *)                  ShowValue,
                                DoForm;

FROM Kbio                   IMPORT maxrow;

FROM LStrings               IMPORT SetString, ConcatLS, ConcatS,
                                   Fill, Compare, TrimRear,
                                   Copy, Procustes;

FROM MacBuffs               IMPORT MacBuffer;

FROM MacCodes               IMPORT InCodeSet, CToStr, ExtendedCharStr;

FROM MacHeader              IMPORT
                                   MacHeaderStack, PushMacHeaderStack,
                                   AMacHeaderStackPtr,
                                   PopMacHeaderStack;

FROM MacCodes               IMPORT BeginCode, EndCode, NameCode,
                                   GetCodeString;

FROM MacNodes               IMPORT
                                   MacroTree, MacroNode;
 
FROM MacrosRc               IMPORT
                                   FindMacroByName,
                                   FindMacroByHotkey,
                                   GetMacroName,
                                   SetMacroHotKey,
                                   SetMacroHotKeyStr,
                                   GetMacroHotKeyStr,
                                   ClearMacNode,
                                   CreateMacro;

FROM MacSetUp               IMPORT
                                   StartRecordKey, StopRecordKey,
                                   ListKey, MenuKey, MacInsertKey;

FROM MacState               IMPORT PopState;

FROM MacStore               IMPORT StoreMacro,
                                   StoreReplacementMacro;

FROM MacTalk                IMPORT MacDeath;

FROM MacVars                IMPORT 
                                   DoRecord, PlaybackOK,
                                   ReplacedMacro,
                                   StealHotkeyNode,
                                   FormAccepted,
                                   ReplacedKeySet, Editing,
                                   SpecialCharSet, ExtendedCharSet;

FROM MsgFile                IMPORT GetMessage, DisplayMessage;

FROM Keys                   IMPORT CancelKey;

FROM Overlays               IMPORT OverlayContext;

FROM Rugs                   IMPORT ARug;

FROM Space                  IMPORT Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT TSIZE, SIZE;

FROM TreeObjects            IMPORT ATreeNode;

FROM Words                  IMPORT ParseBal;



CONST NameLength = 40;
      HotkeyStrLength = 10;

TYPE MacRecordPtr = POINTER TO RECORD
                                 name      : ARRAY [0..42] OF CHAR; (* 22-Nov-89 RSC was 40 *)
                                 hotkey    : CARDINAL;
                                 hotkeystr : ARRAY [0..10] OF CHAR;
                               END;

VAR
     str                : ARRAY [0..80] OF CHAR;
     S                  : ARRAY [0..255] OF CHAR;
     WasPlaybackOK      : BOOLEAN;
     temp               : AMacHeaderStackPtr;
     MacRecord          : MacRecordPtr;
     NameNode,
     HotkeyNode         : ATreeNode;

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

  CONST jump = 8000H;

  VAR   title               : ARRAY [0..31] OF CHAR;
        MacroName           : ARRAY [0..40] OF CHAR;
        phrase1,
        phrase2             : ARRAY [0..80] OF CHAR;
        i                   : CARDINAL;

  BEGIN
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
      IF ORD(str[0]) = 0 THEN
        DisplayMessage (26325);
        code := 0;
        RETURN FALSE;
      END;
    END;
    CASE fieldno OF
      0 : IF checkreason = CheckFieldEntry THEN
            DisplayMessage (41300);
            code := 0;
            RETURN TRUE;
          ELSIF ((checkreason = CheckFieldExit) OR
                 (checkreason = CheckFormExit)) THEN
            Copy (FormValue[0].CharValue^, str);
            TrimRear (str);

            IF ORD(str[0]) <> 0 THEN

             (* check for macros in progress with same name *)
              temp := MacHeaderStack;
              LOOP
                IF temp = NIL THEN EXIT; END;
                IF Compare (FormValue[0].CharValue^, temp^.record.name) = 0 THEN
                  GetMessage (26326, S);
                  Error (S);
                  code := 0;
                  RETURN FALSE;
                END;
                temp := temp^.next;
              END;

              IF Compare (FormValue[0].CharValue^,
                        ReplacementOKRecord.Name) <> 0 THEN
                Procustes (str, 40);
                Copy (str, ReplacementOKRecord.Name);
                (* now check for macros in memory by the same name *)
                MacroNode := FindMacroByName (FormValue[0].CharValue^);
                IF MacroNode <> NIL THEN
                  NameNode := MacroNode;
                  GetMessage (26327, S);
                  GetMessage (26328, title);
                  IF ContinuationBox (S, title, NoHelp) THEN
                    ReplacedMacro := MacroNode;
                    code := jump + 1;   (* jumps to next field, field #2 *)
                    RETURN TRUE;
                  ELSE
                    NameNode := NIL;
                    ReplacedMacro := NIL;
                    Fill(ReplacementOKRecord.Name, ' ', NameLength);
                    code := 0;
                    RETURN FALSE;
                  END;
                END;
              END;
              code := 0;
              RETURN TRUE;
            ELSE
              DisplayMessage (26325);
              code := 0;
              NameNode := NIL;
              ReplacedMacro := NIL;
              Fill(ReplacementOKRecord.Name, ' ', NameLength);
              RETURN FALSE;
            END;
          ELSIF ((checkreason = CheckFieldKey) AND (code = 32)) THEN
            code := CARDINAL(BITSET(ORD("_")) + {14});
            RETURN TRUE;
          END|

      1 : IF checkreason = CheckFieldEntry THEN
            DisplayMessage (41301);
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
              IF NOT ExtendedCharStr (str, code)
              THEN
                GetMessage (26319, S);
                Error (S);
                code := 0;
                RETURN FALSE;
              END;
            END;  
            code := 0;
            RETURN TRUE;
          ELSIF ((checkreason = CheckFieldKey) AND (code <> 32)) THEN

              (* check for macros in progress with same hotkey *)
            temp := MacHeaderStack;
            LOOP
              IF temp = NIL THEN EXIT; END;
              IF code = temp^.record.hotkey THEN
                GetMessage (26329, S);
                Error (S);
                code := 0;
                RETURN TRUE;
              END;
              temp := temp^.next;
            END;
  
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
                ParseBal (S, i, phrase1);
                ParseBal (S, i, phrase2);
                Copy (phrase1, S);
                ConcatLS (S, MacroName);
                TrimRear (S);
                ConcatLS (S, phrase2); 
                GetMessage (26328, title);
                IF ContinuationBox (S, title, NoHelp) THEN
                  StealHotkeyNode := HotkeyNode;
                  (*code := jump + 2;   (* jumps to next field, field #2 *)
                  RETURN TRUE;*)
                ELSE
                  SetString (FormValue[1].CharValue^, "          ");
                  ShowValue (form, fieldno, FormValue);
                  code := 0;
                  FormValue[1].CardValue := code;
                  RETURN FALSE;
                END;
              END;
            END;
          code := jump + 2;
          RETURN TRUE
        END|
      2 : IF checkreason  = CheckFieldEntry THEN
            DisplayMessage (41302);
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
    cULX                    = 4;
    cULY                    = 15;
    cLRX                    = 75;
    MaxLine                 = 4;
    
VAR
    FormRecord              : POINTER TO AFormRecord;
    FormValue               : ARRAY [0..2] OF AFieldValue;
    FormHandle              : AFormHandle;
    code                    : ACode;
    LRY                     : CARDINAL;
    i, j                    : CARDINAL;
    buffer                  : ARRAY [0..1] OF CARDINAL;
    length                  : CARDINAL;
    Copyright               : ARRAY[0..50] OF CHAR;




      PROCEDURE FillMacHeaderStack;
      BEGIN
        Procustes (FormValue[0].CharValue^, 40);
        Copy (FormValue[0].CharValue^, MacHeaderStack^.record.name);
        MacHeaderStack^.record.hotkey := FormValue[1].CardValue;
        Copy (FormValue[1].CharValue^, MacHeaderStack^.record.hotkeystr);
        Copy (FormValue[2].CharValue^, MacHeaderStack^.record.description);
      END FillMacHeaderStack;



BEGIN                       (* GetFileName *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    FormValue[1].CardValue := 0;

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
        GetMessage (26330, S);
        Error (S);
        FOR i := 0 TO j-1 DO
           DISPOSE (FormValue[i].CharValue);
(*           DISPOSE (FormRecord);*)    (* 20-Mar-90 RSC Deleted this *)
        END;
        RETURN FALSE;
      END;
      INC (i); INC (j);
      IF i > 2 THEN EXIT; END;
    END;
      
    IF Available (TSIZE(AFormRecord)) THEN
      NEW(FormRecord);
    ELSE
      GetMessage (26305, S);
      Error (S);
      RETURN FALSE;
    END;

     (* name *)
    Fill (FormValue[0].CharValue^, ' ', 40);
     (* hotkey *)
    Fill (FormValue[1].CharValue^, ' ', 10);
     (* hotkey *)
    Fill (FormValue[2].CharValue^, ' ', 49);

    IF NOT GetFormRecordByNumber (113, FormRecord^) THEN
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
        LRY := maxrow-10 + MaxLine + 2;

        DISPOSE(FormRecord);   (* We no longer need our copy. *)

        code := DoFormByHandle(cULX, maxrow-10, cLRX, LRY,
                               FormHandle,
                               TRUE, FormValue, OurCheckProc);
        DiscardFormHandle(FormHandle);

    ELSE
        DISPOSE(FormRecord);
    END;


    IF code <> CancelKey THEN

          (* get the name into MacRecord *)
          TrimRear (FormValue[0].CharValue^);
          SetString (MacRecord^.name, "{");
          ConcatLS (MacRecord^.name, FormValue[0].CharValue^);
          ConcatS (MacRecord^.name, "}");

          (* get the hotkey into MacRecord *)
          IF FormValue[1].CardValue <> 0 THEN
            MacRecord^.hotkey := FormValue[1].CardValue;
            IF (InCodeSet (SpecialCharSet, FormValue[1].CardValue) OR
                InCodeSet (ExtendedCharSet, FormValue[1].CardValue)) THEN
              GetCodeString (FormValue[1].CardValue, MacRecord^.hotkeystr);
            END;
          END;

      IF NOT Editing THEN  (* put it all in the recording *)
 
        (* get name *)     
        Copy (FormValue[0].CharValue^, str);
        TrimRear (str);

        (* start secondary macro *)
        MacBuffer^.buffer[MacBuffer^.count] := BeginCode;
        INC (MacBuffer^.count);

        (* start name *)
        MacBuffer^.buffer[MacBuffer^.count] := NameCode;
        INC (MacBuffer^.count);

        (* put in name *)
        FOR i := 1 TO ORD(str[0]) DO
          MacBuffer^.buffer[MacBuffer^.count] := ORD(str[i]);
          INC (MacBuffer^.count);
        END;

        (* end name *)
        MacBuffer^.buffer[MacBuffer^.count] := NameCode;
        INC (MacBuffer^.count);
        
        (* end secondary macro *)
        MacBuffer^.buffer[MacBuffer^.count] := EndCode;
        INC (MacBuffer^.count);

      END;

      IF MacroNode = NIL THEN
        PushMacHeaderStack;
        FillMacHeaderStack;
        length := 0;        (* was 1 *)
        buffer[0] := 0;
        IF NOT CreateMacro (MacroNode) THEN
          GetMessage (26331, S);
          Error (S);
          MacDeath;
        END;
        IF NOT StoreMacro (buffer, length, MacroNode, NIL, MacroTree) THEN
          GetMessage (26332, S);
          Error (S);
          MacDeath;
        END;
        PopMacHeaderStack;
      ELSIF ReplacedMacro <> NIL THEN
        IF NOT ClearMacNode(ReplacedMacro) THEN
          MacDeath;
        END;
        PushMacHeaderStack;
        FillMacHeaderStack;
        IF NOT StoreReplacementMacro(buffer, length, ReplacedMacro) THEN
          MacDeath;
        END;
        PopMacHeaderStack;
        ReplacedMacro := NIL;
      END;
      IF StealHotkeyNode <> NIL THEN
        SetMacroHotKey(StealHotkeyNode, 0);
        Fill(S, ' ', 10);
        SetMacroHotKeyStr(StealHotkeyNode,S);
        StealHotkeyNode := NIL;
      END;
      
    END;

    DISPOSE(FormValue[0].CharValue);
    DISPOSE(FormValue[1].CharValue);
    DISPOSE(FormValue[2].CharValue);

    RETURN code <> CancelKey;

END GetOptions;

BEGIN
  WasPlaybackOK := PlaybackOK;
  PlaybackOK := FALSE;
  DoRecord := FALSE;
  FormAccepted := FALSE;
  MacRecord := OverlayContext();
  IF GetOptions() THEN 
    DoRecord := TRUE;
    FormAccepted := TRUE;
  END;
  PlaybackOK := WasPlaybackOK;
  PopState;
END MacSec.
