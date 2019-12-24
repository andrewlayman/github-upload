(*V9=DEBUGGING Code*)

IMPLEMENTATION MODULE LinkedListObjects;        (* A subclass of Objects *)

    (*  MODIFICATION HISTORY
        01-Dec-87 LAA   Minor changes for low memory behavior.
        23-Jan-89 RSC   Changed Storage to Space    .
    *)

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject,
    (* PROC *)                  CloneObjectMethods, ValidateObject,
                                InitAsObject, UnInitAsObject;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR  *)                  AnxietyLevel;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, BYTE,
    (* PROC *)                  ADR, TSIZE;


CONST
    ModuleNumber = 14900;


TYPE
        (*  XLinkedList is a subclass of Objects.AnObject  *)

    XLinkedList             = POINTER TO XLinkedListRecord;



        (*  XLinkedListNode is a subclass of Objects.AnObject  *)

    XLinkedListNode         = POINTER TO XLinkedListNodeRecord;






TYPE

        (*  This defines the data fields which exist for every object of 
            type XLinkedList.  Any subclasses of ListObjects must implement 
            at least this much.
        *)



    XLinkedListRecord       = RECORD
                                Methods     : ALinkedListMethods;
                                Header      : XLinkedListNode;
                              END;




        (*  These are the data fields of XLinkedListNode.  The DataObject 
            can't be more specifically defined here, because we don't know 
            what it's a list of.  Subclasses may specify a specific data 
            object.
        *)

    XLinkedListNodeRecord   = RECORD
                                Methods     : ALinkedListNodeMethods;
                                HeaderFlag  : BOOLEAN;
                                Filler      : BYTE;
                                Next        : XLinkedListNode;
                                Prev        : XLinkedListNode;
                                DataObject  : ADDRESS;
                              END;



    (*  A procedure of this type is passed to XListForAllProc procedures.  *)

TYPE
    XListNodeProcessingProc = PROCEDURE(VAR XLinkedListNode,
                                            ADDRESS        );






VAR
    LinkedListMethodsRecord     : ALinkedListMethodsRecord;
    LinkedListNodeMethodsRecord : ALinkedListNodeMethodsRecord;





PROCEDURE NodeClone (Node1: XLinkedListNode;
                 VAR Node2: XLinkedListNode): BOOLEAN;
VAR
    PrivateNode: ALinkedListNode;

BEGIN                   (* NodeClone *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (ALinkedListNode (Node1));
    END;
    DEBUGGING>*)

    IF NOT CreateLinkedListNode (PrivateNode) THEN
        RETURN FALSE;
    END;
    Node2 := XLinkedListNode (PrivateNode);
    Node2^.DataObject := Node1^.DataObject;
    RETURN TRUE;
END NodeClone;





PROCEDURE NodeStoreOn ( Node: XLinkedListNode;
                        File: AnObject;
               VAR Exception: BOOLEAN);

BEGIN                   (* NodeStoreOn *)

    FatalError;
END NodeStoreOn;






PROCEDURE NodeDiscard (VAR Node: XLinkedListNode);

BEGIN                   (* NodeDiscard *)

    ValidateLinkedListNode (ALinkedListNode (Node));
    UnInitAsLinkedListNode (ALinkedListNode (Node));
    DISPOSE (Node);

END NodeDiscard;






PROCEDURE GetNextNode (Node: XLinkedListNode): XLinkedListNode;

BEGIN                   (* GetNextNode *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (ALinkedListNode (Node));
    END;
    DEBUGGING>*)

    IF (Node^.Next^.HeaderFlag) THEN
        RETURN NIL;
    ELSE
        RETURN Node^.Next;
    END;
END GetNextNode;






PROCEDURE GetPrevNode (Node: XLinkedListNode): XLinkedListNode;

BEGIN                   (* GetPrevNode *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (ALinkedListNode (Node));
    END;
    DEBUGGING>*)
    IF (Node^.Prev^.HeaderFlag) THEN
        RETURN NIL;
    ELSE
        RETURN Node^.Prev;
    END;
END GetPrevNode;






PROCEDURE AddBeforeNode (TargetNode, NewNode: XLinkedListNode);

BEGIN                   (* AddBeforeNode *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (ALinkedListNode (TargetNode));
        ValidateLinkedListNode (ALinkedListNode (NewNode));
    END;
    DEBUGGING>*)

    TargetNode^.Prev^.Next := NewNode;
    NewNode^.Prev := TargetNode^.Prev;
    TargetNode^.Prev := NewNode;
    NewNode^.Next := TargetNode;
END AddBeforeNode;





PROCEDURE AddAfterNode (TargetNode, NewNode: XLinkedListNode);

BEGIN                   (* AddAfterNode *)

    AddBeforeNode (TargetNode^.Next, NewNode);
END AddAfterNode;





PROCEDURE DeListNode (Node: XLinkedListNode);

BEGIN               (* DeListNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (ALinkedListNode (Node));
    END;
    DEBUGGING>*)

    WITH Node^ DO
        Prev^.Next := Next;
        Next^.Prev := Prev;
        Prev := Node;
        Next := Node;
    END;
END DeListNode;




PROCEDURE SetNodeDataObject (Node: XLinkedListNode; Data: ADDRESS);

BEGIN                   (* SetNodeDataObject *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (ALinkedListNode (Node));
    END;
    DEBUGGING>*)

    Node^.DataObject := Data;
END SetNodeDataObject;




PROCEDURE GetNodeDataObject (Node: XLinkedListNode): ADDRESS;

BEGIN                   (* GetNodeDataObject *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (ALinkedListNode (Node));
    END;
    DEBUGGING>*)

    RETURN Node^.DataObject;
END GetNodeDataObject;





PROCEDURE GetNodeList (Node: XLinkedListNode): XLinkedList;
VAR
    CurrentNode: XLinkedListNode;

BEGIN                   (* GetNodeList *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (ALinkedListNode (Node));
        IF Node^.HeaderFlag THEN
            FatalError;
        END;
    END;
    DEBUGGING>*)

    IF (Node^.Next = Node) THEN
        RETURN NIL;
    ELSE
        CurrentNode := Node^.Next;
        WHILE NOT CurrentNode^.HeaderFlag DO
            CurrentNode := CurrentNode^.Next;
        END;
        RETURN CurrentNode^.DataObject;
    END;
END GetNodeList;





PROCEDURE GetFirstVisibleCoNode (Node: ALinkedListNode)
                                                       : ALinkedListNode;
VAR
    List: ALinkedList;

BEGIN               (* GetFirstVisibleCoNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (Node);
    END;
    DEBUGGING>*)

    List := Node^.Methods^.GetList (Node);
    IF (List = NIL) THEN
        RETURN Node;
    ELSE
        RETURN List^.Methods^.GetFirst (List);
    END;

END GetFirstVisibleCoNode;





PROCEDURE GetLastVisibleCoNode (Node: ALinkedListNode)
                                                       : ALinkedListNode;
VAR
    List: ALinkedList;

BEGIN               (* GetLastVisibleCoNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode (Node);
    END;
    DEBUGGING>*)

    List := Node^.Methods^.GetList (Node);
    IF (List = NIL) THEN
        RETURN Node;
    ELSE
        RETURN List^.Methods^.GetLast (List);
    END;

END GetLastVisibleCoNode;







PROCEDURE SetNodeVisible(    Node           : XLinkedListNode;
                             Visible        : BOOLEAN        );

BEGIN                       (* SetNodeVisible *)
END SetNodeVisible;





PROCEDURE NodeVisible(    Node              : XLinkedListNode)
                                                              : BOOLEAN;

BEGIN                       (* NodeVisible *)

    RETURN TRUE;

END NodeVisible;








(*----------------------------------------------------------------------------
    List routines begin here
*)






(*----------------------------------------------------------------------------
    ListClone, ListStoreOn, and ListDiscard are replacements for three of the
    original LinkedListMethods from Objects.
*)



PROCEDURE ListClone (List1: XLinkedList;
                 VAR List2: XLinkedList): BOOLEAN;

VAR
    CurrentNode: XLinkedListNode;
    PrivateList: ALinkedList;
    NewNode: ALinkedListNode;

BEGIN                   (* ListClone *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedList (ALinkedList (List1));
     END;
    DEBUGGING>*)

    IF NOT CreateLinkedList (PrivateList) THEN
        RETURN FALSE;
    END;

    CurrentNode := List1^.Header^.Next;
    WHILE NOT CurrentNode^.HeaderFlag DO
        IF NOT CurrentNode^.Methods^.Clone
                (ALinkedListNode (CurrentNode), NewNode) THEN
            PrivateList^.Methods^.Discard (PrivateList);
            RETURN FALSE;
        END;
        PrivateList^.Methods^.AddLast (PrivateList, NewNode);
        CurrentNode := CurrentNode^.Next;
    END;
    List2 := XLinkedList (PrivateList);
    RETURN TRUE;
END ListClone;





(*  ListStoreOn is not yet implemented, so we get a FatalError if we call it
    by mistake.     *)

PROCEDURE ListStoreOn (List: XLinkedList;
                       File: AnObject;
              VAR Exception: BOOLEAN);

BEGIN                   (* ListStoreOn *)
    FatalError;
END ListStoreOn;





PROCEDURE ListDiscard (VAR List: XLinkedList);

BEGIN                   (* ListDiscard *)

    ValidateLinkedList (ALinkedList (List));
    UnInitAsLinkedList (ALinkedList (List));
    DISPOSE (List);

END ListDiscard;





(*----------------------------------------------------------------------------
    AddFirstNode, AddLastNode, GetFirstNode, GetLastNode, and ForAllNodes
    are the Methods specific to Linked Lists.
*)



PROCEDURE AddFirstNode (List: XLinkedList;
                        Node: XLinkedListNode );

BEGIN                       (* AddFirstNode *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedList (ALinkedList (List));
        ValidateLinkedListNode (ALinkedListNode (Node));
    END;
    DEBUGGING>*)

    List^.Header^.Methods^.AddAfter (ALinkedListNode (List^.Header),
        ALinkedListNode (Node));
END AddFirstNode;





PROCEDURE AddLastNode ( List: XLinkedList;
                        Node: XLinkedListNode );

BEGIN                       (* AddLastNode *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedList (ALinkedList (List));
        ValidateLinkedListNode (ALinkedListNode (Node));
    END;
    DEBUGGING>*)

    List^.Header^.Methods^.AddBefore (ALinkedListNode (List^.Header),
        ALinkedListNode (Node));
END AddLastNode;





PROCEDURE GetFirstNode (List: XLinkedList): XLinkedListNode;

BEGIN                       (* GetFirstNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedList (ALinkedList (List));
    END;
    DEBUGGING>*)

    IF (List^.Header^.Next = List^.Header) THEN
        RETURN NIL;
    ELSE
        RETURN List^.Header^.Next;
    END;
END GetFirstNode;





PROCEDURE GetLastNode (List: XLinkedList): XLinkedListNode;

BEGIN                   (* GetLastNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedList (ALinkedList (List));
    END;
    DEBUGGING>*)

    IF (List^.Header^.Next = List^.Header) THEN
        RETURN NIL;
    ELSE
        RETURN List^.Header^.Prev;
    END;
END GetLastNode;






PROCEDURE ForAllNodes (List                 : XLinkedList;
                       NodeProcessingProc   : XListNodeProcessingProc;
                       Context              : ADDRESS);

VAR
    CurrentNode, NextNode: XLinkedListNode;

BEGIN                   (* ForAllNodes *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedList (ALinkedList (List));
    END;
    (*DEBUGGING>*)

    CurrentNode := List^.Header^.Next;
    WHILE NOT CurrentNode^.HeaderFlag DO
        NextNode := CurrentNode^.Next;
        NodeProcessingProc (CurrentNode, Context);
        CurrentNode := NextNode;
    END;

END ForAllNodes;






(*----------------------------------------------------------------------------
    InitAsLinkedListNode --

    Initialize the indicated storage location as an object of type 
    XLinkedListNode.

    Preconditions:
        None.

    Postconditions:
        The indicated object will be initialized as a list node object.  This 
        procedure does not allocate storage, it only initializes the area
        of memory referenced by the object provided.
----------------------------------------------------------------------------*)
PROCEDURE InitAsLinkedListNode (Node: ALinkedListNode);
VAR
    PrivateNode: XLinkedListNode;

BEGIN                   (* InitAsLinkedListNode *)

    InitAsObject (AnObject (Node));

    PrivateNode := XLinkedListNode (Node);
    PrivateNode^.Methods := ADR (LinkedListNodeMethodsRecord); (* Coercion happens here!!! *)
    PrivateNode^.HeaderFlag := FALSE;
    PrivateNode^.DataObject := NIL;
    PrivateNode^.Next := PrivateNode;
    PrivateNode^.Prev := PrivateNode;

END InitAsLinkedListNode;





(*----------------------------------------------------------------------------
    UnInitAsLinkedListNode --

    Un-Initialize the indicated storage location as an object of type 
    ALinkedListNode.

    Preconditions:
        The object must be a valid Linked List Node Object.

    Postconditions:
        The indicated object will no longer be initialized as a list node
        object.  Any side-effects of InitAsLinkedListNode will be undone.
        This procedure does not deallocate storage.
----------------------------------------------------------------------------*)
PROCEDURE UnInitAsLinkedListNode (Node: ALinkedListNode);
BEGIN
    Node^.Methods^.DeList (Node);
    UnInitAsObject (AnObject (Node));

END UnInitAsLinkedListNode;





(*----------------------------------------------------------------------------
    CreateLinkedListNode --

    Allocate storage off of the heap, and initialize it as an object of type
    XLinkedListNode.  This procedure should only be used to create objects
    which are not subclassed, or for which the subclassing does not add new
    data fields.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, a new object of type
        XLinkedListNode will be allocated, initialized, and TRUE will be 
        returned.
----------------------------------------------------------------------------*)
PROCEDURE CreateLinkedListNode (VAR Node: ALinkedListNode): BOOLEAN;

BEGIN                   (* CreateLinkedListNode *)

    IF (NOT Available(TSIZE(XLinkedListNodeRecord))) THEN         (* 01-Dec-87 LAA *)
        RETURN FALSE;
    END;
    ALLOCATE(Node, TSIZE(XLinkedListNodeRecord));
    InitAsLinkedListNode(Node);
    RETURN TRUE;
END CreateLinkedListNode;




(*----------------------------------------------------------------------------
    ValidateLinkedListNode --

    Validate the indicated storage location as an object of type 
    XLinkedListNode.

    Preconditions:
        None.

    Postconditions:
        If the indicated object is not a linked list node, or a subclass, 
        FatalError will be called.
----------------------------------------------------------------------------*)
PROCEDURE ValidateLinkedListNode (Node: ALinkedListNode);
VAR
    PrivateNode: XLinkedListNode;

BEGIN                   (* ValidateLinkedListNode *)

    (*<DEBUGGING
    IF (AnxietyLevel <> Calm) THEN
        ValidateObject (AnObject (Node));
    END;
    DEBUGGING>*)

    PrivateNode := XLinkedListNode (Node);

    IF (PrivateNode^.Methods^.ListNodeMethodsTag <> ModuleNumber + 1) THEN
        FatalError;
    END;
END ValidateLinkedListNode;




(*----------------------------------------------------------------------------
    CloneLinkedListNodeMethods --

    Make a copy of this class' methods into the indicated method object.

    Preconditions:
        None.

    Postconditions:
        The linked list node methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)
PROCEDURE CloneLinkedListNodeMethods (MethodObject: ALinkedListNodeMethods);

BEGIN                   (* CloneLinkedListNodeMethods *)

    MethodObject^ := LinkedListNodeMethodsRecord;
    MethodObject^.SuperclassMethods := ADR (LinkedListNodeMethodsRecord);
END CloneLinkedListNodeMethods;





(*----------------------------------------------------------------------------
    InitAsLinkedList --

    Initialize the indicated storage location as an object of type 
    XLinkedList.

    Preconditions:
        None.

    Postconditions:
        The indicated object will be initialized as a list object.  This 
        procedure does not allocate storage, it only initializes the area
        of memory referenced by the object provided.
----------------------------------------------------------------------------*)
PROCEDURE InitAsLinkedList (List: ALinkedList);
VAR
    PrivateList: XLinkedList;

BEGIN                   (* InitAsLinkedList *)

    InitAsObject (AnObject (List));

    PrivateList := XLinkedList (List);

    WITH PrivateList^ DO
        Methods := ADR (LinkedListMethodsRecord); (* Coercion happens here !!!*)
        NEW (Header);
        InitAsLinkedListNode (ALinkedListNode (Header));
        Header^.HeaderFlag := TRUE;
        Header^.DataObject := List;
    END;

END InitAsLinkedList;




(*----------------------------------------------------------------------------
    UnInitAsLinkedList --

    Un-Initialize the indicated storage location as an object of type 
    ALinkedList.

    Preconditions:
        The object must be a valid Linked List Object.

    Postconditions:
        The indicated object will no longer be initialized as a list object.
        Any side-effects of InitAsLinkedList will be undone.  This 
        procedure does not deallocate storage.
----------------------------------------------------------------------------*)
PROCEDURE UnInitAsLinkedList (List: ALinkedList);
VAR
    PrivateList: XLinkedList;

BEGIN

    List^.Methods^.ForAll (List, DiscardAnyNode, NIL);

    PrivateList := XLinkedList (List);

    UnInitAsLinkedListNode (ALinkedListNode (PrivateList^.Header));
    DISPOSE (PrivateList^.Header);

    UnInitAsObject (AnObject (List));

END UnInitAsLinkedList;


(*  DiscardAnyNode is used in UnInitAsLinkedList simply to pass the correct
    Discard procedure to each node referred to in ForAll.           *)

PROCEDURE DiscardAnyNode (VAR Node: ALinkedListNode;
                              Context       : ADDRESS);

BEGIN
    Node^.Methods^.Discard (Node);
END DiscardAnyNode;





(*----------------------------------------------------------------------------
    CreateLinkedList --

    Allocate storage off of the heap, and initialize it as an object of type
    XLinkedList.  This procedure should only be used to create objects
    which are not subclassed, or for which the subclassing does not add new
    data fields.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, a new object of type
        XLinkedList will be allocated, initialized, and TRUE will be returned.
----------------------------------------------------------------------------*)
PROCEDURE CreateLinkedList (VAR List: ALinkedList): BOOLEAN;

BEGIN                   (* CreateLinkedList *)

    IF (NOT Available(TSIZE(XLinkedListRecord))) THEN             (* 01-Dec-87 LAA *)
        RETURN FALSE;
    END;
    ALLOCATE(List, TSIZE(XLinkedListRecord));
    InitAsLinkedList(List);
    RETURN TRUE;
END CreateLinkedList;




(*----------------------------------------------------------------------------
    ValidateLinkedList --

    Validate the indicated storage location as an object of type 
    XLinkedList.

    Preconditions:
        None.

    Postconditions:
        If the indicated object is not a linked list, or a subclass, 
        FatalError will be called.
----------------------------------------------------------------------------*)
PROCEDURE ValidateLinkedList (List: ALinkedList);
VAR
    PrivateList: XLinkedList;

BEGIN                   (* ValidateLinkedList *)
    (*<DEBUGGING
    IF (AnxietyLevel <> Calm) THEN
        ValidateObject (AnObject (List));
    END;
    DEBUGGING>*)

    PrivateList := XLinkedList (List);
    IF (PrivateList^.Methods^.ListMethodsTag <> ModuleNumber) THEN
        FatalError;
    END;
END ValidateLinkedList;




(*----------------------------------------------------------------------------
    CloneLinkedListMethods --

    Make a copy of this class' methods into the indicated method object.

    Preconditions:
        None.

    Postconditions:
        The linked list methods will be copied into the indicated method object.
----------------------------------------------------------------------------*)
PROCEDURE CloneLinkedListMethods (MethodObject: ALinkedListMethods);

BEGIN                   (* CloneLinkedListMethods *)

    MethodObject^ := LinkedListMethodsRecord;
    MethodObject^.SuperclassMethods := ADR (LinkedListMethodsRecord);
END CloneLinkedListMethods;






BEGIN   (* LinkedListObjects *)

    CloneObjectMethods (ADR (LinkedListMethodsRecord));
    WITH LinkedListMethodsRecord DO

        Clone :=        AListCloneProc (ListClone);
        StoreOn :=      AListStoreOnProc (ListStoreOn);
        Discard :=      AListDiscardProc (ListDiscard);
        MethodSize :=   TSIZE (ALinkedListMethodsRecord);
        AddFirst :=     AListAddProc (AddFirstNode);
        AddLast :=      AListAddProc (AddLastNode);
        GetFirst :=     AListGetProc (GetFirstNode);
        GetLast :=      AListGetProc (GetLastNode);
        GetFirstVisible := AListGetProc (GetFirstNode);
        GetLastVisible := AListGetProc (GetLastNode);
        ForAll :=       AListForAllProc (ForAllNodes);
        ListMethodsTag := ModuleNumber;
    END;

    CloneObjectMethods (ADR (LinkedListNodeMethodsRecord));
    WITH LinkedListNodeMethodsRecord DO
        Clone :=        AListNodeCloneProc (NodeClone);
        StoreOn :=      AListNodeStoreOnProc (NodeStoreOn);
        Discard :=      AListNodeDiscardProc (NodeDiscard);
        MethodSize :=   TSIZE (ALinkedListNodeMethodsRecord);
        GetNext :=      AListNodeGetProc (GetNextNode);
        GetPrev :=      AListNodeGetProc (GetPrevNode);
        GetNextVisible := AListNodeGetProc (GetNextNode);
        GetPrevVisible := AListNodeGetProc (GetPrevNode);
        AddBefore :=    AListNodeAddProc (AddBeforeNode);
        AddAfter :=     AListNodeAddProc (AddAfterNode);
        DeList :=       AListNodeDeListProc (DeListNode);
        SetDataObject := AListNodeSetObjectProc (SetNodeDataObject);
        GetDataObject := AListNodeGetObjectProc (GetNodeDataObject);
        GetList :=      AListNodeGetListProc (GetNodeList);
        NextForDisplay := AListNodeGetProc (GetNextNode);
        PrevForDisplay := AListNodeGetProc (GetPrevNode);
        FirstVisibleCoNode := AListNodeGetProc (GetFirstVisibleCoNode);
        LastVisibleCoNode := AListNodeGetProc (GetLastVisibleCoNode);
        SetVisible := AListNodeSetVisibleProc (SetNodeVisible);
        Visible := AListNodeVisibleProc (NodeVisible);
        ListNodeMethodsTag := ModuleNumber + 1;
    END;

END LinkedListObjects.

