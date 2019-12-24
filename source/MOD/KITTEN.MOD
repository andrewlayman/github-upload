MODULE Kitten;

(* Modification History:

    2-Mar-89 RSC  Changed parameters to "InstallNewProcedure".
    7-Mar-89 LAA  Changed ADDRESS to ADR in calls to InstallNewProcedure.
   24-Dec-90 AJL  Monitor more notices so that we can deny permission
                  to do dangerous things.
                  Use the Overlays procedures, rather than Chainer.
*)

    FROM ExportLinkage IMPORT ExportMedia;

    FROM Clock  IMPORT ATestProcedure, Delay, NoEarlyExit;

    FROM Codes  IMPORT ACode, ASetOfCodes, EmptyCodeSet;

    FROM Dialog   IMPORT Message, FatalError, Burp, Error,
                         NotYetImplemented, MessageBox;

    FROM FormRec IMPORT AFormRecord;

    FROM Kbio     IMPORT avidmode, soundon, BreakRequested;

    IMPORT Keyboard;

    FROM Keys     IMPORT CancelKey;

    FROM LStrings IMPORT Fill, SetString, Search, CtoS, ConcatS, ConcatLS,
                         Copy, Upshift, LengthOf;

    FROM Menus    IMPORT NoYes;

    FROM Notices                IMPORT
        (* TYPE *)                  AnOccasion, AStep,
        (* PROC *)                  RegisterForNotices, SendNotices;

    FROM Overlays      IMPORT
        (* TYPE *)          AnOverlayID,
        (* PROC *)          ImALockedOverlay, InstallNewProcedure,
                            EnteringOverlay, ExitingOverlay;

    FROM OvTree        IMPORT
        (* TYPE *)          AContextListEntry, AnOverlayProc,
        (* VAR  *)          OverlayTree;

    FROM Random   IMPORT        RandomInit, Randomize, RandomCard;  

    FROM SYSTEM                 IMPORT ADDRESS, ADR;



CONST
    MacroPlaybackKey = 256 + 19H;   (* Alt-P *)



VAR
    OldGetCode              : Keyboard.AGetCodeProcedure;
    OldKeyPress             : Keyboard.AYesNoProcedure;
    OldFlushKeyboardBuffer  : Keyboard.AServiceProcedure;
    OldBreakRequested       : Keyboard.AYesNoProcedure;
    Running                 : BOOLEAN;
    MemoryAlerts            : BOOLEAN;
    RequireEscape           : BOOLEAN;
    Interlock               : CARDINAL;
    OldBreakHandler         : Keyboard.AServiceProcedure;
    OverlayID               : AnOverlayID;
    LowSpeedCount           : CARDINAL;



PROCEDURE NoticeFailure(       Occasion : AnOccasion;
                               Step     : AStep;
                               Context  : ADDRESS ):BOOLEAN;
VAR
    String  : POINTER TO ARRAY [0..255] OF CHAR;
    S,S2    : ARRAY [0..20] OF CHAR;
   
BEGIN
    IF (NOT Running) OR (Step=RequestPermission) THEN
        RETURN TRUE;
    END;

    CASE Occasion OF
        ProgramEnd : Running := FALSE;
     |  DialogActive,
        WarningActive :  
                         String := Context;
                         Copy(String^,S);
                         Upshift(S);
                         SetString(S2,"FATAL");
                         IF (Search(S,S2,1) <> 0) THEN
                             Running := FALSE;
                             HALT;
                         END;
     ELSE
    END;
    RETURN TRUE;
END NoticeFailure;




PROCEDURE Refuser(       Occasion : AnOccasion;
                         Step     : AStep;
                         Context  : ADDRESS ):BOOLEAN;
CONST
    DosDateForm = 7;
VAR
    FormRecord : POINTER TO AFormRecord;
BEGIN
    IF (Running) AND (Step = RequestPermission) THEN
        CASE Occasion OF
            ModelSave,
            ConfigSave,
            ExitToDOS,
            DiskFileErase,
            ProgramQuit    : IF (Step = RequestPermission) THEN
                                 RETURN FALSE;
                             END;
         |  FormActive     :         (* A form is receiving input *)
                             FormRecord := Context;
                                 (* Don't allow reset of DOS Date and Time. *)
                             IF (FormRecord <> NIL) AND (FormRecord^.ID = DosDateForm) THEN
                                 CASE Step OF
                                     RequestPermission:  RETURN FALSE;
                                   | BeforeActing     :  RequireEscape := TRUE;
                                     ELSE                RequireEscape := FALSE;
                                 END;
                             END;
        ELSE
            (* Ignore *)
        END;
    END;
    RETURN TRUE;
END Refuser;






PROCEDURE NoRoom():BOOLEAN;
BEGIN
     RETURN FALSE;
END NoRoom;


PROCEDURE CheckLowMemory();
BEGIN
        (* About 1 out of every ten codes, panic and flush memory. *)
    INC(Interlock);
    IF (MemoryAlerts) AND (RandomCard(9)=1) AND (Running) THEN
        SendNotices(LowMemory, AfterActing, ADDRESS(NoRoom));
    END;
    DEC(Interlock);
END CheckLowMemory;




PROCEDURE CheckConditions();
BEGIN
    IF (LengthOf(ExportMedia) >= HIGH(ExportMedia)) THEN
        Running := FALSE;
        FatalError();
    END;
END CheckConditions;


PROCEDURE RandomKey():CARDINAL;
VAR
    C : CARDINAL;
BEGIN
    REPEAT
       C := RandomCard(371)+2;
    UNTIL (C <> 255);
    RETURN C;
END RandomKey;



PROCEDURE MacroGetCode():CARDINAL;
VAR
    C  : CARDINAL;
    S  : ARRAY [0..80] OF CHAR;
BEGIN
    EnteringOverlay(OverlayID);

    IF (Interlock > 0) THEN
        ExitingOverlay(OverlayID);
        RETURN OldGetCode();  
    END;

    INC(Interlock);

    CheckLowMemory();
    CheckConditions();

    LOOP
            (* If a user presses a key, we run slowly for a while to 
               make it easier to enter more keys without our intervening
               codes gumming things up. *)
        IF (LowSpeedCount > 0) THEN
                (* Wait a few seconds, or until a real key is pressed. *)
            Delay(500,ATestProcedure(OldKeyPress));
        END;

        IF (Running) AND (NOT OldKeyPress()) THEN
                (* If running slowly, and no real keys, count down to
                   full speed. *)
            IF (LowSpeedCount > 0) THEN
                DEC(LowSpeedCount);
            END;

            IF (OldBreakRequested()) THEN
                Keyboard.ClearBreak();
                Running := FALSE;
            ELSIF (RequireEscape) THEN
                    (* Return the key that means cancel this thing. *)
                C := CancelKey;
                EXIT;
            ELSE
                soundon := FALSE;   (* Continually turn off the sound so it doesn't
                                       slow things down (or drive us nuts!)  *)

                    (* Make up a random character. *)
                C := RandomKey();
                EXIT;
            END;
        ELSE
            C := OldGetCode();
            IF (C = MacroPlaybackKey) THEN
                Running := FALSE;
                SetString(S,"Play Kitten-on-the-Keyboard?");
                IF NoYes(S) THEN
                    SetString(S,"Continual Memory Alerts?");
                    MemoryAlerts := NoYes(S);
                    SetString(S,"Randomize?");
                    IF NoYes(S) THEN
                        Randomize();
                    ELSE
                        RandomInit(3);
                    END;
                    Running := TRUE;
                ELSE
                    Running := FALSE;
                END;
            ELSE 
                LowSpeedCount := 1;
                EXIT;
            END;
        END;
    END;

    DEC(Interlock);

    ExitingOverlay(OverlayID);

    RETURN C;

END MacroGetCode;





PROCEDURE OurBreakRequested():BOOLEAN;
VAR 
    B : BOOLEAN;
BEGIN
    EnteringOverlay(OverlayID);
    IF (Interlock = 0) THEN
        CheckLowMemory();
        CheckConditions();
    END;
    B := OldBreakRequested();
    ExitingOverlay(OverlayID);
    RETURN B;
END OurBreakRequested;




PROCEDURE MacroKeyPress(): BOOLEAN;
VAR 
    B : BOOLEAN;
BEGIN
    EnteringOverlay(OverlayID);
    IF (Interlock = 0) THEN
        CheckLowMemory();
        CheckConditions();
        IF (Running) THEN
            B := TRUE;
        ELSE
            B := OldKeyPress();
        END;
    ELSE
        B :=  OldKeyPress();
    END;
    ExitingOverlay(OverlayID);
    RETURN B;
END MacroKeyPress;






PROCEDURE MacroFlushKeyboardBuffer;
BEGIN
    EnteringOverlay(OverlayID);
    OldFlushKeyboardBuffer;
    ExitingOverlay(OverlayID);
END MacroFlushKeyboardBuffer;



    (* OurBreakHandler intercepts the BreakHandler declared in
       the Keyboard module. *)


PROCEDURE OurBreakHandler();
BEGIN
    EnteringOverlay(OverlayID);
    Running := FALSE;
    ExitingOverlay(OverlayID);
END OurBreakHandler;



    (* Back out the installation. *)


PROCEDURE UnInstall();
BEGIN
    Running := FALSE;
END UnInstall;



PROCEDURE StartUp();
VAR
    S : ARRAY [0..81] OF CHAR;
    S1 : ARRAY [0..1] OF CHAR;
BEGIN
    SetString(S,"Installing Kitten.   (Run with Alt-P.)");
    SetString(S1,"+");

    MessageBox(S,S1);
        (* Wait 2 seconds or until a key is pressed. *)
    Delay(200,ATestProcedure(Keyboard.KeyPress));
    Keyboard.FlushKeyboardBuffer();



    Running := FALSE;
    MemoryAlerts := FALSE;
    RequireEscape := FALSE;
    Interlock     := 0;
    LowSpeedCount := 0;      (* Run slowly when above 0. *)

        (* Stop if anything really bad happens. *)
    RegisterForNotices( AllOccasions,   NoticeFailure );
        (* Deny permission for dangerous actions. *)           
    RegisterForNotices(AllOccasions,Refuser);


    (* Install our keystroke handler into the keystroke handling chain.

        2-Mar-89  RSC  New paramters.
    *)

    InstallNewProcedure(ADR(Keyboard.GetAnyCode), PROC(MacroGetCode), ADR(OldGetCode));
    InstallNewProcedure(ADR(Keyboard.KeyPress),PROC(MacroKeyPress), ADR(OldKeyPress));
    InstallNewProcedure(ADR(Keyboard.BreakRequested),PROC(OurBreakRequested), ADR(OldBreakRequested));
    InstallNewProcedure(ADR(Keyboard.FlushKeyboardBuffer),MacroFlushKeyboardBuffer, ADR(OldFlushKeyboardBuffer));
    InstallNewProcedure(ADR( Keyboard.BreakHandler), OurBreakHandler, ADR(OldBreakHandler));

END StartUp;



BEGIN


    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), UnInstall );

    StartUp();

END Kitten.
