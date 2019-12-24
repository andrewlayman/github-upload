(*<BIND IMPLEMENTATION BIND>*) MODULE Macros;



(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)




(*  Modifications:

      2/9/88 - added capability in OurGetCode to playback macro during
               recording (hotkey only right now).
             - Added DoMacroByName to enable above with PickList.

      rraaiidd: End of DoMacroMenu uses OnMenu to PushBuffer, etc.
                Causes program crash.  Why is it there?
                To return user to Time Line main menu... but why a crash???

      2/19/88 - Added call to Available in DoRecording to check heap space
                for the rug.
                
      3/6/88  - Added Keyboard.ClearBreak to OurFlushKeyboard
      
      3/30/88 - Remved call to Available in DoRecording. 
      
      6/27/88 - Moved DoMacroMenu to an overlay "MacMenuD".
      
      10-Aug-89  KKC - Add copyright message.
      
      27-Sep-89 RSC - Fixed a bug where Keyboard.KeyPress was being called
                while waiting for a keystroke.  Because of this, the lights
                in KBState were not being changed (CAPS/SCROLL/NUM) when a
                macro FINISHED, before any "real" key is hit.
                Bug # 1508.
                
      29-Sep-89 LVK - Removed calls to InstallNewProcedure and Unregister-
                ForNotices after the call to Chain at the end of program.
                The overlay manager now replaces all stolen vectors, etc.

     13-Nov-89  RSC - Import from Space rather than Storage.

     30-Nov-89  RSC - Added the MacStackCheckOK procedure use and import.

     11-Dec-89  LVK - Cannot get macro list with hot key (ListKey) if
                 on the Macro Menu.

     18-Dec-89  RSC - Minor cleanups to reduce code size in Macros root.
                      Also put MacMenuD into the reserved layer, because
                      it calls MACLOAD (in the reserved layer), and
                      MACLOAD loads lots of macros, so we don't want
                      heap fragmentations.

      3-Jan-90  RSC - Removed calls to MACSETKE and MACAUTO, as they are
                      now part of MACINIT.  Done to speed up the starting
                      of TimeLine.

     10-Jan-90  RSC - fixed bug # 2040, where the editor was being fed
                      mouse codes via MACED as, say, {MouseUp} rather
                      than the code 450.

     20-Jan-90  LAA - Removed the construct:
                      IF (OldBreakRequested()) THEN
                         ....
                      ELSE
                         RETURN OldBreakRequested();
                      END;
                      which had a veritable portal of penetrability that would
                      allow Macros to miss-process a Break if the timing was 
                      wrong.  I also fixed a bug: Ctrl-Break was not being
                      honored when Macros was installed an in neutral, so you
                      couldn't break out of recalcs, reports, etc.
                      
      7-Mar-90  RSC - Changed use of "MenuOn", so that there is only one
                      copy of the boolean, not several pointers to several
                      copies of it.

      5-Oct-90  RSC - Changed this to be loaded on demand, and THEN
                      locked.

      9-Oct-90  RSC - Oops.  Save OverlayContext and OverlayCallChain
                      in the MAIN before calling MACINIT.

     20-Oct-90  RSC - Added BIND toggles.

     30-May-91  RSC - Well, well, well.  Just goes to show you how little
                      programmers use this stuff.  On my 9-Oct-90 change
                      I introduced a cataclismic error when Macros are
                      re-invoked a second time from RunMenu.  Fixed it.
                      I was not re-fetching the context and call chain.

     31-May-91  RSC - If startup fails,don't continue.

      Note: for phrases, use module numbers 26300 & 26400
*)

    IMPORT Kbio;

    IMPORT Keyboard;

    FROM Dialog         IMPORT
                               FatalError, Burp, Error;
    
    FROM Keys           IMPORT
                               ExitKey, GotoTodayKey, MouseUp, MouseStillDown;

    FROM Lights         IMPORT 
                               RemoveLight;

    FROM LStrings       IMPORT
                               SetString,
                               ConcatS,
                               Copy;

    FROM MacBuffs       IMPORT
                               PopBuffer;

    FROM MacCancl       IMPORT
                               CancelProc,
                               CheckForCancel,
                               ClearPlayback,
                               ClearPlaybackLights;

    FROM MacCodes       IMPORT CodeIsAHotKey;
                         
    FROM MacDo          IMPORT
                               DoMacroByHotkey;

    FROM MacLights      IMPORT
                               InputLight,
                               RecordLight,
                               PauseLight;

    FROM MacNodes       IMPORT
                               MacroTree;

    FROM MacRcord       IMPORT
                               DoRecording, StopRecording;

    FROM MacrosRc       IMPORT
                               GetMacroLength;

    FROM MacStack       IMPORT
                               MacStack;
                         
     FROM MacSetUp      IMPORT
                               StartRecordKey, MenuKey,
                               ListKey, StepMode;

    FROM MacState       IMPORT
                               PopState, AState,
                               State, StateStack;
                         
    FROM MacTalk        IMPORT
                               MacDeath;

    FROM MacVars        IMPORT 
                               Editing,
                               EditCancel,
                               MacrosModified,
                               (*InAForm,*)
                               Interlock,
                               FormAccepted,
                               OldGetCode,
                               OldKeyPress,
                               OldFlushKeyboardBuffer,
                               OldBreakRequested,

                               OurEditRecord,
                               OurRecordingRecord,
                               OurCodeRecord,
                               
                               MenuOn  (* 8-Mar-90 RSC *);

    FROM Menus          IMPORT
                               NoYes;

    FROM MsgFile        IMPORT
                               GetMessage;

    FROM Notices        IMPORT
                               AnOccasion, AStep, RegisterForNotices,
                               UnRegisterForNotices;

FROM Overlays           IMPORT
    (* TYPE *)                 AnOverlayID,
    (* PROC *)                 ImALockedOverlay,
                               CallOverlay, InstallNewProcedure,
                               OverlayContext, OverlayCallChain,
                               CallOverlayWithContext;

FROM OvTree             IMPORT
    (* TYPE *)                 AnOverlayProc;

    FROM Space          IMPORT
                               ALLOCATE, DEALLOCATE, StackSpaceLeft;

    FROM SYSTEM         IMPORT
                               ADR, ADDRESS;


                                              

VAR
    OverlayID               : AnOverlayID;

    MouseCount              : CARDINAL;
    CheckingForCancel       : BOOLEAN;





(* RSC  18-Dec-89  Put these small utility procs here to help save global
                   variable space, and MAYBE a little code space.
*)
PROCEDURE CallTheOverlay(     Name      : ARRAY OF CHAR;
                              Context   : ADDRESS ) : BOOLEAN;
VAR
    S   : ARRAY [0..19] OF CHAR;
BEGIN
    SetString (S, Name);
    RETURN CallOverlayWithContext( S, Context );
END CallTheOverlay;


PROCEDURE DoTheError(     TheNumber     : CARDINAL );
VAR
    S   : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage( TheNumber, S );
    Error(S);
END DoTheError;





(*--------------------------------------------------------------------------

If user quits Time Line, ProgramQuitting asks the user if he wants to
save his macros (if any macros were created or saved during the session).

ProgramQuitting is a registered NoticeProc.

---------------------------------------------------------------------------*)



PROCEDURE ProgramQuitting(     Occasion : AnOccasion;
                               Step     : AStep;
                               Context  : ADDRESS ) : BOOLEAN;

BEGIN
  IF ((MacrosModified) AND (Step = (*BeforeActing*)RequestPermission)) THEN
    RETURN SaveMacros();
  END;
  RETURN TRUE;
END ProgramQuitting;





PROCEDURE SaveMacros():BOOLEAN;
VAR
    S   : ARRAY [0..255] OF CHAR;
    ok  : BOOLEAN;
BEGIN
    IF MacroTree^.Methods^.GetFirst (MacroTree) = NIL THEN
      MacrosModified := FALSE;
      RETURN TRUE;
    END;
    INC (Interlock);
    GetMessage (26454, S);
    IF NOT NoYes (S) THEN
      IF (CallTheOverlay("|MACSAVE", NIL) AND FormAccepted) THEN
        (*MacrosModified := FALSE;*) (* why bother?.. user is quitting TL *)
        ok := TRUE;
      ELSE
        ok := FALSE;
      END;
    ELSE
      ok := TRUE;
    END;
    DEC (Interlock);
    RETURN ok;
END SaveMacros;








(*------------------------------------------------------------------------

The main man.

-------------------------------------------------------------------------*)

PROCEDURE OurGetCode():CARDINAL;
VAR
    C   : CARDINAL;
    ok  : BOOLEAN;

    PROCEDURE DoMacPick();
    VAR
        TempMacName     : ARRAY [0..40] OF CHAR;
        ok              : BOOLEAN;
    BEGIN
        INC (Interlock);
        ok := (CallTheOverlay("|MACPICK", ADR(TempMacName)));
        DEC (Interlock);
    END DoMacPick;


    (* 10-Jan-90 RSC added some special editing mouse support.
                     bug # 2040.
    *)
    PROCEDURE MouseCode() : BOOLEAN;
    VAR
        MouseCodeFound  : BOOLEAN;
    BEGIN
        MouseCodeFound := TRUE;

        IF (MouseCount > 0) THEN
            DEC(MouseCount);    (* one less to go.  *)
        ELSIF (C >= MouseUp) AND (C <= MouseStillDown) THEN
            MouseCount := 2;    (* We expect 2 more *)
        ELSE
            MouseCodeFound := FALSE;
        END;

        RETURN MouseCodeFound;

    END MouseCode;


BEGIN


  IF (Interlock > 0) THEN
    RETURN OldGetCode();
  END;

  INC(Interlock);
 

  LOOP
    CASE State OF
      Neutral   :
                  (* loop is needed so KBSTATE will be updated *)

                  REPEAT
                  UNTIL Kbio.KeyPress();

                  C := OldGetCode();

                  IF Editing THEN
                        OurEditRecord^.code := C;
                        IF (MouseCode()) THEN
                            EXIT;
                        ELSE
                            IF CallTheOverlay("|MACED",NIL) THEN
                              C := OurEditRecord^.code;
                              IF OurEditRecord^.exit THEN
                                OurEditRecord^.exit := FALSE;
                                EXIT;
                              END;
                            ELSE
                                DoTheError(26455);
                                EXIT;
                            END;
                        END;

                  ELSIF (CodeIsAHotKey(C) AND NOT MenuOn) THEN
                        IF NOT DoMacroByHotkey(C) THEN EXIT END;

                  ELSIF ((C=StartRecordKey) AND NOT MenuOn) THEN
                        IF (StateStack^.next = NIL) THEN
                          IF NOT DoRecording() THEN
                            DoTheError(26456);
                            EXIT;
                          END;
                        ELSE
                          DoTheError(26457);
                        END;

                  ELSIF ((C=MenuKey) AND
                          NOT MenuOn AND
                          NOT OurCodeRecord^.InputPause) THEN
                        DEC (Interlock);
                        ok := CallTheOverlay("|MACMENUD", NIL);
                        INC (Interlock);

                  ELSIF (OurCodeRecord^.InputPause) THEN
                        IF (C = ExitKey) THEN
                          RemoveLight (InputLight);
                          OurCodeRecord^.InputPause := FALSE;
                          PopState;
                        ELSE EXIT;
                        END;

                  ELSIF (OurCodeRecord^.Pause AND (C = GotoTodayKey)) THEN
                        RemoveLight (PauseLight);
                        OurCodeRecord^.Pause := FALSE;
                        PopState;

                  ELSIF C = ListKey THEN
                     IF NOT MenuOn THEN                     (*12/11/89 LVK*)
                         DoMacPick();
                     ELSE
                         Burp;
                     END;

                  ELSE
                        EXIT;
                  END;

    | Recording :

                      (* 7-Mar-90 RSC Was ...menuOn^ := MenuOn;
                                      Now handled in MACINIT.
                      *)
                    OurRecordingRecord^.exit := FALSE;

                    IF CallTheOverlay("|MACREC", NIL) THEN
                      C := OurRecordingRecord^.code;
                      IF OurRecordingRecord^.exit THEN
                        OurRecordingRecord^.exit := FALSE;
                        EXIT;
                      END;
                    ELSE
                      DoTheError(26459);
                      StopRecording;
                    END;

      | Playback  :
                    IF CallTheOverlay("|MACPLAY", NIL) THEN
                      C := OurCodeRecord^.code;
                      IF (OurCodeRecord^.exit) THEN
                        OurCodeRecord^.exit := FALSE;
                        EXIT;
                      END;
                    ELSE
                      DoTheError(26460);
                      ClearPlayback;
                    END;
    ELSE 
        FatalError();
    END;
  END;

  DEC(Interlock);

  RETURN C;
END OurGetCode;











(*------------------------------------------------------------------------

   Returns TRUE if: 1) a macro is being played back, OR
                    2) a key is pressed while a macro is not being played.

-------------------------------------------------------------------------*)

PROCEDURE OurKeyPress(): BOOLEAN;
VAR
    len   : CARDINAL;
BEGIN

    IF MacStack = NIL THEN RETURN OldKeyPress(); END;

    len := GetMacroLength (MacStack^.macro);

    RETURN (
            (State=Playback)                           AND
            (MacStack^.pos < len) AND
            (Interlock=0)
           )                                           OR
           (
            OldKeyPress()
           );

END OurKeyPress;






PROCEDURE OurBreakRequested():BOOLEAN;
CONST
    StackConstant   = 4096;         (* min stack space we allow *)

    PROCEDURE LocalCheckCancel(     Message : CARDINAL ) : BOOLEAN;
    VAR
        S   : ARRAY [0..255] OF CHAR;
        ok  : BOOLEAN;
    BEGIN
       CheckingForCancel := TRUE;
       Keyboard.ClearBreak;
       GetMessage( Message, S);
       ok := CheckForCancel (S);
       CheckingForCancel := FALSE;
       RETURN ok;
    END LocalCheckCancel;

BEGIN
    IF (NOT StackSpaceLeft( StackConstant )) THEN  (* 30-Nov-89 RSC added. *)
        RETURN FALSE;
    END;

    IF CheckingForCancel THEN
      Keyboard.ClearBreak;
      RETURN FALSE;
    END;

    IF (OldBreakRequested()) THEN
        IF (OurCodeRecord^.InputPause) THEN
           IF (LocalCheckCancel(26462)) THEN
               OurCodeRecord^.InputPause := FALSE;
               RemoveLight (InputLight);
               ClearPlayback;
           END;
        ELSIF (State = Playback) THEN
           IF ((StateStack^.next <> NIL) AND
               (StateStack^.next^.state = Playback)) THEN
               IF (LocalCheckCancel(26462)) THEN
                   OurCodeRecord^.InputPause := FALSE;
                   RemoveLight (InputLight);
                   ClearPlayback;
               END;
            ELSIF (LocalCheckCancel(26461)) THEN
                ClearPlayback;
            END;
        ELSIF (OurCodeRecord^.Pause) THEN
            IF (LocalCheckCancel(26463)) THEN
               OurCodeRecord^.Pause := FALSE;
               RemoveLight (PauseLight);
               ClearPlayback;
            END;
        ELSIF (State = Recording)                   THEN
            IF (StateStack^.next^.state = Playback) THEN
                           (* Must be a Secondary Macro *)
                IF (LocalCheckCancel(26464)) THEN
                    OurRecordingRecord^.break := TRUE;
                    OurCodeRecord^.InputPause := FALSE;
                    PopBuffer;
                    RemoveLight (InputLight);
                    ClearPlaybackLights;
  	            ELSE
                    OurFlushKeyboardBuffer;
                END;
            ELSE
                IF (LocalCheckCancel(26465)) THEN
                    OurRecordingRecord^.break := TRUE;
                    RemoveLight (RecordLight);
                    PopBuffer;
                END;
            END;
        ELSE                         (* Idle state, and break was requested *)
            RETURN TRUE;
        END;
    END;                                                       (* 20-Jan-90 *)

    RETURN FALSE;

END OurBreakRequested;



(*------------------------------------------------------------------------

Same as Keyboard.FlushKeyboardBuffer.

-------------------------------------------------------------------------*)

PROCEDURE OurFlushKeyboardBuffer;
VAR
     Copyright : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    OldFlushKeyboardBuffer;
END OurFlushKeyboardBuffer;



VAR
    TheCallChain,
    TheContext     : ADDRESS;

(* If our invoker wants us to call someone else, so be it.

    30-May-91 RSC The caller must set up TheCallChain and TheContext.
                  On re-invokations, he did not (prior to this fix).
*)
PROCEDURE DoCallThrough();
VAR
    CallChain   : POINTER TO ARRAY [0..255] OF CHAR;
    OverlayName : ARRAY [0..15] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    CallChain := TheCallChain;

    IF (CallChain = NIL) OR
       (CallChain^[0] = 0C) THEN (* Handle RunMenu calls too ... *)
        CallChain := TheContext;
    END;

    IF (CallChain <> NIL) THEN
        Copy(CallChain^,OverlayName);
        ok := CallOverlay( OverlayName );
    END;

END DoCallThrough;



PROCEDURE DoMacros();           (* 30-May-91 RSC  *)
BEGIN
    TheCallChain    := OverlayCallChain();
    TheContext      := OverlayContext();
    DoCallThrough();
END DoMacros;





(*<BIND
PROCEDURE MacrosBind();
BIND>*) 
BEGIN
    MenuOn            := FALSE;
    CheckingForCancel := FALSE;
    MouseCount        := 0;

        (* Install our keystroke handler into the keystroke handling chain. *)
    OldGetCode := Keyboard.GetAnyCode;
    InstallNewProcedure (ADR(Keyboard.GetAnyCode), PROC(OurGetCode),
                         ADR(OldGetCode));

    OldKeyPress := Keyboard.KeyPress;
    InstallNewProcedure (ADR(Keyboard.KeyPress), PROC(OurKeyPress),
                         ADR(OldKeyPress));

    OldBreakRequested := Keyboard.BreakRequested;
    InstallNewProcedure (ADR(Keyboard.BreakRequested),
                         PROC(OurBreakRequested), ADR(OldBreakRequested));

    OldFlushKeyboardBuffer := Keyboard.FlushKeyboardBuffer;
    InstallNewProcedure (ADR(Keyboard.FlushKeyboardBuffer),
              PROC(OurFlushKeyboardBuffer), ADR(OldFlushKeyboardBuffer));


         (* So we can watch for quitting Time Line *)

    RegisterForNotices(ProgramQuit, ProgramQuitting);

        (* 30-May-91 RSC Was DoCallThrough
        *)
    OverlayID := ImALockedOverlay( DoMacros, AnOverlayProc(NIL) );

        (* 9-Oct-90 RSC Grab these before the next overlay runs.
        *)
    TheCallChain    := OverlayCallChain();
    TheContext      := OverlayContext();

    IF NOT CallTheOverlay("|MACINIT",NIL) THEN
        MacDeath;
    ELSE
        DoCallThrough();
    END;

(*<BIND
END MacrosBind;
BIND>*) 

END Macros.
