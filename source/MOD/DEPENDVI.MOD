IMPLEMENTATION MODULE DependViews;          (* Subclass of ActiveViews *)

    (*  DependViews provides an object which is a view of a tree node.
        The data object of the tree node is a task name.  Its name is
        displayed using indentation to reflect depth in the tree, and "+"
        and "-" symbols to show whether or not it is a summary task.  The
        name is displayed in reverse video if the cursor is on it.

       12-Jan-88 RSC    "Unchanged" fixes.
       23-Jan-89 RSC    Changed Storage to Space    .
       27-Feb-89 EGK    Added stuff to show controlling dependencies.
       28-Apr-89 EGK    Added support for "?" indicator, for tasks that
                        need recalc.
        1-Sep-89 AJL    Added new parameter (FALSE) to EdgeIsCritical and
                        EdgeIsControlling.
       21-Feb-90 KKC   Remove import of Timeu.
    *)

(*V9=DEBUGGING Code*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveViewMethods, AnActiveView,
    (* PROC *)                  CloneActiveViewMethods, ValidateActiveView,
                                InitAsActiveView, UnInitAsActiveView;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ATaskStatus, ATaskName;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Indentation            IMPORT
    (* PROC *)                  FormatIndentation;

FROM DependOutlines         IMPORT
    (* TYPE *)                  ADependOutline;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM EdgeInfo               IMPORT
    (* PROC *)                  EdgeIsNormal, DescribeEdge,
                                EdgeIsControlling, EdgeIsCritical;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString, PutAttribute;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Procustes, Copy, SetLengthOf, SetString,
                                ConcatS, ConcatLS, LengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM ObjectViews            IMPORT
    (* TYPE *)                  AnObjectView;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeNodeAttribute;


CONST
    ModuleNumber            = 19600;



TYPE
    XDependView             = POINTER TO XDependViewRecord;
        
    XDependViewRecord       = RECORD
                                Methods        : ADependViewMethods;
                                ViewObject     : ATreeNode;
                                ParentView     : ADependOutline;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : ADependViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                              END;


    ADependViewDiscardProc = PROCEDURE (VAR ADependView   );

    ADependViewTitleProc   = PROCEDURE (    ADependView,
                                        VAR ARRAY OF CHAR );

    ADependViewDisplayProc = PROCEDURE (    ADependView   );


VAR
    DependViewMethodsRecord : ADependViewMethodsRecord;
    DependFont              : ARRAY [0..15] OF CHAR;




    (*  Following are the procedures which replace the methods inherited from
        ActiveViews.
    *)


PROCEDURE DependViewDiscard(VAR DependView  : XDependView);

BEGIN                       (* DependViewDiscard *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateDependView(ADependView(DependView));
    END;
    (*DEBUGGING>*)

    UnInitAsDependView(ADependView(DependView));
    DISPOSE(DependView);

END DependViewDiscard;




PROCEDURE DependViewDisplay(    DependView  : XDependView);

CONST
    StatusLength            = 3;
    DescriptionLength       = 11;       (* Taken up by the description column *)

VAR
    Leader                  : CARDINAL;
    Task                    : ATaskPtr;
    TaskName                : ATaskName;
    mode                    : avidmode;
    MatchLength             : CARDINAL;
    s                       : ARRAY [0..81] OF CHAR;
    EdgePtr                 : AnEdgePtr;
    InALoop                 : BOOLEAN;
    NeedsCalc               : BOOLEAN;
    X                       : ascreenx;
    TaskSpaceLength         : CARDINAL;
    RealEdge                : BOOLEAN;


BEGIN                       (* DependViewDisplay *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateDependView(ADependView(DependView));
    END;
    (*DEBUGGING>*)

    WITH DependView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        mode := VideoMode;
        Fill (s, " ", StatusLength);
        TaskSpaceLength := Lrx-Ulx+1-StatusLength-DescriptionLength;

        IF (ViewObject = NIL) THEN
            PutString (s, Ulx, Uly, videodatebar);
            Fill (s, " ", TaskSpaceLength+DescriptionLength);
            X := Ulx + StatusLength;
            IF (CursorOn IN Status) THEN
                PutString (s, X, Uly, cvideonormal);
            ELSE
                PutString (s, X, Uly, mode);
            END;
        ELSE
            Task := ViewObject^.Methods^.LockFlexStorDataObject (ViewObject);
            InALoop := (Loop IN Task^.TaskStatusSet);
            NeedsCalc := (NeedsRecalculate IN Task^.TaskStatusSet);
            Copy (Task^.taskname, TaskName);
            EdgePtr := Task^.WorkSpace;
            ViewObject^.Methods^.UnlockUnchangedDataObject (ViewObject);
            RealEdge := FALSE;

            IF (ViewObject^.Methods^.TestAttributeBit (ViewObject, Select2)) THEN
                RealEdge := TRUE;
                mode := videofilter1;
                s[1] := DependFont[1];          (* "P" *)
                IF (InALoop) THEN
                    s[1] := DependFont[7];      (* "L" *)
                ELSIF (NOT EdgeIsNormal (EdgePtr)) THEN
                    s[1] := DependFont[2];      (* "p" *)
                END;
                IF (NeedsCalc) THEN
                    s[2] := DependFont[11];     (* "?" *)
                ELSIF (EdgeIsCritical (EdgePtr,FALSE)) THEN
                    s[2] := DependFont[8];      (* "C" *)
                END;
                IF (EdgeIsControlling (EdgePtr, 0, FALSE)) AND (NOT NeedsCalc) THEN
                    s[3] := DependFont[9];      (* "" *)
                END;
            ELSIF (ViewObject^.Methods^.TestAttributeBit (ViewObject, Select1)) THEN
                RealEdge := TRUE;
                mode := videofilter2;
                s[1] := DependFont[3];          (* "S" *)
                IF (InALoop) THEN
                    s[1] := DependFont[7];      (* "L" *)
                ELSIF (NOT EdgeIsNormal (EdgePtr)) THEN
                    s[1] := DependFont[4];      (* "s" *)
                END;
                IF (NeedsCalc) THEN
                    s[2] := DependFont[11];     (* "?" *)
                ELSIF (EdgeIsCritical (EdgePtr,FALSE)) THEN
                    s[2] := DependFont[8];      (* "C" *)
                END;
                IF (EdgeIsControlling (EdgePtr, 0,FALSE)) AND (NOT NeedsCalc) THEN
                    s[3] := DependFont[9];      (* "" *)
                END;
            ELSIF (ViewObject^.Methods^.TestAttributeBit (ViewObject, TempFlag1)) THEN

                    (*  TempFlag1, set by TLDepend.MOD, tells us that this
                        is the task we're showing dependencies of.  Put
                        font character #10 in the last column of the status
                        section.        *)

                s[StatusLength] := DependFont[10];
            END;
            PutString (s, Ulx, Uly, videodatebar);

            FormatIndentation (ViewObject, TaskSpaceLength-StatusLength-1, s);
            ConcatS (s, " ");
            PutString (s, Ulx+StatusLength, Uly, mode);
            Leader := LengthOf(s) + StatusLength;
            IF (Leader < TaskSpaceLength) THEN
                Copy (TaskName, s);
                Procustes (s, TaskSpaceLength+StatusLength-Leader);
                MatchLength := ParentView^.Methods^.GetMatchCount (ParentView);
                IF (MatchLength > 0) AND (NOT ViewObject^.Methods^.TestAttributeBit
                        (ViewObject, SelfMatch)) THEN
                    MatchLength := 0;
                END;
                X := Ulx+Leader;
                IF (CursorOn IN Status) THEN
                    PutString (s, X, Uly, cvideonormal);
                    PutAttribute (X, Uly, MatchLength, videosecondarycursor);
                ELSE
                    PutString (s, X, Uly, mode);
                    PutAttribute (X, Uly, MatchLength, videoenhance);
                END;
            END;
            X := Ulx+StatusLength+TaskSpaceLength;
            SetString (s, " ");
            PutString (s, X, Uly, mode);
            INC(X);
            IF (RealEdge) AND (NOT EdgeIsNormal (EdgePtr)) THEN
                DescribeEdge (EdgePtr, FALSE, s);
                Procustes (s, DescriptionLength-1);
            ELSE
                Fill (s, " ", DescriptionLength-1);
            END;
            IF (CursorOn IN Status) THEN
                PutString (s, X, Uly, cvideonormal);
            ELSE
                PutString (s, X, Uly, mode);
            END;
        END;

        EXCL(Status, NeedsRedisplay);
    END;

END DependViewDisplay;







    (*  These are the procedures which are exported from this module  *)


(*----------------------------------------------------------------------------
    InitAsDependView --

    Initialize the indicated object as a filter view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid filter view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsDependView(    DependView   : ADependView;
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
    PrivateDependView     : XDependView;

BEGIN                       (* InitAsDependView *)

    Fill(s, " ", 0);
    InitAsActiveView(AnActiveView(DependView), AnObjectView(SuperView), Ulx, 
                     Uly, Lrx, Lry, Box, VideoMode, s, HelpKey, FALSE);
    PrivateDependView := XDependView(DependView);
    WITH PrivateDependView^ DO
        Methods := ADependViewMethods(ADR(DependViewMethodsRecord));
    END;

END InitAsDependView;







(*----------------------------------------------------------------------------
    CreateDependView --

    Allocate storage for, and initialize the indicated object as a filter 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid filter view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateDependView(VAR DependView   : ADependView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL)
                                                       : BOOLEAN;

BEGIN                       (* CreateDependView *)

    IF (HeapAvailable()) THEN
        ALLOCATE(DependView, TSIZE(XDependViewRecord));
        InitAsDependView(DependView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                         VideoMode, HelpKey);
        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateDependView;







(*----------------------------------------------------------------------------
    UnInitAsDependView --

    UnInitialize the indicated object as a filter view.

    Preconditions:
        The object will be a valid filter view object.

    Postconditions:
        Whatever was done by InitAsDependView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsDependView(    DependView : ADependView);

BEGIN                       (* UnInitAsDependView *)

    UnInitAsActiveView(AnActiveView(DependView));

END UnInitAsDependView;












(*----------------------------------------------------------------------------
    CloneDependViewMethods --

    Make a copy of the filter view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The filter view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneDependViewMethods(    MethodObject : ADependViewMethods);

BEGIN                       (* CloneDependViewMethods *)

    FatalError();

END CloneDependViewMethods;








(*----------------------------------------------------------------------------
    ValidateDependView --

    Determine that the indicated object is in fact a valid filter view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid filter view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateDependView(    DependView : ADependView);

BEGIN                       (* ValidateDependView *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(DependView));
    END;
    (*DEBUGGING>*)

    IF (DependView^.Methods^.DependViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateDependView;


BEGIN                       (* DependViews *)

    CloneActiveViewMethods(AnActiveViewMethods(ADR(DependViewMethodsRecord)));
    WITH DependViewMethodsRecord DO
        MethodSize := TSIZE(ADependViewMethodsRecord);
        Discard    := ADependViewDiscardProc(DependViewDiscard);
        Display    := ADependViewDisplayProc(DependViewDisplay);
        DependViewTag := ModuleNumber;
    END;

    GetMessage (ModuleNumber, DependFont);  (* "PpSsBbLC" *)

END DependViews.
