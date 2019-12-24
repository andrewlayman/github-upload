IMPLEMENTATION MODULE WeekNumberInfo;

(*  =========================================================================
    Last Edit : October 26, 1990 3:27PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description:
        Week number support.

    MODIFICATION HISTORY:

         3-Mar-90 MWP  First version.
        17-Apr-90 MWP  Fixed bug causing whole week days to be incremented
                       one day to many.
        18-Apr-90 MWP  Fixed bug caused by fix of bug on 17th. ( Stupid Matt. )
         2-Jul-90 PHR  Export AWeekStartRecord and WeekStartTable, so that
                       TSEDTIME can write them for TLGS.
        24-Oct-90 RSC  Applied Debra's suggested fixes.
        26-Oct-90 PFG  Added Timei/TimeFormat/TimeInfo changes for 4.5.
        26-Oct-90 TGS  Applied MORE of Debra's suggested fixes.
        29-Oct-90 TGS  More fixes.
        31-Oct-90 TGS  Screw the fixes, let's code something that WORKS.
                       Re-wrote TimeToWeekNumber, WeekNumberToTime,
                       lobotomized InitWeekNumberInfo. Added WeeksInYear.
         2-Nov-90 TGS  One last fix -- er -- improvement.
    =========================================================================
*)

FROM LStrings       IMPORT
    (* PROCS *)             StoC;

FROM MsgFile        IMPORT
    (* PROCS *)             GetMessage;

FROM TimeFormat     IMPORT
    (* VAR *)               DefaultDateFormat;
                       

FROM Timei          IMPORT
    (* CONST *)             Jan, Dec,
    (* TYPES *)             ADate, ADurationUnit, ATimeInfo,
    (* PROCS *)             TtoTimeU, TimeUtoT, DaysInMonth, DayOfWeek, KDay,
                            KDate;

FROM Timeu          IMPORT
    (* CONST *)             YearsOnFile,
    (* VARS *)              WeeksBeginOn, TimeTable;




CONST
    ModuleNumber  =   9800;


VAR
   WholeWeeks     : BOOLEAN;  (* From phrase 9800 *)
   BoundaryDay    : CARDINAL; (* From phrase 9801 *)
   Day1IsJan1     : BOOLEAN;  (* From phrase 9802 *)
   FirstTime      : BOOLEAN;  (* Only read phrases first time *)




PROCEDURE CtoIntDay (     C : CARDINAL;
                      VAR s : ARRAY OF CHAR );
BEGIN
    GetMessage ( ModuleNumber + 10 + C, s );
END CtoIntDay;


PROCEDURE DaysInYear ( Year : CARDINAL ) : CARDINAL;
VAR
    i   : CARDINAL;
    Sum : CARDINAL;

BEGIN
    Sum := 0;

    FOR i := Jan TO Dec DO
       Sum := Sum + DaysInMonth ( Year, i );
    END;

    RETURN ( Sum );

END DaysInYear;


PROCEDURE WeeksInYear ( Year : CARDINAL ) : CARDINAL;

VAR
    NJan1Day, NDec31Day, NBoundaryDay : CARDINAL;
    TotalDays, TotalWeeksFound   : CARDINAL;

BEGIN

    (* Normalize some key days so we can compare and use them *)
    NJan1Day  := (7 + DayOfWeek(Year, Jan, 1)  - WeeksBeginOn) MOD 7;
    NDec31Day := (7 + DayOfWeek(Year, Dec, 31) - WeeksBeginOn) MOD 7;

    TotalDays := DaysInYear(Year) + NJan1Day;

    TotalWeeksFound := TotalDays DIV 7;
    IF (TotalDays MOD 7 > 0) THEN
        INC(TotalWeeksFound);
    END;

    (* We're done if using Partial weeks *)

    IF (WholeWeeks) THEN

        NBoundaryDay := (7 + BoundaryDay - WeeksBeginOn) MOD 7;

        (* Is Jan1 in Week 1 ? *)
        IF (NJan1Day > NBoundaryDay) THEN
            (* Jan1 is not in Week 1 *)
            DEC(TotalWeeksFound);
        END;

        (* Is Dec31 in last Week? *)
        IF (NDec31Day < NBoundaryDay) THEN
            (* Dec31 is not in this year's Whole weeks *)
            DEC(TotalWeeksFound);
        END;

    END;

    RETURN TotalWeeksFound

END WeeksInYear;


PROCEDURE TimeToWeekNumber (      Month, Day,
                                  Hour, Minute      : CARDINAL;
                             VAR  Year, WeekNumber,
                                  WeekDay           : CARDINAL ) : BOOLEAN;
VAR
    TDay        : CARDINAL;
    NJan1Day, NDec31Day,
    NBoundaryDay   : CARDINAL;
    i           : INTEGER;
BEGIN

    WeekDay       := DayOfWeek ( Year, Month, Day);

    (* Get day index *)
    TDay := KDay ( Year, Month, Day ) - KDay ( Year, Jan, 1 );

    (* Normalize some key days so we can compare and use them *)
    NJan1Day  := (7 + DayOfWeek(Year, Jan, 1)  - WeeksBeginOn) MOD 7;
    NDec31Day := (7 + DayOfWeek(Year, Dec, 31) - WeeksBeginOn) MOD 7;

    WeekNumber := (1 + TDay + NJan1Day) DIV 7;
    IF ((1 + TDay + NJan1Day) MOD 7 > 0) THEN
        INC(WeekNumber);
    END;

    (* We're done now unless using Whole weeks *)

    IF (WholeWeeks) THEN

        NBoundaryDay := (7 + BoundaryDay - WeeksBeginOn) MOD 7;
        
        IF (NJan1Day > NBoundaryDay) THEN
            DEC(WeekNumber);
        END;

        (* Is this day really in previous year's Whole Week? *)
        IF ((TDay < (7 - NJan1Day)) AND
            (NJan1Day > NBoundaryDay )) THEN

            IF (Year <= TimeTable.FirstYear) THEN 
                (* we can't represent it correctly *)
                WeekNumber := 1; 
                RETURN FALSE;
            END;

            DEC(Year);
            WeekNumber := WeeksInYear(Year);

        (* Is this day really in next year's Whole Week? *)
        ELSIF ((TDay >= (DaysInYear(Year) - NDec31Day - 1)) AND
            (NDec31Day < NBoundaryDay )) THEN

            IF (Year >= TimeTable.FirstYear + YearsOnFile - 1) THEN 
                (* we can't represent it correctly *)
                WeekNumber := WeeksInYear(Year);
                RETURN FALSE;
            END;

            INC(Year);
            WeekNumber := 1;
        
        END;
    END;

    RETURN TRUE;

END TimeToWeekNumber;


PROCEDURE TimeUToWeekNumber (     Timeu             : ADate;
                              VAR Year, WeekNumber,
                                  WeekDay,
                                  Hour, Minute      : CARDINAL ) : BOOLEAN;
VAR
    TimeInfo    : ATimeInfo;
    Month, Day  : CARDINAL;
    ok          : BOOLEAN;
BEGIN

    TimeUtoT ( Timeu, TimeInfo );

    Month := TimeInfo.tiMonth;
    Day := TimeInfo.tiDay;
    Hour := TimeInfo.tiHour;
    Minute := TimeInfo.tiMinute;
    Year := TimeInfo.tiYear;

    ok := TimeToWeekNumber (  Month, Day, Hour, Minute,
                              Year, WeekNumber, WeekDay  );

    RETURN ( ok );

END TimeUToWeekNumber;



PROCEDURE WeekNumberToTime (     WeekNumber, WeekDay : CARDINAL;
                             VAR Year, Month, Day    : CARDINAL ) : BOOLEAN;
VAR
    TDay, NBoundaryDay,
    NJan1Day, NDec31Day, 
    NWeekDay, WeeksThisYear : CARDINAL;

BEGIN

    IF ((Year < TimeTable.FirstYear ) OR
        (Year >= TimeTable.FirstYear + YearsOnFile - 1)) THEN
       RETURN FALSE;
    END;

    (* Normalize key days so we can compare them and compute with them *)
    NJan1Day  := (7 + DayOfWeek(Year, Jan, 1)  - WeeksBeginOn) MOD 7;
    NDec31Day := (7 + DayOfWeek(Year, Dec, 31) - WeeksBeginOn) MOD 7;
    NWeekDay  := (7 + WeekDay - WeeksBeginOn) MOD 7;

    (* Make the WeekNumber fit the year *)
    WeeksThisYear := WeeksInYear(Year);

    IF (WeekNumber < 1) THEN

        WeekNumber := 1;

    ELSIF (WeekNumber > WeeksThisYear) THEN

        WeekNumber := WeeksThisYear;

    END;

    IF (WholeWeeks) THEN

        NBoundaryDay:= (7 + BoundaryDay - WeeksBeginOn) MOD 7;
        
        (* Would it be before calendar? *)
        IF ((Year = TimeTable.FirstYear) AND
                (WeekNumber = 1) AND
                (NJan1Day <= NBoundaryDay) AND
                (NWeekDay < NJan1Day)) THEN

            TDay := KDay(Year, Jan, 1);

        (* Would it be after calendar? *)
        ELSIF ((Year = (TimeTable.FirstYear + YearsOnFile - 1)) AND
            (WeekNumber = WeeksThisYear) AND
            (NDec31Day < NBoundaryDay)) THEN

            TDay := KDay(Year, Dec, 31);

        (* Is Jan 1 in previous whole weeks year ? *)
        ELSIF (NJan1Day > NBoundaryDay) THEN

            TDay := KDay(Year, Jan, 1) 
                    + (WeekNumber) * 7
                    + NWeekDay - NJan1Day;

        ELSE
        (* Jan 1 is in whole weeks year *)

            TDay := KDay(Year, Jan, 1) 
                    + (WeekNumber - 1) * 7
                    + NWeekDay - NJan1Day;

        END;

    ELSE

        (* Partial Weeks *)

        IF ((WeekNumber = 1) AND
            (NWeekDay < NJan1Day)) THEN

            TDay := KDay( Year, Jan, 1);

        ELSIF ((WeekNumber = WeeksThisYear) AND
               (NWeekDay > NDec31Day)) THEN

            TDay := KDay( Year, Dec, 31);

        ELSE

            TDay := KDay( Year, Jan, 1) 
                    + ((WeekNumber-1) * 7) 
                    + NWeekDay - NJan1Day; 

        END;

    END;

    KDate( TDay, Year, Month, Day);
    RETURN TRUE;

END WeekNumberToTime;


PROCEDURE WeekNumberToTimeU (     Year, WeekNumber, WeekDay,
                                  Hour, Minute      : CARDINAL;
                              VAR Timeu             : ADate ) : BOOLEAN;
VAR
    Month, Day  : CARDINAL;
    ok          : BOOLEAN;
    TimeInfo    : ATimeInfo;

BEGIN

    ok := WeekNumberToTime ( WeekNumber, WeekDay, Year, Month, Day );

    TimeInfo.tiYear := Year;
    TimeInfo.tiMonth := Month;
    TimeInfo.tiDay := Day;
    TimeInfo.tiHour := Hour;
    TimeInfo.tiMinute := Minute;

    ok := ok AND TtoTimeU ( TimeInfo, Timeu );

    RETURN ( ok );

END WeekNumberToTimeU;


PROCEDURE InitWeekNumberInfo ();
VAR
    i,j             : CARDINAL;
    DaysLeft        : CARDINAL;
    s               : ARRAY [0..255] OF CHAR;

BEGIN

    IF ( FirstTime ) THEN
        (* Get phrases from phrases file. *)
        GetMessage ( ModuleNumber + 0, s );
        j := 1;
        i := StoC ( s, j );
        WholeWeeks := i = 1;


        GetMessage ( ModuleNumber + 1, s );
        j := 1;
        BoundaryDay := StoC ( s, j );

        (* This phrase is currently not implemented *)
        GetMessage ( ModuleNumber + 2, s );
        j := 1;
        i := StoC ( s, j );
        Day1IsJan1 := i = 1;

        FirstTime := FALSE;
    END;

    UsingWeekNumbers := AreWeActive ();

END InitWeekNumberInfo;



PROCEDURE AreWeActive () : BOOLEAN;
VAR
    i : CARDINAL;

BEGIN

    FOR i := 0 TO HIGH(DefaultDateFormat) DO
        WITH DefaultDateFormat[i] DO
            IF ( Unit = Weeks ) THEN
               RETURN TRUE;
            END;
        END;
    END;

    RETURN FALSE;

END AreWeActive;



BEGIN

     FirstTime := TRUE;
     UsingWeekNumbers := FALSE;

END WeekNumberInfo.

