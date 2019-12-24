    (*V1=OS2 OS2 code changes.    *)
    (*V2=DOS Regular DOS TL code. *)

(*<DOS*)
MODULE TLITL4;
(*DOS>*)


(*<OS2
IMPLEMENTATION MODULE TLITL4;
OS2>*)


    (*------------------------------------------------------------------------

                        Import Time Line 4.0 files.


    -------------------------------------------------------------------------*)


(*  =========================================================================
    Last Edit : August 16, 1991 4:08PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description:


    MODIFICATION HISTORY:

            RSC  6-Feb-89  First version, from TLiTL3.Mod
            EGK 28-Feb-89  Disable reading of resource node attributes.
          20-Mar-89 AJL    Use CopyEdgeContents.
                           Changed the record type number of an edge record
                           since the format has changed.  Was 8, is now 1.
          20-Apr-89 AJL    Continue to import the type 8 edge records.
          27-Apr-89 EGK    Changed ConvertDateBlocks to check for bad dates
                           before computing the task duration (to help those
                           bozos who like to save schedules with loops).
          28-Apr-89 EGK    In GetResources, took out the Burp that would
                           happen whenever you ignored a duplicate resource.
           5-Apr-89 EGK    Changed GetTasks to handle V3 tasks, which had
                           WBS, OBS, and AUX stored in the task record.
          21-May-89 LAa    Added code to read TLGS records in from the
                           schedule file.
          23-May-89 LAA    Oops.  Record numbers have to be less than 255.
          26-May-89 LAA    The TitleBlock and Palettes are now store in
                           FlexStor, rather than on the heap.
          29-May-89 LAA    Loaded the ScheduleStartDate from the file.
          30-May-89 LAA    Fixed a bug which caused the TLGS records to not
                           be loaded from the schedule file.
          31-May-89 LAA    If the subfile containing the TLG/S records does
                           not exist, an error message is put up.  That's not
                           right, so I fixed it.
           1-Jun-89 EGK    Combine now asks whether or not to create a
                           summary task, and inserts the combined tasks
                           after the cursor task.
           6-Jun-89 AJL    Put filters into FlexStor.
          14-Jun-89 LAA    Removed the code which loaded Palettes, as that's
                           now done by LoadCommon.
          16-Jun-89 LAA    Finished up adding the scrolling list of Palettes.
          19-Jun-89 RSC    Added messages to the reading of schedules to make
                           it clearer what is going on.
          20-Jun-89 RSC    Check Registry for # of tasks allowed.
          22-Jun-89 RSC    Optimise use of TaskFind by increasing the scope
                           of its Begin/End.
          25-Jun-89 WKH    Get UserName from Registry instead of Schedule
          06-Jul-89 WKH    Use ProductName from Registry instead of locally.
          06-Jul-89 LAA    Reused the PLT retrieve type, which used to be for
                           plotter (i.e. TLG) info in order to have a separate
                           way of getting Palettes.
           7-Jul-89 EGK    Changed GetTasks to put the cursor on the first
                           task combined if no top-level summary task is to
                           be created.
          27-Jul-89 KKC    Set Extras to NIL in GetResources.
          01-Aug-89 WKH    Made this module smaller by extracting all code
                           related to renumbering sequence numbers into the
                           module Renumber.  This module was too big to
                           compile!!!
          09-Aug-89 KKC    Add copyright message.
          10-Aug-89 WKH    Initial OS/2 edits
          14-Aug-89 WKH/
                    KKC    Added call to RecomputeTable at end of ReadInFile.
          18-Aug-89 KKC    Moved call to RecomputeTable in loadcommon.mod
          21-Aug-89 RSC    Added flexstor check to make sure there is room
                           to add to the model.
          22-Aug-89 KKC    After reading in the new schedule file, if there
                           is a left over calc error from the previous schedule
                           then recompute the schedule.
           1-Sep-89 RSC    Added call to "WriteAllForeignSubfiles"
          21-Sep-89 RSC    Reduced the number of symbols.
          28-Sep-89 LAA    Removed ability to read in Version 3.0 task
                           records.  Removed the FixTaskBugs procedure, which
                           was put in to fix a Version 3.0 problem.
          28-Sep-89 RSC    1) Added "RegCapacity" as an alternative to
                              "RegSupport", because RegSupport is too large
                              for us.
                           2) Removed KKC's change of 22-Aug-89, as I made
                              a simularly-intentioned fix in SaveCommon.
                              Ken's fix had the effect that if the schedule
                              in memory when you went to load this schedule
                              had a calc error, the new schedule was
                              recomputed.
           5-Oct-89 EGK    Fixed a bug in ReadAssignmentArray which would fail
                           to resolve an assignment record's resource pointer
                           if a bad element was found in the middle of the
                           array.
         9-Oct-89 MWP   Removed text literals.
        26-Oct-89 RSC   Updated GetSignature processing.  Bug # 1638.
        27-Oct-89 RSC   Made the SIGnature the first thing read from the
                        file, so that if the signature is bad, we have not
                        read calendar information and so on.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        16-Aug-90 RSC   Tinkered, fixing minor problems, trying to get the
                        program to load schedules.  Copy the ID from the
                        V4 resource to the V45 resource.
        20-Aug-90 RSC   Convert big time formats from the old style.
        12-Sep-90 RSC   Fixed for new Allocs.Def
         2-Oct-90 RSC   Added SupposedToStart translation.
        31-Oct-90 PFG   Clear out existing column names when a new 
                        schedule is loaded by calling ClearColumnNames.
        21-Nov-90 AJL   Initialize Planner values for compatability.
        10-Jan-91 AJL   Read old format text lines.
        21-Jan-91 RSC - Remove Fiscal Calendar.  Lower number of task locks.
        24-Jan-91 RSC - Zapload texts.  Alter calls to TaskFind for new
                        calling sequence.
        13-Feb-91 RSC   Change the calls to registry.
        5-Mar-91 TGS    Import LayoutChanged and call it when retrieving a
                        schedule, so we reset the Gantt layout properly.
         7-May-91 RSC   Allow negative slack in Sanitize.  Also, check for
                        any duplicate assignments.
        27-Jun-91 AJL   Because a fiscal year may require a change to the
                        date format, we need to cancel it and warn the user
                        to restore it. 
         8-Aug-91 PFG   Some new fields had been added to RecalcOptions, but
                        not initialized here.
       14-Aug-91 EGK    Don't mess with the task duration when reading the
                        baseline date block.
       16-Aug-91 PFG    The CodingField columns moved in version 5.  Added a
                        new parameter to GetFiltersInfo, GetLayoutsInfo and 
                        GetNetLayoutsInfo so that any filters or layouts 
                        which refer to changed columns get adjusted.
       17-Sep-91 AJL    If there is evidence that the schedule did not
                        compute ok, warn that it may not import right either.
                        Bug 5102.
        27-Jan-92 TGS   Fix TLXAFORM held item, if any, updating the ColumnID
                        numbers contained therein. Calls new proc in
                        XArTable. Bug 5391.
    =========================================================================
*)


FROM Allocs                 IMPORT ATask, ATaskPtr, ATaskName, ATaskStatus,
                                   ADateBlock, ABigDateBlock, AFixType,
                                   TskNmLen, ARollupStatus,
                                   ATaskFlag, ATaskFlagSet, AStartStatus,
                                   ATaskStatusSet, AddTask,
                                   CreateTask, CopyTask, TaskTree;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate,
    (* PROC *)                  SetAsOfDate;

FROM BigTimeU               IMPORT
    (* TYPE *)                      ABigTime,
    (* VAR  *)                      MINBIGTIME;

FROM Chart                  IMPORT  BugTaskA, BugDayA, BugTaskB, BugDayB,
                                    CursorTask, CursorDay, GanttChart;

FROM ChartControl           IMPORT  UnSetState, AChartState;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR  *)                  LayoutTree, CurrentChartFormat,
                                DefaultChartFormat,
    (* PROC *)                  CreateLayout, SortLayouts,
                                LayoutChanged;

FROM Dialog                 IMPORT Message, Error, FatalError, Burp,
                                   MultipleChoiceBox, ADialogOption,
                                   WarningBox, NotYetImplemented,
                                   ErrorPhrase;

FROM Directory              IMPORT
        (* CONST *)             MaximumPathNameLength,
        (* PROCS *)             ExtractFileNameParts;

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

FROM FileOpen               IMPORT  RequestFileOpenReadOnly;

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

FROM IV4Resources           IMPORT
    (* PROC *)                  GetResources;

FROM Kbio                   IMPORT avidmode,
                                   maxrow, maxcol,
                                   GetAnyCode, BreakRequested, ClearBreak,
                                   PutString;

FROM LoadCommon             IMPORT  ErrorFlag,
                                    SkipRecordBody, GetLayoutsInfo,
                                    GetCalendar,
                                    GetTheEnvironment, GetSignature,
                                    SignatureError, ReadDate,
                                    GetFiltersInfo,
                                    ReadTaskNumber, GetHeldItems,
                                    GetMemosInfo, GetNetLayoutsInfo,
                                    GetPalettesInfo, ClearColumnNames,
                                    ReadManyOldTextLines;

FROM LStrings               IMPORT SetString, ConcatLS, ConcatS, CtoS,
                                   SubStr, LStringToTString, TStringToLString,
                                   Search, Insert, Remove, Copy, SetLengthOf,
                                   StoC, Fill, Upshift, TrimRear, Procustes;

FROM Menus                  IMPORT NoYes;

FROM MsgFile                IMPORT  GetMessage, DisplayMessage, ConcatMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NetLayoutTree, CurrentNetLayout,
                                EnlargedNetLayout;

FROM OBigTimeU              IMPORT
    (* PROC *)                  BigTimeToTime;

FROM Overlays               IMPORT
        (* PROCS *)                 OverlayContext, CallOverlay;

FROM Planner                IMPORT
    (* VAR *)                   ScheduleStartDate, ScheduleEndDate, HonorDaysOff,
                                Levelling, KeepEffortContiguous,
                                MoveFutureTasks, TimeConstrained, RecalcOptions,
    (* TYPE  *)                 ARollupWeighting;

FROM PrintStatic            IMPORT  PrintDiskFileName, ReportSettings;


FROM RateLists              IMPORT
    (* TYPE *)                  ARateList,
    (* PROC *)                  CreateRateList, DisposeRateList;

FROM RecordIO               IMPORT  ReadRecord, ReadString, ReadRecordPreface,
                                    ReadRecordBody, ReadStringBody;

FROM Registry               IMPORT
    (* CONST *)                 QCapacity,
    (* TYPE *)                  ARegistryDataRecord,
    (* VAR  *)                  UserName, ProductName;

FROM RegCapacity            IMPORT
    (* PROC *)                  GetRegistryInfo;

FROM RsrcMod                IMPORT
    (* TYPE *)                  AResourceType, AResourcePointer, ACostStyle,
    (* VAR  *)                  ResourceNameLength, ResourceTree,
    (* PROC *)                  CreateResource, ChangedResource,
                                FindResourceByName, AddResource,
                                FindResourceByNumber;

FROM Schedule               IMPORT ProjectName, ProjectText,
                                   RetrievalName, ProjectStartDate,
                                   Author, FullScheduleName,
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
    (* CONST*)                  MinDate, NoDuration, Jan,
    (* TYPE *)                  ADuration, ADurationUnit, ADate, ATimeInfo,
    (* PROC *)                  TtoTimeU;

FROM Timeu                  IMPORT
    (* VAR *)                   SMUPH,
    (* PROC *)                  SetStartingMonth, DownScale,
                                GetStartingMonth;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM Transfer               IMPORT  ARetrieveType, RetrieveType,
                                    AHeaderRecord;

FROM TreeObjects            IMPORT
    (* TYPE *)                      ATree, ATreeNode, ATreeOrder,
    (* PROC *)                      CreateTreeNode,
                                    ValidateTree, ValidateTreeNode;

FROM V4Assignments          IMPORT
    (* PROC *)                  ReadV4AssignmentArray;

FROM V4Tasks                IMPORT
    (* TYPE *)                  ATaskV4, AV4BigDateBlock,
    (* PROC *)                  ConvertTaskFromV4;

FROM WBSCommon              IMPORT
    (* TYPE *)                  AWBSPtr,
    (* PROC *)                  SetWBSValues, SaveWBSValues;

FROM XArTable               IMPORT 
    (* PROC *)                  FixV4HeldArtemisTable;

CONST
    ModuleNumber           = 12400; (* SAME AS TLITL3.MOD *)


    (*  Subfile numbers in the Time Line save file  *)
CONST
     HeaderType            = 0;     (* Record type of a node header, which
                                       contains visibility information     *)
     ProjectType           = 1;
     EnvironmentType       = 2;
     PrintFileType         = 3;
     SummaryType           = 4;
     ResourceType          = 5;
     TaskType              = 6;
     EdgeType              = 8;
     CalendarType          = 9;
     BugsType              = 10;
     SignatureType         = 11;
     PrinterTableType      = 12;
     FileNamesType         = 13;
     VideoType             = 14;
     PreferencesType       = 15;
     CodeSetsType          = 16;
     FontsType             = 17;
     PlotsType             = 18;
     FiltersType           = 19;
     HeldItemsType         = 20;
     MemosType             = 21;
     LayoutsType           = 23;
     NetLayoutsType        = 24;
     TLGSDeviceType        = 25;                                  (* 21-May-89 LAA *)
     PalettesType          = 26;  (* Actually, 26, 27 and 28 because of 3 trees *)

     NotesType             = 100;
     SummarizesType        = 103;
     CodingType            = 123;
     PlanAssignmentsType   = 70;
     BaseAssignmentsType   = 80;
     DateBlockPlan         = 90;
     DateBlockBase         = 91;



     ResourceFileVersionNumber   = 1;
     TaskFileVersionNumber       = 9;
     EdgeFileVersionNumber       = 6;
     EnvironmentVersionNumber    = 17;
     CalendarFileVersionNumber   = 1;
     BugsFileVersionNumber       = 1;

CONST
    MAXCARDINAL = 65535;

TYPE
    ADuplicateAction = (DontKnow, Ignore, Override);
    ANoMemoryPlace   = (StartingUp, AddingTasks, AddingEdges,
                        AddingResources, AddingAssignments);
    AWarning         = (BadTaskRecalc);
    ASetOfWarnings   = SET OF AWarning;



VAR
    GlobalCursorNode,
    Node                : ATreeNode;
    TaskBugCount        : CARDINAL;
    DuplicateAction     : ADuplicateAction;
    SaveTaskDates       : BOOLEAN;
    ProjectFileName     : ARRAY [0..81] OF CHAR;
    NoteMessage         : ARRAY [0..39] OF CHAR;
    P                   : POINTER TO ARRAY [0..255] OF CHAR;
    MakeSummaryTask     : BOOLEAN;
    WarningsIssued      : ASetOfWarnings;



PROCEDURE IssueWarning(Warning : AWarning; PhraseNumber : CARDINAL);
BEGIN
    IF (NOT (Warning IN WarningsIssued)) THEN
        INCL(WarningsIssued, Warning);
        ErrorPhrase(PhraseNumber);
    END;
END IssueWarning;








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
    GetMessage( ModuleNumber + 24, s ); (* "No enoough memory while reading " *)
    CASE When OF
      StartingUp        :    GetMessage(    ModuleNumber + 29, s ); (* "Not enough memory to load a schedule" *)
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
            0  :  ReadStringBody(f,Length,Author);
          | 1  :  ReadStringBody(f,Length,FullScheduleName);
          | 2,3:  ReadManyOldTextLines(f, Length, Type, ProjectText);            (* 12/02/86 LAA *)
          | 4  :  ReadStringBody(f,Length,PlannedProjectName);
          | 5  :  ReadDate(f,Length,ScheduleEndDate);             (* 20-Jan-88 LAA *)
          | 6  :  ReadDate(f, Length, ScheduleStartDate);         (* 29-May-89 LAA *)
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
            0  :  ReadStringBody(f,Length,PrintDiskFileName);
          | 1  :  ReadRecordBody(f,Length,ADR(ReportSettings),SIZE(ReportSettings));
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;
END GetPrinterSettings;










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
            2  :  ReadRecordBody(f,Length,ADR(LocalSMUPH),SIZE(LocalSMUPH));
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
END SanitizeTask;








PROCEDURE GetTasks(VAR f : File);
VAR
    TaskNode            : ATreeNode;
    LastTaskAdded       : ATreeNode;
    newtaskV4           : ATaskV4;
    newtask             : ATask;
    Version             : CARDINAL;
    TaskRecordLength    : CARDINAL;
    Type                : CARDINAL;
    TotalTaskCount      : CARDINAL;
    MaxReadCount        : CARDINAL;
    Length              : CARDINAL;
    BadAssignmentCount  : CARDINAL;
    BadAssignments      : CARDINAL;
    CurrentTask         : ATaskPtr;
    Amount              : REAL;
    Header              : AHeaderRecord;
    LevelOffset         : CARDINAL;
    LocalSMUPH          : ADuration;
    Multiplier          : REAL;
    s                   : ARRAY [0..199] OF CHAR;
    Title               : ARRAY [0..29] OF CHAR;
    DuplicateAssignments,
    AnyDuplicateAssignments : BOOLEAN;  (* 7-May-91 RSC  *)


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

        INC( TotalTaskCount );

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


    PROCEDURE BigTimeToTimeU( BigTime : ABigTime; VAR SmallTime : ADate );
    VAR
        TimeInfo     : ATimeInfo;
        ok           : BOOLEAN;
    BEGIN
        BigTimeToTime
        (
            BigTime,
            TimeInfo.tiYear,
            TimeInfo.tiMonth,
            TimeInfo.tiDay,
            TimeInfo.tiHour,
            TimeInfo.tiMinute,
            TimeInfo.tiSecond
        );
        ok := TtoTimeU( TimeInfo, SmallTime );
        IF (NOT ok) THEN
            SmallTime := 0; (* Error in task record Big Date block *)
        END;
    END BigTimeToTimeU;


    PROCEDURE ConvertDateBlocks( UseBaseLine : BOOLEAN );
    VAR BigDateBlock : AV4BigDateBlock;
           DateBlock :      ADateBlock;
        FixedStart   : ADate;
           R         : REAL;
    BEGIN
        IF (CurrentTask <> NIL) THEN
            ReadRecordBody( f, Length, ADR(BigDateBlock),SIZE(BigDateBlock));
            BigTimeToTimeU( BigDateBlock.FixedStart,     FixedStart );
            BigTimeToTimeU( BigDateBlock.EarlyStart,     DateBlock.EarlyStart     );
            BigTimeToTimeU( BigDateBlock.LateFreeStart,  DateBlock.LateFreeStart  );
            BigTimeToTimeU( BigDateBlock.LateTotalStart, DateBlock.LateTotalStart );

                (* For baseline dates, we NEVER calculate the end date
                   based on the duration value.     (3/8/88 EGK )    *)

            IF (NOT UseBaseLine) THEN       (* 8/14/91 EGK *)

                R := (FLOAT(CurrentTask^.duration) * Multiplier) + 0.5;

                IF (R < 65535.0) THEN
                    CurrentTask^.duration  := TRUNC(R);
                ELSE
                    CurrentTask^.duration  := 65535;
                END;
            END;

            IF (SaveTaskDates) OR (UseBaseLine) THEN
                BigTimeToTimeU( BigDateBlock.LateFreeEnd,    DateBlock.LateFreeEnd    );
                BigTimeToTimeU( BigDateBlock.EarlyEnd,       DateBlock.EarlyEnd       );
                BigTimeToTimeU( BigDateBlock.LateTotalEnd,   DateBlock.LateTotalEnd   );

                    (*  Try to compute the duration.  If the dates are wacko,
                        just keep the old duration as a first cut.  *)

                IF (NOT UseBaseLine) AND (DateBlock.EarlyEnd >= DateBlock.EarlyStart) THEN
                    CurrentTask^.duration := DateBlock.EarlyEnd - DateBlock.EarlyStart;
                END;
            ELSE
                DateBlock.LateFreeEnd  := DateBlock.LateFreeStart + CurrentTask^.duration;
                DateBlock.LateTotalEnd := DateBlock.LateTotalStart + CurrentTask^.duration;
                DateBlock.EarlyEnd     := DateBlock.EarlyStart + CurrentTask^.duration;
            END;

            IF (UseBaseLine) THEN
                CurrentTask^.BaseLine.Dates := DateBlock;
            ELSE
                CurrentTask^.Plan.Dates      := DateBlock;
                CalendarTimeToBigTime( FixedStart, TRUE, CurrentTask^.UserEnteredStartDate );  (* 12-Sep-90 RSC *)
                CalendarTimeToBigTime( DateBlock.EarlyEnd, FALSE, CurrentTask^.UserEnteredEndDate );  (* 2-Oct-90 RSC *)
                CurrentTask^.SupposedToStart := CurrentTask^.UserEnteredStartDate;  (* 2-Oct-90 RSC  *)
            END;
        ELSE
            SkipRecordBody (f, Length);
        END;
    END ConvertDateBlocks;


BEGIN
    TaskFindBegin();            (* 24-Jan-91 RSC *)


    AnyDuplicateAssignments := FALSE;
    TaskRecordLength := TSIZE (ATask);
    LocalSMUPH := GetLocalSMUPH (f);
    Multiplier := FLOAT(SMUPH) / FLOAT(LocalSMUPH);

    MaxReadCount    := GetMaxReadCount();
    TotalTaskCount := 0;
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

    LOOP
        IF (BreakRequested()) OR (ErrorFlag) THEN
            EXIT;
        END;
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN
            FileComplaint(f);
            EXIT;
        END;
        CASE Type OF
            HeaderType : ReadRecordBody (f, Length, ADR(Header), SIZE(Header));
          | TaskType:    ReadRecordBody(f,Length,ADR(newtaskV4),TaskRecordLength);  (* 28-Sep-89 LAA *)

                         QuickMessage( newtask.taskname );

                             (* If we detect evidence of a failed recalc,
                                then warn the user that import may not 
                                be right. *)
                         IF (Loop IN newtaskV4.TaskStatusSet) THEN
                             IssueWarning(BadTaskRecalc, 12478);
                         END;

                         ConvertTaskFromV4 (newtaskV4, newtask );

                         IF (CurrentTask <> NIL) THEN
                             Compress(CurrentTask^.notes);
                             SanitizeTask ( CurrentTask );  (* 25-Jan-91 RSC *)
                             TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);
                         END;

                         IF (TotalTaskCount > MaxReadCount) THEN
                             GetMessage(ModuleNumber+36,s);     (* You have too many tasks *)
                             GetMessage(ModuleNumber+37,Title); (* Too many tasks *)
                             WarningBox( s, Title, OfferHelp );
                             EXIT;
                         END;

                         AddIt;

          | NotesType :
                        IF (CurrentTask <> NIL) THEN
                            ReadManyOldTextLines(f, Length, Type, CurrentTask^.notes);
                        ELSE
                            SkipRecordBody(f, Length);
                        END;
          | SummarizesType :
                        IF (CurrentTask <> NIL) THEN
                            ReadManyOldTextLines(f, Length, Type, CurrentTask^.summarizes);
                            Compress(CurrentTask^.summarizes);
                            UnSetState (Scheduled);
                            CurrentTask^.rollupstatus := RollupNotLoaded;
                        ELSE
                            SkipRecordBody(f, Length);
                        END;
          | CodingType :
                        IF (CurrentTask <> NIL) THEN
                            ReadManyOldTextLines(f, Length, Type, CurrentTask^.Coding);
                        ELSE
                            SkipRecordBody(f, Length);
                        END;

          | PlanAssignmentsType :
                        IF (CurrentTask <> NIL) THEN
                            IF (NOT ReadV4AssignmentArray( f, Length,
                                            CurrentTask^.Plan.Assignments,
                                            BadAssignments,
                                            DuplicateAssignments)) THEN
                                TellOfNoMemory( AddingAssignments );
                            END;
                            AnyDuplicateAssignments := AnyDuplicateAssignments OR DuplicateAssignments;
                            INC(BadAssignmentCount,BadAssignments);
                        ELSE
                            SkipRecordBody (f, Length);
                        END;
          | BaseAssignmentsType :
                        IF (CurrentTask <> NIL) THEN
                            IF (NOT ReadV4AssignmentArray (f, Length,
                                            CurrentTask^.BaseLine.Assignments,
                                            BadAssignments,
                                            DuplicateAssignments)) THEN
                                TellOfNoMemory( AddingAssignments );
                            END;
                            AnyDuplicateAssignments := AnyDuplicateAssignments OR DuplicateAssignments;
                            INC(BadAssignmentCount,BadAssignments);
                        ELSE
                            SkipRecordBody (f, Length);
                        END;
          | PlanAssignmentsType+1,
            PlanAssignmentsType+2,
            BaseAssignmentsType+1,
            BaseAssignmentsType+2   :   GetMessage (ModuleNumber+73, s);
                                        Error (s);
                                        SkipRecordBody (f, Length);

          | DateBlockPlan : ConvertDateBlocks( FALSE );

          | DateBlockBase : ConvertDateBlocks( TRUE );

          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

    IF CurrentTask <> NIL THEN
        Compress(CurrentTask^.notes);
        TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);
    END;

    Loaded := NOT ErrorFlag;

    IF (AnyDuplicateAssignments) THEN
        ErrorPhrase( ModuleNumber );
    END;

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

END GetTasks;













PROCEDURE NoteEdge(VAR taskname1,taskname2 : ATaskName);
VAR
    note : ARRAY [0..(2*TskNmLen)+10] OF CHAR;
BEGIN
    SubStr(taskname1,note,1,100);
    IF (NoteMessage[0] = 0C) THEN
        GetMessage(ModuleNumber+13,NoteMessage);   (*  " ----> "  *)
    END;
    ConcatLS( note, NoteMessage );
    ConcatLS(note,taskname2);
    QuickMessage(note);
END NoteEdge;









PROCEDURE AttachEdge( VAR EdgeFromFile : AnEdge ) : BOOLEAN;
VAR
    Task1, Task2            : ATreeNode;
    Status1, Status2        : ATaskStatusSet;
    TaskPtr1, TaskPtr2      : ATaskPtr;
    Task1No  , Task2No      : INTEGER;
    EdgePtr                 : AnEdgePtr;
    i                       : CARDINAL;
    k                       : INTEGER;
    AddressTrick : RECORD
                       CASE BOOLEAN OF
                           TRUE :  P  : ATreeNode;
                         | FALSE:  C  : RECORD
                                            A, B  : INTEGER;
                                        END;
                       END;
                   END;
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

    AddressTrick.P := EdgeFromFile.headtask;
    Task1No        := AddressTrick.C.A;
    Task1          := FindTaskByNumber(Task1No);

    AddressTrick.P := EdgeFromFile.tailtask;
    Task2No        := AddressTrick.C.A;
    Task2          := FindTaskByNumber(Task2No);

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
        NoteEdge (TaskPtr1^.taskname, TaskPtr2^.taskname);  (* 21-Jan-91 RSC *)
        WITH EdgePtr^.FromOffset DO
            IF (Start) THEN
                DEC(k,TaskPtr1^.duration);
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



PROCEDURE GetEdges(VAR f : File);
TYPE
    AnOldEdge = RECORD
                 rectag     : CARDINAL;
                 FromOffset,
                 ToOffset   : RECORD
                                  Start : BOOLEAN;
                                  Plus  : BOOLEAN;
                                  Dur   : ADuration;
                                  Scale : ADurationUnit;
                              END;
                 Delta      : INTEGER;
                 Z          : CARDINAL;
                 headtask   : ATreeNode;
                 tailtask   : ATreeNode;
                 headlink   : AnEdgePtr;
                 taillink   : AnEdgePtr;
            END;

VAR
    RecordLength            : CARDINAL;
    Version, count          : CARDINAL;
    Length                  : CARDINAL;
    Type                    : CARDINAL;
    EdgeFromFile            : AnEdge;
    EdgeFormat8             : AnOldEdge;   (* Version 3.x edge. *)

BEGIN
    IF (NOT StartSubfileInput(f,EdgeType,Version)) THEN
        FileComplaint(f);
        RETURN;
    END;

    DisplayMessage( ModuleNumber + 82 );  (* "Preparing to join tasks ..." *)

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
        INC(count);  (* Help debugging *)

        CASE Type OF
            1 :
                       RecordLength := TSIZE(AnEdge) - 2 * TSIZE(AnEdgePtr);
                       ReadRecordBody(f,Length,ADR(EdgeFromFile),RecordLength);
                       IF (NOT AttachEdge(EdgeFromFile)) THEN
                           EXIT;
                       END;
          | 8 :
                       RecordLength := TSIZE(AnOldEdge) - 2 * TSIZE(AnEdgePtr);
                       ReadRecordBody(f,Length,ADR(EdgeFormat8),RecordLength);
                           (* Convert to new format. *)
                       EdgeFromFile.FromOffset.Start := EdgeFormat8.FromOffset.Start;
                       EdgeFromFile.FromOffset.Plus  := EdgeFormat8.FromOffset.Plus;
                       EdgeFromFile.FromOffset.Dur   := EdgeFormat8.FromOffset.Dur;
                       EdgeFromFile.FromOffset.Scale := EdgeFormat8.FromOffset.Scale;
                       EdgeFromFile.ToOffset.Start   := EdgeFormat8.ToOffset.Start;
                           (* including the code numbers of the tasks. *)
                       EdgeFromFile.headtask         := EdgeFormat8.headtask;
                       EdgeFromFile.tailtask         := EdgeFormat8.tailtask;
                           (* and set defaults for new attributes. *)
                       EdgeFromFile.Type             := Flexible;
                       EdgeFromFile.Attributes       := ASetOfEdgeAttributes{};
                           (* Create the dependency. *)
                       IF (NOT AttachEdge(EdgeFromFile)) THEN
                           EXIT;
                       END;

          | 0FFH     : EXIT;  (* End of subfile *)
            ELSE       SkipRecordBody(f,Length);
        END;

    END;


END GetEdges;








PROCEDURE GetBugs(VAR f:File);
VAR
    Length, Version, Type      : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput(f,BugsType,Version)) THEN
        FileComplaint(f);
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
            1  :  ReadTaskNumber(f,Length,BugTaskA);
          | 2  :  ReadDate(f,Length,BugDayA);
          | 3  :  ReadTaskNumber(f,Length,BugTaskB);
          | 4  :  ReadDate(f,Length,BugDayB);
          | 100:  ReadTaskNumber(f,Length,CursorTask);
          | 101:  ReadDate(f,Length,CursorDay);
          | 0FFH : EXIT;
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

            10   :  TitleBlock := LockTLGSTitleBlock(TLGSGanttChart);   (* 26-May-89 LAA *)
                    IF (TitleBlock <> NIL) THEN
                        ReadRecordBody(F, Length, TitleBlock, SIZE(TitleBlock^));
                    END;
                    UnlockTLGSTitleBlock(TLGSGanttChart);               (* 26-May-89 LAA *)
          | 11   :  GanttRecord := TLGSGanttRecord(0.0);
                    IF (GanttRecord <> NIL) THEN
                        ReadRecordBody(F, Length, GanttRecord, SIZE(GanttRecord^));
                    END;

                (*  Pert chart records  *)

          | 20   :  TitleBlock := LockTLGSTitleBlock(TLGSPertChart);     (* 26-May-89 LAA *)
                    IF (TitleBlock <> NIL) THEN
                        ReadRecordBody(F, Length, TitleBlock, SIZE(TitleBlock^));
                    END;
                    UnlockTLGSTitleBlock(TLGSPertChart);                 (* 26-May-89 LAA *)
          | 21   :  PertRecord := TLGSPertRecord();
                    IF (PertRecord <> NIL) THEN
                        ReadRecordBody(F, Length, PertRecord, SIZE(PertRecord^));
                    END;

                (*  Tree chart records  *)

          | 30   :  TitleBlock := LockTLGSTitleBlock(TLGSTreeChart);    (* 26-May-89 LAA *)
                    IF (TitleBlock <> NIL) THEN
                        ReadRecordBody(F, Length, TitleBlock, SIZE(TitleBlock^));
                    END;
                    UnlockTLGSTitleBlock(TLGSTreeChart);                (* 26-May-89 LAA *)
          | 31   :  TreeRecord := TLGSTreeRecord();
                    IF (TreeRecord <> NIL) THEN
                        ReadRecordBody(F, Length, TreeRecord, SIZE(TreeRecord^));
                    END;

                (*  Page record  *)

          | 40   :  PageRecord := TLGSPageRecord();
                    IF (PageRecord <> NIL) THEN
                        ReadRecordBody(F, Length, PageRecord, SIZE(PageRecord^));
                    END;

          | 0FFH :  EXIT;
        ELSE
            SkipRecordBody(F,Length);
        END;
    END;

END GetTLGSRecords;





PROCEDURE DuplicatesOK( VAR DuplicateName : ARRAY OF CHAR ) : BOOLEAN;
BEGIN

    RETURN (GetDuplicateAction( DuplicateName ) = Override);

END DuplicatesOK;

PROCEDURE FixupV4HeldItems();

VAR
    WBSRecordP              : AWBSPtr;
    Name                    : ARRAY [0..5] OF CHAR;

BEGIN                       (* FixupV4HeldItems *)

    FixV4HeldArtemisTable();  (* 27-Jan-92 TGS *)

    SetString( Name, "TLWBS" );
    IF (SetWBSValues ( Name, WBSRecordP )) THEN
        SaveWBSValues ( Name, WBSRecordP );
    END;

END FixupV4HeldItems;




    (* These constants control the order and choice of subfiles
       read.  Their order is important so as to assure that
       data is available before it is referenced by another
       subfile. *)
CONST
    SIG   =  0; (* 27-Oct-89 RSC moved this to the top. *)
    HLD   =  1;
    ENV   =  2;
    CAL   =  3;
    PRJ   =  4;
    RES   =  5;
    TSK   =  6;
    EDG   =  7;
    PRT   =  8;
    BUG   =  9;
    TLGS  =  10;                                                  (* 21-May-89 LAA *)
    ALIEN =  11; (* 27-Oct-89 RSC they are stored after TLGS recs. *)
    FTR   =  12;
    MMO   =  13;
    LAY   =  14;
    PLT   =  15;     (* Now for Palettes 06-Jul-89 LAA *)




PROCEDURE GetProjectFile(VAR Directory : ARRAY OF CHAR;
                         VAR FileName : ARRAY OF CHAR;
                             RetrieveSet : BITSET
                         ) : BOOLEAN;
VAR
    i,j         : CARDINAL;
    Version     : CARDINAL;
    f           : File;
    s           : ARRAY [0..255] OF CHAR;
    Description : ARRAY [0..1] OF CHAR;
    C           : CHAR;
    FileType    : AFileType;
    ok          : BOOLEAN;

BEGIN
    SetLengthOf(Description,0);
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
                SIG:  ok := GetSignature(f,j);  (* 26-Oct-89 RSC *)
                      IF (ok) THEN
                          ok := (j = 400);
                          IF (NOT ok) THEN
                              SignatureError(400,j);
                          END;
                      END;

              | HLD:  DisplayMessage( ModuleNumber + 87 );  (* "Reading report settings..." *)
                      GetHeldItems(f);
                      FixupV4HeldItems();

              | ENV:  GetTheEnvironment(f);

              | CAL:  DisplayMessage( ModuleNumber + 85 );  (* "Reading calendar information..." *)
                      BeforeCalendarChange();   (* Save a copy *)
                      GetCalendar(f);           (* Get from file *)
                      CalendarUpdate();         (* Do the conversions *)

              | PRJ:  GetProjectDetails(f);

              | RES:  IF (NOT GetResources(f)) THEN
                          IF (CheckIO(f) <> done) THEN
                              FileComplaint(f);
                          ELSE
                              TellOfNoMemory( AddingResources );
                          END;
                      END;

              | TSK:  GetTasks(f);

              | EDG:  GetEdges(f);

              | PRT:  GetPrinterSettings(f);

              | BUG:  GetBugs(f);

              | FTR:  DisplayMessage( ModuleNumber + 90 );  (* "Reading filters..." *)
                        (* 16-Aug-91 PFG    Added an argument that tells 
                                            GetFiltersInfo to account for 
                                            column number changes.  *)
                      GetFiltersInfo(f,DuplicatesOK,(RetrieveType=RetrieveAll), TRUE);

              | MMO:  DisplayMessage( ModuleNumber + 88 );  (* "Reading journal notes..." *)
                      GetMemosInfo(f);                             (* 01/07/87 LAA *)

              | LAY:  DisplayMessage( ModuleNumber + 89 );  (* "Reading layouts..." *)
                        (* 16-Aug-91 PFG    Added an argument that tells 
                                            GetLayoutsInfo and 
                                            GetNetLayoutsInfo to account for 
                                            column number changes.  *)
                      GetLayoutsInfo(f,DuplicatesOK,(RetrieveType=RetrieveAll), TRUE);
                      GetNetLayoutsInfo(f, DuplicatesOK,(RetrieveType=RetrieveAll), TRUE);         (* 17-Nov-87 LAA *)

              | PLT:  GetPalettesInfo(f, TLGSGanttChart, DuplicatesOK,   (* 06-Jul-89 LAA *)
                                      (RetrieveType=RetrieveAll));
                      GetPalettesInfo(f, TLGSPertChart, DuplicatesOK,
                                      (RetrieveType=RetrieveAll));
                      GetPalettesInfo(f, TLGSTreeChart, DuplicatesOK,
                                      (RetrieveType=RetrieveAll));

              | TLGS: GetTLGSRecords(f);

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


    (* SetDefaultOptions -- Set the default values for choiced that
                            don't, or might not, exist in earlier versions.
    *)


PROCEDURE SetDefaultOptions();
BEGIN
    Levelling          := FALSE;
    TimeConstrained    := FALSE;
    HonorDaysOff       := TRUE;
    MoveFutureTasks    := TRUE;
    KeepEffortContiguous := TRUE;             (* 4.0 compatability. *)
    WITH RecalcOptions DO
        AllowNegativeSlack := FALSE;
        Smoothing          := FALSE;
        RollupWeighting    := RollBaseCost;     (* 8-Aug-91 PFG *)
    END;
END SetDefaultOptions;





PROCEDURE LoadOneFile (VAR Directory : ARRAY OF CHAR;
                       VAR FileName  : ARRAY OF CHAR
                       ) : BOOLEAN;

VAR
    s                  : ARRAY [0..MaximumPathNameLength] OF CHAR;
    RetrieveSet        : BITSET;
    Month              : CARDINAL;
    Result             : BOOLEAN;

BEGIN
    SetDefaultOptions();


    RetrieveSet := {  HLD,ENV,PRJ,CAL,SIG,ALIEN,
                      RES,TSK,EDG,BUG,PRT,FTR,MMO,LAY,PLT,TLGS  };   (* 30-May-89 LAA *)

    UnSetState(Sorted);
    UnSetState(Filtered);
    SaveTaskDates := TRUE;

    ResetFilters;                           (* 3/1/88 EGK *)
    CurrentChartFormat := NIL;
    CurrentNetLayout := NIL;
    EnlargedNetLayout := NIL;

    ClearColumnNames();         (* 31-Oct-90 PFG *)

    Result := GetProjectFile(Directory,FileName,RetrieveSet);
    ScheduleSaved := TRUE;       (* 2/29/88 EGK *)
    LayoutChanged();            (* 5-Mar-91 TGS *)

        (* Because a fiscal year may require a change to the date format,
           we need to cancel it and warn the user to restore it. *)
    GetStartingMonth(Month);
    IF (Month <> Jan) THEN
        ErrorPhrase(ModuleNumber+77);
        SetStartingMonth(Jan);
    END;

    RETURN Result;

END LoadOneFile;







PROCEDURE CombineOneFile(VAR Directory : ARRAY OF CHAR;
                         VAR FileName : ARRAY OF CHAR
                         ) : BOOLEAN;
VAR
    RetrieveSet          : BITSET;
    Selection            : CARDINAL;
    s                    : ARRAY [0..200] OF CHAR;
    Prefix               : ARRAY [0..80] OF CHAR;
    Choices              : ARRAY [0..160] OF CHAR;
    Title                : ARRAY [0..30] OF CHAR;
    ok                   : BOOLEAN;
    TasksInMemory,
    RsrcsInMemory        : BOOLEAN;

    PROCEDURE SelectPortion(VAR RetrieveSet:BITSET);
    VAR
        Choice  : CARDINAL;
        Title   : ARRAY [0..40] OF CHAR;
        S       : ARRAY [0..80] OF CHAR;
    BEGIN
        RetrieveSet := {};
        GetMessage(ModuleNumber+4,S);           (* "What do you wish to combine?" *)
        GetMessage(ModuleNumber+75, Title);     (* "Combine options" *)
        SetLengthOf (Prefix, 0);
        GetMessage(ModuleNumber+5,Choices);     (*  "Tasks,Resources/Costs Only,Calendar Only,Filters Only,Memos Only,Layouts Only,Palettes Only"  *)
        Choice := 1;
        IF (MultipleChoiceBox (S, Title, NoHelp, Prefix, Choices, Choice)) THEN
            CASE Choice OF
                1:  RetrieveSet := {SIG,RES,TSK,EDG};
                    GetMessage (ModuleNumber+76, S);    (* Create a summary? *)
                    MakeSummaryTask := NoYes(S);
              | 2:  RetrieveSet := {SIG,RES};
              | 3:  RetrieveSet := {SIG,CAL};
              | 4:  RetrieveSet := {SIG,FTR};
              | 5:  RetrieveSet := {SIG,MMO};
              | 6:  RetrieveSet := {SIG,LAY};
              | 7:  RetrieveSet := {SIG,PLT};                     (* 06-Jul-89 LAA *)
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

           (* If we are combining a project, then we may want to change
               task or resource names as they are read in.  This may be
               done to avoid conflicts with existing names, or to segregate
               tasks into a work-breakdown structure. *)

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

(*      IF (RES IN RetrieveSet) THEN
            GetMessage(ModuleNumber+17, s);   (*  "Rename resources as they are read in? "  *)
            IF (NoYes(s)) THEN
                CheckRenameOf(IsAResourceName);
            END;
        END;

        IF (FTR IN RetrieveSet) THEN
            GetMessage(ModuleNumber + 19, s);  (*  "Rename filters as they are read in? "  *)
            IF NoYes(s) THEN
                CheckRenameOf(IsAFilterName);
            END;
        END;

        IF (MMO IN RetrieveSet) THEN
            GetMessage(ModuleNumber + 31, s);  (*  "Rename memos as they are read in? "  *)
            IF NoYes(s) THEN
                CheckRenameOf(IsAMemoName);
            END;
        END;
*)

        ok := GetProjectFile(Directory,FileName,RetrieveSet);

        IF ((RetrieveSet * {FTR,MMO,LAY,PLT}) = {}) THEN          (* 06-Jul-89 LAA *)
            UnSetState( Scheduled );
        END;

        RETURN ok;

END CombineOneFile;








PROCEDURE ReadInFile();
VAR
    Device       : ARRAY [0..80] OF CHAR;
    Directory    : ARRAY [0..70] OF CHAR;
    Extension    : ARRAY [0..3]  OF CHAR;
    FileName     : ARRAY [0..15] OF CHAR;
    ok           : BOOLEAN;
    Copyright    : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
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
            RetrieveAll :
                            ok := LoadOneFile(    Device, FileName );
          | RetrievePart:
                            ok := CombineOneFile( Device, FileName );
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
    WarningsIssued  := ASetOfWarnings{};

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

END TLITL4.


