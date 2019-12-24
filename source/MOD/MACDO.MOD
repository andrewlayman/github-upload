IMPLEMENTATION MODULE MacDo;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)


FROM LStrings    IMPORT TrimRear, SetString, ConcatS, ConcatLS;

FROM MacBuffs    IMPORT PushBuffer, PutStrInBuffer, PlayBuffer;

FROM MacNodes    IMPORT MacroNode;

FROM MacrosRc    IMPORT FindMacroByName, FindMacroByHotkey;

FROM MacSetUp    IMPORT StepMode;

FROM MacStack    IMPORT PushMacro;

FROM MacState    IMPORT AState, PushState, StateStack;

FROM MacVars     IMPORT LightsOnRecord;

FROM MacLights   IMPORT DoOurLight, StepModeLight, PlaybackLight;

FROM MsgFile     IMPORT GetMessage;



PROCEDURE DoMacro;

VAR S : ARRAY [0..80] OF CHAR;

BEGIN
  PushMacro (MacroNode);
  IF StateStack^.state <> Playback THEN
    PushState (Playback);
  END;
  IF NOT LightsOnRecord.PlayLight THEN
    GetMessage (26372, S);
    DoOurLight (PlaybackLight, S);
    LightsOnRecord.PlayLight := TRUE;
  END;
  IF StepMode AND NOT LightsOnRecord.StepLight THEN
    GetMessage (26490, S);
    DoOurLight (StepModeLight, S);
    LightsOnRecord.StepLight := TRUE;
   END;
END DoMacro;




(*------------------------------------------------------------------------

If a hotkey was entered during a session, this attempts to locate a macro
in memory that has that hotkey.  If one is found, the macro is played back.

-------------------------------------------------------------------------*)


PROCEDURE DoMacroByHotkey(VAR Hotkey : CARDINAL):BOOLEAN;

BEGIN
  MacroNode := FindMacroByHotkey (Hotkey);
  IF MacroNode = NIL THEN RETURN FALSE END;
  DoMacro;
  RETURN TRUE;
END DoMacroByHotkey;



PROCEDURE DoMacroByName (VAR MacName : ARRAY OF CHAR);

BEGIN
  MacroNode := FindMacroByName (MacName);
  IF MacroNode <> NIL THEN
    DoMacro;
  END;
END DoMacroByName;




  (*------------------------------------------------------------------------

  Puts the name of the selected macro into the edited macro at the point
  of the cursor.

  -------------------------------------------------------------------------*)

PROCEDURE DoName (MacName : ARRAY OF CHAR);

VAR S : ARRAY [0..42] OF CHAR;

BEGIN
   TrimRear (MacName);
   SetString (S, "{");
   ConcatLS (S, MacName);
   ConcatS (S, "}");
   IF NOT PushBuffer() THEN RETURN; END;
   IF PutStrInBuffer (S) THEN END;
   PlayBuffer;
END DoName;



END MacDo.
