IMPLEMENTATION MODULE ResPriority;

(*V2=PRINT WITH debugging printouts *)

     (* ------------------------------------------------------------

        ResPriority -- Priorities between tasks.

        MODIFICATION HISTORY:

        9/9/91  JES - Added PRINT version.
        9/10/91 JES - Removed consideration of "Date" in determining
                        priority for ALAP tasks. (It was resulting
                        in an indeterminate priority order; i.e.,
                        sometimes A < B and and sometimes A > B, resulting
                        in an infinite cycle of bumping.)

      -------------------------------------------------------------- *)


FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr, AnAssignmentSummary,
                            AStartStatus, AFixType, ADurationMethod, ATaskFlag,
                            ASplittingRule;

FROM ResConstants   IMPORT
    (* CONST *)             DontBump;

FROM Schedule       IMPORT
    (* VAR *)               ZeroIsLowestPriority;

FROM Timei  IMPORT
    (* TYPE *)   ADate, ADuration;

(*<PRINT
FROM LongConvert    IMPORT LongToString;
FROM LStrings       IMPORT SetString, ConcatS, ConcatLS, CtoS;
FROM PrintSupport   IMPORT StartReport, PrintLine, EndReport;
FROM RealFormat     IMPORT FormatAsAmount, DefaultAmountFormat; 
FROM ResTrace       IMPORT PrintOn, NoteString, PrintAString, PrintList,
                           ConcatTaskID, PrintResidueAvailability;
FROM Codes          IMPORT ACode;
FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;



VAR
    s : ARRAY [0..255] OF CHAR;
    DummyCode: ACode;
PRINT>*)



    (*--------------------------------------------------------------- 
        BPreemptA

                     Compares two tasks.  Returns FALSE iff B has same
                     or lower priority than A.

                     Another way of looking at this is TRUE means B
                     can preempt A.
    ----------------------------------------------------------------- *)

PROCEDURE BPreemptA (A,B  : ATaskPtr;
                     Date : ADate): BOOLEAN;
VAR
    DateA, DateB : ADate;
BEGIN
    (*<PRINT
    SetString(NoteString, "          BPreemptA:          task A = ");
    ConcatTaskID(NoteString, A);
    PrintAString(NoteString);
    SetString(NoteString, "                     task B = ");
    ConcatTaskID(NoteString, B);
    PrintAString(NoteString);
    PRINT>*)

        (* The first check looks for tasks that are clearly different in
           their priorities. *)

    CASE MuchHigherPriority(A,B) OF
        -1 : RETURN FALSE;
      |  1 : RETURN TRUE;
         ELSE;
    END;

        (* This is our primary heuristic measure:  which task has
           the earlier late start date?  In other words, who has
           the greatest urgency to start.  This comes from the
           CPM analysis done earlier. Note: what we are
           interested in here is trying to prevent downstream effects
           i.e., preventing tasks from being scheduled too far off their
           late total start dates *)

    DateA := A^.Plan.Dates.LateTotalStart;
    DateB := B^.Plan.Dates.LateTotalStart;

    (*<PRINT
    SetString(NoteString, "A's LateTotalStart = ");
    CtoS(DateA, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    SetString(NoteString, "B's LateTotalStart = ");
    CtoS(DateB, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    SetString(NoteString, "Date = ");
    CtoS(Date, s);
    ConcatLS(NoteString, s);
    PrintAString(NoteString);
    PRINT>*)



        (* If one task needs to start sooner,
           it gets the higher priority. *)

    IF (DateA > DateB) THEN  (*  Who needs to start first? *)
        (*<PRINT
        SetString(NoteString,"       A's LTS > B's LTS so B>A");
        PrintAString(NoteString);
        PRINT>*)
        RETURN TRUE;
    ELSIF (DateA < DateB) THEN
        (*<PRINT
        SetString(NoteString,"       B's LTS > A's LTS so A>B");
        PrintAString(NoteString);
        PRINT>*)
        RETURN FALSE;
    END;

        (* If one of the tasks is ALAP and the other not,
           then the ALAP task loses. *)

    IF (A^.fixation = ALAP) AND (B^.fixation < ALAP) THEN
        (*<PRINT
        SetString(NoteString,"       A is ALAP and B is not, so B>A");
        PrintAString(NoteString);
        PRINT>*)
        RETURN TRUE;
    ELSIF(B^.fixation = ALAP) AND (A^.fixation < ALAP) THEN
        (*<PRINT
        SetString(NoteString,"       B is ALAP and A is not, so A>B");
        PrintAString(NoteString);
        PRINT>*)
        RETURN FALSE;
    END;


    (*  Delay beats Split, because it is harder to schedule.  *)
    IF (A^.SplittingRule = Delay) THEN
        IF (NOT(B^.SplittingRule = Delay )) THEN
            (*<PRINT
            SetString(NoteString,"        A is Delay so A>B");
            ConcatTaskID(NoteString, A);
            PrintAString(NoteString);
            PRINT>*)
            RETURN FALSE;
        END;
    ELSIF (B^.SplittingRule = Delay) THEN
        (*<PRINT
        SetString(NoteString,"        B is Delay so B>A");
        ConcatTaskID(NoteString, B);
        PrintAString(NoteString);
        PRINT>*)
        RETURN TRUE;
    END;


        (* Now we are into tests that are meant to act primarily as 
           tie-breakers. *)

    IF (B^.ToGoSummary.Time > A^.ToGoSummary.Time) THEN  (* longest task wins *)
        (*<PRINT
        SetString(NoteString,"       B has longer ToGo so B>A");
        PrintAString(NoteString);
        PRINT>*)
        RETURN TRUE;
    ELSIF (B^.ToGoSummary.Time < A^.ToGoSummary.Time) THEN
        (*<PRINT
        SetString(NoteString,"       A has longer ToGo so A>B");
        PrintAString(NoteString);
        PRINT>*)
        RETURN FALSE;
    ELSE        (*  Task nearest the top of list? *)
        (*<PRINT
        SetString(NoteString, "      using sequence number as tie-breaker");
        PrintAString(NoteString);
        SetString(NoteString, "B sequence number = ");
        CtoS(B^.SequenceNumber, s);
        ConcatLS(NoteString, s);
        ConcatS(NoteString, ". A sequence number = ");
        CtoS(A^.SequenceNumber, s);
        ConcatLS(NoteString, s);
        ConcatS(NoteString, ".");
        PrintAString(NoteString);
        PRINT>*)

        RETURN  (B^.SequenceNumber < A^.SequenceNumber);
    END;
END BPreemptA;




    (*--------------------------------------------------------------- 
        MuchHigherPriority

                     Compares two tasks.  Returns > 0 if B has a much
                     higher priority than A, < 0 if B is much lower
                     than A, and 0 if they are roughly equal.
    ----------------------------------------------------------------- *)

PROCEDURE MuchHigherPriority( A, B : ATaskPtr ) : INTEGER;
BEGIN
    (*<PRINT
    SetString(NoteString, "          MuchHigherPriority: task A = ");
    ConcatTaskID(NoteString, A);
    PrintAString(NoteString);
    SetString(NoteString, "                     task B = ");
    ConcatTaskID(NoteString, B);
    PrintAString(NoteString);
    PRINT>*)

        (* 1. Frozen, Done or Started tasks take precedence over others. *)
    IF (DontBump IN B^.TempTaskFlags) AND NOT (DontBump IN A^.TempTaskFlags) THEN
        (*<PRINT
        SetString(NoteString,"        DontBump in B.TempTaskFlags so B>A");
        ConcatTaskID(NoteString,B);
        PrintAString(NoteString);
        PRINT>*)
        RETURN 1;
    ELSIF (DontBump IN A^.TempTaskFlags) THEN
        (*<PRINT
        SetString(NoteString,"        DontBump in A.TempTaskFlags so A>B");
        ConcatTaskID(NoteString, A);
        PrintAString(NoteString);
        PRINT>*)
        RETURN -1;
    END;

        (* 2. Does one have greater priority? *)
    IF (A^.priority < B^.priority) THEN
        (*<PRINT
        IF (ZeroIsLowestPriority) THEN
            SetString(NoteString,"        A.Priority < B.Priority ");
        ELSE
            SetString(NoteString,"        B.Priority < A.Priority ");
        END;
        PrintAString(NoteString);
        PRINT>*)
        IF (ZeroIsLowestPriority) THEN
            RETURN 1;
        ELSE
            RETURN -1;
        END;
    ELSIF (B^.priority < A^.priority) THEN
        (*<PRINT
        IF (ZeroIsLowestPriority) THEN
            SetString(NoteString,"        B.Priority < A.Priority ");
        ELSE
            SetString(NoteString,"        A.Priority < B.Priority ");
        END;
        PrintAString(NoteString);
        PRINT>*)
        IF (ZeroIsLowestPriority) THEN
            RETURN -1;
        ELSE
            RETURN 1;
        END;
    END;

        (*  User set priorities are equal:  *)

        (*  If one of the tasks must start sooner than the other one,
            it gets priority. *)

    IF (A^.StartDateUpperBound > B^.StartDateUpperBound) THEN        
        (*<PRINT
        SetString(NoteString,"        B.LowerBound < A.LowerBound so B>A");
        PrintAString(NoteString);
        PRINT>*)
        RETURN 1;
    ELSIF (A^.StartDateUpperBound < B^.StartDateUpperBound) THEN
        (*<PRINT
        SetString(NoteString,"        A.LowerBound < B.LowerBound so A>B");
        PrintAString(NoteString);
        PRINT>*)
        RETURN -1;
    END;

        (* Neither task is a clear winner. *)

    RETURN 0;

END MuchHigherPriority;



END ResPriority.


