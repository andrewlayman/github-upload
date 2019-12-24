IMPLEMENTATION MODULE ResBumpTasks;
(*V2=PRINT WITH debugging printouts. *)
(*V3=KILL  WITH set pointers to NIL *)
(*V4=DEBUG WITH debugging checks to be removed before production *)

(* Procedures that determine priorities of tasks and bump tasks.

   MODIFICATION HISTORY

    Feb 27, 89 - JES -created by yanking procedures from old TlrPlan
                      to here.

                      Most of the procedures remain intact from the
                      old Tlrplan. However,
                      WeCanSteal now calls FreeTaskResources
                      when it deactivates a task (to update the
                      resource availability tables).

    May 3  89  - JES - changed "MustStartOnTime" in BPreemptA to
                       "DontBump"

    July 12, 89 - JES - Modified to exit gracefully when flexstore create
                        fails.
    Aug. 28, 89 - AJL Fixed some of the PRINT imports.
    Aug-30-89   AJL     -Changed name of "InsufficientVirtualMemory" to
                         "SchedulingAbandoned".
    Dec 1, 89  JES   - rewrote to clarify in preparation for multiple
                       calendars.
    Aug 13,90  JES   - temporarily deactivated bumping for first-phase
                       testing of multiple calendars
    Oct 12, 90 JES   - moved AddLowDate out of here and into PTaskList.
                       Also, removed procedure MustStartOnTime that
                       just returned TRUE iff the task is Started or
                       Done. Changed name of TryToBumpTasks to BumpTasks
                       and slightly modified argument names.
    Oct 25, 90 JES  -  completed support for multiple calendars, effort
                       split tasks, etc. The main differences are:

                        (1) instead of checking only for resource problems
                        actually ON the desired start date, we now calculate
                        the "first-order obstacles" (i.e., for each resource,
                        the first date that there is actually a bottleneck,
                        if the task tries to start on the desired date)
                        and try to remove those by bumping;

                        (2) we include vacations as bottlenecks, and, if
                        there is at least one such, we exit since no
                        amount of bumping can remove a vacation. (The
                        exception is effort-driven split tasks; for
                        them, we know that the removal, by bumping, of
                        just one resource-shortage obstacle (even if
                        there are other vacation obstacles) can allow
                        the task to start on the desired date);

                        (3) "MaxTasksToBump" has been changed from 20 to
                        50; and

                        (4) the program has been restructured somewhat.

    Oct 29, 90  JES    Fixed minor bugs; added comments on how
                       to handle contouring for effort-driven split
                       tasks (for later).
    30-OCT-90  CL  - IMPORT MaxDate from Timei instead of ResConstants.
     1-Nov-90  CL  - Rename LowerBoundStartDate to StartDateLowerBound,
                     ResourceDriven to EffortDriven.
    Nov 15, 90 JES - Modified bumping to support contoured effort-split
                     tasks. To this end, added the parameter
                     "DoWeBumpForContourTask" to the BumpTasks procedure
                     (and relevant subsidiaries). In this case, an
                     obstacle is any date (besides vacations) where
                     the amount of the resource is non-positive, rather
                     than where the amount is less than
                     max rate percent. Thus, the variable "SomeObstacleRemoved"
                     will be true if there is at least one valuable bumpee
                     (i.e., we do not have to wait and tally all the contributions).
    Nov 18, 90 JES - Added support for ignore-calendar option (i.e.,
                     the Honor-Days-Off flag); also checks whether resource
                     is Employable before trying to check its duration (etc).
    Dec 11, 90 JES - Put check for no elements before FOR loops.
    Jan  3, 91 JES - DoBumping now uses new procedure DeactivateTask in
                        ResSched.
    Jan 14, 91 JES - Added new parameter DoWeUseLateAvailabilities to calls
                        to ResAvail procedures.
                     Deactivated BumpTasks until we specifically test it.
   Jan 14, 91 - JES - Added "DoWe" prefixes to some BOOLEANS.
   Jan 18, 91 - JES - Made some fixes to BPreemptA procedure (Delay tasks
                        take precedence over Split, etc).
   Jan 25, 91 - JES - Bumping now deactivates as of "count2", which is
                        set during activation to be the date computed
                        by levelling.
   Feb  7, 91 - JES - Removed all references to WBS numbers.
   Feb 11, 91 - JES - Fixed bug in FindObstacles where Resource was being
                        referenced before it was assigned.
   Feb 13, 91 - JES - Deactivated BumpTasks again for further testing of
                        all but bumping.
   Feb 20, 91 - JES - Removed unused import AStartStatus.
   Feb 22, 91 - JES - Removed references to HonorDaysOff (making vacations
                        invisible is now done in the initial residue
                        availability lists if HonorDaysOff is FALSE).
   Mar 5,  91 - AJL - Change BPreemptA so that the importance of the Split
                      choice is less than the importance of the late end date.
                    - Make the tie-breaker selection by SequenceNumber.
   Mar 8, 91  - AJL - Change BPreemptA some more, to favor NoLaterStart.
   Mar 26, 91 - JES/AJL - Fixed BPreemptA so that it compares StartDateLower
                      Bounds instead of the count field.
   Mar 27, 91 - JES - Tasks to be bumped are now correctly deactivated as
                      of their count, rather than count2, fields.
                    - Reactivated the BumpTasks procedure for testing
                      (up until now it had been made into a no-op).
   Apr  2, 91 - JES - Changed ObstaclesRemain so it just returns FALSE
                       if NumObstacles was already 0 (instead of 
                       calling FatalError).
   Apr  3, 91 - JES - Changed FindObstacles to use the same (symantic)
                      definition of obstacle for effort-split as for all
                      other tasks - namely, the first place there is a
                      vacation or resource conflict. (This is more accurate
                      since sometimes an effort-split task cannot be
                      scheduled feasibly due to an end date resstriction, and
                      not just because no resource is available on the
                      desired start date.)
   Apr. 5, 91   AJL - Gave more emphasis to UpperBoundStartDate in BPreemptA.
   Apr 5,  91 - JES - Added more print statements.
   Apr 8,  91 - JES - Moved procedure BPreemptA out of this module (and into
                      ResUtilities).
                    - Changed procedure BumpTasks so that, before going to
                      the expense of FindObstacles, it first checks whether
                      there exist any lower priority tasks on the active list;
                      and if there are not, it does not do any further processing
                      (since there are no tasks to bump in any case). This
                      should reduce the expense of frequent attempts to
                      bump that turn out to be futile simply because there
                      are no lower priority tasks to bump.
   Apr 10, 91 - JES - Changed name of BumpTasks parameter "EnoughToBump" to
                        "BumpingSucceeded", and changed some print 
                        statements.
   Apr 10, 91 - JES - Made BumpTasks a no-op until we finish testing it
                        locally.
   Apr 10, 91 - JES - Reactivated BumpTasks for local testing - do not
                        turn this into s:!
   Apr 24, 91 - JES - Added procedures FinishBumpingTasks and UnbumpTasks, and
                        renamed BumpTasks to TentativelyBumpTasks. The
                        new procedure TentativelyBumpTasks simply finds
                        what tasks can profitably be bumped (as before)
                        and updates the resource availabilities accordingly;
                        it does not remove the varying assignments. The
                        procedure FinishBumping completes the bumping by
                        removing the varying assignments, and the procedure
                        UnbumpTasks undoes the effects of TentativelyBumpTasks
                        by updating the resource availabilities to what they
                        were before.
   Apr 26, 91  JES   -  Added VAR parameter WeStartedTheBumping to
                        procedure TentativelyBumpTasks.
                     -  Changed the "minor optimization" in FindObstacles
                        so that we say the date is good if we can "ignore
                        resource levels and allow vacations", not the 
                        needlessly restrictive condition "ignore resource 
                        levels and count vacations".
   May  3, 91  JES   -  Don't bump milestones (i.e., duration driven tasks
                        with duration 0). Incorporated this into new
                        procedure "TaskIsBumpable".
   May 20, 91  JES   -  Added procedure "BumpAllMuchLowerPriorityTasks".
                     -  Changed TentativelyBumpTasks so it adds to a
                         list of bumpees, not just creates it; and so
                         that the check at the beginning (ThereAreLower
                         PriorityActiveTasks) to see if there are 
                         any lower priority tasks also makes sure that 
                         there are some resource(s) in common.
   Jun 18, 91  JES      Changed name of parameter UnscheduledList to
                         PreCandidatesList in FinishBumpingTasks.
   Jun 18, 91  JES   - If NumObstacles = 0, that can be okay if the
                        task happened to be assignment-driven split with
                        everyone on vacation on the desired start date.
   Jun 20, 91  JES   - Fixed FindObstacles so it doesn't try to call
                        CheckResourceOnDate for violation date = maxdate.
   Jun 21, 91  AJL   - In UnbumpTasks, unlock the BumpeeHandle before calling
                         RemoveFromResourceAvailability, so that we reduce
                         the number of outstanding locks.
   Jul 12, 91  JES   - Removed DEBUG checks.

   Sep 19, 91  JES   - Fixed TentativelyBumpTasks so that it does not
                        add a task to the BumpeeList if it was already
                        on it. Fixes bug #5154.
   Nov 13, 91  JES      Changed BumpeeList to be an array of elements of
                         the new type Bumpee, which consists of a task handle
                         and a boolean to indicate whether or not the task's
                         resources have been freed. (Previously, it was just
                         a list of task handles.) Now, DoTentativeBumping
                         frees the resources only of tasks who did not reach
                         the bumpee list via the 
                        "TentativelyBumpMuchLowerPriorityTasks" procedure,
                         since those tasks already had their resources
                         freed there. Fixes bug 5351A.
   Jan 22, 92  JES      Fixed TentativelyBumpAllMuchLowerPriorityTasks so
                         it checks MaxTasksToBump (and does not exceed it).        
   Feb  4, 92  AJL     -Convert rates to REAL.

*)
(*V2=PRINT WITH debugging printouts. *)

FROM Allocs      IMPORT
    (* TYPE *)          ATaskPtr, ATask, ATaskFlag, AFixType, 
                        ASplittingRule, ADurationMethod,
    (* PROC *)          GetCodingField;

FROM Assignments IMPORT
    (* TYPE *)          AnAssignmentArray, AnAssignmentRecord,
    (* PROC *)          DurationOf;

FROM Dialog      IMPORT FatalError, ErrorPhrase;

FROM FlexStor    IMPORT
    (* TYPE *)          AnExtHandle,
    (* PROC *)          LockObject, LockObjectArray, ObjectsAreSame,
                        ReleaseUnchangedObject, ReleaseObject;

FROM LongConvert IMPORT LongToReal;

FROM Planner     IMPORT ScheduleComputedOk;

FROM PTaskList      IMPORT
    (* TYPE *)          AlreadyScheduled,
    (* PROC *)          TaskResourceAmount,  AddBefore;

FROM ResAvailableResources IMPORT
    (* PROC *)          AmountAvailableOnDate, CheckResourceOnDate;

FROM ResConstants IMPORT
    (* CONST *)         Zero, DontBump,
    (* VAR *)           SchedulingAbandoned;

FROM ResPriority  IMPORT
    (* PROC *)          BPreemptA, MuchHigherPriority;


FROM ResScheduleTaskResources IMPORT
    (* PROC *)          DeactivateTask, RemoveFromResourceAvailability;

FROM ResUtilities IMPORT
    (* PROC *)          ResourceAssignedAtDate, 
                        TaskUsesNoEmployableResources, 
                        ToGoDurationOfEffortDrivenTask,
                        CheckResourceDuration,
                        TaskDuration,
                        TasksMightHaveResourcesInCommon;

FROM ResWarnings IMPORT
    (* TYPE *)          AWarning,
    (* PROC *)          IssueWarning, SendErrorMsg;

FROM RsrcMod     IMPORT
    (* TYPE *)          AResourcePointer, AResourceType;

FROM Schedule    IMPORT  ZeroIsLowestPriority;


FROM SYSTEM         IMPORT  TSIZE;
    (* PROC *)

FROM Timei       IMPORT
    (* TYPE *)          ADate, ADuration, MaxDate;

(*  ------------------------ Import if tracing ------------------*)
(*<PRINT
FROM LStrings     IMPORT ConcatS, ConcatLS, SetString, CtoS;
FROM PrintSupport IMPORT StartReport, EndReport;
FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat;
FROM ResTrace     IMPORT PrintOn, NoteString, PrintAString, PrintList,
                                ConcatTaskID, PrintResidueAvailability;
FROM TimeFormat   IMPORT TimeUtoS;
VAR
    s : ARRAY [0..255] OF CHAR;
PRINT>*)

CONST
    MaxResourcesToCollect = 50;

TYPE
    AnObstacle = RECORD
                     Resource    : AResourcePointer;
                       (* the resource with the obstacle *)
                     Date        : ADate;
                       (* the date of the obstacle *)
                     Vacation    : BOOLEAN;
                       (* true iff the obstacle is due to a vacation as
                           opposed to a resource shortage *)
                     AmountShort : REAL;
                       (* if obstacle is due to a resource shortage,
                          the amount of the shortage *)
                 END;
    AnObstacleArray = ARRAY[1..MaxResourcesToCollect] OF AnObstacle;

    AContribution = REAL;
        (* represents contribution to obstacle removal by potential bumpee *)

    AContributionArray = ARRAY[1..MaxResourcesToCollect] OF AContribution;

(*------ TentativelyBumpTasks-----------------------------
        NOTE: THIS PROCEDURE ASSUMES THAT "NumBumpees" HAS ALREADY
        BEEN INITIALIZED.
*)

PROCEDURE TentativelyBumpTasks (ActiveList         : AnExtHandle;
                                BumperHandle       : AnExtHandle;
                                DesiredStartDate   : ADate;
                                DoWeForceBump      : BOOLEAN;
                            VAR Bumpees            : ABumpeeArray;
                            VAR NumBumpees         : CARDINAL;
                            VAR WeStartedBumping   : BOOLEAN;
                            VAR BumpingSucceeded   : BOOLEAN);
VAR
    Bumper              : ATaskPtr;
    SplittingRule       : ASplittingRule;
    DurationMethod      : ADurationMethod;
    Obstacles           : AnObstacleArray;
    NumObstacles        : CARDINAL; (* number of obstacles found *)
    SomeObstacleReduced : BOOLEAN;
    BumpingCantHelp     : BOOLEAN;

BEGIN
    WeStartedBumping := FALSE;
    BumpingSucceeded := FALSE;

    IF LockObject(BumperHandle,Bumper)=0 THEN FatalError(); END;
    (*<PRINT
    SetString(NoteString,"TENTATIVELY BUMPING FOR ");
    ConcatTaskID(NoteString, Bumper);
    PrintAString(NoteString);
    SetString(NoteString," as of ");
    CtoS(DesiredStartDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    PRINT>*)

    (*<DEBUG
    IF (DesiredStartDate = MaxDate) THEN
        SendErrorMsg("BumpTasks: desired start = maxdate");
        SchedulingAbandoned := TRUE;        
        ScheduleComputedOk := FALSE;
        ErrorPhrase(0);
    END;
    DEBUG>*)

    (* Initialize: *)
      (* note: this procedure assumes NumBumpees is already initialized! *)
    NumObstacles := 0;
    SomeObstacleReduced := FALSE;
    SplittingRule   := Bumper^.SplittingRule;
    DurationMethod  := Bumper^.DurationMethod;


    (* First check whether there are any lower priority tasks at all
       on the active list (that are not already on the bumpee list!);
       and if there aren't, don't waste any more time: *)

    IF NOT (ThereAreLowerPriorityActiveTasks (Bumper, 
                                              BumperHandle,
                                              ActiveList, 
                                              DesiredStartDate,
                                              Bumpees,
                                              NumBumpees)) THEN
        (*<PRINT
        SetString(NoteString, " no bumpable lower priority tasks");
        PrintAString(NoteString);
        PRINT>*)
        ReleaseUnchangedObject(BumperHandle);
        RETURN;
    END;


    (* Find obstacles to bumper task starting on desired date -
       this sets NumObstacles and fills in the Obstacles array: *)
    FindObstacles(Bumper,
                  SplittingRule,
                  DurationMethod,
                  DesiredStartDate,
                  DoWeForceBump,
                  Obstacles,            (* out *)
                  NumObstacles,         (* out *)
                  SomeObstacleReduced,  (* out *)
                  BumpingCantHelp       (* out *));

    (*<DEBUG
        (* verify that there was a reason to call bumping - this
           checks consistency of our model *)
    IF (NumObstacles= 0) THEN
            (* first rule out the case that we had an assignment-driven
               split task such that, for the given desired start date,
               everybody is on vacation: *)
         IF (
             (DurationMethod = AssignmentDriven) 
                        AND             
             (SplittingRule = Split)    
                        AND
             (AllResourcesAreOnVacation(Bumper, DesiredStartDate))
            )  THEN
             (* okay - no error message *)
         ELSE
            (*<PRINT
            SetString(NoteString, "FindObstacles finds no obstacles.");
            PrintAString(NoteString);
            PRINT>*)
            SendErrorMsg("BumpTasks finds no obstacle.");
        END;
    END;
    DEBUG>*)

        (* here's what we actually need to do if no obstacles were
           found because it was an assignment-driven split task with
           everybody on vacation on day 1 (see Debug check above) *)
     IF NumObstacles = 0 THEN
        BumpingCantHelp := TRUE;
        ReleaseUnchangedObject(BumperHandle);
        RETURN;
     END;

    (*<PRINT
    SetString(NoteString, " found ");
    CtoS(NumObstacles, s);
    ConcatLS(NoteString, s);
    ConcatS(NoteString, " obstacles");
    PrintAString(NoteString);
    PRINT>*)

    IF BumpingCantHelp THEN
        (* no amount of bumping can possibly help: *)
        (*<PRINT
        SetString(NoteString, "Bumping couldn't help since there's a vacation obstacles");
        PrintAString(NoteString);
        PRINT>*)
        ReleaseUnchangedObject(BumperHandle);
        RETURN;
    END;

    (* Find potential tasks to bump - this increments NumBumpees and adds to
       the BumpeesArray: *)
    FindBumpees(Bumper, 
                DesiredStartDate, 
                ActiveList,
                NumObstacles,
                Obstacles,            (* in/out *)
                Bumpees,              (* out *)
                NumBumpees,           (* out *)
                SomeObstacleReduced   (* out *));

    (*<PRINT
    SetString(NoteString, "  found ");
    CtoS(NumBumpees, s);
    ConcatLS(NoteString, s);
    ConcatS(NoteString, " bumpees");
    PrintAString(NoteString);
    PRINT>*)

    (* Determine if bumping is profitable enough to remove all
       bottlenecks to the bumper task starting on DesiredStartDate.
       For all tasks other than effort-driven split, this is true iff
       all obstacles can be removed by bumping all bumpees found.

       For an effort-driven split task, all bottlenecks will
       be removed if at least one obstacle can be removed -
       because, barring end-date constraints,
       an effort-driven split task can start at any date at
       which there is at least one resource available in the required
       amount (and not on vacation).
    *)

    IF (SplittingRule = Split) AND (DurationMethod = EffortDriven) THEN
        BumpingSucceeded := SomeObstacleReduced;
    ELSE
        BumpingSucceeded := (NOT ObstaclesRemain(Obstacles, NumObstacles));
    END;

    (*<PRINT
    IF BumpingSucceeded THEN
       SetString(NoteString, "All first-order obstacles removed.");
    ELSE
       SetString(NoteString, "Remaining obstacles = ");
       CtoS(NumObstacles, s);
       ConcatLS(NoteString, s);
    END;
    PrintAString(NoteString);
    PRINT>*)

    (* Bump all the bumpees, provided that either (1) we could remove
       all obstacles by doing so or (2) a forcible bump was called for: *)

    IF (NumBumpees >0) AND ((BumpingSucceeded) OR (DoWeForceBump)) THEN
        (*<PRINT
        SetString(NoteString, " bumping for task ");
        ConcatTaskID(NoteString, Bumper);
        PrintAString(NoteString);
        PRINT>*)
        WeStartedBumping := TRUE;
        DoTentativeBumping(Bumpees, NumBumpees);
    END;

    ReleaseObject(BumperHandle);

END TentativelyBumpTasks;

(* ---- FindObstacles:

          Find all the "first-order" bottlenecks for Bumper task
          with respect to Date, and put them into ObstaclesList.
          That is, for each resource assigned to Bumper, find the
          first resource conflict or vacation violation (if any)
          that would occur if Bumper were to start on Date.

          (Note on effort-driven split tasks:
          A start date is feasible for an effort-driven
          split task if, for some employable resource, the resource is
          not on vacation on that date and either (i) the resource is not
          levellable or (ii) there is no resource shortage on that date,
          where "shortage" means " < 0 " if contouring and not 
          force-scheduling, and means " < max rate percent " 
          if not contouring or if force-scheduling:
          HOWEVER: in finding obstacles, we take the course of pretending
          that we want each employable resource to be available at max rate
          percent for the entire "remaining duration" (i.e., we pretend
          that we are not contouring and that we are force scheduling).
          This allows us to free as many required resources as possible,
          and could have the effect of shortening the resulting length
          of the task. This approach can't do any harm, since we only
          bump lower-priority tasks anyway.)

          If DoWeForceBump is FALSE and if any obstacle is due to a vacation,
          then this procedure doesn't proceed with further calculations
          (i.e., it does not process any further resource assignments)
          and returns with BumpingCantHelp as TRUE. (This is
          because there is no need to proceed if DoWeForceBump is FALSE and
          BumpingCantHelp is TRUE, since NO AMOUNT OF BUMPING CAN REMOVE
          A VACATION OBSTACLE).

          Effects: sets NumObstacles, the Obstacles array, SomeObstacleReduced,
             and BumpingCantHelp. *)

PROCEDURE FindObstacles (Bumper               : ATaskPtr;
                         SplittingRule        : ASplittingRule;
                         DurationMethod       : ADurationMethod;
                         DesiredStartDate     : ADate;
                         DoWeForceBump        : BOOLEAN;
                     VAR Obstacles            : AnObstacleArray;
                     VAR NumObstacles         : CARDINAL;
                     VAR SomeObstacleReduced  : BOOLEAN;
                     VAR BumpingCantHelp      : BOOLEAN);
VAR


    ViolationDate, AssignmentEndDate,
      ResourceEndDate : ADate;

    ResourceDurationRequired, DurationRequired,
      DurationFound : ADuration;

    Obstacle                   : AnObstacle;
    ResourceCount, i           : CARDINAL;
    AmountAvail                : LONGINT;
    RequiredLevel              : REAL;
    AssignmentHandle           : AnExtHandle;
    Assignments                : AnAssignmentArray;
    Resource                   : AResourcePointer;
    DoWeAllowVacations, DoWeCountVacations, DateIsGoodForResource, DateIsVacation,
      DoWeIgnoreResourceLevels : BOOLEAN;
BEGIN

    (*<PRINT
    SetString(NoteString,"FindObstaclesFor ");
    ConcatTaskID(NoteString,Bumper);
    ConcatS(NoteString,", from ");
    CtoS(DesiredStartDate,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    PRINT>*)

    NumObstacles := 0;

    (*<DEBUG
       (* caller should recognize this condition and not call us *)
    IF (TaskUsesNoEmployableResources(Bumper)) THEN
        (* no obstacles *)
        SendErrorMsg("FindObstacles called for task w no emp resources.");
        RETURN;
    END;
    DEBUG>*)

    AssignmentHandle := Bumper^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));
    (*<DEBUG
       (* caller should recognize this condition and not call us *)
    IF (ResourceCount = 0) THEN
        (* no obstacles *)
        ReleaseUnchangedObject(AssignmentHandle);                
        SendErrorMsg("FindObstacles called for task w no assignments.");
        RETURN;
    END;
    DEBUG>*)

    DoWeAllowVacations   := (SplittingRule = Split);
    DoWeCountVacations   := (DurationMethod = DurationDriven);
       (* Bumping if futile if some obstacle is due to
       a vacation - so we set it to false, and change it to true if we
       find any vacation obstacle *)
    BumpingCantHelp  := FALSE;

        (* Loop thru resources, finding first obstacle (if any) for each. *)
    i := 0;
    WHILE (i < ResourceCount) AND (NOT BumpingCantHelp) DO
        Resource := Assignments^[i].Resource;

            (* we don't touch or consider non-employable resources *)
        IF (Resource^.Type = Employable) THEN
            (* PSEUDOCODE:
                  1. DETERMINE THE REQUIRED RESOURCE DURATION;
                  2. FIND THE FIRST OBSTACLE;
                  3. IF A VACATION OBSTACLE, THEN SET BUMPING CANT HELP TO 
                      TRUE, AND IF NOT FORCE BUMP THEN EXIT;
             *)

            (* Determine the required duration of this resource: *)
            IF (DurationMethod = DurationDriven) THEN
               ResourceDurationRequired := Bumper^.duration;
                (* note: the above is correct since, for a duration-driven
                   task, cpm either schedules the whole task (in which 
                   case levelling would not be trying to place it at all)
                   or schedules none of it - so since levelling is now
                   trying to schedule the task, cpm must not have
                   scheduled any of it and the whole duration remains
                   to be scheduled *)
            ELSIF (DurationMethod = EffortDriven) THEN
               ResourceDurationRequired := ToGoDurationOfEffortDrivenTask(Bumper);
            ELSE (* task is assignment driven *)
               ResourceDurationRequired :=
                    DurationOf(Assignments^[i].MaxRatePercent,
                           Assignments^[i].YetToGoQuantity);
            END;

            (* If a levellable resource, then get the required resource level: *)
            IF (Resource^.LevelThisResource) THEN
                (* get resource level required - even if the
                   task is effort-driven split, and thus is a contour
                   task, we still take max rate percent as the desired level 
                *)
                RequiredLevel := FLOAT( Assignments^[i].MaxRatePercent );
                DoWeIgnoreResourceLevels := FALSE;
            ELSE
                RequiredLevel := Zero; (* this value will not be used *)
                DoWeIgnoreResourceLevels := TRUE;
            END;

            (* Search for the first obstacle, if any: *)

            (* A minor optimization is inserted here, namely:
                If both DoWeIgnoreResourceLevels and DoWeAllowVacations are true,
                then there can't be any obstacle for this resource,
                so we don't bother to pass through dates *)

            IF (DoWeIgnoreResourceLevels AND DoWeAllowVacations) THEN
                (*<PRINT
                SetString(NoteString, "ignore levels & allow vacations so date is good");
                PrintAString(NoteString);
                PRINT>*)
                DateIsGoodForResource := TRUE;
            ELSE
                (* NOTE ON LOCKING: at this point, Bumper and Assignments are
                   locked. CheckResourceDuration will lock an availability cell.
                   Thus, we will now fulfill the limit of three locked objects. *)
    
                CheckResourceDuration(Resource,
                                      DesiredStartDate,
                                      RequiredLevel,
                                      ResourceDurationRequired,
                                      DoWeAllowVacations,
                                      DoWeCountVacations,
                                      DoWeIgnoreResourceLevels,
                                      DateIsGoodForResource,
                                      ResourceEndDate,
                                      ViolationDate);
                 (*<PRINT
                 SetString(NoteString, "  after CheckResourceDuration:");
                 PrintAString(NoteString);
                 SetString(NoteString, "          DateIsGoodForResource = ");
                 IF DateIsGoodForResource THEN
                     ConcatS(NoteString, "TRUE");
                 ELSE
                     ConcatS(NoteString, "FALSE");
                 END;
                 PrintAString(NoteString);
                 PRINT>*)
            END;

             (* If we found an obstacle, see what kind it is - vacation
                obstacles take priority (since they are "worse" in that
                they are not removable: *)
  
             IF NOT (DateIsGoodForResource) THEN
                 (* found an obstacle: *)
                 (*<PRINT
                  SetString(NoteString, "found an obstacle on:");
                  CtoS(ViolationDate, s);
                  ConcatLS(NoteString, s);
                  PrintAString(NoteString);
                  PRINT>*)
                  INC(NumObstacles);
                  Obstacles[NumObstacles].Resource := Resource;
                  Obstacles[NumObstacles].Date     := ViolationDate;
                  IF ViolationDate < MaxDate THEN
                      (* see if it's a vacation or a resource shortage: *)
                      CheckResourceOnDate(Resource,
                                          ViolationDate,
                                          FALSE, (*DoWeUseLateAvailabilities*)
                                          AmountAvail,
                                          DateIsVacation);
                      IF (DateIsVacation) AND (NOT DoWeAllowVacations) THEN
                          (*<PRINT
                          SetString(NoteString, 
                           "   found a vacation obstacle; bumping can't help");
                          PrintAString(NoteString);
                          PRINT>*)
                          BumpingCantHelp := TRUE;
                          Obstacles[NumObstacles].Vacation := TRUE;
                          (*<PRINT
                          IF NOT (DoWeForceBump) THEN
                              SetString(NoteString, "   not force bump, so bumping exits");
                              PrintAString(NoteString);
                          END;
                          PRINT>*)
                      ELSE
                         (*<PRINT
                         SetString(NoteString, "     found a resource shortage obstacle");
                         PrintAString(NoteString);
                         PRINT>*)
                         Obstacles[NumObstacles].Vacation := FALSE;
                         Obstacles[NumObstacles].AmountShort := RequiredLevel 
                                                    - LongToReal(AmountAvail);
                      END; (* DateIsvacation *)
                  ELSE (* violation date is maxdate, i.e., end of calendar *)
                      (*<PRINT
                      SetString(NoteString, "  end-of-calendar obstacle");
                      PrintAString(NoteString);
                      PRINT>*)
                      INC(NumObstacles);
                      Obstacles[NumObstacles].Date := MaxDate;
                      BumpingCantHelp := TRUE;
                  END; (* whether violation date was < MaxDate *)
              END; (* found an obstacle *)
          END; (* employable resource *)
        INC(i);
    END; (* end loop *)
    ReleaseUnchangedObject(AssignmentHandle);

END FindObstacles;



(* ---- FindBumpees -----------------------------------------

     Search the active list for lower-priority tasks
     (in the sense of "BPreemptsA") which, if bumped,
     could contribute to the removal of obstacles.
     (Note: we look for tasks that are not already
     on the BumpeesList!)

     Tasks that were completely scheduled by cpm (i.e.,
     that have the AlreadyScheduled flag set)
     cannot be bumped, nor can tasks which have the DontBump flag set.
     As a simple heuristic, we prefer to bump tasks that start
     later; so the active list is searched in reverse order.

     Effects: Sets NumBumpees and the Bumpees array, and
     reduces obstacles accordingly by reducing them according
     to the contributions made by the bumpees.
*)

PROCEDURE FindBumpees (Bumper           : ATaskPtr;
                       DesiredStartDate : ADate;
                       ActiveList       : AnExtHandle;
                       NumObstacles     : CARDINAL;
                   VAR Obstacles        : AnObstacleArray;
                   VAR Bumpees          : ABumpeeArray;   
                   VAR NumBumpees       : CARDINAL;
                   VAR SomeObstacleReduced : BOOLEAN);

VAR
    BumpeeHandle, NextHandle : AnExtHandle;
    Bumpee : ATaskPtr;
    ContributionSet : AContributionArray;
    SomeContribution, BumpeeHasLowerPriority : BOOLEAN;
BEGIN
    (*<PRINT
    SetString(NoteString, "find bumpees:");
    PrintAString(NoteString);    
    PRINT>*)

    BumpeeHandle := ActiveList;
    IF LockObject(BumpeeHandle,Bumpee)=0 THEN FatalError(); END;
    LOOP
        NextHandle := Bumpee^.Prevlink;
        (* release previous element: *)
        ReleaseUnchangedObject(BumpeeHandle);     (*<KILL*)  Bumpee := NIL; (*KILL>*)
        BumpeeHandle := NextHandle;

        (* Exit if end of active list, or reached max tasks to bump,
           or all obstacles removed: *)
        IF ((ObjectsAreSame(BumpeeHandle,ActiveList)) OR
           (NumBumpees >= MaxTasksToBump) OR
           (NumObstacles = 0)) THEN
           EXIT;
        END;

        IF LockObject(BumpeeHandle,Bumpee)=0 THEN FatalError(); END;
            (*<PRINT
            SetString(NoteString,"    FindBumpees checks task ");
            ConcatTaskID(NoteString,Bumpee);
            PrintAString(NoteString);
            PRINT>*)
        IF (TaskNotAlreadyABumpee(BumpeeHandle, Bumpees, NumBumpees)) THEN
            BumpeeHasLowerPriority := BPreemptA(Bumpee,Bumper,DesiredStartDate);
            (*<PRINT
            IF BumpeeHasLowerPriority THEN
                SetString(NoteString, "  lower priority task - potential bumpee:");
            ELSE
                SetString(NoteString, "  higher priority task - not potential bumpee");
            END;
            PrintAString(NoteString);
            PRINT>*)

            IF (BumpeeHasLowerPriority) AND (TaskIsBumpable(Bumpee)) THEN
                FindBumpeeContribution(Bumpee,
                                       DesiredStartDate,
                                       Obstacles,
                                       NumObstacles,
                                       ContributionSet,  (* out *)
                                   SomeContribution  (* out *));
                IF SomeContribution THEN
                    (*<PRINT
                    SetString(NoteString, "  bumpee makes contribution");
                    PrintAString(NoteString);
                    PRINT>*)
                    RecordBumpee(BumpeeHandle, 
                                 Bumpee, 
                                 ContributionSet,
                                 NumObstacles,
                                 Obstacles,           (* in/out *)
                                 Bumpees,             (* in/out *)
                                 NumBumpees,          (* in/out *)
                                 SomeObstacleReduced  (* in/out *));

                (*<PRINT
                ELSE
                    SetString(NoteString, " no contribution from potential bumpee");
                    PrintAString(NoteString);
                PRINT>*)
                END;
            END;
        END;
    END; (* end loop *)
END FindBumpees;


(* ---- FindBumpeeContribution ---------------------------------
    Determines if bumping the "Bumpee" task could
    contribute to the removal of any obstacles. If so, the
    contributions are recorded in the ContributionSet array,
    and SomeContribution is set to TRUE.
*)

PROCEDURE FindBumpeeContribution (Bumpee             : ATaskPtr;
                                  DesiredStartDate   : ADate;
                                  Obstacles          : AnObstacleArray;
                                  NumObstacles       : CARDINAL;
                             VAR  ContributionSet    : AContributionArray;
                             VAR  SomeContribution   : BOOLEAN);
VAR
    i : CARDINAL;
BEGIN
    (* determine contributions: *)
    SomeContribution := FALSE;

    (*<DEBUG
    IF NumObstacles = 0 THEN
        SendErrorMsg("FindBumpeeContribution called when no obstacles exist");
        SchedulingAbandoned := TRUE;
        ScheduleComputedOk := FALSE;
        ErrorPhrase(0);
    END;
    DEBUG>*)

    FOR i := 1 TO NumObstacles DO
        (* For the i'th obstacle, determine if the bumpee uses the
            resource in question on the obstacle date. If the obstacle
            is a vacation obstacle, we don't care about any possible
            resource contributions, so we only say there is a contribution
            if the obstacle is not a vacation. *)
        IF NOT (Obstacles[i].Vacation) THEN
            ContributionSet[i] :=
                 ResourceAssignedAtDate(Bumpee,
                                        Obstacles[i].Resource,
                                        Obstacles[i].Date);
            IF ContributionSet[i] > Zero THEN
                SomeContribution := TRUE;
            END;
        END;
    END;
END FindBumpeeContribution;

(* ---- RecordBumpee ------------------------------------------
   Pretend the bumpee is bumped by adding it to
   the bumpee list and removing whatever it can contribute from the
   obstacles list. Effects: adds bumpee to the bumpee list, and
   reduces obstacles according to the bumpee's contribution.
*)

PROCEDURE RecordBumpee (BumpeeHandle        : AnExtHandle;
                        Bumpee              : ATaskPtr;
                        ContributionSet     : AContributionArray;
                        NumObstacles        : CARDINAL;
                    VAR Obstacles           : AnObstacleArray;
                    VAR Bumpees             : ABumpeeArray;
                    VAR NumBumpees          : CARDINAL;
                    VAR SomeObstacleReduced : BOOLEAN);
VAR
    i : CARDINAL;
BEGIN
    (*<PRINT    
    SetString(NoteString, "recording bumpee ");        
    ConcatTaskID(NoteString, Bumpee);    
    PrintAString(NoteString);
    PRINT>*)

    (* add bumpee to the bumpee list *)
    INC(NumBumpees);
    Bumpees[NumBumpees].TaskToBump             := BumpeeHandle;
    Bumpees[NumBumpees].ResourcesHaveBeenFreed := FALSE;

    (*<DEBUG
    IF NumObstacles = 0 THEN
        SendErrorMsg("RecordBumpee called when no obstacles exist");
        FatalError();
    END;
    DEBUG>*)

    (* remove bumpee's contribution from the obstacles list: *)
    FOR i := 1 TO NumObstacles DO
        IF NOT (Obstacles[i].Vacation) THEN
            Obstacles[i].AmountShort := Obstacles[i].AmountShort -
                ContributionSet[i];
            (* record that the obstacle was reduced - this information
               is used in the case of a effort-driven split bumper
               task *)
            SomeObstacleReduced := TRUE;
        END;
    END;
END RecordBumpee;



(* -------------- DoTentativeBumping ----------------------------------
   For all tasks on the bumpee list, add their
   resource usage back into the residue availabilities
*)

PROCEDURE DoTentativeBumping(VAR Bumpees: ABumpeeArray;
                                 NumBumpees : CARDINAL);

BEGIN
    (*<PRINT
    SetString(NoteString, "   DOING THE TENTATIVE BUMPING");
    PrintAString(NoteString);
    PRINT>*)

    IF NumBumpees = 0 THEN
        (*<PRINT
        SetString(NoteString, "DoTentativeBumping: no bumpees.");
        PrintAString(NoteString);
        PRINT>*)
        RETURN;
    END;
    DeactivateBumpees(Bumpees,
                      NumBumpees,
                      AnExtHandle(NIL), (* UnscheduledList - not used *)
                      TRUE,             (* DoWeFreeTaskResources *)
                      FALSE,            (* DoWeRemoveVaryingAssignments *)
                      FALSE             (* DoWeMoveToUnscheduledList *));
END DoTentativeBumping;




(* ------- ThereAreLowerPriorityActiveTasks ------------------------------

   Returns TRUE iff there is at least one task on the active list 
   (that is not already on the bumpee list!) whose
   priority is lower than Task's (in the sense of BPreemptA), AND
   who might have some resource(s) in common with Task.
*)

PROCEDURE ThereAreLowerPriorityActiveTasks (Bumper           : ATaskPtr;
                                            BumperHandle     : AnExtHandle;
                                            ActiveList       : AnExtHandle;
                                            DesiredStartDate : ADate;
                                            Bumpees          : ABumpeeArray;
                                            NumBumpees       : CARDINAL) : BOOLEAN;

VAR
    ActiveTaskHandle, NextHandle : AnExtHandle;
    ActiveTask : ATaskPtr;
    ActiveTaskHasLowerPriority, 
       FoundALowerPriorityTask : BOOLEAN;

BEGIN
    FoundALowerPriorityTask := FALSE;

    ActiveTaskHandle := ActiveList;
    IF LockObject(ActiveTaskHandle, ActiveTask)=0 THEN FatalError(); END;

    (*<PRINT
    SetString(NoteString, "checking for lower priority active tasks:");
    PrintAString(NoteString);    
    PRINT>*)

    LOOP
        NextHandle := ActiveTask^.Prevlink;
        ReleaseUnchangedObject(ActiveTaskHandle);  (*<KILL*)  ActiveTask := NIL; (*KILL>*)
   
        ActiveTaskHandle := NextHandle;

        (* Exit if end of active list or found lower priority task: *)
        IF ((ObjectsAreSame(ActiveTaskHandle,ActiveList)) OR
           (FoundALowerPriorityTask)) THEN
           EXIT;
        END;

        IF LockObject(ActiveTaskHandle, ActiveTask)=0 THEN FatalError(); END;
            (*<PRINT
            SetString(NoteString,"  ThereAreLowerPriorityTasks checks task ");
            ConcatTaskID(NoteString, ActiveTask);
            PrintAString(NoteString);
            PRINT>*)
        IF (TaskNotAlreadyABumpee(ActiveTaskHandle, Bumpees, NumBumpees)) THEN
            ActiveTaskHasLowerPriority := BPreemptA(ActiveTask,Bumper,DesiredStartDate);

            IF (
                (ActiveTaskHasLowerPriority) AND
                (NOT (DontBump IN ActiveTask^.TempTaskFlags)) AND
                (NOT (AlreadyScheduled IN ActiveTask^.TempTaskFlags)) AND
                (TasksMightHaveResourcesInCommon(ActiveTask, Bumper))
               ) THEN
               FoundALowerPriorityTask := TRUE;
            END;
        END;
    END; (* end loop *)

    (*<PRINT
    IF (FoundALowerPriorityTask) THEN
        SetString(NoteString, " found lower priority task");
    ELSE
        SetString(NoteString, " no lower-priority tasks found");
    END;
    PrintAString(NoteString);
    PRINT>*)

    RETURN (FoundALowerPriorityTask);

END ThereAreLowerPriorityActiveTasks;

PROCEDURE FinishBumpingTasks (Bumpees         : ABumpeeArray;
                              NumBumpees      : CARDINAL;
                              PreCandidatesList : AnExtHandle);

BEGIN
    (*<PRINT
    SetString(NoteString, "   FINISH BUMPING");
    PrintAString(NoteString);
    PRINT>*)

    IF NumBumpees = 0 THEN
        (*<PRINT
        SetString(NoteString, "FinishBumpingTasks: no bumpees.");
        PrintAString(NoteString);
        PRINT>*)
        RETURN;
    END;
    DeactivateBumpees(Bumpees,
                      NumBumpees,
                      PreCandidatesList,
                      FALSE, (* DoWeFreeTaskResources *)
                      TRUE,  (* DoWeRemoveVaryingAssignments *)
                      TRUE   (* DoWeMoveToPreCandidatesList *));
END FinishBumpingTasks;


(* -------------- DeactivateBumpees ----------------------------------
   Called by DoTentativeBumping and FinishBumping. For each bumpee
   in the list, do some combination of the following: free its
   resources from the residue availabilities, remove its varying
   assignment structures, and move it to the unscheduled list.
*)
PROCEDURE DeactivateBumpees (VAR Bumpees               : ABumpeeArray;
                                 NumBumpees            : CARDINAL;
                                 PreCandidatesList       : AnExtHandle;
                                 DoWeFreeTaskResources        : BOOLEAN;
                                 DoWeRemoveVaryingAssignments : BOOLEAN;
                                 DoWeMoveToPreCandidatesList    : BOOLEAN);

VAR
    ResourceCount, i, j            : CARDINAL;
    BumpeeHandle, AssignmentHandle : AnExtHandle;
    Bumpee                         : ATaskPtr;
    Assignments                    : AnAssignmentArray;
    DeactivationStartDate          : ADate;
    FreeTheResources               : BOOLEAN;
BEGIN
    (*<DEBUG
    IF NumBumpees = 0 THEN
        SendErrorMsg("DeactivateBumpees called with NumBumpees = 0");
        ErrorPhrase(0);
        SchedulingAbandoned := TRUE;
        ScheduleComputedOk := FALSE;
        RETURN;
    END;
    DEBUG>*)

    FOR i := 1 TO NumBumpees DO
        BumpeeHandle := Bumpees[i].TaskToBump;
        IF LockObject(BumpeeHandle, Bumpee)=0 THEN FatalError(); END;
        (*<PRINT
        SetString(NoteString, " deactivating bumpee ");
        ConcatTaskID(NoteString, Bumpee);
        PrintAString(NoteString);
        PRINT>*)

            (* set deactivation start date to "count", the date at
             which levelling originally scheduled the task: *)           

        DeactivationStartDate := Bumpee^.count;

        FreeTheResources := (DoWeFreeTaskResources) AND 
                              NOT (Bumpees[i].ResourcesHaveBeenFreed);

        (*<PRINT
        SetString(NoteString, "DoWeFreeTaskResources = ");
        IF (DoWeFreeTaskResources) THEN 
            ConcatS(NoteString, "TRUE");        
        ELSE
            ConcatS(NoteString, "FALSE");
        END;
        PrintAString(NoteString);

        SetString(NoteString, "ResourcesHaveBeenFreed was ");
        IF (Bumpees[i].ResourcesHaveBeenFreed) THEN 
            ConcatS(NoteString, "TRUE");        
        ELSE
            ConcatS(NoteString, "FALSE");
        END;
        PrintAString(NoteString);

        SetString(NoteString, "FreeTheResources = ");
        IF (FreeTheResources) THEN 
            ConcatS(NoteString, "TRUE");        
        ELSE
            ConcatS(NoteString, "FALSE");
        END;
        PrintAString(NoteString);
        PRINT>*)        

        DeactivateTask(BumpeeHandle, 
                       Bumpee, 
                       DeactivationStartDate,
                       PreCandidatesList,
                       DoWeRemoveVaryingAssignments,
                       FreeTheResources,
                       DoWeMoveToPreCandidatesList);

        IF (FreeTheResources) THEN
            Bumpees[i].ResourcesHaveBeenFreed := TRUE;
        END;

        ReleaseObject(BumpeeHandle);

        IF SchedulingAbandoned THEN
            ScheduleComputedOk := FALSE;
            RETURN;
        END;
    END;
END DeactivateBumpees;
                              

(* -------------- UnbumpTasks ----------------------------------
   Restore resource availabilities to what they were before
   tentative bumping.
*)

PROCEDURE UnbumpTasks (Bumpees    : ABumpeeArray;
                       NumBumpees : CARDINAL);


VAR
    ResourceCount, i, j            : CARDINAL;
    BumpeeHandle, AssignmentHandle : AnExtHandle;
    Bumpee                         : ATaskPtr;
    Assignments                    : AnAssignmentArray;
    ActivationDate                 : ADate;
BEGIN

    (*<PRINT
    SetString(NoteString, "   UNBUMPING");
    PrintAString(NoteString);
    PRINT>*)

    IF NumBumpees = 0 THEN
        (*<PRINT
        SetString(NoteString, "UnbumpTasks: no bumpees.");
        PrintAString(NoteString);
        PRINT>*)
        RETURN;
    END;

    FOR i := 1 TO NumBumpees DO
        BumpeeHandle := Bumpees[i].TaskToBump;
        IF LockObject(BumpeeHandle, Bumpee)=0 THEN FatalError(); END;
        (*<PRINT
        SetString(NoteString, "   bumpee = ");
        ConcatTaskID(NoteString, Bumpee);
        PrintAString(NoteString);
        PRINT>*)

        IF NOT (Bumpees[i].ResourcesHaveBeenFreed) THEN
            (* we don't have to restore the resource usage, since
                resources weren't freed *)
            ReleaseUnchangedObject(BumpeeHandle);
            (*<PRINT
            SetString(NoteString, "resources weren't freed for this task");
            PrintAString(NoteString);
            PRINT>*)    
        ELSE
            (* update the resource availabilities: *)
                (* set activation date to "count", the date at
                   which levelling originally scheduled the task: *)           
            ActivationDate := Bumpee^.count;
            AssignmentHandle := Bumpee^.Plan.Assignments;
            ReleaseObject(BumpeeHandle);  (*<KILL*) Bumpee := NIL; (*KILL>*)
            ResourceCount    := LockObjectArray(AssignmentHandle,
                                                Assignments,  
                                                TSIZE(AnAssignmentRecord));
            RemoveFromResourceAvailability(Assignments, ResourceCount, ActivationDate);
            ReleaseObject(AssignmentHandle);
        END;
    END;
END UnbumpTasks;


(* ---- ObstaclesRemain --- runs through the obstacles list,
         checking for any that have been effectively removed by
         simulating a bump (i.e., amount needed = 0), and removes
         any such elements from the list and dec's numobstacles
         accordingly. *)

PROCEDURE ObstaclesRemain (VAR Obstacles    : AnObstacleArray;
                           VAR NumObstacles : CARDINAL) : BOOLEAN;

VAR
    i : CARDINAL;
BEGIN
    IF NumObstacles = 0 THEN
        RETURN FALSE;
    END;

    i := 1;
    WHILE (i <= NumObstacles) DO
        IF ((Obstacles[i].AmountShort > Zero) OR
                 (Obstacles[i].Vacation)) THEN
            (*<PRINT
            SetString(NoteString, "   BumpTasks still needs resource ");
            ConcatLS(NoteString,Obstacles[i].Resource^.Name);
            PrintAString(NoteString);
            IF Obstacles[i].Vacation THEN
              SetString(NoteString, "    because of vacation obstacle");
            ELSE
              SetString(NoteString, "    because of resource shortage");
            END;
            PRINT>*)
          INC(i);
        ELSE
           (*<PRINT
           SetString(NoteString,"    BumpTasks no longer needs resource ");
           ConcatLS(NoteString,Obstacles[i].Resource^.Name);
           PrintAString(NoteString);
           PRINT>*)
            (* shift the last element into the i'th place, and remove
                the last element (i.e., delete the i'th element): *)
            Obstacles[i] := Obstacles[NumObstacles];
            DEC(NumObstacles);
        END;
    END;

    RETURN (NumObstacles >= 1);

END ObstaclesRemain;


PROCEDURE TaskIsBumpable (Task : ATaskPtr) : BOOLEAN;

VAR
    TaskIsMilestone : BOOLEAN;
BEGIN
    TaskIsMilestone := (Task^.DurationMethod = DurationDriven) AND
                        (Task^.duration = 0);
    IF (NOT (TaskIsMilestone)) AND
       (NOT (DontBump IN Task^.TempTaskFlags)) AND
       (NOT (AlreadyScheduled IN Task^.TempTaskFlags)) AND
       (NOT (FrozenTask IN Task^.TaskFlags)) 
    THEN
       RETURN TRUE;
    ELSE
       RETURN FALSE;
    END;
END TaskIsBumpable;


(* --- BumpAllMuchLowerPriorityTasks --------------------------------

   Find any tasks on the active list such that they have (a) "much lower
   priority" than our tasks and (b) might have some resource in common
   with our task. For all such tasks, "tentatively bump them", i.e.: 
   free their resources and put them on the bumpee list.

   NOTE: THIS PROCEDURE ASSUMES THAT "NumBumpees" HAS ALREADY
   BEEN INITIALIZED.

*)

PROCEDURE TentativelyBumpAllMuchLowerPriorityTasks (Bumper           : ATaskPtr;
                                                    ActiveList       : AnExtHandle;
                                                VAR Bumpees          : ABumpeeArray;
                                                VAR NumBumpees       : CARDINAL);
VAR
    ActiveTaskHandle, NextHandle : AnExtHandle;
    ActiveTask : ATaskPtr;
    ActiveTaskHasMuchLowerPriority : BOOLEAN;
BEGIN
    ActiveTaskHandle := ActiveList;
    IF LockObject(ActiveTaskHandle, ActiveTask)=0 THEN FatalError(); END;

    (*<PRINT
    SetString(NoteString, "TENTATIVELY BUMPING MLP TASKS");
    PrintAString(NoteString);    
    PRINT>*)

    LOOP
        NextHandle := ActiveTask^.Prevlink;
        ReleaseUnchangedObject(ActiveTaskHandle);  (*<KILL*)  ActiveTask := NIL; (*KILL>*)
        ActiveTaskHandle := NextHandle;

        (* Exit if end of active list or reached max tasks to bump: *)
        IF ((ObjectsAreSame(ActiveTaskHandle,ActiveList)) OR
           (NumBumpees >= MaxTasksToBump)) THEN
           EXIT;
        END;

        IF LockObject(ActiveTaskHandle, ActiveTask)=0 THEN FatalError(); END;

        ActiveTaskHasMuchLowerPriority := 
(*            (ActiveTask^.priority > Bumper^.priority);*)
           (MuchHigherPriority(ActiveTask,Bumper) = 1);

        IF (
            (ActiveTaskHasMuchLowerPriority) AND
            (NOT (DontBump IN ActiveTask^.TempTaskFlags)) AND
            (NOT (AlreadyScheduled IN ActiveTask^.TempTaskFlags)) AND
            (TasksMightHaveResourcesInCommon(ActiveTask, Bumper))
           ) THEN
              (* add the active task to the bumpee list: *)
             INC(NumBumpees);
             Bumpees[NumBumpees].TaskToBump := ActiveTaskHandle;
             Bumpees[NumBumpees].ResourcesHaveBeenFreed := FALSE;
        END;      
    END; (* end loop *)

    IF (NumBumpees > 0) THEN
            (* free all the bumpees' resources: *)
        (*<PRINT
        SetString(NoteString, " found some bumpees:");
        PrintAString(NoteString);
        PRINT>*)
        DeactivateBumpees(Bumpees,
                          NumBumpees,
                          AnExtHandle(NIL), (* UnscheduledList - not used *)
                          TRUE,             (* DoWeFreeTaskResources *)
                          FALSE,            (* DoWeRemoveVaryingAssignments *)
                          FALSE             (* DoWeMoveToPreCandidatesList *));
    (*<PRINT
    ELSE
        SetString(NoteString, "no bumpees.");
        PrintAString(NoteString);
    PRINT>*)
    END;
END TentativelyBumpAllMuchLowerPriorityTasks;


(* ------ TaskNotAlreadyOnBumpeeList - returns TRUE if task
            is not already on the bumpee list, else returns FALSE *)

PROCEDURE TaskNotAlreadyABumpee (TaskHandle : AnExtHandle;
                                 Bumpees    : ABumpeeArray;
                                 NumBumpees : CARDINAL) : BOOLEAN;
VAR
    i            : CARDINAL;
BEGIN
    IF NumBumpees = 0 THEN     
        RETURN TRUE;
    END;

    FOR i := 1 TO NumBumpees DO
        IF (TaskHandle = Bumpees[i].TaskToBump) THEN
            RETURN FALSE;
        END;
    END;
    RETURN TRUE;
END TaskNotAlreadyABumpee;


(*<DEBUG
PROCEDURE AllResourcesAreOnVacation (Task: ATaskPtr;
                                     Date: ADate) : BOOLEAN;
VAR
    ResourceCount, i : CARDINAL;
    Resource         : AResourcePointer;
    AssignmentHandle : AnExtHandle;    
    Assignments      : AnAssignmentArray;
    Amount           : LONGINT;
    Vacation         : BOOLEAN;
BEGIN    
    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount := LockObjectArray(AssignmentHandle,
                                     Assignments,
                                     TSIZE(AnAssignmentRecord));
    FOR i := 0 TO ResourceCount - 1 DO
        Resource := Assignments^[i].Resource;
        CheckResourceOnDate(Resource,
                            Date,
                            FALSE, (* use late avails *)
                            Amount,
                            Vacation);
        IF NOT (Vacation) THEN
            ReleaseUnchangedObject(AssignmentHandle);
            RETURN FALSE;
        END;
    END;
    ReleaseUnchangedObject(AssignmentHandle);
    RETURN TRUE;
END AllResourcesAreOnVacation;
DEBUG>*)

END ResBumpTasks.

