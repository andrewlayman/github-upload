IMPLEMENTATION MODULE MacRcord;


(*
MODIFICATION HISTORY
	20-Dec-89 LVK - Replaced macros now retain their node on the tree,
	                only the contents are replaced with ClearMacNode and
	                StoreReplacementMacro.
	04-Jan-90 LVK - StealHotkeyNode used to remove any conflicting hotkey
*)



FROM Lights         IMPORT
                           RemoveLight;

FROM LStrings       IMPORT
                           Fill, SetString;

FROM MacBuffs       IMPORT
                           MacBuffer, PushBuffer, PopBuffer,
                           PutCodeInBuffer;

FROM MacHeader      IMPORT
                           PushMacHeaderStack, PopMacHeaderStack;

FROM MacLights      IMPORT
                           DoOurLight, RecordLight;

FROM MacNodes       IMPORT
                           MacroNode, MacroTree;

FROM MacrosRc       IMPORT
                           CreateMacro, ClearMacNode,
                           SetMacroHotKey, SetMacroHotKeyStr;

FROM MacState       IMPORT
                           PushState, PopState, AState;

FROM MacStore       IMPORT
                           StoreMacro, StoreReplacementMacro;

FROM MacTalk        IMPORT
                           MacDeath;

FROM MacVars        IMPORT
                           DoRecord, MacrosModified,
                           ReplacedMacro, StealHotkeyNode,
                           RecordingSecondaryMacro;

FROM MsgFile        IMPORT
                           GetMessage;

FROM Overlays       IMPORT
                           CallOverlay, CallOverlayWithContext;

FROM Rugs           IMPORT
                           ARug, GetRug, PutRug;

FROM SYSTEM         IMPORT
                           ADDRESS;

(*------------------------------------------------------------------------

Calls up the macro form, and, if the form is accepted, then proceeds to
put up the recording light, set the state to recording, and create a buffer
for the macro.

-------------------------------------------------------------------------*)

PROCEDURE DoRecording():BOOLEAN;

VAR
     rug         : ARug;
     S           : ARRAY [0..127] OF CHAR;
     Context     : ADDRESS;

BEGIN
  Context := NIL;
  IF NOT GetRug (0,0,79,2, rug) THEN RETURN FALSE; END;
  SetString (S, "|MACFORM1");
  PushMacHeaderStack;
  IF CallOverlayWithContext (S, Context) THEN
    PutRug (0,0,79,2, rug);
    IF DoRecord THEN
      GetMessage (26491, S);
      DoOurLight (RecordLight, S);
      PushState (Recording);
      IF NOT PushBuffer() THEN PopState; RETURN FALSE; END;
      MacBuffer^.count := 0;
      MacrosModified := TRUE;
    END;
  ELSE
    PutRug (0,0,79,2, rug);
    RETURN FALSE;
  END;
  RETURN TRUE;
END DoRecording;

(*------------------------------------------------------------------------

Removes the record light, saves the macro, and pops the buffer off the stack.

-------------------------------------------------------------------------*)

PROCEDURE StopRecording;

VAR i, C, dummy : CARDINAL;
    S           : ARRAY [0..10] OF CHAR;

BEGIN
  PopState;
  (*HALT;*)
  IF NOT RecordingSecondaryMacro THEN
    RemoveLight (RecordLight);
  ELSE
    RecordingSecondaryMacro := FALSE;
  END;
  
  FOR i := 0 TO 1 DO            (* Put sentinals at end; *)
    C := 65432;
    IF PutCodeInBuffer(C) THEN dummy := 1; END;
  END;
  
  IF StealHotkeyNode <> NIL THEN
    SetMacroHotKey(StealHotkeyNode, 0);
    Fill(S, ' ', 10);
    SetMacroHotKeyStr(StealHotkeyNode,S);
    StealHotkeyNode := NIL;
  END;
  
  IF ReplacedMacro = NIL THEN
    IF NOT CreateMacro (MacroNode) THEN
      MacDeath;
    END;
    IF NOT StoreMacro (MacBuffer^.buffer, MacBuffer^.count,
                       MacroNode, NIL, MacroTree) THEN
      MacDeath;
    END;
  ELSE
    IF NOT ClearMacNode(ReplacedMacro) THEN
      MacDeath;
    END;
    IF NOT StoreReplacementMacro(MacBuffer^.buffer, MacBuffer^.count,
                                 ReplacedMacro) THEN
      MacDeath;
    END;
    ReplacedMacro := NIL;
  END;
  PopBuffer;
  PopMacHeaderStack;
  
END StopRecording;


END MacRcord.
