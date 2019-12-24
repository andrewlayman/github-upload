MODULE TLKodak;

    (* MODIFICATION HISTORY:

        2-Mar-89 RSC - Changed "InstallNewProcedure" for Overlays.Mod.
        7-Mar-89 LAA   Changed ADDRESS to ADR in calls to InstallNewProcedure.
        09-Aug-89 KKC  Add copyright message.
     12-Dec-89  RSC - support for new menu parameter.
     12-Apr-91  RSC - Change to params for MenuWithPrompts
        
    *)


    FROM Boxes    IMPORT ABoxType, ABoxAttribute;

    FROM Chainer  IMPORT Chain;

    FROM Codes  IMPORT ACode, ASetOfCodes, EmptyCodeSet;

    FROM Dialog   IMPORT Message, FatalError, Burp, Error,
                         NotYetImplemented;

    FROM Direct411    IMPORT GetInputFile, GetOutputFile;

    FROM Directory    IMPORT ExtractFileNameParts;

    FROM FileSystem   IMPORT File, Close, Response, SetPos, GetPos,
                             SetRead, SetWrite, SetModify, Lookup,
                             WriteWord, ReadWord, Delete, Length,
                             SetOpen, WriteNBytes;

    FROM FileAux      IMPORT PrepareForIO, CheckIO, 
                             DisplayFileError;

FROM Kbio       IMPORT ascreenx, ascreeny, maxrow, maxcol, avidmode, vidctrl, Tone;

    FROM Keys     IMPORT DoIt, EditKey, CancelKey, ExitKey, Fwrd, Reverse;

    IMPORT Keyboard;

    FROM Lights   IMPORT ActiveLightRegion, ALight, InstallLight,
                         RemoveLight, DisplayLight, EnableLights;

    FROM LStrings IMPORT Fill, SetString, Search, CtoS, ConcatS, ConcatLS,
                         LStringToTString, Copy;

    FROM Menus    IMPORT NoYes, MenuWithPrompts, APromptType;

    FROM Notices                IMPORT
        (* TYPE *)                  AnOccasion, AStep,
        (* PROC *)                  RegisterForNotices, SendNotices;

    FROM Overlays IMPORT
        (* PROC *)              InstallNewProcedure;

    FROM ParmLine               IMPORT
        (* PROC *)                  GetOption;

    FROM SYSTEM                 IMPORT ADDRESS, ADR, DOSCALL;

FROM Text           IMPORT
    (* TYPE *)          AText;

FROM Video      IMPORT GetImageLine, PutImageLine, GetCursorType,
                       SetCursorType, GetCursorLocation,
                       SetCursorLocation;



    (* Keyboard ----> Logger Facility -----> Application  *)




CONST
    LoggerRecordKey   = 256 + 13H;   (* Alt-R *)
    LoggerPlaybackKey = 256 + 19H;   (* Alt-P *)
    SnapShotKey       = 256 + 1FH;   (* Alt-S - SNAPSHOT! *)
    BreakCode         = 0FFFFH;      (* Internal Signal *)
    GetTime           = 02CH;        (* MS-DOS function *)

TYPE
    ALoggerState     = (Neutral, Recording, Playback);


VAR
    OldGetCode              : Keyboard.AGetCodeProcedure;
    OldKeyPress             : Keyboard.AYesNoProcedure;
    OldBreakRequested       : Keyboard.AYesNoProcedure;
    OldClearBreak           : Keyboard.AServiceProcedure;
    OldBreakHandler         : Keyboard.AServiceProcedure;

    OldScreen,
    ScreenBuffer            : ARRAY [0..2048] OF CARDINAL;
    LastHourMinute,
    LastSecondCent,
    LoggerInterlock         : CARDINAL;
    LoggerLight             : ALight;
    LoggerState             : ALoggerState;
    KeyPressSeen,
    BufferCount             : CARDINAL;   (* Log Buffer index. *)
    LogEvery,                             (* Write to disk every so many keystrokes. *)
    DelayTime               : CARDINAL;   (* Write to disk if no keystrokes for n/100 seconds. *)
    Buffer                  : ARRAY [0..20] OF CARDINAL;
    f                       : File;
    LoggerBreakFlag         : BOOLEAN;    (* Break was hit.  Signal during playback. *)

    LogFileNameLS,
    LogFileNameZS           : ARRAY [0..99] OF CHAR;







    (* Procedures for keystroke logging. *)


PROCEDURE FileComplaint;
VAR
    s  : ARRAY [0..80] OF CHAR;
BEGIN
    SetString(s,"Log File: ");
    ConcatLS(s,LogFileNameLS);
    DisplayFileError(f,s);
END FileComplaint;





PROCEDURE StartLoggerRecording() : BOOLEAN;
VAR
    Path, PathIn, PathOut                 : ARRAY [0..99] OF CHAR;
    S, Device, File, Ext, NameIn, NameOut : ARRAY [0..19] OF CHAR;
    res                                   : Response;
BEGIN
    ExtractFileNameParts( LogFileNameLS, Device, Path, File, Ext );
    Copy(Device, PathIn );
    ConcatLS( PathIn, Path );
    Copy(File, NameIn );
    ConcatS( NameIn, "." );
    ConcatLS(NameIn, Ext );

    IF (NOT GetOutputFile( PathIn, 
                           NameIn, 
                           PathOut, 
                           NameOut,
                           TRUE )) THEN
        RETURN FALSE;
    END;

    Copy(PathOut, LogFileNameLS);
    ConcatLS(     LogFileNameLS, NameOut );

    LStringToTString( LogFileNameLS, LogFileNameZS );

    Delete( LogFileNameZS, f );

    BufferCount          := 0;        (* Codes in buffer. *)

    DOSCALL(GetTime,LastHourMinute,LastSecondCent);

    InstallLight(ActiveLightRegion, 1, 6, 15, LoggerLight);
    SetString(S,"Filming");
    DisplayLight(LoggerLight,S,videolights);
    RETURN TRUE;
END StartLoggerRecording;




PROCEDURE WriteBuffer( VAR TheBuffer : ARRAY OF CARDINAL; VAR WordCount : CARDINAL ):BOOLEAN;
VAR
    WriteCount,
    High,Low,
    Count    : CARDINAL;
    res      : Response;
BEGIN
    IF (WordCount = 0) THEN RETURN TRUE; END;    (* Don't write an empty buffer. *)

    PrepareForIO(f);
    Lookup(f,LogFileNameZS,TRUE);
    res := CheckIO(f);
    IF (res <> done) THEN
        FileComplaint();
        Close(f); 
        RETURN FALSE;
    END;

        (* Find current file length. *)
    Length(f,High,Low);
    SetPos(f,High,Low);
    res := CheckIO(f);
    IF (res <> done) THEN
        FileComplaint();
        Close(f); 
        RETURN FALSE;
    END;

    WriteCount := WordCount * 2;
    WriteNBytes( f, ADR(TheBuffer), WriteCount, Count );

    res := CheckIO(f);
    IF (res <> done) OR (Count <> WriteCount) THEN
        FileComplaint;
        Close(f); 
        RETURN FALSE;
    END;
        
    Close(f); 
    WordCount := 0;  (* Clear the buffer. *)

    RETURN TRUE;

END WriteBuffer;



PROCEDURE LogThisCode( C : CARDINAL ) : BOOLEAN;
BEGIN
    IF (BufferCount < HIGH(Buffer)) THEN
        Buffer[BufferCount] := C;
        INC(BufferCount);
    END;

        (* Don't write to disk during a Break interrupt. *)

    IF (BufferCount >= LogEvery) AND (C <> BreakCode) THEN
        RETURN (WriteBuffer(Buffer, BufferCount));
    END;

    RETURN TRUE;

END LogThisCode;



PROCEDURE EndLoggerRecording();
VAR
    ok : BOOLEAN;
BEGIN
    ok := WriteBuffer(Buffer, BufferCount);
    RemoveLight(LoggerLight);
    LoggerState := Neutral;
END EndLoggerRecording;


    (* LookAhead -- Read the next character from the file, and see if
                    it will be followed by turning Break on.   The character
                    is put onto a stack.   (It should be a queue.)  *)


PROCEDURE LookAhead();
VAR
    res : Response;
    C   : CARDINAL;
BEGIN

    REPEAT
        IF (f.eof) THEN
            RETURN;
        END;
            (* If near the end of the file, slow down. *)

        PrepareForIO(f);
        ReadWord(f,C);
        res := CheckIO(f);
        IF (res <> done) THEN
            FileComplaint;
            RETURN;
        END;
        IF (C = BreakCode) THEN
            LoggerBreakFlag := TRUE;
        END; 
    UNTIL (C <> BreakCode);
    
    Buffer[BufferCount] := C;
    INC(BufferCount);
    
END LookAhead;


PROCEDURE GetLoggedCode ( VAR C : CARDINAL ) : BOOLEAN;
BEGIN
         (* Check the push stack *)
    IF (BufferCount > 0) THEN
        DEC(BufferCount);
        C := Buffer[BufferCount];
        LookAhead();
        RETURN TRUE; 
    END;

    RETURN FALSE;

END GetLoggedCode;



PROCEDURE LoggedCodeWaiting() : BOOLEAN;
BEGIN
   RETURN (NOT f.eof);
END LoggedCodeWaiting;









PROCEDURE StartLoggerPlayback():BOOLEAN;
VAR
    Path, PathIn, PathOut                 : ARRAY [0..99] OF CHAR;
    S, Device, File, Ext, NameIn, NameOut : ARRAY [0..19] OF CHAR;
    res                                   : Response;
BEGIN
    ExtractFileNameParts( LogFileNameLS, Device, Path, File, Ext );
    Copy(Device, PathIn );
    ConcatLS( PathIn, Path );
    Copy(File, NameIn );
    ConcatS( NameIn, "." );
    ConcatLS(NameIn, Ext );

    IF (NOT GetInputFile( PathIn, 
                          NameIn, 
                          PathOut, 
                          NameOut,
                          FALSE, TRUE )) THEN
        RETURN FALSE;
    END;

    Copy(PathOut, LogFileNameLS);
    ConcatLS(     LogFileNameLS, NameOut );

    LStringToTString( LogFileNameLS, LogFileNameZS );

    PrepareForIO(f);
    Lookup(f,LogFileNameZS,FALSE);
    res := CheckIO(f);
    IF (res <> done) THEN
        FileComplaint;
        RETURN FALSE;
    END;

    InstallLight(ActiveLightRegion, 1, 6, 10, LoggerLight);
    SetString(S,"Projecting");
    DisplayLight(LoggerLight,S,videolights);

    BufferCount := 0;
    LoggerBreakFlag := FALSE;
    LookAhead();

    RETURN TRUE;
END StartLoggerPlayback;




PROCEDURE EndLoggerPlayback();
VAR
    S  : ARRAY [0..30] OF CHAR;
BEGIN
    Close(f);
    RemoveLight(LoggerLight);
    LoggerState := Neutral;
END EndLoggerPlayback;







    (* GetRug and PutRug were stolen from RUGS.MOD and hacked for my own
                         devious uses.
    *)

PROCEDURE GetRug(    ULX                    : ascreenx; 
                     ULY                    : ascreeny;
                     LRX                    : ascreenx; 
                     LRY                    : ascreeny;
                 VAR ScreenBuffer           : ARRAY OF CARDINAL;
                 VAR ScreenSize             : CARDINAL);
VAR
    LineAddress : ADDRESS;
    Count       : CARDINAL;
    Y           : CARDINAL;

BEGIN
    GetCursorType(ScreenBuffer[0]);
    GetCursorLocation(ScreenBuffer[1], ScreenBuffer[2] );
        (*  Set the type because GetCursorLocation has the side-effect
            of turning the hardware cursor back on.  DOS does this.
        *)
    SetCursorType(ScreenBuffer[0]);              (* 29-Dec-87 LAA *)

        (*  Copy from the screen to the image area. *)
    LineAddress := ADR(ScreenBuffer[3]);

    ScreenSize  := 3; (* Cursor type, X and Y *)

    Count := LRX - ULX + 1;  (* Screen width *)
    Y := ULY;
    WHILE (Y <= LRY) DO
        GetImageLine(ULX,Y,Count,LineAddress);
        INC(Y);
        INC(LineAddress,Count*2);
        INC(ScreenSize,Count);
    END;

END GetRug;



PROCEDURE DisplayRug(    ULX                : ascreenx;
                         ULY                : ascreeny;
                         LRX                : ascreenx;
                         LRY                : ascreeny;
                 VAR ScreenBuffer           : ARRAY OF CARDINAL );
VAR
    LineAddress : ADDRESS;
    Count       : CARDINAL;
    Y           : CARDINAL;
    WordsUsed   : CARDINAL;

BEGIN                   (* DisplayRug *)
    SetCursorType(ScreenBuffer[0]);
    SetCursorLocation(ScreenBuffer[1], ScreenBuffer[2]);

    LineAddress := ADR(ScreenBuffer[3]);
    Count       := LRX-ULX + 1;                    (* Words per line. *)

    Y := ULY;
    WHILE (Y <= LRY) DO
        PutImageLine(ULX,Y,Count,LineAddress);
        INC(Y);
        INC(LineAddress,Count*2);
    END;
END DisplayRug;





  (* Take a Snap Shot - Take a screen shot and save it into the disk file AFTER
                        any pending buffer bytes.
  *)
PROCEDURE TakeASnapShot();
VAR
    ScreenSize   : CARDINAL;
    ok           : BOOLEAN;
BEGIN
    IF (BufferCount > 0) THEN
        ok := WriteBuffer(Buffer, BufferCount);
    END;

 (* Get current screen and save it. *)

    GetRug( 0, 0, 79, 23, ScreenBuffer, ScreenSize );
    ok := WriteBuffer(    ScreenBuffer, ScreenSize );

END TakeASnapShot;





  (* Get True File Position -

        Take into account the chars in the buffer read by LookAhead().
  *)

PROCEDURE GetTrueFilePosition( VAR H, L : CARDINAL );
VAR
    F : REAL;

CONST
    FMaxCard = 65536.0;

BEGIN
    GetPos( f, H, L );
    F := (FLOAT(H) * FMaxCard) + FLOAT(L);

    F := F - FLOAT(BufferCount*2); (* Account for chars in buffer. *)

    H := TRUNC(F / FMaxCard);
    L := TRUNC(F - (FLOAT(H) * FMaxCard));

END GetTrueFilePosition;





  (* Compare A Snap Shot - Read logged snap shot, and compare it with a CURRENT
                           screen shot.
  *)
PROCEDURE CompareASnapShot();
CONST
    Low  = 1000;
    Hi   =  300;
    Slow = 1000;
    Fast =  500;
VAR
    i, H, L,
    H2, L2,
    ScreenSize   : CARDINAL;
    Code         : ACode;
    ok           : BOOLEAN;
    s            : ARRAY [0..255] OF CHAR;

    PROCEDURE Note( Pitch : CARDINAL; Delay : CARDINAL );
    VAR
        ToneDelay,
        DelaySoFar : CARDINAL;
        F          : REAL;
    BEGIN
        IF (NOT OldKeyPress()) THEN
            ToneDelay := Delay DIV 40;
            IF (Pitch = Low) THEN ToneDelay := ToneDelay DIV 2; END;
            Tone( Pitch, ToneDelay );
            DelaySoFar := 0;
            F          := 10.0;
            WHILE (DelaySoFar < Delay) AND (NOT OldKeyPress()) DO
                INC(DelaySoFar);
                F := ((F + F) * 2.0) / (F * 0.4);
            END;
        END;
    END Note;

BEGIN
    ok := TRUE;

 (* Get current screen *)

    GetRug( 0, 0, 79, 23, ScreenBuffer, ScreenSize );

 (* Read old screen from file. *)

    GetTrueFilePosition( H, L );
    PrepareForIO(f);
    FOR i := 0 TO ScreenSize - 1 DO
        IF (NOT GetLoggedCode(OldScreen[i])) THEN RETURN; END;
        IF (OldScreen[i] <> ScreenBuffer[i]) THEN ok := FALSE; END;
    END;
    GetPos( f, H2, L2 );

    IF ok THEN
        Note( Hi,  Fast );
        Note( Low, Fast );
        Note( Hi,  Fast );
        Note( Low, Fast );
        RETURN;
    END;

 (* The buffers DO NOT compare!!

    1) Clear out the type ahead buffer and wait for a key to be pressed., playing a
       tune for them while we wait.  And wait.

    2) Based on the key pressed, do an action.
 *)

    Keyboard.FlushKeyboardBuffer();
    WHILE (NOT OldKeyPress()) DO
        Note( Low, Slow );
        Note( Hi,  Slow );
        Note( Low, Slow );
        Note( Hi,  Slow );
        Note( Low, Slow );
        Note( Hi,  Slow );
        Note( Low, Fast );
        Note( Low, Fast );
        Note( Hi,  Slow );
    END;

    Code := OldGetCode();
    WHILE (Code <> CancelKey) AND (Code <> ExitKey) DO
        CASE Code OF
            EditKey  :  (* Save new screen as the old one. *)
                Close(f);
                PrepareForIO(f);
                Lookup(f,LogFileNameZS,FALSE);
                IF (CheckIO(f) <> done) THEN
                    FileComplaint();
                    RETURN;
                END;
                SetPos(f,H,L);
                WriteNBytes(f,ADR(ScreenBuffer), ScreenSize*2,i);
                IF (CheckIO(f) <> done) OR (i <> ScreenSize*2) THEN
                    FileComplaint;
                    RETURN;
                END;
                Close(f);
                PrepareForIO(f);
                Lookup(f,LogFileNameZS,FALSE);
                IF (CheckIO(f) <> done) THEN
                    FileComplaint();
                    RETURN;
                END;
                SetPos( f, H2, L2 );

          | Fwrd :      (* Show new screen *)
                DisplayRug(0, 0, 79, 23, ScreenBuffer);
          | Reverse :   (* Show old screen *)
                DisplayRug(0, 0, 79, 23, OldScreen);
        ELSE
            SetString( s, "Valid keys are:üESC - Stop playbacküF10 - Go onü<-- - ");
            ConcatS(s,    "Old Screenü--> - New ScreenüF2  - Save NEW screen");
            Error(s);
        END;
        Code := OldGetCode();
    END;

    IF (Code = CancelKey) THEN
        EndLoggerPlayback();
    END;
    DisplayRug(0, 0, 79, 23, ScreenBuffer); (* Make sure the proper screen is up. *)

END CompareASnapShot;




PROCEDURE LoggerGetCode():CARDINAL;
VAR
    T,
    C  : CARDINAL;
    S  : ARRAY [0..30] OF CHAR;
BEGIN
    IF (LoggerInterlock > 0) THEN
        RETURN OldGetCode();
    END;

    INC(LoggerInterlock);

    LOOP
        CASE LoggerState OF
            Neutral   :
                         C := OldGetCode();
                         IF (C = LoggerRecordKey) THEN
                             IF StartLoggerRecording() THEN LoggerState := Recording; END;
                         ELSIF (C = LoggerPlaybackKey) THEN
                             IF StartLoggerPlayback()  THEN LoggerState := Playback; END;
                         ELSE
                             EXIT;
                         END;


          | Recording :
                         C := OldGetCode();

                         IF (C = LoggerRecordKey) THEN
                             EndLoggerRecording();
                         ELSIF (LogThisCode(C)) THEN
                             IF (C = SnapShotKey) THEN (* Save snapshot code too. *)
                                 TakeASnapShot();
                             ELSE
                                 EXIT;
                             END;
                         ELSE
                             EndLoggerRecording();
                             FOR T := 1000 TO 100 BY -1 DO
                                 Tone(T,2);
                             END;
                             EXIT;
                         END;

          | Playback  :
                         IF (NOT OldBreakRequested()) AND (GetLoggedCode(C)) THEN
                             IF (C = SnapShotKey) THEN (* compare screens. *)
                                 CompareASnapShot();
                             ELSE
                                 EXIT;
                             END;
                         ELSE
                             EndLoggerPlayback();
                         END;
        ELSE HALT;
        END;
    END;

    DEC(LoggerInterlock);

    RETURN C;
END LoggerGetCode;







PROCEDURE OldKeyPressDup():BOOLEAN;
BEGIN
    RETURN OldKeyPress();
END OldKeyPressDup;


    


PROCEDURE LoggerKeyPress(): BOOLEAN;
VAR
    HourMinute, SecondCent : CARDINAL;
    ok : BOOLEAN;
BEGIN
    IF (LoggerState=Playback) AND (LoggerInterlock=0) THEN
        IF (LoggedCodeWaiting()) OR (LoggerBreakRequested()) THEN
            IF (KeyPressSeen > 0) THEN (* Has this routine been called at least once before? *)
                DEC(KeyPressSeen);
                RETURN FALSE;
            ELSE
                KeyPressSeen := 5;  (* Let them ask 5 times before giving it. *)
                RETURN TRUE;
            END;
        ELSE
            EndLoggerPlayback();
        END;
    ELSIF (LoggerState=Recording) AND (LoggerInterlock=0) THEN
            (* If a key is ready, reset our timer and return TRUE. *)
        IF (OldKeyPress()) THEN
            DOSCALL(GetTime,LastHourMinute,LastSecondCent);
            RETURN TRUE;
        END;
            (* If the last key hit was a while ago, write the buffer and
               reset the timer.  Rather than fuss with fancy arithmetic,
               treat any minute boundary as a timeout. *)
        DOSCALL(GetTime,HourMinute,SecondCent);
        IF (SecondCent < LastSecondCent) OR (SecondCent - LastSecondCent > DelayTime) THEN
            IF (WriteBuffer(Buffer,BufferCount)) THEN; END;
            DOSCALL(GetTime,LastHourMinute,LastSecondCent);
        END;
        RETURN FALSE;
    END;
    RETURN OldKeyPress();
END LoggerKeyPress;






PROCEDURE LoggerBreakRequested():BOOLEAN;
BEGIN
    IF (LoggerState=Playback) AND (LoggerInterlock=0) THEN
        RETURN LoggerBreakFlag;
    ELSE
        RETURN OldBreakRequested();
    END;
END LoggerBreakRequested;




PROCEDURE LoggerClearBreak();
BEGIN
    IF (LoggerState=Playback) AND (LoggerInterlock=0) THEN
        LoggerBreakFlag := FALSE;
    END;
    OldClearBreak();
END LoggerClearBreak;





PROCEDURE LoggerBreakHandler();
BEGIN
    IF (LoggerState=Recording) AND (LoggerInterlock=0) THEN
            (* It is crucial that this not do any i/o or call DOS. *)
        IF LogThisCode(BreakCode) THEN; END;
    END;
    OldBreakHandler();
END LoggerBreakHandler;




PROCEDURE NoticeFatalError(     Occasion : AnOccasion;
                                Step     : AStep;
                                Context  : ADDRESS ):BOOLEAN;

TYPE
    AString = ARRAY [0..255] OF CHAR;
VAR
    Title : POINTER TO AString;
    S : ARRAY [0..10] OF CHAR;
BEGIN

    IF (LoggerInterlock = 0) AND (Step = BeforeActing) AND (Context <> NIL) THEN
        INC(LoggerInterlock);
        Title := Context;
        SetString(S,"Fatal");
        IF (Search(Title^,S,1) > 0) THEN
            CASE LoggerState OF
                Neutral   :
              | Recording :  EndLoggerRecording();
              | Playback  :  EndLoggerPlayback();
            END;
        END;
        DEC(LoggerInterlock);
    END;

 
    RETURN TRUE;
END NoticeFatalError;

















PROCEDURE GetLogType():CARDINAL;
VAR
    Prefix,S                       : ARRAY [0..81] OF CHAR;
    LogType                        : CARDINAL;
    Choice                         : CARDINAL;
    Found                          : BOOLEAN;
    Copyright                      : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    SetString(S,"LOGFILE");
    GetOption(S,Found,LogFileNameLS);
    IF (NOT Found) THEN
        SetString(LogFileNameLS,"TLKODAK.SNP");
    END;
    LStringToTString(LogFileNameLS,LogFileNameZS);

    SetString(Prefix,"Install KODAK SnapShot Camera?");
    SetString(S,"No,Yes");
    LogType := 1;
    IF (MenuWithPrompts(Prefix,S,15,9,65,13,ABoxType{GrowBox,DoubleBox,ShadowBox},EmptyCodeSet,
                        NoPrompts,0,AText(NIL),
                        TRUE, (* 12-Dec-89 RSC MODAL *)
                        LogType) = DoIt) THEN
        LogEvery  := 9;
        DelayTime := 900;
        RETURN LogType;
    ELSE
        RETURN 1;
    END;
END GetLogType;



BEGIN

    IF (GetLogType() > 1) THEN

        LoggerInterlock := 0;
        LoggerBreakFlag := FALSE;
        LoggerState     := Neutral;
        KeyPressSeen    := 5;
    
    
            (* Install our keystroke handler into the keystroke handling chain. *)
    
        InstallNewProcedure(ADR(Keyboard.GetAnyCode), PROC(LoggerGetCode), ADR(OldGetCode));
    
        InstallNewProcedure(ADR(Keyboard.KeyPress),PROC(LoggerKeyPress), ADR(OldKeyPress));
    
            (* Swipe all the break vectors.   New Parameter by RSC 2-Mar-89 *)

        InstallNewProcedure(ADR(Keyboard.BreakRequested), PROC(LoggerBreakRequested), ADR(OldBreakRequested));
        InstallNewProcedure(ADR(Keyboard.ClearBreak), PROC(LoggerClearBreak), ADR(OldClearBreak));
        InstallNewProcedure(ADR(Keyboard.BreakHandler), PROC(LoggerBreakHandler), ADR(OldBreakHandler));

        RegisterForNotices( WarningActive,   NoticeFatalError );
 
            (* Start main menu execution. *)
    
        Chain();
    
            (* Deinstall our keystroke handler. *)
    
            (* In case the chained-to program terminates (abnormally)
               without finishing a recording or playback session. *)
    
        CASE LoggerState OF
            Neutral   :
          | Recording :
                        EndLoggerRecording();
          | Playback  :
                        EndLoggerPlayback();
        END;
        LoggerState := Neutral;
    END;
                                    
    
END TLKodak.
