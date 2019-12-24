    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE Kbio;

(*$S+*)

(*  =========================================================================
    Last Edit : June 12, 1991 1:18PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

       8/11/85   AJL  - Changed KbioInit to only preset the video
                        mode array the first time it was called.
                        Otherwise, subsequent calls could mess up the
                        video settings.
                      - DummyArray[0] explicitly set to zero.
                      - acode is now = [0..511]
       9/8/85    AJL  - Use CRC16 to check the serial number.
       9/9/85    AJL  - Remove Burp, Message, MessageWithPriority,
                        Error and FatalError.  Add PushCode.
       1/2/86    AJL  - BreakRequested is checked after KeyPressed
                        in GetAnyCode to avoid overlooking a Break.
       1/3/86    AJL  - Use Foreign.UpshiftTable to convert characters
                        to uppercase in GetCode.
       08/07/86 LAA     Changed the ShowVersionNumberKey constant to reflect
                        the new encoding of extended codes, i.e. add 256
                        instead of 128. 
       10/7/86   LAA    Copied EmergencyDump from vers. 2.2 code, and used it
                        in GetAnyCode.  Turned the cursor off during KbioInit.
                        Made "------" a less harmful invalid serial number.
       11/12/86  LAA    Removed the call to EraseScreen from KbioTerminate.
       11/26/86 LAA     Changed for new Lights module, and brought the 
                        Break light into here.
       01/02/87 LAA     Added hook for the hot key editor.
       01/06/87 LAA     Incorporated hook into Memos for the hot key.
       05/12/87 AJL     Added Keyboard module usage.
       26-Jun-87 LAA    Called ShowKbLights from GetAnyCode so the lights 
                        will appear.
       17-Jul-87 AJL    Initialize vidctrl[videolights].
       23-Jul-87 AJL    Removed hot keys from GetAnyCode.
       12-Sep-87 AJL    Use Words.MaxWordstringThatFits in PourText.
       31-Oct-87 RSC    On re-init of Kbio, only update clean & blink settings.
       24-Sep-87 LAA    Import RTSMain instead of System for Logitech V3.
       29-Dec-87 AJL    Changed the break line char in PourText to Alt-252.
       02-Feb-88 LAA    Put call to DisplaySpaceLight into GetAnyCode.
       05-Feb-88 RSC    Re activate serial number checking with new scheme.
       13-Feb-88 LAA    Moved location of DisplaySpaceLight in GetAnyCode.
       22-Feb-88 LAA       - Force stack checking on for this module.
       27-Feb-88 LAA    Changed PourText so that TrimFront will not be done
                        on the first line of text (so the Press Slash message
                        of GanttVie and AVPViews won't left justify if the
                        date isn't displayed), or on a line which starts
                        with a line-break character (Andrew thinks this might
                        be generally useful for formatting Dialog boxes).
       18-Nov-88 LAA    Protect PutString from getting a dump because we
                        tried to write off-screen.  This change is to protect
                        international versions.  The routines in Video will
                        truncate a string so long as it starts out on the
                        screen.
       22-Nov-88 LAA    The above change didn't work so well.  I caused 
                        infinite recursion!  Changed the call to Error into a
                        call to Message.
        5-Jan-89 RSC    Added "GetCursorType"
        1-9-89   AJL    Changed PourText to allow video mode changes.
                        Reworked the logic in PourText for trimming word and
                        line break characters off a line.  
       2-17-89   AJL   -Made PrintString fill out the rest of the line up to
                        LRX with spaces so that it will erase any previous 
                        contents of the space.  
       13-Apr-89  LAA - Added new procedures PutStringWithColors and
                        PutColors.
       31-May-89  LAA   Changed a constant in DecryptString to handle the new,
                        longer serial number.
       31-May-89  RSC   Made the serial number string fairly impervious to the
                        actual serial number, as long as it is the right length.
       10-Jun-89  WKH   Intialize newly converted maxrow variable. 
                        Changed KbModeRow references to maxrow references
       13-Jun-89  WKH   Moved 2 routines from video to here.
       13-Jun-89  WKH   Use new method to move a light region
       14-Jun-89  WKH   Get cmdline parms text from gaga.
       01-Jul-89  WKH   Get rid of extra DEC stmt while de-crypting
                        VersionString.
       14-Jul-89  WKH   Set and re-set maxrow in PrepareForVideoExit/Return
       17-Aug-89  WKH/  Activate compressed video mode for OS/2, also merge in
                  AJL   AJL's new GetAnyCode procedure that more frequently
                        executes the IdleProc(for TLSwapf).
       13-Sep-89      LAA - Exported the CleanFlag and BlinkFlag from here, so
                            they don't have to be in Holder.  This was done so
                            we can defer reading Holder info until after the
                            calendar is read in from the Config file.
       22-Sep-89  WKH   Got rid of MCGA support
       01-Nov-89  WKH   OOPS!!  There was a slight problem with the EGA
                        compressed mode code.  It was too highly optimized.
        6-Dec-89  RSC   Add vector for GetAnyCode() for mouse support.
       18-Dec-89  RSC   Remove logic for GetCode, it should not be used.
                        Use GetNextEvent instead, to get Mouse support.
       10-Sep-90  RSC   Change Burp to Barf in error about writing off screen,
                        to highlight the specific write better.
        4-Oct-90  AJL   Parameterized the initialization of video attributes 
                        to use MAX(avidmode).
       30-Oct-90  AJL   Improved documentation.
       22-Jan-91  RSC   Removed unused reference to Holder.  This was all
                        that held Holder in the root of the program.
                        Holder's static area is now in FormStatic.
       10-Jun-91  RSC   Remove check of etched serial number; there is still
                        a check in RegSupport for the serial number in the
                        MUSER file, and this one is "superflous".
       12-Jun-91  RSC   Removed prior change.Seems we need it for "Programmer
                        Mode".
       18-Jun-91  TGS   Get VidModeCharacter from GaGa.
    =========================================================================
*)

    (*  This implementation is for the IBM PC running PC-DOS. *)

    IMPORT Keyboard;
    IMPORT SYSTEM;
(*<DOS*)
    IMPORT Devices;
(*DOS>*)
    FROM SYSTEM IMPORT
                       ADR, SIZE, CODE, SWI, AX, BX, BYTE, WORD, SETREG, 
                       GETREG;

(*<DOS*)
    FROM RTSMain IMPORT Terminate, Status;
(*DOS>*)

(*<OS2
FROM RTSTerm	  IMPORT  Terminate;
FROM RTSTypes	  IMPORT  Status;			(* V3 *)
FROM SYSTEM       IMPORT  TSIZE;
FROM VideoIO      IMPORT  ModeFlags, ModeSettings, ModeDataType, VioSetMode;
OS2>*)

    FROM Video  IMPORT PutStringWithAttribute, InitializeVideoHardware,
                       TerminateVideoHardware, SetCursorLocation,
                       MakeTone, GetScreenSize, VidMaxRow, AnAdapterType,
                       QueryAdapterType;

    IMPORT Video;

    FROM Codes    IMPORT ACode, ASetOfCodes, EmptyCodeSet;
    FROM GaGa     IMPORT GetGaGaMessage;
    FROM LStrings IMPORT Fill, SetString, Search, TrimFront, SubStr,
                         Procustes, Upshift, StringsEqual;
    FROM Keys     IMPORT CancelKey;
    FROM Dialog   IMPORT Message, FatalError, Burp, Barf, Error;
    FROM CRC16    IMPORT CheckSum;
    FROM Lights   IMPORT EnableLights, ActiveLightRegion, MoveLightRegion;
    FROM Foreign  IMPORT UpshiftTable, ConvertedCharacter;
    FROM Boxes    IMPORT ABoxType, ABoxAttribute;
    FROM Space    IMPORT DisplaySpaceLight;
    FROM Words    IMPORT EndOfWord;
    IMPORT KbState;


FROM Layout                 IMPORT
    (* VAR *)                   GanttWEnd, MaxRow;

FROM ParmLine               IMPORT
    (* PROC *)                  GetOption;


CONST
    ModuleNumber         = 22700;


    WriteAttrAndChar     =  0900H;
    DOSCall              =  21H;
    CheckInputStatus     = 0B00H;
    DirectConsoleInput   = 0700H;
    GetTime              = 02C00H;
(*    KbModeRow            = maxrow;*)

    (* Compressed mode values *)
    NormalLines          = 24;
    EGALines             = 42;
    VGALines             = 49;


CONST
    BreakLineDefault = 374C;               (* Alt-252 *)
    BreakWordChar = " ";
VAR
    y                       : ascreeny;
    OldBreakHandler         : Keyboard.AServiceProcedure;
    i                       : CARDINAL;
    KbioInitialized         : BOOLEAN;
    CompressedMode          : BOOLEAN;
    OldVideoMode            : CARDINAL;

    VidModeCharacter        : CHAR;
    s                       : ARRAY [0..3] OF CHAR;

    AdapterType             : AnAdapterType;









PROCEDURE ScrollMode():BOOLEAN;
BEGIN
    RETURN Keyboard.ScrollMode();
END ScrollMode;





(* ================= MODULE KeyCodeStacker ===================== *)

    (* Provides a stack of codes, which may be pushed, popped,
       flushed and interrogated. *)

MODULE KeyCodeStacker;

IMPORT ACode;


EXPORT PushCode, PopCode, FlushKeyCodeStack, KeyCodeAvailable;

CONST
    StackSize  = 15;
VAR
    Stack  : ARRAY [0..StackSize-1] OF CARDINAL;
    NextEmpty     : CARDINAL;           (* Index of next unused stack cell. *)



PROCEDURE FlushKeyCodeStack;
BEGIN
    NextEmpty := 0;
END FlushKeyCodeStack;



PROCEDURE KeyCodeAvailable():BOOLEAN;
BEGIN
    RETURN NextEmpty > 0;
END KeyCodeAvailable;


PROCEDURE PushCode( Code : ACode );
BEGIN
        (* Code 0 is a NOP. *)
    IF (Code <> 0) THEN
        (*+2<*)
        IF (NextEmpty >= StackSize) THEN HALT; END;
        (*+2>*)

        Stack[NextEmpty] := Code;
        INC(NextEmpty);
    END;
END PushCode;


PROCEDURE PopCode( VAR Code : ACode ) : BOOLEAN;
BEGIN
    IF (NextEmpty = 0) THEN
        RETURN FALSE;
    ELSE
        DEC(NextEmpty);
        Code := Stack[NextEmpty];
        RETURN TRUE;
    END;
END PopCode;



BEGIN
    NextEmpty := 0;    (* KeyCodeStack is empty. *)
END KeyCodeStacker;

(* ==================== End MODULE KeyCodeStacker ============= *)






    (*  KeyPress

        Check if a character is waiting to be read, OR if Break has
        been hit.

        If one has been typed, return TRUE;

        Else, return FALSE.

    *)

PROCEDURE KeyPress(): BOOLEAN;
VAR
    StatusChar : CHAR;
BEGIN
    KbState.ShowKbLights();
    RETURN KeyCodeAvailable() OR Keyboard.KeyPress();
END KeyPress;







    (* FlushKeyboardBuffer -- Cancel any characters waiting on the
                              standard input device.  Does not affect
                              the Break state. *)

PROCEDURE FlushKeyboardBuffer;
BEGIN
    FlushKeyCodeStack;
    Keyboard.FlushKeyboardBuffer();
END FlushKeyboardBuffer;





    (*  GetAnyCode

        When a character has been typed, this routine returns it.
        If no character has been typed, this routine will wait
        until one is.

        If a Break has been requested, the special code CancelKey
        is returned instead of a character, the keyboard buffer is
        flushed of any following input, and the Break state is
        cleared.

        RSC 6-Dec-89: Made this a stealable vector.  This is for
                      mouse support.  In general, don't steal this
                      vector for any kind of macros or key passing
                      use.  Steal only to be notified that someone
                      is attempting to monitor the keyboard.  Mouse
                      support just uses this to determine if it
                      should put up the mouse cursor and listen for
                      mouse interrupts.  It does NOT use this vector
                      to return codes, or MACROS would not see them.
    *)


PROCEDURE XGetAnyCode (): ACode;

VAR
    Code                    : ACode;
        (* Count is used to wait until the user hasn't done anything in
           a while.  We count and loop for two reasons: (1) we want to
           keep checking the keyboard status so that we can update the
           Num Lock and similar lights, and (2) by counting, we wait 
           longer on slower processors, since they will take longer to 
           complete their "idle" work, we wait longer before initiating it.
         *)  
    Count                   : CARDINAL;

BEGIN

    Count := 0;
    DisplaySpaceLight();                                          (* 13-Feb-88 LAA *)
    LOOP
        KbState.ShowKbLights();                                   (* 26-Jun-87 LAA *)
        IF (Keyboard.BreakRequested()) THEN
            ClearBreak();
            FlushKeyboardBuffer();
            RETURN CancelKey;
        ELSIF (KeyPress() AND (NOT Keyboard.BreakRequested())) THEN
            IF (NOT PopCode(Code)) THEN
                Code := Keyboard.GetAnyCode();
            END;
            RETURN Code;
        ELSIF (Count > 10000) THEN
            IdleProcess();
                (* Now that we have decided we are idle, do a burst of 
                   work. *)
            DEC(Count);       (* Will repeat immediately! *)
        END;
        INC(Count);
    END;

END XGetAnyCode;



PROCEDURE GetCode ( VAR okset : ASetOfCodes ) : ACode;
CONST
    BitsPerBitSet = 16;
VAR
    TheCode, NewCode  : ACode;
    Good     : BOOLEAN;
BEGIN
    FatalError();
(* *************************************************************
    LOOP
        TheCode := GetAnyCode();

            (*  Check if the code is in the set of ok codes.
                If not, convert lower case alphabetics to upper
                case and try again.
            *)

        LOOP
            Good := (TheCode MOD BitsPerBitSet) IN okset[TheCode DIV BitsPerBitSet];
            IF (Good) OR (TheCode > 255) THEN
                EXIT;   (* Exit if good, or outside the character range. *)
            END;
            NewCode := ORD(ConvertedCharacter( CHR(TheCode), UpshiftTable ));
            IF (NewCode <> TheCode) THEN
                TheCode := NewCode;
            ELSE
                EXIT;
            END;
        END;

        IF (Good) THEN
            RETURN TheCode
        END;

        Burp;
    END;
******************************************************* *)
END GetCode;



PROCEDURE NullIdleProcess();

BEGIN
END NullIdleProcess;



PROCEDURE SetCursorType( CursorType : ACursorType );
BEGIN
    Video.SetCursorType( ORD(CursorType) );
END SetCursorType;



    (* GetCursorType -- Get the current cursor mode.   RSC 1/5/89 *)

PROCEDURE GetCursorType() : ACursorType;
VAR
    CursorAsCardnal : CARDINAL;
BEGIN
    Video.GetCursorType( CursorAsCardnal );
    RETURN VAL( ACursorType, CursorAsCardnal );
END GetCursorType;









    (*  GotoXY


    *)



PROCEDURE GotoXY ( x : ascreenx; y : ascreeny );
BEGIN
    SetCursorLocation(x,y);
END GotoXY;









PROCEDURE PutString ( VAR s : ARRAY OF CHAR;
                      x : ascreenx;  y : ascreeny;  mode : avidmode );

VAR
    s2                      : ARRAY [0..81] OF CHAR;

BEGIN
    IF ((x <=maxcol) AND (y <= maxrow)) THEN                      (* 18-Nov-88 LAA *)
        PutStringWithAttribute (s,x,y,vidctrl[mode]);
    ELSE
        SetString(s2, "You're trying to write off-screen!");
        Message(s2);
        Barf();                 (* 10-Sep-90 RSC *)
    END;
END PutString;




        (*  PutAttribute changes the attribute of characters on the
            video screen at a chosen position and length.
            Remember that the "mode" is a coded index representing
            a video attribute, but is not the hardware-dependent
            representation of that attribute. *)

PROCEDURE PutAttribute (  x : ascreenx;
                          y : ascreeny;
                          length : CARDINAL;
                          mode: avidmode );
BEGIN
    Video.PutAttribute (x,y,length,vidctrl[mode]);
END PutAttribute;




PROCEDURE MixOfColors(    Foreground        : avidmode;
                          Background        : avidmode): BITSET;

BEGIN                       (* MixOfColors *)

    RETURN ((vidctrl[Foreground] * {0..3}) + (vidctrl[Background] * {4..7}));

END MixOfColors;




    (*  PutStringWithColors --

        Display an LString on the screen in the given x and y position, 
        with colors selected from the foreground and background video
        modes.

        Preconditions:
            Kbio must have been initialized, and not yet terminated.

        Postconditions:
            The string will be written to the screen with the foreground
            color of the foreground mode, and the background color of the
            background mode.
    *)

PROCEDURE PutStringWithColors(VAR String    : ARRAY OF CHAR;
                                  X         : ascreenx;
                                  Y         : ascreeny;
                                  Foreground: avidmode;
                                  Background: avidmode     );

VAR
    s2                      : ARRAY [0..255] OF CHAR;

BEGIN                       (* PutStringWithColors *)

    IF ((X <=maxcol) AND (Y <= maxrow)) THEN                      (* 18-Nov-88 LAA *)
        PutStringWithAttribute(String,X,Y,MixOfColors(Foreground,Background));
    ELSE
        SetString(s2, "You're trying to write off-screen!");
        Message(s2);
        Burp();
    END;

END PutStringWithColors;




    (*  PutColors --

        Change the colors (foreground and background) of the characters on 
        the screen, at the given position and for the given length, without 
        altering the characters themselves.

        Preconditions:
            Kbio must have been initialized, and not yet terminated.

        Postconditions:
            The foreground and background colors of the screen will be 
            changed for the given position and length.
    *)

PROCEDURE PutColors(    X                   : ascreenx;
                        Y                   : ascreeny;
                        Length              : CARDINAL;
                        Foreground          : avidmode;
                        Background          : avidmode);

BEGIN                       (* PutColors *)

    Video.PutAttribute(X,Y,Length,MixOfColors(Foreground,Background));

END PutColors;





PROCEDURE EraseLn ( y : ascreeny );
VAR
    s : ARRAY [0..maxcol+1] OF CHAR;
BEGIN
    Fill(s," ",maxcol+1);
    PutString(s,0,y,videonormal);
    IF (y=maxrow) THEN
        KbState.ShowKbLights();        (* Force redisplay of lights. *)
    END;
END EraseLn;


    (* PrintString -- Allow internal video mode changes.  Must not
                      have incomplete parts, that is, the ModeChange
                      character, if any, must be followed by a 
                      valid video mode setting character.  Two mode
                      change characters in a row reset to the original
                      mode. *) 


PROCEDURE PrintString( VAR DisplayString : ARRAY OF CHAR;
                           X             : ascreenx;   
                           Y             : ascreeny;
                           LRX           : ascreenx;
                           Mode          : avidmode );
VAR
    i,j  : CARDINAL;
    S    : ARRAY [0..255] OF CHAR;
    ModeChange : ARRAY [0..1] OF CHAR;
    OriginalMode : avidmode;
BEGIN
    OriginalMode := Mode;
    Fill(ModeChange,VidModeCharacter,1);
    i := 1;
    WHILE (i <= ORD(DisplayString[0])) DO
         IF (DisplayString[i] = VidModeCharacter) THEN
             j := ORD(DisplayString[i+1]);
             IF (j = ORD(VidModeCharacter)) THEN
                 Mode := OriginalMode;
             ELSE
                 Mode := VAL(avidmode,j-ORD("A"));
             END;
             INC(i,2);
         END;
         j := Search(DisplayString,ModeChange,i);
         IF (j = 0) THEN
             j := ORD(DisplayString[0]) + 1;
         END;
         SubStr(DisplayString,S,i,j-i);
         Procustes(S,LRX-X+1);
         PutString(S,X,Y,Mode);
         INC(X,j-i);
         i := j;
     END;
         (* Erase the remainer of the space, up to LRX. *)
     IF (X <= LRX) THEN
         Fill(S," ",LRX-X+1);
         PutString(S,X,Y,Mode);
     END;
END PrintString;


    (* Compute the displayed length of the string, skipping over
       video mode change sequences. *)

PROCEDURE VisualLength(   S : ARRAY OF CHAR;
                          Start, End : CARDINAL) : CARDINAL;
VAR
    i, Length : CARDINAL;
    Waiting : BOOLEAN;
BEGIN
    Length := 0;
    Waiting := FALSE;
    FOR i := Start TO End-1 DO
        IF (S[i] = VidModeCharacter) THEN Waiting := TRUE;
        ELSIF (Waiting) THEN Waiting := FALSE;
        ELSE INC(Length);
        END;
    END;
    RETURN Length;
END VisualLength;




PROCEDURE MaxWordstringThatFits(VAR s       :ARRAY OF CHAR;
                                    StartAt : CARDINAL;
                                    MaxLen  : CARDINAL;
                                    HardEnd : CHAR 
                               ) : CARDINAL;
VAR
    Limit, i, VisLen : CARDINAL;
    s1 : ARRAY [0..1] OF CHAR;
BEGIN
    IF (StartAt > ORD(s[0])) THEN
        RETURN 0;
    END;

        (* Find the first hard end, or the end of the string. *)

    Fill(s1,HardEnd,1);
    i := Search(s,s1,StartAt);            (* Find the next hard line end. *)
    IF (i = 0) THEN                       (* If none, then end of string. *)
       i := ORD(s[0])+1;
    END;
    VisLen := VisualLength(s,StartAt,i);  (* How long will it appear to be? *)  
    IF (VisLen <= MaxLen) THEN            (* If short enough, return that. *)
        RETURN ( i - StartAt );
    END;

        (* Failing that being within range, find the last BreakWordChar.
           First, find the longest possible string. *)

    Limit := ORD(s[0]);
    WHILE (VisualLength(s,StartAt,Limit+1) > MaxLen) DO 
        DEC(Limit);
    END;

        (* Find the rightmost word that fits.  *)

    i := Limit;

    REPEAT
        IF (EndOfWord(s,i,BreakWordChar)) THEN
            RETURN ( i + 1 - StartAt );
        END;
        DEC(i);
    UNTIL (i <= StartAt);

        (* Failing that, return the most that will fit. *)

    RETURN Limit;


END MaxWordstringThatFits;



    (* PourText -- Put text from the string S onto the screen
                   within the box bounded by ULX,ULY at the
                   upper left and LRX,LRY at the lower right.
                   Return LastY as the Y of the last line
                   written on.  VideoMode of videovanish will
                   disable output.
                   *)

PROCEDURE PourText  ( VAR S          : ARRAY OF CHAR;
                          VideoMode  : avidmode;
                          ULX        : ascreenx;
                          ULY        : ascreeny;
                          LRX        : ascreenx;
                          LRY        : ascreeny;
                      VAR LastY      : ascreeny);
VAR
    i, FirstCharOnLine : CARDINAL;
    S2   : ARRAY [0..255] OF CHAR;
    Y    : ascreeny;
    LineLength : CARDINAL;
    TextLength : CARDINAL;
    BreakLineChar  : CHAR;
BEGIN
    LineLength := LRX - ULX + 1;
    TextLength := ORD(S[0]);

    Y := ULY;
    LastY := Y;

        (* Normally, a line break is forced by a Alt-252.  However, a
           leading Alt-252 resets the break character to the second
           character, and starts printing with the third. *)

    IF (S[0] > 2C) AND (S[1] = BreakLineDefault) THEN
        BreakLineChar := S[2];
        FirstCharOnLine := 3;
    ELSE
        BreakLineChar := BreakLineDefault;
        FirstCharOnLine := 1;
    END;


        (* Print each line. *)

    WHILE (FirstCharOnLine <= TextLength) AND (Y <= LRY) DO

            (* Trim word or line breaks off subsequent lines. *)
        IF (Y > ULY) THEN   (* not first line *)
            IF (S[FirstCharOnLine] = BreakLineChar) THEN
                INC(FirstCharOnLine);
            END;
            WHILE (S[FirstCharOnLine]=BreakWordChar) DO
                INC(FirstCharOnLine);
            END;
        END;

        i := MaxWordstringThatFits(S,FirstCharOnLine,LineLength,BreakLineChar);

        IF (VideoMode <> videovanish) THEN
            SubStr(S,S2,FirstCharOnLine,i);
            PrintString(S2,ULX, Y, LRX, VideoMode);
        END;

        LastY := Y;
        INC(Y);

        INC(FirstCharOnLine,i);
    END;
END PourText;










    (*  Tone  -- Make a noise on the speaker. *)

PROCEDURE Tone  ( Pitch, Duration : CARDINAL );
BEGIN
    IF (soundon) THEN
        MakeTone(Pitch,Duration);
    END;
END Tone;










PROCEDURE EraseScreen;
VAR
    i:ascreeny;
BEGIN
    FOR i := 0 TO maxrow DO
        EraseLn(i)
    END;
END EraseScreen;






(*$R-*)

PROCEDURE DecryptString(VAR s:ARRAY OF CHAR);
CONST
    StartAt = 1;
VAR
    i,j,x,len : CARDINAL;
    b,b2      : BITSET;
BEGIN
    len := ORD(s[0]);
    x   := 0A3H;
    FOR i := len+2 TO StartAt BY -1 DO
        j    := ORD(s[i]);
        b2   := BITSET( j );
        s[i] := CHR( CARDINAL( (b2/BITSET(x)) / BITSET(125-i) ) );  (* 31-May-89 LAA *)
        x    := CARDINAL(b2);
    END;
    TamperedFlag := (CheckSum(ADR(s[StartAt]),len) =
                    ((ORD(s[len+1]) * 256) + ORD(s[len+2]))); (* 31-May-89 RSC *)
END DecryptString;


(*$R=*)








PROCEDURE KbioInit;
VAR
    S   : ARRAY [0..11]  OF CHAR;
    S2  : ARRAY [0..255] OF CHAR;
    i   : CARDINAL;
    
BEGIN

  (* RSC 10/30/87 - Allow re-init of video hardware, but thats all. *)

    InitializeVideoHardware(BlinkFlag,CleanFlag);

    GetScreenSize(i, maxrow);  (* 10-Jun-89 WKH *)

    IF (KbioInitialized) THEN
        RETURN;
    END;
    KbioInitialized := TRUE;

    Keyboard.KeyboardInit;

        (* Install our break handler into the break handling chain. *)

    OldBreakHandler := Keyboard.BreakHandler;
    Keyboard.BreakHandler := OurBreakHandler;

    TamperedFlag := TRUE;

        (*  Set the version and serial number for this copy of
            the product. *)
                  (*     RSC  31-May-89                             *)
                  (*   123456789 123456789 123456789 123456789 12xx *)
                  (*                                 ^^ FUDGE ^^^   *)
                  (*   Check Summ goes at (VersionStringLength + 1) *)
    VersionString := " THERE IS NO SERIAL NUMBER IN TIME LINE YET!!";
    VersionString[0] := CHR(VersionStringLength);

    SetString(S2,"THERE IS NO");
    IF (Search(VersionString,S2,1) <> 0) THEN
        GetGaGaMessage( ModuleNumber + 0, S2 ); (* "Please serialize this program" *)
        Error(S2);
        KbioTerminate;
        Terminate(Normal);
    END;

    DecryptString(VersionString);

    (* TAMPERED FLAG MAY BE FALSE HERE!! *)

(*    DEC(VersionString[0]);  01-Jul-89 WKH *)

    SetCursorType(NoCursor);                                       (* LAA 10/7/86 *)

END KbioInit;














PROCEDURE KbioTerminate;
BEGIN
            (* Reset the screen to its default video mode and erase it. *)
    EnableLights(FALSE);       (* Don't want any status display lights. *)
    vidctrl[  videonormal ] := BITSET( 07H );    (* Normal white on black. *)
        (* Fill the screen with blanks, in normal video mode.  This will
           prevent the next program from having some wierd colors on the
           screen. *)
    EraseScreen();

        (* Put the cursor at the upper left. *)
    GotoXY(0,0);

    TerminateVideoHardware;

        (* Deinstall our break handler from the break handling chain. *)

    Keyboard.BreakHandler := OldBreakHandler;

        (* Shutdown the keyboard. *)

    Keyboard.KeyboardTerminate();

END KbioTerminate;



PROCEDURE BreakRequested():BOOLEAN;
BEGIN
    KbState.ShowKbLights();                                   (* 12-FEb-88 AJL *)
    RETURN Keyboard.BreakRequested();
END BreakRequested;



PROCEDURE ClearBreak;
BEGIN
    Keyboard.ClearBreak();
    KbState.ShowKbLights();
END ClearBreak;






    (* OurBreakHandler intercepts the BreakHandler declared in
       the Keyboard module. *)


PROCEDURE OurBreakHandler();
BEGIN
    FlushKeyCodeStack();
    OldBreakHandler;
    (* KbState.ShowKbLights();   Don't.  This can cause lock-up. *)
END OurBreakHandler;


    (*
        PrepareVideoForExit - Reset video to state before TL started
    *)
PROCEDURE PrepareVideoForExit();

BEGIN
    IF (CompressedMode) THEN
(*<DOS*)
        SETREG(AX, OldVideoMode);
        CODE(55H);
        SWI(10H);
        CODE(5DH);
        maxrow := NormalLines;  (* 14-Jul-89 WKH *)
(*DOS>*)
    END;
END PrepareVideoForExit;


    (*
        PrepareVideoForReturn - Reset video to state TL wants
    *)
PROCEDURE PrepareVideoForReturn();

BEGIN
    IF (CompressedMode) THEN
(*<DOS*)
        CASE AdapterType OF
            EGAMono,
            EGAColor  : SetEGACompressed();
                        maxrow := EGALines;
        |   VGAMono,
            VGAColor  : SetVGACompressed();
                        maxrow := VGALines;
        ELSE
            FatalError();
        END;
(*DOS>*)
    END;
END PrepareVideoForReturn;

PROCEDURE SetVGACompressed();

(*<OS2
VAR
    Err                     : CARDINAL;
    ModeData                : ModeDataType;
OS2>*)

BEGIN
(*<DOS*)
    (* establish 80x25 alphanumeric mode with 400-line vertical resolution *)
    CODE(0B8H, 02H, 12H,  (* MOV  AX, 1202H ; AL := 12h (INT 10H ftn num)  *)
         0B3H, 30H,       (* MOV  BL,   30H ; AL := 2 (set 400 scan lines) *)
         0CDH, 10H,       (* INT  10H                                      *)
          	
         0B8H, 03H, 00H,  (* MOV  AX, 3     ; set to 80x25 16-color mode   *)
         0CDH, 10H,       (* INT  10H                                      *)

    (* load video BIOS 8x8 characters into alphanumeric character generator*)
         0B8H, 12H, 11H,  (* MOV  AX, 1112H ; set 8x8 character set load   *)
         0B3H, 00H,       (* MOV  BL, 0     ; block to load                *)
         0CDH, 10H);      (* INT  10H                                      *)
(*DOS>*)

(*<OS2
    WITH ModeData DO
        length      := TSIZE(ModeDataType);
        type        := ModeSettings{};
        INCL(type, NoMonoPrtAdapter);
        color       := BYTE(4);            (* 4 bits of color *)
        textColumns := 80;
        textRows    := 50;
        horizRes    := 720;
        vertRes     := 400;
    END;

    Err := VioSetMode(ModeData, 0);    
OS2>*)
END SetVGACompressed;


PROCEDURE SetEGACompressed();

BEGIN
    (* establish 80x25 alphanumeric mode (350-line vertical resolution)    *)
    CODE(0B8H, 03H, 00H,  (* MOV  AX, 3     ; set to 80x25 16-color mode   *)
         0CDH, 10H,       (* INT  10H                                      *)

    (* load video BIOS 8x8 characters into alphanumeric character generator*)
         0B8H, 12H, 11H,  (* MOV  AX, 1112H ; set 8x8 character set load   *)
         0B3H, 00H,       (* MOV  BL, 0     ; block to load                *)
         0CDH, 10H,       (* INT  10H                                      *)

    (* set cursor position in character matrix                             *)
         0B8H, 40H, 00H,  (* MOV  AX, 40H                                  *)
         08EH, 0C0H,      (* MOV  ES, AX    ; ES -> video BIOS data area   *)
         026H, 08BH, 16H, 63H, 00H, (* MOV DX,ES:[63H];DX := CRTC address port   *) (* 1-Nov-89 WKH  *)
                              (*                 from 40:63 (3B4H or 3D4H) *)
         0B8H, 0AH, 06H,  (* MOV  AX, 060AH ; AH := 6  (Cursor Start Value *)
                          (*                  AL := 0AH(Cursor Start reg #)*)
         0EFH,            (* OUT  DX, AX    ; update CRTC Cursor Start reg *)
         0B8H, 0BH, 00H,  (* MOV  AX, 000BH ; AH := 0  (Cursor End Value)  *)
                          (*                  AL := 0BH(Cursor End reg #)  *)
         0EFH,            (* OUT  DX, AX    ; update CRTC Cursor End reg   *)

    (* use alternate video BIOS print screen routine                       *)
         0B4H, 12H,       (* MOV  AH, 12H                                  *)
         0B3H, 20H,       (* MOV  BL, 20H                                  *)
         0CDH, 10H);      (* update INT 5 vector (print screen)            *)
END SetEGACompressed;


    (*
        CheckForCompressedMode - Check for compressed mode parmline option and
                                 switch to compressed mode if on.
    *)
PROCEDURE CheckForCompressedMode();

VAR
    ok                      : BOOLEAN;
    s                       : ARRAY [0..13] OF CHAR;
    s1                      : ARRAY [0..17] OF CHAR;
    DisplayOption           : ARRAY [0..99] OF CHAR;

BEGIN
    (* check parmline to see if DISPLAY=COMPRESSED *)
    GetGaGaMessage(ModuleNumber + 1, s);  (* DISPLAY *)
    GetGaGaMessage(ModuleNumber + 2, s1);  (* COMPRESSED *)

    GetOption(s, ok, DisplayOption);

    Upshift(DisplayOption);

    CompressedMode := FALSE;

    IF (ok AND StringsEqual(DisplayOption, s1)) THEN

(*<DOS*)
        (* Save current video state *)
        SETREG(AX, 0F00H);
        CODE(55H);
        SWI(10H);
        CODE(5DH);

        GETREG(AX, OldVideoMode);
        OldVideoMode := CARDINAL(BITSET(OldVideoMode) * BITSET{0..7});
(*DOS>*)

        AdapterType := QueryAdapterType();

        CASE AdapterType OF
            EGAMono,
            EGAColor  : SetEGACompressed();
                        maxrow         := EGALines;
                        CompressedMode := TRUE;
        |   VGAMono,
            VGAColor  : SetVGACompressed();
                        maxrow         := VGALines;
                        CompressedMode := TRUE;
        ELSE
            maxrow         := NormalLines;
            CompressedMode := FALSE;
        END;
    ELSE
        maxrow         := NormalLines;
        CompressedMode := FALSE;
    END;

    MaxRow    := maxrow;
    VidMaxRow := maxrow;
    GanttWEnd := MaxRow-1;
    MoveLightRegion(0, maxrow, maxcol, maxrow, ActiveLightRegion);
END CheckForCompressedMode;






BEGIN
        (* Some initializations we only want to do the first time. *)
            (*     IBM Any Board  *)
            (*  Initialize the modes that will be used to print errors
                and messages.  These may be needed before we have been
                properly initialized by an external module. *)

    FOR i := 0 TO ORD(MAX(avidmode))-1 BY 2 DO
        vidctrl[VAL(avidmode,i)] := BITSET( 07H );
        vidctrl[VAL(avidmode,i+1)] := BITSET( 70H );
    END;

    BlinkFlag       := TRUE;   (* Allow blinking for now. *)
    CleanFlag       := TRUE;   (* Clean video output. *)
    KbioInitialized := FALSE;
    maxrow          := NormalLines;     (* 10-Jun-89 WKH *)
    CompressedMode  := FALSE;  (* 12-Jun-89 WKH *)

    IdleProcess       := NullIdleProcess;
    GetAnyCode        := XGetAnyCode;     (* 6-Dec-89 RSC *)

    GetGaGaMessage( ModuleNumber + 3, s ); (* 18-Jun-91 TGS *)
    VidModeCharacter := s[1];

END Kbio.
