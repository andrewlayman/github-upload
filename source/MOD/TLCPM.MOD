(*V2=KILL pointers when FlexStor objects are released. *)
(*V8=GELDED*)
(*V9=DEBUG*)
(*V7=TRACE*)


(*<KILL (*$T+*) KILL>*)

MODULE TLCPM;


    (* MODIFICATION HISTORY:

       (notes from 1/2/86 through  9-Sep-90 moved to end of text file.


     *)(*
      12-Sep-90 AJL   -Use UserEnteredStartDate rather than FixedStart.
      13-Sep-90 AJL   -Use StartDateUpperBound and StartDateLowerBound.
      24-Sep-90 AJL   -Lots of reorganizations and consolidations.
                      -Added late independent start and end date calculations.
       6-Oct-90 AJL   -Renamed Task^.Temp3 to Fingerprint.
       9-Oct-90 AJL   -Fill-in sequence numbers on tasks and resources.
      31-Oct-90 AJL   -Use Planner.RecalcOptions.AllowNegativeSlack.
       1-Nov-90 CL    -Rename UpperBoundStartDate to StartDateUpperBound,
                       LowerBoundStartDate to StartDateLowerBound,
                       LockScheduledDates to FrozenTask, 
                       SuppressSlack to ForceCritical.
       3-Nov-90 AJL   -Into the LowerBoundStartDate field, store the maximum
                       of the cpm early start and the MaxEndOfSpent.
       8-Nov-90 AJL   -If we are levelling within slack, set the StartDateUpperBound
                       to the LateTotalStart. 
      13-Nov-90  CL  - Move SubtractDuration to ResUtilities.
      19-Nov-90 AJL  - If we determine that we need to link to external schedules,
                       we set a flag and exit, requesting that the links be done 
                       first and then to call us again.  This saves memory by not
                       having us make the overlay call.
      21-Nov-90 AJL  - Use BackFindTaskStart in place of SubtractDuration.
      27-Nov-90 AJL  - Check SchedulingAbandoned after calling ScheduleResource
                       in case we ran out of memory.
                     - Pass the count of tasks to AddTerminalNodes.  It is not
                       at this point in recalc a completely accurate count, but it
                       is good enough to put up a progress thermometer.
      28-Nov-90 AJL  - Don't try to find a start date for a linked task.  It
                       is already known.
                     - Don't call FindAStartDate.  it has been included
                       as part of the function of ActivateTask.
                       *)(*
       6-Dec-90 AJL  - Moved the INC of TaskCount to before testing it.
                     - Changed the main loop in ForwardPass from a FOR loop
                       to a WHILE one so that we can also check for
                       SchedulingAbandoned.
                     - Fixed ALAP tasks so that we avoid an extra call to 
                       BackFindTaskStart and instead use the FreeStartDate.
      11-Dec-90 AJL  - Set SomeBaselineExists.
      12-Dec-90 AJL  - Don't force an early limit on ALAP tasks in TaskNeedsLimit.
      16-Dec-90 AJL  - After moving ALAP tasks, re-Activate them so that their
                       varying resource assignments reflect the late start
                       dates. 
     *)(*
      24-Dec-90 AJL  - Do not force Done tasks to be duration driven.  This
                       would contradict the behavior of started tasks and 
                       would be particularly incorrect for assignment-driven
                       tasks whose assignments do not end concurrently.
      30-Dec-90 JES  - Substituted FindLatestStartDate for BackFindTaskStart
                        (in computing late free and late total start dates).
                       (BackFindTaskStart erroneously assumed that the
                       given late end date is a possible end date for the
                       task; it also treated all tasks as though they were
                       Split type, and it had not yet been extended to
                       treat Effort-Driven Split tasks.
                AJL  - Modified callers of FindLatestStartDate to use
                       OptimisticFindLatestStartDate which relies on the 
                       knowledge that the EarlyStart and EarlyEnd are known.
       2-Jan-90 AJL  - Don't call fatal error if during the reverse pass
                       we cannot compute a good early start.  Do IssueWarning.
       3-Jan-90 AJL  - Remove global VAR ToGo.
                     - Added AllLevel0TasksAreSummary and SomeLevel0TaskIsSummary.
       5-Jan-90 AJL  - Don't attempt to compute Late Start dates for tasks
                       whose start dates are history: started or done tasks.
       8-Jan-91 AJL  - Skip creation of summary phantoms if there are no
                       summary tasks.
      10-Jan-91 JES  - Changed call to FindLatestStartDate to include
                        the new VAR parameter TaskEndDate.
                     - Dispose any late residue availability.
                     - Add new parameter to create residue avail.
      14-Jan-91 JES  - Added new parameter DoWeUseLateAvailabilities to
                        call of FindLatestStartDate.
      15-Jan-91 AJL  - Don't try to compute late end dates for Done tasks.
      16-Jan-91 AJL  - Incorporate a Depth-first-search into the finding
                       of independent start dates so that summary nodes do
                       not affect the calculated dates.
      17-Jan-91 AJL  - Change the calculations of independent slack to check
                       all tasks except those with no total slack (formerly
                       had be no free slack).
      23-Jan-91 AJL  - For ALAP tasks with bounds on the start date,
                       force the task within bounds before activation.
      Feb 15, 91 JES - Renamed MaxEndOfActuals to MaxEndOfSpent.
      22-Feb-91 AJL  - Add HonorDaysOff as a parameter to 
                       MakeAvailabilityIntoResidue.
      22-Feb-91 JES  - Removed unused imports FwdFindEndDate and
                       FwdFindDuration.
       6-Mar-91 AJL  - Make sure that the NoSoonerStart and NoLaterStart flags
                       are not set for summary tasks.  Fixes problem #580.
                     - Store the CPM Start Date into the SupposedToStart field.
     *)(*
      26-Mar-91 AJL  - Improve error handling in InitOneResource.
       5-Apr-91 AJL  - Schedule started summary tasks at the start date of the
                       earliest child.  Solves problem number 576.
                     - Also, related to this problem, we may force future summary
                       tasks to the right of the today line.
       5-Apr-91 AJL  - Moved FindIndependentDates to TLPlanEx.
      12-Apr-91 AJL  - When levelling within slack (TimeConstrained) and a
                       task has negative total slack, ensure that the 
                       StartDateLowerBound <= StartDateUpperBound.
                     - No longer store a date into the count field.
                       *)(*
      17-Apr-91 AJL  - Use CannotScheduleLate.
      18-Apr-91 AJL  - For tasks that are supposed to be scheduled
                       Contiguously, do not set the StartDateLowerBound
                       to greater than the EarlyStart date.
      25-Apr-91 AJL  - Summary tasks which are actually started must
                       start at the start date of the earliest started child.
                       However, mere containment of a task with a required
                       start will not set a start date requirement on the parent.
                     - Prevent the reverse pass from scheduling any ALAP
                       tasks sooner than their early start dates.
       1-May-91 AJL  - The ForceCritical flag for ALAP tasks is processed
                       AFTER the task is moved to the end of its slack.
       6-May-91 AJL  - Don't schedule ALAP tasks before their early start 
                       dates (fixes a problem that could occur if they have
                       negative free slack).
      23-May-91 AJL  - Fix a bug discovered by Gary (number 4515).
                       Modified the FindInitialStartDate procedure so that
                       if ForceFuture is on, we force all tasks, including
                       Fixed ones, to have their start dates >= the lesser
                       of the AsOfDate and their StartDateUpperBound.  (We
                       used to exempt tasks with NoSoonerStart.)
      29-May-91 AJL  - Fix a bug with dependencies to the end of a task.
                       Put a valid implied duration into the descendant
                       task before computing the effect of the dependency.
       3-Jun-91 AJL  - For linked tasks, or any "AlreadyScheduled" tasks,
                       do not modify the StartDateLowerBound in the 
                       ReversePass procedure.  This is to handle the case
                       of linked tasks, whose lower bounds are set by the
                       linker.
       4-Jun-91 AJL  - Before sending the tasks over for levelling, if 
                       MoveFutureTasks is on, change the LowerBound to 
                       be Min(AsOfDate,UpperBound).
     *)(*
      13-Jun-91 AJL  - If a task has already been scheduled by some
                       other process of calculation (such as linking to another
                       schedule) then we don't update its early start or
                       end dates.
      18-Jun-91 AJL  - Tasks with NoSoonerStart in their Flags will not be
                       forced to the right of the as of date line unless that
                       option is selected by the user.
      20-Jun-91 AJL  - Use the TempFlag1 in the task node to indicate whether
                       or not the task has any assignments.
      24-Jun-91 AJL  - Avoid overflow when adding durations to dates.
       1-Jul-91 AJL  - Flag dependencies from the start or to the end of
                       summary tasks as "partial."
      22-Jul-91 AJL  - If we bail out early from the main loop in ForwardPass,
                       move the remains of the ReadyList to the PrivateTaskList.
      12-Aug-91 AJL  - In procedure ReversePass, always check edges of all tasks,
                       even Done tasks, to detect partial dependencies.  Bug 4958. 
      14-Aug-91 AJL  - Make sure that late free start is not > late total start,
                       which was happening when total slack was negative.
      12-Sep-91 AJL  - Don't set ForceCritical for Done tasks.  Instead, 
                       separately test for done tasks before computing slack.
                       See bug 4917.
                     - If there is a lower bound set for the start date of a
                       task, and this conflicts with the request to level tasks
                       within slack (TimeConstrained) then honor the lower bound
                       and issue a warning.  Bug report 5074.
      19-Sep-91 AJL  - Add a new procedure ConstrainStartDate and expand it
                       so that we work backwards from the target end date for
                       effort driven started tasks.
      27-Sep-91 AJL  - Only fill in a "UserEnteredStartDate" if the task
                       has NO restrictions on its start or end. 
       2-Oct-91 AJL  - Linked, fixed-date tasks will be considered as
                       AlreadyScheduled regardless of their start date
                       restrictions.
       3-Oct-91 AJL  - Don't initialize the start dates of linked tasks.  This
                       was forcing the start dates into the future when 
                       ForceFuture was turned on.
      24-Jan-92 AJL  - Add a shortcut in OptimisticFindLatestStartDate to
                       speed up duration-driven tasks.
                     - Use NoVacationsFlag to speed some decisions.
      29-Jan-92 AJL  - Changed rate parameters to REAL.
       2-Apr-92 AJL  - If Levelling is on, don't put ALAP tasks at their
                       late start dates here.  That constrains them too much
                       during levelling.  See the BORC0326 schedule.
    *)

FROM Allocs    IMPORT
    (* CONST *)         TskNmLen,
    (* TYPE *)          ATask, ADateBlock, AnAssignmentSummary,
                        ATaskPtr, ATaskName, AFixType, ATempTaskFlagSet,
                        AStartStatus, ATaskFlag, ATaskFlagSet, ARollupStatus,
                        ATaskStatusSet, ATaskStatus, ADurationMethod,
                        ASplittingRule,
    (* VAR *)           TaskTree,
                        StartStatusName,
    (* PROC *)          CheckTaskValid,
                        CreateTask, DelTask;


FROM AsOf      IMPORT
    (* VAR  *)          AsOfDate,
    (* PROC *)          SetAsOfDate;

FROM Assignments IMPORT
    (* TYPE *)                  AnAssignmentAttribute,
                                AnAssignmentRecord, AnAssignmentArray,
    (* PROC *)                  ForEachAssignment;


FROM CpmActivate  IMPORT
    (* PROC *)          ActivateTask;

FROM Dialog    IMPORT   Message, Error, FatalError, Burp,
                        ProgressBox, ReleaseBox, ABoxHandle, WarningBox,
                        ADialogOption, NotYetImplemented;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr,
    (* PROC *)                  CheckEdgeValid, FindEdge, DelEdge,
                                CreateEdge, AddEdge, RemoveEdge;

FROM FlexStor       IMPORT
    (* TYPE *)     AnExtHandle, AnExtStoragePreference,
    (* PROC *)     
                   CreateExtObject, SetExtData, GetExtData,
                   CreateExtObjectWithSize, SetExtSize, GetExtSize,
                   DiscardExtObject,
                   HandleIsValid, ObjectsAreSame,
                   LockObject, LockObjectArray, ReleaseObject,
                   ReleaseUnchangedObject,
                   ArraySize, NumberOfElements,
                   CopyExtObject;

FROM IndProjects IMPORT
    (* PROC *)          AddTerminalNodes;

FROM Kbio      IMPORT   PutString, BreakRequested,
                        avidmode, maxrow, maxcol;

FROM LStrings  IMPORT   SetString, ConcatS, ConcatLS, CtoS, Compare,
                        SubStr, Fill, TrimFront, Copy, Procustes,
                        SetLengthOf;

FROM MsgFile   IMPORT   GetMessage, ConcatMessage, DisplayMessage;

FROM Phantoms  IMPORT
    (* CONST*)          SummaryFlag, PhantomFlag,
    (* PROC *)          Scan1, CreateSummaryPhantoms, DiscardSummaryPhantoms;

FROM Planner   IMPORT
    (* TYPE *)          APlannerContext, ARollupWeighting, SomeBaselineExists,
    (* VAR *)           ScheduleComputedOk, Levelling,
                        ScheduleStartDate, ScheduleEndDate, HonorDaysOff,
                        MoveFutureTasks, TimeConstrained, RecalcOptions;

FROM PTaskList    IMPORT
    (* CONST *)         Visited, TerminalFlag, AlreadyScheduled,
                        NoVacationsFlag,
    (* VAR  *)          PrivateTaskList, TaskCount,
                        BoxHandle, BoxShowing, SpaceReserved,
                        NeedLinkedScheduleRollin,
                        AllLevel0TasksAreSummary,SomeLevel0TaskIsSummary,
    (* PROC *)          ListInit, AddBefore, DeList,
                        MoveList,
                        ComputeEdgeDelta, CountDown;

FROM ResAvailableResources IMPORT
    (* PROC *)          ScheduleResource, FreeResource;

FROM ResCal                 IMPORT
    (* PROC *)                  DisposeResAvailabilities;

FROM ResCalMG      IMPORT
    (* PROC *)          MakeAvailabilityIntoResidue;

FROM ResCalUI               IMPORT
    (* TYPE *)                  AResourceCalendarPointer;
    
FROM ResConstants IMPORT
    (* VAR *)           SchedulingAbandoned;

FROM ResLates     IMPORT
    (* PROC *)          FindLatestStartDate;

FROM ResUtilities IMPORT
    (* PROC *)          MaxEndOfSpent, SubtractDuration, UnspentWorkMustBeContiguous;

FROM ResWarnings  IMPORT
    (* TYPE *)          AWarning,
    (* PROC *)          IssueWarning;

FROM Rugs      IMPORT
    (* TYPE *)          ARug,
    (* PROC *)          GetRug, PutRug;

FROM RunMenu   IMPORT   ExecuteMenu;

FROM RsrcCalc  IMPORT
    (* PROC *)          ComputeTaskNodeCosts;

FROM RsrcMod   IMPORT
    (* TYPE *)          AResourcePointer, AResourceType,
    (* VAR *)           ResourceTree;

FROM Schedule  IMPORT
    (* VAR *)           ScheduleSaved;

FROM Space     IMPORT   Available;

FROM SYSTEM          IMPORT
     (* TYPES *)        ADR, ADDRESS, SIZE, TSIZE;

FROM Timei      IMPORT
    (* CONST *)     MinDate, MaxDate,
    (* TYPE *)      ADate, ADuration;

FROM TimeXlate      IMPORT
    (* PROC *)          BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM TreeObjects IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder, ATreeNodeAttribute,
    (* PROC *)          ValidateTree, ValidateTreeNode;

FROM VaryAssgnment IMPORT
    (* TYPE *)          AVaryingAssgnList,
    (* PROC *)          GetVaryingAssgnListEntry;


(*<TRACE
FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;
FROM Tracer IMPORT PrintString, EndTrace;
FROM ResTrace IMPORT ConcatTaskID;
TRACE>*)




CONST
    HowOften = 32;              (* Interval for progress reports. *)
    HowOften2 = 8;              (* A shorter interval *)
    BoxShowsUpAt = 64;          (* Tasks before "Computing" box appears. *)
    ModuleNumber = 3800;        (* For GetMessage *)
    Zero         = 0.0;


    CheckForMultipleProjects   = TRUE;


TYPE

VAR
    Projects                 : CARDINAL;    (* Number of tasks at outer level. *)
    SequenceCounter          : CARDINAL;    (* Sequence numbers for Resources and Tasks. *)



    (*<TRACE
    TraceS : ARRAY [0..255] OF CHAR;
    TraceS2 : ARRAY [0..51] OF CHAR;
    TRACE>*)


     (*********************************************************)
     (*      Useful procedures.                               *)
     (*********************************************************)

PROCEDURE MaybeCountDown(phrase:CARDINAL; ToGo : CARDINAL);

BEGIN
    IF (TaskCount >= 100) THEN
        CountDown(phrase,TaskCount,ToGo);
    END;
END MaybeCountDown;







    (* InitOneResource --
       Create the residual availability list for a singe resource node.
       *)



PROCEDURE InitOneResource( VAR ResourceNode : ATreeNode;
                               Context      : ADDRESS    );
VAR
    Ok : POINTER TO BOOLEAN;
    Resource : AResourcePointer;
BEGIN
    Ok := Context;   (* Get pointer to return value. *)
    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );

        (* Put a sequence number into the Resource record. *)
    INC(SequenceCounter);     (* Global *)
    Resource^.SequenceNumber  := SequenceCounter;

    IF (Resource^.Type = Employable) THEN
        IF Ok^ THEN
            Ok^ := MakeAvailabilityIntoResidue(Resource,
                                               HonorDaysOff,
                                               Resource^.ResidueAvailProfile);
        END;
            (* For now, eliminate any late profile.  CPM doesn't
               use it, and levelling can allocate it if needed. *)
        DisposeResAvailabilities( Resource^.LateResidueAvailProfile );
    END;

END InitOneResource;



    (* InitializeResourceAvailabilities --
       Create the residual availability list for all resources.
    *)


PROCEDURE InitializeResourceAvailabilities():BOOLEAN;
VAR
    Ok : BOOLEAN;
BEGIN
    Ok := TRUE;
    SequenceCounter := 0;
    ResourceTree^.Methods^.TraverseTree(ResourceTree,ParentBeforeChild,
                                    9999, InitOneResource, ADR(Ok));
    IF (NOT Ok) THEN
        IssueWarning( OutOfMemory, NIL );
    END;
    RETURN Ok;
END InitializeResourceAvailabilities;








     (*  FINDLOOP -- Locate which tasks are part of a loop.  Mark them
                     by setting their status codes to "L".
                     *)

PROCEDURE FindLoop;
VAR
    s   : ARRAY [0..9] OF CHAR;
BEGIN
    SetString(s,"FINDLOOP");
    ExecuteMenu(s,s);
END FindLoop;



PROCEDURE SetTaskFlags( Task : ATaskPtr );
BEGIN
    WITH Task^ DO
            (* This setting decision is only until we move this logic to
               the task form, allowing the user to choose. *)
        TaskFlags := TaskFlags - ATaskFlagSet{ NoSoonerEnd,NoLaterEnd}; 

        IF (FrozenTask IN TaskFlags) THEN       (* AJL 9/1/88 *)
        ELSIF (SummaryFlag IN TempTaskFlags) THEN
                (* Until we allow user's to directly control the setting
                   of NoSoonerStart and NoLaterStart on summary tasks, we
                   must clear out these flags. *)
            TaskFlags   := TaskFlags - ATaskFlagSet{NoSoonerStart,NoLaterStart};
        ELSIF (StartStatus <> FutureS) THEN
            TaskFlags := TaskFlags + ATaskFlagSet{NoSoonerStart,NoLaterStart};
        END;
    END;
END SetTaskFlags;




PROCEDURE InitializeTask(     TaskNode : ATreeNode;
                              Task     : ATaskPtr   );
BEGIN

    (*<DEBUG*)
    CheckTaskValid( TaskNode );
    (*DEBUG>*)

        (* Note whether this task has assignments. *)
    IF (Task^.Plan.Assignments = AnExtHandle(NIL)) THEN
        TaskNode^.Methods^.SetAttributeBit(TaskNode,TempFlag1,FALSE);
    ELSE
        TaskNode^.Methods^.SetAttributeBit(TaskNode,TempFlag1,TRUE);
    END;


    SetTaskFlags( Task );

    WITH Task^ DO
        (*<TRACE
        SetString(TraceS,"InitializeTask ");  ConcatTaskID(TraceS,Task);
        PrintString(TraceS);
        TRACE>*)

        IF (NOT (FrozenTask IN TaskFlags)) THEN (* Don't change the dates of frozen tasks. *)

            TempTaskFlags := TempTaskFlags - ATempTaskFlagSet{ Visited,
                                                               TerminalFlag,
                                                               NoVacationsFlag}; 

                (* Linked tasks that have not been changed to other than
                   FixedDate already have their dates and varying
                   assignments set. *)
    
            IF (rollupstatus <> NotRollup) AND (fixation = FixedDate) THEN 
                INCL(TempTaskFlags,AlreadyScheduled); 
            ELSE
                EXCL(TempTaskFlags,AlreadyScheduled); 
            END;

                (* Remove all the task flags, except set the Loop flag.  If
                   all goes well, the loop flag, too, will be removed, and other
                   flags set if and as their conditions obtain. *)

            TaskStatusSet := ATaskStatusSet{Loop};        (* Look for loops *)


            IF (SummaryFlag IN TempTaskFlags) THEN
                    (*  We will compute a duration later.   For now, make it
                        a milestone.   This is important to many of the
                        calculations in other parts of the program.
                        Summary tasks must be ALAP so that they do not push
                        other (real) ALAP tasks earlier. *)
                duration := 0;
                DurationMethod := DurationDriven;
                Plan.Dates.EarlyStart := MinDate;
                fixation    := ALAP;
                StartStatus := FutureS;    (* May get changed by RestrictParents *)
            END;

                (* Set any restrictions of the scheduling date of this task.
                   The date that the user entered can restrict the lower bound
                   of the start date, or can set both the lower and upper
                   bounds. *)


            StartDateUpperBound := MaxDate;     (* In case we restrict w/ NoLaterStart. *)
            StartDateLowerBound := MinDate;

            IF (NoSoonerStart IN TaskFlags) THEN
                StartDateLowerBound := BigTimeToCalendarTime(UserEnteredStartDate);
                (*<TRACE  SetString(TraceS,"  NoSoonerStart, Set LB = ");  
                            TimeUtoS(Task^.StartDateLowerBound,TraceS2);  ConcatLS(TraceS,TraceS2);
                            PrintString(TraceS);
                TRACE>*)
            END;
            IF (NoLaterStart IN TaskFlags) THEN
                StartDateUpperBound := BigTimeToCalendarTime(UserEnteredStartDate);
                (*<TRACE  SetString(TraceS,"  NoLaterStart, Set UB = ");  
                            TimeUtoS(Task^.StartDateUpperBound,TraceS2);  ConcatLS(TraceS,TraceS2);
                            PrintString(TraceS);
                TRACE>*)
            END;

        END;
    END;

END InitializeTask;






    (* Procedures for creating phantom doubles of the summary tasks. *)



PROCEDURE Scan1ExtraWork(     TaskNode : ATreeNode;
                              Task     : ATaskPtr   );
VAR
    InitialChild    : ATreeNode;
    s               : ARRAY [0..51] OF CHAR;

BEGIN

    InitialChild := TaskNode^.Methods^.FirstChild(TaskNode);
    IF (InitialChild <> NIL) THEN  (* A Summary Task *)
        INCL(Task^.TempTaskFlags,SummaryFlag);
    ELSE
        EXCL(Task^.TempTaskFlags,SummaryFlag);
    END;

    InitializeTask(TaskNode,Task);


    WITH Task^ DO
            (* Put a sequence number into the Task record. *)
        INC(SequenceCounter);     (* Global *)
        SequenceNumber  := SequenceCounter;

        (*<TRACE
        SetString(TraceS,"Init task: ");  ConcatTaskID(TraceS,Task);
        ConcatS(TraceS,", SequenceNumber = "); CtoS(SequenceNumber,TraceS2);
        ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        TRACE>*)

        IF (NOT (FrozenTask IN TaskFlags)) THEN (* Don't change the dates of frozen tasks. *)
            IF (NeedsRecalculate IN TaskStatusSet) THEN
                ComputeTaskNodeCosts( TaskNode );
            END;

            IF (rollupstatus = RollupNotLoaded) THEN
                    (* Set the flag which communicates the results of this
                       discovery to other procedures within this module. *)
                NeedLinkedScheduleRollin := TRUE;   (* Declared statically inside this module. *)
            END;
        END;

        IF (BaseLineExists IN TaskFlags) THEN
            SomeBaselineExists := TRUE;
        END;
    END;

        (* We only invoke the slack localizer for multiple independent
           projects if all tasks at the outermost level are summary
           tasks.  A mixture of summary and detail treats the schedule
           as one large project. *)

    IF (TaskNode^.Methods^.IndentationLevel(TaskNode) = 0) THEN
       INC(Projects);
       IF (TaskNode^.Methods^.GetSubtree(TaskNode) = NIL) THEN
           AllLevel0TasksAreSummary := FALSE;
       ELSE
           SomeLevel0TaskIsSummary  := TRUE;
       END;
    END;

        (* If there are many tasks, warn the user that we will be taking
           a while. *)

    INC(TaskCount);
    IF (NOT BoxShowing) THEN
        IF (TaskCount > BoxShowsUpAt ) THEN
            GetMessage(ModuleNumber+11,s);    (*   "Computing  " *)
            BoxHandle := ProgressBox(s);
            BoxShowing := (BoxHandle <> ABoxHandle(NIL));
        END;
    END;

END Scan1ExtraWork;








TYPE
    AFingerprintContext = RECORD
                              ResourceSet  : BITSET;
                              HasVacations : BOOLEAN;
                          END;
    AFingerprintContextPointer = POINTER TO AFingerprintContext;




    (* MakeFingerprint -- Include the ID number of the resource into
                          the context set.
                          See if the assigned resource allows vacation
                          calendars. 
                          *)


PROCEDURE MakeFingerprint( VAR Assignment : AnAssignmentRecord;
                               Ptr        : ADDRESS ) : BOOLEAN;
VAR
    Context         : AFingerprintContextPointer;
    Resource        : AResourcePointer;
    i               : CARDINAL;
BEGIN


    Context := AFingerprintContextPointer(Ptr);
    Resource := Assignment.Resource;
    IF (Resource^.Type = Employable) THEN
        i := Resource^.ID;
        INCL( Context^.ResourceSet, i MOD 16 );
        IF (Resource^.Calendar <> AResourceCalendarPointer(NIL)) THEN
            Context^.HasVacations := TRUE;
        END;
    END;

    RETURN TRUE;

END MakeFingerprint;
















    (* TaskNeedsLimit returns TRUE if there appears to be nothing to stop
       this task from being scheduled at the beginning of time. *)

PROCEDURE TaskNeedsLimit( TaskHandle : AnExtHandle): BOOLEAN;
VAR
    edge           :  AnEdgePtr;
    Task           :  ATaskPtr;
    Collection     :  ARRAY [0..50] OF AnExtHandle;
    i              :  CARDINAL;
BEGIN

    i := 0;

        (* If a task is an ASAP task, then we need to fix its date if it
           has no antecedants, or has none whose dates are set.  Specifically,
           we need to worry about the situation of an ASAP whose only
           antecedants are summary tasks.  Because summaries do not have limits (see
           above) but the cpm calculations treat them as ASAP tasks in the
           main, summary tasks have no limit but no definite start date.  They
           are a problem that will require their successor ASAPs to need
           a limit.

           An ASAP predecessor acts as a limit because somewhere along the
           chain, one of the ASAP predecessors will have a limit.   Similar
           reasoning applies to ALAP tasks, which, for our purposes, are
           like ASAP ones.
        *)

    IF (LockObject(TaskHandle,Task) <> TSIZE(ATask)) THEN FatalError(); END;

        (*<TRACE
        SetLengthOf(TraceS2,0); ConcatTaskID(TraceS2,Task);
        TRACE>*)

        (* ALAP tasks don't generally need to be restricted in how EARLY
           they start.   ALAP and Summary tasks don't need to be restricted,
           but, because they float around, they don't save other tasks from
           the need to be restricted.
           Anything with NoSoonerStart is already limited, so doesn't 
           need an additional limit. *)

    IF (NoSoonerStart IN Task^.TaskFlags) OR
       (SummaryFlag IN Task^.TempTaskFlags) OR
       (Task^.fixation = ALAP) THEN
        ReleaseUnchangedObject(TaskHandle);
        RETURN FALSE;
    END;

    LOOP
            (*  add all antecedants to the queue to be checked. *)
        edge := Task^.antetasks;
        WHILE (edge <> NIL) AND (i < HIGH(Collection)) DO
            IF (i <= HIGH(Collection)) THEN
                Collection[i] := AnExtHandle(edge^.headtask^.Methods^.GetDataObject(edge^.headtask));
                INC(i);
            END;
            edge := edge^.taillink
        END;

        ReleaseUnchangedObject(TaskHandle);   (*<KILL  Task := NIL; KILL>*)

            (* If the Queue is empty, we did not find a limiting task. *)

        IF ( i = 0 ) THEN
            (*<TRACE
            SetString(TraceS,"Needs Limit: ");  ConcatLS(TraceS,TraceS2);  ConcatS(TraceS," to ");
            PrintString(TraceS);
            TRACE>*)

            RETURN TRUE;
        END;

            (* Dequeue a task. *)

        DEC(i);
        TaskHandle := Collection[i];
        IF (LockObject(TaskHandle,Task) <> TSIZE(ATask)) THEN FatalError(); END;

            (* It it is not a summary, or an ALAP, then it must either be 
               limited or have an antecedant that is. *)


            (* It it is not a summary, or an ALAP, then it must either be 
               limited or have an antecedant that is. *)

        IF (NOT (NoSoonerStart IN Task^.TaskFlags)) AND
           ((SummaryFlag IN Task^.TempTaskFlags) OR (Task^.fixation = ALAP))
            THEN
                (* Keep looping and searching. *)
        ELSE
            ReleaseUnchangedObject(TaskHandle);
            (*<TRACE
            SetString(TraceS,"Doesn't need Limit: ");  ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
            TRACE>*)
            RETURN FALSE;
        END;

    END;


END TaskNeedsLimit;


    (* Restrict the task's parents so that they are not allowed to
       start later than the (child) task.   This is to fix a problem that
       could occur if a summary task has a started (or done) child, but
       also has a dependency to its start date requiring it to start
       later than that child.  We do not want the dependency to override
       the start date of the child, so we restrict the upper bound start
       date.  (AJL 21-Sep-89)  See the SUMMDONE schedule.
    *)

PROCEDURE RestrictParentsDates ( TaskNode : ATreeNode;
                                 ChildStartDate : ADate;
                                 ChildStartStatus : AStartStatus );
VAR
    Task : ATaskPtr;

BEGIN
    (*<TRACE
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    SetString(TraceS,"Restrict on behalf of ");  ConcatTaskID(TraceS,Task);
    ConcatS(TraceS," to upper bound of ");
    TimeUtoS(ChildStartDate,TraceS2);  ConcatLS(TraceS,TraceS2);
    CASE ChildStartStatus OF 
        FutureS  : ConcatS(TraceS,",  Future");
      | StartedS : ConcatS(TraceS,",  Started");
      | DoneS    : ConcatS(TraceS,",  Done");
    END;
    PrintString(TraceS);
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
    Task := NIL;
    TRACE>*)


        (* Walk up the tree, restricting the start date of each parent.
        *)

    LOOP
        TaskNode := TaskNode^.Methods^.Parent(TaskNode);
        IF (TaskNode = NIL) THEN
    EXIT;
        END;


        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

            (* Make this milestone happen at the start date of the earliest
               child task. *)

        WITH Task^ DO
            IF (ChildStartDate < StartDateUpperBound) THEN
                StartDateUpperBound := ChildStartDate;
            END;
            IF (ChildStartStatus <> FutureS) THEN
                StartStatus := StartedS;   (* Detect started summaries. *)
            END;
        END;

        (*<TRACE
        SetString(TraceS,"Restrict ");  ConcatTaskID(TraceS,Task);
        ConcatS(TraceS," to start no later than ");
        TimeUtoS(ChildStartDate,TraceS2);  ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        SetString(TraceS,"  LB = ");
        TimeUtoS(Task^.StartDateLowerBound,TraceS2);  ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS,", UB = ");
        TimeUtoS(Task^.StartDateUpperBound,TraceS2);  ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS,", SS = ");
        CASE Task^.StartStatus OF 
            FutureS  : ConcatS(TraceS,"Future");
          | StartedS : ConcatS(TraceS,"Started");
          | DoneS    : ConcatS(TraceS,"Done");
        END;
        PrintString(TraceS);
        TRACE>*)

        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
                           (*<KILL Task := NIL; KILL>*)
    END;
END RestrictParentsDates;






PROCEDURE CountAntecedants( Task : ATaskPtr ) : CARDINAL;
VAR
    i    :  CARDINAL;
    Edge : AnEdgePtr;
BEGIN
    i := 0;
    Edge := Task^.antetasks;

    WHILE (Edge <> NIL) DO
        CheckEdgeValid(Edge);
        INC(i);
        Edge := Edge^.taillink
    END;
    RETURN i;
END CountAntecedants;



    (* FingerprintResources -- Build a set in the task record indicating
                               which resources might be working on the 
                               task, and a flag indicating if any of them
                               have vacations. *)


PROCEDURE FingerprintResources( Task : ATaskPtr );
VAR
    FingerprintContext     : AFingerprintContext;
BEGIN
    WITH Task^ DO

        (* Fingerprint the task to help us quickly decide if it uses
           a given resource or not.  *)

        FingerprintContext.ResourceSet := {};
        FingerprintContext.HasVacations := FALSE;
        ForEachAssignment( Task^.Plan.Assignments, MakeFingerprint,
                           ADR(FingerprintContext) );
        Fingerprint := FingerprintContext.ResourceSet;
        IF (NOT HonorDaysOff) OR
           (NOT FingerprintContext.HasVacations) THEN
            INCL(TempTaskFlags,NoVacationsFlag); 
            (*<TRACE
                SetString(TraceS," ");  ConcatTaskID(TraceS,Task);
                ConcatS(TraceS," has no vacations.");
                PrintString(TraceS);
            TRACE>*)

        END;
    END;
END FingerprintResources;









PROCEDURE FindInitialStartDate( TaskHandle : AnExtHandle;
                                Task       : ATaskPtr );
BEGIN
    WITH Task^ DO

        IF (AlreadyScheduled IN TempTaskFlags) THEN
            (* Linked task.  Already contains a good early start and end. *)

        ELSIF (FrozenTask IN TaskFlags) THEN         (* frozen task *)
            RestrictParentsDates(ATreeNode(WorkSpace), Plan.Dates.EarlyStart,
                                 StartStatus );
        ELSE


                (*  Pick an earliest starting date.  If there will be
                    some limiting factor such as a fixed date or an
                    antecedent, do not limit the earliest start.
                    
                    If the task has an UpperBound on the start date, do not
                    exceed it.

                    *)

            (*<TRACE
            IF (StartDateLowerBound > MinDate) THEN
                SetString(TraceS,"FindInitialStartDate: ");  ConcatTaskID(TraceS,Task);
                ConcatS(TraceS," has a lower bound, ");
                TimeUtoS(StartDateLowerBound,TraceS2);  ConcatLS(TraceS,TraceS2);
                PrintString(TraceS);
            END;
            IF (StartDateUpperBound < MaxDate) THEN
                SetString(TraceS,"FindInitialStartDate: ");  ConcatTaskID(TraceS,Task);
                ConcatS(TraceS," has an upper bound, ");
                TimeUtoS(StartDateUpperBound,TraceS2);  ConcatLS(TraceS,TraceS2);
                PrintString(TraceS);
            END;
            IF (StartDateUpperBound < StartDateLowerBound) THEN
                SetString(TraceS,"*** WHOA!: UpperBound < Lower??!!");
                PrintString(TraceS);
            END;
            TRACE>*)

            IF (StartDateUpperBound < StartDateLowerBound) THEN
                StartDateLowerBound := StartDateUpperBound;
            END;

            Plan.Dates.EarlyStart := StartDateLowerBound;
            IF (NoLaterStart IN TaskFlags) THEN
                RestrictParentsDates(ATreeNode(WorkSpace), StartDateUpperBound,
                                     StartStatus );
            END;


                (*  Only future tasks need to have start date limits
                    computed.  Started and Done tasks have the date
                    entered in the FixedStart field.
                    We do not need an early start limit if we are a
                    Summary.

                    But we do if we we don't have any antecedants, or
                    those that we have are not themselves limited.
                *)

            IF (NOT (SummaryFlag IN TempTaskFlags)) AND 
               (StartStatus = FutureS) THEN

                    (*<TRACE
                    SetString(TraceS,"Test task type: ");  ConcatTaskID(TraceS,Task);
                    ConcatS(TraceS," is not Summary ");
                    PrintString(TraceS);
                    TRACE>*)

                    (* Check whether or not this task is limited. *)

                IF   (MoveFutureTasks OR ( DeferAlarms IN TaskFlags))
                    OR TaskNeedsLimit(TaskHandle)
                    THEN
                             (* Put it in the future, or at the UpperBound. *)
                        IF (StartDateLowerBound < AsOfDate) THEN
                            IF (AsOfDate < StartDateUpperBound) THEN
                                Plan.Dates.EarlyStart := AsOfDate;
                            ELSE
                                Plan.Dates.EarlyStart := StartDateUpperBound;
                            END;
                        END;
                END;
            END;


            (*<TRACE
            SetString(TraceS,"FindInitialStartDate: ");  ConcatTaskID(TraceS,Task);
            ConcatS(TraceS," is ");
            TimeUtoS(Plan.Dates.EarlyStart,TraceS2);  ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
            TRACE>*)


        END;
    END;
END FindInitialStartDate;






PROCEDURE LocateInitialTasks(    PrivateTaskList : AnExtHandle;
                                 ReadyList       : AnExtHandle  );
VAR
    TaskHandle, NextTaskHandle : AnExtHandle;
    Task : ATaskPtr;
    TaskNode : ATreeNode;
    NumberOfAntecedants : CARDINAL;
BEGIN


        (* Prepare to count the number of tasks over again.  Some earlier
           processes may have added new nodes, such as phantoms or
           subproject enders.
        *)

    TaskCount := 0;

        (*  Run through all the tasks.  Set the early start dates.
            If the task has no antecedants, then add it to the queue
            in ReadyList. *)

    IF (LockObject(PrivateTaskList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(PrivateTaskList);     (*<KILL  Task := NIL; KILL>*)

    WHILE (NOT ObjectsAreSame(TaskHandle,PrivateTaskList)) DO

        INC(TaskCount);                    (* Count number of task nodes. *)

        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;

            (* Mark each task to indicate which resources might be
               working on it. *)

        FingerprintResources( Task );

            (* Put into the task dates record a starting value for the
               start date. *)

        FindInitialStartDate( TaskHandle, Task );

            (* Count the number of antecedant tasks to this one. *)

        NumberOfAntecedants := CountAntecedants( Task );
        WITH Task^ DO
           count  := NumberOfAntecedants;
           count2 := NumberOfAntecedants;
           NextTaskHandle := Nextlink;             (* Find the next task. *)
        END;


        ReleaseObject(TaskHandle);   (* Release before checking. *)     (*<KILL Task := NIL; KILL>*)

            (*  If this task has no antecedants, add it to the queue of
                tasks that are ready to be scheduled.  *)

        IF (NumberOfAntecedants = 0) THEN                  (* Task^.count *)
            DeList(TaskHandle);
            AddBefore(ReadyList,TaskHandle);
        END;

        TaskHandle := NextTaskHandle;
    END;
END LocateInitialTasks;







PROCEDURE ForwardPass(     PrivateTaskList : AnExtHandle;
                       VAR EndDateOfSchedule : ADate );
VAR
    ReadyList                          : AnExtHandle;
    currtask, descendant               : ATaskPtr;
    currtaskHandle, descendantHandle   : AnExtHandle;
    DescendantNode                     :  ATreeNode;
    ToGo, TopoSequenceNumber, i, k  : CARDINAL;
    edge: AnEdgePtr;
    EdgeDate  : ADate;      (* Used for processing partial joins. *)
    S0        : ARRAY [0..0] OF CHAR;
BEGIN
       (*<TRACE
    SetString(TraceS,"Procedure ForwardPass");    SetString(TraceS2,"TLCPM");
    PrintString(TraceS);

        (* Erase any previous progress message, such as the one about
           analyzing multiple projects.  We need to erase it since we 
           only put up our own progress messages if there are a lot of 
           tasks. *)
    S0 := "";
    Message(S0);

       TRACE>*)

    IF NOT ListInit(ReadyList) THEN
        IssueWarning(OutOfMemory,NIL);
        SchedulingAbandoned := TRUE;
        RETURN;
    END;

        (* Build the queue of tasks with no predecessors.  Also,
           initialize some information about those tasks. *)


    LocateInitialTasks( PrivateTaskList, ReadyList );

        (* Main part of the forward pass. *)

    ToGo := TaskCount;
    TopoSequenceNumber := 1;

       (*<TRACE
    SetString(TraceS,"Main part of Forward pass:  (");
    CtoS(ToGo,TraceS2); ConcatLS(TraceS,TraceS2);  ConcatS(TraceS," tasks).");
    PrintString(TraceS);
       TRACE>*)


    i := 0;
    WHILE (i < TaskCount) AND (NOT SchedulingAbandoned) DO
        INC(i);

        IF (LockObject(ReadyList,currtask)= 0) THEN FatalError(); END;
        currtaskHandle := currtask^.Nextlink;
        ReleaseUnchangedObject(ReadyList);              (*<KILL currtask := NIL; KILL>*)

        IF (ObjectsAreSame(currtaskHandle,ReadyList)) THEN
                (* LOOP DETECTED! AAAHHH OOOOO GAAAAH!! *)
            DiscardExtObject(ReadyList);
            FindLoop;
            SchedulingAbandoned := TRUE;
            RETURN;
        END;

            (* Dequeue a task.  This takes the task off of the ReadyList. *)

        DeList(currtaskHandle);

            (*  Add the popped task to the rebuilt list of tasks in
                forward order. *)

        AddBefore(PrivateTaskList,currtaskHandle);

            (*  Mark the task's status as ' ' to mean good, not in
                any loop.

                Decide the earliest start date for this task, the
                scheduled end date, the earliest end, and the latest
                end.  These calculations are based on on the task's
                start status,
                fixation and scheduled start date, we have not yet
                taken precedence constraints into account.

                For tasks with a fixed date, the scheduled start date
                is already determined.  See that it is feasible,

                "Started" tasks may have a known start but unknown ending
                date.

                Set the late end date for all tasks to a very large
                number for now.  During the reverse pass it will be
                fixed. *)

        IF (LockObject(currtaskHandle,currtask)= 0) THEN FatalError(); END;

        (*<TRACE
        SetString(TraceS," ");  ConcatTaskID(TraceS,currtask);
        PrintString(TraceS);
        TRACE>*)


        WITH currtask^ DO
            TopoOrder        := TopoSequenceNumber;  (* Record topological order. *)
            INC(TopoSequenceNumber);

            IF (NOT (FrozenTask IN TaskFlags)) THEN

                     (* Summary tasks that are not started may need to 
                        be forced to the right of the today line.  See the
                        RestrictParentDates procedure for setting of the
                        StartStatus.  See PROB576.  *)

                 IF (SummaryFlag IN TempTaskFlags) THEN

                     IF (StartStatus <> FutureS) THEN

                             (* Summary tasks which are actually started must
                                start at the start date of the earliest started child. *)
                         StartDateLowerBound := StartDateUpperBound;

                         (*<TRACE
                         SetString(TraceS," Set lower bound of summary ");  ConcatTaskID(TraceS,currtask);
                         ConcatS(TraceS," to UB, ");
                         TimeUtoS(StartDateLowerBound,TraceS2);  ConcatLS(TraceS,TraceS2);
                         PrintString(TraceS);
                         TRACE>*)

                         (* Future summary tasks: *)
                     ELSIF (MoveFutureTasks) THEN
                             (* Check that there is not some conflicting upper bound. *)
                         IF (StartDateUpperBound > AsOfDate) THEN
                             IF (StartDateLowerBound < AsOfDate) THEN
                                 StartDateLowerBound := AsOfDate;
                             END;
                         ELSE    (* Make it as large as we can. *)
                             IF (StartDateLowerBound < StartDateUpperBound) THEN
                                 StartDateLowerBound := StartDateUpperBound;
                             END;
                         END;
                     END;
                 END;

                    (* Schedule the task.  Compute its end date and the
                       varying assignment profiles.   There is one circumstance 
                       when we don't compute those dates: when the dates have 
                       already been established by linkage (rollup) to  
                       another schedule. *) 
                
                IF (NOT (AlreadyScheduled IN TempTaskFlags)) THEN 
                    ActivateTask( currtask ); 
                END;

                (*<TRACE
                SetString(TraceS,"    Activate ");  ConcatTaskID(TraceS,currtask); ConcatS(TraceS," at ES =");
                TimeUtoS(Plan.Dates.EarlyStart,TraceS2);  ConcatLS(TraceS,TraceS2); ConcatS(TraceS," through ");
                TimeUtoS(Plan.Dates.EarlyEnd,TraceS2);  ConcatLS(TraceS,TraceS2);
                PrintString(TraceS);
                IF (AlreadyScheduled IN TempTaskFlags) THEN
                    SetString(TraceS,"        (AlreadyScheduled)");
                    PrintString(TraceS);
                END;
                SetString(TraceS,"        LB = ");
                TimeUtoS(StartDateLowerBound,TraceS2);  ConcatLS(TraceS,TraceS2);
                ConcatS(TraceS,", UB = ");
                TimeUtoS(StartDateUpperBound,TraceS2);  ConcatLS(TraceS,TraceS2);
                PrintString(TraceS);
                TRACE>*)

                    (* Fill in other dates, for now.  This may be overwritten
                       later. *)
                TaskStatusSet := ATaskStatusSet({});

                WITH Plan.Dates DO
                        (* Find the latest end date of any task. *)
                    IF (EarlyEnd > EndDateOfSchedule) THEN
                        EndDateOfSchedule := EarlyEnd;
                    END;
                        (* Prevent the reverse pass from scheduling any ALAP
                           tasks sooner than their early start dates. *)
                    StartDateLowerBound := EarlyStart;
                END;


            END;
        END;


            (* Examine all descendant tasks of the current task.
               For each, update the early start date and decrease the
               count field, when this reaches zero, each of the
               descendant's antecedants has examined him and updated
               his Plan.Dates.EarlyStart.  If so, add him to the queue.
            *)

        edge := currtask^.desctasks;
        WHILE (edge <> NIL) DO
            CheckEdgeValid(edge);
            DescendantNode := edge^.tailtask;

            CheckTaskValid(DescendantNode);
            descendantHandle := AnExtHandle(DescendantNode^.Methods^.GetDataObject(
                              DescendantNode));
            IF (LockObject(descendantHandle,descendant)=0) THEN FatalError(); END;

                (*  Compute the net effect of the partial join, if any
                    effect at all.  Store the net effect into edge^.Delta.
                    This must be done AFTER any Span tasks have been
                    temporarily turned into milestones (which is done
                    in the PrePass procedure).
                    
                    The ComputeEdgeDelta procedure needs to have a
                    valid duration in EarlyEnd-EarlyStart.  Set this
                    to the shortest duration possible for this task.
                    Since the task might become longer (delaying its 
                    end date, this is conservative, computing a start
                    date that might be earlier than necessary.)
                    
                    However, if the task has already been scheduled by some
                    other process of calculation (such as linking to another
                    schedule) then we don't update its dates.
                 *)

            IF (NOT (AlreadyScheduled IN descendant^.TempTaskFlags)) THEN 
                WITH descendant^.Plan.Dates DO
                    IF (EarlyStart <= MaxDate - descendant^.duration) THEN
                        EarlyEnd := EarlyStart + descendant^.duration;
                    ELSE
                        EarlyEnd := MaxDate;
                    END;
                END;
            END;

            EdgeDate := ComputeEdgeDelta( currtask, descendant, edge );

                (* Look at the descendant task.  Update its start date
                   to be no earlier than the date computed by the current
                   task and its dependency. *)

            WITH descendant^ DO
                IF (NOT (AlreadyScheduled IN TempTaskFlags))
                   AND 
                   (Plan.Dates.EarlyStart < EdgeDate) THEN
                        (* Don't change the dates of frozen tasks. *)
                    IF (NOT (FrozenTask IN TaskFlags)) THEN
                        Plan.Dates.EarlyStart := EdgeDate;
                        (*<TRACE
                        SetString(TraceS,"    Update ES of ");
                        ConcatTaskID(TraceS,descendant); ConcatS(TraceS," to = ");
                        TimeUtoS(EdgeDate,TraceS2);  ConcatLS(TraceS,TraceS2);
                        PrintString(TraceS);
                        TRACE>*)
                    END;
                END;
                DEC(count);
                k := count;    (* Store the count while handle is locked. *)
            END;

            ReleaseObject(descendantHandle);       (*<KILL descendant := NIL; KILL>*)

                (* If this edge to the descendant task is the last to
                   be visited, then k now is zero.  Add the task to the
                   ReadyList queue. *)

            IF (k = 0) THEN  (* k = descendant^.count *)
                DeList(descendantHandle);
                AddBefore(ReadyList,descendantHandle);
            END;
            edge := edge^.headlink
        END;

        ReleaseObject(currtaskHandle);             (*<KILL currtask := NIL; KILL>*)

        DEC(ToGo);
        IF ((ToGo MOD HowOften) = 0) THEN
            MaybeCountDown(ModuleNumber+3,ToGo); (* 'Finding early start dates, ' *)
        END;
    END;

        (* If we bailed out early, consolidate the lists. *)

    IF (SchedulingAbandoned) THEN
        MoveList(PrivateTaskList, ReadyList);
    END;


        (*  Check that the ready queue is empty.   Get rid of it. *)

    IF (LockObject(ReadyList,currtask)= 0) THEN FatalError(); END;
    currtaskHandle := currtask^.Nextlink;
    ReleaseUnchangedObject(ReadyList);              (*<KILL currtask := NIL; KILL>*)

    IF (ObjectsAreSame(currtaskHandle,ReadyList)) THEN
        DiscardExtObject(ReadyList);
    ELSE
        FatalError;
    END;

END ForwardPass;





(* ------------ OptimisticFindLatestStartDate -----------------------------

   Given a maximum end date, find the latest
   feasible start date for the task (i.e., whose end date is <=
   max end date). If such a date can be found, sets FoundADate to
   TRUE and DateFound to that date.
   Otherwise, sets FoundADate to FALSE.

   Feasibility ignores resource-level constraints.

   Preconditions: the  EarlyStart and EarlyEnd dates must be valid.

*)

PROCEDURE OptimisticFindLatestStartDate (Task              : ATaskPtr;
                                         MaxEndDate        : ADate;
                                     VAR FoundADate        : BOOLEAN;
                                     VAR StartDate         : ADate);
VAR
    TaskEndDate : ADate; (* this is computed by FindLatestStartDate but not
                      used by us *)
BEGIN
        (* Shortcut a few simple cases, such as an end date with a 
           known, corresponding start date, or a task
           without possibility of being affected by vacations.
           *)

    FoundADate := FALSE;

    IF  (Task^.StartStatus = FutureS) THEN  
        WITH Task^.Plan.Dates DO
            IF (MaxEndDate = EarlyEnd) THEN
                FoundADate := TRUE;
                StartDate := EarlyStart;
            ELSIF (NoVacationsFlag IN Task^.TempTaskFlags) OR
                  (
                   (Task^.DurationMethod = DurationDriven) AND
                   (Task^.SplittingRule = Split) 
                  ) THEN
                FoundADate := TRUE;
                    (* Duration could not have changed. *)
                StartDate   := MaxEndDate - (EarlyEnd - EarlyStart);
            END;
        END;
    END;

    IF (NOT FoundADate) THEN
        FindLatestStartDate(Task, MaxEndDate, TRUE (*do we allow overbook*),
                            FALSE (* do we use late availabilities *),    
                            FoundADate, StartDate, TaskEndDate);
    END;
END OptimisticFindLatestStartDate;




    (* ConstrainStartDate -- When levelling within slack, determine
                             the latest date that the task (or its
                             remaining effort) can be scheduled and 
                             still meet its late total end date from 
                             CPM. *)



PROCEDURE ConstrainStartDate( Task : ATaskPtr );
VAR
    LatestStart,
    TaskEndDate : ADate;
    FoundADate  : BOOLEAN;
BEGIN
    WITH Task^ DO
        LatestStart := Plan.Dates.LateTotalStart;
            (* When a task has a varying duration (is effort driven)
               and is started (some of the effort is spent) then we
               need to compute a restriction on the start date of the
               remaining portion that may be later than the start
               date of the whole task.  This is because only the 
               shorter amount now needs to be done. *)
        IF (StartStatus <> FutureS) AND (DurationMethod <> DurationDriven) THEN
             FindLatestStartDate (Task,
                                  Plan.Dates.LateTotalEnd  (* MaxEndDate *),
                                  TRUE         (* DoWeAllowOverbookings  *),
                                  FALSE     (* DoWeUseLateAvailabilities *),
                                  FoundADate,
                                  LatestStart,
                                  TaskEndDate);
            (*<TRACE  SetString(TraceS,"    Find a latest start date = ");
                        TimeUtoS(LatestStart,TraceS2);  ConcatLS(TraceS,TraceS2);
                        PrintString(TraceS);
            TRACE>*)
            IF (NOT FoundADate) THEN
                IssueWarning( BeforeStartOfCalendar, Task );
            END;
        END;

        IF (LatestStart < StartDateUpperBound) THEN
            StartDateUpperBound := LatestStart;
            IF (StartDateUpperBound < StartDateLowerBound) THEN
                StartDateUpperBound := StartDateLowerBound;
                IssueWarning(ConflictBoundsSlack,Task);
            END;
        END;
    END;
END ConstrainStartDate;




PROCEDURE ReversePass( PrivateTaskList   : AnExtHandle;
                       EndDateOfSchedule : ADate );
VAR
    Task, Descendant                   : ATaskPtr;
    TaskHandle, DescendantHandle       : AnExtHandle;
    nextHandle                         : AnExtHandle;
    DescendantNode                     : ATreeNode;
    edge                               : AnEdgePtr;
    EdgeDate  : ADate;      (* Used for processing partial joins. *)
    LevellingStartDate  : ADate;  (* Earliest date for levelling to 
                                     schedule the task. *)
    TempDate, 
    FreeEnd, TotalEnd : ADate;
    ToGo : CARDINAL;
    FoundDate : BOOLEAN;
BEGIN
       (*<TRACE
    SetString(TraceS,"******* Procedure ReversePass ********");    SetString(TraceS2,"TLCPM");
    PrintString(TraceS);
       TRACE>*)

    ToGo := TaskCount;

    (*  Run through the tasks in reverse order, rebuilding
        the forward thread and calculating the lateenddates.

        At this point, EndDateOfSchedule is the date of the end of the
        project.
        It is the latest date among the set of ending dates for all
        tasks, where each ending date represents the earliest possible
        ending date for that task.

        During this pass we will calculate the TotalLate dates and the
        FreeLate dates.

        TotalLateEnd   = Min-successors(TotalLateStart).
        TotalLateStart = Latest start date whose end date is <=
                                TotalLateEnd
        FreeLateEnd    =  Min-successors(EarlyStart).
        FreeLateStart  = Latest start date whose end date is <=
                                FreeLateEnd
    *)

    IF (LockObject(PrivateTaskList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Prevlink;
    ReleaseUnchangedObject(PrivateTaskList);             (*<KILL Task := NIL; KILL>*)

    WHILE (NOT ObjectsAreSame(TaskHandle,PrivateTaskList))
          AND
          (NOT SchedulingAbandoned) DO


        IF (BreakRequested()) THEN
            SchedulingAbandoned := TRUE;
        END;


        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;

           (*<TRACE
        SetLengthOf(TraceS,0);  ConcatTaskID(TraceS,Task);
        PrintString(TraceS);
           TRACE>*)


            (* Tasks with no successors will be set to end no later
               than the end date of all other tasks.   Tasks such as
               terminal nodes and tasks whose slack is suppressed will
               already have and end date < this. *)

            (* Terminal nodes are the ends of subgraphs, and they do
               not have any slack.   Neither do tasks that have been requested
               to suppress slack.
               
               ALAP tasks end up with no slack, but through a different process.
               Rather than just calling their slack zero, we compute their slack,
               then adjust their start dates so that they end exactly at the end
               of their free slack. 
               *)

        IF (TerminalFlag IN Task^.TempTaskFlags) OR
           (Task^.StartStatus = DoneS) OR
           ((ForceCritical IN Task^.TaskFlags) AND (Task^.fixation <> ALAP)) THEN

            FreeEnd := Task^.Plan.Dates.EarlyEnd;
            (*<TRACE
            IF (TerminalFlag IN Task^.TempTaskFlags) THEN
                SetString(TraceS,"TerminalFlag: ");
            ELSIF (Task^.StartStatus = DoneS) THEN
                SetString(TraceS,"Task StartStatus = DoneS: ");
            ELSE
                SetString(TraceS,"ForceCritical Flag: ");
            END;
            ConcatTaskID(TraceS,Task);
            PrintString(TraceS);
            TRACE>*)
        ELSE
            FreeEnd := EndDateOfSchedule;
        END;
        TotalEnd := FreeEnd;

        (*<TRACE
        SetString(TraceS,"    initially, FreeEnd = ");
        TimeUtoS(FreeEnd,TraceS2);  ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS,",    ES = ");
        TimeUtoS(Task^.Plan.Dates.EarlyStart,TraceS2);  ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        TRACE>*)

            (* For the benefit of resource levelling, store the
               early start into the count field.   And, while we are here,
               note all partial dependencies.  *)

        LevellingStartDate := Task^.Plan.Dates.EarlyStart;

        (* Examine the dependent tasks of this one, marking any partial
           dependencies, including any that have arisen because tasks were
           scheduled earlier than the dependencies were supposed to allow,
           and accummulating the total and free end dates. *)

        edge := Task^.desctasks;
        WHILE (edge <> NIL) DO
            DescendantNode := edge^.tailtask;
            CheckTaskValid(DescendantNode);
            Descendant := DescendantNode^.Methods^.LockFlexStorDataObject(
                              DescendantNode);
                (*  Find the free late end date, which is the minimum of
                    the early start dates for all successors.
                    Adjust the EdgeDates for the effect of partial joins.
                    Since it is the antecedant task that is being adjusted in
                    terms of the descendant, the adjustments are the negative
                    of the forward pass. *)
                (*$R-*) (*$T-*)   (* Don't want no range checking. *)
            EdgeDate := Descendant^.Plan.Dates.EarlyStart; DEC(EdgeDate,edge^.Delta);
                (*$R=*) (*$T=*)   (* Don't want no range checking. *)
            IF (EdgeDate < FreeEnd) THEN
                FreeEnd := EdgeDate;
            END;
            (*<TRACE
            SetString(TraceS,"    Descendant ");  ConcatTaskID(TraceS,Descendant);
            ConcatS(TraceS,", Free EdgeDate = ");
            TimeUtoS(EdgeDate,TraceS2);  ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
            TRACE>*)


                (*  Ok, now find the total late end date, which is the minimum of
                    the total late start dates for all successors.
                *)
                (*$R-*) (*$T-*)   (* Don't want no range checking. *)
            EdgeDate := Descendant^.Plan.Dates.LateTotalStart; DEC(EdgeDate,edge^.Delta);
                (*$R=*) (*$T=*)   (* Don't want no range checking. *)
            IF (EdgeDate < TotalEnd) THEN
                TotalEnd := EdgeDate;
            END;
            (*<TRACE
            SetString(TraceS,"        Total EdgeDate = ");
            TimeUtoS(EdgeDate,TraceS2);  ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
            TRACE>*)

                (* If this is a partial dependency, flag the tasks.
                   Any offset makes it partial, as does any dependency 
                   from the start or to the end of a task. *)
                (* Unlock the descendent task. *)

            IF (edge^.Delta <> 0)
               OR (edge^.FromOffset.Start)
               OR (NOT edge^.ToOffset.Start)  THEN

                INCL(Task^.TaskStatusSet,PartialJoinPrior);
                INCL(Descendant^.TaskStatusSet,PartialJoinAfter);
                DescendantNode^.Methods^.UnlockFlexStorDataObject( DescendantNode);
            ELSE
                DescendantNode^.Methods^.UnlockUnchangedDataObject( DescendantNode);
            END;

                                        (*<KILL Descendant := NIL; KILL>*)
            edge := edge^.headlink;
        END;

        (* Unless this task's end dates are known because the task is
           done, incorporate the free and total end date information into
           the task record. *)

        IF (Task^.StartStatus <> DoneS) THEN (* Don't change the dates of done tasks. *)

                (* At this point, TotalEnd is the minimum of the late
                   total start dates of the successors, while FreeEnd
                   is the minimum of the early start dates. *)


            WITH Task^.Plan.Dates DO

                (*<TRACE
                SetString(TraceS,"    FreeEnd = ");
                TimeUtoS(FreeEnd,TraceS2);  ConcatLS(TraceS,TraceS2);
                ConcatS(TraceS,", TotalEnd = ");
                TimeUtoS(TotalEnd,TraceS2);  ConcatLS(TraceS,TraceS2);
                ConcatS(TraceS,", Dur = "); CtoS(Task^.duration,TraceS2);
                ConcatLS(TraceS,TraceS2);
                PrintString(TraceS);
                TRACE>*)

                    (* Unless the user has permitted negative slack,
                       never allow a late date earlier than an early
                       date. *)

                IF (NOT RecalcOptions.AllowNegativeSlack) THEN
                    IF (FreeEnd < EarlyEnd) THEN
                        (*<TRACE
                        SetString(TraceS,"Negative slack: ");  ConcatTaskID(TraceS,Task);  ConcatS(TraceS," FLE = ");
                        TimeUtoS(FreeEnd,TraceS2);  ConcatLS(TraceS,TraceS2); ConcatS(TraceS," EE = ");
                        TimeUtoS(EarlyEnd,TraceS2);  ConcatLS(TraceS,TraceS2);
                        PrintString(TraceS);
                        TRACE>*)
                        FreeEnd := EarlyEnd;
                    END;
                    IF (TotalEnd < EarlyEnd) THEN
                        TotalEnd := EarlyEnd;
                    END;
                END;


                WITH Task^ DO
                        (* free slack: *)
                    LateFreeEnd    := FreeEnd;
                        (* total slack: *)
                    LateTotalEnd   := TotalEnd;

                        (* For tasks that are started or done, we don't
                           need to calculate when they SHOULD start; we
                           know when they DID start. *)
                        (* free slack: *)
                    IF (StartStatus = FutureS) THEN

                        (* total slack: *)
                        OptimisticFindLatestStartDate(Task, LateTotalEnd,
                                               FoundDate, LateTotalStart);
                        IF NOT FoundDate THEN 
                            (*<TRACE
                            SetString(TraceS,"Error?? Can't find total late start for");
                            ConcatTaskID(TraceS,Task);  ConcatS(TraceS," LFE = ");
                            TimeUtoS(LateTotalEnd,TraceS2);  ConcatLS(TraceS,TraceS2);
                            ConcatS(TraceS," LFS = ");
                            TimeUtoS(LateTotalStart,TraceS2);  ConcatLS(TraceS,TraceS2);
                            PrintString(TraceS);
                            TRACE>*)
                            IssueWarning(CannotScheduleLate,Task);
                            LateFreeStart := 0;
                        END;
                        

                            (* In case the task has negative slack, don't
                               come up with a free date that ignores the
                               negative situation.   Otherwise, compute the
                               free start and end. *)

                        IF (LateTotalStart < EarlyStart) THEN
                            LateFreeStart := LateTotalStart;
                            LateFreeEnd   := LateTotalEnd;
                        ELSE
                            OptimisticFindLatestStartDate(Task, LateFreeEnd,
                                                   FoundDate, LateFreeStart);
                            IF NOT FoundDate THEN 
                                (*<TRACE
                                SetString(TraceS,"Error?? Can't find late free start for");
                                ConcatTaskID(TraceS,Task);  ConcatS(TraceS," LFE = ");
                                TimeUtoS(LateFreeEnd,TraceS2);  ConcatLS(TraceS,TraceS2);
                                ConcatS(TraceS," LFS = ");
                                TimeUtoS(LateFreeStart,TraceS2);  ConcatLS(TraceS,TraceS2);
                                PrintString(TraceS);
                                TRACE>*)
                                IssueWarning(CannotScheduleLate,Task);
                                LateFreeStart := 0;
                            END;
                        END;

                        (*<TRACE
                        SetString(TraceS,"    FreeStart = ");
                        TimeUtoS(LateFreeStart,TraceS2);  ConcatLS(TraceS,TraceS2);
                        ConcatS(TraceS,", TotalStart = ");
                        TimeUtoS(LateTotalStart,TraceS2);  ConcatLS(TraceS,TraceS2);
                        PrintString(TraceS);
                        TRACE>*)
                    ELSE
                        LateFreeStart := EarlyStart;
                        LateTotalStart := EarlyStart;
                    END;


                    (* ALAP and Summary milestones start as late as
                       possible.  Summary acts like ALAP so that it will
                       work in conjunction with ALAP tasks since ALAP
                       has lower precedence than ASAP (and ASAP task can
                       force an ALAP earlier).

                       However, if levelling is to follow, there is no need
                       to move these tasks to be later.  In fact, it constrains
                       them unnecessarily.  See the BORC0326 schedule.
                       *)
                    IF 
                       (SummaryFlag IN TempTaskFlags) OR
                       ((fixation = ALAP) AND (NOT Levelling))
                       THEN

                            (* If the task is not currently scheduled at
                               its free end date, move it to there. *)

                        IF (EarlyEnd < FreeEnd) THEN
                            EarlyEnd := FreeEnd;
    
                              (* Summary milestone tasks start at their late free start. *)
    
                            IF (SummaryFlag IN TempTaskFlags) THEN
                                EarlyStart := EarlyEnd;   
                            ELSE  (* ALAP *)
                                EarlyStart := LateFreeStart;
                            END;
                        END;
    

                        (*<TRACE
                        SetString(TraceS,"    ALAP or Summary, EarlyStart = ");
                        TimeUtoS(EarlyStart,TraceS2);  ConcatLS(TraceS,TraceS2);
                        ConcatS(TraceS,", EarlyEnd = ");
                        TimeUtoS(EarlyEnd,TraceS2);  ConcatLS(TraceS,TraceS2);
                        PrintString(TraceS);
                        TRACE>*)

                            (* Make sure that the proposes start date is within bounds,
                               then activate the task, computing its end date over again. *)

                        IF (EarlyStart > StartDateUpperBound) THEN    (* Start too late. *)
                            EarlyStart := StartDateUpperBound;
                            LateFreeStart := EarlyStart;
                            (*<TRACE  SetString(TraceS,"    Change ES to UB, = ");
                                        TimeUtoS(EarlyStart,TraceS2);  ConcatLS(TraceS,TraceS2);
                                        PrintString(TraceS);
                            TRACE>*)
                                (* Remove old varying assignments and recompute
                                   assignments to reflect the new start and end 
                                   dates. *)
                            ActivateTask( Task );
                            LateFreeEnd := EarlyEnd;
                        ELSE
                            IF (EarlyStart < StartDateLowerBound) THEN (* Start too soon. *)
                                EarlyStart := StartDateLowerBound;
                                (*<TRACE  SetString(TraceS,"    Change ES to LB, = ");
                                            TimeUtoS(EarlyStart,TraceS2);  ConcatLS(TraceS,TraceS2);
                                            PrintString(TraceS);
                                TRACE>*)
                            END;                                       (* Just right. *)

                                (* Remove old varying assignments and recompute
                                   assignments to reflect the new start and end 
                                   dates. *)
                            ActivateTask( Task );
                        END;

                            (* We store the cpm start date of tasks into the
                               count field in order to help levelling.  For
                               summary tasks, we store the early start. *)
                        IF (SummaryFlag IN TempTaskFlags) THEN
                            LevellingStartDate := EarlyStart;       (* for levelling. *)

                        ELSIF (ForceCritical IN Task^.TaskFlags) THEN 
                             (* If not a summary, but is an ALAP, if we should
                                force it critical then make sure that the total
                                slack is <= 0. *)
                            IF (LateTotalEnd > LateFreeEnd) THEN
                                LateTotalEnd := LateFreeEnd;
                                LateTotalStart := LateFreeStart;
                            END;
                        END;


                        (* End of if ALAP or Summary. *)

                    END;

                        (* Since resource levelling may follow, store the 
                           earliest date it can schedule the task into  
                           the LowerBoundStartDate field. *)

                    (*<TRACE
                    SetString(TraceS,"    ");  ConcatTaskID(TraceS,Task);
                    ConcatS(TraceS," LevellingStartDate =");
                    TimeUtoS(LevellingStartDate,TraceS2);  ConcatLS(TraceS,TraceS2);
                    PrintString(TraceS);
                    TRACE>*)

                    IF (AlreadyScheduled IN TempTaskFlags) THEN 
                        (* No further work needed.   In fact, avoid
                           changing the bounds, because levelling may 
                           depend on them, as it does for linked tasks. *)
                    ELSIF (UnspentWorkMustBeContiguous(Task)) THEN
                        StartDateLowerBound := LevellingStartDate;
                    ELSE
                        StartDateLowerBound := MaxEndOfSpent (Task,LevellingStartDate);
                        IF (MoveFutureTasks) 
                           AND (StartDateLowerBound < AsOfDate) THEN
                               IF (AsOfDate < StartDateUpperBound) THEN
                                   StartDateLowerBound := AsOfDate;
                               ELSE
                                   StartDateLowerBound := StartDateUpperBound;
                               END;
                        END;
                    END;

                    (*<TRACE
                    SetString(TraceS,"    ");  ConcatTaskID(TraceS,Task);
                    ConcatS(TraceS," LB =");
                    TimeUtoS(StartDateLowerBound,TraceS2);  ConcatLS(TraceS,TraceS2);
                    PrintString(TraceS);
                    IF (StartDateUpperBound < StartDateLowerBound) THEN
                        SetString(TraceS,"    WHOA! Bounds out of order!");
                        PrintString(TraceS);
                    END;
                    IF (TimeConstrained) THEN 
                        SetString(TraceS,"    TimeConstrained.  Check UpperBound");
                        PrintString(TraceS);
                    END;
                    TRACE>*)


                        (* If resource levelling will need to deal with 
                           constraints on the start dates of tasks, put those 
                           in now. *) 

                    IF (TimeConstrained) THEN 
                        ConstrainStartDate( Task );
                    END;

                        (* In order to make the gantt chart able to show delay
                            marks to show the results of resource levelling, 
                            we store the cpm start date into
                            the SupposedToStart field.   We do the work here, rather
                            than in the ForwardPass, because it is only during this
                            reverse pass that we will have correctly set the EarlyStart
                            for ALAP and Summary tasks. *)

                    CalendarTimeToBigTime(Plan.Dates.EarlyStart,TRUE,SupposedToStart);
                        (* If the user did not enter any dates, supply him with some
                           defaults in case he wants to. *)
                    IF (TaskFlags * ATaskFlagSet{NoSoonerStart,NoLaterStart,
                                                 NoSoonerEnd,NoLaterEnd}
                        = ATaskFlagSet{}) THEN
                        UserEnteredStartDate := SupposedToStart;
                        CalendarTimeToBigTime(Plan.Dates.EarlyEnd,TRUE,UserEnteredEndDate);
                    END;
                    


                END;
            END;

        END;     (* of exemption for Done tasks. *)


        (*<TRACE
        SetString(TraceS,"Reverse loop, Task  ");
        ConcatTaskID(TraceS,Task);  ConcatS(TraceS," LB = ");
        TimeUtoS(Task^.StartDateLowerBound,TraceS2);  ConcatLS(TraceS,TraceS2);
        ConcatS(TraceS,", UB = ");
        TimeUtoS(Task^.StartDateUpperBound,TraceS2);  ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        TRACE>*)


            (* Take advantage of this final pass to remove the resources
               we have assigned from the availability list. *)

        RemoveAssignmentsFromAvailability( Task );



        DEC(ToGo);
        IF ((ToGo MOD HowOften) = 0) THEN
            MaybeCountDown(ModuleNumber+4,ToGo); (* 'Finding late end dates, ' *)
        END;

        nextHandle := Task^.Prevlink;
        ReleaseObject(TaskHandle);      (*<KILL Task := NIL; KILL>*)
        TaskHandle := nextHandle;
    END;
END ReversePass;





    (* We update the residual availability tables after most of the processing
       is done because CPM scheduling doesn't need to track the ongoing
       availabilities.  By waiting until the end, we reduce the size of the
       tables during the earlier passes, and speed them up. 
       
       This code is duplicated in TLPlanEx. 
       
       *)


PROCEDURE RemoveOneAssignmentFromAvailability(  VAR Assignment      : AnAssignmentRecord;
                                                    Context         : ADDRESS            ) : BOOLEAN;
VAR
    i : CARDINAL;
    PeriodStart,PeriodEnd : ADate;
    PeriodRate            : REAL;
BEGIN
    WITH Assignment DO
            (* Update the list of residual availabilities to show that we
               consumed the resource. *)
        i := 1;
        WHILE ( GetVaryingAssgnListEntry( VaryingAssignment, i,
                                          PeriodStart, PeriodEnd, PeriodRate ))
            AND
              (NOT SchedulingAbandoned) 
            DO
                (* Only schedule entries in the date range we just added. *)
            IF (PeriodRate <> Zero) THEN
                ScheduleResource  (Resource,
                                   TRUNC(PeriodRate),PeriodStart,PeriodEnd);
            END;
            INC(i);
        END;
    END;
    RETURN TRUE;
END RemoveOneAssignmentFromAvailability;



PROCEDURE RemoveAssignmentsFromAvailability( Task : ATaskPtr );
BEGIN
    ForEachAssignment (Task^.Plan.Assignments,
                       RemoveOneAssignmentFromAvailability,
                       NIL);
END RemoveAssignmentsFromAvailability;








    (*  CPM -- Calculate the critical path EARLYSTART and LATEEND
               values for the tasks.

               Resource scheduling is done later.

               This routine has two important side effects:
                   1.  It relinks all tasks in topological order, and
                   2.  It detects any loops.

               See:  Fundamentals of Data Structures, Horowitz and Sahni,
                     1976, p 315;

                     A Management Guide to PERT/CPM, 1969, Wiest and Levy,
                     chapter 3;

                     KNUTH, v1, 2.2.3, program T and exercise 23.
    *)

    (*$S+*)

PROCEDURE ComputeNetworkDates(    LocalizeSlack : BOOLEAN;
                                  SomeLevel0TaskIsSummary : BOOLEAN
                             ):BOOLEAN;


VAR
    EndDateOfSchedule  : ADate;      (* Latest end date of any task. *)

BEGIN

       (*<TRACE
    SetString(TraceS,"Procedure cpm");    SetString(TraceS2,"TLCPM");
    PrintString(TraceS);
       TRACE>*)



        (* Rearrange the network, creating extra nodes and edges so that
           every summary task is represented by two nodes, one for start
           and the other for end, and all the child tasks are dependent
           on the start node and precede the end node.   New tasks which
           are created will be initialized by calling InitializeTask. *)

    IF (SomeLevel0TaskIsSummary) THEN
        IF NOT CreateSummaryPhantoms(InitializeTask) THEN
            SchedulingAbandoned := TRUE;
            RETURN FALSE;
        END;
    END;

        (* Add additional nodes to the tree so that each weakly-connected
           graph of tasks has exactly one (directed) terminal node. *)

    IF (LocalizeSlack) AND (SomeLevel0TaskIsSummary) THEN
           (*<TRACE
        SetString(TraceS,"Procedure cpm; AddTerminalNodes");    SetString(TraceS2,"TLCPM");
        PrintString(TraceS);
           TRACE>*)

        AddTerminalNodes(PrivateTaskList,TaskCount);

        IF (SchedulingAbandoned) THEN
            RETURN FALSE;
        END;

    END;

        (* Forward Pass: Calculate early start dates, overall latest
                         END date, and link all the tasks in
                         topological order.

                         Set up a linked queue of tasks WITH no
                         antecedants.

                         Initialize the early start dates for all tasks.
                         "Done" and "Started" tasks are already in
                         progress so we don't restrict their starting
                         times.  Tasks WITH fixed start dates DO not require
                         intervention to mark them as started, so their
                         start dates are not restricted.  Unfixed (ASAP)
                         tasks cannot start until after the latest of the
                         done tasks.

        *)



        (*  Process all tasks in topological order.  Keep track of
            the latest ending date for any task, in the EndDateOfSchedule
            variable.  Initially we set this to the smallest possible date,
            then, as each task is scheduled it is increased to be
            the greatest end date seen so far.  *)

        (*  "Tasks" is the number of tasks.  If we exhaust the stack
            before processing all of them there was a loop.  This is
            because the queue contains all tasks without predecessors,
            and yet there are tasks left, all of which have predecessors.
            In other words, among the remaining tasks, none of them
            are first.

            When we are done, all of the tasks should be back on the task
            list.
        *)



    EndDateOfSchedule := MinDate;                        (* Will be increased *)

    ForwardPass( PrivateTaskList, EndDateOfSchedule );

    IF (SchedulingAbandoned) THEN
        RETURN FALSE;
    END;


        (* REVERSE PASS:  Calculate late END dates for each task and
                          link tasks into forward topological order.
                          *)


    ReversePass( PrivateTaskList, EndDateOfSchedule );

        (* Independent slack pass. *)

    IF (SchedulingAbandoned) THEN
        RETURN FALSE;
    END;


    RETURN TRUE;

END ComputeNetworkDates;


    (*$S=*)


PROCEDURE RearrangeLists();
VAR
    NewList : AnExtHandle;
    Task                   : ATaskPtr;
    TaskHandle             : AnExtHandle;
    nextHandle             : AnExtHandle;
    ATop                   : BOOLEAN;
BEGIN
    IF NOT ListInit(NewList) THEN FatalError(); END;
    ATop := TRUE;

    IF (LockObject(PrivateTaskList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(PrivateTaskList);             (*<KILL Task := NIL; KILL>*)

    WHILE (NOT ObjectsAreSame(TaskHandle,PrivateTaskList))
          AND
          (NOT SchedulingAbandoned) DO

        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
        nextHandle := Task^.Nextlink;

        (* Delist the task. *)

        DeList( TaskHandle );

        (* Move it to the end of the other list. *)

        AddBefore(NewList,TaskHandle);
        

        (* On to the next task. *)

        ReleaseObject(TaskHandle);      (*<KILL Task := NIL; KILL>*)
        TaskHandle := nextHandle;

    END;

    MoveList(NewList,PrivateTaskList);

END RearrangeLists;







BEGIN
    (*<TRACE
    Fill(TraceS," ",0);
    Fill(TraceS2," ",0);
    TRACE>*)

    SetAsOfDate();                (* 3/27/87 EGK *)

    AllLevel0TasksAreSummary := TRUE;
    SomeLevel0TaskIsSummary  := FALSE;
    Projects            := 0;


    NeedLinkedScheduleRollin := FALSE;
    SchedulingAbandoned      := FALSE;
    ScheduleComputedOk       := FALSE;
    SomeBaselineExists       := FALSE;   (* Unless we see otherwise. *)

        (* Scan1 prepares individual tasks for scheduling.
           It also sets at least one global flag which
           signals if special conditions were found.
           This procedure must be repeatable without
           damage, so that it may be called again after
           handling the special conditions.
               This procedure may also put up the computing
           box.
        *)



       (*<TRACE
    SetString(TraceS,"Scan1 ");    SetString(TraceS2,"TLCPM");
    PrintString(TraceS);
       TRACE>*)


    SequenceCounter := 0;
    Scan1(Scan1ExtraWork);

        (* Scan1 sets NeedLinkedScheduleRollin if we should exit, signalling
           our caller to link tasks first, then call us again. *) 

    IF (NOT NeedLinkedScheduleRollin) THEN
        ScheduleComputedOk := InitializeResourceAvailabilities()  (* Build the resource availability data: *) 
                              AND 
                              ComputeNetworkDates(CheckForMultipleProjects
                                                    AND AllLevel0TasksAreSummary 
                                                    AND (Projects > 1),
                                                  SomeLevel0TaskIsSummary) 
                              AND 
                              (NOT SchedulingAbandoned);
    ELSE
        ScheduleComputedOk := TRUE;   (* We didn't crash. *)
    END;


    (* RearrangeLists();*)


       (*<TRACE
    EndTrace();
       TRACE>*)

END TLCPM.





Early modification history:

       1/2/86   AJL  -- End date now displayed with HDefault.
        07/22/86 LAA    Substituted ExecuteOverlay for SelectAndRunOverlay.
       Oct. 23, 1986  AJL - Added a floating point Tolerance factor
                            to resource conflict checking.

        11/04/86 LAA    ChartState is now a set.
        11/28/86 LAA    In Pert, changed the location of the
                        SetState(Scheduled) so it's only set if the project
                        has really been computed.  Added a Light to display
                        the schedule end date.
        12/30/86 LAA    Replaced the End Date light with usage of the
                        Recompute light from ChartControl.
        28-Jan-87 LAA   Changed the location of SetState(Scheduled) in Pert.
                        I'm still not sure this is right.  The problem it was
                        causing was the on an erased schedule, once
                        PrepareChart was called (with the ChartState empty) it
                        looped forever between that and Pert.
        3/23/87  EGK    Added call to SetAsOfDate, before computing a schedule.
        5/8/87   RSC    Made changes for dates and resource changes in Allocs.
        5/25/87  AJL    Changed to use the TaskTree and also the private
                        usage module, PTaskList;
        27-May-87 LAA   Added the NORMAL and GELDED versions for debugging.
        04-Jun-87 LAA   Changed parameters for TraverseTree.
        13-Jun-87 AJL - Added RollupCostsAndDates.  This has been tested to
                        accurately rollup dates.  I don't know about costs.
                      - Display the progress messages in the RecomputeLight.
        15-Jun-87 AJL - Added logic for MustStartBy and MustEndBy values.
        22-Jun-87 AJL - Fix the rollup logic to work accurately.  Several
                        mistakes fixed.
                      - Added logic that takes the start dates on Started
                        tasks as fixed.  The start and end dates on done
                        tasks are taken as fixed.
                      - Add notices.
         6-Jul-87 AJL - Add effort-driven calculations.
                      - Add procedures to create and remove summary task
                        phantom end milestones.
         7-Jul-87 AJL - Took out all the support for MustStart and MustEnd.
         8-Aug-87 AJL - Removed support for Span tasks.
         1-Sep-87 AJL - Removed references to ExtendedStorage.
                      - Added "fingerprinting" of resources on tasks.
         4-Sep-87 AJL - Improved rollup so that phantoms are
                        ignored.
         9-Sep-87 AJL - RollupCosts now pays attention to tasks with
                        zero percent achieved.
                      - RollupCosts fills in the Completed and ToGo
                        summaries for detail tasks after calling
                        SummTaskNodeAmounts.
                      - If any tasks are linked to another schedule
                        (rollupstatus = RollupNotLoaded) we invoke the
                        procedure to do the summarization of the sub
                        schedule.
        22-Sep-87 AJL - Added code to treat some summary level tasks
                        as "SelfContained," which calculates the slack
                        of the children in terms of the parent's early
                        end date.
                      - Fix the calculation of TotalLate Start and End.
        23-Sep-87 EGK   Changed some calls to conform to new Allocs.DEF.
                        (e.g., DelEdge, CreateEdge)
         9-Oct-87 RSC   Changed DateAsEndOfPeriod to FormatAsDateStyle.
        13-Oct-87 AJL   Moved Rollup calculations to a separate module.
        21-Oct-87 AJL   Rewrote the way we consider groups of tasks to
                        be independent of other groups.  This no longer
                        uses the SelfContained flag.
        27-Oct-87 LAA   Removed display of the end date, or Calc Error light
                        messages, from Planner and moved it to ChartCon.
        27-Oct-87 AJL   Tasks that are in groups now have their slack
                        computed local within the group (weakly connected
                        subgraph).
        30-Oct-87 AJL  -Moved the flags definitions to PTaskLis.def.
                       -Changed the TerminalFlag to not == SelfContained.
         2-Nov-87 AJL  -Restore the message line when we are done.
                       -If we asked permission to do a recalc, send a
                        completion notice.
         5-Nov-87 AJL  -Mark PartialJoinPrior.
        23-Nov-87 AJL  -Only call the leveling routine if overbooked on
                        tasks marked LevelThisResource.
                       -Move the location of the linked schedule rollin
                        so that Rollin is free to add additional tasks
                        to the schedule.
         5-Dec-87 AJL  -Record the topological sequence into Task^.Y.
        10-Dec-87 AJL  -Added FlexStor.
        29-Dec-87 AJL  -Force summary tasks to be duration driven.
                       -Erase and free up message line on exit.
                       -Warn that partial joins with summary tasks won't work.
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
        8-Mar-89 AJL   -Built this module out of most of former TLPLAN.
       14-Mar-89 EGK    Initialize WarningsIssued in main procedure.
       20-Mar-89 AJL   -Put topological order into TopoOrder.
                       -Put Fingerprint into Temp3.
                       -Remove references to Edge^.FromOffset.Plus and Dur.
       21-Apr-89 AJL   -Remove TaskMsg and NoteThis.
       12-May-89 JES   -Remove use of PCache.
                        Fixed a minor bug
                        (you need to reset the summary task's count field
                        after its early start is reset - this fixed
                        bug where summary tasks were starting at the
                        beginning of time, since count field is used
                        by resource levelling).
        14-May-89 AJL   Replaced the Alarms.AlarmOn variable with
                        Planner.MoveFutureTasks.
         2-Aug-89 JES   Changed reference to TLPlantDt to PTasklist
                         (since TlPlanDt stuff was moved into PTasklist)
        09-Aug-89 KKC   Add copyright message.

        22-Aug-89 AJL   Changed a call to IssueWarning(BeforeStartOfCalendar . .)
                        so that it includes the "antecedant" task name.  Ref
                        bug #1064.
        18-Sep-89 AJL   Added some range checking tests to the calculation
                        of EdgeDates so that a negative Delta wouldn't push
                        a date earlier than the start of time.
        21-Sep-89 AJL   If a task is started or done,
                        restrict the task's parents so that they are not allowed to
                        start later than the (child) task.
                        See the RestrictParentsDates procedure.
        04-Oct-89 WKH   Kluge solution to problem of TLCPM causing an
                        exception 13 error due to de-refrencing of a NIL
                        pointer in OVERLAY.MOD.  This is just TEMPORARY until
                        RSC returns to save us.....
        09-Oct-89 RSC   Fixed bug in Overlay.Mod that this module was a victim
                        of, and removed Wayne's temporary patches.
        19-Dec-89 JES   Fixed bug #1970 that caused ALAP tasks never to
                        start before their CPM-computed early start,
                        which in turn sometimes caused fixed milestones
                        to be moved out (rather than moving a precedent
                        ALAP task earlier to fill in the space - see
                        schedule MILSTONS). The bug was caused by an
                        earlier fix that reset the "count" field to
                        the new early start when the latter was updated
                        (see lines with comment "JES" below). This field
                        is now left as is for ALAP tasks that are not
                        summaries; i.e., it is left at its lesser value,
                        allowing levelling to permit a start date that
                        early.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        09-Jul-90 AJL   Moved Visited and TerminalFlag to TempTaskFlags.
        17-Jul-90 AJL  -Adjusted for the renamed flag 'FixTheStart.
                       -Added logic for the new flags ForceCritical and
                        FixTheEnd.
       Aug 15, 90 AJL - Import ComputeEdgeDelta from PTaskList.
       Aug 22, 90 AJL - Compute varying assignments for each task which
                        reflect the spent and yet-to-go efforts.
       Sep. 4, 90 AJL - Added NoSoonerStart to task flags.
       Sep. 9, 90 AJL - Reorganized the structure.
                      - Added use of the NoLaterStart flag and removed use
                        of the FixTheStart flag.
                      - Changed fixed tasks, and also the RestrictParentsDates
                        procedures to use the NoLaterStart flag.
                      - Changed slack calculations.
                      - Allow negative slack.



