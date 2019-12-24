MODULE TLAlarm;

    (* MODIFICATION HISTORY:

       3/3/86  AJL - Set a task to Fixed Date whenever Edit is chosen
                     from the Alarms menu and the proper start status
                     for the task would be Done or Started.
                   - The program used to set an task to FixedDate
                     only if (a) the proper StartStatus were Done, or
                     (b) the proper StartStatus were Started, the task
                     was ASAP and had no antecedants.  We now set it
                     to FixedDate if the proper StartStatus is Done
                     or Started, regardless or antecedants or type.
       03/10/86 LAA  Get text phrases from MsgFile, rather than embedding
                     them in the code.
       11/04/86 LAA  Changed CheckForClockTick to use AsOfDate rather than
                     Today; it was causing looping between the main menu and
                     Chart.windowc.  ChartState is now a set.
       11/11/86 LAA  Replaced an occurance of SetState(Formatted) with
                     UnSetState(Showing), because that's what's really needed.
       11/26/86 LAA  Removed reference to NeedsRecompute, whose function is
                     now handled by the chart state.
       12/04/86 LAA  A change to the StartStatus may affect the %complete.
                     Effected in FixTheDateAndStatus.
       03/23/87 EGK  Calls SetAsOfDate before running the alarms check.
       05/06/87 RSC  replace status references with TaskStatus.
       20-May-87 LAA Commented out CheckAlarms so the new Gantt chart would
                     work.  We need to re-think the way Alarms interacts with
                     the Gantt chart.
       22-May-87 LAA Commented out the FlagIt procedures so this will compile.
                     Due to changes in Chart procedures taking a tree node
                     instead of a task.
        5/22/87 EGK  Made changes to get tasks through the tree.
       04-Jun-87 LAA Changed TraverseTree calls for new parameters.
       22-Oct-87 EGK Removed the comments and got things working again.  Used
                     AsOfDate instead of Today.  In AppropriateStartStatus,
                     we just return the old start status if the times were equal.
       29-Oct-87 EGK Don't call FlagIt for summary tasks or tasks which link
                     to other schedules, since their status gets rolled up.
       11-Jan-88 LAA Changed UnlockFlexStorDataObject to UnlockUnchanged
                     where appropriate.
       16-Sep-88 RSC Fixed "TooLong" error in "FlagIt".
       29-Nov-88 EGK OpenAncestors sends notice (for network view).
       21-Dec-88 LAA Changed imports for Laslo reorganization.
        7-Feb-89 EGK Created this from old Alarms.MOD.
       12-May-89 AJL Modified substantially so that it is only called on
                     user demand.
       24-May-89 AJL Modified to use the StatusChange module when the task's
                     status changes.
        1-Jun-89 RSC Modified to use AssUtilities.
        4-Jun-89 EGK  Changed NotifyUndo calls, for task changes, into
                      SendNotice calls.
        5-Jun-89 RSC Added use of "UsesCostTracking" in addition to the
                     "AdvancedTaskForm".
       19-Jun-89 AJL  Removed FiltersOn boolean, replaced by 
                      SetRevealFilterDisabled, and QueryRevealFilterOn.
       24-Jul-89 AJL  Fixed-date, started or Done tasks, whose EarlyStart
                      is not the same as their FixedStart will have an 
                      additional question asked to determine whether or
                      not they started on time. 
       10-Aug-89 KKC  Add copyright message.
       25-Aug-89 AJL  If the cost tracking task form or the large assignment
                      forms are used, updating a task's status will also
                      bring up the task form so that the details can be 
                      easily added.
       14-Sep-89 RSC  When you choose to Edit the task, the status was still
                      updated as if you said "Yes", AND the task form comes
                      up.  Bug # 1318 wants the setting of the status and
                      % achieved removed.  I dun did it.
       23-Oct-89 EGK  In FlagIt, call EditTheTask AFTER calling
                      FixTheDateAndStatus, if the user picked YES while in
                      cost-tracking mode.
       21-Feb-90 KKC  Remove import of Timeu.
       07-Jun-90 AJL  Remove import of Planner.
       30-Aug-90 RSC  Fixups for assignment trees.
       12-Sep-90  CL  Rename the former Plan.Dates.FixedStart field 
                      to UserEnteredStartDate and change its format 
                      from ADate to ABigTime.
       13-Sep-90 AJL  Format the UserEnteredStartDate with BigTimeToString
                      to keep maximum precision.
        3-Nov-90 AJL  Show the WBS number with each task if it is available.
                      Else, show the abbreviated parentage.
        7-Jan-90 AJL -When the percent achieved is entered, and not doing
                      cost tracking, update all spent efforts on the task.
                     -When a task becomes Started, set its percent achieved
                      to percent time elapsed.
       23-Jan-91 AJL -Only warn the user that the option settings are not
                      correct if recalc is Auto while the choice is to force
                      tasks into the future.
                     -Use a global StatusDate.
       25-Mar-91 AJL -Don't set the percent complete to TimeElapsedPercent
                      if it already has a reasonable value ( 0 < n < 100 ).
        5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
       13-Jun-91 LAA -Bug #4381.  Copied code from TLChange which adjusts
                      the NoSoonerStart & NoLaterStart flags so they're 
                      consistent with the start status.
       17-Jun-91 LAA -Fix up the UserEnteredEndDate when a task is marked as
                      Done.
        3-Jul-91 PFG -Fixed bug #4570:  The task dialog was sometimes getting
                      displayed twice if the user said "Yes" to change the
                      status AND we discover that there are some 
                      inconsistencies in the task data.  Now it's only 
                      displayed once.
       13-Aug-91 AJL -Change parameters to UpdateEffortToMatchRatio.
    *)

FROM Allocs       IMPORT ATaskPtr, AStartStatus, AFixType,
                         ATaskStatus, ATaskStatusSet, AnAssignmentSummary,
                         ATaskFlag, StartStatusName, ATask,
                         TaskTree;

FROM Alarms       IMPORT
    (* PROC *)           AppropriateStartStatus;

FROM AsOf         IMPORT
    (* VAR *)            AsOfDate;

FROM BigTimeU     IMPORT
    (* TYPE *)           ABigTime,
    (* PROC *)           BigTimeToTimeInfo;

FROM Captions     IMPORT
    (* TYPE *)           AColumnInfoChoice, AColumnDataField,
                         AColumnDataRecord,
    (* PROC *)           GetColumnValue;

FROM Changer      IMPORT ChangeTask,
                         AdvancedTaskForm, UsesCostTracking;

FROM Chart        IMPORT MChTask, CursorTask, GanttChart;

FROM ChartControl IMPORT SetState, AChartState, AChartStateSet, ChartState,
                         DisplayTheChart, UnSetState;

FROM Codes        IMPORT ACode, ASetOfCodes, SetCodeBits;

FROM Dialog       IMPORT 
    (* TYPE *)           ADialogOption,
    (* PROC *)           Burp, Message, Error, MultipleChoiceBox, FatalError,
                         ContinuationBox;

FROM EffDone                    IMPORT
    (* PROC *)                     UpdateEffortToMatchRatio;

FROM Filters      IMPORT
    (* PROC *)           ShowFilterLight,
                         SetRevealFilterDisabled, QueryRevealFilterOn;
IMPORT Gantt;

FROM Keys         IMPORT DoIt, CancelKey, ChngTskKey, TimeoutKey,
                         DelTaskKey;

FROM LStrings     IMPORT SetString, ConcatLS, SetLengthOf, Copy, LengthOf,
                         ConcatS, TrimRear, Fill;

FROM MsgFile      IMPORT GetMessage, ConcatMessage;

FROM Notices      IMPORT
    (* TYPE *)           AnOccasion, AStep,
    (* PROC *)           SendNotices;

FROM Overlays     IMPORT
    (* TYPE *)           AnOverlayID,
    (* PROC *)           OverlayContext, ImAnInstallableOverlay;

FROM OvTree       IMPORT
    (* TYPE *)           AnOverlayProc;

FROM Planner      IMPORT
    (* TYPE *)           AWhenToCalc, ACalcComponent,
    (* VAR *)            CalculationState, MoveFutureTasks,
    (* PROC *)           WeShouldRecalc;

FROM RsrcCalc     IMPORT SummTaskNodeAmounts;

FROM Schedule     IMPORT ScheduleSaved;

FROM StatusChange IMPORT
    (* PROC *)           CheckStatusChange, DefaultStatusDialogProc;

FROM SYSTEM       IMPORT
    (* TYPE *)           ADDRESS, ADR, TSIZE;

FROM TaskColNumbers         IMPORT
    (* CONST *)                 AbbrevParentage, WBSColumn, TimeElapsedPct;  

FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;

FROM Timei                  IMPORT
    (* TYPE  *)                 ADate, ADurationUnit, ATimeInfo;

FROM TimeXlate    IMPORT
    (* PROC *)           CalendarTimeToBigTime, BigTimeToCalendarTime;

FROM TreeObjects  IMPORT
    (* TYPE *)           ATreeNode, ATreeOrder;

FROM Undo         IMPORT
    (* TYPE *)           AnUndoStatus, AnUndoableObject, AnUndoAction,
    (* PROC *)           BeginTransactionSet, EndTransactionSet,
                         AbortTransactionSet, NotifyUndo;


CONST 
    ModuleNumber  = 3600;    (* For GetMessage *) 
    OneHundred    = 100.0;

VAR
    OverlayID                   : AnOverlayID;
    StatusDate                  : ADate;

    CostTrackingOrLargeTaskForm : BOOLEAN;



PROCEDURE BigTimeToString( B : ABigTime; VAR S : ARRAY OF CHAR );
VAR
    TimeInfo : ATimeInfo;
BEGIN
    BigTimeToTimeInfo(B,TimeInfo);
    TimeToString(TimeInfo,DefaultDateAndTimeFormat,S);
END BigTimeToString;




PROCEDURE DescribeTask(     Node     : ATreeNode;
                            TaskPtr  : ATaskPtr;
                        VAR S : ARRAY OF CHAR );
VAR
    ColumnData : AColumnDataRecord;
BEGIN
        (* Try to use name and WBS number.  Failing that, use the 
           abbreviated parentage and the name. *)
    Copy(TaskPtr^.taskname,S);
    IF GetColumnValue(Node,TaskPtr,WBSColumn,Gantt.Plan,ColumnData) THEN
        TrimRear(ColumnData.StringValue);
        IF (LengthOf(ColumnData.StringValue) > 0) THEN
            ConcatMessage(S,ModuleNumber+40);
            ConcatLS(S,ColumnData.StringValue);
            ConcatMessage(S,ModuleNumber+41);
        ELSE
            IF (Node^.Methods^.IndentationLevel(Node) >  0) AND
               GetColumnValue(Node,TaskPtr,AbbrevParentage,
                              Gantt.Plan,ColumnData) THEN
                Copy(ColumnData.StringValue,S);
                ConcatS(S,"\");
            ELSE
                SetLengthOf(S,0);
            END;
            ConcatLS(S,TaskPtr^.taskname);
        END;
    END;
END DescribeTask;



    (* CheckAlarms -- Look at all of the tasks.  If any are not correctly
                      noted as started, done, etc., then give the
                      user a chance to change the task status or description. *)

PROCEDURE CheckAlarms;
VAR
    TaskPtr                 : ATaskPtr;
    Node, NextNode          : ATreeNode;
    CorrectStatus           : AStartStatus;
    NeedToFlag              : BOOLEAN;
    KeepRunning             : BOOLEAN;

        (* DeferIt --
           Note that, although the status may not be correct, that 
           is ok with the user. *)


    PROCEDURE DeferIt   ( Node      : ATreeNode );
    BEGIN
        (*  
        TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
        INCL(TaskPtr^.TaskFlags, DeferAlarms);       (* Note not to alarm this one again. *)
        INCL(TaskPtr^.TaskStatusSet,NeedsRecalculate);
        Node^.Methods^.UnlockFlexStorDataObject (Node);
        UnSetState(Scheduled);                                 
        *)
    END DeferIt;


        (* Set the new start status, and make consequential adjustments 
           to the percent achieved, perhaps fixed-date, and recalc. *)

    PROCEDURE SetNewStatusAndAchievement (     Node  : ATreeNode );
    VAR
        Task            : ATaskPtr;
        NewStartStatus  : AStartStatus;
        ColumnData : AColumnDataRecord;
    BEGIN
        Task := Node^.Methods^.LockFlexStorDataObject (Node);
        NewStartStatus := AppropriateStartStatus(Task^,StatusDate);

        WITH Task^ DO
            IF (NewStartStatus <> FutureS) THEN    (* Started or Done. *)
                    (* If it is not a fixed-date task, then we computed a 
                       start date.  Fill that into the user-entered field
                       as a starting guess. *)
                IF (NOT (NoSoonerStart IN TaskFlags)) THEN
                    CalendarTimeToBigTime(Plan.Dates.EarlyStart,TRUE,
                                          UserEnteredStartDate);
                    NewStartStatus := AppropriateStartStatus(Task^,StatusDate);
                END;
                IF (NewStartStatus = DoneS) THEN               (* 17-Jun-91 *)
                    CalendarTimeToBigTime( Plan.Dates.EarlyEnd, TRUE, 
                                           UserEnteredEndDate );
                END;
            END;

            INCL(TaskStatusSet,NeedsRecalculate);

                (*  Force the PercentComplete field to a reasonable value  *)

            IF NewStartStatus = DoneS THEN                         (* 12/04/86 LAA *)
                PercentComplete := 100;
            ELSIF (NewStartStatus = FutureS) THEN
                PercentComplete := 0;
            ELSIF (PercentComplete =0) OR (PercentComplete >= 100) THEN
                IF GetColumnValue(Node,TaskPtr,TimeElapsedPct,
                                  Gantt.Plan,ColumnData) THEN
                    PercentComplete := TRUNC( ColumnData.RealValue * OneHundred );
                END;
            END;

                (* If we are not using cost tracking, update every 
                   assignment to be at the current percent complete. *)

            IF (NOT UsesCostTracking) THEN
                UpdateEffortToMatchRatio( Task^,
                                          FLOAT(PercentComplete)/OneHundred );
            END;

            StartStatus := NewStartStatus;
            IF (StartStatus = FutureS) AND                     (* 13-Jun-91 *)
               ((fixation = ASAP) OR (fixation = ALAP)) THEN   
                EXCL(TaskFlags,NoSoonerStart);
                EXCL(TaskFlags,NoLaterStart);
            END;
        END;
        Node^.Methods^.UnlockFlexStorDataObject (Node);
    END SetNewStatusAndAchievement;


    PROCEDURE FixTheDateAndStatus ( Node            : ATreeNode );
    VAR
        TheTask                 : ATaskPtr;
        Completed               : AnAssignmentSummary;
        ToGo                    : AnAssignmentSummary;

    BEGIN

        SummTaskNodeAmounts (Node, FALSE, Completed, ToGo);

        TheTask := Node^.Methods^.LockFlexStorDataObject (Node);
        WITH TheTask^ DO
            CompletedSummary := Completed;
            ToGoSummary := ToGo;
        END;
        Node^.Methods^.UnlockFlexStorDataObject (Node);

    END FixTheDateAndStatus;



    PROCEDURE FlagIt (Node              : ATreeNode;
                      NewStartStatus    : AStartStatus);
    VAR
        TaskPtr         : ATaskPtr;
        Code            : ACode;
        Choice          : CARDINAL;
        CodeSet         : ASetOfCodes;
        OldChartState   : AChartStateSet;
        s               : ARRAY [0..255] OF CHAR; (* RSC 9/16/88 *)
        s2              : ARRAY [0..17] OF CHAR;
        Choices         : ARRAY [0..255] OF CHAR;
        Title           : ARRAY [0..61] OF CHAR;
        Prefix          : ARRAY [0..1] OF CHAR;
        InProgress      : BOOLEAN; 
        Proceed         : BOOLEAN; 
        NeedToEditFirst : BOOLEAN;

            (* Open Ancestors.  Make sure that the task is visible
               by opening any closed ancestors. *)

        PROCEDURE OpenAncestors (Node   : ATreeNode);
        VAR
            ParentNode      : ATreeNode;
        BEGIN
            ParentNode := Node^.Methods^.Parent (Node);
            WHILE (ParentNode <> NIL) DO
                IF (NOT ParentNode^.Methods^.ChildrenVisible (ParentNode)) THEN
                    SendNotices (OpenATask, BeforeActing, ParentNode);   (* 6/4/89 EGK *)
                    ParentNode^.Methods^.SetChildrenVisible (ParentNode, TRUE);
                END;
                ParentNode := ParentNode^.Methods^.Parent (ParentNode);
            END;
        END OpenAncestors;

            (* EditTheTask -- Make editing changes to the task form. *)


        PROCEDURE EditTheTask   ( Node      : ATreeNode );

        BEGIN
            NotifyUndo (Task, ChartActive, GanttChart);
            BeginTransactionSet();

            (* RSC 14-Sep-89  SetNewStatusAndAchievement(Node); *** *)

            IF NOT ChangeTask (Node) THEN
                NotifyUndo (Task, ChartActive, GanttChart);
                AbortTransactionSet();
                DeferIt (Node); 
            END;

            NotifyUndo (Task, ChartActive, GanttChart);
            EndTransactionSet();
            UnSetState(Scheduled);                                 

        END EditTheTask;

    BEGIN
            (*  Temporarily fiddle around with the chart state. *)
        OldChartState := ChartState;
            (*  Show the chart without any cursor. *)
        CursorTask := NIL;
        ChartState := AChartStateSet{Scheduled,Sorted,Filtered};     (*  Suppress any recomputation. *) (* 11/04/86 LAA *)
            (*  Move to the task in question. *)
        MChTask(Node);
        IF (QueryRevealFilterOn()) AND NOT (Node^.Methods^.Visible (Node)) THEN
            SetRevealFilterDisabled();
            EXCL (OldChartState, Filtered);
        END;
        OpenAncestors (Node);
            (*  Restore the chart state. *)
        ChartState := OldChartState;
        UnSetState (Formatted);
        DisplayTheChart;

        TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
        InProgress := (TaskPtr^.StartStatus = NewStartStatus);
            
        IF (InProgress) AND (CostTrackingOrLargeTaskForm) THEN

            GetMessage(ModuleNumber + 20, s);          (* "(Status Assistant)" *)
            DescribeTask(Node,TaskPtr,Choices);
            ConcatLS(s,Choices);
            ConcatMessage(s, ModuleNumber + 21);       (* '" is Started . . ."' *)
            GetMessage(ModuleNumber + 22, Choices);    (* "Edit, No, Stop" *)
            SetLengthOf(Title,0);

            Node^.Methods^.UnlockUnchangedDataObject (Node);          (* 11-Jan-88 LAA *)

            SetLengthOf (Prefix, 0);
            Choice := 1;

            IF (NOT MultipleChoiceBox (s, Title, NoHelp, Prefix, Choices, Choice)) THEN
                Choice := 3;
            END;

            CASE Choice OF
                1 :
                    EditTheTask (Node);

            |   2 :
                    DeferIt (Node);
            |   3 :
                    KeepRunning := FALSE;
            END;

        ELSE

            REPEAT   
                DescribeTask(Node,TaskPtr,s);
                ConcatMessage(s, ModuleNumber + 2);                        (* '" should be ' *)
                ConcatLS(s,StartStatusName[NewStartStatus]);
                ConcatMessage(s, ModuleNumber + 3);                        (* " now.  Change it to " *)
                ConcatLS(s,StartStatusName[NewStartStatus]);
                ConcatMessage(s, ModuleNumber + 4);                        (* "?" *)
                GetMessage(ModuleNumber + 6, Choices);                     (* "Yes,Edit,No,Stop" *)
                GetMessage(ModuleNumber + 10, Title);
    
                SetLengthOf (Prefix, 0);
    
                Choice := 1;        (* Default is Yes *)
    
                IF (NOT MultipleChoiceBox (s, Title, NoHelp, Prefix, Choices, Choice)) THEN
                    Choice := 4;  (* Stop. *)
                END;
    
                Proceed := TRUE;
    
                WITH TaskPtr^ DO   
                    IF (Choice=1) 
                       AND (NewStartStatus <> FutureS)    (* Started or Done *)
                       AND (fixation = FixedDate) 
                       AND (BigTimeToCalendarTime(UserEnteredStartDate) <> Plan.Dates.EarlyStart) THEN
                        GetMessage(ModuleNumber + 30, s);          (* "Did " *)
                        DescribeTask(Node,TaskPtr,Choices);
                        ConcatLS(s,Choices);
                        ConcatMessage(s, ModuleNumber + 31);       (* ' start on schedule (' *)
                        BigTimeToString(UserEnteredStartDate, s2);
                        ConcatLS(s,s2);
                        ConcatMessage(s, ModuleNumber + 32);       (* ')?' *)
                            (* Yes = ok, No = Edit. *)
                        GetMessage(ModuleNumber + 33, Choices);    (* "Yes, No" *)
                        SetLengthOf(Title,0);
                        Choice := 2;
                        Burp; Burp; Burp;   (* Alert the user that something unexpected is asked. *)
                        IF (NOT MultipleChoiceBox (s, Title, NoHelp, Prefix, Choices, Choice)) THEN
                            Proceed := FALSE;
                        END;
                    END;
                END;
    
            UNTIL (Proceed);

            Node^.Methods^.UnlockUnchangedDataObject (Node);          (* 11-Jan-88 LAA *)

            CASE Choice OF
                1 :  (* Yes *)
                    NotifyUndo (Task, ChartActive, GanttChart);
                    BeginTransactionSet();
                    SendNotices (ChangeATask, BeforeActing, Node);   (* 6/4/89 EGK *)

                    (* 3-Jul-91 PFG   Check to see if the task form will
                                      need to be displayed because of 
                                      inconsistencies.  If it does, bring up
                                      the task form first, then make needed
                                      changes to the task.  Otherwise, make
                                      the needed changes first in case the
                                      task form needs to be brought up for
                                      some other reason.  *)
                    NeedToEditFirst := FALSE;
                    SetNewStatusAndAchievement(Node);
                    
                    IF (NOT CheckStatusChange(Node, DefaultStatusDialogProc)) THEN
                        NeedToEditFirst := TRUE;
                    ELSE
                        FixTheDateAndStatus(Node);
                    END;

                    UnSetState (Scheduled);

                    EndTransactionSet();

                    (* If the user says YES while cost tracking is used,
                       we give him the edit form after . *)

                    IF ((CostTrackingOrLargeTaskForm AND
                        (NewStartStatus <> FutureS)) OR
                        (NeedToEditFirst)) THEN
                        EditTheTask (Node);               (* 10/23/89 EGK *)
                    END;

                    IF (NeedToEditFirst) THEN   (* 3-Jul-91 PFG *)
                        FixTheDateAndStatus(Node);
                    END;

            |   2 :   (* Edit *)
                    EditTheTask (Node);

            |   3 :   (* No *)
                    DeferIt (Node);
            |   4 :   (* Stop *)
                    KeepRunning := FALSE;
            ELSE
                    FatalError(); 
            END;

        END;

        s[0] := 0C;
        Message(s);

        ScheduleSaved := FALSE;
        DisplayTheChart;
        UnSetState(Showing);

    END FlagIt;

BEGIN

    CostTrackingOrLargeTaskForm := (UsesCostTracking OR AdvancedTaskForm);

    Node := TaskTree^.Methods^.GetFirst (TaskTree);         (* 5/22/87 EGK *)

        (*  Loop through all the tasks.  Stop checking tasks after
            we have checked all of them, or the user turns off the
            process, or there is a scheduling problem (e.g. a loop). *)

    KeepRunning := TRUE;

    WHILE (Node <> NIL) AND (KeepRunning) DO
        NextNode := Node^.Methods^.NextPreOrder (Node);

        IF (Node^.Methods^.FirstChild (Node) = NIL) THEN
            NeedToFlag := FALSE;
            TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
            IF (ADDRESS(TaskPtr^.summarizes) = NIL) THEN
                CorrectStatus := AppropriateStartStatus(TaskPtr^,StatusDate);
                IF ((CorrectStatus <> TaskPtr^.StartStatus) OR
                   ((CostTrackingOrLargeTaskForm) AND
                   (CorrectStatus = StartedS) AND
                   (TaskPtr^.StartStatus = StartedS))) THEN
                    NeedToFlag := TRUE;
                END;
            END;
            Node^.Methods^.UnlockUnchangedDataObject (Node);            (* 11-Jan-88 LAA *)
            IF (NeedToFlag) THEN
                FlagIt (Node, CorrectStatus);
            END;
        END;
        Node := NextNode;                     (* "Task" may have been deleted. *)
    END;

END CheckAlarms;




PROCEDURE TLAlarmBody();
VAR
    S   : ARRAY[0..255] OF CHAR;
    Title : ARRAY [0..0] OF CHAR;

BEGIN                       (* TLAlarmBody *)

    S := "Program Copyright (c) 1989 Symantec Corporation.";
    SetLengthOf(Title,0);

        (* Status assistant works best when recalc options specify
           allowing future effort to the left of the as-of date line
           (or recalc has been done).    *)

    IF ( MoveFutureTasks ) AND (CalculationState[Scheduling].When=AutoCalc) THEN
        GetMessage(ModuleNumber+7,S);
        IF (NOT ContinuationBox(S,Title,NoHelp)) THEN
            RETURN;
        END;
    END;

    StatusDate := AsOfDate;

    CheckAlarms;

END TLAlarmBody;



BEGIN

    OverlayID := ImAnInstallableOverlay(TLAlarmBody, AnOverlayProc(NIL));
    TLAlarmBody();

END TLAlarm.


