MODULE TLMouse;

(*  =========================================================================
    Last Edit : June 28, 1991 2:02PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Intercept and process mouse events.  Translate mouse events
        into keycodes to be processed by the rest of Time Line.  Use keycodes
        so that MACROS still works for mouse events.

        Possible events:

            MouseDown       - Left button pushed down
            MouseStillDown  - Left button down and held for a multiple of
                              "RepeatRate", or down and moved (X,Y change).
            MouseUp         - Left button released.
            MouseDouble     - Left button released again at the same point
                              as the most recent release, and within a small
                              period of time ("DoubleClickRate").

            All events are followed by screen X and Y, X is 0-79, Y is 0-49.

            Screen Coordinates are <Row><Col>, each one byte, each
            computed as (# + "0").  Sow, row 5 column 3 is "53".  This
            makes all 50 rows and 80 cols printable ASCII chars, the kind
            that MACROS will like (and not think are his weird keys).


    MODIFICATION HISTORY:

     8-Nov-89 RSC First version.
    11-Dec-89 RSC Support Down events.
    14-Dec-89 RSC Continue to work on cleaning up the functionality.
    18-Dec-89 RSC/AJL/JKS much needed cleanup of the state machine and
                  interrupt facility.
    19-Dec-89 RSC Speedups, misc. tiny improvements.
    22-Dec-89 RSC Increase repeat rate initial delay.
                  Cancel "Mouse Ahead" when receiving a First Down message,
                  because we know that, if any double clicks were done,
                  they were done without us waiting for events.  This is
                  because we expect doubles to be heard perhaps while we
                  are processing the down returned as a MouseDown code,
                  but we do not allow pre clicking while the program is not
                  waiting for codes.  Also cancel when we get a Neutral
                  event, because the client did a silly transition (for
                  example, an UP when we were in Neutral state).

                  So, the conditions which we cancel all "Mouse Ahead" are
                  when we:

                        > Start to listen to events when the last event
                          heard was "Neutral" or "MouseDouble" (because
                          we are NOT in the midst of a mouse transaction)

                        > Get a "real" keyboard keystroke.  This prevents
                          crazy stuff like PRESS-F0-RELEASE.

                        > Receive a pending FirstDown message, BEFORE we
                          return it to the application.  This includes
                          Down-And-Drag (which I get as FirstDowns).

                        > Receive a Neutral message, meaning that somehow
                          the mouse is now out-of-synch with us.

        Dec-28-89 JES   Commented out the FlushBuffer calls when we
                        receive a neutral message. They were causing
                        us to lose events in the queue.

         3-Jan-90 RSC   Rather than try to flush buffers, I keep track of
                        how OLD mouse events are.  If they are older than
                        some "reasonable" time (around 1-3 double click
                        times ago), ignore them.  This way we don't have
                        to worry about confusing the internals of the state
                        machine or of the interupt handler.  It may be faster
                        as well.

         4-Jan-90 RSC   Intercept screen IO so that when recursive calls to
                        Kbio.GetAnyCode do screen writing (like the Journal
                        hot key), we can turn off the mouse cursor.

        17-Jan-90 RSC   As per bug # 2045, sometimes when we are recursive
                        in Kbio.GetAnyCode, the mouse cursor stops responding.
                        This turned out to be a result of calling Keyboard.
                        GetAnyCode, who calls KeyPress in a loop and, when
                        KeyPress returns TRUE, calls the BIOS to get the code.
                        Since KeyPress calls us, we said "Yep, event available".
                        but actually an event was not available from the BIOS.

        27-Jun-91 RSC   Microsoft Mice now can put up a software arrow
                        cursor that looks great, but interferes with VIDEO
                        memory managed by TLVIDMEM.  I now manage the cursor
                        myself down in MouseInt.  Added support for it here.

        05-Sep-91 LAA   Misc. fixes attempting to get the mouse to work
                        consistently.  Looks like the problem was really in
                        the mouse drivers.
        23-Sep-91 LAA   We've decided to tolerate the incompatibility of
                        TLVIDMEM and the Microsoft mouse driver, since this
                        new scheme of handling the cursor ourselves also
                        doesn't reliably work with the MS mouse driver.
                        Replaced all occurances of CursorOn with ShowCursor,
                        and of CursorOff with HideCursor.
        26-Sep-91 LAA   Removed the call to SoftwareReset since running
                        Windows seems to make the mouse hang unless you do
                        a hard reset.
    =========================================================================
*)


FROM Codes      IMPORT
    (* TYPE *)      ACode;

FROM Dialog     IMPORT
    (* PROC *)      Message;

FROM Kbio       IMPORT
    (* TYPE *)      ascreenx, ascreeny,
    (* VAR  *)      maxrow;

IMPORT Kbio;
IMPORT Keyboard;

FROM Keyboard   IMPORT
    (* TYPE *)      AYesNoProcedure, AGetCodeProcedure, AServiceProcedure,
    (* PROC *)      FlushKeyboardBuffer, GetAnyCode, KeyPress;

FROM Keys       IMPORT
    (* CONST *)     MouseDown, MouseStillDown, MouseUp, MouseDouble;

FROM LStrings   IMPORT
    (* PROC *)      SetString, CtoS, ConcatLS, ConcatS, StoC, LengthOf;

FROM LMouse     IMPORT
    (* TYPE *)      Button, ButtonSet, Event, EventSet, EventHandler,
    (* VAR *)       DriverInstalled,
    (* PROC *)      FlagReset, HideCursor, ShowCursor,
                    SetHorizontalLimits, SetVerticalLimits,
                    SetEventHandler, GetPosBut, SoftwareReset,
                    SetCursorPos, SetTextCursor,
                    SetSpeedThreshold;

FROM Menus      IMPORT
    (* PROC *)      WordNumber;

FROM MsgFile    IMPORT
    (* PROC *)      GetMessage;

FROM Mouse      IMPORT
    (* TYPE *)      AMouseTime,
    (* VAR *)       RepeatRate, DoubleClickRate,
    (* PROC *)      MousePresent, CancelDoubleClick;

FROM MouseInt   IMPORT
    (* PROC *)      MouseHandler;

FROM MStates    IMPORT
    (* TYPE *)      AMouseState,
    (* PROC *)      GetNewMouseState;

FROM Notices    IMPORT
    (* TYPE *)      AnOccasion, AStep,
    (* PROC *)      RegisterForNotices;

FROM Overlays   IMPORT
    (* TYPE *)      AnOverlayID,
    (* PROC *)      ImALockedOverlay, InstallNewProcedure;

FROM OvTree     IMPORT
    (* TYPE *)      AnOverlayProc;

FROM ParmLine   IMPORT
    (* PROC *)      GetOption;

FROM RTSMain    IMPORT
    (* PROC *)      InstallTermProc;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS, SETREG, GETREG, SWI, AX, BX, CX, DX, ADR;

FROM Video      IMPORT
    (* TYPE *)      AVideoOutputProc, AVideoPutAttributeProc,
                    AVideoCaptureProc, A2BoolProc,
    (* PROC *)      PutAttribute, PutStringWithAttribute, GetImageLine,
                    PutImageLine;





CONST
    DesiredEventSet     = EventSet{LeftDown,LeftUp,Motion};
    PixelsPerChar       = 8;      (* reported position is this * <col/row> *)
    ModuleNumber        = 9900;

VAR
    OverlayID           : AnOverlayID;
    OldMaxRow           : CARDINAL;
    MouseRunning        : BOOLEAN;


(* *****  MODULE KeyboardEmulator  *****

   Here we emulate the procedures Keyboard.GetAnyCode(), Kbio.PushCode()
   and Kbio.PopCode().

   PushCode and PopCode mimic what Kbio's routines PushCode and PopCode do.
   Unfortunately, we cannot use Kbio's, because then the codes would come
   from Kbio.GetAnyCode() and not Keyboard.GetAnyCode().  Since MACROS
   steal the Keyboard.GetAnyCode() vectors, we must return chars through
   there, or else our mouse strokes are not recordable via macros.

   For the same reason, we steal the Keyboard.GetAnyCode() vector, so we
   can return the codes we push.  No codes pushed?  Call the prior vector.

   Note that the fragile nature of the push stack suggests that we must not
   race ahead, pushing codes that the rest of the product cannot respond to
   right away.  This stack is built specificly to handle the cases of:

    1) SingleClick pushes 3 codes (Click, X, Y)
    2) DoubleClick pushes 1 code while TL may not be looking for input.

   Note that, with the exception of case (2), we MUST NOT respond to mouse
   events when TL is not looking for keystrokes, or we may overflow this
   buffer.
*)
MODULE KeyboardEmulator;

IMPORT  Kbio;
IMPORT  Keyboard;

IMPORT
    (* CONST *) MouseDown, MouseUp, MouseStillDown, MouseDouble,
    (* VAR  *)  RepeatRate, DoubleClickRate, 
    (* TYPE *)  ADR, AGetCodeProcedure, AYesNoProcedure,
                ACode, AMouseTime, ascreenx, ascreeny, AMouseState,
    (* PROC *)  InstallNewProcedure, KeyPress, CtoS, 
                ShowCursor, HideCursor, CancelDoubleClick,
                GetNewMouseState, StealVideoVectors, ReplaceVideoVectors;

EXPORT
    (* VAR *)   AcceptingMouseKeys, MouseEventAcceptedAsOf;

TYPE
    AnEventPiece    = ( NoPiece, TheCode, TheX, TheY );

    AMouseEvent     = RECORD
        EventTime               : AMouseTime;
        EventState              : AMouseState;
        EventX                  : ascreenx;
        EventY                  : ascreeny;
    END;

    AMouseStateSet  = SET OF AMouseState;

CONST
    DownStates              = AMouseStateSet{ ClickedAndDown, DownOnce };
    DoubleClickStates       = AMouseStateSet{ ClickedAndDown, DoubleClicked };
    NeutralStates           = AMouseStateSet{ Neutral, DoubleClicked };

(*$A+*)
VAR
    OldKeyboardGetCode      : AGetCodeProcedure;
    OldKbioGetCode          : PROCEDURE () : ACode;
    OldKeyPress             : AYesNoProcedure;

    MouseEventAcceptedAsOf  : AMouseTime;
    NextRepeatTime          : AMouseTime;
    AcceptingMouseKeys      : CARDINAL;

    EventCode               : ACode;
    EventCodes              : ARRAY AMouseState OF ACode;

    SavedState              : AMouseState;
    Event                   : AMouseEvent;

    EventPieceReturned      : AnEventPiece;
    EventAvailable          : BOOLEAN;
    IgnoreDoubleClick       : BOOLEAN;
(*$A=*)



PROCEDURE CodeIsWaiting() : BOOLEAN;
VAR
    SystemTime[0:046CH] : AMouseTime;    (* 18-Dec-89 RSC as per AJL. *)
    TimeNow             : AMouseTime;
    ReturnIsAllowed     : BOOLEAN;      (* If FALSE, we will not report the (undesired) event *)
BEGIN
    IF (NOT EventAvailable) THEN
        REPEAT
            ReturnIsAllowed := TRUE;

            WITH Event DO
                EventAvailable := GetNewMouseState( EventState,
                                                    EventX,
                                                    EventY,
                                                    EventTime );
            END;

            IF (EventAvailable) THEN
                WITH Event DO
                    (* If we want to ignore double clicks,
                          If we got a double click event, ignore it.
                          If we got a Down, reset the double click flag, for
                             we only allow SETTING the "I hate double clicks"
                             flag AFTER PROCESSING a down or Click.
                    *)
                    IF (IgnoreDoubleClick) THEN
                        EventAvailable    := (NOT (EventState IN DoubleClickStates));
                        IgnoreDoubleClick := (EventState <> DownOnce);
                    END;

                    EventCode   := EventCodes[EventState];

                    IF (EventState IN DownStates)   AND
                       (SavedState IN DownStates)   THEN
                        EventCode := MouseStillDown;
                    ELSE
                        SavedState := EventState;
                    END;

                    (* 22-Dec-89 RSC Increase initial delay for subsequent
                                     RepeatRate delays.  Since this is a LONGINT,
                                     it can afford to become negative during the
                                     duration calculation.
                    *)
                    IF (EventState IN DownStates) THEN
                        NextRepeatTime := EventTime + DoubleClickRate;
                    END;

                    (* If the state machine returned a "Neutral" event, we don't
                       want to report an event back to Time Line, but we do want
                       the saving of the event state for future reference (to not
                       report StillDowns and such).   3-Jan-89.
                    *)
                    IF ((EventState = Neutral) OR
                        (EventTime < MouseEventAcceptedAsOf)) THEN
                        ReturnIsAllowed := FALSE;
                    END;
                END;

            ELSE

                (* Manage Press-And-Hold.

                   Save copies of the event variables in order to not depend
                   on GetNewMouseState preserving the variables.
                *)
                WITH Event DO
                    IF (SavedState IN DownStates)           THEN
                        TimeNow := SystemTime;     (* Boy, I hate this.... *)
                        IF ((TimeNow - NextRepeatTime) >= RepeatRate) THEN
                            NextRepeatTime  := TimeNow;   (* Reset Timer *)
                            EventTime       := NextRepeatTime;
                            EventCode       := MouseStillDown;
                            EventAvailable  := TRUE;
                        END;
                    END;
                END;
            END;
        UNTIL (ReturnIsAllowed);
    END;

    RETURN EventAvailable;

END CodeIsWaiting;




PROCEDURE GetWaitingCode() : ACode;
CONST
    AsciiZero       = ORD("0");
VAR
    CodeToReturn    : ACode;
BEGIN
    INC(EventPieceReturned);

    CASE EventPieceReturned OF
        TheCode : CodeToReturn   := EventCode;
      | TheX    : CodeToReturn   := Event.EventX + AsciiZero;
      | TheY    : CodeToReturn   := Event.EventY + AsciiZero;
                  EventAvailable := FALSE;
                  EventPieceReturned := NoPiece;  (* not yet... *)
    ELSE
        HALT;   (* not possible?? *)
    END;

    RETURN CodeToReturn;

END GetWaitingCode;






(*
    This is the KBIO version of GetAnyCode.  We use it just to tell us
    to allow interrupts from the mouse.  Don't use it to return keys,
    for then MACROS will not work.

    Watch out for recursion.
*)
PROCEDURE OurKbioGetCode() : CARDINAL;
VAR
    CodeToReturn        : CARDINAL;

    PROCEDURE SetTime();
    VAR
        SystemTime[0:046CH] : AMouseTime;
    BEGIN
        (* 3-Jan-89 RSC  Rather than flushing the mouse queue,
                         Monitor the time of events.  Ignore any events
                         that came in a while ago.  What is a "while ago"?
                         well, try a couple of double click intervals.
                         This will allow a LITTLE "Mouse Ahead", but not
                         a lot.  Flushing seems to just confuse things.

                         We only want to reset this time when we are waiting
                         for the start of a mouse transaction, ie when the
                         last event processed was a double click or a
                         neutral.
        *)
        IF (SavedState IN NeutralStates) THEN
            MouseEventAcceptedAsOf := (SystemTime -
                                       (DoubleClickRate + DoubleClickRate)
                                      );
        END;
    END SetTime;
BEGIN
    IF (EventPieceReturned > NoPiece) THEN
        CodeToReturn := OldKbioGetCode(); (* Event waiting *)
    ELSE
        INC(AcceptingMouseKeys);
        IF (AcceptingMouseKeys = 1) THEN
            ShowCursor();
            StealVideoVectors();        (* We may go into recursion *)
        END;
        SetTime();
        CodeToReturn       := OldKbioGetCode();
        IF (AcceptingMouseKeys = 1) THEN
            HideCursor();
            ReplaceVideoVectors();      (* We are not in recursion *)
        END;
        DEC(AcceptingMouseKeys);
    END;

    RETURN CodeToReturn;

END OurKbioGetCode;




(*
    This is the KEYBOARD version of GetAnyCode.  Here is where we return
    keys up the chain so that MACROS can record them.
*)
PROCEDURE OurKeyboardGetCode() : CARDINAL;
VAR
    CodeToReturn    : CARDINAL;
BEGIN
    REPEAT
    UNTIL OurKeyPress();

    IF (CodeIsWaiting()) THEN
        CodeToReturn := GetWaitingCode();
    ELSE
        CodeToReturn := OldKeyboardGetCode();
        (* 3-Jan-89 RSC Removed flushing of mouse buffer. *)
    END;

    RETURN CodeToReturn;

END OurKeyboardGetCode;




PROCEDURE OurKeyPress() : BOOLEAN;
VAR
    KeyPresent  : BOOLEAN;
BEGIN

    KeyPresent := (CodeIsWaiting() OR
                   OldKeyPress());    (* The KEYBOARD version!! *)

    RETURN KeyPresent;

END OurKeyPress;






PROCEDURE OurCancelDoubleClick();
BEGIN
    IgnoreDoubleClick := TRUE;
END OurCancelDoubleClick;







BEGIN

    AcceptingMouseKeys      := 0;
    IgnoreDoubleClick       := FALSE;
    EventAvailable          := FALSE;
    SavedState              := Neutral;
    EventPieceReturned      := NoPiece;

    EventCodes[ Neutral        ] := 0;           (* Should not get this *)
    EventCodes[ DownOnce       ] := MouseDown;
    EventCodes[ ClickedOnce    ] := MouseUp;
    EventCodes[ ClickedAndDown ] := MouseDown;
    EventCodes[ DoubleClicked  ] := MouseDouble;

    InstallNewProcedure(ADR(Keyboard.GetAnyCode), PROC(OurKeyboardGetCode), ADR(OldKeyboardGetCode));
    InstallNewProcedure(ADR(Kbio.GetAnyCode), PROC(OurKbioGetCode), ADR(OldKbioGetCode));
    InstallNewProcedure(ADR(KeyPress),PROC(OurKeyPress), ADR(OldKeyPress));

    InstallNewProcedure(ADR(CancelDoubleClick),PROC(OurCancelDoubleClick), NIL);

END KeyboardEmulator;







MODULE VideoIntercepts;

    (* 4-Jan-90 RSC Added this submodule. *)

    (* Video Intercepts - Because we turn on the mouse cursor in GetAnyCode,
                          and because other procs have stolen GetAnyCode,
                          and becuase these other procs can do screen I/O
                          (such as the journal list), we must shut down
                          the mouse cursor while doing screen IO.
    *)

    (* Ok, I've done some dangerous things in my time, but this one takes
       the cake.  This is the only way I can figure out to steal the video
       vectors.  Time Line starts with Clean Video.  Then it may switch
       to fast video.  InitializeVideoHardware doesn't properly steal
       vectors, so you can't expect Overlays to keep up.  We can't yet
       tell Overlays which overlay we are when asking to steal vectors,
       so we cannot delay stealing vectors.  Instead, I steal by hand,
       each time I need them.
    *)

IMPORT
    (* TYPE *)  AVideoOutputProc, AVideoPutAttributeProc, AVideoCaptureProc,
                ADDRESS, ADR, AMouseTime, AServiceProcedure, A2BoolProc,
    (* VAR  *)  AcceptingMouseKeys, MouseEventAcceptedAsOf,
    (* PROC *)  InstallNewProcedure, HideCursor, ShowCursor,
                PutAttribute, PutStringWithAttribute, GetImageLine,
                FlushKeyboardBuffer, PutImageLine;

EXPORT
    (* PROC *)  StealVideoVectors, ReplaceVideoVectors;

VAR
    OldPutStringWithAttribute   : AVideoOutputProc;
    OldPutAttribute             : AVideoPutAttributeProc;
    OldGetImageLine             : AVideoCaptureProc;
    OldPutImageLine             : AVideoCaptureProc;
    OldFlushKeyboardBuffer      : AServiceProcedure;

    VectorsStolen               : BOOLEAN;



PROCEDURE XPutStringWithAttribute ( VAR s : ARRAY OF CHAR;
                                        x : CARDINAL;
                                        y : CARDINAL;
                                        a : BITSET );
BEGIN
    HideCursor();
    OldPutStringWithAttribute( s, x, y, a );
    ShowCursor();
END XPutStringWithAttribute;







PROCEDURE XPutAttribute ( x     : CARDINAL;
                          y     : CARDINAL;
                          Count : CARDINAL;
                          a     : BITSET );
BEGIN
    HideCursor();
    OldPutAttribute( x, y, Count, a );
    ShowCursor();
END XPutAttribute;




PROCEDURE XGetImageLine( x      : CARDINAL;
                         y      : CARDINAL;
                         Count  : CARDINAL;
                         Line   : ADDRESS );
BEGIN
    HideCursor();
    OldGetImageLine( x, y, Count, Line );
    ShowCursor();
END XGetImageLine;





PROCEDURE XPutImageLine( x      : CARDINAL;
                         y      : CARDINAL;
                         Count  : CARDINAL;
                         Line   : ADDRESS );
BEGIN
    HideCursor();
    OldPutImageLine( x, y, Count, Line );
    ShowCursor();
END XPutImageLine;




(* flush all mouse ahead.
*)
PROCEDURE XFlushKeyboardBuffer();
VAR
    SystemTime[0:046CH] : AMouseTime;
BEGIN
    MouseEventAcceptedAsOf := SystemTime;
    OldFlushKeyboardBuffer();
END XFlushKeyboardBuffer;




PROCEDURE StealVideoVectors();
BEGIN

    (* Reset these items by hand.  This is fairly unstable, as Overlays
       has no Idea we are doing this, and if we were to unload unexpectedly
       they might not be put back.  Fortunately, we are a permenant overlay
       and will only shut down as Time Line shuts down.

       ReplaceVideoVectors must be called to replace these stolen vectors.
    *)
    IF (VectorsStolen) THEN
        HALT;   (* Argh!  stolen already? *)
    END;

    OldPutStringWithAttribute := PutStringWithAttribute;
    OldPutAttribute           := PutAttribute;
    OldGetImageLine           := GetImageLine;
    OldPutImageLine           := PutImageLine;

    PutStringWithAttribute := XPutStringWithAttribute;
    PutAttribute           := XPutAttribute;
    GetImageLine           := XGetImageLine;
    PutImageLine           := XPutImageLine;
    VectorsStolen          := TRUE;

END StealVideoVectors;



PROCEDURE ReplaceVideoVectors();
BEGIN

    (* This is highly dangerous.  Kids, never do this at home!

        StealVideoVectors must have been called before this!
    *)

    IF (NOT VectorsStolen) THEN
        HALT;   (* Argh!  didn't call StealVectors? *)
    END;

    PutStringWithAttribute := OldPutStringWithAttribute;
    PutAttribute           := OldPutAttribute;
    GetImageLine           := OldGetImageLine;
    PutImageLine           := OldPutImageLine;
    VectorsStolen          := FALSE;

END ReplaceVideoVectors;



BEGIN

    VectorsStolen          := FALSE;
    InstallNewProcedure(ADR(FlushKeyboardBuffer), PROC(XFlushKeyboardBuffer), ADR(OldFlushKeyboardBuffer));

END VideoIntercepts;










(* When the customer wants to Exit-From-Dos, we need to shut off the
    mouse driver so as not to process interrupts, and then re-setup
    the mouse when they return.
*)
PROCEDURE CatchNotices(     Occasion    : AnOccasion;
                            Step        : AStep;
                            Context     : ADDRESS   ) : BOOLEAN;
BEGIN

    IF (Step = BeforeActing) THEN
        ShutDownMouse();
    ELSIF (Step = AfterActing) OR (Step = FailureToAct) THEN
        IF (TheCatIsAway()) THEN        (* Mouse still around?? *)
            SetUpMouse( OldMaxRow );
        END;
    END;

    RETURN TRUE;

END CatchNotices;



(* Is the mouse ready to play with us?
*)
PROCEDURE TheCatIsAway() : BOOLEAN;
VAR
    Status          : INTEGER;
    ButtonCount     : CARDINAL;
    MouseWillPlay   : BOOLEAN;
BEGIN
    MouseWillPlay := DriverInstalled;

    IF (MouseWillPlay) THEN
        FlagReset( Status, ButtonCount );
        MouseWillPlay := (Status = -1);
    END;

    RETURN MouseWillPlay;

END TheCatIsAway;





(* Stolen from Mouse.Def *)
PROCEDURE OurMousePresent() : BOOLEAN;
BEGIN
    RETURN MouseRunning;
END OurMousePresent;







(* Called when overlay starts, AND when BACK-FROM-EXIT-TO-DOS message
   received.  Some of these are defined as the Microsoft Standard, 
   but we found that MouseSystems mice do not follow these standards,
   and so we must explicitly set up the mouse.
*)
PROCEDURE SetUpMouse( MaxRow    : CARDINAL );
CONST
    ANDThis             = 0FFFFH;   (* Keep the byte & attribute *)
    XORThis             = 07700H;   (* But flip the attribute (high byte) *)
BEGIN


    SetTextCursor( 0,         (* Software cursor *)
                   ANDThis,   (* AND this to the byte. *)
                   XORThis ); (* XOR this to the byte. *)

    (* Big screens (DISPLAY=COMPRESSED) seem to allow the mouse cursor to
       disappear off the screen.  Always bound the mouse to the visible area.
    *)
    SetVerticalLimits( 0, MaxRow * PixelsPerChar );

    (* Set the initial position to the middle of the screen.
    *)
    SetCursorPos( 39 * PixelsPerChar, (maxrow DIV 2) * PixelsPerChar );

    (* Set the speed threshold at which we get twice as many interrupts.
       We don't want this effect, so make it huge.
    *)

    SetSpeedThreshold(10000);   (* Page 602, Adv MSDOS 2nd addition *)

    SetEventHandler( EventSet(BITSET{0..4}), MouseHandler );

    ShowCursor();                                              (* 23-Sep-91 *)

    MouseRunning := TRUE;

END SetUpMouse;







(* Called when overlay exits, AND when EXIT-TO-DOS message received.
*)
PROCEDURE ShutDownMouse();
VAR
    TerminateProc[0:88H]    : PROC;
    Copyright               : ARRAY[0..49] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    (* We must UN-INSTALL our handler, or we will still get requests after
       the code has been overwritten by some other poor shmuck's program.
       But, never unload more than once.
    *)

    IF (MouseRunning) THEN
        MouseRunning := FALSE;
        TerminateProc();    (* "She cut off their tails with a carving knife" *)
    END;
END ShutDownMouse;



PROCEDURE SetSpeedThresholds();
VAR
    Option,
    s       : ARRAY [0..255] OF CHAR;
    Found   : BOOLEAN;

    PROCEDURE SetOne(     OptionNumber  : CARDINAL;
                      VAR Rate          : AMouseTime );
    VAR
        C,
        i       : CARDINAL;
    BEGIN
        WordNumber( Option, OptionNumber, s );
        IF (LengthOf(s) > 0) THEN
            i := 1;
            C := StoC( s, i );
            IF (C > 0) AND (C < 24) THEN
                Rate := VAL(AMouseTime,C);
            END;
        END;
    END SetOne;

BEGIN

    GetMessage(ModuleNumber + 1, s );    (* "MOUSE" *)
    GetOption( s, Found, Option );

    IF (Found) THEN
        SetOne( 1, DoubleClickRate );
        SetOne( 2, RepeatRate      );
    END;

END SetSpeedThresholds;




BEGIN

    MouseRunning := FALSE;
    IF (TheCatIsAway()) THEN
        SetSpeedThresholds();
        SetUpMouse( maxrow );
        OldMaxRow  := maxrow;
        InstallNewProcedure(ADR(MousePresent), PROC(OurMousePresent), NIL);
        RegisterForNotices( ExitToDOS, CatchNotices );
        OverlayID := ImALockedOverlay( AnOverlayProc(NIL), ShutDownMouse );
    END;

END TLMouse.

