IMPLEMENTATION MODULE Phantoms;

    (*V1=PRODUCTION *)
    (*V2=KILL pointers when FlexStor objects are released. *)

    (* MODIFICATION HISTORY

       Dec. 10, 87  AJL - Added FlexStor
       Jan 11, 88   AJL - Converted some UnlockFlexStorDataObject calls
                          to UnlockUnchangedDataObject.
       Jan 13, 88   AJL - Use Space.Available instead of Storage.Available. 
       Jan 15, 88   AJL - Use bits in the task's tree node instead of in
                          the task record when checking for Starter and Ender
                          child tasks.  By reducing changes to the virtual-
                          memory-based objects, we will reduce the number of
                          times that buffers must be re-written to disk.
       Jan. 22, 88   AJL -Changed the NotYetImplemented calls to Warn.
                         -Exit LinkChildren earlier if out of memory.
       Jan. 28, 88   AJL -Check for missing doppleganger tasks better in
                          UnlinkChildren.
       Feb. 8,  88   AJL -When checking which links are to tasks that are
                          inside the family in LinkChildren, ignore links
                          that could cause a dependant task to start earlier
                          than its antecedant.  This way, we will have links
                          to all of the earliest and latest tasks in the
                          family. 
       Feb. 10, 88   AJL -Changed calls to AddEdge so that they do not 
                          alter the task's status.
       Feb. 22, 88   RSC -removed debugging code prep for ship.
       Feb. 22, 88   AJL -Removed NotYetImplemented.  
       Feb. 25, 88   AJL -Added a parameter to allow the Feb. 8 change to
                          be conditional.  The Network drawing is affected
                          adversely by it.
       Mar. 2, 88    AJL -Tighten error checking in MoveDependents.
                         -Fill in Doppleganger Task names, in part to aid
                          debugging, but also so that the error reporting
                          in TLPlan that complains about summary partial
                          joins will have a name to work with. 

       Sep. 20, 88   RSC -Speedups in LinkChildren.
       Apr. 18, 89   AJL -Create the RelocateDependants and RestoreDependants
                          procedures separately from the MoveDependants 
                          procedure so that we can handle dependencies from
                          the start and to the end of summary tasks.
                         -Use the new edge records.
       Apr. 28, 89   AJL -Removed the IgnoreTime parameter from 
                          CreateSummaryPhantoms. 
                         -Commented out the code for recording the 
                          rigid dependencies.  This was never tested and 
                          is not currently needed.
       May  15, 89   AJL -Summary phantom tasknames now have apostrophes
                          at the end even if the original taskname is
                          30 characters long. 
       Jul  25, 89   AJL -Removed an unused import of BreakRequested.
       Aug  30, 89   AJL -Added a new procedure, MoveStatus, that is used
                          during DiscardSummaryPhantoms.  It moves 
                          status and date information from the Phantom
                          to the real task.  This is so that the summary can
                          incorporate the critical path flags and end dates
                          computed for the end milestone.
       Sep 12, 1989  AJL -Removed the procedure MoveStatus to TLPlan.
       Sep 22, 1989  AJL -Link the summary started to precede the summary ender
                          so that, even in the presence of weird partial dependencies,
                          summary tasks will end no sooner than their start date.
       Sep 16, 90    AJL -When creating doppleganger tasks, set
                          TempTaskFlags := ATempTaskFlagSet{SummaryFlag,PhantomFlag};
                          eliminating any previous contents.
       21-Nov-90     AJL -Remove the NoSoonerStart and NoLaterStart flags
                          from doppleganger tasks.
                         -Remove the NoSoonerEnd and NoLaterEnd flags from
                          the original parent task.  Unless we modify the
                          DiscardSummaryPhantoms procedure to restore these
                          flags (from the doppleganger) Summary tasks
                          will not be able to have required end dates (at
                          present, we don't support required ends for any
                          tasks.)
                          
                          
    *)


    (*<KILL (*$R+*) (*$T+*) KILL>*)

FROM Allocs    IMPORT
    (* CONST *)         TskNmLen,
    (* TYPE *)          ATask, ADateBlock, AnAssignmentSummary,
                        ATaskPtr, ATaskName, AFixType,
                        AStartStatus, ATaskFlag, ATaskFlagSet, ARollupStatus,
                        ATaskStatusSet, ATaskStatus, ADurationMethod,
                        ATempTaskFlag, ATempTaskFlagSet,
    (* VAR *)           TaskTree,
                        StartStatusName,
    (* PROC *)          CheckTaskValid,
                        CreateTask, DelTask;


FROM Dialog      IMPORT
    (* PROC *)          Message, Error, FatalError, NotYetImplemented;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr, AnEdgeAttribute, AnEdgeType,
                                ASetOfEdgeAttributes,
    (* PROC *)                  CheckEdgeValid, FindEdge, DelEdge,
                                CreateEdge, AddEdge, RemoveEdge,
                                CopyEdgeContents;

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
    (* CONST *)         Visited, TerminalFlag,
    (* VAR  *)          PrivateTaskList,
    (* PROC *)          AddBefore, DeList;

FROM Space       IMPORT
    (* PROC *)          Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM      IMPORT
    (* TYPE *)          ADDRESS,
    (* PROC *)          ADR, SIZE, TSIZE;

FROM TreeObjects IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder, ATreeNodeAttribute,
    (* PROC *)          ValidateTree, ValidateTreeNode;


CONST
    ModuleNumber = 21600;
        (* Flags to mark task nodes as being terminal tasks within a
           family.  We mark the nodes instead of the task records in
           order to reduce disk i/o. *)
    StarterNode = SelfMatch;
    EnderNode   = ChildrenMatch;




TYPE
        (*---------------- Not currently used 
    ATaskRefPointer = POINTER TO ATaskRefRecord;
    ATaskRefRecord = RECORD
                         TaskNode : ATreeNode;
                         Link     : ATaskRefPointer;
                     END;
     -------------------------------------  *)
           

   ALinkChildrenContext = RECORD
                              (* --- RigidTasksList : ATaskRefPointer; --- *)
                              InitializeTask : AnInitializeTaskProc;
                              ok : BOOLEAN;
                          END; 




    (* Procedures for creating phantom doubles of the summary tasks. *)


PROCEDURE UnmarkTask  (VAR TaskTreeNode : ATreeNode;
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
        TempTaskFlags := TempTaskFlags - ATempTaskFlagSet{SummaryFlag, PhantomFlag };
        WorkSpace := TaskTreeNode;   (* Link back to the node. *)
    END;

        (* Add this task to the private task list. *)

    AddBefore(PrivateTaskList, TaskHandle );

        (* Do any extra local processing. *)

    ExtraWork(TaskTreeNode,Task);

    ReleaseObject(TaskHandle);    (*<KILL*) Task := NIL; (*KILL>*)

END UnmarkTask;




    (* Scan1 must be repeatable without damage. *)


PROCEDURE Scan1( ExtraWork : AT2Proc );
VAR
    TaskPtr     : ATaskPtr;
BEGIN
    IF LockObject (PrivateTaskList, TaskPtr) <> TSIZE(ATask) THEN
        FatalError();
    END;
    TaskPtr^.Nextlink := PrivateTaskList;
    TaskPtr^.Prevlink := PrivateTaskList;
    ReleaseObject (PrivateTaskList);  (*<KILL*) TaskPtr := NIL; (*KILL>*)

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    UnmarkTask, ADDRESS(ExtraWork));
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
                              (*<KILL ToTask := NIL; KILL>*)
    FromTaskNode^.Methods^.UnlockFlexStorDataObject(FromTaskNode);
                              (*<KILL FromTask := NIL; KILL>*)

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
            NewLink := CreateEdge(SummaryStartNode,TaskNodeB);  (* Add to other *)
            CopyEdgeContents(TempEdge,NewLink^);
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
            NewLink := CreateEdge(TaskNodeB,SummaryEndNode);    (* Add to other *)
            CopyEdgeContents(TempEdge,NewLink^);
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
        NewLink := CreateEdge(SummaryEndNode,TaskNodeB);      (* Add to other *)
        CopyEdgeContents(TempEdge,NewLink^);
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
        NewLink := CreateEdge(TaskNodeB,SummaryStartNode);    (* Add to other *)
        CopyEdgeContents(TempEdge,NewLink^);
        EXCL(TempEdge.Attributes,Relocated);                  (* Note that it was moved. *)
        AddEdge(NewLink,FALSE);
           (* Start searching again. *)
        Link := QueryAntecedantList(SummaryEndNode);
    END;

END RestoreDependants;




PROCEDURE RemoveAnyLink(   Parent,
                           Child         : ATreeNode );
VAR
    EdgePtr         : AnEdgePtr;
BEGIN
    EdgePtr := FindEdge(Parent,Child);
    IF (EdgePtr <> NIL) THEN
        RemoveEdge(EdgePtr);
    END;
    EdgePtr := FindEdge(Child,Parent);
    IF (EdgePtr <> NIL) THEN
        RemoveEdge(EdgePtr);
    END;
END RemoveAnyLink;



    (* This will only work properly if traversed ParentBeforeChild. *)

PROCEDURE LinkChildren(VAR Parent         : ATreeNode;
                           Context        : ADDRESS);
VAR
    ParentTask, ChildTask : ATaskPtr;
    InitialChild, Child : ATreeNode;
    AnteLink, DescLink : AnEdgePtr;
    EdgePtr : AnEdgePtr;
    LinkedTask : ATaskPtr;
    DopplegangerTaskHandle : AnExtHandle;
    DopplegangerTask : ATaskPtr;
    DopplegangerNode : ATreeNode;
    LinkContext : POINTER TO ALinkChildrenContext; 
    ok : POINTER TO BOOLEAN;
    ParentName : ATaskName;
    ParentFlags : ATaskFlagSet;
    (*<DEBUG*) ParentID : CARDINAL; (*DEBUG>*)

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
    IF (InitialChild <> NIL) THEN  (* A Summary Task *)
        ParentTask := Parent^.Methods^.LockFlexStorDataObject(Parent);
        INCL(ParentTask^.TempTaskFlags,SummaryFlag);
        Copy(ParentTask^.taskname,ParentName);
        ParentFlags := ParentTask^.TaskFlags;
        ParentTask^.TaskFlags := 
            ParentFlags - ATaskFlagSet{NoSoonerEnd,NoLaterEnd};
        (*<DEBUG*) ParentID :=ParentTask^.TaskID; (*DEBUG>*)
        Parent^.Methods^.UnlockFlexStorDataObject(Parent);
                          (*<KILL*) ParentTask := NIL; (*KILL>*)
           (* For each child task,
              remove any links from child to the parent task. 
              This is because our model of a schedule isn't supposed
              to have any parent-child links, and we will assume that
              any that exist were put there by us, and should be
              removed in UnlinkChildren.  *)
        Child := InitialChild;
        WHILE (Child <> NIL) DO
               (* This could be improved to also check grandparents. *)
           RemoveAnyLink(Parent,Child);
           Child := Child^.Methods^.GetNext(Child);
        END;
            (* Create a "phantom" copy of the summary task.  This will
               represent the ending of the summary.  Move all of the
               antecedant dependencies from summary to its double.
               In the workspace of the original task, record the
               doppleganger, and visa versa. *)
        IF (Available(500) ) THEN
            DopplegangerNode := CreateTask();
            IF (DopplegangerNode <> NIL) THEN
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
                       part here.  ALAP is handled in the planning.
                       We make them ALAP so that they will not push any
                       tasks to be earlier. *)
                    (* Link task to the node. *)
                WITH DopplegangerTask^ DO
                    WorkSpace := DopplegangerNode;
                    TaskFlags := ParentFlags - ATaskFlagSet{NoSoonerStart,NoLaterStart};
                    TempTaskFlags := ATempTaskFlagSet{SummaryFlag,PhantomFlag};
                    (*<DEBUG*)
                    Copy(ParentName,taskname);
                    IF (ORD(ParentName[0]) < HIGH(taskname)) THEN
                        ConcatS(taskname,"'");
                    ELSE
                        taskname[ORD(taskname[0])] := "'"; 
                    END;
                    TaskID := ParentID + 10000;
                      (*DEBUG>*)
                    LinkContext^.InitializeTask(DopplegangerNode,DopplegangerTask);
                END;
                ReleaseObject(DopplegangerTaskHandle);
                                (*<KILL*)  DopplegangerTask := NIL; (*KILL>*)
                    (* Link the summary started to precede the summary ender
                       so that, even in the presence of weird partial dependencies,
                       summary tasks will end no sooner than their start date.  *) 
                EdgePtr := CreateEdge (Parent, DopplegangerNode);
                IF (EdgePtr = NIL) THEN
                    Warn(2);
                ELSE
                    AddEdge (EdgePtr, FALSE);
                    INCL(EdgePtr^.Attributes,PhantomPredecessor);
                END;
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
               (* Unmark descendant tasks with normal joins. *)
               (* At the same time, note which tasks have Rigid dependencies. *)
           WHILE (DescLink <> NIL) DO
               WITH DescLink^ DO 
                   IF ((FromOffset.Plus) AND (NOT FromOffset.Start)) THEN
                       tailtask^.Methods^.SetAttributeBit( tailtask, StarterNode, FALSE);
                   END;
                   (*  --------------- Not currently used 
                   IF (Type = Rigid) THEN                   (* Record antecedant task. *)
                       RememberTask(LinkContext^.RigidTasksList,Child);
                   END;
                   ----------------------------- *)
               END;
               DescLink := DescLink^.headlink;
           END;
               (* Unmark antecedant tasks (with normal joins). *)
           WHILE (AnteLink <> NIL) DO
               WITH AnteLink^ DO 
                   IF ((FromOffset.Plus) AND (NOT FromOffset.Start)) THEN
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
               EdgePtr := CreateEdge (Parent, Child);
               IF (EdgePtr = NIL) THEN
                   Warn(2);
               ELSE
                   AddEdge (EdgePtr, FALSE);
                   INCL(EdgePtr^.Attributes,PhantomPredecessor);
               END;
           END;

           IF (Child^.Methods^.TestAttributeBit( Child, EnderNode )) THEN
               EdgePtr := CreateEdge (Child, DopplegangerNode);
               IF (EdgePtr = NIL) THEN
                   Warn(2);
               ELSE
                   AddEdge (EdgePtr, FALSE);
                   INCL(EdgePtr^.Attributes,PhantomSuccessor);
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
    END;

END LinkChildren;




PROCEDURE CreateSummaryPhantoms( InitializeTaskProc : AnInitializeTaskProc ):BOOLEAN;
VAR
    LinkContext : ALinkChildrenContext;
BEGIN
    
    WITH LinkContext DO
        ok := TRUE;
        InitializeTask := InitializeTaskProc;
        (* RigidTasksList := NIL; *)
    END;

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    LinkChildren, ADR(LinkContext) );

    (* 
    IF (LinkContext.ok) THEN
        AttachRigidDependencies(LinkContext.RigidTasksList);
    ELSE
        DisposeRigidTasksList(LinkContext.RigidTasksList);
    END;
    *)

    RETURN LinkContext.ok;

END CreateSummaryPhantoms;







PROCEDURE UnLinkChildren(VAR Parent         : ATreeNode;
                             Context        : ADDRESS);
VAR
    Child : ATreeNode;
    NextLink : AnEdgePtr;
    DopplegangerNode : ATreeNode;
    DopplegangerTask : ATaskPtr;
    AllIsInOrder : BOOLEAN;

    S : ARRAY [0..255] OF CHAR;
BEGIN
    Child := Parent^.Methods^.FirstChild(Parent);
    IF (Child <> NIL) THEN  (* A Summary Task *)

            (* This ABSOLUTELY REQUIRES that the doppleganger was
               placed into the list immediately following the real
               task. *)

        DopplegangerNode := Parent^.Methods^.GetNext(Parent);

        
        IF (DopplegangerNode <> NIL) THEN
            DopplegangerTask := DopplegangerNode^.Methods^.LockFlexStorDataObject(DopplegangerNode);
            AllIsInOrder := (PhantomFlag IN DopplegangerTask^.TempTaskFlags);
            DopplegangerNode^.Methods^.UnlockUnchangedDataObject(DopplegangerNode);
        ELSE
            AllIsInOrder := FALSE;    (* Missing doppleganger task. *)
        END;



        IF (AllIsInOrder) THEN
  
            RemoveAnyLink(Parent,DopplegangerNode);

              (* For each child task,
                 remove any links from child to the parent task. *)
            WHILE (Child <> NIL) DO
               RemoveAnyLink(Parent,Child);
               RemoveAnyLink(Child,DopplegangerNode);
               Child := Child^.Methods^.GetNext(Child);
            END;
        
                (* Move the antecedant links from the Doppleganger back to
                   the summary task. *)
            RestoreDependants(Parent,DopplegangerNode);

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
               try to delete it.    
            NotYetImplemented("Missing Doppleganger detected"); 
            *)
        END;
 
     END;
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




(*--------------------------- Not currently used --------------------
    (* Procedures to create the links for rigid dependencies *)


PROCEDURE RememberTask( List : ATaskRefPointer;  Task : ATreeNode );
VAR
    NewNode : ATaskRefPointer;
BEGIN
        (* Search list, avoid duplicates. *)
    NewNode := List;
    WHILE (NewNode <> NIL) DO
        IF (NewNode^.TaskNode = Task) THEN
            RETURN;
        END;
        NewNode := NewNode^.Link;
    END;

        (* Add to linked list. *)
    IF (Available(SIZE(NewNode))) THEN
        NEW(NewNode);
        NewNode^.Link := List;
        NewNode^.TaskNode := Task;
        List := NewNode;
    END;
END RememberTask;



PROCEDURE CreateRigidAttachments( RigidEdge : AnEdge );
VAR
    AntecedantNode, SuccessorNode : ATreeNode;
    AntecedantTask : ATaskPtr;
    AntecedantEdge, SucessorEdge, NewEdge : AnEdgePtr;
BEGIN
    NotYetImplemented("Create rigid attachments.");
    (*
    AntecedantNode := RigidEdge.headtask;
    SuccessorNode  := RigidEdge.tailtask;

        (* Loop over the antecedant edges of the antecedant task, copying each
           to the successor task. *)
    AntecedantTask := AntecedantNode^.Methods^.LockFlexStorDataObject(AntecedantNode);
    AntecedantEdge := AntecedantTask^.desctasks;
    AntecedantNode^.Methods^.UnlockUnchangedDataObject(AntecedantNode);
    WHILE (AntecedantEdge <> NIL) DO
        AntecedantEdge := AntecedantEdge^.headlink;
    END;

        (* Loop over the successor edges of the successor task, copying each
           to the Antecedant task. *)
    SuccessorTask := SuccessorNode^.Methods^.LockFlexStorDataObject(SuccessorNode);
    SuccessorEdge := SuccessorTask^.antetasks;
    SuccessorNode^.Methods^.UnlockUnchangedDataObject(SuccessorNode);
    WHILE (SuccessorEdge <> NIL) DO
        SuccessorEdge := SuccessorEdge^.taillink;
    END;


    *)
END CreateRigidAttachments;



PROCEDURE AttachRigidDependencies(  RigidTasksList : ATaskRefPointer );
VAR
    Reference : ATaskRefPointer;
    AntecedantNode : ATreeNode;
    AntecedantTask : ATaskPtr;
    DescLink : AnEdgePtr;
BEGIN
        (* Roam over the RigidTasksList, adjusting each. *)
    WHILE (RigidTasksList <> NIL) DO
        Reference := RigidTasksList;
            (* Get the list of descendant tasks. *)
        AntecedantNode := Reference^.TaskNode;
        AntecedantTask := AntecedantNode^.Methods^.LockFlexStorDataObject(AntecedantNode);
        DescLink := AntecedantTask^.desctasks;
        AntecedantNode^.Methods^.UnlockUnchangedDataObject(AntecedantNode);
                               (*<KILL*) AntecedantTask := NIL; (*KILL>*)
            (* Scan the list of descendant tasks. *)
        WHILE (DescLink <> NIL) DO
            IF (DescLink^.Type = Rigid) THEN
                CreateRigidAttachments(DescLink^);
            END;
            DescLink := DescLink^.headlink;
        END;
            (* Dispose of the current RigidTasksList entry and go on to 
               next. *)
        RigidTasksList := RigidTasksList^.Link;
        DISPOSE(Reference);
    END;

END AttachRigidDependencies;


PROCEDURE DisposeRigidTasksList(  RigidTasksList : ATaskRefPointer );
VAR
    Reference : ATaskRefPointer;
BEGIN
        (* Roam over the RigidTasksList, disposing each. *)
    WHILE (RigidTasksList <> NIL) DO
        Reference := RigidTasksList;
            (* Dispose of the current RigidTasksList entry and go on to 
               next. *)
        RigidTasksList := RigidTasksList^.Link;
        DISPOSE(Reference);
    END;
END DisposeRigidTasksList;
------------------------------------------------------  *)



END Phantoms.



