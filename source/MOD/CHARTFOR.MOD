(*V9=DEBUGGING Version*)

IMPLEMENTATION MODULE ChartForms;

(*  =========================================================================
    Last Edit : October 29, 1990 1:06PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        (* Comments prior to 1-Jan-88 removed by RSC 1/10/89. *)

        14-Jan-88 LAA   Turned off the "standard" bit of the temporary layout
                        created at the top of the list.
        02-Mar-88 LAA   TLFBASE is not allowed in the reserve layer.
        05-Mar-88 LAA   Use ModuleNumber as the help number.
        20-Sep-88 WKH   Removed SelectLayout and placed it in LayoutKludges as
                        SelectLayoutAt.  Now ChartForms IMPORTs SelectLayoutAt
                        and SelectLayout is just a call to SelectLayoutAt with
                        the old coordinates.  Also, LayoutKludges references
                        the ChartForms ModuleNumber as KludgeNumber.
        07-Nov-88 EGK   Set notes text to NIL in CreateLayout.  We don't want
                        to copy pointers.
          1/10/89 RSC   Moved "SelectLayoutAt" here from "LayoutKluges".
        23-Jan-89 RSC   Changed Storage to Space.
         7-Mar-89 RSC   Ajusted for new columns (removed Blanks2-9) and import
                        magic numbers from MagicNum.Mod, don't hard code them
                        here.
        22-Mar-89 EGK   Changed DefaultLayout to set up the new percent-
                        complete fields.
        01-May-89 LAA   Removed the warning message about the layout being too
                        wide, since we now have a Scrolling Gantt and we can
                        bring columns onto the screen from the right.  Also
                        cleaned up the import list a bit.
        27-Jul-89 EGK   Changed SelectLayoutAt to conform to the new
                        ALayoutContext format.
        12-Sep-89 WKH   Make Layout list bigger for compressed video mode.
        18-Sep-89 RSC   Removed AdjustScale.  Put it in TLLayout.
        14-Dec-89 LAA   Added CheckSumLayout, GetLayoutMetrics, and 
                        FindCurrentColumn.
        21-Feb-90 KKC   Remove all unreferenced id from Timeu.
        30-Mar-90 RSC   Removed Timeu, replaced with Timei
        01-Jun-90 AJL   Removed import of Planner.
        29-Oct-90 RSC   Handle the CheckSumm in a cleaner fasion: don't do
                        it.  Instead, send out a notice when the Gantt
                        Chart Layout changes.  Signal this change in the
                        CheckSummLayout procedure via a unique number.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
    =========================================================================
*)


FROM Boxes                  IMPORT 
                                ABoxType, ABoxAttribute;

FROM Codes                  IMPORT 
                                ACode;

FROM Dialog                 IMPORT 
                                Burp, Message, Error, FatalError, 
                                ADialogOption, WarningBox;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  GetNextEvent;

FROM Gantt                  IMPORT 
                                ASlackStyle, AGanttLineType;

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineViewType;

FROM Kbio                   IMPORT 
                                maxrow, maxcol, ascreenx, ascreeny, avidmode;

FROM Keys                   IMPORT 
                                ExitKey, DoIt, InsertKey, DeleteKey, CancelKey,
                                EditKey, MoveUpKey, MoveDownKey;

FROM MsgFile                IMPORT 
                                GetMessage;

FROM LStrings               IMPORT 
                                SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                Insert, Procustes, TrimFront, TrimRear, Fill, 
                                LengthOf, Copy, Compare, LJust, SetLengthOf,
                                Upshift;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM Schedule               IMPORT 
                                ScheduleSaved, ConfigSaved;

FROM Space                  IMPORT 
                                ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT 
                                ADR, TSIZE;

FROM TaskColNumbers         IMPORT
    (* CONST *)                 TaskNameColumn, ResourceColumn,
                                StatusColumn, PercentAchieved;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  DiscardText;

FROM Timei                  IMPORT
    (* TYPE *)                  ADurationUnit;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  CreateTree, CreateTreeNode, ValidateTreeNode;




CONST
    ModuleNumber = 2600;    (* For GetMessage. *)




VAR
    CurrentLayoutSequenceNumber : CARDINAL; (* 29-Oct-90 RSC *)




PROCEDURE LayoutChanged();
BEGIN

(*$R-*)
    INC(CurrentLayoutSequenceNumber);
(*$R=*)

    SendNotices( GanttLayoutChange, AfterActing, NIL );

END LayoutChanged;










PROCEDURE DetermineFirstGantt(    ChartFormat : AChartFormatPtr);

VAR
    i                       : CARDINAL;

BEGIN                       (* DetermineFirstGantt *)

    WITH ChartFormat^ DO
        GanttPosition := 1;

            (* Calculate starting positions of columns, and start of Gantt *)

        FOR i := 1 TO ColumnCount DO
            ColumnSpec[i].Position := GanttPosition;
            INC(GanttPosition, ColumnSpec[i].Width);
        END;

        IF (GanttPosition < maxcol - 3) THEN
            GanttWidth := maxcol + 1 - GanttPosition;
        ELSE
            GanttWidth := 0;
        END;
    END;

END DetermineFirstGantt;







PROCEDURE DefaultLayout(    ChartFormat : AChartFormatPtr);

BEGIN                       (* DefaultLayout *)

    WITH ChartFormat^ DO                                          (* 20-May-87 LAA *)
        scale := 8;                                               (* 22-Jun-87 LAA *)
        scaleunit := Hours;
        slackstyle := FreeSlack;
        Fill(Name, " ", 0);
        Notes := AText(NIL);
        AVPShowing := FALSE;
        GanttShowing := TRUE;
        TaskNameOnScreen := TRUE;
        LayoutFlags := {1};
        ProgressColumnID := PercentAchieved;        (* 3/22/89 EGK *)
        ProgressLineType := Plan;

        ColumnSpec[1].ColumnID := TaskNameColumn;
        ColumnSpec[1].Width    := 26;
        ColumnSpec[2].ColumnID := ResourceColumn;
        ColumnSpec[2].Width    := 11;
        ColumnSpec[3].ColumnID := StatusColumn;
        ColumnSpec[3].Width    := 8;
        ColumnCount := 3;

        DetermineFirstGantt(ChartFormat);
    END;

END DefaultLayout;





(*----------------------------------------------------------------------------
    InitializeChartForms --

    Initialize this module.  This procedure is defined because it's not
    possible to do the required initialization in the initialization section,
    due to module dependencies.  This procedure should be called by TLINIT.

    Preconditions:
        None.

    Postconditions:
        The module will be initialized, as required.
----------------------------------------------------------------------------*)

PROCEDURE InitializeChartForms();

VAR
    ChartFormat             : AChartFormatPtr;

BEGIN                       (* InitializeChartForms *)

    IF (NOT CreateTreeNode(DefaultChartFormat)) THEN
        FatalError();
    END;

    IF (NOT CreateTree(LayoutTree)) THEN
        FatalError();
    END;

    NEW(ChartFormat);
    IF (ChartFormat = NIL) THEN
        FatalError();
    END;

    DefaultChartFormat^.Methods^.SetDataObject(DefaultChartFormat, ChartFormat);

    DefaultLayout(ChartFormat);

END InitializeChartForms;





(*----------------------------------------------------------------------------
    DoLayoutForm --

    Bring up the layout form to allow editing of a layout record.

    Preconditions:
        The layout parameter must be a valid layout node.

    Postconditions:
        The layout record will be changed as directed by the user, unless the
        form is left with ESC.  The code will be returned.
----------------------------------------------------------------------------*)

PROCEDURE DoLayoutForm(    Layout           : ATreeNode)
                                                        : ACode;

VAR
    PrivateOverlayContext       : AnOverlayContext;
    OverlayName                 : ARRAY [0..21] OF CHAR;
    Result                      : ACode;

BEGIN                       (* DoLayoutForm *)

    (*<DEBUGGING
    ValidateTreeNode(Layout);
      DEBUGGING*)

    PrivateOverlayContext.LayoutNode := Layout;
    PrivateOverlayContext.ReturnCode := CancelKey;
    SetString (OverlayName, "\TLFBASE(TLLAYOUT)");                (* 02-Mar-88 LAA *)

    IF (CallOverlayWithContext (OverlayName, ADR(PrivateOverlayContext))) THEN
    END;

    IF (PrivateOverlayContext.ReturnCode <> CancelKey) THEN
        LayoutChanged();
    END;

    RETURN PrivateOverlayContext.ReturnCode;

END DoLayoutForm;







(*----------------------------------------------------------------------------
    SelectLayout --

    Display a list of the named layouts, defaulting the cursor position to
    the layout passed as parameter, and allow the user to select one.
    The ULX, ULY, LRX, & LRY paramaters specify the screen location of the
    selection box.  The Warning parm indicates whether a warning should be
    issued when the selected layout is longer than the screen width,
    longer than 255 characters, or if the task name isn't on screen.

    Preconditions:
        The layout passed in must be a valid layout, or it may be NIL.

    Postconditions:
        The layout parameter will be changed to reflect the user's choice,
        if a selection is made.  If the user exits with ESC, the initial
        value of the layout parameter will be preserved.  Within this call,
        it is possible to add, delete, copy and edit named layouts.
----------------------------------------------------------------------------*)

(* RSC 16-Jun-89  Made the code be in an overlay. *)

PROCEDURE SelectLayoutAt(VAR TheLayout          : ATreeNode;
                             TheULX,
                             TheULY,
                             TheLRX,
                             TheLRY             : CARDINAL;
                             TheWarning         : BOOLEAN) : ACode;

VAR
    LayoutContext   : ALayoutContext;
    OverlayName     : ARRAY [0..39] OF CHAR;
    ok              : BOOLEAN;
BEGIN

    WITH LayoutContext DO
        LayoutPtr   := ADR(TheLayout);      (* 7/27/89 EGK *)
        ULX         := TheULX;
        ULY         := TheULY;
        LRX         := TheLRX;
        LRY         := TheLRY;
        Warning     := TheWarning;
        ReturnCode  := CancelKey;
    END;

    SetString( OverlayName, "TLLAYLIS" );
    ok := CallOverlayWithContext( OverlayName, ADR(LayoutContext) );

    IF (LayoutContext.ReturnCode <> CancelKey) THEN
        LayoutChanged();
    END;

    RETURN LayoutContext.ReturnCode;

END SelectLayoutAt;







(*----------------------------------------------------------------------------
    SelectLayout --

    Display a list of the named layouts, defaulting the cursor position to
    the layout passed as parameter, and allow the user to select one.

    Preconditions:
        The layout passed in must be a valid layout, or it may be NIL.

    Postconditions:
        The layout parameter will be changed to reflect the user's choice,
        if a selection is made.  If the user exits with ESC, the initial
        value of the layout parameter will be preserved.  Within this call,
        it is possible to add, delete, copy and edit named layouts.
----------------------------------------------------------------------------*)

PROCEDURE SelectLayout(VAR Layout           : ATreeNode)
                                                        : ACode;
CONST
    ULX                     = 29;
    ULY                     = 5;
    LRX                     = 54;

VAR
    LRY                     : CARDINAL;  (* 12-Sep-89 WKH *)

BEGIN
    LRY := maxrow - 4;

    RETURN(SelectLayoutAt(Layout, ULX, ULY, LRX, LRY, TRUE));  (* 9/20/88 WKH *)
END SelectLayout;







(*----------------------------------------------------------------------------
    CurrentLayout --

    Return a pointer to the currently valid layout.

    Preconditions:
        InitializeChartForms must have been called.

    Postconditions:
        A pointer to the current layout will be returned.  Always!
----------------------------------------------------------------------------*)

PROCEDURE CurrentLayout(): AChartFormatPtr;

VAR
    ChartFormat             : ATreeNode;

BEGIN                       (* CurrentLayout *)

    IF (CurrentChartFormat <> NIL) THEN
        ChartFormat := CurrentChartFormat;
    ELSE
        IF (DefaultChartFormat = NIL) THEN
            FatalError();
        END;
        ChartFormat := DefaultChartFormat;
    END;

    (*<DEBUGGING*)
    ValidateTreeNode(ChartFormat);
    (*DEBUGGING>*)

    RETURN ChartFormat^.Methods^.GetDataObject(ChartFormat);

END CurrentLayout;



PROCEDURE CompareLayouts (Node1, Node2: ATreeNode): INTEGER;

VAR
    Layout1, Layout2            : AChartFormatPtr;

BEGIN
    Layout1 := Node1^.Methods^.GetDataObject (Node1);
    Layout2 := Node2^.Methods^.GetDataObject (Node2);
    RETURN Compare (Layout1^.Name, Layout2^.Name);
END CompareLayouts;





(*----------------------------------------------------------------------------
    SortLayouts --

    Sort the layouts in the tree into alpha order.

    Preconditions:
        InitializeChartForms must have been called.

    Postconditions:
        The LayoutTree will be sorted into alphabetical order.
----------------------------------------------------------------------------*)

PROCEDURE SortLayouts();

VAR
    Node, NextNode, TempNode    : ATreeNode;

BEGIN                       (* SortLayouts *)

    (*  Use an insertion sort on the layouts, because it's easy to swap
        items on a linked list.  Also, since only one item is added at a
        time to the end of the (already sorted) list, this will place the 
        new layout into the correct order with only one swap.
    *)

    Node := LayoutTree^.Methods^.GetFirst (LayoutTree);
    IF (Node <> NIL) THEN
        NextNode := Node^.Methods^.GetNext (Node);
        WHILE (NextNode <> NIL) DO
            IF (CompareLayouts (NextNode, Node) < 0) THEN
                TempNode := Node^.Methods^.GetPrev (Node);
                WHILE ((TempNode <> NIL) AND
                        (CompareLayouts (NextNode, TempNode) < 0)) DO
                    TempNode := TempNode^.Methods^.GetPrev (TempNode);
                END;
                NextNode^.Methods^.DeList (NextNode);
                IF (TempNode = NIL) THEN
                    LayoutTree^.Methods^.AddFirst (LayoutTree, NextNode);
                ELSE
                    TempNode^.Methods^.AddAfter (TempNode, NextNode);
                END;
            ELSE
                Node := NextNode;
            END;
            NextNode := Node^.Methods^.GetNext (Node);
        END;
    END;

END SortLayouts;




(*----------------------------------------------------------------------------
    CreateLayout --

    Create a new layout, setting all fields of the layout to their default 
    values.

    Preconditions:
        None.

    Postconditions:
        The layout will be created if possible, and its fields defaulted.
        TRUE will be returned iff the layout was created.
----------------------------------------------------------------------------*)

PROCEDURE CreateLayout(VAR Layout           : ATreeNode)
                                                        : BOOLEAN;

VAR
    ChartRecord         : AChartFormatPtr;
    OldRecord           : AChartFormatPtr;

BEGIN                       (* CreateLayout *)

    IF (NOT HeapAvailable()) OR (NOT CreateTreeNode(Layout)) THEN
        RETURN FALSE;
    END;

    NEW(ChartRecord);
    ChartRecord^.Tag := ModuleNumber;
    Layout^.Methods^.SetDataObject(Layout, ChartRecord);
    IF (CurrentChartFormat = NIL) THEN
        DefaultLayout(ChartRecord);
    ELSE
        OldRecord := 
               CurrentChartFormat^.Methods^.GetDataObject(CurrentChartFormat);
        ChartRecord^ := OldRecord^;
        ChartRecord^.Notes := AText(NIL);           (* 11/7/88 EGK *)
        SetLengthOf(ChartRecord^.Name, 0);
    END;

    RETURN TRUE;

END CreateLayout;




(*----------------------------------------------------------------------------
    DiscardLayout --

    Get rid of the given layout tree node.

    Preconditions:
        The layout must be a valid layout node.

    Postconditions:
        The node and all its associated storage will be discarded.
----------------------------------------------------------------------------*)

PROCEDURE DiscardLayout(VAR Layout          : ATreeNode);

VAR
    ChartRecord             : AChartFormatPtr;

BEGIN                       (* DiscardLayout *)

    (*<DEBUGGING
    ValidateTreeNode(Layout);
      DEBUGGING>*)

    ChartRecord := Layout^.Methods^.GetDataObject(Layout);
    DiscardText (ChartRecord^.Notes);
    ChartRecord^.Tag := 0;
    DISPOSE(ChartRecord);

    IF (Layout = CurrentChartFormat) THEN
        CurrentChartFormat := NIL;
        LayoutChanged();
    END;
    Layout^.Methods^.DeList(Layout);
    Layout^.Methods^.Discard(Layout);

END DiscardLayout;




PROCEDURE CheckSumLayout(    ChartRecord    : AChartFormatPtr): CARDINAL;  (* 25-Sep-89 LAA *)
BEGIN                       (* CheckSumLayout *)

    RETURN CurrentLayoutSequenceNumber;

END CheckSumLayout;




        (*  These procedure belong in ChartForms *)

(*  GetLayoutMetrics --
        Determine if the Gantt bars region and/or the Spreadsheet area is
        on-screen, and return the first position of the Gantt region.
    Preconditions:
        The layout must be valid.
    Postconditions:
        The indicated parameters are returned.
*)

PROCEDURE GetLayoutMetrics( VAR Layout         : AChartFormat;
                                ViewWidth      : CARDINAL;
                            VAR GanttOnScreen  : BOOLEAN;
                            VAR FirstGantt     : CARDINAL;
                            VAR SpreadOnScreen : BOOLEAN       );

VAR
    i                       : CARDINAL;

BEGIN                       (* GetLayoutMetrics *)

    WITH Layout DO
        IF ((GanttWidth > 0) AND (GanttShowing) 
            AND (GanttPosition < ViewWidth)) THEN
            FirstGantt := GanttPosition;
            GanttOnScreen := TRUE;
        ELSE
            FirstGantt := ViewWidth;
            GanttOnScreen := FALSE;
        END;
        SpreadOnScreen := FALSE;
        FOR i := 1 TO ColumnCount DO
            IF (ColumnSpec[i].Width > 1) THEN
                SpreadOnScreen := TRUE;
                RETURN;
            END;
        END;
    END;

END GetLayoutMetrics;



(*  FindCurrentColumn --
        Determine which spreadsheet column corrosponds to the given XOffset.
    Preconditions:
        The layout must be valid.
    Postconditions:
        Current spreadsheet column will be returned, or if the XOffset does
        not corrospond to the spreadsheet area, 1 will be returned.
*)

PROCEDURE FindCurrentColumn( VAR ChartRecord  : AChartFormat;
                                 XOffset      : CARDINAL     ): CARDINAL;

VAR
    i                       : CARDINAL;

BEGIN                       (* FindCurrentColumn *)

    WITH ChartRecord DO
        FOR i := ColumnCount TO 1 BY -1 DO
            IF ( XOffset >= ColumnSpec[i].Position) THEN
                RETURN i;
            END;
        END;
    END;

    RETURN 1;

END FindCurrentColumn;




BEGIN
    CurrentChartFormat := NIL;
    DefaultChartFormat := NIL;
    CurrentLayoutSequenceNumber := 10000;  (* Start here *)
END ChartForms.

