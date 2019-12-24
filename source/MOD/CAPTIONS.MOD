IMPLEMENTATION MODULE Captions;

    (* MODIFICATION HISTORY:


    HOW TO ADD A NEW COLUMN TO CAPTIONS:

        1) Add the title string to the phrases file after the other column
           name phrases, around 192nn.

        2) Add the constant for the phrase to the procedure who will format
           him.  That could be here, TLCaption, or another installable overlay.

        3) Add the code for formatting to the same module.


        (* COMMENTS PRIOR TO SPIKE RELEASE REMOVED BY RSC 12/16/88  *)

        17-Oct-88 WKH       Added procedure FormatReallyLongDuration to handle
                            situations where input value would be greater than
                            MAXINT.
        28-Nov-88 AJL       Modified FormatLongDuration so that we will have a
                            space separating the amount from the units regardless
                            of whether the DefaultAmountFormat specifies a trailing
                            space.  Earlier (wrong) versions of DefaultAmountFormat
                            had followed all positive numbers by a space, and we
                            were dependant on this.
        16-Dec-88 RSC       Moved FormatIndentation into a new module, Indentation.
                            Built most of this module into an overlay, TLCaption,
                            and moved other formatters into TimeFormat and FormatAs.
        23-Jan-89 RSC       set default string values.
        27-Jan-89 RSC       set more default string values.
         7-Feb-89 RSC       Added "GetColumnString".
         3-Mar-89 RSC       Added New columns support:
                            > Removed magic number references.
                            > Moved code that prints out resource lists into
                              tlcaptions.
                            > Moved code that formats an assignment summary into
                              tlcaptions.
                            > Cleaned up the import statements, removing unneeded
                              imports.
        22-Mar-89 EGK       Added ColumnPercentage procedure.
        20-May-89 RSC       Removed references to ManHours and TimeFormat modules.
        21-Feb-90 KKC       Remove all unreferenced id from Timeu.
        30-Mar-90 RSC       Made Timeu to Timei/TimeForm conversions.
         5-Oct-90 RSC       Added support for TLCAPTIONS to be a RESIDENT
                            overlay rather than LOCKED.
        13-Oct-90 AJL       Moved TLCaptions variables to CapData module.
        24-Jan-91 RSC       Added TaskPtr to the parameters for
                            FormatTaskColumns.
        19-Feb-91 RSC       Rearranged the way we call TLCaptions to be
                            more of a standard overlay calling system.
                            This will be a little slower, but will allow
                            TLCaptions to fit into the reserved layers.
        14-Mar-91 RSC       Ahem.  Yes. A "Little Slower".  When we build
                            the list of column alias', bajillions of calls
                            are made to ColumnInfo.  Moved some ColumnInfo
                            logic back into this module.
        21-Mar-91 RSC       Again, for speed, tighten up the calls to
                            TLCaptions so they do not have to do quite as
                            much work.  In particular, remove CallTLCaptions.

                            Also, I added the ColumnTotalByRsrc check in
                            ColumnInfo.
         5-Apr-91 TGS       Moved Task Column Numbers to TaskColN.def, from 
                            MagicNum.def.
    *)


FROM Allocs         IMPORT
    (* TYPE *)          ATaskPtr, AnAssignmentSummary;

FROM CapData        IMPORT
    (* TYPE *)          ALineTypeSet, AFormatSpecAttribute,
                        AFormatSpecAttributeSet, AFormatSpec,
    (* VAR *)           FormatSpecs;

FROM ChartForms     IMPORT
    (* TYPE *)          AChartFormat;

FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM Gantt          IMPORT
    (* TYPE *)          AGanttLineType;

FROM LStrings       IMPORT
    (* PROCS *)         SetString, Procustes, SetLengthOf, Copy;

FROM MagicNum       IMPORT
    (* CONST *)         IsCardValue, IsBoolValue;

FROM Overlays       IMPORT
    (* PROC *)          CallOverlayWithContext;

FROM Space      IMPORT
    (* PROC *)      ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
     (* TYPES *)        ADR, ADDRESS,
     (* PROC *)         SIZE;

FROM TaskColNumbers IMPORT 
    (* CONST *)         HighestRootColumn;

FROM Timei          IMPORT
    (* TYPE *)          ADurationUnit;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATreeNode;




VAR
    CurrencyScale       : REAL;
    TLCaptionsName      : ARRAY [0..9] OF CHAR;






    (* ResourceNameList -- Produce a list of all the resources used
                           by the task. *)

PROCEDURE XResourceNameList(    Node     : ATreeNode;
                                LineType : AGanttLineType;
                                Length   : CARDINAL;
                            VAR S        : ARRAY OF CHAR );
VAR
    Interface   : ACaptionsOverlayInterface;
BEGIN
    WITH Interface DO
        Function        := FResourceNameList;
        TaskNode        := Node;
        GanttLineType   := LineType;
        Width           := Length;
    END;

    IF (CallOverlayWithContext( TLCaptionsName, ADR(Interface) )) THEN
        Copy(Interface.StringValue,S);
    ELSE
        SetLengthOf(S, 0);
    END;

END XResourceNameList;





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

PROCEDURE XAssignmentSummaryToString( 
                      VAR Summary               : AnAssignmentSummary;
                          SuggestedTimeUnit     : ADurationUnit;
                          TimeMinDecimalPlaces,
                          TimeMaxDecimalPlaces,
                          AmountDecimalPlaces   : CARDINAL;
                          MaxLength             : CARDINAL;
                      VAR s                     : ARRAY OF CHAR  );
BEGIN
    SetLengthOf( s, 0 );
END XAssignmentSummaryToString;








PROCEDURE GetColumnData(    TheTaskNode        : ATreeNode;
                        VAR TheTask            : ATaskPtr;
                            TheColumnID        : CARDINAL;
                            TheInfoChoice      : AColumnInfoChoice;
                            TheWidth           : CARDINAL;
                        VAR TheReturnValue     : AColumnDataRecord);
CONST
    BoolFields  = ASetOfColumnDataFields{BooleanInUse};
VAR
    Interface   : ACaptionsOverlayInterface;
    Handled     : BOOLEAN;
BEGIN
    Handled := FALSE;

    IF (FormatSpecs <> NIL) AND
       (TheColumnID <= HighestRootColumn) THEN
        WITH TheReturnValue DO

            DataType      := IsCardValue;        (* Set defaults *)
            DataFields    := ASetOfColumnDataFields{CardinalInUse};
            Handled       := TRUE;  (* Assume we will handle it. *)

            CASE TheInfoChoice OF

                ColumnNext :

                    REPEAT
                        INC(TheColumnID);
                    UNTIL (TheColumnID > HighestRootColumn)
                    OR (KnownColumn IN FormatSpecs^[TheColumnID].Attributes);

                    IF (TheColumnID <= HighestRootColumn) THEN
                        CardinalValue := TheColumnID;
                    ELSE
                        Handled := FALSE; (* Could be more columns *)
                    END;

            |   ColumnMinDecimals :

                    CardinalValue := FormatSpecs^[TheColumnID].Decimals DIV 16;

            |   ColumnMaxDecimals :

                    CardinalValue := FormatSpecs^[TheColumnID].Decimals MOD 16;

            |   ColumnDataType :

                    CardinalValue := ORD(FormatSpecs^[TheColumnID].TypeOfValue);

            |   ColumnFormatType :

                    CardinalValue := ORD(FormatSpecs^[TheColumnID].OutputFormat);

            |   ColumnRightJustified :

                    DataType     := IsBoolValue;
                    DataFields   := BoolFields;
                    BooleanValue := RjustColumn IN FormatSpecs^[TheColumnID].Attributes;

            |   ColumnBslnRequired :

                    DataType     := IsBoolValue;
                    DataFields   := BoolFields;
                    BooleanValue := RequiresBaseColumn IN FormatSpecs^[TheColumnID].Attributes;

            |   ColumnBslnDifferent :

                    DataType     := IsBoolValue;
                    DataFields   := BoolFields;
                    BooleanValue := BaseDifferentColumn IN FormatSpecs^[TheColumnID].Attributes;

            |   ColumnSortSequence :

                    CardinalValue := FormatSpecs^[TheColumnID].SortOrder;

            |   ColumnTotalByRsrc   :

                    DataType     := IsBoolValue;
                    DataFields   := BoolFields;
                    BooleanValue := TotalByRsrc IN FormatSpecs^[TheColumnID].Attributes;
                    
            ELSE
                Handled := FALSE;
            END;
        END;
    END;

    IF (NOT Handled) THEN
        WITH Interface DO
            Function        := FColumnInfo;
            TaskNode        := TheTaskNode;
            TaskPtr         := TheTask;
            Column          := TheColumnID;
            Info            := TheInfoChoice;
            Width           := TheWidth;
            ValuePtr        := ADR(TheReturnValue);
        END;

        IF (NOT CallOverlayWithContext( TLCaptionsName, ADR(Interface) )) THEN
            WITH TheReturnValue DO
                CardinalValue := 0;
                DataType      := 0;  (* 0 = "No Value" *)
                DataFields    := ASetOfColumnDataFields{CardinalInUse};
                SetLengthOf( StringValue, 0 );
            END;
        END;
    END;

END GetColumnData;




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

PROCEDURE ColumnValue(    TheTaskNode          : ATreeNode;
                      VAR TheTask              : ATaskPtr;
                          TheColumnId          : CARDINAL;
                          TheLineType          : AGanttLineType;
                      VAR TheReturnValue       : AColumnDataRecord)
                                                                : BOOLEAN;
VAR
    Interface   : ACaptionsOverlayInterface;
    Ok          : BOOLEAN;
BEGIN                       (* ColumnValue *)
    WITH Interface DO
        Function        := FColumnValue;
        TaskNode        := TheTaskNode;
        TaskPtr         := TheTask;
        Column          := TheColumnId;
        GanttLineType   := TheLineType;
        ValuePtr        := ADR(TheReturnValue);
    END;

    Ok := CallOverlayWithContext( TLCaptionsName, ADR(Interface) );
    IF (Ok) THEN
        Ok := Interface.ReturnValue;
    ELSE
        SetLengthOf( TheReturnValue.StringValue, 0 );
    END;

    RETURN Ok;

END ColumnValue;






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

PROCEDURE ColumnPercentage(    TheTaskNode          : ATreeNode;
                           VAR TheTask              : ATaskPtr;
                               TheColumnId          : CARDINAL;
                               TheLineType          : AGanttLineType;
                           VAR TheReturnValue       : CARDINAL       )
                                                                   : BOOLEAN;
VAR
    Interface   : ACaptionsOverlayInterface;
    Ok          : BOOLEAN;
BEGIN
    WITH Interface DO
        Function        := FColumnPercentage;
        TaskNode        := TheTaskNode;
        TaskPtr         := TheTask;
        Column          := TheColumnId;
        GanttLineType   := TheLineType;
    END;

    Ok := CallOverlayWithContext( TLCaptionsName, ADR(Interface) );

    IF (Ok) THEN
        TheReturnValue := Interface.PercentValue;
        Ok             := Interface.ReturnValue;
    ELSE
        TheReturnValue := 0;
    END;

    RETURN Ok;

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

PROCEDURE XFormatValue(    TheColumnId          : CARDINAL;
                           TheWidth             : CARDINAL;
                           TheLineType          : AGanttLineType;
                           TheMinDecimals       : CARDINAL;
                           TheMaxDecimals       : CARDINAL;
                           TheRightJustify      : BOOLEAN;
                       VAR TheReturnValue       : AColumnDataRecord);
VAR
    Interface   : ACaptionsOverlayInterface;
BEGIN
    WITH Interface DO
        Function        := FFormatValue;
        Column          := TheColumnId;
        Width           := TheWidth;
        GanttLineType   := TheLineType;
        MinDecimals     := TheMinDecimals;
        MaxDecimals     := TheMaxDecimals;
        RightJustify    := TheRightJustify;
        ValuePtr        := ADR(TheReturnValue);
    END;

    IF (NOT CallOverlayWithContext( TLCaptionsName, ADR(Interface) )) THEN
        SetLengthOf( TheReturnValue.StringValue, 0 );
    END;

END XFormatValue;








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

PROCEDURE XFormatTaskColumns(    TheTaskNode    : ATreeNode;
                                 TheTaskPtr     : ATaskPtr;
                                 LineType       : AGanttLineType;
                             VAR ChartFormat    : AChartFormat;
                                 Length         : CARDINAL;
                             VAR String         : ARRAY OF CHAR);
VAR
    Interface   : ACaptionsOverlayInterface;
BEGIN
    WITH Interface DO
        Function        := FFormatTaskColumns;
        TaskNode        := TheTaskNode;
        TaskPtr         := TheTaskPtr;
        GanttLineType   := LineType;
        Width           := Length;
        ChartFormatPtr  := ADR(ChartFormat);
    END;

    IF CallOverlayWithContext( TLCaptionsName, ADR(Interface) ) THEN
        Copy( Interface.StringValue, String );
    ELSE
        SetLengthOf( String, 0 );
    END;

END XFormatTaskColumns;





 (* GetColumnString - Get a value and format it in the default way.
 *)
PROCEDURE XGetColumnString( TreeNode    : ATreeNode;
                        VAR TheTaskPtr  : ATaskPtr;
                            ColumnID    : CARDINAL;
                            LineType    : AGanttLineType;
                            TheWidth    : CARDINAL;
                        VAR Value       : ARRAY OF CHAR ) : BOOLEAN;
VAR
    Interface   : ACaptionsOverlayInterface;
    Ok          : BOOLEAN;
BEGIN
    WITH Interface DO
        Function        := FGetColumnString;
        TaskNode        := TreeNode;
        TaskPtr         := TheTaskPtr;
        Column          := ColumnID;
        GanttLineType   := LineType;
        Width           := TheWidth;
    END;

    Ok := CallOverlayWithContext( TLCaptionsName, ADR(Interface) );
    IF (Ok) THEN
        Copy( Interface.StringValue, Value );
        TheTaskPtr := Interface.TaskPtr;
        Ok         := Interface.ReturnValue;
    ELSE
        SetLengthOf( Value, 0 );
    END;

    RETURN Ok;

END XGetColumnString;




PROCEDURE XGetDataFieldsFromDataType  ( TheDataType :  CARDINAL
                                      ) : ASetOfColumnDataFields;
VAR
    Fields      : ASetOfColumnDataFields;
    Interface   : ACaptionsOverlayInterface;
BEGIN
    WITH Interface DO
        Function := FDataFieldsFromType;
        DataType := TheDataType;
    END;

    IF (CallOverlayWithContext( TLCaptionsName, ADR(Interface) )) THEN
        Fields := Interface.Fields;
    ELSE
        Fields := ASetOfColumnDataFields{};
    END;

    RETURN Fields;

END XGetDataFieldsFromDataType;




  (* Set Currency Scale : Set a new currency scale.  Get the old one with
                          GetCurrencyScale(), and then put it back when you
                          are done with it.
  *)
PROCEDURE SetCurrencyScale( NewScale : REAL );
BEGIN
    CurrencyScale := NewScale;
END SetCurrencyScale;



  (* Get Currency Scale : Get the current currency scale.
  *)
PROCEDURE GetCurrencyScale() : REAL;
BEGIN
    RETURN CurrencyScale;
END GetCurrencyScale;






BEGIN
    SetCurrencyScale( 1.0 );
    GetColumnInfo             := GetColumnData;
    GetColumnValue            := ColumnValue;
    GetColumnPercentage       := ColumnPercentage;
    FormatColumnValue         := XFormatValue;
    ResourceNameList          := XResourceNameList;
    AssignmentSummaryToString := XAssignmentSummaryToString;
    FormatTaskColumns         := XFormatTaskColumns;
    GetColumnString           := XGetColumnString;
    DataFieldsFromDataType    := XGetDataFieldsFromDataType;

    SetString(TLCaptionsName, "TLCAPTIO" );

END Captions.








Cost tracking columns in Time Line Version 3

Andrew Layman
December 16, 1987


This document describes the columns in TL v3 that are available 
for tracking the expenditure of time, money and effort, and the 
progress achieved towards the project goals.  These columns 
follow the techniques of Earned Value Analysis, and many of the 
terms are borrowed from it, although many of them have also 
been renamed for more lay usability.

Key to Earned Value Analysis (EVA) is separate recording of 
progress and expenses, and a comparison of these to each other 
and to a baseline plan.  EVA further assumes that the projected 
expenditure on a task, at the time that the baseline plan is 
established, is an accurate measure of the task's worth, both 
in absolute cash terms and also as a component of the overall 
project worth.  (Fortunately, in a predominantly free, 
competitive economy, this tends to be close to true.)

The values in these columns, then, will have separate 
components for the baseline of a task and its current 
projections (or history).  To simplify presentation, some of 
the baseline components are also available as specific columns 
in their own right.  Nonetheless, these values are copies of 
the corresponding ones from the baseline component of a task.

EVA is isolated from any considerations of how the schedule is 
calculated.  Whether CPM or resource leveling or any other 
process is employed is irrelevant.  It records and measures 
progress against a planned rate of accomplishment, in dollars, 
and a planned rate of spending, again in dollars.

Progress is reported against detail tasks only in Time Line.  
This is by entering the percentage achieved on a task form.  
When a baseline has been established for a schedule, the 
progress of a summary task may be computed by taking the sum of 
the values achieved (percent achieved times baseline cost) of 
each of its child tasks and dividing by the sum of their 
potential values (baseline cost).  Until a baseline has been 
established, it is not possible to measure each child task's 
contribution to the summary task, so it is impossible to infer 
the percentage of the summary that has been achieved.

The accomplishment of some or all of a task does not cause Time 
Line to make any assumptions about what was spent to achieve 
it.

Costs are recorded by entry onto the resource or cost 
assignment forms, accessible through the resource and cost name 
fields on each task form.  The expenditure of effort or money 
on a task does not cause Time Line to assume that anything has 
actually been achieved.

The principal values computed for EVA are BCWS, BCWP and ACWP.  
We have renamed these to "Elapsed Baseline Dollars," "Achieved 
Dollars," and "Spent Dollars."  These are measurements, in the 
common yardstick of cash, of what was supposed to have been 
achieved by now, what has actually been accomplished, and what 
has been spent.   (Time Line presents these as cumulative 
values--it does not have the capacity today to break them into 
periods.)

BCWS (Budgeted Cost of Work Scheduled, glad you asked?) is 
computed by a combination of the As-Of-Date and the baseline 
schedule.  It is, for each task, and up into a summary, the 
value of the work, in dollars, that should be complete to date.  
For detail tasks it is computed by multiplying the baseline 
dollars times the elapsed fraction of time spent on that task.  
Child tasks are summed to give the value of their parent.  Note 
that this value shows what should have been spent, and also, 
based on the premise that the planned cost equals the worth of 
the task, it shows what should have been accomplished.

BCWP (Budgeted Cost of Work Performed) is the measure of what 
we actually did accomplish.  This is computed by multiplying 
the percentage achieved of each detail task times its baseline 
dollar value.  It is summed to parent tasks.

ACWP (Actual Cost of Work Performed) is the measure of what we 
actually spent to accomplish however much or little we got 
done.  It is directly entered for detail tasks, and summed to 
their parent.

So, combining the AsOfDate with baseline costs gives BCWS.  
Combining Percent Achieved with baseline costs gives BCWP, and 
ACWP is entered directly.

Comparing BCWS (what we planned to achieve) against BCWP (what 
we've actually achieved), tells whether a project is ahead or 
behind schedule (in terms of the products it has produced).

Comparing BCWS (what we planned to spend, this time) against 
ACWP (what we have spent) tells us if we are spending our money 
faster or slower than planned.

Finally, comparing BCWP (value achieved) against ACWP (value 
spent) measures how efficiently the money has been spent.


The following columns are available as aids in tracking:

  Baseline Duration         This is the original duration of 
the task as stored in the baseline.  
Since it is computed as the 
  difference between BL start date 
and BL end date, it can be thrown 
off by changes to the workdays or 
hours in the calendar.

  Total Baseln $ (BAC)      Total planned expenditures.  This 
is the baseline cost for the task.  
For summary tasks, it is the sum of 
the costs of the child tasks.

  Baseline Effort           Total planned effort (eg. 
man-hours).  This applies 
(of-course) only to Resources?

  Baseline Start Date       The base start date of the task.

  Baseline End Date         The base end date.

  Elapsed Baseln $ (BCWS)   This is the amount of money that 
had been planned to have been spent 
by the AsOfDate, and also the value 
that had been planned to have been 
achieved.  See the discussion 
above.
This is computed based on the 
AsOfDate, the baseline start and 
end date of detail tasks, and the 
baseline task costs.

                            -
  Start Date                 |
  End Date                   |
  Duration                   |
  Duration in Days           |
  Duration in Weeks          |__ obvious
  Duration in Months         |
  Effort                     |
  Effort in Days             |
  Effort in Weeks            |
  Effort in Months           |
                            -

  Percent Achieved          This number is entered by the user 
for detail tasks, computed for 
linked tasks, and summaries.  When 
a baseline has been established for 
a schedule, the progress of a 
summary task may be computed by 
taking the sum of the values 
achieved (percent achieved times 
baseline cost) of each of its child 
tasks and dividing by the sum of 
their potential values (baseline 
cost).   See discussion above.
PercentAchieved * BAC = BCWP.

  Fixed Start Date          shows date iff fixed date task.
                            Does not show a baseline value.

  Dur as % of Baseline      actual duration as % of baseline 
duration
(actual duration/baseline duration) 
* 100

  Total Dollars (EAC)       (Estimate At Completion)  For the 
baseline, this is merely the total 
task cost (BAC).  For the current 
plan, it is the sum of the money 
spent (Spent Dollars) plus the 
money yet to be spent as listed on 
each task form (To Go Dollars).  
Note that this estimate reflects 
the current plan, which may be 
considerably different from the 
baseline.

  Mathematical EAC          For the baseline, this is, again, 
the total task cost (BAC).  For the 
current plan, it combines the money 
actually spent on tasks, with the 
original, baseline estimate of the 
cost of the unfinished work.  In 
other words, it assumes that the 
baseline is more accurate than the 
current plan.  The formula used is
ACWP+((1-PercentAchieved)*BAC), or, 
equivalently, ACWP+BAC-BCWP.   
Rephrased, this is
SpentDollars + TotalBaselineDollars 
- AchievedDollars.


  Spent Dollars (ACWP)      (Actual Costs for Work Performed so 
far)

                            is this entered by the user on each 
assignment form.  This is the money 
that has been spent, and is not a 
measure of what has been 
accomplished.

  Spent $ as % of Baseline  Spent $ / Elapsed Baseline $
ACWP / BCWS
How fast are we spending our money?

  To Go Dollars             For the baseline, this is (yet 
again) the budgeted cost of the 
task (BAC).  For the current 
schedule, it is the total cost of 
the task, as estimated on each 
assignment form, less the actual 
money spent on each assignment.
Again, this is a measure of 
projected spending, not 
achievement.

  Spent Duration            This is a measure of how much 
elapsed time has been spent on the 
task.  It is not a measure of 
effort spent, dollars spent or 
achievement.  The formula is 
AsOfDate minus StartDate, with 
limits of zero and the duration of 
the task.  For the baseline of a 
task, this equals zero.

  Spent Dur as % of Baseli  elapsed time as % of baseline 
duration
                            Spent Duration / Baseline Duration

  To Go Duration            current estimate of remaining 
effort
Duration - Spent Duration
For the baseline of the task, this 
is equal to the duration.

  To Go Dur as % of Baseli  above as % of baseline duration
To Go Duration / Baseline Duration 

  Spent Effort              Resources' efforts spent so far
                            Effort (eg. man-hours) spent so 
far.  These amounts are entered by 
the user on the resource assignment 
forms within each task form.  The 
spent effort on each assignment 
will equal the spent dollars 
divided by the rate.   For the 
baseline of a task, this is zero.

  To Go Effort              This is computed directly from the 
numbers entered on each resource 
assignment form, and equals the 
total effort minus the spent 
effort.  It represents planned 
expenditures, not planned 
achievement, and so has nothing to 
do with the percent achieved field.
For the baseline of a task, this 
equals the total effort.

  Achieved $ (BCWP)         (Budgeted Costs for Work Performed)
                            Percent Achieved * BaselineDollars.
This is the principal measure of 
what has actually been accomplished 
towards project goals.  There is no 
value for the baseline of this.


  Spending Rate Ratio       Spent Dollars / Elapsed Baseline $
ACWP/BCWS
This measures how much we have 
spent to date versus what we 
planned to spend.

  Schedule Variance         BCWP - BCWS
                            Achieved Value - Elapsed Baseline $
Is value being achieved faster or 
more slowly than the baseline 
projected, and by how much?
                            
  Schedule Variance %       (BCWP - BCWS)/BCWS
The schedule variance as a 
component of the value scheduled to 
have been achieved to date.
                            
  Productivity Time Ratio   Achieved Value / Elapsed Baseline $
BCWP / BCWS
The ratio of the Work Accomplished 
versus the work scheduled to be 
accomplished.

  Cost Variance             BCWP - ACWP
Achieved Value - Spent Value
Is work being accomplished more 
cheaply or expensively than 
planned.
        
  Cost Variance %           (BCWP - ACWP)/BCWP
This is the cost variance as a 
component of the spent value.
                            
  Productivity Cost Ratio   Achieved Dollars / Spent Dollars
BCWP/ACWP
This reflects how efficiently the 
money has been spent, with respect 
to the work that has been 
accomplished.  Note that it is not 
a measure of whether or not the 
project is on schedule, or is 
efficient in its use of time.


  EAC Variance %            (BAC-EAC)/BAC
The Estimate At Completion variance 
as a component of the total budget.


  Variance At Completion    BAC - EAC
The difference between the baseline 
(budgeted) cost for the task and 
the current (projected or actual) 
cost.


