
MODULE MacPlay;

    (*  MODIFICATION HISTORY
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
       30-Nov-89  MWP - Changed call to DoOurLight for Input Pause to
                        DoMacLight, which allows us to specify the video
                        attribute.
       30-May-91  RSC   Removed globals, removed "Nothing" shutdown proc.
    *)

  IMPORT
                            Keyboard;

  FROM Clock IMPORT
                            Delay, NoEarlyExit;

  FROM Dialog IMPORT
                            ContinuationBox, ADialogOption, Error;

  FROM Kbio IMPORT
                            avidmode,                             (* 30-Nov-89 MWP *)
                            Tone, soundon;

  FROM LStrings IMPORT
                            SetString, ConcatS;

  FROM MacCancl IMPORT
                            CancelProc, ClearPlayback;

  FROM Lights IMPORT
                            RemoveLight;

  FROM MacBuffs IMPORT
                            MacBuffPlay;

  FROM MacCodes IMPORT
                            InCodeSet, GetCodeString, CodeIsAHotKey, BeginCode,
                            EndCode, NameCode, MenuCode, MessageCode, PauseCode
                            , ChainCode;

  FROM MacLights IMPORT
                            DoOurLight, InputLight, PlaybackLight, DisplayMacLight,
                            StepModeLight, RecordLight, PauseLight;

  FROM MacNodes IMPORT
                            MacroTree;

  FROM MacrosRc IMPORT
                            FindMacroByName, FindMacroByHotkey, DisposeMacros,
                            GetMacroLength;

  FROM MacSetUp IMPORT
                            PlayBackSpeed, APlayBackSpeed, StepMode;

  FROM MacStack IMPORT
                            AMacStackPtr, MacStack, PushMacro, PopMacro,
                            GetACardinal, GetName;

  FROM MacState IMPORT
                            StateStack, AState, PushState, PopState;

  FROM MacStrings IMPORT
                            ReadMacString, DoMessage;

  FROM MacVars IMPORT
                            Editing, FormAccepted, MacrosModified,
                            Interlock, OurCodeRecord, ACodeRecordPointer,
                            OldGetCode, LightsOnRecord;

  FROM Menus    IMPORT
                            NoYes;

  FROM MsgFile  IMPORT
                            GetMessage;

  FROM Overlays IMPORT
                            OverlayContext, AnOverlayID, CallOverlay,
                            CallOverlayWithContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

  FROM SYSTEM IMPORT
                            ADR;

  FROM TreeObjects IMPORT
                            ATreeNode;



  VAR
    MacroNode  : ATreeNode;
    OverlayID  : AnOverlayID;
    dummy      : CARDINAL;
    C          : CARDINAL;
    MacName    : ARRAY [0 .. 40] OF CHAR;
    result     : BOOLEAN;


  PROCEDURE AskSave;

  VAR
    title : ARRAY [0 .. 80] OF CHAR;
    S     : ARRAY [0 .. 255] OF CHAR;

  BEGIN
    IF MacroTree^.Methods^.GetFirst (MacroTree) = NIL THEN
      MacrosModified := FALSE;
      RETURN;
    END (* if MacroTree *);
    INC (Interlock);
    GetMessage (26444, title);
    GetMessage (26445, S);
    IF ContinuationBox (S, title, NoHelp) THEN
      SetString (S, "|MACSAVE");
      IF CallOverlay (S) THEN
        dummy := 1;
      END (* if CallOverlay *);
    END (* if ContinuationBox *);
    DEC (Interlock);
    MacrosModified := FALSE;
  END AskSave;

  (* ------------------------------------------------------------------------
     Macro playback procedure. 
  -------------------------------------------------------------------------*)


  PROCEDURE PlayBack (VAR ACodeRecord : ACodeRecordPointer);

  VAR
    delay : CARDINAL;
    len   : CARDINAL;
    str   : ARRAY [0 .. 80] OF CHAR;
    S     : ARRAY [0 .. 255] OF CHAR;


    PROCEDURE OurSound;

    VAR
      i : CARDINAL;

    BEGIN
      IF NOT soundon THEN RETURN; END;
      FOR i := 10 TO 1 BY -1 DO
        Tone (50 * i, 5);
      END (* for i *);
    END OurSound;

    (* Maybe read delay numbers from a config file? *)


    PROCEDURE SetPlaybackSpeed;

    BEGIN
      CASE PlayBackSpeed OF
        Fast :
                     delay := 0; |
        MedFast :
                     delay := 10; |
        Medium :
                     delay := 35; |
        MedSlow :
                     delay := 70; |
        Slow :
                     delay := 100;
      ELSE
        ;
      END (* case PlayBackSpeed *);
      Delay (delay, NoEarlyExit);
    END SetPlaybackSpeed;


    PROCEDURE GetTheMacro():BOOLEAN;

    BEGIN
      IF CARDINAL (C) = NameCode THEN
        GetName (CARDINAL (C), MacName);
        MacroNode := FindMacroByName (MacName);
      ELSE
        MacroNode := FindMacroByHotkey (C);
      END (* if CARDINAL *);
      IF MacroNode <> NIL THEN
        PushMacro (MacroNode);
        IF NOT LightsOnRecord.PlayLight THEN
          GetMessage (26372, S);
          DoOurLight (PlaybackLight, S);
          LightsOnRecord.PlayLight := TRUE;
        END (* if *);
        RETURN FALSE; (*??*)
      ELSE
        GetMessage (26447, S);
        RETURN NOT CancelProc (S);
      END (* if MacroNode *);
    END GetTheMacro;


    PROCEDURE EndThisPlayback;

    BEGIN
      PopMacro;
      IF ( ( MacStack = NIL ) AND LightsOnRecord.PlayLight ) THEN
        RemoveLight (PlaybackLight);
        LightsOnRecord.PlayLight := FALSE;
      END;

      (* for recording/playback combinations... need to change state popping *)
      IF ( ( MacStack = NIL ) OR ( ( StateStack^.prev <> NIL ) AND
         ( StateStack^.prev^.state = Recording ) ) ) THEN
        PopState;
        IF (StepMode AND
            (NOT Editing) AND
            (MacBuffPlay = 0) AND
            LightsOnRecord.StepLight) THEN
          RemoveLight (StepModeLight);
          LightsOnRecord.StepLight := FALSE;
        END;
      (* if playing a macro inside a pause or input-pause *)
      ELSIF (ACodeRecord^.Pause OR ACodeRecord^.InputPause) THEN
        PopState;
      END;

      IF MacBuffPlay > 0 THEN DEC (MacBuffPlay); END;

    END EndThisPlayback;


             (* Playback *)
  BEGIN
    S := "Program Copyright (c) 1989 Symantec Corporation.";
    ACodeRecord^.code := 0;
    IF MacStack = NIL THEN
      ACodeRecord^.exit := FALSE;
      RETURN;
    END (* if MacStack *);

    IF NOT Editing THEN
      IF (StepMode AND (MacBuffPlay = 0)) THEN
        LOOP
          IF Keyboard.KeyPress () THEN
            EXIT;
          END (* if Keyboard.KeyPress *);
        END (* loop *);
        C := OldGetCode ();
      END;
      SetPlaybackSpeed;
    END (* if *);

    IF MacStack = NIL THEN
      ACodeRecord^.exit := FALSE;
      RETURN;
    END;   (* Virtual memory & ctrl-brk *)

    len := GetMacroLength (MacStack^.macro);

    IF ( MacStack^.pos <> len ) THEN
      GetACardinal (C);
      ACodeRecord^.code := C;

      IF C = 65432 THEN
        EndThisPlayback;
        ACodeRecord^.exit := FALSE;
        RETURN;
      END (* if C *);

      IF C = BeginCode THEN   (* second degree macro or input pause *)
        GetMessage (26446, S);
(*
        DoOurLight (InputLight, S);
*)
        DisplayMacLight (InputLight, S, videowarning );                (* 30-Nov-89 MWP *)

        OurSound;

        SetString (S, "|MACVARF");
        IF NOT CallOverlay (S) THEN
          GetMessage (26448, S);
          Error (S);
          RemoveLight (InputLight);
        END (* if *);
        ACodeRecord^.exit := FALSE;
        RETURN;
      END (* if C *);

      CASE C OF
        MessageCode :
                     ACodeRecord^.exit := FALSE;
                     DoMessage;
                     ACodeRecord^.exit := FALSE; (* changed 4/26/89: bug *)
                     RETURN; |
        PauseCode :
                     ACodeRecord^.Pause := TRUE;
                     PushState (Neutral);
                     GetMessage (26449, S);
                     DoOurLight (PauseLight, S);
                     OurSound;
                     ACodeRecord^.exit := FALSE;
                     RETURN; |
        MenuCode :
                     SetString (S, "|MACMENU");
                     IF CallOverlay (S) THEN
                       dummy := 1;
                     END (* if CallOverlay *);
                     IF FormAccepted THEN
                       ACodeRecord^.exit := FALSE; (* changed 4/26/89: bug *)
                       RETURN;
                     END (* if FormAccepted *);
                     ACodeRecord^.exit := FALSE; (* changed 4/26/89: bug *)
                     RETURN; |
        ChainCode :
                     ReadMacString (str, ChainCode);
                     ClearPlayback;
                     IF MacrosModified THEN
                       AskSave;
                     END (* if MacrosModified *);
                     DisposeMacros (MacroTree);
                     SetString (S, "|MACCHAIN");
                     IF CallOverlayWithContext (S, ADR (str)) THEN
                       dummy := 1;
                     END (* if CallOverlayWithContext *);
                     ACodeRecord^.exit := FALSE;
                     RETURN;
      ELSE
        ;
      END;   (* CASE *)

      IF ( ( CARDINAL (C) = NameCode ) OR CodeIsAHotKey (C) ) THEN
        result := GetTheMacro ();  (* was ACodeRecord^.exit *)
        ACodeRecord^.exit := FALSE;
        RETURN;
      END (* if *);

      ACodeRecord^.exit := TRUE;
      RETURN;

    END (* if *);

    EndThisPlayback;
    RETURN;

  END PlayBack;


  PROCEDURE DoPlayback;
  BEGIN
    PlayBack (OurCodeRecord);
  END DoPlayback;



BEGIN
  OverlayID := ImAnInstallableOverlay (DoPlayback, AnOverlayProc(NIL));
  DoPlayback;
END MacPlay.
