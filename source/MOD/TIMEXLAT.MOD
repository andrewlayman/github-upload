IMPLEMENTATION MODULE TimeXlate;

(*  =========================================================================
    Last Edit : June 19, 1990 1:48PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Translate time formats from Calendar Time to and from BigTimes.

    MODIFICATION HISTORY:

        11-Jun-90  RSC  First version.
        19-Jun-90  RSC  Removed old big time conversion, added parm to
                        CalendarTimeToBigTime.  Added a new procedure,
                        "TimesToBigTimes"



    =========================================================================
*)



FROM BigTimeU   IMPORT
    (* TYPE *)      ABigTime,
    (* PROC *)      TimeInfoToBigTime, BigTimeToTimeInfo, TimeToBigTime;

FROM TimeFormat IMPORT
    (* VAR *)       EndDateStyle,
    (* PROC *)      TimeAsEndDateStyle;

FROM Timei      IMPORT
    (* TYPE *)      ADate, ATimeInfo,
    (* PROC *)      TtoTimeU, TimeUtoT, KDate;








(*
    Calendar Time To Big Time

    Given a 16 bit time, generate a BigTime.

    Preconditions

        none

    Postconditions

        An accurate representation of the Small Time is produced.

    Input
        SmallTime       The ADate version of the date.
        ItsAStartDate   Is this to be formated as a start or end date?

    Output
        BigTime         The ABigTime version of the date.
*)
PROCEDURE CalendarTimeToBigTime(     SmallTime      : ADate;
                                     ItsAStartDate  : BOOLEAN;
                                 VAR BigTime        : ABigTime );
VAR
    TimeInfo : ATimeInfo;
BEGIN
    IF (ItsAStartDate) THEN
        TimeUtoT( SmallTime, TimeInfo );
    ELSE
        TimeAsEndDateStyle( SmallTime, EndDateStyle, TimeInfo );
    END;

    TimeInfoToBigTime( TimeInfo, BigTime );

END CalendarTimeToBigTime;









(*
    Big Time To Calendar Time

    Given a Big Time, create an (approximate) Small Time.

    Preconditions

        The BigTime must be valid

    Postconditions

        The nearest approximation of the time will be returned.

    Input:

        BigTime         A valid big time

    Output:
        RETURN          the small date format of the number.
                        This could be a near approximation.
*)
PROCEDURE BigTimeToCalendarTime( BigTime        : ABigTime ) : ADate;
VAR
    TimeInfo   : ATimeInfo;
    SmallTime  : ADate;
    ok         : BOOLEAN;
BEGIN
    BigTimeToTimeInfo( BigTime, TimeInfo );

    ok := TtoTimeU( TimeInfo, SmallTime );

    RETURN SmallTime;

END BigTimeToCalendarTime;









(* Times To Big Times

        Given a start and end date period, create the appropriate
        big times.  This arbitrates for formatting end dates as
        end dates, UNLESS the period is 0 (a milestone).

    Preconditions

        SmallEndDate >= SmallStartDate.

    Postconditions

        An accurate representation of the Small Times are produced.
        If the duration of the period is 0, the dates are formatted the
        same, otherwise, the end date is formated in the standard
        end date style (say, 5PM rather than 8AM the next morning).

    Input

        SmallStartDate      The start date in ADate format.
        SmallEndDate        The end   date in ADate format.

    Output

        BigStartDate        The start date in ABigTime format.
        BigEndDate          The end   date in ABigTime format.
*)
PROCEDURE TimesToBigTimes(     SmallStartDate,
                               SmallEndDate     : ADate;
                           VAR BigStartDate,
                               BigEndDate       : ABigTime );
BEGIN

    CalendarTimeToBigTime( SmallStartDate,
                           TRUE,
                           BigStartDate );

    CalendarTimeToBigTime( SmallEndDate,
                           (SmallStartDate = SmallEndDate),
                           BigEndDate );

END TimesToBigTimes;











END TimeXlate.

