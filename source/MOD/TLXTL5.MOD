MODULE TLXTL5;

(*  =========================================================================
    Last Edit : May 30, 1991 9:57AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Save config file.

    MODIFICATION HISTORY:

       30-Mar-90 RSC    Made Timeu to Timei/TimeForm conversions.
       18-Apr-90 KKC    Cleaned all unused imports.
       19-Apr-90 KKC    Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
       29-May-90 AJL  - Use the Filing.AStoreProc and the RateList module 
                        to store rate lists.
       29-Jun-90 AJL  - Removed the tests of AnxietyLevel (needed to remove
                        some imports because of symbol table overflow. 
                      - Ditto on Keys.PlotGantt.
        8-Aug-90 RSC  - Minor cleanups; add new resource fields to save/load.
       15-Aug-90 RSC  - Ajust version number and other tweaks to make reading
                        work.
       17-Aug-90 RSC  - Ajust storing context so it saves file handle.
        5-Sep-90 RSC  - Save and load assignment record contents.
                        Moved Resource saving to XResource because the
                        symbol table became full.
       12-Sep-90 RSC  - Fixed for new Allocs.Def
       17-Sep-90 RSC  - Import the file extension rather than hardcoding it.
       26-Oct-90 PFG    Add a constant for ColumnNamesType.
       29-Oct-90 PFG    Changed ShowSched() call to DisplayTheChart() for
                        Andrew.
       12-Nov-90 RSC  - Save Edge Dur's independantly of SMUPHs, so we
                        can COMBINE schedules of differing precisions.
       10-Jan-91 AJL  - Store all texts with new record type numbers because
                        their formats are different.
       21-Jan-91 RSC  - Remove Fiscal Calendars.
       13-Feb-91 RSC  - Change call to RegSupport.
        2-Apr-91 TGS    Rename this TLXTL5, from TLXTL45.
       10-Apr-91 AJL  - Use the DataFiles module for subfile numbers.
                      - Store the number of objects of several types.
                      - Use a thermometer to show progress while saving tasks.
                      - Don't display anything during saving edges.
       26-Apr-91 AJL  - Actually count the number of tasks and resources stored
                        into the file.  During a file extract, not all tasks 
                        or resources are actually stored.
       29-Apr-91 RSC  - Adjusted the EDGE storing to save hours and minutes,
                        rather than hours and (minutes/SMU).
       20-May-91 AJL  - Only set the ScheduleSaved flag if the user is saving
                        the schedule file to its normal name.  A file save 
                        Make Copy command will not affect the flag; neither
                        will a failed attempt to save the schedule.  Fixes
                        bug 4435.
       30-May-91 AJL  - Only put up progress box when we are ACTUALLY going
                        to save the schedule, as opposed to when we save
                        the CONFIG FILE ONLY.  Also, put in an expand path
                        to help insure that the name compare to determine if
                        this is a /File,Save,Replace works right.  Bug 4463.
       25-Feb-92 AJL  - When converting dates to big times for storage into
                        the file, do not treat end dates specially.  Treat
                        them as start dates (parameter to CalendarTimeToBigTime)
                        so that the end date format is independent of the format
                        setting on the calendar settings form, and the end date
                        is >= start date.
    =========================================================================
*)



FROM Allocs       IMPORT
    (* TYPE  *)          ATask, ATaskPtr, ATaskFilter, ATaskFlag,
                         AFixType, AStartStatus, ADateBlock, ABigDateBlock,
    (* VAR   *)          TaskTree,
    (* PROC  *)          CheckTaskValid, QueryNumberOfTasks;

FROM Assignments  IMPORT
    (* TYPE *)            AnAssignmentRecord, AnAssignmentArray,
    (* PROC *)            ForEachAssignment;

FROM Chart        IMPORT
    (* VAR *)             BugTaskA, BugDayA, BugTaskB, BugDayB,
                          CursorTask, CursorDay, ChartStartDay,
                          GanttChart;

FROM ChartControl IMPORT
    (* TYPE *)            AChartState, AChartStateSet,
    (* VARS *)            ChartState,
    (* PROC *)            UnSetState, DisplayTheChart;

FROM Clock        IMPORT
    (* PROC *)            Delay;

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

FROM Dialog       IMPORT Message, Error, FatalError,
                         ADialogOption, ContinuationBox,
                         ABoxHandle, ProgressBox,
                         ReleaseBox;

FROM Directory    IMPORT  ExtractFileNameParts,
                          AFileNamePart, ASetOfFileNameParts,
                          ExpandPath,
                          StartFileNodeLookup,
                          AFileNameRecord, AFileAttribute, AFileAttributeSet,
                          RemovableMedia;

FROM Edges        IMPORT
    (* TYPE *)            AnEdge, AnEdgePtr,
    (* PROC *)            CheckEdgeValid;

FROM Endings      IMPORT
    (* VARS *)            CompletionCode, QuitDammitCode;

FROM ExportLinkage IMPORT
    (* VARS *)      ExportMedia, ExportName, NewFile,
                    SaveConfiguration, SaveSchedule, SelectiveSave;

IMPORT            FileSystem;

FROM FileSystem   IMPORT  File, Lookup, Response, Close,
                          SetAttribute,
                          WriteChar, Create, Rename, Delete;

FROM FileAux      IMPORT DisplayFileError,
                         FlushBuffer, PrepareForIO, CheckIO;

FROM FilterRc     IMPORT
    (* TYPE *)             AFilterRecordPointer, AFltrSet, AFltrType;

FROM FlexStor     IMPORT
    (* TYPE *)            AnExtHandle, AnExtStoragePreference,
    (* PROC *)            MakeHeapCopy, GetExtSize,
                          LockObjectArray, ReleaseObject, ArraySize,
                          NumberOfElements, ReleaseUnchangedObject,
                          SetExtSize,   LockObject;

FROM ForeignSubfiles IMPORT
    (* TYPE *)          AFileType,
    (* PROC *)          WriteAllForeignSubfiles;

FROM Gantt        IMPORT  AGanttLineType;

FROM Holder       IMPORT AHoldType, AHoldTypeSet;

FROM IlsaStatic   IMPORT
    (* TYPE *)           ATLGSTitleBlockPtr, ATLGSColorAssignmentPtr,
                         ATLGSPertRecordPtr, ATLGSGanttRecordPtr,
                         ATLGSTreeRecordPtr, ATLGSChartType,
                         ATLGSPageRecordPtr,
    (* PROC *)           TLGSTitleBlockExists,
                         TLGSPertRecordExists, TLGSGanttRecordExists,
                         TLGSTreeRecordExists, LockTLGSTitleBlock,
                         TLGSPertRecord,
                         TLGSGanttRecord, TLGSTreeRecord, TLGSPageRecordExists,
                         TLGSPageRecord, UnlockTLGSTitleBlock;

FROM Kbio         IMPORT
                         BreakRequested, avidmode,
                         TamperedFlag,
                         PutString;


FROM LStrings     IMPORT ConcatLS, ConcatS, CtoS, LengthOf,
                         SubStr, LStringToTString, TStringToLString,
                         Procustes, Copy, StringsEqual, SetLengthOf;

FROM MsgFile      IMPORT  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays     IMPORT
    (* VARS *)          PackageOK,
    (* PROCS *)         OverlayContext;

FROM Planner      IMPORT  ScheduleEndDate,
                          ScheduleStartDate;

FROM PrintStatic  IMPORT  PrintDiskFileName, APrinterStyle,
                          ReportSettings;

FROM Progress               IMPORT
    (* TYPE *)                      AThermometer,
    (* PROC *)                      CreateThermometer, UpdateThermometer, 
                                    DiscardThermometer;

FROM RsrcMod      IMPORT
    (* TYPE  *)          AResourcePointer, AResourceType,
    (* VAR   *)          ResourceTree,
    (* PROC *)           CheckResourceValid;

FROM RecordIO     IMPORT  WriteRecord, WriteString;

FROM Registry               IMPORT
    (* CONST *)                 QCapacity,
    (* TYPE *)                  ARegistryDataRecord,
    (* VAR  *)                  UserName, ProductName;

FROM RegCapacity            IMPORT
    (* PROC *)                  GetRegistryInfo;

FROM SaveCommon   IMPORT
    (* VARS *)          f,
    (* PROCS *)         WriteText, WriteNodeInfo, WriteDate,
                        SaveCommonData, WriteTaskID;

FROM Space        IMPORT
    (* PROC *)            DEALLOCATE;

FROM Schedule     IMPORT
    (* VAR *)          CurrentFileExtension,
                       AScheduleLockClass,ProjectText,
                       PlannedProjectName, Author, FullScheduleName,
                       ScheduleSaved, RevisionNumber,
                       ProjectMedia, ProjectName, Loaded,
                       ScheduleDOSTimeStamp, LockSchedule, UnLockSchedule,
                       IsScheduleLocked;

FROM SSaveOptions           IMPORT
    (* TYPE *)                  ASaveSetting,
    (* PROC *)                  GetSaveSettings;

FROM Subfiles     IMPORT  StartFileOutput, EndFileOutput,
                          StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM     IMPORT TSIZE, SIZE, ADR, ADDRESS;

FROM Timei      IMPORT
    (* TYPE *)      ADate, ADuration, ATimeInfo,
    (* PROC *)      TimeUtoT;

FROM Timeu      IMPORT
    (* VAR *)       FSMUPH, SMU, SMUPH;

FROM TimeXlate  IMPORT
    (* PROC *)      CalendarTimeToBigTime;

FROM Transfer   IMPORT BackupsToKeep;

FROM TreeObjects  IMPORT
    (* TYPE *)            ATree, ATreeNode, ATreeOrder,
                          ATreeNodeProcessingProc,
                          ATreeNodeAttribute,
    (* PROC *)            ValidateTree, ValidateTreeNode;

FROM Undo            IMPORT
        (* PROCS *)     FlushUndos;

FROM XResource      IMPORT
    (* PROC *)          SaveResources, SaveOneAssignmentArray;



CONST
    ModuleNumber           = 14400;   (* For GetMessage. *)
    IllegalSchedChngMsg    = 15;
    ScheduleIOConflictMsg  = 16;

CONST
     PlotGantt       = 444;        (* Must match keys.PlotGantt, but import overflows symbol table. *)


     MAXCARDINAL             = 0FFFFH;
     MAXDATE                 = MAXCARDINAL;
     MaxBackupsToKeep        = 8;
     MaxSubfiles             = 35;                                (* 12-Sep-89 LAA *)

    SaveThisOne     = TempFlag2;

    FMAXCARDINAL = 65535.0;
    OneHundred   = 100.0;
    Point5       = 0.5;

TYPE
    ATwoDateRecord = RECORD
                         FirstDate,LastDate     : ADate;
                     END;



     (* Because there can be memory allocation problems, we want to
        preallocate some large variables in order to make detecting
        these stack/heap collisions easier. *)
VAR
    SequenceNumber          : INTEGER;
    GlobalMaxCount,
    GlobalCount,
    CountOfTasks            : CARDINAL;
    CursorNode              : ATreeNode;
    CursorLevel             : CARDINAL;

    SaveSettings            : ASaveSetting;

    ErrorFlag               : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;

    EarlyExit               : BOOLEAN;

    RecordQuantities        : AQuantities;





PROCEDURE QuickMessage(VAR s : ARRAY OF CHAR);
VAR
    s1  : ARRAY [0..81] OF CHAR;
BEGIN
    Copy(s,s1);
    Procustes(s1,80);    (* Pad it so that it erases prev contents of line. *)
    PutString(s1,0,0,videonormal);
END QuickMessage;





PROCEDURE SetInclusion (  Node          : ATreeNode;
                          Included      : BOOLEAN   );
BEGIN
    Node^.Methods^.SetAttributeBit (Node, SaveThisOne, Included);
END SetInclusion;



PROCEDURE IsIncluded  (   Node    : ATreeNode ) : BOOLEAN;
BEGIN
    RETURN Node^.Methods^.TestAttributeBit (Node, SaveThisOne);
END IsIncluded;





PROCEDURE CheckOneAssignment    ( VAR Assignment   : AnAssignmentRecord;
                                      Context      : ADDRESS    ) : BOOLEAN;
VAR
    RsrcNode            : ATreeNode;

BEGIN
    WITH Assignment DO
        RsrcNode := Resource^.WorkSpace;
        SetInclusion (RsrcNode, TRUE);
    END;
    RETURN TRUE;
END CheckOneAssignment;




PROCEDURE SetupData ();
VAR
    Node            : ATreeNode;
    Included        : BOOLEAN;
    TaskPtr         : ATaskPtr;
    ResourcePtr     : AResourcePointer;


    PROCEDURE CheckFamily ();
    VAR
        PNode       : ATreeNode;
    BEGIN
        IF (Included) AND (SaveSettings.CursorTaskOnly) THEN
            Included := FALSE;
            PNode := Node;
            WHILE (PNode <> NIL) DO
                IF (PNode = CursorNode) THEN
                    Included := TRUE;
                    RETURN;
                END;
                PNode := PNode^.Methods^.Parent (PNode);
            END;
        END;
    END CheckFamily;


    PROCEDURE CheckFilter ();
    BEGIN
        IF (Included) THEN
            Included := (Node^.Methods^.Visible (Node));
        END;
    END CheckFilter;


    PROCEDURE CheckOpenClose ();

        PROCEDURE ClosedOff () : BOOLEAN;
        VAR
            PNode       : ATreeNode;
        BEGIN
            PNode := Node^.Methods^.Parent (Node);
            WHILE (PNode <> NIL) DO
                IF (NOT PNode^.Methods^.ChildrenVisible (PNode)) THEN
                    RETURN TRUE;
                END;
                PNode := PNode^.Methods^.Parent (PNode);
            END;
            RETURN FALSE;
        END ClosedOff;

    BEGIN
        IF (Included) THEN
            IF (ClosedOff()) THEN
                Included := NOT SaveSettings.DiscardKids;
            END;
        END;
    END CheckOpenClose;


BEGIN

    GetSaveSettings (SaveSettings);

    CursorNode := GanttChart^.Methods^.GetCursorNode (GanttChart);

        (*  Get the indentation level of the cursor node.  If this is
            a selective save of the cursor task only, we'll need to
            subtract that from every child node saved, because,
            effectively, the cursor node is moving to level 0 (in the file).
        *)

    IF (CursorNode <> NIL) THEN
        CursorLevel := CursorNode^.Methods^.IndentationLevel (CursorNode);
    ELSE
        CursorLevel := 0;
    END;

        (*  First, mark resources as included or not *)

    Node := ResourceTree^.Methods^.GetFirst (ResourceTree);
    WHILE (Node <> NIL) DO
        Included := (NOT SelectiveSave) OR (NOT SaveSettings.FilterResources);
        SetInclusion (Node, Included);
        ResourcePtr := Node^.Methods^.GetDataObject (Node);

            (*  Set the resource's workspace to its tree node, so we can
                find it later *)

        ResourcePtr^.WorkSpace := Node;
        Node := Node^.Methods^.NextPreOrder (Node);
    END;

        (*  Now check all the tasks *)

    Node := TaskTree^.Methods^.GetFirst (TaskTree);
    WHILE (Node <> NIL) DO
        Included := TRUE;
        IF (SelectiveSave) THEN
            CheckFamily();
            CheckFilter();
            CheckOpenClose();
        END;
        SetInclusion (Node, Included);

            (*  Look at all the assignments to this task, and make sure
                that those resources are marked as included     *)

        IF (Included) AND (SelectiveSave) AND (SaveSettings.FilterResources) THEN
            TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
            ForEachAssignment (TaskPtr^.Plan.Assignments, CheckOneAssignment, NIL);
            IF (BaseLineExists IN TaskPtr^.TaskFlags) THEN
                ForEachAssignment (TaskPtr^.BaseLine.Assignments, CheckOneAssignment, NIL);
            END;
            Node^.Methods^.UnlockUnchangedDataObject (Node);
            TaskPtr := NIL;
        END;

        Node := Node^.Methods^.NextPreOrder (Node);
    END;

END SetupData;
















PROCEDURE SaveOneBigDateBlock( VAR DateBlock : ADateBlock;
                                   Duration  : ADuration;
                                   Type      : CARDINAL );
VAR
    BigDateBlock : ABigDateBlock;
BEGIN

    WITH DateBlock DO
        CalendarTimeToBigTime( EarlyStart,          TRUE,  BigDateBlock.EarlyStart    );
        CalendarTimeToBigTime( EarlyEnd,            TRUE,  BigDateBlock.EarlyEnd      );
        CalendarTimeToBigTime( LateFreeStart,       TRUE,  BigDateBlock.LateFreeStart );
        CalendarTimeToBigTime( LateFreeEnd,         TRUE,  BigDateBlock.LateFreeEnd   );
        CalendarTimeToBigTime( LateTotalStart,      TRUE,  BigDateBlock.LateTotalStart);
        CalendarTimeToBigTime( LateTotalEnd,        TRUE,  BigDateBlock.LateTotalEnd  );
        CalendarTimeToBigTime( LateIndStart,        TRUE,  BigDateBlock.LateIndStart  );
        CalendarTimeToBigTime( LateIndEnd,          TRUE,  BigDateBlock.LateIndEnd    );
    END;

    WriteRecord(f,Type,ADR(BigDateBlock),SIZE(BigDateBlock));

END SaveOneBigDateBlock;






PROCEDURE SaveOneTask( VAR TaskNode : ATreeNode;
                           Context  : ADDRESS );
VAR
    TaskPtr             : ATaskPtr;
    TaskRecord          : ATask;
    TaskRecordLength    : CARDINAL;
    LevelOffset         : CARDINAL;
    PlanAssignments     : AnExtHandle;
    BaseAssignments     : AnExtHandle;
    Node                : ATreeNode;
    Thermometer         : AThermometer;
    KidFound            : BOOLEAN;

BEGIN
    Thermometer := AThermometer( Context );

    TaskRecordLength := TSIZE(ATask); (* AJL 6/3/87 *)

    IF  (GlobalCount <= GlobalMaxCount) AND
        (IsIncluded (TaskNode))           AND
        (CheckIO(f) = done)             THEN

        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        TaskRecord := TaskPtr^;
        TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);    TaskPtr := NIL;

            (*  See if this is a summary task that is being saved without
                any of its kid tasks.  Since this will essentially turn
                it into a detail task, switch it from ALAP to ASAP.
            *)

        Node := TaskNode^.Methods^.FirstChild (TaskNode);
        IF (Node <> NIL) THEN
            KidFound := FALSE;
            WHILE (Node <> NIL) AND (NOT KidFound) DO
                KidFound := IsIncluded (Node);
                Node := Node^.Methods^.GetNext (Node);
            END;
            IF (NOT KidFound) THEN
                TaskRecord.fixation := ASAP;            (* 5/26/89 EGK *)
            END;
        END;

        WITH TaskRecord DO
            IF (SelectiveSave) AND (SaveSettings.CursorTaskOnly) THEN
                LevelOffset := CursorLevel;
            ELSE
                LevelOffset := 0;
            END;
            WriteNodeInfo (f, TaskNode, 0, LevelOffset);
            WriteRecord(f,TaskType,ADR(TaskRecord),TaskRecordLength);
    
            WriteText(f, notes, 102);
            WriteText(f, summarizes, 104);
            WriteText(f, Coding, 124);          (* 5/3/89 EGK *)

                (* Save the calendar independant dates for this task. *)

            SaveOneBigDateBlock( Plan.Dates,     duration, 90);
            SaveOneBigDateBlock( BaseLine.Dates, duration, 91);

            SaveOneAssignmentArray(f,Plan.Assignments,70);
            SaveOneAssignmentArray(f,BaseLine.Assignments,80);

            INC(RecordQuantities[ QTask ]);
        END;
    END;

    INC( GlobalCount );

    IF (GlobalCount MOD 16) = 0 THEN
        UpdateThermometer( Thermometer, GlobalCount );
    END;

END SaveOneTask;




PROCEDURE SaveTasks();
VAR
    Thermometer         : AThermometer;
    S                   : ARRAY [0..31] OF CHAR;


    (* This updated by RSC 6/20/89 *)

    PROCEDURE GetMaxWriteCount() : CARDINAL;
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

    END GetMaxWriteCount;


BEGIN
    StartSubfileOutput(f,TaskType,TaskFileVersionNumber);

    GlobalMaxCount := GetMaxWriteCount();
    GlobalCount    := 0;

        (* Prepare to display progress. *)
    GetMessage(ModuleNumber+20,S);
    IF (NOT CreateThermometer(Thermometer,0,0,S,QueryNumberOfTasks())) THEN
        Thermometer := AThermometer(NIL);
    END;

    ValidateTree(TaskTree);

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,
                                    9999,SaveOneTask,ADDRESS(Thermometer));

    IF (CheckIO(f) = done) THEN
        EndSubfileOutput(f,TaskType);
    END;

    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

END SaveTasks;





PROCEDURE SaveOneTasksEdges( VAR TaskNode : ATreeNode;
                                 DummyAddress : ADDRESS );
TYPE
    AnAddressTrick = RECORD
        CASE BOOLEAN OF
            TRUE :  P  : ATreeNode;
          | FALSE:  C  : RECORD
                             A  : INTEGER;
                             B  : CARDINAL;
                         END;
        END;
    END;
VAR
    TaskRecord : ATaskPtr;
    Edge    : AnEdge;
    beforeedge: AnEdgePtr;
    RecordLength : CARDINAL;
    PredecessorTask,
    SuccessorTask    : ATaskPtr;
    PredecessorNode,
    SuccessorNode    : ATreeNode;
    AddressTrick     : AnAddressTrick;
BEGIN

    IF (NOT IsIncluded (TaskNode)) THEN
        RETURN;
    END;

        (* Write out the record less the two linkage pointers. *)

    RecordLength := TSIZE(AnEdge) - (2 * TSIZE(AnEdgePtr) );

    IF (CheckIO(f) = done) THEN
        (*<DEBUG
        CheckTaskValid(TaskNode);
        DEBUG>*)

            (* Write out each descendant edge. *)

        TaskRecord := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

        beforeedge := TaskRecord^.desctasks;  (* We come before these, *)
        TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);    TaskRecord := NIL;

        WHILE (beforeedge <> NIL) DO
            CheckEdgeValid(beforeedge);

                (* Locate the linked tasks *)

            PredecessorNode := beforeedge^.headtask;
            SuccessorNode   := beforeedge^.tailtask;

            (*<DEBUG
                CheckTaskValid(PredecessorNode);
                CheckTaskValid(SuccessorNode);
            DEBUG>*)

            IF (IsIncluded (SuccessorNode)) THEN

                PredecessorTask :=
                    PredecessorNode^.Methods^.LockFlexStorDataObject(PredecessorNode);

                SuccessorTask :=
                    SuccessorNode^.Methods^.LockFlexStorDataObject(SuccessorNode);


                    (* Make a local copy of the edge, and substitute
                       the TaskID's of the tasks for their pointers.
                       For EVE, squish the duration into the address and
                       Z fields.  Ugh.
                     *)

                Edge                := beforeedge^;
                AddressTrick.C.A    := PredecessorTask^.TaskID;
                AddressTrick.C.B    := Edge.FromOffset.Dur DIV SMUPH;  (* 12-Nov-90 RSC *)
                Edge.headtask       := AddressTrick.P;
                AddressTrick.C.A    := SuccessorTask^.TaskID;
                AddressTrick.C.B    := SMUPH;  (* 12-Nov-90 RSC *)
                Edge.tailtask       := AddressTrick.P;
                    (* 29-Apr-91 RSC Adjusted:
                    *)
                Edge.Z              := (Edge.FromOffset.Dur MOD SMUPH) * SMU; (* 12-Nov-90 RSC *)
                Edge.FromOffset.Dur := MAXCARDINAL;

                PredecessorNode^.Methods^.UnlockUnchangedDataObject(PredecessorNode);
                PredecessorTask := NIL;

                SuccessorNode^.Methods^.UnlockUnchangedDataObject(SuccessorNode);
                SuccessorTask := NIL;

                    (* Store the (modified) local edge record. *)

                WriteRecord(f,1,ADR(Edge),RecordLength);

                IF (CheckIO(f) <> done) THEN
                    RETURN;
                END;

                INC( RecordQuantities[ QEdge ] );
            END;

            beforeedge := beforeedge^.headlink
        END;
    END;

END SaveOneTasksEdges;









PROCEDURE SaveEdges ();
VAR
    DummyAddress : ADDRESS;
    S            : ARRAY [0..0] OF CHAR;
BEGIN
    SetLengthOf(S,0); Message(S);

    PrepareForIO(f);
    StartSubfileOutput(f,EdgeType,EdgeFileVersionNumber);

    ValidateTree(TaskTree);

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,
                                    9999,SaveOneTasksEdges,DummyAddress);

    IF (CheckIO(f) = done) THEN
        EndSubfileOutput(f,EdgeType);
    END;

END SaveEdges;







PROCEDURE SaveBugs();
BEGIN
    StartSubfileOutput(f,BugsType,BugsFileVersionNumber);
    WriteTaskID(f,BugTaskA,1);
    WriteDate(f,BugDayA,2);
    WriteTaskID(f,BugTaskB,3);
    WriteDate(f,BugDayB,4);
    WriteTaskID(f,CursorTask,100);
    WriteDate(f,CursorDay,101);
    WriteDate(f,ChartStartDay,102);
    EndSubfileOutput(f,BugsType);
END SaveBugs;







PROCEDURE SaveProjectDetails();

BEGIN
    StartSubfileOutput(f,ProjectType,ProjectFileVersionNumber);
    WriteString(f,0,Author);
    WriteString(f,1,FullScheduleName);
    WriteString(f,4,PlannedProjectName);                          (* 20-Jan-88 LAA *)
    WriteDate(f,ScheduleEndDate,5);
    WriteDate(f, ScheduleStartDate, 6);                           (* 29-May-89 LAA *)
    INC(RevisionNumber);
    WriteRecord(f,7,ADR(RevisionNumber),SIZE(RevisionNumber));
    WriteText(f, ProjectText, 12);
    EndSubfileOutput(f,ProjectType);
END SaveProjectDetails;





PROCEDURE MakeVersion(VAR FileName:ARRAY OF CHAR; n:CARDINAL;
                      VAR TString :ARRAY OF CHAR);
VAR
    s : ARRAY [0..1] OF CHAR;
BEGIN
    IF (n > 9) THEN FatalError; END;
    SubStr(FileName,TString,1,ORD(FileName[0])-1);
    CtoS(n,s);
    ConcatLS(TString,s);
    LStringToTString(TString,TString);
END MakeVersion;





PROCEDURE DeleteBackup(VAR FileName:ARRAY OF CHAR; n:CARDINAL):BOOLEAN;
VAR
    f : File;  (* IMPORTANT: This local copy overrides global f! *)
    TString : ARRAY [0..80] OF CHAR;
    res : Response;

    PROCEDURE FileComplaint;
    VAR
        s  : ARRAY [0..80] OF CHAR;
        s2 : ARRAY [0..80] OF CHAR;
    BEGIN
        GetMessage(ModuleNumber+3,s);   (*  "Backup project file "  *)
        TStringToLString(TString,s2);
        ConcatLS(s,s2);
        DisplayFileError(f,s);
    END FileComplaint;

BEGIN
        (*  n should not be more than 8. *)
    MakeVersion(FileName,n,TString);
    PrepareForIO(f);
    Lookup(f,TString,FALSE);
    res := CheckIO(f);
    CASE (res) OF
        notdone, unknownfile : ;
          |
        done :  Close(f);
                PrepareForIO(f);
                Delete(TString,f);
                IF (CheckIO(f) <> done) THEN
                    FileComplaint;
                    Close(f);
                    RETURN FALSE;
                END;
        ELSE    FileComplaint;
                Close(f);
                RETURN FALSE;
    END;
    RETURN TRUE;
END DeleteBackup;



PROCEDURE PanicButtonPressed() : BOOLEAN;

VAR
    Result              : BOOLEAN;

BEGIN
    IF (BreakRequested()) THEN
        Result    := TRUE;
        EarlyExit := TRUE;
    ELSE
        Result    := FALSE;
        EarlyExit := FALSE;
    END;

    RETURN Result;
END PanicButtonPressed;


PROCEDURE RenameOldFiles(VAR FileName:ARRAY OF CHAR;Max:CARDINAL):BOOLEAN;

CONST
    SleepTime               = 500;  (* 5 seconds *)

VAR
    Count     : CARDINAL;
    f         : File; (* IMPORTANT!  This Local copy of f is needed 'cause global f is in use! *)
    TString   : ARRAY [0..80] OF CHAR;
    s         : ARRAY [0..80] OF CHAR;
    s2        : ARRAY [0..255] OF CHAR;
    res       : Response;
    AwayWeGo  : BOOLEAN;
    BoxShowing: BOOLEAN;
    StatusBox : ABoxHandle;


    PROCEDURE FileComplaint;
    VAR
        s  : ARRAY [0..80] OF CHAR;
        s2 : ARRAY [0..80] OF CHAR;
    BEGIN
        GetMessage(ModuleNumber+2,s);   (*  "Project file "  *)
        TStringToLString(TString,s2);
        ConcatLS(s,s2);
        DisplayFileError(f,s);
    END FileComplaint;



BEGIN
    EarlyExit := FALSE;   (* 18-Jul-89 WKH *)
    FOR Count := Max TO 0 BY -1 DO
        GetMessage(ModuleNumber+4,s);   (*  "Renaming archive file "  *)
        CtoS(Count,TString);  (* Not really a TString, here. *)
        ConcatLS(s,TString);
        Message(s);

        MakeVersion(FileName,Count,TString);

        AwayWeGo   := FALSE;
        BoxShowing := FALSE;

        REPEAT
            PrepareForIO(f);
            Lookup(f,TString,FALSE);
            res := CheckIO(f);
            IF (res = done) THEN
                AwayWeGo := TRUE;

                IF (BoxShowing) THEN
                    BoxShowing := FALSE;
                    ReleaseBox(StatusBox);
                END;

                MakeVersion(FileName,Count+1,TString);
                Rename(f,TString);

                IF (CheckIO(f) <> done) THEN
                    FileComplaint;
                    GetMessage(ModuleNumber+5,s);   (*  "I suggest you make extra copies of your files."  *)
                    Error(s);
                    RETURN FALSE;
                END;

                Close(f);

                IF (CheckIO(f) <> done) THEN
                    FileComplaint;
                    RETURN FALSE;
                END;

            ELSIF (res = userdeverror) THEN  (* 14-Jul-89 WKH *)

                IF (NOT BoxShowing) THEN
                    BoxShowing := TRUE;
                    GetMessage(ModuleNumber + ScheduleIOConflictMsg, s2);
                    StatusBox  := ProgressBox(s2);
                END;

                Delay(SleepTime, PanicButtonPressed);

            ELSIF (res = notdone) OR (res = unknownfile) THEN
                IF (BoxShowing) THEN
                    BoxShowing := FALSE;
                    ReleaseBox(StatusBox);
                END;
                AwayWeGo := TRUE;
            ELSE
                IF (BoxShowing) THEN
                    BoxShowing := FALSE;
                    ReleaseBox(StatusBox);
                END;
                FileComplaint;
                Close(f);
                RETURN FALSE;
            END;

        UNTIL ((AwayWeGo) OR (EarlyExit));

        IF (EarlyExit) THEN
            IF (BoxShowing) THEN
                BoxShowing := FALSE;
                ReleaseBox(StatusBox);
            END;
            RETURN FALSE;
        END;
    END;

    IF (BoxShowing) THEN
        BoxShowing := FALSE;
        ReleaseBox(StatusBox);
    END;
    RETURN TRUE;
END RenameOldFiles;



PROCEDURE SavePrinterSettings();
BEGIN
    StartSubfileOutput(f,PrintFileType,1);

    WriteString(f,0,PrintDiskFileName);
    WriteRecord(f,1,ADR(ReportSettings),SIZE(ReportSettings));

    EndSubfileOutput(f,PrintFileType);
END SavePrinterSettings;




PROCEDURE SaveTLGSRecords();                                      (* 21-May-89 LAA *)

VAR
    TitleBlock              : ATLGSTitleBlockPtr;
    GanttRecord             : ATLGSGanttRecordPtr;
    PertRecord              : ATLGSPertRecordPtr;
    TreeRecord              : ATLGSTreeRecordPtr;
    ColorAssignment         : ATLGSColorAssignmentPtr;
    PageRecord              : ATLGSPageRecordPtr;

BEGIN                       (* SaveTLGSRecords *)

    StartSubfileOutput(f, TLGSDeviceType, 1);
        (*  Gantt chart records  *)

    IF (TLGSTitleBlockExists(TLGSGanttChart)) THEN
        TitleBlock := LockTLGSTitleBlock(TLGSGanttChart);         (* 26-May-89 LAA *)
        WriteRecord(f, 10, TitleBlock, SIZE(TitleBlock^));
        UnlockTLGSTitleBlock(TLGSGanttChart);                     TitleBlock := NIL;
    END;
    IF (TLGSGanttRecordExists()) THEN
        GanttRecord := TLGSGanttRecord(0.0);
        WriteRecord(f, 11, GanttRecord, SIZE(GanttRecord^));
    END;

        (*  Pert chart records  *)

    IF (TLGSTitleBlockExists(TLGSPertChart)) THEN
        TitleBlock := LockTLGSTitleBlock(TLGSPertChart);
        WriteRecord(f, 20, TitleBlock, SIZE(TitleBlock^));
        UnlockTLGSTitleBlock(TLGSPertChart);                      (* 06-Jun-89 LAA *)
    END;
    IF (TLGSPertRecordExists()) THEN
        PertRecord := TLGSPertRecord();
        WriteRecord(f, 21, PertRecord, SIZE(PertRecord^));
    END;

        (*  Tree chart record  *)

    IF (TLGSTitleBlockExists(TLGSTreeChart)) THEN
        TitleBlock := LockTLGSTitleBlock(TLGSTreeChart);
        WriteRecord(f, 30, TitleBlock, SIZE(TitleBlock^));
        UnlockTLGSTitleBlock(TLGSTreeChart);                      (* 06-Jun-89 LAA *)
    END;
    IF (TLGSTreeRecordExists()) THEN
        TreeRecord := TLGSTreeRecord();
        WriteRecord(f, 31, TreeRecord, SIZE(TreeRecord^));
    END;

        (*  Page Record  *)

    IF (TLGSPageRecordExists()) THEN
        PageRecord := TLGSPageRecord();
        WriteRecord(f, 40, PageRecord, SIZE(PageRecord^));
    END;

    EndSubfileOutput(f, TLGSDeviceType);

END SaveTLGSRecords;



    (* Store the number of objects of various types. *)


PROCEDURE SaveCounts();
BEGIN
    StartSubfileOutput(f,CountsType,1);

    WriteRecord(f,1,ADR(RecordQuantities),SIZE(RecordQuantities));

    EndSubfileOutput(f,CountsType);
END SaveCounts;




PROCEDURE NumberTheResource( VAR TreeNode : ATreeNode;
                                 DummyAddress : ADDRESS );
VAR
    Resource : AResourcePointer;
BEGIN
        (* Each Task is numbered successively with a sequence number. *)
    ValidateTreeNode(TreeNode);
    Resource := TreeNode^.Methods^.GetDataObject(TreeNode);
    INC(SequenceNumber);
    CheckResourceValid(Resource);
    Resource^.ID := SequenceNumber;
END NumberTheResource;


PROCEDURE NumberTheTask( VAR TreeNode     : ATreeNode;
                             DummyAddress : ADDRESS );
VAR
    Task : ATaskPtr;
BEGIN
        (* Each Task is numbered successively with a sequence number. *)
    CheckTaskValid(TreeNode);
    Task := TreeNode^.Methods^.LockFlexStorDataObject(TreeNode);
    INC(SequenceNumber);
    Task^.TaskID := SequenceNumber;
    TreeNode^.Methods^.UnlockFlexStorDataObject(TreeNode);
END NumberTheTask;







PROCEDURE SaveProjectFile(FileName:ARRAY OF CHAR):BOOLEAN;

VAR
    i,j                     : CARDINAL;
    high, low               : CARDINAL;
    DummyAddress            : ADDRESS;
    QuantityOf              : AQuantityOf;
    FileNameRecord          : AFileNameRecord;
    tempstring              : ARRAY [0..120] OF CHAR;
    medium                  : ARRAY [0..3] OF CHAR;
    TempFile                : ARRAY [0..81] OF CHAR;
    Path                    : ARRAY [0..81] OF CHAR;
    FName                   : ARRAY [0..9] OF CHAR;
    Extension               : ARRAY [0..3] OF CHAR;
    res                     : Response;
    ok                      : BOOLEAN;
    ScheduleWasLocked       : BOOLEAN;
    CurrentSchedMedia       : ARRAY [0..80] OF CHAR;
    CurrentSchedName        : ARRAY [0..13] OF CHAR;
    CurrentSchedFullName    : ARRAY [0..99] OF CHAR;
    FileSaveReplace         : BOOLEAN;
    Title                   : ARRAY [0..1] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    LocalChartState         : AChartStateSet;


    PROCEDURE FileComplaint(VAR Name:ARRAY OF CHAR);
    VAR
       s    : ARRAY [0..150] OF CHAR;
       s2   : ARRAY [0..80] OF CHAR;
    BEGIN
        GetMessage(ModuleNumber+2,s);  (* "Project file" *)
        ConcatLS(s,Name);
        ConcatS(s,", ");
        DisplayFileError(f,s);
    END FileComplaint;

BEGIN
        (* Set initial counters to zero. *)
    FOR QuantityOf := MIN(AQuantityOf) TO MAX(AQuantityOf) DO
        RecordQuantities[ QuantityOf ] := 0L;
    END;

    SetupData();

    SetLengthOf(Title, 0);  (* 5/25/89 WKH *)

    Copy(ProjectMedia, CurrentSchedMedia);
    ExpandPath(CurrentSchedMedia, Title, CurrentSchedMedia);  (* 07-Jul-89 WKH *)
    Copy(ProjectName, CurrentSchedName);  (* 4/10/89 WKH *)
    ConcatLS(CurrentSchedName, CurrentFileExtension);

    Copy(CurrentSchedMedia, CurrentSchedFullName);   (* 4/12/89 WKH *)
    ConcatLS(CurrentSchedFullName, CurrentSchedName);

    IF (StringsEqual(CurrentSchedFullName, FileName)) THEN
        FileSaveReplace := TRUE;
    ELSE
        FileSaveReplace := FALSE;
    END;

    IF ( FileSaveReplace AND (NOT RemovableMedia(FileName)) ) THEN (* 5/1/89 WKH *)
        FileNameRecord.Attributes := AFileAttributeSet{ReadOnlyAttribute,
                                                       ArchiveAttribute};
        IF (NOT StartFileNodeLookup(FileName, FileNameRecord)) THEN
            GetMessage(ModuleNumber + IllegalSchedChngMsg, s);  (* 16-Oct-89 WKH  *)
            IF (NOT ContinuationBox(s, Title, OfferHelp)) THEN
                RETURN FALSE;
            END;
        END;
        WITH FileNameRecord DO
            IF ((TimeStamp.Low <> ScheduleDOSTimeStamp.Low) OR
                (TimeStamp.High <> ScheduleDOSTimeStamp.High)) THEN
                GetMessage(ModuleNumber + IllegalSchedChngMsg, s);
                IF (NOT ContinuationBox(s, Title, OfferHelp)) THEN
                    RETURN FALSE;
                END;
            END;
        END;
    END;

        (* Put ID numbers into each task. *)

    SequenceNumber := 0;
    ValidateTree(TaskTree);
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,9999,NumberTheTask,
                                    DummyAddress);

    CountOfTasks := SequenceNumber;

        (* Put ID numbers into each resource. *)

    SequenceNumber := 0;
    ValidateTree(ResourceTree);
    ResourceTree^.Methods^.TraverseTree(ResourceTree,ParentBeforeChild,9999,NumberTheResource,
                                        DummyAddress);

    GetMessage(ModuleNumber+6,s);    (* "(temp)" *)
    ConcatLS(s,FileName);

        (*  Instead of creating a DOS temporary file, which would be created
            in the current directory of the destination drive, explicitly
            create a file where the final schedule file will be saved.  This
            handles the case of networks, where the user doesn't have write
            access to the current directory, but does have write access to
            the data directory.  I hope.  - LA
        *)
                                                                  (* 11-May-88 LAA *)
    ExtractFileNameParts(FileName, TempFile, Path, FName, Extension);
    ConcatLS(TempFile, Path);
    ConcatLS(TempFile, FName);
    ConcatLS(TempFile, CurrentFileExtension);
    i := LengthOf(TempFile);
    TempFile[ i ] := TempFile[ i-1 ]; (* So, T$0-->T$$, T%0-->T%%, etc. *)

        (*  Create a new, temporary file for the schedule *)
    LStringToTString(TempFile, TempFile);
    Delete(TempFile, f);
    Lookup(f, TempFile, TRUE);

    IF (CheckIO(f) <> done) THEN
        FileComplaint(s);
        Close(f);
        Delete(TempFile, f);                        (* 11-May-88 LAA *)
        RETURN FALSE;
    END;

    StartFileOutput(f,MaxSubfiles);

    IF (TamperedFlag) THEN
        Close(f);
        Delete(TempFile, f);                        (* 11-May-88 LAA *)
        RETURN FALSE;
    END;

    ErrorFlag := FALSE;

    FlushBuffer(f);


    i := 0;
    LOOP
        ok := (CheckIO(f) = done);
        IF (NOT ok) THEN EXIT; END;
        CASE i OF
            0:  IF (SelectiveSave) THEN
                    LocalChartState := ChartState;
                    EXCL (ChartState, Scheduled);       (* 9/26/89 EGK *)
                END;

                SaveCommonData( HoldInDataFile, 1 );

                IF (SelectiveSave) THEN
                    ChartState := LocalChartState;
                END;

          | 1:  SaveProjectDetails();
          | 2:  SaveResources( f, ResourceTree, ResourceType, ResourceFileVersionNumber,
                                  RecordQuantities[ QResource ]);
          | 3:  SaveTasks();
          | 4:  SaveEdges();
          | 5:  SavePrinterSettings();
          | 6:  SaveBugs();
          | 7:  SaveTLGSRecords();
          | 8:  WriteAllForeignSubfiles( f, ScheduleFile );   (* RSC 1-Sep-89 *)
          | 9:  SaveCounts();
        ELSE
            EXIT;
        END;
        INC(i);
    END;

    EndFileOutput(f);

    IF (NOT ok) THEN
        FileComplaint(s);
        Close(f);
        Delete(TempFile, f);                                      (* 11-May-88 LAA *)
        RETURN FALSE;
    ELSIF (ErrorFlag) THEN
        Close(f);
        Delete(TempFile, f);                                      (* 11-May-88 LAA *)
        RETURN FALSE;
    END;

    DisplayMessage(ModuleNumber+7);   (*  "Renaming archival copies . . ."  *)

        (*  Delete any extra backup file beyond BackupsToKeep.  This is
            probably unnecessary as there won't be any except if
            BackupsToKeep was changed or there was a previous file error. *)

    IF (BackupsToKeep > MaxBackupsToKeep) THEN
        BackupsToKeep := MaxBackupsToKeep;
    END;

    IF (NOT DeleteBackup(FileName,BackupsToKeep+1)) THEN
        Close(f);                                                 (* 11-May-88 LAA *)
        Delete(TempFile, f);
        RETURN FALSE;
    END;

        (*  Make T$8 --> T$9, 7 to 8 ... 1 to 2, 0 to 1.  *)
    ScheduleWasLocked := IsScheduleLocked();  (* 4/10/89 WKH *)

    IF (ScheduleWasLocked AND FileSaveReplace) THEN
        UnLockSchedule(RealLock);
    END;

    IF (NOT RenameOldFiles(FileName,BackupsToKeep)) THEN
        Close(f);                                                 (* 11-May-88 LAA *)
        Delete(TempFile, f);
        RETURN FALSE;
    END;

        (*  Make temp file name .T$0  *)

    GetMessage(ModuleNumber+8,s);    (* "Making " *)
    ConcatLS(s,FileName);
    ConcatMessage(s,ModuleNumber+9);  (* " permanent. . ." *)
    Message(s);

    PrepareForIO(f);
    MakeVersion(FileName,0,tempstring);
    Rename(f,tempstring);
    IF (CheckIO(f) <> done) THEN
        FileComplaint(s);                                         (* 28-Aug-87 LAA *)
        Close(f);
        RETURN FALSE;
    END;

    Close(f);
    IF (CheckIO(f) <> done) THEN
        FileComplaint(FileName);
        RETURN FALSE;
    END;

    SetAttribute( tempstring, FileSystem.ArchiveAttribute, f ); (* RSC 5/22/88 *)

    IF (ScheduleWasLocked AND FileSaveReplace) THEN
        IF (LockSchedule(CurrentSchedMedia, CurrentSchedName, TRUE, RealLock)) THEN (* 4/10/89 WKH *)
                (* Couldn't obtain lock *)
        END;
    END;

        (*  Now, as a result of the above renames, we actually have one
            too many backup files.  Delete that extra one. *)

    IF (NOT DeleteBackup(FileName,BackupsToKeep+1)) THEN
        RETURN FALSE;
    END;

    IF (FileSaveReplace) THEN
        ScheduleSaved := TRUE;
    END;

    RETURN TRUE;
END SaveProjectFile;






PROCEDURE SaveCurrentProject();                                   (* 07-Jul-87 LAA *)

VAR
    Choice                  : CARDINAL;
    BoxHandle               : ABoxHandle;
    Context                 : POINTER TO CHAR;
    ok                      : BOOLEAN;
    s2                      : ARRAY [0..99] OF CHAR;
    s3                      : ARRAY [0..1]  OF CHAR;
BEGIN
    Context   := OverlayContext();

    s2        := "Program Copyright (c) 1989 Symantec Corporation.";

    IF (SaveSchedule) THEN
        GetMessage( ModuleNumber + 11, s2 ); (* "One moment while I save your schedule" *)
        BoxHandle := ProgressBox( s2 );
        Copy( ExportMedia, s2 );
        SetLengthOf(s3,0);
        ExpandPath( s2, s3, s2 );  (* 07-Jul-89 WKH *)
        ConcatLS( s2, ExportName );
        ok            := SaveProjectFile( s2 );
        PackageOK     := ok;  (* 6-Feb-89 RSC - Tell OverlayPackages how we did.... *)
        Loaded        := ok;  (* We don't want to erase the project name. *)
        FlushUndos();
        IF (ok) THEN
            DisplayMessage(ModuleNumber+12);    (* "Saved." *)
            IF (Context^ = "Y") THEN
                CompletionCode := 0;  (* QUIT TO ALTERNATE PRODUCT *)
                QuitDammitCode := PlotGantt;
            END;
        ELSE
            GetMessage(ModuleNumber+13,s2);    (* "Project not saved." *)
            IF (NOT NewFile) THEN
                ConcatMessage(s2,ModuleNumber+14); (* "  Your previous copy remains."  *)
            END;
            Message(s2);
        END;
        ReleaseBox( BoxHandle );

            (* Reformat, and redisplay with a new schedule name light. *)
        UnSetState(Formatted);
        GanttChart^.Methods^.NotifyOfChange(GanttChart);
        DisplayTheChart();
    END;

END SaveCurrentProject;









BEGIN

    SaveCurrentProject();

END TLXTL5.
