IMPLEMENTATION MODULE Cal;

    (* MODIFICATION HISTORY --

       1/2/86   AJL   -- Check the DefaultDateFormat before displaying
                         hours as AM/PM.

       01-Dec-88 LAA    Detection of 24 hour format was reversed.  Date mode
                        is 24 hour when FollowBy is of length 0.
       22-Dec-88 LAA    Changed imports for Laslo reorganization.
       23-Aug-89 KKC    Add one more parameter to RecomputeTable.
       31-Aug-89 KKC    Do not display error message if flag is set
                        in RecomputerTable.
       13-Dec-89 RSC    Mouse support.
       02-Apr-90 MWP    Weeknumber support added.
        9-Apr-90 RSC    Timei/TimeFormat changes.
       19-Apr-90 KKC    Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
       19-Jul-90 AJL   -Moved the days calendar editing logic into CalEdit.
                       -DoWeeks and DoYears return CancelKey when no changes
                        were made; ExitKey if changes were made.
       15-Aug-90 RSC    Speed up RecomputeTable.
       30-Sep-90 AJL   -Made InsertKey and DeleteKey mark and unmark work
                        days.
        2-Nov-90 RSC    Calendar changes for qtr hour days.
        6-Nov-90 RSC    Work on mouse dragging and arrow movement.
        8-Nov-90 RSC    Finish arrow movement changes.
       18-Jan-91 TGS    Modify call to CalendarEdit, which has changed.
       18-Feb-91 TGS    Fix Up case.
        2-May-91 RSC    Changed a > to >= as per bug 4407.  Look for 2-May.
       14-Aug-91 AJL    CalendarCodeHandler procedure handles fiscal
                        years.
    *)


FROM Boxes      IMPORT
    (* TYPE *)         ABoxType, ABoxAttribute;

FROM Buttons    IMPORT
    (* TYPE *)         AButtonCollection, AnOrientation,
                       CreateButtonCollection, DisposeButtonCollection,
                       CorrelateMouseToButton;

FROM CalEdit       IMPORT
    (* PROC *)         EditCalendar;

FROM Codes         IMPORT ACode;

FROM Dialog        IMPORT Message, Error, FatalError, Burp,
                          MultipleChoiceBox, ADialogOption;

FROM Events        IMPORT
    (* TYPE *)          AnEvent, AnEventType,
    (* PROC *)          GetNextEvent;

FROM Helper      IMPORT
    (* TYPE *)      AScreenAction,
    (* PROC *)      GiveHelp;

FROM Kbio          IMPORT PutString,
                          EraseScreen, EraseLn, maxrow, maxcol,
                          ascreenx, ascreeny, avidmode;


FROM Keys          IMPORT Fwrd, Reverse, Up, Down, Tab, RTab, ExitKey,
                          SelectKey, CancelKey, HelpKey, DoIt, TimeoutKey,
                          RollUp, RollDown, InsertKey, DeleteKey,
                          MouseUp, MouseDown, MouseStillDown, MouseDouble,
                          HomeKey, EndKey;

FROM Layout        IMPORT GanttWEnd;

FROM LStrings      IMPORT SetString, ConcatS, ConcatLS, Fill, SubStr,
                          CtoS, Search, StoC, LengthOf, SetLengthOf,
                          Procustes, Copy;

FROM Menus         IMPORT
    (* PROC *)            NoYes, WordNumber;

FROM Mouse         IMPORT
    (* PROC *)            MousePresent;

FROM MsgFile       IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM RealFormat    IMPORT
    (* VARS  *)        DefaultAmountFormat,
    (* PROCS *)        FormatAsAmount;

FROM SYSTEM        IMPORT
    (* PROC *)            ADDRESS, ADR, SIZE;

FROM TimeFormat    IMPORT
    (* VAR  *)            DefaultTimeFormat, DefaultDateFormat,
    (* PROC *)            CtoMonth, CtoDay, TimeToString;

FROM Timei         IMPORT
    (* CONST *)         Jan,Dec,Sun,Sat,
    (* TYPE  *)         ATimeInfo,
    (* VAR *)           Today,
    (* PROCS *)         DaysInMonth, FindToday, KDay, DayOfWeek,
                        FiscalYearToCalendarYear;

FROM Timeu         IMPORT
    (* CONST *)         YearsOnFile,
    (* TYPE *)          ATimeTable, AYearTable, AWeekTable,
    (* VAR  *)          WeeksBeginOn, SMU, SMUPH;


FROM WeekNumberInfo IMPORT                                          (* 2-Apr-90 MWP *)
                          InitWeekNumberInfo;



CONST
    ModuleNumber        = 10100;   (* For GetMessage. *)
    ControlModuleNumber = 10200;   (* For GetMessage. *)

    MAXCARDINAL         = 0FFFFH;




TYPE
    ATimeTablePointer = POINTER TO ATimeTable;
    ACalContext = RECORD
                      SystemTimeTable   : ATimeTablePointer;
                      LastAction        : ACode;
                      ChangesMade       : BOOLEAN;
                  END;




PROCEDURE QtrHourToSector(     QtrHour,
                               ProposedSMU      : CARDINAL;
                           VAR SectorStart,
                               SectorEnd        : CARDINAL );
BEGIN
    CASE ProposedSMU OF
    | 1, 5, 15  :  (* These are always ok. *)

        SectorStart := QtrHour;
        SectorEnd   := SectorStart;

    | 6, 10, 30 :  (* Allow dual sectors only (no .25 or .75 hours) *)

        SectorStart := (QtrHour DIV 2) * 2;
        SectorEnd   := SectorStart + 1;

    | 60        :  (* Allow quad sectors only *)

        SectorStart := (QtrHour DIV 4) * 4;
        SectorEnd   := SectorStart + 3;

    ELSE
        FatalError();  (* Not accounted for. *)
    END;

END QtrHourToSector;





(*
    FALSE means "Abort changes to Time Table"
    TRUE  means "TimeTable's WeekMaps fixed up."
*)
PROCEDURE CheckAndFixupWeekTable( VAR TimeTable   : ATimeTable;
                                      ProposedSMU : CARDINAL;
                                      Warn        : BOOLEAN ) : BOOLEAN;
VAR
    QtrHours,
    i, j,
    Day,
    Selection,
    SectorStart,
    SectorEnd       : CARDINAL;
    Result,
    Fix,
    NeverWarned,
    on              : BOOLEAN;
    s               : ARRAY [0..255] OF CHAR;
    Title           : ARRAY [0..31]  OF CHAR;
    MenuPrefix      : ARRAY [0..1]   OF CHAR;
    MenuString      : ARRAY [0..155] OF CHAR;
BEGIN
    NeverWarned := TRUE;

    FOR Day := Sun TO Sat DO
        WITH TimeTable.WeekTable[Day] DO
            QtrHours  := 0;
            i         := 0;  (* Start with Qtr Hour 0 *)
            WHILE (i <= 95) DO
                QtrHourToSector( i, ProposedSMU, SectorStart, SectorEnd );
                on := (i IN WeekMap);
                FOR j := SectorStart TO SectorEnd DO
                    IF ((j IN WeekMap) <> on) THEN
                        IF (Warn AND NeverWarned) THEN
                            GetMessage (ModuleNumber+32,s);     (* "What should I do?" *)
                            SetLengthOf (MenuPrefix, 0);
                            GetMessage (ModuleNumber+33,MenuString);    (* "Change,Forget it" *)
                            GetMessage (ModuleNumber+34,Title);         (* "Weekmap error" *)
                            Selection := 1;
                            Result := MultipleChoiceBox(s, Title, NoHelp, MenuPrefix, MenuString, Selection);
                            IF (NOT Result) OR (Selection = 2) THEN
                                RETURN FALSE;
                            END;
                            Fix := (Selection = 1);
                            NeverWarned := FALSE;
                        ELSE
                            Fix := TRUE;
                        END;
                        IF (Fix) THEN
                            IF (on) THEN
                                INCL(WeekMap,j);
                            ELSE
                                EXCL(WeekMap,j);
                            END;
                        END;
                    END;
                    IF (NOT on) THEN
                        INC(QtrHours);
                    END;
                END;

                i := SectorEnd + 1;

            END;
                (* Tics in day = (Hours in day) * (Tics Per Hour),

                   but because of cardinal math, avoid fractions by
                   wording this as:

                        (QtrHours * Tics Per Hour) / 4

                   Also note that SMUPH is not possible here because we
                   were given a "proposed SMU", not always the real one.
                *)
            TicsInDay := (QtrHours * (60 DIV ProposedSMU)) DIV 4;
        END;
    END;

    RETURN TRUE;

END CheckAndFixupWeekTable;





(* 2-Nov-90 RSC Massive reworking for qtr hour day changes.
*)
PROCEDURE RecomputeTable(VAR TimeTable    : ATimeTable;
                             DisplayMsg   : BOOLEAN );
VAR
    i               : CARDINAL;
    j               : CARDINAL;
    k               : CARDINAL;
    Day             : CARDINAL;
    Month           : CARDINAL;
    Year            : CARDINAL;
    Tics,
    date            : CARDINAL;

    monthsize       : CARDINAL;
    n               : CARDINAL;
    on              : BOOLEAN;
    Result          : BOOLEAN;
    s               : ARRAY [0..1] OF CHAR;

        (* Get this stuff off the stack when calling other procs.
        *)
    PROCEDURE Warn() : BOOLEAN;
    VAR
        Selection       : CARDINAL;
        TimeInfo        : ATimeInfo;
        s               : ARRAY [0..255] OF CHAR;
        s2              : ARRAY [0..99]  OF CHAR;
        Title           : ARRAY [0..31]  OF CHAR;
        MenuPrefix      : ARRAY [0..1]   OF CHAR;
        MenuString      : ARRAY [0..155] OF CHAR;
    BEGIN

        GetMessage (ModuleNumber+12, s);        (* "I found a bad date ..." *)
        TimeInfo.tiYear := Year + i - 1;
        TimeInfo.tiMonth := Month;
        TimeInfo.tiDay := date;
        TimeInfo.tiHour := 0;
        TimeInfo.tiMinute := 0;
        TimeToString (TimeInfo,DefaultDateFormat,s2);
        ConcatLS (s, s2);
        ConcatMessage (s, ModuleNumber+13);     (* "What should I do?" *)
        SetLengthOf (MenuPrefix, 0);
        GetMessage (ModuleNumber+14,MenuString);    (* "Ignore,Change,Forget it" *)
        GetMessage (ModuleNumber+15,Title);         (* "Calendar error" *)
        Selection := 1;
        Result := MultipleChoiceBox (s, Title, NoHelp, MenuPrefix, MenuString, Selection);
        IF (NOT Result) OR (Selection = 3) THEN
            RETURN FALSE;
        ELSIF (Selection = 2) THEN
            INCL( TimeTable.YearTable[i,Month].YearMap, date );
        END;

        RETURN TRUE;

    END Warn;

BEGIN
    DisplayMessage(ModuleNumber+6);   (*  "Reorganizing the calendar . . ."  *)

     (* Never warn here, thats been handled in the CheckProc
        of the Calendar Form.  Only result possible is TRUE.
     *)
    on   := CheckAndFixupWeekTable( TimeTable, SMU, FALSE );

    Year := TimeTable.FirstYear;
    Day  := DayOfWeek(Year,Jan,1);  (* Day of week *)

    Tics := 0;

    FOR i := 1 TO YearsOnFile DO
        FOR Month := Jan TO Dec DO
            WITH TimeTable.YearTable[i, Month] DO

                TicsAtStartOfMonth := Tics;
                StartDay           := Day;

                FOR j := 1 TO DaysInMonth(Year+i-1,Month) DO
                    IF (NOT (j IN YearMap)) THEN
                        k := TimeTable.WeekTable[Day].TicsInDay;
                        IF ((MAXCARDINAL - Tics) < k) THEN
                            Tics := MAXCARDINAL;
                        ELSE
                            INC( Tics, k );
                        END;
                    END;

                    Day := (Day+1) MOD 7;

                END;
            END;
        END;
    END;


    Today := FindToday();
    s[0] := 0C;
    Message(s);

    InitWeekNumberInfo ();                                          (* 2-Apr-90 MWP *)


    IF ( NOT DisplayMsg ) THEN      (* KKC Aug 31, 1989 *)
        RETURN;
    END;

(* The only thing that is done inside the loop is to display error messages *)
(* if there is any.                                                         *)

    FOR i := 1 TO YearsOnFile DO
        FOR Day := Sun TO Sat DO
            IF (TimeTable.WeekTable[Day].TicsInDay = 0) THEN
                FOR Month := Jan TO Dec DO
                    monthsize := DaysInMonth (Year+i-1,Month);
                    n := monthsize DIV 7 + 1;
                    FOR j := 1 TO n DO
                        date := (7+Day - TimeTable.YearTable[i,Month].StartDay) MOD 7 + 1+7*(j-1);
                        IF (date <= monthsize) THEN
                            on := (date IN TimeTable.YearTable[i,Month].YearMap);
                            IF (NOT on) THEN
                                IF (NOT Warn()) THEN
                                    RETURN;
                                END;
                            END;
                        END;
                    END;
                END;
            END;
        END;
    END;

END RecomputeTable;









PROCEDURE DoWeek (VAR TimeTable:ATimeTable ) : ACode;
CONST
    firstrow    = 0;
    FirstDayCol = 16;
    FirstDayRow = 3;
    depth       = 3;
    LastColText = FirstDayCol + 48 + 1;
VAR
    Event            : AnEvent;
    ButtonNumber     : CARDINAL;
    ButtonCollection : AButtonCollection;
    CursorWidth,
    HomeKeyCount,
    EndKeyCount,
    WeeksEndOn,
    day,
    QtrHour          : CARDINAL;
    SaveX,
    x                : ascreenx;
    SaveY,
    y                : ascreeny;
    code             : ACode;
    ThinBar,
    ThickBar         : ARRAY [0..1]        OF CHAR;
    s                : ARRAY [0..maxcol+1] OF CHAR;
    MouseClickOK,
    On,
    ChangesMade      : BOOLEAN;



    PROCEDURE findxy(day,QtrHour:CARDINAL; VAR x:ascreenx; VAR y:ascreeny);
    VAR
        Offset : CARDINAL;
    BEGIN
        Offset := ((day + 7) - WeeksBeginOn) MOD 7;

        x := FirstDayCol + (QtrHour MOD 48);
        y := FirstDayRow + (QtrHour DIV 48) + (Offset * depth);

    END findxy;


    PROCEDURE FindDayQtrHour(     X         : ascreenx;
                                  Y         : ascreeny;
                              VAR Day,
                                  QtrHour   : CARDINAL;
                                  StillDown : BOOLEAN ) : BOOLEAN;
    VAR
        AreaX      : ascreenx;
        AreaY      : ascreeny;
        NewDay,
        NewQtrHour : CARDINAL;
    BEGIN
            (* If still at the same cursor "block", pretend this cursor
               doesn't exist, so we don't flip flop a cursor block on
               a mouse drag.
            *)
        IF (StillDown) THEN
            IF ( Y                  = SaveY) AND
               ((X DIV CursorWidth) = SaveX) THEN
                RETURN FALSE;
            END;
        END;

        SaveX := X DIV CursorWidth;
        SaveY := Y;

        FOR NewDay := 0 TO 6 DO
            FOR NewQtrHour := 0 TO 95 DO
                findxy( NewDay, NewQtrHour, AreaX, AreaY );
                IF (Y = AreaY) AND
                   (X = AreaX) THEN
                    Day     := NewDay;
                    QtrHour := NewQtrHour;
                    RETURN TRUE;
                END;
            END;
        END;

        RETURN FALSE;

    END FindDayQtrHour;



    PROCEDURE markQtrHour(day,QtrHour:CARDINAL; mark,highlight:BOOLEAN);
    VAR
        x           : ascreenx;
        y           : ascreeny;
        videomode   : avidmode;
        s           : ARRAY [0..1] OF CHAR;
    BEGIN
        findxy(day,QtrHour,x,y);
        IF (mark) THEN
            Copy( ThinBar, s );     (* NO WORK *)
        ELSE
            Copy( ThickBar,  s );   (* WORK *)
        END;

        IF (highlight) THEN
            videomode := cvideonormal;
        ELSE
            videomode := videonormal;
        END;

        PutString(s,x,y,videomode);

    END markQtrHour;




        (* Return the CursorWidth
        *)
    PROCEDURE LayItOut() : CARDINAL;
    CONST
        HBar1      = 304C;
        VBar1      = 263C;
        JoinR      = 303C;
        JoinL      = 264C;
    VAR
        SectorStart,
        SectorEnd    : CARDINAL;
        i, j,
        day, QtrHour,
        Hour,
        AMLimit,
        PMLimit      : CARDINAL;
        Devider,
        Spaces,
        AM, PM       : ARRAY [0..69] OF CHAR;
        ok           : BOOLEAN;
    BEGIN
        EraseScreen;
            (*  "Standard working QtrHours for each day of week, used when day is a work day."  *)
            (*  "(Time Line cannot schedule work for any day that has no work QtrHours specified.)"  *)
        GetMessage(ModuleNumber+8,s);
        PutString(s, 0,firstrow,videonormal);
        GetMessage(ModuleNumber+9,s);
        PutString(s, 0,firstrow+1,videonormal);

        GetMessage(ModuleNumber+10,AM);             (*  "AM"  *)
        GetMessage(ModuleNumber+11,PM);             (*  "PM"  *)
        AMLimit := (FirstDayCol - 1) - LengthOf(AM);
        PMLimit := (FirstDayCol - 1) - LengthOf(PM);

        ConcatS(AM,VBar1);  (* Tack on a vertical bar after "AM" or "PM" *)
        ConcatS(PM,VBar1);

        SetString( Devider, JoinR ); (* Build the horizontal devider bar *)
        Fill(s,HBar1,48);
        ConcatLS(  Devider, s );
        ConcatS(   Devider, JoinL );

        Fill(Spaces, ThinBar[1], 48 );  (* Default the center bits to NO WORK *)
        ConcatS( Spaces, VBar1 );

        ConcatLS( AM, Spaces ); (* Now AM&PM have lots of stuff after the AM and PM *)
        ConcatLS( PM, Spaces );

        FOR day := Sun TO Sat DO
            findxy(day,0,x,y);
            CtoDay(day,s);
            Procustes(s, AMLimit);
            ConcatLS( s, AM );
            PutString(s,           0,               y,   videonormal);
            PutString(PM,          PMLimit,         y+1, videonormal);
            IF (day <> WeeksEndOn) THEN
                PutString(Devider, FirstDayCol - 1, y+2, videonormal);
            END;
        END;


        FOR Hour := 0 TO 11 DO
            findxy(0,Hour * 4,x,y);
            IF (Hour = 0) THEN
                CtoS( 12, s );
            ELSE
                CtoS( Hour, s );
            END;
            PutString(s, x, FirstDayRow - 1, videonormal);
        END;


        FOR day := Sun TO Sat DO
            WITH TimeTable.WeekTable[day] DO
                FOR QtrHour := 0 TO 95 DO
                    IF (NOT (QtrHour IN WeekMap)) THEN
                        markQtrHour(day,QtrHour,FALSE,FALSE); (* WORK QTR HOUR *)
                    END;
                END;
            END;
            ShowDaysHours( day );
        END;

        IF (NOT MousePresent()) THEN
            GetMessage(ModuleNumber+3,s);
            PutString(s,0,GanttWEnd,videonormal);
            GetMessage(ModuleNumber+4,s);
            PutString(s,0,GanttWEnd+1,videonormal);
        END;

        GetMessage( ModuleNumber + 30, s );  (* "Scale:" *)
        PutString( s, LastColText, FirstDayRow, videonormal );


        i := 0;
        LOOP
            CASE i OF
            | 0  :    j := 60;
            | 1  :    j := 30;
            | 2  :    j := 15;
            | 3  :    j := 6;
            | 4  :    j := 5;
            | 5  :    j := 1;
            ELSE FatalError;
            END;
            IF (j <= SMU) THEN
               EXIT;
            END;
            INC(i);
        END;
        IF (j < SMU) THEN           (* 2/3/88 EGK *)
            DEC(i);
        END;

        GetMessage( ModuleNumber + 31, s );  (* "Hour,Half Hour,15 Minute,6 Minute,5 Minute,Minute" *)
        WordNumber( s, i+1, Spaces );   (* 6-Nov-90 RSC *)
        PutString( Spaces, maxcol - LengthOf(Spaces), FirstDayRow+1, videonormal );

        GetMessage(ModuleNumber+18,s); (* Buttons *)
        ok := CreateButtonCollection(2,GanttWEnd,maxcol, GanttWEnd,
                                       ABoxType{NoBox},  Horizontal,s,
                                       ButtonCollection);

        QtrHourToSector( QtrHour, SMU, SectorStart, SectorEnd );

        RETURN (SectorEnd - SectorStart) + 1;

    END LayItOut;



    PROCEDURE GetChar( VAR s        : ARRAY OF CHAR;
                           Default,
                           Word     : CARDINAL;
                       VAR Bar      : ARRAY OF CHAR );
    VAR
        C, i  : CARDINAL;
        s1    : ARRAY [0..3] OF CHAR;
    BEGIN
        WordNumber( s, Word, s1 );
        i := 1;
        C := StoC( s1, i );
        IF (i = 1) THEN
            C := Default;  (* default char *)
        END;
        Bar[0] := 1C;
        Bar[1] := CHR(C);

    END GetChar;




    PROCEDURE Normalize( QtrHour, day : CARDINAL; On : BOOLEAN );
    VAR
        i,
        SectorStart,
        SectorEnd    : CARDINAL;
    BEGIN
        QtrHourToSector( QtrHour, SMU, SectorStart, SectorEnd );

        FOR i := SectorStart TO SectorEnd DO
            WITH TimeTable.WeekTable[day] DO
                IF (On) THEN
                    INCL(WeekMap, i);
                ELSE
                    EXCL(WeekMap, i);
                END;
            END;

            IF (i <> QtrHour) THEN
                markQtrHour( day, i, On, FALSE);
            END;
        END;

        ChangesMade := TRUE;

    END Normalize;




    PROCEDURE ShowDaysHours( Day : CARDINAL );
    VAR
        i,
        QtrHours    : CARDINAL;
    BEGIN
        QtrHours := 0;

        WITH TimeTable.WeekTable[Day] DO
            FOR i := 0 TO 95 DO
                IF (NOT (i IN WeekMap)) THEN
                    INC(QtrHours);
                END;
            END;
        END;

        FormatAsAmount( FLOAT( QtrHours ) / 4.0,
                        DefaultAmountFormat,
                        s, 5, 1, 2, TRUE );

        findxy( Day, 95, x, y );    (* Get one on the second row *)

        PutString( s, 0, y, videonormal );

    END ShowDaysHours;


BEGIN (* DoWeek *)
    MouseClickOK := TRUE;
    HomeKeyCount := 0;
    EndKeyCount  := 0;

    day         := WeeksBeginOn;
    WeeksEndOn  := (WeeksBeginOn + 6) MOD 7;
    QtrHour     := 0;
    ChangesMade := FALSE;

        (* Get the two ascii decimal values that describe NON-WORK and
           WORK time, respectively.
        *)
    GetMessage(ModuleNumber+7,s);  (* "176,177" *)
    GetChar( s, 176, 1, ThinBar  );
    GetChar( s, 177, 2, ThickBar );

    CursorWidth := LayItOut();     (* Draw initial screen *)

    LOOP
        day := day MOD 7; (* Insure normalization *)
        ShowDaysHours( day );
        On := (QtrHour IN TimeTable.WeekTable[day].WeekMap);
        markQtrHour(day,QtrHour,On,TRUE);
        GetNextEvent( Event );
        code := Event.EventCode;

        IF (Event.EventType = MouseEvent) THEN
            IF (Event.EventCode = MouseUp) AND
                CorrelateMouseToButton(ButtonCollection,Event.EventX,
                                       Event.EventY,ButtonNumber) THEN
                CASE ButtonNumber OF
                | 1 : code := ExitKey;
                | 2 : code := CancelKey;
                | 3 : code := HelpKey;
                ELSE
                END;
            END;
        END;

        markQtrHour(day,QtrHour,On,FALSE);

        IF (code = HomeKey) THEN
            INC(HomeKeyCount);
        ELSE
            HomeKeyCount := 0;
        END;

        IF (code = EndKey) THEN
            INC(EndKeyCount);
        ELSE
            EndKeyCount := 0;
        END;

        CASE code OF
        | Down      :
            IF (QtrHour < 48) THEN
                INC(QtrHour, 48);
            ELSE
                DEC(QtrHour, 48);
                INC(day);
            END;
        | Up        :
            IF (QtrHour >= 48) THEN (* 19-Feb-91 TGS *)
                DEC(QtrHour, 48);
            ELSE
                INC(QtrHour, 48);
                IF (day > 0) THEN
                    DEC(day);
                ELSE
                    day := 6;
                END;
            END;
        | Reverse   :
            IF ((QtrHour MOD 48) >= CursorWidth) THEN   (* 2-May-91 RSC  *)
                DEC(QtrHour,CursorWidth);
            ELSE
                QtrHour := (((QtrHour DIV 48) + 1) * 48) - CursorWidth;
            END;
        | Fwrd,
          DoIt      :
            IF ((QtrHour MOD 48) < (48 - CursorWidth)) THEN
                INC(QtrHour, CursorWidth);
            ELSE
                QtrHour := (QtrHour DIV 48) * 48;
            END;

        | HomeKey   :
            IF (HomeKeyCount = 1) THEN
                IF (QtrHour < 48) THEN
                    QtrHour := 0;
                ELSE
                    QtrHour := 48;
                END;
            ELSIF (HomeKeyCount = 2) THEN
                QtrHour := 0;
            ELSE
                QtrHour := 0;
                day     := WeeksBeginOn;
            END;

        | EndKey    :
            IF (EndKeyCount = 1) THEN
                IF (QtrHour < 48) THEN
                    QtrHour := 47;
                ELSE
                    QtrHour := 95;
                END;
            ELSIF (EndKeyCount = 2) THEN
                QtrHour := 95;
            ELSE
                QtrHour := 95;
                day     := WeeksEndOn;
            END;

        | Tab       :
            QtrHour := 0;
            INC(day);

        | RTab      :
            QtrHour := 95;
            IF (day > 0) THEN
                DEC(day);
            ELSE
                day := 6;
            END;

        | SelectKey :
            Normalize(QtrHour,day,(NOT (QtrHour IN TimeTable.WeekTable[day].WeekMap)));

        | InsertKey :
            Normalize(QtrHour,day,FALSE);

        | DeleteKey :
            Normalize(QtrHour,day,TRUE);

        | MouseDown,
          MouseStillDown:
            MouseClickOK := FindDayQtrHour( Event.EventX,
                                            Event.EventY,
                                            day, QtrHour,
                                            (code = MouseStillDown));
            IF (MouseClickOK) THEN
                Normalize(QtrHour,day,(NOT (QtrHour IN TimeTable.WeekTable[day].WeekMap)));
            END;
        | HelpKey   :
            SetString(s,"TL.WEEK");
            GiveHelp(s,0,GanttWEnd,LeaveTheText);   (* Save space--don't save screen. *)
            DisposeButtonCollection(ButtonCollection);
            CursorWidth := LayItOut();
        | CancelKey :
            IF (AllowLeaving(ChangesMade)) THEN
                ChangesMade := FALSE;
                EXIT;
            END;
        | ExitKey,
          TimeoutKey:
            IF (NOT ChangesMade) THEN
                code := CancelKey;        (* Signal that nothing changed. *)
            END;
            EXIT;
        ELSE
            IF (Event.EventType <> MouseEvent) THEN
                Burp;
            END;
        END;
    END;

    DisposeButtonCollection(ButtonCollection);

    EraseScreen;

    IF (code = ExitKey) THEN
        RecomputeTable(TimeTable, TRUE);
    END;

    RETURN code;

END DoWeek;







PROCEDURE AllowLeaving( ChangesMade : BOOLEAN )    : BOOLEAN;

VAR
    s       : ARRAY [0..99] OF CHAR;

BEGIN
    IF (ChangesMade) THEN
        GetMessage (ModuleNumber+16,s);
        RETURN NoYes(s);
    ELSE
        RETURN TRUE;
    END;
END AllowLeaving;





PROCEDURE DrawDateBox( Year, Month, Date : CARDINAL;
                       ULX               : ascreenx;   
                       ULY               : ascreeny;   
                       LRX               : ascreenx;
                       LRY               : ascreeny;
                       Highlight         : BOOLEAN;
                       Context           : ADDRESS );
VAR
    CalendarYear    : CARDINAL;
    CalContext  : POINTER TO ACalContext;
    i           : CARDINAL;
    videomode   : avidmode;
    s           : ARRAY [0..31] OF CHAR;
    Mark        : BOOLEAN;
BEGIN
        (* We are passed the fiscal year.  If this differs from the 
           calendar year, compute the calendar year. *)
    CalendarYear := Year;
    FiscalYearToCalendarYear(Month,CalendarYear);

    CalContext := Context;

    WITH CalContext^.SystemTimeTable^ DO
        i := CalendarYear - FirstYear + 1;
        Mark := Date IN YearTable[i,Month].YearMap;
    END;
    IF (Mark) THEN
        GetMessage(ModuleNumber+5,s);   (* "No Work   " *)
        videomode := videofilter4;
    ELSE
        Fill(s," ",HIGH(s));
        videomode := videonormal;
    END;
    Procustes( s, LRX-ULX+1 );
    IF (Highlight) THEN                (* Cursor on it. *)
        INC(videomode);
    END;

    PutString(s,ULX,ULY,videomode);

END DrawDateBox;   





PROCEDURE CalendarCodeHandler( VAR Code : ACode;
                                   Year, Month, Day : CARDINAL;
                                   Context : ADDRESS
                             ) : BOOLEAN;
VAR
    CalendarYear : CARDINAL;
    CalContext : POINTER TO ACalContext;
    i          : CARDINAL;
    s8         : ARRAY [0..9] OF CHAR;
BEGIN
        (* We are passed the fiscal year.  If this differs from the 
           calendar year, compute the calendar year. *)
    CalendarYear := Year;
    FiscalYearToCalendarYear(Month,CalendarYear);

    CalContext := Context;
    WITH CalContext^.SystemTimeTable^ DO
        i := CalendarYear - FirstYear + 1;
    END;
    WITH CalContext^.SystemTimeTable^.YearTable[i,Month] DO
        IF (Code = MouseStillDown) THEN
            Code := CalContext^.LastAction;
        END;
        CalContext^.LastAction := 0;
        CASE Code OF
        | SelectKey,
          MouseDown :                           (* Flip the day's vacation bit. *)
            IF (Day IN YearMap) THEN
                EXCL(YearMap, Day );
                CalContext^.LastAction := DeleteKey;
            ELSE
                INCL(YearMap, Day );
                CalContext^.LastAction := InsertKey;
            END;
            CalContext^.ChangesMade := TRUE;
            RETURN TRUE;                           (* Code has been fully processed. *)
        | InsertKey :
            INCL(YearMap, Day );
            CalContext^.ChangesMade := TRUE;
            CalContext^.LastAction  := InsertKey;
            RETURN TRUE;                           (* Code has been fully processed. *)
        | DeleteKey :
            EXCL(YearMap, Day );
            CalContext^.ChangesMade := TRUE;
            CalContext^.LastAction := DeleteKey;
            RETURN TRUE;                           (* Code has been fully processed. *)
        | HelpKey   :
            SetString(s8,"TL.MONTH");
            GiveHelp(s8,0,GanttWEnd,LeaveTheText);  (* Save space--don't save screen. *)
            RETURN TRUE;                           (* Code has been fully processed. *)
        | CancelKey :
            IF (AllowLeaving(CalContext^.ChangesMade)) THEN
                CalContext^.ChangesMade := FALSE;   (* Cancel any changes. *)
            ELSE
                RETURN TRUE;                        (* Ignore this key. *)
            END;
        ELSE
        END;
    END;

    RETURN FALSE;   (* We did not process the key, (or at least, not completely). *)

END CalendarCodeHandler;





PROCEDURE DoYears (VAR TimeTable:ATimeTable;VAR CursorDate : ATimeInfo):ACode;
CONST
    AULX = 18;   (* Positioning for the lower left corner. *)
    AULY = 20;
    ALRX = AULX;
    ALRY = AULY;
VAR
    code         : ACode;
    OldDate      : ATimeInfo;
    CalContext   : ACalContext;
    s            : ARRAY [0..0] OF CHAR;
BEGIN

    OldDate := CursorDate;

        (* Set up the Context to contain parameters which specialize the 
           general calendar editting to edit a Master calendar. *)

    WITH CalContext DO
        SystemTimeTable := ADR(TimeTable);
        LastAction      := 0;
        ChangesMade     := FALSE;
    END;

         (* Edit the resource calendar. *)



    SetLengthOf(s, 0); (* This could be a calendar Title later *)

    EditCalendar(CalendarCodeHandler,
                 DrawDateBox,ADR(CalContext),    
                 CursorDate,
                 AULX,AULY,ALRX,ALRY,s);

    IF (CalContext.ChangesMade) THEN
        code       := ExitKey;
        RecomputeTable(TimeTable, TRUE);
    ELSE
        DisplayMessage(ControlModuleNumber+5);   (*  "Ok, calendar not changed."  *)
        code       := CancelKey;
        CursorDate := OldDate;
    END;

    RETURN code;

END DoYears;




END Cal.

