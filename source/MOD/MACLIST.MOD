IMPLEMENTATION MODULE MacList;

(*
    MODIFICATION HISTORY:

    RSC 30-Nov-89  Centered box more and made box wider.
*)


FROM Dialog      IMPORT
                        Message;

FROM Kbio        IMPORT
                        EraseLn, maxrow;

FROM LStrings    IMPORT
                        SetString, Fill, ConcatS, Copy;

FROM MacDo       IMPORT
                        DoName, DoMacroByName;

FROM MacroSelect IMPORT
                        SelectMacroName;

FROM MacState    IMPORT
                        AState, State;

FROM MacVars     IMPORT
                        Editing, FormAccepted;

FROM MsgFile     IMPORT
                        GetMessage;

FROM Rugs        IMPORT
                        ARug, GetRug, PutRug;



PROCEDURE DoMacroList (VAR Name : ARRAY OF CHAR):BOOLEAN;

CONST
      Start = 0;
      End   = 2;

VAR S       : ARRAY [0..255] OF CHAR;
    MacName : ARRAY [0..40] OF CHAR;
    title   : ARRAY [0..30] OF CHAR;
    rug     : ARug;
    i       : CARDINAL;

BEGIN
  FormAccepted := FALSE;
  IF NOT GetRug (0,Start,79,End,rug) THEN RETURN FALSE; END;
  FOR i := 0 TO 2 DO
    EraseLn (i);
  END;
  IF Editing THEN
    GetMessage (26402, S);
  ELSIF State = Recording THEN
    GetMessage (26403, S);
  ELSE 
    GetMessage (26400, S);
  END;
  Message (S);
  Fill (MacName, " ", 0);
  GetMessage (26401, title);
  IF SelectMacroName (15, 5, 62, maxrow - 6, title, MacName) THEN   (* 30-Nov-89 RSC centered more, made wider. *)
    Copy (MacName, Name);
    IF NOT Editing THEN
      DoMacroByName (MacName);
    ELSE
      DoName (MacName);
    END;
    PutRug (0,Start,79,End, rug);
    FormAccepted := TRUE;
    RETURN TRUE;
  END;
  PutRug (0,Start,79,End, rug);
  FormAccepted := FALSE;
  RETURN FALSE;
END DoMacroList;






END MacList.
