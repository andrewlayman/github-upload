IMPLEMENTATION MODULE V4Tasks;


(* MODIFICATION HISTORY:

        27-Jul-90 RSC   Upgraded from V3Tasks.
        16-Aug-90 RSC   Initialize task record first.
        12-Sep-90 RSC   Fixed for new Allocs.Def
         1-Nov-90 CL    Rename SuppressSlack to ForceCritical.
        21-Nov-90 AJL   Set the NoSoonerStart flag for Fixed tasks.
                        Set NoSoonerStart and NoLaterStart for Started
                        and Done tasks.
*)





FROM Allocs                 IMPORT
    (* TYPE *)                  ATask, AFixType, ATaskFlag, ARollupStatus,
                                ATaskStatus, ATaskFlagSet, AStartStatus,
    (* PROC *)                  InitializeTaskRecord;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle;

FROM LStrings               IMPORT
    (* PROC *)                  Copy;

FROM Text                   IMPORT
    (* TYPE *)                  AText;


PROCEDURE ConvertTaskFromV4 (   VAR OldTask         : ATaskV4;
                                VAR NewTask         : ATask     );
BEGIN
    InitializeTaskRecord( NewTask );

    WITH NewTask DO
        rectag                      := OldTask.rectag;
        TaskID                      := OldTask.TaskID;
        Copy (OldTask.taskname, taskname);
        DurationMethod              := OldTask.DurationMethod;
        duration                    := OldTask.duration;
        fixation                    := OldTask.fixation;
        scale                       := OldTask.scale;
        EffortScale                 := OldTask.EffortScale;
        priority                    := OldTask.priority;

        TaskFlags                   := OldTask.TaskFlags
                                       - ATaskFlagSet{
                                             DeferAlarms,          (* No more alarms for this task.    *)
                                             TaskRecentlyAdded,    (* Task added this session.         *)
                                             IsHeadNode,           (* Not a real task, is head of list.*)
                                             FrozenTask,           (* Always schedule at fixed date *)
                                             ForceCritical,        (* Force zero slack. *)
                                             NoSoonerStart,        (* Entered start date is lower bound. *)
                                             NoLaterStart,         (* Entered start date is upper bound. *)
                                             NoSoonerEnd,          (* Entered end date is lower bound. *)
                                             NoLaterEnd,           (* Entered end date is upper bound. *)
                                             TFS1,
                                             TFS2,
                                             TFS3,
                                             ShowSubMilestones,
                                             SelfContained};
        INCL(TaskFlags,PlanExists);

        IF (fixation = FixedDate) THEN
            TaskFlags := TaskFlags + ATaskFlagSet{ForceCritical,NoSoonerStart};
        END;

        FilterSet                   := OldTask.FilterSet;
        PercentComplete             := OldTask.PercentComplete;
        TaskStatusSet               := OldTask.TaskStatusSet;
        StartStatus                 := OldTask.StartStatus;

        IF (StartStatus <> FutureS) THEN
            TaskFlags := TaskFlags + ATaskFlagSet{NoSoonerStart,NoLaterStart};
        END;

        rollupstatus                := OldTask.rollupstatus;
        TaskSortOrder               := OldTask.TaskSortOrder;

        BaseLineSummary             := OldTask.BaseLineSummary;
        ToGoSummary                 := OldTask.ToGoSummary;
        CompletedSummary            := OldTask.CompletedSummary;

        BCWSDollars                 := OldTask.BCWSDollars;
        BCWP                        := OldTask.BCWP;

        IF (rollupstatus <> NotRollup) THEN
            rollupstatus := RollupNotLoaded;
        END;

        INCL (TaskStatusSet, NeedsRecalculate);
    END;

END ConvertTaskFromV4;



END V4Tasks.
