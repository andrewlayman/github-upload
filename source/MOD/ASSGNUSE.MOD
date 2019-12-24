IMPLEMENTATION MODULE AssgnUse;

(*  =========================================================================
    Last Edit : October 25, 1990 5:58PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Compute the usage of an assignment over a time period.


    MODIFICATION HISTORY:

        14-Sep-90 RSC First version.
        25-Sep-90 RSC Handle zero duration tasks.
         4-Oct-90 RSC Added AssignmentTics() and made its return value
                      a LONGINT of how many clock ticks elapsed.
        25-Oct-90 RSC Hmmm.  Removed the scaling of Assignment Tics so
                      it reports a TOTAL, not a RATE.
        14-Feb-91 AJL Rename EndOf ActualDate to EndOfSpentDate.

    =========================================================================
*)


FROM Allocs         IMPORT
    (* TYPE *)          ATask;

FROM Assignments    IMPORT
    (* TYPE *)          AnAssignmentRecord;

FROM LongConvert    IMPORT
    (* PROC *)          LongToReal;

FROM Timei          IMPORT
    (* TYPE *)          ADate, ADuration,
    (* VAR  *)          MinDate, MaxDate;

FROM TimeMath       IMPORT
    (* PROC *)          DurationInPeriod, ConstrainPeriod;

FROM Timeu          IMPORT
    (* VAR  *)          FSMUPH;

FROM VaryAssgnment  IMPORT
    (* TYPE *)          AVaryingAssgnList, AVaryingAssgnListIndex,
    (* PROC *)          GetVaryingAssgnListEntry,
                        LocateDateInVaryingAssgnList;


CONST
    Zero    = 0.0;



(*  =====================================================================
    
    PROCEDURE - Assignment Tics

            How many clock tics has this assignment worked, or
            How many clock tics WILL this assignment work, or both,
            during the period specified?


        Preconditions :

            FlexStor is running
            Recalc has run, filling in the assignment record's
                VaryingAssignment list.
                
                If this condition is not met, the results will be
                    just a guess, based on the task record.

        Postconditions :

            No changes are made to the records passed.

        Parameters :

            Input:

                Assignment      The assignment record to report on.
                                It must have its resource pointer filled in,
                                and the VaryingAssignment list must be
                                VALID or NIL.

                Task            The task record to use as a fallback,
                                in case the VaryingAssignment list is NIL.

                Completion      Completed, ToGo, or both hours?

                StartOfPeriod   The beginning of the period to report on.

                EndOfPeriod     The end of the period to report on.


            Output:

                RETURN is the number of clock tics in the period, taking
                          varying assigned rates into account.  See the
                          note in Preconditions.

    =====================================================================
*)
PROCEDURE AssignmentTics( VAR Assignment     : AnAssignmentRecord;
                          VAR Task           : ATask;
                              Completion     : ACompletion;
                              StartOfPeriod,
                              EndOfPeriod    : ADate

                         ) : REAL;
VAR
    Amount, Rate    : REAL;
    N               : AVaryingAssgnListIndex;
    EntryStartDate,
    EntryEndDate    : ADate;
    Duration,
    TotalDuration   : ADuration;

BEGIN
    WITH Assignment DO

        Amount        := Zero;

        IF (VaryingAssignment <> AVaryingAssgnList(NIL)) THEN

                (* If they only want completed hours,
                   constrain ourselves to just the period containing
                   the completed info.

                   If they only want to go hours,
                   constrain to to go info.

                   If they want it all, don't constrain.
                *)
            IF (Completion = CompletedHours) THEN
                IF (ConstrainPeriod( StartOfPeriod,  EndOfPeriod,
                                     MinDate,        EndOfSpentDate,
                                     EntryStartDate, EntryEndDate)) THEN

                    StartOfPeriod := EntryStartDate;
                    EndOfPeriod   := EntryEndDate;
                ELSE
                    RETURN Amount;
                END;
            ELSIF (Completion = YetToGoHours) THEN
                IF (ConstrainPeriod( StartOfPeriod,   EndOfPeriod,
                                     EndOfSpentDate, MaxDate,
                                     EntryStartDate,  EntryEndDate)) THEN

                    StartOfPeriod := EntryStartDate;
                    EndOfPeriod   := EntryEndDate;
                ELSE
                    RETURN Amount;
                END;
            END;

            LocateDateInVaryingAssgnList( VaryingAssignment, StartOfPeriod, N );
(*            TotalDuration := 0;*)
            Duration      := 1; (* Seed the folowing loop *)

            WHILE (Duration <> 0) AND
                  (GetVaryingAssgnListEntry( VaryingAssignment,
                                             N,
                                             EntryStartDate, EntryEndDate,
                                             Rate )) DO

                Duration := DurationInPeriod( StartOfPeriod,
                                              EndOfPeriod,
                                              EntryStartDate,
                                              EntryEndDate );

                    (* Summ up Tics * Rate
                    *)
                IF (StartOfPeriod = EndOfPeriod) THEN
                    Amount        := Amount + Rate;
                ELSE
                    Amount        := Amount + Rate * FLOAT(Duration);
(*                    TotalDuration := TotalDuration + Duration;*)
                END;
                INC(N);
            END;

                (* Find Average RatePerTic and then convert Tics to Hours.
                *)
(*            IF (TotalDuration <> 0) THEN*)
(*                Amount := Amount DIV VAL(LONGINT,TotalDuration);*)
(*            END;*)
        END;
    END;

    RETURN Amount;

END AssignmentTics;








(*  =====================================================================
    
    PROCEDURE - Assignment Hours

            How many hours has this assignment worked, or
            How many hours WILL this assignment work, or both,
            during the period specified?


        Preconditions :

            FlexStor is running
            Recalc has run, filling in the assignment record's
                VaryingAssignment list.
                
                If this condition is not met, the results will be
                    just a guess, based on the task record.

        Postconditions :

            No changes are made to the records passed.

        Parameters :

            Input:

                Assignment      The assignment record to report on.
                                It must have its resource pointer filled in,
                                and the VaryingAssignment list must be
                                VALID or NIL.

                Task            The task record to use as a fallback,
                                in case the VaryingAssignment list is NIL.

                Completion      Completed, ToGo, or both hours?

                StartOfPeriod   The beginning of the period to report on.

                EndOfPeriod     The end of the period to report on.


            Output:

                RETURN is the number of WorkHours in the period, taking
                          varying assigned rates into account.  See the
                          note in Preconditions.

    =====================================================================
*)
PROCEDURE AssignmentHours( VAR Assignment     : AnAssignmentRecord;
                           VAR Task           : ATask;
                               Completion     : ACompletion;
                               StartOfPeriod,
                               EndOfPeriod    : ADate

                                ) : REAL;
VAR
    Amount  : REAL;
BEGIN
    Amount := AssignmentTics(Assignment, Task, Completion, StartOfPeriod, EndOfPeriod );

    RETURN (Amount / FSMUPH);

END AssignmentHours;




END AssgnUse.



