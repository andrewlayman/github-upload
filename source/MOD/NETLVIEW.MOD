IMPLEMENTATION MODULE NetLViews;          (* Subclass of ActiveViews *)

    (*  NetLViews provides an object which is a view of a tree node.
        The data object of the tree node is a network layout.  The layout
        name is displayed in reverse video if the cursor is on it.

        26-Oct-87 LAA   This module cloned from LayoutViews.
        10-Jan-89 RSC   Changed Storage to Space    .
    *)

(*V9=DEBUGGING Code*)
(*V1=HIER archical layouts *)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveViewMethods, AnActiveView,
    (* PROC *)                  CloneActiveViewMethods, ValidateActiveView,
                                InitAsActiveView, UnInitAsActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString;

FROM MatchNames             IMPORT
    (* PROC *)                  PutMatchedString;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout;

FROM NetLOutlines           IMPORT
    (* TYPE *)                  ANetLOutline;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Procustes, Copy, SetLengthOf, Remove,
                                SubStr;

FROM ObjectViews            IMPORT
    (* TYPE *)                  AnObjectView;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeNodeAttribute,
    (* PROC *)                  ValidateTreeNode;


CONST
    ModuleNumber            = 65000;



TYPE
    XNetLView               = POINTER TO XNetLViewRecord;
        
    XNetLViewRecord         = RECORD
                                Methods        : ANetLViewMethods;
                                ViewObject     : ATreeNode;
                                ParentView     : ANetLOutline;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : ANetLViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                              END;


    ANetLViewDiscardProc   = PROCEDURE (VAR ANetLView);

    ANetLViewDisplayProc   = PROCEDURE (    ANetLView);


VAR
    NetLViewMethodsRecord  : ANetLViewMethodsRecord;




    (*  Following are the procedures which replace the methods inherited from
        ActiveViews.
    *)


PROCEDURE NetLViewDiscard(VAR NetLView  : XNetLView);

BEGIN                       (* NetLViewDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateNetLView(ANetLView(NetLView));
    END;
    DEBUGGING>*)

    UnInitAsNetLView(ANetLView(NetLView));
    DISPOSE(NetLView);

END NetLViewDiscard;





PROCEDURE NetLViewDisplay(    NetLView  : XNetLView);

VAR
    NetLPtr                 : ANetworkLayout;
    s                       : ARRAY [0..80] OF CHAR;
    Count                   : CARDINAL;


BEGIN                       (* NetLViewDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateNetLView(ANetLView(NetLView));
    END;
    DEBUGGING>*)

    WITH NetLView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        IF (ViewObject = NIL) THEN
            Fill (s, " ", Lrx-Ulx+1);
            Count := 0;
        ELSE
            (*<DEBUGGING
            ValidateTreeNode(ViewObject);
            DEBUGGING*)

            NetLPtr := ViewObject^.Methods^.GetDataObject (ViewObject);
            Copy (NetLPtr^.Name, s);
            Procustes (s, Lrx-Ulx+1);
            IF (0 IN NetLPtr^.NetLFlags) THEN
                s[Lrx-Ulx+1] := "*";
            END;
            Count := ParentView^.Methods^.GetMatchCount (ParentView);
        END;
        PutMatchedString (s, Ulx, Uly, Count, VideoMode, CursorMode,
                                (CursorOn IN Status));
        EXCL(Status, NeedsRedisplay);
    END;

END NetLViewDisplay;







    (*  These are the procedures which are exported from this module  *)


(*----------------------------------------------------------------------------
    InitAsNetLView --

    Initialize the indicated object as a layout view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid layout view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsNetLView(    NetLView     : ANetLView;
                             SuperView    : AnActiveView;
                             Ulx          : ascreenx;
                             Uly          : ascreeny;
                             Lrx          : ascreenx;
                             Lry          : ascreeny;
                             Box          : ABoxType;
                             VideoMode    : avidmode;
                             HelpKey      : CARDINAL);

VAR
    s                     : ARRAY [0..1] OF CHAR;
    PrivateNetLView       : XNetLView;

BEGIN                       (* InitAsNetLView *)

    Fill(s, " ", 0);
    InitAsActiveView(AnActiveView(NetLView), AnObjectView(SuperView), Ulx, 
                     Uly, Lrx, Lry, Box, VideoMode, s, HelpKey, FALSE);
    PrivateNetLView := XNetLView(NetLView);
    WITH PrivateNetLView^ DO
        Methods := ANetLViewMethods(ADR(NetLViewMethodsRecord));
    END;

END InitAsNetLView;







(*----------------------------------------------------------------------------
    CreateNetLView --

    Allocate storage for, and initialize the indicated object as a layout 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid layout view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateNetLView(  VAR NetLView     : ANetLView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL)
                                                       : BOOLEAN;

BEGIN                       (* CreateNetLView *)

    IF (Available(TSIZE(XNetLViewRecord))) THEN
        ALLOCATE(NetLView, TSIZE(XNetLViewRecord));
        InitAsNetLView(NetLView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                       VideoMode, HelpKey);
        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateNetLView;







(*----------------------------------------------------------------------------
    UnInitAsNetLView --

    UnInitialize the indicated object as a layout view.

    Preconditions:
        The object will be a valid layout view object.

    Postconditions:
        Whatever was done by InitAsNetLView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsNetLView(    NetLView : ANetLView);

BEGIN                       (* UnInitAsNetLView *)

    UnInitAsActiveView(AnActiveView(NetLView));

END UnInitAsNetLView;












(*----------------------------------------------------------------------------
    CloneNetLViewMethods --

    Make a copy of the layout view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The layout view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneNetLViewMethods(    MethodObject : ANetLViewMethods);

BEGIN                       (* CloneNetLViewMethods *)

    FatalError();

END CloneNetLViewMethods;








(*----------------------------------------------------------------------------
    ValidateNetLView --

    Determine that the indicated object is in fact a valid layout view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid layout view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateNetLView(    NetLView : ANetLView);

BEGIN                       (* ValidateNetLView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(NetLView));
    END;
    DEBUGGING>*)

    IF (NetLView^.Methods^.NetLViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateNetLView;


BEGIN                       (* NetLViews *)

    CloneActiveViewMethods(AnActiveViewMethods(ADR(NetLViewMethodsRecord)));
    WITH NetLViewMethodsRecord DO
        MethodSize := TSIZE(ANetLViewMethodsRecord);
        Discard    := ANetLViewDiscardProc(NetLViewDiscard);
        Display    := ANetLViewDisplayProc(NetLViewDisplay);
        NetLViewTag := ModuleNumber;
    END;

END NetLViews.
