MODULE MacNest;

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



FROM FlexStor        IMPORT
                            CreateExtObject, DiscardExtObject,
                            SetExtData;

FROM MacBuffs        IMPORT
                            PopBuffer, MacBuffer, PutCodeInBuffer;

FROM MacNodes        IMPORT
                            MacroRecordPointer, MacroNode;

FROM MacState        IMPORT
                            PopState;

FROM MacTalk         IMPORT
                            MacDeath;

FROM MacVars         IMPORT
                            FormAccepted, MacStoragePreference;

FROM SYSTEM          IMPORT
                            ADR;

(*------------------------------------------------------------------------

Saves a secondary macro (nested) that was recorded inside a macro that
is being played back.

-------------------------------------------------------------------------*)

PROCEDURE SaveNestedMacro():BOOLEAN;

VAR
    i, C : CARDINAL;
    Copyright       : ARRAY[0..50] OF CHAR;
BEGIN
  Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  PopState;
  FOR i := 0 TO 1 DO            (* Put sentinals at end; *)
    C := 65432;
    IF PutCodeInBuffer(C) THEN END;
  END;
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  IF MacroRecordPointer = NIL THEN MacDeath; END;
  DiscardExtObject (MacroRecordPointer^.handle);
  IF NOT CreateExtObject (MacroRecordPointer^.handle,
                          MacStoragePreference) THEN
    MacDeath;
  END;
  IF NOT SetExtData (MacroRecordPointer^.handle,
                     ADR(MacBuffer^.buffer),
                     MacBuffer^.count * 2) THEN
    MacDeath;
  END;
  MacroRecordPointer^.cardlen := MacBuffer^.count;
  MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);
  PopBuffer;
  RETURN TRUE;
END SaveNestedMacro;



BEGIN

  FormAccepted := FALSE;
  IF SaveNestedMacro() THEN
    FormAccepted := TRUE;
  END;
  
END MacNest.
