(*V2=PRINT WITH debugging printouts. *)
(*V3=KILL pointers when FlexStor objects are released. *)

(*<KILL (*$T+*) KILL>*)



     (*********************************************************)
     (*      Resource Planning.                               *)
     (*********************************************************)

     (* REVISION HISTORY:

        Aug. 10, 1985, AL - Changed the use of WeCanSteal so that if
                            we bump tasks then we recheck for an
                            earliest start date.  This is because
                            certain complicated sequences of task
                            bumping can actually leave an opportunity
                            for a preempting task to start earlier than
                            the current date.  See schedule LASER810 for
                            instance.

        Aug. 18, 1985  AL - Changed FindRoomiestStartDate to compute
                            GapSize up to LatestDateToTry, not
                            EndOfSchedule.  This fixes a problem when
                            a span task occurs near the end of the
                            schedule and the duration was not computed
                            correctly.  See CRITTST1.T@0.
                          - Change FindLate to search for total late
                            start forward from free late start.

        Oct. 5, 1985   AL - Check GapSize of found start date in
                            procedure FindRoomiestStartDate.  Tests
                            SPANTST3.  (Task DESIGN NUMBER).
                          - Partial joins on Span or ALAP tasks could
                            cause incorrect evaluation of latest end
                            dates during the Move phase.  Added code to
                            FindLatestStartDate and FindRoomiestStartDate.
                            See SPANTST4.

        Oct. 6, 1985   AL - ALAP tasks that could occur later were it
                            not for resource conflicts will be so marked
                            in procedure FindLate.
                          - Fixed-Date tasks that are Started or Done
                            will be scheduled at their fixed date
                            regardless of apparent resource conflicts.
                            Such tasks are history, not prediction.

        Nov. 19, 1985  AL - Added extra error detection into FindLate
                            to help track down a problem submitted by
                            Elaine C. Leiter, Syntech Intl., Dallas,
                            TX 75243, 214-340-0379 x 323.

        Feb. 12, 1986  AL - Don't always defer tasks within WeCanSteal
                            when they are bumped.  If there are tasks of
                            lower priority on the ActiveList, we do not
                            defer the start date of the bumped task.  In
                            this way, it will be immediately picked up
                            again as a candidate, and compared against
                            the Active tasks, perhaps itself bumping a
                            lower priority task.

         Mar. 19, 1986 AJL- During FindLate, only mark with "R" ALAP
                            or Span tasks.  This counteracts overactivity
                            of the October 6 change.

         Mar. 20, 1986 AJL- In WeCanCollect, only defer tasks whose
                            contention for resources is total.  In
                            other words, do not defer a task that needs
                            25% of a resource if we need less than
                            75%.  It only makes sense to defer tasks
                            that have no hope of activating.

         Mar. 20, 1986 AJL- Added procedure NoteConflicts in order to
                            change the way that "r" is marked on tasks.
                            Now, we will only mark tasks that (ASAP,Fixed,
                            Span) start later than any antecedant end
                            date, or (ALAP,Span) end sooner than any
                            dependant start date.

          Spike product conversion
             and then . . .

         22 Sep 87 AJL    - Added logic to localize slack within
                            SelfContained tasks.
                          - Change BPreemptA to give precedence to
                            tasks that must start on time.
         30 Oct 87 AJL    - Honor the ZeroIsLowestPriority flag.
         23 Nov 87 AJL    - Use LevelThisResource.
          2 Dec 87 AJL    - Fixed to use Phantoms module.
          5 Dec 87 AJL    - Don't slide terminal nodes to the end.
                            This involves not moving ALAP tasks later
                            when they are Terminal, and topological
                            sorting the list before calling FindLate.
         14 Dec 87 AJL    - Tasks are now in FlexStor.
          8 Jan 88 AJL    - Only treat ALAP tasks as ALAP when they are
                            FutureS.
                          - Don't move ASAP or ALAP tasks during fine-tuning
                            unless they are marked FutureS.
                          - Change some Release (and Unlock) calls to the
                            ReleaseUnchanged variety.  This allows the
                            FlexStor routines greater speed by not marking
                            buffers as dirty when they were accessed only to
                            read, not modify, data.
         13 Jan 88 AJL    - Use LockFixedDate bit in TaskFlags to determine
                            that the task's start date is set.  This bit
                            is set if the task is a FixedDate, is Started or
                            Done, or if FrozenTask is set.
                          - FrozenTask will freeze a task's dates.
         19 Jan 88 AJL    - Corrected a locking problem when PRINT selected.
         28 Jan 88 AJL    - Use PtaskList.CountDown.
         29 Jan 88 AJL    - Use IssueWarning when running past end of calendar.
                          - Fixed two errors with resource over-limit checking:
                            a.  We had forgotten to unlock the task when over-limit.
                            b.  We now call TaskResourceAmount, which can handle
                                the same resource having multiple assignments to
                                the task.
       10-Feb-88 RSC      - Removed references of RtoS (replaced by FormatAsAmount).
       26-Apr-88 AJL      - Evidently the preceding change was never tested by
                            actually running the program.  I have now changed the
                            "DesiredSize" parameter from "HIGH(s)" to "12" so
                            that we don't get a string that is so large that it
                            blows up the next user.
                          - Changed BPreemptA to call MustStartOnTime so that we
                            get consistent preemption of tasks.  This solves a
                            problem in which Fixed date tasks would not preempt ASAP
                            tasks with higher priorities.
        6-Jun-88 AJL      - Modified TopologicalCompare to new definition of
                            ATaskCompareProc.
       18-Aug-88 AJL      - Main loop will now schedule any Started, Done, or frozen
                            task at the fixed start date.
                          - For speed, the free and total late end dates are
                            not recalculated for frozen tasks.
        9-Sep-88 AJL      - Added a PrintOn BOOLEAN to the tracing process so
                            that we can selectively trace certain parts of the
                            leveling process.
       21-Dec-88 LAA     - Changed imports for Lazlo reorganization.
        2-Jan-89 RSC     - Removed reference to Compare().  Deleted anchient comments.

       14-Mar-98 JES     - Completely remodelled this overlay to
                           use the new resource-availability-table scheme
                           for finding start dates, instead of searching through
                           task lists. Now, instead of looking through all
                           scheduled/active tasks to see what resources are in
                           use, we query "resource availability cells"
                           (See ResStartDates and ResAvailableResources for
                           more detailed comments.)

                           Also, made it more modular by creating the
                           new modules

               ResAvailableResources - maintain and query resource
                                        availability data
               ResStartDates         - find earliest and latest start
                                        and end dates (and related
                                        information) for tasks
               ResActivate           - activate candidates by getting
                                        their start dates and
                                        scheduling them
               ResScheduleTasks      - schedule and free the resources
                                        used by a task starting at a
                                        given date
               ResBumpTasks          - determine priorities and bump
                                        tasks to steal resources for
                                        a higher priority task
               ResMoveTasks          - move ALAP tasks farther out
                                        if possible
               ResLateDates          - find free and total late start and
                                        late end dates
               ResConstants          - constants used throughout

               ResWarnings           - warnings and error messages

               ResTrace              - debugging procedures


        20-Mar-89 JES for AJL - Put topological order into TopoOrder.
        21-Apr-89 JES for AJL - Added time constrained leveling.

           May-89 JES         - Removed use of PCache, since with
                                use of the new resource availability
                                data (instead of searching through
                                task lists), it just creates overhead.

        18-May-89 JES - fixed bug in topological compare (you can't
                        use early start and then TopoOrder just for a
                        tiebreaker, since early start order does not
                        coincide with Topo Order if there is a partial
                        dependency with a negative offset.)
        21-Jun-89 JES - Exempted started and done tasks from the check
                        that the resource assignment does not exceed
                        the "maximum for levelling" (in procedure
                        "NumberToSchedule").
        12-Jul-89 JES - Modified to exit gracefully when flexstore crate
                        fails.

        24-Jul-89 JES - Move initialization of InsufficientVirtualMemory
                        from here to Tlplan. Fixes bug where this is
                        uninitialized if levelling is not on.
        09-Aug-89 KKC - Add copyright message.
        30-Aug-89 AJL - Removed unused import of DontBump.
                      - Corrected some errors in the PRINT version code.
        Aug-30-89 AJL - Changed name of "InsufficientVirtualMemory" to
                        "SchedulingAbandoned".
        Sep-13-89 JES for AJL -
                        Moved the insertion sort here from TLPlan.
        Sep-15-89 JES - Added a call to "AdjustPhantoms", to solve the
                        problem where little "r"'s weren't showing up
                        on tasks preceded by a phantom summary (because
                        the phantom was incorrectly set at its latest
                        possible date). This call comes just after
                        MoveTasks and right before FindLate.
        Sep-19-89 LAA   In PlanResources, the call to AdjustPhantoms was
                        missing the ToGo parameter.  Since there is a ToGo
                        variable available within this procedure, I passed it
                        down.  Janet, please check that this is correct.
        Sep-22-89 AJL   InsertionSortTasks and ListInit procedures now return
                        BOOLEANS to indicate success or failure.
        Nov-9-89  AJL   If Break is hit, we set ScheduleComputedOK to
                        false and do not clear Break.
        Dec-28-89 JES   "ResourceConflict" marker (little "r") was changed
                        to be computed by comparing the CPM start date
                        with the date determined by levelling. Thus, now
                        all tasks that are delayed by levelling (whether
                        they are delayed "because" of a resource conflict
                        or "because" of precedence relations) are given
                        the little "r". This was by overwhelming demand
                        from tech support and users; users could not
                        understand the previous meaning of the little "r",
                        and tech support could not explain it to them
                        satisfactorily. Previously, tasks were given the
                        marker only if their date determined by levelling
                        was greater than their latest antecedant's end
                        date.
        Feb-21-90 KKC   Remove unreferenced identifers from timeu.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        02-May-90 KKC   Replace all direct calculations on ADate and Duration
                        by calls to FindDuration, SubtractWorkingTime and
                        AddWorkingTime.
        27-Jun-90 AJL   Rely on our caller to initialize and flush the
                        resource availabilities.
        08-Aug-90 JES   Temporarily disabled calls to MoveALAPS and FindLate,
                        in preparation of preliminary testing of multiple
                        calendar.
        13-Aug-90 JES   We now use "FirstActiveListEnd" as a bumping
                        criterion in ActivateCandidates; instead of
                        checking whether the computed date is < "Day",
                        which was the min of firstactivelistend and
                        nextunscheduledliststart, we use only the former
                        (since the latter was irrelevant to whether or
                        not bumping would help).
        14-Aug-90 JES   Added some comments regarding the above change.
        16-Oct-90 AJL   Janet removed the MustStartOnTime procedure from
                        ResBumpT so I have made its function inline here.
         1-Nov-90 CL  - Rename LockScheduledDates to FrozenTask.
        26-Nov-90 AJL - As each task is moved to the ScheduledList, update
                        the Delta field, which accounts for the effect of 
                        partial dependencies.
                      - Removed checking each assignment against the 
                        Resource^.UpperLimit, which is now obsolete.
        21-Dec-90 JES - Procedure FindLate in module ResLateDates
                        was renamed ComputeSlack in module ResSlack,
                        and module ResMoveTasks was renamed ResAlaps;
                        made these changes be reflected here.
        18-Jan-91 JES - Updated procedure NextEnd so it uses actual EarlyEnd
                        field instead of adding duration to EarlyStart.
                        (This is okay since the procedure is called only
                        on the ActiveList, whose tasks all have their
                        EarlyEnd dates set.)

                      - Replaced procedure NextStart with NextLowerBound,
                        since the StartDateLowerBound is what levelling
                        now uses (rather than the CPM early start).
                      - To coincide with the above change, changed the
                        calculation of "Day" accordingly.
                      - Also to coincide with the above change, changed
                        the procedure ReAdjustDependants to update, instead of
                        the EarlyStart, the StartDateLowerBound
                        (and thus the UnscheduledList is now kept
                        in order of StartDateLowerBound instead of in
                        order of EarlyStart). (Also: no longer updates
                        the EarlyEnd field, either; this was not
                        necessary anyway.)
                      - Also to coincide with this change: changed
                        procedure FindCandidates so that it references
                        the StartDateLowerBound field instead of the
                        EarlyStart field as a criterion.

                      - in procedure SchedAct:
                        - removed setting LateTotalEnds to MaxDate, since this
                           was unnecessary (slack calculations do not read
                           the previously computed late total end)
                        - changed duration comparison to EarlyEnd comparison
                        - changed taskname comparison to taskid comparison
                        - changed setting of SchedEnd to use EarlyEnd
                           field of task instead of EarlyStart + duration
        21-Jan-91 JES  - We now keep the UnscheduledList sorted in order of
                        StartDateLowerBound (instead of CPM early start).
        24-Jan-91      - temporarily commented out call to ComputeSlack
                                for testing purposes
        25-Jan-91  JES - ditto for MoveAlaps
        28-Jan-91  JES - put MoveTasks back in - it's ready for testing.
        04-Feb-91  JES - fixed the call to ActivateCandidates. We now
                          pass in "Day" instead of "FirstActiveListEnd',
                          since ActivateCandidates has been optimized
                          so that FirstActiveListEnd does not provide
                          any further optimization. (Specifically:
                          ActivateCandidates now only tries for start dates
                          within ranges it desires, and bumps only
                          if no such feasible date was found. Previously,
                          it tried for ANY feasible date, and if the
                          date found was higher than desired, it then
                          bumped. In that scenario, it made sense to
                          use FirstActiveListEnd in a comparison with
                          the date found, and if the date found was lower,
                          then bumping could not help (since there is in
                          that case no resource conflict between the task
                          in question and any active tasks).
        07-Feb-91    JES  Removed all references to WBS numbers.
        14-Feb-91    AJL  All trace printing is now done through ResTrace.
        15-Feb-91    AJL  Add printing of residue availabilities at end.
                          Compute TaskCount before sorting tasks.
        25-Mar-91    AJL  Removed unused parameters from ComputeSlack.
        27-Mar-91    JES  Changed TimeUtoS's to CtoS's in debugging
                          printouts, to match the rest of levelling code.
         4-Apr-91    JES  In scheduling active tasks, also put any tasks
                          that have the don't bump flag set onto the
                          scheduled list.
         8-Apr-91    JES -FindCandidates now uses procedure
                          MoveTaskToListInPriorityOrder to move tasks
                          to the candidates list.
                          (No change in functionality.)
                         -Fixed ReAdjustDependants so it never sets the
                          lower bound higher than the upper bound.
                         -Fixed PlanResources so that it recalculates Day
                          after calling SchedAct (schedule active tasks),
                          but only if SchedAct actually scheduled some
                          task(s). (To this end, we make SchedAct return
                          a VAR WeScheduledSomething.) 
                          In this recalculation of Day, we
                          allow Day to move backwards (convergence is
                          still guaranteed since something was moved
                          off the active list never to return).
                          
                          The reason for the
                          recalculation is that previously we were missing some
                          unscheduled tasks out of the "next lower bound"
                          calculation of Day, since they hadn't yet had their
                          count2 reduced to zero when Day was calculated.
                         -Made "CalculateNextSignificantDate" into a procedure (previously
                          it was inlined).
         9 - Apr - 91 JES-Fixed PlanResources so the second call to
                          CalculateNextSignificantDate is indeed conditional
                          on SchedAct having activated any tasks.
                         -Moved CompTaskByLowerBound from here into
                          ResUtilities (and fixed it so that it uses
                          sequence # as a tie-breaker instead of taskname).
                         -Fixed ReAdjustDependants so it moves the 
                          dependant task to the correct (lower-bound order)
                          place in the unscheduled list.'
        10 - Apr - 91 JES-Removed second call to CalculateNextSignificantDate,
                          and re-disallowed backward movement of Day
                          (since it was preventing things from moving from
                          the active to the scheduled list). (The real
                          reason we were missing candidates before is that
                          the unscheduled list's order was being corrupted
                          by ReAdjustDependants, and that is now fixed.)
        11 - Apr - 91 JES-Added some print statements. Changed 
                          ReleaseUnchangedObject to ReleaseObject after
                          call to MoveTaskToListInPriorityOrder.
        12 - Apr - 91 JES-Added a "sanity check" to FindCandidates to
                          check that, for each unscheduled-list task
                          checked, the lower bound is <= the upper bound.
                          (Note: this can't just be done once at the beginning
                          of levelling, because the lower bound is updated
                          by levelling!)
        16 - Apr - 91 JES-More print statements.
        18-Apr-91    AJL -Converted FatalError to ErrorPhrase(  ) in some 
                          places.
        19-Apr-91     JES-This is just a note to document the fact that
                          the Task^.count field now holds (and has held for
                          some time) the date at which levelling schedules
                          the future portion of the task. (It is set in
                          ResSched.ActivateTask.)
      Apr. 20, 91  - AJL -Removed the unnecessary ToGo parameter from MoveTasks.
      May  21, 91  - JES -Changed the structure of the main algorithm, so
                          that to assure convergence, instead of arbitrarily
                          moving "Day" back to its previous value if it
                          moved backwards, we do the following: We now
                          iterate over finding candidates and activating
                          candidates, and schedule active tasks only when
                          both of those steps fail. We use the same 
                          computation for Day in finding and activating
                          candidates, but for scheduling active tasks,
                          we use as a limiting date the next active list end.

                          This new method assures that tasks will not be
                          moved to the scheduled list too soon (this was
                          happening because "Day" got moved up too high
                          by its being arbitrarily reset to its previous
                          value, and therefore active tasks were being
                          left in the dust), and that therefore
                          that priorities will be honored. (I.e., a task
                          with lower priority will not be moved to the
                          scheduled list before one of higher priority
                          has a chance to compete with it on the active list.)
        May 22, 91  JES   FindCandidates is now gated by min LB, not
                          min {min LB, min active end}.
        May 25, 91  JES   This is the version where we sweep new candidates
                          into old only after exiting the inner loop.
        May 29, 91 JES: cloned from v3, but changed CandidatesGate to be
                        same as ActivationLimit.
        May 30, 91 JES  - Modified to use "AlreadyScheduled" list.
          (Note: we are calling this version "V5".)
        June 4, 91 JES  - This is the version that uses OldCandidates and
                           NewCandidates, and tries to activate OldCandidates
                           only if the conditions are auspicious for that.
        June 18,91 JES  - We now partition the UnscheduledList into two
                           lists: one has tasks that have count2 = 0 (i.e.,
                           no unscheduled antecedants), called the
                           PreCandidatesList; the new UnscheduledList has
                           the rest. Tasks start off on the UnscheduledList
                           and move to the PreCandidatesList
                           as soon as their count2 field hits zero. This
                           way, the FindCandidates procedure has to check
                           a shorter list (and thus lock and unlock fewer
                           tasks).
        July 8, 91 JES   - Fixed procedure NoteConflicts so it no longer
                            assumes the count field is the cpm start date.
                           Also, we now exempt all AlreadyScheduled and
                            non-future tasks from the check, since levelling
                            will never change the early start on these
                            tasks.
                           Also, we now use the simple rule:
                             If the task is ALAP and starts before its
                             cpm start date, or if it is non-ALAP and
                             starts after its cpm start date, then we
                             mark it as delayed.
    12-Jul-91  AJL  - Moved NoteConflicts to TLPlanEx.
    Mar 31, 92 - AJL - Removed ActiveList parameter to MoveTasks.

*)


MODULE TLRPlan;


FROM Allocs    IMPORT
    (* CONST *)         TskNmLen, 
    (* TYPE *)          ATask, ADateBlock, AnAssignmentSummary,
                        ATaskPtr, ATaskName, AFixType,
                        AStartStatus, ATaskFlag, ATaskFlagSet,
                        ATaskStatusSet, ATaskStatus, ADurationMethod,
                        StartStatusName,
    (* PROC *)          GetCodingField;

FROM AsOf      IMPORT
    (* VAR  *)          AsOfDate,
    (* PROC *)          SetAsOfDate;

FROM Assignments IMPORT
    (* TYPE *)                  AnAssignmentAttribute,
                                AnAssignmentRecord, AnAssignmentArray;

FROM CalShift               IMPORT
    (* VAR  *)                  TimeSheet;

FROM Chart     IMPORT CursorTask;

FROM Dialog    IMPORT WarningBox, Message, Error, FatalError, Burp,
                      ADialogOption, ErrorPhrase, NotYetImplemented;

FROM Duration               IMPORT
    (* PROC  *)                 AddWorkingTime;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr, AnEdge;

FROM FlexStor       IMPORT
    (* TYPE *)     AnExtHandle, AnExtStoragePreference,
    (* PROC *)     DiscardExtObject,
                   ObjectsAreSame,
                   LockObject, LockObjectArray, ReleaseObject,
                   ReleaseUnchangedObject;

FROM FixPhantoms   IMPORT
    (* PROC *)     AdjustPhantoms;

FROM Kbio      IMPORT GetAnyCode,
                      BreakRequested, ClearBreak;
FROM Keys      IMPORT CancelKey, HelpKey;

FROM LStrings  IMPORT Compare, SetString, ConcatLS, ConcatS, SubStr,
                      CtoS, Procustes, Copy, Fill;
FROM MsgFile   IMPORT GetMessage, DisplayMessage, ConcatMessage;
FROM Notices   IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          Permission, SendNotices;


FROM Planner   IMPORT ScheduleComputedOk, TimeConstrained;

FROM PTaskList    IMPORT
    (* CONST *)         Visited, AlreadyScheduled,
    (* VAR  *)          PrivateTaskList,
    (* PROC *)          ListInit, AddBefore, DeList, MoveList,
                        ComputeEdgeDelta,
                        CountDown;

FROM PSortTaskList IMPORT
    (* PROC *)          InsertionSortTasks, InsertLockedTaskInOrder;

FROM ResActivate   IMPORT
    (* PROC *)          ActivateCandidates;

FROM ResConstants IMPORT
    (* CONST *)       ModuleNumber, MAXCARDINAL, Zero,
                      OurCountDown, HowOften2, DontBump,
    (* VAR *)         SchedulingAbandoned;


FROM ResSlack   IMPORT
    (* PROC *)        ComputeSlack;

FROM ResAlaps IMPORT
    (* PROC *)      MoveTasks;

FROM ResUtilities IMPORT
    (* PROC *)      EarliestDescendantStartDate,
                    LatestAntecedantEndDate,
                    MoveTaskToListInPriorityOrder,
                    CompTaskByLowerBound;

FROM ResWarnings    IMPORT
    (* TYPE *)          AWarning,
    (* PROC *)          IssueWarning, SendErrorMsg;


FROM RsrcMod   IMPORT
    (* TYPE *)          AResourcePointer, AResourceType,
    (* VER *)           ResourceTree;

FROM Schedule  IMPORT
    (* VAR *)           ZeroIsLowestPriority;

FROM Space     IMPORT StackSpaceLeft, HeapAvailable, SetHeapLevels;
FROM SYSTEM    IMPORT TSIZE;

FROM Timei     IMPORT
    (* CONST*)          MaxDate, MinDate,
    (* TYPE *)          ADate;

FROM TimeXlate  IMPORT
    (* PROC *)          BigTimeToCalendarTime;

FROM TreeObjects IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder,
    (* PROC *)          ValidateTree, ValidateTreeNode;


    (*  ------------------------ Import if tracing ------------------*)
(*<PRINT
FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat;

FROM ResTrace    IMPORT
                        PrintOn, NoteString, PrintAString, PrintList,
                        ConcatTaskID, PrintResidueAvailability;
FROM Tracer IMPORT PrintString, EndTrace;
FROM Codes IMPORT ACode;
FROM SYSTEM IMPORT ADDRESS;
FROM TimeFormat   IMPORT TimeUtoS;
VAR
    s : ARRAY [0..255] OF CHAR;
    DummyCode: ACode;

PRINT>*)


(* ----------- MoveTasksWithNoAntecedants -------------------------

   Find all tasks with no antecedants and make them the "charter
   members" of the PreCandidatesList, in order of their
   StartDateLowerBounds. 
*)


PROCEDURE MoveTasksWithNoAntecedants (UnscheduledList   : AnExtHandle;
                                      PreCandidatesList : AnExtHandle);

VAR
    Task, OtherTask                                         : ATaskPtr;
    TaskHandle, NextTaskHandle, OtherTaskHandle, TempHandle : AnExtHandle;
BEGIN

    (*<PRINT
    SetString(NoteString,"-------------------- ");
    PrintAString(NoteString);
    SetString(NoteString,"Finding original tasks with no antecedants:");
    PrintAString(NoteString);
    PRINT>*)

    IF LockObject(UnscheduledList,Task)=0 THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(UnscheduledList);     (*<KILL  Task := NIL; KILL>*)

    IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

    WHILE (NOT ObjectsAreSame(TaskHandle,UnscheduledList)) DO

        WITH Task^ DO
            NextTaskHandle := Nextlink;
                (* We only want tasks with no unscheduled antecedants. *)
            IF (count2 = 0) THEN
                (*<PRINT  
                SetString(NoteString,"found ");
                ConcatTaskID(NoteString,Task);
                PrintAString(NoteString);
                PRINT>*)
                    (*  Move the task to the PreCandidatesList, 
                        in order of StartDateLowerBound: *)
                InsertLockedTaskInOrder(PreCandidatesList, 
                                        TaskHandle,
                                        Task, 
                                        CompTaskByLowerBound);

            END;
        END;
        ReleaseObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
        TaskHandle := NextTaskHandle;
        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;
    END; (* end loop *)
    ReleaseObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
END MoveTasksWithNoAntecedants;




    (* NextEnd  -- Search the indicated list.  Find the
                   earliest end date.
    *)

PROCEDURE NextEnd (ListHead : AnExtHandle): ADate;
VAR
    Task : ATaskPtr;
    TaskHandle, NextHandle : AnExtHandle;
    OldEnd, ThisEnd: ADate;
BEGIN
    OldEnd := MaxDate;

    TaskHandle := ListHead;
    IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

    LOOP
        NextHandle := Task^.Nextlink;
        ReleaseUnchangedObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
        TaskHandle := NextHandle;

        IF (ObjectsAreSame(TaskHandle,ListHead)) THEN
    EXIT;
        END;
        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;
        ThisEnd :=Task^.Plan.Dates.EarlyEnd;
        IF (ThisEnd < OldEnd) THEN
            OldEnd := ThisEnd;
        END;
    END;
    RETURN OldEnd;
END NextEnd;



PROCEDURE ListIsEmpty( List : AnExtHandle ) : BOOLEAN;
VAR
    Task : ATaskPtr;
    TempHandle : AnExtHandle;
BEGIN
    IF (LockObject(List,Task)=0) THEN FatalError(); END;
    TempHandle := Task^.Nextlink;
    ReleaseUnchangedObject(List);
    RETURN ObjectsAreSame(List,TempHandle);
END ListIsEmpty;



    (*  ReAdjustDependants -- Adjust dependant tasks because a task
                              has been moved to the ScheduledList.
                              This involves decreasing
                              each dependant's count of unscheduled
                              antecedants, and possibly adjusting its
                              StartDateLowerBound. If the dependant
                              task's count reaches zero, we move it to
                              the PreCandidatesList. *)


PROCEDURE ReAdjustDependants(Task                    : ATaskPtr;
                             EarlyEnd                : ADate;
                             PreCandidatesList       : AnExtHandle;
                             DoWeMoveToPreCandidates : BOOLEAN);
VAR
    Edge                                             : AnEdgePtr;
    DependantTask, OtherTask                         : ATaskPtr;
    OtherTaskHandle, NextHandle, DependantTaskHandle : AnExtHandle;
    MoveIt                                           : BOOLEAN;
    EdgeDate                                         : ADate;
BEGIN
    (*<PRINT
    SetString(NoteString, "ReAdjusting dependants for :");
    ConcatTaskID(NoteString,Task);
    PrintAString(NoteString);
    PRINT>*)

    Edge := Task^.desctasks;
    WHILE (Edge <> NIL) DO
        DependantTaskHandle :=
              AnExtHandle(Edge^.tailtask^.Methods^.GetDataObject
                             (Edge^.tailtask));
        IF LockObject(DependantTaskHandle,DependantTask)=0 THEN FatalError(); END;

            (*  Compute the net effect of the partial join, if any
                effect at all.  Store the net effect into edge^.Delta.
                This must be done AFTER any Span tasks have been
                temporarily turned into milestones (which is done
                in the PrePass procedure). 
                
                Note, however, that because the DependantTask has not yet
                been scheduled, if the dependency is to the end of the 
                dependent task, the EdgeDate and Delta in the Edge may
                not be correct (if the duration of the DependantTask would
                change during scheduling.)  Since the usual effect of 
                a changed duration is a longer one, the usual effect of
                this flaw is to require the task to start later than
                it might have otherwise. *)

            (* only adjust not "AlreadyScheduled" tasks! *)
        IF NOT (AlreadyScheduled IN DependantTask^.TempTaskFlags) THEN
            (*<DEBUG
            IF (DependantTask^.count2 = 0) THEN
                SendErrorMsg("Trying to readjust dep task with count2 = 0 - take a dump.");
            END;
            DEBUG>*)
        
            EdgeDate := ComputeEdgeDelta( Task, DependantTask, Edge );

            WITH DependantTask^ DO
                (*<PRINT
                SetString(NoteString, " dec count2 field for dependant task");
                ConcatTaskID(NoteString, DependantTask);
                PrintAString(NoteString);
                PRINT>*)
                DEC(count2);     (* Decrease count of unscheduled antecedants. *)
                IF (count2 = 0) AND (DoWeMoveToPreCandidates) THEN 
                    MoveIt := TRUE;
                ELSE
                    MoveIt := FALSE;
                END;

                IF (StartDateLowerBound < EdgeDate) THEN
                     (* never let the lower bound exceed the upper bound! *)
                    IF EdgeDate <= StartDateUpperBound THEN
                        StartDateLowerBound := EdgeDate;
                    ELSE
                        StartDateLowerBound := StartDateUpperBound;
                        (*<PRINT
                        SetString(NoteString, " ran into UB - setting LB = UB ");
                        PrintAString(NoteString);
                        PRINT>*)
                    END;
                    OtherTaskHandle := Nextlink;
                END; (* lower bound < EdgeDate *)
            END; (* WITH dependant task *)
        ELSE
            MoveIt := FALSE; (* don't move AlreadyScheduled tasks *)
        END; (* not AlreadyScheduled task *)

        IF (MoveIt) THEN
                (*  move the task into the correct position in the
                       PreCandidatesList: *)
            DeList(DependantTaskHandle);
            InsertLockedTaskInOrder(PreCandidatesList, 
                                    DependantTaskHandle,
                                    DependantTask, 
                                    CompTaskByLowerBound);
        END; (* if moveit *)

        ReleaseObject(DependantTaskHandle);     (*<KILL  DependantTask := NIL; KILL>*)
        Edge := Edge^.headlink;
    END;

END ReAdjustDependants;




    (*  SchedAct  -- Take tasks from the ActiveList if they are no longer
                     active as of Day. Move each
                     freed task to the end of the ScheduledList.  Reduce the
                     count field of each dependent by 1.
                     Keep track of the latest of scheduled end dates in
                     LateDate. 
    *)

PROCEDURE SchedAct (ActiveList        : AnExtHandle;
                    ScheduledList     : AnExtHandle;
                    PreCandidatesList : AnExtHandle;
                    Day               : ADate;
                    TaskCount         : CARDINAL;
                VAR ToGo              : CARDINAL;
                VAR LateDate          : ADate);
VAR
    Task, OtherTask                                         : ATaskPtr;
    TaskHandle, NextTaskHandle, OtherTaskHandle, TempHandle : AnExtHandle;
    TaskEnd                                                : ADate;
BEGIN
    (*<PRINT
    SetString(NoteString,"----------------------------------------- ");
    PrintAString(NoteString);
    SetString(NoteString,"Schedule Active Tasks (SchedAct).  Day is ");
    CtoS(Day,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"----------------------------------------- ");
    PrintAString(NoteString);
    PRINT>*)

    IF (LockObject(ActiveList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(ActiveList);         (*<KILL  Task := NIL; KILL>*)

    WHILE (NOT ObjectsAreSame(TaskHandle,ActiveList)) DO
        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
      WITH Task^ DO
        NextTaskHandle := Task^.Nextlink;
        TaskEnd := Plan.Dates.EarlyEnd;
        IF (TaskEnd <= Day) OR (DontBump IN Task^.TempTaskFlags) THEN  

            (*<PRINT
            SetString(NoteString,"    Schedule ");
            ConcatTaskID(NoteString,Task);
            PrintAString(NoteString);
            PRINT>*)
            IF (TaskEnd > LateDate) THEN
                LateDate := TaskEnd;
            END;

                (*  Since we are going to all this trouble to put the
                    task onto the scheduled list, let's at least keep
                    the scheduled list sorted by scheduled start dates.
                    To reduce our labor, we search the list in reverse
                    order, since we will very likely go near the end.
                *)
            (* NOTE 1/18/91 (JES/AJL): we probably don't need to keep
               the scheduled list sorted any more, since we no longer
               continually search it. TBD (verify this and change 
               below to simply add the task to the end of the list) 
            *)

            IF (LockObject(ScheduledList,OtherTask)=0) THEN FatalError(); END;
            OtherTaskHandle := OtherTask^.Prevlink;
            ReleaseUnchangedObject(ScheduledList);         (*<KILL  OtherTask := NIL; KILL>*)

            LOOP
              IF (LockObject(OtherTaskHandle,OtherTask)=0) THEN FatalError(); END;
              WITH Task^ DO
                IF (ObjectsAreSame(OtherTaskHandle,ScheduledList)) THEN
            EXIT
                ELSIF (OtherTask^.Plan.Dates.EarlyStart > Plan.Dates.EarlyStart) THEN
                    (*  Keep looping. *)
                ELSIF (OtherTask^.Plan.Dates.EarlyStart < Plan.Dates.EarlyStart) THEN
            EXIT;
                ELSIF (OtherTask^.Plan.Dates.EarlyEnd > Plan.Dates.EarlyEnd) THEN
                    (*  Keep looping. *)
                ELSIF (OtherTask^.Plan.Dates.EarlyEnd < Plan.Dates.EarlyEnd) THEN
            EXIT
                ELSIF (OtherTask^.TaskID >= TaskID) THEN
                    (*  Keep looping. *)
                ELSE
            EXIT;
                END;
                TempHandle := OtherTask^.Prevlink;
                ReleaseUnchangedObject(OtherTaskHandle);        (*<KILL OtherTask := NIL; KILL>*)
                OtherTaskHandle := TempHandle;
              END;
            END;

                (* A funny way of doing AddAfter OtherTask. *)
            DeList(TaskHandle);
            AddBefore(OtherTask^.Nextlink,TaskHandle);

                (* Unchanged by us, that is.   Marked dirty by AddBefore. *)
            ReleaseUnchangedObject(OtherTaskHandle);        (*<KILL OtherTask := NIL; KILL>*)

                (* For each dependent task, reduce the count of
                   unscheduled antecedants (i.e., the count2 field)
                   by 1, and update the
                   StartDateLowerBound if necessary. Move any
                   dependant tasks that get their count2 dec'd to
                   zero to the PreCandidatesList.
                *)
            ReAdjustDependants(Task,
                               TaskEnd, 
                               PreCandidatesList,
                               TRUE (*DoWeMoveToPreCandidatesList *));

            IF SchedulingAbandoned THEN
                RETURN;
            END;
            DEC(ToGo);
            IF ( (ToGo MOD HowOften2) = 0 ) THEN
                CountDown(OurCountDown,TaskCount,ToGo);
            END;
        END;
      END;

            (* Unchanged by us, that is.   Marked dirty by AddBefore. *)
      ReleaseUnchangedObject(TaskHandle);        (*<KILL  Task := NIL; KILL>*)
      TaskHandle := NextTaskHandle;
    END;

END SchedAct;



 (*  FindNewCandidates -- Search the PreCandidatesList 
                          for tasks that might
                          be able to start on Day. That is, we look for
                          tasks whose lower bound is <= Day and whose
                          count2 fields are 0.

                          When found, the
                          tasks are moved to the NewCandidatesList.  We
                          assume that the PreCandidatesList 
                          is sorted in increasing order by start date 
                          lower bounds.

                          When we add tasks to the NewCandidatesList, we
                          add them in increasing order of their
                          priority (which may not be the same as
                          start date lower bound ordering but that's
                          okay).

                          *)

PROCEDURE FindNewCandidates (PreCandidatesList    : AnExtHandle;
                             NewCandidatesList    : AnExtHandle;
                             Day                  : ADate;
                         VAR WeFoundNewCandidates : BOOLEAN);
VAR
    Task, OtherTask                                         : ATaskPtr;
    TaskHandle, NextTaskHandle, OtherTaskHandle, TempHandle : AnExtHandle;
BEGIN

    (*<PRINT
    SetString(NoteString,"-------------------- ");
    PrintAString(NoteString);
    SetString(NoteString,"FindCandidates as of ");
    CtoS(Day,s);
    ConcatLS(NoteString,s);
    ConcatS(NoteString, ":");
    PrintAString(NoteString);
    PRINT>*)

    (*  This outer loop searches through the PreCandidatesList 
        looking
        for tasks that may be able to start as of Day (that is, they
        must at least satisfy StartDateLowerBound <= Day). Since the
        NoUnscheduledAnteceddantsList is sorted by 
        StartDateLowerBound, once we find a
        task with StartDateLowerBound > Day we can stop looking. *)

    WeFoundNewCandidates := FALSE;

    IF LockObject(PreCandidatesList,Task)=0 THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(PreCandidatesList);     (*<KILL  Task := NIL; KILL>*)

    IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

    WHILE (NOT ObjectsAreSame(TaskHandle,PreCandidatesList)) AND
          (Task^.StartDateLowerBound <= Day) DO

        WITH Task^ DO
    
            NextTaskHandle := Nextlink;
            (*<PRINT  
            SetString(NoteString,"FindCandidates found ");
            ConcatTaskID(NoteString,Task);
            PrintAString(NoteString);
            PRINT>*)
                (*  Move the task to the CandidatesList, in priority
                    position. *)
            MoveTaskToListInPriorityOrder (Task, TaskHandle, Day, NewCandidatesList);
            WeFoundNewCandidates := TRUE;
        END;
    
        ReleaseObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
        TaskHandle := NextTaskHandle;
        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;
    END; (* end loop *)

    ReleaseObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
END FindNewCandidates;




(* --------- MergeFirstListIntoSecond -------------------------------
  Move all the tasks on the first list into the second list.
*)

PROCEDURE MergeFirstListIntoSecond(SourceList : AnExtHandle;
                                   TargetList : AnExtHandle;
                                   DateForPriorities : ADate);
VAR
    TaskHandle, PrevTaskHandle : AnExtHandle;
    Task                       : ATaskPtr;
BEGIN
    IF SourceList = AnExtHandle(NIL) THEN
        (* nothing to do *)
        (*<PRINT
        SetString(NoteString, "merge lists: source list is empty");
        PrintAString(NoteString);
        PRINT>*)
        RETURN;
    END;    

    IF LockObject(SourceList,Task)=0 THEN FatalError(); END;
    TaskHandle := Task^.Prevlink;
    ReleaseUnchangedObject(SourceList);

    (*<PRINT
    SetString(NoteString, "Merging lists: ");
    PrintAString(NoteString);
    SetString(NoteString, "source list contains:");
    PrintAString(NoteString);
    PrintList(SourceList);
    SetString(NoteString, "target list contains:");
    PrintAString(NoteString);
    PrintList(TargetList);
    PRINT>*)

        (* Assuming that both lists are in priority order, reading
           the source list in reverse should be faster. *)

    WHILE (NOT ObjectsAreSame(TaskHandle,SourceList)) DO
        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;
        PrevTaskHandle := Task^.Prevlink;
        (*<PRINT
        SetString(NoteString, "moving task ");
        ConcatTaskID(NoteString, Task);
        PrintAString(NoteString);
        PRINT>*)
            (* put it on the TargetList: *)
        MoveTaskToListInPriorityOrder (Task, 
                                       TaskHandle, 
                                       DateForPriorities,
                                       TargetList);
        ReleaseObject(TaskHandle);
        TaskHandle := PrevTaskHandle;
    END; 
END MergeFirstListIntoSecond;



     (*  NextLowerBound -- Returns the StartDateLowerBound of the first 
            plausible candidate task on the PreCandidatesList. *)

PROCEDURE NextLowerBound (PreCandidatesList: AnExtHandle): ADate;
VAR
    Task                   : ATaskPtr;
    TaskHandle, NextHandle : AnExtHandle;
    Date                   : ADate;
    (*<PRINT
    SomeTaskChecked        : BOOLEAN;
    PRINT>*)

BEGIN
    (*<PRINT
    SomeTaskChecked := FALSE;
    PRINT>*)

    TaskHandle := PreCandidatesList;
    IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

    LOOP
        NextHandle := Task^.Nextlink;
        ReleaseUnchangedObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
        TaskHandle := NextHandle;

        IF (ObjectsAreSame(TaskHandle,PreCandidatesList)) THEN
            EXIT;
        END;

        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

        IF (Task^.count2 = 0) THEN
            (*<PRINT
            SomeTaskChecked := TRUE;
            PRINT>*)
            Date := Task^.StartDateLowerBound;
            ReleaseUnchangedObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
            RETURN Date;
        END;

    END;
    (*<PRINT
    IF NOT (SomeTaskChecked) THEN
        SetString(NoteString, "NextLowerBound: no unscheduled tasks with count2 = 0");
        PrintAString(NoteString);
    END;
    PRINT>*)

    RETURN MaxDate;
END NextLowerBound;



PROCEDURE TopologicalCompare (a       : ATaskPtr;
                              bHandle : AnExtHandle) : BOOLEAN;
VAR
    b           : ATaskPtr;
    Answer      : BOOLEAN;
BEGIN
    IF (LockObject(bHandle,b) = 0) THEN FatalError(); END;
    Answer := (a^.TopoOrder > b^.TopoOrder);
    ReleaseUnchangedObject(bHandle);
    RETURN Answer;
END TopologicalCompare;





    (* NoteConflicts -- 
         Note which tasks are scheduled at other
         than the dates that would come about by
         consideration of dependencies. Set "r" delay flag.
         We use the simply rule: if the task is ALAP and
         starts earlier than its cpm start date, or if it
         is non-ALAP and starts after its cpm start date,
         then it is marked as delayed by levelling.
         We exempt AlreadyScheduled, Started, and Done
         tasks from the check, since levelling will never
         change the early start on these tasks. (Note that
         we thus do not detect "delay" of the future portions
         of these task types.) *)


(* ------------- GetNumberToSchedule --------------------------------------

   Schedules any "AlreadyScheduled" tasks and determines how many there
   are yet to schedule and the initial schedule end date.
*)

PROCEDURE GetNumberToSchedule(UnscheduledList     : AnExtHandle;
                              AlreadyScheduledList: AnExtHandle;
                              PreCandidatesList   : AnExtHandle;
                          VAR LateDate            : ADate;
                          VAR TaskCount           : CARDINAL;
                          VAR NumAlreadyScheduled : CARDINAL);

VAR
    Task, OtherTask         : ATaskPtr;
    TaskHandle, NextTaskHandle, TempHandle,
     OtherTaskHandle        : AnExtHandle;
    TaskEnd                 : ADate;
BEGIN

    LateDate  := MinDate;
    TaskCount := 0;
    NumAlreadyScheduled := 0;

    IF (LockObject(UnscheduledList, Task) =0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(UnscheduledList);

    WHILE (NOT ObjectsAreSame(TaskHandle, UnscheduledList)) DO
        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
        NextTaskHandle := Task^.Nextlink;

        WITH Task^ DO
                (* here's a sanity check - make sure LowerBound <= UpperBound:*)
            IF (StartDateLowerBound > StartDateUpperBound) THEN
                (*<PRINT
                SetString(NoteString, "LB > UB for task ");
                ConcatTaskID(NoteString, Task);
                PrintAString(NoteString);
                SetString(NoteString, "UB = ");
                CtoS(StartDateUpperBound, s);
                ConcatLS(NoteString, s);
                PrintAString(NoteString);
                SetString(NoteString, "LB = ");
                CtoS(StartDateLowerBound, s);
                ConcatLS(NoteString, s);
                PrintAString(NoteString);
                PRINT>*)
                ErrorPhrase(ModuleNumber+20);
                StartDateLowerBound := StartDateUpperBound;
            END;
            TaskStatusSet := ATaskStatusSet{};   (* We will set our own status codes. Clear from CPM *)
        END;
        (* for test purposes only: *)
        (*<PRINT
        SetString(NoteString, "Before INC, TaskCount = ");
        CtoS(TaskCount, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)
        INC(TaskCount);
        (****************)

        IF (AlreadyScheduled IN Task^.TempTaskFlags) THEN
            (*<PRINT
            SetString(NoteString,"Already scheduled:");
            ConcatTaskID(NoteString,Task);
            PrintAString(NoteString);
            PRINT>*)
                (* move this task to the already scheduled list and readjust 
                   its dependents - first adjust the schedule end date if
                   necessary: *)
            INC(NumAlreadyScheduled);
            TaskEnd := Task^.Plan.Dates.EarlyEnd;
            IF TaskEnd > LateDate THEN
                LateDate := TaskEnd;
            END;

                (* put the task on the already scheduled list, in order: *)

            IF (LockObject(AlreadyScheduledList,OtherTask)=0) THEN FatalError(); END;
            OtherTaskHandle := OtherTask^.Prevlink;
            ReleaseUnchangedObject(AlreadyScheduledList);         (*<KILL  OtherTask := NIL; KILL>*)

            LOOP
              IF (LockObject(OtherTaskHandle,OtherTask)=0) THEN FatalError(); END;
              WITH Task^ DO
                IF (ObjectsAreSame(OtherTaskHandle,AlreadyScheduledList)) THEN
            EXIT
                ELSIF (OtherTask^.Plan.Dates.EarlyStart > Plan.Dates.EarlyStart) THEN
                    (*  Keep looping. *)
                ELSIF (OtherTask^.Plan.Dates.EarlyStart < Plan.Dates.EarlyStart) THEN
            EXIT;
                ELSIF (OtherTask^.Plan.Dates.EarlyEnd > Plan.Dates.EarlyEnd) THEN
                    (*  Keep looping. *)
                ELSIF (OtherTask^.Plan.Dates.EarlyEnd < Plan.Dates.EarlyEnd) THEN
            EXIT
                ELSIF (OtherTask^.TaskID >= TaskID) THEN
                    (*  Keep looping. *)
                ELSE
            EXIT;
                END;
                TempHandle := OtherTask^.Prevlink;
                ReleaseUnchangedObject(OtherTaskHandle);        (*<KILL OtherTask := NIL; KILL>*)
                OtherTaskHandle := TempHandle;
              END;
            END;

                (* A funny way of doing AddAfter OtherTask. *)
            DeList(TaskHandle);
            AddBefore(OtherTask^.Nextlink,TaskHandle);

                (* Unchanged by us, that is.   Marked dirty by AddBefore. *)
            ReleaseUnchangedObject(OtherTaskHandle);        (*<KILL OtherTask := NIL; KILL>*)


                (* For each dependent task, reduce the count of
                   unscheduled antecedants by 1, and update the
                   StartDateLowerBound if necessary. 
                *)
            ReAdjustDependants(Task,
                               TaskEnd,
                               AnExtHandle(NIL), (* not used *)
                               FALSE (* DoWeMoveToPreCandidates *));

            IF SchedulingAbandoned THEN
                RETURN;
            END;
        END; (* if task was already scheduled *)

        ReleaseObject(TaskHandle);
        TaskHandle := NextTaskHandle;
    END; (* end loop *)

    (*<PRINT
    SetString(NoteString, "Total number of tasks: ");
    CtoS(TaskCount, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    SetString(NoteString, "Already scheduled tasks: ");
    CtoS(NumAlreadyScheduled, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    PRINT>*)

END GetNumberToSchedule;



(*<PRINT
PROCEDURE PrintOneResource( ResourcePtr : AResourcePointer);
VAR
    Line : ARRAY [0..255] OF CHAR;
    S2   : ARRAY [0..255] OF CHAR;
BEGIN
    Fill(Line," ",0);
    PrintAString(Line);
    Fill(Line,"-",75);
    PrintAString(Line);

    Copy(ResourcePtr^.Name, Line);
    Fill(S2," ",5);
    ConcatLS(Line,S2);
    ConcatLS(Line, ResourcePtr^.LongName);
    PrintAString(Line);

    Fill(Line,"-",75);
    PrintAString(Line);

    PrintResidueAvailability( ResourcePtr^.ResidueAvailProfile );
END PrintOneResource;

(****************************************************************************
    PrintResourceStatus -
        Print report for each resource.
****************************************************************************)
PROCEDURE PrintResourceStatus( VAR ResourceNode : ATreeNode;
                                   Context      : ADDRESS );
VAR
    ResourcePtr             :   AResourcePointer;
BEGIN
    ResourcePtr :=  ResourceNode^.Methods^.GetDataObject( ResourceNode );
    IF ( ResourcePtr^.Type <> Employable ) THEN
        RETURN;
    END;

    PrintOneResource( ResourcePtr );
END PrintResourceStatus;




(****************************************************************************
    PrintEachResourceStatus -
        Travese all resouce node in resource tree and print its status.
****************************************************************************)
PROCEDURE PrintEachResourceStatus();
BEGIN
    ResourceTree^.Methods^.TraverseTree(ResourceTree, ParentBeforeChild,
                                               9999, PrintResourceStatus,
                                               NIL);
END PrintEachResourceStatus;

PRINT>*)




    (*  PlanResources  -- Schedule tasks taking resource constraints
                          into account.  On entry, we assume that the
                          precedence scheduling has been done, that
                          the tasks are sorted in order by
                          Plan.Dates.EarlyStart,
                          and that the count2 field of each contains the
                          count of antecedants.
                          *)

PROCEDURE PlanResources;
VAR
    AlreadyScheduledList, UnscheduledList  : AnExtHandle;
    PreCandidatesList                      : AnExtHandle;
    NewCandidatesList, OldCandidatesList   : AnExtHandle;
    ActiveList, ScheduledList              : AnExtHandle;
    TaskCount                              : CARDINAL;
    ToGo                                   : CARDINAL;
    NumAlreadyScheduled                    : CARDINAL;
    FirstActiveListEnd, ActivationLimit,
    OldFirstActiveListEnd,
     OldActivationLimit, 
     FirstUnscheduledLowerBound,
     LateDate                              : ADate;
    Copyright                              : ARRAY[0..50] OF CHAR;
    WeFoundNewCandidates, WeActivatedSomething, 
      ActivationLimitIncreased, TryToActivateOldCandidates,
      WeBumpedSomething, 
      OldCandidatesRenewed : BOOLEAN;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    (*<PRINT
    SetString(NoteString, "Planning resources:");
    PrintAString(NoteString);
    PRINT>*)

    ScheduleComputedOk  := FALSE;   (* Until we are done. *)

    IF (NOT StackSpaceLeft(  1500  )) THEN
        IF HeapAvailable() THEN; END;   (* Message. *)
        RETURN;
    END;

        (* Allocate initialized head nodes for the lists we need. *)
    IF ListInit(UnscheduledList)
       AND ListInit(AlreadyScheduledList)
       AND ListInit(PreCandidatesList)
       AND ListInit(ScheduledList)      THEN ELSE RETURN;
    END;

    IF ListInit(OldCandidatesList)
       AND ListInit(NewCandidatesList)
       AND ListInit(ActiveList)     THEN ELSE RETURN;
    END;

        (*  Move all the tasks to the UnscheduledList. *)
    MoveList(UnscheduledList, PrivateTaskList);

        (* Schedule any "AlreadyScheduled" tasks, count how
           many to go, and initialize schedule end date: *)
    GetNumberToSchedule(UnscheduledList,
                        AlreadyScheduledList,
                        PreCandidatesList,
                        LateDate,
                        TaskCount,
                        NumAlreadyScheduled);
    (*<PRINT
    SetString(NoteString, "AlreadyScheduled list now contains:");
    PrintAString(NoteString);
    PrintList(AlreadyScheduledList);
    PRINT>*)

    ToGo := TaskCount - NumAlreadyScheduled; (* num tasks yet to be scheduled *)


    IF (ToGo > 0) THEN
        IF (ToGo > HowOften2) THEN
            CountDown(OurCountDown,TaskCount,ToGo);
        END;
    END;

        (* Put all tasks with no antecedants into the
           PreCandidatesList, in order of their 
           StartDateLowerBounds: *)
    MoveTasksWithNoAntecedants(UnscheduledList, PreCandidatesList);


        (*  Loop until both unscheduledlists and both CandidatesLists
            are empty.  On each loop, try a new date, and schedule as many
            tasks as possible for that date. *)
    OldActivationLimit := MaxDate;
    LOOP
            (* If all lists of unscheduled tasks are empty, then
               we are done. *)
        IF (ListIsEmpty(UnscheduledList)) AND
           (ListIsEmpty(PreCandidatesList)) AND
           (ListIsEmpty(OldCandidatesList)) AND
           (ListIsEmpty(NewCandidatesList)) THEN
            EXIT;
        END;

            (* The Break key will abort scheduling. *)
        IF (BreakRequested()) THEN
            EXIT;
        END;

        (*<PRINT
        SetString(NoteString, "OUTER LOOP: NEW ITERATION");
        PrintAString(NoteString);
        PRINT>*)

            (* We continually FindCandidates and ActivateCandidates until
               no more tasks can be activated, at which point we move the
               minimum number of active tasks to the ScheduledList (which
               will allow more unscheduled tasks to become candidates): *)

        WeActivatedSomething := TRUE;
        WeFoundNewCandidates := TRUE;
        WeBumpedSomething    := FALSE;
        OldCandidatesRenewed := FALSE;

        WHILE (WeActivatedSomething) OR (WeFoundNewCandidates) DO

            (*<PRINT
            SetString(NoteString, "INNER LOOP: NEW ITERATION");
            PrintAString(NoteString);
            PRINT>*)

                (* Recalculate parameters: *)
            FirstUnscheduledLowerBound := 
                NextLowerBound(PreCandidatesList);
            FirstActiveListEnd := NextEnd(ActiveList);
            IF (FirstUnscheduledLowerBound < FirstActiveListEnd) THEN            
                ActivationLimit := FirstUnscheduledLowerBound;
            ELSE
                ActivationLimit := FirstActiveListEnd;
            END;

            (*<PRINT
            SetString(NoteString, "Activation Limit = ");
            CtoS(ActivationLimit, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            PRINT>*)

               (* merge old candidates into new, if appropriate: *)
            IF (NOT OldCandidatesRenewed) AND
               (WeBumpedSomething OR 
                  (ActivationLimit > OldActivationLimit)) THEN
                (*<PRINT
                IF WeBumpedSomething THEN
                    SetString(NoteString, "We bumped.");
                    PrintAString(NoteString);
                END;
                IF ActivationLimit > OldActivationLimit THEN
                    SetString(NoteString, "Activ limit went up from ");
                    CtoS(OldActivationLimit, s);
                    ConcatLS(NoteString, s);
                    ConcatS(NoteString, " to ");
                    CtoS(ActivationLimit, s);
                    ConcatLS(NoteString, s);
                    PrintAString(NoteString);
                END;
                SetString(NoteString, "OLD ---> NEW: ");
                PrintAString(NoteString); 
                PRINT>*)
                MergeFirstListIntoSecond(OldCandidatesList,
                                         NewCandidatesList,
                                         ActivationLimit);
                OldCandidatesRenewed := TRUE;
            END;

            (*<PRINT
            SetString(NoteString, "   FIND CANDIDATES:");
            PrintAString(NoteString);
            PRINT>*)
            FindNewCandidates(PreCandidatesList,     (* in/out *)
                              NewCandidatesList,   (* in/out *)
                              ActivationLimit,
                              WeFoundNewCandidates (* out *));
            (*<PRINT
            IF WeFoundNewCandidates THEN
                SetString(NoteString, "        found candidates.");
                PrintAString(NoteString);
            ELSE
                SetString(NoteString, "        no new candidates.");
                PrintAString(NoteString);
            END;
            PRINT>*)

                (*  Examine candidates, either activating or bypassing. 
                    We try to activate each task as of its lower bound 
                    (or latest antecedant end date), but failing that, 
                    no later than ActivationLimit. *)

            (*<PRINT
            SetString(NoteString, "   ACTIVATE CANDIDATES:");
            PrintAString(NoteString);
            PRINT>*)
            ActivateCandidates (ActiveList, 
                                NewCandidatesList,
                                PreCandidatesList,
                                ActivationLimit,
                                TimeConstrained,
                                WeActivatedSomething,
                                WeBumpedSomething);
            (*<PRINT
            IF WeActivatedSomething THEN
                SetString(NoteString, "        activated some candidates.");
                PrintAString(NoteString);
            ELSE
                SetString(NoteString, "        no candidates activated.");
                PrintAString(NoteString);
            END;
            PRINT>*)

            IF SchedulingAbandoned THEN
                EXIT;
            END;


        END; (* end loop of finding and activating candidates *)

            (* No candidates were found or activated, so we now move
               the fewest possible tasks from the active list to the
               ScheduledList, making their dates permanent; and thus
               allowing more tasks (i.e., their dependents) to become
               candidates in the next iteration. In order to move
               the fewest possible tasks, we move only those with the
               earliest end date: *)

        (*<PRINT
        ConcatS(NoteString, "   SCHEDULE ACTIVE TASKS: min end = ");
        CtoS(FirstActiveListEnd, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)

        SchedAct(ActiveList,
                 ScheduledList,
                 PreCandidatesList,
                 FirstActiveListEnd,
                 TaskCount,
                 ToGo,
                 LateDate);
        IF SchedulingAbandoned THEN
            EXIT;
        END;

            (* make the new candidates be the old ones: *)
        (*<PRINT
        SetString(NoteString, " NEW ---> OLD:");
        PrintAString(NoteString);
        PRINT>*)
        MoveList(OldCandidatesList, NewCandidatesList);

            (* reset OldActivationLimit *)
        OldActivationLimit := ActivationLimit;

    END;  (* main loop *)

        (* Clean up. *)

    IF (NOT BreakRequested()) AND (NOT SchedulingAbandoned) THEN

            (*  Schedule any remaining active tasks.  This finishes 
                the process of computing the early start dates for all
                tasks.  *)

            SchedAct(ActiveList,
                     ScheduledList,
                     PreCandidatesList,
                     MaxDate,
                     TaskCount,
                     ToGo,
                     LateDate);

            (*<PRINT
            SetString(NoteString, "--------------------------------");
            PrintAString(NoteString);
            SetString(NoteString,"ScheduledList now contains ");
            PrintAString(NoteString);
            PrintList(ScheduledList);
            SetString(NoteString, "--------------------------------");
            PrintAString(NoteString);
            SetString(NoteString,"Ready to move tasks.");
            PrintAString(NoteString);
            PRINT>*)

            (*  Try to push all ALAP tasks to even later dates,
                and ASAP tasks to even earlier dates *)
           IF NOT SchedulingAbandoned THEN
               MoveTasks(ScheduledList, 
                         TaskCount,
                         TaskCount - NumAlreadyScheduled);
               (*<PRINT
               SetString(NoteString,"After MoveTasks, ScheduledList contains ");
               PrintAString(NoteString);
               PrintList(ScheduledList);
               PRINT>*)
           END;

           (* Phantom summary tasks were treated as ALAPs in
              levelling. Now go back and push them all back to
              as early in time as possible (i.e., to their
              latest antecedant end dates). *)

             (*<PRINT
             SetString(NoteString, "Adjusting phantom tasks:");
             PrintAString(NoteString);
             PRINT>*)
             AdjustPhantoms(ScheduledList, 
                            TaskCount,
                            TaskCount - NumAlreadyScheduled);
                (*  Move the AlreadyScheduled tasks to the Scheduled list: *)
             MoveList(ScheduledList, AlreadyScheduledList);


            (*  The ScheduledList is now the task list. *)
        MoveList(PrivateTaskList, ScheduledList);
        (*<PRINT
        SetString(NoteString, "Sorting tasks topologically:");
        PrintAString(NoteString);
        PRINT>*)
        IF (NOT InsertionSortTasks(TopologicalCompare)) THEN
            SchedulingAbandoned := TRUE;
        END;
        MoveList(ScheduledList, PrivateTaskList);

        (*<PRINT
        SetString(NoteString,"After topological sort, ScheduledList contains ");
        PrintAString(NoteString);
        PrintList(ScheduledList);
        SetString(NoteString,"Calling ComputeSlack:");
        PrintAString(NoteString);
        PRINT>*)

        IF NOT SchedulingAbandoned THEN
            ComputeSlack(ScheduledList,
                         LateDate,
                         TaskCount);  

            ScheduleComputedOk  := TRUE;
        END;
    END; (* no break requested and not insufficient virtual memory *)

    IF (BreakRequested() OR SchedulingAbandoned) THEN
            (* Break hit, or insufficient virtual memory to continue.
               Just schedule all tasks at whatever date
               the CPM calculations said, or wherever they are.
               The "ScheduleComputedOk" flag will be left FALSE. *)
        MoveList(ScheduledList, ActiveList);
        MoveList(ScheduledList, OldCandidatesList);
        MoveList(ScheduledList, NewCandidatesList);
        MoveList(ScheduledList, UnscheduledList);
        ScheduleComputedOk  := FALSE;

        (*<PRINT
        IF BreakRequested() THEN
        SetString(NoteString,"******** Break hit. ************* ");
        PrintAString(NoteString);
        END;
        PRINT>*)
    END; (* break requested or insufficient virtual memory *)

    (*<PRINT
    SetString(NoteString,"End of Scheduling.");
    PrintAString(NoteString);
    SetString(NoteString,"Scheduled List now contains ");
    PrintAString(NoteString);
    PrintList(ScheduledList);
    PRINT>*)

        (*  The ScheduledList is now the task list. *)
    MoveList(PrivateTaskList, ScheduledList);
        (* Release the flexstor objects we used temporarily as list headers. *)
    (*<PRINT
    SetString(NoteString,"Cleaning up:");
    PrintAString(NoteString);
    SetString(NoteString, "Discarding unscheduledlist:");
    PrintAString(NoteString);
    PRINT>*);

    DiscardExtObject(UnscheduledList);

    (*<PRINT
    SetString(NoteString, "Discarding scheduledlist:");
    PrintAString(NoteString);
    PRINT>*)

    DiscardExtObject(ScheduledList);

    (*<PRINT
    SetString(NoteString, "Discarding candidateslists:");
    PrintAString(NoteString);
    PRINT>*)

    DiscardExtObject(OldCandidatesList);
    DiscardExtObject(NewCandidatesList);

    (*<PRINT
    SetString(NoteString, "Discarding activelist:");
    PrintAString(NoteString);
    SetString(NoteString, "Residue Availabilities:");
    PrintAString(NoteString);
    PrintEachResourceStatus();
    PRINT>*)

    DiscardExtObject(ActiveList);

END PlanResources;


BEGIN
    (*<PRINT
    PrintOn := TRUE;
    NoteString[0] := 0C;
    PRINT>*)

    PlanResources;


    (*<PRINT
    EndTrace();
    PRINT>*)
END TLRPlan.



