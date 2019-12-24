MODULE TLLnkSum;

(*V7=TRACE*)

    (*  Summary link -- rolls up entire linked schedule into this one task.
        This is the former TLRollem code from version 3.0.
    *)


    (* MODIFICATION HISTORY:

       Aug. 9, 1985  AL   Changed to allow resources to have a rate of
                          zero.  I had to make special provisions in the
                          section that works backwards from total cost to
                          resource amount in this instance.
       11/03/86 LAA     Import ProjectMedia from Schedule rather than
                        Transfer, changed GetProjectDates because summarizes
                        is not AText, ditto GetRollup and AskForMount.  Also
                        changed parameters of call to Menu in AskForMount to
                        be compatible with the current version.
       05/11/87 AJL     - Changed to use new Costs module and changed Allocs.
       23-Sep-87 LAA    Imported AHeaderRecord from Transfer rather than
                        LoadCommon.
       30-Oct-87 RSC    Upgraded for new text format for TimeLink (SPIKE 3.0)
       29-Dec-87 LAA    GetDataObject hadn't been converted to
                        LockFlexStorDataObject.  Removed TLROLLEM message.
       11-Jan-88 LAA    Changed UnlockFlexStorDataObject to UnlockUnchanged
                        where appropriate.
       20-Jan-88 LAA    Made this an installable overlay.
       19-Feb-88 RSC    1) remove baseline rollup for resources.
                        2) Handle non-billable with a dialog box iff there
                           are some billable and some non.
                        3) Improved error handling a little.
        3-Mar-88 EGK    Don't mess with the existing baseline of a linked
                        task.
       31-Oct-88 EGK    If a rollup file is found but has a bad format, we
                        remove the link permanently.
       21-Dec-88 LAA    Changed imports for Laslo reorganization.
        2-Jan-89 RSC    Added references to StringsEqual() rather than Compare().
        6-Jan-89 RSC    Moved "AnOverlayProc" reference.
        8-Feb-89 EGK    Created this from the old TLRollem.
       21-Mar-89 RSC    Changed FLOAT(SMUPH) to FSMUPH.
        3-Apr-89 EGK    Changed TempFlag1 to RTempFlag1.
        7-Apr-89 EGK    Changed the logic to allow a billable and a non-
                        billable assignment to the same resource for the
                        summarizing task.
        4-May-89 EGK    Now reads both old (v3) and new task records.
       12-Jun-89 RSC    Was using ExtFast for some assignment creations.
                        This is a hideous no-no.
       10-Aug-89 KKC    Add copyright message.
       21-Aug-89 RSC    Add checks of GetExtStatus to see if there is
                        plenty of Ext memory.
       26-Sep-89 RSC    Set Extras to NIL in GetResources.
                        Load Extras into new resources from a text area.
       28-Nov-89 EGK    Put an extra check in TLLnkSumBody so that if
                        the link form says to make a summary milestone,
                        we'll never try to roll up the resource assignments
                        (normally the form should ensure this for us, but
                        we won't completely trust that here).
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        02-May-90 KKC   Replace all direct calculations on ADate and Duration
                        by calls to FindDuration, SubtractWorkingTime and
                        AddWorkingTime.
        14-Feb-91 AJL   Renamed EndOf ActualDate to EndOfSpentDate.

        12-Sep-90 RSC   Fixed for new Allocs.Def and for version 4.5.  Should
                        be able to link in V3, V4, and V4.5 tasks.
         2-Oct-90 RSC   ADded UserEnteredEndDate.
         3-Nov-90 AJL  -Set the task flags to {NoSoonerStart,NoLaterStart} so
                        that the task will not be moved by recalc (unless the
                        user changes those flags.
                       -Corrected a problem where the varying assignments were
                        being disposed after being created, but their handle
                        in the assignments record was left around.  This was
                        because some handles were being copied directly with
                        the assignment operator rather than the
                        CopyOneAssignment procedure.
         6-Nov-90 RSC   "SuppressSlack" ---> "ForceCritical".
         *)(*
        11-Nov-90 AJL  -Within the MergeVaryingAssignmentLists procedure,
                        there was a "<>" that should have been "=", and 
                        also an "=" that should have been "<>".
                       -Changed from a V[n] array to V1 and V1 in same proc.
                        The array was tricking the optimizer.
                       -Set Start to MAX(ADate) when dates ran out in the
                        same proc, subproc Scratch.
                       -Clean up some problems with ambiguous variable names
                        that were preventing the dates from the newtask
                        record while reading tasks from being referenced
                        properly.
        16-Nov-90 AJL  -Allow reading of tasks based on their WBS codes.
        10-Jan-91 AJL  -Don't import readTextLine.
         4-Feb-91 AJL  -Add more error messages.
         6-Feb-91 AJL  -Increased the size of the string used for extracting
                        the WBS number, path, etc. from the text.
         7-Feb-91 AJL  -If we didn't actually read any resources, replace the
                        handle to the (empty) assignment array with a NIL handle.
       12-Apr-91 AJL  - Use the DataFiles module for subfile numbers.
                      - Read the Counts subfile and use it to put up a 
                        thermometer for tasks and edges.
        8-May-91  AJL - Added a new DuplicateItems parameter to reading
                        of assignments.
       13-Jun-91  AJL - Stop reading when we finish with the task we were 
                        linking to.
                      - The HeaderType constant had somehow gotten changed
                        to 9!  It should be zero.
       27-Jun-91  AJL - Changed CreateVaryingAssgnListEntry to return BOOLEAN.
       17-JUl-91  AJL - When reading assignments from versions prior to 5.0,
                        supplement the assignment structures with varying
                        assignment lists that match the task.  This way,
                        we can read profiles of version 3 and 4 schedules.
        8-Aug-91  EGK - Set the DurationMethod of the rollup task to be
                        DurationDriven.  It had been set to AssignmentDriven,
                        which was causing problems later on (mostly because
                        we don't support that type any more).  (See Eve bug
                        #4949.)
       18-Sep-91  EGK - Don't set the task type to FixedDate any more; let
                        the user pick something like ASAP if they want and
                        honor that even after re-retrieving the linked
                        schedule.  Eve bug #4951.
       23-Sep-91  EGK - Don't put "NoSoonerStart" or "NoLaterStart" in the
                        task flag set.  That didn't work so well when the
                        user set a linked task to be "ASAP".  Eve bug #4951
                        revisited (reopened).
       26-Sep-91  AJL  -Add BOOLEAN return value to ReadAssignmentArray.
       27-Sep-91  AJL  -No longer force linked tasks to ForceCritical.
                       -If we are not bringing in resources, force the
                        task to be duration/split.
       17-Dec-91  LAA   In GetSummary, I created a new sub-procedure called
                        UpdateTheLinkingTask, and called this only when "ok".
                        This was so I can set ok to FALSE when a WBS code
                        can't be found, to fix bug 5386.  I also did a bit
                        of code reorganization.  Bug #5371 was also fixed,
                        so that links to a task by WBS will bring over the
                        percent achieved, even if there are no resources.
       20-Jan-92  AJL   Use LinkSupport module.
       29-Jan-92 AJL  - Changed rate parameters to REAL.
       25-Feb-92  AJL - Force end dates >= start dates.
       03-Mar-92 LAA    In GetSummary, for the case of DateBlockPlan, moved
                        the setting of FoundOne inside the IF where it was
                        before.  This was causing all links to tasks in other
                        schedules to result in a milestone at the start of
                        time, UNLESS the task being linked to was the very
                        first task in the file.
       06-Apr-92  AJL - Since a milestone is a point in time, it cannot really
                        be started.  If it is claimed as "Started," perhaps because
                        it is the end moment of a started task, then the task may
                        be started, but the end moment is Future.  Bug 5507.
       10-Apr-92  AJL - If a link is made to a specific task, take its 
                        percent achieved as entered in the source schedule.
                        If to an entire other schedule, roll up the outermost
                        tasks according to the rollup method of the source
                        schedule.
       16-Apr-92  AJL - Sum the spent and remaining effort and cost explicitly
                        rather than computing it from the varying assignment
                        arrays.  The trouble was that different tasks in the 
                        rolled-in schedule might have different end-of-spent
                        dates, leading to ambiguity over which portions of the
                        composite profile represented spent vs remaining effort.
                      - Modify the WeWantThisTask proc so that it does not change
                        the CollectPerformanceLevel.  It had been double counting
                        children when CopyResources was FALSE.
       20-Apr-92  AJL - The extra cost fields have been summed into the spent
                        and remaining costs fields in the source schedule.
                        The summarized assignment cannot have separate extra
                        costs.  That would double-count them.
       22-Apr-92  AJL - Since TL5 recalc does not allow the same resource 
                        twice in an assignment list, if a resource assignment
                        is sometimes billable and sometimes not in the source
                        schedule, make it always billable in the summarized
                        assignment.
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
        (* PROC *)              RemoveAssignmentsAndExpenses,
                                CopyOneAssignmentRecord;

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime;

FROM CalShift               IMPORT
    (* VAR  *)                  TimeSheet;

FROM Codes                  IMPORT ACode, EmptyCodeSet;

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
                                WarningBox, ADialogOption, MultipleChoiceBox,
                                NotYetImplemented, ErrorPhrase;

FROM Directory              IMPORT NormalizeFileName, AFileNamePart,
                                ASetOfFileNameParts;

FROM Duration               IMPORT
    (* PROC  *)                 FindDuration;

FROM FileAux                IMPORT PrepareForIO,
                                   DisplayFileError, CheckIO;

FROM FileSystem             IMPORT File, Response, Close,
                                   OpenFile, ReadOnlyMode,
                                   ReadByte, ReadWord;

FROM FlexStor               IMPORT
        (* TYPE *)              AnExtHandle, AnExtStoragePreference,
                                AnExtStatus,
        (* PROC *)              CreateExtObject, SetExtData, NumberOfElements,
                                ArraySize, DiscardExtObject,
                                HandleIsValid, GetExtSize, GetExtStatus,
                                LockObjectArray, SetExtSize,
                                ReleaseObject, ReleaseUnchangedObject;

FROM IResource      IMPORT
    (* TYPE *)          ADuplicateAction, AGetDupeActionProc,
    (* PROC *)          ReadAssignmentArray, GetResources;

IMPORT IV4Resources;

FROM Kbio                   IMPORT  maxcol,
    (* PROC *)                      EraseLn;

FROM Keys                   IMPORT CancelKey, HelpKey, DoIt;

FROM Layout                 IMPORT MenuStart, MenuEnd;

FROM Links                  IMPORT
        (* CONST *)             LinkOverlayNameLine, LinkFileTypeLine, LinkPathLine,
        (* TYPES *)             ALinkInterface, ARollupContext,
        (* PROC *)              GetSummaryInfoLine;

FROM LinkSupport            IMPORT
    (* PROC *)                  MergeVaryingAssignmentLists;

FROM LStrings               IMPORT SetString, LStringToTString, ConcatLS,
                                   Copy, ConcatS, SubStr, TrimRear, CtoS,
                                   StringsEqual, Insert, SetLengthOf, LengthOf,
                                   LJust, Procustes;

FROM LoadCommon             IMPORT  ErrorFlag, SkipRecordBody,
                                    AttachNodeOnTree;

FROM Menus                  IMPORT Menu;

FROM MsgFile                IMPORT  GetMessage, ConcatMessage;

FROM OBigTimeU              IMPORT
    (* PROC *)                  BigTimeToTime;

FROM ObjectID               IMPORT
    (* PROC *)                  NewID;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay, OverlayContext;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Planner                IMPORT
    (* TYPE *)                      ARollupWeighting,
    (* VAR *)                       RecalcOptions;

FROM Progress               IMPORT
    (* TYPE *)                      AThermometer,
    (* PROC *)                      CreateThermometer, UpdateThermometer, 
                                    DiscardThermometer;

FROM RecordIO               IMPORT  ReadRecord, ReadString, ReadRecordPreface,
                                    ReadRecordBody, ReadStringBody;

FROM RsrcCalc               IMPORT  SummTaskNodeAmounts;

FROM RsrcMod                IMPORT  AResourcePointer, ACostStyle,
                                    ResourceNameLength, CreateResource,
                                    AddResource, AResource,
                                    ChangedResource, ResourceTree,
                                    AResourceType,
                                    FindResourceByName, FindResourceByNumber;

FROM Schedule               IMPORT ProjectMedia;

FROM Subfiles               IMPORT  StartFileInput, StartSubfileInput;

FROM Space                  IMPORT  HeapAvailable, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT  ADR, SIZE, ADDRESS, TSIZE;

FROM Text                   IMPORT  TextExists, LineExists, CopyLine,
                                    Compress, AText, DiscardText;

FROM Timei                  IMPORT
    (* CONST*)                  MinDate, MaxDate, NoDuration,
    (* TYPE *)                  ADate, ADuration, ATimeInfo,
    (* PROC *)                  TtoTimeU, DurationToReal;

FROM Timeu                  IMPORT
    (* VAR *)                   FSMUPH,
    (* PROC *)                  UpScale, DownScale;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM Transfer               IMPORT
    (* TYPE *)                  AHeaderRecord;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;

FROM V3Tasks                IMPORT
    (* TYPE *)                  ATaskV3, AV3BigDateBlock,
    (* PROC *)                  ConvertTaskFromV3;

FROM V4Assignments          IMPORT
    (* PROC *)                  ReadV4AssignmentArray;

FROM V4Tasks                IMPORT
    (* TYPE *)                  ATaskV4, AV4BigDateBlock,
    (* PROC *)                  ConvertTaskFromV4;

FROM VaryAssgnment          IMPORT
    (* TYPE *)                  AVaryingAssgnListIndex, AVaryingAssgnList,
    (* PROC *)                  CreateVaryingAssgnList, DisposeVaryingAssgnList,
                                CopyVaryingAssgnList, GetVaryingAssgnListEntry,
                                CreateVaryingAssgnListEntry,
                                CreateVaryingAssgnListRange;


(*<TRACE
FROM FlexDisp IMPORT  HandleToString;
FROM TimeFormat  IMPORT
    (* TYPE *)        AnEndDateStyle,
    (* VAR   *)       DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)       TimeToString, TimeAsEndDateStyle, TimeUtoS;
FROM Tracer   IMPORT  PrintString, EndTrace;
TRACE>*)



CONST
    ModuleNumber = 27900;    (* For GetMessage *)

CONST
     HeaderType            = 0;
     PlanAssignmentsType   = 70;
     DateBlockPlan         = 90;
     OldCodingType         = 123;
     CodingType            = 124;
     FMAXCARDINAL          = 65535.0;
     Zero                  = 0.0;
     Point5                = 0.5;
     OneHundred            = 100.0;



CONST
    LinkFlagsLine       = 3;  (* Choice field settings on link form *)
    LinkWBSLine         = 4;  (* WBS code (15 chars max).  *)

    ResCopyFlag     = 1;    (* TRUE iff should copy resources *)
    EffortFlag      = 2;    (* TRUE iff roll up all efforts   *)
    LinkDateFlag    = 3;    (* TRUE iff end date only         *)

VAR
    RollupsCount        : CARDINAL;
    OverlayID           : AnOverlayID;

    CopyResources           : BOOLEAN;
    MakeMilestone           : BOOLEAN;

    RecordQuantities        : AQuantities;    (* How many recs of various types. *)

    CodingRecord            : RECORD 
                                  LineNumber : CARDINAL;
                                  S          : ARRAY [0..255] OF CHAR;
                              END;

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
    GetMessage(ModuleNumber+1,s);    (* "Detail file " *)
    DisplayFileError( f, s );        (* RSC 2/19/88    *)
END FileComplaint;




PROCEDURE GetDuplicateAction( VAR DuplicateName : ARRAY OF CHAR ):ADuplicateAction;
BEGIN
    RETURN Ignore;
END GetDuplicateAction;






PROCEDURE RenumberTheResource  (VAR Node    : ATreeNode;
                                    Context : ADDRESS   );
VAR
    Resource        : AResourcePointer;
BEGIN
    Resource                   := Node^.Methods^.GetDataObject (Node);
    IF (Resource^.WorkSpace <> NIL) AND 
       (Resource^.WorkSpace.OFFSET <> 0) THEN
        Resource^.ID           := Resource^.WorkSpace.OFFSET;
    ELSE
        Resource^.ID           := NewID();  (* Newly imported! *)
    END;

END RenumberTheResource;






PROCEDURE GetTheResources(VAR f:File);
CONST
    LAZLOVersion = 1;
    EVEVersion   = 2;

VAR
    Version : CARDINAL;
    ok      : BOOLEAN;
BEGIN
    IF (NOT StartSubfileInput(f,ResourceType,Version)) THEN
        RETURN;
    END;

    IF (Version = EVEVersion) THEN
            (* Use zero for count to suppress the thermometer. *)
        ok := GetResources(f,GetDuplicateAction,0);
    ELSIF (Version = LAZLOVersion) THEN
        ok := IV4Resources.GetResources( f );
    END;

END GetTheResources;








PROCEDURE FixAssignments ( Node     : ATreeNode );

VAR
    Task                : ATaskPtr;
    Assignments         : AnExtHandle;
    AssignmentArray     : AnAssignmentArray;
    Count               : CARDINAL;
    i                   : CARDINAL;
    RMaxRatePercent     : REAL;


BEGIN

    Task := Node^.Methods^.LockFlexStorDataObject (Node);

    Assignments := Task^.Plan.Assignments;
    Count := LockObjectArray (Assignments, AssignmentArray, TSIZE(AnAssignmentRecord));

    IF (Count > 0) THEN
        FOR i := 0 TO Count-1 DO
            WITH AssignmentArray^[i] DO
                IF ((Resource^.Type <> Employable)  OR
                    (Task^.duration =  NoDuration )) THEN
                    MaxRatePercent := 100;
                ELSE
                    RMaxRatePercent := (OneHundred *
                                       (ActualQuantity+YetToGoQuantity) /
                                       (DurationToReal(Task^.duration)/FSMUPH))
                                       + Point5;
                    IF (RMaxRatePercent >= FMAXCARDINAL) THEN
                        MaxRatePercent := MAX(CARDINAL);
                    ELSE
                        MaxRatePercent := TRUNC(RMaxRatePercent);
                    END;
                END;

                IF (MaxRatePercent > 100) THEN
                    PercentageEach := CHR(100);
                ELSE
                    PercentageEach := CHR(MaxRatePercent);
                END;

                IF (Resource^.Type = Employable) THEN
                    INCL (Attributes, AllowLevel);
                ELSE
                    EXCL (Attributes, AllowLevel);
                END;
                EXCL (Attributes, Overloaded);
                INCL (Attributes, ComputeByHours);
            END;
        END;
    END;

    ReleaseObject (Assignments);

    Node^.Methods^.UnlockFlexStorDataObject (Node);

END FixAssignments;













PROCEDURE MergeAssignmentRecords ( VAR Source      : AnAssignmentRecord;
                                   VAR Dest        : AnAssignmentRecord );
VAR
    NewList : AVaryingAssgnList;
BEGIN
    WITH Dest DO
        ActualQuantity  := ActualQuantity  + Source.ActualQuantity;
        YetToGoQuantity := YetToGoQuantity + Source.YetToGoQuantity;

            (* If there are varyable assignments on the source record,
               copy or merge them onto the dest record.
            *)
        IF (Source.VaryingAssignment <> AVaryingAssgnList(NIL)) THEN

                (* If there is no existing varying assignment list,
                   just copy the source list to the dest handle.
                *)
            IF (VaryingAssignment = AVaryingAssgnList(NIL)) THEN
                CopyVaryingAssgnList( VaryingAssignment, Source.VaryingAssignment, ExtSlow );

            ELSE

                    (* Otherwise, we must merge the two lists togeather, and,
                       if that is successfull, copy the merged list to the
                       dest and dispose of the old dest.
                    *)
                NewList := MergeVaryingAssignmentLists( VaryingAssignment, Source.VaryingAssignment );

                IF (NewList <> AVaryingAssgnList(NIL)) THEN
                    DisposeVaryingAssgnList( VaryingAssignment );
                    VaryingAssignment := NewList;
                        (* When we are merging two varying assignment lists
                           their spending may have ended at different times.
                           This is a general problem on any kind of rollup,
                           and maybe should be handled by two varying assignment
                           lists: one for spent amounts and one for to-go
                           amounts.  Currently, we use the earlier date.
                           Is this right?  *)
                    IF (Source.EndOfSpentDate < EndOfSpentDate) THEN
                        EndOfSpentDate :=  Source.EndOfSpentDate;
                    END;
                END;
            END;
        END;
    END;
END MergeAssignmentRecords;




(* Add information from the AssignmentRecord to the DestAssignments. *)

(* ON ENTRY, THE ARRAY IS LOCKED.
   ON EXIT,  THE ARRAY MUST STILL BE LOCKED!!
*)


PROCEDURE AddAssignment ( VAR AssignmentRecord : AnAssignmentRecord;
                          VAR DestAssignments  : AnExtHandle;
                          VAR DestArray        : AnAssignmentArray;
                          VAR Count            : CARDINAL
                        ) : BOOLEAN;
VAR
    NewSize             : CARDINAL;
    i                   : CARDINAL;
    s                   : ARRAY [0..99] OF CHAR;
    ok                  : BOOLEAN;

BEGIN

        (*  See if there is an existing assignment to the same resource
            in this array already.  If so, just accumulate our data into
            that same assignment.
        *)

    IF (Count > 0) THEN
        FOR i := 0 TO Count-1 DO
            IF (DestArray^[i].Resource = AssignmentRecord.Resource) THEN

                    (*  Found it, so just merge in the data, without
                        changing the size of the dest array.    *)

                MergeAssignmentRecords (AssignmentRecord, DestArray^[i]);

                    (*  If we find one, but the billable flag is different,
                        then we must pick either billable or not for the 
                        whole assignment since TL5 does not allow the 
                        same resource to be listed twice on a task
                        (problems for levelling).  I would hope that
                        recalc can be changed in the future to allow 
                        the same resource twice, at least for linked
                        schedules.    AJL 4/22/92 *)

                IF ((Billable IN DestArray^[i].Attributes) <>
                   (Billable IN AssignmentRecord.Attributes))      THEN
                    INCL(DestArray^[i].Attributes, Billable);  (* Make it billable. *)
                END;

                RETURN TRUE;
            END;
        END;
    END;

        (*  We didn't find it.  Bump up the size of the array by one, and
            copy this assignment to the end position.   *)

    ReleaseUnchangedObject (DestAssignments);
    NewSize := ArraySize (Count+1, TSIZE(AnAssignmentRecord));

    ok := (SetExtSize (DestAssignments, NewSize));

    Count := LockObjectArray (DestAssignments, DestArray, TSIZE(AnAssignmentRecord));

    IF (NOT ok) OR (Count=0) THEN
        GetMessage (ModuleNumber+3, s);    (* "Not enough memory available" *)
        Error (s);
    ELSE
        (*$O-*)  (* We don't trust the optimizer on complicated array
                    dereferences. *)
        CopyOneAssignmentRecord(DestArray^[Count-1],
                                AssignmentRecord,     ExtMedium );
           (* The extra cost fields have been summed into the spent
              and remaining costs.  The summarized assignment cannot
              have separate extra costs.  That would double-count them. *)
        DestArray^[Count-1].ExtraCosts := Zero;
        (*$O=*)
    END;

    RETURN ok;

END AddAssignment;



    (* SupplementAssignments--

       For each of the assignments in the list, create a varying
       assignment that has the resource working at the single 
       rate over the course of the task.

    *)



PROCEDURE SupplementAssignments( StartDate, EndDate : ADate;
                                 AssignmentsHandle : AnExtHandle ) : BOOLEAN;
VAR
    Assignments : AnAssignmentArray;
    i, NumberOfAssignments : CARDINAL;
    ok : BOOLEAN;
BEGIN
            (*<TRACE
            SetString(TraceS,"    SupplementAssignments, Start = ");
            TimeUtoS(StartDate,TraceS2);  ConcatLS(TraceS,TraceS2);
            ConcatS(TraceS,", End = ");
            TimeUtoS(EndDate,TraceS2);  ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
            TRACE>*)

    IF (AssignmentsHandle = AnExtHandle(NIL)) THEN
        RETURN TRUE;
    END;

    ok := TRUE;

    NumberOfAssignments := LockObjectArray(AssignmentsHandle, Assignments,
                                           TSIZE(AnAssignmentRecord));
    FOR i := 0 TO NumberOfAssignments - 1 DO
        WITH Assignments^[i] DO
                (* As a safety check, remove any existing data. *)
            IF (VaryingAssignment <> AnExtHandle(NIL)) THEN
                DisposeVaryingAssgnList( VaryingAssignment );
            END;
                (* Create a single, uniform interval covering the 
                   entire task duration. *)
            IF (ok) AND (Resource^.Type <> AccountingOnly) THEN 
                ok := CreateVaryingAssgnListRange( VaryingAssignment,
                                                   StartDate, EndDate,
                                                   FLOAT(MaxRatePercent) );
            END;
        END;
    END;

    ReleaseObject( AssignmentsHandle );

    RETURN ok;
END SupplementAssignments;






    (* AddAssignmentArray -- Reads assignment records from the file.
                             Adds the assignment records and their 
                             varying assignments and expenses to "Total".
    *)



PROCEDURE AddAssignmentArray   (VAR f           : File;
                                    Length      : CARDINAL;
                                    Total       : AnExtHandle;
                                    TaskVersion : CARDINAL;
                                    StartDate, EndDate : ADate ) : BOOLEAN;
VAR
    DestArray,
    AssignmentArray         : AnAssignmentArray;
    BadItems,
    DestCount,
    NewAssignmentCount      : CARDINAL;
    i                       : CARDINAL;
    NewHandle               : AnExtHandle;
    DuplicateItems,
    ok                      : BOOLEAN;



BEGIN
    ok       := TRUE;
    BadItems := 0;
    DuplicateItems := FALSE;

    IF (TaskVersion = 50) THEN
        ok := ReadAssignmentArray( f, Length, NewHandle, BadItems, DuplicateItems );

    ELSIF (TaskVersion = 30) OR (TaskVersion = 40) THEN
        IF (ReadV4AssignmentArray( f, Length, NewHandle, BadItems,
                                       DuplicateItems )) THEN
                (* Tasks from versions before V5 did not have varying assignment
                   lists.  We need to create them so that they will contain
                   complete assignment structures. *)
            ok := SupplementAssignments(StartDate, EndDate,
                                        NewHandle);
        ELSE
            BadItems := 1;  (* At least. *)
        END;
    ELSE
        ok := FALSE;
    END;

        (* NewHandle is now an assignment array containing the assignments,
           varying assignments and expenses (or else ok is FALSE.)  *)


    IF (ok) THEN
        IF (BadItems <> 0) THEN
            ErrorFlag := TRUE;
            ErrorPhrase(ModuleNumber+4);
        END;
        IF (DuplicateItems) THEN
            ErrorFlag := TRUE;
            ErrorPhrase(ModuleNumber+11);
        END;

        NewAssignmentCount := LockObjectArray( NewHandle, AssignmentArray, TSIZE(AnAssignmentRecord));
        DestCount          := LockObjectArray( Total,     DestArray,       TSIZE(AnAssignmentRecord));
        i := 0;
        WHILE (i < NewAssignmentCount) AND (ok) DO
(*$O-*)
            ok := AddAssignment(AssignmentArray^[i], Total, DestArray, DestCount );
(*$O=*)
            INC(i);
        END;

        ReleaseObject( Total );
        ReleaseObject(                NewHandle );
        RemoveAssignmentsAndExpenses( NewHandle );

    END;

    RETURN ok;

END AddAssignmentArray;








VAR
   WantedLevel,
   CollectPerformanceLevel : CARDINAL;
   RollupWeighting     : ARollupWeighting;
   WantMatchString : ARRAY [0..WBSLen+5] OF CHAR;


PROCEDURE WBSMatches    (  WBS1, WBS2  : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
    LJust (WBS1);
    TrimRear (WBS1);
    LJust (WBS2);
    TrimRear (WBS2);
    RETURN StringsEqual (WBS1, WBS2);
END WBSMatches;


    (* Decide if a task should be part of the link summarization. *)


PROCEDURE WeWantThisTask( VAR Task : ATask; 
                          VAR WBSCode : ARRAY OF CHAR;    
                              Level : CARDINAL ) : BOOLEAN;
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


        (* Otherwise, we want the task if its WBS code matches the
           one passed in. *)
    Want := WBSMatches(WantMatchString,WBSCode);
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
            SetString(TraceS,"Test for Want: ");  ConcatLS(TraceS,Task.taskname);
            ConcatS(TraceS,", WBS "); ConcatLS(TraceS,WBSCode); 
            IF (Want) THEN SetString(TraceS2,": Yes") ELSE SetString(TraceS2,": No") END;
            ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
            TRACE>*)
    RETURN Want;
END WeWantThisTask;




        (* QueryRollupValue -- Get the relative value of this task *)

PROCEDURE QueryRollupValue( VAR Task : ATask;
                            VAR Weighting : ARollupWeighting ) : REAL;
VAR
    ValueThisTask : REAL;
    BaselineExistsFlag : BOOLEAN;
BEGIN
    (* See the Rollups module for the basis of this procedure. *)

    BaselineExistsFlag := BaseLineExists IN Task.TaskFlags;

    CASE Weighting OF 
        RollBaseCost : 
            IF (BaselineExistsFlag) THEN
                ValueThisTask  := Task.BaseLineSummary.Amount;
            ELSE
                ValueThisTask := Zero;
            END;
      | RollBaseEffort :
            IF (BaselineExistsFlag) THEN
                ValueThisTask  := Task.BaseLineSummary.Time;
            ELSE
                ValueThisTask := Zero;
            END;
      | RollEffort : 
            ValueThisTask  := Task.ToGoSummary.Time
                              +Task.CompletedSummary.Time;
      | RollDuration :
            ValueThisTask := FLOAT(Task.duration);
      | RollOne :
            ValueThisTask := 1.0;   (* All tasks are equal. *)
    END;

    RETURN ValueThisTask;
END QueryRollupValue;




PROCEDURE BigTimeToTimeU( BigTime : ABigTime; VAR SmallTime : ADate );
VAR
    TimeInfo     : ATimeInfo;
    ok           : BOOLEAN;
BEGIN
    BigTimeToTime  (* THE OLD VERSION!!!!! *)
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






    (* Get these off the stack.
    *)
VAR
    newtask                 : ATask;
    newtaskV3               : ATaskV3;
    newtaskV4               : ATaskV4;


(*$S+*)   (* Stack check *)

PROCEDURE GetSummary(VAR f          : File;
                         Node       : ATreeNode;
                     VAR FirstDate,
                         LastDate   : ADate     )
                                                 : BOOLEAN;
TYPE
    AStatusSet = SET OF AStartStatus;

VAR
    TaskCount               : CARDINAL;
    Version                 : CARDINAL;
    TaskVersion,
    i                       : CARDINAL;
    ThisWBS                 : ARRAY [0..WBSLen] OF CHAR;
    CodingLineNo            : CARDINAL;
    ResourcePtr             : AResourcePointer;
    Duration                : REAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;
    Thermometer             : AThermometer;
    BigDateBlock            : ABigDateBlock;
    V4BigDateBlock          : AV4BigDateBlock;

    PercentComplete,
    WeightedValue,
    ValueThisTask,
    PercentThisTask,
    TotalValue              : REAL;
    Header                  : AHeaderRecord;
    CompletedSummary        : AnAssignmentSummary;
    ToGoSummary             : AnAssignmentSummary;
    BCWP                    : REAL;
    TempAssignments         : AnExtHandle;
    AssignmentArray         : AnAssignmentArray;
    StatusSet               : AStatusSet;
    ok                      : BOOLEAN;
    FoundOne                : BOOLEAN;
    DesireThisTask          : BOOLEAN;
    UserNotified            : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;


        (* Processing after each task is read. *)

    PROCEDURE WrapUp();
    BEGIN

        (*<TRACE
        IF (TaskCount > 0) THEN
            SetString(TraceS,"Wrap up: ");  ConcatLS(TraceS,newtask.taskname);
            Procustes(TraceS,40);
            IF (DesireThisTask) THEN SetString(TraceS2,": Desire=Yes") ELSE SetString(TraceS2,": Desire=No") END;
            ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
        END;
        TRACE>*)



           (* If we want this task, and it is the outermost level
              of the family we want, use its value and percent
              achieved.   We pick only the outermost tasks since they 
              already summarize their child tasks. *)

        IF (DesireThisTask) AND (Header.Level = CollectPerformanceLevel) THEN

                (* Add up the spent and remaining hours and money. *)

            IF (CopyResources) THEN
                CompletedSummary.Amount := CompletedSummary.Amount + newtask.CompletedSummary.Amount;
                CompletedSummary.Time   := CompletedSummary.Time   + newtask.CompletedSummary.Time;
                ToGoSummary.Amount      := ToGoSummary.Amount      + newtask.ToGoSummary.Amount;
                ToGoSummary.Time        := ToGoSummary.Time        + newtask.ToGoSummary.Time;
                    (* Add up the Budgetted Cost of Work Performed. *)
                BCWP := BCWP + newtask.BCWP;
            END;


            INCL (StatusSet, newtask.StartStatus);

            ValueThisTask := QueryRollupValue( newtask, RollupWeighting );

            PercentThisTask := FLOAT(newtask.PercentComplete)/OneHundred;

            WeightedValue   := WeightedValue +
                               (PercentThisTask * ValueThisTask);

            TotalValue := TotalValue + ValueThisTask;

        END;
    END WrapUp;


        (*  Actually update the task which links to another schedule (or task)
            if the reading of that schedule has gone well.  Uses some
            variables from the enclosing procedure.
        *)

    PROCEDURE UpdateTheLinkingTask(     Node : ATreeNode );

    VAR
        Task                : ATaskPtr;

    BEGIN                   (* UpdateTheLinkingTask *)

        Task := Node^.Methods^.LockFlexStorDataObject (Node);

        IF (StartedS IN StatusSet) OR
           (  ( StatusSet * AStatusSet{FutureS,DoneS}) = AStatusSet{FutureS,DoneS} ) THEN
            Task^.StartStatus := StartedS;
        ELSIF ( StatusSet = AStatusSet{DoneS}) THEN
            Task^.StartStatus := DoneS;
        ELSE
            Task^.StartStatus := FutureS;
        END;

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


        END;

            (* Since a milestone is a point in time, it cannot really
               be started.  If it is claimed as "Started," perhaps because
               it is the end moment of a started task, then the task may
               be started, but the end moment is Future. *)

        IF (Task^.Plan.Dates.EarlyStart = Task^.Plan.Dates.EarlyEnd) AND
           (Task^.StartStatus = StartedS) THEN

            Task^.StartStatus := FutureS;
            Task^.PercentComplete := 0;

        ELSIF (TotalValue = Zero) THEN

                (*  If we're linking to just one task, take its %Complete *)

            IF (LengthOf(WantMatchString)>0) THEN
                Task^.PercentComplete := TRUNC(PercentThisTask * OneHundred);
            ELSE
                Task^.PercentComplete := 0;
            END;
        ELSE
            PercentComplete := (OneHundred * WeightedValue / TotalValue) + Point5;
            IF (PercentComplete >= FMAXCARDINAL) THEN
                Task^.PercentComplete := MAX(CARDINAL);
            ELSE
                Task^.PercentComplete := TRUNC(PercentComplete);
            END;
        END;

           (* Remove the resource assignments of the current task and
              replace them with the resources read in. *)

        RemoveAssignmentsAndExpenses (Task^.Plan.Assignments);
        IF (CopyResources) THEN
            Task^.Plan.Assignments := TempAssignments;
        END;



        Task^.TempTaskFlags := ATempTaskFlagSet{};

        Node^.Methods^.UnlockFlexStorDataObject (Node);

        IF (CopyResources) THEN
            FixAssignments (Node);
        END;

        Task := Node^.Methods^.LockFlexStorDataObject (Node);
        Task^.CompletedSummary := CompletedSummary;
        Task^.ToGoSummary      := ToGoSummary;
        Task^.BCWP             := BCWP;
        Node^.Methods^.UnlockFlexStorDataObject (Node);

    END UpdateTheLinkingTask;

BEGIN
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

    FoundOne      := FALSE;
    UserNotified  := FALSE;

    ok := (GetExtStatus() = ExtGood) AND    (* 21-Aug-89 RSC *)
          (CreateExtObject (TempAssignments, ExtMedium));

    IF (ok) AND (StartSubfileInput(f,TaskType,Version)) THEN

            (* Prepare to display progress. *)
        EraseLn(1);
        GetMessage(ModuleNumber+10,s);
        TaskCount := VAL(CARDINAL,RecordQuantities[QTask]);
        IF (NOT CreateThermometer(Thermometer,0,1,s,TaskCount)) THEN
            Thermometer := AThermometer(NIL);
        END;
        TaskCount     := 0;


        LOOP
            ReadRecordPreface (f,Type,Length);
            IF (CheckIO(f) <> done) OR (NOT ok) THEN
                ok := FALSE;
        EXIT;
            END;

            CASE Type OF
                HeaderType :

                    (* Wrap up previous task: *)
                    WrapUp();

                        (* If we already have the task we want, and we
                           reach a task that is out of the family, then
                           we are finished. *)

                    IF (FoundOne) AND (NOT DesireThisTask) THEN
        EXIT;
                    END;


                    (* Read this task. *)
                    ReadRecordBody (f,Length,ADR(Header),SIZE(Header));
                    DesireThisTask := FALSE;

            |   TaskType :
                    SetLengthOf(ThisWBS,0);   (* None seen so far. *)
                    CodingLineNo := 0;

                    IF (Length = SIZE(newtask)) THEN
                        ReadRecordBody (f,Length,ADR(newtask),SIZE(newtask));
                        TaskVersion := 50;

                    ELSIF (Length = SIZE(newtaskV3)) THEN
                        ReadRecordBody (f,Length,ADR(newtaskV3),SIZE(newtaskV3));
                        Copy(newtaskV3.WBS,ThisWBS);
                        ConvertTaskFromV3 (newtaskV3, newtask, FALSE);
                        TaskVersion := 30;

                    ELSIF (Length = SIZE(newtaskV4)) THEN
                        ReadRecordBody (f,Length,ADR(newtaskV4),SIZE(newtaskV4));
                        ConvertTaskFromV4 (newtaskV4, newtask );
                        TaskVersion := 40;

                    END;

                        (* If we know enough now to make the decision, do so. *)
                    DesireThisTask := WeWantThisTask( newtask, ThisWBS, Header.Level );

                    INC(TaskCount);
                    IF (TaskVersion = 50) THEN
                        IF ((TaskCount MOD 16) = 0) THEN
                            UpdateThermometer(Thermometer,TaskCount);
                        END;
                    END;

            |   OldCodingType :     (* Text format for version 4.0 and earlier. *)

                        (* Coding types come before Big Date Blocks
                           in the file.

                           "Trust me."
                        *)

                    ReadStringBody(f, Length, ThisWBS);

                        (* If we haven't already decided we want the task,
                           decide now. *)
                    IF (CodingLineNo = WBSLine) AND (TaskVersion >= 40) AND 
                       (NOT DesireThisTask) THEN
                        DesireThisTask := WeWantThisTask( newtask, ThisWBS, Header.Level );
                    END;
                    INC (CodingLineNo);

            |   CodingType :       (* Text format for version 5.0 *)

                        (* Coding types come before Big Date Blocks
                           in the file.

                           "Trust me."
                        *)

                    ReadRecordBody(f, Length, ADR(CodingRecord), SIZE(CodingRecord));

                        (* If we haven't already decided we want the task,
                           decide now. *)
                    IF (CodingRecord.LineNumber = WBSLine) THEN
                        Copy(CodingRecord.S,ThisWBS);
                        IF (TaskVersion >= 40) AND (NOT DesireThisTask) THEN
                            DesireThisTask := WeWantThisTask( newtask, ThisWBS, Header.Level );
                        END;
                    END;

            |   DateBlockPlan :
                    IF (TaskVersion = 50) THEN
                        ReadRecordBody (f, Length, ADR(BigDateBlock), SIZE(BigDateBlock));
                        WITH newtask.Plan.Dates DO
                            EarlyStart := BigTimeToCalendarTime( BigDateBlock.EarlyStart );
                            EarlyEnd   := BigTimeToCalendarTime( BigDateBlock.EarlyEnd   );
                        END;

                    ELSIF (TaskVersion = 30) OR (TaskVersion = 40) THEN

                            (* V3 and V4 big date blocks are the same.
                               They require the OLD BIG TIME routines.

                               "Trust me."
                            *)

                        ReadRecordBody (f, Length, ADR(V4BigDateBlock), SIZE(V4BigDateBlock));

                        WITH newtask.Plan.Dates DO
                            BigTimeToTimeU (V4BigDateBlock.EarlyStart, EarlyStart );
                            BigTimeToTimeU (V4BigDateBlock.EarlyEnd,   EarlyEnd );
                        END;
                    END;


                    WITH newtask.Plan.Dates DO
                            (* Safety check.  TL before 25-Feb-92 could store
                               end dates on milestones as dates < start. *)
                        IF (EarlyEnd < EarlyStart) THEN
                            EarlyEnd := EarlyStart;
                        END;
                            (* Accumulate earliest and latest dates. *)
                        IF (DesireThisTask) THEN
                            IF (EarlyStart < FirstDate) THEN
                                FirstDate := EarlyStart;
                            END;
                            IF (EarlyEnd > LastDate) THEN
                                LastDate := EarlyEnd;
                            END;
                            FoundOne := TRUE;                  (* 03-Mar-92 *)
                        END;
                    END;

            |   PlanAssignmentsType :
                    IF (CopyResources) AND (DesireThisTask) THEN
                        ok := AddAssignmentArray (f,Length, TempAssignments,
                                                  TaskVersion,
                                                  newtask.Plan.Dates.EarlyStart,
                                                  newtask.Plan.Dates.EarlyEnd);
                    ELSE
                        SkipRecordBody (f, Length);
                    END;

            |   0FFH : EXIT;
            ELSE
                SkipRecordBody(f,Length);
            END;
        END;

            (* Finish processing the last task read. *)
        WrapUp();

        IF (Thermometer <> AThermometer(NIL)) THEN
            DiscardThermometer(Thermometer);
        END;

            (* Summarize all the tasks. *)

        IF (NOT FoundOne) THEN
            FirstDate := AsOfDate;
            LastDate  := AsOfDate;
            IF (LengthOf(WantMatchString)>0) THEN
                GetMessage(ModuleNumber+8,s);
                ConcatLS(s,WantMatchString);
            ELSE
                GetMessage(ModuleNumber+9,s);
            END;
            Error(s);
            ok := FALSE;                                       (* 17-Dec-91 *)
            UserNotified := TRUE;
        END;

        IF (FirstDate > LastDate) THEN
            FirstDate := LastDate;
        END;

           (* If we didn't actually read any resources, replace the handle
              to the (empty) assignment array with a NIL handle. *)

        IF (GetExtSize(TempAssignments) = 0) THEN
            DiscardExtObject(TempAssignments);
        END;

        IF (ok) THEN                                           (* 17-Dec-91 *)
            UpdateTheLinkingTask( Node );
        END;
    ELSE
        ok := FALSE;
    END;

    IF (CopyResources) THEN

            (* Restore the proper ID's as they were before the link.
               Here, we do NOT flush Undos.  Therefore, it is CRITICAL
               that the ID's come back the way they were.  New Resource
               records get new ID's.
            *)
        ResourceTree^.Methods^.TraverseTree (ResourceTree, ParentBeforeChild,
                                             9999, RenumberTheResource, NIL);
    END;

    IF ((NOT ok) AND (NOT UserNotified)) THEN
        GetMessage(ModuleNumber+5,s);   (*  "Missing summary data."  *)
        Error(s);
    END;

    RETURN ok;

END GetSummary;

(*$S=*)   (* Stack check *)



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




PROCEDURE GetRollupDates (VAR f         : File;
                              Node      : ATreeNode );
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

    GetCounts(f);

        (* Check the list of resources and costs of the detail
           schedule.  Add to our list any that we do not have. *)

    IF (CopyResources) THEN
        GetTheResources(f);
    END;

        (* Read in the summary data. *)

    ok := (GetSummary(f,Node,StartDate,EndDate)) AND
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
            (* fixation       := FixedDate;     9/18/91 EGK *)

            IF (NOT CopyResources) THEN
                DurationMethod := DurationDriven; (* 8/8/91 EGK *)
                SplittingRule  := Split;  
            END;
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



PROCEDURE GetRollupWeighting( VAR f : File ) : ARollupWeighting;
VAR
    Type,
    Length,
    Version : CARDINAL;
    i                       : CARDINAL;
    SomeBaselineExists      : BOOLEAN;
    LocalRecalcOptions      : RECORD
                                  AllowNegativeSlack : BOOLEAN;    (* Allow late start < early start. *)
                                  Smoothing          : BOOLEAN;    (* Try to reduce peaks and fill valleys. *)
                                  RollupWeighting    : ARollupWeighting;
                                  Filler             : ARRAY [0..48] OF BOOLEAN;
                              END;
BEGIN

    IF (NOT StartSubfileInput(f,EnvironmentType,Version)) THEN
        RETURN RecalcOptions.RollupWeighting;   (* If error, return current schedule's weighting. *)
    END;

    LocalRecalcOptions.RollupWeighting := RecalcOptions.RollupWeighting;
    SomeBaselineExists := TRUE;  (* Optimistic. *)

    LOOP
        ReadRecordPreface(f,Type,Length);
        CASE Type OF
            30   :   ReadRecordBody(f,Length,ADR(LocalRecalcOptions),SIZE(LocalRecalcOptions));
          | 34   :   ReadRecordBody(f,Length,ADR(SomeBaselineExists),SIZE(SomeBaselineExists));
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

        (* If they request to rollup by baseline, but there is no baseline,
           rollup each task at equal value. *)

    IF (NOT SomeBaselineExists) AND (LocalRecalcOptions.RollupWeighting < RollDuration ) THEN
        LocalRecalcOptions.RollupWeighting := RollOne;
    END;

    RETURN LocalRecalcOptions.RollupWeighting;

END GetRollupWeighting;




PROCEDURE TLLnkSumBody();

TYPE
    AContextPtr     = POINTER TO ARollupContext;
VAR
    ContextPtr      : AContextPtr;
    TaskPtr         : ATaskPtr;
    s               : ARRAY [0..99] OF CHAR;

BEGIN                       (* TLLnkSumBody *)

    s := "Program Copyright (c) 1989 Symantec Corporation.";
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
            

            (* Read the source schedule. *)

        IF (StartFileInput (f)) THEN        (* Check for bad format *)
            GetSummaryInfoLine (Node, LinkWBSLine, WantMatchString);
            IF (LengthOf(WantMatchString)=0) THEN
                WantedLevel := 0;          (* Read all tasks. *)
                CollectPerformanceLevel := 0;  (* Summarize achievement of outermost tasks. *)
                RollupWeighting := GetRollupWeighting(f);
            ELSE
                WantedLevel := MAX(CARDINAL);          (* Ignore tasks unless checked out. *)
                CollectPerformanceLevel := MAX(CARDINAL);
                RollupWeighting     := RollOne;        (* Single task, just take its percent achieved field. *)
            END;
            GetRollupDates (f, Node);
        ELSE
            TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
            DiscardText (TaskPtr^.summarizes);
            TaskPtr^.summarizes := AText(NIL);
            TaskPtr^.rollupstatus := NotRollup;
            Node^.Methods^.UnlockFlexStorDataObject (Node);
        END;
    END;


END TLLnkSumBody;


BEGIN                       (* TLLnkSum *)

    OverlayID := ImAnInstallableOverlay(TLLnkSumBody, AnOverlayProc(NIL));
    TLLnkSumBody();

END TLLnkSum.



