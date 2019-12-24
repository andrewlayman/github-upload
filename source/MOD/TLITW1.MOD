MODULE TLITW1;

    (*------------------------------------------------------------------------

                        Import Time Line Windows 1.0 files.


    -------------------------------------------------------------------------*)


(*  =========================================================================
    Last Edit : February 19, 1992 9:42am by TGS
    Language  : Logitech Modula-2/86 Version 3

    Description:


    MODIFICATION HISTORY:

    19-Feb-92 TGS   First version, loosely adapted from TLITL5.
    12-Mar-92 TGS   Put in LAA's CorrelationTable stuff.
    20-Mar-92 TGS   Put in Fixed Cost stuff, Link-to-file stuff.
    31-Mar-92 TGS   Oops. When creating TaskTable, wasn't asking for the
                    right table size. Bug 5485.
    07-Apr-92 TGS   Don't adjust effort numbers by SMUPH. Bug 5508.
    09-Apr-92 TGS   TLWinDurToDur() was not properly converting LONGINTs
                    to CARDINALs.
    09-Apr-92 TGS   If duration was less than SMUPH, it got rounded up to
                    an hour.
    16-Apr-92 LAA   Preinitialized the ResourceTable and TaskTable to NIL
                    so that disposing of them would work if they were never
                    built, and reorganized some of the GetProject code.
    20-Apr-92 TGS   Added TLWinCleanup() to sanitize tasks which may have
                    come in as EffortDriven even though they have no
                    Employable resources assigned. Bug 5563.
    22-Apr-92 LAA   To fix bug #5565, converted TotalCost to a manual cost for
                    OnTarget files not using resource costing.  This 
                    corresponds to the ManualCost in Rocky.
    23-Apr-92 TGS   Check value of BaselineCost to see if baseline exists.
                    Check for BaseLineEffort only works in TLWin. Bug 5588.
    23-Apr-92 TGS   If OriginalTimeUnits is "undefined", set it to Hours,
                    instead of calling FatalError().
                    Some OT files may not explicitly define it.
    =========================================================================
*)


FROM Allocs                 IMPORT 
    (* CONST *)                 AUXLen, AUXLine, OBSLen, OBSLine,
                                TskNmLen, WBSLen, WBSLine,
    (* TYPE *)                  AFixType, ATask, ATaskFlag, ATaskPtr,
                                ATaskName, ATaskStatus, ADateBlock, 
                                ABigDateBlock, ARollupStatus, 
                                ADurationMethod, ATaskFlagSet, AStartStatus,
                                ATaskStatusSet,
    (* PROC *)                  AddTask, CheckTaskValid, CreateTask,
                                CopyTask, DelTask, SetCodingField, TaskTree;

FROM AsOf                   IMPORT
    (* TYPE *)                  AnAsOfSettingOption,
    (* VAR *)                   AsOfDate, AsOfSettingOption,
    (* PROC *)                  SetAsOfDate;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord, AnAssignmentArray, 
                                AnAssignmentAttribute, ARole,
    (* PROC *)                  InitAssignment;

FROM CalShift               IMPORT
    (* VAR  *)                  TimeSheet;

FROM Chart                  IMPORT  BugTaskA, BugDayA, BugTaskB, BugDayB,
                                    CursorTask, CursorDay, GanttChart;

FROM ChartControl           IMPORT
                                UnSetState, AChartState;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR  *)                  LayoutTree, CurrentChartFormat,
                                DefaultChartFormat, 
    (* PROC *)                  CreateLayout, SortLayouts,
                                LayoutChanged;

FROM CorTable               IMPORT 
    (* TYPE *)                  ACorrelationTable,
    (* PROC *)                  AddTableEntry, CreateCorrelationTable,
                                DisposeCorrelationTable, FindEntryByID;

FROM Dialog                 IMPORT Message, Error, FatalError, Burp,
                                   MultipleChoiceBox, ADialogOption,
                                   WarningBox, NotYetImplemented,
                                   ErrorPhrase;

FROM Directory              IMPORT
        (* CONST *)             MaximumFileNameLength, MaximumExtensionLength,
                                MaximumPathNameLength,
        (* PROCS *)             ExtractFileNameParts, PathLookupStart;

FROM Duration               IMPORT
    (* PROC  *)                 FindDuration;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr, AnEdgeType,
                                ASetOfEdgeAttributes, AnEdgesTask,
    (* PROC *)                  FindEdgeInTask, CreateEdgeDammit,
                                AddEdgeWithTasks, CopyEdgeContents;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
                                AnExtStatus,
    (* PROC *)                  CreateExtObject, SaveHeapCopy, NumberOfElements,
                                SetExtData, DiscardExtObject, ReleaseObject,
                                ReleaseUnchangedObject,
                                CreateExtObjectWithSize, LockObject,
                                LockObjectArray, SetExtSize, ArraySize,
                                GetExtStatus;

FROM FileAux                IMPORT FileResultMeans,
                                   FlushBuffer, PrepareForIO, CheckIO;

FROM FileOpen               IMPORT  RequestFileOpenReadOnly,
                                    RequestFileFind;

FROM FileSystem             IMPORT  File, Lookup, Response, Close,
                                    Create, Rename, Delete, Reset, SetRead;

FROM Filters                IMPORT  ResetFilters;

FROM ForeignSubfiles        IMPORT
    (* TYPE *)                      AFileType,
    (* PROC *)                      DigestSubfile;

FROM ImpTLWindows           IMPORT
    (* PROC *)                  GetAssignments, GetResources, 
                                TLWin1DateToDate;

FROM Kbio                   IMPORT avidmode,
                                   maxrow, maxcol,
                                   GetAnyCode, BreakRequested, ClearBreak,
                                   PutString;

FROM Links                  IMPORT
        (* CONST *)             LinkOverlayNameLine, LinkFileTypeLine,
                                LinkPathLine;

FROM LinkSupport            IMPORT
                                A4ByteReal;

FROM LongConvert            IMPORT
    (* PROC *)                  LongToReal;

FROM LStrings               IMPORT
                                ConcatLS, ConcatS, Copy, CtoS, Fill,
                                Insert, LengthOf, LJust, LStringToTString,
                                Search, Remove, SetLengthOf,
                                Procustes, SetString, StoC, StringsEqual,
                                SubStr,
                                TrimRear, TStringToLString, Upshift;

FROM Menus                  IMPORT Menu, NoYes;

FROM MsgFile                IMPORT  GetMessage, DisplayMessage, ConcatMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NetLayoutTree, CurrentNetLayout,
                                EnlargedNetLayout;

FROM Overlays               IMPORT
        (* PROCS *)                 OverlayContext, CallOverlay;

FROM Planner                IMPORT
    (* TYPE *)                  AWhenToCalc, ACalcComponent,
    (* VAR *)                   CalculationState, KeepEffortContiguous,
                                Levelling, RecalcOptions, MoveFutureTasks,
                                TimeConstrained, ScheduleComputedOk,
                                ScheduleEndDate, ScheduleStartDate;

FROM PrintStatic            IMPORT  PrintDiskFileName, ReportSettings;

FROM Progress               IMPORT
    (* TYPE *)                      AThermometer,
    (* PROC *)                      CreateThermometer, UpdateThermometer, 
                                    DiscardThermometer;

                                    (*
FROM RecordIO               IMPORT  ReadRecord, ReadString, ReadRecordPreface,
                                    ReadRecordBody, ReadStringBody;
                                      *)
FROM Registry               IMPORT
    (* CONST *)                 QCapacity,
    (* TYPE *)                  ARegistryDataRecord,
    (* VAR  *)                  UserName, ProductName;

FROM RegCapacity            IMPORT
    (* PROC *)                  GetRegistryInfo;

FROM RsrcMod                IMPORT
    (* TYPE *)                  AResourcePointer, ACostStyle, AResourceType,
    (* VAR   *)                 ResourceTree;

FROM Schedule               IMPORT 
                                ZeroIsLowestPriority, ProjectName, 
                                ProjectText, RetrievalName, ProjectStartDate,
                                Author, FullScheduleName, RevisionNumber,
                                ConfigSaved, PlannedProjectName,
                                ScheduleSaved, Loaded, ProjectMedia;

FROM Space                  IMPORT
                                ALLOCATE, Available, DEALLOCATE,
                                HeapAvailable;

FROM SYSTEM                 IMPORT ADDRESS, TSIZE, SIZE, ADR, BYTE;

FROM TaskFind               IMPORT
    (* PROC *)                  TaskFindBegin, TaskFindEnd, FindTaskByNumber,
                                AddTaskByNumber;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  AppendLine, AssignLine, Compress, CreateText,
                                TextExists, DiscardText;

FROM TimeConversions        IMPORT
    (* PROC *)                  BeforeCalendarChange, AfterCalendarChange,
                                ToNewDuration, ToNewDate, ToNewScale;

FROM Timei                  IMPORT
    (* CONST*)                  MinDate, NoDuration,
    (* TYPE *)                  ADuration, ADurationUnit, ADate, ATimeInfo,
    (* PROC *)                  TtoTimeU;

FROM Timeu                  IMPORT
    (* VAR *)                   FSMUPH, SMUPH, SMU,
    (* PROC *)                  SetStartingMonth, DownScale;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM TLW1File               IMPORT
    (* CONST *)                 NullEffortConst,
    (* TYPE *)                  ACost, AFileHeaderRecord, AFixesSetElement,
                                AKindOfFile,
                                ATLWinAssignment, ATLWinEdge, ATLWinResource, 
                                ATLWinTask,
    (* PROC *)                  KindOfFile, ReadRecordPreface, 
                                ReadRecordBody, ReadStringBody, 
                                SetKindOfFile, SkipRecordBody,
                                StartFileInput; 

FROM Transfer               IMPORT
                                ARetrieveType, RetrieveType,
                                AHeaderRecord;

FROM TreeObjects            IMPORT
    (* TYPE *)                      ATree, ATreeNode, ATreeOrder,
    (* PROC *)                      CreateTreeNode, 
                                    ValidateTree, ValidateTreeNode;

FROM Words        IMPORT
    (* PROC *)             ParseBal;

CONST
    ModuleNumber = 30800;    (* For GetMessage *)
    MAXCARDINAL = 65535;

    MAXTasks    = 1000;

CONST
    (* AFileHeaderRecord.Flag values *)
    LevelResources      = 0;
    SlipFutureToAsOf    = 1;
    SupressResFeatures  = 2;
    SlackIsFreeNotTotal = 3;
    ManualRecalc        = 4;
    ResourceCosting     = 5;

    NullDate            = 0L;

    LinkFlagsLine       = 3;  (* Choice field settings on link form *)
    LinkWBSLine         = 4;

TYPE
    ANoMemoryPlace   = (StartingUp, AddingTasks, AddingEdges,
                        AddingResources, AddingAssignments);

        (* this is the stuff that makes a TLWin task record different
            than an On Target task record *)
    ATLWinTaskRecordDelta = RECORD
                      ManualCost            : ACost;
                      GenericNumeric        : A4ByteReal;
                      TotalEffort           : LONGINT;
                      BaseLineEffort        : LONGINT;
                      PartialEffort         : LONGINT;
                  END;


    ASource                 = (TimeLine, OnTarget);    

    ASourceTypeRecord       = RECORD
                                  ExtTemplate   : ARRAY [0..MaximumExtensionLength] OF CHAR;
                                  ViewerName,
                                  LinkerName    : ARRAY [0..MaximumFileNameLength] OF CHAR;
                                  Source        : ASource;
                                  ResourcesAllowed : BOOLEAN;
                              END;


VAR
    SourceTypes             : ARRAY [1..9] OF ASourceTypeRecord;
    MaxSources              : CARDINAL;

    FlagChar                : ARRAY BOOLEAN OF CHAR;



VAR
    GlobalCursorNode,
    Node,
    FixedCostNode       : ATreeNode;
    P                   : POINTER TO ARRAY [0..255] OF CHAR;
    TaskBugCount        : CARDINAL;
    SaveTaskDates       : BOOLEAN;
    ProjectFileName     : ARRAY [0..81] OF CHAR;
    NoteMessage         : ARRAY [0..39] OF CHAR;
    MakeSummaryTask     : BOOLEAN;

    FileHeaderRecord    : AFileHeaderRecord;
    ErrorFlag           : BOOLEAN;

    ResourceTable,
    TaskTable               : ACorrelationTable;

    TaskRecordSize      : LONGINT;

PROCEDURE PrepareSources();
VAR
    SourceTypeS       : ARRAY [0..5] OF CHAR;
    TempS             : ARRAY [0..255] OF CHAR;
    ExtensionIndex, i, j : CARDINAL;
BEGIN
    MaxSources := 0;
    LOOP
        GetMessage(20600+50+MaxSources,TempS);
           (* (<Extension>)(<Viewer>)(<Linker>)(<SourceType>)(<Resources>) *)
        IF (LengthOf(TempS)=0) THEN
            EXIT;
        END;
        INC(MaxSources);
        i := 1;
        WITH SourceTypes[MaxSources] DO
            ParseBal(TempS,i,ExtTemplate);
            ParseBal(TempS,i,ViewerName);
            ParseBal(TempS,i,LinkerName);
                (* SourceType *)
            ParseBal(TempS,i,SourceTypeS);
            j := 1;
            Source := VAL(ASource,StoC(SourceTypeS,j));
                (* Resources allowed? *)
            ParseBal(TempS,i,SourceTypeS);
            j := 1;
            ResourcesAllowed := VAL(BOOLEAN,StoC(SourceTypeS,j));
        END;
    END;
END PrepareSources;
 

PROCEDURE QuickMessage(VAR s : ARRAY OF CHAR);
VAR
    s1  : ARRAY [0..81] OF CHAR;
BEGIN
    Copy(s,s1);
    Procustes(s1,80);    (* Pad it so that it erases prev contents of line. *)
    PutString(s1,0,0,videonormal);
END QuickMessage;


(* Tell Of No Memory - Warn that memory is all gone.
*)

PROCEDURE TellOfNoMemory( When : ANoMemoryPlace );
VAR
    MessageNumber : CARDINAL;
    s : ARRAY [0..199] OF CHAR;
BEGIN
    GetMessage( ModuleNumber + 24, s ); (* "No enough memory while reading " *)
    CASE When OF
    | StartingUp        :    GetMessage(    ModuleNumber + 29, s ); (* "Not enough memory to load a schedule" *)
    | AddingTasks       : ConcatMessage( s, ModuleNumber + 25 ); (* tasks *)
    | AddingEdges       : ConcatMessage( s, ModuleNumber + 26 ); (* resources *)
    | AddingResources   : ConcatMessage( s, ModuleNumber + 27 ); (* connections *)
    | AddingAssignments : ConcatMessage( s, ModuleNumber + 28 ); (* assignments *)
    ELSE
        FatalError();
    END;
    ErrorFlag := TRUE;
    Error(s);
END TellOfNoMemory;



PROCEDURE AddTaskAsLastChild(   NewTask         : ATreeNode;
                                ParentTask      : ATreeNode;
                                PriorTask       : ATreeNode     );
BEGIN
    IF (PriorTask <> NIL) THEN
        PriorTask^.Methods^.AddAfter (PriorTask, NewTask);
    ELSIF (ParentTask <> NIL) THEN
        ParentTask^.Methods^.AddAsLastChild (ParentTask, NewTask);
    ELSE
        TaskTree^.Methods^.AddLast (TaskTree, NewTask);
    END;
END AddTaskAsLastChild;

    (* TLWinDurToDur - convert a TLWin duration to a TL one, according to
        the current SMU.  TLWin durations are expressed in 0.1ths of an hour.
        Since our durations must be CARDINALS, and TLWin's aren't always,
        we return a flag to indicate if the duration is positive or not.
    *)

PROCEDURE TLWinDurToDur(    TLWinDur    : LONGINT;
                        VAR Dur         : CARDINAL;
                        VAR IsPositive  : BOOLEAN );
VAR
    TempLong    : LONGINT;

BEGIN   
        (* assumption: TLWinDur isn't very close to MAXLONGINT *)
    TempLong := ABS(TLWinDur * VAL(LONGINT,SMUPH));
    IF (TempLong > 655350L) THEN
        Dur := MAXCARDINAL;
    ELSE
        Dur := TRUNC(LongToReal(TempLong + 5L)/10.0); (* 9-Apr-92 TGS *)
    END;
    IsPositive := (TLWinDur >= 0L);
END TLWinDurToDur;


PROCEDURE GetTasks( VAR F           : File;
                    VAR TaskTable   : ACorrelationTable;
                        MaxIDNumber,
                        Count       : CARDINAL
                        ) : BOOLEAN;

VAR
    Task            : ATaskPtr;
    TasksRead       : CARDINAL;
    S,
    TaskNote        : ARRAY [0..255]      OF CHAR;
    TaskName        : ARRAY [0..TskNmLen] OF CHAR;
    KeyWord         : ARRAY [0..AUXLen]   OF CHAR;
    WBSCode         : ARRAY [0..WBSLen]   OF CHAR;
    TaskLink        : ARRAY [0..128]      OF CHAR;
    Thermometer     : AThermometer;
    IsPositive,
    RecordPending,
    NamePending     : BOOLEAN;
    ID, LastID,
    Type            : CARDINAL;
    TempDate        : ADate;
    Length          : LONGINT;
    TLWin1Task      : ATLWinTask;
    TaskNode, 
    PrevNode        : ATreeNode;
    LastLevel       : CARDINAL;
    ManualCost      : ACost;


    PROCEDURE MakeTask( ID : CARDINAL ) : BOOLEAN;
    VAR
        ParentNode  : ATreeNode;
        ResPtr      : AResourcePointer;
        AssignmentArray     : AnAssignmentArray;
        AssignmentRecord    : AnAssignmentRecord;
        AsgnCount   : CARDINAL;
        ok          : BOOLEAN;
        
        PROCEDURE MakeTaskLinkText(VAR Text : AText) : BOOLEAN;
        VAR
            PatternS    : ARRAY [0..4] OF CHAR;
            s           : ARRAY [0..128] OF CHAR;
            i, Index    : CARDINAL;
        BEGIN
            (* build table of valid file extensions like TLLINK does *)
            PrepareSources();

            (* can we find any valid extensions? *)
            i := 1;
            LOOP
                IF (i > MaxSources) THEN
                    EXIT;
                END;
                
                SetString( PatternS, ".");
                ConcatLS( PatternS, SourceTypes[i].ExtTemplate);

                Index := Search( TaskLink, PatternS, 1);

                IF (Index > 0) THEN

                    IF Text=AText(NIL) THEN
                        Text := CreateText();
                    END;

                    (* we "probably" have found a file spec *)
                    (* set Index just past where PatternS was found *)
                    Index := Index + LengthOf(SourceTypes[i].ExtTemplate);
                    SubStr(TaskLink, s, 1, Index);
                    IF NOT AssignLine(s, LinkPathLine, Text) THEN END;

                    (* is there a WBS? *)
                    IF Index < LengthOf(TaskLink) THEN
                        (* Index points to last character of filespec;
                           WBS begins 2 chars beyond, following some
                           (unknown) separator *)
                        SubStr(TaskLink, s, Index+2, LengthOf(TaskLink)); 
                        IF NOT AssignLine(s, LinkWBSLine, Text) THEN END;
                    END;

                    SetString(s, "000");
                    IF NOT AssignLine(s, LinkFlagsLine, Text) THEN END;

                    Copy(SourceTypes[i].LinkerName, s);
                    IF NOT AssignLine(s, LinkOverlayNameLine, Text) THEN END;

                    CtoS(ORD(SourceTypes[i].Source), s);
                    IF NOT AssignLine(s, LinkFileTypeLine, Text) THEN END;

                    EXIT; (* we're done *)
                END;
                INC(i);
            END;
            RETURN (i <= MaxSources);
        END MakeTaskLinkText;

    BEGIN
        (* throw out "Task 0", the summary of schedule *)
        IF (ID = 0) THEN
            RETURN TRUE;
        END;

        (* create a new task *)
        TaskNode := CreateTask();

        IF (TaskNode = NIL) THEN
            (* problem with heap? *)
            RETURN FALSE;
        END;

        (* initialize new task using imported stuff *)
        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        IF (Task = NIL) THEN
            FatalError();
        END;

        WITH Task^ DO

            LJust( TaskName );
            Copy(TaskName, taskname);
            priority := 10 * ORD(TLWin1Task.Priority);
            SetCodingField( Task^, WBSLine, WBSCode );
            SetCodingField( Task^, AUXLine, KeyWord );
            IF (LengthOf(TaskLink) > 0) THEN
                IF NOT MakeTaskLinkText( summarizes ) THEN
                    ErrorPhrase( 30812 ); (* unknown link type *)
                END;
            END;

            IF (LengthOf(TaskNote) > 0) THEN
                IF notes = AText(NIL) THEN
                    notes := CreateText();
                END;
                IF (AppendLine( TaskNote, notes )) THEN END;
                Compress( notes );
            END;

            IF (IsEffortDriven IN TLWin1Task.Fixes) THEN
                DurationMethod := EffortDriven;
            ELSE
                DurationMethod := DurationDriven;
            END;

            TLWinDurToDur( TLWin1Task.Duration, duration, IsPositive);
            IF NOT IsPositive THEN
                duration := 0;
            END;

            CASE (ORD(TLWin1Task.OriginalTimeUnits)) OF
            | 1, 10 :
                scale       := Hours;
                EffortScale := Hours;
            | 2, 11 :
                scale       := Days;
                EffortScale := Days;
            | 3, 12 :
                scale       := Weeks;
                EffortScale := Weeks;
            | 4, 5, 13, 14, 6, 15 :  (* Months, Quarters, AND Years *)
                scale       := Months;
                EffortScale := Months;
            ELSE
                (* 24-Apr-92 TGS
                FatalError();
                *)
                scale       := Hours;
                EffortScale := Hours;
            END;

            IF (IsALAP IN TLWin1Task.Fixes) THEN
                fixation := ALAP;
            ELSIF ((HasFixedStart IN TLWin1Task.Fixes) OR
                   (HasFixedEnd   IN TLWin1Task.Fixes)) THEN
                fixation := FixedDate;
                DurationMethod := DurationDriven;
                INCL(TaskFlags,NoSoonerStart);
                INCL(TaskFlags,NoLaterStart);

                IF (HasFixedStart IN TLWin1Task.Fixes) THEN
                    TempDate := TLWin1DateToDate(TLWin1Task.Fixed[0]);
                    CalendarTimeToBigTime(TempDate,
                                          TRUE, UserEnteredStartDate);
                    IF (TempDate < (MAXCARDINAL - duration)) THEN
                        CalendarTimeToBigTime((TempDate + duration),
                                              FALSE, UserEnteredEndDate);
                    ELSE
                        CalendarTimeToBigTime(MAXCARDINAL,
                                              FALSE, UserEnteredEndDate);
                    END;
                ELSIF (HasFixedEnd IN TLWin1Task.Fixes) THEN
                    TempDate := TLWin1DateToDate(TLWin1Task.Fixed[1]);
                    CalendarTimeToBigTime(TempDate,
                                          FALSE, UserEnteredEndDate);
                    IF (TempDate > duration) THEN
                        CalendarTimeToBigTime((TempDate - duration),
                                            TRUE, UserEnteredStartDate);
                    ELSE
                        CalendarTimeToBigTime(0,
                                            TRUE, UserEnteredStartDate);
                    END;
                END;
                SupposedToStart := UserEnteredStartDate;
            ELSE
                fixation := ASAP;
            END;

            WITH Plan.Dates DO
                IF fixation = ASAP THEN
                    EarlyStart := TLWin1DateToDate(TLWin1Task.EarlyLevelled[0]);
                    IF (EarlyStart < (MAXCARDINAL - duration)) THEN
                        EarlyEnd   := EarlyStart + duration;
                    ELSE
                        EarlyEnd    := MAXCARDINAL;
                    END;
                ELSIF fixation = ALAP THEN
                    EarlyEnd   := TLWin1DateToDate(TLWin1Task.EarlyLevelled[1]);
                    IF (EarlyEnd > (duration))  THEN
                        EarlyStart := EarlyEnd - duration;
                    ELSE
                        EarlyStart := 0;
                    END;
                ELSE (* "fixed" *)
                    EarlyStart := TLWin1DateToDate(TLWin1Task.EarlyLevelled[0]);
                    EarlyEnd   := TLWin1DateToDate(TLWin1Task.EarlyLevelled[1]);
                END;
                LateTotalStart := TLWin1DateToDate(TLWin1Task.Late[0]);
                LateFreeStart  := LateTotalStart;
                LateTotalEnd   := TLWin1DateToDate(TLWin1Task.Late[1]);
                LateFreeEnd    := LateTotalEnd;
            END;

            PercentComplete := ORD(TLWin1Task.Complete);
            IF (PercentComplete = 0) THEN
                StartStatus := FutureS;
            ELSIF (PercentComplete >= 100) THEN
                PercentComplete := 100;
                StartStatus := DoneS;
                IF fixation <> FixedDate THEN
                    (* set UserEnteredStart and End *)
                    CalendarTimeToBigTime(Plan.Dates.EarlyStart,
                                          TRUE, UserEnteredStartDate);
                    CalendarTimeToBigTime(Plan.Dates.EarlyEnd,
                                          FALSE, UserEnteredEndDate);
                END;
            ELSE
                StartStatus := StartedS;
                IF fixation <> FixedDate THEN
                    (* set UserEnteredStart *)
                    CalendarTimeToBigTime(Plan.Dates.EarlyStart,
                                          TRUE, UserEnteredStartDate);
                END;
            END;

            WITH ToGoSummary DO
                Amount := 0.01 * FLOAT(100 - PercentComplete)
                          * TLWin1Task.TotalCost;
                Time   := 0.01 * FLOAT(100 - PercentComplete)
                          * (LongToReal(TLWin1Task.TotalEffort)/10.0); (* Rocky only *)
            END;
            WITH CompletedSummary DO
                Amount := TLWin1Task.TotalCost - ToGoSummary.Amount;
                Time   := (LongToReal(TLWin1Task.TotalEffort)/10.0)
                          - ToGoSummary.Time; (* Rocky only *)
            END;

            (* baseline stuff *)
            IF ((TLWin1Task.BaselineDuration <> NullEffortConst) AND
                (KindOfFile() = RockyFile) ) OR
               ((TLWin1Task.BaselineDuration <> -1L) AND
                (KindOfFile() = OnTargetFile) ) THEN
                (* NullEffortConst means "there is no baseline" in TLWin;
                   -1L means "no baseline" in On Target *)
                INCL(TaskFlags, BaseLineExists);
                WITH BaseLine.Dates DO
                    EarlyStart := TLWin1DateToDate(TLWin1Task.Baseline[0]);
                    EarlyEnd   := TLWin1DateToDate(TLWin1Task.Baseline[1]);
                    LateTotalStart := EarlyStart;
                    LateFreeStart  := EarlyStart;
                    LateTotalEnd   := EarlyEnd;
                    LateFreeEnd    := EarlyEnd;
                END;
                WITH BaseLineSummary DO
                    Amount := TLWin1Task.BaselineCost;
                    Time   := FSMUPH * 
                              LongToReal(TLWin1Task.BaseLineEffort)/10.0; (* Rocky only *)
                END;
            ELSE
                EXCL(TaskFlags, BaseLineExists);
            END;

            IF (KindOfFile() = RockyFile) THEN                 (* 22-Apr-92 *)
                ManualCost := TLWin1Task.ManualCost;
            ELSE
                ManualCost := TLWin1Task.TotalCost;
            END;

            (* check for "fixed costs"; try to add as new assignment *)
            IF ( (KindOfFile() = RockyFile) 
                OR ( (KindOfFile() = OnTargetFile) 
                AND (NOT (ResourceCosting IN FileHeaderRecord.Flags))
                AND (TLWin1Task.Kids = 0) ) ) 
                AND (ManualCost > 0.0) THEN

                ResPtr  := FixedCostNode^.Methods^.GetDataObject( FixedCostNode );

                (* this should be a Fixed Cost type resource.. *)
                IF (ResPtr^.CostStyle = CAmount) THEN
                    AsgnCount := LockObjectArray( Plan.Assignments,
                                              AssignmentArray,
                                              TSIZE( AnAssignmentRecord ) );
                    ReleaseUnchangedObject( Plan.Assignments );

                    InitAssignment( ResPtr, AssignmentRecord );
                    WITH AssignmentRecord DO
                        ActualQuantity  := ManualCost *
                                           FLOAT(PercentComplete)/100.0;
                        YetToGoQuantity := ManualCost - ActualQuantity;
                    END;

                    INC(AsgnCount);
                    IF (AsgnCount = 1) THEN
                        ok := CreateExtObjectWithSize
                                ( Plan.Assignments, 
                                ExtMedium, 
                                TSIZE(AnAssignmentRecord) );
                    ELSE
                        ok := SetExtSize
                                    ( Plan.Assignments, 
                                    ArraySize(AsgnCount, TSIZE(AnAssignmentRecord))
                                    );
                    END;
                    IF ok THEN
                        AsgnCount := LockObjectArray( Plan.Assignments,
                                                AssignmentArray,
                                                TSIZE( AnAssignmentRecord ) );

                        DEC(AsgnCount); (* this is the index of the new entry *)
(*$O-*)
                        AssignmentArray^[AsgnCount] := AssignmentRecord;
(*$O=*)
                        ReleaseObject( Plan.Assignments );
                    ELSE
                        ErrorPhrase( 30800 );  (* unable to create fixed cost assignment *)
                    END;
                ELSE
                    ErrorPhrase( 30800 );
                END;
            END;

            (* store these so we can deal with OT task order *)
            XX := TLWin1Task.Parent;
            YY := TLWin1Task.ListLocation;
        END;

        TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);

        (* add it to TaskTable *)
        IF (NOT AddTableEntry( TaskTable, ID, TaskNode )) THEN
            ErrorPhrase(30800); (* Couldn't create task *)
            DelTask( TaskNode );
            RETURN FALSE;
        END;

        (* hook it into task tree: *)
        (* this method will work for TLWin, because it is stored in the
           same order the user sees it, but not for OT. *)

        IF (LastLevel <> TLWin1Task.Level) THEN
            PrevNode := NIL;
        END;

        IF FindEntryByID( TaskTable, TLWin1Task.Parent, ParentNode) THEN
            AddTaskAsLastChild(TaskNode, ParentNode, PrevNode);
        ELSE
            ErrorPhrase(30800); (* Couldn't add task *)
            DelTask( TaskNode );
            RETURN FALSE;
        END;

        LastLevel := TLWin1Task.Level;
        PrevNode := TaskNode;

        RETURN TRUE;

    END MakeTask;

BEGIN (* GetTasks *)
    
    IF (NOT HeapAvailable()) THEN
        ErrorPhrase( 30801 );    (*  Insufficient memory *)
        RETURN FALSE;
    END;

    Task := NIL;
    
    TasksRead := 0;

    GetMessage(12425, S);
    IF (NOT CreateThermometer(Thermometer, 0, 0, S, Count)) THEN
        Thermometer := AThermometer(NIL);
    END;


    (* Reset to the beginning of the file and read records, looking
       for tasks. *)

    PrepareForIO(F);
    Reset(F);
    SetRead(F);

    IF (CheckIO(F) <> done) THEN
        FileComplaint(F);
        RETURN FALSE;
    END;

    TaskTable := CreateCorrelationTable( MaxIDNumber + 1 );
    IF (TaskTable = ACorrelationTable(NIL)) THEN
        ErrorPhrase( 30801 );    (*  Insufficient memory *)
        RETURN FALSE;
    END;

    (* initialize *)
    RecordPending := FALSE;
    NamePending   := FALSE;
    ID            := 0;
    LastID        := 0;

    LOOP
        ReadRecordPreface (F, Type, ID, Length);
        IF (CheckIO(F) <> done) THEN
            FileComplaint(F);
            EXIT;
        END;

        IF (RecordPending) AND
            ((ID <> LastID) OR (Type = 0)) THEN
            IF (NOT MakeTask( LastID )) THEN
                EXIT;
            END;
            RecordPending := FALSE;
        END;

        CASE Type OF
        | 0 : (* File Ender *)
                EXIT;

        | 1 : (* ATask *)

            IF (RecordPending) THEN
                ErrorPhrase(30802);     (* "Structure or sequence error.." *)
            END;

            SetLengthOf(TaskName, 0);
            SetLengthOf(KeyWord, 0);
            SetLengthOf(WBSCode, 0);
            SetLengthOf(TaskNote, 0);
            SetLengthOf(TaskLink, 0);

            NamePending := FALSE;

            ReadRecordBody( F, Length, TLWin1Task );

            INC(TasksRead);
            UpdateThermometer( Thermometer, TasksRead+1 );

            IF (Length <> TaskRecordSize ) THEN
                ErrorPhrase(30803);  (* Wrong task record length *)
                EXIT;
            END;
            
            RecordPending := TRUE;
            LastID := ID;
            
            (*

        | 6 : (* An Assignment *)

            *)

        | 30 : (* Task Text 1, a.k.a. "Keyword" to the TLWin user *)
            ReadStringBody( F, Length, KeyWord );

        | 33 : (* Task Text 2, a.k.a. "Text 1" to the TLWin user *)
            ReadStringBody( F, Length, S );

        | 35 : (* A WBS Number *)
            ReadStringBody( F, Length, WBSCode );

        | 36 : (* Task Name *)
            IF (NamePending) OR (NOT RecordPending) THEN
                ErrorPhrase(30802);
            END;

            ReadStringBody( F, Length, TaskName );
            LJust(TaskName);
            TrimRear(TaskName);
            NamePending := TRUE;

        | 38 : (* A Task File Link *)
            ReadStringBody( F, Length, TaskLink );
            Upshift( TaskLink );

        | 39 : (* A Task Note *)
            ReadStringBody( F, Length, TaskNote );

        | 47 : (* Task Text 3 *)
            ReadStringBody( F, Length, S );

        ELSE
            SkipRecordBody(F, Length);
        END;
    END;

    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

    RETURN (CheckIO(F) = done);

END GetTasks;


PROCEDURE GetHeader(VAR f:File) : BOOLEAN;
BEGIN
    RETURN (StartFileInput (f,FileHeaderRecord) = TRUE)     (* Check for bad format *)
END GetHeader;


PROCEDURE GetEdges( VAR F           : File;
                        EdgeCount   : CARDINAL
                  )                 : BOOLEAN;

VAR
    S               : ARRAY [0..80] OF CHAR;
    Thermometer     : AThermometer;
    EdgesRead       : CARDINAL;
    ID, Type        : CARDINAL;
    Length          : LONGINT;
    TLWinEdge       : ATLWinEdge;

    PROCEDURE AddEdge( Pred, Succ : CARDINAL ) : BOOLEAN;
    VAR
        Task1, Task2        : ATreeNode;
        TaskPtr1, TaskPtr2  : ATaskPtr;
        EdgePtr             : AnEdgePtr;
    BEGIN
        IF (NOT (FindEntryByID( TaskTable, Pred, Task1 ) AND
                 FindEntryByID( TaskTable, Succ, Task2 ))) THEN
            ErrorPhrase(30810);
            RETURN FALSE;
        END;
        TaskPtr1 := Task1^.Methods^.LockFlexStorDataObject (Task1);
        TaskPtr2 := Task2^.Methods^.LockFlexStorDataObject (Task2);

        EdgePtr := FindEdgeInTask(AnEdgesTask(TaskPtr1), Task2);

        IF (EdgePtr = NIL) THEN
            EdgePtr := FindEdgeInTask(AnEdgesTask(TaskPtr2), Task1);
        END;

        IF (EdgePtr <> NIL) THEN
            RETURN FALSE;
        ELSE
            EdgePtr := CreateEdgeDammit (Task1,Task2);
            IF (EdgePtr <> NIL) THEN
                WITH EdgePtr^ DO
                    WITH FromOffset DO
                        CASE (ORD(TLWinEdge.TypeOfConnection)) OF
                        | 0 : (* S-S *)
                            Start := TRUE;
                            ToOffset.Start := TRUE;
                        | 1 : (* S-F *)
                            Start := TRUE;
                            ToOffset.Start := FALSE;
                        | 2 : (* F-S *)
                            Start := FALSE;
                            ToOffset.Start := TRUE;
                        | 3 : (* F-F *)
                            Start := FALSE;
                            ToOffset.Start := FALSE;
                        ELSE
                            FatalError();
                        END;

                        TLWinDurToDur( TLWinEdge.LagOrLead, Dur, Plus );

                        CASE (ORD(TLWinEdge.OriginalTimeUnits)) OF
                        | 0     : (* some OT files use this (undocumented) value? *)
                            Scale := Hours;
                        | 1, 10 : Scale := Hours; 
                        | 2, 11 : Scale := Days; 
                        | 3, 12 : Scale := Weeks;
                        | 4, 13, 5, 14, 6, 15 : Scale := Months;
                        ELSE
                            (* 24-Apr-92 TGS
                            FatalError();
                            *)
                            Scale := Hours;
                        END;
                            (* 9-Apr-92 TGS added this case:
                                Need to drop Scale down to Minutes if we can
                                and it makes sense to do so.
                            *)
                        IF (Dur > 0) AND    (* Dur of zero can be expressed with any scale *)
                           (SMUPH > 1) AND  (* If SMUPH is one, doesn't make sense to use Min *)
                           (Dur MOD SMUPH > 0) AND (* If we could use Hours and be exact, fine *)
                           (Dur < 999) THEN (* Dependency Form restricts us to 3 digits *)
                            Scale       := Minutes;
                        END;
                    END;
                END;
                AddEdgeWithTasks( EdgePtr, AnEdgesTask(TaskPtr1),
                                  AnEdgesTask(TaskPtr2), FALSE);
            ELSE
                (* If we failed for some reason other than that the
                   dependency already exists (we may be combining),
                   then it is serious. *)
                TellOfNoMemory( AddingEdges );
                Task1^.Methods^.UnlockFlexStorDataObject (Task1);
                Task2^.Methods^.UnlockFlexStorDataObject (Task2);
                RETURN FALSE;
            END;
        END;
        Task1^.Methods^.UnlockFlexStorDataObject (Task1);
        Task2^.Methods^.UnlockFlexStorDataObject (Task2);

        RETURN TRUE;

    END AddEdge;

BEGIN
    
    IF (NOT HeapAvailable()) THEN
        RETURN FALSE;
    END;

    GetMessage(12427, S);
    IF (NOT CreateThermometer(Thermometer, 0, 0, S, EdgeCount)) THEN
        Thermometer := AThermometer(NIL);
    END;

    (* Reset to the beginning of the file and read records, looking
       for tasks. *)

    PrepareForIO(F);
    Reset(F);
    SetRead(F);

    IF (CheckIO(F) <> done) THEN
        FileComplaint(F);
        RETURN FALSE;
    END;

    EdgesRead := 0;

    LOOP
        ReadRecordPreface (F, Type, ID, Length);
        IF (CheckIO(F) <> done) THEN
            FileComplaint(F);
            EXIT;
        END;

        CASE Type OF
        | 0 : (* File Ender *)
                EXIT;

        | 7,8 : (* A Task Dependency - "edge" *)

            ReadRecordBody( F, Length, TLWinEdge );

            IF (Length <> VAL(LONGINT,SIZE(TLWinEdge))) THEN
                ErrorPhrase(30803);  (* wrong record length. *)
                EXIT;
            END;

            IF (NOT AddEdge(TLWinEdge.PredecessorID,
                            TLWinEdge.SuccessorID)) THEN
                ErrorPhrase(30811); (* could not add dependency *)
                EXIT;
            END;
            
            INC(EdgesRead);
            UpdateThermometer( Thermometer, EdgesRead );
            
        ELSE
            SkipRecordBody(F, Length);
        END;
    END;

    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

    RETURN (CheckIO(F) = done);

END GetEdges;


PROCEDURE GetProjectFile(VAR Directory    : ARRAY OF CHAR;
                         VAR FileName     : ARRAY OF CHAR) : BOOLEAN;
VAR
    i,j         : CARDINAL;
    Version     : CARDINAL;
    f           : File;
    FileType    : AFileType;
    s           : ARRAY [0..255] OF CHAR;
    Description : ARRAY [0..13] OF CHAR;
    C           : CHAR;
    ok          : BOOLEAN;
    Extension   : ARRAY [0..3] OF CHAR;

        (* OTCleanup - some or many tasks may not have been "treed" properly,
            since children tasks may have been read in before their parents
            (in TLWin this is never the case).
            
            So this makes sure parents are reunited with their children and
            then sorts according to the last "manual" sort.  *)

    PROCEDURE OTCleanup();
    VAR
        id, ParentID        : CARDINAL;
        CurrentParentNode,
        TrueParentNode,
        TaskNode            : ATreeNode;
        Task                : ATaskPtr;
    BEGIN
        id := 0;
        WHILE ( id <= FileHeaderRecord.MaximumTaskID) DO
            IF FindEntryByID( TaskTable, id, TaskNode ) AND
               (TaskNode <> ATreeNode(NIL)) THEN
                (* get current parent *)
                CurrentParentNode := TaskNode^.Methods^.Parent( TaskNode );

                (* get "real" parent *)
                Task := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
                ParentID := Task^.XX;
                TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);

                IF (ParentID <> 0) THEN
                    IF FindEntryByID( TaskTable, ParentID, TrueParentNode ) AND
                       (CurrentParentNode <> TrueParentNode) THEN
                        (* unhook from tree and reattach to TrueParentNode *)
                        TaskNode^.Methods^.DeList( TaskNode );
                        TrueParentNode^.Methods^.AddAsLastChild(TrueParentNode,
                                                            TaskNode);
                    END;
                END;
            END;

            INC(id);
        END;
    END OTCleanup;

    PROCEDURE TLWinCleanup();
    VAR
        TaskNode            : ATreeNode;
        Assignments         : AnAssignmentArray;
        Count, id, i        : CARDINAL;
        Task                : ATaskPtr;
    BEGIN
        id := 0;
        WHILE (id <= FileHeaderRecord.MaximumTaskID) DO
            IF FindEntryByID( TaskTable, id, TaskNode ) AND
               (TaskNode <> ATreeNode(NIL)) THEN
                Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
                WITH Task^ DO
                    IF (DurationMethod = EffortDriven) THEN
                        (* does it have any effort actually assigned? if not, 
                           make it DurationDriven *)
                        IF (Plan.Assignments <> AnExtHandle(NIL)) THEN
                            Count := LockObjectArray( Plan.Assignments,
                                                    Assignments,
                                                    TSIZE( AnAssignmentRecord )
                                                    );
(*$O-*)
                            WHILE (i < Count) AND
                                (Assignments^[i].Resource^.Type <> Employable) DO
                                INC(i);
                            END;
(*$O=*)
                            IF NOT (i < Count) THEN
                                DurationMethod := DurationDriven;
                            END;
                        ELSE
                            DurationMethod := DurationDriven;
                        END;
                    END;
                END;
                TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
            END;
            INC(id);
        END;
    END TLWinCleanup;

BEGIN
    SetLengthOf(Description,0);

    IF (NOT RequestFileOpenReadOnly(Directory,FileName,Description,f) ) THEN
        RETURN FALSE;
    END;

    ExtractFileNameParts( FileName, s, s, ProjectFileName, Extension );

    GetMessage( 30820, s);
    IF StringsEqual( Extension, s ) THEN
        SetKindOfFile( RockyFile );
        TaskRecordSize := VAL(LONGINT, SIZE(ATLWinTask));
    ELSE
        GetMessage ( 30821, s );
        IF StringsEqual( Extension, s ) THEN
            SetKindOfFile( OnTargetFile );
            TaskRecordSize := VAL(LONGINT, SIZE(ATLWinTask)) -
                            VAL(LONGINT, SIZE(ATLWinTaskRecordDelta));
        ELSE
            FatalError(); (* unknown file type *)
        END;
    END;

    PrepareForIO(f);

    IF (CheckIO(f) <> done) THEN
        FileComplaint(f);
        Close(f);
        RETURN FALSE;
    END;

    IF (NOT GetHeader(f)) THEN
        Close(f);
        RETURN FALSE;
    END;


    (* "Not yet implemented"

    DisplayMessage( ModuleNumber + 85 );  (* "Reading calendar information..." *)
    BeforeCalendarChange();   (* Save a copy *)
    GetCalendar(f);           (* Get from file *)
    CalendarUpdate();         (* Do the conversions *)

    *)

    ResourceTable := ACorrelationTable(NIL);                   (* 16-Apr-92 *)
    TaskTable := ACorrelationTable(NIL);

    ok := GetResources( f, ResourceTable, FileHeaderRecord.MaximumResourceID,
                        FileHeaderRecord.NumberOfResources,
                        FixedCostNode);

    IF (ok AND (GetTasks( f, TaskTable, FileHeaderRecord.MaximumTaskID,
                  FileHeaderRecord.NumberOfTasks ))) THEN
            (* post-process On Target *)
        IF (KindOfFile() = OnTargetFile) THEN
            OTCleanup();
        ELSE
            TLWinCleanup();
        END;
    ELSE
        ok := FALSE;
    END;

    ok := ok AND GetAssignments( f, TaskTable, ResourceTable,
                                 FileHeaderRecord.NumberOfAssignments);

    ok := ok AND GetEdges(f, FileHeaderRecord.NumberOfPredecessors );

    DisposeCorrelationTable( ResourceTable );
    DisposeCorrelationTable( TaskTable );
    Close(f);

    IF (ok) THEN
        (* set calculation, schedule options *)
        WITH FileHeaderRecord DO
            Levelling       := (LevelResources IN Flags);
            TimeConstrained := FALSE;
            MoveFutureTasks := (SlipFutureToAsOf IN Flags);
            IF (ManualRecalc IN Flags) THEN
                CalculationState[Scheduling].When := ManualCalc;
            ELSE
                CalculationState[Scheduling].When := AutoCalc;
            END;
        END;
        KeepEffortContiguous := TRUE;
        ZeroIsLowestPriority := FALSE;

        (* set AsOf *)
        IF (FileHeaderRecord.AsOfDate = 0L) THEN
            (* supposedly this means we should set AsOf to Today *)
            AsOfSettingOption := AsOfToday;
        ELSE
            AsOfDate := TLWin1DateToDate(FileHeaderRecord.AsOfDate);
            AsOfSettingOption := AsOfWhenISay;
        END;
        SetAsOfDate();
    END;

    RETURN ok;

END GetProjectFile;




PROCEDURE FileComplaint(VAR f:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
   s2 : ARRAY [0..80] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+6,s);   (*  "Project file "  *)
    ConcatLS(s,ProjectFileName);
    FileResultMeans(f,s2);
    ConcatLS(s,s2);
    Error(s);
    ErrorFlag := TRUE;
    PrepareForIO(f);
END FileComplaint;



PROCEDURE LoadOneFile (VAR Directory    : ARRAY OF CHAR;
                       VAR FileName     : ARRAY OF CHAR) : BOOLEAN;

VAR
    Result             : BOOLEAN;

BEGIN

    UnSetState(Sorted);
    UnSetState(Filtered);
    SaveTaskDates := TRUE;

    ResetFilters;                           (* 3/1/88 EGK *)
    CurrentChartFormat := NIL;
    CurrentNetLayout := NIL;
    EnlargedNetLayout := NIL;

    Result := GetProjectFile(Directory, FileName);

    ScheduleSaved := TRUE;      (* 2/29/88 EGK *)

    RETURN Result;

END LoadOneFile;


PROCEDURE ReadInFile();
VAR
    Device       : ARRAY [0..80] OF CHAR;
    Directory    : ARRAY [0..70] OF CHAR;
    Extension    : ARRAY [0..3]  OF CHAR;
    FileName     : ARRAY [0..15] OF CHAR;
    ok           : BOOLEAN;
BEGIN
    Directory    := "Program Copyright (c) 1989 Symantec Corporation.";
    Directory[0] := 0C;
    Message(Directory);   (* Erase the "Now loading" message. *)

    IF (P = NIL) THEN
        FatalError(); (* Improper call - not via TLGETIT (Old TLWHAT file?) *)
    END;

    ExtractFileNameParts( P^,
                          Device,
                          Directory,
                          FileName,
                          Extension );

    ConcatLS( Device,    Directory );
    ConcatS(  FileName,  "."       );
    ConcatLS( FileName,  Extension );

    CASE RetrieveType OF
    | RetrieveAll :
        ErrorFlag := NOT LoadOneFile( Device, FileName );
    ELSE
        FatalError;
    END;

END ReadInFile;



PROCEDURE RenumberEverything();

VAR
    s                       : ARRAY [0..11] OF CHAR;

BEGIN                       (* RenumberEverything *)

    SetString(s, "TLRENUM");
    IF (NOT CallOverlay(s)) THEN
    END;

END RenumberEverything;


BEGIN (* TLITW1 *)
    NoteMessage[0]   := 0C;             (* No edge message read yet *)
    GlobalCursorNode := ATreeNode(NIL); (* No cursor node set yet *)
    P := OverlayContext();

    IF (NOT HeapAvailable()) THEN
        TellOfNoMemory( StartingUp );
        P^[1] := "0";                   (* This is the error signal *)
        RETURN;
    END;

    UnSetState (Scheduled);

    ErrorFlag := FALSE;

    ReadInFile();

    RenumberEverything();

    LayoutChanged ();

    SetLengthOf(NoteMessage,0);
    Message(NoteMessage);

    IF (ErrorFlag) THEN
        P^[1] := "0";
    ELSE
        P^[1] := "1";
    END;

END TLITW1.


