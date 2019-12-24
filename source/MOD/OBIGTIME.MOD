IMPLEMENTATION MODULE OBigTimeU;

  (* BigTimeU - Big Time Units.

       This procedure provides the routines to convert into and out of time
       units that are absolute off some base of time.  That is, # of seconds
       since, say, 1980.

       Modification History -

       Jun 19, 1987  RSC  - First version.
       Aug. , 1987   AJL  - Modified to use KDay and KDate so that
                            the numbers really correspond to Julian
                            dates.  The BigTime is the number of
                            seconds since Feb. 29, 1980 12:00 am.
                            Julian Date = 2531959 + (Big / 86400).
                          - Changed the BigTimeArrays to local
                            from global to support reentrant code.

    15-Mar-89 RSC           If the date is outside TimeLine's range of
                            March 1, 1980 through Dec 31, 1999, set the
                            date to be just within the limits.
    14-Sep-89 KKC           Use TimeTable.FirstYear and TimeTable.FirstYear
                            + YearsOnFile as the lower and upper limit in
                            TimeToBigTime.
    30-Mar-90 RSC           Made Timeu to Timei/TimeForm conversions.
    15-Aug-90 RSC           Changed the scaling at the begining of
                            conversions to not scale for the calendar,
                            but for BigTime limitations only.
    20-Aug-90 RSC           For importing old versions of schedules, I
                            made this version.
  *)



FROM BigTimeU   IMPORT
    (* TYPE *)      ABigTime;

FROM Timei      IMPORT
    (* TYPE *)      ATimeInfo,
    (* PROC *)      KDay, KDate;




CONST  FMAXCARDINAL = 65535.0; (* Floating rep of biggest CARDINAL *)

       BaseYear     = 1981;          (* BigTime starts here. *)
       LastYear     = BaseYear + 65; (* And ends a little after here. *)

       CDay         = 1;
       CHour        = 2;
       CMinute      = 3;
       CSecond      = 4;


VAR    Factor : ARRAY [ CDay..CSecond ] OF REAL;








  (* BigTimeToTime - Convert out of BigTime units.

     Preconditions  - BigTime is from a prior call to TimeToBigTime.

     Postconditions - Year, Month, Day, Hour, Minute, Second are returned.
  *)


PROCEDURE BigTimeToTime(     BigTime     : ABigTime;
                         VAR Year,
                             Month,
                             Day,
                             Hour,
                             Minute,
                             Second      : CARDINAL );
VAR R : REAL;
    i : CARDINAL;
    Q : CARDINAL;
VAR
    BigTimeArray : ARRAY [ CDay..CSecond ] OF CARDINAL;
BEGIN
    R := (FLOAT(BigTime.High) * FMAXCARDINAL) + FLOAT(BigTime.Low);

    FOR i := CDay TO CSecond DO
        Q := TRUNC(R / Factor[i]);
        R := R - (FLOAT(Q) * Factor[i]);
        BigTimeArray[i] := Q;
    END;

    KDate(BigTimeArray[CDay],  Year, Month, Day );

    Hour   := BigTimeArray[ CHour   ];
    Minute := BigTimeArray[ CMinute ];
    Second := BigTimeArray[ CSecond ];

END BigTimeToTime;






BEGIN

    Factor[ CSecond ]             := 1.0;
    Factor[ CMinute ]             := 60.0;       (*           60 * 1  *)
    Factor[ CHour   ]             := 3600.0;     (*      60 * 60 * 1  *)
    Factor[ CDay    ]             := 86400.0;    (* 24 * 60 * 60 * 1  *)

END OBigTimeU.
