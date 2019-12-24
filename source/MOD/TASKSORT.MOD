(*----------------------------------------------------------------------------
    MODIFICATION HISTORY

    12/05/86 LAA    Added sorting by WBS, OBS, and AUX, and eliminated sorting
                    on the second line of notes.
       Jan. 5, 1986   AJL - Added QuickSort procedure to speed up 
                            sorting on task names.  Hopefully, this 
                            won't slow down date sorting too badly. 
                          - Test this program by running through the
                            version program with command
                            VERSION SORTER/2 TESTSORT 
                            Compile, then link using TLRPBASE as
                            map file.   Run as a report overlay.
    May 25, 1987 AJL      - Modified to use the TreeSort module.
                          - String comparison no longer stops at a "/".
                          - The Y field in tasks (topological order) is
                            no longer used.
    24-Jun-87 LAA         - Changed the definition of ASortType to accomodate
                            the new sorts on the display form.
    29-Jun-87 AJL         - Added notices.
    04-Aug-87 LAA         - Incorporated named layouts.
    11-Jan-88 LAA         - Changed UnlockFlexStorDataObject to 
                            UnlockUnchangedDataObject.
    03-May-89 EGK         - Changed the compare procs to use the new scheme
                            for getting WBS, OBS, and AUX from a task.
    04-Jun-89 EGK           Put in explicit call to SendNotices since
                            Permission doesn't do it automatically.
----------------------------------------------------------------------------*)

IMPLEMENTATION MODULE TaskSort;


    (* ESSAY: AJL Dec. 18, 1986 

           Sorting can sometimes take an extraordinarily long time. 
       For example, sometimes the user will put WBS number at the start 
       of a task name or notes field, and will sort based on this.
       Partly because these numbers have a lot of leading characters in 
       common, because this method is used for large schedules, because 
       string comparisons are slower than date comparisons, and because 
       the schedule calculations totally jumble the alphabetic order of 
       tasks, this can run very slowly. 

           Several improvements are possible.  First, obviously, we could 
       increase speed by using a better sorting algorithm.   Heap sort
       comes to mind since it is guaranteed N ln N, and can easily use
       the next and prev links. 

           But we can also get improved perceived performance by observing
       that the displayed sort order doesn't change very much from one time to
       the next (unless the user selects a new sort key).  This suggests that 
       if we record the sort order obtained last time, restore the tasks to 
       this order, then make any minor corrections (using an algorithm such as
       insertion sort that works very efficiently of nearly sorted lists) we
       should get seemingly very rapid sorts. 

           This would probably require that we expand each task's record to 
       contain a cardinal sequence number from the last sort, and us to 
       keep a record of the last sort key used, so that we can decide if
       those sequence numbers are still useful. 

           Also, on any change to a task that does not involve recalculating
       the schedule, we could merely move that task to its correct place in 
       the list, without forcing a resort of all tasks. 

       Note: At one point, I thought of allowing CtrlBreak to cancel a
             sorting.  This is not safe, since we do not know what procedure
             is calling us, and the caller may depend on the sort running 
             to completion. 

    *)


FROM Allocs       IMPORT ATaskPtr, ATask, TaskTree,
                         WBSLine, OBSLine, AUXLine, WBSLen, OBSLen, AUXLen,
                         GetCodingField;

FROM ChartForms   IMPORT CurrentLayout, AChartFormatPtr;

FROM Dialog       IMPORT FatalError, NotYetImplemented;

FROM Gantt        IMPORT ASlackStyle;

FROM LStrings     IMPORT Compare, Search, Fill; 

FROM Notices      IMPORT
    (* TYPE *)            AnOccasion, AStep,
    (* PROC *)            Permission, SendNotices;

FROM Objects      IMPORT AnObject;

FROM TreeObjects  IMPORT ATreeNode;

FROM Sorter       IMPORT SortTree, AnObjectCompareProc;






PROCEDURE SortTasksInStandardOrder(SortType:ASortType);
BEGIN
    CASE SortType OF
        SortByName:    SortTasks(CompTaskByAlpha);
      | SortByDate:    SortTasks(CompTaskByDate);
      | SortWBS:       SortTasks(CompTaskByWBS);
      | SortOBS:       SortTasks(CompTaskByOBS);
      | SortAUX:       SortTasks(CompTaskByAUX);
      | SortByEndDate: SortTasks(CompTaskByEndDate);
      | SortSlack:     SortTasks(CompTaskBySlack);
      | SortByPriority:SortTasks(CompTaskByPriority);
    END;
END SortTasksInStandardOrder;









PROCEDURE SortTasks( Compare : ATaskCompareProc );
BEGIN
    IF (Permission(ScheduleSort,NIL)) THEN
        SendNotices (ScheduleSort, BeforeActing, NIL);      (* 6/4/89 EGK *)
        SortTree(TaskTree,AnObjectCompareProc(Compare));
        SendNotices(ScheduleSort,AfterActing,NIL);
    END;
END SortTasks;








    (* COMPTASK -- Returns TRUE iff a > b. *)

PROCEDURE CompTaskByDate(TaskA, TaskB :ATreeNode) : BOOLEAN;
VAR
    a           : ATaskPtr;
    b           : ATaskPtr;
    Result      : BOOLEAN;

BEGIN
        (* The comparisons of the duration and lateenddate will
           not be meaningful if resource scheduling is applied
           later, but they don't hurt, either. *)

    a := TaskA^.Methods^.LockFlexStorDataObject(TaskA);
    b := TaskB^.Methods^.LockFlexStorDataObject(TaskB);
    Result := FALSE;

    WITH a^ DO
        IF (Plan.Dates.EarlyStart > b^.Plan.Dates.EarlyStart) THEN Result := TRUE;
        ELSIF (Plan.Dates.EarlyStart = b^.Plan.Dates.EarlyStart) THEN
            IF (duration > b^.duration) THEN Result := TRUE;
            ELSIF (duration = b^.duration) THEN
                IF (Plan.Dates.LateTotalEnd > b^.Plan.Dates.LateTotalEnd) THEN Result := TRUE;
                ELSIF (Plan.Dates.LateTotalEnd = b^.Plan.Dates.LateTotalEnd) THEN
                    Result := (Compare(taskname,b^.taskname) > 0);
                END;
            END;
        END;
    END;

    TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);             (* 11-Jan-88 LAA *)
    TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);
    RETURN Result;
END CompTaskByDate;







PROCEDURE CompTaskByEndDate(TaskA, TaskB :ATreeNode) : BOOLEAN;
VAR
    a           : ATaskPtr;
    b           : ATaskPtr;
    Result      : BOOLEAN;

BEGIN
        (* The comparisons of the duration and lateenddate will
           not be meaningful if resource scheduling is applied
           later, but they don't hurt, either. *)

    a := TaskA^.Methods^.LockFlexStorDataObject(TaskA);
    b := TaskB^.Methods^.LockFlexStorDataObject(TaskB);
    Result := TRUE;

    WITH a^ DO
        IF (Plan.Dates.EarlyEnd > b^.Plan.Dates.EarlyEnd) THEN 
            Result := TRUE;
        ELSIF (Plan.Dates.EarlyEnd = b^.Plan.Dates.EarlyEnd) THEN
            IF (Plan.Dates.LateTotalEnd > b^.Plan.Dates.LateTotalEnd) THEN 
                Result := TRUE;
            ELSIF (Plan.Dates.LateTotalEnd = b^.Plan.Dates.LateTotalEnd) THEN
                Result := (Compare(taskname,b^.taskname) > 0);
            END;
        END;
    END;

    TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);             (* 11-Jan-88 LAA *)
    TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);
    RETURN Result;
END CompTaskByEndDate;






           


PROCEDURE CompTaskBySlack(TaskA, TaskB :ATreeNode) : BOOLEAN;
VAR
    a : ATaskPtr;
    b : ATaskPtr;
    ChartRecord             : AChartFormatPtr;
    Result                  : BOOLEAN;

BEGIN
        (* The comparisons of the duration and lateenddate will
           not be meaningful if resource scheduling is applied
           later, but they don't hurt, either. *)

    a := TaskA^.Methods^.LockFlexStorDataObject(TaskA);
    b := TaskB^.Methods^.LockFlexStorDataObject(TaskB);

    ChartRecord := CurrentLayout();

    WITH a^ DO
        IF (ChartRecord^.slackstyle = TotalSlack) THEN
            WITH Plan.Dates DO
                IF (LateTotalEnd - EarlyEnd > 
                    b^.Plan.Dates.LateTotalEnd - b^.Plan.Dates.EarlyEnd) THEN 
                    Result := TRUE;
                ELSIF (LateTotalEnd - EarlyEnd = 
                       b^.Plan.Dates.LateTotalEnd - b^.Plan.Dates.EarlyEnd) THEN
                    IF (LateTotalEnd > b^.Plan.Dates.LateTotalEnd) THEN 
                        Result := TRUE;
                    ELSIF (LateTotalEnd = b^.Plan.Dates.LateTotalEnd) THEN
                        Result :=  (Compare(taskname,b^.taskname) > 0);
                    END;
                END;
            END;
        ELSE
            WITH Plan.Dates DO
                IF (LateFreeEnd - EarlyEnd > 
                    b^.Plan.Dates.LateFreeEnd - b^.Plan.Dates.EarlyEnd) THEN 
                    Result := TRUE;
                ELSIF (LateFreeEnd - EarlyEnd = 
                       b^.Plan.Dates.LateFreeEnd - b^.Plan.Dates.EarlyEnd) THEN
                    IF (LateFreeEnd > b^.Plan.Dates.LateFreeEnd) THEN 
                        Result := TRUE;
                    ELSIF (LateFreeEnd = b^.Plan.Dates.LateFreeEnd) THEN
                        Result :=  (Compare(taskname,b^.taskname) > 0);
                    END;
                END;
            END;
        END;
    END;

    TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);             (* 11-Jan-88 LAA *)
    TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);
    RETURN Result;
END CompTaskBySlack;








    (* CompTaskByAlpha -- Returns TRUE iff a > b. *)

PROCEDURE CompTaskByAlpha(TaskA, TaskB :ATreeNode) : BOOLEAN;
VAR
    i           : INTEGER;
    a           : ATaskPtr;
    b           : ATaskPtr;

BEGIN
    a := TaskA^.Methods^.LockFlexStorDataObject(TaskA);
    b := TaskB^.Methods^.LockFlexStorDataObject(TaskB);

    i := Compare(a^.taskname,b^.taskname);

    TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);             (* 11-Jan-88 LAA *)
    TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);

    IF (i <> 0) THEN
        RETURN (i > 0);
    ELSE
        RETURN CompTaskByDate(TaskA,TaskB);
    END;
END CompTaskByAlpha;







PROCEDURE CompTaskByPriority(TaskA, TaskB :ATreeNode) : BOOLEAN;
VAR
    a           : ATaskPtr;
    b           : ATaskPtr;
    PriorA      : CARDINAL;
    PriorB      : CARDINAL;

BEGIN
    a := TaskA^.Methods^.LockFlexStorDataObject(TaskA);
    b := TaskB^.Methods^.LockFlexStorDataObject(TaskB);

    PriorA := a^.priority;
    PriorB := b^.priority;

    TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);             (* 11-Jan-88 LAA *)
    TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);

    IF (PriorA > PriorB) THEN
        RETURN TRUE;
    ELSIF (PriorA = PriorB) THEN
        RETURN CompTaskByDate(TaskA,TaskB);
    END;

END CompTaskByPriority;







PROCEDURE CompTaskByWBS(TaskA, TaskB :ATreeNode) : BOOLEAN;
VAR
    i : INTEGER;
    a : ATaskPtr;
    b : ATaskPtr;
    WBSA, WBSB          : ARRAY [0..WBSLen] OF CHAR;
BEGIN
    a := TaskA^.Methods^.LockFlexStorDataObject(TaskA);
    b := TaskB^.Methods^.LockFlexStorDataObject(TaskB);

    GetCodingField (a^, WBSLine, WBSA);
    GetCodingField (b^, WBSLine, WBSB);

    TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);             (* 11-Jan-88 LAA *)
    TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);

    i := Compare(a^.WBS,b^.WBS);
    IF (i <> 0) THEN
        RETURN (i > 0);
    ELSE
        RETURN CompTaskByDate(TaskA,TaskB);
    END;
END CompTaskByWBS;



PROCEDURE CompTaskByOBS(TaskA, TaskB :ATreeNode) : BOOLEAN;
VAR
    i : INTEGER;
    a : ATaskPtr;
    b : ATaskPtr;
    OBSA, OBSB          : ARRAY [0..OBSLen] OF CHAR;
BEGIN
    a := TaskA^.Methods^.LockFlexStorDataObject(TaskA);
    b := TaskB^.Methods^.LockFlexStorDataObject(TaskB);

    GetCodingField (a^, OBSLine, OBSA);
    GetCodingField (b^, OBSLine, OBSB);

    TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);             (* 11-Jan-88 LAA *)
    TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);

    i := Compare(a^.OBS,b^.OBS);
    IF (i <> 0) THEN
        RETURN (i > 0);
    ELSE
        RETURN CompTaskByDate(TaskA,TaskB);
    END;
END CompTaskByOBS;




PROCEDURE CompTaskByAUX(TaskA, TaskB :ATreeNode) : BOOLEAN;
VAR
    i : INTEGER;
    a : ATaskPtr;
    b : ATaskPtr;
    AUXA, AUXB          : ARRAY [0..AUXLen] OF CHAR;
BEGIN
    a := TaskA^.Methods^.LockFlexStorDataObject(TaskA);
    b := TaskB^.Methods^.LockFlexStorDataObject(TaskB);

    GetCodingField (a^, AUXLine, AUXA);
    GetCodingField (b^, AUXLine, AUXB);

    TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);             (* 11-Jan-88 LAA *)
    TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);

    i := Compare(a^.AUX,b^.AUX);
    IF (i <> 0) THEN
        RETURN (i > 0);
    ELSE
        RETURN CompTaskByDate(TaskA,TaskB);
    END;
END CompTaskByAUX;






BEGIN
END TaskSort.
