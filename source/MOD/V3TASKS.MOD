IMPLEMENTATION MODULE V3Tasks;



(* MODIFICATION HISTORY:

        16-Aug-90 RSC   Initialize task record first.
        12-Sep-90 RSC   Fixed for new Allocs.Def
        21-Nov-90 AJL   Set the NoSoonerStart flag for Fixed tasks.
                        Set NoSoonerStart and NoLaterStart for Started
                        and Done tasks.
                        For Fixed tasks, set the ForceCritical flag.
                        Remove DeferAlarms from all tasks.
*)


FROM Allocs                 IMPORT
    (* CONST *)                 WBSLine, OBSLine, AUXLine,
    (* TYPE *)                  ATask, AFixType, ATaskFlag, ARollupStatus,
                                ATaskStatus, ATaskFlagSet, AStartStatus,
    (* PROC *)                  SetCodingField, InitializeTaskRecord;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle;

FROM LStrings               IMPORT
    (* PROC *)                  Copy;

FROM Text                   IMPORT
    (* TYPE *)                  AText;


PROCEDURE ConvertTaskFromV3 (   VAR OldTask         : ATaskV3;
                                VAR NewTask         : ATask;
                                    CodingFields    : BOOLEAN   );

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
        EXCL(TaskFlags,DeferAlarms);        (* Enable Assist Update. *)

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

        EXCL(TaskFlags,DeferAlarms);        (* Enable alarm clock. *)

        IF (rollupstatus <> NotRollup) THEN
            rollupstatus := RollupNotLoaded;
        END;

        INCL (TaskStatusSet, NeedsRecalculate);
    END;

    IF (CodingFields) THEN
        SetCodingField (NewTask, WBSLine, OldTask.WBS);
        SetCodingField (NewTask, OBSLine, OldTask.OBS);
        SetCodingField (NewTask, AUXLine, OldTask.AUX);
    END;
END ConvertTaskFromV3;



END V3Tasks.
