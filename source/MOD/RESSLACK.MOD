IMPLEMENTATION MODULE ResSlack;
(*V2=PRINT WITH debugging printouts. *)

(* MODIFICATION HISTORY

    Feb. 28, 89 - JES - created from procedures in old Tlrplan, and
                        completely modified to use new resource
                        availability structures.

    May 30, 89  - JES - Fixed bug in FindLateFreeEnds where we used
                        "EarliestDescendantStartDate" instead of
                        "EarliestDescendatnStartDate - 1" for
                        "LatestFitDateToTry" in the call to "LatestContinuous
                        FitDate". When the task used no resources or had
                        duration 0, this resulted in a LateFreeStartDate
                        that was 1 too high.
    June 2, 89 - JES -  Fixed error check in FindLateFreeEnds to coincide
                        with the bug-fix above.
    June 12,89 - JES -  Fixed bug in FindLateFreeEnds where doesn't deal
                        with tasks of duration 0 correctly. (This was
                        causing error box in FindLateFreeEnds to pop up,
                        bug # 528.) Also modified FindLateTotalEnds
                        appropriately.
    June 21,89 - JES -  If we are doing time-constrained levelling (i.e.,
                        levelling within slack), it is possible that the
                        task does not have a resource conflict at its
                        early start (resp late free start) but does have
                        a resource conflict starting at some point in its
                        span. We must treat this case exactly like the
                        case that there is a resource conflict at the
                        start, i.e.: don't compute the late free (resp
                        late total) start, but just set no slack.
    June 27,89 - JES -  Completely restructured FindLateFreeEnds and
                        FindLateTotalEnds because they were ending up
                        big patchworks. Also fixed bug (found by A.Gump)
                        in FindLateFree where slack was erroneously
                        being set to 0 (due to logic error in previous messy
                        structure).
    June 29,89 - JES -  Fixed typo in rewrite of CalculateLateTotalDates,
                        where had FreeEnd being set instead of TotalEnd.

    July 5, 89 - JES -  Fixed two bugs: (1) in both CalculateLateTotalDates
                        and CalculateLateFreeDates, we were erroneously
                        leaving the CPM late dates untouched instead of
                        setting them to earliest antecedant dates; (2)
                        fixed typo in case 6 of CalculateLateFreeDates,
                        where it was erroneously checking "LatestContinuous
                        Fit < LateFreeEnd" instead of " < EarlyEnd".

    July 12, 89 - JES - Modified to exit gracefully when flexstore create
                        fails.
    Aug-30-89   AJL   - Changed name of "InsufficientVirtualMemory" to
                        "SchedulingAbandoned".
    Sep-22-89     AJL - Made sure that the late end dates computed are not
                        earlier than the early ends, which can occasionally
                        happen with done summary tasks.  See the SUMMDN2
                        schedule.
    Sep-25-89    JES -  Put range check into edgedate computation in
                        EarliestDescendantLateTotalStartDate (analogous
                        to the checks put into ResStartDates.
                        EarliestDescendantStartDate, tlcpm, etc)
    Dec-14-89    AJL  - Changed the code so that any task with LockFixedDate
                        in its flags is set to have no slack.  Formerly,
                        only terminal or Started/Done tasks had slack
                        suppressed.  This adds FixedDate tasks to this
                        behavior, and fixes bug number 1938.
                      - Changed what appears to have been a typo in the
                        FindLateFreeEnds procedure.  Case 2a was setting
                        TOTAL, not FREE dates.
    Dec-22-89    JES -  When there are no resources, latefree and latetotal
                        end dates were erroneously set to the descendant's
                        start date minus one, instead of just to the
                        descendant's start date. This is now fixed (and
                        thus obeys the tradition that the "end date" is one
                        moment beyond the time that the task is actually
                        active.)
    30-Mar-90    RSC    Made Timeu to Timei/TimeForm conversions.
    Sept 17 90   JES    Fixed some obsolete imports, and commented out
                        others until we make this module support
                        multiple calendars.
    16-Oct-90    AJL   -Changed use of GetCodingField to ConcatTaskID.
     1-Nov-90    CL   - Rename LockScheduledDates to FrozenTask, 
                        SuppressSlack to ForceCritical.
    21-Dec-90  JES   This module was renamed ResSlack from ResLateDates.
                     (ResLateDates is now a new module that computes
                     late start dates.)
    28-Dec-90  JES   Changed name of FindLate to ComputeSlack.
    04-Jan-91  JES   Began modifications for multiple calendars.
    14-Jan-91  JES   Fixed so Done tasks do not even get their
                        late end dates computed.
    21-Jan-91  JES   Removed unused import TaskFitsAtDate.
    25-Jan-91  JES   Cleaned up procedure ScheduleInLateStructures.
     1-Feb-91  JES   More cleaning  up.
     7-Feb-91  JES   Removed all references to WBSLine.
    25-Feb-91  JES   Added parameter HonorDaysOff to the call to 
                     MakeAvailabilityIntoResidue.
    12-Mar-91  JES   Changed ComputeSlack so that we call ComputeTotalSlack
                     before ComputeFreeSlack, and then use the late total
                     start as an upper limit in computing the late free start.
                     (Otherwise, the late free start was sometimes coming
                     out later than the late total start.)
    25-Mar-91  JES   Fixed SetNoFreeSlack so that it enforces the constraint
                     "late free start <= late total start".
    25-Mar-91  AJL  -Corrected an error in EarliestDescendantLateTotalStartDate
                     in which the sign of the Delta was omitted when 
                     adjusting for Leads (-Delta) on the edge.
                    -Removed references to ActiveList.
                    -Miscellaneous code tightening and error checking.
    25-Mar-91  JES   Fixed bug where SetNoTotalSlack was actually setting
                      the free slack fields.
    25-Mar-91  AJL   (This change note written by JES) 
                     Made procedures InitLateProfileForOneResource
                     and DiscardLateResourceAvailabilities more efficient;
                     fixed misc bugs in EarliestDescendantLateTotalStart.
    26-Mar-91  JES   Implemented further misc improvements resulting 
                     from AJL review. In particular, RemoveNegativeFreeSlack
                     and RemoveNegativeTotalSlack now check late end
                     dates instead of late start dates as their criterion
                     for negative slack.
    16-Apr-91  JES   Improved some print statements.
    19-Apr-91  JES   In ComputeFreeSlackForOneTask, changed two occurrences
                      of ReleaseUnchangedObject(AssignmentsHandle) to
                      ReleaseObject.
    30-Apr-91  JES   Modified both ComputeTotalSlackForOneTask and
                      ComputeFreeSlackForOneTask to incorporate as
                      an upper bound on task end date the cpm-computed
                      late total end date, if we are levelling within
                      slack. That is, if we are levelling within slack,
                      we use a max-task-end-date of min{earliest descendant
                      late total start, cpm-computed task late total end} in 
                      ComputeTotalSlackForOnetask (instead of just
                      earliest descendant late total start), and of
                      min{earliest descendant start, cpm-computed
                      task late totale nd} in ComputeFreeSlackForOneTask
                      (instead of just earliest descendant start). Note
                      that in ComputeTotalSlackForOneTask we have not yet
                      modified the task's own late total end from what was
                      computed in cpm, so we can just use that field. But
                      by the time we get to ComputeFreeSlackForOne task,
                      we have overwritten the task's late total end field.
                      Therefore we use the count2 field to store the original
                      cpm-computed late total end date; we set this field
                      in the ComputeTotalSlack pass, within ComputeTotal
                      SlackForOneTask.
    26-June-91  JES   Fixed ComputeFreeSlackForOneTask and ComputeTotalSlack
                      ForOneTask so that we set no slack for infeasible 
                      tasks (i.e., tasks with the NeedsRecalculate flag set).
    30-July-91  JES   For ForceCritical tasks, instead of setting zero slack,
                      just disallow positive slack (i.e., if the slack turns
                      out to be non-positive, leave it alone; otherwise set
                      it to zero).
    13-Aug-91   JES   Fixed missed cases in the above fix.
     4-Feb-92   AJL  -Convert rates to real.
    26-Feb-92   JES   Fixed so summary tasks are treated as if they have
                        zero duration and no resources.    

*)

FROM Allocs IMPORT
    (* TYPE *)      ATaskPtr, ATask, AFixType, AStartStatus, ATaskFlag,
                    ATaskFlagSet, ATaskStatus, ASplittingRule,
                    ADurationMethod;


FROM Assignments IMPORT
    (* TYPE *)      AnAssignmentArray, AnAssignmentRecord;

FROM CalShift       IMPORT
    (* VAR   *)     TimeSheet;

FROM Dialog IMPORT
    (* PROC *)      FatalError;

FROM Duration       IMPORT
    (* PROC *)      SubtractWorkingTime, AddWorkingTime;

FROM Edges  IMPORT
    (*TYPE *)       AnEdge, AnEdgePtr;

FROM FlexStor IMPORT
    (* TYPE *)      AnExtHandle, AnExtStoragePreference,
    (* PROC *)      LockObject, LockObjectArray,
                    ReleaseObject, ReleaseUnchangedObject, ObjectsAreSame,
                    CopyExtObject, DiscardExtObject;

FROM Planner  IMPORT
    (* VAR *)       ScheduleComputedOk, RecalcOptions, HonorDaysOff,
                     TimeConstrained;

FROM Phantoms       IMPORT SummaryFlag;
    (* CONST *)

FROM  PTaskList      IMPORT
    (* CONST *)     TerminalFlag,
    (* PROC *)      CountDown;

FROM ResCal        IMPORT
    (* PROC *)      DisposeResAvailabilities;

FROM ResCalMG      IMPORT
    (* PROC *)      MakeAvailabilityIntoResidue;

FROM ResConstants IMPORT
    (* CONST *)     ModuleNumber, Zero, HowOften2,
    (* VAR   *)     SchedulingAbandoned;

FROM ResLates     IMPORT
    (* PROC *)      FindLatestStartDate;

FROM ResUtilities   IMPORT
    (* PROC *)      EarliestDescendantStartDate,
                    TaskUsesNoEmployableResources;

FROM ResAvailableResources  IMPORT
    (* PROC *)      AllTaskResourcesAreAvailable;

FROM ResScheduleTaskResources IMPORT
    (* PROC *)      AddToResourceAvailability, 
                    RemoveFromResourceAvailability,
                    RemoveFromLateResourceAvailability,
                    CreateVaryingAssignments;

FROM ResWarnings  IMPORT
    (* TYPE *)      AWarning,
    (* PROC *)      IssueWarning, SendErrorMsg;

FROM RsrcMod      IMPORT
    (* TYPE *)      AResourcePointer, AResourceType,
    (* VAR *)       ResourceTree;

FROM SYSTEM       IMPORT
    (* PROC *)      TSIZE, ADDRESS, ADR;

FROM Timei  IMPORT
    (* TYPE *)      ADate, OneUnitOfDuration, NoDuration, MaxDate, MinDate,
                    ADuration;

FROM TreeObjects  IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder,
    (* PROC *)          ValidateTree, ValidateTreeNode;

FROM VaryAssgnment IMPORT
    (* TYPE *)          AVaryingAssgnList,
    (* PROC *)          CreateVaryingAssgnList, DisposeVaryingAssgnList;




(*  ------------------------ Import if tracing ------------------*)
(*<PRINT
FROM LStrings     IMPORT ConcatS, ConcatLS, CtoS, SetString;
FROM PrintSupport IMPORT StartReport, PrintLine, EndReport;
FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat;
FROM ResTrace     IMPORT NoteString, PrintAString, ConcatTaskID;
FROM TimeFormat   IMPORT TimeUtoS;
VAR
    s : ARRAY [0..255] OF CHAR;
PRINT>*)



(* ----------- SetNoFreeSlack -----------------------------------

   Set the tasks's LateFreeStart and LateFreeEnd to its
   EarlyStart and EarlyEnd, respectively.
*)

PROCEDURE SetNoFreeSlack(Task: ATaskPtr);

BEGIN
    WITH Task^.Plan.Dates DO
        LateFreeStart := EarlyStart;
        LateFreeEnd   := EarlyEnd;
            (* make sure late free is <= late total: *)
        IF LateFreeStart > LateTotalStart THEN
            LateFreeStart := LateTotalStart;
            LateFreeEnd   := LateTotalEnd;
        END;
    END;
END SetNoFreeSlack;


(* ----------- SetNoTotalSlack -----------------------------------

   Set the tasks's LateTotalStart and LateTotalEnd to its
   EarlyStart and EarlyEnd, respectively.
*)

PROCEDURE SetNoTotalSlack(Task: ATaskPtr);

BEGIN
    WITH Task^.Plan.Dates DO
        LateTotalStart := EarlyStart;
        LateTotalEnd   := EarlyEnd;
    END;
END SetNoTotalSlack;


(* -------------- RemoveNegativeFreeSlack ----------------------------

    Make sure late free end is >= early end.
*)

PROCEDURE RemoveNegativeFreeSlack (Task: ATaskPtr);

BEGIN
    WITH Task^.Plan.Dates DO
        IF (LateFreeEnd < EarlyEnd) THEN
            SetNoFreeSlack(Task);            
            (*<PRINT
            SetString(NoteString, "removing negative free slack");
            PrintAString(NoteString);
            PRINT>*)
        END;
    END;
END RemoveNegativeFreeSlack;


(* -------------- RemoveNegativeTotalSlack ----------------------------

    Make sure late total end is >= early end.
*)

PROCEDURE RemoveNegativeTotalSlack (Task: ATaskPtr);

BEGIN
    WITH Task^.Plan.Dates DO
        IF (LateTotalEnd < EarlyEnd) THEN
            SetNoTotalSlack(Task);            
            (*<PRINT
            SetString(NoteString, "removing negative total slack");
            PrintAString(NoteString);
            PRINT>*)
        END;
    END;
END RemoveNegativeTotalSlack;


(* -------------- RemovePositiveFreeSlack ----------------------------

    Make sure late free end is <= early end.
*)

PROCEDURE RemovePositiveFreeSlack (Task: ATaskPtr);

BEGIN
    WITH Task^.Plan.Dates DO
        IF (LateFreeEnd > EarlyEnd) THEN
            SetNoFreeSlack(Task);            
            (*<PRINT
            SetString(NoteString, "removing positive free slack");
            PrintAString(NoteString);
            PRINT>*)
        END;
    END;
END RemovePositiveFreeSlack;


(* -------------- RemovePositiveTotalSlack ----------------------------

    Make sure late total end is <= early end.
*)

PROCEDURE RemovePositiveTotalSlack (Task: ATaskPtr);

BEGIN
    WITH Task^.Plan.Dates DO
        IF (LateTotalEnd > EarlyEnd) THEN
            SetNoTotalSlack(Task);            
            (*<PRINT
            SetString(NoteString, "removing positive total slack");
            PrintAString(NoteString);
            PRINT>*)
        END;
    END;
END RemovePositiveTotalSlack;




PROCEDURE MakeFreeSlackAdjustments (Task: ATaskPtr);
BEGIN
    (* disallow negative slack if the user so specified: *)
    IF NOT (RecalcOptions.AllowNegativeSlack) THEN
        RemoveNegativeFreeSlack(Task);
    END;

    (* disallow positive slack if the task is ForceCritical: *)
    IF ForceCritical IN Task^.TaskFlags THEN
        RemovePositiveFreeSlack(Task);
    END;

END MakeFreeSlackAdjustments;


PROCEDURE MakeTotalSlackAdjustments (Task: ATaskPtr);
BEGIN
    (* disallow negative slack if the user so specified: *)
    IF NOT (RecalcOptions.AllowNegativeSlack) THEN
        RemoveNegativeTotalSlack(Task);
    END;

    (* disallow positive slack if the task is ForceCritical: *)
    IF ForceCritical IN Task^.TaskFlags THEN
        RemovePositiveTotalSlack(Task);
    END;

END MakeTotalSlackAdjustments;




(* -----------  ComputeSlack ----------------------------------------------------

   Compute the late and total start and end dates for all scheduled tasks.

   1. In step one (ComputeTotalSlack) we run backwards through the scheduled
   tasks computing the total slack for each.

   This step assumes that before the computation for each task, all
   descendant tasks are scheduled at their late total start dates. 
   Before this step, we make a copy of the original availabilities
   of each resource, and link it to the resource's LateResidueAvailProfile.
   At the beginning of this step, these structures reflect no scheduling
   of any task.
   
   We then run backwards through the scheduled list, calculating the
   latest start date for each task using the LateResidueAvailProfile's.
   This date becomes (with certain exceptions - see below) the late
   total start date for the task. We then create a temporary set
   of varying assignments for the task at the late total start date,
   and use that structure to remove those resources from the LateResidue
   AvailProfile's. Thus, when we reach any task in the list, the Late
   ResidueAvailProfile's reflect the scheduling of all descendant tasks
   at their late total start dates.

   (At the end of this step we dispose of the late residue availability
   structures, since they are needed only for these computations.)

   2. In step two (ComputeFreeSlack) we run backwards through the scheduled
   tasks computing the free slack for each. 

   This step assumes that before the computation for each task, all
   descendant tasks are scheduled at their early start dates; so for
   this step we use the residue availability structures as they exist
   after all the early start date computations. For each task,
   we unschedule the task's resources as of its early start, calculate
   the late free start (and end), and reschedule the resources as of
   the early start (as before). (To unschedule and re-schedule the
   resources, we use the information in the task's varying assignment
   structures about when resources are in use.)

   In computing the late free start, we stipulate an upper limit equal to the
   task's late total start, to avoid a situation where the late free start
   comes out later than the late total start. (I.e.: we require
   LateFreeStart <= LateTotalStart.)
*)

PROCEDURE ComputeSlack (ScheduledList : AnExtHandle;
                        EndOfSchedule : ADate;
                        TaskCount     : CARDINAL);

BEGIN

        ComputeTotalSlack (ScheduledList,
                           EndOfSchedule,
                           TaskCount);
        IF SchedulingAbandoned THEN
            RETURN;
        END;  

        ComputeFreeSlack (ScheduledList,
                          EndOfSchedule,
                          TaskCount);

END ComputeSlack;




(* ------------ ComputeFreeSlack -----------------------------

   Go backwards through the task list, computing the free slack
   for each task (as described in ComputeFreeSlackForOneTask).

   Before the calculation for each task, we free the task's
   resources (as of the early start date) from the late
   availability structures. After the calculation, we reschedule
   the resources back into the temp availability structures
   at the early start date.
   This assures recursively that the next task can look at those 
   structures and assume in its calculations that all descendants 
   are scheduled at their early starts.

   In computing the late free start date, we use an upper limit equal to
   the task's late total start date (to avoid a situation where the
   late free start is later than the late total start).

*)

PROCEDURE ComputeFreeSlack (ScheduledList : AnExtHandle;
                            EndOfSchedule : ADate;
                            TaskCount     : CARDINAL);
CONST
    LocalCountDown = ModuleNumber+12; (* "Computing free late end dates, " *)
VAR
    ToGo                : CARDINAL;   
    Task                : ATaskPtr;
    TaskHandle          : AnExtHandle;
    TempHandle          : AnExtHandle;
    LocalLateEnd            : ADate;
BEGIN
(*<PRINT
SetString(NoteString,"ComputeFreeSlack------  EndOfSchedule is ");
CtoS(EndOfSchedule,s);
ConcatLS(NoteString,s);
PrintAString(NoteString);
PRINT>*)

    ToGo := TaskCount;
    TaskHandle := ScheduledList;
    IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

    LOOP
        TempHandle := Task^.Prevlink;
        ReleaseObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
        TaskHandle := TempHandle;

        IF ObjectsAreSame(TaskHandle,ScheduledList) THEN
             EXIT;
        END;

        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

(*<PRINT
SetString(NoteString,"COMPUTE FREE SLACK FOR ");
ConcatTaskID(NoteString, Task);
PrintAString(NoteString);
PRINT>*)

        IF (ToGo MOD HowOften2) = 0 THEN
            CountDown(LocalCountDown,TaskCount,ToGo);
        END;

        ComputeFreeSlackForOneTask(Task, EndOfSchedule);

        IF SchedulingAbandoned THEN
            ReleaseObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
            RETURN;
        END;
(*<PRINT
SetString(NoteString, "Late free start for task ");
ConcatTaskID(NoteString, Task);
CtoS(Task^.Plan.Dates.LateFreeStart, s);
ConcatS(NoteString, " = ");
ConcatLS(NoteString, s);
PrintAString(NoteString);
PRINT>*)
     DEC(ToGo);
    END;  (* loop *)
END ComputeFreeSlack;



(*------ ComputeFreeSlackForOneTask ------------------------------------------

   Assuming all descendant tasks were to be scheduled at their
   early start dates: Set the task's late free start to its
   latest start date, and set the task's late free end to the
   corresponding end date. (In computing the late free start date,
   use the task's late total start date as an upper limit.)


   Exceptions:

      1. Frozen tasks are not touched.

      2. We set Terminal, Done, and infeasible 
         tasks to have no free slack
         (i.e., we set late free start = early start and late free end =
         early end).

      3. Started tasks get the
         late end calculation as above, but their late free start date
         is left alone (namely, it equals the early start).
         (That is, we compute a late free end for the task, but
         since the task is already started, there is no such thing
         as a late free start.)

      4. If we compute a late free start date for a task, and that date
         turns out to be earlier than the task's early start, then
         we use the computed late free start and end date only if
         the user has set the AllowNegativeSlack flag; otherwise,
         we set the task to have no free slack (i.e., set set
         late free start = early start and late free end = early end).

         On the other hand, if we compute a late free start for a
         ForceCritical task that turns out to be later than the
         early start, we set the late free start to the early start
         (i.e., set no free slack - we don't allow positive slack
         on ForceCritical tasks).

      5. Summary tasks are treated as if they have no resources and zero
         duration. (2/26/92)                          

*)

PROCEDURE ComputeFreeSlackForOneTask(Task: ATaskPtr;
                                 EndOfSchedule: ADate);
VAR
   AssignmentsHandle       : AnExtHandle;
   Assignments             : AnAssignmentArray;
   ResourceCount           : CARDINAL;
   EarliestDescendantStart, LatestStartDate, MaxEndDate,
      LatestEndDate        : ADate;
   FoundLatestStartDate    : BOOLEAN;

BEGIN
            (* case 1: task is frozen - we don't bother to calculate *)
        IF FrozenTask IN Task^.TaskFlags THEN
            (*<PRINT
            SetString(NoteString, "frozen task - no slack calculation");
            PrintAString(NoteString);
            PRINT>*)
            RETURN;
        END;

            (* case 2: terminal, infeasible, or Done task: 
                no slack *)
        IF (TerminalFlag IN Task^.TempTaskFlags) OR
               (Task^.StartStatus = DoneS) OR
               (NeedsRecalculate IN Task^.TaskStatusSet) THEN
            (*<PRINT
            SetString(NoteString, "terminal,or infeasible: no slack:");
            PrintAString(NoteString);
            PRINT>*)
            SetNoFreeSlack(Task);
            RETURN;
        END;


            (* For all other cases, we need to calculate earliest 
               descendant start date: *)

        EarliestDescendantStart := EarliestDescendantStartDate
                                        (Task, EndOfSchedule);

        (*  If we are not levelling within slack, the absolute latest
            the task can end is the earliest descendant late total start.
            If we are levelling within slack, it is the minimum of that
            and the task's own late total end as computed by cpm,
            which is now held by the count2 field.
            Additionally, we never allow the late free
            end date to exceed the late total end date (as computed
            above). *)

            (* can't end later than earliest descendant start: *)
        MaxEndDate := EarliestDescendantStart;
            (* can't end later than cpm-computed late total end: *)
        IF (TimeConstrained) AND (MaxEndDate > Task^.count2) THEN
            MaxEndDate := Task^.count2;
        END;
            (* can't end later than levelling-computed late total end: *)
        IF (MaxEndDate > Task^.Plan.Dates.LateTotalEnd) THEN
            MaxEndDate := Task^.Plan.Dates.LateTotalEnd;
        END;

        (*<PRINT
        SetString(NoteString, "Earliest desc start = ");
        CtoS(EarliestDescendantStart, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        SetString(NoteString, "MaxEndDate = ");
        CtoS(MaxEndDate, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)

            (* case 3: task uses no employable resources or is summary, so
               it can end as late as its max end date: *)

        IF (TaskUsesNoEmployableResources(Task) 
                OR (SummaryFlag IN Task^.TempTaskFlags)) THEN
            (*<PRINT
            SetString(NoteString, "no employable resources: free end = max end");
            PrintAString(NoteString);
            PRINT>*)

            WITH Task^.Plan.Dates DO
                    (* first set the late free end: *)
                LateFreeEnd := MaxEndDate;
                    (* then set the late free start accordingly: *)
                IF Task^.DurationMethod = DurationDriven THEN
                   LateFreeStart := LateFreeEnd - Task^.duration;
                   (*<PRINT
                   SetString(NoteString, "dur driven task: free start = ");
                   CtoS(LateFreeStart, s);
                   ConcatLS(NoteString, s);
                   PrintAString(NoteString);
                   PRINT>*)
                ELSE
                   (*<PRINT
                   SetString(NoteString, "not dur driven: free start = free end");
                   PrintAString(NoteString);
                   PRINT>*)
                   LateFreeStart := LateFreeEnd;
                END;
            END;

            (* remove negative or positive slack if necessary: *)
            MakeFreeSlackAdjustments(Task);
            
            (* we're done with this case *)
            RETURN;
        END;


            (* case 4: task is duration driven with duration 0, so
               it can end as late as its max end date: *)

        IF (Task^.DurationMethod = DurationDriven) AND (Task^.duration = 0) THEN
            (*<PRINT
            SetString(NoteString, "dur driven with dur = 0: late start/end = max end");
            PrintAString(NoteString);
            PRINT>*)
            WITH Task^.Plan.Dates DO
                LateFreeEnd := MaxEndDate;
                LateFreeStart := LateFreeEnd;
            END;

            (* remove negative or positive slack if necessary: *)
            MakeFreeSlackAdjustments(Task);

            (* we're done with this case *)
            RETURN;
        END;


        (* case 5: task ends at earliest descendant start: no free slack *)

        IF Task^.Plan.Dates.EarlyEnd = EarliestDescendantStart THEN
            (*<PRINT
            SetString(NoteString, "task ends at descendant start: no free slack");
            PrintAString(NoteString);
            PRINT>*)
            SetNoFreeSlack(Task);
            RETURN;
        END;


        (* The easy cases are done. We now need to compute the
           free slack. To do so, we first temporarily free
           free the task's resources in the residue availabilities: *)

        AssignmentsHandle := Task^.Plan.Assignments;
        ResourceCount := LockObjectArray(AssignmentsHandle,
                                         Assignments,
                                         TSIZE(AnAssignmentRecord));

        AddToResourceAvailability(Assignments, 
                                  ResourceCount,
                                  Task^.Plan.Dates.EarlyStart);

        IF SchedulingAbandoned THEN
            ReleaseUnchangedObject(AssignmentsHandle);
            RETURN;
        END;

            (* we now compute the latest start
               date whose end date is no later than the max end date,
               and we compute the corresponding end
               date; we then set the late free start and end dates
               to them, respectively, if appropriate: *)

        FindLatestStartDate (Task, 
                             MaxEndDate,
                             FALSE, (*do we allow overbookings *)
                             FALSE, (*do we use late availabilities *) 
                             FoundLatestStartDate,
                             LatestStartDate,
                             LatestEndDate);


            (* if we couldn't find such a date, we say the
               task has no free slack: *)

        IF NOT (FoundLatestStartDate) THEN
            (*<PRINT
            SetString(NoteString, "no valid latest start date - so no slack");
            PrintAString(NoteString);
            PRINT>*)
            SetNoFreeSlack(Task);
                (* reschedule the resources before returning! *)
            RemoveFromResourceAvailability(Assignments,
                                           ResourceCount,
                                           Task^.Plan.Dates.EarlyStart);
            ReleaseObject(AssignmentsHandle);
            RETURN;
        END;


               (* We now set the late free end
               to the latest end date found, and if the task is
               future, we set the late free start to the latest
               start date. (If the task is not future we leave
               the late free start alone; it is the early start.) *)

        WITH Task^.Plan.Dates DO
            LateFreeEnd := LatestEndDate;
            IF Task^.StartStatus = FutureS THEN
                LateFreeStart := LatestStartDate;
                (*<PRINT
                SetString(NoteString, "future task: setting free start to latest start");
                PrintAString(NoteString);
                ELSE
                SetString(NoteString, "not future task: don't reset free start");
                PrintAString(NoteString);
                PRINT>*)
            END;
        END;

        (* remove negative or positive slack if necessary: *)
        MakeFreeSlackAdjustments(Task);

           (* reschedule the resources before returning! *)
        RemoveFromResourceAvailability(Assignments,
                                       ResourceCount,
                                       Task^.Plan.Dates.EarlyStart);
        ReleaseObject(AssignmentsHandle);

END ComputeFreeSlackForOneTask;





(* ----------------- ComputeTotalSlack ------------------------------

   Go backwards through the task list, computing the total slack
   for each task (as described in ComputeTotalSlackForOneTask).

   ---------------------------------------------------------------------- *)


PROCEDURE ComputeTotalSlack (ScheduledList : AnExtHandle;
                             EndOfSchedule : ADate;
                             TaskCount     : CARDINAL);

CONST
    LocalCountDown = ModuleNumber+13; (* "Computing late total end dates, " *)
VAR
    ToGo                    : CARDINAL;   
    Task                    : ATaskPtr;
    TaskHandle              : AnExtHandle;
    TempHandle              : AnExtHandle;
    LocalLateEnd            : ADate;
BEGIN
    (*<PRINT
    SetString(NoteString,"ComputeTotalSlack------  EndOfSchedule is ");
    CtoS(EndOfSchedule,s);
    ConcatLS(NoteString,s);
    PrintAString(NoteString);
    PRINT>*)

        (* First create the late residue availability profiles: *)

    IF NOT (InitializeLateResourceAvailabilities()) THEN
        SchedulingAbandoned := TRUE;
        RETURN;
    END;

        (* now run backwards through the tasks: *)

    ToGo := TaskCount;
    TaskHandle := ScheduledList;
    IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

    LOOP
        TempHandle := Task^.Prevlink;
        ReleaseObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
        TaskHandle := TempHandle;

        IF ObjectsAreSame(TaskHandle,ScheduledList) THEN
             EXIT;
        END;

        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

        (*<PRINT
        SetString(NoteString,"COMPUTE TOTAL SLACK FOR ");
        ConcatTaskID(NoteString, Task);
        PrintAString(NoteString);
        PRINT>*)
    
        IF (ToGo MOD HowOften2) = 0 THEN
            CountDown(LocalCountDown,TaskCount,ToGo);
        END;

        ComputeTotalSlackForOneTask(Task, EndOfSchedule);


        (*<PRINT
        SetString(NoteString, "Late total start for task ");
        ConcatTaskID(NoteString, Task);
        ConcatS(NoteString, " = ");
        CtoS(Task^.Plan.Dates.LateTotalStart,s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)

        DEC(ToGo);
    END; (* loop *)

        (* Get rid of the late profiles.  If at a later stage in TL's
           development we decide to keep them for analysis or reporting,
           remove this. *)

    DiscardLateResourceAvailabilities();

END ComputeTotalSlack;




(*------ ComputeTotalSlackForOneTask -------------------------------------

   Assuming all descendant tasks are scheduled at their
   late total start dates: Set the task's late total end to its
   latest end date, and set the task's late total start to the
   corresponding start date (if appropriate - see below).

      1. Frozen tasks are not touched.

      2. We set Terminal, Done, and infeasible 
         tasks to have no total slack
         (i.e., we set late total start = early start and late total end =
         early end).

      3. Started tasks get the
         late end calculation as above, but their late total start date
         is left alone (namely, it equals the early start).
         (That is, we compute a late total end for the task, but
         since the task is already started, there is no such thing
         as a late total start.)

      4. If we compute a late total start date for a task, and that date
         turns out to be earlier than the tasks' early start, then
         we use the computed late total start and end date only if
         the user has set the AllowNegativeSlack flag; otherwise,
         we set the task to have no total slack (i.e., set set
         late total start = early start and late total end = early end).

         On the other hand, if we compute a late total start for a
         ForceCritical task that turns out to be later than the
         early start, we set the late total start to the early start
         (i.e., set no free slack - we don't allow positive slack
         on ForceCritical tasks).

      5. Summary tasks are treated as if they have no resources and zero
         duration. (2/26/92)   

*)

PROCEDURE ComputeTotalSlackForOneTask(Task: ATaskPtr;
                                 EndOfSchedule: ADate);
VAR
   EarliestDescendantLateTotalStart, LatestStartDate, MaxEndDate,
      LatestEndDate        : ADate;
   FoundLatestStartDate    : BOOLEAN;

BEGIN

       (* case 1: task is frozen - we don't bother to calculate *)
    IF FrozenTask IN Task^.TaskFlags THEN
        ScheduleInLateStructures(Task, 
                                 TRUE (*DoWeForceSchedule*));
        RETURN;
    END;

        (* If we are levelling within slack:
           before we proceed further, set the task's count2 field
           to the cpm-computed late total end date, so that this
           is available when we compute the free slack later on: *)

    IF TimeConstrained THEN        
        Task^.count2 := Task^.Plan.Dates.LateTotalEnd;
    END;

        (* case 2: terminal, done, or infeasible task : no slack *)
    IF (TerminalFlag IN Task^.TempTaskFlags) OR
           (Task^.StartStatus = DoneS) OR
           (NeedsRecalculate IN Task^.TaskStatusSet) THEN
        (*<PRINT
        SetString(NoteString, "terminal,forcecritical,done, or infeasible: no slack");
        PrintAString(NoteString);
        PRINT>*)
        SetNoTotalSlack(Task);
        ScheduleInLateStructures(Task, 
                                 TRUE (*DoWeForceSchedule*));
        RETURN;
    END;

        (* For all other cases, we need to calculate earliest 
           descendant late total start date: *)

    EarliestDescendantLateTotalStart := 
            EarliestDescendantLateTotalStartDate (Task, EndOfSchedule);

        (*  If we are not levelling within slack, the absolute latest
            the task can end is the earliest descendant late total start.
            If we are levelling within slack, it is the minimum of that
            and the task's own late total end as computed by cpm,
            which is now held by the count2 field: *)

    MaxEndDate := EarliestDescendantLateTotalStart;
    IF (TimeConstrained) AND (MaxEndDate > Task^.count2) THEN
        MaxEndDate := Task^.count2;
    END;

    (*<PRINT
    SetString(NoteString, "earliest desc LTS = ");
    CtoS(EarliestDescendantLateTotalStart, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    SetString(NoteString, "max end date = ");
    CtoS(MaxEndDate, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    PRINT>*)

        (* case 3: task uses no employable resources or is summary, so
           it can end as late as its max end date: *)

    IF (TaskUsesNoEmployableResources(Task)
        OR (SummaryFlag IN Task^.TempTaskFlags)) THEN
        (*<PRINT
        SetString(NoteString, "no employable resources: late total end = max end");
        PrintAString(NoteString);
        PRINT>*)
        WITH Task^.Plan.Dates DO
                (* first set the late total end: *)
            LateTotalEnd :=MaxEndDate;
                (* then set the late total start accordingly: *)
            IF Task^.DurationMethod = DurationDriven THEN
               LateTotalStart := LateTotalEnd - Task^.duration;
               (*<PRINT
               SetString(NoteString, "dur driven - LTS = ");
               CtoS(LateTotalStart, s);
               ConcatLS(NoteString, s);
               PrintAString(NoteString);
               PRINT>*)
            ELSE
                LateTotalStart := LateTotalEnd;
                (*<PRINT
                SetString(NoteString, "not dur driven - LTS= LTE");
                PrintAString(NoteString);
                PRINT>*)
            END;
        END;

        (* remove negative or positive slack if necessary: *)
        MakeTotalSlackAdjustments(Task);

        (* we're done with this case *)
        RETURN;
    END;

        (* case 4: task is duration driven with duration 0, so
           it can end as late as its max end date: *)

    IF (Task^.DurationMethod = DurationDriven) AND (Task^.duration = 0) THEN
        (*<PRINT
        SetString(NoteString, "dur driven with dur = 0: late total start/end = max end");
        PrintAString(NoteString);
        PRINT>*)
        WITH Task^.Plan.Dates DO
            LateTotalEnd := MaxEndDate;
            LateTotalStart := MaxEndDate;
        END;

        (* remove negative or positive slack if necessary: *)
        MakeTotalSlackAdjustments(Task);

        (* we're done with this case *)
        RETURN;
    END;


        (* case 5: task ends at descendant late total start date: no total slack *)

    IF Task^.Plan.Dates.EarlyEnd = EarliestDescendantLateTotalStart THEN
        (*<PRINT
        SetString(NoteString, " task ends at desc late total start - no slack");
        PrintAString(NoteString);
        PRINT>*)
        SetNoTotalSlack(Task);
        ScheduleInLateStructures(Task,
                                 FALSE(*DoWeForceSchedule*));
        RETURN;
    END;


        (* The easy cases are done. We now need to compute the
           total slack. (We do not need to free any resources
           first, as we did in the case of computing free slack,
           since we use the late residue availability structures,
           which do not yet reflect scheduling of this task.)

           Using the late residue availability structures,
           we compute the latest start date 
           whose end date is no later than the max end date,
           and the corresponding end
           date - and set the late total start and end dates
           to them, respectively, if appropriate: *)

    FindLatestStartDate (Task, 
                         MaxEndDate, 
                         FALSE, (*do we allow overbookings *)
                         TRUE,  (*do we use late availabilities *)
                         FoundLatestStartDate,
                         LatestStartDate,
                         LatestEndDate);

        (* if we couldn't find such a date, we say the
           task has no total slack: *)

    IF NOT (FoundLatestStartDate) THEN
        (*<PRINT
        SetString(NoteString, " no latest start date found - setting no slack");
        PrintAString(NoteString);
        PRINT>*)
        SetNoTotalSlack(Task);
        ScheduleInLateStructures(Task,
                                 TRUE (*DoWeForceSchedule*));
        RETURN;
    END;


           (* We now set the late total end
           to the latest end date found, and if the task is
           future, we set the late total start to the latest
           start date. (If the task is not future we leave
           the late total start alone; it is the task start.) *)

    WITH Task^.Plan.Dates DO
        LateTotalEnd := LatestEndDate;
        (*<PRINT
        SetString(NoteString, "LTE = latest end date: ");
        CtoS(LateTotalEnd, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)
        IF Task^.StartStatus = FutureS THEN
            LateTotalStart := LatestStartDate;
            (*<PRINT
            SetString(NoteString, "future task: setting LTS = ");
            CtoS(LateTotalStart, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            PRINT>*)
        END;
    END;

    (* remove negative or positive slack if necessary: *)
    MakeTotalSlackAdjustments(Task);

    ScheduleInLateStructures(Task,
                             FALSE (*DoWeForceSchedule*));

END ComputeTotalSlackForOneTask;



(* ----------------- ScheduleInLateStructures ----------------------

   Schedule resources in the late availability
   structures to reflect scheduling of the task at its
   late total start date. To do so, we need
   to create a temporary local assignment structure,
   and make it hold the varying assignment the task would
   have if it were scheduled at its late total start.
   We then use the information in the structure to update
   the late residue availabilities. 
*)

PROCEDURE ScheduleInLateStructures (Task : ATaskPtr;
                                    DoWeForceSchedule : BOOLEAN);

VAR
    LAssignmentsHandle  : AnExtHandle; (* handle to the local copy *)
    LAssignments        : AnAssignmentArray; 
    LVaryingAssignments : AVaryingAssgnList;  
    TaskEndDate         : ADate;
    ResourceCount, i    : CARDINAL;
    AllWorkDone         : BOOLEAN;

BEGIN

    IF (Task^.Plan.Assignments) = AnExtHandle(NIL) THEN
        RETURN; (* nothing to do *)
    END;

        (* 1. create local copy of task's assignment structure: *)
    IF NOT CopyExtObject(Task^.Plan.Assignments, 
                         ExtMedium,
                         LAssignmentsHandle) THEN
        SchedulingAbandoned := TRUE;
        RETURN;
    END;

    IF NOT (SchedulingAbandoned) THEN
        ResourceCount := LockObjectArray(LAssignmentsHandle,
                                         LAssignments,  
                                         TSIZE(AnAssignmentRecord));
        IF ResourceCount = 0 THEN
            ReleaseUnchangedObject(LAssignmentsHandle);
            DiscardExtObject(LAssignmentsHandle);
            RETURN;
        END;

    END;

        (* 2. create new, blank varying assignments for the new asst array: *)

    FOR i := 0 TO (ResourceCount - 1) DO
        LAssignments^[i].VaryingAssignment := AnExtHandle(NIL);
        IF NOT (SchedulingAbandoned) THEN
            LAssignments^[i].VaryingAssignment := 
                    CreateVaryingAssgnList (Zero,(*init rate - NA *)
                                            MinDate,
                                            ExtMedium);
     
            IF (LAssignments^[i].VaryingAssignment = AVaryingAssgnList(NIL)) THEN
                SchedulingAbandoned := TRUE;
            END;
        END;
    END;

        (* 3. compute varying assignments for the task based on the
              late total start date, and put them into the local
              assignments structure: *)

    IF NOT (SchedulingAbandoned) THEN
        CreateVaryingAssignments (Task, 
                                  Task^.Plan.Dates.LateTotalStart,
                                  DoWeForceSchedule,
                                  TRUE,  (* DoWeUseLateProfiles *)
                                  LAssignmentsHandle,
                                  TaskEndDate,
                                  AllWorkDone); (* dont really care if all work done*)
        (* note:this procedure can set SchedulingAbandoned as a side effect!*)
    END;

        (* 4. the raison d'etre of this procedure: 
              use the local assignments structure to update the late
              residue availability structures *)

    IF NOT (SchedulingAbandoned) THEN
        RemoveFromLateResourceAvailability(LAssignments, 
                                           ResourceCount,
                                           Task^.Plan.Dates.LateTotalStart);
    END;


        (* 5. discard the local assignments array: *)

        (* first get rid of the temporary varying assignment structures: *)
    FOR i := 0 TO (ResourceCount - 1) DO
        IF (LAssignments^[i].VaryingAssignment <> AnExtHandle(NIL)) THEN
            DisposeVaryingAssgnList(LAssignments^[i].VaryingAssignment);
        END;
    END;


        (* now chuck the whole assignment array: *)
    ReleaseObject(LAssignmentsHandle);
    DiscardExtObject(LAssignmentsHandle);

END ScheduleInLateStructures;






(* ------------- InitializeLateResourceAvailabilities --------------

   For each resource, create a virgin version of availabilities (i.e.,
   as if no tasks are scheduled) and link it to the LateResidueAvailProfile
   field of the resource. For use in computing total slack.
*)

PROCEDURE InitializeLateResourceAvailabilities():BOOLEAN;
VAR
    Ok : BOOLEAN;
BEGIN
    Ok := TRUE;
    ResourceTree^.Methods^.TraverseTree(ResourceTree,
                                        ParentBeforeChild,
                                        MAX(CARDINAL), 
                                        InitLateProfileForOneResource, 
                                        ADR(Ok));
    IF (NOT Ok) THEN
        IssueWarning( OutOfMemory, NIL );
    END;
    RETURN Ok;
END InitializeLateResourceAvailabilities;




(* --------- InitLateProfileForOneResource --------------------------

   Creates the late residue availability profile for one resource.
*)


PROCEDURE InitLateProfileForOneResource( VAR ResourceNode : ATreeNode;
                                             Context      : ADDRESS    );
VAR
    Ok : POINTER TO BOOLEAN;
    Resource : AResourcePointer;
BEGIN
    Ok := Context;   (* Get pointer to return value. *)
    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );

    IF (Resource^.Type = Employable) AND Ok^ THEN
        Ok^ := MakeAvailabilityIntoResidue(Resource,
                                           HonorDaysOff,
                                           Resource^.LateResidueAvailProfile);
    END;

END InitLateProfileForOneResource;





(* --------------- DiscardLateResourceAvailabilities -------------------

   Dispose of the late residue availability structures for each resource.
*)

PROCEDURE DiscardLateResourceAvailabilities();
BEGIN
    ResourceTree^.Methods^.TraverseTree(ResourceTree,
                                        ParentBeforeChild,
                                        MAX(CARDINAL), 
                                        DiscardLateProfileForOneResource, 
                                        NIL);
END DiscardLateResourceAvailabilities;



(* ---------- DiscardLateProfileForOneResource -------------------

   Disposes of the late residue availability profile for one resource.
*)


PROCEDURE DiscardLateProfileForOneResource( VAR ResourceNode : ATreeNode;
                                                Context      : ADDRESS    );
VAR
    Resource : AResourcePointer;
BEGIN
    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );

    IF (Resource^.Type = Employable) THEN
        DisposeResAvailabilities(Resource^.LateResidueAvailProfile);
    END;

END DiscardLateProfileForOneResource;




(* -------- EarliestDescendantLateTotalStart ---------------------------

   Find the earliest late total start date among all the task's
   descendants.
*)


PROCEDURE EarliestDescendantLateTotalStartDate(Task          : ATaskPtr;
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
        EdgeDate := DependantTask^.Plan.Dates.LateTotalStart;


        IF (Edge^.Delta = 0) THEN
            (* No lead or lag; EdgeDate doesn't need any adjustment. *)

        ELSIF (Edge^.Delta > 0) THEN      (* Lag *)
            IF (
                    EdgeDate < AddWorkingTime
                                             (
                                               MinDate,
                                               VAL( ADuration, Edge^.Delta),
                                               TimeSheet
                                              )
               ) THEN
                EdgeDate := MinDate;    (* Would be before Day zero. *)
            ELSE
                EdgeDate := SubtractWorkingTime
                            (
                                EdgeDate,
                                VAL
                                (
                                    ADuration,
                                    Edge^.Delta
                                ),
                                TimeSheet
                             ) ;
            END;

        ELSE    (* Lead (overlap) between the tasks. *)

            IF (
                EdgeDate <= SubtractWorkingTime
                           (
                               MaxDate,
                               VAL( ADuration, -Edge^.Delta ),
                               TimeSheet
                           )
              ) THEN

                EdgeDate := AddWorkingTime
                            (
                                EdgeDate,
                                VAL( ADuration, -Edge^.Delta ),
                                TimeSheet
                            );
            ELSE
                   (* Delta is too negative to allow decrement *)
               EdgeDate := MaxDate;
            END;
        END;

        Edge^.tailtask^.Methods^.UnlockUnchangedDataObject(
                             Edge^.tailtask);
        IF (EdgeDate < EarliestStartDate) THEN
            EarliestStartDate := EdgeDate;
            (*<PRINT
            SetString(NoteString, "Setting new minimum: ");
            CtoS(EdgeDate, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            PRINT>*)
        END;
        Edge := Edge^.headlink;
    END;

    RETURN EarliestStartDate;
END EarliestDescendantLateTotalStartDate;




END ResSlack.
