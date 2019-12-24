IMPLEMENTATION MODULE MacVars;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software

    20-Mar-90 RSC  Removed unused globals.

---------------------------------------------------------------------------*)


FROM Codes      IMPORT EmptyCodeSet;

FROM FlexStor   IMPORT AnExtStoragePreference;

FROM LStrings   IMPORT Fill, SetString, TrimRear;

BEGIN

  SetString (LastMacroSaved, " ");
  TrimRear (LastMacroSaved);
  SetString (MacroFileName, " ");
  TrimRear (MacroFileName);
  SetString (MacroFileMedia, " ");
  TrimRear (MacroFileMedia);
  SetString (LinkedMacro, " ");
  TrimRear (LinkedMacro);

  Editing              := FALSE;
  SaveEdits            := FALSE;
  Load                 := ClearOldMacros;
  MacStoragePreference := ExtSlow;
  DoRecord             := FALSE;
  ReplacedKeySet       := EmptyCodeSet;
  EditNavSet           := EmptyCodeSet;
  FormAccepted         := FALSE;
  PlaybackOK           := TRUE;
  MacrosModified       := FALSE;
  ListHotkeyOn         := TRUE;
  EditMacroChange      := FALSE;
  EditCancel           := FALSE;
  Interlock            := 0;
  
  WITH LightsOnRecord DO
    PlayLight   := FALSE;
    StepLight   := FALSE;
    RecordLight := FALSE;
    InputLight  := FALSE;
    PauseLight  := FALSE;
  END;
  
  ReplacedMacro := NIL;
  StealHotkeyNode := NIL;
  
END MacVars.
