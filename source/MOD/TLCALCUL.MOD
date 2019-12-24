MODULE TLCalcul;

(*  =========================================================================
    Last Edit : October 24, 1990 3:04PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Support for Calculations form        

    MODIFICATION HISTORY:

    31-Jul-90 PFG   Created to support new Calculations form.  Recalc info
                    removed from Schedule Options form.
    16-Aug-90 RSC   Moved the form up and over a little.
    29-Aug-90 AJL   Added the FreezeStartedTasks option.
     9-Sep-90 AJL   Rename FreezeStartedTasks to KeepEffortContiguous.
    23-Sep-90 AJL   We changed the phrasing on the form for the KeepEffortContiguous
                    flag, so we need to change the sense of the boolean.
    23-Oct-90 PFG   Made changes to form as per 4.5 prototype review.  Added
                    "Calculate Negative Slack."  Moved "Force Future Tasks..."
                    and "Highest Priority" here from Options form.  Other
                    cosmetic changes.
     8-Feb-91 AJL   Added the rollup weighting field.
     5-Mar-91 AJL   Removed the OverbookCheck field.
    =========================================================================
*)



FROM ChartControl IMPORT  
    (* TYPE *)              AChartState,
    (* VAR *)               ChartState,
    (* PROC *)              UnSetState;

FROM Codes        IMPORT  
    (* TYPE *)              ACode;

FROM Dialog       IMPORT 
    (* PROC *)              FatalError;

FROM FormCon      IMPORT  
    (* TYPE *)              AFieldNo;

FROM Forms        IMPORT  
    (* TYPE *)              AFieldValue, ACheckReason, AStringValue, AForm,
    (* PROC *)              DoForm, NullCheckProc; 

FROM Kbio         IMPORT  
    (* CONST *)             maxcol, maxrow;

FROM Keys         IMPORT  
    (* CONST *)             ExitKey;

FROM Layout       IMPORT  
    (* CONST *)             GanttWEnd;

FROM Overlays     IMPORT
    (* TYPE *)              AnOverlayID,
    (* PROC *)              ImAnInstallableOverlay;

FROM OvTree       IMPORT
    (* TYPE *)              AnOverlayProc;

FROM Planner      IMPORT 
    (* TYPE *)              ACalcComponent, ACalculationState, AWhenToCalc,
                            ARollupWeighting,
    (* VAR *)               CalculationState, Levelling, TimeConstrained,
                            HonorDaysOff, MoveFutureTasks, RecalcOptions,
                            KeepEffortContiguous;

FROM Schedule     IMPORT
    (* VAR *)               ScheduleSaved, ConfigSaved, ZeroIsLowestPriority;


CONST
    ModuleNumber = 13600;

    REC  =  0;           (* Recalc: Auto, Manual *)
    FFT  =  1;           (* Force Future Tasks After As-of Date: No, Yes *)
    CNS  =  2;           (* Calculate Negative Slack: No, Yes *)
    HDO  =  3;           (* Honor Days Off: No, Yes *)
    SST  =  4;           (* Separate Spent/To Go Effort: No, Yes *)
    LEV  =  5;           (* Leveling: No, Yes, Within Slack *)
    PRI  =  6;           (* Highest Priority: (0, 999.9) *)
    WGT  =  7;
    TopField = 7;        (* Highest numbered field. *)
    
    (* Responses to Resource Leveling field: *)

    NoLeveling  =   0;
    YesLeveling =   1; 
    WithinSlack =   2;  


VAR
    OverlayID               : AnOverlayID;




PROCEDURE DoCalculationsForm;

CONST
    FormNumber  = 73;       (* Form in CALCFORM.MOD *)
    Auto        = 0;
    Manual      = 1;
    Never       = 2;
    No          = 0;
    Yes         = 1;

VAR
    NewLevel                : CARDINAL;
    OldPlanningMethod       : CARDINAL;
    i                       : CARDINAL;
    Code                    : ACode;
    SomethingChanged        : BOOLEAN;
    FormValue               : ARRAY [0..TopField] OF AFieldValue;
    OldValues               : ARRAY [0..TopField] OF CARDINAL;
    Copyright               : ARRAY[0..50] OF CHAR;

BEGIN       (* DoCalculationsForm *)

    Copyright := "Program Copyright (c) 1990 Symantec Corporation.";

    IF (NOT Levelling) THEN
        OldPlanningMethod := NoLeveling;
    ELSE
        IF (TimeConstrained) THEN
           OldPlanningMethod := WithinSlack; 
        ELSE
           OldPlanningMethod := YesLeveling; 
        END;
    END;

    (* Set default values: *)

    FormValue[REC].CardValue := ORD(CalculationState[Scheduling].When);
    FormValue[FFT].CardValue := ORD(MoveFutureTasks);
    FormValue[CNS].CardValue := ORD(RecalcOptions.AllowNegativeSlack);  (* 24-Oct-90 PFG *)
    FormValue[HDO].CardValue := ORD(HonorDaysOff);
    FormValue[SST].CardValue := ORD(NOT KeepEffortContiguous);
    FormValue[LEV].CardValue := OldPlanningMethod;
    FormValue[PRI].CardValue := ORD(ZeroIsLowestPriority);
    FormValue[WGT].CardValue := ORD(RecalcOptions.RollupWeighting);

        (* Save previous choices. *)

    FOR i := 0 TO TopField DO
        OldValues[i] := FormValue[i].CardValue;
    END;

    Code := DoForm (7, 0, maxcol, GanttWEnd-4, FormNumber, TRUE, FormValue,
            NullCheckProc);

    IF (Code = ExitKey) THEN

        CalculationState[Scheduling].When := VAL(AWhenToCalc,FormValue[REC].CardValue);

        NewLevel := FormValue[LEV].CardValue;
        CASE NewLevel OF

               NoLeveling   : Levelling := FALSE;

            |  YesLeveling  : Levelling := TRUE;
                              TimeConstrained := FALSE;    

            |  WithinSlack  : Levelling := TRUE;
                              TimeConstrained := TRUE;

            ELSE FatalError();
        END;    

        HonorDaysOff := FormValue[HDO].CardValue > 0;
        KeepEffortContiguous := FormValue[SST].CardValue = 0;
        MoveFutureTasks      := VAL(BOOLEAN,FormValue[FFT].CardValue);
        ZeroIsLowestPriority := VAL(BOOLEAN, FormValue[PRI].CardValue);
        RecalcOptions.AllowNegativeSlack 
                       := VAL(BOOLEAN, FormValue[CNS].CardValue);
        RecalcOptions.RollupWeighting 
                       := VAL(ARollupWeighting, FormValue[WGT].CardValue);

            (* Set the flags so the schedule and the config need to be saved.
               Check whether anything that should cause a recalc was changed, and
               if so, set the recalc state. *)

        SomethingChanged := FALSE;
        FOR i := 0 TO TopField DO
            IF OldValues[i] <> FormValue[i].CardValue THEN
                SomethingChanged := TRUE;
                IF (i IN {REC}) THEN
                    IF (FormValue[i].CardValue = Auto) THEN
                        UnSetState(Scheduled);
                    END;
                ELSE
                    UnSetState(Scheduled);
                END;
            END;
        END;

        IF (SomethingChanged) THEN
            ScheduleSaved    := FALSE;
            ConfigSaved      := FALSE;
            UnSetState (Formatted);
        END;


    END;

END DoCalculationsForm;


BEGIN           (* TLCalcul *)

    OverlayID := ImAnInstallableOverlay(DoCalculationsForm, 
                                        AnOverlayProc(NIL));
    DoCalculationsForm();

END TLCalcul.


