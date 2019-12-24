IMPLEMENTATION MODULE Edges;


 (* Modification History:

       10-Jan-89 RSC   -Changed Storage to Space.
       20 MAr 89 AJL   -Initialize Type and Attributes.
                       -Added a DeadEdgeList to reduce ALLOCATE and DEALLOCATE.
       14-May 89 AJL   -Reduce the heap consumption of the dead edge list. 
                        Do this by flushing the list whenever an overlay
                        loads or exits.  The intent here is to reduce the
                        retention of unused edges in heap blocks that would
                        fragment memory.
        4-Jun-89 EGK    Removed unnecessary imports from Undo module.
       16 Jun 89 RSC   -Added "InitializeEdges".  Lowered Edge Cache to 5
                        from 50 as per AJL.
       30 Aug 89 AJL   -Initialize Edge.Delta to 0 when an edge is created.
       21-Feb-90 KKC   -Remove all unreferenced id from Timeu.
       30-Mar-90 RSC    Removed Timeu, replaced with Timei.
       25-Jan-91 RSC    Added some no-lock versions of routines:
                        FindEdgeInTask, CreateEdgeDammit, AddEdgeWithTasks.
 *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ATaskStatus, ATaskStatusSet,
    (* PROC *)                  CheckTaskValid;

FROM Dialog                 IMPORT
   (* PROCS *)                  NotYetImplemented, Message, Error,
                                FatalError, Burp;

FROM MsgFile                IMPORT
   (* PROCS *)                  GetMessage, DisplayMessage, ConcatMessage;

FROM Notices                IMPORT
   (* TYPE *)                   AnOccasion, AStep,
   (* PROC *)                   RegisterForNotices;


FROM Space                  IMPORT
  (* PROCS *)                   ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM                 IMPORT
  (* TYPES *)                   ADDRESS,
  (* PROCS *)                   TSIZE, ADR;

FROM Timei                  IMPORT
  (* CONST *)                   NoDuration,
    (* TYPE *)                  ADurationUnit;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder, ATree,
    (* PROC *)                  CreateTree, CreateTreeNode, ValidateTreeNode;



CONST
    ModuleNumber = 0700;  (* For GetMessage, same # as Allocs for now *)

    EdgeRecTag = 233; (* Code confirms that this is an edge record. *)
    DeadEdgeTag = 41; (* A deleted edge. *)  

    MinSpace   = 500;   (* Minimum Heap Space we'll tolerate. *)

TYPE
    AnEdgesTask   = ATaskPtr;

CONST
    DeadEdgeLimit = 5;  (* Maximum number of unused edge records we will 
                           cache rather than DISPOSE. *)

VAR
    DeadEdgeList  : AnEdgePtr;
    DeadEdgeCount : CARDINAL;
    CheckDepth    : CARDINAL;



PROCEDURE XCheckEdgeValid(Edge:AnEdgePtr);
BEGIN
    IF (Edge = NIL)                 OR
       (Edge^.rectag <> EdgeRecTag) THEN
        FatalError();
    END;
        (* Debugging 2/2/88 AJL  *)
        (*<DEBUG
    INC(CheckDepth);
    IF (CheckDepth <= 1) THEN
        CheckTaskValid(Edge^.tailtask);
        CheckTaskValid(Edge^.headtask);
    END;
    DEC(CheckDepth);
        DEBUG>*)
END XCheckEdgeValid;






PROCEDURE FindEdgeInTask(   PriorTask : AnEdgesTask;
                            After     : ATreeNode) : AnEdgePtr;
VAR
    newedge                 : AnEdgePtr;
BEGIN
    newedge := PriorTask^.desctasks;

    WHILE (newedge <> NIL) DO
        CheckEdgeValid(newedge);
        IF (newedge^.tailtask=After) THEN
            RETURN newedge;
        ELSE
            newedge := newedge^.headlink
        END;
    END;
    RETURN NIL;
END FindEdgeInTask;




    (*  FindEdge -- Returns a pointer to the Edge between the two tasks
                    (if there is one) or else NIL.  *)


PROCEDURE FindEdge (Prior,After : ATreeNode) : AnEdgePtr;

VAR
    newedge                 : AnEdgePtr;
    PriorTask               : AnEdgesTask;
BEGIN
    CheckTaskValid(Prior);
    CheckTaskValid(After);

    PriorTask := Prior^.Methods^.LockFlexStorDataObject(Prior);
    newedge   := FindEdgeInTask( PriorTask, After );
    Prior^.Methods^.UnlockUnchangedDataObject(Prior);             (* 11-Jan-88 LAA *)

    RETURN newedge;

END FindEdge;





    (* ITDEPENDS -- Tells if after task depends on prior task. *)

PROCEDURE ItDepends (Prior,After : ATreeNode) : BOOLEAN;
BEGIN
    RETURN FindEdge(Prior,After) <> AnEdgePtr(NIL);
END ItDepends;








PROCEDURE CreateEdgeDammit ( Prior, After : ATreeNode ) : AnEdgePtr;
VAR
    newedge       : AnEdgePtr;
BEGIN
    IF (After = Prior)       OR
       (NOT Available(MinSpace)) THEN
        RETURN NIL;
    END;

        (* Create an edge node. *)

    IF (DeadEdgeCount > 0) THEN
        newedge := DeadEdgeList;
        DeadEdgeList := DeadEdgeList^.headlink;
        (* DEBUGGING *) IF newedge^.rectag <> DeadEdgeTag THEN FatalError(); END;
        DEC(DeadEdgeCount);
    ELSE
        NEW(newedge);
    END;

    WITH newedge^ DO
        rectag    := EdgeRecTag;
        headtask  := Prior;
        tailtask  := After;
        WITH FromOffset DO
            Start := FALSE;
            Plus  := TRUE;
            Dur   := NoDuration;
            Scale := Minutes;
        END;
        ToOffset.Start := TRUE;
        Attributes := ASetOfEdgeAttributes{};
        Delta      := 0;
        Type       := Flexible;
    END;

    RETURN newedge;

END CreateEdgeDammit;





PROCEDURE CreateEdge ( Prior, After : ATreeNode ) : AnEdgePtr;
VAR
    s             : ARRAY [0..255] OF CHAR;
BEGIN
    CheckTaskValid(Prior);
    CheckTaskValid(After);

        (* Check for redundancy. *)

    IF (ItDepends(Prior,After)) OR (ItDepends(After,Prior)) THEN
        GetMessage(ModuleNumber+1, s);    (* "Already joined" *)
        Error(s);
        RETURN NIL;
    END;

    RETURN CreateEdgeDammit ( Prior, After );

END CreateEdge;





PROCEDURE AddEdgeWithTasks( EdgePtr         : AnEdgePtr;
                            PriorTask       : AnEdgesTask;
                            AfterTask       : AnEdgesTask;
                            ChangeStatus    : BOOLEAN );
BEGIN
    CheckEdgeValid (EdgePtr);
    WITH EdgePtr^ DO
        headlink := PriorTask^.desctasks;
        taillink := AfterTask^.antetasks;
    END;
    PriorTask^.desctasks := EdgePtr;
    AfterTask^.antetasks := EdgePtr;

    IF (ChangeStatus) THEN
        PriorTask^.TaskStatusSet := ATaskStatusSet{NeedsRecalculate};
        AfterTask^.TaskStatusSet := ATaskStatusSet{NeedsRecalculate};
    END;

END AddEdgeWithTasks;



PROCEDURE AddEdge( EdgePtr : AnEdgePtr; ChangeStatus : BOOLEAN );
VAR
    PriorTask           : AnEdgesTask;
    AfterTask           : AnEdgesTask;
BEGIN
    CheckEdgeValid (EdgePtr);
    WITH EdgePtr^ DO
        PriorTask := headtask^.Methods^.LockFlexStorDataObject (headtask);
        AfterTask := tailtask^.Methods^.LockFlexStorDataObject (tailtask);

        AddEdgeWithTasks( EdgePtr, PriorTask, AfterTask, ChangeStatus );

        headtask^.Methods^.UnlockFlexStorDataObject (headtask);
        tailtask^.Methods^.UnlockFlexStorDataObject (tailtask);
    END;

END AddEdge;



(*----------------------------------------------------------------------------
    CopyEdgeContents --

    Copy the data describing the edge, except the identity of the From and
    To tasks, from the Source to the Destination Edge.

    Preconditions:
        The two parameters must be valid task nodes.

    Postconditions:
        The second edge will be the same type of edge, in all internal 
        contents except the identification of the joined tasks. 
----------------------------------------------------------------------------*)
PROCEDURE CopyEdgeContents(     SourceEdge : AnEdge; 
                            VAR DestEdge : AnEdge ); 
BEGIN
    WITH DestEdge DO
        FromOffset := SourceEdge.FromOffset;
        ToOffset   := SourceEdge.ToOffset;
        Attributes := SourceEdge.Attributes;
        Type       := SourceEdge.Type;
        Delta      := SourceEdge.Delta;
        Z          := SourceEdge.Z;
    END;
        
END CopyEdgeContents;




PROCEDURE RemoveEdge ( VAR EdgePtr : AnEdgePtr );

VAR
    oldedgea, oldedgeb,
    curedgea, curedgeb      : AnEdgePtr;
    TaskForA                : ATaskPtr;
    TaskForB                : ATaskPtr;

BEGIN
    CheckEdgeValid (EdgePtr);

    WITH EdgePtr^ DO
        TaskForA := headtask^.Methods^.LockFlexStorDataObject(headtask);
        TaskForB := tailtask^.Methods^.LockFlexStorDataObject(tailtask);
    END;

    oldedgea := NIL;
    curedgea := TaskForA^.desctasks;
    LOOP
        IF (curedgea = NIL) THEN
            FatalError();
            RETURN;
        ELSE
            CheckEdgeValid(curedgea);
            IF (curedgea^.tailtask = EdgePtr^.tailtask) THEN EXIT; END;
        END;
        oldedgea := curedgea;
        curedgea := curedgea^.headlink;
    END;

    oldedgeb := NIL;
    curedgeb := TaskForB^.antetasks;
    WHILE (curedgeb <> curedgea) DO
        CheckEdgeValid(curedgeb);
        oldedgeb := curedgeb;
        curedgeb := curedgeb^.taillink;
        IF (curedgeb = NIL) THEN FatalError END;
    END;

        (*  Pass the new edge over with its neighbor's links. *)

    IF (oldedgea = NIL) THEN
        TaskForA^.desctasks := curedgea^.headlink
    ELSE
        oldedgea^.headlink := curedgea^.headlink;
    END;

                      (* nb: curedgea = curedgeb. *)

    IF (oldedgeb = NIL) THEN
        TaskForB^.antetasks := curedgea^.taillink
    ELSE
        oldedgeb^.taillink := curedgea^.taillink;
    END;

    WITH EdgePtr^ DO
        headtask^.Methods^.UnlockFlexStorDataObject(headtask);
        tailtask^.Methods^.UnlockFlexStorDataObject(tailtask);
        TaskForA := NIL;                                          (* 28-Dec-87 LAA *)
        TaskForB := NIL;
    END;

        (* Throw the old edge away. *)

    DelEdge (EdgePtr);

END RemoveEdge;





PROCEDURE DelEdge   ( VAR EdgePtr      : AnEdgePtr);
BEGIN
    EdgePtr^.rectag := DeadEdgeTag;
    IF (DeadEdgeCount < DeadEdgeLimit) THEN
        EdgePtr^.headlink := DeadEdgeList;
        DeadEdgeList      := EdgePtr;
        INC(DeadEdgeCount);
    ELSE
        DISPOSE (EdgePtr);
    END;
END DelEdge;




PROCEDURE FlushDeadEdges( Occasion : AnOccasion; 
                          Step : AStep; 
                          A : ADDRESS ) : BOOLEAN;
VAR
    Temp : AnEdgePtr;
BEGIN
    WHILE DeadEdgeList <> NIL DO
        Temp := DeadEdgeList;
        DeadEdgeList := Temp^.headlink;
        DISPOSE(Temp); 
    END;
    DeadEdgeCount := 0;
    RETURN TRUE;
END FlushDeadEdges;


    (* Do the initialization that we should defer until after the program
       is safely running. *)

PROCEDURE InitializeEdges();
BEGIN
    RegisterForNotices(OverlayCall,FlushDeadEdges);
    RegisterForNotices(ModelErase,FlushDeadEdges);
    RegisterForNotices(ProgramEnd,FlushDeadEdges);
END InitializeEdges;


BEGIN
    DeadEdgeList  := NIL;
    DeadEdgeCount := 0;
    CheckDepth    := 0;
    CheckEdgeValid := XCheckEdgeValid;
END Edges.
