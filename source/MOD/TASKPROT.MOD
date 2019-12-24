IMPLEMENTATION MODULE TaskProtection;

(*  =========================================================================
    Last Edit : September 18, 1991 11:36AM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Task Protection:  Determine what fields are enterable,
                          and which of those are numeric.

    MODIFICATION HISTORY:

    19-Apr-89  RSC  First Version.  Based on code from TLSpread and TLChange.
    12-May-89  RSC  Use numeric editing rules for enumerations, like "Done".
    20-May-89  RSC  Update list of fields that cause filtering to include the
                    resource columns, % achieved, and the coding fields.
    26-May-89  RSC  1) Added "ToGoEffort" to the list of editable columns.
                    2) Don't allow editing of the effort columns if
                       there are no resource assignments.
    30-May-89  RSC  1) Added 10 more coding fields.
                    2) Improve error returns for the spreadsheet view when
                       a column is not editable.
     7-Aug-89  RSC  New module header format.  Fixed bug # 873, where resources
                    could be edited on tasks linked to other tasks.
    25-Aug-89  MWP  Allow editing on new WBSErros task column.
     5-Sep-89  RSC  Disavow any knowledge of the SortSequence Column.
                    (Make it NON-EDITABLE).
    20-Jul-90  AJL  Import NumberOfCodingFields.
     6-Aug-90  RSC  Added the new "Split/Delay" field to the task form, and
                    ajusted protections for Split/Delay and for the new
                    task type (in addition to Duration and Effort Driven),
                    Assignment Driven.
    14-Sep-90 PFG   Added support for editing the new Splitting Rule column.
    17-Sep-90 PFG   Changed FixedStartColumn to UserEnteredStartColumn.
                    Added UserEnteredEndColumn.
    28-Oct-90 AJL   Added RequiredStartColumn and AllowSlackColumn.
     1-Nov-90 CL    Rename ResourceDriven to EffortDriven.
     5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
     9-Sep-91 EGK   Added FFX to RollupProtection set.  Eve bug #4951.
    16-Sep-91 LAA   I added ToGoEffort to the RecalcColumns set.
    17-Sep-91 LAA   Added PriorityColumn to SummaryProtectionCol, to fix
                    bug #5155.
    18-Sep-91 EGK   Oops, I shouldn't have made the change of 9-Sep-91.  The
                    proper fix is to allow the user to change the task type.
    =========================================================================
*)


FROM Allocs     IMPORT
    (* TYPE *)      AFixType, ATaskPtr, AStartStatus, ADurationMethod,
                    ASplittingRule;

FROM Dialog     IMPORT
    (* PROC *)      FatalError;

FROM FlexStor   IMPORT
    (* TYPE *)      AnExtHandle;

FROM MagicNum   IMPORT
    (* CONST *)     IsStringValue,          IsRealValue,
                    IsIntValue,             IsCardValue,
                    IsDuration,             IsSlack,
                    IsCurrency,             IsEffort,
                    IsEnumValue,            IsTruncatedString;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS;

FROM TaskColNumbers IMPORT 
    (* CONST *)     TaskNameColumn,         NotesColumn,
                    UserEnteredStartColumn, EarlyStartColumn,
                    EarlyEndColumn,         DurationColumn,
                    DurationHours,          DurationDays,
                    DurationWeeks,          DurationMonths,
                    TotalEffort,            EffortHours,
                    EffortDays,             EffortWeeks,
                    EffortMonths,           AUXColumn,
                    WBSColumn,              OBSColumn,
                    TaskTypeColumn,         StartStatusColumn,
                    DurationMethodColumn,   PercentAchieved,
                    PriorityColumn,         Summarizes,
                    SortSequenceNumber,     ToGoEffort,
                    ResourceColumn,         CostColumn,
                    CostAmount,             ResourceAmount,
                    PredecessorWBS,         SuccessorWBS,
                    SplittingRuleColumn,                (* 14-Sep-90 PFG *)
                    UserEnteredEndColumn,               (* 17-Sep-90 PFG *)
                    RequiredStartColumn,                (* 28-Oct-90 AJL *)
                    AllowSlackColumn,                   (* 28-Oct-90 AJL *)

                    CodingField1,
                    NumberOfCodingFields,
                    WBSErrors,                                    (* 25-Aug-89 MWP *)

                    HighestRootColumn,
                    CompletedEffort,                           (* 15-Sep-91 *)
                    ExtraExpenses;

FROM TreeObjects IMPORT
    (* CONST *)     ATreeNode;




VAR
    (* If the task is a summary task, these fields cannot be changed.
    *)

    SummaryProtection       : ATaskFormField;
    SummaryProtectionCol    : AColumnSet;


    (* If the task is on the BIG task form, these fields are protected.
    *)

    FullProtection          : ATaskFormField;


    StartDateColumns        : AColumnSet;
    EndDateColumns          : AColumnSet;
    DurationColumns         : AColumnSet;
    EffortColumns           : AColumnSet;

    ColumnsInColumnSets     : AColumnSet;


VAR
    ColumnSets  : ARRAY ADurationMethod OF
                  ARRAY AStartStatus    OF
                  ARRAY AFixType        OF AColumnSet;






(* Get Protection - Get field protection values for Start Date, End Date,
                    Duration Number and Duration Units.

     Preconditions  - Fixation           is the task's AFixType.
                      StartStatus        is the task's AStartStatus.
                      DurationMethod     is the task's ADurationMethod.
                      TaskFormProtection is the existing protection.  May have
                                            been set by "SetStaticProtection".

     Postconditions - StartProtection, EndProtection, EffortProtection,
                      and DurationProtection are set.  (TRUE = PROTECT).
*)
PROCEDURE GetProtection( VAR StartProtection,
                             EndProtection,
                             EffortProtection,
                             DurationProtection : BOOLEAN;
                             TaskFormProtection : ATaskFormField;
                             Fixation           : AFixType;
                             StartStatus        : AStartStatus;
                             DurationMethod     : ADurationMethod );

(* Parameters to the setting of protections are:

   - Fixation        ( Fixed, ASAP, ALAP, Span )
   - StartStatus     ( Future, Started, Done )
   - Duration Method ( DurationDriven, EffortDriven, AssignmentDriven )

          DurationDriven         EffortDriven          AssignmentDriven
      Future  Started  Done   Future  Started  Done   Future  Started  Done
Fixed 0: SDE  4: SDE    8:SDE 0: SF   4: SF     8:SFE 0: S    4: S      8:S E
ASAP  1:  D   5: SD     9:SDE 1:  F   5: SF     9:SFE 1:      5: S      9:S E
ALAP  2:  D   6: SD    10:SDE 2:  F   6: SF    10:SFE 2:      6: S     10:S E
Span  3:      7: S     11:SDE 3:      7: S     11:SFE 3:      7: S     11:S E

  (S=Start Date field, E=End Date Field, D=Duration fields, F=Effort fields)

  Here, we implement this lookup table as BITSETs.  One BITSET for
  each field group for each duration method, or 12 BITSETs.
  Each BIT represents one of the row,col pairs numbered above.  For
  example, ALAP/Started = BIT 6.
  Bit ON = Allow entry.  OFF = Do not allow entry.

*)

CONST
      DurationDrivenStartDate   = {0,4,5,6,7,8,9,10,11};
      EffortDrivenStartDate     = {0,4,5,6,7,8,9,10,11};
      AssignmentDrivenStartDate = {0,4,5,6,7,8,9,10,11};

      DurationDrivenDuration    = {0,1,2,4,5,6,8,9,10,11};
      EffortDrivenDuration      = {};
      AssignmentDrivenDuration  = {};

      DurationDrivenEffort      = {};
      EffortDrivenEffort        = {0,1,2,4,5,6,8,9,10,11};
      AssignmentDrivenEffort    = {};

      DurationDrivenEndDate     = {0,4,8,9,10,11};
      EffortDrivenEndDate       = {    8,9,10,11};
      AssignmentDrivenEndDate   = {    8,9,10,11};

      LastFixPlus1 = ORD(MAX(AFixType)) + 1;

VAR
    FixationAndStatusOffset : CARDINAL;
BEGIN
    FixationAndStatusOffset := (ORD(Fixation) +
                               (ORD(StartStatus) * LastFixPlus1));

    CASE DurationMethod OF

      EffortDriven:

            StartProtection    := NOT (FixationAndStatusOffset IN
                                                EffortDrivenStartDate);
            EndProtection      := NOT (FixationAndStatusOffset IN
                                                EffortDrivenEndDate);
            DurationProtection := NOT (FixationAndStatusOffset IN
                                                EffortDrivenDuration);
            EffortProtection   := NOT (FixationAndStatusOffset IN
                                                EffortDrivenEffort );

    | DurationDriven:

            StartProtection    := NOT (FixationAndStatusOffset IN
                                                DurationDrivenStartDate);
            EndProtection      := NOT (FixationAndStatusOffset IN
                                                DurationDrivenEndDate);
            DurationProtection := NOT (FixationAndStatusOffset IN
                                                DurationDrivenDuration);
            EffortProtection   := NOT (FixationAndStatusOffset IN
                                                DurationDrivenEffort );

    | AssignmentDriven:

            StartProtection    := NOT (FixationAndStatusOffset IN
                                                AssignmentDrivenStartDate);
            EndProtection      := NOT (FixationAndStatusOffset IN
                                                AssignmentDrivenEndDate);
            DurationProtection := NOT (FixationAndStatusOffset IN
                                                AssignmentDrivenDuration);
            EffortProtection   := NOT (FixationAndStatusOffset IN
                                                AssignmentDrivenEffort );

    ELSE
        FatalError();   (* New DurationMethod?? *)
    END;

    StartProtection    := (StartProtection    OR (FSD IN TaskFormProtection));
    EndProtection      := (EndProtection      OR (FED IN TaskFormProtection));
    DurationProtection := (DurationProtection OR (FDN IN TaskFormProtection));
    EffortProtection   := (EffortProtection   OR (FEN IN TaskFormProtection));

END GetProtection;






 (* Set Static Protection - Setup the protection bitsets that are fairly
                            static.

      Preconditions  - AdvancedTaskForm   is it non-moron-mode?
                       ThisIsASummaryTask is it summary or detail?
                       RollupTask         is the SUMMARIZES field filled in?

      Postconditions - TaskFormProtection is set up for subsequent
                                             testing by GetProtection or
                                             whomever.
  *)
PROCEDURE SetStaticProtection(     AdvancedTaskForm,
                                   ThisIsASummaryTask,
                                   RollupTask          : BOOLEAN;
                               VAR TaskFormProtection  : ATaskFormField );
BEGIN

    TaskFormProtection := ATaskFormField{};

    IF (AdvancedTaskForm) THEN
        TaskFormProtection := FullProtection;
    ELSE
        TaskFormProtection := SmallProtection;
    END;

    IF (ThisIsASummaryTask) THEN
        TaskFormProtection := TaskFormProtection + SummaryProtection;
    END;

    IF (RollupTask) THEN
        TaskFormProtection := TaskFormProtection + RollupProtection;
    END;

END SetStaticProtection;









(* Column Is Protected.

        Given a column, is the column "protected"?  If so, why?
*)
PROCEDURE ColumnIsProtected(     TaskNode     : ATreeNode;
                                 ColumnID     : CARDINAL
                           ) : AReasonWhyProtected;
VAR
    TaskPtr     : ATaskPtr;
    Reason      : AReasonWhyProtected;
BEGIN
    Reason := RNotProtected;

    IF (NOT (ColumnID IN EditableColumns)) THEN
        Reason := RNotPossible;

    ELSE

        IF (TaskNode^.Methods^.FirstChild( TaskNode ) <> NIL) THEN

            (* It is a smummary task, see if we have been locked out. *)

            IF (ColumnID IN SummaryProtectionCol) THEN
                Reason := RSummaryTask;
            END;
        ELSE

            (* Not a summary, we need to lock the task to get the task ptr *)

            TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );


            (* Is it a Linked task? *)

            IF (ADDRESS(TaskPtr^.summarizes) <> NIL) THEN

                    (* it is linked, so see what that does to us. *)

                IF (ColumnID IN RollupProtectionCol) THEN
                    Reason := RLinkedTask;
                END;

                (* Is it an effort column with no assignment records?
                   Duration Method column  "    "      "        "
                   RSC 26-May-89
                *)
            ELSIF ((ColumnID IN EffortColumns) OR
                   (ColumnID = DurationMethodColumn)) AND
                  (TaskPtr^.Plan.Assignments = AnExtHandle(NIL)) THEN

                Reason := RNoAssignments;



                (* Other special conditions?
                *)
            ELSIF (ColumnID IN ColumnsInColumnSets) THEN

                    (* ColumnSets' bits are ON if editing is OK. *)

                IF (NOT (ColumnID IN ColumnSets[ TaskPtr^.DurationMethod,
                                                 TaskPtr^.StartStatus,
                                                 TaskPtr^.fixation ])) THEN
                    Reason := RNoFSD;
                END;
            END;

            TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
        END;
    END;

    RETURN Reason;

END ColumnIsProtected;





PROCEDURE Init();
VAR
    DurationMethod  : ADurationMethod;
    StartStatus     : AStartStatus;
    FixType         : AFixType;
BEGIN

(*$O-*)
    (* This is the list of columns that MIGHT be editable. *)

    EditableColumns     := AColumnSet{
                                            TaskNameColumn,
                                            NotesColumn,
                                            UserEnteredStartColumn,
                                            EarlyStartColumn,
                                            EarlyEndColumn,
                                            DurationColumn,
                                            DurationHours,
                                            DurationDays,
                                            DurationWeeks,
                                            DurationMonths,
                                            TotalEffort,
                                            EffortHours,
                                            EffortDays,
                                            EffortWeeks,
                                            EffortMonths,
                                            AUXColumn,
                                            WBSColumn,
                                            OBSColumn,
                                            TaskTypeColumn,
                                            StartStatusColumn,
                                            DurationMethodColumn,
                                            PercentAchieved,
                                            PriorityColumn,
                                            Summarizes,
                                            ResourceColumn,
                                            CostColumn,
                                            CostAmount,
                                            ResourceAmount,
                                            PredecessorWBS,
                                            SuccessorWBS,
                                            ToGoEffort,
                                            SplittingRuleColumn,    (* 14-Sep-90 PFG *)
                                            UserEnteredEndColumn,   (* 17-Sep-90 PFG *)
                                            AllowSlackColumn,       (* 28-Oct-90 AJL *)
                                            RequiredStartColumn,     (* 28-Oct-90 AJL *)
                                            CodingField1..CodingField1+NumberOfCodingFields-1,
                                            WBSErrors             (* 25-Aug-89 MWP *)
                                     };


    (* These columns are numeric. *)

    NumericFields       := AFieldKindSet{
                                            IsEnumValue, (* RSC 12-May-89 *)
                                            IsRealValue,
                                            IsIntValue,
                                            IsCardValue,
                                            IsCurrency,
                                            IsDuration,
                                            IsEffort,
                                            IsSlack
                                        };


    (* If this field or column changes, the task
       and schedule need to be recalcd.

        6-Aug-90 RSC Added SPD
       14-Sep-90 PFG Added SplittingRuleColumn.
       17-Sep-90 PFG Added UserEnteredEndColumn.
    *)

    RecalcFields       := ATaskFormField{   FFX,FSD,FDN,FDU,
                                            FED,FEN,FEU,FSS,
                                            PCP,PRI,SPD,RED
                                        };
    RecalcColumns      := AColumnSet{       TaskTypeColumn,
                                            UserEnteredStartColumn,
                                            EarlyStartColumn,
                                            EarlyEndColumn,
                                            DurationColumn,
                                            DurationHours,
                                            DurationDays,
                                            DurationWeeks,
                                            DurationMonths,
                                            DurationMethodColumn,
                                            TotalEffort,
                                            EffortHours,
                                            EffortDays,
                                            EffortWeeks,
                                            EffortMonths,
                                            StartStatusColumn,
                                            PercentAchieved,
                                            PriorityColumn,
                                            SplittingRuleColumn,
                                            UserEnteredEndColumn,    (* 17-Sep-90 PFG *)
                                            AllowSlackColumn,        (* 28-Oct-90 AJL *)
                                            RequiredStartColumn,     (* 28-Oct-90 AJL *)
                                            ToGoEffort               (* 15-Sep-91 *)
                                        };


    (* If this field or column changes,
       the schedule needs to be sorted.
    *)

    SortFields         := ATaskFormField{   FNM,FAU,FWB,FOB
                                        };

    SortColumns        := AColumnSet{       TaskNameColumn,   NotesColumn,
                                            ResourceColumn,   PercentAchieved,
                                            CostColumn,       CostAmount,
                                            ResourceAmount,
                                            CodingField1..CodingField1+NumberOfCodingFields-1,
                                            WBSErrors,            (* 25-Aug-89 MWP *)
                                            AUXColumn,
                                            WBSColumn,
                                            OBSColumn
                                        };

    (* If this field changes,
       the task form needs to be redisplayed.
    *)

    RecalcRedisplay    := ATaskFormField{   FDN,FDU,FEN,FEU,
                                            EVD,BAS,CMP,CPP,
                                            YTG,YGP
                                        };


    (* If a rollup (linked to another schedule) task, these fields need
       to be protected.

        RSC  6-Aug-90 Added Split/Delay field.
        PFG 14-Sep-90 Added Split/Delay column.
        17-Sep-90 PFG Added UserEnteredEndColumn.
         9-Sep-91 EGK Added Fixation. (Eve bug #4951)
        19-Sep-91 EGK Removed fixation.  (Eve bug #4951 re-opened)
    *)

    RollupProtection   := ATaskFormField{   RED,FDN,FEN,
                                            FSS,FSD,FED,PCP,
                                            EVD,BAS,CMP,CPP,
                                            YTG,YGP,SPD
                                        };

    RollupProtectionCol := AColumnSet{      DurationMethodColumn,
                                            UserEnteredStartColumn,
                                            EarlyStartColumn,
                                            EarlyEndColumn,
                                            DurationColumn,
                                            DurationHours,
                                            DurationDays,
                                            DurationWeeks,
                                            DurationMonths,
                                            TotalEffort,
                                            EffortHours,
                                            EffortDays,
                                            EffortWeeks,
                                            EffortMonths,
                                            StartStatusColumn,
                                            ResourceColumn,
                                            CostColumn,
                                            CostAmount,
                                            ResourceAmount,
                                            PercentAchieved,
                                            SplittingRuleColumn,
                                            UserEnteredEndColumn     (* 17-Sep-90 PFG *)
                                        };


    (* If the task is a summary task, these fields cannot be changed.

        RSC  6-Aug-90 Added Split/Delay field.
        PFG 14-Sep-90 Added Split/Delay column.
        17-Sep-90 PFG Added UserEnteredEndColumn.
    *)

    SummaryProtection  := ATaskFormField{   FFX,RED,FDN,FEN,
                                            FSS,FSD,FED,PCP,
                                            EVD,BAS,CMP,CPP,
                                            YTG,YGP,SUM,SPD
                                        };

    SummaryProtectionCol := AColumnSet{     TaskTypeColumn,
                                            UserEnteredStartColumn,
                                            EarlyStartColumn,
                                            EarlyEndColumn,
                                            DurationMethodColumn,
                                            DurationColumn,
                                            DurationHours,
                                            DurationDays,
                                            DurationWeeks,
                                            DurationMonths,
                                            TotalEffort,
                                            EffortHours,
                                            EffortDays,
                                            EffortWeeks,
                                            EffortMonths,
                                            StartStatusColumn,
                                            PercentAchieved,
                                            Summarizes,
                                            SplittingRuleColumn,
                                            UserEnteredEndColumn,    (* 17-Sep-90 PFG *)
                                               (* Unsupported for rollup tasks as of Oct. 90 *)
                                            AllowSlackColumn,        (* 28-Oct-90 AJL *)
                                            RequiredStartColumn,     (* 28-Oct-90 AJL *)
                                            PriorityColumn           (* 17-Sep-91 *)
                                        };


    (* If the task is on the BIG task form, these fields are protected.
    *)

    FullProtection     := ATaskFormField{   EVD,BAS,CMP,CPP,
                                            YTG,YGP,SUM
                                        };

    (* If the task is on the SMALL task form, these fields are protected.
    *)

    SmallProtection    := ATaskFormField{   PCP,EVD,BAS,CMP,
                                            CPP,YTG,YGP,FWB,
                                            FOB,PRI,SUM
                                        };


    StartDateColumns       := AColumnSet{ UserEnteredStartColumn, EarlyStartColumn };
    EndDateColumns         := AColumnSet{ UserEnteredEndColumn, EarlyEndColumn };
    DurationColumns        := AColumnSet{
                                            DurationColumn,
                                            DurationHours,
                                            DurationDays,
                                            DurationWeeks,
                                            DurationMonths
                                        };
    EffortColumns          := AColumnSet{
                                            TotalEffort,
                                            EffortHours,
                                            EffortDays,
                                            EffortWeeks,
                                            EffortMonths,
                                            ToGoEffort
                                        };

    ColumnsInColumnSets    := StartDateColumns +
                              EndDateColumns   +
                              DurationColumns  +
                              EffortColumns    +
                              AColumnSet{RequiredStartColumn};


(* Parameters to the setting of protections are:

            - Fixation        ( FixedDate, ASAP, ALAP, Span )
            - StartStatus     ( FutureS, StartedS, DoneS )
            - Duration Method ( DurationDriven, EffortDriven )

          DurationDriven         EffortDriven          AssignmentDriven
      Future  Started  Done   Future  Started  Done   Future  Started  Done
Fixed 0: SDE  4: SDE    8:SDE 0: SF   4: SF     8:SFE 0: S    4: S      8:S E
ASAP  1:  D   5: SD     9:SDE 1:  F   5: SF     9:SFE 1:      5: S      9:S E
ALAP  2:  D   6: SD    10:SDE 2:  F   6: SF    10:SFE 2:      6: S     10:S E
Span  3:      7: S     11:SDE 3:      7: S     11:SFE 3:      7: S     11:S E

    ( S = Start Date field, E = End Date Field, D = Duration fields,
      F = Effort fields ).

  Bit ON = Allow entry.  OFF = Do not allow entry.

*)

    (* Initialize.  Set "Future" ASAP through SPAN to empty sets,
       All others to include the Start Date Columns.
    *)
    FOR DurationMethod := MIN(ADurationMethod) TO MAX(ADurationMethod) DO
        FOR FixType := MIN(AFixType) TO MAX(AFixType) DO
            FOR StartStatus := MIN(AStartStatus) TO MAX(AStartStatus) DO
                ColumnSets[ DurationMethod, StartStatus, FixType ] := StartDateColumns;
            END;
            IF (FixType > FixedDate) THEN
                ColumnSets[ DurationMethod, FutureS, FixType ] := AColumnSet{};
            END;
        END;
    END;


    (* Include Duration in Duration Driven, and Effort in Effort Driven, for
       all but Span.  Include in Span only if DONE.
    *)
    FOR FixType := FixedDate TO ALAP DO
        FOR StartStatus := FutureS TO DoneS DO
            ColumnSets[ DurationDriven, StartStatus, FixType ] :=
            ColumnSets[ DurationDriven, StartStatus, FixType ] + DurationColumns;

            ColumnSets[ EffortDriven, StartStatus, FixType ] :=
            ColumnSets[ EffortDriven, StartStatus, FixType ] + EffortColumns;
        END;
    END;
    ColumnSets[ DurationDriven, DoneS, Span ] :=
    ColumnSets[ DurationDriven, DoneS, Span ] + DurationColumns;

    ColumnSets[ EffortDriven, DoneS, Span ] :=
    ColumnSets[ EffortDriven, DoneS, Span ] + EffortColumns;


    (* Include End Dates in all DONE, and in Duration Driven Future and
       Started Fixed tasks.

       Include the RequiredStart column only for all Future, Fixed tasks.
    *)
    FOR DurationMethod := MIN(ADurationMethod) TO MAX(ADurationMethod) DO
        FOR FixType := MIN(AFixType) TO MAX(AFixType) DO
            ColumnSets[ DurationMethod, DoneS, FixType ] :=
            ColumnSets[ DurationMethod, DoneS, FixType ] + EndDateColumns;
        END;
        INCL(ColumnSets[ DurationMethod, FutureS, FixedDate ], RequiredStartColumn );
    END;
    FOR StartStatus := FutureS TO StartedS DO
        ColumnSets[ DurationDriven, StartStatus, FixedDate ] :=
        ColumnSets[ DurationDriven, StartStatus, FixedDate ] + EndDateColumns;
    END;

(*$O=*)

END Init;






BEGIN
    Init();
END TaskProtection.



