IMPLEMENTATION MODULE StringViews;          (* Subclass of ActiveViews *)

    (*  StringViews provides an object which is a view of an edit node.
        This allows an individual edit node to be viewed and edited.  All
        the commands which apply to editing a line of text as an individual
        entity are implemented here.  The view provided is used as a
        subview of EditViews, which handles editing an entire workspace of
        text.

        07/10/87  AJL - Converted to use cursor control procedures from
                        Kbio instead of Video.

       10-Jan-89  RSC   Changed Storage to Space    .

    *)

(*V9=DEBUGGING Code*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveViewMethods, AnActiveView,
    (* PROC *)                  CloneActiveViewMethods, ValidateActiveView,
                                InitAsActiveView, UnInitAsActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode, ASetOfCodes;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error;

FROM EditObjects            IMPORT
    (* TYPE *)                  AnEditNode;

FROM EditViews              IMPORT
    (* TYPE *)                  AnEditView;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString,
    (* PROC *)                  ACursorType, SetCursorType, GotoXY;


FROM Keys                   IMPORT
    (* CONST *)                 Fwrd, Reverse, HomeKey, EndKey, BackSpace,
                                DeleteKey, InsertKey, RollLeft, RollRight;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Remove, LengthOf, SetLengthOf, ConcatLS,
                                SetString;

FROM ObjectViews            IMPORT
    (* TYPE *)                  AnObjectView;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug,
    (* PROC *)                  PutRug;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;


CONST
    ModuleNumber            = 15200;



TYPE
    XStringView             = POINTER TO XStringViewRecord;
        
    XStringViewRecord       = RECORD
                                Methods        : AStringViewMethods;
                                ViewObject     : AnEditNode;
                                ParentView     : AnEditView;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : AStringViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                              END;




VAR
    StringViewMethodsRecord : AStringViewMethodsRecord;




    (*  Following are the procedures which replace the methods inherited from
        ActiveViews.
    *)


PROCEDURE StringViewDiscard(VAR StringView  : XStringView);

BEGIN                       (* StringViewDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateStringView(AStringView(StringView));
    END;
    DEBUGGING>*)

    UnInitAsStringView(AStringView(StringView));
    DISPOSE(StringView);

END StringViewDiscard;






PROCEDURE StringViewDisplay(    StringView  : XStringView);

VAR
    s                       : ARRAY [0..81] OF CHAR;
    s2                      : ARRAY [0..81] OF CHAR;
    LeftMargin              : CARDINAL;
    RightMargin             : CARDINAL;
    CursorColumn            : CARDINAL;
    InsertMode              : BOOLEAN;

BEGIN                       (* StringViewDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateStringView(AStringView(StringView));
    END;
    DEBUGGING>*)

    WITH StringView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        Fill(s, " ", 0);
        LeftMargin := ParentView^.Methods^.GetLeftMargin(ParentView);
        RightMargin := ParentView^.Methods^.GetRightMargin(ParentView);
        IF (ViewObject <> NIL) THEN
            ViewObject^.Methods^.GetLine(ViewObject, LeftMargin, 999, s);
            IF (LengthOf(s) > RightMargin) THEN
                SetLengthOf(s, RightMargin);
            END;
        END;
        Fill(s2, " ", (RightMargin - LeftMargin + 1) - LengthOf(s));
        ConcatLS(s, s2);
        PutString(s, Ulx + 1, Uly, VideoMode);
        IF (CursorOn IN Status) THEN
            CursorColumn := ParentView^.Methods^.GetCursorX(ParentView);
            InsertMode := ParentView^.Methods^.GetInsertMode(ParentView);
            GotoXY(Ulx + CursorColumn - LeftMargin + 1, Uly);
            IF (InsertMode) THEN
                SetCursorType(BlockCursor);
            ELSE
                SetCursorType(UnderlineCursor);
            END;
        END;
        EXCL(Status, NeedsRedisplay);
    END;

END StringViewDisplay;





    (*  These are the procedures which are exported from this module  *)


(*----------------------------------------------------------------------------
    InitAsStringView --

    Initialize the indicated object as a string view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid string view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsStringView(    StringView   : AStringView;
                               SuperView    : AnEditView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL);

VAR
    s                       : ARRAY [0..1] OF CHAR;
    PrivateStringView       : XStringView;

BEGIN                       (* InitAsStringView *)

    Fill(s, " ", 0);
    InitAsActiveView(AnActiveView(StringView), AnActiveView(SuperView), Ulx, 
                     Uly, Lrx, Lry, Box, VideoMode, s, HelpKey, FALSE);
    PrivateStringView := XStringView(StringView);
    WITH PrivateStringView^ DO
        Methods := AStringViewMethods(ADR(StringViewMethodsRecord));
    END;

END InitAsStringView;







(*----------------------------------------------------------------------------
    CreateStringView --

    Allocate storage for, and initialize the indicated object as a string 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid string view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateStringView(VAR StringView   : AStringView;
                               SuperView    : AnEditView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL)
                                                       : BOOLEAN;

BEGIN                       (* CreateStringView *)

    IF (HeapAvailable()) THEN
        ALLOCATE(StringView, TSIZE(XStringViewRecord));
        InitAsStringView(StringView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                         VideoMode, HelpKey);

        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateStringView;







(*----------------------------------------------------------------------------
    UnInitAsStringView --

    UnInitialize the indicated object as a string view.

    Preconditions:
        The object will be a valid string view object.

    Postconditions:
        Whatever was done by InitAsStringView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsStringView(    StringView : AStringView);

BEGIN                       (* UnInitAsStringView *)

    UnInitAsActiveView(AnActiveView(StringView));

END UnInitAsStringView;







(*----------------------------------------------------------------------------
    ValidateStringView --

    Determine that the indicated object is in fact a valid string view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid string view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateStringView(    StringView : AStringView);

BEGIN                       (* ValidateStringView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(StringView));
    END;
    DEBUGGING>*)

    IF (StringView^.Methods^.StringViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateStringView;


BEGIN                       (* StringViews *)

    CloneActiveViewMethods(AnActiveViewMethods(ADR(StringViewMethodsRecord)));
    WITH StringViewMethodsRecord DO
        MethodSize := TSIZE(AStringViewMethodsRecord);
        Discard := AStringViewDiscardProc(StringViewDiscard);
        Display := AStringViewDisplayProc(StringViewDisplay);
        StringViewTag := ModuleNumber;
    END;

END StringViews.
