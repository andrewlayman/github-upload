MODULE TLPlanEx;

(*V7=TRACE*)
(*V3=KILL  WITH set pointers to NIL *)

    (* The final step in recalc.  Do all the things downstream of 
       computing the schedule. *)

    (* MODIFICATION HISTORY:

      14-Feb-91 AJL  - Rename EndOf ActualDate to EndOfSpentDate.
      15-Feb-91 AJl  - Corrected an error in the CheckOverloads 
                       procedure which was returning a starting 
                       cell handle that was the next cell handle.
                       Except when the EndDate is at the cell boundary,
                       it should return the current cell.
                     - Added TRACE toggle.
       5-Mar-91 AJL  - If the LateTotalStart is earlier than the task
                       start date, show the deley marks beginning at the
                       late total start.
                     - Always do an overbooked check; not optionally.
       6-Mar-91 AJL  - Permit summary tasks to have delay marks; do not
                       overwrite the SupposedToStart field.
       7-Mar-91 AJL  - If there were problems during recalc, offer to display them.
       2-Apr-91 JES  - Put in some more trace print statements.  
       2-Apr-91 AJL  - Modify the loop that checks varying assignments for
                       overloads so that if we search for a date but it is
                       not in the varying assignment list, then, because it
                       must have been prior to the start date of the list, we
                       start searching with the first element.
                     - Change the structure of the loop from a WHILE to a 
                       REPEAT loop.
       5-Apr-91 AJL  - Moved FindIndependentDates to here from TLCPM.
      11-Apr-91 AJL  - Corrected a starting index when reading the error
                       log text.
                     - Add a Countdown progress indication to FindIndependent
                       Dates.
      30-May-91 AJL  - Speed up computation of Independent Slack dates by
                       removing recursive algorithm.
                     - Correct Independent Slack computations to include
                       partial dependencies from summary tasks.
                     - Call SummTaskNodeAmounts to recompute task costs.
      31-May-91 AJL  - Recompute the total effort of duration split tasks.
       5-Jun-91 AJL  - Recompute task costs.
      18-Jun-91 AJL  - Recompute the end dates of tasks during the Independent
                       slack calculations to take into account splitting that
                       could happen for effort or assignment driven tasks.
      21-Jun-91 AJL  - Use the TempFlag1 in the node to determine if the task
                       has any assignments.
                     - Remove dead code.
      24-Jun-91 AJL  - Avoid overflow when adding durations to dates.
                     - Display warning text even if only one line exists.
      25-Jun-91 AJL  - For duration driven tasks, after computing the effort
                       of each assignment, update the assignment record.
                     - Compute the effort and costs of resources on tasks
                       even if the varying assignment is NIL.
                     - Do not include the costs of assignments that are 
                       not marked "Billable."
      25-Jun-91 JES  - Added new parameters to the calls to FindEarliest
                        StartDate and FindEarliestStartForEffortSplit.
      27-Jun-91 AJL  - Unlock a doppleganger task before calling
                       ActivateSummaryTask.
       1-Jul-91 AJL  - If a summary task has a partial dependency to/from
                       its end, include that in its status set.  Bug 4677.
      12-Jul-91 AJL  - Moved NoteConflicts here and renamed it to 
                       CheckMovedByLevelling.
      19-Jul-91 AJL  - Mark tasks with the little "r" in their status
                       column if their date is made earlier or later by
                       levelling.
      26-Jul-91 AJL  - Check overloads on resources, even if they are
                       marked as not needing levelling.  This makes the "R"
                       more useful and makes levelling with some tasks
                       exempt more consistent with CPM only.
                     - In FindIndependentDates, only search for start
                       dates > IndependentStart, even if task has negative
                       total slack.
      30-Jul-91 AJL  - Don't clear the NeedsRecalculate flag.
      12-Aug-91 AJL  - Remove resources assigned to summary tasks from 
                       the residual availability.
      14-Aug-91 AJL  - Remove unused import of RsrcCalc.
      14-Aug-91 AJL  - If an effort-driven task was not computed correctly,
                       do not recompute its assignment costs.
      22-Aug-91 AJL  - Reinstate a change that I lost on this trip: compute
                       durations for effort-driven tasks (provided they
                       did not have a recalc problem).
                     - For effort-driven tasks, verify that the effort was
                       fully distributed to the assignments.
                     - Warn if a done task has its end date in the future,
                       or a started or done task starts in the future.
      16-Sep-91 AJL  - Warn if a future task has spent effort.
                     - Warn if a Done task has unspent effort.
                     - Warn if a milestone has spent effort or spent
                       variable costs.
                     - Add more comments.
      25-Sep-91 AJL  - Don't warn about efforts not fully allocated unless
                       they are >= calendar resolution.
      26-Sep-91 AJL  - Remove obsolete code which checks for late tasks.
      30-Sep-91 AJL  - Don't warn about efforts not fullocated unless 
                       difference exceeds 1% of task effort.
                     - Don't attempt to look for overloads for periods
                       >= MaxDate.
       3-Oct-91 AJL  - When finding independent dates, if the late total
                       end date is < the end of antecedants, search up to
                       the greater of the two.  Bug 5288.
       3-Oct-91 TGS  - Feed AverageResourceRate a "non-negative" interval.
       3-Oct-91 AJL  - Compute the BCWS and BCWP of each detail task.
       4-Oct-91 AJL  - Add documentation.
      12-Dec-91 AJL  - When computing the spent and to go efforts and dollars
                       of tasks in ComputeThisTasksCost, we had been working
                       from the varying assignment lists because this fully
                       reflected the results of scheduling.  However, it has
                       some rounding problems.  I have changed it so that 
                       tasks which were definitely not split or contoured have
                       their efforts taken as entered on the assignment forms
                       and their costs computed as that effort over the 
                       average of the period.
                         This remains imperfect.  Improvements could be made by
                       better detection of tasks which could have been but which
                       were not, in fact, split.  Also, there is a flaw in that
                       average rates could be wrong if levelling contours an
                       effort-split task, loading the effort unequally into more
                       than one rate period.
                         The best accuracy, however, would require that the varying
                       assignment lists be increased in their precision, which
                       would be rather expensive.
                         Please see additional notes at the end of this module.
      13-Dec-91 AJL  - The Start and EndOfSpent dates were not being computed
                       for resources in ComputeThisTaskCost, and this threw off
                       the above change.
                     - Duration-driven delay tasks will have their future effort
                       computed as the assigned rate times to-go duration.
      16-Dec-91 AJL  - Duration-driven delay tasks that are in the future
                       will leave their to-go effort unaltered (provided that
                       they have no spent effort.)
      18-Dec-91 AJL  - Fix bug 5375.  The amount assigned was ignored for 
                       computing costs of varying costs.
      18-Dec-91 AJL  - For duration-driven tasks, and assignments that had
                       an effort amount entered by the user, do not recompute
                       the to-go effort.
      20-Jan-92 AJL  - Compute the spent dollars directly from the spent 
                       effort, rather than the varying assignment list.
      27-Jan-92 AJL  - Speed up checking of overbooked tasks by first 
                       determining which resources are overbooked, and only
                       checking tasks to which those resources are assigned.
      29-Jan-92 AJL  - Changed rate parameters to REAL.
       3-Feb-92 AJL  - Only check resources, not cost types.
      10-Feb-92 AJL  - Improve the error message for spending on milestones.
      20-Feb-92 AJL  - Use ComputeEffortAndCostsInPeriod for effort or duration
                       split tasks so that we will have consistent cost
                       calculations whether effort is spent or to go.  My test 
                       schedule for this is AL920221.
      24-Feb-92 AJL  - Take out many of the optimizations in ComputeThisTaskCost.
                       They are in many cases no longer needed, and can lead to
                       errors, as in bug 5440.
      25-Feb-92 AJL  - Corrected the definition of critical.  The critical path
                       is the path of tasks through the schedule that has the 
                       least total slack.  When negative total slack appears, the
                       critical path may exclude some tasks that have <= zero
                       slack.  The value of the critical path is that it identifies
                       those tasks that should be managed to shorten the overall
                       project length.
      18-Mar-92 AJL  - Do not overwrite the YetToGoQuantity (remaining hours)
                       for assignments in which that was entered by the user
                       (ComputeByHours set).  Bug 5455.
       3-Apr-92 AJL  - Add LinkFailed warning to calc warnings log.
      16-Apr-92 AJL  - Do not recompute the costs of linked tasks, because the
                       computation will already have been done, perhaps more
                       accurately, in TLROLLEM.

      *)


FROM Allocs    IMPORT
    (* CONST *)         TskNmLen,
    (* TYPE *)          ATask, ADateBlock, AnAssignmentSummary,
                        ATaskPtr, ATaskName, AFixType,
                        AStartStatus, ATaskFlag, ATaskFlagSet, ARollupStatus,
                        ATaskStatusSet, ATaskStatus, ADurationMethod,
                        ATempTaskFlag, ATempTaskFlagSet, ASplittingRule,
    (* VAR *)           TaskTree,
                        StartStatusName,
    (* PROC *)          CheckTaskValid,
                        CreateTask, DelTask;

FROM AsOf      IMPORT
    (* VAR  *)          AsOfDate;

FROM AssgnCalc   IMPORT
    (* PROC *)          ComputeEffortsAndCostsInPeriod;

FROM Assignments IMPORT
    (* TYPE *)                  AnAssignmentAttribute,
                                AnAssignmentRecord, AnAssignmentArray,
    (* PROC *)                  ForEachAssignment;

FROM BigTimeU   IMPORT
    (* TYPE *)                  ABigTime,
    (* PROC *)                  CompareBigTimes;

FROM Boxes      IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM CalShift   IMPORT
    (* VAL  *)                  TimeSheet;

FROM CpmActivate  IMPORT
    (* PROC *)          ActivateSummaryTask;

FROM Dialog    IMPORT   Message, Error, FatalError, Burp,
                        ReleaseBox, ABoxHandle, WarningBox,
                        ADialogOption, ContinuationBox, ErrorPhrase;


FROM Duration   IMPORT
    (* PROC *)                  AddWorkingTime, FindDuration;


FROM Edges      IMPORT
    (* TYPE *)          AnEdgePtr;

FROM Edits      IMPORT
    (* PROC *)          EditText;

FROM FlexStor       IMPORT
    (* TYPE *)     AnExtHandle, AnExtStoragePreference,
    (* PROC *)     InitExtStorage, TerminateExtStorage,
                   CreateExtObject, SetExtData, GetExtData,
                   CreateExtObjectWithSize, SetExtSize, GetExtSize,
                   DiscardExtObject,
                   HandleIsValid, ObjectsAreSame,
                   SaveHeapCopy, MakeHeapCopy,
                   LockObject, LockObjectArray, ReleaseObject,
                   ReleaseUnchangedObject,
                   ArraySize, NumberOfElements,
                   CopyExtObject;

FROM Kbio      IMPORT   BreakRequested;

FROM Layout    IMPORT
    (* VAR *)           GanttWStart, GanttWEnd, MaxColumn, MaxRow;

FROM LStrings  IMPORT   SetString, ConcatS, ConcatLS, CtoS, Compare,
                        SubStr, Fill, TrimFront, Copy, Procustes,
                        LengthOf, SetLengthOf, Remove, Insert,
                        TrimRear;

FROM MsgFile   IMPORT   GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays  IMPORT
    (* PROC *)          OverlayContext;

FROM Phantoms  IMPORT
    (* CONST*)          SummaryFlag, PhantomFlag;

FROM Planner   IMPORT
    (* TYPE *)          APlannerContext, AWhenToCalc, ACalcComponent,
    (* VAR *)           Levelling, CalculationState, ScheduleComputedOk,
                        HonorDaysOff, MoveFutureTasks,
                        ScheduleStartDate, ScheduleEndDate;

FROM PTaskList    IMPORT
    (* CONST *)         AlreadyScheduled,
    (* VAR  *)          PrivateTaskList, TaskCount,
                        BoxHandle, BoxShowing, SpaceReserved, 
                        NeedLinkedScheduleRollin,
                        SomeLevel0TaskIsSummary,
    (* PROC *)          ListInit, AddBefore, DeList,
                        MoveList,
                        CountDown;

FROM RealFormat    IMPORT
    (* VAR *)           DefaultAmountFormat,
    (* PROC *)          FormatAsAmount;

FROM ResAvailableResources IMPORT
    (* PROC *)          ScheduleResource;

FROM ResCal        IMPORT
    (* TYPE *)          AnAvailabilityCellPointer, AnAvailabilityCell,
    (* PROC *)          DisposeResAvailabilities, CellContainingDate;

FROM ResConstants  IMPORT
    (* VAR *)           SchedulingAbandoned;

FROM ResStartDates IMPORT
    (* PROC *)          FindEarliestStartDate,
                        FindEarliestStartForEffortSplit;

FROM ResUtilities IMPORT
    (* PROC *)          LatestAntecedantEndDate, EarliestDescendantStartDate,
                        TaskUsesNoEmployableResources;

FROM ResWarnings   IMPORT
    (* TYPE *)          AWarning,
    (* VAR *)           WarningLogText,
    (* PROC *)          IssueWarning, IssueWarningWithParms, SendErrorMsg;

FROM Rollups   IMPORT   RollupPlan;

FROM RsrcMod   IMPORT
    (* TYPE *)          AResourcePointer, AResourceType, ACostStyle,
    (* VAR *)           ResourceTree,
    (* PROC *)          AverageResourceRate;

FROM SYSTEM          IMPORT
     (* TYPES *)        ADR, ADDRESS, TSIZE;

FROM Text           IMPORT
    (* TYPE *)          AText,
    (* PROC *)          TextExists, LineExists, CopyLine, AppendLine,
                        CreateText, DiscardText;

FROM Timei          IMPORT
    (* CONST*)          NoDuration, MaxDate, MinDate, OneUnitOfDuration,
    (* TYPE *)          ADate, ADuration;

FROM Timeu      IMPORT
    (* VAR *)       SMU, FSMUPH;

FROM TimeXlate      IMPORT
    (* PROC *)          BigTimeToCalendarTime, CalendarTimeToBigTime,
    (* PROC *)          TimesToBigTimes;


FROM TreeObjects IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder, ATreeNodeAttribute,
    (* PROC *)          ValidateTree, ValidateTreeNode;

FROM Words         IMPORT
    (* PROC *)          ParseBal, FindPriorWord;

FROM VaryAssgnment IMPORT
    (* TYPE *)          AVaryingAssgnList,
    (* PROC *)          CreateVaryingAssgnList, DisposeVaryingAssgnList,
                        CreateVaryingAssgnListRange,CreateVaryingAssgnListEntry,
                        GetVaryingAssgnListEntry, LocateDateInVaryingAssgnList;

(*<TRACE
FROM FlexDisp      IMPORT HandleToString;
FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;
FROM Tracer IMPORT PrintString, EndTrace;
FROM ResTrace IMPORT ConcatTaskID;
TRACE>*)



    (*<TRACE
VAR
    TraceS : ARRAY [0..255] OF CHAR;
    TraceS2 : ARRAY [0..51] OF CHAR;
    TRACE>*)



CONST
    ModuleNumber = 3800;        (* For GetMessage, shared w/ TLPlan *)
    HowOften = 32;              (* Interval for progress reports. *)
    Zero     = 0.0;
    OneHundred = 100.0;
VAR
    PlannerContext          : APlannerContext;
    ToGo                    : CARDINAL;          (* Countdown number of tasks. *)
    OneHundredTimesSMUPH    : REAL;      
    LeastSlack              : LONGINT;



PROCEDURE MaybeCountDown(phrase:CARDINAL; ToGo : CARDINAL);

BEGIN
    IF (TaskCount >= 100) THEN
        CountDown(phrase,TaskCount,ToGo);
    END;
END MaybeCountDown;



PROCEDURE NoteThis(VAR s:ARRAY OF CHAR);
BEGIN
    IF (NOT SpaceReserved) THEN
        SpaceReserved := TRUE;
        Message(s);
    END;
END NoteThis;






PROCEDURE DoStep( Step : ACalcComponent;
                  DoAllSteps : BOOLEAN )   : BOOLEAN;
BEGIN
    RETURN DoAllSteps OR
           (CalculationState[Step].When = AutoCalc);
END DoStep;





    (* ------------------------------------------------------------------

       FindIndependentDates

       Finds the Independent (Total) start dates and slack for all tasks.

       This is the difference between the latest of the late total end
       dates of all antecedants (LateTotalIndependentStart) and the 
       EarlyStart of all dependents.

       It is a measure of how much slack (if any!) would remain on this
       task if all of its antecedants ended as late as they totally could.

       The quantity "LeastSlack" is also computed as a side-effect of this
       procedure.  It is the smallest LTE-EE.

       ---------------------------------------------------------------- *)




PROCEDURE FindIndependentDates(     PrivateTaskList   : AnExtHandle;
                                VAR LeastSlack        : LONGINT );
VAR
    Task                   : ATaskPtr;
    TaskHandle             : AnExtHandle;
    nextHandle             : AnExtHandle;
    EdgeDate  : ADate;      (* Used for processing partial joins. *)
    IndependentStart,
    EndSearchDate          : ADate;
    FoundADate             : BOOLEAN;
    Dummy                  : BOOLEAN; (* for unused parameters in EarliestStart *)
    ToGo                   : CARDINAL;
    TotalSlack             : LONGINT;
    Copyright  : ARRAY[0..51] OF CHAR;

    (* Find the latest total end date of any antecedant task in the edge
       list.  This procedure is recursive, in that summary tasks are
       not checked directly, but each antecedant of the summary is 
       checked.  We want to find the latest date than any REAL antecedant
       might end.
       
       However, rather than writing the procedure recursively, we rely on
       the fact that we are processing the list in topological order.
       This guarantees us that each summary task will have its Late
       Independent Start set to the latest of its antecedant end dates, 
       earlier in the process than we need to view it.
       *)


    PROCEDURE FindLatestAnteEdge(  Edge : AnEdgePtr ) : ADate;
    VAR
        AntecedantNode                     : ATreeNode;
        AntecedantHandle : AnExtHandle;
        Antecedant : ATaskPtr;
        EdgeDate   : ADate;      (* Used for processing partial joins. *)
        LatestDate : ADate;   
        AntecedantEdges : AnEdgePtr;
    BEGIN
        LatestDate := MinDate;
        WHILE (Edge <> NIL) DO
            AntecedantNode := Edge^.headtask;
            CheckTaskValid(AntecedantNode);
            Antecedant := AntecedantNode^.Methods^.LockFlexStorDataObject(
                              AntecedantNode);
            IF (SummaryFlag IN Antecedant^.TempTaskFlags) THEN
                   (*<TRACE
                SetString(TraceS,"  Antecedant is SUMMARY: ");  ConcatTaskID(TraceS,Antecedant);
                PrintString(TraceS);
                   TRACE>*)
                EdgeDate := Antecedant^.Plan.Dates.LateIndStart;
            ELSE
                    (*  Find latest (maximum) late total end date of all
                        antecedant tasks. *)
                EdgeDate := Antecedant^.Plan.Dates.LateTotalEnd;
                   (*<TRACE
                SetString(TraceS,"  Antecedant is ");  ConcatTaskID(TraceS,Antecedant);
                ConcatS(TraceS,", EdgeDate = "); TimeUtoS(EdgeDate,TraceS2);  ConcatLS(TraceS,TraceS2);
                PrintString(TraceS);
                   TRACE>*)
        
            END;

            AntecedantNode^.Methods^.UnlockUnchangedDataObject( AntecedantNode);
                                            (*<KILL Antecedant := NIL; KILL>*)


                (* Adjust for effect of partial dependencies. *)
            (*$R-*) (*$T-*)   (* Don't want no range checking. *)
            INC(EdgeDate,Edge^.Delta);
            (*$R=*) (*$T=*)   (* Don't want no range checking. *)
    
            IF (EdgeDate > LatestDate) THEN
                LatestDate := EdgeDate;
            END;
        
            Edge := Edge^.taillink;
        END;

        RETURN LatestDate;
    
    END FindLatestAnteEdge;


BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
       (*<TRACE
    SetString(TraceS,"******* Procedure FindIndependentDates ********");    SetString(TraceS2,"TLCPM");
    PrintString(TraceS);
       TRACE>*)


    ToGo := TaskCount;

    LeastSlack := MAX(LONGINT);

    (*
        IndependentLateStart := Max-Predecessors(TotalLateEnd).
        IndependentLateEnd   := IndependentLateStart + duration;
    *)

    IF (LockObject(PrivateTaskList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(PrivateTaskList);             (*<KILL Task := NIL; KILL>*)

    WHILE (NOT ObjectsAreSame(TaskHandle,PrivateTaskList))
          AND
          (NOT SchedulingAbandoned) DO


        IF (BreakRequested()) THEN
            SchedulingAbandoned := TRUE;
        END;


        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;

        WITH Task^.Plan.Dates DO
            LateIndStart := EarlyStart;
            LateIndEnd   := EarlyEnd;
            IndependentStart := EarlyStart;

            TotalSlack   := VAL(LONGINT,LateTotalEnd) - VAL(LONGINT,EarlyEnd);
        END;

        IF (TotalSlack < LeastSlack) THEN
            LeastSlack := TotalSlack;
        END;


           (*<TRACE
        SetLengthOf(TraceS,0);  ConcatTaskID(TraceS,Task);
        ConcatS(TraceS,", Currently, ES = "); TimeUtoS(Task^.Plan.Dates.EarlyStart,TraceS2);  ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS,"            LTS = "); TimeUtoS(Task^.Plan.Dates.LateTotalStart,TraceS2);  ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
           TRACE>*)


            (* Unless a task has free slack, it cannot have positive 
               independent slack.   Most tasks won't have free slack, so this pass
               would save a lot of work and so should run very
               quickly.
               
               However, such tasks might still have NEGATIVE independent slack
               if their antecedants have slack, so before we really know that the 
               independent slack is zero, we must check that the total slack is
               zero.

               In order for a task to have negative independent slack, the latest total
               end date over all predecessors would have to be later than the early
               start date of the task, which can be tested by checking whether the
               total end of the task is later than its early end.

               In order to have positive independent slack, it is necessary to have
               free slack; in order to have free slack, the task must have total slack.

               Consequently, having non-zero total slack is a necessary condition to have 
               independent slack.


               
               
               *)

            (* Tasks which are started or done have a known start date,
               independent of the antecedants. *)

            (* Unless this task's dates are locked (frozen), examine the
               predecessors. *)

        IF (SummaryFlag IN Task^.TempTaskFlags)
           OR
           (
             (Task^.StartStatus = FutureS) AND
             (Task^.TaskFlags * ATaskFlagSet{NoSoonerStart,NoLaterStart} <>
                                ATaskFlagSet{NoSoonerStart,NoLaterStart} ) 
             AND
             (NOT (FrozenTask IN Task^.TaskFlags)) AND (* Don't change the dates of frozen tasks. *)
             (Task^.Plan.Dates.LateTotalEnd > Task^.Plan.Dates.EarlyEnd)
           ) THEN
           
            EdgeDate := FindLatestAnteEdge( Task^.antetasks );

            IF (EdgeDate > IndependentStart) THEN
                IndependentStart := EdgeDate;
            END;
    
                (* At this point, IndependentStart is the maximum of the
                   latest possible end dates of all predecessors. *)

            WITH Task^.Plan.Dates DO

                (*<TRACE
                SetString(TraceS,"    IndependentStart = ");
                TimeUtoS(IndependentStart,TraceS2);  ConcatLS(TraceS,TraceS2);
                PrintString(TraceS);
                TRACE>*)

                    (* The negative slack option controls the scheduling of
                       tasks so that they are (optionally) delayed in their
                       start rather than create negative TOTAL slack.  It
                       controls their scheduling; not their measurement.
                       Note, however, that this does not eliminate
                       negative independent slack.  It is easily possible,
                       and useful to know, that the latest end date of the
                       latest antecedant might be later than the late 
                       free end date.  *)

                IF (Task^.DurationMethod = DurationDriven) THEN
                    LateIndStart := IndependentStart;
                    IF (IndependentStart <= MaxDate - Task^.duration) THEN
                        LateIndEnd   := IndependentStart + Task^.duration;
                    ELSE  (* avoid overflow. *)
                        LateIndEnd   := MaxDate;
                    END;
                    FoundADate    := TRUE;
                ELSE
                        (* We are going to look for a start date in the 
                           range [IndependentStart .. MAX(IndepStart,LTS) )
                        *)
    
                    EndSearchDate := LateTotalStart;
                    IF (EndSearchDate < IndependentStart) THEN
                        EndSearchDate := IndependentStart;
                    END;

                    (*<TRACE
                    SetString(TraceS,"    EndSearchDate  = ");
                    TimeUtoS(EndSearchDate,TraceS2);  ConcatLS(TraceS,TraceS2);
                    PrintString(TraceS);
                    TRACE>*)

                    IF (Task^.SplittingRule = Split) AND 
                       (Task^.DurationMethod = EffortDriven) THEN
                        FindEarliestStartForEffortSplit (Task,
                                               IndependentStart,   (* Start search *)
                                               EndSearchDate,      (* End Search *)
                                               TRUE (*AllowOverbookings*),
                                               FALSE (*DoWeContour*), 
                                               TRUE, (*DoWeComputeTaskEndDate*)
                                               FoundADate,
                                               LateIndStart,
                                               LateIndEnd,
                                               Dummy);
                    ELSE
                        FindEarliestStartDate (Task,
                                               IndependentStart,   (* Start search *)
                                               EndSearchDate,      (* End Search *)
                                               TRUE (*AllowOverbookings*),
                                               FoundADate,
                                               LateIndStart,
                                               LateIndEnd,
                                               Dummy);
                    END;
                END;

                    (* Check for an error in finding an end date. *)
                IF (NOT FoundADate) THEN
                    LateIndStart := IndependentStart;
                    IF (IndependentStart <= MaxDate - Task^.duration) THEN
                        LateIndEnd   := IndependentStart + Task^.duration;
                    ELSE  (* Avoid overflow. *)
                        LateIndEnd   := MaxDate;
                    END;
                END;

            END;

        END;     (* of exemption for frozen tasks. *)


        (*<TRACE
        SetString(TraceS,"    Ind Start = ");
        TimeUtoS(Task^.Plan.Dates.LateIndStart,TraceS2);  ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        TRACE>*)

        DEC(ToGo);
        IF ((ToGo MOD HowOften) = 0) THEN
            MaybeCountDown(ModuleNumber+19,ToGo);   (* 'Analyzing Independent Slack. *)
        END;

        (* On to the next task. *)

        nextHandle := Task^.Nextlink;
        ReleaseObject(TaskHandle);      (*<KILL Task := NIL; KILL>*)
        TaskHandle := nextHandle;
    END;
END FindIndependentDates;














PROCEDURE SetDatesAndStatus(LeastSlack : LONGINT);
VAR
    TaskHandle            : AnExtHandle;
    NextHandle            : AnExtHandle;
    Task                  : ATaskPtr;
    Date                  : ADate;
    ToGo                  : CARDINAL;
    TotalSlack            : LONGINT;
    Changed               : BOOLEAN;
BEGIN


    ToGo := TaskCount;
        (* Make a forward pass through the tasks to move the
           early dates of the phantoms. *)

    IF (LockObject(PrivateTaskList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(PrivateTaskList);    (*<KILL  Task := NIL; KILL>*)
    WHILE (NOT (ObjectsAreSame(TaskHandle,PrivateTaskList))) AND
          (NOT BreakRequested()) DO
        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;

        NextHandle := Task^.Nextlink;
        Changed := FALSE;



        WITH Task^ DO
            IF (NOT (FrozenTask IN TaskFlags) )  THEN   (* Unless frozen . . . *)

                    (* Schedule each phantom summary end milestone at its earliest
                       possible date.  We need to do this so that we can compute
                       which ones are truely critical, a calculation that would
                       be obscured by the general treatment of phantoms as ALAP.
                       This must be done before we transfer the status information
                       from the phantom to the real task, and before rolling up
                       dates, or otherwise losing this data.
                     *)
                IF (PhantomFlag IN Task^.TempTaskFlags) THEN
                    Date :=  LatestAntecedantEndDate(Task,MinDate);
                    WITH Task^.Plan.Dates DO
                        EarlyStart := Date;
                        EarlyEnd   := Date;
                    END;
                    Changed := TRUE;
                END;
                    (* Flag critical tasks. *)
                WITH Plan.Dates DO
                    TotalSlack := VAL(LONGINT,LateTotalEnd) - VAL(LONGINT,EarlyEnd);
                END;
                IF (ForceCritical IN TaskFlags) OR (TotalSlack <= LeastSlack) THEN
                    INCL(TaskStatusSet,Critical);
                    Changed := TRUE;
                END;
                
            END;
        END;

        IF (Changed) THEN
            ReleaseObject(TaskHandle);              (*<KILL  Task := NIL; KILL>*)
        ELSE
            ReleaseUnchangedObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
        END;

             (* On to the next task. *)
        DEC(ToGo);
        IF ((ToGo MOD HowOften) = 0) THEN
            MaybeCountDown(ModuleNumber+15,ToGo);   (* 'Analyzing critical path.' *)
        END;

        TaskHandle := NextHandle;
    END;


    (*------  This is commented out because there is nobody at present who
              would use the information.

        (* Make a backward pass through the tasks to move the
           late free end dates of the phantoms. *)
    IF (LockObject(PrivateTaskList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Prevlink;
    ReleaseUnchangedObject(PrivateTaskList);    (*<KILL  Task := NIL; KILL>*)
    WHILE (NOT (ObjectsAreSame(TaskHandle,PrivateTaskList))) AND
          (NOT BreakRequested()) DO
        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;

        IF (PhantomFlag IN Task^.TaskFlags) THEN
            Date :=  EarliestDescendantStartDate(Task,MaxDate);
            WITH Task^.Plan.Dates DO
                LateFreeStart := Date;
                LateFreeEnd   := Date;
            END;
        END;


        NextHandle := Task^.Prevlink;
        ReleaseUnchangedObject(TaskHandle);
        TaskHandle := NextHandle;
    END;
   -----*)



END SetDatesAndStatus;








    (* We update the residual availability tables after most of the processing
       is done because CPM scheduling doesn't need to track the ongoing
       availabilities.  By waiting until the end, we reduce the size of the
       tables during the earlier passes, and speed them up.
       
       This code is duplicated in TLCPM.
       
       *)


PROCEDURE RemoveOneAssignmentFromAvailability(  VAR Assignment      : AnAssignmentRecord;
                                                    Context         : ADDRESS            ) : BOOLEAN;
VAR
    i : CARDINAL;
    PeriodStart,PeriodEnd : ADate;
    PeriodRate            : REAL;
BEGIN
    WITH Assignment DO
            (* Update the list of residual availabilities to show that we
               consumed the resource. *)
        i := 1;
        WHILE ( GetVaryingAssgnListEntry( VaryingAssignment, i,
                                          PeriodStart, PeriodEnd, PeriodRate ))
            AND
              (NOT SchedulingAbandoned) 
            DO
                (* Only schedule entries in the date range we just added. *)
            IF (PeriodRate <> Zero) THEN
                ScheduleResource  (Resource,
                                   TRUNC(PeriodRate),PeriodStart,PeriodEnd);
            END;
            INC(i);
        END;
    END;
    RETURN TRUE;
END RemoveOneAssignmentFromAvailability;








PROCEDURE ExpandSummaryDate( VAR TaskNode : ATreeNode;           (* Created 9/13/89 AJL *)
                                Context  : ADDRESS  );
VAR
    Child : ATreeNode;
    DopplegangerNode : ATreeNode;
    Task, DopplegangerTask : ATaskPtr;
    AssignmentHandle       : AnExtHandle;
    AllIsInOrder : BOOLEAN;

BEGIN
        (* Process only summary tasks. *)

    Child := TaskNode^.Methods^.FirstChild(TaskNode);

    IF (Child <> NIL) THEN  (* A Summary Task *)

            (* This ABSOLUTELY REQUIRES that the doppleganger was
               placed into the list immediately following the real
               task. *)

        DopplegangerNode := TaskNode^.Methods^.GetNext(TaskNode);


        IF (DopplegangerNode <> NIL) THEN
            DopplegangerTask := DopplegangerNode^.Methods^.LockFlexStorDataObject(DopplegangerNode);
            AllIsInOrder := (PhantomFlag IN DopplegangerTask^.TempTaskFlags);
            DopplegangerNode^.Methods^.UnlockUnchangedDataObject(DopplegangerNode);
        ELSE
            AllIsInOrder := FALSE;    (* Missing doppleganger task. *)
        END;



        IF (AllIsInOrder) THEN
            Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

            DopplegangerTask := DopplegangerNode^.Methods^.LockFlexStorDataObject(DopplegangerNode);
            WITH Task^.Plan.Dates DO
                EarlyEnd       := DopplegangerTask^.Plan.Dates.EarlyEnd;
                LateFreeEnd    := DopplegangerTask^.Plan.Dates.LateFreeEnd;
                LateTotalEnd   := DopplegangerTask^.Plan.Dates.LateTotalEnd;
                Task^.duration := FindDuration( EarlyStart, EarlyEnd, TimeSheet );
                LateIndEnd     := AddWorkingTime( LateIndStart, Task^.duration, TimeSheet );
            END;
            DopplegangerNode^.Methods^.UnlockUnchangedDataObject(DopplegangerNode);

            (* If there are any resources assigned to the summary task, schedule
               their effort now that we know the dates. *)

            ActivateSummaryTask(Task);

            AssignmentHandle := Task^.Plan.Assignments;
            TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

            ForEachAssignment (AssignmentHandle,
                               RemoveOneAssignmentFromAvailability,
                               NIL);
        END;

     END;

END ExpandSummaryDate;




PROCEDURE ExpandSummaryDates();
BEGIN
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,
                    MAX(CARDINAL),ExpandSummaryDate,
                    NIL   );
END ExpandSummaryDates;








    (* CostToDate -- Compute the proportion of the Amount linearly
                     distributed from TaskStart to TaskEnd as of the 
                     AsOfDate.
                     
                     This code, computation of BCWS and BCWP, is 
                     duplicated in TLMkBase and Rollups. 
                     
                     *)



PROCEDURE CostToDate(     Amount         : REAL;
                          TaskStart,
                          TaskEnd        : ADate   ) : REAL;
BEGIN
    IF (AsOfDate <= TaskStart) THEN
        RETURN Zero;
    ELSIF (TaskEnd <= AsOfDate) THEN
        RETURN Amount;
    ELSE
        RETURN ( FLOAT(AsOfDate-TaskStart) / FLOAT(TaskEnd-TaskStart) ) * Amount;
    END;
END CostToDate;






(* CheckForOverload ---- 

     This procedure assumes that a resource has been assigned to a task 
     at a positive rate during the given interval. It sets Overload
     to TRUE if either

     (1) HonorDaysOff is true and there is some point during the interval
         at which the resource is on vacation; or

     (2) The resource is levellable and there is some point during the
         interval at which the residue availability is negative.
     
     Otherwise it sets Overload to FALSE.

     In its search through the residue availbility list, it starts at
     the given CellHandleToStartAt, and returns in NextCellHandleToStartAt
     the "NextCell" field of the last cell it touched.

*)


PROCEDURE CheckForOverload (CellHandleToStartAt     : AnExtHandle;
                            StartDate               : ADate;       
                            EndDate                 : ADate;
                        VAR NextCellHandleToStartAt : AnExtHandle;
                            LevellableResource      : BOOLEAN;
                        VAR Overload                : BOOLEAN);
VAR
    CellHandle       : AnExtHandle;
    NextCellHandle   : AnExtHandle;
    Cell             : AnAvailabilityCellPointer;
    Finished         : BOOLEAN;
BEGIN
    (*<TRACE
    SetString(TraceS,"    CheckForOverload at  ");
    TimeUtoS(StartDate,TraceS2);  ConcatLS(TraceS,TraceS2);  ConcatS(TraceS," thru ");
    TimeUtoS(EndDate,TraceS2);  ConcatLS(TraceS,TraceS2);
    PrintString(TraceS);
    SetString(TraceS,"    CellHandleToStartAt = ");
    HandleToString(CellHandleToStartAt,TraceS2);  ConcatLS(TraceS,TraceS2);
    PrintString(TraceS);
    TRACE>*)

    Overload := FALSE;

    IF (StartDate = MaxDate) THEN
        RETURN;
    END;


    Finished := FALSE;
    CellHandle := CellContainingDate
                       (CellHandleToStartAt, StartDate);
    (*<DEBUG*)
    IF CellHandle = AnExtHandle(NIL) THEN
        FatalError();
    END;
    (*DEBUG>*)


    REPEAT
        IF (LockObject(CellHandle,Cell) = 0) THEN FatalError; END;

        (*<DEBUG*)
        IF Cell^.IsHeadCell THEN 
            SendErrorMsg("CheckOverload reached head cell - exiting ");
            FatalError();
        END;
        (*DEBUG>*)

        IF (Cell^.ThisIsAVacation)
                 OR
          ((LevellableResource) AND (Cell^.AmountAvailable < 0L)) THEN
            Overload := TRUE;              
        END;

        NextCellHandle := Cell^.NextCell;
        IF Cell^.EndDate >= EndDate THEN
            Finished := TRUE;
            NextCellHandleToStartAt := CellHandle;
        END;

        ReleaseUnchangedObject(CellHandle);
        CellHandle := NextCellHandle;

    UNTIL Overload OR Finished;

END CheckForOverload;       
       






(* -------- NoteResourceOverloads ---------------------------------

    A.  Note Resource Overloads

        Check each task's assignments for resource overbookings.

        An overbooking is defined as a point in time when
        either (a) the residue availability structure indicates a
        negative amount, or (b) the availability structure indicates 
        a vacation but the varying assignment shows usage of the
        resource by the task. (Note: (a) is checked only if the
        resource is levellable, and (b) is checked only if HonorDays
        Off is true.)

        Each assignment is checked for overbookings during the period of 
        time on or after its end of spending date and before the task
        end date (i.e., we check only the future portion of the task), 
        and, within that period, only when the varying assignments 
        structure indicates actual usage of the resource. 
        
                
        For every overbooking found, both the task and the
        task's assignment record are marked as overloaded. 

    B.  Compute the BCWS of each DETAIL task.   (RollupPlan will compute
        the BCWS of the summary tasks).  We compute the detail BCWS and 
        BCWP here, rather than in Rollups, in order to reduce the number
        of locks performed, speeding up recalc slightly, but forcing us
        to duplicate code.  In fact, code is similarly duplicated in 
        TLMkBase.)

    C.  Compute the BCWP also.

*)



PROCEDURE NoteResourceOverloads();
CONST
    OverloadSetSize       = 32;   (* Equivalence classes for resource id's *)
TYPE
        (* If a resource's id, mod set size, is not in this set, then 
           the resource is not overloaded. *)
    AnOverloadSet         = SET OF [0..OverloadSetSize-1];

VAR
    TaskHandle            : AnExtHandle;
    NextHandle            : AnExtHandle;
    CellHandleToStartAt, NextCellHandleToStartAt
                          : AnExtHandle; (* to residue avail cells *)
    AssignmentHandle      : AnExtHandle;
    Assignments           : AnAssignmentArray;
    ResourceWeUse         : AResourcePointer;
    LAssignments          : AnAssignmentArray; (* local copy of assts array*)
    VAssignments          : AVaryingAssgnList; 
    RsrcNode              :   ATreeNode;
    AsstRate              : REAL;
    OverloadSet           : AnOverloadSet;
    FingerprintSet        : BITSET;  (* Same rules as overload set, sized for task record. *)
    Task                  : ATaskPtr;
    ResourceCount, 
      i, j, n                : CARDINAL;
    StartDate, EndDate,
    AsstStart, AsstEnd    : ADate;
    ToGo                  : CARDINAL;
    Size                  : CARDINAL;
    AsstOverload, TaskOverload, ArrayAllocated,
    GotAnEntry, LevellableResource,
    WorthChecking  
                          : BOOLEAN;

BEGIN
        (* Create sets that indicate which resources might be overloaded,
           and which definitely are not. *)

    OverloadSet := AnOverloadSet{};
    FingerprintSet := {};

    RsrcNode := ResourceTree^.Methods^.GetFirst(ResourceTree);
    WHILE ( RsrcNode <> NIL ) DO
        ResourceWeUse := RsrcNode^.Methods^.GetDataObject( RsrcNode );
            (* See if this resource is overbooked. *)
        IF (ResourceWeUse^.Type <> AccountingOnly) THEN
            AsstOverload := FALSE;
            LevellableResource := ResourceWeUse^.LevelThisResource;
            CellHandleToStartAt := ResourceWeUse^.ResidueAvailProfile;
            CheckForOverload(CellHandleToStartAt,
                             MIN(ADate),MAX(ADate),
                             NextCellHandleToStartAt,
                             LevellableResource,
                             AsstOverload);
            IF (AsstOverload) THEN
                i := ResourceWeUse^.ID;
                INCL(FingerprintSet,i MOD 16);
                INCL(OverloadSet,i MOD OverloadSetSize);
            END;
        END;
        RsrcNode := RsrcNode^.Methods^.GetNext(RsrcNode);
    END;
    


    ToGo := TaskCount;
    IF (LockObject(PrivateTaskList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(PrivateTaskList);    (*<KILL  Task := NIL; KILL>*)

    (* loop through the tasks *)
    WHILE (NOT (ObjectsAreSame(TaskHandle,PrivateTaskList))) AND
          (NOT BreakRequested()) DO
        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;

        (*<TRACE
        SetString(TraceS,"CheckOverload ");  ConcatTaskID(TraceS,Task);
        PrintString(TraceS);
        TRACE>*)


            (* Compute the BCWS and BCWP of each detail task. *)

        WITH Task^ DO
            IF (NOT (SummaryFlag IN Task^.TempTaskFlags)) AND
               (BaseLineExists IN Task^.TaskFlags) THEN
                BCWSDollars :=  CostToDate(BaseLineSummary.Amount,
                                           BaseLine.Dates.EarlyStart,
                                           BaseLine.Dates.EarlyEnd);
                BCWP  := FLOAT(PercentComplete)/OneHundred * BaseLineSummary.Amount;
            ELSE
                BCWSDollars := Zero;
                BCWP        := Zero;
            END;
        END;

            
            (* Check for task overloads. *)


        TaskOverload := FALSE;     (* Task is not yet known to be overloaded. *)

        NextHandle             := Task^.Nextlink;
        WITH Task^.Plan DO
            AssignmentHandle       := Assignments;
            StartDate              := Dates.EarlyStart;
            EndDate                := Dates.EarlyEnd;
        END;
	    (* Decide whether this task even has the possibility of
               being flagged as overbooked.   That is, it has to have
               positive duration, not be done, have at least one resource
               that is somewhere overbooked, and have some 
               employable resources. *)
        WorthChecking := 
            (EndDate > StartDate) AND 
            NOT (Task^.StartStatus = DoneS) AND
                (Task^.Fingerprint * FingerprintSet <> {}) AND
            NOT (TaskUsesNoEmployableResources(Task));
        ReleaseUnchangedObject (TaskHandle);    (*<KILL  Task := NIL; KILL>*)

        (* Check for overbooking only on tasks with some duration and
           some employable resources, and that aren't Done: *)
        ArrayAllocated := FALSE; (* test whether to do it right now: *)

        IF (WorthChecking) THEN	    (* Might be overbooked. *)

            IF MakeHeapCopy( AssignmentHandle,LAssignments,Size) THEN
                ResourceCount := NumberOfElements( Size, 
                                                   TSIZE(AnAssignmentRecord));
                ArrayAllocated := TRUE;
            ELSE
                SchedulingAbandoned := TRUE;
                RETURN;
            END;


            (* Check each assignment:   This is safe to loop 0 to
               ResourceCount-1, since by checking above that the task
               has some levellable resources, we have checked that
               ResourceCount is > 0.  *)

            FOR i := 0 TO (ResourceCount - 1) DO
                EXCL(LAssignments^[i].Attributes, Overloaded);
                ResourceWeUse := LAssignments^[i].Resource;
                    (* check the assignment only if the resource
                       is employable and is somewhere maybe overbooked. *)
                j := ResourceWeUse^.ID MOD OverloadSetSize;
                IF (ResourceWeUse^.Type = Employable) AND
                   (j IN OverloadSet) THEN                

                    VAssignments  := LAssignments^[i].VaryingAssignment;
                    (* loop through varying assignment list, starting
                       at end of spending date: *)
                    LocateDateInVaryingAssgnList
                         (VAssignments, 
                          LAssignments^[i].EndOfSpentDate, n);

                    (*<TRACE
                    SetString(TraceS,"  Resource =  ");
                    ConcatLS(TraceS,ResourceWeUse^.Name);
                    ConcatS(TraceS,", starting after spent date = ");
                    TimeUtoS(LAssignments^[i].EndOfSpentDate,TraceS2);
                    ConcatLS(TraceS,TraceS2);
                    PrintString(TraceS);
                    IF (n <= 0) THEN
                        SetString(TraceS, " no entries on or before this date");
                        PrintString(TraceS);
                    END;
                    TRACE>*)

                    IF (n=0) THEN   (* If the end of spent date was before the *)
                        n := 1;     (* start of the list, start search with first *)
                    END;            (* entry in list. *)

                    AsstOverload := FALSE;
                    LevellableResource := ResourceWeUse^.LevelThisResource;
                    CellHandleToStartAt := ResourceWeUse^.ResidueAvailProfile;

                        (* loop thru varying assignment list *)
                    REPEAT
                        GotAnEntry := GetVaryingAssgnListEntry
                                           (VAssignments, n,
                                            AsstStart, AsstEnd, AsstRate);
                        IF (GotAnEntry) AND (AsstRate > Zero) THEN
                            (* Check for overbooking only if the resource
                               is in use during this interval.
                               The procedure below sets
                               sets AsstOverload to TRUE if either 
                               there is any vacation time during the 
                               interval, or the residue availability 
                               is < 0 at any time during the interval;
                               vacation-type overload is checked only 
                               if HonorDaysOff is TRUE, and 
                               residue-availability-type overload is checked
                               only if the resource is levellable *)
                            CheckForOverload(CellHandleToStartAt,
                                             AsstStart, AsstEnd,
                                             NextCellHandleToStartAt,
                                             LevellableResource,
                                             AsstOverload);
                            IF AsstOverload THEN    
                                TaskOverload := TRUE;
                                    (* set overload flag in assignment record: *)
                                INCL(LAssignments^[i].Attributes, Overloaded);
                            ELSE
                                (* otherwise go on to the next interval *)
                                CellHandleToStartAt := NextCellHandleToStartAt;
                            END; (* assignment overload found *)
                        END; (* rate > 0 *)
                        INC(n);
                    UNTIL (NOT GotAnEntry) OR (AsstOverload);
                        (* loop thru varying assignment list *)


                END; (* employable resource *)
            END; (* loop through resources *)
        END; (* task had some duration and some employable resources 
                 and was not type Done *)


        IF (TaskOverload) THEN
                (* set overload flag in task record:*)
            IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
            INCL (Task^.TaskStatusSet, ResourceOverload);
            ReleaseObject(TaskHandle);     (*<KILL*) Task := NIL; (*KILL>*)
        END;

            (* we're done with this task - now clean up *)
        IF (ArrayAllocated) THEN
            IF NOT SaveHeapCopy( AssignmentHandle,LAssignments,Size) THEN
                FatalError();
            END;
        END;

        (* go on to the next task: *)
        DEC(ToGo);
        IF ((ToGo MOD HowOften) = 0) THEN
            MaybeCountDown(ModuleNumber+5,ToGo); (* 'Checking resource levels, ' *)
        END;
        TaskHandle := NextHandle;
    END;  (* loop thru all tasks *)


END NoteResourceOverloads;

       









PROCEDURE MoveStatus( TaskNode, DopplegangerNode : ATreeNode;
                      LeastSlack : LONGINT );
VAR
    Task, DopplegangerTask : ATaskPtr;
    StatusUnion : ATaskStatusSet;
    TotalSlack  : LONGINT;
BEGIN
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    DopplegangerTask := DopplegangerNode^.Methods^.LockFlexStorDataObject(DopplegangerNode);

        (* Merge the two status sets so that any contition applying to
           either of them applies to the real task.  Most importantly,
           we want the task to be marked critical if the start or end
           milestone is.  Loop is useful, too.

           However, we also need to keep an indication of whether the it
           was the start or the end that was critical.  This is especially
           important to the PERT view.   See NetPhantoms.

         *)

    WITH Task^ DO
            (* Once a summary task is started, its start is not considered
               "critical" making it earlier is past hope.  The value of the
               "critical path" is to point out those tasks which shortening
               would help the end date of the project. *)
        IF (StartStatus <> FutureS) THEN
            EXCL(TaskStatusSet,Critical);
            EXCL(TaskStatusSet,CriticalStart);
        END;
        EXCL(TaskStatusSet,CriticalEnd);
        IF (Critical IN TaskStatusSet) THEN
            INCL(TaskStatusSet,CriticalStart);
        END;
    END;

    WITH DopplegangerTask^ DO
        WITH Plan.Dates DO
            TotalSlack := VAL(LONGINT,LateTotalEnd) - VAL(LONGINT,EarlyEnd);
        END;
            (* Done tasks are never considered "critical" because shortening
               them is past hope.  The value of the "critical path" is to 
               point out those tasks which shortening would help the end
               date of the project. *)
        IF (StartStatus <> DoneS) AND
           (ForceCritical IN TaskFlags) OR (TotalSlack <= LeastSlack) THEN
            INCL(Task^.TaskStatusSet,CriticalEnd);
            INCL(Task^.TaskStatusSet,Critical);
        END;
    END;


        (* Some status flags need to be copied from the end milestone to
           the start so that if they are on in either, they are on. *)

    StatusUnion := DopplegangerTask^.TaskStatusSet * 
                   ATaskStatusSet{Loop,PartialJoinPrior,PartialJoinAfter};
    Task^.TaskStatusSet := Task^.TaskStatusSet + StatusUnion;

        (* Unlock the tasks. *)

    DopplegangerNode^.Methods^.UnlockUnchangedDataObject(DopplegangerNode);
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
END MoveStatus;




    (* TransferPhantomData --

       Transfer information from the phantom end node (doppleganger task)
       to the primary node.

       Context must be a pointer to a LONGINT containing the minimum total 
       slack over all tasks.

    *)


PROCEDURE TransferPhantomData( VAR TaskNode : ATreeNode;           (* Created 9/13/89 AJL *)
                                Context  : ADDRESS  );
VAR
    Child : ATreeNode;
    DopplegangerNode : ATreeNode;
    DopplegangerTask : ATaskPtr;
    AllIsInOrder : BOOLEAN;
    LeastSlack   : POINTER TO LONGINT;
BEGIN
    LeastSlack := Context;    

    Child := TaskNode^.Methods^.FirstChild(TaskNode);
    IF (Child <> NIL) THEN  (* A Summary Task *)

            (* This ABSOLUTELY REQUIRES that the doppleganger was
               placed into the list immediately following the real
               task. *)

        DopplegangerNode := TaskNode^.Methods^.GetNext(TaskNode);


        IF (DopplegangerNode <> NIL) THEN
            DopplegangerTask := DopplegangerNode^.Methods^.LockFlexStorDataObject(DopplegangerNode);
            AllIsInOrder := (PhantomFlag IN DopplegangerTask^.TempTaskFlags);
            DopplegangerNode^.Methods^.UnlockUnchangedDataObject(DopplegangerNode);
        ELSE
            AllIsInOrder := FALSE;    (* Missing doppleganger task. *)
        END;



        IF (AllIsInOrder) THEN
                (* Move the antecedant links from the Doppleganger back to
                   the summary task. *)
            MoveStatus(TaskNode,DopplegangerNode,LeastSlack^);
        END;

     END;

END TransferPhantomData;









PROCEDURE LookForBadOnes (  VAR Assignment      : AnAssignmentRecord;
                                Context         : ADDRESS            ) : BOOLEAN;
VAR
    BadFlag     : POINTER TO BOOLEAN;
BEGIN
    BadFlag := Context;
    WITH Assignment DO
        BadFlag^ := (CalcError IN Attributes);
    END;
    RETURN NOT BadFlag^;
END LookForBadOnes;







    (*  TaskMsg -- Display a Message about a task.
                   "msg" is a constant string, not an LString. *)

PROCEDURE TaskMsg(msg:CARDINAL; Task : ATaskPtr);
VAR
    s2:ARRAY [0..81] OF CHAR;
BEGIN
    IF (NOT SpaceReserved) THEN
        GetMessage(msg,s2);
        ConcatLS(s2,Task^.taskname);
        NoteThis(s2);
        SpaceReserved := TRUE;
        Burp;
    END;
END TaskMsg;





PROCEDURE Max( A, B : ADate ) : ADate;
BEGIN
    IF (A > B) THEN RETURN A; ELSE RETURN B; END;
END Max;


PROCEDURE Min( A, B : ADate ) : ADate;
BEGIN
    IF (A > B) THEN RETURN B; ELSE RETURN A; END;
END Min;




    (* ComputeThisTaskCost --

       Examine each of the assignments of the task.  For each assignment,
       compute the dollar cost of that assignment, taking into account
       varying assignments and varying cost rates.
       Compute task totals.

       For varying costs, compute the spent and to go quantities and 
       update the assignment records.

    *)


PROCEDURE ComputeThisTaskCost(     TaskNode           : ATreeNode;
                               VAR Task               : ATask;     (* Use Read-Only. *)
                                   AssignmentsHandle  : AnExtHandle;
                                   TaskStart, TaskEnd : ADate;
                               VAR TotalSpentEffort,
                                   TotalToGoEffort   : REAL;
                               VAR TotalSpentCost,
                                   TotalToGoCost     : REAL);
VAR
    SpentEffort, ToGoEffort: REAL;          (* Hours *)
    SpentCost, ToGoCost: REAL;              (* Money, local currency *)
    TotalQuantity      : REAL;
    StartOfSpentDate,
    StartOfToGoDate    : ADate;
    iStart, iEnd       : ADate;
    Assignments        : AnAssignmentArray;
    i, j, Count        : CARDINAL;
    CountOfResources   : CARDINAL;
    Some               : BOOLEAN;
    AssignmentEffortUnchanged : BOOLEAN;
    S                  : ARRAY [0..81] OF CHAR;
BEGIN

    TotalSpentEffort := Zero;
    TotalToGoEffort  := Zero;
    TotalSpentCost   := Zero;
    TotalToGoCost    := Zero;


    (* This process of computing the task cost is tricky because of 
       rounding and truncation problems.  For example, if a user enters a
       task as 100 hours of effort, one resource at 30%, that will take
       333 hours at hourly precision.  Working from the varying assignment
       list would account for only 99.9 hours of effort.  So, which is
       correct?

       We will try to work from the varying assignment list when we suspect
       that splitting has occurred, and use the assignment data entered by
       the user when it has not.

       In any case, there will always be the possibility that of the three
       items effort calculated, effort entered, and effort shown in the 
       varying list, one may not match the other two.

    *)


    Count := LockObjectArray( AssignmentsHandle,
                              Assignments, TSIZE( AnAssignmentRecord ) );

        (* Count how many of the assigned resources are Employable.  We
           will use this to recognize tasks that are Effort-Split, but
           whose effort must all be on a single resource assignment (and
           must therefore equal the task effort, and not reliant on the
           varying assignment lists. *)

    CountOfResources := 0;
    FOR i := 1 TO Count DO
        WITH Assignments^[i-1] DO
            IF (Resource^.Type <> AccountingOnly) THEN
                INC(CountOfResources);
            END;
        END;
    END;



        (* For each assignment, compute the spent and to go effort and
           dollar cost. *)

    FOR i := 1 TO Count DO

        WITH Assignments^[i-1] DO
    
            StartOfSpentDate    := Min(EndOfSpentDate, TaskStart); (* 3-Oct-91 TGS *)
            StartOfToGoDate     := Max(EndOfSpentDate, TaskStart);

            (* For this assignment, see if it is an
               assignment to a cost category or a resource.
               *)

            IF (Resource^.Type = AccountingOnly) THEN


                IF (Resource^.CostStyle = CAmount) THEN
                    SpentCost := ActualQuantity;
                    ToGoCost  := YetToGoQuantity;
                ELSE
                    IF (Resource^.CostStyle = CAmountRateTime) THEN
                        TotalQuantity :=  FLOAT(TaskEnd-TaskStart)
                                              / OneHundredTimesSMUPH
                                              * FLOAT( MaxRatePercent );
                        YetToGoQuantity := TotalQuantity - ActualQuantity;
                            (* Negative time doesn't make sense. *)
                        IF (YetToGoQuantity < Zero) THEN
                            YetToGoQuantity := Zero;
                        END;
                    END;

                    SpentCost := ActualQuantity * 
                                 AverageResourceRate(Resource,
                                                     StartOfSpentDate,
                                                     EndOfSpentDate,
                                                     FALSE (* not Baseline *)
                                                     );
                    ToGoCost  := YetToGoQuantity * 
                                 AverageResourceRate(Resource,
                                                     StartOfToGoDate,
                                                     TaskEnd,
                                                     FALSE (* not Baseline *)
                                                     );
                END;


            ELSIF (Resource^.Type <> AccountingOnly) THEN         (* A levellable resource. *)
                IF (VaryingAssignment <> AnExtHandle(NIL)) THEN


                    (* Compute the spent and togo costs and efforts of the
                       task.  
                       *)


                        (* Compute spent and to-go effort and cost. *)

                    Some := ComputeEffortsAndCostsInPeriod(
                                VaryingAssignment,
                                Resource^.ActualRates,
                                EndOfSpentDate,
                                MinDate, MaxDate,    (* Get total cost. *)
                                TRUE (* WeWantSpent *),
                                SpentEffort,
                                SpentCost );

                    Some := ComputeEffortsAndCostsInPeriod(
                                VaryingAssignment,
                                Resource^.ActualRates,
                                EndOfSpentDate,
                                MinDate, MaxDate,    (* Get total cost. *)
                                FALSE (* not WeWantSpent *),
                                ToGoEffort,
                                ToGoCost );
                    
                ELSE
                    SpentEffort := Zero;
                    SpentCost   := Zero;
                    ToGoEffort  := Zero;
                    ToGoCost    := Zero;
                END;

                    (* Make sure that a task with spent amounts for a
                       variable cost or a resource is not also a milestone. *)

                IF (Resource^.CostStyle = CAmountRateTime) AND
                   (TaskStart >= TaskEnd) AND
                   (ActualQuantity <> Zero) THEN
                    SetString(S,"(");  ConcatLS(S,Resource^.Name);  ConcatS(S,")");
                    IssueWarningWithParms( SpentOnMilestone, ADR(Task), S );
                END;

                    (* Fill in the assignment with the newly computed 
                       to go effort, unless the to go effort was entered
                       by the user.  Do not adjust the spent effort,
                       since that was directly entered by the user. *)

                IF (NOT (ComputeByHours IN Attributes)) THEN
                    YetToGoQuantity  := ToGoEffort;
                END;

                TotalSpentEffort := TotalSpentEffort + ActualQuantity;
                TotalToGoEffort  := TotalToGoEffort  + ToGoEffort;

            END;

            IF (Billable IN Attributes) THEN
                TotalSpentCost   := TotalSpentCost + SpentCost 
                                    + ExtraCosts;
                TotalToGoCost    := TotalToGoCost  + ToGoCost;
            END;
    
        END;
    END;

    ReleaseUnchangedObject( AssignmentsHandle );

END ComputeThisTaskCost;



    (* CheckMovedByLevelling -- Mark the task with a little "r" if
                                levelling put it at a different date
                                than CPM did. 
    *)



PROCEDURE CheckMovedByLevelling( Task : ATaskPtr );
VAR
    CpmStartDate           : ADate;
    Changed                : BOOLEAN;
BEGIN
    WITH Task^ DO
        IF (StartStatus = FutureS) AND 
              (NOT (AlreadyScheduled IN TempTaskFlags)) THEN
            CpmStartDate := BigTimeToCalendarTime(SupposedToStart);
            IF (Plan.Dates.EarlyStart <> CpmStartDate) THEN
                INCL(TaskStatusSet,ResourceConflict); (*delay "r" *)
            END; (* mark task *)
        END;  (* exempt task *)
    END;  (* with task *)

END CheckMovedByLevelling;






PROCEDURE ComputeTaskCost( VAR TaskNode : ATreeNode;
                               Context  : ADDRESS  );
VAR
    Task : ATaskPtr;
    AssignmentHandle : AnExtHandle;
    SpentEffort, ToGoEffort : REAL;
    EffortDifference, LimitOfDifference : REAL;
    SplittingRule : ASplittingRule;
    DurationMethod : ADurationMethod;
    SpentCost, ToGoCost : REAL;
    TaskStart, TaskEnd : ADate;
    LocalTask : ATask;  (* A Local, stack copy of the task. *)
    S : ARRAY [0..25] OF CHAR;
    S2 : ARRAY [0..11] OF CHAR;
BEGIN


        (* If there are no assignments on the task, then we can just go 
           away. *)
    IF (NOT TaskNode^.Methods^.TestAttributeBit(TaskNode,TempFlag1)) THEN
        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);


           (*<TRACE
        SetString(TraceS,"  Reject task, no assignments: ");
        ConcatTaskID(TraceS,Task);
        PrintString(TraceS);
           TRACE>*)
           (* Since there are no assignments, the costs and efforts are
              all zero. *)
        WITH Task^ DO
            IF (rollupstatus = NotRollup) THEN
                CompletedSummary.Amount := Zero;
                CompletedSummary.Time   := Zero;
                ToGoSummary := CompletedSummary;
            END;
        END;
        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
                                      (*<KILL  Task := NIL; KILL>*)
        RETURN;
    END;

    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);


         (* If this task represents another schedule, the linking 
            process will have brought in the costs. *)

    IF (Task^.rollupstatus <> NotRollup) THEN
        TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
                                      (*<KILL  Task := NIL; KILL>*)
        RETURN;
    END;
       


        (* Add to this tasks's expenses any that are listed in
           the assignments for this task.  Some summary tasks
           may have private expenses listed, most detail tasks
           will.   *)
    

       (*<TRACE
    SetString(TraceS,"ComputeTaskCost: ");  ConcatTaskID(TraceS,Task);
    PrintString(TraceS);
       TRACE>*)


       (* If there were errors in scheduling the task, do not recompute
          its effort, which could override important information needed
          for scheduling effort-driven tasks next time.  Instead, leave
          old data in place so that the task for will still have the entered
          efforts to work from. *)

    IF (NeedsRecalculate IN Task^.TaskStatusSet) AND
       (Task^.DurationMethod <> DurationDriven) THEN
           (*<TRACE
        SetString(TraceS,"  Reject task, did not recalc correctly: ");
        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        ConcatTaskID(TraceS,Task);
        TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
        PrintString(TraceS);
           TRACE>*)
        TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
        RETURN;
    END;

        (* Get some local copies of vital stuff so we can unlock the task. *)

    WITH Task^.Plan DO
        AssignmentHandle := Assignments;
        TaskStart        := Dates.EarlyStart;
        TaskEnd          := Dates.EarlyEnd;
    END;
    LocalTask := Task^;

        (* Unlock the task handle because currently (June 1991) there
           is a limit on how many objects can be simultaneously 
           locked. *)

    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
                                      (*<KILL  Task := NIL; KILL>*)

    ComputeThisTaskCost( TaskNode,
                         LocalTask,
                         AssignmentHandle,
                         TaskStart,TaskEnd,
                         SpentEffort, ToGoEffort,
                         SpentCost, ToGoCost );
    
    
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    
    Task^.CompletedSummary.Amount := SpentCost;
    Task^.ToGoSummary.Amount      := ToGoCost;
    
        (* The effort on a duration-driven task can be changed by
           recalc. *)
    
    WITH Task^ DO
        IF (DurationMethod = DurationDriven) THEN
            (* The effort could have changed by splitting during recalc.
               Splitting can occur if the task SplittingRule is Split, but
               also if the Spent and ToGo efforts are segregated. *)
           ToGoSummary.Time      := ToGoEffort;
        ELSIF (DurationMethod = EffortDriven) THEN
            IF (NOT (NeedsRecalculate IN TaskStatusSet)) THEN
                    (* Recompute the duration. *)
                duration := Plan.Dates.EarlyEnd - Plan.Dates.EarlyStart;
                    (* Verify that the effort was fully allocated.   If
                       not, warn the user, showing both the entered and the
                       allocated to go amounts, as parameters 2 and 3 (task
                       name is always parm number one). *)
                EffortDifference := ABS( ToGoSummary.Time - ToGoEffort );
                LimitOfDifference := 1.0 / FSMUPH;   (* Calendar resolution. *)
                   (*<TRACE
                SetString(TraceS,"  Difference is: ");
                FormatAsAmount(EffortDifference,DefaultAmountFormat,
                               TraceS2,HIGH(TraceS2),0,3,FALSE);
                TrimRear(TraceS2);  ConcatLS(TraceS,TraceS2);
                ConcatS(TraceS,", Limit is: ");
                FormatAsAmount(LimitOfDifference,DefaultAmountFormat,
                               TraceS2,HIGH(TraceS2),0,3,FALSE);
                TrimRear(TraceS2);  ConcatLS(TraceS,TraceS2);
                PrintString(TraceS);
                   TRACE>*)
                IF (EffortDifference >= LimitOfDifference) AND
                   ((EffortDifference / ToGoEffort) >= 0.01) THEN
                    SetString(S,"(");
                    FormatAsAmount(ToGoSummary.Time,DefaultAmountFormat,
                                   S2,HIGH(S2),0,3,FALSE);
                    TrimRear(S2);  ConcatLS(S,S2);  ConcatS(S,")(");
                    FormatAsAmount(ToGoEffort,DefaultAmountFormat,
                                   S2,HIGH(S2),0,3,FALSE);
                    TrimRear(S2);  ConcatLS(S,S2);  ConcatS(S,")");
                    IssueWarningWithParms(CantMakeEffortExact, Task, S);
                END;
            END;
        END;
    END;


        (* If levelling was done, check the task to see if it was 
           moved by levelling from its CPM date. *)

    IF (Levelling) THEN
        CheckMovedByLevelling( Task );
    END;
    
    
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
                                      (*<KILL  Task := NIL; KILL>*)
    
          (* On to the next task. *)
     DEC(ToGo);
     IF ((ToGo MOD HowOften) = 0) THEN
         MaybeCountDown(ModuleNumber+20,ToGo);   (* 'Analyzing efforts.' *)
     END;

END ComputeTaskCost;









    (* CleanTheTaskNode -- 

       Context must be a pointer to a LONGINT containing the minimum total 
       slack over all tasks.

    *)


PROCEDURE CleanTheTaskNode( VAR TaskNode : ATreeNode;
                                Context  : ADDRESS  );            (* 04-Jun-87 LAA *)

VAR
    Task, LinkedTask : ATaskPtr;
    LocalEarlyEnd,
    LocalEarlyStart  : ADate;
    BigLateStart     : ABigTime;
    BadOne           : BOOLEAN;

BEGIN


        (* Transfer the dates (and also some status information)
           from the phantom end milestone to the summary start. *)

    TransferPhantomData( TaskNode, Context );


        (* Clean the insides of this task node. *)


    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);


    WITH Task^ DO
        WITH Plan.Dates DO
            LocalEarlyEnd   := Plan.Dates.EarlyEnd;
            LocalEarlyStart := Plan.Dates.EarlyStart;   (* RSC 1/4/89 *)
        END;

            (* Done tasks are never considered "critical" because shortening
               them is past hope.  The value of the "critical path" is to 
               point out those tasks which shortening would help the end
               date of the project. *)

        IF (StartStatus = DoneS) THEN
            EXCL(TaskStatusSet,Critical);
        END;

        IF (rollupstatus >= RollupNotAvailable) THEN
            IssueWarning(LinkFailed,Task);
        END;

        IF (StartStatus = DoneS) AND (LocalEarlyEnd > AsOfDate) THEN
            IssueWarning(DoneInFuture,Task);
        ELSIF (StartStatus <> FutureS) AND (LocalEarlyStart > AsOfDate) THEN
            IssueWarning(StartInFuture,Task);
        END;

          (* Issue disclaimer warning if the task is future but
             has spent effort.   We currently (Sept. 91) allow users
             to enter such tasks, because the user may want to have a
             task bar that shows only the remaining effort, and we
             don't display split task bars, but the results on 
             scheduling of the spent effort are difficult to interpret. *)

        IF (StartStatus = FutureS) AND (CompletedSummary.Time > Zero) THEN
            IssueWarning(FutureTaskWithSpentEffort, Task);
        ELSIF (StartStatus = DoneS) AND (ToGoSummary.Time > Zero) THEN
                (* Much of the scheduling code implicitly depends on the
                   assumption that Done tasks have no remaining effort.  If
                   this is untrue, the edit checks in the program failed to
                   prevent such a task, it we may have computed things 
                   incorrectly, such as calculating slack for a Done task. *)
            IssueWarning(DoneTaskWithToGoEffort, Task);
        END;

        (*-------------------------------removed, obsolete
        IF (NOT (FrozenTask IN TaskFlags) )  THEN   (* Unless frozen . . . *)
                (* See if this task is a fixed-date task that would be forced
                   to start later than its fixed date. *)
            IF (NOT (SummaryFlag IN TempTaskFlags))
               AND
               (NoLaterStart IN TaskFlags)
              THEN
                IF (BigTimeToCalendarTime(UserEnteredStartDate)
                    < Plan.Dates.EarlyStart) THEN
                    TaskMsg(ModuleNumber+1,           (* "PredictLate: " *)
                            Task);
                END;
            END;
        END;
        ---------------------------------------------*)

    END;


        (* Find the latest end date of any task. *)
    IF (LocalEarlyEnd > ScheduleEndDate) THEN
        ScheduleEndDate := LocalEarlyEnd;
    END;
        (* Find the earliest start date of any task.  RSC  1/4/89 *)
    IF (LocalEarlyStart < ScheduleStartDate) THEN
        ScheduleStartDate := LocalEarlyStart;
    END;

            (*  Look for any "effort-driven" assignments, and count up the
                ones that couldn't be calced properly (the efforts were
                too large).             (3/13/89 EGK)
            *)

    BadOne := FALSE;
    ForEachAssignment (Task^.Plan.Assignments, LookForBadOnes, ADR(BadOne));
    IF (BadOne) THEN
        IssueWarning (CrummedAssignment, Task);
        INCL (Task^.TaskStatusSet, NeedsRecalculate);
    END;





    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
                                      (*<KILL  Task := NIL; KILL>*)

          (* On to the next task. *)
     DEC(ToGo);
     IF ((ToGo MOD HowOften) = 0) THEN
         MaybeCountDown(ModuleNumber+16,ToGo);   (* 'Analyzing summary dates.' *)
     END;


END CleanTheTaskNode;







PROCEDURE LastCleanUpPass( LeastSlack : LONGINT );

BEGIN
    ScheduleEndDate := MinDate;
    ScheduleStartDate := MaxDate;
    ToGo := TaskCount;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,
                                    MAX(CARDINAL),CleanTheTaskNode,
                                    ADR(LeastSlack)   );

END LastCleanUpPass;




    (* TidyText -- Take the text containing warning messages and 
                   reformat it to look nicer. *)


PROCEDURE TidyText( VAR Text : AText );
CONST
    HelpKey = 235C;
    NewLine = 374C;
    VidChange = 375C;
VAR
   Line, j : CARDINAL;
   S, Bal  : ARRAY [0..255] OF CHAR;
   S2 : ARRAY [0..21] OF CHAR;
   NewText : AText;
BEGIN
   NewText := CreateText();

       (* Put a paragraph of error log explanations at the beginning of
          the log. *)

   Line    := 3833;               (* Initial paragraph phrase number. *)
   LOOP
       GetMessage(Line, S);
       IF (Line > 3899) OR ((LengthOf(S) > 0) AND (S[1]="-")) THEN
           EXIT;
       END;
       IF AppendLine(S,NewText) THEN; END;
       INC(Line);
   END;

       (* Break each line of error log text as it comes from recalc into
          several lines, formatted for user viewing. *)

   Line := 0;
   WHILE (LineExists(Text,Line)) DO
       CopyLine(Text,Line,S);
           (* If an error number is at the start of the line, separate it. *)
       IF (LengthOf(S) >0) AND (S[1] = "(") THEN
           j := 1;
           ParseBal(S,j,Bal);
           Remove(S,1,j-1);
           IF (Bal[1] = HelpKey) THEN    (* Remove the special letter ù meaning help key. *)
               Remove(Bal,1,1);
               j := 1;
               IF (Bal[1] = "(") THEN j := 2; END;
               GetMessage(ModuleNumber+32,S2);
               Insert(Bal,S2,j);
           END;
           IF AppendLine(Bal,NewText) THEN; END;
       END;

           (* Remove formatting. *)
       j := 1;
       WHILE (j <= LengthOf(S)) DO
           IF (S[j] = NewLine) THEN
               S[j] := " ";
           ELSIF (S[j] = VidChange) THEN
               Remove(S,j,2);
           ELSE
               INC(j);
           END;
       END;

           (* Wrap lines *)
       REPEAT
           j := LengthOf(S);
           IF (j > MaxColumn-4) THEN
               j := MaxColumn-4;
               FindPriorWord(S,j," ");
               DEC(j);
           END;
           SubStr(S,Bal,1,j);
           Remove(S,1,j);
           IF AppendLine(Bal,NewText) THEN; END;
       UNTIL (LengthOf(S) = 0);
           (* Add a blank line. *)
       SetLengthOf(S,0);
       IF AppendLine(S,NewText) THEN; END;
       INC(Line);
   END;
   DiscardText(Text);
   Text := NewText;
END TidyText;





PROCEDURE PostPlan( PlannerContext : APlannerContext;
                    LeastSlack     : LONGINT);
VAR
    Changed : BOOLEAN;
    Title   : ARRAY [0..79] OF CHAR;
    S       : ARRAY [0..255] OF CHAR;
BEGIN
        (* Move the dates of the phantom tasks, setting the
           phantoms to their earliest possible date.   We need
           to do this prior to determining which are critical.
           Set fixed dates.  Note which tasks are critical. *)

    SetDatesAndStatus( LeastSlack );

    IF (SomeLevel0TaskIsSummary) THEN
            (* Expand summary dates. *)
        ExpandSummaryDates();
    END;

        (* Compute the actual costs of each task, taking into account
           the dates that the task is scheduled at.   Do this after the
           summary dates are expanded (so that variable costs for 
           summaries are accurate) and before costs are rolled up. *)
           

    ToGo := TaskCount;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,
                                    MAX(CARDINAL),ComputeTaskCost,
                                    NIL   );

        (* Detect overloads.   Need to do this after
           expanding dates of summary tasks. *)

    NoteResourceOverloads();

    IF (NOT SchedulingAbandoned) AND (SomeLevel0TaskIsSummary) THEN
        DisplayMessage(ModuleNumber+12);    (*   "Rollup." *)
        RollupPlan();                       (* Rollup Planned values. *)
    END;

    IF (BreakRequested()) THEN
        SchedulingAbandoned := TRUE;
    END;

    IF (NOT SchedulingAbandoned) THEN
        LastCleanUpPass( LeastSlack );
            (* If there were problems during recalc, offer to display them. *)
        IF (LineExists(WarningLogText,0)) THEN 
            GetMessage(ModuleNumber+30,Title);    (* Problems during Recalculation *)
            GetMessage(ModuleNumber+31,S);        (* Look at them? *)
            Message(Title);
            IF (ContinuationBox(S,Title,NoHelp)) THEN
                TidyText(WarningLogText);
                EditText(0,GanttWStart,MaxColumn,GanttWEnd,ABoxType{DoubleBox},
                         Title, 0, WarningLogText, Changed );
            END;
        END;
    END;
END PostPlan;




BEGIN
    OneHundredTimesSMUPH := FSMUPH * OneHundred;

    PlannerContext := OverlayContext();
    IF (PlannerContext^.Tag <> ModuleNumber) THEN
        FatalError();
    END;

    FindIndependentDates( PrivateTaskList, LeastSlack );

    PostPlan(PlannerContext, LeastSlack);

    (*<TRACE
    EndTrace();
    TRACE>*)
END TLPlanEx.


Notes on the Dec. 12, 1991 change to effort calculations:




[140] From: Andrew Layman 12/13/91 11:55AM (5465 bytes: 113 ln)
To: Gary McEwan
cc: Kris Hearrell, Larry Azlin, Chris Lofgren, Tom Semple, Ken Cadby,
  Kurt Sussman, Richard Couch, Andrew Layman
Subject: Preliminary code fix to TLPlanEx
------------------------------- Message Contents -------------------------------
      OK.  Here is what recalc now does differently:

      If a task is set to "Delay" or is an Effort driven task with
          only a single resource, then recalc does not affect the
          spent or to go efforts.  It leaves whatever values are in
          the assignment form.  The purpose of this is to avoid any
          intermediate calculation steps that could lead to rounding
          errors, particularly those that derive efforts from the
          varying assignment arrays.

          One of the actions taken by the task form during task edit
          is to compute the to go effort for all tasks.  For tasks in
          the above categories, these efforts are presumed correct. 
          Here is why:

          On a duration-delay task, the duration of the task cannot
          change, and, since the efforts would be uninterrupted, the
          efforts will not change.  The user may have entered the
          effort into the assignment form.  Even if the percentage
          (computed) times the duration would not equal the effort
          exactly, the assignment record contains the effort as
          entered by the user.

          On an effort-delay task, the task form had a total effort
          entered by the user.  This was apportioned by the task form
          edit rules among all the assignments, in amounts
          proportional to the entered rates.  Since the distribution
          is based on the ratio of each entered rate to the total of
          the rates, and this is carried out in 64-bit floating point,
          the rounding errors are negligible.

          On an effort-split task with a single assignment, all the
          effort goes to that assignment, so the effort on the
          assignment cannot change.

          OK, so for these three types of tasks, the effort in the
          assignment form is presumed correct.  We can assure that it
          is if all sources of task input work correctly and work as
          the task form does.  So, this means that spreadsheet edit,
          status update assistant, and all the various forms of import
          need to be verified as passing through a routine that
          assures that the effort in the assignment record is correct.
          I believe that Larry plans to do this.

          Costs are then derived from the effort by multiplying the
          spent effort times the average cost of the resource during
          the spent period, and the same for the to go effort.  This
          is generally accurate, but has a possible source of
          complaints in that an effort-split task might have its
          resource effort countoured, and that contouring might cross
          a resource rate change boundary, and the allocation into the
          two periods might be uneven.  In this case, the unevenness
          would not be accounted-for in the derivation of cost from
          effort.  This is, in my opinion, worth it for the larger
          gain of avoiding obvious rounding errors, especially since
          it does not affect the predictability of the computations.

          So, to recap, for many tasks we can keep the efforts on each
          assignment exactly as they were entered or computed by the
          task form, bypassing steps that can lead to rounding
          problems.

          However, for some split-type tasks we cannot do this.

          Duration-split tasks can have their effort decreased by
          splitting.  For these, we need to determine the actual
          effort spent by looking at the varying assignment array.

          Effort-Split tasks with multiple resources will not change
          their total effort, but may allocate it the the resources
          differently than the task form did.  For this, also, we need
          to compute the effort of each assignment by looking at the
          actual allocation in the varying assignment arrays.

          Open areas:

       1. We might be able to detect split-type tasks that were not,
          in fact, split or contoured, and avoid the varying
          assignment lists, for these.

       2. Spent effort on future tasks--I have not yet figured
          these out, but I suspect that they will be a problem, and
          will mean a further extension to the above rules.

          --Andrew, Dec. 13, 1991, 11:56am


