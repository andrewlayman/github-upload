    (*V1=OS2 OS2 code changes.    *)
    (*V2=DOS Regular DOS TL code. *)

(*<DOS*)
MODULE TLITL5;
(*DOS>*)


(*<OS2
IMPLEMENTATION MODULE TLITL5;
OS2>*)


    (*------------------------------------------------------------------------

                        Import Time Line 5.0 files.


    -------------------------------------------------------------------------*)


(*  =========================================================================
    Last Edit : September 18, 1991 2:02PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description:


    MODIFICATION HISTORY:

        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
       29-May-90 AJL  - Use the Filing.ALoadProc and the RateList module
                        to store rate lists.
       01-Jun-90 AJL  - Removed use of the PlanLevel variables from Planner.
       25-Jun-90 AJL  - Initialized the VaryingAssignment field in assignments
                        to NIL.
        8-Aug-90 RSC  - Minor cleanups; add new resource fields to save/load.
       13-Aug-90 RSC  - Ajust some of the INITs upon calendar reading.
       15-Aug-90 RSC  - Ajust version number and other tweaks to make reading
                        work.
        5-Sep-90 RSC  - Save and load assignment record contents.
                        Split out resource and assignment reading into
                        IResource.Mod to save symbol table space.
       12-Sep-90 RSC  - Fixed for new Allocs.Def
       26-Oct-90 PFG    Load column names.  Also define a type called
                        ASetOfSubfileNumbers so there can be more than 16
                        types.
       12-Nov-90 RSC  - Load Edge Dur's independantly of SMUPHs, so we
                        can COMBINE schedules of differing precisions.
       21-Jan-91 RSC  - Remove Fiscal Calendar.  Lower number of task locks.
       24-Jan-91 RSC  - Zapload texts.
       13-Feb-91 RSC   Change the calls to registry.
        5-Mar-91 TGS    Import LayoutChanged and call it when retrieving a
                        schedule, so we reset the Gantt layout properly.
       12-Mar-91 TGS    Call LayoutChanged on File/Combine/Calendar|Layout.
       13-Mar-91 AJL    Unlock the task handle before reading the assignments
                        and lock it again later.  We need to do this to 
                        keep the number of outstanding locks always 4 or 
                        fewer.  (When reading assingments, the TaskFind module
                        has one lock, the assignment array is locked, the
                        datelist and varying assignment list become locked.)
        2-Apr-91 TGS    4.5 --> 5.0:
                        Renamed this module from TLITL45 to TLITL5
                        Look for Signature = 450 OR 500 (we'll start saving
                            "500")
       10-Apr-91 AJL  - Use the DataFiles module for subfile numbers.
                      - Read the Counts subfile and use it to put up a 
                        thermometer for tasks and edges.
       29-Apr-91 RSC  - On Edge reading, compute the duration in a calendar
                        independant way (what I attempted first in 12-Nov
                        of last year).
        7-May-91 RSC  - Remove scrub of neg slack in SanitizeTask.
                        Also, report ONCE of assignment duplicates, not
                        once per task.
        4-Jun-91 RSC  - Allow for "optional" files to retrieve, this is
                        used by the OnTarget importer.
       15-Jul-91 PFG    In GetBugs(), if the subfile doesn't exist, set the
                        default values rather than generating an error.  
                        This was done for schedule files created by the
                        OnTarget importer.
       18-Jul-91 TGS    Change any AssignmentDriven tasks to DurationDriven
                        on their way in.
       30-Jul-91 EGK    Switched the order of reading of the CAL and ENV
                        subfiles.  Since the As-of date is now written in
                        32-bit format, but converted to a small date after
                        it's read in, we must have the correct calendar
                        before we do that conversion.  See Eve bug #4810.
        14-Aug-91 PFG   For some reason, code was removed that allowed the
                        user to choose whether to preserve durations or
                        end dates if two schedules with different calendars
                        were combined.  I dissected the code from TLITL4,
                        added the new DateBlock fields and put it in here.
       14-Aug-91 EGK    Don't mess with the task duration when reading the
                        baseline date block.
       16-Aug-91 PFG    Added a parameter to the Layout and Filter info
                        procs (in LoadCommon) so that previous versions
                        can notify the procs to update for changes to
                        column order.
        22-Aug-91 PFG   If imported tasks come in with a scale of "years",
                        change to months in SanitizeTask.  I discovered in
                        the process that the last task in a schedule never
                        got sanitized, so I fixed that.
        18-Sep-91 EGK   Fixed up the logic in ConvertDateBlocks so that for
                        file-combine, we compute the duration based on the
                        start and end dates.
        25-Sep-91 AJL  -Add BOOLEAN return value to ReadAssignmentArray.
                       -Set AssignmentHandles to NIL unless they are read
                        correctly.
                       -Update the thermometer correctly even when doing
                        a file combine.  Use TasksReadCount rather than
                        TotalTasksCount.
        19-Mar-92 LAA   After reading in a project, force a manual recalc if
                        we didn't find any new-format varying assignment
                        records.  This indicates an old format file, and
                        numbers won't be as correct as they should be until
                        a recalc has been done.
    =========================================================================
*)


FROM Allocs                 IMPORT ATask, ATaskPtr, ATaskName, ATaskStatus,
                                   ADateBlock, ABigDateBlock, AFixType,
                                   TskNmLen, ARollupStatus, ADurationMethod,
                                   ATaskFlag, ATaskFlagSet, AStartStatus,
                                   ATaskStatusSet, AddTask,
                                   CreateTask, CopyTask, TaskTree,
                                   CheckTaskValid;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate,
    (* PROC *)                  SetAsOfDate;

FROM Chart                  IMPORT  BugTaskA, BugDayA, BugTaskB, BugDayB,
                                    CursorTask, CursorDay, GanttChart;

FROM ChartControl           IMPORT  UnSetState, AChartState;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR  *)                  LayoutTree, CurrentChartFormat,
                                DefaultChartFormat, 
    (* PROC *)                  CreateLayout, SortLayouts,
                                LayoutChanged;

FROM DataFiles    IMPORT
    (* CONST *)           ProjectType, EnvironmentType, PrintFileType,
                          SummaryType, ResourceType, TaskType, EdgeType,
                          CalendarType, BugsType, SignatureType, PrinterTableType,
                          FileNamesType, VideoType, PreferencesType,
                          CodeSetsType, FontsType, PlotsType, FiltersType,
                          HeldItemsType, MemosType, LayoutsType, NetLayoutsType,
                          TLGSDeviceType, PalettesType, ColumnNamesType,
                          CountsType,
                          ResourceFileVersionNumber, TaskFileVersionNumber,
                          EdgeFileVersionNumber, 
                          CalendarFileVersionNumber, BugsFileVersionNumber,
                          ProjectFileVersionNumber,
    (* TYPE *)            AQuantityOf, AQuantities;

FROM Dialog                 IMPORT Message, Error, FatalError, Burp,
                                   MultipleChoiceBox, ADialogOption,
                                   WarningBox, NotYetImplemented,
                                   ErrorPhrase;

FROM Directory              IMPORT
        (* CONST *)             MaximumPathNameLength,
        (* PROCS *)             ExtractFileNameParts, PathLookupStart;

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
                                CreateExtObjectWithSize, LockObject,
                                LockObjectArray, SetExtSize, ArraySize,
                                GetExtStatus;

FROM FileAux                IMPORT FileResultMeans,
                                   FlushBuffer, PrepareForIO, CheckIO;

FROM FileOpen               IMPORT  RequestFileOpenReadOnly,
                                    RequestFileFind;

FROM FileSystem             IMPORT  File, Lookup, Response, Close,
                                    Create, Rename, Delete;

FROM Filters                IMPORT  ResetFilters;

FROM ForeignSubfiles        IMPORT
    (* TYPE *)                      AFileType,
    (* PROC *)                      DigestSubfile;

FROM IlsaStatic   IMPORT
    (* TYPE *)           ATLGSTitleBlockPtr, ATLGSColorAssignmentPtr,
                         ATLGSPertRecordPtr, ATLGSGanttRecordPtr,
                         ATLGSTreeRecordPtr, ATLGSChartType,
                         ATLGSPageRecordPtr,
    (* VAR *)            PaletteTree,
    (* PROC *)           LockTLGSTitleBlock, TLGSPageRecord, TLGSGanttRecord,
                         TLGSPertRecord, TLGSTreeRecord, UnlockTLGSTitleBlock;

FROM IResource      IMPORT
    (* TYPE *)          ADuplicateAction, AGetDupeActionProc,
    (* VAR *)           NewVaryingAssgnFormatFound,
    (* PROC *)          ReadAssignmentArray, GetResources;

FROM Kbio                   IMPORT avidmode,
                                   maxrow, maxcol,
                                   GetAnyCode, BreakRequested, ClearBreak,
                                   PutString;

FROM LoadCommon             IMPORT  ErrorFlag,
                                    SkipRecordBody, GetLayoutsInfo,
                                    GetCalendar,
                                    GetTheEnvironment, GetSignature,
                                    SignatureError, ReadDate,
                                    ReadManyTextLines, GetFiltersInfo,
                                    ReadTaskNumber, GetHeldItems,
                                    GetMemosInfo, GetNetLayoutsInfo,
                                    GetPalettesInfo, GetColumnNames,
                                    ReadManyOldTextLines;

FROM LStrings               IMPORT SetString, ConcatLS, ConcatS, CtoS,
                                   SubStr, LStringToTString, TStringToLString,
                                   Search, Insert, Remove, Copy, SetLengthOf,
                                   Procustes, StoC, Fill, Upshift, TrimRear;

FROM Menus                  IMPORT Menu, NoYes;

FROM MsgFile                IMPORT  GetMessage, DisplayMessage, ConcatMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NetLayoutTree, CurrentNetLayout,
                                EnlargedNetLayout;

FROM Overlays               IMPORT
        (* PROCS *)                 OverlayContext, CallOverlay;

FROM Planner                IMPORT 
    (* TYPE *)                  ACalcComponent, AWhenToCalc,
    (* VAR *)                   ScheduleComputedOk, ScheduleEndDate,
                                ScheduleStartDate, CalculationState;

FROM PrintStatic            IMPORT  PrintDiskFileName, ReportSettings;

FROM Progress               IMPORT
    (* TYPE *)                      AThermometer,
    (* PROC *)                      CreateThermometer, UpdateThermometer, 
                                    DiscardThermometer;

FROM RecordIO               IMPORT  ReadRecord, ReadString, ReadRecordPreface,
                                    ReadRecordBody, ReadStringBody;

FROM Registry               IMPORT
    (* CONST *)                 QCapacity,
    (* TYPE *)                  ARegistryDataRecord,
    (* VAR  *)                  UserName, ProductName;

FROM RegCapacity            IMPORT
    (* PROC *)                  GetRegistryInfo;

FROM RsrcMod                IMPORT
    (* VAR   *)                 ResourceTree;

FROM Schedule               IMPORT ProjectName, ProjectText,
                                   RetrievalName, ProjectStartDate,
                                   Author, FullScheduleName, RevisionNumber,
                                   ConfigSaved, PlannedProjectName,
                                   ScheduleSaved, Loaded, ProjectMedia;

FROM Space                  IMPORT  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM Subfiles               IMPORT  StartFileInput, StartSubfileInput,
                                    TraverseSubfiles;

FROM SYSTEM                 IMPORT ADDRESS, TSIZE, SIZE, ADR, BYTE;

FROM TaskFind               IMPORT
    (* PROC *)                  TaskFindBegin, TaskFindEnd, FindTaskByNumber,
                                AddTaskByNumber;

FROM Text                   IMPORT
    (* PROC *)                  CreateText, TextExists, DiscardText, AppendLine,
                                Compress, AText;

FROM TimeConversions        IMPORT
    (* PROC *)                  BeforeCalendarChange, AfterCalendarChange,
                                ToNewDuration, ToNewDate, ToNewScale;

FROM Timei                  IMPORT
    (* CONST*)                  MinDate, NoDuration,
    (* TYPE *)                  ADuration, ADurationUnit, ADate, ATimeInfo,
    (* PROC *)                  TtoTimeU;

FROM Timeu                  IMPORT
    (* VAR *)                   SMUPH, SMU,
    (* PROC *)                  SetStartingMonth, DownScale;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM Transfer               IMPORT  ARetrieveType, RetrieveType,
                                    AHeaderRecord;

FROM TreeObjects            IMPORT
    (* TYPE *)                      ATree, ATreeNode, ATreeOrder,
    (* PROC *)                      CreateTreeNode,
                                    ValidateTree, ValidateTreeNode;




CONST
    ModuleNumber           = 12400; (* SAME AS TLITL3.MOD *)


    (*  Subfile numbers in the Time Line save file  *)
CONST
     HeaderType            = 0;     (* Record type of a node header, which
                                       contains visibility information     *)

     OldNotesType          = 100; (* Pre- Jan 10 91 *)
     OldSummarizesType     = 103;
     OldCodingType         = 123;
     NotesType             = 102;
     SummarizesType        = 104;
     CodingType            = 124;
     PlanAssignmentsType   = 70;
     BaseAssignmentsType   = 80;
     DateBlockPlan         = 90;
     DateBlockBase         = 91;




CONST
    MAXCARDINAL = 65535;

TYPE
    ANoMemoryPlace   = (StartingUp, AddingTasks, AddingEdges,
                        AddingResources, AddingAssignments);



VAR
    GlobalCursorNode,
    Node                : ATreeNode;
    P                   : POINTER TO ARRAY [0..255] OF CHAR;
    TaskBugCount        : CARDINAL;
    RecordQuantities    : AQuantities;
    DuplicateAction     : ADuplicateAction;
    SaveTaskDates       : BOOLEAN;
    ProjectFileName     : ARRAY [0..81] OF CHAR;
    NoteMessage         : ARRAY [0..39] OF CHAR;
    MakeSummaryTask     : BOOLEAN;










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





PROCEDURE GetDuplicateAction( VAR DuplicateName : ARRAY OF CHAR ):ADuplicateAction;
VAR
    Choice  : CARDINAL;
    s       : ARRAY [0..255] OF CHAR;
    Title   : ARRAY [0..29]  OF CHAR;
    Prefix  : ARRAY [0..50]  OF CHAR;
    Choices : ARRAY [0..99]  OF CHAR;
BEGIN
    IF (DuplicateAction = DontKnow) THEN
        Choice := 1;
        GetMessage(ModuleNumber+ 7,s      ); (* 'Duplicate name:"' *)
        ConcatLS(  s, DuplicateName       ); (* Roger *)
        ConcatMessage( s, ModuleNumber + 8 ); (* '".  What is the policy?' *)
        GetMessage(ModuleNumber+11,Title  ); (* "Duplicate Action" *)
        GetMessage(ModuleNumber+ 9,Prefix ); (* "I should always:" *)
        GetMessage(ModuleNumber+10,Choices); (* "Keep current,Overwrite data" *)
        REPEAT
        UNTIL ( MultipleChoiceBox( s, Title, OfferHelp, Prefix, Choices, Choice ) );
        DuplicateAction := VAL(ADuplicateAction, Choice-1+ORD(Ignore) );
    END;

    RETURN DuplicateAction;
END GetDuplicateAction;





PROCEDURE GetProjectDetails(VAR f:File);
VAR
    Version : CARDINAL;
    Type,
    Length  : CARDINAL;
    s                       : ARRAY [0..80] OF CHAR;

BEGIN
    IF (NOT StartSubfileInput(f,ProjectType,Version)) THEN
        RETURN;
    END;

    DisplayMessage( ModuleNumber + 83 );  (* "Reading schedule options ..." *)

    ProjectText := AText(NIL);                                     (* 12/02/86 LAA *)

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) OR (ErrorFlag) THEN EXIT; END;
        CASE Type OF
        | 0  :  ReadStringBody(f,Length,Author);
        | 1  :  ReadStringBody(f,Length,FullScheduleName);
        | 2,3:  ReadManyOldTextLines(f, Length, Type, ProjectText);            (* 12/02/86 LAA *)
        | 4  :  ReadStringBody(f,Length,PlannedProjectName);
        | 5  :  ReadDate(f,Length,ScheduleEndDate);             (* 20-Jan-88 LAA *)
        | 6  :  ReadDate(f, Length, ScheduleStartDate);         (* 29-May-89 LAA *)
        | 7  :  ReadRecordBody(f,Length,ADR(RevisionNumber),SIZE(RevisionNumber));
        | 12 :  ReadManyTextLines(f, Length, Type, ProjectText);           (* 1/10/91 AJL *)
        | 0FFH : EXIT;
        ELSE    SkipRecordBody(f,Length);
        END;
    END;
    Compress(ProjectText);

END GetProjectDetails;




PROCEDURE GetPrinterSettings(VAR f : File);
VAR
    Version : CARDINAL;
    Type,
    Length  : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput(f,PrintFileType,Version)) THEN
        RETURN;
    END;

    DisplayMessage( ModuleNumber + 84 );  (* "Reading printer settings..." *)

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
        | 0  :  ReadStringBody(f,Length,PrintDiskFileName);
        | 1  :  ReadRecordBody(f,Length,ADR(ReportSettings),SIZE(ReportSettings));
        | 0FFH : EXIT;
        ELSE    SkipRecordBody(f,Length);
        END;
    END;
END GetPrinterSettings;






PROCEDURE GetCounts(VAR f : File);
VAR
    Version : CARDINAL;
    Type,
    Length  : CARDINAL;
    QuantityOf : AQuantityOf;
BEGIN
        (* Set initial counters to zero. *)
    FOR QuantityOf := MIN(AQuantityOf) TO MAX(AQuantityOf) DO
        RecordQuantities[ QuantityOf ] := 0L;
    END;

    IF (NOT StartSubfileInput(f,CountsType,Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
        | 1  :  ReadRecordBody(f,Length,ADR(RecordQuantities),SIZE(RecordQuantities));
        | 0FFH : EXIT;
        ELSE    SkipRecordBody(f,Length);
        END;
    END;
END GetCounts;












PROCEDURE GetLocalSMUPH(VAR f:File):ADuration;
VAR
    LocalSMUPH : ADuration;
    Type : CARDINAL;
    Length : CARDINAL;
    Version: CARDINAL;
BEGIN
    IF (NOT StartSubfileInput(f,CalendarType,Version)) THEN
        RETURN SMUPH;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
        | 2  :  ReadRecordBody(f,Length,ADR(LocalSMUPH),SIZE(LocalSMUPH));
                EXIT;
        | 0FFH : LocalSMUPH := SMUPH;     (* Couldn't find it. *)
                EXIT;
        ELSE    SkipRecordBody(f,Length);
        END;
    END;

    RETURN LocalSMUPH;

END GetLocalSMUPH;





PROCEDURE RenumberTheTask   (VAR Node       : ATreeNode;
                                 Context    : ADDRESS   );
VAR
    Task        : ATaskPtr;
BEGIN
    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    WITH Task^ DO
        IF (TaskID > 0) THEN
            TaskID := -TaskID;
        END;
    END;
    Node^.Methods^.UnlockFlexStorDataObject (Node);
END RenumberTheTask;




PROCEDURE SanitizeTask ( TaskPtr : ATaskPtr );
VAR
    FixedStart  : ADate;
BEGIN
    FixedStart := BigTimeToCalendarTime( TaskPtr^.UserEnteredStartDate );  (* 12-Sep-90 RSC *)
    WITH TaskPtr^.Plan.Dates DO
        IF (FixedStart > EarlyStart) THEN
            EarlyStart := FixedStart;
        END;
            (* 7-May-91 RSC  *)
(*        IF (LateFreeEnd < EarlyEnd) THEN*)
(*            LateFreeEnd := EarlyEnd;*)
(*        END;*)
(*        IF (LateTotalEnd < EarlyEnd) THEN*)
(*            LateTotalEnd := EarlyEnd;*)
(*        END;*)
    END;
        (* If the project was saved with any tasks needing
           recalculate, turn recalc needed on. *)
    IF (NeedsRecalculate IN TaskPtr^.TaskStatusSet) THEN      (* AJL 2/2/88 *)
         UnSetState (Scheduled);
    END; 
    (* 18-Jul-91 TGS If this is assignment driven, make it duration driven *)
    IF TaskPtr^.DurationMethod = AssignmentDriven THEN
        TaskPtr^.DurationMethod := DurationDriven;
        UnSetState (Scheduled);
    END;

    WITH TaskPtr^ DO            (*  Change years to months.  The task form
                                    doesn't allow years.  *)
        IF (scale = Years) THEN
            scale := Months;
        END;
        IF (EffortScale = Years) THEN
            EffortScale := Months;
        END;
    END;

END SanitizeTask;






PROCEDURE GetTasks(VAR f : File);
VAR
    TaskNode            : ATreeNode;
    LastTaskAdded       : ATreeNode;
    CurrentTask         : ATaskPtr;
    Version             : CARDINAL;
    TaskRecordLength    : CARDINAL;
    Type                : CARDINAL;
    TotalTaskCount      : CARDINAL;
    TasksReadCount      : CARDINAL;
    MaxReadCount        : CARDINAL;
    Length              : CARDINAL;
    LevelOffset         : CARDINAL;
    BadAssignmentCount  : CARDINAL;
    LocalSMUPH          : ADuration;
    AssignmentsHandle   : AnExtHandle;
    Amount              : REAL;
    Multiplier          : REAL;
    Header              : AHeaderRecord;
    newtask             : ATask;
    Thermometer         : AThermometer;
    TaskCount           : CARDINAL;
    s                   : ARRAY [0..199] OF CHAR;
    Title               : ARRAY [0..29] OF CHAR;
    DuplicateAssignments,
    AnyDuplicateAssignments : BOOLEAN;


    (* This updated by RSC 6/20/89 *)

    PROCEDURE GetMaxReadCount() : CARDINAL;
    VAR
        MaximumAllowed      : CARDINAL;
        RegistryDataRecord  : ARegistryDataRecord;
    BEGIN
        IF (GetRegistryInfo( UserName,  ProductName,
                             QCapacity, RegistryDataRecord )) THEN
            MaximumAllowed := RegistryDataRecord.CardinalValue;
            IF (MaximumAllowed = 0) THEN
                MaximumAllowed := MAXCARDINAL;
            END;
        ELSE
            MaximumAllowed := 0;
        END;

        RETURN MaximumAllowed;

    END GetMaxReadCount;



    PROCEDURE AddIt;
    VAR
        ThisLevel       : CARDINAL;
        LastLevel       : CARDINAL;

    BEGIN
            (* Create a tree node that has a task record attached. *)

        TaskNode := CreateTask();

        IF (TaskNode = NIL) THEN
             (* Must be problem with heap -- can't check though
                because the stack is popped now and so the problem
                is no longer here. *)
             CurrentTask := NIL;
             TellOfNoMemory( AddingTasks );
             RETURN;
        END;

        INC( TasksReadCount );

        IF ((TasksReadCount MOD 8) = 0) THEN
            UpdateThermometer(Thermometer,TasksReadCount);
        END;

            (*  If this is the first task we're reading in, and it's a
                file-combine, but we're not creating a top-level summary
                task, then the cursor should go on this task.  This is
                the best place to detect that.
            *)

        IF (CurrentTask = NIL) THEN
            IF (RetrieveType = RetrievePart) AND NOT (MakeSummaryTask) THEN
                GlobalCursorNode := TaskNode;           (* 7/7/89 EGK *)
            END;
        END;

            (* Locate the attached task record. *)

        CurrentTask := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

        IF (CurrentTask = NIL) THEN
            FatalError();
        END;

            (* Change the contents of the attached task record to
               reflect the data record read from the file. *)

        CurrentTask^ := newtask;
        (* 21-Jan-91 RSC *)
(*        TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);*)

        AddTaskByNumber( CurrentTask^.TaskID, TaskNode );    (* 24-Jan-91 RSC *)


        TaskNode^.Methods^.SetAttributes (TaskNode, Header.Attributes);
        ThisLevel := Header.Level + LevelOffset;

            (* Put the tree node into the task tree at the right place. *)

        IF (LastTaskAdded = NIL) THEN                   (* 6/1/89 EGK *)
            AddTask (TaskNode, NIL, NIL);
        ELSE
            LastLevel := LastTaskAdded^.Methods^.IndentationLevel (LastTaskAdded);
            IF (ThisLevel > LastLevel) THEN
                AddTask (TaskNode, LastTaskAdded, NIL);
            ELSIF (ThisLevel = LastLevel) THEN
                AddTask (TaskNode, NIL, LastTaskAdded);
            ELSE
                REPEAT
                    LastTaskAdded := LastTaskAdded^.Methods^.Parent (LastTaskAdded);
                    DEC (LastLevel);
                UNTIL (LastLevel = ThisLevel);
                AddTask (TaskNode, NIL, LastTaskAdded);
            END;
        END;

        LastTaskAdded := TaskNode;
        (* 21-Jan-91 RSC *)
(*        CurrentTask := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);*)
    END AddIt;


    PROCEDURE ConvertDateBlocks( UseBaseLine : BOOLEAN );
    VAR BigDateBlock : ABigDateBlock;
           DateBlock :    ADateBlock;
           R         : REAL;
    BEGIN
        IF (CurrentTask <> NIL) THEN
            ReadRecordBody( f, Length, ADR(BigDateBlock),SIZE(BigDateBlock));

            WITH BigDateBlock DO
                DateBlock.EarlyStart     := BigTimeToCalendarTime( EarlyStart     );
                DateBlock.LateFreeStart  := BigTimeToCalendarTime( LateFreeStart  );
                DateBlock.LateTotalStart := BigTimeToCalendarTime( LateTotalStart );
                DateBlock.LateIndStart   := BigTimeToCalendarTime( LateIndStart   );
            END;
                (* For baseline dates, we NEVER calculate the end date
                   based on the duration value.     (3/8/88 EGK )    *)

            IF (NOT UseBaseLine) AND (NOT SaveTaskDates) THEN

                R := (FLOAT(CurrentTask^.duration) * Multiplier) + 0.5;

                IF (R < 65535.0) THEN
                    CurrentTask^.duration  := TRUNC(R);
                ELSE
                    CurrentTask^.duration  := 65535;
                END;

            ELSE
                WITH BigDateBlock DO
                    DateBlock.EarlyEnd     := BigTimeToCalendarTime( EarlyEnd     );
                    DateBlock.LateFreeEnd  := BigTimeToCalendarTime( LateFreeEnd  );
                    DateBlock.LateTotalEnd := BigTimeToCalendarTime( LateTotalEnd );
                    DateBlock.LateIndEnd   := BigTimeToCalendarTime( LateIndEnd   );
                END;
            END;

            IF (NOT UseBaseLine) THEN
                IF (NOT SaveTaskDates) THEN
                    DateBlock.LateFreeEnd  := DateBlock.LateFreeStart + CurrentTask^.duration;
                    DateBlock.LateTotalEnd := DateBlock.LateTotalStart + CurrentTask^.duration;
                    DateBlock.EarlyEnd     := DateBlock.EarlyStart + CurrentTask^.duration;
                    DateBlock.LateIndEnd   := DateBlock.LateIndStart + CurrentTask^.duration;

                ELSE    (* 9/18/91 EGK *)

                    IF (DateBlock.EarlyEnd >= DateBlock.EarlyStart) THEN
                        CurrentTask^.duration := DateBlock.EarlyEnd - DateBlock.EarlyStart;
                    END;
                END;
            END;

            IF (UseBaseLine) THEN
                CurrentTask^.BaseLine.Dates := DateBlock;
            ELSE
                CurrentTask^.Plan.Dates     := DateBlock;
            END;
        ELSE
            SkipRecordBody (f, Length);
        END;
    END ConvertDateBlocks;


BEGIN
    TaskFindBegin();            (* 24-Jan-91 RSC  *)

    AnyDuplicateAssignments := FALSE;
    TaskRecordLength := TSIZE (ATask);
    LocalSMUPH := GetLocalSMUPH (f);
    Multiplier := FLOAT(SMUPH) / FLOAT(LocalSMUPH);

    MaxReadCount    := GetMaxReadCount();
    TotalTaskCount := 0;
    TasksReadCount := 0;
    BadAssignmentCount := 0;
    TaskBugCount := 0;

    IF (NOT StartSubfileInput(f,TaskType,Version)) THEN
        RETURN;
    END;

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
            RenumberTheTask, NIL);

    LevelOffset := 0;
    LastTaskAdded := NIL;               (* 6/1/89 EGK *)

    IF (RetrieveType = RetrievePart) THEN
        LastTaskAdded := GanttChart^.Methods^.GetCursorNode (GanttChart);
        IF (LastTaskAdded <> NIL) THEN
            LevelOffset := LastTaskAdded^.Methods^.IndentationLevel (LastTaskAdded);
        END;


            (* RSC 6/20/89  Account for existing tasks: *)

        TaskNode := TaskTree^.Methods^.GetFirst( TaskTree );
        WHILE (TaskNode <> NIL) DO
            INC( TotalTaskCount );
            TaskNode := TaskNode^.Methods^.NextPreOrder( TaskNode );
        END;


        IF (MakeSummaryTask) THEN               (* 6/1/89 EGK *)
            TaskNode := CreateTask();
            IF (TaskNode = NIL) THEN
                ErrorFlag := TRUE;
                RETURN;
            ELSE
                CurrentTask := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
                GetMessage (ModuleNumber+32, CurrentTask^.taskname);    (* "Summary of " *)
                ConcatLS (CurrentTask^.taskname, ProjectFileName);
                TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);
                AddTask (TaskNode, NIL, LastTaskAdded);
                LastTaskAdded := TaskNode;
                INC (LevelOffset);
                INC( TotalTaskCount );
            END;
        END;
        GlobalCursorNode := LastTaskAdded;
    END;

    CurrentTask := NIL;

        (* Prepare to display progress. *)
    GetMessage(ModuleNumber+25,s);
    TaskCount := VAL(CARDINAL,RecordQuantities[QTask]);
    IF (NOT CreateThermometer(Thermometer,0,0,s,TaskCount)) THEN
        Thermometer := AThermometer(NIL);
    END;


    LOOP
        IF (CheckIO(f) <> done) THEN
            FileComplaint(f);
            EXIT;
        END;
        IF (BreakRequested()) OR (ErrorFlag) THEN
            EXIT;
        END;
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN
            FileComplaint(f);
            EXIT;
        END;
        CASE Type OF
        | HeaderType            : 
            ReadRecordBody (f, Length, ADR(Header), SIZE(Header));

        | TaskType              :
            ReadRecordBody(f,Length,ADR(newtask),TaskRecordLength);  (* 28-Sep-89 LAA *)

            IF (CurrentTask <> NIL) THEN
                Compress(CurrentTask^.notes);
                SanitizeTask ( CurrentTask );  (* 25-Jan-91 RSC *)
                TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);
                CheckTaskValid( TaskNode );
            END;

            IF (TotalTaskCount > MaxReadCount) THEN
                GetMessage(ModuleNumber+36,s);     (* You have too many tasks *)
                GetMessage(ModuleNumber+37,Title); (* Too many tasks *)
                WarningBox( s, Title, OfferHelp );
                EXIT;
            END;

            WITH newtask DO
                notes := AText(NIL);
                summarizes := AText(NIL);
                Coding := AText(NIL);                (* 28-Sep-89 LAA *)
                (*   RenameIfAppropriate(taskname,IsATaskName);    *)
                IF (rollupstatus = NotRollup) THEN
                    DiscardText(summarizes);
                ELSE
                    rollupstatus := RollupNotLoaded;
                END;
                IF (RetrieveType = RetrievePart) THEN
                    INCL (TaskStatusSet, NeedsRecalculate);        (* 3/8/88 EGK *)
                END;
                desctasks := AnEdgePtr (NIL);
                antetasks := AnEdgePtr (NIL);

                Nextlink := AnExtHandle(NIL);           (* 10/20/88 EGK *)
                Prevlink := AnExtHandle(NIL);
                WorkSpace := NIL;

                Plan.Assignments := AnExtHandle (NIL);
                BaseLine.Assignments := AnExtHandle (NIL);
                EXCL(TaskFlags,DeferAlarms);        (* Enable alarm clock. *)
            END;

            AddIt;

        | OldNotesType          :
            IF (CurrentTask <> NIL) THEN
                ReadManyOldTextLines(f, Length, Type, CurrentTask^.notes);
            ELSE
                SkipRecordBody(f, Length);
            END;

        | OldSummarizesType     :
            IF (CurrentTask <> NIL) THEN
                ReadManyOldTextLines(f, Length, Type, CurrentTask^.summarizes);
                Compress(CurrentTask^.summarizes);
                UnSetState (Scheduled);
                CurrentTask^.rollupstatus := RollupNotLoaded;
            ELSE
                SkipRecordBody(f, Length);
            END;

        | OldCodingType         :
            IF (CurrentTask <> NIL) THEN
                ReadManyOldTextLines(f, Length, Type, CurrentTask^.Coding);
            ELSE
                SkipRecordBody(f, Length);
            END;

        | NotesType             :
            IF (CurrentTask <> NIL) THEN
                ReadManyTextLines(f, Length, Type, CurrentTask^.notes);
            ELSE
                SkipRecordBody(f, Length);
            END;

        | SummarizesType        :
            IF (CurrentTask <> NIL) THEN
                ReadManyTextLines(f, Length, Type, CurrentTask^.summarizes);
                Compress(CurrentTask^.summarizes);
                UnSetState (Scheduled);
                CurrentTask^.rollupstatus := RollupNotLoaded;
            ELSE
                SkipRecordBody(f, Length);
            END;

        | CodingType            :
            IF (CurrentTask <> NIL) THEN
                ReadManyTextLines(f, Length, Type, CurrentTask^.Coding);
            ELSE
                SkipRecordBody(f, Length);
            END;

        | PlanAssignmentsType   :
            IF (CurrentTask <> NIL) THEN
                    (* Because reading the assignments takes several locks,
                       we need to release the task first, the relock it after. *)
                TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);
                IF NOT ReadAssignmentArray (f, Length, AssignmentsHandle, BadAssignmentCount, DuplicateAssignments) THEN
                    ErrorFlag := TRUE;
                END;
                CurrentTask := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
                CurrentTask^.Plan.Assignments := AssignmentsHandle;
                AnyDuplicateAssignments := AnyDuplicateAssignments OR DuplicateAssignments;
            ELSE
                SkipRecordBody (f, Length);
            END;

        | BaseAssignmentsType   :
            IF (CurrentTask <> NIL) THEN
                    (* Because reading the assignments takes several locks,
                       we need to release the task first, the relock it after. *)
                TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);
                IF NOT ReadAssignmentArray (f, Length, AssignmentsHandle, BadAssignmentCount, DuplicateAssignments) THEN
                    ErrorFlag := TRUE;
                END;
                CurrentTask := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
                CurrentTask^.BaseLine.Assignments := AssignmentsHandle;
                AnyDuplicateAssignments := AnyDuplicateAssignments OR DuplicateAssignments;
            ELSE
                SkipRecordBody (f, Length);
            END;

        | PlanAssignmentsType+1,
          PlanAssignmentsType+2,
          BaseAssignmentsType+1,
          BaseAssignmentsType+2 :
            GetMessage (ModuleNumber+73, s);
            Error (s);
            SkipRecordBody (f, Length);

        | DateBlockPlan         :
            ConvertDateBlocks( FALSE );

        | DateBlockBase         :
            ConvertDateBlocks( TRUE );

        | 0FFH                  : 
            EXIT;

        ELSE
            SkipRecordBody(f,Length);
        END;
    END;

    INC( TotalTaskCount, TasksReadCount ); 
    

    IF CurrentTask <> NIL THEN
        Compress(CurrentTask^.notes);
        SanitizeTask ( CurrentTask );       (* 22-Aug-91 PFG *)

        (* 18-Jul-91 TGS If this is assignment driven, make it duration driven *)
        IF CurrentTask^.DurationMethod = AssignmentDriven THEN
            CurrentTask^.DurationMethod := DurationDriven;
            UnSetState (Scheduled);
        END;
        TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);
        CheckTaskValid( TaskNode );
    END;

    Loaded := NOT ErrorFlag;
    IF (BadAssignmentCount > 0) THEN
        GetMessage (ModuleNumber+71,s);         (* "While loading assignments, " *)
        CtoS (BadAssignmentCount, Title);
        ConcatLS (s, Title);
        ConcatMessage (s, ModuleNumber+72);     (* "bad assignments were found" *)
        Error (s);
    END;

    IF (TaskBugCount > 0) THEN
        GetMessage (ModuleNumber+92,s);                           (* 9-Oct-89 MWP *)
        (* "While loading tasks, " *)
        CtoS (TaskBugCount, Title);
        ConcatLS (s, Title);
        ConcatMessage ( s, ModuleNumber + 93 );                   (* 9-Oct-89 MWP *)
        (* " data errors were found and corrected." *)
        Error (s);
    END;

    IF (AnyDuplicateAssignments) THEN
        ErrorPhrase( ModuleNumber );
    END;

    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

END GetTasks;
















PROCEDURE AttachEdge( VAR EdgeFromFile : AnEdge ) : BOOLEAN;
TYPE
    AnAddressTrick = RECORD
        CASE BOOLEAN OF
        | TRUE :  P : ATreeNode;
        | FALSE:  C : RECORD
                        A  : INTEGER;
                        B  : CARDINAL;
                      END;
        END;
    END;
VAR
    Task1, Task2            : ATreeNode;
    L                       : LONGINT;
    TaskPtr1, TaskPtr2      : ATaskPtr;
    Task1No  , Task2No      : INTEGER;
    EdgePtr                 : AnEdgePtr;
    i                       : CARDINAL;
    k                       : INTEGER;
    AddressTrick1,
    AddressTrick2           : AnAddressTrick;
    Status1, Status2        : ATaskStatusSet;
    s  : ARRAY [0..199] OF CHAR;


    PROCEDURE CannotFind(number : INTEGER);
    VAR
        s  : ARRAY [0..79] OF CHAR;
        s2 : ARRAY [0..5]  OF CHAR;
    BEGIN
        GetMessage(ModuleNumber+1,s);   (*  "While loading joins, I can't find "  *)
        CtoS (CARDINAL(number), s2);
        ConcatLS(s,s2);
        ConcatS(s,'.');
        Message(s);
    END CannotFind;

BEGIN

    AddressTrick1.P := EdgeFromFile.headtask;
    Task1No         := AddressTrick1.C.A;
    Task1 := FindTaskByNumber(Task1No);

    AddressTrick2.P := EdgeFromFile.tailtask;
    Task2No         := AddressTrick2.C.A;
    Task2 := FindTaskByNumber(Task2No);

    IF (Task1 = NIL) THEN
        CannotFind(Task1No);
    ELSIF (Task2 = NIL) THEN
        CannotFind(Task2No);
    ELSE
        TaskPtr1 := Task1^.Methods^.LockFlexStorDataObject (Task1);
        TaskPtr2 := Task2^.Methods^.LockFlexStorDataObject (Task2);

        EdgePtr := FindEdgeInTask(AnEdgesTask(TaskPtr1),Task2);
        IF (EdgePtr = NIL) THEN
            EdgePtr := FindEdgeInTask(AnEdgesTask(TaskPtr2),Task1);
        END;
        IF (EdgePtr <> NIL) THEN
            GetMessage (ModuleNumber+73, s);
            Error (s);
        ELSE
            EdgePtr := CreateEdgeDammit (Task1,Task2);
            IF (EdgePtr <> NIL) THEN
                CopyEdgeContents(EdgeFromFile,EdgePtr^);
                AddEdgeWithTasks (EdgePtr, AnEdgesTask(TaskPtr1), AnEdgesTask(TaskPtr2), FALSE);
            ELSE
                (* If we failed for some reason other than that the
                   dependency already exists (we may be combining),
                   then it is serious. *)
                 TellOfNoMemory( AddingEdges );
                 RETURN FALSE;
            END;
        END;
             (* Recompute the net effect of partial dependencies.  *)
        k := NoDuration;
             (*  Partial join from. *)
        WITH EdgePtr^.FromOffset DO
            IF (Start) THEN
                DEC(k,TaskPtr1^.duration);
            END;

                (* Perhaps fix up the duration.  This is a 4.5 invention
                   only, flagged by Dur being MAXCARDINAL.
                   AddressTrick1 has the number of HOURS
                   Z has the remainder of Tics DIV SMUPH * old SMU.

                   12-Nov-90 RSC
                   (* 29-Apr-91 RSC Updated the calcs, as the old ones
                                    eroniously scaled the numbers to the
                                    old calendar, not the new one.
                   *)
                *)
            IF (Dur  = MAXCARDINAL) THEN
                L := (VAL(LONGINT,AddressTrick1.C.B) * VAL(LONGINT,SMUPH)) +
                     VAL(LONGINT,(EdgePtr^.Z + (SMU DIV 2)) DIV SMU);
                IF (L < 65536L) THEN
                    Dur := VAL(CARDINAL,L);
                END;
            END;

            IF (Plus) THEN
                INC(k,Dur);
            ELSE
                DEC(k,Dur);
            END;
        END;
            (*  Partial join to. *)
        WITH EdgePtr^.ToOffset DO
            IF (NOT Start) THEN
                DEC(k,TaskPtr2^.duration);
            END;
        END;
        EdgePtr^.Delta := k;            (* Jason Bourne *)
        Task1^.Methods^.UnlockFlexStorDataObject (Task1);
        Task2^.Methods^.UnlockFlexStorDataObject (Task2);
    END;

    RETURN TRUE;

END AttachEdge;



    (* 8-Aug-90 RSC Removed old edge support (rec type 8) *)

PROCEDURE GetEdges(VAR f : File);
VAR
    RecordLength            : CARDINAL;
    Version, count          : CARDINAL;
    Length                  : CARDINAL;
    Type                    : CARDINAL;
    Thermometer             : AThermometer;
    EdgeCount               : CARDINAL;
    EdgeFromFile            : AnEdge;
    S                       : ARRAY [0..51] OF CHAR;

BEGIN
    IF (NOT StartSubfileInput(f,EdgeType,Version)) THEN
        FileComplaint(f);
        RETURN;
    END;

        (* Prepare to display progress. *)
    GetMessage(ModuleNumber+27, S);
    EdgeCount := VAL(CARDINAL,RecordQuantities[QEdge]);
    IF (NOT CreateThermometer(Thermometer,0,0,S,EdgeCount)) THEN
        Thermometer := AThermometer(NIL);
    END;

    count := 0;
    LOOP
        IF (BreakRequested()) OR (ErrorFlag) THEN
            RETURN;
        END;
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN
            FileComplaint(f);
            RETURN;
        END;
        INC(count);

        CASE Type OF
        | 1    :
            RecordLength := TSIZE(AnEdge) - 2 * TSIZE(AnEdgePtr);
            ReadRecordBody(f,Length,ADR(EdgeFromFile),RecordLength);
            IF (NOT AttachEdge(EdgeFromFile)) THEN
                EXIT;
            END;
            IF ((count MOD 8) = 0) THEN
                UpdateThermometer(Thermometer,count);
            END;

        | 0FFH :
            EXIT;  (* End of subfile *)

        ELSE
            SkipRecordBody(f,Length);
        END;

    END;


    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

END GetEdges;








PROCEDURE GetBugs(VAR f:File);
VAR
    Length, Version, Type      : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput(f,BugsType,Version)) THEN
        (* 15-Jul-91 PFG   If the subfile doesn't exist, set the defaults. *)
        BugTaskA := NIL;
        BugTaskB := NIL;
        BugDayA := AsOfDate;
        BugDayB := AsOfDate;
        CursorTask := TaskTree^.Methods^.GetFirstVisible(TaskTree);
        CursorDay := AsOfDate;
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
        | 1   : ReadTaskNumber(f,Length,BugTaskA);
        | 2   : ReadDate(f,Length,BugDayA);
        | 3   : ReadTaskNumber(f,Length,BugTaskB);
        | 4   : ReadDate(f,Length,BugDayB);
        | 100 : ReadTaskNumber(f,Length,CursorTask);
        | 101 : ReadDate(f,Length,CursorDay);
        | 0FFH: EXIT;
        ELSE    SkipRecordBody(f,Length);
        END;
    END;
END GetBugs;







    (* All this stuff just to adjust durations to changes in
       calendar precisions. *)





PROCEDURE RecomputeTaskDuration (VAR Node    : ATreeNode;
                                     Context : ADDRESS   );
VAR
    Edge : AnEdgePtr;
    Task : ATaskPtr;
BEGIN
    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    ToNewDuration(Task^.duration, Task^.scale, TRUE);
    Edge := Task^.desctasks;
    WHILE (Edge <> NIL) DO
        ToNewDuration(Edge^.FromOffset.Dur, Edge^.FromOffset.Scale, TRUE);
        (*  To offset is always 0 in 2.0
        ToNewDuration(Edge^.ToOffset.Dur, Edge^.ToOffset.Scale, TRUE);
        *)
        Edge := Edge^.headlink;
    END;
    Node^.Methods^.UnlockFlexStorDataObject (Node);
END RecomputeTaskDuration;




PROCEDURE RecomputeLayoutScale  (VAR Node        : ATreeNode;
                                     Context     : ADDRESS   );
VAR
    LayoutPtr       : AChartFormatPtr;

BEGIN
    LayoutPtr := Node^.Methods^.GetDataObject (Node);
    WITH LayoutPtr^ DO
        ToNewScale (scale, scaleunit, TRUE);
    END;
END RecomputeLayoutScale;





        (* If we have Combined in a new calendar, then
           fix up any differences in calendar precision. *)

PROCEDURE CalendarUpdate();
BEGIN
    AfterCalendarChange();
    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild,
            9999, RecomputeTaskDuration, NIL);
    LayoutTree^.Methods^.TraverseTree (LayoutTree, ParentBeforeChild,
            9999, RecomputeLayoutScale, NIL);
    RecomputeLayoutScale (DefaultChartFormat, NIL);

    IF (RetrieveType = RetrievePart) THEN
        ToNewDate (AsOfDate);
        SetAsOfDate;
    END;

END CalendarUpdate;



PROCEDURE GetTLGSRecords(VAR F              : File);

VAR
    Version                 : CARDINAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;
    TitleBlock              : ATLGSTitleBlockPtr;
    GanttRecord             : ATLGSGanttRecordPtr;
    PertRecord              : ATLGSPertRecordPtr;
    TreeRecord              : ATLGSTreeRecordPtr;
    ColorAssignment         : ATLGSColorAssignmentPtr;
    PageRecord              : ATLGSPageRecordPtr;


BEGIN                       (* GetTLGSRecords *)

    IF (NOT StartSubfileInput(F,TLGSDeviceType,Version)) THEN
        IF (CheckIO(F) <> done) THEN                              (* 31-May-89 LAA *)
            FileComplaint(F);
        END;
        RETURN;
    END;

    DisplayMessage( ModuleNumber + 86 );  (* "Reading graphics information..." *)

    LOOP
        ReadRecordPreface(F,Type,Length);
        IF (CheckIO(F) <> done) THEN EXIT; END;
        CASE Type OF
            (*  Gantt chart records  *)

        | 10   :  
            TitleBlock := LockTLGSTitleBlock(TLGSGanttChart);   (* 26-May-89 LAA *)
            IF (TitleBlock <> NIL) THEN
                ReadRecordBody(F, Length, TitleBlock, SIZE(TitleBlock^));
            END;
            UnlockTLGSTitleBlock(TLGSGanttChart);               (* 26-May-89 LAA *)

        | 11   :
            GanttRecord := TLGSGanttRecord(0.0);
            IF (GanttRecord <> NIL) THEN
                ReadRecordBody(F, Length, GanttRecord, SIZE(GanttRecord^));
            END;

            (*  Pert chart records  *)

        | 20   :
            TitleBlock := LockTLGSTitleBlock(TLGSPertChart);     (* 26-May-89 LAA *)
            IF (TitleBlock <> NIL) THEN
                ReadRecordBody(F, Length, TitleBlock, SIZE(TitleBlock^));
            END;
            UnlockTLGSTitleBlock(TLGSPertChart);                 (* 26-May-89 LAA *)

        | 21   :
            PertRecord := TLGSPertRecord();
            IF (PertRecord <> NIL) THEN
                ReadRecordBody(F, Length, PertRecord, SIZE(PertRecord^));
            END;

            (*  Tree chart records  *)

        | 30   :
            TitleBlock := LockTLGSTitleBlock(TLGSTreeChart);    (* 26-May-89 LAA *)
            IF (TitleBlock <> NIL) THEN
                ReadRecordBody(F, Length, TitleBlock, SIZE(TitleBlock^));
            END;
            UnlockTLGSTitleBlock(TLGSTreeChart);                (* 26-May-89 LAA *)

        | 31   :
            TreeRecord := TLGSTreeRecord();
            IF (TreeRecord <> NIL) THEN
                ReadRecordBody(F, Length, TreeRecord, SIZE(TreeRecord^));
            END;

            (*  Page record  *)

        | 40   :
            PageRecord := TLGSPageRecord();
            IF (PageRecord <> NIL) THEN
                ReadRecordBody(F, Length, PageRecord, SIZE(PageRecord^));
            END;

        | 0FFH :
            EXIT;

        ELSE
            SkipRecordBody(F,Length);
        END;
    END;

END GetTLGSRecords;





PROCEDURE DuplicatesOK( VAR DuplicateName : ARRAY OF CHAR ) : BOOLEAN;
BEGIN

    RETURN (GetDuplicateAction( DuplicateName ) = Override);

END DuplicatesOK;






    (* These constants control the order and choice of subfiles
       read.  Their order is important so as to assure that
       data is available before it is referenced by another
       subfile.

          15-Aug-90 RSC reordered these so they appear in the order that
                        they are saved by SAVECOMMON/TLXTL5.
    *)
CONST
    SIG   =  0;
    HLD   =  1;
    CAL   =  2;     (* <-- switched the order of CAL and ENV *)
    ENV   =  3;     (* <-- EGK 7/30/91 *)
    FTR   =  4;
    MMO   =  5;
    LAY   =  6;
    PLT   =  7;
    PRJ   =  8;
    RES   =  9;
    TSK   = 10;
    EDG   = 11;
    PRT   = 12;
    BUG   = 13;
    TLGS  = 14;
    CNAM  = 15;
    ALIEN = 16;

TYPE
    ASetOfSubfileNumbers = SET OF [0..31];          (* 26-Oct-90 PFG *)


PROCEDURE GetProjectFile(VAR Directory    : ARRAY OF CHAR;
                         VAR FileName     : ARRAY OF CHAR;
                             RetrieveSet  : ASetOfSubfileNumbers;
                             OptionalFile : BOOLEAN
                         ) : BOOLEAN;
VAR
    i,j         : CARDINAL;
    Version     : CARDINAL;
    f           : File;
    FileType    : AFileType;
    s           : ARRAY [0..255] OF CHAR;
    Description : ARRAY [0..13] OF CHAR;
    C           : CHAR;
    ok          : BOOLEAN;

BEGIN
    SetLengthOf(Description,0);

        (* 4-Jun-91 RSC Skip error message if optional file.
        *)
    IF (OptionalFile) AND
       (NOT PathLookupStart(Directory,FileName,s,Description)) THEN
        RETURN FALSE;
    END;

    IF (NOT RequestFileOpenReadOnly(Directory,FileName,Description,f) ) THEN
        RETURN FALSE;
    END;


    ExtractFileNameParts( FileName, s,s, ProjectFileName, s );

    PrepareForIO(f);
    ScheduleSaved := TRUE;       (* Until we have successfully read in the
                                    entire file, disk copy is better. *)

    IF (NOT StartFileInput(f)) THEN
        FileComplaint(f);
        Close(f);
        RETURN FALSE;
    END;

    IF (CheckIO(f) <> done) THEN
        FileComplaint(f);
        Close(f);
        RETURN FALSE;
    END;

    GetCounts(f);               (* How many things are there? *)

    ok := TRUE;
    i := 0;
    LOOP

        ErrorFlag := (ErrorFlag            OR
                      BreakRequested());

        IF (NOT ok) OR (ErrorFlag) THEN
            EXIT;
        END;

        IF (i > 15) THEN
            EXIT;
        ELSIF (i IN RetrieveSet) THEN
            CASE i OF
            | SIG:
                ok := GetSignature(f,j);  (* 26-Oct-89 RSC *)
                IF (ok) THEN
                    ok := (j = 450) OR (j = 500); (* 2-Apr-91 TGS *)
                    IF (NOT ok) THEN
                        SignatureError(500,j);
                    END;
                END;

            | HLD:
                DisplayMessage( ModuleNumber + 87 );  (* "Reading report settings..." *)
                GetHeldItems(f);

            | ENV:
                GetTheEnvironment(f);

            | CAL:
                DisplayMessage( ModuleNumber + 85 );  (* "Reading calendar information..." *)
                BeforeCalendarChange();   (* Save a copy *)
                GetCalendar(f);           (* Get from file *)
                CalendarUpdate();         (* Do the conversions *)

            | PRJ:
                GetProjectDetails(f);

            | RES:
                IF (NOT GetResources(f,GetDuplicateAction,
                                     VAL(CARDINAL,RecordQuantities[QResource]))
                    ) THEN
                    IF (CheckIO(f) = done) THEN
                        TellOfNoMemory( AddingResources );
                    ELSE
                        FileComplaint(f);
                    END;
                END;

            | TSK:
                GetTasks(f);

            | EDG:
                GetEdges(f);

            | PRT:
                GetPrinterSettings(f);

            | BUG:
                GetBugs(f);

            | FTR:
                DisplayMessage( ModuleNumber + 90 );  (* "Reading filters..." *)
                GetFiltersInfo(f,DuplicatesOK,(RetrieveType=RetrieveAll), FALSE);

            | MMO:
                DisplayMessage( ModuleNumber + 88 );  (* "Reading journal notes..." *)
                GetMemosInfo(f);                             (* 01/07/87 LAA *)

            | LAY:
                DisplayMessage( ModuleNumber + 89 );  (* "Reading layouts..." *)
                GetLayoutsInfo(f,DuplicatesOK,(RetrieveType=RetrieveAll), FALSE);
                GetNetLayoutsInfo(f, DuplicatesOK,(RetrieveType=RetrieveAll), FALSE);         (* 17-Nov-87 LAA *)

            | PLT:
                GetPalettesInfo(f, TLGSGanttChart, DuplicatesOK,   (* 06-Jul-89 LAA *)
                                (RetrieveType=RetrieveAll));
                GetPalettesInfo(f, TLGSPertChart, DuplicatesOK,
                                (RetrieveType=RetrieveAll));
                GetPalettesInfo(f, TLGSTreeChart, DuplicatesOK,
                                (RetrieveType=RetrieveAll));

            | TLGS:
                GetTLGSRecords(f);

            | CNAM:
                GetColumnNames(f);        (* 26-Oct-90 PFG *)

            | ALIEN:  (* RSC 1-Sep-89 *)
                FileType := ScheduleFile;
                TraverseSubfiles( f, DigestSubfile, ADR( FileType ) );

            ELSE
                EXIT;
            END;
        END;
        IF (ok) THEN
            ok := (CheckIO(f) = done);
        END;
        INC(i);
    END;

    TaskFindEnd();  (* RSC 22-Jun-89 *)

    ClearBreak;    (* Clear any Break request. *)

    Close(f);

    ErrorFlag := (ErrorFlag OR (NOT ok));   (* 27-Oct-89 RSC *)

    RETURN (NOT ErrorFlag);                 (* 27-Oct-89 RSC *)

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
                       VAR FileName     : ARRAY OF CHAR;
                           OptionalFile : BOOLEAN
                       ) : BOOLEAN;

VAR
    RetrieveSet        : ASetOfSubfileNumbers;
    Result             : BOOLEAN;

BEGIN

    RetrieveSet := ASetOfSubfileNumbers{  HLD,ENV,PRJ,CAL,SIG,ALIEN,
                                          RES,TSK,EDG,BUG,PRT,FTR,MMO,
                                          LAY,PLT,TLGS,CNAM  };   (* 30-May-89 LAA *)

    UnSetState(Sorted);
    UnSetState(Filtered);
    SaveTaskDates := TRUE;

    ResetFilters;                           (* 3/1/88 EGK *)
    CurrentChartFormat := NIL;
    CurrentNetLayout := NIL;
    EnlargedNetLayout := NIL;

    Result := GetProjectFile(Directory,FileName,RetrieveSet, OptionalFile);
    ScheduleSaved := TRUE;      (* 2/29/88 EGK *)
    LayoutChanged();            (* 5-Mar-91 TGS *)

    IF (NOT NewVaryingAssgnFormatFound) THEN                   (* 19-Mar-92 *)
            (*  Force a manual recalc if we've read an old format file! *)

        WITH CalculationState[Scheduling] DO
            DataIsValid := FALSE;
            Abandoned := FALSE;
            When := ManualCalc;
        END;
    END;

    RETURN Result;

END LoadOneFile;







PROCEDURE CombineOneFile(VAR Directory    : ARRAY OF CHAR;
                         VAR FileName     : ARRAY OF CHAR;
                             OptionalFile : BOOLEAN
                         ) : BOOLEAN;
VAR
    RetrieveSet          : ASetOfSubfileNumbers;
    Selection            : CARDINAL;
    s                    : ARRAY [0..200] OF CHAR;
    Prefix               : ARRAY [0..80] OF CHAR;
    Choices              : ARRAY [0..160] OF CHAR;
    Title                : ARRAY [0..30] OF CHAR;
    ok                   : BOOLEAN;
    TasksInMemory,
    RsrcsInMemory        : BOOLEAN;

    PROCEDURE SelectPortion(VAR RetrieveSet : ASetOfSubfileNumbers);
    VAR
        Choice  : CARDINAL;
        Title   : ARRAY [0..40] OF CHAR;
        S       : ARRAY [0..80] OF CHAR;
    BEGIN
        RetrieveSet := ASetOfSubfileNumbers{};
        GetMessage(ModuleNumber+4,S);           (* "What do you wish to combine?" *)
        GetMessage(ModuleNumber+75, Title);     (* "Combine options" *)
        SetLengthOf (Prefix, 0);
        GetMessage(ModuleNumber+5,Choices);     (*  "Tasks,Resources/Costs Only,Calendar Only,
                                                     Filters Only,Memos Only,Layouts Only,
                                                     Palettes Only, Column Names Only  *)
        Choice := 1;
        IF (MultipleChoiceBox (S, Title, NoHelp, Prefix, Choices, Choice)) THEN
            CASE Choice OF
            | 1:
                RetrieveSet := ASetOfSubfileNumbers{SIG,RES,TSK,EDG};
                GetMessage (ModuleNumber+76, S);    (* Create a summary? *)
                MakeSummaryTask := NoYes(S);
            | 2:  RetrieveSet := ASetOfSubfileNumbers{SIG,RES};
            | 3:  RetrieveSet := ASetOfSubfileNumbers{SIG,CAL};
            | 4:  RetrieveSet := ASetOfSubfileNumbers{SIG,FTR};
            | 5:  RetrieveSet := ASetOfSubfileNumbers{SIG,MMO};
            | 6:  RetrieveSet := ASetOfSubfileNumbers{SIG,LAY};
            | 7:  RetrieveSet := ASetOfSubfileNumbers{SIG,PLT};   (* 06-Jul-89 LAA *)
            | 8:  RetrieveSet := ASetOfSubfileNumbers{SIG,CNAM};  (* 31-Oct-90 PFG *)
            ELSE;
            END;
        END;
    END SelectPortion;

BEGIN
        SelectPortion(RetrieveSet);

        IF (CAL IN RetrieveSet) THEN
            TasksInMemory := (TaskTree^.Methods^.GetFirst (TaskTree) <> NIL);    (* There are existing tasks left over. *)
            RsrcsInMemory := (ResourceTree^.Methods^.GetFirst (ResourceTree) <> NIL);

            IF (RsrcsInMemory OR TasksInMemory) THEN
                GetMessage(ModuleNumber+38,s    ); (* "There is already a schedule in memory."  *)
                GetMessage(ModuleNumber+39,Title); (* "Schedule in memory"  *)
                WarningBox( s, Title, OfferHelp );
                RETURN FALSE;
            END;
        END;

        IF (TSK IN RetrieveSet) THEN
            GetMessage (ModuleNumber+33, s);            (* "Which shall I preserve?" *)
            GetMessage (ModuleNumber+34, Choices);      (* "Durations,End Dates" *)
            GetMessage (ModuleNumber+35, Title);        (* "Combine options" *)
            SetLengthOf (Prefix, 0);
            Selection := 1;
            IF (NOT MultipleChoiceBox (s, Title, NoHelp, Prefix, Choices, Selection)) THEN
                RETURN FALSE;
            END;
            SaveTaskDates := (Selection = 2);
        END;

        ok := GetProjectFile(Directory,FileName,RetrieveSet, OptionalFile);

        IF ((RetrieveSet * ASetOfSubfileNumbers{FTR,MMO,LAY,PLT,CNAM}) 
                        = ASetOfSubfileNumbers{}) THEN          (* 06-Jul-89 LAA *)
            UnSetState( Scheduled );
        END;

        IF (CAL IN RetrieveSet) OR
           (LAY IN RetrieveSet) THEN (* 12-Mar-91 TGS *)
            LayoutChanged();
        END;

        RETURN ok;

END CombineOneFile;








PROCEDURE ReadInFile();
VAR
    Device       : ARRAY [0..80] OF CHAR;
    Directory    : ARRAY [0..70] OF CHAR;
    Extension    : ARRAY [0..3]  OF CHAR;
    FileName     : ARRAY [0..15] OF CHAR;
    OptionalFile,
    ok           : BOOLEAN;
BEGIN
    Directory    := "Program Copyright (c) 1989 Symantec Corporation.";
    Directory[0] := 0C;
    Message(Directory);   (* Erase the "Now loading" message. *)

    IF (P = NIL) THEN
        FatalError(); (* Improper call - not via TLGETIT (Old TLWHAT file?) *)
    END;

    OptionalFile := (P^[1] = "@");
    IF (OptionalFile) THEN
        Remove(P^,1,1);
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
        ok := LoadOneFile(    Device, FileName, OptionalFile );
    | RetrievePart:
        ok := CombineOneFile( Device, FileName, OptionalFile );
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



(*<OS2
PROCEDURE TLITL4Bind ();
OS2>*)

BEGIN
    NoteMessage[0]   := 0C;             (* No edge message read yet *)
    GlobalCursorNode := ATreeNode(NIL); (* No cursor node set yet *)
    P := OverlayContext();

    IF (NOT HeapAvailable()) THEN
        TellOfNoMemory( StartingUp );
        P^[1] := "0";                   (* This is the error signal *)
        RETURN;
    END;


    ErrorFlag := FALSE;
    DuplicateAction := DontKnow;

    ReadInFile();

    RenumberEverything();

    Node := TaskTree^.Methods^.GetFirst(TaskTree);
    GanttChart^.Methods^.SetFirst(GanttChart, Node);
    IF (GlobalCursorNode <> NIL) THEN (* Summary of combined tasks? *)
        CursorTask := GlobalCursorNode;
    END;
    GanttChart^.Methods^.SetCursorNode(GanttChart, CursorTask);

    SetLengthOf(NoteMessage,0);
    Message(NoteMessage);

    IF (ErrorFlag) THEN                                 (* 3/3/88 EGK *)
        P^[1] := "0";
    ELSE
        P^[1] := "1";
    END;

(*<OS2
END TLITL4Bind;
OS2>*)

END TLITL5.

