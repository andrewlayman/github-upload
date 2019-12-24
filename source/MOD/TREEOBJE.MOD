(*V9=DEBUGGING Code*)

IMPLEMENTATION MODULE TreeObjects;       (* A subclass of LinkedListObjects *)

    (* MODIFICATION HISTORY

    14-Jul-87 LAA   Changed NextPreOrderNode to not use FirstVisibleChild, 
                    but rather to call FirstChild.
    16-Sep-87 RSC   Removed call in CreateTree to HeapAvailable because of
                    initialization problems.  CreateTree is called by other
                    modules during init when Lights has not been initted.
    15-Oct-87 EGK   If a node has type-through on, then its visibility is
                    determined by SelfMatch and ChildrenMatch.
    01-Dec-87 LAA   Minor changes for low memory behavior.
    10-Dec-87 RSC   Implemented the LockFlexStor/UnlockFlexStor methods.
    07-Jan-88 LAA   Added UnlockUnchangedDataObject method.
    20-Sep-88 RSC   Replaced method calls with equivelent proc calls.
    10-Jan-89 RSC   Changed Storage to Space    .
    29-May-90 RSC   Initialized Level in TreeNode's Initialization.
    20-Jun-91 TGS   Well, methinks we doth initialize too much.
                    After initializing them correctly in a call to 
                    InitAsLinkedListObject, we were setting Prev and Next to 
                    NIL. Trying to delete such a thing before it had been put
                    into a list (as was happening in TLITL2) caused a NIL
                    pointer dereference. Bug 4286.
    *)


FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle,
    (* PROCS *)                 LockObject, ReleaseObject, 
                                ReleaseUnchangedObject;

FROM LinkedListObjects      IMPORT
    (* TYPE *)                  ALinkedList, ALinkedListNode,
    (* PROC *)                  CloneLinkedListMethods, ValidateLinkedList,
                                InitAsLinkedList, UnInitAsLinkedList,
                                CloneLinkedListNodeMethods, ValidateLinkedListNode,
                                InitAsLinkedListNode, UnInitAsLinkedListNode;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR  *)                  AnxietyLevel;

FROM SYSTEM                IMPORT
    (* TYPE *)                  ADDRESS, BYTE,
    (* PROC *)                  ADR, TSIZE;


CONST
    ModuleNumber = 15800;


TYPE
        (*  XTree is a subclass of LinkedListObjects.ALinkedList  *)

    XTree             = POINTER TO XTreeRecord;



        (*  XTreeNode is a subclass of LinkedListObjects.ALinkedListNode  *)

    XTreeNode         = POINTER TO XTreeNodeRecord;






TYPE

        (*  This defines the data fields which exist for every object of 
            type XTree.  Any subclasses of TreeObjects must implement 
            at least this much.
        *)



    XTreeRecord       =       RECORD
                                Methods     : ATreeMethods;
                                Header      : XTreeNode;
                                Parent      : XTreeNode;
                              END;




        (*  These are the data fields of XTreeNode.  The DataObject 
            can't be more specifically defined here, because we don't know 
            what it's a list of.  Subclasses may specify a specific data 
            object.
        *)


    AnAttributeSet = SET OF ATreeNodeAttribute;

    XTreeNodeRecord   =       RECORD
                                Methods     : ATreeNodeMethods;
                                HeaderFlag  : BOOLEAN;
                                Level       : BYTE;
                                Next        : XTreeNode;
                                Prev        : XTreeNode;
                                DataObject  : ADDRESS;
                                Subtree     : XTree;
                                Attributes  : AnAttributeSet;
                              END;



    ATreeDiscardProc        = PROCEDURE(VAR ATree);

    ATreeGetParentProc      = PROCEDURE(    ATree)
                                                  : ATreeNode;

    ATreeSetParentProc      = PROCEDURE(    ATree,
                                            ATreeNode);

    ATreeNodeDiscardProc    = PROCEDURE(VAR ATreeNode);

    ATreeNodeGetProc        = PROCEDURE(    ATreeNode)
                                                      : ATreeNode;

    ATreeNodeSetVisibleProc = PROCEDURE(    ATreeNode,
                                            BOOLEAN  );

    ATreeNodeVisibleProc    = PROCEDURE(    ATreeNode)
                                                      : BOOLEAN;

    ATreeNodeGetSubtreeProc = PROCEDURE(    ATreeNode)
                                                      : ATree;

    ATreeNodeSetSubtreeProc = PROCEDURE(    ATreeNode,
                                            ATree    );

    ATreeNodeLevelProc      = PROCEDURE(    ATreeNode)
                                                      : CARDINAL;

    ATreeNodeParentProc     = PROCEDURE(    ATreeNode)
                                                      : ATreeNode;

    ATreeNodeSetAttrBitProc     = PROCEDURE( ATreeNode,             (* Node *)
                                             ATreeNodeAttribute,    (* Flag *)
                                             BOOLEAN            );  (* Value *)

    ATreeNodeGetAttrBitProc     = PROCEDURE( ATreeNode,             (* Node *)
                                             ATreeNodeAttribute)    (* Flag *)
                                                                : BOOLEAN;

    ATreeNodeSetAttributesProc  = PROCEDURE( ATreeNode,
                                             CARDINAL       );

    ATreeNodeGetAttributesProc  = PROCEDURE( ATreeNode )
                                                        : CARDINAL;

    ATreeNodeGetObjectProc      = PROCEDURE( ATreeNode)
                                                       : ADDRESS;

    ATreeNodeUnlockProc         = PROCEDURE( ATreeNode);



VAR
    TreeMethodsRecord     : ATreeMethodsRecord;
    TreeNodeMethodsRecord : ATreeNodeMethodsRecord;
    LinkedListGetNext     : ATreeNodeGetProc;
    LinkedListGetPrev     : ATreeNodeGetProc;



(*----------------------------------------------------------------------------
    IncrementNodeLevel, and IncrementLevel
    are used internal to this module.
*)





PROCEDURE SetNodeLevelFromParent (VAR Node    : ATreeNode;
                                      Context : ADDRESS);

VAR
    LocalNode,
    ParentNode: XTreeNode;

BEGIN           (* SetNodeLevelFromParent *)

    LocalNode        := XTreeNode(Node);
    ParentNode       := GetNodeParent( Node );  (* RSC 9/20/88 *)
    WITH LocalNode^ DO
        Level := ParentNode^.Level;
        INC(Level);
    END;

END SetNodeLevelFromParent;





PROCEDURE SetAllLevels (Node: ATreeNode);

VAR
    LocalNode,
    ParentNode  : XTreeNode;
    Subtree     : XTree;

BEGIN           (* SetAllLevels *)

    ParentNode       := GetNodeParent( Node );  (* RSC 9/20/88 *)
    LocalNode        := XTreeNode(Node);
    IF (ParentNode = NIL) THEN
        LocalNode^.Level := BYTE(0C);
    ELSE
        WITH LocalNode^ DO
            Level := ParentNode^.Level;
            INC(Level);
        END;
    END;
    Subtree := GetNodeSubtree( LocalNode );
    IF (Subtree <> NIL) THEN
        Traverse ( ATree(Subtree), ParentBeforeChild, 9999,
                   SetNodeLevelFromParent, NIL);
    END;

END SetAllLevels;






(*----------------------------------------------------------------------------
    Here are the "real methods" for TreeObjects
*)




PROCEDURE NodeClone (Node1: ATreeNode;
                 VAR Node2: ATreeNode): BOOLEAN;
VAR
    Subtree       : XTree;
    NewTree       : ATree;
    LocalNode1,
    LocalNode2    : XTreeNode;

BEGIN                   (* NodeClone *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node1);
    END;
    DEBUGGING>*)

    IF NOT CreateTreeNode (Node2) THEN
        RETURN FALSE;
    END;

    LocalNode1 := XTreeNode(Node1);
    LocalNode2 := XTreeNode(Node2);
    LocalNode2^.DataObject := LocalNode1^.DataObject;     (* RSC 9/20/88 *)

    Subtree := GetNodeSubtree( LocalNode1 );
    IF (Subtree <> NIL) THEN
        IF NOT TreeClone( ATree(Subtree), NewTree ) THEN
            NodeDiscard( LocalNode2 );
            RETURN FALSE;
        ELSE
            SetNodeSubtree( LocalNode2, XTree(NewTree) );
        END;
    END;
    RETURN TRUE;

END NodeClone;





PROCEDURE NodeStoreOn ( Node: ATreeNode;
                        File: AnObject );

BEGIN                   (* NodeStoreOn *)
    FatalError();
END NodeStoreOn;






PROCEDURE NodeDiscard (VAR Node: XTreeNode);

BEGIN                   (* NodeDiscard *)
      (*<DEBUG
    ValidateTreeNode (ATreeNode (Node));
      DEBUG>*)
    UnInitAsTreeNode (ATreeNode (Node));
    DISPOSE (Node);
END NodeDiscard;





PROCEDURE GetNextVisibleNode (Node: ATreeNode): ATreeNode;

BEGIN           (* GetNextVisibleNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    REPEAT
        Node := LinkedListGetNext( Node );                (* RSC 9/20/88 *)
    UNTIL (Node = NIL) OR (NodeVisible(XTreeNode(Node)));
    RETURN Node;

END GetNextVisibleNode;




PROCEDURE GetPrevVisibleNode (Node: ATreeNode): ATreeNode;

BEGIN           (* GetPrevVisibleNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    REPEAT
        Node := LinkedListGetPrev( Node );                  (* RSC 9/20/88 *)
    UNTIL (Node = NIL) OR (NodeVisible(XTreeNode(Node)));
    RETURN Node;

END GetPrevVisibleNode;







PROCEDURE AddBeforeNode (TargetNode, NewNode: ATreeNode);

BEGIN           (* AddBeforeNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (TargetNode);
        ValidateTreeNode (NewNode);
    END;
    DEBUGGING>*)

    TreeNodeMethodsRecord.SuperclassMethods^.AddBefore
        (ALinkedListNode (TargetNode), ALinkedListNode (NewNode));
    SetAllLevels (NewNode);
END AddBeforeNode;



PROCEDURE AddAfterNode (TargetNode, NewNode: ATreeNode);

BEGIN           (* AddAfterNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (TargetNode);
        ValidateTreeNode (NewNode);
    END;
    DEBUGGING>*)

    TreeNodeMethodsRecord.SuperclassMethods^.AddAfter
        (ALinkedListNode (TargetNode), ALinkedListNode (NewNode));
    SetAllLevels (NewNode);
END AddAfterNode;




PROCEDURE SetNodeVisible (Node: ATreeNode;
                          Flag: BOOLEAN);

BEGIN           (* SetNodeVisible *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    SetNodeAttribute ( XTreeNode(Node), SelfVisible, Flag); (* RSC 9/20/88 *)

END SetNodeVisible;




PROCEDURE NodeVisible (Node: XTreeNode): BOOLEAN;

BEGIN           (* NodeVisible *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    IF (TypeThroughEnable IN Node^.Attributes) THEN
        RETURN (SelfMatch IN Node^.Attributes) OR
               (ChildrenMatch IN Node^.Attributes);
    ELSE
        RETURN ((SelfVisible IN Node^.Attributes)
            AND (PrivateSelfVisible IN Node^.Attributes));
    END;

END NodeVisible;





PROCEDURE SetNodePrivateVisible (Node: ATreeNode;
                                 Flag: BOOLEAN);

BEGIN           (* SetNodePrivateVisible *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    SetNodeAttribute ( XTreeNode(Node), PrivateSelfVisible, Flag); (* RSC 9/20/88 *)

END SetNodePrivateVisible;




PROCEDURE NodePrivateVisible (Node: XTreeNode): BOOLEAN;

BEGIN           (* NodePrivateVisible *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    RETURN (PrivateSelfVisible IN Node^.Attributes);

END NodePrivateVisible;





PROCEDURE GetNextForDisplay (Node: ATreeNode)
                                             : ATreeNode;
VAR
    CNode, TNode: ATreeNode;

BEGIN           (* GetNextForDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    TNode := GetFirstVisibleChild( Node ); (* RSC 9/20/88 *)
    IF (TNode <> NIL) THEN
        RETURN TNode;
    END;

    TNode := GetNextVisibleNode( Node );
    IF (TNode <> NIL) THEN
        RETURN TNode;
    END;

    LOOP
        TNode := ATreeNode(GetNodeParent( Node ));  (* RSC 9/20/88 *)
        IF (TNode = NIL) THEN
            RETURN NIL;
        END;
        CNode := GetNextVisibleNode( TNode );
        IF (CNode <> NIL) THEN
            RETURN CNode;
        END;
        Node := TNode;
    END;

END GetNextForDisplay;





PROCEDURE GetPrevForDisplay (Node: ATreeNode)
                                             : ATreeNode;
VAR
    CNode, PNode: ATreeNode;

BEGIN           (* GetPrevForDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    CNode := GetPrevVisibleNode( Node );  (* RSC 9/20/88 *)
    IF (CNode = NIL) THEN
        LOOP
            PNode := ATreeNode(GetNodeParent( Node ));  (* RSC 9/20/88 *)
            IF (PNode = NIL) THEN
                RETURN NIL;
            ELSIF (NodeVisible(XTreeNode(PNode))) THEN
                RETURN PNode;
            ELSE
                RETURN GetPrevForDisplay (PNode);
            END;
        END;
    ELSE
        Node := CNode;
        LOOP
            CNode := GetLastVisibleChild (Node);
            IF (CNode = NIL) THEN
                RETURN Node;
            ELSE
                Node := CNode;
            END;
        END;
    END;

END GetPrevForDisplay;




PROCEDURE NextPreOrderNode(    Node         : ATreeNode)
                                                        : ATreeNode;

VAR
    CNode, TNode: ATreeNode;

BEGIN                       (* NextPreOrderNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    TNode := GetFirstChild( Node ); (* RSC 9/20/88 *)    (* 14-Jul-87 LAA *)
    IF (TNode <> NIL) THEN
        RETURN TNode;
    END;

    TNode := LinkedListGetNext(Node);
    IF (TNode <> NIL) THEN
        RETURN TNode;
    END;

    LOOP
        TNode := GetNodeParent( Node );
        IF (TNode = NIL) THEN
            RETURN NIL;
        END;
        CNode := LinkedListGetNext( TNode );
        IF (CNode <> NIL) THEN
            RETURN CNode;
        END;
        Node := TNode;
    END;

END NextPreOrderNode;



PROCEDURE PrevPreOrderNode(    Node         : ATreeNode)
                                                        : ATreeNode;

VAR
    CNode, PNode: ATreeNode;

BEGIN                       (* PrevPreOrderNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    CNode := LinkedListGetPrev( Node );  (* RSC 9/20/88 *)
    IF (CNode = NIL) THEN
        PNode := GetNodeParent( Node );
        IF (PNode = NIL) THEN
            RETURN NIL;
        ELSE
            RETURN PNode;
        END;
    ELSE
        Node := CNode;
        LOOP
            CNode := GetLastChild(Node);
            IF (CNode = NIL) THEN
                RETURN Node;
            ELSE
                Node := CNode;
            END;
        END;
    END;

END PrevPreOrderNode;




PROCEDURE GetFirstVisibleCoNode (Node: ATreeNode)
                                                 : ATreeNode;
VAR
    PrevNode: ATreeNode;

BEGIN           (* GetFirstVisibleCoNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    LOOP
        PrevNode := GetPrevVisibleNode( Node );
        IF (PrevNode = NIL) THEN
            RETURN Node;
        ELSE
            Node := PrevNode;
        END;
    END;

END GetFirstVisibleCoNode;




PROCEDURE GetLastVisibleCoNode (Node: ATreeNode)
                                                 : ATreeNode;
VAR
    NextNode: ATreeNode;

BEGIN           (* GetLastVisibleCoNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    LOOP
        NextNode := GetNextVisibleNode( Node );
        IF (NextNode = NIL) THEN
            RETURN Node;
        ELSE
            Node := NextNode;
        END;
    END;

END GetLastVisibleCoNode;






PROCEDURE GetNodeSubtree (Node: XTreeNode): XTree;

VAR
    Subtree : ATree;
BEGIN
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    Subtree := ATree (Node^.Subtree);
    IF (Subtree <> NIL) THEN

            (*  This is kind of a crude garbage collection step that
                looks for subtrees that have no nodes and discards them,
                since the NIL subtree object represents the same thing
                but with less space.
            *)

        IF (Subtree^.Methods^.GetFirst (Subtree) = NIL) THEN
            Subtree^.Methods^.Discard (Subtree);
            Node^.Subtree := NIL;
        END;
    END;
    RETURN Node^.Subtree;

END GetNodeSubtree;




PROCEDURE SetNodeSubtree (Node: XTreeNode;
                          Tree: XTree);

BEGIN           (* SetNodeSubtree *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    Node^.Subtree := Tree;
    Tree^.Parent := Node;

END SetNodeSubtree;




PROCEDURE GetNodeLevel (Node: XTreeNode): CARDINAL;
BEGIN           (* GetNodeLevel *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    RETURN ORD (Node^.Level);

END GetNodeLevel;




PROCEDURE NodePromote (Node: ATreeNode);
VAR
    ParentNode: ATreeNode;

BEGIN           (* NodePromote *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    ParentNode := GetNodeParent( Node ); (* RSC 9/20/88 *)
    IF (ParentNode <> NIL) THEN
        Node^.Methods^.DeList( Node );
        AddAfterNode( ParentNode, Node );
    ELSE
        (* Post an error *)
    END;

END NodePromote;




PROCEDURE NodeDemote (Node: ATreeNode);

VAR
    PrevNode: ATreeNode;

BEGIN           (* NodeDemote *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    PrevNode := Node^.Methods^.GetPrev (Node);
    IF (PrevNode <> NIL) THEN
        Node^.Methods^.DeList( Node );
        AddLastChild( PrevNode, Node ); (* RSC 9/20/88 *)
    END;

END NodeDemote;




PROCEDURE GetNodeParent (Node: ATreeNode): XTreeNode;
VAR
    Tree: ATree;

BEGIN           (* GetNodeParent *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    Tree := Node^.Methods^.GetList (Node);
    IF (Tree = NIL) THEN
        RETURN NIL;
    ELSE
        RETURN GetTreeParent( XTree(Tree) );
    END;
END GetNodeParent;



PROCEDURE GetFirstChild (Node: ATreeNode): ATreeNode;
VAR
    Subtree: ATree;

BEGIN           (* GetFirstChild *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    Subtree := GetNodeSubtree( XTreeNode(Node) ); (* RSC 9/20/88 *)
    IF (Subtree = NIL) THEN
        RETURN NIL;
    ELSE
        RETURN Subtree^.Methods^.GetFirst (Subtree);
    END;
END GetFirstChild;




PROCEDURE GetLastChild (Node: ATreeNode): ATreeNode;
VAR
    Subtree: ATree;

BEGIN           (* GetLastChild *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    Subtree := GetNodeSubtree( XTreeNode(Node) ); (* RSC 9/20/88 *)
    IF (Subtree = NIL) THEN
        RETURN NIL;
    ELSE
        RETURN Subtree^.Methods^.GetLast (Subtree);
    END;
END GetLastChild;




PROCEDURE GetFirstVisibleChild (Node: ATreeNode): ATreeNode;

BEGIN           (* GetFirstVisibleChild *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    IF ((NOT NodeChildrenVisible( XTreeNode(Node) )) OR (* RSC 9/20/88 *)
        (GetNodeSubtree( XTreeNode(Node) ) = NIL)) THEN
        RETURN NIL;
    END;
    Node := GetFirstChild (Node);
    IF (Node = NIL) THEN
        RETURN NIL;
    ELSIF (NodeVisible( XTreeNode(Node) )) THEN
        RETURN Node;
    ELSE
        RETURN GetNextVisibleNode( XTreeNode(Node) );
    END;

END GetFirstVisibleChild;


PROCEDURE GetLastVisibleChild (Node: ATreeNode): ATreeNode;

BEGIN           (* GetLastVisibleChild *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    IF ((NOT NodeChildrenVisible( XTreeNode(Node) )) OR (* RSC 9/20/88 *)
        (GetNodeSubtree( XTreeNode(Node) ) = NIL)) THEN
        RETURN NIL;
    END;
    Node := GetLastChild (Node);
    IF (Node = NIL) THEN
        RETURN NIL;
    ELSIF (NodeVisible( XTreeNode(Node) )) THEN
        RETURN Node;
    ELSE
        RETURN GetPrevVisibleNode( XTreeNode(Node) );
    END;

END GetLastVisibleChild;




PROCEDURE SetNodeChildrenVisible (Node: ATreeNode;
                                  Flag: BOOLEAN);

BEGIN           (* SetNodeChildrenVisible *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    SetNodeAttribute( XTreeNode(Node), ChildrenVisible, Flag );

END SetNodeChildrenVisible;




PROCEDURE NodeChildrenVisible (Node: XTreeNode): BOOLEAN;

BEGIN           (* NodeChildrenVisible *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    RETURN (ChildrenVisible IN Node^.Attributes);

END NodeChildrenVisible;





PROCEDURE NodeParentVisible (Node: ATreeNode): BOOLEAN;

BEGIN           (* NodeParentVisible *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    Node := GetNodeParent (Node);
    RETURN ((Node <> NIL) AND (NodeVisible( XTreeNode(Node) )));

END NodeParentVisible;







PROCEDURE AddFirstChild (ParentNode, ChildNode: ATreeNode);
VAR
    Subtree: ATree;

BEGIN           (* AddFirstChild *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ParentNode);
        ValidateTreeNode (ChildNode);
    END;
    DEBUGGING>*)

    Subtree := GetNodeSubtree( XTreeNode(ParentNode) );
    IF (Subtree = NIL) THEN
        IF CreateTree (Subtree) THEN
            SetNodeSubtree( XTreeNode(ParentNode), XTree(Subtree) );
        ELSE
            (* Post an error *)
            FatalError(); (* RSC 9/20/88 was no check here, so ... *)
        END;
    END;
    AddFirstNode( Subtree, ChildNode );

END AddFirstChild;



PROCEDURE AddLastChild (ParentNode, ChildNode: ATreeNode);
VAR
    Subtree: ATree;

BEGIN           (* AddLastChild *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ParentNode);
        ValidateTreeNode (ChildNode);
    END;
    DEBUGGING>*)

    Subtree := GetNodeSubtree( XTreeNode(ParentNode) );
    IF (Subtree = NIL) THEN
        IF CreateTree (Subtree) THEN
            SetNodeSubtree( XTreeNode(ParentNode), XTree(Subtree) );
        ELSE
            (* Post an error *)
        END;
    END;
    AddLastNode(Subtree, ChildNode);

END AddLastChild;





PROCEDURE GetNodeRoot (Node: ATreeNode): ATree;
VAR
    Tree: ATree;

BEGIN           (* GetNodeRoot *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    Tree := Node^.Methods^.GetList (Node);
    IF (Tree = NIL) THEN
        RETURN NIL;
    ELSE
        RETURN GetTreeRoot (Tree);
    END;

END GetNodeRoot;





PROCEDURE GetNodeAttribute (Node: XTreeNode;
                            Flag: ATreeNodeAttribute)    : BOOLEAN;
BEGIN           (* GetNodeAttribute *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    RETURN (Flag IN Node^.Attributes);

END GetNodeAttribute;




PROCEDURE SetNodeAttribute (Node: XTreeNode;
                            Flag: ATreeNodeAttribute;
                            Value: BOOLEAN);

BEGIN           (* SetNodeSelection *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode(Node));
    END;
    DEBUGGING>*)

    WITH Node^ DO
        IF (Value) THEN
            INCL (Attributes, Flag);
        ELSE
            EXCL (Attributes, Flag);
        END;
    END;

END SetNodeAttribute;





PROCEDURE GetNodeAttributes (Node: XTreeNode)
                                             : CARDINAL;
BEGIN           (* GetNodeAttributes *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    RETURN CARDINAL (Node^.Attributes);

END GetNodeAttributes;




PROCEDURE SetNodeAttributes (Node       : XTreeNode;
                             Value      : CARDINAL  );

BEGIN           (* SetNodeAttributes *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    Node^.Attributes := AnAttributeSet (Value);

END SetNodeAttributes;






PROCEDURE TreeClone (Tree1: ATree;
                 VAR Tree2: ATree): BOOLEAN;

VAR
    CurrentNode,
    NewNode     : ATreeNode;
    LocalTree   : XTree;

BEGIN                   (* TreeClone *)
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree (Tree1);
    END;
    DEBUGGING>*)

    IF NOT CreateTree (Tree2) THEN
        RETURN FALSE;
    END;

    CurrentNode := Tree1^.Methods^.GetFirst (Tree1);
    WHILE (CurrentNode <> NIL) DO
        IF NOT NodeClone( CurrentNode, NewNode ) THEN
            LocalTree := XTree(Tree2);
            TreeDiscard( LocalTree );
            Tree2 := ATree(LocalTree);
            RETURN FALSE;
        END;
        Tree2^.Methods^.AddLast (Tree2, NewNode);
        CurrentNode := LinkedListGetNext (CurrentNode); (* RSC 9/20/88 *)
    END;
    RETURN TRUE;
END TreeClone;





PROCEDURE TreeStoreOn (Tree: ATree;
                       File: AnObject);

BEGIN                   (* TreeStoreOn *)

    FatalError();

END TreeStoreOn;





PROCEDURE TreeDiscard (VAR Tree: XTree);

BEGIN                   (* TreeDiscard *)

    (*<DEBUGGING
    ValidateTree (ATree (Tree));
    DEBUGGING>*)
    UnInitAsTree (ATree (Tree));
    DISPOSE (Tree);

END TreeDiscard;




PROCEDURE AddFirstNode (Tree: ATree;
                        Node: ATreeNode);

BEGIN           (* AddFirstNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree (Tree);
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    TreeMethodsRecord.SuperclassMethods^.AddFirst
        (ALinkedList (Tree), ALinkedListNode (Node));
    SetAllLevels (Node);
END AddFirstNode;




PROCEDURE AddLastNode (Tree: ATree;
                        Node: ATreeNode);

BEGIN           (* AddLastNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree (Tree);
        ValidateTreeNode (Node);
    END;
    DEBUGGING>*)

    TreeMethodsRecord.SuperclassMethods^.AddLast
        (ALinkedList (Tree), ALinkedListNode (Node));
    SetAllLevels (Node);
END AddLastNode;




PROCEDURE GetFirstVisibleNode (Tree: ATree): ATreeNode;

VAR
    CurrentNode: ATreeNode;

BEGIN           (* GetFirstVisibleNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree (Tree);
    END;
    DEBUGGING>*)

    CurrentNode := Tree^.Methods^.GetFirst (Tree);
    IF (CurrentNode = NIL) THEN
        RETURN NIL;
    ELSIF (NodeVisible( XTreeNode(CurrentNode) )) THEN
        RETURN CurrentNode;
    ELSE
        RETURN GetNextVisibleNode( CurrentNode ); (* RSC 9/20/88 *)
    END;

END GetFirstVisibleNode;




PROCEDURE GetLastVisibleNode (Tree: ATree): ATreeNode;

VAR
    CurrentNode: ATreeNode;

BEGIN           (* GetLastVisibleNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree (Tree);
    END;
    DEBUGGING>*)

    CurrentNode := Tree^.Methods^.GetLast (Tree);
    IF (CurrentNode = NIL) THEN
        RETURN NIL;
    ELSIF (NodeVisible( XTreeNode(CurrentNode) )) THEN
        RETURN CurrentNode;
    ELSE
        RETURN GetPrevVisibleNode( CurrentNode );
    END;

END GetLastVisibleNode;






PROCEDURE GetTreeParent (Tree: XTree): XTreeNode;

BEGIN           (* GetTreeParent *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree (ATree (Tree));
    END;
    DEBUGGING>*)

    RETURN Tree^.Parent;

END GetTreeParent;





PROCEDURE SetTreeParent ( Tree: XTree;
                          Node: XTreeNode );

BEGIN           (* SetTreeParent *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree (ATree (Tree));
        ValidateTreeNode (ATreeNode (Node));
    END;
    DEBUGGING>*)

    Tree^.Parent  := Node;
    Node^.Subtree := Tree;

END SetTreeParent;





PROCEDURE Traverse (Tree: ATree;
                    Order: ATreeOrder;
                    Level: CARDINAL;
                    ProcessingProc: ATreeNodeProcessingProc;
                    Context                 : ADDRESS      );

VAR
    CurrentNode, NextNode: ATreeNode;
    Subtree: ATree;

BEGIN           (* Traverse *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateTree (Tree);
    END;
    (*DEBUGGING>*)

    CurrentNode := Tree^.Methods^.GetFirst (Tree);
    WHILE (CurrentNode <> NIL) DO

        NextNode := LinkedListGetNext( CurrentNode );

        IF ((Level > 0) AND (CurrentNode <> NIL)) THEN
            Subtree := GetNodeSubtree( XTreeNode(CurrentNode) );
            IF (Subtree <> NIL) THEN
                IF (Order = ParentBeforeChild) THEN
                    ProcessingProc( CurrentNode, Context );
                END;
                Traverse (Subtree, Order, Level - 1, ProcessingProc, Context);
                IF (Order = ParentAfterChild) THEN
                    ProcessingProc (CurrentNode, Context);
                END;
            ELSE
                ProcessingProc (CurrentNode, Context);
            END;
        ELSE
            ProcessingProc (CurrentNode, Context);
        END;

        CurrentNode := NextNode;
    END;

END Traverse;




PROCEDURE GetTreeRoot (Tree: ATree): ATree;
VAR
    ParentNode: ATreeNode;

BEGIN           (* GetTreeRoot *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree (Tree);
    END;
    DEBUGGING>*)

    ParentNode := GetTreeParent( XTree(Tree) );
    IF (ParentNode = NIL) THEN
        RETURN Tree;
    ELSE
        RETURN GetNodeRoot( ParentNode );
    END;

END GetTreeRoot;




PROCEDURE LockFlexStorObject(    TreeNode   : XTreeNode)
                                                        : ADDRESS;
VAR
    A : ADDRESS;
    i : CARDINAL;
BEGIN                       (* LockFlexStorObject *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (TreeNode));
    END;
    (*DEBUGGING>*)

    i := LockObject( AnExtHandle(TreeNode^.DataObject), A );
    RETURN A;

END LockFlexStorObject;





PROCEDURE UnlockFlexStorObject(    TreeObject : XTreeNode);

BEGIN                       (* UnlockFlexStorObject *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (TreeObject));
    END;
    (*DEBUGGING>*)

    ReleaseObject( AnExtHandle(TreeObject^.DataObject) );

END UnlockFlexStorObject;



PROCEDURE UnlockUnchangedObject(    TreeObject : XTreeNode);

BEGIN                       (* UnlockUnchangedObject *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateTreeNode (ATreeNode (TreeObject));
    END;
    (*DEBUGGING>*)

    ReleaseUnchangedObject( AnExtHandle(TreeObject^.DataObject) );

END UnlockUnchangedObject;






(*----------------------------------------------------------------------------
    InitAsTreeNode --

    Initialize the indicated storage location as an object of type 
    ATreeNode.

    Preconditions:
        None.

    Postconditions:
        The indicated object will be initialized as a tree node object.  This 
        procedure does not allocate storage, it only initializes the area
        of memory referenced by the object provided.
----------------------------------------------------------------------------*)
PROCEDURE InitAsTreeNode (Node: ATreeNode);
VAR
    PrivateNode: XTreeNode;

BEGIN                   (* InitAsTreeNode *)

    InitAsLinkedListNode (ALinkedListNode (Node));

    PrivateNode := XTreeNode (Node);
    WITH PrivateNode^ DO
        Methods     := ADR (TreeNodeMethodsRecord);
        Subtree     := NIL;
        Attributes  := AnAttributeSet {SelfVisible, ChildrenVisible,
                                       PrivateSelfVisible};
        (* 29-May-90 RSC Added init of these items: *)
        Level       := BYTE(0C);
        (* 20-Jun-91 TGS These are all init-ed, correctly, in InitAsLinkedListNode
        Next        := NIL;
        Prev        := NIL;
        DataObject  := NIL;
        HeaderFlag  := FALSE;
        *)
    END;

END InitAsTreeNode;





(*----------------------------------------------------------------------------
    UnInitAsTreeNode --

    Un-Initialize the indicated storage location as an object of type 
    ATreeNode.

    Preconditions:
        The object must be a valid Tree Node Object.

    Postconditions:
        The indicated object will no longer be initialized as a tree node
        object.  Any side-effects of InitAsTreeNode will be undone.
        This procedure does not deallocate storage.
----------------------------------------------------------------------------*)
PROCEDURE UnInitAsTreeNode (Node: ATreeNode);
VAR
    Subtree : XTree;

BEGIN           (* UnInitAsTreeNode *)

    Node^.Methods^.DeList (Node);
    Subtree := XTree(GetNodeSubtree( XTreeNode(Node) ));
    IF (Subtree <> NIL) THEN
        TreeDiscard( Subtree );
    END;    
    UnInitAsLinkedListNode( ALinkedListNode( Node ) );

END UnInitAsTreeNode;





(*----------------------------------------------------------------------------
    CreateTreeNode --

    Allocate storage off the heap, and initialize it as an object of type
    ATreeNode.  This procedure should only be used to create objects
    which are not subclassed, or for which the subclassing does not add new
    data fields.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, a new object of type
        ATreeNode will be allocated, initialized, and TRUE will be 
        returned.
----------------------------------------------------------------------------*)
PROCEDURE CreateTreeNode (VAR Node: ATreeNode): BOOLEAN;

BEGIN                   (* CreateTreeNode *)

    IF (NOT Available(TSIZE(XTreeNodeRecord))) THEN               (* 01-Dec-87 LAA *)
        RETURN FALSE;
    END;
    ALLOCATE(Node, TSIZE(XTreeNodeRecord));
    InitAsTreeNode(Node);
    RETURN TRUE;
END CreateTreeNode;




(*----------------------------------------------------------------------------
    ValidateTreeNode --

    Validate the indicated storage location as an object of type 
    ATreeNode.

    Preconditions:
        None.

    Postconditions:
        If the indicated object is not a tree node, or a subclass, 
        FatalError will be called.
----------------------------------------------------------------------------*)
PROCEDURE ValidateTreeNode (Node: ATreeNode);
VAR
    PrivateNode: XTreeNode;

BEGIN                   (* ValidateTreeNode *)

    (*<DEBUGGING
    IF (AnxietyLevel <> Calm) THEN
        ValidateLinkedListNode (ALinkedListNode (Node));
    END;
    DEBUGGING>*)

    PrivateNode := XTreeNode (Node);

    IF (PrivateNode^.Methods^.TreeNodeMethodsTag <> ModuleNumber + 1) THEN
        FatalError;
    END;
END ValidateTreeNode;




(*----------------------------------------------------------------------------
    CloneTreeNodeMethods --

    Make a copy of this class' methods into the indicated method object.

    Preconditions:
        None.

    Postconditions:
        The linked list node methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)
PROCEDURE CloneTreeNodeMethods (MethodObject: ATreeNodeMethods);

BEGIN                   (* CloneTreeNodeMethods *)

    MethodObject^ := TreeNodeMethodsRecord;
    MethodObject^.SuperclassMethods := ADR (TreeNodeMethodsRecord);
END CloneTreeNodeMethods;





(*----------------------------------------------------------------------------
    InitAsTree --

    Initialize the indicated storage location as an object of type 
    ATree.

    Preconditions:
        None.

    Postconditions:
        The indicated object will be initialized as a tree object.  This 
        procedure does not allocate storage, it only initializes the area
        of memory referenced by the object provided.
----------------------------------------------------------------------------*)
PROCEDURE InitAsTree (Tree: ATree);
VAR
    PrivateTree: XTree;

BEGIN                   (* InitAsTree *)

    InitAsLinkedList (ALinkedList (Tree));

    PrivateTree := XTree (Tree);

    WITH PrivateTree^ DO
        Methods := ADR (TreeMethodsRecord); (* Coercion happens here !!!*)
        Parent := NIL;
    END;

END InitAsTree;




(*----------------------------------------------------------------------------
    UnInitAsTree --

    Un-Initialize the indicated storage location as an object of type 
    ATree.

    Preconditions:
        The object must be a valid Tree Object.

    Postconditions:
        The indicated object will no longer be initialized as a tree object.
        Any side-effects of InitAsTree will be undone.  This 
        procedure does not deallocate storage.
----------------------------------------------------------------------------*)
PROCEDURE UnInitAsTree (Tree: ATree);

BEGIN

    Tree^.Methods^.ForAll (Tree, DiscardAnyNode, NIL);

    UnInitAsLinkedList (ALinkedList (Tree));

END UnInitAsTree;


(*  DiscardAnyNode is used in UnInitAsTree simply to pass the correct
    Discard procedure to each node referred to in ForAll.           *)

PROCEDURE DiscardAnyNode (VAR Node          : ATreeNode;
                              Context       : ADDRESS  );
VAR
    LocalNode : XTreeNode;
BEGIN
    LocalNode := XTreeNode(Node);
    NodeDiscard( LocalNode ); (* RSC 9/20/88 *)
    Node      := ATreeNode(LocalNode);
END DiscardAnyNode;





(*----------------------------------------------------------------------------
    CreateTree --

    Allocate storage off of the heap, and initialize it as an object of type
    ATree.  This procedure should only be used to create objects
    which are not subclassed, or for which the subclassing does not add new
    data fields.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, a new object of type
        ATree will be allocated, initialized, and TRUE will be returned.
----------------------------------------------------------------------------*)
PROCEDURE CreateTree (VAR Tree: ATree): BOOLEAN;

BEGIN                   (* CreateTree *)

    IF (NOT Available(TSIZE(XTreeRecord))) THEN                   (* 01-Dec-87 LAA *)
        RETURN FALSE;
    END;
    ALLOCATE (Tree, TSIZE (XTreeRecord));
    InitAsTree (Tree);
    RETURN TRUE;
END CreateTree;




(*----------------------------------------------------------------------------
    ValidateTree --

    Validate the indicated storage location as an object of type 
    ATree.

    Preconditions:
        None.

    Postconditions:
        If the indicated object is not a linked list, or a subclass, 
        FatalError will be called.
----------------------------------------------------------------------------*)
PROCEDURE ValidateTree (Tree: ATree);
VAR
    PrivateTree: XTree;

BEGIN                   (* ValidateTree *)
    (*<DEBUGGING
    IF (AnxietyLevel <> Calm) THEN
        ValidateLinkedList (ALinkedList (Tree));
    END;
    DEBUGGING>*)

    PrivateTree := XTree (Tree);
    IF (PrivateTree^.Methods^.TreeMethodsTag <> ModuleNumber) THEN
        FatalError;
    END;
END ValidateTree;




(*----------------------------------------------------------------------------
    CloneTreeMethods --

    Make a copy of this class' methods into the indicated method object.

    Preconditions:
        None.

    Postconditions:
        The tree methods will be copied into the indicated method object.
----------------------------------------------------------------------------*)
PROCEDURE CloneTreeMethods (MethodObject: ATreeMethods);

BEGIN                   (* CloneTreeMethods *)

    MethodObject^ := TreeMethodsRecord;
    MethodObject^.SuperclassMethods := ADR (TreeMethodsRecord);
END CloneTreeMethods;






BEGIN   (* TreeObjects *)

    CloneLinkedListMethods (ADR (TreeMethodsRecord));
    WITH TreeMethodsRecord DO

        Clone :=        TreeClone;
        StoreOn :=      TreeStoreOn;
        Discard :=      ATreeDiscardProc (TreeDiscard);
        MethodSize :=   TSIZE (ATreeMethodsRecord);
        AddFirst :=     AddFirstNode;
        AddLast :=      AddLastNode;
        GetFirstVisible := GetFirstVisibleNode;
        GetLastVisible :=  GetLastVisibleNode;
        GetParent :=    ATreeGetParentProc (GetTreeParent);
        SetParent :=    ATreeSetParentProc (SetTreeParent);
        TraverseTree := Traverse;
        GetRoot :=      GetTreeRoot;
        TreeMethodsTag := ModuleNumber;
    END;

    CloneLinkedListNodeMethods (ADR (TreeNodeMethodsRecord));
    WITH TreeNodeMethodsRecord DO
        Clone               := NodeClone;
        StoreOn             := NodeStoreOn;
        Discard             := ATreeNodeDiscardProc (NodeDiscard);
        MethodSize          := TSIZE (ATreeNodeMethodsRecord);
        GetNextVisible      := GetNextVisibleNode;
        GetPrevVisible      := GetPrevVisibleNode;
        AddBefore           := AddBeforeNode;
        AddAfter            := AddAfterNode;
        SetVisible          := ATreeNodeSetVisibleProc (SetNodeVisible);
        Visible             := ATreeNodeVisibleProc (NodeVisible);
        SetPrivateVisible   := ATreeNodeSetVisibleProc (SetNodePrivateVisible);
        PrivateVisible      := ATreeNodeVisibleProc (NodePrivateVisible);
        NextForDisplay      := GetNextForDisplay;
        PrevForDisplay      := GetPrevForDisplay;
        FirstVisibleCoNode  := GetFirstVisibleCoNode;
        LastVisibleCoNode   := GetLastVisibleCoNode;
        GetSubtree          := ATreeNodeGetSubtreeProc (GetNodeSubtree);
        SetSubtree          := ATreeNodeSetSubtreeProc (SetNodeSubtree);
        IndentationLevel    := ATreeNodeLevelProc (GetNodeLevel);
        Promote             := NodePromote;
        Demote              := NodeDemote;
        Parent              := ATreeNodeParentProc (GetNodeParent);
        FirstChild          := GetFirstChild;
        LastChild           := GetLastChild;
        FirstVisibleChild   := GetFirstVisibleChild;
        LastVisibleChild    := GetLastVisibleChild;
        SetChildrenVisible  := ATreeNodeSetVisibleProc (SetNodeChildrenVisible);
        ChildrenVisible     := ATreeNodeVisibleProc (NodeChildrenVisible);
        ParentVisible       := NodeParentVisible;
        AddAsFirstChild     := AddFirstChild;
        AddAsLastChild      := AddLastChild;
        GetRoot             := GetNodeRoot;
        SetAttributeBit     := ATreeNodeSetAttrBitProc (SetNodeAttribute);
        TestAttributeBit    := ATreeNodeGetAttrBitProc (GetNodeAttribute);
        SetAttributes       := ATreeNodeSetAttributesProc (SetNodeAttributes);
        GetAttributes       := ATreeNodeGetAttributesProc (GetNodeAttributes);
        NextPreOrder        := ATreeNodeGetProc(NextPreOrderNode);
        PrevPreOrder        := ATreeNodeGetProc(PrevPreOrderNode);
        LockFlexStorDataObject   := ATreeNodeGetObjectProc(LockFlexStorObject);
        UnlockFlexStorDataObject := ATreeNodeUnlockProc(UnlockFlexStorObject);
        UnlockUnchangedDataObject := ATreeNodeUnlockProc(UnlockUnchangedObject);
        TreeNodeMethodsTag  := ModuleNumber + 1;
    END;

    (* Save these foreign methods as simple procedure pointers, so we save
       lots of Node^.Methods^.GetNext constructs.   RSC 9/20/88
    *)
    LinkedListGetNext := ATreeNodeGetProc(TreeNodeMethodsRecord.GetNext);
    LinkedListGetPrev := ATreeNodeGetProc(TreeNodeMethodsRecord.GetPrev);

END TreeObjects.

