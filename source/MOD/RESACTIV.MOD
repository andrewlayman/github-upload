IMPLEMENTATION MODULE ResActivate;

(*V2=PRINT WITH debugging printouts. *)
(*V3=KILL pointers when FlexStor objects are released. *)

     (* Procedures used by resource levelling to activate tasks on the
        candidates list. 
    
        MODIFICATION HISTORY:
        
        May, 89    JES - created.

        July 12, 89 JES - modified to exit gracefully when flexstore create
                          fails.
        30 Aug 89  AJL - When we are not doing time-constrained leveling,
                         don't set the DontBump flag on FixedDate tasks.
                         This allows them to be preempted by tasks with
                         higher priorities.  Fixes bug report #1101.
    Aug-30-89   AJL     -Changed name of "InsufficientVirtualMemory" to
                         "SchedulingAbandoned". 
    Sep 5, 90 JES       -Radically changed the procedures
                         ActivateCandidates and 
                         ActivateTask in
                         support of multiple calendars. Namely, we can
                         no longer assume that all resources work on the
                         task continuously in the interval [StartDate,
                         StartDate + task duration]. Instead we must
                         skip over vacations or not, as appropriate, for
                         each resource; create the appropriate varying
                         assignment structure to indicate the resource
                         usage (for each resource); and update each
                         resource's availability accordingly.

                        -Also: we changed the criterion for bumping
                         from 
                          " (tentative or computed start date) > Day"
                              to                               >= Day"

    Sep 11, 90 - JES - 
                       (1) If a task is started or done, and unspent
                           effort must be contiguous, we now make the
                           future portion of EACH ASSIGNMENT start at its
                           own EndOfSpentDate.
                       (2) ActivateTask was failing to set the task's
                           early end date. It now does that.
    Sep 12, 90 - JES - If a task is Started or Done and the switch
                        KeepEffortContiguous is set, then cpm will now
                        create assignment structures for the whole task
                        (rather than just the spent portion). Thus,
                        when levelling activates such a task, all it
                        has to do is set the DontBump flag and move
                        the task to the active list. (So the change
                        just above this has been undone.)

                       Also: we use the new
                       task fields StartDateLowerBound and StartDateUpperBound
                       in the ActivateCandidates procedure.
    Oct 1, 90 - JES  -Added support for resource-driven split tasks.
                       These tasks can be split around periods of
                       reduced availability (i.e., resource-splitting
                       around other tasks). 
                       NOTE: IT IS EXTREMELY SIMPLE TO MODIFY THIS CODE
                       TO SUPPORT CONTOURING FOR EFFORT-SPLIT TASKS!
                       THIS IS DOCUMENTED WITHIN THE PROCEDURE
                       CreateSubstitutableResourceAssignments.
    Oct 4, 90  - JES - Minor bug fixes.

    Oct 4, 90  - JES - Modified to handle non-levellable resources. These
                       must have assignments created for them even though
                       their resource levels were not a factor in the
                       start-date decision.
    Oct 5, 90  - JES - Modified the procedure ActivateCandidates so that
                       it uses the "EndSearchAt" parameter in calling
                       FindEarliestStartDate. This should optimize
                       the code considerably.
    Oct 12, 90 - JES - AddLowDate is now imported from PTaskList instead
                        of ResBumpTasks.
    Oct 18, 90 - JES - Changed import of "UpdateResourceAvailability" to
                        "RemoveFromResourceAvailability", since the
                        name of that procedure changed.
    30-Oct-90   CL   - Removed "from ResConstants IMPORT MAXDATE".
    Nov  5, 90  JES  - changed names (to correspond to new allocs.def): 
                            UpperBoundStartDate to StartDateUpperBound
                            LowerBoundStartDate to StartDateLowerBound
                            ResourceDriven to EffortDriven
                       Also added support for contouring to procedure
                       "CreateSubstitutableResourceAssignments".
    6-Nov-90    CL   - Rename MakeAssignments to AssignForInterval and
                       MakeAssignments2 to AssignForDuration.
    Nov 12, 90  JES  - Changed all references to "UnspentWorkMustBe
                        Contiguous(Task)" to "AlreadyScheduled IN 
                        TempTaskFlags", since for levelling's
                        purposes these are equivalent (i.e., the
                        task has already been completely scheduled
                        by cpm, for whatever reason).
    Nov 15, 90 JES - Added support for contour tasks to the calls
                       to the BumpTasks procedure.
    
                     Moved the procedures 
                     CreateSubstitutableResourceAssignments and
                     CreateNonSubstitutableResourceAssignments
                     from this module to the ResSched module.
    Nov 29, 90 JES - Added some missing error-handling, mostly in
                     ActivateTask procedure.
                   - Removed unused type "AVaryingAssgnArray".
    Dec 21, 90 JES   Procedure FindEarliestStartDate now returns the
                     task end date, so made calls to this procedure
                     contain that parameter.
    Jan 11, 91 JES - Moved procedure CreateVaryingAssignments from here to
                        ResSched, and added some parameters (see
                        comment this date in ResSched).
    Jan 17, 91 JES - Changed ActivateTask so that it treats summary
                        tasks specially (i.e., no varying assignments
                        created, and set start and end to ScheduleAtDate).
                   - Changed ActivateCandidates to deal with a case
                        not treated before, namely: Day -1 is < upper bound.
                        In this case, we simply bypass the task in this
                        round (eventually "Day" will catch up).
                        Restructured this procedure to be more clear.
    Jan 21, 91 JES  -Redid our assumptions so that we want tasks to be
                        able to start on a date <= Day, not < Day, which
                        is impossible. (In fact, Day is now equal to 
                        the lower bound of EVERY CANDIDATE, and thus
                        a feasible start date, if found, should actually
                        EQUAL Day. 
    Jan 25, 91 JES  - ActivateTask now sets the task's count2 field to
                        the ScheduleAtDate. (Note 3/27/90: this has now
                        been corrected to set the count field. Also
                        the procedure has been moved to ResSched.)
                        Also, fixed calls to
                        FindEarliestStartDate so parameters are in the
                        right order. Also, moved ActivateTask to
                        ResSched module so it can be exported to various
                        other modules.
    Feb  4, 91 JES  - Fixed ActivateCandidates so case 3.1 is the
                        case that "Day < StartSearchAt", not
                        "Day <= StartSearch". (Thus, tasks whose
                        StartSearch = Day are no longer erroneously
                        bypassed.)
    Feb  7, 91 JES  - Removed all references to WBS numbers.
    Feb 14, 91 JES  - Fixed cases 3.3 and 3.4 of ActivateCandidates
                        to handle the levelling within slack case
                        correctly.
    Feb 14, 91 AJL  - Renamed EndOf ActualDate to EndOfSpentDate. 
    Feb 20, 91 JES  - Removed unused import AStartStatus.
    Feb 26, 91 JES  - Fixed ActivateCandidates so that if Day = MaxDate
                        and we still can't find a feasible start date,
                        we pass the task to the new procedure
                        ActivateInfeasibleTask.
    Mar 26, 91 JES  - Changed TimeUtoS's to CtoS's in debugging printouts.
    Mar 27, 91 JES  - Added debugging printouts.
    Apr  3, 91 JES  - Removed parameter DoWeBumpForContourTask from calls
                        to BumpTasks.

    Apr  4, 91 JES  - Restructured case 3 of procedure ActivateCandidates.
                      In case 2 there, force-activate the task at UB if
                      if ScheduleAtDate > UB. Before the
                      cases, activate as infeasible task if lower bound
                      = MaxDate. Moved the setting of the dont bump flag
                      in case 1 to the ActivateTask procedure.
    Apr  8, 91 JES  - In setting of StartSearchAt, made sure we don't
                      overshoot the task's upper bound.
    Apr  9, 91 JES -  Removed unused imports DeList and AddLowDate.
    Apr 10, 91 JES -  After calling BumpTasks, call FindEarliestStartDate
                        again only if bumping succeeded (in the sense of
                        removing all first-order obstacles).
                   -  ActivateCandidates was calling ReleaseUnchangedObject
                        instead of ReleaseObject in two places.
    Apr 11, 91 JES -  Don't try to bump tasks at Day if Day = MaxDate.
    Apr 23, 91 JES -  Use the new procedures TentativelyBumpTasks,
                       FinishBumpingTasks, and UnbumpTasks. Now,
                       instead of calling the old BumpTasks, we call
                       TentativelyBumpTasks. Then, if the task still
                       can't be activated (i.e., a feasible start date
                       still can't be found), we call UnbumpTasks. If
                       one can be found, we instead call FinishBumpingTasks.
    Apr 26, 91 JES -  Use new procedure CheckIfTaskFitsAtDate instead of
                       TaskFitsAtDate, so that we can check task end date
                       constraint in the time-constrained case.
    Apr. 26 91 AJL -  Only Unbump tasks if BumpingSucceeded.
    Apr 26, 91 JEs -  Use the new parameter WeStartedBumping in Tentatively
                        BumpTasks. We only call FinishBumping or UnbumpTasks
                        if WeStartedBumping is true.
    May  6, 91 JES -  In case 3.3 of ActivateCandidates, we want to try again
                       in [SS, UB] if EITHER bumping succeeded OR
                       the new interval is bigger (i.e., UB > Day); otherwise,
                       we may be needlessly force-activating at UB, which 
                       could be a higher date than necessary.
    May 10, 91 JES -  Removed case 2 of ActivateCandidates (did not renumber
                       cases so that change histories and documentation
                       makes sense - can renumber later). This case was
                       levelling within slack, with a Fixed task. We had
                       been force-scheduling the task at max{lower bound,
                       LatestAntecedantEndDate}, and there is really no
                       reason to do this. Fixed tasks are now treated
                       just like ASAP's - the only functional difference
                       is that the user has the ability to give them
                       upper or lower bounds.
    May 20, 91 JES -  Changed last three cases of Activate Candidates
                       so that we first test StartSearch as a start date.
                       If it is not feasible, we then brute-force bump
                       (i.e., tentatively) all "much lower priority"
                       tasks and continue as we would have before (that is,
                       try in either [SS, Day] or [SS, UB], etc). 
                      Also restructured this procedure by breaking it up
                       into smaller pieces and renaming the cases so
                       there are no "holes".
    May 21, 91 JES  - Added VAR parameter WeActivatedSomething to
                        ActivateCandidates.
    May 25, 91 JES  - Added VAR parameter WeBumpedSomething to
                        ActivateCandidates.
    May 31, 91 JEs  - Since Tlrplan now removes AlreadyScheduled tasks
                        onto their own list, ActivateCandidates should
                        not find any, so this case has been removed.
    Jun 18, 91 JES - Changed name of VAR parameter UnscheduledList
                          to PreCandidatesList in ActivateCandidates.
    Jun 25, 91 JES - Added VAR parameter TaskIsInfeasible to calls to
                        FindEarliestStartDate and CheckIfTaskFitsAtDate.
                        If this parameter is
                        returned as TRUE, we know the task can't be
                        feasibly scheduled (this happens ONLY in the
                        case of an effort-split task for which a 
                        tentatively valid start date can be found, but
                        for which not all the work can be scheduled
                        because resources have availability of zero
                        or vacation out until the end of time). If
                        the parameter is returned as FALSE, we could
                        still discover in a later iteration that the
                        task is infeasible.
    Jul 12, 91 JES -  In calls to ActivateInfeasibleTask where
                        we have reached MaxDate and the task can't 
                        be scheduled, (i.e., the resources were
                        overassigned by the user), 
                        or where the TaskIsInfeasible
                        parameter comes back as TRUE from FindEarliest
                        StartDate (i.e., because the task is effort
                        split and not all the required work could be 
                        fit in), we call
                        the procedure with the warning that 
                        the task can't be scheduled because the
                        resources have been overassigned (and not
                        simply that the task can't be scheduled).
    Jul 23, 91 JES -   In procedures AttemptToActivateForLowUpperBound
                        and AttemptToActivateForHighUpperBound,
                        we previously force-scheduled the task if
                        all else failed (last line of the procedure).
                        We now force-schedule only if we are in the
                        time-constrained case; if not, we instead
                        call ActivateInfeasibleTask.
    Sep 10, 91 JES -   In procedures AttemptToActivateForNoUpperBound
                        and AttemptToActivateForHighUpperBound,
                        we were failing to initialize the VAR
                        parameter WeBumped to FALSE. This was fixed.
     *)


FROM Allocs         IMPORT
    (* TYPE *)          ATaskPtr,  ATaskFlag,
                        AFixType, ASplittingRule, ADurationMethod;

FROM AsOf      IMPORT
    (* VAR  *)          AsOfDate;

FROM Assignments    IMPORT
    (* TYPE *)          AnAssignmentArray, AnAssignmentRecord;

FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM FlexStor       IMPORT    
    (* PROC *)          LockObject, ObjectsAreSame, ReleaseUnchangedObject,
                        AnExtHandle, ReleaseObject, LockObjectArray;

FROM Kbio           IMPORT  BreakRequested;
    (* PROC *)


FROM Planner        IMPORT  MoveFutureTasks, ScheduleComputedOk;
    (* VAR *)

FROM PTaskList      IMPORT AlreadyScheduled;
    (* CONST *)


FROM ResCal         IMPORT 
    (* TYPE *)            AnAvailabilityCell, AnAvailabilityCellPointer,
    (* PROC *)            CellContainingDate;

FROM ResBumpTasks      
                   IMPORT
    (* TYPE *)           ABumpeeArray,    
    (* PROC *)           TentativelyBumpTasks, FinishBumpingTasks, 
                           TentativelyBumpAllMuchLowerPriorityTasks, 
                           UnbumpTasks;

FROM ResConstants   IMPORT
     (* CONST *)            DontBump, 
     (* VAR *)              SchedulingAbandoned;

FROM ResScheduleTaskResources
    (* PROC *)      IMPORT ActivateTask, ActivateInfeasibleTask;

FROM ResStartDates  IMPORT 
    (* PROC *)        FindEarliestStartDate, CheckIfTaskFitsAtDate;

FROM ResUtilities   IMPORT
    (* PROC *)          LatestAntecedantEndDate, 
                        TaskIsFixedType;

FROM ResWarnings    IMPORT
    (* TYPE *)          AWarning,
    (* PROC *)          IssueWarning, SendErrorMsg;

FROM RsrcMod    IMPORT  AResourcePointer, AResourceType;
    (* TYPE *)

FROM SYSTEM         IMPORT  TSIZE;
    (* PROC *)

FROM Timei          IMPORT ADate, ADuration, MaxDate;

FROM VaryAssgnment IMPORT AVaryingAssgnList;
    (* TYPE *)

(*<PRINT
FROM LongConvert    IMPORT LongToString;
FROM LStrings       IMPORT SetString, ConcatS, ConcatLS, CtoS;
FROM PrintSupport   IMPORT StartReport, PrintLine, EndReport;
FROM RealFormat     IMPORT FormatAsAmount, DefaultAmountFormat; 
FROM ResTrace       IMPORT PrintOn, NoteString, PrintAString, PrintList,
                           ConcatTaskID, PrintResidueAvailability;
FROM Codes          IMPORT ACode;
FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;



VAR
    s : ARRAY [0..255] OF CHAR;
    DummyCode: ACode;
PRINT>*)


(*------ ActivateCandidates --------------(exported)----------------*)


PROCEDURE ActivateCandidates (ActiveList           : AnExtHandle;
                              CandidatesList       : AnExtHandle;
                              PreCandidatesList    : AnExtHandle;
                              Day                  : ADate;
                              TimeConstrained      : BOOLEAN;
                          VAR WeActivatedSomething : BOOLEAN;
                          VAR WeBumpedSomething    : BOOLEAN);
VAR

        StartSearchAt              : ADate;
        TaskHandle, NextTaskHandle : AnExtHandle;
        Task                       : ATaskPtr;
        WeActivatedThisTask, WeBumpedForThisTask : BOOLEAN;
BEGIN

    IF LockObject(CandidatesList,Task)=0 THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(CandidatesList);

    (*<PRINT
    SetString(NoteString, "-------------------------");
    PrintAString(NoteString);
    SetString(NoteString, "ActivateCandidates: ");
    PrintAString(NoteString);
    SetString(NoteString, "-------------------------");
    PrintAString(NoteString);
    SetString(NoteString, "candidates list contains:");
    PrintAString(NoteString);
    PrintList(CandidatesList);
    PRINT>*)

    WeActivatedSomething := FALSE;
    WeBumpedSomething    := FALSE;

    WHILE (NOT ObjectsAreSame(TaskHandle,CandidatesList)) AND
           (NOT BreakRequested())                          DO
        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;
        NextTaskHandle := Task^.Nextlink;
        EXCL(Task^.TempTaskFlags,DontBump); (* temporarily *)

        (*<PRINT
        SetString(NoteString, "Attempting to activate task ");
        ConcatTaskID(NoteString, Task);
        PrintAString(NoteString);
        PRINT>*)

            (* case 1: LB = maxdate, infeasible task: *)

        IF (Task^.StartDateLowerBound = MaxDate) THEN
            (*<PRINT
            SetString(NoteString, "case 1: LB = maxdate - activating as infeasible task");
            PrintAString(NoteString);
            PRINT>*)
            ActivateInfeasibleTask(TaskHandle, 
                                   Task, 
                                   CannotSchedule, (* warning *)
                                   ActiveList);

                (* note: we leave WeActivatedSomething alone, since we
                   did not affect resources, and the task can't be
                   bumped - in essence, it did not really get scheduled *)

            (* case 2 - "AlreadyScheduled" case:  this case is
                now nonexistent (see change history 5/31/91) *)


                (* In the remaining cases, we attempt normal activation.
                Optimally we would like a start date of
                StartSearchAt, where StartSearchAt == latest antecedant end.
                If this is not feasible, we try to
                bump all "much lower priority tasks". 
                In any case, we want a start date <= Day.
                Details are described within each individual case. 

                In the below, "SS" denotes StartSearchAt, and "UB" the task's
                StartDateUpperBound. *)

        ELSE    
            (*<PRINT
            SetString(NoteString, " attempting normal activation:");
            PrintAString(NoteString);
            PRINT>*)

                (* Find the absolute lowest that the start date can be: *)
            StartSearchAt := 
               LatestAntecedantEndDate(Task, Task^.StartDateLowerBound);
                (* make sure we don't overshoot the upper bound: *)
            IF (StartSearchAt > Task^.StartDateUpperBound) THEN
                StartSearchAt := Task^.StartDateUpperBound;
            END;

            (*<PRINT
            SetString(NoteString, "Day = ");
            TimeUtoS(Day, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            SetString(NoteString, "SS = ");
            TimeUtoS(StartSearchAt, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            SetString(NoteString, "UB = ");
            TimeUtoS(Task^.StartDateUpperBound, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            PRINT>*)


                (* case 3: start-search too high (i.e., > Day) *)

                (* We bypass the task and wait for Day
                   to get higher *)

            IF (Day  < StartSearchAt) THEN
                (*<PRINT
                SetString(NoteString, "case 3, Day < SS: bypass the task");
                PrintAString(NoteString);
                PRINT>*)
                (* bypass the task - wait for a later iteration when
                    Day will have caught up - we leave WeActivatedSomething
                    alone *)

                (* case 4: no upper bound - attempt to activate *)

            ELSIF (Task^.StartDateUpperBound = MaxDate) THEN
                AttemptToActivateForNoUpperBound(TaskHandle,
                                                 Task,
                                                 StartSearchAt,
                                                 Day,
                                                 ActiveList,
                                                 PreCandidatesList,
                                                 WeActivatedThisTask,
                                                 WeBumpedForThisTask);
                WeActivatedSomething := (WeActivatedSomething) OR 
                                        (WeActivatedThisTask);
                WeBumpedSomething    := (WeBumpedSomething) OR
                                        (WeBumpedForThisTask);

                (* case 5: high, active upper bound 
                   (i.e., upper-bound >= Day and < MaxDate); 
                   attempt to activate. 
                   (Note: in this case we need to know if we are 
                   time constrained) *)

            ELSIF (Day <= Task^.StartDateUpperBound) THEN
                AttemptToActivateForHighUpperBound(TaskHandle,
                                                   Task,
                                                   StartSearchAt,
                                                   Day,
                                                   ActiveList,
                                                   PreCandidatesList,
                                                   TimeConstrained,
                                                   WeBumpedForThisTask);
                   (* in this case, we either found a feasible date or
                      we force-activated: *)
                WeActivatedSomething := TRUE;
                WeBumpedSomething := WeBumpedSomething OR
                                     WeBumpedForThisTask;
                (* case 6: low, active upper bound (upper bound < Day);
                     in this case we need to know if we are
                     time constrained *)

            ELSE
                AttemptToActivateForLowUpperBound(TaskHandle,
                                                  Task,
                                                  StartSearchAt,
                                                  Day,
                                                  ActiveList,
                                                  PreCandidatesList,
                                                  TimeConstrained,
                                                  WeBumpedForThisTask);
                   (* in this case, we either found a feasible date or
                      we force-activated: *)
                WeActivatedSomething := TRUE;
                WeBumpedSomething    := WeBumpedSomething OR
                                        WeBumpedForThisTask;

            END; (* end of "normal" activation cases 3-6 *)
        END; (* end of all cases for this task *)
        ReleaseObject(TaskHandle);   (*<KILL*) Task := NIL; (*KILL>*)
        IF SchedulingAbandoned THEN RETURN; END;
        TaskHandle := NextTaskHandle;
    END; (* loop *)

    (*<PRINT
    IF WeActivatedSomething THEN
        SetString(NoteString, "ACTIVATED SOMETHING!");
        PrintAString(NoteString);
    END;
    IF WeBumpedSomething THEN
        SetString(NoteString, "BUMPED SOMETHING!");
        PrintAString(NoteString);
    END;
    PRINT>*)

END ActivateCandidates;




(* ---- AttemptToActivateForNoUpperBound -----------------------------------------

   Case 4:      UB = MaxDate; SS <=Day <= UB;  

   1. If SS is feasible, activate there. 
   
   2. If not, brute-force bump all "much lower priority" 
      tasks, and then search  in [SS, Day]; if successful, activate.
      
   3. If not, bump at Day & try again in the same interval; if successful,
      activate.
   
   4. If not, bypass the task, provided that Day < MaxDate; if Day = MaxDate,
      then it is useless to wait for Day to get higher, so mark the task
      infeasible.
*)


PROCEDURE AttemptToActivateForNoUpperBound(TaskHandle      : AnExtHandle;            
                                           Task            : ATaskPtr;     
                                           StartSearchAt   : ADate;
                                           Day             : ADate;
                                           ActiveList      : AnExtHandle;
                                           PreCandidatesList : AnExtHandle;
                                       VAR WeActivated     : BOOLEAN;
                                       VAR WeBumped        : BOOLEAN);
VAR
    EndSearchAt, EarliestStart, ScheduleAtDate, 
     TaskEndDate : ADate;
    Bumpees           : ABumpeeArray;
    NumBumpees        : CARDINAL;
    WeStartedBumping, WeStartedBumpingMuchLowerPriorityTasks, 
      BumpingSucceeded, DoWeForceSchedule, AllWorkDone,
        DateIsGood, FoundADate,
        TaskIsInfeasible  : BOOLEAN;
    (*<PRINT
    AssignmentHandle : AnExtHandle;
    Assignments : AnAssignmentArray;
    Resource : AResourcePointer;
    ResourceCount, i : CARDINAL;
    PRINT>*)

BEGIN
    (*<PRINT
    SetString(NoteString, "case 4: activate for no upper bound");
    PrintAString(NoteString);
    PRINT>*)

    WeActivated := FALSE;

        (* initialize in preparation for bumping: *)
    BumpingSucceeded := FALSE;
    WeStartedBumping := FALSE;
    WeStartedBumpingMuchLowerPriorityTasks := FALSE;
    NumBumpees := 0;    
    WeBumped := FALSE;
    TaskIsInfeasible := FALSE;

        (* test SS as a feasible start date: *)

    (*<PRINT
    SetString(NoteString, "check SS as feasible date:");
    TimeUtoS(StartSearchAt, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    PRINT>*)

    CheckIfTaskFitsAtDate(Task, StartSearchAt, DateIsGood, TaskEndDate,
                           TaskIsInfeasible);

    IF TaskIsInfeasible THEN
       (*<PRINT
       SetString(NoteString, "Task is infeasible.");
       PrintAString(NoteString);
       PRINT>*)
       ActivateInfeasibleTask(TaskHandle, 
                              Task, 
                              ResourcesOverassigned, (* warning *)
                              ActiveList);
       RETURN;
    END;

        (* If SS is feasible, then activate; otherwise, bump all 
          "much lower priority" tasks and search the interval [SS, Day]: *)

    IF (DateIsGood) THEN
        (*<PRINT
        SetString(NoteString, "   SS feasible - activating:");
        PrintAString(NoteString);
        PRINT>*)
        ActivateTask(TaskHandle, Task, StartSearchAt,
                     FALSE (*force schedule*), ActiveList, AllWorkDone);
        WeActivated := TRUE;
        RETURN;
    END;

        (* SS wasn't feasible, so we continue: *)

    (*<PRINT
    SetString(NoteString, " SS not feasible - bumping much lower priority tasks:");
    PrintAString(NoteString);
    PRINT>*)
    TentativelyBumpAllMuchLowerPriorityTasks(Task,
                                             ActiveList,
                                             Bumpees,   (*in/out*)
                                             NumBumpees (*in/out*));
    IF SchedulingAbandoned THEN RETURN; END;
    WeStartedBumpingMuchLowerPriorityTasks := (NumBumpees > 0);

        (* Search in [SS, Day] *)

    (*<PRINT
    SetString(NoteString, "search in [SS, Day] = [");
    TimeUtoS(StartSearchAt, s);
    ConcatLS(NoteString, s);
    ConcatS(NoteString, ", ");
    TimeUtoS(Day, s);
    ConcatLS(NoteString, s);
    ConcatS(NoteString, "]");
    PrintAString(NoteString);
    PRINT>*)
    EndSearchAt := Day;
    FindEarliestStartDate (Task, StartSearchAt, EndSearchAt,
             FALSE (*allow overbookings*), FoundADate, 
             EarliestStart, TaskEndDate, TaskIsInfeasible);
    IF TaskIsInfeasible THEN
       (*<PRINT
       SetString(NoteString, "Task is infeasible.");
       PrintAString(NoteString);
       PRINT>*)
       ActivateInfeasibleTask(TaskHandle, 
                              Task, 
                              ResourcesOverassigned, (* warning *)
                              ActiveList);
       RETURN;
    END;

        (* If failure, and if Day < MaxDate, then bump at Day and try again *)
                        
    IF (NOT (FoundADate)) AND (Day < MaxDate) THEN
        (*<PRINT
        SetString(NoteString, " failure - bump at Day and try again in same interval");
        PrintAString(NoteString);
        PRINT>*)

        TentativelyBumpTasks(ActiveList, 
                             TaskHandle,
                             EndSearchAt, 
                             FALSE (*DoWeForceBump*),
                             Bumpees,         (* in/out *)
                             NumBumpees,      (* in/out *)
                             BumpingSucceeded,(* out *)
                             WeStartedBumping (* out *));
        IF (SchedulingAbandoned) THEN 
            RETURN; 
        END;
            (* if first-order obstacles removed, try again:*)
        IF (BumpingSucceeded) THEN
            (*<PRINT
            SetString(NoteString, "tentative bumping succeeded - try again");
            PrintAString(NoteString);
            PRINT>*)
            FindEarliestStartDate (Task, StartSearchAt, EndSearchAt,
                   FALSE (*allow overbookings*), FoundADate, 
                   EarliestStart, TaskEndDate, TaskIsInfeasible);
            IF TaskIsInfeasible THEN
               (*<PRINT
               SetString(NoteString, "Task is infeasible.");
               PrintAString(NoteString);
               PRINT>*)
               ActivateInfeasibleTask(TaskHandle, 
                                      Task, 
                                      ResourcesOverassigned, (* warning *)
                                      ActiveList);
               RETURN;
            END;
        END; (* bumping succeeded *)
    END; (* if not FoundADate and Day < MaxDate *)

         (* If success (whether or not we had to bump),
            finish bumping (if any) and activate the task -
            otherwise, undo the tentative bumping (if any) *)

    IF (FoundADate) THEN
        (*<PRINT
        SetString(NoteString, " success - finish bumping, and activate at ");
        TimeUtoS(EarliestStart, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)

        IF (WeStartedBumping OR WeStartedBumpingMuchLowerPriorityTasks) THEN
              FinishBumpingTasks (Bumpees, NumBumpees, PreCandidatesList);
              WeBumped := TRUE;
        END;
        ActivateTask(TaskHandle, Task, EarliestStart, 
             FALSE (*force schedule*), ActiveList, AllWorkDone);
        WeActivated := TRUE;

            (* If failure, undo the tentative bumping (if any) and
               bypass the task, UNLESS Day = MaxDate, in which
               case waiting for Day to get higher is futile,
               so we activate as an infeasible task *)
    ELSIF (Day = MaxDate) THEN
        (*<PRINT
        SetString(NoteString, " failure, and Day = Maxdate - activate as infeasible");
        PrintAString(NoteString);
        PRINT>*)

        IF (WeStartedBumpingMuchLowerPriorityTasks) THEN
              (* note: we didn't do TentativeBumping in this case *)
            UnbumpTasks(Bumpees, NumBumpees);
            IF SchedulingAbandoned THEN RETURN; END;
        END;
        ActivateInfeasibleTask(TaskHandle, 
                               Task, 
                               ResourcesOverassigned, (* warning *)
                               ActiveList);
          (* note - we leave "WeActivated" as false *)
    ELSIF (WeStartedBumping OR WeStartedBumpingMuchLowerPriorityTasks) THEN
         (*<PRINT
         SetString(NoteString, " failure - undo bumping and bypass task in this iteration");
         PrintAString(NoteString);
         PRINT>*)
         UnbumpTasks(Bumpees, NumBumpees);
    END; (* if FoundADate *)

END AttemptToActivateForNoUpperBound;


(* --------------- AttemptToActivateForHighUpperBounnd ------------------------

   Case 5: SS <= Day <= UB < MaxDate

   1. If SS is feasible, activate there. 
   
   2. If not, brute-force bump
      all "much lower priority" tasks, and then search in [SS, Day].
      If successful, activate.

   3. If not, bump at Day and try again
      in [SS, UB], which is possibly an expanded interval. If 
      successful, activate.

   4. If not, force-activate at UB.
   
*)

PROCEDURE AttemptToActivateForHighUpperBound(TaskHandle      : AnExtHandle;
                                             Task            : ATaskPtr;
                                             StartSearchAt   : ADate;
                                             Day             : ADate;
                                             ActiveList      : AnExtHandle;
                                             PreCandidatesList : AnExtHandle;
                                             TimeConstrained : BOOLEAN;
                                         VAR WeBumped        : BOOLEAN);
VAR
    EndSearchAt, EarliestStart, ScheduleAtDate, 
     TaskEndDate : ADate;
    Bumpees           : ABumpeeArray;
    NumBumpees        : CARDINAL;
    WeStartedBumping, WeStartedBumpingMuchLowerPriorityTasks, 
      BumpingSucceeded, DoWeForceSchedule, AllWorkDone,
        DateIsGood, FoundADate, TaskIsInfeasible      : BOOLEAN;
BEGIN

    (*<PRINT
    SetString(NoteString, "case 5: activate for upper bound >= Day");
    PrintAString(NoteString);
    PRINT>*)
        (* initialize in preparation for bumping: *)

    BumpingSucceeded := FALSE;
    WeStartedBumping := FALSE;
    WeStartedBumpingMuchLowerPriorityTasks := FALSE;
    WeBumped := FALSE;
    NumBumpees := 0;    

        (* test SS as a feasible start date: *)

    (*<PRINT
    SetString(NoteString, "check SS as feasible date:");
    TimeUtoS(StartSearchAt, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    PRINT>*)

    CheckIfTaskFitsAtDate(Task, StartSearchAt, DateIsGood, TaskEndDate,
                           TaskIsInfeasible);
    IF TaskIsInfeasible THEN
       (*<PRINT
       SetString(NoteString, "Task is infeasible.");
       PrintAString(NoteString);
       PRINT>*)
       ActivateInfeasibleTask(TaskHandle, 
                              Task, 
                              ResourcesOverassigned, (* warning *)
                              ActiveList);
       RETURN;
    END;

        (* If SS is feasible, then activate; otherwise, bump all 
          "much lower priority" tasks and search the interval [SS, Day].*)
           
        (* for a date to be feasible, we must also satisfy end-date
           constraint if we are in the time-constrained case: *)

    IF (DateIsGood) AND
        (NOT (TimeConstrained) OR 
         (TaskEndDate <= Task^.Plan.Dates.LateTotalEnd)) THEN
        (*<PRINT
        SetString(NoteString, "   SS feasible - activating:");
        PrintAString(NoteString);
        PRINT>*)
        ActivateTask(TaskHandle, Task, StartSearchAt,
                     FALSE (*force schedule*), ActiveList, AllWorkDone);
        RETURN;
    END;

        (* SS wasn't feasible, so we continue: *)

    (*<PRINT
    SetString(NoteString, " SS not feasible - bumping much lower priority tasks:");
    PrintAString(NoteString);
    PRINT>*)
    TentativelyBumpAllMuchLowerPriorityTasks(Task,
                                             ActiveList,
                                             Bumpees,   (*in/out*)
                                             NumBumpees (*in/out*));
    IF SchedulingAbandoned THEN RETURN; END;
    WeStartedBumpingMuchLowerPriorityTasks := (NumBumpees > 0);
                   
       (* Search in [SS, Day] *)
 
    (*<PRINT
    SetString(NoteString, "search in [SS, Day] = [");
    TimeUtoS(StartSearchAt, s);
    ConcatLS(NoteString, s);
    ConcatS(NoteString, ", ");
    TimeUtoS(Day, s);
    ConcatLS(NoteString, s);
    ConcatS(NoteString, "]");
    PrintAString(NoteString);
    PRINT>*)
    EndSearchAt := Day;
    FindEarliestStartDate (Task, StartSearchAt, EndSearchAt,
        FALSE (*allow overbookings*), FoundADate, 
        EarliestStart, TaskEndDate, TaskIsInfeasible);
    IF TaskIsInfeasible THEN
       (*<PRINT
       SetString(NoteString, "Task is infeasible.");
       PrintAString(NoteString);
       PRINT>*)
       ActivateInfeasibleTask(TaskHandle, 
                              Task, 
                              ResourcesOverassigned, (* warning *)
                              ActiveList);
       RETURN;
    END;

        (* If failure, bump at Day and try again in [SS, UB] *)

    IF (NOT (FoundADate)) OR 
       ((TimeConstrained) AND 
             (TaskEndDate > Task^.Plan.Dates.LateTotalEnd))  THEN
        (*<PRINT
        SetString(NoteString, " failure - bump at Day and try in [SS, UB] = [SS, ");
        TimeUtoS(Task^.StartDateUpperBound, s);
        ConcatLS(NoteString, s);
        ConcatS(NoteString, "]");
        PrintAString(NoteString);
        PRINT>*)
            (* bump and try again: *)
        TentativelyBumpTasks(ActiveList, 
                             TaskHandle, 
                             EndSearchAt, 
                             FALSE (*DoWeForceBump*),
                             Bumpees,         (* in/out *)
                             NumBumpees,      (* in/out *)
                             BumpingSucceeded,(* out *)
                             WeStartedBumping (* out *));
        IF (SchedulingAbandoned) THEN 
            RETURN; 
        END;

        (* if first-order obstacles removed or if the
           new interval is bigger, try again:*)

        IF (BumpingSucceeded) 
              OR (Task^.StartDateUpperBound > Day) THEN
            EndSearchAt := Task^.StartDateUpperBound;
            FindEarliestStartDate (Task, StartSearchAt, EndSearchAt,
                 FALSE (*allow overbookings*), FoundADate, 
                 EarliestStart, TaskEndDate, TaskIsInfeasible);
            IF TaskIsInfeasible THEN
               (*<PRINT
               SetString(NoteString, "Task is infeasible.");
               PrintAString(NoteString);
               PRINT>*)
               ActivateInfeasibleTask(TaskHandle, 
                                      Task, 
                                      ResourcesOverassigned, (* warning *)
                                      ActiveList);
               RETURN;
            END;
        END;
    END; (* not FoundADate *)

        (* If success (whether or not we bumped), 
           finish bumping (if any) and activate the task *)

    IF (FoundADate) AND
       (NOT (TimeConstrained) OR 
         (TaskEndDate <= Task^.Plan.Dates.LateTotalEnd)) THEN
        (*<PRINT
        SetString(NoteString, " success - finishing bumping and activating at ");
        TimeUtoS(EarliestStart, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)
        IF (WeStartedBumping OR WeStartedBumpingMuchLowerPriorityTasks) THEN
            FinishBumpingTasks(Bumpees, NumBumpees, PreCandidatesList);
            WeBumped := TRUE;
        END;
        ActivateTask(TaskHandle, Task, EarliestStart, 
                FALSE (*force schedule*), ActiveList, AllWorkDone);

            (* If failure, finish bumping tasks 
               and force-activate at UB - we finish the bumping
               since it's still better to have removed as
               many obstacles as possible *)
    ELSE
        (*<PRINT
        SetString(NoteString, " failure - ");
        IF TimeConstrained THEN
            ConcatS(NoteString, "finish bumping and force-activate at UB");
        ELSE
            ConcatS(NoteString, "activate as infeasible task");
        END;
        PrintAString(NoteString);
        PRINT>*)

        IF (WeStartedBumping OR WeStartedBumpingMuchLowerPriorityTasks) THEN
            IF (TimeConstrained) THEN
                FinishBumpingTasks(Bumpees, NumBumpees, PreCandidatesList);
                WeBumped := TRUE;
            ELSE
                UnbumpTasks(Bumpees, NumBumpees);
                WeBumped := FALSE;
            END;
        END;
        IF (TimeConstrained) THEN
            ActivateTask(TaskHandle, Task, Task^.StartDateUpperBound,
               TRUE (*force schedule*), ActiveList, AllWorkDone);
        ELSE
            ActivateInfeasibleTask(TaskHandle, 
                                   Task, 
                                   CannotSchedule, (* warning *)
                                   ActiveList);
        END;
    END;
END AttemptToActivateForHighUpperBound;


(* ------------- AttemptToActivateForLowUpperBound ----------------------------

    Case 6:     SS <= Day, UB < MaxDate, UB < Day

    1. If SS is feasible, activate there. 
    
    2. If not, brute-force bump all "much lower priority" 
       tasks, and then search in [SS, UB]. If successful, activate.

    3. If not, bump at UB and try again in [SS, UB]; if successful,
       activate.
    
    4. If not, force-activate at UB.
*)

PROCEDURE AttemptToActivateForLowUpperBound(TaskHandle      : AnExtHandle;
                                            Task            : ATaskPtr;
                                            StartSearchAt   : ADate;
                                            Day             : ADate;
                                            ActiveList      : AnExtHandle;
                                            PreCandidatesList : AnExtHandle;
                                            TimeConstrained : BOOLEAN;
                                        VAR WeBumped        : BOOLEAN);
VAR
    EndSearchAt, EarliestStart, ScheduleAtDate, 
      TaskEndDate : ADate;
    Bumpees           : ABumpeeArray;
    NumBumpees        : CARDINAL;
    WeStartedBumping, WeStartedBumpingMuchLowerPriorityTasks, 
       BumpingSucceeded, DoWeForceSchedule, AllWorkDone,
         DateIsGood, FoundADate, TaskIsInfeasible      : BOOLEAN;
BEGIN

    (*<PRINT
    SetString(NoteString, "case 6: activate for upper bound < Day");
    PrintAString(NoteString);
    PRINT>*)

        (* initialize in preparation for bumping: *)

    BumpingSucceeded := FALSE;
    WeStartedBumping := FALSE;
    WeStartedBumpingMuchLowerPriorityTasks := FALSE;
    WeBumped := FALSE;
    NumBumpees := 0;    

        (* test SS as a feasible start date: *)

    (*<PRINT
    SetString(NoteString, "check SS as feasible date:");
    TimeUtoS(StartSearchAt, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    PRINT>*)

    CheckIfTaskFitsAtDate(Task, StartSearchAt, DateIsGood, TaskEndDate,
                           TaskIsInfeasible);
    IF TaskIsInfeasible THEN
       (*<PRINT
       SetString(NoteString, "Task is infeasible.");
       PrintAString(NoteString);
       PRINT>*)
       ActivateInfeasibleTask(TaskHandle, 
                              Task, 
                              ResourcesOverassigned, (* warning *)
                              ActiveList);
       RETURN;
    END;

        (* If SS is feasible, then activate; otherwise, bump all 
          "much lower priority" tasks and search the interval [SS, Day]: *)

        (* for a date to be feasible, we must also satisfy end-date
           constraint if we are in the time-constrained case: *)
    IF (DateIsGood) AND
        (NOT (TimeConstrained) OR 
         (TaskEndDate <= Task^.Plan.Dates.LateTotalEnd)) THEN
        (*<PRINT
        SetString(NoteString, "   SS feasible - activating:");
        PrintAString(NoteString);
        PRINT>*)
        ActivateTask(TaskHandle, Task, StartSearchAt,
                     FALSE (*force schedule*), ActiveList, AllWorkDone);
        RETURN;
    END;


        (* SS was not feasible, so we continue: *)

    (*<PRINT
    SetString(NoteString, " SS not feasible - bumping much lower priority tasks:");
    PrintAString(NoteString);
    PRINT>*)
    TentativelyBumpAllMuchLowerPriorityTasks(Task,
                                             ActiveList,
                                             Bumpees,   (*in/out*)
                                             NumBumpees (*in/out*));
    IF SchedulingAbandoned THEN RETURN; END;
    WeStartedBumpingMuchLowerPriorityTasks := (NumBumpees > 0);

        (* Search in [SS, UB] *)
    (*<PRINT
    SetString(NoteString, "search in [SS, UB] = [");
    TimeUtoS(StartSearchAt, s);
    ConcatLS(NoteString, s);
    ConcatS(NoteString, ", ");
    TimeUtoS(Task^.StartDateUpperBound, s);
    ConcatLS(NoteString, s);
    ConcatS(NoteString, "]");
    PrintAString(NoteString);
    PRINT>*)

    EndSearchAt := Task^.StartDateUpperBound;
    FindEarliestStartDate (Task, StartSearchAt, EndSearchAt,
          FALSE (*allow overbookings*), FoundADate, 
          EarliestStart, TaskEndDate, TaskIsInfeasible);
    IF TaskIsInfeasible THEN
       (*<PRINT
       SetString(NoteString, "Task is infeasible.");
       PrintAString(NoteString);
       PRINT>*)
       ActivateInfeasibleTask(TaskHandle, 
                              Task, 
                              ResourcesOverassigned, (* warning *)
                              ActiveList);
       RETURN;
    END;

        (* If failure, bump at UB and try again *)

    IF (NOT (FoundADate)) OR 
          ((TimeConstrained) AND 
             (TaskEndDate > Task^.Plan.Dates.LateTotalEnd))  THEN
        (*<PRINT
        SetString(NoteString, " failure - bump at UB and try again in same interval");
        PrintAString(NoteString);
        PRINT>*)
        TentativelyBumpTasks(ActiveList, 
                             TaskHandle,
                             EndSearchAt, 
                             TRUE (*DoWeForceBump*),
                             Bumpees,         (* in/out *)
                             NumBumpees,      (* in/out *)
                             BumpingSucceeded,(* out *)
                             WeStartedBumping (* out *));
        IF (SchedulingAbandoned) THEN RETURN; END;
            (* if first-order obstacles removed, try again:*)
        IF (BumpingSucceeded) THEN
            FindEarliestStartDate (Task, StartSearchAt, EndSearchAt,
                  FALSE (*allow overbookings*), FoundADate, 
                  EarliestStart, TaskEndDate, TaskIsInfeasible);
            IF TaskIsInfeasible THEN
               (*<PRINT
               SetString(NoteString, "Task is infeasible.");
               PrintAString(NoteString);
               PRINT>*)
               ActivateInfeasibleTask(TaskHandle, 
                                      Task, 
                                      ResourcesOverassigned, (* warning *)
                                      ActiveList);
               RETURN;
            END;
        END;
    END;

        (* If success (whether or not we bumped), 
           finish bumping (if any) and activate the task *)

    IF (FoundADate) AND
          (NOT (TimeConstrained) OR 
               (TaskEndDate <= Task^.Plan.Dates.LateTotalEnd)) THEN
        (*<PRINT
        SetString(NoteString, " success - finishing bumping and activating at ");
        TimeUtoS(EarliestStart, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)

        IF (WeStartedBumping OR WeStartedBumpingMuchLowerPriorityTasks) THEN
            FinishBumpingTasks(Bumpees, NumBumpees, PreCandidatesList);
            WeBumped := TRUE;
        END;
        ActivateTask(TaskHandle, Task, EarliestStart, 
              FALSE (*force schedule*), ActiveList, AllWorkDone);

            (* If failure, finish bumping anyway and 
               force-activate at UB - we finish bumping
               since it's still desirable to have removed
               as many obstacles as possible *)

    ELSE
        (*<PRINT
        SetString(NoteString, " failure - ");
        IF TimeConstrained THEN
            ConcatS(NoteString, "finish bumping and force-activate at UB");
        ELSE
            ConcatS(NoteString, "activate as infeasible task");
        END;
        PrintAString(NoteString);
        PRINT>*)

        IF (WeStartedBumping OR WeStartedBumpingMuchLowerPriorityTasks) THEN
            IF (TimeConstrained) THEN
                FinishBumpingTasks(Bumpees, NumBumpees, PreCandidatesList);
                WeBumped := TRUE;
            ELSE
                UnbumpTasks(Bumpees, NumBumpees);
                WeBumped := FALSE;
            END;
        END;
        IF (TimeConstrained) THEN
            ActivateTask(TaskHandle, Task, Task^.StartDateUpperBound,
               TRUE (*force schedule*), ActiveList, AllWorkDone);
        ELSE
            ActivateInfeasibleTask(TaskHandle, 
                                   Task, 
                                   CannotSchedule, (* warning *)
                                   ActiveList);
        END;
    END;
END AttemptToActivateForLowUpperBound;

END ResActivate.

