MODULE MacRec;

    (*  MODIFICATION HISTORY
       10-Aug-89  KKC - Add copyright message.
       01-Ock-89  WKH - ReSynched code btwn Cybersoft & Symantec
       13-Nov-89  RSC - Import from Space rather than Storage.
       16-Nov-89  LVK - Disabled Insert Menu when recording Secondary Macro,
                        and disabled the Macro Menu for the same situation.
       19-Dec-89  RSC - Load MACMENUD into the reserved layer.
        8-Mar-90  RSC - Removed "MenuOn" parameter to MacMenuD.
       10-May-91  PFG   Removed two global variables (MacName and MacNamePtr)
                        and created local variables on stack where needed so
                        they can be passed to overlays.
       30-May-91  RSC   Removed globals, removed "Nothing" shutdown proc.
    *)

IMPORT Keyboard;

FROM Codes  IMPORT MaxCode;

FROM Dialog IMPORT Burp;

FROM Keys IMPORT ExitKey;

FROM LStrings IMPORT SetString, Copy, TrimRear;

FROM Lights IMPORT RemoveLight;

FROM MacBuffs IMPORT MacBuffer, PutStrInBuffer, PutCodeInBuffer;

FROM MacCancl IMPORT ClearPlayback, ClearMacStacks;

FROM MacCodes IMPORT CodeIsAHotKey, NameCode, InCodeSet;

FROM MacDo IMPORT DoMacroByHotkey;

FROM MacLights IMPORT RecordLight, InputLight;

FROM MacRcord IMPORT StopRecording;

FROM MacrosRc IMPORT FindMacroByHotkey, GetMacroName;


FROM MacSetUp IMPORT MenuKey, StartRecordKey, StopRecordKey, ListKey,
                     MacInsertKey;

FROM MacState IMPORT State, AState, PopState, PushState, StateStack;

FROM MacStack IMPORT MacStack, PopMacro, PushMacro;

FROM MacTalk  IMPORT MacDeath;

FROM MacVars IMPORT Interlock, FormAccepted, Editing,
                    OldGetCode,
                    SpecialCharSet,
                    ExtendedCharSet,
                    RecordingSecondaryMacro,
                    OurRecordingRecord,
                    ARecordingRecordPointer;

FROM Overlays IMPORT CallOverlayWithContext,
                     CallOverlay,
                     OverlayContext,
                     AnOverlayID,
                     ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Space       IMPORT ALLOCATE, DEALLOCATE;

FROM SYSTEM      IMPORT ADR;

FROM TreeObjects IMPORT ATreeNode;



CONST OurMaxCodeIn = 384;
      TopAscii     = 255;
VAR
    dummy      : CARDINAL;
    OverlayID  : AnOverlayID;



(* Used during recording *)

PROCEDURE InsertMacroByName (C : CARDINAL):BOOLEAN;

VAR
    NameCode1,
    NameCode2   : CARDINAL;
    oldcount    : CARDINAL;
    MacroNode   : ATreeNode;
    MacName     : ARRAY [0..40] OF CHAR;        (* 10-May-91 PFG *)
    
BEGIN
  IF MacBuffer <> NIL THEN
    oldcount := MacBuffer^.count;
  ELSE
    oldcount := 0;
  END;
  
  MacroNode := FindMacroByHotkey (C);
  IF MacroNode = NIL THEN MacDeath; END;
  GetMacroName (MacroNode, MacName);
  TrimRear (MacName);
  IF Editing THEN
    NameCode1 := ORD("{");
    NameCode2 := ORD("}");
  ELSE
    NameCode1 := NameCode;
    NameCode2 := NameCode;
  END; 
  IF (PutCodeInBuffer (NameCode1) AND
     PutStrInBuffer (MacName) AND
     PutCodeInBuffer (NameCode2)) THEN
     RETURN TRUE;
  ELSE
    MacBuffer^.count := oldcount;
    RETURN FALSE;
  END;
END InsertMacroByName;




PROCEDURE DoOurRecording (VAR ARecordingRecord : ARecordingRecordPointer);

VAR
    C           : CARDINAL;
    dummy       : CARDINAL;
    S           : ARRAY [0..80] OF CHAR;
    MacName     : ARRAY [0..40] OF CHAR;        (* 10-May-91 PFG *)


   (* added 12/17/88 *)
   
   PROCEDURE OurBreak():BOOLEAN;
   BEGIN
     S := "Program Copyright (c) 1989 Symantec Corporation.";
     IF ARecordingRecord^.break THEN
       ARecordingRecord^.break := FALSE;
       ClearMacStacks;
       ARecordingRecord^.exit := FALSE;
       RETURN TRUE;
     END;
     RETURN FALSE;
   END OurBreak;


BEGIN

                    ARecordingRecord^.exit := FALSE;
                    
                    IF OurBreak() THEN RETURN; END;
                    
                         (* Do not call OldGetCode until
                            we know that there really is a
                            code ready--otherwise it will
                            translate Break into CancelKey. *)
                    REPEAT
                      dummy := 1;
                    UNTIL (Keyboard.KeyPress());

                    IF OurBreak() THEN RETURN; END;

                    C := OldGetCode();

                    ARecordingRecord^.code := C;

                    (* Trap bizarre codes *)
                    IF (
                        ( (C > TopAscii) AND (C <= MaxCode) ) AND

                        ( NOT ( (InCodeSet (SpecialCharSet, C)) OR
                        (InCodeSet (ExtendedCharSet, C) ) ) )
                       ) THEN
                      Burp();
		      ARecordingRecord^.exit := FALSE;
                      RETURN;
                    END;

                    IF ((C = ExitKey) AND RecordingSecondaryMacro) THEN
                          RecordingSecondaryMacro := FALSE;
                          RemoveLight (InputLight);
                          SetString (S, "|MACNEST");
                          IF CallOverlay (S) THEN dummy := 1; END;
                          IF ((StateStack^.next <> NIL) AND 
                              (StateStack^.next^.state = Recording)) THEN
                            PopState;              (* pops playback *)
                            PopMacro;              (* pops macro    *)
                          END;

                    ELSIF C = MenuKey THEN
                      IF NOT RecordingSecondaryMacro THEN
                          INC(Interlock);
                          SetString (S, "|MACMENUD");
                          IF CallOverlayWithContext (S, NIL) THEN (* 8-Mar-90 RSC *)
                          END;
                          DEC(Interlock);
                      ELSE
                          Burp();
                      END;

                    ELSIF (C = StopRecordKey) THEN
                          IF  ((StateStack^.next^.state = Neutral) AND
                               (StateStack^.next^.next = NIL)) THEN
                            StopRecording;
                          ELSE
                            Burp;
                          END;

                    ELSIF C = StartRecordKey THEN
                          Burp;
                      
                    ELSIF C = ListKey THEN
                          INC (Interlock);
                          SetString (S, "|MACPICK");
                          IF ((CallOverlayWithContext (S, ADR(MacName))) AND
                              (FormAccepted)) THEN
                            TrimRear (MacName);
                            IF (PutCodeInBuffer (NameCode) AND
                               PutStrInBuffer (MacName) AND
                               PutCodeInBuffer (NameCode)) THEN
                                 dummy := 1;
                            END;
                          END;
                          DEC (Interlock);
                     
                    ELSIF C = MacInsertKey THEN   (* 5/30/88 *)
                      IF NOT RecordingSecondaryMacro THEN
                          INC (Interlock);
                          SetString (S, "|MACADD");
                          IF CallOverlay (S) THEN dummy := 1; END;
                          DEC (Interlock);
                      ELSE
                          Burp();
                      END;
                      
                    ELSE
                      
                         (* added to allow playback of macro during recording
                             of a parent macro *)

                          IF CodeIsAHotKey(C) THEN
                            IF NOT InsertMacroByName (C) THEN
                              ARecordingRecord^.exit := TRUE;
                              RETURN;
                            END;
                            IF NOT DoMacroByHotkey(C) THEN
                              ARecordingRecord^.exit := TRUE;
                              RETURN;
                            END;
                          ELSIF PutCodeInBuffer (C) THEN
                            dummy := 1;
                          END;
                          ARecordingRecord^.exit := TRUE;
                    END;
                    
END DoOurRecording;




  PROCEDURE DoRecording;

 
  BEGIN
    DoOurRecording (OurRecordingRecord);
  END DoRecording;






BEGIN
  OverlayID := ImAnInstallableOverlay (DoRecording, AnOverlayProc(NIL));
  DoRecording;

END MacRec.
