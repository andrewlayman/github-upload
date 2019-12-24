(*V2=KILL pointers when FlexStor objects are released. *)
(*V8=GELDED*)
(*V9=TRACE*)

(*<KILL*) (*$T+*) (*KILL>*)

MODULE TLPlan;


    (* MODIFICATION HISTORY:

       Removed modification history prior to 1988.
         8-Jan-88 AJL  -Do not schedule ALAP tasks at their late start date
                        unless they are FutureS.
        12-Jan-88 AJL  -Don't signal that resource leveling is needed unless
                        the task is ASAP or ALAP, Future.  In other words,
                        don't try to level tasks whose start dates are already
                        determined.
                       -Fix an errant call to UnlockUnchanged.
                       -Allow the presence of FrozenTask in TaskFlags
                        to force a task to be scheduled at its fixed start date.
                       -Condense all the decisions to fix a task's start date
                        by setting or not the LockFixedDate bit in TaskFlags.
                       -Use Space.Available instead of Storage.Available.
        13-Jan-88 AJL  -No longer flag done tasks as critical.
        20-Jan-88 AJL  -The "Computing" box will now only appear when we
                        have more than 32 tasks.
                       -The summary partial join box now has a title and will
                        allow Help.
        21-Jan-88 AJL  -We only invoke the slack localizer for multiple
                        independent projects if all tasks at the outermost
                        level are summary tasks.  A mixture of summary and
                        detail treats the schedule as one large project.
        25-Jan-88 AJL  -Display progress messages during the free late end
                        computations.
                       -Allow break during free late end pass.
                       -Show a thermometer with the progress message.
        28-Jan-88 AJL     -Display a message before doing sorting or rollup.
                       -Moved CountDown to PTaskList.
                       -Added warnings that the program would run past the
                        ends of the calendar.
                       -No longer limit the start date for antecedant of
                        Summary.
        31-Jan-88 AJL  -Extracted the logic that determines when to put a
                        limit on the start date of a task into a new procedure
                        TaskNeedsLimit, and fixed it.
                       -It was taking too long to check the resource overloads
                        before doing a resource level.  I've removed that so
                        we just level, even if not necessary.  This will ofter
                        prove faster.
         2-Feb-88 AJL  -More fixes to limiting the start dates of tasks.
         8-Feb-88 AJL  -Set ScheduleSaved to FALSE after recalc.
                       -Summary tasks will not cause start date limiting.
                       -Allow Break out of several processes.
         9-Feb-88 AJL  -More work on TaskNeedsLimit.  Now the program will
                        (a) never limit summary tasks.
                        (b) search all antecedants of a task looking for a
                            limit.
                        (c) Limit ALAP tasks similarly to ASAP.
        10-Feb-88 AJL  -Changed the calls to AddEdge so that they don't
                        affect the task's status.
        11-Feb-88 AJL  -Yet more work on getting TaskNeedsLimit correct.
        22-Feb-88 AJL  -Turn off KILL toggle for shipment.
                       -Add an ErrorFlag exit to the subgraph ender building
                        loop.
                       -Change calls to NotYetImplemented to call the
                        ReportError procedure.
                       -Removed import of the Clock module.
        27-Feb-88 LAA  -Parameter to CreateSummaryPhantoms was added.  Changed
                        so this module would compile.  Since the call in TSort
                        uses TRUE, it looks like this call should use FALSE.
         2-2-88   AJL  -In VisitNeighbors (for linking multiple project
                        groups, never mark a summary start milestone as
                        needing a terminator.
         5-Mar-88 LAA  -Changed RollupDates to return a BOOLEAN.
        15-Mar-88 AJL  -Removed import of RollupCosts.
        26-Apr-88 AJL  -Added a resource overload checking pass after resource
                        leveling to detect any remaining overloads that may
                        exist.  These might come about by either resources
                        assigned to summary tasks or failures in the leveling
                        procedures.
                       -Suppress resource overload checking on Done tasks.
        6-Jun-88 AJL   -Add cacheing to CompareTaskByDate.
        3-Aug-88 EGK    Found a bug where NoteResourceOverloads would call
                        OverbookedCheck with an invalid task pointer in its
                        context.  We now keep the task locked down while we
                        call OverbookedCheck.
       17-Aug-88 AJL   -Don't localize slack if only one task at outer level.
                       -I changed the forward pass of the CPM calculations so
                        that tasks which are Started, Done or Locked will be
                        scheduled at their claimed start dates.  This allows a
                        start date to override a dependency for an out-of-sequence
                        start.
                       -Exempt locked tasks from most recalculations.  This will
                        leave their dates and status alone.  (And may save a small
                        amount of time.)
                       -The "Computing" box comes up after 64 tasks, to reflect
                        speed improvements made elsewhere.
                       -Use the new CacheEnable procedure to load up the cache
                        more efficiently.  This makes large schedules run faster
                        by putting the earlier tasks in the cache preferentially,
                        regardless of their order in the task tree.
        1-Sep-88 AJL   -More work on frozen tasks.
        9-Sep-88 AJL   -Suppress all slack on FixedDate tasks in the final
                        cleanup pass.  I have suppressed it here, rather than
                        modifying the recalculation procedures, so that it
                        is guaranteed to have an effect, and so that it can
                        be removed easily.
       20-Oct-88 AJL   -Set BoxShowing only if BoxHandle not NIL.
       21-Dec-88 LAA    Changed imports for Laslo reorganization.
        4-Jan-89 RSC    Added support for "ScheduleStartDate".
       23-Jan-89 RSC    Removed Storage.Mod
       14-Mar-89 EGK    Add check in LastCleanupPass to look for
                        improperly calced assignments.
       24-Apr-89 AJL    Removed unused import of PTaskLis.Visited.
        4-May-89 JES    Changed NoteResourceOverloads to use new resource
                        availability data. (really 19-May-89)
                        Removed use of PCache.
        15-May-89 AJL    Removed Alarms.

        25-May-89 JES   Fixed pointer bug in NoteResourceOverloads (now
                        allocates local assignments array)
         4-Jun-89 EGK   Put in explicit call to SendNotices (BeforeActing),
                        since Permission doesn't do it automatically.
        23-Jun-89 JES   Fixed NoteResourceOverloads so it marks the
                        assignment records and not just the task records
                        as overloaded. (This was an oversight in rewriting
                        the procedure to use the new resource availability
                        data structures.) (Note: this fixes part of bug
                        #599.)
        26-Jun-89 JES   Changed NoteResourceOverloads so that instead of
                        just exempting "Done" tasks, it now only checks
                        for resource overloads on the portion of the
                        task (if any) that's in the future (i.e., AsOfDate
                        and beyond), regardless of the task's start status.
        12-Jul-89 JES   Modified to exit gracefully when flexstore create
                        fails.
        24-Jul-89 JES   InsufficientVirtualMemory now initialized as part
                        of initialization in Pert instead of in Tlrplan.
                        This fixes bug where the variable was not
                        initialized when resource levelling was off.
       *)(*
         2-Aug-89 JES   Changed reference to TLPlanDt to PTasklist, since
                          TLPlanDt stuff was moved to PTasklist.
        09-Aug-89 KKC   Add copyright message.
        Aug-30-89 AJL  -Changed name of "InsufficientVirtualMemory" to
                        "SchedulingAbandoned".
        Aug-31-89 AJL  -Set tasks flags to indicate Critical before we rollup
                        dates so that we can catch whether a summary start
                        milestone is critical.
        Sep-7-89  AJL  -Add a necessary (but omitted) lock before using a
                        task handle added last week.
        Sep-13-89 AJL  -Added new procedures to set the dates of phantom summary
                        enders and move status from them into the summary tasks.
                        This is so that we can set the CriticalEnd and CriticalStart
                        flags to support the traditional network view.
      18-Sep-89  AJL  - Removed the RollupDates procedure.   The Start and End
                        dates of summary tasks are no longer discovered by
                        rolling up the dates of the children.  Instead, the
                        TLPlan.ExpandSummaryDates takes the dates directly from
                        the start and end milestones' dates computed by the
                        scheduling process.  See the MOMTEST schedule for a test.
                       -Made LastCleanupPass run in ParentBeforeChild order.
                       -Combined TransferPhantomData into LastCleanupPass.
      22-Sep-89  AJL   -Done tasks do not have slack.
       9-Nov-89  AJL   -ClearBreak at end of scheduling.
                       -Removed the unused Planned parameter from Rollup().
      28-Nov-89  AJL   -Restore the Planned parameter to Rollup().  It is
                        needed for baseline setting.
      21-Feb-90 KKC    -Remove all unreferenced id from Timeu.
      30-Mar-90 RSC     Made Timeu to Timei/TimeForm conversions.
      02-May-90 KKC     Replace all direct calculations on ADate and Duration
                        by calls to FindDuration, SubtractWorkingTime and
                        AddWorkingTime.
      09-Jul-90        -Removed unused import of PTaskList.TerminalFlag.
      22-Aug-90 AJL    -Moved the setting of varying assignments to the TLCPM
                        module.  Similar work will be needed in TLRPlan.
      27-Aug-90 AJL    -Changed imports from ResStart to ResUtilities.
       9-Sep-90 CL     -Removed the unused NeedLinkedScheduleRollin.
       9-Sep-90 AJL    -Suppress negative slack.
      12-Sep-90 AJL    -Use UserEnteredStartDate rather than FixedStart.
      24-Sep-90 DSL    -Change Rollups.Rollup to Rollups.RollupPlan
      24-Sep-90 AJL    -Moved the setting of the PartialJoin flags to TLCPM.
       6-Oct-90 AJL    -Allow negative slack.
       *)(*
      14-Oct-90 AJl    -Transfer the independent end dates of summary end
                        milestones to the main task record.
                       -Changed the ThruDate in NoteResourceOverloads.
                       -Removed code that suppressed slack (is done in TLCPM).
       1-Nov-90 CL     -Rename LockScheduledDates to FrozenTask.
      16-Nov-90 AJL    -Import NeedLinkedScheduleRollin.
                       -Move the code to call RollupAnySummaries to this module
                        from TLCPM, and we will call it if TLCPM returns after
                        setting a flag.  Rearranges who calls whom to save
                        memory.
      21-Nov-90 AJL    -Rearranged the loop that calls TLCPM so that it exits
                        if the overlay fails.
      10-Dec-90 JES    -Updated NoteResourceOverloads to support vacation
                        time, varying resource assignments, and spent effort.
                        Specifically: (1) a resource booked during vacation
                        time is now considered overbooked; (2) a task is
                        checked for overbooking of a resource only during
                        periods when the varying assignment indicates
                        actual usage of the resource; and (3) as a general-
                        ization of checking for overbookings only on the
                        future portion of the task (where we previously
                        checked for overbookings only after the AsOfDate),
                        we now check for overbookings only after the end of
                        spending date for each assignment. (Furthermore,
                        the procedure is modified to use "end dates" rather
                        than "thru dates" in accordance with the established
                        convention.)
      11-Dec-90 AJL   - Move some things around in NoteResourceOverloads
                        so that we don't try to continue using the task 
                        pointer when it is unlocked.  
                      - Moved the INC(n) increment of the loop index so that
                        it is always used.
                      - Moved a line in checking an assignment overload.
                      - Resources scheduled during vacations are considered
                        overbooked even if HonorVacations is off.
      24-Dec-90 AJL   - Display the Rollup message as a message, not a light.
                      - Remove any delay marks from summary tasks, which do
                        not (12/90) have supposed to start dates.
                      - Allow "Predict Late:" on any task that is to be 
                        late, not just Future ones.  I don't think this will
                        have much effect other than a slight code savings.
       4-Jan-91 AJL   - Don't rollup costs if there are no summary tasks.
       5-Jan-90 AJL   - If there are no summary tasks, don't discard phantoms--
                        none will exist.
      12-Jan-91 AJL   - Added ActivateSummaryTask to schedule the efforts of 
                        summary tasks.
      26-Jan-91 AJL   - Moved a lot of the end of processing to a new overlay,
                        TLPlanEx.
      22-Feb-91 JES   - Removed unused import Honor-Days-Off.
      19-Sep-91 AJL   - If not levelling, turn off TimeConstrained flag.
  *)

FROM Allocs    IMPORT
    (* CONST *)         TskNmLen,
    (* TYPE *)          ATask, ADateBlock, 
                        ATaskPtr, ATaskName, AFixType,
                        AStartStatus, ATaskFlag, ATaskFlagSet, ARollupStatus,
                        ATaskStatusSet, ATaskStatus, ADurationMethod,
                        ATempTaskFlag, ATempTaskFlagSet,
    (* VAR *)           TaskTree,
                        StartStatusName,
    (* PROC *)          CheckTaskValid,
                        CreateTask, DelTask;


FROM AsOf      IMPORT
    (* VAR  *)          AsOfDate,
    (* PROC *)          SetAsOfDate;

FROM ChartControl IMPORT
    (* TYPE *)          AChartState,
    (* VAR *)           RecomputeLight,
    (* PROC *)          SetState;


FROM Dialog    IMPORT   Message, Error, FatalError, Burp,
                        ReleaseBox, ABoxHandle, WarningBox,
                        ADialogOption;

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

FROM Kbio      IMPORT   PutString, BreakRequested,  ClearBreak,
                        avidmode, maxrow, maxcol;

FROM Layout    IMPORT   GanttWStart;

FROM Lights    IMPORT   DisplayLight;

FROM LStrings  IMPORT   SetString, ConcatS, ConcatLS, CtoS, Compare,
                        SubStr, Fill, TrimFront, Copy, Procustes;

FROM MsgFile   IMPORT   GetMessage, ConcatMessage, DisplayMessage;

FROM Notices   IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          Permission, SendNotices;

FROM Overlays  IMPORT
    (* PROC *)          OverlayContext, CallOverlayWithContext;

FROM Phantoms  IMPORT
    (* CONST*)          SummaryFlag, PhantomFlag,
    (* PROC *)          Scan1, CreateSummaryPhantoms, DiscardSummaryPhantoms;

FROM Planner   IMPORT
    (* TYPE *)          APlannerContext, AWhenToCalc, ACalcComponent,
    (* VAR *)           Levelling, CalculationState, ScheduleComputedOk,
                        TimeConstrained,
                        ScheduleStartDate, ScheduleEndDate;

FROM PTaskList    IMPORT
    (* VAR  *)          PrivateTaskList, TaskCount,
                        BoxHandle, BoxShowing, SpaceReserved, 
                        NeedLinkedScheduleRollin,
                        SomeLevel0TaskIsSummary,
    (* PROC *)          ListInit, AddBefore, DeList,
                        MoveList,
                        CountDown;


FROM ResConstants  IMPORT
    (* CONST *)         LongZero,
    (* VAR *)           SchedulingAbandoned;

FROM ResUtilities IMPORT
    (* PROC *)          LatestAntecedantEndDate, EarliestDescendantStartDate,
                        TaskUsesNoEmployableResources;

FROM ResWarnings  IMPORT
    (* TYPE *)          AWarning,
    (* VAR *)           WarningLogText,
    (* PROC *)          IssueWarning, SendErrorMsg;

FROM Rugs      IMPORT
    (* TYPE *)          ARug,
    (* PROC *)          GetRug, PutRug;

FROM Schedule  IMPORT
    (* VAR *)           ScheduleSaved;

FROM Space     IMPORT   Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM          IMPORT
     (* TYPES *)        ADR, ADDRESS, SIZE, TSIZE;

FROM Text      IMPORT
    (* TYPE *)          AText,
    (* PROC *)          CreateText, DiscardText;

FROM Timei          IMPORT
    (* CONST*)          NoDuration, MaxDate, MinDate, OneUnitOfDuration,
    (* TYPE *)          ADate;

FROM Transfer    IMPORT
    (* PROC *)          RollupAnySummaries;

FROM TreeObjects IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder,
    (* PROC *)          ValidateTree, ValidateTreeNode;


(*<TRACE
FROM Codes  IMPORT    ACode, ASetOfCodes;
FROM Dialog IMPORT NotYetImplemented, MessageBox;
FROM Kbio   IMPORT KeyPress, GetAnyCode;
FROM FlexDisp IMPORT HandleToString;
FROM Tracer   IMPORT EndTrace;
TRACE>*)


CONST
    HowOften = 32;              (* Interval for progress reports. *)
    HowOften2 = 8;              (* A shorter interval *)
    BoxShowsUpAt = 64;          (* Tasks before "Computing" box appears. *)
    MAXCARDINAL = 0FFFFH;
    Tolerance = 0.0000000001;   (* Real number tolerance. *)
    Zero      = 0.0;
    OneHundred = 100.0;
    ModuleNumber = 3800;        (* For GetMessage, shared with TLPlanEx *)


VAR
    ToGo : CARDINAL;
    PlannerContext          : APlannerContext;





     (*********************************************************)
     (*      Useful procedures.                               *)
     (*********************************************************)

PROCEDURE MaybeCountDown(phrase:CARDINAL; ToGo : CARDINAL);

BEGIN
    IF (TaskCount >= 100) THEN
        CountDown(phrase,TaskCount,ToGo);
    END;
END MaybeCountDown;


    (*$S+*)




PROCEDURE HardCall(What:ARRAY OF CHAR; Context : ADDRESS):BOOLEAN;
VAR
    s   : ARRAY [0..9] OF CHAR;
    dummy : BOOLEAN;
BEGIN
    SetString(s,What);
    RETURN CallOverlayWithContext(s,Context);
END HardCall;



PROCEDURE DoStep( Step : ACalcComponent;
                  DoAllSteps : BOOLEAN )   : BOOLEAN;
BEGIN
    RETURN DoAllSteps OR
           (CalculationState[Step].When = AutoCalc);
END DoStep;



(*------------------------------------------------------------
PROCEDURE FlushOneResource( VAR ResourceNode : ATreeNode;
                               Context      : ADDRESS    );
VAR
    Resource : AResourcePointer;
BEGIN
    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );

    IF (Resource^.Type = Employable) THEN
        DisposeResAvailabilities( Resource^.ResidueAvailProfile );
    END;

END FlushOneResource;




PROCEDURE FlushResourceAvailabilities();
VAR
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    ResourceTree^.Methods^.TraverseTree(ResourceTree,ParentBeforeChild,
                                    9999, FlushOneResource, NIL);
END FlushResourceAvailabilities;
--------------------------------------------------------*)



PROCEDURE ComputeSchedule( Levelling : BOOLEAN;
                           DoAllSteps : BOOLEAN;
                           StartDate:ADate
                           ):BOOLEAN;
VAR
    s : ARRAY [0..41] OF CHAR;
    LocalDateBlock : ADateBlock;
    Rug            : ARug;
    CalcComponent : ACalcComponent;
BEGIN
    WarningLogText := CreateText();

    BoxShowing := FALSE;
    TaskCount  := 0;


        (* We will use our own list of tasks, threaded through the
           Nextlink and Prevlink fields in each task record.  We
           will bypass the tree structure many times. *)

    IF (NOT ListInit(PrivateTaskList)) THEN
        ScheduleComputedOk := FALSE;
        RETURN FALSE;
    END;


    SchedulingAbandoned := FALSE;
    SpaceReserved := FALSE;
    ScheduleComputedOk := TRUE;

       (* Just for safety, make sure that TimeConstrained is set only
          when levelling is to be done. *)
    TimeConstrained := Levelling AND TimeConstrained;


    IF (DoStep(Scheduling,DoAllSteps)) THEN
       (* The order of these tests is important so that we send
          an AfterActing notice iff we sent a BeforeActing notice. *)

        IF (Permission(ScheduleCompute,NIL)) THEN
            SendNotices(ScheduleCompute,BeforeActing,NIL);      (* 6/4/89 EGK *)

                (* Note that all derivative calculations are wrong. *)

                (* The data is about to be recalced, so it is probably invalid. *)
            FOR CalcComponent := MIN(ACalcComponent) TO MAX(ACalcComponent) DO
                WITH CalculationState[CalcComponent] DO
                    DataIsValid := FALSE;
                    Abandoned := FALSE;
                END;
            END;

            ScheduleEndDate := MinDate;
            ScheduleStartDate := MinDate;     (* RSC 1/4/89 *)
            GetMessage(ModuleNumber+11,s);    (*   "Computing" *)
            DisplayLight(RecomputeLight,s,videoreverse);
            IF (GetRug(0,0,maxcol,2,Rug)) THEN   (* Save message line. *)

               (* Compute the CPM schedule.  There is a loop here because
                  of our attempt to avoid having too much code loaded
                  into memory at once.  TLCPM will either do its job, or
                  else it will exit after setting NeedLinkedScheduleRollin.
                  This is not great modularity, it is an awkwardness created
                  to avoid having to make an extra pass over tasks in this
                  module.
               *)

                LOOP
                    ScheduleComputedOk := FALSE;
                    IF NOT HardCall("|TLCPM",PlannerContext) THEN
                        SchedulingAbandoned := TRUE;
                    END;
                    IF (SchedulingAbandoned) THEN
                        EXIT;
                    ELSIF (NeedLinkedScheduleRollin) THEN
                        RollupAnySummaries()
                    ELSE
                        EXIT;
                    END;
                END;      

                IF (ScheduleComputedOk) THEN
                    IF (BreakRequested()) OR (SchedulingAbandoned) THEN
                    ELSE
                        IF (Levelling) THEN
                            IF NOT HardCall("|TLRPLAN",PlannerContext) THEN
                                SchedulingAbandoned := TRUE;
                            END;
                        END;
                    END;

                    IF (BreakRequested()) THEN
                        SchedulingAbandoned := TRUE;
                    END;

                        (* Record whether or not we finished the scheduling calc. *)
                    CalculationState[Scheduling].DataIsValid := NOT SchedulingAbandoned;
                    CalculationState[Scheduling].Abandoned := SchedulingAbandoned;

                        (* Do the schedule wrap-up. *)

                    IF (NOT SchedulingAbandoned) THEN
                        IF NOT HardCall("|TLPLANEX",PlannerContext) THEN
                            SchedulingAbandoned := TRUE;
                        END;
                    END;

                END;

                Fill(s," ",0);              (* Erase and free message line. *)
                Message(s);

                IF (SomeLevel0TaskIsSummary) THEN
                    DiscardSummaryPhantoms();
                END;

                PutRug(0,0,maxcol,2,Rug);   (* Restore message line. *)
            END;


            SendNotices(ScheduleCompute,AfterActing,NIL);

            IF BoxShowing THEN
                ReleaseBox(BoxHandle);
            END;
        END;
    END;

    DiscardExtObject(PrivateTaskList);

    IF (SchedulingAbandoned) THEN
        ScheduleComputedOk := FALSE;
    END;

    IF ScheduleComputedOk THEN
        ScheduleSaved := FALSE;   (* We've changed it. *)
    END;

    ClearBreak();      (* Clear any pending Break. *)


    DiscardText( WarningLogText );

    RETURN  ScheduleComputedOk;

    (*<GELDED
    RETURN TRUE;
    GELDED>*)

END ComputeSchedule;




BEGIN
    PlannerContext := OverlayContext();
    WITH PlannerContext^ DO
        IF (Tag <> ModuleNumber) THEN
            FatalError();
        END;
        Computed := ComputeSchedule(Levelling,DoAllSteps,StartDate);
        SetState(Scheduled);    (* Triggers subsequent states by unsetting them. *)
    END;

       (*<TRACE
    EndTrace();
       TRACE>*)


END TLPlan.








