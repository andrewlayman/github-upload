(*V9=DEBUGGING Code*)
IMPLEMENTATION MODULE ListViews;        (*  a subclass of ActiveViews  *)

(*  =========================================================================
    Last Edit : September 5, 1990 5:56PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 


    MODIFICATION HISTORY:

        25-Jun-87 LAA   Changed the effect of Up and Down if Scroll Lock is
                        on.
        30-Jun-87 LAA   Added the SetCursorMode method.
        15-Jul-87 LAA   Added processing for * keys.
        10-Jan-89 RSC   Changed Storage to Space    .
        06-Mar-89 LAA   Changed the meanings of PgUp and Ctrl-PgUp, and PgDn
                        and Ctrl-PgDn.  Now PgUp and PgDn will scroll the
                        list or outline by a full screen (or window) and the
                        ctrl keys will move up by 1 on a list, or by 1 at the
                        same level on an outline.
        10-Jun-89 WKH   Added support for variable screen rows.
        05-Jan-90 LAA   Moved the MouseDownRegion from OutlineViews to here.
        05-Jan-90 MWP   Moved MouseSupport from OutlineViews to here.
        06-Jan-90 LAA   Just a safety check (in MoveToNewSelection).
                        Turned off optimization for procedures which index into,
                        then dereference the SubView array.
        19-Jan-90 MWP   When double clicking on a list selection, we were
                        unconditionally sending an edit command to the
                        appropriate outline processing routine. Now, we
                        check that the row that the double click happened
                        on is a valid row.
        5-Sep-90 PFG    If NeedsRedisplay is set for a goto list, call
                        NotifyOfChange for each SubView so each SubView also
                        gets redisplayed.  This is needed for user-defined
                        column headings.
        6-Oct-90 AJL    Use the CorrelateMouseToCode procedure to allow
                        additional mouse buttons beyond OK and Cancel.
*)


FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView, AnActiveViewMethods, 
    (* PROC *)                  CloneActiveViewMethods, ValidateActiveView,
                                InitAsActiveView, UnInitAsActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType,
                                AMouseClickPoint,                 (* 5-Jan-89 MWP *)
    (* PROC *)                  CorrelateMousePoint, CorrelateMouseToCode;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Burp, Error;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  PushEvent;                       (* 5-Jan-89 MWP *)

FROM ErrorCategories        IMPORT
    (* CONST *)                 NotPossibleInContextError, UnknownEventError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker,
                                GetErrorDetails, PostError, UnPostError;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 AbsoluteMaxRow, maxrow;

FROM KbState                IMPORT
    (* PROC *)                  ScrollMode;

FROM Keys                   IMPORT
    (* CONST *)                 Up, Down, Fwrd, Reverse, HomeKey, EndKey,
                                RepeatKey, PgUpKey, PgDnKey, GotoFirstKey,
                                GotoLastKey, EditKey,
                                DoIt, MouseUp, MouseDouble, MouseDown,  (* 5-Jan-89 MWP *)
                                MouseStillDown, ExitKey, CancelKey;

FROM LinkedListObjects      IMPORT
    (* TYPE *)                  ALinkedList, ALinkedListNode;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, CtoS, ConcatLS;

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
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;


CONST
    ModuleNumber            = 15400;


        (*  XListView is a redefinition of AListView, for the use
            of this module only.
        *)

TYPE
    XListView               = POINTER TO XListViewRecord;


        (*  The beginning of XListViewRecord MUST be identical with that of
            AnActiveViewRecord.  They MUST be kept in sync.
        *)

    XListViewRecord         = RECORD
                                Methods        : AListViewMethods;
                                ViewObject     : ALinkedList;
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
                                Status         : AListViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                 AnActiveView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                              END;


    ADirection              = (Upward, Downward);


VAR
    ListViewMethodsRecord   : AListViewMethodsRecord;






    (*  These procedures are not called directly, but are used to support
        the methods of this module.
    *)

(*$0-*)
PROCEDURE ScrollNodes(    ListView          : XListView;
                          Direction         : ADirection)
                                                         : BOOLEAN;

VAR
    i                       : CARDINAL;
    Node                    : ALinkedListNode;
    Object                  : AnObject;

BEGIN                       (* ScrollNodes *)

    WITH ListView^ DO
        IF (Direction = Downward) THEN
            Node := ALinkedListNode(SubView[1]^.Methods^.GetObject(SubView[1]));
            IF (Node <> NIL) THEN
                Node := Node^.Methods^.PrevForDisplay(Node);
                IF (Node <> NIL) THEN
                    FOR i := Last TO 2 BY -1 DO
                        Object := 
                           SubView[i - 1]^.Methods^.GetObject(SubView[i - 1]);
                        SubView[i]^.Methods^.SetObject(SubView[i], Object);
                    END;
                    SubView[1]^.Methods^.SetObject(SubView[1], AnObject(Node));

                    RETURN TRUE;
                END;
            END;
        ELSE
            Node := ALinkedListNode(SubView[Last]^.Methods^.
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
(*$0=*)





(*$0-*)
PROCEDURE PositionIn(    ListView           : XListView;
                         ListNode           : ALinkedListNode )
                                                               : CARDINAL;

VAR
    i                       : CARDINAL;

BEGIN                       (* PositionIn *)

    WITH ListView^ DO
        FOR i := 1 TO Last DO
            IF (ALinkedListNode(SubView[i]^.Methods^.
                                GetObject(SubView[i])) = ListNode) THEN
                RETURN i;
            END;
        END;
    END;

    RETURN 0;

END PositionIn;
(*$0=*)




(*$0-*)
PROCEDURE MakeNoCursor(    ListView         : XListView);

VAR
    i                       : CARDINAL;

BEGIN                       (* MakeNoCursor *)

    WITH ListView^ DO
        FOR i := 1 TO Last DO
            IF (SubView[i]^.Methods^.GetCursor(SubView[i])) THEN
                SubView[i]^.Methods^.SetCursor(SubView[i], FALSE);
            END;
        END;
        Cursor := 0;
    END;

END MakeNoCursor;
(*$0=*)






    (*  These procedures override methods from Objects  *)

PROCEDURE ListViewDiscard(VAR ListView      : XListView);

BEGIN                       (* ListViewDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(ListView));
    END;
    DEBUGGING>*)

    UnInitAsListView(AListView(ListView));
    DISPOSE(ListView);

END ListViewDiscard;





    (*  These procedures override methods from ObjectViews.  *)


(*$0-*)
PROCEDURE ListViewDisplay(    ListView      : XListView);

VAR
    i                       : CARDINAL;

BEGIN                       (* ListViewDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(ListView));
    END;
    DEBUGGING>*)

    WITH ListView^ DO
        IF (NeedsRedisplay IN Status) THEN
            ListViewMethodsRecord.SuperclassMethods^.
                                              Display(AnActiveView(ListView));
            EXCL(Status, NeedsRedisplay);
            FOR i := 1 TO Last DO           (* 5-Sep-90 PFG  *)
                SubView[i]^.Methods^.NotifyOfChange(SubView[i]);
            END;
        END;

        IF (SubView[1]^.Methods^.GetObject(SubView[1]) = NIL) THEN
            SubView[1]^.Methods^.SetCursor(SubView[1], TRUE);
        END;

        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Display(SubView[i]);
        END;
    END;

END ListViewDisplay;
(*$0=*)








    (*  These procedures implement the methods which are used to override
        methods of ActiveViews.
    *)


PROCEDURE ListViewActOn(    ListView        : XListView;
                            Event           : AnEvent;
                        VAR ReturnEvent     : AnEvent  );

VAR
    Code                    : ACode;
    Node                    : ALinkedListNode;
    LastNode                : ALinkedListNode;
    List                    : ALinkedList;
    WantToRecord            : BOOLEAN;
    ErrorMarker             : AnErrorMarker;
    Repeat                  : BOOLEAN;


    PROCEDURE RespondToErrors(    ErrorMarker : AnErrorMarker);

    VAR
        Category                : CARDINAL;
        Code                    : CARDINAL;
        i                       : CARDINAL;

    BEGIN                   (* RespondToErrors *)

        i := 0;
        REPEAT
            GetErrorDetails(ErrorMarker, i, Category, Code);
            IF ((Category = NotPossibleInContextError) OR 
               (Category = UnknownEventError)) THEN
                Burp();
            ELSIF (Category <> 0) THEN
                (* Call WhatTheHell here *)
            END;
            INC(i);
        UNTIL (Category = 0);

    END RespondToErrors;



    PROCEDURE DoUpKey();

    VAR
        Node                : ALinkedListNode;

    BEGIN                   (* DoUpKey *)

        WITH ListView^ DO
            Node := ALinkedListNode(Methods^.GetCursorNode(AListView(ListView)));
            IF (Node <> NIL) THEN
                Node := Node^.Methods^.GetPrevVisible(Node);
                IF (Node <> NIL) THEN
                    IF ((Cursor = 1) OR ScrollMode()) THEN
                        IF (NOT ScrollNodes(ListView, Downward)) THEN
                            PostError(NotPossibleInContextError,ModuleNumber+1);
                            RETURN;
                        END;
                    END;
                    Methods^.SetCursorNode(AListView(ListView), Node);
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
        Node                : ALinkedListNode;
        LastNode            : ALinkedListNode;
        CNode               : ALinkedListNode;

    BEGIN                   (* DoDownKey *)

        WITH ListView^ DO
            CNode := Methods^.GetCursorNode(AListView(ListView));
            IF (CNode <> NIL) THEN
                Node := CNode^.Methods^.GetNextVisible(CNode);
                IF (Node <> NIL) THEN
                    LastNode := Methods^.GetLast(AListView(ListView));
                    IF ((CNode = LastNode) OR ScrollMode()) THEN
                        IF (NOT ScrollNodes(ListView, Upward)) THEN
                            PostError(NotPossibleInContextError,ModuleNumber+2);
                            RETURN;
                        END;
                    END;
                    Methods^.SetCursorNode(AListView(ListView), Node);
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 6);
                END;
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 4);
            END;
        END;

    END DoDownKey;


    (*$0-*)
    PROCEDURE DoPageDownKey();

    VAR
        i               : CARDINAL;
        Node            : ALinkedListNode;
        NextNode        : ALinkedListNode;

    BEGIN
        WITH ListView^ DO
            Node := SubView[Last]^.Methods^.GetObject(SubView[Last]);
            IF (Node <> NIL) THEN
                NextNode := Node^.Methods^.NextForDisplay(Node);
            ELSE
                NextNode := NIL;
            END;
            IF (NextNode <> NIL) THEN
                i := 2;
                LOOP
                    IF (NextNode = NIL) THEN
                        EXIT;
                    END;
                    Node := NextNode;
                    IF (i >= Last) THEN
                        EXIT;
                    END;
                    NextNode := Node^.Methods^.NextForDisplay(Node);
                    INC(i);
                END;
                FOR i := 1 TO Last - 1 DO
                    Node := Node^.Methods^.PrevForDisplay(Node);
                END;
                Methods^.SetFirst(AListView(ListView), Node);
            ELSE
                Node := Methods^.GetCursorNode (AListView (ListView));
                IF (Node = NIL) OR
                        (Node^.Methods^.NextForDisplay (Node) = NIL) THEN
                    PostError (NotPossibleInContextError, ModuleNumber+2);
                ELSE
                    Node := Methods^.GetLast(AListView(ListView));
                    Methods^.SetCursorNode(AListView(ListView), Node);
                END;
            END;
        END;                    
    END DoPageDownKey;
    (*$0=*)


    (*$0-*)
    PROCEDURE DoPageUpKey();
    VAR
        i               : CARDINAL;
        Node            : ALinkedListNode;
        PrevNode        : ALinkedListNode;

    BEGIN
        WITH ListView^ DO
            Node := SubView[1]^.Methods^.GetObject(SubView[1]);
            IF (Node <> NIL) THEN
                PrevNode := Node^.Methods^.PrevForDisplay(Node);
            ELSE
                PrevNode := NIL;
            END;
            IF (PrevNode <> NIL) THEN
                i := 2;
                LOOP
                    IF (PrevNode = NIL) THEN
                        EXIT;
                    END;
                    Node := PrevNode;
                    IF (i >= Last) THEN
                        EXIT;
                    END;
                    PrevNode := Node^.Methods^.PrevForDisplay(Node);
                    INC(i);
                END;
                Methods^.SetFirst(AListView(ListView), Node);
            ELSE
                Node := Methods^.GetCursorNode (AListView (ListView));
                IF (Node = NIL) OR
                        (Node^.Methods^.PrevForDisplay (Node) = NIL) THEN
                    PostError (NotPossibleInContextError, ModuleNumber+2);
                ELSE
                    Node := Methods^.GetFirst(AListView(ListView));
                    Methods^.SetCursorNode(AListView(ListView), Node);
                END;
            END;
        END;                    
    END DoPageUpKey;
    (*$0=*)


               

    (*$0-*)
    PROCEDURE  MoveToNewSelection ();
    VAR
         SelectedRow             : CARDINAL;
         Node                    : ALinkedListNode;
         
    BEGIN

         WITH ListView^ DO
             IF ( FindSelectedRow ( Event.EventY, SelectedRow ) ) THEN   (* 19-Jan-90 MWP *)
                 Node := ALinkedListNode(SubView[SelectedRow]^.Methods^.GetObject(SubView[SelectedRow]));
             ELSE
                 Node := ALinkedListNode(NIL);
             END;

             IF (Node <> NIL) THEN
                 Methods^.SetCursorNode(AListView(ListView), Node);
             ELSIF (Event.EventCode = MouseDown) THEN
                 PostError(NotPossibleInContextError, ModuleNumber);
             END;
         END;

    END MoveToNewSelection;
    (*$0=*)


    (*$0-*)
    PROCEDURE  FindSelectedRow (     EventY      : CARDINAL;
                                 VAR SelectedRow : CARDINAL ) : BOOLEAN;      (* 19-Jan-90 MWP *)
                                
    VAR
         Node                    : ALinkedListNode;
         LocalUlx                : ascreenx;
         LocalUly                : ascreeny;
         LocalLrx                : ascreenx;
         LocalLry                : ascreeny;

    BEGIN

         Node := NIL;

         WITH ListView^ DO
             Methods^.GetInternalXY  ( AListView(ListView),
                                       LocalUlx, LocalUly, LocalLrx, LocalLry);
             SelectedRow := ( EventY - LocalUly ) + 1;

             IF (SelectedRow <= Last) THEN
                 Node := ALinkedListNode(SubView[SelectedRow]^.Methods^.GetObject(SubView[SelectedRow]));
             END;
         END;

         RETURN (Node <> NIL);

    END FindSelectedRow;
    (*$0=*)


    PROCEDURE ProcessMouseEvent ();
    VAR
        MouseArea           : AMouseClickPoint;
        CNode               : ALinkedListNode;
        LastNode            : ALinkedListNode;
        ScrollDirection     : ADirection;
        LocalEvent          : AnEvent;
        OldCursor           : CARDINAL;
        LocalUlx            : ascreenx;
        LocalUly            : ascreeny;
        LocalLrx            : ascreenx;
        LocalLry            : ascreeny;
        Row                 : CARDINAL;
        LocalCode           : ACode;
    BEGIN

        WITH ListView^ DO
            Methods^.GetExternalXY  ( AListView(ListView),
                                      LocalUlx, LocalUly, LocalLrx, LocalLry);

            MouseArea := CorrelateMousePoint ( LocalUlx, LocalUly, LocalLrx, LocalLry, Box,
                                               Event.EventX, Event.EventY );
            IF (Event.EventCode = MouseDown) THEN              (* 27-Dec-89 *)
                MouseDownRegion := ORD(MouseArea);
            ELSIF (MouseDownRegion <> ORD(MouseArea)) THEN
                    (* Reject any mouse event that was not in the same area
                       as the last mouse down. *)
                RETURN;
            END;
        END;

        CASE MouseArea OF
            OnInside :
               CASE Event.EventCode OF
                   MouseUp, MouseDown, MouseStillDown :
                       MoveToNewSelection ();
               |   MouseDouble :
                       IF ( FindSelectedRow ( Event.EventY, Row ) ) THEN   (* 19-Jan-90 MWP *)
                           LocalEvent := Event;
                           LocalEvent.EventCode := EditKey;
                           PushEvent ( LocalEvent );
                       END;
               ELSE
               END;

         |  OnVScrollUp, OnVScrollDown :
               CASE Event.EventCode OF
                  MouseDown, MouseStillDown :
                       WITH ListView^ DO
                           CNode := Methods^.GetCursorNode(AListView(ListView));
                           OldCursor := ListView^.Cursor;

                           IF (CNode <> NIL) THEN
                                IF ( MouseArea = OnVScrollUp ) THEN
                                   LastNode := Methods^.GetLast(AListView(ListView));
                                   IF ( CNode = LastNode ) THEN
                                      CNode := CNode^.Methods^.PrevForDisplay(CNode);
                                   END;
                                   ScrollDirection := Downward;
                                ELSE
                                   IF ( OldCursor = 1 ) THEN
                                       CNode := CNode^.Methods^.NextForDisplay(CNode);
                                   END;
                                   ScrollDirection := Upward;
                                END;

                                IF ( NOT ScrollNodes(ListView,
                                                     ScrollDirection ) ) THEN
                                   IF (Event.EventCode = MouseDown) THEN
                                      PostError(NotPossibleInContextError,
                                                ModuleNumber+2);
                                   END;
                                ELSE
                                   Methods^.SetCursorNode(AListView(ListView),
                                                          CNode);
                                END;
                           END;
                       END;

               ELSE
               END;

        ELSE  (* Not in the inside, not in the scroll bars. *)
              (* Where was the event? *)
            LocalCode := CorrelateMouseToCode(LocalUlx, LocalUly,
                                              LocalLrx, LocalLry,
                                              ListView^.Box,
                                              Event.EventX, Event.EventY );
            IF (LocalCode <> 0) THEN
                    (* On a button.   Buttons react on mouse up. *)
                IF (Event.EventCode = MouseUp) THEN
                    LocalEvent := Event;
                    LocalEvent.EventCode := LocalCode;
                    PushEvent ( LocalEvent );
                END;
            ELSE
                    (* Not on anything we want a click on. *)
                IF (Event.EventCode = MouseDown) THEN
                    PostError(NotPossibleInContextError, ModuleNumber + 4);
                END;
            END;
        END;

    END ProcessMouseEvent;


BEGIN                       (* ListViewActOn *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(ListView));
    END;
    (*DEBUGGING>*)

    ErrorMarker := NewMarker();

    ReturnEvent := Event;
    ReturnEvent.EventCode := 0;
    WantToRecord := TRUE;
    WITH ListView^ DO
        Repeat := EventHistory[0].EventCode = RepeatKey;

        CASE Event.EventCode OF
            Up, GotoFirstKey :                                    (*  6-Mar-89 LAA *)
                DoUpKey();
                IF (Repeat) THEN
                    REPEAT
                        DoUpKey();
                    UNTIL (ErrorPosted(ErrorMarker));
                    UnPostError(ErrorMarker, 0);
                END;
        |   Down, GotoLastKey :                                   (*  6-Mar-89 LAA *)
                DoDownKey();
                IF (Repeat) THEN
                    REPEAT
                        DoDownKey();
                    UNTIL (ErrorPosted(ErrorMarker));
                    UnPostError(ErrorMarker, 0);
                END;
        |   HomeKey :
                Node := (Methods^.GetCursorNode(AListView(ListView)));
                IF (Node <> NIL) THEN
                    List := Node^.Methods^.GetList(Node);
                    Node := List^.Methods^.GetFirstVisible(List);
                    Methods^.SetFirst(AListView(ListView), Node);
                    Methods^.SetCursorNode(AListView(ListView), Node);
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 5);
                END;
        |   EndKey :
                Node := (Methods^.GetCursorNode(AListView(ListView)));
                IF (Node <> NIL) THEN
                    List := Node^.Methods^.GetList(Node);
                    Node := List^.Methods^.GetLastVisible(List);
                    Methods^.SetFirst(AListView(ListView), Node);
                    Methods^.SetCursorNode(AListView(ListView), Node);
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 5);
                END;
        |   PgDnKey:                                              (*  6-Mar-89 LAA *)
                DoPageDownKey();
                IF (Repeat) THEN
                    REPEAT
                        DoPageDownKey();
                    UNTIL (ErrorPosted(ErrorMarker));
                    UnPostError(ErrorMarker, 0);
                END;
        |   PgUpKey:                                              (*  6-Mar-89 LAA *)
                DoPageUpKey();
                IF (Repeat) THEN
                    REPEAT
                        DoPageUpKey();
                    UNTIL (ErrorPosted(ErrorMarker));
                    UnPostError(ErrorMarker, 0);
                END;

        |   MouseUp, MouseDown, MouseStillDown, MouseDouble :     (* 5-Jan-90 MWP *)
                ProcessMouseEvent ();

        |   RepeatKey :
                ;
        ELSE
            WITH ListViewMethodsRecord.SuperclassMethods^ DO
                ActOnEvent(AnActiveView(ListView), Event, ReturnEvent);
            END;
            WantToRecord := FALSE;
        END;
        IF (WantToRecord) THEN
            Methods^.RecordEvent(AListView(ListView), Event);
        END;
        IF (ErrorPosted(ErrorMarker)) THEN
            RespondToErrors(ErrorMarker);
        END;
        PopToMarker(ErrorMarker);
    END;

END ListViewActOn;








    (*  These procedures implement the methods unique to ListViews  *)

(*----------------------------------------------------------------------------
    SetListViewFirst --

    Define the indicated list node to be the first displayed node within the
    list view.

    Preconditions:
        The list view must be a valid list view object.

    Postconditions:
        The indicated node will be the first one displayed in the list view, 
        if possible.  If the indicated list node is NIL, the list will be 
        assumed to be empty.  This method will cause a re-synchronization of
        the internal list view data structures, so that an entirely different
        set of nodes may be displayed.
----------------------------------------------------------------------------*)

(*$0-*)
PROCEDURE SetListViewFirst(    ListView     : XListView;
                               ListNode     : ALinkedListNode);

VAR
    i                       : CARDINAL;

BEGIN                       (* SetListViewFirst *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(ListView));
    END;
    DEBUGGING>*)

    WITH ListView^ DO
        i := 1;
        LOOP
            IF (i > Last) THEN
                EXIT;
            END;
            SubView[i]^.Methods^.SetObject(SubView[i], AnObject(ListNode));
            IF (ListNode <> NIL) THEN
                ListNode := ListNode^.Methods^.NextForDisplay(ListNode);
            END;
            INC(i);
        END;
        WHILE ((SubView[Last]^.Methods^.GetObject(SubView[Last]) = NIL) 
               AND (ScrollNodes(ListView, Downward))) DO END;
    END;

END SetListViewFirst;
(*$0=*)





(*----------------------------------------------------------------------------
    GetListViewFirst --

    Determine which list node is the first one within the view.

    Preconditions:
        The list view must be a valid list view object.

    Postconditions:
        The first list node within the view will be returned.  This may be
        NIL if the view is of an empty list.
----------------------------------------------------------------------------*)

(*$0-*)
PROCEDURE GetListViewFirst(    ListView     : XListView)
                                                        : ALinkedListNode;

VAR
    NodeView                : AnActiveView;

BEGIN                       (* GetListViewFirst *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(ListView));
    END;
    DEBUGGING>*)

    WITH ListView^ DO
        RETURN SubView[1]^.Methods^.GetObject(SubView[1]);
    END;

END GetListViewFirst;
(*$0=*)







(*----------------------------------------------------------------------------
    GetListViewLast --

    Determine which list node is the last one within the view.

    Preconditions:
        The list view must be a valid list view object.

    Postconditions:
        The last list node within the view will be returned.  This may be
        NIL if the view is of an empty list.
----------------------------------------------------------------------------*)

(*$0-*)
PROCEDURE GetListViewLast(    ListView     : XListView)
                                                       : ALinkedListNode;

VAR
    Node                    : ALinkedListNode;
    i                       : CARDINAL;

BEGIN                       (* GetListViewLast *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(ListView));
    END;
    DEBUGGING>*)

    WITH ListView^ DO
        i := Last;
        REPEAT
            Node := SubView[i]^.Methods^.GetObject(SubView[i]);
            DEC(i);
        UNTIL ((i = 0) OR (Node <> NIL));

        RETURN Node;
    END;

END GetListViewLast;
(*$0=*)







(*----------------------------------------------------------------------------
    SetListViewCursorNode --

    Define the list node which has the cursor on it.

    Preconditions:
        The list view must be a valid list view object.

    Postconditions:
        The indicated list node will be made the cursor node.  If this node 
        is not within the view, the view will be changed, and the cursor node
        placed as close to the center of the view as is possible.  The list
        node may be NIL, in which case there is no displayable cursor.
----------------------------------------------------------------------------*)

(*$0-*)
PROCEDURE SetListViewCursorNode(    ListView : XListView;
                                    ListNode : ALinkedListNode );

VAR
    i                       : CARDINAL;
    j                       : CARDINAL;
    OldCursor               : CARDINAL;

BEGIN                       (* SetListViewCursorNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(ListView));
    END;
    DEBUGGING>*)

    WITH ListView^ DO
        OldCursor := Cursor;
        MakeNoCursor(ListView);
        IF (ListNode <> NIL) THEN
            i := PositionIn(ListView, ListNode);
            IF (i = 0) THEN
                ListView^.Methods^.SetFirst(AListView(ListView), ListNode);
                i := PositionIn(ListView, ListNode);
                IF (OldCursor = 0) THEN
                    IF (i < Last DIV 2) THEN
                        FOR j := 1 TO (Last DIV 2) - i DO
                            IF (ScrollNodes(ListView, Downward)) THEN END;
                        END;
                    END;
                ELSIF (OldCursor > i) THEN
                    FOR j := 1 TO (OldCursor - i) DO
                        IF (ScrollNodes(ListView, Downward)) THEN END;
                    END;
                ELSIF (OldCursor < i) THEN
                    FOR j := 1 TO (i - OldCursor) DO
                        IF (ScrollNodes(ListView, Upward)) THEN END;
                    END;
                END;
                SetListViewCursorNode(ListView, ListNode);
            ELSE
                SubView[i]^.Methods^.SetCursor(SubView[i], TRUE);
                Cursor := i;
            END;    
        END;
    END;

END SetListViewCursorNode;
(*$0=*)






(*----------------------------------------------------------------------------
    GetListViewCursorNode --

    Determine which list node is the current cursor node.

    Preconditions:
        The list view must be a valid list view object.

    Postconditions:
        The current cursor node is returned.  This may be NIL, if there is no
        cursor node.
----------------------------------------------------------------------------*)

(*$0-*)
PROCEDURE GetListViewCursorNode(    ListView : XListView)
                                                         : ALinkedListNode;

VAR
    i                       : CARDINAL;

BEGIN                       (* GetListViewCursorNode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(ListView));
    END;
    DEBUGGING>*)

    WITH ListView^ DO
        IF (Cursor <> 0) THEN
            RETURN SubView[Cursor]^.Methods^.GetObject(SubView[Cursor]);
        END;
    END;

    RETURN NIL;

END GetListViewCursorNode;
(*$0=*)







(*----------------------------------------------------------------------------
    ListViewSynchronize --

    Synchronize the view within the list view with the objects of the list 
    which is being viewed.  This needs to be called if the list has changed,
    but the first node viewed is the same.

    Preconditions:
        The view must be a valid list view, and a first viewed node must have
        been established which is not NIL.

    Postconditions:
        The subviews which have changed because of changes in the list being
        viewed will be marked as needing to be redisplayed.
----------------------------------------------------------------------------*)

PROCEDURE ListViewSynchronize(    ListView  : XListView);

VAR
    Node                    : ALinkedListNode;

BEGIN                       (* ListViewSynchronize *)

    Node := GetListViewFirst(ListView);
    SetListViewFirst(ListView, Node);

END ListViewSynchronize;






(*------------------------------------------------------------------------
    ListViewForce --

    Force the given node to be displayed in the view at the indicated
    position, if at all possible.  Blank lines may be allowed at the
    bottom of the view, but not at the top.  If the position indicated
    is too large, the node will be placed as the last one in the view.

    Preconditions:
        The view must be a valid list view, and the node must be a valid
        linked list node.

    Postconditions:
        The linked list node will be displayed at or above the indicated
        position with the list view.
------------------------------------------------------------------------*)

(*$0-*)
PROCEDURE ListViewForce(    ListView        : XListView;
                            Node            : ALinkedListNode;
                            Position        : CARDINAL       );

VAR
    i                       : CARDINAL;
    CNode                   : ALinkedListNode;

BEGIN                       (* ListViewForce *)

    WITH ListView^ DO
        CNode := Methods^.GetCursorNode(AListView(ListView));

        i := 1;
        LOOP
            IF (i > Last) THEN
                EXIT;
            END;
            SubView[i]^.Methods^.SetObject(SubView[i], AnObject(Node));
            IF (Node <> NIL) THEN
                Node := Node^.Methods^.NextForDisplay(Node);
            END;
            INC(i);
        END;

        i := 1;
        LOOP
            IF (i > Position - 1) THEN
                EXIT;
            END;
            IF (NOT ScrollNodes(ListView, Downward)) THEN
                EXIT;
            END;
            INC(i);
        END;

        MakeNoCursor(ListView);
        i := PositionIn(ListView, CNode);
        IF (i <> 0) THEN
            SubView[i]^.Methods^.SetCursor(SubView[i], TRUE);
            Cursor := i;
        END;
    END;

END ListViewForce;
(*$0=*)






(*------------------------------------------------------------------------
    Determine the position in this view of the indicated node.  If the
    node is not in the view, zero will be returned.

    Preconditions:
        The view must be a valid list view, and the node must be a valid
        linked list node.

    Postconditions:
        The position of the node in the view (or zero) will be returned.
------------------------------------------------------------------------*)

(*$0-*)
PROCEDURE ListViewInquire(    View          : XListView;
                              Node          : ALinkedListNode)
                                                              : CARDINAL;

VAR
    i                       : CARDINAL;

BEGIN                       (* ListViewInquire *)

    WITH View^ DO
        FOR i := 1 TO Last DO
            IF (SubView[i]^.Methods^.GetObject(SubView[i]) = Node) THEN
                RETURN i;
            END;
        END;
    END;

    RETURN 0;

END ListViewInquire;
(*$0=*)




PROCEDURE ListViewNotifyDeleted(     ListView : XListView;
                                     Node     : ALinkedListNode);
VAR
    List                : ALinkedList;
    TempNode            : ALinkedListNode;

BEGIN                       (* ListViewNotifyDeleted *)

    WITH ListView^ DO
        IF (Node = Methods^.GetFirst(AListView(ListView))) THEN
            List := ListView^.Methods^.GetObject(AListView(ListView));
            TempNode := List^.Methods^.GetFirst(List);
            IF (Node = TempNode) THEN
                TempNode := TempNode^.Methods^.NextForDisplay(TempNode);
            END;
            Methods^.SetFirst(AListView(ListView), TempNode);
        ELSE
            Methods^.Synchronize(AListView(ListView));
        END;
    END;

END ListViewNotifyDeleted;


(*$0-*)
PROCEDURE ListViewSetMode(    ListView      : XListView;          (* 30-Jun-87 LAA *)
                              VidMode       : avidmode );

VAR
    i                       : CARDINAL;

BEGIN                       (* ListViewSetMode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateListView(AListView(ListView));
    END;
    DEBUGGING>*)

    WITH ListView^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.SetCursorMode(SubView[i], VidMode);
        END;
        CursorMode := VidMode;
    END;

END ListViewSetMode;
(*$0=*)




(*----------------------------------------------------------------------------
    InitAsListView --

    Initialize the indicated object as a list view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid list view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsListView(    ListView       : AListView;
                             SuperView      : AnActiveView;
                             Ulx            : ascreenx;
                             Uly            : ascreeny;
                             Lrx            : ascreenx;
                             Lry            : ascreeny;
                             Box            : ABoxType;
                             VideoMode      : avidmode;
                         VAR Title          : ARRAY OF CHAR;
                             HelpKey        : CARDINAL;
                             TakeRug        : BOOLEAN      );

VAR
    PrivateListView         : XListView;
    i                       : CARDINAL;

BEGIN                       (* InitAsListView *)

    InitAsActiveView(AnActiveView(ListView), AnObjectView(SuperView), Ulx, 
                     Uly, Lrx, Lry, Box, VideoMode, Title, HelpKey, TakeRug);
                     
    PrivateListView := XListView(ListView);
    WITH PrivateListView^ DO
        Methods := ADR(ListViewMethodsRecord);
        Last := 0;
        FOR i := 1 TO HIGH(SubView) DO
            SubView[i] := NIL;
        END;
        Cursor := 0;
        MouseDownRegion := 0;
    END;

END InitAsListView;







(*----------------------------------------------------------------------------
    CreateListView --

    Allocate storage for, and initialize the indicated object as a list
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid list view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateListView(VAR ListView       : AListView;
                             SuperView      : AnActiveView;
                             Ulx            : ascreenx;
                             Uly            : ascreeny;
                             Lrx            : ascreenx;
                             Lry            : ascreeny;
                             Box            : ABoxType;
                             VideoMode      : avidmode;
                         VAR Title          : ARRAY OF CHAR;
                             HelpKey        : CARDINAL;
                             TakeRug        : BOOLEAN      ) 
                                                            : BOOLEAN;

BEGIN                       (* CreateListView *)

    IF (HeapAvailable()) THEN
        ALLOCATE(ListView, TSIZE(XListViewRecord));
        InitAsListView(ListView, SuperView, Ulx, Uly, Lrx, Lry, Box, 
                       VideoMode, Title, HelpKey, TakeRug);

        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateListView;








(*----------------------------------------------------------------------------
    UnInitAsListView --

    UnInitialize the indicated object as a list view.

    Preconditions:
        The object will be a valid list view object. 

    Postconditions:
        Whatever was done by InitAsListView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsListView(    ListView     : AListView);

BEGIN                       (* UnInitAsListView *)

    UnInitAsActiveView(AnActiveView(ListView));

END UnInitAsListView;







(*----------------------------------------------------------------------------
    CloneListViewMethods --

    Make a copy of the list view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The list view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneListViewMethods(    MethodObject : AListViewMethods);

BEGIN                       (* CloneListViewMethods *)

    MethodObject^ := ListViewMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(ListViewMethodsRecord);

END CloneListViewMethods;







(*----------------------------------------------------------------------------
    ValidateListView --

    Determine that the indicated object is in fact a valid list view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid list view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateListView(    ListView : AListView);

VAR
    PrivateListView         : XListView;

BEGIN                       (* ValidateListView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(ListView));
    END;
    DEBUGGING>*)

    PrivateListView := XListView(ListView);
    IF (PrivateListView^.Methods^.ListViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateListView;




BEGIN                       (* ListViews *)

    CloneActiveViewMethods(ADR(ListViewMethodsRecord));
    WITH ListViewMethodsRecord DO
        MethodSize := TSIZE(AListViewMethodsRecord);
        Discard := AListViewDiscardProc(ListViewDiscard);
        Display := AListViewProc(ListViewDisplay);
        ActOnEvent := AListViewActOnProc(ListViewActOn);
        SetFirst := AListViewSetProc(SetListViewFirst);
        GetFirst := AListViewGetProc(GetListViewFirst);
        GetLast := AListViewGetProc(GetListViewLast);
        SetCursorNode := AListViewSetProc(SetListViewCursorNode);
        GetCursorNode := AListViewGetProc(GetListViewCursorNode);
        Synchronize := AListViewProc(ListViewSynchronize);
        ForceToPosition := AListViewForceProc(ListViewForce);
        InquirePosition := AListViewInquireProc(ListViewInquire);
        NotifyNodeDeleted := AListViewSetProc(ListViewNotifyDeleted);
        SetCursorMode := AListViewSetCursorModeProc(ListViewSetMode);
        ListViewTag := ModuleNumber;
    END;

END ListViews.

