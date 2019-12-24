IMPLEMENTATION MODULE Timei;

(*  =========================================================================
    Last Edit : June 24, 1991 5:02PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Converts units of time from different formats

    MODIFICATION HISTORY:

        31-Jul-90 RSC  Cleared out tiSeconds in TimeUtoT.
        16-Aug-90 RSC  AJusted KDay so that it can deal with more than
                       65535/1461 years (44).  Now it can handle
                       65535/366  years (179).  This helps BigTimeU.
         5-Oct-90 PFG  Renamed TtoTimeU to TtoAbsTimeU, TimeUtoT to 
                       AbsTimeUtoT, KDay to AbsKDay and KDate to AbsKDate.  
                       The "Abs" procedures can be used whenever real 
                       calendar dates should always be used (rather than
                       fiscal dates), such as for the BigTime formatters.
                       Only AbsKDay and AbsKDate are currently exported.
                       The new TtoTimeU, TimeUtoT, KDay and KDate adjust for 
                       fiscal year.  Also adjusted SystemTimeToTime and
                       TimeToSystemTime.
        27-Oct-90 RSC  Ajustments for half hour days.  The format of the
                       TimeTable changed.  Rule: If you have half hour days,
                       precision must be half hours or smaller.  Other minor
                       improvements where noted.
        15-Feb-91 TGS  DaysInMonth handles special case where FY starts in
                       Feb.
         7-May-91 RSC  TimeUtoT was eroniously reporting extra TICS as
                       extra MINUTES.
        24-Jun-91 RSC  AbsTimeUtoT was using DaysInMonth, which redundantly
                       checks for fiscal time; I created an AbsDaysInMonth.
                       Same prob in AbsTtoTimeU.
         4-Jul-91 AJL  Rearrange the minutes calculation in AbsTimeUtoT to
                       avoid underflow.
        25-Jul-91 LAA  TimeUtoYYMM was having problems with MaxDate.  The
                       "real" problem is that a binary search like this 
                       doesn't work so well when there are duplicates - i.e.
                       the months after work time, where TicksAtStartOfMonth
                       are all MaxDate.  The search won't stop at the first
                       such month, it stops (in the case I looked at) a couple
                       of months later.  A date of 65534 seems to work fine,
                       so I fixed it with a special case for MaxDate.  The
                       correct solution would be to set Last to the first
                       month whose Ticks... = MaxDate, but that would impact
                       the speed of every date calculation.  We could keep
                       track of this special month, since it only changes when
                       we reorganize the calendar, so when there's time ...
    =========================================================================
*)


    FROM Timeu  IMPORT  SMUPH, TimeTable, YearsOnFile,
                        SMU, GetStartingMonth;

    FROM Clock      IMPORT GetDateAndTime, ASystemTime;

    FROM Dialog     IMPORT Message, FatalError;

    FROM LStrings   IMPORT ConcatLS;

    FROM MsgFile    IMPORT GetMessage, DisplayMessage, ConcatMessage;



CONST
    MAXCARDINAL  = 65535;
    BigTime      = MAXCARDINAL;
    ModuleNumber = 0400;              (*  For GetMessage     *)
    Feb = Jan + 1;




(*  Return the current date and time in terms of the current
    calendar TimeTable.
*)
PROCEDURE FindToday (): ADate;
VAR
    Today      : ADate;
    TimeInfo   : ATimeInfo;
    SystemTime : ASystemTime;
    ok         : BOOLEAN;
BEGIN
    GetDateAndTime(SystemTime);
    SystemTimeToTime( SystemTime, TimeInfo );

    ok := TtoTimeU(TimeInfo, Today);    (* 27-Oct-90 RSC *)

    RETURN Today;

END FindToday;





PROCEDURE AbsDaysInMonth(Year,Month:CARDINAL):CARDINAL;
VAR
    Days,
    StartingMonth : CARDINAL;
BEGIN

    IF (Month = Feb) THEN
        IF (Year MOD 4 = 0) THEN
            Days := 29;
        ELSE
            Days := 28;
        END
    ELSE
        IF (Month < 7) THEN INC(Month) END;
        Days := 30 + (Month MOD 2);
    END;

    RETURN Days;

END AbsDaysInMonth;





    (* Daysinmonth -- Computes the number of days in the given month
                     given the year and month. *)

        (* This routine actually is very lucky: unlike in most centuries,
           the year 2000 is a leap year.    But, this routine would
           not work for 1900 or 2100. *)

PROCEDURE DaysInMonth(Year,Month:CARDINAL):CARDINAL;
VAR
    StartingMonth : CARDINAL;
BEGIN

    IF (Month = Feb) THEN
            (* 13-Jan-91 TGS Special case: FY starts Feb *)
        GetStartingMonth(StartingMonth);
        IF (StartingMonth = Feb) THEN
            DEC(Year);
        END;
    END;

    RETURN AbsDaysInMonth(Year,Month);

END DaysInMonth;




PROCEDURE CalendarYearToFiscalYear(    Month : CARDINAL;
                                   VAR Year  : CARDINAL);  (* 22-Oct-90 PFG *)

VAR
    StartingMonth : CARDINAL;

BEGIN

    GetStartingMonth(StartingMonth);
    IF (StartingMonth > Jan) THEN       (* User modified starting month *)
        IF (Month >= StartingMonth) THEN
            INC(Year);            (* Change to fiscal year *)
        END;
    END;

END CalendarYearToFiscalYear;




PROCEDURE FiscalYearToCalendarYear(     Month : CARDINAL;
                                    VAR Year  : CARDINAL); (* 22-Oct-90 PFG *)

VAR
    StartingMonth : CARDINAL;

BEGIN

    GetStartingMonth(StartingMonth);
    IF (StartingMonth > Jan) THEN       (* User modified starting month *)
        IF (Month >= StartingMonth) THEN
            DEC(Year);                  (* Go back to calendar year *)
        END;
    END;

END FiscalYearToCalendarYear;



    (* KDAY -- Convert a year/month/day triplet to a serial date.
              Years are Gregorian, months 0..11, days 1..31.
              Mar. 1, 1980 is day 1.    Valid dates are in range
              of March 1, 1980 .. Dec. 31, 1999.
              Based on Algorithm 199, CAACM.
    *)

PROCEDURE KDay(year,month,day:CARDINAL) : CARDINAL ;

BEGIN

    FiscalYearToCalendarYear(month, year);

    RETURN(AbsKDay(year, month, day));

END KDay;


PROCEDURE AbsKDay(year,month,day:CARDINAL) : CARDINAL ;

BEGIN

    year := year - 1980;
    IF (month > 1) THEN
        DEC(month,2)
    ELSE
        INC(month,10);
        DEC(year);
    END;

    (* 16-Aug-90 RSC OLD FORMULA:

             ((1461 * year) DIV 4)
            + (((153 * month) + 2) DIV 5)
            + day

       NEW FORMULA:
    *)

    RETURN     (365 * year) + (year DIV 4)

            + (((153 * month) + 2) DIV 5)
            + day;


END AbsKDay;






    (*  DAYOFWEEK -- Computes the day of the week (Sun..Sat) given
                    a year, month, and day.  Works FOR 1980..1999.
                    Years are 1980..1999, Month is 0..11, day is
                    1..31.  *)

PROCEDURE DayOfWeek (year,month,day:CARDINAL):CARDINAL ;
VAR
    StartingMonth   : CARDINAL;
BEGIN
    RETURN (KDay(year,month,day) + 5) MOD 7
END DayOfWeek;




(* 5-Oct-90 PFG   Old TtoTimeU renamed to TtoAbsTimeU.  New one assumes the
                  TimeInfo record has been adjusted for fiscal year.  The
                  TimeU return is adjusted back to the calendar year.
*)

PROCEDURE TtoTimeU (    TimeInfo : ATimeInfo;
                    VAR TimeU    : ADate ) : BOOLEAN;

BEGIN

    FiscalYearToCalendarYear(TimeInfo.tiMonth, TimeInfo.tiYear);

    RETURN TtoAbsTimeU(TimeInfo, TimeU);

END TtoTimeU;






(* Given a TimeInfo record, return an internal date.
   Extensively changed by RSC 27-Ovt-90.
*)
PROCEDURE TtoAbsTimeU(      TimeInfo : ATimeInfo;
                        VAR TimeU    : ADate      ) : BOOLEAN;
VAR
    Day,
    i,
    QtrHour,
    DaysQtrHours,
    YearIndex       : CARDINAL;
    ok              : BOOLEAN;


    PROCEDURE DoINC( VAR X : CARDINAL; Y : CARDINAL );
    BEGIN

        IF (X  > (MAXCARDINAL - Y)) THEN
            X  := MAXCARDINAL;
            ok := FALSE;
        ELSE
            INC(X,Y);
        END;

    END DoINC;

BEGIN
    TimeU := 0;

    WITH TimeInfo DO

            (* **** PARAMETER CHECKING ****

                   If parameters are out of range, we exit below in the
                   IF (NOT ok) test.
            *)
        ok := (tiHour   <  24)   AND
              (tiMinute <  60)   AND
              (tiMonth  <= Dec)  AND
              (tiDay    <= AbsDaysInMonth(tiYear,tiMonth)); (* 24-Jun-91 RSC *)

        WITH TimeTable DO

            IF (tiYear >= FirstYear+YearsOnFile) THEN
                TimeU  := MAXCARDINAL;
                tiYear := 0; (* Force us to exit in this next test ... *)
            END;

            IF (NOT ok) OR (tiYear < FirstYear) THEN
                RETURN ok;
            END;

                (* **** END OF PARAMETER CHECKING **** *)

            YearIndex := tiYear - FirstYear + 1;

            WITH YearTable[YearIndex,tiMonth] DO

                      (* Total clock ticks up to the start of this month.
                      *)
                TimeU := TicsAtStartOfMonth;

                    (*  If day bit is on, its holiday time, so
                        set hour and minute to start of next work day.
                    *)
                IF (tiDay IN YearMap) THEN
                    tiHour   := 0;
                    tiMinute := 0;
                END;

                Day := StartDay; (* Day of week that starts the month. *)
                i   := 1;

                    (* Compute how many tics are in each day of the month
                       up to the day we are interested in.
                    *)
                WHILE (i < tiDay) DO
                    IF (NOT (i IN YearMap)) THEN
                        DoINC(TimeU, WeekTable[Day].TicsInDay);
                    END;
                    Day := (Day+1) MOD 7;
                    INC(i);
                END;
            END;

                (* Note that "Day" now reflects the correct day of
                   week, one past tiDay-1.
                *)

                (* Compute the half hour we are interested in.
                   HalfHour 0 is the FIRST half hour of the day.
                   tiHour can be 0..23, timinute can be 0..59.
                *)
            QtrHour := (tiHour * 4) + (tiMinute DIV 15);

            WITH WeekTable[Day] DO

                    (* Check that this is a working qtr hour.
                       Allow the first minute of the day to pass
                       this check, however, since
                       that is the default if no time is entered.
                    *)
                IF (QtrHour IN WeekMap) AND
                   ( (QtrHour<>0) OR (tiMinute<>0) ) THEN
                        (* Set minute to start of next working hour. *)
                    tiMinute := 0;
                END;

                i             := 0;
                DaysQtrHours  := 0;
                WHILE (i < QtrHour) DO
                    IF (NOT (i IN WeekMap)) THEN
                        INC(DaysQtrHours);
                    END;
                    INC(i);
                END;

                (* Compute working minutes in the day and devide by the
                   smallest number of minutes allowed.
                *)
                i := ((DaysQtrHours * 15) + (tiMinute MOD 15)) DIV SMU;

                DoINC( TimeU, i );  (* Add tics to summ *)

            END;
        END;

            (* TIMEU now reflects total time since the first moment of the
               first day of the first year on the calendar.
            *)

    END;

    RETURN ok;

END TtoAbsTimeU;






(* 5-Oct-90 PFG   Old TimeUtoT renamed to AbsTimeUtoT.  New one adjusts for
                  fiscal year.  
*)

PROCEDURE TimeUtoT (TimeU:ADate; VAR TimeInfo : ATimeInfo );

BEGIN

    AbsTimeUtoT(TimeU, TimeInfo);

    CalendarYearToFiscalYear(TimeInfo.tiMonth, TimeInfo.tiYear);

END TimeUtoT;



PROCEDURE AbsTimeUtoT (TimeU:ADate; VAR TimeInfo : ATimeInfo );
VAR
    i,
    Year,
    Day,
    LastDay,
    QtrHour,
    QuartersRemaining : CARDINAL;
    Minute,
    ExtraMinutes      : CARDINAL;  (* Minutes that don't fit into quarters. *)



    (* Find the Year and Month from the TimeU.  Do this via a binary
       search, rather than a sequential search.  On average, we will
       check 8 entries.  With a sequential search, we would check
       (YearsOnFile / 2) + (MonthsPerYear / 2), or 24, entries.
       Worst case for this search is 9 tests, worst case for the
       sequential method is 47 tests.

       Note that a sequential search would first find the YEAR, then
       the MONTH in that year.  Here we find the YEAR AND MONTH, so we
       are searching over 35*12 or 420 total entries.
    *)
    PROCEDURE TimeUtoYYMM(     TimeU     : ADate;
                           VAR TheYear,
                               TheMonth  : CARDINAL );
    VAR
        TicsByThisMonth,
        TicsByNextMonth : ADuration;
        NextMonth,
        NextYear,
        LowBound,
        Target,
        Last            : CARDINAL;
    BEGIN

        LowBound   := 0;
        Last       := (YearsOnFile * 12) - 1;

            (* Do a binary search on the sorted list of names.
            *)

        LOOP
            Target    := (LowBound + Last) DIV 2;

            TheYear   := (Target DIV 12) + 1;
            TheMonth  := (Target MOD 12);   (* We want 0..11 *)

                (* TicsByThisMonth are the tics by the start of this month.
                   TicsByNextMonth are the tics by the start of the next
                       month, which may be in the next year, or could be
                       off the end of the calendar.
                *)
            TicsByThisMonth := TimeTable.YearTable[TheYear, TheMonth].TicsAtStartOfMonth;

                (* Is the TimeU we are looking for BELOW this point
                   in the list?  If so, set the high point of the search
                   just BELOW this item.
                *)
            IF (TimeU < TicsByThisMonth) THEN

                Last     := Target - 1;

                (* Is the TimeU we are looking for ABOVE this point
                   in the list?  If so, set the starting point of the
                   search just ABOVE this item.

                   Note that here we must do the extra calculations to see
                   if the date we are searching for is in or beyond
                   the next month.
                *)
            ELSE
                NextMonth := TheMonth + 1;        (* 1..12, 12 is too many. *)
                NextYear  := TheYear  + (NextMonth DIV 12);
                NextMonth := NextMonth MOD 12;

                IF (NextYear > HIGH(TimeTable.YearTable)) THEN
                    TicsByNextMonth := MaxDate;
                ELSE
                    TicsByNextMonth := TimeTable.YearTable[NextYear, NextMonth].TicsAtStartOfMonth;
                END;

                IF (TimeU >= TicsByNextMonth)    AND
                   (TicsByNextMonth <> MaxDate) THEN

                        LowBound := Target + 1;

                    (* TimeU is sometime within this month.
                    *)
                ELSIF (TimeU = MaxDate) THEN                   (* 25-Jul-91 *)
                        TimeUtoYYMM( MaxDate - 1, TheYear, TheMonth );
                        RETURN;
                ELSE
                    EXIT;
                END;
            END;

                (* Search points pass if item doesn't exist.
                   This is not likely for small dates, so assume that the
                   date is beyond our range (lots of days off).
                *)

            IF (LowBound > Last) THEN
                TheYear  := YearsOnFile;
                TheMonth := Dec;
            END;

        END;

    END TimeUtoYYMM;


BEGIN

    WITH TimeInfo DO

        tiSecond := 0;

        TimeUtoYYMM( TimeU, Year, tiMonth );

        tiYear  := Year + TimeTable.FirstYear - 1;  (* eg, 1990 from 7 *)

        LastDay := AbsDaysInMonth(tiYear,tiMonth);  (* 24-Jun-91 RSC ABS *)

        WITH TimeTable.YearTable[Year,tiMonth] DO

            DEC( TimeU, TicsAtStartOfMonth );

                (* TimeU now is the number of tics away from the start
                   of the month.
                *)
            tiDay := 1;
            Day   := StartDay;  (* Day of week, like Tuesday *)
            LOOP
                IF (NOT (tiDay IN YearMap)) THEN
                    i := TimeTable.WeekTable[Day].TicsInDay;
                    IF (TimeU < i) THEN
                        EXIT;
                    END;
                    DEC( TimeU, i );
                END;

                    (* If this is the last day, then
                           EITHER TimeU = 0 (the first moment of the
                                            last day of the month)
                           OR We are off the end of the calendar
                                            (say, MaxDate and there are
                                            not enough days ON).

                           Remember both of these cases for the
                           Qtr Hour loop.  Here all we do is make sure
                           math won't overflow by making sure that TimeU
                           is not > tics today.
                    *)
                IF (tiDay = LastDay) THEN
                    i := TimeTable.WeekTable[Day].TicsInDay;
                    IF (TimeU  >= i) THEN
                        TimeU  := i - 1;
                    END;
                    EXIT;
                END;
                INC(tiDay);
                Day := (Day+1) MOD 7;
            END;
        END;

        QtrHour      := 0;
        Minute     := TimeU * SMU; (* Minutes into today *)
            (* Determine the number of 15-minute periods, plus the
               remainder of minutes. *)
        QuartersRemaining := Minute DIV 15;  (* Truncate *)
        ExtraMinutes      := Minute MOD 15;

        WITH TimeTable.WeekTable[Day] DO
            LOOP
                IF (NOT (QtrHour IN WeekMap) ) THEN
                    IF (QuartersRemaining = 0) THEN
                        EXIT;
                    END;
                    DEC(QuartersRemaining);  (* One less quarter hour *)
                END;

                    (* In case we are off the end of the calendar,
                       stop now.
                    *)
                IF (QtrHour = 95) THEN
                    EXIT;
                END;

                INC(QtrHour);
            END;
        END;
        tiHour   :=   QtrHour DIV 4;       (* Which hour of the day? *)
            (* minutes = fractional hour * 15 mins *)
        tiMinute := ((QtrHour MOD 4) * 15) + ExtraMinutes;
    END;

END AbsTimeUtoT;










PROCEDURE KDate(k: CARDINAL; VAR Year, Month, Day: CARDINAL);

BEGIN

    AbsKDate(k, Year, Month, Day);

    CalendarYearToFiscalYear(Month, Year);

END KDate;







PROCEDURE AbsKDate(k: CARDINAL; VAR Year, Month, Day: CARDINAL);

VAR
    LYear,
    K4            : LONGINT;

BEGIN
    (* 16-Aug-90 RSC OLD FORMULA:

        Year := ((4 * k) -1) DIV 1461;
        Day  := 4 * k - 1 - 1461 * Year;

       NEW FORMULA:
    *)


    K4    := 4L * VAL(LONGINT,k);

    LYear := (K4 - 1L) DIV 1461L;
    Year  := VAL(CARDINAL,LYear);

    Day   := VAL(CARDINAL,K4 - 1L - (1461L * LYear));



    Day := (Day + 4) DIV 4;
    Month := (5 * Day - 3) DIV 153;
    Day := 5 * Day - 3 - 153 * Month;
    Day := (Day + 5) DIV 5;
    IF Month < 10 THEN
        Month := Month + 2
    ELSE
        Month := Month - 10;
        Year := Year + 1
    END;
    Year := Year + 1980;

END AbsKDate;



PROCEDURE SystemTimeToTime(     SystemTime : ASystemTime; 
                            VAR TimeInfo   : ATimeInfo );
BEGIN
    TimeInfo.tiYear     := SystemTime.SysYear;
    TimeInfo.tiMonth    := SystemTime.SysMonth;
    TimeInfo.tiDay      := SystemTime.SysDay;
    TimeInfo.tiHour     := SystemTime.SysHour;
    TimeInfo.tiMinute   := SystemTime.SysMinute;
    TimeInfo.tiSecond   := SystemTime.SysSecond;

    CalendarYearToFiscalYear(TimeInfo.tiMonth, TimeInfo.tiYear);

END SystemTimeToTime;







PROCEDURE TimeToSystemTime(       TimeInfo : ATimeInfo;
                            VAR SystemTime : ASystemTime );
BEGIN

    FiscalYearToCalendarYear(TimeInfo.tiMonth, TimeInfo.tiYear);

    SystemTime.SysYear      := TimeInfo.tiYear;
    SystemTime.SysMonth     := TimeInfo.tiMonth;
    SystemTime.SysDay       := TimeInfo.tiDay;
    SystemTime.SysHour      := TimeInfo.tiHour;
    SystemTime.SysMinute    := TimeInfo.tiMinute;
    SystemTime.SysSecond    := TimeInfo.tiSecond;

END TimeToSystemTime;







PROCEDURE DurationToReal( Duration : ADuration ) : REAL;
BEGIN
    RETURN( FLOAT ( Duration ) );
END DurationToReal;





PROCEDURE RealToDuration( r : REAL ) : ADuration;
BEGIN
    RETURN( TRUNC( r ) );
END RealToDuration;





PROCEDURE DurationCounterToReal( DurationCounter : ADurationCounter ) : REAL;
BEGIN
    RETURN( FLOAT ( DurationCounter ) );
END DurationCounterToReal;





PROCEDURE RealToDurationCounter( r : REAL ) : ADurationCounter;
BEGIN
    RETURN( TRUNC( r ) );
END RealToDurationCounter;





PROCEDURE DateToReal( Date : ADate ) : REAL;
BEGIN
    RETURN( FLOAT ( Date ) );
END DateToReal;




PROCEDURE RealToDate( r : REAL ) : ADate;
BEGIN
    RETURN( TRUNC( r ) );
END RealToDate;





BEGIN
    Today  := MinDate;
END Timei.

