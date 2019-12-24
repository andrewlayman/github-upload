MODULE MacEd;


(*----------------------------------------------------------------------

A resident overlay. (around 12/25/88)

Need to: Import MacText; check MacText size periodically, and on ExitKey.

         Check InsertMacroByName... in another module. (12/6/88).

------------------------------------------------------------------------*)

    (*  MODIFICATION HISTORY
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynch code btwn Cybersoft & Symantec.
       11-Nov-89  LVK - Disabled Insert Menu when rcording Secondary Macro.
       19-Dec-89  RSC - Load MACMENUD into the reserved layer.
       17-Jan-90  RSC - Load MacPick in the reserved layer.
        7-Mar-90  RSC - Changed use of "MenuOn", so that there is only one
                        copy of the boolean, not several pointers to several
                        copies of it.

       30-May-91  RSC   Removed globals, removed "Nothing" shutdown proc.

    *)

FROM Dialog   IMPORT Error, Burp;

FROM Keys     IMPORT ExitKey, CancelKey, BackSpace, EditKey;

FROM LStrings IMPORT Copy, SetString, TrimRear, ConcatS, ConcatLS;

FROM MacBuffs IMPORT PushBuffer, PlayBuffer, PutStrInBuffer,
                     MacBuffer, PutCodeInBuffer, PopBuffer;

FROM MacCancl  IMPORT ClearPlayback;

FROM MacCodes IMPORT InCodeSet, CodeIsAHotKey, GetCodeString, NameCode;

FROM MacrosRc IMPORT FindMacroByHotkey, GetMacroName;

FROM MacSetUp IMPORT MenuKey, ListKey, MacInsertKey;

FROM MacTalk  IMPORT MacDeath, MacError;

FROM MacVars  IMPORT EditCancel,
                     EditMacroChange,
                     OurEditRecord,
                     SaveEdits,
                     Interlock,
                     Editing,
                     MacrosModified,
                     EditNavSet,
                     EditCodeSet,
                     InAForm,
                     SpecialCharSet,
                     RecordingSecondaryMacro,
                     FormAccepted;

FROM MsgFile        IMPORT
                           GetMessage;
                    
FROM Notices        IMPORT
                           AnOccasion, AStep, RegisterForNotices,
                           UnRegisterForNotices;


FROM Overlays IMPORT CallOverlayWithContext,
                     CallOverlay,
                     OverlayContext,
                     ImAnInstallableOverlay,
                     AnOverlayID;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM SYSTEM   IMPORT ADDRESS, ADR;

FROM Text     IMPORT
                     AText;

FROM TreeObjects IMPORT ATreeNode;

(* ---------------------------------------------------------------------- *)

CONST
      F7key    = 321;
      F8key    = 322;

VAR
    OverlayID  : AnOverlayID;





(* Used during recording and editing *)

PROCEDURE InsertMacroByName (C : CARDINAL):BOOLEAN;

VAR
    NameCode1,
    NameCode2   : CARDINAL;
    MacroNode   : ATreeNode;
    oldcount    : CARDINAL;
    MacName     : ARRAY [0..40] OF CHAR;
    
BEGIN
  oldcount := MacBuffer^.count;
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






(*------------------------------------------------------------------------

Used during macro editing sessions.  Inserts string equivalents of extended
characters into the edited macro.  Also handles the Proceed/Cancel
message that EditText puts up when the user enters [Esc] so that the
macro will be saved or discarded as necessary.


Change: 4/28/88  Added InsertKey processing to get around problems in editor.


------------------------------------------------------------------------*)

PROCEDURE DoEdits ();


VAR
    str              : ARRAY [0..255] OF CHAR;
    S                : ARRAY [0..80] OF CHAR;
    dummy            : CARDINAL;
    InDirList        : BOOLEAN;



PROCEDURE CheckCancelBox():BOOLEAN;
BEGIN
  IF (EditCancel AND EditMacroChange) THEN
                                       (* but a MacEdit error msg returns *)
    EditCancel := FALSE;               (* user to text, esc not ok after. *)
    CASE OurEditRecord^.code OF
      333,331,32 :
                   INC (OurEditRecord^.cancel);                  (* arrow or space *)
                   EditCancel := TRUE;
    | 80,112     :
                   OurEditRecord^.cancel := 1;                   (* P,p *)
                   EditCancel := TRUE;
    | 67, 99     :
                   OurEditRecord^.cancel := 1;                   (* C,c *)
    | 13,324     :
                   IF ODD(OurEditRecord^.cancel) THEN            (* enter or F10 *)
                     OurEditRecord^.cancel := 1;
                   END;
    ELSE ;
    END;
  END;
  RETURN (EditCancel AND EditMacroChange);
END CheckCancelBox; 



PROCEDURE InformOfFailure; (* I hope it's never called *)
BEGIN
  GetMessage (26388, S);
  INC (Interlock);
  Error (S);
  DEC (Interlock);
  S := "Program Copyright (c) 1989 Symantec Corporation.";
END InformOfFailure;






BEGIN  (* DoEdits *)
  InDirList := FALSE;


  IF NOT (InCodeSet (EditNavSet, OurEditRecord^.code)) THEN
    EditMacroChange := TRUE;
  END;

  SaveEdits := FALSE;     (*  <---------- Added because F10 sets to true, *)

  IF CheckCancelBox() THEN dummy := 1;

  ELSE
    IF OurEditRecord^.code = EditKey THEN
      IF InAForm THEN
        OurEditRecord^.exit := TRUE;
        InDirList := TRUE;
        RETURN;
      END;
    ELSIF (OurEditRecord^.code = F7key) OR
          (OurEditRecord^.code = F8key) THEN
      InAForm := TRUE;
    ELSIF (((OurEditRecord^.code = ExitKey)    OR
            (OurEditRecord^.code = CancelKey)) AND
           InAForm) THEN
      IF InDirList THEN
        InDirList := FALSE;
      ELSE
        InAForm := FALSE;
      END;
    END;
    
    CASE OurEditRecord^.code OF
      ExitKey    : (* F10 *)
                       MacrosModified := TRUE;
                       SaveEdits := TRUE;
    | CancelKey    :
                     EditCancel := TRUE;
    | BackSpace    :
                     OurEditRecord^.exit := TRUE;
                     RETURN;
    ELSE
      IF OurEditRecord^.code = 32 THEN OurEditRecord^.code := 249;

      ELSIF OurEditRecord^.code = 13 THEN dummy := 1;

      ELSIF OurEditRecord^.code = MenuKey THEN
        SetString (S, "|MACMENUD");

        (* 7-Mar-90 RSC Removed MenuOn parameter *)

        IF CallOverlayWithContext (S, NIL) THEN
          OurEditRecord^.exit := FALSE;
          RETURN;
        END;

      ELSIF OurEditRecord^.code = ListKey THEN
        SetString (S, "|MACPICK");  (* 17-Jan-90 RSC  *)
        IF CallOverlayWithContext (S, OurEditRecord^.macNamePtr) THEN
          OurEditRecord^.exit := FALSE;
          RETURN;
        ELSE
          GetMessage (26389, S);
          Error (S);
        END;

      ELSIF OurEditRecord^.code = MacInsertKey THEN
        IF NOT RecordingSecondaryMacro THEN
          SetString (S, "|MACADD");
          IF CallOverlay (S) THEN
            dummy := 1;
          END;
          OurEditRecord^.exit := FALSE; RETURN;
        ELSE
          Burp();
        END;

      ELSIF CodeIsAHotKey (OurEditRecord^.code) THEN
        IF NOT PushBuffer() THEN
          InformOfFailure;
          ClearPlayback;
          OurEditRecord^.exit := TRUE;
          RETURN;
        END;
        IF NOT InsertMacroByName (OurEditRecord^.code) THEN
          InformOfFailure;
          PopBuffer;
          ClearPlayback;
          OurEditRecord^.exit := TRUE;
          RETURN;
        END;
        OurEditRecord^.exit := FALSE;
        PlayBuffer;
        RETURN;


      ELSIF (InCodeSet (EditCodeSet, OurEditRecord^.code)   OR
             InCodeSet (SpecialCharSet, OurEditRecord^.code)) THEN
        GetCodeString (OurEditRecord^.code, str);
        IF NOT PushBuffer() THEN
          InformOfFailure;
          OurEditRecord^.exit := TRUE;
          ClearPlayback;
          RETURN;
        END;
        IF NOT PutStrInBuffer (str) THEN
          InformOfFailure;
          ClearPlayback;
        END;
        PlayBuffer;
        OurEditRecord^.exit := FALSE;
        RETURN;
      END;
    END;
  END;
  OurEditRecord^.exit := TRUE;

END DoEdits;






BEGIN
  OverlayID := ImAnInstallableOverlay (DoEdits, AnOverlayProc(NIL));
  DoEdits();
END MacEd.
