IMPLEMENTATION MODULE WorkHours;

    (* Modification History:

        RSC 21-Mar-89  Support SMUPH better, without needing to FLOAT(SMUPH).
        RSC 20-May-89  Renamed module as WorkHours from ManHours.  Added
                       DurationToRealTime and RealTimeToDuration.
        KKC 21-Feb-90  Remove ADate from the import statement.
        30-Mar-90 RSC  Made Timeu to Timei/TimeForm conversions.
        26-Jul-91 EGK  RealTimeToWorkHours and WorkHoursToRealTime were
                       using integer division instead of floating-point
                       division, which was causing truncation errors for
                       fractional hours-per-day values.
    *)

FROM Timei              IMPORT 
        (* TYPES *)        ADurationUnit, ADuration;

FROM Timeu              IMPORT 
        (* VARS  *)        SMUPH, FSMUPH,
        (* PROCS *)        UpScale;


CONST
      Zero        =     0.0;
      Point5      =     0.5;
      One         =     1.0;
      Sixty       =    60.0;
      MAXCARDINAL = 65535;
     FMAXCARDINAL = 65535.0;






 (* RealTimeToWorkHours - Convert a real number and Units to a number of
                         WorkHours.

     Preconditions  - RealTime is the quantity of Units
                      Units    is Minute, Hour, Day, Week, Month, or Year.

     Postconditions - RETURN value is the number of Work Hours.
 *)
PROCEDURE RealTimeToWorkHours( RealTime : REAL; Units : ADurationUnit ) : REAL;
CONST
    OneSixtyth = (One / Sixty);
VAR
    HoursPerUnit : REAL;
BEGIN
    CASE Units OF
       Minutes : HoursPerUnit := OneSixtyth;
    |  Hours   : RETURN RealTime;
    ELSE
       HoursPerUnit := FLOAT(UpScale(1,Units)) / FSMUPH;    (* 7/26/91 EGK *)
    END;
    RETURN (RealTime * HoursPerUnit);
END RealTimeToWorkHours;






 (* WorkHoursToRealTime - Convert man hours to a displayable time.  Like DownScale.

     Preconditions  - Duration is the number of clock tics.
                      Units    is Minute, Hour, Day, Week, Month, or Year.

     Postconditions - RETURN value is the displayable time in real format.
 *)
PROCEDURE WorkHoursToRealTime( WorkHours : REAL; Units : ADurationUnit ) : REAL;
BEGIN
    CASE Units OF
       Minutes : RETURN (Sixty * WorkHours);
    |  Hours   : RETURN WorkHours;
    ELSE
        RETURN (WorkHours / (FLOAT(UpScale(1,Units)) / FSMUPH));    (* 7/26/91 EGK *)
    END;
END WorkHoursToRealTime;





 (* RealTimeToDuration - Convert a real number and Units to a number of
                         clock tics.

     Preconditions  - RealTime is the quantity of Units
                      Units    is Minute, Hour, Day, Week, Month, or Year.

     Postconditions - RETURN value is the number of clock tics.
 *)
PROCEDURE RealTimeToDuration( RealTime : REAL; Units : ADurationUnit ) : ADuration;
VAR Tics : REAL;
BEGIN
    Tics := (RealTimeToWorkHours( RealTime, Units ) * FSMUPH) + Point5;
    IF (Tics >= FMAXCARDINAL) THEN
        RETURN MAXCARDINAL;
    ELSIF (Tics < Zero) THEN
        RETURN 0;
    ELSE
        RETURN TRUNC(Tics);
    END;
END RealTimeToDuration;








 (* DurationToRealTime - Convert clock tics and Units to a real number
                         for display.  Like DownScale.

     Preconditions  - Duration is the quantity of clock tics.
                      Units    is Minute, Hour, Day, Week, Month, or Year.

     Postconditions - RETURN value is the displayable real number.
 *)
PROCEDURE DurationToRealTime( Duration : ADuration; Units : ADurationUnit ) : REAL;
BEGIN
    RETURN WorkHoursToRealTime( FLOAT(Duration) / FSMUPH, Units );
END DurationToRealTime;






END WorkHours.
