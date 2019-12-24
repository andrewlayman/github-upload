IMPLEMENTATION MODULE Planner;

    (* Modification History:

        RSC     1/4/89  Added ScheduleStartDate.
        AJL  20 Apr 89  Added new variables, TimeConstrained and Smoothing.   
        AJL  24 May 89  Initialize MoveFutureTasks.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        31-May-90 AJL   Changed the exported variables.  Eliminated the
                        PlanLevel stuff, and added new options.
        19-Jun-90 AJL   Check that TaskTree is not NIL before recalc.
        29-Aug-90 AJL   Added the FreezeStartedTasks option.
         9-Sep-90 AJL   Rename FreezeStartedTasks to KeepEffortContiguous.
         3-Oct-90 AJL   Added a record containing uncommitted flags,
                        RecalcOptions.
        15-Nov-90 AJL   Changed the default for KeepEffortContiguous to 
                        FALSE.
                        Changed the name of the Init proc to ResetPlannerDefaults.
        11-Dec-90 AJL   Initialize RollupWeighting.
         8-Jan-91 AJL   Changed the ResetPlannerDefaults proc so that it
                        does not change the settings on the Calculations
                        form.
         8-Feb-91 AJL  -Added the RollEffort type.
        28-Aug-91 PFG  -Changed the ResetPlannerDefaults proc again.  It was
                        resetting the When field to AutoCalc, regardless of
                        the setting on the Calculations form.
                    
    *)

FROM Allocs                 IMPORT
    (* VAR *)                   TaskTree;
    
FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

FROM Timei                  IMPORT
    (* CONST*)                  MinDate,
    (* TYPE *)                  ADate;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree;

(*<TRACE
FROM Dialog IMPORT NotYetImplemented;
TRACE>*)

VAR
    i : CARDINAL;
    CalcComponent : ACalcComponent;


PROCEDURE Pert(   Start     : ADate;
                  WhenIsThis: AWhenToCalc):BOOLEAN;

VAR
    PlannerContext          : APlannerContextRecord;
    s                       : ARRAY [0..9] OF CHAR;
BEGIN
    WITH PlannerContext DO
        Tag := 3800;
        StartDate := Start;
        DoAllSteps := (WhenIsThis = ManualCalc);
    END;

    SetString(s, "|TLPLAN");
    IF (NOT CallOverlayWithContext(s, ADR(PlannerContext))) THEN
        PlannerContext.Computed := FALSE;
        ScheduleComputedOk := FALSE;
    END;

    RETURN PlannerContext.Computed;


END Pert;




PROCEDURE WeShouldRecalc( VAR CalculationState : ACalculationState;
                              WhenIsThis: AWhenToCalc):BOOLEAN;
VAR
    CalcComponent : ACalcComponent;
    ManualRequest : BOOLEAN;
BEGIN
    IF (TaskTree^.Methods^.GetFirst (TaskTree) = NIL) THEN
        RETURN FALSE;
    END;

        (* If recalc failed, redo it. *)
    IF (NOT ScheduleComputedOk) THEN RETURN TRUE; END;

        (* If any step of the calculation needs to be done, and is 
           to be done automatically, do recalc.   Similarly, if this
           is an explicit request to recalc, do so if the calc 
           needs doing. *)

    ManualRequest := (WhenIsThis = ManualCalc);

    FOR CalcComponent := MIN(ACalcComponent) TO MAX(ACalcComponent) DO
        WITH CalculationState[CalcComponent] DO
            IF (NOT DataIsValid) THEN
                CASE When OF
                    AutoCalc:   RETURN TRUE;
                  | ManualCalc: IF (ManualRequest) THEN RETURN TRUE; END;
                  ELSE;
                END;
            END;
        END;
    END;

    RETURN FALSE;
END WeShouldRecalc;




PROCEDURE ResetPlannerDefaults;
VAR
    CalcComponent : ACalcComponent;
BEGIN
        (* Everything is ok, because there is no data to calc yet! *)
    FOR CalcComponent := MIN(ACalcComponent) TO MAX(ACalcComponent) DO
        WITH CalculationState[CalcComponent] DO
            DataIsValid := TRUE;
            Abandoned := FALSE;
            Filler := FALSE;
        END;
    END;

    ScheduleComputedOk := TRUE;
    ScheduleEndDate    := MinDate;
    ScheduleStartDate  := MinDate;            (* RSC 1/4/89 *)

END ResetPlannerDefaults;


BEGIN
    Levelling          := TRUE;
    TimeConstrained    := FALSE;
    HonorDaysOff       := TRUE;
    MoveFutureTasks    := TRUE;
    KeepEffortContiguous := FALSE;             (* 4.0 compatability. *)
    WITH RecalcOptions DO
        AllowNegativeSlack := FALSE;
        Smoothing          := FALSE;
        RollupWeighting    := RollBaseCost;
        FOR i := 0 TO HIGH(Filler) DO
            Filler[i] := FALSE;
        END;
    END;

    (*  This used to be done in ResetPlannerDefaults.  Move it here so it
        doesn't get done again once the program's been loaded.  *)

    FOR CalcComponent := MIN(ACalcComponent) TO MAX(ACalcComponent) DO
        CalculationState[CalcComponent].When := AutoCalc;
    END;

    ResetPlannerDefaults();
END Planner.



