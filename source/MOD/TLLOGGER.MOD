MODULE TLLogger;

    (* MODIFICATION HISTORY:

     2-Mar-89   RSC - Changed parameters to "InstallNewProcedure".
     7-Mar-89   RSC - Changed parameters to "InstallNewProcedure".
     09-Aug-89  KKC - Add copyright message.
     12-Dec-89  RSC - support for new menu parameter.
     25-Dec-90  AJL - Add new overlay locking calls.
     12-Apr-91  RSC - MenuWithPrompt changes.
    
    *)


    FROM Boxes    IMPORT ABoxType, ABoxAttribute;

    FROM Chainer  IMPORT Chain;

    FROM Clock    IMPORT Delay, NoEarlyExit;

    FROM Codes  IMPORT ACode, ASetOfCodes, EmptyCodeSet;

    FROM Dialog   IMPORT Message, FatalError, Burp, Error,
                         NotYetImplemented;

    FROM FileSystem   IMPORT File, Close, Response, SetPos, GetPos,
                             SetRead, SetWrite, SetModify, Lookup,
                             WriteWord, ReadWord, Delete, Length,
                             WriteNBytes;

    FROM FileAux      IMPORT PrepareForIO, CheckIO, 
                             DisplayFileError;

    FROM Kbio     IMPORT avidmode, Tone;

    FROM Keys     IMPORT DoIt;

    IMPORT Keyboard;

    FROM Lights   IMPORT ActiveLightRegion, ALight, InstallLight,
                         RemoveLight, DisplayLight, EnableLights;

    FROM LStrings IMPORT Fill, SetString, Search, CtoS, ConcatS, ConcatLS,
                         LStringToTString, Compare, Copy, Upshift;

    FROM Menus    IMPORT NoYes, MenuWithPrompts, APromptType;

    (* FROM MsgFile  IMPORT GetMessage;  *)

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

    FROM ParmLine               IMPORT
        (* PROC *)                  GetOption;

    FROM SYSTEM                 IMPORT ADDRESS, ADR, DOSCALL;

FROM Text           IMPORT
    (* TYPE *)          AText;



    (* Keyboard ----> Logger Facility -----> Application  *)




CONST
    DefaultLogFileName= "TLLOGGER.DAT";
    BreakCode         = 0FFFFH;             (* Internal Signal *)
    GetTime = 02CH;                       (* MS-DOS function *)

TYPE
    ALoggerState     = (Neutral, Recording, Playback);


VAR
    OldGetCode              : Keyboard.AGetCodeProcedure;
    OldKeyPress             : Keyboard.AYesNoProcedure;
    OldFlushKeyboardBuffer  : Keyboard.AServiceProcedure;
    OldBreakRequested       : Keyboard.AYesNoProcedure;
    OldClearBreak           : Keyboard.AServiceProcedure;
    OldBreakHandler         : Keyboard.AServiceProcedure;
    OverlayID               : AnOverlayID;


    LogFileNameLS, LogFileNameZS : ARRAY [0..60] OF CHAR;

    LastHourMinute, LastSecondCent : CARDINAL;
    LoggerInterlock         : CARDINAL;
    LoggerLight             : ALight;
    LoggerState             : ALoggerState;
    f                       : File;  
    i                       : CARDINAL;   (* Log Buffer index. *)
    LogEvery,                             (* Write to disk every so many keystrokes. *)
    DelayTime               : CARDINAL;   (* Write to disk if no keystrokes for n/100 seconds. *)
    Buffer                  : ARRAY [1..50] OF CARDINAL;
    RecentHistory           : ARRAY [0..63] OF CARDINAL;
    HistoryIndex            : CARDINAL;
    LoggerBreakFlag         : BOOLEAN;    (* Break was hit.  Signal during playback. *)
    InitFlag                : BOOLEAN;
    






    (* Procedures for keystroke logging. *)


PROCEDURE FileComplaint;
VAR
    s  : ARRAY [0..80] OF CHAR;
BEGIN
    SetString(s,"LOG FILE ");
    ConcatLS(s,LogFileNameLS);
    DisplayFileError(f,s);
END FileComplaint;





PROCEDURE StartLoggerRecording() : BOOLEAN;
VAR
    S  : ARRAY [0..30] OF CHAR;
    res : Response;

BEGIN
    PrepareForIO(f);
    Lookup(f,LogFileNameZS,TRUE);
    res := CheckIO(f);
    CASE (res) OF
        notdone, unknownfile : ;
          |
        done :  Close(f);
                PrepareForIO(f);
                Delete(LogFileNameZS,f);
                IF (CheckIO(f) <> done) THEN
                    FileComplaint;
                    Close(f);
                    RETURN FALSE;
                END;
        ELSE    FileComplaint;
                Close(f);
                RETURN FALSE;
    END;

    i          := 0;        (* Codes in buffer. *)

    DOSCALL(GetTime,LastHourMinute,LastSecondCent);

    InstallLight(ActiveLightRegion, 1, 6, 15, LoggerLight);
    SetString(S,"Log");
    DisplayLight(LoggerLight,S,videolights);
    RETURN TRUE;
END StartLoggerRecording;




PROCEDURE WriteBuffer():BOOLEAN;
VAR
    res : Response;
    High,Low : CARDINAL;
    Count : CARDINAL;
BEGIN
    IF (i = 0) THEN RETURN TRUE; END;    (* Don't write an empty buffer. *)


    PrepareForIO(f);
    Lookup(f,LogFileNameZS,TRUE);
    res := CheckIO(f);
    IF (res <> done) THEN
        FileComplaint();
        Close(f); 
        RETURN FALSE;
    END;

    PrepareForIO(f);
        (* Find current file length. *)
    Length(f,High,Low);
    SetWrite(f);               (* Position to eof. *)
    SetPos(f,High,Low);
    res := CheckIO(f);
    IF (res <> done) THEN
        FileComplaint();
        Close(f); 
        RETURN FALSE;
    END;

    PrepareForIO(f);

    WriteNBytes(f,ADR(Buffer),i*2,Count);

    res := CheckIO(f);
    IF (res <> done) OR (Count <> i*2) THEN
        FileComplaint;
        Close(f); 
        RETURN FALSE;
    END;

    i := 0;                (* Empty the buffer. *)

    Close(f); 

    RETURN TRUE;
END WriteBuffer;



PROCEDURE LogThisCode( C : CARDINAL ) : BOOLEAN;
VAR
    ok : BOOLEAN;
BEGIN
        (* To help the PMD, keep recent codes in memory. *)
    RecentHistory[ HistoryIndex ] := C;
    HistoryIndex := HistoryIndex + 1;
    IF (HistoryIndex > HIGH(RecentHistory)) THEN
        HistoryIndex := 0;
    END;

    IF (i < HIGH(Buffer)) THEN INC(i); END;
    Buffer[i] := C;

        (* Don't write to disk during a Break interrupt. *)

    IF (i >= LogEvery) AND (C <> BreakCode) THEN
        ok := WriteBuffer();
        RETURN ok;
    END;

    RETURN TRUE;
END LogThisCode;



PROCEDURE EndLoggerRecording();
VAR
    ok : BOOLEAN;
BEGIN
    ok := WriteBuffer();
    RemoveLight(LoggerLight);
END EndLoggerRecording;


    (* LookAhead -- Read the next character from the file, and see if
                    it will be followed by turning Break on.   The character
                    is put onto a stack.   (It should be a queue.)  *)


PROCEDURE LookAhead();
CONST
    SmallNumber = 50;
VAR
    res : Response;
    C, UserC   : CARDINAL;
    FH,FL,H,L : CARDINAL;
    S   : ARRAY [0..45] OF CHAR;
    S2  : ARRAY [0..9] OF CHAR;
BEGIN

    REPEAT
        IF (f.eof) THEN
            RETURN;
        END;

        PrepareForIO(f);
        ReadWord(f,C);
        res := CheckIO(f);
        IF (res <> done) THEN
            FileComplaint;
            RETURN;
        END;


            (* If near the end of the file, slow down. *)

        INC(LoggerInterlock);

        PrepareForIO(f);
        Length(f,FH,FL);
        GetPos(f,H,L);
        IF (H = FH) AND ((FL - L) DIV 2 <= SmallNumber) THEN
               (* Display a countdown and the key code. *)
            CtoS((FL-L) DIV 2,S);
            ConcatS(S,": ");
            IF (C = BreakCode) THEN
                ConcatS(S,"{Break}");
            ELSE
                CtoS(C,S2);
                ConcatLS(S,S2);
            END;
            DisplayLight(LoggerLight,S,videolights);
            IF ((FL - L) DIV 2 = SmallNumber) THEN
                SetString(S,"Ready for last few keys.");
                Error(S);
            END; 
            Delay(200,OldKeyPressDup);     (* Wait 2 secs or until a key is pressed. *)
            IF (OldKeyPressDup()) AND (NOT OldBreakRequested()) THEN
                UserC := OldGetCode();         (* Eat the key, but never eat a Break! *)
            END; 
        END;

        DEC(LoggerInterlock);



        IF (C = BreakCode) THEN
            LoggerBreakFlag := TRUE;
        END; 
    UNTIL (C <> BreakCode);
    
    INC(i);
    Buffer[i] := C;
    
END LookAhead;


PROCEDURE GetLoggedCode ( VAR C : CARDINAL ) : BOOLEAN;
BEGIN
         (* Check the push stack *)
    IF (i > 0) THEN
        C := Buffer[i];
        DEC(i);
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
    S  : ARRAY [0..30] OF CHAR;
    res : Response;
BEGIN
    PrepareForIO(f);
    Lookup(f,LogFileNameZS,FALSE);
    res := CheckIO(f);
    IF (res <> done) THEN
        FileComplaint;
        RETURN FALSE;
    END;

    InstallLight(ActiveLightRegion, 1, 6, 10, LoggerLight);
    SetString(S,"LogPlay");
    DisplayLight(LoggerLight,S,videolights);

    i := 0;
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
                         EXIT;

          | Recording :
                             C := OldGetCode();

                             IF (LogThisCode(C)) THEN
                             ELSE
                                 LoggerState := Neutral;
                                 EndLoggerRecording();
                                 FOR T := 1000 TO 100 BY -1 DO
                                     Tone(T,2);
                                 END;
                             END;
                             EXIT;

          | Playback  :
                         IF (NOT OldBreakRequested()) AND (GetLoggedCode(C)) THEN
                             EXIT;
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
            RETURN TRUE;
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
            IF (WriteBuffer()) THEN; END;
            DOSCALL(GetTime,LastHourMinute,LastSecondCent);
        END;
        RETURN FALSE;
    END;
    RETURN OldKeyPress();
END LoggerKeyPress;






PROCEDURE LoggerFlushKeyboardBuffer;
BEGIN
    IF (LoggerInterlock > 0) OR (LoggerState = Playback) THEN
        (* *)
    ELSE
        OldFlushKeyboardBuffer;
    END;
END LoggerFlushKeyboardBuffer;







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
        OldClearBreak();
    ELSE
        OldClearBreak();
    END;
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
    S,S2 : ARRAY [0..21] OF CHAR;
    Title : POINTER TO AString;
    i : CARDINAL;
BEGIN

    IF (LoggerInterlock = 0) AND (Step = BeforeActing) AND (Context <> NIL) THEN
        INC(LoggerInterlock);
        Title := Context;
        Copy(Title^,S);
        Upshift(S);
        SetString(S2,"FATAL");
        i := Search(S,S2,1);
        IF (i > 0) THEN
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
        SetString(LogFileNameLS,"TLLOGGER.DAT");
    END;
    LStringToTString(LogFileNameLS,LogFileNameZS);

    SetString(Prefix,"Install Logger?");
    SetString(S,"No,Record,Playback");
    LogType := 1;
    IF (MenuWithPrompts(Prefix,S,10,8,60,14,ABoxType{DoubleBox,ShadowBox},EmptyCodeSet,
                        NoPrompts,0,AText(NIL),
                        TRUE,   (* 12-Dec-89 RSC MODAL *)
                        LogType) = DoIt) THEN
        IF (LogType = 2) THEN
            HistoryIndex := 0;
            SetString(Prefix,"Buffer size");
            SetString(S,"1,2,3,4,5,6,7,8,9");
            LogEvery := 4;
            IF (MenuWithPrompts(Prefix,S,10,8,60,14,ABoxType{DoubleBox,ShadowBox},EmptyCodeSet,
                                NoPrompts,0,AText(NIL),
                                TRUE,   (* 12-Dec-89 RSC MODAL *)
                                LogEvery) = DoIt) THEN
                SetString(Prefix,"Delay in seconds");
                SetString(S,"0,1,2,3,4,5,6,7,8,9");
                DelayTime := 6;
                IF (MenuWithPrompts(Prefix,S,10,8,60,14,ABoxType{DoubleBox,ShadowBox},EmptyCodeSet,
                                    NoPrompts,0,AText(NIL),
                                    TRUE,   (* 12-Dec-89 RSC MODAL *)
                                    DelayTime) = DoIt) THEN
                    DelayTime := (DelayTime-1) * 100;                                
                    RETURN LogType;
                ELSE
                    RETURN 1;
                END;
                RETURN LogType;
            ELSE
                RETURN 1;
            END;
        ELSE
            RETURN LogType;
        END;
    ELSE
        RETURN 1;
    END;
END GetLogType;





PROCEDURE RockAndRoll();
BEGIN
    IF (InitFlag) THEN
        RETURN;
    END;
    InitFlag := TRUE;
    LoggerState := Neutral;


    i := GetLogType();
    IF (i > 1) THEN

        LoggerInterlock := 0;
        LoggerBreakFlag := FALSE;


    
    
            (* Install our keystroke handler into the keystroke handling chain. *)
    
        InstallNewProcedure(ADR(Keyboard.GetAnyCode), PROC(LoggerGetCode), ADR(OldGetCode));
        InstallNewProcedure(ADR(Keyboard.KeyPress),PROC(LoggerKeyPress),   ADR(OldKeyPress));
        InstallNewProcedure(ADR(Keyboard.FlushKeyboardBuffer),LoggerFlushKeyboardBuffer, ADR(OldFlushKeyboardBuffer));
    
            (* Swipe all the break vectors.

                2-Mar-89  RSC   New parameters.
            *)

        InstallNewProcedure(ADR(Keyboard.BreakRequested), PROC(LoggerBreakRequested), ADR(OldBreakRequested));
        InstallNewProcedure(ADR(Keyboard.ClearBreak),     PROC(LoggerClearBreak),     ADR(OldClearBreak));
        InstallNewProcedure(ADR(Keyboard.BreakHandler),   PROC(LoggerBreakHandler),   ADR(OldBreakHandler));



        CASE i OF
            2  :  IF StartLoggerRecording() THEN LoggerState := Recording; END;
          | 3  :  IF StartLoggerPlayback() THEN LoggerState := Playback; END;
        END;  

        RegisterForNotices( WarningActive,   NoticeFatalError );
        RegisterForNotices( DialogActive,    NoticeFatalError );
 
    
    END;
END RockAndRoll;







PROCEDURE ShutDown();
BEGIN
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
END ShutDown;





BEGIN
    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), ShutDown );

    InitFlag := FALSE;

            (* Start main menu execution. *)
    RockAndRoll();

END TLLogger.
