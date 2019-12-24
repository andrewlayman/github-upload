IMPLEMENTATION MODULE ResStartDates;
(*V2=PRINT WITH debugging printouts. *)
(*V9=CASES WITH more debugging printouts *)
(*V3=DEBUG with assertions verified *)
(*V4=KILL pointers when FlexStor objects are released. *)

(*<KILL*) (*$T+*) (*KILL>*)

    (* This module provides procedures to find earliest
       start dates for tasks,
       for use in resource levelling. 

      MODIFICATION HISTORY

   Jan. 31  92  AJL - Converted rates to floating point.
    Feb   4, 92  JES - Changed FindPotentialStartDateForSplitTask (and
                        other related procedures) so duration-driven
                        split tasks are not allowed to start on a date
                        when all resources are on vacation. (Note: the
                        exception is if the duration is zero; however,
                        the case "AllowOverbookings" was not left in
                        as an exception.)
                     - Fixed bug in SomeResourceNotOnVacation where i'th
                        resource was not getting initialized.
    Feb  11, 92   JES- FindEarliestStartDateForEffortSplit now requires
                        2, and not just 1% to be available on the start
                        date. (Note: when we implement the "min rate"
                        parameter, if this is on an assignment or resource
                        (rather than on a per-task) basis,
                        we will have to be careful about requirements
                        on the start date for these tasks.)
    Mar 3,   92   JES - In addition to not levelling summary tasks and those
                        with no employable resources, we now do not level       
                        duration-driven tasks with duration 0.
    Mar 4,   92   JES - Moved the degenerate case of an effort-driven task      
                        out into the top, together with the other degenerate
                        cases (duration driven w duration 0, etc). For
                        cleanup only (no effect).
    Apr 1, 92     AJL - If an effort driven task has no assigned resources,
                        schedule it as we would if it were a duration-driven
                        task with a duration equal to the effort at 100%.
                        Bug 5472.
*)


FROM Allocs         IMPORT  
    (* TYPE *)              ATask, ATaskPtr, ATaskStatus, AnAssignmentSummary,
                            ASplittingRule, ADurationMethod;

FROM Allocs         IMPORT  AFixType;

FROM AsOf      IMPORT
    (* VAR  *)          AsOfDate;

FROM Assignments    IMPORT  AnAssignmentRecord, AnAssignmentArray,
                              DurationOf;
    (* TYPE *)

FROM CalShift       IMPORT
    (* VAR  *)              TimeSheet;

FROM Dialog         IMPORT  Error, FatalError, ErrorPhrase;
    (* PROC *)

FROM Edges          IMPORT 
    (* TYPE *)                  AnEdgePtr, AnEdge;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, 
    (* PROC *)              LockObject, LockObjectArray, ReleaseObject,
                            ReleaseUnchangedObject;
 
FROM LStrings       IMPORT  SetString, CtoS;
    (* PROC *)

FROM Planner        IMPORT ScheduleComputedOk, MoveFutureTasks;
    (* VAR *)

FROM Phantoms       IMPORT SummaryFlag;
    (* CONST *)

FROM ResAvailableResources IMPORT
                            FindFirstDateHaveResourceAmount,
                            AllResourcesAreAvailable,
                            FindFirstDateResOnVacationOrAvailable,
                            FindFirstDateResourceNotOnVacation,
                            AllResourcesOnVacationOrAvailable,
                            CheckResourceOnDate;



FROM ResConstants   IMPORT  MaxLevellableResourcesPerTask, SchedulingAbandoned,
                             LongZero, Two;

FROM ResScheduleTaskResources       
    (* PROC *)      IMPORT  CreateSubstitutableResourceAssignments;


FROM ResUtilities   IMPORT   
    (* TYPE *)              Zero,
    (* PROC *)              EarliestDescendantStartDate, 
                            TaskUsesNoEmployableResources,
                            NoEmployableResources,
                            CheckResourceDuration,
                            ToGoDurationOfEffortDrivenTask,
                            EffortToDuration, DurationToEffort;

FROM ResWarnings    IMPORT  
    (* TYPE *)              AWarning,
    (* PROC *)              IssueWarning, SendErrorMsg;


FROM RsrcMod        IMPORT  AResourcePointer, AResourceType;
    (* TYPE *)             

FROM Space          IMPORT  HeapAvailable, ALLOCATE, DEALLOCATE;
    (* PROC *)

FROM SYSTEM         IMPORT  TSIZE;
    (* PROC *)

FROM Timei          IMPORT  
    (* CONST*)             MaxDate, OneUnitOfDuration, MinDate, NoDuration,
    (* TYPE *)             ADate, ADuration;

FROM Timeu          IMPORT FSMUPH;
    (* VAR *)


FROM VaryAssgnment IMPORT AVaryingAssgnList;
    (* TYPE *)


(*  ------------------------ Import if tracing ------------------*)
(*<PRINT

FROM LStrings IMPORT ConcatS, ConcatLS;
FROM LongConvert  IMPORT LongToString;
FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat; 

FROM ResTrace    IMPORT
                        NoteString, PrintAString, PrintList, ConcatTaskID,
                        PrintResidueAvailability;

FROM TimeFormat   IMPORT TimeUtoS;

VAR
    s : ARRAY [0..255] OF CHAR;
PRINT>*)





(*------FindEarliestStartDate--------------------(exported)------------------

    Returns the earliest possible date in the interval
    [StartSearchAt, EndSearchAt] on which the
    task could start, taking into account vacations and required
    remaining duration(s).

    If such a date is found, FoundADate is returned as TRUE and
    StartDate holds the date, and TaskEndDate holds the resulting
    task end date.
    Otherwise, FoundADate is returned
    as FALSE and StartDate holds no valid date.

    [If at any point the procedure finds that the only possible start
    date on or after StartSearchAt is MaxDate (regardless of the value of
    EndSearchAt), the task is flagged as unschedulable, a warning to
    that effect is issued, and
    the procedure returns FoundADate as FALSE and StartDate as
    the task duration minus MaxDate.]

    If AllowOverbookings is FALSE, then resource-level 
    constraints are in effect; otherwise they are ignored. 
    
    Note: 
        (1) If the task is effort-driven split, the ONLY requirement
            for the start date (other than being >= StartSearchAt
            and <= EndSearchAt) is that at least one resource is 
            available at the required level and is not on vacation.
        (2) For other split-type tasks, the requirements are that 
            (1) at least one resource is not on vacation, (2) and
            all resources are available at the required levels (except
            possibly for vacations) throughout whatever duration is required.
            (In duration-driven tasks, vacations count in the required
            duration; in assignment-driven tasks, the required duration
            is a function of each resource assignment.)
        (3) For delay-type tasks, the requirements are (1) no resource is
            on vacation and (2) all resources are available at the
            required levels, and are never on vacation, during the whole
            required duration starting at the date.

    Preconditions -
       A valid task. StartSearchAt <= EndSearchAt.
        
    Postconditions -
       No effects.
*)
PROCEDURE FindEarliestStartDate (Task              : ATaskPtr;
                                 StartSearchAt     : ADate;
                                 EndSearchAt       : ADate;
                                 DoWeAllowOverbookings : BOOLEAN;
                             VAR FoundADate        : BOOLEAN;
                             VAR StartDate         : ADate;
                             VAR TaskEndDate       : ADate;
                             VAR TaskIsInfeasible  : BOOLEAN);

BEGIN

    (*<PRINT
    SetString(NoteString,"**EARLIEST STARTDATE FOR ");
    ConcatTaskID(NoteString,Task);
    ConcatS(NoteString,", between ");
    TimeUtoS(StartSearchAt,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString," and ");
    TimeUtoS(EndSearchAt,s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    SetString(NoteString, "   with allow overbookings = ");
    IF DoWeAllowOverbookings THEN
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    PrintAString(NoteString);
    PRINT>*)

    (*<DEBUG*)
    IF (EndSearchAt < StartSearchAt) THEN
        SendErrorMsg("EarliestStart: end search < start search");
        ErrorPhrase(0);
    END;
    (*DEBUG>*)

        (* TaskIsInfeasible will get set to TRUE only if the task
           is effort-split and we find that 
           not all the work can be scheduled. 
           Note: a return value of FALSE for this parameter does not
           mean that the task may not be found to be infeasible in
           a later iteration of activation ! *)

    TaskIsInfeasible := FALSE; 

        (* dispense with summary tasks: *)
    IF (SummaryFlag IN Task^.TempTaskFlags) THEN        
        (*<PRINT
        SetString(NoteString, " summary task: start = end = StartSearchAt");
        PrintAString(NoteString);
        PRINT>*)
        StartDate   := StartSearchAt;
        TaskEndDate := StartSearchAt;
        FoundADate  := TRUE;
        RETURN;
    END;


        
        (* dispense with effort-driven tasks with no ToGo effort: *)
    IF (Task^.DurationMethod = EffortDriven) AND
       (Task^.ToGoSummary.Time <= Zero) THEN
        (*<PRINT
        SetString(NoteString, " eff-driv w no effort: start = end = StartSearchAt");
        PrintAString(NoteString);
        PRINT>*)
        StartDate   := StartSearchAt;
        TaskEndDate := StartSearchAt;
        FoundADate  := TRUE;
        RETURN;
    END;

        (* Special rule for "effort-driven" tasks with no assignments. *)

    IF (Task^.DurationMethod = EffortDriven) AND
       (TaskUsesNoEmployableResources(Task)) THEN
        Task^.duration := TRUNC(Task^.ToGoSummary.Time * FSMUPH);
        StartDate      := StartSearchAt;
        TaskEndDate    := StartSearchAt + Task^.duration;
        FoundADate     := TRUE;
        RETURN;
    END;


        (* dispense with milestones: *)
    IF (Task^.DurationMethod = DurationDriven) AND (Task^.duration = 0) THEN
        (*<PRINT
        SetString(NoteString, " dur-driv with dur 0: start = end = StartSearchAt");
        PrintAString(NoteString);
        PRINT>*)
        StartDate   := StartSearchAt;
        TaskEndDate := StartSearchAt;
        FoundADate  := TRUE;
        RETURN;
    END;

        (* dispense with tasks that have no employable resources: *)
    IF (TaskUsesNoEmployableResources(Task)) THEN        
        (*<PRINT
        SetString(NoteString, "  no employable resources: just check end date");
        PrintAString(NoteString);
        PRINT>*)
        StartDate := StartSearchAt;
        IF (Task^.DurationMethod = DurationDriven) THEN
            IF (StartDate <= MaxDate - Task^.duration) THEN
                FoundADate := TRUE;
                TaskEndDate := StartDate + Task^.duration;
            ELSE
                (*<PRINT
                SetString(NoteString, "task overruns maxdate");
                PrintAString(NoteString);
                PRINT>*)
                FoundADate  := FALSE;
                TaskEndDate := MaxDate;
            END;
        ELSE
            FoundADate  := TRUE;
            TaskEndDate := StartDate;
        END;
        RETURN;
    END;


    IF (Task^.SplittingRule = Split) THEN
        FindEarliestStartDateForSplitTask(Task,
                                          StartSearchAt,
                                          EndSearchAt,
                                          DoWeAllowOverbookings,
                                          FoundADate,
                                          StartDate,
                                          TaskEndDate,
                                          TaskIsInfeasible);
    ELSE
        FindEarliestStartDateForDelayTask(Task,
                                          StartSearchAt,
                                          EndSearchAt,
                                          DoWeAllowOverbookings,
                                          FoundADate,
                                          StartDate,
                                          TaskEndDate);
    END;

    (*<DEBUG*)
    IF (FoundADate) AND 
       ((StartDate < StartSearchAt) OR (StartDate > EndSearchAt)) THEN
       SendErrorMsg("FindEarliestStart: start date out of range");
       FatalError;
    END;
    (*DEBUG>*)

END FindEarliestStartDate;



(* ---------------- FindEarliestStartDateForSplitTask ----------------------*)



PROCEDURE FindEarliestStartDateForSplitTask (Task              : ATaskPtr;
                                             StartSearchAt     : ADate;
                                             EndSearchAt       : ADate;
                                             DoWeAllowOverbookings : BOOLEAN;
                                         VAR FoundADate        : BOOLEAN;
                                         VAR StartDate         : ADate;
                                         VAR TaskEndDate       : ADate;
                                         VAR TaskIsInfeasible  : BOOLEAN);


VAR
    AssignmentHandle    : AnExtHandle;      
    Assignments         : AnAssignmentArray;
    DurationMethod      : ADurationMethod;
    ResourceCount       : CARDINAL;         
    FirstViolationDate  : ADate;    
        (* Given a potential start date, FirstViolationDate is the 
         last date contained in the first cell with 
         a resource violation (i.e., insufficient amount available
         and resource not on vacation) *)         
    PotentialDate       : ADate;
    FoundGoodDate,FoundPotentialDate,
      AllWorkDone : BOOLEAN;
    Print : BOOLEAN;

BEGIN

    (* case 1 - effort driven split task *)
    IF (Task^.DurationMethod = EffortDriven) THEN
        (*<PRINT
        SetString(NoteString, "Effort split task: ");
        PrintAString(NoteString);
        PRINT>*)

         FindEarliestStartForEffortSplit(Task,
                                         StartSearchAt,
                                         EndSearchAt,
                                         DoWeAllowOverbookings,
                                         TRUE, (* DoWeContour - inline for now *)
                                         TRUE, (* DoWeComputeTaskEndDate*)
                                         FoundADate,
                                         StartDate,
                                         TaskEndDate,
                                         AllWorkDone);

        IF (FoundADate) AND NOT (AllWorkDone) THEN
            TaskIsInfeasible := TRUE; (* this task can never be scheduled *)
            (*<PRINT
            SetString(NoteString, "This task is infeasible.");
            PrintAString(NoteString);
            PRINT>*)
            (*<DEBUG*)
            IF ((Task^.SplittingRule = Delay) OR
                NOT (Task^.DurationMethod = EffortDriven)) THEN
                SendErrorMsg("Only eff split tasks should be found infeasible here!");
                FatalError;
            END;
            (*DEBUG>*)
        END;

    (* case 2 - assignment-driven or duration-driven split task *)
    ELSE    
        IF (Task^.DurationMethod = DurationDriven) AND
              (Task^.duration  = 0) THEN 

               (*<PRINT
               SetString(NoteString, "dur-driven split w");
               ConcatS(NoteString, " duration = 0");
               PrintAString(NoteString);
               SetString(NoteString, "       - date is good");
               PrintAString(NoteString);
               PRINT>*)

               StartDate := StartSearchAt;
               TaskEndDate := StartDate;
               FoundADate := TRUE;
               RETURN;
        END;


        (* First find a potential start date:
              Set PotentialDate to the first date that some resource is
              available and not on vacation, and such that any other
              resource not on vacation has the required amount available.
        *)
        DurationMethod := Task^.DurationMethod;
        AssignmentHandle := Task^.Plan.Assignments;
        ResourceCount    := LockObjectArray(AssignmentHandle,
                                            Assignments,  
                                            TSIZE(AnAssignmentRecord));
        
        FindPotentialStartDateForSplitTask(Assignments,
                                           ResourceCount,  
                                           DurationMethod,
                                           StartSearchAt,
                                           EndSearchAt,
                                           DoWeAllowOverbookings,
                                           FoundPotentialDate,
                                           PotentialDate);


        (*<DEBUG*)
        IF (FoundPotentialDate) AND
           ((PotentialDate < StartSearchAt) OR (PotentialDate > EndSearchAt)) THEN
           SendErrorMsg("find potential date for split task: pot date out of range");
           FatalError;
        END;
        (*DEBUG>*)

        (* exit now if no such date: *)
        IF NOT (FoundPotentialDate) THEN
            (*<PRINT
            SetString(NoteString, " no date with all resources available in given interval.");
            PrintAString(NoteString);
            PRINT>*)
            (* there is no feasible date within the specified interval: *)
            FoundADate := FALSE;
            ReleaseUnchangedObject(AssignmentHandle);
            (*<KILL*) Assignments := NIL; (*KILL>*)
            RETURN; 
        END;
    
        (* Note: If allow overbookings is TRUE, then we know the date found above
           is valid; otherwise, we must check that all the resource durations
           can be satisfied, and if not, try again in a loop. In both
           cases, we use the CheckStartDateFeasibility procedure, since this
           will return us the resulting task end date. *)
    
        FoundGoodDate := FALSE;
        WHILE (NOT FoundGoodDate) DO
    
            (*<PRINT
            SetString(NoteString,"    **TRIAL START DATE = ");
            TimeUtoS(PotentialDate,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            PRINT>*)
    
            CheckStartDateFeasibility (Task,
                                       Assignments,
                                       ResourceCount,
                                       PotentialDate,
                                       DoWeAllowOverbookings,
                                       FoundGoodDate,
                                       TaskEndDate,
                                       FirstViolationDate);
            
            IF FoundGoodDate THEN
                (*<PRINT
                SetString(NoteString, "Found good date: ");
                TimeUtoS(PotentialDate, s);
                ConcatLS(NoteString, s);
                PrintAString(NoteString);
                SetString(NoteString, "end date = : ");
                TimeUtoS(TaskEndDate, s);
                ConcatLS(NoteString, s);
                PrintAString(NoteString);
                PRINT>*)
   
                    (* The task fits at PotentialDate. *)
                FoundADate := TRUE;
                StartDate := PotentialDate; (*end date set by check feasib *)
            ELSE
        
                (*<PRINT
                SetString(NoteString, "Trial date is bad: ");
                TimeUtoS(PotentialDate, s);
                ConcatLS(NoteString, s);
                PrintAString(NoteString);
                SetString(NoteString, "  violation date: ");
                TimeUtoS(FirstViolationDate,s);
                ConcatLS(NoteString,s);
                PrintAString(NoteString);
                PRINT>*)
    
                (* Try again from violation date + 1 (reset PotentialDate): *)
    
                IF ((FirstViolationDate <= EndSearchAt - 1) AND
                    (FirstViolationDate < MaxDate - 1)) THEN
                      FindPotentialStartDateForSplitTask (Assignments,
                                                          ResourceCount,  
                                                          DurationMethod,
                                                          FirstViolationDate + 1,
                                                          EndSearchAt,
                                                          DoWeAllowOverbookings,
                                                          FoundPotentialDate,
                                                          PotentialDate);
                ELSE
                    (*<PRINT
                    SetString(NoteString, "no more tries or exceed range");
                    PrintAString(NoteString);
                    PRINT>*)
                    FoundPotentialDate := FALSE;
                END;
    
                IF NOT (FoundPotentialDate) THEN
                    (* there is no feasible date within the specified interval: *)
                    FoundADate := FALSE;
                    ReleaseUnchangedObject(AssignmentHandle);
                    (*<KILL*)  Assignments := NIL;  (*KILL>*)
                    RETURN; 
                END;
    
                (*<PRINT
                SetString(NoteString, "New candidate date = ");
                TimeUtoS(PotentialDate, s);
                ConcatLS(NoteString, s);
                PRINT>*)
            END;
        END; (* end loop *)
        ReleaseUnchangedObject(AssignmentHandle);
        (*<KILL*)  Assignments := NIL; (*KILL>*)

    END; (* end case on duration method *)


END FindEarliestStartDateForSplitTask;



(* ------ FindEarliestStartDateForDelayTask --------------------------------

   Note: For now, we require a single start date for all assignments
         in the case of an assignment driven delay task. Later we
         may relax this constraint. For instance, we may allow a date
         such that the longest assignment starts there, and all other
         assignments must fit between the start and end of the longest
         assignment. Or, we may have a single end date (i.e., all 
         assignments end on the same date, but may start at different
         dates) instead of a single start date. There are all manner
         of possibilities for user-choices in future releases. 
         JES 1/10/91
*)            



PROCEDURE FindEarliestStartDateForDelayTask (Task              : ATaskPtr;
                                             StartSearchAt     : ADate;
                                             EndSearchAt       : ADate;
                                             DoWeAllowOverbookings : BOOLEAN;
                                         VAR FoundADate        : BOOLEAN;
                                         VAR StartDate         : ADate;
                                         VAR TaskEndDate       : ADate);


VAR
    AssignmentHandle    : AnExtHandle;      
    Assignments         : AnAssignmentArray;
    ResourceCount       : CARDINAL;         
    FirstViolationDate  : ADate;    
        (* Given a potential start date, FirstViolationDate is the 
         last date contained in the first cell with 
         a resource violation (i.e., insufficient amount available
         and resource not on vacation) *)         
    PotentialDate       : ADate;
    FoundGoodDate      : BOOLEAN;
    FoundPotentialDate : BOOLEAN;

BEGIN

    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,  
                                        TSIZE(AnAssignmentRecord));


    (* Set PotentialDate to the first date that all resources are
       available. *)

    FindFirstDateAllResourcesAreAvailable (Assignments,
                                           ResourceCount,
                                           StartSearchAt,
                                           EndSearchAt,
                                           FALSE, (* allow vacations *)
                                           DoWeAllowOverbookings,
                                           FoundPotentialDate,
                                           PotentialDate);
    (* exit now if no such date: *)
    IF NOT (FoundPotentialDate) THEN
        (*<PRINT
        SetString(NoteString, " no date with all resources available in given interval.");
        PrintAString(NoteString);
        PRINT>*)
        FoundADate := FALSE;
        ReleaseUnchangedObject(AssignmentHandle);
        (*KILL*)  Assignments := NIL;  (*KILL>*)
        RETURN; 
    END;
    
        (* now check that the required durations can be satisfied: *)

    FoundGoodDate := FALSE;
    WHILE (NOT FoundGoodDate) DO
    
        (*<PRINT
        SetString(NoteString,"    **TRIAL START DATE = ");
        TimeUtoS(PotentialDate,s);
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
        PRINT>*)
    
        CheckStartDateFeasibility (Task,
                                   Assignments,
                                   ResourceCount,
                                   PotentialDate,
                                   DoWeAllowOverbookings,
                                   FoundGoodDate,
                                   TaskEndDate,
                                   FirstViolationDate);
            
        IF FoundGoodDate THEN
            (*<PRINT
            SetString(NoteString, "Found good date: ");
            TimeUtoS(PotentialDate, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            SetString(NoteString, "End date = : ");
            TimeUtoS(TaskEndDate, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            PRINT>*)
   
            FoundADate := TRUE;
            StartDate := PotentialDate; (* task end date set by check feasib *)
        ELSE
            (*<PRINT
            SetString(NoteString, "Trial date is bad: ");
            TimeUtoS(PotentialDate, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            SetString(NoteString, "  violation date: ");
            TimeUtoS(FirstViolationDate,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            PRINT>*)
    
            (* Try again from violation date + 1 (reset PotentialDate): *)

            IF ((FirstViolationDate <= EndSearchAt - 1) AND
               (FirstViolationDate < MaxDate - 1)) THEN
                FindFirstDateAllResourcesAreAvailable (Assignments,
                                                       ResourceCount,
                                                       FirstViolationDate+1,
                                                       EndSearchAt,
                                                       FALSE, (* allow vacations *)
                                                       DoWeAllowOverbookings,
                                                       FoundPotentialDate,
                                                       PotentialDate);
            ELSE
                (*<PRINT
                SetString(NoteString, "no more tries since violation is >= maxdate - 1");
                PrintAString(NoteString);
                PRINT>*)
                FoundPotentialDate := FALSE;
            END;
    
            IF NOT (FoundPotentialDate) THEN
                (* there is no feasible date within the specified interval: *)
                FoundADate := FALSE;
                ReleaseUnchangedObject(AssignmentHandle);
                (*<KILL*)   Assignments := NIL;  (*KILL>*)
                RETURN; 
            END;
    
            (*<PRINT
            SetString(NoteString, "New candidate date = ");
            TimeUtoS(PotentialDate, s);
            ConcatLS(NoteString, s);
            PRINT>*)
        END;
    END; (* end loop *)

    ReleaseUnchangedObject(AssignmentHandle);
    (*<KILL*)   Assignments := NIL;  (*KILL>*)

END FindEarliestStartDateForDelayTask;


(* --- FindEarliestStartForEffortSplit - 

    Returns, via DateFound, the first date in the interval
    [StartSearchAt, EndSearchAt] such that at least one of the
    required resources is not on vacation and is
    available at the required level, i.e.:
      - no requirement on level if resource is non-levellable;
      - level >= min (Two, max rate percent)
                if DoWeContour is true and resource is levellable;
      - level >= MaxRatePercent if DoWeContour is true and resource
                      is levellable)
    If DateIsGood turns out to be true and the procedure is called with
    DoWeComputeEndDate set to true, then we call the dry-run version of 
    CreateSubstitutableResourceAssignments) to determine the
    resulting TaskEndDate. Otherwise the value of TaskEndDate
    is not meaningful.

    If DateIsGood turns out to be true and the procedure is called with
    DoWeComputeEndDate set to true, then AllWorkDone is set to true if
    all required effort can be accomplished within the resulting end date.
    Otherwise, AllWorkDone is set to false.

*)

PROCEDURE FindEarliestStartForEffortSplit (Task               : ATaskPtr;
                                           StartSearchAt      : ADate;
                                           EndSearchAt        : ADate;
                                           DoWeAllowOverbookings : BOOLEAN;
                                           DoWeContour        : BOOLEAN;
                                           DoWeComputeEndDate : BOOLEAN;
                                       VAR FoundADate         : BOOLEAN;
                                       VAR DateFound          : ADate;
                                       VAR TaskEndDate        : ADate;
                                       VAR AllWorkDone        : BOOLEAN);

VAR
    ResourceDate, ResultingEndDate : ADate;
    Resource                       : AResourcePointer;
    ResourceLevelRequired          : LONGINT;
    AssignmentHandle               : AnExtHandle;      
    Assignments                    : AnAssignmentArray;
    ResourceCount, i, 
       LevelledResourceCount       : CARDINAL;         
    DoWeAllowOverbook, FoundResourceDate, TaskHasResources : BOOLEAN;

        (* Special case for effort-split tasks without any resources.
           For these, we pretend that the task was duration-split.
        *)

    PROCEDURE SpecialEffortWithoutResources;
    BEGIN
        DateFound := StartSearchAt;
        TaskEndDate := StartSearchAt + TRUNC(Task^.ToGoSummary.Amount * FSMUPH);
        AllWorkDone := TRUE;   (* Lie. *)
        FoundADate := FALSE;
    END SpecialEffortWithoutResources;

BEGIN


    TaskHasResources := FALSE;

    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,  
                                        TSIZE(AnAssignmentRecord));

    IF (ResourceCount = 0) THEN
        SpecialEffortWithoutResources();
        RETURN;
    END;

    LevelledResourceCount := 0;
    FoundADate := FALSE;
    DateFound  := MaxDate;
    FOR i := 0 TO (ResourceCount - 1) DO
        Resource     := Assignments^[i].Resource;
        IF (Resource^.Type = Employable) THEN
            (* we don't consider or touch non-employable resources in levelling *)
            TaskHasResources := TRUE;

            IF (Resource^.LevelThisResource) THEN
                INC(LevelledResourceCount);
                IF LevelledResourceCount > MaxLevellableResourcesPerTask THEN
                    IssueWarning(TooManyResources, Task);                    
                    INCL(Task^.TaskStatusSet, NeedsRecalculate);
                END;            
            END; (* level this resource *)

                (* set required level of resource - if contouring, this will be
                   the minimum of Two Percent and the max rate percent *)
            ResourceLevelRequired := VAL(LONGINT, Assignments^[i].MaxRatePercent);
            IF (DoWeContour) AND (ResourceLevelRequired >= Two) THEN
                ResourceLevelRequired :=Two;
            END;
                
            DoWeAllowOverbook := (DoWeAllowOverbookings) OR NOT (Resource^.LevelThisResource);

            FindFirstDateHaveResourceAmount (Resource,
                                             ResourceLevelRequired,
                                             StartSearchAt,
                                             EndSearchAt,
                                             FALSE, (*DoWeAllowVacations*)
                                             DoWeAllowOverbook,
                                             FALSE, (*DoWeUseLateAvailabilities*)
                                             FoundResourceDate,
                                             ResourceDate);
            (*<PRINT
            IF FoundResourceDate THEN
                SetString(NoteString,"   first date for this resource = ");
                TimeUtoS(ResourceDate, s);
                ConcatLS(NoteString,s);
                PrintAString(NoteString);
            END;
            PRINT>*)
            IF (FoundResourceDate) AND (ResourceDate < DateFound) THEN
                DateFound := ResourceDate;
                (*<PRINT
                SetString(NoteString,  " (resetting temp task date)");
                PrintAString(NoteString);
                PRINT>*)
            END;
            FoundADate := (FoundADate) OR (FoundResourceDate);
        END; (* employable resource *)
    END; (* end loop *)

    ReleaseUnchangedObject( AssignmentHandle );  
    (*<KILL*)  Assignments := NIL;   (*KILL>*)


    IF (NOT FoundADate) THEN 
        (*<PRINT
            SetString(NoteString," no resource available in given range.");
            PrintAString(NoteString);
        PRINT>*)
        IF (NOT TaskHasResources) THEN        (* Trick for effort-split but no resources. *)
            SpecialEffortWithoutResources();
        END;
        RETURN;
    END;

    (* we found a date; now calculate the resulting TaskEndDate,
       if called for: *)

       (*<PRINT
       SetString(NoteString, "  found start date = ");
       TimeUtoS(DateFound,s);
       ConcatLS(NoteString,s);
       PrintAString(NoteString);
       PRINT>*)

       IF (DoWeComputeEndDate) THEN
           (*<PRINT
           SetString(NoteString, "  computing task end date:");
           PrintAString(NoteString);
           PRINT>*)
           CreateSubstitutableResourceAssignments 
                   (Task,
                    DateFound,
                    FALSE, (* DoWeForceSchedule *)
                    FALSE, (* DoWeUseLateProfiles *)
                    DoWeContour,
                    FALSE, (* DoWeCreateVAssignments *)
                    Task^.Plan.Assignments,
                    TaskEndDate,
                    AllWorkDone); 
           (*<PRINT
           SetString(NoteString, "     task end date = ");
           TimeUtoS(TaskEndDate, s);
           ConcatLS(NoteString, s);
           PrintAString(NoteString);
           PRINT>*)
       END;

END FindEarliestStartForEffortSplit;





(* -- FindCpmEarliestStartDate ---- 
       This is a version of FindEarliestStartDate specifically for use
       by cpmactivate. It does the following:

       - For non effort-split tasks: calls FindEarliestStartDate with
          AllowOverbookings = TRUE;
       - For effort-split tasks: calls FindEarliestStartForEffortSplit
          with AllowOverbookings = TRUE and
          DoWeContour = FALSE.
*)





PROCEDURE FindCpmEarliestStartDate (Task          : ATaskPtr;
                                    StartSearchAt : ADate;
                                    EndSearchAt   : ADate;
                                VAR FoundADate    : BOOLEAN;
                                VAR DateFound     : ADate);
VAR
    TaskEndDate : ADate;
    Dummy       : BOOLEAN;
BEGIN
    IF (Task^.DurationMethod = EffortDriven) AND
       (Task^.SplittingRule = Split) AND
       (NOT TaskUsesNoEmployableResources(Task)) THEN

       FindEarliestStartForEffortSplit (Task, StartSearchAt, EndSearchAt,
                                            TRUE (*AllowOverbookings*),
                                            FALSE (*DoWeContour*), 
                                            FALSE, (*DoWeComputeTaskEndDate*)
                                            FoundADate,
                                            DateFound, 
                                            TaskEndDate,
                                            Dummy (* for AllWorkDone *));
    ELSE (* Normal case, all except effort-split tasks. *)
       FindEarliestStartDate (Task,StartSearchAt, EndSearchAt,
                              TRUE (*AllowOverbookings*), FoundADate,
                              DateFound, TaskEndDate,
                              Dummy (* for TaskIsInfeasible*));
    END;
END FindCpmEarliestStartDate;

(*------CheckStartDateFeasibility-------------------------(exported)-------

    Determines whether or not a candidate start date is feasible
    (i.e., the required effort or duration can be accumulated, 
    without running into a vacation or resource violation, if the
    task starts then). Also returns the resulting task end date if
    the date is feasible.
    
    For all task types except effort-driven split:

      For each resource:
      Starting at CandidateStartDate, pass through availability cells,
      stopping when either (1) enough duration has been accumulated
      by the resource or (2) a violation has been found.

      As soon as some violation (if any) has been found, do not process
      any remaining assignments, and return the violation date via
      ViolationDate.

    For effort-driven split tasks (i.e., substitutable resources):
       THIS PROCEDURE DOES NOT HANDLE THEM. USE CheckIfTaskFitsAtDate instead.
       Any date with at least
       one resource available in any amount > 0 
       is feasible (because we now allow these
       tasks to be split around other tasks, and we allow contouring).
       For these tasks, we simply call FindStartDateForEffortSplitTask
       with a single-point interval (namely, the date we are testing),
       and MaxEndDate = MaxDate; and then check if the value of
       FoundADate is TRUE or not.



*)

PROCEDURE CheckStartDateFeasibility(Task           : ATaskPtr;
                                    Assignments    : AnAssignmentArray;
                                    NumAssignments : CARDINAL;
                                    CandidateStartDate : ADate;
                                    DoWeAllowOverbookings  : BOOLEAN;
                                VAR DateIsGood         : BOOLEAN;  
                                VAR TaskEndDate        : ADate;
                                VAR FirstViolationDate : ADate);
VAR

    LevelledResourceCount, i : CARDINAL;
    ResourceLevelRequired    : REAL;
    ResourceViolationDate, ResourceEndDate    : ADate;
    ResourceDurationRequired : ADuration;
    Resource                 : AResourcePointer;
    DurationMethod           : ADurationMethod;
    SplittingRule            : ASplittingRule;
    DoWeAllowVacations, DoWeCountVacations, DateIsGoodForResource, 
      DoWeIgnoreResourceLevels     : BOOLEAN;

BEGIN
    SplittingRule := Task^.SplittingRule;
    DurationMethod := Task^.DurationMethod;
    DoWeAllowVacations := (SplittingRule = Split);
    DoWeCountVacations := (DurationMethod = DurationDriven);

    (*<PRINT
     SetString(NoteString, "    Task type: ");
     PrintAString(NoteString);
     IF (DurationMethod = DurationDriven) THEN
     SetString(NoteString, "      duration-driven");
     ELSIF (DurationMethod = AssignmentDriven) THEN
     SetString(NoteString, "      assignment-driven");
     ELSE 
     SetString(NoteString, "      effort-driven");
     END;
     PrintAString(NoteString);
     IF (SplittingRule = Split) THEN
     SetString(NoteString, "      split");
     ELSE
     SetString(NoteString, "      delay");
     END;
     PrintAString(NoteString);
    PRINT>*)


    (*<PRINT
    SetString(NoteString,"      **Check candidate date ");
    TimeUtoS(CandidateStartDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"        allow overbookings = ");
    IF DoWeAllowOverbookings THEN ConcatS(NoteString, "TRUE");
    ELSE ConcatS(NoteString, "FALSE");
    END;
    PrintAString(NoteString);
    PRINT>*)

    LevelledResourceCount := 0;
    TaskEndDate := CandidateStartDate; (* initialize *)

    FOR i := 0 TO (NumAssignments - 1) DO
        Resource     := Assignments^[i].Resource;
        IF (Resource^.Type <> AccountingOnly) THEN
            (* we don't consider or touch non-employable resources in levelling *)
            IF (Resource^.LevelThisResource) THEN
                INC(LevelledResourceCount);
                IF LevelledResourceCount > MaxLevellableResourcesPerTask THEN
                    IssueWarning(TooManyResources, Task);                    
                    INCL(Task^.TaskStatusSet, NeedsRecalculate);
                END;            
            END;
  
            (* get level and duration required: *)
            ResourceLevelRequired := 
                FLOAT( Assignments^[i].MaxRatePercent);
  
            IF (DurationMethod = DurationDriven) THEN 
                ResourceDurationRequired := Task^.duration;            
                (* note: the above is correct since cpm never schedules
                    any spent effort on duration-driven tasks! *)
            ELSIF (DurationMethod = EffortDriven) THEN
                ResourceDurationRequired := ToGoDurationOfEffortDrivenTask(Task);
            ELSE (* task is assignment driven *)
                ResourceDurationRequired := 
                     DurationOf(Assignments^[i].MaxRatePercent, 
                                Assignments^[i].YetToGoQuantity);
            END;
  
  
            (* check the date wrt this resource: *)
            IF (ResourceDurationRequired = 0) 
                            OR 
               ((DoWeAllowVacations) AND (ResourceLevelRequired = Zero)) THEN
                 DateIsGoodForResource := TRUE;
                 ResourceEndDate      := CandidateStartDate + ResourceDurationRequired;
                 (*<PRINT
                  SetString(NoteString, "no need to check date; vacuous constraints");
                  PrintAString(NoteString);
                 PRINT>*)
            ELSE
                IF (DoWeAllowOverbookings) OR NOT (Resource^.LevelThisResource) THEN
                    (*<PRINT
                     SetString(NoteString, "     IgnoreResourceLevels: TRUE");
                     PrintAString(NoteString);
                    PRINT>*)
                    DoWeIgnoreResourceLevels := TRUE;
                ELSE
                    (*<PRINT
                     SetString(NoteString, "     IgnoreResourceLevels: FALSE");
                     PrintAString(NoteString);
                    PRINT>*)
                    DoWeIgnoreResourceLevels := FALSE;
                END;
                CheckResourceDuration(Resource,
                                      CandidateStartDate,
                                      ResourceLevelRequired,
                                      ResourceDurationRequired,
                                      DoWeAllowVacations,
                                      DoWeCountVacations,
                                      DoWeIgnoreResourceLevels,
                                      DateIsGoodForResource,
                                      ResourceEndDate,
                                      ResourceViolationDate);
            END; 
            IF NOT DateIsGoodForResource THEN
                FirstViolationDate := ResourceViolationDate;
                DateIsGood := FALSE;
                (*<PRINT
                SetString(NoteString, " date not feasible: violation = ");
                TimeUtoS(FirstViolationDate,s);
                ConcatLS(NoteString, s);
                PrintAString(NoteString);
                SetString(NoteString, " resource w violation = ");
                ConcatLS(NoteString, Resource^.Name);
                PrintAString(NoteString);
                PRINT>*)
                RETURN;
            ELSE
                IF ResourceEndDate > TaskEndDate THEN
                    TaskEndDate := ResourceEndDate;
                END;
            END;
        END; (* employable resource *)
    END; (* end loop *)

    DateIsGood := TRUE; (* we passed through all resources successfully *)

    (*<DEBUG*)
    IF (DateIsGood) AND(Task^.DurationMethod = DurationDriven) THEN
        IF (TaskEndDate <> CandidateStartDate + Task^.duration) THEN        
            SendErrorMsg("Check startdate feasibility: wrong task end date");
        END;
    END;
    (*DEBUG>*)

END CheckStartDateFeasibility;





(*------FindMaxOfFirstDatesAvailable------------------(local)-------------

    Returns, via FoundADate, the maximum, over all resources required 
    by Task, of the first date in the interval [StartSearchDate, 
    EndSearchDate] such that the resource is available. If
    "AllowVacations" is false, additionally requires resource to not
    be on vacation. 

    For FoundADate to be returned as TRUE, EVERY resource must have
    had some date withing the specified interval for which it is
    available; otherwise it is returned as FALSE.

    (Note that not all the resources are necessarily available    
    on the day returned, but the day returned is at least a lower bound
    on the earliest such date.)
*)

PROCEDURE FindMaxOfFirstDatesAvailable(Assignments       : AnAssignmentArray;
                                       NumAssignments    : CARDINAL;
                                       StartSearchDate   : ADate;
                                       EndSearchDate     : ADate;
                                       DoWeAllowVacations    : BOOLEAN;
                                       DoWeAllowOverbookings : BOOLEAN;
                                   VAR FoundADate        : BOOLEAN;
                                   VAR DateFound         : ADate);
                                   
VAR
    i                    : CARDINAL;
    AmountWeUse          : LONGINT;
    ResourceWeUse        : AResourcePointer;
    MaximumDate          : ADate;
    DoWeIgnoreResourceLevels : BOOLEAN;
    FoundResourceDate    : BOOLEAN;
    (*<PRINT
    s   : ARRAY [0..80] OF CHAR;
    PRINT>*)

BEGIN

    (*<PRINT
    SetString(NoteString,"        MaxFirstDatesAvail: between ");
    TimeUtoS(StartSearchDate,s);
    ConcatLS(NoteString,s);    PrintAString(NoteString);    SetString(NoteString,"             and ");
    TimeUtoS(EndSearchDate,s);    ConcatLS(NoteString,s);    PrintAString(NoteString);
    SetString(NoteString, "             with allow overbookings = ");
    IF DoWeAllowOverbookings THEN ConcatS(NoteString, "TRUE");
    ELSE ConcatS(NoteString, "FALSE"); END; PrintAString(NoteString);
    SetString(NoteString, "             and allow vacations = ");
    IF DoWeAllowVacations THEN ConcatS(NoteString, "TRUE");
    ELSE ConcatS(NoteString, "FALSE"); END; PrintAString(NoteString);
    PRINT>*)

    (*<DEBUG
    IF NumAssignments = 0 THEN
        SendErrorMsg("MaxOfFirstDatesAvailable: task has no resources");
        FatalError();
    END;
    DEBUG>*)

    MaximumDate    := StartSearchDate; (* initialization - it can grow higher *)

    (*<PRINT
    SetString(NoteString,  "          max date so far:");  TimeUtoS(MaximumDate,s);
    ConcatLS(NoteString,s);  PrintAString(NoteString);
    PRINT>*)

    FOR i := 0 TO (NumAssignments - 1) DO
        ResourceWeUse := Assignments^[i].Resource;
        (*<PRINT
        SetString(NoteString, "             checking resource ");  ConcatLS(NoteString, ResourceWeUse^.Name);
        PrintAString(NoteString);
        PRINT>*)

        IF (ResourceWeUse^.Type <> AccountingOnly) THEN
            (* we don't consider or touch non-employable resources in levelling *)
            AmountWeUse  := VAL(LONGINT, Assignments^[i].MaxRatePercent);
            IF (ResourceWeUse^.LevelThisResource) AND NOT (DoWeAllowOverbookings) THEN
                DoWeIgnoreResourceLevels := FALSE;
            ELSE
                DoWeIgnoreResourceLevels := TRUE;
            END;
 
            (* reset MaximumDate to a date on or after current value: *)
            FindFirstDateHaveResourceAmount(ResourceWeUse,                    
                                            AmountWeUse,
                                            MaximumDate,
                                            EndSearchDate,
                                            DoWeAllowVacations,
                                            DoWeIgnoreResourceLevels,
                                            FALSE (* DoWeUseLateAvailabilities*),
                                            FoundResourceDate,
                                            MaximumDate);    
            (*<PRINT
            IF FoundResourceDate THEN
                SetString(NoteString,  "         new max date = ");  
                TimeUtoS(MaximumDate,s);
                ConcatLS(NoteString,s);  PrintAString(NoteString);
            END;
            PRINT>*)

            IF NOT (FoundResourceDate) THEN
                FoundADate := FALSE;
                (*<PRINT
                SetString(NoteString,"   no date for resource in restricted interval");
                PrintAString(NoteString);
                PRINT>*)
                RETURN;
            END;
        END; (* employable resource *)
    END; (* end loop *)

    (* we made it through all resources: *)
    FoundADate := TRUE;
    DateFound := MaximumDate;

    (*<PRINT
    SetString(NoteString,"        MaxFirstDatesAvail found date ");  TimeUtoS(DateFound,s);    
    ConcatLS(NoteString,s);  PrintAString(NoteString);
    PRINT>*)
END FindMaxOfFirstDatesAvailable;

(*------FindMaxOfFirstDatesAvailOrOnVacation  ---------------------

   Like MaxOfFirstDatesAvailable, but the condition is relaxed to say
   the resource is either available or on vacation.

*)

PROCEDURE FindMaxOfFirstDatesAvailOrOnVacation(Assignments       : AnAssignmentArray;
                                               NumAssignments    : CARDINAL;
                                               StartSearchDate   : ADate;
                                               EndSearchDate     : ADate;
                                           VAR FoundADate        : BOOLEAN;
                                           VAR DateFound         : ADate);
                                   
VAR
    i                    : CARDINAL;
    AmountWeUse          : LONGINT;
    ResourceWeUse        : AResourcePointer;
    MaximumDate          : ADate;
    DoWeIgnoreResourceLevels : BOOLEAN;
    FoundResourceDate    : BOOLEAN;
    (*<PRINT
    s   : ARRAY [0..80] OF CHAR;
    PRINT>*)

BEGIN

    (*<PRINT
    SetString(NoteString,"        MaxFirstDatesAvailOrOnVacation: between ");
    TimeUtoS(StartSearchDate,s);
    ConcatLS(NoteString,s);    PrintAString(NoteString);    SetString(NoteString,"             and ");
    TimeUtoS(EndSearchDate,s);    ConcatLS(NoteString,s);    PrintAString(NoteString);
    PRINT>*)

    (*<DEBUG
    IF NumAssignments = 0 THEN
        SendErrorMsg("MaxOfFirstDatesAvailable: task has no resources");
        FatalError();
    END;
    DEBUG>*)

    MaximumDate    := StartSearchDate; (* initialization - it can grow higher *)

    (*<PRINT
    SetString(NoteString,  "          max date so far:");  TimeUtoS(MaximumDate,s);
    ConcatLS(NoteString,s);  PrintAString(NoteString);
    PRINT>*)

    FOR i := 0 TO (NumAssignments - 1) DO
        ResourceWeUse := Assignments^[i].Resource;
        (*<PRINT
        SetString(NoteString, "             checking resource ");  ConcatLS(NoteString, ResourceWeUse^.Name);
        PrintAString(NoteString);
        PRINT>*)

        IF (ResourceWeUse^.Type <> AccountingOnly) THEN
            (* we don't consider or touch non-employable resources in levelling *)
            AmountWeUse  := VAL(LONGINT, Assignments^[i].MaxRatePercent);
            IF (ResourceWeUse^.LevelThisResource) THEN
                DoWeIgnoreResourceLevels := FALSE;
            ELSE
                DoWeIgnoreResourceLevels := TRUE;
            END;
 
            (* reset MaximumDate to a date on or after current value: *)
            FindFirstDateResOnVacationOrAvailable(ResourceWeUse,                    
                                                  AmountWeUse,
                                                  MaximumDate,
                                                  EndSearchDate,
                                                  FALSE (* use late avails *),
                                                  FoundResourceDate,
                                                  MaximumDate);    
            (*<PRINT
            IF FoundResourceDate THEN
                SetString(NoteString,  "         new max date = ");  
                TimeUtoS(MaximumDate,s);
                ConcatLS(NoteString,s);  PrintAString(NoteString);
            END;
            PRINT>*)

            IF NOT (FoundResourceDate) THEN
                FoundADate := FALSE;
                (*<PRINT
                SetString(NoteString,"   no date for resource in restricted interval");
                PrintAString(NoteString);
                PRINT>*)
                RETURN;
            END;
        END; (* employable resource *)
    END; (* end loop *)

    (* we made it through all resources: *)
    FoundADate := TRUE;
    DateFound := MaximumDate;

    (*<PRINT
    SetString(NoteString,"        MaxFirstDatesAvail found date ");  TimeUtoS(DateFound,s);    
    ConcatLS(NoteString,s);  PrintAString(NoteString);
    PRINT>*)
END FindMaxOfFirstDatesAvailOrOnVacation;




(*------FindFirstDateAllResourcesAreAvailable-----------------(local)--------------

    Returns the first date in the interval [StartSearchDate, EndSearchDate]
    which all resources required by Task are available
    in sufficient amounts. If there is no such date, sets FoundADate 
    to FALSE.

    Note: if "AllowVacations" is FALSE, then additionally NO resource
          can be on vacation on the day returned; otherwise, SOME
          resource(s) can be on vacation, but at least ONE resource
          must not be. 
*)          

PROCEDURE FindFirstDateAllResourcesAreAvailable (Assignments       : AnAssignmentArray;
                                                 NumAssignments    : CARDINAL;
                                                 StartSearchDate   : ADate;
                                                 EndSearchDate     : ADate;
                                                 DoWeAllowVacations    : BOOLEAN;
                                                 DoWeAllowOverbookings : BOOLEAN;
                                             VAR FoundADate        : BOOLEAN;
                                             VAR DateFound         : ADate);



VAR
    OnOrAfter          : ADate;
    PotentialDate      : ADate;
    FoundPotentialDate : BOOLEAN;
    (*<PRINT
    s   : ARRAY [0..80] OF CHAR;
    PRINT>*)

BEGIN

    (*<PRINT
    SetString(NoteString,"    FirstDateAllResAvail ");
    SetString(NoteString,"          between ");
    TimeUtoS(StartSearchDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"          and ");
    TimeUtoS(EndSearchDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    PRINT>*)

    FoundADate := FALSE;
    OnOrAfter := StartSearchDate;
    
    LOOP
        FindMaxOfFirstDatesAvailable(Assignments,
                                     NumAssignments,
                                     OnOrAfter,
                                     EndSearchDate,
                                     DoWeAllowVacations,
                                     DoWeAllowOverbookings,
                                     FoundPotentialDate,
                                     PotentialDate);
             (* If FoundPotentialDate is TRUE, then PotentialDate
                now holds the max over all resources of
                the first date the resource is available 
                between OnOrAfter and EndSearchDate. *)
        
        IF NOT (FoundPotentialDate) THEN
            (*<PRINT
            SetString(NoteString, " interval no good");
            PrintAString(NoteString);
            PRINT>*)
            (* There is no potential start date for the task within the
               given interval, since some resource was never available
               within the interval. *)
            EXIT; 
        END;                
            
        IF AllResourcesAreAvailable(Assignments,
                                    NumAssignments,
                                    PotentialDate,
                                    DoWeAllowVacations,
                                    DoWeAllowOverbookings,
                                    FALSE (*DoWeUseLateAvailabilities*)) THEN
            (* We've found the first date in the interval for which
               all resources are available. *)
            FoundADate := TRUE;
            DateFound := PotentialDate;
            EXIT;    
        END;    

        (* Some resource is not available on PotentialDate, 
           so try again from PotentialDate + 1 *)
        IF (PotentialDate < MaxDate - 1) 
            AND (PotentialDate <= EndSearchDate - 1) THEN
            OnOrAfter := PotentialDate + 1;
        ELSE
            EXIT;
        END;
    END; (* end loop *)

    (*<PRINT
    IF FoundADate THEN
        SetString(NoteString,"        first date all avail-->");
        TimeUtoS(PotentialDate,s);
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
    ELSE
        SetString(NoteString,"        first date all avail: none in interval");
        PrintAString(NoteString);
    END
    PRINT>*)

END FindFirstDateAllResourcesAreAvailable;



PROCEDURE FindPotentialStartDateForSplitTask (Assignments           : AnAssignmentArray;
                                              NumAssignments        : CARDINAL;
                                              DurationMethod        : ADurationMethod;
                                              StartSearchDate       : ADate;
                                              EndSearchDate         : ADate;
                                              DoWeAllowOverbookings : BOOLEAN;
                                          VAR FoundADate            : BOOLEAN;
                                          VAR DateFound             : ADate);



VAR
    OnOrAfter          : ADate;
    PotentialDate      : ADate;
    FoundPotentialDate : BOOLEAN;
    (*<PRINT
    s   : ARRAY [0..80] OF CHAR;
    PRINT>*)

BEGIN

    (*<PRINT
    SetString(NoteString,"    Find potential date for split task ");
    PrintAString(NoteString);
    SetString(NoteString,"          between ");
    TimeUtoS(StartSearchDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"          and ");
    TimeUtoS(EndSearchDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    PRINT>*)

    FoundADate := FALSE;

        (* dispense with allow-overbookings case - just need the
           first date that some resource is not on vacation: *)
    IF DoWeAllowOverbookings THEN
        FindFirstDateSomeResourceNotOnVacation(Assignments,    
                                               NumAssignments,                 
                                               StartSearchDate,
                                               EndSearchDate,
                                               DateFound,
                                               FoundADate);
        (*<PRINT
        SetString(NoteString, "FindPotDateForSplit: pot date --> ");
        TimeUtoS(DateFound, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)
        RETURN;
    END;    


    OnOrAfter := StartSearchDate;
    LOOP
        FindMaxOfFirstDatesAvailOrOnVacation(Assignments,
                                             NumAssignments,
                                             OnOrAfter,
                                             EndSearchDate,
                                             FoundPotentialDate,
                                             PotentialDate);
             (* If FoundPotentialDate is TRUE, then PotentialDate
                now holds the max over all resources of
                the first date the resource is available or on vac
                between OnOrAfter and EndSearchDate. *)
        
        IF NOT (FoundPotentialDate) THEN
            (*<PRINT
            SetString(NoteString, " interval no good");
            PrintAString(NoteString);
            PRINT>*)
            (* There is no potential start date for the task within the
               given interval, since some resource was never available
               within the interval. *)
            EXIT; 
        END;                
            
        IF ((AllResourcesOnVacationOrAvailable
                           (Assignments,
                            NumAssignments,
                            PotentialDate,
                            FALSE (*DoWeUseLateAvailabilities*))) AND
            (SomeResourceNotOnVacation
                           (Assignments,
                            NumAssignments,
                            PotentialDate)))
        THEN
            FoundADate := TRUE;
            DateFound := PotentialDate;
            EXIT;    
        END;    

        (* Some resource is not available on PotentialDate, 
           so try again from PotentialDate + 1 *)
        IF (PotentialDate < MaxDate - 1) 
            AND (PotentialDate <= EndSearchDate - 1) THEN
            OnOrAfter := PotentialDate + 1;
        ELSE
            EXIT;
        END;
    END; (* end loop *)

    (*<PRINT
    IF FoundADate THEN
        SetString(NoteString,"        potential date -->");
        TimeUtoS(PotentialDate,s);
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
    ELSE
        SetString(NoteString,"        potentialdate: none in interval");
        PrintAString(NoteString);
    END
    PRINT>*)

END FindPotentialStartDateForSplitTask;


(*--------------------- CheckIfTaskFitsAtDate ----------------------------

  Returns DateIsGood as TRUE iff Date is a feasible start date for Task.
  If DoWeComputeEndDate is TRUE, also computes the resulting task end date
  (provided that DateIsGood turns out to be true).

*)

PROCEDURE CheckIfTaskFitsAtDate (Task              : ATaskPtr;
                                 Date              : ADate;
                             VAR DateIsGood        : BOOLEAN;
                             VAR TaskEndDate       : ADate;
                             VAR TaskIsInfeasible  : BOOLEAN);
VAR
    DateFound : ADate;
BEGIN
    FindEarliestStartDate(Task, 
                          Date,   (* StartSearchAt *)
                          Date,   (* EndSearchAt *)
                          FALSE,  (* DoWeAllowOverbookings *)
                          DateIsGood,  (* out *)
                          DateFound,   (* out *)
                          TaskEndDate  (* out *),
                          TaskIsInfeasible (* out *));

    (*<DEBUG*)
    IF (DateIsGood) AND (DateFound <> Date) THEN
        SendErrorMsg("TaskFitsAtDate: wrong start date");
    END;
    (*DEBUG>*)

END CheckIfTaskFitsAtDate;

(* ------- SomeResourceNotOnVacation ------------------------------
   Returns TRUE if some employable resource is not on vacation
   on Date. Otherwise returns FALSE. (Assumes the task has
   employable resources.)
*)

PROCEDURE SomeResourceNotOnVacation(Assignments    : AnAssignmentArray;
                                    NumAssignments : CARDINAL;
                                    Date           : ADate) : BOOLEAN;

VAR
    Resource               : AResourcePointer;
    AmountAvail            : LONGINT;
    i                      : CARDINAL;
    DateIsVacation         : BOOLEAN;
    (*<PRINT
    s   : ARRAY [0..80] OF CHAR;
    PRINT>*)
BEGIN
    (*<PRINT
    SetString(NoteString, "SomeResNotOnVac for date "); 
    TimeUtoS(Date, s); ConcatLS(NoteString, s); PrintAString(NoteString);
    PRINT>*)

    FOR i := 0 TO NumAssignments - 1 DO
        Resource := Assignments^[i].Resource;
        IF (Resource^.Type <> AccountingOnly) THEN
            (*<PRINT
            SetString(NoteString, "checking res ");  
            ConcatLS(NoteString, Resource^.Name);
            PrintAString(NoteString);
            PRINT>*)
            Resource := Assignments^[i].Resource;
            CheckResourceOnDate(Resource, Date, FALSE (* late avails *),
                                AmountAvail, DateIsVacation);
            IF NOT (DateIsVacation) THEN
                (*<PRINT
                PrintResidueAvailability (Resource^.ResidueAvailProfile);
                SetString(NoteString, "Date is not vacation");
                PrintAString(NoteString);        
                PRINT>*)                
                RETURN TRUE;    
            END;
        END;
    END;
    RETURN FALSE;
END SomeResourceNotOnVacation;


PROCEDURE FindFirstDateSomeResourceNotOnVacation (Assignments    : AnAssignmentArray;
                                                  NumAssignments : CARDINAL;
                                                  StartSearchAt  : ADate;
                                                  EndSearchAt    : ADate;
                                              VAR DateFound      : ADate;
                                              VAR FoundADate     : BOOLEAN);
VAR
    i : CARDINAL;
    Resource          : AResourcePointer;
    ResourceDate      : ADate;
    FoundResourceDate : BOOLEAN;
BEGIN
    FoundADate := FALSE;
    DateFound  := MaxDate;
    FOR i := 0 TO NumAssignments - 1 DO
        FoundResourceDate := FALSE;
        Resource := Assignments^[i].Resource;
        IF (Resource^.Type <> AccountingOnly) THEN
            FindFirstDateResourceNotOnVacation(Resource,    
                                               StartSearchAt,
                                               EndSearchAt,
                                               ResourceDate,
                                               FoundResourceDate);
            (*<PRINT
            SetString(NoteString, "first date resource " );
            ConcatLS(NoteString, Resource^.Name);
            ConcatS(NoteString, " not on vac: ");
            TimeUtoS(ResourceDate, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            PRINT>*)        

            IF (FoundResourceDate) AND (ResourceDate < DateFound) THEN
                FoundADate := TRUE;
                DateFound  := ResourceDate;
            END;
        END;
    END;
END FindFirstDateSomeResourceNotOnVacation;



BEGIN
END ResStartDates.


OLD MODIFICATION HISTORY:

    Feb 23, 89 - JES -created. See comment with this date in .def part.
    Jun 12, 89 - JES -added some print statements useful for debugging.
    Jul 12, 89 - JES -fixed bug in TaskUsesNoLevellableResources where it
                      was returning without releasing the assignment handle
                      in the case that the resource count is zero. (Why this 
                      bug never caused any problems is a mystery..)
    Sep 25, 89 - JES -just as in Sep-21-89 change to Tlcpm by AJL:
                      added some range checking tests to the calculation
                      of EdgeDates so that a negative Delta wouldn't push
                      a date earlier than the start of time (in procedures
                      LatestAntecedantEndDate and EarliestDescendantStartDate).
    30-Mar-90    RSC  Made Timeu to Timei/TimeForm conversions.
    11-Apr-90    KKC  Replace all direct calculations on ADate and Duration
                      by calls to FindDuration, SubtractWorkingTime and
                      AddWorkingTime.
    18-Jul-90    JES  Added parameter "AllowVacations" to procedures:
                              FirstDateAllResourcesAreAvailable
                              MaxOfFirstDatesAvailable
                              AllResourcesAreAvailable

                      (Note: this parameter will also filter down
                      to lower level procedures in the ZResAvail
                      module that are called by the above procedures;
                      see the ResAvail module.)  

                      The parameter is set in procedures
                      EarliestStartDate and
                      CheckStartDateFeasibility (which call, directly or
                      indirectly, the above procedures).
                      It is TRUE if the task is of type split, otherwise
                      it is FALSE.

                      The procedure AllResourcesAreAvailable now returns
                      TRUE if all resources have the required amounts
                      available on the date in question, and either
                      (i) AllowVacations is FALSE and no resource is on                        
                      vacation on the date, or (ii) AllowVacations is 
                      TRUE and at least one resource is not on vacation
                      on the date. Similar considerations apply to                       
                      the procedure FirstDateAllResourcesAreAvailable  
                      (which calls AllResourcesAreAvailable).

                      In MaxOfFirstDatesAvailable, the dates considered
                      require resources not to be on vacation if                                                   
                      AllowVacations is FALSE. (There is no requirement
                      regarding at least one resource to not be on                        
                      vacation if AllowVacations is TRUE, since resources
                      are considered individually.)  


                      IN GENERAL, CHANGED EarliestStartDate and all
                      subservient procedures to deal with vacations.
                      Also changed TaskFitsAtDate to use the new
                      procedure CheckStartDateFeasibility.

                      (Note - still not changed for multiple calendars:
                      LatestStartDate, LatestContinuousFitDate. These
                      have to do with ALAP tasks and slack calculations,
                      respectively.)

    Sep-04-90  JES    Procedure "EarliestStartDate" now uses the following
                      three dates as lower bounds: (1) the AsOfDate, if
                      MoveFutureTasks is on; (2) the task's LatestAntecedant
                      EndDate (as before); (3) the task's cpm start date
                      (as before); and (4) the max, over all resource
                      assignments, of the EndOfSpentDate. (This is in
                      support of scheduling only the remaining - i.e.
                      as yet not done - portion of the task, if the user
                      has entered some actual effort on the task. Such
                      effort will have been scheduled in cpm, if the
                      switch FreezeStartedTasks was not set.)
    Sep-06-90  JES    Added boolean parameters AllowOverbookings and
                      UseLowerBounds to procedure EarliestStartDate
                      (and lower level procedures it calls).
                      (So that cpm can use the procedure with overbookings
                      allowed and no automatic lower bounds except the
                      one input.)
    Sep 12, 90 JES    Removed parameter "UseLowerBounds" from procedure
                      EarliestStartDate, and changed name of parameter
                      "Day" to "StartSearchAt". Any lower bounds to be
                      used will be incorporated into "StartSearchAt"
                      by the caller. (I.e., the procedure no longer
                      automatically incorporates latest antecedant end
                      date, as of date, or max end of actual dates.)

    Sept 17, 90  JES  Added support for "resource-driven split" tasks
                       to procedure CheckStartDateFeasibility.
    Sept 18, 90  JES  Resource-driven split tasks will now allow splitting
                        around other tasks. Thus, any date (satisfying
                        the lower and upper bounds) such that at least
                        one resource can work at the required level is
                        a feasible start date. CheckStartDateFeasibility
                        and EarliestStartDate have been modified accordingly.
    Sept 25, 90  JES  EarliestStartDate was corrected to return 
                      StartSearchAt if the task uses no levellable
                      resources.
    Oct 2,   90  JES  Modified procedures to take non-levellable resources
                      into account (i.e., in all feasibility checks, their
                      vacations but not their resource levels are honored).
    Oct 5,  90  JES   Incorporated an "upper bound" parameter into
                      procedure EarliestStartDate. This will typically
                      take into account the "Day" variable and the
                      task's upper bound on the start date (i.e., the
                      late total start if levelling within slack).
                      This avoids having the procedure calculate way out 
                      in time, only to have the caller decide that the
                      result is too high and we have to bump and start
                      over. Also added a VAR parameter "bounds are 
                      feasible". This is returned as true if the procedure
                      succeeded in finding a start date between the lower
                      and upper bound; otherwise, it is returned as false,
                      and no valid start date is returned.
    Oct 29,  90   JES Fixed bugs in CheckCandidateStartDate.

    Nov  2,  90   JES Changed name "ResourceDriven" to "EffortDriven";
                      changed MAXDATE to import MaxDate from Timei.
    Nov  8,  90   JES Added support for contouring for effort-split tasks.

    Nov 12,  90   JES (1) Made the "EndSearchAt" parameter filter down
                      to procedures subservient to FindEarliestStartDate.
                      (2) Changed CheckStartDateFeasibility so that 
                      vacations must be honored even for non-levellable 
                      resources.
                      (3) Removed the call to ProcessResource from
                      CheckStartDateFeasibility, and substituted the
                      new specific procedure CheckResourceDuration.
    Nov 13, 90    JES Moved the procedure CheckResourceDuration into
                        ResUtilities.
    Nov 15, 90    JES Further work on FindEarliestStartForEffortSplit.

    Nov 19, 90    JES Added support for Honor-Days-Off flag to FindEarliest
                   StartDate and subsidiaries. Also removed non-employable
                   resources from all consideration.

    Nov 21, 90 AJL   -Added release of the AssignmentsHandle to 
                      FindEarliestStartForEffortSplit.
                     -Cosmetic changes to indentation.
                     -Fixed a bug in which LevelledResourceCount was
                      unitialized.
                     -Changed the warning issued if too many resources from
                      CannotSchedule to TooManyResources.
                     -Modified AllResourcesAreAvailable so that it will
                      not return FALSE unless there is at least one employable
                      resource that is not available.  This solves a 
                      problem in which there are no resources who are not
                      on vacation--because there are no employable resources.
                     -Modified FindEarliestStartDate so that it doesn't try
                      to search for dates past MaxDate.
                     -Removed an unused import of the ResCal module.


DOCUMENTATION

1/10/91 JES         
         For now, we require a single start date for all assignments
         in the case of an assignment driven delay task. Later we
         may relax this constraint. For instance, we may allow a date
         such that the longest assignment starts there, and all other
         assignments must fit between the start and end of the longest
         assignment. Or, we may have a single end date (i.e., all 
         assignments end on the same date, but may start at different
         dates) instead of a single start date. There are all manner
         of possibilities for user-choices in future releases. 
         JES 1/10/91
    Nov 26, 90 JES   -Fixed the infinite-loop bug found above by AJL in
                      the procedure FindFirstDateAllResourcesAreAvailable.
                     -Made FindEarliestStartForEffortSplit call 
                      CreateSubstitutableResourceAssignments with the
                      correct value for the parameter "Contour" (rather
                      than just inlining "TRUE").
                     -In procedure FindEarliestStartDate:
                         - removed the line that erroneously reset the input
                            parameter EndSearchAt;
                         - changed the test for FirstViolationDate < MaxDate
                            to FirstViolationDate < MaxDate - 1.
                     -In procedure FindFirstDateAllResourcesAreAvailable,
                      added boundary test for MaxDate in next trial date.
    Nov 27, 90 JES   -Added some print statements for debugging.
    Nov 28, 90 JES   -Fixed some comments and changed all calls to
                      TaskUsesNoResources and TaskUsesNoLevellableResources
                      to TaskUsesNoEmployableResources.
                     -Fixed bug in FindMaxOfFirstDatesAvailable where
                      FoundADate was never being set to TRUE.
    Nov 29, 90 JES   -Changed MaxResourcesPerTask to the new
                        MaxLevellableResourcesPerTask.
                     -Fixed some indentations in debugging printouts.
    Nov 30 11:40 a.m. 
               JES   -Fixed bug in FindEarliestStartForEffortSplit; changed
                      condition "IF Contour" to "IF Contour AND NOT
                      AllowOverbookings" before the call to FindFirstDate
                      LevelIsAboveZero. Since if we are allowing overbookings,
                      resource level should be ignored.
    Nov 30 6:30 p.m.
               JES   -Added parameter MaxEndDate to procedure 
                      FindStartForEffortDrivenSplit, so that it can
                      be called by the new procedure FindCpmEarliestStartDate.
                      This is a new procedure that calls FindEarliestStart
                      Date or FindStartForEffortDrivenSplit, with the
                      correct parameters for cpm's purposes.
    Dec 11, 90   JES -Checked bounds before calling FOR loops.

    Dec 11, 90   JES -Optimized CheckStartDateFeasibility so it knows
                      that any date is feasible if  AllowOverbookings AND
                      (AllowVacations OR NOT Honor-Days-Off).

                      (not done yet: )
    Dec xx, 90  JES   Rewrote procedure FindLatestStartDate to support
                      calendars.
                      Changed FindEarliestStartDate so always returns
                      "StartSearchAt" for DurationDriven Split tasks.
                      (I.e., for these tasks, removes the constraint
                      that at least one resource must be available.) 
                      Also added TaskEndDate as an
                      out parameter to FindEarliestStartDate.
    Dec 21, 90  JES  -Moved all FindLatestStartDate procedures into
                      a ResLateDates.
                     -Moved AllResourcesAreAvailable into ResAvailability
                      so it can be called both from here and from ResLateDates.
                     -Optimized all procedures within FindEarliestStartDate
                      so they don't all lock and unlock the assignments
                      array (instead we keep it locked and pass it around).
                     -Changed definition of feasible start date for
                      assignment-driven delay tasks, namely: at least
                      one resource must be available (i.e., not on vacation
                      and available in the required amount), and all resources not
                      on vacation (previously "all resources") must be
                      available in the required amounts. This coincides
                      more with (a) reality and (b) the latest start date
                      policies.
    Dec 28, 90  JES  -Finished procedure FindPotentialDateForAsstSplitTask,
                       that was previously left as a stub.
    Jan 14, 91  JES - Modified calls to procedures in ResAvail to include
                        the new parameter DoWeUseLateAvailabilities.
    Jan 15, 91  JES - Modified FindEarliestStartDate to dispense with
                        summary tasks right away.
    Jan 21, 91  JES - Generalized TaskFitsAtDate 
                        to handle effort-driven split tasks.
    Jan 29, 91  JES - Fixed FindEarliestStartDate so handles tasks with
                        no employable resources correctly.
    Feb 11, 91  JES - Fixed bug #4077; the code for duration driven split
                        tasks was being surrounded by PRINT comments,
                        resulting in manifestation of the bug whenever
                        PRINT was toggled off.
    Feb 14, 91  JES - Removed MaxEndDate parameter from FindEarliestStart
                         DateForEffortSplit. The procedure returns 
                         TaskEndDate anyway, and the caller can compare
                         that result with whatever is necessary (e.g.,
                         LateTotalEndDate).
                    - Changed FindCpmEarliestStartDate so calls
                        FindStartDateForEffortSplit with "DoWeComputeEndDate"
                        set to FALSE (since we were just throwing out the
                        result anyway).
    Feb 14, 91 AJL  - Renamed EndOf ActualDate to EndOfSpentDate. 
    Feb 15, 91    JES - Renamed MaxEndOfActuals to MaxEndOfSpent.
    Feb 19, 91    JES - Changed FindEarliestStartDateForSplitTasks to
                        put requirements on the start date for a duration
                        driven task (previously there were none). Namely,
                        the interval [start date, start date + duration] must
                        be such that each resource, when not on vacation,
                        is available at the required rate. 
                      - Fixed bug in FindPotentialDateForAsstSplitTask
                        where FoundPotentialDate was being set to TRUE
                        precipitously.
                      - Removed unused import AStartStatus.
    Feb 21, 91    JES - Made FindEarliestStartDate cleaner by calling
                        FindEarliestStartDateForSplitTask only if
                        Honor-Days-Off is TRUE (and otherwise treating
                        split tasks as delay tasks), and removing all
                        references to Honor-Days-Off from within 
                        FindEarliestStartDateForSplitTask and subordinate
                        procedures.
    Feb 22, 91    JES - Removed the above fix since the initial
                        residue availabilities now already take
                        Honor-Days-Off into account.
    Feb 26, 91    JES - We now let the ActivateCandidates procedure deal
                        with infeasible (unschedulable) tasks, rather
                        than the EarliestStartDate procedures here.
    Mar  6, 91    JES - In setting returned value TaskEndDate in
                        FindEarliestStartDate, make sure we don't overrun
                        MaxDate. 
    Mar  7, 91    JES - In the above, set FoundADate to FALSE if the
                        start date would cause the task to overrun
                        MaxDate.
    Mar  8, 91    JES - In CheckStartDateFeasibility, sets ResourceEndDate
                        to Task^.duration (neglected to set this before)
                        in the case of vacuous constraints.
    Mar 14, 91    JES - added a print debugging statement for summary tasks.
    Mar 26, 91 JES  - Changed TimeUtoS's to TimeUtoS's in debugging printouts.
    Apr  3, 91 JES -  Use new name "ToGoDurationOfEffortDrivenTask"
                      (previously "ToGoDurationOfEffortDelayTask").
    Apr 15, 91 JES -  Removed some unused imports.
                   -  Call ErrorPhrase instead of FatalError if StartSearch
                       > EndSearch in FindEarliestStartDate.
    Apr 17, 91 JES -  In CheckStartDateFeasibility, in the case that
                       we don't have to call CheckResourceDuration,
                       we now set ResourceEndDate to CandidateStartDate +
                       ResourceDuration instead of CanditateStartDate +
                       Task^.duration. Also, the final block "IF NOT 
                       DateIsGoodForResource" was moved outward so that
                       it applies to both cases (i.e., whether 
                       CheckResourceDuration was called or not).
    Apr 19, 91 JES -  In TaskFitsAtDate, the DEBUG check for effort-split
                       tasks checked only "Date <> StartDate" and left
                       out "DateIsGood". (There is an error only if both
                       DateIsGood and Date <> StartDate.)
    Apr 26, 91 JES -  Changed TaskFitsAtDate to CheckIfTaskFitsAtDate, which
                       returns both DateIsGood and TaskEndDate (and not just
                       a BOOLEAN equivalent to DateIsGood). The procedure
                       simply calls FindEarliestStartDate with StartSearch =
                       EndSearch = the given date, and with DoWeAllowOverbookings
                       = FALSE. 
    May  3, 91 JES -  Changed FindEarliestStartDateForDelayTask so that, for
                        a milestone task (i.e., duration driven with 0
                        duration), we just look for the first date such that
                        no resources are on vacation (and ignore resource
                        availability). The rationale is that, since no
                        actual work has to be done, we don't care about the
                        level of resource availability; but we still require
                        the resource to be "present" (not on vacation) in
                        order to "check off" completion of the milestone.
                        (Note that for split milestones, there is no
                        requirement at all.)
    May  3, 91 JES -  Fixed logic bug in above fix.
    June 13, 91 JES - In trying again from violation + 1, in procedure
                        FindEarliestStartForSplitTask, changed the
                        condition "If FirstViolationDate < EndSearchAt - 1"
                        to        "If FirstViolationDate <=EndSearchAt - 1".
                        Otherwise, the date EndSearch was not getting tried.
                      Also, added this condition (previously lacking) to
                        the same point in the procedure FindEarliestStart
                        ForDelayTask.
    June 17, 91  JES - Added minor optimization to FindPotentialDateFor
                        DurationSplitTask.
    June 18, 91  JES - Wrote FindPotentialStartDateForSplitTask, to
                        replace both FindPotentialStartDateForDuration
                        SplitTask and FindPotentialStartDateForAsst
                        SplitTask. The assumption underlying the optimiza-
                        tions in these procedures was flawed, resulting
                        in good start dates erroneously being rejected.
    June 24, 91  JES - In FindPotentialStartDateForSplitTask, in the
                        AllowOverbookings case, removed condition that
                        some resource be on vacation if the task is
                        duration driven. Also fixed that case so that
                        it is setting DateFound correctly.
    June 25, 91  JES - FindEarliestStartForEffortSplit needs to pass
                        back the value of AllWorkDone, so that ResActiv.
                        ActivateCandidates knows whether or not the
                        task is infeasible. To support this, the VAR
                        parameter AllWorkDone has been added to 
                        FindEarliestStartForEffortSplit, and corresponding
                        VAR parameter TaskIsInfeasible to procedures
                        FindEarliestStartDateForSplitTask,
                        FindEarliestStartDate, and CheckIfTaskFitsAtDate.
    July 12, 91  JES - Turned off some the DEBUG checks.
    July 25, 91  AJL - In SomeResourceNotOnVacation and in
                       FindFirstDateSomeResourceNotOnVacation, check only
                       resources, not costs, which do not have vacations
                       or ResidualAvailabilities.
    Nov. 15, 91  AJL - When searching for task start dates, handle the
                       degenerate case of a task requiring no effort.
 
