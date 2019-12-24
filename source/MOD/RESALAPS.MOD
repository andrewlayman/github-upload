IMPLEMENTATION MODULE ResAlaps;
(*V1=KILL *)
(*V2=PRINT WITH debugging printouts. *)
(*V3=DEBUG WITH debugging assertions tested *)

(*<KILL*) (*$T+*) (*KILL>*)

(* Procedures to move ALAP tasks later (and then ASAP tasks earlier etc)
   in resource levelling.

   MODIFICATION HISTORY

    Feb 27, 89 - JES -created by yanking procedures from Tlrplan
                      and completely modifying most of them to
                      use the new resource availability structures.

    July 12, 89 - JES - Modified to exit gracefully when flexstore create
                        fails.
    Aug-30-89   AJL     -Changed name of "InsufficientVirtualMemory" to
                         "SchedulingAbandoned". 
    30-Mar-90   RSC     Made Timeu to Timei/TimeForm conversions.
    02-May-90   KKC     Replace all direct calculations on ADate and Duration
                        by calls to FindDuration, SubtractWorkingTime and
                        AddWorkingTime.
    Sepy 17, 90 JES     Fixed some obsolete imports, and commented out
                        a bunch of obsolete code (for now). Later we
                        must rewrite this module for multiple calendars
                        (for now it has been deactivated in levelling).
    Oct. 9, 1990 AJL    Janet changed the parameters to FindEarliestStartDate
                        by adding an upper bound and also a found flag.  I have
                        changed the calls to this procedure so that they
                        compile, but I have not studied it carefully in the 
                        context of the algorithm to make sure that my changes
                        are exactly what is needed.
    Oct 12, 90   JES    AddLowDate is now imported from PTaskList instead
                        of from ResBumpTasks. Also, temporarily deactivated
                        calls to MustStartOnTime - eventually we will need
                        a substitute for it. (It returned TRUE iff the
                        task was Started or Done.)
    Nov  5, 90   JES    Changed name "UpperBoundStartDate" to 
                        "StartDateUpperBound" to correspond to new
                        allocs.def.
    Dec 21, 90 - JES -renamed this module ResAlaps (formerly called
                        ResMoveTasks).
    Jan 14, 91 - JES -changed call of FindLatestStartDate to match new
                        spec.

    Jan 25, 91 - JES - this module is IN PROGRESS - do not use.
                        Its main procedure has temporarily been commented
                        out of tlrplan.
    Jan 28, 91 - JES - this module is now ready for testing.
    Feb  7, 91 - JES - removed all references to WBS numbers.
    Mar  7, 91 - JES - added parameter AllWorkDone to calls to
                        ActivateTask
    Mar 14, 91 - JES - ConcatTaskID was not imported - it now is.
    Mar 25, 91 - JES - Changed TimeUtoS's to CtoS's in debugging printouts.
    Mar 27, 91 - JES - Move Alaps now correctly deactivates the task as of
                       the count field (rather than the count2 field).
    Apr  9, 91 - JES - Removed unused import AddLowDate.
    Apr 10, 91 - AJL - Removed the process of changing SupposedToStart. 
    Apr 12, 91 - JES - Added the condition that the task is not 
                        AlreadyScheduled to procedure "TaskIsMovable".
                       Also added condition (1) for ALAP task, it's not
                        movable if count = UpperBound; (2) for ASAP task,
                        it's not movable if count = LowerBound.
                       Also removed condition that disallowed moving of
                        summary tasks.
    Apr 15, 91 - JES - Added print statements.
                     - Changed call to FindLatestStartDate to use as max end date
                        the earliest descendant start date, instead of the
                        end of the schedule.
                     - Changed call to FindEarliestStartDate to use
                        max of LowerBound and LatestAntecendantEndDate
                        as StartSearch, instead of simply LowerBound.
                     - Removed calls to AddBefore when reactivating a task,
                        since the task was never removed from the list.
                     - We were failing to re-update the resource availabilities
                        in MoveALAPEvenLater and MoveALAPEvenEarlier in the
                        case that the task could not be moved. We now do it.
    Apr 16, 91 - JES - Further optimized conditions on TaskIsMovable (made
                        it slightly more restrictive to avoid futile effort
                        to move unmovable tasks).
                     - Call ActivateTask with ScheduledList instead of
                        ActiveList, so tasks don't get moved to ActiveList.
                     - Removed calls to DeactivateTask and inlined relevant
                        functions.
    Apr 18, 91 - AJL - In MoveALAPEvenLater, removed an extra lock statement
                       that would have locked the assignments handle twice if 
                       a task was not moved.
                     - In that procedure, changed a LOOP loop to a FOR loop.
                     - Unlocked the assignments handle before error return.
                     - Similar fixes to MoveASAPEvenEarlier.
    Apr 19, 91 - AJL - In those same two procedures, if FoundDate became false,
                       we were not unlocking the assignment handle.
    Apr 20, 91 - AJL - In those procedures, unlock the assignment handle
                       before searching for a date, relocking it again after.
                       This is necessary because searching for a date can
                       itself lock that handle several times, and FlexStor
                       currently has a limit of no more than two locks per
                       handle.
                     - Removed the unnecessary ToGo parameter from MoveTasks.
    May  6, 91 - JES - In MoveASAPs, we now also allow Fixed tasks to be 
                       moved (i.e., we treat them just like ASAPs), since
                       there is no reason not to (and without this
                       capability, Fixed tasks were getting left way out in
                       the middle of the schedule after other tasks were
                       moved).
                       
    May 30, 91 - JES - Put back the ToGo parameter in MoveTasks, to support
                        use of the AlreadyScheduled list in Tlrplan.
    Jun 25, 91 - JES - Added new (dummy) parameter TaskIsInfeasible to call to
                        FindEarliestStartDate.
                     - Added condition that task is not infeasible
                        (CantSchedule flag not set) to procedure
                        TaskIsMovable.
     4-Feb-92   AJL  -  Convert rates to real.
    Mar 31, 92 - AJL - Removed ActiveList parameter to MoveTasks.
                     - Changed the list traversal of the ScheduledList in
                       MoveALAPs and MoveASAPs so that as tasks are moved,
                       they are temporarily stored into another list.  This
                       way they will not be processed twice.  Bug 5472.1.

*)

FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr, ATask, AFixType, ATaskStatus, ATaskFlag,
    (* PROC *)              GetCodingField;


FROM Assignments    IMPORT
    (* TYPE *)              AnAssignmentArray, AnAssignmentRecord;

FROM CalShift       IMPORT
    (* VAR  *)              TimeSheet;

FROM Dialog         IMPORT
    (* PROC *)              FatalError, NotYetImplemented;


FROM Duration       IMPORT
    (* PROC  *)             AddWorkingTime;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, LockObject, ReleaseObject, LockObjectArray,
                            DiscardExtObject,
                            ReleaseUnchangedObject, ObjectsAreSame;

FROM LStrings       IMPORT    
    (* PROC *)              SetString, CtoS;

FROM Phantoms       IMPORT SummaryFlag;
    (* CONST *)


FROM ResConstants   IMPORT
    (* CONST *)             ModuleNumber, HowOften2, Zero,
    (* VAR   *)             SchedulingAbandoned; 


FROM ResStartDates  IMPORT
    (* PROC *)              FindEarliestStartDate;

FROM ResLates     IMPORT
    (* PROC *)              FindLatestStartDate;

FROM ResScheduleTaskResources     IMPORT
    (* PROC *)              ActivateTask, RemoveFromResourceAvailability,
                              AddToResourceAvailability;


FROM RsrcMod      IMPORT    AResourcePointer;
    (* TYPE *)

FROM PTaskList    IMPORT
    (* PROC *)              CountDown, ListInit, AddLowDate,
                            TerminalFlag, AlreadyScheduled;

FROM ResUtilities  IMPORT   EarliestDescendantStartDate, LatestAntecedantEndDate;
    (* PROC *)

FROM ResWarnings  IMPORT    IssueWarning, AWarning;
    (* PROC *)

FROM SYSTEM       IMPORT    TSIZE;
    (* PROC *)

FROM Timei          IMPORT
    (* CONST*)              MinDate, MaxDate,
    (* TYPE *)              ADate;

FROM TimeXlate      IMPORT
    (* PROC *)          CalendarTimeToBigTime;

FROM VaryAssgnment  IMPORT
    (* PROC *)          CreateVaryingAssgnListRange;


(*  ------------------------ Import if tracing ------------------*)
(*<PRINT
FROM LStrings     IMPORT ConcatS, ConcatLS;
FROM PrintSupport IMPORT StartReport, PrintLine, EndReport;
FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat; 
FROM ResTrace     IMPORT NoteString, PrintAString, ConcatTaskID, PrintList;
FROM TimeFormat   IMPORT TimeUtoS;     

VAR
    s : ARRAY [0..255] OF CHAR;
PRINT>*)


(*------MoveALAPEvenLater -- Examine this ALAP task.  If
                              it can be moved into the future,
                              do so.   Returns TRUE iff the
                              task was moved.  
*)

PROCEDURE MoveALAPEvenLater(TaskHandle    : AnExtHandle;
                            Task          : ATaskPtr;
                            EndOfSchedule : ADate;
                            ActivationList : AnExtHandle) : BOOLEAN;
VAR
    NewDate, OriginalDate, MaxEndDate, TaskEndDate  : ADate;
    AssignmentHandle: AnExtHandle;
    Assignments:  AnAssignmentArray;
    ResourceCount, j : CARDINAL;
    Moved, FoundDate, AllWorkDone  : BOOLEAN;
BEGIN
    OriginalDate := Task^.count;

        (* free the resources *)
    (*<PRINT
    SetString(NoteString, "   freeing the resources:");
    PrintAString(NoteString);
    PRINT>*)
    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));
    AddToResourceAvailability(Assignments,
                              ResourceCount,
                              OriginalDate);
    ReleaseUnchangedObject(AssignmentHandle);  (* Keep outstanding locks < 3 *)
    IF SchedulingAbandoned THEN
        RETURN FALSE;
    END;

        (* find the new latest possible start date: *)
    MaxEndDate := EarliestDescendantStartDate(Task, EndOfSchedule);
    FindLatestStartDate(Task,                
                        MaxEndDate,
                        FALSE, (* do we allow overbookings *)
                        FALSE, (* do we use late availabilities *)
                        FoundDate,
                        NewDate,
                        TaskEndDate);

    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));

    IF (FoundDate) AND (NewDate > OriginalDate) THEN
        Moved := TRUE;
        (* finish deactivating at original date, and reactivate at
            the new date: *)

        (*<PRINT
        SetString(NoteString, "MoveALAP: ");  ConcatTaskID(NoteString, Task);
        PrintAString(NoteString);
        SetString(NoteString, "Original date: ");  CtoS(OriginalDate, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        SetString(NoteString, "New date: "); CtoS(NewDate, s); ConcatLS(NoteString, s);
        PrintAString(NoteString);
        SetString(NoteString, "Reactivating at new start date.");
        PrintAString(NoteString);
        SetString(NoteString, "    removing varying assignments:");
        PrintAString(NoteString);
        PRINT>*)
        
            (* remove the old varying assts *)

        FOR j := 1 TO ResourceCount DO
            IF NOT (CreateVaryingAssgnListRange
                           (Assignments^[j-1].VaryingAssignment,
                            OriginalDate,
                            MaxDate,
                            Zero)) THEN
                SchedulingAbandoned := TRUE;
                ReleaseObject(AssignmentHandle);
                RETURN FALSE;
            END;
        END;

        ReleaseObject(AssignmentHandle);

             (* activate the task at the new date: *)
        ActivateTask(TaskHandle,
                     Task,
                     NewDate,
                     FALSE, (*DoWeForceSchedule*)
                     ActivationList, 
                     AllWorkDone); 
        IF SchedulingAbandoned THEN
            RETURN FALSE;
        END;
    ELSE
            (* the task could not be moved: *)
        Moved := FALSE;
        (*<PRINT  SetString(NoteString, "    task not moved, updating resource availabilities:");
                  PrintAString(NoteString);
        PRINT>*)
            (* update the resource availabilities to what they
               were originally: *)
        RemoveFromResourceAvailability(Assignments, ResourceCount, OriginalDate);
        ReleaseUnchangedObject(AssignmentHandle);
    END;

    RETURN Moved;
END MoveALAPEvenLater;




(*------MoveALAPs -- Move ALAP tasks forward, if possible.  Returns TRUE
                     if any were moved. 
*)

PROCEDURE MoveALAPs(EndOfSchedule      : ADate;
                    ScheduledList : AnExtHandle;                               
                    TaskCount     : CARDINAL  ;
                    ToGo          : CARDINAL)   : BOOLEAN;


CONST
    LocalCountDown = ModuleNumber+5;
VAR
    Task                           : ATaskPtr;
    TaskHandle, PreviousTaskHandle : AnExtHandle;
    TempList                       : AnExtHandle;  (* Holds moved tasks. *)                              
    Moved                          : BOOLEAN;
    s                              : ARRAY [0..81] OF CHAR;
BEGIN

    (*<PRINT SetString(NoteString,"------MoveALAPs");
             PrintAString(NoteString);
    PRINT>*)

    IF NOT ListInit( TempList ) THEN RETURN FALSE; END;
                              (* Create an empty, temporary list.  As
                                 we move tasks, we put them into this list
                                 so that they do not have any possibility of
                                 being visited twice. *)

    CountDown(LocalCountDown,TaskCount,ToGo);

        (*  Run backwards through the task list, moving ALAP tasks
            forward in time, to later dates. *)

    Moved := FALSE;
    IF (LockObject(ScheduledList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Prevlink;
    ReleaseUnchangedObject(ScheduledList);
    WHILE (NOT ObjectsAreSame(TaskHandle,ScheduledList)) DO
        IF ( (ToGo MOD HowOften2) = 0 ) THEN
            CountDown(LocalCountDown,TaskCount,ToGo);
        END;
        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;

        PreviousTaskHandle := Task^.Prevlink;

        (*<PRINT
        SetString(NoteString, ".Consider ");
        ConcatTaskID(NoteString, Task);
        PrintAString(NoteString);
        IF (Task^.TaskID >= 236) AND (Task^.TaskID <= 238) THEN
            SetString(NoteString, "---Scheduled List ----- ");
            PrintAString(NoteString);
            PrintList(ScheduledList);
        END;
        PRINT>*)


        IF (Task^.fixation = ALAP) AND (TaskIsMovable(Task,EndOfSchedule)) THEN
            (*<PRINT
            SetString(NoteString, "Ready to try to move ALAP task ");
            ConcatTaskID(NoteString, Task);
            PrintAString(NoteString);
            PRINT>*)
            Moved := (MoveALAPEvenLater(TaskHandle, 
                                        Task,
                                        EndOfSchedule,
                                        TempList)) 
                        OR (Moved);
            IF SchedulingAbandoned THEN
                ReleaseObject(TaskHandle);
                (*<KILL*) Task := NIL; (*KILL>*)
                RETURN FALSE;
            END;

        END;
        ReleaseObject(TaskHandle);     (*<KILL*)  Task := NIL; (*KILL>*)
        TaskHandle := PreviousTaskHandle;
        IF (ToGo > 0) THEN
            DEC(ToGo);
        END;
    END;

        (* Move all the tasks from the temporary list into the scheduled list. *)

    IF (Moved) THEN
        IF (LockObject(TempList,Task)=0) THEN FatalError(); END;
        TaskHandle := Task^.Prevlink;
        ReleaseUnchangedObject(TempList);
        WHILE (NOT ObjectsAreSame(TaskHandle,TempList)) DO
            IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
            PreviousTaskHandle := Task^.Prevlink;
            AddLowDate(ScheduledList,TaskHandle,Task);  (* Must be in sorted order. *)
            ReleaseObject(TaskHandle);     (*<KILL*)  Task := NIL; (*KILL>*)
            TaskHandle := PreviousTaskHandle;
        END;
    END;

    DiscardExtObject(TempList);


    RETURN Moved;

END MoveALAPs;



PROCEDURE MoveASAPEvenEarlier(TaskHandle    : AnExtHandle;
                              Task          : ATaskPtr;
                              ActivationList : AnExtHandle) : BOOLEAN;
VAR
    NewDate, OriginalDate, TaskEndDate, StartSearchAt, EndSearchAt  : ADate;
    AssignmentHandle : AnExtHandle;
    Assignments : AnAssignmentArray;
    ResourceCount, j : CARDINAL;
    Moved, FoundDate, AllWorkDone, TaskIsInfeasible  : BOOLEAN;
BEGIN
    OriginalDate := Task^.count;
        (* It is very important that this routine NEVER move a task
           later in the list.  Otherwise, the calling procedure may
           loop forever, since it scans in a forward direction. *)

        (* free the resources *)
    (*<PRINT SetString(NoteString, "   freeing the resources:");
             PrintAString(NoteString);
    PRINT>*)

    AssignmentHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));
    AddToResourceAvailability(Assignments,
                              ResourceCount,
                              OriginalDate);
    ReleaseUnchangedObject(AssignmentHandle);   (* Keep outstanding locks < 3 *)
    IF SchedulingAbandoned THEN
        RETURN FALSE;
    END;

        (* find the new earliest possible start date: *)
    StartSearchAt := LatestAntecedantEndDate (Task, Task^.StartDateLowerBound);
    EndSearchAt   := Task^.count; (* the current activation date *)
    FindEarliestStartDate (Task, 
                           StartSearchAt,
                           EndSearchAt,
                           FALSE, (* DoWeAllowOverbookings *)
                           FoundDate,
                           NewDate,
                           TaskEndDate,
                           TaskIsInfeasible (* dummy parameter *));

    ResourceCount    := LockObjectArray(AssignmentHandle,
                                        Assignments,
                                        TSIZE(AnAssignmentRecord));

    IF (FoundDate) AND (NewDate < OriginalDate) THEN
        Moved := TRUE;
        (* finish deactivating at original date, and reactivate at
            the new date: *)
        (*<PRINT
        SetString(NoteString, "MoveASAP: ");  ConcatTaskID(NoteString, Task);
        PrintAString(NoteString);
        SetString(NoteString, "Original date: "); CtoS(OriginalDate, s);
        ConcatLS(NoteString, s);
        PrintAString(NoteString);
        SetString(NoteString, "New date: "); CtoS(NewDate, s); ConcatLS(NoteString, s);
        PrintAString(NoteString);
        SetString(NoteString, "Reactivating at new start date.");
        PrintAString(NoteString);
        SetString(NoteString, "    removing varying assignments:");
        PrintAString(NoteString);
        PRINT>*)

            (* remove the old varying assts *)

        FOR j := 1 TO ResourceCount DO
            IF NOT (CreateVaryingAssgnListRange
                          (Assignments^[j-1].VaryingAssignment,
                           OriginalDate,
                           MaxDate,
                           Zero)) THEN
                SchedulingAbandoned := TRUE;
                ReleaseObject(AssignmentHandle);
                RETURN FALSE;
            END;
        END;

        ReleaseObject(AssignmentHandle);
            (* activate the task at the new date: *)
        ActivateTask(TaskHandle,
                     Task,
                     NewDate,
                     FALSE, (*DoWeForceSchedule*)
                     ActivationList, 
                     AllWorkDone); 
        IF SchedulingAbandoned THEN
            RETURN FALSE;
        END;
    ELSE
            (* the task could not be moved: *)
        Moved := FALSE;
        (*<PRINT
        SetString(NoteString, "    task not moved.");
        PrintAString(NoteString);
        SetString(NoteString, "updating resource availabilities:");
        PrintAString(NoteString);
        PRINT>*)

            (* update the resource availabilities to what they
               were originally: *)
        RemoveFromResourceAvailability(Assignments, ResourceCount, OriginalDate);
        ReleaseUnchangedObject(AssignmentHandle);
    END;
    

    RETURN Moved;
END MoveASAPEvenEarlier;




PROCEDURE MoveASAPs(ScheduledList : AnExtHandle;
                    TaskCount     : CARDINAL;
                    ToGo          : CARDINAL) : BOOLEAN;
CONST
    LocalCountDown = ModuleNumber+6;
VAR
    Task  : ATaskPtr;
    TaskHandle, NextTaskHandle : AnExtHandle;
    TempList : AnExtHandle;
    s     : ARRAY [0..81] OF CHAR;
    Moved : BOOLEAN;
BEGIN
    (*<PRINT SetString(NoteString,"------MoveASAPs");
             PrintAString(NoteString);
    PRINT>*)

    IF NOT ListInit( TempList ) THEN RETURN FALSE; END;
                              (* Create an empty, temporary list.  As
                                 we move tasks, we put them into this list
                                 so that they do not have any possibility of
                                 being visited twice. *)

    CountDown(LocalCountDown,TaskCount,ToGo);

        (*  Run forwards through the task list, moving ASAP tasks
            back in time. We also allow Fixed type tasks to be
            moved, since for now they are essentially like ASAPs. *)

    Moved := FALSE;
    IF (LockObject(ScheduledList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(ScheduledList);               (*<KILL*) Task := NIL; (*KILL>*)
    WHILE (NOT ObjectsAreSame(TaskHandle,ScheduledList)) DO
        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
        IF ( (ToGo MOD HowOften2) = 0 ) THEN
            CountDown(LocalCountDown,TaskCount,ToGo);
        END;
        NextTaskHandle := Task^.Nextlink;
        IF (Task^.fixation <> ALAP) AND (TaskIsMovable(Task,MaxDate)) THEN
            (*<PRINT
            SetString(NoteString, "Ready to try to move ASAP or Fixed task ");
            ConcatTaskID(NoteString, Task);
            PrintAString(NoteString);
            PRINT>*)
            Moved := (MoveASAPEvenEarlier(TaskHandle, 
                                          Task, 
                                          TempList))
                     OR (Moved);
            IF SchedulingAbandoned THEN
                ReleaseObject(TaskHandle);
                (*<KILL*) Task := NIL; (*KILL>*)
                RETURN FALSE;
            END;
        END;
        ReleaseObject(TaskHandle);          (*<KILL*) Task := NIL; (*KILL>*)
        TaskHandle := NextTaskHandle;
        IF (ToGo > 0) THEN
            DEC(ToGo);
        END;
    END;

        (* Move all the tasks from the temporary list into the scheduled list. *)

    IF (Moved) THEN
        IF (LockObject(TempList,Task)=0) THEN FatalError(); END;
        TaskHandle := Task^.Nextlink;
        ReleaseUnchangedObject(TempList);               (*<KILL*) Task := NIL; (*KILL>*)
        WHILE (NOT ObjectsAreSame(TaskHandle,TempList)) DO
            IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
            NextTaskHandle := Task^.Nextlink;
            ReleaseObject(TaskHandle);          (*<KILL*) Task := NIL; (*KILL>*)
            AddLowDate(ScheduledList,TaskHandle,Task);  (* Must be in sorted order. *)
            TaskHandle := NextTaskHandle;
            IF (ToGo > 0) THEN
                DEC(ToGo);
            END;
        END;
    END;


    DiscardExtObject(TempList);


    RETURN Moved;

END MoveASAPs;




(*------MoveTasks-----------------------------------------(exported)----*)


PROCEDURE MoveTasks(ScheduledList : AnExtHandle;
                    TaskCount     : CARDINAL;
                    ToGo          : CARDINAL);
VAR
    EndOfSchedule : ADate;
    Moved    : BOOLEAN;
BEGIN
    EndOfSchedule := EndOfLatestTaskOnList(ScheduledList);
    Moved := TRUE;
    REPEAT
        (*<PRINT
        SetString(NoteString, "MoveTasks: Moved = ");
        IF Moved THEN
          ConcatS(NoteString, "TRUE");
        ELSE
          ConcatS(NoteString, "FALSE");
        END;
        PrintAString(NoteString);
        PRINT>*)

        IF (Moved) THEN
            Moved := MoveALAPs(EndOfSchedule, 
                               ScheduledList, 
                               TaskCount,
                               ToGo);
            IF SchedulingAbandoned THEN
                RETURN;
            END;
            (*<PRINT
            SetString(NoteString, "MoveTasks: Moved = ");
            IF Moved THEN
              ConcatS(NoteString, "TRUE");
            ELSE
              ConcatS(NoteString, "FALSE");
            END;
            PrintAString(NoteString);
            PRINT>*)
        END;
        IF (Moved) THEN
            Moved := MoveASAPs(ScheduledList, 
                               TaskCount,
                               ToGo);
            IF SchedulingAbandoned THEN
                RETURN;
            END;
        END;
    UNTIL (NOT Moved);

END MoveTasks;


PROCEDURE EndOfLatestTaskOnList(List:AnExtHandle):ADate;
VAR
    Task : ATaskPtr;
    TaskHandle, TempHandle : AnExtHandle;
    EndOfSchedule : ADate;
    EarlyEnd : ADate;
BEGIN
    EndOfSchedule := MinDate;
        (*  Find the latest end date of any task. *)
    TaskHandle := List;
    IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

    LOOP
        TempHandle := Task^.Nextlink;
        ReleaseUnchangedObject(TaskHandle);     (*<KILL*)  Task := NIL; (*KILL>*)
        TaskHandle := TempHandle;

        IF (ObjectsAreSame(TaskHandle,List)) THEN
    EXIT;
        END;
        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

        EarlyEnd := Task^.Plan.Dates.EarlyEnd;
        IF (EarlyEnd > EndOfSchedule) THEN
            EndOfSchedule := EarlyEnd;
        END;
    END;
    RETURN EndOfSchedule;
END EndOfLatestTaskOnList;



(* ------ TaskIsMovable -----------------------------------------

  Returns TRUE iff task could theoretically be moved.
*)

PROCEDURE TaskIsMovable(Task : ATaskPtr;
                        EndOfSchedule : ADate) : BOOLEAN;
VAR
    Movable: BOOLEAN;
BEGIN

        IF (Task^.StartDateLowerBound <> Task^.StartDateUpperBound) AND
             (NOT (AlreadyScheduled IN Task^.TempTaskFlags)) AND
             (NOT (FrozenTask IN Task^.TaskFlags)) AND
             (NOT (NeedsRecalculate IN Task^.TaskStatusSet)) AND
             (NOT (TerminalFlag IN Task^.TempTaskFlags)) THEN
               (* we can move an ASAP only if it's not at the lower bound: *)
           IF (Task^.fixation <> ALAP) THEN
               Movable := (Task^.count > LatestAntecedantEndDate
                                            (Task,
                                             Task^.StartDateLowerBound));
               (* we can move an ALAP only if it's not at the upper bound: *)
           ELSE
               Movable := (
                            (Task^.Plan.Dates.EarlyEnd < 
                                 EarliestDescendantStartDate
                                      (Task, EndOfSchedule)) 
                           AND
                            (Task^.count < Task^.StartDateUpperBound)
                          );
           END;
        ELSE
            Movable := FALSE;
        END;
    (*<PRINT
    IF Movable THEN 
        SetString(NoteString, " task is potentially movable");
    ELSE    
        SetString(NoteString, " task is not potentially movable");
    END;
    PRINT>*)

    RETURN Movable;

END TaskIsMovable;


END ResAlaps.

