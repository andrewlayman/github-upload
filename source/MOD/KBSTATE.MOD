    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

(*----------------------------------------------------------------------------
    MODIFICATION HISTORY

    12/03/86 LAA    In ShowKbLights, display the Break state unconditionally.
                    Get the string to be used as the Break light the first
                    time ShowKbLights is called, because we can't call 
                    GetMessage during the CtrlBreakProcedure of Kbio.
    05/14/87 AJL  - Use the Keyboard module.
                  - Move the installation of Lights inside the FirstTime
                    test.
                  - Treat the Break test equally with other lights.
     1/20/88 AJL  - Display these keyboard lights in videowarnig.
    20-Jul-89 RSC - Don't init unless we have initilized Time Line a little.
                    This is because the MsgFile may not have been opened.
    05-Aug-89 WKH - Initial OS/2 edits.  Replace CheckKbState with OS/2 API
                    equivalent.
    15-Sep-89 RSC - Fix the min size of the lights.
    20-Sep-89 RSC - Initialize lights to NIL to prevent the infinite
                    FatalError recursion problem.  Pass lights by VAR to the
                    MakeOneLight procedure.
----------------------------------------------------------------------------*)
 
IMPLEMENTATION MODULE KbState;

(*<OS2
FROM KbdCalls               IMPORT 
    (* TYPE *)                  KbdStateType,
    (* PROC *)                  KbdGetStatus;
OS2>*)

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode;

FROM Keyboard               IMPORT
    (* PROC *)                  BreakRequested;
IMPORT Keyboard;

FROM Lights                 IMPORT
    (* TYPE *)                  ALight,
    (* VAR *)                   ActiveLightRegion,
    (* PROC *)                  InstallLight, DisplayLight;

FROM LStrings               IMPORT 
    (* PROC *)                  SetString, Fill, SubStr, Copy, LengthOf;

FROM MsgFile                IMPORT GetMessage;

FROM Paranoia               IMPORT
    (* TYPE *)                  AProgramState,
    (* VAR *)                   ProgramState;

FROM SYSTEM                 IMPORT CODE, GETREG, WORD, AX, SIZE;


CONST
      ModuleNumber = 4200;   (* For GetMessage *) 


    (*  These codes are for bits within the KB state flag returned
        from the IBM ROM bios. *)
CONST
    KbScrollState    = 4;
    KbNumLockState   = 5;
    KbCapsState      = 6;

    (*  These constants control the placement of lights on the screen  *)

CONST
    CapsLightPriority       = 10;
    NumLightPriority        = 20;
    ScrollLightPriority     = 30;
    BreakLightPriority      = 40;

VAR
    ScrollLight             : ALight;
    NumLight                : ALight;
    CapsLight               : ALight;
    BreakLight              : ALight;
    PreviousKbState         : BITSET;
    PreviousBreakState      : BOOLEAN;
    FirstTime               : BOOLEAN;
    BreakString             : ARRAY [0..21] OF CHAR;
    ScrollString            : ARRAY [0..21] OF CHAR;
    NumString               : ARRAY [0..11] OF CHAR;
    CapsString              : ARRAY [0..11] OF CHAR;







PROCEDURE ScrollMode(): BOOLEAN;
BEGIN
    RETURN Keyboard.ScrollMode();
END ScrollMode;




(*<DOS*)
PROCEDURE CheckKbState(VAR KbState:BITSET);
VAR
    x : WORD;
BEGIN
    CODE ( 1EH,            (* PUSH DS         Save Data Segment       *)
           0B8H, 40H, 00,  (* MOV AX,  0040   Get BIOS Data Segment   *)
           08EH, 0D8H,     (* MOV DS,  AX                             *)
           0A0H, 17H, 00H, (* MOV AL, [17]    Load Kb Flags.          *)
           1FH   );        (* POP DS          Restore data segment    *)
    GETREG(AX,x); 
    KbState := BITSET(x);

END CheckKbState;
(*DOS>*)



(*<OS2
PROCEDURE CheckKbState(VAR KbState : BITSET);

VAR
    StatusRec : KbdStateType;
    err       : CARDINAL;

BEGIN

    StatusRec.size := SIZE(KbdStateType);
    err            := KbdGetStatus( StatusRec, 0);
    KbState        := BITSET(StatusRec.shiftState);
END CheckKbState;
OS2>*)


PROCEDURE DisplayCapsLight();

VAR
    KbSet                   : BITSET;
    S                       : ARRAY [0..10] OF CHAR;

BEGIN

    CheckKbState(KbSet);
    IF (KbCapsState IN KbSet) THEN
        Copy(CapsString, S);
    ELSE
        Fill(S, " ", 0);
    END;
    DisplayLight(CapsLight, S, videowarning);

END DisplayCapsLight;





PROCEDURE DisplayNumLight();

VAR
    KbSet                   : BITSET;
    S                       : ARRAY [0..10] OF CHAR;

BEGIN

    CheckKbState(KbSet);
    IF (KbNumLockState IN KbSet) THEN
        Copy(NumString, S);
    ELSE
        Fill(S, " ", 0);
    END;
    DisplayLight(NumLight, S, videowarning);

END DisplayNumLight;




PROCEDURE DisplayScrollLight();

VAR
    KbSet                   : BITSET;
    S                       : ARRAY [0..20] OF CHAR;

BEGIN

    CheckKbState(KbSet);
    IF (KbScrollState IN KbSet) THEN
        Copy(ScrollString, S);
    ELSE
        Fill(S, " ", 0);
    END;
    DisplayLight(ScrollLight, S, videowarning);

END DisplayScrollLight;




PROCEDURE DisplayBreakLight( Break : BOOLEAN);

VAR
    s                       : ARRAY [0..20] OF CHAR;

BEGIN                       (* DisplayBreakLight *)

    IF (Break) THEN
        Copy(BreakString, s);
    ELSE
        Fill(s, " ", 0);
    END;
    DisplayLight(BreakLight, s, videowarning);

END DisplayBreakLight;







PROCEDURE ShowKbLights();

VAR
    KbState                 : BITSET;
    Break                   : BOOLEAN;

    PROCEDURE MakeOneLight(     Phrase      : CARDINAL;
                            VAR String      : ARRAY OF CHAR;
                                Priority    : CARDINAL;
                            VAR Light       : ALight );
    VAR
        i   : CARDINAL;
    BEGIN
        GetMessage(ModuleNumber + Phrase, String);
        i := LengthOf(String);
        InstallLight(ActiveLightRegion, Priority, i, i, Light);
    END MakeOneLight;

BEGIN                       (* ShowKbLights *)

        (*  This is here because we can't call GetMessage from the CtrlBreak
            procedure, because interrupts are disabled.                     *)

    IF (FirstTime) THEN
        IF (ProgramState <= RootInit) THEN
            RETURN;     (* RSC 20-Jul-89 MsgFile may not be running yet. *)
        END;
        FirstTime := FALSE;

        (* RSC 15-Sep-89 *)
        MakeOneLight( 3, ScrollString,  ScrollLightPriority,    ScrollLight );
        MakeOneLight( 4, NumString,     NumLightPriority,       NumLight );
        MakeOneLight( 5, CapsString,    CapsLightPriority,      CapsLight );
        MakeOneLight( 6, BreakString,   BreakLightPriority,     BreakLight );
    END;

    CheckKbState(KbState);
    KbState := KbState * {KbScrollState, KbNumLockState, KbCapsState};
    IF KbState <> PreviousKbState THEN
        DisplayScrollLight();
        DisplayNumLight();
        DisplayCapsLight();
    END;
    PreviousKbState := KbState;

        (* Because Break handling can cause the Break bit to flicker
           on and off, it is important that the Break display be based
           on the exact same value that made us decide to display the
           light.  Else, we could test once, get a FALSE, go to display
           the light, who, if he tests again, could get a TRUE.  Then we
           might store the FALSE, or maybe the TRUE.
           *)
    Break := BreakRequested();
    IF (Break <> PreviousBreakState) THEN
        DisplayBreakLight(Break);
        PreviousBreakState := Break;
    END;
    
END ShowKbLights;




BEGIN
    SetString(BreakString,  "*");
    SetString(ScrollString, "*");
    SetString(NumString,    "*");
    SetString(CapsString,   "*");
    PreviousKbState         := {};
    PreviousBreakState      := FALSE;
    FirstTime               := TRUE;
    ScrollLight             := ALight(NIL);
    NumLight                := ALight(NIL);
    CapsLight               := ALight(NIL);
    BreakLight              := ALight(NIL);
END KbState.
