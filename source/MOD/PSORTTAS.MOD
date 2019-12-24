IMPLEMENTATION MODULE PSortTaskList;

    (* MODIFICATION HISTORY:

       Sep. 22, 89  AJL -Created by moving code here from PTaskList.
       9 Apr 91 JES  - Made version of InsertInOrder called 
                       InsertLockedTaskInOrder that takes
                       an already locked task.
    *)



FROM Allocs        IMPORT
    (* TYPE *)         ATask, ATaskPtr;

FROM Dialog IMPORT
    (* PROC *)               FatalError;

FROM FlexStor       IMPORT
    (* TYPE *)     AnExtHandle, AnExtStoragePreference,
    (* PROC *)     InitExtStorage, TerminateExtStorage,
                   CreateExtObject, SetExtData, GetExtData,
                   CreateExtObjectWithSize, SetExtSize, GetExtSize,
                   DiscardExtObject,
                   HandleIsValid, ObjectsAreSame,
                   SaveHeapCopy, MakeHeapCopy,
                   LockObject, LockObjectArray, ReleaseObject,
                   ReleaseUnchangedObject,
                   ArraySize, NumberOfElements,
                   CopyExtObject;


FROM PTaskList    IMPORT
    (* CONST *)         TerminalFlag,
    (* VAR  *)          PrivateTaskList, TaskCount,
                        BoxHandle, BoxShowing, SpaceReserved,
    (* PROC *)          ListInit, AddBefore, DeList,
                        MoveList,
                        CountDown;


CONST
    HowOften = 32;


PROCEDURE InsertInOrder(List, TaskHandle: AnExtHandle; Compare:APTaskListCompareProc);
VAR
    p, Nextp : AnExtHandle;
    pTask, Task : ATaskPtr;
BEGIN
    IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
    InsertLockedTaskInOrder(List, TaskHandle, Task, Compare);
    ReleaseUnchangedObject(TaskHandle); (* RSC 9/20/88 was "ReleaseObject" *)
END InsertInOrder;
    


PROCEDURE InsertLockedTaskInOrder(List, TaskHandle: AnExtHandle; 
                                  Task : ATaskPtr;       
                                  Compare:APTaskListCompareProc);

VAR
    p, Nextp : AnExtHandle;
    pTask    : ATaskPtr;
BEGIN
    IF (LockObject(List,pTask)=0) THEN FatalError(); END;
    p := pTask^.Nextlink;
    ReleaseUnchangedObject(List); (* RSC 9/20/88 was "ReleaseObject" *)
        (*<KILL pTask := NIL; KILL>*)

       (* The compare proc operates on (a: ATaskPtr, b: AnExtHandle. The
          task b will probably be locked and released by the compare proc. *)

    WHILE (NOT (ObjectsAreSame(p,List))) AND Compare(Task,p) DO
        IF (LockObject(p,pTask) = 0) THEN FatalError(); END;
        Nextp := pTask^.Nextlink;
        ReleaseUnchangedObject(p);  (* RSC 9/20/88 was "ReleaseObject" *)
                (*<KILL pTask := NIL; KILL>*)
        p := Nextp;
    END;

        (*<KILL Task := NIL; KILL>*)
    DeList(TaskHandle);                                                 
    AddBefore(p,TaskHandle);


END InsertLockedTaskInOrder;



PROCEDURE InsertionSortTasks(Compare:APTaskListCompareProc) : BOOLEAN;
    (* Insertion sort.  See Knuth, vol 3, section 5.2.1. *)
VAR
    r0, j: AnExtHandle;
    PrivateTask : ATaskPtr;
    ToGo : CARDINAL; 
BEGIN
        (*  Make an empty list. *)

    IF NOT ListInit(r0) THEN
        RETURN FALSE;
    END;

        (*  Read through the task list backwards.  Put each removed
            task into the r0 list, in order. *)

    ToGo := TaskCount;

    LOOP
        IF (LockObject(PrivateTaskList,PrivateTask) = 0) THEN
            FatalError();
        END;
        j := PrivateTask^.Prevlink;
        ReleaseUnchangedObject(PrivateTaskList); (* RSC 9/20/88 was "ReleaseObject" *)
            (*<KILL PrivateTask := NIL; KILL>*)
        IF (ObjectsAreSame(j,PrivateTaskList)) THEN
    EXIT;
        END;

        InsertInOrder(r0,j,Compare);

        DEC(ToGo);
        IF (ToGo MOD HowOften) = 0 THEN
            CountDown(3917,TaskCount,ToGo);
        END;

    END;

        (*  Move all of the tasks onto the TaskList, and discard r0. *)

    MoveList(PrivateTaskList,r0);

    DiscardExtObject(r0);

    RETURN TRUE;
END InsertionSortTasks;







END PSortTaskList.
