IMPLEMENTATION MODULE AVPViews;          (* A subclass of GanttViews *)

    (*  MODIFICATION HISTORY
        07-Jan-88 LAA   Initialize CursorMode here because of a compiler
                        problem.  It's initialized in InitAsActiveView, but
                        get's garbaged along the way.  Also put in a previous
                        change to GanttViews so that ViewObjects which are
                        nil are not dereferenced (for SetMode calls).
        11-Jan-88 LAA   Changed UnlockFlexStor to UnlockUnchanged method.
        17-Feb-88 LAA   Changed use of HeapAvailable to Available since we
                        do want to be able to change from Gantt to AVP even
                        if low on memory.  Also imported ALLOCATE and
                        DEALLOCATE from Space.
        21-Feb-88 LAA   Put in new scheme for display of cursor date and got
                        bug characters from the phrases file.
        22-Feb-88 LAA   Put in PressSlashMessage.
        25-Feb-88 LAA   Messed with cursor date display (again).
        27-Feb-88 LAA   Fixed bug with press slash message being displayed
                        twice.
        21-Dec-88 LAA   Changed imports for Laslo reorganization.
        06-Feb-89 LAA   Made changes ala GanttView for showing the current
                        cursor column.
         3-Mar-89 LAA   Put in more changes for the scrolling task table
                        columns, and changes to usage of keys ala GanttView.
         6-Mar-89 LAA   Brought structure of Display portions of GanttViews
                        and AVPViews into more close alignment.
        13-Mar-89 LAA   Display the Gantt cursor even if scrolling Gantt
                        columns are enabled.
        22-Mar-89 EGK   Changed MakeBars to use new "percent" parameter in
                        GanttLine, and to get the percentage column from
                        Captions.  Put back code to initialize TTaskFlags.
        23-Mar-89 LAA   Removed some commented out code.  Fixed bug causing
                        sporadic display of the baseline.
        27-Mar-89 LAA   Removed an unnecessary import of Keys.
        18-Apr-89 LAA   Merged changes from GanttView of 12-Apr-89.  Made use
                        of PutStringWithColors so that the Gantt cursor will
                        take on filter colors as it passes over the relevant
                        tasks.
        12-Dec-89 LAA   Put in support for mouse, removed all references to
                        Caching.
        02-Jan-89 LAA   Oops.  Forgot to handle the cursor.  Using the code
                        of GanttViews as a prototype, I put in the changes
                        for eliminating extraneous cursors left on the screen
                        when the mouse moves.
        10-Jan-90 LAA   Fixed a bug in DisplayCursor, which occured because
                        I'd named a parameter (VideoMode) the same name as a
                        field in GanttViews, and used it in a WITH statement.
                        This caused the cursor to display in the wrong color.
                        This fix was made to GanttViews on 5-Jan-90.  Oops.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
         8-Jun-90 MWP   Fixed a bug in DisplayCursor, which was causing the
                        baseline cursor to be displayed with the display
                        character of the actuals line.
         9-Nov-90 TGS   Integrate changes from 4.03.
        25-Jan-91 RSC   Update for new GanttLine and FormatTaskColumns
                        procedures.
    *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ATaskFlag, ATaskFilter,
                                ATaskFlagSet, ATaskFilterSet,
    (* PROC *)                  CheckTaskValid;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Captions               IMPORT
    (* PROC *)                  ResourceNameList, FormatTaskColumns,
                                GetColumnPercentage;

FROM Chart                  IMPORT
    (* VAR *)                   ChartStartDay, CursorDay, BugTaskA, BugTaskB;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr, AChartFormat, CurrentLayout;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error, Burp, MessageWithPriority,
                                NotYetImplemented, MessagePriority,
                                SetMessagePriority;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM Gantt                  IMPORT
    (* TYPE *)                  ASlackStyle, AGanttLineType, AGanttFont,
    (* VAR *)                   ChartFont, SummaryFont,
                                BaselineDetailFont, BaselineSummaryFont,
    (* PROC *)                  GanttLine, SetGanttLineTask;

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineSpecificChange, AGanttOutline;

FROM GanttViews            IMPORT
    (* TYPE *)                  AGanttViewMethods, AGanttView,
    (* VAR *)                   DisplayedCursorDate,
    (* PROC *)                  InitAsGanttView, UnInitAsGanttView,
                                ValidateGanttView, CloneGanttViewMethods;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol,
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString, KeyPress, PutAttribute, PutColors,
                                PutStringWithColors;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, ConcatLS, Copy, LengthOf, SetLengthOf,
                                Overlay, SetString, Procustes, ConcatS, Insert;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject, AnObjectMethods;

FROM ObjectViews            IMPORT
    (* TYPE *)                  AnObjectView;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TimeFormat             IMPORT
    (* PROC *)                  DtoS, CtoDay;

FROM TimeJump               IMPORT
    (* PROC *)                  FindPriorKeyDate, FindNextKeyDate;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate, ATimeInfo,
    (* PROC *)                  TimeUtoT, DayOfWeek;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;



CONST
    ModuleNumber            = 17900;
    LeftArrow               = 33C;
    RightArrow              = 32C;

TYPE
    XAVPView              = POINTER TO XAVPViewRecord;

    XAVPViewRecord        = RECORD
                                Methods      : AnAVPViewMethods;
                                ViewObject   : ATreeNode;
                                ParentView   : AGanttOutline;
                                Ulx          : ascreenx;
                                Uly          : ascreeny;
                                Lrx          : ascreenx;
                                Lry          : ascreeny;
                                Box          : ABoxType;
                                VideoMode    : avidmode;
                                Title        : ARRAY [0..40] OF CHAR;
                                HelpNumber   : CARDINAL;
                                Rug          : ARug;
                                Status       : AnAVPViewStatusSet;
                                EventHistory : ARRAY [0..10] OF AnEvent;
                                CursorMode   : avidmode;
                                    (*  GanttView fields  *)
                                CharUnderCursor : CHAR;
                                ViewCursorDay: ADate;
                            END;


    AnAVPViewDiscardProc = PROCEDURE (VAR AnAVPView   );

    AnAVPViewDisplayProc = PROCEDURE (    AnAVPView   );


VAR
    AVPViewMethodsRecord    : AnAVPViewMethodsRecord;
    BugALetter              : CHAR;
    BugBLetter              : CHAR;
    SeperatorChar           : CHAR;
    GlobalInitialized       : BOOLEAN;
    PressSlashMessage       : ARRAY [0..31] OF CHAR;




PROCEDURE AVPViewDiscard(VAR AVPView    : XAVPView);

BEGIN                       (* AVPViewDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateAVPView(AnAVPView(AVPView));
    END;
    DEBUGGING*)

    UnInitAsAVPView(AnAVPView(AVPView));
    DISPOSE(AVPView);

END AVPViewDiscard;





PROCEDURE AVPViewDisplay(    AVPView    : XAVPView);

VAR
    TaskPtr                 : ATaskPtr;
    FirstGantt              : CARDINAL;
    i                       : CARDINAL;
    x                       : CARDINAL;
    CursorColumn            : CARDINAL;
    ViewWidth               : CARDINAL;
    ChartRecord             : AChartFormatPtr;
    TTaskFlags              : ATaskFlagSet;
    mode                    : avidmode;
    cmode                   : avidmode;
    tablemode               : avidmode;
    barmode                 : avidmode;
    Seperator               : ARRAY [0..1] OF CHAR;
    BugIndicator            : ARRAY [0..1] OF CHAR;
    Bars                    : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    Name                    : ARRAY [0..80] OF CHAR;
    s2                      : ARRAY [0..1] OF CHAR;
    GanttOnScreen           : BOOLEAN;
    PreambleDone            : BOOLEAN;
    ScrollEnabled           : BOOLEAN;
    TaskIsLocked            : BOOLEAN;


    PROCEDURE DisplayCursorDate(   ShowDate : BOOLEAN);           (* 25-Feb-88 LAA *)

    CONST
        SlashPosition           = 50;
        SlashWidth              = maxcol + 1 - SlashPosition;

    VAR
        TimeInfo                : ATimeInfo;
        DateString              : ARRAY [0..81] OF CHAR;
        s                       : ARRAY [0..81] OF CHAR;

    BEGIN                       (* DisplayCursorDate *)

        IF (KeyPress()) THEN RETURN END;

        WITH AVPView^ DO WITH TimeInfo DO
            WITH ChartRecord^ DO
                IF ((CursorDay <> DisplayedCursorDate)
                   OR (MessagePriority() = 0)) THEN               (* 21-Feb-88 LAA *)
                    SetLengthOf(DateString, 0);                   (* 25-Feb-88 LAA *)
                    IF (ShowDate) THEN
                        TimeUtoT(CursorDay,TimeInfo);(* 25-Feb-88 LAA *)
                        CtoDay(DayOfWeek(tiYear,tiMonth,tiDay), DateString);(* 22-Feb-88 LAA *)
                        Procustes(DateString, 17);
                        DtoS(TimeInfo,s);
                        Procustes(s, 17);
                        ConcatLS(DateString, s);
                    END;
                    Procustes(DateString, maxcol + 1);
                    Overlay(DateString, PressSlashMessage, SlashPosition,
                            SlashWidth);
                    IF (MessagePriority() > 1) THEN
                        SetMessagePriority(1);
                    END;
                    MessageWithPriority(DateString, 1);
                    DisplayedCursorDate := CursorDay;             (* 19-Feb-88 LAA *)
                END;
            END;
        END; END;

    END DisplayCursorDate;




    PROCEDURE SendColumnSeparators(    ShowCursorCol : BOOLEAN);

    VAR
        x                   : CARDINAL;
        i                   : CARDINAL;

    BEGIN                   (* SendColumnSeparators *)

        WITH ChartRecord^ DO
            FOR i := 1 TO ColumnCount DO
                WITH ColumnSpec[i] DO                             (* 12-Apr-89 LAA *)
                    IF (Width > 0) THEN
                        x := Position + Width-1;
                        IF (x >= FirstGantt) THEN
                            RETURN;
                        END;
                        WITH AVPView^ DO
                            IF ((i = CursorColumn) AND (ShowCursorCol)) THEN
                                PutAttribute(Ulx+Position, Uly, Width-1, cmode);       (* 04-Feb-89 LAA *)
                                PutAttribute(Ulx+Position, Uly+1,Width-1, cmode);    (* 04-Feb-89 LAA *)
                            END;
                            PutAttribute(Ulx + x, Uly, 1, videonormal);
                            PutAttribute(Ulx + x, Uly + 1, 1, videonormal);
                        END;
                    END;
                END;
            END;
        END;

    END SendColumnSeparators;





    PROCEDURE MakeGanttLine (LineType           : AGanttLineType;
                             HasBaseline        : BOOLEAN;
                             VAR s              : ARRAY OF CHAR  );

    VAR
        Percentage          : CARDINAL;
        Font                : AGanttFont;
        Started             : BOOLEAN;
        Continues           : BOOLEAN;

    BEGIN

        WITH AVPView^ DO
            IF ((ViewObject = NIL)
                OR ((LineType = Baseline) AND (NOT HasBaseline))) THEN
                MakeEmptyGanttLine( s );
                RETURN;
            END;

            IF (LineType = Plan) THEN
                IF (ViewObject^.Methods^.GetSubtree (ViewObject) = NIL) THEN
                    Font := ChartFont;
                ELSE
                    Font := SummaryFont;
                END;
            ELSE
                IF (ViewObject^.Methods^.GetSubtree (ViewObject) = NIL) THEN
                    Font := BaselineDetailFont;
                ELSE
                    Font := BaselineSummaryFont;
                END;
            END;

            WITH ChartRecord^ DO
                Percentage := 0;
                IF (ProgressLineType = LineType) THEN
                    IF (NOT GetColumnPercentage (ViewObject, TaskPtr,
                            ProgressColumnID, LineType, Percentage)) THEN
                        Percentage := 0;
                    END;
                END;
                SetGanttLineTask( ViewObject, TaskPtr );    (* 25-Jan-91 RSC  *)
                GanttLine(ViewObject, LineType, ChartStartDay, AsOfDate,
                          Percentage, GanttWidth, 1, scale, slackstyle,
                          Font, s, Started, Continues);
            END;

            IF (Started) THEN
                s[1] := LeftArrow;
            END;
            IF (Continues) THEN
                s[ViewWidth - FirstGantt + 1] := RightArrow;
            END;
        END;

    END MakeGanttLine;



    PROCEDURE MakeEmptyGanttLine    (   VAR s   : ARRAY OF CHAR );

    VAR
        i       : CARDINAL;

    BEGIN

        WITH AVPView^ DO
            Fill(s, " ", ViewWidth + 1 - FirstGantt);
            IF (AsOfDate >= ChartStartDay) THEN
                i := (AsOfDate - ChartStartDay) DIV ChartRecord^.scale;
                IF (i < LengthOf(s)) THEN
                    s[i + 1] := ChartFont[9];
                END;
            END;
        END;

    END MakeEmptyGanttLine;



    PROCEDURE DisplayCursor(    CursorDate  : ADate;
                                CursorChar  : CHAR;
                                y           : ascreeny;
                                LCursorMode : avidmode);

    VAR
        i                   : CARDINAL;
        Cur                 : ARRAY [0..10] OF CHAR;              (* 8-Jun-90 MWP *)

    BEGIN                   (* DisplayCursor *)

        WITH AVPView^ DO
            i := (CursorDate - ChartStartDay) DIV ChartRecord^.scale;
            IF (i < ChartRecord^.GanttWidth) THEN                 (* 8-Jun-90 MWP *)
                SetString(Cur, CursorChar);                       (* 8-Jun-90 MWP *)
                PutString(Cur, Ulx + FirstGantt + i, y, LCursorMode);
            END;
        END;

    END DisplayCursor;



    PROCEDURE DoPreamble();

    VAR
        s                   : ARRAY [0..255] OF CHAR;

    BEGIN                   (* DoPreamble *)

        IF (NOT PreambleDone) THEN
            WITH AVPView^ DO
                    (*  Doesn't count column for bugs  *)
                ViewWidth := Lrx - Ulx;

                ChartRecord := ParentView^.Methods^.GetLayout(ParentView);  (* 30-Dec-88 LAA *)
                WITH ChartRecord^ DO
                    IF ((GanttWidth > 0) AND (GanttShowing)) THEN
                        FirstGantt := GanttPosition;
                        GanttOnScreen := TRUE;
                    ELSE
                        FirstGantt := ViewWidth + 1;
                        GanttOnScreen := FALSE;
                    END;
                END;

                mode := VideoMode;
                IF (ViewObject <> NIL) THEN
                    TaskPtr := ViewObject^.Methods^.LockFlexStorDataObject(ViewObject);  (* 10-Dec-87 LAA *)
                    TaskIsLocked := TRUE;
                    IF (Highlight1 IN TaskPtr^.FilterSet) THEN
                        mode := videofilter1;
                    ELSIF (Highlight2 IN TaskPtr^.FilterSet) THEN
                        mode := videofilter2;
                    ELSIF (Highlight3 IN TaskPtr^.FilterSet) THEN
                        mode := videofilter3;
                    ELSIF (Highlight4 IN TaskPtr^.FilterSet) THEN
                        mode := videofilter4;
                    ELSIF (Highlight5 IN TaskPtr^.FilterSet) THEN
                        mode := videofilter5;
                    END;
                    TTaskFlags := TaskPtr^.TaskFlags;             (* 23-Mar-89 LAA *)
                END;

                ScrollEnabled := ParentView^.Methods^.QueryScrollMode(ParentView);

                cmode     := mode;
                tablemode := mode;
                barmode   := mode;
                IF (CursorOn IN Status) THEN
                    IF (CursorMode <> VideoMode) THEN  (* highlight filter in effect *)
                        cmode := CursorMode;
                    ELSE
                        INC(cmode);
                    END;
                    tablemode := videosecondarycursor;
                    IF (ScrollEnabled) THEN
                        barmode := tablemode;
                    ELSE
                        barmode := cmode;
                    END;
                END;

                CursorColumn := ParentView^.Methods^.GetCursorColumn(ParentView);  (* 04-Feb-89 LAA *)

                PreambleDone := TRUE;
            END;
        END;

    END DoPreamble;



BEGIN                       (* AVPViewDisplay *)

    TaskIsLocked := FALSE;

    WITH AVPView^ DO
        IF (NeedsRedisplay IN Status) THEN
            INCL(Status, NeedsTaskNameDisplay);
            INCL(Status, NeedsBugsDisplay);
            INCL(Status, NeedsGanttBarDisplay);
            INCL(Status, NeedsGanttCursorDisplay);
            EXCL(Status, NeedsRedisplay);
        END;

        PreambleDone := FALSE;
        IF (NeedsTaskNameDisplay IN Status) THEN
            DoPreamble();
            IF (ViewObject = NIL) THEN
                IF (FirstGantt > 1) THEN
                    Fill(s, " ", FirstGantt - 2);
                    PutStringWithColors(s, Ulx + 1, Uly, mode, tablemode);  (* 18-Apr-89 LAA *)
                    PutStringWithColors(s, Ulx + 1, Uly + 1, mode, tablemode);
                        (* X pos: Ulx + 1 + ((FirstGantt - 1) - 1)  *)
                    Fill(Seperator, SeperatorChar, 1);
                    PutString(Seperator, Ulx+FirstGantt-1, Uly, videonormal);
                    PutString(Seperator, Ulx+FirstGantt-1, Uly + 1, videonormal);
                END;
            ELSE
                    (*  Format and print columnar data  *)
                FormatTaskColumns(ViewObject,TaskPtr,Plan,ChartRecord^,FirstGantt-1,s);
                PutStringWithColors(s, Ulx + 1, Uly, mode, tablemode);       (* 18-Apr-89 LAA *)
                IF (BaseLineExists IN TTaskFlags) THEN
                    FormatTaskColumns(ViewObject,TaskPtr,Baseline,ChartRecord^,
                                      FirstGantt-1,s);
                ELSE
                    Fill (s, " ", FirstGantt-1);
                END;
                PutStringWithColors(s, Ulx + 1, Uly + 1, mode, tablemode);   (* 18-Apr-89 LAA *)

                IF (tablemode <> videonormal) THEN
                    SendColumnSeparators(ScrollEnabled);
                END;
            END;
            EXCL(Status, NeedsTaskNameDisplay);
        END;

        IF (NeedsBugsDisplay IN Status) THEN
            DoPreamble();
            SetString(BugIndicator, " ");
            PutString (BugIndicator, Ulx, Uly + 1, videodatebar);
            IF (ViewObject <> NIL) THEN
                    (*  Overwrite first char with bug, in reverse video  *)
                IF (ViewObject = BugTaskA) THEN
                    SetString(BugIndicator, BugALetter);
                ELSIF (ViewObject = BugTaskB) THEN
                    SetString(BugIndicator, BugBLetter);
                END;
            END;
            PutString(BugIndicator, Ulx, Uly, videodatebar);
            EXCL(Status, NeedsBugsDisplay);
        END;

        IF (NeedsGanttBarDisplay IN Status) THEN
            DoPreamble();
            IF (GanttOnScreen) THEN                               (* 25-Feb-88 LAA *)
                MakeGanttLine (Baseline,BaseLineExists IN TTaskFlags,Bars);
                MakeGanttLine (Plan, FALSE, s);
                PutString (s, Ulx + FirstGantt, Uly, mode);
                PutString (Bars, Ulx + FirstGantt, Uly + 1, mode);

                    (*  Display the cursor symbol *)
                WITH ChartRecord^ DO
                    IF (CursorOn IN Status) THEN                  (* 13-Mar-89 LAA *)
                        DisplayCursor(CursorDay, ChartFont[4], Uly, barmode);  (* 02-Jan-89 *)
                        DisplayCursor(CursorDay, ChartFont[4], Uly + 1, barmode);
                        ViewCursorDay := CursorDay;
                    END;
                END;
            END;
            IF (CursorOn IN Status) THEN                          (* 25-Feb-88 LAA *)
                DisplayCursorDate(GanttOnScreen);
            END;
            EXCL(Status, NeedsGanttCursorDisplay);
            EXCL(Status, NeedsGanttBarDisplay);
        END;

        IF (NeedsGanttCursorDisplay IN Status) THEN
            DoPreamble();
            PutColors(Ulx + 1, Uly, FirstGantt - 1, mode, tablemode);     (* 18-Apr-89 LAA *)
            PutColors(Ulx + 1, Uly + 1, FirstGantt - 1, mode, tablemode);
            IF ((ViewObject <> NIL) AND (CursorOn IN Status)) THEN
                SendColumnSeparators((ScrollEnabled) AND (CursorOn IN Status));  (* 3-Mar-89 LAA *)
            END;
            IF (GanttOnScreen) THEN
                IF (CursorOn IN Status) THEN                      (* 13-Mar-89 LAA *)
                    IF (CursorDay <> ViewCursorDay) THEN
                        IF (ViewCursorDay >= ChartStartDay) THEN
                            i := (ViewCursorDay-ChartStartDay)
                                  DIV ChartRecord^.scale + 1;
                            MakeGanttLine (Plan, FALSE, Bars);
                            MakeGanttLine (Baseline,
                                           BaseLineExists IN TTaskFlags,s);
                            DisplayCursor(ViewCursorDay, Bars[i], Uly, mode);
                            DisplayCursor(ViewCursorDay, s[i], Uly + 1, mode);
                        END;
                        ViewCursorDay := CursorDay;
                    END;
                    DisplayCursor(CursorDay, ChartFont[4], Uly, barmode);  (* 02-Jan-89 *)
                    DisplayCursor(CursorDay, ChartFont[4], Uly + 1, barmode);
                ELSIF ((ViewObject <> NIL)                        (* 13-Mar-89 LAA *)
                    AND (ViewCursorDay >= ChartStartDay)) THEN
                    i := (ViewCursorDay-ChartStartDay)
                          DIV ChartRecord^.scale + 1;
                    MakeGanttLine (Plan, FALSE, Bars);
                    MakeGanttLine (Baseline,BaseLineExists IN TTaskFlags,s);
                    DisplayCursor(ViewCursorDay, Bars[i], Uly, mode);
                    DisplayCursor(ViewCursorDay, s[i], Uly + 1, mode);
                END;
            END;
            IF (CursorOn IN Status) THEN                          (* 25-Feb-88 LAA *)
                DisplayCursorDate(GanttOnScreen);
            END;
            EXCL(Status, NeedsGanttCursorDisplay);
        END;

        IF (TaskIsLocked) THEN
            ViewObject^.Methods^.UnlockUnchangedDataObject(ViewObject);  (* 10-Dec-87 LAA *)
        END;
    END;

END AVPViewDisplay;








(*----------------------------------------------------------------------------
    InitAsAVPView --

    Initialize the indicated object as an AVP view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid AVP view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsAVPView(    AVPView       : AnAVPView;
                            SuperView     : AnObjectView;
                            ChartFormat   : AChartFormatPtr;
                            Ulx           : ascreenx;
                            Uly           : ascreeny;
                            Lrx           : ascreenx;
                            Lry           : ascreeny;
                            Box           : ABoxType;
                            VideoMode     : avidmode;
                            HelpKey       : CARDINAL        );

VAR
    PrivateAVPView          : XAVPView;
    Title                   : ARRAY [0..5] OF CHAR;

BEGIN                       (* InitAsAVPView *)

    PrivateAVPView := XAVPView(AVPView);
    Fill(Title, " ", 0);
    InitAsGanttView(AGanttView(AVPView), SuperView, ChartFormat, Ulx, Uly,
                    Lrx, Lry, Box, VideoMode, HelpKey);

    WITH PrivateAVPView^ DO
        Methods := ADR(AVPViewMethodsRecord);
        CursorMode := VideoMode;                                  (* 07-Jan-88 LAA *)
    END;

    IF (NOT GlobalInitialized) THEN
        GlobalInitialized := TRUE;
        GetMessage(ModuleNumber + 1, Title);
        BugALetter := Title[1];
        SeperatorChar := Title[2];
        BugBLetter := Title[3];
        GetMessage(ModuleNumber + 2, PressSlashMessage);          (* 22-Feb-88 LAA *)
    END;

END InitAsAVPView;





(*----------------------------------------------------------------------------
    UnInitAsAVPView --

    Un-Initialize the indicated object as an AVP view.

    Preconditions:
        The object must be a valid AVP View object.

    Postconditions:
        The object will no longer be a valid AVP view object, and all
        effects of InitAsAVPView will be undone.  No storage deallocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsAVPView(    AVPView   : AnAVPView);

BEGIN                       (* UnInitAsAVPView *)

    UnInitAsGanttView (AGanttView (AVPView));

END UnInitAsAVPView;






(*----------------------------------------------------------------------------
    CreateAVPView --

    Allocate storage for, and initialize the indicated object as an AVP
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be
        allocated and initialized as a valid Gantt view object, and TRUE
        will be returned.
----------------------------------------------------------------------------*)

PROCEDURE CreateAVPView(VAR AVPView       : AnAVPView;
                            SuperView     : AnObjectView;
                            ChartFormat   : AChartFormatPtr;
                            Ulx           : ascreenx;
                            Uly           : ascreeny;
                            Lrx           : ascreenx;
                            Lry           : ascreeny;
                            Box           : ABoxType;
                            VideoMode     : avidmode;
                            HelpKey       : CARDINAL        )
                                                             : BOOLEAN;
BEGIN                       (* CreateAVPView *)

    IF (NOT Available(TSIZE(XAVPViewRecord))) THEN                (* 17-Feb-88 LAA *)
        RETURN FALSE;
    END;

    ALLOCATE(AVPView, TSIZE(XAVPViewRecord));
    InitAsAVPView(AVPView, SuperView, ChartFormat, Ulx, Uly, Lrx, Lry,
                    Box, VideoMode, HelpKey);

    RETURN TRUE;

END CreateAVPView;







(*----------------------------------------------------------------------------
    CloneAVPViewMethods --

    Make a copy of the Gantt view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The Gantt view methods will be copied into the indicated method
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneAVPViewMethods(    MethodObject : AnAVPViewMethods);

BEGIN                       (* CloneAVPViewMethods *)

    MethodObject^ := AVPViewMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(AVPViewMethodsRecord);

END CloneAVPViewMethods;








(*----------------------------------------------------------------------------
    ValidateAVPView --

    Determine that the indicated object is in fact a valid Gantt view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid Gantt view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateAVPView(    AVPView   : AnAVPView);

BEGIN                       (* ValidateAVPView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateGanttView(AGanttView(AVPView));
    END;
    DEBUGGING*)

    IF (AVPView^.Methods^.AVPViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateAVPView;




BEGIN                       (* AVPViews *)

    CloneGanttViewMethods(ADR(AVPViewMethodsRecord));
    WITH AVPViewMethodsRecord DO
        MethodSize := TSIZE(AnAVPViewMethodsRecord);
        Discard := AnAVPViewDiscardProc(AVPViewDiscard);
        Display := AnAVPViewDisplayProc(AVPViewDisplay);
        AVPViewTag := ModuleNumber;
    END;
    GlobalInitialized := FALSE;

END AVPViews.

