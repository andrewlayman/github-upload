    (*V1=OS2 OS2 code changes.    *)
    (*V2=DOS Regular DOS TL code. *)

(*<OS2
IMPLEMENTATION MODULE TLCaption;
OS2>*)
(*<DOS*)
MODULE TLCaption;
(*DOS>*)

(*  =========================================================================
    Last Edit : September 18, 1991 8:15PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description:
        Add captions to Time Line.

    MODIFICATION HISTORY:
    pre-1990 history at end of this file
    30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
    11-Apr-90 KKC   Replace all direct calculations on ADate and Duration
                    by calls to FindDuration, SubtractWorkingTime and
                    AddWorkingTime.
    21-May-90 AJL   Made the proportional percent columns sensitive to the
                    possibility of 0/0.
                    SpentEffort% column now shows zero if spent effort is zero.
    12-Jun-90 AJL   ProportionalPct columns are now clipped to 100% partly
                    because this is in keeping with the spirit of the formula,
                    and partly to avoid a problem which is in the FormatColumns
                    module, which is that any very large number is printed as
                    zero!  (See FormatColumns, 19-Oct-89).
    13-Jun-90 AJL   ProportionalPercent columns have been rewritten again to
                    show reasonable values when the bar does not cross the
                    as-of date line.  See the notes with the DoPropPctAchieved
                    procedure.
    20-Jul-90 AJL   Phrased the last coding field in terms of NumberOfCodingFields.
    22-Jul-90 AJL   Modified XFormatTaskColumns to call GetColumnString
                    rather than XGetColumnString.   This allows us to
                    work even if another overlay has taken the vectors.
    10-Aug-90 RSC   Ajusted for new AssignmentCost routine.
    22-Aug-90 PFG   Added support for user-defined column headings.  Get
                    column headings from either Phrases file or memory (if
                    user-modified).  Also, use constants to refer to various
                    parts of column information.
    12-Sep-90 RSC   Fixed for new Allocs.Def.  Allow AssignmentDriven
                    to be formatted.
    14-Sep-90 PFG   Added support for new Splitting Rule column.
    14-Sep-90 AJL   Asking for a column whose number is higher than known
                    returns in empty record (all zeros and nils) from
                    GetColumnInfo.
    17-Sep-90 PFG   Changed FixedStartColumn to UserEnteredStartColumn.
                    Added UserEnteredEndColumn, SupposedToStartColumn,
                    LateIndStartColumn, LateIndEndColumn.
    19-Sep-90 PFG   Use EarlyEnd-EarlyStart for duration, as per Andrew.
    24-Sep-90 PFG   Fixed UserEnteredStart, UserEnteredEnd and SupposedToStart
                    to fill in BigTimeValue rather than DateValue (whoops!)

     5-Oct-90 RSC   Make TLCAPTIONS a RESIDENT rather than DYNAMIC overlay.
                    Basicly, this means that all entry and exit points
                    MUST BE BRACKETED by the procedures
                    EnteringOverlay and ExitingOverlay.  In particular,
                    BE ABSOLUTELY SURE all exit points are covered.
     6-Oct-90 AJL  -Made most RealRatio calculations compute 0/0 as 0.
                    The schedule performance, cost performance, and burn rate
                    ratios are still 0/0 = 1.
                   -Allow for negative slack, that is, in the slack calculations
                    permit the computed slack duration to be negative.
                   -Add independent slack and SequenceNumber columns.
                   -Reorganized the code to use a new procedure GetATaskDate.
                   -Moved the code that initializes until AFTER an overlay id
                    has been obtained.
                   -Rephrased the code that obtains the next column id.  I
                    think that as part of the 5-Oct fix above it got broken.
                   -Put the FormatSpecs array into FlexStor.
    27-Oct-90 AJL  -Add RequiredStart and ForceCritical columns.
                   -Combined the phrases for several enumerated column types
                    into a single phrase.  These are DurationMethod and
                    SplittingRule.
                   -Added "ColumnEnumerations" which returns a phrase number
                    of a list of the valid entries in a field during
                    field edit, or else zero if not an enumerated type.
                   -Added ColumnHelpKey.
                   *)(*
     1-Nov-90 CL  - Rename SuppressSlack to ForceCritical.
     7-Nov-90 PFG   Added fixes from 4.0.3:
                    09-Jul-90 WKH   
                        Well, for proportional pct complete, we were showing
                        the same values for plan and baseline, which isn't
                        necessarily correct.  So since we already have code 
                        to do that calculation, I call it if I detect that
                        the caller really wants baseline info as opposed to 
                        plan. 
                    18-Jul-90 WKH   
                        You will notice that the previous two mod histories 
                        are in chronologically incorrect order.  This is not
                        a mistake.  Andrew had made a change to PropPctComplete 
                        calculation that didn't make it into this source file.
                        I also made a change that clashed with his.  So the net 
                        effect of the 13-Jun-90 change by Andrew and the  
                        09-Jul-90 change by me has been consolodated into 
                        the 18-Jul-90 change.  ARRRGGGGH!!!  I'll get you for 
                        this Roger....
                    23-Sep-90 PFG   
                        Commented out code that places a  in a notes column
                        if it's only one character wide.  It was causing
                        printing problems.
                    End of 4.0.3 fixes.
    12-Nov-90 RSC   Found a couple more places that used "duration".
    29-Nov-90 AJL - Changed the computations of DelayPastBaselineStartDate and
                    EndDate to use the DurationInHours procedure, which can
                    handle negative numbers.

    22-Jan-91 RSC   Removed spurious import of LongDurationToString.
    25-Jan-91 RSC   Updated definition of FormatTaskColumns
    19-Feb-91 RSC   Updated to behave like an ordinary overlay which does
                    not steal vectors.  One note of caution.  I changed
                    XFormatTaskColumns to use XGetColumnString rather than
                    GetColumnString to avoid nesting calls through 
                    CallOverlayWithContext.  What this means is that if you
                    implement another overlay which steals GetColumnString,
                    you should also steal FormatTaskColumns to handle the
                    added columns.
      6-Mar-91 AJL  The ResourceLevelingDelay column was showing the delay
                    past the UserEnteredStartDate, when it should have been
                    showing the delay past the SupposedToStart date.
     14-Mar-91 RSC  When we build the list of column alias', bajillions of
                    calls are made to ColumnInfo.  Moved some ColumnInfo
                    logic back into Captions.Mod.  Also always put the
                    FormatSpecs onto the heap, not into FlexStor.  This
                    way, this overlay needs no shutdown procedure, a
                    requirement for caching it.
     20-Mar-91 TGS  Call to FormatValue had Min and MaxDecimals switched.
     21-Mar-91 RSC  Avoid some recursive calls through the Captions procedure.
                    If someone steals some vectors to add columns, you better
                    steal them all.
      4-Apr-91 TGS  UserEnteredStartDate appears only for Fixed|StartedS|DoneS.
                    UserEnteredEndDate appears only for Fixed|DoneS.
                    Neither appears on Summary tasks.
      5-Apr-91 TGS  Moved Task Column numbers to TaskColN from MagicNum.
     25-Apr-91 RSC  Added a new ColumnInfo function to search for the name
                    of a column.  If the passed ColumnID is MAXCARDINAL,
                    we search for the string passed in StringValue, and
                    return as CardinalValue the column number the name
                    represents.  CardinalValue of MAXCARDINAL means "not
                    found".
                   *)(*
      2-May-91 TGS  The "*Effort----Overtime" columns now work.
                    The "*EffortLessOvertime" columns are now named
                    "*EffortWithOvertime". This, rather than change the
                    calculation of the preexisting Effort columns.
                    ProjectedDuration now uses Sched Performance Ratio rather
                    than Current Cost Efficiency (per Andrew).
      6-May-91 TGS  DurationVarianceDays computes duration from Plan.EarlyEnd
                    and Plan.EarlyStart instead of the duration field.
                    Also fixed a couple of places where it wrongly said
                    EarlyEnd-EarlyEnd instead of EarlyEnd-EarlyStart, and one
                    remaining use of duration instead of EE-ES.
                    While I'm at it, have these places call FindDuration
                    rather than calculating directly (let's be consistent).
      9-May-91 TGS  Adjustments per column review.
                    Some column identifiers renamed. Spelling of "Mathematical"
                    corrected (I couldn't help myself, I majored in math).
     20-May-91 TGS  Comment out code for overtime-type columns.
     29-May-91 RSC  Update SchedulingDelay to be EarlyStart - CPMEnd as per
                    AJL and Bug # 4467.
     19-Jul-91 AJL -Modify DoEndDate so that it works for all end date types.
                   -Fix Late Total End to format as end date.   Bug 4797.
                   -Created a SetHighlight procedure.
     15-Sep-91 EGK  Fixed "ProjectedEndDate" logic so it uses the milestone
                    end date rule if appropriate.
     16-Sep-91 LAA  In DoPropPctComplete, don't compute the value base on
                    baseline data (BCWP and BCWSDollars) unless the baseline
                    exists.  Bug #4639 & 4918.  Also, ColumnPercentage was
                    always returning TRUE, so that was changed too.
    17-Sep-91 TGS   DoFindStartOfSpending & DoFindEndOfSpending were wrong.
                    They now pay attention to costs and begin with more 
                    reasonable defaults.
    18-Sep-91 TGS   Don't show Start/EndOfSpending for Baseline.
    18-Sep-91 EGK   When handling the WBSErrors column, we were still
                    assuming that it was numbered one past the last coding
                    column.  This is no longer true.
    30-Sep-91 AJL   Make SpentEffortPercent show 100% when tasks are done.
     1-Oct-91 AJL   Limit the SpentEffortEndDate to <= AsOfDate.
                    Don't show SpentEffort start or end date unless there
                    is some spent effort.
     3-Oct-91 AJL   Show spent effort/cost start and end dates if either
                    effort or cost was spent.
    03-Oct-91 LAA   CostVariancePercent was producing random number, because
                    it was using RealValue instead of BCWP.
    04-Oct-91 TGS   Fix PropPctAchieved cols. They now agree with the manual
                    for the first time in history. I think. We were using the
                    wrong TotalDuration number and were not factoring in
                    EAC/BAC.
                    Changed TimeCompleted parm from ATask to ADateBlock. This
                    allows it to be used for BaseLine dates too.
                    SpentDuration and ToGoDuration cols work for BaseLine.
    13-Jan-92 TGS   Sigh. Once more, into the breach, to fix "projected 
                    duration" calculation. Hope everyone's happy now.
    23-Jan-92 AJL   Fixed ProjectedCost column, similar to the above fix,
                    made it = SpentCost / Percent Achieved.
    30-Jan-92 TGS   AVaryingAssgnList now contains REALs. Changed a local
                    variable to match this type.
    03-Mar-92 LAA   In ExamineOneResource, changed CtoS to FormatAsAmount
                    so we can show decimal quantities for the amount of a
                    resource assigned.
    07-Apr-92 TGS   Increase max length of numeric expression to 25 from 19.
    =========================================================================
*)

FROM Allocs     IMPORT
    (* CONST *)     WBSLine, OBSLine, AUXLine, FirstOtherCodingLine,
    (* TYPE *)      ATaskPtr, AnAssignmentSummary, ADateBlock, ATaskStatus,
                    ADurationMethod, AFixType, AStartStatus, ATaskFilter,
                    ATaskStatusSet, ATaskFlag, ATaskFlagSet, ASplittingRule,
    (* VARS *)      FixationName, StartStatusName,
    (* PROC *)      GetCodingField;

FROM AsOf       IMPORT
    (* VAR *)       AsOfDate;

FROM AssgnUse  IMPORT 
    (* TYPE *)      ACompletion, (* CompletedHours, YetToGoHours, TotalHours *)
    (* PROC *)      AssignmentHours;

FROM Assignments IMPORT
    (* TYPE *)      AnAssignmentRecord, AnAssignmentArray,
    (* PROC *)      ForEachAssignment;

FROM BigTimeU   IMPORT
    (* TYPE *)      ABigTime,
    (* PROC *)      CompareBigTimes;

FROM CalShift   IMPORT
    (* VAR *)       TimeSheet;

FROM CapData    IMPORT
    (* TYPE *)      ALineTypeSet, AFormatSpecAttribute,
                    AFormatSpecAttributeSet, AFormatSpec,
    (* VAR *)       FormatSpecs, SummaryString, AssignmentString,
                    DelayString, SplitString, DurationString, StatusString,
                    EffortString, PSString, TrueChar, FalseChar, OutputField,
                    StatusPosition;

FROM Captions   IMPORT
    (* TYPE *)      AColumnInfoChoice, AColumnDataField, ASetOfColumnDataFields,
                    AGetColumnInfoProc, AGetColumnValueProc,
                    AFormatColumnValueProc, AColumnDataRecord,
                    ACaptionsOverlayInterface, ACaptionsFunction,
(*    (* VARS *)      GetColumnInfo, GetColumnValue, FormatColumnValue,*)
(*                    FormatTaskColumns, GetColumnPercentage,*)
    (* PROCS *)     GetCurrencyScale;

FROM Chainer    IMPORT
    (* PROC *)      Chain;

FROM ChartForms IMPORT
    (* TYPE *)      AChartFormat;

FROM ColData    IMPORT
    (* TYPE *)      AColumnType;                        (* 29-Aug-90 PFG  *)

FROM ColFind    IMPORT
    (* PROC *)      GetColumnItem,
                    GetColInfoFromPhrasesOrText;        (* 29-Aug-90 PFG  *)

FROM ColumnSupport      IMPORT                          (* 29-Aug-90 PFG  *)
    (* CONST *)     FullTitle,
                    Title1,
                    Title2,
                    DefaultLength,
                    NarrowWidth,
                    NarrowTitle1,
                    NarrowTitle2,
                    FormalName,
                    UniqueID,
                    Percentage,
                    MinExportWidth;

FROM Dialog     IMPORT
    (* PROC *)      FatalError, NotYetImplemented;

FROM Duration   IMPORT
    (* PROC *)      FindDuration;

FROM Edges      IMPORT
    (* TYPE *)      AnEdgePtr,
    (* PROC *)      CheckEdgeValid;

FROM FlexStor   IMPORT
    (* TYPE *)      AnExtHandle, AnExtStoragePreference,
    (* PROC *)      LockObject, ReleaseObject, CreateExtObjectWithSize,
                    MakeHeapCopy,
                    LockObjectArray, ReleaseUnchangedObject;

FROM FormatCommon           IMPORT
    (* PROC *)                  FormatDataValue;

FROM Gantt      IMPORT
    (* TYPE *)      AGanttLineType, ASlackStyle;

FROM Indentation IMPORT
    (* PROC *)      FormatIndentation;

FROM Links      IMPORT
    (* VAR *)       GetDisplayableLink;

FROM LongConvert            IMPORT
    (* PROC *)                  LongToReal;

FROM LStrings   IMPORT
    (* PROC *)      SetString, ConcatS, ConcatLS, Insert, Search,
                    Overlay, TrimFront, TrimRear, SubStr,
                    StringsEqual, TStringToLString, Copy, Procustes,
                    CtoS, Fill, RJust, SetLengthOf, StoC,
                    Remove, LengthOf, Upshift;

FROM MagicNum   IMPORT
    (* CONST *)     IsStringValue,
                    IsRealValue,
                    IsIntValue,
                    IsCardValue,
                    IsBoolValue,
                    IsEnumValue,
                    IsBigStart,
                    IsBigEnd,
                    IsStartDate,
                    IsEndDate,
                    IsDuration,
                    IsSlack,
                    IsCurrency,
                    IsEffort,
                    IsMilestoneEnd,
                    IsDurationUnits,
                    IsEffortUnits,
                    IsTruncatedString;

FROM Menus      IMPORT
    (* PROC *)      WordNumber;

FROM MsgFile    IMPORT
    (* PROC *)      GetMessage;

FROM Overlays   IMPORT
    (* PROC *)      AnOverlayID, ImAnInstallableOverlay,
                    OverlayContext;

FROM OvTree     IMPORT
    (* TYPE *)      AnOverlayProc;

FROM Planner    IMPORT
    (* TYPE *)      ScheduleStartDate;

FROM RealFormat IMPORT
    (* VARS *)      DefaultAmountFormat, DefaultCurrencyFormat,
    (* PROCS *)     FormatAsAmount, FormatAsCurrency;

FROM RsrcMod    IMPORT
    (* TYPE *)      ACostStyle, AResourceType;

FROM RsrcCalc   IMPORT
    (* TYPE *)      AnAssignmentCostTypeSet, AnAssignmentCostType,
    (* PROC *)      AssignmentCost;

FROM Space      IMPORT
    (* PROC *)      ALLOCATE, DEALLOCATE;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS, ADR, SIZE, TSIZE;

FROM TaskColNumbers     IMPORT 
    (* CONST *)     TaskNameColumn,
                    NotesColumn,
                    ResourceColumn,
                    EarlyStartColumn,
                    EarlyEndColumn,
                    DurationColumn,
                    DurationDays,
                    DurationWeeks,
                    DurationMonths,
                    TotalEffort,
                    EffortDays,
                    EffortWeeks,
                    EffortMonths,
                    AUXColumn,
                    WBSColumn,
                    OBSColumn,
                    TaskTypeColumn,
                    StatusColumn,
                    StartStatusColumn,
                    DurationMethodColumn,
                    PercentAchieved,
                    PriorityColumn,
                    Summarizes,
                    UserEnteredStartColumn,
                    LateStartColumn,
                    LateEndColumn,
                    FreeSlackColumn,
                    LateTotalStartColumn,
                    LateTotalEndColumn,
                    TotalSlackColumn,
                    Highlight1Column,
                    Highlight2Column,
                    Highlight3Column,
                    PredSuccColumn,
                    BaselineDuration,
                    BaselineDollars,
                    BaselineEffort,
                    BaselineDollarsToGo,
                    BaselineStartDate,
                    BaselineEndDate,
                    BaselineBCWS,
                    DurationDIVBase,
                    TotalDollars,
                    MathematicalEAC,
                    SpentDollars,
                    SpentDollarsDIVBase,
                    ToGoDollars,
                    CompletedDuration,
                    CompletedDurationDIVBase,
                    ToGoDuration,
                    ToGoDurationDIVBase,
                    CompletedEffort,
                    ToGoEffort,
                    AchievedDollars,
                    CostPerformanceRatio,
                    SchedulePerformanceRatio,
                    BurnRateDollars,
                    ScheduleVariance,
                    CostVariance,
                    VarianceAtCompletion,
                    CostVariancePercent,
                    ScheduleVariancePercent,
                    EACVariancePercent,
                    BlanksColumn,
                    TotalSlackHours,
                    TotalSlackPercent,
                    StartElapsedDays,
                    StartElapsedWeeks,
                    EndElapsedDays,
                    EndElapsedWeeks,
                    DelayPastBaselineStartDays,
                    DelayPastBaselineEndDays,
                    IndentationLevel,
                    ParentWBS,
                    PredecessorWBS,
                    SuccessorWBS,
                    AbbreviatedTaskName,
                    AbbrevParentage,
                    EffortHours,
                    DurationHours,
                    FreeSlackHours,
                    FreeSlackPercent,
                    SpentEffortPercent,
                    PropPctComplete,
                    BaselinePropPctComplete,
                    ResourceLevelingDelay,
                    DurationVarianceDays,
                    CostColumn,
                    CostAmount,
                    ResourceAmount,
                    FixedTaskDelay,
                    LinkStatus,
                    SortSequenceNumber,
                    IsItLate,
                    TotalDollarsAsPctOfBase,
                    SpentDollarsAsPctOfTotal,
                    CurrentCostEfficiency,
                    ProjectedDuration,
                    ProjectedEndDate,
                    ProjectedCost,
                    TimeElapsedPct,
                    SplittingRuleColumn,                (* 14-Sep-90 PFG *)
                    SupposedToStartColumn,              (* 17-Sep-90 PFG *)
                    UserEnteredEndColumn,               (* 17-Sep-90 PFG *)
                    LateIndStartColumn,                 (* 17-Sep-90 PFG *)
                    LateIndEndColumn,                   (* 17-Sep-90 PFG *)
                    EffortVariance, (* 29-Nov-89 RSC added. *)
                    IndSlackHours,
                    IndSlackDays,
                    IndSlackPct,
                    SeqNumColumn,
                    AllowSlackColumn,
                    RequiredStartColumn,

                        (* 3-Apr-91 TGS Added OvertimeDollars..LinkedTaskWBS *)
                    SpentEffortStartDate,
                    SpentEffortEndDate,
                    LinkedTaskWBS,
                    ExtraExpenses,
                    (* 20-May-91 TGS - easy come, easy go...
                    OvertimeDollars,
                    SpentOvertimeDollars,
                    ToGoOvertimeDollars,
                    OvertimeEffortHours,
                    SpentOvertimeEffortHours,
                    ToGoOvertimeEffortHours,
                    BaselineOvertimeDollars,
                    BaselineOvertimeEffortHours,
                    TotalDollarsLessExtras,
                    SpentTotalDollarsLessExtras,
                    ToGoTotalDollarsLessExtras,
                    TotalEffortWithOvertime,
                    ToGoEffortWithOvertime,
                    SpentEffortWithOvertime,
                    BaselineTotalEffortWithOvertime,
                    BaselineTotalDollarsLessExtras,
                    *)

                    LastNonCodingTaskColumn,
                    CodingField1, NumberOfCodingFields,
                    WBSErrors,                                    (* 27-Aug-89 MWP *)
                    HighestRootColumn;

FROM Text       IMPORT
    (* PROC *)      TextExists, CopyLine;

FROM TimeFormat IMPORT
    (* VAR *)       EndDateStyle,
    (* PROCS *)     TimeUtoS, FormatAsEndDateStyle;

FROM Timei      IMPORT
    (* CONST *)     NoDuration, MaxDate,
    (* TYPE *)      ADuration, ADurationUnit, ADate,
    (* PROC *)      DurationToReal, DateToReal, RealToDate;

FROM Timeu      IMPORT
    (* VAR *)       FSMUPH,
    (* PROC *)      DownScale;

FROM TimeXlate  IMPORT
    (* PROC *)      BigTimeToCalendarTime;

FROM TreeObjects IMPORT
    (* TYPE *)      ATreeNode;

FROM VaryAssgnment  IMPORT 
    (* PROC *)      GetVaryingAssgnListEntry, NumberOfRatesInList;

FROM Words      IMPORT
    (* PROC *)      ParseString;

FROM WorkHours   IMPORT
    (* PROC *)      WorkHoursToRealTime;







CONST
    ModuleNumber            = 27300;    (* Private phrases *)
    ModuleNumber2           = 19200;    (* List of columns *)

    Zero                    =   0.0;
    One                     =   1.0;
    Ten                     =  10.0;
    OneHundred              = 100.0;
    NegativeOne             = -1.0;
    MAXCARDINAL             = 65535;
    FMAXCARDINAL            = 65535.0;
    MaxReal                 = 1.79E+308;    (* Local infinity. *)

    AbbreviationLength      = 6;    (* Bytes to trim abbrev. task names to. *)
    Enumerations            = 20;   (* Word number in phrase. *)
    HelpKeyColumnNumber     = 21;





CONST
    HighestKnownColumn = HighestRootColumn;  (* Last one I've ever heard of. *)

VAR
    OverlayID            : AnOverlayID;




    (* Items for producing a resource list *)

TYPE
    ADateType               = (ES,EE,LFS,LFE,LTS,LTE,LIS,LIE);

    AResourceListIncludes   = (ResourcesIncluded,
                               CostsIncluded );

    AResourceListIncludeSet = SET OF AResourceListIncludes;

    AResourceListDecoration = (NoDecoration,
                               DecorateWithQuantities,
                               DecorateWithDollars);

    AResourceListContext = RECORD
        S            : POINTER TO ARRAY [0..255] OF CHAR;   (* KKC Jun 7, 89 *)
        SLen         : CARDINAL;
        Length       : CARDINAL;
        i            : CARDINAL;
        Include      : AResourceListIncludeSet;
        Decorate     : AResourceListDecoration;
        StartDate,
        EndDate      : ADate;
        BaseLine,
        AllFit       : BOOLEAN;
     END;

    ACostSummary    = RECORD  (* 2-Apr-91 TGS *)
        RealVal             : REAL;
        AssignmentCostTypes : AnAssignmentCostTypeSet;
        ExtrasOnly          : BOOLEAN;
    END;








 (* RSC 5/8/87 - moved things around to take into account new cost stuff. *)

PROCEDURE ExamineOneResource( VAR Assignment : AnAssignmentRecord;
                                  Ptr        : ADDRESS ) : BOOLEAN;

VAR
    Context : POINTER TO AResourceListContext;
    j       : CARDINAL;
    NextName: ARRAY [0..69] OF CHAR;



    PROCEDURE FormatNextName();
    VAR
        P           : CARDINAL;
        CostTypes   : AnAssignmentCostTypeSet;
        s           : ARRAY [0..25] OF CHAR;
    BEGIN

            (* Always include the name of the resource. *)

        Copy( Assignment.Resource^.Name, NextName );

        CASE Context^.Decorate OF

          NoDecoration:

        | DecorateWithQuantities:

            ConcatS(  NextName, " " );

            CASE Assignment.Resource^.CostStyle OF
              CAmount:
                FormatAsCurrency( (Assignment.ActualQuantity
                                  + Assignment.YetToGoQuantity),
                                DefaultCurrencyFormat,
                                s,  HIGH(s),
                                FALSE,   (* Right Justify? *)
                                TRUE,    (* Show fractions? *)
                                TRUE  ); (* Show Dollar Sign? *)
                TrimRear(s);
                ConcatLS(NextName,s);
            | CAmountRate:
                FormatAsAmount( (Assignment.ActualQuantity
                               + Assignment.YetToGoQuantity),
                                 DefaultAmountFormat,
                                 s, HIGH(s), 0, 4, FALSE );
                TrimRear(s);
                ConcatLS(NextName, s);
                ConcatS( NextName, " " );
                ConcatLS(NextName, Assignment.Resource^.UnitOfMeasure);
                TrimRear(NextName);
            | CAmountRateTime:
                P := ORD(Assignment.PercentageEach);
                IF (Assignment.MaxRatePercent <> P) AND (P <> 0) THEN
                    FormatAsAmount( FLOAT(Assignment.MaxRatePercent) / FLOAT(P), 
                                    DefaultAmountFormat,
                                    s, HIGH(s), 0, 4, FALSE );
                    TrimRear( s );
                    ConcatLS( NextName, s );
                    ConcatS(  NextName, " @ " );
                END;
                CtoS( P, s );                              (* 20 *)
                ConcatLS( NextName, s );
                ConcatS(  NextName, "%" );
            ELSE
                FatalError();
            END;

        | DecorateWithDollars:

            CostTypes := AnAssignmentCostTypeSet{
                                IncludeToGo,
                                IncludeSpent,
                                IncludeExtras,
                                IncludeOvertime};
            IF (Context^.BaseLine) THEN
                INCL(CostTypes,TreatAsBaseline);
            END;
            FormatAsCurrency(
                    AssignmentCost( Assignment,
                            Context^.StartDate,
                            Context^.EndDate,
                            CostTypes ),
                    DefaultCurrencyFormat,
                    s,
                    HIGH(s),
                    FALSE,      (* Right Justify?  *)
                    TRUE,       (* Show fractions? *)
                    TRUE );     (* Include Symbol? *)

            TrimFront( s );
            TrimRear(  s );
            ConcatS(  NextName, " " );
            ConcatLS( NextName, s );

        ELSE
            FatalError();
        END;

    END FormatNextName;



    PROCEDURE DoOneResource() : BOOLEAN;
    BEGIN
        WITH Context^ DO
            IF (ORD(S^[0]) >= Length - 1) THEN                    (* 23-Jun-87 LAA *)
                AllFit := FALSE;
                RETURN FALSE;
            END;

                (* Separate names with commas. *)
            IF (i > 0) THEN
                ConcatS(S^,", ");                                 (* 17-Jun-87 LAA *)
            END;

            FormatNextName();

                (* Exit loop if not enough room for next name.   If
                   only part of name will fit, trim it.       *)

            j := Length - ORD(S^[0]); (* Max len. *)
            IF (j = 0) THEN
                AllFit := FALSE;
                RETURN FALSE;
            ELSIF (j < ORD(NextName[0])) THEN
                AllFit := FALSE;
                SetLengthOf(NextName,j-1);
            END;

                (* Append name to list. *)
            ConcatLS(S^,NextName);

            INC(i);
        END;

        RETURN TRUE;

    END DoOneResource;


BEGIN
    Context := Ptr;

    WITH Context^ DO
        IF (Assignment.Resource^.Type = Employable) AND
           (ResourcesIncluded IN Include) THEN
            RETURN DoOneResource();
        ELSIF (Assignment.Resource^.Type <> Employable) AND
              (CostsIncluded IN Include) THEN
            RETURN DoOneResource();
        END;
    END;

    RETURN TRUE;

END ExamineOneResource;





PROCEDURE ResourceList(    TaskPtr    : ATaskPtr;
                           LineType   : AGanttLineType;
                           Length     : CARDINAL;
                           Includes   : AResourceListIncludeSet;
                           Decoration : AResourceListDecoration;
                       VAR S          : ARRAY OF CHAR );
VAR
    AssignmentHandle : AnExtHandle;
    Context          : AResourceListContext;
    j                : CARDINAL;
    s2               : ARRAY [0..1] OF CHAR;

BEGIN

    SetLengthOf( S, 0 );
    IF (Length = 0) THEN RETURN; END;

    IF (LineType = Plan) THEN
        WITH TaskPtr^ DO
            AssignmentHandle  := Plan.Assignments;
            Context.StartDate := Plan.Dates.EarlyStart;
            Context.EndDate   := Plan.Dates.EarlyEnd;
        END;
    ELSIF (LineType = Baseline) THEN
        WITH TaskPtr^ DO
            AssignmentHandle  := BaseLine.Assignments;
            Context.StartDate := BaseLine.Dates.EarlyStart;
            Context.EndDate   := BaseLine.Dates.EarlyEnd;
        END;
    ELSE
        FatalError ();
    END;

    (* List as many resource names as will fit.  As we are
       doing so, record where the end of each name is.
    *)

    Context.S           := ADR(S);
    Context.SLen        := HIGH(S);
    Context.Length      := Length;
    Context.Include     := Includes;
    Context.Decorate    := Decoration;
    Context.BaseLine    := (LineType = Baseline);

    WITH Context DO
        AllFit := TRUE;
        i      := 0;
        ForEachAssignment( AssignmentHandle, ExamineOneResource, ADR(Context) );

            (* While there is room, put in amounts. *)

        IF (NOT AllFit) THEN
            j := ORD(S^[0]);
            SetString(s2,"+");
            IF (j < Length) THEN
                ConcatLS(S^,s2);
            ELSE
                Overlay(S^,s2,j,1);
            END;
        END;
    END;

END ResourceList;






    (* ResourceNameList -- Produce a list of all the resources used
                           by the task. *)

PROCEDURE XResourceNameList(     Node     : ATreeNode;
                                 LineType : AGanttLineType;
                                 Length   : CARDINAL;
                             VAR S        : ARRAY OF CHAR );
VAR
    Task    : ATaskPtr;
BEGIN

    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    ResourceList( Task, LineType, Length,
                  AResourceListIncludeSet{ResourcesIncluded},
                  NoDecoration, S );
    Node^.Methods^.UnlockUnchangedDataObject(Node);               (* 11-Jan-88 LAA *)

END XResourceNameList;



PROCEDURE DoDollars( VAR Assignment : AnAssignmentRecord; (* 2-Apr-91 TGS *)
                         Ptr        : ADDRESS) : BOOLEAN;
VAR
    CostContext : POINTER TO ACostSummary;

BEGIN
    CostContext := Ptr;
    WITH CostContext^ DO
        RealVal := RealVal
                    +
                    AssignmentCost
                    (
                    Assignment,
                    0,
                    MAXCARDINAL,
                    AssignmentCostTypes
                    );
        IF (ExtrasOnly) THEN
            (* Subtract the portion contributed by scheduled work *)
            RealVal := RealVal
                        -
                        AssignmentCost
                            (
                            Assignment,
                            0,
                            MAXCARDINAL,
                            (AssignmentCostTypes 
                            - AnAssignmentCostTypeSet
                                {IncludeOvertime, IncludeExtras}
                            )
                            );
        END;
    END;

    RETURN TRUE;

END DoDollars;

(* 20-May-91 TGS
PROCEDURE DoOTEfforts(VAR Assignment : AnAssignmentRecord;  (* 2-Apr-91 TGS *)
                          Ptr        : ADDRESS ) : BOOLEAN;
VAR
    CostContext : POINTER TO ACostSummary;
BEGIN
    CostContext := Ptr;
    WITH CostContext^ DO
        IF (IncludeSpent IN AssignmentCostTypes) AND
            (IncludeToGo  IN AssignmentCostTypes) THEN
            RealVal := RealVal + LongToReal(Assignment.OvertimeHours);
        ELSIF (IncludeSpent IN AssignmentCostTypes) THEN
            RealVal := RealVal 
                    + LongToReal(Assignment.OvertimeHours)
                    - LongToReal(Assignment.YetToGoOvertimeHours);
        ELSIF (IncludeToGo IN AssignmentCostTypes) THEN
            RealVal := RealVal + LongToReal(Assignment.YetToGoOvertimeHours);
        END;
    END;

    RETURN TRUE;

END DoOTEfforts;
*)

PROCEDURE DoFindEndOfSpent(VAR Assignment : AnAssignmentRecord; (* 2-Apr-91 TGS *)
                               Ptr        : ADDRESS ) : BOOLEAN;
VAR
    PEndDate    : POINTER TO ADate;
    IsItOk      : BOOLEAN;
BEGIN
    PEndDate := Ptr;
    WITH Assignment DO
        IF ( Resource^.Type = Employable ) THEN
            IF ( VaryingAssignment <> AnExtHandle(NIL) )    AND
               ( EndOfSpentDate > PEndDate^ )               THEN
                PEndDate^ := EndOfSpentDate;
            END;
        ELSE    (* 17-Sep-91 TGS "cost" resource *)
            IF ( EndOfSpentDate > PEndDate^ ) THEN
                PEndDate^ := EndOfSpentDate;
            END;
        END;
    END;
    RETURN TRUE;
END DoFindEndOfSpent;

PROCEDURE DoFindStartOfSpent(VAR Assignment : AnAssignmentRecord;   (* 2-Apr-91 TGS *)
                                 Ptr        : ADDRESS ) : BOOLEAN;
VAR
    PStartDate  : POINTER TO ADate;
    StartDate,
    EndDate     : ADate;
    Rate        : REAL;
    i, Count    : CARDINAL;
    Found       : BOOLEAN;
BEGIN
    PStartDate := Ptr;
    WITH Assignment DO
    IF ( Resource^.Type = Employable ) THEN
        IF ( VaryingAssignment <> AnExtHandle(NIL) ) THEN
            Count := NumberOfRatesInList( VaryingAssignment );
            i     := 1;
            Found := FALSE;
            WHILE (i <= Count) AND (NOT Found) DO   
                    (* look for the first non-zero-rate entry *)
                    (* if they're all zero-rate entries, we don't change anything *)    
                IF GetVaryingAssgnListEntry
                    ( VaryingAssignment, i, StartDate, EndDate, Rate ) AND
                   ( Rate > Zero )                                     THEN
                    IF (PStartDate^ >  StartDate) THEN
                        PStartDate^ := StartDate;
                    END;
                    Found := TRUE;
                ELSE
                    INC(i);
                END;
            END;
            IF (NOT Found) AND (PStartDate^ > EndOfSpentDate) THEN
                    (* special case: rate(s) were all zero *)
                PStartDate^ := EndOfSpentDate;
            END;
        END;
    ELSE    (* 18-Sep-91 TGS "cost" resource *)
        IF (PStartDate^ >  EndOfSpentDate) THEN
            PStartDate^ := EndOfSpentDate;
        END;
    END;
    END;
    RETURN TRUE;
END DoFindStartOfSpent;










    (* Replacement for "GetColumnInfo" from Captions.Mod.
    *)
PROCEDURE ColumnInfo(       TaskNode        : ATreeNode;
                        VAR Task            : ATaskPtr;
                            ColumnID        : CARDINAL;
                            InfoChoice      : AColumnInfoChoice;
                            Width           : CARDINAL;     (* RSC 7-Feb-89 *)
                        VAR ReturnValue     : AColumnDataRecord);

    PROCEDURE GetNumber( Word : CARDINAL );
    BEGIN
        WITH ReturnValue DO
            DataType      := IsCardValue;
            DataFields    := ASetOfColumnDataFields{CardinalInUse};
            GetColumnItem(ModuleNumber2,
                          TaskColumnInfo,
                          ColumnID,
                          Word,
                          TRUE,
                          CardinalValue,
                          StringValue);         (* 29-Aug-90 PFG *)
        END;
    END GetNumber;


    PROCEDURE GetText( Word : CARDINAL );
    BEGIN
        WITH ReturnValue DO
            DataType   := IsStringValue;
            DataFields := ASetOfColumnDataFields{StringInUse};

            GetColumnItem(ModuleNumber2,
                          TaskColumnInfo,
                          ColumnID,
                          Word,
                          FALSE,
                          CardinalValue,
                          StringValue);         (* 29-Aug-90 PFG *)

            IF ( NOT ( InfoChoice = ColumnFormalName ) ) THEN      (* 17-May-89 MWP *)
               IF (Width >  HIGH(StringValue)) THEN
                   Width := HIGH(StringValue);
               END;
               Procustes( StringValue, Width );

               IF ( (RjustColumn IN FormatSpecs^[ColumnID].Attributes) AND
                    (InfoChoice <> ColumnName) ) THEN
                  RJust( StringValue );
               END;
            END;
        END;
    END GetText;


    PROCEDURE GetBoolean( Word : CARDINAL );
    BEGIN
        WITH ReturnValue DO
            DataType   := IsBoolValue;
            DataFields := ASetOfColumnDataFields{BooleanInUse};

            GetColumnItem(ModuleNumber2,
                          TaskColumnInfo,
                          ColumnID,
                          Word,
                          FALSE,
                          CardinalValue,
                          StringValue);         (* 29-Aug-90 PFG *)
            BooleanValue := (StringValue[1] = "T");  (* Yes, its always in English *)
        END;
    END GetBoolean;


        (* Search for the string now in StringValue.  If found, return
           as a CardinalValue the column it was found in.
        *)
    PROCEDURE DoColumnNameSearch( Word : CARDINAL );
    VAR
        i       : CARDINAL;
        Card    : CARDINAL;
        String  : ARRAY [0..99] OF CHAR;
    BEGIN
        WITH ReturnValue DO
            DataType      := IsCardValue;
            DataFields    := ASetOfColumnDataFields{CardinalInUse};
            CardinalValue := MAXCARDINAL; (* NOT FOUND *)
            Upshift( StringValue ); (* failure here --> not a valid string *)
            TrimRear( StringValue );
            TrimFront(StringValue );

            IF (LengthOf(StringValue) > 0) THEN
                FOR i := 1 TO HighestKnownColumn DO
                    GetColumnItem(ModuleNumber2,
                                  TaskColumnInfo,
                                  i,
                                  Word,
                                  FALSE,
                                  Card,
                                  String);
                    Upshift(   String );
                    TrimRear(  String );
                    TrimFront( String );
                    IF (StringsEqual( String, StringValue )) THEN
                        CardinalValue := i;
                        RETURN;
                    END;
                END;
            END;
        END;

    END DoColumnNameSearch;



BEGIN                       (* GetColumnData *)


        (* 25-Apr-91 RSC New functionality.
                         IF Request is for ColumnName, and the
                            ColumnID is -1 (MAXCARDINAL),
                                Search for the PASSED name and
                                return the column id as the CARDINAL
                                value returned.
        *)
    IF (InfoChoice = ColumnName)  AND
       (ColumnID   = MAXCARDINAL) THEN
        DoColumnNameSearch( FullTitle );
        RETURN;
    END;


            (* If this is not a column we have ever heard of, return an
               empty values record. *)

    IF (ColumnID > HighestKnownColumn) THEN
        WITH ReturnValue DO
            DataType      := IsCardValue;        (* Set defaults *)
            DataFields    := ASetOfColumnDataFields{CardinalInUse,StringInUse};
            BooleanValue  := FALSE;
            RealValue     := Zero;
            CardinalValue := 0;
            AddressValue  := NIL;
            DiscardContext:= NIL;
            SetLengthOf(StringValue,0);
        END;
    ELSE
        WITH ReturnValue DO

            DataType      := IsCardValue;        (* Set defaults *)
            DataFields    := ASetOfColumnDataFields{CardinalInUse};

            CASE InfoChoice OF

              ColumnWidth :

                GetNumber( DefaultLength );

            | ColumnName :

                GetText( FullTitle );

            | ColumnHeading1 :

                GetNumber( NarrowWidth );             (* Width for narrow hdg *)
                IF (Width > CardinalValue) THEN
                    GetText( Title1 );                      (* Full heading *)
                ELSE
                    GetText( NarrowTitle1 );                (* Narrow heading *)
                END;

            | ColumnNarrowHeading1 :

                GetText( NarrowTitle1 );                    (* Narrow heading *)

            | ColumnHeading2 :

                GetNumber( NarrowWidth );             (* Width for narrow hdg *)
                IF (Width > CardinalValue) THEN
                    GetText( Title2 );                      (* Full heading *)
                ELSE
                    GetText( NarrowTitle2 );                (* Narrow heading *)
                END;

            | ColumnNarrowHeading2 :

                GetText( NarrowTitle2 );                    (* Narrow heading *)

            | ColumnNarrowWidth :

                GetNumber( NarrowWidth );                   (* Width for narrow hdg *)

            | ColumnExportWidth :

                GetNumber( MinExportWidth );

            | ColumnFormalName :

                GetText( FormalName );         (* Export name *)

            | ColumnUniqueId :

                GetBoolean( UniqueID );

            | ColumnPhraseRaw :       (*  Retrieve entire line  *)

                GetColInfoFromPhrasesOrText(ModuleNumber2,
                                            TaskColumnInfo,
                                            ColumnID,
                                            StringValue);   (* 29-Aug-90 PFG *)

            | ColumnEnumerations :

                GetNumber( Enumerations );   (* Phrase with enumerations. *)

            | ColumnHelpKey :

                GetText( HelpKeyColumnNumber );

            ELSE
                FatalError();   (* 21-Mar-91 RSC should be in CAPTIONS.MOD *)
            END;
        END;
    END;

END ColumnInfo;





    (* 4-Oct-91 TGS changed parameter from ATask to ADateBlock *)
PROCEDURE TimeCompleted( VAR Dates : ADateBlock )
                                                   : ADuration;
VAR
    i                   : ADuration;
BEGIN                   (* TimeCompleted *)

    WITH Dates DO
        IF (EarlyStart < AsOfDate) THEN
            IF (AsOfDate < EarlyEnd) THEN
                i := FindDuration
                        (EarlyStart, AsOfDate, TimeSheet);
            ELSE
                i := FindDuration
                        (EarlyStart, EarlyEnd, TimeSheet); (* 6-May-91 TGS *)
            END;
        ELSE
            i := NoDuration;
        END;
    END;

    RETURN i;

END TimeCompleted;











PROCEDURE ComputeEACVariancePercent( Task        : ATaskPtr;
                                 VAR ReturnValue : AColumnDataRecord );
BEGIN

    WITH Task^ DO
        WITH ReturnValue DO
            RealValue := RealRatio((BaseLineSummary.Amount
                                    - (CompletedSummary.Amount
                                    + ToGoSummary.Amount)),

                                    BaseLineSummary.Amount);
        END;
    END;

END ComputeEACVariancePercent;






PROCEDURE ResultCheck( Result      : BOOLEAN;
                   VAR ReturnValue : AColumnDataRecord ) : BOOLEAN;
BEGIN
    IF (NOT Result) THEN
        WITH ReturnValue DO
            DataFields := ASetOfColumnDataFields{};
            DataType   := 0;
        END;
    END;
    RETURN Result;
END ResultCheck;








PROCEDURE GetAbbrevTaskName(     TaskPtr : ATaskPtr;
                             VAR s       : ARRAY OF CHAR );
VAR
    StringLength,
    ScrunchContext  : CARDINAL;
    OldChar         : CHAR;
    TrimWords       : ARRAY [0..255] OF CHAR;


    PROCEDURE ScrunchOneByte( VAR ScrunchMe,
                                  ThingsToScrunch : ARRAY OF CHAR;
                              VAR ScrunchIndex    : CARDINAL  ) : BOOLEAN;
    VAR
        WhereFound  : CARDINAL;
    BEGIN
        IF (ScrunchIndex > LengthOf( ThingsToScrunch )) THEN
            RETURN FALSE;
        END;
        WhereFound := LengthOf(ScrunchMe); (* RSC 25-May-89 Search backwards *)
        WHILE (WhereFound > 1) AND
            (ScrunchMe[WhereFound] <> ThingsToScrunch[ ScrunchIndex ]) DO
            DEC( WhereFound );
        END;
        IF (WhereFound > 1) THEN
            Remove( ScrunchMe, WhereFound, 1 );
        ELSE
            INC( ScrunchIndex );  (* Better luck next time *)
        END;
        RETURN TRUE;
    END ScrunchOneByte;


    PROCEDURE ScrunchOneWord( VAR ScrunchMe,
                                  ThingsToScrunch : ARRAY OF CHAR;
                              VAR ScrunchIndex    : CARDINAL  ) : BOOLEAN;
    VAR
        ParseIndex,
        ParseOld,
        WhereFound  : CARDINAL;
        LookFor,
        CompareWith : ARRAY [0..39] OF CHAR;
        Found       : BOOLEAN;
    BEGIN
        WordNumber( ThingsToScrunch, ScrunchIndex, LookFor );
        IF (LengthOf( LookFor ) = 0) THEN
            RETURN FALSE;
        END;

        Found      := FALSE;
        ParseIndex := 1;
        ParseOld   := ParseIndex;
        ParseString( ScrunchMe, ParseIndex, CompareWith );
        WHILE (LengthOf(CompareWith) > 0) DO
            Upshift( CompareWith );
            IF (StringsEqual( CompareWith, LookFor )) THEN
                Remove( ScrunchMe, ParseOld, (ParseIndex - ParseOld) );
                RETURN TRUE;
            END;
            ParseOld   := ParseIndex;
            ParseString( ScrunchMe, ParseIndex, CompareWith );
        END;

        INC( ScrunchIndex );  (* Better luck next time *)

        RETURN TRUE;

    END ScrunchOneWord;


BEGIN
    Copy( TaskPtr^.taskname, s );
    TrimRear(s);
    TrimFront(s);

    IF (LengthOf(s) > AbbreviationLength) THEN

        (* Trim out entire words. *)

        GetMessage( ModuleNumber + 7, TrimWords );  (* Words to trim, comma seperated. *)
        ScrunchContext := 1;

        WHILE (LengthOf(s) > AbbreviationLength) AND
              (ScrunchOneWord( s, TrimWords, ScrunchContext )) DO
            TrimRear(s);
            TrimFront(s);
        END;

        IF (LengthOf(s) = 0) THEN   (* All words are junk words? *)
            Copy( TaskPtr^.taskname, s );
            TrimRear(s);
            TrimFront(s);
        END;

        IF (LengthOf(s) > AbbreviationLength) THEN

            (* Now go for individual bytes. *)

            GetMessage( ModuleNumber + 8, TrimWords );  (* Chars to trim *)
            ScrunchContext := 1;

            WHILE (LengthOf(s) > AbbreviationLength) AND
                  (ScrunchOneByte( s, TrimWords, ScrunchContext )) DO
            END;

            IF (LengthOf(s) > AbbreviationLength) THEN

                (* Remove duplicate adjacent bytes *)

                OldChar        := 40C;  (* default to spaces. *)
                ScrunchContext := 1;
                StringLength   := LengthOf(s);
                WHILE (StringLength > AbbreviationLength) AND
                      (ScrunchContext <= StringLength)    DO
                    IF (s[ ScrunchContext ] = OldChar)    THEN (* Don't do a CAP *)
                        Remove( s, ScrunchContext, 1 );
                        DEC( StringLength );
                    ELSE
                        OldChar := s[ ScrunchContext ];
                        INC( ScrunchContext );  (* RSC 12-May-89 *)
                    END;
                END;
            END;
        END;
    END;

    IF (LengthOf(s) > AbbreviationLength) THEN
        Procustes( s, AbbreviationLength );
    END;

END GetAbbrevTaskName;






PROCEDURE GetMessageWord( PhraseNumber    : CARDINAL;
                          TheWordNumber   : CARDINAL;
                      VAR ReturnValue     : ARRAY OF CHAR );
VAR
    s   : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage( PhraseNumber, s );
    WordNumber( s, TheWordNumber, ReturnValue );
END GetMessageWord;



    (* RealRatio

       Compute the ratio of A:B, taking into account that either or
       both might be zero.

       IF a=0 and b=0    ----> 0
          a = b          ----> 1
          b = 0          ----> infinity
          a = infinity   ----> infinity
          b = infinity   ----> 0
          else           ----> a/b

           When composing complex formulas involving
       division, you will get the most meaningful results if the terms
       with like units are paired, as in the formula for Proportional
       Percent Complete: (BCWP/BCWS) * (TimeCompleted/Duration).
           In this case, we compute a dollar ratio and a time ratio
       separately, then multiply them.  This permits us to compute the
       ratios as 1 in case both numerator and denominator are both
       zero (or infinity), in effect cancelling the zeros instead of
       propagating a zero or infinity.

     *)

PROCEDURE RealRatio ( A, B : REAL ) : REAL;
VAR
    C : REAL;
BEGIN
    IF (B = Zero) THEN             (* Ratio  A : 0  *)
        IF (A = Zero) THEN
            C := Zero;             (*        0  : 0  *)
        ELSE
            C := MaxReal;          (*        N  : 0  *)
        END;
    ELSIF (A >= MaxReal) THEN      (* Ratio Infinity : B *)
        IF (B >= MaxReal) THEN
            C := One;              (*        Infinity  : Infinity  *)
        ELSE
            C := MaxReal;          (*        Infinity  : B  *)
        END;
    ELSIF (B >= MaxReal) THEN      (* Ratio A : Infinity *)
        C := Zero;
    ELSE                           (* Ratio A : B *)
        C := A / B;
    END;
    RETURN C;
END RealRatio;



    (* RealEqualRatio

       Compute the ratio of A:B, taking into account that either or
       both might be zero.

       IF a=b    ----> 1
       else      ----> RealRatio(a,b)

    *)

PROCEDURE RealEqualRatio ( A, B : REAL ) : REAL;
BEGIN
    IF (A=B) THEN RETURN One;
    ELSE RETURN RealRatio(A,B);
    END;
END RealEqualRatio;



PROCEDURE GetATaskDate( Task : ATaskPtr;
                        DateType : ADateType;
                        PlanLine : BOOLEAN ) : ADate;
VAR
        (* The definitions of ADateType will need to be reordered if
           ADateBlock is ever changed. *)
    Trick : RECORD
        CASE BOOLEAN OF
          TRUE : DateBlock : ADateBlock;
        | FALSE: DT: ARRAY ADateType OF ADate;
        END;
    END;
BEGIN
    WITH Task^ DO
        IF (PlanLine) THEN
            Trick.DateBlock := Plan.Dates;
        ELSE
            Trick.DateBlock := BaseLine.Dates;
        END;
    END;
    RETURN Trick.DT[ DateType ];
END GetATaskDate;




PROCEDURE DurationInHours( StartDate, EndDate : ADate  ) : REAL;
VAR
    Duration : ADuration;
    IsNegative : BOOLEAN;
    R : REAL;
BEGIN
    IF (StartDate <= EndDate) THEN
        IsNegative := FALSE;
        Duration   := FindDuration(StartDate,EndDate,TimeSheet);
    ELSE
        IsNegative := TRUE;
        Duration   := FindDuration(EndDate,StartDate,TimeSheet);
    END;
    R := DurationToReal(Duration) / FSMUPH; (* Elapsed Hours *)
    IF (IsNegative) THEN
        R := R * NegativeOne;
    END;
    RETURN R;
END DurationInHours;




PROCEDURE TaskDurationInHours(Task : ATaskPtr;
                              PlanLine : BOOLEAN):REAL;
VAR
    i   : ADuration;
BEGIN
    RETURN DurationInHours( GetATaskDate( Task, ES, PlanLine ),
                            GetATaskDate( Task, EE, PlanLine ) );
END TaskDurationInHours;




        (* ProportionalPercentAchieved is a tricky column.  Ideally, we
           would like to compute a percentage that fills the bar in to
           a length which represents the duration that was expected to
           elapse when this much work was achieved.  When work is achieved
           non-linearly, for example, slower at first, faster in the middle,
           and slower again at the end, the percent filled in needs to be
           exaggerated at the start and ends of the bar, and reduced in the
           middle.

           The effect of this is that it makes tracking a schedule visually
           much easier because fill-in to the left of the as-of-date shows that
           a task is behind schedule, while fill-in to the right is ahead.

           Ideally, this would be computed by finding a date such that the
           integral of the area under the expected work achieved ("S") curve
           up to that date is in proportion to the total area as the
           percent achieved is to 100%.

           However, that is expensive to compute, so we use a simpler formula
           which give the correct fill-in when the task is exactly on schedule,
           and gives plausible fill-ins, in the right direction, when the task
           is ahead or behind.

        *)



PROCEDURE DoPropPctComplete(      Task  : ATaskPtr;
                              VAR Dates : ADateBlock; VAR Value : REAL );
VAR
    TimeElapsed        : REAL;
    Duration           : REAL;
BEGIN
    (* 4-Oct-91 TGS changed this back to what TL4 had.. *)
    Duration      := DurationToReal(
                        FindDuration( Dates.EarlyStart, Dates.EarlyEnd,
                                      TimeSheet
                                    ));
        (* Milestones use the less accurate way of getting the percent
           achieved, because they often have no cost, but this is ok because
           the answer is always either zero or one.   Similarly, if there
           is no baseline to provide a yardstick, we do the best we can
           with the percent achieved field. *)
    WITH Task^ DO
        IF (Duration > Zero) AND (BCWSDollars <> Zero)
           AND (BaseLineExists IN TaskFlags) THEN              (* 16-Sep-91 *)
            Value := RealRatio(BCWP,BCWSDollars)*
                     RealRatio(GetEAC(Task,TRUE),              (* 4-Oct-91 TGS *)
                               GetEAC(Task,FALSE));

        ELSE
            Value := FLOAT(PercentComplete)/OneHundred;
        END;
    END;
        (* When the task bar crosses the as-of-date line, we use a
           formula which fills in the bar up to the as of date line
           whenever the task is exactly on schedule. *)
    WITH Dates DO
        Value :=  Value * RealRatio(DurationToReal(TimeCompleted(Dates)),
                                    Duration);
    END;

    IF (Value > One) THEN                       (* AJL 12-Jun-90 *)
        Value := One;
    END;
END DoPropPctComplete;





PROCEDURE GetElapsedDurationHours(    Task : ATaskPtr;
                                      PlanLine : BOOLEAN) : REAL;
VAR
    LocalRealValue       : REAL;
    Duration             : ADuration;
BEGIN
    WITH Task^ DO
        IF (PlanLine) THEN
            Duration       := TimeCompleted(Plan.Dates);
            LocalRealValue := DurationToReal(Duration) / FSMUPH; (* Elapsed Hours *)
        ELSE
            (* 4-Oct-91 TGS *)
            Duration       := TimeCompleted(BaseLine.Dates);
            LocalRealValue := DurationToReal(Duration) / FSMUPH; (* Elapsed Hours *)
        END;
    END;
    RETURN LocalRealValue;
END GetElapsedDurationHours;




PROCEDURE GetToGoDurationHours(    Task : ATaskPtr;
                                   PlanLine : BOOLEAN ) : REAL;
VAR
    LocalRealValue       : REAL;
    Dates                : ADateBlock;
BEGIN
    IF PlanLine THEN                    (* 4-Oct-91 TGS *)
        Dates := Task^.Plan.Dates;
    ELSE
        Dates := Task^.BaseLine.Dates;
    END;
    LocalRealValue := TaskDurationInHours(Task,PlanLine)
                      - (DurationToReal(TimeCompleted(Dates)) / FSMUPH);
    RETURN LocalRealValue;
END GetToGoDurationHours;




PROCEDURE GetEAC( Task : ATaskPtr; PlanLine : BOOLEAN ) : REAL;
VAR
    LocalRealValue : REAL;
BEGIN
    WITH Task^ DO
        IF (PlanLine) THEN
            LocalRealValue := ToGoSummary.Amount + CompletedSummary.Amount;
        ELSE
            LocalRealValue := BaseLineSummary.Amount;
        END;
    END;
    RETURN LocalRealValue;
END GetEAC;






PROCEDURE GetCostEfficiency( Task : ATaskPtr ) : REAL;   (* Ajusted 19-Apr-89 by RSC. *)
VAR                                                      (* Adjusted 21-Aug-89 by AJL/WKH *)
    LocalRealValue : REAL;
BEGIN
    WITH Task^ DO
        LocalRealValue := RealEqualRatio(GetEAC(Task,TRUE),CompletedSummary.Amount) *
                          RealEqualRatio(BCWP,BaseLineSummary.Amount );
    END;
    RETURN LocalRealValue;
END GetCostEfficiency;









PROCEDURE GetProjectedDurationHours(      Task          : ATaskPtr;
                                          PlanLine      : BOOLEAN ) : REAL;
    (* adjusted 9-May-91 TGS per AJL *)
VAR
    PerformanceRatio : REAL;
BEGIN
    WITH Task^ DO
        IF (PercentComplete > 0) THEN
            (*
            PerformanceRatio := RealEqualRatio(BCWP,BCWSDollars);
            IF (PerformanceRatio <> Zero)      AND
               (PerformanceRatio <> MaxReal)   THEN
                RETURN (GetElapsedDurationHours(Task,PlanLine)
                       / PerformanceRatio);
            END;
            *)
            RETURN (GetElapsedDurationHours(Task, PlanLine) * OneHundred
                    / FLOAT(PercentComplete)); (* 13-Jan-92 TGS *)
        END;
    END;
    RETURN TaskDurationInHours(Task,TRUE (* Plan *) );
END GetProjectedDurationHours;








(*$R-*) (*$T-*)

(*----------------------------------------------------------------------------
    ColumnValue --

    Return the value of the column specified, for the given task and
    Plan/Baseline choice.

    Preconditions:
        The task node must not be NIL, and  The Task must be the result of
        having the task node locked.  It's passed as a VAR parameter so the
        node can be unlocked and relocked if necessary.

    Postconditons:
        The value of the indicated column will be filled in, and TRUE returned
        if there is a value.  Else FALSE will be returned.
----------------------------------------------------------------------------*)

PROCEDURE ColumnValue(    TaskNode          : ATreeNode;
                      VAR Task              : ATaskPtr;
                          ColumnId          : CARDINAL;
                          LineType          : AGanttLineType;
                      VAR ReturnValue       : AColumnDataRecord) : BOOLEAN;

VAR
    Result                  : BOOLEAN;
    PlanLine                : BOOLEAN;
    s                       : ARRAY [0..9] OF CHAR;
    EMSHandle               : AnExtHandle;
    CostSummary             : ACostSummary;


    PROCEDURE Durations();
    BEGIN
        WITH Task^ DO
            WITH ReturnValue DO
                IF (PlanLine) THEN
                    DurationValue := FindDuration
                                     (
                                        Plan.Dates.EarlyStart,
                                        Plan.Dates.EarlyEnd,
                                        TimeSheet
                                     );
                ELSE
                    DurationValue := FindDuration
                                     (
                                        BaseLine.Dates.EarlyStart,
                                        BaseLine.Dates.EarlyEnd,
                                        TimeSheet
                                     );
                END;
                RealValue     := DurationToReal(DurationValue) / FSMUPH; (* Hours *)

                BooleanValue  := (ColumnId = DurationColumn);

                CASE ColumnId OF
                  DurationColumn  :
                    TimeUnitValue  := scale;
                | DurationHours   :
                    TimeUnitValue  := Hours;
                | DurationDays    :
                    TimeUnitValue  := Days;
                | DurationWeeks   :
                    TimeUnitValue  := Weeks;
                |  DurationMonths :
                    TimeUnitValue  := Months;
                ELSE
                    FatalError();
                END;
            END;
        END;
    END Durations;



    PROCEDURE Efforts();
    BEGIN
        WITH Task^ DO
            WITH ReturnValue DO
                IF (PlanLine) THEN
                    RealValue := ToGoSummary.Time + CompletedSummary.Time
                ELSE
                    RealValue := BaseLineSummary.Time;
                END;

                BooleanValue  := (ColumnId = TotalEffort);

                CASE ColumnId OF
                  TotalEffort  :
                    TimeUnitValue := EffortScale;
                | EffortHours  :
                    TimeUnitValue := Hours;
                | EffortDays   :
                    TimeUnitValue := Days;
                | EffortWeeks  :
                    TimeUnitValue := Weeks;
                | EffortMonths :
                    TimeUnitValue := Months;
                ELSE
                    FatalError();
                END;
            END;
        END;
    END Efforts;



    PROCEDURE DoStatus( VAR StringValue : ARRAY OF CHAR );
    VAR
        Stat : ATaskStatus;
        Set  : ATaskStatusSet;
    BEGIN
        Set := Task^.TaskStatusSet;
        Fill(StringValue, " ", 7);

        FOR Stat := Critical TO NeedsRecalculate DO
            IF (Stat IN Set) THEN
                StringValue[StatusPosition[Stat]]
                        := StatusString[ORD(Stat)+1];
            END;
        END;
    END DoStatus;




      (* RSC 1/23/89 Account for milestones. *)

    PROCEDURE DoEndDate( DateType : ADateType; PlanLine : BOOLEAN );
    VAR
        i   : ADuration;
        LStartDate, LEndDate : ADate;
    BEGIN
            (* Get the end date.  Also, if the corresponding start date
               is the same as the end date, format the end date so that
               it matches the start date, rather than at the end of the
               previous day. *)

            (* The working of this procedure relies on the DateType
               being organized into pairs of Start then End, with
               ORD(any start) being even.   So, we can get the 
               corresponding start date type by subtracting 1 from
               the type. *)
        WITH Task^ DO
            WITH ReturnValue DO
                DateValue  := GetATaskDate( Task, DateType, PlanLine );
                LStartDate := GetATaskDate( Task,
                                            VAL(ADateType,ORD(DateType)-1),
                                            PlanLine );
                IF (LStartDate = DateValue) THEN
                    DataType := IsMilestoneEnd;
                END;
            END;
        END;
    END DoEndDate;



        (* Returns the duration in hours, possibly negative, between the
           two dates identified by the Start and End date types. *)

    PROCEDURE GetElapsedHours( Start, End : ADateType;
                               PlanLine   : BOOLEAN    ) : REAL;
    VAR
        StartDate, EndDate : ADate;
        R : REAL;
    BEGIN
        StartDate := GetATaskDate( Task, Start, PlanLine );
        EndDate := GetATaskDate( Task, End, PlanLine );
        RETURN DurationInHours(StartDate,EndDate);
    END GetElapsedHours;



    PROCEDURE DoSlack( Start, End : ADateType;
                       Units      : ADurationUnit;
                       PlanLine   : BOOLEAN);
    BEGIN
        WITH ReturnValue DO
            RealValue := GetElapsedHours(Start,End,PlanLine);
            TimeUnitValue := Units;
        END;
    END DoSlack;


    PROCEDURE DoSlackPercent( Start, End : ADateType;
                              PlanLine   : BOOLEAN );
    BEGIN
        ReturnValue.RealValue := RealRatio(GetElapsedHours(Start,End,PlanLine),
                                           TaskDurationInHours(Task,PlanLine));
    END DoSlackPercent;



    PROCEDURE DoCPMDelay( Units : ADurationUnit ) : BOOLEAN;
    BEGIN
        WITH Task^ DO
            WITH ReturnValue DO
                DateValue := NoDuration;
                IF (PlanLine) THEN
                    WITH Plan.Dates DO
                        IF (fixation = FixedDate) THEN
                            DateValue := FindDuration
                                         (
                                            BigTimeToCalendarTime( UserEnteredStartDate ),
                                            EarlyStart,
                                            TimeSheet
                                         );
                        ELSE
                            RETURN FALSE;
                        END;
                    END;
                ELSE
                    WITH BaseLine.Dates DO
                        IF (fixation = FixedDate) THEN
                            DateValue := 0; (* 12-Sep-90 RSC *)
(*                            DateValue := FindDuration*)
(*                                         ( *)
(*                                            BigTimeToCalendarTime( UserEnteredStartDate ),*)
(*                                            EarlyStart,*)
(*                                            TimeSheet*)
(*                                         );*)
                        ELSE
                            RETURN FALSE;
                        END;
                    END;
                END;
                RealValue     := DurationToReal(DateValue) / FSMUPH; (* Elapsed Hours *)
                TimeUnitValue := Units;
            END;
        END;
        RETURN TRUE;
    END DoCPMDelay;



    PROCEDURE DoParentWBS() : BOOLEAN;
    VAR
        ParentNode      : ATreeNode;
        ParentTask      : ATaskPtr;
    BEGIN
        ParentNode := TaskNode^.Methods^.Parent( TaskNode );
        IF (ParentNode = NIL) THEN
            RETURN FALSE;
        ELSE
            ParentTask := ParentNode^.Methods^.LockFlexStorDataObject( ParentNode );
            GetCodingField (ParentTask^, WBSLine, ReturnValue.StringValue);
            ParentNode^.Methods^.UnlockUnchangedDataObject( ParentNode );
            ParentTask := ATaskPtr(NIL);    (* DEBUGGING *)
        END;
        RETURN TRUE;
    END DoParentWBS;


    PROCEDURE DoDurationDIVBase( TheDuration : ADuration );
    VAR
        i   : ADuration;
    BEGIN
        WITH Task^.BaseLine.Dates DO
            WITH ReturnValue DO
                IF (PlanLine) THEN
                    i := FindDuration
                        (
                            EarlyStart,
                            EarlyEnd,
                            TimeSheet
                        );
                    RealValue := RealRatio(DurationToReal(TheDuration),DurationToReal(i));
                ELSE
                    RealValue := One;
                END;
            END;
        END;
    END DoDurationDIVBase;


    PROCEDURE DoAbbrevParents( VAR StringValue : ARRAY OF CHAR );
    VAR
        ParentNode      : ATreeNode;
        ParentTask      : ATaskPtr;
        s               : ARRAY [0..39] OF CHAR;
    BEGIN
        SetLengthOf( StringValue, 0 );
        SetLengthOf( s,           0 );
        ParentNode := TaskNode^.Methods^.Parent( TaskNode );

        (* While there are parents,
              Make the abbreviated name of this parent.
              IF (There is room for the parent within the string, including
                  room for a slash ("\")),
                  IF (A slash is needed),
                     Insert a slash.
                  Insert the formatted value.
                  Get the next higher parent.
              OTHERWISE,
                  Stop formatting here.
        *)
        WHILE (ParentNode <> NIL) DO
            ParentTask := ParentNode^.Methods^.LockFlexStorDataObject( ParentNode );
            GetAbbrevTaskName( ParentTask, s );
            ParentNode^.Methods^.UnlockUnchangedDataObject( ParentNode );
            IF ((LengthOf(s) + LengthOf(StringValue)) < HIGH(StringValue)) THEN
                IF (LengthOf(StringValue) > 0) THEN
                    ConcatS( s, "\" );
                END;
                Insert( StringValue, s, 1 );
                ParentNode := ParentNode^.Methods^.Parent( ParentNode );
            ELSE
                ParentNode := NIL;
            END;
        END;
    END DoAbbrevParents;



    PROCEDURE AddWBS(     NewNode   : ATreeNode;
                      VAR String    : ARRAY OF CHAR );
    VAR
        NewTask      : ATaskPtr;
        s            : ARRAY [0..39] OF CHAR;
    BEGIN
        NewTask := NewNode^.Methods^.LockFlexStorDataObject( NewNode );
        GetCodingField (NewTask^, WBSLine, s);
        TrimRear(  s );
        TrimFront( s );
        IF ((LengthOf( s ) + LengthOf( String )) <= (HIGH(String) - 2)) THEN
            IF (LengthOf(String) > 0) THEN
                ConcatS( String, ", " );
            END;
            ConcatLS( String, s );
        END;
        NewNode^.Methods^.UnlockUnchangedDataObject( NewNode );
    END AddWBS;



    PROCEDURE DoPredecessorWBS(     EdgeList : AnEdgePtr;
                                VAR String   : ARRAY OF CHAR );
    BEGIN
        SetLengthOf( String, 0 );

        WHILE (EdgeList <> NIL) DO
            CheckEdgeValid( EdgeList );
            AddWBS( EdgeList^.headtask, String );
            EdgeList := EdgeList^.taillink;
        END;
    END DoPredecessorWBS;



    PROCEDURE DoSuccessorWBS(     EdgeList : AnEdgePtr;
                              VAR String   : ARRAY OF CHAR );
    BEGIN
        SetLengthOf( String, 0 );

        WHILE (EdgeList <> NIL) DO
            CheckEdgeValid( EdgeList );
            AddWBS( EdgeList^.tailtask, String );
            EdgeList := EdgeList^.headlink;
        END;
    END DoSuccessorWBS;





    PROCEDURE GetMathematicalEAC() : REAL;
    VAR
        LocalRealValue : REAL;
    BEGIN
        WITH Task^ DO
            (* MoneySpent + MoneyYetToBeSpent *)
            IF (PlanLine) THEN
                LocalRealValue := (CompletedSummary.Amount
                                 +  BaseLineSummary.Amount)
                                 -  BCWP;
            ELSE
                LocalRealValue := BaseLineSummary.Amount;
            END;
        END;
        RETURN LocalRealValue;
    END GetMathematicalEAC;



    PROCEDURE SetHighlight( Highlight : ATaskFilter; Symbol : CHAR );
    BEGIN
        WITH ReturnValue DO
            Fill(StringValue, " ", 1);
            IF (Highlight IN Task^.FilterSet) THEN
                StringValue[1] := Symbol;
            END;
        END;
    END SetHighlight;




    PROCEDURE DoColumnsPart1() : BOOLEAN;

    VAR
        Result              : BOOLEAN;                            (* 10-Jul-89 LAA *)


    BEGIN

    WITH Task^ DO
        Result := TRUE;
        WITH ReturnValue DO
            CASE ColumnId OF
            | TaskNameColumn :
                Copy(taskname, StringValue);

            | NotesColumn :
                IF (TextExists(notes)) THEN
                    CopyLine(notes, 0, StringValue);
                ELSE
                    SetLengthOf(StringValue, 0);
                END;

            | ResourceColumn :
                ResourceList( Task, LineType, HIGH(StringValue),
                              AResourceListIncludeSet{ResourcesIncluded},
                              NoDecoration, StringValue );

            | EarlyStartColumn :
                DateValue := GetATaskDate( Task, ES, PlanLine );

            | EarlyEndColumn :
                DoEndDate( EE, PlanLine );

            | DurationColumn, DurationDays, DurationWeeks, DurationMonths :
                Durations();

            | TotalEffort, EffortDays, EffortWeeks, EffortMonths :
                Efforts();

            | AUXColumn :
                GetCodingField (Task^, AUXLine, StringValue);

            | WBSColumn :
                GetCodingField (Task^, WBSLine, StringValue);

            | OBSColumn :
                GetCodingField (Task^, OBSLine, StringValue);

            | TaskTypeColumn :
                IF (TaskNode^.Methods^.GetSubtree(TaskNode) = NIL) THEN
                    CardinalValue := ORD(fixation);
                    Copy(FixationName[fixation], StringValue);
                ELSE
                    Copy( SummaryString, StringValue );
                END;
                Upshift(StringValue);

            | StatusColumn :
                DoStatus( StringValue );

            | StartStatusColumn :
                CardinalValue := ORD(StartStatus);
                Copy(StartStatusName[StartStatus], StringValue);

            | DurationMethodColumn :
                IF (TaskNode^.Methods^.GetSubtree(TaskNode) = NIL) THEN
                    CardinalValue := ORD(DurationMethod);
                    GetMessageWord( ModuleNumber+1,CardinalValue+1,
                                    StringValue );
                ELSE
                    Result := FALSE;
                END;

            | PercentAchieved :
                IF (PlanLine) THEN                            (* 16-Feb-88 LAA *)
                    RealValue := FLOAT(PercentComplete) / OneHundred;
                ELSE
                    RealValue := Zero;
                END;

            | PriorityColumn :
                IF (TaskNode^.Methods^.GetSubtree(TaskNode) = NIL) THEN
                    RealValue := FLOAT(priority) / Ten;
                ELSE
                    Result := FALSE;
                END;

            | Summarizes :
                GetDisplayableLink(TaskNode, StringValue);             (* 02-Nov-87 LAA *)

            | UserEnteredStartColumn :        (* 17-Sep-90 PFG changed from FixedStartColumn *)
                IF (PlanLine) AND
                   (TaskNode^.Methods^.GetSubtree(TaskNode) = NIL) AND (* 4-Apr-91 TGS *)
                   ((fixation = FixedDate) OR
                   (StartStatus = StartedS) OR (StartStatus = DoneS)) THEN
                    BigTimeValue := UserEnteredStartDate;
                ELSE
                    Result := FALSE;    (* 12-Sep-90 RSC *)
                END;

            | SupposedToStartColumn :         (* 17-Sep-90 PFG *)
                IF (PlanLine) THEN
                    BigTimeValue := SupposedToStart;
                ELSE
                    Result := FALSE;
                END;

            | UserEnteredEndColumn :          (* 17-Sep-90 PFG *)
                IF (PlanLine) AND 
                   (TaskNode^.Methods^.GetSubtree(TaskNode) = NIL) AND (* 4-Apr-91 TGS *)
                   ((fixation = FixedDate) OR
                   (StartStatus = DoneS)) THEN
                    BigTimeValue := UserEnteredEndDate;
                ELSE
                    Result := FALSE;
                END;

            | LateStartColumn :
                DateValue := GetATaskDate( Task, LFS, PlanLine );

            | LateEndColumn : (* RSC 1/23/89 Account for milestones. *)
                DoEndDate( LFE, PlanLine );

            | LateIndStartColumn :        (* 17-Sep-90 PFG *)
                DateValue := GetATaskDate( Task, LIS, PlanLine );

            | LateIndEndColumn :          (* 17-Sep-90 PFG *)
                DoEndDate( LIE, PlanLine );

            | FreeSlackColumn :
                DoSlack( EE, LFE, Days, PlanLine );

            | LateTotalStartColumn :
                DateValue := GetATaskDate( Task, LTS, PlanLine );

            | LateTotalEndColumn :
                DoEndDate( LTE, PlanLine );

            | TotalSlackColumn :
                DoSlack( EE, LTE, Days, PlanLine );

            | Highlight1Column :
                SetHighlight( Highlight3, "1");

            | Highlight2Column :
                SetHighlight( Highlight4, "2");

            | Highlight3Column :
                SetHighlight( Highlight5, "3");

            | PredSuccColumn :
                Fill(StringValue, " ", 1);
                IF (Highlight1 IN FilterSet) THEN
                    StringValue[1] := PSString[1];
                ELSIF (Highlight2 IN FilterSet) THEN
                    StringValue[1] := PSString[2];
                END;

            | BaselineDuration :
                WITH BaseLine.Dates DO
                    DurationValue := FindDuration
                                        (
                                        EarlyStart,
                                        EarlyEnd,
                                        TimeSheet
                                        );
                END;
                TimeUnitValue := scale;
                RealValue     := DurationToReal(DurationValue) / FSMUPH; (* Elapsed Hours *)

            | BaselineDollars :
                RealValue := BaseLineSummary.Amount;

            | BaselineEffort :
                RealValue     := BaseLineSummary.Time;
                TimeUnitValue := EffortScale;

            | BaselineDollarsToGo :                             (* 08-Feb-88 LAA *)
                IF (PlanLine) THEN
                    RealValue := BaseLineSummary.Amount - BCWP;
                ELSE
                    RealValue := BaseLineSummary.Amount;
                END;

            | BaselineStartDate :
                DateValue := BaseLine.Dates.EarlyStart;

            | BaselineEndDate :   (* RSC 1/23/89 Account for milestones. *)
                DoEndDate( EE, FALSE (* always baseline *) );

            | BaselineBCWS :
                RealValue := BCWSDollars;

            | DurationDIVBase :
                DoDurationDIVBase
                    (
                    FindDuration
                        (
                        Task^.Plan.Dates.EarlyStart,
                        Task^.Plan.Dates.EarlyEnd,
                        TimeSheet
                        )
                    ); (* 6-May-91 TGS *)

            | TotalDollars :
                RealValue := GetEAC(Task,PlanLine);

            | MathematicalEAC :
                RealValue := GetMathematicalEAC();

            | SpentDollars :
                IF (PlanLine) THEN
                    RealValue := CompletedSummary.Amount;
                ELSE
                    RealValue := Zero;
                END;

            | SpentDollarsDIVBase :
                IF (PlanLine) THEN
                    RealValue := RealRatio(CompletedSummary.Amount,
                                            BaseLineSummary.Amount);
                ELSE
                    RealValue := Zero;
                END;

            | ToGoDollars :
                IF (PlanLine) THEN
                    RealValue := ToGoSummary.Amount;
                ELSE
                    RealValue := BaseLineSummary.Amount;
                END;

            | CompletedDuration :
                RealValue := GetElapsedDurationHours(Task,PlanLine);
                TimeUnitValue  := Task^.scale;

            | CompletedDurationDIVBase :
                DoDurationDIVBase( TimeCompleted(Task^.Plan.Dates) );

            | ToGoDuration :
                RealValue := GetToGoDurationHours(Task,PlanLine);
                TimeUnitValue  := Task^.scale;

            | ToGoDurationDIVBase :
                DoDurationDIVBase
                    ( 
                    FindDuration
                        (
                        Task^.Plan.Dates.EarlyStart,
                        Task^.Plan.Dates.EarlyEnd,
                        TimeSheet
                        )
                    - TimeCompleted(Task^.Plan.Dates)
                    );

            | CompletedEffort :
                IF (PlanLine) THEN                            (* 16-Feb-88 LAA *)
                    RealValue := CompletedSummary.Time;
                ELSE
                    RealValue := Zero;
                END;
                TimeUnitValue := EffortScale;

            | ToGoEffort :
                IF (PlanLine) THEN                            (* 16-Feb-88 LAA *)
                    RealValue := ToGoSummary.Time;
                ELSE
                    RealValue := BaseLineSummary.Time;
                END;
                TimeUnitValue := EffortScale;

            | AchievedDollars :
                RealValue := BCWP;

            | CostPerformanceRatio :
                RealValue := RealEqualRatio(BCWP, CompletedSummary.Amount);

            | SchedulePerformanceRatio :
                RealValue := RealEqualRatio(BCWP,BCWSDollars);

            | BurnRateDollars :
                (*  This is BCWS / ACWP  *)

                RealValue := RealEqualRatio(BCWSDollars,CompletedSummary.Amount );

            ELSE
                Result := FALSE;
            END;
        END;
    END;

    RETURN Result;

    END DoColumnsPart1;




    PROCEDURE ElapsedTimeFromStart(Date : ADate) : REAL;
    VAR
        Value : ADuration;
    BEGIN
        IF (ScheduleStartDate >= Date) THEN
            Value := NoDuration;
        ELSE
            Value := FindDuration( ScheduleStartDate, Date, TimeSheet );
        END;
        RETURN (DurationToReal(Value) / FSMUPH);
    END ElapsedTimeFromStart;



    PROCEDURE DoEffortVariance() : REAL;    (* 29-Nov-89 RSC Added this *)
    VAR
         Value : REAL;
    BEGIN
         WITH Task^ DO
             Value := RealRatio(BCWP,BaseLineSummary.Amount); (* Get REAL % complete. *)

             IF (Value < MaxReal) THEN
                 Value := (BaseLineSummary.Time * Value) - CompletedSummary.Time;
             END;
         END;

         RETURN Value;

    END DoEffortVariance;



    PROCEDURE DoRequiredStartValue(  VAR StringValue : ARRAY OF CHAR );
    VAR
        i : CARDINAL;
        Set  : ATaskFlagSet;
    BEGIN
        i := 0;
        Set := Task^.TaskFlags;
            (* Convert the bits into an index, 0..3. *)
        IF (NoSoonerStart IN Set) THEN
            INC(i);
        END;
        IF (NoLaterStart IN Set) THEN
            INC(i,2);
        END;
            (* Look up the description. *)
        GetMessageWord(ModuleNumber+16, i+1, StringValue);
    END DoRequiredStartValue;

    PROCEDURE DoColumnsPart2() : BOOLEAN;

    VAR
        Result              : BOOLEAN;                            (* 10-Jul-89 LAA *)
        TempBigTime         : ABigTime;

    BEGIN (* DoColumnsPart2 *)

    WITH Task^ DO
        Result := TRUE;                                           (* 10-Jul-89 LAA *)
        WITH ReturnValue DO
            CASE ColumnId OF
                (* COLUMNS ADDED 3-MAR-89 BY RSC:   *)

              ScheduleVariance :
                RealValue := BCWP - BCWSDollars;

            | CostVariance :
                RealValue := BCWP - CompletedSummary.Amount;

            | EffortVariance :    (* 29-Nov-89 RSC Added this.... *)
                RealValue := DoEffortVariance();

            | VarianceAtCompletion :
                RealValue := BaseLineSummary.Amount
                             - (CompletedSummary.Amount + ToGoSummary.Amount);

            | CostVariancePercent :
                RealValue := RealRatio((BCWP - CompletedSummary.Amount),      (* 03-Oct-91 *)
                                        BCWP);

            | ScheduleVariancePercent :
                RealValue := RealRatio((BCWP - BCWSDollars),BCWSDollars);

            | EACVariancePercent :
                ComputeEACVariancePercent( Task, ReturnValue );

            | BlanksColumn :      (* RSC 3-Mar-89 *)
                SetLengthOf(StringValue, 0);

            | IndentationLevel :
                CardinalValue := TaskNode^.Methods^.IndentationLevel(TaskNode)
                                 + 1;

            | TotalSlackHours  :
                DoSlack( EE, LTE, Hours, PlanLine );

            | TotalSlackPercent       :
                DoSlackPercent( EE, LTE, PlanLine );

            | StartElapsedDays        :
                RealValue := ElapsedTimeFromStart(Plan.Dates.EarlyStart);
                BooleanValue  := FALSE;
                TimeUnitValue := Days;

            | StartElapsedWeeks       :
                RealValue := ElapsedTimeFromStart(Plan.Dates.EarlyStart);
                BooleanValue  := FALSE;
                TimeUnitValue := Weeks;

            | EndElapsedDays          :
                RealValue := ElapsedTimeFromStart(Plan.Dates.EarlyEnd);
                BooleanValue  := FALSE;
                TimeUnitValue := Days;


            | EndElapsedWeeks         :
                RealValue := ElapsedTimeFromStart(Plan.Dates.EarlyEnd);
                BooleanValue  := FALSE;
                TimeUnitValue := Weeks;

            | DelayPastBaselineStartDays  :  (* NEEDS A BASELINE *)
                RealValue    := WorkHoursToRealTime
                                    (
                                    DurationInHours
                                        (
                                        Plan.Dates.EarlyStart,
                                        BaseLine.Dates.EarlyStart
                                        ),
                                    Days
                                    );

            | DelayPastBaselineEndDays    :  (* NEEDS A BASELINE *)
                RealValue    := WorkHoursToRealTime
                                    (
                                    DurationInHours
                                        (
                                        Plan.Dates.EarlyEnd,
                                        BaseLine.Dates.EarlyEnd
                                        ),
                                    Days
                                    );

            | ParentWBS               :
                Result := DoParentWBS();

            | PredecessorWBS          :
                DoPredecessorWBS( antetasks, StringValue );

            | SuccessorWBS            :
                DoSuccessorWBS( desctasks, StringValue );

            | AbbreviatedTaskName     :
                GetAbbrevTaskName( Task, StringValue );

            | AbbrevParentage         :
                DoAbbrevParents( StringValue );

            | EffortHours             :
                Efforts();

            | DurationHours           :
                Durations();

            | FreeSlackHours          :
                DoSlack( EE, LFE, Hours, PlanLine );

            | FreeSlackPercent        :
                DoSlackPercent( EE, LFE, PlanLine );

            | SpentEffortPercent      :
                IF (StartStatus = DoneS) THEN
                    RealValue := One;
                ELSE
                    RealValue := RealRatio
                                    (CompletedSummary.Time,
                                    (CompletedSummary.Time + ToGoSummary.Time));   (* 7/7/89 EGK *)
                END;

            | PropPctComplete         :
                IF (PlanLine) THEN
                    DoPropPctComplete( Task, Plan.Dates, RealValue ); 
                ELSE
                    DoPropPctComplete( Task, BaseLine.Dates, RealValue ); (* 18-Jul-90 WKH *) 
                END;

            | BaselinePropPctComplete     :
                DoPropPctComplete( Task, BaseLine.Dates, RealValue );

            | ResourceLevelingDelay       :   (* PLAN LINE ONLY *)
                TempBigTime := SupposedToStart;

                        (* 29-May-91 RSC REMOVED THIS:
                        *)
(*                IF (CompareBigTimes(UserEnteredStartDate,TempBigTime)<0) THEN*)
(*                    TempBigTime := UserEnteredStartDate;*)
(*                END;*)
                WITH Plan.Dates DO
                    DateValue := FindDuration
                                    (
                                    BigTimeToCalendarTime( TempBigTime ),
                                    EarlyStart,
                                    TimeSheet
                                    );
                    RealValue := DurationToReal(DateValue) / FSMUPH; (* Elapsed Hours *)
                END;
                RealValue     := WorkHoursToRealTime( RealValue, Days );

            | DurationVarianceDays        :  (* NEEDS A BASELINE *)
                RealValue := (
                             DurationToReal
                                (
                                FindDuration
                                    (
                                    BaseLine.Dates.EarlyStart,
                                    BaseLine.Dates.EarlyEnd,
                                    TimeSheet
                                    )
                                )
                             - DurationToReal (* 6-May-91 TGS *)
                                (
                                FindDuration
                                    (
                                    Plan.Dates.EarlyStart,
                                    Plan.Dates.EarlyEnd,
                                    TimeSheet
                                    )
                                )
                             )
                             / FSMUPH; (* Elapsed Hours *)
                RealValue := WorkHoursToRealTime( RealValue, Days );


            | CostColumn              :
                ResourceList( Task, LineType, HIGH(StringValue),
                              AResourceListIncludeSet{CostsIncluded,ResourcesIncluded},
                              DecorateWithDollars, StringValue );

            | CostAmount              :
                ResourceList( Task, LineType, HIGH(StringValue),
                              AResourceListIncludeSet{CostsIncluded},
                              DecorateWithQuantities, StringValue );

            | ResourceAmount          :
                ResourceList( Task, LineType, HIGH(StringValue),
                              AResourceListIncludeSet{ResourcesIncluded},
                              DecorateWithQuantities, StringValue );

            | FixedTaskDelay       :
                Result := DoCPMDelay( Days );

            | LinkStatus              :
                GetMessageWord( ModuleNumber + 9, (ORD(rollupstatus) + 1), StringValue );

            | SortSequenceNumber      :
                CardinalValue   := TaskSortOrder;

            | IsItLate                :
                BooleanValue := (Plan.Dates.EarlyEnd > BaseLine.Dates.EarlyEnd);

            | TotalDollarsAsPctOfBase     :
                RealValue := RealRatio(GetEAC(Task,PlanLine),BaseLineSummary.Amount);

            | SpentDollarsAsPctOfTotal    :
                IF (PlanLine) THEN
                    RealValue := RealRatio(CompletedSummary.Amount,
                                           GetEAC(Task,PlanLine));
                ELSE
                    RealValue := Zero;
                END;

            | CurrentCostEfficiency       :
                RealValue := GetCostEfficiency(Task);

            | ProjectedDuration           :
                RealValue := GetProjectedDurationHours( Task, PlanLine );
                TimeUnitValue := scale;

            | ProjectedEndDate            :
                RealValue := DateToReal( Plan.Dates.EarlyStart )
                            + (GetProjectedDurationHours(Task,PlanLine) * FSMUPH);
                IF (RealValue >= FMAXCARDINAL) THEN
                    DateValue := MaxDate;
                ELSE
                    DateValue := RealToDate(RealValue);
                END;
                IF (DateValue = Plan.Dates.EarlyStart) THEN
                    DataType := IsMilestoneEnd;     (* 9/14/91 EGK *)
                END;

            | ProjectedCost               : (* Adjusted 9-May-91 TGS per AJL *)
                IF (PercentComplete = 0) THEN
                    RealValue := GetEAC(Task,PlanLine);   (* In the future. *)
                ELSE
                    WITH Task^ DO
                        RealValue := CompletedSummary.Amount * OneHundred
                                     / FLOAT(PercentComplete); (* 23-Jan-92 AJL *)
                    END;
                END;

            | TimeElapsedPct  :
                IF (duration = NoDuration) THEN
                    IF (StartStatus = DoneS) THEN
                        RealValue := One;
                    ELSE
                        RealValue := Zero;
                    END;
                ELSE
                    DurationValue    := TimeCompleted(Task^.Plan.Dates);
                    RealValue        := RealRatio
                                            (
                                            DurationToReal( DurationValue),
                                            DurationToReal
                                                ( 
                                                FindDuration
                                                    (
                                                    Plan.Dates.EarlyStart,
                                                    Plan.Dates.EarlyEnd,
                                                    TimeSheet
                                                    )
                                                )
                                            ); (* 6-May-91 TGS *) 
                    END;

            | CodingField1..CodingField1+NumberOfCodingFields-1:
                GetCodingField (Task^,
                                (FirstOtherCodingLine + (ColumnId - CodingField1)),
                                ReturnValue.StringValue);

            | WBSErrors :                   (* 9/18/91 EGK *)
                GetCodingField (Task^,
                                (FirstOtherCodingLine + NumberOfCodingFields),
                                ReturnValue.StringValue);

            | SplittingRuleColumn :                 (* 14-Sep-90 PFG  *)
                IF (TaskNode^.Methods^.GetSubtree(TaskNode) = NIL) THEN
                    CardinalValue := ORD(SplittingRule);
                    GetMessageWord( ModuleNumber+13,CardinalValue+1,
                                    StringValue );
                ELSE
                    Result := FALSE;
                END;

            | IndSlackHours :                 (* 9-Oct-90 AJL  *)
                DoSlack( LIE, LFE, Hours, PlanLine );

            | IndSlackDays :                  (* 9-Oct-90 AJL  *)
                DoSlack( LIE, LFE, Days, PlanLine );

            | IndSlackPct :                   (* 9-Oct-90 AJL  *)
                DoSlackPercent( LIE, LFE, PlanLine );

            | SeqNumColumn :                  (* 9-Oct-90 AJL  *)
                CardinalValue   := SequenceNumber;

            | AllowSlackColumn:      (* Force critical *)
                BooleanValue := ( ForceCritical IN TaskFlags );

            | RequiredStartColumn:
                DoRequiredStartValue( StringValue );

            ELSE
                Result := FALSE;

            END;
        END;
    END;

    RETURN Result;                                                (* 10-Jul-89 LAA *)

    END DoColumnsPart2;

    PROCEDURE GetAssignmentHandle( ItIsPlan : BOOLEAN) : BOOLEAN;

    BEGIN
        IF ( ItIsPlan ) THEN
            EMSHandle := Task^.Plan.Assignments;
        ELSE
            EMSHandle := Task^.BaseLine.Assignments;
        END;

        IF (EMSHandle = AnExtHandle(NIL)) THEN (* Is there a handle? *)
            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END;
    END GetAssignmentHandle;

    PROCEDURE DoColumnsPart3() : BOOLEAN;

    VAR
        Result              : BOOLEAN;                            (* 10-Jul-89 LAA *)
        TempBigTime         : ABigTime;

    BEGIN (* DoColumnsPart3 *)

    CostSummary.AssignmentCostTypes := AnAssignmentCostTypeSet{};
    IF (NOT PlanLine) THEN
        INCL(CostSummary.AssignmentCostTypes, TreatAsBaseline);
    END;

    WITH Task^ DO
        Result := TRUE;                                           (* 10-Jul-89 LAA *)
        WITH ReturnValue DO
            CASE ColumnId OF
                (* COLUMNS ADDED 3-APR-91 BY TGS:   *)

            | SpentEffortStartDate             : (* 3-Apr-91 TGS *)
                IF (PlanLine)
                   AND
                   ((CompletedSummary.Time > Zero) OR (CompletedSummary.Amount > Zero))
                   AND
                   (GetAssignmentHandle( PlanLine )) THEN
                    DateValue := AsOfDate;
                    IF (DateValue >  Plan.Dates.EarlyStart) THEN
                        DateValue := Plan.Dates.EarlyStart;
                    END;
                    ForEachAssignment
                        (EMSHandle, DoFindStartOfSpent, ADR(DateValue));
                ELSE
                    Result := FALSE;
                END;

            | SpentEffortEndDate               : (* 3-Apr-91 TGS *)
                IF (PlanLine)
                   AND
                   ((CompletedSummary.Time > Zero) OR (CompletedSummary.Amount > Zero))
                   AND
                   (GetAssignmentHandle( PlanLine )) THEN
                    DateValue := 0;             (* 17-Sep-91 TGS *)
                    ForEachAssignment
                        (EMSHandle, DoFindEndOfSpent, ADR(DateValue));
                    IF (DateValue >  AsOfDate) THEN
                        DateValue := AsOfDate;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | LinkedTaskWBS                    : (* 3-Apr-91 TGS *)
                IF TextExists(summarizes) THEN
                    CopyLine(summarizes, 4, StringValue);
                ELSE
                    SetLengthOf(StringValue, 0);
                END;

            | ExtraExpenses                    : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeExtras);
                        ExtrasOnly := TRUE;
                        ForEachAssignment
                            (EMSHandle, DoDollars, ADR(CostSummary));
                        RealValue := RealVal;
                    END;
                ELSE
                    Result := FALSE;
                END;

            (* 20-May-91 TGS - Easy come, easy go...
            | OvertimeDollars                  : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeToGo);
                        INCL(AssignmentCostTypes, IncludeOvertime);
                        ExtrasOnly := TRUE;
                        ForEachAssignment
                            (EMSHandle, DoDollars, ADR(CostSummary));
                        RealValue := RealVal;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | SpentOvertimeDollars             : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeOvertime);
                        ExtrasOnly := TRUE;
                        ForEachAssignment
                            (EMSHandle, DoDollars, ADR(CostSummary));
                        RealValue := RealVal;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | ToGoOvertimeDollars              : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeToGo);
                        INCL(AssignmentCostTypes, IncludeOvertime);
                        ExtrasOnly := TRUE;
                        ForEachAssignment
                            (EMSHandle, DoDollars, ADR(CostSummary));
                        RealValue := RealVal;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | OvertimeEffortHours              : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeToGo);
                        ForEachAssignment
                            (EMSHandle, DoOTEfforts, ADR(CostSummary));
                        RealValue := RealVal;
                        TimeUnitValue := Hours;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | SpentOvertimeEffortHours         : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        ForEachAssignment
                            (EMSHandle, DoOTEfforts, ADR(CostSummary));
                        RealValue := RealVal;
                        TimeUnitValue := Hours;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | ToGoOvertimeEffortHours          : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeToGo);
                        ForEachAssignment
                            (EMSHandle, DoOTEfforts, ADR(CostSummary));
                        RealValue := RealVal;
                        TimeUnitValue := Hours;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | BaselineOvertimeDollars          : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( FALSE ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeToGo);
                        INCL(AssignmentCostTypes, IncludeOvertime);
                        ExtrasOnly := TRUE;
                        ForEachAssignment
                            (EMSHandle, DoDollars, ADR(CostSummary));
                        RealValue := RealVal;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | BaselineOvertimeEffortHours      : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( FALSE ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeToGo);
                        ForEachAssignment
                            (EMSHandle, DoOTEfforts, ADR(CostSummary));
                        RealValue := RealVal;
                        TimeUnitValue := Hours;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | TotalDollarsLessExtras           : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeToGo);
                        ExtrasOnly := FALSE;
                        ForEachAssignment
                            (EMSHandle, DoDollars, ADR(CostSummary));
                        RealValue := RealVal;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | SpentTotalDollarsLessExtras      : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        ExtrasOnly := FALSE;
                        ForEachAssignment
                            (EMSHandle, DoDollars, ADR(CostSummary));
                        RealValue := RealVal;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | ToGoTotalDollarsLessExtras       : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeToGo);
                        ExtrasOnly := FALSE;
                        ForEachAssignment
                            (EMSHandle, DoDollars, ADR(CostSummary));
                        RealValue := RealVal;
                    END;
                ELSE
                    Result := FALSE;
                END;

            | TotalEffortWithOvertime          : (* 2-May-91 TGS *)
                (* get regular effort *)
                IF (PlanLine) THEN
                    RealValue := ToGoSummary.Time + CompletedSummary.Time
                ELSE
                    RealValue := BaseLineSummary.Time;
                END;
                (* add overtime effort, if any *)
                IF GetAssignmentHandle( PlanLine ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeToGo);
                        ForEachAssignment
                            (EMSHandle, DoOTEfforts, ADR(CostSummary));
                        RealValue := RealValue + RealVal;
                    END;
                END;
                TimeUnitValue := EffortScale;
                
            | SpentEffortWithOvertime          : (* 2-May-91 TGS *)
                IF (PlanLine) THEN
                    (* regular effort *)
                    RealValue := CompletedSummary.Time;
                    (* add overtime effort, if any *)
                    IF GetAssignmentHandle( PlanLine ) THEN
                        WITH CostSummary DO
                            RealVal := Zero;
                            INCL(AssignmentCostTypes, IncludeSpent);
                            ForEachAssignment
                                (EMSHandle, DoOTEfforts, ADR(CostSummary));
                            RealValue := RealValue + RealVal;
                        END;
                    END;
                ELSE
                    RealValue := Zero;
                END;
                TimeUnitValue := EffortScale;

            | ToGoEffortWithOvertime           : (* 2-May-91 TGS *)
                IF (PlanLine) THEN
                    (* regular effort *)
                    RealValue := ToGoSummary.Time;
                    (* add overtime effort, if any *)
                    IF GetAssignmentHandle( PlanLine ) THEN
                        WITH CostSummary DO
                            RealVal := Zero;
                            INCL(AssignmentCostTypes, IncludeToGo);
                            ForEachAssignment
                                (EMSHandle, DoOTEfforts, ADR(CostSummary));
                            RealValue := RealValue + RealVal;
                            TimeUnitValue := EffortScale;
                        END;
                    END;
                ELSE
                    RealValue := Zero;
                END;
                TimeUnitValue := EffortScale;

            | BaselineTotalEffortWithOvertime  : (* 2-May-91 TGS *)
                RealValue     := BaseLineSummary.Time;
                (* add overtime effort, if any *)
                IF GetAssignmentHandle( FALSE ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeToGo);
                        ForEachAssignment
                            (EMSHandle, DoOTEfforts, ADR(CostSummary));
                        RealValue := RealValue + RealVal;
                    END;
                END;
                TimeUnitValue := EffortScale;

            | BaselineTotalDollarsLessExtras   : (* 3-Apr-91 TGS *)
                IF GetAssignmentHandle( FALSE ) THEN
                    WITH CostSummary DO
                        RealVal := Zero;
                        INCL(AssignmentCostTypes, IncludeSpent);
                        INCL(AssignmentCostTypes, IncludeToGo);
                        ExtrasOnly := FALSE;
                        ForEachAssignment
                            (EMSHandle, DoDollars, ADR(CostSummary));
                        RealValue := RealVal;
                    END;
                ELSE
                    Result := FALSE;
                END;
            *)
            ELSE
                Result := FALSE;

            END;
        END;
    END;

    RETURN Result;                                                (* 10-Jul-89 LAA *)

    END DoColumnsPart3;

BEGIN                       (* ColumnValue *)


    PlanLine               := (LineType = Plan);
    ReturnValue.DataType   := ORD(FormatSpecs^[ColumnId].TypeOfValue);
    ReturnValue.DataFields := FormatSpecs^[ColumnId].DataFields;

    Result := (LineType IN OutputField[ (RequiresBaseColumn  IN FormatSpecs^[ColumnId].Attributes),
                                        (BaseLineExists      IN Task^.TaskFlags),
                                        (BaseDifferentColumn IN FormatSpecs^[ColumnId].Attributes)
                                      ]);
    IF (Result) THEN
        Result := (DoColumnsPart1() OR DoColumnsPart2() OR DoColumnsPart3());         (* 10-Jul-89 LAA *)
    END;

    Result := ResultCheck( Result, ReturnValue );

    RETURN Result;

END ColumnValue;


(*$R=*) (*$T=*)




(*----------------------------------------------------------------------------
    ColumnPercentage --

    Return the value of the column specified, as a cardinal number in
    the range 0-100.

    Preconditions:
        The task node must not be NIL, and  The Task must be the result of
        having the task node locked.  It's passed as a VAR parameter so the
        node can be unlocked and relocked if necessary.

    Postconditons:
        The value of the indicated column will be filled in, and TRUE returned
        if there is a value.  Else FALSE will be returned.
        Values which would be less than 0 or greater than 100 are "clipped"
        to those limits.  Columns which have no numeric analogue (e.g.,
        text columns) will return 0.
----------------------------------------------------------------------------*)

PROCEDURE ColumnPercentage(    TaskNode          : ATreeNode;
                           VAR Task              : ATaskPtr;
                               ColumnId          : CARDINAL;
                               LineType          : AGanttLineType;
                           VAR ReturnValue       : CARDINAL       )
                                                                   : BOOLEAN;
VAR
    OK              : BOOLEAN;
    DataValue       : AColumnDataRecord;

BEGIN                       (* ColumnPercentage *)



        (* Special quick case.   AJL *)
    IF (ColumnId = PercentAchieved) THEN
        ReturnValue := Task^.PercentComplete;
        OK := TRUE;
    ELSE
        OK := ColumnValue (TaskNode, Task, ColumnId, Plan, DataValue);

        IF (OK) THEN
            WITH DataValue DO

                IF (DataType = IsRealValue) THEN
                    IF (RealValue < Zero) THEN
                        ReturnValue := 0;
                    ELSIF (RealValue > One) THEN
                        ReturnValue := 100;
                    ELSE
                        ReturnValue := TRUNC(OneHundred * RealValue);
                    END;
                ELSE
                    ReturnValue := 0;
                END;
            END;
        END;
    END;

    RETURN OK;                                                 (* 16-Sep-91 *)

END ColumnPercentage;






(*----------------------------------------------------------------------------
    FormatValue --

    Format the given value into a displayable string according to the
    format spec and other parameters.

    Preconditions:
        The value must be a result returned from ColumnValue.

    Postconditions:
        The StringValue will return a formatted version of the data passed
        in.
----------------------------------------------------------------------------*)

PROCEDURE FormatValue(    ColumnId          : CARDINAL;
                          Width             : CARDINAL;
                          LineType          : AGanttLineType;
                          MinDecimals       : CARDINAL;
                          MaxDecimals       : CARDINAL;
                          RightJustify      : BOOLEAN;
                      VAR ReturnValue       : AColumnDataRecord);

VAR
    FormatType              : CARDINAL;

BEGIN                       (* FormatValue *)


    WITH ReturnValue DO

        FormatType := ORD(FormatSpecs^[ColumnId].OutputFormat);

            (* First, a bit of preprocessing for a couple of special cases *)

(* Commented out 9/23/90 by PFG.  Was causing problems at printtime.

        IF (ColumnId = NotesColumn) THEN
            IF (Width = 1) AND (LengthOf(StringValue) > Width) THEN
                Fill(StringValue,16C,1);
            END;
        END;
*)

        IF ((LineType <> Plan)
           AND (NOT (BaseDifferentColumn IN FormatSpecs^[ColumnId].Attributes))) THEN
            SetLengthOf (StringValue, 0);
        END;


            (* Now do the generic formatting *)

        FormatDataValue (Width, MinDecimals, MaxDecimals, RightJustify,
                         FormatType, ReturnValue);

    END;

END FormatValue;






 (* GetColumnString - Get a value and format it in the default way.
 *)
PROCEDURE XGetColumnString( TaskNode : ATreeNode;
                        VAR Task     : ATaskPtr;
                            ID       : CARDINAL;
                            LineType : AGanttLineType;
                            Wid      : CARDINAL;
                        VAR Value    : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i           : CARDINAL;
    ValueRecord : AColumnDataRecord;
    ok          : BOOLEAN;
BEGIN



    ok := TRUE;

    IF (Wid = 0) THEN
        ok := FALSE;

    (* 17-Mar-89 RSC Reorganized this a little. *)

    ELSIF (ID = TaskNameColumn) THEN
        IF (LineType = Plan) THEN
            WITH ValueRecord DO
                FormatIndentation(TaskNode, Wid, StringValue);
                ConcatS(   StringValue, " " );
                ConcatLS(  StringValue, Task^.taskname );
                IF (LengthOf(StringValue) < Wid) THEN
                    Procustes(StringValue, Wid);
                ELSE
                    SetLengthOf(StringValue, Wid);  (* Procustes does an LJUST! *)
                END;
            END;
        ELSE
            ok := FALSE;
        END;
    ELSIF (ColumnValue(TaskNode, Task, ID,          (* 21-Mar-91 RSC GET LOCAL VERSION *)
                       LineType, ValueRecord)) THEN
        WITH FormatSpecs^[ID] DO
            FormatValue(ID, Wid, LineType,  (* 21-Mar-91 RSC LOCAL VERSION *)
                        Decimals DIV 16,
                        Decimals MOD 16,
                        RjustColumn IN Attributes,
                        ValueRecord);
        END;
    ELSE
        ok := FALSE;
    END;

    IF (ok) THEN
        Copy( ValueRecord.StringValue, Value );
    ELSE
        Fill(Value, " ", Wid);
    END;

    RETURN ok;

END XGetColumnString;




(*----------------------------------------------------------------------------
    FormatTaskColumns --

    Format the fields of this task's record into a string of the indicated
    length, using the given ChartFormat to determine the length and position
    of each field.  The indicated total length of the resulting LString may
    be less than the sum of the field lengths specified in the ChartFormat.

    Preconditions:
        The task node must not be NIL.  The ChartFormat must have valid and
        consistent fields.

    Postconditions:
        The result LString will contain the fields of the task record, in the
        order, and with the length specified in the ChartFormat, but limited
        to the indicated total length.  Each field will be seperated by a
        single blank, which is included as part of the field length.
----------------------------------------------------------------------------*)

PROCEDURE XFormatTaskColumns(    TaskNode    : ATreeNode;
                                 Task        : ATaskPtr;
                                 LineType    : AGanttLineType;
                             VAR ChartFormat : AChartFormat;
                                 Length      : CARDINAL;
                             VAR String      : ARRAY OF CHAR);
VAR
    i                       : CARDINAL;
    Pos                     : CARDINAL;
    Wid                     : CARDINAL;
    ID                      : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* FormatTaskColumns *)

    IF (Length > HIGH(String)) THEN
        Length := HIGH(String);
    END;
    Fill(String, " ", Length);

    WITH ChartFormat DO
        FOR i := 1 TO ColumnCount DO
            WITH ColumnSpec[i] DO
                Pos := Position;
                Wid := Width;
                ID  := ColumnID;
            END;
            IF (Wid > 0) THEN
                IF (Pos > Length) THEN
                    RETURN;
                END;
                DEC(Wid);
                IF (Pos + Wid - 1 > Length) THEN
                    Wid := Length - Pos + 1;
                END;

                IF (XGetColumnString( TaskNode, Task, ID, LineType, Wid, s )) THEN
                    Overlay(String, s, Pos, ORD(s[0]));
                END;
            END;
        END;
    END;

END XFormatTaskColumns;







PROCEDURE DataFromType( TypeOfValue : CARDINAL
                      ) : ASetOfColumnDataFields;
VAR
    DataFields : ASetOfColumnDataFields;
BEGIN

(* Formatters may use additional fields as temp values.  For example,
   they may set CardinalValue := ORD(IntegerValue)
*)
    CASE TypeOfValue OF
      IsStringValue,
      IsEnumValue     :
         DataFields := ASetOfColumnDataFields{StringInUse};
    | IsRealValue,
      IsCurrency      :
         DataFields := ASetOfColumnDataFields{RealInUse};
    | IsEffort,
      IsDuration,
      IsSlack,
      IsDurationUnits,
      IsEffortUnits   :
         DataFields := ASetOfColumnDataFields{TimeUnitInUse,RealInUse};
    | IsIntValue      :
         DataFields := ASetOfColumnDataFields{IntegerInUse};
    | IsCardValue     :
         DataFields := ASetOfColumnDataFields{CardinalInUse};
    | IsBoolValue     :
         DataFields := ASetOfColumnDataFields{BooleanInUse};
    | IsBigStart,
      IsBigEnd        :
         DataFields := ASetOfColumnDataFields{BigTimeInUse};
    | IsStartDate,
      IsEndDate,
      IsMilestoneEnd  :
         DataFields := ASetOfColumnDataFields{DateInUse};
    ELSE
        DataFields := ASetOfColumnDataFields{}; (* Unknown here. *)
    END;

    RETURN DataFields;

END DataFromType;







    (*  Here's the presumed structure of the phrases lines - better keep
        this in sync if you change it!

        Constants are now assigned to each of these values and can be
        imported from ColumnSupport. ( PFG 8/27/90 )

  1      <FullTitle>           is the form title. (Can't be greater than 24 characters)
  2      <Title1>              is the first title line.  May be blank.
  3      <Title2>              is the second title line.
  4      <DefaultLength>       is the default length for the form.
  5      <NarrowWidth>         is 'below this width, use the narrow titles'
  6      <NarrowTitle1>        is the first narrow title line.
  7      <NarrowTitle2>        is the second narrow title line.
  8      <FormalName>          is the predicate title name (all caps).
  9      <UniqueID>            is T if this column is the unique ID.
 10      <FormatType>          is 0 = Text,     1 = Date,   2 = Numeric,
                                  3 = Currency, 4 = Boolean
 11      <MaxDecimals>         is the maximum number of decimal places for numerics
 12      <DataType>            is  1 = Text,           2 = RealNumber,
                                   3 = Integer,        4 = Cardinal,
                                   5 = Boolean,        6 = EnumeratedType,
                                   7 = BigStartTime,   8 = BigEndType,
                                   9 = StartTime,     10 = EndTime,
                                  11 = Duration,      12 = Slack,
                                  13 = Currency,      14 = Effort,
                                  15 = Milestone end, 16 = DurationUnits,
                                  17 = EffortUnits,   18 = Truncated String
 13      <TotalByRsrc>         is "Can we total this col by resource?"
 14      <MinDecimals>         is the minimum number of decimals places to use
 15      <BslnRequired>        is T if a baseline is required for this column
 16      <BslnDifferent>       is T if the baseline value can be different than the plan value
 17      <RightJustify>        is T if the column data should be right justified
 18      <MinExportWidth>      is the minimum width for use in exporting
 19      <SortOrder>           is the order the column should appear in on a QuickPick list.
 20      <EnumerationsPhrase>  for enumerated types, the phrase number with a list of
                               valid entries. Other types 0.
 21      <HelpKey>             Index into the help text for this column.  Max 8 letters.
                               Default is "SPRDVIEW".

    *)


PROCEDURE CaptionsInit();
CONST
    BaseRequired        = TRUE;
    BaseAvailable       = TRUE;
    BaseDifferent       = TRUE;
    BaseNotRequired     = FALSE;
    BaseNotAvail        = FALSE;
    BaseNotDifferent    = FALSE;
    P                   = ALineTypeSet{Plan};
    B                   = ALineTypeSet{Baseline};
    PB                  = ALineTypeSet{Plan,Baseline};
    NONE                = ALineTypeSet{};

VAR
    i, Size                 : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;
    Copyright               : ARRAY[0..47] OF CHAR;


    (* Word To C - Convert a phrase's word number to a Cardinal.

           Preconditions  - Phrase     is the phrase number to look up
                            Word       is the 'word' to seek in that phrase.
           Postconditions - RETURN     is the cardinal number.
    *)

    PROCEDURE WordToC( VAR Phrase           : ARRAY OF CHAR;
                           Word             : CARDINAL     )
                                                            : CARDINAL;

    VAR
        i  : CARDINAL;
        s1 : ARRAY [0..9] OF CHAR;

    BEGIN
        WordNumber( Phrase, Word, s1 );
        i := 1;
        RETURN StoC( s1, i );
    END WordToC;



    (* Word To B - Convert a phrase's word number to a Boolean.

           Preconditions  - Phrase     is the phrase number to look up
                            Word       is the 'word' to seek in that phrase.
           Postconditions - RETURN     is the boolean.
    *)

    PROCEDURE WordToB( VAR Phrase           : ARRAY OF CHAR;
                           Word             : CARDINAL     )
                                                            : BOOLEAN;

    VAR
        s1 : ARRAY [0..9] OF CHAR;
    BEGIN
        WordNumber( Phrase, Word, s1 );
        RETURN (s1[1] = TrueChar);
    END WordToB;


BEGIN                       (* CaptionsInit *)
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    NEW(FormatSpecs);

    GetMessage(ModuleNumber + 6, s);    (* "TF" *)
    TrueChar    := s[1];
    FalseChar   := s[2];

    GetMessageWord(ModuleNumber+1, 1, DurationString);   (* "Duration" *)
    GetMessageWord(ModuleNumber+1, 2, EffortString);     (* "Effort" *)
    GetMessageWord(ModuleNumber+1, 3, AssignmentString); (* "Assignment" *)
    GetMessage(ModuleNumber + 3, SummaryString);         (* "SUMMARY"         *)
    GetMessage(ModuleNumber + 4, StatusString);          (* "CpsRrL?"         *)
    GetMessage(ModuleNumber + 5, PSString);              (*  "PS"             *)
    GetMessageWord(ModuleNumber+13, 1, DelayString);     (* "Delay"     *)
    GetMessageWord(ModuleNumber+13, 2, SplitString);     (* "Split"     *)

    StatusPosition[NeedsRecalculate] := 1;
    StatusPosition[Critical]         := 2;
    StatusPosition[ResourceOverload] := 3;
    StatusPosition[ResourceConflict] := 4;
    StatusPosition[PartialJoinPrior] := 5;
    StatusPosition[PartialJoinAfter] := 6;
    StatusPosition[Loop]             := 7;

    (* How do we decide if we need to put out a field?

        The three factors are:

            Is a baseline required for the column?
            Is a baseline available for the column?
            Is the baseline value different?

        We implement this as a tripple dimensioned array.
        The contents are the set of whether we do a PLAN line or a BASE line.
    *)
    OutputField[ BaseRequired,     BaseAvailable, BaseDifferent   ] := PB;
    OutputField[ BaseRequired,     BaseAvailable, BaseNotDifferent] := P;
    OutputField[ BaseRequired,     BaseNotAvail,  BaseDifferent   ] := NONE;
    OutputField[ BaseRequired,     BaseNotAvail,  BaseNotDifferent] := NONE;
    OutputField[ BaseNotRequired,  BaseAvailable, BaseDifferent   ] := PB;
    OutputField[ BaseNotRequired,  BaseAvailable, BaseNotDifferent] := P;
    OutputField[ BaseNotRequired,  BaseNotAvail,  BaseDifferent   ] := P;
    OutputField[ BaseNotRequired,  BaseNotAvail,  BaseNotDifferent] := P;


    FOR i := 1 TO HighestKnownColumn DO
        GetColInfoFromPhrasesOrText(ModuleNumber2,
                                    TaskColumnInfo,
                                    i, s);  (* 29-Aug-90 PFG *)
        WITH FormatSpecs^[i] DO
            Attributes  := AFormatSpecAttributeSet{};
            TypeOfValue := 0C;
            Decimals    := 0;
            DataFields  := ASetOfColumnDataFields{StringInUse};

            IF (LengthOf(s) > 0) THEN
                INCL(Attributes, KnownColumn);
                IF (WordToB(s, 16)) THEN
                    INCL(Attributes, BaseDifferentColumn);
                END;
                IF (WordToB(s, 15)) THEN
                    INCL(Attributes, RequiresBaseColumn);
                END;
                IF (WordToB(s, 17)) THEN
                    INCL(Attributes, RjustColumn);
                END;
                IF (WordToB(s, 13)) THEN
                    INCL(Attributes, TotalByRsrc ); (* 21-Mar-91 RSC  *)
                END;
                OutputFormat := CHR(WordToC(s, 10));
                TypeOfValue :=  CHR(WordToC(s, 12));
                Decimals    := WordToC(s, 14) * 16 + WordToC(s, 11);
                SortOrder   := WordToC(s, 19);
                DataFields  := DataFromType( ORD(TypeOfValue) );
            END;
        END;
    END;

END CaptionsInit;





PROCEDURE DoACaption();
VAR
    Interface : POINTER TO ACaptionsOverlayInterface;
BEGIN
    Interface := OverlayContext();
    IF (Interface = NIL) THEN
        FatalError();
    END;

    WITH Interface^ DO

        ReturnValue := TRUE;

        CASE Function OF
          FDataFieldsFromType :
            Fields := DataFromType( DataType );

        | FGetColumnString    :
            ReturnValue := XGetColumnString( TaskNode, TaskPtr, Column,
                                             GanttLineType, Width,
                                             StringValue );

        | FFormatTaskColumns  :
            XFormatTaskColumns( TaskNode, TaskPtr, GanttLineType,
                                ChartFormatPtr^, Width, StringValue );

        | FFormatValue        :
                (* 20-Mar-91 TGS Min and Max were switched... *)
            FormatValue( Column, Width, GanttLineType, MinDecimals,
                         MaxDecimals, RightJustify, ValuePtr^ );

        | FColumnPercentage   :
            ReturnValue := ColumnPercentage( TaskNode, TaskPtr, Column,
                                             GanttLineType, PercentValue );

        | FColumnValue        :
            ReturnValue := ColumnValue( TaskNode, TaskPtr, Column,
                                        GanttLineType, ValuePtr^ );

        | FColumnInfo         :
            ColumnInfo( TaskNode, TaskPtr, Column, Info, Width,
                        ValuePtr^ );

        | FResourceNameList   :
            XResourceNameList( TaskNode, GanttLineType, Width,
                               StringValue );

        ELSE
            FatalError();
        END;
    END;

END DoACaption;





(*<OS2
PROCEDURE TLCaptionBind();
OS2>*)


BEGIN

    (* RSC 2-Mar-89 *)  (* 31-Mar-89 EGK/LAA *)
(*    InstallNewProcedure( ADR( GetColumnInfo          ), PROC( ColumnInfo         ), NIL );*)
(*    InstallNewProcedure( ADR( GetColumnValue         ), PROC( ColumnValue        ), NIL );*)
(*    InstallNewProcedure( ADR( GetColumnPercentage    ), PROC( ColumnPercentage   ), NIL );*)
(*    InstallNewProcedure( ADR( FormatColumnValue      ), PROC( FormatValue        ), NIL );*)
(*    InstallNewProcedure( ADR( FormatTaskColumns      ), PROC( XFormatTaskColumns ), NIL );*)
(*    InstallNewProcedure( ADR( GetColumnString        ), PROC( XGetColumnString   ), NIL );*)
(*    InstallNewProcedure( ADR( ResourceNameList       ), PROC( XResourceNameList  ), NIL );*)
(*    InstallNewProcedure( ADR( DataFieldsFromDataType ), PROC( DataFromType       ), NIL );*)

    OverlayID := ImAnInstallableOverlay( DoACaption, AnOverlayProc(NIL) );

    IF (FormatSpecs = NIL) THEN
        CaptionsInit();
    END;

    DoACaption();

(*<OS2
END TLCaptionBind;
OS2>*)

END TLCaption.
(*
    RSC  12/16/88   Moved here from the Captions module.
    RSC  12/22/88   Got to the point of compiling.
    RSC   1/23/89   Minor ajustements to make formatting come out like
                    it always used to.  For example, format milestone end dates
                    as if they were start dates.
    RSC 16-Feb-89   Ajusted EAC Varience Percent.
    RSC 22-Feb-89   Mirrored Ed's fixes, and condensed some code in
                    ColumnInfo by use of local subroutines.
    RSC  2-Mar-89   Support for "InstallNewProcedure" in Overlays.
    RSC  2-Mar-89   When duration field is zero, leading spaces were missing.
    RSC  3-Mar-89   New columns added.  Also moved more routines here from
                    captions.  Had to split up the GetColumnValue procedure,
                    because it was huge.  Added support for
                    "ColumnSortSequence" to allow columns to be sorted
                    before being put into a QuickPick list.
    RSC 13-Mar-89   7 more columns added (Army columns + TaskLocked).
    RSC 17-Mar-89   Bug fixes for new columns.
    RSC 21-Mar-89   Added support for FSMUPH rather than FLOAT(SMUPH).
                    Also added support for the report info type
                    "ColumnTotalByRsrc".  Fixed some bugs.
    RSC 27-Mar-89   Still fixing bugs.  Also, added support for
                    "DataFieldsFromDataType" from Captions, added for the
                    "Better Reports" project.
    EGK 28-Mar-89   Added ColumnPercentage procedure.
    EGK 31-Mar-89   LAA added a fix sent up by Ed to make ColumnPercentage
                    stuff work.
    RSC 19-Apr-89   Reversed "CurrentCostEfficiency" calculation.
    EGK 05-May-89   Changed to use new WBS storage scheme.
    RSC 12-May-89   1) Removed "TaskIsLocked" column.
                    2) Added "Time Elapsed Percent" in its place.
                    3) Added 10 new coding fields.
                    4) Change ProjectedCost to
                       Total$ / CurrentCostEfficiency.
                    5) Baseline fields that shouldn't have come out did,
                       like TaskName.
                    6) Leading chars are never eliminated in an
                       abbreviated name, like abbreviated task name
                       (unless it is a space).
                    7) remove adjacent duplicate chars.  Was removing
                       any duplicates, not just adjacents.  Also was
                       skipping triplets; "ttt" would become "tt",
                       with the second "t" removed.
                    8) Change the calc for "BurnRateDollars", otherwise
                       known as "SendingRateRatio", to be BCWS/ACWP.
    17-May-89 LAA   Fixed a problem in ColumnValue which was resulting in
                    random garbage on the screen for all but the task
                    name column.
    17-May-89 MWP   Removed truncation and various barbaric acts from being
                    performed on the formal column names.
    20-May-89 RSC   Accomidated new WorkHours module.
    25-May-89 RSC   1) "Improve" abbreviation routine for task name.
                    2) Column value was spuriously returning FALSE.
    30-May-89 RSC   Add 10 MORE coding fields.
    06-Jun-89 KKC   Change array size of S in AResourceListContext from
                    254 to 255
    20-Jun-89 AJL   1) Changed the definitions of the PropPctComplete columns
                       to reflect the Baseline Total $ instead of EAC.
                    2) Modified the percentage formatting so that
                       columns that used to return real values multiplied by
                       one hundred are formatted as strings at 100 times real
                       value, but the real value in the data record is not
                       so scaled.
                    3) Defined PercentAchieved to be a real-valued column.
                    4) Put a special case test into ColumnPercentage to
                       run more quickly when the ColumnId = PercentAchieved.
    30-Jun-89 AJL   1) Added a procedure "RealRatio" so that we can define
                       ratios of real numbers, taking into account that both
                       might be zero.  (0/0 = 1, else x/0 = infinity.) and
                       that one or the other of the numbers might be infinity.
                    2) Made the definition of ProportionalPercentComplete
                       = (BCWP/BCWS) * ProportionalPctComplete
                       even if BCWS = 0.
     6-Jul-89 AJL   1) Fix BaselinePropPctComplete so that it uses RealRatio.
    06-Jul-89 WKH   DO NOT RJust the column name in GetColumnInfo !!!
    07-Jul-89 WKH   Elapsed time was incorrectly being calculated as a
                    CARDINAL value.  Made them into durations.  This has
                    a corrsponding phrases change.
     7-Jul-89 EGK   Changed calculation of SpentEffortPercent -- the
                    two parameters to RealRatio were reversed.
    10-Jul-89 LAA   GetColumnValue was not returning FALSE when the column
                    it was asked for didn't have a valid value.
    12-Jul-89 AJL   1-Character wide notes columns use the note symbol.
     1-Aug-89 RSC   Remove SequenceNumber column.
     6-Aug-89 WKH   Initial OS/2 edits.
     8-Aug-89 WKH   Comment LockedOverlay call for OS/2
    21-Aug-89 WKH/
              AJL   Implement new GetCostEfficiency Proc.
    22-Aug-89 KKC   Add copyright message.
    27-Aug-89 MWP   Include support for new column WBS Errors.
     1-Sep-89 EGK   Changed FormatValue to use new common code from
                    FormatCommon.
    20-Sep-89 AJL   Changed the ProjectedCost column so that the formula
                    is:
                        if elapsed duration = 0 then
                            use Estimate at Completion,
                        else
                            use Budget at Completion * ( Spent $ / BCWP )
                        end.
    21-Sep-89 AJL   1-Character wide notes columns use the double-note symbol.
                    The single-note = Carriage Return which messes up
                    printouts.
    29-Nov-89 RSC   Added EffortVariance column.
*)




