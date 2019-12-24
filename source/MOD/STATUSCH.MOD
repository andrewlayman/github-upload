IMPLEMENTATION MODULE StatusChange;

(* Status Change    - Manage task status changes.

    When a task becomes Done,

        For resource assignments and variable costs:

            For duration-driven tasks, we may need to change
            assignments to effort driven, and adjust percentages so that the
            spent and planned efforts are the same on each.

            For effort-driven tasks, we need to verify that the total of the 
            spent effort on the assignments matches the task total.

            For assignment-driven tasks, we may need to adjust the 
            assignments so that the spent and planned efforts are the same
            on each.

        For other assignments:

            We may need to change the total assigned to match the actual
            completed amount.


    Modification History:

    16-May-89 RSC First version, based on ideas by Andrew.
    23-May-89 RSC Correct the computed percentages.
                  Also, fix tasks where YTG <> 0, not YTG > 0.
     1-Jun-89 RSC Import AnAssignmentPointer from Assignme, not RsrcCalc.
                  Also, check "UsesCostTracking" rather than
                  "AdvancedTaskForm".
     8-Jun-89 RSC When the customer does NOT use cost tracking, instead of
                  setting TOTALS := SPENT, set SPENT := TOTALS when the
                  task becomes "Done".
    21-Jun-89 AJL If the spent is zero and the plan isn't, confirm
                  before setting the plan to spent.  This modifies the
                  default dialog procedure.
     5-Sep-89 RSC Initialize StatusDialogResponse to "AllowCondition".
                  This fixes a bug were, on the task form, Future or Done
                  tasks with no errors sometimes just beeped at you when
                  you tried to exit.
    30-Mar-90 RSC Made Timeu to Timei/TimeForm conversions.
    27-Aug-90 RSC Ajust for no assignments in trees.
     1-Nov-90 CL  Rename ResourceDriven to EffortDriven.
    28-Dec-90 AJL -New edit rules permit done tasks to remain effort or 
                   assignment driven, and for effort-driven tasks allow 
                   the spent effort on each assignment to differ from the
                   planned amount, so long as the total of the spent effort
                   on the assignments equals the task total.
                  -Include overtime hours in the calculations of spent 
                   hours, and set to go overtime hours to zero.
                  -Do not change the effort or percent assigned to the 
                   assignments of assignment-driven tasks.
    29-Dec-90 AJL -Arithmetic fixes to overtime computations.
    04-Jan-91 TGS -Effort driven tasks must have Estimated effort greater
                   than or equal to entered Spent efforts.
    29-Apr-91 TGS -Added 2 AssignmentSummary parameters to CheckTaskEfforts.
                   Copy the Task record's Completed- and ToGoSummary to these
                   to make it easier to pass them back to the caller.
    18-Jun-91 TGS -When checking spent task efforts, ignore cost quantities.     
    12-Aug-91 AJL -Expanded the AStatusDialogResponse to distinguish 
                   CancelRemainingEffort from SpendRemainingEffort.  Formerly,
                   these were combined into FixTheTask.
                  -Replace calls to FatalError with calls to ErrorPhrase.
    17-Sep-91 AJL -GlomOnResources had been multiplying the effort hours on
                   assignments by FSMUPH (following the inaccurate documentation
                   for the LongDurationToString procedure).  Bug 5138.
    19-Sep-91 TGS   Turn off optimization around dereference of asgnmt ptr.
    31-Jan-91 LAA -In MakeAssignmentRateMatchTotal, I removed old code which
                   would change the NumberAt and the percentage to get the
                   best match for MaxRatePercent.  This was undesirable, 
                   particularly in light of our allowing decimals in the
                   NumberAt field on the assignment form.  I also ensured
                   that MaxRatePercent will always equal NumberAt * percent.
     1-Apr-92 TGS   Interface to LongDurationToString changed.
*)


FROM Allocs         IMPORT
    (* TYPE *)          ATaskPtr, AStartStatus, ARollupStatus,
                        ADurationMethod, AnAssignmentSummary;

FROM Assignments    IMPORT
    (* TYPE *)          AnAssignmentRecord,
                        AnAssignmentAttribute,
                        AnAssignmentAttributeSet,
                        AnAssignmentPointer,
                        AnAssignmentArray;

FROM Changer        IMPORT
    (* VARS *)          UsesCostTracking;

FROM Dialog         IMPORT
    (* TYPES *)         ADialogOption,
    (* PROCS *)         MultipleChoiceBox, ContinuationBox, WarningBox,
                        FatalError, ErrorPhrase;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtHandle,
    (* PROC *)          LockObjectArray, ReleaseObject,
                        ReleaseUnchangedObject;

FROM LongConvert    IMPORT
    (* PROC *)          LongToReal;

FROM LongDuration           IMPORT
    (* PROC *)                  LongDurationToString;

FROM LStrings       IMPORT
    (* PROCS *)         LengthOf, ConcatS, ConcatLS, Copy, TrimRear;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM RealFormat     IMPORT
    (* VAR *)           DefaultAmountFormat, DefaultCurrencyFormat,
    (* PROC *)          FormatAsAmount, FormatAsCurrency;

FROM RsrcCalc       IMPORT
    (* PROC *)          ComputeTaskNodeCosts;

FROM RsrcMod        IMPORT
    (* TYPE *)          ACostStyle, AResourceType, AResourcePointer;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS, TSIZE;

FROM Text           IMPORT
    (* TYPE *)          AText;

FROM Timei          IMPORT
    (* CONST*)          NoDuration,
    (* TYPE *)          ADuration, ADurationUnit,
    (* PROG *)          DurationToReal;

FROM Timeu          IMPORT
    (* VAR *)           FSMUPH;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATreeNode;



CONST
    Zero            = 0.0;
    MAXCARDINAL     = 65535;
    FMAXCARDINAL    = 65535.0;


    ModuleNumber    = 5200;

TYPE
    AResponseSet = SET OF AStatusDialogResponse;





(* Make Assignment Rate Match Total

    Ajust an assignment record's rate match the total effort.
    Only has an effect on Resources and Variable Costs.

    Preconditions
    Postconditions
                    Assignment record may have been ajusted, or else
                    FALSE is returned.

                    FALSE is possible because:

                        The assignment cannot be made that large;
                        More than 260 @ 250%
*)
PROCEDURE MakeAssignmentRateMatchTotal( VAR Assignment      : AnAssignmentRecord;
                                            TaskDuration    : ADuration
                                      ) : BOOLEAN;
CONST
    MaxPercent      = 250;
    MaxNumber       = 65535 DIV MaxPercent;
    MaxRate         = MaxNumber * MaxPercent;
VAR
    i, j,
    BestDifference,
    Besti,
    NewRate,
    OldNumber           : CARDINAL;
    AssignmentRate,
    TaskEffort          : REAL;

BEGIN

    WITH Assignment DO
        IF (Resource^.CostStyle = CAmountRateTime) THEN


            (* Find the new rate.
            *)
            IF (TaskDuration = NoDuration) THEN
                NewRate        := 0;
            ELSE
                TaskEffort     := DurationToReal( TaskDuration ) / FSMUPH;
                AssignmentRate := (((YetToGoQuantity + ActualQuantity)
                                   / TaskEffort) * 100.0) + 0.5;
                IF (AssignmentRate > FLOAT(MaxRate)) THEN
                    PercentageEach := CHR(MaxPercent);
                    MaxRatePercent := MaxRate;
                    RETURN FALSE;
                END;
                NewRate := TRUNC(AssignmentRate);
            END;


            (* If the new rate = old rate, then keep things the way they are.
               Otherwise, try to find a new percentage.

               If the Old number works, keep it.
            *)
            IF (NewRate <> MaxRatePercent) THEN
                IF (PercentageEach <> 0C) THEN
                    OldNumber := MaxRatePercent DIV ORD(PercentageEach);
                    IF ((OldNumber <> 0) AND 
                       ((NewRate DIV OldNumber) <= MaxPercent)) THEN
                        PercentageEach := CHR(NewRate DIV OldNumber);
                        MaxRatePercent := OldNumber * ORD(PercentageEach);
                        RETURN TRUE;
                    END;
                END;
                MaxRatePercent := NewRate;
            END;

                (*------------------------------------------------------------
                    Old code.  This was before we changed the 
                    VaryingAssignments to be LONGINT's and allowed decimals 
                    in the Number at.                                31-Jan-92
        
                IF (PercentageEach <> 0C) THEN
                    OldNumber := MaxRatePercent DIV ORD(PercentageEach);
                    IF ((OldNumber <> 0) AND
                       ((NewRate MOD OldNumber) = 0) AND
                       ((NewRate DIV OldNumber) <= MaxPercent)) THEN
                        PercentageEach := CHR(NewRate DIV OldNumber);
                        MaxRatePercent := NewRate;
                        RETURN TRUE;
                    END;
                END;


                (* Compute the best (HIGHEST) percentage for this rate.
                   Start at the MIN( HighestPercentageAllowed, NewRate ).
                *)
                MaxRatePercent := NewRate;
                i              := MaxPercent;
                IF (i >  MaxRatePercent) THEN
                    i := MaxRatePercent;
                END;


                (* Look for a percentage that devides evenly into the rate.
                   barring that, find the nearest fit.
                *)
                BestDifference := NewRate;
                Besti          := i;
                WHILE (i > 0) AND
                        ((MaxRatePercent MOD i) <> 0) DO
                    j := (MaxRatePercent MOD i);
                    IF (j < BestDifference) THEN
                        BestDifference := j;
                        Besti          := i;
                    END;
                    DEC(i);
                END;


                (* See if we met our goal.
                   If i is zero, then we found no even devisors, OR
                       i started out as zero.
                   Otherwise, i is ok.
                *)
                IF (i = 0) THEN
                    PercentageEach := CHR(Besti);
                ELSE
                    PercentageEach := CHR(i);
                END;
                ------------------------------------------------------------*)
        END;
    END;

    RETURN TRUE;

END MakeAssignmentRateMatchTotal;





    (* RepairTheAssignments -- Make the assignments have all their
                               effort and costs spent. 
    *)

PROCEDURE RepairTheAssignments( VAR Assignments : AnAssignmentArray;
                                    Count       : CARDINAL; 
                                    DurationMethod : ADurationMethod;
                                    TaskDuration   : ADuration;
                                    RepairMethod   : AStatusDialogResponse
                              );
VAR
    i : CARDINAL;
    ok : BOOLEAN;
BEGIN

    (*$O-*)
    FOR i := 0 TO Count-1 DO
        WITH Assignments^[i] DO

            IF (RepairMethod = CancelRemainingEffort) (* COST TRACKING *) THEN


                (* Cost tracking is on, so presumably the user has entered
                   the actual amounts of time and other costs spent on the 
                   task.
                
                   Mark the work with TOTAL := SPENT.  For resources and
                   var costs, make the RATE of assignment match total effort.
                   This loop handles all updating except the assignments of 
                   employable resources to effort-driven tasks.
                *)

                IF ((DurationMethod <> EffortDriven)
                    OR
                    (Resource^.Type = AccountingOnly)
                   )THEN

                    IF (YetToGoQuantity <> Zero)  THEN
                        YetToGoQuantity := Zero;
                            (* If this is a resource or a variable cost,
                               make sure that it is marked on the asignment
                               form as though the total amount of effort
                               was what was entered, and change the rate
                               as necessary so the rate * duration = effort. 
                               *)
                        IF (DurationMethod = DurationDriven) 
                           AND
                           (Resource^.CostStyle = CAmountRateTime) THEN
                            INCL( Attributes, ComputeByHours );
                            ok := MakeAssignmentRateMatchTotal( Assignments^[i],
                                                                TaskDuration );
                            IF (NOT ok) THEN
                                ErrorPhrase(ModuleNumber+11);
                            END;
                        END;
                    END;

                END;


                (* Overtime hours are not stored as Spent and ToGo, but
                   rather as Total and ToGo, so, to set the total to
                   the spent amount, we set the total to itself, less the
                   amount that is not spent.
                   *)
                OvertimeHours := OvertimeHours - YetToGoOvertimeHours;
            ELSE
                (* Cost tracking is off, or they have chosen to duplicate
                   the behavior that is the default for off cost tracking.
                   Presumably they have not entered
                   any costs on the task, so change the assignments to say that
                   they actually spent whatever amount they had planned to.
                   Since they cannot change things, make SPENT:=TOTAL.
                   Added 8-Jun-89 by RSC.
                *)
                ActualQuantity  := ActualQuantity + YetToGoQuantity;

                (* Note by AJL, 12/28/90: We could perhaps improve this
                   estimate by seeing if there is a varying assignment
                   profile for the task, and, if so, seeing how much effort
                   was actually scheduled to be spent.  The descrepency
                   for effort-driven tasks could be large. *)

            END;

            (* Regardless of the type of task or assignment, there
               is no more to-go effort, because the task is Done.
            *)
            YetToGoQuantity := Zero;
            YetToGoOvertimeHours := 0L;

        END;
    END;

    (*$O=*)

END RepairTheAssignments;






(* Check Status Change

    Check the passed task, checking assignments for consistency with the
    task status.

    Preconditions
                    TaskNode            The task to check.
                    NextAssignmentProc  The way of getting assignment records.
                    StatusDialogProc    The way of getting answers to our
                                        queries.
    Postconditions
                    RETURN              TRUE  Task is ok.
                                        FALSE More editing is called for.
*)
PROCEDURE CheckStatusChange(     TaskNode           : ATreeNode;
                                 StatusDialogProc   : AStatusDialogProc
                           ) : BOOLEAN;
VAR
    TaskPtr                 : ATaskPtr;
    AssignmentHandle        : AnExtHandle;
    Assignments             : AnAssignmentArray;
    TaskDuration            : ADuration;
    Count,
    i                       : CARDINAL;
    LocalStartStatus        : AStartStatus;
    StatusDialogResponse    : AStatusDialogResponse;
    LocalDurationMethod     : ADurationMethod;
    Text,
    Menu                    : ARRAY [0..255] OF CHAR;
    Title,
    Prefix                  : ARRAY [0..59]  OF CHAR;
    Selection               : CARDINAL;
    TaskTotalEffort,
    TaskToGoEffort,
    AssignmentSpentEffort   : REAL;    (* Regular and overtime. *)
    AssignmentTotalMaxRate  : REAL;    (* Total of MaxRatePercent on all assignments. *)
    AssignmentSpentOvertime : LONGINT; (* Spent overtime *)
    AssignmentOvertime      : LONGINT; (* Spent + ToGo overtime *)
    RollupTask              : BOOLEAN;
    NeedsFixing             : BOOLEAN;
    ok                      : BOOLEAN;


BEGIN

    (* Ignore summary tasks.
    *)
    IF (TaskNode^.Methods^.FirstChild( TaskNode ) <> NIL) THEN
        RETURN TRUE;
    END;


    (* Get needed stuff from the task.
    *)
    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    WITH TaskPtr^ DO
        LocalStartStatus    := StartStatus;
        RollupTask          := rollupstatus <> NotRollup;
        LocalDurationMethod := DurationMethod;
        TaskDuration        := duration;
        TaskToGoEffort      := ToGoSummary.Time;
        TaskTotalEffort     := CompletedSummary.Time + TaskToGoEffort;
        AssignmentHandle    := Plan.Assignments;
    END;
    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    (* If there are no assignments, there is nothing to fix. *)

    IF (AssignmentHandle = AnExtHandle(NIL)) THEN
        RETURN TRUE;
    END;


    (* Rollup tasks don't need checking.   (A "rollup" task is one that
       is linked to another schedule.  This is a somewhat obsolete term.
       In versions 1 and 2 of Time Line, linked tasks always rolled-up, or
       summarized entire other schedules.  Now, they can link to individual
       tasks.)
    *)
    IF (RollupTask) THEN
        RETURN TRUE;
    END;


    StatusDialogResponse := AllowCondition;     (* Anything goes. *)


    (* Based on the start status, do the appropriate thing.
    *)
    IF (LocalStartStatus = DoneS) THEN

            (* If there is work to go and the task is DONE,
               then maybe the total should be the same as completed.
            *)

            (* Is there work to be done??
               Count the number of assignments which have work remaining.
               Also, find the total amount of spent effort across all
               assignments.
            *)

        Count := LockObjectArray( AssignmentHandle, Assignments, TSIZE(AnAssignmentRecord) );

        IF (Count = 0) THEN
            ReleaseUnchangedObject( AssignmentHandle );
            RETURN TRUE;
        END;

        NeedsFixing := FALSE;
            (* Check the assignments of resources to tasks.  If the task
               is effort driven, we require only that the total of the spent
               effort on the assignments matches the task total, not that
               each assignment have spent = plan, as we do on duration-
               or assignment-driven tasks.   In either case, assignments
               to costs require that each assignments spent = its plan. *)
        AssignmentSpentEffort   := Zero;
        AssignmentTotalMaxRate  := Zero;
        AssignmentSpentOvertime := 0L;
        AssignmentOvertime      := 0L;

(*$O-*)
        FOR i := 0 TO Count-1 DO
            WITH Assignments^[i] DO
                IF (Resource^.Type = AccountingOnly) THEN
                    IF (YetToGoQuantity <> Zero) THEN
                        NeedsFixing := TRUE;
                    END;

                ELSIF (LocalDurationMethod = EffortDriven) THEN
                    (* Add up the hours spent on each assignment. *)
                    AssignmentSpentEffort := AssignmentSpentEffort
                      + ActualQuantity;
                    (* Add up any spent overtime, plus all overtime. *)
                    AssignmentSpentOvertime := AssignmentSpentOvertime
                        + (OvertimeHours-YetToGoOvertimeHours);      
                    AssignmentOvertime := AssignmentOvertime + OvertimeHours;
                    (* Find the total rate at which effort could be applied,
                       best case, assuming no vacations or splitting. *)
                    AssignmentTotalMaxRate := AssignmentTotalMaxRate +
                        FLOAT(MaxRatePercent);
                ELSE
                    IF (YetToGoQuantity <> Zero) OR
                       (YetToGoOvertimeHours <> 0L) THEN
                        NeedsFixing := TRUE;
                    END;
                END;
            END;
        END;
(*$O=*)

        AssignmentSpentEffort := AssignmentSpentEffort
            + LongToReal(AssignmentSpentOvertime);

        ReleaseUnchangedObject( AssignmentHandle );


            (* On effort-driven tasks, we don't decide whether each assignment
               was fully spent, but instead whether the task as a total was. *)
        IF (LocalDurationMethod = EffortDriven) THEN
            IF (AssignmentSpentEffort <> TaskTotalEffort) THEN
                NeedsFixing := TRUE;
            END;
        END;

            (* If there is work to go, or costs unspent,
               ask if we should do something about it.
            *)
        IF (NeedsFixing) THEN
            StatusDialogResponse := StatusDialogProc( TaskNode,
                                                      LocalStartStatus );


            (* If the customer wants us to handle things, do so.
            *)
            IF (StatusDialogResponse IN 
                   AResponseSet{CancelRemainingEffort,SpendRemainingEffort}) THEN (* "Make TOTAL = SPENT?" *)

                    (* Effort driven tasks require that the effort spent on the 
                       task equals the sum of the efforts spent on each assignment,
                       but, because resources are substitutable one for another,
                       does not require that each resource have worked his planned 
                       amount. *)
                IF (LocalDurationMethod = EffortDriven) THEN
                    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
                        (* If cost data was entered, set the plan to equal the spent
                           amount.  If tracking is off, set the spent to equal the 
                           plan. *)
                    WITH TaskPtr^ DO
                        IF (StatusDialogResponse = CancelRemainingEffort) THEN
                                (* Plan := Spent *)
                            CompletedSummary.Time := AssignmentSpentEffort;
                        ELSE
                                (* Spent := Plan *)
                            CompletedSummary.Time :=
                                CompletedSummary.Time + ToGoSummary.Time
                                     + LongToReal(AssignmentOvertime);

                        END;
                        ToGoSummary.Time      := Zero;
                    END;
                    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
                END;
                    (* Repair the assignments so they match the plan. *)
                Count := LockObjectArray( AssignmentHandle, Assignments, TSIZE(AnAssignmentRecord) );
                RepairTheAssignments( Assignments, Count, LocalDurationMethod,
                                      TaskDuration, StatusDialogResponse );
                ReleaseObject( AssignmentHandle );     Assignments := NIL;
                    (* Recalculate the costs of the task. *)
                ComputeTaskNodeCosts( TaskNode );
            END;
        END;
    END;


    RETURN (StatusDialogResponse <> RejectChange);

END CheckStatusChange;










(* Default Status Dialog Proc

        Provide a default dialog proc; one that interacts with the customer.
*)
PROCEDURE DefaultStatusDialogProc(    TaskNode          : ATreeNode;
                                      StartStatus       : AStartStatus
                                 ) : AStatusDialogResponse;
VAR
    TaskPtr                 : ATaskPtr;
    StatusDialogResponse    : AStatusDialogResponse;
    Text,
    Menu                    : ARRAY [0..255] OF CHAR;
    Title,
    Prefix                  : ARRAY [0..59]  OF CHAR;
    FinalAnswer             : BOOLEAN;


    (* Tack onto the passed string a list of the resources.
    *)
    PROCEDURE GlomOnResources( VAR s : ARRAY OF CHAR );
    VAR
        S2                : ARRAY [0..51] OF CHAR;
        S3                : ARRAY [0..15] OF CHAR;
        AssignmentHandle  : AnExtHandle;
        Assignments       : AnAssignmentArray;
        Count, i, j       : CARDINAL;
        DurationUnit      : ADurationUnit;
        FoundAny          : BOOLEAN;
    BEGIN
        FoundAny      := FALSE;

        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        AssignmentHandle    := TaskPtr^.Plan.Assignments;
        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

        Count := LockObjectArray( AssignmentHandle, Assignments, TSIZE(AnAssignmentRecord) );
        i     := 0;
(*$O-*)
        LOOP
            IF (i >= Count) THEN
                EXIT;
            END;
            WITH Assignments^[i] DO
                IF (YetToGoQuantity <> Zero) THEN
                        (* Add on the resource name and the amount
                           of the resource. *)
                    Copy(Resource^.Name, S2);
                    ConcatS(S2," (");
                    CASE Resource^.CostStyle OF
                        CAmount:
                            FormatAsCurrency( YetToGoQuantity,
                                    DefaultCurrencyFormat,
                                    S3, HIGH(S3), 
                                    FALSE,           (* Right justify? *)
                                    TRUE,            (* Show customary fraction? *)
                                    TRUE );          (* Include the currency symbol? *)

                      | CAmountRate:
                            FormatAsAmount( YetToGoQuantity,
                                            DefaultAmountFormat,
                                            S3, HIGH(S3), 
                                            0, 2,    (* Min and Max digits *)
                                            FALSE ); (* Right Just *)
                      | CAmountRateTime:
                            DurationUnit := ActualTimeUnits;
                            LongDurationToString( YetToGoQuantity,
                                                  DurationUnit,
                                                  0,       (* MinDecimalPlaces *)
                                                  2,       (* MaxDecimalPlaces *)
                                                  HIGH(S3),(* MaxLength  *)
                                                  S3, j );
                    END;

                    TrimRear(S3);
                    ConcatLS(S2,S3);
                    ConcatS(S2,")");
                    IF ((LengthOf(s) + 2 + LengthOf(S2)) > HIGH(s)) THEN
                        EXIT;
                    END;
                    IF (FoundAny) THEN
                        ConcatS( s, ", " );
                    END;
                    ConcatLS( s, S2 );
                    FoundAny      := TRUE;
                END;
            END;
            INC(i);
        END;
(*$O=*)
        ReleaseUnchangedObject( AssignmentHandle );

    END GlomOnResources;


    PROCEDURE DoDialog( SequenceNumber : CARDINAL ) : AStatusDialogResponse;
    VAR
        Selection               : CARDINAL;
    BEGIN
        GetMessage( SequenceNumber + 0, Text   ); (* e.g. "Task is Future, and some assignment rates are too big:" *)
        GlomOnResources( Text );
        GetMessage( SequenceNumber + 1, Title  ); (* "Task duration too long." *)
        GetMessage( SequenceNumber + 2, Prefix ); (* "Should I:" *)
        GetMessage( SequenceNumber + 3, Menu   ); (* "Fix it, Let you edit the task, Let It Be." *)

        Selection := 1;
        StatusDialogResponse := RejectChange;
        IF (MultipleChoiceBox( Text, Title, NoHelp, Prefix, Menu, Selection )) THEN
            CASE Selection OF
            | 1 : StatusDialogResponse := CancelRemainingEffort;
            | 2 : StatusDialogResponse := SpendRemainingEffort;
            | 3 : (* StatusDialogResponse := RejectChange; Already set. *)
            | 4 : StatusDialogResponse := AllowCondition;
            ELSE
                ErrorPhrase(0);  (* Extra menu choice? *)
            END;
        END;

        RETURN StatusDialogResponse;
    END DoDialog;



BEGIN
    FinalAnswer := TRUE;




    REPEAT
            (* If the customer does not use cost tracking, then just adjust things for
               him/her.
            *)
        IF (NOT UsesCostTracking) (* NOT COST TRACKING *) THEN
            StatusDialogResponse := SpendRemainingEffort;


            (* Started tasks need no attention by us.
            *)
        ELSIF (StartStatus = StartedS) THEN
            StatusDialogResponse := AllowCondition;


            (* Future tasks must be warned, and could be fixed.
            *)
        ELSIF (StartStatus = FutureS) THEN
            StatusDialogResponse := DoDialog(ModuleNumber + 1);


            (* Done tasks need to have spent = total.  They don't, so see what to do.
            *)
        ELSE
            StatusDialogResponse := DoDialog(ModuleNumber + 5);
            IF (StatusDialogResponse = CancelRemainingEffort) THEN
                    (* If they are asking us to set the plan to zero,
                       confirm.   The only exemption is if both the plan
                       dollars and time are supposed to be zero. *)
                TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
                WITH TaskPtr^ DO
                    FinalAnswer :=  (CompletedSummary.Time <> 0.0)
                                   OR
                                    (CompletedSummary.Amount <> 0.0)
                                   OR
                                    ((ToGoSummary.Time = 0.0)
                                      AND
                                    (ToGoSummary.Amount = 0.0));
                END;
                TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
            ELSE
                FinalAnswer := TRUE;
            END;

            IF (NOT FinalAnswer) THEN
                GetMessage(ModuleNumber+9,Text);
                GetMessage(ModuleNumber+10,Title);
                FinalAnswer := ContinuationBox(Text,Title,NoHelp);
            END;
        END;
    UNTIL (FinalAnswer);

        (* Return the answer. *)

    RETURN StatusDialogResponse;

END DefaultStatusDialogProc;


(* CheckTaskEfforts :

    Checks to see if task is Effort-driven, and if it is, makes sure
    the sum of the assigned Spent effort(s) is not greater than the
    Estimated task effort.

    If task doesn't check out, we offer to make Estimated = Spent, or
    to let the user fix the problem.

    Preconditions
                    TaskNode    The task to check

    Postconditions
                    RETURN      TRUE    Task is ok (now).
                                FALSE   More editing is needed.

*)
PROCEDURE CheckTaskEfforts(     TaskNode    : ATreeNode;
                                PutUpDialog : BOOLEAN;
                            VAR CompletedSum,
                                ToGoSum     : AnAssignmentSummary
                          ) : BOOLEAN;

VAR
    TaskPtr                 : ATaskPtr;
    AssignmentHandle        : AnExtHandle;
    Assignments             : AnAssignmentArray;
    TaskDuration            : ADuration;
    Count,
    i                       : CARDINAL;
    StatusDialogResponse,
    RepairMethod            : AStatusDialogResponse;
    LocalDurationMethod     : ADurationMethod;
    Text,
    Menu                    : ARRAY [0..255] OF CHAR;
    Title,
    Prefix                  : ARRAY [0..59]  OF CHAR;
    Selection               : CARDINAL;
    TaskTotalEffort,
    AssignmentSpentEffort   : REAL;
    RollupTask              : BOOLEAN;
    NeedsFixing             : BOOLEAN;

BEGIN

    (* Ignore summary tasks.
    *)
    IF (TaskNode^.Methods^.FirstChild( TaskNode ) <> NIL) THEN
        RETURN TRUE;
    END;


    (* Get needed stuff from the task.
    *)
    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    WITH TaskPtr^ DO
        RollupTask          := rollupstatus <> NotRollup;
        LocalDurationMethod := DurationMethod;
        TaskDuration        := duration;
        TaskTotalEffort     := CompletedSummary.Time + ToGoSummary.Time;
        AssignmentHandle    := Plan.Assignments;
    END;
    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    (* If there are no assignments, there is nothing to fix. *)

    IF (AssignmentHandle = AnExtHandle(NIL)) THEN
        RETURN TRUE;
    END;


    (* Rollup tasks don't need checking.   (A "rollup" task is one that
       is linked to another schedule.  This is a somewhat obsolete term.
       In versions 1 and 2 of Time Line, linked tasks always rolled-up, or
       summarized entire other schedules.  Now, they can link to individual
       tasks.)
    *)
    IF (RollupTask) THEN
        RETURN TRUE;
    END;

    StatusDialogResponse := AllowCondition;     (* Anything goes. *)

    IF (LocalDurationMethod = EffortDriven) THEN
        (* Need to make sure Estimated task effort >= Spent efforts *)
        Count := LockObjectArray( AssignmentHandle, Assignments, TSIZE(AnAssignmentRecord) );
        IF (Count = 0) THEN
            ReleaseUnchangedObject( AssignmentHandle );
            RETURN TRUE;
        END;

        AssignmentSpentEffort := Zero;

(*$O-*)
        FOR i := 0 TO Count-1 DO
            WITH Assignments^[i] DO
                IF (Resource^.Type <> AccountingOnly) THEN (* 18-Jun-91 TGS *)
                    AssignmentSpentEffort := AssignmentSpentEffort + 
                                             ActualQuantity;
                END;
            END;
        END;
(*$O=*)

        ReleaseUnchangedObject( AssignmentHandle );

        IF (AssignmentSpentEffort > TaskTotalEffort) THEN
            (* Put up a dialog box if asked *)
            IF PutUpDialog THEN
                GetMessage( ModuleNumber + 20, Text);   (* e.g. "Spent Effort greater than Estimated Effort" *)
                GetMessage( ModuleNumber + 21, Title);  (* "Estimated less than Spent" *)
                GetMessage( ModuleNumber + 22, Prefix); (* "Should I" *)
                GetMessage( ModuleNumber + 23, Menu);   (* "Fix it, Let you fix it" *)

                Selection := 1;
                StatusDialogResponse := RejectChange;
                IF MultipleChoiceBox( Text, Title, NoHelp, Prefix, Menu, Selection ) THEN
                    CASE Selection OF
                    | 1 : StatusDialogResponse := FixTheTask;
                    | 2 : (* StatusDialogResponse := RejectChange; Already set. *)
                    ELSE
                        ErrorPhrase(0); (* Extra menu choice? *)
                    END;
                END;
            ELSE
                StatusDialogResponse := FixTheTask;
            END;

            IF (StatusDialogResponse = FixTheTask) THEN
                TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
                TaskPtr^.CompletedSummary.Time := AssignmentSpentEffort;
                TaskPtr^.ToGoSummary.Time      := Zero;
                TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
                    (* Moved the "repair" steps inside this IF, so we don't overdo it *)
                    (* Repair the assignments so they match the plan. *)
                    (* The first step is to fix each assignment so that it
                       matches its plan, so that the total equals
                       the spent amount, either by setting the total to the
                       spent, or increasing the spent to the total. *) 
                IF (UsesCostTracking) THEN
                    RepairMethod := CancelRemainingEffort;
                ELSE
                    RepairMethod := SpendRemainingEffort;
                END;
                Count := LockObjectArray( AssignmentHandle, Assignments, TSIZE(AnAssignmentRecord) );
                RepairTheAssignments( Assignments, Count, LocalDurationMethod,
                                      TaskDuration, RepairMethod );
                ReleaseObject( AssignmentHandle );     Assignments := NIL;
                    (* Now, recompute the total effort on the task. *)
                ComputeTaskNodeCosts( TaskNode );
                    (* 29-Apr-91 TGS: pass back the updated AssignmentSummary info. *)
                    (* Lock the task? Again?? Well, better here than by the caller... *)
                TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
                CompletedSum := TaskPtr^.CompletedSummary;
                ToGoSum      := TaskPtr^.ToGoSummary;
                TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
            END;
        ELSE
            StatusDialogResponse := AllowCondition;
        END;
    END;
    
    RETURN (StatusDialogResponse <> RejectChange);

END CheckTaskEfforts;



END StatusChange.


