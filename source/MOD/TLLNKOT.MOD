MODULE TLLnkOT;

(*V7=TRACE*)

    (*  Summary link to On Target -- 
    *)


    (* MODIFICATION HISTORY:

       31-Jan-91 AJL  - Built from former TLLNKSUM.mod
        6-Feb-99 AJL  -Increased the size of the string used for extracting
                       the WBS number, path, etc. from the text.
        4-Mar-91 AJL  -Corrected reading of percent achieved.
        1-May-91 AJL  -Adjust OT hours of the day to best matching TL hour. 
        1-Jul-91 AJL  -Convert to Eve, which uses Quarter hours.
       14-Jul-91 AJL  -Detect date conversion failures that are from
                       dates earlier than the start of working dates.
                       Bug #4886.
       27-Sep-91 AJL  -No longer force linked tasks to ForceCritical.
       23-Mar-92 TGS - Do ANSIToOEM conversion on incoming strings.
       06-Apr-92 AJL - Since a milestone is a point in time, it cannot really
                       be started.  If it is claimed as "Started," perhaps because
                       it is the end moment of a started task, then the task may
                       be started, but the end moment is Future.  Bug 5507.

    *)

FROM Allocs                 IMPORT
    (* CONST *)                 WBSLen, WBSLine,
    (* TYPE *)                  ATaskPtr, AFixType, ARollupStatus,
                                ATask, AStartStatus, ABigDateBlock,
                                ADurationMethod, ASplittingRule,
                                ATaskStatus, AnAssignmentSummary,
                                ATaskFlag, ATaskFlagSet, ATempTaskFlagSet,
    (* VAR *)                   TaskTree,
    (* PROC *)                  CheckTaskValid;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;

FROM CalShift               IMPORT
    (* VAR  *)                  TimeSheet;

FROM Codes                  IMPORT ACode, EmptyCodeSet;

FROM Dialog                 IMPORT Message, Error, FatalError, Burp,
                                WarningBox, ADialogOption, MultipleChoiceBox,
                                NotYetImplemented;

FROM Directory              IMPORT NormalizeFileName, AFileNamePart,
                                ASetOfFileNameParts;

FROM Duration               IMPORT
    (* PROC  *)                 FindDuration;


FROM FileAux                IMPORT 
    (* PROC *)                  PrepareForIO, CheckIO, FileResultMeans,
                                DisplayFileError;


FROM FileSystem             IMPORT
                                File, Response, Close,
                                OpenFile, ReadOnlyMode, ReadNBytes,
                                ReadByte, ReadWord, SetRead, SetPos,
                                Reset;

FROM FlexStor               IMPORT
        (* TYPE *)              AnExtHandle, AnExtStoragePreference,
                                AnExtStatus,
        (* PROC *)              CreateExtObject, SetExtData, NumberOfElements,
                                ArraySize, DiscardExtObject,
                                HandleIsValid, GetExtSize, GetExtStatus,
                                LockObjectArray, SetExtSize,
                                ReleaseObject, ReleaseUnchangedObject;

FROM Foreign        IMPORT
    (* TYPE *)          ACharacterConversionTable,
    (* PROC *)          DecodeString, DoDash, ConvertString;

FROM Kbio                   IMPORT  maxcol;

FROM Keys                   IMPORT CancelKey, HelpKey, DoIt;

FROM Layout                 IMPORT MenuStart, MenuEnd;

FROM Links                  IMPORT
        (* CONST *)             LinkOverlayNameLine, LinkFileTypeLine, LinkPathLine,
        (* TYPES *)             ALinkInterface, ARollupContext,
        (* PROC *)              GetSummaryInfoLine;

FROM LStrings               IMPORT SetString, LStringToTString, ConcatLS,
                                   Copy, ConcatS, SubStr, TrimRear, CtoS,
                                   StringsEqual, Insert, SetLengthOf, LengthOf,
                                   LJust, TStringToLString, Upshift;

FROM MsgFile                IMPORT  GetMessage, ConcatMessage;

FROM ObjectID               IMPORT
    (* PROC *)                  NewID;

FROM OTFiles                IMPORT
    (* TYPE *)                  AnOnTargetTask,
    (* PROC *)                  ReadRecordPreface, ReadRecordBody,
                                SkipRecordBody, StartFileInput; 

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay, OverlayContext;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM RsrcCalc               IMPORT  SummTaskNodeAmounts;

FROM Schedule               IMPORT ProjectMedia;

FROM Space                  IMPORT  HeapAvailable, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT  ADR, SIZE, ADDRESS, TSIZE;

FROM Text                   IMPORT  TextExists, LineExists, CopyLine,
                                    Compress, AText, DiscardText;

FROM Timei                  IMPORT
    (* CONST*)                  MinDate, MaxDate, NoDuration,
    (* CONST *)                 Sun,Sat,
    (* TYPE *)                  ADate, ADuration, ATimeInfo,
    (* PROC *)                  TtoTimeU, DurationToReal, DayOfWeek,
                                TtoAbsTimeU;

FROM Timeu                  IMPORT
    (* TYPE *)                  ADayOfQtrHours,
    (* VAR *)                   FSMUPH, TimeTable, SMU,
    (* PROC *)                  UpScale, DownScale;

FROM TimeFormat             IMPORT
    (* VAR *)                   DefaultDateFormat,
                                TimeToString;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM Transfer               IMPORT
    (* TYPE *)                  AHeaderRecord;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;


(*<TRACE
FROM FlexDisp IMPORT  HandleToString;
FROM LongConvert IMPORT LongToString;
FROM TimeFormat  IMPORT
    (* TYPE *)        AnEndDateStyle,
    (* VAR   *)       DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)       TimeToString, TimeAsEndDateStyle, TimeUtoS;
FROM Tracer   IMPORT  PrintString, EndTrace;
TRACE>*)



CONST
    ModuleNumber = 16600;    (* For GetMessage *)

CONST
     FMAXCARDINAL          = 65535.0;
     Zero                  = 0.0;
     Half                = 0.5;
     OneHundred            = 100.0;



CONST
    LinkFlagsLine       = 3;  (* Choice field settings on link form *)
    LinkWBSLine         = 4;  (* WBS code (15 chars max).  *)

    ResCopyFlag     = 1;    (* TRUE iff should copy resources *)
    EffortFlag      = 2;    (* TRUE iff roll up all efforts   *)
    LinkDateFlag    = 3;    (* TRUE iff end date only         *)

TYPE  
       (* For each On Target Hour, gives the corresponding Time Line hour. *) 
    AnHourConversion = ARRAY [Sun..Sat] OF ARRAY [0..23] OF CARDINAL; 





VAR
    OverlayID           : AnOverlayID;

    HourConversion          : AnHourConversion; 

    CopyResources           : BOOLEAN;
    MakeMilestone           : BOOLEAN;

    ErrorFlag               : BOOLEAN;
    ComplainedAboutDate     : BOOLEAN;


    (*<TRACE
    TraceS : ARRAY [0..255] OF CHAR;
    TraceS2 : ARRAY [0..51] OF CHAR;
    TraceTitle : ARRAY [0..21] OF CHAR;
    TRACE>*)

    CharacterTable          : ACharacterConversionTable;


PROCEDURE LinkFlagSet (  VAR s        : ARRAY OF CHAR;
                             FlagNo   : CARDINAL      ) : BOOLEAN;
BEGIN
    RETURN (LengthOf(s) >= FlagNo) AND (s[FlagNo] = "1");
END LinkFlagSet;



PROCEDURE FileComplaint(VAR f:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);    (* "On Target file " *)
    DisplayFileError( f, s );        (* RSC 2/19/88    *)
END FileComplaint;



PROCEDURE Complain( N : CARDINAL );
VAR 
    S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(N,S);
    Error(S);
END Complain;














    (* KDate1968 -- Given the number of days beginning March 1, 1968
                    as 0, return the Year, Month and Day.
                    See the Timei module for further documentation.
                    *)


PROCEDURE KDate1968(K: LONGINT; VAR Year, Month, Day: CARDINAL);

VAR
    LYear : LONGINT;

BEGIN
    (* 16-Aug-90 RSC OLD FORMULA:

        Year := ((4 * k) -1) DIV 1461;
        Day  := 4 * k - 1 - 1461 * Year;

       NEW FORMULA:
    *)



    K := K * 4L;
    LYear := (K - 1L) DIV 1461L;
    Year  := VAL(CARDINAL,LYear);

    Day   := VAL(CARDINAL,K - 1L - (1461L * LYear));



    Day := (Day + 4) DIV 4;
    Month := (5 * Day - 3) DIV 153;
    Day := 5 * Day - 3 - 153 * Month;
    Day := (Day + 5) DIV 5;
    IF Month < 10 THEN
        Month := Month + 2
    ELSE
        Month := Month - 10;
        Year := Year + 1
    END;
    Year := Year + 1968;

END KDate1968;




PROCEDURE KDate1970(K: LONGINT; VAR Year, Month, Day: CARDINAL);
CONST
    Jan11970 = 672L;   (* Days since the base of KDate1968 *)
BEGIN
    KDate1968(K+Jan11970, Year,Month,Day);
END KDate1970;




    (* ---------------------------------------------------------------

       OTHourToHour

       Convert an OT hour and minute, representing a certain number of
       hours and minutes since the start of the OT work day, to the hour
       and minute in TL that is the same distance from the start of the 
       TL work day.

       ---------------------------------------------------------------- *)



PROCEDURE OTHourToHour(     Day : CARDINAL;
                            OTHour, OTMinute : CARDINAL;
                        VAR Hour, Minute     : CARDINAL   );
VAR
    QtrHour,
    QuartersInDay,
    QuartersRemaining : CARDINAL;
    ExtraMinutes      : CARDINAL;  (* Minutes that don't fit into quarters. *)

BEGIN
    QtrHour      := 0;
    Minute       := (OTHour * 60) + OTMinute; (* Minutes into today *)


    WITH TimeTable.WeekTable[Day] DO

        QuartersRemaining := Minute DIV 15;  (* Truncate *)
        ExtraMinutes      := Minute MOD 15;

        LOOP
            IF (NOT (QtrHour IN WeekMap) ) THEN
                IF (QuartersRemaining = 0) THEN
                    EXIT;
                END;
                DEC(QuartersRemaining);  (* One less quarter hour *)
            END;

                (* In case we are off the end of the calendar,
                   stop now.
                *)
            IF (QtrHour = 95) THEN
                EXIT;
            END;

            INC(QtrHour);
        END;
    END;

    Hour   :=   QtrHour DIV 4;       (* Which hour of the day? *)
        (* minutes = fractional hour * 15 mins *)
    Minute := ((QtrHour MOD 4) * 15) + ExtraMinutes;
END OTHourToHour;




PROCEDURE ComplainAboutDate( TimeInfo : ATimeInfo; N : CARDINAL );
VAR
    S    : ARRAY [0..255] OF CHAR;
    S2   : ARRAY [0..25] OF CHAR;
BEGIN
    IF (NOT ComplainedAboutDate) THEN
        GetMessage(N,S);
        TimeToString(TimeInfo,DefaultDateFormat,S2);
        ConcatLS(S,S2);
        Error(S);
        ComplainedAboutDate := TRUE;
    END;
END ComplainAboutDate;




PROCEDURE OnTargetDateToDate( OTDate : LONGINT ) : ADate;
CONST
    MinimumTLDate = 4384L;   (* March 1, 1980 *)
VAR
    TimeInfo : ATimeInfo;
    ElapsedHours, ElapsedDays : LONGINT;
    LN : LONGINT;
    OTHour, OTMinute : CARDINAL;
    Date : ADate;
BEGIN
    (*<TRACE
    SetString(TraceS,"OTDateToDate ");
    LongToString(OTDate,TraceS2);  ConcatLS(TraceS,TraceS2);
    PrintString(TraceS);
    TRACE>*)


        (* OTDate is 10ths of hours since January 1, 1970. *)
        (* Convert those 10ths into minutes. *)
    ElapsedHours := OTDate DIV 10L;
    LN := OTDate - (ElapsedHours * 10L);
    OTMinute := VAL(CARDINAL,LN) * 6;
    TimeInfo.tiSecond := 0;
        (* Now hours. *)
    LN := (ElapsedHours MOD 24L);
    OTHour     := VAL(CARDINAL,LN);
        (* Now Year, Month, Day *)
    ElapsedDays := ElapsedHours DIV 24L;     (* 24 hours per day. *)

        (* Get the year, month and day. *)
    WITH TimeInfo DO
        KDate1970(ElapsedDays,tiYear,tiMonth,tiDay);
    END;

    IF (ElapsedDays < MinimumTLDate) THEN
        ComplainAboutDate(TimeInfo,ModuleNumber+13);
        Date := 0;
    ELSE
        WITH TimeInfo DO
                (* Locate the equivalent working hour in TL. *) 
            OTHourToHour( DayOfWeek(tiYear,tiMonth,tiDay ),
                          OTHour, OTMinute, 
                          tiHour, tiMinute );
            (*<TRACE
            SetString(TraceS,"  Year   = "); CtoS(tiYear,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            SetString(TraceS,"  Month  = "); CtoS(tiMonth,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            SetString(TraceS,"  Day    = "); CtoS(tiDay,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            SetString(TraceS,"  Hour   = "); CtoS(tiHour,TraceS2);
              ConcatLS(TraceS,TraceS2);  
              ConcatS(TraceS,"  OTHour   = "); CtoS(OTHour,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            SetString(TraceS,"  Minute = "); CtoS(tiMinute,TraceS2);
              ConcatLS(TraceS,TraceS2);  
              ConcatS(TraceS,"  OTMinute   = "); CtoS(OTMinute,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            TRACE>*)

        END;
        IF NOT TtoAbsTimeU (TimeInfo,Date) THEN
            ComplainAboutDate(TimeInfo,ModuleNumber+14);
        ELSIF (Date <= 0) THEN
                (* If the converted date ends up at day zero, assume that
                   it was an earlier date that got rolled to the first day
                   of the calendar.  This is an accurate complaint for all
                   cased except the unlikely circumstance of a task in OT
                   starting exactly at the TL calendar day 0. *)
            ComplainAboutDate(TimeInfo,ModuleNumber+17);
        END;

    END;



      (*<TRACE
    SetString(TraceS,"  Date   = "); TimeUtoS(Date,TraceS2);
    ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
      TRACE>*)

    RETURN Date;
END OnTargetDateToDate;









PROCEDURE WBSMatches    (  WBS1, WBS2  : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
    LJust (WBS1);
    TrimRear (WBS1);
    LJust (WBS2);
    TrimRear (WBS2);
    Upshift(WBS1);
    Upshift(WBS2);
    RETURN StringsEqual (WBS1, WBS2);
END WBSMatches;


    (* Decide if a task should be part of the link summarization. *)


PROCEDURE WeWantThisTask(     ID    : CARDINAL;    
                              Level : CARDINAL;
                              DoWeReadAll : BOOLEAN;
                              WantTaskID : CARDINAL ) : BOOLEAN;
VAR
    
    Want : BOOLEAN;
BEGIN
        (* If linking to the whole schedule, take the master task. *)

    IF (DoWeReadAll) THEN
        Want := (Level = 0);
    ELSE
        (* Otherwise, we want the task if its WBS code matches the
           one passed in. *)
        Want := (ID = WantTaskID);
    END;
    
            (*<TRACE
            SetString(TraceS,"Test for Want, ID = ");
            CtoS(ID,TraceS2);  ConcatLS(TraceS,TraceS2);
            ConcatS(TraceS,", Level = ");
            CtoS(Level,TraceS2);  ConcatLS(TraceS,TraceS2);
            IF (Want) THEN SetString(TraceS2,": Yes") ELSE SetString(TraceS2,": No") END;
            ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
            TRACE>*)
    RETURN Want;
END WeWantThisTask;



PROCEDURE FindTaskIDForWBS( VAR F          : File;
                            VAR WBS : ARRAY OF CHAR;
                            VAR WantTaskID : CARDINAL ) : BOOLEAN;
VAR
    Type                    : CARDINAL;
    ID                      : CARDINAL;
    Length                  : CARDINAL;
    S                       : ARRAY [0..35] OF CHAR;
    ok                      : BOOLEAN;
BEGIN
    (* Reset to the beginning of the file and read records, looking
       for tasks we want. *)

    PrepareForIO(F);
    Reset(F);
    SetRead(F);

    IF (CheckIO(F) = done) THEN
        LOOP
            ReadRecordPreface (F,Type,ID,Length);
            IF (CheckIO(F) <> done) THEN
                EXIT;
            END;
            CASE Type OF
                0 : (* File Ender *)
                    EXIT;

              | 35 : (* A WBS Number *)
                    ReadRecordBody (F,Length,S);
                    TStringToLString(S,S);
                    ConvertString(S, CharacterTable);   (* 23-Mar-92 TGS *)
                    IF (WBSMatches(WBS,S)) THEN
                        WantTaskID := ID;
        (* Exit *)      RETURN TRUE;
                    END;
            ELSE
                SkipRecordBody(F,Length);
            END;
        END;
    END;

    RETURN FALSE;

END FindTaskIDForWBS;






PROCEDURE GetSummary(VAR F          : File;
                         Node       : ATreeNode;
                         DoWeReadAll: BOOLEAN; 
                     VAR WantMatchString : ARRAY OF CHAR;
                     VAR FirstDate,
                         LastDate   : ADate     )
                                                 : BOOLEAN;
TYPE
    AStatusSet = SET OF AStartStatus;

VAR
    OnTargetTask            : AnOnTargetTask;
    Task                    : ATaskPtr;
    Type                    : CARDINAL;
    ID, WantTaskID          : CARDINAL;
    Length                  : CARDINAL;
    TasksRead               : CARDINAL;

    CompletedSummary,
    ToGoSummary             : AnAssignmentSummary;

    PercentComplete,
    WeightedValue,
    TotalValue              : REAL;
    StatusSet               : AStatusSet;
    ok                      : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;
    DesireThisTask          : BOOLEAN;



    PROCEDURE AccumulateDates(OnTargetTask : AnOnTargetTask );
    VAR
        EarlyStart,
        EarlyEnd : ADate;
    BEGIN
            (* Extract the start and end dates, and find the earliest
               of the early dates of all tasks, and the latest of the
               end dates. *)
        EarlyStart := OnTargetDateToDate(OnTargetTask.EarlyLevelled[0]);
        EarlyEnd   := OnTargetDateToDate(OnTargetTask.EarlyLevelled[1]);
        IF (EarlyStart < FirstDate) THEN
            FirstDate := EarlyStart;
        END;
        IF (EarlyEnd > LastDate) THEN
            LastDate := EarlyEnd;
        END;
    END AccumulateDates;





        (* Processing after each task is read. *)

    PROCEDURE AccumulateProgress(    OnTargetTask : AnOnTargetTask );
    VAR
        StartStatus : AStartStatus;
        PercentAchieved : CARDINAL;
        ValueThisTask,
        PercentThisTask : REAL;
    BEGIN
            (* Get the status and percent achieved. *)
        PercentAchieved := ORD(OnTargetTask.Complete);

        IF (PercentAchieved = 0) THEN
            StartStatus := FutureS;
        ELSIF (PercentAchieved >= 100) THEN
            StartStatus := DoneS;
        ELSE
            StartStatus := StartedS;
        END;

        INCL (StatusSet, StartStatus);

            (* For computing the achieved value, summarize all tasks
               at the desired level.  *)

        PercentThisTask := FLOAT(PercentAchieved)/OneHundred;

        ValueThisTask   := 1.0;       (* Uniform weighting. *)

        WeightedValue   := WeightedValue +
                           (PercentThisTask);

        TotalValue := TotalValue + ValueThisTask;
        

    END AccumulateProgress;

BEGIN

    WeightedValue := Zero;
    TotalValue    := Zero;
    StatusSet     := AStatusSet{};
    LastDate      := MinDate;
    FirstDate     := MaxDate;
    TasksRead     := 0;        (* How many were selected for import. *)


    ok := (GetExtStatus() = ExtGood);

        (* Optionally look for a particular WBS Number. *)

    IF (NOT DoWeReadAll) THEN
        IF NOT FindTaskIDForWBS(F,WantMatchString,WantTaskID) THEN
            GetMessage(ModuleNumber+15,s);
            ConcatLS(s,WantMatchString);
            Error(s);
            ok := FALSE;
        END;
    END;
   


    (* Reset to the beginning of the file and read records, looking
       for tasks we want. *)

    PrepareForIO(F);
    Reset(F);
    SetRead(F);

    IF (ok) AND (CheckIO(F) = done) THEN
        LOOP
            ReadRecordPreface (F,Type,ID,Length);
            IF (CheckIO(F) <> done) OR (NOT ok) THEN
                ok := FALSE;
                EXIT;
            END;
            CASE Type OF
                0 : (* File Ender *)
                    EXIT;

              | 1 : (* ATask *)
                    ReadRecordBody (F,Length,OnTargetTask);
                    IF (Length <> SIZE(OnTargetTask)) THEN
                        Complain(ModuleNumber+12);
                    END;
                        (* If we know enough now to make the decision, do so. *)
                    DesireThisTask := WeWantThisTask( ID, OnTargetTask.Level,
                                                      DoWeReadAll, WantTaskID );
    
                    IF (DesireThisTask) THEN
                        AccumulateDates( OnTargetTask );
                        AccumulateProgress(OnTargetTask);
                        INC(TasksRead);
                    END;
            ELSE
                SkipRecordBody(F,Length);
            END;
        END;

            (* Summarize all the tasks. *)

        IF (TasksRead = 0) THEN            (* None selected? *)
            FirstDate := AsOfDate;
            LastDate  := AsOfDate;
        END;

        IF (FirstDate > LastDate) THEN
            FirstDate := LastDate;
        END;

        Task := Node^.Methods^.LockFlexStorDataObject (Node);

        WITH Task^.Plan.Dates DO
            EarlyEnd := LastDate;
            IF (MakeMilestone) THEN
                EarlyStart := EarlyEnd;
            ELSE
                EarlyStart := FirstDate;
            END;

            CalendarTimeToBigTime( EarlyStart, TRUE, Task^.UserEnteredStartDate );  (* 12-Sep-90 RSC *)
            CalendarTimeToBigTime( EarlyEnd,   FALSE,Task^.UserEnteredEndDate );  (* 2-Oct-90 RSC *)
            WITH Task^ DO
                StartDateUpperBound := EarlyStart; 
                StartDateLowerBound := EarlyStart; 
                SupposedToStart     := UserEnteredStartDate;
            END;

            LateTotalStart := EarlyStart;
            LateFreeStart  := EarlyStart;
            LateTotalEnd   := EarlyEnd;
            LateFreeEnd    := EarlyEnd;
            Task^.duration := FindDuration( EarlyStart, EarlyEnd, TimeSheet );

            (*<TRACE
            SetString(TraceS,"  EarlyStart = "); TimeUtoS(EarlyStart,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            SetString(TraceS,"  EarlyEnd = "); TimeUtoS(EarlyEnd,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            TRACE>*)
        END;

        IF (StartedS IN StatusSet) OR
           (  ( StatusSet * AStatusSet{FutureS,DoneS}) = AStatusSet{FutureS,DoneS} ) THEN
            Task^.StartStatus := StartedS;
        ELSIF ( StatusSet = AStatusSet{DoneS}) THEN
            Task^.StartStatus := DoneS;
        ELSE
            Task^.StartStatus := FutureS;
        END;

            (* Compute the percent achieved.
            
               Since a milestone is a point in time, it cannot really
               be started.  If it is claimed as "Started," perhaps because
               it is the end moment of a started task, then the task may
               be started, but the end moment is Future. *)

        IF (TasksRead = 0) OR (TotalValue = Zero) THEN
            Task^.PercentComplete := 0;
            IF (TasksRead = 0) THEN
                Complain(ModuleNumber+16);
            END;

        ELSIF (Task^.Plan.Dates.EarlyStart = Task^.Plan.Dates.EarlyEnd) AND
              (Task^.StartStatus = StartedS) THEN

            Task^.StartStatus := FutureS;
            Task^.PercentComplete := 0;

        ELSE
            PercentComplete := (OneHundred * WeightedValue / TotalValue) + Half;
            IF (PercentComplete >= FMAXCARDINAL) THEN
                Task^.PercentComplete := MAX(CARDINAL);
            ELSE
                Task^.PercentComplete := TRUNC(PercentComplete);
            END;
        END;


        (*--- AJL 9/27/91  Allow users to set any attributes.
        Task^.TaskFlags := Task^.TaskFlags + ATaskFlagSet{NoSoonerStart,
                                                          NoLaterStart,
                                                          ForceCritical};
        ----*)

        Task^.TempTaskFlags := ATempTaskFlagSet{};

        Node^.Methods^.UnlockFlexStorDataObject (Node);

        SummTaskNodeAmounts (Node, FALSE, CompletedSummary, ToGoSummary);

        Task := Node^.Methods^.LockFlexStorDataObject (Node);
        Task^.CompletedSummary := CompletedSummary;
        Task^.ToGoSummary      := ToGoSummary;
        Node^.Methods^.UnlockFlexStorDataObject (Node);

    ELSE
        ok := FALSE;
    END;

    IF (NOT ok) THEN
        Complain(ModuleNumber+5);   (*  "Missing summary data."  *)
    END;

    RETURN ok;

END GetSummary;







PROCEDURE GetRollupDates (VAR f         : File;
                              Node      : ATreeNode;
                              DoWeReadAll : BOOLEAN;
                          VAR WantMatchString : ARRAY OF CHAR );
VAR
    s           : ARRAY [0..201] OF CHAR;
    summarizes  : ARRAY [0..99]  OF CHAR;
    Version     : CARDINAL;
    StartDate,
    EndDate     : ADate;
    Task        : ATaskPtr;
    ok          : BOOLEAN;
BEGIN

    CheckTaskValid(Node);    (* Check for and catch any totally 
                                bananas data corruption. *)

    GetSummaryInfoLine (Node, LinkPathLine, summarizes);

    GetMessage(ModuleNumber+6,s);   (*  "Now reading rollup file "  *)
    ConcatLS(s, summarizes);
    ConcatMessage(s,ModuleNumber+7);   (*  ' for task '  *)
    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    ConcatLS(s,Task^.taskname);
    Node^.Methods^.UnlockFlexStorDataObject (Node);
    ConcatS(s,".");
    Message(s);

        (* Read in the summary data. *)

    ok := (GetSummary(f,Node,DoWeReadAll,WantMatchString,StartDate,EndDate)) AND
          (CheckIO(f) = done);

    CheckTaskValid(Node);    (* Check for and catch any totally 
                                bananas data corruption. *)


    Task := Node^.Methods^.LockFlexStorDataObject (Node);

    WITH Task^ DO
        IF (ok) THEN
            rollupstatus := RollupLoaded;
            INCL (TaskStatusSet, NeedsRecalculate);

                (* 14-Sep-90 RSC Try to better hold the task.
                *)
            (* fixation       := FixedDate;  removed 9-21-91 AJL *)

            DurationMethod := DurationDriven;
            SplittingRule  := Split;
        ELSE
            Task^.rollupstatus := RollupLoadError;
        END;
    END;

    Node^.Methods^.UnlockFlexStorDataObject (Node);

    IF (CheckIO(f) <> done) THEN
        FileComplaint( f );
    END;

    s[0] := 0C;
    Message(s);

END GetRollupDates;





PROCEDURE TLLnkOTBody();

TYPE
    AContextPtr     = POINTER TO ARollupContext;
VAR
    ContextPtr      : AContextPtr;
    TaskPtr         : ATaskPtr;
    s               : ARRAY [0..99] OF CHAR;
    MaxTaskNumber   : CARDINAL;
    DoWeReadAll     : BOOLEAN;

BEGIN                       (* TLLnkSumBody *)

    s := "Program Copyright (c) 1991 Symantec Corporation.";
    ContextPtr := AContextPtr(OverlayContext());

    ErrorFlag              := FALSE;
    ComplainedAboutDate    := FALSE;

    WITH ContextPtr^ DO

        GetSummaryInfoLine (Node, LinkFlagsLine, s);
        IF (LengthOf(s) = 0) THEN
            SetString (s, "100");
        END;
        MakeMilestone := LinkFlagSet (s, LinkDateFlag);
        CopyResources := LinkFlagSet (s, ResCopyFlag) AND (NOT MakeMilestone);  (* 11/28/89 EGK *)

           (* Look at the line which specifies which tasks to include.
              If blank, take all tasks. *)
            
        GetSummaryInfoLine (Node, LinkWBSLine, s);
        DoWeReadAll := (LengthOf(s)=0);

            (* Read the source schedule. *)

        IF (StartFileInput (f,MaxTaskNumber)) THEN        (* Check for bad format *)
            GetRollupDates (f, Node, DoWeReadAll, s );
        ELSE
            TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
            (* DiscardText (TaskPtr^.summarizes); *)
            TaskPtr^.summarizes := AText(NIL);
            TaskPtr^.rollupstatus := NotRollup;
            Node^.Methods^.UnlockFlexStorDataObject (Node);
        END;
    END;


END TLLnkOTBody;


    (* Build the character translation table used to do ANSIToOEM
        conversion. *)

PROCEDURE BuildCharacterTable ();
VAR 
    i               : CARDINAL; 
    From            : ARRAY [0..199] OF CHAR; 
    To              : ARRAY [0..127] OF CHAR; 
    Pos             : CARDINAL; 

BEGIN 
    i := 0;
    Pos := 0; 

    LOOP
        IF (Pos > 255) THEN 
            EXIT; 
        END;

        GetMessage (6020+i, From);  

        IF (LengthOf(From) = 0) THEN
            EXIT; 
        END;
        DecodeString (From, To);
        DoDash (To, CharacterTable, Pos); 
        INC (i);
    END;
END BuildCharacterTable;


BEGIN                       (* TLLnkSum *)
    BuildCharacterTable();

    OverlayID := ImAnInstallableOverlay(TLLnkOTBody, AnOverlayProc(NIL));
    TLLnkOTBody();

    (*<TRACE
    EndTrace();
    TRACE>*)

END TLLnkOT.




