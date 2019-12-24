(*<BIND IMPLEMENTATION BIND>*) MODULE MacEdit;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

(*
Modifications:  
     10-Aug-89  KKC - Add copyright message.
     01-Oct-89  WKH - ReSynch code btwn Cybersoft & Symantec.
     13-Nov-89  RSC - Import from Space rather than Storage.
     13-Jan-90  LAA - Detect that the macro editing is to be saved if the 
                      Changed parameter of EditText is returned TRUE.  This 
                      was done to correct a problem when using the mouse, in
                      which you could click on the OK button, but the macro 
                      would not be saved.  Reason for this is that the OK
                      button pushes an EVENT equal to F10, but macros never 
                      sees it.  Macros doesn't see it because he's monitoring
                      GetAnyCode, and a pushed event will be returned without
                      having to call GetAnyCode.  Since seeing F10 is how
                      macros knows that the macro is to be saved, he missed
                      it.  This is NOT a complete solution, but it's the best
                      I can do given the lack of time before we ship!  

     20-Oct-90  RSC - Added BIND toggles.
                      Made minor tweaks to put things on the stack
                      rather than in globals.
*)


(* Edit the macro *)


FROM Boxes           IMPORT ABoxType, ABoxAttribute;

FROM Codes           IMPORT EmptyCodeSet, SetCodeBits;

FROM Dialog          IMPORT Message, Error,
                            ABoxHandle, ProgressBox, ReleaseBox;

FROM Edits           IMPORT EditText;

FROM FlexStor        IMPORT CreateExtObject, DiscardExtObject, SetExtData,
                            AnExtHandle;

FROM Kbio            IMPORT EraseLn, maxrow;

FROM LStrings        IMPORT LStringToTString, SetString, Copy, TrimRear,
                            ConcatLS, ConcatS, Fill, CtoS;

FROM MacBuffs        IMPORT MaxKeystrokes;

FROM MacHeader       IMPORT
                            MacHeaderStack, PushMacHeaderStack,
                            PopMacHeaderStack;

FROM MacNodes        IMPORT MacroTree, AMacroRecordPointer;

FROM MacrosRc        IMPORT
                            FindMacro, DeleteMacro,
                            FindMacroByHotkey, FindMacroByName,
                            CreateMacro;

FROM MacTalk         IMPORT MacDeath;

FROM MacVars         IMPORT Editing, SaveEdits,  MacStoragePreference,
                            EditMacroChange, EditCancel, OurEditRecord,
                            FormAccepted, ReplacedKeySet, Interlock;

FROM MacXlate        IMPORT MacToText, TextToMac;

FROM MsgFile         IMPORT GetMessage;

FROM Overlays        IMPORT OverlayContext;

FROM Rugs            IMPORT ARug, GetRug, PutRug;

FROM Space           IMPORT ALLOCATE, DEALLOCATE;

FROM SYSTEM          IMPORT ADDRESS, ADR;

FROM Text            IMPORT AText, CreateText, DiscardText, SizeOfText;

FROM TreeObjects     IMPORT ATreeNode;


CONST
    RugULX  = 0;
    RugULY  = 7;
    RugLRX  = 79;
    CancelKey = 27;
    MaxMacroSize = 1500;





PROCEDURE DoMacEdits();

VAR
    MacroRecordPointer : AMacroRecordPointer;
    TextRow,
    CurC,
    CurR          : CARDINAL;
    result        : INTEGER;
    rug           : ARug;
    Buffer        : POINTER TO ARRAY [0..2000] OF CARDINAL;
    handle        : AnExtHandle;
    WasInterlock,
    len           : CARDINAL;
    boxhandle     : ABoxHandle;
    Changed       : BOOLEAN;
    box           : ABoxType;
    title,
    MacName       : ARRAY [0..80] OF CHAR;
    S             : ARRAY [0..80] OF CHAR;




PROCEDURE DoTitle;
BEGIN
  Copy (MacroRecordPointer^.name, title);
  TrimRear (title);
  ConcatS (title, " ");
  ConcatLS (title, MacroRecordPointer^.hotkeystr);
  TrimRear (title);
END DoTitle;





PROCEDURE ProcessMacro():BOOLEAN;

BEGIN
        IF TextToMac (OurEditRecord^.MacText, Buffer^, len)THEN
          MacroRecordPointer :=
                     OurEditRecord^.Macro^.Methods^.LockFlexStorDataObject
                                          (OurEditRecord^.Macro);

          handle := MacroRecordPointer^.handle;
          DiscardExtObject (handle);
          IF NOT CreateExtObject (handle, MacStoragePreference) THEN
            MacDeath;
          END;
          IF NOT SetExtData (handle, ADR (Buffer^), len*2) THEN
            MacDeath;
          END;
          IF MacroRecordPointer = NIL THEN
            MacDeath;
          END;
          MacroRecordPointer^.cardlen := len;
          MacroRecordPointer^.handle := handle;
          OurEditRecord^.Macro^.Methods^.UnlockFlexStorDataObject
                                                  (OurEditRecord^.Macro);
          RETURN TRUE;
        ELSE
          RETURN FALSE;
        END;
        
END ProcessMacro;





PROCEDURE StartEdits;

BEGIN

  NEW (Buffer);
  WasInterlock := Interlock;
  Interlock := 0;
  Changed := FALSE;
  SaveEdits := FALSE;
  PushMacHeaderStack;
  OurEditRecord^.MacText := CreateText();
  MacroRecordPointer :=
     OurEditRecord^.Macro^.Methods^.LockFlexStorDataObject
                                          (OurEditRecord^.Macro);

  GetMessage (26391, S);
  boxhandle := ProgressBox (S);
  MacToText (MacroRecordPointer, OurEditRecord^.MacText);
  ReleaseBox (boxhandle);
  
  DoTitle;
  IF NOT GetRug (RugULX, RugULY, RugLRX, (maxrow) - 1, rug) THEN MacDeath; END;
  box := ABoxType{DoubleBox, ShadowBox};
  OurEditRecord^.Macro^.Methods^.UnlockUnchangedDataObject
         (OurEditRecord^.Macro);

END StartEdits;





PROCEDURE EndEdits;
VAR
     Copyright : ARRAY[0..50] OF CHAR;
BEGIN
  Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  DISPOSE (Buffer);
  DiscardText (OurEditRecord^.MacText);
  (*EraseLn (0);*)                         (* 9/23/89 *)
  PutRug (RugULX, RugULY, RugLRX, (maxrow) - 1, rug);
  PopMacHeaderStack;
  Interlock := WasInterlock;
END EndEdits;




BEGIN  (* MacEdits *)

  StartEdits;

  LOOP  (* exit iff (ProcessMacro = TRUE) OR (NOT SaveEdits) *)
    Editing := TRUE; EditMacroChange := FALSE;
    EditText (RugULX, RugULY, RugLRX, (maxrow) - 1, box, title, 0,
              OurEditRecord^.MacText, Changed);
    Editing := FALSE; EditMacroChange := FALSE; EditCancel := FALSE;

    IF (Changed) THEN                                          (* 13-Jan-90 *)
      SaveEdits := TRUE;
    END;

    IF SaveEdits THEN
    
      GetMessage (26391, S);
      boxhandle := ProgressBox (S);
      IF ProcessMacro() THEN
        ReleaseBox (boxhandle);
        EXIT;
      ELSE
        ReleaseBox (boxhandle);
      END;

    ELSE
      (*OurEditRecord^.Macro^.Methods^.UnlockUnchangedDataObject
         (OurEditRecord^.Macro);*)
      EXIT;
    END;
  END; (* loop *)

  EndEdits;

END DoMacEdits;





(*<BIND
PROCEDURE MacEditBind();
BIND>*)

BEGIN

    DoMacEdits();

(*<BIND
END MacEditBind;
BIND>*) 


END MacEdit.
