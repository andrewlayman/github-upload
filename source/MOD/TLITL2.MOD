MODULE TLITL2;

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
       10/08/86 LAA         Fixed this module so it just imports vers. 2.0
                            type files into 3.0 structure.
       11/03/86 LAA         Merged some minor improvements in PLLOAD into this
                            module.  In  GetBugs, replaced calls to ReadDate
                            with calls to a local procedure, because the format
                            of dates stored in Time Line 2.0 files is not
                            compatible with ReadDate.
        11/04/86 LAA        Because this is now really an importer, only allow
                            retreival of complete files.
        11/10/86 LAA        Use RecomputeAfterLoad to fixup whatever, when a
                            schedule is imported with this.
        12/02/86 LAA        Set the notes field of a resource to NIL after
                            reading in the resource body.
        12/05/86 LAA        Made adjustments for differencs in record
                            structure between vers. 2 and 3.
        03/30/87 EGK        Made more adjustments for differences in record
                            structure (in GetResources).
        05/06/87 AJL      - Fixed reading of dependencies.
                          - Add routines to copy notes text to WBS, OBS or
                            AUX fields.
                          - Although the new form asks "Infer Indentation" this
                            is not active.
                          - Commented out the task and resource renaming.
        05/08/87 AJL      - Added logic to read in the resource amounts into
                            new assignment records.
        05/18/87 RSC      - Used the new SetManyExtObjects to increase the range
                            of assignment records that can be assigned to a task.
        05/22/87 EGK      - Modified GetResources, GetFiltersInfo, and
                            GetTasks to use their respective trees.
        02-Jun-87 LAA     - Used the Traverse method instead of ForAllTasks.
        07-Jun-87 AJL     - Removed some references to P@0 files.
                          - Incorporated former text from LoadCommon.
        16-Jun-87 AJL     - Fill in the MustStartBy and MustEndBy fields.
                          - Put PlanExists into the task flags set.
        22-Jun-87 LAA     - Re-initialized the GanttChart if, after reading
                            in the version 2 schedule, the cursor node is NIL.
        11-Jul-87 RSC     - Remove MustStartBy and MustEndBy.
        15-Jul-87 RSC     - Remove datestring from new task record.
        23-Jul-87 RSC     - Remove InferIndentation from form.  Calculate
                            resource costing better.  Allow for new cost calc
                            schemes and record layouts.
        5-Aug-87  EGK       Removed all stuff having to do with loading of
                            filters, since ver 2 files don't contain this
                            information.
       24-Sep-87  RSC       Bug fixes for all bugs to date.  New TLGETIT
                            loading scheme.  Handle Span tasks.
        7-Oct-87  RSC       For some reason, SMUPH was not being set up in
                            GetTasks().  Also, I removed GetLocalSMUPH, as
                            it was not needed.  Removed references to SetMany
                            ExtObjects with the more Andrew-Prefered SetExtData.
                            This also let me clean up the whole messy business
                            of adding assignments.
       15-Oct-87  RSC       When adding edges, don't let the task need recalc.
       28-Oct-87  RSC       Fixup priority field in task record as <old pri>
                            times 10, unless MAX(<old pri>) > 999.
       30-Dec-87  LAA       When reading in the schedule notes, try to break
                            into words if it's longer than we currently
                            allow in one line.
       12-Jan-88  RSC       "Unchanged" changes.
       28-Jan-88  RSC       Clean up low memory notices and file complaints.
                            conversion of rates cleanup.
        9-Feb-88  RSC       Try to trap out-of-memory better.
       11-Feb-88  EGK       Fix up existing standard layout durations after
                            reading in the calendar.
       12-Feb-88  RSC       1) For VC assignments's, ignore rsrc limits.
                            2) Non-Rsrcs have "Level this rsrc" turned off.
       23-Feb-88  RSC       1) Implemented NameCopy to WBS/OBS/AUX
                            2) Cleaned up serialization check for max tasks.
        1-Mar-88  EGK       Fill in FixedStart values for the span task
                            milestones, in case the span was started or done.
        02-Mar-88 LAA       TLFBASE is not allowed in the reserve layer.
         3-Mar-88 EGK       We now return (in our overlay context) a flag
                            telling our caller whether we successfully read
                            in the file.
         7-Mar-88 EGK       Fix up handling of partial joins to span tasks.
                            Clear all unused (in v2) task status bits.
        11-Mar-88 RSC       fix illegal chars in edges so that they find their
                            (fixed name) tasks.
        21-Dec-88 LAA       Changed imports for Lazlo reorganization.
         2-Jan-89 RSC       Added references to StringsEqual() rather than Compare().
        10-Jan-89 RSC       Changed Storage to Space    .
        21-Mar-89 RSC       Upgraded to use FSMUPH rather than FLOAT(SMUPH).
        20-Apr-89 AJL       Convert to use new edge records.
         5-May-89 EGK       Changed to use new WBS storage scheme.
        14-May-89 AJL       Remove import of Alarms.
        20-Jun-89 RSC       Check Registry for # of tasks allowed.
        25-Jun-89 WKH       Get UserName from Registry instead of Schedule
        06-Jul-89 WKH       Use ProductName from Registry instead of locally.
        01-Aug-89 WKH       Use RenumberEverything from Renumber module.
        09-Aug-89 KKC       Add copyright message.
        21-Aug-89 RSC       Check ExtStatus before adding assignment records.
        12-Sep-89 LAa       Removed the import of Holder (no longer used).
        21-Sep-89 RSC       Added parm for SetResourceRate.
        29-Sep-89 RSC       Changed RegSupport to RegCapacity.  Saves 3K.
        30-Mar-90 RSC       Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC       Grouped year, month, day, hour, minute into one
                            date structure, ATimeInfo. 
        26-Jul-90 RSC       Upgraded for EVE records.
        20-Aug-90 RSC       Upgraded for new BigTimes.
        12-Sep-90 RSC       Fixed for new Allocs.Def
         2-Oct-90 RSC       1) Don't create a rate if = 1.0.
                            2) Fill in SupposedToStart.
        31-Oct-90 PFG       Clear out existing column names when a new 
                            schedule is loaded by calling ClearColumnNames.
        21-Nov-90 AJL       Initialize Planner values for compatability.
        25-Jan-91 RSC       Ajust for new procedures from Edges and Text.
        31-Jan-91 TGS       Create a DateList to put availability into.
                            Fix Notes import.
        13-Feb-91 RSC       Change the calls to registry.
        17-Apr-91 RSC       Don't allow duplicate resources.
         7-May-91 RSC       Allow negative slack in Sanitize.
        21-Jun-91 TGS       Provided a way for a WHILE loop to exit.
         1-Jul-91 TGS       All years start with January.
        10-Jul-91 TGS       Initialize some uninitialized assignment stuff.
        31-Jul-91 AJL       Always create a RateList for resources.
         8-Aug-91 PFG       Some new fields had been added to RecalcOptions, 
                            but not initialized here.
        27-Aug-91 PFG       Removed unused import of ImportSelect.
         1-Oct-91 AJL       UnSetState(Scheduled) always, turning on the 
                            recalc light.  
        20-Jan-92 AJL       Use LinkSupport module.
    =========================================================================
*)





    (*------------------------------------------------------------------------

                     Import Time Line 2.0 files into 3.0.

    IMPORTER ISSUES/CHECKLIST  (Started 10/7/87 by RSC)

        > The V2 calendar was smaller and has less fields in it than the V3
          calendar.  As of now, we import the V2 calendar, making the new
          fields No Verk fields.  We also don't update start of week, Start
          of year, etc.

    -------------------------------------------------------------------------*)










FROM Allocs                 IMPORT ATask, ATaskPtr, ATaskName,
                                   AFixType, ADurationMethod,
                                   TskNmLen, ARollupStatus,
                                   ATaskFlag, ATaskFlagSet, AStartStatus,
                                   ATaskStatus, ATaskStatusSet, ATaskFilter,
                                   CopyTask, ATaskFilterSet, DelTask,
                                   InitializeTaskRecord, CreateTask, TaskTree,
                                   AddTask, WBSLine, OBSLine, AUXLine,
                                   SetCodingField;

FROM AsOf                   IMPORT  AsOfSettingOption, AsOfDate;

IMPORT Assignments;

FROM BigTimeU               IMPORT
    (* VAR  *)                  MINBIGTIME;

FROM Chart                  IMPORT BugTaskA, BugDayA, BugTaskB, BugDayB,
                                   CursorTask, CursorDay, GanttChart;

FROM ChartControl           IMPORT UnSetState, AChartState;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR *)                   LayoutTree, DefaultChartFormat;

FROM Codes                  IMPORT ACode, EmptyCodeSet, SetCodeBits,
                                   MaxCode;

FROM DateLists              IMPORT
    (* TYPE *)                  ADateList,
    (* PROC *)                  CreateDateList;

FROM Dialog                 IMPORT Message, Error, FatalError, Burp,
                                   MultipleChoiceBox, ADialogOption,
                                   WarningBox, NotYetImplemented,
                                   ErrorPhrase;

FROM Directory              IMPORT ExtractFileNameParts;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr, AnEdgeType, ASetOfEdgeAttributes,
    (* PROC *)                  FindEdge, CreateEdge, AddEdge;

FROM FlexStor               IMPORT
    (* TYPE *)                      AnExtHandle, AnExtStoragePreference,
                                    AnExtStatus,
    (* PROC *)                      ArraySize, CreateExtObject,
                                    DiscardExtObject, SetExtData,
                                    GetExtStatus;

FROM FileSystem             IMPORT File, Lookup, Response, Close,
                                   Create, Rename, Delete;

FROM FileAux                IMPORT FileResultMeans,
                                   FlushBuffer, PrepareForIO, CheckIO;

FROM FileOpen               IMPORT RequestFileOpen;

FROM RealFormat             IMPORT FormatAsAmount, DefaultAmountFormat;

FROM ResCalUI               IMPORT 
    (* TYPE *)                  AnAvailabilityRate;

FROM Kbio                   IMPORT avidmode,
                                   maxrow, maxcol,
                                   GetAnyCode, BreakRequested, ClearBreak,
                                   PutString;

FROM Layout                 IMPORT MenuStart, GanttWEnd;

FROM LinkSupport            IMPORT
                                   NewPercent;

FROM LStrings               IMPORT SetString, ConcatLS, ConcatS, CtoS,
                                   SubStr, LStringToTString, TStringToLString,
                                   Search, Insert, Remove, StoC,
                                   Fill, StringsEqual, Upshift, TrimRear,
                                   TrimFront, Copy, LengthOf, SetLengthOf;

FROM Menus                  IMPORT WordNumber, Menu, NoYes;

FROM MsgFile                IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM ObjectID               IMPORT NewID;

FROM Overlays               IMPORT
        (* PROCS *)                CallOverlayWithContext, OverlayContext;

FROM ParseTime              IMPORT
    (* PROC *)                  StoTimeU;

FROM Planner                IMPORT
    (* VAR *)                   HonorDaysOff,
                                Levelling, KeepEffortContiguous,
                                MoveFutureTasks, TimeConstrained, RecalcOptions,
   (* TYPE *)                   AWhenToCalc, ACalcComponent, ARollupWeighting,
   (* VAR *)                    CalculationState;

FROM PrintStatic            IMPORT PrintDiskFileName, ReportSettings;

FROM RateLists              IMPORT
    (* PROC *)                  CreateRateList;

FROM RecordIO               IMPORT ReadRecord, ReadString, ReadRecordPreface,
                                   ReadRecordBody, ReadStringBody;

FROM Registry               IMPORT
    (* CONST *)                 QCapacity,
    (* TYPE *)                  ARegistryDataRecord,
    (* VAR  *)                  UserName, ProductName;

FROM RegCapacity            IMPORT
    (* PROC *)                  GetRegistryInfo;

FROM Renumber               IMPORT
    (* PROC *)                  RenumberEverything;

FROM RsrcMod                IMPORT 
    (* CONST *)                 ResourceNameLength, DefaultCostRate,
                                DefaultAvailabilityAmount,
                                DefaultAvailabilityPercent,
    (* TYPE *)                  AResourcePointer,
                                AResourceType, ACostStyle,
    (* VAR *)                   ResourceTree,
    (* PROC *)                  CreateResource, ChangedResource,
                                InitializeResource, DeleteResource,
                                CopyResourceNode, FindResourceByName, 
                                AddResource;

FROM Schedule               IMPORT ProjectName, ProjectText,
                                   ProjectStartDate,
                                   Author, FullScheduleName,
                                   PlannedProjectName,
                                   ScheduleSaved, Loaded, ProjectMedia;

FROM Space                  IMPORT HeapAvailable,
                                   ALLOCATE, DEALLOCATE;

FROM Subfiles               IMPORT StartFileInput, StartSubfileInput;

FROM SYSTEM                 IMPORT ADDRESS, TSIZE, SIZE, ADR;

FROM Text                   IMPORT
    (* PROC *)                  CreateText, TextExists, DiscardText, AppendLine,
                                Compress, AText;

FROM TimeConversions        IMPORT
    (* PROC *)                  BeforeCalendarChange, AfterCalendarChange,
                                ToNewScale;

FROM Timei                  IMPORT
    (* CONST*)                  NoDuration, Jan,
    (* TYPE *)                  ADuration, ADurationUnit, ADate, ATimeInfo,
    (* VAR *)                   Today,
    (* PROC *)                  FindToday, TtoTimeU;

FROM Timeu                  IMPORT
    (* TYPE *)                  AYearTable,
    (* VAR *)                   TimeTable, ATimeTable, FSMUPH,
                                WeeksBeginOn,
    (* PROC *)                  SetStartingMonth, UpScale,
                                GetStartingMonth;

FROM TimeXlate              IMPORT
    (* PROC *)                  CalendarTimeToBigTime, BigTimeToCalendarTime;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder, ATreeNodeAttribute,
    (* PROC *)                  CreateTreeNode, ValidateTreeNode;

FROM LoadCommon             IMPORT
    (* PROCS *)                 SkipRecordBody, GetCalendar, GetTheEnvironment,
                                GetHeldItems, ClearColumnNames;

CONST
    ModuleNumber           = 12400;


    (*  Subfile numbers in the Time Line save file  *)
CONST
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
     FiltersType           = 19;        (* Not actually used *)
     HeldItemsType         = 20;

        (* Record types within the task subfile, from vers. 2.0 *)
CONST
     NotesType             = 100;
     Notes2Type            = 101;
     SummarizesType        = 2;


     ResourceFileVersionNumber   = 1;
     TaskFileVersionNumber       = 9;
     EdgeFileVersionNumber       = 6;
     EnvironmentVersionNumber    = 17;
     CalendarFileVersionNumber   = 1;
     BugsFileVersionNumber       = 1;

CONST
   FMAXCARDINAL           = 65535.0;  (* Max card as a REAL number *)
    MAXCARDINAL           = 65535;
    MAXDATE               = MAXCARDINAL;
    Zero                  = 0.0;
    One                   = 1.0;
    OneHundred            = 100.0;
    Point5                = 0.5;
    SpanFlag              = TempFlag6;


TYPE

    AResourceNodePointer = POINTER TO AResourceNode;

    AResourceNode = RECORD
                        Tag      : CARDINAL;
                        Resource : AResourcePointer;
                        Amount   : REAL;
                        Conflict : BOOLEAN;
                        NextLink : AResourceNodePointer;
                    END;

    ANoMemoryPlace   = (StartingUp, AddingTasks, AddingEdges,
                        AddingResources, AddingAssignments);

VAR
    Node                : ATreeNode;
    MaxPriority         : CARDINAL;
    Notes1Copy,
    Notes2Copy          : [0..3];
    InferIndentation    : BOOLEAN;
    ErrorFlag           : BOOLEAN;
    ProjectFileName     : ARRAY [0..81] OF CHAR;
    NoteMessage         : ARRAY [0..39] OF CHAR;
    P                   : POINTER TO ARRAY [0..255] OF CHAR;
    GNotifiedNameChange : BOOLEAN;







    (* * * * Module Renaming. * * * *)

    (* Facilities for renaming tasks and resources. *)

(*
MODULE Renaming;

IMPORT ModuleNumber, GetMessage,
       DoForm, NullCheckProc, AFieldValue, CancelKey,
       Search, Remove, Insert, SubStr, TrimRear, Upshift,
       ALLOCATE, DEALLOCATE,  maxcol, GanttWEnd;

EXPORT ANameType, CheckRenameOf, RenameIfAppropriate;

CONST
    MaxRenameLength = 30;
TYPE
    ANameType  = (IsATaskName, IsAResourceName);
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
    FieldNumber : CARDINAL;
    FormValue   : ARRAY [0..MaxFields] OF AFieldValue;
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
    FOR NameType := IsATaskName TO IsAResourceName DO
        Renames[NameType].Enabled := FALSE;
    END;
END Renaming;
*)
          (* * * * End module Renaming. * * * *)








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
    Error(s);
END TellOfNoMemory;








PROCEDURE FindTask ( VAR Name: ATaskName ) : ATreeNode;
VAR
    Node    : ATreeNode;
    Task    : ATaskPtr;
    Same    : BOOLEAN;
BEGIN
    Node := TaskTree^.Methods^.GetFirst (TaskTree);
    WHILE (Node <> NIL) DO
        Task := Node^.Methods^.LockFlexStorDataObject (Node);
        Same := (StringsEqual (Task^.taskname, Name));      (* RSC 1/2/88 *)
        Node^.Methods^.UnlockUnchangedDataObject (Node);

        IF (Same) THEN
            RETURN Node;
        END;
        Node := Node^.Methods^.GetNext (Node);
    END;
    RETURN NIL;
END FindTask;




PROCEDURE ReadDate(    VAR F      : File;
                           Length : CARDINAL;
                       VAR D      : ADate );
VAR
    N    : ARRAY [0..4] OF CARDINAL;
    TimeInfo    :   ATimeInfo;
    i,j  : CARDINAL;
    S    : ARRAY [0..30] OF CHAR;
    S2   : ARRAY [0..2] OF CHAR;
BEGIN
    ReadStringBody(F,Length,S);
    FOR i := 0 TO 4 DO
        SubStr(S,S2,(2*i)+1,2);
        j := 1;
        N[i] := StoC(S2,j);
    END;

    IF (N[0] < 83) THEN
        INC(N[0],2000);
    ELSE
        INC(N[0],1900);
    END;

    TimeInfo.tiYear := N[0];
    TimeInfo.tiMonth := N[1] - 1;
    TimeInfo.tiDay := N[2];
    TimeInfo.tiHour := N[3];
    TimeInfo.tiMinute := N[4];

    IF (TtoTimeU(TimeInfo,D)) THEN
    ELSE
        Error(S);
    END;
END ReadDate;







    (* GetSignature -- Read the date that the file was saved. *)


PROCEDURE GetSignature(VAR f:File);
VAR
    Version,
    Type,
    Length      : CARDINAL;
    DateString  : ARRAY [0..20] OF CHAR;
    GotAsOfDate : BOOLEAN;
BEGIN
    IF (NOT StartSubfileInput(f,SignatureType,Version)) THEN
        RETURN;
    END;

    GotAsOfDate := FALSE;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
            2  :  ReadStringBody(f,Length,DateString);
                  IF (NOT GotAsOfDate) AND
                     (NOT StoTimeU(DateString,AsOfDate)) THEN
                      AsOfDate := Today;
                  END;
          | 3  :  ReadStringBody(f,Length,DateString);
                  IF (NOT StoTimeU(DateString,AsOfDate)) THEN
                      AsOfDate := Today;
                  ELSE
                      GotAsOfDate := TRUE;
                  END;
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;
END GetSignature;







PROCEDURE GetProjectDetails(VAR f:File);

CONST
    ScheduleNotesWidth      = 60;

VAR
    Version,
    Type,
    Length                  : CARDINAL;
    i                       : CARDINAL;
    s, s2                   : ARRAY [0..80] OF CHAR;

BEGIN
    IF (NOT StartSubfileInput(f,ProjectType,Version)) THEN
        RETURN;
    END;

    IF TextExists(ProjectText) THEN
        DiscardText(ProjectText);
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
            0  :  ReadStringBody(f,Length,Author);
          | 1  :  ReadStringBody(f,Length,FullScheduleName);
          | 2,
            3  :  ReadStringBody(f,Length, s);
                  IF NOT TextExists(ProjectText) THEN
                      ProjectText := CreateText();
                  END;
                  TrimRear(s);                                    (* 30-Dec-87 LAA *)
                  IF (LengthOf(s) > ScheduleNotesWidth) THEN
                      i := ScheduleNotesWidth;
                      WHILE ((i > ScheduleNotesWidth - 20)
                            AND (s[i] <> " ")) DO
                          DEC(i);
                      END;
                      SubStr(s, s2, i + 1, HIGH(s));
                      SetLengthOf(s, i);
                  ELSE
                      SetLengthOf(s2, 0);
                  END;
                  IF ((NOT AppendLine(s, ProjectText))
                     OR (NOT AppendLine(s2, ProjectText))) THEN
                      ErrorFlag := TRUE;
                      RETURN
                  END;
          | 4  :  ReadStringBody(f,Length,PlannedProjectName);
          (* | 5  :  ReadStringBody(f,Length,HotLinkedProjectName); *)
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;
    Compress(ProjectText);

END GetProjectDetails;




PROCEDURE GetPrinterSettings(VAR f : File);
VAR
    Version,
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











PROCEDURE GetResources(VAR f:File);
VAR
    n, p            : CARDINAL;
    Resource        : AResourcePointer;
    LocalResource   : AResourcePointer;
    Node            : ATreeNode;
    LocalNode       : ATreeNode;
    Loop,
    Version,
    Length,
    Type,
    RecordLength    : CARDINAL;
    A1, A2          : ADDRESS;
    Avail           : AnAvailabilityRate;
    RsrcName        : ARRAY [0..ResourceNameLength] OF CHAR;
    NullName        : ARRAY [0..1] OF CHAR;

TYPE
    ACostPlace   =  (AllAtStart, AllAtEnd, ProRate, IgnoreIt);  (* 26-Jul-90 RSC *)

VAR
(*  Make a copy of a version 2 resource record and compile with the alignment
    setting on, so that this structure will match the one in the file.  (3/30/87 EGK)  *)
(*$A+*)
    Version2Record : RECORD
                        Tag         : CARDINAL;
                        Name        : ARRAY [0..ResourceNameLength] OF CHAR;
                        CostStyle   : ACostStyle;
                        CostPlace   : ACostPlace;
                        Type        : AResourceType;
                        Rate        : REAL;
                        Per         : ADuration;
                        Units       : ADurationUnit;
                        Limit       : REAL;
                        LongName    : ARRAY [0..31] OF CHAR;
                    END;
(*$A=*)

    PROCEDURE BuildCalendar( SpikeResource : AResourcePointer;
                             OldRate       : REAL;
                             OldPer        : ADuration );
    VAR RPer     : REAL;
        NewRate  : REAL;
    BEGIN

        CASE SpikeResource^.CostStyle OF
           CAmount         : NewRate := 1.0;
        |  CAmountRate     : NewRate := OldRate;
        |  CAmountRateTime : RPer := FLOAT(OldPer) / FSMUPH; (* Make into hours *)
                             IF (RPer <> Zero) THEN
                                 NewRate := OldRate / RPer;
                             ELSE
                                 NewRate := Zero;
                             END;
        ELSE
            FatalError();
        END;

        SpikeResource^.ActualRates := CreateRateList( NewRate, MINBIGTIME );

    END BuildCalendar;



    PROCEDURE WarnOfCostChange( VAR ResourceName : ARRAY OF CHAR;
                                    CostPlace    : ACostPlace );
    VAR
        s  : ARRAY [0..255] OF CHAR;
        s1,
        s2 : ARRAY [0..39]  OF CHAR;
    BEGIN
        Copy( ResourceName, s );
        ConcatMessage( s, ModuleNumber + 59 ); (* "'s costs were accumulated all at the ~" *)
        GetMessage( ModuleNumber + 60, s1 );   (* "start,end" *)
        WordNumber( s1, (ORD(CostPlace) + 1), s2 );  (* pick one *)
        ConcatLS( s, s2 );
        ConcatMessage( s, ModuleNumber + 61 ); (* ", but will become Pro-Rated..." *)
        GetMessage( ModuleNumber + 62, s1 ); (* "Not Pro-Rated" *)
        WarningBox( s, s1, NoHelp );
    END WarnOfCostChange;



BEGIN

    IF (NOT StartSubfileInput(f,ResourceType,Version)) THEN
        FileComplaint(f);
        RETURN;
    END;

    IF (NOT HeapAvailable()) OR (NOT CreateResource( LocalNode )) THEN
        TellOfNoMemory( AddingResources );
        ErrorFlag := TRUE;
        RETURN;
    END;

    LocalResource := LocalNode^.Methods^.GetDataObject (LocalNode);

    A1      := ADR(Version2Record);             (* 3/30/87 EGK *)
    A2      := ADR(Version2Record.LongName);
    RecordLength := A2.OFFSET - A1.OFFSET;

    LOOP
        IF (BreakRequested()) THEN
            RETURN;
        END;
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN
            FileComplaint(f);
            EXIT;
        END;
        CASE Type OF
            ResourceType:
                           ReadRecordBody(f,Length,A1,RecordLength);
                           ReadString(f,LocalResource^.LongName);

        (* Copy the necessary fields from the version 2 structure to the
            LocalResource record (which follows the version 5 format).  *)

                           WITH Version2Record DO
                                LocalResource^.Tag        := Tag;
                                Copy( Name, LocalResource^.Name );
                                LocalResource^.CostStyle  := CostStyle;
                                IF (CostPlace <> ProRate) THEN
                                    WarnOfCostChange( Name, CostPlace );
                                END;
                                LocalResource^.Type       := Type;
                                LocalResource^.LevelThisResource := (Type = Employable);
                                BuildCalendar( LocalResource, Rate, Per );
                                LocalResource^.Units      := Units;

                                IF (CostStyle = CAmountRateTime) THEN
                                    NullName[0] := 0C;
                                    NewPercent( NullName, Name,
                                                Limit,
                                                (9999.0 * 9.99), (* UpperLimit *)
                                                0.01,            (* LowerLimit *)
                                                9999,            (* Max n *)
                                                999,             (* Max % *)
                                                n, p );

                                    LocalResource^.UpperLimit   := 100.0;
                                    LocalResource^.UpperPercent := 100;

                                    (* 31-Jan-91 TGS *)
                                    IF (n <> DefaultAvailabilityAmount)  OR 
                                       (p <> DefaultAvailabilityPercent) THEN

                                        IF (p > 250) THEN
                                            p := 250;
                                        END;
                                        IF (n > 650) THEN
                                            n := 650;
                                        END;

                                        IF (n <> 0) THEN 
                                            IF ((MAXCARDINAL DIV n) < p) THEN
                                                p := MAXCARDINAL DIV n;
                                            END;
                                        END;

                                        Avail.Amount  := n;
                                        Avail.Percent := p;
                                        LocalResource^.Availability := CreateDateList (Avail, MINBIGTIME);

                                    END;
                                END;
                            END;

                            LocalResource^.FilteredIn := TRUE;
                           (*
                           RenameIfAppropriate(LocalResource^.Name,IsAResourceName);
                           *)

                           Copy(LocalResource^.Name,RsrcName);
                           Message(RsrcName);

                           Node := FindResourceByName(RsrcName);
                           IF (Node = NIL) THEN
                               IF (CreateResource (Node)) THEN
                                   CopyResourceNode(LocalNode, Node, FALSE);
                                   AddResource (Node, NIL, NIL);
                                   ChangedResource (Node);
                               ELSE (* Probably out of heap space. *)
                                   ErrorFlag := TRUE;
                                   TellOfNoMemory( AddingResources );
                                   EXIT;
                               END;
                           ELSE
                               FatalError(); (* Dup rsrc found ! *)
                           END;
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

    DeleteResource(LocalNode); (* Free up ALL space taken by this cretin *)

END GetResources;








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
END SanitizeTask;







PROCEDURE GetTasks(VAR f : File);

CONST MaxAssignmentsPerTask = 18; (* Max in Version 2 *)

VAR
        (*  Align this like vers. 1 of the compiler, or it won't work.  *)
    (*$A+*)
    vers2task : RECORD
                    rectag: [0..255];
                    priority: CARDINAL;
                    fixation: AFixType;
                    schedstart,
                    earlystartdate,
                    freelateend,
                    lateenddate : ADate;
                    duration: ADuration;
                    scale:ADurationUnit;
                    TaskFlags : ATaskFlagSet;
                    StartStatus : AStartStatus;
                    status,
                    status2: CHAR;
                    rollupstatus : ARollupStatus;
                    taskname: ATaskName;
                    datestring: ARRAY [0..17] OF CHAR;  (* Text as entered. *)
                    notes : ARRAY [0..60] OF CHAR;
                    notes2 : ARRAY [0..60] OF CHAR;
                    summarizes : ARRAY [0..14] OF CHAR; (* other file name. *)
                    FilteredIn  : BOOLEAN;
                    X,Y      :   CARDINAL;
                    count,
                    count2 : CARDINAL;
                    ResourceList : AResourceNodePointer;
                    antetasks: AnEdgePtr;  (* List of tasks that must
                                           precede this one. *)
                    desctasks: AnEdgePtr;  (* List of tasks that must follow
                                           this one. *)
                    prevlink: ATaskPtr;  (* Prior task. *)
                    nextlink: ATaskPtr;  (* Next task. *)
                END;

    TotalTaskCount,
    MaxReadCount        : CARDINAL;
   count, RecordsInFile : CARDINAL;
    i, j, n, p          : CARDINAL;
    Version             : CARDINAL;
    TaskRecordLength    : CARDINAL;
    Type                : CARDINAL;
    Length              : CARDINAL;
    A1, A2              : ADDRESS;
    Node                : ATreeNode;
    Amount              : REAL;
    R                   : REAL;
    CountOfAssignments  : CARDINAL;
    NewTaskRec          : ATask;
    AssignmentArray     : ARRAY [1..MaxAssignmentsPerTask] OF Assignments.AnAssignmentRecord;
    s                   : ARRAY [0..255] OF CHAR;
    s1, s2              : ARRAY [0..39]  OF CHAR;
    SummariesNotWarned  : BOOLEAN;
    SpansNotWarned      : BOOLEAN;
    HaveATask           : BOOLEAN;
    DuplicateAssignments: BOOLEAN;
    Found               : BOOLEAN;
    (*$A=*)



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



    PROCEDURE AddIt() : ATreeNode;
    VAR
        AddedTask    : ATreeNode;
        AddedTaskPtr : ATaskPtr;
    BEGIN
         AddedTask := CreateTask();
         IF (AddedTask = NIL) THEN
              ErrorFlag := TRUE;
              TellOfNoMemory( AddingTasks );
              RETURN NIL;
         ELSE
             AddedTaskPtr  := AddedTask^.Methods^.LockFlexStorDataObject(AddedTask);
             AddedTaskPtr^ := NewTaskRec;
             SanitizeTask ( AddedTaskPtr );  (* 25-Jan-91 RSC *)
             AddedTask^.Methods^.UnlockFlexStorDataObject(AddedTask);
             AddTask (AddedTask, NIL, TaskTree^.Methods^.GetLast(TaskTree));
         END;
         INC(TotalTaskCount);
         RETURN AddedTask;
    END AddIt;



    PROCEDURE SetTaskStatus( VAR Set : ATaskStatusSet; old : CHAR );
    BEGIN
        CASE old OF
          "C" : INCL( Set, Critical         );
        | "P" : INCL( Set, PartialJoinPrior );
        | "R" : INCL( Set, ResourceOverload );
        | "r" : INCL( Set, ResourceConflict );
        | "L" : INCL( Set, Loop             );
        | "?" : INCL( Set, NeedsRecalculate );
        ELSE
          (* Else what? *)
        END;
    END SetTaskStatus;




        (*  This procedure adjusts for differences in the record structure
            from vers. 2 to vers. 5.                                        *)

    PROCEDURE CopyVers2Task();
    VAR
    BEGIN                   (* CopyVers2Task *)
        WITH vers2task DO
            NewTaskRec.rectag    := rectag;
            NewTaskRec.priority  := priority;
            IF (priority > MaxPriority) THEN
                MaxPriority := priority;
            END;
            CalendarTimeToBigTime( schedstart, TRUE, NewTaskRec.UserEnteredStartDate );  (* 12-Sep-90 RSC *)
            NewTaskRec.SupposedToStart           :=  NewTaskRec.UserEnteredStartDate;    (*  2-Oct-90 RSC *)
            NewTaskRec.fixation                  := fixation;
            NewTaskRec.Plan.Dates.EarlyStart     := earlystartdate;
            NewTaskRec.Plan.Dates.EarlyEnd       := earlystartdate + duration;
            NewTaskRec.Plan.Dates.LateFreeStart  := freelateend - duration;
            NewTaskRec.Plan.Dates.LateFreeEnd    := freelateend;
            NewTaskRec.Plan.Dates.LateTotalEnd   := lateenddate;
            NewTaskRec.Plan.Dates.LateTotalStart := lateenddate - duration;
            NewTaskRec.duration                  := duration;
            NewTaskRec.scale                     := scale;
            NewTaskRec.EffortScale               := scale;
            CalendarTimeToBigTime( NewTaskRec.Plan.Dates.EarlyEnd, FALSE, NewTaskRec.UserEnteredEndDate );  (* 12-Sep-90 RSC *)

            NewTaskRec.TaskFlags                 := TaskFlags *
                    ATaskFlagSet{DeferAlarms,TaskRecentlyAdded,IsHeadNode};     (* 3/7/88 EGK *)

            INCL(NewTaskRec.TaskFlags,PlanExists);
            NewTaskRec.StartStatus               := StartStatus;
            NewTaskRec.TaskStatusSet             := ATaskStatusSet( {} );
            SetTaskStatus( NewTaskRec.TaskStatusSet, status  );
            SetTaskStatus( NewTaskRec.TaskStatusSet, status2 );
            NewTaskRec.rollupstatus              := rollupstatus;
            Copy( taskname, NewTaskRec.taskname );
        END;

        WITH NewTaskRec DO
            IF StartStatus = DoneS THEN
               PercentComplete := 100;
            ELSE
               PercentComplete := 0;
            END;
            TaskID := 0;
        END;

    END CopyVers2Task;


        (* CopyAndTrim -- Copy the characters in s up to a slash
                          to To, and remove those characters.
                          *)

    PROCEDURE CopyAndTrim( VAR s  : ARRAY OF CHAR;
                           VAR To : ARRAY OF CHAR );
    VAR
        i,j : CARDINAL;
        s1  : ARRAY [0..1] OF CHAR;
    BEGIN
        SetString(s1,"/");
        i := Search(s,s1,1);
        IF (i = 0) THEN
            j := ORD(s[0]);
        ELSE
            j := i-1;
        END;

        IF (j > HIGH(To)) THEN
            j := HIGH(To);
        END;

        SubStr(s,To,1,j);

        IF (i > 0) THEN
            Remove(s,1,i);
        ELSE
            SetLengthOf(s,0);
        END;
    END CopyAndTrim;



    PROCEDURE CopyNotes( VAR s : ARRAY OF CHAR;
                             Option : CARDINAL   );
    VAR
        s2              : ARRAY [0..50] OF CHAR;
    BEGIN
        WITH NewTaskRec DO
            CASE Option OF
            | 0 :
            | 1 :
                CopyAndTrim (s, s2);
                SetCodingField (NewTaskRec, WBSLine, s2);
            | 2 :
                CopyAndTrim (s, s2);
                SetCodingField (NewTaskRec, OBSLine, s2);
            | 3 :
                CopyAndTrim (s, s2);
                SetCodingField (NewTaskRec, AUXLine, s2);
            ELSE FatalError();
            END;

            IF (LengthOf(s) > 0) THEN
                IF (NOT TextExists(notes)) THEN
                    notes := CreateText();
                    IF (NOT TextExists(notes)) THEN
                        ErrorFlag := TRUE;
                        TellOfNoMemory( AddingTasks );
                        RETURN;
                    END;
                END;
                IF (NOT AppendLine(s, notes)) THEN
                    ErrorFlag := TRUE;
                    TellOfNoMemory( AddingTasks );
                    RETURN;
                END;
            END;
        END;
    END CopyNotes;




    PROCEDURE SaveRemainders;
    VAR Loop    : CARDINAL;
        Context : ADDRESS;
        NewNode : ATreeNode;
    BEGIN
        Compress(NewTaskRec.notes);
        IF CountOfAssignments > 0 THEN

           (* Do this here in case we do not know the start status when we
              are getting resources. *)

            IF NOT (NewTaskRec.StartStatus = DoneS) THEN
                FOR Loop := 1 TO CountOfAssignments DO
                    WITH AssignmentArray[ Loop ] DO
                        YetToGoQuantity := ActualQuantity;
                        ActualQuantity  := Zero;
                    END;
                END;
            END;

            NewTaskRec.Plan.Assignments := AnExtHandle(NIL);
            IF (GetExtStatus() = ExtGood) AND            (* 21-Aug-89 RSC *)
               (CreateExtObject(  NewTaskRec.Plan.Assignments,
                                  ExtMedium    ) AND
                SetExtData(       NewTaskRec.Plan.Assignments,
                                  ADR( AssignmentArray ),
                                  ArraySize( CountOfAssignments,
                                             TSIZE(Assignments.AnAssignmentRecord) ))) THEN
            ELSE
                ErrorFlag := TRUE;
                TellOfNoMemory( AddingTasks );
                IF (NewTaskRec.Plan.Assignments <> AnExtHandle(NIL)) THEN
                    DiscardExtObject( NewTaskRec.Plan.Assignments );
                END;
                RETURN;
            END;
        END;
        NewNode := AddIt();
        IF (ADDRESS(NewNode) = NIL) THEN
            RETURN;
        END;
        IF (NewTaskRec.fixation = Span) THEN
            IF (SpansNotWarned) THEN
                GetMessage(ModuleNumber + 44,s);  (* "convert v2 summaries to v3" *)
                GetMessage(ModuleNumber + 45,s1); (* "V2 Linked tasks" *)
                WarningBox(s,s1,OfferHelp);
                SpansNotWarned := FALSE;
            END;
            SplitSpanTask(NewNode); (* We don't like Spans. *)
        END;

    END SaveRemainders;




    (* For span tasks, we need to make kids on the fly.  See 'SplitSpan' *)

    PROCEDURE MakeATask(     SpanNode  : ATreeNode;
                         VAR KidNode   : ATreeNode;
                             PriorTask : ATreeNode;
                             First     : BOOLEAN );
    VAR
        KidTask     : ATaskPtr;
        Msg         : CARDINAL;
        FixedStart  : ADate;
    BEGIN
        KidNode := CreateTask();
        IF (KidNode = NIL) THEN
            ErrorFlag := TRUE;
            RETURN;
        END;
        KidTask := KidNode^.Methods^.LockFlexStorDataObject( KidNode );
        WITH KidTask^ DO
            IF (First) THEN
                Msg      := 42;  (* "Span Task Start" *)
                fixation := ASAP;
                FixedStart := NewTaskRec.Plan.Dates.EarlyStart;
            ELSE
                Msg      := 43;  (* "Span Task End" *)
                fixation := ALAP;
                FixedStart := NewTaskRec.Plan.Dates.EarlyEnd;
            END;
            CalendarTimeToBigTime( FixedStart, TRUE, UserEnteredStartDate );  (* 12-Sep-90 RSC *)

            GetMessage(ModuleNumber + Msg, taskname); (* "Span Task Start/End" *)
            scale        := NewTaskRec.scale;
            EffortScale  := NewTaskRec.EffortScale;
            priority     := NewTaskRec.priority;
            StartStatus  := NewTaskRec.StartStatus;
        END;
        KidNode^.Methods^.UnlockFlexStorDataObject( KidNode );
        AddTask (KidNode, SpanNode, PriorTask);
    END MakeATask;




    (* Split Span Task - We have a V2 span task that we can't handle in V3.
       Split it into a mom and two kids.  The first kid is an ASAP milestone
       with all the predecessors attached to it.  The second kid is an ALAP
       milestone with all the successors attached to it.  The mom keeps all
       notes text and resource assignments, however.

       In this pass, we keep its fixation as Span so that the GetEdges routine
       can resolve edges easily.
    *)
    PROCEDURE SplitSpanTask( SpanNode : ATreeNode );
    VAR
        FirstKid,
        LastKid   : ATreeNode;
    BEGIN
        IF (ErrorFlag OR (SpanNode = NIL)) THEN RETURN; END;
        NewTaskRec.fixation := ASAP; (* Change away from SPAN *)
        MakeATask( SpanNode, FirstKid, NIL, TRUE  );
        IF (ErrorFlag) THEN RETURN; END;
        MakeATask( SpanNode, LastKid, FirstKid, FALSE );
        IF (ErrorFlag) THEN
            DelTask( FirstKid ); (* Delete first kid, 'cause second didn't make it *)
            RETURN;
        END;
        SpanNode^.Methods^.SetAttributeBit (SpanNode, SpanFlag, TRUE);      (* 3/7/88 EGK *)
        SpanNode^.Methods^.SetChildrenVisible( SpanNode, FALSE );
    END SplitSpanTask;


BEGIN
    MaxPriority         := 0;  (* Largest we have seen so far. *)
    SummariesNotWarned  := TRUE;
    SpansNotWarned      := TRUE;
    DuplicateAssignments:= FALSE;

    MaxReadCount        := GetMaxReadCount();
    TotalTaskCount      := 0;


        (* We need to find out how many time units there are per
           hour in the incoming file, in order to scale the incoming
           durations to the current calendar. *)

    HaveATask := FALSE;

        (* Compute the length of the fixed storage part of the
           task record.   *)

    A1      := ADR(vers2task);
    A2      := ADR(vers2task.X);
    TaskRecordLength := A2.OFFSET - A1.OFFSET;


    IF (NOT StartSubfileInput(f,TaskType,Version)) THEN
        FileComplaint(f);
        RETURN;
    END;

    CountOfAssignments := 0;

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
            TaskType:    IF (HaveATask) THEN
                             SaveRemainders();
                             HaveATask := FALSE;
                             IF (ErrorFlag) THEN
                                 RETURN;
                             END;
                         END;

                         IF (TotalTaskCount >= MaxReadCount) THEN
                             GetMessage(ModuleNumber+36,s);     (* You have too many tasks *)
                             GetMessage(ModuleNumber+37,s1);    (* Too many tasks *)
                             WarningBox( s, s1, OfferHelp );
                             EXIT;
                         END;

                         InitializeTaskRecord( NewTaskRec );
                         ReadRecordBody(f,Length,A1,TaskRecordLength);
                         CopyVers2Task();
                         WITH NewTaskRec DO
                             summarizes := AText(NIL);
                             Copy(taskname,s);
                             Message(s);
                             IF (rollupstatus <> NotRollup) THEN
                                 rollupstatus := RollupNotLoaded;
                             END;
                             EXCL(TaskFlags,DeferAlarms);        (* Enable alarm clock. *)
                         END;
                         CountOfAssignments := 0;
                         INC(count);
                         HaveATask := TRUE;
          | NotesType :
                        ReadStringBody(f, Length, s);
                        CopyNotes(s,Notes1Copy);
          | Notes2Type :
                        ReadStringBody(f, Length, s);
                        CopyNotes(s,Notes2Copy);
          | SummarizesType :
                        IF (Length > 1) THEN
                            IF (SummariesNotWarned) THEN
                                GetMessage(ModuleNumber + 40,s);  (* "convert v2 summaries to v3" *)
                                GetMessage(ModuleNumber + 41,s1); (* "V2 Linked tasks" *)
                                WarningBox(s,s1,OfferHelp);
                                SummariesNotWarned := FALSE;
                            END;
                            ReadStringBody(f, Length, s);
                            ConcatS(s,".5T0"); (* Convert to version 5 *)
                            WITH NewTaskRec DO
                                IF (fixation <> Span) THEN
                                    summarizes := CreateText();
                                    IF (ADDRESS(summarizes) = NIL) THEN
                                        TellOfNoMemory( AddingTasks );
                                        ErrorFlag := TRUE;
                                        EXIT;
                                    END;
                                    SetString(s1,"TLROLLEM"); (* Overlay to call *)
                                    SetString(s2,"0");        (* Version/Type number *)
                                    IF (NOT ((AppendLine(s1, summarizes))    AND
                                             (AppendLine(s2, summarizes))    AND
                                             (AppendLine(s,  summarizes))))  THEN
                                        TellOfNoMemory( AddingTasks );
                                        ErrorFlag := TRUE;
                                        EXIT;
                                    END;
                                    Compress(summarizes);
                                END;
                            END;
                        ELSE
                            SkipRecordBody(f,Length);
                        END;
          | TaskType+1:
                         ReadRecordBody(f,Length,ADR(Amount),SIZE(Amount));
                         ReadString(f,s);  (* Resource Name *)
                         Node := FindResourceByName(s);
                         IF (Node <> NIL) THEN
                             i     := 1;
                             Found := FALSE;
                             WHILE (i <= CountOfAssignments) AND (NOT Found) DO
                                 Found := (AssignmentArray[ i ].Resource =
                                           Node^.Methods^.GetDataObject(Node));
                                 INC(i); (* 21-Jun-91 TGS *)
                             END;
                             IF (Found) THEN
                                 DuplicateAssignments := TRUE;
                             ELSE
                                 INC(CountOfAssignments);
                                 WITH AssignmentArray[ CountOfAssignments ] DO
                                     Resource   := Node^.Methods^.GetDataObject (Node);
                                     Attributes := Assignments.AnAssignmentAttributeSet{Assignments.Billable};
                                     IF (Resource^.Type = Employable) THEN
                                         INCL(Attributes,Assignments.AllowLevel);
                                     END;
                                     ActualTimeUnits := NewTaskRec.scale;
                                     Expenses        := AnExtHandle(NIL);

                                         (* 10-Jul-91 TGS *)
                                     VaryingAssignment := AnExtHandle(NIL);
                                     OvertimeHours  := 0L;
                                     YetToGoOvertimeHours   := 0L;
                                     ExtraCosts     := Zero;

                                     YetToGoQuantity := Zero;
                                     IF (Resource^.CostStyle = CAmountRateTime) THEN
                                         IF (Resource^.Type = Employable) THEN
                                             p := Resource^.Percent;
                                             n := TRUNC(Resource^.Limit / FLOAT(p));
                                         ELSE
                                             p := 250;  (* RSC 2/12/88 - for VC's we don't care. *)
                                             n := 650;
                                         END;
                                         NewPercent( NewTaskRec.taskname,
                                                     Resource^.Name,
                                                     Amount,
                                                     655.0,   (* UpperLimit *)
                                                     Zero,    (* LowerLimit *)
                                                     n, p,    (* Suggested limits *)
                                                     n, p );
    
                                         MaxRatePercent  := n * p;
                                         PercentageEach  := CHR(p);
                                         ActualQuantity  := (FLOAT(NewTaskRec.duration) *
                                                             FLOAT(MaxRatePercent))     /
                                                             (FSMUPH * OneHundred);
                                     ELSE
                                         ActualQuantity  := Amount;
                                         PercentageEach  := CHR(100);
                                         MaxRatePercent  := 0;
                                     END;
                                 END;
                             END;
                         ELSE
                             ConcatMessage(s,ModuleNumber+13);   (*  " is not available as a resource."  *)
                             Message(s);
                         END;
       | 0FFH : EXIT;
            ELSE      SkipRecordBody(f,Length);
        END;
    END;

    IF (HaveATask) THEN
        SaveRemainders();
    END;


    IF (DuplicateAssignments) THEN
        ErrorPhrase( ModuleNumber );
    END;

    Loaded := (NOT ErrorFlag);

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
    Message(note);
END NoteEdge;













PROCEDURE GetEdges(VAR f : File);
TYPE
        (*$A+*)
    AnEdgeFromFile = RECORD
                 rectag : CARDINAL;
                 FromOffset,
                 ToOffset  :  RECORD
                                  Start : BOOLEAN;
                                  Plus  : BOOLEAN;
                                  Dur   : ADuration;
                                  Scale : ADurationUnit;
                              END;
            END;
        (*$A=*)
VAR
    Task1, Task2         : ATreeNode;
    TaskPtr              : ATaskPtr;
    EdgePtr              : AnEdgePtr;
    count, i,
    Version,
    RecordLength,
    Length,
    Type                 : CARDINAL;
    k                    : INTEGER;
    EdgeFromFile         : AnEdgeFromFile;
    taskname1, taskname2 : ATaskName;
    s                    : ARRAY [0..81] OF CHAR;


    PROCEDURE CannotFind(VAR name:ARRAY OF CHAR);
    VAR
        s : ARRAY [0..81] OF CHAR;
    BEGIN
        GetMessage(ModuleNumber+1,s);   (*  "While loading joins, I can't find "  *)
        ConcatLS(s,name);
        ConcatS(s,'. ');
        Message(s)
    END CannotFind;

BEGIN
    IF (NOT StartSubfileInput(f,EdgeType,Version)) THEN
        FileComplaint(f);
        RETURN;
    END;

    RecordLength := TSIZE(AnEdgeFromFile);

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

          | 0:         ReadStringBody(f,Length, taskname1 );

          | 1:         ReadStringBody(f,Length, taskname2 );

                       Task1 := FindTask(taskname1);
                       Task2 := FindTask(taskname2);

                       IF (Task1 = NIL) THEN
                           CannotFind(taskname1);
                       ELSIF (Task2 = NIL) THEN
                           CannotFind(taskname2);
                       ELSE
                           EdgePtr := FindEdge(Task1,Task2);
                           IF (EdgePtr <> NIL) THEN
                               GetMessage (ModuleNumber+73, s);
                               Error (s);
                           END;
                           EdgePtr := CreateEdge (Task1, Task2);
                           IF (EdgePtr <> NIL) THEN
                               EdgePtr^.FromOffset.Start := EdgeFromFile.FromOffset.Start;
                               EdgePtr^.FromOffset.Plus  := EdgeFromFile.FromOffset.Plus;
                               EdgePtr^.FromOffset.Dur   := EdgeFromFile.FromOffset.Dur;
                               EdgePtr^.FromOffset.Scale := EdgeFromFile.FromOffset.Scale;
                               EdgePtr^.ToOffset.Start := EdgeFromFile.ToOffset.Start;
                               EdgePtr^.Type := Flexible;
                               EdgePtr^.Attributes := ASetOfEdgeAttributes{};
                               NoteEdge(taskname1,taskname2);

                           ELSE
                                   (* If we failed for some reason other than that the
                                      dependency already exists (we may be combining),
                                      then it is serious. *)
                               TellOfNoMemory( AddingEdges );
                               ErrorFlag := TRUE;
                               EXIT;
                           END;
                                (* Recompute the net effect of partial dependencies.  *)
                           k := NoDuration;
                                (*  Partial join from. *)
                           WITH EdgePtr^.FromOffset DO
                               IF (Start) THEN
                                   TaskPtr := Task1^.Methods^.LockFlexStorDataObject (Task1);
                                   DEC(k,TaskPtr^.duration);
                                   Task1^.Methods^.UnlockUnchangedDataObject (Task1);
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
                                   TaskPtr := Task2^.Methods^.LockFlexStorDataObject (Task2);
                                   DEC(k,TaskPtr^.duration);
                                   Task2^.Methods^.UnlockUnchangedDataObject (Task2);
                               END;
                           END;
                           EdgePtr^.Delta := k;            (* Jason Bourne *)

                            (* If we are joining from the start or to the end
                               of a former span task, change the edge to point
                               to the appropriate kid milestone instead.  (3/7/88 EGK)  *)

                           IF (Task1^.Methods^.TestAttributeBit (Task1, SpanFlag)) AND
                                     (EdgePtr^.FromOffset.Start) THEN
                                EdgePtr^.headtask := Task1^.Methods^.FirstChild (Task1);
                           END;
                           IF (Task2^.Methods^.TestAttributeBit (Task2, SpanFlag)) AND
                                     (NOT EdgePtr^.ToOffset.Start) THEN
                                EdgePtr^.tailtask := Task2^.Methods^.LastChild (Task2);
                           END;

                           AddEdge (EdgePtr, FALSE);

                       END;
          | 0FFH     : EXIT;  (* End of subfile *)
            ELSE       SkipRecordBody(f,Length);
        END;



    END;
END GetEdges;








PROCEDURE ReadTaskName(VAR f:File; Length : CARDINAL; VAR Task:ATreeNode);
VAR
    Name : ATaskName;
BEGIN
    ReadStringBody(f,Length,Name);
    Task := FindTask(Name);
END ReadTaskName;








PROCEDURE GetBugs(VAR f:File);
VAR
    Length, Version, Type      : CARDINAL;

        (*  This is in here because the format of dates in a Time Line 2.0
            file is incompatible with ReadDate, as used in Plot Line.       *)

    PROCEDURE ReadFormattedDate(VAR F       : File;                (* LAA 11/03/86 *)
                                    Length  : CARDINAL;
                                VAR Date    : ADate);

    VAR
        s                   : ARRAY [0..80] OF CHAR;

    BEGIN                   (* ReadFormattedDate *)

        ReadRecordBody(F, Length, ADR(s), HIGH(s));
        IF CheckIO(F) <> done THEN
            FileComplaint(F);
            RETURN;
        END;
        IF NOT StoTimeU(s, Date) THEN
            ConcatMessage(s, ModuleNumber + 30);
            Error(s);
        END;
    END ReadFormattedDate;


BEGIN
    IF (NOT StartSubfileInput(f,BugsType,Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
            1  :  ReadTaskName(f,Length,BugTaskA);
          | 2  :  ReadFormattedDate(f,Length,BugDayA);
          | 3  :  ReadTaskName(f,Length,BugTaskB);
          | 4  :  ReadFormattedDate(f,Length,BugDayB);
          | 100:  ReadTaskName(f,Length,CursorTask);
          | 101:  ReadFormattedDate(f,Length,CursorDay);
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;
END GetBugs;



 (* Handle version 2 span tasks and ajusting priority.

    Priority:  Under SPIKE, Priority (a CARDINAL) is interpreted on the
               Task Form as a REAL number, or FLOAT(priority) / 10.0.
               A version 2 priority of, say, 3 would come out as 0.3.
               If they did not have priorities in the thousands, we will
               shift the pri up by 10 so '3' will show as '3' on the form.
 *)

PROCEDURE HandlePri( VAR TaskNode : ATreeNode;
                         Context  : ADDRESS );
VAR
    FirstKid,
    LastKid   : ATreeNode;
    Task      : ATaskPtr;


BEGIN
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    WITH Task^ DO
        priority := priority * 10; (* Ajust all priorities *)
    END;
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
END HandlePri;





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
    LayoutTree^.Methods^.TraverseTree (LayoutTree, ParentBeforeChild,
            9999, RecomputeLayoutScale, NIL);
    RecomputeLayoutScale (DefaultChartFormat, NIL);

END CalendarUpdate;





    (* These constants control the order and choice of subfiles
       read.  Their order is important so as to assure that
       data is available before it is referenced by another
       subfile. *)
CONST
    HLD   =  0;
    ENV   =  1;
    CAL   =  2;
    SIG   =  3;
    PRJ   =  4;
    RES   =  5;
    TSK   =  6;
    EDG   =  7;
    PRT   =  8;
    BUG   =  9;





PROCEDURE GetProjectFile(VAR Directory   : ARRAY OF CHAR;
                         VAR FileName    : ARRAY OF CHAR;
                             RetrieveSet : BITSET
                         ) : BOOLEAN;
VAR
    i,j,Month,
    Version            : CARDINAL;
    DummyAddress       : ADDRESS;
    f                  : File;
    C                  : CHAR;
    s                  : ARRAY [0..255] OF CHAR;
    Description        : ARRAY [0..1] OF CHAR;
    ok                 : BOOLEAN;


BEGIN
    SetLengthOf(Description,0);
    IF (NOT RequestFileOpen(Directory,FileName,Description,f) ) THEN
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
        IF (i > 15) THEN
            EXIT;
        ELSIF (i IN RetrieveSet) THEN
            CASE i OF
                HLD:  GetHeldItems(f);
              | ENV:  GetTheEnvironment(f);
              | CAL:  BeforeCalendarChange();
                      GetCalendar(f);
                      CalendarUpdate();
              | SIG:  AsOfDate := FindToday();
                      GetSignature(f);
              | PRJ:  GetProjectDetails(f);
              | RES:  GetResources(f);
              | TSK:  GetTasks(f);
              | EDG:  GetEdges(f);
              | PRT:  GetPrinterSettings(f);
              | BUG:  GetBugs(f);
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

    (* If the max priority read in was less than 1000, bump all priorities
       up by a factor of 10 to allow for the new scheme of 0.0 to 999.9
    *)
    IF (MaxPriority < 1000) THEN
        TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
                                         HandlePri,
                                         DummyAddress);
    END;

    Close(f);

        (* 1-Jul-91 TGS Andrew's changes to remove fiscal calendars: *)
        (* Because a fiscal year may require a change to the date format,
           we need to cancel it and warn the user to restore it. *)
    GetStartingMonth(Month);
    IF (Month <> Jan) THEN
        ErrorPhrase(12477);
        SetStartingMonth(Jan);
    END;

    RETURN ok AND (NOT ErrorFlag);

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
    RetrieveSet        : BITSET;

BEGIN
    SetDefaultOptions();

    IF (NOT GetOptions()) THEN
        RETURN FALSE;
    END;

    RetrieveSet := {HLD,ENV,PRJ,CAL,SIG,RES,TSK,EDG,BUG,PRT};

    UnSetState(Sorted);
    UnSetState(Filtered);
    UnSetState (Scheduled);     (* So many differences between version
                                   2 and version 5, we should just recompute. *)

    ClearColumnNames();         (* 31-Oct-90 PFG *)

    RETURN GetProjectFile(Directory,FileName,RetrieveSet);

END LoadOneFile;







PROCEDURE GetOptions() : BOOLEAN;
VAR
    i       : CARDINAL;
    Context : ARRAY [0..3] OF CARDINAL;
    s       : ARRAY [0..29] OF CHAR;
    ok      : BOOLEAN;
BEGIN                       (* GetFileName *)
    SetString(s, "\TLFBASE(TL2FORM)" );                           (* 02-Mar-88 LAA *)

    FOR i := 0 TO 3 DO
        Context[i] := 0
    END;

    ok := CallOverlayWithContext( s, ADR(Context) );

    Notes1Copy := Context[1];
    Notes2Copy := Context[2];

    RETURN (ok AND (Context[0] <> 0));

END GetOptions;


  (* In version 3, task and resource names cannot have these charactors:

           \, ^, *, or [.

  *)
PROCEDURE AjustName( VAR NewName : ARRAY OF CHAR );
VAR
    Loop : CARDINAL;
    C    : CHAR;

    PROCEDURE NotifyOfNameChange();
    VAR
        s : ARRAY [0..255] OF CHAR;
    BEGIN
        IF (NOT GNotifiedNameChange) THEN
            GNotifiedNameChange := TRUE;
            GetMessage( ModuleNumber + 74, s ); (* "Fixed names." *)
            Error(s);
        END;
    END NotifyOfNameChange;

BEGIN
    FOR Loop := 1 TO ORD(NewName[0]) DO
        C := NewName[ Loop ];
        IF ((C = "\") OR
            (C = "^") OR
            (C = "*") OR
            (C = "]") OR
            (C = "["))  THEN
            NotifyOfNameChange();
            NewName[ Loop ] := "-";    (* Give 'em a replacement char. *)
        END;
    END;
END AjustName;


(******************************************************  01-Aug-89 WKH

PROCEDURE NumberAndFixTheTask( VAR Node      : ATreeNode;
                                   Context   : ADDRESS   );
VAR
    TaskPtr             : ATaskPtr;
BEGIN
    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    WITH TaskPtr^ DO
        TaskID := NewID();
        AjustName( taskname );
    END;
    Node^.Methods^.UnlockFlexStorDataObject (Node);
END NumberAndFixTheTask;




PROCEDURE NumberAndFixTheResource     ( VAR Node      : ATreeNode;
                                      Context   : ADDRESS   );
VAR
    ResourcePtr             : AResourcePointer;
BEGIN
    ResourcePtr := Node^.Methods^.GetDataObject (Node);
    WITH ResourcePtr^ DO
        ID := NewID();
        AjustName( Name );
    END;
END NumberAndFixTheResource;




PROCEDURE RenumberEverything();

BEGIN

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentAfterChild, 9999,
        NumberAndFixTheTask, NIL);
    ResourceTree^.Methods^.TraverseTree (ResourceTree, ParentAfterChild, 9999,
        NumberAndFixTheResource, NIL);

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

    ok := LoadOneFile( Device, FileName );

END ReadInFile;







BEGIN
    NoteMessage[0] := 0C;
    P := OverlayContext();
    GNotifiedNameChange := FALSE;

    IF (NOT HeapAvailable()) THEN
        TellOfNoMemory( StartingUp );
        P^[1] := "0";                   (* This is the error signal *)
        RETURN;
    END;

    ErrorFlag  := FALSE;
    Notes1Copy := 0;
    Notes2Copy := 0;
    InferIndentation := FALSE;

    CursorDay := AsOfDate; (* RSC 5/14/87 *)

    ReadInFile;

    RenumberEverything();

    IF (GanttChart^.Methods^.GetCursorNode(GanttChart) = NIL) THEN (* 22-Jun-87 LAA *)
        Node := TaskTree^.Methods^.GetFirst(TaskTree);
        GanttChart^.Methods^.SetFirst(GanttChart, Node);
        GanttChart^.Methods^.SetCursorNode(GanttChart, Node);
    END;

    IF (ErrorFlag) THEN                                 (* 3/3/88 EGK *)
        P^[1] := "0";
    ELSE
        P^[1] := "1";
    END;


    (* CalculationState[Scheduling].When := ManualCalc; *)   (* Debugging *)

END TLITL2.
