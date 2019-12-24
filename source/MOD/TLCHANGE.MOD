MODULE TLChange;

(*  =========================================================================
    Last Edit : October 3, 1991 6:29PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description:
        Display the task form.

    MODIFICATION HISTORY

       10/13/87 - RSC - Removed old history (9/3/85 to 7/31/87)

*)(*
         6-Jan-89 RSC   Moved "AnOverlayProc" reference.
         8-Mar-89 EGK   For CheckFieldChange of duration method,
                        set all the task's assignments to be computed by
                        resource rate (as opposed to total effort).
         9-Mar-89 EGK   Incorporated Roger's change which implemented
                        AssignmentSummaryToString here instead of in
                        Captions.MOD.
        13-Mar-89 EGK   Use FindAssignmentErrors to keep us from leaving
                        the form if any assignments can't be calced properly.
        21-Mar-89 EGK   Check return value from ZeroAssignmentWork,
                        which signals FALSE if the user aborted the
                        process of marking assignments as done.
        25-Apr-89 RSC   Added support for modules
                        changed for the SpreadSheet View.
         5-May-89 EGK/RSC Changed for new WBS storage scheme.
        18-May-89 RSC   1) Made a few changes for the ability to allow started
                           and done tasks to have overbooked resources.  Also,
                           an empty task name field only gripes when the form
                           is exited, not when the field is exited.
                        2) Removed "ZeroAssignmentWork" and "IsThereAssignmentWork".
                           Also "FindAssignmentErrors".
                        3) When the start date changes, do not preserve old
                           old dates in the date block.
        20-May-89 RSC   Accomidated the new WorkHours module.
        23-May-89 RSC   Fixed task form navigation bugs.
        26-May-89 EGK   Changed MapFormToTask so that it only marks the
                        link status as "RollupNotLoaded" if the task
                        needs recalculation.  Changed
                        SetProperRollupProtection to protect the resource
                        fields on tasks with links.
        30-May-89 RSC   Check proc was always returning TRUE.  A side
                        effect of this was that the task name could be
                        left blank.
         2-Jun-89 RSC   If you F2d the task and then hit F10, resource leveling
                        dots dissapeared.
         4-Jun-89 EGK   Removed unnecessary imports from Undo module.
         7-Jun-89 RSC   If the notes field changes, but is blank and was blank,
                        the task was left locked.
        12-Jun-89 AJL   Don't preempt the EditKey.
        15-Jun-89 RSC   Allow EraseToEOLKey as well as EraseKey and DeleteKey.
                        This is for bug # 512.
        26-Jun-89 RSC   Bug # 611: Lower the notes field a little, so that it
                        does not obliterate the menus lines.  I tied the size
                        of the notes to the screen size, so rich folk with
                        EGA/VGA will get more notes lines.
        31-Jul-89 KKC   Call ContinuationBox instead of NoYes.
         7-Aug-89 RSC   Bug # 934, If there are no resources, do not allow
                        The task to stay as Effort Driven.  Added standard
                        header to this module.
        09-Aug-89 KKC   Add copyright message.
        24-Aug-89 RSC   1) Bug 773, ajust editor placement on small form
                            in 25 line mode.
                        2) Bug 934, effort numbers grow by magic.
        12-Sep-89 LAA   Bug 1051.  Reinstalled a check so you can't leave the
                        task name field if it's blank.
        19-Sep-89 RSC   pass default start date to StoEndTimeU.
        22-Sep-89 KKC   Copy date to FixedStart in TaskPtr if user switch
                        to Fixed task.
*)
(*
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        31-May-90 AJL   Removed import of Expenses.
        06-Jul-90 AJL   Added some checks of CheckTaskValid.
         6-Aug-90 RSC   Added the new "Split/Delay" field to the form, and
                        ajusted protections for Split/Delay and for the new
                        task type (in addition to Duration and Effort Driven),
                        Assignment Driven.
        12-Sep-90 RSC   Fixed for new Allocs.Def
        25-Sep-90 RSC   Make sure UserEnteredStartDate and SupposedToStart
                        have values in them when we exit.
         6-Oct-90 AJL - Allow the AlternateEraseKey (Ctrl-End) to erase to eol.
        24-Oct-90 RSC - Correct problem where tasks appear as milestones
                        when first set up before recalc is done.
                      - When DONE, set task to Split and protect the field.
                      - If task changes to FIXED, take the defaults from
                        the options form.
                      - If task changes to ASAP/ALAP, make sure that the
                        "NoSoonerThan/NoLaterThan" fields are cleared.
         1-Nov-90 CL -  Rename SuppressSlack to ForceCritical,
                        ResourceDriven to EffortDriven.
                        Import Schedule.FixedDateRules.
                        Rearranged setting of the TaskFlag ForceCritical.
         9-Nov-90 PFG   Added 4.0.3 fixes: 23-Sep-90 RSC  
                            Upon form exit, determine if there are RESOURCES 
                            on the form, rather than determining if there are
                            ANY KIND of assignments.  Use that to determine if 
                            we must convert EffortDriven to DurationDriven.
                            Bug # 2150 
                            Also, related to bug # 3115, if we change to a 
                            LINKED task, make sure we reset to DurationDriven.   
                        End of 4.0.3 fixes. 
        19-Dec-90 TGS   Don't set NoLaterStart and NoSoonerStart for Future 
                        tasks.
        27-Dec-90 TGS   Don't force Done tasks to Duration-driven.
        04-Jan-90 TGS   Check efforts on Effort driven tasks to make sure
                        they are consistent.
*)
(*
        22-Jan-91 RSC   Import AppendDurationUnit from LongDuration rather
                        than from TimeFormat.  Remove import of NameScale.
        19-Feb-91 TGS   FormWrapUp. Make Duration=Effort if they entered no
                        resources on an effort driven task.
        29-Apr-91 TGS   Change CheckTaskEfforts to return a copy of the task's
                        CompletedSummary and ToGoSummary fields. We needed to
                        update the Form values as well as the task record, 
                        because after we call CheckTaskEfforts and leave the
                        DoForm proc, there's CopyFormToTask, which was 
                        undoing our changes to the task record.
        30-Apr-91 TGS   Use "*" instead of "û" to indicate linked task.
        30-Apr-91 TGS   Set ONLY duration-driven tasks to Split when they are
                        Started or Done. (spec 10.2)
        11-Jun-91 RSC   Check assignment fields on a check field exit.  I
                        was ignoring CheckFieldExit on the theory that I
                        would have caught everything on a CheckFieldChange.
                        However, If you change a field to something REJECTED
                        by CheckFieldChange, and then change it BACK to
                        the original entry, there is no final CheckFieldChange
                        to indicate that things changed BACK.  I added the
                        check on Exit if the field is the last one changed.
                        Also, I moved the FormValue array and the StringFields
                        array onto the stack.  That will cost around 2KB of
                        stack space, but it shrinks this, the largest of
                        the overlays.
        19-Jul-91 AJL  -Changing the percent complete will prompt for a change
                        to the start status.
        26-Jul-91 PFG  -We were checking for a priority less greater than
                        the max, but not for less than zero.
        11-Aug-91 TGS   Compute a duration for EffortDriven tasks from 
                        EarlyEnd-EarlyStart.
        14-Aug-91 TGS   Check enterable Start Date on form exit. If task is
                        StartedS or DoneS, and it is less than AsOfDate, get
                        confirmation.
                        If Start Date is okay, check enterable End Date on
                        DoneS tasks to see if it is before AsOfDate.
        16-Aug-91 TGS   Make sure UserEnteredEndDate has the value of an
                        enterable End Date field.
        20-Aug-91 TGS   Don't recompute anything if none of the assignment
                        info has changed.
        21-Aug-91 TGS   If task is FutureS and PercentAchieved is non-zero,
                        put up a dialog to propose changing it to zero.
                        Don't compute the effort number for effort-driven
                        tasks; just use the number the user entered.
        24-Aug-91 TGS   Once EffortDriven task is StartedS, compute duration
                        as End-Start.
                        Go ahead and use duration in MapTaskToForm "as b4".
                        Recalc now makes sure recalc puts the correct number
                        in, and whenever there's a local recalc we want to 
                        use the resulting number.
        30-Aug-91 TGS   If we haven't changed a RecalcField, then don't
                        RecomputeTask and screw up $ numbers (Bug 5008).
                        Don't compute AssignmentSummaries on the way into the
                        task form.
         2-Sep-91 TGS   Tidying up a bit more on the call to CheckDuration.
        18-Sep-91 EGK   If a resource field is changed, set NeedsFormWrapUp
                        to make sure that effort-driven-but-no-resources
                        is checked on form exit.  Eve bug #5046.
        19-Sep-91 TGS   FormWrapUp calls CheckStatusChange now instead of 
                        AssForms.
                        MapTaskToForm ignores Task.duration if the task is
                        EffortDriven and DoneS, computing a temporary 
                        duration locally. This is so end date can be kept the
                        same as what the user may have typed in. Deja vu, man!
        27-Sep-91 EGK   Set the splitting rule for a linked task to "split".
        27-Sep-91 TGS   Get the resource field prompts to refresh, clean up
                        the logic in there a bit (I'm actually beginning to 
                        understand it now!).
         2-Oct-91 EGK   In AssignmentForms, always call CheckDuration for
                        summary tasks.  This fixes bug #5271, in which the
                        total effort and dollar amounts were being recomputed
                        incorrectly when you exited the task form with F10.
        03-Oct-91 LAA   Bug #5285.  New effort-driven tasks were showing up
                        on the Gantt chart and spreadsheet as milestones, 
                        until recalc was done.  There were OK on the task 
                        form.  This was because logic which depended on
                        catching differences between the current values and
                        GlobalOldStartDate and GlobalOldDuration was 
                        ineffective since those values were repeatedly set
                        in MapTaskToForm.  I added a BOOLEAN flag to allow
                        them to be set just once.
        03-Oct-91 TGS/EGK Moved initialization of "RFLastFieldChanged" and
                        "NeedsFormWrapUp" from the initialization of this
                        entire module to the beginning of the "TLTaskForm"
                        procedure.  This ensures that those two globals are
                        re-initialized for each task form invocation, rather
                        than only once each time the overlay is loaded.
        07-Oct-91 LAA   Damn local variables!  The LocalCompleted and 
                        LocalToGo need to be updated anytime you change the
                        CompletedSummary or ToGoSummary, since they're used
                        after F10 to update the task record.  Instead of
                        changing CheckStatusChange to take them as parameters,
                        which is the more correct solution, I created a new
                        procedure UpdateLocalSummaries to do this so we don't
                        have to alter a .DEF at this late date.
*)
(*
        08-Oct-91 LAA   In order to prevent incorrect total effort from
                        being locally computed, and then converted into
                        spent effort when we mark a task as done, I removed
                        some calls to RecomputeTask and replaced them with
                        calls to MaybeCalcSpent (which seems to be
                        the important thing that RecomputeTask was doing 
                        under the circumstances).
        15-Jan-92 TGS   In an attempt to ameliorate some of the effects
                        described in Bug 5376, if user blanks out the Start
                        Date, wait until Duration or End Date changes before
                        computing a new one. It seemed wrong to arbitrarily
                        set it to Today.
        18-Feb-92 TGS   What a mess. We have to run UpdateLocalSummaries
                        before CheckTaskEffort(), in case CheckTaskStatus
                        changed the task effort.  Then run it again after
                        CheckTaskEffort in case IT changed it. Sheesh.
        10-Mar-92 LAA   In MapFormToTask, mess around with the ForceCritical
                        flag so it won't end up set on just by the task
                        being temporarily Fixed.  Introduced the 
                        GlobalForceCritical BOOLEAN to help.
         3-Apr-92 AJL   Don't put up the warning message about achievement
                        not rolling up unless the rollup option chosen would
                        not lead to rollup.  Now that there are more options,
                        not all of them require baselines, or even assignments.
        16-Apr-92 TGS   If we do something that changes the Spent/Togo effort
                        of the assignments, blast the VaryingAssignments so
                        that $ amounts will be estimated without reference to
                        them. Bug 5547.
    =========================================================================
*)



FROM Allocs         IMPORT
    (* CONST *)             TskNmLen, WBSLine, OBSLine, AUXLine,
    (* VAR  *)              TaskTree,
    (* TYPE *)              ATaskPtr, ATask, ATaskFilterSet, ATaskFilter,
                            ATaskName, AFixType, ARollupStatus,
                            ATaskFlag, ADurationMethod,
                            ATaskFlagSet, AStartStatus,
                            AnAssignmentSummary, ATaskStatus, ATaskStatusSet,
                            ASplittingRule,
    (* PROC *)              CheckTaskValid,
                            SetCodingField, GetCodingField,
                            CreateTask,
                            RemoveTask;

FROM AsOf           IMPORT 
    (* VAR *)               AsOfDate;

FROM AssForms       IMPORT
    (* PROCS *)             CheckTaskFormResources,
                            RecomputeTaskOnForm,
                            SetupTaskFormAssignments,
                            StoreTaskFormAssignments,
                            MakeAssignmentsRateDriven,
                            ResourcesAssignedToTask;

FROM Assignments    IMPORT
    (* TYPE *)              AnAssignmentAttribute, AnAssignmentAttributeSet,
                            AnAssignmentRecord, AnAssignmentArray,
    (* PROC *)              RemoveAssignmentsAndExpenses, ForEachAssignment;

FROM BigTimeU       IMPORT
    (* VAR *)               MINBIGTIME,
    (* PROC *)              CompareBigTimes;

FROM Boxes          IMPORT
    (* TYPES *)             ABoxType, ABoxAttribute;

FROM CalShift       IMPORT
    (* VAR *)               TimeSheet;

FROM Changer        IMPORT
    (* TYPE *)              ATaskFormContext,
    (* VARS *)              AdvancedTaskForm, UsesCostTracking;

FROM ChartControl   IMPORT  AChartState, SetState, UnSetState, DisplayTheChart;

FROM Codes          IMPORT  ACode;

FROM Dialog         IMPORT  Message, FatalError, Error, Burp, WarningBox,
                            NotYetImplemented,
                            ADialogOption, ContinuationBox, MultipleChoiceBox;

FROM Duration       IMPORT
    (* PROC *)              FindDuration;

FROM Edges          IMPORT
    (* TYPE *)              AnEdge, AnEdgePtr,
    (* PROC *)              ItDepends, CheckEdgeValid, FindEdge, CreateEdge,
                            RemoveEdge, AddEdge, DelEdge;

FROM Edits          IMPORT  EditText;

FROM EffDone        IMPORT
    (* PROC *)              UpdateEffortToMatchRatio;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle,
    (* PROC *)              LockObjectArray, ReleaseObject;

FROM FormCon        IMPORT  AFieldNo;

FROM Forms          IMPORT  AForm, DoForm, AFieldValue, ACheckReason, AStringValue,
                            NullCheckProc, ShowValue, SetFieldProtection,
                            SetFormChange, FindFieldXY,
                            OpenForm, CloseForm, ACursorAttribute, HighlightField;

FROM Kbio           IMPORT  maxcol, ascreenx, ascreeny;

FROM Keys           IMPORT  ExitKey, CancelKey,
                            EditKey,
                            DeleteKey, EraseKey, EraseToEOLKey, AlternateEraseKey;

FROM Layout         IMPORT  GanttWEnd, GanttWStart;

FROM Links          IMPORT
    (* CONST *)             LinkActionForm,
    (* TYPES *)             ALinkInterface,
    (* PROCS *)             InvokeTLLink;

FROM LongDuration   IMPORT
    (* PROC *)              AppendDurationUnit;

FROM LStrings       IMPORT  Fill, SetString, ConcatS, ConcatLS, SubStr,
                            LengthOf, Overlay, LJust, TrimRear, Insert, Procustes,
                            CtoS, RJust, Compare, TrimFront, Copy, SetLengthOf;

FROM MsgFile        IMPORT  GetMessage, DisplayMessage, ConcatMessage;

FROM Overlays       IMPORT  OverlayContext, ImAnInstallableOverlay, AnOverlayID;

FROM OvTree         IMPORT
    (* TYPE *)              AnOverlayProc;

FROM ParseTime      IMPORT
    (* PROC *)              StoTimeU, StoEndTimeU;

FROM Planner        IMPORT
    (* TYPE *)              ARollupWeighting,
    (* VAR  *)              RecalcOptions;

FROM RealFormat     IMPORT
    (* VAR  *)              DefaultAmountFormat, DefaultCurrencyFormat,
    (* PROC *)              FormatAsCurrency, FormatAsAmount;

FROM RsrcMod        IMPORT 
    (* CONST *)             ResourceNameLength,
    (* TYPE  *)             ACostStyle, AResourcePointer, AResourceType,
    (* VAR   *)             ResourceTree,
    (* PROC  *)             FindResourceByName;

FROM RsrcCalc       IMPORT
    (* PROCS *)             SummTaskNodeAmounts;

FROM Space          IMPORT  HeapAvailable;

FROM StatusChange   IMPORT  
    (* PROC *)              CheckStatusChange, CheckTaskEfforts,
                            DefaultStatusDialogProc;

FROM SYSTEM         IMPORT
    (* THING *)             ADDRESS, TSIZE, ADR;

FROM Schedule       IMPORT
    (* VAR *)               FixedDateRules, ScheduleSaved;

FROM TaskProtection IMPORT
    (* CONST *)             FNM,    (*  Name            *)
                            FAU,    (*  Keyword (AUX)   *)
                            NT1,    (*  Notes 1         *)
                            FFX,    (*  Fixation        *)
                            RED,    (*  Resource/Effort Driven *)
                            FDN,    (*  Duration number *)
                            FDU,    (*  Duration units  *)
                            FEN,    (*  Effort   number *)
                            FEU,    (*  Effort   units  *)
                            SPD,    (*  Split / Delay   *) (* 6-Aug-90 RSC *)
                            FSS,    (*  Start Status    *)
                            FSD,    (*  Start date      *)
                            FED,    (*  End Date        *)
                            PCP,    (*  Percent Complete*)
                            EVD,    (*  Earned Value $  *)
                            BAS,    (*  BaseLine        *)
                            CMP,    (*  Completed       *)
                            CPP,    (*  Completed %     *)
                            YTG,    (*  Yet To Go       *)
                            YGP,    (*  Yet To Go %     *)
                            FWB,    (*  WBS Code        *)
                            FOB,    (*  OBS Code        *)
                            PRI,    (*  Priority        *)
                            SUM,    (*  Summary         *)
                            RCF,    (*  First resource conflict flag field. *)

    (* TYPE *)              ATaskFormField,
    (* VAR  *)              RecalcFields,  SortFields, RecalcRedisplay,
                            SmallProtection, RollupProtection,
    (* PROC *)              GetProtection, SetStaticProtection;


FROM Text           IMPORT  DiscardText, AssignText, TextExists, SizeOfText,
                            CopyLine, AText, Compress, CreateText, AssignLine;

FROM Timei          IMPORT
    (* TYPE *)              ADate, ADurationUnit, ADuration, ASetOfADurationUnit,
    (* VAR  *)              Today,
    (* PROC *)              TimeUtoT, TtoTimeU;

FROM TimeFormat     IMPORT
    (* PROCS *)             TimeUtoS, FormatAsEndDateStyle;

FROM Timeu          IMPORT
    (* PROC *)              UpScale, DownScale, FindCorrectScale;

FROM TimeXlate      IMPORT
    (* PROC *)              BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder, ATree,
    (* PROC *)              ValidateTreeNode;

FROM VaryAssgnment      IMPORT
    (* TYPE *)              AVaryingAssgnList,
    (* PROC *)              DisposeVaryingAssgnList;

FROM WorkHours      IMPORT
    (* PROC *)              RealTimeToWorkHours, WorkHoursToRealTime,
                            RealTimeToDuration,  DurationToRealTime;




CONST
    ModuleNumber = 3500;    (* For GetMessage - SAME # AS CHANGER FOR NOW!! *)

    MAXCARDINAL  = 0FFFFH;
    MAXDATE      = MAXCARDINAL;
    FMAXCARDINAL = 65535.0;
    ConflictCharacter = 20C;
    Zero              =   0.0;
    Ten               =  10.0;
    Point5            =   0.5;
    OneHundred        = 100.0;


   ResourcesOnForm   = 24; (* There are 3 columns, 8 rows each *)
   FieldsPerResource = 2;
   LastTaskFormField = RCF + (ResourcesOnForm * FieldsPerResource) - 1;

   StringFieldSet    = ATaskFormField{FNM,FAU,NT1,FSD,FED,EVD,BAS,CMP,CPP,YTG,YGP,FWB,FOB,SUM};
   TotalStringFields = 14; (* Total set bits in above set *)

VAR
    OverlayID               : AnOverlayID;

    RFLastFieldChanged      : CARDINAL;     (* 11-Jun-91 RSC *)
    GlobalOldStartDate      : ADate;
    GlobalOldDuration       : ADuration;    (* 24-Oct-90 RSC *)
    GlobalTaskNode          : ATreeNode;
    TaskFormProtection      : ATaskFormField;
    GlobalPCP               : CARDINAL;
    GBCWP                   : REAL;
    GlobalBaseLine          : AnAssignmentSummary;
    TaskFormNumber          : ARRAY BOOLEAN OF ARRAY BOOLEAN OF CARDINAL;
    KidsCompleted,
    KidsToGo,
    LocalCompleted,
    LocalToGo               : AnAssignmentSummary;
    GlobalStartingAchievment: CARDINAL;
    GlobalDurationMethod    : ADurationMethod;
    GlobalScale             : ADurationUnit;
    GlobalEffortScale       : ADurationUnit;
    GlobalFixation          : AFixType;
    GlobalBaselineExists    : BOOLEAN;
    GlobalForceCritical     : BOOLEAN;
    NeedsRecalc             : BOOLEAN;
    NeedsSort               : BOOLEAN;
    ThisIsASummaryTask      : BOOLEAN;
    LinkedTask              : BOOLEAN;
    NeedsFormWrapUp         : BOOLEAN;

    GlobalBaselineText      : ARRAY [0..29] OF CHAR;



    (* IsErase -- Returns TRUE iff passed one of the several codes which
       mean "erase the rest of this field."
    *)

PROCEDURE IsErase( Code : ACode ) : BOOLEAN;
BEGIN
    CASE Code OF
    | DeleteKey,
      EraseKey,
      EraseToEOLKey,
      AlternateEraseKey : RETURN TRUE;
    ELSE RETURN FALSE;
    END;
END IsErase;





PROCEDURE FormatEndDate(     Start   : ADate;
                             Dur     : ADuration;
                         VAR S       : ARRAY OF CHAR );
VAR
    End        : ADate;

BEGIN
    End := Start + Dur;

    IF (Dur > 0) THEN
        FormatAsEndDateStyle(End,S);
    ELSE
        TimeUtoS(End,S);
    END;
END FormatEndDate;








    (* AssignmentSummaryToString - Make AnAssignmentSummary printable.

          Preconditions  - Summary is a filled in assignment summary.  "Time"
                           is a huge duration, "Amount" is bucks.

                           SuggestedTimeUnit is the desired minimum time unit.
                           If it seems appropriate, I may scale this up.

                           TimeMinDecimalPlaces is the minimum number of decimal
                           places to include in the Time field.  It may be zero.

                           TimeMaxDecimalPlaces is the maximum number of decimal
                           places to include in the Time field.  It may be zero.

                           AmountDecimalPlaces is the number of digits to the
                           right of the decimal point.  If zero, no decimal
                           point is generated.

                           MaxLength is the maximum length to fill the string
                           with.  This allows FormValues, which are 80 bytes,
                           to be filled in for, say, 25 bytes.

          Postconditions - The string "s" is filled in up to MaxLength.
                           The Amount is right justified, the time is left
                           justified.
    *)

PROCEDURE AssignmentSummaryToString(
                      VAR Summary               : AnAssignmentSummary;
                          SuggestedTimeUnit     : ADurationUnit;
                          TimeMinDecimalPlaces,
                          TimeMaxDecimalPlaces,
                          AmountDecimalPlaces   : CARDINAL;
                          MaxLength             : CARDINAL;
                      VAR s                     : ARRAY OF CHAR  );

VAR
    i       : CARDINAL;
    Value   : REAL;
    s1      : ARRAY [0..81] OF CHAR;

BEGIN
    FormatAsCurrency( Summary.Amount, DefaultCurrencyFormat, s, MaxLength,
                      TRUE, (AmountDecimalPlaces > 0), TRUE );
    Copy(s,s1);
    TrimFront(s1);
    i := MaxLength - ORD(s1[0]);
    Value := WorkHoursToRealTime(Summary.Time, SuggestedTimeUnit); (* 13-Feb-88 LAA *)
    FormatAsAmount (Value, DefaultAmountFormat, s1, i, TimeMinDecimalPlaces,
                    TimeMaxDecimalPlaces, FALSE);

    TrimRear(s1);
    AppendDurationUnit(s1, SuggestedTimeUnit, Value <> 1.0);

    IF (ORD(s1[0]) > i) THEN
        SetLengthOf(s1, i);
    END;

    Overlay(s,s1,1,i);

END AssignmentSummaryToString;


    (*  UpdateLocalSummaries --
        Update the LocalCompleted and LocalToGo summaries from the 
        corresponding fields of the given task.
    *)

PROCEDURE UpdateLocalSummaries(    TaskNode : ATreeNode );

VAR
    TaskPtr                 : ATaskPtr;

BEGIN                       (* UpdateLocalSummaries *)

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    LocalCompleted := TaskPtr^.CompletedSummary;
    LocalToGo      := TaskPtr^.ToGoSummary;
    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

END UpdateLocalSummaries;



 (* Check Task Data - Check the Task Form.

        Preconditions  - The Values have been set up for the Task Form OR
                         the Summary Task Form.

        Postconditions - The Values have been edited as per the rules in DoForm.
                         This Check Proc works for both the TaskForm and
                         the SummaryTaskForm.  The first few fields are
                         treated a little differently, as the summary form
                         has these fields protected and formatted as strings.
  *)


PROCEDURE CheckTaskData (     Form          : AForm;
                              FieldNo       : AFieldNo;
                          VAR FormValue     : ARRAY OF AFieldValue;
                              CheckReason   : ACheckReason;
                          VAR Code          : CARDINAL ):BOOLEAN;
VAR
    LCode                   : CARDINAL;
    TheDuration             : ADuration;
    DurationScale,
    EffortScale             : ADurationUnit;
    Result,
    Changed,
    DurationOverflow        : BOOLEAN;




    PROCEDURE MaybeCalcSpent(     PercentComplete : CARDINAL );

    VAR
        Task                    : ATaskPtr;

    BEGIN                       (* MaybeCalcSpent *)

        IF (NOT LinkedTask) THEN (* not a rollup task? *)
            MapFormToTask( FormValue, GlobalTaskNode );  
            IF (NOT UsesCostTracking) THEN
                Task  := GlobalTaskNode^.Methods^.LockFlexStorDataObject(GlobalTaskNode);
                UpdateEffortToMatchRatio(Task^, FLOAT(Task^.PercentComplete)/OneHundred);
                GlobalTaskNode^.Methods^.UnlockFlexStorDataObject(GlobalTaskNode);
            END;
            MapTaskToForm( FormValue, GlobalTaskNode, FALSE );
        END;

    END MaybeCalcSpent;



    PROCEDURE SetProperRollupProtection();
    VAR
        Loop       : CARDINAL;
    BEGIN

    (* Set the static protection as if there were no rollup restrictions *)

        SetStaticProtection( AdvancedTaskForm,
                             ThisIsASummaryTask,
                             FALSE,                 (* RollupTask? *)
                             TaskFormProtection );

    (* Set or clear protections that are unique to rollups: *)

        FOR Loop := FNM TO RCF DO
            IF ((NOT ( Loop IN TaskFormProtection)) AND
                     ( Loop IN RollupProtection  )) THEN
                SetFieldProtection( Form, Loop, FormValue, LinkedTask );
            END;
        END;

    (*  If a link task, protect the resource fields.  *)

        FOR Loop := RCF+1 TO LastTaskFormField BY 2 DO      (* 5/26/89 EGK *)
            SetFieldProtection( Form, Loop, FormValue, LinkedTask );
        END;

    (* Finally, set the protections properly. *)

        SetStaticProtection( AdvancedTaskForm,
                             ThisIsASummaryTask,
                             LinkedTask,
                             TaskFormProtection );
        SetProtection();

    END SetProperRollupProtection;




    (* If the field is invisible (small form or invisible summary fields),
       then do not attempt to redisplay the value.
    *)
    PROCEDURE MaybeShowValue( Field : CARDINAL );
    BEGIN
        IF (AdvancedTaskForm) THEN
            IF NOT (ThisIsASummaryTask AND (Field = PCP)) THEN
                ShowValue( Form, Field, FormValue );
            END;
        ELSIF (NOT (Field IN SmallProtection)) THEN
            ShowValue( Form, Field, FormValue );
        END;
    END MaybeShowValue;


    (* If the field is invisible (small form or invisible summary fields),
       then do not attempt to protect or unprotect it.
    *)
    PROCEDURE MaybeSetProtection( Field : CARDINAL; Protect : BOOLEAN );
    BEGIN
        IF (NOT (Field IN TaskFormProtection)) THEN
            SetFieldProtection( Form, Field, FormValue, Protect );
        END;
    END MaybeSetProtection;



    (* A Note about edit rules for START DATE, END DATE, AND DURATION:

      IF StartDate is BLANK,

          AND THEY CHANGE            WE UPDATE
          ---------------            -----------
          Start Date                 End Date
          Duration                   Start Date
          End Date                   Start Date
          *nothing*                  *nothing*  (* 15-Jan-92 TGS *)

      ELSE (if it is NOT BLANK),

          AND THEY CHANGE            WE UPDATE
          ---------------            -----------
          Start Date                 End Date
          Duration                   End Date
          End Date                   Duration   IFF duration driven,
          End Date                   StartDate  IFF effort driven.
    *)
    PROCEDURE CheckStartDate():BOOLEAN;
    VAR
        schedstart         : ADate;
        s                  : ARRAY [0..29]  OF CHAR;
    BEGIN
        DurationScale := VAL(ADurationUnit,FormValue[FDU].CardValue);
        TheDuration   := RealTimeToDuration(FormValue[FDN].RealValue,DurationScale);

        schedstart := FormValue[FSD].CardValue;
        Copy(FormValue[FSD].CharValue^,s);
        TrimFront(s);
        IF (s[0] = 0C) THEN
            (* 15-Jan-92 TGS Do nothing -- wait for something else to change
            FormValue[FSD].CardValue := Today; (* Empty start date *)
            *)
        ELSIF (NOT StoTimeU(s,schedstart)) THEN
            RETURN FALSE;
        ELSIF (schedstart > MAXCARDINAL - TheDuration) THEN
            DisplayMessage(ModuleNumber+1);             (*  "Task would run longer than calendar."  *)
            RETURN FALSE;
        ELSE
            FormValue[FSD].CardValue := schedstart;
            FormValue[FED].CardValue := schedstart + TheDuration;
            FormatEndDate(schedstart,TheDuration,FormValue[FED].CharValue^);
            TimeUtoS(schedstart,FormValue[FSD].CharValue^);
            RecomputeTask( TheDuration );
            ShowNormalizedDuration( TheDuration, DurationScale );
            ShowDateGroup();
        END;
        RETURN TRUE;
    END CheckStartDate;



    PROCEDURE RecomputeTask( VAR Duration : ADuration );
    VAR
        Task            : ATaskPtr;
        AssignmentArray : AnAssignmentArray;
        i, Loop         : CARDINAL;
    BEGIN

        IF (NOT LinkedTask) THEN (* not a rollup task? *)

            MapFormToTask( FormValue, GlobalTaskNode );  (* Fill in new task values. *)

            RecomputeTaskOnForm( GlobalTaskNode );

            (* 16-Apr-92 TGS We changed something. Can't trust any Varying
                Assignment records any more, so blast 'em. *)          
            Task  := GlobalTaskNode^.Methods^.LockFlexStorDataObject(GlobalTaskNode);
            WITH Task^ DO

                Loop := LockObjectArray( Plan.Assignments,
                                         AssignmentArray, 
                                         TSIZE( AnAssignmentRecord ) );
            END;
            GlobalTaskNode^.Methods^.UnlockFlexStorDataObject(GlobalTaskNode);

            i := 0;
(*$O-*)
            WHILE (i < Loop) DO
                WITH AssignmentArray^[i] DO
                    IF ( VaryingAssignment <> AVaryingAssgnList(NIL) ) THEN (* 6-Apr-92 TGS *)
                        DisposeVaryingAssgnList(VaryingAssignment);
                        VaryingAssignment := AVaryingAssgnList(NIL);
                    END;
                END;
                INC(i);
            END;
(*$O=*)
            ReleaseObject( Task^.Plan.Assignments );

            MapTaskToForm( FormValue, GlobalTaskNode, FALSE );     (* 03-Oct-91 *)
            Duration := RealTimeToDuration(FormValue[FDN].RealValue,VAL(ADurationUnit,FormValue[FDU].CardValue));
            RedisplayEfforts(LocalCompleted, LocalToGo);
        END;

    END RecomputeTask;



    PROCEDURE RedisplayEfforts(VAR Completed, ToGo : AnAssignmentSummary);
    VAR
        TCompleted, TToGo : AnAssignmentSummary;
        Loop              : CARDINAL;
    BEGIN
        TCompleted.Time   := Completed.Time   + KidsCompleted.Time;
        TCompleted.Amount := Completed.Amount + KidsCompleted.Amount;
        TToGo.Time        := ToGo.Time        + KidsToGo.Time;
        TToGo.Amount      := ToGo.Amount      + KidsToGo.Amount;

        EffortScale       := VAL(ADurationUnit,FormValue[FEU].CardValue);
        AssignmentSummaryToString(
                          TToGo, EffortScale,
                          0,2, 0,                     (* Min, Max, Pennies *)
                          22,                         (* Field Width *)
                          FormValue[YTG].CharValue^ );
        AssignmentSummaryToString(
                          TCompleted, EffortScale,
                          0,2, 0,                     (* Min, Max, Pennies *)
                          22,                         (* Field Width *)
                          FormValue[CMP].CharValue^ );
        FormValue[ FEN ].RealValue := WorkHoursToRealTime( TCompleted.Time + TToGo.Time,
                                                          EffortScale );
        MapEarnedValue( FormValue, GBCWP, TCompleted, TToGo, EffortScale );
        FOR Loop := FNM TO RCF DO
            IF (Loop IN RecalcRedisplay) THEN
                MaybeShowValue( Loop );
            END;
        END;
    END RedisplayEfforts;



    PROCEDURE CheckDuration();
    VAR schedstart : CARDINAL;
    BEGIN
        schedstart    := FormValue[FSD].CardValue;
        DurationScale := VAL(ADurationUnit,FormValue[FDU].CardValue);
        TheDuration   := RealTimeToDuration(FormValue[FDN].RealValue,DurationScale);
        IF (TheDuration = 0) AND (FormValue[FDN].RealValue <> Zero) THEN
            TheDuration := 1; (* Did they enter something too small?  Bump it. *)
        END;

        (* Do show normalized duration twice so we get the benefit of the
           checking for out-of-calendar durations BEFORE recalcing.
           Otherwise, duration and effort can appear to be out of synch.
        *)
        ShowNormalizedDuration( TheDuration, DurationScale );
        RecomputeTask( TheDuration );
        ShowNormalizedDuration( TheDuration, DurationScale );
    END CheckDuration;


    (* For those who care, DurationOverflow is set as a side effect of this
       procedure.  Use it to test for absurd values. *)

    PROCEDURE ShowNormalizedDuration( VAR Duration : ADuration; VAR Scale : ADurationUnit );
    VAR schedstart : CARDINAL;
        ok         : BOOLEAN;
    BEGIN
        schedstart := FormValue[FSD].CardValue;
        IF (schedstart > (MAXDATE - Duration)) THEN
            DisplayMessage(ModuleNumber+1);             (*  "Task would run longer than calendar."  *)
            Burp;
            Duration := (MAXDATE - schedstart);
            DurationOverflow := TRUE;
        ELSE
            DurationOverflow := FALSE;
        END;
        WITH FormValue[FDN] DO
            RealValue := DurationToRealTime(Duration,Scale);
            WHILE (RealValue > 9999.0) AND (Scale < Months) DO
                INC(Scale);
                RealValue := DurationToRealTime(Duration,Scale);
            END;
            FormValue[FDU].CardValue := ORD(Scale);
        END;
        WITH FormValue[FSD] DO
            TrimRear(CharValue^);
            IF (LengthOf(CharValue^) = 0) THEN
                ok := CheckEndDate();
            ELSE
                FormatEndDate(CardValue,Duration,FormValue[FED].CharValue^);
            END;
        END;
        MaybeShowValue( FDN );
        MaybeShowValue( FDU );
        ShowDateGroup();
        FormValue[FDN].CardValue := Duration;
        GlobalScale              := Scale;
    END ShowNormalizedDuration;



    PROCEDURE MaybeAlterDuration();
    VAR
        StartProtection,
        EndProtection,
        EffortProtection,
        DurationProtection : BOOLEAN;
    BEGIN
        GetProtection( StartProtection, EndProtection, EffortProtection,
                       DurationProtection,
                       TaskFormProtection,
                       VAL(AFixType,        FormValue[FFX].CardValue),
                       VAL(AStartStatus,    FormValue[FSS].CardValue),
                       VAL(ADurationMethod, FormValue[RED].CardValue) );

        (* If the duration field is protected, then scale the number in that
           field by the new scale value.  Otherwise just note the change.
        *)

        DurationScale := VAL(ADurationUnit,FormValue[FDU].CardValue);
        IF (DurationProtection) THEN
          (* Get old duration, so we don't alter it. *)
            TheDuration := FormValue[FDN].CardValue;
            ShowNormalizedDuration( TheDuration, DurationScale );
        ELSE
            CheckDuration();
        END;
    END MaybeAlterDuration;






    PROCEDURE CheckEffort() : BOOLEAN;
    VAR
        Effort      : REAL;
        ok          : BOOLEAN;
    BEGIN
        ok             := TRUE;
        EffortScale    := VAL(ADurationUnit,FormValue[FEU].CardValue);
        Effort         := RealTimeToWorkHours(FormValue[FEN].RealValue,EffortScale);
        LocalToGo.Time := Effort - LocalCompleted.Time;
        TheDuration    := FormValue[FDN].CardValue;
        RecomputeTask( TheDuration );
        DurationScale := VAL(ADurationUnit,FormValue[FDU].CardValue);
        ShowNormalizedDuration( TheDuration, DurationScale );
        FormValue[FDN].CardValue := TheDuration;
        RETURN (ok AND (NOT DurationOverflow));
    END CheckEffort;




    PROCEDURE MaybeAlterEffort() : BOOLEAN;
    VAR
        Effort             : REAL;
        StartProtection,
        EndProtection,
        EffortProtection,
        DurationProtection : BOOLEAN;
        ok                 : BOOLEAN;
    BEGIN
        ok := TRUE;
        GetProtection( StartProtection, EndProtection, EffortProtection,
                       DurationProtection,
                       TaskFormProtection,
                       VAL(AFixType,        FormValue[FFX].CardValue),
                       VAL(AStartStatus,    FormValue[FSS].CardValue),
                       VAL(ADurationMethod, FormValue[RED].CardValue) );

        (* If the duration field is protected, then scale the number in that
           field by the new scale value.  Otherwise just note the change.
        *)

        EffortScale := VAL(ADurationUnit,FormValue[FEU].CardValue);
        Effort      := KidsCompleted.Time  + KidsToGo.Time +
                       LocalCompleted.Time + LocalToGo.Time;
        IF (EffortProtection) THEN
            FormValue[FEN].RealValue := WorkHoursToRealTime(Effort,EffortScale);
            MaybeShowValue( FEN );
            RedisplayEfforts(LocalCompleted, LocalToGo); (* RSC 2/24/88 *)
        ELSE
            Effort  := RealTimeToWorkHours( WorkHoursToRealTime( Effort, GlobalEffortScale ), EffortScale );
            FormValue[FEN].RealValue := WorkHoursToRealTime(Effort,EffortScale);
            ok      := CheckEffort();
        END;
        GlobalEffortScale := EffortScale;
        RETURN ok;
    END MaybeAlterEffort;





    PROCEDURE CheckEndDate():BOOLEAN;
    VAR
        schedstart      : ADate;
        enddate         : ADate;
        Year,Month,Day,Hour,Minute : CARDINAL;
        s               : ARRAY [0..29]  OF CHAR;

        PROCEDURE GetEndDate( VAR S       : ARRAY OF CHAR;
                              VAR enddate : ADate):BOOLEAN;
        VAR
            SaveDate : ADate;
            ok       : BOOLEAN;
        BEGIN
            (* Milestones can match the start date. *)

            (* 19-Sep-89 RSC  StoEndTimeU needs a default date, the
                              start date.  We must preserve the passed-in
                              default date because StoTimeU assumes different
                              defaults.  For example, if, in September, you
                              say:

                                START DATE: JUNE
                                END DATE:   JULY

                              June assumes NEXT year, July assumes THIS year
                              for start dates, NEXT year for end dates.
            *)
            SaveDate := enddate;

            ok := ((TheDuration = 0) AND
                   (StoTimeU(S,enddate)) AND
                   (enddate = schedstart));

            IF (NOT ok) THEN
                enddate := SaveDate;
                ok      := StoEndTimeU(S,enddate);
            END;

            RETURN ok;

        END GetEndDate;


    BEGIN
            (*  Check if the start date is blank. *)
        Copy(FormValue[FSD].CharValue^,s);
        TrimFront(s);
            (*  Find the ostensive scheduled start. *)
        schedstart    := FormValue[FSD].CardValue;
        enddate       := schedstart;
        DurationScale := VAL(ADurationUnit,FormValue[FDU].CardValue);
        TheDuration   := RealTimeToDuration(FormValue[FDN].RealValue,DurationScale);
        TrimRear(FormValue[FED].CharValue^);
        IF (FormValue[FED].CharValue^[0] = 0C) THEN
            FormatEndDate(schedstart,TheDuration,FormValue[FED].CharValue^);
        ELSIF NOT ( GetEndDate(FormValue[FED].CharValue^,enddate)) THEN
            RETURN FALSE;
        ELSIF (s[0] = 0C) THEN (* Start date is blank *)
            FormValue[FED].CardValue := enddate;
            schedstart               := enddate - TheDuration;
            FormValue[FSD].CardValue := schedstart;
            TimeUtoS( schedstart, FormValue[FSD].CharValue^ );
        ELSIF (enddate < schedstart) THEN
            DisplayMessage(ModuleNumber+2);    (*  "End before begin??  (To compute start date, leave it blank.) *)
            RETURN FALSE;
        ELSE (* 24-Aug-91 TGS This is for Effort/Done tasks now, too.. *)
            FormValue[FED].CardValue := enddate;
            TheDuration              := enddate - schedstart;
            FindCorrectScale(TheDuration,DurationScale);
            FormValue[FDU].CardValue := ORD(DurationScale);
            FormValue[FDN].RealValue := DurationToRealTime(TheDuration,DurationScale);
            FormatEndDate(schedstart,TheDuration,FormValue[FED].CharValue^);
        END;
        RecomputeTask( TheDuration );
        ShowNormalizedDuration( TheDuration, DurationScale );
        ShowDateGroup();
        RETURN TRUE;
    END CheckEndDate;



    PROCEDURE SetProtection();
    VAR StartProtection,
        EndProtection,
        EffortProtection,
        SplitProtection,
        DurationProtection : BOOLEAN;
        StartStatus        : AStartStatus;
    BEGIN
        StartStatus := VAL(AStartStatus,    FormValue[FSS].CardValue);

        GetProtection( StartProtection,
                       EndProtection,
                       EffortProtection,
                       DurationProtection,
                       TaskFormProtection,
                       VAL(AFixType,        FormValue[FFX].CardValue),
                       StartStatus,
                       VAL(ADurationMethod, FormValue[RED].CardValue) );

        SplitProtection := ((StartStatus = DoneS) OR (StartStatus = StartedS))
                           AND
                           (VAL(ADurationMethod, FormValue[RED].CardValue)
                              = DurationDriven); (* 30-Apr-91 TGS *)

        MaybeSetProtection(FSD,StartProtection);
        MaybeSetProtection(FED,EndProtection);
        MaybeSetProtection(FDN,DurationProtection);
        MaybeSetProtection(FEN,EffortProtection);
        MaybeSetProtection(SPD,SplitProtection);
    END SetProtection;



    PROCEDURE ShowDateGroup();
    BEGIN
        MaybeShowValue(FSD);
        MaybeShowValue(FED);
        MaybeShowValue(FDN);
        MaybeShowValue(FEN);
    END ShowDateGroup;


    PROCEDURE SetPercentComplete();
    VAR Status : AStartStatus;
    BEGIN        (* SetPercentComplete *)
        IF (NOT ThisIsASummaryTask) THEN
            Status := VAL(AStartStatus, FormValue[FSS].CardValue);
            IF (Status = DoneS) THEN
                FormValue[PCP].CardValue := 100;
            ELSIF ((Status = FutureS) AND (NOT AdvancedTaskForm)) THEN (* RSC 2/24/88 *)
                FormValue[PCP].CardValue := 0;
            ELSE
                FormValue[PCP].CardValue := GlobalPCP;
            END;
            MaybeShowValue(PCP);
            (*                                                 08-Oct-91
            RecomputeTask( FormValue[FDN].CardValue );
            *)
            MaybeCalcSpent( FormValue[PCP].CardValue );
        END;
    END SetPercentComplete;

        (* SetStartStatus -- After a change to the percent achieved 
                             field, propose a matching start status.
                              
                             We do not force the start status because 
                             there are some useful tricks that a user 
                             might want to do by marking a task that
                             is partly achieved as still future, for  
                             example, to suppress the splitting of the
                             task bars.  *) 



    PROCEDURE SetStartStatus( PercentComplete :  CARDINAL );
    TYPE
        AStartStatusSet = SET OF AStartStatus;
    VAR 
        Text : ARRAY [0..255] OF CHAR;
        Title: ARRAY [0..1] OF CHAR;
        Choices: ARRAY [0..79] OF CHAR; 
        Choice : CARDINAL;
        Status, DesiredStatus : AStartStatus; 
        OKSet : AStartStatusSet;
    BEGIN 
        IF (NOT ThisIsASummaryTask) THEN
            Status := VAL(AStartStatus, FormValue[FSS].CardValue);
                (* Valid start statusses: 
                       0      : Future or Started,
                       1..99  : Started 
                       100    : Done
                *)
            IF ( PercentComplete = 0 ) THEN 
                DesiredStatus := FutureS; 
                OKSet := AStartStatusSet{FutureS,StartedS}; 
            ELSIF (PercentComplete = 100 ) THEN 
                DesiredStatus := DoneS; 
                OKSet := AStartStatusSet{DoneS};
            ELSE
                DesiredStatus := StartedS;
                OKSet := AStartStatusSet{StartedS}; 
            END;

            IF (NOT (Status IN  OKSet)) THEN
                GetMessage(ModuleNumber + 82, Text );  (* Task status is *) 
                SetLengthOf(Title,0); 
                GetMessage(27302, Choices );           (* Future,Started,Done *)
                Choice := ORD(DesiredStatus)+1; 
                IF MultipleChoiceBox(Text,Title,NoHelp,Title, 
                                     Choices,Choice) THEN 
                    FormValue[FSS].CardValue := ORD(Choice)-1;
                    MaybeShowValue(FSS);
                    (* RecomputeTask( FormValue[FDN].CardValue ); 08-Oct-91 *)
                    SetProtection();
                END;
            END;

        END;
    END SetStartStatus; 


    PROCEDURE SaveNotesToText();
    VAR
        TaskPtr         : ATaskPtr;
        s               : ARRAY [0..255] OF CHAR;
    BEGIN                      (* SaveNotesToText *)
        TaskPtr       := GlobalTaskNode^.Methods^.LockFlexStorDataObject( GlobalTaskNode );

        TrimRear(FormValue[NT1].CharValue^);
        IF (ADDRESS(TaskPtr^.notes) = NIL) THEN
            IF (FormValue[NT1].CharValue^[0] = 0C) THEN
                GlobalTaskNode^.Methods^.UnlockUnchangedDataObject( GlobalTaskNode );   (* RSC 7-Jun-89 *)
                RETURN;
            ELSE
                TaskPtr^.notes := CreateText();
            END;
        END;
        IF NOT AssignLine(FormValue[NT1].CharValue^, 0, TaskPtr^.notes) THEN
            GetMessage(ModuleNumber + 28, s); (* "Can't save notes.  Memory?" *)
            Error(s);
        END;

        GlobalTaskNode^.Methods^.UnlockFlexStorDataObject( GlobalTaskNode );

    END SaveNotesToText;



    PROCEDURE DoTaskLinkForm();
    VAR
        TaskPtr         : ATaskPtr;
        LinkInterface   : ALinkInterface;
    BEGIN
        HighlightField(Form,FormValue,FieldNo, CursorResting);

        WITH LinkInterface DO
            TaskNode      := NIL;              (* None, really. *)
            TaskPtr       := GlobalTaskNode^.Methods^.LockFlexStorDataObject( GlobalTaskNode );
            LinkText      := TaskPtr^.summarizes;
            GlobalTaskNode^.Methods^.UnlockUnchangedDataObject( GlobalTaskNode );
            DesiredAction := LinkActionForm;   (* Do the Link Form *)
        END;

        InvokeTLLink( LinkInterface );

        WITH LinkInterface DO
            IF (CompletedOK) AND (ChangesMade) THEN

                TaskPtr             := GlobalTaskNode^.Methods^.LockFlexStorDataObject( GlobalTaskNode );
                TaskPtr^.summarizes := LinkText;
                LinkedTask          := (ADDRESS(LinkText) <> NIL);
                GlobalTaskNode^.Methods^.UnlockFlexStorDataObject( GlobalTaskNode );

                IF (LinkedTask) THEN
                    SetString( FormValue[SUM].CharValue^, "*" ); (* 30-Apr-91 TGS *)
                    FormValue[FFX].CardValue := ORD(FixedDate);
                    FormValue[RED].CardValue := ORD(DurationDriven);   (* 23-Sep-90 RSC *)
                    FormValue[SPD].CardValue := ORD(Split);     (* 9/27/91 EGK *)
                    NeedsRecalc := TRUE;
                ELSE
                    SetString( FormValue[SUM].CharValue^, " " );
                END;
                SetProperRollupProtection();
                MaybeShowValue( SUM );
                MaybeShowValue( RED );  (* 23-Sep-90 RSC *) 
                MaybeShowValue( FFX );
                MaybeShowValue(SPD);        (* 9/27/91 EGK *)
                SetFormChange( Form );
            END;
        END;

        HighlightField(Form,FormValue,FieldNo, CursorOff);
    END DoTaskLinkForm;



    (* Exit key has been hit. *)

    PROCEDURE FormWrapUp() : BOOLEAN;
    VAR 
        Duration        : ADuration;
        Choice          : CARDINAL;
        s               : ARRAY [0..255]  OF CHAR;
        s1              : ARRAY [0..79]  OF CHAR;
        Title           : ARRAY [0..1]  OF CHAR;
        Prefix          : ARRAY [0..20] OF CHAR;
        StartStatus     : AStartStatus;
        ThisIsAKidTask  : BOOLEAN;
        GoodAss         : BOOLEAN;
        OK              : BOOLEAN;
        StartProtection,
        EndProtection,
        EffortProtection,
        SplitProtection,
        DurationProtection : BOOLEAN;
    BEGIN
        (* 21-Nov-89 RSC removed task name check because its done on field exit *)

        IF (LinkedTask) THEN (* Rollups don't get checked *)
            RETURN TRUE;
        END;

        GoodAss := ResourcesAssignedToTask();   (* 23-Sep-90 RSC *) 


        (* RSC 21-Nov-89 If they entered effort but no resources,
                         tell them they have troubles ahead.
        *)
        IF (NOT GoodAss)                                    AND
           (FormValue[RED].CardValue = ORD(EffortDriven))   THEN
            IF (NOT ThisIsASummaryTask)             AND
               (FormValue[FEN].RealValue <> Zero)   THEN
                GetMessage( ModuleNumber + 33, s  ); (* "You entered effort, but no resources." *)
                GetMessage( ModuleNumber + 34, s1 ); (* "No Rsrcs, No Effort" *)
                WarningBox( s, s1, OfferHelp );
                FormValue[FDN].RealValue := FormValue[FEN].RealValue; (* 19-Feb-91 TGS *)
                FormValue[FDU].CardValue := FormValue[FEU].CardValue;
                FormValue[FEN].RealValue := Zero;
            END;
            FormValue[RED].CardValue := ORD(DurationDriven);
            RecomputeTask( Duration );
        END;



        (* If there is no baseline and this is a kid of a parent and
           the customer changed achievement, warn them. RSC 11/6/87.
           Or, if there are no resources. RSC 2/25/88.
           Expanded Apr. 3, 92, AJL.
         *)
        ThisIsAKidTask := (GlobalTaskNode^.Methods^.Parent( GlobalTaskNode ) <> NIL);


        IF (AdvancedTaskForm) AND
           (GlobalStartingAchievment <> FormValue[PCP].CardValue) AND
           (ThisIsAKidTask  OR (NOT GoodAss))                     AND
           (RecalcOptions.RollupWeighting < RollDuration)         THEN

            IF ((RecalcOptions.RollupWeighting < RollEffort) AND
                (NOT GlobalBaselineExists))
               OR
               ((RecalcOptions.RollupWeighting = RollEffort) AND
                (NOT GoodAss))                                    THEN
                GetMessage( ModuleNumber + 31, s  ); (* "achievement cannot roll up unless baseline set." *)
                GetMessage( ModuleNumber + 32, s1 ); (* "Achieved but no Baseline" *)
                WarningBox( s, s1, OfferHelp );
            END;
        END;

        (*
        14-Aug-91 TGS   Check enterable Start Date on form exit. If task is
                        StartedS or DoneS, and it is less than AsOfDate, get
                        confirmation.
                        If Start Date is okay, check enterable End Date on
                        DoneS tasks to see if it is before AsOfDate.
        21-Aug-91 TGS   If they accept an "inconsistent" start date, don't
                        bother complaining about the end date, which'll also
                        be inconsistent.
        *)

        GetProtection( StartProtection, EndProtection,
                       EffortProtection, DurationProtection, TaskFormProtection,
                       VAL(AFixType,        FormValue[FFX].CardValue),
                       VAL(AStartStatus,    FormValue[FSS].CardValue),
                       VAL(ADurationMethod, FormValue[RED].CardValue) );

        IF (NOT StartProtection)                        AND
           (FormValue[FSS].CardValue <> ORD(FutureS))   AND
           (FormValue[FSD].CardValue > AsOfDate)        THEN

            (* "Inconsistent Start Date" *)
            GetMessage(ModuleNumber + 83, s);
            SetLengthOf(Title, 0);
            IF NOT ContinuationBox(s, Title, NoHelp) THEN
                RETURN FALSE; (* They want to fix it, go back to form *)
            END;

        ELSIF (NOT EndProtection)                       AND
              (FormValue[FSS].CardValue = ORD(DoneS))   AND
              (FormValue[FED].CardValue > AsOfDate)     THEN

            (* "Inconsistent End Date" *)
            GetMessage(ModuleNumber + 84, s);
            SetLengthOf(Title, 0);
            IF NOT ContinuationBox(s, Title, NoHelp) THEN
                RETURN FALSE; (* They want to fix it, go back to form *)
            END;
        END;


        (* 21-Aug-91 TGS *)
        IF (FormValue[FSS].CardValue = ORD(FutureS))    AND
           (FormValue[PCP].CardValue <> 0)              THEN
            SetLengthOf(Title, 0);
            GetMessage(ModuleNumber + 85, s);   (* "The task is Future, but.." *)
            GetMessage(ModuleNumber + 86, Prefix); (* "Should I:" *)
            GetMessage(ModuleNumber + 87, s1);  (* Set to Zero, Continue without changing, Cancel *)
            Choice := 1; 
            IF MultipleChoiceBox(s, Title, NoHelp, Prefix, s1, Choice) THEN 
                CASE Choice OF
                    1 : (* Set achievment to zero *)
                        FormValue[PCP].CardValue := 0;
                        |
                    2 : (* Accept entered values *)
                        |
                    3 : (* Cancel, return to form *)
                        RETURN FALSE;
                    ELSE
                END;
            ELSE
                RETURN FALSE;
            END;
        END;

        (* 29-Apr-91 TGS *)
        IF CheckTaskEfforts(GlobalTaskNode,  TRUE,
                            LocalCompleted,  LocalToGo)                AND
           CheckStatusChange(GlobalTaskNode, DefaultStatusDialogProc)  THEN
            UpdateLocalSummaries( GlobalTaskNode);  (* 18-Feb-92 TGS *)
            IF MaybeAlterEffort() THEN
                UpdateLocalSummaries( GlobalTaskNode );
            ELSE
                RETURN FALSE;
            END;
                             
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END;

    END FormWrapUp;


    PROCEDURE AssignmentForms() : BOOLEAN;
    VAR
        Map,
        Check,
        Dur,        
        ok                 : BOOLEAN;

    BEGIN
        IF (IsErase(LCode)) THEN
            Code := LCode + CARDINAL({14});
            RETURN TRUE;
        END;

        (* Only do the expensive mapping when needed.  A side effect of
           this mapping is that the LocalCompleted/LocalToGo are ajusted,
           and so we must be sure that we do a recalc of the task in order
           to correctly ajust the task's CompletedSummary/ToGoSummary.
           Otherwise, summary tasks get their effort numbers screwed up.

               This is not a good long-term solution.
        *)
        (* 27-Sep-91 TGS 
            Added another BOOLEAN, "Dur", to help figure out when to run
            CheckDuration and when not to. In TL4, this depended mostly on 
            the values of Check and Map, but it caused local recalcs to
            happen right and left. I fixed this previously with a lot of
            conditionals, but this will simplify the logic a bit and fix
            one remaining problem (resource field prompts were not updating).
        *)
        Check := TRUE;      (* Do we check assignments?   *)
        Map   := TRUE;      (* Do we map the task record? *)
        Dur   := FALSE;     (* Do we CheckDuration?       *)
        ok    := TRUE;      (* What should we return?     *)

        CASE CheckReason OF

        | CheckFormExit   :

            IF (FieldNo <> (RCF + 1)) THEN
                Check := FALSE;
                Map   := FALSE;
            END;

        | CheckFormEntry  :

            Check := FALSE;
            Map   := FALSE;

        | CheckFieldEntry :  
            (* No mapping of the task node, just CheckTask.. to update field prompts *)
            Map   := FALSE;

        | CheckFieldExit  :  (* 11-Jun-91 RSC moved from after CheckFormEntry. *)

                (* 11-Jun-91 RSC And added this test
                *)
            IF (RFLastFieldChanged <> FieldNo) THEN

                Check := FALSE;
                Map   := FALSE;
            ELSE
                Dur   := TRUE;
            END;

        | CheckFieldChange :

            RFLastFieldChanged := FieldNo;
            NeedsFormWrapUp := TRUE;        (* 9/18/91 EGK *)
            Dur := TRUE;
        ELSE
        END;

        IF (Map) THEN
            MapFormToTask( FormValue, GlobalTaskNode );  (* Fill in new task values. *)
        END;

        IF (Check) THEN
            ok :=        CheckTaskFormResources(Form,
                                                FieldNo,
                                                RCF,
                                                FormValue,
                                                CheckReason,
                                                LCode,
                                                GlobalTaskNode
                                               );
            Code := LCode;
        END;

        IF (Map) THEN
            MapTaskToForm( FormValue, GlobalTaskNode, FALSE );    (* 03-Oct-91 *)
        END;

            (* 2-Sep-91 TGS *)
            (* Don't do this until we get something good from 
               CheckTaskFormResources *)
        IF (Dur) AND (ok) THEN
            CheckDuration();
        END;

            (* See the comment at the beginning of this sub-procedure.
               For summary tasks, there is an unpleasant side effect of
               the complementary MapFormToTask and MapTaskToForm here,
               namely that the task's CompletedSummary and ToGoSummary
               are wrong.  For summary tasks, we use the "old" check
               that we used in TL4, which seems to work better.
            *)

        IF (ThisIsASummaryTask) AND (Map OR Check) THEN     (* 10/2/91 EGK *)
            CheckDuration();
        END;

        RETURN ok;

    END AssignmentForms;


    PROCEDURE DeleteSummarizes() : BOOLEAN;
    VAR
        TaskPtr         : ATaskPtr;
        s               : ARRAY [0..255] OF CHAR;
        NullString      : ARRAY [0..0] OF CHAR;
    BEGIN
        WITH FormValue[SUM] DO
            IF (LinkedTask) THEN
                GetMessage(ModuleNumber + 30, s  ); (* "Do you realy want to remove the link?" *)
                SetLengthOf(NullString, 0);
                IF ( NOT ContinuationBox (s, NullString, NoHelp) ) THEN
                    RETURN FALSE;
                END;

                TaskPtr   := GlobalTaskNode^.Methods^.LockFlexStorDataObject( GlobalTaskNode );
                DiscardText( TaskPtr^.summarizes );
                GlobalTaskNode^.Methods^.UnlockFlexStorDataObject( GlobalTaskNode );

                LinkedTask := FALSE;

                SetLengthOf( CharValue^, 0 );
                SetProperRollupProtection();
                ShowValue( Form, SUM, FormValue );
                SetFormChange( Form );
            END;
        END;
        RETURN TRUE;
    END DeleteSummarizes;


    PROCEDURE EditNotesField();
    VAR
        TaskPtr  : ATaskPtr;
        Cursorx  : ascreenx;
        Starty,
        Endy,
        Cursory  : ascreeny;
        Endx     : ascreenx;
    BEGIN

        HighlightField(Form,FormValue,FieldNo, CursorResting);
        FindFieldXY( Form, FieldNo, 1, Cursorx, Cursory, Endx ); (* RSC 26-Jun-89 *)
        DEC(Cursory, 2);
        Starty := GanttWStart;
        Endy   := Cursory;
        IF (Endy <= (Starty + 6)) THEN
            Endy   := GanttWEnd;
            Starty := Cursory+2;
        END;
        SaveNotesToText();
        TaskPtr   := GlobalTaskNode^.Methods^.LockFlexStorDataObject( GlobalTaskNode );
        WITH FormValue[FNM] DO
            LJust (CharValue^);
            TrimRear (CharValue^);
            EditText(12,Starty,77,Endy, ABoxType{ShadowBox, DoubleBox}, CharValue^, 0, TaskPtr^.notes, Changed);
        END;
        IF (Changed) THEN
            SetFormChange( Form );
        END;
        SetLengthOf(FormValue[NT1].CharValue^, 0);
        IF (ADDRESS(TaskPtr^.notes) <> NIL) THEN
            CopyLine(TaskPtr^.notes, 0, FormValue[NT1].CharValue^);
        END;
        GlobalTaskNode^.Methods^.UnlockFlexStorDataObject( GlobalTaskNode );
        MaybeShowValue(NT1);
        HighlightField(Form,FormValue,FieldNo, CursorOff );

    END EditNotesField;




    PROCEDURE CopyDateToTask( VAR FormValue : ARRAY OF AFieldValue );
    VAR
        TaskPtr            : ATaskPtr;
    BEGIN

        TaskPtr := GlobalTaskNode^.Methods^.LockFlexStorDataObject( GlobalTaskNode );
        CalendarTimeToBigTime( FormValue[FSD].CardValue, TRUE, TaskPtr^.UserEnteredStartDate ); (* 12-Sep-90 RSC *)
        GlobalTaskNode^.Methods^.UnlockFlexStorDataObject(GlobalTaskNode);

    END CopyDateToTask;

    (* 
    PROCEDURE MaybeSetNewStart(); (* 24-Aug-91 TGS *)
    VAR
        TaskPtr            : ATaskPtr;
    BEGIN
        TaskPtr := GlobalTaskNode^.Methods^.LockFlexStorDataObject( GlobalTaskNode );
        WITH TaskPtr^ DO
            IF (StartStatus = FutureS) AND
               (CompletedSummary.Time > Zero) THEN
                FormValue[FSD].CardValue 
                    := BigTimeToCalendarTime( SupposedToStart );
                TimeUtoS( FormValue[FSD].CardValue, FormValue[FSD].CharValue^ );
                TheDuration := FormValue[FED].CardValue - FormValue[FSD].CardValue;
                DurationScale := VAL(ADurationUnit,FormValue[FDU].CardValue);
                RecomputeTask( TheDuration );
                ShowNormalizedDuration( TheDuration, DurationScale );
                ShowDateGroup();
            END;
        END;
        GlobalTaskNode^.Methods^.UnlockUnchangedDataObject( GlobalTaskNode );   (* RSC 7-Jun-89 *)
    END MaybeSetNewStart;
    *)


BEGIN   (* CheckTaskData *)
    LCode  := Code;
    Code   := 0;    (* Set Code safely to zero for return. *)

    (* If this field check in any way affects the resource table, pass it
       directly to "CheckTaskFormResources".  RCF is the first field in the
       resource table on the form.   02-Jun-87 RSC.
    *)

    IF (FieldNo >= RCF) THEN
        RETURN AssignmentForms();
    END;


    (* Handle the various check reasons:

         - On form entry we need to setup the field protection.
         - On Field Entry for the StartStatus we need to save the current % value.
         - On form exit, we need to do one-time wrap up checking.
         - F2 has three meanings on this form.
    *)

    Result := TRUE;

    CASE CheckReason OF

    | CheckFormEntry  :
            
        IF (FieldNo = FNM) THEN
            SetProperRollupProtection();
            IF (NOT ThisIsASummaryTask) AND
               (FormValue[FFX].CardValue = ORD(FixedDate)) THEN
                MaybeSetProtection(RED,TRUE);
                FormValue[RED].CardValue := ORD(DurationDriven);
            END;
            SetProtection();
        END;

    | CheckFormExit   :

        IF (FieldNo = 0) AND
           (NeedsFormWrapUp) THEN (* 30-Aug-91 TGS *)
            Result := FormWrapUp();
        END;

    | CheckFieldEntry :

        IF (FieldNo = FSS) THEN
            GlobalPCP := FormValue[PCP].CardValue;
        END;

    | CheckFieldKey   :

        IF (IsErase(LCode)) THEN
            IF (FieldNo = SUM) THEN
                IF (NOT DeleteSummarizes()) THEN
                    Result := FALSE;
                END;
            ELSE
                Code := LCode + CARDINAL({14}); (* restore the key. *)
            END;
        ELSIF (LCode = EditKey) THEN
            IF (FieldNo = NT1) THEN    (* Notes field *)
                EditNotesField();
            ELSIF (FieldNo = SUM) AND (LCode = EditKey) THEN  (* Summary field *)
                DoTaskLinkForm();
                MaybeShowValue(SUM);
            ELSE
                Code := LCode + CARDINAL({14}); (* restore the key. *)
            END;
        ELSE
            Burp;
            Result := FALSE;
        END;

    | CheckFieldExit:

        IF (FieldNo = FNM) THEN                               (* 12-Sep-89 LAA *)
            WITH FormValue[FieldNo] DO
                LJust(CharValue^);
                TrimRear(CharValue^);
                IF (LengthOf(CharValue^) = 0) THEN
                    DisplayMessage(ModuleNumber+3); (*  "Please fill in a task name." RSC 21-Nov-89 *)
                    Burp();
                    Result := FALSE;
                END;
            END;
        END;

    | CheckFieldChange:

        IF (NOT ThisIsASummaryTask) THEN
            NeedsRecalc := (NeedsRecalc OR
                           (FieldNo     IN RecalcFields));
        END;
        NeedsSort       := (NeedsSort   OR
                           (FieldNo     IN SortFields));

        NeedsFormWrapUp := NeedsFormWrapUp OR
                           (FieldNo     IN RecalcFields); (* 30-Aug-91 TGS *)

        WITH FormValue[FieldNo] DO
            CASE FieldNo OF
            | FAU,
              FWB,
              FOB: 
                LJust( CharValue^ );
                MaybeShowValue( FieldNo );
            | FNM:
                LJust(CharValue^);
                TrimRear(CharValue^);
                ShowValue( Form, FNM, FormValue );
            | NT1:
                SaveNotesToText();
            | FFX:
                IF (CardValue = ORD(FixedDate)) THEN
                    CopyDateToTask(FormValue);
                    MaybeSetProtection(RED,TRUE);
                    GlobalDurationMethod     := VAL(ADurationMethod,FormValue[RED].CardValue);
                    FormValue[RED].CardValue := ORD(DurationDriven);
                ELSE
                    MaybeSetProtection(RED,FALSE);
                    FormValue[RED].CardValue := ORD(GlobalDurationMethod);
                END;
                SetProtection();
                MaybeShowValue(RED);
            | RED:    
                SetProtection();
                GlobalDurationMethod := VAL(ADurationMethod, CardValue);
                IF (CheckReason = CheckFieldChange) THEN
                    MakeAssignmentsRateDriven();          (* 3/8/89 EGK *)
                    RecomputeTask( FormValue[FDN].CardValue );

                    (* 30-Apr-91 TGS *)
                    IF (FormValue[FSS].CardValue <> ORD(FutureS))
                          AND
                       (GlobalDurationMethod = DurationDriven) THEN
                        FormValue[SPD].CardValue := ORD(Split);
                        MaybeShowValue(SPD);
                    END;
                END;
            | FDN:  
                CheckDuration();
                Result := (NOT DurationOverflow);
            | FDU: 
                MaybeAlterDuration();
                Result := (NOT DurationOverflow);
            | FEN:
                Result := CheckEffort();
            | FEU:
                Result := MaybeAlterEffort();
            | FSD:
                Result := CheckStartDate();
            | FED:
                Result := CheckEndDate();
            | FSS:
                IF ((CardValue = ORD(DoneS)) OR (CardValue = ORD(StartedS))) THEN
                    IF (VAL(ADurationMethod, FormValue[RED].CardValue) =
                            DurationDriven) THEN
                        FormValue[SPD].CardValue := ORD(Split);
                        MaybeShowValue(SPD);
                    ELSE (* EffortDriven *)
                        (* If it was FutureS before, get the SupposedToStartDate *)
                        (* MaybeSetNewStart(); *)
                    END;
                END;
                SetPercentComplete();
                SetProtection();
            | PCP:
                IF (CardValue > 100) THEN
                    DisplayMessage(ModuleNumber + 61);  (* "Can't be > 100" *)
                    Burp();
                    CardValue := 100;
                    MaybeShowValue( PCP );
                    Result := FALSE;
                ELSE
                    SetStartStatus( CardValue );
                END;
                (*                                                 08-Oct-91 
                RecomputeTask( FormValue[FDN].CardValue );
                *)
                MaybeCalcSpent( CardValue );
            | PRI: 
                (* 26-Jul-91 PFG  Check for < 0, too.  *)
                IF ((RealValue > 999.9) OR (RealValue < Zero)) THEN
                    DisplayMessage(ModuleNumber + 79);  (* "Can't be > 999.9" *)
                    Burp();
                    IF (RealValue < Zero) THEN
                        RealValue := Zero;
                    ELSE
                        RealValue := 999.9;
                    END;
                    MaybeShowValue( PRI );
                    Result := FALSE;
                ELSE
                    RealValue := (* Clean up small fractions *)
                    FLOAT(TRUNC((RealValue * Ten)+Point5)) / Ten;
                    MaybeShowValue( PRI );
                END;
            ELSE
            END;
        END;
    ELSE
        FatalError();   (* What?  How did we get here? *)
    END;

    RETURN Result;

END CheckTaskData;









PROCEDURE MapFormToTask( VAR FormValue  : ARRAY OF AFieldValue;
                         VAR TaskNode   : ATreeNode );
VAR
    TotalEffort        : REAL;
    TaskPtr            : ATaskPtr;
    TempDate           : ADate;
BEGIN
    TaskPtr        := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    WITH TaskPtr^ DO
        Copy(FormValue[FNM].CharValue^,taskname);
        LJust(taskname);
        TrimRear(taskname);

        (* Notes are NOT saved in this procedure, but in the edit
           check proc when stuff is typed in or F2 hit.
        *)

        fixation        := VAL(AFixType,FormValue[FFX].CardValue);
        DurationMethod  := VAL(ADurationMethod,FormValue[RED].CardValue);
        scale           := VAL(ADurationUnit,FormValue[FDU].CardValue);
        duration        := RealTimeToDuration(FormValue[FDN].RealValue,scale);
        EffortScale     := VAL(ADurationUnit,FormValue[FEU].CardValue);
        SplittingRule   := VAL(ASplittingRule,FormValue[SPD].CardValue); (* 6-Aug-90 RSC  *)

            (* 24-Oct-90 RSC  IF Fixation changed, then

                If fixed, apply defaults from options form.

                If not fixed, NoSooner/Later Start/End do not apply.

                Yes, I know this COULD be done with SET math, but, for once,
                I take pity on the reader.
            *)
        IF (fixation <> GlobalFixation) THEN
            EXCL(TaskFlags,NoSoonerStart);
            EXCL(TaskFlags,NoLaterStart);
            EXCL(TaskFlags, ForceCritical);                    (* 10-Mar-92 *)
            IF (fixation = FixedDate) THEN
                IF (FixedDateRules.ForceCritical) THEN
                    INCL(TaskFlags,ForceCritical);
                END;
                INCL(TaskFlags,NoSoonerStart);
                IF (FixedDateRules.StartDateMustStart) THEN
                    INCL(TaskFlags,NoLaterStart);
                END;
            END;
        ELSIF (GlobalForceCritical <> (ForceCritical IN TaskFlags)) THEN  (* 10-Mar-92 *)
                (*  ForceCritical flag has been changed even though the
                    task type has not.  This can occur by setting it to
                    Fixed, then back to the original value.  So we reset
                    the ForceCritical flag to it's original value, too.
                *)
            IF (GlobalForceCritical) THEN
                INCL(TaskFlags, ForceCritical);
            ELSE
                EXCL(TaskFlags, ForceCritical);
            END;
        END;

        CompletedSummary.Time   := LocalCompleted.Time   + KidsCompleted.Time;
        CompletedSummary.Amount := LocalCompleted.Amount + KidsCompleted.Amount;
        ToGoSummary.Time        := LocalToGo.Time        + KidsToGo.Time;
        ToGoSummary.Amount      := LocalToGo.Amount      + KidsToGo.Amount;

        StartStatus     := VAL(AStartStatus,FormValue[FSS].CardValue);
        IF (StartStatus = FutureS) AND
           ((fixation = ASAP) OR (fixation = ALAP)) THEN (* 19-Dec-90 TGS *)
            EXCL(TaskFlags,NoSoonerStart);
            EXCL(TaskFlags,NoLaterStart);
        END;

        TempDate        := VAL(ADate,FormValue[FSD].CardValue);

        (* On the form, EndDate just determines the duration. *)

        PercentComplete := FormValue[PCP].CardValue;
        priority        := TRUNC((FormValue[PRI].RealValue * Ten)+Point5);
        SetCodingField (TaskPtr^, WBSLine, FormValue[FWB].CharValue^);
        SetCodingField (TaskPtr^, OBSLine, FormValue[FOB].CharValue^);
        SetCodingField (TaskPtr^, AUXLine, FormValue[FAU].CharValue^);

        (* Summary field (Link To File) is saved in the check proc. *)
        (* Resource fields are saved in AssForms *)

        WITH Plan.Dates DO
            IF (GlobalOldStartDate = TempDate) AND
               (GlobalOldDuration  = duration) THEN (* 24-Oct-90 RSC *)

                    (* 25-Sep-90 RSC Don't recompute everything from durations,
                                     and make sure that SupposedToStart and
                                     UserEnteredStartDate contain reasonable values.
                    *)
                IF (CompareBigTimes(UserEnteredStartDate, MINBIGTIME) = 0) THEN
                    CalendarTimeToBigTime( TempDate, TRUE, UserEnteredStartDate );
                END;
                IF (CompareBigTimes(SupposedToStart, MINBIGTIME) = 0) THEN
                    SupposedToStart := UserEnteredStartDate;
                END;
            ELSE
                CalendarTimeToBigTime( TempDate, TRUE, UserEnteredStartDate );  (* 12-Sep-90 RSC *)
                SupposedToStart := UserEnteredStartDate;    (* 12-Sep-90 RSC  *)
                IF (EarlyStart <  TempDate) THEN
                    EarlyStart := TempDate;
                END;
                EarlyEnd       := EarlyStart + duration;
                IF (LateFreeStart <  EarlyStart) THEN
                    LateFreeStart := EarlyStart;
                END;
                IF (LateFreeEnd <  EarlyEnd) THEN
                    LateFreeEnd := EarlyEnd;
                END;
                IF (LateTotalStart <  EarlyStart) THEN
                    LateTotalStart := EarlyStart;
                END;
                IF (LateTotalEnd <  EarlyEnd) THEN
                    LateTotalEnd := EarlyEnd;
                END;
            END;

            IF (FormValue[FSS].CardValue = ORD(DoneS)) OR
               (FormValue[FFX].CardValue = ORD(FixedDate)) THEN
                CalendarTimeToBigTime( FormValue[FED].CardValue,
                                       FALSE, UserEnteredEndDate ); (* 16-Aug-91 TGS *)
            ELSE
                CalendarTimeToBigTime( EarlyEnd, FALSE, UserEnteredEndDate );  (* 12-Sep-90 RSC *)
            END;
        END;
        IF (NeedsRecalc) THEN
            INCL( TaskStatusSet, NeedsRecalculate );
            IF (LinkedTask) THEN
                rollupstatus := RollupNotLoaded;        (* 5/26/89 EGK *)
            ELSE
                rollupstatus := NotRollup;
            END;
        END;
    END;

    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

END MapFormToTask;








PROCEDURE MapEarnedValue( VAR FormValue   : ARRAY OF AFieldValue;
                              BCWP        : REAL;
                          VAR Completed,
                              ToGo        : AnAssignmentSummary;
                              EffortScale : ADurationUnit );
VAR
    R, R1, R2    : REAL;
    Ass          : AnAssignmentSummary;

    PROCEDURE ComputePercentOfBaseLine( Baseline,
                                        StartWith   : REAL;
                                        WhereItGoes : CARDINAL );
    VAR
        R        : REAL;
        C        : CARDINAL;
    BEGIN
        IF (Baseline = Zero) THEN
            C := 0;
        ELSE
            R := ((StartWith / Baseline)
                 * OneHundred)
                 + Point5;
            IF (R > 9999.0) OR (R < Zero) THEN
                C := 10000; (* Cause overflow *)
            ELSE
                C := TRUNC(R);
            END;
        END;
        WITH FormValue[ WhereItGoes ] DO
            CardValue := C;
            IF (C = 0) THEN
                SetString(CharValue^,"   0");
            ELSIF (C > 9999) THEN
                SetString(CharValue^,"****");
            ELSE
                CtoS( C,   CharValue^ );
                Procustes( CharValue^, 4 );
                RJust(     CharValue^ );
            END;
        END;
    END ComputePercentOfBaseLine;

BEGIN

    IF (GlobalBaselineExists) THEN
        R  := GlobalBaseLine.Amount;
        R1 := GlobalBaseLine.Time;
    ELSE
        R  := Zero;
        R1 := Zero;
    END;

    R2       := (FLOAT(FormValue[PCP].CardValue) / OneHundred);
    Ass.Time := (R1 * R2);
    IF (ThisIsASummaryTask) THEN
        Ass.Amount := BCWP;  (* Use this slightly more accurate figure. *)
    ELSE
        Ass.Amount := (R  * R2);
    END;
    AssignmentSummaryToString(
                      Ass, EffortScale,
                      0,2, 0,                     (* Min, Max, Pennies *)
                      22,                         (* Field Width *)
                      FormValue[EVD].CharValue^ );

    ComputePercentOfBaseLine( R, Completed.Amount, CPP );
    ComputePercentOfBaseLine( R, ToGo.Amount,      YGP );

END MapEarnedValue;




    (*  SetGlobals really means to set some globals to values which existed
        in the task before it was edited.  Only some of the variables named
        "Global..." are used in this way, so only some need be set just once.
    *)

PROCEDURE MapTaskToForm( VAR FormValue : ARRAY OF AFieldValue;
                         VAR TaskNode  : ATreeNode;
                             SetGlobals: BOOLEAN              );

VAR                                                   
    TaskPtr            : ATaskPtr;
    TempDate, TempEnd  : ADate;
    TempDur            : ADuration;
    StartProtection,
    EndProtection,
    EffortProtection,
    DurationProtection : BOOLEAN;

BEGIN

    TaskPtr        := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    (* Map out things into the form, DO NOT CHANGE THE TASK RECORD
       (so we can unlock without changes).
    *)
    WITH TaskPtr^ DO
        IF (SetGlobals) THEN                                   (* 03-Oct-91 *)
            IF (BaseLineExists IN TaskFlags) THEN
                AssignmentSummaryToString( BaseLineSummary, EffortScale,
                                           0,2, 0,   (* Min, Max, Pennies *)
                                           22,       (* Field Width *)
                                           GlobalBaselineText );
                GlobalBaseLine       := BaseLineSummary;
                GlobalBaselineExists := TRUE;
            ELSE
                GetMessage(ModuleNumber + 78, GlobalBaselineText ); (* "<No BaseLine>" *)
                GlobalBaselineExists := FALSE;
            END;
            GlobalForceCritical := (ForceCritical IN TaskFlags);   (* 10-Mar-92 *)
        END;

        LocalCompleted := CompletedSummary;
        LocalToGo      := ToGoSummary;

        CompletedSummary.Time   := CompletedSummary.Time    + KidsCompleted.Time;
        CompletedSummary.Amount := CompletedSummary.Amount  + KidsCompleted.Amount;
        ToGoSummary.Time        := ToGoSummary.Time         + KidsToGo.Time;
        ToGoSummary.Amount      := ToGoSummary.Amount       + KidsToGo.Amount;

        Copy(GlobalBaselineText,FormValue[BAS].CharValue^);

        Copy(taskname,FormValue[FNM].CharValue^);

        IF (ADDRESS(notes) <> NIL) THEN
            CopyLine(notes, 0, FormValue[NT1].CharValue^);
        ELSE
            SetLengthOf(FormValue[NT1].CharValue^,0);
        END;

        LinkedTask := (ADDRESS(summarizes) <> NIL);
        IF (LinkedTask) THEN
            SetString(   FormValue[SUM].CharValue^, "*" ); (* 30-Apr-91 TGS *)
        ELSE
            rollupstatus := NotRollup;
            SetLengthOf( FormValue[SUM].CharValue^,0);
        END;

        FormValue[FFX].CardValue := ORD(fixation);
        IF (SetGlobals) THEN
            GlobalFixation       := fixation;
        END;

        FormValue[RED].CardValue := ORD(DurationMethod);
        GlobalDurationMethod     := DurationMethod;

        FormValue[FDU].CardValue := ORD(scale);
        GlobalScale              := scale;


        FormValue[FSS].CardValue := ORD(StartStatus);
        FormValue[SPD].CardValue := ORD(SplittingRule); (* 6-Aug-90 RSC  *)

        SetStaticProtection( AdvancedTaskForm,
                             ThisIsASummaryTask,
                             LinkedTask,
                             TaskFormProtection );

        GetProtection( StartProtection, EndProtection, EffortProtection,
                       DurationProtection,
                       TaskFormProtection,
                       fixation,
                       StartStatus,
                       DurationMethod );

        IF (StartProtection) THEN
            TempDate := Plan.Dates.EarlyStart;
        ELSE
            TempDate := BigTimeToCalendarTime( UserEnteredStartDate );  (* 12-Sep-90 RSC *)
        END;
        IF (SetGlobals) THEN                                   (* 03-Oct-91 *)
            GlobalOldStartDate := TempDate;
        END;

        FormValue[FSD].CardValue := TempDate; (* Save for Check Proc *)
        TimeUtoS (TempDate, FormValue[FSD].CharValue^);

            (* 19-Sep-91 TGS *)
            (* We don't want to trust the duration field for EffortDriven
               DoneS tasks, because a local recalc might have mucked with it.
               We want to leave the end date the way the user had it no
               matter what in such cases.

               It seemed risky to fix the local recalc, because it has so 
               many clients, not all of whom would necessarily share the
               problems of task form edit. Hence this bandaid fix, wherein we
               blithely ignore the results that might otherwise trouble us.
            *)
        IF (DurationMethod <> EffortDriven) OR
           (StartStatus    <> DoneS)        THEN
            TempDur := duration;
        ELSE
            TempEnd := BigTimeToCalendarTime( UserEnteredEndDate );
            TempDur := FindDuration(TempDate, TempEnd, TimeSheet);
        END;

        FormValue[FDN].RealValue := DurationToRealTime(TempDur,scale);

        FormValue[FDN].CardValue := TempDur; (* For check proc *)

        FormatEndDate(TempDate, TempDur, FormValue[FED].CharValue^);
        FormValue[FED].CardValue := TempDate + TempDur;

        FormValue[PCP].CardValue := PercentComplete;

        IF (SetGlobals) THEN                                   (* 03-Oct-91 *)
            GlobalOldDuration        := TempDur; (* For FormToTask *)  (* 24-Oct-90 RSC *)
            GlobalStartingAchievment := PercentComplete;
        END;

        GetCodingField (TaskPtr^, WBSLine, FormValue[FWB].CharValue^);
        GetCodingField (TaskPtr^, OBSLine, FormValue[FOB].CharValue^);
        GetCodingField (TaskPtr^, AUXLine, FormValue[FAU].CharValue^);
        FormValue[PRI].RealValue := FLOAT(priority) / Ten;
        AssignmentSummaryToString(
                          ToGoSummary, EffortScale,
                          0,2, 0,                     (* Min, Max, Pennies *)
                          22,                         (* Field Width *)
                          FormValue[YTG].CharValue^ );
        AssignmentSummaryToString(
                          CompletedSummary, EffortScale,
                          0,2, 0,                     (* Min, Max, Pennies *)
                          22,                         (* Field Width *)
                          FormValue[CMP].CharValue^ );

        FormValue[FEU].CardValue := ORD(EffortScale);
        GlobalEffortScale        :=     EffortScale;

        FormValue[FEN].RealValue := WorkHoursToRealTime(
                                       (CompletedSummary.Time +
                                        ToGoSummary.Time),
                                        EffortScale);

        MapEarnedValue( FormValue, BCWP, CompletedSummary, ToGoSummary, EffortScale );
        GBCWP := BCWP;
    END;

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

END MapTaskToForm;






PROCEDURE TLTaskForm(TaskNode:ATreeNode):ACode;
VAR
    TaskPtr            : ATaskPtr;
    i                  : CARDINAL;
    WhichForm          : CARDINAL;
    Loop               : CARDINAL;
    Code               : ACode;
    FormValue          : ARRAY [0..LastTaskFormField] OF AFieldValue;
    StringFields       : ARRAY [1..TotalStringFields] OF AStringValue;
    ok                 : BOOLEAN;


    PROCEDURE Max( R1, R2 : REAL ) : REAL;
    BEGIN
        IF (R1 > R2) THEN RETURN R1; ELSE RETURN R2; END;
    END Max;


BEGIN
    CheckTaskValid(TaskNode);

    GlobalTaskNode      := TaskNode;
    ThisIsASummaryTask  := (TaskNode^.Methods^.FirstChild (TaskNode) <> NIL);
    NeedsRecalc         := FALSE;
    NeedsSort           := FALSE;
    GlobalForceCritical := FALSE;                              (* 10-Mar-92 *)

        (* Moved these here from the module init -- TGS/EGK 10/3/91 *)
    RFLastFieldChanged             := 0;
    NeedsFormWrapUp                := FALSE; (* 30-Aug-91 TGS *)

    (* setup storage for the string fields. *)

    i := 0;
    FOR Loop := 0 TO (RCF - 1) DO
        IF (Loop IN StringFieldSet) THEN
            INC(i);
            FormValue[Loop].CharValue := ADR(StringFields[i]);
        ELSE
            FormValue[Loop].CharValue := NIL;
        END;
    END;
    (* DEBUG *) IF (i <> TotalStringFields) THEN FatalError(); END;

    WhichForm := TaskFormNumber[ ThisIsASummaryTask, AdvancedTaskForm ];


        (* DANGER!!
                     The Completed and ToGo summaries at the bottom of the
                     task and summary forms are used in calculations to
                     determine the TOTAL EFFORT for this task.
                     We liberally recalc this task, even if it is a summary task.
                     A summary task recalc may yield strange results.  Therefore,
                     we keep a copy of any kid's efforts for rollup purposes.
                     Note that if the schedule has not been recalcd lately, the
                     results may appear off (even negative).

                     Now, these numbers are a result of rollups.  If this is a
                     detail task, there should be no numbers there.

        *)

    SummTaskNodeAmounts( TaskNode, FALSE,
                        LocalCompleted, LocalToGo );

    TaskPtr        := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    CheckTaskValid(TaskNode);

    WITH TaskPtr^ DO
        IF (ThisIsASummaryTask) THEN
            ToGoSummary.Time        := Max(ToGoSummary.Time,        LocalToGo.Time  );
            ToGoSummary.Amount      := Max(ToGoSummary.Amount,      LocalToGo.Amount);
            CompletedSummary.Time   := Max(CompletedSummary.Time,   LocalCompleted.Time  );
            CompletedSummary.Amount := Max(CompletedSummary.Amount, LocalCompleted.Amount);
            KidsToGo.Time           := ToGoSummary.Time           - LocalToGo.Time;
            KidsToGo.Amount         := ToGoSummary.Amount         - LocalToGo.Amount;
            KidsCompleted.Time      := CompletedSummary.Time      - LocalCompleted.Time;
            KidsCompleted.Amount    := CompletedSummary.Amount    - LocalCompleted.Amount;

            ToGoSummary             := LocalToGo;
            CompletedSummary        := LocalCompleted;
        ELSE 
            KidsToGo.Time           := Zero;
            KidsToGo.Amount         := Zero;
            KidsCompleted           := KidsToGo;
                (*  30-Aug-91 TGS 
                    Don't change the Summary's of detail tasks
                *)
        END;
    END;

    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

    MapTaskToForm( FormValue, TaskNode, TRUE );                (* 03-Oct-91 *)
    SetupTaskFormAssignments( TaskNode, FormValue, RCF );

        (*  Edit the form. *)

    Code := DoForm(0,0,maxcol,GanttWEnd,WhichForm,
                   TRUE,FormValue,CheckTaskData);

    IF (StoreTaskFormAssignments( GlobalTaskNode )) THEN
        NeedsRecalc := TRUE;
    END;

    IF (Code = ExitKey) THEN
        MapFormToTask( FormValue, TaskNode );  (* Fill in new task values. *)
        (* 21-Nov-89 RSC Fix of 7-Aug-89 removed, functionality placed in
                                "FormWrapUp".
        *)
        IF (NeedsRecalc) THEN                     (* 6/17/87 EGK *)
            UnSetState (Scheduled);
            ScheduleSaved := FALSE;
        END;
        IF (NeedsSort) THEN
            UnSetState (Sorted);
            UnSetState (Filtered);
            ScheduleSaved := FALSE;
        END;
    END;

    CheckTaskValid(TaskNode);

    RETURN Code;

END TLTaskForm;





PROCEDURE DoCopyright();
VAR
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
END DoCopyright;






PROCEDURE TLChangeBody();                                         (* 19-Jan-88 LAA *)
VAR
    TaskFormContextPtr      : POINTER TO ATaskFormContext;
BEGIN                       (* TLChangeBody *)
    DoCopyright();  (* Keep it linked in by referencing it *)

    TaskFormContextPtr := OverlayContext();

    TaskFormContextPtr^.Code := TLTaskForm( TaskFormContextPtr^.TaskNode );

END TLChangeBody;



BEGIN
      (* RSC 9/3/87 and again on 10/5/87 *)

    TaskFormNumber[ TRUE,  TRUE  ] := 27;  (* Summary form, complicated *)
    TaskFormNumber[ TRUE,  FALSE ] := 14;  (* Summary form, simple      *)
    TaskFormNumber[ FALSE, TRUE  ] :=  1;  (* Detail  form, complicated *)
    TaskFormNumber[ FALSE, FALSE ] := 12;  (* Detail  form, simple      *)
    TaskFormProtection             := ATaskFormField{};

    OverlayID := ImAnInstallableOverlay(TLChangeBody, AnOverlayProc(NIL));       (* 19-Jan-88 LAA *)
    TLChangeBody();

END TLChange.
        05-Aug-87 LAA   Added use of Named Layouts.
        03-Sep-87 RSC   Additional "simple" task form.  some moved fields.
        08-Sep-87 RSC   Set rollup status on F10.  Protect lots of fields on
                        rollup tasks.
        14-Sep-87 EGK   Rewrote lots of stuff to use new ALLOCS procedures
                        for manipulating tasks and edges underneath the
                        user interface, primarily for use by undo.
         2-Oct-87 RSC   Bug fixes: Turn resting cursor off for Editor returns.
                        Redisplay of calc'd units not proper.
                        On Duration change when start date is blank refresh
                            start date, not end date.
                        Move most init code from InitializeChanger() to
                        the initialization section of this module.
        13-Oct-87 RSC   Bug fixes and remove references to TaskOnTheForm for
                        conversion to EMS Task storage.  Also added Shadows
                        to boxes and decoupled StartStatus from %Achieved.
                        Added param to EditText
        20-Oct-87 RSC   Change scale being passed to AssForms to EffortScale.
        26-Oct-87 RSC   misc bug fixes (again), including detecting resources
                        on the task form to interlock against deletion, and
                        telling forms that something has changed when the
                        notes text is updated.
        28-Oct-87 RSC   After EGK made a small change (Set(Filtering)), I
                        split off the task link form into an overlay (TLLINK).
         3-Nov-87 RSC   Warn for deletion of task with baseline info.  Allow
                        deleting link info via DELETE or ALT/F9 on link field.
         6-Nov-87 RSC   Warn for altering % achieved when no baseline and there
                        is a parent task.  ARGHHHHH!
        25-Nov-87 AJL   Added special processing for end dates.
        16-Dec-87 LAA   Commented out DuplicateTask, which is not used.
        28-Dec-87 RSC   Made Spent and ToGo percentages percents of BaseLine,
                        and they can be from 0-9999 (was 3 digits)
*)
(*        
        11-Jan-88 RSC   Split this module out from Changer in prep for
                        turning into an overlay.  Also, as per bug 3263,
                        don't tamper with slack dates unless nescessary.
                        This helps non-changes look the same on the Gantt
                        (all end dates were set to EarlyEnd before).
                        Convert to Unchanged versions of UNLOCKS.
        19-Jan-88 LAA   Added call to identify this as a resident overlay.
        28-Jan-88 RSC   Always set both fixed and early start date on F10.
        02-Feb-88 LAA   Removed reference to LowFuel.
        18-Feb-88 LAA   Import from ManHours instead of RsrcCalc.
        23-Feb-88 RSC   For summary tasks, use BCWP rather than %*Baseline$
        24-Feb-88 RSC   1) Summary tasks do not recalc for the RecalcFields
                           like details do, so now the only way to get it to
                           recalc summaries is to change assignments.
                        2) Redisplay earned value stuff when effort units
                           change, so as to rephrase earned vale times.
                        3) MoronMode users who go to Future automaticly get
                           Percent Complete (Achieved) set to 0.
        25-Feb-88 RSC   1) Put up "Wont rollup" message iff no resources,
                           but % ach. as per DBryan's request of 1/31/88.
        11-Mar-88 LAA   Compress the notes and summarizes when we leave the
                        form, and not while we're on the form.
        16-Aug-88 RSC   Split off the assignment forms into another overlay,
                        TLAssgn.Mod
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
*)

