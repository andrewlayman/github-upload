(*V1=NORMAL Version*)
(*V3=OS2 OS2 code changes.	  *)
(*V4=DOS Regular DOS TL code. *)
(*V8=GELDED Version for debugging*)


(*<OS2
IMPLEMENTATION MODULE TLFilter;
OS2>*)
(*<DOS*)
MODULE TLFilter;
(*DOS>*)

    (* Need to do work on setting and resetting of FiltersOn. *)

    (* MODIFICATION HISTORY

       Sep. 3, 1985, AJL - Added support for default date format.

       Dec. 4, 1985, AJL - Expanded size of many text buffers.

       May  2, 1986  AJL - Enhanced for separate Reveal/Highlight
                           filters.

       Jul 16, 1986  AJL - CleanFilterSet will now make sure that
                           Resource names in the record actually
                           refer to real resources.  This is necessary
                           in case a File Combine loaded a filter
                           record with names of resources that do
                           not exist.
                         - Call CleanFilterSet from within DoFilterForm
                           as well as within Filter.
       07/23/86 LAA     Changed Code in CheckFilters to be a CARDINAL.              
        11/04/86 LAA    ChartState is now a set.
        11/26/86 LAA    Changed for the new Lights module.
        11/28/86 LAA    In Filter, set the state to Filtered unconditionally.
        12/04/86 LAA    Made changes for new FilterSet in the task record.
        12/08/86 LAA    Added initialization for HighlightFilterName, 
                        RevealFilterName, and F7Filtering.  ResetFilters now
                        uses FilterDefaults from FilterRc instead of doing it
                        itself.  ResetFilters now also resets all manual 
                        filters, and manual filter clear only resets that
                        task.
        12/16/86 LAA    Removed the filter form, and WFilter.  They are now
                        in FilterSelect.  No longer filter on the notes, but
                        do filter on the sort codes.
        5/7/87  EGK     Several changes to allow use of the task tree object
                        for filtering tasks.
        5/ 8/87 RSC    Altered the resource connections.
        5/19/87 RSC    Removed manuall filtering references.
        5/22/87 EGK     Made changes to support tasks as nodes.
        27-May-87 LAA   Added the GELDED and NORMAL version comments.
        01-Jun-87 LAA   Used new methods exported from TreeObjects for
                        TaskFwd, TaskBack, and AdjacentTask.
        04-Jun-87 LAA   Changed parameters for TraverseTree.
        06/09/87 EGK    Modified Filter to handle filter start and end dates
                        as strings.
        7/6/87  EGK     Added code for FLate filter type (late tasks).
        7/9/87  EGK     Added FilterMyAncestors to filter up to the top of
                        the task tree for filtering on dependencies and
                        resource usage.
        7/13/87 EGK     Added MarkEdges procedure in bfs to allow recursive
                        marking of dependencies of subtasks.
        7/28/87 AJL     Changed references from RunOver to RunMenu.
        7/29/87 EGK     Removed all references to manual filtering.
        7/30/87 EGK     Conversions for five highlight filters, including
                        internal dependency filters ([1], [2]) and user-
                        selected highlights ([3], [4], [5]).  These are now
                        copies of tree object pointers from the filter list.
        9/16/87 RSC     Moved init of lights region into init procedure.  
       10/14/87 EGK     Changed the meaning of "late" tasks.  A task is now
                        late if it has a baseline defined and the planned
                        EarlyEnd exceeds the baseline EarlyEnd.
       11/30/87 AJL     Parse end date using StoEndTimeU.
       16-Dec-87 LAA    Removed TaskIsIn, TaskIsHighlighted, and
                        CompletelyUnfilterNode, which are no longer used.
       12-Jan-88 RSC    "Unchanged" changes.
       15-Jan-88 EGK    Rewrote things so that we only make one pass through
                        the task tree.  Removed "bfs" procedure.
       11-Mar-88 RSC    dont Parse end date using StoEndTimeU.
       12-Oct-88 EGK    Added ParentsOpen procedure to keep TaskBack and TaskFwd
                        from returning a node which is invisible because an
                        ancestor task is closed.
       21-Nov-88 LAA    Changed imports for Lazlo reorganiation.
       23-Jan-89 EGK    Created this overlay from old Filters module.
       26-Jan-89 EGK    Get StringMatch from new Searcher module, which allows
                        wildcard patterns.
       05-May-89 EGK    Changed to use new scheme for WBS, OBS, and AUX.
       11-May-89 AJL   Added the "Needs Update" field.
       30-May-89 AJL   Moved filter records to FlexStor.
       15-Jun-89 AJL    Removed F7Filtering.
       19-Jun-89 AJL   Removed FiltersOn boolean.
       07-Jul-89 LAA    Pay attention to the new filter fields on the form, 
                        which allow filtering on any Gantt column.
       16-Jul-89 LAA    Put in use of the Inverted field.
       06-Aug-89 WKH    Initial OS/2 edits.
       09-Aug-89 KKC    Add copyright message.
       14-Aug-89 LAA    Fixed some bugs in filtering of the new fields.
       17-Aug-89 AJL    Added in a floating point tolerance allowing for 
                        the inexact representation of real numbers.  This is
                        NOT the same as testing that the string representation
                        of the number in the data column matches that typed
                        in.
       22-Aug-89 LAA    Filtering on date columns was not working because
                        the CompareTo field parsed correctly as a real number,
                        and the procedure doing this didn't know it was
                        supposed to be a date.
       24-Aug-89 EGK    Import procs from FilterUtility instead of FilterRc.
       31-Aug-89 LAA    Added a parameter to ParseAmountToReal.
        9-Sep-89 LAA    Fixed bug #1251 which reported that the Keywork, Obs,
                        and WBS fields of the filter form were not working
                        for exact matches.  Fixed by doing a trimrear before
                        trying to match the task's data.  Also downsized the
                        gs global string to match what it's used for, and 
                        moved gs2 from being global into MatchString.
       04-Jan-90 WKH    Import from VersionConflict to fix our arch nemesis,
                        the version conflict error.
       21-Feb-90  KKC   Remove import of Timeu.
       11-Apr-90  KKC   Replace all direct calculations on ADate and Duration
                        by calls to FindDuration, SubtractWorkingTime and
                        AddWorkingTime.
       02-Oct-90  DSL   Changed the logic a bit in CompareReals so that it
                        works as intended.
       23-Jan-91  AJL   Add AsOf parameter to AppropriateStartStatus.
       24-Jan-91  RSC   Keep the filters global to save a LOT of locks.
                        (<# of task> * <# of set filters>)

                        Also, avoid ulocking with WRITE whenever possible.
       29-May-91  LAA   In PrepareFilter, the FlexStor record was not being
                        updated with the changes caused by that routine, only
                        the FilterRecord parameter was changed.  This caused
                        problems in reports which start with a filter node,
                        and use fields which are only correct if the filter
                        has gone through PrepareFilter.
       25-Sep-91  LAA   In MatchDataField, I had arbitrarily limited the size
                        of the string for Captions to use to 24 bytes.  This
                        was causing some filtering to not work correctly.  I
                        changed this to arbitrarily limit it to 80 characters.
    *)

FROM Alarms                 IMPORT
    (* PROC *)                  AppropriateStartStatus;

FROM Lights                 IMPORT
    (* TYPE *)                  ALight,
    (* VAR *)                   ActiveLightRegion,
    (* PROC *)                  InstallLight, DisplayLight;

FROM Allocs   IMPORT  ATaskPtr, CheckTaskValid,
                      ATaskName, AStartStatus, ATaskFilter, ATaskFilterSet,
                      ATask, ATaskFlag, ATaskStatus, ATaskStatusSet,
                      AFixType, TaskTree,
                      WBSLine, OBSLine, AUXLine, GetCodingField;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;

FROM Assignments            IMPORT
    (* PROC *)                  ForEachAssignment, AnAssignmentRecord;

FROM CalShift  IMPORT   
    (* VAR  *)          TimeSheet;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnDataRecord, AColumnDataField,
                                ASetOfColumnDataFields, AColumnInfoChoice,
    (* PROC *)                  GetColumnString, GetColumnValue, GetColumnInfo;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* VAR *)                   ChartState,
    (* PROC *)                  SetState, UnSetState;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError,
                                Message, Burp;

FROM Duration               IMPORT
    (* PROC *)                  FindDuration;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr,
    (* PROC *)                  ItDepends, CheckEdgeValid;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFltrType, AFltrSet, 
                                AFilterRecord, AFilterRecordPointer,
                                AFilterMatch, ASlackCheck,
    (* VAR *)                   RevealFilter, HighlightFilter,
                                EmptyFilterSet;

FROM FilterUtility          IMPORT
    (* PROC *)                  SetFilterBit, TestFilterBit,
                                CleanFilterRecord;

FROM Kbio                   IMPORT avidmode;

FROM LStrings               IMPORT  ConcatLS, Upshift, Fill, SetString,
                                Remove, SubStr, LJust, TrimRear, TrimFront,
                                Search, Copy, LengthOf, StoC;

FROM MagicNum               IMPORT
    (* CONST *)                 IsRealValue, IsCurrency, IsEffort, IsDuration, 
                                IsSlack, IsDurationUnits, IsEffortUnits, 
                                IsIntValue, IsCardValue, IsStartDate, 
                                IsEndDate, IsMilestoneEnd, IsBigStart, 
                                IsBigEnd;

FROM MsgFile                IMPORT  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM ParseReal              IMPORT
    (* PROC *)                  ParseAmountToReal;

FROM ParseTime              IMPORT
    (* PROC *)                  StoTimeU;

FROM RealFormat             IMPORT
    (* VAR *)                   DefaultAmountFormat;

FROM RsrcMod                IMPORT  AResourcePointer, ResourceTree, FindResourceByName;

FROM Searcher               IMPORT
    (* PROC *)                  StringMatch;

FROM Space                  IMPORT ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT ADR, ADDRESS;

FROM TimeFormat             IMPORT
    (* PROC *)                  TimeUtoS;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate, ADurationCounter,
    (* PROC *)                  DurationToReal,
    (* CONST*)                  MaxDate, MinDate, NoDuration;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder, ATreeNodeProcessingProc;

FROM VersionConflict        IMPORT
    (* PROC *)                  ConflictProc;

FROM WorkHours              IMPORT
    (* PROC *)                  WorkHoursToRealTime;

IMPORT                      Gantt;


CONST
    Tolerance    = 0.000000025;    (* Equality Limit *)

VAR
    GResource    : AResourcePointer;

    OverlayID    : AnOverlayID;

    GlobalRF     : AFilterRecord;                  (* RevealFilter *)
    GlobalHF     : ARRAY [1..5] OF AFilterRecord;  (* Highlight filters *)


    gs           : ARRAY [0..31] OF CHAR;                         (* 09-Sep-89 LAA *)










    (* TaskMatch -- Does the task contain a given character
                    string? If so, where?   Note: this routine
                    assumes that the pattern is all upper
                    case. *)

PROCEDURE TaskMatch ( VAR task          : ATask;
                          FilterType    : AFltrType;
                      VAR Filter        : AFilterRecord
                                                              ) : BOOLEAN;
VAR
    s2          : ARRAY [0..255] OF CHAR;
BEGIN

    (*<NORMAL*)  
    CASE FilterType OF
        FNameHas   : Copy (task.taskname,s2);
    |   FWBSHas    : GetCodingField (task, WBSLine, s2);
    |   FOBSHas    : GetCodingField (task, OBSLine, s2);
    |   FAUXHas    : GetCodingField (task, AUXLine, s2);
        ELSE         FatalError;
    END;

    TrimRear(s2);                                                 (* 09-Sep-89 LAA *)
    WITH Filter.Match[FilterType] DO
        RETURN StringMatch(Pattern,s2,Type);
    END;
    (*NORMAL>*)

END TaskMatch;



 (* RSC - Massive changes 5/8/87 START HERE *)

PROCEDURE MatchString( VAR Assignment : AnAssignmentRecord;
                           Ptr        : ADDRESS     ) : BOOLEAN;

VAR 
    MatchFound              : POINTER TO BOOLEAN;
    gs2                     : ARRAY [0..21] OF CHAR;  

BEGIN

    Copy (Assignment.Resource^.Keyword, gs2);
    IF (StringMatch(gs, gs2, ItContains)) THEN
        MatchFound  := Ptr;
        MatchFound^ := TRUE;
        RETURN FALSE; (* do not continue *)
    END;

    RETURN TRUE; (* Continue to next item *)

END MatchString;




PROCEDURE ResourceStringMatch(      Task   : ATaskPtr;
                                VAR Filter : AFilterRecord
                                                              ) : BOOLEAN;
VAR
    MatchFound : BOOLEAN;
BEGIN

    (*<NORMAL*)  
    Copy (Filter.Match[FRNameHas].Pattern, gs);
    MatchFound := FALSE;
    ForEachAssignment (Task^.Plan.Assignments, MatchString, ADR(MatchFound));
    RETURN MatchFound;
      (*NORMAL>*)

    (*<GELDED
    RETURN FALSE;
    GELDED>*)

END ResourceStringMatch;




    PROCEDURE MatchRsrc( VAR Assignment : AnAssignmentRecord;
                             Ptr        : ADDRESS     ) : BOOLEAN;
    VAR MatchFound : POINTER TO BOOLEAN;
    BEGIN

        (*<NORMAL*)  
        IF Assignment.Resource = GResource THEN
            MatchFound  := Ptr;
            MatchFound^ := TRUE;
            RETURN FALSE; (* do not continue *)
        END;
        RETURN TRUE; (* Continue to next item *)
          (*NORMAL>*)

        (*<GELDED
        RETURN TRUE;
        GELDED>*)

    END MatchRsrc;


PROCEDURE TaskUsesResource(Task:ATaskPtr; Resource:AResourcePointer):BOOLEAN;
VAR MatchFound : BOOLEAN;
BEGIN

    (*<NORMAL*)  
    GResource  := Resource;
    MatchFound := FALSE;
    ForEachAssignment( Task^.Plan.Assignments, MatchRsrc, ADR(MatchFound) );
    RETURN MatchFound;
      (*NORMAL>*)

    (*<GELDED
    RETURN FALSE;
    GELDED>*)

END TaskUsesResource;

 (* RSC - Massive changes 5/8/87 END HERE *)



PROCEDURE SetTaskFilter (   Node        : ATreeNode;
                            TaskLocked  : ATaskPtr;
                            Variety     : ATaskFilter;
                        VAR LocalFilterSet : ATaskFilterSet;
                            Value       : BOOLEAN       );
VAR
    TaskPtr         : ATaskPtr;
BEGIN
    IF (Variety = Selected) THEN
        Node^.Methods^.SetVisible (Node, Value);
    END;
    IF (TaskLocked <> NIL) THEN
        TaskPtr := TaskLocked;
    ELSE
        TaskPtr        := Node^.Methods^.LockFlexStorDataObject (Node);
        LocalFilterSet := TaskPtr^.FilterSet;
    END;

    IF (Value) THEN
        INCL (LocalFilterSet, Variety);
    ELSE
        EXCL (LocalFilterSet, Variety);
    END;

    IF (TaskLocked = NIL) THEN
        IF (TaskPtr^.FilterSet = LocalFilterSet) THEN
            Node^.Methods^.UnlockUnchangedDataObject (Node);
        ELSE
            TaskPtr^.FilterSet := LocalFilterSet;
            Node^.Methods^.UnlockFlexStorDataObject (Node);
        END;
    END;

END SetTaskFilter;





    (*  FilterAllTasks
                 Run through the tasks and set up the FilterRecordet in each
                 to determine which of the active FilterRecord it matches and
                 which ones it does not.

                 The set "fltrset" in the FilterRecord structure indicates
                 which filter types are currently turned on.  The matching
                 item in each task's set will be present iff the task passes
                 that filter.
    *)

PROCEDURE DoOneFilter (     Node        : ATreeNode;
                            Task        : ATaskPtr;
                        VAR FilterRecord: AFilterRecord;
                        VAR LocalFilterSet : ATaskFilterSet;
                            Variety     : ATaskFilter   );


VAR
    ParentNode      : ATreeNode;
    RNode           : ATreeNode;
    Resource        : AResourcePointer;
    TaskStatus      : ATaskStatusSet;
    ParentFilterSet : ATaskFilterSet;
    LocalSet        : AFltrSet;
    FilterType      : AFltrType;
    In              : BOOLEAN;
    ParentsToo      : BOOLEAN;


    PROCEDURE GetValueToCompare(VAR CompareTo    : ARRAY OF CHAR;
                                    DataType     : CARDINAL;
                                VAR CompareValue : AColumnDataRecord);

    VAR
        i, j                : CARDINAL;
        r                   : REAL;
        ok                  : BOOLEAN;
        TmpDate             : ADate;

    BEGIN                   (* GetValueToCompare *)

        CompareValue.DataFields := ASetOfColumnDataFields{};
        TrimRear(CompareTo);
        CASE DataType OF
            IsRealValue, IsCurrency, IsDuration, IsEffort, IsSlack,
            IsIntValue, IsCardValue :
                i := 1;
                j := StoC(CompareTo, i);
                IF (i > LengthOf(CompareTo)) THEN
                    CompareValue.CardinalValue := j;
                    INCL(CompareValue.DataFields, CardinalInUse);
                    RETURN;
                END;

                i := 1;
                ParseAmountToReal(CompareTo, DefaultAmountFormat, r, ok, i); (* 31-Aug-89 LAA *)
                IF (ok) THEN
                    CompareValue.RealValue := r;
                    INCL(CompareValue.DataFields, RealInUse);
                    RETURN;
                END;
        |   IsStartDate, IsEndDate, IsMilestoneEnd, IsBigStart, IsBigEnd :
                IF (StoTimeU(CompareTo, TmpDate)) THEN
                    CompareValue.DateValue := TmpDate;
                    INCL(CompareValue.DataFields, DateInUse);
                    RETURN;
                END;
        ELSE
        END;

        CompareValue.CardinalValue := 0;
        INCL(CompareValue.DataFields, CardinalInUse);

    END GetValueToCompare;


    PROCEDURE CompareCards(    TaskValue    : CARDINAL;
                               Comparison   : AFilterMatch;
                               CompareValue : CARDINAL    ) : BOOLEAN;

    VAR
        result              : BOOLEAN;

    BEGIN                   (* CompareCards *)

        CASE Comparison OF
            ItIsEqual :
                result := (TaskValue = CompareValue);

        |   ItIsNotEqual :
                result := (TaskValue <> CompareValue);

        |   ItIsGreater :
                result := (TaskValue > CompareValue);

        |   ItIsGreaterEqual :
                result := (TaskValue >= CompareValue);

        |   ItIsLess :
                result := (TaskValue < CompareValue);

        |   ItIsLessEqual :
                result := (TaskValue <= CompareValue);
        ELSE
            FatalError();
        END;

        RETURN result;

    END CompareCards;


    PROCEDURE CompareDates(    TaskValue    : ADate;
                               Comparison   : AFilterMatch;
                               CompareValue : ADate    ) : BOOLEAN;

    VAR
        result              : BOOLEAN;

    BEGIN                   (* CompareCards *)

        CASE Comparison OF
            ItIsEqual :
                result := (TaskValue = CompareValue);

        |   ItIsNotEqual :
                result := (TaskValue <> CompareValue);

        |   ItIsGreater :
                result := (TaskValue > CompareValue);

        |   ItIsGreaterEqual :
                result := (TaskValue >= CompareValue);

        |   ItIsLess :
                result := (TaskValue < CompareValue);

        |   ItIsLessEqual :
                result := (TaskValue <= CompareValue);
        ELSE
            FatalError();
        END;

        RETURN result;

    END CompareDates;


    PROCEDURE CompareReals(    TaskValue    : REAL;
                               Comparison   : AFilterMatch;
                               CompareValue : REAL        ) : BOOLEAN;

    VAR
        result              : BOOLEAN;

    BEGIN                   (* CompareReals *)
    (* The logic here is this: We define all the points in 
     * the interval x-tolerance to be equal to x.
     * Andrew likes to call this an equivalence class. In order that no two
     * intervals overlap, we leave one end of each open. I have arbitrarily
     * chosen the lower bound to be open.
     * If you have questions about how we make the tests, I suggest drawing
     * a number line, and marking off what gets considered as equal, 
     * less than, etc.                    -DSL
     *)


        CASE Comparison OF
            ItIsEqual :
                result := (TaskValue > CompareValue - Tolerance)
                          AND (TaskValue <= CompareValue + Tolerance);

        |   ItIsNotEqual :
                result := NOT CompareReals(TaskValue,ItIsEqual,CompareValue);

        |   ItIsGreater :
                result := (TaskValue > CompareValue + Tolerance);

        |   ItIsGreaterEqual :
                result := (TaskValue > CompareValue - Tolerance);

        |   ItIsLess :
                result := (TaskValue < CompareValue - Tolerance);

        |   ItIsLessEqual :
                result := (TaskValue <= CompareValue + Tolerance);
        ELSE
            FatalError();
        END;

        RETURN result;

    END CompareReals;


    PROCEDURE ValuesMatch(VAR TaskValue     : AColumnDataRecord;
                          VAR CompareValue  : AColumnDataRecord;
                              Comparison    : AFilterMatch     ): BOOLEAN;

    VAR
        result              : BOOLEAN;

    BEGIN                   (* ValuesMatch *)

        result := FALSE;

        IF (CardinalInUse IN CompareValue.DataFields) THEN
            IF (CardinalInUse IN TaskValue.DataFields) THEN
                result := CompareCards(TaskValue.CardinalValue, Comparison,
                                       CompareValue.CardinalValue);
            ELSIF (RealInUse IN TaskValue.DataFields) THEN
                IF (TimeUnitInUse IN TaskValue.DataFields) THEN
                    TaskValue.RealValue := 
                        WorkHoursToRealTime(TaskValue.RealValue,
                                            TaskValue.TimeUnitValue);
                END;
                result := CompareReals(TaskValue.RealValue, Comparison,
                                       FLOAT(CompareValue.CardinalValue));
            ELSIF (DurationInUse IN TaskValue.DataFields) THEN
                result := CompareCards(TaskValue.DurationValue, Comparison,
                                       CompareValue.CardinalValue);
            ELSIF (IntegerInUse IN TaskValue.DataFields) THEN
                IF (TaskValue.IntegerValue > 0) THEN
                    result := CompareCards(ORD(TaskValue.IntegerValue), 
                                           Comparison,
                                           CompareValue.CardinalValue);
                END;
            END;

        ELSIF (RealInUse IN CompareValue.DataFields) THEN
            IF (CardinalInUse IN TaskValue.DataFields) THEN
                result := CompareReals(FLOAT(TaskValue.CardinalValue),
                                       Comparison,
                                       CompareValue.RealValue);
            ELSIF (RealInUse IN TaskValue.DataFields) THEN
                IF (TimeUnitInUse IN TaskValue.DataFields) THEN
                    TaskValue.RealValue := 
                        WorkHoursToRealTime(TaskValue.RealValue,
                                            TaskValue.TimeUnitValue);
                END;
                result := CompareReals(TaskValue.RealValue, Comparison,
                                       CompareValue.RealValue);
            ELSIF (DurationInUse IN TaskValue.DataFields) THEN
                result := CompareReals
                          (
                            DurationToReal( TaskValue. DurationValue ),
                            Comparison,
                            CompareValue.RealValue
                          );
            ELSIF (IntegerInUse IN TaskValue.DataFields) THEN
                result := CompareReals(FLOAT(TaskValue.IntegerValue),
                                       Comparison,
                                       CompareValue.RealValue);
            END;
            
        ELSIF (DateInUse IN CompareValue.DataFields) THEN
            IF (DateInUse IN TaskValue.DataFields) THEN
                result := CompareDates(TaskValue.DateValue, Comparison,
                                       CompareValue.DateValue);
            END;
        END;

        RETURN result;

    END ValuesMatch;


    PROCEDURE MatchDataField(    FilterType : AFltrType): BOOLEAN;

    VAR
        Value               : AColumnDataRecord;
        CompareValue        : AColumnDataRecord;
        TempValue           : AColumnDataRecord;
        s                   : ARRAY [0..255] OF CHAR;

    BEGIN                   (* MatchDataField *)

        WITH FilterRecord.DataField[FilterType] DO
            IF ((CompareAs >= ItBegins) AND (CompareAs <= ItMatches)) THEN
                IF (GetColumnString(Node,Task,FieldId,Gantt.Plan,80,s)) THEN   (* 24-Sep-91 *)
                    TrimFront(s);
                    TrimRear(s);
                    IF (StringMatch(CompareTo, s, CompareAs)) THEN
                        RETURN (NOT Inverted);
                    END;
                END;
            ELSIF (GetColumnValue(Node,Task,FieldId,Gantt.Plan,Value)) THEN
                GetColumnInfo(Node,Task,FieldId,ColumnDataType,1,TempValue);
                GetValueToCompare(CompareTo, TempValue.CardinalValue, 
                                  CompareValue);
                IF (ValuesMatch(Value, CompareValue, CompareAs)) THEN
                    RETURN (NOT Inverted);
                END;
            END;

            RETURN Inverted;
        END;

    END MatchDataField;


BEGIN

    (* ******************

        24-Jan-91 RSC

        NOTE: FilterOneTask ASSUMES THAT THIS TASK RECORD DOES NOT
              CHANGE.  THIS IS CRITICAL TO THE FlexStor Unlock LOGIC.
              ONLY CHANGE THE LocalFilterSet.

    **********************)



    IF (FilterRecord.fltrset[0] = EmptyFilterSet[0]) AND
       (FilterRecord.fltrset[1] = EmptyFilterSet[1]) THEN
        RETURN;
    END;

    LocalSet := EmptyFilterSet;
    ParentsToo := FALSE;

    TaskStatus := Task^.TaskStatusSet;

        (*  Check slack. *)

    IF TestFilterBit (FilterRecord.fltrset, FSlack) THEN
        CASE FilterRecord.SlackCheck OF
            CriticalCheck :
                IF (Critical IN TaskStatus) THEN
                    SetFilterBit (LocalSet,FSlack,TRUE);
                END;
        |   NearlyCriticalCheck :
                IF (
                    (
                        FindDuration
                        ( 
                            Task^.Plan.Dates.EarlyEnd, 
                            Task^.Plan.Dates.LateTotalEnd,
                            TimeSheet
                        ) 
                        <= 
                        ( Task^.duration DIV VAL( ADurationCounter, 5 ) )
                     )
                     AND 
                     ( Task^.StartStatus <> DoneS ) 
                    ) THEN
                    SetFilterBit (LocalSet,FSlack,TRUE);
                END;
        ELSE;
        END;
    END;


    IF TestFilterBit (FilterRecord.fltrset, FMilestone) THEN
        IF (Task^.duration = NoDuration) THEN
            SetFilterBit (LocalSet,FMilestone,TRUE);
        END;
    END;



    IF TestFilterBit (FilterRecord.fltrset, FComplete) THEN
        IF ((FilterRecord.PercentComplete = 0) AND
            (Task^.StartStatus = FutureS)) OR
           ((FilterRecord.LessThan) AND
            (Task^.PercentComplete < FilterRecord.PercentComplete)) OR
           ((NOT FilterRecord.LessThan) AND
            (Task^.PercentComplete >= FilterRecord.PercentComplete)) THEN
                SetFilterBit (LocalSet, FComplete, TRUE);
        END;
    END;


    IF TestFilterBit (FilterRecord.fltrset, FJoin) THEN
        IF (TaskStatus * ATaskStatusSet{PartialJoinAfter,
                PartialJoinPrior} <> ATaskStatusSet{}) THEN
            SetFilterBit (LocalSet, FJoin, TRUE);
        END;
    END;


    IF TestFilterBit (FilterRecord.fltrset, FResConflict) THEN
        IF (ResourceConflict IN TaskStatus) OR
           (ResourceOverload IN TaskStatus) THEN
            SetFilterBit (LocalSet, FResConflict, TRUE);
        END;
    END;



    IF TestFilterBit (FilterRecord.fltrset, FLoop) THEN
        IF (Loop IN TaskStatus) THEN
            SetFilterBit (LocalSet, FLoop, TRUE);
        END;
    END;

        (* Needs update? *)

    IF TestFilterBit (FilterRecord.fltrset, FNeedsUpdate) THEN
        IF (Task^.StartStatus <> AppropriateStartStatus(Task^,AsOfDate)) THEN
            SetFilterBit (LocalSet, FNeedsUpdate, TRUE);
        END;
    END;


    IF TestFilterBit (FilterRecord.fltrset, FLate) THEN
        IF (BaseLineExists IN Task^.TaskFlags) AND
                (Task^.Plan.Dates.EarlyEnd > Task^.BaseLine.Dates.EarlyEnd) THEN
            SetFilterBit (LocalSet, FLate, TRUE);
        END;
    END;




        (* Check for patterns in the names and sort code fields. *)

    FOR FilterType := FNameHas TO FAUXHas DO               (* 12/16/86 LAA *)
        IF TestFilterBit (FilterRecord.fltrset, FilterType) THEN
            IF (TaskMatch(Task^,FilterType,FilterRecord)) THEN
                SetFilterBit(LocalSet,FilterType,TRUE);
            END;
        END;
    END;

        (* See if the dates are in the right range. *)

    IF TestFilterBit (FilterRecord.fltrset, FDate) THEN
           IF (Task^.Plan.Dates.EarlyStart < FilterRecord.enddate) AND
              (Task^.Plan.Dates.EarlyEnd > FilterRecord.startdate) THEN
            SetFilterBit(LocalSet,FDate,TRUE);
        END;
    END;

        (* Do we use any of the named resources? *)

    FOR FilterType := FResource0 TO FResource3 DO
        IF TestFilterBit (FilterRecord.fltrset, FilterType) THEN
            RNode := FilterRecord.ResourceNode[FilterType];
            IF (RNode <> NIL) THEN
                Resource := RNode^.Methods^.GetDataObject (RNode);
                IF (TaskUsesResource(Task,Resource)) THEN
                    SetFilterBit(LocalSet,FilterType,TRUE);
                    ParentsToo := TRUE;
                END;
            END;
        END;
    END;

        (* Do we use any resources with matching names? *)

    IF TestFilterBit (FilterRecord.fltrset, FRNameHas) THEN
        IF (ResourceStringMatch(Task,FilterRecord)) THEN
            SetFilterBit(LocalSet,FRNameHas,TRUE);
            ParentsToo := TRUE;
        END;
    END;


    IF TestFilterBit (FilterRecord.fltrset, FAnte) THEN
        IF (ItDepends (Node, FilterRecord.antetask)) THEN
            SetFilterBit (LocalSet, FAnte, TRUE);
        END;
    END;


    IF TestFilterBit (FilterRecord.fltrset, FDesc) THEN
        IF (ItDepends (FilterRecord.desctask, Node)) THEN
            SetFilterBit (LocalSet, FDesc, TRUE);
        END;
    END;

    FOR FilterType := FDataField1 TO FDataField2 DO
        IF (TestFilterBit(FilterRecord.fltrset, FilterType)) THEN
            IF (MatchDataField(FilterType)) THEN
                SetFilterBit(LocalSet, FilterType, TRUE);
            END;
        END;
    END;


    IF (FilterRecord.Any) THEN
        In :=  (LocalSet[0] <> EmptyFilterSet[0])
                OR (LocalSet[1] <> EmptyFilterSet[1]);
    ELSE
        In :=  (LocalSet[0] = FilterRecord.fltrset[0])
                AND (LocalSet[1] = FilterRecord.fltrset[1]);
    END;
    IF (FilterRecord.Negative) THEN
        In := NOT In;
    END;

    SetTaskFilter (Node, Task, Variety, LocalFilterSet, In);
    IF ((Variety = Selected) AND (In)) OR
       ((Variety <> Selected) AND (ParentsToo)) THEN

        ParentNode := Node^.Methods^.Parent (Node);
        WHILE (ParentNode <> NIL) DO
            SetTaskFilter (ParentNode, ATaskPtr(NIL), Variety, ParentFilterSet, In);
            ParentNode := ParentNode^.Methods^.Parent (ParentNode);
        END;
    END;

END DoOneFilter;




PROCEDURE FilterOneTask (VAR    Node        : ATreeNode;
                                Context     : ADDRESS   );
VAR
    TaskPtr         : ATaskPtr;
    i               : CARDINAL;
    LocalFilterSet  : ATaskFilterSet;
BEGIN

    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);

    LocalFilterSet := TaskPtr^.FilterSet;

    INCL (LocalFilterSet, Selected);
    LocalFilterSet := LocalFilterSet - ATaskFilterSet{Highlight1..Highlight5};
    Node^.Methods^.SetVisible (Node, TRUE);

    FOR i := 1 TO HIGH(HighlightFilter) DO
        IF (HighlightFilter[i] <> NIL) THEN
            DoOneFilter (Node, TaskPtr, GlobalHF[i], LocalFilterSet, VAL(ATaskFilter,i-1+ORD(Highlight1)));
        END;
    END;
    IF (RevealFilter <> NIL) THEN
        DoOneFilter (Node, TaskPtr, GlobalRF, LocalFilterSet, Selected);
    END;

    (* 24-Jan-91 RSC If the filter set has not changed, we don't need to
                     write this record.
    *)
    IF (TaskPtr^.FilterSet = LocalFilterSet) THEN
        Node^.Methods^.UnlockUnchangedDataObject (Node);
    ELSE
        TaskPtr^.FilterSet := LocalFilterSet;
        Node^.Methods^.UnlockFlexStorDataObject (Node);
    END;

END FilterOneTask;






PROCEDURE PrepareFilter (     Node          : ATreeNode;
                          VAR FilterRecord  : AFilterRecord );

VAR
    FilterRecordPtr     : AFilterRecordPointer;
    MatchType           : AFltrType;

BEGIN
    IF (Node = NIL) THEN
        RETURN;
    END;

    FilterRecordPtr := Node^.Methods^.LockFlexStorDataObject (Node);

    CleanFilterRecord( FilterRecordPtr^ );

    WITH FilterRecordPtr^ DO
        IF TestFilterBit (fltrset, FDate) THEN
            enddate := AsOfDate;
            IF (LengthOf (EndDateString) = 0)
                    OR (NOT StoTimeU (EndDateString, enddate)) THEN          (* 6/9/87 EGK *)
                enddate := MaxDate;
            END;
            startdate := AsOfDate;
            IF (LengthOf (StartDateString) = 0)
                    OR (NOT StoTimeU (StartDateString, startdate)) THEN
                startdate := MinDate;
            END;
        END;
        FOR MatchType := FResource0 TO FResource3 DO
            IF (TestFilterBit (fltrset, MatchType)) THEN
                ResourceNode[MatchType] 
                    := FindResourceByName (ResourceName[MatchType]);
            END;
        END;
    END;
    FilterRecord := FilterRecordPtr^;                          (* 29-May-91 *)
    Node^.Methods^.UnlockFlexStorDataObject (Node);    FilterRecordPtr := NIL;

END PrepareFilter;




    (* Filter -- Set the filter flags for all tasks *)


PROCEDURE Filter;
VAR
    i           : CARDINAL;
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    FOR i := 1 TO 5 DO
        PrepareFilter (HighlightFilter[i], GlobalHF[i]);
    END;
    PrepareFilter (RevealFilter, GlobalRF);

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
                                     FilterOneTask, NIL);
END Filter;



PROCEDURE TLFilterBody();

BEGIN                       (* TLFilterBody *)

    Filter;

END TLFilterBody;


(*<OS2
PROCEDURE TLFilterBind();
OS2>*)

BEGIN
(*<DOS*)
    OverlayID := ImAnInstallableOverlay(TLFilterBody, AnOverlayProc(NIL));
(*DOS>*)
    TLFilterBody();

(*<OS2
END TLFilterBind;
OS2>*)

END TLFilter.
