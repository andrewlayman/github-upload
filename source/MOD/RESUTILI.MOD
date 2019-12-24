IMPLEMENTATION MODULE ResUtilities;
(*V2=PRINT WITH debugging printouts. *)
(*V3=DEBUG WITH debugging checks *)
(*V4=KILL  Set pointers to NIL when unlocked. *)

(* Procedures useful to various parts of resource levelling.

      MODIFICATION HISTORY

    Jan 04, 90 - JES -created.

    Sep 04, 90 - JES -added procedures ProcessResource and MaxEndOfSpent.
                      Changed name of TaskHasAbsoluteStartDate to
                      UnspentWorkMustBeContiguous.
                      Also, in that procedure, changed the condition
                      "StartStatus <> FutureS" to "FixTheStart in
                      TaskFlags", since (for now) these will be equivalent
                      (as soon as AJL ceases to set this flag for "Fixed"
                      tasks).
    Sep 12, 90 - JES - no more "FixTheStart" flag - back to "Started or
                        Done"
    Sep 17, 90 - JES -added procedures DurationToEffort and EffortToDuration.

    Sep 18, 90 - JES -procedure UnspentWorkMustBeContiguous always returns
                        FALSE for effort-driven split tasks, since
                        levelling will schedule any unspent effort on these
                        tasks in all circumstances.
    Oct 2,  90 - JES -added procedure TaskUsesNoResources.
    Oct 4,  90 - JES - undid the change made Sep 18. Cpm can now handle
                       started/done "contiguous work" tasks even if they
                       are effort-driven split, since it can use the
                       same procedure ("CreateSubstitutableResourceAssignments")
                       that levelling uses.
    Oct. 9, 90 - AJL - Added ResourceAssignedAtDate and ResourceIsAssignedToTask.
    Oct-16-90 AJL/CL - Modify ProcessResource to use the head cell as a
                       boundary for searching thru the availability list.
                     - Rename an argument of ConstrainedEndDate from
                       MaxDate to UpperLimit because MaxDate is being
                       defined as a constant in module Timei.
                     - Fix the indentation of IMPORT section.
    25-Oct-90   CL   - Modify CellIsLegal to include head cells.
     1-Nov-90   CL   - Rename LockScheduledDates to FrozenTask,
                       ResourceDriven to EffortDriven.
    Nov-3-90  AJL    - Set AssignmentHandle in MaxEndOfSpent to a valid
                       value before using it.
    Nov 12, 90  JES  - Fixed a bug in ProcessResource (line 561 had
                       a " > " sign instead of a " < " sign)
      13-Nov-90  CL  - Move SubtractDuration here from TLCPM.
      Nov 13, 90 JES - Added procedure CheckResourceDuration.
      Nov 19, 90 JES - Added support for Honor-Days-Off to CheckResourceDuration.
      Nov 21, 90 AJL - Fixed some trace support problems.
      Nov 26, 90 JES - Fixed a lock-and-not-release problem and removed
                       the now unused procedure ProcessResource.
      Nov 27, 90 JES - Added some print statements for debugging.
                       Fixed bug at very end of CheckResourceDuration.
      Nov 28, 90    JES - Added procedure TaskUsesNoEmployableResources.
                        - Minor optimization in CheckResourceDuration
                          (avoid the repeated test "Cell^.StartDate 
                          < StartDate").
      Nov 29, 90  JES - Refixed bug of uninitialized "Finished" in
                        CheckResourceDuration, since change didn't
                        make it in.
      Dec 11, 90  JES - Checked bounds before FOR loops.                
      Dec 12, 90  AJL - Moved a test for NIL handle within MaxEndOfSpent
                        and commented-out a debug warning that complained
                        when MaxEndOfSpent was called and the task had
                        no assignments.
      Dec 17, 90  JES - Completely removed the above-mentioned debug warning.
      Dec 17, 90  JES - 1. Added procedure BackCheckResourceDuration.
                        2. Changed CheckResourceDuration so that, instead
                           of returning the start date of the earliest
                           cell with the violation, it returns that cell's
                           end date minus 1. (This way, the calling procedures,
                           when trying again from "violation date + 1",
                           will not waste any more time with that cell!)
   Dec 19, 90    JES - Added EndDate  as an out parameter to
                       CheckResourceDuration, and StartDate as
                       an out parameter to BackCheckResourceDuration.
   Dec 21, 90    JES - Added procedure NoEmployableResources that's
                       like TaskUsesNoEmployableResources but takes
                       an assignment array instead of a task.
   Jan  3, 90    JES - In procedure DurationToEffort, took floats of
                        the two factors in the numerator separately
                        to avoid overflow.
   Jan 4,  90    JES - Fixed bug in BackCheckResourceDuration and
                        CheckResourceDuration (condition of overshooting
                        the required duration was not being handled
                        correctly).
   Jan 7,  90    JES - Fixed bug in CheckResourceDuration (the above fix
                        erroneously did subtraction instead of addition
                        to get EndDate).
   Jan 7,  90    AJL  - Touched up CheckResourceDuration use of DurationFound.
   Jan 14, 91    JES - Added parameter DoWeUseLateAvailabilities to
                        procedure BackCheckResourceDuration.
   Jan 18, 91    JES - Added procedure TaskDuration.
   Jan 28, 91    JES - Added procedure ToGoDurationOfEffortDelayAssignments.
   Feb  1, 91    JES - Changed procedures that convert from effort to
                        duration so that they round instead of truncate.
   Feb 15, 91    AJL - Renamed EndOf ActualDate to EndOfSpentDate. 
   Feb 15, 91    JES - Renamed MaxEndOfActuals to MaxEndOfSpent.
   Feb 22, 91    JES - Removed all references to Honor-Days-Off, since
                       initial residue availabilities now make vacations
                       invisible if Honor-Days-Off is FALSE.
   Mar  4, 91    JES - Fixed EffortToDuration and ToGoDurationOfEffortDelayTask
                       so rounding is done properly.
   Mar 11, 91    JES - Added more debugging statements.
   Mar 18, 91    JES - Changed UnspentWorkMustBeContiguous so that it
                        returns TRUE for one more case, namely: a duration
                        driven task with some spent effort (i.e., even if
                        the task is marked Future). Also removed fallacious
                        debugging test with printout "overshot required
                        duration" from procedure CheckResourceDuration.
   Apr  3, 91    JES - Renamed procedure ToGoDurationOfEffortDelayTask
                       to ToGoDurationOfEffortDrivenTask, and removed
                       restriction that it be called with the Delay task.
   Apr  8, 91    JES - Added procedure MoveTaskToListInPriorityOrder.
                       For this purpose, moved procedure BPreemptA from
                       ResBumpt to here.
   Apr  9, 91    JES - Moved CompTaskByLowerBound from Tlrplan to here.
   Apr 11, 91    JES - Cleaned up according to m2check.
   Apr 16, 91    AJL - Kill pointers after releasing handles.
   May  8, 91    JES - Added documentation to BPreemptA.
                     - Changed BPreemptA:
                       1. after comparing StartDateUpperBounds, if they
                          are equal, we simply use the late total start date
                          in the next test (instead of "DateA", which is
                          the minimum of the A's late total start and its
                          StartDateUpperBound)
                       2. instead of comparing task durations, we compare
                          the remaining effort (ToGoSummary.Time), since
                          this is a better measure of the difficulty in
                          scheduling the task.
   May 10, 91   JES  - Removed comparison of StartDateLowerBounds in
                        BPreemptA. The tasks are kept in order of
                        this on the unscheduled list anyway, 
                        so all other things being equal they will
                        be taken in this order. (In any case, this
                        comparison was the reverse of what it should 
                        have been to make any sense - namely, if A'
                        lower bound is higher, if anything A should
                        have a lower (rather than higher) priority.)
   May 17, 91   JES -  Removed BPreemptA (it's now in the new module
                        ResPriority).
   May 21, 1991 AJL  - Added TasksMightHaveResourcesInCommon.
   Jun  1, 91   AJL  - Changed UnspentWorkMustBeContiguous so that it
                        no longer returns TRUE for a duration
                        driven task with some spent effort.
   Jun 13, 91   AJL  - Changed UnspentWorkMustBeContiguous so that it
                        returns TRUE for a duration-driven task that
                        has a MustStart date (LB = UB).
   Jun 25, 91   JES  - Fixed ToGoDurationOfEffortDriven... so that it
                        doesn't count non-employable resources.
   Jan 29, 92   AJL  - Changed rate parameters to REAL.
*)

FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr, AnAssignmentSummary,
                            AStartStatus, AFixType, ADurationMethod, ATaskFlag,
                            ASplittingRule;


FROM Assignments    IMPORT
    (* TYPE *)              AnAssignmentAttribute, 
                            AnAssignmentRecord, AnAssignmentArray,
    (* PROC *)              ForEachAssignment;

FROM Dialog         IMPORT
    (* PROC *)				FatalError, NotYetImplemented;

FROM Edges          IMPORT
    (* TYPE *)              AnEdgePtr;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle,
    (* PROC *)              LockObject, LockObjectArray, ReleaseObject,
                            ReleaseUnchangedObject, ObjectsAreSame;

FROM LongConvert   IMPORT
    (* PROC *)          RealToLong, LongToReal;

FROM LStrings       IMPORT
    (* PROC *)				SetString, Compare;

FROM Planner        IMPORT
    (* VAR  *)              KeepEffortContiguous;

FROM PTaskList      IMPORT
    (* PROC *)              DeList, AddBefore;


FROM ResCal         IMPORT
    (* TYPE *)              AnAvailabilityCellPointer,
    (* PROC *)              CellContainingDate;

FROM ResConstants   IMPORT
    (* CONST *)             DontBump;

FROM ResPriority    IMPORT
    (* PROC *)              BPreemptA;    

FROM ResWarnings    IMPORT
    (* TYPE *)              AWarning,
    (* PROC *)              IssueWarning, SendErrorMsg;


FROM RsrcMod        IMPORT
    (* TYPE *)             	AResourcePointer, AResourceType;

FROM Schedule       IMPORT
    (* VAR *)               ZeroIsLowestPriority;


FROM SYSTEM         IMPORT
    (* PROC *)				TSIZE, ADR, ADDRESS;

FROM Timei          IMPORT
    (* CONST *)             MinDate, MaxDate,
    (* TYPE *)              ADate, ADuration;

FROM Timeu          IMPORT
    (* VAR *)				FSMUPH;

FROM VaryAssgnment  IMPORT
							LocateRateAtDate;

(*  ------------------------ Import if tracing ------------------*)
(*<PRINT

FROM LStrings     IMPORT ConcatS, ConcatLS, CtoS;

FROM LongConvert  IMPORT LongToString;

FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat;

FROM ResTrace     IMPORT NoteString, PrintAString, PrintList,
                         ConcatTaskID, PrintAvailabilityCell,
                         PrintResidueAvailability;

FROM TimeFormat   IMPORT TimeUtoS;

VAR
    s : ARRAY [0..255] OF CHAR;
PRINT>*)

(*<PRINT
VAR
    TraceS, TraceS2 : ARRAY [0..255] OF CHAR;
PRINT>*)




PROCEDURE SubtractDuration( Date     : ADate; 
                            Duration : ADuration ) : ADate;
BEGIN
    IF (Date >= Duration) THEN
        RETURN Date - Duration;         (* Needs calendar work? *)
    ELSE
        (*<PRINT   SetString(TraceS, "WHOA! Date < duration!  ");
                     ConcatS(TraceS, ", Date = ");  CtoS(Date, TraceS2); ConcatLS(TraceS, TraceS2);
                     ConcatS(TraceS, ", dur = ");  CtoS(Duration, TraceS2); ConcatLS(TraceS, TraceS2);
                     PrintAString(TraceS);
        PRINT>*)

        IssueWarning(BeforeStartOfCalendar, NIL);
        RETURN MinDate;
    END;
END SubtractDuration;



PROCEDURE ToGoDurationOfEffortDrivenTask (Task: ATaskPtr) : ADuration;

VAR
    AssignmentHandle  : AnExtHandle;
    Assignments       : AnAssignmentArray;
    Answer            : ADuration;
    ResourceCount, i  : CARDINAL;

BEGIN
    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));
    Answer := ToGoDurationOfEffortDrivenAssignments(Task,
                                                    Assignments,
                                                    ResourceCount);
    ReleaseUnchangedObject(AssignmentHandle);
    (*<KILL*) Assignments := NIL; (*KILL>*)
    RETURN Answer;

END ToGoDurationOfEffortDrivenTask;


PROCEDURE ToGoDurationOfEffortDrivenAssignments (Task: ATaskPtr;
                                                 Assignments : AnAssignmentArray;
                                                 NumAssignments : CARDINAL) : ADuration;
VAR
    SumOfRates        : REAL;
    i  : CARDINAL;

BEGIN

    IF NumAssignments = 0 THEN
        RETURN 0; (* this shouldn't happen, but who knows.. *)
    END;

    SumOfRates := Zero;
    FOR i := 0 TO NumAssignments - 1 DO
        IF Assignments^[i].Resource^.Type = Employable THEN
            SumOfRates := SumOfRates + FLOAT(Assignments^[i].MaxRatePercent);
        END;
    END;
    (*<DEBUG*)
    IF SumOfRates = Zero THEN
        SendErrorMsg("ToGoDuration called with task w no employable resource");
        FatalError();
    END;
    RETURN TRUNC(Half + (Task^.ToGoSummary.Time * OneHundred * FSMUPH)/SumOfRates);

END ToGoDurationOfEffortDrivenAssignments;




(*------LatestAntecedantEndDate---------(exported)--------------------*)


PROCEDURE LatestAntecedantEndDate(Task : ATaskPtr;
                                  Day  : ADate ) : ADate;
VAR
    EdgeDate : ADate;
    Edge: AnEdgePtr;
    AntecedantTask : ATaskPtr;
    LatestEndDate  : ADate;
BEGIN
            (*  Returns max of (Day, latest end date of any antecedants)   *)

    LatestEndDate := Day;

    Edge := Task^.antetasks;
    WHILE (Edge <> NIL) DO
        WITH Edge^.headtask^ DO
            AntecedantTask := Methods^.LockFlexStorDataObject(Edge^.headtask);
            EdgeDate := AntecedantTask^.Plan.Dates.EarlyEnd;
            Methods^.UnlockUnchangedDataObject(Edge^.headtask);
            IF (Edge^.Delta >= 0) THEN
                IF (EdgeDate > MaxDate-CARDINAL(Edge^.Delta)) THEN
                   (* case 1: delta too big to allow increment *)
                   IssueWarning(PastEndOfCalendar,Task);
                   EdgeDate := MaxDate;
                ELSE
                   (* case 2: delta small enough to allow increment *)
                   INC(EdgeDate,Edge^.Delta);
                END;
            ELSIF (EdgeDate >= CARDINAL(-Edge^.Delta)) THEN (* k < 0, EdgeDate + k >= 0 *)
                 (* case 3: negative delta but not too negative *)
                    (* No warning if EdgeDate + k < 0 so that summary starts
                       can be scheduled at day 0, and have dependencies with
                       -Deltas (x to end) without triggering a warning. *)
                    (*$R-*) (*$T-*)   (* Don't want no range checking. *)
                INC(EdgeDate,Edge^.Delta);
                    (*$R=*) (*$T=*)   (* Don't want no range checking. *)
            ELSE
                (* case 4: delta too negative, so just reduce edgedate to 0 *)
                EdgeDate := 0;
            END;
            IF (EdgeDate > LatestEndDate) THEN
                LatestEndDate := EdgeDate;
            END;
        END;
        Edge := Edge^.taillink;
    END;
    RETURN LatestEndDate;
END LatestAntecedantEndDate;


PROCEDURE EarliestDescendantStartDate(Task          : ATaskPtr;
                                      EndOfSchedule : ADate) : ADate;
VAR
    EarliestStartDate  : ADate;
    Edge               : AnEdgePtr;
    EdgeDate           : ADate;
    DependantTask      : ATaskPtr;
BEGIN
    EarliestStartDate := EndOfSchedule;

    Edge := Task^.desctasks;
    WHILE (Edge <> NIL) DO
        DependantTask := Edge^.tailtask^.Methods^.LockFlexStorDataObject(
                             Edge^.tailtask);
            (*$R-*) (*$T-*)   (* Don't want no range checking. *)
        EdgeDate := DependantTask^.Plan.Dates.EarlyStart;

        IF (Edge^.Delta >= 0) THEN
            IF (EdgeDate < CARDINAL(Edge^.Delta)) THEN
            (* case #'s below correspond to those in LatestAntecedantEndDate*)
            (* "case 4": delta too big to allow decrement *)
                EdgeDate := 0;
            ELSE
            (* "case 3" - delta small enough to allow decrement *)
                DEC(EdgeDate,Edge^.Delta);
            END;
        ELSIF (EdgeDate < MaxDate-CARDINAL(-Edge^.Delta)) THEN
           (* "case 2": delta not too negative - allow decrement *)
            (*$R-*) (*$T-*)   (* Don't want no range checking. *)
            DEC(EdgeDate,Edge^.Delta);
            (*$R=*) (*$T=*)   (* Don't want no range checking. *)
        ELSE
          (* "case 1": delta too negative to allow decrement - do nothing *)
        END;

        Edge^.tailtask^.Methods^.UnlockUnchangedDataObject(
                             Edge^.tailtask);
        IF (EdgeDate < EarliestStartDate) THEN
(*<PRINT
SetString(NoteString, "Setting new minimum: ");
TimeUtoS(EdgeDate, s);
ConcatLS(NoteString, s);
PrintAString(NoteString);
PRINT>*)
            EarliestStartDate := EdgeDate;
        END;
        Edge := Edge^.headlink;
    END;

    RETURN EarliestStartDate;
END EarliestDescendantStartDate;


(*------ TaskUsesNoLevellableResources ------------------(exported)-------------*)

PROCEDURE TaskUsesNoLevellableResources(Task: ATaskPtr) : BOOLEAN;

VAR
    AssignmentHandle         : AnExtHandle;
    Assignments              : AnAssignmentArray;
    ResourceCount            : CARDINAL;
    ResourceWeUse            : AResourcePointer;
    AmountWeUse              : CARDINAL;
    UsesLevellableResource   : BOOLEAN;
    i                        : CARDINAL;
BEGIN

    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));

    IF ResourceCount = 0 THEN
        ReleaseUnchangedObject(AssignmentHandle);
        (*<KILL*) Assignments := NIL; (*KILL>*)
        RETURN TRUE;
    END;

    UsesLevellableResource := FALSE;
    i := 0;
    LOOP
        IF i = ResourceCount THEN
            EXIT;
        END;
        ResourceWeUse := Assignments^[i].Resource;
        AmountWeUse   := Assignments^[i].MaxRatePercent;
        IF (ResourceWeUse^.LevelThisResource) AND (AmountWeUse > 0) THEN
            UsesLevellableResource := TRUE;
            EXIT;
        END;
        INC(i);
    END;

    ReleaseUnchangedObject(AssignmentHandle);
    (*<KILL*) Assignments := NIL; (*KILL>*)
    RETURN NOT (UsesLevellableResource);

END TaskUsesNoLevellableResources;

(*------ TaskUsesNoEmployableResources ------------------(exported)-------------*)

PROCEDURE TaskUsesNoEmployableResources(Task: ATaskPtr) : BOOLEAN;

VAR
    AssignmentHandle         : AnExtHandle;
    Assignments              : AnAssignmentArray;
    ResourceCount            : CARDINAL;
    Answer                   : BOOLEAN;
BEGIN

    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));
    Answer := NoEmployableResources(Assignments, ResourceCount);
    ReleaseUnchangedObject(AssignmentHandle);
    (*<KILL*) Assignments := NIL; (*KILL>*)
    RETURN Answer;

END TaskUsesNoEmployableResources;

(*------ NoEmployableResources ------------------(exported)-------------*)

PROCEDURE NoEmployableResources(Assignments : AnAssignmentArray;
                                NumAssignments : CARDINAL) : BOOLEAN;

VAR
    ResourceWeUse            : AResourcePointer;
    AmountWeUse              : CARDINAL;
    UsesEmployableResource   : BOOLEAN;
    i                        : CARDINAL;
BEGIN

    IF NumAssignments = 0 THEN
        RETURN TRUE;
    END;

    UsesEmployableResource := FALSE;
    i := 0;
    LOOP
        IF i = NumAssignments THEN
            EXIT;
        END;
        ResourceWeUse := Assignments^[i].Resource;
        AmountWeUse   := Assignments^[i].MaxRatePercent;
        IF (ResourceWeUse^.Type = Employable) AND (AmountWeUse > 0) THEN
            UsesEmployableResource := TRUE;
            EXIT;
        END;
        INC(i);
    END;

    RETURN NOT (UsesEmployableResource);

END NoEmployableResources;



(*------ TaskUsesNoResources ------------------(exported)-------------*)

PROCEDURE TaskUsesNoResources (Task : ATaskPtr) : BOOLEAN;
VAR
    AssignmentHandle         : AnExtHandle;
    Assignments              : AnAssignmentArray;
    ResourceCount            : CARDINAL;
    ResourceWeUse            : AResourcePointer;
    AmountWeUse              : CARDINAL;
    UsesResource             : BOOLEAN;
    i                        : CARDINAL;
BEGIN

    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));

    IF ResourceCount = 0 THEN
        ReleaseUnchangedObject(AssignmentHandle);
        (*<KILL*) Assignments := NIL; (*KILL>*)
        RETURN TRUE;
    END;

    UsesResource := FALSE;
    i := 0;
    LOOP
        IF i = ResourceCount THEN
            EXIT;
        END;
        ResourceWeUse := Assignments^[i].Resource;
        AmountWeUse   := Assignments^[i].MaxRatePercent;
        IF (AmountWeUse > 0) THEN
            UsesResource := TRUE;
            EXIT;
        END;
        INC(i);
    END;

    ReleaseUnchangedObject(AssignmentHandle);
    (*<KILL*) Assignments := NIL; (*KILL>*)
    RETURN NOT (UsesResource);
END TaskUsesNoResources;



PROCEDURE UnspentWorkMustBeContiguous (Task: ATaskPtr) : BOOLEAN;
BEGIN
        IF (Task^.DurationMethod = DurationDriven) THEN
                (* If the user has given us a start date, or no choice
                   about the start date, then it is scheduled by the 
                   CPM phase. *)
            IF (Task^.StartStatus <> FutureS) OR 
               (Task^.StartDateLowerBound = Task^.StartDateUpperBound) THEN
                RETURN TRUE;
            ELSE
                RETURN FALSE;
            END;
        ELSIF ((KeepEffortContiguous) AND (Task^.StartStatus <> FutureS))
              OR
              (FrozenTask IN Task^.TaskFlags) THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END;
END UnspentWorkMustBeContiguous;

PROCEDURE TaskIsFixedType (Task: ATaskPtr) : BOOLEAN;

BEGIN
         IF (Task^.fixation = FixedDate) THEN
             RETURN TRUE;
         ELSE
             RETURN FALSE;
         END;
END TaskIsFixedType;




PROCEDURE MaxEndOfSpent(Task : ATaskPtr; Day: ADate) : ADate;

VAR
    Assignments           : AnAssignmentArray;
    AssignmentHandle      : AnExtHandle;
    ReturnDate               : ADate;
    ResourceCount, i      : CARDINAL;

BEGIN
    ReturnDate := Day;
    AssignmentHandle := Task^.Plan.Assignments;

    IF AssignmentHandle = AnExtHandle(NIL) THEN
        RETURN (ReturnDate); (* return value is "Day" *)
    END;

    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));
    FOR i := 1 TO ResourceCount DO
        IF ReturnDate < Assignments^[i-1].EndOfSpentDate THEN
            ReturnDate := Assignments^[i-1].EndOfSpentDate;
        END;
    END;
    ReleaseUnchangedObject(AssignmentHandle);
    (*<KILL*) Assignments := NIL; (*KILL>*)
    RETURN ReturnDate;

END MaxEndOfSpent;

(* --- DurationToEffort - given a duration (in ticks) and a resource level,
     does the conversion to effort (in people * ticks) *)
PROCEDURE DurationToEffort(Duration: ADuration;
                           ResourceLevel: REAL) : REAL;
BEGIN
    RETURN (FLOAT(Duration) * ResourceLevel/ OneHundred);
END DurationToEffort;


(* --- EffortToDuration - given an amount of effort (in people * ticks)
    and a resource level, does the conversion to duration *)
PROCEDURE EffortToDuration(Effort : REAL;
                           ResourceLevel: REAL) : ADuration;
BEGIN
    RETURN TRUNC(Half + ((Effort * OneHundred)) / ResourceLevel);
END EffortToDuration;



    (* These routines search all the assignments of the task and return the
       amount of a resource in use at any particular date.  If the resource
       is assigned more than once, the total is returned. *)


TYPE
    AnAssignmentSearchContext = RECORD
                                    Resource : AResourcePointer;
                                    Date     : ADate;
                                    Rate     : REAL;
                                END;



PROCEDURE LookForResource(  VAR Assignment      : AnAssignmentRecord;
                                Context         : ADDRESS            ) : BOOLEAN;
VAR
    SearchContext : POINTER TO AnAssignmentSearchContext;
BEGIN
    SearchContext := Context;         (* Get the pointer to the context record. *)

    WITH SearchContext^ DO
        IF (Assignment.Resource = Resource) THEN
            Rate := 1.0;
            RETURN FALSE;   (* End search. *)
        END;
    END;

    RETURN TRUE;


END LookForResource;



(* --- ResourceIsAssignedToTask
       Answers the question "Is this resource working on this task?"
       *)

PROCEDURE ResourceIsAssignedToTask(     Task     : ATaskPtr;
                                        Resource : AResourcePointer
                                   ) : BOOLEAN;
VAR
    Context : AnAssignmentSearchContext;
    i : CARDINAL;
BEGIN
        (* Before searching through all the assignments of the task, check
           the fingerprint on the task.  Only resources whose equivalence
           class (ID MOD 16) is represented in the fingerprint are assigned
           to the task. *)

    i           := Resource^.ID MOD 16;

    IF (i IN Task^.Fingerprint) THEN

        Context.Resource := Resource;
        Context.Rate     := Zero;

        ForEachAssignment (Task^.Plan.Assignments, LookForResource, ADR(Context) );

        RETURN (Context.Rate <> Zero);
    ELSE
        RETURN FALSE;
    END;
END ResourceIsAssignedToTask;




PROCEDURE LookForResourceAtDate(  VAR Assignment      : AnAssignmentRecord;
                                      Context         : ADDRESS            ) : BOOLEAN;
VAR
    SearchContext : POINTER TO AnAssignmentSearchContext;
    LRate : REAL;
BEGIN
    SearchContext := Context;         (* Get the pointer to the context record. *)

    WITH SearchContext^ DO
        IF (Assignment.Resource = Resource) THEN
            LRate := LocateRateAtDate( Assignment.VaryingAssignment, Date );
            Rate := Rate + LRate;
        END;
    END;

    RETURN TRUE;


END LookForResourceAtDate;



(* --- ResourceAssignedAtDate
       Given a task, resource and date, shows the amount of the resource
       assigned to the task at that date. *)

PROCEDURE ResourceAssignedAtDate(     Task     : ATaskPtr;
                                      Resource : AResourcePointer;
                                      Date     : ADate
                                ) : REAL;
VAR
    Context : AnAssignmentSearchContext;
    i           : CARDINAL;
BEGIN
        (* Before searching through all the assignments of the task, check
           the fingerprint on the task.  Only resources whose equivalence
           class (ID MOD 16) is represented in the fingerprint are assigned
           to the task. *)


    i           := Resource^.ID MOD 16;

    IF (i IN Task^.Fingerprint) THEN

        Context.Resource := Resource;
        Context.Date     := Date;
        Context.Rate     := Zero;

        ForEachAssignment (Task^.Plan.Assignments, LookForResourceAtDate, ADR(Context) );

        RETURN Context.Rate;
    ELSE
        RETURN Zero;
    END;

END ResourceAssignedAtDate;

(* -------- CheckResourceDuration ----------------------------

   Determine if given required duration and level of a Resource can
   be satisfied starting at StartDate, without running
   into a violation. If "DoWeCountVacations" is TRUE, then vacation
   time is counted in the accumulated duration, provided that
   "DoWeAllowVacations" is also TRUE. A violation is a date such that
   either (a) the level is not satisfied and "DoWeIgnoreResourceLevels"
   is FALSE, or (b) the resource is on vacation and "DoWeAllowVacations"
   is FALSE. If the conditions can be satisfied, "DateIsGoodForResource"
   is returned as TRUE, and "EndDate" contains the last active date
   for the resource. If not, "DateIsGood" is returned
   as FALSE, and ViolationDate contains the last date contained in
   the earliest cell found to have a violation (that is, the cell's
   end date minus 1).

*)

PROCEDURE CheckResourceDuration (Resource             : AResourcePointer;
                                 StartDate            : ADate;
                                 LevelRequired        : REAL;
                                 DurationRequired     : ADuration;
                                 DoWeAllowVacations       : BOOLEAN;
                                 DoWeCountVacations       : BOOLEAN;
                                 DoWeIgnoreResourceLevels : BOOLEAN;
                            VAR  DateIsGood           : BOOLEAN;
                            VAR  EndDate              : ADate;
                            VAR  ViolationDate        : ADate);

VAR
    CellHandle, NextCellHandle    : AnExtHandle;
    Cell                          : AnAvailabilityCellPointer;
    LevelNeeded                   : LONGINT;
    RemainingDurationRequired     : ADuration;
    Start                         : ADate;
    FirstCell, Finished           : BOOLEAN;
BEGIN
    (*<PRINT
    SetString(NoteString, "checking resource duration with: ");
    PrintAString(NoteString);
    SetString(NoteString, "     resource = ");
    ConcatLS(NoteString, Resource^.Name);
    PrintAString(NoteString);
    SetString(NoteString,"      start date = ");
    TimeUtoS(StartDate,s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    SetString(NoteString,"      level required = ");
    RtoS(LevelRequired,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"      duration required = ");
    CtoS(DurationRequired,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"      allow vacations = ");
    IF DoWeAllowVacations THEN 
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    SetString(NoteString,"      count vacations = ");
    IF DoWeCountVacations THEN 
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    SetString(NoteString,"      ignore resource levels = ");
    IF DoWeIgnoreResourceLevels THEN 
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    PrintAString(NoteString);
    PRINT>*)

    LevelNeeded := RealToLong(LevelRequired);   (* Convert for format of residue list. *)

    CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, StartDate);
    RemainingDurationRequired := DurationRequired;
    FirstCell := TRUE;
    Finished := FALSE;
    DateIsGood := TRUE; (* changes to FALSE if we find a violation *)
    EndDate := StartDate; (* equivalent to 0 duration *)
    REPEAT
        IF (LockObject(CellHandle,Cell) = 0) THEN FatalError; END;
        IF Cell^.IsHeadCell THEN 
            (*<PRINT
            SetString(NoteString, "reached head cell - exiting ");
            PRINT>*)
            Finished := TRUE;
        ELSE
            NextCellHandle := Cell^.NextCell;
            IF (FirstCell) THEN
                Start := StartDate;
                FirstCell := FALSE;
            ELSE
                Start := Cell^.StartDate;
            END;
            (*<PRINT
             SetString(NoteString,"checking cell with date ");
             TimeUtoS(Start,s);
             ConcatLS(NoteString, s);
             PrintAString(NoteString);
            PRINT>*)
            (* check this cell for a violation: *)
            (*<PRINT
             IF (Cell^.ThisIsAVacation) THEN
             SetString(NoteString,  " vacation cell");
             ELSE
             SetString(NoteString,  " worktime cell");
             END;
             PrintAString(NoteString);
             SetString(NoteString,    " amount available = ");
             LongToString(Cell^.AmountAvailable,s);
             ConcatLS(NoteString, s);
             PrintAString(NoteString);
            PRINT>*)
            IF ((Cell^.ThisIsAVacation) AND 
                NOT (DoWeAllowVacations))
                          OR
               ((Cell^.AmountAvailable < LevelNeeded) 
                 AND NOT (DoWeIgnoreResourceLevels)) THEN
                DateIsGood := FALSE; 
                ViolationDate := Cell^.EndDate - 1; (* used to be "Start" *)        
                (*<PRINT
                SetString(NoteString,"            violation cell");
                PrintAString(NoteString);
                PRINT>*);
            ELSE
                (* we have a "legal" cell - count it in duration if appropriate: *)
                IF (DoWeCountVacations) OR 
                   (NOT Cell^.ThisIsAVacation) THEN
                       (* Don't overshoot the required duration: *)
                   IF (Cell^.EndDate - Start) >= RemainingDurationRequired THEN
                       (*<PRINT
                       SetString(NoteString, "  accumulated required duration");
                       PrintAString(NoteString);
                       PRINT>*)
                       EndDate := Start + RemainingDurationRequired;
                       Finished := TRUE;
                   ELSE
                       EndDate := Cell^.EndDate;
                   END;
                   RemainingDurationRequired := RemainingDurationRequired 
                       - (EndDate - Start);
                    (*<PRINT
                    SetString(NoteString,"         Remaining Dur = ");
                    CtoS(RemainingDurationRequired,s);
                    ConcatLS(NoteString, s);
                    PrintAString(NoteString);
                    ELSE
                    SetString(NoteString,"         legal cell but not counting duration");
                    PRINT>*)
                END;
            END;
        END;
        ReleaseUnchangedObject(CellHandle);      (*<KILL*) Cell := NIL; (*KILL>*)
        CellHandle := NextCellHandle;
    UNTIL Finished OR (NOT DateIsGood);


    (* check for error condition: *)
    IF (RemainingDurationRequired > 0) AND (DateIsGood) THEN
        (* this should not happen unless we reached the head cell 
           without coming across a violation, and we still did not
           accumulate enough duration: *)
        DateIsGood := FALSE;
        ViolationDate := MaxDate; 
        (*<PRINT
        SetString(NoteString,"   no violation, but not enough duration - exiting ");
        PrintAString(NoteString);
        PRINT>*)
    END;

END CheckResourceDuration;



(* -------- BackCheckResourceDuration ----------------------------

   Determine if given required duration and level of a Resource can
   be satisfied starting at ThruDate and running backwards in time,
   without running
   into a violation. If "DoWeCountVacations" is TRUE, then vacation
   time is counted in the accumulated duration, provided that
   "DoWeAllowVacations" is also TRUE. A violation is a date such that
   either (a) the level is not satisfied and "DoWeIgnoreResourceLevels"
   is FALSE, or (b) the resource is on vacation and "DoWeAllowVacations"
   is FALSE. If the conditions can be satisfied, "DateIsGoodForResource"
   is returned as TRUE. If not, "DateIsGood" is returned
   as FALSE, and ViolationDate contains the START DATE of the latest
   cell found to have a violation. (Note that this is not the same as
   the latest violation date found! That would be the cell's end date
   minus 1.)

   If DoWeUseLateAvailabilities is TRUE, the procedure references
   the LateAvailProfile of each resource; otherwise it references
   the regular AvailProfile.

*)

PROCEDURE BackCheckResourceDuration (Resource             : AResourcePointer;
                                     ThruDate             : ADate;
                                     LevelRequired        : REAL;
                                     DurationRequired     : ADuration;
                                     DoWeAllowVacations       : BOOLEAN;
                                     DoWeCountVacations       : BOOLEAN;
                                     DoWeIgnoreResourceLevels : BOOLEAN;
                                     DoWeUseLateAvailabilities: BOOLEAN;
                                VAR  DateIsGood           : BOOLEAN;
                                VAR  StartDate            : ADate;
                                VAR  ViolationDate        : ADate);

VAR
    CellHandle, PrevCellHandle    : AnExtHandle;
    Cell                          : AnAvailabilityCellPointer;
    LevelNeeded                   : LONGINT;
    RemainingDurationRequired     : ADuration;
    End                           : ADate;
    FirstCell, Finished           : BOOLEAN;
BEGIN
    (*<PRINT
    SetString(NoteString, "back checking resource duration with: ");
    PrintAString(NoteString);
    SetString(NoteString, "     resource = ");
    ConcatLS(NoteString, Resource^.Name);
    PrintAString(NoteString);
    SetString(NoteString,"      thru date = ");
    TimeUtoS(ThruDate,s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    SetString(NoteString,"      level required = ");
    RtoS(LevelRequired,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"      duration required = ");
    CtoS(DurationRequired,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    SetString(NoteString,"      allow vacations = ");
    IF DoWeAllowVacations THEN 
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    SetString(NoteString,"      count vacations = ");
    IF DoWeCountVacations THEN 
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    SetString(NoteString,"      ignore resource levels = ");
    IF DoWeIgnoreResourceLevels THEN 
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    SetString(NoteString,"       use late availabilities = ");
    IF DoWeUseLateAvailabilities THEN
    ConcatS(NoteString, "TRUE");
    ELSE
    ConcatS(NoteString, "FALSE");
    END;
    PrintAString(NoteString);
    PRINT>*)

    LevelNeeded := RealToLong(LevelRequired);   (* Convert to form used in residue list. *)

    IF (DoWeUseLateAvailabilities) THEN
        CellHandle := CellContainingDate(Resource^.LateResidueAvailProfile, ThruDate);
    ELSE
        CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, ThruDate);
    END;
    RemainingDurationRequired := DurationRequired;
    FirstCell := TRUE;
    Finished := FALSE;
    DateIsGood := TRUE; (* changes to FALSE if we find a violation *)
    StartDate := ThruDate; (* equivalent to 0 duration *)
    REPEAT
        IF (LockObject(CellHandle,Cell) = 0) THEN FatalError; END;

        IF Cell^.IsHeadCell THEN 
            (*<PRINT
            SetString(NoteString, "reached head cell - exiting ");
            PRINT>*)
            Finished := TRUE;
        ELSE
            PrevCellHandle := Cell^.PrevCell;
            IF (FirstCell) THEN
                End := ThruDate + 1; (* to make it an "end date" type *)
                FirstCell := FALSE;
            ELSE
                End := Cell^.EndDate;
            END;
            (*<PRINT
             SetString(NoteString,"checking cell with date ");
             TimeUtoS(End,s);
             ConcatLS(NoteString, s);
             PrintAString(NoteString);
            PRINT>*)
            (* check this cell for a violation: *)
            (*<PRINT
             IF (Cell^.ThisIsAVacation) THEN
             SetString(NoteString,  " vacation cell");
             ELSE
             SetString(NoteString,  " worktime cell");
             END;
             PrintAString(NoteString);
             SetString(NoteString,    " amount available = ");
             LongToString(Cell^.AmountAvailable,s);
             ConcatLS(NoteString, s);
             PrintAString(NoteString);
            PRINT>*)
            IF ((Cell^.ThisIsAVacation) AND 
                NOT (DoWeAllowVacations))
                          OR
               ((Cell^.AmountAvailable < LevelNeeded) 
                 AND NOT (DoWeIgnoreResourceLevels)) THEN
                DateIsGood := FALSE; 
                ViolationDate := Cell^.StartDate;
                (*<PRINT
                SetString(NoteString, "violation on ");
                TimeUtoS(ViolationDate, s);
                ConcatLS(NoteString, s);
                PrintAString(NoteString);
                PRINT>*)
            ELSE
                (* we have a "legal" cell - count it in duration if appropriate: *)
                IF (DoWeCountVacations) OR 
                   (NOT Cell^.ThisIsAVacation) THEN
                       (* Don't overshoot the required duration: *)
                   IF (End - Cell^.StartDate) >= RemainingDurationRequired THEN
                       (*<PRINT
                       SetString(NoteString,"  accumulated required duration");
                       PrintAString(NoteString);
                       PRINT>*)
                       StartDate := End - RemainingDurationRequired;
                       Finished := TRUE;
                   ELSE
                       StartDate := Cell^.StartDate;
                   END;
                   RemainingDurationRequired := RemainingDurationRequired
                       - (End - StartDate);
                    (*<PRINT
                    SetString(NoteString,"          remaining duration = ");
                    CtoS(RemainingDurationRequired,s);
                    ConcatLS(NoteString, s);
                    PrintAString(NoteString);
                    ELSE
                    SetString(NoteString,"         legal cell but not counting duration");
                    PRINT>*)
                END;
            END;
        END;
        ReleaseUnchangedObject(CellHandle);    (*<KILL*) Cell := NIL; (*KILL>*)
        CellHandle := PrevCellHandle;
    UNTIL Finished OR (NOT DateIsGood);

    (* check for error condition: *)
    IF (RemainingDurationRequired > 0) AND (DateIsGood) THEN
        (* this should not happen unless we reached the head cell 
           without coming across a violation, and we still did not
           accumulate enough duration: *)
        DateIsGood := FALSE;
        ViolationDate := MinDate; 
        (*<PRINT
        SetString(NoteString,"   no violation, but not enough duration - exiting ");
        PrintAString(NoteString);
        PRINT>*)
    END;
END BackCheckResourceDuration;

(* -------- TaskDuration ----------------------------------------

   Simply subtracts task's early start from early end. (Note: this is
   not necessarily the same as the Task^.duration field!)
*)

PROCEDURE TaskDuration(Task : ATaskPtr) : ADuration;

BEGIN
    RETURN VAL(ADuration, 
               Task^.Plan.Dates.EarlyEnd - Task^.Plan.Dates.EarlyStart);
END TaskDuration;




PROCEDURE MoveTaskToListInPriorityOrder (Task       : ATaskPtr;
                                         TaskHandle : AnExtHandle;
                                         Day        : ADate;
                                         List       : AnExtHandle);
VAR
    OtherTask    : ATaskPtr;
    OtherTaskHandle, TempHandle : AnExtHandle;
BEGIN
        (* remove the task from whatever list it is currently on: *)
    DeList(TaskHandle);

        (* put the task onto the new list, in priority order: *)

    IF LockObject(List,OtherTask)=0 THEN FatalError(); END;
    OtherTaskHandle := OtherTask^.Nextlink;
    ReleaseUnchangedObject(List);     (*<KILL*)  OtherTask := NIL; (*KILL>*)
    LOOP
       IF (ObjectsAreSame(OtherTaskHandle, List)) THEN
            EXIT;
       END;
       IF LockObject(OtherTaskHandle,OtherTask)=0 THEN FatalError(); END;
       IF (BPreemptA(OtherTask,Task,Day)) THEN
           ReleaseUnchangedObject(OtherTaskHandle);     (*<KILL*)  OtherTask := NIL; (*KILL>*)
           EXIT;
       END;
       TempHandle := OtherTask^.Nextlink;
       ReleaseUnchangedObject(OtherTaskHandle);     (*<KILL*)  OtherTask := NIL; (*KILL>*)
       OtherTaskHandle := TempHandle;
    END;
    AddBefore(OtherTaskHandle,TaskHandle);
END MoveTaskToListInPriorityOrder;







PROCEDURE CompTaskByLowerBound(   a : ATaskPtr;
                            bHandle : AnExtHandle) : BOOLEAN;
VAR
    b           : ATaskPtr;
    Answer      : BOOLEAN;

BEGIN
    IF (LockObject(bHandle,b) = 0) THEN FatalError(); END;
    IF (a^.StartDateLowerBound > b^.StartDateLowerBound) THEN
        Answer := TRUE;
    ELSIF (a^.StartDateLowerBound < b^.StartDateLowerBound) THEN
        Answer := FALSE;
    ELSE
        Answer := (a^.SequenceNumber > b^.SequenceNumber);
    END;
    ReleaseUnchangedObject(bHandle);
    RETURN Answer;
END CompTaskByLowerBound;


(* -----------------------------------------------------------
    TasksMightHaveResourcesInCommon


-------------------------------------------------------------- *)

PROCEDURE TasksMightHaveResourcesInCommon( A, B : ATaskPtr ) : BOOLEAN;
BEGIN
    RETURN (A^.Fingerprint * B^.Fingerprint) <> {};
END TasksMightHaveResourcesInCommon;


    (* GetToGoLevel -- Return the rate at which the resource should
                       be assigned for the remainder of the task.  This
                       will be, depending on the assignment, either entered
                       by the user or computed based on the remaining
                       effort. *)


PROCEDURE GetToGoLevel(     Task         : ATaskPtr;
                        VAR Assignment   : AnAssignmentRecord; 
                            ToGoDuration : ADuration ) : REAL;
VAR
    ToGoLevel : REAL;
BEGIN
    WITH Assignment DO 
        IF (ComputeByHours IN Attributes) THEN
            IF (ToGoDuration > 0) AND (YetToGoQuantity > Zero) THEN
                ToGoLevel := YetToGoQuantity * OneHundredTimesSMUPH
                             / FLOAT(ToGoDuration);
            ELSE
                ToGoLevel := Zero;
                IF (YetToGoQuantity <> Zero) THEN
                    IssueWarning(CantSchedFutureEffort, Task);                    
                    (*<PRINT    SetString(TraceS, "       Can't schedule Hours.");
                                PrintAString(TraceS);
                    PRINT>*)
                END;
            END;
        ELSE
            ToGoLevel := FLOAT(MaxRatePercent);  (* Rate entered on assignment form. *)
        END;
    END;
    RETURN ToGoLevel;
END GetToGoLevel;


BEGIN
    OneHundredTimesSMUPH := FSMUPH * OneHundred;
END ResUtilities.


