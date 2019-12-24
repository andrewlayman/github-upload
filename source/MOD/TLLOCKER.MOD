MODULE TLLocker;

    (* This subprogram will set allow a user to interrogate the "Locked
       Dates" status of a task.  If that is changed, the changed is made
       to all child tasks as well.  We notify the Undo module of each
       changed task (and this can absorb a lot of memory.
    *)

    (* MODIFICATION HISTORY

       18-Aug-88  AJL   Version 1.
        4-Jun-89  EGK   Changed NotifyUndo call into a SendNotices call.
       09-Aug-89  KKC   Add copyright message.
       12-Sep-90  CL    Rename the former Plan.Dates.FixedStart field to
                        UserEnteredStartDate and change its format
                        from ADate to ABigTime.
        1-Nov-90  CL   	Rename LockScheduledDates to FrozenTask. 
    *)


FROM Allocs             IMPORT
    (* TYPE *)          ATaskFlag, ATaskFlagSet, ATaskPtr, AStartStatus,
                        AFixType;

FROM Chart              IMPORT
    (* VAR *)           CursorTask, GanttChart;

FROM ChartControl       IMPORT
    (* TYPE *)          AChartState,
    (* PROC *)          UnSetState;

FROM Dialog             IMPORT
    (* TYPE *)          ADialogOption,
    (* PROC *)          MultipleChoiceBox;

FROM LStrings           IMPORT
    (* PROC *)          SetString, Copy, ConcatS, ConcatLS;

FROM Keys               IMPORT
    (* CONST *)         ExitKey, CancelKey, DoIt;

FROM Notices            IMPORT
    (* TYPE *)              AnOccasion, AStep,
    (* PROC *)              SendNotices;

FROM Schedule           IMPORT
    (* VAR *)           ScheduleSaved;

FROM SYSTEM             IMPORT ADDRESS, ADR;

FROM TimeXlate          IMPORT
    (* PROC *)          CalendarTimeToBigTime;

FROM TreeObjects        IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder,
    (* PROC *)          ValidateTree, ValidateTreeNode;

IMPORT Undo;
FROM Undo               IMPORT
    (* TYPE *)          AnUndoableObject, AnUndoAction,
    (* PROC *)          NotifyUndo,
                        BeginTransactionSet, EndTransactionSet;



PROCEDURE ResetOneTaskNode ( VAR TaskNode : ATreeNode; Context : ADDRESS);
VAR
    Task : ATaskPtr;
    FreezeIt : POINTER TO BOOLEAN;
    OldSetting : BOOLEAN;

BEGIN
    FreezeIt := Context;

    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    OldSetting := (FrozenTask IN Task^.TaskFlags);

       (* Only record for Undo the actual changes. *)

    IF (FreezeIt^ <> OldSetting) THEN
        UnSetState (Scheduled);
        SendNotices (ChangeATask, BeforeActing, TaskNode);   (* 6/4/89 EGK *)
            (* Change the task. *)
        IF (FreezeIt^) THEN
            WITH Task^ DO
                INCL(TaskFlags,FrozenTask);
                     (* If the task does not have a user-entered start date,
                        lock it to its current, computed start date. *)
                IF (StartStatus = FutureS) AND (fixation <> FixedDate) THEN
                    CalendarTimeToBigTime(Plan.Dates.EarlyStart,TRUE,UserEnteredStartDate);
                END;
            END;
        ELSE
            EXCL(Task^.TaskFlags,FrozenTask);
        END;
    END;

    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

END ResetOneTaskNode;



PROCEDURE FreezeThisTask( TaskNode : ATreeNode; FreezeIt : BOOLEAN );
VAR
    Task : ATaskPtr;
    SubTree : ATree;
BEGIN
    ResetOneTaskNode(TaskNode,ADR(FreezeIt));

        (* Freeze or thaw all child tasks. *)
    SubTree := TaskNode^.Methods^.GetSubtree(TaskNode);
    IF (SubTree <> ATree(NIL)) THEN
        SubTree^.Methods^.TraverseTree(SubTree,ParentBeforeChild,
                                    MAX(CARDINAL),ResetOneTaskNode,
                                    ADR(FreezeIt));
    END;

END FreezeThisTask;



PROCEDURE Choose();
VAR
    S : ARRAY [0..255] OF CHAR;
    Title, Prefix, Choices : ARRAY [0..41] OF CHAR;
    Choice : CARDINAL;
    Task : ATaskPtr;
    Copyright : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Task := CursorTask^.Methods^.LockFlexStorDataObject(CursorTask);
    Copy(Task^.taskname,S);
    ConcatS(S,"üüTasks can be locked or unlocked.  When a summary task ");
    ConcatS(S,"is changed, so are all its child tasks.");

    SetString(Title,"Lock or Unlock Task Dates");
    SetString(Prefix,"LOCKED");
    SetString(Choices,"No,Yes");
    Choice := ORD( (FrozenTask IN Task^.TaskFlags) ) + 1;
    CursorTask^.Methods^.UnlockFlexStorDataObject(CursorTask);

    IF (MultipleChoiceBox(S,Title,OfferHelp,Prefix,Choices,Choice)) THEN
        NotifyUndo(Undo.Task,ChartActive,GanttChart);
        BeginTransactionSet();
        FreezeThisTask(CursorTask,VAL(BOOLEAN,Choice-1));
        EndTransactionSet();
        ScheduleSaved := FALSE;
    END;

END Choose;



BEGIN
    Choose();
END TLLocker.
