IMPLEMENTATION MODULE ObjectViews;      (* A subclass of Objects *)

(*V9=DEBUGGING Code*)

   (* Jan 28 1988  RSC  If InitAsObjectView can't take a rug, dont fatal error.
      Nov 16 1988  EGK  O.K., but at least post an error.
      10-Jan-89    RSC  Changed Storage to Space    .
       9-Oct-89    MWP  Commented out an unused text literal.
   *)

FROM Objects                IMPORT
    (* TYPE *)                  AnObject,
    (* PROC *)                  CloneObjectMethods, ValidateObject,
                                InitAsObject, UnInitAsObject;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType,
    (* PROC *)                  GetInnerBoxSize, GetOuterBoxSize, DrawBox;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR  *)                  AnxietyLevel;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode, ascreenx, ascreeny;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, Copy;

FROM ErrorCategories        IMPORT
    (* CONST *)                 AllocationError;

FROM ErrorHandler           IMPORT
    (* PROC *)                  PostError;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug,
    (* PROC *)                  GetRug, PutRug;


CONST
    ModuleNumber = 15000;


TYPE

    (*  XObjectView is a redefinition of AnObjectView, for the use of this
        module only.
    *)

    XObjectView = POINTER TO XObjectViewRecord;

    XObjectViewRecord = RECORD
                                Methods     : AnObjectViewMethods;
                                ViewObject  : AnObject;
                                ParentView  : AnObjectView;
                                Ulx         : ascreenx;
                                Uly         : ascreeny;
                                Lrx         : ascreenx;
                                Lry         : ascreeny;
                                Box         : ABoxType;
                                VideoMode   : avidmode;
                                Title       : ARRAY [0..40] OF CHAR;
                                HelpNumber  : CARDINAL;
                                Rug         : ARug;
                                Status      : AnObjectViewStatusSet;
                        END;

VAR
    ObjectViewMethodsRecord :   AnObjectViewMethodsRecord;






PROCEDURE ViewDiscard (VAR View: XObjectView);

BEGIN               (* ViewDiscard *)

    ValidateObjectView (AnObjectView (View));
    UnInitAsObjectView (AnObjectView (View));
    DISPOSE (View);

END ViewDiscard;



PROCEDURE GetViewExternalXY (View: XObjectView;
                        VAR Ulx: ascreenx;
                        VAR Uly: ascreeny;
                        VAR Lrx: ascreenx;
                        VAR Lry: ascreeny);

BEGIN           (* GetViewExternalXY *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    DEBUGGING>*)

    GetViewInternalXY (View, Ulx, Uly, Lrx, Lry);
    GetOuterBoxSize (Ulx, Uly, Lrx, Lry, View^.Box);

END GetViewExternalXY;



PROCEDURE GetViewInternalXY (View: XObjectView;
                        VAR Ulx: ascreenx;
                        VAR Uly: ascreeny;
                        VAR Lrx: ascreenx;
                        VAR Lry: ascreeny);

BEGIN           (* GetViewInternalXY *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    DEBUGGING>*)

    Ulx := View^.Ulx;
    Uly := View^.Uly;
    Lrx := View^.Lrx;
    Lry := View^.Lry;

END GetViewInternalXY;



PROCEDURE GetViewTitle (View: XObjectView;
                    VAR Title: ARRAY OF CHAR);

BEGIN           (* GetViewTitle *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    DEBUGGING>*)

    Copy (View^.Title, Title);

END GetViewTitle;



PROCEDURE GetViewObject (View: XObjectView): AnObject;

BEGIN               (* GetViewObject *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    DEBUGGING>*)

    RETURN View^.ViewObject;

END GetViewObject;




PROCEDURE SetViewObject (View: XObjectView; Object: AnObject);

BEGIN               (* SetViewObject *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    DEBUGGING>*)

    View^.ViewObject := Object;
    View^.Methods^.NotifyOfChange(AnObjectView(View));

END SetViewObject;




PROCEDURE ViewMove (View: XObjectView;
                    Ulx: ascreenx;
                    Uly: ascreeny);

VAR
    DX, DY: INTEGER;
    WasVisible: BOOLEAN;

BEGIN               (* ViewMove *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    (*DEBUGGING>*)

    WasVisible := NOT (ViewHidden IN View^.Status);

    IF WasVisible THEN
        View^.Methods^.HideView (AnObjectView (View));
    END;

    DX := Ulx - View^.Ulx;
    DY := Uly - View^.Uly;

    View^.Ulx := Ulx;
    View^.Uly := Uly;

    View^.Lrx := CARDINAL (INTEGER (View^.Lrx) + DX);
    View^.Lry := CARDINAL (INTEGER (View^.Lry) + DY);

    IF WasVisible THEN
        View^.Methods^.RevealView (AnObjectView (View));
        View^.Methods^.Display (AnObjectView (View));
    END;

END ViewMove;



PROCEDURE ViewDisplay (View: XObjectView);
VAR
    Ulx, Uly, Lrx, Lry: CARDINAL;

BEGIN               (* ViewDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    DEBUGGING>*)


    IF (NeedsRedisplay IN View^.Status) AND NOT (ViewHidden IN View^.Status) THEN
        View^.Methods^.GetExternalXY (AnObjectView (View), Ulx, Uly, Lrx, Lry);
        DrawBox (Ulx, Uly, Lrx, Lry, View^.Box, View^.Title, View^.VideoMode);
        EXCL (View^.Status, NeedsRedisplay);
    END;

END ViewDisplay;



PROCEDURE ViewGetHelp (View: XObjectView);

VAR
    s: ARRAY[0..80] OF CHAR;

BEGIN               (* ViewGetHelp *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    (*DEBUGGING>*)

    (*
    SetString (s, "ViewGetHelp");                                 (* 9-Oct-89 MWP *)
    NotYetImplemented (s);
    *)
END ViewGetHelp;



PROCEDURE ViewHide (View: XObjectView);
VAR
    Ulx, Uly, Lrx, Lry: CARDINAL;

BEGIN               (* ViewHide *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    (*DEBUGGING>*)

    IF (RugTaken IN View^.Status) THEN
        View^.Methods^.GetExternalXY (AnObjectView (View), Ulx, Uly, Lrx, Lry);
        PutRug (Ulx, Uly, Lrx, Lry, View^.Rug);
        EXCL (View^.Status, RugTaken);
        INCL (View^.Status, ViewHidden);
    ELSE
        FatalError();
    END;

END ViewHide;



PROCEDURE ViewReveal (View: XObjectView);
VAR
    Ulx, Uly, Lrx, Lry: CARDINAL;

BEGIN               (* ViewReveal *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (View));
    END;
    (*DEBUGGING>*)


    IF (RugTaken IN View^.Status) THEN
        FatalError();
    END;
    View^.Methods^.GetExternalXY (AnObjectView (View), Ulx, Uly, Lrx, Lry);
    IF GetRug (Ulx, Uly, Lrx, Lry, View^.Rug) THEN
        INCL (View^.Status, RugTaken);
        INCL (View^.Status, NeedsRedisplay);
        EXCL (View^.Status, ViewHidden);
    ELSE
        FatalError();
    END;

END ViewReveal;


PROCEDURE ViewChanged (View: XObjectView);

BEGIN
    INCL (View^.Status, NeedsRedisplay);
END ViewChanged;




(*----------------------------------------------------------------------------
    InitAsObjectView --

    Initialize the indicated object as an object view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid object view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsObjectView(    ObjectView   : AnObjectView;
                               SuperView    : AnObjectView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                           VAR Title        : ARRAY OF CHAR;
                               HelpKey      : CARDINAL;
                               TakeRug      : BOOLEAN      );

VAR
    PrivateView: XObjectView;

BEGIN               (* InitAsObjectView *)

    InitAsObject (AnObject (ObjectView));

    PrivateView := XObjectView (ObjectView);

    PrivateView^.ViewObject := NIL;
    PrivateView^.ParentView := SuperView;
    PrivateView^.Methods := ADR (ObjectViewMethodsRecord);
    PrivateView^.Ulx := Ulx;
    PrivateView^.Uly := Uly;
    PrivateView^.Lrx := Lrx;
    PrivateView^.Lry := Lry;
    PrivateView^.Box := Box;
    WITH PrivateView^ DO
        GetInnerBoxSize (Ulx, Uly, Lrx, Lry, Box);
    END;
    PrivateView^.VideoMode := VideoMode;
    Copy (Title, PrivateView^.Title);
    PrivateView^.HelpNumber := HelpKey;
    PrivateView^.Status := AnObjectViewStatusSet{NeedsRedisplay};

    IF (TakeRug) THEN
        IF (GetRug(Ulx, Uly, Lrx, Lry, PrivateView^.Rug)) THEN
            INCL (PrivateView^.Status, RugTaken);
        ELSE
            PostError (AllocationError, ModuleNumber);      (* 11/16/88 EGK *)
        END;
    END;
END InitAsObjectView;





(*----------------------------------------------------------------------------
    UnInitAsObjectView --

    Un-Initialize the indicated object as an object view.

    Preconditions:
        The object must be a valid Object View object.

    Postconditions:
        The object will no longer be a valid object view object, and the
        effects of InitAsObjectView will be undone.  No storage deallocation
        is done by this procedure.
----------------------------------------------------------------------------*)
PROCEDURE UnInitAsObjectView (ObjectView: AnObjectView);

VAR
    PrivateView: XObjectView;

BEGIN
    PrivateView := XObjectView (ObjectView);
    IF (RugTaken IN PrivateView^.Status) THEN
        ObjectView^.Methods^.HideView (ObjectView);
    END;
    UnInitAsObject (AnObject (ObjectView));
END UnInitAsObjectView;



(*----------------------------------------------------------------------------
    CreateObjectView --

    Allocate storage for, and initialize the indicated object as an object
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be
        allocated and initialized as a valid object view object, and TRUE
        will be returned.
----------------------------------------------------------------------------*)

PROCEDURE CreateObjectView(VAR ObjectView   : AnObjectView;
                               SuperView    : AnObjectView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                           VAR Title        : ARRAY OF CHAR;
                               HelpKey      : CARDINAL;
                               TakeRug      : BOOLEAN      )
                                                            : BOOLEAN;

BEGIN           (* CreateObjectView *)

    IF NOT HeapAvailable () THEN
        RETURN FALSE;
    END;
    ALLOCATE (ObjectView, TSIZE (XObjectViewRecord));
    InitAsObjectView (ObjectView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                        VideoMode, Title, HelpKey, TakeRug);
    RETURN TRUE;
END CreateObjectView;






(*----------------------------------------------------------------------------
    CloneObjectViewMethods --

    Make a copy of the object view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The object view methods will be copied into the indicated method
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneObjectViewMethods(    MethodObject : AnObjectViewMethods);

BEGIN           (* CloneObjectViewMethods *)

    MethodObject^ := ObjectViewMethodsRecord;
    MethodObject^.SuperclassMethods := ADR (ObjectViewMethodsRecord);
END CloneObjectViewMethods;








(*----------------------------------------------------------------------------
    ValidateObjectView --

    Determine that the indicated object is in fact a valid object view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid object view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateObjectView(    ObjectView : AnObjectView);
VAR
    PrivateView: XObjectView;

BEGIN
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateObject (AnObject (ObjectView));
    END;
    DEBUGGING>*)


    PrivateView := XObjectView (ObjectView);
    IF (PrivateView^.Methods^.ObjectViewTag <> ModuleNumber) THEN
        FatalError();
    END;
END ValidateObjectView;




BEGIN       (* ObjectViews *)

    CloneObjectMethods (ADR (ObjectViewMethodsRecord));
    WITH ObjectViewMethodsRecord DO
        Discard := AnObjectViewDiscardProc (ViewDiscard);
        MethodSize := TSIZE (AnObjectViewMethodsRecord);
        GetExternalXY := AnObjectViewXYProc (GetViewExternalXY);
        GetInternalXY := AnObjectViewXYProc (GetViewInternalXY);
        GetTitle := AnObjectViewTitleProc (GetViewTitle);
        GetObject := AnObjectViewGetObjectProc (GetViewObject);
        SetObject := AnObjectViewSetObjectProc (SetViewObject);
        Move := AnObjectViewMoveProc (ViewMove);
        Display := AnObjectViewDisplayProc (ViewDisplay);
        GetHelp := AnObjectViewHelpProc (ViewGetHelp);
        HideView := AnObjectViewHiddenProc (ViewHide);
        RevealView := AnObjectViewRevealProc (ViewReveal);
        NotifyOfChange := AnObjectViewChangedProc (ViewChanged);
        ObjectViewTag := ModuleNumber;
    END;


END ObjectViews.

