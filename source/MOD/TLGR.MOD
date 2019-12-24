MODULE TLGR;    (*  TimeLine Gantt Report  *)

(*----------------------------------------------------------------------------
       MODIFICATION HISTORY:

       May 13, 1986    LAA - In GrepPage, notes2 was being looked at for a
                             page break indicator.  We now look in the second
                             line of the task notes text.  Also imported
                             AFieldNo from FormCon rather than Forms.
       Aug. 13, 1985   AJL - Since we always print a row of year numbers
                             above the MonthDay time lines, I have changed
                             the DateStyle to use MonthDay whenever it
                             would have used YearMonth.
                           - Add StartDateTag.
                           - Changed the logic of determining the next
                             date to print on continuation strips so that
                             the next date is the same as it would be if
                             one very wide strip were being printed.  This
                             overrides an effect of CheckScale, and required
                             a compensating change to Gantt.DateLines.  It
                             fixes a problem of tags sometimes dropping
                             characters at the strip boundary.
        11/14/86 LAA    The report settings are now kept in a help item.
        11/20/86 LAA    Removed usage of FiltersOmit.
        12/05/86 LAA    Used TaskIsIn and TaskIsHighlighted instead of direct
                        access to these fields of the task record.
        7/9/87   EGK    Many modifications and improvements for version 3.0.
                        Options form is now built into code.  Report now
                        includes all the columnar data from the Gantt Chart,
                        all of which can also be split into strips.
        11/16/87  EGK   New fields on options form.  Also prints baseline
                        data and suppresses gantt bars if layout dictates.
         1/12/88  RSC   added "Unchanged" fixes.
        14-Jan-88 LAA   Moved the form up so it doesn't overwrite the lights.
         1-Feb-88 EGK   Consider baseline dates when finding beginning of
                        schedule.
        08-Feb-88 LAA   Adjusted for new parameter to GetColumnInfo.
        15-Feb-88 EGK   GrepPage aborts if it can't print any tasks on a
                        page.
        25-Feb-88 EGK   Avoids splitting strips in the middle of a tabular
                        column.
        01-Mar-88 EGK   Adjust StartDate so that it falls at the beginning of
                        a period.  Truncate last strip if user specifies an
                        end date.
        07-Mar-88 EGK   If we're not showing gantt bars, don't use the
                        user-specified start and end dates.
        20-Jul-88 LAA   Put up an error message if there aren't any tasks to
                        report on.
        17-Nov-88 LAA   Massivly reorganized GanttChartReport to fix bug 8504
                        and 8502.
        28-Nov-88 LAA   Fixed a bug in determining end dates, which only 
                        occured when the last task of a schedule is a 
                        milestone, and it occured on a key date.
        29-Nov-88 LAA   Moved English phrases into message file.
        30-Nov-88 LAA   Tested for a cardinal overflow condition which caused
                        the Gantt Report to produce far too many pages.
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
        23-Jan-89 RSC   Changed Storage to Space    .
        22-Mar-89 EGK   Changed PrintOneTaskLine to use new "percent"
                        parameter in GanttLine, and to get the
                        percentage column from Captions.
        29-Mar-89 EGK   Write out another legend line showing what the
                        "progress" column is and on which line (baseline
                        or actual) it shows.
        04-Apr-89 EGK   Fixed PrintOneTaskLine so that it doesn't call
                        GanttLine on the baseline if there isn't a baseline.
        18-Apr-89 EGK   Check for NextDate < StartDate, which would mean
                        that there wasn't enough room for gantt bars on
                        the strip.
        23-May-89 LAA   Put code into GanttChartReport to fix a bug reported
                        from a customer.  What happened was that he/she 
                        entered a start date of February (in May), which was
                        taken as a future date.  But that date was after the
                        end of the schedule, a condition which we don't check
                        for.  So I checked for it, and now force the end date
                        to be after the start date.
          6-Jun-89 AJL  Put filters into FlexStor.
        19-Jun-89 AJL   Removed FiltersOn boolean, replaced by 
                        QueryRevealFilterOn.
        10-Aug-89 KKC   Add copyright message.
        21-Aug-89 EGK   Removed unnecessary imports from FilterRc.
        24-Aug-89 KKC   Start from the actual earlies task if baseline is not
                        shown.
                        Add Baseline in legend.
        19-Sep-89 RSC   Fixed Bug 1362, legend not starting at the start
                        of the report.  Did this by backing off the start
                        of the report to the start of the next higher
                        time unit.  Eg, if report is by hours, start with
                        start of the day.
        22-Sep-89 RSC   Bug 1362 again.
                        Well, lets try again.... The case above worked in
                        many cases, but not for cases like "180 minutes" or
                        "4 hours", where logic later will ajust to a much
                        higher scale for the captions.

                     KLUGE:  I can't figure out the RIGHT way to handle this
                             in the time alloted (we freeze 4.0 code today
                             and its now 4:45PM), so I will try to make
                             an even better guess, using DownScale.
        20-Oct-89 KKC   If there is no room to display any task, display one
                        one task and move the legend to the next page.
        16-Nov-89 KKC   Set NextScale based on the value of ScaleRange and 
                        Scale
        20-Nov-89 EGK   Changed FormatTaskHeadings to handle the column
                        headings AND the task column data formatting, and to
                        handle a layout whose total columnar data width
                        exceeds 255 characters.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        11-May-90 MWP   If date format is weeknumbers, then check whether
                        we should print a 3 line date format.
        12-Sep-90 RSC   Fixed for new Allocs.Def
        22-Jan-91 RSC   Import NameScale from LongDuration rather than
                        TimeFormat.
         2-May-91 TGS   When deciding when to print Legend, we were checking 
                        only BreakPages and not also PrintCaptions.
        2-Jul-91  AJL - Added parameters to FilterNotes.
----------------------------------------------------------------------------*)


FROM Allocs                 IMPORT ATaskPtr, ATask, ATaskName, ATaskFlag,
                                   ATaskFilter, ATaskFilterSet, TskNmLen,
                                   TaskTree;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* VAR *)                   GetColumnInfo, GetColumnString,
    (* PROC *)                  GetColumnPercentage;

FROM ChartForms             IMPORT AChartFormatPtr, CurrentLayout;

FROM Dialog                 IMPORT Message, Error;

FROM FilterRc               IMPORT AFltrType, RevealFilter,
                                   AFilterRecordPointer;

FROM Gantt                  IMPORT MaxPrtWidth, ADStyle, CheckScale,
                                   DateLines, GanttLine, AGanttFont,
                                   ChartFont, SummaryFont,
                                   BaselineSummaryFont, BaselineDetailFont,
                                   AGanttLineType,
                                   SetGanttLineTask;

FROM GrepOptions            IMPORT
    (* TYPE *)                  ATagType, AReportSettingPointer,
    (* VAR *)                   ReportSettings,
    (* PROC *)                  DoPrintDialog;

FROM LongDuration           IMPORT
    (* PROC *)                  NameScale;

FROM LStrings               IMPORT Fill, SetString, ConcatLS, CtoS, RJust,
                                   SubStr, ConcatS, Insert, Procustes,
                                   Search, LJust, TrimRear, Remove, Copy,
                                   LengthOf, SetLengthOf, Overlay;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM MsgFile                IMPORT GetMessage, ConcatMessage;

FROM ParseTime              IMPORT
    (* PROC *)                  StoTimeU, StoEndTimeU;

FROM PrintSupport           IMPORT RowsLeft, PageWidth, PageTop, StartReport,
                                   StartPage, EndReport, PrintLine, 
                                   AllowUnlimitedPageLength, ProgressMessage,
                                   AllowLeftMargin, Stopped;

FROM PrintCaptions          IMPORT FilterNotes, PageHead;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TimeFormat             IMPORT
    (* PROCS *)                 TimeUtoS;

FROM TimeJump               IMPORT FindStartDateOf, FindNextKeyDate,
                                   FindPriorKeyDate;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate, ADuration, ADurationUnit;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM WeekNumberInfo      IMPORT                                (* 11-May-90 MWP *)
    (* VAR *)                   UsingWeekNumbers;

CONST
    MAXDATE                 = 0FFFFH;
    Normal                  = 0;
    Bold                    = 1;
    NumericTagLength        = 5;
    TagLength               = 10; (* The maximum size of a tag *)
    GanttModule             = 17500;
    ModuleNumber            = 23000;
    
VAR
    DateRow1                : CARDINAL;
    TagIndex                : CARDINAL;
    FormatPtr               : AChartFormatPtr;



    (*
       The Gantt chart report is displayed on one or more pages.
       If the tasks are too wide (long in time) to fit onto a
       single page of printer output, the chart is continued onto
       subsequent pages.  The full task name is displayed on the
       left for the first page only.

       We display a menu that lets the user decide if s/he wants
       identifiers used to identify tasks and their lines.
       These identifiers can aid in visually lining up tasks
       with their bars (lines).

     *)




PROCEDURE InitTag( VAR TagIndex : CARDINAL );
BEGIN
    TagIndex := 0;  (* reset tag counter to zero. *)
END InitTag;





  (* BuildTag - there are three different tag types.  Generate the
                correct one.  The returned string is left justified
                with no trailing blanks.
                *)
(*
PROCEDURE BuildTag( VAR Tag         : ARRAY OF CHAR;
                    VAR TagIndex    : CARDINAL;
                    VAR TaskNode    : ATreeNode;
                        Option      : ATagType       );
CONST
    MaxNameLen = TagLength;
VAR
    l       : CARDINAL;
    Task    : ATaskPtr;
BEGIN
    Task := TaskNode^.Methods^.GetDataObject (TaskNode);
    CASE Option OF
        NumberTag  :
                      INC( TagIndex );
                      CtoS( TagIndex, Tag );
      | NameTag    :
                      l := 1;
                      WHILE (l <= ORD(Task^.taskname[0])) AND (Task^.taskname[l] <> " ") AND (l <= MaxNameLen) DO
                          INC(l);
                      END;
                      SubStr(Task^.taskname,Tag,1,l-1);
      | StartDateTag: TimeUtoS(Task^.Plan.Dates.EarlyStart,Tag);
        ELSE ; (* No tag *)
    END;
END BuildTag;
*)




  (* InsertTag decides if the tag needs to be inserted in front of
               a line of text.  It returns how many bytes to indent. *)

PROCEDURE InsertTag(    StripNumber     : CARDINAL;
                        FirstColumn     : CARDINAL;
                        Option          : ATagType  ): CARDINAL;
BEGIN

 (* If we are doing some tags and firstcolumn indicates that we are
    displaying the task names, then insert the tag. *)

    IF (Option      = NumberTag) AND
       (StripNumber = 1)         AND
       (FirstColumn > 1        ) THEN  RETURN NumericTagLength+1; END;

 (* All else returns no insert. *)

    RETURN 0;    (* Indent zero columns *)

END InsertTag;





(*
PROCEDURE FillInTag(VAR Line,
                        Tag         : ARRAY OF CHAR;
                        StripNumber : CARDINAL;
                        FirstColumn : CARDINAL;
                        Option      : ATagType      );
CONST
    BackOff      = 2;
    MinimumSpace = BackOff+1;
VAR
    i,l:CARDINAL;
    s : ARRAY [0..30] OF CHAR;
    ShortTag : ARRAY [0..30] OF CHAR;
BEGIN
    IF Option = NoTags THEN RETURN;  END;

        (*  Find the beginning of the task (Gantt) bar.   Skip past
            blanks, possibly the today mark, and any grid dots. *)

    l := FirstColumn;  (* Start after header data *)
    i := ORD(Line[0]);
    WHILE (l <= i)
          AND ((Line[l] = " ") OR (Line[l] = GanttFont[9]) OR (Line[l] = ".") ) DO
        INC( l );
    END;

        (* Now we have either l > ORD(line[0]) (i,EOL) or we have a nonblank,
           non | charactor.  Go back as much of the tag as possible.
           We will only put in a tag if either (1) The page has no names at
           the beginning (FirstColumn=1) or (2) there are enough blank spaces
           to the left of the task bar to accomodate the tag.  *)

    Copy (Tag,ShortTag);  (* Trimmed version. *)
    LJust(ShortTag);
    TrimRear(ShortTag);

    IF (l <= i) THEN                                           (* Was Gantt bar found? *)
        i := ORD(ShortTag[0]);                                 (* Tag length *)
            (* If this is a continuation page or the whole tag fits easily. *)
        IF (FirstColumn = 1) OR (l >= (FirstColumn + i + MinimumSpace))  THEN
            INC(i,BackOff);                                    (* Back up before Gantt bar. *)
            WHILE (l >= FirstColumn) AND (i > 0) DO
                IF (i <= ORD(ShortTag[0])) THEN
                    Line[l] := ShortTag[i];
                END;
                DEC(l);    DEC(i);
            END; (* While *)
        END;   (* If room enough to put it all or this is a cont page *)
    END;     (* If there are non-blanks on the page *)

        (* If we are to insert the tag, then do so. *)

    IF InsertTag(StripNumber,FirstColumn,Option) > 0 THEN
      Fill(s," ",1);
      Insert(Line,s,1);
      Copy (Tag, s);
      Procustes(s,NumericTagLength);
      RJust(s);
      Insert(Line,s,1);
    END;

END FillInTag;
*)









PROCEDURE EdgeCharacter( C : CHAR ) : BOOLEAN;
BEGIN
    RETURN (C = " ") OR
           ( (C >= "a") AND (C <= "z") );
END EdgeCharacter;





    (* WordBoundary -- Will not work if i <= 1 or greater
                       than the length of the string. *)


PROCEDURE WordBoundary(VAR s:ARRAY OF CHAR; i:CARDINAL):BOOLEAN;
VAR
    C : CHAR;
BEGIN
    RETURN (EdgeCharacter(s[i-1])) AND (NOT EdgeCharacter(s[i]));
END WordBoundary;





PROCEDURE FindNextWord(VAR s:ARRAY OF CHAR; VAR i:CARDINAL);
BEGIN
    LOOP
        INC(i);
        IF (i > ORD(s[0])) THEN
            EXIT;
        END;
        IF (WordBoundary(s,i)) THEN
            EXIT;
        END;
    END;
END FindNextWord;




  (* End of code from module TasksRep *)



PROCEDURE TaskIsHighlighted ( Node : ATreeNode ) : BOOLEAN;

VAR
    Task    : ATaskPtr;
    Result  : BOOLEAN;

BEGIN

    IF (Node = NIL) THEN
        RETURN FALSE;
    ELSE
        Task := Node^.Methods^.LockFlexStorDataObject (Node);

        Result := ((ATaskFilterSet{Highlight1,Highlight2,
                                   Highlight3,Highlight4,Highlight5} *
                   Task^.FilterSet) <> ATaskFilterSet{});

        Node^.Methods^.UnlockUnchangedDataObject (Node);
        RETURN Result;
    END;

END TaskIsHighlighted;




PROCEDURE TaskIsIn ( Task : ATreeNode ) : BOOLEAN;
BEGIN
    IF (Task = NIL) THEN
        RETURN FALSE;
    ELSE
        RETURN Task^.Methods^.Visible (Task);
    END;
END TaskIsIn;





PROCEDURE TasksInMemory() : BOOLEAN;

VAR
    s                       : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;

BEGIN

    ok := TaskTree^.Methods^.GetFirst (TaskTree) <> NIL;          (* 20-Jul-88 LAA *)
    IF (NOT ok) THEN
        GetMessage(ModuleNumber + 2, s);
        Error(s);
    END;

    RETURN ok;

END TasksInMemory;



    (*  FormatColumnStrings --

        Handles the formatting of both the headings and the data for
        the columnar portion of the gantt report.

        FirstCol    =   character position (in the current layout) to
                        start at
        Length      =   total width of the output string
        TaskNode    =   NIL to get column headings only, OR
                        a valid tree node to get its column information
        LineType    =   Plan or Baseline (used only if TaskNode <> NIL)
        InfoChoice  =   which heading line to use (only if TaskNode = NIL)
        String      =   the string variable to hold the result
    *)

PROCEDURE FormatColumnStrings (     FirstCol    : CARDINAL;
                                    Length      : CARDINAL;
                                    TaskNode    : ATreeNode;
                                    LineType    : AGanttLineType;
                                    InfoChoice  : AColumnInfoChoice;
                                VAR String      : ARRAY OF CHAR     );
VAR
    i                       : CARDINAL;
    LastCol                 : CARDINAL;
    diff                    : CARDINAL;
    k                       : CARDINAL;
    Pos                     : CARDINAL;
    T                       : ATaskPtr;
    TaskPtr                 : ATaskPtr;
    DataRecord              : AColumnDataRecord;

BEGIN                       (* FormatTaskColumns *)

    IF (Length > HIGH(String)) THEN
        Length := HIGH(String);
    END;
    LastCol := FirstCol + Length - 1;

    Fill (String, " ", Length);
    WITH FormatPtr^ DO

        i := 1;
        LOOP
            IF (i > ColumnCount) THEN
                EXIT;
            END;
            Pos := ColumnSpec[i].Position;
            IF (Pos < GanttPosition) THEN
                IF (ColumnSpec[i].Width > 0) THEN
                    k := ColumnSpec[i].Width - 1;
                    IF (Pos + k >= GanttPosition) THEN
                        k := GanttPosition - Pos - 1;
                    END;

                        (* Does any portion of this column fit into our
                           limits?  First, see if it lies to the left of
                           our right margin.  Then see if any of it lies
                           to the right of our left margin.  It may be
                           necessary to truncate the column at either the
                           left or right side.    -- EGK 11/17/89  *)

                    IF (Pos <= LastCol) THEN
                        IF (Pos < FirstCol) THEN
                            diff := FirstCol - Pos;
                            Pos := FirstCol;    (* truncate on left side *)
                            IF (diff > k) THEN
                                k := 0;
                            ELSE
                                DEC (k, diff);
                            END;
                        END;
                        IF (k > Length) THEN
                            k := Length;        (* truncate on right side *)
                        END;
                        IF (k > 0) THEN

                                (*  OK, finally we get to see what data
                                    we actually want!  *)

                            IF (TaskNode = NIL) THEN
                                TaskPtr := NIL;
                                GetColumnInfo (TaskNode, TaskPtr,
                                               ColumnSpec[i].ColumnID,
                                               InfoChoice, k, DataRecord);
                            ELSE
                                TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
                                IF (NOT GetColumnString (TaskNode, TaskPtr,
                                                 ColumnSpec[i].ColumnID,
                                                 LineType, k,
                                                 DataRecord.StringValue)) THEN
                                    SetLengthOf (DataRecord.StringValue, 0);
                                END;
                                TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);
                            END;

                            Overlay (String, DataRecord.StringValue,
                                     (Pos - FirstCol + 1), k);
                        END;
                    END;
                END;
            ELSE
                EXIT;
            END;
            INC (i);
        END;
    END;

END FormatColumnStrings;





PROCEDURE AdjustColumns (       LeftMargin      : CARDINAL;
                            VAR Columns         : CARDINAL  );

VAR
    i                       : CARDINAL;
    k                       : CARDINAL;
    Pos                     : CARDINAL;
    RightMargin             : CARDINAL;
    GotOne                  : BOOLEAN;

BEGIN                       (* FormatTaskColumns *)

    RightMargin := LeftMargin + Columns - 1;

    WITH FormatPtr^ DO

        i := 1;
        GotOne := FALSE;

        LOOP
            IF (i > ColumnCount) THEN
                EXIT;
            END;
            Pos := ColumnSpec[i].Position;
            IF (Pos <= RightMargin) THEN
                IF (ColumnSpec[i].Width > 0) THEN
                    k := ColumnSpec[i].Width - 1;
                    IF (Pos + k > RightMargin) THEN
                        RightMargin := Pos - 1;
                        EXIT;
                    ELSIF (Pos >= LeftMargin) THEN
                        GotOne := TRUE;
                    END;
                END;
            ELSE
                EXIT;
            END;
            INC (i);
        END;
    END;

    IF (GotOne) THEN
        Columns := RightMargin - LeftMargin + 1;
    END;

END AdjustColumns;





PROCEDURE GetProgressColumnName ( VAR s         : ARRAY OF CHAR );
VAR
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;
BEGIN
    T := NIL;
    GetColumnInfo(NIL, T, FormatPtr^.ProgressColumnID, ColumnName,
                  HIGH(s), DataRecord);
    LJust (DataRecord.StringValue);
    TrimRear( DataRecord.StringValue );
    Copy(DataRecord.StringValue, s);
END GetProgressColumnName;




PROCEDURE GetMessageWord    (   PhraseNumber    : CARDINAL;
                                WordNum         : CARDINAL;
                            VAR s               : ARRAY OF CHAR );
VAR
    s2              : ARRAY [0..30] OF CHAR;

BEGIN
    GetMessage (PhraseNumber, s2);
    WordNumber (s2, WordNum, s);
END GetMessageWord;




PROCEDURE GrepPage(    StripNumber,
                       PageNumber       : CARDINAL;
                       StartDate        : ADate;
                       Scale            : ADuration;
                       ScaleRange       : ADurationUnit;
                       DateStyle        : ADStyle;
                       LeftMargin,
                       RightMargin      : CARDINAL;
                   VAR MoreStrip        : BOOLEAN;
                   VAR TaskNode         : ATreeNode;
                       Option           : ATagType);
CONST
    LegendLines = 4;
        (* If the end line captions, below, are changed, also change the
           ELColumnX values here which give the horizontal offset to the
           characters appearing in the end lines. *)
    ELColumn1  = 1;
    ELColumn2  = 23;
    ELColumn3  = 46;
    ELMaxColumn = 65;   (* This is the length of the longest legend line *)

VAR
    i,j,n                  : CARDINAL;
    PrintMode              : CARDINAL;
    ExtraTagSize           : CARDINAL;
    FirstColumn            : CARDINAL;
    Columns                : CARDINAL;
    ExtraColumns           : CARDINAL; (* So we can put in tags *)
    BarColumns             : CARDINAL;
    EndLines               : CARDINAL;
    ExtraLines             : CARDINAL;
    Task                   : ATaskPtr;
    BiggerDateStyle        : ADStyle;
    ok, Started, Continues : BOOLEAN;
    C                      : CHAR;
    BlankLine              : ARRAY [0..1] OF CHAR;
    Tag                    : ARRAY [0..40] OF CHAR;  (* report tags *)
        (*  Keep a copy of the second date line so that we can use it
            to decide where to print date alignment dots. *)
    DateLine2 : ARRAY [0..MaxPrtWidth] OF CHAR;  (* Copy of 2nd line. *)
    EarlyExit : BOOLEAN;
    Line, Line2            : ARRAY [0..MaxPrtWidth] OF CHAR;
    Header1, Header2       : ARRAY [0..MaxPrtWidth] OF CHAR;
    ColumnString, s,
    BarsString             : ARRAY [0..MaxPrtWidth] OF CHAR;
    Spaces                 : ARRAY [0..30] OF CHAR;

    PROCEDURE FirstDate;
    VAR
        NewLength : CARDINAL;
        DateArray : ARRAY [0..1] OF ADate; (* Dummy *)
        s         : ARRAY [0..MaxPrtWidth] OF CHAR;

    BEGIN
        Fill(Tag," ",ExtraTagSize);

             (* If possible, do a three-line date line. *)

        IF (BiggerDateStyle > DateStyle) THEN
            IF (FormatPtr^.GanttShowing) THEN
                DateLines (StartDate, Columns, FirstColumn, Scale, ScaleRange,
                           BiggerDateStyle, ChartFont, FALSE, Line, DateLine2, DateArray);
            ELSE
                SetLengthOf (Line, 0);
                SetLengthOf (DateLine2, 0);
            END;
            Insert(Line,Tag,1);
            IF (LengthOf (Header1) <> 0) THEN
                Fill (s, " ", LengthOf (Header1));
                IF ((LengthOf(Line) + LengthOf(s)) > Columns) THEN
                    SetLengthOf (Line, Columns - LengthOf(s));
                END;
                Insert (Line, s, 1);
            END;
            PrintLine(Line,Normal);
        END;

        IF (FormatPtr^.GanttShowing) THEN
            DateLines(StartDate,Columns,FirstColumn,Scale,ScaleRange,
                      DateStyle,ChartFont,FALSE,Line, DateLine2,DateArray);
        ELSE
            SetLengthOf (Line, 0);
            SetLengthOf (DateLine2, 0);
        END;
        Copy (DateLine2, Line2);
        Insert(Line2,Tag,1);
        Insert(Line,Tag,1);
        IF (LengthOf (Header1) <> 0) THEN
            IF ((LengthOf(Line) + LengthOf(Header1)) > Columns) THEN
                NewLength := Columns - LengthOf(Header1);
                SetLengthOf (Line, NewLength);
                SetLengthOf (Line2, NewLength);
                SetLengthOf (DateLine2, NewLength);
            END;
            Insert (Line, Header1, 1);
            Insert (Line2, Header2, 1);
            Insert (DateLine2, Header2, 1);
        END;
        PrintLine(Line,Normal);
        PrintLine(Line2,Normal);
    END FirstDate;


    PROCEDURE PrintOneTaskLine  (LineType   : AGanttLineType);

    VAR
        Font        : AGanttFont;
        Percentage  : CARDINAL;
        HasBase     : BOOLEAN;

    BEGIN
        SetLengthOf (BarsString, 0);
        IF (FormatPtr^.GanttPosition > LeftMargin) THEN
            FormatColumnStrings (LeftMargin, 255, TaskNode, LineType,
                                 ColumnHeading1, s);    (* 11/20/89 EGK *)
            IF (FormatPtr^.GanttPosition < RightMargin) THEN
                SetLengthOf (s, FirstColumn - 1);
            ELSE    
                SetLengthOf (s, Columns);
                MoreStrip := TRUE;
            END;
        ELSE
            SetLengthOf (s, 0);
        END;

        Copy (s, Line);

        IF (FormatPtr^.GanttShowing) THEN

            IF (FormatPtr^.GanttPosition <= RightMargin) THEN

                IF (LineType = Plan) THEN
                    IF (TaskNode^.Methods^.FirstChild (TaskNode) = NIL) THEN
                        Font := ChartFont;
                    ELSE
                        Font := SummaryFont;
                    END;
                ELSE
                    IF (TaskNode^.Methods^.FirstChild (TaskNode) = NIL) THEN
                        Font := BaselineDetailFont;
                    ELSE
                        Font := BaselineSummaryFont;
                    END;
                END;

                Task := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);

                Percentage := 0;
                IF (FormatPtr^.ProgressLineType = LineType) THEN
                    IF (NOT GetColumnPercentage (TaskNode, Task,
                            FormatPtr^.ProgressColumnID, LineType, Percentage)) THEN
                        Percentage := 0;
                    END;
                END;

                (*  See if we will need a continuation strip. *)

                SetGanttLineTask( TaskNode, Task );  (* 25-Jan-91 RSC *)

                GanttLine(TaskNode,LineType,StartDate,AsOfDate,
                          Percentage, BarColumns, 1, Scale,
                          FormatPtr^.slackstyle,Font,BarsString,
                          Started,Continues);

                MoreStrip := MoreStrip OR Continues;

                IF (LineType = Baseline) THEN
                    HasBase := (BaseLineExists IN Task^.TaskFlags);
                END;

                IF (LineType = Plan) OR (HasBase) THEN      (* 4/5/89 EGK *)

                    (*  Format some extra to make installing tags easier. *)
                    GanttLine(TaskNode,LineType,StartDate,AsOfDate,
                              Percentage, ExtraColumns, 1, Scale,
                              FormatPtr^.slackstyle, Font, BarsString,
                              Started,Continues);
                ELSE
                    Fill (BarsString, " ", ExtraColumns);
                END;

                TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);
            END;

            ConcatLS (Line, BarsString);
            SetLengthOf (Line, Columns);

        ELSIF (FormatPtr^.GanttPosition <= RightMargin) THEN
            MoreStrip := FALSE;
        END;

            (*  Put in some vertical lines to help line up the dates.
                we will line these up with the actual dates printed in
                the date lines at the top.  The reason we go with the
                printed lines instead of using FindNextKeyDate is that
                the key dates could be denser than the printed ones. *)

        IF (ReportSettings^.MakeGrid) AND (FormatPtr^.GanttShowing) THEN
            i := FirstColumn;
                (* If there is text to the left of the first date, skip
                   the first date.  Otherwise, print a column of dots in
                   the first column. *)
            IF (FirstColumn > 1) THEN
                FindNextWord(DateLine2,i);
            END;
            LOOP
                IF (i <= Columns) THEN
                    IF (Line[i] = " ") THEN
                        Line[i] := ".";
                    END;
                ELSE
                    EXIT;
                END;
                FindNextWord(DateLine2,i);
            END;
        END;

        IF (TaskIsIn(TaskNode)) AND (TaskIsHighlighted(TaskNode)) THEN     (* 12/05/86 LAA *)
            PrintMode := Bold
        ELSE
            PrintMode := Normal;
        END;
        PrintLine(Line,PrintMode);
    END PrintOneTaskLine;

BEGIN

    IF (ReportSettings^.PrintCaptions) AND (FormatPtr^.GanttShowing) THEN
        EndLines := LegendLines+5;
    ELSE
        EndLines := 3;
    END;

        (* See if we can do a three-line heading. *)

    BiggerDateStyle := DateStyle;
    IF ( UsingWeekNumbers ) THEN                                  (* 11-May-90 *)
       IF (BiggerDateStyle < YearMonth) AND
          (BiggerDateStyle <> MonthDay) THEN
           INC(BiggerDateStyle);
       END;
    ELSE
       IF (BiggerDateStyle < YearMonth) THEN
           INC(BiggerDateStyle);
       END;
    END;

    ExtraTagSize := InsertTag(StripNumber,FirstColumn,Option);

    IF (FormatPtr^.GanttPosition < LeftMargin) THEN
        FirstColumn := 1;
    ELSE
        FirstColumn := FormatPtr^.GanttPosition - LeftMargin + 1;
    END;
    Columns := RightMargin - LeftMargin + 1;
    IF (FirstColumn > Columns) THEN
        BarColumns := 0;
    ELSE
        BarColumns := Columns - FirstColumn + 1;
    END;
    ExtraColumns := BarColumns + TagLength + 4;
    MoreStrip := FALSE;
    Fill(BlankLine," ",0);

        (* Print the report header at the top of the page, or else
           skip enough lines to equal the room that would be printed. *)

    IF (PageNumber=1) OR (ReportSettings^.PrintCaptions) THEN
       IF ((StripNumber = 1) OR (ReportSettings^.PrintCaptions)) THEN
           PageHead;
           FilterNotes(TRUE,    (* Select Filters *)
                       TRUE);   (* Highlight Filters *)
           DateRow1 := RowsLeft();
       ELSE
           StartPage;
           WHILE (RowsLeft() > DateRow1) DO
               PrintLine(BlankLine,0)
           END;
       END;
    ELSE
        StartPage;
    END;

        (* Always print a date line at the top of each page. *)


    IF (FormatPtr^.GanttPosition > LeftMargin) THEN
        FormatColumnStrings (LeftMargin, 255, NIL, Plan,
                             ColumnHeading1, Header1);      (* 11/20/89 EGK *)
        FormatColumnStrings (LeftMargin, 255, NIL, Plan,
                             ColumnHeading2, Header2);
        i := InsertTag (StripNumber, FirstColumn, Option);
        Fill (Spaces, " ", i);
        IF (StripNumber = 1) AND (i > 0) THEN
            Remove (Header1, 256-i, i);
            Remove (Header2, 256-i, i);
            Insert (Header1, Spaces, 1);
            Insert (Header2, Spaces, 1);
        END;
        IF (FormatPtr^.GanttPosition < RightMargin) THEN
            SetLengthOf (Header1, FirstColumn - 1);
            SetLengthOf (Header2, FirstColumn - 1);
        ELSE    
            SetLengthOf (Header1, Columns);
            SetLengthOf (Header2, Columns);
        END;
    ELSE
        SetLengthOf (Header1, 0);
    END;



    IF (FirstColumn <= Columns) THEN
        FirstDate;
    ELSE
        IF (BiggerDateStyle > DateStyle) THEN
            PrintLine (BlankLine, 0);
        END;
        PrintLine (Header1, 0);
        PrintLine (Header2, 0);
    END;
    PrintLine(BlankLine,0);

        (* Print as many tasks as will fit. *)

    EarlyExit := FALSE;

    ExtraLines := 0;
    IF (FormatPtr^.AVPShowing) THEN
        INC (ExtraLines);
    END;
    i := ReportSettings^.Spacing - 1;
    INC (ExtraLines, i);

(*
    IF (RowsLeft() <= EndLines+ExtraLines) AND (NOT Stopped) THEN     (* 2/15/88 EGK *)
        GetMessage (ModuleNumber+1,s);       (* "Not enough room on page" *)
        Error (s);
        Stopped := TRUE;
        RETURN;
    END;
*)

    IF (RowsLeft() <= EndLines+ExtraLines) AND (NOT Stopped) THEN
        EndLines := RowsLeft() - ExtraLines - 1;
    END;

    WHILE (TaskNode <> NIL)        AND
          (NOT Stopped)            AND
          (RowsLeft() > EndLines + ExtraLines)  AND
          (NOT EarlyExit)                  DO

        PrintOneTaskLine (Plan);
        IF (FormatPtr^.AVPShowing) THEN
            PrintOneTaskLine (Baseline);
        END;

        i := ReportSettings^.Spacing - 1;
        WHILE (RowsLeft() > EndLines) AND (i > 0) DO
            PrintLine(BlankLine,0);
            DEC(i);
        END;

        i := TaskNode^.Methods^.IndentationLevel (TaskNode);

        TaskNode := TaskNode^.Methods^.NextForDisplay( TaskNode );
(*
        Force a page break if we just jumped to a task whose level is less
        than or equal to the user-specified page break level. (1 = top)
*)
        IF (ReportSettings^.BreakPages) AND (ReportSettings^.PageBreakLevel > 0)
                AND (TaskNode <> NIL) THEN
            j := TaskNode^.Methods^.IndentationLevel (TaskNode);
            n := ReportSettings^.PageBreakLevel - 1;
            IF ((j <= n) AND (n <= i)) OR (j = n) THEN
                EarlyExit := TRUE;
            END;
        END;

    END;

        (* If we are printing separate pages, move to the bottom of
           the page before printing the caption.  If we are printing
           one long strip we won't do this--because there is no
           bottom to the page. *)

    IF (ReportSettings^.BreakPages) THEN
        IF (TaskNode = NIL) AND (FormatPtr^.GanttShowing) THEN
            EndLines := LegendLines+5;
        END;
        IF (RowsLeft() < EndLines) THEN
            StartPage;
        END;
        WHILE (RowsLeft() > EndLines) DO
            PrintLine(BlankLine,Normal);
        END;
    END;

    IF (Columns < ELMaxColumn) THEN     (* 2/25/88 EGK *)
        Columns := ELMaxColumn;
    END;

    PrintLine(BlankLine,Normal);
    IF (FormatPtr^.GanttShowing) AND (ReportSettings^.PrintCaptions OR (TaskNode = NIL)) THEN
        Fill(Line,"-",Columns+ExtraTagSize);
        PrintLine(Line,Normal);

        IF (StripNumber = 1) OR 
           ((ReportSettings^.BreakPages) AND (ReportSettings^.PrintCaptions)) (* 2-May-91 TGS *)
           THEN 

            GetMessage(ModuleNumber + 3, Line);                    (* "      Detail Task           Summary Task         Baseline" *)
            FOR i := 0 TO 4 DO
                Line[ELColumn1+i] := ChartFont[0];
                Line[ELColumn2+i] := SummaryFont[0];
                Line[ELColumn3+i] := BaselineDetailFont[0];
            END;
            PrintLine(Line,Normal);

            GetMessage(ModuleNumber + 4, Line);                    (* "      (Started)             (Started)            Conflict" *)
            FOR i := 0 TO 2 DO
                Line[ELColumn1+2+i] := ChartFont[0];
                Line[ELColumn2+2+i] := SummaryFont[0];
                Line[ELColumn3+i] := ChartFont[5];
            END;
            FOR i := 0 TO 1 DO
                Line[ELColumn1+i] := ChartFont[2];
                Line[ELColumn2+i] := SummaryFont[2];
            END;
            PrintLine(Line,Normal);

            GetMessage(ModuleNumber + 5, Line);                    (* "      (Slack)               (Slack)                Resource delay" *)
            FOR i := 0 TO 2 DO
                Line[ELColumn1+i] := ChartFont[0];
                Line[ELColumn2+i] := SummaryFont[0];
                Line[ELColumn3+2+i] := ChartFont[0];
            END;
            FOR i := 0 TO 1 DO
                Line[ELColumn1+3+i] := ChartFont[10];
                Line[ELColumn2+3+i] := SummaryFont[10];
                Line[ELColumn3+i] := ChartFont[6];
            END;
            PrintLine(Line,Normal);

            GetMessage (ModuleNumber+10, Line);         (* "Progress shows ~" *)
            GetProgressColumnName (s);
            ConcatLS (Line, s);
            ConcatMessage (Line, ModuleNumber+11);      (* " on " *)
            GetMessageWord (ModuleNumber+12, ORD(FormatPtr^.ProgressLineType)+1, s);
            ConcatLS (Line, s);
            ConcatS(Line,"        ");
            Fill(s, ChartFont[8], 1);
            ConcatLS (Line, s);
            ConcatS(Line," ");
            ConcatMessage (Line, ModuleNumber+13);      (* "MileStone" *)
            PrintLine (Line, Normal);

            Fill (Line, "-", Columns+ExtraTagSize);
            GetMessage(ModuleNumber + 6, Line2);                (* " Scale: " *)
            NameScale (Scale, FormatPtr^.scaleunit, BarsString);
            ConcatLS (Line2, BarsString);
            ConcatMessage(Line2, ModuleNumber + 8);             (* " per character " *)
            Overlay (Line, Line2, 19, LengthOf(Line2));
            PrintLine(Line,Normal);
        ELSE
            FOR i := 1 TO LegendLines DO
                PrintLine(BlankLine,Normal);
            END;
            Fill(Line,"-",Columns+ExtraTagSize);
            PrintLine(Line,Normal);
        END;
    
    END;
    PrintLine(BlankLine,Normal);

    IF (NOT Stopped) THEN
                    (*  123456789 123456789 123456789 123456789 123456789 *)
        GetMessage(ModuleNumber + 7, Line);            (* "TIME LINE Gantt Chart Report, Strip " *)
        CtoS(StripNumber,Line2);
        ConcatLS(Line,Line2);
        IF (ReportSettings^.BreakPages) THEN
            ConcatMessage(Line, ModuleNumber + 9);              (* ", Page " *)
            CtoS(PageNumber,Line2);
            ConcatLS(Line,Line2);
        END;
        ProgressMessage(Line);
        PrintLine(Line,Normal);
    END;
END GrepPage;











PROCEDURE GrepStrip(StripNumber:CARDINAL;
                    StartDate:ADate; Scale:ADuration;
                    ScaleRange : ADurationUnit;
                    DateStyle:ADStyle; LeftMargin, RightMargin : CARDINAL;
                    VAR MoreStrip:BOOLEAN; Option:ATagType);
VAR
    Task                   : ATreeNode;
    PageNumber             : CARDINAL;
    Continues              : BOOLEAN;



BEGIN
    InitTag( TagIndex );
    MoreStrip  := FALSE;
    Task       := TaskTree^.Methods^.GetFirstVisible( TaskTree );
    PageNumber := 0;

    WHILE (NOT Stopped) AND (Task <> NIL) DO
        INC(PageNumber);
        GrepPage(StripNumber,PageNumber,StartDate,Scale,ScaleRange,
                 DateStyle,LeftMargin, RightMargin, Continues,Task,Option);
        MoreStrip := MoreStrip OR Continues;
    END;

END GrepStrip;











PROCEDURE GanttChartReport;

VAR
    Filter         : AFilterRecordPointer;
    TaskNode       : ATreeNode;
    Task           : ATaskPtr;
    FixedStart,
    NextDate       : ADate;
    StartDate, 
    EndDate        : ADate;
    SchedStartDate : ADate;
    SchedEndDate   : ADate;
    StripNumber, 
    OurFirstColumn : CARDINAL;
    OurLeftMargin, 
    OurRightMargin : CARDINAL;
    Columns, i     : CARDINAL;
    TempDate       : ADate;
    Scale          : ADuration;
    More, 
    ok             : BOOLEAN;
    s              : ARRAY [0..81] OF CHAR;
    DateStyle      : ADStyle;
    NextScale,
    ScaleRange     : ADurationUnit;
    BarsVisible    : BOOLEAN;
    UserEndDate    : BOOLEAN;
    Copyright      : ARRAY[0..50] OF CHAR;

BEGIN                       (* GanttChartReport *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    s[0] := 0C;
    Message(s);
    FormatPtr := CurrentLayout();

    Scale          := FormatPtr^.scale;
    ScaleRange     := FormatPtr^.scaleunit;
               

    IF (NOT StartReport()) THEN RETURN; END;


        (*  Pick the starting and ending dates for the report. *)

    SchedStartDate := MAXDATE;
    SchedEndDate   := 0;
    StartDate      := AsOfDate;
    EndDate        := AsOfDate;

    TaskNode := TaskTree^.Methods^.GetFirstVisible(TaskTree);
    WHILE (TaskNode <> NIL) DO
        Task := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
        FixedStart := BigTimeToCalendarTime( Task^.UserEnteredStartDate );  (* 12-Sep-90 RSC *)
        IF (FixedStart < SchedStartDate) THEN
            SchedStartDate := FixedStart;
        END;
        WITH Task^.Plan.Dates DO
            IF (EarlyEnd >= SchedEndDate) THEN
                SchedEndDate := EarlyEnd;
                IF (EarlyEnd = EarlyStart) THEN
                    INC(SchedEndDate, Scale);
                END;
            END;
        END;
        IF ( ( FormatPtr^.AVPShowing) AND (BaseLineExists IN Task^.TaskFlags)) THEN
            WITH Task^.BaseLine.Dates DO
                IF (EarlyStart < SchedStartDate) THEN
                    SchedStartDate := EarlyStart;
                END;
                IF (EarlyEnd >= SchedEndDate) THEN
                    SchedEndDate := EarlyEnd;
                    IF (EarlyEnd = EarlyStart) THEN                  (* 28-Nov-88 LAA *)
                        INC(SchedEndDate, Scale);
                    END;
                END;
            END;
        END;
        TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);
        TaskNode := TaskNode^.Methods^.NextForDisplay (TaskNode);
    END;

    IF (LengthOf (ReportSettings^.StartDate) = 0) OR
            (NOT FormatPtr^.GanttShowing) OR            (* 3/7/88 EGK *)
            (NOT StoTimeU (ReportSettings^.StartDate, StartDate)) THEN
        StartDate := SchedStartDate;
    END;

    IF (LengthOf (ReportSettings^.EndDate) = 0) OR
            (NOT FormatPtr^.GanttShowing) OR            (* 3/7/88 EGK *)
            (NOT StoEndTimeU (ReportSettings^.EndDate, EndDate)) OR
            (EndDate < StartDate) THEN
        UserEndDate := FALSE;
        EndDate := FindNextKeyDate(SchedEndDate, ScaleRange);
    ELSE
        UserEndDate := TRUE;
    END;

        (*  Check to be sure the StartDate is before the EndDate.  *)

    IF (StartDate >= EndDate) THEN                                (* 23-May-89 LAA *)
        EndDate := FindNextKeyDate(StartDate, ScaleRange);
    END;

(*
        IF (RevealFilter <> NIL) THEN
            Filter := RevealFilter^.Methods^.LockFlexStorDataObject (RevealFilter);
            WITH Filter^ DO                                 (* 11/20/86 LAA *)
                IF (QueryRevealFilterOn()) AND (TestFilterBit (fltrset, FDate)) THEN
                    EndDate := enddate;
                    IF (startdate > StartDate) AND
                            (LengthOf (ReportSettings^.StartDate) = 0) THEN
                        StartDate := startdate;
                    END;
                END;
            END;
            RevealFilter^.Methods^.UnlockFlexStorDataObject (RevealFilter);   Filter := NIL;
        END;
*)


        (*  If we are not going to do page breaks, then turn off all
            automatic perforation skipping. *)

    IF (NOT ReportSettings^.BreakPages) THEN
        AllowUnlimitedPageLength(TRUE);
    END;

    StripNumber    := 1;
    OurLeftMargin  := 1;

    (* RSC 19-Sep-89 In order to start the report on an even time slice, so
                     the date bars show up correctly, back off the start
                     date to the start of the next higher unit.  For example,
                     If Hours, back off to the start of this day.
                     BUG # 1362

       RSC 22-Sep-89 Well, lets try again.... The case above worked in many
                     cases, but not for cases like "180 minutes" or
                     "4 hours", where logic below will ajust to a much higher
                     scale for the captions.

                     KLUGE:  I can't figure out the right way to handle this
                             in the time alloted (we freeze 4.0 code today
                             and its now 4:45PM), so I will try to make
                             an even better guess, using DownScale.
    *)
(*      KKC Nov 16, 89
    NextScale := ScaleRange;

    WHILE (DownScale( Scale * 8, NextScale ) > 1) AND
          (NextScale < Weeks) DO
        INC(NextScale);
    END;
*)

    CASE ScaleRange OF
    | Minutes: 
        NextScale := Days;
    | Hours:
        IF ( Scale < 4 ) THEN
            NextScale := Days;
        ELSE
            NextScale := Weeks;
        END;
    | Days:
        NextScale := Weeks;
    ELSE
        NextScale := ScaleRange;
    END;

    StartDate := FindStartDateOf( StartDate, NextScale );
    TempDate := FindNextKeyDate(StartDate, NextScale);
    IF ( EndDate < TempDate ) THEN
        EndDate := TempDate;
    END;


            (*  Print all the strips. *)

    LOOP


            (*  Find out how many columns are available for us to
                use in printing.  
            *)

        Columns := PageWidth();

        IF (FormatPtr^.GanttPosition < OurLeftMargin) THEN
            OurFirstColumn := 1;
        ELSE
            OurFirstColumn := FormatPtr^.GanttPosition
                    - OurLeftMargin + 1;
        END;

        BarsVisible := (OurFirstColumn <= Columns) AND FormatPtr^.GanttShowing;

        (*                                                        
        DEC(Columns,InsertTag(StripNumber,OurFirstColumn,ReportSettings^.TagType));
        *)

            (* Set next date to the first date to print on the NEXT strip. *)

        IF (BarsVisible) THEN
            StartDate := FindStartDateOf (StartDate, ScaleRange);       (* 3/1/88 EGK *)

            LOOP
                TempDate := StartDate;
                ok := CheckScale(Columns, OurFirstColumn, TempDate, Scale,
                                 ScaleRange, DateStyle);
                IF ((TempDate = StartDate) OR (Columns < OurFirstColumn)) THEN
                    EXIT;
                END;
                DEC(Columns);
                IF (Columns = 0) THEN
                    EXIT;
                END;
            END;

            IF (((MAXDATE-StartDate) DIV Scale) > (Columns-OurFirstColumn+1)) THEN  (* 30-Nov-88 LAA *)
                NextDate := StartDate + ((Columns-OurFirstColumn+1) * Scale);
            ELSE
                NextDate := MAXDATE;
            END;
            NextDate := FindStartDateOf(NextDate,ScaleRange);

            IF (EndDate < NextDate) THEN                        (* 3/1/88 EGK *)
                NextDate := FindNextKeyDate (EndDate-1, ScaleRange);
            END;

                 (* Now figure out how many columns will really be used.  *)
           
            IF (NextDate < StartDate) THEN  (* 4/18/89 EGK *)
                NextDate := StartDate;      (* Forget the gantt bars on this strip *)
            ELSE
                Columns := OurFirstColumn-1 + ((NextDate - StartDate) DIV Scale);
            END;

            IF (Columns = 0) THEN
                EXIT;
            END;
            
        ELSE
            NextDate := StartDate;
            AdjustColumns (OurLeftMargin, Columns);     (* 2/25/88 EGK *)
        END;

        OurRightMargin := OurLeftMargin + Columns - 1;


                (* Since we can print YearMonthDay as well as
                   MonthDay, never go beyond MonthDay.  GrepStrip
                   will also fill in the year if we use MonthDay. *)

        IF (DateStyle > MonthDay) THEN
            DateStyle := MonthDay;
        END;



        GrepStrip (StripNumber,StartDate,Scale,ScaleRange,DateStyle,
                   OurLeftMargin, OurRightMargin, More, ReportSettings^.TagType);

        INC(StripNumber);

        StartDate := NextDate;

        IF (UserEndDate) THEN
            More := TRUE;
        END;

            (* If we are not doing page breaks, then turn off the
               left margin so that the pages can be pasted next to
               each other more easily. *)

        IF (NOT ReportSettings^.BreakPages) THEN
            AllowLeftMargin(FALSE);    (* Suppress left margins.       *)
        END;

        INC (OurLeftMargin, Columns);

        IF (NOT More) OR (Stopped) OR (StartDate > EndDate) 
                                   OR (StartDate > (MAXDATE - Scale)) THEN
            EXIT;
        END;

    END;

    IF (NOT Stopped) THEN
        ProgressMessage(s);
    END;

    EndReport;

END GanttChartReport;






BEGIN

    IF (TasksInMemory()) AND (DoPrintDialog()) THEN
        GanttChartReport;
    END;

END TLGR.

