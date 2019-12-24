IMPLEMENTATION MODULE RollupResourceModule;

    (*  MODIFICATION HISTORY
        11-Jan-88 LAA   Changed UnlockFlexStorDataObject to UnlockUnchanged.
                        Also changed ReleaseObject to ReleaseUnchanged.
        12-Feb-88 LAA   Costs and resources were appearing in the period
                        after the end of the task, even though their amounts
                        were zero.
        17-Feb-88 RSC   When there were no more tasks at the same level as
                        the one we were on, we would search to the end of
                        the tree.
        26-Feb-88 LAA   Changed parameters of RollupResource.
         3-Mar-88 AJL  -Modified CalcSpentAndToGo to compute ratios for
                        milestones.
                       -Changed the computation of SpentDuration in same
                        from OurAsOfDate-EarlyStart+1 to OurAsOfDate-EarlyStart.
                       -Changed start date and end date transition points
                        in same when computing ratios.
         4-Mar-88 AJL  -Add PeriodType parameter to RollupResources to handle
                        the problem of a milestone occurring at the exact end 
                        of the schedule.
                       -Modify CalcSpentAndToGo to never treat any baseline
                        amounts as spent.
         6-Mar-88 AJL  -Removed use of the local variable OurAsOfDate in favor 
                        of the imported AsOfDate and then cleaned up the 
                        relevant calculations so that costs are prorated 
                        correctly, which they were occasionally not.
        27-Jun-88 AJL  -Added assignment filtering.  
         5-Jul-88 AJL  -Revised the insides of CalcSpentAndToGo to simplify
                        the formulas.  See comments.
        31-Aug-88 AJL  -Removed special processing for the last period in
                        a report.  This is so that filtering reports for 
                        particular slices of time will give consistent reporting
                        of milestone expenses.  This requires a change to the
                        ROLLUPRE or TLCRFORM module to ensure that the final
                        milestone of a schedule has a period in which to appear,
                        which may include adding an extra period at the end of 
                        a report.  
        13-Jun-89 AJL  -If not using CostTracking, prorate spent and to go costs
                        as they would be if spending were on schedule.  We do this
                        by adding together the spent and actual amounts.

        28-Jul-89 RSC  -Pro-Rate MaxRatePercent to mean "Proportion of the
                        Max Rate Percent this period vs POSSIBLE percent
                        this period", or:

                            MaxRatePercent * (TaskTimeInPeriod / PeriodTime)

                        This does not apply to periods of the entire calendar.
        23-Aug-89 EGK   Made "CostTracking" a parameter of RollupResource
                        instead of an imported variable from Changer.
        23-Oct-89 MWP/AJL Modified the RollupResources procedure so that the
                        spent duration (with cost tracking off) is computed
                        right when the AsOfDate is earlier than the start of
                        the task.  This is the nested LaterOf(LaterOf . . . 
                        stuff.     
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        11-Apr-90 KKC   Replace all direct calculations on ADate and Duration
                        by calls to FindDuration, SubtractWorkingTime and
                        AddWorkingTime.
        10-Aug-90 RSC   Updated for new call to AssignmentCost.
        23-Aug-90 TGS   Add new XTab columns; initialize & compute them.
         4-Oct-90 TGS   Use EarlyEnd-EarlyStart instead of duration.
        22-Oct-90 TGS   Accumulate Spent/ToGoOTDollars, ExtraCosts. Now
                        Spent/ToGoDollars do not include Extras, OT.
        16-Nov-90 TGS   Fix Spent/ToGoRatio.
        26-Nov-90 TGS   Create ResCalcSpentAndToGo - uses AssignmentHours.
         4-Jun-91 TGS   Rewrite AddAssignmentInfo.
        11-Sep-91 TGS   Fix PercentAssigned calculation.
        14-Sep-91 TGS   Added check for VarCost assigned to milestone (should
                        return zero except for any Extra Costs).
                        If Assignment isn't Billable, don't add in its $.
        16-Sep-91 TGS   For Baseline stuff, use "0" instead of EndOfSpentDate.
                        We consider ANY spending to be ToGo.
        23-Sep-91 EGK   When computing the baseline values for a cost, use
                        the EarlyStart and EarlyEnd as date values (we were
                        using 0 for the start date, which caused Eve bug
                        #5073 (re-opened).
        24-Sep-91 EGK   For the baseline calculation on a resource, we were
                        setting DataExists to the value of
                        ComputeEffortsAndCostsInPeriod, instead of setting
                        it to TRUE if the function returns TRUE.  The effect
                        was that if one assignment had no data, it could
                        wipe out the accumulation so far.
        06-Mar-92 LAA   In AddAssignmentInfo, the ToGo amounts of a cost were
                        being spread over the interval from EndOfSpending to
                        the task's EarlyEnd date.  However, this isn't correct
                        for a future task, because EndOfSpending is then set
                        to the AsOf date.  This was changed to pick up the
                        later of the EndOfSpending and the EarlyStart.
                        
    *)


FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ADateBlock, ATaskFilterSet, ATaskFilter,
    (* PROC *)                  CheckTaskValid;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord, AnAssignmentArray,
                                AnAssignmentAttribute,
                                AnAssignmentAttributeSet, ASetOfRoles;

FROM AssgnCalc              IMPORT
    (* PROC *)                  ComputeEffortsAndCostsInPeriod,
                                ComputeLinearCostsInPeriod;

FROM AssgnUse               IMPORT
    (* TYPE *)                  ACompletion, (* CompletedHours, YetToGoHours, TotalHours *)
    (* PROC *)                  AssignmentHours;

FROM CalShift               IMPORT
    (* VAR *)                   TimeSheet;

FROM RateLists              IMPORT
    (* TYPE *)                  ARateList;

FROM Dialog                 IMPORT 
    (* PROC *)                  NotYetImplemented;

FROM Duration               IMPORT
    (* PROC *)                  AddWorkingTime, SubtractWorkingTime,
                                FindDuration;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle,
    (* PROC *)                  LockObjectArray, ReleaseObject, 
                                ReleaseUnchangedObject;

FROM Filter1                IMPORT
    (* PROC *)                  AssignmentFiltersPassed;

FROM LongConvert            IMPORT
    (* PROC *)                  LongToReal;

FROM RsrcCalc               IMPORT
    (* TYPE *)                  AnAssignmentCostType, AnAssignmentCostTypeSet,
    (* PROC *)                  AssignmentCost;

FROM RsrcMod                IMPORT
    (* PROC *)                  AverageResourceRate,
    (* TYPE *)                  AResourcePointer, ACostStyle, AResourceType,
                                CheckResourceValid;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, ADDRESS, TSIZE;

FROM Timei                  IMPORT
    (* CONST*)                  NoDuration, MaxDuration,
    (* TYPE *)                  ADate, ADuration, ADurationUnit,
    (* PROC *)                  DurationToReal, RealToDuration;

FROM Timeu                  IMPORT 
    (* VAR*)                    FSMUPH;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM VaryAssgnment          IMPORT 
    (* TYPE *)                  AVaryingAssgnList;




CONST  Zero        = 0.0;  (* Because Logitek cares.   Ugh. *)
       Point5      = 0.5;
       One         = 1.0;
       MAXCARDINAL = 65535;

    PROCEDURE AssignmentFilteredIn( TaskNode : ATreeNode; VAR Assignment : AnAssignmentRecord ) : BOOLEAN;
    BEGIN
        RETURN Selected IN AssignmentFiltersPassed(TaskNode,Assignment);
    END AssignmentFilteredIn;


  (* Rollup Resource - Rollup a tasks' resource[s].

        The goal of this module is to return assignment data for one or more
        resources for a task AND ALL ITS FILTERED-IN kids.  This is different
        from Rollups.Rollup.

        Preconditions  - Task          is a valid task node
                         ResourceNode  is a valid resource node, or NIL if
                                          all resources, costs, etc. are to
                                          be accumulated.
                         StartDate     -  defines the period during which
                         EndDate          resource info is rolled up
                         KidsToo       is "Rollup task's Children?"
                         Baseline      is 'Do you want Baseline information'
                         FirstTime     is 'Do you want me to initialize?'
                         PeriodType    should be NormalPeriod for all date
                                       ranges except when accumulating costs
                                       for the terminal range.


        Postconditions - Accumulation  is record containing rolled up values.
  *)

PROCEDURE RollupResource(    Task           : ATreeNode;
                             ResourceNode   : ATreeNode;
                             StartOfPeriod,
                             EndOfPeriod    : ADate;
                             KidsToo,
                             Baseline,
                             FirstTime,
                             CostTracking   : BOOLEAN;
                             PeriodType     : APeriodType;
                         VAR Accumulation   : AnAccumulationRecord);


VAR
    SameLevelTask           : CARDINAL;  (* RSC 2/17/88 *)
    ResourcePtr             : AResourcePointer;
    r                       : AResourceKind;

    PROCEDURE AddAssignmentInfo( Task   : ATreeNode);

    VAR
        TaskPtr             : ATaskPtr;
        i                   : CARDINAL;
        EMSHandle           : AnExtHandle;
        AssignmentArray     : AnAssignmentArray;
        EarlyStart, EarlyEnd,
        IntervalStart, IntervalEnd          : ADate;
        AssExtraCosts                       : REAL;
        AssSpentDollars, AssToGoDollars     : REAL; 
        AssSpentQuantity, AssToGoQuantity   : REAL; 
        LAssignment         : AnAssignmentRecord;
        TempDate            : ADate;


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

            (* 11-Sep-91 TGS *)
        PROCEDURE MaxRateThisPeriod() : REAL;
        CONST
            MAXPERIOD   = 65534;
            OneHundred  = 100.0;
        VAR
            PeriodDuration  : ADuration;
        BEGIN
            WITH LAssignment DO
                PeriodDuration := FindDuration
                                    (StartOfPeriod, EndOfPeriod, TimeSheet);
                IF PeriodDuration >= MAXPERIOD THEN
                    (* Probably TvsR, just return the assigned amount *)
                    RETURN FLOAT(MaxRatePercent)/OneHundred;
                ELSE
                    (* return prorata portion in this period *)
                    RETURN  (AssSpentQuantity + AssToGoQuantity) * 
                            FSMUPH
                            /
                            (FLOAT(PeriodDuration));
                END;
            END;
        END MaxRateThisPeriod;


    BEGIN                   (* AddAssignmentInfo *)

        TaskPtr := Task^.Methods^.LockFlexStorDataObject(Task);

        IF (Baseline) THEN
            EMSHandle := TaskPtr^.BaseLine.Assignments;
            EarlyStart  := TaskPtr^.BaseLine.Dates.EarlyStart;
            EarlyEnd    := TaskPtr^.BaseLine.Dates.EarlyEnd;
        ELSE               (* must be the plan *)
            EMSHandle := TaskPtr^.Plan.Assignments;
            EarlyStart  := TaskPtr^.Plan.Dates.EarlyStart;
            EarlyEnd    := TaskPtr^.Plan.Dates.EarlyEnd;
        END;
        Task^.Methods^.UnlockUnchangedDataObject(Task);           (* 11-Jan-88 LAA *)
        
        IF (ADDRESS(EMSHandle) = NIL) THEN (* Is there a handle? *)
            RETURN;
        END;

        i := LockObjectArray(EMSHandle, AssignmentArray, TSIZE(AnAssignmentRecord));

        WHILE (i > 0) DO
            DEC(i);
            LAssignment := AssignmentArray^[i]; (* Lousy stinking optimizer! *)
            WITH LAssignment DO 
                    (* If we want all resources, or we want this resource,
                       and this resource is not filtered out . . . *)
                IF ((ResourcePtr = NIL) OR (Resource = ResourcePtr))
                   AND
                   (AssignmentFilteredIn(Task,LAssignment)) THEN

                    WITH Accumulation[ResourceKind(Resource)] DO

                        AssSpentQuantity := Zero;
                        AssToGoQuantity  := Zero;
                        AssExtraCosts    := Zero;
                        AssSpentDollars  := Zero;
                        AssToGoDollars   := Zero;

                            (* Prorate the expenses. *)
                        IF (ResourceKind(Resource) = Rsrc) THEN
                            IF (VaryingAssignment <> AVaryingAssgnList(NIL)) THEN
                                
                                IF (Baseline) THEN

                                    IF ComputeEffortsAndCostsInPeriod
                                          ( VaryingAssignment,
                                            Resource^.BaseLineRates,
                                            0, (* 16-Sep-91 TGS *)
                                            StartOfPeriod, EndOfPeriod,
                                            FALSE, (* "We Want ToGo" *)
                                            AssToGoQuantity,
                                            AssToGoDollars
                                          ) THEN
                                        DataExists := TRUE; (* 9/24/91 EGK *)
                                    END;

                                ELSE

                                    IF ComputeEffortsAndCostsInPeriod
                                          ( VaryingAssignment,
                                            Resource^.ActualRates,
                                            EndOfSpentDate,
                                            StartOfPeriod, EndOfPeriod,
                                            TRUE, (* "We Want Spent" *)
                                            AssSpentQuantity,
                                            AssSpentDollars
                                          ) THEN
                                        DataExists := TRUE;
                                    END;

                                    IF ComputeEffortsAndCostsInPeriod
                                          ( VaryingAssignment,
                                            Resource^.ActualRates,
                                            EndOfSpentDate,
                                            StartOfPeriod, EndOfPeriod,
                                            FALSE, (* "We Want ToGo" *)
                                            AssToGoQuantity,
                                            AssToGoDollars
                                          ) THEN
                                        DataExists := TRUE;
                                    END;

                                    IF ComputeLinearCostsInPeriod
                                          ( ExtraCosts,
                                            EarlyStart, EndOfSpentDate,
                                            StartOfPeriod, EndOfPeriod,
                                            TRUE, (* Spent *)
                                            AssExtraCosts,
                                            IntervalStart, IntervalEnd
                                          ) THEN
                                        DataExists := TRUE;
                                    END;
                                
                                END;
                            END;

                        ELSE (* a "cost" resource *)

                            IF (Baseline) THEN
                                    (* 14-Sep-91 TGS added this check *)
                                IF ((ResourceKind(Resource) <> VarCost) OR
                                    (EarlyStart <> EarlyEnd)) AND
                                   ComputeLinearCostsInPeriod
                                      ( YetToGoQuantity,
                                        EarlyStart, EarlyEnd, (* 16-Sep-91 TGS *) (* 9/24/91 EGK *)
                                        StartOfPeriod, EndOfPeriod,
                                        FALSE, (* all baseline is ToGo *)
                                        AssToGoQuantity,
                                        IntervalStart, IntervalEnd
                                      ) THEN

                                    AssToGoDollars :=
                                        AssToGoQuantity *
                                        AverageResourceRate( Resource,
                                                             IntervalStart,
                                                             IntervalEnd,
                                                             TRUE
                                                           );
                                    DataExists := TRUE;

                                END;
                            
                            ELSE   

                                IF (ResourceKind(Resource) = VarCost) AND
                                   ComputeLinearCostsInPeriod
                                      (   ExtraCosts,
                                          EarlyStart, EndOfSpentDate,
                                          StartOfPeriod, EndOfPeriod,
                                          TRUE, (* Spent *)
                                          AssExtraCosts,
                                          IntervalStart, IntervalEnd
                                      ) THEN

                                    DataExists := TRUE;
                                END;

                                    (* 14-Sep-91 TGS added this check *)
                                IF (ResourceKind(Resource) <> VarCost) OR
                                   (EarlyStart <> EarlyEnd) THEN
                                    IF ComputeLinearCostsInPeriod
                                        ( ActualQuantity,
                                            EarlyStart, EndOfSpentDate,
                                            StartOfPeriod, EndOfPeriod,
                                            TRUE, (* Spent *)
                                            AssSpentQuantity,
                                            IntervalStart, IntervalEnd
                                        ) THEN

                                        AssSpentDollars :=
                                            AssSpentQuantity *
                                            AverageResourceRate(Resource,
                                                                IntervalStart,
                                                                IntervalEnd,
                                                                FALSE
                                                                );
                                        DataExists := TRUE;
                                    END;

                                    IF (EarlyStart > EndOfSpentDate) THEN  (* 06-Mar-92 *)
                                        TempDate := EarlyStart;
                                    ELSE
                                        TempDate := EndOfSpentDate;
                                    END;

                                    IF ComputeLinearCostsInPeriod
                                        ( YetToGoQuantity,
                                            TempDate, EarlyEnd,
                                            StartOfPeriod, EndOfPeriod,
                                            FALSE, (* ToGo *)
                                            AssToGoQuantity,
                                            IntervalStart, IntervalEnd
                                        ) THEN

                                        AssToGoDollars :=
                                            AssToGoQuantity *
                                            AverageResourceRate( Resource,
                                                                IntervalStart,
                                                                IntervalEnd,
                                                                FALSE
                                                            );
                                        DataExists := TRUE;
                                    END;
                                END;
                            END;
                        END;

                        (* Accumulate this assignment into accumulator *)
                        Assignment.ActualQuantity :=
                            Assignment.ActualQuantity + AssSpentQuantity;

                        Assignment.YetToGoQuantity := 
                            Assignment.YetToGoQuantity + AssToGoQuantity;

                        Assignment.ExtraCosts :=
                            Assignment.ExtraCosts + AssExtraCosts;

                        IF (Billable IN Attributes) THEN
                            SpentDollars :=
                                SpentDollars + AssSpentDollars;

                            ToGoDollars :=
                                ToGoDollars  + AssToGoDollars;
                        END;

                        IF (Resource^.CostStyle = CAmountRateTime) THEN

                            TotalMaxRate := 
                                TotalMaxRate + MaxRateThisPeriod(); (* 11-Sep-91 TGS *)

                            IF (Assignment.PercentageEach < PercentageEach) THEN
                                Assignment.PercentageEach := PercentageEach;
                            END;
                            IF (Assignment.ActualTimeUnits < ActualTimeUnits) THEN
                                Assignment.ActualTimeUnits := ActualTimeUnits;
                            END;
                        END;

                        Assignment.Attributes := Assignment.Attributes + Attributes;

                    END;
                END;
            END;
        END;

        ReleaseUnchangedObject(EMSHandle);                        (* 11-Jan-88 LAA *)

    END AddAssignmentInfo;


BEGIN                       (* RollupResource *)

    IF (ResourceNode = NIL) THEN
        ResourcePtr := NIL;
    ELSE
        ResourcePtr := ResourceNode^.Methods^.GetDataObject(ResourceNode);
        CheckResourceValid( ResourcePtr );
    END;

    IF (FirstTime) THEN
        CheckTaskValid( Task ); (* Only bother to check the FIRST time. *)
        FOR r := Rsrc TO VarCost DO
            WITH Accumulation[r] DO
                DataExists      := FALSE;  (* Not yet it don't *)
                SpentDollars    := Zero;
                ToGoDollars     := Zero;
                SpentOTDollars  := Zero;
                ToGoOTDollars   := Zero;
                RealDoneOTHours := Zero;
                RealToGoOTHours := Zero;
                TotalMaxRate    := Zero;
                WITH Assignment DO
                    Resource        := ResourcePtr;
                    Attributes      := AnAssignmentAttributeSet{};
                    MaxRatePercent  := 0;
                    PercentageEach  := 0C;
                    ActualTimeUnits := Minutes;
                    MaxRateUnits    := 0;
                    Expenses        := AnExtHandle(NIL);
                    ActualQuantity  := Zero;
                    YetToGoQuantity := Zero;
                    OvertimeHours   := 0L;
                    YetToGoOvertimeHours := 0L;
                    ExtraCosts      := Zero;
                    VaryingAssignment    := AnExtHandle(NIL);
                    EndOfSpentDate  := 0;
                    Spare           := BITSET{};
                    Roles           := ASetOfRoles{};
                END;
            END;
        END;
    END;

    AddAssignmentInfo(Task);

    IF (KidsToo) THEN

     (* RSC 2/17/88 -
           This used to save off the next tree node at this level by using
           a GetNext.  This would return NIL if there was no next level task,
           and therefore, we would search the tree to the end.  I've changed
           this to pay attention to the indentation level.
     *)
        SameLevelTask := Task^.Methods^.IndentationLevel( Task );

        Task := Task^.Methods^.FirstChild(Task);
        WHILE (Task <> NIL) AND
              (SameLevelTask < Task^.Methods^.IndentationLevel( Task )) DO
            IF (Task^.Methods^.Visible(Task)) THEN
                AddAssignmentInfo(Task);
            END;
            Task := Task^.Methods^.NextPreOrder(Task);
        END;
    END;

END RollupResource;




BEGIN
END RollupResourceModule.


Notes on computing spent and to go ratios (CalcSpentAndToGo):

        When allocating the costs of a task in order to figure out how much
is spent (or will be) during the current period, and how much was and will be
spent in other periods, we invent or calculate a date called the "SpentDate".
All the spending on the task is presumed to occur before this date.

        There are several methods of computing this date, but for each task
it is a particular date.  What does not remain constant as we compute the
costs in this module are the boundary dates of the current period.  After all, 
the X-vs-time reports change time periods for every column.  Consequently,
we must continually calculate what proportion of the spending occurred between
the start and the end of the current period.   This reduces to the problem
of computing how much of the time that was spent occurred in the period as
a proportion of all time elapsed on the task.

         So, the general formula is:  


                SpentRatio = Duration Spent This Period
                            -----------------------------
                                  Duration Spent   


        But, there are numerous boundary conditions.   For this reason the
CalcSpentAndToGo procedure is complicated.

        First, it must handle milestones in a special way, since they have
no duration at all, and they might fall on the boundary of a time period, in
which case it is ambiguous into what period it goes.

        Second, it might be a baseline calculation.

        Third, tasks with spending shown might or might not actually have
dates that straddle the AsOfDate line.  We might have a task entirely in the
past with some expenses yet to go, or a future task that shows some costs
spent.  We need to deal with these differently from the more normal tasks
that only show partial spending when they also are partially complete.

        Fourth, there are numerous possibilities for a task with spending to
occur relative to the date boundaries of the current period.  These are
all computed within the calculation of the Duration Spent This Period, 
which is

        DurationSpentThisPeriod =

            Max( 0, Min( SpentDate, EndOfPeriod ) - Max( EarlyStart, StartOfPeriod ) )

        That is, we never spend less than zero time, and what time is spent
is from the EarlyStartDate of the task or the period, whichever comes later, 
and runs until the end of the SpentDate or the end of the period, whichever comes 
first.
    
        Alternatively, look at it as SpentDate - EarlyStart, clipped to the
boundaries of the period.

        That is how much time is spent in the period.  The total spent time
is SpentDate - EarlyStart, but NOT clipped to the boundaries of the period.

        There are, of course, some further boundary conditions to check:

        What if the task starts exactly at the start of the period, and 
the spent date is also the start of the period?  In this case, we have
EarlyStart = StartOfPeriod = SpentDate, so we will attempt to compute a
ratio of zero divided by zero.  For this reason, we test for SpentDuration
of zero explicitly, and in that case, put all the spending into the period
containing the start of the task.

