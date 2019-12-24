IMPLEMENTATION MODULE ResScheduleTaskResources;
(*V2=PRINT WITH debugging printouts. *)
(*V3=DEBUG with assertions verified *)

(* Procedures to "schedule" and "free" resources used by a task
   by updating the resource availability tables.

   MODIFICATION HISTORY

   Dec 4,  90   JES  In BackFindStartDate, removed unnecessary variable
                     DurationFound.
   Dec 6,  90   JES  Added procedure BackCreateSubstitutableResAssignments,
                     the backwards version of CreateSubstitutableResource
                     Assignments.
   
                     In BackFindStartDate, substituted the new procedure
                     BackCellContainingDate for CellContainingDate.
                     This procedure allows us to find a cell that
                     represents the end date of a time period (i.e.,
                     given a date, it finds the cell such that
                     cell start date < date <= cell end date).
                     Thus it removes the problem where BackFindStartDate
                     finds an extraneous first cell if the given 
                     EndDate is actually the end date of some cell.
                     (BackCellContainingDate also happens to search
                     backwards instead of forwards through the linked list.
                     It was created for use by BackCreateSubstitutableRes
                     Assignments but is turning out to be useful for
                     "backwards versions" in general.)
    *)(*
   Dec 11, 90    JES Checked for no-elements condition in FOR loops.
   Dec 17, 90    JES Fixed "BackFindStartDate" so that is HonorVacations
                     parameter is FALSE it just does subtraction
                     instead of passing through the list of cells.
                     (Note: eventually we should remove this parameter.
                     It is always equal to the global HonorDaysOff and
                     is therefore misleading.)
   Dec 14, 90    AJL Changed AssignForInterval and AssignForDuration to 
                     make local copies of the cells instead of locking
                     them, which could cause FlexStor to exceed its lock
                     limit. 
   Dec 27, 1990  AJL In FwdFindDuration, if the end of the period being 
                     searched was during a vacation, the end condition was
                     not noted because vacation cells were totally ignored. 
                     Consequently, we would run past the period, create an
                     end date that preceded the start, and crash with 
                     a cardinal overflow. 
                         Made similar modifications to this procedure, and
                     to FwdFindEndDate and BackFindStartDate. 

   Dec 28, 90 JES - Added VAR parameter AllWorkDone to procedure 
                    BackCreateSubs. This parameter is set to TRUE if
                    all the work can be done without running into 
                    MinDate; otherwise it is set to FALSE (and the 
                    TaskStartDate is set to MinDate).
                  - Added BOOLEAN VAR parameter DurationSatisfied to
                    procedure BackFindStartDate. This parameter is set
                    to TRUE if the required duration can be satisfied
                    without running into MinDate; otherwise it is set
                    to FALSE (and the start date is set to MinDate).
   Jan  3, 90  JES -In CreateSubstitutableResourceAssignments, if
                    there is no effort to be done on the task, sets
                    TaskEndDate to TaskStartDate and returns. (The
                    analog of this was already being done in
                    BackCreateSubstitutableResourceAssignments.)
                    In BackCreateSubstitutableResourceAssignments,
                    set AllWorkDone to TRUE if there is no effort on the
                    task.
                   -In BackFindStartDate, fixed a previous fix that made
                    the procedure end if we happened to be in a vacation cell
                    that would have satisfied the required duration had
                    it not been a vacation cell. (The result was that
                    the procedure erroneously exited without the required 
                    duration being satisfied.) Similarly fixed 
                    FwdFindEndDate.
                   -Added procedure DeactivateTask.                    
   Jan  4, 90  JES -Added procedures AddToLateResourceAvailability and
                     RemoveFromLateResourceAvailability.
   Jan 10, 91  JES -Changed BackCreateSubstitutableResourceAssignments
                    as follows: (1) renamed the in parameter "TaskEndDate"
                    to "MaxEndDate", since it may not be an actual
                    end date in the sense of resources being at work
                    at that date minus 1; (2) added the VAR parameter
                    "TaskEndDate" that contains the actual end date
                    corresponding to the start date returned.
    *)(*
   Jan 11, 91  JES -Removed unused procedure AddToLateResourceAvailability.
                   -Moved procedure CreateVaryingAssignments from
                     ResActiv to here.
                   -To procedure CreateVaryingAssignments and its
                     subsidiaries CreateSubstitutable... and
                     CreateNonSubstitutableResourceAssignments, added
                     parameters:
                      (1)  VAR VAssignments - the varying assignments 
                           structure to be updated
                      (2) a BOOLEAN "DoWeUseLateResidueProfiles" - if no,
                            accesses the usual ResidueAvailProfile of
                            each resource in determining how much to
                            schedule of each resource; if yes, accesses 
                            resources'LateResidueAvailProfile.
                            (This parameter not added to CreateNonSubsti
                             tutable...since no residue availability
                             profiles are referenced by it.)
   Jan 12, 91  AJL -Corrected some of the print statements in DeactivateTask
                    that would not compile.
                   -In BackCreateSubstitutableResourceAssignments, moved
                    the test of PeriodEnd=MinDate from the end of the loop
                    to the beginning, so that it would prevent a FatalError
                    if the loop was ever entered with PeriodEnd=MinDate the
                    first time around.
                   -Test RemainingEffort <= Zero rather than = Zero.
                   -In BackFindStartDate, explicitly check for EndDate =
                    MinDate as an impossible condition.
                   -In the 1/10/91 change, the item (1) created a problem,
                    in that PeriodEnd was being set to MinDate by the 
                    statement PeriodEnd := TaskEndDate, which was now 
                    preceded by TaskEndDate := MinDate.  Replaced this by
                    PeriodEnd := MaxEndDate, restoring the original,
                    pre 1/10/91, meaning.
    Jan 25, 91  JES - Added parameters to DeactivateTask to make it more
                        flexible. Also, moved procedure ActivateTask
                        from ResActivate to here.
    Jan 28, 91  JES -Fixed CreateVaryingAssignments so it handles tasks
                        with no resources correctly (i.e., just sets
                        their end dates and returns).
    Jan 29, 91  JES -Whoops - the above fix was not done correctly (we
                      needed to set the VAR parameter TaskEndDate, not
                      the task's actual end date).
                    Also: fixed bug where CreateNonSubstitutableResource
                     Assignments was setting AssignmentsHandle to
                     Task^.Plan.Assignments even though it was a 
                     parameter. Made this parameter a non-VAR
                     parameter in CreateVaryingAssignments, 
                     CreateSubstitutableResourceAssignments, and
                     CreateNonSubstitutableResourceAssignments.

    Feb 22, 91  JES - Removed parameter HonorVacations from procedures
                      BackFindStartDate, FwdFindEndDate, and FwdFindDuration.
                      They now assume that vacations are always honored
                      (the initial residue availability lists now make
                      vacations invisible if HonorDaysOff is FALSE).
    Feb 22, 91  JES - Removed parameter ScheduleThruVacations from procedures
                      AssignForInterval and AssignForDuration,
                      for the same reason as above.
    Feb 26, 91  JES - Added procedure ActivateInfeasibleTask.
    Mar  6, 91  JES - Added VAR parameter AllWorkDone to procedures
                      ActivateTask, CreateVaryingAssignments,
                      CreateSubstitutableResourceAssignments, and
                      CreateNonSubstitutableResourceAssignments, 
                      to take into account
                      the possibility of running into MaxDate before
                      the task has been completely scheduled.
    *)(*
    Mar  8, 91  JES - Fixed ActivateInfeasibleTask so that instead of
                        scheduling the task at MaxDate - duration,
                        it schedules it at latest antecedant end date.
    Mar 11, 91  JES - Fixed wrong-direction inequality in test for
                        overrun of maxdate in procedure CreateNonSubs...
                        for duration-driven tasks.
    Mar 26, 91 JES  - Changed TimeUtoS's to CtoS's in debugging printouts.
    Mar 27, 91 JES  - ActivateTask now correctly sets the count, rather than    
                      the count2, field to the activation date.
    Mar 28, 91 JES -  In CreateSubstitutableResourceAssignments, the VAR
                      parameter AllWorkDone is now set correctly by
                      checking "RemainingEffort > Zero" instead of
                      "RemainingEffort >= Zero".
    Apr  2, 91 JES -  Added some more print debugging statements.
    Apr  3, 91 JES -  Use new name "ToGoDurationOfEffortDrivenTask"
                      (previously "ToGoDurationOfEffortDelayTask").
    Apr  8, 91 JES -  Setting of the DontBump flag is now done by
                      ActivateTask instead of ActivateCandidates.
    Apr  9, 91 JES -  DeactivateTask now correctly moves deactivated tasks
                      to the unscheduled list in lower bound, rather than
                      early start, order. 
    Apr 10, 91 JES -  In ActivateInfeasibleTask, just set early end to
                        early start (adding duration might cause overflow
                        and is not valid anyway...)
    Apr 12, 91 JES -  In ActivateTask, set count field in all cases (even
                        if not necessary for further processing), for]
                        clarity in debugging.
    Apr 16, 91  JES - Changed name of parameter "ActiveList" in procedure
                      ActivateTask to "ActivationList" (because sometimes
                      we call it with another list).
    Apr 23, 91  JES - Removed unused parameter ActiveList from procedure
                      DeactivateTask.
    Apr. 30, 91 AJL - Added more print tracing.
    May 13, 91  JES - Changed ActivateInfeasibleTask so it sets the
                        early start date only if the task is Future.
    Jun 11, 91  AJL - Made Task a VAR parm to DeactivateTask so that it can
                      be unlocked and relocked.
    Jun 20, 91 JES  - Made ActivateInfeasibleTask set ScheduleComputedOk
                        to FALSE.
    Jun 21, 91 AJL  - Modified FwdFindEndDate to check for the special case
                      of StartDate = MaxDate.
    Jun 24, 91 AJL  - Modified AssignForDuration to check for the special case
                      of StartDate = MaxDate.
                    - Additional, similar bounds checking on other procedures.
    Jun 25, 91 JES  - Made CreateNonSubs... deal with the special case
                        of a duration-driven future tasks with upperbound
                        < AsOfDate, with the MoveFutureTasks flag set.
                        In this case we leave the start date as is, but
                        we cut off any effort (i.e., don't schedule any
                        effort) to the left of the AsOfDate.
    July 2, 91 JES  - Removed setting of ScheduleComputedOk to FALSE in
                        ActivateInfeasibleTask.

    Jul 11, 91  JES - Added Warning parameter to procedure
                        ActivateInfeasibleTask, so we can say either
                        just "Can't schedule task" or the new warning
                        "Can't schedule task - resources overassigned"
                        or whatever other warnings we may choose later.
                    - Turned off debugs.
    Jul 23, 91  JES - In ActivateInfeasibleTask, we set start date to
                        latest antecedant end and end date to that
                        plus task duration, for duration-driven tasks
                        (so they don't get turned into milestones).
    Jan 29, 92  AJL - Changed rate parameters to REAL.
    Feb 11, 92  JES - Changed MaxAllowableUsage to take a MinRate parameter,
                       and hardcoded 2% into the callers.
    Feb 27, 92  JES - Changed MaxAllowableUsage so returns zero instead of
                        error msg if max rate < min rate.
    Mar  3, 92  JES - Changed MaxAllowableUsage so if max rate < min rate,      
                        but max rate was < 2%, it honors the user's entered
                        max rate as the assignment amount.
    Mar 17, 92  AJL - Created procedure GetToGoLevel. 
                    - Using GetToGoLevel, make the
                      CreateNonSubstitutableResourceAssignments procedure 
                      correctly schedule the effort for duration-driven tasks 
                      that have had effort, not level, entered.  Bug 5455.
    Mar 20, 92 AJL  - Modified last change to take vacations into account.
*)

FROM Allocs        IMPORT
    (* TYPE *)          ATaskPtr, ATask, ASplittingRule, ADurationMethod,
                        ATaskStatus, ATempTaskFlag, AStartStatus;

FROM AsOf          IMPORT
    (* VAR *)           AsOfDate;

FROM Assignments   IMPORT
    (* TYPE *)          AnAssignmentArray, AnAssignmentRecord,
    (* PROC *)          DurationOf;

FROM Dialog        IMPORT
    (* PROC *)          FatalError, ErrorPhrase;

FROM FlexStor      IMPORT
    (* TYPE *)          AnExtHandle,
    (* PROC *)          LockObjectArray, ReleaseUnchangedObject, LockObject,
                        ReleaseObject;

FROM LongConvert   IMPORT
    (* PROC *)          RealToLong, LongToReal;

FROM Phantoms      IMPORT
    (* CONST *)         SummaryFlag;


FROM Planner       IMPORT
    (* VAR  *)          ScheduleComputedOk, HonorDaysOff, MoveFutureTasks;

FROM PSortTaskList IMPORT
    (* PROC *)          InsertLockedTaskInOrder;

FROM PTaskList     IMPORT
    (* PROC *)          AddLowDate, DeList,
    (* CONST *)         AlreadyScheduled;


FROM ResAvailableResources IMPORT
    (* PROC *)          ScheduleResource, FreeResource,
                        ScheduleLateResource, FreeLateResource;

FROM ResCal        IMPORT  
    (* TYPE *)          AnAvailabilityCellPointer, AnAvailabilityCell,
    (* PROC *)          CellContainingDate, BackCellContainingDate;

FROM ResConstants  IMPORT
    (* CONST *)         MaxEmployableResourcesPerTask, LongZero, DontBump,
                        TwoPercent,
    (* VAR *)           SchedulingAbandoned;

FROM ResUtilities  IMPORT 
    (* PROC *)          ToGoDurationOfEffortDrivenTask, 
                        TaskUsesNoEmployableResources,
                        LatestAntecedantEndDate,
                        CompTaskByLowerBound,
                        DurationToEffort, EffortToDuration, 
                        GetToGoLevel, Zero; 

FROM ResWarnings   IMPORT
    (* TYPE *)          AWarning,
    (* PROC *)          IssueWarning, SendErrorMsg;

FROM RsrcMod       IMPORT 
    (* TYPE *)          AResourcePointer, AResourceType;

FROM SYSTEM        IMPORT 
    (* PROC *)			SIZE, TSIZE;

FROM Timei         IMPORT
    (* TYPE *)          ADate, ADuration,
    (* CONST*)          MaxDate, MinDate;

FROM Timeu          IMPORT FSMUPH;

FROM VaryAssgnment IMPORT
    (* TYPE *)          AVaryingAssgnList,
    (* PROC *)          GetVaryingAssgnListEntry,
                        CreateVaryingAssgnListRange;

(*  ------------------------ Import if tracing ------------------*)
(*<PRINT
FROM LStrings     IMPORT ConcatS, ConcatLS, CtoS, SetString;
FROM LongConvert  IMPORT LongToString;
FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat; 
FROM ResTrace     IMPORT NoteString, PrintAString, ConcatTaskID,
                         PrintVaryingAssignment;
FROM TimeFormat   IMPORT TimeUtoS;     
VAR
    s : ARRAY [0..255] OF CHAR;
PRINT>*)

CONST

TYPE
    ACellDatum = RECORD
                    AssignmentsIndex : CARDINAL; 
                       (* index to assignments array*)
                    Handle           : AnExtHandle;
                       (* handle to res avail cell for last asst period *)
                    AmountToUse      : REAL;
                       (* amount to use of the resource this period *)
                 END;




    (*<PRINT
    PROCEDURE FtoS( R : REAL; VAR S : ARRAY OF CHAR);
    BEGIN
        FormatAsAmount(R, DefaultAmountFormat, S, 8, 0, 3, FALSE);
    END FtoS;
    PRINT>*)


(*-------------------------------------------------------------------

    RemoveFromResourceAvailability

    Update resource availability tables to reflect scheduling of
    all the Task's resources for the Task's duration beginning
    at the given start date.

    This looks at the varying assignment structures in each assignment
    and removes the assigned amounts from the resources residual
    availability.

    Input : AssignmentArray -- Reference to an assignment array, may
                               be of any size.
            Count           -- Actual number of entries in the array. 

            StartDate       -- Update only on and after this date.
---------------------------------------------------------------------*)

PROCEDURE RemoveFromResourceAvailability(AssignmentArray : AnAssignmentArray;
                                         Count           : CARDINAL;
                                         StartDate       : ADate);
VAR
    i,j : CARDINAL;
    ResourceWeUse   : AResourcePointer;
    Details         : AVaryingAssgnList;
    Start, End      : ADate;
    Rate            : REAL; 
BEGIN
    IF Count = 0 THEN RETURN; END;

    FOR i := 1 TO Count DO
        WITH AssignmentArray^[i-1] DO
            ResourceWeUse := Resource;
            Details       := VaryingAssignment;
        END;

        j := 1;
        WHILE ( GetVaryingAssgnListEntry( Details, j,
                                          Start, End, Rate ))   DO
            IF (Rate <> Zero) AND (StartDate <= End) THEN
                IF Start < StartDate THEN
                    Start := StartDate; (* don't update before StartDate *)
                END;
                ScheduleResource  (ResourceWeUse,
                                   TRUNC(Rate),Start,End);
                IF SchedulingAbandoned THEN
                    RETURN;
                END;
            END;    

            INC(j);   (* Next period. *)
        END;
        
    END;
END RemoveFromResourceAvailability;




(* -------------- RemoveFromLateResourceAvailability ------------------------

   Just like RemoveFromResourceAvailability but references the resources'
   LateResidueAvailProfiles instead of their ResidueAvailProfiles.
*)

PROCEDURE RemoveFromLateResourceAvailability(AssignmentArray : AnAssignmentArray;
                                         Count           : CARDINAL;
                                         StartDate       : ADate);

VAR
    i,j : CARDINAL;
    ResourceWeUse   : AResourcePointer;
    Details         : AVaryingAssgnList;
    Start, End      : ADate;
    Rate            : REAL; 
BEGIN
    IF Count = 0 THEN RETURN; END;

    FOR i := 1 TO Count DO
        WITH AssignmentArray^[i-1] DO
            ResourceWeUse := Resource;
            Details       := VaryingAssignment;
        END;

        j := 1;
        WHILE ( GetVaryingAssgnListEntry( Details, j,
                                          Start, End, Rate ))   DO
            IF (Rate <> Zero) AND (StartDate <= End) THEN
                IF Start < StartDate THEN
                    Start := StartDate; (* don't update before StartDate *)
                END;
                ScheduleLateResource  (ResourceWeUse,
                                       TRUNC(Rate),Start,End);
                IF SchedulingAbandoned THEN
                    RETURN;
                END;
            END;    

            INC(j);   (* Next period. *)
        END;
        
    END;
END RemoveFromLateResourceAvailability;




(*-------------------------------------------------------------------

    AddToResourceAvailability

    Update resource availability tables to reflect UNscheduling of
    all the Task's resources for the Task's duration beginning
    at the given start date.

    This looks at the varying assignmnet structures in each assignment
    and adds back in the assigned amounts to the resources residual
    availability.

    Input : AssignmentArray -- Reference to an assignment array, may
                               be of any size.
            Count           -- Actual number of entries in the array. 

            StartDate       -- Update only on and after this date.
---------------------------------------------------------------------*)

PROCEDURE AddToResourceAvailability(AssignmentArray : AnAssignmentArray;
                                    Count           : CARDINAL;
                                    StartDate       : ADate);
VAR
    i,j : CARDINAL;
    ResourceWeUse   : AResourcePointer;
    Details         : AVaryingAssgnList;
    Start, End      : ADate;
    Rate            : REAL; 
BEGIN

    IF Count = 0 THEN RETURN; END;

    FOR i := 1 TO Count DO
        WITH AssignmentArray^[i-1] DO
            ResourceWeUse := Resource;
            Details       := VaryingAssignment;
        END;

        j := 1;
        WHILE ( GetVaryingAssgnListEntry( Details, j,
                                          Start, End, Rate ))   DO
            IF (Rate <> Zero) AND (StartDate <= End) THEN
                IF Start < StartDate THEN
                    Start := StartDate; (* don't update before StartDate *)
                END;
                FreeResource (ResourceWeUse,
                              TRUNC(Rate),Start,End);
                IF SchedulingAbandoned THEN
                    RETURN;
                END;
            END;    

            INC(j);   (* Next period. *)
        END;
        
    END;
END AddToResourceAvailability;



(* ------- AddToLateResourceAvailability -------------------------------

   Just like AddToResourceAvailability but references the resources'
   LateResidueAvailProfiles instead of their ResidueAvailProfiles.
*)

PROCEDURE AddToLateResourceAvailability(AssignmentArray : AnAssignmentArray;
                                        Count           : CARDINAL;
                                        StartDate       : ADate);
VAR
    i,j : CARDINAL;
    ResourceWeUse   : AResourcePointer;
    Details         : AVaryingAssgnList;
    Start, End      : ADate;
    Rate            : REAL;
BEGIN

    IF Count = 0 THEN RETURN; END;

    FOR i := 1 TO Count DO
        WITH AssignmentArray^[i-1] DO
            ResourceWeUse := Resource;
            Details       := VaryingAssignment;
        END;

        j := 1;
        WHILE ( GetVaryingAssgnListEntry( Details, j,
                                          Start, End, Rate ))   DO
            IF (Rate <> Zero) AND (StartDate <= End) THEN
                IF Start < StartDate THEN
                    Start := StartDate; (* don't update before StartDate *)
                END;
                FreeLateResource (ResourceWeUse,
                                  TRUNC(Rate),Start,End);
                IF SchedulingAbandoned THEN
                    RETURN;
                END;
            END;    

            INC(j);   (* Next period. *)
        END;
        
    END;

END AddToLateResourceAvailability;


PROCEDURE FwdFindEndDate ( Resource          : AResourcePointer;
                           StartDate         : ADate;
                           DurationRequired  : ADuration;
                       VAR DurationSatisfied : BOOLEAN) : ADate;    
VAR
    CellHandle,
    NextHandle     : AnExtHandle;
    Cell           : AnAvailabilityCellPointer;
    Start,
    EndDate        : ADate; 
    Finished       : BOOLEAN;
BEGIN
        (* If no duration or no vacations to consider, do simple
           arithmetic and return: *)
    IF NOT (HonorDaysOff) THEN  (* optimization 12/17 - JES/AJL *)
        RETURN (StartDate + DurationRequired);
    END;

        (* We cannot search for a cell containing MaxDate, and even if
           we could, we need to treat it specially. *)

    IF (StartDate = MaxDate) THEN
        DurationSatisfied := ( DurationRequired = 0);
        RETURN MaxDate;
    END;

        (* Pass thru the list until we've satisfied the duration with
           non-vacation cells: *)
    CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, StartDate);
    IF CellHandle = AnExtHandle(NIL) THEN
        ErrorPhrase(0);
    END;

    Finished := FALSE;
    REPEAT
        IF (LockObject(CellHandle, Cell) <> SIZE(Cell^)) THEN
            FatalError;
        END;
        IF Cell^.IsHeadCell THEN
            Finished := TRUE;
        ELSE
            NextHandle := Cell^.NextCell;
            IF (Cell^.StartDate < StartDate) THEN
                Start := StartDate;
            ELSE
                Start := Cell^.StartDate;
            END;

                (* The cell will be counted only if it is non-vacation: *)
            IF NOT (Cell^.ThisIsAVacation) THEN
                    (* Don't overshoot the required duration: *)
                IF (Cell^.EndDate - Start) >= DurationRequired THEN
                    EndDate  := Start + DurationRequired;
                    Finished := TRUE;
                ELSE
                    EndDate := Cell^.EndDate;
                END;
                DurationRequired := DurationRequired - (EndDate - Start);
            END;
        END;
        ReleaseUnchangedObject(CellHandle);
        Cell := NIL;
        CellHandle := NextHandle;
    UNTIL Finished;

    IF (DurationRequired <= 0 ) THEN
        DurationSatisfied := TRUE;
    ELSE        
        DurationSatisfied := FALSE;
    END;

    RETURN EndDate;

END FwdFindEndDate;


PROCEDURE BackFindStartDate ( Resource         : AResourcePointer;
                              EndDate          : ADate;
                              DurationRequired : ADuration;
                          VAR StartDate        : ADate;
                          VAR DurationSatisfied: BOOLEAN);

VAR
    CellHandle,
    PrevHandle     : AnExtHandle;
    Cell           : AnAvailabilityCellPointer;
    End            : ADate;
    Finished       : BOOLEAN;
BEGIN
        (* If no duration or no vacations to consider, do simple
           arithmetic and return: *)
    IF (DurationRequired = 0 ) OR 
           NOT (HonorDaysOff) THEN  (* optimization *)
        DurationSatisfied := TRUE;
        StartDate := EndDate - DurationRequired;
        RETURN;
    END;

        (* There is no period ending with MinDate. *)
    IF (EndDate = MinDate) THEN
        StartDate := MinDate;
        DurationSatisfied := FALSE;
        RETURN;
    END;

        (* Pass thru the list until we've satisfied the duration with
           non-vacation cells: *)
    CellHandle := BackCellContainingDate(Resource^.ResidueAvailProfile, 
                                         EndDate);
    IF CellHandle = AnExtHandle(NIL) THEN
        ErrorPhrase(0);
    END;

    Finished := FALSE;
    REPEAT
        IF (LockObject(CellHandle, Cell) <> SIZE(Cell^)) THEN
            FatalError;
        END;
        IF Cell^.IsHeadCell THEN
            Finished := TRUE;
        ELSE
            PrevHandle := Cell^.PrevCell;
                (* Set the correct end date (don't overshoot): *)
            IF (Cell^.EndDate > EndDate) THEN
                End := EndDate;
            ELSE
                End := Cell^.EndDate;
            END;

                (* The cell will be counted only if it is non-vacation: *)
            IF NOT (Cell^.ThisIsAVacation) THEN
                    (* Don't overshoot the required duration: *)
                IF (End - Cell^.StartDate) >= DurationRequired THEN
                    StartDate := End - DurationRequired;
                    Finished  := TRUE;
                ELSE
                    StartDate := Cell^.StartDate;
                END;
                DurationRequired := DurationRequired - (End - StartDate);
            END;
        END;
        ReleaseUnchangedObject(CellHandle);
        Cell := NIL;
        CellHandle := PrevHandle;
    UNTIL Finished;

    DurationSatisfied := (DurationRequired = 0);

END BackFindStartDate;




PROCEDURE FwdFindDuration ( Resource       : AResourcePointer;
                            StartDate      : ADate;
                            EndDate        : ADate ) : ADuration;
VAR
    CellHandle,
    NextHandle     : AnExtHandle;
    Cell           : AnAvailabilityCellPointer;
    Start,
    End            : ADate; 
    DurationFound  : ADuration;
    Finished       : BOOLEAN;
BEGIN
    IF (StartDate >= EndDate) THEN
        RETURN 0;
    END;

        (* There is no cell containing MaxDate. *)
    IF (StartDate = MaxDate) THEN
        EndDate := MaxDate;
        RETURN 0;
    END;
               
    CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, StartDate);
    IF CellHandle = AnExtHandle(NIL) THEN
        ErrorPhrase(0);
    END;

    Finished      := FALSE;
    DurationFound := 0;
    REPEAT
        IF (LockObject(CellHandle, Cell) <> SIZE(Cell^)) THEN
            FatalError;
        END;
        IF Cell^.IsHeadCell THEN
            Finished := TRUE;
        ELSE
            NextHandle := Cell^.NextCell;
            IF (Cell^.StartDate < StartDate) THEN
                Start := StartDate;
            ELSE
                Start := Cell^.StartDate;
            END;
            IF (Cell^.EndDate >= EndDate) THEN
                End      := EndDate;
                Finished := TRUE;
            ELSE
                End      := Cell^.EndDate;
            END;
            IF (NOT Cell^.ThisIsAVacation) THEN
                DurationFound := DurationFound + (End - Start);
            END;
        END;
        ReleaseUnchangedObject(CellHandle);
        Cell := NIL;
        CellHandle := NextHandle;
    UNTIL Finished;

    RETURN DurationFound;

END FwdFindDuration;


PROCEDURE AssignForInterval ( Resource              : AResourcePointer;
                              StartDate             : ADate;
                              EndDate               : ADate;
                              RateToSchedule        : REAL;
                          VAR VaryingAssignment     : AVaryingAssgnList);
VAR
    CellHandle,
    NextHandle     : AnExtHandle;
    CellPointer    : AnAvailabilityCellPointer;
    Cell           : AnAvailabilityCell;
    Start,
    End            : ADate;
    Finished       : BOOLEAN;
BEGIN
    (*<PRINT
    SetString(NoteString, "AssignForInterval: assigning resource ");
    ConcatLS(NoteString, Resource^.Name);
    PrintAString(NoteString);
    SetString(NoteString, "    for interval ");
    CtoS(StartDate, s);
    ConcatLS(NoteString, s);
    ConcatS(NoteString, " - ");
    CtoS(EndDate, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    PRINT>*)
    IF (StartDate >= EndDate) THEN
        (*<PRINT
        SetString(NoteString, " start date >= end date - nothing to do");
        PrintAString(NoteString);
        PRINT>*)
        RETURN;
    END;

    IF (StartDate = MaxDate) THEN
        RETURN;
    END;
               
    CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, StartDate);
    IF CellHandle = AnExtHandle(NIL) THEN
        ErrorPhrase(0);
    END;


    Finished      := FALSE;
    REPEAT
            (* Make a local copy of the cell so that we don't need to
               keep it locked.  The CreateVaryingAssgnListRange proc below
               may lock several additional items, and we don't want to
               exceed the (12/90) limit of four locks. *)
        IF (LockObject(CellHandle, CellPointer) = SIZE(Cell)) THEN
            Cell := CellPointer^;
            ReleaseUnchangedObject(CellHandle);
        ELSE
            FatalError;
        END;

        IF Cell.IsHeadCell THEN
            Finished := TRUE;
        ELSE
            NextHandle := Cell.NextCell;
            IF (NOT Cell.ThisIsAVacation) THEN
                IF (Cell.StartDate < StartDate) THEN
                    Start := StartDate;
                ELSE
                    Start := Cell.StartDate;
                END;
                IF (Cell.EndDate >= EndDate) THEN
                    End      := EndDate;
                    Finished := TRUE;
                ELSE
                    End      := Cell.EndDate;
                END;
                (*<PRINT
                            PrintVaryingAssignment(VaryingAssignment);
                            SetString(NoteString, "    CreateVaryingAssgnListRange(  ");
                            CtoS(Start, s);  ConcatLS(NoteString, s);  ConcatS(NoteString, ", ");
                            CtoS(End, s); ConcatLS(NoteString, s);  ConcatS(NoteString,", ");
                            FtoS(RateToSchedule, s); ConcatLS(NoteString, s);
                            ConcatS(NoteString," )");
                            PrintAString(NoteString);
                PRINT>*)
                IF NOT ( CreateVaryingAssgnListRange(
                             VaryingAssignment,
                             Start,
                             End,
                             RateToSchedule ) ) THEN
                    SchedulingAbandoned := TRUE;
                    ScheduleComputedOk  := FALSE;
                    RETURN;
                END;
                (*<PRINT
                            PrintVaryingAssignment(VaryingAssignment);
                PRINT>*)
            END;
        END;
        CellHandle := NextHandle;
    UNTIL Finished OR SchedulingAbandoned;
END AssignForInterval;






PROCEDURE AssignForDuration ( Resource              : AResourcePointer;
                              StartDate             : ADate;
                              DurationToSchedule    : ADuration;
                              RateToSchedule        : REAL;
                          VAR AssignmentEndDate     : ADate;
                          VAR VaryingAssignment     : AVaryingAssgnList;
                          VAR DurationSatisfied     : BOOLEAN);
VAR
    CellHandle,
    NextHandle     : AnExtHandle;
    CellPointer    : AnAvailabilityCellPointer;
    Cell           : AnAvailabilityCell;
    Start          : ADate; 
    Finished       : BOOLEAN;
BEGIN
        (* No cell actually contains MaxDate. *)
    IF (StartDate = MaxDate) THEN
        DurationSatisfied := (DurationToSchedule = 0);
        RETURN;
    END;

    CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, StartDate);
    IF CellHandle = AnExtHandle(NIL) THEN
        ErrorPhrase(0);
    END;

    Finished := FALSE;
    REPEAT
            (* Make a local copy of the cell so that we don't need to
               keep it locked.  The CreateVaryingAssgnListRange proc below
               may lock several additional items, and we don't want to
               exceed the (12/90) limit of four locks. *)
        IF (LockObject(CellHandle, CellPointer) = SIZE(Cell)) THEN
            Cell := CellPointer^;
            ReleaseUnchangedObject(CellHandle);
        ELSE
            FatalError;
        END;

        IF Cell.IsHeadCell THEN
            Finished := TRUE;
        ELSE
            NextHandle := Cell.NextCell;
            IF (NOT Cell.ThisIsAVacation) THEN
                IF (Cell.StartDate < StartDate) THEN
                    Start := StartDate;
                ELSE
                    Start := Cell.StartDate;
                END;
                IF (Cell.EndDate - Start) >= DurationToSchedule THEN
                    AssignmentEndDate  := Start + DurationToSchedule;
                    Finished := TRUE;
                ELSE
                    AssignmentEndDate := Cell.EndDate;
                END;
                IF CreateVaryingAssgnListRange(
                                    VaryingAssignment,
                                    Start,
                                    AssignmentEndDate,
                                    RateToSchedule )  THEN
                    DurationToSchedule := DurationToSchedule - 
                                          ( AssignmentEndDate - Start );
                ELSE
                    SchedulingAbandoned := TRUE;
                    ScheduleComputedOk  := FALSE;
                    RETURN;
                END;
            END;
        END;
        CellHandle := NextHandle;
    UNTIL Finished OR SchedulingAbandoned;

    IF (DurationToSchedule <= 0) THEN
        DurationSatisfied := TRUE;    
    ELSE
        DurationSatisfied := FALSE;
    END;

END AssignForDuration;







(* --- CreateSubstitutableResourceAssignments ------------------

  FUNCTION:

  This procedure operates on effort-driven, split tasks. It calculates
  varying assignments such that the total amount of effort required
  by the task is satisfied by all the resources combined. The resulting
  end date of the task is returned via TaskEndDate. 
  
  IF CreateVAssignments is TRUE, the assignments calculated are 
  actually implemented (i.e., they are created and inserted into
  the task's varying assignment structures). If FALSE, the
  assignments are not implemented but the date that the task
  would end if they were to be implemented is returned via TaskEndDate.
  (The purpose of the parameter is to allow callers to find out
  a hypothetical end date, given a start date for the task, without
  actually creating any assignments.)

  NOTE: THIS PROCEDURE DOES NOT UPDATE RESOURCE AVAILABILITIES!
  (The caller can do that afterwards, if desired.)

  If ForceSchedule is FALSE (the "normal" value), the assignments 
  calculated are allowed to be split around any periods of non-availability
  of a resource (either due to vacation time or resource shortage). That
  is, task-splitting will be allowed. If ForceSchedule is TRUE,
  then vacations are honored (assuming that HonorDaysOff is TRUE)
  but resource availabilities are ignored and each resource is
  always assigned at max rate percent (regardless of its actual
  availability or the value of the Contour parameter - see below).

  If Contour is TRUE and ForceSchedule is FALSE, then
  the procedure allows multi-valued resource 
  assignments with values ranging between 0 and "max rate percent".
  The procedure will always use as much of the resource as is available
  (but never more than max rate percent). 
  
  OVERVIEW OF THE ALGORITHM:

  The procedure tries to create a "breadth-first" set of assignments in 
  order to equalize the elapsed time that each
  resource spends on the task, and thus to minimize the total length 
  of the task. (That is, instead of taking each resource one by one and 
  exhausting it, we instead pass through time periods, using as many
  resources as possible during each period, until all the work is done.)

  The idea is to determine an increasing set of assignment periods.
  For each period we determine a set of "subassignments", that is,
  a set of resources to be used and the amount of each to be used. 
  We always use a resource if it is available (i.e., not blocked by a
  vacation or shortage), and we use as much of the resource as possible
  (determined by the values of the Contour and ForceSchedule parameters, 
  the value of max rate percent in the assignment record, and the 
  amount available of the resource). 

  Each period is defined by 

      PeriodStart = 
         (1) if this is the first period: the task start date (the
             "TaskStartDate" parameter);
         (2) if this is not the first period: the end date of the 
             preceding period.

      PeriodEnd = 
            minimum, over all resources (whether or not used this period),
            of the end date of the availability cell containing the period's
            start date. However, if this date would cause more than
            the remaining amount of work to be done, then it is
            truncated. Specifically:
            
            PeriodEnd = the minimum of the following two dates:

         (1) the minimum, over all resources,
             of the end date of the availability cell containing 
             the period's start date;

         (2) the PeriodStart plus the "average remaining duration",
             where the average remaining duration is defined as
             the remaining effort divided by the "group work rate" for
             this period. (The "group work rate" is simply the sum of
             the levels of all the resources used during the period.)

      Thus, if the PeriodEnd turns out to be (2), then this is the final
      assignment period (since the remaining work will be satisfied
      after making all the assignments in the period).
      
  INTERNAL DESIGN:

  For each period we make two passes through all the resources. In the
  first pass, we determine the level of each resource to be used and
  the tentative period end date (i.e., quantity (1) above). At the end
  of the pass we also calculate the average remaining duration, and
  truncate the period end date if necessary (i.e., to quantity (2) above).

  At the end of the first pass, we know which resources, and how 
  much of each, to use; the PeriodStart and PeriodEnd; and what
  the new remaining effort will be after this period.
  (Namely, decrement the previous remaining effort by
  the (length of this period * group work rate) .) If the new remaining
  effort is zero, we set the out parameter "TaskEndDate" to the 
  PeriodEnd, and the procedure exits.

  The second pass consists of going through the resources and actually
  making the assignments; this pass takes place only if the parameter
  CreateVAssignments is TRUE (and if there were usable resources in 
  this period; if there were no usable resources, we simply set the 
  next PeriodStart to the minimum end date among all the
  resource's availability cells for this period).

  We then continue to the next period, unless the remaining effort is zero.

  ***Note: THIS PROCEDURE DOES NOT UPDATE RESOURCE AVAILABILITIES. It is
  not necessary to update them after each period, since the periods
  are disjoint. (I.e.: updating resource availability for a given period
  j will have no effect on the availability for period (j + 1).)
  It is the caller's responsibility to update resource availabilities if
  desired.***

  (Note: as an optimization, we save, for each resource, the handle of the
  availability cell from the preceding period, to avoid starting the 
  availability-list search from the beginning each time. Since
  resource availabilities are not updated, and thus the cells do not
  change, this is valid.)

   *)

PROCEDURE CreateSubstitutableResourceAssignments (Task                   : ATaskPtr;
                                                  TaskStartDate          : ADate;
                                                  DoWeForceSchedule      : BOOLEAN;
                                                  DoWeUseLateProfiles    : BOOLEAN;
                                                  DoWeContour            : BOOLEAN;
                                                  DoWeCreateVAssignments : BOOLEAN;
                                                  AssignmentHandle       : AnExtHandle;
                                              VAR TaskEndDate    : ADate;
                                              VAR AllWorkDone    : BOOLEAN);
VAR
    Cell                        : AnAvailabilityCellPointer;
    RemainingEffort, SumOfRates,
      WorkThisPeriod            : REAL;
    PeriodStart, PeriodEnd, 
    MinCellEndDate              : ADate;
    PeriodDuration, 
    MinCellDuration,
    AverageRemainingDuration    : ADuration;
    CellHandle                  : AnExtHandle;
    Assignments                 : AnAssignmentArray;
    CellData  : ARRAY [0..MaxEmployableResourcesPerTask-1] OF ACellDatum;
      (* one element for each employable resource *)
    GroupWorkRate               : REAL;
    i, j, CellIndex,
       ResourceCount            : CARDINAL;

BEGIN

    (*<PRINT
    SetString(NoteString,"CreateSubs... ");
    ConcatTaskID(NoteString,Task);
    PrintAString(NoteString);
    SetString(NoteString,"   TaskStartDate     = ");
    CtoS(TaskStartDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"   ForceSchedule      = ");
    IF DoWeForceSchedule THEN ConcatS(NoteString,"TRUE");
    ELSE ConcatS(NoteString,"FALSE");END;
    PrintAString(NoteString);
    SetString(NoteString,"   Contour            = ");
    IF DoWeContour THEN ConcatS(NoteString,"TRUE");
    ELSE ConcatS(NoteString,"FALSE"); END;
    PrintAString(NoteString);
    SetString(NoteString,"   CreateVAssignments = ");
    IF DoWeCreateVAssignments THEN ConcatS(NoteString,"TRUE");
    ELSE ConcatS(NoteString,"FALSE"); END;
    PrintAString(NoteString);
    PRINT>*)

    RemainingEffort := Task^.ToGoSummary.Time * FSMUPH;
    IF RemainingEffort = Zero THEN
        (*<PRINT
        SetString(NoteString, "    no work to do - enddate = startdate");
        PrintAString(NoteString);
        PRINT>*)
        TaskEndDate := TaskStartDate;
        RETURN;
    END;

    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,  
                                        TSIZE(AnAssignmentRecord));

    PeriodStart := TaskStartDate;

    (* initialize the cell data array: *)
    i := 0; (* index into assignments array *)
    j := 0; (* index into cell data array *)
    WHILE (i < ResourceCount) AND (j < MaxEmployableResourcesPerTask) DO
        IF (Assignments^[i].Resource^.Type = Employable) THEN
            CellData[j].AssignmentsIndex := i;
            IF (DoWeUseLateProfiles) THEN
                CellData[j].Handle := 
                    Assignments^[i].Resource^.LateResidueAvailProfile;
            ELSE
                CellData[j].Handle := 
                    Assignments^[i].Resource^.ResidueAvailProfile;
            END;

            CellData[j].AmountToUse := Zero;
            INC(j);
            IF (j = MaxEmployableResourcesPerTask) THEN
                IssueWarning(TooManyResources, Task);                    
                INCL(Task^.TaskStatusSet, NeedsRecalculate);
            END;    
        END;
        INC(i);
    END;
    (* We now have one cell-data entry for every employable resource,
       and the number of them is j. Each entry points to the 
       corresponding assignment array element (and contains the
       head of the availability list for that resource). *)


    (* Loop through assignment periods until no more effort remains: *)

    WHILE (RemainingEffort > Zero) AND (PeriodStart < MaxDate) DO
    (* Each iteration of this loop represents one assignment period. *)
        (*<PRINT
        SetString(NoteString, "");PrintAString(NoteString);
        SetString(NoteString,"  NEW REMAINING EFFORT = ");
        FormatAsAmount(RemainingEffort,DefaultAmountFormat,
                       s, 8, 8,0, FALSE );
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
        SetString(NoteString,  "  PERIOD START     = ");
        CtoS(PeriodStart,s);
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
        PRINT>*)

        (* Step 1: determine amounts of resources to use this period: *)
        SumOfRates := Zero;
        MinCellEndDate := MaxDate;

        FOR CellIndex :=0 TO (j - 1) DO
            i := CellData[CellIndex].AssignmentsIndex;
            CellData[CellIndex].Handle := 
                CellContainingDate(CellData[CellIndex].Handle, PeriodStart);
            IF LockObject(CellData[CellIndex].Handle, Cell) = 0 THEN
                FatalError();
            END;
            CellData[CellIndex].AmountToUse := 
                MaxAllowableUsage(Cell, 
                                  FLOAT(Assignments^[i].MaxRatePercent),
                                  TwoPercent (* min rate *),
                                  Assignments^[i].Resource^.LevelThisResource,
                                  DoWeForceSchedule,
                                  DoWeContour);

            (*<PRINT
            SetString(NoteString,"   Resource: ");
            ConcatLS(NoteString,Assignments^[i].Resource^.Name); 
            PrintAString(NoteString);
            SetString(NoteString,    "      amount this period: ");
            FtoS(CellData[CellIndex].AmountToUse,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            PRINT>*)

            IF Cell^.EndDate < MinCellEndDate THEN
                MinCellEndDate := Cell^.EndDate;
            END;

            IF (CellData[CellIndex].AmountToUse > Zero) THEN
                SumOfRates := SumOfRates + CellData[CellIndex].AmountToUse;
            END;
            ReleaseObject(CellData[CellIndex].Handle);
        END; (* end loop *)

        (* Step 2: Get period end, update remaining effort, and
           assign any usable resources this period: *)

        GroupWorkRate := SumOfRates;
        (*<PRINT
        SetString(NoteString,"  GROUP WORK RATE  = ");
        FormatAsAmount(SumOfRates,DefaultAmountFormat,
                       s, 8, 13,5, FALSE );
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
        PRINT>*)
        IF (GroupWorkRate > Zero) THEN
            AverageRemainingDuration := EffortToDuration(RemainingEffort, 
                                                         GroupWorkRate);
            MinCellDuration := VAL(ADuration, 
                                   MinCellEndDate - PeriodStart);
            IF MinCellDuration < AverageRemainingDuration THEN
                PeriodEnd       := MinCellEndDate;
                PeriodDuration  := MinCellDuration;
                WorkThisPeriod  := DurationToEffort(PeriodDuration, 
                                                    GroupWorkRate);
                RemainingEffort := RemainingEffort - WorkThisPeriod;
            ELSE
                PeriodEnd:= PeriodStart+
                              VAL(ADate, AverageRemainingDuration);
                WorkThisPeriod := RemainingEffort; (* avoid unnec calculation*)
                RemainingEffort := Zero;          
                TaskEndDate := PeriodEnd;
                (*<PRINT
                PeriodDuration := AverageRemainingDuration;
                PRINT>*)
            END;
            (*<PRINT
            SetString(NoteString, "  PERIOD END       = ");
            CtoS(PeriodEnd, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            SetString(NoteString, "  MINCELL DURATION = ");
            CtoS(MinCellDuration,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            SetString(NoteString, "  AVG REM DURATION = ");
            CtoS(AverageRemainingDuration,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            SetString(NoteString, "  PERIOD DURATION  = ");
            CtoS(PeriodDuration,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            SetString(NoteString, "  WORK THIS PERIOD = ");
            FormatAsAmount(WorkThisPeriod, DefaultAmountFormat,
                 s, 8,8,0,FALSE);
            ConcatLS(NoteString,s);PrintAString(NoteString);
            PRINT>*)

            (* make assignments: *)
            IF (DoWeCreateVAssignments) THEN
                (*<PRINT
                SetString(NoteString, "  Creating the assignments:");
                PrintAString(NoteString);
                PRINT>*)
                (* loop through the cell data array: *)
                FOR CellIndex := 0 TO (j - 1) DO
                    IF (CellData[CellIndex].AmountToUse > Zero) THEN
                        i := CellData[CellIndex].AssignmentsIndex;
                        AssignForInterval(Assignments^[i].Resource,
                                          PeriodStart,
                                          PeriodEnd,
                                          CellData[CellIndex].AmountToUse,
                                          Assignments^[i].VaryingAssignment);
                        IF SchedulingAbandoned THEN 
                            ReleaseUnchangedObject(AssignmentHandle);
                            RETURN;
                        END;
                    END; (* amount to use > 0 *)
                END; (* end loop through cell data array *)
            END; (* create assignments *)
            (* get ready for next period: *)
            PeriodStart := PeriodEnd;
        ELSE
            (* no usable resources this period - get ready for next period *)
            (*<PRINT
            SetString(NoteString, "  No usable resources this period.");
            PrintAString(NoteString);
            PRINT>*)
            PeriodStart := MinCellEndDate;
        END; (* there were usable resources *)
    END; (* main loop through periods *)
    ReleaseObject(AssignmentHandle);

    IF (RemainingEffort >Zero) THEN
            (* PeriodStart is MaxDate but couldn't schedule all effort: *)
        AllWorkDone := FALSE;
        (*<PRINT
        SetString(NoteString, "Couldn't schedule all effort.");
        PrintAString(NoteString);
        PRINT>*)
    ELSE
        AllWorkDone := TRUE;
    END;        

    (*<PRINT
    SetString(NoteString, " end of CreateSubstitutableResourceAssignments.");
    PrintAString(NoteString);
    PRINT>*)

END CreateSubstitutableResourceAssignments;




(* ------- BackCreateSubstitutableResAssignments --------------------------
   Just like CreateSubstitutableResourceAssignments, with these differences:
   Instead of given a TaskStartDate and producing a TaskEndDate, this
   procedure takes a MaxTaskEndDate and produces a TaskStartDate. 
   The MaxEndDate may not be the actual end date of the task in the
   sense that a resource is at work at MaxEndDate - 1.
   
   The procedure creates
   assignments backwards in time (starting as close as possible to
   MaxEndDate) until all the work is done. 

   If all the work can be done without hitting MinDate, the procedure
   returns the resulting start date in TaskStartDate and the
   corresponding actual task end date in TaskEndDate, and sets
   AllWorkDone to TRUE. Otherwise, sets TaskStartDate and TaskEndDate
   to MinDate and AllWorkDone to FALSE. *)




PROCEDURE BackCreateSubstitutableResAssignments (Task               : ATaskPtr;
                                                 MaxEndDate         : ADate;
                                                 DoWeForceSchedule      : BOOLEAN;
                                                 DoWeContour            : BOOLEAN;
                                                 DoWeCreateVAssignments    : BOOLEAN;
                                                 DoWeUseLateAvailabilities : BOOLEAN;
                                             VAR TaskStartDate      : ADate;
                                             VAR TaskEndDate        : ADate;
                                             VAR AllWorkDone        : BOOLEAN);
VAR
    Cell                        : AnAvailabilityCellPointer;
    RemainingEffort, SumOfRates,
      WorkThisPeriod            : REAL;
    PeriodStart, PeriodEnd, 
    MaxCellStartDate              : ADate;
    PeriodDuration, 
    MinCellDuration,
    AverageRemainingDuration    : ADuration;
    AssignmentHandle, CellHandle: AnExtHandle;
    Assignments                 : AnAssignmentArray;
    CellData  : ARRAY [0..MaxEmployableResourcesPerTask-1] OF ACellDatum;
      (* one element for each employable resource *)
    GroupWorkRate               : REAL;
    i, j, CellIndex,
       ResourceCount            : CARDINAL;
    EndDateSet                  : BOOLEAN;


BEGIN
    (*<DEBUG
    IF (Task^.DurationMethod <> EffortDriven) OR 
       (Task^.SplittingRule <> Split) THEN
       SendErrorMsg("Called create subs for non effort split task!");
       FatalError();
    END;
    DEBUG>*)

    (*<PRINT
    SetString(NoteString,"BackCreateSubs... ");
    ConcatTaskID(NoteString,Task);
    PrintAString(NoteString);
    SetString(NoteString,"   MaxEndDate     = ");
    CtoS(MaxEndDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"   DoWeForceSchedule      = ");
    IF DoWeForceSchedule THEN ConcatS(NoteString,"TRUE");
    ELSE ConcatS(NoteString,"FALSE");END;
    PrintAString(NoteString);
    SetString(NoteString,"   DoWeContour            = ");
    IF DoWeContour THEN ConcatS(NoteString,"TRUE");
    ELSE ConcatS(NoteString,"FALSE"); END;
    PrintAString(NoteString);
    SetString(NoteString,"   CreateVAssignments = ");
    IF DoWeCreateVAssignments THEN ConcatS(NoteString,"TRUE");
    ELSE ConcatS(NoteString,"FALSE"); END;
    PrintAString(NoteString);
    SetString(NoteString,"   UseLateAvailabilities = ");
    IF DoWeUseLateAvailabilities THEN ConcatS(NoteString,"TRUE");
    ELSE ConcatS(NoteString,"FALSE"); END;
    PrintAString(NoteString);
    PRINT>*)

    RemainingEffort := Task^.ToGoSummary.Time * FSMUPH;
    IF RemainingEffort = Zero THEN
        (*<PRINT
        SetString(NoteString,   " no work to do: startdate = enddate");
        PrintAString(NoteString);
        PRINT>*)
        AllWorkDone := TRUE;
        TaskStartDate := MaxEndDate;
        TaskEndDate := MaxEndDate;
        RETURN;
    END;

    AllWorkDone := FALSE;
    EndDateSet  := FALSE;
    TaskEndDate := MinDate; 

    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,  
                                        TSIZE(AnAssignmentRecord));

    PeriodEnd := MaxEndDate;

    (* initialize the cell data array: *)
    i := 0; (* index into assignments array *)
    j := 0; (* index into cell data array *)
    WHILE (i < ResourceCount) AND (j < MaxEmployableResourcesPerTask) DO
        IF (Assignments^[i].Resource^.Type = Employable) THEN
            CellData[j].AssignmentsIndex := i;
            IF (DoWeUseLateAvailabilities) THEN
                CellData[j].Handle := 
                    Assignments^[i].Resource^.LateResidueAvailProfile;
            ELSE
                CellData[j].Handle := 
                    Assignments^[i].Resource^.ResidueAvailProfile;
            END;
            CellData[j].AmountToUse := Zero;
            INC(j);
            IF (j = MaxEmployableResourcesPerTask) THEN
                IssueWarning(TooManyResources, Task);                    
                INCL(Task^.TaskStatusSet, NeedsRecalculate);
            END;    
        END;
        INC(i);
    END;
    (* We now have one cell-data entry for every employable resource,
       and the number of them is j. Each entry points to the 
       corresponding assignment array element (and contains the
       head of the availability list for that resource). *)


    (* Loop through assignment periods until no more effort remains: *)

    WHILE (RemainingEffort > Zero) AND (PeriodEnd > MinDate) DO
    (* Each iteration of this loop represents one assignment period. *)
        (*<PRINT
        SetString(NoteString, "");PrintAString(NoteString);
        SetString(NoteString,"  NEW REMAINING EFFORT = ");
        FormatAsAmount(RemainingEffort,DefaultAmountFormat,
                       s, 8, 8,0, FALSE );
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
        SetString(NoteString,  "  PERIOD END     = ");
        CtoS(PeriodEnd,s);
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
        PRINT>*)

        (* Step 1: determine amounts of resources to use this period: *)
        SumOfRates := Zero;
        MaxCellStartDate := MinDate;

        FOR CellIndex :=0 TO (j - 1) DO
            i := CellData[CellIndex].AssignmentsIndex;
            CellData[CellIndex].Handle := 
                BackCellContainingDate(CellData[CellIndex].Handle, PeriodEnd);
            IF LockObject(CellData[CellIndex].Handle, Cell) = 0 THEN
                FatalError();
            END;

            CellData[CellIndex].AmountToUse := 
                MaxAllowableUsage(Cell, 
                                  FLOAT(Assignments^[i].MaxRatePercent),
                                  TwoPercent, (* min rate *)
                                  Assignments^[i].Resource^.LevelThisResource,
                                  DoWeForceSchedule,
                                  DoWeContour);

            (*<PRINT
            SetString(NoteString,"   Resource: ");
            ConcatLS(NoteString,Assignments^[i].Resource^.Name); 
            PrintAString(NoteString);
            SetString(NoteString,    "      amount this period: ");
            FtoS(CellData[CellIndex].AmountToUse,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            PRINT>*)

            IF Cell^.StartDate > MaxCellStartDate THEN
                MaxCellStartDate := Cell^.StartDate;
            END;

            IF (CellData[CellIndex].AmountToUse > Zero) THEN
                SumOfRates := SumOfRates + CellData[CellIndex].AmountToUse;
            END;
            ReleaseObject(CellData[CellIndex].Handle);
        END; (* end loop *)

        (* Step 2: Get period start, update remaining effort, and
           assign any usable resources this period; also set
           TaskEndDate if not previously set and if there are
           usable resources: *)

        GroupWorkRate := SumOfRates;
        (*<PRINT
        SetString(NoteString,"  GROUP WORK RATE  = ");
        FormatAsAmount(SumOfRates,DefaultAmountFormat,
                       s, 8, 13,5, FALSE );
        ConcatLS(NoteString,s);
        PrintAString(NoteString);
        PRINT>*)
        IF (GroupWorkRate > Zero) THEN
            IF NOT (EndDateSet) THEN
                EndDateSet := TRUE;
                TaskEndDate := PeriodEnd;
            END;

            AverageRemainingDuration := EffortToDuration(RemainingEffort, 
                                                         GroupWorkRate);
            MinCellDuration := VAL(ADuration, 
                                   PeriodEnd - MaxCellStartDate);
            IF MinCellDuration < AverageRemainingDuration THEN
                PeriodStart     := MaxCellStartDate;
                PeriodDuration  := MinCellDuration;
                RemainingEffort := RemainingEffort - 
                    DurationToEffort(PeriodDuration, GroupWorkRate);
            ELSE
                PeriodStart:= PeriodEnd -
                              VAL(ADate, AverageRemainingDuration);
                RemainingEffort := Zero; (* avoids redundant calculation *)
                TaskStartDate := PeriodStart;
                (*<PRINT
                PeriodDuration := AverageRemainingDuration;
                PRINT>*)
            END;
            (*<PRINT
            SetString(NoteString, "  PERIOD START       = ");
            CtoS(PeriodStart, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            SetString(NoteString, "  PERIOD DURATION  = ");
            CtoS(PeriodDuration,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            SetString(NoteString, "  WORK THIS PERIOD = ");
            WorkThisPeriod := DurationToEffort(PeriodDuration,GroupWorkRate);
            FormatAsAmount(WorkThisPeriod, DefaultAmountFormat,
                 s, 8,13,5,FALSE);
            ConcatLS(NoteString,s);PrintAString(NoteString);
            PRINT>*)

            (* make assignments: *)
            IF (DoWeCreateVAssignments) THEN
                (*<PRINT
                SetString(NoteString, "  Creating the assignments:");
                PrintAString(NoteString);
                PRINT>*)
                (* loop through the cell data array: *)
                FOR CellIndex := 0 TO (j - 1) DO
                    IF (CellData[CellIndex].AmountToUse > Zero) THEN
                        i := CellData[CellIndex].AssignmentsIndex;
                        AssignForInterval(Assignments^[i].Resource,
                                          PeriodStart,
                                          PeriodEnd,
                                          CellData[CellIndex].AmountToUse,
                                          Assignments^[i].VaryingAssignment);
                        IF SchedulingAbandoned THEN 
                            ReleaseUnchangedObject(AssignmentHandle);
                            RETURN;
                        END;
                    END; (* amount to use > 0 *)
                END; (* end loop through cell data array *)
            END; (* create assignments *)
            (* get ready for next period: *)
            PeriodEnd := PeriodStart;  

        ELSE
            (* no usable resources this period - get ready for next period *)
            (*<PRINT
            SetString(NoteString, "  No usable resources this period.");
            PrintAString(NoteString);
            PRINT>*)
            PeriodEnd := MaxCellStartDate;
        END; (* there were usable resources *)
    END; (* main loop through periods *)

        (* check that we're not at the beginning of time: *)
    IF (RemainingEffort <= Zero) THEN
        AllWorkDone := TRUE;
    ELSE
        (*<PRINT
        SetString(NoteString, " BackCreateSubs: ran into MinDate");
        PrintAString(NoteString);
        PRINT>*)
        AllWorkDone := FALSE;
    END;

    ReleaseObject(AssignmentHandle);

    (*<PRINT
    SetString(NoteString, " end of BackCreateSubstitutableResAssignments.");
    PrintAString(NoteString);
    PRINT>*)

END BackCreateSubstitutableResAssignments;





(* ---- CreateNonSubstitutableResourceAssignments ------------------------------------
    compute a varying assignment for given fixed duration and level
    for each resource assigned to the
    task, and add it to the varying assignment structure of the
    resource assignment record. Return the task end date (highest
    end date of all assignments).
*)

PROCEDURE CreateNonSubstitutableResourceAssignments(Task             : ATaskPtr;
                                                    TaskStartDate    : ADate;
                                                    AssignmentHandle : AnExtHandle;
                                                VAR TaskEndDate      : ADate;
                                                VAR AllWorkDone      : BOOLEAN);

VAR
    Assignments           : AnAssignmentArray;
    ResourceCount, i      : CARDINAL;
    Resource              : AResourcePointer;
    ToGoDuration          : ADuration;
    ToGoLevel             : REAL;
    AssignmentEndDate     : ADate;
    DurationSatisfied     : BOOLEAN;
BEGIN
      TaskEndDate := TaskStartDate; (* initialization *)

      (* loop through the resources, computing a varying assignment for
         each one: *)
      ResourceCount    := LockObjectArray(AssignmentHandle,
                                          Assignments,  
                                          TSIZE(AnAssignmentRecord));

      IF ResourceCount = 0 THEN RETURN; END;    

      AllWorkDone := TRUE; (* we will set to FALSE if we find a problem *)
      FOR i:= 0 TO (ResourceCount - 1) DO
          Resource := Assignments^[i].Resource;
              (* we don't create assignment structures for non-emp resources *)
          IF (Resource^.Type = Employable) THEN

              (*<PRINT
                  SetString(NoteString, " scheduling ");
                  ConcatLS(NoteString,Resource^.Name);
                  PrintAString(NoteString);
              PRINT>*)

              IF (Task^.DurationMethod =DurationDriven) THEN 
                        (*  Special case: for duration-driven task
                            with upper bound in conflict with asof date,
                            we don't schedule any effort before the
                            asof date: 
                        *)
                     IF (TaskStartDate < AsOfDate) AND 
                        (Task^.StartStatus = FutureS) AND
                        (MoveFutureTasks) THEN
                        TaskStartDate := AsOfDate;
                     END;      

                     IF (TaskStartDate <=
                          MaxDate - VAL(ADate, Task^.duration)) THEN
                          AssignmentEndDate := TaskStartDate + VAL(ADate, Task^.duration);
                     ELSE
                          AllWorkDone := FALSE; (* we ran into MaxDate *)
                          AssignmentEndDate := MaxDate;
                     END;
                     ToGoDuration := FwdFindDuration(Resource, TaskStartDate, 
                                                AssignmentEndDate);

                     (* Determine whether the rate is entered by the user, or will 
                        be computed based on the to go effort. *)

                     ToGoLevel := GetToGoLevel( Task, Assignments^[i], ToGoDuration );

                     (*<PRINT
                     SetString(NoteString, "   for interval ");
                     CtoS(TaskStartDate, s); ConcatLS(NoteString, s);
                     CtoS(AssignmentEndDate, s); ConcatS(NoteString, "- ");
                     ConcatLS(NoteString, s);
                     ConcatS(NoteString, " @ "); FtoS( ToGoLevel, s );
                     ConcatLS(NoteString, s);
                     PrintAString(NoteString);
                     PRINT>*)
                     AssignForInterval (Resource,
                                        TaskStartDate,
                                        AssignmentEndDate,
                                        ToGoLevel,
                                        Assignments^[i].VaryingAssignment);

              ELSIF (Task^.DurationMethod = EffortDriven) THEN
                     ToGoLevel := FLOAT(Assignments^[i].MaxRatePercent);  (* Rate entered on assignment form. *)
                (* must be a delay task, since eff-split handled in diff proc*)
                     ToGoDuration := ToGoDurationOfEffortDrivenTask(Task);
                     (*<PRINT
                     SetString(NoteString, " from date ");
                     CtoS(TaskStartDate, s);
                     ConcatLS(NoteString, s);
                     ConcatS(NoteString, "   for duration ");
                     CtoS(ToGoDuration, s);
                     ConcatLS(NoteString, s);
                     ConcatS(NoteString, " @ "); FtoS( ToGoLevel, s );
                     ConcatLS(NoteString, s);
                     PrintAString(NoteString);
                     PRINT>*)
                     AssignForDuration( Resource, 
                                        TaskStartDate, 
                                        ToGoDuration,
                                        ToGoLevel, 
                                        AssignmentEndDate,
                                        Assignments^[i].VaryingAssignment,
                                        DurationSatisfied);
                     IF NOT (DurationSatisfied) THEN
                         (*<PRINT
                         SetString(NoteString, " couldn't satisfy duration");
                         PrintAString(NoteString);
                         PRINT>*)
                         AllWorkDone := FALSE;
                     END;
              ELSE (* task is assignment driven *)
                     WITH Assignments^[i] DO
                         ToGoLevel := FLOAT(MaxRatePercent);  (* Rate entered on assignment form. *)
                         ToGoDuration := DurationOf(MaxRatePercent, 
                                                    YetToGoQuantity);
                     END;
                     (*<PRINT
                     SetString(NoteString, " from date ");
                     CtoS(TaskStartDate, s);
                     ConcatLS(NoteString, s);
                     ConcatS(NoteString, "   for duration ");
                     CtoS(ToGoDuration, s);
                     ConcatLS(NoteString, s);
                     ConcatS(NoteString, " @ "); FtoS( ToGoLevel, s );
                     ConcatLS(NoteString, s);
                     PrintAString(NoteString);
                     PRINT>*)
                     AssignForDuration( Resource, 
                                        TaskStartDate, 
                                        ToGoDuration,
                                        ToGoLevel, 
                                        AssignmentEndDate,
                                        Assignments^[i].VaryingAssignment,
                                        DurationSatisfied);
                     IF NOT (DurationSatisfied) THEN
                         (*<PRINT
                         SetString(NoteString, " couldn't satisfy duration");
                         PrintAString(NoteString);
                         PRINT>*)
                         AllWorkDone := FALSE;
                     END;
              END;
 
              IF SchedulingAbandoned THEN 
                   ReleaseObject(AssignmentHandle);
                   RETURN;
              END;
              IF AssignmentEndDate > TaskEndDate THEN
                  TaskEndDate := AssignmentEndDate;
              END;
          END (* employable resource *)
       END; (* end loop *)
       ReleaseObject(AssignmentHandle);

END CreateNonSubstitutableResourceAssignments;





(* ---- MaxAllowableUsage ---------------------------------------------
   Given an availability cell and information about the resource
   and levelling constants, determine how much of the resource
   to use for the duration of this cell. 
*)


PROCEDURE MaxAllowableUsage(Cell               : AnAvailabilityCellPointer;
                            MaxRate            : REAL;
                            MinRate            : REAL;
                            LevellableResource : BOOLEAN;
                            ForceSchedule      : BOOLEAN;
                            Contour            : BOOLEAN) : REAL;
VAR
    CellAmount, AllowableUsage : REAL;
BEGIN
    IF (MaxRate < TwoPercent) THEN
        (* max rate is less than the allowable 2%, which has
           been hardwired in as the min rate for now - in this case, the
           user has specifically requested an assignment of less than
           2%, so we will honor it - fixes bug 5447 - 3/3/92, JES *)
        CellAmount := LongToReal(Cell^.AmountAvailable);
        IF (CellAmount >= MaxRate) THEN
            AllowableUsage := MaxRate;
        ELSE
            AllowableUsage := Zero;
        END;
    ELSIF (MaxRate < MinRate) THEN
        AllowableUsage := Zero;  (* this should be checked in the UI in future *)
    ELSIF (Cell^.ThisIsAVacation AND HonorDaysOff) THEN 
        (* note: we honor vacations even if this is not a levellable resource! *)
        AllowableUsage := Zero;
    ELSIF (ForceSchedule) OR NOT (LevellableResource) THEN
        AllowableUsage := MaxRate;
    ELSE
        CellAmount := LongToReal(Cell^.AmountAvailable);
        IF (CellAmount >= MaxRate) THEN
            AllowableUsage := MaxRate;
        ELSIF (Contour) AND (CellAmount >= MinRate) THEN 
            AllowableUsage := CellAmount;
        ELSE
            AllowableUsage := Zero;
        END;
    END;
    RETURN AllowableUsage;
END MaxAllowableUsage;




(* ------- DeactivateTask ----------------------------

        (see def for description)

*)


PROCEDURE DeactivateTask (    TaskHandle                    : AnExtHandle;
                          VAR Task                          : ATaskPtr;
                              DeactivationStartDate         : ADate;
                              UnscheduledList               : AnExtHandle;
                              DoWeRemoveVaryingAssignments  : BOOLEAN;
                              DoWeFreeTaskResources         : BOOLEAN;
                              DoWeMoveToUnscheduledList     : BOOLEAN);

VAR
    ResourceCount,  j  : CARDINAL;
    AssignmentHandle   : AnExtHandle;
    Assignments        : AnAssignmentArray;
BEGIN

    (*<PRINT
    SetString(NoteString, "   deactivating task ");
    ConcatTaskID(NoteString,Task);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    PRINT>*)

    AssignmentHandle := Task^.Plan.Assignments;


        (* remove from the active list: *)
    IF (DoWeMoveToUnscheduledList) THEN
        (*<PRINT
        SetString(NoteString, "   removing from active list: ");
        PrintAString(NoteString);
        PRINT>*)
        DeList(TaskHandle);
    END;

        (* Don't keep too many things locked at once. *)
    ReleaseObject(TaskHandle);       (*<KILL*) Task := NIL; (*KILL>*)

        (* free assigned resources (update residue availabilities): *)
    IF (DoWeFreeTaskResources) THEN
        (*<PRINT
        SetString(NoteString, "    updating residue availabilities:");
        PrintAString(NoteString);
        PRINT>*)

        ResourceCount    := LockObjectArray(AssignmentHandle,
                                            Assignments,
                                            TSIZE(AnAssignmentRecord));
        AddToResourceAvailability(Assignments,
                                  ResourceCount,
                                  DeactivationStartDate);
        IF SchedulingAbandoned THEN
            ScheduleComputedOk := FALSE;
            ReleaseObject(AssignmentHandle);
            RETURN;
        END;

    END;


        (* update the varying assignment structures: *)
    IF (DoWeRemoveVaryingAssignments) THEN
        (*<PRINT
        SetString(NoteString, "    removing varying assignments:");
        PrintAString(NoteString);
        PRINT>*)

        (* lock assignments, if we didn't already do this: *)
        IF NOT (DoWeFreeTaskResources) THEN
            ResourceCount    := LockObjectArray(AssignmentHandle,
                                                Assignments,
                                                TSIZE(AnAssignmentRecord));
        END;

        j := 0;
        LOOP
            IF j = ResourceCount THEN EXIT; END;
            (*<PRINT
            PrintVaryingAssignment(Assignments^[j].VaryingAssignment);
            SetString(NoteString, "    set 0 asst for ");
            ConcatLS(NoteString, Assignments^[j].Resource^.Name);
            ConcatS(NoteString," as of ");
            CtoS(DeactivationStartDate,s); ConcatLS(NoteString,s);
            PrintAString(NoteString);
            PRINT>*)
            IF NOT (CreateVaryingAssgnListRange
                               (Assignments^[j].VaryingAssignment,
                                DeactivationStartDate,
                                MaxDate,
                                Zero)) THEN
                SchedulingAbandoned := TRUE;
                ScheduleComputedOk := FALSE;
                ReleaseObject(AssignmentHandle);
                RETURN;
            END;

            (*<PRINT
            PrintVaryingAssignment(Assignments^[j].VaryingAssignment);
            PRINT>*)

            INC(j);
         END;
    END;

        (* release assignments, if we locked them: *)
     IF (DoWeFreeTaskResources) OR (DoWeRemoveVaryingAssignments) THEN
         ReleaseObject(AssignmentHandle);
     END;
     
         (* Lock the task again. *)
     j := LockObject(TaskHandle,Task);

        (* add the task to the unscheduled list, in lower bound order: *)
     IF (DoWeMoveToUnscheduledList) THEN
         (*<PRINT
         SetString(NoteString, "  moving task to unscheduled list:");
         PrintAString(NoteString);
         PRINT>*)
         InsertLockedTaskInOrder(UnscheduledList, TaskHandle, Task,
                                    CompTaskByLowerBound);
     END;

END DeactivateTask;



PROCEDURE CreateVaryingAssignments (Task                : ATaskPtr;
                                    TaskStartDate       : ADate;
                                    DoWeForceSchedule   : BOOLEAN;
                                    DoWeUseLateProfiles : BOOLEAN;
                                    AssignmentHandle    : AnExtHandle;
                                VAR TaskEndDate         : ADate;
                                VAR AllWorkDone         : BOOLEAN);
BEGIN

        (* first dispense with tasks that have no employable resources: *)
    IF (TaskUsesNoEmployableResources(Task)) THEN
        (*<PRINT
        SetString(NoteString, "  task uses no employable resources:");
        PrintAString(NoteString);
        PRINT>*)

        IF (Task^.DurationMethod = DurationDriven) THEN
            (*<PRINT
            SetString(NoteString, "duration-driven task:");
            PrintAString(NoteString);
            PRINT>*)

            IF (TaskStartDate <= MaxDate - Task^.duration) THEN
                TaskEndDate := TaskStartDate + Task^.duration;
                AllWorkDone := TRUE;
                (*<PRINT
                SetString(NoteString, "task fits - end date = ");
                CtoS(TaskEndDate, s);
                ConcatLS(NoteString, s);
                PrintAString(NoteString);
                PRINT>*)

            ELSE
                (*<PRINT
                SetString(NoteString, "task would overrun maxdate - setting end date to maxdate");
                PrintAString(NoteString);
                PRINT>*)
                TaskEndDate := MaxDate;
                AllWorkDone := FALSE;
            END;
        ELSE
            (*<PRINT
            SetString(NoteString, "task not dur-driven - setting end date = start date");
            PrintAString(NoteString);
            PRINT>*)
            TaskEndDate := TaskStartDate;
            AllWorkDone := TRUE;
        END;
        RETURN;
    END;


    IF (Task^.DurationMethod = EffortDriven) AND (Task^.SplittingRule = Split) THEN
        (*<PRINT
        SetString(NoteString, "creating substitutable resource assts:");
        PrintAString(NoteString);
        PRINT>*)
        CreateSubstitutableResourceAssignments (Task, 
                                                TaskStartDate, 
                                                DoWeForceSchedule,
                                                DoWeUseLateProfiles,
                                                TRUE (* DoWeContour - later this
                                                  can be optional *),
                                                TRUE (* DoWeCreateVAssignments *),
                                                AssignmentHandle,
                                                TaskEndDate,
                                                AllWorkDone);
        (*<PRINT
        SetString(NoteString, "after create subs, task end date =");
        CtoS(TaskEndDate, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        SetString(NoteString, "all work done = ");
        IF AllWorkDone THEN ConcatS(NoteString, "TRUE");
          ELSE ConcatS(NoteString, "FALSE"); END;
        PrintAString(NoteString);
        PRINT>*)
    ELSE
        (* note: DoWeForceSchedule and DoWeUseLateProfiles are
            not relevant in this case *)
        (*<PRINT
        SetString(NoteString, "creating non-substitutable resource assignments:");
        PrintAString(NoteString);
        PRINT>*)
        CreateNonSubstitutableResourceAssignments(Task, 
                                                  TaskStartDate,
                                                  AssignmentHandle,
                                                  TaskEndDate,
                                                  AllWorkDone);
        (*<PRINT
        SetString(NoteString, "after create nonsubs, task end date =");
        CtoS(TaskEndDate, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        SetString(NoteString, "all work done = ");
        IF AllWorkDone THEN ConcatS(NoteString, "TRUE");
          ELSE ConcatS(NoteString, "FALSE"); END;
        PrintAString(NoteString);
        PRINT>*)

    END;
END CreateVaryingAssignments;


(*------ ActivateTask------------------------------------------

   See description in def part.

*)

PROCEDURE ActivateTask (TaskHandle        : AnExtHandle;
                        Task              : ATaskPtr;
                        ScheduleAtDate    : ADate;
                        DoWeForceSchedule : BOOLEAN;
                        ActivationList    : AnExtHandle;
                    VAR AllWorkDone       : BOOLEAN);
VAR
    AssignmentHandle : AnExtHandle;
    Assignments        : AnAssignmentArray;
    TaskEndDate        : ADate;
    ResourceCount      : CARDINAL;

BEGIN

(*<PRINT
  SetString(NoteString,"ACTIVATING ");
  ConcatTaskID(NoteString,Task);
  ConcatS(NoteString," on ");
  CtoS(ScheduleAtDate,s);
  ConcatLS(NoteString,s);
  PrintAString(NoteString);
PRINT>*)

        (* First dispense with AlreadyScheduled and Summary tasks: *)

        (* If the task is "AlreadyScheduled", then cpm has
           already created varying assignments and set the early start
           and end. All we do here is move the task to the active list: *)
    IF (AlreadyScheduled IN Task^.TempTaskFlags) THEN
        (*<PRINT
        SetString(NoteString, "task is AlreadyScheduled - just move to active list");
        PrintAString(NoteString);
        PRINT>*)
     (* set the dont bump flag and move the task to the active list - 
        everything else has been done by cpm: *)
       INCL(Task^.TempTaskFlags,DontBump); 
       Task^.count := Task^.Plan.Dates.EarlyStart;
       AllWorkDone := TRUE;
       DeList(TaskHandle);
       AddLowDate(ActivationList,TaskHandle,Task);  (* Must be in sorted order. *)
       RETURN;
    END;

        (* deal with summary task: *)
    IF (SummaryFlag IN Task^.TempTaskFlags) THEN
        (*<PRINT
        SetString(NoteString, "summary task: set start=end and move to active list");
        PrintAString(NoteString);
        PRINT>*)
        AllWorkDone := TRUE;
        Task^.count := ScheduleAtDate;
        Task^.Plan.Dates.EarlyStart := ScheduleAtDate;
        Task^.Plan.Dates.EarlyEnd   := ScheduleAtDate;
        DeList(TaskHandle);
        AddLowDate(ActivationList,TaskHandle,Task);  (* Must be in sorted order. *)
        RETURN;
    END;


    (* in all other cases, set count field to ScheduleAtDate: *)
    Task^.count := ScheduleAtDate;


    (* 1. Set the task's early start date, if task is Future: *)
    IF (Task^.StartStatus = FutureS) THEN
        Task^.Plan.Dates.EarlyStart := ScheduleAtDate;
    END;

    (* 2. Determine and attach the varying assignment, and set end date: *)
    (*<PRINT
    SetString(NoteString, "creating varying assignments:");
    PrintAString(NoteString);
    PRINT>*)
    CreateVaryingAssignments(Task, 
                             ScheduleAtDate, 
                             DoWeForceSchedule, 
                             FALSE, (* DoWeUseLateProfiles *)
                             Task^.Plan.Assignments,
                             TaskEndDate,
                             AllWorkDone);
    (*<PRINT
    SetString(NoteString, "after creating assts, task end date = ");
    CtoS(TaskEndDate, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    SetString(NoteString, "   and AllWorkDone = ");
    IF AllWorkDone THEN ConcatS(NoteString, "TRUE"); 
      ELSE ConcatS(NoteString, "FALSE");  END;
    PrintAString(NoteString);
    PRINT>*)
    IF SchedulingAbandoned THEN
        RETURN;
    END;
    Task^.Plan.Dates.EarlyEnd := TaskEndDate;

    (* 3. Update resource availabilities: *)
    (*<PRINT
    SetString(NoteString, "updating resource availabilities:");
    PrintAString(NoteString);
    PRINT>*)
    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,  
                                        TSIZE(AnAssignmentRecord));
    RemoveFromResourceAvailability(Assignments, ResourceCount, ScheduleAtDate);
    IF SchedulingAbandoned THEN
        ReleaseObject(AssignmentHandle);
        RETURN;
    END;

    (* 4. If force-scheduling, set the dont bump flag: *)
    IF (DoWeForceSchedule) THEN
        INCL(Task^.TempTaskFlags, DontBump);
    END;

    (* 5. Move the task to the active list: *)
    DeList(TaskHandle);
    AddLowDate(ActivationList,TaskHandle,Task);  (* Must be in sorted order. *)

    ReleaseObject(AssignmentHandle);

    (*<PRINT
    SetString(NoteString, "done activing task.");
    PrintAString(NoteString);
    PRINT>*)

END ActivateTask;


(*------ ActivateInfeasibleTask------------------------------------------

    This procedure is called when ActivateCandidates has determined that
    there is no feasible start date for the task (probably because the
    assignments exceed their absolute limits).

    (see .def part for description)
*)

PROCEDURE ActivateInfeasibleTask (TaskHandle        : AnExtHandle;
                                  Task              : ATaskPtr;
                                  Warning           : AWarning;
                                  ActiveList        : AnExtHandle );
VAR
    LatestAntecedantEnd : ADate;
BEGIN
 
        (* issue warning and set error flag: *)
    IssueWarning(Warning,Task);(*  "Cannot schedule task "  *)
    INCL(Task^.TaskStatusSet,NeedsRecalculate);  (* Error Flag *)

        (* set dont bump flag: *)
    INCL(Task^.TempTaskFlags,DontBump);

        (* set dates: *)
    LatestAntecedantEnd := LatestAntecedantEndDate(Task,
                                Task^.StartDateLowerBound);
    WITH Task^.Plan.Dates DO
        IF (Task^.StartStatus = FutureS) THEN
            EarlyStart := LatestAntecedantEnd;
        END;
        IF Task^.DurationMethod = DurationDriven THEN
            EarlyEnd := EarlyStart + Task^.duration;
        ELSE
            EarlyEnd   := EarlyStart;
        END;
    END;
    Task^.count := LatestAntecedantEnd;

        (* move task to the active list: *)
    DeList(TaskHandle);
    AddLowDate(ActiveList,TaskHandle,Task);  (* Must be in sorted order. *)

END ActivateInfeasibleTask;

END ResScheduleTaskResources.





    Mar 1 , 89 - JES - created.

    July 12, 89 - JES - Modified to exit gracefully when flexstore create
                        fails.
    Aug-30-89   AJL     -Changed name of "InsufficientVirtualMemory" to
                         "SchedulingAbandoned". 
    Jan-09-90  - JES  - Started to modify in preparation for support of
                        multiple calendars and varying resource assignments.

    Sep-04-90  - JES  - Removed unused procedures ScheduleFlatVaryingAsst
                        etc - added procedures FindEndDate, FindDuration,
                        and MakeAssignments.

    Sep-05-90  - JES  - Added procedure MakeAssignments2. (Both this and
                        MakeAssignments now take a parameter "Schedule
                        ThroughVacations", allowing the caller to specify
                        whether or not vacations should be skipped over
                        in scheduling the assignments.) 

                        Added parameter "StartDate" to procedure 
                        UpdateResourceAvailability, so that no availabilities
                        before that date will be updated.

   Sep 11, 90 - JES   - MakeAssignments2 now has VAR parameter 
                        AssignmentEndDate, so we know when the assignment ends.
   Sep. 20 90   AJL   - Made the AllowVacations parameter to ProcessResource
                        always TRUE.  I don't understand this parameter, but
                        TRUE seems required for CPM scheduling to skip over
                        vacations without halting.
   Sep. 27 90  AJL/CL - Changed UpdateResourceAvailabilities so that only 
                        periods with non-zero amounts and after the StartDate 
                        are considered.

   Oct 18, 90 - JES - Added a "negative variant" of UpdateResourceAvailability,
        called UpdateResourceAvailabilityNeg. The original procedure
        took a an assignment array and subtracted the resources used
        by the varying assignment structures from the residue availabilities.
        The negative variant adds the amounts rather than subtracting them,
        and is used when deactivating tasks.

   30-Oct-90  CL  - Rewrite FindEndDate and FindDuration who no longer calls
                    ProcessResource.
                  - Rename FindEndDate to FwdFindEndDate and FindDuration
                    to FwdFindDuration.
                  - Create BackFindStartDate.
                  - IMPORT MaxDate from Timei instead of ResConstants.
    6-Nov-90  CL  - Rename MakeAssignments to AssignForInterval and
                    MakeAssignments2 to AssignForDuration.
    9-Nov-90  CL  - Rewrite AssignForInterval and AssignForDuration who
                    no longer calls ProcessResource.

   Nov 15, 90 JES - Moved procedures CreateSubstitutableResourceAssignments
                    and CreateNonSubstitutableResourceAssignments into
                    this module from ResActivate.
   19-Nov-90  CL  - Added parameter HonorVacations to procedures  
                    BackFindStartDate, FwdFindEndDate, and FwdFindDuration.
   Nov 19, 90 JES - Corrected the procedure CreateNonSubstitutableResource
                     Assignments so that it does not schedule resources
                     through their vacations for duration-driven tasks
                     (it was previously doing that). This requires calling
                     AssignForInterval instead of AssignForDuration for
                     these tasks. 

                     Added support for HonorDaysOff flag.

                     Removed non-employable resources from consideration
                     in procedures CreateSubstitutableResourceAssignments
                     and CreateNonSubstitutableResourceAssignments.
   Nov 27, 90 JES -  In procedure CreateSubstitutableResourceAssignments:
                     improved documentation and overall structure. Also
                     incorporated AJL review comments.
   Nov 29, 90 JES -  Added missing error handling to AddToAvailability
                     and RemoveFromAvailability. Fixed error-handling
                     in AssignForInterval and AssignForDuration.
                     Put finishing touches on CreateSubstitutableResource
                     Assignments.
   Nov 30, 90 - 3 pm.  - JES
                     Fixed bug in CreateSubs... where procedure was setting
                     period end to min end of USED cells, instead of just
                     min end of ALL cells found.

