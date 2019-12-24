IMPLEMENTATION MODULE RsrcCalc;

(*V7=TRACE*)    (* If you use tracing, set report output to screen,
                   since this module doesn't close the report printer. *)

  (* MODIFICATION HISTORY:

         7/10/87 RSC Created from AssForms for sharing with Planner.
         9/ 8/87 RSC Added "Invisible" recalc type for Rollup tasks.
        12/22/87 RSC Fixed up handling of variable costs during recalcs.
         2/01/88 RSC Fixed up handling of variable costs during recalcs.
                     (My fix of Dec 22 also recalc'd Unit and Fixed costs!)
        18-Feb-88 LAA Moved ManHoursToRealTime and RealTimeToManHours into
                      their own module.
         8-Mar-88 EGK  Recompute the baseline effort in ComputeTaskCosts.
         7-Mar-89 EGK  Changed ComputeTaskCosts to not compute the total
                       effort (based on MaxRatePercent) if it has been
                       entered by the user on the assignment form.
         8-May-89 RSC  Added a new recalc proc to recalc an assignment tree.
                       Done for the sanity of the spreadsheet view.
        17-May-89 RSC  Corrected a ReleaseUnchangedObject that should be
                       a ReleaseObject.
        20-May-89 RSC  Ajust the task calc logic so that Started and Done
                       tasks can have unbelievable assignment rates.
                       Use the common procedure "MakeAssignmentRateMatchTotal"
                       to recalc effort driven assignments.  Gawd, this
                       is hideous.

                       Moved "DurationToRealTime" and "RealTimeToDuration"
                       to the WorkHours module (formerly "ManHours")
        28-Aug-89 EGK  In SummAssignmentsViaAssProc, compensate for real
                       arithmetic errors by quantizing the total effort
                       amount to an integral number of thousandths of a
                       minute, the smallest enterable unit.
        16-Oct-89 EGK  Modified QuantizeRealTime to work correctly for
                       negative real numbers.  Copied Int procedure instead
                       of importing it from FloatingUtilities.
        30-Mar-90 RSC  Made Timeu to Timei/TimeForm conversions.
        11-Apr-90 KKC  Replace all direct calculations on ADate and Duration
                       by calls to FindDuration, SubtractWorkingTime and
                       AddWorkingTime.
         6-Aug-90 RSC  Added the calcs for "AssignmentDriven".
         7-Aug-90 RSC  Minor cleanup of "AssignmentDriven" calc.
        10-Aug-90 RSC  Radicly changed the AssignmentCost procedure, to
                       account for all the new cost types and possibilites.
        27-Aug-90 RSC  Removed the "ViaAss" versions of the procs.
         4-Sep-90 RSC  Extra Dollars count even when the assignment is not
                       billable.
        25-Sep-90 RSC  Fixup cost calcs.
         1-Nov-90 CL   Rename ResourceDriven to EffortDriven.
         5-Feb-91 TGS  We were checking UpperLimit. No can do with varying
                       availabilities.
        12-Aug-91 AJL  In ComputeTaskCosts, avoid having negative to go
                       amounts by changing the way that we apportion effort
                       among the assignments of an effort-driven task.  
                       Rather that dividing the total effort evenly, we
                       keep any spent effort and instead divide the to go 
                       effort among the assignments.  This matches RECALC
                       more closely, and prevents the effort on any assignment
                       from exceeding the spent effort.
        13-Aug-91 AJL  In ComputeTaskCosts, add the spent effort of all 
                       assignments for effort-driven tasks rather than trusting
                       the CompletedSummary.Time.
  *)

FROM Assignments        IMPORT
        (* TYPES *)        AnAssignmentRecord, AnAssignmentAttribute,
                           AnAssignmentArray, AnAssignmentPointer,
        (* PROC *)         DurationOf;

FROM Allocs             IMPORT
        (* TYPES *)        ATaskPtr, AnAssignmentSummary, ADurationMethod,
                           ARollupStatus, AStartStatus, AFixType, ATaskFlag;

FROM CalShift           IMPORT
    (* VAR   *)             TimeSheet;

FROM Dialog             IMPORT
        (* PROCS *)        Error, FatalError;

FROM Duration           IMPORT
    (* PROC *)              FindDuration;

FROM LongConvert        IMPORT
    (* PROC *)              LongToReal;

FROM Timei              IMPORT
    (* CONST *)             MinDate, MaxDate, MaxDuration, NoDuration,
    (* TYPES *)             ADate, ADuration,
    (* PROC  *)             DurationToReal, RealToDuration;

FROM Timeu              IMPORT
        (* VARS  *)        FSMUPH;

FROM TreeObjects        IMPORT
        (* TYPE  *)        ATreeNode;

FROM FlexStor           IMPORT
        (* PROC  *)        AnExtHandle, LockObjectArray, ReleaseObject,
                           ReleaseUnchangedObject;

FROM RsrcMod            IMPORT
        (* TYPE  *)        AResourcePointer, ACostStyle,
                           AResourceType,
        (* PROCS *)        AverageResourceRate;

FROM BigTimeU           IMPORT
        (* TYPE  *)        ABigTime;

FROM StatusChange       IMPORT
        (* PROC *)         MakeAssignmentRateMatchTotal;

FROM SYSTEM             IMPORT
        (* THINGS *)       TSIZE, ADR, ADDRESS;



(*<TRACE
FROM LStrings IMPORT SetString, ConcatS, ConcatLS, CtoS;
FROM RealFormat IMPORT
    (* VAR *)         DefaultAmountFormat, 
    (* PROC *)        FormatAsAmount;
FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;
FROM Tracer IMPORT PrintString, EndTrace;
TRACE>*)





CONST MAXCARDINAL = 65535;
     FMAXCARDINAL = 65535.0;
      Zero        =   0.0;
      Point5      =   0.5;
      One         =   1.0;
      Sixty       =  60.0;
      OneHundred  = 100.0;




    (*<TRACE
VAR
    TraceS : ARRAY [0..255] OF CHAR;
    TraceS2 : ARRAY [0..51] OF CHAR;
    TRACE>*)






PROCEDURE QuantizeRealTime  ( VAR RealTime  : REAL  );

CONST
    OneMinute = One / Sixty;        (* one minute in work-hours *)
    QuantizationUnit = 0.001 * OneMinute;       (* smallest usable unit *)

VAR
    Negative        : BOOLEAN;


    (* 12-Oct-89 RSC This proc moved here from FloatingUtilities *)

    PROCEDURE Int ( r : REAL ) : REAL;
    TYPE
        RealType = RECORD
            CASE INTEGER OF
               1 : word : ARRAY [0..3] OF CARDINAL;
            |  2 : num  : REAL;
            |  3 : bs   : ARRAY [0..3] OF BITSET;
            END;
        END;
    VAR
        temp  : RealType;
        exp   : INTEGER;
        words : CARDINAL;
        bits  : CARDINAL;
        i     : CARDINAL;
    BEGIN
        temp.num := r;
        exp := INTEGER( ( temp.word[ 3 ] MOD 8000H ) DIV 16 ) - 3FFH;
        IF exp < 0 THEN
            temp.num := Zero;
        ELSE
            exp := exp MOD 52;
            exp := 52 - exp;      (* bits to set to 0 *)
            words := exp DIV 16;
            bits := exp MOD 16;
            FOR i := 1 TO ( words ) DO
                temp.word[ i - 1 ] := 0;
            END;
            FOR i := 1 TO bits DO
                EXCL( temp.bs[ words ], i - 1 );
            END;
        END;

        RETURN temp.num;

    END Int;


BEGIN
    Negative := (RealTime < Zero);
    IF (Negative) THEN
        RealTime := -RealTime;
    END;
    RealTime := QuantizationUnit * (Int (0.5 +
                                         (RealTime / QuantizationUnit)));
    IF (Negative) THEN
        RealTime := -RealTime;
    END;
END QuantizeRealTime;








(* Assignment Cost - How many bucks are attributable to this assignment
                     for the specified cost types?

    10-Aug-90 RSC Added the new parameters for EVE.

    Preconditions:

        The assignment record is valid and points to a valid resource.

        PeriodStartDate <= PeriodEndDate

        You have chosen a period of time you are interested in.  To get
        accurate costs back, it is important to chose a period of time
        during which the task who ownes this assingnment actually runs.
        The more accurate the time period, the closer the answer.  For
        example, a cost report over time should call this routine with
        MAX(Task start date, reporting period start) and
        MIN(Task end date,   reporting period end), making sure that the
        start is really before the end.

        See the TimeMath module for procedures to aid in this endever.

    Postconditions:

        The model remains unchanged.  The only affect of this procedure
        is to return the computed cost.

    InputParameters:

        AssignmentRecord    is the assignment you are interested in.
        StartOfPeriod       is the start of the period of time to report
                               about.
        EndOfPeriod         is the end of the period to report about.
        AssignmentCostTypes is the set of cost types to report on.
                                See the notes on the definition of
                                "AnAssignmentCostTypeSet", above.

    OutputParameter:

        RETURN value is the dollar amount for this assignment for the
               sum of all types asked for.

    Note:

        If an empty cost type set is passed in, 0.0 will be returned.

*)
PROCEDURE AssignmentCost( VAR AssignmentRecord      : AnAssignmentRecord;
                              StartOfPeriod,
                              EndOfPeriod           : ADate;
                              AssignmentCostTypes   : AnAssignmentCostTypeSet
                        ) : REAL;
CONST
    SpentExtras = AnAssignmentCostTypeSet{IncludeExtras,IncludeSpent};
VAR
    Cost,
    Units,
    OT      : REAL;
BEGIN

    Cost  := Zero;
    Units := Zero;
    OT    := Zero;

    WITH AssignmentRecord DO
        IF (Billable IN Attributes) THEN

                (* Handle the UNIT items (hours or # of items)
                *)
            IF (IncludeToGo IN AssignmentCostTypes) THEN
                Units := YetToGoQuantity;
                OT    := LongToReal(YetToGoOvertimeHours);
            END;

            IF (IncludeSpent IN AssignmentCostTypes) THEN
                Units := Units + ActualQuantity;
                OT    := OT    + LongToReal(OvertimeHours - YetToGoOvertimeHours);
            END;

                (* Note that the overtime multiplier can be applied
                   to the hours as much as it can to the resulting cost.
                   4 hours at time-and-a-half is the same as 6 hours at
                   normal time.
                *)
            IF (IncludeOvertime IN AssignmentCostTypes) THEN
                Units := Units + (OT * Resource^.OvertimeMultiplier);
            END;

                (* Translate units into bucks
                *)
            IF (Units <> Zero) THEN
                Cost := Units *
                        AverageResourceRate( Resource,
                                 StartOfPeriod, EndOfPeriod,
                                 (TreatAsBaseline IN AssignmentCostTypes) );
            END;

        END;
            (* Add in extra bucks, even if this assignment is NOT billable!
               Ah, but only show extras as SPENT extras, there are no
               TO GO extras.

            *)                  (* 4-Sep-90 RSC *)
        IF ((AssignmentCostTypes * SpentExtras) = SpentExtras) THEN
            Cost := Cost + ExtraCosts;
        END;
    END;

    RETURN Cost;

END AssignmentCost;





 (* SummTaskNodeAmounts - Figure out the cost of this task in bucks and time.

      Preconditions  - A Valid TaskNode
                       BaseLine is TRUE if you want BaseLine.  FALSE=Plan.
      Postconditions - Completed and ToGo are local summaries.
 *)
PROCEDURE SummTaskNodeAmounts( TaskNode : ATreeNode;
                               BaseLine : BOOLEAN;
                           VAR Completed,
                               ToGo     : AnAssignmentSummary );
VAR Task        : ATaskPtr;
    Assignments : AnAssignmentArray;
    StartDate,
    EndDate     : ADate;
    Count       : CARDINAL;
    Handle      : AnExtHandle;
BEGIN
    Task  := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    IF (BaseLine) THEN
        WITH Task^.BaseLine DO
            Handle      := Assignments;
            StartDate   := Dates.EarlyStart;
            EndDate     := Dates.EarlyEnd;
        END;
    ELSE
        WITH Task^.Plan DO
            Handle      := Assignments;
            StartDate   := Dates.EarlyStart;
            EndDate     := Dates.EarlyEnd;
        END;
    END;

    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);

    Count := LockObjectArray( Handle,
                              Assignments, TSIZE( AnAssignmentRecord ) );

    SummAssignments( Assignments, Count,
                     StartDate,   EndDate,
                     BaseLine,
                     Completed,
                     ToGo );

    ReleaseObject( Handle );

END SummTaskNodeAmounts;




 (* Summ Assignments - Summarize the assignment records.

    Preconditions:

        The assignment array is valid for Count assignments.

        StartOfPeriod <= EndOfPeriod

        You have chosen a period of time you are interested in.  To get
        accurate costs back, it is important to chose a period of time
        during which the task who ownes this assingnment actually runs.
        The more accurate the time period, the closer the answer.  For
        example, a cost report over time should call this routine with
        MAX(Task start date, reporting period start) and
        MIN(Task end date,   reporting period end), making sure that the
        start is really before the end.

        See the TimeMath module for procedures to aid in this endever.

    Postconditions:

        The model remains unchanged.  The only affect of this procedure
        is to return the computed cost.

    Input:

        Assignments is a valid assignment array.
        Count       is the number of assignment records
        StartOfPeriod is the start of the period to report on.
        EndOfPeriod is the end of the period.
        BaseLine    is wether you want BaseLine or not (Plan).

     Output:

        CompletedSummary and ToGoSummary are the returned amounts.
 *)
PROCEDURE SummAssignments(  Assignments     : AnAssignmentArray;
                            Count           : CARDINAL;
                            StartOfPeriod,
                            EndOfPeriod     : ADate;
                            BaseLine        : BOOLEAN;
                        VAR CompletedSummary,
                            ToGoSummary     : AnAssignmentSummary);
VAR
    i               : CARDINAL;
    Flags           : AnAssignmentCostTypeSet;
BEGIN
    CompletedSummary.Amount := Zero;
    CompletedSummary.Time   := Zero;
    ToGoSummary.Amount      := Zero;
    ToGoSummary.Time        := Zero;
    Flags                   := AnAssignmentCostTypeSet{IncludeOvertime};
    IF (BaseLine) THEN
        INCL(Flags,TreatAsBaseline);
    END;

(*$O-*)

    i := 0;
    WHILE (i < Count) DO
        CompletedSummary.Amount := CompletedSummary.Amount +
                  AssignmentCost( Assignments^[i],
                                  StartOfPeriod, EndOfPeriod,
                                  Flags + AnAssignmentCostTypeSet{IncludeSpent} );  (* 25-Sep-90 RSC removed Extras *)

        ToGoSummary.Amount := ToGoSummary.Amount +
                  AssignmentCost( Assignments^[i],
                                  StartOfPeriod, EndOfPeriod,
                                  Flags + AnAssignmentCostTypeSet{IncludeToGo} );

        WITH Assignments^[i] DO
            IF (Resource^.Type = Employable) THEN
                ToGoSummary.Time      :=  ToGoSummary.Time
                                        + YetToGoQuantity;

                CompletedSummary.Time :=  CompletedSummary.Time
                                        + ActualQuantity;
            END;
        END;
        INC(i);
    END;

(*$O=*)

    QuantizeRealTime (ToGoSummary.Time);            (* 8/28/89 EGK *)

END SummAssignments;








 (* ComputeTaskNodeCosts - Figure out the cost of this task in work
                           hours and duration.  This also may ajust the
                           resource assignment records.

                           This also ajusts the task's COSTS.

                           There is no need to call "SummAssignments"
                           after calling this procedure.

      Preconditions  - A Valid TaskNode
      Postconditions - The Task has been recomputed, and the results
                       are stored in the task record.
 *)
PROCEDURE ComputeTaskNodeCosts( TaskNode : ATreeNode );
VAR Task        : ATaskPtr;
    Assignments : AnAssignmentArray;
    Count       : CARDINAL;
    MaxDur              : ADuration;
    TempDuration        : ADuration;
    UnusedSummary       : AnAssignmentSummary;
BEGIN
    Task  := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    WITH Task^ DO
        IF (rollupstatus = NotRollup) THEN
            Count := LockObjectArray( Plan.Assignments,
                                      Assignments, TSIZE( AnAssignmentRecord ) );

            ComputeTaskCosts( Assignments, Count,
                              duration,
                              CompletedSummary,
                              ToGoSummary,
                              DurationMethod,
                              StartStatus,
                              Plan.Dates.EarlyStart,
                              Plan.Dates.EarlyEnd,
                              fixation );

            ReleaseObject( Plan.Assignments );

(* **************************** RSC 23-Aug-90 Why recompute baseline???

            IF (BaseLineExists IN TaskFlags) THEN       (* 3/8/88 EGK *)
                Count := LockObjectArray( BaseLine.Assignments,
                                          Assignments, TSIZE( AnAssignmentRecord ) );

                TempDuration :=  FindDuration
                                 (
                                    BaseLine.Dates.EarlyStart,
                                    BaseLine.Dates.EarlyEnd,
                                    TimeSheet
                                 );
                UnusedSummary.Time := Zero;
                UnusedSummary.Amount := Zero;
                ComputeTaskCosts( Assignments, Count,
                                  TempDuration,
                                  UnusedSummary,
                                  BaseLineSummary,
                                  DurationMethod,
                                  StartStatus,
                                  Plan.Dates.EarlyStart,
                                  Plan.Dates.EarlyEnd,
                                  fixation );

                ReleaseObject( BaseLine.Assignments );
            END;
********************************* *)

        END;
    END;
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
END ComputeTaskNodeCosts;










 (* ComputeTaskCosts - Figure out the cost of this task in effort
                       and duration.  This also may ajust the resource
                       assignment records.

      Preconditions  - Assignments is an accessible assignment array.
                       Count    is the count of assignments.
                       Duration is the Task Duration.  It is input for
                                Duration Driven tasks and ignored otherwise.
                       CompletedSummary and ToGoSummary is the effort in
                                man hours for this task.  They are input
                                for EffortDriven tasks.
                       Method   is the task duration method.

        StartOfPeriod <= EndOfPeriod

        You have chosen a period of time you are interested in.  To get
        accurate costs back, it is important to chose a period of time
        during which the task who ownes this assingnment actually runs.
        The more accurate the time period, the closer the answer.  For
        example, a cost report over time should call this routine with
        MAX(Task start date, reporting period start) and
        MIN(Task end date,   reporting period end), making sure that the
        start is really before the end.

        See the TimeMath module for procedures to aid in this endeavor.


      Postconditions - May recalc resource assignment records.
                       Duration, for Duration Driven tasks, is the same as
                                what was passed.  For EffortDriven Tasks,
                                it is the (new) task duration.
                       CompletedSummary and ToGoSummary, for EffortDriven
                                tasks, the Time field is what was passed.  For
                                Duration Driven tasks, they are the (new)
                                Work Hours.

                           This also ajusts the task's COSTS.

                           There is no need to call "SummAssignments"
                           after calling this procedure.

    CALLER BEWARE!!

 *)

PROCEDURE ComputeTaskCosts( Assignments : AnAssignmentArray;
                            Count       : CARDINAL;
                        VAR Duration    : ADuration;
                        VAR CompletedSummary,
                            ToGoSummary : AnAssignmentSummary;
                            Method      : ADurationMethod;
                            StartStatus : AStartStatus;
                            StartOfPeriod,
                            EndOfPeriod : ADate;
                            Fixation    : AFixType );
VAR FPercent,
    FDuration,
    TaskEffort,
    TaskSpentEffort,
    RsrcEffort      : REAL;
    i               : CARDINAL;
    MaxDur,
    AssignmentDur   : ADuration;
    Number          : CARDINAL;
    P               : CARDINAL;
    AssignmentPtr   : AnAssignmentPointer;

BEGIN
  (*
         Duration Driven : Compute resource effort as task duration * %.
                           well, % / 100.
  *)
(*$O-*)
    CASE Method OF

    | DurationDriven :

        CompletedSummary.Time   := Zero;
        ToGoSummary.Time        := Zero;
        TaskEffort              := DurationToReal(Duration) / FSMUPH;
        i                       := 0;
        WHILE (i < Count) DO
            WITH Assignments^[i] DO
                EXCL (Attributes, CalcError);
                IF (Resource^.CostStyle = CAmountRateTime) THEN
                    IF (ComputeByHours IN Attributes) THEN   (* 3/7/89 EGK *)
                        RsrcEffort := ActualQuantity + YetToGoQuantity;
                        IF (RsrcEffort = Zero) THEN
                            MaxRatePercent := 0;
                            PercentageEach := 1C; (* 5-Feb-91 TGS *)
                        ELSIF (StartStatus = FutureS) AND
                              (TaskEffort = Zero)     THEN
                            INCL (Attributes, CalcError);
                        ELSE
                            IF (MakeAssignmentRateMatchTotal( Assignments^[i],
                                                              Duration )) THEN
                                (* 5-Feb-91 TGS can't do this now...
                                IF ((StartStatus = FutureS) AND
                                    (FLOAT(MaxRatePercent) > Resource^.UpperLimit)) THEN
                                    INCL (Attributes, CalcError);
                                END;
                                *)
                            ELSE
                                INCL (Attributes, CalcError);
                            END;
                        END;
                    ELSE
                        RsrcEffort := (TaskEffort
                                    * (FLOAT(MaxRatePercent)
                                    /  OneHundred));
                        YetToGoQuantity := RsrcEffort - ActualQuantity;
                    END;
                ELSE
                    EXCL (Attributes, ComputeByHours);
                END;
            END;
            INC(i);
        END;




      (*
         EffortDriven : Figure out max percent and continue iff > 0.
                           Make a second pass to compute resource efforts
                              and split into total and yet to go.
      *)

    | EffortDriven :

        FPercent := Zero;          (* Total of the MaxRatePercent on all assignments. *)
        TaskSpentEffort := Zero;

        i        := 0;
        WHILE (i < Count) DO
            WITH Assignments^[i] DO
                IF (Resource^.Type = Employable)  THEN
                    FPercent := FPercent + FLOAT(MaxRatePercent);
                    TaskSpentEffort := TaskSpentEffort + ActualQuantity;
                    (* Recalc var costs
                    *)
                ELSIF (Resource^.CostStyle = CAmountRateTime) THEN
                    RsrcEffort := ( (DurationToReal(Duration) / FSMUPH)
                                * (FLOAT(MaxRatePercent)
                                /  OneHundred));
                    YetToGoQuantity := RsrcEffort - ActualQuantity;
                END;
                EXCL (Attributes, CalcError);
                EXCL (Attributes, ComputeByHours);
            END;
            INC(i);
        END;

        (*<TRACE
        SetString(TraceS, "In ComputeTaskCosts, FPercent = ");
        FormatAsAmount(FPercent, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
        ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        TRACE>*)


        IF (FPercent = Zero) THEN
            Duration := NoDuration; (* No resources!! *)
            RETURN;
        END;
        TaskEffort := CompletedSummary.Time
                    + ToGoSummary.Time;
        FDuration  := (TaskEffort / (FPercent / OneHundred));
        FDuration  := (FDuration * FSMUPH) + Point5; (* Turn Hours into clock tics *)
        IF (FDuration >= FMAXCARDINAL) THEN
            Duration := MaxDuration;
        ELSE
            Duration := RealToDuration( FDuration );
        END;
        IF (StartStatus >= StartedS) OR (Fixation = FixedDate) THEN
            MaxDur := FindDuration( StartOfPeriod, MaxDate, TimeSheet );
            IF (Duration > MaxDur) THEN
                Duration := MaxDur;
            END;
        END;

        (*<TRACE
        SetString(TraceS, "    FDuration = ");
        FormatAsAmount(FDuration, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
        ConcatLS(TraceS, TraceS2);
        ConcatS(TraceS,", Duration = ");  CtoS(Duration,TraceS2);
        ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        SetString(TraceS, "    ToGoSummary.Time = ");
        FormatAsAmount(ToGoSummary.Time, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
        ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        SetString(TraceS, "    TaskEffort = ");
        FormatAsAmount(TaskEffort, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
        ConcatLS(TraceS, TraceS2);
        ConcatS(TraceS, ", TaskSpentEffort = ");
        FormatAsAmount(TaskSpentEffort, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
        ConcatLS(TraceS, TraceS2);
        PrintString(TraceS);
        TRACE>*)


                (* The spent effort on the task is set to the total of
                   the assignments spent effort.  Keep total task effort
                   unchanged. *)

        CompletedSummary.Time := TaskSpentEffort;
        ToGoSummary.Time      := TaskEffort - TaskSpentEffort;


            (* Divide the to go effort among the assignments, so that 
               the to go effort on each is proportional to its MaxRatePercent.
               The Spent Effort on each is unchanged.
            *)
             

        i := 0;
        WHILE (i < Count) DO
            WITH Assignments^[i] DO
                IF (Resource^.Type = Employable)  THEN
                    (*<TRACE
                    SetString(TraceS, "    YetToGoQuantity = ");
                    FormatAsAmount(YetToGoQuantity, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
                    ConcatLS(TraceS, TraceS2);
                    ConcatS(TraceS,", ActualQuantity = ");
                    FormatAsAmount(ActualQuantity, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
                    ConcatLS(TraceS, TraceS2);
                    PrintString(TraceS);
                    TRACE>*)
                    YetToGoQuantity := (FLOAT(MaxRatePercent) / FPercent)
                                      * ToGoSummary.Time;
                    (*<TRACE
                    SetString(TraceS, "    YetToGoQuantity = ");
                    FormatAsAmount(YetToGoQuantity, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
                    ConcatLS(TraceS, TraceS2);
                    ConcatS(TraceS,", ActualQuantity = ");
                    FormatAsAmount(ActualQuantity, DefaultAmountFormat, TraceS2, 8, 0, 3, FALSE);
                    ConcatLS(TraceS, TraceS2);
                    PrintString(TraceS);
                    TRACE>*)
                END;
            END;
            INC(i);
        END;


        (* 6-Aug-90 RSC Added this case.....

            - The task duration is the LONGEST assignment duration.
            - The task effort is the summ of the efforts of the employables,
              including overtime efforts.
        *)

    | AssignmentDriven :

        Duration                := 0;
        CompletedSummary.Time   := Zero;
        ToGoSummary.Time        := Zero;

        i := 0;
        WHILE (i < Count) DO
            WITH Assignments^[i] DO
                IF (Resource^.Type = Employable)  THEN
                    RsrcEffort := YetToGoQuantity + ActualQuantity;
                    MaxDur     := DurationOf( MaxRatePercent, RsrcEffort );
                    IF (MaxDur > Duration) THEN
                        Duration := MaxDur;
                    END;

                    ToGoSummary.Time      :=  ToGoSummary.Time
                                            + YetToGoQuantity;

                    CompletedSummary.Time :=  CompletedSummary.Time
                                            + ActualQuantity;
(* 25-Sep-90 RSC ??? OT ??? *)
                    INCL (Attributes, ComputeByHours);

                ELSIF (Resource^.CostStyle <> CAmountRateTime) THEN
                    EXCL (Attributes, ComputeByHours);
                END;
                EXCL (Attributes, CalcError);
            END;
            INC(i);
        END;

    ELSE
        FatalError(); (* Not duration, resource, or assignment driven? *)
    END;
(*$O=*)

    SummAssignments( Assignments, Count,
                     StartOfPeriod, EndOfPeriod,
                     FALSE, (* Baseline? *)
                     CompletedSummary, ToGoSummary );

END ComputeTaskCosts;




END RsrcCalc.


