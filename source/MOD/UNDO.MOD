(*V1=OS2 OS2 code changes.    *)
(*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE Undo;

    (*  MODIFICATION HISTORY --

        25-Nov-87 LAA   Added SendNotices calls to NotifyUndo to help 
                        interface the network view.
        12-Jan-88 RSC   "Unchanged" changes.
        24-Feb-88 EGK   Changed all notice contexts to NIL.
        10-Jan-89 RSC   Changed Storage to Space    .
        26-Apr-89 EGK   Added TSError field to the transaction set record.
                        Now, if we run out of memory in the middle of
                        recording a set, EndTransactionSet will just throw
                        the whole set away (it's all or nothing).
        14-May-89 AJL   Remove import of AlarmOn. 
         5-Jun-89 EGK   In UndoTransaction, changed NotifyUndo calls to
                        SendNotice calls.  Removed SendNotice calls from
                        NotifyUndo.  Added NoticeCatcher to get new notices
                        and call NotifyUndo itself as appropriate.
         6-Jun-89 EGK   Added InitUndo procedure.
         6-Aug-89 WKH   Initial OS/2 edits.  Assign "safe value" to a ptr seg.
        11-Aug-89 EGK   Removed obsolete "OppositeType" procedure.
        27-Sep-89 EGK   Fixed setting of BeforeChartState so that it is
                        properly initialized for edge and resource
                        transactions.  Put checks in to handle cases where
                        FindEdge would return a NIL.
        16-Jan-90 EGK   To replace an existing edge with a saved copy (to
                        undo an edge change), UndoTransaction was simply
                        assigning one record to the other.  This was
                        occasionally setting the headlink and taillink fields
                        of the target back to invalid values.  Now I just use
                        CopyEdgeContents, leaving all the links as they were.
        21-Jun-91 RSC   Moved some code to the new overlay, TLUNDO.  This
                        will shrink the root memory requirements.
        27-Jun-91 RSC   Made ActuveChartState and ActiveChart variables passed
                        to the overlay, so that they are preserved across
                        invocations.
         3-Sep-91 EGK   Moved some of the up-front checking that NotifyUndo
                        does before actually calling the TLUndo overlay.
                        Those checks probably shouldn't have been moved over
                        when the TLUndo overlay was created.  This keeps us
                        from calling the overlay unless we're actually
                        recording a transaction.
    *)

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartStateSet;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Burp;

FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  RegisterForNotices;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineView;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, ADR;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
    (* PROC *)                  CreateTree, CreateTreeNode;




TYPE
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
    UndoLimit       : CARDINAL;

    ActiveChartType : AnUndoableObject;
    ActiveChart     : AnOutlineView;






        (* 20-Jun-91 RSC communicate with the TLUNDO overlay.
        *)
TYPE
    AnOperation   = (OUndo, OFlush, ORemoveOld, ONotify,
                     OEndTransaction, OCreate);



PROCEDURE CallTLUndo( O             : AnOperation;
                      Node          : ATreeNode;
                      UndoObject    : AnUndoableObject;
                      UndoAction    : AnUndoAction  ) : BOOLEAN;
TYPE
    AnUndoContext = RECORD      (* KEEP IN SYNCH WITH TLUNDO *)
        Node        : ATreeNode;
        UndoObject  : AnUndoableObject;
        UndoAction  : AnUndoAction;
        Result      : BOOLEAN;
        Operation   : AnOperation;
        ActiveChartType : AnUndoableObject;
        ActiveChart     : AnOutlineView;
    END;
VAR
    Context         : AnUndoContext;
    Result          : BOOLEAN;
    s               : ARRAY [0..9] OF CHAR;
BEGIN
    SetString( s, "TLUNDO" );
    Context.Operation := O;
    Context.UndoObject:= UndoObject;
    Context.UndoAction:= UndoAction;
    Context.Node      := Node;
    Context.Result    := FALSE; (* Assume failure, in case he doesn't run *)
    Context.ActiveChart := ActiveChart; (* 26-Jun-91 RSC load em *)
    Context.ActiveChartType := ActiveChartType;

    Result          := CallOverlayWithContext( s, ADR( Context ) ) AND
                       Context.Result;

    ActiveChart     := Context.ActiveChart;    (* 26-Jun-91 RSC save em *)
    ActiveChartType := Context.ActiveChartType;

    RETURN Result;

END CallTLUndo;



PROCEDURE GetUndoLimit () : CARDINAL;
BEGIN
    RETURN UndoLimit;
END GetUndoLimit;


PROCEDURE SetUndoLimit (Limit : CARDINAL);
VAR
    ok  : BOOLEAN;
BEGIN

    UndoLimit := Limit;
    ok := CallTLUndo( ORemoveOld, ATreeNode( NIL ), Task, None );

END SetUndoLimit;




PROCEDURE BeginTransactionSet();
BEGIN
    IF (UndoStatus = Aborted) THEN
        RETURN;
    END;

    IF (NOT CallTLUndo( OCreate, ATreeNode(NIL), Task, None )) THEN
        RETURN;
    END;
    UndoStatus := Active;
END BeginTransactionSet;




PROCEDURE EndTransactionSet();
VAR
    Node            : ATreeNode;
    ok              : BOOLEAN;
BEGIN
    Node := LastOpenTransactionSet (UndoTree);
    IF (Node = NIL) THEN
        RETURN;
    END;

    ok := CallTLUndo( OEndTransaction, Node, Task, None );

END EndTransactionSet;







PROCEDURE AbortTransactionSet();
VAR
    Node        : ATreeNode;
BEGIN

    (*  Actually, this works just like a regular undo.  The UndoStatus of
        Aborted just tells us not to do certain things (like recording a new
        transaction set for redo).          *)

    UndoStatus := Aborted;
    Node := LastOpenTransactionSet (UndoTree);
    IF (Node = NIL) OR (NOT UndoTransactionSet (Node)) THEN
        FatalError();
    END;
    UndoStatus := Inactive;
END AbortTransactionSet;




PROCEDURE NotifyUndo    (   UndoObject      : AnUndoableObject;
                            UndoAction      : AnUndoAction;
                            DataObject      : ADDRESS           );
VAR
    ok  : BOOLEAN;
BEGIN

        (* Put these checks in -- EGK 9/3/91 *)

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

    ok := CallTLUndo( ONotify, ATreeNode(DataObject), UndoObject, UndoAction );
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







PROCEDURE UndoTransactionSet (VAR Node      : ATreeNode) : BOOLEAN;
BEGIN

    RETURN CallTLUndo( OUndo, Node, Task, None );

END UndoTransactionSet;








PROCEDURE UndoLastChange (Redo : BOOLEAN) : BOOLEAN;
VAR
    Tree1, Tree2    : ATree;
    Node            : ATreeNode;
    Result          : BOOLEAN;
BEGIN

    Tree1 := UndoTree;
    Tree2 := RedoTree;


    IF (NOT Redo) THEN
        RedoTree := Tree1;
        UndoTree := Tree2;
    END;

    Node     := RedoTree^.Methods^.GetLast (RedoTree);
    Result   := UndoTransactionSet (Node);

    UndoTree := Tree1;
    RedoTree := Tree2;

    RETURN Result;        

END UndoLastChange;





PROCEDURE FlushUndos();
VAR
    ok  : BOOLEAN;
BEGIN

    ok := CallTLUndo( OFlush, ATreeNode(NIL), Task, None );

END FlushUndos;







PROCEDURE DebugUndo();
BEGIN
    Burp();
END DebugUndo;




PROCEDURE NoticeCatcher (   Occasion    : AnOccasion;
                            Step        : AStep;
                            Context     : ADDRESS    ) : BOOLEAN;
VAR
    UndoObject          : AnUndoableObject;
    UndoAction          : AnUndoAction;

BEGIN
    CASE Occasion OF
        AddATask..CloseATask :
            UndoObject := Task;
    |   AddAResource..ChangeAResource :
            UndoObject := Resource;
    |   AddAnEdge..ChangeAnEdge :
            UndoObject := Edge;
    ELSE
    END;

    CASE Occasion OF
        AddATask, AddAResource, AddAnEdge :
            UndoAction := Add;
    |   DeleteATask, DeleteAResource, DeleteAnEdge :
            UndoAction := Delete;
    |   ChangeATask, ChangeAResource, ChangeAnEdge :
            UndoAction := Change;
    |   MoveATask :
            UndoAction := Move;
    |   OpenATask :
            UndoAction := Open;
    |   CloseATask :
            UndoAction := Close;
    ELSE
        UndoAction := None;
    END;

    IF (UndoAction <> None) AND (Step <> RequestPermission) THEN
        NotifyUndo (UndoObject, UndoAction, Context);
    END;

    RETURN TRUE;
END NoticeCatcher;


PROCEDURE InitUndo();
BEGIN
    UndoLimit  := 50;
    UndoStatus := Inactive;
    IF (NOT CreateTree (UndoTree)) OR
       (NOT CreateTree (RedoTree)) THEN
        FatalError();
    END;

    RegisterForNotices (AllOccasions, NoticeCatcher);   (* 6/5/89 EGK *)

END InitUndo;


END Undo.
