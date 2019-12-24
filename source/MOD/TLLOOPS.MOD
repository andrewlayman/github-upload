MODULE TLLoops;

    (*V1=PRODUCTION*)
    (*V2=KILL pointers on release of FlexStor handles. *)

(*  =========================================================================
    Last Edit : September 15, 1989 1:53PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

       Dec. 10, 87  AJL - Added FlexStor.
                        - Fixed for new PTaskLis exports, and new
                          Phantoms.
       12-Jan-88 RSC    "Unchanged" fixes.

       17-Feb-88 LAA    Removed calls to HeapAvailable and SetHeapLevels.
       09-Aug-89 KKC    Add copyright message.
       15-Sep-89 WKH    Set PackageOK to FALSE if we detect a loop.
       24-Aug-90 AJL    - The PhantomsFlag and SummaryFlag are now in
                          TempTaskFlags.

    =========================================================================
*)


FROM Allocs        IMPORT ATaskPtr, ATaskStatus,
                          ATaskStatusSet, ATaskFlag;

FROM Dialog        IMPORT ADialogOption, WarningBox, FatalError;

FROM Edges          IMPORT
    (* TYPE *)          AnEdgePtr;

FROM FlexStor       IMPORT
    (* TYPE *)     AnExtHandle, AnExtStoragePreference,
    (* PROC *)     InitExtStorage, TerminateExtStorage,
                   CreateExtObject, SetExtData, GetExtData,
                   CreateExtObjectWithSize, SetExtSize, GetExtSize,
                   DiscardExtObject,
                   HandleIsValid, ObjectsAreSame,
                   SaveHeapCopy, MakeHeapCopy,
                   LockObject, LockObjectArray, ReleaseObject,
                   ArraySize, NumberOfElements, ReleaseUnchangedObject,
                   CopyExtObject;

FROM LStrings      IMPORT SetString, ConcatS;

FROM MsgFile       IMPORT GetMessage;

FROM Overlays      IMPORT PackageOK;

FROM Phantoms      IMPORT SummaryFlag, PhantomFlag;

FROM PTaskList     IMPORT PrivateTaskList;

FROM TreeObjects   IMPORT ATreeNode;


CONST
    ModuleNumber = 12500;



PROCEDURE Complain;
VAR
    S   : ARRAY [0..255] OF CHAR;
    Title : ARRAY [0..20] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,Title); (* "Loop Detected" *)
    GetMessage(ModuleNumber+2,S);
        (*   'Your schedule has a LOOP in it.$When you return to the Gantt chart, try UNDO [Shift-F10].' *)
        (*   '$(Tasks with an "L" in the STATUS column are in the loop.)$Press [Esc] to continue.'       *)
    WarningBox(S,Title,OfferHelp);
END Complain;




     (*  FINDANYLOOP -- Locate which tasks are part of a loop.  Mark them
                        by setting their status sets to include Loop.

                        See Knuth, F.A., vol. 1, sec. 2.2.3, exercise 23. *)

PROCEDURE FindAnyLoop;
VAR
    taskHandle, NextHandle, PrevHandle, suctaskHandle, TempHandle  : AnExtHandle;
    task, NextTask  : ATaskPtr;
    edge            : AnEdgePtr;
    Node            : ATreeNode;
    k               : CARDINAL;
    Copyright       : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
        (* At this point, tasks which may be part of the loop have
           Loop in their TaskStatusSet. *)

        (* Set all Prevlinks to NIL. *)

    IF (LockObject(PrivateTaskList,task)=0) THEN FatalError(); END;
    taskHandle := task^.Nextlink;
    ReleaseUnchangedObject(PrivateTaskList);         (*<KILL*) task := NIL; (*KILL>*)

    WHILE (NOT ObjectsAreSame(taskHandle,PrivateTaskList)) DO
        IF (LockObject(taskHandle,task)=0) THEN FatalError(); END;
        task^.count := 99;
        task^.Prevlink := AnExtHandle(NIL);

        NextHandle := task^.Nextlink;
        ReleaseObject(taskHandle);          (*<KILL*) task := NIL; (*KILL>*)
        taskHandle := NextHandle;
    END;

        (* Steps 9 and 10.  Loop not in TaskStatusSet is equivalent to
           p = NIL (lambda)

           The effect of this loop is to set task^.Prevlink to an
           antecedant task, for each antecedant task that might
           be part of the loop.

           Count is set to 0 for all visited tasks.

        *)

    IF (LockObject(PrivateTaskList,task)=0) THEN FatalError(); END;
    taskHandle := task^.Nextlink;
    ReleaseUnchangedObject(PrivateTaskList);         (*<KILL*) task := NIL; (*KILL>*)

    WHILE (NOT ObjectsAreSame(taskHandle,PrivateTaskList)) DO
      IF (LockObject(taskHandle,task)=0) THEN FatalError(); END;
      WITH task^ DO
        IF (Loop IN TaskStatusSet) THEN
            TaskStatusSet := ATaskStatusSet{NeedsRecalculate};
                (* TASK might be part of the loop. *)
            edge := desctasks;                       (* p := top(k) *)
            count := 0;                              (* top(k) := 0 *)
                (* Examine each descendant task. *)
            WHILE (edge <> NIL) DO             (* IF p = lambda . . . *)
                Node    := edge^.tailtask;
                NextTask := Node^.Methods^.LockFlexStorDataObject(Node);
                    (* If Prevlink isn't already filled in,
                      make it point to task. *)
                IF (ObjectsAreSame(NextTask^.Prevlink,AnExtHandle(NIL))) THEN    (* IF qlink(suc(p))... *)
                    NextTask^.Prevlink := taskHandle;
                    Node^.Methods^.UnlockFlexStorDataObject(Node);
                ELSE
                    Node^.Methods^.UnlockUnchangedDataObject(Node);
                END;
                                    (*<KILL*) NextTask := NIL; (*KILL>*)
                edge := edge^.headlink
            END;
        ELSE
            count := 0;
            TaskStatusSet := ATaskStatusSet{NeedsRecalculate};
        END;
      END;
      NextHandle := task^.Nextlink;
      ReleaseObject(taskHandle);    (*<KILL*)  task := NIL; (*KILL>*)
      taskHandle := NextHandle;
    END;

        (* Step 11.  Find a task that does not have its Prevlink NIL.
           In other words, find a task with an antecedant that might be
           part of the loop. *)

    IF (LockObject(PrivateTaskList,task)=0) THEN FatalError(); END;
    taskHandle := task^.Nextlink;
    ReleaseUnchangedObject(PrivateTaskList);  (*<KILL*) task := NIL; (*KILL>*)
    IF (LockObject(taskHandle,task)=0) THEN FatalError(); END;

    WHILE (NOT ObjectsAreSame(taskHandle,PrivateTaskList)) AND
          (ObjectsAreSame(task^.Prevlink,AnExtHandle(NIL))) DO
        NextHandle := task^.Nextlink;
        ReleaseUnchangedObject(taskHandle);   (*<KILL*) task := NIL; (*KILL>*)
        taskHandle := NextHandle;
        IF (LockObject(taskHandle,task)=0) THEN FatalError(); END;
    END;

        (* Step 12.  Search through the tasks, marking each one '1'
           as we go.  When we hit one we've already marked, then we
           are somewhere in the loop. *)

    REPEAT
        task^.count  := 1;                       (* top(k) := 1   *)
        PrevHandle := task^.Prevlink;            (* k := qlink(k) *)
        ReleaseObject(taskHandle);               (*<KILL*) task := NIL; (*KILL>*)
        taskHandle := PrevHandle;
        IF (LockObject(taskHandle,task)=0) THEN FatalError(); END;
    UNTIL (task^.count <> 0);


        (* Step 13.  For each task in the loop, mark it with the
          status of "L". *)

    REPEAT
        WITH task^ DO
            TaskStatusSet := ATaskStatusSet{NeedsRecalculate,Loop};
                (* If a phantom task ender (for a summary task) is
                   in a loop, mark the real task. *)
            IF (PhantomFlag IN TempTaskFlags) AND (SummaryFlag IN TempTaskFlags) THEN
                Node := ATreeNode(WorkSpace);
                Node := Node^.Methods^.GetPrev(Node);  (* Real task node. *)
                NextTask := Node^.Methods^.LockFlexStorDataObject(Node);
                NextTask^.TaskStatusSet := ATaskStatusSet{NeedsRecalculate,Loop};
                Node^.Methods^.UnlockFlexStorDataObject(Node);
                                                 (*<KILL*) NextTask := NIL; (*KILL>*)
            END;
            count := 0;                          (* top(k) := 0   *)
        END;
        PrevHandle := task^.Prevlink;            (* k := qlink(k) *)
        ReleaseObject(taskHandle);               (*<KILL*) task := NIL; (*KILL>*)
        taskHandle := PrevHandle;
        IF (LockObject(taskHandle,task)=0) THEN FatalError(); END;
    UNTIL (task^.count <> 1);

    ReleaseObject(taskHandle);                   (*<KILL*) task := NIL; (*KILL>*)

        (* Step 14 is omitted, since we DO not want to print out
          the list of tasks, only mark them. *)

        (* Go through all of the tasks and rebuild the prev links *)

    IF (LockObject(PrivateTaskList,task)=0) THEN FatalError(); END;
    taskHandle := task^.Nextlink;
    ReleaseUnchangedObject(PrivateTaskList);  (*<KILL*) task := NIL; (*KILL>*)
    PrevHandle := taskHandle;        (* Sentinel *)

    IF (LockObject(taskHandle,task)=0) THEN FatalError(); END;
    NextHandle := task^.Nextlink;
    ReleaseUnchangedObject(taskHandle);       (*<KILL*) task := NIL; (*KILL>*)
    IF (LockObject(NextHandle,NextTask)=0) THEN FatalError(); END;

    REPEAT
        NextTask^.Prevlink := taskHandle;
        taskHandle := NextHandle;
        NextHandle := NextTask^.Nextlink;
        ReleaseObject(taskHandle);    (*<KILL*)  NextTask := NIL; (*KILL>*)
        IF (LockObject(NextHandle,NextTask)=0) THEN FatalError(); END;
    UNTIL (ObjectsAreSame(taskHandle,PrevHandle));

    ReleaseObject(NextHandle);        (*<KILL*)  NextTask := NIL; (*KILL>*)

END FindAnyLoop;









BEGIN
    Complain;
    PackageOK := FALSE;  (* 15-Sep-89 WKH *)
    FindAnyLoop;
END TLLoops.
