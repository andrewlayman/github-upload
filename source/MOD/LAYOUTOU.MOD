IMPLEMENTATION MODULE LayoutOutlines;        (*  a subclass of OutlineViews  *)

    (*  MODIFICATION HISTORY --
        23-Dec-87 LAA   Inhibit the numeric zero key (same as Shift insert) if 
                        type-through is in effect.  Also prevented new layout 
                        from  inheriting the "standard" attribute when created 
                        by insert; will inherit it if created by copy.
        16-Nov-88 EGK   CreateLayoutOutline Discards if error is posted.
        10-Jan-89 RSC   Changed Storage to Space    .
        10-Jun-89 WKH   Added support for variable screen rows
        31-Jul-89 KKC   Call ContinuationBox instead of NoYes.
        27-Dec-89 LAA   Added MouseDownRegion to the object record definition,
                        so we can limit mouse actions to the screen region on 
                        which the mouse button was originally pressed.
         5-Jan-90 LAA   Moved the location of MouseDownRegion, because this
                        instance variable is now defined in ListViews instead
                        of OutlineViews.
                        Also moved the initialization of TypeThroughEnabled,
                        as it's now init'ed to FALSE by InitAsOutlineView.
    *)

(*V9=DEBUGGING Code*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR *)                   LayoutTree, CurrentChartFormat,
    (* PROC *)                  CreateLayout, DoLayoutForm, SortLayouts,
                                DiscardLayout, CurrentLayout;

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
    (* TYPE *)                  AGoToNameProc;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 AbsoluteMaxRow, maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 JoinKey, UnJoinKey, CancelKey,
                                InsertKey, DeleteKey, EditKey, CopyKey,
                                PromoteKey, DemoteKey, MoveUpKey, MoveDownKey,
                                OpenKey, CloseKey;

FROM LayoutViews              IMPORT
    (* TYPE *)                  ALayoutView,
    (* PROC *)                  CreateLayoutView;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, ConcatLS, TrimRear, Copy, 
                                LengthOf, SetLengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

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
    (* VAR  *)                  ScheduleSaved;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  AssignText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTreeNode;


CONST
    ModuleNumber            = 18400;


TYPE
        (*  ALayoutOutline is a subclass of AnOutlineView  *)

    XLayoutOutline            = POINTER TO XLayoutOutlineRecord;

    XLayoutOutlineRecord      = RECORD
                                Methods        : ALayoutOutlineMethods;
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
                                Status         : ALayoutOutlineStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                    ALayoutView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                                  (* New fields for outline views *)
                                MatchCount          : CARDINAL;
                                MatchString         : ARRAY [0..80] OF CHAR;
                                TypeThroughEnabled  : BOOLEAN;
                                MatchCodeSet        : ASetOfCodes;
                                NameProc            : AGoToNameProc;
                              END;


    ALayoutOutlineDiscardProc = PROCEDURE (VAR ALayoutOutline);

    ALayoutOutlineActOnProc   = PROCEDURE(    ALayoutOutline,
                                              AnEvent,
                                          VAR AnEvent        );

VAR
    LayoutOutlineMethodsRecord : ALayoutOutlineMethodsRecord;






PROCEDURE DiscardSubViews(    LayoutOutline   : XLayoutOutline);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    WITH LayoutOutline^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;
        Cursor := 0;
    END;

END DiscardSubViews;




PROCEDURE GetLayoutName   (    Node       : ATreeNode;
                           VAR s          : ARRAY OF CHAR );
VAR
    LayoutPtr         : AChartFormatPtr;

BEGIN               (* LayoutViewGetTitle *)

    LayoutPtr := Node^.Methods^.GetDataObject (Node);
    Copy (LayoutPtr^.Name, s);

END GetLayoutName;





PROCEDURE LayoutOutlineDiscard(VAR LayoutOutline : XLayoutOutline);

BEGIN                       (* LayoutOutlineDiscard *)

    UnInitAsLayoutOutline(ALayoutOutline(LayoutOutline));
    DISPOSE(LayoutOutline);

END LayoutOutlineDiscard;



PROCEDURE LayoutOutlineActOn (  LayoutOutline   : XLayoutOutline;
                                Event           : AnEvent;
                            VAR ReturnEvent     : AnEvent        );
VAR
    WantToRecord            : BOOLEAN;
    ErrorMarker             : AnErrorMarker;
    Layout                  : AChartFormatPtr;
    Msg                     : ARRAY [0..255] OF CHAR;
    Node, FirstNode         : ATreeNode;

CONST
    LineAboveLayoutForm     = 1;


    PROCEDURE CursorOnBlankLayout(): BOOLEAN;

    VAR
        Node                : ATreeNode;
        Layout              : AChartFormatPtr;
        s                   : ARRAY [0..80] OF CHAR;

    BEGIN                   (* CursorOnBlankLayout *)

        WITH LayoutOutline^.Methods^ DO
            Node := GetCursorNode(ALayoutOutline(LayoutOutline));
            IF (Node <> NIL) THEN
                Layout := Node^.Methods^.GetDataObject(Node);
                Copy(Layout^.Name, s);
                TrimRear(s);
                RETURN (LengthOf(s) = 0);
            END;

            RETURN FALSE;           (* so insert & edit keys will work *)
        END;

    END CursorOnBlankLayout;



    PROCEDURE ScrollAbove(    Node          : ATreeNode;
                              Position      : CARDINAL)
                                                       : CARDINAL;

    VAR
        i                   : CARDINAL;

    BEGIN                   (* ScrollAbove *)

        WITH LayoutOutline^.Methods^ DO
            i := InquirePosition(ALayoutOutline(LayoutOutline), Node);
            IF (i > Position) THEN
                ForceToPosition(ALayoutOutline(LayoutOutline), Node, Position);
            END;

            RETURN i;
        END;

    END ScrollAbove;



    PROCEDURE ScrollBack(    Node           : ATreeNode;
                             Position       : CARDINAL);

    BEGIN                   (* ScrollBack *)

        WITH LayoutOutline^.Methods^ DO
            ForceToPosition(ALayoutOutline(LayoutOutline), Node, Position);
        END;

    END ScrollBack;



    PROCEDURE HandleErrors(    ErrorMarker : AnErrorMarker);

    VAR
        Category                : CARDINAL;
        Code                    : CARDINAL;
        i                       : CARDINAL;
        s                       : ARRAY [0..255] OF CHAR;

    BEGIN

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

    END HandleErrors;




    PROCEDURE DoInsertKey ();

    VAR
        Node                : ATreeNode;
        ChartFormatPtr      : AChartFormatPtr;
        CurrentFormatPtr    : AChartFormatPtr;
        PrevPosition        : CARDINAL;
        CursorNode          : ATreeNode;
        WasAdded            : BOOLEAN;

    BEGIN

        IF (CreateLayout (Node)) THEN
            WITH LayoutOutline^.Methods^ DO
                ChartFormatPtr := Node^.Methods^.GetDataObject (Node);
                CurrentFormatPtr := CurrentLayout();
                ChartFormatPtr^ := CurrentFormatPtr^;
                EXCL(ChartFormatPtr^.LayoutFlags, 0);             (* 23-Dec-87 LAA *)
                ChartFormatPtr^.Notes := AText(NIL);
                SetLengthOf (ChartFormatPtr^.Name, 0);
                CursorNode := GetCursorNode(ALayoutOutline(LayoutOutline));
                IF (CursorNode <> NIL) THEN
                    CursorNode^.Methods^.AddAfter(CursorNode, Node);
                ELSE
                    LayoutTree^.Methods^.AddFirst(LayoutTree, Node);
                    SetFirst(ALayoutOutline(LayoutOutline), Node);
                END;
                Synchronize(ALayoutOutline(LayoutOutline));
                SetCursorNode(ALayoutOutline(LayoutOutline), Node);

                PrevPosition := ScrollAbove(Node, LineAboveLayoutForm);
                SetCursorMode(ALayoutOutline(LayoutOutline), videorestingcursor);

                Display(ALayoutOutline(LayoutOutline));

                WasAdded := (DoLayoutForm(Node) <> CancelKey);
                SetCursorMode(ALayoutOutline(LayoutOutline), 
                              LayoutOutline^.VideoMode);
                IF (WasAdded) THEN
                    ScrollBack(Node, PrevPosition);
                    SortLayouts();
                    Synchronize(ALayoutOutline(LayoutOutline));
                    LayoutOutline^.Methods^.ResetMatching (ALayoutOutline(LayoutOutline));
                    SetCursorNode(ALayoutOutline(LayoutOutline), Node);
                ELSE
                    Node^.Methods^.DeList(Node);
                    IF (Node = GetFirst(ALayoutOutline(LayoutOutline))) THEN
                        SetFirst(ALayoutOutline(LayoutOutline), CursorNode);
                    END;
                    DiscardLayout(Node);
                    ScrollBack(CursorNode, PrevPosition - 1);
                    SetCursorNode(ALayoutOutline(LayoutOutline), CursorNode);
                END;
            END;
        ELSE
            PostError (AllocationError, ModuleNumber+5);
        END;
    END DoInsertKey;




    PROCEDURE DoDeleteKey ();

    VAR
        NextNode                : ATreeNode;
        OkToDelete              : BOOLEAN;
        PrivateLayoutOutline    : XLayoutOutline;
        Msg                     : ARRAY [0..255] OF CHAR;
        Node                    : ATreeNode;


        PROCEDURE GetApproval   ( Node  : ATreeNode ) : BOOLEAN;
        VAR
            OK          : BOOLEAN;
            NullString  : ARRAY [0..0] OF CHAR;
        BEGIN
            Layout := Node^.Methods^.GetDataObject(Node);
            GetMessage(ModuleNumber, Msg);
            ConcatLS(Msg, Layout^.Name);
            TrimRear(Msg);
            ConcatMessage(Msg, ModuleNumber + 1);
            SetLengthOf(NullString, 0);
            OK := ContinuationBox (Msg, NullString, NoHelp);
            IF (OK) AND (0 IN Layout^.LayoutFlags) THEN
                GetMessage (ModuleNumber + 7, Msg);
                OK := ContinuationBox (Msg, NullString, NoHelp);
            END;
            RETURN OK;
        END GetApproval;


    BEGIN                   (* DoDeleteKey *)

        IF (CursorOnBlankLayout()) THEN
            PostError(NotPossibleInContextError, ModuleNumber + 2);
            RETURN;
        END;

        WITH LayoutOutline^ DO
            WITH Methods^ DO
                Node := GetCursorNode(ALayoutOutline(LayoutOutline));
                IF (Node <> NIL) THEN
                    SetCursorMode(ALayoutOutline(LayoutOutline),videorestingcursor);
                    Display(ALayoutOutline(LayoutOutline));
                    OkToDelete := GetApproval (Node);
                    SetCursorMode(ALayoutOutline(LayoutOutline), VideoMode);
                    IF (OkToDelete) THEN
                        IF (Node = CurrentChartFormat) THEN
                            CurrentChartFormat := NIL;
                        END;
                        NextNode := Node^.Methods^.GetNext (Node);
                        IF (NextNode = NIL) THEN
                            NextNode := Node^.Methods^.GetPrev (Node);
                        END;
                        DiscardLayout(Node);
                        IF (LayoutOutline^.Cursor = 1) THEN
                            SetFirst(ALayoutOutline(LayoutOutline), NextNode);
                        ELSE 
                            Synchronize(ALayoutOutline(LayoutOutline));
                        END;
                        LayoutOutline^.Methods^.ResetMatching (ALayoutOutline(LayoutOutline));
                        SetCursorNode(ALayoutOutline(LayoutOutline), NextNode);
                    END;
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 2);
                END;
            END;
        END;

    END DoDeleteKey;


    PROCEDURE DoEditKey ();

    VAR
        FirstNode           : ATreeNode;
        Layout              : AChartFormatPtr;
        PrevPosition        : CARDINAL;
        Node                : ATreeNode;

    BEGIN                   (* DoEditKey *)

        WITH LayoutOutline^.Methods^ DO
            Node := GetCursorNode(ALayoutOutline(LayoutOutline));
            PrevPosition := ScrollAbove(Node, LineAboveLayoutForm);
            IF ((Node <> NIL) AND (NOT CursorOnBlankLayout())) THEN
                SetCursorMode(ALayoutOutline(LayoutOutline),videorestingcursor);
                Display(ALayoutOutline(LayoutOutline));
                IF (DoLayoutForm(Node) <> CancelKey) THEN
                    SortLayouts ();
                    LayoutOutline^.Methods^.ResetMatching (ALayoutOutline(LayoutOutline));
                END;
                SetCursorMode(ALayoutOutline(LayoutOutline),LayoutOutline^.VideoMode);
                SetCursorNode(ALayoutOutline(LayoutOutline), Node);
            ELSE
                DoInsertKey ();
            END;
            ScrollBack(Node, PrevPosition);
        END;

    END DoEditKey;



    PROCEDURE DoCopyKey ();

    VAR
        OldLayout           : AChartFormatPtr;
        Layout              : AChartFormatPtr;
        CNode               : ATreeNode;
        Node                : ATreeNode;
        PrevPosition        : CARDINAL;

    BEGIN

        IF (CursorOnBlankLayout()) THEN
            PostError(NotPossibleInContextError, ModuleNumber + 2);
            RETURN;
        END;

        WITH LayoutOutline^.Methods^ DO
            CNode := GetCursorNode(ALayoutOutline(LayoutOutline));
            IF (CNode <> NIL) THEN
                OldLayout := CNode^.Methods^.GetDataObject(CNode);
                IF (CreateLayout (Node)) THEN
                    Layout := Node^.Methods^.GetDataObject (Node);
                    Layout^ := OldLayout^;
                    Layout^.Notes := AText(NIL);
                    IF (AssignText(OldLayout^.Notes, Layout^.Notes)) THEN END;
                    CNode^.Methods^.AddAfter(CNode, Node);
                    Synchronize(ALayoutOutline(LayoutOutline));
                    SetCursorNode(ALayoutOutline(LayoutOutline), Node);
                    PrevPosition := ScrollAbove(Node, LineAboveLayoutForm);
                    SetCursorMode(ALayoutOutline(LayoutOutline),videorestingcursor);
                    Display(ALayoutOutline(LayoutOutline));
                    IF (DoLayoutForm(Node) = CancelKey) THEN
                        DiscardLayout(Node);
                        Node := CNode;
                    ELSE
                        LayoutOutline^.Methods^.ResetMatching (ALayoutOutline(LayoutOutline));
                        SortLayouts ();
                    END;
                    SetCursorMode(ALayoutOutline(LayoutOutline),LayoutOutline^.VideoMode);
                    SetCursorNode(ALayoutOutline(LayoutOutline), Node);
                    ScrollBack(Node, PrevPosition);
                END;
            ELSE
                PostError (NotPossibleInContextError, ModuleNumber);
            END;
        END;

    END DoCopyKey;


BEGIN               (* LayoutOutlineActOn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateLayoutOutline(ALayoutOutline(LayoutOutline));
    END;
      DEBUGGING>*)

    ErrorMarker := NewMarker ();

    ReturnEvent.EventCode := 0;
    WantToRecord := TRUE;

    WITH LayoutOutline^ DO
        IF (Cursor = 0) THEN
            Cursor := 1;
        END;
        WITH SubView[Cursor]^.Methods^ DO
            ActOnEvent(SubView[Cursor], Event, ReturnEvent);
        END;

        IF (ReturnEvent.EventCode <> 0) THEN
            Event := ReturnEvent;
            ReturnEvent.EventCode := 0;

            CASE Event.EventCode OF
                InsertKey :
                    DoInsertKey ();
            |   DeleteKey :
                    DoDeleteKey ();
            |   EditKey :
                    DoEditKey ();
            |   CopyKey :
                    IF (MatchCount > 0) THEN                      (* 23-Dec-87 LAA *)
                        WITH LayoutOutlineMethodsRecord.SuperclassMethods^ DO
                            ActOnEvent(AnOutlineView(LayoutOutline),Event,
                                       ReturnEvent);
                        END;
                        WantToRecord := (ReturnEvent.EventCode <> 0);
                    ELSE
                        DoCopyKey ();
                    END;
            |   PromoteKey, DemoteKey, MoveUpKey, MoveDownKey, OpenKey, 
                CloseKey :
                    IF (NOT LayoutOutline^.Methods^.FindChar
                            (ALayoutOutline(LayoutOutline),CHR(Event.EventCode))) THEN
                        PostError (NotPossibleInContextError, ModuleNumber+1);
                    ELSE
                        Event.EventCode := 0;
                    END;
            ELSE
                WITH LayoutOutlineMethodsRecord.SuperclassMethods^ DO
                    ActOnEvent(AnOutlineView(LayoutOutline),Event,ReturnEvent);
                END;
                WantToRecord := (ReturnEvent.EventCode <> 0);
            END;
        END;

        IF (WantToRecord) THEN
            Methods^.RecordEvent(ALayoutOutline(LayoutOutline), Event);
        END;
    END;

    IF (ErrorPosted (ErrorMarker)) THEN
        HandleErrors (ErrorMarker);
    END;
    PopToMarker (ErrorMarker);

END LayoutOutlineActOn;





(*----------------------------------------------------------------------------
    InitAsLayoutOutline --

    Initialize the indicated object as a filter outline view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid filter outline view object.  No storage 
        allocation is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsLayoutOutline(  LayoutOutline   : ALayoutOutline;
                                SuperView       : AnActiveView;
                                Ulx             : ascreenx;
                                Uly             : ascreeny;
                                Lrx             : ascreenx;
                                Lry             : ascreeny;
                                Box             : ABoxType;
                                VideoMode       : avidmode;
                            VAR Title           : ARRAY OF CHAR;
                                HelpKey         : CARDINAL;
                                TakeRug         : BOOLEAN        );

VAR
    PrivateLayoutOutline    : XLayoutOutline;
    y                       : ascreeny;

BEGIN                       (* InitAsLayoutOutline *)

    InitAsOutlineView(AnOutlineView(LayoutOutline), SuperView, Ulx, Uly, Lrx,
                      Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    PrivateLayoutOutline := XLayoutOutline(LayoutOutline);
    WITH PrivateLayoutOutline^ DO
        TypeThroughEnabled := TRUE;
        NameProc := GetLayoutName;
        Methods := ADR(LayoutOutlineMethodsRecord);
        Last := 0;
        FOR y := Uly TO Lry DO
            IF (NOT CreateLayoutView(SubView[Last + 1], AnActiveView(LayoutOutline), 
                                   Ulx, y, Lrx, y, ABoxType{NoBox}, VideoMode, 
                                   HelpKey)) THEN
                DiscardSubViews(PrivateLayoutOutline);

                PostError(ModuleNumber, AllocationError);
    
                RETURN;
            END;
            INC(Last);
        END;
    END;

END InitAsLayoutOutline;





(*----------------------------------------------------------------------------
    CreateLayoutOutline --

    Allocate storage for, and initialize the indicated object as a filter 
    outline view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid filter outline view object, and 
        TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateLayoutOutline(VAR LayoutOutline : ALayoutOutline;
                                  SuperView     : AnActiveView;
                                  Ulx           : ascreenx;
                                  Uly           : ascreeny;
                                  Lrx           : ascreenx;
                                  Lry           : ascreeny;
                                  Box           : ABoxType;
                                  VideoMode     : avidmode;
                              VAR Title         : ARRAY OF CHAR;
                                  HelpKey       : CARDINAL;
                                  TakeRug       : BOOLEAN        ) 
                                                                  : BOOLEAN;

VAR
    ErrorMarker             : AnErrorMarker;
    ok                      : BOOLEAN;

BEGIN                       (* CreateLayoutOutline *)

    ok := FALSE;
    ErrorMarker := NewMarker();
    IF (Available(TSIZE(XLayoutOutlineRecord))) THEN
        ALLOCATE(LayoutOutline, TSIZE(XLayoutOutlineRecord));
        InitAsLayoutOutline(LayoutOutline, SuperView, Ulx, Uly, Lrx, Lry, Box,
                          VideoMode, Title, HelpKey, TakeRug);
        ok := NOT ErrorPosted(ErrorMarker);
        IF (NOT ok) THEN
            LayoutOutline^.Methods^.Discard (LayoutOutline);    (* 11/16/88 EGK *)
        END;
    END;
    PopToMarker(ErrorMarker);

    RETURN ok;

END CreateLayoutOutline;







(*----------------------------------------------------------------------------
    UnInitAsLayoutOutline --

    UnInitialize the indicated object as a filter outline view.

    Preconditions:
        The object will be a valid filter outline view object. 

    Postconditions:
        The outline view will be invalidated.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsLayoutOutline(    LayoutOutline : ALayoutOutline);


BEGIN                       (* UnInitAsLayoutOutline *)

    DiscardSubViews(XLayoutOutline(LayoutOutline));
    UnInitAsOutlineView(AnOutlineView(LayoutOutline));

END UnInitAsLayoutOutline;







(*----------------------------------------------------------------------------
    CloneLayoutOutlineMethods --

    Make a copy of the filter outline methods into the indicated method 
    object.

    Preconditions:
        None.

    Postcondition:
        The filter outline methods will be copied into the indicated 
        method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneLayoutOutlineMethods(    MethodObject : ALayoutOutlineMethods);

BEGIN                       (* CloneLayoutOutlineMethods *)

    MethodObject^ := LayoutOutlineMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(LayoutOutlineMethodsRecord);
END CloneLayoutOutlineMethods;








(*----------------------------------------------------------------------------
    ValidateLayoutOutline --

    Determine that the indicated object is in fact a valid filter outline view 
    object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid filter outline view object, FatalError 
        will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateLayoutOutline(    LayoutOutline : ALayoutOutline);

VAR
    PrivateLayoutOutline      : XLayoutOutline;

BEGIN                       (* ValidateLayoutOutline *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(LayoutOutline));
    END;
      DEBUGGING>*)

    PrivateLayoutOutline := XLayoutOutline(LayoutOutline);
    IF (PrivateLayoutOutline^.Methods^.LayoutOutlineTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateLayoutOutline;





BEGIN                       (* LayoutOutlines *)

    CloneOutlineViewMethods(ADR(LayoutOutlineMethodsRecord));
    WITH LayoutOutlineMethodsRecord DO
        MethodSize := TSIZE(ALayoutOutlineMethodsRecord);
        Discard := ALayoutOutlineDiscardProc(LayoutOutlineDiscard);
        ActOnEvent := ALayoutOutlineActOnProc (LayoutOutlineActOn);
        LayoutOutlineTag := ModuleNumber;
    END;

END LayoutOutlines.
