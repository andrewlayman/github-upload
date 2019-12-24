(*V9=DEBUG Version*)
(*V1=EXTRA Adds abbreviations for Duration method and Splitting rule *)

IMPLEMENTATION MODULE Chart;

(*  =========================================================================
    Last Edit : January 22, 1991 6:00PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:
       Sep. 3, 1985, AJL - Added support for default date format.

       Dec. 4, 1985, AJL - Expanded the size of some text buffers.

       25 Jul 86     AJL - Moved some reset out of reset chart and
                           into the initialization.  This fixes the
                           problem of the chart date line resetting
                           whenever you do a file erase.
        10/10/86   LAA     In MChDay, changed the second condition of the
                           WHILE loop; it was incorrectly phrased.
        10/31/86 LAA    Commented out part of windowc, which used keys not
                        exported from Actions, so this will compile.  I don't
                        know why that code is necessary, but maybe Andrew 
                        does.  Removed all references to GlanceStyle, since it
                        no longer exists.  Chart.DEF modified also.
        11/04/86 LAA    ChartState is now a set, so changes were made to 
                        accomodate that.
        11/10/86 LAA    Brought a line of code in from vers. 2.3, in 
                        PlanAppropriateChartScale.
        11/11/86 LAA    Instead of setting the chart state directly to an
                        empty set, use UnSetState(Scheduled).  Also, in
                        PrepareChart, a series of IF's was changed to
                        ELSIF's, to more closely mimic the previous CASE
                        statement.
        11/28/86 LAA    In PrepareChart, don't ask for Pert unless the plan
                        level will cause it to do something.  That is, a
                        schedule does NOT have to be Scheduled before it's
                        Sorted, Filtered, etc.
        12-May-87 LAA   Removed all sorts of stuff for GanttOutlines.  In
                        particular, I removed things associated with
                        AutoTracking.
        19-May-87 LAA   Incorporated the GanttOutlines into Spike, replacing
                        the previous Gantt chart.
        20-May-87 LAA   Move the definition of ChartFormat and 
                        CurrentChartFormat from here to ChartForms.
        21-May-87 LAA   Changed the definitions of CursorTask, BugTasks to be
                        tree nodes, rather than task pointers.  Made similar
                        changes to the parameters of several procedures.
        05-Jun-87 LAA   Fixing minor bugs in the Gantt chart.
        10-Jun-87 LAA   Changed MChTask and MChTaskAndDay to take a NIL node.
        19-Jun-87 LAA   Require redisplay of the Gantt chart whenever a bug
                        is set.
        24-Jun-87 LAA   MChToday will force the today to appear at the left
                        of the chart.
        27-Jul-87 LAA   The definition of ChartFormat was changed.
        04-Aug-87 LAA   Changes for named layouts.  Moved InitializeChart 
                        here from Timeline.
        19-Aug-87 LAA   Use a chart state of showing to prevent redundant
                        calls to the display method for the gantt chart.
         9-Oct-87 RSC   Removed DateAsEndOfPeriod (not used).
        27-Oct-87 EGK   Change Gantt cursor to resting during a recalc.
        10-Dec-87 LAA   Incorporated LockFlexStorDataObject method.
        11-Jan-88 LAA   Changed UnlockFlexStorDataObject to UnlockUnchanged.
        29-Jan-88 EGK   Check alarms only if auto-recalc.  Set cursor mode
                        to resting while filtering and formatting.
        01-Feb-88 LAA   Moved calls to SetCursorMode so that resting cursor 
                        is set only for calcing and filtering.
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
         5-Jan-89 RSC   Removed reference to Actions.Mod
        18-Feb-89 LAA   Moved code for TaskStats procedure here from
                        GanttOutlines, and made it a procedure variable.
        21-Mar-89 RSC   Use FSMUPH rather than FLOAT(SMUPH).
        29-Mar-89 RSC   Enhance the prompt line for SCROLL MODE.
         3-Apr-89 RSC   Left Justify prompt line.
         4-Apr-89 RSC   Trim "+" off the front of the prompt line.
        18-Apr-89 RSC   Prompt lines had a bad call to "LongDurationToString".
                        this caused "2 days" to become "2".
        08-May-89 LAA   In MChCurrentTask, I transposed a factor to eliminate
                        a subtraction to fix a reported bug.  Using Ctrl-End
                        on a Fixed milestone at 4-Jan-83 caused a PMD.
        12-May-89 RSC   1) Make Task Table summary line one byte wider.
                        2) Only get WBS for status lines when really needed
                           (because this is a slow operation).
                        3) Improve on task name formatting, so leading "+"
                           signs are not removed.
                        4) As per AJL, change reference to Alarms to
                           SetAsOfDate.
        19-Jun-89 AJL   Removed FiltersOn boolean.

        22-Aug-89 RSC   Shortened the WBS number real estate on the top line.
        28-Aug-89 WKH   Register for a VideoSetupChange notice so we can 
                        refresh the GanttChart afterwards.
         6-Sep-89 RSC   Fix bug 1095, UnSetState(Scheduled) called upon task
                        deletion.  UnSetState is done in Changer.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        02-May-90 KKC   Replace all direct calculations on ADate and Duration
                        by calls to FindDuration, SubtractWorkingTime and
                        AddWorkingTime.
        01-Jun-90 AJL   Replaced the PlanLevel variables from Planner with
                        use of the CalculationState array.
        03-Jul-90 AJL   Moved display of lights into the ShowChartLights proc.
        15-Oct-90 AJL   Monitor the loading and saving of schedule notices so
                        that we can redisplay the ScheduleLight if the schedule
                        status changes.
	11-Dec-90 AJL   Changed the ShowStats procedure so that it displays
                        the same duration as Captions would.
    22-Jan-91 RSC   Removed spurious import of LongDurationToString.
    15-Feb-91 AJL   If the EXTRAS toggle is enabled, the status line will
                    show abbreviations for the Duration Method and Splitting
                    Rule.
     5-Apr-91 TGS   Moved Task Column numbers from magicnum.def to
                    taskcoln.def.
    =========================================================================
*)



FROM Allocs                 IMPORT ATaskPtr, TskNmLen, AFixType, AStartStatus,
                                   StartStatusName, CheckTaskValid, 
                                   FixationName, ATaskName, TaskTree,
                                   WBSLen, WBSLine, GetCodingField;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate,
    (* PROC *)                  SetAsOfDate;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM CalShift               IMPORT
    (* VAR  *)                  TimeSheet;

FROM Captions               IMPORT
    (* PROC *)                  ResourceNameList, GetColumnString;

FROM ChartControl           IMPORT AChartState, ChartState, AChartStateSet,
                                   SetState, UnSetState, RecomputeLight;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormat, AChartFormatPtr,
    (* PROC *)                  CurrentLayout;

FROM ChartMgr               IMPORT PushChartDisplayProcedure;

FROM Codes                  IMPORT ACode, ASetOfCodes;

FROM Dialog                 IMPORT Error, FatalError, Burp, Message,
                                   MessageWithPriority, WarningBox,
                                   ADialogOption;

FROM Duration               IMPORT
    (* PROC  *)                 AddWorkingTime;

FROM ErrorCategories        IMPORT
    (* CONST *)                 NotPossibleInContextError, UnknownEventError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker,
                                GetErrorDetails;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent, AnEventType;

FROM Filters                IMPORT Filter, AdjacentTask;

FROM Gantt                  IMPORT DateLnDepth, StatWidth, ChartFont,
                                   ADStyle, DateLines, CheckScale, GanttLine,
                                   ASlackStyle, AGanttLineType;

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutline, AGanttOutlineSpecificChange,
    (* PROC *)                  CreateGanttOutline, ValidateGanttOutline;

FROM Helper                 IMPORT GiveHelp, AScreenAction;

FROM Kbio                   IMPORT maxrow, maxcol, ascreenx, ascreeny,
                                   avidmode, KeyPress,
                                   soundon,
                                   PutString, ACursorType, SetCursorType, GotoXY,
                                   GetAnyCode, EraseLn, EraseScreen,
                                   ScrollMode;

FROM Keys                   IMPORT Fwrd, Reverse, Up, Down, RollLeft, RollRight,
                                   RollUp, RollDown, DoIt,
                                   InsertKey, DeleteKey, EditKey, CopyKey,
                                   UndoKey,
                                   CancelKey, ExitKey, HelpKey,
                                   SplitKey, HomeKey, EndKey,
                                   AnteKey, Tab, RTab, ComputeKey;

FROM Layout                 IMPORT GanttWStart, GanttWEnd, MenuStart, MenuEnd;

FROM Lights                 IMPORT
    (* PROC *)                  DisplayLight;

FROM LStrings               IMPORT SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                   Insert, Procustes, TrimFront, TrimRear,
                                   Copy, Fill, SetLengthOf, Overlay, LengthOf,
                                   LJust, Remove;

FROM MsgFile                IMPORT GetMessage, ConcatMessage, DisplayMessage;

FROM Notices                IMPORT AnOccasion, AStep, RegisterForNotices;

FROM Planner                IMPORT 
    (* TYPE *)                     ACalcComponent, AWhenToCalc, 
    (* VAR *)                      ScheduleComputedOk, ScheduleEndDate,
                                   CalculationState,
    (* PROC *)                     Pert, WeShouldRecalc; 

FROM Schedule               IMPORT
    (* PROC *)                     DisplayScheduleLight;
    
FROM SYSTEM                 IMPORT ADDRESS;

FROM TaskColNumbers         IMPORT 
    (* CONST *)                 TaskNameColumn, DurationColumn;

FROM TimeFormat             IMPORT
    (* TYPE *)                  ADateString,
    (* PROC *)                  FormatAsEndDateStyle,
                                TimeUtoS;

FROM TimeJump               IMPORT FindNextKeyDate, FindPriorKeyDate,
                                   FindStartDateOf;

FROM Timei                  IMPORT
    (* CONST*)                  OneUnitOfDuration, MaxDate, NoDuration,
                                MinDate,
    (* TYPE *)                  ADate, ADuration, ADurationUnit,
    (* VAR *)                   Today,
    (* PROC *)                  FindToday, TtoTimeU, TimeUtoT,
                                DayOfWeek, DurationToReal;

FROM Timeu                  IMPORT
    (* VAR *)                   FSMUPH,
    (* PROC *)                  UpScale, DownScale;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  ValidateTreeNode;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;



CONST
    ModuleNumber            = 3900;    (* For GetMessage *)

CONST
    BothBugsLetter          = 253C;    (* Shows as 1/2 on the IBM PC. *)
    uparrow                 = 30C;
    downarrow               = 31C;
    rightarrow              = 32C;
    leftarrow               = 33C;

VAR
    TimeOfLastFormat        : ADate;
    FirstTimeFlag           : BOOLEAN;     (* Chart has never been formatted,
                                          no start date and task are known. *)




    (*  ChartNotifyDeleted -- Please call this routine whenever a task
                              is deleted so that we can update our
                              records and know that any private pointers
                              to it are no longer valid. *)

PROCEDURE ChartNotifyDeleted(Task:ATreeNode);

    PROCEDURE Check(VAR CheckTask:ATreeNode);

    BEGIN
        IF (CheckTask = Task) THEN CheckTask := NIL; END;
    END Check;

BEGIN

    (*<DEBUG*)
    ValidateTreeNode(Task);
    ValidateGanttOutline(GanttChart);
    (*DEBUG>*)

    CursorTask := GanttChart^.Methods^.GetCursorNode(GanttChart);
    Check(CursorTask);
    Check(BugTaskA);
    Check(BugTaskB);

    (* RSC 6-Sep-89 Removed UnSetState(Scheduled) and NotifyNodeDeleted *)

END ChartNotifyDeleted;



PROCEDURE MChTaskAndDay(Task:ATreeNode; Day:ADate);

BEGIN

    GanttChart^.Methods^.SetCursorNode(GanttChart, Task);
    UnSetState(Formatted);

    MChDay(Day);

END MChTaskAndDay;





PROCEDURE MChToday;
    
BEGIN                       (* MChToday *)

    ChartStartDay := AsOfDate;
    MChDay(AsOfDate);

END MChToday;






PROCEDURE MChDay (Timeu:ADate);

BEGIN

    CursorDay := Timeu;
    UnSetState(Formatted);

END MChDay;





PROCEDURE MChTask (    Task                 : ATreeNode);

VAR
    TaskPtr                 : ATaskPtr;
    Date                    : ADate;

BEGIN

    GanttChart^.Methods^.SetCursorNode(GanttChart, Task);
    UnSetState(Formatted);
    GanttChart^.Methods^.NoteSpecificChange (GanttChart, TaskChange);
    IF (Task <> NIL) THEN
        (*<DEBUG*)
        ValidateTreeNode(Task);
        (*DEBUG>*)

        TaskPtr := Task^.Methods^.LockFlexStorDataObject(Task);   (* 10-Dec-87 LAA *)
        Date := TaskPtr^.Plan.Dates.EarlyStart;
        Task^.Methods^.UnlockUnchangedDataObject(Task);            (* 10-Dec-87 LAA *) (* 11-Jan-88 LAA *)

        MChDay(Date);
    END;

END MChTask;




    (*  MChCurrentTask --

        Leaving the cursor on the current task, move the cursor to the
        beginning of the task bar.  One exception: if the cursor is
        already on the beginning of the task bar, it will move to the end. *)


PROCEDURE MChCurrentTask;

VAR
    TargetDay               : ADate;
    CurrentNode             : ATreeNode;
    CurrentTask             : ATaskPtr;
    ChartRecord             : AChartFormatPtr;

BEGIN

    CurrentNode := GanttChart^.Methods^.GetCursorNode(GanttChart);
    IF (CurrentNode <> NIL) THEN

        (*<DEBUG*)
        ValidateTreeNode(CurrentNode);
        (*DEBUG>*)

        ChartRecord := CurrentLayout();

        CurrentTask := CurrentNode^.Methods^.LockFlexStorDataObject(CurrentNode);  (* 10-Dec-87 LAA *)
        TargetDay := CurrentTask^.Plan.Dates.EarlyStart;
        IF (
              ( 
                AddWorkingTime
                (
                    CursorDay, 
                    ChartRecord^.scale, 
                    TimeSheet
                ) 
                >= 
                TargetDay 
              ) (* 08-May-89 LAA *) (* 2-May-90 KKC  *)
             AND 
              ( 
                CursorDay 
                <= 
                AddWorkingTime
                (
                    TargetDay,
                    ChartRecord^.scale,
                    TimeSheet
                )
              )
           ) THEN
            TargetDay := CurrentTask^.Plan.Dates.EarlyEnd;
        END;
        CurrentNode^.Methods^.UnlockUnchangedDataObject(CurrentNode);  (* 10-Dec-87 LAA *) (* 11-Jan-88 LAA *)
        UnSetState(Formatted);
        MChTaskAndDay(CurrentNode, TargetDay);
    END;

END MChCurrentTask;







PROCEDURE InitViewOfTaskTree();

VAR
    Node                    : ATreeNode;

BEGIN                       (* InitViewOfTaskTree *)

    Node := TaskTree^.Methods^.GetFirstVisible(TaskTree);
    GanttChart^.Methods^.SetObject(GanttChart, TaskTree);
    GanttChart^.Methods^.SetFirst(GanttChart, Node);
    GanttChart^.Methods^.SetCursorNode(GanttChart, Node);
    GanttChart^.Methods^.SetCursor(GanttChart, TRUE);

END InitViewOfTaskTree;



    (*$S+*)

PROCEDURE PrepareChart(starttask:ATreeNode; startday:ADate);

VAR
    Node                    : ATreeNode;
    FirstNode               : ATreeNode;
    s                       : ARRAY [0..31] OF CHAR;
    ok                      : BOOLEAN;

BEGIN                       (* PrepareChart *)

    Node := GanttChart^.Methods^.GetCursorNode(GanttChart);
    WHILE NOT (Formatted IN ChartState) DO                         (* LAA 11/04/86 *)
        IF 
           (NOT (Scheduled IN ChartState))    
           AND ( WeShouldRecalc(CalculationState,AutoCalc))
           THEN
            GanttChart^.Methods^.SetCursorMode(GanttChart, videorestingcursor);  (* 01-Feb-88 LAA *)
            GanttChart^.Methods^.Display (GanttChart);
            ok := Pert(AsOfDate,AutoCalc);
            SetAsOfDate();
            SetState(Scheduled);
            GanttChart^.Methods^.SetCursorMode(GanttChart, videonormal);
        ELSIF NOT (Sorted IN ChartState) THEN                     (* 27-Jul-87 LAA *)
            SetState(Sorted);
        ELSIF NOT (Filtered IN ChartState) THEN
            GetMessage(ModuleNumber+15, s);    (* "Filtering" *)
            DisplayLight(RecomputeLight, s, videoreverse);
            GanttChart^.Methods^.SetCursorMode(GanttChart, videorestingcursor);  (* 01-Feb-88 LAA *)
            GanttChart^.Methods^.Display (GanttChart);
            Filter;
            GanttChart^.Methods^.SetCursorMode(GanttChart, videonormal);
            Today := FindToday();
            TimeOfLastFormat := AsOfDate;  (* Help prevent looping *)
        ELSIF NOT (Formatted IN ChartState) THEN
            SetState(Formatted);
            TimeOfLastFormat := AsOfDate;  (* Help prevent looping *)
            GanttChart^.Methods^.NotifyOfChange(GanttChart);
            FirstNode := GanttChart^.Methods^.GetFirst (GanttChart);
            IF (FirstNode <> NIL) THEN
                IF (FirstNode^.Methods^.Visible (FirstNode)) THEN
                    GanttChart^.Methods^.Synchronize(GanttChart);
                ELSE
                    FirstNode := AdjacentTask (FirstNode);
                    GanttChart^.Methods^.SetFirst (GanttChart, FirstNode);
                END;
            ELSE
                InitViewOfTaskTree();
            END;
            IF (Node = NIL) THEN
                Node := TaskTree^.Methods^.GetFirstVisible (TaskTree);
            ELSIF (NOT Node^.Methods^.Visible (Node)) THEN
                Node := AdjacentTask (Node);
            END;
            GanttChart^.Methods^.SetCursorNode(GanttChart, Node);
            ShowChartLights();
        END;
    END;



END PrepareChart;

    (*$S=*)


PROCEDURE ShowChartLights();
VAR
    s                       : ARRAY [0..31] OF CHAR;
    s2                      : ARRAY [0..31] OF CHAR;
    Mode                    : avidmode;
BEGIN
        (* Display the recalc light. *)


    SetLengthOf(s,0);
    Mode := videolights;
        (* Was there an error? *)
    IF (NOT ScheduleComputedOk) THEN
        ConcatMessage(s, ModuleNumber+25);                     (* Calc Error *)
        Mode := videowarning;
    ELSIF (CalculationState[Scheduling].DataIsValid) THEN
        IF (ScheduleEndDate > MinDate) THEN
                (* Display end date of schedule. *)
            ConcatMessage(s,ModuleNumber+24);                   (* "End: " *)
            FormatAsEndDateStyle(ScheduleEndDate,s2);
            TrimFront(s2);
            ConcatLS(s,s2);
        END;
            (* Would a manual recalc change things? *)
        IF (WeShouldRecalc(CalculationState,ManualCalc)) THEN
            ConcatS(s, "+");                       (* Recalc *)
        END;
    ELSIF (WeShouldRecalc(CalculationState,ManualCalc)) THEN
        ConcatMessage(s, ModuleNumber + 26);                       (* Recalc *)
    END;

    DisplayLight(RecomputeLight, s, Mode);

    DisplayScheduleLight();                                        (* Project name & changed status. *)
END ShowChartLights;



PROCEDURE ChartNoticeHandler(Occasion : AnOccasion;
                             Step     : AStep;
                             Context  : ADDRESS) : BOOLEAN;

BEGIN
    IF (Step = AfterActing) THEN
        CASE Occasion OF
            VideoSetupChange,
            ModelLoad,  
            ModelErase, 
            ModelSave,
            MiscSetupChange :
                    (* Reformat, and redisplay in new colors or with a
                       new schedule name light. *)
                UnSetState(Formatted);
                GanttChart^.Methods^.NotifyOfChange(GanttChart);
                ShowSched();
          ELSE;
        END;
    END;

    RETURN TRUE;
END ChartNoticeHandler;



    (* SHOWSCHED -- Show the current view of the Gantt chart. *)

PROCEDURE ShowSched;

BEGIN                       (* ShowSched *)

    IF (FirstTimeFlag) THEN
            (*  Have to initialize here because, until TLINIT is executed,
                the AsOfDate is wrong.
            *)
        ChartStartDay := AsOfDate;
        CursorDay := AsOfDate;

        InitViewOfTaskTree();
    
        RegisterForNotices(VideoSetupChange, ChartNoticeHandler); (* 28-Aug-89 WKH *)
        FirstTimeFlag := FALSE;
    END;
    IF (NOT (Showing IN ChartState)) THEN                           (* 19-Aug-87 LAA *)
        PrepareChart(ATreeNode(NIL), MinDate);
        GanttChart^.Methods^.Display(GanttChart);
        SetState(Showing);
    END;
     
END ShowSched;









    (*  ResetChart -- Set up for a blank chart. *)


PROCEDURE ResetChart;
BEGIN
    BugTaskA := NIL;
    BugTaskB := NIL;
    CursorTask := NIL;
    TimeOfLastFormat := MaxDate;   (* Avoid clock tick on first time. *)
    IF (NOT FirstTimeFlag) THEN
        GanttChart^.Methods^.NotifyOfChange(GanttChart);
        InitViewOfTaskTree();
    END;

END ResetChart;



PROCEDURE InitializeChart();

VAR
    s                       : ARRAY [0..1] OF CHAR;

BEGIN                       (* InitializeChart *)

    Fill(s, " ", 0);
    IF (NOT CreateGanttOutline(GanttChart, NIL, NIL,
                               0, GanttWStart + 2, 79, GanttWEnd, 
                               ABoxType{NoBox}, videonormal, s, 0, 
                               FALSE)) THEN
        FatalError();
    END;

END InitializeChart;



PROCEDURE ShowStats(Task:ATreeNode);

CONST
    DesiredWBSMaxLen        = 15;

VAR
    T                       : ATaskPtr;
    ColumnID,
    i                       : CARDINAL;
    PrivateEarlyStart       : ADate;
    PrivateEarlyEnd         : ADate;
    PrivateFixation         : AFixType;
    PrivateScale            : ADurationUnit;
    PrivateStartStatus      : AStartStatus;
    PrivateTaskName         : ATaskName;
    PrivateWBS              : ARRAY [0..WBSLen]  OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    s1                      : ARRAY [0..3]   OF CHAR;
    s2                      : ARRAY [0..81]  OF CHAR;
    comma                   : ARRAY [0..9]   OF CHAR;
    ok,
    ScrollMode              : BOOLEAN;

BEGIN                       (* ShowStats *)

    IF (Task <> NIL) THEN
        (*<DEBUG
        IF (AnxietyLevel > Calm) THEN
            ValidateTreeNode(Task);
        END;
        DEBUG>*)

        IF (KeyPress()) THEN RETURN END;

        ScrollMode := GanttChart^.Methods^.QueryScrollMode( GanttChart );

        T := Task^.Methods^.LockFlexStorDataObject(Task);         (* 10-Dec-87 LAA *)
        WITH T^ DO
            PrivateEarlyStart  := Plan.Dates.EarlyStart;
            PrivateEarlyEnd    := Plan.Dates.EarlyEnd;
            PrivateFixation    := fixation;
            PrivateScale       := scale;
            PrivateStartStatus := StartStatus;
            PrivateTaskName    := taskname;
        END;
        IF (ScrollMode) THEN
            ColumnID := GanttChart^.Methods^.GetColumnId( GanttChart );
            IF (ColumnID = TaskNameColumn) THEN
                Copy(T^.taskname, s );
                Procustes(s, maxcol + 1);
            ELSE
                ok := GetColumnString( Task, T,
                                       ColumnID,
                                       Plan,
                                       maxcol + 1,
                                       s );
                LJust(s);
            END;
        ELSE
            GetCodingField (T^, WBSLine, PrivateWBS);      (* 5/3/89 EGK *)
        END;

        IF (NOT ScrollMode) THEN
            Copy( PrivateTaskName, s );
            Procustes( s, HIGH(PrivateTaskName) + 2 );
            Procustes( PrivateWBS, DesiredWBSMaxLen ); (* RSC 22-Aug-89 *)
            ConcatS(  s, " " );
            ConcatLS( s, PrivateWBS );
            ConcatMessage(s, ModuleNumber+3);        (* "Who: " *)
            ResourceNameList(Task, Plan, maxcol + 1 - LengthOf(s), s2);
            Procustes(s2, maxcol + 1 - LengthOf(s));
            ConcatLS(s, s2);
        END;

        (* Second line comes first *)

        PutString(s,0,GanttWStart-2,videocaption);

        (* Now the first line *)

        IF (Task^.Methods^.GetSubtree(Task) = NIL) THEN
            SubStr(FixationName[PrivateFixation],s,1,100);
            (*<EXTRA*)
                (* Abbreviations for DurationMethod and Vacation splitting. *)
            ConcatMessage(s,ModuleNumber+34);    
            ConcatMessage(s,ModuleNumber+36+ORD(T^.DurationMethod)); 
            ConcatMessage(s,ModuleNumber+40+ORD(T^.SplittingRule)); 
            ConcatMessage(s,ModuleNumber+35);
            (*EXTRA>*)
        ELSE
            GetMessage(ModuleNumber + 5, s);      (* "SUMMARY" *)
        END;
        GetMessage( ModuleNumber+1, comma );       (* ", " *)
        IF (PrivateEarlyStart <> PrivateEarlyEnd) THEN
            ConcatLS(s,comma);
            IF GetColumnString(Task,T,DurationColumn,Plan,HIGH(s2),s2) THEN
                 LJust(s2);  TrimRear(s2);
                 ConcatLS(s,s2);
            END;
        ELSE
            ConcatMessage(s,ModuleNumber+2);   (* " MILESTONE " *)
        END;

        ConcatLS(s,comma);
        TimeUtoS(PrivateEarlyStart,s2);
        TrimRear(s2);
        ConcatLS(s,s2);
        IF (PrivateEarlyStart <> PrivateEarlyEnd) THEN
            ConcatMessage(s,ModuleNumber+4);   (* " thru " *)
            FormatAsEndDateStyle (PrivateEarlyEnd, s2);
            TrimRear(s2);
            ConcatLS(s,s2);
        END;
        ConcatMessage(s,ModuleNumber+20+ORD(PrivateStartStatus)); (* "Future,Started,Done" *)
        Procustes(s, maxcol + 1);
        PutString(s,0,GanttWStart-1,videocaption);

        Task^.Methods^.UnlockUnchangedDataObject(Task);            (* 10-Dec-87 LAA *) (* 11-Jan-88 LAA *)

    ELSE
        Fill(s, " ", maxcol + 1);
        PutString(s, 0, GanttWStart - 1, videocaption);
        PutString(s, 0, GanttWStart - 2, videocaption);
    END;

END ShowStats;




BEGIN                       (* Chart *)

    FirstTimeFlag      := TRUE;
    GanttChart         := NIL;
    DisplayTaskStats   := ShowStats;
    PushChartDisplayProcedure(ShowSched);   (* We are the base chart. *)

    ResetChart;

END Chart.


