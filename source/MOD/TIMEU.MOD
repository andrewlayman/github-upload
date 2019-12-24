IMPLEMENTATION MODULE Timeu;

        (* MODIFICATION HISTORY:

           Sep. 3, 1985  AJL -  Added support for HDefault, H0 and
                                DefaultDateFormat.

           Jun. 13, 1986 AJL -  Modified CompressTime to allow dates
                                to be specified right up to BigTime.
                                Previously, they were rejected a
                                little short.

           Jun. 26, 1986 AJL -  Moved SetDateAndTime and GetDateAndTime
                                to the Clock module.
           07/25/86 LAA     Added a new format to DtoS for unambiguous saving
                            of dates in the project file.
           03/19/87 EGK     Initialized WeeksBeginOn := Sun.
           03/24/87 EGK     Added support for setting the first fiscal month,
                            the month which begins a year.  This consists of
                            procedures GetStartingMonth and SetStartingMonth
                            and variable FirstFiscalMonth.
           06/15/87 RSC     Made DtoS call "TimeToString" in FormatAs.
            7/27/87 EGK     In StoD, replaced calls to GetDateAndTime with
                            TimeUtoT (AsOfDate, ... ) so that parsing looks
                            at as-of date instead of clock time.
            8/11/87 EGK     Modified DtoS to use DefaultDateOption instead of
                            DefaultDateFormat, which is no longer used.
           10/13/87 RSC     Added TimeAsEndDateStyle and FormatAsEndDateStyle.
           29-Oct-87 LAA    Added comments to UpScale and DownScale.
           24-Nov-87 AJL   -Added the StoEndD and PartialDateToDate procs.
                           -Changed default SMU to 60, SMUPH to 1.  This
                            sets the default precision to 1 hour.
           16-Dec-87 LAA   -Removed nested procedure SetAsOfDate and LeftFill
                            which appeared to not be used.
           17-Dec-87 LAA    Hooked in the assembler module AsmTimeu.
           29-Dec-87 AJL   -Added recognition of the keyword "ASOF".
                           -Changed "YEST", "TODAY", "NOW" and "TOMOR"
                            to be relative to the actual clock time, not
                            the AsOfDate. 
                           -Guess the ProbableYear when a month is given
                            but no year.
           16-Feb-88 AJL   -Changed PartialDateToDate so that it doesn't 
                            infer end times when hours or minutes are 
                            specified.  In other words, something like
                            5pm is taken as 5:00 pm. 
           15-Sep-88 WKH   -Removed call to AdjustDate for ASOF parsing in
                            FindDay.
           16-Sep-88 WKH   -Changed size of local array s in CompressTime
                            from 0..31 to 0..255
            1-Dec-88 AJL   -Made "." a legal hour to minute separator in
                            XParseDate, and also made the parsing scan
                            for am or pm using the phrases from gaga.  
                           -InitializingTime resets the month/day parsing
                            order.
           21-Dec-88 RSC    Removed all "Stoxxxxx" procedures and put them into
                            ParseTime.
            9-Mar-89 RSC    Remove code that checked for USA date, as it has
                            the side effect of destroying the stack, causing
                            somewhat random problems, including PMD's
                            during startup.  My fix was to cauterize the
                            wound, not to fix the problem.

                            ANDREW NEEDS TO FIX THIS.
           10-Mar-89 AJL   -Andrew fixed it. 
           21-Mar-89 RSC   -Added support for FSMUPH as FLOAT(SMUPH).
           12-Sep-89 LAA   CompressTime was overflowing the CARDINAL TimeU
                           variable when the date values input were within the
                           calendar but beyond 65,535 "ticks" of the beginning
                           of the calendar.  It now returns 65,535 and FALSE
                           under those conditions.  
           20-Nov-89 EGK   In PartialDateToDate, check the set of time units
                           found and put in suitable default values for the
                           missing ones.
            3-Jan-90 RSC   Initialize parts of the TimeTable so we don't bomb
                           when range checking is on and TLStart has not yet
                           run.

           22-Oct-90 RSC   Changed Hours to HalfHours in time table.
            3-Jul-91 PFG   Used new constant CalendarBaseYear rather than
                           hard-coded value.
        *)

    FROM Timei      IMPORT ADurationUnit, Jan, Dec, ADuration, Sun;

    FROM Dialog     IMPORT FatalError;

    FROM MsgFile    IMPORT DisplayMessage;

    FROM SYSTEM     IMPORT
        (* TYPE *)          ADDRESS,
        (* PROC *)          SIZE, ADR;

CONST
    MAXCARDINAL  = 65535;
    BigTime      = MAXCARDINAL;
    ModuleNumber = 0400;              (*  For GetMessage     *)



VAR
    FirstFiscalMonth : [Jan..Dec];
    Init             : BOOLEAN;

        (* Values for DaysInMonth procedure. *)


(*----------------------------------------------------------------------------
    UpScale --

    UpScale will convert an amount (n) of the specified TimeUnit into an
    internal duration (clock ticks, where one tick is SMU minutes).

    Note that if there are an odd number of half hours per day (StdDay),
    then SMUPH is >= 2, we cannot have hour precision.
----------------------------------------------------------------------------*)

PROCEDURE UpScale (n:CARDINAL; TimeUnit:ADurationUnit) : CARDINAL;
VAR
    Quantity,
    MaxT,
    x           : CARDINAL;

    PROCEDURE InDays(n,x:CARDINAL):CARDINAL;
    BEGIN
        IF (n <= MAXCARDINAL DIV x) THEN
            n := n * x;
        ELSE
            n := MAXCARDINAL;
        END;

        RETURN UpScale( n, Days );

    END InDays;

BEGIN
    IF (n = 0) THEN
        Quantity := 0;
    ELSE
        CASE TimeUnit OF

        Minutes: (* Round to nearest SMU minutes, but not < 1. *)

                 x := (n DIV SMU) + (((n MOD SMU) + (SMU DIV 2)) DIV SMU);

                 IF (x = 0) THEN
                     Quantity := 1;
                 ELSE
                     Quantity := x;
                 END;
          |
        Hours:   MaxT := (BigTime DIV SMUPH);
                 IF (n > MaxT) THEN
                     DisplayMessage(ModuleNumber+16);   (*  "Duration is too long."  *)
                     n := MaxT;
                 END;
                 Quantity := n * SMUPH;
          |
        Days:    x := TimeTable.StdDayTics; (* Tics per day *)
                 MaxT := (BigTime DIV x);
                 IF (n > MaxT) THEN
                     DisplayMessage(ModuleNumber+16);   (*  "Duration is too long."  *)
                     n := MaxT;
                 END;

                 Quantity := (n * x);
          |
        Weeks:   Quantity := InDays(n,TimeTable.StdWeek);
          |
        Months:  x := ((30 * TimeTable.StdWeek)+4) DIV 7;
                 Quantity := InDays(n,x);
          |
        Years:   MaxT := BigTime DIV 12;
                 IF n > MaxT THEN
                     n := MaxT;
                 END;
                 Quantity := UpScale(12*n,Months);    
        ELSE
            FatalError();
        END;
    END;

    RETURN Quantity;

END UpScale;





(*----------------------------------------------------------------------------
    DownScale --

    DownScale is the inverse of UpScale.  It takes a duration (internal clock
    ticks) and converts it to an amount of the indicated TimeUnit.
----------------------------------------------------------------------------*)

PROCEDURE DownScale( Scale:ADuration; TimeUnit:ADurationUnit):CARDINAL;
VAR
    Quantity,
    x           : CARDINAL;
BEGIN
    IF (Scale = 0) THEN
        Quantity := 0;
    ELSE
        CASE TimeUnit OF
            Minutes:  IF (Scale <= MAXCARDINAL DIV SMU) THEN
                          Quantity := Scale * SMU;
                      ELSE
                          Quantity := MAXCARDINAL;
                      END;
              |
            Hours:    Quantity := Scale DIV SMUPH;
              |
            Days:     x := TimeTable.StdDayTics; (* Tics per day *)
            
                      Quantity := Scale DIV x;
              |
            Weeks:    Quantity := (DownScale(Scale DIV TimeTable.StdWeek,Days));
              |
            Months:   x := ((30 * TimeTable.StdWeek)+4) DIV 7;
                      Quantity := (DownScale(Scale DIV x, Days));
              |
            Years:    Quantity := (DownScale(Scale DIV 12, Months));
        ELSE
            FatalError();
        END
    END;

    RETURN Quantity;

END DownScale;





 (* RSC moved the improved version here from Captions.  12/19/88 *)

PROCEDURE FindCorrectScale(Duration: ADuration; VAR Scale:ADurationUnit);
VAR
    n : CARDINAL;
BEGIN
        (*  Two cases:  (1)  The duration must fit into four digits.
                        (2)  Make the scale as fine as necessary to express
                             the duration as precisely as possible.
        *)
    IF (Duration > 0) THEN
        LOOP
            n := DownScale(Duration,Scale);
                (* Since we cannot control rounding here, these are the
                   rules:
                     a) 2 or more of anything is sufficient display
                        precision.
                     b) there is no scale < Minutes
                     c) anything that gives the precise duration is right.
                 *)
            IF (Scale = Minutes) OR
               (UpScale(n,Scale) = Duration) THEN  EXIT;
            END;
                (* Try greater precision. *)
            DEC(Scale);
        END;
        WHILE (n > 9999) AND (Scale < Years) DO
            INC(Scale);
            n := DownScale(Duration,Scale);
        END;
    END;
END FindCorrectScale;




(*----------------------------------------------------------------------------
    SetStartingMonth:

    Sets the internal value of the First Fiscal Month (the month which begins
    a year) to the value specified by Month.

    Preconditions:  Month must be in the range [Jan..Dec] to avoid an error.

----------------------------------------------------------------------------*)
PROCEDURE SetStartingMonth (Month: CARDINAL);
BEGIN
    IF (Month < Jan) OR (Month > Dec) THEN
        FatalError;
    ELSE
        FirstFiscalMonth := Month;
    END;
END SetStartingMonth;


(*----------------------------------------------------------------------------
    GetStartingMonth:

    Takes the current internal value of the First Fiscal Month and stores it
    in the variable Month.
----------------------------------------------------------------------------*)
PROCEDURE GetStartingMonth (VAR Month: CARDINAL);
BEGIN
    Month := FirstFiscalMonth;
END GetStartingMonth;





PROCEDURE SetSMU( NewSMU : CARDINAL );    (* Added by RSC 21-Mar-89 *)
BEGIN

    SMU               := NewSMU;
    SMUPH             := 60 DIV SMU;
    FSMUPH            := FLOAT( SMUPH );

END SetSMU;




(* 3-Jan-90  RSC Moved module init code here and added the init of the
                 Time Table.
*)
PROCEDURE ModuleInit();

    PROCEDURE Blast(    A       : ADDRESS;
                        Count   : CARDINAL );
    VAR
        Ptr : POINTER TO ARRAY [1..65000] OF CHAR;
        i   : CARDINAL;
    BEGIN

        Ptr := A;

        FOR i := 1 TO Count DO
            Ptr^[i] := 0C;
        END;

    END Blast;

BEGIN
    Init              := FALSE;
    SetSMU( 60 );   (* RSC 21-Mar-89 *)

    WeeksBeginOn      := Sun;
    FirstFiscalMonth  := Jan;


    WITH TimeTable DO
        FirstYear     := CalendarBaseYear;      (* 3-Jul-91 PFG   Was "1983" *)
        StdDayTics    := 8 * SMUPH;
        StdWeek       := 5;
        Blast( ADR(YearTable[1]), SIZE(YearTable) );
        Blast( ADR(WeekTable),    SIZE(WeekTable) );
    END;

END ModuleInit;





BEGIN
    ModuleInit();
END Timeu.
