IMPLEMENTATION MODULE FixPhantoms;
(*V2=PRINT WITH debugging printouts. *)
(*

   MODIFICATION HISTORY

    Sep 15, 89 - JES -created
     30-Mar-90   RSC  Made Timeu to Timei/TimeForm conversions.
    Sept 17, 89  JES -fixed some obsolete imports.
    Oct. 16, 90  AJL -Fixed some imports wheich were moved to another
                      module, formerly in ResBumpT.
    Oct. 30, 90  CL  -Removed unused MaxDate from IMPORT.
    Mar  8, 91 - JES -Fixed AdjustPhantoms so uses StartDateLowerBound
                        instead of the count field of the task.
    May 30, 91 - JES -Changed AdjustPhantoms so it uses ToGo as a
                        real in parameter (and not just sets it
                        to TaskCount), to support use of the AlreadyScheduled
                        list in Tlrplan.
*)

FROM Allocs         IMPORT
    (* CONST *)             WBSLine,
    (* TYPE *)              ATaskPtr, ATask, AFixType, ATaskStatus, ATaskFlag;

FROM Dialog         IMPORT
    (* PROC *)              FatalError;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, LockObject, ReleaseObject, LockObjectArray,
                            ReleaseUnchangedObject, ObjectsAreSame;

FROM LStrings       IMPORT    
    (* PROC *)              SetString;

FROM Phantoms       IMPORT
    (* CONST *)         SummaryFlag, PhantomFlag;

FROM ResConstants   IMPORT
    (* CONST *)             ModuleNumber, HowOften2, Zero,
    (* VAR   *)             SchedulingAbandoned; 

FROM ResUtilities  IMPORT
    (* PROC *)              LatestAntecedantEndDate;


FROM PTaskList    IMPORT
    (* PROC *)              AddBefore, AddLowDate, DeList, CountDown,
                            TerminalFlag;

FROM ResWarnings  IMPORT    IssueWarning, AWarning;
    (* PROC *)

FROM SYSTEM       IMPORT    TSIZE;
    (* PROC *)


FROM Timei          IMPORT
    (* TYPE *)              ADate, MinDate;

(*  ------------------------ Import if tracing ------------------*)
(*<PRINT
FROM LStrings     IMPORT ConcatS, ConcatLS, CtoS;
FROM PrintSupport IMPORT StartReport, PrintLine, EndReport;
FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat; 
FROM ResTrace     IMPORT NoteString, PrintAString, ConcatTaskID;
FROM TimeFormat   IMPORT TimeUtoS;     

VAR
    s : ARRAY [0..255] OF CHAR;
PRINT>*)


PROCEDURE AdjustPhantoms(ScheduledList : AnExtHandle;
                         TaskCount     : CARDINAL;
                         ToGo          : CARDINAL);
CONST
    LocalCountDown = ModuleNumber+6;
VAR
    Task  : ATaskPtr;
    TaskHandle, NextTaskHandle : AnExtHandle;
    s     : ARRAY [0..80] OF CHAR;
BEGIN
(*<PRINT
SetString(NoteString,"------AdjustPhantoms");
PrintAString(NoteString);
PRINT>*)


    CountDown(LocalCountDown,TaskCount,ToGo);

        (*  Run forwards through the task list, moving phantom summary tasks
            back in time. Note: it is very important that this
            procedure never move a task later in time, since the
            loop moves forward through the task list, and it would
            not end! *)

    IF (LockObject(ScheduledList,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(ScheduledList);               (*<KILL Task := NIL; KILL>*)
    WHILE (NOT ObjectsAreSame(TaskHandle,ScheduledList)) DO
        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
        IF ( (ToGo MOD HowOften2) = 0 ) THEN
            CountDown(LocalCountDown,TaskCount,ToGo);
        END;
        NextTaskHandle := Task^.Nextlink;
        IF (PhantomFlag IN Task^.TempTaskFlags) AND
           (SummaryFlag IN Task^.TempTaskFlags) THEN
               AdjustThisPhantomTask(TaskHandle, 
                                     Task, 
                                     ScheduledList);
        END;
        ReleaseObject(TaskHandle);          (*<KILL Task := NIL; KILL>*)
        TaskHandle := NextTaskHandle;
        DEC(ToGo);
    END;

END AdjustPhantoms;


PROCEDURE AdjustThisPhantomTask(TaskHandle    : AnExtHandle;
                                Task          : ATaskPtr;
                                ScheduledList : AnExtHandle);
VAR
    Day : ADate;
    TheNextTaskHandle : AnExtHandle;
BEGIN
        (* It is very important that this routine NEVER move a task
           later in the list.  Otherwise, the calling procedure may
           loop forever, since it scans in a forward direction. *)


    TheNextTaskHandle := Task^.Nextlink;  (* Save our place in line. *)
    DeList(TaskHandle);                   (* Remove it so it isn't counted *)

        (* Limit backward movement to the earliest possible start date: *)

        (* Compute earliest possible start point. *)

    Day := LatestAntecedantEndDate(Task, Task^.StartDateLowerBound);



        (*  At this point, Day is the earliest start date for
            task.   If this date is before the current start of
            the task, move the task backward in the scheduled
            list. *)

    IF (Day < Task^.Plan.Dates.EarlyStart) THEN
        (*<PRINT
        SetString(NoteString, "adjusting phantom :");
        ConcatTaskID(NoteString,Task);
        PrintAString(NoteString);  
        SetString(NoteString, "original early start was :");
        TimeUtoS(Task^.Plan.Dates.EarlyStart, s);  ConcatLS(NoteString, s);
        PrintAString(NoteString);  
        SetString(NoteString, "resetting to equal lower bound of :");
        TimeUtoS(Day, s);  ConcatLS(NoteString, s);
        PrintAString(NoteString);
        PRINT>*)
        Task^.Plan.Dates.EarlyStart := Day;
        Task^.Plan.Dates.EarlyEnd   := Day;
        AddLowDate(ScheduledList,TaskHandle,Task);  (* Earlier spot in the list. *)
    ELSE
        AddBefore(TheNextTaskHandle,TaskHandle);     (* Back where we came from. *)
    END;



END AdjustThisPhantomTask;


PROCEDURE EndOfLatestTaskOnList(List:AnExtHandle):ADate;
VAR
    Task : ATaskPtr;
    TaskHandle, TempHandle : AnExtHandle;
    LateDate : ADate;
    EarlyEnd : ADate;
BEGIN
    LateDate := MinDate;
        (*  Find the latest end date of any task. *)
    TaskHandle := List;
    IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

    LOOP
        TempHandle := Task^.Nextlink;
        ReleaseUnchangedObject(TaskHandle);     (*<KILL  Task := NIL; KILL>*)
        TaskHandle := TempHandle;

        IF (ObjectsAreSame(TaskHandle,List)) THEN
    EXIT;
        END;
        IF LockObject(TaskHandle,Task)=0 THEN FatalError(); END;

        EarlyEnd := Task^.Plan.Dates.EarlyEnd;
        IF (EarlyEnd > LateDate) THEN
            LateDate := EarlyEnd;
        END;
    END;
    RETURN LateDate;

END EndOfLatestTaskOnList;



END FixPhantoms.
