IMPLEMENTATION MODULE Alarms;

    (* MODIFICATION HISTORY:

       3/3/86  AJL - Set a task to Fixed Date whenever Edit is chosen
                     from the Alarms menu and the proper start status
                     for the task would be Done or Started.
                   - The program used to set an task to FixedDate
                     only if (a) the proper StartStatus were Done, or
                     (b) the proper StartStatus were Started, the task
                     was ASAP and had no antecedants.  We now set it
                     to FixedDate if the proper StartStatus is Done
                     or Started, regardless or antecedants or type.
       03/10/86 LAA  Get text phrases from MsgFile, rather than embedding
                     them in the code.
       11/04/86 LAA  Changed CheckForClockTick to use AsOfDate rather than
                     Today; it was causing looping between the main menu and
                     Chart.windowc.  ChartState is now a set.
       11/11/86 LAA  Replaced an occurance of SetState(Formatted) with
                     UnSetState(Showing), because that's what's really needed.
       11/26/86 LAA  Removed reference to NeedsRecompute, whose function is
                     now handled by the chart state.
       12/04/86 LAA  A change to the StartStatus may affect the %complete.
                     Effected in FixTheDateAndStatus.
       03/23/87 EGK  Calls SetAsOfDate before running the alarms check.
       05/06/87 RSC  replace status references with TaskStatus.
       20-May-87 LAA Commented out CheckAlarms so the new Gantt chart would
                     work.  We need to re-think the way Alarms interacts with
                     the Gantt chart.
       22-May-87 LAA Commented out the FlagIt procedures so this will compile.
                     Due to changes in Chart procedures taking a tree node
                     instead of a task.
        5/22/87 EGK  Made changes to get tasks through the tree.
       04-Jun-87 LAA Changed TraverseTree calls for new parameters.
       22-Oct-87 EGK Removed the comments and got things working again.  Used
                     AsOfDate instead of Today.  In AppropriateStartStatus,
                     we just return the old start status if the times were equal.
       29-Oct-87 EGK Don't call FlagIt for summary tasks or tasks which link
                     to other schedules, since their status gets rolled up.
       11-Jan-88 LAA Changed UnlockFlexStorDataObject to UnlockUnchanged
                     where appropriate.
       16-Sep-88 RSC Fixed "TooLong" error in "FlagIt".
       29-Nov-88 EGK OpenAncestors sends notice (for network view).
       21-Dec-88 LAA Changed imports for Laslo reorganization.
        7-Feb-89 EGK Moved CheckAlarms into TLALARM overlay.
       14-May-89 AJL Removed CompareDates.
                     Gutted CheckAlarms. 
       16-Jun-89 AJL If the AsOfDate = the end date of the task, we will
                     suggest a start status of Done.  We used to suggest
                     Started.  
       21-Feb-90 KKC Remove import of Timeu.
       23-Jan-91 AJL Remove unused proc.
                     Add AsOf parameter to AppropriateStartStatus;
                     Removed unused imports and variables.
       25-Mar-91 AJL Take percent achieved and spent effort into account
                     when proposing start status for tasks.
    *)

FROM Allocs       IMPORT AStartStatus, AFixType,
                         ATask;

FROM Timei        IMPORT ADate, NoDuration;


VAR





PROCEDURE AppropriateStartStatus(VAR Task:ATask; AsOf:ADate):AStartStatus;
VAR
    StartDate, EndDate : ADate;
BEGIN
    WITH Task DO
        IF (
            ( duration = NoDuration ) 
            AND 
            ( AsOf = Plan.Dates.EarlyStart ) 
            AND 
            ( fixation <> FixedDate ) 
           ) THEN
            RETURN StartStatus;
        END;
        StartDate := Plan.Dates.EarlyStart;
        EndDate   := Plan.Dates.EarlyEnd;
            (*  Kick out the easy ones. *)
        IF (PercentComplete >= 100) THEN
            RETURN DoneS;
        ELSIF (AsOf <= StartDate) THEN
                (* If some work has been spent, or achievement registered,
                   then it is started or done. *)
            IF (CompletedSummary.Time > 0.0) OR (PercentComplete > 0) THEN
                RETURN StartedS;
            ELSE
                RETURN FutureS;
            END;
        ELSIF (AsOf >= EndDate) THEN
            RETURN DoneS;
        ELSE 
            RETURN StartedS;
        END;
    END;

    HALT;

END AppropriateStartStatus;





BEGIN
END Alarms.
