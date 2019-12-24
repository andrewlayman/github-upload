IMPLEMENTATION MODULE LayoutViews;          (* Subclass of ActiveViews *)

    (*  LayoutViews provides an object which is a view of a tree node.
        The data object of the tree node is a layout.  Its name is
        displayed using indentation to reflect depth in the tree, and "+"
        and "-" symbols to show whether or not it has children.  The layout
        name is displayed in reverse video if the cursor is on it.

        7/9/87   AJL - Removed references to the Video module.
        07-Dec-87 LAA  Use Available instead of HeapAvailable when creating
                       the LayoutView.
        10-Jan-89 RSC    Changed Storage to Space    .
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

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString;

FROM LayoutOutlines         IMPORT
    (* TYPE *)                  ALayoutOutline;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Procustes, Copy, SetLengthOf, Remove,
                                SubStr;

FROM MatchNames             IMPORT
    (* PROC *)                  PutMatchedString;

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
    ModuleNumber            = 18500;



TYPE
    XLayoutView             = POINTER TO XLayoutViewRecord;
        
    XLayoutViewRecord       = RECORD
                                Methods        : ALayoutViewMethods;
                                ViewObject     : ATreeNode;
                                ParentView     : ALayoutOutline;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : ALayoutViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                              END;


    ALayoutViewDiscardProc = PROCEDURE (VAR ALayoutView   );

    ALayoutViewTitleProc   = PROCEDURE (    ALayoutView,
                                        VAR ARRAY OF CHAR );

    ALayoutViewDisplayProc = PROCEDURE (    ALayoutView   );


VAR
    LayoutViewMethodsRecord : ALayoutViewMethodsRecord;




    (*  Following are the procedures which replace the methods inherited from
        ActiveViews.
    *)


PROCEDURE LayoutViewDiscard(VAR LayoutView  : XLayoutView);

BEGIN                       (* LayoutViewDiscard *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateLayoutView(ALayoutView(LayoutView));
    END;
    (*DEBUGGING>*)

    UnInitAsLayoutView(ALayoutView(LayoutView));
    DISPOSE(LayoutView);

END LayoutViewDiscard;





PROCEDURE LayoutViewDisplay(    LayoutView  : XLayoutView);

VAR
    LayoutPtr               : AChartFormatPtr;
    s                       : ARRAY [0..80] OF CHAR;
    Count                   : CARDINAL;


BEGIN                       (* LayoutViewDisplay *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateLayoutView(ALayoutView(LayoutView));
    END;
    (*DEBUGGING>*)

    WITH LayoutView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        IF (ViewObject = NIL) THEN
            Fill (s, " ", Lrx-Ulx+1);
            Count := 0;
        ELSE
            (*<DEBUGGING
            ValidateTreeNode(ViewObject);
            DEBUGGING*)

            LayoutPtr := ViewObject^.Methods^.GetDataObject (ViewObject);
            Copy (LayoutPtr^.Name, s);
            Procustes (s, Lrx-Ulx+1);
            IF (0 IN LayoutPtr^.LayoutFlags) THEN
                s[Lrx-Ulx+1] := "*";
            END;
            Count := ParentView^.Methods^.GetMatchCount (ParentView);
        END;

        PutMatchedString (s, Ulx, Uly, Count, VideoMode, CursorMode,
                            (CursorOn IN Status));
        EXCL(Status, NeedsRedisplay);
    END;

END LayoutViewDisplay;







    (*  These are the procedures which are exported from this module  *)


(*----------------------------------------------------------------------------
    InitAsLayoutView --

    Initialize the indicated object as a layout view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid layout view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsLayoutView(    LayoutView   : ALayoutView;
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
    PrivateLayoutView       : XLayoutView;

BEGIN                       (* InitAsLayoutView *)

    Fill(s, " ", 0);
    InitAsActiveView(AnActiveView(LayoutView), AnObjectView(SuperView), Ulx, 
                     Uly, Lrx, Lry, Box, VideoMode, s, HelpKey, FALSE);
    PrivateLayoutView := XLayoutView(LayoutView);
    WITH PrivateLayoutView^ DO
        Methods := ALayoutViewMethods(ADR(LayoutViewMethodsRecord));
    END;

END InitAsLayoutView;







(*----------------------------------------------------------------------------
    CreateLayoutView --

    Allocate storage for, and initialize the indicated object as a layout 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid layout view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateLayoutView(  VAR LayoutView     : ALayoutView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL)
                                                       : BOOLEAN;

BEGIN                       (* CreateLayoutView *)

    IF (Available(TSIZE(XLayoutViewRecord))) THEN
        ALLOCATE(LayoutView, TSIZE(XLayoutViewRecord));
        InitAsLayoutView(LayoutView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                         VideoMode, HelpKey);
        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateLayoutView;







(*----------------------------------------------------------------------------
    UnInitAsLayoutView --

    UnInitialize the indicated object as a layout view.

    Preconditions:
        The object will be a valid layout view object.

    Postconditions:
        Whatever was done by InitAsLayoutView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsLayoutView(    LayoutView : ALayoutView);

BEGIN                       (* UnInitAsLayoutView *)

    UnInitAsActiveView(AnActiveView(LayoutView));

END UnInitAsLayoutView;












(*----------------------------------------------------------------------------
    CloneLayoutViewMethods --

    Make a copy of the layout view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The layout view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneLayoutViewMethods(    MethodObject : ALayoutViewMethods);

BEGIN                       (* CloneLayoutViewMethods *)

    FatalError();

END CloneLayoutViewMethods;








(*----------------------------------------------------------------------------
    ValidateLayoutView --

    Determine that the indicated object is in fact a valid layout view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid layout view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateLayoutView(    LayoutView : ALayoutView);

BEGIN                       (* ValidateLayoutView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(LayoutView));
    END;
    DEBUGGING>*)

    IF (LayoutView^.Methods^.LayoutViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateLayoutView;


BEGIN                       (* LayoutViews *)

    CloneActiveViewMethods(AnActiveViewMethods(ADR(LayoutViewMethodsRecord)));
    WITH LayoutViewMethodsRecord DO
        MethodSize := TSIZE(ALayoutViewMethodsRecord);
        Discard    := ALayoutViewDiscardProc(LayoutViewDiscard);
        Display    := ALayoutViewDisplayProc(LayoutViewDisplay);
        LayoutViewTag := ModuleNumber;
    END;

END LayoutViews.
