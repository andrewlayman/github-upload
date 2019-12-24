IMPLEMENTATION MODULE CpmActivate;

(*V7=TRACE*)
(*V4=KILL  WITH set pointers to NIL *)


    (* CpmActivate

       Helps to locate the start and end dates of tasks in the Critical
       Path Method (precedence network) calculations by adjusting start
       dates to take into account restrictions on the start dates of
       tasks and the effects on end dates of the resources assigned.

       These procedures can respect vacation calendars, but they ignore
       resource availability.


       MODIFICATION HISTORY:

      11-Jan-91  AJL - Don't schedule effort on summary tasks.
      11-Jan-91  JES - Changed call to CreateSubstitutableResourceAssignments
                        to match new spec.
      12-Jan-91  AJL - Added ActivateSummaryTask.
      25-Jan-91  AJL - Convert duration calculations to use FwdFindDuration.
      28-Jan-91  AJL - Round numbers when converting durations and efforts
                       rather than truncating them.  Of course, this produces
                       no greater accuracy, but it makes our results match 
                       4.0.
      14-Feb-91  AJL - Rename EndOf ActualDate to EndOfSpentDate.
      22-Feb-91  JES - Removed HonorVacations parameter from calls to
                       BackFindStartDate, FwdFindEndDate, and FwdFindDuration,
                       since this is now taken care of by having the initial
                       residue availability lists reflect the value of the
                       global HonorDaysOff.
      22-Feb-91  JES - Removed parameter ScheduleThruVacations from 
                       call to AssignForInterval.
      26-Feb-91  AJL - For effort and assignment driven tasks, if the 
                       remaining effort is zero, set the AlreadyScheduled 
                       flag.
       7-Mar-91  JES - Added parameter AllWorkDone to calls to CreateSubs..
                       and added parameter DurationSatisfied to calls to
                       FwdFindEndDate.
      15-Mar-91  AJL - Changed flagging of AlreadyScheduled so that it is
                       set for assignment and duration-driven tasks only if
                       all assignments have no remaining effort, or if the
                       task is scheduled contiguously.
      12-Apr-91  AJL - We had not be setting the EndOfSpent date for some
                       tasks that were sheduled contiguously, but whose
                       start dates were >= AsOf or whose total effort <= 0.
                     - Do not set AlreadyScheduled on duration-driven tasks
                       just because they have no remaining effort.  Their
                       scheduling does not depend on remaining effort!
                       (Corrects bug introduced 26-Feb).
       1-Jun-91  AJL - Make sure that EOS <= AsOfDate.
                     - For duration driven tasks, change the spent level
                       if spending was not at the rate entered on the 
                       form.  For example, if 7 days of effort were spent
                       in six days, perhaps due to a vacation, then set
                       the rate in the varying assignment list to 7/6.
                     - For duration driven tasks, if KeepEffortContiguous
                       is FALSE (SeparateSpent/ToGo) then allow a gap
                       between the end of spending and the start of togo.
                     - If a duration-driven task is future, schedule it
                       to start at its future date for its full duration,
                       even if some effort was spent.
       3-Jun-91  AJL - When tasks have some effort spent, only release the
                       UpperBound if it is also marked Future.
       5-Jun-91  AJL - Fill in the EndOfSpentDate on assignments to 
                       costs of Contiguous Effort tasks.
      14-Jun-91  AJL - If a task is duration driven, future and has a
                       StartDateUpperBound < AsOf date, honor that bound
                       as the official start date of the task, even if we
                       do not schedule any effort until the AsOfDate (because
                       force future was on or a vacation.)
      24-Jun-91  AJL - Avoid adding dates and durations if that would produce
                       overflow.
      25-Jun-91  AJL - Don't mark tasks with no resources as already scheduled.
                       That throws off levelling's ability to process
                       dependencies.
      27-Jun-91  AJL - Remove unused import.
                     - Effort-Split Started tasks, when we are keeping
                       effort contiguous, are now scheduled around 
                       vacations.  What a mess!  I would love to get 
                       rid of this keeping of efforts contiguous.
      17-Jul-91  AJL - For summary tasks, add a new procedure to 
                       create their to go assignments based solely
                       on the task duration and the assigned levels.
                     - For duration-driven tasks, removed a shortcut
                       in AssignToGoEfforts that was skipping calculations
                       when YetToGoQuantity was zero.
      30-Jul-91  AJL - If there is no effort that needs to be scheduled on 
                       a duration-driven task, but resources are assigned,
                       allow the task to be zero-lengthed.  This corrects 
                       the false triggering of an error messages resulting
                       from the last change, above.
      11-Aug-91  AJL - If the user has entered an end date for a done task,
                       use that as the end date of the task.  Otherwise,
                       use the end of the spending date.
                     - Even for Done or Started Duration-Driven tasks, or
                       Fixed-Date tasks that have spent effort, but are
                       scheduled at future dates, contiguously, put the
                       spent effort into the past.  (Yes, this will increase
                       the total effort of the task, because the future
                       period will then get To-Go effort.)
      13-Aug-91  AJL - Correct logic in AssignContiguousEfforts so that
                       it treats as the normal case tasks that don't have
                       spent effort, not the wierd case.
      15-Aug-91  AJL - Remove restrictions on the levelling start date
                       (uses StartDateUpperBound) whenever the task is 
                       Started or Done.  Procedure FindStartDateForFutureWork
                       used to require both Started (or Done) and 
                       SpentEffort > 0.  Bug 4992.
      22-Aug-91  JES - In ActivateTask, issue warning if task is Future
                       but has some spent effort.
      16-Sep-91  AJL - Move that warning message to TLPlanEx.
      18-Sep-91  AJL - Even if there are no resources on a task, still call
                       the AssignContiguousEfforts procedures (remove an
                       optimization) because we still need to compute the
                       end of spent dates for cost types.
                     - Constrain StartOfSpent dates to <= AsOfDate.
       4-Oct-91  AJL - Make sure that, even for contiguous effort tasks, that
                       the StartOfToGoDate >= EarlyStart.
       6-Oct-91  AJL - Add more diagnostics.
                     - Correct a problem in which the EndOfSpent var was
                       not initialized for cost types in the AssignSpentEfforts
                       procedure.
      18-Dec-91  AJL - If a duration-driven task has an assignment for which
                       the user specified a particular number of effort hours,
                       and some effort was spent, adjust the spending rate of the
                       future portion in an attempt to keep the total hours
                       constant.
                         This replaces the prior policy of altering the total hours,
                       keeping the rate, and switching the assignment to say that
                       the rate was what had been entered.
      27-Jan-92  AJL - Reorganize ActivateTask for more clarity.
                     - Use the NoVacationsFlag to short-cut some calculations.
      29-Jan-92  AJL - Convert varying assingment lists to REAL rates.
      10-Feb-92  AJL - Check for tasks with end dates earlier than start.
      14-Feb-92  AJL - Correct the computation of to go levels from the change
                       made 18-Dec, which was not taking into account the 
                       schedule precision, SMUPH.
                     - Correct the computation of to go effort on summary tasks.
      24-Feb-92  AJL - Removed an incorrect "optimization" is the scheduling
                       of summary tasks which assumed that if there was not spent
                       effort on a summary that the level of future effort did
                       not need calculation.
      25-Feb-92  AJL - When computing the rates and durations of spent effort
                       in ComputeEndOfSpent, make sure that the duration times
                       the rate equals the spent effort, even though the 
                       durations have limited precision.
      18-Mar-92  AJL - Moved the computation of ToGoLevel into ResUtilities
                       procedure GetToGoLevel (so that it can be shared with
                       levelling to fix bug 5455.)
      Apr 1, 92  AJL - If an effort driven task has no assigned resources,
                       schedule it as we would if it were a duration-driven
                       task with a duration equal to the effort at 100%.
                       Bug 5472.
      Apr 20, 92 AJL - Missed a case in the above fix: effort-driven started
                       tasks with KeepEffortContiguous On.
    *)
					


FROM Allocs        IMPORT
    (* CONST *)         TskNmLen, 
    (* TYPE *)          ATask, ADateBlock, AnAssignmentSummary, 
                        ATaskPtr, ATaskName, AFixType, ATempTaskFlagSet, 
                        AStartStatus, ATaskFlag, ATaskFlagSet, ARollupStatus, 
                        ATaskStatusSet, ATaskStatus, ADurationMethod, 
                        ASplittingRule, 
    (* VAR *)           TaskTree, 
    (* PROC *)          CheckTaskValid;

FROM AsOf          IMPORT
    (* VAR  *)          AsOfDate;

FROM Assignments   IMPORT
    (* TYPE *)          AnAssignmentAttribute, 
                        AnAssignmentRecord, AnAssignmentArray, 
    (* PROC *)          ForEachAssignment, DurationOf;

FROM BigTimeU      IMPORT
    (* PROC *)          CompareBigTimes;

FROM Dialog        IMPORT
    (* PROC *)          Message, Error, FatalError, Burp, ErrorPhrase,
                        ProgressBox, ReleaseBox, ABoxHandle, WarningBox, 
                        ADialogOption, NotYetImplemented;

FROM FlexStor      IMPORT
    (* TYPE *)          AnExtHandle,
    (* PROC *)          LockObject, LockObjectArray, ReleaseObject, 
                        ReleaseUnchangedObject;

FROM Phantoms  IMPORT
    (* CONST*)          SummaryFlag, PhantomFlag;

FROM Planner       IMPORT
    (* VAR *)           HonorDaysOff, KeepEffortContiguous,
                        MoveFutureTasks, Levelling;

FROM PTaskList     IMPORT 
    (* CONST *)         AlreadyScheduled, NoVacationsFlag;

FROM ResConstants IMPORT
    (* VAR *)           SchedulingAbandoned;

FROM ResScheduleTaskResources IMPORT
    (* PROC *)          FwdFindEndDate, FwdFindDuration, AssignForInterval,
                        BackFindStartDate,
                        CreateSubstitutableResourceAssignments;

FROM ResStartDates IMPORT
    (* PROC *)          FindCpmEarliestStartDate;

FROM ResWarnings   IMPORT
    (* TYPE *)          AWarning, 
    (* PROC *)          IssueWarning;

FROM ResUtilities  IMPORT
    (* PROC *)          UnspentWorkMustBeContiguous, SubtractDuration,
                        GetToGoLevel, TaskUsesNoEmployableResources;

FROM RsrcMod       IMPORT
    (* TYPE *)          AResourcePointer, AResourceType;

FROM SYSTEM        IMPORT
     (* TYPES *)        ADR, ADDRESS, SIZE, TSIZE;

FROM Timei         IMPORT
    (* CONST *)         MinDate, MaxDate, 
    (* TYPE *)          ADate, ADuration;

FROM Timeu         IMPORT
    (* VAR *)           FSMUPH;

FROM TimeXlate      IMPORT
    (* PROC *)          BigTimeToCalendarTime;

FROM VaryAssgnment IMPORT
    (* TYPE *)          AVaryingAssgnList, 
    (* PROC *)          CreateVaryingAssgnList, DisposeVaryingAssgnList, 
                        CreateVaryingAssgnListRange,  
                        GetVaryingAssgnListEntry;


(*<TRACE
FROM FlexDisp IMPORT  HandleToString;
FROM Kbio     IMPORT  KeyPress, GetAnyCode;
FROM LStrings IMPORT  SetString, ConcatS, ConcatLS, CtoS, Compare, 
                      SubStr, Fill, TrimFront, Copy, Procustes;
FROM RealFormat IMPORT
    (* VAR *)         DefaultAmountFormat, 
    (* PROC *)        FormatAsAmount;
FROM ResTrace IMPORT  ConcatTaskID;
FROM TimeFormat  IMPORT
    (* TYPE *)        AnEndDateStyle, 
    (* VAR   *)       DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle, 
    (* PROC  *)       TimeToString, TimeAsEndDateStyle, TimeUtoS;
FROM Tracer   IMPORT  PrintString, EndTrace;
TRACE>*)





CONST
    Zero             = 0.0;
    Half             = 0.5;
    OneHundred       = 100.0;
    FLOATMAXCARDINAL = 65535.0;


TYPE
    AnActivationContext = RECORD
                               Task : ATaskPtr;
                               TotalRate : REAL;  (* Sum of the rates in all assignments. *)
                               EndOfSpentDate,           (* Last day of any spent effort. *)
                               StartOfToGoDate : ADate;  (* When can future work start. *)
                               TaskIsDurationDriven : BOOLEAN;
                               CreateAssignments    : BOOLEAN;
                               ScheduleSummaryTasks       : BOOLEAN;
                          END;

VAR
    OneHundredTimesSMUPH     : REAL;

    (*<TRACE
    TraceS : ARRAY [0..255] OF CHAR;
    TraceS2 : ARRAY [0..51] OF CHAR;
    TraceTitle : ARRAY [0..21] OF CHAR;
    TRACE>*)

    (*<TRACE
    PROCEDURE FtoS( R : REAL; VAR S : ARRAY OF CHAR);
    BEGIN
        FormatAsAmount(R, DefaultAmountFormat, S, 8, 0, 3, FALSE);
    END FtoS;
    TRACE>*)


    (*---------------------------------------------------------------------
      AddRange

      Adds a new entry to a varying assignment structure (creating the
      varying assignment if necessary).

    ---------------------------------------------------------------------- *)



PROCEDURE AddRange( VAR VaryingAssignment : AVaryingAssgnList;
                        Resource          : AResourcePointer;
                        Start, End        : ADate;
                        Rate              : REAL );
BEGIN
       (*<TRACE
    SetString(TraceS, "AddRange, ");
    ConcatS(TraceS, ", Start = ");  TimeUtoS(Start, TraceS2);   ConcatLS(TraceS, TraceS2);
    ConcatS(TraceS, ", End = ");  TimeUtoS(End, TraceS2);   ConcatLS(TraceS, TraceS2);
    ConcatS(TraceS, ", Rate = ");
    FormatAsAmount(Rate, DefaultAmountFormat, TraceS2, 12, 0, 7, FALSE);
    ConcatLS(TraceS, TraceS2);
    PrintString(TraceS);
       TRACE>*)

    IF (HonorDaysOff) THEN
        AssignForInterval (Resource, Start, End, Rate, VaryingAssignment);

    ELSE
        IF (NOT CreateVaryingAssgnListRange(VaryingAssignment, 
                                            Start, End, Rate)) THEN
            IssueWarning( OutOfMemory , NIL);
            SchedulingAbandoned := TRUE;
        END;
    END;

END AddRange;


    (*---------------------------------------------------------------------
      ComputeTotalRates

      Add up the total of the effort rates for all the employable resources.
      Finds the total, over all resources, of the rate at which work
      could be performed.

      This is here to support effort-driven, delay tasks, whose duration
      is computed by taking the total effort for the task and dividing
      by the rate at which the effort is worked.

    ---------------------------------------------------------------------- *)



PROCEDURE ComputeTotalRates( VAR Assignment : AnAssignmentRecord;
                                 Context    : ADDRESS            ) : BOOLEAN;
VAR
    ActivationContext : POINTER TO AnActivationContext;

BEGIN

    IF (Assignment.Resource^.Type <> AccountingOnly) THEN
        ActivationContext := Context;         (* Get the pointer to the context record. *)
        WITH ActivationContext^ DO
            TotalRate := TotalRate + FLOAT(Assignment.MaxRatePercent);

               (*<TRACE
            SetString(TraceS, "   ComputeTotalRates @ ");
            ConcatLS(TraceS, Assignment.Resource^.Name);
            ConcatS(TraceS,", Rate is now ");
            FormatAsAmount(TotalRate, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
            ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
               TRACE>*)
        END;
    END;


    RETURN TRUE;


END ComputeTotalRates;


    (* ComputeTotalWorkRate -- Compute the total of the rates of each of the
                               assignments to the task, and put the answer
                               into Context.TotalRate.
    *)


PROCEDURE ComputeTotalWorkRate( Task : ATaskPtr;
                                VAR Context : AnActivationContext );
BEGIN
    WITH Context DO
        TotalRate := Zero;
    END;
    ForEachAssignment (Task^.Plan.Assignments, ComputeTotalRates,
                       ADR(Context) );
END ComputeTotalWorkRate;



    (*---------------------------------------------------------------------
      AssignToGoEfforts

      Determines an end date for the assignment and (optionally) creates
      varying assignment entries for the work that is yet to go
      on this resource assignment.

      This procedure works for duration- and assignment-driven tasks,
      and effort-driven delay ones (but not effort-split).

      Varying assignment entries are created only if the context
      variable CreateAssignments is TRUE. 

      This procedure relies on the global values of several variables:

      	HonorDaysOff:  TRUE iff we are paying attention to resource
                       holiday calendars.

    ---------------------------------------------------------------------- *)


PROCEDURE AssignToGoEfforts( VAR Assignment : AnAssignmentRecord;
                                 Context    : ADDRESS            ) : BOOLEAN;
VAR
    ActivationContext : POINTER TO AnActivationContext;
    Task : ATaskPtr;
    i : CARDINAL;
    TaskEnd : ADate;
    ToGoLevel : REAL;
    StartOfToGo, EndOfToGo, EndOfSpent : ADate;
    AvailableTicks, ToGoDuration : ADuration;
    R : REAL;
    ToGoEffort : REAL;
    DurationSatisfied : BOOLEAN;

BEGIN
    IF (Assignment.Resource^.Type = AccountingOnly) THEN
        RETURN TRUE;
    END;

       (*<TRACE
    SetString(TraceS, "   AssignToGoEfforts for ");
    ConcatLS(TraceS, Assignment.Resource^.Name);
    PrintString(TraceS);
       TRACE>*)

    ActivationContext := Context;         (* Get the pointer to the context record. *)
    Task := ActivationContext^.Task;      (* Get the pointer to the task record. *)

    StartOfToGo := ActivationContext^.StartOfToGoDate;

       (*<TRACE
    SetString(TraceS, "     StartOfToGo is ");
    TimeUtoS(StartOfToGo,TraceS2); ConcatLS(TraceS,TraceS2);
    PrintString(TraceS);
       TRACE>*)


        (* Four cases:  1.  There is no yet-to-go effort.
                        2.  The task is duration-driven (and therefore
                            we know its early end date a priori).
                        3.  The task is effort-driven.
                        4.  The task is assignment-driven.
        *)

    IF (Task^.DurationMethod = EffortDriven) THEN     (* Effort Driven. *)

        ToGoEffort := Task^.ToGoSummary.Time * OneHundredTimesSMUPH; 

            (* This cannot be an effort-split task, because those would 
               be processed differently by our caller. *)

        (*<TRACE  SetString(TraceS, "       3: Effort Driven");
        PrintString(TraceS);
        IF (Task^.SplittingRule  <> Delay) THEN
            SetString(TraceS,"       ***** Error: should be effort-delay!");
            PrintString(TraceS);
            ErrorPhrase(0);
        END;
        SetString(TraceS, "     ToGoEffort = ");
        FormatAsAmount(ToGoEffort, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
        ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS, ", TotalRate = ");
        FormatAsAmount(ActivationContext^.TotalRate, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
        ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS, ", MaxRatePercent = ");
        CtoS(Assignment.MaxRatePercent,TraceS2);
        ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        TRACE>*)

        IF (ActivationContext^.TotalRate <= Zero) THEN
            IssueWarning(CrummedAssignment, Task);
        END;

            (* We know that the start date of the task is ok.  In fact, since
               this is a delay-type task, we know that all the resources
               can run uninterrupted for the duration.  

               We make each assignment end at the same date, computed by
               making the to go duration of each the same, equal to the
               task's total effort divided by the task's total effort rate.
               Sort of like one big assignment, in which all resources are
               interchangeable.  *)


        IF (ToGoEffort > Zero) THEN
            ToGoDuration := TRUNC( (ToGoEffort / ActivationContext^.TotalRate) + Half );
        ELSE
            ToGoDuration := 0;
                (* Tell the levelling step that there is no further work  
                   needed. *) 
            INCL(Task^.TempTaskFlags, AlreadyScheduled);
            (*<TRACE  SetString(TraceS, "       Mark AlreadyScheduled.");
                      PrintString(TraceS);
            TRACE>*)
        END;

            (* Compute the end of the assignment. *)

        IF (StartOfToGo <= MaxDate - ToGoDuration) THEN
            EndOfToGo := StartOfToGo + ToGoDuration;       (* Valid because this is not a Split task. *)
        ELSE
            EndOfToGo := MaxDate;
        END;

        (*<TRACE
        SetString(TraceS, "     ToGoDuration  = ");  CtoS(ToGoDuration,TraceS2);
        ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS, ", EndOfToGo = ");  TimeUtoS(EndOfToGo,TraceS2);
        ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        TRACE>*)

        WITH Assignment DO
            ToGoLevel := FLOAT(MaxRatePercent);
            IF (ActivationContext^.CreateAssignments) THEN
                AddRange(VaryingAssignment, Resource, StartOfToGo, EndOfToGo, ToGoLevel);
            END;
        END;

    (*--------  This sounds like a good idea, but, since the YTG Quantity
                will be recomputed based on the duration, later, it
                isn't really known yet, so cannot be a basis for a 
                decision.
    ELSIF (Assignment.YetToGoQuantity <= Zero) THEN
        (* No yet to go effort, so no need to create an entry in the
           varying assignment list. *)
        (*<TRACE  SetString(TraceS, "       1: YetToGo = 0");
        PrintString(TraceS);
        TRACE>*)
           (* The assignment ended when the spending ended. *)
       EndOfToGo := StartOfToGo;
    ---------------- *)

    ELSIF (Task^.DurationMethod = DurationDriven) THEN
           (* Further is work needed if levelling follows.
              Clear the flag that would indicate that no more was required.  *)
        EXCL(Task^.TempTaskFlags, AlreadyScheduled); 

            (* If the duration-driven task is marked Future, then,
               even if it has spent effort, it still requires full 
               duration.  The future portion requires the whole planned
               amount of time, and the task officially begins at that
               date.
               
               From the start date, compute the end date. *)

        WITH Task^ DO
            IF (StartStatus = FutureS) THEN
                Plan.Dates.EarlyStart := ActivationContext^.StartOfToGoDate;
                    (* If the user claims that the task must
                       start earlier, let that earlier date be the official
                       start date. *)
                IF (Plan.Dates.EarlyStart > StartDateUpperBound) THEN
                    Plan.Dates.EarlyStart := StartDateUpperBound;
                END;
            END;
        END;
        SetTentativeEndDate( Task );

            (* We know the start date and the end date of the future
               work.  Compute the rate the work must be done at. *)

        WITH Assignment DO
            EndOfToGo := Task^.Plan.Dates.EarlyEnd;

            IF (EndOfToGo <= StartOfToGo) THEN    (* No period in which to put to go effort. *)
                IF (EndOfToGo = StartOfToGo) AND (YetToGoQuantity <= Zero) THEN
                    (* If there is no effort that needs to be scheduled, allow
                       the task to be zero-lengthed. *)
                ELSE
                    (* Unfortunately, the only date at which we can find to 
                       start the tasks' to go effort, probably
                       because it is a delay-type task and vacations got in
                       the way, is after its end! *) 
                    IssueWarning( CantSchedFutureEffort, Task);
                    (*<TRACE  SetString(TraceS, "       2a: EndOfToGo <= StartOfToGo");
                    PrintString(TraceS);
                    TRACE>*)
                        (* Make up a start date.  This will violate some 
                           constraint, but is better than totally ignoring the 
                           effort. *)
                    StartOfToGo := EndOfSpentDate;
                END;
            END;
            
                (* Since we picked a start date already that guarantees
                   no splits unless the task is a split-type task, we
                   can quickly add durations unless we might have to 
                   split around vacations. *)
            IF (HonorDaysOff) AND (Task^.SplittingRule = Split) THEN
                ToGoDuration := FwdFindDuration(Resource, StartOfToGo, 
                                                EndOfToGo);
            ELSE
                ToGoDuration := EndOfToGo-StartOfToGo;
            END;

            (*<TRACE  SetString(TraceS, "       2b: ToGoDur =");
            CtoS(ToGoDuration, TraceS2); ConcatLS(TraceS, TraceS2);  ConcatS(TraceS, ", ActualQuantity = ");
            FormatAsAmount(ActualQuantity, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
            ConcatLS(TraceS, TraceS2); ConcatS(TraceS, ", YetToGoQuantity = ");
            FormatAsAmount(YetToGoQuantity, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
            ConcatLS(TraceS, TraceS2); PrintString(TraceS);
            PrintString(TraceS);
            TRACE>*)

                (* If the user had entered the total number of hours of 
                   effort on the assignment, see how close we can come to
                   accomodating them.  Else, if they had entered a work
                   rate, use that. *)

            ToGoLevel := GetToGoLevel( Task, Assignment, ToGoDuration );
    
                (* Add the to go effort of this assignment to the task's total
                   to go effort.  We need to do this, since vacations may have
                   reduced the effort (we keep the rate the same, but the 
                   number of days is reduced) or spent effort could have
                   increased the effort, if it was spent before the start
                   of the task. *)

            (* ----- This is now taken over in TLPlanEx, ComputeThisTasksCosts.
            Task^.ToGoSummary.Time := Task^.ToGoSummary.Time + ToGoEffort;
               and we aren't computing ToGoEffort above, any longer.
            ------- *)

                (* Create the varying assignment entry if 
                   levelling is not going to do it later on. *)

            IF (ActivationContext^.CreateAssignments) THEN
                AddRange(VaryingAssignment, Resource, StartOfToGo, EndOfToGo, ToGoLevel);
            END;
            
        END;

    ELSIF (Task^.DurationMethod = AssignmentDriven) THEN
        (*<TRACE  SetString(TraceS, "       4: Assignment Driven");
        PrintString(TraceS);
        TRACE>*)
           (* Further is work needed if levelling follows.
              Clear the flag that would indicate that no more was required.  *)
        EXCL(Task^.TempTaskFlags, AlreadyScheduled); 

            (* We know the effort and the rate of this particular assignment.
               Compute its duration. *)
        WITH Assignment DO
            ToGoLevel := FLOAT(MaxRatePercent);

            IF (ToGoLevel > Zero) THEN
                ToGoEffort := YetToGoQuantity;
                R := (YetToGoQuantity * OneHundredTimesSMUPH) / ToGoLevel;  (* Should consider calendars, too. *)
                IF (R <= FLOATMAXCARDINAL) THEN
                    ToGoDuration := TRUNC(R+Half);
                ELSE
                    ToGoDuration := MAX(ADuration);
                END;
            ELSE
                ToGoDuration := 0;               (* Error condition: dur would be infinite. *)
            END;
            

            IF (NoVacationsFlag IN Task^.TempTaskFlags) OR 
               (Task^.SplittingRule = Delay) THEN  (* Shortcut, no change of duration. *)
                IF (StartOfToGo <= MaxDate - ToGoDuration) THEN 
                    EndOfToGo := StartOfToGo + ToGoDuration;
                ELSE
                        (* There would have been overflow.  Truncate instead. *)
                    EndOfToGo := MaxDate;
                END;
            ELSE
                EndOfToGo := FwdFindEndDate(Resource, StartOfToGo, 
                                            ToGoDuration, DurationSatisfied);
            END;


            IF (ActivationContext^.CreateAssignments) THEN
                AddRange(VaryingAssignment, Resource, StartOfToGo, EndOfToGo, ToGoLevel);
            END;

        END;
    ELSE
          ErrorPhrase(0);             (* How could we possibly get here? *)
    END;

        (* The task ends when the last of its assignments ends. *)
    IF (EndOfToGo > Task^.Plan.Dates.EarlyEnd) THEN
        Task^.Plan.Dates.EarlyEnd := EndOfToGo;
    END;

    RETURN NOT SchedulingAbandoned;

END AssignToGoEfforts;



    (*---------------------------------------------------------------------
      SetEndDateAndFutureAssignments

      Determine the task end date, and create varying assignments
      for the future portion of the task if levelling will not take place.

    ---------------------------------------------------------------------- *)


PROCEDURE SetEndDateAndFutureAssignments (    Task: ATaskPtr;
                                          VAR ActivationContext: AnActivationContext;
                                              DoWeCreateVaryingAssignments : BOOLEAN );

VAR
    EndOfToGo : ADate;
    AllWorkDone,
    EffortWithoutResources: BOOLEAN;
BEGIN
    (*<TRACE  SetString(TraceS, "  SetEndDateAndFutureAssignments");
    PrintString(TraceS);
    TRACE>*)

        (* Set the communication parameter for AssignToGoEfforts. *)

    ActivationContext.CreateAssignments := DoWeCreateVaryingAssignments;


    (* SUMMARY TASKS (start or end milestone): *)

    IF (SummaryFlag IN Task^.TempTaskFlags) THEN
            (* Summary tasks do not have a set length, so we do not 
               schedule any future effort assigned to them here.  That
               must be done later, in TLPlan, or whoever it is that
               sets the durations of the summary tasks.  Here, we
               schedule the starte or end milestone as a point in time. *)
        WITH Task^.Plan.Dates DO
            EarlyEnd := EarlyStart;
        END;

    (* EFFORT-DRIVEN TASKS: *)

    ELSIF (Task^.DurationMethod = EffortDriven) THEN

            (* Check that there is remaining effort on the task.  If not,
               then the task ended when the spending did. *)

        IF (Task^.ToGoSummary.Time <= Zero) THEN

                (* If the user has entered an end date for a done task,
                   use that as the end date of the task.  Otherwise,
                   use the end of the spending date.  We also have a special
                   case for "effort-driven" tasks on which the user has
                   not entered any assignments.  Pretend that the duration
                   equals the effort at 100%.  *)

            WITH Task^.Plan.Dates DO
    
                IF (Task^.StartStatus = DoneS) THEN
                    EarlyEnd := BigTimeToCalendarTime(Task^.UserEnteredEndDate);
                ELSIF (TaskUsesNoEmployableResources(Task)) THEN
                    Task^.duration := TRUNC(Task^.ToGoSummary.Time * FSMUPH);
                    EarlyEnd := EarlyStart + Task^.duration;
                ELSE
                    EarlyEnd := ActivationContext.EndOfSpentDate;
                END;
    
                IF (EarlyEnd < EarlyStart) THEN
                    IssueWarning(DoneBeforeStart, Task );
                    EarlyEnd := EarlyStart;
                END;
            END;

            (* Tell the levelling step that there is no further work 
               needed. *)
            INCL(Task^.TempTaskFlags, AlreadyScheduled);
            (*<TRACE  SetString(TraceS, "       Mark AlreadyScheduled.");
                        PrintString(TraceS);
            TRACE>*)

                (* EFFORT-DRIVEN, but no resources.

                   We also have a special
                   case for "effort-driven" tasks on which the user has
                   not entered any assignments.  Pretend that the duration
                   equals the effort at 100%.  *)

        ELSIF (TaskUsesNoEmployableResources(Task)) THEN

            Task^.duration := TRUNC(Task^.ToGoSummary.Time * FSMUPH);
            WITH Task^.Plan.Dates DO
                EarlyEnd := EarlyStart + Task^.duration;
            END;

            (* EFFORT-DRIVEN DELAY TASKS: *)

        ELSIF (Task^.SplittingRule = Delay) THEN
            (*<TRACE
            SetString(TraceS, "    This task is effort-driven, delay.");
            ConcatTaskID(TraceS, Task);
            PrintString(TraceS);
            TRACE>*)

            (* Plan the to go assignments.   We will always conpute an end date, 
               but, if Levelling is to follow CPM analysis, we will not actually
               build the future-effort varying assignments.   This schedules all
               task types except those which have been handled above, already:
               effort-split and started/Done duration-driven tasks.  *)

                (* For effort driven tasks, we need to compute the remaining
                   duration of the task by taking into account the total rate at
                   which the resources will work. *)
            ComputeTotalWorkRate(Task,ActivationContext);
            ForEachAssignment (Task^.Plan.Assignments, AssignToGoEfforts, 
                               ADR(ActivationContext) );

            (* EFFORT-DRIVEN SPLIT TASKS: *)

        ELSE   (* Task^.SplittingRule = Split *)
            (*<TRACE
            SetString(TraceS, "    This task is effort-driven, split.  ");
            ConcatTaskID(TraceS, Task);
            PrintString(TraceS);
            TRACE>*)
                (* Call CreateSubstitutableResourceAssignments in order 
                   to determine the end date of the task.  If we are
                   not levelling, then also create the appropriate varying
                   assignments. *)
            WITH ActivationContext DO 
                
                IF (StartOfToGoDate < EndOfSpentDate) THEN
                    StartOfToGoDate := EndOfSpentDate;
                END;
                CreateSubstitutableResourceAssignments( Task, 
                                            StartOfToGoDate,  
                                            TRUE (* DoWeForceSchedule *), 
                                            FALSE (* DoWeUseLateProfiles *),
                                            FALSE (* DoWeContour *),  
                                            DoWeCreateVaryingAssignments,
                                            Task^.Plan.Assignments, 
                                            Task^.Plan.Dates.EarlyEnd,
                                            AllWorkDone);
      
            END;
        END;


        (* DURATION OR ASSIGNMENT DRIVEN TASKS: *)

    ELSE  (* Duration-driven or Assignment-Driven. *)

        (* Plan the to go assignments.   We will always conpute an end date, 
           but, if Levelling is to follow CPM analysis, we will not actually
           build the future-effort varying assignments.   This schedules all
           task types except those which have been handled above, already:
           effort-driven and started/done duration-driven tasks (note that
           started/done duration driven tasks, being "continguous effort"
           tasks, were handled in another procedure.) *)
    
           (* If this is an assignment-driven task, whose assignments' durations
              depend on the amount of remaining effort, presume that there is no
              further work needed.  If more work is
              needed by levelling, AssignToGoEfforts will clear this flag.
              *)

        IF (Task^.DurationMethod = AssignmentDriven) THEN
            INCL(Task^.TempTaskFlags, AlreadyScheduled); 
        END;

        ForEachAssignment (Task^.Plan.Assignments, AssignToGoEfforts, 
                           ADR(ActivationContext) );

                (* If the user has entered an end date for a done task,
                   use that as the end date of the task.  Otherwise,
                   use the end of the spending date. *)

        IF (Task^.StartStatus = DoneS) THEN
            Task^.Plan.Dates.EarlyEnd := BigTimeToCalendarTime(Task^.UserEnteredEndDate);
            WITH Task^.Plan.Dates DO
                IF (EarlyEnd < EarlyStart) THEN
                    IssueWarning(DoneBeforeStart, Task );
                    EarlyEnd := EarlyStart;
                END;
            END;
        END;

    END;
END SetEndDateAndFutureAssignments;


    (*---------------------------------------------------------------------
      FindStartDateForFutureWork

      Determine earliest valid start date for the future portion of the task.
      This is >= the end of the spent work.  Additionally, if the 
      MoveFutureTasks switch is on the future work is after the AsOfDate. 
      Also, vacations must be taken into account if appropriate.

    ---------------------------------------------------------------------- *)


PROCEDURE FindStartDateForFutureWork(    Task : ATaskPtr;
                                     VAR ActivationContext: AnActivationContext);
VAR
    Found : BOOLEAN;
BEGIN

    WITH ActivationContext DO
        StartOfToGoDate := EndOfSpentDate; (* tentatively *)

        (*<TRACE
        SetString(TraceS, "On entry to FindStartDateForFutureWork, ");  ConcatTaskID(TraceS, Task);
        ConcatS(TraceS, ", EndOfSpentDate = ");
        TimeUtoS(EndOfSpentDate, TraceS2);  ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        TRACE>*)

        IF (StartOfToGoDate < Task^.Plan.Dates.EarlyStart) THEN
            StartOfToGoDate := Task^.Plan.Dates.EarlyStart;
        END;

            (* Load future work to right of As-of Date: *)
        IF (MoveFutureTasks) 
           AND (Task^.ToGoSummary.Time > Zero)
           AND (StartOfToGoDate < AsOfDate) THEN
                StartOfToGoDate := AsOfDate;
        END;

            (* If the task is started, that removes the restrictions on
               the start of to go effort.   This is because Time Line 
               v.5 doesn't have any separate way of storing a history of
               when spent effort was spent that is different from recording a
               required start date for the task.
               
               Or, put another way, TL doesn't have a way of recording a
               start date for the task, and also a bound on the start
               of future effort.
               
               So, when the task is started, 
               we use the date that the user entered as the date the 
               effort began, and then don't have any additional fields to
               restrict the beginning of the unspent effort.
               
               However, we have an odd case to handle: a task that is in 
               the future but some effort was spent.  In that case, we 
               stick the spent effort somewhere in the past, but schedule
               the remaining part of the task in the future.  In the case
               of a Fixed-Date task, this would be the whole original
               duration.  *)

        IF (Task^.StartStatus <> FutureS) THEN   
                (* Cases 3 and 4 of ActivateTask. Since the user
                   chose to allow separation of Spent and ToGo effort,
                   we scheduled the start of the spent effort based on the 
                   StartDateUpperBound.  Now we need to reset that bound
                   so that we, and later resource levelling, can schedule
                   the to go effort. *)

            (*<TRACE SetString(TraceS, "    Cases 3 & 4, release UpperBound"); 
                       PrintString(TraceS);
            TRACE>*)

            Task^.StartDateUpperBound := MaxDate;
                (* Find the earliest feasible start date for the togo effort.
                   If we are not honoring vacations, this is not necessary
                   since the initialized value (end of spending or as of date)
                   will do fine. *)
            IF (HonorDaysOff) AND 
               (NOT (NoVacationsFlag IN Task^.TempTaskFlags)) THEN
                FindCpmEarliestStartDate (Task, StartOfToGoDate, 
                                          MaxDate, (* Task^.StartDateUpperBound *) 
                                          Found, 
                                          StartOfToGoDate);
                IF (NOT Found) THEN
                    IssueWarning( ConflictWithBounds, Task );
                    StartOfToGoDate := MaxDate;  (* Task^.StartDateUpperBound; *)
                END;
            END;
        END;  
    END;


    (*<TRACE
    SetString(TraceS, "On exit from FindStartDateForFutureWork, ");  ConcatTaskID(TraceS, Task);
    ConcatS(TraceS, ", StartOfToGoDate = ");
    TimeUtoS(ActivationContext.StartOfToGoDate, TraceS2);  ConcatLS(TraceS, TraceS2);
    PrintString(TraceS);
    TRACE>*)


END FindStartDateForFutureWork;


    (*---------------------------------------------------------------------
      ComputeEndOfSpent

      For this particular assignment, decide on a date such that all the
      spending, if any, occurred before that date and all the unspent
      effort (if any) will occur after that date.

      The date will never be earlier than the earlier or AsOfDate and
      StartOfSpent or later than the TaskEnd, if the end date is known.

      KnownEndDate as a parameter means that the TaskEnd parameter contains 
      an upper bound for the end of spent date.  If KnownEndDate is FALSE,
      TaskEnd is not used.

      In addition to computing the date at which the spending is presumed to
      have ended, SpentLevel returns a rate at which the spending was
      presumed to have happened, such that the rate times the duration between
      StartOfSpent and the returned value is the spent effort.

      Preconditions:

      If KnownEndDate is TRUE, TaskEnd must be >= StartOfSpent.

    ---------------------------------------------------------------------- *)




PROCEDURE ComputeEndOfSpent(     Assignment   : AnAssignmentRecord;
                                 Task         : ATaskPtr;
                                 StartOfSpent : ADate;
                                 TaskEnd      : ADate;
                                 KnownEndDate : BOOLEAN;
                             VAR SpentLevel   : REAL
                           ) : ADate;
VAR
    AvailableTicks    : CARDINAL;
    EndOfSpent        : ADate;
    SpentDuration     : ADuration;
    R                 : REAL;
    DurationSatisfied : BOOLEAN;
BEGIN
    (*<TRACE
    SetString(TraceS, "    ComputeEndOfSpent for ");
    ConcatLS(TraceS,Assignment.Resource^.Name);
    ConcatS(TraceS,", AsOfDate = ");
    TimeUtoS(AsOfDate, TraceS2);  ConcatLS(TraceS, TraceS2);
    ConcatS(TraceS,", StartOfSpent = ");
    TimeUtoS(StartOfSpent, TraceS2);  ConcatLS(TraceS, TraceS2);
    PrintString(TraceS);
    TRACE>*)

    IF (AsOfDate < StartOfSpent) THEN
        StartOfSpent := AsOfDate;
    END;


    IF (Task^.StartStatus = DoneS) THEN
        EndOfSpent := BigTimeToCalendarTime(Task^.UserEnteredEndDate);
        IF (AsOfDate < EndOfSpent) THEN
            EndOfSpent := AsOfDate;
        END;
    ELSIF (KnownEndDate) AND (TaskEnd < AsOfDate) THEN
        EndOfSpent := TaskEnd;
    ELSE
        EndOfSpent :=  AsOfDate;
    END;

    IF (EndOfSpent < StartOfSpent) THEN
        EndOfSpent := StartOfSpent;
    END;


	(* If the resource is not a real flesh-and-blood resource, but
           is instead a cost category, then we don't need much sophistication
           to decide when the spending ended. *)

    IF (Assignment.Resource^.Type = AccountingOnly) THEN
        (*<TRACE
        SetString(TraceS, "    On exit from EndOfSpent, Cost Type ");
        ConcatLS(TraceS,Assignment.Resource^.Name);
        ConcatS(TraceS,", EOS= ");
        TimeUtoS(EndOfSpent, TraceS2);  ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        TRACE>*)
        RETURN EndOfSpent;
    END;

        (* EndOfSpent is now the last day on which the spending could
           have happened, and is >= StartOfSpent.
	*)


    WITH Assignment DO
            (* Before going through all the work of assigning spent effort,
               make sure that there is some. *)

        IF (ActualQuantity > Zero) THEN

	        (* See whether the spent effort (ActualQuantity), at the assigned
                level, could have been spent in the period between StartOfSpent
                and EndOfSpent.  If the spent effort is <= MaxRatePercent * SpentDuration, 
                then it fits, and we see if the SpentDuration can be reduced.
                Otherwise, we increase the SpentLevel. *)

            IF (HonorDaysOff) THEN
                AvailableTicks := FwdFindDuration(Assignment.Resource, StartOfSpent, 
                                                                   EndOfSpent);
            ELSE
                AvailableTicks := EndOfSpent - StartOfSpent;  (* Should consider calendars, too. *)
            END;

            IF (AvailableTicks > 0) THEN
                SpentLevel := (ActualQuantity * OneHundredTimesSMUPH) / FLOAT(AvailableTicks);
                IF (SpentLevel > FLOATMAXCARDINAL) THEN
                    SpentLevel := FLOATMAXCARDINAL;    (* Limit in case the implied level is wildly too high. *)
                END;
            ELSE
                SpentLevel := FLOATMAXCARDINAL;     (* Limit in case the time is zero. *)
            END;

                (* Was less effort spent than expected?   Compute a
                   duration that is the smallest duration <= elapsed 
                   duration and the largest rate that fits in that
                   interval, but trying not to exceed MaxRatePercent. *)

            R := FLOAT(MaxRatePercent);
            IF (SpentLevel < R) THEN   (* finished before AsOfDate. *)
                SpentLevel := R;
                R := (ActualQuantity * OneHundredTimesSMUPH) / SpentLevel;
                IF (R <= FLOATMAXCARDINAL) THEN
                       (* Round up trying to get a duration that will allow
                          a rate <= MaxRatePercent, but do not exceed the
                          elapsed duration. *)
                    SpentDuration := TRUNC(R+0.9999999);
                    IF (SpentDuration > AvailableTicks) THEN
                        SpentDuration := AvailableTicks;
                    END;
                ELSE
                    SpentDuration := MAX(ADuration);
                END;
                    (* Compute the level which matches the duration.  We need to
                       do this since the duration has been rounded due to its limited
                       precision, and the duration times the MaxRatePercent may not
                       multiply to exactly the spent effort. *)
                SpentLevel := (ActualQuantity * OneHundredTimesSMUPH) / FLOAT(SpentDuration);
                    (* If respecting calendars, then call the procedure which takes them into
                    account.  Otherwise, just add dates. *)
                IF (HonorDaysOff) THEN
                    EndOfSpent := FwdFindEndDate(Resource, StartOfSpent, 
                                                 SpentDuration, DurationSatisfied);
                ELSE
                    IF (StartOfSpent <= MaxDate - SpentDuration) THEN 
                        EndOfSpent := StartOfSpent + SpentDuration;
                    ELSE
                            (* There would have been overflow.  Truncate instead. *)
                        EndOfSpent := MaxDate;
                    END;
                END;
            END;
        ELSE (* ActualQuantity <= Zero *)
            (* No spending happened. *)
            EndOfSpent := StartOfSpent;
            SpentLevel := Zero;
        END;
    END;

    (*<TRACE
    SetString(TraceS, "    On exit from EndOfSpent, EOS= ");
    TimeUtoS(EndOfSpent, TraceS2);  ConcatLS(TraceS, TraceS2);
    ConcatS(TraceS,", SpentLevel = ");
    FtoS(SpentLevel, TraceS2);  ConcatLS(TraceS, TraceS2);
    PrintString(TraceS);
    TRACE>*)

    RETURN EndOfSpent;

END ComputeEndOfSpent;







    (*---------------------------------------------------------------------
      AssignSpentEfforts

      Remove any previous varying assignments from the assignment record.
      Add new varying assignments for the spent portion of the effort.
      Record these into the varying assignment structure attached to the
      assignment.

      If there is no spent effort, the varying assignment handle will become
      NIL.

      The spent effort will be allocated into the period between the start
      date of the task and the earlier of the end of the task and the AsOfDate.
      If the StartDate is not before the AsOfDate, no effort will be allocated
      (and the varying assignment will become NIL).

      The assignment will have filled into it the EndOfActual date, which is
      >= the task start date and is the least date after which no spending
      happened.

      Sometimes the spent effort on an assignment is more or less than would
      be expected given the assigned level and the duration of the spending.
      If more, we increase the assignment's level; if less, we decrease the
      duration.

    ------------------------------------------------------------------------- *)


PROCEDURE AssignSpentEfforts( VAR Assignment : AnAssignmentRecord;
                                  Context    : ADDRESS            ) : BOOLEAN;
VAR
    ActivationContext : POINTER TO AnActivationContext;
    Task : ATaskPtr;
    R : REAL;
    TotalEffortThisAssignment : REAL;
    i : CARDINAL;
    TaskStart, TaskEnd : ADate;
    SpentLevel : REAL;
    StartOfSpent, EndOfSpent : ADate;
    AvailableTicks, SpentDuration : ADuration;
    DurationSatisfied, ok : BOOLEAN;

BEGIN
       (*<TRACE
    SetString(TraceS, "   AssignSpentEfforts for ");
    ConcatLS(TraceS, Assignment.Resource^.Name);
    PrintString(TraceS);
       TRACE>*)

    ActivationContext := Context;         (* Get the pointer to the context record. *)
    Task := ActivationContext^.Task;      (* Get the pointer to the task record. *)


    TaskStart := Task^.Plan.Dates.EarlyStart;



    WITH Assignment DO
            (* Create a list.  It begins at the start date of the task with
               the requested amount, and runs until the end date. *)

            (* Remove any previous varying assignment list data. 
               Rather than removing the list, keep it allocated to save
               time, but remove the effort. *)

        IF (VaryingAssignment <> AVaryingAssgnList(NIL)) THEN
            ok := CreateVaryingAssgnListRange(VaryingAssignment,
                                        MinDate,MaxDate,Zero);
        END;

            (* Provided that the task actually started before the as-of date, 
               allocate the spent effort into the period between the start of the
               task and the as-of date.  There are two situations to consider:
               (1) the resource, working at the user-entered level (MaxRatePercent)
               would have worked the required number of hours on or before reaching the
               AsOfDate, and (2) at the entered level the resource would have
               had to work past the As-Of Date, so in order to have done the work
               before the as-of date, the resource must have worked at a higher level.
            *)

        TotalEffortThisAssignment := ActualQuantity + YetToGoQuantity;


        IF (ActualQuantity <= Zero) THEN     (* No spent effort. *)
            EndOfSpent      := TaskStart;    (* Spending never happened. *)
            EndOfSpentDate  := TaskStart;    (* Spending never happened. *)

        ELSIF (Resource^.Type = AccountingOnly) THEN 
	       (* This is not a resource, but is only a cost category. *)
            EndOfSpentDate  := ComputeEndOfSpent( Assignment, 
                                                  Task,
                                                  TaskStart,  
                                                  Task^.Plan.Dates.EarlyEnd, 
                                                    (* only used if TaskIsDurationDriven *)
                                                  ActivationContext^.TaskIsDurationDriven, 
                                                  SpentLevel);
            EndOfSpent := EndOfSpentDate;
               (*<TRACE
            SetString(TraceS, "    Cost ");  ConcatLS(TraceS,Resource^.Name);
            ConcatS(TraceS,", EndOfSpentDate = ");
            TimeUtoS(EndOfSpentDate, TraceS2);   ConcatLS(TraceS, TraceS2);
            PrintString(TraceS);
               TRACE>*)

        ELSE  (* Some spending happened.  When? *)
        
            IF (TaskStart < AsOfDate) THEN       (* Normal situation. *)
                (* Some spending happened.  We need to calculate the level at
                which the spent effort was spent, and the date the spending ended.
                If there is a known end date to the task and it is before the
                as of date, it must have ended by then.  Otherwise by the as of
                date.  (In either case, it could have ended even sooner.)  *)

                StartOfSpent := TaskStart;   (* Start of spent effort. *)

                EndOfSpent := ComputeEndOfSpent( Assignment, 
                                                 Task,
                                                 StartOfSpent, 
                                                 Task^.Plan.Dates.EarlyEnd,
                                                   (* only used if TaskIsDurationDriven *)
                                                 ActivationContext^.TaskIsDurationDriven,
                                                 SpentLevel);
            ELSE
                (* Wierd situation.  The user claims that some spending happened, but
                   the task doesn't start until in the future!  Stick the spending into
                   a time before the AsOfDate. *)
                EndOfSpent := AsOfDate;          (* Start of spent effort. *)
                SpentLevel := FLOAT(Assignment.MaxRatePercent);
                SpentDuration := TRUNC(((ActualQuantity * OneHundredTimesSMUPH) /
                                         SpentLevel)+Half);
                BackFindStartDate(Resource,EndOfSpent,SpentDuration,
                                  StartOfSpent,         (* Returned parameter *)
                                  DurationSatisfied );  (* Returned parameter *)
                (* There is a slim possibility that the effort cannot be satisfied 
                   in the period [MinDate,EndOfSpent), in which case DurationSatisfied 
                   will be FALSE (and we will not schedule all the effort!) *)
                (*<TRACE
                         SetString(TraceS, "   Start > AsOf Date");
                         PrintString(TraceS);
                         SetString(TraceS, "   BackFindStartDate, EOS= ");
                         TimeUtoS(EndOfSpent,TraceS2); ConcatLS(TraceS,TraceS2);
                         ConcatS(TraceS,", SpentDur = ");
                         CtoS(SpentDuration,TraceS2); ConcatLS(TraceS,TraceS2);
                         PrintString(TraceS);
                         SetString(TraceS, "                      SOS= ");
                         TimeUtoS(StartOfSpent,TraceS2); ConcatLS(TraceS,TraceS2);
                         ConcatS(TraceS,", DurSatisfied = ");
                         IF (DurationSatisfied) THEN ConcatS(TraceS,"TRUE");
                         ELSE ConcatS(TraceS,"FALSE");
                         END;
                         PrintString(TraceS);
                TRACE>*)
            END;

                (* Record the spent effort *)

            AddRange(VaryingAssignment, Resource, StartOfSpent, EndOfSpent, SpentLevel);

            EndOfSpentDate := EndOfSpent;      (* When the spent part ended. *)
        END;

            (* If the task is duration-driven, but the user entered an effort,
               not a rate, for the assignment, do the best we can to keep the
               total effort constant.     (AJL Dec 18, 91)
            *)

        IF (ActivationContext^.TaskIsDurationDriven) AND
           (ComputeByHours IN Attributes) AND
           (Resource^.Type <> AccountingOnly) THEN 
            YetToGoQuantity := TotalEffortThisAssignment - ActualQuantity;
            IF (YetToGoQuantity < Zero) THEN
                YetToGoQuantity := Zero;
            END;
            (*<TRACE
                     SetString(TraceS, "   Update the YetToGoQuantity :=");
                     FormatAsAmount(YetToGoQuantity, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
                     ConcatLS(TraceS,TraceS2);
                     PrintString(TraceS);
            TRACE>*)
        END;
    END;

    IF (ActivationContext^.EndOfSpentDate < EndOfSpent) THEN
        ActivationContext^.EndOfSpentDate := EndOfSpent;
    END;

    (*<TRACE
             SetString(TraceS, "   Exit AssignSpentEfforts, EndOfSpentDate =");
             TimeUtoS(ActivationContext^.EndOfSpentDate,TraceS2); ConcatLS(TraceS,TraceS2);
             PrintString(TraceS);
    TRACE>*)

    RETURN NOT SchedulingAbandoned;

END AssignSpentEfforts;




    (*---------------------------------------------------------------------
      FindAStartDate

      Locate a date on which to start the task that
      meets its requirements for task type, splitting
      rule, etc.  

    ---------------------------------------------------------------------- *)


PROCEDURE FindAStartDate (Task : ATaskPtr);

VAR
    Found : BOOLEAN;
BEGIN

    WITH Task^ DO WITH Plan.Dates DO
        (*<TRACE
        SetString(TraceS, "On entry to FindAStartDate, ");  ConcatTaskID(TraceS, Task);
        ConcatS(TraceS, "   ES = ");
        TimeUtoS(EarlyStart, TraceS2);  ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        TRACE>*)
        IF (EarlyStart > StartDateUpperBound) 
                   OR (StartDateUpperBound <= StartDateLowerBound) THEN
            (* start date is forced - cases 1 and 3 of ActivateTask *)

            EarlyStart := StartDateUpperBound;
                (* This task is starting out of sequence, that is, it has
                   a start date earlier than was implied
                   by the precedence constraints, and is Started or Done, 
                   or otherwise has had its start date set.  *)
            (*<TRACE
            SetString(TraceS, "Out-of-sequence or required start for ");  ConcatTaskID(TraceS, Task);
            PrintString(TraceS);  SetString(TraceS, "   ES = ");
            TimeUtoS(EarlyStart, TraceS2);  ConcatLS(TraceS, TraceS2); ConcatS(TraceS, " UpperBound = ");
            TimeUtoS(StartDateUpperBound, TraceS2);  ConcatLS(TraceS, TraceS2);
            ConcatS(TraceS,", Dur = ");
            CtoS(duration, TraceS2); ConcatLS(TraceS, TraceS2);
            PrintString(TraceS);
            TRACE>*)

        ELSIF (Task^.CompletedSummary.Time = Zero) THEN        
            (* case 2 of ActivateTask: no spent effort *)
          (* remove this comment later: here is where we inlined
             the former "FindAStartDate": *)

            IF (EarlyStart < StartDateLowerBound) THEN
                    (* This task is scheduled to start later than its
                       early start date.  *)
                (*<TRACE
                SetString(TraceS, "Would have started < LowerBound: ");  ConcatTaskID(TraceS, Task);
                PrintString(TraceS);
                SetString(TraceS, "   ES = ");
                TimeUtoS(EarlyStart, TraceS2);  ConcatLS(TraceS, TraceS2); ConcatS(TraceS, " LowerBound = ");
                TimeUtoS(StartDateLowerBound, TraceS2);  ConcatLS(TraceS, TraceS2); ConcatS(TraceS, ".");
                PrintString(TraceS);
                TRACE>*)

                EarlyStart := StartDateLowerBound; (* make sure satisfies LB *)
            END;

                (* If we need to delay this task until after vacations, do
                   so here. *)

            IF (HonorDaysOff) THEN
                    (* This finds when the ToGo portion of the task
                       can start.   If the task has been marked Started
                       or Done, then the user will have entered a 
                       must-start date, setting the upper and lower bounds,
                       and we won't take this branch of the program.  See
                       the assumuptions in the comments to this proc.  *)
                FindCpmEarliestStartDate (Task, EarlyStart, 
                                      StartDateUpperBound, 
                                      Found, EarlyStart);
                IF (NOT Found) THEN
                    IssueWarning( ConflictWithBounds, Task );
                    EarlyStart := StartDateUpperBound;
                END;
            END;
        END;
    END END;
END FindAStartDate;



    (*---------------------------------------------------------------------
      AssignContiguousEfforts

      Create a single varying assignment record
      for the assignment.  It does not attempt to
      put a different amount of effort into spent and
      to go rates, or split the assignment, so far as
      assigning the quantities goes (though it does
      still compute an EndOfActual date).

    ---------------------------------------------------------------------- *)


PROCEDURE AssignContiguousEfforts( VAR Assignment : AnAssignmentRecord;
                                       Context    : ADDRESS            ) : BOOLEAN;
VAR
    ActivationContext : POINTER TO AnActivationContext;
    Task : ATaskPtr;
    TaskStart, TaskEnd : ADate;
    StartOfToGoDate,
    StartOfSpent    : ADate;
    EndOfAssignment : ADate;
    SpentDuration, ToGoDuration, TotalDuration : ADuration;
    R : REAL;
    TotalEffort : REAL;      (* Number of work-hours (people * hours) *)
    SpentLevel, ToGoLevel : REAL;
    DurationSatisfied, ok : BOOLEAN;
BEGIN
       (*<TRACE
    SetString(TraceS, "   AssignContiguousEfforts for ");
    ConcatLS(TraceS, Assignment.Resource^.Name);
    PrintString(TraceS);
       TRACE>*)

    ActivationContext := Context;         (* Get the pointer to the context record. *)
    Task := ActivationContext^.Task;      (* Get the pointer to the task record. *)

    TaskStart := Task^.Plan.Dates.EarlyStart;
    TaskEnd   := Task^.Plan.Dates.EarlyEnd;



    WITH Assignment DO
            (* Remove any previous varying assignment list data. 
               Rather than removing the list, keep it allocated to save
               time, but remove the effort. *)
        IF (VaryingAssignment <> AVaryingAssgnList(NIL)) THEN
            ok := CreateVaryingAssgnListRange(VaryingAssignment,
                                        MinDate,MaxDate,Zero);
        END;

            (* The "effort" of non-employable resources doesn't need to 
               be scheduled. *) 

        IF (Assignment.Resource^.Type = AccountingOnly) THEN 
	       (* This is not a resource, but is only a cost category. *)
            EndOfSpentDate := ComputeEndOfSpent( Assignment, 
                                                 Task,
                                                 TaskStart,
                                                 Task^.Plan.Dates.EarlyEnd,
                                                   (* only used if TaskIsDurationDriven *)
                                                 ActivationContext^.TaskIsDurationDriven,
                                                 SpentLevel);
            RETURN TRUE;
        END;

            (* What is the amount of effort needed on this assignment?
               At what rate will it be spent?  *)

        IF (Task^.StartStatus <> DoneS) THEN
            ToGoLevel       := FLOAT(MaxRatePercent);
        ELSE
            ToGoLevel       := Zero;
        END;

           (*<TRACE
        SetString(TraceS, "       ToGoLevel = ");  FtoS(ToGoLevel,TraceS2);
        ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
           TRACE>*)

            (* If there is spent effort, decide when the spending ended. *)

        IF (TaskStart < AsOfDate) OR             (* Some portion before AsOfDate. *)
           (ActualQuantity <= Zero) THEN          (* Spent effort. *)
            StartOfSpent    := TaskStart;
            EndOfSpentDate  := ComputeEndOfSpent( Assignment, 
                                                  Task,
                                                  TaskStart, 
                                                  TaskEnd, 
                                                  ActivationContext^.TaskIsDurationDriven, 
                                                  SpentLevel);
            StartOfToGoDate := EndOfSpentDate;
            IF (StartOfToGoDate < TaskStart) THEN
                StartOfToGoDate := TaskStart;
            END;
        ELSE
            (* Wierd situation.  The user claims that some spending happened, but
               the task doesn't start until in the future!  Stick the spending into
               a time before the AsOfDate. *)
            EndOfSpentDate := AsOfDate;          (* Start of spent effort. *)
            SpentLevel     := FLOAT(Assignment.MaxRatePercent);
            SpentDuration  := TRUNC(((ActualQuantity * OneHundredTimesSMUPH) /
                                      SpentLevel)+Half);
            BackFindStartDate(Resource,EndOfSpentDate,SpentDuration,
                              StartOfSpent,         (* Returned parameter *)
                              DurationSatisfied );  (* Returned parameter *)
            StartOfToGoDate := TaskStart;
            (* There is a slim possibility that the effort cannot be satisfied 
               in the period [MinDate,EndOfSpent), in which case DurationSatisfied 
               will be FALSE (and we will not schedule all the effort!) *)
            (*<TRACE
                     SetString(TraceS, "   Start > AsOf Date");
                     PrintString(TraceS);
                     SetString(TraceS, "   BackFindStartDate, EOS= ");
                     TimeUtoS(EndOfSpentDate,TraceS2); ConcatLS(TraceS,TraceS2);
                     ConcatS(TraceS,", SpentDur = ");
                     CtoS(SpentDuration,TraceS2); ConcatLS(TraceS,TraceS2);
                     PrintString(TraceS);
                     SetString(TraceS, "                      SOS= ");
                     TimeUtoS(StartOfSpent,TraceS2); ConcatLS(TraceS,TraceS2);
                     ConcatS(TraceS,", DurSatisfied = ");
                     IF (DurationSatisfied) THEN ConcatS(TraceS,"TRUE");
                     ELSE ConcatS(TraceS,"FALSE");
                     END;
                     PrintString(TraceS);
            TRACE>*)
        END;

        (*<TRACE
             SetString(TraceS, "    SOS= ");
             TimeUtoS(StartOfSpent,TraceS2); ConcatLS(TraceS,TraceS2);
             ConcatS(TraceS,", EOS = ");
             TimeUtoS(EndOfSpentDate,TraceS2); ConcatLS(TraceS,TraceS2);
             ConcatS(TraceS,", SpentLevel = ");
             FtoS(SpentLevel,TraceS2); ConcatLS(TraceS,TraceS2);
             PrintString(TraceS);
             SetString(TraceS, "    Start of To Go = ");
             TimeUtoS(StartOfToGoDate,TraceS2); ConcatLS(TraceS,TraceS2);
             PrintString(TraceS);
        TRACE>*)



            (* If the user has elected to keep future effort in the 
               future, and has elected the sensible choice to 
               Separate Spent/ToGo = Yes, then make sure that future
               effort is not before the as of date. *)


        IF (NOT KeepEffortContiguous) AND
           (MoveFutureTasks) AND
           (StartOfToGoDate < AsOfDate) THEN
            StartOfToGoDate := AsOfDate;
        END;


        (*<TRACE
             SetString(TraceS, "    Start of To Go = ");
             TimeUtoS(StartOfToGoDate,TraceS2); ConcatLS(TraceS,TraceS2);
             PrintString(TraceS);
        TRACE>*)


        IF (ActivationContext^.EndOfSpentDate < EndOfSpentDate) THEN
            ActivationContext^.EndOfSpentDate := EndOfSpentDate;
        END;

            (* Create a varying assignment for the effort. *)

            (* Four cases:  
                            1.  The task is effort-driven.
                            3.  There is no effort.
                            3.  We know exactly when the assignment must end.
                            4.  The task is assignment-driven.
            *)

        IF (Task^.DurationMethod = EffortDriven) THEN     
            (* Effort Driven: If it's Delay, 
               we make each assignment end at the same date, computed by
               making the to go duration of each the same, equal to the
               task's total effort divided by the task's total effort rate.
               Sort of like one big assignment, in which all resources are
               interchangeable.  *)
            IF (Task^.SplittingRule = Split) THEN
                ErrorPhrase(0);     (* Should have been handled by our caller. *)
            END;
            TotalEffort := Task^.CompletedSummary.Time + Task^.ToGoSummary.Time;
            IF (TotalEffort > Zero) THEN
                ToGoDuration := TRUNC( ( ( TotalEffort * OneHundredTimesSMUPH)
                                           / ActivationContext^.TotalRate ) + Half);
            ELSE
                ToGoDuration := 0;
            END;

                (* Compute the end of assignment date, avoiding overflow. *)
            IF (TaskStart <= MaxDate - ToGoDuration) THEN
                EndOfAssignment := TaskStart + ToGoDuration;
            ELSE
                EndOfAssignment := MaxDate;
            END;
                (* See if this is the latest-ending assignment. *)
                (* Update the duration field of the task to reflect the 
                   duration that resulted from this effort. *)

            WITH Task^.Plan.Dates DO
                IF (EarlyEnd < EndOfAssignment) THEN
                    EarlyEnd := EndOfAssignment;
                END;
            END;

        ELSIF (MaxRatePercent <= 0) THEN
            (* No effort, No list. *)
            ToGoLevel := Zero;
        ELSIF (ActivationContext^.TaskIsDurationDriven) THEN
            EndOfAssignment := TaskEnd;
                (* If the user had entered the total number of hours of 
                   effort on the assignment, see how close we can come to
                   accomodating them.  Else, if they had entered a work
                   rate, use that. *)
            IF (HonorDaysOff) AND (Task^.SplittingRule = Split) THEN
                ToGoDuration := FwdFindDuration(Resource, StartOfToGoDate, 
                                                TaskEnd);
            ELSE
                ToGoDuration := TaskEnd - StartOfToGoDate;
            END;
            IF (ComputeByHours IN Attributes) THEN
                IF (ToGoDuration > 0) AND (YetToGoQuantity > Zero) THEN
                    ToGoLevel := YetToGoQuantity * OneHundredTimesSMUPH
                                 / FLOAT(ToGoDuration);
                ELSE
                    ToGoLevel := Zero;
                    IF (YetToGoQuantity <> Zero) THEN
                        IssueWarning(CantSchedFutureEffort, Task);                    
                        (*<TRACE    SetString(TraceS, "       Can't schedule Hours.");
                                    PrintAString(TraceS);
                         TRACE>*)
                    END;
                END;
            END;
        ELSIF (Task^.DurationMethod = AssignmentDriven) THEN
            TotalEffort := ActualQuantity + YetToGoQuantity;
            IF (ToGoLevel > Zero) THEN
                R := (TotalEffort * OneHundredTimesSMUPH) / ToGoLevel;
                IF (R <= FLOATMAXCARDINAL) THEN
                    ToGoDuration := TRUNC(R+Half);
                ELSE
                    ToGoDuration := MAX(ADuration);
                END;
            ELSE
                ToGoDuration := 0;               (* Error condition: dur would be infinite. *)
            END;
            EndOfAssignment := FwdFindEndDate(Resource, TaskStart, 
                                              ToGoDuration, DurationSatisfied);

                (* See if this is the latest-ending assignment. *)
                (* Update the duration field of the task to reflect the 
                   duration that resulted from this effort. *)

            WITH Task^.Plan.Dates DO
                IF (EarlyEnd < EndOfAssignment) THEN
                    EarlyEnd := EndOfAssignment;
                END;
            END;

        ELSE
            ErrorPhrase(0);             (* How could we possibly get here? *)
        END;


    END;


        (* Create the varying assignment entries to record the effort. *)


    WITH Assignment DO
           (*<TRACE
        SetString(TraceS, "       SpentLevel = ");  FtoS(SpentLevel,TraceS2);
        ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS, ", ToGoLevel = ");  FtoS(ToGoLevel,TraceS2);
        ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        SetString(TraceS, "       EOS = ");  TimeUtoS(EndOfSpentDate,TraceS2);
        ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS, ", STGD = ");  TimeUtoS(StartOfToGoDate,TraceS2);
        ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS, ", EOAss = ");  TimeUtoS(EndOfAssignment,TraceS2);
        ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
           TRACE>*)

       IF (SpentLevel <> ToGoLevel) OR (EndOfSpentDate <> StartOfToGoDate) THEN
               (* Should only happen for duration-driven tasks. *)
           AddRange(VaryingAssignment, Resource, StartOfSpent, EndOfSpentDate, 
                    SpentLevel);
           AddRange(VaryingAssignment, Resource, StartOfToGoDate, EndOfAssignment,
                    ToGoLevel);
       ELSE
           IF (ToGoLevel > Zero) THEN
               AddRange(VaryingAssignment, Resource, StartOfSpent, EndOfAssignment, ToGoLevel);
           END;
       END;
    END;

    RETURN NOT SchedulingAbandoned;

END AssignContiguousEfforts;




    (*---------------------------------------------------------------------
      AssignContiguousEffortDriven

      For a contiguous, effort-driven task,
      schedule the whole task and create the varying assignments.

    ---------------------------------------------------------------------- *)


PROCEDURE AssignContiguousEffortDriven( Task : ATaskPtr;
                                  VAR ActivationContext: AnActivationContext);
VAR
    LocalSplittingRule :  ASplittingRule;
BEGIN
        (* If the task is to be scheduled contiguously, then it will
           need to split around vacations. *)
    LocalSplittingRule := Task^.SplittingRule;
    Task^.SplittingRule := Split;

         (* Assign the spent effort, and determine an end of
            spent date. *)
    ActivationContext.EndOfSpentDate := Task^.Plan.Dates.EarlyStart; 
    ComputeTotalWorkRate(Task,ActivationContext);

    ForEachAssignment (Task^.Plan.Assignments, AssignSpentEfforts,
                       ADR(ActivationContext) );
    IF SchedulingAbandoned THEN RETURN; END;
         (*  Now allocate the to go effort evenly. *)
    ActivationContext.StartOfToGoDate := ActivationContext.EndOfSpentDate; 
    SetEndDateAndFutureAssignments(Task, ActivationContext,
                                   TRUE  (* CreateVaryingAssignments *) );

    Task^.SplittingRule := LocalSplittingRule;
END AssignContiguousEffortDriven;


    (*---------------------------------------------------------------------
      ActivateContiguousEffortTask

      For a task whose future and spent efforts must be contiguous,
      schedule the whole task and create the varying assignments.

    ---------------------------------------------------------------------- *)

PROCEDURE ActivateContiguousEffortTask (    Task : ATaskPtr;
                                        VAR ActivationContext: AnActivationContext);
BEGIN
       (*<TRACE
    SetString(TraceS, "   ActivateContiguousEffortTask ");
    ConcatTaskID( TraceS, Task );
    PrintString(TraceS);
       TRACE>*)


    WITH Task^ DO WITH Plan.Dates DO
            (* Case that start date is forced: *)
        IF (EarlyStart > StartDateUpperBound) 
            OR (StartDateUpperBound <= StartDateLowerBound) THEN
            EarlyStart := StartDateUpperBound;
            EarlyEnd   := EarlyStart+duration;      (* Safety setting. *)
        END;
            (* Summary tasks do not have a set length, so we do not 
               schedule any future effort assigned to them during
               the main part of scheduleing.  That
               must be done later, in TLPlan, or whoever it is that
               sets the durations of the summary tasks.  Here, if we
               are in the main part of planning we schedule the start
               or end milestone as a point in time. *)
        IF (SummaryFlag IN TempTaskFlags) AND
           (NOT ActivationContext.ScheduleSummaryTasks) THEN
            EarlyEnd   := EarlyStart;
        END;
    END END;

        (* Assign the complete effort for the task, both spent and  
           to go.  Mark the task "AlreadyScheduled" because there is
           nothing left for resource levelling to do. *)


        (* Effort-driven tasks get handled here because we have to
           take a view of all resources on the task simultaneously. *)
    IF (Task^.DurationMethod = EffortDriven) THEN
        AssignContiguousEffortDriven(Task,ActivationContext);
    ELSE
        ForEachAssignment (Task^.Plan.Assignments, AssignContiguousEfforts,
                           ADR(ActivationContext) );
    END;
    



            (* If the user has entered an end date for a done task,
               use that as the end date of the task.  Otherwise,
               use the end of the spending date. *)

    IF (Task^.StartStatus = DoneS) THEN
        WITH Task^.Plan.Dates DO
            EarlyEnd := BigTimeToCalendarTime(Task^.UserEnteredEndDate);
            IF (EarlyEnd < EarlyStart) THEN
                IssueWarning(DoneBeforeStart, Task );
                EarlyEnd := EarlyStart;
            END;
        END;
        (*<TRACE  SetString(TraceS, "       Task is Done, so end date is .");
                    TimeUtoS(Task^.Plan.Dates.EarlyEnd, TraceS2);   ConcatLS(TraceS, TraceS2);
                    PrintString(TraceS);
        TRACE>*)
    END;

    INCL(Task^.TempTaskFlags, AlreadyScheduled);
    (*<TRACE  SetString(TraceS, "       Mark AlreadyScheduled.");
                PrintString(TraceS);
    TRACE>*)
END ActivateContiguousEffortTask;




    (*---------------------------------------------------------------------
      SetTentativeEndDate

      Put a tentative value into the EarlyEnd field, consisting of either
      the early start + duration (if the task is duration driven) or
      the early start.

    ---------------------------------------------------------------------- *)


PROCEDURE SetTentativeEndDate (Task : ATaskPtr);
BEGIN
   WITH Task^.Plan.Dates DO
        IF (Task^.StartStatus = DoneS) THEN
                (* If the user has entered an end date, then this
                   establishes a lower bound on the end date of the task.
                   If the date that the user entered conflicts with the
                   computations implied by the assignments, the 
                   assignments win.  This is not expected to be a problem,
                   since the task form edit rules should prevent entry
                   of a task whose assignments would extend past the 
                   entered date.
                *)
            (*<TRACE
            SetString(TraceS, "    SetTentativeEndDate for Done task.");
            PrintString(TraceS);
            TRACE>*)
            EarlyEnd := BigTimeToCalendarTime(Task^.UserEnteredEndDate);
        ELSIF (Task^.DurationMethod = DurationDriven) THEN
            IF (EarlyStart <= MaxDate-Task^.duration) THEN
                EarlyEnd   := EarlyStart + Task^.duration;
            ELSE
                (*<TRACE
                SetString(TraceS, "Past end of calendar ");  ConcatTaskID(TraceS, Task);  ConcatS(TraceS, " at ");
                TimeUtoS(EarlyStart, TraceS2);  ConcatLS(TraceS, TraceS2); ConcatS(TraceS, " dur = ");
                CtoS(Task^.duration, TraceS2); ConcatLS(TraceS, TraceS2);
                PrintString(TraceS);
                TRACE>*)
                IssueWarning(PastEndOfCalendar, Task);
                EarlyEnd   := MaxDate;
            END;
        ELSE
            EarlyEnd := EarlyStart;
        END;

        IF (EarlyEnd < EarlyStart) THEN
            (* IssueWarning(DoneBeforeStart, Task );  Warnings will be issued by
               other procs. *)
            EarlyEnd := EarlyStart;
        END;

        (*<TRACE
        SetString(TraceS, "    TentativeEndDate set to ");
        TimeUtoS(EarlyEnd, TraceS2);  ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        SetString(TraceS, "    EarlyStart = ");
        TimeUtoS(EarlyStart, TraceS2);  ConcatLS(TraceS, TraceS2);
        ConcatS(TraceS, ", Duration = ");
        CtoS(Task^.duration, TraceS2);  ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        TRACE>*)
    END;

END SetTentativeEndDate;




    (*---------------------------------------------------------------------
      ActivateTask (exported procedure described in def)


    ---------------------------------------------------------------------- *)


PROCEDURE ActivateTask( Task : ATaskPtr );
VAR
    ActivationContext : AnActivationContext;
    TaskEnd : ADate;
    Found   : BOOLEAN; 
BEGIN
       (*<TRACE
    SetString(TraceS, "ActivateTask ");
    ConcatTaskID(TraceS, Task);
    PrintString(TraceS);
       TRACE>*)

    (* INITIALIZATION: *)
    ActivationContext.Task := Task;
        (* This procedure does not schedule summary tasks.  That is
           done later. *)
    ActivationContext.ScheduleSummaryTasks := FALSE;


    WITH Task^ DO
 
            (* Set TaskIsDurationDriven if it is.  FALSE means
               that we must compute an end date. *)
        ActivationContext.TaskIsDurationDriven :=
              (DurationMethod = DurationDriven);
    END;


    (* Initialize early end date to lowest possible value.
       It will be updated later to the max of the end dates
       of the varying assignments. *)
    SetTentativeEndDate(Task);


    (* GET "CONTIGUOUS EFFORT" TASKS OUT OF THE WAY *)
        (* If the user has elected to make scheduling compatible with version
           4.0 of Time Line, and it is a Started or Done task, assign the
           complete and unvarying effort.   We also can schedule the complete
           effort for Started or Done duration-driven tasks, because levelling
           could not do otherwise.  *)

    IF (UnspentWorkMustBeContiguous(Task)) THEN
         (* The user has specified that unspent work must be
            contiguous to spent work, and the task is either
            started, done, or duration-driven: *)
        ActivateContiguousEffortTask(Task, ActivationContext);
    ELSE

            (* HANDLE NON-"CONTIGUOUS EFFORT" TASKS" (this is the "normal" case)
               Four cases 
    
             (note: Started or Done implies a must start date):
                       1.  No spent effort, must start date.
                       2.  No spent effort, unknown start date.
                       3.  Some spent effort, must start date. 
                       4.  Some spent effort, unknown start date.
    
           CASE 1    Use the required start date as the start of 
                     the to go effort on the task.
    
                2    Find a start date that meets the requirements of
                     the task, based on its task type, splitting rule, etc.
    
                3.   Use the required start date as the date on which the
                     spending started.  Find a start date for the future
                     effort, though, based only on the task type, etc.
    
                4    Use the minimum start date as determined by antecedant
                     tasks as the start date of the spent effort.  Find
                     a start date for future effort based on task type, etc.
            *)
    
    
            (* 1. FIND START DATE FOR BEGINNING OF THE TASK *)
    
        FindAStartDate(Task);
        SetTentativeEndDate(Task); (* update tentative early end date *)
    
    
            (* 2. ACTIVATE ANY SPENT EFFORT *)
            (* Activate the spent effort in order to set the end of spending
               in each assignment and to set the overall task start of 
               to go date.   If the spent effort was zero, these dates are
               set.  If there was spent effort, we figure out how much of the
               effort has been spent and put that into the past, that is, we put
               it before the as-of date; and we set the end of spending 
               accordingly. *)
        ActivationContext.EndOfSpentDate := Task^.Plan.Dates.EarlyStart; 
        ForEachAssignment (Task^.Plan.Assignments, AssignSpentEfforts,
                           ADR(ActivationContext) );
        IF SchedulingAbandoned THEN RETURN; END;
    
    
            (* 3. FIND START DATE FOR TOGO EFFORT *)
            (* If some effort was spent, then we need to find a legal date,
               StartOfToGoDate, for the remaining effort. For Split tasks this
               is the end of spending date.  For delay tasks, it may be
               later.  *)
    
        FindStartDateForFutureWork(Task, ActivationContext);
    
    
            (* 4. FIND TASK END DATE (AND CREATE ASSIGNMENTS FOR TOGO EFFORT) 
                   Find the early end date, and create varying assignments if
                   levelling will not take place. (Note that for effort-driven
                   split tasks, one procedure accomplishes both of these.) *)
    
        SetEndDateAndFutureAssignments(Task, ActivationContext,
                                       (NOT Levelling));

    END;

END ActivateTask;




    (*---------------------------------------------------------------------
      AssignSummaryToGoEfforts

      Determines an end date for the assignment and (optionally) creates
      varying assignment entries for the work that is yet to go
      on this resource assignment.

    ---------------------------------------------------------------------- *)


PROCEDURE AssignSummaryToGoEfforts( VAR Assignment : AnAssignmentRecord;
                                 Context    : ADDRESS            ) : BOOLEAN;
VAR
    ActivationContext : POINTER TO AnActivationContext;
    Task : ATaskPtr;
    i : CARDINAL;
    TaskEnd : ADate;
    ToGoLevel : REAL;
    StartOfToGo, EndOfToGo, EndOfSpent : ADate;
    AvailableTicks, ToGoDuration : ADuration;
    R : REAL;
    ToGoEffort : REAL;
    DurationSatisfied : BOOLEAN;

BEGIN
       (*<TRACE
    SetString(TraceS, "   AssignSummaryToGoEfforts for ");
    ConcatLS(TraceS, Assignment.Resource^.Name);
    PrintString(TraceS);
       TRACE>*)

    IF (Assignment.Resource^.Type = AccountingOnly) THEN
        RETURN TRUE;
    END;

    ActivationContext := Context;         (* Get the pointer to the context record. *)
    Task := ActivationContext^.Task;      (* Get the pointer to the task record. *)

    StartOfToGo := ActivationContext^.StartOfToGoDate;

       (*<TRACE
    SetString(TraceS, "     StartOfToGo is ");
    TimeUtoS(StartOfToGo,TraceS2); ConcatLS(TraceS,TraceS2);
    PrintString(TraceS);
       TRACE>*)



        (* We know the start date and the end date of the future
           work.  Compute the rate the work must be done at. *)

    WITH Assignment DO
        EndOfToGo := Task^.Plan.Dates.EarlyEnd;
        ToGoLevel := FLOAT(MaxRatePercent);
        ToGoDuration := EndOfToGo-StartOfToGo;
        ToGoEffort   := Zero;

        (*<TRACE  SetString(TraceS, "       2b: ToGoDur =");
        CtoS(ToGoDuration, TraceS2); ConcatLS(TraceS, TraceS2);  ConcatS(TraceS, ", ActualQuantity = ");
        FormatAsAmount(ActualQuantity, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
        ConcatLS(TraceS, TraceS2); PrintString(TraceS);
        TRACE>*)

        
            (* If the user had entered the total number of hours of 
               effort on the assignment, see how close we can come to
               accomodating them.  Else, if they had entered a work
               rate, use that. *)
    
        IF (ComputeByHours IN Attributes) THEN
            (*<TRACE  SetString(TraceS, "       ComputeByHours is set.");
                        PrintString(TraceS);
            TRACE>*)

            IF (ToGoDuration > 0) AND (YetToGoQuantity > Zero) THEN
                ToGoLevel := YetToGoQuantity * OneHundredTimesSMUPH
                             / FLOAT(ToGoDuration);
            ELSE
                ToGoLevel := Zero;
                IF (YetToGoQuantity <> Zero) THEN
                    EXCL(Attributes, ComputeByHours);
                    (*<TRACE  SetString(TraceS, "       Exclude ComputeByHours.");
                                PrintString(TraceS);
                    TRACE>*)
                END;
            END;
        ELSE
            ToGoLevel := FLOAT(MaxRatePercent);  (* Rate entered on assignment form. *)
        END;

        ToGoEffort := (FLOAT(ToGoDuration) * ToGoLevel) / OneHundredTimesSMUPH;

        

            (* Add the to go effort of this assignment to the task's total
               to go effort.  We need to do this, since vacations may have
               reduced the effort (we keep the rate the same, but the 
               number of days is reduced) or spent effort could have
               increased the effort, if it was spent before the start
               of the task. *)

        Task^.ToGoSummary.Time := Task^.ToGoSummary.Time + ToGoEffort;

            (* Create the varying assignment entry. *)

        AddRange(VaryingAssignment, Resource, StartOfToGo, EndOfToGo, ToGoLevel);
        
    END;

    RETURN NOT SchedulingAbandoned;

END AssignSummaryToGoEfforts;





    (*---------------------------------------------------------------------
      ActivateTask (exported procedure described in def)


    ---------------------------------------------------------------------- *)


PROCEDURE ActivateSummaryTask( Task : ATaskPtr );
VAR
    ActivationContext : AnActivationContext;
    TaskEnd : ADate;
    Found   : BOOLEAN; 
BEGIN
       (*<TRACE
    SetString(TraceS, "ActivateSummaryTask ");
    ConcatTaskID(TraceS, Task);
    PrintString(TraceS);
       TRACE>*)

    (* INITIALIZATION: *)
    ActivationContext.Task := Task;
    WITH ActivationContext DO
            (* Since we are the last step of scheduling,
               we need to schedule all effort, both spent and to go. *)
        ScheduleSummaryTasks := TRUE;
        CreateAssignments    := TRUE;
        TaskIsDurationDriven := TRUE;
    END;
    WITH Task^ DO
        DurationMethod := DurationDriven;
        SplittingRule  := Split;
            (* We need to add up the actual effort, because the task duration
               changes and also vacations may reduce it. *)
        ToGoSummary.Time := Zero;
    END;



        (* 2. ACTIVATE ANY SPENT EFFORT *)
        (* Activate the spent effort in order to set the end of spending
           in each assignment and to set the overall task start of 
           to go date.   If the spent effort was zero, these dates are
           set.  If there was spent effort, we figure out how much of the
           effort has been spent and put that into the past, that is, we put
           it before the as-of date; and we set the end of spending 
           accordingly. *)
    ActivationContext.EndOfSpentDate := Task^.Plan.Dates.EarlyStart; 
    ForEachAssignment (Task^.Plan.Assignments, AssignSpentEfforts,
                       ADR(ActivationContext) );
    IF SchedulingAbandoned THEN RETURN; END;


        (* 3. FIND START DATE FOR TOGO EFFORT *)
        (* If some effort was spent, then we need to find a legal date,
           StartOfToGoDate, for the remaining effort.
        *)

    WITH ActivationContext DO
        StartOfToGoDate := EndOfSpentDate; (* tentatively *)

        (*<TRACE
        SetString(TraceS, "Find Start Date For Future Summary Work, ");
        ConcatTaskID(TraceS, Task);
        ConcatS(TraceS, ", EndOfSpentDate = ");
        TimeUtoS(EndOfSpentDate, TraceS2);  ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        TRACE>*)

        IF (StartOfToGoDate < Task^.Plan.Dates.EarlyStart) THEN
            StartOfToGoDate := Task^.Plan.Dates.EarlyStart;
        END;

            (* Load future work to right of As-of Date: *)
        IF (MoveFutureTasks) 
           AND (Task^.ToGoSummary.Time > Zero)
           AND (StartOfToGoDate < AsOfDate) THEN
                StartOfToGoDate := AsOfDate;
        END;
    END;


        (* 4. CREATE ASSIGNMENTS FOR TOGO EFFORT  *) 

    ForEachAssignment (Task^.Plan.Assignments, AssignSummaryToGoEfforts, 
                       ADR(ActivationContext) );


END ActivateSummaryTask;











BEGIN
    (*<TRACE
    Fill(TraceS, " ", 0);
    Fill(TraceS2, " ", 0);
    SetString(TraceTitle, "CpmActivate");
    TRACE>*)

    OneHundredTimesSMUPH := FSMUPH * OneHundred;
END CpmActivate.


Early mod history:

       Sep. 9, 1990   AJL - Moved code here from TLCPM.
       Sep 18, 1990   AJL - Always compute the total rates for effort-driven
                            tasks.
       Sep. 21 1990   AJL - Remove the code which was removing assigned
                            resources from the residual availability lists.
                            This is now done elsewhere.
       Sep 28  1990   AJL - Implemented more of the scheduling of effort-delay
                            tasks.
       Oct. 3, 1990   AJL - Added effort-split tasks.
       Oct. 5, 1990   AJL - Removed extra parameter from
                            CreateSubstitutableResourceAssignments.
       Oct. 6, 1990   AJL - The former procedure EarliestStartDate was renamed
                            to FindEarliestStartDate and a latest search date
                            parameter was added.
       Oct. 16, 1990  AJL - Corrected a problem in which a duration-driven task
                            with no spent effort would not have any varying assignment
                            list created.
       Oct. 19, 1990  AJL - Corrected the documentation for AddRange.
       Oct. 30, 1990  CL  - Renamed FindDuration to FwdFindDuration and
                            FindEndDate to FwdFindEndDate.
                          - Fix the indentation of IMPORT section.
       1-Nov-90       CL  - Renamed UpperBoundStartDate to StartDateUpperBound, 
                            LowerBoundStartDate to StartDateLowerBound, 
                            LockScheduledDates to FrozenTask, 
                            ResourceDriven to EffortDriven.
       Nov. 2,  1990  AJL - Mark completely scheduled tasks AlreadyScheduled. 

       Nov  5,  1990  JES - Added parameter "Contour" to the call of
                            "CreateSubstitutableResourceAssignments"
       6-Nov-90  CL  - Renamed MakeAssignments to AssignForInterval.
      15-Nov-90  CL  - IMPORT CreateSubstitutableResourceAssignments
                       from ResScheduleTaskResourcesResSched instead of 
					   ResActivate.
      16-Nov-90  AJL - Handle the case where a task cannot be scheduled
                       within its bounds and still honor vacations. 
      19-Nov-90  CL  - Added parameter HonorVacations to procedures  
                       FwdFindEndDate and FwdFindDuration.
      20-Nov-90  CL  - Created procedure BackFindTaskStart.
      21-Nov-90  AJL - Added some tracing.
      27-Nov-90  AJL - Added more documentation.
                     - Rearranged some of the processing of effort-split
                       tasks.
      28-Nov-90  AJL - For tasks with spent effort, reset the UpperBound to
                       MaxDate (see comments in body of code.)  For some
                       of these, recompute the start date of the to go 
                       effort.
      29-Nov-90  AJL - Restructured the processing of effort-driven tasks.
                     - Added SchedulingAbandoned error testing.
                     - Removed test for Frozen tasks from FindAStartDate.
      30-Nov-90  JES - Changed call to FindEarliestStartDate to the new
                       procedure FindCpmEarliestStartDate. This procedure
                       sets parameters correctly for cpmactivate's
                       purposes.
       6-Dec-90  AJL - Make sure that we set MustStart dates for tasks
                       even when the user has elected that the task must
                       be scheduled contiguously.
       6-Dec-90  JES - Fixed some comments and minor bugs. Broke
                       ActivateTask into some smaller procedures.
      10-Dec-90  JES - Put procedures back into bottom-up order in the
                       module.
      10-Dec-90  AJL - Always compute the EndOfSpent date, even for 
                       assignments to resources which are not Employable.
                     - Make sure that the StartOfToGo date is >= the
                       earlystart of the task.
                     - Add additional comments.
      11-Dec-90  AJL - Changed some parameters to VAR so that the 
                       ActivateTaskContext will be updated properly.
                     - Moved a test that the Resource is Employable into
                       AssignSpentEfforts.  
      16-Dec-90  AJL - Moved a test of Resource is Employable in AssignContig..
                       Efforts so that we always deallocate any previous
                       varying assignments.
                     - For duration-driven tasks, recompute the remaining
                       effort whenever the task is scheduled.
      17-Dec-90  AJL - In AssignToGoEfforts, always set the task end date
                       to be later than any spending, even when all the
                       effort was spent.
                     - Remove some tests which avoided calling AssignToGoEfforts
                       when the remaining effort on the task was zero, because
                       the logic required additional support to get the task
                       end date right, and I don't think that there will be
                       enough tasks in a typical schedule that have all effort
                       spent but are not marked dome to warrant the complexity
                       of this "optimization."
      23-Dec-90  AJL - Make a change in SetEndDateAndFutureAssignments similar
                       to the above change to AssignToGoEfforts, so that the
                       end date is = end of spending when remaining effort is
                       zero.
      27-Dec-90  AJL - Before going through all the work of assigning spent
                       effort, make sure that there is some.
                     - Limit the end date of spent effort to the UserEnteredEndDate.
      28-Dec-90  JES - In calls to BackFindStartDate, added the new 
                       BOOLEAN VAR parameter "DurationSatisfied". 
      29-Dec-90  AJL - Rearrange the procedures to check for effort-driven
                       tasks before looking at the assignment details.
      31-Dec-90  AJL - Renamed ActivateTaskContext to ActivationContext.
                     - Removed BackFindTaskStart;
