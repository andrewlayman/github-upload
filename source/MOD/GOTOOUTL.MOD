IMPLEMENTATION MODULE GoToOutlines;        (*  a subclass of OutlineViews  *)

    (* Modification History:

       10-Jan-89 RSC    Changed Storage to Space    .
       10-Jun-89 WKH    Added support for variable screen rows
       27-Dec-89 LAA    Added MouseDownRegion to the object record definition,
                        so we can limit mouse actions to the screen region on 
                        which the mouse button was originally pressed.
        5-Jan-90 LAA    Moved the location of MouseDownRegion, because this
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

FROM Codes                  IMPORT
    (* TYPE *)                  ASetOfCodes;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Burp, Error;

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

FROM GoToViews              IMPORT
    (* TYPE *)                  AGoToView,
    (* PROC *)                  CreateGoToView;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 AbsoluteMaxRow, maxrow, maxcol;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Compare, ConcatLS;

FROM Menus                  IMPORT
    (* PROC *)                  NoYes;

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

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
                                ATreeNodeProcessingProc,
    (* PROC *)                  CreateTreeNode;



CONST
    ModuleNumber            = 18300;


TYPE
        (*  AGoToOutline is a subclass of AnOutlineView  *)

    XGoToOutline            = POINTER TO XGoToOutlineRecord;

    XGoToOutlineRecord      = RECORD
                                Methods        : AGoToOutlineMethods;
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
                                Status         : AGoToOutlineStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                    AGoToView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                                  (* New fields for outline views *)
                                MatchCount          : CARDINAL;
                                MatchString         : ARRAY [0..80] OF CHAR;
                                TypeThroughEnabled  : BOOLEAN;
                                MatchCodeSet        : ASetOfCodes;
                                NameProc            : AGoToNameProc;
                              END;


    AGoToOutlineDiscardProc = PROCEDURE (VAR AGoToOutline );



VAR
    GoToOutlineMethodsRecord : AGoToOutlineMethodsRecord;






PROCEDURE DiscardSubViews(    GoToOutline   : XGoToOutline);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    WITH GoToOutline^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;
        Cursor := 0;
    END;

END DiscardSubViews;




PROCEDURE GoToOutlineDiscard(VAR GoToOutline : XGoToOutline);

BEGIN                       (* GoToOutlineDiscard *)

    UnInitAsGoToOutline(AGoToOutline(GoToOutline));
    DISPOSE(GoToOutline);

END GoToOutlineDiscard;






(*----------------------------------------------------------------------------
    InitAsGoToOutline --

    Initialize the indicated object as a GoTo outline view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid GoTo outline view object.  No storage 
        allocation is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsGoToOutline(    GoToOutline : AGoToOutline;
                                SuperView   : AnActiveView;
                                Ulx         : ascreenx;
                                Uly         : ascreeny;
                                Lrx         : ascreenx;
                                Lry         : ascreeny;
                                LNameProc   : AGoToNameProc;
                                Box         : ABoxType;
                                VideoMode   : avidmode;
                            VAR Title       : ARRAY OF CHAR;
                                HelpKey     : CARDINAL;
                                TakeRug     : BOOLEAN      );

VAR
    PrivateGoToOutline      : XGoToOutline;
    y                       : ascreeny;

BEGIN                       (* InitAsGoToOutline *)

    InitAsOutlineView(AnOutlineView(GoToOutline), SuperView, Ulx, Uly, Lrx,
                      Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    PrivateGoToOutline := XGoToOutline(GoToOutline);
    WITH PrivateGoToOutline^ DO
        TypeThroughEnabled := TRUE;
        NameProc := LNameProc;
        Methods := ADR(GoToOutlineMethodsRecord);
        Last := 0;
        FOR y := Uly TO Lry DO
            IF (NOT CreateGoToView(SubView[Last + 1],
                                   AnActiveView(GoToOutline), Ulx, y, Lrx, y,
                                   LNameProc, ABoxType{NoBox}, VideoMode,
                                   HelpKey)) THEN
                DiscardSubViews(PrivateGoToOutline);
                PostError(AllocationError, ModuleNumber);         (* 04-Mar-88 LAA *)
                RETURN;
            END;
            INC(Last);
        END;
    END;

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateGoToOutline(GoToOutline);
    END;
      DEBUGGING>*)

END InitAsGoToOutline;






(*----------------------------------------------------------------------------
    CreateGoToOutline --

    Allocate storage for, and initialize the indicated object as a GoTo 
    outline view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid GoTo outline view object, and 
        TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateGoToOutline(VAR GoToOutline : AGoToOutline;
                                SuperView   : AnActiveView;
                                Ulx         : ascreenx;
                                Uly         : ascreeny;
                                Lrx         : ascreenx;
                                Lry         : ascreeny;
                                NameProc    : AGoToNameProc;
                                Box         : ABoxType;
                                VideoMode   : avidmode;
                            VAR Title       : ARRAY OF CHAR;
                                HelpKey     : CARDINAL;
                                TakeRug     : BOOLEAN      ) 
                                                            : BOOLEAN;

VAR
    ErrorMarker             : AnErrorMarker;

BEGIN                       (* CreateGoToOutline *)

    ErrorMarker := NewMarker();                                   (* 04-Mar-88 LAA *)

    IF (HeapAvailable()) THEN
        ALLOCATE(GoToOutline, TSIZE(XGoToOutlineRecord));
        InitAsGoToOutline(GoToOutline, SuperView, Ulx, Uly, Lrx, Lry,
                          NameProc, Box, VideoMode, Title, HelpKey, TakeRug);

        IF (ErrorPosted(ErrorMarker)) THEN                        
            UnInitAsGoToOutline(GoToOutline);
            DEALLOCATE(GoToOutline, TSIZE(XGoToOutlineRecord));
        ELSE
            PopToMarker(ErrorMarker);                                     
            RETURN TRUE;
        END;
    END;

    PopToMarker(ErrorMarker);                                     

    RETURN FALSE;

END CreateGoToOutline;







(*----------------------------------------------------------------------------
    UnInitAsGoToOutline --

    UnInitialize the indicated object as a GoTo outline view.

    Preconditions:
        The object will be a valid GoTo outline view object. 

    Postconditions:
        The outline view will be invalidated.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsGoToOutline(    GoToOutline : AGoToOutline);


BEGIN                       (* UnInitAsGoToOutline *)

    DiscardSubViews(XGoToOutline(GoToOutline));
    UnInitAsOutlineView(AnOutlineView(GoToOutline));

END UnInitAsGoToOutline;







(*----------------------------------------------------------------------------
    CloneGoToOutlineMethods --

    Make a copy of the GoTo outline view methods into the indicated method 
    object.

    Preconditions:
        None.

    Postcondition:
        The GoTo outline view methods will be copied into the indicated 
        method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneGoToOutlineMethods(    MethodObject : AGoToOutlineMethods);

BEGIN                       (* CloneGoToOutlineMethods *)

    MethodObject^ := GoToOutlineMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(GoToOutlineMethodsRecord);
END CloneGoToOutlineMethods;








(*----------------------------------------------------------------------------
    ValidateGoToOutline --

    Determine that the indicated object is in fact a valid GoTo outline view 
    object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid GoTo outline view object, FatalError 
        will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateGoToOutline(    GoToOutline : AGoToOutline);

VAR
    PrivateGoToOutline      : XGoToOutline;

BEGIN                       (* ValidateGoToOutline *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(GoToOutline));
    END;
      DEBUGGING>*)

    PrivateGoToOutline := XGoToOutline(GoToOutline);
    IF (PrivateGoToOutline^.Methods^.GoToOutlineTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateGoToOutline;





BEGIN                       (* GoToOutlines *)

    CloneOutlineViewMethods(ADR(GoToOutlineMethodsRecord));
    WITH GoToOutlineMethodsRecord DO
        MethodSize := TSIZE(AGoToOutlineMethodsRecord);
        Discard := AGoToOutlineDiscardProc(GoToOutlineDiscard);
        GoToOutlineTag := ModuleNumber;
    END;

END GoToOutlines.
