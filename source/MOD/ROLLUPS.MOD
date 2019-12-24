(*V2=KILL pointers on unlock *)
(*V9=TRACE*)

(*<KILL*)  (*$T+*)  (*KILL>*)

IMPLEMENTATION MODULE Rollups;


(* MODIFICATION HISTORY

    01-Jan-88  AJL  - Set LDates to some useful value in RollupDates before
                      using it.
    11-Jan-88  AJL  - Use UnlockUnchangedDataObject.
     2-Feb-88  AJL  - Fill in the BCWP (new) field in each task record with the
                      full value of the PercentComplete * Budgetted Value.  This
                      is now accurate to many more digits than the former method
                      of only storing a percent complete as a cardinal number
                      in each task record. 
     8-Feb-88  AJL  - Allow Break out of rollup.
    10-Feb-88  AJL  - Add SStatus to the status set in Rollup AFTER it has
                      been computed.
    16-Feb-88  AJL  - Rearranged the order of SummTaskNodeAmounts inside 
                      RollupCosts so that they are computed, obtained and
                      aggregated in the correct order.
    22-Feb-88  RSC  - Ajust DEBUG toggles for ship.
    22-Feb-88  AJL  - Adjust KILL toggles for ship.
    15-Mar-88  AJL  - Rearrange the insides of RollupCosts so that both
                      baseline and plan are rolled up every time.  This is
                      needed because the baseline efforts get recalculated
                      inside ComputeTaskCosts, which is necessary because 
                      a change to calendar precision can throw off the baseline
                      efforts, requiring us to recompute them.  If we change
                      to a calendar that does not have changable internal 
                      representations for dates and durations, then it will
                      be possible to merely store the baseline data, not
                      recompute it each time. 
    16-Mar-88  AJL  - Fix an error from yesterday which was not rolling 
                      subtask baseline costs into the total task value.   
    27-Apr-89  AJL  - On rollup, done tasks with no baseline costs will
                      have their percent complete set to 100.
     3-May-89  AJL  - When rolling up dates, allow the duration of the 
                      parent to exceed the date range of the subtasks.  This
                      is useful when there are partial dependencies from the
                      start or to the end.
    25-Jul-89  AJL  - Changed RollupDates to keep better accounting of when a
                      list is empty. 
    18-Sep-89  AJL  - Removed the RollupDates procedure.   The Start and End
                      dates of summary tasks are no longer discovered by 
                      rolling up the dates of the children.  Instead, the 
                      TLPlan.ExpandSummaryDates takes the dates directly from
                      the start and end milestones' dates computed by the
                      scheduling process.  See the MOMTEST schedule for a test.  
     9-Nov-89  AJL  - Integrate date rollup into RollupCosts.
                    - Summary tasks with descendants will have their slack
                      dates computed based on the slack of their children.
    28-Nov-89  AJL  - Restored the Planned parameter.  It is used in the 
                      setting of baselines. 
    30-Mar-90  RSC    Made Timeu to Timei/TimeForm conversions.
    11-Apr-90  KKC    Replace all direct calculations on ADate and Duration
                      by calls to FindDuration, SubtractWorkingTime and
                      AddWorkingTime.
     9-Jul-90  AJL   -Moved flags.'
    24-Sep-90  DSL   -Split RollupCosts into RollPlan and RollBaseline. 
                      Split Rollup into RollupPlan and RollupBaseline. The 
                      "Planned" parameter is no longer necessary.
    14-Oct-90  AJL   -Removed LateIndStart and LateIndEnd from rollups.
                     -Remove RollupBaseline.
    11-Dec-90  AJL   -Allow the choice of the weighting given to tasks.
     8-Feb-91  AJL   -Added the RollEffort type.
     6-Mar-91  AJL   -Rollup the SupposedToStart value, and the
                      UserEnteredStartDate value.
    23-Sep-91  AJL   -Do not overwrite the costs and efforts computed
                      for detail tasks.
     3-Oct-91  AJL   -Add BCWS computations.  They somehow got removed
                      when Debra reorganized the code about a year ago.
                      I have implemented this in two parts for greater
                      schedule speed (through reduced locks): the BCWS
                      of detail tasks is computed in TLPlanEx before
                      calling these procedures.  We need only roll up
                      the BCWS of those into the summaries.
                     -If one chose any weighting method other than 
                      BCWS (RollBaseCost), we had been setting the
                      task's BCWP to the weighted value, not the 
                      PercentAchieved * BAC.
     3-Apr-92  AJL   -When Cost Tracking is off, spend for the user the proportion
                      of effort indicated by the percent achieved.
     6-Apr-92  AJL   -Since at least one of the performance measures (effort)
                      relies on a weighting factor computed in the 
                      SummarizePlan procedure, move it earlier.  Bug 5503.
                    
*)


FROM Allocs    IMPORT
    (* TYPE *)          ATask, ADateBlock, AnAssignmentSummary,
                        ATaskPtr,
                        AStartStatus, ATaskFlag, ATaskFlagSet, ARollupStatus,
                        ATempTaskFlag, ATempTaskFlagSet, 
                        ATaskStatusSet, ATaskStatus, ADurationMethod,
    (* VAR *)           TaskTree,
                        StartStatusName,
    (* PROC *)          CheckTaskValid;

FROM AsOf      IMPORT   AsOfDate;

FROM BigTimeU  IMPORT
    (* TYPE *)          ABigTime,
    (* VAR *)           MINBIGTIME, MAXBIGTIME,
    (* PROC *)          CompareBigTimes;

FROM CalShift  IMPORT   
    (* VAR  *)          TimeSheet;

FROM Changer   IMPORT
    (* VAR *)           UsesCostTracking;

FROM Dialog    IMPORT   Message, Error, FatalError, Burp;

FROM Duration  IMPORT   
    (* PROC *)          FindDuration;

FROM EffDone                    IMPORT
    (* PROC *)                     UpdateEffortToMatchRatio;

FROM Kbio      IMPORT   
    (* PROC *)          BreakRequested;


FROM Phantoms  IMPORT
    (* CONST *)         PhantomFlag;

FROM Planner   IMPORT
    (* TYPE *)          ARollupWeighting, 
    (* VAR *)           RecalcOptions, SomeBaselineExists; 

FROM RsrcCalc  IMPORT
    (* PROC *)          SummTaskNodeAmounts, ComputeTaskNodeCosts;

FROM Timei     IMPORT
    (* CONST*)      MinDate, MaxDate,
    (* TYPE *)      ADate, ADuration, ATimeInfo,
    (* PROC *)      DurationToReal;

FROM TreeObjects IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder,
    (* PROC *)          ValidateTree, ValidateTreeNode;

(*<TRACE
FROM BigTimeU               IMPORT
    (* PROC *)                  BigTimeToTimeInfo;
FROM FlexDisp IMPORT HandleToString;
FROM LStrings   IMPORT  Fill, ConcatS, ConcatLS, SetString, CtoS;
FROM RealFormat IMPORT
    (* VAR *)         DefaultAmountFormat, 
    (* PROC *)        FormatAsAmount;
FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;
FROM Tracer IMPORT PrintString, EndTrace;
FROM ResTrace IMPORT ConcatTaskID;
TRACE>*)




CONST
    MAXCARDINAL = 0FFFFH;
    Zero      = 0.0;
    OneHundred = 100.0;


VAR
    (*<TRACE
    TraceS : ARRAY [0..100] OF CHAR;
    TraceS2 : ARRAY [0..51] OF CHAR;
    TRACE>*)

    (*<TRACE
PROCEDURE FormatBigTime( B : ABigTime; VAR S : ARRAY OF CHAR );
VAR
    TimeInfo : ATimeInfo;
BEGIN
    BigTimeToTimeInfo(B,TimeInfo);
    TimeToString(TimeInfo,DefaultDateAndTimeFormat,S);
END FormatBigTime;
    TRACE>*)




PROCEDURE CostToDate(     Amount         : REAL;
                          TaskStart,
                          TaskEnd        : ADate   ) : REAL;
BEGIN
    IF (AsOfDate <= TaskStart) THEN
        RETURN Zero;
    ELSIF (TaskEnd <= AsOfDate) THEN
        RETURN Amount;
    ELSE
        RETURN ( FLOAT(AsOfDate-TaskStart) / FLOAT(TaskEnd-TaskStart) ) * Amount;
    END;
END CostToDate;

(*------------------- More generalized version
PROCEDURE CostToDate(     Amount         : REAL;
                          TaskStart,
                          TaskEnd        : ADate   ) : REAL;
VAR
    TmpDuration1, TmpDuration2 : ADuration;
BEGIN
    IF (AsOfDate <= TaskStart) THEN
        RETURN Zero;
    ELSIF (TaskEnd <= AsOfDate) THEN
        RETURN Amount;
    ELSE
        TmpDuration1 := FindDuration( TaskStart, AsOfDate, TimeSheet );
        TmpDuration2 := FindDuration( TaskStart, TaskEnd, TimeSheet );
        RETURN 
        ( 
            DurationToReal( TmpDuration1 ) 
                / 
            DurationToReal( TmpDuration2 )  
                * 
            Amount
        );
    END;
END CostToDate;
-------------------------------- *)



PROCEDURE MoveBack( VAR Early : ADate;  MaybeEarlier : ADate);
BEGIN
    IF MaybeEarlier  < Early THEN
        Early := MaybeEarlier;
    END;
END MoveBack;


PROCEDURE MoveForward( VAR Late : ADate;  MaybeLater : ADate);
BEGIN
    IF MaybeLater > Late THEN
        Late := MaybeLater;
    END;
END MoveForward;



PROCEDURE AdjustDateBlock( VAR Dates, Adjustment : ADateBlock );
BEGIN
    MoveBack(Dates.EarlyStart,Adjustment.EarlyStart);
    MoveForward(Dates.EarlyEnd, Adjustment.EarlyEnd);
    MoveBack(Dates.LateFreeStart,Adjustment.LateFreeStart);
    MoveForward(Dates.LateFreeEnd, Adjustment.LateFreeEnd);
    MoveBack(Dates.LateTotalStart,Adjustment.LateTotalStart);
    MoveForward(Dates.LateTotalEnd, Adjustment.LateTotalEnd);
END AdjustDateBlock;






(* DSL's Proposed new RollupPlan and RollupBaseline *)


PROCEDURE RollPlan     (       Tree            : ATree;     
                           VAR HasTasks        : BOOLEAN;   
                               Weighting       : ARollupWeighting;
                           VAR PlanCompleted,
                               PlanYetToGo     : AnAssignmentSummary;
                           VAR PercentComplete : REAL;
                           VAR BCWS            : REAL;
                           VAR Status          : AStartStatus;
                           VAR Dates           : ADateBlock;
                           VAR SupposedStart   : ABigTime;
                           VAR UserEnteredStart: ABigTime );

TYPE
    AStatusSet              = SET OF AStartStatus;

VAR Subtree                 : ATree;
    TaskNode                : ATreeNode;
    TaskPtr                 : ATaskPtr;

    PlanLCompleted,
    PlanLYetToGo,
    PlanSCompleted,
    PlanSYetToGo            : AnAssignmentSummary;
    UseRate,
    LPercentComplete,
    SPercentComplete,
    PercentThisTask,
    ValueSoFar,
    ValueThisTask,          (* from the set baseline eg. BAC *)
    BCWSThisTask,
    AchievedValueThisTask,
    WeightedValueSoFar      : REAL;              (* BCWP *)
    LTaskFlags              : ATaskFlagSet;
    LTempTaskFlags          : ATempTaskFlagSet;
    LStatus, SStatus        : AStartStatus;
    StatusSet               : AStatusSet;
    LDates, SDates          : ADateBlock;
    LSupposedStart,
    SSupposedStart          : ABigTime;
    LUserEnteredStart,
    SUserEnteredStart          : ABigTime;
    BaselineExistsFlag      : BOOLEAN;
    SHasTasks               : BOOLEAN;

    (* Most of the vars above are temporary space holders.
     * We try to minimize the amount of time that the Tree is locked.
     * So we store all sorts of task info and partial calulations
     * in parts of this very long var list.
     * NB:  L indicates local copy (this time through the recursion)
     *      S indicates that it holds the value from the subtree.
     *)




    (*____________________________________________________________________*)
    (*                                                                    *)
    (*            THIS IS WHERE THE SUB-SUBROUTINES BEGIN.                *)
    (*            THE DETAIL WORK OF THIS PROC GETS DONE UP HERE !!!      *)
    (*____________________________________________________________________*)

    (*___________________GET PLAN TASK INFO_________________________________*)


    PROCEDURE GetPlanTaskInfo( );

    BEGIN
        TaskPtr   := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        WITH TaskPtr^ DO
            LTaskFlags        := TaskFlags;
            LTempTaskFlags    := TempTaskFlags;
            BaselineExistsFlag:= (BaseLineExists IN LTaskFlags);
            UseRate           := FLOAT(PercentComplete)/OneHundred;
            LStatus           := StartStatus;
            LDates            := Plan.Dates;
            LSupposedStart    := SupposedToStart;
            LUserEnteredStart := UserEnteredStartDate;
            BCWSThisTask      := BCWSDollars;  (* Unless recomputed later. *)
        END;
        (*<TRACE
        SetString(TraceS,"    End GetPlanTaskInfo for task ");
        ConcatTaskID(TraceS,TaskPtr);
        ConcatS(TraceS,", LSupposedStart = ");
        FormatBigTime(LSupposedStart,TraceS2);   ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        TRACE>*)

        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );  
        TaskPtr := NIL;

    END GetPlanTaskInfo;


 
    (*___________________COMPUTE PERFORMANCE MEASURES____________________*)

    PROCEDURE ComputePerformanceMeasures();
    BEGIN
        (* Compute the performance measures such as AchievedValue (BCWP)
            and total value. *)

        CASE Weighting OF 
            RollBaseCost : 
                IF(BaselineExistsFlag) THEN
                    ValueThisTask  := TaskPtr^.BaseLineSummary.Amount;
                ELSE
                    ValueThisTask := Zero;
                END;
          | RollBaseEffort :
                IF(BaselineExistsFlag) THEN
                    ValueThisTask  := TaskPtr^.BaseLineSummary.Time;
                ELSE
                    ValueThisTask := Zero;
                END;
          | RollEffort : 
                ValueThisTask  := TaskPtr^.ToGoSummary.Time
                                  +TaskPtr^.CompletedSummary.Time;
          | RollDuration :
                ValueThisTask := FLOAT(TaskPtr^.duration);
          | RollOne :
                ValueThisTask := 1.0;   (* All tasks are equal. *)
        END;

        AchievedValueThisTask := (PercentThisTask * ValueThisTask);
        WeightedValueSoFar    := WeightedValueSoFar + AchievedValueThisTask;

        ValueSoFar            := ValueSoFar + ValueThisTask;

            (* Accumulate the Budgeted Cost of the Work Scheduled (BCWS)
               of all peer tasks so that we can return this amount. *)

        BCWS := BCWS + BCWSThisTask;

        INCL(StatusSet,LStatus);       (* Done, Future? *)

        (*<TRACE
        SetString(TraceS,"    Value of ");  ConcatTaskID(TraceS,TaskPtr);
        ConcatS(TraceS," = ");
        FormatAsAmount(ValueThisTask,DefaultAmountFormat,TraceS2,10,0,4,FALSE);
        ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        SetString(TraceS,"    Achieved Value = ");
        FormatAsAmount(AchievedValueThisTask,DefaultAmountFormat,TraceS2,10,0,4,FALSE);
        ConcatLS(TraceS,TraceS2);
        PrintString(TraceS);
        TRACE>*)

    END ComputePerformanceMeasures;




    (*__________________CHECK START STATUS_________________________________*)

    PROCEDURE CheckStartStatus();
    BEGIN
        (* Figure out this task's start status by checking for which one's
            were seen in child tasks. *)


        IF (StartedS IN StatusSet) OR
            (StatusSet = AStatusSet{FutureS,DoneS}) THEN
            Status := StartedS;
        ELSIF ( StatusSet = AStatusSet{DoneS}) THEN
            Status := DoneS;
        ELSE
            Status := FutureS;
        END;
    END CheckStartStatus;

    (*____________________________________________________________________*)

    PROCEDURE DoPlanSummaryTask;
    VAR
        SBCWS, LBCWS : REAL;     (* Subtask and local BCWS measurments. *)
        BaseLCompleted, BaseLYetToGo : AnAssignmentSummary;    (* Value w/o subtasks. *)
    BEGIN

        (* Recursively parse summary tasks. *)

            (* Find out what this task's baseline value is, exclusive
               of subtasks. *)

        IF (BaselineExistsFlag) THEN
            SummTaskNodeAmounts(   TaskNode,  TRUE,
                                   BaseLCompleted, BaseLYetToGo );
        END;

            (* Get costs and other measurements of subtasks. *)

        RollPlan(Subtree,        SHasTasks,    Weighting,
                 PlanSCompleted, PlanSYetToGo, SPercentComplete,
                 SBCWS,
                 SStatus,        SDates,
                 SSupposedStart, SUserEnteredStart
                );

        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

        WITH TaskPtr^ DO

            IF (SHasTasks) THEN              (* Avoid empty subtrees. *)
                (* eg: could have an "ATree" node
                    * which has no actual TreeNodes (tasks) 
                    * as children.
                    * So if your Subtree's subtree is non-empty, then
                    * your tree must have real tasks in it.
                    *  -dsl 14 Sept 90
                    *)
    
                HasTasks := TRUE;               (* A real task is seen. *)
    
                PercentThisTask := SPercentComplete;
                (* Keep full accuracy up the tree. *)
    
                LDates  := SDates;
                LSupposedStart    := SSupposedStart;
                LUserEnteredStart := SUserEnteredStart;
                LStatus := SStatus; 
    
                StartStatus     := SStatus;
                PercentComplete := TRUNC((SPercentComplete * OneHundred)+0.5);

                    (* When Cost Tracking is off, spend for the user the proportion
                       of effort indicated by the percent achieved.  *)

                IF (NOT UsesCostTracking) THEN
                    UpdateEffortToMatchRatio( TaskPtr^,
                                              SPercentComplete );
                END;


                    (* Some dates can be rolled up.  Others, such as the 
                       independent start and end, cannot be. *)
                WITH Plan.Dates DO
                    EarlyStart              := LDates.EarlyStart;
                    EarlyEnd                := LDates.EarlyEnd;
                    LateFreeStart           := LDates.LateFreeStart;
                    LateFreeEnd             := LDates.LateFreeEnd;
                    LateTotalStart          := LDates.LateTotalStart;
                    LateTotalEnd            := LDates.LateTotalEnd;
                END;
                SupposedToStart             := LSupposedStart;
                UserEnteredStartDate        := LUserEnteredStart;
                duration   := FindDuration
                                ( 
                                Plan.Dates.EarlyStart, 
                                Plan.Dates.EarlyEnd, 
                                TimeSheet
                                );

                (*<TRACE
                SetString(TraceS,"    Update task ");
                ConcatTaskID(TraceS,TaskPtr);
                ConcatS(TraceS,", SupposedToStart = ");
                FormatBigTime(SupposedToStart,TraceS2);   ConcatLS(TraceS,TraceS2);
                PrintString(TraceS);
                TRACE>*)
                (* Move the subtask computations into the task. *)

            END;

                (* If there is a baseline, compute the cost, and the value,
                   that should have been achieved to date.  We allow, however,
                   for the possibility that there might be baselines set for
                   subtasks even if the parent has no baseline. *)

            IF (BaselineExistsFlag) THEN
                LBCWS :=  CostToDate( BaseLCompleted.Amount + BaseLYetToGo.Amount,
                                      BaseLine.Dates.EarlyStart,
                                      BaseLine.Dates.EarlyEnd);
            ELSE
                LBCWS := Zero;
            END;
            BCWSDollars  :=  LBCWS + SBCWS;    (* Put the money into the task. *)
            BCWSThisTask :=  BCWSDollars;

        END;

            (* Get the local cost of this task (w/o subtasks). *)

        ComputeTaskNodeCosts( TaskNode );

        SummTaskNodeAmounts(TaskNode,  FALSE,
                            PlanLCompleted, PlanLYetToGo );

        TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode ); 
        TaskPtr := NIL;
    END DoPlanSummaryTask;
    (*___________________________________________________________________*)


    PROCEDURE DoPlanDetailTask();
    BEGIN


        HasTasks := TRUE;        (* A real task is seen. *)

        (* Add to this tree's expenses any that are listed in
            * the assignments for this task.
            *)

        SummTaskNodeAmounts(TaskNode,       FALSE,
                            PlanLCompleted, PlanLYetToGo );

        (* For a detail task, the subtask amounts are zero. *)

        PlanSCompleted.Amount := Zero;   
        PlanSYetToGo.Amount   := Zero;
        PlanSCompleted.Time   := Zero;   
        PlanSYetToGo.Time     := Zero;

        (* The percent achieved on a detail task is given explicitly.
         *)

        PercentThisTask   := UseRate;   (* PercentComplete/100.0 *)


    END DoPlanDetailTask;



    (*___________________________________________________________________*)

    PROCEDURE SetPercentComplete;
    BEGIN

        IF (ValueSoFar <> Zero) THEN
            PercentComplete := WeightedValueSoFar / ValueSoFar;
        ELSE
            (* The best that we can do, avoiding a division by zero. *)

            IF (Status = DoneS) THEN
                PercentComplete := 1.0;
            ELSE
                PercentComplete := Zero;
            END;   
        END;


    END SetPercentComplete;
    (*___________________________________________________________________*)

    PROCEDURE SummarizePlan( IsDetail : BOOLEAN );
    BEGIN
        (* Fill in the summary for each task. *)

        WITH TaskPtr^ DO
                (* For detail tasks, the procedures in TLPlanEx have
                   computed the costs and made any compromizes on
                   accuracy.  Don't second-guess them here. *)
            IF (NOT IsDetail) THEN
                CompletedSummary.Amount := PlanLCompleted.Amount
                                         + PlanSCompleted.Amount;
                CompletedSummary.Time   := PlanLCompleted.Time
                                         + PlanSCompleted.Time;
                ToGoSummary.Amount      := PlanLYetToGo.Amount
                                         + PlanSYetToGo.Amount;
                ToGoSummary.Time        := PlanLYetToGo.Time
                                         + PlanSYetToGo.Time;

                IF(BaselineExistsFlag) THEN
                    BCWP  := PercentThisTask * BaseLineSummary.Amount;
                ELSE
                    BCWP := Zero;
                END;
            END;

            (* Now add in the costs from this task to the accumulators. *)

            PlanCompleted.Amount := PlanCompleted.Amount 
                                  + CompletedSummary.Amount;
            PlanCompleted.Time   := PlanCompleted.Time   
                                  + CompletedSummary.Time;
            PlanYetToGo.Amount   := PlanYetToGo.Amount   
                                  + ToGoSummary.Amount;
            PlanYetToGo.Time     := PlanYetToGo.Time     
                                  + ToGoSummary.Time;
        

        END;
        
    END SummarizePlan;



    (*___________________________________________________________________*)



(*_____________________________*)
(*                             *)
(* LOGICAL START OF ROLLUPPLAN *)
(*_____________________________*)


BEGIN
    (*<TRACE
    SetString(TraceS,"Begin RollPlan");  
    ConcatS(TraceS,", SupposedStart = ");
    FormatBigTime(SupposedStart,TraceS2);   ConcatLS(TraceS,TraceS2);
    PrintString(TraceS);
    TRACE>*)


    InitializeVars(PlanCompleted, PlanYetToGo, BCWS, Dates, 
                   SupposedStart, UserEnteredStart    );

    ValueSoFar           := Zero;
    WeightedValueSoFar   := Zero;

    HasTasks := FALSE;       (* Remains false unless tree has tasks. *)

    StatusSet := AStatusSet{};


    (* Run through all of the tasks on this level of the tree.
       Compute the total of these task's costs plus the costs of
       any subtasks of these tasks.  Similarly, find the earliest
       and latest dates. 
     *)

    TaskNode := Tree^.Methods^.GetFirst(Tree); 

    WHILE (TaskNode <> NIL) AND (NOT BreakRequested()) DO

        (*<TRACE
        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        Fill(TraceS," ",2* TaskNode^.Methods^.IndentationLevel(TaskNode));
        ConcatS(TraceS,"WHILE ");  ConcatTaskID(TraceS,TaskPtr);
        PrintString(TraceS);
        TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
        TRACE>*)

        GetPlanTaskInfo();

        IF(NOT (PhantomFlag IN LTempTaskFlags)) THEN

            Subtree := TaskNode^.Methods^.GetSubtree(TaskNode);


            IF (Subtree <> NIL) THEN
                DoPlanSummaryTask();

            ELSE (* SubTree = NIL, therefore it's a Detail task *)

                DoPlanDetailTask();

            END;

                (* Adjust to record the minimum and maximum dates. *)

            AdjustDateBlock(Dates,LDates);

            IF (CompareBigTimes(LSupposedStart,SupposedStart)<0) THEN
                SupposedStart := LSupposedStart;
            END;

            IF (CompareBigTimes(LUserEnteredStart,UserEnteredStart)<0) THEN
                UserEnteredStart := LUserEnteredStart;
            END;
        
            (* LOCK *)           
            TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
            
            SummarizePlan( (Subtree = NIL) );

            ComputePerformanceMeasures();   (* After SummarizePlan, which
                                               can affect the weighting, e.g. Effort. *)

            TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
            (* UNLOCK *)           
            TaskPtr := NIL;

        END;

       TaskNode := TaskNode^.Methods^.GetNext(TaskNode);
       (* Next at this level *)

    END;

    CheckStartStatus();

    SetPercentComplete();
     

    (* If no tasks were in the tree, set all of the dates to 0. *)

    IF (NOT(HasTasks)) THEN
        WITH Dates DO
            EarlyStart     := MinDate;
            LateFreeStart  := MinDate;
            LateTotalStart := MinDate;
        END;
        SupposedStart      := MINBIGTIME;
        UserEnteredStart   := MINBIGTIME;
        Status := FutureS;
    END;


    (*<TRACE
    SetString(TraceS,"End RollPlan");  
    ConcatS(TraceS,", SupposedStart = ");
    FormatBigTime(SupposedStart,TraceS2);   ConcatLS(TraceS,TraceS2);
    PrintString(TraceS);
    TRACE>*)

END RollPlan;






PROCEDURE RollupPlan();
VAR
    LocalCompleted,
    LocalYetToGo         : AnAssignmentSummary;
    LocalPercentComplete : REAL;
    LocalBCWS            : REAL;
    LocalStatus          : AStartStatus;
    Dates                : ADateBlock;
    SupposedStart        : ABigTime;
    UserEnteredStart     : ABigTime;
    Weighting            : ARollupWeighting; 
    HasDates             : BOOLEAN; 
BEGIN

    (*<TRACE
    SetString(TraceS,"RollupPlan");  
    PrintString(TraceS);
    TRACE>*)

        (* Some of the weightings rely on the existence of a baseline.
           if there is no baseline, use a simpler measure. *)
    Weighting := RecalcOptions.RollupWeighting;
    IF (NOT SomeBaselineExists) AND (Weighting < RollDuration) THEN
        Weighting := RollOne;
    END;

    RollPlan(TaskTree, HasDates, Weighting,
             LocalCompleted, LocalYetToGo,
             LocalPercentComplete,
             LocalBCWS,
             LocalStatus,
             Dates, SupposedStart, UserEnteredStart );

    (*<TRACE
    EndTrace();
    TRACE>*)
    
END RollupPlan;









(*___________________INITIALIZE VARS_________________________________*)

PROCEDURE InitializeVars(VAR    Completed,
                                YetToGo   : AnAssignmentSummary;
                         VAR    BCWS      : REAL;
                         VAR    Dates     : ADateBlock;
                         VAR    SupposedStart,
                                UserEnteredStart : ABigTime );
BEGIN

    Completed.Amount := Zero;
    Completed.Time   := Zero;
    BCWS             := Zero;
    YetToGo          := Completed;
    SupposedStart    := MAXBIGTIME;
    UserEnteredStart := MAXBIGTIME;

    WITH Dates DO
        EarlyStart     := MaxDate;
        EarlyEnd       := MinDate;
        LateFreeStart  := MaxDate;
        LateFreeEnd    := MinDate;
        LateTotalStart := MaxDate;
        LateTotalEnd   := MinDate;
        LateIndStart   := MaxDate;
        LateIndEnd     := MinDate;
    END;

END InitializeVars;

END Rollups.




