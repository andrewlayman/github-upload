IMPLEMENTATION MODULE GanttViews;          (* A subclass of ActiveViews *)

    (* MODIFICATION HISTORY --
        03-Oct-87 LAA   Calls to CurrentLayout and GetDataObject will not be
                        done unless this view is going to display something.
        10-Dec-87 LAA   Incorporated LockFlexStorDataObject method.
        22-Dec-87 LAA   The last character of the cursor bar was being left
                        on the screen when moving from task to task if the
                        layout defined columns which took up the entire
                        screen width (or more), so there was no blank column
                        between the data columns and Gantt bars.
        29-Dec-87 LAA   Removed all overhead of caching.
        30-Dec-87 LAA   Speeded up processing of "/".
        07-Jan-88 LAA   Initialize CursorMode here because of a compiler
                        problem.  It's initialized in InitAsActiveView, but
                        get's garbaged along the way.
        17-Feb-88 LAA   Use Available instead of HeapAvailable, since we do
                        want to be able to switch between AVP and Gantt views
                        with low memory.  Also import ALLOCATE and DEALLOCATE
                        from Space.
        19-Feb-88 LAA   Added DisplayedCursorDate variable initialization, and
        21-Feb-88 LAA   changed the way cursor dates are displayed, and got
                        bug characters from the phrases file.
        22-Feb-88 LAA   Put in PressSlashMessage.
        25-Feb-88 LAA   Messed with cursor date display (again).
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
        28-Dec-88 LAA   Made changes to support getting the layout to use from
                        the parent view, so we can scroll data columns on the
                        Gantt chart.
        04-Feb-89 LAA   Added display of Cursor column on the data columns
                        area.  This way is probably not the best - it should
                        be fixed later!!!!!
        18-Feb-89 LAA   Changed column stuff to use secondarycursor.
        22-Feb-89 LAA   Turn off Gantt bar cursor if in scroll mode.
         3-Mar-89 LAA   Changed ScrollMode BOOLEAN to ScrollEnabled to aviod
                        confusion with the procedure ScrollMode.  Also fixed
                        keys so that Ctrl-Left and Right move the Gantt bar
                        cursor by 1 character, and Tab and BackTab (RTab) move
                        it by "large" jumps, like Ctrl-Left & Right used to.
         6-Mar-89 LAA   Brought structure of Display portions of GanttViews
                        and AVPViews into more close alignment.
        13-Mar-89 LAA   Display the Gantt cursor even if scrolling Gantt
                        columns are enabled.
        22-Mar-89 EGK   Changed MakeBars to use new "percent" parameter in
                        GanttLine, and to get the percentage column from
                        Captions.
        27-Mar-89 LAA   Changed the keys which scroll the Gantt bars region
                        of the Gantt chart back to the way they were in
                        Version 3.0 - except the Tab and BackTab keys are
                        used for scrolling the task table region.
        28-Mar-89 LAA   Decode Ctrl-Home and Ctrl-End keys here so they will
                        not work if scolling is enabled on the task table
                        section of the Gantt chart.
        11-Apr-89 LAA/EGK Merged in Ed's bug fix.
        12-Apr-89 LAA   Display the Gantt bar cursor in secondary video if
                        scroll mode is on, rather than making it disappear
                        entirely.
        18-Apr-89 LAA   Made use of PutStringWithColors so that the Gantt
                        cursor will take on filter colors as it passes over
                        the relevant tasks.

        23-May-89 LAA   Moved code from the ActOn procedure to a local
                        Dispatch procedure, and enabled Ctrl-Home and Ctrl-End
                        to work even if the active cursor is on the
                        Spreadsheet area.
        11-Dec-89 LAA   Added support for mouse events.
        04-Jan-90 LAA   More mouse support.
         5-Jan-90 LAA   Fixed a bug in DisplayCursor, which occured because
                        I'd named a parameter (VideoMode) the same name as a
                        field in GanttViews, and used it in a WITH statement.
                        This caused the cursor to display in the wrong color.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
         8-Jun-90 MWP   Fixed a bug in DisplayCursor, which was causing the
                        baseline cursor to be displayed with the display
                        character of the actuals line.
         9-Nov-90 TGS   Integrate changes to 4.03.
        25-Jan-91 RSC   Update for new GanttLine and FormatTaskColumns
                        procedures.
    *)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveViewMethods, AnActiveView,
    (* PROC *)                  InitAsActiveView, UnInitAsActiveView,
                                ValidateActiveView, CloneActiveViewMethods;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ATaskFilter,
    (* PROC *)                  CheckTaskValid;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Captions               IMPORT
    (* PROC *)                  ResourceNameList, FormatTaskColumns,
                                GetColumnPercentage;

FROM Chart                  IMPORT
    (* VAR *)                   ChartStartDay, CursorDay, BugTaskA, BugTaskB,
    (* PROC *)                  MChToday, MChCurrentTask;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr, AChartFormat,
    (* PROC *)                  GetLayoutMetrics, FindCurrentColumn;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Correl                 IMPORT
    (* TYPE *)                  ACorrelationList, ARegionSet,
    (* PROC *)                  CreateCorrelationList, DisposeCorrelationList,
                                SetRegion, CorrelatePointMulti,
                                CorrelatePoint;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error, Burp, MessageWithPriority,
                                MessagePriority, SetMessagePriority;

FROM ErrorCategories        IMPORT
    (* CONST *)                 NotPossibleInContextError, UnknownEventError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  GetErrorDetails, NewMarker, ErrorPosted,
                                PopToMarker, PostError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  PushEvent;

FROM Gantt                  IMPORT
    (* TYPE *)                  ASlackStyle, AGanttLineType, AGanttFont,
    (* VAR  *)                  ChartFont, SummaryFont,
    (* PROC *)                  GanttLine, SetGanttLineTask;

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineSpecificChange, AGanttOutline;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 maxcol,
    (* PROC *)                  PutString, PutAttribute, KeyPress, PutColors,
                                PutStringWithColors;

FROM KbState                IMPORT
    (* PROC *)                  ScrollMode;

FROM Keys                   IMPORT
    (* CONST *)                 Fwrd, Reverse, GotoTodayKey,
                                InsertKey, DeleteKey, EditKey, GotoFirstKey,
                                GotoLastKey, RollRight, RollLeft,
                                GotoCurrentTaskKey, MouseUp, MouseDown,
                                MouseDouble, MouseStillDown;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, ConcatLS, Copy, LengthOf, SetLengthOf,
                                Overlay, SetString, Procustes, ConcatS,
                                Insert, Remove;

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
    (* TYPE *)                  ADate, ADurationUnit, ATimeInfo,
    (* PROC *)                  TimeUtoT, DayOfWeek;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;



CONST
    ModuleNumber            = 17600;
    MAXCARDINAL             = 0FFFFH;
    LeftArrow               = 33C;
    RightArrow              = 32C;

TYPE
    XGanttView              = POINTER TO XGanttViewRecord;

    XGanttViewRecord        = RECORD
                                Methods     : AGanttViewMethods;
                                ViewObject  : ATreeNode;
                                ParentView  : AGanttOutline;
                                Ulx         : ascreenx;
                                Uly         : ascreeny;
                                Lrx         : ascreenx;
                                Lry         : ascreeny;
                                Box         : ABoxType;
                                VideoMode   : avidmode;
                                Title       : ARRAY [0..40] OF CHAR;
                                HelpNumber  : CARDINAL;
                                Rug         : ARug;
                                Status      : AGanttViewStatusSet;
                                EventHistory : ARRAY [0..10] OF AnEvent;
                                CursorMode  : avidmode;
                                    (*  GanttView fields  *)
                                CharUnderCursor : CHAR;
                                ViewCursorDay: ADate;
                              END;


VAR
    GanttViewMethodsRecord  : AGanttViewMethodsRecord;
    BugALetter              : CHAR;
    BugBLetter              : CHAR;
    SeperatorChar           : CHAR;
    GlobalInitialized       : BOOLEAN;
    PressSlashMessage       : ARRAY [0..31] OF CHAR;










PROCEDURE GanttViewDiscard(VAR GanttView    : XGanttView);

BEGIN                       (* GanttViewDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateGanttView(AGanttView(GanttView));
    END;
    DEBUGGING*)

    UnInitAsGanttView(AGanttView(GanttView));
    DISPOSE(GanttView);

END GanttViewDiscard;




PROCEDURE GanttViewDisplay(    GanttView    : XGanttView);

CONST
    SpacesPerLevel          = 3;

VAR
    TaskPtr                 : ATaskPtr;
    FirstGantt              : CARDINAL;
    i                       : CARDINAL;
    x                       : CARDINAL;
    CursorColumn            : CARDINAL;
    ViewWidth               : CARDINAL;
    ChartRecord             : AChartFormatPtr;
    mode                    : avidmode;
    cmode                   : avidmode;
    tablemode               : avidmode;
    barmode                 : avidmode;
    Seperator               : ARRAY [0..1] OF CHAR;
    BugIndicator            : ARRAY [0..1] OF CHAR;
    Bars                    : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    GanttOnScreen           : BOOLEAN;
    PreambleDone            : BOOLEAN;
    ScrollEnabled           : BOOLEAN;
    TaskIsLocked            : BOOLEAN;


    PROCEDURE DisplayCursorDate(    ShowDate : BOOLEAN);          (* 25-Feb-88 LAA *)

    CONST
        SlashPosition           = 50;
        SlashWidth              = maxcol + 1 - SlashPosition;

    VAR
        TimeInfo                : ATimeInfo;
        DateString              : ARRAY [0..81] OF CHAR;
        s                       : ARRAY [0..81] OF CHAR;

    BEGIN                       (* DisplayCursorDate *)

        IF (KeyPress()) THEN RETURN END;

        WITH GanttView^ DO WITH TimeInfo DO
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
                        WITH GanttView^ DO
                            IF ((i = CursorColumn) AND (ShowCursorCol)) THEN
                                PutAttribute(Ulx+Position, Uly, Width-1, cmode);
                            END;
                            PutAttribute(Ulx + x, Uly, 1, videonormal);
                        END;
                    END;
                END;
            END;
        END;

    END SendColumnSeparators;


    PROCEDURE MakeBars();

    VAR
        Percentage          : CARDINAL;
        i                   : CARDINAL;
        PrivateChartFont    : AGanttFont;
        Started             : BOOLEAN;
        Continues           : BOOLEAN;

    BEGIN                   (* MakeBars *)

        WITH GanttView^ DO
            IF (ViewObject = NIL) THEN
                Fill(Bars, " ", ViewWidth + 1 - FirstGantt);
                IF (AsOfDate >= ChartStartDay) THEN
                    i := (AsOfDate - ChartStartDay) DIV ChartRecord^.scale;
                    IF (i < LengthOf(Bars)) THEN
                        Bars[i + 1] := ChartFont[9];
                    END;
                END;
                RETURN;
            END;

            IF (ViewObject^.Methods^.GetSubtree(ViewObject) <> NIL) THEN
                PrivateChartFont := SummaryFont;
            ELSE
                PrivateChartFont := ChartFont;
            END;

            WITH ChartRecord^ DO
                Percentage := 0;

                IF (ProgressLineType = Plan) THEN
                    IF (NOT GetColumnPercentage (ViewObject, TaskPtr,
                            ProgressColumnID, Plan, Percentage)) THEN
                        Percentage := 0;
                    END;
                END;


                SetGanttLineTask( ViewObject, TaskPtr );    (* 25-Jan-91 RSC  *)

                GanttLine(ViewObject, Plan, ChartStartDay, AsOfDate,
                          Percentage, GanttWidth, 1, scale, slackstyle,
                          PrivateChartFont, Bars, Started, Continues);
            END;

            IF (Started) THEN
                Bars[1] := LeftArrow;
            END;
            IF (Continues) THEN
                Bars[ViewWidth - FirstGantt + 1] := RightArrow;
            END;
        END;

    END MakeBars;


    PROCEDURE DisplayCursor(    CursorDate  : ADate;
                                CursorChar  : CHAR;
                                LCursorMode : avidmode);

    VAR
        i                   : CARDINAL;
        Cur                 : ARRAY [0..10] OF CHAR;              (* 8-Jun-90 MWP *)

    BEGIN                   (* DisplayCursor *)

        WITH GanttView^ DO
            i := (CursorDate - ChartStartDay) DIV ChartRecord^.scale;
            IF (i < ChartRecord^.GanttWidth) THEN
                SetString(Cur, CursorChar);
                PutString(Cur, Ulx + FirstGantt + i, Uly, LCursorMode);
            END;
        END;

    END DisplayCursor;


    PROCEDURE DoPreamble();

    VAR
        s                   : ARRAY [0..255] OF CHAR;

    BEGIN                   (* DoPreamble *)

        IF (NOT PreambleDone) THEN
            WITH GanttView^ DO
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



BEGIN                       (* GanttViewDisplay *)

    TaskIsLocked := FALSE;

    WITH GanttView^ DO
        IF (NeedsRedisplay IN Status) THEN
            Status := Status + AGanttViewStatusSet{NeedsTaskNameDisplay,
                                                   NeedsBugsDisplay,
                                                   NeedsGanttBarDisplay,
                                                   NeedsGanttCursorDisplay};
(*            INCL(Status, NeedsTaskNameDisplay);*)
(*            INCL(Status, NeedsBugsDisplay);*)
(*            INCL(Status, NeedsGanttBarDisplay);*)
(*            INCL(Status, NeedsGanttCursorDisplay);*)
            EXCL(Status, NeedsRedisplay);
        END;

        PreambleDone := FALSE;
        IF (NeedsTaskNameDisplay IN Status) THEN
            DoPreamble();
            IF (ViewObject = NIL) THEN
                IF (FirstGantt > 1) THEN
                    Fill(s, " ", FirstGantt - 2);
                    PutStringWithColors(s, Ulx+1, Uly, mode, tablemode);  (* 18-Apr-89 LAA *)
                        (* X pos: Ulx + 1 + ((FirstGantt - 1) - 1)  *)
                    Fill(Seperator, SeperatorChar, 1);
                    PutString(Seperator, Ulx+FirstGantt-1, Uly, videonormal);
                END;
            ELSE
                    (*  Format and print columnar data  *)
                FormatTaskColumns(ViewObject,TaskPtr,Plan,ChartRecord^,FirstGantt-1,s);
                PutStringWithColors(s, Ulx+1, Uly, mode, tablemode);  (* 18-Apr-89 LAA *)


                IF (tablemode <> videonormal) THEN
                    SendColumnSeparators(ScrollEnabled);
                END;

            END;
            EXCL(Status, NeedsTaskNameDisplay);
        END;

        IF (NeedsBugsDisplay IN Status) THEN
            DoPreamble();
            SetString(BugIndicator, " ");
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
            IF (GanttOnScreen) THEN
                MakeBars();
                PutString(Bars, Ulx + FirstGantt, Uly, mode);

                    (*  Display the cursor symbol *)
                WITH ChartRecord^ DO
                    IF (CursorOn IN Status) THEN                  (* 13-Mar-89 LAA *)
                        DisplayCursor(CursorDay, ChartFont[4], barmode);              (* 12-Apr-89 LAA *)
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
            PutColors(Ulx + 1, Uly, FirstGantt - 1, mode, tablemode);  (* 18-Apr-89 LAA *)
            IF (ViewObject <> NIL) THEN                           (* 22-Dec-87 LAA *)
                SendColumnSeparators((CursorOn IN Status) AND (ScrollEnabled));
            ELSIF ((GanttOnScreen) AND (FirstGantt > 1)) THEN
                PutAttribute(Ulx + FirstGantt - 1, Uly, 1, videonormal);
            END;
            IF (GanttOnScreen) THEN
                IF (CursorOn IN Status) THEN                      (* 13-Mar-89 LAA *)
                    IF (CursorDay <> ViewCursorDay) THEN
                        IF (ViewCursorDay >= ChartStartDay) THEN
                            i := (ViewCursorDay-ChartStartDay)
                                  DIV ChartRecord^.scale + 1;
                            MakeBars();
                            DisplayCursor( ViewCursorDay, Bars[i], mode );
                        END;
                        ViewCursorDay := CursorDay;
                    END;
                    DisplayCursor(CursorDay, ChartFont[4], barmode);
                ELSIF ((ViewObject <> NIL)                         (* 13-Mar-89 LAA *)
                    AND (ViewCursorDay >= ChartStartDay)) THEN
                    i := (ViewCursorDay-ChartStartDay)
                          DIV ChartRecord^.scale + 1;
                    MakeBars();
                    DisplayCursor(ViewCursorDay, Bars[i], mode );
                END;
            END;
            IF (CursorOn IN Status) THEN
                DisplayCursorDate(GanttOnScreen);                 (* 25-Feb-88 LAA *)
            END;
            EXCL(Status, NeedsGanttCursorDisplay);
        END;

        IF (TaskIsLocked) THEN
            ViewObject^.Methods^.UnlockUnchangedDataObject(ViewObject);
            TaskIsLocked := FALSE;
        END;
    END;

END GanttViewDisplay;



PROCEDURE GanttViewSetCursor(   GanttView   : XGanttView;
                                Display     : BOOLEAN   );

BEGIN                       (* GanttViewSetCursor *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateGanttView(AGanttView(GanttView));
    END;
    DEBUGGING>*)

    WITH GanttView^ DO
        IF (Display <> (CursorOn IN Status)) THEN
            IF Display THEN
                INCL(Status, CursorOn);
                ParentView^.Methods^.NoteSpecificChange( ParentView, TaskChange );
            ELSE
                EXCL(Status, CursorOn);
            END;
            INCL(Status, NeedsGanttCursorDisplay);
            (* INCL(Status, NeedsGanttBarDisplay); *)
        END;
    END;

END GanttViewSetCursor;


PROCEDURE GanttViewActOn(    GanttView    : XGanttView;
                             Event        : AnEvent;
                         VAR ReturnEvent  : AnEvent     );

VAR
    ErrorMarker             : AnErrorMarker;
    ChartRecord             : AChartFormatPtr;
    MouseCorrel             : ACorrelationList;
    WantToRecord            : BOOLEAN;
    ScrollEnabled           : BOOLEAN;

    PROCEDURE DateInView(    GanttView      : XGanttView;
                             Date           : ADate)
                                                    : BOOLEAN;

    BEGIN                       (* DateInView *)

        WITH GanttView^ DO
            WITH ChartRecord^ DO
                IF (CursorDay < ChartStartDay) THEN
                    RETURN FALSE;
                ELSIF (CursorDay >= ChartStartDay + GanttWidth * scale) THEN
                    RETURN FALSE;
                END;

                RETURN TRUE;
            END;
        END;

    END DateInView;


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
            ELSIF (Category <> 0) THEN
                (* Call WhatTheHell here *)
                GetMessage(Code, s);
                Error(s);
            END;
            INC(i);
        UNTIL (Category = 0);

    END RespondToErrors;



    PROCEDURE JumpRight(VAR Date            : ADate;
                            TimeUnit        : ADurationUnit);

    VAR
        MaxDate             : ADate;

    BEGIN                   (* JumpRight *)

            (* Make sure that we never NEVER try to go too near the
               right hand edge of time.  Just to be very sure, back off
               by two weeks, days or whatever the synchronizing unit is. *)
        MaxDate := FindPriorKeyDate(MAXCARDINAL, TimeUnit);
        MaxDate := FindPriorKeyDate(MaxDate, TimeUnit);

        IF (Date < MaxDate) THEN
            Date := FindNextKeyDate(Date + ChartRecord^.scale - 1, TimeUnit);
        ELSE
            PostError(NotPossibleInContextError, ModuleNumber + 3);
        END;

    END JumpRight;



    PROCEDURE JumpLeft(VAR Date             : ADate;
                           TimeUnit         : ADurationUnit);

    BEGIN                   (* JumpLeft *)

        IF (Date > 0) THEN
            Date := FindPriorKeyDate(Date, TimeUnit);
        ELSE
            PostError(NotPossibleInContextError, ModuleNumber + 4);
        END;

    END JumpLeft;





    PROCEDURE DoFwrdKey();

    VAR
        LastDate            : ADate;

    BEGIN                   (* DoFwrdKey *)

        WITH GanttView^ DO
            WITH ChartRecord^ DO
                LastDate := FindPriorKeyDate(MAXCARDINAL, scaleunit);
                IF (ScrollMode()) THEN
                    JumpRight(CursorDay, scaleunit);
                    JumpRight(ChartStartDay, scaleunit);
                ELSIF (LastDate >= scale) AND (LastDate - scale > CursorDay) THEN   (* 4/7/89 EGK *)
                    INC(CursorDay, scale);
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 1);
                END;
            END;
        END;

    END DoFwrdKey;



    PROCEDURE DoReverseKey();

    BEGIN                   (* DoReverseKey *)

        WITH GanttView^ DO
            WITH ChartRecord^ DO
                IF (ScrollMode()) THEN
                    JumpLeft(CursorDay, scaleunit);
                    JumpLeft(ChartStartDay, scaleunit);
                ELSIF (CursorDay > scale) THEN
                    DEC(CursorDay, scale);
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 2);
                END;
            END;
        END;

    END DoReverseKey;





    PROCEDURE DoTabKey(    TimeUnit         : ADurationUnit);

    BEGIN                   (* DoTabKey *)

        JumpRight(CursorDay, TimeUnit);

    END DoTabKey;





    PROCEDURE DoRTabKey(    TimeUnit        : ADurationUnit);

    BEGIN                   (* DoRTabKey *)

        JumpLeft(CursorDay, TimeUnit);

    END DoRTabKey;




    PROCEDURE Dispatch(    Code             : ACode);

    VAR
        BigJump             : ADurationUnit;

    BEGIN                   (* Dispatch *)

        WITH GanttView^ DO                                        (* 23-May-89 LAA *)
            INCL(Status, NeedsGanttCursorDisplay);

            WITH ParentView^.Methods^ DO                          (* 28-Dec-88 LAA *)
                ChartRecord := GetLayout(ParentView);             (* 30-Dec-88 LAA *)
                CASE Code OF
                    Fwrd :
                        DoFwrdKey();
                |   Reverse :
                        DoReverseKey();
                |   RollRight:
                        BigJump := ChartRecord^.scaleunit;
                        IF (BigJump < Years) THEN                 (* 13-Mar-89 LAA *)
                            INC(BigJump);
                        END;
                        DoTabKey(BigJump);
                |   RollLeft :
                        BigJump := ChartRecord^.scaleunit;
                        IF (BigJump < Years) THEN                 (* 13-Mar-89 LAA *)
                            INC(BigJump);
                        END;
                        DoRTabKey(BigJump);
                |   GotoTodayKey :
                        MChToday();
                |   GotoCurrentTaskKey :
                        MChCurrentTask();
                END;

                IF ((ChartRecord^.GanttWidth > 0)
                   AND (NOT DateInView(GanttView, CursorDay))) THEN
                    NoteSpecificChange(ParentView, GanttDatesChange);
                END;
            END;
        END;

    END Dispatch;




    (*  AddMouseRegions --
            Add regions to the correlation list for the spreadsheet area
            and Gantt bars area, if each exists.  These regions must exclude
            the coordinates which are to be used for horizontal scrolling.
        Preconditions:
            ChartRecord must be a pointer to a valid layout.
        Postconditions:
            Regions will be added to the correlation list, as appropriate.
            Region 1 is the spreadsheet area, region 2 the Gantt bars area.
    *)

    PROCEDURE AddMouseRegions(     MouseCorrel : ACorrelationList );

    VAR
        FirstGantt          : CARDINAL;
        ViewWidth           : CARDINAL;
        GanttOnScreen       : BOOLEAN;
        SpreadOnScreen      : BOOLEAN;

    BEGIN                   (* AddMouseRegions *)

        WITH GanttView^ DO
            ViewWidth := (Lrx - Ulx) + 1;
            GetLayoutMetrics( ChartRecord^, ViewWidth, GanttOnScreen,
                              FirstGantt, SpreadOnScreen );
            IF (SpreadOnScreen) THEN
                SetRegion( MouseCorrel, 1, Ulx + 1, Uly, Ulx + FirstGantt - 1,
                           Lry );
            END;
            IF (GanttOnScreen) THEN
                SetRegion( MouseCorrel, 2, Ulx + FirstGantt, Uly, Lrx, Lry );
            END;
        END;

    END AddMouseRegions;



    (*  DispatchMouse --
            Act on all the mouse event codes which are to be processed in the
            ActOnEvent procedure.
        Precondtions:
            Called from main body of ActOnEvent proc.; only mouse events are
            passed.
        Postconditions:
            The mouse event will be handled appropriately.  ReturnEvent may
            be altered if necessary to reject the event.  An error may also
            be posted if the event is not appropriate.
    *)

    PROCEDURE DispatchMouse(    Event       : AnEvent);


        PROCEDURE SelectWithMouse();

        VAR
            i                   : CARDINAL;
            LocalColumn         : CARDINAL;
            CNode               : ATreeNode;
            MouseRegions        : ARegionSet;
            ok                  : BOOLEAN;

        BEGIN                   (* SelectWithMouse *)

            WITH GanttView^ DO
                WITH ParentView^.Methods^ DO
                    CNode := GetCursorNode( ParentView );
                    IF (CNode <> ViewObject) THEN
                        SetCursorNode( ParentView, ViewObject );
                    END;
                    i := CorrelatePointMulti( MouseCorrel, Event.EventX,
                                              Event.EventY, MouseRegions );

                    IF (1 IN MouseRegions) THEN     (* Spreadsheet area *)
                        IF (NOT ScrollEnabled) THEN
                            SetScrollMode( ParentView, TRUE );
                            ScrollEnabled := TRUE;
                        END;
                        LocalColumn := FindCurrentColumn( ChartRecord^,
                                                          Event.EventX - Ulx );
                        IF (LocalColumn <> GetCursorColumn( ParentView )) THEN
                            SetCursorColumn( ParentView, LocalColumn );
                        END;
                    END;

                    IF (2 IN MouseRegions) THEN      (* Gantt bars area *)
                        IF (ScrollEnabled) THEN
                            SetScrollMode( ParentView, FALSE );
                            ScrollEnabled := FALSE;
                        END;
                        i := (Event.EventX - (Ulx+ChartRecord^.GanttPosition))
                             * ChartRecord^.scale + ChartStartDay;
                        IF (CursorDay <> i) THEN
                            CursorDay := i;
                            INCL(Status, NeedsGanttCursorDisplay);
                        END;
                    END;
                END;
            END;

        END SelectWithMouse;


    BEGIN                   (* DispatchMouse *)

        WITH GanttView^ DO
            CASE Event.EventCode OF
                MouseDown, MouseStillDown :
                    IF (ViewObject <> ATreeNode(NIL)) THEN
                        SelectWithMouse();
                    ELSIF (Event.EventCode = MouseDown) THEN
                        PostError(NotPossibleInContextError, ModuleNumber + 2);
                    END;
            |   MouseDouble :
                    IF (ViewObject <> ATreeNode(NIL)) THEN
                        Event.EventCode := EditKey;
                        PushEvent( Event );
                    ELSE
                        PostError(NotPossibleInContextError, ModuleNumber + 2);
                    END;
            ELSE
                FatalError();
            END;
        END;

    END DispatchMouse;


BEGIN                       (* GanttViewActOn *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateGanttView(AGanttView(GanttView));
    END;
    (*DEBUGGING>*)

    WITH GanttView^ DO
        ErrorMarker := NewMarker();
        ScrollEnabled := ParentView^.Methods^.QueryScrollMode(ParentView);  (* 28-Mar-89 LAA *)

        ReturnEvent.EventCode := 0;
        WantToRecord := TRUE;

        CASE Event.EventCode OF                                   (* 23-May-89 LAA *)
            RollRight, RollLeft, Fwrd, Reverse :
                IF (NOT ScrollEnabled) THEN                       (* 28-Mar-89 LAA *)
                    Dispatch(Event.EventCode);
                ELSE
                    ReturnEvent := Event;
                    WantToRecord := FALSE;
                END;

        |   GotoTodayKey, GotoCurrentTaskKey :
                Dispatch(Event.EventCode);

        |   MouseDown, MouseStillDown, MouseDouble :
                MouseCorrel := CreateCorrelationList();
                IF (MouseCorrel <> ACorrelationList(NIL)) THEN
                    ChartRecord := ParentView^.Methods^.GetLayout(ParentView);
                    AddMouseRegions( MouseCorrel );
                    IF (CorrelatePoint( MouseCorrel, Event.EventX,
                                                     Event.EventY ) > 0 ) THEN
                        DispatchMouse(Event);
                    ELSE
                        ReturnEvent := Event;
                        WantToRecord := FALSE;
                    END;
                    DisposeCorrelationList( MouseCorrel );
                ELSE
                    PostError(NotPossibleInContextError, ModuleNumber + 2);
                END;

        |   MouseUp : ;
        ELSE
            ReturnEvent := Event;
            WantToRecord := FALSE;
        END;


        IF (WantToRecord) THEN
            Methods^.RecordEvent(AGanttView(GanttView), Event);
        END;
        IF (ErrorPosted(ErrorMarker)) THEN
            RespondToErrors(ErrorMarker);
        END;
        PopToMarker(ErrorMarker);
    END;

END GanttViewActOn;




PROCEDURE GanttViewNoteChange(    GanttView : XGanttView;
                                  Change    : AGanttViewSpecificChange);

BEGIN                       (* GanttViewNoteChange *)

    WITH GanttView^ DO
        CASE Change OF
            BugsChange :
                INCL(Status, NeedsBugsDisplay);
        |   TaskNameChange :
                INCL(Status, NeedsTaskNameDisplay);
        |   GanttBarChange :
                INCL(Status, NeedsGanttBarDisplay);
        |   GanttCursorChange :
                INCL(Status, NeedsGanttCursorDisplay);
        END;
    END;

END GanttViewNoteChange;





PROCEDURE SetGanttCursorMode(    GanttView        : XGanttView;
                                 VideoMode        : avidmode   );

BEGIN                   (* SetGanttCursorMode *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateGanttView (AGanttView (GanttView));
    END;
    DEBUGGING>*)

    IF (GanttView^.CursorMode <> VideoMode) THEN
        GanttView^.CursorMode := VideoMode;
        INCL(GanttView^.Status, NeedsGanttCursorDisplay);
    END;

END SetGanttCursorMode;




(*----------------------------------------------------------------------------
    InitAsGanttView --

    Initialize the indicated object as a Gantt view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid Gantt view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsGanttView(    GanttView     : AGanttView;
                              SuperView     : AnObjectView;
                              ChartFormat   : AChartFormatPtr;
                              Ulx           : ascreenx;
                              Uly           : ascreeny;
                              Lrx           : ascreenx;
                              Lry           : ascreeny;
                              Box           : ABoxType;
                              VideoMode     : avidmode;
                              HelpKey       : CARDINAL     );

VAR
    PrivateGanttView        : XGanttView;
    Title                   : ARRAY [0..5] OF CHAR;

BEGIN                       (* InitAsGanttView *)

    PrivateGanttView := XGanttView(GanttView);
    Fill(Title, " ", 0);
    InitAsActiveView(AnActiveView(GanttView), SuperView, Ulx, Uly, Lrx, Lry,
                     Box, VideoMode, Title, HelpKey, FALSE);

    WITH PrivateGanttView^ DO
        Methods := ADR(GanttViewMethodsRecord);
        CursorMode := VideoMode;                                  (* 07-Jan-88 LAA *)
        ViewCursorDay := 0;
    END;

    IF (NOT GlobalInitialized) THEN
        GlobalInitialized := TRUE;
        GetMessage(ModuleNumber + 1, Title);
        BugALetter := Title[1];
        SeperatorChar := Title[2];
        BugBLetter := Title[3];
        GetMessage(ModuleNumber + 2, PressSlashMessage);          (* 22-Feb-88 LAA *)
    END;

END InitAsGanttView;





(*----------------------------------------------------------------------------
    UnInitAsGanttView --

    Un-Initialize the indicated object as a Gantt view.

    Preconditions:
        The object must be a valid Gantt View object.

    Postconditions:
        The object will no longer be a valid Gantt view object, and all
        effects of InitAsGanttView will be undone.  No storage deallocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsGanttView(    GanttView   : AGanttView);

BEGIN                       (* UnInitAsGanttView *)

    UnInitAsActiveView(AnActiveView(GanttView));

END UnInitAsGanttView;






(*----------------------------------------------------------------------------
    CreateGanttView --

    Allocate storage for, and initialize the indicated object as a Gantt
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be
        allocated and initialized as a valid Gantt view object, and TRUE
        will be returned.
----------------------------------------------------------------------------*)

PROCEDURE CreateGanttView(VAR GanttView     : AGanttView;
                              SuperView     : AnObjectView;
                              ChartFormat   : AChartFormatPtr;
                              Ulx           : ascreenx;
                              Uly           : ascreeny;
                              Lrx           : ascreenx;
                              Lry           : ascreeny;
                              Box           : ABoxType;
                              VideoMode     : avidmode;
                              HelpKey       : CARDINAL     )
                                                            : BOOLEAN;
BEGIN                       (* CreateGanttView *)

    IF (NOT Available(TSIZE(XGanttViewRecord))) THEN
        RETURN FALSE;
    END;

    ALLOCATE(GanttView, TSIZE(XGanttViewRecord));
    InitAsGanttView(GanttView, SuperView, ChartFormat, Ulx, Uly, Lrx, Lry,
                    Box, VideoMode, HelpKey);

    RETURN TRUE;

END CreateGanttView;







(*----------------------------------------------------------------------------
    CloneGanttViewMethods --

    Make a copy of the Gantt view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The Gantt view methods will be copied into the indicated method
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneGanttViewMethods(    MethodObject : AGanttViewMethods);

BEGIN                       (* CloneGanttViewMethods *)

    MethodObject^ := GanttViewMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(GanttViewMethodsRecord);

END CloneGanttViewMethods;








(*----------------------------------------------------------------------------
    ValidateGanttView --

    Determine that the indicated object is in fact a valid Gantt view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid Gantt view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateGanttView(    GanttView   : AGanttView);

BEGIN                       (* ValidateGanttView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(GanttView));
    END;
    DEBUGGING*)

    IF (GanttView^.Methods^.GanttViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateGanttView;




BEGIN                       (* GanttViews *)

    CloneActiveViewMethods(ADR(GanttViewMethodsRecord));
    WITH GanttViewMethodsRecord DO
        MethodSize := TSIZE(AGanttViewMethodsRecord);
        Discard := AGanttViewDiscardProc(GanttViewDiscard);
        Display := AGanttViewProc(GanttViewDisplay);
        SetCursor := AGanttViewSetCursorProc(GanttViewSetCursor);
        ActOnEvent := AGanttViewActOnProc(GanttViewActOn);
        NoteSpecificChange := AGanttViewNoteProc(GanttViewNoteChange);
        SetCursorMode := AGanttViewSetCursorModeProc(SetGanttCursorMode);
        GanttViewTag := ModuleNumber;
    END;
    DisplayedCursorDate := 0;                                     (* 19-Feb-88 LAA *)
    GlobalInitialized := FALSE;

END GanttViews.

