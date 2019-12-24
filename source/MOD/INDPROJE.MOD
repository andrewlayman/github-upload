IMPLEMENTATION MODULE IndProjects;


    (*--------------------------------------------------------------------

      IndProjects

      This module determines if the schedule consists of one connected network,
      or several unconnected networks (independent projects).  Each weakly
      connected network of task nodes is identified as a project.  For each
      such network, a single node is identified as a terminal node and marked
      as such.  This may require creating an extra node and adding it as a
      temporary, zero-length task to the network.

    -------------------------------------------------------------------- *)

    (*--------------------------------------------------------------------

       MODIFICATION HISTORY

        8-Sep-90  AJL -Moved code to here from TLCPM.
       16-Sep-90  AJL -Fill in the upper and lower bounds on the start
                       dates.
        1-Nov-90  CL - Rename UpperBoundStartDate to StartDateUpperBound,
                       LowerBoundStartDate to StartDateLowerBound,
                       SuppressSlack to ForceCritical.
                     - Fix the indentation for IMPORT section.
       27-Nov-90 AJL - Periodically report progress.
       28-Nov-90 AJL - Use MaybeCountDown.
    -----------------------------------------------------------------------*)

FROM Allocs    IMPORT
    (* CONST *)         TskNmLen,
    (* TYPE *)          ATask, ADateBlock, AnAssignmentSummary,
                        ATaskPtr, ATaskName, AFixType, ATempTaskFlagSet,
                        AStartStatus, ATaskFlag, ATaskFlagSet, ARollupStatus,
                        ATaskStatusSet, ATaskStatus, ADurationMethod,
    (* VAR *)           TaskTree,
                        StartStatusName,
    (* PROC *)          CheckTaskValid,
                        CreateTask, DelTask;


FROM Dialog    IMPORT   Message, Error, FatalError, Burp,
                        ProgressBox, ReleaseBox, ABoxHandle, WarningBox,
                        ADialogOption, NotYetImplemented;

FROM Edges     IMPORT
    (* TYPE *)          AnEdge, AnEdgePtr,
    (* PROC *)          CheckEdgeValid, FindEdge, DelEdge,
                        CreateEdge, AddEdge, RemoveEdge;

FROM FlexStor  IMPORT
    (* TYPE *)          AnExtHandle, AnExtStoragePreference,
    (* PROC *)          InitExtStorage, TerminateExtStorage,
                        CreateExtObject, SetExtData, GetExtData,
                        CreateExtObjectWithSize, SetExtSize, GetExtSize,
                        DiscardExtObject,
                        HandleIsValid, ObjectsAreSame,
                        SaveHeapCopy, MakeHeapCopy,
                        LockObject, LockObjectArray, ReleaseObject,
                        ReleaseUnchangedObject,
                        ArraySize, NumberOfElements,
                        CopyExtObject;


FROM Kbio      IMPORT   
    (* PROC *)          BreakRequested;

FROM MsgFile   IMPORT
    (* PROC *)          GetMessage;

FROM LStrings  IMPORT
    (* PROC *)          SetString;

FROM Phantoms  IMPORT
    (* CONST*)          SummaryFlag, PhantomFlag;

FROM PTaskList    IMPORT
    (* CONST *)         Visited, TerminalFlag,
    (* VAR  *)          PrivateTaskList, TaskCount,
                        BoxHandle, BoxShowing, SpaceReserved,
    (* PROC *)          ListInit, AddBefore, DeList,
                        MoveList,
                        ComputeEdgeDelta, MaybeCountDown;

FROM ResConstants IMPORT
    (* VAR *)           SchedulingAbandoned;

FROM ResWarnings  IMPORT
    (* TYPE *)          AWarning,
    (* PROC *)          IssueWarning;

FROM Space     IMPORT   Available;

FROM SYSTEM          IMPORT
     (* TYPES *)        ADR, ADDRESS, SIZE, TSIZE;

FROM Timei      IMPORT
    (* CONST *)         MinDate, MaxDate;

FROM TreeObjects IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder,
    (* PROC *)          ValidateTree, ValidateTreeNode;



CONST
    ModuleNumber = 3800;        (* For GetMessage.  Shared with TLCPM. *)


VAR
    VisitedList,
    ReadyList : AnExtHandle;     (* A Queue of ready to go tasks. *)
    ToGo      : CARDINAL;






PROCEDURE ReportError( N : CARDINAL );
VAR
   S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(N,S);
    Error(S);
END ReportError;







    (* Visit each task on the ReadyList, and each of their neighbors,
       ad infinitum.   Those without directed descendants are added
       to an EndList array.  Actually the tree node for the task is
       added.
       The number of such tasks is returned as our value.
       *)

PROCEDURE VisitNeighbors( VAR EndArray : ARRAY OF ATreeNode
                          ): CARDINAL;
VAR
    edge, anteedge: AnEdgePtr;
    Node:  ATreeNode;
    TaskHandle, NeighborHandle : AnExtHandle;
    Task, Neighbor : ATaskPtr;
    Count : CARDINAL;
BEGIN
    Count := 0;


    (*<PRODUCTION*)

        (* Loop.
           Each time, pull the top task off the ReadyList and
           process it, until the ReadyList is empty.
        *)

    LOOP
        IF (LockObject(ReadyList,Task)=0) THEN FatalError(); END;
        TaskHandle := Task^.Nextlink;
        ReleaseUnchangedObject(ReadyList);       (*<KILL  Task := NIL; KILL>*)

    IF (ObjectsAreSame(TaskHandle,ReadyList)) THEN EXIT; END;


            (* Move the task to the list of visited tasks. *)
        DeList(TaskHandle);
        AddBefore(VisitedList,TaskHandle);

            (* Periodically report progress. *)
        IF (ToGo > 0) THEN
            DEC(ToGo);
            IF ((ToGo MOD 32)=0) THEN
                MaybeCountDown(ModuleNumber+18,ToGo);
            END;
        END;
            


        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;

            (* Visit the descendant tasks. *)
        edge := Task^.desctasks;
        anteedge := Task^.antetasks;

            (* The only tasks that we will ever add to our list are the
               doppleganger task enders to summary task groups.  We need
               to explicitly test that we do not add summary task tasks
               that are not the phantom enders because that would assume
               that Phantoms correctly linked the parents to the children.
               When a summary contains a loop, there might not be any
               link from the parent start task to anything. *)

        IF (edge = NIL)
           AND (SummaryFlag IN Task^.TempTaskFlags)
           AND (PhantomFlag IN Task^.TempTaskFlags)       (* AJL 2/2/88 *)
           AND (Count < HIGH(EndArray)) THEN
            EndArray[ Count ] := ATreeNode(Task^.WorkSpace);  (* WorkSpace points to node. *)
            INC(Count);
        END;

        ReleaseUnchangedObject(TaskHandle);      (*<KILL Task := NIL; KILL>*)

             (* Move each dependent task to the queue of tasks to
                visit. *)

        WHILE (edge <> NIL) DO
            Node := edge^.tailtask;
            NeighborHandle := AnExtHandle(Node^.Methods^.GetDataObject(Node));
            IF (LockObject(NeighborHandle,Neighbor)=0) THEN FatalError(); END;
            IF (NOT (Visited IN Neighbor^.TempTaskFlags)) THEN
                INCL(Neighbor^.TempTaskFlags, Visited);
                DeList(NeighborHandle);
                AddBefore(ReadyList,NeighborHandle);
                ReleaseObject(NeighborHandle);      (*<KILL Neighbor := NIL; KILL>*)
            ELSE
                ReleaseUnchangedObject(NeighborHandle);      (*<KILL Neighbor := NIL; KILL>*)
            END;
            edge := edge^.headlink
        END;

            (* Move each dependent task to the queue of tasks to
               visit. *)

        edge := anteedge;                (* Saved earlier. *)
        WHILE (edge <> NIL) DO
            Node := edge^.headtask;
            NeighborHandle := AnExtHandle(Node^.Methods^.GetDataObject(Node));
            IF (LockObject(NeighborHandle,Neighbor)=0) THEN FatalError(); END;
            IF (NOT (Visited IN Neighbor^.TempTaskFlags)) THEN
                INCL(Neighbor^.TempTaskFlags, Visited);
                DeList(NeighborHandle);
                AddBefore(ReadyList,NeighborHandle);
                ReleaseObject(NeighborHandle);      (*<KILL Neighbor := NIL; KILL>*)
            ELSE
                ReleaseUnchangedObject(NeighborHandle);      (*<KILL Neighbor := NIL; KILL>*)
            END;
            edge := edge^.taillink
        END;

    END;
    (*PRODUCTION>*)

    RETURN Count;

END VisitNeighbors;



    (* AddTerminalNodes -- Add some new nodes to the graph so that
                           each (weakly) connected subgraph has exactly
                           one node with no (directed) descendants.

                           Assumes that ReadyList is empty, and returns
                           it empty.

                           *)



PROCEDURE AddTerminalNodes (  PrivateTaskList : AnExtHandle;
                              TaskCount       : CARDINAL );
CONST
    MaxNodesToTrack = 200;
VAR
    currtaskHandle, NewEndTaskHandle : AnExtHandle;
    currtask, NewEndTask       : ATaskPtr;
    EndNodes                            : CARDINAL;
    NewEndNode                          : ATreeNode;
    EndArray : ARRAY [0..MaxNodesToTrack-1] OF ATreeNode;
    i : CARDINAL;
    EdgePtr : AnEdgePtr;
BEGIN
    (*<PRODUCTION*)

    ToGo := TaskCount;

    IF NOT ListInit(ReadyList) THEN
        IssueWarning(OutOfMemory,NIL);
        SchedulingAbandoned := TRUE;
        RETURN;
    END;
    IF NOT ListInit(VisitedList) THEN
        DiscardExtObject(ReadyList);
        IssueWarning(OutOfMemory,NIL);
        SchedulingAbandoned := TRUE;
        RETURN;
    END;

        (* Loop, removing tasks from the private task list, until
           no more remain. *)


    LOOP
        IF (BreakRequested()) THEN
            SchedulingAbandoned := TRUE;
        END;

        IF (SchedulingAbandoned) THEN EXIT; END;
        IF (LockObject(PrivateTaskList,currtask)=0) THEN FatalError(); END;
        currtaskHandle := currtask^.Nextlink;
        ReleaseUnchangedObject(PrivateTaskList);        (*<KILL  currtask := NIL; KILL>*)
        IF ( ObjectsAreSame(currtaskHandle,PrivateTaskList)) THEN
    EXIT;
        END;

        IF (LockObject(currtaskHandle,currtask)=0) THEN FatalError(); END;

            (* Visit all weakly connected nodes.  Transfer each
               to the visited list. *)
            (* Exclude the task from further visits. *)
        INCL(currtask^.TempTaskFlags, Visited);
        DeList(currtaskHandle);
        AddBefore(ReadyList,currtaskHandle);
        ReleaseObject(currtaskHandle);          (*<KILL  currtask := NIL; KILL>*)

        EndNodes := VisitNeighbors(EndArray);


        IF (EndNodes = 1) THEN
                (* Mark that task as the end of a subgraph. *)
            NewEndTask (* not really *)
                := EndArray[0]^.Methods^.LockFlexStorDataObject(EndArray[0]);
            INCL(NewEndTask^.TempTaskFlags,TerminalFlag);
            INCL(NewEndTask^.TaskFlags,ForceCritical);
            EndArray[0]^.Methods^.UnlockFlexStorDataObject(EndArray[0]);
        ELSIF (EndNodes > 1) THEN
                (* Create a new task that will be the end of the subgraph. *)
            IF (Available(500)) THEN
                NewEndNode := CreateTask();
                IF (NewEndNode <> NIL) THEN
                        (* Move it in the tree at the very bottom. *)
                    NewEndNode^.Methods^.DeList(NewEndNode);
                    TaskTree^.Methods^.AddLast(TaskTree,NewEndNode);

                    NewEndTaskHandle := AnExtHandle(NewEndNode^.Methods^.GetDataObject(NewEndNode));
                    IF ( LockObject(NewEndTaskHandle,NewEndTask)=0) THEN FatalError(); END;
                        (* Add to the PrivateTaskList *)
                    AddBefore(PrivateTaskList,NewEndTaskHandle);
                        (* Make sure that End tasks ends are treated
                           as ALAP milestones.  *)
                    WITH NewEndTask^ DO
                        WorkSpace := NewEndNode;   (* Link to tree node. *)
                        duration := 0;
                        fixation := ALAP;
                        TaskFlags := ATaskFlagSet{};
                        TempTaskFlags := ATempTaskFlagSet{PhantomFlag,TerminalFlag};
                        StartDateLowerBound := MinDate;
                        StartDateUpperBound := MaxDate;
                        (*<DEBUG*)
                        SetString(taskname,"**SUBGRAPH ENDER**");
                        (*DEBUG>*)
                    END;

                    ReleaseObject(NewEndTaskHandle);        (*<KILL NewEndTask := NIL; KILL>*)

                    FOR i := 0 TO EndNodes-1 DO
                            (* Link this task as a predecessor to the
                               NewEndTask. *)
                        EdgePtr := CreateEdge( EndArray[i], NewEndNode );
                        IF (EdgePtr <> NIL) THEN
                            AddEdge(EdgePtr,FALSE);
                        ELSE
                            ReportError(ModuleNumber+13);
                            SchedulingAbandoned := TRUE;
                        END;
                    END;

                END;
            ELSE
                ReportError(ModuleNumber+14);
                SchedulingAbandoned := TRUE;   (* "Out of memory with subgraphs."*)
            END;
        END;
    END;

    MoveList(PrivateTaskList,VisitedList);

    DiscardExtObject(VisitedList);
    (*PRODUCTION>*)



END AddTerminalNodes;


END IndProjects.

