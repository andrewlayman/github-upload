IMPLEMENTATION MODULE GoToViews;          (* Subclass of ActiveViews *)

    (*  GoToViews provides an object which is a view of a tree node.
        The data object of the tree node can be a task, a resource, a memo,
        etc.  depending on the caller of CreateGoToOutline.  Only the name of
        the object is displayed, using indentation to reflect depth in its
        tree, along with "-" and "+" symbols to show whether or not it has
        children.  Any matched characters in the name are displayed in bright
        video.  If the cursor is on this view, the unmatched characters are
        displayed in reverse video.

       10-Jan-89 RSC    Changed Storage to Space.

    *)

(*V9=DEBUGGING Code*)


FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveViewMethods, AnActiveView,
    (* PROC *)                  CloneActiveViewMethods, ValidateActiveView,
                                InitAsActiveView, UnInitAsActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Indentation            IMPORT
    (* PROC *)                  FormatIndentation;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM GoTo                   IMPORT
    (* TYPE *)                  AGoToNameProc;

FROM GoToOutlines           IMPORT
    (* TYPE *)                  AGoToOutline;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString, PutAttribute;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Procustes, ConcatS, Remove, SubStr,
                                LengthOf, SetLengthOf, ConcatLS;

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
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeNodeAttribute;



CONST
    ModuleNumber            = 18200;

    NotMatchedWithoutCursorMode     = videonormal;
    NotMatchedWithCursorMode        = cvideonormal;

    MatchedWithCursorMode           = videoenhance;
    NotYetMatchedWithCursorMode     = cvideoenhance;
    MatchedWithoutCursorMode        = videobright;


TYPE
    XGoToView             = POINTER TO XGoToViewRecord;
        
    XGoToViewRecord       = RECORD
                                Methods        : AGoToViewMethods;
                                ViewObject     : ATreeNode;
                                ParentView     : AGoToOutline;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : AGoToViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                NameProc       : AGoToNameProc;
                              END;


    AGoToViewDiscardProc = PROCEDURE (VAR AGoToView);

    AGoToViewTitleProc   = PROCEDURE (    AGoToView,
                                      VAR ARRAY OF CHAR);

    AGoToViewDisplayProc = PROCEDURE (    AGoToView);


VAR
    GoToViewMethodsRecord : AGoToViewMethodsRecord;




    (*  Following are the procedures which replace the methods inherited from
        ActiveViews.
    *)


PROCEDURE GoToViewDiscard(VAR GoToView  : XGoToView);

BEGIN                       (* GoToViewDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateGoToView(AGoToView(GoToView));
    END;
      DEBUGGING>*)

    UnInitAsGoToView(AGoToView(GoToView));
    DISPOSE(GoToView);

END GoToViewDiscard;




PROCEDURE GoToViewDisplay(    GoToView  : XGoToView);

VAR
    s                       : ARRAY [0..80] OF CHAR;
    s1                      : ARRAY [0..180] OF CHAR;
    Leader                  : CARDINAL;
    Count                   : CARDINAL;
    mode1                   : avidmode;
    mode2                   : avidmode;
    i                       : CARDINAL;
    FillLength              : CARDINAL;
    BoxWidth                : CARDINAL;

BEGIN                       (* GoToViewDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateGoToView(AGoToView(GoToView));
    END;
      DEBUGGING>*)

    WITH GoToView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        mode1 := VideoMode;
        mode2 := VideoMode;
        IF (CursorOn IN Status) THEN
            mode1 := CursorMode;
            INC (mode1);
            mode2 := CursorMode;
            INC (mode2);
        END;

        BoxWidth := Lrx-Ulx+1;

        IF (ViewObject = NIL) THEN
            Fill (s, " ", BoxWidth);
            SetLengthOf (s1, 0);
            Count := 0;
            Leader := 0;
        ELSE
            FormatIndentation (ViewObject, BoxWidth, s1);
            ConcatS (s1, " ");
            Count := ParentView^.Methods^.GetMatchCount (ParentView);
            NameProc (ViewObject, s);
            IF (LengthOf(s) > BoxWidth) THEN
                SetLengthOf (s, BoxWidth);
            END;
            Leader := LengthOf(s1);

            IF (ViewObject^.Methods^.TestAttributeBit (ViewObject, TypeThroughEnable)) AND
               (ViewObject^.Methods^.TestAttributeBit (ViewObject, SelfMatch)) THEN
                IF (CursorOn IN Status) THEN
                    mode1 := MatchedWithCursorMode;
                    mode2 := NotYetMatchedWithCursorMode;
                ELSE
                    mode1 := MatchedWithoutCursorMode;
                END;
            ELSE
                Count := 0;
            END;

            ConcatLS (s1, s);
            SetLengthOf (s1, Count+Leader);
            Remove (s, 1, Count);

            IF (Count+Leader > BoxWidth) THEN
                SetLengthOf (s1, BoxWidth);
                SetLengthOf (s, 0);
                Count := 0;
                Leader := 0;
            ELSE
                FillLength := BoxWidth-Leader-Count;
                IF (LengthOf (s) > FillLength) THEN
                    SetLengthOf (s, FillLength);
                ELSE
                    FOR i := 1 TO FillLength-LengthOf(s) DO
                        ConcatS (s, " ");
                    END;
                END;
            END;
        END;

        PutString (s1, Ulx, Uly, VideoMode);
        PutAttribute (Ulx+Leader, Uly, Count, mode1);
        PutString (s, Ulx+Count+Leader, Uly, mode2);

        EXCL(Status, NeedsRedisplay);
    END;

END GoToViewDisplay;







    (*  These are the procedures which are exported from this module  *)


(*----------------------------------------------------------------------------
    InitAsGoToView --

    Initialize the indicated object as a GoTo view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid GoTo view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsGoToView(      GoToView     : AGoToView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               NameProc     : AGoToNameProc;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL);

VAR
    s                     : ARRAY [0..1] OF CHAR;
    PrivateGoToView       : XGoToView;

BEGIN                       (* InitAsGoToView *)

    Fill(s, " ", 0);
    InitAsActiveView(AnActiveView(GoToView), AnObjectView(SuperView), Ulx,
                     Uly, Lrx, Lry, Box, VideoMode, s, HelpKey, FALSE);
    PrivateGoToView := XGoToView(GoToView);
    PrivateGoToView^.Methods := AGoToViewMethods(ADR(GoToViewMethodsRecord));
    PrivateGoToView^.NameProc := NameProc;

END InitAsGoToView;







(*----------------------------------------------------------------------------
    CreateGoToView --

    Allocate storage for, and initialize the indicated object as a GoTo 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid GoTo view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateGoToView(  VAR GoToView     : AGoToView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               NameProc     : AGoToNameProc;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL)
                                                       : BOOLEAN;

BEGIN                       (* CreateGoToView *)

    IF (HeapAvailable()) THEN
        ALLOCATE(GoToView, TSIZE(XGoToViewRecord));
        InitAsGoToView(GoToView, SuperView, Ulx, Uly, Lrx, Lry, NameProc,
                         Box, VideoMode, HelpKey);
        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateGoToView;







(*----------------------------------------------------------------------------
    UnInitAsGoToView --

    UnInitialize the indicated object as a GoTo view.

    Preconditions:
        The object will be a valid GoTo view object.

    Postconditions:
        Whatever was done by InitAsGoToView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsGoToView(    GoToView : AGoToView);

BEGIN                       (* UnInitAsGoToView *)

    UnInitAsActiveView(AnActiveView(GoToView));

END UnInitAsGoToView;












(*----------------------------------------------------------------------------
    CloneGoToViewMethods --

    Make a copy of the GoTo view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The GoTo view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneGoToViewMethods(    MethodObject : AGoToViewMethods);

BEGIN                       (* CloneGoToViewMethods *)

    FatalError();

END CloneGoToViewMethods;








(*----------------------------------------------------------------------------
    ValidateGoToView --

    Determine that the indicated object is in fact a valid GoTo view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid GoTo view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateGoToView(    GoToView : AGoToView);

BEGIN                       (* ValidateGoToView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(GoToView));
    END;
      DEBUGGING>*)

    IF (GoToView^.Methods^.GoToViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateGoToView;


BEGIN                       (* GoToViews *)

    CloneActiveViewMethods(AnActiveViewMethods(ADR(GoToViewMethodsRecord)));
    WITH GoToViewMethodsRecord DO
        MethodSize := TSIZE(AGoToViewMethodsRecord);
        Discard := AGoToViewDiscardProc(GoToViewDiscard);
        Display := AGoToViewDisplayProc(GoToViewDisplay);
        GoToViewTag := ModuleNumber;
    END;

END GoToViews.
