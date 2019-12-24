IMPLEMENTATION MODULE EffDone;

    (* ----------------------------------------------------------------

       EffDone -- Procedure(s) to help update the effort spent on tasks
                  automatically to equal the percent of work accomplished.
    
       MODIFICATION HISTORY:

       14-Nov-90  AJL -Initial version.
       13-Aug-91  AJL -Add Task parameter to UpdateEffortToMatchRatio. 
                       Update both the assignment efforts and the task
                       summaries.


       -----------------------------------------------------------------*)



FROM Allocs        IMPORT
    (* TYPE *)        ATask;

FROM Assignments   IMPORT
    (* TYPES *)       AnAssignmentRecord,
    (* PROCS *)       ForEachAssignment;

FROM FlexStor      IMPORT
    (* TYPE *)        AnExtHandle;

FROM LongConvert   IMPORT
    (* PROC *)        LongToReal, RealToLong;

FROM SYSTEM        IMPORT
    (* TYPE *)        ADDRESS,
    (* PROC *)        ADR;







PROCEDURE UpdateOneAssignment( VAR Assignment  : AnAssignmentRecord;
                                   Context     : ADDRESS ) : BOOLEAN;
VAR
    Ratio : POINTER TO REAL;
    Total : REAL;
    TotalLong : LONGINT;
BEGIN
    Ratio := Context;
    WITH Assignment DO
            (* Regular hours. *)
        Total := ActualQuantity + YetToGoQuantity;
        ActualQuantity := Total * Ratio^;
        YetToGoQuantity := Total - ActualQuantity;
            (* Overtime hours *)
        TotalLong := OvertimeHours + YetToGoOvertimeHours;
        OvertimeHours := RealToLong(LongToReal(TotalLong) * Ratio^);
        YetToGoOvertimeHours := TotalLong - OvertimeHours;
    END;
    RETURN TRUE; (* Keep going. *)
END UpdateOneAssignment;




    (*--------------------------------------------------------------

    UpdateEffortToMatchRatio

    Update each of the assignments in the Task's assignment
    array so that the amount of spent effort relative to the 
    total effort is equal to the passed Ratio, as closely as
    possible.

    Also update the CompletedSummary and ToGoSummary in the task.

    If the total effort is zero, the spent will also be zero.

    Input:  Task             -- Task to be updated.
            Ratio            -- Desired Spent/Total Effort ratio.


    --------------------------------------------------------------*)


PROCEDURE UpdateEffortToMatchRatio   ( VAR Task         : ATask;
                                           Ratio            : REAL );
VAR
    Total : REAL;
BEGIN
        (* Update the spent effort of each assignment. *)
    ForEachAssignment( Task.Plan.Assignments,
                       UpdateOneAssignment, ADR(Ratio));
        (* Update the spent effort of the task. *)
    WITH Task DO
        Total := CompletedSummary.Time + ToGoSummary.Time;
        CompletedSummary.Time := Total * Ratio;
        ToGoSummary.Time := Total - CompletedSummary.Time;
    END;
END UpdateEffortToMatchRatio;




END EffDone.
