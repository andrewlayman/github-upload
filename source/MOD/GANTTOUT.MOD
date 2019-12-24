(*V9=DEBUGGING Version*)
(*V1=ANDREW    Special commands added for Andrew's convenience. *)

IMPLEMENTATION MODULE GanttOutlines;        (*  a subclass of OutlineViews  *)

(*  =========================================================================
    Last Edit : June 21, 1991 5:20PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

         5-Jan-90 LAA   Moved the location of MouseDownRegion, because this
                        instance variable is now defined in ListViews instead
                        of OutlineViews.
                        Also removed the initialization of TypeThroughEnabled,
                        as this is now set to FALSE in InitAsOutlineView.
         6-Jan-90 LAA   Turned optimization off for all procedure which
                        indexed into and the dereferenced SubView.  It's hard
                        for me to believe that this hasn't been done before,
                        sinced that's exactly the construct that we KNOW the
                        optimizer has trouble with!!!!!  This should be done
                        in ListViews and all it's subclasses.
         6-Jan-90 RSC   Removed GoTo references.  This lets GoTo leave
                        the root.
         9-Jan-90 LAA   The horizontal scroll regions were not being correctly
                        sized when there was no bars region specified in the
                        layout record.
        13-Jan-90 LAA   Scrolling with the mouse was not behaving correctly
                        if the layout had defined columns at the end with a
                        width of zero.  Bug # 2054.
                        Scrolling columns with the mouse, positioning to 
                        column 1 with the mouse, the using the right arrow
                        key, was resulting in the 2nd column being displayed
                        with a width of the remainder of the screen.  This
                        prevented the Gantt bars from being seen.  Bug #2055.
        17-Jan-90 LAA   When expanding columns of the spreadsheet area from 
                        the left, if more than one column drops off the right
                        side of the view, the cursor column will not be 
                        on-screen.  By itself this is not good, but if you
                        then double-click a spreadsheet column you'll end
                        up editing THE WRONG COLUMN!  This could only happen
                        when scrolling with the mouse.
        18-Jan-90 LAA   In InitAsGanttOutline, I set the LayoutChecksum to be
                        zero when we're creating the GanttChart.  This will
                        force the layout to be copied into the GanttOutline
                        from the current layout when we first display or
                        call ActOnEvent.  I've left the LayoutRecord set up
                        to default, just in case some part of the code 
                        depends on it being reasonable, if not right.  The
                        reason for this change is as follows:  When 
                        InitAsGanttOutline is called, TLMouse has not yet
                        run, so we don't detect that the user has a mouse.
                        This causes the Gantt bar region width to be 1 too
                        big, overwriting the vertical scroll bars.  It can
                        only happen when the current layout stored in the
                        config file is the blank default layout, because only
                        then does the checksum computed at InitAsGanttOutline
                        time match the current layout checksum when Display
                        or ActOnEvent is called.  For any other current layout,
                        a difference is detected and the LayoutRecord is
                        re-initialized correctly.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        05-May-90 LAA   Changed DoTaskInsert to use spreadsheet editing of a
                        new task, if the CursorColumn is on the task name.
                        This should allow easier creation of simple schedules
                        from the Gantt chart.
        30-May-90 LAA   Fixed bug #2132.  Without a mouse, layouts with
                        more columns than will fix on the screen cause the
                        cursor to vanish when you scroll off the right edge
                        of the screen.  Fixed by having AdjustLayout fix
                        Layout.GanttPosition to be view width + 1.
        19-Jun-90 AJL  -Double-click on the recalc light forces a recalc.
                       -Mouse-up (not MouseDown) does a recalc, if needed.
                       -Replaced the numbers defining the various mouse regions
                        with constants.
        17-Jul-90 LAA   Changed the way spreadsheet insert is done.  Instead
                        of embedding it all in InsertTask, the main decision
                        is made in GanttDispatch, and InsertTask now takes a
                        parameter telling it what editing procedure to use.
                        This "should" ensure that, when the user explicitly
                        asks for a task form (ctrl-F2, alt-F2), he gets it.
         6-Oct-90 AJL  -F10 (ExitKey) will bring up the menu, same as /.
        13-Nov-90 TGS   Merge changes made to 4.03.
        16-Dec-90 AJL  -Added Zoom and UnZoom keys, Alt-Plus and Alt-Minus.
                       -Moved old change history to the end of the file.
                       -Changed use of MAXCARDINAL to MaxDate;
         9-Jan-91 AJL  -Added the toggle ANDREW which switches on the special
                        features:
                        1.  Double-Click on the recalc light forces a recalc.
                        2.  Zoom and Unzoom keys Alt+ and Alt-.
        16-Jan-91 TGS   Send SoundOn/SoundOff codes to Dispatch.
        24-Jan-91 AJL   Added support for dispatching the HistSynchKey.
         5-Apr-91 TGS   Move Task Column numbers to TaskColN from MagicNum.
                        There were too many identifiers in there.
        21-Jun-91 PFG   Turned off the ANDREW toggle on request from QA.
        24-Jun-91 LAA   Rearranged a calculation which was causing a CARDINAL
                        overflow in some circumstances.  Bug #4592.  
                        The old calculation was:
                        IF (CursorDay >= ChartStartDay + GanttWidth * scale)
                        which caused the overflow for large values of scale.
        01-Aug-91 LAA   When Histograms are up, the Gantt chart may be only
                        two lines high.  In this case, the down arrow on the
                        vertical scroll bar was not available (or displayed).
                        Changed the calculation of the correlation regions
                        to correct this, and changed GanttHelper PutVScrollBar
                        also.  Bug # 4819.
         9-Sep-91 TGS   Import new HistStat variable, HistogramsAreUp. This
                        allows us to properly handle HistKey/HistSynchKey
                        when histograms are up (we just want to pass it back
                        down to TLRHist rather than dispatching it).
        11-Feb-92 AJL   Allow the NewProjectKey (Ctrl-F9).
    =========================================================================
*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, AFixType, ATaskName, AStartStatus,
                                ATaskFlag,
    (* VAR *)                   FixationName, StartStatusName;

FROM AVPViews               IMPORT
    (* TYPE *)                  AnAVPView,
    (* PROC *)                  CreateAVPView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* VAR *)                   GetColumnInfo;

FROM Changer                IMPORT
    (* VAR *)                   AdvancedTaskForm,
    (* PROC *)                  AddNewTask, ChangeTask, DeleteTask,
                                AddTaskCopy;

FROM Chart                  IMPORT
    (* VAR *)                   ChartStartDay, CursorDay, BugTaskA, BugTaskB,
                                CursorTask,
    (* PROC *)                  ChartNotifyDeleted, DisplayTaskStats;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* VAR *)                   RecomputeLight,
    (* PROC *)                  UnSetState;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr, AChartFormat,
    (* PROC *)                  CurrentLayout, DetermineFirstGantt,
    (* PROC *)                  CheckSumLayout, GetLayoutMetrics;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode, ASetOfCodes;

FROM Correl                 IMPORT
    (* TYPE *)                  ACorrelationList, ARegionSet,
    (* PROC *)                  CreateCorrelationList, DisposeCorrelationList,
                                SetRegion, CorrelatePoint,QueryRegion;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  FatalError, Error, Burp, Message,
                                MultipleChoiceBox;
                                
FROM Dispatcher             IMPORT
    (* PROC *)                  Dispatch;

FROM Edits                  IMPORT
    (* PROC *)                  EditText;

FROM Edges                  IMPORT
    (* PROC *)                  ItDepends;

FROM ErrorCategories        IMPORT
    (* CONST *)                 NotPossibleInContextError, UnknownEventError,
                                AllocationError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  GetErrorDetails, NewMarker, ErrorPosted,
                                PopToMarker, PostError, UnPostError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent, AnEventType,
    (* PROC *)                  PushEvent;

FROM Gantt                  IMPORT
    (* TYPE *)                  ADStyle, 
    (* VAR *)                   ChartFont,
    (* PROC *)                  CheckScale, DateLines;

FROM GanttHelper            IMPORT
    (* PROC *)                  DoGanttGotoKey, WantToQuit, PutVScrollBar,
                                PutHScrollBar;

FROM GanttViews             IMPORT
    (* TYPE *)                  AGanttView, AGanttViewSpecificChange,
    (* PROC *)                  CreateGanttView;

FROM HistStat               IMPORT
    (* VAR *)                   HistogramsAreUp; (* 9-Sep-91 TGS *)

FROM Helper                 IMPORT 
    (* TYPE *)                  AScreenAction,
    (* PROC *)                  GiveHelp;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode, 
    (* CONST *)                 AbsoluteMaxRow, maxcol,
    (* PROC *)                  PutString, EraseLn;

FROM Keys                   IMPORT
    (* CONST *)                 Tab, Reverse, InsertKey, DeleteKey, EditKey,
                                CancelKey, ExitKey,
                                JoinKey, UnJoinKey, GotoKey, 
                                ReInsertKey, RollLeft, RTab,
                                UndoKey, JoinPartialKey, 
                                EditBigTaskKey, DsplyKey, ComputeKey, 
                                OptionsFormKey, Fwrd, NewProjectKey,
                                ResourceFormKey, DaysKey, 
                                RedoKey, ReportsKey, PromoteKey, RollRight,
                                FileFormKey, AnteKey, DemoteKey, MoveUpKey,
                                MoveDownKey, OpenKey, CloseKey, 
                                SelectKey, CopyKey, GotoWBSKey, NetworkKey, 
                                TaskNotesKey, HelpKey, HistKey, SelListKey, 
                                HighListKey, HighList2Key, HighList3Key, 
                                DependViewKey, AltUndoKey, HelpIndexKey,
                                FileErase, FiltersClear, MouseStillDown,
                                FileRetrieve, RepeatKey, MouseDown,
                                QuitProgram, OnMenu, MouseUp, MouseDouble,
                                HistSynchKey,
                                SoundOn, SoundOff; (* 16-Jan-91 TGS *)

FROM Layout                 IMPORT
    (* CONST *)                 GanttWStart, GanttWEnd, MenuStart, MenuEnd;

FROM Lights                 IMPORT
    (* PROC *)                  QueryLightXY;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Overlay, ConcatLS, 
                                SetString, 
                                SetLengthOf, LengthOf;

FROM Mouse                  IMPORT
    (* PROC *)                  MousePresent, CancelDoubleClick;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices, Permission;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineView,
    (* PROC *)                  InitAsOutlineView, UnInitAsOutlineView,
                                ValidateOutlineView, CloneOutlineViewMethods;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM RunMenu                IMPORT
    (* PROC *)                     SelectAndRunMenu;

FROM Schedule               IMPORT
    (* VAR *)                   ScheduleSaved, 
                                WarnBeforeManualChange,
                                SortOrderManuallyAltered;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TaskColNumbers         IMPORT
    (* CONST *)                 TaskNameColumn, WBSColumn;

FROM Text                   IMPORT
    (* TYPE *)                  AText;

FROM TimeJump               IMPORT
    (* PROC *)                  FindStartDateOf, FindNextKeyDate, 
                                FindPriorKeyDate;

FROM Timei                  IMPORT
    (* CONST *)                 MaxDate,
    (* TYPE *)                  ADate, ADuration, ADurationCounter,
                                ADurationUnit,
    (* CONST *)                 NoDuration;

FROM Timeu                  IMPORT
    (* PROC *)                  UpScale, DownScale;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode;

FROM Undo                   IMPORT
    (* TYPE *)                  AnUndoStatus,
    (* VAR  *)                  UndoStatus,
    (* PROC *)                  BeginTransactionSet, EndTransactionSet,
                                DebugUndo,
                                AbortTransactionSet, UndoLastChange,
                                NotifyUndo, AnUndoableObject, AnUndoAction;


CONST
    ModuleNumber            = 17500;
        (* Mouse correlation region numbers. *)
    InteriorRegion          = 1;
    MenuRegion              = 2;
    ScrollDownRegion        = 3;
    ScrollUpRegion          = 4;
    ScrollSpreadRightRegion = 5;
    ScrollSpreadLeftRegion  = 6;
    ScrollGanttRightRegion  = 7;
    ScrollGanttLeftRegion   = 8;
    RecalcLightRegion       = 9;

    (*<ANDREW
CONST
    ZoomKey       =  334;     (* Alt-Plus*)
    UnZoomKey     =  330;     (* Alt-Minus *)
    SearchUpKey   =  397;     (* Ctrl-Up *)
    SearchDownKey =  401;     (* Ctrl-Down *)
    ANDREW>*)


TYPE
    (* 6-Jan-90 RSC Copied here from GoTo *)
    AGoToNameProc           = PROCEDURE (ATreeNode, VAR ARRAY OF CHAR);

    XGanttOutline           = POINTER TO XGanttOutlineRecord;

    XGanttOutlineRecord     = RECORD
                                Methods        : AGanttOutlineMethods;
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
                                Status         : AGanttOutlineStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF
                                                                   AGanttView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                                  (* New fields for outline views *)
                                MatchCount          : CARDINAL;
                                MatchString         : ARRAY [0..80] OF CHAR;
                                TypeThroughEnabled  : BOOLEAN;
                                MatchCodeSet        : ASetOfCodes;
                                NameProc            : AGoToNameProc;
                                  (* These are for GanttOutlines *)
                                AVPView             : BOOLEAN; 
                                PreviousChartStartDay : ADate;
                                WhatShows           : AGanttOutlineShowing;
                                CursorColumn        : CARDINAL;
                                LayoutChecksum      : CARDINAL;
                                LayoutRecord        : AChartFormat;
                                ScrollingEnabled    : BOOLEAN;
                                ScreenCorrelList    : ACorrelationList;
                              END;


    AGanttOutlineShowingProc  = PROCEDURE(    AGanttOutline,
                                              AGanttOutlineShowing);

    AGanttOutlineResizeProc   = PROCEDURE(    AGanttOutline,
                                              ascreeny,
                                              ascreeny  );   (* RSC 12/16/88 *)

    AGanttOutlineLayoutProc   = PROCEDURE(    AGanttOutline): AChartFormatPtr;  (* 29-Dec-88 LAA *)

    AGanttOutlineSetCursProc  = PROCEDURE(    AGanttOutline,
                                              CARDINAL     );

VAR
    GanttOutlineMethodsRecord : AGanttOutlineMethodsRecord;


        (*  WARNING -- This global is for use only as communication
                       between DoGoTo and its NameProc, and is only
                       valid when GoTo is active.
        *)

    GoToColumnID                : CARDINAL;


PROCEDURE DebugMsg(     Msg                 : ARRAY OF CHAR);

VAR
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* DebugMsg *)

    SetString( s, Msg );
    Error( s );

END DebugMsg;



PROCEDURE SubviewForNode(    GanttOutline   : XGanttOutline;
                             TaskNode       : ATreeNode    )
                                                            : CARDINAL;

VAR
    i                   : CARDINAL;
    Node                : ATreeNode;

BEGIN                   (* SubviewForNode *)

    WITH GanttOutline^ DO
        FOR i := 1 TO Last DO
            Node := SubView[i]^.Methods^.GetObject(SubView[i]);
            IF (Node = TaskNode) THEN
                RETURN i;
            END;
        END;
    END;

    RETURN 0;

END SubviewForNode;






PROCEDURE DiscardSubViews(    GanttOutline  : XGanttOutline);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateGanttOutline(AGanttOutline(GanttOutline));
    END;
    DEBUGGING>*)

    WITH GanttOutline^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;
        Cursor := 0;
    END;

END DiscardSubViews;






PROCEDURE InitGanttView(    GanttOutline    : XGanttOutline);

VAR
    y                       : ascreeny;
    i                       : CARDINAL;
BEGIN                       (* InitGanttView *)

    DiscardSubViews(GanttOutline);
    WITH GanttOutline^ DO
        AVPView := FALSE;
        IF (MousePresent()) THEN                               (* 13-Dec-89 *)
            i := 1;
        ELSE
            i := 0;
        END;
        Last := 0;
        FOR y := Uly TO Lry DO
            IF (NOT CreateGanttView(SubView[Last + 1], 
                                    AnActiveView(GanttOutline), NIL,
                                    Ulx, y, Lrx-i, y, ABoxType{NoBox}, 
                                    VideoMode, HelpNumber)) THEN

                (* NOTE AN ERROR HERE *)
                FatalError();

                RETURN;
            END;
            INC(Last);
        END;
        BuildCorrelationList( GanttOutline );
    END;

END InitGanttView;




PROCEDURE InitAVPView(    GanttOutline      : XGanttOutline);

VAR
    y                       : ascreeny;
    TempView                : AnAVPView;
    i                       : CARDINAL;

BEGIN                       (* InitAVPView *)

    DiscardSubViews(GanttOutline);
    WITH GanttOutline^ DO
        AVPView := TRUE;
        IF (MousePresent()) THEN                               (* 13-Dec-89 *)
            i := 1;
        ELSE
            i := 0;
        END;
        Last := 0;
        FOR y := Uly + 1 TO Lry BY 2 DO
            IF (NOT CreateAVPView(TempView, 
                                  AnActiveView(GanttOutline), NIL,
                                  Ulx, y - 1, Lrx-i, y, ABoxType{NoBox},
                                  VideoMode, HelpNumber)) THEN

                (* NOTE AN ERROR HERE *)
                FatalError();

                RETURN;
            END;
            SubView[Last + 1] := AGanttView(TempView);
            INC(Last);
        END;
        BuildCorrelationList( GanttOutline );
    END;

END InitAVPView;


(*  AdjustLayout --
        Adjust the layout fields GanttWidth and GanttPosition for existance
        of scroll bar areas when there's a mouse.
*)

PROCEDURE AdjustLayout(     GanttOutline    : XGanttOutline );

VAR
    ViewWidth           : CARDINAL;

BEGIN                   (* AdjustLayout *)

    WITH GanttOutline^ DO
        DetermineFirstGantt( ADR(LayoutRecord) );
        IF (MousePresent()) THEN
            ViewWidth := Lrx-Ulx;
        ELSE                                                   (* 30-May-90 *)
            ViewWidth := Lrx - Ulx + 1;
        END;
        WITH LayoutRecord DO
            IF (ColumnCount > 0) THEN
                GanttPosition := ColumnSpec[ColumnCount].Position
                                 + ColumnSpec[ColumnCount].Width;
                IF (GanttPosition > ViewWidth - 3) THEN
                    GanttPosition := ViewWidth;
                END;
            ELSE
                GanttPosition := 1;
            END;
            IF (GanttShowing) THEN
                GanttWidth := ViewWidth - GanttPosition;
            ELSE
                GanttWidth := 0;
            END;
        END;
    END;

END AdjustLayout;




PROCEDURE CheckForChangeOnLayout(    GanttOutline : XGanttOutline;
                                     ChartRecord  : AChartFormatPtr);

VAR
    C   : CARDINAL;

BEGIN

    C := CheckSumLayout(ChartRecord);                             (* 25-Sep-89 LAA *)

    WITH GanttOutline^ DO
        IF (LayoutChecksum <> C) THEN                             (* 29-Dec-88 LAA *)
            LayoutRecord := ChartRecord^;
            AdjustLayout( GanttOutline );
            LayoutChecksum := C;
            BuildCorrelationList( GanttOutline );
            IF (WhatShows = ShowEverything) THEN
                CursorColumn := 1;

                    (*  If the Gantt bars region is NOT on the screen, then force
                        scrolling mode of the task tables portion so that the
                        arrow keys will do something that's visible.
                    *)

                WITH LayoutRecord DO
                    IF ((GanttWidth = 0) OR (NOT GanttShowing)) THEN
                        ScrollingEnabled := TRUE;
                    ELSIF (ColumnCount <= 1) THEN
                        ScrollingEnabled := FALSE;
                    END;
                END;
            END;
        END;
    END;

END CheckForChangeOnLayout;






PROCEDURE GanttOutlineDisplay(    GanttOutline : XGanttOutline);

VAR
    CNode                   : ATreeNode;
    i                       : CARDINAL;
    Pos                     : CARDINAL;
    Length                  : CARDINAL;
    FirstGantt              : CARDINAL;
    ViewWidth               : CARDINAL;
    RegUlx, RegUly,
    Reg2Lrx, Reg2Lry        : CARDINAL;
    ColumnDates             : ARRAY [0..maxcol + 1] OF ADate;
    ChartRecord             : AChartFormatPtr;
    r                       : REAL;
    DateLine1               : ARRAY [0..maxcol + 1] OF CHAR;
    DateLine2               : ARRAY [0..maxcol + 1] OF CHAR;
    GanttOnScreen           : BOOLEAN;
    SpreadOnScreen          : BOOLEAN;
    ChartStyle              : ADStyle;


    PROCEDURE MakeDateLine(     Heading     : AColumnInfoChoice;
                                ColumnId    : CARDINAL;
                                Pos         : CARDINAL;
                                Length      : CARDINAL;
                            VAR S           : ARRAY OF CHAR );
    
    VAR
        Task                : ATaskPtr;
        ColumnDataRecord    : AColumnDataRecord;
    
    BEGIN                   (* MakeDateLine *)
    
        Task := NIL;
        GetColumnInfo(NIL, Task, ColumnId, Heading, Length, ColumnDataRecord );
        Overlay(S, ColumnDataRecord.StringValue, Pos + 1, 
                LengthOf(ColumnDataRecord.StringValue));
    
    END MakeDateLine;


BEGIN                       (* GanttOutlineDisplay *)
    
    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateGanttOutline(AGanttOutline(GanttOutline));
    END;
    (*DEBUGGING>*)

    WITH GanttOutline^ DO
        ChartRecord := CurrentLayout();
        CheckForChangeOnLayout( GanttOutline, ChartRecord );
        IF (AVPView <> LayoutRecord.AVPShowing) THEN
            INCL(Status, NeedsRedisplay);
            GanttOutlineSetView(GanttOutline,
                                VAL(AGanttOutlineViewType,
                                ORD(LayoutRecord.AVPShowing)));
        END;

        IF (NeedsRedisplay IN Status) THEN
            Status := Status + AGanttOutlineStatusSet{NeedsStatusDisplay,
                                                   NeedsColumnHeadingsDisplay,
                                                   NeedsGanttDatesDisplay};
            EXCL(Status, NeedsRedisplay);
        END;

        IF ((NeedsStatusDisplay IN Status) 
           AND (WhatShows >= ShowTaskStats)) THEN
            CNode := Methods^.GetCursorNode(AGanttOutline(GanttOutline));
            DisplayTaskStats(CNode);
            EXCL(Status, NeedsStatusDisplay);
        END;

        IF (WhatShows <> ShowEverything) THEN                  (* 13-Dec-89 *)
            RETURN;
        END;

        IF (ChartStartDay <> PreviousChartStartDay) THEN
            INCL(Status, NeedsGanttDatesDisplay);
        END;

        WITH LayoutRecord DO
            ViewWidth := (Lrx - Ulx) + 1;
            GetLayoutMetrics( LayoutRecord, ViewWidth, GanttOnScreen, 
                              FirstGantt, SpreadOnScreen );
            IF (NeedsColumnHeadingsDisplay IN Status) THEN
                    (* FirstGantt - 1 for columns + 1 for the bug column *)
                Fill(DateLine1, " ", FirstGantt);
                Fill(DateLine2, " ", FirstGantt);

                i := 1;
                LOOP
                    IF (i > ColumnCount) THEN
                        EXIT;
                    END;
                    Pos := ColumnSpec[i].Position;
                    IF (Pos < FirstGantt) THEN
                        IF (ColumnSpec[i].Width > 1) THEN
                            Length := ColumnSpec[i].Width - 1;
                            IF (Pos + Length >= FirstGantt) THEN
                                Length := FirstGantt - Pos - 1;
                            END;
                            MakeDateLine( ColumnHeading1, 
                                          ColumnSpec[i].ColumnID,
                                          Pos, Length, DateLine1 );
                            MakeDateLine( ColumnHeading2, 
                                          ColumnSpec[i].ColumnID,
                                          Pos, Length, DateLine2 );
                        END;
                    ELSE
                        EXIT;
                    END;
                    INC(i);
                END;
                PutString(DateLine1, Ulx, Uly - 2, videodatebar);
                PutString(DateLine2, Ulx, Uly - 1, videodatebar);
                IF ((AVPView) AND (ODD(Lry - Uly + 1))) THEN      (* 17-Feb-88 LAA *)
                    EraseLn(Lry);
                END;
                IF (MousePresent()) THEN
                    IF (QueryRegion( ScreenCorrelList,7,RegUlx,RegUly,i,i ) AND
                        QueryRegion( ScreenCorrelList,8,i,i,Reg2Lrx,i)) THEN
                        PutHScrollBar( RegUlx, RegUly, Reg2Lrx, 
                                       SpreadOnScreen, FALSE );
                    END;
                    IF (QueryRegion( ScreenCorrelList,5,RegUlx,RegUly,i,i ) AND
                        QueryRegion( ScreenCorrelList,6,i,i,Reg2Lrx,i)) THEN
                        PutHScrollBar( RegUlx, RegUly, Reg2Lrx, 
                                       FALSE, GanttShowing );
                    END;
                    IF (QueryRegion( ScreenCorrelList,3,RegUlx,RegUly,i,i ) AND
                        QueryRegion( ScreenCorrelList,4,i,i,i,Reg2Lry )) THEN
                        PutVScrollBar( RegUlx, RegUly, Reg2Lry );
                    END;
                END;

                FOR i := 1 TO Last DO
                    SubView[i]^.Methods^.NotifyOfChange(SubView[i]);
                END;
                EXCL(Status, NeedsColumnHeadingsDisplay);
            END;

            IF ((NeedsGanttDatesDisplay IN Status) AND (GanttOnScreen)) THEN
                    (* Insure that the cursor date in on the screen *)
                ChartStartDay := FindStartDateOf(ChartStartDay, scaleunit);
                IF (CursorDay < ChartStartDay) THEN
                    ChartStartDay := FindPriorKeyDate(CursorDay, scaleunit);
                        (*  FindPriorKeyDate -> ChartStartDay <= CursorDay  *)
                    IF ((CursorDay-ChartStartDay) >= GanttWidth * scale) THEN  (* 24-Jun-91 *)
                        ChartStartDay := CursorDay - (GanttWidth * scale - 1);
                    END;
                ELSIF ((CursorDay - ChartStartDay) >= GanttWidth * scale) THEN
                    ChartStartDay := CursorDay - (GanttWidth * scale - 1);
                    ChartStartDay := FindNextKeyDate(ChartStartDay, 
                                                     scaleunit);
                    IF (CursorDay < ChartStartDay) THEN           (* 03-Nov-87 LAA *)
                        ChartStartDay := CursorDay;
                    END;
                END;

                IF (NOT CheckScale(GanttWidth,GanttPosition+1,ChartStartDay,
                                   scale,scaleunit,ChartStyle) ) THEN
                    FatalError();
                END;

                (*<DEBUGGING*)
                IF ((CursorDay < ChartStartDay) OR 
                   (((CursorDay - ChartStartDay) DIV GanttWidth) >= scale)) THEN
                    FatalError();
                END;
                (*DEBUGGING>*)

                i := GanttWidth;
                IF (MousePresent()) THEN
                    INC(i);
                END;
                DateLines(ChartStartDay,i,1,scale,scaleunit,
                          ChartStyle,ChartFont,TRUE,DateLine1,DateLine2,
                          ColumnDates);

                PutString(DateLine1, Ulx+FirstGantt, Uly-2, videodatebar);
                PutString(DateLine2, Ulx+FirstGantt, Uly-1, videodatebar);
                PreviousChartStartDay := ChartStartDay;
                FOR i := 1 TO Last DO
                    SubView[i]^.Methods^.
                               NoteSpecificChange(SubView[i], GanttBarChange);
                END;
                EXCL(Status, NeedsGanttDatesDisplay);
            END;
        END;

        GanttOutlineMethodsRecord.SuperclassMethods^.
                                         Display(AnOutlineView(GanttOutline));
    END;
    
END GanttOutlineDisplay;




PROCEDURE GanttOutlineDiscard(VAR GanttOutline : XGanttOutline);

BEGIN                       (* GanttOutlineDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateGanttOutline(AGanttOutline(GanttOutline));
    END;
    DEBUGGING>*)

    UnInitAsGanttOutline(AGanttOutline(GanttOutline));
    DISPOSE(GanttOutline);

END GanttOutlineDiscard;



(*  ExpandLeft --
        Expand a column from the left, starting with the Start column in the
        LayoutRecord.  ChartRecord is the master layout from the LayoutTree,
        LayoutRecord the local (munged) copy kept in GanttOutlines.
*)

PROCEDURE ExpandLeft( VAR LayoutRecord      : AChartFormat;
                          Start             : CARDINAL;
                          ChartRecord       : AChartFormatPtr): BOOLEAN;

BEGIN                       (* ExpandLeft *)

    WHILE (Start > 1) DO
        IF (LayoutRecord.ColumnSpec[Start].Width = 0) THEN
            IF (ChartRecord^.ColumnSpec[Start].Width > 0) THEN
                LayoutRecord.ColumnSpec[Start].Width :=
                                ChartRecord^.ColumnSpec[Start].Width;
                RETURN TRUE;
            END;
        END;
        DEC(Start);
    END;

    RETURN FALSE;

END ExpandLeft;


PROCEDURE SqueezeLeft( VAR LayoutRecord     : AChartFormat; 
                           End              : CARDINAL     ): BOOLEAN;

VAR 
    i               : CARDINAL; 

BEGIN               (* SqueezeLeft *) 

    i := 2; 
    WHILE (i < End) DO
        IF (LayoutRecord.ColumnSpec[i].Width > 0) THEN
            LayoutRecord.ColumnSpec[i].Width := 0;
            RETURN TRUE;
        END;
        INC(i); 
    END;

    RETURN FALSE; 

END SqueezeLeft;





PROCEDURE CursorColumnOnScreen(    GanttOutline : XGanttOutline;
                                   Cursor       : CARDINAL     ): BOOLEAN;

VAR
    i                   : CARDINAL;

BEGIN                   (* CursorColumnOnScreen *)

    WITH GanttOutline^.LayoutRecord.ColumnSpec[Cursor] DO
        RETURN ((Width <> 0) 
         AND (Position+Width <= (GanttOutline^.LayoutRecord.GanttPosition)));
    END;

END CursorColumnOnScreen;




PROCEDURE PreviousColumn(     ChartRecord   : AChartFormat;
                          VAR CursorColumn  : CARDINAL): BOOLEAN;

VAR
    i               : CARDINAL;

BEGIN               (* PreviousColumn *)

    WITH ChartRecord DO
        i := CursorColumn;
        WHILE (i > 1) DO
            DEC(i);
            IF (ColumnSpec[i].Width > 0) THEN
                CursorColumn := i;
                RETURN TRUE;
            END;
        END;
    END;

    RETURN FALSE;

END PreviousColumn;


PROCEDURE NextColumn( VAR ChartRecord  : AChartFormat;
                      VAR CursorColumn : CARDINAL     ): BOOLEAN; 

VAR 
    i               : CARDINAL; 

BEGIN               (* NextColumn *)

    WITH ChartRecord DO 
        i := CursorColumn;
        WHILE (i < ColumnCount) DO
            INC(i); 
            IF (ColumnSpec[i].Width > 0) THEN 
                CursorColumn := i;
                RETURN TRUE;
            END;
        END;
    END;

    RETURN FALSE; 

END NextColumn; 



PROCEDURE DoColumnScroll(    GanttOutline: XGanttOutline;
                             Code        : ACode;
                             Repeat      : BOOLEAN      );        (* 08-May-89 LAA *)

VAR
    ChartRecord         : AChartFormatPtr;



    PROCEDURE ColumnPartiallyOnScreen(    GanttOutline : XGanttOutline;           (* 03-May-89 LAA *)
                                          Cursor       : CARDINAL     ): BOOLEAN;

    VAR
        i                   : CARDINAL;

    BEGIN                   (* ColumnPartiallyOnScreen *)

        WITH GanttOutline^.LayoutRecord.ColumnSpec[Cursor] DO
            RETURN ((Width <> 0) 
                 AND (Position < (GanttOutline^.LayoutRecord.GanttPosition)));
        END;

    END ColumnPartiallyOnScreen;



    (*$O-*)
    PROCEDURE GotoNextColumn(): BOOLEAN;

    VAR
        ViewWidth       : CARDINAL;
        ok              : BOOLEAN;

    BEGIN               (* GotoNextColumn *)

        ok := TRUE;

        WITH GanttOutline^ DO
            ViewWidth := Lrx - Ulx;                            (* 11-Dec-89 *)
            IF (NextColumn(LayoutRecord, CursorColumn)) THEN   (* 13-Jan-90 *)
                IF (NOT CursorColumnOnScreen(GanttOutline, CursorColumn)) THEN
                    LOOP
                        IF (CursorColumnOnScreen(GanttOutline, CursorColumn)) THEN
                            EXIT; 
                        END;
                        IF (NOT SqueezeLeft( LayoutRecord, CursorColumn )) THEN 
                            WITH LayoutRecord.ColumnSpec[CursorColumn] DO   (* 01-May-89 LAA *)
                                IF (Position < ViewWidth) THEN
                                    Width := ViewWidth - Position;
                                ELSE
                                    IF (PreviousColumn(ChartRecord^, 
                                                       CursorColumn)) THEN END;
                                    ok := FALSE;
                                    EXIT;
                                END;
                            END;
                        END;
                        AdjustLayout( GanttOutline );
                        BuildCorrelationList( GanttOutline );
                    END;
                    Methods^.NotifyOfChange(AGanttOutline(GanttOutline));
                END;
                SubView[Cursor]^.Methods^.NotifyOfChange(SubView[Cursor]);
            ELSIF (SqueezeLeft( LayoutRecord, CursorColumn )) THEN
                AdjustLayout( GanttOutline );
                BuildCorrelationList( GanttOutline );
                Methods^.NotifyOfChange(AGanttOutline(GanttOutline));
            ELSE
                ok := FALSE;
            END;
        END;

        RETURN ok;
                    
    END GotoNextColumn;
    (*$O=*)

    (*$O-*)
    PROCEDURE GotoPreviousColumn(): BOOLEAN;

    VAR
        ViewWidth       : CARDINAL;
        ok              : BOOLEAN;

    BEGIN               (* GotoPreviousColumn *)

        ok := TRUE;

        WITH GanttOutline^ DO
            ViewWidth := Lrx - Ulx;                            (* 11-Dec-89 *)
            IF (PreviousColumn(ChartRecord^, CursorColumn)) THEN
                IF (NOT CursorColumnOnScreen(GanttOutline, CursorColumn)) THEN
                    LOOP
                        IF (CursorColumnOnScreen(GanttOutline, CursorColumn)) THEN
                            EXIT;
                        END;
                        IF (ColumnPartiallyOnScreen(GanttOutline,        (* 03-May-89 LAA *)
                                                    CursorColumn)) THEN
                            WITH LayoutRecord.ColumnSpec[CursorColumn] DO   
                                Width := ViewWidth - Position;
                            END;
                            EXIT;
                        END;

                        IF (NOT ExpandLeft(LayoutRecord, CursorColumn, 
                                           ChartRecord)) THEN
                            IF (NextColumn(ChartRecord^, CursorColumn)) THEN END; 
                            ok := FALSE;
                            EXIT;
                        END;
                        AdjustLayout( GanttOutline );
                        BuildCorrelationList( GanttOutline );
                    END;
                    Methods^.NotifyOfChange(AGanttOutline(GanttOutline));
                END;
                SubView[Cursor]^.Methods^.NotifyOfChange(SubView[Cursor]);
            ELSIF (ExpandLeft(LayoutRecord, CursorColumn, ChartRecord)) THEN
                AdjustLayout( GanttOutline );
                BuildCorrelationList( GanttOutline );
                Methods^.NotifyOfChange(AGanttOutline(GanttOutline));
            ELSE
                ok := FALSE;
            END;
        END;

        RETURN ok;

    END GotoPreviousColumn;
    (*$O=*)


BEGIN                   (* DoColumnScroll *)                  (* 13-Mar-89 LAA *)

    ChartRecord := CurrentLayout();
    WITH GanttOutline^ DO
        REPEAT
            IF (Code = Fwrd) THEN
                IF (NOT GotoNextColumn()) THEN
                    IF (Repeat) THEN
                        Repeat := FALSE;
                    ELSE
                        PostError (NotPossibleInContextError, ModuleNumber + 6);
                    END;
                END;
            ELSIF (Code = Reverse) THEN
                IF (NOT GotoPreviousColumn()) THEN
                    IF (Repeat) THEN
                        Repeat := FALSE;
                    ELSE
                        PostError (NotPossibleInContextError, ModuleNumber + 6);
                    END;
                END;
            END;
        UNTIL (NOT Repeat);
    END;

END DoColumnScroll;




(*$O-*)
PROCEDURE BuildCorrelationList(     GanttOutline     : XGanttOutline );

VAR
    FirstUlx,
    FirstUly,
    FirstLrx, 
    FirstLry,
    LastUlx,
    LastUly,
    LastLrx, 
    LastLry                 : CARDINAL;
    ViewWidth               : CARDINAL;
    FirstGantt              : CARDINAL;
    GanttOnScreen           : BOOLEAN;
    SpreadOnScreen          : BOOLEAN;

BEGIN                       (* BuildCorrelationList *)

    IF (NOT MousePresent()) THEN RETURN; END;

    WITH GanttOutline^ DO
        IF (ScreenCorrelList <> ACorrelationList(NIL)) THEN
            DisposeCorrelationList( ScreenCorrelList );
        END;
        ScreenCorrelList := CreateCorrelationList();

        IF (Last > 0) THEN
            SubView[1]^.Methods^.GetInternalXY( SubView[1], 
                                                FirstUlx, FirstUly, 
                                                FirstLrx, FirstLry );
            SubView[Last]^.Methods^.GetInternalXY( SubView[Last], 
                                                   LastUlx, LastUly,
                                                   LastLrx, LastLry );
            SetRegion( ScreenCorrelList, InteriorRegion, 
                       FirstUlx, FirstUly, LastLrx, LastLry );
        END;
        SetRegion( ScreenCorrelList, MenuRegion, 0, 0, maxcol, Uly - 3 );
        ViewWidth := Lrx - Ulx + 1;
        GetLayoutMetrics( LayoutRecord, ViewWidth, GanttOnScreen, 
                          FirstGantt, SpreadOnScreen );
        IF (LayoutRecord.GanttShowing) THEN
            FirstUlx := Ulx+1;
            IF (SpreadOnScreen) THEN
                INC(FirstUlx, ((ViewWidth-2) DIV 2) + 1);
            END;
            FirstLrx := FirstUlx+((Lrx-1-FirstUlx) DIV 2)-1;
            LastUlx := FirstLrx + 3;
            SetRegion( ScreenCorrelList, ScrollGanttRightRegion, FirstUlx, Lry+1, FirstLrx, Lry+1 );
            SetRegion( ScreenCorrelList, ScrollGanttLeftRegion, LastUlx, Lry+1, Lrx-1, Lry+1 );
        END;
        IF (SpreadOnScreen) THEN
            IF (LayoutRecord.GanttShowing) THEN
                LastLrx := FirstUlx - 2;            (* from above section *)
                LastUlx := LastLrx - (((ViewWidth-2) DIV 4) - 1);
            ELSE
                LastLrx := Lrx-1;
                LastUlx := LastLrx - (((ViewWidth-2) DIV 2) - 1);
            END;
            FirstLrx := LastUlx - 3;
            SetRegion( ScreenCorrelList, ScrollSpreadRightRegion, Ulx+1, Lry+1, FirstLrx, Lry+1 );
            SetRegion( ScreenCorrelList, ScrollSpreadLeftRegion, LastUlx, Lry+1, LastLrx, Lry+1 );
        END;
        FirstUly := Uly;
        FirstLry := Uly + ((Lry-Uly+1) DIV 2) - 1;
        LastUly := FirstLry + 2;
        LastLry := Lry;
        IF (LastUly > LastLry) THEN                            (* 01-Aug-91 *)
            LastUly := LastLry;
        END;
        SetRegion( ScreenCorrelList, ScrollDownRegion, Lrx, FirstUly, Lrx, FirstLry );
        SetRegion( ScreenCorrelList, ScrollUpRegion, Lrx, LastUly, Lrx, LastLry );
        IF (QueryLightXY( RecomputeLight,FirstUlx,FirstUly,FirstLrx,FirstLry )) THEN
            SetRegion( ScreenCorrelList,RecalcLightRegion,FirstUlx,FirstUly,FirstLrx,FirstLry );
        END;
    END;
 
END BuildCorrelationList;
(*$O=*)




PROCEDURE GanttOutlineActOn(    GanttOutline : XGanttOutline;
                                Event        : AnEvent;
                            VAR ReturnEvent  : AnEvent     );

TYPE
    AGotoType           = (ByName, ByWBS, ByCursorColumn);

VAR
    ChartRecord             : AChartFormatPtr;
    CursorNode              : ATreeNode;
    i                       : CARDINAL;
    Sub                     : CARDINAL;
    ErrorMarker             : AnErrorMarker;
    Region                  : CARDINAL;
    WantToRecord            : BOOLEAN;
    s                       : ARRAY [0..31] OF CHAR;
    RecordForUndo           : BOOLEAN;
    LAdvancedTaskForm       : BOOLEAN;

    
    PROCEDURE RespondToErrors(    ErrorMarker : AnErrorMarker);

    VAR
        Category                : CARDINAL;
         Code                    : CARDINAL;
        i                       : CARDINAL;
        s                       : ARRAY [0..255] OF CHAR;

    BEGIN                   (* RespondToErrors *)

        i := 0;
        REPEAT
            GetErrorDetails(ErrorMarker, i, Category, Code);
            IF ((Category = NotPossibleInContextError) OR 
               (Category = UnknownEventError)) THEN
                Burp();
            END;
            INC(i);
        UNTIL (Category = 0);

    END RespondToErrors;



    PROCEDURE BugMessage();

    VAR
        TaskForBug          : ATaskPtr;
        s                   : ARRAY [0..255] OF CHAR;

    BEGIN                   (* BugMessage *)

        Fill(s, " ", 0);
        IF (BugTaskA <> NIL) THEN
            GetMessage(ModuleNumber+74, s);       (* 'Pressing F3 will join ' *)
            TaskForBug := BugTaskA^.Methods^.LockFlexStorDataObject(BugTaskA);
            ConcatLS(s, TaskForBug^.taskname);
            BugTaskA^.Methods^.UnlockUnchangedDataObject(BugTaskA);  (* 11-Jan-88 LAA *)
            ConcatMessage(s, ModuleNumber+76);    (* ' ---> the cursor task.' *)
        ELSIF (BugTaskB <> NIL) THEN
            GetMessage(ModuleNumber+73,s);        (*  'Pressing F3 will join the cursor task ---> " *)
            TaskForBug := BugTaskB^.Methods^.LockFlexStorDataObject(BugTaskB);
            ConcatLS(s,TaskForBug^.taskname);
            BugTaskB^.Methods^.UnlockUnchangedDataObject(BugTaskB);  (* 11-Jan-88 LAA *)  
            ConcatMessage(s,ModuleNumber+75);     (* '".' *)
        END;
        Message(s);

    END BugMessage;



    PROCEDURE OkToDemote(): BOOLEAN;

    VAR
        Node                : ATreeNode;
        CNode               : ATreeNode;
        SNode               : ATreeNode;
        ANode               : ATreeNode;
        Task                : ATaskPtr;
        Summary             : BOOLEAN;
        OurStartStatus      : AStartStatus;
        s                   : ARRAY [0..255] OF CHAR;
        PrevIsSummary       : BOOLEAN;


        PROCEDURE Joined(    A  : ATreeNode;
                             B  : ATreeNode): BOOLEAN;

        BEGIN               (* Joined *)
            RETURN (ItDepends(A, B)) OR (ItDepends(B, A));
        END Joined;

    BEGIN                   (* OkToDemote *)

        IF (CursorNode = NIL) THEN
            RETURN TRUE;
        END;

        CNode := CursorNode;

        SNode := CNode^.Methods^.GetPrev(CNode);

        IF (SNode <> NIL) THEN                                    (* 29-Dec-87 LAA *)
            Task  := SNode^.Methods^.LockFlexStorDataObject(SNode);
            ANode := SNode^.Methods^.FirstChild(SNode); (* 28-Sep-89 WKH  *)
            PrevIsSummary  := ANode <> NIL;
            Summary        := Task^.summarizes <> AText(NIL);
            OurStartStatus := Task^.StartStatus;
            SNode^.Methods^.UnlockUnchangedDataObject(SNode);     (* 11-Jan-88 LAA *)
            IF (Summary) THEN
                GetMessage(ModuleNumber + 78, s);  (* "The previous task cannot be made into a summary." *)
                Error(s);
                RETURN FALSE;
            ELSIF ((OurStartStatus = StartedS) OR (OurStartStatus = DoneS))
                  AND (NOT PrevIsSummary) THEN
                GetMessage(ModuleNumber + 81, s);  (* "The previous task cannot be made into a summary." *)
                Error(s);
                RETURN FALSE;
            END;
        END;

        Node := CNode;
        WHILE (Node <> NIL) DO
            ANode := Node^.Methods^.GetNext (Node);
            IF (ANode = NIL) THEN
                Node := Node^.Methods^.Parent (Node);
            ELSE
                Node := NIL;
            END;
        END;

        Node := SNode;
        WHILE (CNode <> ANode) DO
            WHILE (Node <> NIL) DO
                IF (Joined(Node, CNode)) THEN
                    GetMessage(ModuleNumber + 71, s);  (* "This task is joined to a task which would summarize it." *)
                    Error(s);
                    RETURN FALSE;
                END;
                Node := Node^.Methods^.Parent(Node);
            END;
            CNode := CNode^.Methods^.NextPreOrder(CNode);
            Node := SNode;
        END;

        RETURN TRUE;

    END OkToDemote;



    (*$O-*)
    PROCEDURE DoTaskEdit( ChangeTaskProc : AnAlternateChangeTaskProc ); (* RSC 4/3/89 *)

    VAR
        PrevPosition        : CARDINAL;
        Changed             : BOOLEAN;

    BEGIN                   (* DoTaskEdit *)

        WITH GanttOutline^.Methods^ DO
            IF (CursorNode <> NIL) THEN
                Display(AGanttOutline(GanttOutline));
                Changed := ChangeTaskProc (CursorNode); (* RSC 4/3/89 *)
                IF (NOT Changed) THEN
                    NotifyUndo (Task, ChartActive, GanttOutline);
                    AbortTransactionSet();
                ELSE
                    WITH GanttOutline^ DO
                        Methods^.NoteSpecificChange( AGanttOutline(GanttOutline), TaskChange );
                        SubView[Cursor]^.Methods^.NotifyOfChange(SubView[Cursor]);
                    END;
                END;
            ELSE
                DoTaskInsert( ChangeTaskProc );
            END;
        END;

    END DoTaskEdit;
    (*$O=*)



    PROCEDURE DoTaskDelete();

    VAR
        CNode               : ATreeNode;
        TNode               : ATreeNode;

    BEGIN                   (* DoTaskDelete *)

        WITH GanttOutline^.Methods^ DO
            IF (CursorNode <> NIL) THEN
                CNode := CursorNode^.Methods^.GetNextVisible(CursorNode);
                IF (CNode = NIL) THEN
                    CNode := CursorNode^.Methods^.GetPrevVisible(CursorNode);
                    IF (CNode = NIL) THEN
                        CNode := CursorNode^.Methods^.Parent(CursorNode);
                    END;
                END;
                Display(AGanttOutline(GanttOutline));
                DeleteTask(CursorNode);
                IF (CursorNode = NIL) THEN
                    IF (GanttOutline^.Cursor = 1) THEN
                        SetFirst(AGanttOutline(GanttOutline), CNode);
                    ELSE
                        Synchronize(AGanttOutline(GanttOutline));
                    END;
                    SetCursorNode(AGanttOutline(GanttOutline), CNode);
                END;
            ELSE
                PostError(NotPossibleInContextError, ModuleNumber + 1);
            END;
        END;

    END DoTaskDelete;



    PROCEDURE DoTaskInsert( ChangeProc : AnAlternateChangeTaskProc );

    VAR
        NewNode             : ATreeNode;
        OldCursorNode       : ATreeNode;
        TaskPtr             : ATaskPtr;

    BEGIN                   (* DoTaskInsert *)

        WITH GanttOutline^.Methods^ DO
            NewNode := AddNewTask (CursorNode);
            IF (NewNode = NIL) THEN
                PostError (AllocationError, ModuleNumber + 2);
                RETURN;
            END;
            IF (CursorNode = NIL) THEN
                SetFirst (AGanttOutline(GanttOutline), NewNode);
            END;
            OldCursorNode := CursorNode;
            CursorNode := NewNode;
            SetCursorNode (AGanttOutline(GanttOutline), NewNode);
            DoTaskEdit( ChangeProc );
            IF (UndoStatus = Active) THEN
                UnSetState (Scheduled);
                ScheduleSaved := FALSE;
                TaskPtr := NewNode^.Methods^.LockFlexStorDataObject (NewNode);  (* 10-Dec-87 LAA *)
                IF (TaskPtr^.fixation = ALAP) THEN
                    BugTaskA := NIL;
                    BugTaskB := OldCursorNode;  (* old one gets a "S" *)
                ELSE
                    BugTaskA := OldCursorNode;  (* old one gets a "P" *)
                    BugTaskB := NIL;
                END;
                NewNode^.Methods^.UnlockUnchangedDataObject(NewNode);  (* 10-Dec-87 LAA *) (* 11-Jan-88 LAA *)
            END;
        END;

        SortOrderManuallyAltered := TRUE;
    END DoTaskInsert;



    PROCEDURE DoTaskCopy();

    VAR
        CopyOfNode          : ATreeNode;
        OldCursorNode       : ATreeNode;
        TaskPtr             : ATaskPtr;

    BEGIN                   (* DoTaskCopy *)

        WITH GanttOutline^.Methods^ DO
            IF (CursorNode <> NIL) THEN
                CopyOfNode := AddTaskCopy (CursorNode);           (* 4/18/89 EGK *)
                IF (CopyOfNode <> NIL) THEN
                    OldCursorNode := CursorNode;                  (* 23-Feb-88 LAA *)
                    Synchronize(AGanttOutline(GanttOutline));
                    SetCursorNode(AGanttOutline(GanttOutline), CopyOfNode);
                    CursorNode := CopyOfNode;
                    DoTaskEdit( ChangeTask );
                    IF (UndoStatus = Active) THEN
                        UnSetState (Scheduled);
                        ScheduleSaved := FALSE;
                        TaskPtr := CopyOfNode^.Methods^.LockFlexStorDataObject (CopyOfNode);  (* 23-Feb-88 LAA *)
                        IF (TaskPtr^.fixation = ALAP) AND
                                (* Handle summaries here as if ASAP, not ALAP *)
                           (OldCursorNode^.Methods^.GetSubtree (OldCursorNode) = NIL) THEN  (* 4/18/89 EGK *)
                            BugTaskA := NIL;
                            BugTaskB := OldCursorNode;  (* old one gets a "S" *)
                        ELSE
                            BugTaskA := OldCursorNode;  (* old one gets a "P" *)
                            BugTaskB := NIL;
                        END;
                        CopyOfNode^.Methods^.UnlockUnchangedDataObject(CopyOfNode);  
                    END;
                ELSE
                    PostError (AllocationError, ModuleNumber + 3);  (* No memory *)
                END;
            ELSE
                DoTaskInsert( ChangeTask );
            END;
        END;

        SortOrderManuallyAltered := TRUE;
    END DoTaskCopy;



    PROCEDURE DoBugKey();


        (*$O-*)
        PROCEDURE NotifyChanged(    Node    : ATreeNode);

        VAR
            i               : CARDINAL;

        BEGIN               (* NotifyChanged *)

            IF (Node = NIL) THEN RETURN END;

            WITH GanttOutline^ DO
                i := SubviewForNode(GanttOutline, Node);
                IF (i <> 0) THEN
                    SubView[i]^.Methods^.
                                   NoteSpecificChange(SubView[i], BugsChange);
                END;
            END;

        END NotifyChanged;
        (*$O=*)

    BEGIN                   (* DoBugKey *)

        IF (CursorNode <> NIL) THEN
            IF (CursorNode = BugTaskA) THEN
                NotifyChanged(CursorNode);
                BugTaskA := NIL;
                BugTaskB := CursorNode;
            ELSIF (CursorNode = BugTaskB) THEN
                NotifyChanged(CursorNode);
                BugTaskB := NIL;
            ELSE
                NotifyChanged(BugTaskA);
                NotifyChanged(BugTaskB);
                BugTaskA := CursorNode;
                BugTaskB := NIL;
                NotifyChanged(CursorNode);
            END;
        END;

        BugMessage();

    END DoBugKey;


    PROCEDURE DoTaskNotes();

    VAR
        TaskPtr             : ATaskPtr;
        PrevPosition        : CARDINAL;
        Changed             : BOOLEAN;
        PrivateTaskName     : ATaskName;
        PrivateNotes        : AText;

    BEGIN                   (* DoTaskNotes *)

        WITH GanttOutline^.Methods^ DO
            IF (CursorNode = NIL) THEN 
                PostError(NotPossibleInContextError, ModuleNumber + 4);
                RETURN;
            END;

            Display(AGanttOutline(GanttOutline));

            SendNotices (ChangeATask, BeforeActing, CursorNode);     (* 6/4/89 EGK *)
            TaskPtr := CursorNode^.Methods^.LockFlexStorDataObject(CursorNode);  (* 10-Dec-87 LAA *)
            WITH TaskPtr^ DO
                PrivateTaskName := taskname;
                PrivateNotes    := notes;
            END;
            CursorNode^.Methods^.UnlockUnchangedDataObject(CursorNode);  (* 10-Dec-87 LAA *) (* 11-Jan-88 LAA *)

                                 (*   9/14/89 EGK *)
            EditText(9, GanttWStart+4, 74, GanttWEnd,  (* 10-Feb-88 LAA *)
                     ABoxType{ShadowBox, DoubleBox}, PrivateTaskName, 0,
                     PrivateNotes, Changed);

            IF (Changed) THEN   (* 9/15/88 - WKH - Wasn't saving schedule before *)
                ScheduleSaved := FALSE;
                INCL(GanttOutline^.Status, NeedsStatusDisplay); (* RSC 4/4/89 *)
            END;

            TaskPtr := CursorNode^.Methods^.LockFlexStorDataObject(CursorNode);  (* 10-Dec-87 LAA *)
            TaskPtr^.notes := PrivateNotes;
            CursorNode^.Methods^.UnlockFlexStorDataObject(CursorNode);  (* 10-Dec-87 LAA *)
        END;

    END DoTaskNotes;


    PROCEDURE ProceedWithTaskMovement(): BOOLEAN;

    VAR
        Selection           : CARDINAL;
        Choices             : ARRAY [0..255] OF CHAR;
        Title               : ARRAY [0..31] OF CHAR;
        Prefix              : ARRAY [0..81] OF CHAR;
        s                   : ARRAY [0..255] OF CHAR;

    BEGIN                   (* ProceedWithTaskMovement *)

        IF (CursorNode = NIL) THEN
            PostError (NotPossibleInContextError, ModuleNumber + 5);
            RETURN FALSE;
        END;

        IF (GanttOutline^.LayoutRecord.TaskNameOnScreen) THEN
            IF (NOT WarnBeforeManualChange) THEN
                RETURN TRUE;
            END;
                (*  Moving tasks around will invalidate the last manual order.  Do you want to continue?  *)
            GetMessage(ModuleNumber + 10, s);
            SetLengthOf(Prefix, 0);
                (*  Forget I asked, Proceed, Stop bothering me  *)
            GetMessage(ModuleNumber + 11, Choices);
                (*  Move Task *)
            GetMessage(ModuleNumber + 12, Title);
            Selection := 2;
            Burp();
            IF (MultipleChoiceBox(s, Title, OfferHelp, Prefix, Choices,
                                  Selection)) THEN
                IF (Selection > 1) THEN
                    IF (Selection = 3) THEN
                        WarnBeforeManualChange := FALSE;
                    END;
                    RETURN TRUE;
                END;
            END;
        ELSE
            GetMessage(ModuleNumber + 70, s);    (* "That function is disabled when the task names are not on the screen." *)
            Error(s);
        END;

        RETURN FALSE;

    END ProceedWithTaskMovement;



    PROCEDURE DoPromoteKey();

    VAR
        Indent              : CARDINAL;
        ParentTask          : ATreeNode;

    BEGIN                   (* DoPromoteKey *)

        IF (NOT ProceedWithTaskMovement()) THEN
            RETURN;
        END;

        Indent := CursorNode^.Methods^.IndentationLevel(CursorNode);

        SendNotices (MoveATask, BeforeActing, CursorNode);        (* 6/4/89 EGK *)
        ParentTask := CursorNode^.Methods^.Parent (CursorNode);
        IF (ParentTask <> NIL) THEN
            SendNotices (ChangeATask, BeforeActing, ParentTask);
        END;

        WITH GanttOutlineMethodsRecord.SuperclassMethods^ DO
            ActOnEvent(AnOutlineView(GanttOutline), Event, ReturnEvent);
        END;
        WantToRecord := FALSE;
        IF (Indent <> CursorNode^.Methods^.IndentationLevel(CursorNode)) THEN
            UnSetState(Scheduled);
            ScheduleSaved := FALSE;
        END;
        SortOrderManuallyAltered := TRUE;

    END DoPromoteKey;



    PROCEDURE DoDemoteKey();

    VAR
        Indent              : CARDINAL;
        PrevTask            : ATreeNode;

    BEGIN                   (* DoDemoteKey *)

        IF (NOT ProceedWithTaskMovement()) THEN
            RETURN;
        END;

        IF OkToDemote() THEN
            Indent := CursorNode^.Methods^.IndentationLevel(CursorNode);
            SendNotices (MoveATask, BeforeActing, CursorNode);    (* 6/4/89 EGK *)
            PrevTask := CursorNode^.Methods^.GetPrev (CursorNode);
            IF (PrevTask <> NIL) THEN
                SendNotices (ChangeATask, BeforeActing, PrevTask);
            END;

            WITH GanttOutlineMethodsRecord.SuperclassMethods^ DO
                ActOnEvent(AnOutlineView(GanttOutline),Event,ReturnEvent);
            END;
            WantToRecord := FALSE;
            IF (Indent <> CursorNode^.Methods^.IndentationLevel(CursorNode)) THEN
                UnSetState(Scheduled);
                ScheduleSaved := FALSE;
            END;
            SortOrderManuallyAltered := TRUE;
        END;

    END DoDemoteKey;


    PROCEDURE DoMoveUpAndDownKeys();

    BEGIN                   (* DoMoveUpAndDownKeys *)

        IF (NOT ProceedWithTaskMovement()) THEN
            RETURN;
        END;

        SendNotices (MoveATask, BeforeActing, CursorNode);   (* 6/4/89 EGK *)
        WITH GanttOutlineMethodsRecord.SuperclassMethods^ DO
            ActOnEvent(AnOutlineView(GanttOutline), Event, ReturnEvent);
        END;
        WantToRecord := FALSE;
        ScheduleSaved := FALSE;
        UnSetState (Formatted);
        SortOrderManuallyAltered := TRUE;

    END DoMoveUpAndDownKeys;



    PROCEDURE DoOpenAndCloseKeys(   Code    : ACode );
    VAR
        DoubleRepeat        : BOOLEAN;
        Occasion            : AnOccasion;

    BEGIN                   (* DoOpenAndCloseKeys *)

        IF (CursorNode = NIL) THEN
            PostError (NotPossibleInContextError, ModuleNumber + 6);
            RETURN;
        END;

        DoubleRepeat := (GanttOutline^.EventHistory[0].EventCode = RepeatKey) AND
                        (GanttOutline^.EventHistory[1].EventCode = RepeatKey);

        IF (CursorNode^.Methods^.FirstChild (CursorNode) <> NIL) OR
                    (DoubleRepeat) THEN                 (* 9/25/89 EGK *)
            IF (Code = OpenKey) THEN
                Occasion := OpenATask;
            ELSE
                Occasion := CloseATask;
            END;
            SendNotices (Occasion, BeforeActing, CursorNode);
        END;

        WITH GanttOutlineMethodsRecord.SuperclassMethods^ DO
            ActOnEvent(AnOutlineView(GanttOutline), Event, ReturnEvent);
        END;
        WantToRecord := FALSE;
        ScheduleSaved := FALSE;
        INCL(GanttOutline^.Status, NeedsStatusDisplay);   (* RSC 6-Sep-89 *)

    END DoOpenAndCloseKeys;



    PROCEDURE DoGotoKey ( GoToColumn   : CARDINAL );

    BEGIN                   (* DoGotoKey *)

        WITH GanttOutline^ DO
            Methods^.Display(AGanttOutline(GanttOutline));
            IF (DoGanttGotoKey( Ulx+40, Uly+1, Ulx+75, Lry-6, ViewObject, (* 11-Dec-89 *)
                                GoToColumn, CursorColumn, CursorNode )) THEN
                Methods^.SetCursorNode(AGanttOutline(GanttOutline),CursorNode);
                INCL(Status, NeedsStatusDisplay);
            END;
        END;

    END DoGotoKey;



    (*$O-*)
    PROCEDURE SubviewByPosition(     X      : CARDINAL;
                                     Y      : CARDINAL): CARDINAL;

    VAR
        i                   : CARDINAL;
        LocalUlx,
        LocalUly,
        LocalLrx,
        LocalLry            : CARDINAL;

    BEGIN                   (* SubviewByPosition *)
        
        WITH GanttOutline^ DO
            FOR i := 1 TO Last DO
                SubView[i]^.Methods^.GetInternalXY( SubView[i], LocalUlx,
                                                    LocalUly, LocalLrx,
                                                    LocalLry );
                IF ((X >= LocalUlx) AND (X <= LocalLrx) 
                    AND (Y >= LocalUly) AND (Y <= LocalLry)) THEN
                    RETURN i;
                END;
            END;
        END;

        FatalError();
        
    END SubviewByPosition;
    (*$O=*)


    PROCEDURE MaybePostError(    EventCode  : ACode );

    BEGIN                   (* MaybePostError *)

        IF (EventCode = MouseDown) THEN
            PostError(NotPossibleInContextError, ModuleNumber + 3);
        END;

    END MaybePostError;



    PROCEDURE ScrollLeft(    EventCode      : ACode);

    VAR
        MaxiDate             : ADate;

    BEGIN                   (* ScrollLeft *)

        WITH GanttOutline^.LayoutRecord DO
            (* Make sure that we never NEVER try to go too near the
               right hand edge of time.  Just to be very sure, back off
               by two weeks, days or whatever the synchronizing unit is. *)
            MaxiDate := FindPriorKeyDate(MaxDate, scaleunit);
            MaxiDate := FindPriorKeyDate(MaxiDate, scaleunit);

            IF (ChartStartDay < MaxiDate) THEN
                ChartStartDay := FindNextKeyDate(ChartStartDay + scale,
                                                 scaleunit);
                ChartStartDay := FindStartDateOf(ChartStartDay, scaleunit);
                INCL( GanttOutline^.Status, NeedsGanttDatesDisplay );
                IF (CursorDay < ChartStartDay) THEN
                    CursorDay := ChartStartDay;
                END;
            ELSE
                MaybePostError(EventCode);
            END;
        END;

    END ScrollLeft;


    PROCEDURE ScrollRight(    EventCode     : ACode );

    BEGIN                   (* ScrollRight *)

        WITH GanttOutline^.LayoutRecord DO
            IF (ChartStartDay > 0) THEN
                ChartStartDay := FindPriorKeyDate(ChartStartDay, scaleunit);
                ChartStartDay := FindStartDateOf(ChartStartDay, scaleunit);
                IF (CursorDay > (ChartStartDay + (scale * GanttWidth) - 1)) THEN
                    CursorDay := (ChartStartDay + scale * GanttWidth) - 1;
                END;
                INCL( GanttOutline^.Status, NeedsGanttDatesDisplay );
            ELSE
                MaybePostError(EventCode);
            END;
        END;
  
    END ScrollRight;


    PROCEDURE ScrollSpreadRight(    EventCode : ACode );

    VAR
        i                   : CARDINAL;

    BEGIN                   (* ScrollSpreadRight *)

        WITH GanttOutline^ DO
            i := 1; 
            IF ((NextColumn( LayoutRecord, i )) AND
               (ExpandLeft( LayoutRecord, i, ChartRecord))) THEN 
                AdjustLayout( GanttOutline ); 
                WHILE ((CursorColumn > 1) AND              (* 17-Jan-90 *)
                      (NOT CursorColumnOnScreen(GanttOutline,CursorColumn))) DO
                    IF (NOT PreviousColumn( LayoutRecord, CursorColumn )) THEN
                    END; 
                END;
                BuildCorrelationList( GanttOutline ); 
                Methods^.NotifyOfChange(AGanttOutline(GanttOutline)); 
            ELSE
                MaybePostError(EventCode);
            END;
        END;

    END ScrollSpreadRight;



    PROCEDURE ScrollSpreadLeft(    EventCode : ACode );

    VAR
        i                   : CARDINAL;

    BEGIN                   (* ScrollSpreadLeft *)

        WITH GanttOutline^ DO 
            i := LayoutRecord.ColumnCount;                     (* 13-Jan-90 *)
            WHILE ((i > 1) AND (LayoutRecord.ColumnSpec[i].Width = 0)) DO
                DEC( i );
            END;
            IF (SqueezeLeft( LayoutRecord, i )) THEN 
                AdjustLayout( GanttOutline ); 
                IF (NOT CursorColumnOnScreen( GanttOutline, CursorColumn )) THEN
                    IF (NextColumn( LayoutRecord, CursorColumn )) THEN END; 
                END;
                BuildCorrelationList( GanttOutline ); 
                Methods^.NotifyOfChange(AGanttOutline(GanttOutline)); 
            ELSE
                MaybePostError(EventCode);
            END;
        END;

    END ScrollSpreadLeft;



    PROCEDURE ScrollDown(    EventCode      : ACode );

    VAR 
        First               : ATreeNode;
        CNode               : ATreeNode;
        LNode               : ATreeNode;

    BEGIN                   (* ScrollDown *)

        WITH GanttOutline^ DO 
            First := Methods^.GetFirst( AGanttOutline(GanttOutline) );
            CNode := Methods^.GetCursorNode( AGanttOutline(GanttOutline) );
            LNode := Methods^.GetLast( AGanttOutline(GanttOutline) );
            IF (First <> ATreeNode(NIL)) THEN 
                First := First^.Methods^.PrevForDisplay( First ); 
                IF (First <> ATreeNode(NIL)) THEN 
                    Methods^.SetFirst( AGanttOutline(GanttOutline), First );
                    IF ((CNode = LNode) AND
                       (LNode <> Methods^.GetLast( AGanttOutline(GanttOutline) ))) THEN
                        CNode := LNode^.Methods^.PrevForDisplay( LNode );
                    END;
                    Methods^.SetCursorNode( AGanttOutline(GanttOutline),CNode );
                ELSE
                    MaybePostError(EventCode);
                END;
            ELSE
                MaybePostError(EventCode);
            END;
        END;

    END ScrollDown; 


    PROCEDURE ScrollUp(    EventCode        : ACode );

    VAR 
        FNode               : ATreeNode;
        CNode               : ATreeNode;
        Same                : BOOLEAN;

    BEGIN                   (* ScrollUp *)

        WITH GanttOutline^ DO 
            FNode := Methods^.GetFirst( AGanttOutline(GanttOutline) );
            CNode := Methods^.GetCursorNode( AGanttOutline(GanttOutline) );
            Same := (FNode = CNode);
            IF (FNode <> ATreeNode(NIL)) THEN 
                FNode := FNode^.Methods^.NextForDisplay( FNode ); 
                IF (FNode <> ATreeNode(NIL)) THEN 
                    Methods^.SetFirst( AGanttOutline(GanttOutline), FNode );
                    IF (FNode <> Methods^.GetFirst( AGanttOutline(GanttOutline) )) THEN 
                        MaybePostError(EventCode);
                    ELSE
                        IF (Same) THEN
                            CNode := FNode;
                        END;
                        Methods^.SetCursorNode( AGanttOutline(GanttOutline),
                                                CNode );
                    END;
                ELSE
                    MaybePostError(EventCode);
                END;
            ELSE
                MaybePostError(EventCode);
            END;
        END;

    END ScrollUp; 



    PROCEDURE DispatchMouse(     Event      : AnEvent );

    VAR
        i                   : CARDINAL;

    BEGIN                   (* DispatchMouse *)

        WITH Event DO
            i := CorrelatePoint( GanttOutline^.ScreenCorrelList, 
                                 EventX, EventY );
            IF (i = RecalcLightRegion) THEN
                (*<ANDREW
                IF (EventCode = MouseDouble) THEN
                    UnSetState(Scheduled);
                    EventCode := ComputeKey;
                    PushEvent( Event );
                END;
                ANDREW>*)
                IF (EventCode = MouseUp) THEN
                    EventCode := ComputeKey;
                    PushEvent( Event );
                END;
            ELSIF ((EventCode = MouseDown) 
                OR ((i = GanttOutline^.MouseDownRegion) 
                    AND (EventCode = MouseStillDown))) THEN
                GanttOutline^.MouseDownRegion := i;
                CASE i OF
                    ScrollDownRegion :
                        ScrollDown(EventCode); 
                |   ScrollUpRegion :
                        ScrollUp(EventCode); 
                |   ScrollSpreadRightRegion :
                        ScrollSpreadRight(EventCode);
                |   ScrollSpreadLeftRegion :
                        ScrollSpreadLeft(EventCode); 
                |   ScrollGanttRightRegion :
                        ScrollRight(EventCode);
                |   ScrollGanttLeftRegion :
                        ScrollLeft(EventCode);
                ELSE
                END;
            END;
        END;
    END DispatchMouse;



    PROCEDURE GanttDispatch(    Code        : ACode);

    BEGIN                   (* GanttDispatch *)

    (*$O-*)
        GanttOutline^.Methods^.SetCursorMode(AGanttOutline(GanttOutline), videorestingcursor);
        CASE Code OF
            InsertKey :
                WITH GanttOutline^ DO
                    IF (( LayoutRecord.ColumnSpec[CursorColumn].ColumnID   (* 17-Jul-90 *)
                         = TaskNameColumn ) AND (ScrollingEnabled)) THEN
                        DoTaskInsert( Methods^.AlternateChangeTaskProc );
                    ELSE
                        DoTaskInsert( ChangeTask );
                    END;
                END;

        |   EditKey :
                IF (GanttOutline^.ScrollingEnabled) THEN
                    DoTaskEdit( GanttOutline^.Methods^.AlternateChangeTaskProc );  (* From our methods record. RSC 4/3/89 *)
                ELSE
                    DoTaskEdit( ChangeTask );
                END;
        |   DeleteKey :
                DoTaskDelete();
        |   CopyKey :
                DoTaskCopy();
        |   TaskNotesKey :
                DoTaskNotes();
                GanttOutline^.Methods^.NotifyOfChange(AGanttOutline(GanttOutline));  (* 22-Feb-88 LAA *)

        |   GotoKey :
                DoGotoKey (TaskNameColumn);
        |   GotoWBSKey :
                DoGotoKey (WBSColumn);
        |   ReportsKey :
                IF (ChartRecord^.ColumnCount > 0) THEN
                    DoGotoKey (ChartRecord^.ColumnSpec[GanttOutline^.CursorColumn].ColumnID);
                ELSE
                    DisplayMessage (ModuleNumber+77);    (* "No cursor column" *)
                    PostError( NotPossibleInContextError, ModuleNumber+77 );
                END;

  (* DANGER!  NON-REENTRANT CODE HERE!  DANGER!  *)

        |   EditBigTaskKey :   (* JM 10/14/87 (well, really, RSC) *)
                DoTaskEdit( ChangeTask );                         (* 23-May-89 LAA *)

        |   ReInsertKey    :    (* RSC 4/6/89 ALT-F2 = EditSmallTaskKey *)
                LAdvancedTaskForm := AdvancedTaskForm;
                AdvancedTaskForm  := FALSE;
                DoTaskEdit( ChangeTask );
                AdvancedTaskForm  := LAdvancedTaskForm;


  (* END OF NON-REENTRANT CODE  *)

        END;
        GanttOutline^.Methods^.SetCursorMode(AGanttOutline(GanttOutline),GanttOutline^.VideoMode);
        UnSetState(Showing);
    (*$O=*)

    END GanttDispatch;
    
    (*<ANDREW
        (* DoZoom -- Magnify or shrink the scale of the chart by keeping
                     the same number of things per column, but changing
                     the things to larger or smaller units. *)

    PROCEDURE DoZoom( Bigger : BOOLEAN );
    VAR
        DurationCount : ADurationCounter;
        TempScaleUnit           : ADurationUnit;
        i                       : CARDINAL;
    BEGIN
        IF (GanttOutline^.ScrollingEnabled) THEN
        ELSE
            WITH GanttOutline^.LayoutRecord DO
                TempScaleUnit := scaleunit;
                IF (TempScaleUnit > MIN(ADurationUnit)) THEN
                    DEC(TempScaleUnit);
                END;
                DurationCount := DownScale(scale,TempScaleUnit);
                IF (DurationCount = 0) THEN
                    DurationCount := 1;
                END;
            END;
                (* The scaleunit field in the layout is not necessarily
                   useful for computing the desirable scale, because it
                   represents the intervals of the lower date line, not
                   a display units for the scale.  Compute a useful
                   units for displaying the scale. *)
            (*
            LOOP
                DurationCount := DownScale(TempScale,TempScaleUnit);
                IF (TempScale = NoDuration ) OR (DurationCount > 0) THEN
                    EXIT;
                END;
                DEC(TempScaleUnit);
            END;
            *)
                (* Now change the scale to the same number of a different
                   unit.   We do this MOD the MAX(ADurationUnit) rather
                   than MAX(ADurationUnit) because currently, 12/90, we
                   cannot display one year per column. *)

            i := ORD(TempScaleUnit);
            IF (Bigger) THEN
                DEC(i);
            ELSE
                INC(i);
            END;
            i := i MOD (ORD(MAX(ADurationUnit)));
            TempScaleUnit := VAL(ADurationUnit, i);
            GanttOutline^.LayoutRecord.scale := UpScale(DurationCount,TempScaleUnit);
        END;
      
    
        AdjustLayout( GanttOutline );
        BuildCorrelationList( GanttOutline );
        WITH GanttOutline^ DO
            INCL(Status, NeedsStatusDisplay);
            INCL(Status, NeedsGanttDatesDisplay);
            Methods^.NotifyOfChange(AGanttOutline(GanttOutline)); 
        END;
    END DoZoom;
    ANDREW>*)

    PROCEDURE DoOtherKeys();
    BEGIN
        WITH GanttOutline^ DO
            Methods^.SetCursorMode(AGanttOutline(GanttOutline), videorestingcursor);
            Methods^.Display(AGanttOutline(GanttOutline));
            Dispatch(Event.EventCode);
            INCL(Status, NeedsStatusDisplay);
            UnSetState(Showing);
            Methods^.SetCursorMode(AGanttOutline(GanttOutline), VideoMode);
        END;
    END DoOtherKeys;

(*$O-*)
BEGIN                       (* GanttOutlineActOn *)
    
    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateGanttOutline(AGanttOutline(GanttOutline));
    END;
    (*DEBUGGING>*)

    WITH GanttOutline^ DO
        ErrorMarker := NewMarker();
        WantToRecord := TRUE;

        CursorNode := Methods^.GetCursorNode(AGanttOutline(GanttOutline));
        ChartRecord := CurrentLayout();
        CheckForChangeOnLayout( GanttOutline, ChartRecord );

        IF (Event.EventType = MouseEvent) THEN
            Region := CorrelatePoint( ScreenCorrelList,Event.EventX,
                                      Event.EventY );
            IF ((Region = MenuRegion) AND (MouseDownRegion = MenuRegion)) THEN
                Event.EventCode := OnMenu;
                CancelDoubleClick();                               (* 28-Dec-89 *)
            END;
        END;

            (* Treat / or F10 as a call to the menus. *)                (* AJL 6/Oct/90 *) 

        WITH Methods^ DO
            WHILE (Event.EventCode = OnMenu) OR 
                  (Event.EventCode = ExitKey) DO
                SetCursorMode(AGanttOutline(GanttOutline), videorestingcursor);
                Display(AGanttOutline(GanttOutline));
                FOR i := MenuStart TO MenuEnd DO
                    EraseLn(i);
                END;
                GetMessage(ModuleNumber + 4, s);
                Event.EventCode := SelectAndRunMenu(s,s);
                NotifyOfChange(AGanttOutline(GanttOutline)); 
                UnSetState(Showing);
                SetCursorMode(AGanttOutline(GanttOutline), VideoMode);
                IF (NOT Permission(KeyForAltView, ADR(Event.EventCode))) THEN  (* 27-Feb-88 LAA *)
                    Event.EventCode := CancelKey;
                END;
            END;
        END;

        CASE Event.EventCode OF
            InsertKey, DeleteKey, EditKey, CopyKey, TaskNotesKey,
            JoinKey, UnJoinKey, JoinPartialKey, OpenKey, CloseKey,
            PromoteKey, DemoteKey, MoveUpKey, MoveDownKey, EditBigTaskKey :
                RecordForUndo := TRUE;
        ELSE
            RecordForUndo := FALSE;
        END;

        IF (RecordForUndo) THEN
            NotifyUndo (Task, ChartActive, GanttOutline);
            BeginTransactionSet();
        END;

        IF (Cursor = 0) THEN
            Cursor := 1;
        END;

        Sub := Cursor;
        IF (Event.EventType = MouseEvent) THEN
            IF ((Region = InteriorRegion) 
               AND ((Event.EventCode = MouseDown) OR (MouseDownRegion = InteriorRegion))) THEN
                MouseDownRegion := InteriorRegion;
                Sub := SubviewByPosition( Event.EventX, Event.EventY );
                SubView[Sub]^.Methods^.ActOnEvent(SubView[Sub], Event, 
                                                  ReturnEvent);
            ELSE
                ReturnEvent := Event;
            END;
        ELSE
            SubView[Sub]^.Methods^.ActOnEvent(SubView[Sub], Event, ReturnEvent);
        END;

        IF (ReturnEvent.EventCode <> 0) THEN
            Event := ReturnEvent;
            ReturnEvent.EventCode := 0;

            CASE Event.EventCode OF
                InsertKey, EditKey, DeleteKey, CopyKey, TaskNotesKey,
                EditBigTaskKey, GotoKey, (* ReInsertKey,  5/25/89 EGK *)
                GotoWBSKey, ReportsKey :
                    GanttDispatch(Event.EventCode);

            |   SelectKey :
                    DoBugKey();

            |   PromoteKey :
                    DoPromoteKey();

            |   DemoteKey :
                    DoDemoteKey();

            |   MoveUpKey, MoveDownKey :
                    DoMoveUpAndDownKeys();

            |   OpenKey, CloseKey :
                    DoOpenAndCloseKeys(Event.EventCode);

                (* Undo and set up for redo *)

            |   RedoKey :
                    NotifyUndo (Task, ChartActive, GanttOutline);
                    IF (NOT UndoLastChange(TRUE)) THEN
                        PostError (NotPossibleInContextError, ModuleNumber+8);
                    END;


                (* Undo but don't set up for redo (i.e. undo multiples)  *)

            |   UndoKey :
                    NotifyUndo (Task, ChartActive, GanttOutline);
                    IF (NOT UndoLastChange(FALSE)) THEN
                        PostError (NotPossibleInContextError, ModuleNumber+9);
                    END;

            |   AltUndoKey :
                    DebugUndo();

            |   JoinPartialKey, JoinKey, UnJoinKey :
                    Dispatch(Event.EventCode);
                    INCL(Status, NeedsStatusDisplay);

            (*<ANDREW
            |   ZoomKey:   DoZoom(TRUE);
            |   UnZoomKey: DoZoom(FALSE);
            ANDREW>*)

            |   Tab :
                    WITH LayoutRecord DO
                        IF (ScrollingEnabled) THEN
                            IF (GanttShowing) THEN
                                IF (GanttWidth = 0) THEN
                                    DoColumnScroll(GanttOutline, Fwrd, TRUE);
                                END;
                                ScrollingEnabled := FALSE;
                                Methods^.NotifyOfChange(AGanttOutline(GanttOutline)); 
                            ELSE
                                PostError (NotPossibleInContextError, ModuleNumber+10);
                            END;
                        ELSE
                            IF (ColumnCount > 0) THEN
                                ScrollingEnabled := TRUE;
                                Methods^.NotifyOfChange(AGanttOutline(GanttOutline)); 
                            ELSE
                                PostError (NotPossibleInContextError, ModuleNumber+10);
                            END;
                        END;
                    END;
                    INCL(Status, NeedsStatusDisplay);

            |   RTab :                                            (* 20-Apr-89 LAA *)
                    IF (NOT ScrollingEnabled) THEN
                        IF (LayoutRecord.ColumnCount > 0) THEN
                            ScrollingEnabled := TRUE;
                            Methods^.NotifyOfChange(AGanttOutline(GanttOutline)); 
                        ELSE
                            PostError (NotPossibleInContextError, ModuleNumber+10);
                        END;
                    END;

            |   Fwrd, Reverse :
                    IF (ScrollingEnabled) THEN
                        DoColumnScroll(GanttOutline, Event.EventCode, 
                                       EventHistory[0].EventCode = RepeatKey);
                        INCL(Status, NeedsStatusDisplay);
                    ELSE
                        PostError (NotPossibleInContextError, ModuleNumber+10);
                    END;

            |   RollLeft :
                    DoColumnScroll(GanttOutline, Reverse,
                                   EventHistory[0].EventCode = RepeatKey);
                    IF (NOT ErrorPosted(ErrorMarker)) THEN
                        DoColumnScroll(GanttOutline, Reverse,
                                       EventHistory[0].EventCode = RepeatKey);
                        DoColumnScroll(GanttOutline, Reverse,
                                       EventHistory[0].EventCode = RepeatKey);
                        WHILE (ErrorPosted(ErrorMarker)) DO
                            UnPostError(ErrorMarker, 0);
                        END;
                    END;

            |   RollRight :
                    DoColumnScroll(GanttOutline, Fwrd,
                                   EventHistory[0].EventCode = RepeatKey);
                    IF (NOT ErrorPosted(ErrorMarker)) THEN
                        DoColumnScroll(GanttOutline, Fwrd,
                                       EventHistory[0].EventCode = RepeatKey);
                        DoColumnScroll(GanttOutline, Fwrd,
                                       EventHistory[0].EventCode = RepeatKey);
                        WHILE (ErrorPosted(ErrorMarker)) DO
                            UnPostError(ErrorMarker, 0);
                        END;
                    END;

            |   FileErase, FiltersClear, DsplyKey, ComputeKey, OptionsFormKey, 
                NewProjectKey,
                ResourceFormKey, DaysKey, SelListKey, 
                FileRetrieve, HighListKey, HighList2Key, HighList3Key, 
                DependViewKey, FileFormKey, AnteKey, ReInsertKey, (* 5/25/89 EGK *)
                HelpIndexKey, NetworkKey :                        (* 10-Feb-88 LAA *)
                    DoOtherKeys();

            |   HistKey, HistSynchKey :
                    IF HistogramsAreUp THEN     (* 10-Sep-91 TGS *)
                        ReturnEvent.EventCode := Event.EventCode;
                    ELSE
                        DoOtherKeys();
                    END;

            |  HelpKey :
                    SetString(s,"TM.GANTT");
                    GiveHelp(s,0,GanttWEnd,RestoreTheScreen);

            |   QuitProgram :
                    IF WantToQuit() THEN
                        ReturnEvent.EventCode := QuitProgram;
                    END;

            |   MouseUp, MouseDown, MouseDouble, MouseStillDown :
                    DispatchMouse( Event );

            |   SoundOn, SoundOff : (* 16-Jan-91 TGS *)
                    Dispatch(Event.EventCode);

            ELSE
                WITH GanttOutlineMethodsRecord.SuperclassMethods^ DO
                    ActOnEvent(AnOutlineView(GanttOutline),Event,ReturnEvent);
                END;
                WantToRecord := FALSE;
                INCL(Status, NeedsStatusDisplay);
            END;
        ELSE
            WantToRecord := FALSE;
        END;

        IF (WantToRecord) THEN
            Methods^.RecordEvent(AGanttOutline(GanttOutline), Event);
        END;
        IF (ErrorPosted(ErrorMarker)) THEN
            RespondToErrors(ErrorMarker);
        END;
        PopToMarker(ErrorMarker);
        IF (RecordForUndo) THEN
            NotifyUndo (Task, ChartActive, GanttOutline);
            EndTransactionSet();
        END;

        CursorTask := Methods^.GetCursorNode(AGanttOutline(GanttOutline)); (* RSC 5-Sep-89 *)
    END;
    
END GanttOutlineActOn;
(*$O=*)






PROCEDURE GanttOutlineSetView(    GanttOutline : XGanttOutline;
                                  TypeOfView   : AGanttOutlineViewType);

VAR
    CNode                   : ATreeNode;
    FNode                   : ATreeNode;

BEGIN                       (* GanttOutlineSetView *)

    (*<DEBUGGING*)
    ValidateGanttOutline(AGanttOutline(GanttOutline));
    (*DEBUGGING>*)

    WITH GanttOutline^ DO
        CNode := Methods^.GetCursorNode(AGanttOutline(GanttOutline));
        FNode := Methods^.GetFirst(AGanttOutline(GanttOutline));
        IF (TypeOfView = ActualView) THEN
            InitGanttView(GanttOutline);
        ELSE
            IF (ODD(Lry - Uly + 1)) THEN
                EraseLn(Lry);
            END;
            InitAVPView(GanttOutline);
        END;
        IF (FNode <> NIL) THEN
            Methods^.SetFirst(AGanttOutline(GanttOutline), FNode);
        END;
        IF (CNode <> NIL) THEN
            Methods^.SetCursorNode(AGanttOutline(GanttOutline), CNode);
        END;
        INCL(Status, NeedsRedisplay);
    END;

END GanttOutlineSetView;





(*$O-*)
PROCEDURE GanttOutlineNoteChange(    GanttOutline : XGanttOutline;
                                     Change    : AGanttOutlineSpecificChange);

VAR
    i                       : CARDINAL;

BEGIN                       (* GanttOutlineNoteChange *)

    WITH GanttOutline^ DO
        CASE Change OF
            LayoutChange :
                INCL(Status, NeedsColumnHeadingsDisplay);
        |   GanttDatesChange :
                INCL(Status, NeedsGanttDatesDisplay);
        |   TaskChange :
                INCL(Status, NeedsStatusDisplay);
        |   SubviewsChange :
                FOR i := 1 TO Last DO
                    SubView[i]^.Methods^.NotifyOfChange(SubView[i]);
                END;
        END;
    END;

END GanttOutlineNoteChange;
(*$O=*)



    (*------------------------------------------------------------------------
        Change the vertical height of the Gantt Outline

            Passed us the outline and the new upper and lower bound.

            RSC 12/16/88 changed Height to Upper and Lower Y.

        Preconditions:
            The Gantt Outline must be valid.

        Postconditons:
            The height of the Gantt Outline will be altered as necessary.
            All necessary adjustments for the difference in size will be made.
    ------------------------------------------------------------------------*)

PROCEDURE GanttOutlineResize(    GanttOutline : XGanttOutline;
                                 NewUpperY,
                                 NewLowerY    : ascreeny );

BEGIN                       (* GanttOutlineResize *)

    (*<DEBUGGING*)
    ValidateGanttOutline(AGanttOutline(GanttOutline));
    (*DEBUGGING>*)

    WITH GanttOutline^ DO
        Uly := NewUpperY;
        IF (MousePresent()) THEN                               (* 13-Dec-89 *)
            Lry := NewLowerY - 1;
        ELSE
            Lry := NewLowerY;
        END;
        IF (AVPView) THEN
            GanttOutlineSetView(GanttOutline, ActualAndBaselineView);
        ELSE
            GanttOutlineSetView(GanttOutline, ActualView);
        END;
    END;

END GanttOutlineResize;



PROCEDURE GanttOutlineGetLayout(    GanttOutline : XGanttOutline)
                                                            : AChartFormatPtr;

BEGIN                       (* GanttOutlineGetLayout *)

    (*<DEBUGGING
    ValidateGanttOutline(AGanttOutline(GanttOutline));
    DEBUGGING>*)

    RETURN (ADR(GanttOutline^.LayoutRecord));

END GanttOutlineGetLayout;



PROCEDURE GanttOutlineGetCursor(    GanttOutline  : XGanttOutline): CARDINAL;

BEGIN                       (* GanttOutlineGetCursor *)

    (*<DEBUGGING
    ValidateGanttOutline(AGanttOutline(GanttOutline));
    DEBUGGING>*)

    WITH GanttOutline^ DO                                         (* 20-Apr-89 LAA *)
        RETURN CursorColumn;
    END;

END GanttOutlineGetCursor;



(*$O-*)
PROCEDURE GanttOutlineSetCursor(    GanttOutline   : XGanttOutline;
                                    ColumnToSet    : CARDINAL     );

VAR
    Save                    : CARDINAL;
    ErrorMarker             : AnErrorMarker;

BEGIN                       (* GanttOutlineSetCursor *)

    (*<DEBUGGING
    ValidateGanttOutline(AGanttOutline(GanttOutline));
    DEBUGGING>*)

    IF (ColumnToSet = 1) THEN
        GanttOutline^.CursorColumn := ColumnToSet;
    END;

    Save := GanttOutline^.CursorColumn;

    ErrorMarker := NewMarker();

    IF (ColumnToSet = 1) THEN
        GanttOutline^.CursorColumn := ColumnToSet;
    ELSE
        IF (ColumnToSet > Save) THEN
            REPEAT
                DoColumnScroll(GanttOutline, Fwrd, FALSE);
            UNTIL ((ErrorPosted(ErrorMarker)) 
                  OR (GanttOutline^.CursorColumn = ColumnToSet));
        ELSIF (ColumnToSet < Save) THEN
            REPEAT
                DoColumnScroll(GanttOutline, Reverse, FALSE);
            UNTIL ((ErrorPosted(ErrorMarker)) 
                  OR (GanttOutline^.CursorColumn = ColumnToSet));
        END;

        IF (ErrorPosted(ErrorMarker)) THEN
            GanttOutlineSetCursor(GanttOutline, Save);
        END;
    END;

    WITH GanttOutline^ DO
        IF (Cursor <> 0) THEN                                      (* 13-Dec-89 *)
            SubView[Cursor]^.Methods^.NoteSpecificChange( SubView[Cursor],
                                                          TaskNameChange );
        END;
        INCL(Status, NeedsStatusDisplay);
    END;

    PopToMarker(ErrorMarker);

END GanttOutlineSetCursor;
(*$O=*)



PROCEDURE GanttOutlineGetColumnId(    GanttOutline : XGanttOutline): CARDINAL;

BEGIN                       (* GanttOutlineGetColumnId *)

    (*<DEBUGGING
    ValidateGanttOutline(AGanttOutline(GanttOutline));
    DEBUGGING>*)

    WITH GanttOutline^ DO
        IF (NOT ScrollingEnabled) THEN
            CursorColumn := 1;
        END;

        RETURN LayoutRecord.ColumnSpec[CursorColumn].ColumnID;
    END;

END GanttOutlineGetColumnId;



PROCEDURE GanttOutlineQueryScroll(    GanttOutline : XGanttOutline): BOOLEAN;

BEGIN                       (* GanttOutlineQueryScroll *)

    (*<DEBUGGING
    ValidateGanttOutline(AGanttOutline(GanttOutline));
    DEBUGGING>*)

    WITH GanttOutline^ DO
        RETURN (ScrollingEnabled);
    END;

END GanttOutlineQueryScroll;



PROCEDURE GanttOutlineSetScroll(    GanttOutline : XGanttOutline;
                                    NewMode      : BOOLEAN      );

BEGIN                       (* GanttOutlineSetScroll *)

    (*<DEBUGGING
    ValidateGanttOutline(AGanttOutline(GanttOutline));
    DEBUGGING>*)

    WITH GanttOutline^ DO
        ScrollingEnabled := NewMode;
        Methods^.NotifyOfChange(AGanttOutline(GanttOutline)); 
    END;

END GanttOutlineSetScroll;







PROCEDURE GanttOutlineDefaultChangeProc( CursorNode : ATreeNode ) : BOOLEAN;
BEGIN
    RETURN ChangeTask( CursorNode );
END GanttOutlineDefaultChangeProc;








    (*------------------------------------------------------------------------
        Set the amount of the Gantt chart to show when the Display method is
        called.  If you set ShowTaskStats, the only the top three lines of 
        the screen will be displayed form the Gantt chart.

        Preconditions:
            The Gantt Outline must be valid.

        Postconditons:
            A mode is established which conditions the action of the Display
            method.  This mode will remain in effect until altered by another
            call of this method.
    ------------------------------------------------------------------------*)

PROCEDURE GanttOutlineSetShow(    GanttOutline : XGanttOutline;
                                  Showing      : AGanttOutlineShowing);

BEGIN                       (* GanttOutlineSetShow *)

    WITH GanttOutline^ DO
        WhatShows := Showing;
        INCL(Status, NeedsRedisplay);
    END;

END GanttOutlineSetShow;




(*----------------------------------------------------------------------------
    InitAsGanttOutline --

    Initialize the indicated object as a Gantt outline view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid Gantt outline view object.  No storage 
        allocation is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsGanttOutline(    GanttOutline : AGanttOutline;
                                 SuperView    : AnActiveView;
                                 ChartFormat  : AChartFormatPtr;
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
    PrivateGanttOutline     : XGanttOutline;
    ChartRecord             : AChartFormatPtr;

BEGIN                       (* InitAsGanttOutline *)

    InitAsOutlineView(AnOutlineView(GanttOutline), SuperView, Ulx, Uly, Lrx,
                      Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    PrivateGanttOutline := XGanttOutline(GanttOutline);
    WITH PrivateGanttOutline^ DO
        Methods := ADR(GanttOutlineMethodsRecord);
        PreviousChartStartDay := 0;
        WhatShows := ShowEverything;
        ChartRecord := CurrentLayout();
        LayoutRecord := ChartRecord^;                             (* 29-Dec-88 LAA *)
        CursorColumn := 1;
        WITH LayoutRecord DO                                      (* 04-May-89 LAA *)
            WHILE ((CursorColumn <= ColumnCount) 
               AND (ColumnSpec[CursorColumn].Width = 0)) DO
                INC(CursorColumn);
            END;
            IF (CursorColumn > ColumnCount) THEN
                CursorColumn := 1;
            END;
        END;
        AdjustLayout( PrivateGanttOutline );
        ScrollingEnabled := TRUE;
        LayoutChecksum := 0;                                   (* 18-Jan-90 *)
        ScreenCorrelList := ACorrelationList(NIL);
        IF (LayoutRecord.AVPShowing) THEN
            InitAVPView(PrivateGanttOutline);
        ELSE
            InitGanttView(PrivateGanttOutline);
        END;
    END;

END InitAsGanttOutline;







(*----------------------------------------------------------------------------
    CreateGanttOutline --

    Allocate storage for, and initialize the indicated object as a Gantt
    outline view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid Gantt outline view object, and 
        TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateGanttOutline(VAR GanttOutline : AGanttOutline;
                                 SuperView    : AnActiveView;
                                 ChartFormat  : AChartFormatPtr;
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

BEGIN                       (* CreateGanttOutline *)

    IF (HeapAvailable()) THEN
        ALLOCATE(GanttOutline, TSIZE(XGanttOutlineRecord));
        InitAsGanttOutline(GanttOutline, SuperView, ChartFormat, Ulx, Uly, 
                           Lrx, Lry, Box, VideoMode, Title, HelpKey, 
                           TakeRug);

        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateGanttOutline;







(*----------------------------------------------------------------------------
    UnInitAsGanttOutline --

    UnInitialize the indicated object as a Gantt outline view.

    Preconditions:
        The object will be a valid Gantt outline view object. 

    Postconditions:
        The Gantt outline view will be invalidated.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsGanttOutline(    GanttOutline : AGanttOutline);

VAR
    PrivateGanttOutline     : XGanttOutline;

BEGIN                       (* UnInitAsGanttOutline *)

    PrivateGanttOutline := XGanttOutline(GanttOutline);
    DiscardSubViews(XGanttOutline(GanttOutline));
    DisposeCorrelationList( PrivateGanttOutline^.ScreenCorrelList );
    UnInitAsOutlineView(AnOutlineView(GanttOutline));

END UnInitAsGanttOutline;







(*----------------------------------------------------------------------------
    CloneGanttOutlineMethods --

    Make a copy of the Gantt outline view methods into the indicated method 
    object.

    Preconditions:
        None.

    Postcondition:
        The Gantt outline view methods will be copied into the indicated 
        method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneGanttOutlineMethods(    MethodObject : AGanttOutlineMethods);

BEGIN                       (* CloneGanttOutlineMethods *)

    MethodObject^ := GanttOutlineMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(GanttOutlineMethodsRecord);

END CloneGanttOutlineMethods;







(*----------------------------------------------------------------------------
    ValidateGanttOutline --

    Determine that the indicated object is in fact a valid Gantt outline view 
    object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid Gantt outline view object, FatalError 
        will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateGanttOutline(    GanttOutline : AGanttOutline);

VAR
    PrivateGanttOutline     : XGanttOutline;

BEGIN                       (* ValidateGanttOutline *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(GanttOutline));
    END;
    DEBUGGING>*)

    PrivateGanttOutline := XGanttOutline(GanttOutline);
    IF (PrivateGanttOutline^.Methods^.GanttOutlineTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateGanttOutline;


BEGIN                       (* GanttOutlines *)

    CloneOutlineViewMethods(ADR(GanttOutlineMethodsRecord));
    WITH GanttOutlineMethodsRecord DO
        MethodSize         := TSIZE(AGanttOutlineMethodsRecord);
        Discard            := AGanttOutlineDiscardProc(GanttOutlineDiscard);
        Display            := AGanttOutlineProc(GanttOutlineDisplay);
        ActOnEvent         := AGanttOutlineActOnProc(GanttOutlineActOn);
        SetTypeOfView      := AGanttOutlineSetViewProc(GanttOutlineSetView);
        NoteSpecificChange := AGanttOutlineNoteProc(GanttOutlineNoteChange);
        SetShowing         := AGanttOutlineShowingProc(GanttOutlineSetShow);
        ChangeHeight       := AGanttOutlineResizeProc(GanttOutlineResize);
        GetLayout          := AGanttOutlineLayoutProc(GanttOutlineGetLayout);
        GetCursorColumn    := AGanttOutlineGetCountProc(GanttOutlineGetCursor);
        GetColumnId        := AGanttOutlineGetCountProc(GanttOutlineGetColumnId);
        QueryScrollMode    := AGanttOutlineGetCursorProc(GanttOutlineQueryScroll);
        SetScrollMode      := AGanttOutlineSetCursorProc(GanttOutlineSetScroll);
        AlternateChangeTaskProc := GanttOutlineDefaultChangeProc;
        SetCursorColumn    := AGanttOutlineSetCursProc(GanttOutlineSetCursor);
        GanttOutlineTag    := ModuleNumber;
    END;

END GanttOutlines.


        03-Oct-87 LAA   Erase the lines where menu will go before putting up
                        the menu.
         9-Oct-87 RSC   Changed DateAsEndOfPeriod to FormatAsDateStyle.
                        Added MessageWithPriority to clear message after
                        Join key pressed.
        14-Oct-87 JM/MD Added the EditBigTaskKey procedure in GanttDispatch.
                        (well..... RSC did this) 
                        Added Start Status to the summary line.
                        Added shadows to boxes.  Added param to EditText.
        28-Oct-87 LAA   In the display proc, changed computation order to
                        avoid arithmetic overflow.
        03-Nov-87 LAA   Tried to correct a problem where the width of the
                        Gantt bars region of the screen is less than the
                        width between key dates for the established scale.
        25-Nov-87 LAA   Cleaned up codes passed to Dispatch to only those
                        necessary.
        01-Dec-87 LAA   Fixed my clean-up, which broke the retrieve dammit
                        function.
        10-Dec-87 LAA   Incorporated LockFlexStorDataObject method.
        18-Dec-87 LAA   Added new method, ChangeHeight, to resize the chart.
        29-Dec-87 LAA   Prohibit demotion of a task under one which summarizes
                        another schedule.  Removed all the caching overhead.
        30-Dec-87 LAA   Don't scroll the Gantt chart up so that the cursor
                        task is visible while on the task form.
        11-Jan-88 LAA   Changed UnlockFlexStorDataObject to UnlockUnchanged
                        where it was appropriate.
        15-Jan-88 LAA   Go to RestingCursor when editing a task, even though
                        the screen doesn't scroll.
        05-Feb-88 LAA   Changed the definition of GetColumnInfo.
        10-Feb-88 LAA   Allow NetworkKey to bring up the network.  Made the
                        Shift-F2 editor window two charaters wider.  Task copy
                        no longer copies the baseline.
        12-Feb-88 LAA   Clear the BaseLineExists flag from task set upon copy.
                        Clear odd line at end of AVP display.
        17-Feb-88 LAA   Only clear the odd line if AVP showing.
        21-Feb-88 LAA   Don't hard-code position of resources on summary line.
        22-Feb-88 LAA   Use FormatLongDuration on the summary line.
                        Fixed bug of task notes not being displayed after
                        using ShiftF2 to edit.  Also fixed bug of phantom
                        message when trying to join two tasks which are 
                        already joined.
        23-Feb-88 LAA   Make P and S behave the same on Copy as Insert.
        25-Feb-88 LAA   Added notice of KeyForAltView for the network view.
                        Fixed ShowStats for duration display.  Changed 
                        parameters to FormatLongDuration.
        27-Feb-88 LAA   Changed SendNotice to Permission, so the Network View
                        would have the opportunity to disallow a function
                        chosen from the main menu (provided it returns a code
                        instead of running an overlay directly).
        29-Feb-88 LAA   Removed processing of AlternateDisplayKey, so that it
                        will be returned to the NetworkView (if it's active).
        01-Mar-88 LAA   Changed the width of the duration number so there's
                        room to format up the largest number we expect.
        15-Sep-88 WKH   Set ScheduleSaved to FALSE if any editing changes are
                        detected in DoTaskNotes.
        03-Oct-88 RSC   Removed ScrollBack and ScrollForward.
        28-Nov-88 AJL   Changed the duration formatting for the readout lines
                        so that it will be sensitive to international number
                        rules.
         1-Dec-88 AJL   Changed the duration formatting again so that it uses
                        MinDigits of 0 instead of a complicated scan for the
                        radix character followed by a zero.  
        16-Dec-88 RSC   Made the "ChangeHeight" method accept upper and lower y.
        21-Dec-88 LAA   Changed imports for Laslo reorganization.
        22-Dec-88 LAA   The string field of AColumnDataRecord was changed from
                        being called String to StringValue.
        28-Dec-88 LAA   Made changes to allow scrolling of the data columns
                        on the Gantt chart.
        03-Jan-88 LAA   Called AdjustedGanttLayout after any potential change
                        of the current layout, and put a check into 
                        CursorColumnOnScreen for column 1, which is special.
        09-Jan-88 LAA   Yet another approach to scrolling columns.
        04-Feb-89 LAA   Brought back into sync with version on N:  Fixed 
                        problems with reverse scrolling and changing layouts.
                        Added new method to provide the number of the cursor
                        column, and the "magic number" used by Captions.
        18-Feb-89 LAA   Added new methods to query and set the scrolling mode,
                        and moved ShowStats proc to Chart, making it a
                        procedure variable so it can be stolen.
        22-Feb-89 LAA   More on Scrolling Gantt columns.
         3-Mar-89 LAA   Commented out the key to switch back to non-scrolling
                        task table columns.  Left and Right arrow keys now only
                        move the task table cursor; they no longer affect the
                        Gantt bars region at all.
        13-Mar-89 LAA   Added feature to scrolling Gantt such that the repeat
                        key "*" followed by right arrow scroll the task table
                        cursor to the last column, and the repeat key followed
                        by the left arrow key scrolls it to the first column.
        27-Mar-89 LAA   Changed the key which scrolls the task table portion of
                        the Gantt chart back to Tab and BackTab, for purposes
                        of testing whether people like this better that use of
                        right an left arrow keys.
        28-Mar-89 LAA   Changed the Scrolling Gantt to using a mode toggled
                        by the Tab key.  If you're scrolling the task table
                        region, you can't move the bars cursor and vice versa,
                        since they're both moved by the arrow keys.  Moved
                        the decoding of Ctrl-Home and Ctrl-End to the 
                        GanttViews module, so they will be sensitive to whether
                        scrolling on the task table portion is enabled or
                        not.
         3-Apr-89 RSC   Added hooks for the SpreadSheet view, including the
                        method, "AlternateChangeTaskProc".
         7-Apr-89 RSC   Fixed a bug introduced 3-Apr-89 by me where ESC from
                        the task form crashed Time Line when there was no
                        cursor task.  This was an update to the way
                        "DisplayStats" was called.
        13-Apr-89 LAA   Added Ctrl-left and Ctrl-right as active keys when on
                        the task table portion of the Gantt chart.  They will
                        scroll 3 columns in either direction.
        14-Apr-89 EGK   Changed DoTaskCopy to use the new AddTaskCopy
                        procedure in Changer, which allows summary tasks
                        to be copied.
        20-Apr-89 LAA   Ed, what are you doing in my module????  Well, I was
                        just in here putting in the backtab key as a way to
                        force the cursor over to the task table region.  I 
                        also changed the criteria by which we prohibit moving
                        the cursor onto the task table side, so it'll work 
                        if you have at least one column.
                        Congrats on the task copy stuff.  It'll be great!
                        Also fixed a bug with the GetCursorColumn method.
        27-Apr-89 EGK   Ha ha!  I'm in here again!  Added support for two
                        new go-to lists, one for WBS (Shift-F5) and the
                        other for whatever the Gantt cursor column is
                        (Ctrl-F5).
        01-May-89 LAA   Attempted to allow scrolling onto the screen from the
                        right even if the column coming in is too wide to
                        fit.  Did this by reducing the width of the column so
                        it's just small enought to fit on the screen.  This
                        is just a first cut; there are probably cases where
                        it doesn't work.
        03-May-89 LAA   Fixed bug with May 1 change which resulted in loosing
                        the task table cursor if a very large column was 
                        squeezed down to zero width, and later expanded back
                        so it would come onto the screen from the left.
        04-May-89 LAA   Fixed a bug: if the first column was specified in the
                        layout with a width of zero, there'd be no task table
                        cursor althought you you still edit that column.
                        Credit to Roger for finding this one.  
                        Also enabled more stringent checking in the Display
                        procedure after Ed and I looked at a bug which 
                        seemed to be in histograms, but which I think is 
                        really a GanttOutline bug.
        08-May-89 LAA   If the Tab key is pressed, in order to move over to
                        the Gantt bars region, AND the Gantt bars region is
                        enabled, BUT it's not on-screen, then a REPEAT-right
                        arrow functions will be performed before the Tab key
                        takes effect.  To support this, a REPEAT parameter
                        has been added to DoColumnScroll.
        23-May-89 LAA   Changed the action of Ctrl-F2 so it will always bring
                        up the default task form, rather than the Large task
                        form.  Thus Ctrl-F2 is a sure way to get to the task
                        form, even is Spreadsheet editing is in effect.
        25-May-89 EGK   Pass ALT-F2 (ReInsertKey) to Dispatch, allowing
                        journal notes to be brought up using a menu action.
         4-Jun-89 EGK   Changed NotifyUndo calls into SendNotices calls.
        05-Jun-89 KKC   Set SortOrderManuallyAltered to TRUE for DoTaskInsert
                        and DoTaskCopy.
        10-Jun-89 WKH   Added support for variable screen rows.
        13-Jul-89 EGK   Changed "PrjtNotesKey" to "GotoWBSKey".
        14-Jul-89 EGK   Changed OkToDemote so that it actually puts up the
                        error boxes, allowing us to put up different
                        messages for the two cases where demoting is not
                        allowed.
        10-Aug-89 EGK   Moved WantToQuit from TLMain to here, so we can
                        ask the user whether they REALLY want to quit,
                        without making them exit any alternate views.
        14-Aug-89 RSC   Only resynch current layout's ScrollingMode if
                        we are displaying the Gantt.  This fixes a bug
                        where changing the calendar precision caused the
                        spreadsheet editor to pop up instead of the task form.
                        When the current Gantt layout had no gantt bars
                        showing.  Hows that for weird?
         5-Sep-89 RSC   Moved the setting of "CursorTask" here from TLMain.
                        In the ActOnEvent proc.
         6-Sep-89 RSC   Set the status for needing stats line display on an
                        open or close key.  Fixes bug # 1118.
        12-Sep-89 WKH   make goto boxes bigger for compressed video mode
        14-Sep-89 EGK   Removed SetLineAboveForm procedure, since the gantt
                        chart no longer scrolls around when forms come up.
                        Changed ULY parameter to EditText to use a constant
                        instead.
        19-Sep-89 WKH   Disallow demotion of a task that is going to become
                        the child of a done or started detail task
                        Also moved over code from Goto that didn't belong there.
        25-Sep-89 EGK   Check to see whether the task is actually a summary
                        before sending out OpenATask or CloseATask notices.
        25-Sep-89 LAA   Don't checksum the portion of a layout which will
                        change because of a file save, i.e. the id number.
                        This was causing the spreadsheet area to scroll back
                        to column 1 when it shouldn't.
        28-Sep-89 WKH   Related to fix dated 19-Sep-89.  We were not allowing
                        the addition of tasks to a task that was already
                        a summary.  So we don't allow the demotion of a task
                        if it's potential parent task is either started or
                        done, unless of course the potential parent is 
                        already a summary task!!!  This is the final fix
                        to The Bug That Wouldn't Die!!!!(#642)
        03-Nov-89 EGK   Enhanced my fix of 25-Sep-89 so that if we're on a
                        detail task but we're opening or closing the whole
                        outline, we'll still send notices.
        08-Nov-89 EGK   In GotoCheckProc, replaced incorrect use of
                        ModuleNumber+81 (which was already used) to
                        ModuleNumber+82.  Obviously, this required a new
                        phrase # 17582.
        15-Nov-89 EGK/RSC  Removed import of RealFormat to save space.
        06-Dec-89 EGK   In GoToCheckProc, added code to send "OpenATask"
                        notices if a closed-off task is picked.
        11-Dec-89 LAA   Removed references to maxcol which should have been
                        to the view width.  Removed all the old, commented-out
                        code having to do with caching.  Added support for a
                        mouse.
        27-Dec-89 LAA   Added MouseDownRegion to the object record definition,
                        so we can limit mouse actions to the screen region on 
                        which the mouse button was originally pressed.
        28-Dec-89 LAA   Cancel double-clicks when we bring up the menu.






