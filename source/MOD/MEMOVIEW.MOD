IMPLEMENTATION MODULE MemoViews;          (* Subclass of ActiveViews *)

    (*  MemoViews provides an object which is a view of a tree node.
        The data object of the tree node is a memo name.  The memo name is
        displayed using indentation to reflect depth in the tree, and "+"
        and "-" symbols to show whether or not it has children.  The memo
        name is displayed in reverse video if the cursor is on it.

        07/10/87 AJL - Removed import of Video.
        12-Oct-87 LAA   Called FormatIndentation to create the +- prefix to
                        memo view strings.
        24-Dec-87 LAA   Left justified the first line of a memo used as it's
                        title, and ensured that heavily indented memos don't
                        crash the system.
        10-Jan-89 RSC   Changed Storage to Space    .
    *)

(*V9=DEBUGGING Code*)


FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveViewMethods, AnActiveView,
    (* PROC *)                  CloneActiveViewMethods, ValidateActiveView,
                                InitAsActiveView, UnInitAsActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM Indentation            IMPORT
    (* PROC *)                  FormatIndentation;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, LengthOf, SetLengthOf, Copy, Overlay,
                                Procustes, ConcatS, LJust;

FROM Memos                  IMPORT
    (* TYPE *)                  AMemoRecordPointer;

FROM ObjectViews            IMPORT
    (* TYPE *)                  AnObjectView;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  CopyLine;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;


CONST
    ModuleNumber            = 17400;



TYPE
    XMemoView             = POINTER TO XMemoViewRecord;
        
    XMemoViewRecord       = RECORD
                                Methods        : AMemoViewMethods;
                                ViewObject     : ATreeNode;
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
                                Status         : AMemoViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                              END;



    AMemoViewDiscardProc = PROCEDURE (VAR AMemoView     );

    AMemoViewTitleProc   = PROCEDURE (    AMemoView,
                                      VAR ARRAY OF CHAR );

    AMemoViewDisplayProc = PROCEDURE (    AMemoView     );


VAR
    MemoViewMethodsRecord : AMemoViewMethodsRecord;




    (*  Following are the procedures which replace the methods inherited from
        ActiveViews.
    *)


PROCEDURE MemoViewDiscard(VAR MemoView  : XMemoView);

BEGIN                       (* MemoViewDiscard *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateMemoView(AMemoView(MemoView));
    END;
    (*DEBUGGING>*)

    UnInitAsMemoView(AMemoView(MemoView));
    DISPOSE(MemoView);

END MemoViewDiscard;





PROCEDURE MemoViewDisplay(    MemoView  : XMemoView);

CONST
    SpacesPerLevel = 2;

VAR
    Leader                  : CARDINAL;
    Memo                    : AMemoRecordPointer;
    s                       : ARRAY [0..81] OF CHAR;

BEGIN                       (* MemoViewDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateMemoView(AMemoView(MemoView));
    END;
    DEBUGGING>*)

    WITH MemoView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        IF (ViewObject = NIL) THEN
            Fill (s, " ", Lrx-Ulx+1);
            IF (CursorOn IN Status) THEN
                PutString (s, Ulx, Uly, cvideonormal);
            ELSE
                PutString (s, Ulx, Uly, VideoMode);
            END;
        ELSE
            (*
            Leader := ViewObject^.Methods^.IndentationLevel (ViewObject)
                    * SpacesPerLevel;
            Fill (s, " ", Leader);
            IF (ViewObject^.Methods^.FirstChild (ViewObject) = NIL) THEN
                s[Leader+1] := "-";
            ELSE
                s[Leader+1] := "+";
            END;
            s[Leader+2] := " ";
            SetLengthOf (s, Leader+2);
            *)
            FormatIndentation(ViewObject, Lrx-Ulx+1, s);          (* 12-Oct-87 LAA *)
            ConcatS(s, " ");
            Leader := LengthOf(s);
            IF (Leader > Lrx-Ulx+1) THEN                          (* 24-Dec-87 LAA *)
                Leader := Lrx-Ulx+1;
            END;
            SetLengthOf(s, Leader);
            PutString (s, Ulx, Uly, VideoMode);

            Memo := ViewObject^.Methods^.GetDataObject (ViewObject);
            CopyLine (Memo^.text, 0, s);
            LJust(s);                                             (* 24-Dec-87 LAA *)
            Procustes (s, Lrx-Ulx+1-Leader);                      (* 12-Oct-87 LAA *)
            IF (CursorOn IN Status) THEN
                PutString (s, Ulx+Leader, Uly, cvideonormal);
            ELSE
                PutString (s, Ulx+Leader, Uly, VideoMode);
            END;
        END;

        EXCL(Status, NeedsRedisplay);
    END;

END MemoViewDisplay;







    (*  These are the procedures which are exported from this module  *)


(*----------------------------------------------------------------------------
    InitAsMemoView --

    Initialize the indicated object as a memo view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid memo view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsMemoView(      MemoView     : AMemoView;
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
    PrivateMemoView       : XMemoView;

BEGIN                       (* InitAsMemoView *)

    Fill(s, " ", 0);
    InitAsActiveView(AnActiveView(MemoView), AnObjectView(SuperView), Ulx, 
                     Uly, Lrx, Lry, Box, VideoMode, s, HelpKey, FALSE);
    PrivateMemoView := XMemoView(MemoView);
    WITH PrivateMemoView^ DO
        Methods := AMemoViewMethods(ADR(MemoViewMethodsRecord));
    END;

END InitAsMemoView;







(*----------------------------------------------------------------------------
    CreateMemoView --

    Allocate storage for, and initialize the indicated object as a memo 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid memo view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateMemoView(  VAR MemoView     : AMemoView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL)
                                                       : BOOLEAN;

BEGIN                       (* CreateMemoView *)

    IF (Available(TSIZE(XMemoViewRecord))) THEN
        ALLOCATE(MemoView, TSIZE(XMemoViewRecord));
        InitAsMemoView(MemoView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                       VideoMode, HelpKey);
        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateMemoView;







(*----------------------------------------------------------------------------
    UnInitAsMemoView --

    UnInitialize the indicated object as a memo view.

    Preconditions:
        The object will be a valid memo view object.

    Postconditions:
        Whatever was done by InitAsMemoView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsMemoView(    MemoView : AMemoView);

BEGIN                       (* UnInitAsMemoView *)

    UnInitAsActiveView(AnActiveView(MemoView));

END UnInitAsMemoView;












(*----------------------------------------------------------------------------
    CloneMemoViewMethods --

    Make a copy of the memo view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The memo view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneMemoViewMethods(    MethodObject : AMemoViewMethods);

BEGIN                       (* CloneMemoViewMethods *)

    FatalError();

END CloneMemoViewMethods;








(*----------------------------------------------------------------------------
    ValidateMemoView --

    Determine that the indicated object is in fact a valid memo view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid memo view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateMemoView(    MemoView : AMemoView);

BEGIN                       (* ValidateMemoView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(MemoView));
    END;
    DEBUGGING>*)

    IF (MemoView^.Methods^.MemoViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateMemoView;


BEGIN                       (* MemoViews *)

    CloneActiveViewMethods(AnActiveViewMethods(ADR(MemoViewMethodsRecord)));
    WITH MemoViewMethodsRecord DO
        MethodSize := TSIZE(AMemoViewMethodsRecord);
        Discard := AMemoViewDiscardProc(MemoViewDiscard);
        Display := AMemoViewDisplayProc(MemoViewDisplay);
        MemoViewTag := ModuleNumber;
    END;

END MemoViews.
