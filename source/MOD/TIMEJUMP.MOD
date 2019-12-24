IMPLEMENTATION MODULE TimeJump;

(*  =========================================================================
    Last Edit : November 5, 1990 5:14PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

    11/28/86 LAA    Incorporated Andrew's changes for a year beginning in a
                    month other than January.  Defaults to January.
    03/19/87 EGK    Incorporated Andrew's changes for a week beginning on a
                    day other than Sunday.  Defaults to Sunday.
    03/24/87 EGK    Removed code to handle starting months.  Now uses
                    GetStartingMonth and SetStartingMonth from Timeu.
    21-Dec-88 LAA   Changed imports for Laslo reorganization.
    30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
    19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                    date structure, ATimeInfo. 
    5-Oct-90  PFG   Removed incrementing of year to handle fiscal years.
                    Now handled in Timei procedures.
    2-Nov-90  RSC   Minor changes for qtr hours.  Also some residual touches
                    to fiscal year support.
    =========================================================================
*)



FROM TimeFormat   IMPORT
    (* TYPE *)          AnEndDateStyle,
    (* PROC *)          DtoS, TimeAsEndDateStyle;

FROM Timei        IMPORT
    (* CONST *)         Jan, Dec,
    (* TYPE *)          ADuration, ADurationUnit, ADate, ATimeInfo,
    (* PROC *)          TtoTimeU, TimeUtoT, KDay, DayOfWeek, KDate;

FROM Timeu        IMPORT
    (* VAR *)           SMUPH, TimeTable, WeeksBeginOn,
    (* PROC *)          GetStartingMonth;




CONST
    MAXCARDINAL  = 65535;








    (* FindStartDateOf -- Given an input date, find the start of the
                          hour, day, week, month or year that includes
                          that date. *)

PROCEDURE FindStartDateOf(Date:ADate;TimeUnit:ADurationUnit):ADate;
VAR
    TimeInfo      : ATimeInfo;
    i, w, d       : CARDINAL;
BEGIN
    TimeUtoT(Date,TimeInfo);
    WITH TimeInfo DO
        IF (TimeUnit > Minutes) THEN
            tiMinute := 0;
        END;
        IF (TimeUnit > Hours) THEN
            tiHour := 0;
        END;

        IF (TimeUnit = Weeks) THEN
                (* Find the Sequential day number, then subtract as many days
                as necessary to get back to a day which is the beginning of a
                week.    *)
            d := KDay(tiYear,tiMonth,tiDay)
                 -
                 (7+DayOfWeek(tiYear,tiMonth,tiDay)-WeeksBeginOn) MOD 7;       (* 3/24/87 EGK *)
                (* Convert that sequential day back to a (year,month,day)
                triplet. *)
            KDate(d,tiYear,tiMonth,tiDay);
        ELSIF (TimeUnit = Months) THEN
            tiDay := 1;
        ELSIF (TimeUnit >= Years) THEN
            tiDay := 1;
            GetStartingMonth(tiMonth);               (* 3/24/87 EGK *)
        END;
    END;

        (*  Find the next working moment. *)

    IF NOT (TtoTimeU(TimeInfo,w)) THEN
        w := Date;
    END;

    RETURN w;
END FindStartDateOf;



    (* FindNextKeyDate -- Given a date, and a time unit such as
                          hour, day, week etc., find the next
                          hour, day, week etc.  *)


PROCEDURE FindNextKeyDate(Date:ADate; TimeUnit:ADurationUnit):ADate;
VAR
    TimeInfo      : ATimeInfo;
    d             : CARDINAL;
    StartingMonth : CARDINAL;
BEGIN

    TimeUtoT(Date, TimeInfo);
    WITH TimeInfo DO
        IF (TimeUnit > Hours) THEN
            IF (TimeUnit >= Years) THEN
                GetStartingMonth(tiMonth);            (* 3/24/87 EGK *)
                tiDay   := 1;
                INC(tiYear);                          (* 3-Nov-90 RSC *)
            ELSIF (TimeUnit = Months) THEN
                IF (tiMonth >= Dec) THEN
                    tiMonth := Jan;
                ELSE
                    INC(tiMonth);
                END;
                GetStartingMonth(StartingMonth);
                IF (tiMonth = StartingMonth) THEN   (* 5-Nov-90 RSC *)
                    INC(tiYear);
                END;
                tiDay := 1;
            ELSE
                d := KDay(tiYear,tiMonth,tiDay);
                IF (TimeUnit = Weeks) THEN
                    INC(d, (WeeksBeginOn + 6 - DayOfWeek(tiYear,tiMonth,tiDay)) MOD 7 + 1 );      (* 3/24/87 EGK *)
                ELSE  (* Days. *)
                    INC(d);
                END;
                KDate(d,tiYear,tiMonth,tiDay);
            END;
            tiHour := 0;
            tiMinute := 0;
            IF (TtoTimeU(TimeInfo,Date)) THEN; END;
        ELSE
            IF (TimeUnit = Hours) THEN
                d := SMUPH - (Date MOD SMUPH);
            ELSE
                d := 1;
            END;
            IF (MAXCARDINAL - d > Date) THEN
                INC(Date,d);
            ELSE
                Date := MAXCARDINAL;
            END;
        END;
    END;

    RETURN Date;

END FindNextKeyDate;


    (* FindPriorKeyDate -- Given a date, and a time unit such as
                           hour, day, week etc., find the prior
                           hour, day, week etc.  *)


PROCEDURE FindPriorKeyDate(Date:ADate; TimeUnit:ADurationUnit):ADate;
BEGIN
    IF (Date > 0) THEN
        Date :=  FindStartDateOf(Date-1,TimeUnit);
    END;
    RETURN Date;
END FindPriorKeyDate;






    (* DateAsEndOfPeriod -- Format the date, but phrase it as the
                            end of a period of time.  For example,
                            if days end at 5pm and resume at 9am,
                            then TimeUtoS would call 9am "9am" but
                            we would call it "5pm."  *)

PROCEDURE DateAsEndOfPeriod(      Date    : ADate;
                              VAR S       : ARRAY OF CHAR  );
VAR
    TimeInfo : ATimeInfo;
BEGIN
    TimeAsEndDateStyle( Date, EndOfDay, TimeInfo );
    DtoS(TimeInfo,S);
END DateAsEndOfPeriod;




END TimeJump.
