MODULE MacMenuDo;

    (*  MODIFICATION HISTORY
        26-Jun-89 LAA   Imported Space to resolve another of those annoying
                        version conflicts.
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
       16-Nov-89  LVK - Changed from Dynamic to Resident overlay due to
                        potential problem with recursive calls in the
                        editor.
       29-Nov-89  RSC - Put up error boxes when choices not allowed due
                        to recording or editing.  Bug # 1636.
       12-Dec-89  RSC - Added MODAL parameter to the menus call.
        7-Mar-90  RSC - Removed call to OverlayContext.  Import new
                        global variable "MenuOn" and use that rather
                        than pointers to MenuOn.
        1-Jun-90  MWP - Burp if user selects 'OnMenu' during Playback.
       12-Apr-91  RSC - Change params to MenuWithPrompts.
       30-May-91  RSC - Make the termination proc NIL rather than a procedure
                        called "Nothing".
    *)


FROM Boxes           IMPORT
                            ABoxType, ABoxAttribute;

FROM Codes           IMPORT
                            ACode;

FROM CodeSets        IMPORT
                            MenuCodeSet;

FROM Dialog          IMPORT
                            Burp, Error;

FROM FlexStor        IMPORT
                            LockObjectArray, ReleaseObject;

FROM Kbio            IMPORT
                            EraseLn;


FROM Layout          IMPORT MenuStart, MenuEnd;

FROM LStrings        IMPORT
                            Procustes, SetString, ConcatLS, Fill,
                            ConcatS;

FROM Keys            IMPORT
                            CancelKey, OnMenu;

FROM Menus           IMPORT
    (* TYPE *)              APromptType,
                            MenuWithPrompts, NoYes;

FROM MacBuffs        IMPORT
                            PushBuffer, PutCodeInBuffer, PlayBuffer;

FROM MacCodes        IMPORT
                            GetCodeString;

FROM MacList         IMPORT
                            DoMacroList;

FROM MacNodes        IMPORT
                            MacroTree;

FROM MacRcord        IMPORT
                            StopRecording, DoRecording;

FROM MacrosRc        IMPORT
                            DisposeMacros;

FROM MacSetUp        IMPORT
                            StartRecordKey, StopRecordKey,
                            ListKey, MacInsertKey;

FROM MacState        IMPORT
                            State, AState, StateStack, PushState;

FROM MacVars         IMPORT
                            XKey, NormKey, KeyOffset,
                            Editing, MacrosModified, Interlock,
                            FormAccepted, MacroFileName,
                            
                            (* RSC 8-Mar-90 *) MenuOn;

FROM MsgFile         IMPORT
                            GetMessage;

FROM Overlays        IMPORT
                            CallOverlay, AnOverlayID,
                            ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Rugs            IMPORT
                            ARug, GetRug, PutRug;

FROM Space           IMPORT
    (* PROC *)              Available;

FROM Text           IMPORT
    (* TYPE *)          AText,
    (* PROC *)          CreateText, DiscardText, AppendLine;




VAR
     OverlayID : AnOverlayID;



PROCEDURE AppendKeyStr (C       : CARDINAL;
                        VAR Str : ARRAY OF CHAR);

VAR ourhotkeystr : ARRAY [0..10] OF CHAR;

BEGIN
  Procustes (Str, 61);
  GetCodeString (C, ourhotkeystr);
  ConcatLS (Str, ourhotkeystr);
END AppendKeyStr;





(*------------------------------------------------------------------------

Used with MacroMenu.

-------------------------------------------------------------------------*)

PROCEDURE GetPromptText( VAR Text : AText );
VAR
    prompt  : ARRAY [0..255] OF CHAR;
    ok      : BOOLEAN;
BEGIN
    Text := CreateText();
    IF (Text <> AText(NIL)) THEN
        GetMessage (26428, prompt);
        ok := AppendLine( prompt, Text );
        GetMessage (26429, prompt);
        ok := AppendLine( prompt, Text );
        GetMessage (26430, prompt);
        AppendKeyStr (StartRecordKey, prompt);
        ok := AppendLine( prompt, Text );
        GetMessage (26431, prompt);
        AppendKeyStr (StopRecordKey, prompt);
        ok := AppendLine( prompt, Text );
        GetMessage (26432, prompt);
        AppendKeyStr (ListKey, prompt);
        ok := AppendLine( prompt, Text );
        GetMessage (26433, prompt);
        AppendKeyStr (MacInsertKey, prompt);
        ok := AppendLine( prompt, Text );
        GetMessage (26434, prompt);
        ok := AppendLine( prompt, Text );
        GetMessage (26435, prompt);
        ok := AppendLine( prompt, Text );
        GetMessage (26436, prompt);
        ok := AppendLine( prompt, Text );
    END;

END GetPromptText;










(*------------------------------------------------------------------------

The menu that does it all.

-------------------------------------------------------------------------*)

PROCEDURE DoMacroMenu;

TYPE
     Subset          = [0..9];
     ChoiceSet       = SET OF Subset;

VAR 
     rug             : ARug;
     PromptText      : AText;
     i,
     Length,
     dummy,
     select          : CARDINAL;
     choice          : ACode;
     ok              : BOOLEAN;
     title           : ARRAY [0..20] OF CHAR;
     prefix          : ARRAY [0..15] OF CHAR;
     menu            : ARRAY [0..79] OF CHAR;
     ValidEditSet,
     ValidRecordSet  : ChoiceSet;
     S               : ARRAY [0..127] OF CHAR;


    PROCEDURE DoAnError( Which : CARDINAL );
    VAR
       s   : ARRAY [0..255] OF CHAR;
    BEGIN
         GetMessage( Which, s );
         INC(Interlock);
         Error(s);
         DEC(Interlock);
    END DoAnError;


    PROCEDURE DoOverlay( Name : ARRAY OF CHAR ) : BOOLEAN;
    VAR
       s   : ARRAY [0..39] OF CHAR;
    BEGIN
        SetString( s, Name );
        RETURN CallOverlay( s );
    END DoOverlay;

BEGIN

  S := "Program Copyright (c) 1989 Symantec Corporation.";
  ValidEditSet := ChoiceSet {5,6,9};
  ValidRecordSet := ChoiceSet {4,5,6,9};
  select := 1;
  MenuOn := TRUE;
  IF NOT GetRug (0,MenuStart,79,MenuEnd,rug) THEN RETURN; END;
  FOR i := 0 TO 2 DO
    EraseLn (i);
  END;
  GetMessage (26437, prefix);
  GetMessage (26438, menu);
  GetPromptText( PromptText );  (* 15-Apr-91 RSC  *)
  LOOP
    choice :=
              MenuWithPrompts (prefix,menu,1,MenuStart,76,MenuEnd,
                               ABoxType{DoubleBox,ShadowBox},MenuCodeSet,
                               PromptFromText,0,PromptText, (* 15-Apr-91 RSC  *)
                               TRUE,    (* 12-Dec-89 RSC MODAL *)
                               select);
    IF ((choice = CancelKey) OR (choice = OnMenu)) THEN EXIT; END;
    IF ((Editing) AND NOT (select IN ValidEditSet)) THEN DoAnError(26442); (* 29-Nov-89 RSC "Not valid while editing" *)
    ELSIF ((State = Recording) AND NOT (select IN ValidRecordSet)) THEN DoAnError(26443);  (* 29-Nov-89 RSC "Not valid while recording" *)
    ELSE  (* not Editing or Recording *)
    
       CASE select OF
        1 :
            (* Load *)

            IF DoOverlay( "MACLOAD" ) THEN EXIT; END;
        |
        2 :
            (* Save *)
            IF MacroTree^.Methods^.GetFirst(MacroTree) <> NIL THEN
              IF (DoOverlay("MACSAVE") AND FormAccepted) THEN
                MacrosModified := FALSE;
              END;
              EXIT;
            ELSE
              GetMessage (26439, S);
              Error (S);
            END|
        3 :
            (* Record *)
            IF StateStack^.state = Neutral THEN
              IF NOT DoRecording() THEN
                GetMessage (26440, S);
                Error (S);
              END;
              EXIT;
            ELSIF StateStack^.state = Recording THEN
              PushState (Neutral);
              IF DoOverlay("MACFORM2") THEN EXIT; END; (* 30-May-91 RSC *)
            END|
        4 : 
            (* Halt *)
            IF State = Recording THEN  (* StateStack^.state ?? *)
              StopRecording;
              EXIT;
            ELSE
              DoAnError(26423); (* 29-Nov-89 RSC "Only valid while recording." *)
            END|
        5 :
            (* Macros *)
            IF DoMacroList (S) THEN EXIT END|
        6 : 
            (* Insert *)
            IF ((State = Recording) OR (Editing)) THEN
              INC (Interlock);
              ok := DoOverlay("MACADD");
              DEC (Interlock);
              EXIT;
            ELSE
              DoAnError(26427);  (* 29-Nov-89 RSC "valid only while recording or editing" *)
            END|
        7 :
            (* Erase *)
            IF ((State <> Recording) AND
               (MacroTree^.Methods^.GetFirst(MacroTree) <> NIL)) THEN
              GetMessage(26441, S);
              IF NoYes (S) THEN
                DisposeMacros (MacroTree);
                Fill (MacroFileName, " ", 8); 
                MacrosModified := FALSE;
              END;
              EXIT;
            ELSIF (State = Recording) THEN
              DoAnError(26443);  (* 29-Nov-89 RSC "Not valid while recording" *)
            ELSE
              Burp;
            END|
        8 :
            (* Configure *)
            INC (Interlock);
            ok := DoOverlay("MACINST");    (* 30-May-91 RSC  *)
            DEC (Interlock);
            EXIT|
        9 :
            (* Quit *)
            EXIT;
      ELSE ;
      END;                    (* case *)

    END;                      (* if   *)

  END;                        (* loop *)
  PutRug (0,0,79,2, rug);
  DiscardText( PromptText );    (* 15-Apr-91 RSC  *)
  MenuOn := FALSE;
  IF choice = OnMenu THEN      (* ??? why does it crash ??? 2/10/88 *)
    IF ( State <> Playback ) THEN                                   (* 1-Jun-90 MWP *)
       IF NOT PushBuffer() THEN
            RETURN;
       END;
                                 (* gives message of "End Embedded Macro" *)
       IF PutCodeInBuffer (OnMenu) THEN 
           dummy := 1;
       END;
       PlayBuffer;
    ELSE
       Burp ();
    END;
  END;

END DoMacroMenu;



BEGIN
  
  OverlayID := ImAnInstallableOverlay (DoMacroMenu, AnOverlayProc(NIL));
  DoMacroMenu;

END MacMenuDo.

