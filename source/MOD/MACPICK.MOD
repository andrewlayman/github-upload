MODULE MacPick;

    (*  MODIFICATION HISTORY
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
       30-May-91  RSC   Removed "Nothing" shutdown proc.
    *)


FROM MacList         IMPORT DoMacroList;

FROM Overlays        IMPORT OverlayContext, ImAnInstallableOverlay,
                            AnOverlayID;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;


TYPE AName = ARRAY [0..40] OF CHAR;

TYPE AMacroPointer = POINTER TO AName;


VAR
     OverlayID : AnOverlayID;
     
PROCEDURE DoTheList;

VAR OurMacro    : AMacroPointer;
    dummy       : CARDINAL;
    Copyright   : ARRAY[0..50] OF CHAR;

BEGIN
  Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

  OurMacro := OverlayContext();
  IF DoMacroList (OurMacro^) THEN dummy := 1; END;

END DoTheList;



BEGIN
  OverlayID := ImAnInstallableOverlay (DoTheList, AnOverlayProc(NIL));
  DoTheList;
END MacPick.
