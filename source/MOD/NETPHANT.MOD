IMPLEMENTATION MODULE NetPhantoms;


    (* This module rearranges edges in the network and creates new ones
       to assist the PERT diagram drawing.

       When summary tasks are open, they are split into two tasks, a
       starter and an ender, and edges are added so that the children 
       follow the starter and precede the ender.
          
       When summary tasks are closed, any dependencies to or from the 
       children (that go outside the family) are duplicated into 
       dependencies to or from the parent. 
    *)




    (*V1=PRODUCTION *)
    (*V2=KILL pointers when FlexStor objects are released. *)

    (* MODIFICATION HISTORY

       Apr. 27, 89  AJL - Copied basic code from Phantoms.  Added
                          new behavior, mostly that we do not treat
                          partial dependencies specially, and the 
                          rollup of edges of closed summary tasks.
       Jun  14  89  AJL - Added QueryVisibleAncestor so that we do not
                          create edges to invisible tasks. 
       Jun  26  89  AJL - Clean out the edge flags at the start of this
                          process (in Scan1) and again at the end (in
                          DiscardSummaryPhantoms).
                        - Always call RemoveTemporaryEdges for every task.
       Jul  25, 89  AJL -Removed an unused import of BreakRequested.
       Aug  30, 89  AJL -Copy the TaskStatusSet from a summary start task
                         to its phantom.  Also the date blocks.  This
                         is so that the EdgeInfo.EdgeIsCritical proc
                         can correctly identify the critical edges from/to
                         summary tasks and their phantoms.  Similarly,
                         set the dates.
                        -Set the Delta values on the summary edges to zero.
       Sep  18, 89  AJL -Mess around with the highlight filters on summary
                         start and end milestones so that they are more
                         (though not yet completely) accurately reflective
                         of the critical path.  See the AdjustCriticalHighlight
                         procedure.
                        -The summary end milestone has all the data fields of
                         the summary starter.
       Sep 21, 1989 AJL -Turn off the missing doppleganger warning.  
       Nov 07, 1989 EGK -Have RollupEdges call a loop detection procedure
                         (LoopExists) each time it rolls up one edge from a
                         child to a parent.  This keeps the PERT view from
                         reporting loops that the user "created" by closing
                         summary tasks.
       Dec 14, 1989 AJL/EGK  -In LinkChildren, modified logic for marking
                         tasks as "starter" or "ender".
       Dec 15, 1989 AJL/EGK  -Pulled the code out of LinkChildren that
                         handled rolling up edges into summary tasks, and
                         put that in a new procedure, RollupChildren, that
                         is called in a completely separate pass after all
                         the phantom edges are created.
       Dec 19, 1989 EGK  Oops.  Forgot to recursively call RollupChildren
                         at the bottom of itself, like LinkChildren did.

       Mar 19, 1990 RSC  Moved a line around as per EGK (on the phone),
                         to solve the problem with start to start dependancies
                         on closed summaries.

       Aug   6, 90  RSC  Changed some references of ATaskFlag to ATempTaskFlag.

       Sep 12, 1990 CL   Rename the former Plan.Dates.FixedStart field 
                         to UserEnteredStartDate and change its format 
                         from ADate to ABigTime.
       Sep. 13 1990 AJL  Remove references to UserEnteredStartDate and 
                         add in LateIndStart and End.
       31-Jan-91 RSC     Remove some exteranious locks of task nodes by
                         using some slightly different calling sequences
                         for some edge manipulations.
       26-Feb-92 AJL    -Use the CriticalEnd flag produced by recalc so that
                         we insure a single, consistent definition of 
                         critical path.
                        -The filters for summary tasks were not reassembled
                         correctly always when phantoms were rejoined to the
                         main task.  Now, we will filter the task explicitly.
    *)


    (*<KILL (*$R+*) (*$T+*) KILL>*)

FROM Allocs    IMPORT
    (* CONST *)         TskNmLen,
    (* TYPE *)          ATask, ADateBlock, AnAssignmentSummary,
                        ATaskPtr, ATaskName, AFixType, ATaskFilter, ATaskFilterSet,
                        AStartStatus, ATaskFlag, ATaskFlagSet, ARollupStatus,
                        ATaskStatusSet, ATaskStatus, ADurationMethod,
                        ATempTaskFlag, ATempTaskFlagSet,
    (* VAR *)           TaskTree,
                        StartStatusName,
    (* PROC *)          CheckTaskValid,
                        CreateTask, CopyTask, DelTask;

FROM CritFilt    IMPORT
    (* PROC *)          QueryCriticalPathFilter;

FROM Dialog      IMPORT
    (* PROC *)          Message, Error, FatalError, NotYetImplemented;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr, AnEdgeAttribute, AnEdgeType,
                                ASetOfEdgeAttributes, AnEdgesTask,
    (* PROC *)                  CheckEdgeValid, DelEdge,
                                CreateEdgeDammit, AddEdge, RemoveEdge,
                                CopyEdgeContents, FindEdgeInTask;

FROM FlexStor    IMPORT
    (* TYPE *)     AnExtHandle, AnExtStoragePreference,
    (* PROC *)
                   CreateExtObject, SetExtData, GetExtData,
                   CreateExtObjectWithSize, SetExtSize, GetExtSize,
                   DiscardExtObject,
                   HandleIsValid, ObjectsAreSame,
                   LockObject, ReleaseObject, ReleaseUnchangedObject;


FROM LStrings    IMPORT
    (* PROC *)          Copy, ConcatS;

FROM MsgFile     IMPORT
    (* PROC *)          GetMessage;

FROM PTaskList   IMPORT
    (* VAR  *)          PrivateTaskList,
    (* PROC *)          AddBefore, DeList;

FROM Space       IMPORT
    (* PROC *)          Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM      IMPORT
    (* TYPE *)          ADDRESS,
    (* PROC *)          ADR, SIZE, TSIZE;

FROM Timei          IMPORT
                        NoDuration;

FROM TreeObjects IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder, ATreeNodeAttribute,
    (* PROC *)          ValidateTree, ValidateTreeNode;


CONST
    ModuleNumber = 21600;
        (* Flags to mark task nodes as being terminal tasks within a
           family.  We mark the nodes instead of the task records in
           order to reduce disk i/o. *)
    StarterNode = SelfMatch;               (* from TreeObjects *)
    EnderNode   = ChildrenMatch;

TYPE
   ALinkChildrenContext = RECORD
                              ProminentAncestor : ATreeNode;
                              ok                : BOOLEAN;
                          END; 

(* *)

    (* Procedures for creating phantom doubles of the summary tasks. *)


PROCEDURE UnmarkInvisibleTask( VAR TaskTreeNode : ATreeNode;
                                   Context      : ADDRESS);
VAR
    Task : ATaskPtr;
    ExtraWork : AT2Proc;
    TaskHandle : AnExtHandle;
BEGIN
    ExtraWork := AT2Proc(Context);

    TaskHandle := AnExtHandle(TaskTreeNode^.Methods^.GetDataObject(TaskTreeNode));

    IF ( LockObject(TaskHandle,Task) <> TSIZE(ATask)) THEN
        FatalError();
    END;

    TaskTreeNode^.Methods^.SetAttributeBit( TaskTreeNode, StarterNode, FALSE);
    TaskTreeNode^.Methods^.SetAttributeBit( TaskTreeNode, EnderNode, FALSE);

    WITH Task^ DO

            (* 6-Aug-90 RSC Changed to TempTaskFlags *)

        TempTaskFlags := TempTaskFlags
                       - ATempTaskFlagSet{ VisibleChildrenFlag,
                                           SummaryFlag, PhantomFlag };
        INCL(TempTaskFlags,InvisibleFlag);
        WorkSpace := TaskTreeNode;   (* Link back to the node. *)
    END;

        (* Do any extra local processing. *)

    ExtraWork(TaskTreeNode,Task);

    ReleaseObject(TaskHandle);    (*<KILL*) Task := NIL; (*KILL>*)

END UnmarkInvisibleTask;






PROCEDURE UnmarkVisibleTask  (VAR TaskTreeNode : ATreeNode;
                                  Context      : ADDRESS);
VAR
    Task : ATaskPtr;
    ExtraWork : AT2Proc;
    TaskHandle : AnExtHandle;
    SubTree    : ATree;
    Link : AnEdgePtr;
    FilteredIn : BOOLEAN;

BEGIN
    ExtraWork := AT2Proc(Context);

    TaskHandle := AnExtHandle(TaskTreeNode^.Methods^.GetDataObject(TaskTreeNode));

    IF ( LockObject(TaskHandle,Task) <> TSIZE(ATask)) THEN
        FatalError();
    END;

    TaskTreeNode^.Methods^.SetAttributeBit( TaskTreeNode, StarterNode, FALSE);
    TaskTreeNode^.Methods^.SetAttributeBit( TaskTreeNode, EnderNode, FALSE);

    WITH Task^ DO

            (* 6-Aug-90 RSC Changed to TempTaskFlags *)

        TempTaskFlags := TempTaskFlags
                       - ATempTaskFlagSet{ InvisibleFlag, VisibleChildrenFlag, 
                                           SummaryFlag, PhantomFlag };
        WorkSpace := TaskTreeNode;   (* Link back to the node. *)
        FilteredIn := (Selected IN FilterSet);
    END;

        (* Add this task to the private task list. *)

    AddBefore(PrivateTaskList, TaskHandle );

        (* Do any extra local processing. *)

    ExtraWork(TaskTreeNode,Task);


    ReleaseObject(TaskHandle);    (*<KILL*) Task := NIL; (*KILL>*)

        (* Clean the flags in all edges. *)

    Link := QueryDescendantList(TaskTreeNode);
    WHILE (Link <> NIL) DO
        Link^.Attributes := ASetOfEdgeAttributes{};   
        Link := Link^.headlink;
    END;


        (* Decide whether the task node has visible children.  Because the
           network chart has a problem with dependencies that run through
           filtered-out tasks if those tasks were to disappear, we treat 
           them as closed.  It is very important to the subsequent operation
           of the CreateSummaryPhantoms procedure that this flag, and the
           InvisibleFlag in the task, is marked accurately in advance for
           all tasks. *)

    SubTree := TaskTreeNode^.Methods^.GetSubtree(TaskTreeNode);

    IF (SubTree <> NIL) THEN
        IF (FilteredIn) AND
           (TaskTreeNode^.Methods^.ChildrenVisible(TaskTreeNode)) THEN
                (* Open, filter-selected summary tasks are marked with
                   the visible children flag. *)
            Task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
            INCL(Task^.TempTaskFlags,VisibleChildrenFlag);  (* 6-Aug-90 RSC  *)
            TaskTreeNode^.Methods^.UnlockFlexStorDataObject(TaskTreeNode);
                (* Now process all the children. *)
            TaskTree^.Methods^.TraverseTree(SubTree,ParentBeforeChild,0,
                                            UnmarkVisibleTask, ADDRESS(ExtraWork));
        ELSE
            TaskTree^.Methods^.TraverseTree(SubTree,ParentBeforeChild,MAX(CARDINAL),
                                            UnmarkInvisibleTask, ADDRESS(ExtraWork));
        END; 
    END;

END UnmarkVisibleTask;




    (* Scan1 must be repeatable without damage. *)


PROCEDURE Scan1( ExtraWork : AT2Proc );
VAR
    TaskPtr     : ATaskPtr;
BEGIN
        (* Initialize the PrivateTaskList. *)
    
    IF LockObject (PrivateTaskList, TaskPtr) <> TSIZE(ATask) THEN
        FatalError();
    END;
    TaskPtr^.Nextlink := PrivateTaskList;
    TaskPtr^.Prevlink := PrivateTaskList;
    ReleaseObject (PrivateTaskList);  (*<KILL*) TaskPtr := NIL; (*KILL>*)

       (* Process each task. *)

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,0,
                                    UnmarkVisibleTask, ADDRESS(ExtraWork));

END Scan1;







    (* Move all of the descendant dependencies from the FromTask
       so that they are now dependant on the ToTask.  A precondition
       of this procedure working is that the ToTask have no
       descendant dependencies. *)

PROCEDURE MoveDependants(     FromTaskNode, ToTaskNode : ATreeNode );
VAR
    Link : AnEdgePtr;
    ToTask, FromTask : ATaskPtr;
BEGIN
    ToTask := ToTaskNode^.Methods^.LockFlexStorDataObject(ToTaskNode);
    FromTask := FromTaskNode^.Methods^.LockFlexStorDataObject(FromTaskNode);

    IF (ToTask^.desctasks <> NIL) THEN 
        (* Debugging *)
        Link := ToTask^.desctasks;
        WHILE (Link <> NIL) DO
                (* Really the descendant. *)
            FromTask := Link^.tailtask^.Methods^.LockFlexStorDataObject(Link^.tailtask);
            Error(FromTask^.taskname);
            Link^.tailtask^.Methods^.UnlockFlexStorDataObject(Link^.tailtask);
            Link := Link^.headlink;
        END;
        (* *)
        FatalError(); 
    END;

    Link := FromTask^.desctasks;
    IF (Link <> NIL) THEN
        ToTask^.desctasks   := Link;
        FromTask^.desctasks := NIL;
        WHILE (Link <> NIL) DO
            Link^.headtask := ToTaskNode;
            Link := Link^.headlink;
        END;
    END;

    ToTaskNode^.Methods^.UnlockFlexStorDataObject(ToTaskNode);
                              (*<KILL*) ToTask := NIL; (*KILL>*)
    FromTaskNode^.Methods^.UnlockFlexStorDataObject(FromTaskNode);
                              (*<KILL*) FromTask := NIL; (*KILL>*)

END MoveDependants;




PROCEDURE QueryAntecedantList( TaskNode : ATreeNode ) : AnEdgePtr;
VAR
    Task : ATaskPtr;
    Edge : AnEdgePtr;
BEGIN
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    Edge := Task^.antetasks;
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
    RETURN Edge;
END QueryAntecedantList;


PROCEDURE QueryDescendantList( TaskNode : ATreeNode ) : AnEdgePtr;
VAR
    Task : ATaskPtr;
    Edge : AnEdgePtr;
BEGIN
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    Edge := Task^.desctasks;
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
    RETURN Edge;
END QueryDescendantList;



    (* Move all of the descendant dependencies from the SummaryStartNode
       so that they are now dependant on the SummaryEndNode.  A precondition
       of this procedure working is that the SummaryEndNode have no
       descendant dependencies.   We will only move the dependencies
       that are From or To the End of SummaryStartNode. *)

PROCEDURE RelocateDependants(     SummaryStartNode, SummaryEndNode : ATreeNode );
VAR
    Link, NewLink : AnEdgePtr;
    TaskNodeB : ATreeNode;                      (* The correspondent *)
    TempEdge : AnEdge;
BEGIN
        (*  Move the whole edges list to the SummaryEnd, figuring that
            most of them will stay there, and we will reduce the number
            of times we need to Lock or Unlock. *)

    MoveDependants( SummaryStartNode, SummaryEndNode );


        (* Take all the edges which should be from the start of the 
           summary task, and put them there. *)

    Link := QueryDescendantList(SummaryEndNode);

    WHILE (Link <> NIL) DO
        IF (Link^.FromOffset.Start) THEN
               (* Transfer the edge *)
            TaskNodeB := Link^.tailtask;
            TempEdge  := Link^;
            RemoveEdge(Link);                                   (* Remove from one task. *)
            NewLink := CreateEdgeDammit(SummaryStartNode,TaskNodeB);  (* Add to other *)
            IF (NewLink = NIL) THEN FatalError(); END;
            CopyEdgeContents(TempEdge,NewLink^);
            NewLink^.Delta := 0;
            EXCL(TempEdge.Attributes,Relocated);                (* Note that it was put back. *)
            AddEdge(NewLink,FALSE);
               (* Start searching again. *)
            Link := QueryDescendantList(SummaryEndNode);
        ELSE
            Link := Link^.headlink;
        END; 
    END;


       (* Part 2: Take any x-to-End links to the summary and put them
          on the SummaryEnd. *)

    Link := QueryAntecedantList(SummaryStartNode);

    WHILE (Link <> NIL) DO
        IF (NOT Link^.ToOffset.Start) THEN
               (* Transfer the edge *)
            TaskNodeB := Link^.headtask;
            TempEdge  := Link^;
            RemoveEdge(Link);                                   (* Remove from one task. *)
            NewLink := CreateEdgeDammit(TaskNodeB,SummaryEndNode);    (* Add to other *)
            IF (NewLink = NIL) THEN FatalError(); END;
            CopyEdgeContents(TempEdge,NewLink^);
            NewLink^.Delta := 0;
            INCL(TempEdge.Attributes,Relocated);                (* Note that it was moved. *)
            AddEdge(NewLink,FALSE);
               (* Start searching again. *)
            Link := QueryAntecedantList(SummaryStartNode);
        ELSE
            Link := Link^.taillink;
        END; 
    END;


END RelocateDependants;


    (* Move all of the descendant dependencies to the SummaryStart
       from the SummaryEnd.   *)

PROCEDURE RestoreDependants(     SummaryStartNode, SummaryEndNode : ATreeNode );
VAR
    Link, NewLink : AnEdgePtr;
    TaskNodeB : ATreeNode;
    TempEdge : AnEdge;
BEGIN

        (* Transfer edges from the SummaryStart to the SummaryEnd!   There
           shouldn't be many. *)

    Link := QueryDescendantList(SummaryStartNode);

    WHILE (Link <> NIL) DO
           (* Transfer the edge *)
        TaskNodeB := Link^.tailtask;
        TempEdge  := Link^;
        RemoveEdge(Link);                                 (* Remove from one task. *)
        NewLink := CreateEdgeDammit(SummaryEndNode,TaskNodeB);      (* Add to other *)
        IF (NewLink = NIL) THEN FatalError(); END;
        CopyEdgeContents(TempEdge,NewLink^);
        NewLink^.Delta := 0;
        EXCL(TempEdge.Attributes,Relocated);              (* Note that it was moved. *)
        AddEdge(NewLink,FALSE);
           (* Start searching again. *)
        Link := QueryDescendantList(SummaryStartNode);
    END;


        (*  Now bulk transfer the whole edge list from the SummaryEnd
            to the SummaryStart. *)

    MoveDependants( SummaryEndNode, SummaryStartNode );


       (* Part 2: Take all links to the summary and put them
          back on the SummaryStart. *)


    Link := QueryAntecedantList(SummaryEndNode);
    WHILE (Link <> NIL) DO
           (* Transfer the edge *)
        TaskNodeB := Link^.headtask;
        TempEdge  := Link^;
        RemoveEdge(Link);                                     (* Remove from one task. *)
        NewLink := CreateEdgeDammit(TaskNodeB,SummaryStartNode);    (* Add to other *)
        IF (NewLink = NIL) THEN FatalError(); END;
        CopyEdgeContents(TempEdge,NewLink^);
        NewLink^.Delta := 0;
        EXCL(TempEdge.Attributes,Relocated);                  (* Note that it was moved. *)
        AddEdge(NewLink,FALSE);
           (* Start searching again. *)
        Link := QueryAntecedantList(SummaryEndNode);
    END;

END RestoreDependants;




    (* QueryVisibleAncestor  -- Returns this task or the nearest ancestor task
                                (up the tree) that is visible.  If there are no ancestors,
                                returns the outermost task.
    *)                           



     (* This implementation relies on each task being accurately flagged
        as visible or not. *)

PROCEDURE QueryVisibleAncestor( TaskNode : ATreeNode ) : ATreeNode;
VAR
    Task : ATaskPtr;
    Visible : BOOLEAN;
BEGIN
    WHILE (TaskNode^.Methods^.IndentationLevel(TaskNode) > 0) DO

        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        Visible := NOT (InvisibleFlag IN Task^.TempTaskFlags);  (* 6-Aug-90 RSC  *)
        TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);   Task := NIL;

        IF (Visible) THEN
            RETURN TaskNode; 
        END;
        TaskNode := TaskNode^.Methods^.Parent(TaskNode);
    END;
    RETURN TaskNode;
END QueryVisibleAncestor;




(* 31-Jan-91 RSC Reduce locks of tasks. *)
PROCEDURE RemoveAnyLinkToTasks(   ParentNode,
                                  ChildNode     : ATreeNode;
                                  ParentTask,
                                  ChildTask     : ATaskPtr ) : BOOLEAN;
VAR
    Changed1,
    Changed2    : BOOLEAN;



    PROCEDURE LocalRemoveEdge(TaskForA,TaskForB : ATaskPtr;
                                       NodeForB : ATreeNode ) : BOOLEAN;

    VAR
        oldedgea, oldedgeb,
        curedgea, curedgeb      : AnEdgePtr;
        Changed                 : BOOLEAN;
    BEGIN

        Changed  := FALSE;

        oldedgea := NIL;
        curedgea := TaskForA^.desctasks;
        LOOP
            IF (curedgea = NIL) THEN
                RETURN Changed;
            ELSE
                IF (curedgea^.tailtask = NodeForB) THEN EXIT; END;
            END;
            oldedgea := curedgea;
            curedgea := curedgea^.headlink;
        END;

        oldedgeb := NIL;
        curedgeb := TaskForB^.antetasks;
        LOOP
            IF (curedgeb = NIL) THEN
                RETURN Changed;
            ELSE
                IF (curedgeb = curedgea) THEN EXIT; END;
            END;
            oldedgeb := curedgeb;
            curedgeb := curedgeb^.taillink;
        END;

            (*  Pass the new edge over with its neighbor's links. *)

        IF (oldedgea = NIL) THEN
            TaskForA^.desctasks := curedgea^.headlink;
            Changed := TRUE;
        ELSE
            oldedgea^.headlink := curedgea^.headlink;
        END;

                      (* nb: curedgea = curedgeb. *)

        IF (oldedgeb = NIL) THEN
            TaskForB^.antetasks := curedgea^.taillink;
            Changed := TRUE;
        ELSE
            oldedgeb^.taillink := curedgea^.taillink;
        END;

            (* Throw the old edge away. *)

        DelEdge (curedgea);

        RETURN Changed;

    END LocalRemoveEdge;


BEGIN
    Changed1 := LocalRemoveEdge(ParentTask,ChildTask,ChildNode);
    Changed2 := LocalRemoveEdge(ChildTask,ParentTask,ParentNode);

    RETURN Changed1 OR Changed2;

END RemoveAnyLinkToTasks;



    (*  LoopExists --  this is based on the old "bfs" procedure in the
                       Filters code from TL2.  Given a starting task node,
                       it searches all the descendant paths to see if any
                       return back to that original task.
    *)

PROCEDURE LoopExists ( StartTask    : ATreeNode ) : BOOLEAN;
CONST
    maxtasks        = 100;
VAR
    TaskNode        : ATreeNode;
    TaskPtr         : ATaskPtr;
    taskqueue       : ARRAY [1..maxtasks] OF ATreeNode;
    front, rear     : CARDINAL;
    EdgePtr         : AnEdgePtr;

    PROCEDURE Bump ( VAR i : CARDINAL );
    BEGIN
        IF (i >= maxtasks) THEN
            i := 1;
        ELSE
            INC(i);
        END;
    END Bump;

BEGIN
    rear := 1;
    front := 0;
    taskqueue[rear] := StartTask;
    LOOP
        IF (front = rear) THEN
            RETURN FALSE;           (* no more tasks to check; no loop! *)
        END;
        Bump (front);

        TaskNode := taskqueue[front];
        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
        EdgePtr := TaskPtr^.desctasks;
        TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);

        WHILE (EdgePtr <> NIL) DO
            IF (EdgePtr^.tailtask = StartTask) THEN
                RETURN TRUE;        (* we came back to the original task *)
            END;

            Bump (rear);
            IF (rear = front) THEN
                RETURN FALSE;       (* we overflowed the queue *)
            END;

            taskqueue[rear] := EdgePtr^.tailtask;
            EdgePtr := EdgePtr^.headlink;
        END;
    END;
END LoopExists;




    (* RollupEdges -- Take the edges from external tasks to this parent task's
                      children and make edges from those tasks to this parent.

            NOTE:  The current version (as of 11/7/89) of the PERT view code
            will report an "imaginary loop" in some cases after these edge
            rollups are done.  Until we can get the PERT code to handle
            these cases, we make RollupEdges look for a loop each time it
            rolls up an edge from a child to a visible parent.  Since it is
            possible to create a loop by rolling up just the antecedants or
            just the descendants, we have to run the loop check in both
            places.     -- EGK 11/7/89
    *)


PROCEDURE Joined(  A, B : ATreeNode ) : BOOLEAN;
VAR
    Task    : AnEdgesTask;
    Found   : BOOLEAN;
BEGIN
        (* 31-Jan-91 RSC Lock locally to avoid several locks in Edges.
        *)
    Task  := AnEdgesTask(A^.Methods^.LockFlexStorDataObject(A));
    Found := (FindEdgeInTask( Task, B ) <> NIL);
    A^.Methods^.UnlockUnchangedDataObject(A);

    IF (NOT Found) THEN
        Task  := AnEdgesTask(B^.Methods^.LockFlexStorDataObject(B));
        Found := (FindEdgeInTask( Task, A ) <> NIL);
        B^.Methods^.UnlockUnchangedDataObject(B);
    END;

    RETURN Found;

END Joined;



PROCEDURE RollupEdges(VAR TaskNode       : ATreeNode;
                          Context        : ADDRESS);
VAR
    Task        : ATaskPtr;
    LinkContext : POINTER TO ALinkChildrenContext; 
    Link, NewLink : AnEdgePtr;
    TaskNodeB, LinkToNode : ATreeNode;                      (* The correspondent *)
BEGIN
    LinkContext := Context;

    IF (NOT LinkContext^.ok) THEN RETURN; END;

        (* Roll the edges up. *)

    Link := QueryAntecedantList(TaskNode);

    WHILE (Link <> NIL) DO
           (* Check the edge *)
        TaskNodeB := Link^.headtask;
            (* If the link is outside the family . . . *)
        IF (NOT TaskNodeB^.Methods^.TestAttributeBit( TaskNodeB, SelfMatch )) THEN
               (* . . . and there is not already a link to our closed summary . . . *)
            LinkToNode := QueryVisibleAncestor(TaskNodeB);
            IF (NOT Joined(LinkToNode,LinkContext^.ProminentAncestor)) THEN
                NewLink := CreateEdgeDammit(LinkToNode,LinkContext^.ProminentAncestor);
                IF (NewLink <> NIL) THEN
                    INCL(NewLink^.Attributes,Temporary);                (* Note that it isn't real. *)
                    INCL(NewLink^.Attributes,RolledUp);                 (* Note that it isn't real. *)
                    AddEdge(NewLink,FALSE);
                    IF (LoopExists(LinkToNode)) THEN
                        RemoveEdge (NewLink);       (* 11/7/89 EGK *)
                    END;
                ELSE
                    LinkContext^.ok := FALSE;  
                    RETURN;
                END;
            END;
                (* Mark the old edge as invisible. *)
            INCL(Link^.Attributes,InvisibleEdge);
        ELSE
            EXCL(Link^.Attributes,InvisibleEdge);
        END;
        Link := Link^.taillink;
    END;

    Link := QueryDescendantList(TaskNode);

    WHILE (Link <> NIL) DO
           (* Check the edge *)
        TaskNodeB := Link^.tailtask;
            (* If the link is outside the family . . . *)
        IF (NOT TaskNodeB^.Methods^.TestAttributeBit( TaskNodeB, SelfMatch )) THEN
               (* . . . and there is not already a link to our closed summary . . . *)
            LinkToNode := QueryVisibleAncestor(TaskNodeB);
            IF (NOT Joined(LinkContext^.ProminentAncestor,LinkToNode)) THEN
                NewLink := CreateEdgeDammit(LinkContext^.ProminentAncestor,
                                      LinkToNode);
                IF (NewLink <> NIL) THEN
                    INCL(NewLink^.Attributes,Temporary);                (* Note that it isn't real. *)
                    INCL(NewLink^.Attributes,RolledUp);                 (* Note that it isn't real. *)
                    AddEdge(NewLink,FALSE);
                    IF (LoopExists(LinkToNode)) THEN
                        RemoveEdge (NewLink);       (* 11/7/89 EGK *)
                    END;
                ELSE
                    LinkContext^.ok := FALSE;  
                    RETURN;
                END;
            END;
                (* Mark the old edge as invisible. *)
            INCL(Link^.Attributes,InvisibleEdge);
        ELSE
            EXCL(Link^.Attributes,InvisibleEdge);
        END;
        Link := Link^.headlink;
    END;

END RollupEdges;


    (* Set a bit in the task node which we can test later. *)

PROCEDURE MarkTaskNode( VAR TaskNode  : ATreeNode;
                            Context        : ADDRESS);
BEGIN
    TaskNode^.Methods^.SetAttributeBit( TaskNode, SelfMatch, TRUE);
END MarkTaskNode;

    (* Clear that bit. *)

PROCEDURE UnMarkTaskNode( VAR TaskNode  : ATreeNode;
                              Context        : ADDRESS);
BEGIN
    TaskNode^.Methods^.SetAttributeBit( TaskNode, SelfMatch, FALSE);
END UnMarkTaskNode;



    (* AdjustCriticalHighlight -- Take a guess about what the highlight
                                  filters ought to be.  This is so that
                                  the start and end milestones of a summary
                                  task don't have to have the same filtering.
                                  This proc isn't always accurate, in that
                                  the highlight could have been turned on
                                  even while Critical was not the only 
                                  criterea.  A bug.  Tradeoff is not having
                                  to reapply the filter module.
    *)      


PROCEDURE AdjustCriticalHighlight( Task : ATaskPtr );
VAR
    HighlightFilterNumber : CARDINAL;
BEGIN
    IF QueryCriticalPathFilter( HighlightFilterNumber ) THEN
        WITH Task^ DO
            IF (Critical IN TaskStatusSet) THEN
                INCL(FilterSet,VAL(ATaskFilter,HighlightFilterNumber));
            ELSE
                EXCL(FilterSet,VAL(ATaskFilter,HighlightFilterNumber));
            END;
        END; 
    END;
END AdjustCriticalHighlight;




    (* This will only work properly if traversed ParentBeforeChild. *)

PROCEDURE LinkChildren(VAR Parent         : ATreeNode;
                           Context        : ADDRESS);
VAR
    ParentTask, ChildTask : ATaskPtr;
    InitialChild, Child : ATreeNode;
    ParentTree         : ATree;
    AnteLink, DescLink : AnEdgePtr;
    EdgePtr : AnEdgePtr;
    LinkedTask : ATaskPtr;
    DopplegangerTaskHandle : AnExtHandle;
    DopplegangerTask : ATaskPtr;
    DopplegangerNode : ATreeNode;
    LinkContext : POINTER TO ALinkChildrenContext; 
    ok : POINTER TO BOOLEAN;
    ParentDates  : ADateBlock;
    ParentFlags : ATempTaskFlagSet;
    ParentStatus : ATaskStatusSet;
    ParentName : ATaskName;

    PROCEDURE Warn( N : CARDINAL );
    VAR
        S : ARRAY [0..99] OF CHAR;
    BEGIN
        GetMessage(ModuleNumber+N,S);
        Error(S);
        LinkContext^.ok := FALSE;
    END Warn;
 
BEGIN
    LinkContext := Context;

    IF (NOT LinkContext^.ok) THEN RETURN; END;


    InitialChild := Parent^.Methods^.FirstChild(Parent);

        (* We are only interested in summary tasks. *)

    IF (InitialChild = NIL) THEN RETURN; END;

    ParentTree := Parent^.Methods^.GetSubtree(Parent);

        (* If the children are hidden, then we will roll-up their
           edges.  If visible, we will create new links to their
           summary phantoms.  Note that the decision about what
           "hidden" means is made elsewhere so that it will be
           noted and processed consistently. *)

    ParentTask := Parent^.Methods^.LockFlexStorDataObject(Parent);

    IF (NOT (VisibleChildrenFlag IN ParentTask^.TempTaskFlags)) THEN
        Parent^.Methods^.UnlockUnchangedDataObject(Parent);
            (* processing of these tasks will be handled in RollupChildren. *)
        RETURN; 
    END;


    WITH ParentTask^ DO
        INCL(TempTaskFlags,SummaryFlag);
        Copy(taskname,ParentName);
        ParentFlags := TempTaskFlags;
        ParentStatus := TaskStatusSet;                 (* Keep if critical or not. *)
        ParentDates  := Plan.Dates;
            (* Determine whether the start milestone is critical.   Stuff this
               into the start milestone.
               
               *) 

        IF (CriticalStart IN TaskStatusSet) THEN
            INCL(TaskStatusSet,Critical);
        ELSE
            EXCL(TaskStatusSet,Critical);
        END;
    END;
    AdjustCriticalHighlight( ParentTask );


       (* For each child task,
          remove any links from child to the parent task. *)
    Child := InitialChild;
    WHILE (Child <> NIL) DO
           (* This could be improved to also check grandparents. *)

        ChildTask := Child^.Methods^.LockFlexStorDataObject(Child);
        IF (RemoveAnyLinkToTasks(Parent,Child,ParentTask,ChildTask)) THEN
            Child^.Methods^.UnlockFlexStorDataObject(Child);
        ELSE
            Child^.Methods^.UnlockUnchangedDataObject(Child);
        END;
        Child := Child^.Methods^.GetNext(Child);
    END;
    Parent^.Methods^.UnlockFlexStorDataObject(Parent);
                      (*<KILL*) ParentTask := NIL; (*KILL>*)

        (* Create a "phantom" copy of the summary task.  This will
           represent the ending of the summary.  Move all of the
           antecedant dependencies from summary to its double.
           In the workspace of the original task, record the
           doppleganger, and visa versa. *)
    IF (Available(500) ) THEN
        DopplegangerNode := CreateTask();
        IF (DopplegangerNode <> NIL) THEN
            CopyTask(Parent,DopplegangerNode);       (* Copy ALL the details of the original. *)
                (* Move it in the tree to follow the original. *)
            DopplegangerNode^.Methods^.DeList(DopplegangerNode);
            Parent^.Methods^.AddAfter(Parent,DopplegangerNode);
            RelocateDependants(Parent,DopplegangerNode);
            DopplegangerTaskHandle := AnExtHandle
                    (DopplegangerNode^.Methods^.GetDataObject(DopplegangerNode));
            IF ( LockObject(DopplegangerTaskHandle,DopplegangerTask) <> TSIZE(ATask)) THEN
                FatalError();
            END;
                (* Add to the PrivateTaskList *)
            AddBefore(PrivateTaskList,DopplegangerTaskHandle);
                (* Make sure that Summary tasks' ends are treated
                   as ALAP milestones.   We set the milestone
                   part here.  ALAP is handled in the planning. *)
                (* Link task to the node. *)
            WITH DopplegangerTask^ DO
                WorkSpace := DopplegangerNode;
                    (* Turn it into a milestone. *)
                duration := NoDuration;
                WITH Plan.Dates DO
                    EarlyStart := EarlyEnd;
                    LateFreeStart := LateFreeEnd;
                    LateTotalStart := LateTotalEnd;
                    LateIndStart := LateIndEnd;
                        (* Determine whether the end milestone is critical. *)  
                    IF (CriticalEnd IN TaskStatusSet) THEN
                        INCL(TaskStatusSet,Critical);
                    ELSE
                        EXCL(TaskStatusSet,Critical);
                    END;    
                END;
                INCL(TempTaskFlags,PhantomFlag);
                Copy(ParentName,taskname);
                IF (ORD(ParentName[0]) < HIGH(taskname)) THEN
                    ConcatS(taskname,"'");
                END;
            END;
            AdjustCriticalHighlight( DopplegangerTask );
            ReleaseObject(DopplegangerTaskHandle);
                            (*<KILL*)  DopplegangerTask := NIL; (*KILL>*)
        ELSE
            LinkContext^.ok := FALSE;
        END;
    ELSE
        LinkContext^.ok := FALSE;
    END;


    IF (NOT LinkContext^.ok) THEN
       Warn(1);
       RETURN;
    END;


        (* For each child, mark each as a starter and an ender *)
    Child := InitialChild;
    WHILE (Child <> NIL) DO
       Child^.Methods^.SetAttributeBit( Child, StarterNode, TRUE);
       Child^.Methods^.SetAttributeBit( Child, EnderNode, TRUE);
       Child := Child^.Methods^.GetNext(Child);
    END;

        (* For each child, mark each antecedant task as not an
           ender, and each dependant task as not a starter. *)
    Child := InitialChild;
    WHILE (Child <> NIL) AND (LinkContext^.ok) DO
           (* Lock the child task, locate links, unlock. *)
       ChildTask := Child^.Methods^.LockFlexStorDataObject(Child);
       AnteLink := ChildTask^.antetasks;
       DescLink := ChildTask^.desctasks;
       Child^.Methods^.UnlockUnchangedDataObject(Child);
                       (*<KILL*) ChildTask := NIL; (*KILL>*)
           (* Unmark descendant tasks. *)

           (* If the descendant is a summary task AND the dependency is to
              the end of that task, then leave the descendant marked as a
              "starter".    -- EGK 12/14/89  *)

       WHILE (DescLink <> NIL) DO
           WITH DescLink^ DO 
               IF ((tailtask^.Methods^.FirstChild (tailtask) = NIL) OR  (* 12/14/89 EGK *)
                   (ToOffset.Start)) THEN
                   tailtask^.Methods^.SetAttributeBit( tailtask, StarterNode, FALSE);
               END;
           END;
           DescLink := DescLink^.headlink;
       END;
           (* Unmark antecedant tasks. *)

           (* As above, if the antecedant is a summary task AND the
              dependency is from the start of that task, then leave the
              antecedant marked as an "ender".  -- EGK 12/14/89  *)

       WHILE (AnteLink <> NIL) DO
           WITH AnteLink^ DO 
               IF ((headtask^.Methods^.FirstChild (headtask) = NIL) OR  (* 12/14/89 EGK *)
                   (NOT FromOffset.Start)) THEN
                   headtask^.Methods^.SetAttributeBit( headtask, EnderNode, FALSE);
               END;
           END;
           AnteLink := AnteLink^.taillink;
       END;
       Child := Child^.Methods^.GetNext(Child);
    END;


        (* At this point, the only tasks marked as Starters are the
           child tasks with no antecedants that are also child tasks.
           Similarly for the Enders. *)
        (* For each child marked as a Starter, make it depend on the
           Parent.  Make the doppleganger depend on each ender.
           While we're here, unmark each child task as we go. *)
    Child := InitialChild;
    WHILE (Child <> NIL) DO
       IF (Child^.Methods^.TestAttributeBit( Child, StarterNode )) THEN
           EdgePtr := CreateEdgeDammit (Parent, Child);
           IF (EdgePtr = NIL) THEN
               Warn(2);
           ELSE
               AddEdge (EdgePtr, FALSE);
               INCL(EdgePtr^.Attributes,PhantomPredecessor);
               EdgePtr^.Delta := 0;
           END;
       END;

       IF (Child^.Methods^.TestAttributeBit( Child, EnderNode )) THEN
           EdgePtr := CreateEdgeDammit (Child, DopplegangerNode);
           IF (EdgePtr = NIL) THEN
               Warn(2);
           ELSE
               AddEdge (EdgePtr, FALSE);
               INCL(EdgePtr^.Attributes,PhantomSuccessor);
               EdgePtr^.Delta := 0;
           END;
       END;

           (* Clear the bits so that this procedure can run in 
              a hierarchy. *)

       Child^.Methods^.SetAttributeBit( Child, StarterNode, FALSE);
       Child^.Methods^.SetAttributeBit( Child, EnderNode, FALSE);

       Child := Child^.Methods^.GetNext(Child);
    END;

    Parent^.Methods^.UnlockUnchangedDataObject(Parent);
        (*<KILL*) ParentTask := NIL; (*KILL>*)

        (* Now, recursively, do the same to each child. *)

    ParentTree^.Methods^.TraverseTree(ParentTree,ParentBeforeChild,0,
                                  LinkChildren, LinkContext );

END LinkChildren;




    (*  RollupChildren -- this handles the rolling up of edges into
                summary tasks.  It used to be part of LinkChildren, but
                is now separate so that it can be called after all
                necessary phantom edges are created for all visible summary
                tasks.   (We do this so that our loop detector can be sure
                that no more edges will be created after it has a chance
                to catch loops.)
    *)


PROCEDURE RollupChildren(VAR Parent         : ATreeNode;
                             Context        : ADDRESS   );
VAR
    ParentTask      : ATaskPtr;
    InitialChild    : ATreeNode;
    ParentTree      : ATree;
    LinkContext     : POINTER TO ALinkChildrenContext; 
    ok              : POINTER TO BOOLEAN;
    IsClosed        : BOOLEAN;

BEGIN
    LinkContext := Context;

    IF (NOT LinkContext^.ok) THEN RETURN; END;


    InitialChild := Parent^.Methods^.FirstChild(Parent);

        (* We are only interested in summary tasks. *)

    IF (InitialChild = NIL) THEN RETURN; END;

    ParentTree := Parent^.Methods^.GetSubtree(Parent);

        (* If the children are hidden, then we will roll-up their
           edges.  If visible, we will create new links to their
           summary phantoms.  Note that the decision about what
           "hidden" means is made elsewhere so that it will be
           noted and processed consistently. *)

    ParentTask := Parent^.Methods^.LockFlexStorDataObject(Parent);
    IsClosed := NOT (VisibleChildrenFlag IN ParentTask^.TempTaskFlags);
    Parent^.Methods^.UnlockUnchangedDataObject(Parent);

    IF (IsClosed) THEN
                      (*<KILL*) ParentTask := NIL; (*KILL>*)
            (* Mark each child task with a flag. *)  
        ParentTree^.Methods^.TraverseTree(ParentTree,ParentBeforeChild,MAX(CARDINAL),
                                          MarkTaskNode, LinkContext );
            (* Rollup any edges to tasks outside the family. *)
        LinkContext^.ProminentAncestor := Parent;
        ParentTree^.Methods^.TraverseTree(ParentTree,ParentBeforeChild,MAX(CARDINAL),
                                          RollupEdges, LinkContext );
            (* Clear those flags. *)
        ParentTree^.Methods^.TraverseTree(ParentTree,ParentBeforeChild,MAX(CARDINAL),
                                          UnMarkTaskNode, LinkContext );
        RETURN;
    END;

    ParentTree^.Methods^.TraverseTree(ParentTree,ParentBeforeChild,0,
                                  RollupChildren, LinkContext );
END RollupChildren;




PROCEDURE CreateSummaryPhantoms():BOOLEAN;
VAR
    LinkContext : ALinkChildrenContext;
BEGIN
    
    WITH LinkContext DO
        ok := TRUE;
    END;

        (*  First, create dopplegangers and phantom edges for all OPEN
            summary tasks.  *)

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,0,
                                    LinkChildren, ADR(LinkContext) );

        (*  Now, roll up edges from the children of CLOSED summary tasks,
            checking for possible loops as we go.   *)

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,0,
                                    RollupChildren, ADR(LinkContext) );

    RETURN LinkContext.ok;

END CreateSummaryPhantoms;




    (* RemoveTemporaryEdges -- Remove the edges which were created to 
                               roll-up the dependencies from child to 
                               parent, or are otherwise temporary.
                               Remove the miscellaneous flag settings
                               from the real tasks. *) 
                               


PROCEDURE RemoveTemporaryEdges( TaskNode      : ATreeNode );
VAR
    Link : AnEdgePtr;
BEGIN
    Link := QueryDescendantList(TaskNode);

    WHILE (Link <> NIL) DO
               (* Delete the the edge? *)
        IF (Temporary IN Link^.Attributes) THEN
            RemoveEdge(Link);                                   (* Remove from one task. *)
               (* Start searching again. *)
            Link := QueryDescendantList(TaskNode);
        ELSE
            Link^.Attributes := ASetOfEdgeAttributes{};   
            Link := Link^.headlink;
        END; 
    END;

    Link := QueryAntecedantList(TaskNode);

    WHILE (Link <> NIL) DO
               (* Delete the the edge? *)
        IF (Temporary IN Link^.Attributes) THEN
            RemoveEdge(Link);                                   (* Remove from one task. *)
               (* Start searching again. *)
            Link := QueryAntecedantList(TaskNode);
        ELSE
            Link^.Attributes := ASetOfEdgeAttributes{};   
            Link := Link^.taillink;
        END; 
    END;
END RemoveTemporaryEdges;




PROCEDURE MoveStatus( TaskNode : ATreeNode;
                      DopplegangerStatusSet : ATaskStatusSet  );
VAR
    Task : ATaskPtr;
BEGIN
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

        (* Merge the two status sets so that any condition applying to 
           either of them applies to the real task.  Most importantly,
           we want the task to be marked critical if the start or end
           milestone is.  Loop is useful, too. *) 

    WITH Task^ DO
        IF  ( Critical IN TaskStatusSet ) OR   
            ( CriticalStart IN TaskStatusSet) OR
            ( CriticalEnd IN DopplegangerStatusSet) THEN
            INCL(TaskStatusSet,Critical);
        ELSE
            EXCL(TaskStatusSet,Critical);
        END; 
        AdjustCriticalHighlight( Task );
    END;

    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
END MoveStatus;    




PROCEDURE UnLinkChildren(VAR Parent         : ATreeNode;
                             Context        : ADDRESS);
VAR
    Child : ATreeNode;
    NextLink : AnEdgePtr;
    ChildTask,
    Doppleganger, ParentTask : ATaskPtr;
    DopplegangerNode : ATreeNode;
    DopplegangerTask : ATaskPtr;
    AllIsInOrder : BOOLEAN;
    VisibleChildren : BOOLEAN;
    DopplegangerStatusSet : ATaskStatusSet;

    SomethingChanged, C1, C2 : BOOLEAN;

(*    S : ARRAY [0..255] OF CHAR;*)
BEGIN

        (* Remove any temporary edges attached to this task, and clean up
           the flags within the real edges. *)

        (* 19-Mar-90 RSC Moved here from below. *)

    RemoveTemporaryEdges( Parent );

    Child := Parent^.Methods^.FirstChild(Parent);
    IF (Child <> NIL) THEN  (* A Summary Task *)

        ParentTask := Parent^.Methods^.LockFlexStorDataObject(Parent);
        VisibleChildren := (VisibleChildrenFlag IN ParentTask^.TempTaskFlags);

        (* 31-Jan-91 RSC ParentTask was unlocked HERE before my changes.
                         In the Child loop below, there will be 3 tasks
                         locked, which is our max.  I am hoping that
                         there are not other locks around that will
                         blow the limit.

                         Note that unlocks of the Parent and Doppleganger
                         are also done on the ELSE clauses to the IF
                         statements, so that no matter which path we take
                         we will unlock the tasks.

                         Please take care when modifying this code to make
                         sure that the tasks are unlocked under all
                         logic paths.
        *)

        IF (VisibleChildren) THEN
    
                (* This ABSOLUTELY REQUIRES that the doppleganger was
                   placed into the list immediately following the real
                   task. *)
    
            DopplegangerNode := Parent^.Methods^.GetNext(Parent);
    
           
            IF (DopplegangerNode <> NIL) THEN
                DopplegangerTask := DopplegangerNode^.Methods^.LockFlexStorDataObject(DopplegangerNode);
                AllIsInOrder := (PhantomFlag IN DopplegangerTask^.TempTaskFlags);
            ELSE
                AllIsInOrder := FALSE;    (* Missing doppleganger task. *)
            END;
    
    
    
            IF (AllIsInOrder) THEN

                DopplegangerStatusSet := DopplegangerTask^.TaskStatusSet;
      
                SomethingChanged := FALSE;
     
                  (* For each child task,
                     remove any links from child to the parent task. *)
                WHILE (Child <> NIL) DO
                    ChildTask := Child^.Methods^.LockFlexStorDataObject(Child);
                    C1    := RemoveAnyLinkToTasks(Parent,Child,ParentTask,ChildTask);
                    C2    := RemoveAnyLinkToTasks(Child,DopplegangerNode,ChildTask,DopplegangerTask);
                    IF (C1 OR C2) THEN
                        SomethingChanged := TRUE;
                        Child^.Methods^.UnlockFlexStorDataObject(Child);
                    ELSE
                        Child^.Methods^.UnlockUnchangedDataObject(Child);
                    END;
                    Child := Child^.Methods^.GetNext(Child);
                END;
           
                    (* 31-Jan-91 RSC release locks.  Either readonly or
                                     read-write.
                    *)
                IF (SomethingChanged) THEN
                    DopplegangerNode^.Methods^.UnlockFlexStorDataObject(DopplegangerNode);  DopplegangerTask := NIL;
                    Parent^.Methods^.UnlockFlexStorDataObject(Parent);   ParentTask := NIL;
                ELSE
                    DopplegangerNode^.Methods^.UnlockUnchangedDataObject(DopplegangerNode);   DopplegangerTask := NIL;
                    Parent^.Methods^.UnlockUnchangedDataObject(Parent);   ParentTask := NIL;
                END;

                    (* Move the antecedant links from the Doppleganger back to
                       the summary task. *)
                RestoreDependants(Parent,DopplegangerNode);

                    (* Transfer some status information that was moved
                       to the end milestone back to the start milestone. *)

                MoveStatus(Parent, DopplegangerStatusSet );

                    (* Dispose of the phantom.   Because of the INTERNALS of
                       how the TraverseTree proc is written, we cannot dispose of
                       the phantom here.   The problem is that the Traverse proc
                       relies on the next sibling of the current task remaining
                       at its location in the tree, and the DopplegangerNode may
                       be (probably is) that sibling. *)
                    (* DelTask(DopplegangerNode); *)
     
            ELSE
                (*  We must have failed to put a doppleganger task into the task
                   list for this task.  Well . . . since it isn't there, don't 
                   try to delete it.    *)
                (*
                NotYetImplemented("Missing Doppleganger detected"); 
                *)
                IF (DopplegangerNode <> NIL) THEN
                    DopplegangerNode^.Methods^.UnlockUnchangedDataObject(DopplegangerNode);
                END;
                Parent^.Methods^.UnlockUnchangedDataObject(Parent);
            END;
        ELSE
            Parent^.Methods^.UnlockUnchangedDataObject(Parent);
        END;
    END;

    (* 19-Mar-90 RSC Was here
    *)

END UnLinkChildren;




PROCEDURE DisposePhantoms(VAR TaskNode       : ATreeNode;
                              Context        : ADDRESS);
VAR
    Task : ATaskPtr;
    GottaGo : BOOLEAN;
BEGIN
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    GottaGo := (PhantomFlag IN Task^.TempTaskFlags);
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
                           (*<KILL*) Task := NIL; (*KILL>*)
    IF (GottaGo) THEN
        DelTask (TaskNode);
    END;
END DisposePhantoms;




PROCEDURE DiscardSummaryPhantoms;
BEGIN
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentAfterChild,65535,
                                    UnLinkChildren, NIL );
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentAfterChild,65535,
                                    DisposePhantoms, NIL );
END DiscardSummaryPhantoms;









END NetPhantoms.
