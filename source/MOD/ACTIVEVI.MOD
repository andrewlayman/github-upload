IMPLEMENTATION MODULE ActiveViews;      (* A subclass of ObjectViews *)

    (* MODIFICATION HISTORY

    15-Jul-87 LAA   Changed the ActOn procedure to not record events, and
                    to return any events it gets.
    23-Jan-89 RSC   Change Storage to Space    .
    28-Jul-89 EGK   Implemented "GetRecordedEvent" for all objects that
                    are descendants of AnActiveView.
    *)

FROM ObjectViews                IMPORT
    (* TYPE *)                      AnObjectView, AnObjectViewMethods,
    (* PROC *)                      CloneObjectViewMethods,
                                    ValidateObjectView, InitAsObjectView,
                                    UnInitAsObjectView;

FROM Events                     IMPORT
    (* TYPE *)                      AnEvent, AnEventType;

FROM Dialog                     IMPORT
    (* PROC *)                      FatalError;

FROM Helper                     IMPORT
    (* TYPE *)                      AScreenAction,
    (* PROC *)                      GiveHelp;

FROM Kbio                       IMPORT
    (* TYPE *)                      ascreenx, ascreeny, avidmode, maxrow;

FROM Keys                       IMPORT
    (* CONST *)                     HelpKey;

FROM Boxes                      IMPORT
    (* TYPE *)                      ABoxType;

FROM LStrings                   IMPORT
    (* PROC *)                      CtoS;

FROM Objects                    IMPORT
    (* TYPE *)                      AnObject;

FROM Paranoia                   IMPORT
    (* TYPE *)                      AnAnxietyLevel,
    (* VAR  *)                      AnxietyLevel;

FROM Rugs                       IMPORT
    (* TYPE *)                      ARug;

FROM Space                      IMPORT
    (* PROC *)                      HeapAvailable,
                                    ALLOCATE, DEALLOCATE;

FROM SYSTEM                     IMPORT
    (* PROC *)                      ADR, TSIZE;


CONST
    ModuleNumber = 15100;

TYPE

    (*  XActiveView is a redefinition of AnActiveView, for the use of this
        module only.
    *)


    XActiveView = POINTER TO XActiveViewRecord;

    XActiveViewRecord = RECORD
                                Methods     : AnActiveViewMethods;
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
                                Status      : AnActiveViewStatusSet;
                                EventHistory : ARRAY [0..10] OF AnEvent;
                                CursorMode  : avidmode;
                        END;


VAR
    ActiveViewMethodsRecord: AnActiveViewMethodsRecord;




PROCEDURE ActiveViewDiscard (VAR View: XActiveView);

BEGIN

    ValidateActiveView (AnActiveView (View));
    UnInitAsActiveView (AnActiveView (View));
    DISPOSE (View);

END ActiveViewDiscard;




PROCEDURE Record (ActiveView: XActiveView;
                  Event: AnEvent    );
VAR
    i : CARDINAL;

BEGIN

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView (AnActiveView (ActiveView));
    END;
    DEBUGGING>*)

    WITH ActiveView^ DO
        FOR i := 9 TO 0 BY -1 DO
            EventHistory[i+1] := EventHistory[i];
        END;
        EventHistory[0] := Event;
    END;

END Record;





PROCEDURE GetEvent (    ActiveView     : XActiveView;
                        EventNumber    : CARDINAL;
                    VAR Event          : AnEvent     );
BEGIN

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView (AnActiveView (ActiveView));
    END;
    DEBUGGING>*)

    WITH ActiveView^ DO
        IF (EventNumber <= 10) THEN
            Event := EventHistory[EventNumber];
        ELSE
            Event.EventType := KeyboardEvent;     (* Why not? *)
            Event.EventCode := 0;
        END;
    END;

END GetEvent;





PROCEDURE ActOn (    ActiveView             : XActiveView;
                     EventIn                : AnEvent;
                 VAR EventOut               : AnEvent);

VAR
    s                       : ARRAY [0..9] OF CHAR;

BEGIN       (* ActOn *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView (AnActiveView (ActiveView));
    END;
    (*DEBUGGING>*)

    IF (EventIn.EventCode = HelpKey) THEN
        IF (ActiveView^.HelpNumber <> 0) THEN
            CtoS(ActiveView^.HelpNumber, s);
        ELSE
            CtoS(ModuleNumber, s);
        END;
        GiveHelp(s, 0, maxrow, RestoreTheScreen);
        EventIn.EventCode := 0;
    END;
    EventOut := EventIn;

END ActOn;



PROCEDURE GetActiveCursor (ActiveView: XActiveView): BOOLEAN;

BEGIN
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView (AnActiveView (ActiveView));
    END;
    DEBUGGING>*)

    RETURN (CursorOn IN ActiveView^.Status);

END GetActiveCursor;



PROCEDURE SetActiveCursor (ActiveView: XActiveView;
                           Displaying: BOOLEAN);

BEGIN
    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView (AnActiveView (ActiveView));
    END;
    DEBUGGING>*)

    IF Displaying THEN
        INCL (ActiveView^.Status, CursorOn);
    ELSE
        EXCL (ActiveView^.Status, CursorOn);
    END;
    INCL(ActiveView^.Status, NeedsRedisplay);

END SetActiveCursor;




PROCEDURE SetActiveCursorMode(    ActiveView      : XActiveView;
                                  VideoMode       : avidmode   );

BEGIN                   (* SetActiveCursorMode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView (AnActiveView (ActiveView));
    END;
    DEBUGGING>*)

    IF (ActiveView^.CursorMode <> VideoMode) THEN
        ActiveView^.CursorMode := VideoMode;
        INCL(ActiveView^.Status, NeedsRedisplay);
    END;

END SetActiveCursorMode;




(*----------------------------------------------------------------------------
    UnInitAsActiveView --

    Un-Initialize the indicated object as an active view.

    Preconditions:
        The object must be a valid Active View object.

    Postconditions:
        The object will no longer be a valid active view object, and all
        effects of InitAsActiveView will be undone.  No storage deallocation
        is done by this procedure.
----------------------------------------------------------------------------*)
PROCEDURE UnInitAsActiveView (ObjectView: AnActiveView);

BEGIN
    UnInitAsObjectView (AnObjectView (ObjectView));

END UnInitAsActiveView;




(*----------------------------------------------------------------------------
    InitAsActiveView --

    Initialize the indicated object as an active view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid active view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsActiveView(    ObjectView   : AnActiveView;
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
    PrivateView: XActiveView;
    i          : CARDINAL;

BEGIN
    InitAsObjectView (AnObjectView (ObjectView), SuperView, Ulx, Uly,
                      Lrx, Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    PrivateView := XActiveView (ObjectView);
    WITH PrivateView^ DO
        CursorMode := VideoMode;
        Methods := ADR (ActiveViewMethodsRecord);

        FOR i := 0 TO 10 DO
            EventHistory[i].EventCode := 0;
        END;
    END;
END InitAsActiveView;






(*----------------------------------------------------------------------------
    CreateActiveView --

    Allocate storage for, and initialize the indicated object as an active 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid active view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateActiveView(VAR ObjectView   : AnActiveView;
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

BEGIN
    IF NOT HeapAvailable() THEN
        RETURN FALSE;
    END;

    ALLOCATE (ObjectView, TSIZE (XActiveViewRecord));
    InitAsActiveView (ObjectView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                      VideoMode, Title, HelpKey, TakeRug);
    RETURN TRUE;
END CreateActiveView;








(*----------------------------------------------------------------------------
    CloneActiveViewMethods --

    Make a copy of the active view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The active view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneActiveViewMethods(    MethodObject : AnActiveViewMethods);

BEGIN
    MethodObject^ := ActiveViewMethodsRecord;
    MethodObject^.SuperclassMethods := ADR (ActiveViewMethodsRecord);
END CloneActiveViewMethods;








(*----------------------------------------------------------------------------
    ValidateActiveView --

    Determine that the indicated object is in fact a valid active view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid active view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateActiveView(    ActiveView : AnActiveView);
VAR
    PrivateView: XActiveView;

BEGIN

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateObjectView (AnObjectView (ActiveView));
    END;
    DEBUGGING*)

    PrivateView := XActiveView (ActiveView);
    IF (PrivateView^.Methods^.ActiveViewTag <> ModuleNumber) THEN
        FatalError ();
    END;

END ValidateActiveView;




BEGIN           (* ActiveViews *)

    CloneObjectViewMethods (ADR (ActiveViewMethodsRecord));
    WITH ActiveViewMethodsRecord DO
        Discard := AnActiveViewDiscardProc (ActiveViewDiscard);
        MethodSize := TSIZE (AnActiveViewMethodsRecord);
        RecordEvent := AnActiveViewRecordProc (Record);
        GetRecordedEvent := AnActiveViewGetEventProc (GetEvent);
        ActOnEvent := AnActiveViewActOnProc (ActOn);
        GetCursor := AnActiveViewGetCursorProc (GetActiveCursor);
        SetCursor := AnActiveViewSetCursorProc (SetActiveCursor);
        SetCursorMode := AnActiveViewSetCursorModeProc (SetActiveCursorMode);
        ActiveViewTag := ModuleNumber;
    END;

END ActiveViews.

