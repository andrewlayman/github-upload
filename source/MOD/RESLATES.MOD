IMPLEMENTATION MODULE ResLates;
(*V2=PRINT WITH debugging printouts. *)
(*V9=CASES WITH more debugging printouts *)
(*V3=DEBUG with assertions verified *)

    (* This module provides procedures to computes the latest start
       date for a task.

    MODIFICATION HISTORY:

    Dec 21, 90  JES - created.
    Dec 30, 90  JES - Changed the constraints of the latest start date
                      returned by FindLatestStartDate. Namely:
                        Instead of calling FatalError if a
                        start date is not found which is >= the
                        given min start date and whose end date is
                        <= the given max end date: we now simply
                        search for the latest start date whose end
                        date is <= max end date (i.e., we remove 
                        the constraint that the start date found be
                        >= min start date, since there may be negative
                        slack...see AJL for better explanation). If
                        we cannot find such a date, we simply return the
                        given min start date.
    Jan 2, 90   AJL - In proc FindLatestStartDateForDelayTask, the var
                      AssignmentsHandle was never given a value, but was
                      passed to the Release... proc.
                    - When the PRINT toggle was enabled, formatting of 
                      dates was incorrect and wouldn't compile.
    Jan 3, 90   JES - In FindLongestAssignment, we need the test for
                      updating the longest asst to ">=" instead of
                      ">", since the longest duration is initialized
                      to 0 (and thus if all assignments have duration 0,
                      the ">" test would be satisfied by no assignment
                      and the procedure would not return any assignment).

                      Also: if FindLongestAssignment says that all assts
                      have 0 duration, we can set startdate = max end
                      and return in procedure FindLatestStartDateForDelayTask.

                      Also: fixed some locking bugs.
    Jan 4, 90   JES - Made minor clarifications to CheckAsstDrivenDelayThru..
    Jan 7, 90   JES - CheckAsstDrivenDelayThruDate and CheckUniform....
                      were not setting
                      IgnoreResourceLevels correctly in the call to
                      BackCheckResourceDuration. It now correctly takes
                      into account the value of DoWeAllowOverbookings.
    Jan 8, 90   JES - Fixed bug where LatestViolationDate should have 
                        been a VAR parameter in CheckUniformAsst...
    Jan 10, 90  JES - changed FindLatestStartDate so it also returns
                        the corresponding end date.
    Jan 14, 91  JES - added parameter "DoWeUseLateAvailabilities" to
                        procedure FindLatestStartDate.
    Jan 12, 91  AJL - Changed FindLatestDateAllAsstsAvail to start searching
                      at MaxEndDate -1, which seems to me to be correct,
                      as the latest date in the half-open interval ending
                      at MaxEndDate.
    Jan 28, 91  JES - Changed call to ToGoDurationOfEffortDelayTask to
                        ToGoDurationOfEffortDelayAssignments (which takes
                        an already locked assignments array), to remove
                        a locking bug (assignments array locked too many
                        times).
   Feb 15, 91    JES - Renamed MaxEndOfActuals to MaxEndOfSpent.
   Feb 20, 91    JES - Removed unused import AStartStatus.
   Feb 22, 91    JES - Made policy for duration-driven split tasks match
                        that of earliest start date policy (i.e., fixed
                        bug where there were no restrictions on the date
                        found). Also removed all references to Honor-Days-Off
                        since this is now being taken into account
                        by the initial residue availability lists.
   Mar 1, 91     JES - Fixed bug in all procedures that check thru dates,
                        wherein the last assignment would never be checked 
                        because of wrong limit in WHILE loop
   Mar 12, 91    JES - For asst-driven tasks, changed the "OnOrBefore"
                       parameter in FindLatestDateHaveResourceAmount
                       (within FindLatestStartDate...) from MaxEndDate
                       to MaxEndDate -1 (since that would be the appropriate
                       ThruDate; otherwise we overrun the end of the
                       schedule).
   Mar 25, 91    JES - Fixed bug in FindLatestStartDateForDelayTask where,      
                       if task was assignment driven, the parameter
                       DoWeAllowOverbookings was being reset according
                       to the longest-assignment resource's value of
                       LevellableResource. Now we correctly use a local
                       variable "DoWeIgnoreResourceLevel" instead.
   Mar 26, 91 JES  - Changed TimeUtoS's to CtoS's in debugging printouts.
   Mar 27, 91 JES  - Fixed bug where StartDate was not being set for
                     duration-driven split tasks.
                   - Fixed bug where TaskEndDate was not being set in
                     the correct place for duration or asst-driven
                     split tasks.
                   - Added more print debugging statements.
   Mar 28, 91 JES  - Fixed uninitialized VAR parameter StartDate in
                     procedure CheckAsstDrivenSplitThruDate.
   Apr. 2 91  AJL  - Changed FindPotentialThruDateForAsstSplitTask to
                     speed it up a bit buy testing the potential date
                     before calling AllResourcesAreAvailable.
                   - Ditto on FindPotentialThruDateForDurSplitTask.
   Apr. 3 91  AJL  - Changed a comparison to eliminate a possible 0-1 
                     subtraction in FindLatestDateAllAsstsAvail.
   Apr  3, 91 JES -  Use new name "ToGoDurationOfEffortDrivenTask"
                     (previously "ToGoDurationOfEffortDelayTask").
   July 12,91 JES -  Removed some DEBUG checks.
   Jan. 31 92 AJL -  Converted rates to floating point.
   Feb  4, 92 JES -  Changed latest start date for split task so that
                     the start date corresponding to a given thrudate
                     must satisfy "some resource is not on vacation" in
                     order to be considered feasible. 

                     (Note: I left untouched the requirement that 
                     the thrudate itself satisfy "some resource is not
                     on vacation" for assignment-driven tasks, for now.
                     This makes sense since a date when no one is working
                     would never the thrudate of an assignment driven task.
                     For duration-driven tasks, on the other hand, such
                     a date could easily end up being the thrudate.)

   Mar 3, 92  - JES  Fixed so we explicitly exclude summary tasks and duration
                     driven tasks with dur 0 from levelling (corresponding
                     to similar fix in resstart today).
   Mar 4, 92  - JES  Explicitly eliminated (as in ResStart) the degenerate
                     case of an effort-driven task with no ToGo effort, for
                     both split and delay tasks.
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

FROM Dialog         IMPORT  Error, FatalError, NotYetImplemented;
    (* PROC *)

FROM Edges          IMPORT
    (* TYPE *)                  AnEdgePtr, AnEdge;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, 
    (* PROC *)              LockObject, LockObjectArray, ReleaseObject,
                            ReleaseUnchangedObject;
 
FROM LStrings       IMPORT  SetString, CtoS;
    (* PROC *)

FROM Phantoms       IMPORT SummaryFlag;
    (* CONST *)

FROM Planner        IMPORT ScheduleComputedOk, MoveFutureTasks;
    (* VAR *)

FROM ResAvailableResources IMPORT
                            FindLatestDateHaveResourceAmount,
                            FindLatestViolationOrNonVacation,
                            AllResourcesAreAvailable;


FROM ResConstants   IMPORT  MaxLevellableResourcesPerTask, SchedulingAbandoned,
                             LongZero;

FROM ResScheduleTaskResources       
    (* PROC *)      IMPORT  BackCreateSubstitutableResAssignments,
                            BackFindStartDate;


FROM ResUtilities   IMPORT   
    (* TYPE *)              Zero,
    (* PROC *)              EarliestDescendantStartDate, 
                            LatestAntecedantEndDate,
                            TaskUsesNoEmployableResources,
                            NoEmployableResources,
                            MaxEndOfSpent,
                            BackCheckResourceDuration,
                            ToGoDurationOfEffortDrivenAssignments,
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
                        NoteString, PrintAString, PrintList, ConcatTaskID;

FROM TimeFormat   IMPORT TimeUtoS;     

VAR
    s : ARRAY [0..255] OF CHAR;
    TraceS2 : ARRAY [0..255] OF CHAR;
PRINT>*)

TYPE
    AMiniAsst = RECORD
                      Resource           : AResourcePointer;
                      RequiredLevel      : LONGINT;
                      RequiredDuration   : ADuration;
                      LevellableResource : BOOLEAN;
    END;




(* ------------ FindLatestStartDate -----------------------------
   Given a maximum end date, find the latest
   feasible start date for the task (i.e., whose end date is <=
   max end date). If such a date can be found, sets FoundADate to
   TRUE and StartDate to that date, and sets TaskEndDate to the
   corresponding end date.
   Otherwise, sets FoundADate to FALSE.

   If DoWeAllowOverbookings is FALSE, feasibility includes resource-level
   constraints; otherwise it does not. 
   Feasibility includes vacation constraints (depending on the
   task type etc).

*)

PROCEDURE FindLatestStartDate (Task                      : ATaskPtr;
                               MaxEndDate                : ADate;
                               DoWeAllowOverbookings     : BOOLEAN;
                               DoWeUseLateAvailabilities : BOOLEAN;
                           VAR FoundADate                : BOOLEAN;
                           VAR StartDate                 : ADate;
                           VAR TaskEndDate               : ADate);
BEGIN
        (* dispense with summary tasks: *)
    IF (SummaryFlag IN Task^.TempTaskFlags) THEN        
        (*<PRINT
        SetString(NoteString, " summary task: start = end = maxenddate");
        PrintAString(NoteString);
        PRINT>*)
        StartDate   := MaxEndDate;
        TaskEndDate := MaxEndDate;
        FoundADate  := TRUE;
        RETURN;
    END;

        (* dispense with effort-driven tasks with no ToGo effort: *)    
    IF (Task^.DurationMethod = DurationDriven) AND 
       (Task^.ToGoSummary.Time <= Zero) THEN    
        (*<PRINT
        SetString(NoteString, " eff driven w no effort: start = end = maxenddate");
        PrintAString(NoteString);
        PRINT>*)
        StartDate   := MaxEndDate;
        TaskEndDate := MaxEndDate;
        FoundADate  := TRUE;
        RETURN;
    END;

        (* dispense with milestones: *)
    IF (Task^.DurationMethod = DurationDriven) AND (Task^.duration = 0) THEN
        (*<PRINT
        SetString(NoteString, " dur-driv with dur 0: start = end = maxenddate");
        PrintAString(NoteString);
        PRINT>*)
        StartDate   := MaxEndDate;
        TaskEndDate := MaxEndDate;
        FoundADate  := TRUE;
        RETURN;
    END;

        (* dispense with tasks that have no employable resources: *)
    IF (TaskUsesNoEmployableResources(Task)) THEN        
        (*<PRINT
        SetString(NoteString, "  no employable resources: just check start date");
        PrintAString(NoteString);
        PRINT>*)
        TaskEndDate := MaxEndDate;
        IF (Task^.DurationMethod = DurationDriven) THEN
            IF (TaskEndDate - Task^.duration >= MinDate) THEN
                FoundADate := TRUE;
                StartDate := TaskEndDate - Task^.duration;
            ELSE
                (*<PRINT
                SetString(NoteString, "task overruns mindate");
                PrintAString(NoteString);
                PRINT>*)
                FoundADate  := FALSE;
                StartDate := MinDate;
            END;
        ELSE
            FoundADate  := TRUE;
            StartDate := TaskEndDate;
        END;
        RETURN;
    END;

    IF (Task^.SplittingRule = Split) THEN
        (*<PRINT
        SetString(NoteString, "Ready to call latest start for split:");
        PrintAString(NoteString);
        PRINT>*)
        FindLatestStartDateForSplitTask(Task, 
                                        MaxEndDate,
                                        DoWeAllowOverbookings,
                                        DoWeUseLateAvailabilities,
                                        FoundADate,
                                        StartDate,
                                        TaskEndDate);
    ELSE
        (*<PRINT
        SetString(NoteString, "Ready to call latest start for delay:");
        PrintAString(NoteString);
        PRINT>*)
        FindLatestStartDateForDelayTask(Task,
                                        MaxEndDate,
                                        DoWeAllowOverbookings,
                                        DoWeUseLateAvailabilities,
                                        FoundADate,
                                        StartDate,
                                        TaskEndDate);

    END;
END FindLatestStartDate;



(* Note on "ThruDate" concept (for the following two procedures): 

   A "ThruDate" is a date that
   can potentially be the last date that some resource works on
   a task. It (and not "EndDate") is the reverse analog of 
   "StartDate", which is the first date that some resource 
   works on the task. (Note that, given a ThruDate, the corresponding
   EndDate is ThruDate + 1.) In general: end=start + duration. IF
   Duration is > 0 (i.e., if there exists a thrudate), then:
   thru = end - 1, end = thru + 1, thru = start + duration - 1,
   start = thru - duration + 1.

   Our strategy in the procedures below is to find the latest possible
   ThruDate less than the given MaxEndDate. (This is the reverse analog
   of finding an earliest start date.) The start date corresponding to 
   this date is then the latest start date.
*)





(* ---- FindLatestStartDateForSplitTask ------------------------- *)



PROCEDURE FindLatestStartDateForSplitTask (Task              : ATaskPtr;
                                           MaxEndDate        : ADate;
                                           DoWeAllowOverbookings : BOOLEAN;
                                           DoWeUseLateAvailabilities : BOOLEAN;
                                       VAR FoundADate        : BOOLEAN;
                                       VAR StartDate         : ADate;
                                       VAR TaskEndDate       : ADate);

VAR
    AssignmentsHandle     : AnExtHandle;      
    Assignments          : AnAssignmentArray;
    DurationRequired     : ADuration;
    Resource             : AResourcePointer;
    AssignmentEndDate, AssignmentStart, TheDateWeFound,
       LatestViolationDate,  TrialStartDate, 
       TrialThruDate     : ADate;
    i, ResourceCount     : CARDINAL;
    FoundPotentialThruDate, DurationSatisfied,
    DoWeForceSchedule, DoWeContour, 
    WeFoundStartOrViolationDate, TrialThruDateIsOkay,
    TheDateWeFoundIsViolation : BOOLEAN;

BEGIN
    (*<PRINT
    SetString(NoteString,"Latest startdate for split task ");
    ConcatTaskID(NoteString,Task);
    ConcatS(NoteString,", MaxEndDate = ");
    CtoS(MaxEndDate,s);
    ConcatLS(NoteString,s);
    CtoS(MaxEndDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString, "   with allow overbookings = ");
    IF DoWeAllowOverbookings THEN
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    PrintAString(NoteString);
    PRINT>*)

    (*<DEBUG
    IF Task^.SplittingRule <> Split THEN
        SendErrorMsg("Latest start for splits called with non-split task");
        FatalError();
    END;
    DEBUG>*)

    FoundADate := FALSE;

    (* case 1 - effort-driven split task *)

    IF (Task^.DurationMethod = EffortDriven) THEN
        (*<PRINT
        SetString(NoteString, "    Effort-driven - calling BackCreateSubs:");
        PrintAString(NoteString);
        PRINT>*)

        (* call dry-run, backwards version of create substitutable
           resource assignments to find the start date: *)
        DoWeForceSchedule := DoWeAllowOverbookings;
        DoWeContour := NOT (DoWeForceSchedule); 
            (* In the following procedure, the last parameter
               is set to TRUE iff all the work can be done
               without running into MinDate *)
        BackCreateSubstitutableResAssignments (Task,
                                               MaxEndDate,
                                               DoWeForceSchedule,     
                                               DoWeContour,
                                               FALSE, (* create assts *)
                                               DoWeUseLateAvailabilities,
                                               StartDate,
                                               TaskEndDate,
                                               FoundADate);


    (* case 2 - assignment-driven split task with DoWeAllowOverbookings = TRUE *)

    ELSIF (Task^.DurationMethod = AssignmentDriven) AND (DoWeAllowOverbookings) THEN
        (*<PRINT
        SetString(NoteString, "asst-driv w allow overbook:");
        PrintAString(NoteString);
        PRINT>*)
        AssignmentsHandle := Task^.Plan.Assignments;
        ResourceCount := LockObjectArray(AssignmentsHandle,
                                         Assignments,
                                         TSIZE(AnAssignmentRecord));

             (* First find the end date, namely, the latest date on or
                before MaxEndDate such that some assignment can work,
                and such that no other resource has a violation. *)

             (* NOTE: we need an actual valid thru date so that
                we can return the correct TaskEndDate *)
        FindPotentialThruDateForAsstSplitTask(Assignments,
                                              ResourceCount,
                                              MaxEndDate - 1,
                                              TRUE (* allow overbook *),
                                              DoWeUseLateAvailabilities,
                                              FoundPotentialThruDate,
                                              TrialThruDate);
        IF (NOT FoundPotentialThruDate) THEN
            (*<PRINT
            SetString(NoteString, " no potential thru date found");
            PrintAString(NoteString);
            PRINT>*)
            FoundADate := FALSE;
            ReleaseUnchangedObject(AssignmentsHandle);
            RETURN;
        END;  
        TaskEndDate := TrialThruDate + 1; 

              (* run through all the assignments backwards from
               TaskEndDate, skipping over vacations, and take the
               minimum of the resulting start dates *)

        StartDate := TaskEndDate;
        FOR i := 0 TO (ResourceCount - 1) DO
            Resource := Assignments^[i].Resource;
            IF (Resource^.Type = Employable) THEN
                WITH Assignments^[i] DO
                    DurationRequired := DurationOf(MaxRatePercent,
                                                   YetToGoQuantity);
                    IF DurationRequired > 0 THEN
                        BackFindStartDate(Resource,
                                          TaskEndDate,
                                          DurationRequired,
                                          AssignmentStart,
                                          DurationSatisfied);

                        IF NOT (DurationSatisfied) THEN
                            FoundADate := FALSE;
                            ReleaseUnchangedObject(AssignmentsHandle);
                            RETURN;
                        END;

                        IF AssignmentStart < StartDate THEN                                                
                            StartDate := AssignmentStart;
                        END;
                    END;
                END; (* with asst[i] *)
            END; (* employable resource *)
        END; (* end loop *)

        ReleaseUnchangedObject(AssignmentsHandle);
        FoundADate := TRUE;

    (* case 3 - assignment-driven with no overbook allowed, 
                or duration driven with duration > 0 *)

    ELSE
        (*<PRINT
        SetString(NoteString, "asst or dur-driv w no overbook allowed:");
        PrintAString(NoteString);
        PRINT>*)
            (* In this case we may run into a resource-level violation while
               running backwards trying to satisfy resource durations.
               We first find a TrialThruDate, i.e., the latest date such
               that there is no resource violation and, for asst-driven
               tasks only, when some resource is not on vacation. We then
               loop through resources testing whether durations
               can be satisfied. If we run into a violation, we take the
               violation date as the new trial end date and try again
               from there. 
        
               In the case of duration-driven tasks, the resulting start
               must also satisfy "some resource is not on vacation". If
               it does not, we traverse backwards from it until we find
               such a date. If we cannot do so without hitting a violation,
               then the trial thru date is not good and we must start again
               from the violation. Otherwise, we take as start date the
               latest date on or before {the start date resulting from the
               trial thru date} such that some resource is not on vacation;
               and we take as the end date, that date plus the task duration.
               (This modification made 2/4/92 - JES)
                
*)
        AssignmentsHandle := Task^.Plan.Assignments;
        ResourceCount := LockObjectArray(Task^.Plan.Assignments,
                                         Assignments,
                                         TSIZE(AnAssignmentRecord));

        IF (Task^.DurationMethod = AssignmentDriven) THEN
            (*<PRINT
            SetString(NoteString, "Asst split task: seek potential thru date");
            PrintAString(NoteString);
            PRINT>*)
            FindPotentialThruDateForAsstSplitTask(Assignments,
                                                  ResourceCount,
                                                  MaxEndDate - 1,
                                                  FALSE (* allowoverbook *),
                                                  DoWeUseLateAvailabilities,
                                                  FoundPotentialThruDate,
                                                  TrialThruDate);
        ELSE                
            (*<PRINT
            SetString(NoteString, "Dur split task: seek potential thru date");
            PrintAString(NoteString);
            PRINT>*)
            IF (DoWeAllowOverbookings) THEN
                FoundPotentialThruDate := TRUE;
                TrialThruDate := MaxEndDate - 1;
            ELSE
                FindPotentialThruDateForDurSplitTask(Assignments,
                                                     ResourceCount,
                                                     MaxEndDate - 1,
                                                     DoWeUseLateAvailabilities,
                                                     FoundPotentialThruDate,
                                                     TrialThruDate);
            END;        
        END;


        IF NOT (FoundPotentialThruDate) THEN
            (*<PRINT
            SetString(NoteString, " no potential thru date found");
            PrintAString(NoteString);
            PRINT>*)
            FoundADate := FALSE;
            ReleaseUnchangedObject(AssignmentsHandle);
            RETURN;
        END;


            (* So far, we have just found a potential thrudate. Now, we
               try to find a feasible corresponding start date. If that's
               not possible with this thrudate, then we iterate. In each
               iteration, we take (violation date found - 1) as the
               new potential thrudate. In the case of a duration driven
               task, we must take special pains to ensure that the start
               date has some resource which is not on vacation. (This will
               happen automatically in the case of assignment-driven tasks.)
            *)

        FoundADate := FALSE; 
        WHILE NOT (FoundADate) DO
            (*<PRINT
            SetString(NoteString, "potential thrudate = ");
            CtoS(TrialThruDate, s);
            ConcatLS(NoteString, s);
            CtoS(TrialThruDate, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            PRINT>*)
            IF (Task^.DurationMethod = AssignmentDriven) THEN
                CheckAsstDrivenSplitThruDate(Assignments,
                                             ResourceCount,
                                             TrialThruDate,
                                             DoWeUseLateAvailabilities,
                                             StartDate,
                                             LatestViolationDate,
                                             FoundADate);
            ELSE
                (* Task is duration driven - first check that there
                   are no violations wrt the TrialThruDate, and if
                   not, then backtrack from the corresponding start
                   date to find one for which some resource is not
                   on vacation. If both things can be satisfied, we
                   have found a good date. Otherwise, we try again
                   from a new trial thru date equal to the violation
                   date minus one. *)

                IF (DoWeAllowOverbookings) THEN
                    TrialThruDateIsOkay := TRUE;
                ELSE
                    CheckDurDrivenSplitThruDate(Assignments,
                                                ResourceCount,
                                                TrialThruDate,
                                                Task^.duration,
                                                DoWeUseLateAvailabilities,
                                                LatestViolationDate,
                                                TrialThruDateIsOkay);
                END;
                IF (TrialThruDateIsOkay) THEN
                    (*<PRINT
                    SetString(NoteString, "trial thrudate ok, backtracking:");
                    PrintAString(NoteString);
                    SetString(NoteString, "task duration = ");    
                    CtoS(Task^.duration, s);
                    ConcatLS(NoteString, s);
                    PrintAString(NoteString);
                    PRINT>*)
                        (* try to find a good corresponding start date: *)
                        (* note: start date = end date - duration , and
                                end date = thru date + 1 *)
                    TrialStartDate := (TrialThruDate + 1) - Task^.duration;
                    BackTrackToFindStartDate (Assignments,
                                              ResourceCount,
                                              TrialStartDate,
                                              DoWeUseLateAvailabilities,
                                              DoWeAllowOverbookings,
                                              TheDateWeFound,
                                              WeFoundStartOrViolationDate,
                                              TheDateWeFoundIsViolation);
                    IF (NOT TheDateWeFoundIsViolation) THEN
                        (*<PRINT
                        SetString(NoteString, "backtrack found good date = ");
                        CtoS(TheDateWeFound,s);
                        ConcatLS(NoteString, s);
                        CtoS(TheDateWeFound,s);
                        ConcatLS(NoteString, s);
                        PrintAString(NoteString);
                        PRINT>*)
                        FoundADate    := TRUE; (* we're done *)        
                        StartDate     := TheDateWeFound;
                            (* We reset the thrudate so that the end
                               date will be set correctly below: *)
                        TrialThruDate := StartDate + Task^.duration - 1;
                    ELSE
                        (*<PRINT
                        SetString(NoteString, "backtrack found violation =");
                        CtoS(TheDateWeFound, s);
                        ConcatLS(NoteString, s);
                        PrintAString(NoteString);
                        PRINT>*)        
                        LatestViolationDate := TheDateWeFound;
                    END;
                END;

            END; (* case task is asst or duration driven *)                
    
            IF NOT (FoundADate) THEN
                IF (LatestViolationDate > MinDate) THEN
                    TrialThruDate := LatestViolationDate - 1;
                    (*<PRINT
                    SetString(NoteString, "trying again from latestviol -1 = ");
                    CtoS(TrialThruDate, s);
                    ConcatLS(NoteString, s);
                    PrintAString(NoteString);
                    PRINT>*)
                ELSE
                    (*<PRINT
                    SetString(NoteString, "latest viol date = mindate so no date found");
                    PrintAString(NoteString);
                    PRINT>*)
                        (* no date can be found *)
                    ReleaseUnchangedObject(AssignmentsHandle);
                    RETURN;
                END;
            END;

        END; (* end loop *)

            (* We found a good thru date, so set the task end date: *)
        TaskEndDate := TrialThruDate + 1; (* the corresponding end date *)

        (*<PRINT
        SetString(NoteString, "trial thru date is good - end date = ");
        CtoS(TaskEndDate, s);
        ConcatLS(NoteString, s);
        CtoS(TaskEndDate, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        SetString(NoteString, " corresp start date = ");
        CtoS(StartDate, s);
        ConcatLS(NoteString, s);
        CtoS(StartDate, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)

        ReleaseUnchangedObject(AssignmentsHandle);

    END; (* end cases *)

END FindLatestStartDateForSplitTask;




(* ---- FindLatestStartDateForDelayTask --------------------- *)


PROCEDURE FindLatestStartDateForDelayTask (Task              : ATaskPtr;
                                           MaxEndDate        : ADate;
                                           DoWeAllowOverbookings : BOOLEAN;
                                           DoWeUseLateAvailabilities : BOOLEAN;
                                       VAR FoundADate        : BOOLEAN;
                                       VAR StartDate         : ADate;
                                       VAR TaskEndDate       : ADate);

VAR
    AssignmentsHandle       : AnExtHandle;
    Assignments             : AnAssignmentArray;
    LongestAssignment       : AMiniAsst;
    LongestAsstDuration, DurationRequired,
      UniformAsstDuration   : ADuration;
    LatestViolationDate, 
      TrialThruDate         : ADate;
    i, ResourceCount        : CARDINAL;
    DoWeIgnoreResourceLevel,
      FoundPotentialThruDate: BOOLEAN;

BEGIN

    (*<PRINT
    SetString(NoteString,"Latest startdate for delay task ");
    ConcatTaskID(NoteString,Task);
    ConcatS(NoteString,", MaxEndDate = ");
    CtoS(MaxEndDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString, "   with allow overbookings = ");
    IF DoWeAllowOverbookings THEN
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    PrintAString(NoteString);
    PRINT>*)

    (*<DEBUG
    IF Task^.SplittingRule <> Delay THEN
        SendErrorMsg("Latest start for delay called with non-delay task");
        FatalError();
    END;
    DEBUG>*)

    AssignmentsHandle := Task^.Plan.Assignments;
    ResourceCount := LockObjectArray(AssignmentsHandle,
                                     Assignments,  
                                     TSIZE(AnAssignmentRecord));

    (* case 1 - assignment-driven delay task *)

    IF (Task^.DurationMethod = AssignmentDriven) THEN

            (* For a potential ThruDate to be valid in this case, all 
               resources must be available continuously in the interval 
               [(ThruDate - LongestAsstDuration + 1),
                 ThruDate - (LongestAsstDuration - this resource's duration)];

                 Picture of required availability:           
                                                                 thrudate
                 Longest assignment: |-------------------------------|
                 Other assignments:  |----------------|
                                     |------------------------  |
                                          ...
            *)

            (* First find the longest assignment, and then the latest date
               less than MaxEndDate such that its resource is available - 
               we look for a date strictly less than MaxEndDate, because that 
               will serve as the test ThruDate, i.e., the latest date
               that any resource would be actually working on the task *)

        FindLongestAssignment(Assignments,
                              ResourceCount,
                              LongestAssignment);
        LongestAsstDuration := LongestAssignment.RequiredDuration;

        IF LongestAsstDuration = 0 THEN
            (*<PRINT
            SetString(NoteString,"    all assts have 0 duration - start = maxend");
            PrintAString(NoteString);
            PRINT>*)
            FoundADate := TRUE;
            StartDate  := MaxEndDate;
            TaskEndDate := MaxEndDate;
            ReleaseUnchangedObject(AssignmentsHandle);
            RETURN;
        END;

        WITH LongestAssignment DO
            DoWeIgnoreResourceLevel := (DoWeAllowOverbookings) OR
                                          NOT (LevellableResource);
            FindLatestDateHaveResourceAmount(Resource,
                                             RequiredLevel,
                                             MaxEndDate - 1, (* on or before *)
                                             FALSE, (* allow vacations *)
                                             DoWeIgnoreResourceLevel,
                                             DoWeUseLateAvailabilities,
                                             FoundPotentialThruDate,
                                             TrialThruDate);
        END; (* with longest assignment *)

        IF NOT (FoundPotentialThruDate) THEN 
            FoundADate := FALSE;
            ReleaseUnchangedObject(AssignmentsHandle);
            RETURN;
        END;

        FoundADate := FALSE; 
        WHILE (NOT FoundADate) DO
            (*<PRINT
            SetString(NoteString, "    TrialThruDate = ");
            CtoS(TrialThruDate, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            PRINT>*)

            CheckAsstDrivenDelayThruDate (Assignments,
                                          ResourceCount,
                                          DoWeAllowOverbookings,
                                          DoWeUseLateAvailabilities,
                                          TrialThruDate,
                                          LongestAsstDuration,
                                          LatestViolationDate,
                                          FoundADate);

            IF FoundADate THEN
                TaskEndDate := TrialThruDate + 1;
                StartDate   := TaskEndDate - LongestAsstDuration;
                (*<PRINT
                SetString(NoteString, "latest start date = ");
                CtoS(StartDate,TraceS2); ConcatLS(NoteString, TraceS2);
                PrintAString(NoteString);
                PRINT>*)
            ELSE
                (*<PRINT
                SetString(NoteString, "potential thru date gets violation on ");
                CtoS(LatestViolationDate,TraceS2); 
                ConcatLS(NoteString, TraceS2);
                PrintAString(NoteString);
                PRINT>*)

                (* try again from violation date - 1 (note: we are
                   therefore testing the violation date as an end date) *)
                IF LatestViolationDate > MinDate THEN
                    WITH LongestAssignment DO
                        DoWeIgnoreResourceLevel := (DoWeAllowOverbookings) OR
                                                     NOT (LevellableResource);
                        FindLatestDateHaveResourceAmount(Resource,
                                                         RequiredLevel,
                                                         LatestViolationDate - 1,
                                                         FALSE, (* allow vac *)
                                                         DoWeIgnoreResourceLevel,
                                                         DoWeUseLateAvailabilities,
                                                         FoundPotentialThruDate,
                                                         TrialThruDate);
                    END; (* with longest asst *)

                    IF NOT (FoundPotentialThruDate) THEN 
                        FoundADate := FALSE;
                        ReleaseUnchangedObject(AssignmentsHandle);
                        RETURN;
                    END;
                ELSE
                    (* we ran into MinDate: *)
                    FoundADate := FALSE;
                    ReleaseUnchangedObject(AssignmentsHandle);
                    RETURN;
                END;

                (*<PRINT
                SetString(NoteString, "New potential thrudate = ");
                CtoS(TrialThruDate,TraceS2); ConcatLS(NoteString, TraceS2);
                PrintAString(NoteString);
                PRINT>*)
            END; (* if date is good *)
        END; (* end loop *)
        ReleaseUnchangedObject(AssignmentsHandle);


    (* case 2 - effort-driven or duration-driven delay task *)

    ELSE
            (* in this case, ALL resources must be available on the
               end date, and they must be able to run continuously
               backwards through the remaining task duration without
               running into a violation; so, as in case 1, we first
               find the latest date on or before MaxEndDate such that
               all resources are available, and then run backwards
               testing whether durations can be satisfied, taking any
               violation date found as the new test end date *)

        IF (Task^.DurationMethod = DurationDriven) THEN
                UniformAsstDuration := Task^.duration;
        ELSE
                UniformAsstDuration := ToGoDurationOfEffortDrivenAssignments
                                            (Task,
                                             Assignments,
                                             ResourceCount);
        END;

        FindLatestDateAllAsstsAvail(Assignments,
                                    ResourceCount,
                                    MaxEndDate,
                                    DoWeAllowOverbookings,
                                    DoWeUseLateAvailabilities,
                                    TrialThruDate, (* out param *)
                                    FoundPotentialThruDate);      

        IF NOT (FoundPotentialThruDate) THEN 
            FoundADate := FALSE;
            ReleaseUnchangedObject(AssignmentsHandle);
            RETURN;
        END;

            (* For a potential ThruDate to be valid, all resources
               must be available continuously in the interval 

               [(ThruDate + 1 - ToGoDuration), ThruDate];
            *)

        FoundADate := FALSE;
        WHILE (NOT FoundADate) DO
            (*<PRINT
            SetString(NoteString, "    TrialThruDate = ");
            CtoS(TrialThruDate, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            PRINT>*)

            CheckUniformDurationDelayThruDate (Assignments,
                                               ResourceCount,
                                               DoWeAllowOverbookings,
                                               DoWeUseLateAvailabilities,
                                               TrialThruDate,
                                               UniformAsstDuration,
                                               LatestViolationDate,
                                               FoundADate);

            IF FoundADate THEN
                TaskEndDate := TrialThruDate + 1;
                StartDate   := TaskEndDate - UniformAsstDuration;
                (*<PRINT
                SetString(NoteString, "latest start date = ");
                CtoS(StartDate,TraceS2); ConcatLS(NoteString, TraceS2);
                PrintAString(NoteString);
                PRINT>*)
            ELSE
                (*<PRINT
                SetString(NoteString, "potential thru date gets violation on ");
                CtoS(LatestViolationDate,TraceS2); ConcatLS(NoteString, TraceS2);
                PrintAString(NoteString);
                PRINT>*)

                (* try again from violation date - 1 (note: we are
                   therefore testing the violation date as an end date) *)

                IF (LatestViolationDate > MinDate) THEN
                    FindLatestDateAllAsstsAvail(Assignments,
                                                ResourceCount,
                                                LatestViolationDate - 1,
                                                DoWeAllowOverbookings,
                                                DoWeUseLateAvailabilities,
                                                TrialThruDate, 
                                                FoundPotentialThruDate);    

                    IF NOT (FoundPotentialThruDate) THEN 
                        FoundADate := FALSE;
                        ReleaseUnchangedObject(AssignmentsHandle);
                        RETURN;
                    END;
                ELSE
                        (* we ran into MinDate: *)
                    FoundADate := FALSE;
                    ReleaseUnchangedObject(AssignmentsHandle);
                    RETURN;
               END;


                (*<PRINT
                SetString(NoteString, "New potential thrudate = ");
                CtoS(TrialThruDate,TraceS2); ConcatLS(NoteString, TraceS2);
                PrintAString(NoteString);
                PRINT>*)
            END; (* if date is good *)
        END; (* end loop *)

        ReleaseUnchangedObject(AssignmentsHandle);

    END; (* end cases *)

END FindLatestStartDateForDelayTask;






(* Note regarding all of the below procedures: all of them assume
   that the assignments array contains some elements. They are only
   called by procedures that have already checked that there are
   some employable (and therefore some) resources.
*)



(* ---------------- FindPotentialThruDateForAsstSplitTask ----------------

   For an assignment-driven split task, find the latest date
   date on or before MaxThruDate such that some resource is
   available at the required level and not on vacation, and such
   that any other resource not on vacation is available at the
   required level (i.e., such that there are no resource violations).

   If DoWeAllowOverbookings is TRUE, the resource-level
   constraints are not active.

   If DoWeUseLateAvailabilities is TRUE, the procedure references
   the LateAvailProfile of each resource; otherwise it references
   the regular AvailProfile.

   This procedure assumes the caller has checked that there are some
   employable resources in the assignments array, and that this task 
   has a duration > 0.

*)



PROCEDURE FindPotentialThruDateForAsstSplitTask (Assignments        : AnAssignmentArray;
                                                 NumAssignments     : CARDINAL;
                                                 MaxThruDate        : ADate;
                                                 DoWeAllowOverbookings     : BOOLEAN;
                                                 DoWeUseLateAvailabilities : BOOLEAN;
                                             VAR FoundPotentialDate : BOOLEAN;
                                             VAR PotentialDate      : ADate);
VAR
    LatestResourceDate : ADate;
    i                  : CARDINAL;
    DoWeAllowOverbook  : BOOLEAN; (* for an individual resource *) 
    FoundResourceDate  : BOOLEAN;

BEGIN
    FoundPotentialDate := FALSE;
    PotentialDate := MinDate; (* we search for the latest one *)
    i := 0;
        (* We try all resources, but we exit the loop if we've already
           done the best we are allowed to do: *)
    WHILE (i < NumAssignments) AND (PotentialDate < MaxThruDate) DO
        WITH Assignments^[i] DO
            IF Resource^.Type = Employable THEN
                DoWeAllowOverbook := (DoWeAllowOverbookings) OR 
                                  NOT (Resource^.LevelThisResource);
                    (* find latest date when res is ACTUALLY available: *)
                FindLatestDateHaveResourceAmount(Resource,
                                                 VAL(LONGINT, MaxRatePercent),
                                                 MaxThruDate,
                                                 FALSE, (* allow vacs *)
                                                 DoWeAllowOverbook,(*this res only*)
                                                 DoWeUseLateAvailabilities,
                                                 FoundResourceDate,
                                                 LatestResourceDate);
                IF FoundResourceDate AND 
                   (LatestResourceDate > PotentialDate) THEN
                    IF AllResourcesAreAvailable(Assignments,
                                                NumAssignments,
                                                LatestResourceDate,
                                                TRUE, (*allow vacations*)
                                                DoWeAllowOverbookings,
                                                DoWeUseLateAvailabilities) THEN
                        FoundPotentialDate := TRUE;
                        PotentialDate := LatestResourceDate;
                    END;
                END;
            END; (* employable resource *)
            INC(i);
        END; (* with asst[i] *)
    END; (* end loop *)

END FindPotentialThruDateForAsstSplitTask;



(* ---------------- FindPotentialThruDateForDurSplitTask ----------------
   
   For a duration-driven split task, find the latest date
   date on or before MaxThruDate such that
   any resource not on vacation is available at the
   required level (i.e., such that there are no resource violations).

   (Note: unlike for assignment-driven tasks, here we allow all resources
   to be on vacation on the thrudate.)

   If DoWeUseLateAvailabilities is TRUE, the procedure references
   the LateAvailProfile of each resource; otherwise it references
   the regular AvailProfile.

   This procedure assumes the caller has checked that there are some
   employable resources in the assignments array, and that the duration
   of the task > 0.

*)



PROCEDURE FindPotentialThruDateForDurSplitTask (Assignments        : AnAssignmentArray;
                                                NumAssignments     : CARDINAL;
                                                MaxThruDate        : ADate;
                                                DoWeUseLateAvailabilities : BOOLEAN;
                                            VAR FoundPotentialDate : BOOLEAN;
                                            VAR PotentialDate      : ADate);
VAR
    LatestResourceDate : ADate;
    i                  : CARDINAL;
    FoundResourceDate  : BOOLEAN;

BEGIN
    FoundPotentialDate := FALSE;
    PotentialDate := MinDate; (* we search for the latest one *)
    i := 0;
        (* We try all resources, but we exit the loop if we've already
           done the best we are allowed to do: *)
    WHILE (i < NumAssignments) AND (PotentialDate < MaxThruDate) DO
        WITH Assignments^[i] DO
            IF Resource^.Type = Employable THEN
                IF NOT (Resource^.LevelThisResource) THEN
                    FoundResourceDate := TRUE;
                    LatestResourceDate := MaxThruDate;                        
                ELSE
                    FindLatestDateHaveResourceAmount(Resource,
                                                     VAL(LONGINT, MaxRatePercent),
                                                     MaxThruDate,
                                                     TRUE, (* allow vacations *)
                                                     FALSE, (*allow overbook *)
                                                     DoWeUseLateAvailabilities,
                                                     FoundResourceDate,
                                                     LatestResourceDate);
                END;
                IF FoundResourceDate AND 
                   (LatestResourceDate > PotentialDate) THEN
                    IF AllResourcesAreAvailable(Assignments,
                                                NumAssignments,
                                                LatestResourceDate,
                                                TRUE, (*allow vacations*)
                                                FALSE, (*allow overbookings*)
                                                DoWeUseLateAvailabilities) THEN
                        FoundPotentialDate := TRUE;                                
                        PotentialDate := LatestResourceDate;
                    END;
                END;
            END; (* employable resource *)
            INC(i);
        END; (* with asst[i] *)
    END; (* end loop *)

END FindPotentialThruDateForDurSplitTask;



(* ------------ CheckAsstDrivenSplitThruDate -------------------------------

   Given an assignment-driven split task and a potential ThruDate,
   this procedure determines whether resource levels can be continuously
   met, except for vacations, starting at ThruDate and running through
   each assignment's duration. The procedure runs backwards in time
   starting at the ThruDate, for each assignment.

   If DoWeUseLateAvailabilities is TRUE, the procedure references
   the LateAvailProfile of each resource; otherwise it references
   the regular AvailProfile.

   A violation date is a date such that the resource is not on vacation
   and not enough of the resource (i.e., less than MaxRatePercent) is
   available. If the procedure finds a violation date for any
   assignment, it returns that via LatestViolationDate (actually, the
   start date of the latest cell with the violation), and sets
   DateIsGood to FALSE. 
   
   Otherwise, it sets DateIsGood to TRUE, and
   sets StartDate to the minimum, over all assignments, of the earliest
   date any resource must work in order to satisfy the ThruDate.
*)

PROCEDURE CheckAsstDrivenSplitThruDate(Assignments               : AnAssignmentArray;
                                       NumAssignments            : CARDINAL;
                                       TrialThruDate             : ADate;
                                       DoWeUseLateAvailabilities : BOOLEAN;
                                  VAR  StartDate           : ADate;
                                  VAR  LatestViolationDate : ADate;
                                  VAR  DateIsGood          : BOOLEAN);
VAR
    LevelRequired     : REAL;
    DurationRequired  : ADuration;
    ResourceStartDate : ADate;
    ResourceViolationDate : ADate;
    i                 : CARDINAL;
    DoWeIgnoreResourceLevels : BOOLEAN;

BEGIN
        i := 0;
        StartDate := MaxDate;
        DateIsGood := TRUE;
        WHILE (DateIsGood) AND (i < NumAssignments) DO
            WITH Assignments^[i] DO
                IF Resource^.Type = Employable THEN
                    DurationRequired := DurationOf(MaxRatePercent,
                                                   YetToGoQuantity);
                    IF NOT (Resource^.LevelThisResource) THEN
                        DateIsGood := TRUE;
                        ResourceStartDate := (TrialThruDate + 1) - DurationRequired;
                    ELSE
                        LevelRequired := FLOAT(MaxRatePercent);
                        BackCheckResourceDuration(Resource,
                                                  TrialThruDate,
                                                  LevelRequired,
                                                  DurationRequired,
                                                  TRUE,  (* AllowVacations *)
                                                  FALSE, (* CountVacations *)
                                                  FALSE, (*ignore levels *)
                                                  DoWeUseLateAvailabilities,
                                                  DateIsGood,
                                                  ResourceStartDate,
                                                  ResourceViolationDate);
                    END;
                    IF (DateIsGood) AND (ResourceStartDate < StartDate) THEN    
                        StartDate := ResourceStartDate;
                    END;
                END; (* employable resource *)
            END; (* with assignments[i] *)
            INC(i);
        END; (* loop thru assignments *)

        IF NOT (DateIsGood) THEN 
            LatestViolationDate := ResourceViolationDate;
        END;

END CheckAsstDrivenSplitThruDate;


(* ------------ CheckDurDrivenSplitThruDate -------------------------------

   Given a duration-driven split task and a potential ThruDate,
   this procedure determines whether resource levels can be continuously
   met, except for vacations, starting at ThruDate and running through
   the task duration. The procedure runs backwards in time
   starting at the ThruDate for each resource.

   If DoWeUseLateAvailabilities is TRUE, the procedure references
   the LateAvailProfile of each resource; otherwise it references
   the regular AvailProfile.

   A violation date is a date such that the resource is not on vacation
   and not enough of the resource (i.e., less than MaxRatePercent) is
   available. If the procedure finds a violation date for any
   assignment, it returns that via LatestViolationDate (actually, the
   start date of the latest cell with the violation), and sets
   DateIsGood to FALSE. 
   
   Otherwise, it sets DateIsGood to TRUE.
*)

PROCEDURE CheckDurDrivenSplitThruDate(Assignments               : AnAssignmentArray;
                                      NumAssignments            : CARDINAL;
                                      TrialThruDate             : ADate;
                                      TaskDuration              : ADuration;
                                      DoWeUseLateAvailabilities : BOOLEAN;
                                 VAR  LatestViolationDate : ADate;
                                 VAR  DateIsGood          : BOOLEAN);
VAR
    LevelRequired                  : REAL;
    ResourceStartDate,
      ResourceViolationDate        : ADate;
    i                              : CARDINAL;

BEGIN
        (*<PRINT
        SetString(NoteString, "Checking dur-driv split thru date:");
        PrintAString(NoteString);        
        PRINT>*)
        i := 0;
        DateIsGood := TRUE;
        WHILE (DateIsGood) AND (i < NumAssignments) DO
            WITH Assignments^[i] DO
                IF Resource^.Type = Employable THEN
                    IF Resource^.LevelThisResource THEN
                        LevelRequired := FLOAT( MaxRatePercent);
                        BackCheckResourceDuration(Resource,
                                                  TrialThruDate,
                                                  LevelRequired,
                                                  TaskDuration,
                                                  TRUE, (*AllowVacations*)
                                                  TRUE, (*CountVacations*)
                                                  FALSE,(*DoWeIgnoreResourceLevels*)
                                                  DoWeUseLateAvailabilities,
                                                  DateIsGood,
                                                  ResourceStartDate,
                                                  ResourceViolationDate);
                    END; (* levellable resource *)
                END; (* employable resource *)
            END; (* with assignments[i] *)
            INC(i);
        END; (* loop thru assignments *)

        IF NOT (DateIsGood) THEN
            LatestViolationDate := ResourceViolationDate;
            (*<PRINT    
            SetString(NoteString, "check dur-driv split thrudate: viol = ");
            CtoS(LatestViolationDate, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);    
            ELSE
            SetString(NoteString, "check dur-driv split thrudate: date is good");    
            PrintAString(NoteString);
            PRINT>*)
        END;


END CheckDurDrivenSplitThruDate;





(*-----BackTrackToFindStartDate--------------

   Starting with a tentative start date that has no violations
   (BackTrackFromDate), work backwards to find either the first
   date such that (a) there are no violations and some resource
   is not on vacation, or (b) there is a violation; whichever
   comes first. If (a) comes first, returns the date in DateFound,
   and sets DateIsViolation to FALSE. If (b) comes first, returns
   the violation date in DateFound, and sets DateIsViolation to
   TRUE. If neither such date happens before hitting the mindate,
   sets FoundADate to FALSE. (Note: this should not happen if 
   BackTrackFromDate is >= the task's actual start date, since
   in the worst case the procedure should find that date.)
*)


PROCEDURE BackTrackToFindStartDate (Assignments               : AnAssignmentArray;
                                    NumAssignments            : CARDINAL;
                                    BackTrackFromDate         : ADate;
                                    DoWeUseLateAvailabilities : BOOLEAN;
                                    DoWeAllowOverbookings     : BOOLEAN;
                                VAR DateFound                 : ADate;
                                VAR FoundADate                : BOOLEAN;
                                VAR DateIsViolation           : BOOLEAN);
VAR
    ResourceEvent       : ADate;    
    LevelRequired       : LONGINT;
    i                   : CARDINAL;
    DoWeIgnoreResourceLevels, WeFoundResourceEvent, 
        ResourceEventIsViolation : BOOLEAN;

BEGIN
    FoundADate        := FALSE;
    DateFound         := MinDate;

    i := 0;
    WHILE (i < NumAssignments) DO
        WITH Assignments^[i] DO
            IF Resource^.Type = Employable THEN
                IF (Resource^.LevelThisResource) AND NOT
                   (DoWeAllowOverbookings) THEN
                    LevelRequired := VAL(LONGINT, MaxRatePercent);
                    DoWeIgnoreResourceLevels := FALSE;
                ELSE
                    DoWeIgnoreResourceLevels := TRUE;
                END;    
                FindLatestViolationOrNonVacation (Resource,
                                                  LevelRequired,
                                                  BackTrackFromDate,
                                                  DoWeIgnoreResourceLevels,
                                                  DoWeUseLateAvailabilities,
                                                  ResourceEvent,
                                                  WeFoundResourceEvent,       
                                                  ResourceEventIsViolation);
                IF (WeFoundResourceEvent) THEN
                    FoundADate := TRUE;
                        (* keep track of the latest event and its type *)
                    IF ResourceEvent >= DateFound THEN
                        (* note: we need the >= in the above! *)
                        DateFound := ResourceEvent;                    
                        IF ResourceEventIsViolation THEN
                            DateIsViolation := TRUE;
                        ELSE    
                            DateIsViolation := FALSE;
                        END;            
                    END;
                END;
            END; (* employable resource *)
        END; (* with assignments[i] *)
        INC(i);    
    END; (* loop through resources *)

    (*<DEBUG*)
    IF NOT (FoundADate) THEN
        SendErrorMsg ("BackTrack for dur driven task: no event found");    
    END;
    (*DEBUG>*) 

END BackTrackToFindStartDate;

(* --------- FindLongestAssignment ---------------------------------------
   We have an assignment driven task. This procedure returns the
   Resource, MaxRatePercent, and ToGoDuration, and value of
   LevelThisResource for the assignment
   with the longest ToGoDuration among all employable assignments.
*)

PROCEDURE  FindLongestAssignment(Assignments         : AnAssignmentArray;
                                 ResourceCount       : CARDINAL;
                            VAR  LongestAssignment   : AMiniAsst);
VAR
    i, Longest: CARDINAL;
    ResourceWeUse    : AResourcePointer;
    AsstDuration, LongestDuration  : ADuration;
BEGIN

    LongestDuration := 0;

    FOR i := 0 TO (ResourceCount - 1) DO
        (* note: we know there are some employable resources *)
        WITH Assignments^[i] DO
            ResourceWeUse := Resource;
            IF (ResourceWeUse^.Type = Employable) THEN
                AsstDuration :=DurationOf(MaxRatePercent, YetToGoQuantity);      
                IF AsstDuration >= LongestDuration THEN
                    LongestDuration := AsstDuration;
                    Longest := i;
                END;
           END; (* employable resource *)
        END; (* with asst[i] *)
    END; (* end loop *)

    LongestAssignment.RequiredDuration := LongestDuration;
    LongestAssignment.Resource         := Assignments^[Longest].Resource;
    LongestAssignment.LevellableResource := 
        Assignments^[Longest].Resource^.LevelThisResource;
    LongestAssignment.RequiredLevel    := 
       VAL(LONGINT, Assignments^[Longest].MaxRatePercent);

END FindLongestAssignment;





(* --------------- CheckAsstDrivenDelayThruDate -------------------------
   For an assignment-driven delay task. Given a TrialThruDate, and knowing
   the duration of the longest assignment, determine whether all resources
   are continuously available for their assignment's duration beginning
   at (TrialThruDate + 1 - LongestAsstDuration). 

   If DoWeUseLateAvailabilities is TRUE, the procedure references
   the LateAvailProfile of each resource; otherwise it references
   the regular AvailProfile.

   (Note: TrialThruDate + 1 is the corresponding "EndDate" for TrialThruDate, 
   and   TrialThruDate + 1 - LongestAsstDuration is the corresponding
   task StartDate.) (I.e., EndDate - duration = StartDate.)

   This procedure works backwards, for each assignment, beginning at
   the last date for which the resource must be available, namely
   ThruDate - (LongestAsstDuration - assignment duration).
   If it finds a violation for any assignment, it returns via
   LatestViolationDate the start date of the latest cell with
   the violation, and sets DateIsGood to FALSE. Otherwise, it
   sets DateIsGood to TRUE.
*)


PROCEDURE CheckAsstDrivenDelayThruDate (Assignments          : AnAssignmentArray;
                                        NumAssignments       : CARDINAL;
                                        DoWeAllowOverbookings     : BOOLEAN;
                                        DoWeUseLateAvailabilities : BOOLEAN;
                                        TrialThruDate        : ADate;
                                        LongestAsstDuration  : ADuration;
                                    VAR LatestViolationDate  : ADate;
                                    VAR DateIsGood           : BOOLEAN);
VAR
    i : CARDINAL;
    DurationRequired, AsstDiff : ADuration;
    ResourceTrialThruDate, ResourceStartDate, ResourceEndDate, StartDate,
       ResourceViolationDate   : ADate;
    LevelRequired              : REAL;
    DoWeIgnoreResourceLevels       : BOOLEAN;
BEGIN
        StartDate := TrialThruDate + 1 - LongestAsstDuration;

        i := 0;
        DateIsGood := TRUE;
        WHILE (DateIsGood) AND (i < NumAssignments) DO
            WITH Assignments^[i] DO
                IF Resource^.Type = Employable THEN
                    DurationRequired := DurationOf(MaxRatePercent,
                                                   YetToGoQuantity);
                    AsstDiff := LongestAsstDuration - DurationRequired;
                    ResourceTrialThruDate := TrialThruDate - AsstDiff;
                    IF (Resource^.LevelThisResource) AND
                            NOT (DoWeAllowOverbookings) THEN
                        DoWeIgnoreResourceLevels := FALSE;
                        LevelRequired := FLOAT(MaxRatePercent);
                    ELSE
                        DoWeIgnoreResourceLevels := TRUE;
                        LevelRequired := Zero; (* (not used) *)
                    END;

                    BackCheckResourceDuration(Resource,
                                              ResourceTrialThruDate,
                                              LevelRequired,
                                              DurationRequired,
                                              FALSE,  (* AllowVacations *)
                                              FALSE, (* CountVacations *)
                                              DoWeIgnoreResourceLevels,
                                              DoWeUseLateAvailabilities,
                                              DateIsGood,
                                              ResourceStartDate,
                                              ResourceViolationDate);
                    (*DEBUG*)
                    IF (ResourceViolationDate > ResourceTrialThruDate) 
                          AND NOT (DateIsGood) THEN
                        SendErrorMsg("check asst delay: viol date > thru date!");
                    END;
                    (*DEBUG>*)

                    (*<DEBUG*)
                     IF (DateIsGood) AND (ResourceStartDate <> StartDate) THEN
                        SendErrorMsg("CheckAsstDrivDelay: wrong res start date");
                     END;
                    (*DEBUG>*)

                END; (* employable resource *)
            END; (* with assignments[i] *)
            INC(i);
        END; (* loop thru assignments *)

        IF NOT (DateIsGood) THEN 
            LatestViolationDate := ResourceViolationDate;
        END;


END CheckAsstDrivenDelayThruDate;


(* ----------------- FindLatestDateAllAsstsAvail --------------------------
   For an effort-driven or duration-driven delay task. Finds the
   latest date less than MaxEndDate such that all resources are
   available. If DoWeAllowOverbookings is TRUE, "available" means
   not on vacation. If it is FALSE, it additionally means the
   resource is available at the required level. 

   If DoWeUseLateAvailabilities is TRUE, the procedure references
   the LateAvailProfile of each resource; otherwise it references
   the regular AvailProfile.


   If such a date exists, returns it via TrialThruDate and sets
   FoundDate to TRUE; otherwise sets FoundDate to FALSE.
*)

PROCEDURE  FindLatestDateAllAsstsAvail(Assignments        : AnAssignmentArray;
                                       NumAssignments     : CARDINAL;
                                       MaxEndDate         : ADate;
                                       DoWeAllowOverbookings     : BOOLEAN;
                                       DoWeUseLateAvailabilities : BOOLEAN;
                                   VAR DateFound          : ADate;
                                   VAR FoundADate         : BOOLEAN);

VAR
    OnOrBefore         : ADate;
    PotentialDate      : ADate;
    FoundPotentialDate : BOOLEAN;

BEGIN
    (*<PRINT
    SetString(NoteString,"    LatestDateAllResAvail ");
    SetString(NoteString,"          on or before ");
    CtoS(MaxEndDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    PRINT>*)

    FoundADate := FALSE;
    OnOrBefore := MaxEndDate - 1;
    
    LOOP
        FindMinOfLatestDatesAvailable(Assignments,
                                      NumAssignments,
                                      OnOrBefore,
                                      DoWeAllowOverbookings,
                                      DoWeUseLateAvailabilities,
                                      FoundPotentialDate,
                                      PotentialDate);
             (* If FoundPotentialDate is TRUE, then PotentialDate
                now holds the min over all resources of
                the latest date the resource is available 
                on or before the OnOrBefore date. *)

        IF NOT (FoundPotentialDate) THEN
            (*<PRINT
            SetString(NoteString, " can't find potential date");
            PrintAString(NoteString);
            PRINT>*)
            (* There is no potential start date for the task,
               since some resource was never available
               on or before MaxEndDate. *)
            EXIT; 
        END;                
            
        IF AllResourcesAreAvailable(Assignments,
                                    NumAssignments,
                                    PotentialDate,
                                    FALSE, (* allow vacations *)
                                    DoWeAllowOverbookings,
                                    DoWeUseLateAvailabilities) THEN
            (* We've found it: *)
            FoundADate := TRUE;
            DateFound := PotentialDate;
            EXIT;    
        END;    

        (* Some resource is not available on PotentialDate, 
           so try again from PotentialDate - 1 *)
        IF (PotentialDate > MinDate + 1 ) THEN
            OnOrBefore := PotentialDate - 1;
        ELSE
            EXIT;
        END;
    END; (* end loop *)

    (*<PRINT
    IF FoundADate THEN
        SetString(NoteString,"        latest date all avail-->");
        CtoS(PotentialDate,s);
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
    ELSE
        SetString(NoteString,"        latest date all avail: none <= MaxEndDate");
        PrintAString(NoteString);
    END
    PRINT>*)

END FindLatestDateAllAsstsAvail;





(*------FindMinOfLatestDatesAvailable------------------------------

    Returns, via DateFound, the minimum, over all assignments,
    of the latest date on or before the OnOrBefore date
    such that the resource is available (i.e., such that the
    resource is not on vacation and has the required amount
    available - the second constraint is not active if DoWeAllowOverbookings
    is TRUE).

    For FoundADate to be returned as TRUE, EVERY resource must have
    had some date withing the specified interval for which it is
    available; otherwise it is returned as FALSE.

    (Note that not all the resources are necessarily available    
    on the day returned, but the day returned is at least an upper bound
    on the latest such date.)
*)


PROCEDURE FindMinOfLatestDatesAvailable(Assignments       : AnAssignmentArray;
                                        NumAssignments    : CARDINAL;
                                        OnOrBefore        : ADate;
                                        DoWeAllowOverbookings     : BOOLEAN;
                                        DoWeUseLateAvailabilities : BOOLEAN;
                                    VAR FoundADate        : BOOLEAN;    
                                    VAR DateFound         : ADate);


VAR
    i                    : CARDINAL;
    AmountWeUse          : LONGINT;
    ResourceWeUse        : AResourcePointer;
    MinimumDate          : ADate;
    DoWeIgnoreResourceLevels : BOOLEAN;
    FoundResourceDate    : BOOLEAN;

BEGIN

    (*<PRINT
    SetString(NoteString,"        MinFirstDatesAvail on or before ");
    CtoS(OnOrBefore,s);
    ConcatLS(NoteString,s);    
    PrintAString(NoteString);    
    SetString(NoteString, "   with allow overbookings = ");
    IF DoWeAllowOverbookings THEN ConcatS(NoteString, "TRUE");
    ELSE ConcatS(NoteString, "FALSE"); END; PrintAString(NoteString);
    PRINT>*)

    (*<DEBUG
    IF NumAssignments = 0 THEN
        SendErrorMsg("MinOfFirstDatesAvailable: task has no resources");
        FatalError();
    END;
    DEBUG>*)

    MinimumDate    := OnOrBefore; (* initialization - it can grow lower *)

    (*<PRINT
    SetString(NoteString,  "          min date so far:");  CtoS(MinimumDate,s);
    ConcatLS(NoteString,s);  PrintAString(NoteString);
    PRINT>*)

    FOR i := 0 TO (NumAssignments - 1) DO
        ResourceWeUse := Assignments^[i].Resource;
        (*<PRINT
        SetString(NoteString, "             checking resource ");  ConcatLS(NoteString, ResourceWeUse^.Name);
        PrintAString(NoteString);
        PRINT>*)

        IF (ResourceWeUse^.Type = Employable) THEN
            (* we don't consider or touch non-employable resources in levelling *)
            AmountWeUse  := VAL(LONGINT, Assignments^[i].MaxRatePercent);
            IF (ResourceWeUse^.LevelThisResource) AND NOT (DoWeAllowOverbookings) THEN
                DoWeIgnoreResourceLevels := FALSE;
            ELSE
                DoWeIgnoreResourceLevels := TRUE;
            END;
 
            (* reset MinimumDate to a date on or before current value: *)
            FindLatestDateHaveResourceAmount(ResourceWeUse,                    
                                             AmountWeUse,
                                             MinimumDate, (*OnOrBefore*)
                                             FALSE, (* allow vacations *)
                                             DoWeIgnoreResourceLevels,
                                             DoWeUseLateAvailabilities,
                                             FoundResourceDate,
                                             MinimumDate (* return value *));    
            (*<PRINT
            IF FoundResourceDate THEN
                SetString(NoteString,  "         new min date = ");  
                CtoS(MinimumDate,s);
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
    DateFound := MinimumDate;

    (*<PRINT
    SetString(NoteString,"        MinLatestDatesAvail found date ");  CtoS(DateFound,s);    
    ConcatLS(NoteString,s);  PrintAString(NoteString);
    PRINT>*)
END FindMinOfLatestDatesAvailable;







(* ---------------- CheckUniformDurationDelayThruDate -----------------
   For an effort-driven or duration-driven delay task. Given a TrialThruDate,
   and knowing the required ToGo duration (which is uniform for all
   assignments), determine whether all resources are continuously
   available for that duration beginning at TrialThruDate and working
   backwards. If it finds a violation for any assignments, it returns
   via LatestViolationDate the start date of the latest cell with
   the violation, and sets DateIsGood fo FALSE. Otherwise, it
   sets DateIsGood to TRUE.

   If DoWeUseLateAvailabilities is TRUE, the procedure references
   the LateAvailProfile of each resource; otherwise it references
   the regular AvailProfile.
*)

PROCEDURE CheckUniformDurationDelayThruDate (Assignments          : AnAssignmentArray;
                                             NumAssignments       : CARDINAL;
                                             DoWeAllowOverbookings     : BOOLEAN;
                                             DoWeUseLateAvailabilities : BOOLEAN;
                                             TrialThruDate        : ADate;
                                             UniformAsstDuration  : ADuration;
                                         VAR LatestViolationDate  : ADate;
                                         VAR DateIsGood           : BOOLEAN);


VAR
    i : CARDINAL;
    ResourceStartDate,
       ResourceViolationDate   : ADate;
    LevelRequired              : REAL;
    DoWeIgnoreResourceLevels       : BOOLEAN;
BEGIN

        i := 0;
        DateIsGood := TRUE;
        WHILE (DateIsGood) AND (i < NumAssignments) DO
            WITH Assignments^[i] DO
                IF Resource^.Type = Employable THEN
                    IF (Resource^.LevelThisResource) AND
                          NOT (DoWeAllowOverbookings) THEN
                        DoWeIgnoreResourceLevels := FALSE;
                        LevelRequired := FLOAT(MaxRatePercent);
                    ELSE
                        DoWeIgnoreResourceLevels := TRUE;
                        LevelRequired := Zero; (* (not used) *)
                    END;
                    BackCheckResourceDuration(Resource,
                                              TrialThruDate,
                                              LevelRequired,
                                              UniformAsstDuration,
                                              FALSE,  (* AllowVacations *)
                                              FALSE, (* CountVacations *)
                                              DoWeIgnoreResourceLevels,
                                              DoWeUseLateAvailabilities,
                                              DateIsGood,
                                              ResourceStartDate,
                                              ResourceViolationDate);
                END; (* employable resource *)
            END; (* with assignments[i] *)
            INC(i);
        END; (* WHILE DateIsGood AND i < NumAssignments *)

        IF NOT (DateIsGood) THEN 
            LatestViolationDate := ResourceViolationDate;
        END;

END CheckUniformDurationDelayThruDate;


END ResLates.




