    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE Keyboard;

    (*  MODIFICATION HISTORY
        31-Dec-87 LAA  -BreakHandler procedure variable was never being called
                        in Ctrl-Break processing.
        12-Feb-88 AJL  -Added a BreakInterlock to prevent our procedures
                        from doing any DOS actions from within the Break
                        handler, though, frankly, I don't see how they could.   
        30-Sep-88 WKH  -Now all keyboard processing is done directly via BIOS
                        and not DOS.  Also fixes problem of Ctrl-C wasting
                        the screen.
        21-Oct-88 WKH  -Wipe out the halt call for stacks of Control-Breaks
        06-Aug-89 WKH  -Initial OS/2 edits.
         5-Oct-90 AJL  -Made Ctrl-Enter return same code as F10 (ExitKey).
    *)

FROM Keys  IMPORT
    (* CONST *)    CancelKey, ExitKey;

(*<DOS*)
IMPORT Devices;
(*DOS>*)

(*<OS2
FROM KbdCalls               IMPORT
                                KbdGetStatus, KbdStateType,
                                KbdCharIn, CharDataType,
                                KbdFlushBuffer,
                                KbdPeek, FinalChar;

FROM Signals                IMPORT
                                DosSetSigHandler;
OS2>*)

IMPORT SYSTEM;

FROM SYSTEM IMPORT
    (* TYPE *)     WORD, ADDRESS, BYTE,
    (* CONST *)    AX, BX, CX, DX,
    (* PROC *)     SETREG, GETREG, SWI, DOSCALL,
                   ADR, SIZE, CODE;


CONST
    DOSCall              =  21H;
    BIOSKeyboardCall     =  16H;
    DeathKey             = 255;
    EnhancedKeyboardBit  = 4;
    OldGetKeyCall        = 0000H;
    NewGetKeyCall        = 1000H;
    OldCheckKeyCall      = 0100H;
    NewCheckKeyCall      = 1100H;
    CtrlEnter            = 10;        (* Code for the Ctrl-Enter key. *)



    (*  These codes are for bits within the KB state flag returned
        from the IBM ROM bios. *)
CONST
    KbScrollState    = 4;
    KbNumLockState   = 5;
    KbCapsState      = 6;


(*<DOS*)
VAR
    BIOSStuff[0040H:0096H] : SET OF [0..7];   (* BIOS data area for kbd detection *)
    DirectConsoleInput     : WORD;
    CheckInputStatus       : WORD;
(*DOS>*)
    


    (* EmergencyDump -- Dump the program. *)

PROCEDURE EmergencyDump;
CONST
    AUX = 3;
BEGIN
(*<DOS*)
        (* Close a spare file handle to make sure that we
           can open the dump file. *)
    SETREG(BX,AUX);      (* File handle for AUX device *) 
    SETREG(AX,3E00H);    (* Close function             *) 
    SWI(DOSCall);
        (* Dump *)
(*DOS>*)
    HALT;
END EmergencyDump;

(*<DOS*)
PROCEDURE XKeyPress(): BOOLEAN;
VAR
    StatusChar : CHAR;
BEGIN
        (* True if break requested or internal stack not empty. *)
    IF (BreakInterlock > 0) OR (BreakRequested()) THEN
        RETURN TRUE;
    END;
        (* Check if BIOS has anything for us. *)
    SETREG(AX, CheckInputStatus); 
    CODE(55H);               (* PUSH BP   *)
    SWI(BIOSKeyboardCall);
    CODE(05DH,               (* POP BP    *)
         0B8H, 000H, 000H,   (* MOV AX, 0 *)
         075H, 003H,         (* JNZ +3    *)
         0B8H, 001H, 000H);  (* MOV AX, 1 *)
    GETREG(AX, StatusChar); 
    RETURN (ORD(StatusChar) = 0);
END XKeyPress;
(*DOS>*)


(*<OS2
PROCEDURE XKeyPress() : BOOLEAN;

VAR
    err        : CARDINAL;
    charData   : CharDataType;

BEGIN
	(* True if break requested or internal stack not empty. *)
    IF (BreakInterlock > 0) OR (BreakRequested()) THEN
	    RETURN TRUE;
    END;

    err := KbdPeek ( charData, 0 );

    IF ( FinalChar IN charData.charState ) THEN
        RETURN TRUE;
    END;

    RETURN FALSE;
END XKeyPress;
OS2>*)

    (* FlushKeyboardBuffer -- Cancel any characters waiting on the
                              standard input device.  Does not affect
                              the Break state. *)
(*<DOS*)
PROCEDURE XFlushKeyboardBuffer;
VAR
    StatusChar : CHAR;
BEGIN
    IF (BreakInterlock = 0) THEN

            (* Eat any characters obtainable from BIOS. *)
        LOOP
            SETREG(AX, CheckInputStatus);        (* Is there a char?   *) 
            CODE(55H);               (* PUSH BP   *)
            SWI(BIOSKeyboardCall);
            CODE(05DH,               (* POP BP    *)
                 0B8H, 000H, 000H,   (* MOV AX, 0 *)
                 075H, 003H,         (* JNZ +3    *)
                 0B8H, 001H, 000H);  (* MOV AX, 1 *)
            GETREG(AX, StatusChar); 
            IF (StatusChar <> 0C) THEN
                EXIT;
            END;
            SETREG(AX, DirectConsoleInput);      (* Get the character. *) 
            CODE(55H);               (* PUSH BP *) 
            SWI(BIOSKeyboardCall);
            CODE(5DH);               (* POP BP  *)
        END;
    END;
END XFlushKeyboardBuffer;
(*DOS>*)

(*<OS2
PROCEDURE XFlushKeyboardBuffer();

VAR
    StatusChar : CHAR;
    err        : CARDINAL;

BEGIN
    IF (BreakInterlock = 0) THEN
	    (* Eat any characters obtainable from DOS. *)
	    err := KbdFlushBuffer ( 0 );
    END;
END XFlushKeyboardBuffer;
OS2>*)


    (*  GetAnyCode

        When a character has been typed, this routine returns it.
        If no character has been typed, this routine will wait
        until one is.

        If a Break has been requested, the special code CancelKey
        is returned instead of a character, the keyboard buffer is
        flushed of any following input, and the Break state is
        cleared.

        As coded here, it uses the KeyPress procedure to wait for
        a key to be pressed.

        This routine also handles processing the special character
        "LeadCode" and shifting the following character into the
        range 256..511.

    *)


PROCEDURE XGetAnyCode (): CARDINAL;

VAR
    Code     : CARDINAL;
    s                       : ARRAY [0..20] OF CHAR;
    changed                 : BOOLEAN;
    P                       : ADDRESS;


(*<DOS*)
    PROCEDURE ReadCARDINAL(): CARDINAL;

    CONST
        F10                 = BYTE(044H);
        F11                 = BYTE(085H);
        F12                 = BYTE(086H);
        SF10                = BYTE(05DH);
        SF11                = BYTE(087H);
        SF12                = BYTE(088H);
        CF10                = BYTE(067H);
        CF11                = BYTE(089H);
        CF12                = BYTE(08AH);
        AF10                = BYTE(071H);
        AF11                = BYTE(08BH);
        AF12                = BYTE(08CH);
        NewInsert           = WORD(52E0H);
        NewHome             = WORD(47E0H);
        NewPgUp             = WORD(49E0H);
        NewDelete           = WORD(53E0H);
        NewEnd              = WORD(4FE0H);
        NewPgDn             = WORD(51E0H);
        NewUp               = WORD(48E0H);
        NewLeft             = WORD(4BE0H);
        NewDown             = WORD(50E0H);
        NewRight            = WORD(4DE0H);
        NewCtrlInsert       = WORD(92E0H);
        NewCtrlHome         = WORD(77E0H);
        NewCtrlPgUp         = WORD(84E0H);
        NewCtrlDelete       = WORD(93E0H);
        NewCtrlEnd          = WORD(75E0H);
        NewCtrlPgDn         = WORD(76E0H);
        NewCtrlUp           = WORD(8DE0H);
        NewCtrlLeft         = WORD(73E0H);
        NewCtrlDown         = WORD(91E0H);
        NewCtrlRight        = WORD(74E0H);
(*      NewAltInsert        = WORD(A200H);
        NewAltHome          = WORD(9700H);
        NewAltPgUp          = WORD(9900H);
        NewAltDelete        = WORD(A300H);
        NewAltEnd           = WORD(9F00H);
        NewAltPgDn          = WORD(A100H);
        NewAltUp            = WORD(9800H);
        NewAltLeft          = WORD(9B00H);
        NewAltDown          = WORD(A000H);
        NewAltRight         = WORD(9D00H);*)


    TYPE
        ABIOSKeyCode        = RECORD
                                ASCIICode    : BYTE;
                                ExtendedCode : BYTE;
                              END;

    VAR
        Code                : CARDINAL;
        KeyStruck           : ABIOSKeyCode;
        w                   : WORD;

    BEGIN                   (* ReadCARDINAL *)
            (* If there are any characters in the internal stack,
               get the next one. *)


            (* Wait until a key code is ready or Break is pressed.
               Note that since KeyPress is sensitive to BreakRequested,
               it should only be accepted while BreakRequested is
               FALSE.  AL 1/2/86  *)

        LOOP
            IF (BreakInterlock > 0) THEN
                RETURN CancelKey;
            ELSIF (BreakRequested()) THEN
                ClearBreak;            (* Acknowledge it. *)
                FlushKeyboardBuffer;   (* Cancel any waiting input.   *)
                RETURN CancelKey;               (* Treat as a Cancel (Escape). *)
            ELSIF (KeyPress()) AND (NOT BreakRequested()) THEN
                EXIT;
            END;
        END;


            (* Otherwise, try to get characters from DOS. *)

             (* Ask DOS for the next input character. *)

        SETREG(AX, DirectConsoleInput); 
        CODE(55H);
        SWI(BIOSKeyboardCall);
        CODE(5DH);
        GETREG(AX, w);

        KeyStruck := ABIOSKeyCode(w);

        WITH KeyStruck DO
            IF ((ASCIICode = BYTE(0E0H)) AND (ExtendedCode <> BYTE(00H))) THEN
                KeyStruck.ASCIICode := BYTE(00H);
            END;
        END;

        IF (KeyStruck.ASCIICode = BYTE(00H)) THEN
            (* Force F11 and F12 to act like F10 *)
            WITH KeyStruck DO
                CASE ExtendedCode OF
                    F11, F12   : ExtendedCode := F10;
                |   SF11, SF12 : ExtendedCode := SF10;
                |   CF11, CF12 : ExtendedCode := CF10;
                |   AF11, AF12 : ExtendedCode := AF10;
                ELSE
                END;
            END;
            Code := 256 + ORD(KeyStruck.ExtendedCode);
        ELSE
            Code := ORD(KeyStruck.ASCIICode);
        END;

        IF (Code = CtrlEnter) THEN   (* AJL 6-Oct-90 *)
            Code := ExitKey;
        END;


        RETURN Code;

    END ReadCARDINAL;
(*DOS>*)
    
(*<OS2
    PROCEDURE ReadCARDINAL(): CARDINAL;

    VAR
	    Code		    : CARDINAL;
	    Prefixed	    : BOOLEAN;
	    Char		    : CHAR;
	    charData	    : CharDataType;
	    err		        : CARDINAL;

    BEGIN		    (* ReadCARDINAL *)
	    (* If there are any characters in the internal stack,
	       get the next one. *)


	    (* Wait until a key code is ready or Break is pressed.
	       Note that since KeyPress is sensitive to BreakRequested,
	       it should only be accepted while BreakRequested is
	       FALSE.  AL 1/2/86  *)

	LOOP
	    IF (BreakInterlock > 0) THEN
		    RETURN CancelKey;
	    ELSIF (BreakRequested()) THEN
		    ClearBreak;	           (* Acknowledge it. *)
		    FlushKeyboardBuffer;   (* Cancel any waiting input.   *)
		    RETURN CancelKey;      (* Treat as a Cancel (Escape). *)
	    ELSIF (KeyPress()) AND (NOT BreakRequested()) THEN
		    EXIT;
	    END;
	END;

	(* Otherwise, try to get characters from OS/2. *)
	err := KbdCharIn ( charData, 0, 0 );

	IF ( charData.asciiCharCode = 0C ) THEN
	    Code := ORD(charData.scanCode);
	    IF ( Code < 256 ) THEN
	        INC ( Code, 256 )
	    END;
	ELSE
	    Code := ORD(charData.asciiCharCode);
	END;

    IF (Code = CtrlEnter) THEN   (* AJL 6-Oct-90 *)
        Code := ExitKey;
    END;

	RETURN Code;

    END ReadCARDINAL;
OS2>*)

BEGIN

    LOOP
        Code := ReadCARDINAL();

            (* Special hook for testing: Any time a character 255 is entered,
               the program will abort and dump. *)
            (* Another special hook to display the version
               number. *)
        IF (Code = DeathKey) THEN
            KeyboardTerminate;
            EmergencyDump();
        ELSE
            RETURN Code;
        END;

    END;

END XGetAnyCode;









(*<DOS*)
PROCEDURE CheckKbState(VAR KbState:BITSET);
VAR
    x : WORD;
BEGIN
    IF (BreakInterlock > 0) THEN
        KbState := {};
    ELSE 
        CODE ( 1EH,            (* PUSH DS         Save Data Segment       *)
               0B8H, 40H, 00,  (* MOV AX,  0040   Get BIOS Data Segment   *)
               08EH, 0D8H,     (* MOV DS,  AX                             *)
               0A0H, 17H, 00H, (* MOV AL, [17]    Load Kb Flags.          *)
               1FH   );        (* POP DS          Restore data segment    *)
        GETREG(AX,x); 
        KbState := BITSET(x);
    END;
END CheckKbState;
(*DOS>*)

(*<OS2
PROCEDURE CheckKbState(VAR KbState : BITSET);

VAR
    StatusRec : KbdStateType;
    err       : CARDINAL;

BEGIN
    IF (BreakInterlock > 0) THEN
	    KbState := {};
    ELSE
	    StatusRec.size := SIZE( KbdStateType );
	    err            := KbdGetStatus ( StatusRec, 0 );
	    KbState        := BITSET(StatusRec.shiftState);
    END;
END CheckKbState;
OS2>*)



PROCEDURE XScrollMode():BOOLEAN;
VAR
    KbState : BITSET;
BEGIN
    CheckKbState(KbState);
    RETURN (KbScrollState IN KbState);
END XScrollMode;




MODULE BreakInterruptHandler;(********************************************)

    (*  We take over two interrupt vectors, 1BH and 23H, treating them
        the same. *)

    IMPORT KeyboardTerminate, FlushKeyboardBuffer, BreakHandler;

    FROM SYSTEM IMPORT INBYTE, OUTBYTE, ADR, BYTE, ADDRESS,
                       ENABLE, DISABLE;

(*<DOS*)
    FROM Devices IMPORT SaveInterruptVector, RestoreInterruptVector;
(*DOS>*)
(*<OS2
    IMPORT DosSetSigHandler;
OS2>*)

    EXPORT StartCtrlBreakMonitor, StopCtrlBreakMonitor,
           XBreakRequested, XClearBreak, XBreakHandler,
           BreakInterlock;

    CONST
        CtrlCInterrupt       = 23H;
        CtrlBreakInterrupt   = 1BH;
        MaxBreaksBeforeDeath = 10;

    VAR
       CtrlBreakCount : CARDINAL;
       ISR  : ARRAY [0..30] OF BYTE; (* It will contain the code of the ISR *)
       OldVector23, OldVector1B : ADDRESS;
       IsStarted   : BOOLEAN;
       BreakInterlock : CARDINAL;

        (*$S-*)

    PROCEDURE XBreakRequested():BOOLEAN;
    BEGIN
        RETURN (CtrlBreakCount > 0);
    END XBreakRequested;



    PROCEDURE XClearBreak;
    BEGIN
        CtrlBreakCount := 0;
    END XClearBreak;

    (*$S=*)





    PROCEDURE XBreakHandler;  (* Body of the Interrupt Service Routine *)
    BEGIN
        INC(CtrlBreakCount);
(*        IF (CtrlBreakCount >= MaxBreaksBeforeDeath) THEN
            KeyboardTerminate;               (* Restore borrowed vectors. *)
            HALT;
        END;     *) (* 10/21/88 WKH *)
            (* Do not call FlushKeyboardBuffer within the
               BreakHandler, or anything else that could call DOS. *)
    END XBreakHandler;


(*<DOS*)
    PROCEDURE PrivateBreakHandler;  (* Body of the Interrupt Service Routine *)

    BEGIN                   (* PrivateBreakHandler *)

            (* Do not call FlushKeyboardBuffer within the
               BreakHandler, or anything else that could call DOS. *)

        INC(BreakInterlock);
        
        BreakHandler();

        DEC(BreakInterlock);

    END PrivateBreakHandler;
(*DOS>*)

(*<OS2
    PROCEDURE PrivateBreakHandler ( usSigArg : CARDINAL; usSigNum : CARDINAL ); (* Body of the Interrupt Service Routine *)

    VAR   
        ISRbody : PROC;
	    err     : CARDINAL; prevAction : CARDINAL;

    BEGIN		    (* PrivateBreakHandler *)

	        (* Do not call FlushKeyboardBuffer within the
	        BreakHandler, or anything else that could call DOS. *)

        INC(BreakInterlock);
        BreakHandler();
        DEC(BreakInterlock);

        err := DosSetSigHandler ( PROC(PrivateBreakHandler), ISRbody, prevAction,
				4, 1 );
    END PrivateBreakHandler;
OS2>*)

    PROCEDURE StartCtrlBreakMonitor;
      VAR tempSet : BITSET; ch: CHAR; dummy: BOOLEAN;
          ISRbody: PROC; p: POINTER TO ADDRESS;
(*<OS2
	      err : CARDINAL; prevAction : CARDINAL;
OS2>*)
    BEGIN
      IF (IsStarted) THEN RETURN; END;

      IsStarted := TRUE;
      BreakInterlock := 0;

(*<DOS*)
      DISABLE;
      ISR[ 0] := BYTE (50H);    (* push ax *)
      ISR[ 1] := BYTE (51H);    (* push cx *)
      ISR[ 2] := BYTE (52H);    (* push dx *)
      ISR[ 3] := BYTE (53H);    (* push bx *)
      ISR[ 4] := BYTE (56H);    (* push si *)
      ISR[ 5] := BYTE (57H);    (* push di *)
      ISR[ 6] := BYTE (1EH);    (* push ds *)
      ISR[ 7] := BYTE (06H);    (* push es *)
      ISR[ 8] := BYTE (9AH);    (* call far *)
      ISR[ 9] := BYTE (00H);    (* address will be fixed below *)
      ISR[10] := BYTE (00H);    (* that routine saves and restores bp *)
      ISR[11] := BYTE (00H);
      ISR[12] := BYTE (00H);
      ISR[13] := BYTE (07H);    (* pop es *)
      ISR[14] := BYTE (1FH);    (* pop ds *)
      ISR[15] := BYTE (5FH);    (* pop di *)
      ISR[16] := BYTE (5EH);    (* pop si *)
      ISR[17] := BYTE (5BH);    (* pop bx *)
      ISR[18] := BYTE (5AH);    (* pop dx *)
      ISR[19] := BYTE (59H);    (* pop cx *)
      ISR[20] := BYTE (58H);    (* pop ax *)
      ISR[21] := BYTE (0CFH);   (* iret *)


      ISRbody := PrivateBreakHandler;
      p := ADR (ISR[9]);
      p^:= ADDRESS (ISRbody);

           (* Install the Interrupt Service Routine for CTRL-C *)

      SaveInterruptVector(CtrlCInterrupt, OldVector23 );
      RestoreInterruptVector(CtrlCInterrupt, ADR(ISR) );

           (* Install the Interrupt Service Routine for CTRL-Break *)

      SaveInterruptVector(CtrlBreakInterrupt, OldVector1B );
      RestoreInterruptVector(CtrlBreakInterrupt, ADR(ISR) );

          (* Finish. *)

      CtrlBreakCount := 0;
      ENABLE;
(*DOS>*)

(*<OS2
      err := DosSetSigHandler ( PROC(PrivateBreakHandler), 
                                ISRbody, 
                                prevAction,
				                2, 1 );
      CtrlBreakCount := 0;
OS2>*)

    END StartCtrlBreakMonitor;


    PROCEDURE StopCtrlBreakMonitor;
    BEGIN
(*<DOS*)
        IF (IsStarted) THEN
            DISABLE;
            RestoreInterruptVector(CtrlCInterrupt, OldVector23 );
            RestoreInterruptVector(CtrlBreakInterrupt, OldVector1B );
            ENABLE;
        END;
(*DOS>*)
        IsStarted := FALSE;
    END StopCtrlBreakMonitor;


BEGIN
    CtrlBreakCount := 0;   (* So that BreakRequested will return FALSE
                              if we are not started. *)
    IsStarted := FALSE;

END BreakInterruptHandler;(*******************************************)








    (*  KeyboardInit -- Initialize the Keyboard module.
                        Other calls in this module are only valid
                        after this has been called. *)

PROCEDURE KeyboardInit;
BEGIN
(*<DOS*)
    IF (EnhancedKeyboardBit IN BIOSStuff) THEN
        DirectConsoleInput := WORD(NewGetKeyCall);
        CheckInputStatus   := WORD(NewCheckKeyCall);
    ELSE
        DirectConsoleInput := WORD(OldGetKeyCall);
        CheckInputStatus   := WORD(OldCheckKeyCall);
    END;
(*DOS>*)
END KeyboardInit;





    (*  KeyboardTerminate -- Do whatever is necessary to clean up when
                             the program ends.  Further calls to other
                             procedures in this module (except
                             KeyboardInit) are invalid after this has
                             been called.    *)

PROCEDURE KeyboardTerminate;
BEGIN
    StopCtrlBreakMonitor;
END KeyboardTerminate;





BEGIN

    GetAnyCode          := XGetAnyCode;
    KeyPress            := XKeyPress;
    ScrollMode          := XScrollMode;
    FlushKeyboardBuffer := XFlushKeyboardBuffer;
    BreakRequested      := XBreakRequested;
    ClearBreak          := XClearBreak;
    BreakHandler        := XBreakHandler;

    StartCtrlBreakMonitor;
END Keyboard.
