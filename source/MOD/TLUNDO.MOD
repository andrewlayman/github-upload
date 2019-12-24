MODULE TLUndo;

(*  =========================================================================
    Last Edit : June 27, 1991 9:40AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Undo's guts, removed from Undo.Mod to take out of the root.

    MODIFICATION HISTORY:

        20-Jun-91 RSC First version, from UNDO.MOD.
        26-Jun-91 RSC Minor fixes, caused from tearing out the code from
                      the root.
                      A) Put back a condition test I thought could never
                         happen (and, of course, does) in UndoTransaction
                         when it wants to create a transaction set.  When
                         aborting a transaction, I was adding more things
                         to the undo list.
                      B) Only message undo messages when we are not
                         aborting.
                      C) It is not enough to save the ChartState anymore
                         to see if we need a recalc.  We also need to
                         save and restore the CalculationState.
        15-Jul-91 LAA In RestoreState, don't mess with the ChartState if it
                      hasn't been changed!  Because of the slightly changed
                      meaning of Scheduled, the test of Scheduled IN 
                      ChartState was causing extra, unnecessary redisplays
                      of the Gantt chart.  Bug #4727.
        16-Jul-91 LAA In SaveState, Roger was doing an UnSetState(Scheduled)
                      if the CalculationState.DataIsValid was FALSE.  This
                      was too aggressive, since if forces PrepareChart to
                      do a lot of extra display work.  I made it conditional
                      on the ChartState and DataIsValid being inconsistent.
    =========================================================================
*)


FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr,
    (* VAR  *)                  TaskTree,
    (* PROC *)                  CreateTask, CopyTask, DelTask,
                                CheckTaskValid,
                                AddTask, RemoveTask,
                                FindTaskByNumber, CreateTaskWithSpeed;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord,
    (* PROC *)                  ForEachAssignment;

FROM Chart                  IMPORT
    (* VAR  *)                  BugTaskA, BugTaskB;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState, AChartStateSet,
    (* VAR  *)                  ChartState,
    (* PROC *)                  SetState, UnSetState;

FROM Codes                  IMPORT
    (* CONST *)                 MaxCode,
    (* TYPE *)                  ACode,
    (* PROC *)                  SetCodeBits;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  NotYetImplemented, FatalError,
                                WarningBox, Error, Burp, Message;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr,
    (* PROC *)                  FindEdge, CheckEdgeValid, DelEdge,
                                AddEdge, RemoveEdge, CopyEdgeContents;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtStoragePreference;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow,
    (* TYPE *)                  avidmode;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, CtoS, ConcatS, ConcatLS, SetLengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices, RegisterForNotices;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineView;

FROM Overlays   IMPORT
    (* PROC *)      AnOverlayID, ImAnInstallableOverlay,
                    OverlayContext;

FROM OvTree     IMPORT
    (* PROC *)      AnOverlayProc;

FROM Planner                IMPORT 
    (* TYPE *)                 ACalcComponent, AWhenToCalc, 
    (* VAR *)                  ScheduleComputedOk, CalculationState;

FROM RsrcMod    IMPORT
    (* TYPE *)      AResourcePointer,
    (* VAR  *)      ResourceTree,
    (* PROC *)      CreateResource, DeleteResource,
                    AddResource, RemoveResource,
                    FindResourceByNumber, CopyResourceNode,
                    ChangedResource;

FROM Space      IMPORT
    (* PROC *)      ALLOCATE, DEALLOCATE, Available, HeapAvailable;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS;

FROM TreeObjects IMPORT
    (* TYPE *)      ATree, ATreeNode, ATreeOrder,
    (* PROC *)      CreateTree, CreateTreeNode;

FROM Undo       IMPORT
    (* TYPE *)      AnUndoableObject, AnUndoAction, AnUndoStatus,
    (* VAR *)       UndoTree, RedoTree, UndoStatus,
    (* PROC *)      GetUndoLimit;






(* CONST AND TYPES SHARED WITH UNDO.MOD -- KEEP IN SYNCH!!
*)
CONST
    ModuleNumber        = 20700;
    MinSpace            = 75;

TYPE

    ATransactionFlag    = (TUndone, TError);

    ATransactionFlagSet = SET OF ATransactionFlag;


    ATransactionRecordPointer = POINTER TO ATransactionRecord;

    ATransactionRecord  =   RECORD
        ID                  : CARDINAL;
        Type                : AnUndoableObject;
        Action              : AnUndoAction;
        TransactionFlags    : ATransactionFlagSet;
        DataObject          : ADDRESS;              (* Tree node or edge pointer *)

        CASE tag : AnUndoableObject OF
            Task, Resource :
                NodeID      : INTEGER;
                ParentID    : INTEGER;
                PrevID      : INTEGER;
        |   Edge :
                AnteID      : INTEGER;
                DescID      : INTEGER;
        ELSE
        END;

                            END;


    AStateRecordPointer = POINTER TO AStateRecord;

    AStateRecord =          RECORD
        ActiveChartType     : AnUndoableObject;
        BeforeChartState    : AChartStateSet;
        AfterChartState     : AChartStateSet;
        FirstNode           : INTEGER;
        CursorNode          : INTEGER;
        BugA                : INTEGER;
        BugB                : INTEGER;
        Open                : BOOLEAN;
        TSError             : BOOLEAN;
                            END;



VAR
    OverlayID       : AnOverlayID;

    Undoing         : BOOLEAN;







PROCEDURE GetTaskID ( Node : ATreeNode ) : INTEGER;
VAR
    Task            : ATaskPtr;
    ID              : INTEGER;

BEGIN
    IF (Node = NIL) THEN
        RETURN 0;
    END;

    CheckTaskValid (Node);
    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    ID := Task^.TaskID;
    Node^.Methods^.UnlockUnchangedDataObject (Node);
    RETURN ID;

END GetTaskID;



PROCEDURE GetRsrcID ( Node : ATreeNode ) : CARDINAL;
VAR
    ResourcePtr     : AResourcePointer;
BEGIN
    IF (Node = NIL) THEN
        RETURN 0;
    END;

    ResourcePtr := Node^.Methods^.GetDataObject (Node);
    RETURN ResourcePtr^.ID;

END GetRsrcID;


PROCEDURE AddTaskName   (VAR s          : ARRAY OF CHAR;
                             Node       : ATreeNode     );
VAR
    Task        : ATaskPtr;
BEGIN
    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    ConcatLS (s, Task^.taskname);
    Node^.Methods^.UnlockUnchangedDataObject (Node);
END AddTaskName;



PROCEDURE AddResourceName   (VAR s          : ARRAY OF CHAR;
                                 Node       : ATreeNode     );
VAR
    Resource        : AResourcePointer;
BEGIN
    Resource := Node^.Methods^.GetDataObject (Node);
    ConcatLS (s, Resource^.Name);
END AddResourceName;




PROCEDURE CodeAssignment (VAR AssignmentRecord  : AnAssignmentRecord;
                              Context           : ADDRESS            ): BOOLEAN;
VAR
    p       : ADDRESS;
BEGIN
    WITH AssignmentRecord DO
(*<OS2
        p := Resource;  (* Make segment a valid value *)
OS2>*)
        p.OFFSET := CARDINAL(Resource^.ID);
        Resource := p;
    END;
    RETURN TRUE;
END CodeAssignment;



PROCEDURE DecodeAssignment (VAR AssignmentRecord  : AnAssignmentRecord;
                                Context           : ADDRESS            ): BOOLEAN;
VAR
    p       : ADDRESS;
    Node    : ATreeNode;
BEGIN
    WITH AssignmentRecord DO
        p := Resource;
        Node := FindResourceByNumber (INTEGER(p.OFFSET));
        IF (Node <> NIL) THEN
            Resource := Node^.Methods^.GetDataObject (Node);
        ELSE
            Resource := NIL;
        END;
    END;
    RETURN TRUE;
END DecodeAssignment;




PROCEDURE DecodeTaskAssignments (Node       : ATreeNode);
(*  Convert the resource assignments to point back to real resources instead
    of just ID numbers.     *)
VAR
    TaskPtr         : ATaskPtr;
BEGIN
    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    ForEachAssignment (TaskPtr^.Plan.Assignments, DecodeAssignment, NIL);
    ForEachAssignment (TaskPtr^.BaseLine.Assignments, DecodeAssignment, NIL);
    Node^.Methods^.UnlockUnchangedDataObject (Node);
END DecodeTaskAssignments;



PROCEDURE CodeTaskAssignments (Node       : ATreeNode);
(*  Convert all resource pointers in the assignments to resource IDs.  This
    is necessary to restore the task if the resources were deleted and then
    undeleted.  *)
VAR
    TaskPtr         : ATaskPtr;
BEGIN
    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    ForEachAssignment (TaskPtr^.Plan.Assignments, CodeAssignment, NIL);
    ForEachAssignment (TaskPtr^.BaseLine.Assignments, CodeAssignment, NIL);
    Node^.Methods^.UnlockUnchangedDataObject (Node);
END CodeTaskAssignments;








PROCEDURE DiscardTransactionSet (VAR Node       : ATreeNode);
VAR
    Subtree         : ATree;
BEGIN
    IF (Node <> NIL) THEN
        Subtree := Node^.Methods^.GetSubtree (Node);
        IF (Subtree <> NIL) THEN
            Subtree^.Methods^.TraverseTree (Subtree, ParentAfterChild, 9999,
                    DiscardTransaction, NIL);
        END;
        DiscardTransaction (Node, NIL);
    END;
END DiscardTransactionSet;






PROCEDURE DiscardTransaction    (VAR Node       : ATreeNode;
                                     Context    : ADDRESS   );
VAR
    Transaction         : ATransactionRecordPointer;
    Status              : AStateRecordPointer;
    TaskNode            : ATreeNode;
    ResourceNode        : ATreeNode;
    EdgePtr             : AnEdgePtr;

    PROCEDURE RemoveTransactionData();
    BEGIN
        IF NOT (TError IN Transaction^.TransactionFlags) THEN
            CASE Transaction^.Type OF
                Task :
                    TaskNode := Transaction^.DataObject;
                    DelTask (TaskNode);
            |   Edge :
                    EdgePtr := Transaction^.DataObject;
                    DelEdge (EdgePtr);
            |   Resource :
                    ResourceNode := Transaction^.DataObject;
                    DeleteResource (ResourceNode);
            ELSE
            END;
        END;
    END RemoveTransactionData;

BEGIN
    IF (Node^.Methods^.IndentationLevel (Node) > 0) THEN
        Transaction := Node^.Methods^.GetDataObject (Node);
        CASE Transaction^.Action OF
            Change :
                RemoveTransactionData();
        |   Delete :
                IF NOT (TUndone IN Transaction^.TransactionFlags) THEN
                    RemoveTransactionData();
                END;
        |   Open, Close :
                TaskNode := Transaction^.DataObject;
                TaskNode^.Methods^.Discard (TaskNode);
        ELSE
        END;
        DISPOSE (Transaction);
    ELSE
        Status := Node^.Methods^.GetDataObject (Node);
        DISPOSE (Status);
    END;
    Node^.Methods^.Discard (Node);
END DiscardTransaction;








PROCEDURE CreateTransactionNode     (VAR Node : ATreeNode   ): BOOLEAN;
VAR
    TransactionPointer  : ATransactionRecordPointer;
    ParentNode          : ATreeNode;
    Status              : AStateRecordPointer;
BEGIN

    ParentNode := LastOpenTransactionSet (UndoTree);
    Status := ParentNode^.Methods^.GetDataObject (ParentNode);

    IF (NOT Available(MinSpace)) THEN
        Status^.TSError := TRUE;
        RETURN FALSE;
    END;
    NEW (TransactionPointer);
    IF (NOT CreateTreeNode (Node)) THEN
        DISPOSE (TransactionPointer);
        Status^.TSError := TRUE;
        RETURN FALSE;
    END;

    Node^.Methods^.SetDataObject (Node, TransactionPointer);
    TransactionPointer^.TransactionFlags := ATransactionFlagSet{};
    ParentNode^.Methods^.AddAsLastChild (ParentNode, Node);

    RETURN TRUE;

END CreateTransactionNode;









PROCEDURE NotifyUndo    (    UndoObject      : AnUndoableObject;
                             UndoAction      : AnUndoAction;
                             DataObject      : ADDRESS;
                         VAR ActiveChartType : AnUndoableObject;
                         VAR ActiveChart     : AnOutlineView );
VAR
    Node            : ATreeNode;
    Transaction     : ATransactionRecordPointer;
    ParentNode      : ATreeNode;
    NodeToCopy      : ATreeNode;
    EdgeToCopy      : AnEdgePtr;
    NewEdge         : AnEdgePtr;
    NewNode         : ATreeNode;
    TaskPtr         : ATaskPtr;
    Attributes      : CARDINAL;
    LocalError      : BOOLEAN;
    Status          : AStateRecordPointer;

BEGIN
    IF (UndoAction = None) THEN
        RETURN;
    END;

    IF (UndoAction = ChartActive) THEN
        ActiveChartType := UndoObject;
        ActiveChart     := DataObject;
        RETURN;
    END;

    IF (UndoStatus <> Active) THEN
        RETURN;
    END;

    ParentNode := LastOpenTransactionSet(UndoTree);
    Status := ParentNode^.Methods^.GetDataObject (ParentNode);

        (*  The following is kind of a kluge that ignores a "change"
            if the immediately preceding transaction was an "add",
            since presumably we have just added a defaulted object
            and are about to change it to what we really want.  This
            keeps undo from wastefully saving the defaulted original
            object, when all we really need to record is the addition
            of the changed object as a single step.
        *)

    IF (UndoAction = Change) THEN
        Node := ParentNode^.Methods^.LastChild (ParentNode);
        IF (Node <> NIL) THEN
            Transaction := Node^.Methods^.GetDataObject (Node);
            IF (Transaction^.Action = Add) THEN
                RETURN;
            END;
        END;
    END;

    IF (NOT CreateTransactionNode (Node)) THEN
        RETURN;
    END;

    Transaction := Node^.Methods^.GetDataObject (Node);
    Transaction^.Type := UndoObject;
    Transaction^.Action := UndoAction;

    CASE UndoObject OF
        Task :
            NodeToCopy := DataObject;
            CheckTaskValid (NodeToCopy);
            Transaction^.NodeID := GetTaskID (NodeToCopy);
            Transaction^.ParentID := GetTaskID (NodeToCopy^.Methods^.Parent (NodeToCopy));
            Transaction^.PrevID := GetTaskID (NodeToCopy^.Methods^.GetPrev (NodeToCopy));
    |   Edge :
            EdgeToCopy := DataObject;
            CheckEdgeValid (EdgeToCopy);
            Transaction^.AnteID := GetTaskID (EdgeToCopy^.headtask);
            Transaction^.DescID := GetTaskID (EdgeToCopy^.tailtask);
    |   Resource :
            NodeToCopy := DataObject;
            Transaction^.NodeID := GetRsrcID (NodeToCopy);
            Transaction^.PrevID := GetRsrcID (NodeToCopy^.Methods^.GetPrev (NodeToCopy));
    ELSE
    END;

    LocalError := FALSE;

    CASE UndoAction OF

        Add, Move :                   (* Nothing else to do *)

    |   Delete, Change :
            CASE UndoObject OF

                Task :
                    NewNode := CreateTaskWithSpeed (ExtSlow);
                    IF (NewNode <> NIL) THEN
                        CopyTask (NodeToCopy, NewNode);
                        CodeTaskAssignments (NewNode);
                        Transaction^.DataObject := NewNode;
                    ELSE
                        INCL (Transaction^.TransactionFlags, TError);
                        LocalError := TRUE;
                    END;

            |   Edge :
                    IF (Available(MinSpace)) THEN
                        NEW (NewEdge);
                        NewEdge^ := EdgeToCopy^;
                        Transaction^.DataObject := NewEdge;
                    ELSE
                        INCL (Transaction^.TransactionFlags, TError);
                        LocalError := TRUE;
                    END;

            |   Resource :
                    IF (CreateResource (NewNode)) THEN
                        CopyResourceNode (NodeToCopy, NewNode, TRUE);
                        Transaction^.DataObject := NewNode;
                    ELSE
                        INCL (Transaction^.TransactionFlags, TError);
                        LocalError := TRUE;
                    END;

            ELSE
                FatalError();
            END;

    |   Open, Close :
            CASE UndoObject OF

                Task :
                    IF (CreateTreeNode (NewNode)) THEN
                        Attributes := NodeToCopy^.Methods^.GetAttributes (NodeToCopy);
                        NewNode^.Methods^.SetAttributes (NewNode, Attributes);
                        Transaction^.DataObject := NewNode;
                    ELSE
                        INCL (Transaction^.TransactionFlags, TError);
                        LocalError := TRUE;
                    END;

            ELSE
                FatalError();
            END;
        
    ELSE
        FatalError();
    END;

    IF (LocalError) THEN
        Status^.TSError := TRUE;        (* This set ain't no good *)
    END;

END NotifyUndo;






PROCEDURE TransactionSetOpen   ( Node : ATreeNode   ) : BOOLEAN;
VAR
    Status      : AStateRecordPointer;
BEGIN
    Status := Node^.Methods^.GetDataObject (Node);
    RETURN Status^.Open;
END TransactionSetOpen;






PROCEDURE LastOpenTransactionSet   ( Tree      : ATree ) : ATreeNode;
VAR
    Node            : ATreeNode;
BEGIN
    Node := Tree^.Methods^.GetLast (Tree);
    WHILE (Node <> NIL) DO
        IF (TransactionSetOpen (Node)) THEN
            RETURN Node;
        ELSE
            Node := Node^.Methods^.GetPrev (Node);
        END;
    END;
    RETURN NIL;
END LastOpenTransactionSet;








PROCEDURE RestoreState(      State           : AStateRecordPointer;
                         VAR ActiveChartType : AnUndoableObject;
                         VAR ActiveChart     : AnOutlineView );
VAR
    FirstNode           : ATreeNode;
    CursorNode          : ATreeNode;
    Mask                : AChartStateSet;

BEGIN
    IF (ActiveChartType = State^.ActiveChartType) THEN
        CASE ActiveChartType OF
            Task :
                BugTaskA := FindTaskByNumber (State^.BugA);
                BugTaskB := FindTaskByNumber (State^.BugB);
                FirstNode := FindTaskByNumber (State^.FirstNode);
                ActiveChart^.Methods^.SetFirst (ActiveChart, FirstNode);
                CursorNode := FindTaskByNumber (State^.CursorNode);
                ActiveChart^.Methods^.SetCursorNode (ActiveChart, CursorNode);
        |   Resource :
                FirstNode := FindResourceByNumber (State^.FirstNode);
                CursorNode := FindResourceByNumber (State^.CursorNode);
                ActiveChart^.Methods^.SetFirst (ActiveChart, FirstNode);
                ActiveChart^.Methods^.SetCursorNode (ActiveChart, CursorNode);
        |   Edge :
                FirstNode := FindTaskByNumber (State^.FirstNode);
                ActiveChart^.Methods^.SetFirst (ActiveChart, FirstNode);
                CursorNode := FindTaskByNumber (State^.CursorNode);
                ActiveChart^.Methods^.SetCursorNode (ActiveChart, CursorNode);
        ELSE
            FatalError();
        END;
    END;

        (*  This mess with the chartstate was put in so that extraneous
            refiltering, etc. was not caused by the saved chart state being
            restored, when the states were "really" the same.  I figure 
            that a difference in the Showing bit isn't important.
        *)

    Mask := AChartStateSet{Scheduled,Sorted,Filtered,Formatted};              (* 16-Jul-91 *)

    IF ((ChartState * Mask) <> (State^.BeforeChartState * Mask)) THEN
        ChartState := ChartState * State^.BeforeChartState;
        IF (Scheduled IN ChartState) THEN
            SetState (Scheduled);
            CalculationState[Scheduling].DataIsValid := TRUE;   (* 26-Jun-91 RSC *)
        ELSE
            UnSetState (Scheduled);
        END;
    ELSE
        UnSetState( Showing );                                 (* 16-Jul-91 *)
    END;

END RestoreState;







PROCEDURE UndoTransaction (VAR Node     : ATreeNode);
VAR
    Transaction         : ATransactionRecordPointer;
    TaskToDelete        : ATreeNode;
    EdgeToDelete        : AnEdgePtr;
    TaskToAdd           : ATreeNode;
    EdgeToAdd           : AnEdgePtr;
    ParentTask          : ATreeNode;
    PriorTask           : ATreeNode;
    FirstTask           : ATreeNode;
    SecondTask          : ATreeNode;
    OldTask             : ATreeNode;
    NewTask             : ATreeNode;
    ResourceToDelete    : ATreeNode;
    NextResource        : ATreeNode;
    ResourceToAdd       : ATreeNode;
    NewResource         : ATreeNode;
    OldResource         : ATreeNode;
    PrevResource        : ATreeNode;
    Attributes          : CARDINAL;
    NewNode             : ATreeNode;
    TaskPtr             : ATaskPtr;
    ResourcePtr         : AResourcePointer;
    s                   : ARRAY [0..255] OF CHAR;


BEGIN
    Transaction := Node^.Methods^.GetDataObject (Node);
    INCL (Transaction^.TransactionFlags, TUndone);

    GetMessage (ModuleNumber+1, s);     (* "OK, I have " *)
    ConcatMessage (s, ModuleNumber+1+ORD(Transaction^.Action));
    ConcatMessage (s, ModuleNumber+10+ORD(Transaction^.Type));

    CASE Transaction^.Action OF

        Add :
           CASE Transaction^.Type OF

                Task :
                    TaskToDelete := FindTaskByNumber (Transaction^.NodeID);
                    CheckTaskValid (TaskToDelete);
                    AddTaskName (s, TaskToDelete);
                    RemoveTask (TaskToDelete);
            |   Edge :
                    FirstTask := FindTaskByNumber (Transaction^.AnteID);
                    AddTaskName (s, FirstTask);
                    ConcatMessage (s, ModuleNumber+13);     (* "ÄÄ" *)
                    SecondTask := FindTaskByNumber (Transaction^.DescID);
                    AddTaskName (s, SecondTask);
                    EdgeToDelete := FindEdge (FirstTask, SecondTask);
                    IF (EdgeToDelete <> NIL) THEN           (* 9/27/89 EGK *)
                        CheckEdgeValid (EdgeToDelete);
                        SendNotices (DeleteAnEdge, BeforeActing, EdgeToDelete);     (* 6/5/89 EGK *)
                        RemoveEdge (EdgeToDelete);
                    END;

            |   Resource :
                    ResourceToDelete := FindResourceByNumber (Transaction^.NodeID);
                    AddResourceName (s, ResourceToDelete);
                    RemoveResource (ResourceToDelete);

            ELSE
                FatalError();
            END;

    |   Delete :
            IF (TError IN Transaction^.TransactionFlags) THEN
                RETURN;
            END;
            CASE Transaction^.Type OF

                Task :
                    TaskToAdd := Transaction^.DataObject;
                    AddTaskName (s, TaskToAdd);
                    ParentTask := FindTaskByNumber (Transaction^.ParentID);
                    PriorTask := FindTaskByNumber (Transaction^.PrevID);
                    CheckTaskValid (TaskToAdd);
                    DecodeTaskAssignments (TaskToAdd);
                    AddTask (TaskToAdd, ParentTask, PriorTask);

            |   Edge :
                    EdgeToAdd := Transaction^.DataObject;
                    EdgeToAdd^.headtask := FindTaskByNumber (Transaction^.AnteID);
                    EdgeToAdd^.tailtask := FindTaskByNumber (Transaction^.DescID);
                    CheckEdgeValid (EdgeToAdd);
                    IF (Undoing) THEN
                        WITH EdgeToAdd^ DO
                            AddTaskName (s, headtask);
                            ConcatMessage (s, ModuleNumber+13);
                            AddTaskName (s, tailtask);
                            headtask^.Methods^.SetVisible (headtask, TRUE);
                            tailtask^.Methods^.SetVisible (tailtask, TRUE);
                        END;
                    END;
                    AddEdge (EdgeToAdd, TRUE);
                    SendNotices (AddAnEdge, AfterActing, EdgeToAdd);    (* 6/5/89 EGK *)

            |   Resource :
                    ResourceToAdd := Transaction^.DataObject;
                    PrevResource := FindResourceByNumber (Transaction^.PrevID);
                    AddResourceName (s, ResourceToAdd);
                    AddResource (ResourceToAdd, NIL, PrevResource);
            ELSE
                FatalError();
            END;

    |   Change :
            IF (TError IN Transaction^.TransactionFlags) THEN
                RETURN;
            END;
            CASE Transaction^.Type OF
                Task :
                    OldTask := Transaction^.DataObject;
                    NewTask := FindTaskByNumber (Transaction^.NodeID);
                    AddTaskName (s, NewTask);
                    SendNotices (ChangeATask, BeforeActing, NewTask);
                    DecodeTaskAssignments (OldTask);
                    CopyTask (OldTask, NewTask);
            |   Edge :
                    EdgeToAdd := Transaction^.DataObject;
                    EdgeToAdd^.headtask := FindTaskByNumber (Transaction^.AnteID);
                    EdgeToAdd^.tailtask := FindTaskByNumber (Transaction^.DescID);
                    AddTaskName (s, EdgeToAdd^.headtask);
                    ConcatMessage (s, ModuleNumber+13);
                    AddTaskName (s, EdgeToAdd^.tailtask);
                    EdgeToDelete := FindEdge (EdgeToAdd^.headtask, EdgeToAdd^.tailtask);
                    IF (EdgeToDelete <> NIL) THEN       (* 9/27/89 EGK *)
                        CheckEdgeValid (EdgeToDelete);
                        SendNotices (ChangeAnEdge, BeforeActing, EdgeToDelete);
                        CopyEdgeContents (EdgeToAdd^, EdgeToDelete^);   (* 1/16/90 EGK *)
                    END;
            |   Resource :
                    OldResource := Transaction^.DataObject;
                    AddResourceName (s, OldResource);
                    NewResource := FindResourceByNumber (Transaction^.NodeID);
                    SendNotices (ChangeAResource, BeforeActing, NewResource);
                    CopyResourceNode (OldResource, NewResource, TRUE);
                    ChangedResource (NewResource);
            ELSE
                FatalError();
            END;

    |   Move :
            CASE Transaction^.Type OF
                Task :
                    TaskToAdd := FindTaskByNumber(Transaction^.NodeID);
                    AddTaskName (s, TaskToAdd);
                    ParentTask := FindTaskByNumber (Transaction^.ParentID);
                    PriorTask := FindTaskByNumber (Transaction^.PrevID);
                    SendNotices (MoveATask, BeforeActing, TaskToAdd);
                    TaskToAdd^.Methods^.DeList (TaskToAdd);
                    IF (PriorTask <> NIL) THEN
                        PriorTask^.Methods^.AddAfter (PriorTask, TaskToAdd);
                    ELSIF (ParentTask <> NIL) THEN
                        ParentTask^.Methods^.AddAsFirstChild (ParentTask, TaskToAdd);
                    ELSE
                        TaskTree^.Methods^.AddFirst (TaskTree, TaskToAdd);
                    END;
            ELSE
                FatalError();
            END;

    |   Open, Close :
            IF (TError IN Transaction^.TransactionFlags) THEN
                RETURN;
            END;
            CASE Transaction^.Type OF
                Task :
                    OldTask := Transaction^.DataObject;
                    NewTask := FindTaskByNumber (Transaction^.NodeID);
                    AddTaskName (s, NewTask);
                    IF (Transaction^.Action = Open) THEN
                        SendNotices (CloseATask, BeforeActing, NewTask);
                    ELSE
                        SendNotices (OpenATask, BeforeActing, NewTask);
                    END;
                    Attributes := OldTask^.Methods^.GetAttributes (OldTask);
                    NewTask^.Methods^.SetAttributes (NewTask, Attributes);
            ELSE
                FatalError();
            END;

    ELSE
        FatalError();
    END;

    ConcatMessage (s, ModuleNumber+14);     (* "'." *)
    IF (Undoing) THEN
        Message (s);
    END;

    DiscardTransaction (Node, NIL);

END UndoTransaction;


                    


PROCEDURE UndoTransactionSet (VAR Node       : ATreeNode;
                         VAR ActiveChartType : AnUndoableObject;
                         VAR ActiveChart     : AnOutlineView ) : BOOLEAN;
VAR
    TransactionNode         : ATreeNode;
    PrevNode                : ATreeNode;
    Status                  : AStateRecordPointer;
    s                       : ARRAY [0..99] OF CHAR;

BEGIN

    IF (Node = NIL) THEN
        RETURN FALSE;
    END;

    IF (UndoStatus <> Aborted) THEN (* 26-Jun-91 RSC  *)
        Undoing := TRUE;
    END;

    Status := Node^.Methods^.GetDataObject (Node);

    IF (Status^.ActiveChartType <> ActiveChartType) AND
       (ActiveChartType <> Task) THEN
        GetMessage (ModuleNumber+20, s);
        Error (s);
        Undoing  := FALSE;
        RETURN FALSE;
    END;

(*    BeginTransactionSet();*)
    IF (UndoStatus <> Aborted) AND (* 26-Jun-91 RSC  *)
       (CreateTransactionSet(ActiveChartType, ActiveChart)) THEN    (* 21-Jun-91 RSC simplify *)
        UndoStatus := Active;
    END;

    TransactionNode := Node^.Methods^.LastChild (Node);
    WHILE (TransactionNode <> NIL) DO
        PrevNode := TransactionNode^.Methods^.GetPrev (TransactionNode);
        UndoTransaction (TransactionNode);
        TransactionNode := PrevNode;
    END;

    IF (Status^.ActiveChartType = ActiveChartType) THEN
        RestoreState (Status, ActiveChartType, ActiveChart );
    END;

    IF (UndoStatus <> Aborted) THEN

        (*  If this was a legitimate undo, we need to restore the chart state
            after (not before) the transaction set.  Otherwise we might not
            do the necessary re-calc, re-sort, re-format, etc.      *)

        ChartState := ChartState * Status^.AfterChartState;
    END;

    DiscardTransactionSet (Node);

    EndTransactionSet(ActiveChartType, ActiveChart);

    Undoing  := FALSE;

    RETURN TRUE;

END UndoTransactionSet;









PROCEDURE TopLevelCount (Tree : ATree) : CARDINAL;
VAR
    Node        : ATreeNode;
    Count       : CARDINAL;
BEGIN
    Count := 0;
    Node := Tree^.Methods^.GetFirst (Tree);
    WHILE (Node <> NIL) DO
        INC (Count);
        Node := Node^.Methods^.GetNext (Node);
    END;
    RETURN Count;
END TopLevelCount;









PROCEDURE RemoveOldTransactions (Tree : ATree);

VAR
    UndoLimit       : CARDINAL;
    UndoCount       : CARDINAL;
    Node            : ATreeNode;

BEGIN
    UndoLimit := GetUndoLimit();
    UndoCount := TopLevelCount (Tree);
    LOOP
        Node := Tree^.Methods^.GetFirst (Tree);
        IF (Node = NIL) OR (TransactionSetOpen (Node)) OR (UndoCount = 0) THEN
            EXIT;
        END;
        IF (UndoCount <= UndoLimit) AND (HeapAvailable()) THEN
            EXIT;
        END;
        DiscardTransactionSet (Node);
        DEC (UndoCount);
    END;
END RemoveOldTransactions;





PROCEDURE EmptyTransactionSet (Node     : ATreeNode ) : BOOLEAN;
BEGIN
    RETURN (Node^.Methods^.FirstChild (Node) = NIL);
END EmptyTransactionSet;



PROCEDURE BadTransactionSet ( Node      : ATreeNode ) : BOOLEAN;
VAR
    Status              : AStateRecordPointer;
BEGIN
    Status := Node^.Methods^.GetDataObject (Node);
    RETURN (Status^.TSError);
END BadTransactionSet;







PROCEDURE EndTransactionSet( VAR ActiveChartType : AnUndoableObject;
                             VAR ActiveChart     : AnOutlineView );
VAR
    Node            : ATreeNode;
    Status          : AStateRecordPointer;
BEGIN
(*
    IF (UndoStatus <> Active) THEN
        RETURN;
    END;
*)
    Node := LastOpenTransactionSet (UndoTree);
    IF (Node = NIL) THEN
        RETURN;
    END;

    IF (EmptyTransactionSet (Node)) OR (BadTransactionSet (Node)) THEN
        DiscardTransactionSet (Node);       (* Why save an empty one? *)
    ELSE

        Status := Node^.Methods^.GetDataObject (Node);
        IF (Status^.ActiveChartType <> ActiveChartType) THEN
            RETURN;
        END;
        Status^.AfterChartState := ChartState;
        Status^.Open := FALSE;

        (*  Move this transaction set to the end so it will be the first one
            undone.  This is necessary in case of multiple open transaction
            sets (e.g. making resource changes from the task form).     *)

        Node^.Methods^.DeList (Node);
        UndoTree^.Methods^.AddLast (UndoTree, Node);

        (*  Make sure that recording of this transaction set did not push us
            over the limit.  If so, we'll need to trim the list.        *)

        RemoveOldTransactions (UndoTree);

        IF (NOT Undoing) THEN

        (*  Now erase any pending redos *)

            RedoTree^.Methods^.TraverseTree (RedoTree, ParentAfterChild, 9999,
                    DiscardTransaction, NIL);
        END;

    END;

    UndoStatus := Inactive;
END EndTransactionSet;









PROCEDURE SaveState(     State           : AStateRecordPointer;
                     VAR ActiveChartType : AnUndoableObject;
                     VAR ActiveChart     : AnOutlineView );
BEGIN
        (* 26-Jun-91 RSC *)
    IF ((Scheduled IN ChartState) AND                          (* 16-Jul-91 *)
        (NOT CalculationState[Scheduling].DataIsValid)) THEN
        UnSetState (Scheduled);
    END;
    State^.ActiveChartType := ActiveChartType;
    State^.BeforeChartState := ChartState;              (* 9/27/89 EGK *)

    CASE ActiveChartType OF
        Task :
            State^.BugA := GetTaskID (BugTaskA);
            State^.BugB := GetTaskID (BugTaskB);
            State^.FirstNode := GetTaskID (ActiveChart^.Methods^.GetFirst (ActiveChart));
            State^.CursorNode := GetTaskID (ActiveChart^.Methods^.GetCursorNode (ActiveChart));
    |   Resource :
            State^.FirstNode := GetRsrcID (ActiveChart^.Methods^.GetFirst (ActiveChart));
            State^.CursorNode := GetRsrcID (ActiveChart^.Methods^.GetCursorNode (ActiveChart));
    |   Edge :
            State^.FirstNode := GetTaskID (ActiveChart^.Methods^.GetFirst (ActiveChart));
            State^.CursorNode := GetTaskID (ActiveChart^.Methods^.GetCursorNode (ActiveChart));
    ELSE
        FatalError();
    END;
END SaveState;







PROCEDURE CreateTransactionSet(
                     VAR ActiveChartType : AnUndoableObject;
                     VAR ActiveChart     : AnOutlineView ) : BOOLEAN;
VAR
    Status              : AStateRecordPointer;
    Node                : ATreeNode;
BEGIN
    IF (NOT Available(MinSpace)) THEN
        RETURN FALSE;
    END;
    NEW (Status);
    IF (NOT CreateTreeNode (Node)) THEN
        DISPOSE (Status);
        RETURN FALSE;
    END;
    Node^.Methods^.SetDataObject (Node, Status);
    UndoTree^.Methods^.AddLast (UndoTree, Node);
    Status^.Open := TRUE;
    Status^.TSError := FALSE;
    SaveState(Status, ActiveChartType, ActiveChart);

    RETURN TRUE;

END CreateTransactionSet;







PROCEDURE DoTLUndo;
TYPE
    AnOperation   = (OUndo, OFlush, ORemoveOld, ONotify,
                     OEndTransaction, OCreate);
    AnUndoContext = RECORD      (* KEEP IN SYNCH WITH UNDO *)
        Node        : ATreeNode;
        UndoObject  : AnUndoableObject;
        UndoAction  : AnUndoAction;
        Result      : BOOLEAN;
        Operation   : AnOperation;
        ActiveChartType : AnUndoableObject;
        ActiveChart     : AnOutlineView;
    END;
VAR
    Node            : ATreeNode;
    Context         : POINTER TO AnUndoContext;
BEGIN
    Context := OverlayContext();

    WITH Context^ DO

        Result := TRUE; (* Assume success *)

        CASE Operation OF
          OUndo:

            Result := UndoTransactionSet (Node, ActiveChartType, ActiveChart);

        | OFlush:

            UndoTree^.Methods^.TraverseTree(UndoTree, ParentAfterChild, 9999,
                                            DiscardTransaction, NIL);
            RedoTree^.Methods^.TraverseTree(RedoTree, ParentAfterChild, 9999,
                                            DiscardTransaction, NIL);
            UndoStatus := Inactive;

        | ORemoveOld:

            RemoveOldTransactions(UndoTree);

        | ONotify:

            NotifyUndo( UndoObject, UndoAction, ADDRESS(Node), ActiveChartType, ActiveChart );

        | OEndTransaction:

            EndTransactionSet(ActiveChartType, ActiveChart);

        | OCreate:

            Result := CreateTransactionSet(ActiveChartType, ActiveChart);

        ELSE
            FatalError();
        END;
    END;

END DoTLUndo;


BEGIN
    Undoing := FALSE;

    OverlayID := ImAnInstallableOverlay( DoTLUndo, AnOverlayProc(NIL) );
    DoTLUndo();

END TLUndo.

