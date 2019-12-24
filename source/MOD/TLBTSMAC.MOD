MODULE TLBTSMacro;

    (* MODIFICATION HISTORY:

       Feb. 25, 1988  AJL  -Made FlushBuffer cancel any playback.
                           -Removed the code that was supposed to ask
                            whether or not to cancel playback on Break,
                            since a call to FlushBuffer will have already
                            cancelled playback.
        May 4, 1988   RSC   When keystroke limit reached, beep and stop
                            recording.  Raise limit to 200 keys.
       Feb 14, 1989   RSC   Made into a LOCKED overlay.

       Mar  2, 1989   RSC   Support new "InstallNewProcedure" call.
       Mar  7, 1989   RSC   Fixed above change to "InstallNewProcedure".
       Aug  9, 1989   KKC   Add copyright message.
       Oct  9, 1990   RSC   Add support to invoke "real" macros.
       Feb 12, 1991   RSC   Oops.  Bug # 4176, we require an extra code
                            before macros runs.
       May 30, 1991   RSC   Once we launch keopke macros, never reference
                            them again.

    *)



    FROM Chainer  IMPORT Chain;

    FROM Codes  IMPORT ACode, ASetOfCodes, EmptyCodeSet;

    FROM Dialog   IMPORT Message, FatalError, Burp, Error,
                         NotYetImplemented;

    FROM Kbio     IMPORT avidmode, Tone;

    IMPORT Keyboard;

    FROM Lights   IMPORT ActiveLightRegion, ALight, InstallLight,
                         RemoveLight, DisplayLight, EnableLights;

    FROM LStrings IMPORT SetString, StoC;

    FROM Menus    IMPORT NoYes;

    FROM MsgFile  IMPORT GetMessage;

FROM Overlays      IMPORT
    (* TYPE *)          AnOverlayID,
    (* PROC *)          ImALockedOverlay, InstallNewProcedure,
                        CallOverlayWithContext;

FROM OvTree        IMPORT
    (* TYPE *)          AContextListEntry, AnOverlayProc,
    (* VAR  *)          OverlayTree;

FROM ParmLine      IMPORT GetOption;

FROM SegWords      IMPORT 
    (* PROC *)          WordNumber;

FROM SYSTEM        IMPORT ADDRESS, ADR;



    (* Keyboard ----> Macro Facility -----> Application  *)




CONST
    MaxKeystrokes    = 200;         (* RSC 5/4/88 *)
    MacroRecordKey   = 256 + 13H;   (* Alt-R *)
    MacroPlaybackKey = 256 + 19H;   (* Alt-P *)
    ModuleNumber     = 23300; 

TYPE
    AMacroState     = (Neutral, Recording, Playback);


VAR
    OverlayID               : AnOverlayID;

    OldGetCode              : Keyboard.AGetCodeProcedure;
    OldKeyPress             : Keyboard.AYesNoProcedure;
    OldFlushKeyboardBuffer  : Keyboard.AServiceProcedure;
    Count, Count2           : [0..MaxKeystrokes];
    Buffer                  : ARRAY [1..MaxKeystrokes] OF CARDINAL;
    MacroInterlock          : CARDINAL;
    MacroLight              : ALight;
    MacroState              : AMacroState;
    KeopkeMacrosOn          : BOOLEAN;





    (* Procedures for keyboard macros. *)





PROCEDURE StartMacroRecording();
VAR
    S  : ARRAY [0..30] OF CHAR;
BEGIN
    Count := 0;
    InstallLight(ActiveLightRegion, 1, 6, 15, MacroLight);
    GetMessage(ModuleNumber+1,S);    (* "Record" *)
    DisplayLight(MacroLight,S,videolights);
END StartMacroRecording;




PROCEDURE EndMacroRecording();
VAR
    S  : ARRAY [0..30] OF CHAR;
BEGIN
    RemoveLight(MacroLight);
END EndMacroRecording;







PROCEDURE StartMacroPlayback();
VAR
    S  : ARRAY [0..30] OF CHAR;
BEGIN
    Count2 := 0;
    InstallLight(ActiveLightRegion, 1, 6, 10, MacroLight);
    GetMessage(ModuleNumber+2,S);   (* "Playback" *) 
    DisplayLight(MacroLight,S,videolights);
END StartMacroPlayback;




PROCEDURE EndMacroPlayback();
VAR
    S  : ARRAY [0..30] OF CHAR;
BEGIN
    RemoveLight(MacroLight);
    MacroState := Neutral;
END EndMacroPlayback;



PROCEDURE CheckForCancel( VAR What : ARRAY OF CHAR ):BOOLEAN;
VAR
    ok      : BOOLEAN;
BEGIN
    INC(MacroInterlock);
    ok := NoYes(What);
    DEC(MacroInterlock);
    RETURN ok;
END CheckForCancel;




VAR
    MenuKey : CARDINAL;


PROCEDURE SetupMacroMenuKey();  (* FROM MACSETUP.MOD!! *)
CONST
    MacroModuleNumber = 26400;
VAR
    k       : CARDINAL;
    Text    : ARRAY [0..8]  OF CHAR;
    S       : ARRAY [0..255] OF CHAR;
BEGIN

    GetMessage(MacroModuleNumber+95,S);
    WordNumber(S,1,Text); k := 1; MenuKey        := StoC(Text,k);

END SetupMacroMenuKey;






PROCEDURE MacroGetCode():CARDINAL;
VAR
    T,
    C  : CARDINAL;
    S  : ARRAY [0..30] OF CHAR;
    ok : BOOLEAN;
BEGIN
    IF (MacroInterlock > 0) THEN
        RETURN OldGetCode();
    END;

    INC(MacroInterlock);

    LOOP
        CASE MacroState OF
            Neutral   :
                         C := OldGetCode();
                         IF (C=MacroRecordKey) THEN
                             MacroState := Recording;
                             StartMacroRecording();
                         ELSIF (C=MacroPlaybackKey) THEN
                             MacroState := Playback;
                             StartMacroPlayback();

                          (* 30-May-91 RSC

                            Complication: Once we invoke Keopke macros via
                            ALT-F1 (the macros menu key), we pretend we got
                            no code back.  Macros has hooked itself into
                            the chain of keyboard sniffers.  However, this
                            module is still waiting for a code, and has
                            already written off the ALT-F1 processing,
                            knowing that macros will handle it.  Well,
                            Macros won't until we return something.  If
                            we return a spurious "dummy" code, we could
                            cause grief for our caller.

                            To alleviate this problem, I call the NEW,
                            STOLEN GetAnyCode.
                          *)
                         ELSIF (C=MenuKey) AND
                               (NOT KeopkeMacrosOn)  THEN
                             SetString( S, "!MACROS(MACMENUD)" );
                             KeopkeMacrosOn       := TRUE;
                             ok := CallOverlayWithContext( S, NIL );
                             C  := Keyboard.GetAnyCode();
                             EXIT;
                         ELSE
                             EXIT;
                         END;

          | Recording :
                                 (* Do not call OldGetCode until
                                    we know that there really is a
                                    code ready--otherwise it will
                                    translate Break into CancelKey. *)
                             REPEAT
                                 IF (Keyboard.BreakRequested()) THEN
                                     Keyboard.ClearBreak();
                                     GetMessage(ModuleNumber+3,S);  (* "Cancel the recording?" *)
                                     IF (CheckForCancel(S)) THEN
                                         MacroState := Neutral;
                                         EndMacroRecording();
                                     END;
                                 END;
                             UNTIL (MacroState=Neutral) OR (OldKeyPress() AND NOT Keyboard.BreakRequested());

                             C := OldGetCode();

                             IF (C=MacroRecordKey) THEN
                                 MacroState := Neutral;
                                 EndMacroRecording();
                             ELSE
                                 IF (Count < HIGH(Buffer)) THEN
                                     INC(Count);
                                     Buffer[Count] := C;
                                 ELSE
            (* RSC 5/4/88 *)         MacroState := Neutral;
                                     EndMacroRecording();
                                     FOR T := 800 TO 200 BY -1 DO
                                         Tone(T,2);
                                     END;
                                 END;
                                 EXIT;
                             END;

          | Playback  :
                         IF (Count2 < Count) THEN
                             INC(Count2);
                             C := Buffer[Count2];
                             EXIT;
                         ELSE
                             EndMacroPlayback();
                         END;
        ELSE HALT;
        END;
    END;

    DEC(MacroInterlock);

    RETURN C;
END MacroGetCode;










PROCEDURE MacroKeyPress(): BOOLEAN;
BEGIN
    IF (MacroState=Playback) AND (MacroInterlock=0) THEN
        IF (Count2 < Count) THEN
            RETURN TRUE;
        ELSE
            EndMacroPlayback();
            RETURN FALSE;
        END;
    ELSE
        RETURN OldKeyPress();
    END;
END MacroKeyPress;






PROCEDURE MacroFlushKeyboardBuffer;
BEGIN
    IF (MacroInterlock = 0) AND (MacroState = Playback) THEN
        EndMacroPlayback();
    END;
    OldFlushKeyboardBuffer;
END MacroFlushKeyboardBuffer;




PROCEDURE ShutDown();
VAR
    Copyright           : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

(* RSC 2-Mar-89 - Removed putting back old vectors. *)

        (* In case the chained-to program terminates (abnormally)
           without finishing a recording or playback session. *)

    CASE MacroState OF
        Neutral   :
      | Recording :
                    EndMacroRecording();
      | Playback  :
                    EndMacroPlayback();
    END;
    MacroState := Neutral;

END ShutDown;





PROCEDURE DoWeStartMacros();
CONST
    StartupMessageForMacros = 26374;  (* FROM MACINIT.MOD *)
VAR
    Argument,
    Option  : ARRAY [0..99] OF CHAR;
    Found   : BOOLEAN;
BEGIN

    GetMessage(StartupMessageForMacros, Option);
    GetOption(Option, Found, Argument);
    IF Found THEN
        SetString( Option, "!MACROS" );

            (* 30-May-91 RSC  *)
        KeopkeMacrosOn := TRUE;
        Found := CallOverlayWithContext( Option, NIL );
    END;

END DoWeStartMacros;



BEGIN
    KeopkeMacrosOn := FALSE;
    MacroState     := Neutral;
    Count          := 0;
    MacroInterlock := 0;

        (* Install our keystroke handler into the keystroke handling chain. *)

    InstallNewProcedure(ADR(Keyboard.GetAnyCode), PROC(MacroGetCode), ADR(OldGetCode));  (* RSC 2-Mar-89 *)
    InstallNewProcedure(ADR(Keyboard.KeyPress),PROC(MacroKeyPress), ADR(OldKeyPress));
    InstallNewProcedure(ADR(Keyboard.FlushKeyboardBuffer),MacroFlushKeyboardBuffer, ADR(OldFlushKeyboardBuffer));

    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), ShutDown );

    (* 9-Oct-90 RSC Start macros if needed; setup macros' menu key
    *)
    SetupMacroMenuKey();
    DoWeStartMacros();

END TLBTSMacro.
