(*V9=DEBUGGING Code*)

IMPLEMENTATION MODULE NetLOutlines;        (*  a subclass of OutlineViews  *)

    (*  MODIFICATION HISTORY
        23-Feb-88 LAA   Fixed bug with type-through of 2, 4, 6, 9 and 0 by
                        bringing code over from layoutou.mod.
        16-Nov-88 EGK   CreateNetLOutline Discards if error is posted.
        10-Jan-89 RSC   Change Storage to Space.
        10-Jun-89 WKH   Added variable screen row support
        31-Jul-89 KKC   Call ContinuationBox instead of NoYes.
        25-Sep-89 EGK   Moved procs from NetLayouts to NetLUtility.
        27-Dec-89 LAA   Added MouseDownRegion to the object record definition,
                        so we can limit mouse actions to the screen region on 
                        which the mouse button was originally pressed.
         5-Jan-90 LAA   Moved the location of MouseDownRegion, because this
                        instance variable is now defined in ListViews instead
                        of OutlineViews.
                        Also moved the initialization of TypeThroughEnabled,
                        as it's now init'ed to FALSE by InitAsOutlineView.
    *)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Codes                  IMPORT
    (* TYPE *)                  ASetOfCodes;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Burp, Error, FatalError, ContinuationBox;

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

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, ConcatLS, TrimRear, Copy, 
                                LengthOf, SetString, SetLengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NetLayoutTree;

FROM NetLUtility            IMPORT
    (* PROC *)                  CreateNetLayout, DiscardNetLayout,
                                SortNetLayouts;

FROM NetLList               IMPORT
    (* PROC *)                  DoNetLayoutForm;

FROM NetLViews              IMPORT
    (* TYPE *)                  ANetLView,
    (* PROC *)                  CreateNetLView;

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

FROM Space              IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

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
        (*  ANetLOutline is a subclass of AnOutlineView  *)

    XNetLOutline            = POINTER TO XNetLOutlineRecord;

    XNetLOutlineRecord      = RECORD
                                Methods        : ANetLOutlineMethods;
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
                                Status         : ANetLOutlineStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                    ANetLView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                                  (* New fields for outline views *)
                                MatchCount          : CARDINAL;
                                MatchString         : ARRAY [0..80] OF CHAR;
                                TypeThroughEnabled  : BOOLEAN;
                                MatchCodeSet        : ASetOfCodes;
                                NameProc            : AGoToNameProc;
                              END;


    ANetLOutlineDiscardProc = PROCEDURE (VAR ANetLOutline);

    ANetLOutlineActOnProc   = PROCEDURE(    ANetLOutline,
                                            AnEvent,
                                        VAR AnEvent      );

VAR
    NetLOutlineMethodsRecord : ANetLOutlineMethodsRecord;





PROCEDURE DiscardSubViews(    NetLOutline   : XNetLOutline);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    WITH NetLOutline^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;
        Cursor := 0;
    END;

END DiscardSubViews;




PROCEDURE GetNetLName   (    Node       : ATreeNode;
                         VAR s          : ARRAY OF CHAR);
VAR
    NetLPtr         : ANetworkLayout;

BEGIN               (* NetLViewGetTitle *)

    NetLPtr := Node^.Methods^.GetDataObject (Node);
    Copy (NetLPtr^.Name, s);

END GetNetLName;






PROCEDURE NetLOutlineDiscard(VAR NetLOutline : XNetLOutline);

BEGIN                       (* NetLOutlineDiscard *)

    UnInitAsNetLOutline(ANetLOutline(NetLOutline));
    DISPOSE(NetLOutline);

END NetLOutlineDiscard;



PROCEDURE NetLOutlineActOn (    NetLOutline     : XNetLOutline;
                                Event           : AnEvent;
                            VAR ReturnEvent     : AnEvent      );
VAR
    WantToRecord            : BOOLEAN;
    ErrorMarker             : AnErrorMarker;
    NetL                    : ANetworkLayout;
    Msg                     : ARRAY [0..255] OF CHAR;
    Node, FirstNode         : ATreeNode;

CONST
    LineAboveNetLForm     = 7;


    PROCEDURE CursorOnBlankNetL(): BOOLEAN;

    VAR
        Node                : ATreeNode;
        NetL                : ANetworkLayout;
        s                   : ARRAY [0..80] OF CHAR;

    BEGIN                   (* CursorOnBlankNetL *)

        WITH NetLOutline^.Methods^ DO
            Node := GetCursorNode(ANetLOutline(NetLOutline));
            IF (Node <> NIL) THEN
                NetL := Node^.Methods^.GetDataObject(Node);
                Copy(NetL^.Name, s);
                TrimRear(s);
                RETURN (LengthOf(s) = 0);
            END;

            RETURN FALSE;           (* so insert & edit keys will work *)
        END;

    END CursorOnBlankNetL;



    PROCEDURE ScrollAbove(    Node          : ATreeNode;
                              Position      : CARDINAL)
                                                       : CARDINAL;

    VAR
        i                   : CARDINAL;

    BEGIN                   (* ScrollAbove *)

        WITH NetLOutline^.Methods^ DO
            i := InquirePosition(ANetLOutline(NetLOutline), Node);
            IF (i > Position) THEN
                ForceToPosition(ANetLOutline(NetLOutline), Node, Position);
            END;

            RETURN i;
        END;

    END ScrollAbove;



    PROCEDURE ScrollBack(    Node           : ATreeNode;
                             Position       : CARDINAL);

    BEGIN                   (* ScrollBack *)

        WITH NetLOutline^.Methods^ DO
            ForceToPosition(ANetLOutline(NetLOutline), Node, Position);
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
        PrevPosition        : CARDINAL;
        CursorNode          : ATreeNode;
        WasAdded            : BOOLEAN;

    BEGIN

        WITH NetLOutline^.Methods^ DO
            CursorNode := GetCursorNode(ANetLOutline(NetLOutline));
            IF (CreateNetLayout (Node)) THEN
                IF (CursorNode <> NIL) THEN
                    CursorNode^.Methods^.AddAfter(CursorNode, Node);
                ELSE
                    NetLayoutTree^.Methods^.AddFirst(NetLayoutTree, Node);
                    SetFirst(ANetLOutline(NetLOutline), Node);
                END;
                Synchronize(ANetLOutline(NetLOutline));
                SetCursorNode(ANetLOutline(NetLOutline), Node);
                PrevPosition := ScrollAbove(Node, LineAboveNetLForm);
                
                SetCursorMode(ANetLOutline(NetLOutline), videorestingcursor);

                Display(ANetLOutline(NetLOutline));
                
                WasAdded := (DoNetLayoutForm(Node) <> CancelKey);
                SetCursorMode(ANetLOutline(NetLOutline), 
                              NetLOutline^.VideoMode);
                IF (WasAdded) THEN
                    ScrollBack(Node, PrevPosition);
                    SortNetLayouts();
                    Synchronize(ANetLOutline(NetLOutline));
                    NetLOutline^.Methods^.ResetMatching (ANetLOutline(NetLOutline));
                    SetCursorNode(ANetLOutline(NetLOutline), Node);
                ELSE
                    Node^.Methods^.DeList(Node);
                    IF (Node = GetFirst(ANetLOutline(NetLOutline))) THEN
                        SetFirst(ANetLOutline(NetLOutline), CursorNode);
                    END;
                    DiscardNetLayout(Node);
                    ScrollBack(CursorNode, PrevPosition - 1);
                    SetCursorNode(ANetLOutline(NetLOutline), CursorNode);
                END;
            ELSE
                PostError (AllocationError, ModuleNumber+5);
            END;
        END;

    END DoInsertKey;




    PROCEDURE DoDeleteKey ();

    VAR
        NextNode                : ATreeNode;
        OkToDelete              : BOOLEAN;
        PrivateNetLOutline      : XNetLOutline;
        Msg                     : ARRAY [0..255] OF CHAR;
        Node                    : ATreeNode;


        PROCEDURE GetApproval   ( Node  : ATreeNode ) : BOOLEAN;
        VAR
            OK          : BOOLEAN;
            NullString  : ARRAY [0..0] OF CHAR;
        BEGIN
            NetL := Node^.Methods^.GetDataObject(Node);
            GetMessage(ModuleNumber, Msg);
            ConcatLS(Msg, NetL^.Name);
            TrimRear(Msg);
            ConcatMessage(Msg, ModuleNumber + 1);
            SetLengthOf(NullString, 0);
            OK := ContinuationBox (Msg, NullString, NoHelp);
            IF (OK) AND (0 IN NetL^.NetLFlags) THEN
                GetMessage (ModuleNumber + 7, Msg);
                OK := ContinuationBox (Msg, NullString, NoHelp);
            END;
            RETURN OK;
        END GetApproval;


    BEGIN                   (* DoDeleteKey *)

        IF (CursorOnBlankNetL()) THEN
            PostError(NotPossibleInContextError, ModuleNumber + 2);
            RETURN;
        END;

        WITH NetLOutline^ DO
            WITH Methods^ DO
                Node := GetCursorNode(ANetLOutline(NetLOutline));
                IF (Node <> NIL) THEN
                    SetCursorMode(ANetLOutline(NetLOutline),videorestingcursor);
                    Display(ANetLOutline(NetLOutline));
                    OkToDelete := GetApproval (Node);
                    SetCursorMode(ANetLOutline(NetLOutline), VideoMode);
                    IF (OkToDelete) THEN
                        NextNode := Node^.Methods^.GetNext (Node);
                        IF (NextNode = NIL) THEN
                            NextNode := Node^.Methods^.GetPrev (Node);
                        END;
                        DiscardNetLayout(Node);
                        IF (NetLOutline^.Cursor = 1) THEN
                            SetFirst(ANetLOutline(NetLOutline), NextNode);
                        ELSE 
                            Synchronize(ANetLOutline(NetLOutline));
                        END;
                        NetLOutline^.Methods^.ResetMatching (ANetLOutline(NetLOutline));
                        SetCursorNode(ANetLOutline(NetLOutline), NextNode);
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
        NetL                : ANetworkLayout;
        PrevPosition        : CARDINAL;
        Node                : ATreeNode;

    BEGIN                   (* DoEditKey *)

        WITH NetLOutline^.Methods^ DO
            Node := GetCursorNode(ANetLOutline(NetLOutline));
            PrevPosition := ScrollAbove(Node, LineAboveNetLForm);
            IF (NOT CursorOnBlankNetL()) THEN
                SetCursorMode(ANetLOutline(NetLOutline),videorestingcursor);
                Display(ANetLOutline(NetLOutline));
                IF (DoNetLayoutForm(Node) <> CancelKey) THEN
                    SortNetLayouts ();
                    NetLOutline^.Methods^.ResetMatching (ANetLOutline(NetLOutline));
                END;
                SetCursorMode(ANetLOutline(NetLOutline),NetLOutline^.VideoMode);
                SetCursorNode(ANetLOutline(NetLOutline), Node);
            ELSIF (Node^.Methods^.GetNext(Node) = NIL) THEN
                DoInsertKey ();
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 2);
            END;
            ScrollBack(Node, PrevPosition);
        END;

    END DoEditKey;



    PROCEDURE DoCopyKey ();

    VAR
        OldNetL             : ANetworkLayout;
        NetL                : ANetworkLayout;
        CNode               : ATreeNode;
        Node                : ATreeNode;
        PrevPosition        : CARDINAL;

    BEGIN

        IF (CursorOnBlankNetL()) THEN
            PostError(NotPossibleInContextError, ModuleNumber + 2);
            RETURN;
        END;

        WITH NetLOutline^.Methods^ DO
            CNode := GetCursorNode(ANetLOutline(NetLOutline));
            IF (CNode <> NIL) THEN
                OldNetL := CNode^.Methods^.GetDataObject(CNode);
                IF (CreateNetLayout (Node)) THEN
                    NetL := Node^.Methods^.GetDataObject (Node);
                    NetL^ := OldNetL^;
                    NetL^.Notes := AText(NIL);
                    IF (AssignText(OldNetL^.Notes, NetL^.Notes)) THEN END;
                    CNode^.Methods^.AddAfter(CNode, Node);
                    Synchronize(ANetLOutline(NetLOutline));
                    SetCursorNode(ANetLOutline(NetLOutline), Node);
                    PrevPosition := ScrollAbove(Node, LineAboveNetLForm);
                    SetCursorMode(ANetLOutline(NetLOutline),videorestingcursor);
                    Display(ANetLOutline(NetLOutline));
                    IF (DoNetLayoutForm(Node) = CancelKey) THEN
                        DiscardNetLayout(Node);
                        Node := CNode;
                    ELSE
                        NetLOutline^.Methods^.ResetMatching (ANetLOutline(NetLOutline));
                        SortNetLayouts ();
                    END;
                    SetCursorMode(ANetLOutline(NetLOutline),NetLOutline^.VideoMode);
                    SetCursorNode(ANetLOutline(NetLOutline), Node);
                    ScrollBack(Node, PrevPosition);
                END;
            ELSE
                PostError (NotPossibleInContextError, ModuleNumber);
            END;
        END;

    END DoCopyKey;


BEGIN               (* NetLOutlineActOn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateNetLOutline(ANetLOutline(NetLOutline));
    END;
      DEBUGGING>*)

    ErrorMarker := NewMarker ();

    ReturnEvent.EventCode := 0;
    WantToRecord := TRUE;

    WITH NetLOutline^ DO
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
                    IF (MatchCount > 0) THEN                      (* 23-Feb-88 LAA *)
                        WITH NetLOutlineMethodsRecord.SuperclassMethods^ DO
                            ActOnEvent(AnOutlineView(NetLOutline),Event,
                                       ReturnEvent);
                        END;
                        WantToRecord := (ReturnEvent.EventCode <> 0);
                    ELSE
                        DoCopyKey ();
                    END;
            |   PromoteKey, DemoteKey, MoveUpKey, MoveDownKey, OpenKey, 
                CloseKey :
                    IF (NOT Methods^.FindChar                     (* 23-Feb-88 LAA *)
                            (ANetLOutline(NetLOutline),CHR(Event.EventCode))) THEN
                        PostError (NotPossibleInContextError, ModuleNumber+1);
                    ELSE
                        Event.EventCode := 0;
                    END;
            ELSE
                WITH NetLOutlineMethodsRecord.SuperclassMethods^ DO
                    ActOnEvent(AnOutlineView(NetLOutline),Event,ReturnEvent);
                END;
                WantToRecord := (ReturnEvent.EventCode <> 0);
            END;
        END;

        IF (WantToRecord) THEN
            Methods^.RecordEvent(ANetLOutline(NetLOutline), Event);
        END;
    END;

    IF (ErrorPosted (ErrorMarker)) THEN
        HandleErrors (ErrorMarker);
    END;
    PopToMarker (ErrorMarker);

END NetLOutlineActOn;





(*----------------------------------------------------------------------------
    InitAsNetLOutline --

    Initialize the indicated object as a filter outline view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid filter outline view object.  No storage 
        allocation is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsNetLOutline(    NetLOutline     : ANetLOutline;
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
    PrivateNetLOutline      : XNetLOutline;
    y                       : ascreeny;

BEGIN                       (* InitAsNetLOutline *)

    InitAsOutlineView(AnOutlineView(NetLOutline), SuperView, Ulx, Uly, Lrx,
                      Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    PrivateNetLOutline := XNetLOutline(NetLOutline);
    WITH PrivateNetLOutline^ DO
        TypeThroughEnabled := TRUE;
        NameProc := GetNetLName;
        Methods := ADR(NetLOutlineMethodsRecord);
        Last := 0;
        FOR y := Uly TO Lry DO
            IF (NOT CreateNetLView(SubView[Last + 1], AnActiveView(NetLOutline), 
                                   Ulx, y, Lrx, y, ABoxType{NoBox}, VideoMode, 
                                   HelpKey)) THEN
                DiscardSubViews(PrivateNetLOutline);

                PostError(ModuleNumber, AllocationError);
    
                RETURN;
            END;
            INC(Last);
        END;
    END;

END InitAsNetLOutline;





(*----------------------------------------------------------------------------
    CreateNetLOutline --

    Allocate storage for, and initialize the indicated object as a filter 
    outline view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid filter outline view object, and 
        TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateNetLOutline(VAR NetLOutline   : ANetLOutline;
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

BEGIN                       (* CreateNetLOutline *)

    ok := FALSE;
    ErrorMarker := NewMarker();
    IF (Available(TSIZE(XNetLOutlineRecord))) THEN
        ALLOCATE(NetLOutline, TSIZE(XNetLOutlineRecord));
        InitAsNetLOutline(NetLOutline, SuperView, Ulx, Uly, Lrx, Lry, Box,
                          VideoMode, Title, HelpKey, TakeRug);

        ok := NOT ErrorPosted(ErrorMarker);
        IF (NOT ok) THEN
            NetLOutline^.Methods^.Discard (NetLOutline);        (* 11/16/88 EGK *)
        END;
    END;
    PopToMarker(ErrorMarker);

    RETURN ok;

END CreateNetLOutline;







(*----------------------------------------------------------------------------
    UnInitAsNetLOutline --

    UnInitialize the indicated object as a filter outline view.

    Preconditions:
        The object will be a valid filter outline view object. 

    Postconditions:
        The outline view will be invalidated.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsNetLOutline(    NetLOutline : ANetLOutline);


BEGIN                       (* UnInitAsNetLOutline *)

    DiscardSubViews(XNetLOutline(NetLOutline));
    UnInitAsOutlineView(AnOutlineView(NetLOutline));

END UnInitAsNetLOutline;







(*----------------------------------------------------------------------------
    CloneNetLOutlineMethods --

    Make a copy of the filter outline methods into the indicated method 
    object.

    Preconditions:
        None.

    Postcondition:
        The filter outline methods will be copied into the indicated 
        method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneNetLOutlineMethods(    MethodObject : ANetLOutlineMethods);

BEGIN                       (* CloneNetLOutlineMethods *)

    MethodObject^ := NetLOutlineMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(NetLOutlineMethodsRecord);
END CloneNetLOutlineMethods;








(*----------------------------------------------------------------------------
    ValidateNetLOutline --

    Determine that the indicated object is in fact a valid filter outline view 
    object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid filter outline view object, FatalError 
        will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateNetLOutline(    NetLOutline : ANetLOutline);

VAR
    PrivateNetLOutline      : XNetLOutline;

BEGIN                       (* ValidateNetLOutline *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(NetLOutline));
    END;
      DEBUGGING>*)

    PrivateNetLOutline := XNetLOutline(NetLOutline);
    IF (PrivateNetLOutline^.Methods^.NetLOutlineTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateNetLOutline;





BEGIN                       (* NetLOutlines *)

    CloneOutlineViewMethods(ADR(NetLOutlineMethodsRecord));
    WITH NetLOutlineMethodsRecord DO
        MethodSize := TSIZE(ANetLOutlineMethodsRecord);
        Discard := ANetLOutlineDiscardProc(NetLOutlineDiscard);
        ActOnEvent := ANetLOutlineActOnProc (NetLOutlineActOn);
        NetLOutlineTag := ModuleNumber;
    END;

END NetLOutlines.
