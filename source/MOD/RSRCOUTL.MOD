IMPLEMENTATION MODULE RsrcOutlines;        (*  a subclass of OutlineViews  *)

(*V9=DEBUGGING Code*)

(*  =========================================================================
    Last Edit : March 16, 1990 9:48AM by KKC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

      RSC  Oct 28, 87  Moved up resource cursor to be over the (taller) form.
                       Its taller because I added a shadow to it.
      RSC  Jan 28 88   Import Available from Space, not Storage.
      16-Nov-88 EGK    CreateResourceOutline Discards if error is posted.
      10-Jan-89 RSC    Changed Storage to Space    .
       4-Jun-89 EGK    Changed callers of ResourceIsUsed to take a node
                       instead of a pointer.  Changed calls to NotifyUndo
                       into calls to SendNotices.
      10-Jun-89 WKH    Added support for variable screen rows  
      31-Jul-89 KKC    Call ContinuationBox instead of NoYes.
      14-Aug-89 EGK    Import "ResourceIsUsed" from RsrcUsed instead of
                       from Changer.
      18-Sep-89 WKH    Don't allow CopyKey on a subset list created by
                       QuickPick
      25-Oct-89 EGK    In DoDeleteKey, moved the call to ResetMatching
                       after the node is removed.  This fixed a bug where
                       the set of matching characters was out of synch with
                       the actual contents of the list.
      27-Dec-89 LAA    Added MouseDownRegion to the object record definition,
                       so we can limit mouse actions to the screen region on 
                       which the mouse button was originally pressed.
       5-Jan-90 LAA    Moved the location of MouseDownRegion, because this
                       instance variable is now defined in ListViews instead
                       of OutlineViews.
                       Also moved the initialization of TypeThroughEnabled,
                       as it's now init'ed to FALSE by InitAsOutlineView.
      21-Feb-90 KKC    Remove import of Timeu.
      04-Jun-90 AJL    Remove import of RsrcMod.ACostPlace.
    =========================================================================
*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

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
    (* CONST *)                 Up, Down, PgUpKey, PgDnKey, HomeKey, EndKey,
                                CancelKey,
                                InsertKey, DeleteKey, EditKey, CopyKey,
                                PromoteKey, DemoteKey, MoveUpKey, MoveDownKey,
                                UndoKey, RedoKey, AltUndoKey;

FROM LStrings               IMPORT
    (* PROC *)                  SubStr, ConcatLS, Copy, SetString,
                                SetLengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM ObjectID               IMPORT
    (* PROC *)                  NewID;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineViewMethods, AnOutlineView,
    (* PROC *)                  InitAsOutlineView, UnInitAsOutlineView,
                                ValidateOutlineView, CloneOutlineViewMethods;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM RsrcEdit               IMPORT
    (* PROC *)                  DoResourceForm;

FROM RsrcMod                IMPORT
    (* TYPE *)                  AResourcePointer, ACostStyle, 
                                AResourceType,
    (* VAR  *)                  ResourceTree,
    (* PROC *)                  CreateResource, RemoveResource, AddResource,
                                CopyResourceNode,
                                InitializeResource, ChangedResource;

FROM RsrcUsed               IMPORT
    (* PROC *)                  ResourceIsUsed;

FROM RsrcViews              IMPORT
    (* TYPE *)                  AResourceView,
    (* PROC *)                  CreateResourceView;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM Schedule               IMPORT
    (* VAR  *)                  ScheduleSaved;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTreeNode;

FROM Undo                   IMPORT
    (* TYPE *)                  AnUndoableObject, AnUndoAction,
    (* PROC *)                  NotifyUndo, BeginTransactionSet, EndTransactionSet,
                                AbortTransactionSet, DebugUndo, UndoLastChange;


CONST
    ModuleNumber            = 16500;

TYPE
        (*  AResourceOutline is a subclass of AnOutlineView  *)

    XResourceOutline         = POINTER TO XResourceOutlineRecord;

    XResourceOutlineRecord   = RECORD
                                Methods        : AResourceOutlineMethods;
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
                                Status         : AResourceOutlineStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                    AResourceView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                                  (* New fields for outline views *)
                                MatchCount          : CARDINAL;
                                MatchString         : ARRAY [0..80] OF CHAR;
                                TypeThroughEnabled  : BOOLEAN;
                                MatchCodeSet        : ASetOfCodes;
                                NameProc            : AGoToNameProc;
                              END;




VAR
    ResourceOutlineMethodsRecord    : AResourceOutlineMethodsRecord;





PROCEDURE DiscardSubViews(    ResourceOutline   : XResourceOutline);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    WITH ResourceOutline^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;
        Cursor := 0;
    END;

END DiscardSubViews;




PROCEDURE GetResourceName   (    Node       : ATreeNode;
                             VAR s          : ARRAY OF CHAR );
VAR
    Resource            : AResourcePointer;

BEGIN               (* ResourceViewGetTitle *)

    Resource := Node^.Methods^.GetDataObject (Node);
    Copy (Resource^.Name, s);

END GetResourceName;






PROCEDURE ResourceOutlineDiscard(VAR ResourceOutline : XResourceOutline);

BEGIN                       (* ResourceOutlineDiscard *)

    UnInitAsResourceOutline(AResourceOutline(ResourceOutline));
    DISPOSE(ResourceOutline);

END ResourceOutlineDiscard;





PROCEDURE ResourceOutlineActOn (ResourceOutline : XResourceOutline;
                                Event           : AnEvent;
                            VAR ReturnEvent     : AnEvent          );
CONST
    LineAboveForm = 4;  (* RSC, 10/28/87 *)

VAR
    WantToRecord            : BOOLEAN;
    ErrorMarker             : AnErrorMarker;
    RecordForUndo           : BOOLEAN;
    CursorNode              : ATreeNode;


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



    PROCEDURE ScrollAbove(    Node          : ATreeNode;
                              Position      : CARDINAL)
                                                       : CARDINAL;

    VAR
        i                   : CARDINAL;

    BEGIN                   (* ScrollAbove *)

        WITH ResourceOutline^.Methods^ DO
            i := InquirePosition(AResourceOutline(ResourceOutline), Node);
            IF (i > Position) THEN
                ForceToPosition(AResourceOutline(ResourceOutline), Node, Position);
            END;

            RETURN i;
        END;

    END ScrollAbove;



    PROCEDURE ScrollBack(    Node           : ATreeNode;
                             Position       : CARDINAL);

    BEGIN                   (* ScrollBack *)

        WITH ResourceOutline^.Methods^ DO
            ForceToPosition(AResourceOutline(ResourceOutline), Node, Position);
        END;

    END ScrollBack;



    PROCEDURE DoInsertKey ();
    VAR
        Node                : ATreeNode;
        ResourcePtr         : AResourcePointer;
    BEGIN
        IF (CreateResource (Node)) THEN
            ResourcePtr := Node^.Methods^.GetDataObject (Node);
            ResourcePtr^.ID := NewID();
            WITH ResourceOutline^.Methods^ DO
                AddResource (Node, NIL, CursorNode);
                IF (CursorNode = NIL) THEN
                    SetFirst (AResourceOutline(ResourceOutline), Node);
                END;
                SetCursorNode (AResourceOutline (ResourceOutline), Node);
                CursorNode := Node;
                DoEditKey();
            END;
        ELSE
            PostError (AllocationError, ModuleNumber+8);
        END;
    END DoInsertKey;


    PROCEDURE DoCopyKey ();
    VAR
        Node                : ATreeNode;
        ResourcePtr         : AResourcePointer;
    BEGIN
        IF (CursorNode = NIL) THEN
            PostError (NotPossibleInContextError, ModuleNumber+9);
            RETURN;
        END;

        IF (CreateResource (Node)) THEN
            CopyResourceNode (CursorNode, Node, FALSE);
            ResourcePtr := Node^.Methods^.GetDataObject (Node);
            ResourcePtr^.ID := NewID();
            WITH ResourceOutline^.Methods^ DO
                AddResource (Node, NIL, CursorNode);
                SetCursorNode (AResourceOutline (ResourceOutline), Node);
                CursorNode := Node;
                DoEditKey();
            END;
        ELSE
            PostError (AllocationError, ModuleNumber+8);
        END;
    END DoCopyKey;



    PROCEDURE DoDeleteKey ();
    VAR
        NextNode    : ATreeNode;
        Msg         : ARRAY [0..255] OF CHAR;
        NullString  : ARRAY [0..0] OF CHAR;
        Resource    : AResourcePointer;
    BEGIN
        WITH ResourceOutline^.Methods^ DO
            IF (CursorNode <> NIL) THEN
                SetCursorMode (AResourceOutline(ResourceOutline), videorestingcursor);
                IF (NOT ResourceIsUsed (CursorNode)) THEN
                    GetMessage (ModuleNumber + 5, Msg);
                    Resource := CursorNode^.Methods^.GetDataObject (CursorNode);
                    ConcatLS (Msg, Resource^.Name);
                    ConcatMessage (Msg, ModuleNumber + 6);
                    SetLengthOf(NullString, 0);
                    IF ( ContinuationBox (Msg, NullString, NoHelp) ) THEN
                        NextNode := CursorNode^.Methods^.GetNext (CursorNode);
                        IF (NextNode = NIL) THEN
                            NextNode := CursorNode^.Methods^.GetPrev (CursorNode);
                        END;
                        RemoveResource (CursorNode);
                        IF (ResourceOutline^.Cursor = 1) THEN
                            SetFirst (AResourceOutline (ResourceOutline), NextNode);
                        ELSE
                            Synchronize (AResourceOutline (ResourceOutline));
                        END;
                        ResetMatching (AResourceOutline(ResourceOutline));
                        SetCursorNode (AResourceOutline (ResourceOutline), NextNode);
                    END;
                ELSE            (* "Resource is in use." *)
                    GetMessage ( ModuleNumber+7, Msg );
                    Error( Msg );
                    PostError (NotPossibleInContextError, ModuleNumber+7);
                END;
                SetCursorMode (AResourceOutline(ResourceOutline),
                        ResourceOutline^.VideoMode);
            ELSE                (* "Nothing to delete!" *)
                PostError (NotPossibleInContextError, ModuleNumber+1);
            END;
        END;
    END DoDeleteKey;


    PROCEDURE DoEditKey ();
    VAR
        PrevPosition    : CARDINAL;
        ResourcePtr     : AResourcePointer;
        WasChanged      : BOOLEAN;
    BEGIN
        WITH ResourceOutline^ DO
            IF (CursorNode <> NIL) THEN
                Methods^.SetCursorMode (AResourceOutline(ResourceOutline), videorestingcursor);
                PrevPosition := ScrollAbove (CursorNode, LineAboveForm);
                Methods^.Display (AResourceOutline(ResourceOutline));
                ResourcePtr := CursorNode^.Methods^.GetDataObject (CursorNode);
                IF (ResourceIsUsed (CursorNode)) THEN
                    ResourcePtr^.WorkSpace := ResourcePtr;
                ELSE
                    ResourcePtr^.WorkSpace := NIL;
                END;
                SendNotices (ChangeAResource, BeforeActing, CursorNode);     (* 6/4/89 EGK *)
                WasChanged := (DoResourceForm (ResourcePtr) <> CancelKey);
                ScrollBack (CursorNode, PrevPosition);
                IF (WasChanged) THEN
                    Methods^.ResetMatching (AResourceOutline(ResourceOutline));
                    ChangedResource (CursorNode);
                    IF (CursorNode = ResourceTree^.Methods^.GetFirst (ResourceTree)) THEN
                        Methods^.SetFirst (AResourceOutline(ResourceOutline), CursorNode);
                    ELSE
                        Methods^.Synchronize (AResourceOutline(ResourceOutline));
                    END;
                    Methods^.SetCursorNode (AResourceOutline(ResourceOutline), CursorNode);
                ELSE
                    AbortTransactionSet();
                END;
                Methods^.SetCursorMode (AResourceOutline(ResourceOutline), VideoMode);
            ELSE
                DoInsertKey ();
            END;
        END;
    END DoEditKey;



BEGIN               (* ResourceOutlineActOn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateResourceOutline (AResourceOutline (ResourceOutline));
    END;
      DEBUGGING>*)

    ErrorMarker := NewMarker ();

    CASE Event.EventCode OF
(*      Up, Down, PgUpKey, PgDnKey, HomeKey, EndKey,    *)
        InsertKey, DeleteKey, EditKey, CopyKey :
            RecordForUndo := TRUE;
    ELSE
        RecordForUndo := FALSE;
    END;

    IF (RecordForUndo) THEN
        NotifyUndo (Resource, ChartActive, ResourceOutline);
        BeginTransactionSet();
    END;

    CASE Event.EventCode OF
        PromoteKey,
        DemoteKey,
        MoveUpKey,
        MoveDownKey :
            IF (NOT ResourceOutline^.Methods^.FindChar
                    (AResourceOutline(ResourceOutline),CHR(Event.EventCode))) THEN
                PostError (NotPossibleInContextError, ModuleNumber+1);
            ELSE
                Event.EventCode := 0;
            END;
    ELSE
            ResourceOutlineMethodsRecord.SuperclassMethods^.ActOnEvent
                (AnOutlineView (ResourceOutline), Event, ReturnEvent);
            Event := ReturnEvent;
    END;

    ReturnEvent.EventCode := 0;
    WantToRecord := TRUE;

    CursorNode := ResourceOutline^.Methods^.GetCursorNode
            (AResourceOutline(ResourceOutline));

    CASE Event.EventCode OF

        InsertKey :
            DoInsertKey ();

    |   DeleteKey :
            DoDeleteKey ();

    |   EditKey :
            DoEditKey ();

    |   CopyKey :
            WITH ResourceOutline^ DO
                IF (MatchCount > 0) THEN                 (* 18-Sep-89 LAA *)
                    WITH ResourceOutlineMethodsRecord.SuperclassMethods^ DO
                        ActOnEvent(AnOutlineView(ResourceOutline),Event,
                                    ReturnEvent);
                    END;
                    WantToRecord := (ReturnEvent.EventCode <> 0);
                ELSE
                    DoCopyKey ();
                END;
            END;

    |   RedoKey :
            NotifyUndo (Resource, ChartActive, ResourceOutline);
            IF (NOT UndoLastChange(TRUE)) THEN
                PostError (NotPossibleInContextError, ModuleNumber+2);
            END;


        (* Undo but don't set up for redo (i.e. undo multiples)  *)

    |   UndoKey :
            NotifyUndo (Resource, ChartActive, ResourceOutline);
            IF (NOT UndoLastChange(FALSE)) THEN
                PostError (NotPossibleInContextError, ModuleNumber+2);
            END;

    |   AltUndoKey :
            DebugUndo();

    ELSE
        ReturnEvent := Event;
        WantToRecord := FALSE;
    END;

    IF (WantToRecord) THEN
        ResourceOutline^.Methods^.RecordEvent
                (AResourceOutline (ResourceOutline), Event);
    END;

    IF (RecordForUndo) THEN
        EndTransactionSet();
    END;

    IF (ErrorPosted (ErrorMarker)) THEN
        HandleErrors (ErrorMarker);
    END;
    PopToMarker (ErrorMarker);

END ResourceOutlineActOn;





(*----------------------------------------------------------------------------
    InitAsResourceOutline --

    Initialize the indicated object as a resource outline view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid resource outline view object.  No storage 
        allocation is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsResourceOutline(    ResourceOutline : AResourceOutline;
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
    PrivateResourceOutline      : XResourceOutline;
    y                       : ascreeny;

BEGIN                       (* InitAsResourceOutline *)

    InitAsOutlineView(AnOutlineView(ResourceOutline), SuperView, Ulx, Uly, Lrx,
                      Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    PrivateResourceOutline := XResourceOutline(ResourceOutline);
    WITH PrivateResourceOutline^ DO
        TypeThroughEnabled := TRUE;
        NameProc := GetResourceName;
        Methods := ADR(ResourceOutlineMethodsRecord);
        Last := 0;
        FOR y := Uly TO Lry DO
            IF (NOT CreateResourceView(SubView[Last + 1], AnActiveView(ResourceOutline), 
                                   Ulx, y, Lrx, y, ABoxType{NoBox}, VideoMode, 
                                   HelpKey)) THEN
                DiscardSubViews(PrivateResourceOutline);

                PostError(ModuleNumber, AllocationError);
    
                RETURN;
            END;
            INC(Last);
        END;
    END;

END InitAsResourceOutline;





(*----------------------------------------------------------------------------
    CreateResourceOutline --

    Allocate storage for, and initialize the indicated object as a resource 
    outline view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid resource outline view object, and 
        TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateResourceOutline(VAR ResourceOutline : AResourceOutline;
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

BEGIN                       (* CreateResourceOutline *)

    ok := FALSE;
    ErrorMarker := NewMarker();
    IF (Available(TSIZE(XResourceOutlineRecord))) THEN
        ALLOCATE(ResourceOutline, TSIZE(XResourceOutlineRecord));
        InitAsResourceOutline(ResourceOutline, SuperView, Ulx, Uly, Lrx, Lry, Box,
                          VideoMode, Title, HelpKey, TakeRug);

        ok := NOT ErrorPosted(ErrorMarker);
        IF (NOT ok) THEN
            ResourceOutline^.Methods^.Discard (ResourceOutline);    (* 11/16/88 EGK *)
        END;
    END;
    PopToMarker(ErrorMarker);

    RETURN ok;

END CreateResourceOutline;







(*----------------------------------------------------------------------------
    UnInitAsResourceOutline --

    UnInitialize the indicated object as a resource outline view.

    Preconditions:
        The object will be a valid resource outline view object. 

    Postconditions:
        The outline view will be invalidated.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsResourceOutline(    ResourceOutline : AResourceOutline);


BEGIN                       (* UnInitAsResourceOutline *)

    DiscardSubViews(XResourceOutline(ResourceOutline));
    UnInitAsOutlineView(AnOutlineView(ResourceOutline));

END UnInitAsResourceOutline;







(*----------------------------------------------------------------------------
    CloneResourceOutlineMethods --

    Make a copy of the resource outline methods into the indicated method 
    object.

    Preconditions:
        None.

    Postcondition:
        The resource outline methods will be copied into the indicated 
        method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneResourceOutlineMethods(    MethodObject : AResourceOutlineMethods);

BEGIN                       (* CloneResourceOutlineMethods *)

    MethodObject^ := ResourceOutlineMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(ResourceOutlineMethodsRecord);
END CloneResourceOutlineMethods;








(*----------------------------------------------------------------------------
    ValidateResourceOutline --

    Determine that the indicated object is in fact a valid resource outline view 
    object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid resource outline view object, FatalError 
        will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateResourceOutline(    ResourceOutline : AResourceOutline);

VAR
    PrivateResourceOutline      : XResourceOutline;

BEGIN                       (* ValidateResourceOutline *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(ResourceOutline));
    END;
      DEBUGGING>*)

    PrivateResourceOutline := XResourceOutline(ResourceOutline);
    IF (PrivateResourceOutline^.Methods^.ResourceOutlineTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateResourceOutline;





BEGIN                       (* ResourceOutlines *)

    CloneOutlineViewMethods(ADR(ResourceOutlineMethodsRecord));
    WITH ResourceOutlineMethodsRecord DO
        MethodSize := TSIZE(AResourceOutlineMethodsRecord);
        Discard := AResourceOutlineDiscardProc(ResourceOutlineDiscard);
        ActOnEvent := AResourceOutlineActOnProc (ResourceOutlineActOn);
        ResourceOutlineTag := ModuleNumber;
    END;

END RsrcOutlines.

