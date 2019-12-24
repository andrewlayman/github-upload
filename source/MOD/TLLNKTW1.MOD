MODULE TLLnkTW1;

(*V7=TRACE*)

    (*  Summary link to Time Line Windows -- 
    *)


    (* MODIFICATION HISTORY:

       15-Jan-92 AJL  -Built this from TLLnkOT and TLLnkSum.
                       Known limits: 
                         1.  All resources of the source schedule
                             are imported, even if they are not used
                             on a linked task.
                         2.  Not all the text columns of a resource
                             are copied across.
       29-Jan-92 AJL  - Changed rate parameters to REAL.
     3-Mar-92 TGS   Move GetResources and other such stuff to ImpTLWindows,
                    so it can be shared with importer.
    10-Mar-92 TGS   Move TLWin1DateToDate stuff to IMPTLWindows.
    19-Mar-92 TGS   Interface to GetResources() changed, as well as the
                    definition of ResourceTable.
    20-Mar-92 TGS   Added FixedCostNode parameter to GetResources(). This
                    points to an arbitrarily created Fixed Cost resource
                    that can be used to hook TLWin's "other" task costs to.
    20-Mar-92 TGS   Only run DeallocateCorrelationTable() if we ran
                    GetResources() (else there's nothing to deallocate, ha).
    25-Mar-92 TGS   If this is a unit cost, don't mess with the percent
                    stuff.
    27-Mar-92 TGS   We were reporting a file error even after encountering
                    a non-file error. Bug 5464.
    06-Apr-92 AJL - Since a milestone is a point in time, it cannot really
                    be started.  If it is claimed as "Started," perhaps because
                    it is the end moment of a started task, then the task may
                    be started, but the end moment is Future.  Bug 5507.
    08-Apr-92 TGS   If we ran out of memory while allocating the Task and
                    Date arrays, we were deallocating the memory on the spot
                    (good), but then later on, tried to deallocate the memory
                    again (bad). Bug 5537.
    16-Apr-92 AJL - Sum the spent and remaining effort and cost explicitly
                    rather than computing it from the varying assignment
                    arrays.  The trouble was that different tasks in the 
                    rolled-in schedule might have different end-of-spent
                    dates, leading to ambiguity over which portions of the
                    composite profile represented spent vs remaining effort.
                  - Modify the WeWantThisTask proc so that it does not change
                    the CollectPerformanceLevel.  It had been double counting
                    children when CopyResources was FALSE.
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

FROM Assignments            IMPORT
        (* TYPE *)              AnAssignmentAttribute, AnAssignmentAttributeSet,
                                AnAssignmentRecord, AnAssignmentArray,
        (* PROC *)              RemoveAssignmentsAndExpenses, InitAssignment,
                                CopyOneAssignmentRecord;

FROM BigTimeU               IMPORT
                                MINBIGTIME;

FROM CalShift               IMPORT
    (* VAR  *)                  TimeSheet;

FROM Codes                  IMPORT ACode, EmptyCodeSet;

FROM CorTable               IMPORT 
    (* TYPE *)                  ACorrelationTable,
    (* PROC *)                  AddTableEntry, CreateCorrelationTable,
                                DisposeCorrelationTable, FindEntryByID;

FROM DateLists              IMPORT
    (* PROC *)                  CreateDateList;   

FROM Dialog                 IMPORT Message, Error, FatalError, Burp,
                                WarningBox, ADialogOption, MultipleChoiceBox,
                                NotYetImplemented, ErrorPhrase;

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
                                CreateExtObjectWithSize,
                                ReleaseObject, ReleaseUnchangedObject;

FROM ImpTLWindows           IMPORT
    (* PROC *)                  GetResources, TLWin1DateToDate;

FROM Kbio                   IMPORT  maxcol;

FROM Keys                   IMPORT CancelKey, HelpKey, DoIt;

FROM Layout                 IMPORT MenuStart, MenuEnd;

FROM Links                  IMPORT
        (* CONST *)             LinkOverlayNameLine, LinkFileTypeLine, LinkPathLine,
        (* TYPES *)             ALinkInterface, ARollupContext,
        (* PROC *)              GetSummaryInfoLine;

FROM LinkSupport            IMPORT
    (* TYPE *)                  A4ByteReal,
    (* PROC *)                  MergeVaryingAssignmentLists,
                                NewPercent, Convert4ByteReal;

FROM LongConvert            IMPORT
    (* PROC *)                     LongToReal;

FROM LStrings               IMPORT SetString, LStringToTString, ConcatLS,
                                   Copy, ConcatS, SubStr, TrimRear, CtoS,
                                   StringsEqual, Insert, SetLengthOf, LengthOf,
                                   LJust, TStringToLString, Upshift, TrimFront;

FROM MsgFile                IMPORT  GetMessage, ConcatMessage;

FROM RsrcMod                IMPORT  AResourcePointer, ACostStyle,
                                    ResourceNameLength, CreateResource,
                                    AddResource, AResource,
                                    ChangedResource, ResourceTree,
                                    AResourceType,
                                    FindResourceByName, FindResourceByNumber;
                                    

FROM ObjectID               IMPORT
    (* PROC *)                  NewID;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay, OverlayContext;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Progress               IMPORT
    (* TYPE *)                      AThermometer,
    (* PROC *)                      CreateThermometer, UpdateThermometer, 
                                    DiscardThermometer;

FROM RateLists              IMPORT
    (* PROC *)                      CreateRateList;

FROM RealFormat             IMPORT FormatAsAmount, DefaultAmountFormat;

FROM ResCalUI               IMPORT 
    (* TYPE *)                      AnAvailabilityRate;

FROM RsrcCalc               IMPORT  SummTaskNodeAmounts;

FROM Schedule               IMPORT  ProjectMedia;

FROM Space                  IMPORT  HeapAvailable,
                                    Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT  ADR, SIZE, ADDRESS, TSIZE;

FROM Text                   IMPORT  TextExists, LineExists, CopyLine,
                                    Compress, AText, DiscardText;

FROM Timei                  IMPORT
    (* CONST*)                  MinDate, MaxDate, NoDuration,
    (* CONST *)                 Sun,Sat,
    (* TYPE *)                  ADate, ADuration, ATimeInfo, ADurationUnit,
                                ADurationCounter,
    (* PROC *)                  TtoTimeU, DurationToReal, DayOfWeek,
                                TtoAbsTimeU;

FROM Timeu                  IMPORT
    (* TYPE *)                  ADayOfQtrHours,
    (* VAR *)                   FSMUPH, TimeTable, SMU,
    (* PROC *)                  UpScale, DownScale;

FROM TimeFormat             IMPORT
    (* VAR *)                   DefaultDateFormat,
                                DefaultDateAndTimeFormat, EndDateStyle,
    (* TYPE *)                  AnEndDateStyle,
    (* PROC  *)                 TimeAsEndDateStyle, TimeUtoS,
                                TimeToString;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM TLW1File               IMPORT
    (* TYPE *)                  AKindOfFile, ATLWinTask, ATLWinResource,
                                AFileHeaderRecord, ATLWinAssignment,
    (* PROC *)                  ReadRecordPreface, ReadRecordBody,
                                ReadStringBody, SetKindOfFile, SkipRecordBody,
                                StartFileInput; 

FROM Transfer               IMPORT
    (* TYPE *)                  AHeaderRecord;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder,
    (* PROC *)                  ValidateTreeNode;

FROM VaryAssgnment          IMPORT
    (* TYPE *)                  AVaryingAssgnList,
    (* PROC *)                  CreateVaryingAssgnListRange,
                                DisposeVaryingAssgnList;

(*<TRACE
FROM LongConvert IMPORT LongToString;
FROM Tracer   IMPORT  PrintString, EndTrace;
TRACE>*)



CONST
    ModuleNumber = 30600;    (* For GetMessage, shared with TLVUTW1 and TLW1FILE *)

CONST
     FMAXCARDINAL          = 65535.0;
     MAXCARDINAL           = 65535;
     Zero                  = 0.0;
     Half                  = 0.5;
     OneHundred            = 100.0;

CONST
    LinkFlagsLine       = 3;  (* Choice field settings on link form *)
    LinkWBSLine         = 4;  (* WBS code (15 chars max).  *)

    ResCopyFlag     = 1;    (* TRUE iff should copy resources *)
    EffortFlag      = 2;    (* TRUE iff roll up all efforts   *)
    LinkDateFlag    = 3;    (* TRUE iff end date only         *)
    MaxTaskID       = 10001;  (* We cannot summarize more than this many tasks,
                                 or tasks numbered higher than this. *)

TYPE  
       (* For each Time Line Windows Hour, gives the corresponding Time Line hour. *) 
    AnHourConversion = ARRAY [Sun..Sat] OF ARRAY [0..23] OF CARDINAL; 
    
    ATasksWantedSet = ARRAY [0..(MaxTaskID DIV 16)] OF BITSET;   (* Possible Task IDs *)
    ATasksWantedSetPointer = POINTER TO ATasksWantedSet;

    ADateArray             = ARRAY [0..MaxTaskID] OF ADate;
    ADateArrayPointer      = POINTER TO ADateArray;




VAR
    OverlayID           : AnOverlayID;

    WantedLevel,                          (* Set to cause child tasks to be processed. *)
    CollectPerformanceLevel : CARDINAL;

    HourConversion          : AnHourConversion; 

    CopyResources           : BOOLEAN;
    MakeMilestone           : BOOLEAN;
    DisposeTasksWantedArrays: BOOLEAN;  (* 9-Apr-92 TGS *)

    ErrorFlag               : BOOLEAN;

    FileHeaderRecord        : AFileHeaderRecord;

    ResourceTable           : ACorrelationTable;

    TasksWanted             : ATasksWantedSetPointer;
    StartDates,
    EndDates                : ADateArrayPointer;

    FixedCostNode           : ATreeNode;

    (*<TRACE
    TraceS : ARRAY [0..255] OF CHAR;
    TraceS2 : ARRAY [0..51] OF CHAR;
    TraceTitle : ARRAY [0..21] OF CHAR;
    TRACE>*)



PROCEDURE LinkFlagSet (  VAR s        : ARRAY OF CHAR;
                             FlagNo   : CARDINAL      ) : BOOLEAN;
BEGIN
    RETURN (LengthOf(s) >= FlagNo) AND (s[FlagNo] = "1");
END LinkFlagSet;



PROCEDURE FileComplaint(VAR f:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);    (* "Time Line Windows file " *)
    DisplayFileError( f, s );        (* RSC 2/19/88    *)
END FileComplaint;



PROCEDURE Complain( N : CARDINAL );
VAR 
    S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(N,S);
    Error(S);
END Complain;




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
        (* All children of a wanted task are wanted, and they are
           stored sequentially in the file, following their parent.
           In order to read dates, we can just take the task with
           the matching WBS number, but to read resources, we need
           to read all the subtasks assignments. *)

    IF (Level = WantedLevel) THEN
        RETURN TRUE;
    ELSIF (Level > WantedLevel) THEN
        RETURN CopyResources;
    END;


        (* If linking to the whole schedule, take the master task. *)

    IF (DoWeReadAll) THEN
        Want := (Level = 0);
    ELSE
        (* Otherwise, we want the task if its WBS code matches the
           one passed in. *)
        Want := (ID = WantTaskID);
    END;
    
        (* If we decide that we want a task, we also will want its
           children.  If we don't want a task, we don't want any
           tasks consequent to it. *)
    IF (Want) THEN
        WantedLevel := Level+1;          (* Read all subtasks. *)
        CollectPerformanceLevel := Level;    (* But take the achievement of this task only. *)
    ELSE
        WantedLevel := MAX(CARDINAL);
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
    Length                  : LONGINT;
    Type                    : CARDINAL;
    ID                      : CARDINAL;
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
                    ReadStringBody (F,Length,S);
                    IF (WBSMatches(WBS,S)) THEN
                        WantTaskID := ID;
        (* Exit *)      RETURN TRUE;
                    END;
            ELSE
                SkipRecordBody(F,Length);
            END;
        END;
    ELSE
        FileComplaint(F);
    END;

    RETURN FALSE;

END FindTaskIDForWBS;




PROCEDURE CreateTasksWanted( VAR TasksWanted : ATasksWantedSetPointer;
                             VAR StartDates,
                                 EndDates        : ADateArrayPointer;
                                 HighestEntry  : CARDINAL ) : BOOLEAN;
VAR
    Sets, i : CARDINAL;
    TasksWantedSize : CARDINAL;
BEGIN
        (* Sometimes we have problems allocating small heap items. *)
    IF (HighestEntry < 63) THEN
        HighestEntry := 63;
    END;


    Sets := (HighestEntry DIV 16)+1;
    TasksWantedSize := Sets * TSIZE(BITSET);
    IF (Available(TasksWantedSize)) THEN
        ALLOCATE(TasksWanted,TasksWantedSize);
        FOR i := 0 TO Sets-1 DO
            TasksWanted^[i] := {};
        END;
        i := HighestEntry * TSIZE(ADate);
        IF (Available(i)) THEN
            ALLOCATE(StartDates,i);
        ELSE
            DEALLOCATE(TasksWanted,TasksWantedSize);
            ErrorPhrase(30619);
            RETURN FALSE;
        END;
        IF (Available(i)) THEN
            ALLOCATE(EndDates,i);
        ELSE
            DEALLOCATE(StartDates,i);
            DEALLOCATE(TasksWanted,TasksWantedSize);
            ErrorPhrase(30619);
            RETURN FALSE;
        END;
        RETURN TRUE;
    ELSE
        ErrorPhrase(30619);
        RETURN FALSE;
    END;
END CreateTasksWanted;


    (* Dispose the arrays with information about each task. *)


PROCEDURE DisposeTasksWanted( VAR TasksWanted : ATasksWantedSetPointer;
                              VAR StartDates,
                                  EndDates        : ADateArrayPointer;
                                  HighestEntry  : CARDINAL );
VAR
    Sets, i : CARDINAL;
    TasksWantedSize : CARDINAL;
BEGIN
        (* Sometimes we have problems allocating small heap items. *)
    IF (HighestEntry < 63) THEN
        HighestEntry := 63;
    END;

    Sets := (HighestEntry DIV 16)+1;
    TasksWantedSize := Sets * TSIZE(BITSET);
    IF (TasksWanted <> NIL) THEN
        DEALLOCATE(TasksWanted,TasksWantedSize);
    END;
    i := HighestEntry * TSIZE(ADate);
    IF (StartDates <> NIL) THEN
        DEALLOCATE(StartDates,i);
    END;
    IF (EndDates <> NIL) THEN
        DEALLOCATE(EndDates,i);
    END;
END DisposeTasksWanted;




    (* GetSummary -- Read in tasks that match the link rule or WBS.

                     There are several outputs from this proc:

                        Each task that we matched will have its ID
                        entered into TasksWanted, and its start and
                        end date in StartDates and EndDates.

                        Assignments to the wanted tasks will be added to
                        the master task (identified by Node).

                     Returns the range of dates in [FirstDate,LastDate).
                     Updates Node with new dates and percent achieved.
                     *)


PROCEDURE GetSummary(VAR F          : File;
                         Node       : ATreeNode;
                         DoWeReadAll: BOOLEAN;       (* Read all tasks. *)
                         CopyResources : BOOLEAN;    (* Add assignments. *)
                     VAR WantMatchString : ARRAY OF CHAR;
                     VAR TasksWanted : ATasksWantedSetPointer;
                     VAR StartDates,
                         EndDates    : ADateArrayPointer;
                     VAR FirstDate,
                         LastDate   : ADate     )
                                                 : BOOLEAN;
TYPE
    AStatusSet = SET OF AStartStatus;

VAR
    PercentComplete,
    WeightedValue,
    TotalValue              : REAL;
    BCWP                    : REAL;
    TLWin1Task              : ATLWinTask;
    TLW1Assignment          : ATLWinAssignment;
    Task                    : ATaskPtr;
    Assignments             : AnExtHandle;
    Length                  : LONGINT;
    Type                    : CARDINAL;
    ID, WantTaskID          : CARDINAL;
    TasksRead               : CARDINAL;

    CompletedSummary,
    ToGoSummary             : AnAssignmentSummary;

    StatusSet               : AStatusSet;
    s                       : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
    DesireThisTask          : BOOLEAN;


    PROCEDURE AccumulateDates(TLWin1Task : ATLWinTask );
    VAR
        EarlyStart,
        EarlyEnd : ADate;
    BEGIN
            (* Extract the start and end dates, and find the earliest
               of the early dates of all tasks, and the latest of the
               end dates. *)
        EarlyStart := TLWin1DateToDate(TLWin1Task.EarlyLevelled[0]);
        EarlyEnd   := TLWin1DateToDate(TLWin1Task.EarlyLevelled[1]);
        IF (EarlyStart < FirstDate) THEN
            FirstDate := EarlyStart;
        END;
        IF (EarlyEnd > LastDate) THEN
            LastDate := EarlyEnd;
        END;

            (* Store the ID of this task into the table of tasks that
               we have linked/rolled up.  Store the start and end dates. *)

        (*<TRACE
            SetString(TraceS,"Store task ");
            CtoS(ID,TraceS2);  ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
        TRACE>*)


        IF (ID <= FileHeaderRecord.MaximumTaskID) THEN
            INCL(TasksWanted^[ID DIV 16],ID MOD 16); (* Note that we took it. *)
            StartDates^[ID] := EarlyStart;
            EndDates^[ID] := EarlyEnd;
        ELSE
            ErrorPhrase(ModuleNumber+20);
        END;


    END AccumulateDates;





        (* Processing after each task is read. *)

    PROCEDURE AccumulateProgress(    TLWin1Task : ATLWinTask );
    VAR
        StartStatus : AStartStatus;
        PercentAchieved : CARDINAL;
        ValueThisTask,
        PercentThisTask,
        SpentCost,
        SpentEffort : REAL;
    BEGIN
            (* Get the status and percent achieved. *)
        PercentAchieved := ORD(TLWin1Task.Complete);

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

            (* Add up the spent and remaining cost for the tasks. *)
        
        IF (CopyResources) THEN
            SpentCost   := TLWin1Task.TotalCost * PercentThisTask;
            SpentEffort := LongToReal(TLWin1Task.TotalEffort) / 10.0 * PercentThisTask;
    
            CompletedSummary.Amount := CompletedSummary.Amount + SpentCost;
            CompletedSummary.Time   := CompletedSummary.Time   + SpentEffort;
            ToGoSummary.Amount      := ToGoSummary.Amount
                + TLWin1Task.TotalCost - SpentCost;
            ToGoSummary.Time        := ToGoSummary.Time
                + LongToReal(TLWin1Task.TotalEffort) / 10.0 - SpentEffort;
        END;

    END AccumulateProgress;

BEGIN (* GetSummary *)

        (* Clear the accumulators for rolled-up amounts. *)
    WITH CompletedSummary DO
        Time   := Zero;
        Amount := Zero;
    END;
    WITH ToGoSummary DO
        Time   := Zero;
        Amount := Zero;
    END;
    BCWP := Zero;

    WeightedValue := Zero;
    TotalValue    := Zero;
    StatusSet     := AStatusSet{};
    LastDate      := MinDate;
    FirstDate     := MaxDate;

    TasksRead     := 0;        (* How many were selected for import. *)


        (* Remove old assignments on master task. *)

    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    RemoveAssignmentsAndExpenses( Task^.Plan.Assignments );
    Node^.Methods^.UnlockFlexStorDataObject (Node);

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
   

       (* Create and clear the set of task id's that we captured. *)
         

    DisposeTasksWantedArrays := TRUE;   (* 9-Apr-92 TGS *)
    IF NOT CreateTasksWanted( TasksWanted, StartDates, EndDates,
                              FileHeaderRecord.MaximumTaskID ) THEN
        DisposeTasksWantedArrays := FALSE;
        ok := FALSE;
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
                    ReadRecordBody (F,Length,TLWin1Task);
                    IF (Length <> VAL(LONGINT,SIZE(TLWin1Task))) THEN
                        Complain(ModuleNumber+12);
                        EXIT;
                    END;
                        (* If we know enough now to make the decision, do so. *)
                    DesireThisTask := WeWantThisTask( ID, TLWin1Task.Level,
                                                      DoWeReadAll, WantTaskID );
    
                    IF (DesireThisTask) THEN
                        AccumulateDates( TLWin1Task );
                            (* If this task contains the Percent Achieved we
                               need, draw the achievement from this task. *)
                        IF (TLWin1Task.Level = CollectPerformanceLevel) THEN
                            AccumulateProgress(TLWin1Task);
                        END;
                        INC(TasksRead);
                    END;


              | 6 : (* An Assignment *)

                        (* Interleaving the processing of assignments and 
                           tasks works because each the assignments to a 
                           task always occur later in the file than the
                           task does, though not necessarily directly. *)

                    IF (CopyResources) THEN
                        ReadRecordBody (F,Length,TLW1Assignment);
                        IF (Length <> VAL(LONGINT,SIZE(TLW1Assignment))) THEN
                            Complain(ModuleNumber+12);
                            EXIT;
                        END;
    
                        (*<TRACE
                            CtoS(TLW1Assignment.TaskID,TraceS);
                            CtoS(TLW1Assignment.ResourceID,TraceS2);
                            ConcatS(TraceS," <-- Resource ");  ConcatLS(TraceS,TraceS2);
                            IF WeWantThisAssignment(TLW1Assignment) THEN
                                ConcatS(TraceS,"  Wanted");
                            END;
                            PrintString(TraceS);
                        TRACE>*)
        
                        IF WeWantThisAssignment(TLW1Assignment) THEN
                            AddTW1ResourceAssignment(Node,TLW1Assignment);
                        END;
                    ELSE
                        SkipRecordBody(F,Length);
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


        Task^.TempTaskFlags := ATempTaskFlagSet{};

        Node^.Methods^.UnlockFlexStorDataObject (Node);

        Task := Node^.Methods^.LockFlexStorDataObject (Node);
        Task^.CompletedSummary := CompletedSummary;
        Task^.ToGoSummary      := ToGoSummary;
        Task^.BCWP             := BCWP;
        Node^.Methods^.UnlockFlexStorDataObject (Node);

    ELSE
        IF (CheckIO(F) <> done) THEN    (* 27-Mar-92 TGS *)
            FileComplaint( F );
        END;
        ok := FALSE;
    END;


    IF (NOT ok) THEN
        Complain(ModuleNumber+5);   (*  "Missing summary data."  *)
    END;

    RETURN ok;

END GetSummary;












PROCEDURE AddResourceAssignment( TaskNode : ATreeNode;
                                 Resource : AResourcePointer;
                                 Rate     : REAL;      (* FTE * 100 *)
                                 p        : CARDINAL;  (* at this Percent *)
                                 StartDate,
                                 EndDate  : ADate );
VAR
    TempVAL, CompositeVAL, OriginalVAL : AVaryingAssgnList;
    Task : ATaskPtr;
    Assignments : AnExtHandle;
    AssignmentArray         : AnAssignmentArray;
    StartStat   : AStartStatus;
    i,Count,Index,NewSize : CARDINAL;
    Found, ok   : BOOLEAN;
BEGIN
        (* Make sure that there is an assignments array on the task. *)
    Task := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
    IF (Task^.Plan.Assignments = AnExtHandle(NIL)) THEN
        IF NOT CreateExtObjectWithSize( Task^.Plan.Assignments, ExtMedium, 0) THEN
            TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);
            RETURN;
        END;
    END;
    Assignments := Task^.Plan.Assignments;
    StartStat   := Task^.StartStatus;
    TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);

        (* Find out if the resource is already assigned to this task. 
           Locate or create the entry in the AssignmentsArray. *)

    Count := LockObjectArray (Assignments, AssignmentArray, TSIZE(AnAssignmentRecord));

    Found := FALSE;
    i     := 0; 
    WHILE (i < Count) AND (NOT Found) DO
        IF ( AssignmentArray^[i].Resource = Resource ) THEN
            Index := i;
            Found := TRUE;
        END;
        INC(i);
    END;
        (* If there was not yet an assignment to this resource, add an
           assignment entry.  Leave the array locked.
           *)
    IF (NOT Found) THEN
        ReleaseObject (Assignments);
        NewSize := ArraySize (Count+1, TSIZE(AnAssignmentRecord));
        ok := (SetExtSize (Assignments, NewSize));
        Count := LockObjectArray (Assignments, AssignmentArray, TSIZE(AnAssignmentRecord));
        Index := Count-1;  (* Position of new entry. *)
            (* Fill in the new assignment. *)
        InitAssignment( Resource, AssignmentArray^[ Index ]);
        WITH AssignmentArray^[ Index ] DO
            IF (Resource^.CostStyle = CAmountRate) THEN (* 25-Mar-92 TGS *)
                IF (StartStat = DoneS) THEN
                    ActualQuantity := Rate;
                ELSE
                    YetToGoQuantity:= Rate;
                END;
            ELSE
                MaxRatePercent := TRUNC(Rate);
                PercentageEach := CHR( p );
            END;
        END;
    END;



        (* Merge the new period into the varying assignment list.  Do
           this by temporarily creating a varying assignment list for the
           new period, and using that as a source for the merge routine.
           This creates a new, composite list which will replace the
           original. *)

    IF (Resource^.Type <> AccountingOnly) AND          (* Not just a cost category. *)
       (Rate > Zero) AND (StartDate < EndDate) THEN
            (* Get a handle to the original VAL. *)
        OriginalVAL := AssignmentArray^[ Index ].VaryingAssignment;
            (* Unlock the assignments to reduce outstanding locks. *)
        ReleaseObject (Assignments);

            (* Make a temp VAL with Rate in interval [StartDate,EndDate),
               zero elsewhere. *)
        TempVAL := AVaryingAssgnList(NIL);
        IF NOT CreateVaryingAssgnListRange( TempVAL, StartDate, EndDate,
                                            Rate ) THEN
            ErrorPhrase(ModuleNumber+19);   (* memory problem. *)
        END;

            (* Merge the lists into a new, composite one. *)

        CompositeVAL := MergeVaryingAssignmentLists( OriginalVAL, TempVAL);

        DisposeVaryingAssgnList(TempVAL);    (* Discard the temp list. *)

            (* Replace the former list with the new one. *)

        DisposeVaryingAssgnList(OriginalVAL);      (* Discard original list. *)
        Count := LockObjectArray (Assignments, AssignmentArray, TSIZE(AnAssignmentRecord));
        AssignmentArray^[ Index ].VaryingAssignment := CompositeVAL;
    END;

    ReleaseObject (Assignments);

END AddResourceAssignment;



    (* Determine if this assignment is to a task that we linked to,
       or to a child task of the linked task. *)

PROCEDURE WeWantThisAssignment( VAR TLW1Assignment : ATLWinAssignment
                              ) : BOOLEAN;
VAR
    ID : CARDINAL;
BEGIN
        (* Look up the task id in the set of ids for tasks that were
           linked. *)
    ID := TLW1Assignment.TaskID;
    RETURN (ID MOD 16) IN TasksWanted^[ ID DIV 16 ];
END WeWantThisAssignment;





PROCEDURE AddTW1ResourceAssignment(     TaskNode : ATreeNode;
                                    VAR TLW1Assignment : ATLWinAssignment );
VAR
    Rate : REAL;
    Task : ATaskPtr;
    ResourceNode : ATreeNode;
    Resource : AResourcePointer;
    StartDate, EndDate : ADate;
    NullName        : ARRAY [0..1] OF CHAR;
    n, p     : CARDINAL;
    FTE100   : REAL;
BEGIN
        (* Unlike TL5, the TLW1 resource assignments do not contain
           a start or end date.  So, we go to the task information we
           stored earlier to get those dates. *)

    WITH TLW1Assignment DO
        Rate := Convert4ByteReal( UtilizationRate );
        StartDate := StartDates^[ TaskID ];
        EndDate   := EndDates^  [ TaskID ];
        IF FindEntryByID( ResourceTable, ResourceID, ResourceNode) THEN END;
    END;
    ValidateTreeNode(ResourceNode);
    Resource := ResourceNode^.Methods^.GetDataObject (ResourceNode);

        (* We are now ready to assign Resource at Rate for the half-open
           interval [StartDate,EndDate). *)

    NullName[0] := 0C;
    IF (Resource^.CostStyle <> CAmountRate) THEN (* 25-Mar-92 TGS *)
        NewPercent( NullName, Resource^.Name,
                    Rate,            (* Usage in TLWin. *)
                    655.0,           (* UpperLimit *)
                    Zero,            (* LowerLimit *)
                    650,             (* Max n *)
                    250,             (* Max % *)
                    n, p );
            (* The rate is specified for each assignment as the number of
            people working full time (FTE) scaled by 100. *)

        FTE100 := OneHundred * Rate;
        IF (FTE100 > FMAXCARDINAL) THEN
            FTE100 := FMAXCARDINAL;
        END;
    ELSE (* a unit cost *)
        FTE100 := Rate;
    END;



    AddResourceAssignment( TaskNode, Resource,
                           FTE100, p,
                           StartDate, EndDate );

END AddTW1ResourceAssignment;




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

    ok := TRUE;

        (* Check the list of resources and costs of the detail
           schedule.  Add to our list any that we do not have. *)

    IF (CopyResources) THEN
        IF NOT GetResources(f, ResourceTable,
                            FileHeaderRecord.MaximumResourceID,
                            MAXCARDINAL, FixedCostNode) THEN
            ok := FALSE;
        END;
    END;

        (* Read in the summary data. *)

    TasksWanted := NIL;
    IF (ok) THEN
        ok := (GetSummary(f,Node,
                          DoWeReadAll, CopyResources,
                          WantMatchString,
                          TasksWanted, StartDates, EndDates,
                          StartDate,EndDate)) AND
              (CheckIO(f) = done);
    END;

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

        (* Deallocate the id tables. *)

    IF (CopyResources) THEN
        DisposeCorrelationTable( ResourceTable );
    END;

    IF DisposeTasksWantedArrays THEN    (* 9-Apr-92 TGS *)
        DisposeTasksWanted( TasksWanted, StartDates, EndDates,
                            FileHeaderRecord.MaximumTaskID );
    END;

    Node^.Methods^.UnlockFlexStorDataObject (Node);

    IF (CheckIO(f) <> done) THEN
        FileComplaint( f );
    END;

    s[0] := 0C;
    Message(s);

END GetRollupDates;





PROCEDURE TLLnkTLW1Body();

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

        IF (DoWeReadAll) THEN
            WantedLevel := 0;          (* Read all tasks. *)
            CollectPerformanceLevel := 0;  (* Summarize achievement of outermost tasks. *)
        ELSE
            WantedLevel := MAX(CARDINAL);          (* Ignore tasks unless checked out. *)
            CollectPerformanceLevel := MAX(CARDINAL);
        END;


            (* Read the source schedule. *)
        SetKindOfFile( RockyFile );

        IF (StartFileInput (f,FileHeaderRecord)) THEN        (* Check for bad format *)
            GetRollupDates (f, Node, DoWeReadAll, s );
        ELSE
            TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
            (* DiscardText (TaskPtr^.summarizes); *)
            TaskPtr^.summarizes := AText(NIL);
            TaskPtr^.rollupstatus := NotRollup;
            Node^.Methods^.UnlockFlexStorDataObject (Node);
        END;
    END;


END TLLnkTLW1Body;


BEGIN                       (* TLLnkSum *)

    OverlayID := ImAnInstallableOverlay(TLLnkTLW1Body, AnOverlayProc(NIL));
    TLLnkTLW1Body();

    (*<TRACE
    EndTrace();
    TRACE>*)

END TLLnkTW1.





