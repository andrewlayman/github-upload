IMPLEMENTATION MODULE DependOutlines;        (*  a subclass of OutlineViews  *)

(*V9=DEBUGGING Code*)

  (* MODIFICATION HISTORY:

        12-Jan-88  RSC  "Unchanged" changes.
        16-Nov-88 EGK   CreateDependOutline Discards if error is posted.
        10-Jan-89 RSC   Changed Storage to Space    .
        21-Mar-89 EGK   Get the edge description from EdgeInfo.DescribeEdge.
        10-Jun-89 WKH   Added varible screen row suppor
        27-Dec-89 LAA   Added MouseDownRegion to the object record definition,
                        so we can limit mouse actions to the screen region on 
                        which the mouse button was originally pressed.
         5-Jan-90 LAA   Moved the location of MouseDownRegion, because this
                        instance variable is now defined in ListViews instead
                        of OutlineViews.
                        Also removed the initialization of TypeThroughEnabled,
                        as this is now set to FALSE in InitAsOutlineView.
                        Commented out GetDependName, as it's no longer needed.
         6-Oct-90 AJL   Added new mouse buttons to those which are passed by.
        22-Jan-90 RSC   Removed NameScale import, which was not used.
  *)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute,
                                AMouseClickPoint,                 (* 12-Dec-89 MWP *)
    (* PROC *)                  CorrelateMousePoint, CorrelateMouseToCode;

FROM Changer                IMPORT
    (* PROC *)                  ChangeEdge;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode, ASetOfCodes;

FROM DependViews              IMPORT
    (* TYPE *)                  ADependView,
    (* PROC *)                  CreateDependView;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, Burp, Error, FatalError;

FROM EdgeInfo               IMPORT
    (* PROC *)                  DescribeEdge;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr;

FROM ErrorCategories        IMPORT
    (* CONST *)                 NotPossibleInContextError, UnknownEventError,
                                AllocationError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker,
                                GetErrorDetails, PostError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  PushEvent;

FROM GoTo                   IMPORT
    (* TYPE *)                  AGoToNameProc;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 AbsoluteMaxRow, maxrow,
    (* PROC *)                  PutString;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey, DoIt,
                                DeleteKey, EditKey, OpenKey, CloseKey,
                                PromoteKey, DemoteKey, MoveUpKey, MoveDownKey,
                                ExitKey, MouseUp,
                                MouseDouble, MouseDown, MouseStillDown;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, ConcatLS, ConcatS, Procustes,
                                LengthOf, SetLengthOf, SetString, Insert, Copy;

FROM Menus                  IMPORT
    (* PROC *)                  NoYes;

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

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeNodeAttribute;


CONST
    ModuleNumber            = 19700;


TYPE
        (*  ADependOutline is a subclass of AnOutlineView  *)

    XDependOutline            = POINTER TO XDependOutlineRecord;

    XDependOutlineRecord      = RECORD
                                Methods        : ADependOutlineMethods;
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
                                Status         : ADependOutlineStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                    ADependView;
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
    DependOutlineMethodsRecord : ADependOutlineMethodsRecord;





PROCEDURE DiscardSubViews(    DependOutline   : XDependOutline);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    WITH DependOutline^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;
        Cursor := 0;
    END;

END DiscardSubViews;



(*   No longer needed - LAA 5-Jan-90
PROCEDURE GetDependName  (    Node        : ATreeNode;
                          VAR s           : ARRAY OF CHAR   );

VAR
    Task            : ATaskPtr;

BEGIN                       (* DependViewTitle *)

    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    Copy (Task^.taskname, s);
    Node^.Methods^.UnlockUnchangedDataObject (Node);

END GetDependName;
*)




PROCEDURE DependOutlineDiscard(VAR DependOutline : XDependOutline);

BEGIN                       (* DependOutlineDiscard *)

    UnInitAsDependOutline(ADependOutline(DependOutline));
    DISPOSE(DependOutline);

END DependOutlineDiscard;




PROCEDURE DependOutlineDisplay (DependOutline   : XDependOutline);

CONST
    StatusLength        = 3;        (* Space used by status chars *)

VAR
    Node                : ATreeNode;
    Task                : ATaskPtr;
    Edge                : AnEdgePtr;
    s                   : ARRAY [0..80] OF CHAR;
    s2                  : ARRAY [0..40] OF CHAR;

BEGIN               (* DependOutlineDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateDependOutline (ADependOutline (DependOutline));
    END;
      DEBUGGING>*)

    DependOutlineMethodsRecord.SuperclassMethods^.Display
            (AnOutlineView (DependOutline));

    WITH DependOutline^ DO

        Node := Methods^.GetCursorNode (ADependOutline (DependOutline));
        IF (Node = NIL) OR
           ((NOT Node^.Methods^.TestAttributeBit (Node, Select1)) AND
            (NOT Node^.Methods^.TestAttributeBit (Node, Select2))) THEN
            Fill (s, " ", Lrx-Ulx+1);
        ELSE
            Task := Node^.Methods^.LockFlexStorDataObject (Node);
            Edge := Task^.WorkSpace;
            Node^.Methods^.UnlockUnchangedDataObject (Node);
            DescribeEdge (Edge, TRUE, s);
            Procustes (s, Lrx-Ulx+1-StatusLength);
            Fill (s2, " ", StatusLength);
            Insert (s, s2, 1);
        END;
        PutString (s, Ulx, Uly, videodatebar);
    END;

END DependOutlineDisplay;




PROCEDURE DependOutlineActOn (  DependOutline   : ADependOutline;
                                Event           : AnEvent;
                            VAR ReturnEvent     : AnEvent        );
VAR
    WantToRecord            : BOOLEAN;
    ErrorMarker             : AnErrorMarker;
    Node                    : ATreeNode;


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



    PROCEDURE  MoveToNewSelection () : BOOLEAN;
    VAR
         SelectedRow             : CARDINAL;
         Node                    : ATreeNode;
         LocalUlx                : ascreenx;
         LocalUly                : ascreeny;
         LocalLrx                : ascreenx;
         LocalLry                : ascreeny;
         ok                      : BOOLEAN;     
         PDependOutline      : XDependOutline;
    BEGIN
         ok := TRUE;

         PDependOutline  :=  XDependOutline(DependOutline);

         WITH DependOutline^ DO
             Methods^.GetInternalXY  ( ADependOutline(DependOutline),
                                       LocalUlx, LocalUly, LocalLrx, LocalLry);

             IF ( LocalUly >= Event.EventY ) THEN
                 IF (Event.EventCode = MouseDown) THEN
                     PostError(NotPossibleInContextError, ModuleNumber);
                 END;
                 ok := FALSE;
             ELSE
                 INC(LocalUly); 

                 SelectedRow := ( Event.EventY - LocalUly ) + 1;

                 Node := ATreeNode(PDependOutline^.SubView[SelectedRow]^.Methods^.GetObject(PDependOutline^.SubView[SelectedRow]));
        
                 IF (Node <> NIL) THEN
                     Methods^.SetCursorNode(ADependOutline(DependOutline), Node);
                 ELSIF (Event.EventCode = MouseDown) THEN
                     PostError(NotPossibleInContextError, ModuleNumber);
                     ok := FALSE;
                 END;
             END;
         END;

         RETURN ok;

    END MoveToNewSelection;



    PROCEDURE ProcessMouseEvent () : BOOLEAN;
    VAR
        MouseArea           : AMouseClickPoint;
        ok                  : BOOLEAN;
        LocalUlx            : ascreenx;
        LocalUly            : ascreeny;
        LocalLrx            : ascreenx;
        LocalLry            : ascreeny;
        PDependOutline      : XDependOutline;
        LocalEvent          : AnEvent;
    BEGIN

        ok := TRUE;

        PDependOutline  :=  XDependOutline(DependOutline);

        WITH PDependOutline^ DO
            Methods^.GetExternalXY  ( ADependOutline(PDependOutline),
                                      LocalUlx, LocalUly, LocalLrx, LocalLry);

            MouseArea := CorrelateMousePoint ( LocalUlx, LocalUly, LocalLrx, LocalLry, PDependOutline^.Box,
                                               Event.EventX, Event.EventY );
            IF (Event.EventCode = MouseDown) THEN              (* 27-Dec-89 *)
                MouseDownRegion := ORD(MouseArea);
            ELSIF (MouseDownRegion <> ORD(MouseArea)) THEN
                RETURN FALSE;
            END;
        END;

        ReturnEvent.EventCode := 0;

        CASE MouseArea OF
            OnInside :
               CASE Event.EventCode OF
                   MouseUp, MouseDown, MouseStillDown :
                       ok := MoveToNewSelection ();
                       ok := TRUE;
               |   MouseDouble :
                       LocalEvent := Event;
                       LocalEvent.EventCode := DoIt;
                       PushEvent ( LocalEvent );
               ELSE
               END;

         |  OnVScrollUp, OnVScrollDown, OnOk, OnCancel, OnHelp,
            OnInsert, OnDelete, OnEdit :
               ok := FALSE;

        ELSE
            IF (Event.EventCode = MouseDown) THEN
               PostError(NotPossibleInContextError, ModuleNumber);
            END;
        END;

        RETURN ok;

    END ProcessMouseEvent;






BEGIN               (* DependOutlineActOn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateDependOutline (DependOutline);
    END;
      DEBUGGING>*)

    ErrorMarker := NewMarker ();

    CASE Event.EventCode OF
        OpenKey,
        CloseKey,
        PromoteKey,
        DemoteKey,
        MoveUpKey,
        MoveDownKey :;

    |   MouseUp, MouseDown, MouseStillDown, MouseDouble :
                IF ( NOT ProcessMouseEvent () ) THEN
                    DependOutlineMethodsRecord.SuperclassMethods^.ActOnEvent
                     (AnOutlineView (DependOutline), Event, ReturnEvent);
                END;

                Event := ReturnEvent;
    ELSE
            DependOutlineMethodsRecord.SuperclassMethods^.ActOnEvent
                (AnOutlineView (DependOutline), Event, ReturnEvent);
            Event := ReturnEvent;
    END;

    ReturnEvent := Event;

    IF (ErrorPosted (ErrorMarker)) THEN
        HandleErrors (ErrorMarker);
    END;
    PopToMarker (ErrorMarker);

END DependOutlineActOn;





(*----------------------------------------------------------------------------
    InitAsDependOutline --

    Initialize the indicated object as a dependency outline.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid dependency outline object.  No storage 
        allocation is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsDependOutline(  DependOutline   : ADependOutline;
                                SuperView       : AnActiveView;
                                Ulx             : ascreenx;
                                Uly             : ascreeny;
                                Lrx             : ascreenx;
                                Lry             : ascreeny;
                                Box             : ABoxType;
                                VideoMode       : avidmode;
                            VAR Title           : ARRAY OF CHAR;
                                HelpKey         : CARDINAL;
                                TakeRug         : BOOLEAN      );

VAR
    PrivateDependOutline        : XDependOutline;
    y                           : ascreeny;

BEGIN                       (* InitAsDependOutline *)

    InitAsOutlineView(AnOutlineView(DependOutline), SuperView, Ulx, Uly, Lrx,
                      Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    PrivateDependOutline := XDependOutline(DependOutline);
    WITH PrivateDependOutline^ DO
        Methods := ADR(DependOutlineMethodsRecord);
        Last := 0;
        FOR y := Uly+1 TO Lry DO
            IF (NOT CreateDependView(SubView[Last + 1], AnActiveView(DependOutline), 
                                   Ulx, y, Lrx, y, ABoxType{NoBox}, VideoMode, 
                                   HelpKey)) THEN
                DiscardSubViews(PrivateDependOutline);

                PostError(ModuleNumber, AllocationError);
    
                RETURN;
            END;
            INC(Last);
        END;
    END;

END InitAsDependOutline;





(*----------------------------------------------------------------------------
    CreateDependOutline --

    Allocate storage for, and initialize the indicated object as a dependency 
    outline.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid dependency outline object, and 
        TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateDependOutline(VAR DependOutline : ADependOutline;
                                    SuperView   : AnActiveView;
                                    Ulx         : ascreenx;
                                    Uly         : ascreeny;
                                    Lrx         : ascreenx;
                                    Lry         : ascreeny;
                                    Box         : ABoxType;
                                    VideoMode   : avidmode;
                                VAR Title       : ARRAY OF CHAR;
                                    HelpKey     : CARDINAL;
                                    TakeRug     : BOOLEAN       ) 
                                                                 : BOOLEAN;

VAR
    ErrorMarker             : AnErrorMarker;
    ok                      : BOOLEAN;

BEGIN                       (* CreateDependOutline *)

    ok := FALSE;
    ErrorMarker := NewMarker();
    IF (HeapAvailable()) THEN
        ALLOCATE(DependOutline, TSIZE(XDependOutlineRecord));
        InitAsDependOutline(DependOutline, SuperView, Ulx, Uly, Lrx, Lry, Box,
                          VideoMode, Title, HelpKey, TakeRug);

        ok := NOT ErrorPosted(ErrorMarker);
        IF (NOT ok) THEN
            DependOutline^.Methods^.Discard (DependOutline);    (* 11/16/88 EGK *)
        END;
    END;

    PopToMarker(ErrorMarker);

    RETURN ok;

END CreateDependOutline;







(*----------------------------------------------------------------------------
    UnInitAsDependOutline --

    UnInitialize the indicated object as a dependency outline.

    Preconditions:
        The object will be a valid dependency outline object. 

    Postconditions:
        The outline will be invalidated.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsDependOutline(    DependOutline : ADependOutline);


BEGIN                       (* UnInitAsDependOutline *)

    DiscardSubViews(XDependOutline(DependOutline));
    UnInitAsOutlineView(AnOutlineView(DependOutline));

END UnInitAsDependOutline;







(*----------------------------------------------------------------------------
    CloneDependOutlineMethods --

    Make a copy of the dependency outline methods into the indicated method 
    object.

    Preconditions:
        None.

    Postcondition:
        The dependency outline methods will be copied into the indicated 
        method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneDependOutlineMethods(    MethodObject : ADependOutlineMethods);

BEGIN                       (* CloneDependOutlineMethods *)

    MethodObject^ := DependOutlineMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(DependOutlineMethodsRecord);
END CloneDependOutlineMethods;








(*----------------------------------------------------------------------------
    ValidateDependOutline --

    Determine that the indicated object is in fact a valid dependency outline 
    object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid dependency outline object, FatalError 
        will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateDependOutline(    DependOutline : ADependOutline);

VAR
    PrivateDependOutline      : XDependOutline;

BEGIN                       (* ValidateDependOutline *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(DependOutline));
    END;
      DEBUGGING>*)

    PrivateDependOutline := XDependOutline(DependOutline);
    IF (PrivateDependOutline^.Methods^.DependOutlineTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateDependOutline;





BEGIN                       (* DependOutlines *)

    CloneOutlineViewMethods(ADR(DependOutlineMethodsRecord));
    WITH DependOutlineMethodsRecord DO
        MethodSize := TSIZE(ADependOutlineMethodsRecord);
        Discard := ADependOutlineDiscardProc(DependOutlineDiscard);
        Display := ADependOutlineProc(DependOutlineDisplay);
        ActOnEvent := ADependOutlineActOnProc (DependOutlineActOn);
        DependOutlineTag := ModuleNumber;
    END;

END DependOutlines.

