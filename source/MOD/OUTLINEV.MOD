(*V9=DEBUGGING Code*)

IMPLEMENTATION MODULE OutlineViews;        (*  a subclass of ActiveViews  *)

    (* MODIFICATION HISTORY

    15-Jul-87 LAA   Added processing of * keys.
    20-Oct-87 EGK   Merged type-through stuff here from old GoTo module.
    18-Feb-88 EGK   Call ResetMatching during UnInit.
    07-Mar-88 LAA/EGK Don't call ResetMatching during UnInit if the view
                      object is NIL.
    13-Mar-88 LAA   Gave GotoFirst and GotoLast keys the meaning that used to
                    be assigned to PgUp and PgDn, i.e. to move up or down one
                    item at the same level.
    10-Jun-89 WKH   Added support for variable screen rows
    27-Dec-89 LAA   Added MouseDownRegion to the object record definition,
                    so we can limit mouse actions to the screen region on 
                    which the mouse button was originally pressed.  In 
                    ProcessMouseEvent, also added logic such that mouse
                    events outside of the MouseDownRegion are ignored.
    28-Dec-89 LAA   Process mouse events even if the cursor node is zero.
                    This is necessary so that events on the Cancel button 
                    will be recognized for empty lists.
     3-Jan-89 RSC   "OnOk" had been "optimized" out of existance, but is
                    still needed by the Memo list.  I un-commented it.
     5-Jan-90 MWP   Mouse support removed, and various initializations
                    of variables added to InitAsOutlineiew.
     6-Jan-90 LAA   Turned off optimization for procedures which index into,
                    then dereference the SubView array.
    13-Jul-90 PFG/LAA In OutlineViewFindChar, use Upshift instead of CAP.
                    This is for consistency.  The MatchCodeSet is build with
                    Upshift, and the two methods don't always produce the
                    same results, esp. on foreign characters.
     2-Jul-91 AJL   Remove an unused, large string from the Dispatch proc.
    *)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Codes                  IMPORT
    (* TYPE *)                  ASetOfCodes, ACode,
    (* VAR  *)                  EmptyCodeSet,
    (* PROC *)                  SetCodeBits;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Burp, Error;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM ErrorCategories        IMPORT
    (* CONST *)                 NotPossibleInContextError, UnknownEventError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker,
                                GetErrorDetails, PostError, UnPostError;

FROM Helper                 IMPORT
    (* TYPE *)                  AScreenAction,
    (* PROC *)                  GiveHelp;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 AbsoluteMaxRow, maxrow;

FROM KbState                IMPORT
    (* PROC *)                  ScrollMode;

FROM Keys                   IMPORT
    (* CONST *)                 Up, Down, Fwrd, Reverse, HomeKey, EndKey,
                                PromoteKey, DemoteKey, RepeatKey,
                                MoveUpKey, MoveDownKey, OpenKey, CloseKey,
                                GotoFirstKey, GotoLastKey, BackSpace, HelpKey;

FROM ListViews              IMPORT
    (* TYPE *)                  AListView,
    (* PROC *)                  InitAsListView, UnInitAsListView, 
                                CloneListViewMethods;

FROM LStrings               IMPORT
    (* PROC *)                  Compare, SetLengthOf, LengthOf, Upshift, CtoS,
                                SetString;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM ObjectViews            IMPORT
    (* TYPE *)                  AnObjectView;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
                                ATreeNodeAttribute;


CONST
    ModuleNumber            = 15600;

    (*<HIDE/REVEAL    
    TildeKey                = 07EH;
    ApostropheKey           = 060H;
    ExclamationKey          = 021H;
    HIDE/REVEAL>*)


        (*  XOutlineView is a redefinition of AnOutlineView, for the use
            of this module only.
        *)

TYPE
    ANameProc               = PROCEDURE (ATreeNode, ARRAY OF CHAR);
    XOutlineView            = POINTER TO XOutlineViewRecord;


        (*  The beginning of XOutlineViewRecord MUST be identical with that 
            of AListViewRecord.  They MUST be kept in sync.
        *)

    XOutlineViewRecord      = RECORD
                                Methods        : AnOutlineViewMethods;
                                ViewObject     : ATree;
                                ParentView     : AnActiveView;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : AnOutlineViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                 AnActiveView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;       (* 5-Jan-90 LAA *)

                                (* New fields for outline views *)

                                MatchCount          : CARDINAL;
                                MatchString         : ARRAY [0..80] OF CHAR;
                                TypeThroughEnabled  : BOOLEAN;
                                MatchCodeSet        : ASetOfCodes;
                                NameProc            : ANameProc;
                              END;



    ADirection              = (Upward, Downward);




VAR
    OutlineViewMethodsRecord   : AnOutlineViewMethodsRecord;




    (*  These procedures are not called directly, but are used to support
        the methods of this module.
    *)

PROCEDURE ScrollNodes(    OutlineView       : XOutlineView;
                          Direction         : ADirection  )
                                                           : BOOLEAN;

VAR
    i                       : CARDINAL;
    Node                    : ATreeNode;
    Object                  : AnObject;

BEGIN                       (* ScrollNodes *)

    WITH OutlineView^ DO
        IF (Direction = Downward) THEN
            Node := ATreeNode(SubView[1]^.Methods^.GetObject(SubView[1]));
            IF (Node <> NIL) THEN
                Node := Node^.Methods^.PrevForDisplay(Node);
                IF (Node <> NIL) THEN
                    FOR i := Last TO 2 BY -1 DO
                        Object := 
                               SubView[i-1]^.Methods^.GetObject(SubView[i-1]);
                        SubView[i]^.Methods^.SetObject(SubView[i], Object);
                    END;
                    SubView[1]^.Methods^.SetObject(SubView[1], AnObject(Node));

                    RETURN TRUE;
                END;
            END;
        ELSE
            Node := ATreeNode(SubView[Last]^.Methods^.
                                                    GetObject(SubView[Last]));
            IF (Node <> NIL) THEN
                Node := Node^.Methods^.NextForDisplay(Node);
                IF (Node <> NIL) THEN
                    FOR i := 1 TO Last - 1 DO
                        Object := 
                           SubView[i + 1]^.Methods^.GetObject(SubView[i + 1]);
                        SubView[i]^.Methods^.SetObject(SubView[i], Object);
                    END;
                    SubView[Last]^.Methods^.
                                     SetObject(SubView[Last], AnObject(Node));

                    RETURN TRUE;
                END;
            END;
        END;
    END;

    RETURN FALSE;

END ScrollNodes;




(*<HIDE/REVEAL

    (*  This procedure is used by the TraverseTree method to make nodes
        visible
    *)

PROCEDURE MakeNodeVisible(VAR Node          : ATreeNode);

BEGIN                       (* MakeNodeVisible *)

    Node^.Methods^.SetVisible(Node, TRUE);

END MakeNodeVisible;

HIDE/REVEAL>*)






    (*  These procedures implement the methods which are used to override
        methods of ListViews.
    *)

PROCEDURE OutlineViewActOn(    OutlineView  : XOutlineView;
                               Event        : AnEvent;
                           VAR ReturnEvent  : AnEvent     );

VAR
    ErrorMarker             : AnErrorMarker;
    WantToRecord            : BOOLEAN;
    s                       : ARRAY [0..9] OF CHAR;


    PROCEDURE RespondToErrors(    ErrorMarker : AnErrorMarker);

    VAR
        Category                : CARDINAL;
        Code                    : CARDINAL;
        i                       : CARDINAL;
        s                       : ARRAY [0..255] OF CHAR;

    BEGIN                   (* RespondToErrors *)

        i := 0;
        REPEAT
            GetErrorDetails(ErrorMarker, i, Category, Code);
            IF ((Category = NotPossibleInContextError) OR 
               (Category = UnknownEventError)) THEN
                Burp();
            ELSIF (Category <> 0) THEN
                (* Call WhatTheHell here *)
                GetMessage(Code, s);
                Error(s);
            END;
            INC(i);
        UNTIL (Category = 0);

    END RespondToErrors;



    PROCEDURE DoHomeKey();

    VAR
        CNode               : ATreeNode;
        PNode               : ATreeNode;

    BEGIN                   (* DoHomeKey *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            PNode := CNode^.Methods^.Parent(CNode);
            IF (PNode <> NIL) AND (PNode^.Methods^.Visible(PNode)) THEN
                SetCursorNode(AnOutlineView(OutlineView), PNode);
            ELSE
                PNode := CNode^.Methods^.FirstVisibleCoNode(CNode);
                IF (CNode = PNode) THEN
                    PostError(NotPossibleInContextError, ModuleNumber + 6);
                ELSE
                    SetCursorNode(AnOutlineView(OutlineView), PNode);
                END;
            END;
        END;

    END DoHomeKey;



    PROCEDURE DoGotoFirst();

    VAR
        Tree                : ATree;
        FNode               : ATreeNode;

    BEGIN                   (* DoGotoFirst *)

        WITH OutlineView^.Methods^ DO
            Tree := ATree(GetObject(AnOutlineView(OutlineView)));
            FNode := Tree^.Methods^.GetFirstVisible(Tree);
            IF (FNode = GetCursorNode(AnOutlineView(OutlineView))) THEN
                PostError (NotPossibleInContextError, ModuleNumber + 2);
            ELSE
                SetCursorNode(AnOutlineView(OutlineView), FNode);
            END;
        END;

    END DoGotoFirst;



    PROCEDURE DoEndKey();

    VAR
        CNode               : ATreeNode;
        Subtree             : ATree;
        TNode               : ATreeNode;

    BEGIN                   (* DoEndKey *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            TNode := CNode^.Methods^.LastVisibleCoNode(CNode);
            IF (CNode = TNode) THEN
                Subtree := CNode^.Methods^.GetSubtree(CNode);
                IF ((Subtree <> NIL) AND (CNode^.Methods^.ChildrenVisible(CNode))) THEN
                    TNode := Subtree^.Methods^.GetLastVisible(Subtree);
                    IF (TNode <> NIL) THEN
                        SetCursorNode(AnOutlineView(OutlineView), TNode);
                        RETURN;
                    END;
                END;
                PostError(NotPossibleInContextError, ModuleNumber + 5);
            ELSE
                SetCursorNode(AnOutlineView(OutlineView), TNode);
            END;
        END;

    END DoEndKey;



    PROCEDURE DoGotoLast();

    VAR
        Tree                : ATree;
        FNode               : ATreeNode;

    BEGIN                   (* DoGotoLast *)

        WITH OutlineView^.Methods^ DO
            Tree := ATree(GetObject(AnOutlineView(OutlineView)));
            FNode := Tree^.Methods^.GetLastVisible(Tree);
            WHILE (FNode^.Methods^.NextForDisplay(FNode) <> NIL) DO
                FNode := FNode^.Methods^.NextForDisplay(FNode);
            END;
            SetCursorNode(AnOutlineView(OutlineView), FNode);
        END;

    END DoGotoLast;





    PROCEDURE DoDemoteKey();

    VAR
        CNode               : ATreeNode;
        SNode               : ATreeNode;

    BEGIN                   (* DoDemoteKey *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            SNode := CNode^.Methods^.GetPrevVisible(CNode);
            IF (SNode <> NIL) THEN
                CNode^.Methods^.DeList(CNode);
                SNode^.Methods^.AddAsLastChild(SNode, CNode);
                SNode^.Methods^.SetChildrenVisible(SNode, TRUE);
                Synchronize(AnOutlineView(OutlineView));
                SetCursorNode(AnOutlineView(OutlineView), CNode);
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 4);
            END;
        END;

    END DoDemoteKey;



    PROCEDURE DoPromoteKey();

    VAR
        CNode               : ATreeNode;
        PNode               : ATreeNode;

    BEGIN                   (* DoPromoteKey *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            PNode := CNode^.Methods^.Parent(CNode);
            IF ((PNode <> NIL) AND (PNode^.Methods^.Visible(PNode))) THEN
                CNode^.Methods^.DeList(CNode);
                PNode^.Methods^.AddAfter(PNode, CNode);
                Synchronize(AnOutlineView(OutlineView));
                SetCursorNode(AnOutlineView(OutlineView), CNode);
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 3);
            END;
        END;

    END DoPromoteKey;


    PROCEDURE DoMoveUp();

    VAR
        CNode               : ATreeNode;
        SNode               : ATreeNode;

    BEGIN                   (* DoMoveUp *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            SNode := CNode^.Methods^.GetPrevVisible(CNode);
            IF (SNode <> NIL) THEN
                CNode^.Methods^.DeList(CNode);
                SNode^.Methods^.AddBefore(SNode, CNode);
                Synchronize(AnOutlineView(OutlineView));
                SetCursorNode(AnOutlineView(OutlineView), CNode);
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 2);
            END;
        END;

    END DoMoveUp;



    PROCEDURE DoMoveDown();

    VAR
        CNode               : ATreeNode;
        SNode               : ATreeNode;

    BEGIN                   (* DoMoveDown *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            SNode := CNode^.Methods^.GetNextVisible(CNode);
            IF (SNode <> NIL) THEN
                CNode^.Methods^.DeList(CNode);
                SNode^.Methods^.AddAfter(SNode, CNode);
                IF (OutlineView^.Cursor = 1) THEN
                    SetFirst(AnOutlineView(OutlineView), SNode);
                ELSE
                    Synchronize(AnOutlineView(OutlineView));
                END;
                SetCursorNode(AnOutlineView(OutlineView), CNode);
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 1);
            END;
        END;

    END DoMoveDown;




    PROCEDURE DoChildrenVisible(    Visible : BOOLEAN);

    VAR
        CNode               : ATreeNode;

    BEGIN                   (* DoChildrenVisible *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            CNode^.Methods^.SetChildrenVisible(CNode, Visible);
            Synchronize(AnOutlineView(OutlineView));
            SetCursorNode(AnOutlineView(OutlineView), CNode);
        END;

    END DoChildrenVisible;



    PROCEDURE DoAllChildrenVisible(    Visible : BOOLEAN);

    VAR
        CNode               : ATreeNode;
        CLevel              : CARDINAL;
        NLevel              : CARDINAL;
        CursorNode          : ATreeNode;

    BEGIN                   (* DoAllChildrenVisible *)

        WITH OutlineView^.Methods^ DO
            CursorNode := GetCursorNode(AnOutlineView(OutlineView));
            CNode := CursorNode;
            CLevel := CNode^.Methods^.IndentationLevel(CNode);
            LOOP
                CNode^.Methods^.SetChildrenVisible(CNode, Visible);
                CNode := CNode^.Methods^.NextPreOrder(CNode);
                IF (CNode = NIL) THEN
                    EXIT;
                END;
                NLevel := CNode^.Methods^.IndentationLevel(CNode);
                IF (NLevel <= CLevel) THEN
                    EXIT;
                END;
            END;

            Synchronize(AnOutlineView(OutlineView));
            SetCursorNode(AnOutlineView(OutlineView), CursorNode);
        END;

    END DoAllChildrenVisible;



    PROCEDURE DoEverythingVisible(    Visible : BOOLEAN);

    VAR
        Node                : ATreeNode;
        CNode               : ATreeNode;
        Tree                : ATree;

    BEGIN                   (* DoEverythingVisible *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            IF (NOT Visible) THEN
                WHILE (CNode^.Methods^.Parent(CNode) <> NIL) DO
                    CNode := CNode^.Methods^.Parent(CNode);
                END;
            END;
            Tree := CNode^.Methods^.GetRoot(CNode);
            Node := Tree^.Methods^.GetFirstVisible(Tree);
            WHILE (Node <> NIL) DO
                SetCursorNode(AnOutlineView(OutlineView), Node);
                DoAllChildrenVisible(Visible);
                Node := Node^.Methods^.GetNextVisible(Node);
            END;
            SetCursorNode(AnOutlineView(OutlineView), CNode);
        END;

    END DoEverythingVisible;



    PROCEDURE DoUpKey();

    VAR
        Node                : ATreeNode;

    BEGIN                   (* DoUpKey *)

        WITH OutlineView^ DO
            Node := ATreeNode(Methods^.GetCursorNode(AnOutlineView(OutlineView)));
            IF (Node <> NIL) THEN
                Node := Node^.Methods^.PrevForDisplay(Node);
                IF (Node <> NIL) THEN
                    IF ((Cursor = 1) OR ScrollMode()) THEN
                        IF (NOT ScrollNodes(OutlineView, Downward)) THEN
                            PostError(NotPossibleInContextError,ModuleNumber+1);
                            RETURN;
                        END;
                    END;
                    Methods^.SetCursorNode(AnOutlineView(OutlineView), Node);
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 5);
                END;
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 3);
            END;
        END;

    END DoUpKey;


    PROCEDURE DoDownKey();

    VAR
        Node                : ATreeNode;
        LastNode            : ATreeNode;
        CNode               : ATreeNode;

    BEGIN                   (* DoDownKey *)

        WITH OutlineView^ DO
            CNode := (Methods^.GetCursorNode(AnOutlineView(OutlineView)));
            IF (CNode <> NIL) THEN
                Node := CNode^.Methods^.NextForDisplay(CNode);
                IF (Node <> NIL) THEN
                    LastNode := Methods^.GetLast(AnOutlineView(OutlineView));
                    IF ((CNode = LastNode) OR ScrollMode()) THEN
                        IF (NOT ScrollNodes(OutlineView, Upward)) THEN
                            PostError(NotPossibleInContextError,ModuleNumber+2);
                            RETURN;
                        END;
                    END;
                    Methods^.SetCursorNode(AnOutlineView(OutlineView), Node);
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 6);
                END;
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 4);
            END;
        END;

    END DoDownKey;





    PROCEDURE DoPgUpKey();

    VAR
        Node                : ATreeNode;
        CNode               : ATreeNode;

    BEGIN                   (* DoPgUpKey *)

        WITH OutlineView^ DO
            CNode := Methods^.GetCursorNode(AnOutlineView(OutlineView));
            IF (CNode <> NIL) THEN
                Node := CNode^.Methods^.GetPrevVisible(CNode);
                IF (Node = NIL) THEN
                    Node := CNode^.Methods^.PrevForDisplay(CNode);
                END;
                IF (Node <> NIL) THEN
                    IF ((Cursor = 1) OR ScrollMode()) THEN
                        IF (NOT ScrollNodes(OutlineView, Downward)) THEN
                            PostError(NotPossibleInContextError,ModuleNumber+1);
                            RETURN;
                        END;
                    END;
                    Methods^.SetCursorNode(AnOutlineView(OutlineView), Node);
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 3);
                END;
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 3);
            END;
        END;

    END DoPgUpKey;


    PROCEDURE DoPgDnKey();

    VAR
        Node                : ATreeNode;
        LastNode            : ATreeNode;
        CNode               : ATreeNode;

    BEGIN                   (* DoPgDnKey *)

        WITH OutlineView^ DO
            CNode := Methods^.GetCursorNode(AnOutlineView(OutlineView));
            IF (CNode <> NIL) THEN
                Node := CNode^.Methods^.GetNextVisible(CNode);
                IF (Node = NIL) THEN
                    REPEAT
                        CNode := CNode^.Methods^.Parent(CNode);
                        IF (CNode <> NIL) THEN
                            Node := CNode^.Methods^.GetNextVisible(CNode);
                        END;
                    UNTIL ((Node <> NIL) OR (CNode = NIL));
                END;
                IF (Node <> NIL) THEN
                    LastNode := Methods^.GetLast(AnOutlineView(OutlineView));
                    IF ((CNode = LastNode) OR ScrollMode()) THEN
                        IF (NOT ScrollNodes(OutlineView, Upward)) THEN
                            PostError(NotPossibleInContextError,ModuleNumber+2);
                            RETURN;
                        END;
                    END;
                    Methods^.SetCursorNode(AnOutlineView(OutlineView), Node);
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 6);
                END;
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 4);
            END;
        END;

    END DoPgDnKey;





    PROCEDURE DoGotoTop();

    VAR
        Node                : ATreeNode;

    BEGIN                   (* DoGotoTop *)

        WITH OutlineView^.Methods^ DO
            Node := GetCursorNode(AnOutlineView(OutlineView));
            IF (Node <> NIL) THEN
                WHILE (Node <> NIL) DO
                    Node := Node^.Methods^.GetPrevVisible(Node);
                    IF (Node <> NIL) THEN
                        IF ((OutlineView^.Cursor = 1) OR ScrollMode()) THEN
                            IF (NOT ScrollNodes(OutlineView, Downward)) THEN
                                PostError(NotPossibleInContextError,ModuleNumber+1);
                                RETURN;
                            END;
                        END;
                        SetCursorNode(AnOutlineView(OutlineView), Node);
                    END;
                END;
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 3);
            END;
        END;

    END DoGotoTop;




    PROCEDURE DoGotoBottom();

    VAR
        Node                : ATreeNode;
        NNode               : ATreeNode;

    BEGIN                   (* DoGotoBottom *)

        WITH OutlineView^.Methods^ DO
            Node := GetCursorNode(AnOutlineView(OutlineView));
            IF (Node <> NIL) THEN
                WHILE (Node <> NIL) DO
                    NNode := Node^.Methods^.GetNextVisible(Node);
                    IF (NNode <> NIL) THEN
                        IF ((Node = GetLast(AnOutlineView(OutlineView))) 
                           OR ScrollMode()) THEN
                            IF (NOT ScrollNodes(OutlineView, Upward)) THEN
                                PostError(NotPossibleInContextError,ModuleNumber+2);
                                RETURN;
                            END;
                        END;
                        SetCursorNode(AnOutlineView(OutlineView), NNode);
                    END;
                    Node := NNode;
                END;
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 4);
            END;
        END;

    END DoGotoBottom;





(*<HIDE/REVEAL

    PROCEDURE DoHideSelf();

    VAR
        CNode               : ATreeNode;
        SNode               : ATreeNode;
        TNode               : ATreeNode;
        Tree                : ATree;

    BEGIN                   (* DoHideSelf *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            SNode := CNode^.Methods^.PrevForDisplay(CNode);
            Tree := CNode^.Methods^.GetList(CNode);
            CNode^.Methods^.SetVisible(CNode, FALSE);
            IF (SNode = NIL) THEN
                SNode := Tree^.Methods^.GetFirstVisible(Tree);
            ELSE
                TNode := SNode^.Methods^.NextForDisplay(SNode);
                IF (TNode <> NIL) THEN
                    SNode := TNode;
                END;
            END;
            IF (SNode <> NIL) THEN
                IF (CNode = GetFirst(AnOutlineView(OutlineView))) THEN
                    SetFirst(AnOutlineView(OutlineView), SNode);
                ELSE
                    Synchronize(AnOutlineView(OutlineView));
                END;
                SetCursorNode(AnOutlineView(OutlineView), SNode);
            ELSE
                CNode^.Methods^.SetVisible(CNode, TRUE);
            END;
        END;

    END DoHideSelf;


    PROCEDURE DoRevealChildrenDammit();

    VAR
        CNode               : ATreeNode;
        SubTree             : ATree;

    BEGIN                   (* DoRevealChildrenDammit *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            DoChildrenVisible(TRUE);
            SubTree := CNode^.Methods^.GetSubtree(CNode);
            IF (SubTree <> NIL) THEN
                SubTree^.Methods^.TraverseTree(SubTree, ParentBeforeChild,
                                               1, MakeNodeVisible);
            Synchronize(AnOutlineView(OutlineView));
            END;
        END;

    END DoRevealChildrenDammit;



    PROCEDURE DoRevealAllAtLevel();

    VAR
        CNode               : ATreeNode;
        Tree                : ATree;

    BEGIN                   (* DoRevealAllAtLevel *)

        WITH OutlineView^.Methods^ DO
            CNode := GetCursorNode(AnOutlineView(OutlineView));
            Tree := CNode^.Methods^.GetList(CNode);
            Tree^.Methods^.TraverseTree(Tree, ParentBeforeChild, 1,
                                        MakeNodeVisible);
            Synchronize(AnOutlineView(OutlineView));
            SetCursorNode(AnOutlineView(OutlineView), CNode);
        END;

    END DoRevealAllAtLevel;

HIDE/REVEAL>*)



    PROCEDURE Dispatch(    Code             : ACode);

    VAR
        Repeat              : BOOLEAN;

    BEGIN                   (* Dispatch *)

        Repeat := OutlineView^.EventHistory[0].EventCode = RepeatKey;

        CASE Code OF
            HomeKey :
                IF (Repeat) THEN
                    DoGotoFirst();
                ELSE
                    DoHomeKey();
                END;
        |   EndKey :
                DoEndKey();
                IF (Repeat) THEN
                    REPEAT
                        DoEndKey();
                    UNTIL (ErrorPosted(ErrorMarker));
                    UnPostError(ErrorMarker, 0);
                END;
        |   DemoteKey :
                DoDemoteKey();
        |   PromoteKey :
                DoPromoteKey();
        |   MoveUpKey :
                DoMoveUp();
                IF (Repeat) THEN
                    REPEAT
                        DoMoveUp();
                    UNTIL (ErrorPosted(ErrorMarker));
                    UnPostError(ErrorMarker, 0);
                END;
        |   MoveDownKey :
                DoMoveDown();
                IF (Repeat) THEN
                    REPEAT
                        DoMoveDown();
                    UNTIL (ErrorPosted(ErrorMarker));
                    UnPostError(ErrorMarker, 0);
                END;
        |   OpenKey :
                IF (Repeat) THEN
                    IF (OutlineView^.EventHistory[1].EventCode = RepeatKey) THEN
                        DoEverythingVisible(TRUE);
                    ELSE
                        DoAllChildrenVisible(TRUE);
                    END;
                ELSE
                    DoChildrenVisible(TRUE);
                END;
        |   CloseKey :
                IF (Repeat) THEN
                    IF (OutlineView^.EventHistory[1].EventCode = RepeatKey) THEN
                        DoEverythingVisible(FALSE);
                    ELSE
                        DoAllChildrenVisible(FALSE);
                    END;
                ELSE
                    DoChildrenVisible(FALSE);
                END;
        |   Up :
                IF (Repeat) THEN
                    DoGotoFirst();
                ELSE
                    DoUpKey();
                END;
        |   Down :
                IF (Repeat) THEN
                    DoGotoLast();
                ELSE
                    DoDownKey();
                END;
        |   GotoFirstKey :
                IF (Repeat) THEN
                    DoGotoTop();
                ELSE
                    DoPgUpKey();
                END;
        |   GotoLastKey :
                IF (Repeat) THEN
                    DoGotoBottom();
                ELSE
                    DoPgDnKey();
                END;

        (*<HIDE/REVEAL
        |   TildeKey :
                DoHideSelf();
        |   ApostropheKey :
                DoRevealAllAtLevel();
        |   ExclamationKey :
                DoRevealChildrenDammit();
        HIDE/REVEAL>*)
        END;

    END Dispatch;

BEGIN                       (* OutlineViewActOn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(OutlineView));
    END;
    DEBUGGING>*)

    WITH OutlineView^ DO
        ErrorMarker := NewMarker();

        ReturnEvent := Event;
        ReturnEvent.EventCode := 0;
        WantToRecord := FALSE;

        IF (Event.EventCode > 255) OR (NOT OutlineView^.Methods^.FindChar
                (AnOutlineView(OutlineView), CHR(Event.EventCode))) THEN

            CASE Event.EventCode OF

                (*<HIDE/REVEAL
                TildeKey, ApostropheKey, ExclamationKey,
                HIDE/REVEAL>*)

                HomeKey, EndKey, DemoteKey, PromoteKey, MoveUpKey, MoveDownKey,
                OpenKey, CloseKey, Down, Up, GotoFirstKey, GotoLastKey :
                    WantToRecord := TRUE;
                    IF (Methods^.GetCursorNode(AnOutlineView(OutlineView)) <> NIL) THEN
                        Dispatch(Event.EventCode);
                    ELSE
                        PostError(NotPossibleInContextError, ModuleNumber + 7);
                    END;

            |   HelpKey :                                         (* 04-Mar-88 LAA *)
                    IF (HelpNumber = 0) THEN
                        CtoS(ModuleNumber, s);
                    ELSE
                        CtoS(HelpNumber, s);
                    END;
                    GiveHelp(s, 0, maxrow, RestoreTheScreen);

            ELSE
                WITH OutlineViewMethodsRecord.SuperclassMethods^ DO
                    ActOnEvent(AListView(OutlineView), Event, ReturnEvent);
                END;
            END;
        END;
        IF (WantToRecord) THEN
            Methods^.RecordEvent(AnOutlineView(OutlineView), Event);
        END;
        IF (ErrorPosted(ErrorMarker)) THEN
            RespondToErrors(ErrorMarker);
        END;
        PopToMarker(ErrorMarker);
    END;

END OutlineViewActOn;




PROCEDURE OutlineViewResetMatching  (OutlineView        : XOutlineView);
VAR
    Node            : ATreeNode;
    Name            : ARRAY [0..80] OF CHAR;
BEGIN

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(OutlineView));
    END;
    (*DEBUGGING>*)

    WITH OutlineView^ DO
        IF ((NOT TypeThroughEnabled) OR (ViewObject = NIL)) THEN  (* 07-Mar-88 LAA *)
            RETURN;
        END;
        MatchCodeSet := EmptyCodeSet;
        Node := ViewObject^.Methods^.GetFirst (ViewObject);
        WHILE (Node <> NIL) DO
            Node^.Methods^.SetAttributeBit (Node, TypeThroughEnable, FALSE);
            NameProc (Node, Name);
            Upshift (Name);
            IF (LengthOf(Name) > 0) THEN
                SetCodeBits (MatchCodeSet, ORD(Name[1]), ORD(Name[1]), TRUE);
            END;
            IF (Node^.Methods^.ChildrenVisible (Node)) THEN
                Node := Node^.Methods^.NextPreOrder (Node);
            ELSE
                Node := Node^.Methods^.GetNext (Node);
            END;
        END;
        MatchCount := 0;
        SetLengthOf (MatchString, 0);
    END;

END OutlineViewResetMatching;




PROCEDURE OutlineViewGetCount   (OutlineView    : XOutlineView)
                                                                : CARDINAL;

BEGIN

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(OutlineView));
    END;
    DEBUGGING>*)

    RETURN OutlineView^.MatchCount;

END OutlineViewGetCount;





PROCEDURE OutlineViewFindChar   (OutlineView    : XOutlineView;
                                 MatchChar      : CHAR         )
                                                                : BOOLEAN;
CONST
    BitsPerBitSet   = 16;
VAR
    Code            : ACode;
    Node            : ATreeNode;
    OldCursorNode   : ATreeNode;
    ParentNode      : ATreeNode;
    Result          : CARDINAL;
    Name            : ARRAY [0..80] OF CHAR;
    Found           : BOOLEAN;
    Backup          : BOOLEAN;
    FirstKey        : BOOLEAN;

BEGIN

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(OutlineView));
    END;
    DEBUGGING>*)

    WITH OutlineView^ DO
        IF (NOT TypeThroughEnabled) OR
                (LengthOf(MatchString) = HIGH(MatchString)) THEN
            RETURN FALSE;
        END;

        SetString( Name, MatchChar );                          (* 13-Jul-90 *)
        Upshift( Name);
        Code := ORD( Name[1] );
        IF NOT ((Code MOD BitsPerBitSet) IN
                MatchCodeSet[Code DIV BitsPerBitSet]) THEN
            RETURN FALSE;
        END;
        MatchCodeSet := EmptyCodeSet;

        Backup := (Code = BackSpace);
        FirstKey := (MatchCount = 0);

        IF (Backup) THEN
            DEC (MatchCount);
        ELSE
            INC (MatchCount);
            MatchString[MatchCount] := MatchChar;
        END;
        SetLengthOf (MatchString, MatchCount);
        Upshift (MatchString);

        IF (Backup) THEN
            Node := ViewObject^.Methods^.GetFirst (ViewObject);
        ELSE
            Node := ViewObject^.Methods^.GetFirstVisible (ViewObject);
        END;

        OldCursorNode := Methods^.GetCursorNode (AnOutlineView(OutlineView));
        Found := FALSE;
        WHILE (Node <> NIL) DO
            IF (FirstKey) THEN
                Node^.Methods^.SetAttributeBit (Node, TypeThroughEnable, TRUE);
            ELSIF (Backup) AND (MatchCount = 0) THEN
                Node^.Methods^.SetAttributeBit (Node, TypeThroughEnable, FALSE);
            END;
            NameProc (Node, Name);
            Upshift (Name);
            Result := ABS (Compare (MatchString, Name));
            IF (Result > MatchCount) THEN
                SetCodeBits (MatchCodeSet, ORD(Name[Result]), ORD(Name[Result]), TRUE);
            END;
            IF (Result = 0) OR (Result > MatchCount) THEN
                Node^.Methods^.SetAttributeBit (Node, SelfMatch, TRUE);
                Found := TRUE;
                ParentNode := Node^.Methods^.Parent (Node);
                WHILE (ParentNode <> NIL) DO
                    ParentNode^.Methods^.SetAttributeBit (ParentNode, ChildrenMatch, TRUE);
                    ParentNode := ParentNode^.Methods^.Parent (ParentNode);
                END;
            ELSE
                Node^.Methods^.SetAttributeBit (Node, SelfMatch, FALSE);
                Node^.Methods^.SetAttributeBit (Node, ChildrenMatch, FALSE);
            END;
            IF (Backup) THEN
                Node := Node^.Methods^.NextPreOrder (Node);
            ELSE
                Node := Node^.Methods^.NextForDisplay (Node);
            END;
        END;

        Node := ViewObject^.Methods^.GetFirstVisible (ViewObject);
        OutlineView^.Methods^.SetFirst (AnOutlineView(OutlineView), Node);

        (* Now try to find a node to set the cursor on *)

        IF (MatchCount > 0) THEN
            WHILE (NOT Node^.Methods^.TestAttributeBit (Node, SelfMatch)) DO
                Node := Node^.Methods^.NextForDisplay (Node);
            END;
        END;

        IF (Backup) THEN
            Node := OldCursorNode;
        END;
        OutlineView^.Methods^.SetCursorNode (AnOutlineView(OutlineView), Node);

        IF (Found) AND (MatchCount > 0) THEN
            SetCodeBits (MatchCodeSet, BackSpace, BackSpace, TRUE);
        END;

    END;
    RETURN Found;
END OutlineViewFindChar;





PROCEDURE DummyNameProc ( Node : ATreeNode; VAR s : ARRAY OF CHAR );
BEGIN
    FatalError ();
END DummyNameProc;


(*----------------------------------------------------------------------------
    InitAsOutlineView --

    Initialize the indicated object as an outline view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid outline view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsOutlineView(    OutlineView : AnOutlineView;
                                SuperView   : AnActiveView;
                                Ulx         : ascreenx;
                                Uly         : ascreeny;
                                Lrx         : ascreenx;
                                Lry         : ascreeny;
                                Box         : ABoxType;
                                VideoMode   : avidmode;
                            VAR Title       : ARRAY OF CHAR;
                                HelpKey     : CARDINAL;
                                TakeRug     : BOOLEAN      );

VAR
    PrivateOutlineView      : XOutlineView;

BEGIN                       (* InitAsOutlineView *)

    InitAsListView(AListView(OutlineView), AnObjectView(SuperView), Ulx, 
                   Uly, Lrx, Lry, Box, VideoMode, Title, HelpKey, TakeRug);
                     
    PrivateOutlineView := XOutlineView(OutlineView);
    WITH PrivateOutlineView^ DO
        Methods := ADR(OutlineViewMethodsRecord);
        TypeThroughEnabled := FALSE;
        MatchCount := 0;
        MatchCodeSet := EmptyCodeSet;                             (* 5-Jan-90 MWP *)
        SetLengthOf ( MatchString, 0 );
        NameProc := ANameProc(DummyNameProc);
    END;

END InitAsOutlineView;


(*----------------------------------------------------------------------------
    CreateOutlineView --

    Allocate storage for, and initialize the indicated object as an outline
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid outline view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateOutlineView(VAR OutlineView : AnOutlineView;
                                SuperView   : AnActiveView;
                                Ulx         : ascreenx;
                                Uly         : ascreeny;
                                Lrx         : ascreenx;
                                Lry         : ascreeny;
                                Box         : ABoxType;
                                VideoMode   : avidmode;
                            VAR Title       : ARRAY OF CHAR;
                                HelpKey     : CARDINAL;
                                TakeRug     : BOOLEAN      ) 
                                                            : BOOLEAN;

BEGIN                       (* CreateOutlineView *)

    IF (HeapAvailable()) THEN
        ALLOCATE(OutlineView, TSIZE(XOutlineViewRecord));
        InitAsOutlineView(OutlineView, SuperView, Ulx, Uly, Lrx, Lry, Box, 
                          VideoMode, Title, HelpKey, TakeRug);

        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateOutlineView;








(*----------------------------------------------------------------------------
    UnInitAsOutlineView --

    UnInitialize the indicated object as an outline view.

    Preconditions:
        The object will be a valid outline view object. 

    Postconditions:
        Whatever was done by InitAsOutlineView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsOutlineView(    OutlineView : AnOutlineView);

BEGIN                       (* UnInitAsOutlineView *)

    OutlineView^.Methods^.ResetMatching (OutlineView);  (* 18-Feb-88  EGK *)
    UnInitAsListView(AListView(OutlineView));

END UnInitAsOutlineView;







(*----------------------------------------------------------------------------
    CloneOutlineViewMethods --

    Make a copy of the outline view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The outline view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneOutlineViewMethods(    MethodObject : AnOutlineViewMethods);

BEGIN                       (* CloneOutlineViewMethods *)

    MethodObject^ := OutlineViewMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(OutlineViewMethodsRecord);

END CloneOutlineViewMethods;







(*----------------------------------------------------------------------------
    ValidateOutlineView --

    Determine that the indicated object is in fact a valid outline view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid outline view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateOutlineView(    OutlineView : AnOutlineView);

VAR
    PrivateOutlineView      : XOutlineView;

BEGIN                       (* ValidateOutlineView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(OutlineView));
    END;
    DEBUGGING>*)

    PrivateOutlineView := XOutlineView(OutlineView);
    IF (PrivateOutlineView^.Methods^.OutlineViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateOutlineView;




BEGIN                       (* OutlineViews *)

    CloneListViewMethods(ADR(OutlineViewMethodsRecord));
    WITH OutlineViewMethodsRecord DO
        MethodSize := TSIZE(AnOutlineViewMethodsRecord);
        ActOnEvent := AnOutlineViewActOnProc(OutlineViewActOn);
        ResetMatching := AnOutlineViewResetCountProc(OutlineViewResetMatching);
        GetMatchCount := AnOutlineViewGetCountProc(OutlineViewGetCount);
        FindChar := AnOutlineViewFindCharProc(OutlineViewFindChar);
        OutlineViewTag := ModuleNumber;
    END;

END OutlineViews.
