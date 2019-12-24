MODULE TLDepend;

(*  =========================================================================
    Last Edit : September 14, 1989 4:41PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        12-Jan-88  RSC  "Unchanged" changes.
        19-Jan-88  LAA  Made this an installable overlay.
        05-Mar-88  LAA  Pass ModuleNumber as help number.
         6-Jan-89  RSC  Moved "AnOverlayProc" reference.
        21-Mar-89  EGK  Made the box bigger to handle new columns.  Also
                        used TempFlag1 to mark which task is the one
                        whose dependencies are being shown.
        27-Mar-89  EGK  Force Gantt chart's cursor node to be above box.
         4-Jun-89  EGK  Changed SendNotice call to be more specific about
                        which tasks were opened.
        19-Jun-89  AJL  Removed FiltersOn boolean, replaced by 
                        SetRevealFilterDisabled, and QueryRevealFilterOn.
        31-Jul-89  KKC  Call ContinuationBox instead of NoYes.
        09-Aug-89  KKC  Add copyright message.
        15-Aug-89  RSC  Temporarily fool with notice sending because of a
                        name conflict between Notices.AnOccasion and
                        GanttOutlines.AGanttOutlineSpecificChange.
                        Remove this at any time in the future, as I have
                        renamed the offender inside Notices.
        14-Sep-89  WKH  Made dependency list box bigger for compressed mode
        14-Dec-89  MWP  Added checking for existence of rodents.
        27-Dec-89  LAA  Removed the Ok button, since double-clicking now does
                        the same thing.
         5-Jan-90 MWP   Put the Ok button back in.
        6-Oct-90 AJL    Add insert and delete mouse buttons.
    =========================================================================
*)


FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ATaskName,
    (* VAR *)                   TaskTree;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Changer                IMPORT
    (* PROC *)                  ChangeEdge, UnjoinTasks;

FROM Chart                  IMPORT
    (* VAR  *)                  GanttChart, BugTaskA, BugTaskB, CursorTask;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState, DisplayTheChart;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* PROC *)                  CurrentLayout;

FROM DependOutlines         IMPORT
    (* TYPE *)                  ADependOutline,
    (* PROC *)                  CreateDependOutline;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Message, NotYetImplemented, Burp,
                                ContinuationBox;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr,
    (* PROC *)                  FindEdge;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent, GetNextEvent;

FROM FilterRc               IMPORT
    (* VAR *)                   RevealFilter;

FROM Filters                IMPORT
    (* PROC *)                  ShowFilterLight,
                                SetRevealFilterDisabled, QueryRevealFilterOn;


FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineSpecificChange;

FROM Helper                 IMPORT 
    (* TYPE *)                  AScreenAction,
    (* PROC *)                  GiveHelp;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol,
    (* TYPE *)                  avidmode,
    (* PROC *)                  PutString;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey, ExitKey, DoIt, EditKey, DeleteKey,
                                Up, Down, PgUpKey, PgDnKey, HomeKey, EndKey,
                                UndoKey, AltUndoKey, HelpKey, RedoKey;

FROM Layout                 IMPORT
    (* VAR *)                   GanttWEnd, GanttWStart;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, ConcatLS, ConcatS, Fill, Procustes,
                                LengthOf, SetLengthOf, Copy, Insert;


FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, DisplayMessage, ConcatMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AStep,
    (* PROC *)                  SendNotices;

IMPORT Notices;                 (* RSC 15-Aug-89 *)

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
                                ATreeNodeAttribute,
                                ATreeNodeMethods, ATreeNodeProcessingProc;

FROM Undo                   IMPORT
    (* TYPE *)                  AnUndoableObject, AnUndoAction,
    (* PROC *)                  BeginTransactionSet, EndTransactionSet,
                                NotifyUndo, UndoLastChange, DebugUndo;

FROM   Mouse                IMPORT
    (* PROC *)                  MousePresent;                    (* 14-Dec-89 MWP *)


CONST
    ModuleNumber            = 19800;
    FontNumber              = 19600;     (* From DependViews *)

    MaxTitleLength          = 40;
    DistanceFromGanttWStart = 9;

VAR
    Outline         : ADependOutline;
    FirstNode       : ATreeNode;
    CursorNode      : ATreeNode;
    Node            : ATreeNode;
    ParentNode      : ATreeNode;
    Event           : AnEvent;
    Length          : CARDINAL;
    DependNode      : ATreeNode;
    ShowPred        : BOOLEAN;
    ShowSucc        : BOOLEAN;
    Ulx, Uly,
    Lrx, Lry        : CARDINAL;
    AboveBox        : CARDINAL;
    NeedToCreate    : BOOLEAN;
    NeedUpdate      : BOOLEAN;
    OldBugTaskA     : ATreeNode;
    OldBugTaskB     : ATreeNode;
    Selected        : BOOLEAN;
    RecordThis      : BOOLEAN;
    OverlayID       : AnOverlayID;
    Done            : BOOLEAN;
    DependFont      : ARRAY [0..15] OF CHAR;
    s               : ARRAY [0..100] OF CHAR;
    s2              : ARRAY [0..30] OF CHAR;


    (*  For all nodes, we will use selection bit 0 to store the old visibility
        state, and bit 3 to store the old open/close state.  We will probably
        modify these values during the viewing process.     *)

(*$S+*)


PROCEDURE SaveVisibility    (VAR Node    : ATreeNode;
                                 Context : ADDRESS   );
VAR
    Value : BOOLEAN;
BEGIN
    Value := Node^.Methods^.Visible (Node);
    Node^.Methods^.SetAttributeBit (Node, Select0, Value);
    Value := Node^.Methods^.ChildrenVisible (Node);
    Node^.Methods^.SetAttributeBit (Node, Select3, Value);
END SaveVisibility;




PROCEDURE RestoreVisibility    (VAR Node    : ATreeNode;
                                    Context : ADDRESS   );
VAR
    Value : BOOLEAN;
BEGIN
    Value := Node^.Methods^.TestAttributeBit (Node, Select0);
    Node^.Methods^.SetVisible (Node, Value);
    Value := Node^.Methods^.TestAttributeBit (Node, Select3);
    Node^.Methods^.SetChildrenVisible (Node, Value);
END RestoreVisibility;





PROCEDURE HideNode  (VAR    Node       : ATreeNode;
                            Context    : ADDRESS   );
BEGIN
    Node^.Methods^.SetVisible (Node, FALSE);
    Node^.Methods^.SetAttributeBit (Node, Select1, FALSE);
    Node^.Methods^.SetAttributeBit (Node, Select2, FALSE);
    Node^.Methods^.SetAttributeBit (Node, TempFlag1, FALSE);
END HideNode;





PROCEDURE ShowNode  (Node           : ATreeNode;
                     SendNotice     : BOOLEAN   );
VAR
    Parent                  : ATreeNode;

BEGIN
    Node^.Methods^.SetVisible (Node, TRUE);
    Parent := Node^.Methods^.Parent (Node);
    WHILE (Parent <> NIL) DO
        Parent^.Methods^.SetVisible (Parent, TRUE);
        IF (NOT Parent^.Methods^.ChildrenVisible (Parent)) THEN
            IF (SendNotice) THEN
                SendNotices (Notices.OpenATask, BeforeActing, Parent); (* 8/15/89 RSC *)
            END;
            Parent^.Methods^.SetChildrenVisible (Parent, TRUE);
        END;
        Parent := Parent^.Methods^.Parent (Parent);
    END;
END ShowNode;




PROCEDURE InitBox   (Node   : ATreeNode) : BOOLEAN;
VAR
    Title           : ARRAY [0..60] OF CHAR;
    Pos             : CARDINAL;
    MaxName         : CARDINAL;
    Name            : ATaskName;
    TaskPtr         : ATaskPtr;
    LocalBoxType    : ABoxType;
BEGIN

    IF (Node = NIL) THEN
        SetLengthOf (Title, 0);
    ELSE
        GetMessage (ModuleNumber+2, Title);         (* ' "' *)
        Pos := LengthOf(Title) + 1;
        ConcatMessage (Title, ModuleNumber+3);      (* '" Dependencies ' *)
        MaxName := MaxTitleLength - LengthOf(Title);

        TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
        Copy (TaskPtr^.taskname, Name);
        Node^.Methods^.UnlockUnchangedDataObject (Node);
        IF (LengthOf(Name) > MaxName) THEN
            SetLengthOf (Name, MaxName);
        END;

        Insert (Title, Name, Pos);
    END;

    GanttChart^.Methods^.ForceToPosition (GanttChart, Node, AboveBox);       (* 3/27/89 EGK *)

    IF ( MousePresent () ) THEN                                  (* 14-Dec-89 MWP *)
      LocalBoxType := ABoxType{DoubleBox,HasOk,HasCancel,HasVScroll,
                               HasInsert,HasDelete }; (* 5-Jan-89 MWP *)
    ELSE
      LocalBoxType := ABoxType{DoubleBox};
    END;

    IF (NOT CreateDependOutline (Outline, NIL, Ulx, Uly, Lrx, Lry,
            LocalBoxType, videonormal, Title, ModuleNumber,  (* 05-Mar-88 LAA *)
            TRUE)) THEN

        DisplayMessage (ModuleNumber);     (* "Not enough memory for the view" *)
        Burp ();
        RETURN FALSE;
    ELSE
        Outline^.Methods^.SetObject (Outline, TaskTree);
        Outline^.Methods^.SetCursor (Outline, TRUE);
        Outline^.Methods^.SetCursorNode (Outline, Node);
        Outline^.Methods^.ResetMatching (Outline);
        NeedToCreate := FALSE;
    END;
    RETURN TRUE;
END InitBox;




PROCEDURE FilterDependencies (Node      : ATreeNode);

VAR
    DependNode          : ATreeNode;
    DependTask          : ATaskPtr;
    FirstNode           : ATreeNode;
    Edge                : AnEdgePtr;
    AntePtr             : AnEdgePtr;
    DescPtr             : AnEdgePtr;
    Task                : ATaskPtr;
    CursorNode          : ATreeNode;
BEGIN

    IF (Node = NIL) THEN
        RETURN;
    END;

    CursorNode := Outline^.Methods^.GetCursorNode (Outline);

    (*  Hide everything, and then reveal the joined tasks *)

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
            HideNode, NIL);

    ShowNode (Node, FALSE);        (* Of course, show ourself *)

        (*  Tell DependViews that we are the reference node, the
            task that we're showing dependencies of               *)

    Node^.Methods^.SetAttributeBit (Node, TempFlag1, TRUE);

    (*  Now find and reveal our joins *)

    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    AntePtr := Task^.antetasks;
    DescPtr := Task^.desctasks;
    Node^.Methods^.UnlockUnchangedDataObject (Node);

    IF (ShowPred) THEN
        Edge := AntePtr;
        WHILE (Edge <> NIL) DO
            DependNode := Edge^.headtask;
            ShowNode (DependNode, FALSE);
            DependNode^.Methods^.SetAttributeBit (DependNode, Select2, TRUE);
            DependTask := DependNode^.Methods^.LockFlexStorDataObject (DependNode);
            DependTask^.WorkSpace := Edge;
            DependNode^.Methods^.UnlockFlexStorDataObject (DependNode);
            Edge := Edge^.taillink;
        END;
    END;
    IF (ShowSucc) THEN
        Edge := DescPtr;
        WHILE (Edge <> NIL) DO
            DependNode := Edge^.tailtask;
            ShowNode (DependNode, FALSE);
            DependNode^.Methods^.SetAttributeBit (DependNode, Select1, TRUE);
            DependTask := DependNode^.Methods^.LockFlexStorDataObject (DependNode);
            DependTask^.WorkSpace := Edge;
            DependNode^.Methods^.UnlockFlexStorDataObject (DependNode);
            Edge := Edge^.headlink;
        END;
    END;
    FirstNode := TaskTree^.Methods^.GetFirstVisible (TaskTree);
    Outline^.Methods^.SetFirst (Outline, FirstNode);
    IF (NOT CursorNode^.Methods^.Visible (CursorNode)) THEN
        CursorNode := Node;
    END;
    Outline^.Methods^.SetCursorNode (Outline, CursorNode);
    Outline^.Methods^.ResetMatching (Outline);
    NeedUpdate := FALSE;

END FilterDependencies;




PROCEDURE TryToUnjoin   ( TaskA, TaskB : ATreeNode );
VAR
    NewNode             : ATreeNode;
    NullString          : ARRAY [0..0] OF CHAR;
BEGIN
    GetMessage (ModuleNumber+4, s);     (* "Really delete this dependency?" *)
    SetLengthOf(NullString, 0);
    IF ( ContinuationBox (s, NullString, NoHelp) ) THEN
        NewNode := DependNode^.Methods^.NextForDisplay (DependNode);
        IF (NewNode = NIL) THEN
            NewNode := DependNode^.Methods^.PrevForDisplay (DependNode);
        END;
        Outline^.Methods^.SetCursorNode (Outline, NewNode);
        UnjoinTasks (TaskA, TaskB);
        NeedUpdate := TRUE;
    END;
END TryToUnjoin;



PROCEDURE ProceedWithSelection (Node    : ATreeNode) : BOOLEAN;
VAR
    WasVisible      : BOOLEAN;
    NullString      : ARRAY [0..0] OF CHAR;

BEGIN
    IF NOT (QueryRevealFilterOn()) THEN
        RETURN TRUE;
    END;

    RestoreVisibility (Node, NIL);
    IF (Node^.Methods^.Visible (Node)) THEN
        RETURN TRUE;
    END;

    GetMessage (ModuleNumber+5, s);     (* "... will turn off filtering.  Proceed?" *)
    SetLengthOf(NullString, 0);
    IF ( ContinuationBox (s, NullString, NoHelp) ) THEN
        UnSetState (Filtered);
        SetRevealFilterDisabled();
        ShowFilterLight();
        RETURN TRUE;
    ELSE
        Node^.Methods^.SetVisible (Node, TRUE);
        RETURN FALSE;
    END;

END ProceedWithSelection;


PROCEDURE TLDependBody();                                         (* 19-Jan-88 LAA *)
VAR
    Copyright                      : ARRAY[0..50] OF CHAR;
    LayoutInUse                    : AChartFormatPtr;

BEGIN                       (* TLDependBody *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    SetLengthOf (s, 0);
    Message (s);        (* Erase the "Now loading ..." message *)

    GetMessage (FontNumber, DependFont);        (* "PpSsBbL" *)

    Lrx := maxcol;
    Ulx := Lrx - 58;
    Lry := GanttWEnd;
    Uly := GanttWStart + DistanceFromGanttWStart;        (* 14-Sep-89 WKH *)

    AboveBox := DistanceFromGanttWStart - GanttWStart;   (* 14-Sep-89 WKH *)

    LayoutInUse := CurrentLayout();

    IF (LayoutInUse^.AVPShowing) THEN
        AboveBox := AboveBox DIV 2;
    END;

    Node := GanttChart^.Methods^.GetCursorNode (GanttChart);
    GanttChart^.Methods^.ForceToPosition (GanttChart, Node, AboveBox);       (* 3/27/89 EGK *)
    GanttChart^.Methods^.NoteSpecificChange (GanttChart, TaskChange);
    UnSetState (Showing);
    DisplayTheChart();

    IF (NOT InitBox (Node)) THEN
        RETURN;
    END;

    ShowPred := TRUE;
    ShowSucc := TRUE;

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
            SaveVisibility, NIL);

    FilterDependencies (Node);

    Selected := FALSE;
    Done := FALSE;

    LOOP

        Outline^.Methods^.Display (Outline);

        GetNextEvent (Event);

        WITH Event DO
            IF (EventCode < 256) THEN
                EventCode := ORD(CAP(CHR(EventCode)));
            END;
        END;

        CASE Event.EventCode OF
(*          Up, Down, HomeKey, EndKey, PgUpKey, PgDnKey, DoIt,   *)
            EditKey, DeleteKey :
                RecordThis := TRUE;
        ELSE
            RecordThis := FALSE;
        END;

        IF (RecordThis) THEN
            NotifyUndo (Edge, ChartActive, Outline);
            BeginTransactionSet();
        END;

        Outline^.Methods^.ActOnEvent (Outline, Event, Event);

        CASE Event.EventCode OF
            0 :;

        |   CancelKey :
                EXIT;

        |   DoIt, ExitKey :
                IF (Node = Outline^.Methods^.GetCursorNode (Outline)) THEN
                    Done := TRUE;
                ELSE
                    Node := Outline^.Methods^.GetCursorNode (Outline);
                    IF (ProceedWithSelection (Node)) THEN
                        IF (Event.EventCode = ExitKey) THEN
                            Selected := TRUE;
                            Done := TRUE;
                        ELSE
                            Outline^.Methods^.Discard (Outline);
                            TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild,
                                    9999, RestoreVisibility, NIL);
                            ShowNode (Node, TRUE);
                            GanttChart^.Methods^.SetCursorNode (GanttChart, Node);
                            GanttChart^.Methods^.ForceToPosition (GanttChart, Node, AboveBox);       (* 3/27/89 EGK *)
                            CursorTask := Node;
                            GanttChart^.Methods^.NoteSpecificChange (GanttChart, TaskChange);
                            UnSetState (Showing);
                            DisplayTheChart();
                            TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild,
                                    9999, SaveVisibility, NIL);
                            NeedToCreate := TRUE;
                            NeedUpdate := TRUE;
                        END;
                    END;
                END;

        |   EditKey :
                DependNode := Outline^.Methods^.GetCursorNode (Outline);
                OldBugTaskA := BugTaskA;
                OldBugTaskB := BugTaskB;
                Outline^.Methods^.SetCursorMode (Outline, videorestingcursor);
                Outline^.Methods^.Display (Outline);
                IF (Node = NIL) THEN
                    Burp();
                ELSIF (Node^.Methods^.TestAttributeBit (DependNode, Select2)) THEN
                    BugTaskA := DependNode;
                    BugTaskB := NIL;
                    ChangeEdge();
                ELSIF (Node^.Methods^.TestAttributeBit (DependNode, Select1)) THEN
                    BugTaskB := DependNode;
                    BugTaskA := NIL;
                    ChangeEdge();
                ELSE
                    Burp();
                END;
                Outline^.Methods^.SetCursorMode (Outline, videonormal);
                Outline^.Methods^.Display (Outline);
                BugTaskA := OldBugTaskA;
                BugTaskB := OldBugTaskB;

        |   DeleteKey :
                DependNode := Outline^.Methods^.GetCursorNode (Outline);
                IF (DependNode = NIL) THEN
                    Burp ();
                ELSIF (DependNode^.Methods^.TestAttributeBit (DependNode, Select1)) THEN
                    TryToUnjoin (DependNode, Node);
                ELSIF (DependNode^.Methods^.TestAttributeBit (DependNode, Select2)) THEN
                    TryToUnjoin (Node, DependNode);
                ELSE
                    Burp ();
                END;

        |   RedoKey :
                NotifyUndo (Edge, ChartActive, Outline);
                IF (NOT UndoLastChange(TRUE)) THEN
                    Burp();
                ELSE
                    NeedUpdate := TRUE;
                END;

        |   UndoKey :
                NotifyUndo (Edge, ChartActive, Outline);
                IF (NOT UndoLastChange(FALSE)) THEN
                    Burp();
                ELSE
                    NeedUpdate := TRUE;
                END;

        |  HelpKey :
                SetString(s,".DEPLIST");
                GiveHelp(s,0,GanttWEnd,RestoreTheScreen);
        ELSE
            IF (Event.EventCode = ORD(DependFont[1])) THEN       (* "P" *)
                ShowPred := TRUE;
                ShowSucc := FALSE;
                NeedUpdate := TRUE;
            ELSIF (Event.EventCode = ORD(DependFont[3])) THEN    (* "S" *)
                ShowPred := FALSE;
                ShowSucc := TRUE;
                NeedUpdate := TRUE;
            ELSIF (Event.EventCode = ORD(DependFont[5])) THEN    (* "B" *)
                ShowPred := TRUE;
                ShowSucc := TRUE;
                NeedUpdate := TRUE;
            ELSE
                Burp ();
            END;
        END;

        IF (RecordThis) THEN
            NotifyUndo (Edge, ChartActive, Outline);
            EndTransactionSet();
        END;

        IF (Done) THEN
            EXIT;
        END;

        IF (NeedToCreate) THEN
            IF (NOT InitBox (Node)) THEN
                EXIT;
            END;
        END;

        IF (NeedUpdate) THEN
            FilterDependencies (Node);
        END;

    END;

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
            RestoreVisibility, NIL);

    IF (Selected) AND (ProceedWithSelection (Node)) THEN
        ShowNode (Node, TRUE);
        CursorTask := Node;
        GanttChart^.Methods^.SetCursorNode (GanttChart, Node);
        GanttChart^.Methods^.NoteSpecificChange (GanttChart, TaskChange);
    END;

    IF (NOT NeedToCreate) THEN
        Outline^.Methods^.Discard (Outline);
    END;

END TLDependBody;

(*$S=*)

BEGIN                       (* TLDependBody *)

    OverlayID := ImAnInstallableOverlay(TLDependBody, AnOverlayProc(NIL));       (* 19-Jan-88 *)
    TLDependBody();

END TLDepend.

