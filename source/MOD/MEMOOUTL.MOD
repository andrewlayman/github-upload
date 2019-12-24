(*V9=DEBUGGING Code*)

IMPLEMENTATION MODULE MemoOutlines;        (*  a subclass of OutlineViews  *)

(*  =========================================================================
    Last Edit : September 12, 1989 2:39PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        12-Oct-87 LAA   Set ScheduleSaved to FALSE when something is done to
                        to a memo.
        15-Oct-87 RSC   Removed import of EditText
        24-Dec-87 LAA   Added an extra message when deleting a memo to warn
                        that children will also be deleted.
        16-Nov-88 EGK   CreateMemoOutline Discards if error is posted.
        10-Jan-89 RSC   Changed Storage to Space    .
        10-Jun-89 WKH   Added support for variable screen rows
        31-Jul-89 KKC   Call ContinuationBox instead of NoYes.
        12-Sep-89 WKH   Make goto box bigger for compressed video
        27-Dec-89 LAA   Added MouseDownRegion to the object record definition,
                        so we can limit mouse actions to the screen region on 
                        which the mouse button was originally pressed.
         5-Jan-90 LAA   Moved the location of MouseDownRegion, because this
                        instance variable is now defined in ListViews instead
                        of OutlineViews.
                        Also removed the initialization of TypeThroughEnabled,
                        as this is now set to FALSE in InitAsOutlineView.

    =========================================================================
*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM Codes                  IMPORT
    (* TYPE *)                  ASetOfCodes;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Burp, Error, FatalError, NotYetImplemented,
                                ContinuationBox;

FROM ErrorCategories        IMPORT
    (* CONST *)                 NotPossibleInContextError, UnknownEventError,
                                AllocationError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker,
                                GetErrorDetails, PostError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM GoTo                   IMPORT
    (* TYPE *)                  AGoToNameProc,
    (* PROC *)                  DoGoTo, NullGoToCheckProc;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 AbsoluteMaxRow, maxrow, maxcol;

FROM Keys                   IMPORT
    (* CONST *)                 EditKey, DeleteKey, InsertKey, CancelKey,
                                CopyKey, GotoKey;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Compare, ConcatLS, LJust, SetLengthOf;

FROM Memos                  IMPORT
    (* TYPE *)                  AMemoRecordPointer,
    (* VAR  *)                  MemoTree,
    (* PROC *)                  CreateMemo, EditMemo, DiscardMemo;

FROM MemoViews              IMPORT
    (* TYPE *)                  AMemoView, CreateMemoView;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, DisplayMessage, ConcatMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineViewMethods, AnOutlineView,
    (* PROC *)                  InitAsOutlineView, UnInitAsOutlineView,
                                ValidateOutlineView, CloneOutlineViewMethods;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM Schedule               IMPORT
    (* VAR *)                   ScheduleSaved;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  AssignText, DiscardText, CopyLine;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
                                ATreeNodeProcessingProc,
    (* PROC *)                  CreateTreeNode;



CONST
    ModuleNumber            = 17300;


TYPE
        (*  AMemoOutline is a subclass of AnOutlineView  *)

    XMemoOutline            = POINTER TO XMemoOutlineRecord;

    XMemoOutlineRecord      = RECORD
                                Methods        : AMemoOutlineMethods;
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
                                Status         : AMemoOutlineStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                    AMemoView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                                  (* New fields for outline views *)
                                MatchCount          : CARDINAL;
                                MatchString         : ARRAY [0..80] OF CHAR;
                                TypeThroughEnabled  : BOOLEAN;
                                MatchCodeSet        : ASetOfCodes;
                                NameProc            : AGoToNameProc;
                              END;

    AContext = POINTER TO BOOLEAN;

VAR
    MemoOutlineMethodsRecord : AMemoOutlineMethodsRecord;






PROCEDURE DiscardSubViews(    MemoOutline   : XMemoOutline);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    WITH MemoOutline^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;
        Cursor := 0;
    END;

END DiscardSubViews;




PROCEDURE MemoOutlineDiscard(VAR MemoOutline : XMemoOutline);

BEGIN                       (* MemoOutlineDiscard *)

    UnInitAsMemoOutline(AMemoOutline(MemoOutline));
    DISPOSE(MemoOutline);

END MemoOutlineDiscard;


PROCEDURE GetMemoName   (       Node    : ATreeNode;
                            VAR s       : ARRAY OF CHAR );
VAR
    Memo        : AMemoRecordPointer;

BEGIN
    Memo := Node^.Methods^.GetDataObject (Node);
    CopyLine (Memo^.text, 0, s);
    LJust(s);                                    (* 24-Dec-87 LAA *)

END GetMemoName;



PROCEDURE LookForOpenMemos  (VAR Node       : ATreeNode;
                                 Context    : AContext  );
VAR
    Memo            : AMemoRecordPointer;

BEGIN
    Memo := Node^.Methods^.GetDataObject (Node);
    Context^ := Context^ OR Memo^.open;
END LookForOpenMemos;



PROCEDURE MemoOutlineActOn(    MemoOutline  : XMemoOutline;
                               Event        : AnEvent;
                           VAR ReturnEvent  : AnEvent     );

VAR
    WantToRecord            : BOOLEAN;
    ErrorMarker             : AnErrorMarker;
    MemosAreOpen            : BOOLEAN;


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


    PROCEDURE DoEditKey ();

    VAR
        Node                : ATreeNode;

    BEGIN                   (* EditMemo *)

        WITH MemoOutline^.Methods^ DO
            Node := GetCursorNode(AMemoOutline(MemoOutline));
            IF (Node <> NIL) THEN
                EditMemo (Node);
                ResetMatching (AMemoOutline(MemoOutline));
                Synchronize (AMemoOutline(MemoOutline));
                ScheduleSaved := FALSE;
            ELSE
                DoInsertKey ();
            END;
        END;

    END DoEditKey;



    PROCEDURE DoDeleteKey ();

    VAR
        Node                : ATreeNode;
        CNode               : ATreeNode;
        Msg                 : ARRAY [0..255] OF CHAR;
        NullString          : ARRAY [0..0] OF CHAR;

    BEGIN                   (* DoMemoDelete *)

        IF (MemosAreOpen) THEN
            PostError (NotPossibleInContextError, ModuleNumber+2);
            RETURN;
        END;
        WITH MemoOutline^.Methods^ DO
            Node := GetCursorNode(AMemoOutline(MemoOutline));
            IF (Node = NIL) THEN
                PostError (NotPossibleInContextError, ModuleNumber+2);
                RETURN;
            END;
                (* Caution.  Really delete this note? *)
            GetMessage (ModuleNumber+0, Msg);
            IF (Node^.Methods^.GetSubtree(Node) <> NIL) THEN      (* 24-Dec-87 LAA *)
                    (* Deleting it will also delete it's children.  *)
                ConcatMessage(Msg, ModuleNumber + 1);             
            END;
            SetLengthOf(NullString, 0);
            IF ( ContinuationBox (Msg, NullString, NoHelp) ) THEN
                Node^.Methods^.SetChildrenVisible (Node, FALSE);
                CNode := Node^.Methods^.NextForDisplay(Node);
                IF (CNode = NIL) THEN
                    CNode := Node^.Methods^.PrevForDisplay(Node);
                END;
                DiscardMemo (Node);
                IF (MemoOutline^.Cursor = 1) THEN
                    SetFirst(AMemoOutline(MemoOutline), CNode);
                ELSE
                    Synchronize(AMemoOutline(MemoOutline));
                END;
                ScheduleSaved := FALSE;
                ResetMatching (AMemoOutline(MemoOutline));
                SetCursorNode(AMemoOutline(MemoOutline), CNode);
            END;
        END;

    END DoDeleteKey;


    PROCEDURE DoInsertKey ();

    VAR
        Node                : ATreeNode;
        NewNode             : ATreeNode;
        Memo                : AMemoRecordPointer;

    BEGIN                   (* DoMemoInsert *)

        IF (MemosAreOpen) THEN
            PostError (NotPossibleInContextError, ModuleNumber+2);
            RETURN;
        END;
        WITH MemoOutline^.Methods^ DO
            Node := GetCursorNode(AMemoOutline(MemoOutline));
            NewNode := CreateMemo (AText (NIL));
            IF (NewNode = NIL) THEN
                PostError(AllocationError, ModuleNumber + 99);
                RETURN;
            END;
            IF (Node = NIL) THEN
                MemoTree^.Methods^.AddFirst (MemoTree, NewNode);
            ELSE
                Node^.Methods^.AddAfter (Node, NewNode);
            END;
            EditMemo (NewNode);
            Memo := NewNode^.Methods^.GetDataObject (NewNode);
            IF (ADDRESS (Memo^.text) = NIL) THEN
                DiscardMemo (NewNode);
                RETURN;
            END;
            IF (Node = NIL) THEN
                SetFirst (AMemoOutline (MemoOutline), NewNode);
            ELSE
                Synchronize (AMemoOutline (MemoOutline));
            END;
            ScheduleSaved := FALSE;
            ResetMatching (AMemoOutline(MemoOutline));
            SetCursorNode(AMemoOutline(MemoOutline), NewNode);
        END;
    END DoInsertKey;


    PROCEDURE DoCopyKey ();
    VAR
        Node            : ATreeNode;
        NewNode         : ATreeNode;
        Memo            : AMemoRecordPointer;
        newtext         : AText;
    BEGIN
        IF (MemosAreOpen) THEN
            PostError (NotPossibleInContextError, ModuleNumber+2);
            RETURN;
        END;
        WITH MemoOutline^.Methods^ DO
            Node := GetCursorNode(AMemoOutline(MemoOutline));
            IF (Node = NIL) THEN
                PostError(NotPossibleInContextError, ModuleNumber + 2);
                RETURN;
            END;
            Memo := Node^.Methods^.GetDataObject (Node);
            IF (NOT AssignText (Memo^.text, newtext)) THEN
                PostError (AllocationError, ModuleNumber+20);
                RETURN;
            END;
            NewNode := CreateMemo (newtext);
            IF (NewNode <> NIL) THEN
                Node^.Methods^.AddAfter (Node, NewNode);
                Synchronize (AMemoOutline (MemoOutline));
                ResetMatching (AMemoOutline(MemoOutline));
                SetCursorNode (AMemoOutline (MemoOutline), NewNode);
                ScheduleSaved := FALSE;
            ELSE
                DiscardText (newtext);
                PostError (AllocationError, ModuleNumber+20);
            END;
        END;

    END DoCopyKey;


    PROCEDURE DoGotoKey ();
    VAR
        CursorNode                  : ATreeNode;
        Title                   : ARRAY [0..30] OF CHAR;

    BEGIN
        CursorNode := MemoOutline^.Methods^.GetCursorNode (AMemoOutline (MemoOutline));
        GetMessage (ModuleNumber+30, Title);
        IF DoGoTo (MemoOutline^.ViewObject, 40, 6, 75, maxrow-7, Title, TRUE,
                   NullGoToCheckProc, GetMemoName, CursorNode) THEN
            MemoOutline^.Methods^.SetCursorNode (AMemoOutline (MemoOutline), CursorNode);
        END;
    END DoGotoKey;

        

BEGIN                       (* MemoOutlineActOn *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateMemoOutline(AMemoOutline(MemoOutline));
    END;
    (*DEBUGGING>*)

    ErrorMarker := NewMarker();

    WITH MemoOutline^ DO
        MemoOutlineMethodsRecord.SuperclassMethods^.
                   ActOnEvent(AnOutlineView(MemoOutline), Event, ReturnEvent);
        Event := ReturnEvent;

        ReturnEvent.EventCode := 0;
        WantToRecord := TRUE;

        MemosAreOpen := FALSE;
        ViewObject^.Methods^.TraverseTree (ViewObject, ParentBeforeChild,
                9999, ATreeNodeProcessingProc (LookForOpenMemos),
                ADR (MemosAreOpen));

        CASE Event.EventCode OF
            EditKey :
                DoEditKey ();
        |   DeleteKey :
                DoDeleteKey ();
        |   InsertKey :
                DoInsertKey ();
        |   CopyKey :
                DoCopyKey ();
        |   GotoKey :
                DoGotoKey ();
        ELSE
            ReturnEvent := Event;
            WantToRecord := FALSE;
        END;
        IF (WantToRecord) THEN
            Methods^.RecordEvent(AMemoOutline(MemoOutline), Event);
        END;
        IF (ErrorPosted(ErrorMarker)) THEN
            RespondToErrors(ErrorMarker);
        END;
        PopToMarker(ErrorMarker);
    END;

END MemoOutlineActOn;





(*----------------------------------------------------------------------------
    InitAsMemoOutline --

    Initialize the indicated object as a memo outline view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid memo outline view object.  No storage 
        allocation is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsMemoOutline(    MemoOutline : AMemoOutline;
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
    PrivateMemoOutline      : XMemoOutline;
    y                       : ascreeny;

BEGIN                       (* InitAsMemoOutline *)

    InitAsOutlineView(AnOutlineView(MemoOutline), SuperView, Ulx, Uly, Lrx,
                      Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    PrivateMemoOutline := XMemoOutline(MemoOutline);
    WITH PrivateMemoOutline^ DO
        Methods := ADR(MemoOutlineMethodsRecord);
        Last := 0;
        FOR y := Uly TO Lry DO
            IF (NOT CreateMemoView(SubView[Last + 1], AnActiveView(MemoOutline), 
                                   Ulx, y, Lrx, y, ABoxType{NoBox}, VideoMode, 
                                   HelpKey)) THEN
                DiscardSubViews(PrivateMemoOutline);

                PostError(ModuleNumber, AllocationError);
    
                RETURN;
            END;
            INC(Last);
        END;
        NameProc := GetMemoName;
    END;

END InitAsMemoOutline;





(*----------------------------------------------------------------------------
    CreateMemoOutline --

    Allocate storage for, and initialize the indicated object as a memo 
    outline view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid memo outline view object, and 
        TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateMemoOutline(VAR MemoOutline : AMemoOutline;
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

VAR
    ErrorMarker             : AnErrorMarker;
    ok                      : BOOLEAN;

BEGIN                       (* CreateMemoOutline *)

    ok := FALSE;
    ErrorMarker := NewMarker();
    IF (Available(TSIZE(XMemoOutlineRecord))) THEN
        ALLOCATE(MemoOutline, TSIZE(XMemoOutlineRecord));
        InitAsMemoOutline(MemoOutline, SuperView, Ulx, Uly, Lrx, Lry, Box,
                          VideoMode, Title, HelpKey, TakeRug);

        ok := NOT ErrorPosted(ErrorMarker);
        IF (NOT ok) THEN
            MemoOutline^.Methods^.Discard (MemoOutline);        (* 11/16/88 EGK *)
        END;
    END;
    PopToMarker(ErrorMarker);

    RETURN ok;

END CreateMemoOutline;







(*----------------------------------------------------------------------------
    UnInitAsMemoOutline --

    UnInitialize the indicated object as a memo outline view.

    Preconditions:
        The object will be a valid memo outline view object. 

    Postconditions:
        The outline view will be invalidated.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsMemoOutline(    MemoOutline : AMemoOutline);


BEGIN                       (* UnInitAsMemoOutline *)

    DiscardSubViews(XMemoOutline(MemoOutline));
    UnInitAsOutlineView(AnOutlineView(MemoOutline));

END UnInitAsMemoOutline;







(*----------------------------------------------------------------------------
    CloneMemoOutlineMethods --

    Make a copy of the memo outline view methods into the indicated method 
    object.

    Preconditions:
        None.

    Postcondition:
        The memo outline view methods will be copied into the indicated 
        method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneMemoOutlineMethods(    MethodObject : AMemoOutlineMethods);

BEGIN                       (* CloneMemoOutlineMethods *)

    MethodObject^ := MemoOutlineMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(MemoOutlineMethodsRecord);
END CloneMemoOutlineMethods;








(*----------------------------------------------------------------------------
    ValidateMemoOutline --

    Determine that the indicated object is in fact a valid memo outline view 
    object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid memo outline view object, FatalError 
        will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateMemoOutline(    MemoOutline : AMemoOutline);

VAR
    PrivateMemoOutline      : XMemoOutline;

BEGIN                       (* ValidateMemoOutline *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(MemoOutline));
    END;
    DEBUGGING>*)

    PrivateMemoOutline := XMemoOutline(MemoOutline);
    IF (PrivateMemoOutline^.Methods^.MemoOutlineTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateMemoOutline;





BEGIN                       (* MemoOutlines *)

    CloneOutlineViewMethods(ADR(MemoOutlineMethodsRecord));
    WITH MemoOutlineMethodsRecord DO
        MethodSize := TSIZE(AMemoOutlineMethodsRecord);
        Discard := AMemoOutlineDiscardProc(MemoOutlineDiscard);
        ActOnEvent := AMemoOutlineActOnProc(MemoOutlineActOn);
        MemoOutlineTag := ModuleNumber;
    END;

END MemoOutlines.
