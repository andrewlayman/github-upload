MODULE TLITL3;


    (*------------------------------------------------------------------------

                        Import Time Line 3.0 files.


    -------------------------------------------------------------------------*)


(*  =========================================================================
    Last Edit : August 27, 1991 1:04PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description:


    MODIFICATION HISTORY:

       Aug. 28, 1985  AJL - Added handling of duplicates to allow override
                            or ignore.
       Sep. 8, 1985   AJL - Added rename capability for task and resource
                            names.
       Dec. 7, 1985   AJL - When reading in durations, always adjust
                            scales to represent durations exactly.

       May 22, 1986   AJL - Converted to use for Graphics program.

       July 16, 1986  LAA   Massive modifications for Time Line ver. 3
       July 25, 1986  LAA - The two project description lines have been
                            expanded into AText of a very large size.
        11/04/86 LAA    Changed the file extension for Time Line version 3 to
                        be T#0.
        12/02/86 LAA    After reading in a resource, force the notes text to
                        NIL.  Added a procedure to ReadTextLine, and read the
                        resource notes in from the file.  Additional usage of
                        Resource in GetResources.  Used ReadTextLine to get
                        the ProjectText.
        12/12/86 LAA    Read filter information from the project file.
        01/07/87 LAA    Read in the memos from the project file.
        01/28/87 LAA    When the RevealFilterName is read in, set FiltersOn
                        appropriately and show the filter light.
        6/4/87   AJL  - Upgrade to use trees and task and resource ID numbers.
        7/15/87  RSC  - Upgrade for new BigDateBlock saved in file.  No datestring.
        7/27/87  EGK    Removed some code from Graphics which was canceling
                        automatic recalc after loading.
        8/5/87   EGK    For each task, filter, resource, and memo loaded,
                        first read a header record containing attributes of
                        the object regarding storage in its tree (visibility,
                        indentation level, ID of its parent node).
        8/7/87   EGK    Load named layouts.
        8/16/87  RSC    Load Plotter static info.
        9/24/87  EGK    Changes for new procedures to manipulate tasks,
                        resources, and edges.
       10/05/87  RSC    File/Combine bug fixes.
       10/15/87  RSC    When adding edges, don't let tasks need recalc.
       17-Nov-87 LAA    Added reloading of network layouts.
       12-Jan-88 RSC    "Unchanged" changes.
       20-Jan-88 LAA    Added loading and saving of ScheduleEndDate.
       28-Jan-88 RSC    Clean up low memory notices and file complaints.
       02-Feb-88 LAA    Removed use of LowFuel.
       10-Feb-88 EGK    Fix up existing standard layout durations after
                        reading in a calendar.
       12-Feb-88 LAA    Tried to improve behavior under low memory conditions.
       21-Feb-88 EGK    If we ever read in an assignment with an invalid
                        resource ID, we just take it out of the array and
                        keep going.
       26-Feb-88 EGK    Changed to handle new parameter to GetFiltersInfo
                        and GetLayoutsInfo.  Fixed logic in GetDuplicateAction,
                        which was reversed.
       29-Feb-88 EGK    Set ScheduleSaved to TRUE after reading in a complete
                        schedule file.
        1-Mar-88 EGK    Reset layouts and filters before reading in a complete
                        schedule file.
        3-Mar-88 EGK    We now return (in our overlay context) a flag telling
                        our caller whether we successfully read in the file.
        8-Mar-88 EGK    Don't convert baseline end dates to new calendar
                        by adding start date plus duration.
       18-Mar-88 EGK    Erase undo list after combining.  Objects now have
                        different numbers, and undo would get lost.
        6-May-88 EGK    Don't call GetPlotterDetails when reading in a
                        schedule.  Hardware-dependent stuff shouldn't
                        travel around with these files.
        8-Aug-88 EGK    Added FixTaskBugs procedure to compensate for any
                        effects of "the bug".
       20-Oct-88 EGK    After reading in a task record, set Prevlink,
                        Nextlink, and Workspace to NIL.
       31-Oct-88 EGK    Changed SelectPortion to use a multiple-choice box
                        instead of a menu.  This also covers up the "one
                        moment" box.
        2-Jan-89 RSC    Removed references to Compare() (not used).
       10-Jan-89 RSC    Changed Storage to Space.
       28-Feb-89 EGK    Disable reading of resource node attributes.
       20-Mar-89 AJL    Convert version 3 edges.
        5-May-89 EGK    Convert tasks from old format to new format
                        (where WBS, OBS, and AUX are stored in AText).
       12-May-89 RSC    Convert old layout's spaces columns to the one new
                        column.
        6-Jun-89 AJL    Put filters into FlexStor.
        20-Jun-89 RSC       Check Registry for # of tasks allowed.
        22-Jun-89 LAA   Removed unused imports so this module would compile.
                        The addition of RegSupport caused there to be "Too
                        many identifiers".
        25-Jun-89 WKH   Get UserName from Registry instead of Schedule.
        30-Jun-89 LAA   Removed the import of MagicNum and duplicated the one
                        constant needed locally in AjustLayoutColumns.
                        Otherwise, this module won't compile - too many
                        identifiers!  KLUDGE!  KLUDGE!  KLUDGE!
        06-Jul-89 WKH   Use ProductName from Registry instead of local one
        13-Jul-89 EGK   Don't get the same phrase with the combine choices
                        as the one TLITL4 uses.  For this I added a new
                        phrase that doesn't have the "Palettes" choice.
        01-Aug-89 WKH   Use RenumberEverything from Renumber module.
        09-Aug-89 KKC   Add copyright message.
                        Set "Extars" to NIL.
        21-Aug-89 RSC   When creating assignment records, check ExtStatus
                        to make sure there is enough room.
        29-Sep-89 RSC   Removed Tran2 and TLG code (no longer needed) and
                        changed RegSupport to RegCapacity.  This is all to
                        make the overlay small enough to fit in the reserved
                        layer.
         5-Oct-89 EGK   Fixed a bug in ReadAssignmentArray which would fail
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
        16-Aug-90 RSC   Updated for 4.5.
        20-Aug-90 RSC   Convert big time formats from the old style.
        12-Sep-90 RSC   Fixed for new Allocs.Def
        31-Oct-90 PFG   Clear out existing column names when a new 
                        schedule is loaded by calling ClearColumnNames.
        21-Nov-90 AJL       Initialize Planner values for compatability.
        10-Jan-91 AJL   Read old format text lines.
        21-Jan-91 RSC - Remove Fiscal Calendar, and Holder references.
        24-Jan-91 RSC - Zapload texts.  Make SanitizeTask local.
        13-Feb-91 RSC   Change the calls to registry.
         5-Mar-91 TGS   Import LayoutChanged and call it when retrieving a
                        schedule, so we reset the Gantt layout properly.
         7-May-91 RSC   Allow negative slack in Sanitize.  Also, check for
                        any duplicate assignments.
         8-Aug-91 PFG   Some new fields had been added to RecalcOptions, but
                        not initialized here.
        16-Aug-91 PFG   Added arguments to the Layout and Filter info procs
                        (in LoadCommon) so that version 4 column ids could
                        be updated.
        27-Aug-91 PFG   Removed unused import of ImportSelect.
        17-Sep-91 AJL   If there is evidence that the schedule did not
                        compute ok, warn that it may not import right either.
                        Bug 5102.
        30-Sep-91 AJL   Program was crashing when attempting to display
                        a task name before conversion from V3.
         7-Jan-92 TGS   We wasn't setting UEEndDate. Bug 5369. Also, put in
                        some other stuff that was in TLITL4 that looked
                        relevant.
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

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentAttribute, AnAssignmentAttributeSet,
                                AnAssignmentRecord, AnAssignmentArray;

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

FROM Codes                  IMPORT ACode, EmptyCodeSet;

FROM Dialog                 IMPORT Message, Error, FatalError, Burp,
                                   MultipleChoiceBox, ADialogOption,
                                   WarningBox, NotYetImplemented,
                                   ErrorPhrase;

FROM Directory              IMPORT
        (* CONST *)             MaximumPathNameLength,
        (* PROCS *)             ExtractFileNameParts;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr, AnEdgeType, ASetOfEdgeAttributes,
    (* PROC *)                  FindEdge, CreateEdge, AddEdge;

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

FROM FilterRc               IMPORT  FilterTree, AFilterRecordPointer;

FROM Filters                IMPORT  ResetFilters;

FROM IV4Resources           IMPORT
    (* PROC *)                  GetResources;

FROM Kbio                   IMPORT avidmode,
                                   maxrow, maxcol,
                                   GetAnyCode, BreakRequested, ClearBreak,
                                   PutString;

FROM Keys                   IMPORT DoIt, CancelKey;

FROM Layout                 IMPORT MenuStart, MenuEnd, GanttWEnd;

FROM LoadCommon             IMPORT  ErrorFlag, ReadDate,
                                    SkipRecordBody, GetLayoutsInfo,
                                    GetCalendar,
                                    GetTheEnvironment, GetSignature,
                                    SignatureError,
                                    ReadManyOldTextLines, GetFiltersInfo,
                                    ReadTaskNumber, GetHeldItems,
                                    GetMemosInfo, GetNetLayoutsInfo, 
                                    ClearColumnNames;

FROM LStrings               IMPORT SetString, ConcatLS, ConcatS, CtoS,
                                   SubStr, LStringToTString, TStringToLString,
                                   Search, Insert, Remove, Copy, SetLengthOf,
                                   Procustes, StoC, Fill, Upshift, TrimRear;

FROM Memos                  IMPORT  MemoTree, AMemoRecordPointer;

FROM MsgFile                IMPORT  GetMessage, DisplayMessage, ConcatMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NetLayoutTree, CurrentNetLayout,
                                EnlargedNetLayout;

FROM OBigTimeU              IMPORT
    (* PROC *)                  BigTimeToTime;

FROM ObjectID               IMPORT  NewID, InitializeIDs;

FROM Overlays               IMPORT
        (* PROCS *)                 OverlayContext;

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

FROM Renumber               IMPORT
    (* PROC *)                  RenumberEverything;

FROM RsrcMod                IMPORT  ResourceNameLength, AResourcePointer,
                                    CreateResource, ChangedResource,
                                    FindResourceByName, AddResource,
                                    ResourceTree, AResourceType,
                                    ACostStyle,
                                    FindResourceByNumber;

FROM Schedule               IMPORT ProjectName, ProjectText,
                                   RetrievalName, ProjectStartDate,
                                   Author, FullScheduleName,
                                   ConfigSaved, PlannedProjectName,
                                   ScheduleSaved, Loaded, ProjectMedia;

FROM Space                  IMPORT  ALLOCATE, DEALLOCATE, HeapAvailable,
                                    SetHeapLevels;

FROM Subfiles               IMPORT  StartFileInput, StartSubfileInput;

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
    (* CONST*)                  NoDuration, Jan,
    (* TYPE *)                  ADuration, ADurationUnit, ADate, ATimeInfo,
    (* PROC *)                  TtoTimeU;

FROM Timeu                  IMPORT
    (* VAR *)                   SMUPH,
    (* PROC *)                  SetStartingMonth, DownScale,
                                GetStartingMonth;

FROM TimeXlate              IMPORT
    (* PROC *)                  CalendarTimeToBigTime, BigTimeToCalendarTime;

FROM Transfer               IMPORT  ARetrieveType, RetrieveType,
                                    AHeaderRecord;

FROM TreeObjects            IMPORT
    (* TYPE *)                      ATree, ATreeNode, ATreeOrder,
    (* PROC *)                      CreateTreeNode,
                                    ValidateTree, ValidateTreeNode;

FROM Undo                   IMPORT
    (* PROC *)                      FlushUndos;

FROM V3Tasks                IMPORT
    (* TYPE *)                  ATaskV3, AV3BigDateBlock,
    (* PROC *)                  ConvertTaskFromV3;

FROM V4Assignments          IMPORT
    (* PROC *)                  ReadV4AssignmentArray;





CONST
    ModuleNumber           = 12400;


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

     NotesType             = 100;
     SummarizesType        = 103;
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




(*


    (* * * * Module Renaming. * * * *)

    (* Facilities for renaming tasks and resources. *)

MODULE Renaming;

IMPORT ModuleNumber, GetMessage,
       DoForm, NullCheckProc, AFieldValue, CancelKey,
       Search, Remove, Insert, SubStr, TrimRear, Upshift,
       ALLOCATE, DEALLOCATE,  maxcol, GanttWEnd;

EXPORT ANameType, CheckRenameOf, RenameIfAppropriate;

CONST
    MaxRenameLength = 30;
TYPE
    ANameType  = (IsATaskName, IsAResourceName, IsAFilterName, IsAMemoName,
                  IsALayoutName);
    ARenameRecord = RECORD
                        Enabled     : BOOLEAN;
                        From,
                        To          : ARRAY [0..MaxRenameLength] OF CHAR;
                        CaseSensitivity : BOOLEAN;
                    END;
VAR
    Renames       : ARRAY ANameType OF ARenameRecord;
    NameType      : ANameType;


    (* TrimQuote -- If the string is enclosed in quotes, remove them. *)

PROCEDURE TrimQuote( VAR S : ARRAY OF CHAR );
BEGIN
    IF (S[0] > 1C) AND
       (S[1] = '"') AND
       (S[ORD(S[0])] = '"') THEN
           Remove(S,1,1);
           Remove(S,ORD(S[0]),1);
    END;
END TrimQuote;



PROCEDURE CheckRenameOf( NameType : ANameType );
CONST
    FormNumber = 6;
    MaxFields  = 3;
VAR
    FormValue : ARRAY [0..MaxFields] OF AFieldValue;
    FieldNumber : CARDINAL;
BEGIN
    FOR FieldNumber := 0 TO 2 DO
        NEW(FormValue[FieldNumber].CharValue);
        FormValue[FieldNumber].CharValue^[0] := 0C;   (* Null String *)
    END;

        (* Case Sensitivity. *)

    FormValue[3].CardValue := 0;   (* Ignore Case. *)

        (* Get a caption for the form. *)

    GetMessage(ModuleNumber+20+ORD(NameType), FormValue[0].CharValue^ );

        (* Put the form on the screen.  If approved, get the data. *)

    IF (DoForm( 0,0,maxcol,GanttWEnd,FormNumber,TRUE,FormValue,NullCheckProc ) <> CancelKey) THEN
        WITH Renames[NameType] DO
            SubStr(FormValue[1].CharValue^,From,1,MaxRenameLength);
            SubStr(FormValue[2].CharValue^,To,1,MaxRenameLength);
            TrimRear(From);
            TrimRear(To);
            TrimQuote(From);
            TrimQuote(To);
            CaseSensitivity := (FormValue[3].CardValue = 1);
            IF (NOT CaseSensitivity) THEN
                Upshift(From);
            END;
                (* Enable renaming if either field is filled in. *)
            Enabled := (From[0] > 0C) OR (To[0] > 0C);
        END;
    ELSE
        Renames[NameType].Enabled := FALSE;
    END;

    FOR FieldNumber := 0 TO 2 DO
        DISPOSE(FormValue[FieldNumber].CharValue);
    END;
END CheckRenameOf;



PROCEDURE Substitute( VAR TargetString    : ARRAY OF CHAR;
                      VAR From            : ARRAY OF CHAR;
                      VAR To              : ARRAY OF CHAR;
                          CaseSensitivity : BOOLEAN        );
VAR
    i     : CARDINAL;
    Len   : CARDINAL;
    TempString, CopyString : ARRAY [0..80] OF CHAR;
BEGIN
        (* Make a copy of the TargetString that we can Upshift. *)

    SubStr(TargetString, CopyString, 1, HIGH(CopyString) );
    IF (NOT CaseSensitivity) THEN
        Upshift(CopyString);
    END;

        (* See if the From string is in the TargetString.  If
           From is null, then consider it to match at the start. *)

    IF (From[0] > 0C) THEN
        i := Search(CopyString,From,1);
    ELSE
        i := 1;
    END;

        (* If a match, replace From with To. *)

    IF (i > 0) THEN
            (* Do all work on a larger copy so that we don't have to worry
               about the substitution string causing a result too large
               for the target. *)
        SubStr(TargetString,TempString,1,HIGH(TempString));
        Remove(TempString,i,ORD(From[0]));    (* Remove the From pattern. *)
        Insert(TempString,To,i);              (* Replace with To pattern. *)
            (* Copy back, as much as will fit. *)
        SubStr(TempString,TargetString,1,HIGH(TargetString));
    END;
END Substitute;



PROCEDURE RenameIfAppropriate  ( VAR Name    : ARRAY OF CHAR;
                                     NameType: ANameType      );
BEGIN
    WITH Renames[NameType] DO
        IF (Enabled) THEN
            Substitute(Name,From,To,CaseSensitivity);
        END;
    END;
END RenameIfAppropriate;



BEGIN
    FOR NameType := IsATaskName TO IsALayoutName DO
        Renames[NameType].Enabled := FALSE;
    END;
END Renaming;
          (* * * * End module Renaming. * * * *)

*)



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





PROCEDURE FixTaskBugs   ( VAR  Task     : ATask );

CONST
    TaskRecTag          = 111;
    BugValue            = 8;      (* 2**3 *)

    PROCEDURE CheckEnumeration  ( VAR Value           : BYTE;
                                      MaxValue        : CARDINAL;
                                      Default         : CARDINAL  );
    BEGIN
        IF (ORD(Value) > MaxValue) THEN
            INC (TaskBugCount);
            Value := BYTE(CHR(ORD(Value) - BugValue));
            IF (ORD(Value) > MaxValue) THEN
                Value := BYTE(CHR(Default));
            END;
        END;
    END CheckEnumeration;


BEGIN
    WITH Task DO
        IF (rectag <> TaskRecTag) THEN
            INC (TaskBugCount);
            rectag := TaskRecTag;
        END;
        CheckEnumeration (fixation, ORD(Span), ORD(FixedDate));
        CheckEnumeration (EffortScale, ORD(Years), ORD(Days));
        CheckEnumeration (StartStatus, ORD(DoneS), ORD(FutureS));

    END;
END FixTaskBugs;






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
    newtaskV3           : ATaskV3;
    newtask             : ATask;
    count,
    RecordsInFile       : CARDINAL;
    i,j                 : CARDINAL;
    Version             : CARDINAL;
    TaskRecordLength    : CARDINAL;
    Type                : CARDINAL;
    TotalTaskCount      : CARDINAL;
    MaxReadCount        : CARDINAL;
    Length              : CARDINAL;
    BadAssignmentCount  : CARDINAL;
    BadAssignments      : CARDINAL;
    CurrentTask         : ATaskPtr;
    OldTask             : ATaskPtr;
    Resource            : AResourcePointer;
    Amount              : REAL;
    Header              : AHeaderRecord;
    SummaryNode         : ATreeNode;
    SummaryLevel        : CARDINAL;
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
        OtherNode       : ATreeNode;
        ChildNode       : ATreeNode;
        Level           : CARDINAL;
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

            (* Put the tree node into the task tree at the right place. *)

        TaskNode^.Methods^.SetAttributes (TaskNode, Header.Attributes);

        Level := Header.Level + SummaryLevel;

        IF (Level = 0) THEN
            AddTask (TaskNode, NIL, TaskTree^.Methods^.GetLast (TaskTree));
        ELSE
            OtherNode := TaskTree^.Methods^.GetLast(TaskTree);
            IF (OtherNode = NIL) THEN
                AddTask (TaskNode, NIL, NIL);
                RETURN;
            END;
            LOOP
                ChildNode := OtherNode^.Methods^.LastChild (OtherNode);
                IF (OtherNode^.Methods^.IndentationLevel (OtherNode) >= Level - 1) THEN
                    AddTask (TaskNode, OtherNode, ChildNode);
                    EXIT;
                END;
                IF (ChildNode = NIL) THEN
                    AddTask (TaskNode, OtherNode, ChildNode);
                    EXIT;
                ELSE
                    OtherNode := ChildNode;
                END;
            END;
        END;
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
    VAR BigDateBlock : AV3BigDateBlock;
           DateBlock :      ADateBlock;
        FixedStart   : ADate;
           R         : REAL;
    BEGIN
        IF (CurrentTask <> NIL) THEN
            ReadRecordBody( f, Length, ADR(BigDateBlock),SIZE(BigDateBlock));
            BigTimeToTimeU( BigDateBlock.FixedStart,     FixedStart  );
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
                WITH CurrentTask^ DO
                    Plan.Dates     := DateBlock;
                    CalendarTimeToBigTime( FixedStart, TRUE, UserEnteredStartDate );  (* 12-Sep-90 RSC *)
                    CalendarTimeToBigTime( FixedStart, TRUE, SupposedToStart );  (* 12-Sep-90 RSC *)

                    (* 7-Jan-91 TGS added these as with tlitl4: *)
                    CalendarTimeToBigTime( DateBlock.EarlyEnd, FALSE, UserEnteredEndDate );
                    SupposedToStart := UserEnteredStartDate;
                END;
            END;
        ELSE
            SkipRecordBody (f, Length);
        END;
    END ConvertDateBlocks;


BEGIN
    TaskFindBegin();            (* 24-Jan-91 RSC *)


    AnyDuplicateAssignments := FALSE;
    TaskRecordLength := TSIZE (ATaskV3);
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

    SummaryLevel := 0;
    IF (RetrieveType = RetrievePart) THEN
        SummaryNode := CreateTask();
        IF (SummaryNode = NIL) THEN
            ErrorFlag := TRUE;
            RETURN;
        ELSE
            CurrentTask := SummaryNode^.Methods^.LockFlexStorDataObject (SummaryNode);
            GetMessage (ModuleNumber+32, CurrentTask^.taskname);    (* "Summary of " *)
            ConcatLS (CurrentTask^.taskname, ProjectFileName);
            SummaryNode^.Methods^.UnlockFlexStorDataObject (SummaryNode);
            TaskTree^.Methods^.AddLast (TaskTree, SummaryNode);
            SummaryLevel := 1;
            INC( TotalTaskCount );
            GlobalCursorNode := SummaryNode;
        END;
    END;

    CurrentTask := NIL;

    count := 0;
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
          | TaskType:    ReadRecordBody(f,Length,ADR(newtaskV3),TaskRecordLength);

                         QuickMessage(newtaskV3.taskname);

                             (* If we detect evidence of a failed recalc,
                                then warn the user that import may not 
                                be right. *)
                         IF (Loop IN newtaskV3.TaskStatusSet) THEN
                             IssueWarning(BadTaskRecalc, 12478);
                         END;

                         ConvertTaskFromV3 (newtaskV3, newtask, TRUE);

                         IF CurrentTask <> NIL THEN
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

                         FixTaskBugs (newtask);         (* 8/8/88 EGK *)

                         AddIt;

                         INC(count);
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













PROCEDURE GetEdges(VAR f : File);
VAR
    Task1, Task2            : ATreeNode;
    Status1, Status2        : ATaskStatusSet;
    TaskPtr1, TaskPtr2      : ATaskPtr;
    Task1No  , Task2No      : INTEGER;
    EdgePtr                 : AnEdgePtr;
    count, i                : CARDINAL;
    Version, RecordLength   : CARDINAL;
    Type                    : CARDINAL;
    k                       : INTEGER;
    Length                  : CARDINAL;
    AddressTrick : RECORD
                       CASE BOOLEAN OF
                           TRUE :  P  : ATreeNode;
                         | FALSE:  C  : RECORD
                                            A, B  : INTEGER;
                                        END;
                       END;
                   END;
        (* A Version 3 Edge record. *)
    EdgeFromFile            :  RECORD
                 rectag : CARDINAL;
                 FromOffset,
                 ToOffset  :  RECORD
                                  Start : BOOLEAN;
                                  Plus  : BOOLEAN;
                                  Dur   : ADuration;
                                  Scale : ADurationUnit;
                              END;
                 Delta : INTEGER;
                 Z     : CARDINAL;
                 headtask: ATreeNode;
                 tailtask: ATreeNode;
                 headlink: AnEdgePtr;
                 taillink: AnEdgePtr;
            END;

    s                       : ARRAY [0..199] OF CHAR;

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
    IF (NOT StartSubfileInput(f,EdgeType,Version)) THEN
        FileComplaint(f);
        RETURN;
    END;

    RecordLength := TSIZE(AnEdge) - 2 * TSIZE(AnEdgePtr);

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
            EdgeType :
                       ReadRecordBody(f,Length,ADR(EdgeFromFile),RecordLength);

                       AddressTrick.P := EdgeFromFile.headtask;
                       Task1No        := AddressTrick.C.A;
                       Task1 := FindTaskByNumber(Task1No);

                       AddressTrick.P := EdgeFromFile.tailtask;
                       Task2No        := AddressTrick.C.A;
                       Task2 := FindTaskByNumber(Task2No);

                       IF (Task1 = NIL) THEN
                           CannotFind(Task1No);
                       ELSIF (Task2 = NIL) THEN
                           CannotFind(Task2No);
                       ELSE
                           EdgePtr := FindEdge(Task1,Task2);
                           IF (EdgePtr <> NIL) THEN
                               GetMessage (ModuleNumber+73, s);
                               Error (s);
                           ELSE
                               EdgePtr := CreateEdge (Task1,Task2);
                               IF (EdgePtr <> NIL) THEN
                                   EdgePtr^.FromOffset.Start := EdgeFromFile.FromOffset.Start;
                                   EdgePtr^.FromOffset.Plus := EdgeFromFile.FromOffset.Plus;
                                   EdgePtr^.FromOffset.Dur := EdgeFromFile.FromOffset.Dur;
                                   EdgePtr^.FromOffset.Scale := EdgeFromFile.FromOffset.Scale;
                                   EdgePtr^.ToOffset.Start := EdgeFromFile.ToOffset.Start;
                                   EdgePtr^.Type := Flexible;
                                   EdgePtr^.Attributes := ASetOfEdgeAttributes{};
                                   TaskPtr1 := Task1^.Methods^.LockFlexStorDataObject (Task1);
                                   TaskPtr2 := Task2^.Methods^.LockFlexStorDataObject (Task2);
                                   NoteEdge (TaskPtr1^.taskname, TaskPtr2^.taskname);
                                   Task1^.Methods^.UnlockUnchangedDataObject (Task1);
                                   Task2^.Methods^.UnlockUnchangedDataObject (Task2);

                                   AddEdge (EdgePtr, FALSE);

                               ELSE
                                   (* If we failed for some reason other than that the
                                      dependency already exists (we may be combining),
                                      then it is serious. *)
                                    TellOfNoMemory( AddingEdges );
                                    EXIT;
                               END;
                           END;
                                (* Recompute the net effect of partial dependencies.  *)
                           k := NoDuration;
                                (*  Partial join from. *)
                           TaskPtr1 := Task1^.Methods^.LockFlexStorDataObject (Task1);
                           TaskPtr2 := Task2^.Methods^.LockFlexStorDataObject (Task2);
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
                           Task1^.Methods^.UnlockUnchangedDataObject (Task1);
                           Task2^.Methods^.UnlockUnchangedDataObject (Task2);
                           EdgePtr^.Delta := k;            (* Jason Bourne *)
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





PROCEDURE DuplicatesOK( VAR DuplicateName : ARRAY OF CHAR ) : BOOLEAN;
BEGIN

    RETURN (GetDuplicateAction( DuplicateName ) = Override);

END DuplicatesOK;



PROCEDURE AjustLayoutColumns( VAR Node        : ATreeNode;
                                  Context     : ADDRESS   );
CONST
    OldBadRangeStart    = 65;
    OldBadRangeEnd      = 74;
    BlanksColumn        = 64;   (*  From MagicNum.DEF - this should REALLY *)
                                (*  be IMPORTED, but if we do that this    *)
                                (*  module has too many identifiers to     *)
                                (*  compile!  KLUDGE !  KLUDGE !  KLUDGE ! *)
VAR
    Col,
    i               : CARDINAL;
    LayoutPtr       : AChartFormatPtr;
BEGIN
    LayoutPtr := Node^.Methods^.GetDataObject (Node);

(*  Don't alter if it's one of the standard layouts.
    This assumes we erase the schedule before reading a V3 schedule in.
    Tran2.Mod deletes all old non-standard layouts.
*)

    WITH LayoutPtr^ DO
        IF NOT (0 IN LayoutFlags) THEN
            FOR i := 1 TO HIGH(ColumnSpec) DO
                Col := ColumnSpec[i].ColumnID;
                IF (Col >= OldBadRangeStart) AND (Col <= OldBadRangeEnd) THEN
                    ColumnSpec[i].ColumnID := BlanksColumn;
                END;
            END;
        END;
    END;
END AjustLayoutColumns;



(*
    There were 9 spaces columns in V3.  Only 1 in V4.  Convert old spaces cols
    to new spaces cols.
*)
PROCEDURE AjustV3Layouts(); (* RSC 12-May-89 *)
VAR
BEGIN
    LayoutTree^.Methods^.TraverseTree (LayoutTree, ParentBeforeChild,
            9999, AjustLayoutColumns, NIL);
END AjustV3Layouts;




    (* These constants control the order and choice of subfiles
       read.  Their order is important so as to assure that
       data is available before it is referenced by another
       subfile. *)
CONST
    SIG   =  0;     (* 27-Oct-89 RSC changed ordering, so SIG is first. *)
    HLD   =  1;
    ENV   =  2;
    CAL   =  3;
    PRJ   =  4;
    RES   =  5;
    TSK   =  6;
    EDG   =  7;
    PRT   =  8;
    BUG   =  9;
    FTR   =  11;
    MMO   =  12;
    LAY   =  14;




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
        IF (BreakRequested()) THEN
            ErrorFlag := TRUE;
        END;
        IF (NOT ok) OR (ErrorFlag) THEN EXIT; END;
        IF (i > LAY) THEN
            EXIT;
        ELSIF (i IN RetrieveSet) THEN
            CASE i OF
                SIG:  ok := GetSignature(f,j);  (* 26-Oct-89 RSC *)
                      IF (ok) THEN
                          ok := (j = 300);
                          IF (NOT ok) THEN
                              SignatureError(300,j);
                          END;
                      END;
              | HLD:  GetHeldItems(f);
              | ENV:  GetTheEnvironment(f);
              | CAL:  BeforeCalendarChange();   (* Save a copy *)
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
              | FTR:  GetFiltersInfo(f,DuplicatesOK,(RetrieveType=RetrieveAll), FALSE);
              | MMO:  GetMemosInfo(f);                             (* 01/07/87 LAA *)
              | LAY:  GetLayoutsInfo(f,DuplicatesOK,(RetrieveType=RetrieveAll), FALSE);
                      GetNetLayoutsInfo(f, DuplicatesOK,(RetrieveType=RetrieveAll), FALSE);         (* 17-Nov-87 LAA *)
                      AjustV3Layouts(); (* RSC 12-May-89 *)
              ELSE
                    EXIT;
            END;
        END;
        IF (ok) THEN
            ok := (CheckIO(f) = done);
        END;
        INC(i);
    END;


    ClearBreak;    (* Clear any Break request. *)

    TaskFindEnd();

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


    RetrieveSet := {  HLD,ENV,PRJ,CAL,SIG,
                      RES,TSK,EDG,BUG,PRT,FTR,MMO,LAY  };

    UnSetState(Sorted);
    UnSetState(Filtered);
    SaveTaskDates := TRUE;

    ResetFilters;                           (* 3/1/88 EGK *)
    CurrentChartFormat := NIL;
    CurrentNetLayout := NIL;
    EnlargedNetLayout := NIL;

    ClearColumnNames();         (* 31-Oct-90 PFG *)

    Result := GetProjectFile(Directory,FileName,RetrieveSet);
    ScheduleSaved := TRUE;      (* 2/29/88 EGK *)
    LayoutChanged();            (* 5-Mar-91 TGS *)

        (* Because a fiscal year may require a change to the date format,
           we need to cancel it and warn the user to restore it. *)
    GetStartingMonth(Month);
    IF (Month <> Jan) THEN
        ErrorPhrase(12477);
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
    Choices              : ARRAY [0..100] OF CHAR;
    Title                : ARRAY [0..30] OF CHAR;
    ok                   : BOOLEAN;
    TasksInMemory,
    RsrcsInMemory        : BOOLEAN;

    PROCEDURE SelectPortion(VAR RetrieveSet:BITSET);
    VAR
        Code   : ACode;
        Choice : CARDINAL;
        Title   : ARRAY [0..40] OF CHAR;
        S       : ARRAY [0..80] OF CHAR;
    BEGIN
        RetrieveSet := {};
        GetMessage(ModuleNumber+4,S);           (* "What do you wish to combine?" *)
        GetMessage(ModuleNumber+75, Title);     (* "Combine options" *)
        SetLengthOf (Prefix, 0);
        GetMessage(ModuleNumber+91,Choices);     (*  "Tasks,Resources/Costs Only,Calendar Only,Filters Only,Memos Only,Layouts Only"  *)
        Choice := 1;
        IF (MultipleChoiceBox (S, Title, NoHelp, Prefix, Choices, Choice)) THEN
            CASE Choice OF
                1:  RetrieveSet := {SIG,RES,TSK,EDG};
              | 2:  RetrieveSet := {SIG,RES};
              | 3:  RetrieveSet := {SIG,CAL};
              | 4:  RetrieveSet := {SIG,FTR};
              | 5:  RetrieveSet := {SIG,MMO};
              | 6:  RetrieveSet := {SIG,LAY};
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

        ok := GetProjectFile(Directory,FileName,RetrieveSet);

        IF ((RetrieveSet * {FTR,MMO,LAY}) = {}) THEN
            UnSetState( Scheduled );
        END;

        RETURN ok;

END CombineOneFile;



(******************************************************  01-Aug-89 WKH

PROCEDURE NumberTheTask     ( VAR Node      : ATreeNode;
                                  Context   : ADDRESS   );
VAR
    TaskPtr             : ATaskPtr;
BEGIN
    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    TaskPtr^.TaskID := NewID();
    Node^.Methods^.UnlockFlexStorDataObject (Node);
END NumberTheTask;




PROCEDURE NumberTheResource     ( VAR Node      : ATreeNode;
                                      Context   : ADDRESS   );
VAR
    ResourcePtr             : AResourcePointer;
BEGIN
    ResourcePtr := Node^.Methods^.GetDataObject (Node);
    ResourcePtr^.ID := NewID();
END NumberTheResource;




PROCEDURE NumberTheLayout     ( VAR Node      : ATreeNode;
                                    Context   : ADDRESS   );
VAR
    LayoutPtr             : AChartFormatPtr;
BEGIN
    LayoutPtr := Node^.Methods^.GetDataObject (Node);
    LayoutPtr^.ID := CARDINAL(NewID());
END NumberTheLayout;




PROCEDURE NumberTheNetLayout  ( VAR Node      : ATreeNode;
                                    Context   : ADDRESS   );
VAR
    LayoutPtr             : ANetworkLayout;
BEGIN
    LayoutPtr := Node^.Methods^.GetDataObject (Node);
    LayoutPtr^.ID := CARDINAL(NewID());
END NumberTheNetLayout;




PROCEDURE NumberTheFilter     ( VAR Node      : ATreeNode;
                                    Context   : ADDRESS   );
VAR
    FilterPtr             : AFilterRecordPointer;
BEGIN
    FilterPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    FilterPtr^.ID := CARDINAL(NewID());
    Node^.Methods^.UnlockFlexStorDataObject (Node);
END NumberTheFilter;




PROCEDURE NumberTheMemo     ( VAR Node      : ATreeNode;
                                  Context   : ADDRESS   );
VAR
    MemoPtr             : AMemoRecordPointer;
BEGIN
    MemoPtr := Node^.Methods^.GetDataObject (Node);
    MemoPtr^.ID := CARDINAL(NewID());
END NumberTheMemo;




PROCEDURE RenumberEverything();

BEGIN
    InitializeIDs (0);

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentAfterChild, 9999,
        NumberTheTask, NIL);
    ResourceTree^.Methods^.TraverseTree (ResourceTree, ParentAfterChild, 9999,
        NumberTheResource, NIL);
    FilterTree^.Methods^.TraverseTree (FilterTree, ParentAfterChild, 9999,
        NumberTheFilter, NIL);
    LayoutTree^.Methods^.TraverseTree (LayoutTree, ParentAfterChild, 9999,
        NumberTheLayout, NIL);
    NetLayoutTree^.Methods^.TraverseTree(NetLayoutTree,ParentAfterChild,9999,  (* 17-Nov-87 LAA *)
        NumberTheNetLayout, NIL);
    MemoTree^.Methods^.TraverseTree (MemoTree, ParentAfterChild, 9999,
        NumberTheMemo, NIL);

END RenumberEverything;
01-Aug-89 WKH  *******************************************)





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

(*$S=*)





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
    FlushUndos();                                       (* 3/18/88 EGK *)

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

END TLITL3.



