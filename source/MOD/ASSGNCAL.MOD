IMPLEMENTATION MODULE AssgnCalc;
    
    (* MODIFICATION HISTORY:

     3-Jun-91 TGS   Created.
     5-Aug-91 EGK   Found a bug in ComputeEffortsAndCostsInPeriod, in which
                    the WHILE loop would not terminate if the requested
                    period extended beyond the end of the calendar.  In Eve
                    bug #4286, the small date corresponding to the end of
                    the calendar was less than 65535, but the requested
                    time period was MinDate to MaxDate, or 0 to 65535. and
                    no date could ever be reached that would equal MaxDate
                    and end the loop.
    13-Sep-91 TGS   ComputeLinearCosts wasn't returning good VAR values
                    for the "milestone" cases.
    30-Jan-92 TGS   VaryingAssgnLists now have REALs in them. Changed the
                    TYPE of the corresponding local variables to match.
                    For now, trust that the REAL gotten is in the appropriate
                    range, 0.0<=Rate<=65535.0.
     2-Apr-92 TGS   Add AssignmentDollars(). This returns "accurate" Spent,
                    ToGo, or Total dollar amounts if possible, using the 
                    Compute.. procedures in this module, or gets a plausible
                    number from AssignmentCost() if not.
    *)

FROM AsOf               IMPORT
    (* VAR *)               AsOfDate;

FROM Assignments        IMPORT
    (* TYPE *)              AnAssignmentRecord;

FROM BigTimeU           IMPORT
    (* TYPE *)              ABigTime,
    (* VAR *)               MAXBIGTIME;

FROM CalShift           IMPORT
    (* VAR   *)             TimeSheet;

FROM Duration           IMPORT
    (* PROC *)              FindDuration;

FROM RateLists          IMPORT
    (* PROC *)              LocateDateInRateList,
                            GetRateListEntry,
    (* TYPE *)              ARateList,
                            ARateListIndex;

FROM RsrcCalc           IMPORT
    (* TYPE *)              AnAssignmentCostType, AnAssignmentCostTypeSet,
    (* PROC *)              AssignmentCost;

FROM RsrcMod            IMPORT
    (* TYPE *)              ACostStyle, AResourceType, AResourcePointer,
    (* PROC *)              AverageResourceRate;

FROM SYSTEM             IMPORT
    (* THINGS *)            TSIZE;

FROM Timei              IMPORT 
    (* CONST *)             NoDuration,
    (* PROC *)              DurationToReal,
    (* TYPE *)              ADate, ADuration;

FROM Timeu              IMPORT
    (* VAR *)               FSMUPH;

FROM TimeXlate          IMPORT
    (* PROC *)              BigTimeToCalendarTime,
                            CalendarTimeToBigTime;

FROM VaryAssgnment      IMPORT 
    (* PROC *)              LocateDateInVaryingAssgnList,
                            GetVaryingAssgnListEntry,
    (* TYPE *)              AVaryingAssgnList,
                            AVaryingAssgnListIndex;

CONST
    Zero        = 0.0;
    One         = 1.0;
    MAXCARDINAL = 65535;

TYPE
    AResourceKind           = (Rsrc, FixedCost, UnitCost, VarCost);

    PROCEDURE EarlierOf(A,B:ADate):ADate;
    BEGIN
        IF (A <= B) THEN RETURN A ELSE RETURN B END;
    END EarlierOf;

    PROCEDURE LaterOf(A,B:ADate):ADate;
    BEGIN
        IF (A >= B) THEN RETURN A ELSE RETURN B END;
    END LaterOf;

    PROCEDURE Ratio ( a, b : ADuration ) : REAL;

    BEGIN           (* Ratio *)

        IF (b = NoDuration) THEN
            RETURN One;
        ELSE
            RETURN DurationToReal(a) / DurationToReal(b);
        END;

    END Ratio;

    PROCEDURE ResourceKind( Resource : AResourcePointer ) : AResourceKind;

    VAR
        r               : AResourceKind;

    BEGIN               (* ResourceKind *)

        IF (Resource^.Type = Employable) THEN
            r := Rsrc;
        ELSE
            CASE Resource^.CostStyle OF
                CAmount :   
                    r := FixedCost;
            |   CAmountRate :
                    r := UnitCost;
            |   CAmountRateTime :
                    r := VarCost;
            END;
        END;

        RETURN r;

    END ResourceKind;

        (*   3-Jun-91 TGS

            ComputeEffortsAndCostsInPeriod --

            Purpose:
                To calculate the amount of effort and its associated cost
                for a particular period.

                Within the period, there are one or more "intervals", each
                with a different cost rate and/or assignment rate than those
                adjacent to it. We compute the efforts and costs in each such
                interval and sum them up over the whole period.

            Preconditions:
                A VaryingAssignment profile exists.

            Postconditions:
                Return the number of workhours and the costs, zero if there
                was no VaryingAssignment profile or if there wasn't anything
                happening.

            Inputs:
                Three things from the assignment record:
                    Handle for VaryingAssignmentList
                    Handle for assigneed Resource's VaryingRateList
                    EndOfSpending date

                Period of interest
                    (a half-open period beginning at PeriodStart and ending
                     one tic before PeriodEnd)
                WeWantSpent (as opposed to ToGo)

            Outputs:
                PeriodWorkHours
                PeriodCosts

        *)

PROCEDURE ComputeEffortsAndCostsInPeriod
            (   AsgnRatesList   : AVaryingAssgnList;
                CostRatesList   : ARateList;
                EndOfSpentDate,
                PeriodStart,
                PeriodEnd       : ADate;
                WeWantSpent     : BOOLEAN;
            VAR PeriodEffort,
                PeriodCost      : REAL
            ) : BOOLEAN;

VAR
    RateStart,
    AsgnRateEnd,
    CostRateEnd,
    IntervalEnd         : ADate;
    CalendarEnd         : ADate;
    BPeriodStart,
    BPeriodEnd,
    BRateStart,
    BCostRateEnd        : ABigTime;
    CostRateIndex       : ARateListIndex;
    AsgnRateIndex       : AVaryingAssgnListIndex;
    CostRate,
    IntervalCostRate,
    IntervalEffort      : REAL;
    AsgnRate,
    IntervalAsgnRate    : REAL;
    ok                  : BOOLEAN;

    PROCEDURE CheckAsgnRate();
        (* If AssignmentRate is zero, skip to next interval *)
    BEGIN
        (* not yet implemented *)
    END CheckAsgnRate;

    PROCEDURE GetCostRateStuff();
    BEGIN
        (* only bother with this stuff if there is a CostRatesList *)
        IF (CostRatesList <> ARateList(NIL)) THEN
            INC(CostRateIndex);
            ok := GetRateListEntry
                    ( CostRatesList, CostRateIndex,
                        BRateStart, BCostRateEnd, CostRate);
            CostRateEnd := BigTimeToCalendarTime(BCostRateEnd);
        END;
    END GetCostRateStuff;

    PROCEDURE GetIntervalEndAndNextRates
                (EndPeriod, EndCost, EndAsgn : ADate) : ADate;

    BEGIN
        IF (EndPeriod <= EndCost) THEN
            IF (EndPeriod <= EndAsgn) THEN
                (* this interval closes out the period *)
                RETURN EndPeriod;

            ELSE
                (* the assignment rate change defines IntervalEnd *)
                INC(AsgnRateIndex);
                ok := GetVaryingAssgnListEntry
                        ( AsgnRatesList, AsgnRateIndex,
                          RateStart, AsgnRateEnd, AsgnRate);
                RETURN EndAsgn;

            END;

        ELSE (* IntervalEnd < PeriodEnd *)
            IF (EndCost < EndAsgn) THEN
                (* the cost rate change defines IntervalEnd *)
                GetCostRateStuff();
                RETURN EndCost;

            ELSIF (EndCost > EndAsgn) THEN
                (* the assignment rate change defines IntervalEnd *)
                INC(AsgnRateIndex);
                ok := GetVaryingAssgnListEntry
                        ( AsgnRatesList, AsgnRateIndex,
                          RateStart, AsgnRateEnd, AsgnRate);
                RETURN EndAsgn;

            ELSE
                (* EndCost = EndAsgn = IntervalEnd *)
                GetCostRateStuff();
                INC(AsgnRateIndex);
                ok := GetVaryingAssgnListEntry
                        ( AsgnRatesList, AsgnRateIndex,
                          RateStart, AsgnRateEnd, AsgnRate);
                RETURN EndAsgn;
            END;
        END;
    END GetIntervalEndAndNextRates;

BEGIN (* ComputeEffortsAndCostsInPeriod *)
    PeriodEffort    := Zero;
    PeriodCost      := Zero;
    
        (* If this is a zero-duration period, return: effort requires some duration *)
    IF (PeriodStart >= PeriodEnd) THEN
        RETURN FALSE;
    END;

    IF WeWantSpent THEN
            (* If we want Spent stuff, end with EndOfSpentDate *)
        IF (PeriodEnd > EndOfSpentDate) THEN
            PeriodEnd := EndOfSpentDate;
        END;
    ELSE
            (* If we want ToGo stuff, start with EndOfSpentDate *)
        IF (PeriodStart < EndOfSpentDate) THEN
            PeriodStart := EndOfSpentDate;
        END;
    END;

        (* Get AsgnRateIndex and the assignment rate associated with it *)
    LocateDateInVaryingAssgnList( AsgnRatesList, PeriodStart, AsgnRateIndex);
    IF (AsgnRateIndex = 0) THEN
        (* check to see if PeriodEnd < date of first AsgnList entry *)
        ok := GetVaryingAssgnListEntry( AsgnRatesList, 1,
                                        RateStart, AsgnRateEnd, AsgnRate);
        IF (RateStart < PeriodEnd) THEN
            AsgnRateIndex := 1;
            PeriodStart   := RateStart;
        ELSE
            RETURN FALSE;
        END;
    ELSE
        ok := GetVaryingAssgnListEntry( AsgnRatesList, AsgnRateIndex,
                                        RateStart, AsgnRateEnd, AsgnRate);

            (* does period start after end of the assignment? *)
        IF (AsgnRate = Zero) AND (AsgnRateEnd = MAXCARDINAL) THEN
            RETURN FALSE;
        END;

    END;

        (* Get CostRateIndex and the cost rate associated with it *)
    IF (CostRatesList = ARateList(NIL)) THEN
        CostRate        := One;
        CostRateEnd     := MAXCARDINAL;
    ELSE
        CalendarTimeToBigTime(PeriodStart, TRUE, BPeriodStart);
        LocateDateInRateList( CostRatesList, BPeriodStart, CostRateIndex);
        ok := GetRateListEntry( CostRatesList, CostRateIndex,
                                BRateStart, BCostRateEnd, CostRate);
        CostRateEnd := BigTimeToCalendarTime(BCostRateEnd);
    END;

        (* Make sure that the period end date is not greater than the
           maximum calendar date.  This guarantees that the WHILE loop
           will terminate.   -- 8/5/91 EGK, see bug #4286
        *)

    CalendarEnd := BigTimeToCalendarTime (MAXBIGTIME);
    IF (PeriodEnd > CalendarEnd) THEN
        PeriodEnd := CalendarEnd;
    END;

        (* Loop until each "interval" in the period is summed up *)
    WHILE (PeriodStart < PeriodEnd) DO
            (* We look up the rates for the following interval (if any)
                when we figure out when the current interval ends, so first
                we save the current rates so we have them to calculate with.
            *)
        IntervalCostRate := CostRate;
        IntervalAsgnRate := AsgnRate;

            (* Figure out when this interval ends and look up rates for next one *)
        IntervalEnd     := GetIntervalEndAndNextRates
                                (PeriodEnd, CostRateEnd, AsgnRateEnd);

            (* Add this interval's efforts and costs to the period's *)
            (* First, compute the effort in Hours *)
        IntervalEffort  := IntervalAsgnRate *
                           DurationToReal( FindDuration( PeriodStart,
                                                         IntervalEnd,
                                                         TimeSheet))
                           /(100.0 * FSMUPH);
        PeriodEffort    := PeriodEffort + IntervalEffort;
        PeriodCost      := PeriodCost +
                           IntervalEffort * IntervalCostRate;

            (* Move to next interval (if any) *)
        PeriodStart     := IntervalEnd;
    END;

    RETURN TRUE;

END ComputeEffortsAndCostsInPeriod;


    (*   3-Jun-91 TGS

        ComputePortionOfSpendingInPeriod --

        Purpose:
            Given a Period of interest, an interval of spending activity,
            an amount of "something" (usually a quantity) return the 
            portion of this quantity which occurs in this period,
            assuming rate of spending is constant over the spending 
            interval.
            
            Return FALSE if there was no spending in the period. Else,
            return the quantity of spending quantity (e.g. "2 spent"),
            as well as the interval within this period in which spending
            occurred (so cost rates can be computed and applied to this
            quantity, if it wasn't "dollars" already).

        Preconditions:
            Caller has figured out the correct spending interval, which
            could have End < Start (meaning lump all costs at End).

        PostConditions:
            Return TRUE if there was spending in the period, else FALSE.
            If there was no spending don't change the things passed in.
            Else, the amount passed in is scaled back to proportion 
            spent in period. Similarly, the SpendingStart and SpendingEnd
            dates change to span the interval within the period during
            which the spending occured.

        Inputs:
            Spending Information:
                SpentAmount, SpendingStart, SpendingEnd
            Period information:
                PeriodStart, PeriodEnd
            ThisIsSpent - needed to handle special case

        Outputs:
            Whether spending occurred or not
            Amount
            IntervalStart, IntervalEnd
    *)

PROCEDURE ComputeLinearCostsInPeriod
            (     Amount        : REAL;
                  SpendingStart,
                  SpendingEnd,
                  PeriodStart,
                  PeriodEnd     : ADate;
                  ThisIsSpent   : BOOLEAN;
              VAR ScaledAmount  : REAL;
              VAR IntervalStart,
                  IntervalEnd   : ADate
            ) : BOOLEAN;

BEGIN

        (* is this one of them there zero length periods? *)
    IF (PeriodStart < PeriodEnd) THEN

            (* is this a "normal", non-milestone spending period? *)
        IF (SpendingStart < SpendingEnd) THEN 
            IF (SpendingStart >= PeriodEnd)     OR 
               (SpendingEnd   <  PeriodStart) THEN
                (* nothing's happening here, leave without doing anything *)
                RETURN FALSE;

            ELSE
                (* there's some activity in this period *)
                IntervalStart := LaterOf  (SpendingStart, PeriodStart);
                IntervalEnd   := EarlierOf(SpendingEnd,   PeriodEnd  );
                ScaledAmount := Amount *
                                Ratio
                                  ( FindDuration(   IntervalStart,
                                                    IntervalEnd,
                                                    TimeSheet),
                                    FindDuration(   SpendingStart,
                                                    SpendingEnd,
                                                    TimeSheet)
                                  );
            END;

            (* "Milestone" spending period.
                Could be a bona-fide milestone, or a situation where
                we are looking at spending on a future task, which looks
                the same way (spending is lumped just before AsOf).
            *)
        ELSE
            (* is spending is lumped on tic before AsOfDate? *)
            IF (SpendingEnd = AsOfDate) AND
               (ThisIsSpent) THEN
                (* is tic before AsOf in the period? *)
                IF (SpendingEnd <= PeriodStart) OR 
                   (SpendingEnd >  PeriodEnd  ) THEN
                    RETURN FALSE;
                ELSE
                    ScaledAmount  := Amount;
                    IntervalEnd   := AsOfDate - 1;
                    IntervalStart := IntervalEnd;
                END;

            ELSE
                (* is milestone outside the period? *)
                IF (SpendingEnd <  PeriodStart) OR 
                   (SpendingEnd >= PeriodEnd  ) THEN
                    RETURN FALSE;
                ELSE
                    ScaledAmount  := Amount;
                    IntervalEnd   := AsOfDate - 1;
                    IntervalStart := IntervalEnd;
                END;

            END;
        END;
    ELSE
        (* A zero-length period.
            Only way there's spending in it is if spending period is a
            milestone and the milestone date = PeriodStart 
        *)
        IF (SpendingStart <> SpendingEnd) OR
           (SpendingEnd   <> PeriodStart) THEN 
            RETURN FALSE;
        ELSE
            ScaledAmount  := Amount;
            IntervalEnd   := PeriodStart;
            IntervalStart := IntervalEnd;
        END;

    END;

        (* If we get here, spending occurred in this period, and we've
            changed any VAR parameters that we need to. Hence: 
        *)
    RETURN TRUE;

END ComputeLinearCostsInPeriod;




    (* AssignmentDollars

        Take an assignment, a period, and hints as to whether Spent or
        ToGo or baseline amounts are desired, and return the best figure
        possible, or at least some "plausible" estimate.  If it is a Resource
        assignment, we'll try to call ComputeEffortAndCostsInPeriod if it has
        a VaryingAssignment attached, else we call AssignmentCost().  For 
        non-Resources, we call ComputeLinearCostsInPeriod.

        Interface to this proc is the same as RsrcCalc.AssignmentCost().
        That's to make it easy to replace calls to that with calls to this.
    *)


PROCEDURE AssignmentDollars( VAR Assignment         : AnAssignmentRecord;
                                 StartOfPeriod,            
                                 EndOfPeriod        : ADate;
                                 AssignmentCostTypes: AnAssignmentCostTypeSet
                           ) : REAL;

VAR
    Dummy, RSpent, RToGo, RExtra : REAL;
    TempDate, IntervalStart, IntervalEnd   : ADate;

BEGIN

    RSpent      := Zero;
    RToGo       := Zero;
    RExtra      := Zero;

    WITH Assignment DO

        IF (StartOfPeriod > EndOfSpentDate) THEN
            TempDate := StartOfPeriod;
        ELSE
            TempDate := EndOfSpentDate;
        END;

            (* Prorate the expenses. *)
        IF (ResourceKind(Resource) = Rsrc) THEN

            IF (VaryingAssignment <> AVaryingAssgnList(NIL)) THEN

                IF (TreatAsBaseline IN AssignmentCostTypes) THEN

                    IF ComputeEffortsAndCostsInPeriod
                            ( VaryingAssignment,
                            Resource^.BaseLineRates,
                            0,
                            StartOfPeriod, EndOfPeriod,
                            FALSE, (* "ToGo" *)
                            Dummy, (* don't care about effort here *)
                            RSpent
                            ) THEN
                    END;

                ELSE

                    IF (IncludeSpent IN AssignmentCostTypes) AND
                        ComputeEffortsAndCostsInPeriod
                                ( VaryingAssignment,
                                Resource^.ActualRates,
                                EndOfSpentDate,
                                0, MAXCARDINAL,
                                TRUE, (* "Spent" *)
                                Dummy,
                                RSpent
                                ) THEN
                    END;

                    IF (IncludeToGo IN AssignmentCostTypes) AND
                        ComputeEffortsAndCostsInPeriod
                                ( VaryingAssignment,
                                Resource^.ActualRates,
                                EndOfSpentDate,
                                0, MAXCARDINAL,
                                FALSE, (* "ToGo" *)
                                Dummy,
                                RToGo
                                ) THEN
                    END;

                    IF (IncludeExtras IN AssignmentCostTypes) THEN
                        RExtra := ExtraCosts;
                    END;
            
                END;

            ELSE (* do our best.. *)

                RSpent := AssignmentCost( Assignment,
                                          StartOfPeriod, EndOfPeriod,
                                          AssignmentCostTypes);
            END;

        ELSE (* a "cost" resource *)

            IF (TreatAsBaseline IN AssignmentCostTypes) THEN

                IF ((ResourceKind(Resource) <> VarCost) OR
                    (StartOfPeriod <> EndOfPeriod)) AND
                    ComputeLinearCostsInPeriod
                        ( YetToGoQuantity,
                        StartOfPeriod, EndOfPeriod,
                        0, MAXCARDINAL,
                        FALSE, (* all baseline is ToGo *)
                        Dummy, (* we don't need to know this *)
                        IntervalStart, IntervalEnd
                        ) THEN

                    RToGo := YetToGoQuantity *
                             AverageResourceRate( Resource,
                                                  IntervalStart,
                                                  IntervalEnd,
                                                  TRUE
                                                );
                END;
        
            ELSE   

                IF (ResourceKind(Resource) = VarCost) AND
                   (IncludeExtras IN AssignmentCostTypes) THEN
                    RExtra := ExtraCosts;
                END;

                IF (ResourceKind(Resource) <> VarCost) OR
                   (StartOfPeriod <> EndOfPeriod) THEN
                    IF (IncludeSpent IN AssignmentCostTypes) AND 
                        ComputeLinearCostsInPeriod
                          ( ActualQuantity,
                            StartOfPeriod, EndOfSpentDate,
                            0, MAXCARDINAL,
                            TRUE, (* Spent *)
                            Dummy,
                            IntervalStart, IntervalEnd
                          ) THEN

                        RSpent := ActualQuantity *
                                  AverageResourceRate( Resource,
                                                       IntervalStart,
                                                       IntervalEnd,
                                                       FALSE
                                                     );
                    END;

                    IF (IncludeToGo IN AssignmentCostTypes) AND
                        ComputeLinearCostsInPeriod
                          ( YetToGoQuantity,
                            TempDate, EndOfPeriod,
                            0, MAXCARDINAL, (* total over "all time" *)
                            FALSE, (* ToGo *)
                            Dummy,
                            IntervalStart, IntervalEnd
                          ) THEN

                        RToGo := YetToGoQuantity *
                                 AverageResourceRate( Resource,
                                                      IntervalStart,
                                                      IntervalEnd,
                                                      FALSE
                                                    );
                    END;
                END;
            END;
        END;
    END;

    RETURN (RSpent + RToGo + RExtra);

END AssignmentDollars;

BEGIN
END AssgnCalc.

