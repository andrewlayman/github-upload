MODULE MacVarF;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

    (*  MODIFICATION HISTORY
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
    *)


FROM Dialog             IMPORT Error;


FROM Codes              IMPORT
                               SetCodeBits;

FROM FlexStor           IMPORT
                               CreateExtObject, AnExtHandle;

FROM Keyboard           IMPORT
                               AGetCodeProcedure, AServiceProcedure;

FROM Lights             IMPORT
                               RemoveLight;

FROM LStrings           IMPORT
                               Copy, SetString, ConcatS, ConcatLS, Procustes;

FROM MacBuffs           IMPORT
                               MacBuffer, PushBuffer;

FROM MacCancl           IMPORT
                               ClearPlayback;

FROM MacCodes           IMPORT
                               BeginCode, EndCode, NameCode, InCodeSet,
                               GetCodeString;

FROM MacHeader          IMPORT
                               MacHeaderStack, PushMacHeaderStack,
                               PopMacHeaderStack;

FROM MacLights          IMPORT
                               DoOurLight, RecordLight, InputLight;

FROM MacNodes           IMPORT
                               MacroRecordPointer, MacroNode, MacroTree;

FROM MacrosRc           IMPORT
                               CreateMacro, DeleteMacro,
                               FindMacroByName, FindMacroByHotkey,
                               SetMacroName, SetMacroHotKey,
                               SetMacroDescription, SetMacroHandle;

FROM MacStack           IMPORT
                               MacStack, GetACardinal, GetName;

FROM MacState           IMPORT
                               AState, PushState, PopState;

FROM MacStore           IMPORT
                               StoreMacro;

FROM MacTalk            IMPORT
                               MacDeath;

FROM MacVars            IMPORT
                               MacStoragePreference, ReplacedKeySet,
                               Interlock, KeyOffset,
                               RecordingSecondaryMacro,
                               NormKey, XKey,
                               OurCodeRecord,
                               ACodeRecordPointer,
                               SpecialCharSet, ExtendedCharSet;


FROM MsgFile            IMPORT
                               GetMessage;

FROM Overlays           IMPORT
                               OverlayContext;

(* Mods :
           6/4/88 - included hotkey in the secondary macro call
*)



VAR
      C          : CARDINAL;
      MacName    : ARRAY [0..40] OF CHAR;
      S          : ARRAY [0..255] OF CHAR;

(*------------------------------------------------------------------------

Does the Input Pauses and Secondary macros that are recorded during
playback of the parent (primary) macro.

-------------------------------------------------------------------------*)

PROCEDURE DoVariableField;

  (*------------------------------------------------------------------------

  If the secondary macro had been deleted by the user, this creates a new
  node and storage for the secondary macro (on the fly, so to speak).

  -------------------------------------------------------------------------*)

PROCEDURE CreateNewNestedMacro():BOOLEAN;

VAR
    buffer     : ARRAY [0..1] OF CARDINAL;
    length     : CARDINAL;
    ahotkeystr : ARRAY [0..10] OF CHAR;
    handle     : AnExtHandle;
    Copyright  : ARRAY[0..50] OF CHAR;


BEGIN
  Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  length := 0;
  buffer[0] := 0;
  PushMacHeaderStack;
  IF NOT CreateMacro (MacroNode) THEN
    MacDeath;
  END;
  MacHeaderStack^.record.hotkey := 0;
  SetString (MacHeaderStack^.record.hotkeystr, "         ");
  Copy (MacName, MacHeaderStack^.record.name);
  GetMessage (26473, S);
  Procustes (S, 49);
  Copy (S, MacHeaderStack^.record.description);
  IF NOT CreateExtObject (handle,
                          MacStoragePreference) THEN
    MacDeath;
  END;
  SetMacroHandle (MacroNode, handle);
  IF NOT StoreMacro (buffer, length, MacroNode, NIL, MacroTree) THEN
    MacDeath;
  END;
  PopMacHeaderStack;
  RETURN TRUE;
END CreateNewNestedMacro;




BEGIN
  GetACardinal (C);  (* must be either EndCode or NameCode *)
  IF CARDINAL(C) <> EndCode THEN    (* it must be a NameCode *)
    GetName (CARDINAL(C), MacName);
    GetACardinal (C);  (* {endinput} *)

    MacroNode := FindMacroByName (MacName);
    IF MacroNode = NIL THEN                   (* it's been deleted *)
      IF NOT CreateNewNestedMacro() THEN
        RemoveLight (InputLight);
        RETURN;
      END;
    END;

    PushState (Recording);
    RecordingSecondaryMacro := TRUE;
    IF NOT PushBuffer() THEN
      PopState;
      RETURN;
    END;
    MacBuffer^.count := 0;
  ELSE
    OurCodeRecord^.InputPause := TRUE;
    PushState (Neutral);
  END;
END DoVariableField;

BEGIN

  DoVariableField;

END MacVarF.
