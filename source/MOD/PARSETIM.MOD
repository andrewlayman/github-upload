IMPLEMENTATION MODULE ParseTime;

(*  =========================================================================
    Last Edit : August 21, 1991 2:35PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Parse strings representing Time.

    MODIFICATION HISTORY:

    12/20/88  RSC   Moved here from Timeu.
    04/07/89  EGK   Changed GetYearMonthDayOrHour and XParseDate to
                    check for month = 0 or day = 0.
    07/10/89  AJL   Allow military time, where hours are like "1900".
    08/14/89  KKC   Determine given task is in twenty first century
                    by calcaluating the number of years it exceed 2000
                    instead of checking the leading zero.
    02-Apr-90 MWP   Weeknumber support added.
     9-Apr-90 RSC   Timei/TimeFormat changes.
    11-Apr-90 KKC   Replace all direct calculations on ADate and Duration
                    by calls to FindDuration, SubtractWorkingTime and
                    AddWorkingTime.
    11-Apr-90 MWP   Re-worked parsing of weeknumbers to make it more
                    robust.
    18-Apr-90 MWP   Added reporting of a bad date to one area of week
                    number parsing.
    19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                    date structure, ATimeInfo. 
    28-May-90 MWP   Allow adding of weeks and months to weeknumber dates
                    where the day of the week is Thursday, Friday or
                    Saturday.
    28-May-90 MWP   Allow spaces between day of the week and YEAR/WEEKNUMBER
                    for weeknumber formats.
    29-May-90 MWP   Fixed a bug which was inhibiting acceptance of partial
                    week number dates.
    19-Oct-90 PFG   Substituted call to CompressTime() with call to
                    TtoTimeU so that fiscal years will be handled con-
                    sistently.
    19-Oct-90 TGS   Change Alphabetic so it doesn't lie when it is dealing
                    with non-English alphabets.
    26-Oct-90 TGS   Change a CASE statement so that always checks for am/pm
                    in the ELSE clause, in case the am/pm characters aren't
                    in the range A-Z.
    12-Nov-90 TGS   Merge changes made to 4.03.
     5-Jan-90 AJL  -Rearrange parsing of words like "Today" and "Tomorrow"
                    to reduce code size and use only one phrase.
                   -Added keywords BOT and EOT.
    14-May-91 AJL  -Parse the keyword "FY" in a date to indicate that the
                    date contains a fiscal year.
    11-Jun-91 RSC  - Someone put "GetMessageWord" from FormatCommon in here,
                    which tends to get all kinds of modules sucked in, like
                    GoTo, GoToViews, GoToOutlines, etc.
    26-Jun-91 LAA  -The parsing of words like "Today" and "AsOf" was a little
                    "suboptimal".  Because the loop in FindDay starts at 0,
                    but WordNumber starts counting words at 1, all the
                    keywords were actually resulting in a date appropriate
                    for the following keyword.  I also moved the call to 
                    GetMessage out of the loop.
    21-Aug-91 EGK  -StoEndD wasn't using the end-date rule when converting
                    from a small date back to a TimeInfo record.  It was
                    just calling TimeUtoT, instead of TimeAsEndDateStyle.
    =========================================================================
*)


FROM AsOf       IMPORT AsOfDate;

FROM CalShift   IMPORT TimeSheet;

FROM Clock      IMPORT 
    (* TYPE *)          ASystemTime,
    (* PROC *)          GetDateAndTime;

FROM Dialog     IMPORT Message, Error, FatalError;

FROM Duration   IMPORT SubtractWorkingTime, AddWorkingTime, FindDuration;

(*FROM FormatCommon IMPORT*)    (* 11-Jun-91 RSC removed. *)
(*    (* PROC *)             GetMessageWord;*)

FROM GaGa       IMPORT
        (* PROCS *)        GetGaGaMessage;

FROM LStrings   IMPORT SetString, ConcatLS, CtoS, Fill, ConcatS,
                           SetLengthOf, Insert, SubStr, StoC, Compare,
                           Upshift, Overlay, Remove, TrimRear, LJust,
                           Search, TrimFront, LengthOf, Copy;

FROM MsgFile    IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM Menus      IMPORT
    (* PROC *)      WordNumber;

FROM TimeFormat IMPORT
    (* TYPE *)      AMonthString,
    (* VAR  *)      USADate, EndDateStyle,
    (* PROC *)      CtoDay, CtoM, PartialDateToDate, TimeAsEndDateStyle;

FROM Timei      IMPORT
    (* CONST *)     Jan, Dec, Sat, Sun, MaxDate,  MinDate,
    (* TYPE *)      ADate, ASetOfADurationUnit, ADurationUnit, ADuration,
                    ATimeInfo,
    (* PROC *)      TtoTimeU, TimeUtoT, SystemTimeToTime,
                    CalendarYearToFiscalYear;

FROM Timeu      IMPORT
    (* CONST *)     YearsOnFile,
    (* VAR  *)      TimeTable,
    (* PROC *)      UpScale;


FROM WeekNumberInfo      IMPORT                                     (* 2-Apr-90 MWP *)
    (* VAR *)                   UsingWeekNumbers,
    (* PROC *)                  CtoIntDay,
    (* PROC *)                  WeekNumberToTimeU,
    (* PROC *)                  WeekNumberToTime;

CONST
    ModuleNumber = 0400;              (*  SAME AS TIMEU!!    *)
    TimeFormatModuleNumber = 21900;   (*  For GetGaGaMessage *)


    MAXCARDINAL  = 65535;





    (*  StoTimeU -- Parses the string.  Converts the date to internal format. *)

PROCEDURE StoTimeU(VAR s:ARRAY OF CHAR; VAR Date:ADate):BOOLEAN;
VAR
    TimeInfo : ATimeInfo;
    SystemTime : ASystemTime;
    TimeUnitsFound : ASetOfADurationUnit;
BEGIN
    GetDateAndTime( SystemTime );
    SystemTimeToTime( SystemTime, TimeInfo );
    RETURN
        ParseDate (s, TimeInfo, TimeUnitsFound )
        AND
        PartialDateToDate(TimeInfo,TimeUnitsFound,TRUE,Date);
END StoTimeU;









    (* StoD -- Parse the string into a date. *)


PROCEDURE StoD (VAR s:ARRAY OF CHAR; VAR TimeInfo : ATimeInfo ): BOOLEAN;
VAR
    TimeUnitsFound : ASetOfADurationUnit;
    SystemTime : ASystemTime;
BEGIN
    GetDateAndTime( SystemTime );
    SystemTimeToTime( SystemTime, TimeInfo );

    RETURN ParseDate (s,
                      TimeInfo,
                      TimeUnitsFound );

END StoD;






    (*  StoEndTimeU -- Parses the string.  Returns the latest moment that
                   could be within the period named by the string.  For
                   example, "June" would yield the last moment of the
                   last day in June.  And, what is so rare as a day in
                   June?

                   19-Sep-89 RSC

                   Pass down a start date for use in determining the defaults
                   for end dates!!

     *)
PROCEDURE StoEndTimeU(VAR s:ARRAY OF CHAR; VAR Date:ADate):BOOLEAN;
VAR
    TimeInfo : ATimeInfo;
    TimeUnitsFound : ASetOfADurationUnit;
BEGIN
    TimeUtoT(Date,TimeInfo);
    RETURN
        ParseDate (s,  TimeInfo,  TimeUnitsFound )
        AND
        PartialDateToDate(TimeInfo,TimeUnitsFound,
                          FALSE,Date);
END StoEndTimeU;






    (*  StoEndD -- Parses the string.  Returns the latest moment that
                   could be within the period named by the string.  For
                   example, "June" would yield the last moment of the
                   last day in June.  And, what is so rare as a day in
                   June?

                   19-Sep-89 RSC

                   Pass down a start date for use in determining the defaults
                   for end dates!!
    *)
PROCEDURE StoEndD (VAR s:ARRAY OF CHAR; VAR TimeInfo : ATimeInfo )
                     : BOOLEAN;
VAR
    Date           : ADate;
    TimeUnitsFound : ASetOfADurationUnit;
    ok             : BOOLEAN;
BEGIN

    ok := ParseDate (s, TimeInfo, TimeUnitsFound )
          AND
          PartialDateToDate(TimeInfo,TimeUnitsFound,
                            FALSE,Date);

    IF (ok) THEN
        TimeAsEndDateStyle (Date, EndDateStyle, TimeInfo);  (* 8/21/91 EGK *)
    END;

    RETURN ok;

END StoEndD;







 (* Helpers for Parse Date. *)



PROCEDURE Alphabetic( C : CHAR ) : BOOLEAN;
BEGIN
(*  This old vay of doing things no verk in Svensk, or Russky, or... *)
(*  RETURN (C >= "A") AND (C <= "Z");                                *)

    (* It should be good enough to check to see if it is a character *)
    (* that we KNOW is NOT "Alphabetic", and assume that it is       *)
    (* Alphabetic if it is not one of these characters. On Forms,    *)
    (* only Alphabetic and <SP>+,-./0123456789: can be typed in, so  *)
    (* this is a true assumption; on SS edit, if other characters    *)
    (* are typed in they will either cause an "invalid date" error   *)
    (* or get absorbed as part of a word, but should not cause any   *)
    (* more serious problem.                                         *)

    RETURN NOT (((C >= "+") AND (C <= ":")) OR (C = " ")); (* 19-Oct-90 TGS *)
END Alphabetic;




PROCEDURE RemoveRestOfWord(  VAR S : ARRAY OF CHAR;
                                 i : CARDINAL       );
BEGIN
    WHILE (i <= ORD(S[0])) AND Alphabetic(S[i]) DO
        Remove(S,i,1);
    END;
END RemoveRestOfWord;



    (* AdjustDate -- Take the indicated date and move it
                     ahead or behind by a duration of time. *)


PROCEDURE AdjustDate( VAR TimeInfo                   : ATimeInfo;
                          Quantity                   : CARDINAL;
                          TimeUnit                   : ADurationUnit;
                          Plus                       : BOOLEAN);
VAR
    T  : ADate;
    Dur : ADuration;
BEGIN
    IF (TtoTimeU(TimeInfo, T)) THEN ; END;

    Dur := UpScale(Quantity,TimeUnit);

    IF (Plus) THEN
        IF (T <= SubtractWorkingTime( MaxDate, Dur, TimeSheet ) ) THEN
            T := AddWorkingTime( T, Dur, TimeSheet );
        ELSE
            T := MaxDate;
        END;
    ELSE
        IF (Dur < FindDuration( MinDate, T, TimeSheet ) ) THEN
            T := SubtractWorkingTime( T, Dur, TimeSheet );
        ELSE
            T := MinDate;
        END;
    END;

    TimeUtoT(T,TimeInfo);
END AdjustDate;



PROCEDURE MatchWord( VAR S      : ARRAY OF CHAR;
                         Word   : ARRAY OF CHAR  ) : BOOLEAN;
VAR
    i : CARDINAL;
BEGIN
    i := Search(S,Word,1);
    IF (i > 0) AND
       ((i = 1) OR (NOT Alphabetic(S[i-1]))  ) THEN
        RemoveRestOfWord(S,i);
        RETURN TRUE;
    END;
    RETURN FALSE;
END MatchWord;



PROCEDURE MatchADurationUnit( VAR   S    : ARRAY OF CHAR;
                              VAR   TU   : ADurationUnit    ) :BOOLEAN;
VAR
    S2  : ARRAY [0..10] OF CHAR;
BEGIN
    TU := Minutes;
    LOOP
        (*
        CASE TU OF
            Minutes:  SetString(S2,"MI");
          | Hours:    SetString(S2,"H");
          | Days:     SetString(S2,"D");
          | Weeks:    SetString(S2,"W");
          | Months:   SetString(S2,"MO");
          | Years:    SetString(S2,"Y");
          ELSE EXIT;
        END;
        *)
        GetMessage(ModuleNumber+40+ORD(TU),S2);

        IF (MatchWord(S,S2)) THEN
            RETURN TRUE;
        END;
        IF (TU >= Years) THEN
            EXIT;
        END;
        INC(TU);
    END;
    RETURN FALSE;
END MatchADurationUnit;






PROCEDURE MatchADuration( VAR   S    : ARRAY OF CHAR;
                          VAR   Quantity : CARDINAL;
                          VAR   TimeUnit : ADurationUnit;
                          VAR   Plus : BOOLEAN      ) :BOOLEAN;
VAR
    i        : CARDINAL;
BEGIN
    Plus := TRUE;
    TimeUnit := Days;

    IF (NOT MatchADurationUnit(S,TimeUnit)) THEN
        RETURN FALSE;
    END;

    TrimFront(S);

    LOOP
        IF (S[0] = 0C) THEN
            RETURN FALSE;
        ELSIF (S[1] = "+") THEN
            Plus := TRUE;
            Remove(S,1,1);
        ELSIF (S[1] = "-") THEN
            Plus := FALSE;
            Remove(S,1,1);
        ELSE
            EXIT;
        END;
    END;

    TrimFront(S);

    i := 1;
    Quantity := StoC(S,i);
    IF (i = 1) THEN
        Quantity := 1;
    ELSE
        Remove(S,1,i-1);
    END;

    RETURN TRUE;

END MatchADuration;






PROCEDURE MatchAMonthName(  VAR S      : ARRAY OF CHAR;
                            VAR Month  : CARDINAL       ) : BOOLEAN;
VAR
    M  : CARDINAL;
    s1 : AMonthString;
BEGIN
    M := Jan;
    LOOP

        CtoM( M, s1 );  (* Formerly used the MonthAbbrevArray. RSC 12/21/88 *)
        Upshift( s1 );

        IF (MatchWord(S, s1 )) THEN
            Month := M;
            RETURN TRUE;
        ELSIF (M = Dec) THEN
            RETURN FALSE;
        ELSE
            INC(M)
        END
    END;
END MatchAMonthName;





PROCEDURE ProbableYear(ThisMonth,ThisYear,Month:CARDINAL):CARDINAL;
CONST
    Window = 2;
BEGIN
       (* If the month entered differs by more than ? from the
          current month, it is probably from a different year. *)
   IF (Month < ThisMonth) AND (ThisMonth - Month > Window) THEN
       RETURN ThisYear + 1;
   ELSIF (Month > ThisMonth) AND (Month - ThisMonth > 12-Window) THEN
       RETURN ThisYear - 1;
   ELSE
       RETURN ThisYear;
   END;
END ProbableYear;










    (*  ParseDate -- Parses the string.

        19-Sep-89 RSC

        Pass down a start date for use in determining the defaults
        for end dates!!
    *)
PROCEDURE XParseDate (VAR s:ARRAY OF CHAR;
                      VAR TimeInfo : ATimeInfo;
                      VAR TimeUnitsFound : ASetOfADurationUnit )
               : BOOLEAN;
VAR
    i         : CARDINAL;
    ThisMonth : CARDINAL;
    ThisYear  : CARDINAL;
    Quantity  : CARDINAL;
    InternalS : ARRAY [0..41] OF CHAR;
    s2        : ARRAY [0..5] OF CHAR;
    TimeUnit  : ADurationUnit;
    Fiscal,
    Plus      : BOOLEAN;




    PROCEDURE ItsBad;
    BEGIN
        DisplayMessage(ModuleNumber+6);   (*  'Format dates like "22-Oct-84 10:00pm".'  *)
    END ItsBad;




    PROCEDURE GetHourOrMinute():BOOLEAN;
    VAR
        i,k: CARDINAL;
    BEGIN
        i := 1;
        k := StoC(InternalS,i);
        Remove(InternalS,1,i-1);   (* Remove what we matched. *)

        WITH TimeInfo DO
            IF (Hours IN TimeUnitsFound) THEN
                IF (k <= 59) THEN
                    tiMinute := k;
                    INCL(TimeUnitsFound,Minutes);
                ELSE
                    ItsBad;
                    RETURN FALSE;
                END;
            ELSE
                tiHour := k;
                INCL(TimeUnitsFound,Hours);
                IF (tiHour >= 100) THEN                 (* Military time. *)
                    tiMinute := tiHour MOD 100;
                    tiHour   := tiHour DIV 100;
                    INCL(TimeUnitsFound,Minutes);
                END;
            END;
        END;

        RETURN TRUE;
    END GetHourOrMinute;



    PROCEDURE GetAMorPM():BOOLEAN;
    VAR
        i         : CARDINAL;
        KeyLength : INTEGER;
        AMString, PMString : ARRAY [0..15] OF CHAR;
    BEGIN
            (* AMString gets the AM designation, up to the first
               difference between it and the PM designation. *)
        GetGaGaMessage( TimeFormatModuleNumber + 0, AMString); (* "am" *)
        GetGaGaMessage( TimeFormatModuleNumber + 1, PMString); (* "pm" *)
        Upshift(AMString);
        Upshift(PMString);
        KeyLength := Compare(AMString,PMString);
        IF (KeyLength < 0) THEN
           KeyLength := -KeyLength;
        END;
        SetLengthOf(AMString,KeyLength);
        SetLengthOf(PMString,KeyLength);

        i := Search(InternalS,AMString,1);
        IF (i = 1) THEN
            IF (TimeInfo.tiHour = 12) THEN TimeInfo.tiHour := 0 END;
            RemoveRestOfWord(InternalS,1);
            RETURN TRUE;
        END;

        i := Search(InternalS,PMString,1);
        IF (i = 1) THEN
            IF (TimeInfo.tiHour <= 11) THEN INC(TimeInfo.tiHour,12) END;
            RemoveRestOfWord(InternalS,1);
            RETURN TRUE;
        END;

        RETURN FALSE;

    END GetAMorPM;





    PROCEDURE GetYearMonthDayOrHour():BOOLEAN;
    VAR
        i,k                         :   CARDINAL;
        NYearsInTwentyFirstCentury  :   CARDINAL;
        InTwentyFirstCentury        :   BOOLEAN;

    BEGIN
        i := 1;
        k := StoC(InternalS,i);
        NYearsInTwentyFirstCentury := TimeTable.FirstYear + YearsOnFile - 2000;
        InTwentyFirstCentury := ( k <= NYearsInTwentyFirstCentury );

        Remove(InternalS,1,i-1);   (* Remove what we matched. *)

        IF (s[0] >0C) AND (InternalS[1]=":") THEN
            TimeInfo.tiHour := k;
            INCL(TimeUnitsFound,Hours);
            RemoveIt;   (* Remove ":" *)
              (* For the USA, months as numbers typically precede the day of month. *)
        ELSIF (USADate) AND
              (NOT (Months IN TimeUnitsFound)) AND (k <= 12) THEN
            IF (k = 0) THEN         (* 4/7/89 EGK *)
                ItsBad;
                RETURN FALSE;
            END;
            TimeInfo.tiMonth := k-1;
            INCL(TimeUnitsFound,Months);
            IF (NOT (Days IN TimeUnitsFound)) THEN
                TimeInfo.tiDay := 1;
            END;
            IF (NOT (Years IN TimeUnitsFound)) THEN
                TimeInfo.tiYear := ProbableYear(ThisMonth, ThisYear, TimeInfo.tiMonth );
            END;
        ELSIF (NOT (Days IN TimeUnitsFound)) AND (k <= 31) THEN
            IF (k = 0) THEN         (* 4/7/89 EGK *)
                ItsBad;
                RETURN FALSE;
            END;
            TimeInfo.tiDay := k;
            INCL(TimeUnitsFound,Days);
                (* For (European) *)                 (* 4/7/89 EGK    *)
        ELSIF (NOT (Months IN TimeUnitsFound)) AND (k <= 12) AND (k > 0) THEN
            IF (k = 0) THEN         (* 4/7/89 EGK *)
                ItsBad;
                RETURN FALSE;
            END;
            TimeInfo.tiMonth := k-1;
            INCL(TimeUnitsFound,Months);
            IF (NOT (Years IN TimeUnitsFound)) THEN
                TimeInfo.tiYear := ProbableYear(ThisMonth, ThisYear, TimeInfo.tiMonth );
            END;
        ELSIF (NOT (Years IN TimeUnitsFound)) AND
              ((k >= 24) OR (InTwentyFirstCentury))  THEN
            TimeInfo.tiYear := k;
            IF (TimeInfo.tiYear <  80) THEN
                INC(TimeInfo.tiYear,2000);
            ELSIF (TimeInfo.tiYear < 100) THEN
                INC(TimeInfo.tiYear,1900);
            END;
            IF (TimeInfo.tiYear < 1980) OR (TimeInfo.tiYear >= TimeTable.FirstYear+YearsOnFile) THEN
                ItsBad;
                RETURN FALSE;
            END;
            INCL(TimeUnitsFound,Years);
        ELSIF (NOT (Hours IN TimeUnitsFound)) AND (k < 24) THEN
            TimeInfo.tiHour := k;
            INCL(TimeUnitsFound,Hours);
        ELSE
            ItsBad;
            RETURN FALSE;
        END;
        RETURN TRUE;
    END GetYearMonthDayOrHour;


    PROCEDURE SetToday;
    VAR
        SystemTime  :   ASystemTime;
    BEGIN
        GetDateAndTime( SystemTime );
        SystemTimeToTime( SystemTime, TimeInfo );
        TimeInfo.tiHour := 0;
        TimeInfo.tiMinute := 0;
        TimeUnitsFound := ASetOfADurationUnit{Years,Months,Days};
    END SetToday;

    PROCEDURE SetAsOfDate;
    BEGIN
        TimeUtoT(AsOfDate,TimeInfo);  (* 7/27/87 EGK *)
        TimeInfo.tiHour := 0;
        TimeInfo.tiMinute := 0;
        TimeUnitsFound := ASetOfADurationUnit{Years,Months,Days};
    END SetAsOfDate;



    PROCEDURE FindDay;
    VAR
        SystemTime  : ASystemTime;
        i           : CARDINAL;
        Found       : BOOLEAN;
        s           : ARRAY [0..99] OF CHAR;    (* 12-Jun-91 RSC declared. *)
        s2          : ARRAY [0..15] OF CHAR;

    BEGIN
            (* The words today, now, etc. can be used to set dates. *)
        i := 0;
        Found := FALSE;
        GetMessage( ModuleNumber+12, s );                      (* 26-Jun-91 *)
        WHILE (i <= 6) AND (NOT Found) DO 
                (* 11-Jun-91 RSC This to remove import of FormatCommon.
                *)
            INC(i);
            WordNumber( s, i, s2 );
            Found := MatchWord(InternalS,s2);
        END;
               
        IF (Found) THEN
            Fiscal := TRUE;
            CASE i OF 
                1 :  (* TODAY *)
                        SetToday;
               |2 :  (* NOW *)
                        GetDateAndTime( SystemTime );
                        SystemTimeToTime( SystemTime, TimeInfo );
                        TimeUnitsFound := ASetOfADurationUnit{Years,Months,Days};
               |3 :  (* TOMO *)
                        SetToday;
                        AdjustDate(TimeInfo,1,Days,TRUE);
               |4 :  (* YEST *)
                        SetToday;
                        AdjustDate(TimeInfo,1,Days,FALSE);
               |5 :  (* ASOF *)
                        SetAsOfDate;
                        (*    AdjustDate(TimeInfo,1,Days,FALSE); *)   (* 9/15/88 - WKH - Don't need to adjust*)
               |6 :  (* BOT *)
                        TimeUtoT(0,TimeInfo);
               |7 :  (* EOT *)
                        TimeUtoT(MaxDate,TimeInfo);
               ELSE
                    FatalError();
            END;
        END;

    END FindDay;



    PROCEDURE RemoveIt;
    BEGIN
        Remove(InternalS,1,1);     (* Remove the first character from the string. *)
    END RemoveIt;


    PROCEDURE GetDay ( VAR s1 : ARRAY OF CHAR );                   (* 28-May-90 MWP *)
    VAR
       S       : ARRAY [0..30] OF CHAR;
       LDay, i : CARDINAL;
    BEGIN

       LDay := Sun;

       LOOP

           CtoIntDay ( LDay, S );
           Upshift( S );

           IF ( LengthOf ( S ) > 2 ) THEN
              SetLengthOf ( S, 2);
           END;

           i := Search ( s1, S, 1 );

           IF ( i = 1 ) THEN                                       (* 29-May-90 MWP *)
              TimeInfo.tiDay := LDay;
              RemoveRestOfWord( s1, i );
              EXIT;                                                (* 29-May-90 MWP *)
           END;

           IF ( LDay = Sat) THEN
               EXIT;
           END;

           INC(LDay)
       END;

    END GetDay;


    PROCEDURE GetToken (  VAR S  : ARRAY OF CHAR;
                          VAR S1 : ARRAY OF CHAR ) : CARDINAL;
    VAR
       j  : CARDINAL;
    BEGIN
        j := 1;

        WHILE ( j <= ORD(S[0] ) ) AND ( S[j] <> " " ) DO
           CASE S[ j ] OF
               "0".."9" :
                      INC(j);
             |  "-",  ".",  "/", "," :
                      Remove ( S,j,1);
             ELSE
                RETURN ( 0 );
           END;
        END;


        IF ( j < ORD(S[0]) ) AND                                   (* 28-May-90 MWP *)
           ( S[j] <> " " ) THEN
           j := 0;
        ELSE
           DEC(j);
           SubStr ( S, S1, 1, j );
           Remove ( S, 1, j );
        END;

        RETURN ( j );

    END GetToken;


    PROCEDURE GetWeekNumbers ( VAR s : ARRAY OF CHAR ) : BOOLEAN;
    VAR
        LYear, LMonth, LDay : CARDINAL;
        WeekNumber, WeekDay : CARDINAL;
        CharCount           : CARDINAL;
        ok                  : BOOLEAN;
        Partial             : ARRAY [0..30] OF CHAR;
        s1                  : ARRAY [0..41] OF CHAR;
        W                   : ARRAY [0..30] OF CHAR;
        Y                   : ARRAY [0..30] OF CHAR;
    BEGIN

       ok := TRUE;

       Copy ( s, s1 );

       TrimFront ( s1 );

       TimeInfo.tiDay := 1;

       GetDay ( s1 );                                              (* 29-May-90 MWP *)

       WeekDay     := TimeInfo.tiDay;                              (* 28-May-90 MWP *)
       INCL ( TimeUnitsFound, Days );

       TrimFront ( s1 );

       CharCount := GetToken ( s1, Partial );

       CASE CharCount OF
           1,
           2 :
              Copy ( Partial, W );
              SetLengthOf ( Y, 0 );

       |   3, 4 :
              SubStr ( Partial, Y, 1, 2 );
              SubStr ( Partial, W, 3, CharCount - 2 );

         ELSE
            RETURN FALSE;
       END;

       WeekNumber := 1;
       LYear      := ThisYear;

       INCL ( TimeUnitsFound, Years );
       INCL ( TimeUnitsFound, Months );

       CalcDates ( Y, W, LYear, WeekNumber );

       ok :=  WeekNumberToTime (   WeekNumber, WeekDay,
                                   LYear, LMonth, LDay );

       IF ( ok ) THEN
          TimeInfo.tiMonth := LMonth;
          TimeInfo.tiDay   := LDay;
          TimeInfo.tiYear  := LYear;

          Copy ( s1, s );
       ELSE
          ItsBad ();
       END;

       RETURN ( ok );

    END GetWeekNumbers;



    PROCEDURE DoYear ( YrIn : CARDINAL; VAR YrOut : CARDINAL );
    BEGIN

         IF ( YrIn <  80 ) THEN
            INC( YrIn,2000 );
         ELSIF ( YrIn < 100 ) THEN
            INC( YrIn,1900 );
         END;

         YrOut := YrIn;

    END DoYear;


    PROCEDURE CalcDates ( VAR Y, W              : ARRAY OF CHAR;
                          VAR LYear, WeekNumber : CARDINAL );
    VAR
        Yr, Wk : CARDINAL;
    BEGIN

        Yr := LYear;
        Wk := WeekNumber;

        IF ( LengthOf ( Y ) > 0 ) THEN
            i := 1;
            Yr := StoC( Y, i );

            DoYear ( Yr, Yr );
        END;

        IF ( LengthOf ( W ) > 0 ) THEN
            i := 1;
            Wk := StoC( W, i );

            IF ( Wk > 53 ) THEN
                DoYear ( Wk, Yr );
                Wk := WeekNumber;
            END;
        END;

       LYear      := Yr;
       WeekNumber := Wk;

    END CalcDates;

BEGIN

    (* Removed SetToday() RSC 19-Sep-89 *)

    Fiscal := FALSE;


    ThisMonth := TimeInfo.tiMonth;
    ThisYear  := TimeInfo.tiYear;
    TimeUnitsFound := ASetOfADurationUnit{};

    SubStr(s,InternalS,1,HIGH(InternalS));
    LJust(InternalS);
    TrimRear(InternalS);
    Upshift(InternalS);

    IF (InternalS[0] = 0C) THEN
        ItsBad;
        RETURN FALSE;
    END;

    FindDay;    (* Search for key words that give the date. *)

        (* Check for the presence of the word indicating a fiscal year. *)

    GetMessage(ModuleNumber+10,s2);              (* "FY" *)
    IF (MatchWord(InternalS, s2 )) THEN
        Fiscal := TRUE;
    END;


    IF (MatchAMonthName(InternalS,TimeInfo.tiMonth)) THEN
        TimeInfo.tiDay := 1;
        INCL(TimeUnitsFound,Months);
        TimeInfo.tiYear := ProbableYear(ThisMonth, ThisYear, TimeInfo.tiMonth );
    END;


        (*  Find the first non-blank character. *)

    TrimFront(InternalS);


    (* For week number support. If the date format is week numbers,
       and we have not found any time units yet,
       first examine the date string to see if it can be parsed into
       a reasonable date. If it cannot, we will parse it in the
       normal fashion.
    *)

    IF ( UsingWeekNumbers ) AND                                     (* 2-Apr-90 MWP *)
       ( TimeUnitsFound = ASetOfADurationUnit{} ) THEN
      IF ( NOT GetWeekNumbers ( InternalS ) ) THEN
      END;
    END;


        (*  Get Year, Month, and Day. *)


    LOOP
        IF (InternalS[0]=0C) OR
           (Hours IN TimeUnitsFound) OR
           (ASetOfADurationUnit{Years,Days,Months} <= TimeUnitsFound) THEN
            EXIT;
        END;
        CASE InternalS[1] OF
            "0".."9"  :
                        IF (NOT GetYearMonthDayOrHour()) THEN
                            RETURN FALSE;
                        END;
          | " ",  "-",  ".",  "/", "," :
                        RemoveIt;
          | "+"       :
                        EXIT;
          ELSE
                        ItsBad;
                        RETURN FALSE;
        END;
    END;


        (*  Get Hour and Minute *)


    LOOP
        IF (InternalS[0] = 0C) THEN
            EXIT;
        END;
        CASE InternalS[1] OF
            "0".."9" :
                        IF (NOT GetHourOrMinute()) THEN
                            RETURN FALSE;
                        END;
(* 26-Oct-90 TGS: go ahead and see if it is am/pm in any case; not
                  everybody uses A-Z for am/pm designators...
          | "A".."Z" :
                        IF (NOT GetAMorPM()) THEN
                            RETURN FALSE;
                        END;
*)
          | ":"," ","."  :
                        RemoveIt;
          | "+", "-" :
                        EXIT;
        ELSE
            IF (NOT GetAMorPM()) THEN
                RETURN FALSE;
            END;
(* 26-Oct-90 TGS
            ItsBad;
            RETURN FALSE;
*)
        END;
    END;

        (* To handle cases where only the month was given, but, because
           it was a number, we thought it was the day. *)

    IF (Days IN TimeUnitsFound) AND ( NOT (Months IN TimeUnitsFound)) THEN
        IF (TimeInfo.tiDay < 1) THEN           (* 4/7/89 EGK *)
            ItsBad;
            RETURN FALSE;
        END;
        TimeInfo.tiMonth := TimeInfo.tiDay-1;
        TimeInfo.tiDay := 1;
        EXCL(TimeUnitsFound,Days);
        INCL(TimeUnitsFound,Months);
    END;


    IF (TimeInfo.tiHour > 23) THEN
        ItsBad;
        RETURN FALSE;
    END;

    IF (NOT Fiscal) THEN
        CalendarYearToFiscalYear( TimeInfo.tiMonth, TimeInfo.tiYear );
    END;


    IF (InternalS[0] > 0C) THEN
        IF (MatchADuration(InternalS,Quantity,TimeUnit,Plus)) THEN
            AdjustDate(TimeInfo,Quantity,TimeUnit,Plus);
        ELSE
            ItsBad;
            RETURN FALSE;
        END;
    END;


    RETURN TRUE;

END XParseDate;






BEGIN

    ParseDate := XParseDate;        (* Install procedure. *)

END ParseTime.
