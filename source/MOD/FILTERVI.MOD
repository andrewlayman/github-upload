IMPLEMENTATION MODULE FilterViews;          (* Subclass of ActiveViews *)

    (*  FilterViews provides an object which is a view of a tree node.
        The data object of the tree node is a filter.  Its name is
        displayed using indentation to reflect depth in the tree, and "+"
        and "-" symbols to show whether or not it has children.  The filter
        name is displayed in reverse video if the cursor is on it.

        7/9/87   AJL - Removed references to the Video module.
       10-Jan-89 RSC   Changed Storage to Space    .
        5-Jun-89 AJL   Put filter records into FlexStor.
    *)

(*V9=DEBUGGING Code*)
(*V1=HIER archical filters *)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveViewMethods, AnActiveView,
    (* PROC *)                  CloneActiveViewMethods, ValidateActiveView,
                                InitAsActiveView, UnInitAsActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM FilterOutlines         IMPORT
    (* TYPE *)                  AFilterOutline;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecordPointer;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString;

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

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeNodeAttribute;


CONST
    ModuleNumber            = 16100;



TYPE
    XFilterView             = POINTER TO XFilterViewRecord;
        
    XFilterViewRecord       = RECORD
                                Methods        : AFilterViewMethods;
                                ViewObject     : ATreeNode;
                                ParentView     : AFilterOutline;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : AFilterViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                              END;


    AFilterViewDiscardProc = PROCEDURE (VAR AFilterView   );

    AFilterViewTitleProc   = PROCEDURE (    AFilterView,
                                        VAR ARRAY OF CHAR );

    AFilterViewDisplayProc = PROCEDURE (    AFilterView   );


VAR
    FilterViewMethodsRecord : AFilterViewMethodsRecord;




    (*  Following are the procedures which replace the methods inherited from
        ActiveViews.
    *)


PROCEDURE FilterViewDiscard(VAR FilterView  : XFilterView);

BEGIN                       (* FilterViewDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateFilterView(AFilterView(FilterView));
    END;
      DEBUGGING>*)

    UnInitAsFilterView(AFilterView(FilterView));
    DISPOSE(FilterView);

END FilterViewDiscard;







PROCEDURE FilterViewDisplay(    FilterView  : XFilterView);

VAR
    FilterPtr               : AFilterRecordPointer;
    s                       : ARRAY [0..80] OF CHAR;
    Count                   : CARDINAL;

BEGIN                       (* FilterViewDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateFilterView(AFilterView(FilterView));
    END;
      DEBUGGING>*)

    WITH FilterView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        IF (ViewObject = NIL) THEN
            Fill (s, " ", Lrx-Ulx+1);
            Count := 0;
        ELSE
            FilterPtr := ViewObject^.Methods^.LockFlexStorDataObject (ViewObject);
            Copy (FilterPtr^.Name, s);

            Procustes (s, Lrx-Ulx+1);
            IF (0 IN FilterPtr^.FilterFlags) THEN
                s[Lrx-Ulx+1] := "*";
            END;
            ViewObject^.Methods^.UnlockUnchangedDataObject (ViewObject);
            FilterPtr := NIL;

            Count := ParentView^.Methods^.GetMatchCount (ParentView);
        END;

        PutMatchedString (s, Ulx, Uly, Count, VideoMode, CursorMode,
                            (CursorOn IN Status));
        EXCL(Status, NeedsRedisplay);
    END;

END FilterViewDisplay;







    (*  These are the procedures which are exported from this module  *)


(*----------------------------------------------------------------------------
    InitAsFilterView --

    Initialize the indicated object as a filter view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid filter view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsFilterView(      FilterView     : AFilterView;
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
    PrivateFilterView       : XFilterView;

BEGIN                       (* InitAsFilterView *)

    Fill(s, " ", 0);
    InitAsActiveView(AnActiveView(FilterView), AnObjectView(SuperView), Ulx, 
                     Uly, Lrx, Lry, Box, VideoMode, s, HelpKey, FALSE);
    PrivateFilterView := XFilterView(FilterView);
    WITH PrivateFilterView^ DO
        Methods := AFilterViewMethods(ADR(FilterViewMethodsRecord));
    END;

END InitAsFilterView;







(*----------------------------------------------------------------------------
    CreateFilterView --

    Allocate storage for, and initialize the indicated object as a filter 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid filter view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateFilterView(  VAR FilterView     : AFilterView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL)
                                                       : BOOLEAN;

BEGIN                       (* CreateFilterView *)

    IF (Available(TSIZE(XFilterViewRecord))) THEN
        ALLOCATE(FilterView, TSIZE(XFilterViewRecord));
        InitAsFilterView(FilterView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                         VideoMode, HelpKey);
        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateFilterView;







(*----------------------------------------------------------------------------
    UnInitAsFilterView --

    UnInitialize the indicated object as a filter view.

    Preconditions:
        The object will be a valid filter view object.

    Postconditions:
        Whatever was done by InitAsFilterView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsFilterView(    FilterView : AFilterView);

BEGIN                       (* UnInitAsFilterView *)

    UnInitAsActiveView(AnActiveView(FilterView));

END UnInitAsFilterView;












(*----------------------------------------------------------------------------
    CloneFilterViewMethods --

    Make a copy of the filter view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The filter view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneFilterViewMethods(    MethodObject : AFilterViewMethods);

BEGIN                       (* CloneFilterViewMethods *)

    FatalError();

END CloneFilterViewMethods;








(*----------------------------------------------------------------------------
    ValidateFilterView --

    Determine that the indicated object is in fact a valid filter view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid filter view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateFilterView(    FilterView : AFilterView);

BEGIN                       (* ValidateFilterView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(FilterView));
    END;
      DEBUGGING>*)

    IF (FilterView^.Methods^.FilterViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateFilterView;


BEGIN                       (* FilterViews *)

    CloneActiveViewMethods(AnActiveViewMethods(ADR(FilterViewMethodsRecord)));
    WITH FilterViewMethodsRecord DO
        MethodSize := TSIZE(AFilterViewMethodsRecord);
        Discard    := AFilterViewDiscardProc(FilterViewDiscard);
        Display    := AFilterViewDisplayProc(FilterViewDisplay);
        FilterViewTag := ModuleNumber;
    END;

END FilterViews.
