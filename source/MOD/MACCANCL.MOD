IMPLEMENTATION MODULE MacCancl;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)



FROM Dialog        IMPORT
                           Error;

IMPORT Keyboard;

FROM Lights        IMPORT
                           RemoveLight;

FROM LStrings      IMPORT
                           SetString;

FROM MacLights     IMPORT
                           StepModeLight, PlaybackLight;

FROM MacSetUp      IMPORT
                           StepMode;

FROM MacStack      IMPORT
                           MacStack, PopMacro;

FROM MacState      IMPORT
                           StateStack, AState, State, PopState;

FROM MacVars       IMPORT
                           Interlock, LightsOnRecord;

FROM Menus         IMPORT
                           NoYes;

FROM MsgFile       IMPORT
                           GetMessage;


(*------------------------------------------------------------------------

Clears playback (or not) with various messages.
Input is an LString.

-------------------------------------------------------------------------*)

PROCEDURE CancelProc (S : ARRAY OF CHAR):BOOLEAN;

BEGIN
  IF (CheckForCancel(S)) THEN
    ClearPlayback;
    RETURN TRUE;
  END;
  RETURN FALSE;
END CancelProc;






(*------------------------------------------------------------------------

Returns TRUE iff user confirms cancellation of playback/record.

-------------------------------------------------------------------------*)

PROCEDURE CheckForCancel( VAR What : ARRAY OF CHAR ):BOOLEAN;
VAR
    ok      : BOOLEAN;
    title   : ARRAY [0..10] OF CHAR;

BEGIN
    INC(Interlock);
    GetMessage (26379, title);
    ok := NoYes(What);
    DEC(Interlock);
    RETURN ok;
END CheckForCancel;




PROCEDURE ClearMacStacks;

BEGIN
  WHILE MacStack <> NIL DO
    PopMacro;
  END;
  WHILE (StateStack^.next <> NIL) DO
    PopState;
  END;
END ClearMacStacks;

PROCEDURE ClearPlaybackLights;
BEGIN
  IF StepMode AND LightsOnRecord.StepLight THEN
    RemoveLight (StepModeLight);
    LightsOnRecord.StepLight := FALSE;
   END;
  IF LightsOnRecord.PlayLight THEN
    RemoveLight (PlaybackLight);
    LightsOnRecord.PlayLight := FALSE;
  END;
END ClearPlaybackLights;



(*------------------------------------------------------------------------

Clears playback by popping the associated stacks until they are empty.

-------------------------------------------------------------------------*)

PROCEDURE ClearPlayback;

BEGIN
  ClearMacStacks;
  ClearPlaybackLights;
END ClearPlayback;





END MacCancl.
