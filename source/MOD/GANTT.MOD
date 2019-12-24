(*V1=OS2 OS2 code changes.	  *)
(*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE Gantt;

    (* WARNING !!  WARNING !!  THIS MODULE CONTAINS ASSEMBER CODE!!!!! *)

    (* MODIFICATION HISTORY:

       Aug. 13, 1985   AJL - Modified CheckScale to not reduce scale
                             even if chart would not all fit on screen.
                             Modified DateLines and GanttLine to only
                             format up to MAXCARDINAL.
                           - Change DateLines to move the official date
                             of the first date printed to the next key
                             date if it is not a key date.  This
                             supports the Gantt Report.
       Aug. 18, 1985   AJL - Removed the change of date (#2, above).
                           - Synchronized second date line with first
                             by commenting-out second calls to
                             BuildDateArray.
                           - Rearranged loop in build date array to
                             scan forward over first column if not on
                             a date boundary.

      Dec. 17, 1986    AJL - Used a value, LastDate, inside the DateLines
                             procedure to terminate the loop before actually
                             running out of the entire range of dates.

      May   6, 1986    RSC - PLACED TIME BOMB IN HERE FOR LARRY OR WHOEVER
                             IS NEXT TO EDIT THIS.  I HAD REMOVED STATUS
                             AND STATUS2 FROM THE TASK RECORD.  INSTEAD,
                             THOSE FIELDS NEED "ATASKSTATUS" FROM ALLOCS,
                             WHICH I HAVE THOUGHTFULLY IMPORTED.  LOOK
                             AROUND LINE 800 FOR "NOTYETIMPLEMENTED".
        25-May-87 LAA   In GanttLine, commented out code for doing the
                        resource list.  That's now done in GanttView.
        10-Jun-87 LAA   GanttLines now uses new fonts to show baseline, and
                        percent complete.
        27-Jul-87 LAA   Removed AColumnName, which is no longer an enumerated
                        type.  Forced GanttLines and DateLines to start at 1.
        17-Aug-87 LAA   Recoded main loop of GanttLines in assembler.
         5-Nov-87 RSC   Word aligned all routines except GanttLine, because
                        it contains assembler code.  Made Started tasks
                        show same slippage chars as fixed-date tasks.
        23-Dec-87 LAA   The baseline symbol was being made a milestone if the
                        actual (not baseline) duration was zero.  Changed to
                        test for EarlyStart = EarlyEnd.
        11-Jan-88 LAA   Changed UnlockFlexStorDataObject to UnlockUnchanged.
        16-Mar-88 LAA   Fixed bug in GanttLine which would cause the completed
                        portion of task bars to be wrong if the task was too
                        long and the percent complete was high.  Oops!
        21-Dec-88 LAA   Changed imports for Laslo reorganization.
        16-Mar-89 AJL   Cleaned up a sloppy IF statement in "GanttLine".
        22-Mar-89 EGK   Added support for "Percentage" parameter in GanttLine.
        05-Aug-89 WKH   Initial OS/2 edits.  Change code in GanttLine to
                        reflect new procedure activation record structure.
        02-Apr-90 MWP   Weeknumber support added.
         9-Apr-90 RSC   Timei/TimeFormat changes.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 

        11-Sep-90 RSC   Fixups for Andrew's Allocs DEF changes.
        17-Sep-90 AJL   Changed the offsets within the assambler code because
                        of the change in size of ADateBlock.
        27-Oct-90 RSC   StdDay is now in HalfHours, not Hours.
        25-Jan-91 RSC   Added "SetGanttLineTask".
         6-Mar-91 AJL   Made the GanttLine procedure look at both the 
                        SupposedToStart and UserEnteredStart fields.
         1-Apr-91 AJL   Corrected GanttLine so that it shows the skid
                        marks only for FixedDate tasks and those that
                        have negative total slack.
        15-Apr-91 AJL   In GanttLine, only show Negative Slack if the 
                        format calls for displaying slack.
         1-Jul-91 AJL   Allow slack on fixed date tasks.  Bug 4623.
        14-Aug-91 LAA   Bug #4874.  GanttLine had never been fixed up to
                        allow for both resource delay markers and negative
                        slack (conflict) markers.  This unfortunately
                        required futzing with Assembler, but it also gave
                        me an opportunity to word-align the procedure
                        variables, which should speed things up slightly.
        27-Sep-91 LAA   Delay markers were not showing for fixed-date tasks
                        which had been delayed by dependencies.
        30-Sep-91 AJL   Tasks which are marked NoSoonerStart (or MustStart)
                        will show delay marks, but tasks which are merely
                        NoLaterStart will not.
        04-Oct-91 LAA   A part of GanttLine was still implicitly assuming 
                        that LateXXXEnd dates were greater than EarlyXXXEnd
                        dates, which is no longer true with negative slack.
                        This was showing up for milestones.  I fixed it to
                        only adjust the lastday if a LateXXXEnd was greater
                        than the realend.
                        I also had to adjust the ShouldStart to be the
                        earlier of the SupposedToStart (CPM start date) and
                        the LateXXXStart, so that negative slack could be
                        shown.
        05-Mar-92 TGS   DOWsto used a string only 10 characters long, not
                        long enough for (e.g.) Russian day names, which are
                        up to 11 characters long. I made it 18.
    *)

FROM Allocs    IMPORT   AFixType, ATaskPtr, CheckTaskValid,
                        ATaskFlag,
                        ATaskStatus, AStartStatus, ADateBlock;

FROM BigTimeU  IMPORT
    (* PROC *)          CompareBigTimes;

FROM Captions               IMPORT
    (* PROC *)                  ResourceNameList;

FROM ChartForms     IMPORT   CurrentChartFormat;   (**** Temporary *****)

FROM Dialog                 IMPORT
                                Message, FatalError, NotYetImplemented;

FROM LStrings               IMPORT
                                SetString, ConcatS, ConcatLS, SubStr, Insert,
                                CtoS, Fill, TrimRear, Overlay, Procustes;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, DisplayMessage, ConcatMessage;

FROM SYSTEM                 IMPORT
    (* PROC *)                  CODE;

FROM TimeFormat             IMPORT
    (* TYPE *)                  AMonthString, ADateString,
    (* VAR  *)                  DefaultTimeFormat,
    (* PROC *)                  TimeToString, CtoDay, CtoM;

FROM TimeJump               IMPORT
    (* PROC *)                  FindNextKeyDate, FindPriorKeyDate,
                                FindStartDateOf;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate, ADuration, ADurationUnit, ATimeInfo,
    (* PROC *)                  TimeUtoT,  TtoTimeU, DayOfWeek;

FROM Timeu                  IMPORT
    (* VAR *)                   SMUPH, TimeTable,
    (* PROC *)                  UpScale;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM WeekNumberInfo      IMPORT                                (* 2-Apr-90 MWP *)
    (* VAR *)                   UsingWeekNumbers,
    (* PROC *)                  TimeUToWeekNumber,
    (* PROC *)                  TimeToWeekNumber;


CONST
    ModuleNumber   = 1000;    (*  For GetMessage. *)
    MinDateSpacing = 2;       (*  Minimum Columns per date. *)
    MAXCARDINAL  = 0FFFFH;    (*  Largest possible cardinal number. *)
    ComputationLimit = MAXCARDINAL DIV 100;  (* For GanttLine *)






PROCEDURE gcd(x,y:CARDINAL):CARDINAL;
BEGIN
    WHILE (x <> y) DO
        IF (x > y) THEN DEC(x,y);
        ELSE DEC(y,x);
        END;
    END;
    RETURN x;
END gcd;


    (*  Compute a multiplier of b so that M*b is evenly divided by a *)


PROCEDURE Align(a,b:CARDINAL):CARDINAL;
BEGIN
    RETURN a DIV gcd(a,b);
END Align;






    (* ComputeScaleRange -- Given LineScale, which is the time scale
                            for each column on the Gantt Chart, compute
                            whether the time lines at the top should
                            show minutes, hours, days, weeks, months,
                            or years. *)

PROCEDURE ComputeScaleRange(LineScale:ADuration):ADurationUnit;
CONST
    MinimumMaxCPD = 10;
VAR
    CPD,                  (* Columns per date. *)
    w        : CARDINAL;
    Quantity : ADuration;
    Table    : ARRAY ADurationUnit OF RECORD
                                      Grouping   : CARDINAL;
                                      MaxCPD     : CARDINAL;
                                  END;
    TimeUnit : ADurationUnit;
    s        : ARRAY [0..60] OF CHAR;
BEGIN
    IF (LineScale = 0) THEN FatalError; END;


        (* Decide how many columns apart the date markings will be.

          Try to print in multiples of weeks, then try days, then try
          hours, and finally resort to minutes if necessary.

        *)

    Table[Minutes].Grouping := SMUPH;
    Table[Hours].Grouping   := (TimeTable.StdDayTics + (SMUPH DIV 2)) DIV SMUPH;  (* 1-Nov-90 RSC *)
    Table[Days ].Grouping   := TimeTable.StdWeek;
    Table[Weeks].Grouping   := 4;
    Table[Months].Grouping  := 12;
    Table[Years].Grouping   := 10;

        (*  Decide the minimum spacing for each possible time scale.
            If the scale produces date synchronization in this or fewer
            columns, use that scale.
            *)

    TimeUnit := Years;
    WHILE (TimeUnit > Minutes) DO
        w := Table[VAL(ADurationUnit,ORD(TimeUnit)-1)].Grouping;
        IF (w < MinimumMaxCPD) THEN
            w := MinimumMaxCPD;
        END;
        Table[TimeUnit].MaxCPD := w;
        DEC(TimeUnit);
    END;



        (* Pick a starting point for our TimeUnit search.  If
           we are doing more than 15 divisions per hour, it would
           be difficult to even contain a full year, so don't
           try.  This avoids the error messages produced by
           UpScale. *)

    IF (SMUPH > 15) THEN
        TimeUnit := Months;
    ELSE
        TimeUnit := Years;
    END;



    LOOP
        IF (TimeUnit <= Minutes) THEN EXIT; END;
        Quantity := UpScale(1,TimeUnit);
        CPD := Align(Quantity,LineScale);
            (* Exit if the scale is larger than the amount of time in the
               current time unit. *)
        IF (LineScale >= Quantity) THEN
            IF (TimeUnit < Years) THEN
                INC(TimeUnit);
            END;
            EXIT;
        END;
            (* Exit if the number of columns between weeks, hours, etc.
               is acceptably small. *)
        IF (CPD <= Table[TimeUnit].MaxCPD) THEN
            EXIT;
        ELSE
            DEC(TimeUnit);
        END;
    END;

    IF (CPD = 0) THEN
        FatalError;
    END;

    RETURN TimeUnit;

END ComputeScaleRange;





    (* DATELINES -- Produce the two line caption that appears at the
                    top of a Gantt chart. *)

PROCEDURE DateLines ( StartDay : ADate;
                      Columns, FirstColumn : CARDINAL;
                      Scale : ADuration;
                      ScaleRange : ADurationUnit;
                      Style : ADStyle;
                      VAR Font:AGanttFont;
                      ScreenFlag : BOOLEAN;
                      VAR Line1, Line2 : ARRAY OF CHAR;
                      VAR DateArray : ARRAY OF ADate );
CONST
    maxcolumns = MaxPrtWidth;
    maxdates   = maxcolumns DIV MinDateSpacing;
CONST
    MinForWho = 10;       (* Minimum name width before dropping headings. *)
    MinForStatus = 10;
TYPE
    ADecodedDateArray = ARRAY [0..maxdates] OF RECORD
                    TimeInfo : ATimeInfo;
                     Column  : CARDINAL;
                 END;
VAR
    i           : CARDINAL;
    Column      : CARDINAL;
    numdates    : CARDINAL;
    dates       : ADecodedDateArray;
    sm          : ARRAY [0..25] OF CHAR;


    PROCEDURE PlugDate(Date:ADate; Column:CARDINAL);
    BEGIN
        IF (Column-1 <= HIGH(DateArray)) THEN
            DateArray[Column-1] := Date;
        END;
    END PlugDate;


    PROCEDURE MoveText( VAR  Source : ARRAY OF CHAR;
                        VAR  Target : ARRAY OF CHAR;
                             col    : CARDINAL;
                        VAR  NextCol: CARDINAL   );
    VAR
        j : CARDINAL;
    BEGIN
        NextCol := col;
        FOR j := 1 TO ORD(Source[0]) DO
            IF (NextCol <= HIGH(Target)) THEN
                Target[NextCol] := Source[j];
            END;
            INC(NextCol)
        END;
    END MoveText;


    PROCEDURE MakeTwoDigits(  VAR S : ARRAY OF CHAR);
    VAR
        S2   : ARRAY [0..1] OF CHAR;
    BEGIN
        IF (S[0] = 1C) THEN
           Fill(S2,"0",1);
           Insert(S,S2,1);
        END;
    END MakeTwoDigits;


    PROCEDURE hoursto (VAR s:ARRAY OF CHAR);
    VAR
        i, col, NextColumn,
        k, OurHour, OurMinute : CARDINAL;
        SpaceNeeded           : CARDINAL;
        ts                    : ARRAY [0..20] OF CHAR;
        LTimeInfo             : ATimeInfo;
    BEGIN
        NextColumn := 0;
        i := 1;
        WHILE (i <= numdates) DO
            col := dates[i].Column;
            IF (col >= NextColumn) THEN
                k := col;
                WITH dates[i] DO
                    OurHour := TimeInfo.tiHour;
                    OurMinute := TimeInfo.tiMinute;
                END;

                LTimeInfo.tiYear := 64;
                LTimeInfo.tiMonth := 7;
                LTimeInfo.tiDay := 16;
                LTimeInfo.tiHour := OurHour;
                LTimeInfo.tiMinute := OurMinute;
                TimeToString (LTimeInfo,DefaultTimeFormat,ts);
                MoveText(ts,s,k,NextColumn);
            END;
            INC(i);
        END;
    END hoursto;

    PROCEDURE daysto (VAR s:ARRAY OF CHAR);
    VAR
        i, col, NextColumn : CARDINAL;
        Date, LastDate     : CARDINAL;
        ns                 : ARRAY [0..6] OF CHAR;
    BEGIN
        i := 1;
        NextColumn := 0;
        LastDate   := 99;  (* Prevent match on first time. *)
        WHILE (i <= numdates) DO
            col := dates[i].Column;
            IF (col >= NextColumn) THEN
                Date := dates[i].TimeInfo.tiDay;
                IF (Style >= MonthDay) OR
                   (Date <> LastDate) THEN
                    CtoS(Date,ns);
                    Procustes(ns,2);        (* Make all dates 2 cols. *)
                    MoveText(ns,s,col,NextColumn);
                    INC(NextColumn);
                    LastDate := Date;
                END;
            END;
            INC(i);
        END;
    END daysto;


    PROCEDURE DOWsto (VAR s:ARRAY OF CHAR);
    VAR
        i, col, NextColumn : CARDINAL;
        ns                 : ARRAY [0..18] OF CHAR;
    BEGIN
        i := 1;
        NextColumn := 0;
        WHILE (i <= numdates) DO
            col := dates[i].Column;
            IF (col >= NextColumn) THEN
                WITH dates[i] DO WITH TimeInfo DO
                    CtoDay(DayOfWeek(tiYear,tiMonth,tiDay),ns);
                END; END;
                Procustes(ns,3);
                MoveText(ns,s,col,NextColumn);
                INC(NextColumn);
            END;
            INC(i);
        END;
    END DOWsto;




    PROCEDURE monthsto (VAR s:ARRAY OF CHAR);
    VAR
        i, col, NextColumn : CARDINAL;
        Month, LastMonth   : CARDINAL;
        sm                 : AMonthString;
    BEGIN
        i := 1;
        NextColumn := 0;
        LastMonth  := 99;
        WHILE (i <= numdates) DO
            col := dates[i].Column;
            IF (col >= NextColumn) THEN
                Month := dates[i].TimeInfo.tiMonth;
                IF (Month <> LastMonth) THEN
                    CtoM(Month,sm);
                    MoveText(sm,s,col,NextColumn);
                    LastMonth := Month;
                END;
            END;
            INC(i);
        END;
    END monthsto;



    PROCEDURE yearsto (VAR s:ARRAY OF CHAR);
    VAR
        i, col, NextColumn : CARDINAL;
        Year, LastYear     : CARDINAL;
        sm                 : ARRAY [0..4] OF CHAR;
    BEGIN
        i := 1;
        NextColumn := 0;
        LastYear  := 9999;
        WHILE (i <= numdates) DO
            col := dates[i].Column;
            IF (col >= NextColumn) THEN
                Year := dates[i].TimeInfo.tiYear MOD 100;
                IF (Year <> LastYear) THEN
                    CtoS(Year,sm);
                    MakeTwoDigits(sm);
                    MoveText(sm,s,col,NextColumn);
                    LastYear := Year;
                END;
            END;
            INC(i);
        END;
    END yearsto;


    PROCEDURE weeksto (VAR s:ARRAY OF CHAR);                        (* 2-Apr-90 MWP *)
    VAR
        i, col, NextColumn  : CARDINAL;
        Month, LastWeek     : CARDINAL;
        sm                  : AMonthString;
        WeekNumber, WeekDay : CARDINAL;
        Year, Hour, Minute  : CARDINAL;
        LYear, LMonth, LDay, LHour, LMinute : CARDINAL;
        ok                  : BOOLEAN;

    BEGIN
        i := 1;
        NextColumn := 0;
        LastWeek   := 99;

        WHILE (i <= numdates) DO
            col := dates[i].Column;
            IF (col >= NextColumn + 1) THEN

                LYear   := dates[i].TimeInfo.tiYear;
                LMonth  := dates[i].TimeInfo.tiMonth;
                LDay    := dates[i].TimeInfo.tiDay;
                LHour   := dates[i].TimeInfo.tiHour;
                LMinute := dates[i].TimeInfo.tiMinute;

                ok := TimeToWeekNumber ( LMonth,
                                         LDay,
                                         LHour,
                                         LMinute,
                                         LYear,
                                         WeekNumber,
                                         WeekDay );


                IF ( WeekNumber <> LastWeek ) THEN
                    CtoS(WeekNumber, sm );
                    MoveText(sm,s,col,NextColumn);
                    LastWeek := WeekNumber;
                END;
            END;

            INC(i);
        END;

    END weeksto;



    PROCEDURE ticsto (VAR s:ARRAY OF CHAR;c:CHAR);
    VAR
        i, col : CARDINAL;
    BEGIN
        i := 1;
        WHILE (i <= numdates) DO
            col := dates[i].Column;
            s[col] := c;
            INC(i);
        END;
    END ticsto;


    PROCEDURE BuildDateArray(ScaleRange:ADurationUnit;FirstColumn:CARDINAL;
                             StartDay : ADate; Columns: CARDINAL;
                             Scale : ADuration;
                             VAR dates: ADecodedDateArray;
                             VAR numdates : CARDINAL);
    VAR
        Col, OldColumn : CARDINAL;
        day, nextday   : ADate;
        LastDate       : ADate;     (* AJL Dec. 17, 1986 *)
        FirstTime      : BOOLEAN;
    BEGIN
        numdates := 0;
        Col := 1;
        day := FindPriorKeyDate(StartDay,ScaleRange);
        LastDate := FindPriorKeyDate(MAXCARDINAL,ScaleRange);      (* AJL Dec 17, 1986 *)
        FirstTime := TRUE;

        WHILE (Col <= Columns) AND (day < LastDate) DO             (* AJL Dec 17 1986 *)

                (* Find a date that is on the appropriate TimeUnit
                   boundary (day,week, etc.) and is at least the
                   minimum number of columns in the future.   An
                   exemption to the minimum columns test is
                   appropriate for the first column. *)

            OldColumn := Col;
            nextday := day;
            REPEAT
                    (* Try a new date and column. *)
                nextday := FindNextKeyDate(nextday,ScaleRange);
                Col := ((nextday-StartDay) DIV Scale) + FirstColumn;
            UNTIL
                (Col-OldColumn >= MinDateSpacing) OR
                (FirstTime) OR
                (nextday >= LastDate);                             (* AJL Dec. 17, 1986 *)

            FirstTime := FALSE;

                (* Move on to the next column and the next date. *)
            day := nextday;

            IF (Col <= Columns) THEN

                    (* Fill in the dates array with an entry for a day and
                       the column where it goes. *)
                INC(numdates);
                IF (numdates > HIGH(dates)) THEN FatalError; END;
                WITH dates[numdates] DO WITH TimeInfo DO
                    TimeUtoT(day, TimeInfo);
                    Column := Col;
                END; END;

                    (* Record that as the official date for the column. *)

                PlugDate(day,Col);

            END;

        END;  (* End of LOOP *)

        (* Make sure that the date displayed is the start of a
           period.   This adjustment will be overwritten when
           BuildDateArray is called for the top line. *)


    END BuildDateArray;






BEGIN
    IF (Scale < 1) THEN FatalError END;

    FirstColumn := 1;                                             (* 27-Jul-87 LAA *)

    Fill(Line1, " ", Columns);
    Fill(Line2, " ", Columns);

        (*  Build a basic list of dates. *)

    Column := FirstColumn;
    i := StartDay;
    WHILE (Column <= Columns) DO
        PlugDate(i,Column);
        INC(i,Scale);
        INC(Column);
    END;

    BuildDateArray(ScaleRange,FirstColumn,StartDay,Columns,Scale,
                   dates,numdates);



        (* Move dates from the arrays to the output strings. *)

    CASE Style OF
        HourMinute:
                     ticsto(Line2,37C);
                     (*
                         (* Synchronize these on hour boundaries. *)
                     BuildDateArray(Hours,FirstColumn,StartDay,Columns,Scale,
                                    dates,numdates);
                     *)
                     hoursto(Line1);
      | DayHour:
                     IF (NOT ScreenFlag) OR
                        (dates[1].TimeInfo.tiDay <> dates[numdates].TimeInfo.tiDay) THEN
                         hoursto(Line2);
                         (*
                             (* Synchronize these on day boundaries. *)
                         BuildDateArray(Days,FirstColumn,StartDay,Columns,Scale,
                                        dates,numdates);
                         *)
                         IF ( UsingWeekNumbers = FALSE ) THEN       (* 2-Apr-90 MWP *)
                            daysto(Line1);
                         ELSE
                            weeksto(Line1);
                         END;
                     ELSE
                         hoursto(Line1);
                         ticsto(Line2,37C);
                     END;
      | MonthDay:
                     IF (NOT ScreenFlag) OR
                        (dates[1].TimeInfo.tiMonth <> dates[numdates].TimeInfo.tiMonth) OR
                        (dates[1].TimeInfo.tiYear <> dates[numdates].TimeInfo.tiYear) THEN
                         IF ( UsingWeekNumbers = FALSE ) THEN       (* 2-Apr-90 MWP *)
                             daysto(Line2);
                             monthsto(Line1);
                         ELSE
                             (* Display the week numbers on line 1.
                                Day of week ( MO, TU, WE etc. on line 2 *)
                             weeksto(Line2);
(*
                             monthsto(Line1);
*)
                             yearsto(Line1);                       (* 17-Apr-90 MWP *)
                         END;
                         (*
                             (* Synchronize these on month boundaries. *)
                         BuildDateArray(Months,FirstColumn,StartDay,Columns,Scale,
                                        dates,numdates);
                         *)
                     ELSE
                         IF ( UsingWeekNumbers = FALSE ) THEN       (* 2-Apr-90 MWP *)
                            DOWsto(Line1);
                            daysto(Line2);
                         ELSE
                             (* Display the week numbers on line 1.
                                Day of week ( MO, TU, WE etc. on line 2 *)
                             DOWsto(Line2);
                             weeksto(Line1);
                         END;
                     END;
      | YearMonth:
                     IF (numdates > 1) AND (dates[1].TimeInfo.tiMonth = dates[2].TimeInfo.tiMonth) THEN
                         ticsto(Line2,37C);
                     ELSE
                         IF ( UsingWeekNumbers = FALSE ) THEN
                             monthsto(Line2);
                         ELSE
                             weeksto(Line2);
                         END;
                     END;
                     (*
                         (* Synchronize these on year boundaries. *)
                     BuildDateArray(Years,FirstColumn,StartDay,Columns,Scale,
                                    dates,numdates);
                     *)
                     yearsto(Line1);
      ELSE FatalError;
    END;



END DateLines;












    (*  CHECKSCALE -- Check that the scale is plausible.  Fix it
                      if not.  Adjust the startdate if necessary to
                      make all of our calculations possible and to
                      make the chart easy to read. *)

    (*  Check, and maybe alter, the parameters for the DateLines
        and GanttLine procedures.  ScaleRange and Style are purely output. *)

PROCEDURE CheckScale (Columns,FirstColumn:CARDINAL; (*columns used for gantt bars*)
                      VAR StartDate: ADate;
                      VAR LineScale : ADuration;
                      VAR ScaleRange : ADurationUnit;
                      VAR Style : ADStyle (* Style of dateline. *)
                     ) : BOOLEAN;
CONST
    MinimumGanttArea = 1;
VAR
    i,
    d, w                : CARDINAL;
    year, month, date,
    hour, minute        : CARDINAL;
    s                   : ARRAY [0..60] OF CHAR;
BEGIN
    IF (FirstColumn > Columns+1-MinimumGanttArea) THEN
        FirstColumn := Columns+1-MinimumGanttArea;
    END;

    IF (FirstColumn <= 0) OR
       (* (FirstColumn > Columns+2) OR *)  (* Superceded by above test. *)
       (Columns > MaxPrtWidth) THEN FatalError END;

        (* Compute the number of columns that must properly pass through
          the formatting algorithm.  This is one more column than will
          actually appear on the screen, in order to keep NEXTDAY in
          GANTTLINE less than MAXWORD. *)

    INC(Columns,3);                 (* Add an extra 1 to the needed 2. *)
    DEC(Columns,FirstColumn);

    IF (Columns = 0) THEN RETURN TRUE END;

        (* Make sure that the start date is not so far out as to make
          it impossible to print the whole chart. *)


    IF (LineScale <= MAXCARDINAL DIV Columns) THEN
        w := MAXCARDINAL - (LineScale * Columns);
        IF (StartDate > w) THEN
            DisplayMessage(ModuleNumber+5);  (* "You are as far right as you can go."  *)
            StartDate := w;
        END;
    END;

        (* Calculate the maximum scale allowed, based on the startdate
           and the number of columns. *)

        (*  Maxcardinal here should be replaced by the maximum legal
            working date. *)

    (*
    w := (MAXCARDINAL - StartDate) DIV Columns;
    IF (w=0) THEN
        w := 1;
    END;
    IF (LineScale > w) THEN
        DisplayMessage(ModuleNumber+6);    (*  "Scale has been reduced to fit."  *)
        LineScale := w DIV 2;
    END;
    *)

    IF (LineScale = 0) THEN LineScale := 1; END;

        (* Figure out how far apart markings should be.  Every minute,
           hour, day, week, month, year or what?  *)

    ScaleRange := ComputeScaleRange(LineScale);

    CASE ScaleRange OF
        Minutes  :    Style := HourMinute;
      | Hours    :    Style := DayHour;
      | Days,
        Weeks    :    Style := MonthDay;
      ELSE            Style := YearMonth;
    END;


    RETURN TRUE;

END CheckScale;







(* $R- $T- $S- *)




(* Set Gantt Line Task

        sets up a shortcut for GanttLine to speed it up a smirch by
        removing the need to lock the task.  Call this before calling
        GanttLine.  This is a separate proc because GanttLine is
        assemblerized.

*)
VAR
    GlobalTaskPtr  : ATaskPtr;
    GlobalTaskNode : ATreeNode;

PROCEDURE SetGanttLineTask( TaskNode : ATreeNode; TaskPtr : ATaskPtr );
BEGIN
    GlobalTaskNode := TaskNode;
    GlobalTaskPtr  := TaskPtr;
END SetGanttLineTask;



    (*  GANTTLINE -- Make one line of a gantt chart.
                    STARTED and CONTINUED tell the caller if any
                    portion of the task's gantt line precedes or
                    follows the portion returned in LINE. *)

PROCEDURE GanttLine (Node               : ATreeNode;
                     LineType           : AGanttLineType;
                     StartDay           : ADate;
                     Today              : ADate;
                     Percentage         : CARDINAL;
                     Columns,
                     FirstColumn        : CARDINAL;
                     LineScale          : ADuration;
                     SlackStyle         : ASlackStyle;
                     VAR Font           : AGanttFont;
                     VAR Line           : ARRAY OF CHAR;
                     VAR Started,
                         Continues      : BOOLEAN );

VAR
    ShouldStart           : ADate;  (* 12-Sep-90 RSC *)
    Task                  : ATaskPtr;
    realstart, realend,
    lastday, day, nextday : ADate;
    i, column             : CARDINAL;
    MaxColumn             : CARDINAL;
    DoneDate              : ADate;
    ConflictDate          : ADate;
    DateBlock             : ADateBlock;
    s                     : ARRAY [0..255] OF CHAR;
    done                  : BOOLEAN;    
    donetime              : CHAR;
    tasktime, delaytime   : CHAR;
    conflicttime          : CHAR;
    PastChar, SlackChar   : CHAR;

BEGIN
    IF (Columns > MaxPrtWidth) OR
       (Columns > HIGH(Line)) THEN   FatalError;
    END;

    FirstColumn := 1;                                             (* 27-Jul-87 LAA *)

        (* Make the line into a string of the correct length filled
          with blanks. *)

    Fill(Line," ",Columns);

        (*  Fill in the chart line. *)

    IF (Node <> NIL) THEN
       IF (GlobalTaskNode <> Node) THEN
           FatalError();
       END;
       Task := GlobalTaskPtr;

       IF (LineType = Baseline) THEN
           DateBlock  := Task^.BaseLine.Dates;
           ShouldStart := DateBlock.EarlyStart;  (* 12-Sep-90 RSC no skids. *)
           ConflictDate := DateBlock.EarlyStart;               (* 14-Aug-91 *)
       ELSIF (LineType = Plan) THEN
           WITH Task^ DO
               DateBlock  := Plan.Dates;
                       (* Choose whether or not, and how, to show delays and conflicts. *)
               ConflictDate := DateBlock.EarlyStart;           (* 27-Sep-91 *)
               day          := ConflictDate;
               IF (StartStatus = DoneS) OR (NoSoonerStart IN TaskFlags) THEN
                   ShouldStart := BigTimeToCalendarTime( UserEnteredStartDate );  (* 6-Mar-91 AJL *)
                   day := ShouldStart;
                   delaytime := ' ';
               ELSE
                      (* SupposedToStart is really the CPM start date *)
                   ShouldStart := BigTimeToCalendarTime( SupposedToStart );       (* 12-Sep-90 RSC *)
                   IF (SlackStyle = NoSlack ) THEN
                       delaytime := ' ';
                   ELSE
                       delaytime := Font[6];  (* Resource-levelling delays. *)
                       IF (SlackStyle = FreeSlack) THEN
                           day := DateBlock.LateFreeStart;
                       ELSE
                           day := DateBlock.LateTotalStart;
                       END;
                   END;
               END;
               conflicttime := Font[5];        (* Negative slack skid marks. *)
                   (* If there is negative slack, show that with skid marks, too. *)
               IF (SlackStyle <> NoSlack) THEN
                   IF (day < ConflictDate) THEN
                       ConflictDate := day;
                   END;
                   IF (ConflictDate < ShouldStart) THEN        (* 04-Oct-91 *)
                       ShouldStart := ConflictDate;
                   END;
               END;
           END;

       ELSE
           FatalError ();
       END;


       WITH Task^ DO


            (* Decide what day the task really starts. *)

        realstart := DateBlock.EarlyStart;

            (* Decide the real end date. *)

        realend := DateBlock.EarlyEnd;

            (* Get the character to use for slack lines. *)

        SlackChar := Font[10];

            (* Pick the character that will represent this task.
               Pick a character based on the task's type and
               StartStatus. *)

        IF (DateBlock.EarlyEnd = DateBlock.EarlyStart) THEN       (* 23-Dec-87 LAA *)
                (* A milestone. *)
            IF (StartStatus = DoneS) THEN
                tasktime := Font[11];   (* filled in milestone *)
            ELSE
                tasktime := Font[8];    (*  Milestone  *)
            END;
            donetime := tasktime;
            realend  := realstart;
            IF (realend < MAXCARDINAL) THEN
                INC( realend );
            END;
        ELSE
            tasktime := Font[FutureBar];     
            donetime := Font[DoneBar];
        END;



            (* Find the last day on which the task may be scheduled.
              If this is a Done task the
              last date is known precisely.  A lastday > realend
              (earlyend) indicates slack. *)

        IF (StartStatus = DoneS) THEN
            SlackStyle := NoSlack;
        END;

        lastday := realend;                                    (* 04-Oct-91 *)
        CASE SlackStyle OF
              TotalSlack:   IF (DateBlock.LateTotalEnd > lastday) THEN
                                lastday := DateBlock.LateTotalEnd;
                            END;
            | FreeSlack:    IF (DateBlock.LateFreeEnd > lastday) THEN
                                lastday := DateBlock.LateFreeEnd;
                            END;
            | NoSlack:      ;
            ELSE            FatalError;
        END;

            (* "i" counts how many Columns until the column that
               will have the scheduled start day of the task. *)

        IF (ShouldStart > StartDay) THEN                   (* 12-Sep-90 RSC *)
            i := ((ShouldStart - StartDay) DIV LineScale);  (* 12-Sep-90 RSC *)
        ELSE
            i := 0;
        END;

        column := FirstColumn + i;

        IF (column > Columns) THEN    (* Make sure we are at most one col. past edge. *)
            column := Columns+1;      (* Otherwise, continuation flag may not be set correctly. *)
            i := column-FirstColumn;
        END;

        day := StartDay + (i * LineScale);

            (* Compute the rightmost column to print. *)

        MaxColumn := FirstColumn - 1 + ( (MAXCARDINAL - StartDay) DIV LineScale );
        IF (Columns > MaxColumn) THEN
            Columns := MaxColumn;
        END;

            (*  Determine a date corresponding to the percent complete *)
        DoneDate := 0;
        IF (Percentage > 0) THEN
                (*  The largest part of the duration we can compute on is:
                    65536 DIV 100.  Do the computation on that amount, then
                    determine how many of these there are within the total
                    duration, and multiply by that amount.  Adjust as best
                    we can for truncation.
                *)
            i := (realend - realstart) DIV ComputationLimit;      (* 16-Mar-88 LAA *)
            DoneDate := realstart +
                        ((ComputationLimit * Percentage) DIV 100) * i
                        + (i DIV 2);

                (*  Take care of the remainder here.  *)
            INC(DoneDate, (((realend - realstart) MOD ComputationLimit)
                           * Percentage) DIV 100);

            (*  This didn't work because of range overflow when
                (realend - realstart) * Percentage was greater than
                65535.

            DoneDate := ((realend - realstart) * Percentage) DIV 100
                        + realstart;
            *)
        END;

            (*  Fill in the task time symbols. *)
        (*
        LOOP
            nextday := day + LineScale;

            IF (column > Columns) THEN
                EXIT;
            ELSIF (nextday <= ConflictDate) THEN               (* 14-Aug-91 *)
                Line[column] := delaytime;
            ELSIF (nextday <= realstart) THEN
                Line[column] := conflicttime;
            ELSIF (day < DoneDate) THEN
                Line[column] := donetime;
            ELSIF (day < realend) THEN
                Line[column] := tasktime;
            ELSIF (day < lastday) THEN
                Line[column] := SlackChar;        (* Slack time. *)
            ELSE
                EXIT
            END;
            day := nextday;
            INC(column);
        END;
        *)

(*<DOS*)
        (* Assembler code is stored at the end of this module.   This 
           assembler in the comments uses HEX numbers which don't compile.
           with MASM. *)

        CODE(
            01EH,                (* PUSH DS                                           *)
      
            08BH,09EH,0E0H,0FEH, (* MOV BX,[column]       ;column->BX                 *)
            08BH,08EH,0DAH,0FEH, (* MOV CX,[day]          ;day->CX                    *)
            08BH,0D1H,           (* MOV DX,CX             ;day->nextday (in DX)       *)
            0C5H,076H,00EH,      (* LDS SI,[Line]         ;Line->DS:SI                *)
            003H,0F3H,           (* ADD SI,BX             ;Line[column]->DS:SI        *)
      
                (* beginloop: *)
            003H,056H,01AH,      (* ADD DX,[LineScale]    ;inc nextday by LineScale   *)
            03BH,05EH,01EH,      (* CMP BX,[Columns]      ;column > Columns?          *)
            077H,04DH,           (* JA  endofloop         ;yes, jump                  *)
            03BH,096H,0E6H,0FEH, (* CMP DX,[ConflictDate] ;nextday <= ConflictDate?   *)
            077H,008H,           (* JA  case2             ;no, jump                   *)
            08AH,046H,0FBH,      (* MOV AL,[delaytime]    ;delaytime->Line[column]    *)
            088H,004H,           (* MOV [SI],AL                                       *)
            0EBH,036H,090H,      (* JMP endofcases                                    *)
      
                (* case2: *)
            03BH,096H,0D4H,0FEH, (* CMP DX,[realstart]    ;nextday <= realstart?      *)
            077H,008H,           (* JA  case3             ;no, jump                   *)
            08AH,046H,0FCH,      (* MOV AL,[conflicttime] ;conflicttime->Line[column] *)
            088H,004H,           (* MOV [SI],AL                                       *)
            0EBH,028H,090H,      (* JMP endofcases                                    *)
            
                (* case3: *)
            03BH,08EH,0E4H,0FEH, (* CMP CX,[DoneDate]     ;day < DoneDate?            *)
            073H,008H,           (* JNB case4             ;no, jump                   *)
            08AH,046H,0F9H,      (* MOV AL,[donetime]     ;donetime->Line[column]     *)
            088H,004H,           (* MOV [SI],AL                                       *)
            0EBH,01AH,090H,      (* JMP endofcases                                    *)
      
                (* case4: *)
            03BH,08EH,0D6H,0FEH, (* CMP CX,[realend]      ;day < realend?             *)
            073H,008H,           (* JNB case5             ;no, jump                   *)
            08AH,046H,0FAH,      (* MOV AL,[tasktime]     ;tasktime->Line[column]     *)
            088H,004H,           (* MOV [SI],AL                                       *)
            0EBH,00CH,090H,      (* JMP endofcases                                    *)
      
                (* case5: *)
            03BH,08EH,0D8H,0FEH, (* CMP CX,[lastday]      ;day < lastday?             *)
            073H,00FH,           (* JNB endofloop         ;no, jump                   *)
            08AH,046H,0FEH,      (* MOV AL,[SlackChar]    ;SlackChar->Line[column]    *)
            088H,004H,           (* MOV [SI],AL                                       *)
      
                (* endofcases: *)
            08BH,0CAH,           (* MOV CX,DX             ;nextday->day               *)
            083H,0C3H,001H,      (* ADD BX,1              ;inc column                 *)
            083H,0C6H,001H,      (* ADD SI,1              ;adjust Line[column]        *)
            0EBH,0ABH,           (* JMP beginloop                                     *)
      
                (* endofloop: *)
            089H,096H,0DCH,0FEH, (* MOV [nextday],DX      ;save nextday value         *)
            089H,08EH,0DAH,0FEH, (* MOV [day],CX          ;save day value             *)
            089H,09EH,0E0H,0FEH, (* MOV [column],BX       ;save columne value         *)
      
            01FH                 (* POP DS                                            *)

            );
(*DOS>*)

(*<OS2
	    CODE(
	        01EH,		         (* PUSH DS				                    *)

	        08BH,09EH,0E6H,0FEH, (* MOV BX,[BP-11C]    column->BX	        *)
	        08BH,08EH,0E0H,0FEH, (* MOV CX,[BP-122]    day->CX		        *)
	        089H,0CAH,		     (* MOV DX,CX	       day->nextday(DX)     *)
	        0C5H,076H,00EH,	     (* LDS SI,[BP+E]      Line->DS,SI	        *)
	        001H,0DEH,		     (* ADD SI,BX	       Add column offset    *)

		        (* begin-of-loop *)
	        003H,056H,01AH,	     (* ADD DX,[BP+1A]     inc nextday by LineScale *)
	        03BH,05EH,01EH,	     (* CMP BX,[BP+1E]     column > Columns?    *)
	        077H,03DH,		     (* JA	end-of-loop    yes, jump.	        *)
	        03BH,096H,0DAH,0FEH, (* CMP DX,[BP-128]    nextday<=realstart?  *)
	        077H,008H,		     (* JA	case2	       no, jump.	        *)
	        08AH,086H,0D9H,0FEH, (* MOV AL,[BP-129]    Line[column]	        *)
	        088H,004H,		     (* MOV [SI],AL        <-delaytime	        *)
	        0EBH,025H,		     (* JMP end-of-cases			            *)

		        (* case2 *)
	        03BH,08EH,0DCH,0FEH, (* CMP CX,[BP-126]    day < realend?	    *)
	        073H,014H,		     (* JNB case3	       no, jump.	        *)
	        03BH,04EH,0FCH,	     (* CMP CX,[BP-4]      day < DoneDate?	    *)
	        073H,007H,		     (* JNB case2b	       no, jump.	        *)
	        08AH,046H,0FBH,	     (* MOV AL,[BP-5]      Line[column]	        *)
	        088H,004H,		     (* MOV [SI],AL        <-donetime	        *)
	        0EBH,013H,		     (* JMP end-of-cases			            *)

		        (* case2b *)
	        08AH,086H,0D8H,0FEH, (* MOV AL,[BP-12A]    Line[column]	        *)
	        088H,004H,		     (* MOV [SI],AL        <-tasktime	        *)
	        0EBH,00BH,		     (* JMP end-of-cases			            *)

		        (* case3 *)
	        03BH,08EH,0DEH,0FEH, (* CMP CX,[BP-124]    day < lastday?	    *)
	        073H,00FH,		     (* JNB end-of-loop    no, jump 	        *)
	        08AH,046H,0EAH,	     (* MOV AL,[BP-16]     Line[column]	        *)
	        088H,004H,		     (* MOV [SI],AL        <-SlackChar	        *)

		        (* end-of-cases *)
	        089H,0D1H,		     (* MOV CX,DX	       day<-nextday	        *)
	        083H,0C3H,001H,	     (* ADD BX,1	       inc column	        *)
	        083H,0C6H,001H,	     (* ADD SI,1	       inc Line addr.	    *)
	        0EBH,0BBH,		     (* JMP begin-of-loop			            *)

		        (* end-of-loop *)
	        089H,096H,0E2H,0FEH, (* MOV [BP-122],DX    save nextday	        *)

	        01FH		         (* POP DS				                    *)
	        );
OS2>*)

        Continues := (nextday < lastday);

        IF (SlackStyle = NoSlack) THEN
            Started := (StartDay > realstart);
        ELSE
            Started := (StartDay > ShouldStart);    (* 12-Sep-90 RSC *)
        END;
     END; (* With *)

    ELSE
        Started := FALSE;
        Continues := FALSE;
    END;

        (*  Fill in an indication of "today". *)

    IF (Today >= StartDay) THEN
        i := ((Today-StartDay) DIV LineScale) + FirstColumn;
        IF (i <= HIGH(Line)) AND (Line[i] = " ") THEN
            Line[i] := Font[9];
        END;
    END;

END GanttLine;


(* $R= $T= $S= *)





BEGIN
    GlobalTaskNode := NIL;
    GlobalTaskPtr  := NIL;
END Gantt.



Assembler code for the GanttLine procedure:

page    ,132
code	segment
	assume	cs:code

;       These are parameters, and thus are positive offsets from BP

Columns         EQU     BP + 01EH
Line            EQU     BP + 00EH
LineScale       EQU     BP + 01AH

;       These are local variables, and are negative offsets from BP

column          EQU     BP - 0120H
ConflictDate    EQU     BP - 011AH
conflicttime    EQU     BP - 0004H
day             EQU     BP - 0126H
delaytime       EQU     BP - 0005H
DoneDate        EQU     BP - 011CH
donetime        EQU     BP - 0007H
lastday         EQU     BP - 0128H
nextday         EQU     BP - 0124H
realend         EQU     BP - 012AH
realstart       EQU     BP - 012CH
SlackChar       EQU     BP - 0002H
tasktime        EQU     BP - 0006H

	org	100h

ready proc far

    PUSH DS           

    MOV BX,[column]             ;column->BX
    MOV CX,[day]                ;day->CX
    MOV DX,CX                   ;day->nextday (in DX)
    LDS SI,[Line]               ;Line->DS:SI
    ADD SI,BX                   ;Line[column]->DS:SI

beginloop:
    ADD DX,[LineScale]          ;inc nextday by LineScale
    CMP BX,[Columns]            ;column > Columns?
    JA  endofloop               ;yes, jump
    CMP DX,[ConflictDate]       ;nextday <= ConflictDate?
    JA  case2                   ;no, jump
    MOV AL,[delaytime]          ;delaytime->Line[column]
    MOV [SI],AL       
    JMP endofcases  

case2:
    CMP DX,[realstart]          ;nextday <= realstart?
    JA  case3                   ;no, jump
    MOV AL,[conflicttime]       ;conflicttime->Line[column]
    MOV [SI],AL
    JMP endofcases

case3:
    CMP CX,[DoneDate]           ;day < DoneDate?
    JNB case4                   ;no, jump
    MOV AL,[donetime]           ;donetime->Line[column]
    MOV [SI],AL
    JMP endofcases

case4:
    CMP CX,[realend]            ;day < realend?
    JNB case5                   ;no, jump
    MOV AL,[tasktime]           ;tasktime->Line[column]
    MOV [SI],AL       
    JMP endofcases  

case5:
    CMP CX,[lastday]            ;day < lastday?
    JNB endofloop               ;no, jump
    MOV AL,[SlackChar]          ;SlackChar->Line[column]
    MOV [SI],AL       

endofcases:
    MOV CX,DX                   ;nextday->day
    ADD BX,1                    ;inc column
    ADD SI,1                    ;adjust Line[column]
    JMP beginloop 

endofloop:
    MOV [nextday],DX            ;save nextday value
    MOV [day],CX                ;save day value
    MOV [column],BX             ;save columne value

    POP DS            

    RET

ready   endp
code	ends
	end	ready


