IMPLEMENTATION MODULE TimeMath;

(*  =========================================================================
    Last Edit : September 14, 1990 3:37PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        This module provides some important math functions for time
        periods and durations.


    MODIFICATION HISTORY:

    RSC 12-Jun-90 First version.

    =========================================================================
*)



FROM BigTimeU   IMPORT
    (* TYPE *)      ABigTime;

FROM Timei      IMPORT
    (* TYPE *)      ADate, ADuration;

FROM TimeXlate  IMPORT
    (* PROC *)      BigTimeToCalendarTime;





(* Constrain Period

    Given a task start and end date and a period start and end date,
    Determine the smaller period of the two periods.

    Preconditions

        none

    Postconditions

        Smallest period contained in each of the two passed periods.
        There may be no period, in which case both the returned dates
        are undefined.

    Input

        Period1Start        First period start and end
        Period1End
        Period2Start        Second period start and end
        Period2End

    Output

        ConstrainedStart    Period during which both input periods
        ConstrainedEnd          are active.

        RETURN              TRUE  There is a non-zero length period.
                            FALSE There is no common period.
*)
PROCEDURE ConstrainPeriod(     Period1Start,
                               Period1End,
                               Period2Start,
                               Period2End       : ADate;
                           VAR ConstrainedStart,
                               ConstrainedEnd   : ADate ) : BOOLEAN;
BEGIN

    IF (Period1Start > Period2Start) THEN
        ConstrainedStart := Period1Start;
    ELSE
        ConstrainedStart := Period2Start;
    END;

    IF (Period1End < Period2End) THEN
        ConstrainedEnd := Period1End;
    ELSE
        ConstrainedEnd := Period2End;
    END;

    RETURN (ConstrainedStart < ConstrainedEnd);  (* Not <= *)

END ConstrainPeriod;







(* Duration In Period

    Given a task start and end date and a period start and end date,
    Return the duration that the task operates during the period.

    Preconditions

        none

    Postconditions

        Duration returned, or 0 if the task does not operate during the
        period, or the task is a milestone.

    Input
        TaskStart       Start Date of task
        TaskEnd         End Date of task
        PeriodStart     calendar slice to start looking at.
        PeriodEnd       Calendar slice to stop looking at.

    Output
        Duration, as described above.
*)
PROCEDURE DurationInPeriod( TaskStart,
                            TaskEnd,
                            PeriodStart,
                            PeriodEnd       : ADate ) : ADuration;
VAR
    Duration    : ADuration;
    ResultStart,
    ResultEnd   : ADate;
BEGIN

    Duration := 0;
    IF (ConstrainPeriod(TaskStart, TaskEnd, PeriodStart, PeriodEnd,
                        ResultStart, ResultEnd )) THEN
        Duration := (ResultEnd - ResultStart);
    ELSE
        Duration := 0;
    END;

    RETURN Duration;

END DurationInPeriod;







(* Duration In Big Period

    Given a task start and end date and a period start and end date,
    all phrased as BigTimes, Return the (CARDINAL) duration that the
    task operates during the period.

    Preconditions

        none

    Postconditions

        Duration returned, or 0 if the task does not operate during the
        period, or the task is a milestone.

        The BigTimes are scaled to fit in the nearest possible calendar
        dates.  The duration must be in the range of a legal duration,
        so may be trimmed to MAXCARDINAL if need be.

    Input
        TaskStart       Start Date of task, as a BigTime.
        TaskEnd         End Date of task, as a BigTime.
        PeriodStart     calendar slice to start looking at, as a BigTime.
        PeriodEnd       Calendar slice to stop looking at, as a BigTime.

    Output
        Duration, as described above.
*)
PROCEDURE DurationInBigPeriod(  TaskStart,
                                TaskEnd,
                                PeriodStart,
                                PeriodEnd       : ABigTime ) : ADuration;
VAR
    STaskStart,
    STaskEnd,
    SPeriodStart,
    SPeriodEnd      : ADate;
BEGIN
    STaskStart    := BigTimeToCalendarTime( TaskStart   );
    STaskEnd      := BigTimeToCalendarTime( TaskEnd     );
    SPeriodStart  := BigTimeToCalendarTime( PeriodStart );
    SPeriodEnd    := BigTimeToCalendarTime( PeriodEnd   );

    RETURN DurationInPeriod( STaskStart, STaskEnd, SPeriodStart, SPeriodEnd );

END DurationInBigPeriod;




END TimeMath.


