IMPLEMENTATION MODULE ChartControl;

(*----------------------------------------------------------------------------
    MODIFICATION HISTORY
    
    11/04/86 LAA    Changed because the ChartState is now a set, rather than
                    an enumerated type.
    11/11/86 LAA    Created ClearState to implement the effect that setting
                    a chart state is intended to clear all successor states.
    11/12/86 LAA    Installed light to show when the schedule needs recalc.
    11/25/86 LAA    Modified for the new version of Lights.
    12/30/86 LAA    Expanded the size of the RecomputeLight because its now
                    also used the show the end date.  It was moved to the
                    DEF and exported.
     9/16/87 RSC    Changed init so light is not installed right away.
    21-Dec-88 LAA   Changed imports for Laslo reorganization.
    22-Dec-89 LAA   Set RecomputeLight to NIL so its initialized.
     8-Jul-90 AJL  -Added setting of the CalculationState to UnSetState.
                   -Spelling correction.
    18-Jun-91 AJL  -Update the CalcState and the RecomputeLight after each
                    call to SetState or UnsetState.
    16-Jul-91 LAA   Removed a local variable from UnSetState which is no
                    longer needed.  Also commented out the one call to
                    DisplayRecomputeLight, since the entire body of that
                    procedure is commented out.  Anybody know why it's still
                    in here?
----------------------------------------------------------------------------*)




FROM ChartMgr           IMPORT DisplayCurrentChart;

FROM Dialog             IMPORT FatalError;

FROM Kbio               IMPORT avidmode;

FROM Lights             IMPORT InstallLight, ActiveLightRegion, ALight,
                               DisplayLight;

FROM MsgFile            IMPORT GetMessage;

FROM Planner            IMPORT 
    (* TYPE *)                 ACalcComponent, AWhenToCalc, 
    (* VAR *)                  CalculationState;



CONST
    ModuleNumber            = 17000;
    RecomputeLightPriority  = 60;
    
VAR LightInstalled : BOOLEAN;




PROCEDURE ClearState(State                  : AChartState);

BEGIN                   (* ClearState *)

    CASE State OF
        Showing     :   EXCL(ChartState, Showing);
    |   Formatted   :   ClearState(Showing);
                        EXCL(ChartState, Formatted);
    |   Sorted      :   ClearState(Formatted);
                        EXCL(ChartState, Sorted);
    |   Filtered    :   ClearState(Formatted);
                        EXCL(ChartState, Filtered);
    |   Scheduled   :       (* Need to attempt recalc before redisplay. *)
                        ClearState(Sorted);
                        ClearState(Filtered);
                        EXCL(ChartState, Scheduled);
    ELSE
        FatalError();
    END;                

END ClearState;


PROCEDURE Track();
BEGIN
    IF (NOT (Scheduled IN ChartState)) THEN
            (* The schedule needs recalc. *)
        CalculationState[Scheduling].DataIsValid := FALSE;
    END;
    (* DisplayRecomputeLight(); *)                             (* 16-Jul-91 *)
END Track;



PROCEDURE SetState (State:AChartState);
BEGIN
    ClearState(State);
    INCL(ChartState, State);
    Track();
END SetState;





PROCEDURE UnSetState (State:AChartState);
BEGIN
    ClearState(State);
    Track();
END UnSetState;


(*
PROCEDURE DisplayRecomputeLight();

VAR
    s                       : ARRAY [0..31] OF CHAR;

BEGIN                       (* DisplayRecomputeLight *)
    
    IF (LightInstalled) THEN
        IF NOT (Scheduled IN ChartState) THEN
            GetMessage(ModuleNumber, s);                       (* Recalc *)
            DisplayLight(RecomputeLight, s, videolights);
        END;
    END;
    
END DisplayRecomputeLight;
*)


PROCEDURE DisplayTheChart;
BEGIN
    IF (NOT LightInstalled) THEN
        InstallLight(ActiveLightRegion, RecomputeLightPriority, 10, 23, RecomputeLight); (* 12/30/86 LAA *)
        LightInstalled := TRUE;
    END;
    DisplayCurrentChart;
END DisplayTheChart;


BEGIN
    LightInstalled := FALSE;
    RecomputeLight := ALight(NIL);
    ChartState := AChartStateSet{Formatted,Sorted,Filtered,Scheduled};
END ChartControl.
