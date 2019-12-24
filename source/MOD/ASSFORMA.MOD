IMPLEMENTATION MODULE AssFormat;

(*  =========================================================================
    Last Edit : September 26, 1990 5:47PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 

    Ass Format - Format Assignment Information

        This module is intended to do for Assignments what Captions does for
        tasks.  That is, given a column ID, return information about an
        assignment.

        At this time, only the information about an assignment COLUMN is
        returned, not information about a specific assignment.


        MODIFICATION History -

        20-Feb-89 RSC First version - information only.
        17-Mar-89 RSC Full feature version.
        03-May-89 EGK Changed to use new WBS storage scheme.
        17-May-89 MWP Changed offsets into Phrases file.
        20-May-89 RSC Changed ManHours to WorkHours.
        23-Jun-89 MWP Added Baseline column values to complement Actual
                      columns.
        13-Jul-89 MWP Removed Task ID column.
        27-Jul-89 MWP Changed incorrect indexing for retrieving the Assignment
                      Time Units fro the phrases file.
        24-Aug-89 MWP Trim trailing spaces from WBS field.
        31-Aug-89 EGK Changed PercentEach columns to be real-valued
                      percentage columns.  Added FormatType parameter to
                      FormatAssValue.
        12-Sep-89 KKC Check for baseline in XGetAssValue.
        30-Nov-89 MWP In GetAssValue, Look to see if the assignment is
                      valid before entering the case statement. This removes
                      the check within each case. If the resource type
                      for a particular case is not valid, don't continue
                      calculating the value.
        10-Aug-90 RSC Updated method of getting costs from assignment rec.
        26-Sep-90 PFG Added ColumnType parameter to ColumnInfo for 
                      user-defined column headings.
        29-Jan-92 TGS "NumberOf" is considered a real value now.
        06-Mar-92 LAA The calculations for Spent and ToGo assignment costs
                      were incorrectly using the Baseline dates, so it 
                      picked up the wrong rate when rates varied.
        30-Mar-92 TGS   Replaced a call to GetFormattingInfo() with several
                        calls to ColumnInfo(). We weren't picking up user
                        entered Min/MaxDigits values.
         6-Apr-92 TGS   Call new proc, AssignmentDollars(), instead of
                        AssignmentCosts().
    =========================================================================
  *)
FROM Allocs                 IMPORT
    (* CONST *)                 WBSLine,
    (* TYPE *)                  ATaskPtr,
    (* PROC *)                  GetCodingField;

FROM AssgnCalc              IMPORT
    (* PROC *)                  AssignmentDollars;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord, AnAssignmentAttribute;

FROM AssgnCalc              IMPORT
    (* PROC *)                  ComputeEffortsAndCostsInPeriod,
                                ComputeLinearCostsInPeriod;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* PROC *)                  FormatColumnValue;

FROM ColData                IMPORT
    (* TYPE  *)                 AColumnType;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FormatCommon           IMPORT
    (* PROC *)                  ColumnInfo, GetFormattingInfo, GetValueInfo,
                                GetMessageWord, ConcatMessageWord,
                                FormatDataValue;

FROM Gantt                  IMPORT
    (* TYPE *)                  AGanttLineType;

FROM LStrings               IMPORT
    (* PROC *)                  Copy, ConcatLS, TrimFront, TrimRear,
                                SetLengthOf;

FROM MagicNum               IMPORT
    (* CONST *)                 AssModuleNumber, AssLastColumn,
                                AssBsLnLastColumn,
                                AssTaskName,
                                AssTaskWBS,
                                AssResourceName,
                                AssBillable,
                                AssNumberAt,
                                AssPercentEach,
                                AssTotalHours,
                                AssCompletedHours,
                                AssYTGHours,
                                AssTotalTime,
                                AssCompletedTime,
                                AssYTGTime,
                                AssTimeUnits,
                                AssTotalUnits,
                                AssCompletedUnits,
                                AssYTGUnits,
                                AssTotalCost,
                                AssCompletedCost,
                                AssYTGoCost,

                                BsLnBillable,
                                BsLnNumberAt,
                                BsLnPercentEach,
                                BsLnTotalHours,
                                BsLnCompletedHours,
                                BsLnYTGHours,
                                BsLnTotalTime,
                                BsLnCompletedTime,
                                BsLnYTGTime,
                                BsLnTimeUnits,
                                BsLnTotalUnits,
                                BsLnCompletedUnits,
                                BsLnYTGUnits,
                                BsLnTotalCost,
                                BsLnCompletedCost,
                                BsLnYTGoCost;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM RsrcCalc               IMPORT
    (* TYPE *)                  AnAssignmentCostType, AnAssignmentCostTypeSet;

FROM RsrcMod                IMPORT
    (* TYPE *)                  AResourcePointer, ACostStyle, AResourceType,
    (* PROC *)                  AverageResourceRate;

FROM VaryAssgnment          IMPORT 
    (* TYPE *)                  AVaryingAssgnList;

FROM WorkHours               IMPORT
    (* PROC *)                  WorkHoursToRealTime;

CONST
    OneHundred          = 100.0;
    MAXCARDINAL         = 65535;


(*
    Get Ass Info

        Preconditions
                        > ColumnID  is the column to return information about.

                        > InfoChoice is the kind of information you are
                          interested in.  See Captions.Def for the choices.

                        > Length is the length of the string to return,
                          important mostly for Right Justified strings.

        Postconditions
                        > If TRUE, InfoValue contains the desired information.
                          If a string value is being returned, it may be right
                          justified, and is always exactly "Length" bytes long.

                        > If FALSE, The column does not exist.  This allows
                          looking for information on ALL columns.
*)
PROCEDURE XGetAssInfo(     ColumnID      : CARDINAL;
                           InfoChoice    : AColumnInfoChoice;
                           Length        : CARDINAL;
                       VAR InfoValue     : AColumnDataRecord) : BOOLEAN;
BEGIN
    IF (ColumnID > AssBsLnLastColumn) THEN
        RETURN FALSE;
    ELSE
        ColumnInfo( AssModuleNumber,
                    ColumnID,
                    AssBsLnLastColumn,
                    InfoChoice, 
                    Length, 
                    AssgColumnInfo,         (* 26-Sep-90 PFG *)
                    InfoValue );
        RETURN TRUE;
    END;
END XGetAssInfo;











(*
    Get Ass Value

        Preconditions
                        > Assignment is the assignment record.

                        > Task       is the assignment's task's pointer.

                        > ColumnID   is the column to return information about.

        Postconditions
                        > If TRUE, Value contains the desired information.

                        > If FALSE, The column data is not applicable.
*)
PROCEDURE XGetAssValue(VAR Assignment   : AnAssignmentRecord;
                           Task         : ATaskPtr;
                           ColumnID     : CARDINAL;
                       VAR Value        : AColumnDataRecord)
                                                              : BOOLEAN;
VAR
    R1, R2   : REAL;
    Resource : AResourcePointer;
    ok       : BOOLEAN;

BEGIN

    ok       := TRUE;


    WITH Assignment DO
        IF ( Resource = AResourcePointer(NIL) ) THEN                 (* 30-Nov-89 MWP *)
           ok := FALSE;
        ELSE
           WITH Value DO
               GetValueInfo( AssModuleNumber + ColumnID, DataType, DataFields );
               CASE ColumnID OF
                   AssTaskName :
                       Copy( Task^.taskname, StringValue );
                       TrimRear ( StringValue );                     (* 24-Aug-89 MWP *)

                 | AssTaskWBS  :
                       GetCodingField (Task^, WBSLine, StringValue);

                 | AssResourceName :
                       Copy( Resource^.Name, StringValue );

                 | AssBillable, BsLnBillable  :
                       BooleanValue := (Billable IN Attributes);
                       GetMessageWord( AssModuleNumber - 7, ORD(BooleanValue), StringValue );
                       (* "No,Yes" *)

                 | AssNumberAt, BsLnNumberAt  :
                       ok := (Resource^.CostStyle = CAmountRateTime);
                       IF (PercentageEach <> 0C) THEN
                           RealValue := FLOAT(MaxRatePercent)/
                                        FLOAT(ORD(PercentageEach));
                       ELSE
                           RealValue := 0.0;
                       END;

                 | AssPercentEach , BsLnPercentEach  :
                       ok := (Resource^.CostStyle = CAmountRateTime);
                       IF ( ok ) THEN
                          RealValue := FLOAT(ORD(PercentageEach)) / OneHundred;   (* 8/31/89 EGK *)
                       END;

                 | AssTotalHours, BsLnTotalHours   :
                       ok        := (Resource^.CostStyle = CAmountRateTime);
                       IF ( ok ) THEN
                          RealValue := ActualQuantity + YetToGoQuantity;
                       END;

                 | AssCompletedHours, BsLnCompletedHours   :
                       ok        := (Resource^.CostStyle = CAmountRateTime);
                       IF ( ok ) THEN
                          RealValue := ActualQuantity;
                       END;

                 | AssYTGHours, BsLnYTGHours  :
                       ok        := (Resource^.CostStyle = CAmountRateTime);
                       IF ( ok ) THEN
                          RealValue := YetToGoQuantity;
                       END;

                 | AssTotalTime, BsLnTotalTime  :
                       ok            := (Resource^.CostStyle = CAmountRateTime);
                       IF ( ok ) THEN
                          TimeUnitValue := ActualTimeUnits;
                          RealValue     := WorkHoursToRealTime( ActualQuantity
                                                              + YetToGoQuantity,
                                                               ActualTimeUnits);
                       END;

                 | AssCompletedTime, BsLnCompletedTime  :
                       ok            := (Resource^.CostStyle = CAmountRateTime);
                       IF ( ok ) THEN
                          TimeUnitValue := ActualTimeUnits;
                          RealValue     := WorkHoursToRealTime( ActualQuantity,
                                                                ActualTimeUnits);
                       END;
                 | AssYTGTime, BsLnYTGTime  :
                       ok            := (Resource^.CostStyle = CAmountRateTime);
                       IF ( ok ) THEN
                          TimeUnitValue := ActualTimeUnits;
                          RealValue     := WorkHoursToRealTime( YetToGoQuantity,
                                                                ActualTimeUnits);
                       END;
                 | AssTimeUnits, BsLnTimeUnits   :
                       ok            := (Resource^.CostStyle = CAmountRateTime);
                       IF ( ok ) THEN
                           TimeUnitValue := ActualTimeUnits;
                           CardinalValue := ORD( ActualTimeUnits );
                
                           GetMessageWord( AssModuleNumber - 8,         (* 28-Jul-89 MWP *)
                                            CardinalValue,
                                            StringValue );
                                    (* Minutes/Hours/Days... *)
                       END;

                 | AssTotalUnits, BsLnTotalUnits   :
                       ok            := (Resource^.CostStyle = CAmountRate);
                       IF ( ok ) THEN
                          RealValue     := ActualQuantity + YetToGoQuantity;
                       END;

                 |  AssCompletedUnits, BsLnCompletedUnits   :
                       ok            := (Resource^.CostStyle = CAmountRate);
                       IF ( ok ) THEN
                          RealValue     := ActualQuantity;
                       END;
                 | AssYTGUnits, BsLnYTGUnits  :
                       ok            := (Resource^.CostStyle = CAmountRate);
                       IF ( ok ) THEN
                          RealValue     := YetToGoQuantity;
                       END;

                 | AssTotalCost :
                    RealValue := AssignmentDollars( Assignment,
                                                    Task^.Plan.Dates.EarlyStart,
                                                    Task^.Plan.Dates.EarlyEnd,
                                                    AnAssignmentCostTypeSet{
                                                        IncludeToGo,
                                                        IncludeSpent,
                                                        IncludeExtras,
                                                        IncludeOvertime} );

                 | BsLnTotalCost :
                       RealValue := AssignmentDollars( Assignment,
                                                    Task^.BaseLine.Dates.EarlyStart,
                                                    Task^.BaseLine.Dates.EarlyEnd,
                                                    AnAssignmentCostTypeSet{
                                                        IncludeToGo,
                                                        IncludeSpent,
                                                        IncludeExtras,
                                                        IncludeOvertime,
                                                        TreatAsBaseline} );

                 | AssCompletedCost  :
                       RealValue := AssignmentDollars( Assignment,
                                                    Task^.Plan.Dates.EarlyStart,  (* 06-Mar-92 *)
                                                    Task^.Plan.Dates.EarlyEnd,
                                                    AnAssignmentCostTypeSet{
                                                        IncludeSpent,
                                                        IncludeOvertime} );

                 | BsLnCompletedCost :
                       RealValue := AssignmentDollars( Assignment,
                                                    Task^.BaseLine.Dates.EarlyStart,
                                                    Task^.BaseLine.Dates.EarlyEnd,
                                                    AnAssignmentCostTypeSet{
                                                        IncludeSpent,
                                                        IncludeOvertime,
                                                        TreatAsBaseline} );

                 | AssYTGoCost  :
                       RealValue := AssignmentDollars( Assignment,
                                                    Task^.Plan.Dates.EarlyStart,  (* 06-Mar-92 *)
                                                    Task^.Plan.Dates.EarlyEnd,
                                                    AnAssignmentCostTypeSet{
                                                        IncludeToGo,
                                                        IncludeOvertime} );
                 | BsLnYTGoCost :
                       RealValue := AssignmentDollars( Assignment,
                                                    Task^.BaseLine.Dates.EarlyStart,
                                                    Task^.BaseLine.Dates.EarlyEnd,
                                                    AnAssignmentCostTypeSet{
                                                        IncludeToGo,
                                                        IncludeOvertime,
                                                        TreatAsBaseline} );

               ELSE
                   FatalError();  (* New column I don't know about? *)
               END;
           END;
        END;
    END;

    RETURN ok;

END XGetAssValue;









(*
    Format Ass Value

        Preconditions
                        > ColumnID     is the column to return information about.

                        > Width        is how wide the data is.

                        > MinDecimals  is the min decimals to use for REALs.

                        > MaxDecimals  is the max decimals to use for REALs.

                        > RightJust    is wether to right justify the string.

        Postconditions
                        > Value contains the desired string.

*)
PROCEDURE XFormatAssValue(    ColumnID     : CARDINAL;
                              Width        : CARDINAL;
                              MinDecimals  : CARDINAL;
                              MaxDecimals  : CARDINAL;
                              RightJust    : BOOLEAN;
                              FormatType   : CARDINAL;
                          VAR Value        : AColumnDataRecord);
BEGIN
    FormatDataValue( Width, MinDecimals, MaxDecimals,
                     RightJust, FormatType, Value    );
END XFormatAssValue;










(*
    Get Ass String

        Preconditions
                        > Assignment is the assignment record.

                        > Task       is the assignment's task's pointer.

                        > ColumnID  is the column to return information about.

                        > Width     is how wide the data is.

        Postconditions
                        > If TRUE, Value contains the desired string.

                        > If FALSE, The column data is not applicable.
*)
PROCEDURE XGetAssString(VAR Assignment     : AnAssignmentRecord;
                            Task           : ATaskPtr;
                            ColumnID       : CARDINAL;
                            Width          : CARDINAL;
                        VAR Value          : ARRAY OF CHAR )
                                                              : BOOLEAN;
VAR
    MinDecimals,
    MaxDecimals   : CARDINAL;
    RightJustify  : BOOLEAN;
    FormatType    : CARDINAL;
    ValueRecord   : AColumnDataRecord;
BEGIN

    (* 30-Mar-92 TGS Replaced a call to GetFormattingInfo with this: *)

    ColumnInfo(AssModuleNumber, ColumnID, AssBsLnLastColumn,
                ColumnMinDecimals, Width, AssgColumnInfo, ValueRecord);
    MinDecimals := ValueRecord.CardinalValue;
    ColumnInfo(AssModuleNumber, ColumnID, AssBsLnLastColumn,
                ColumnMaxDecimals, Width, AssgColumnInfo, ValueRecord);
    MaxDecimals := ValueRecord.CardinalValue;
    ColumnInfo(AssModuleNumber, ColumnID, AssBsLnLastColumn,
                ColumnRightJustified, Width, AssgColumnInfo, ValueRecord);
    RightJustify := ValueRecord.BooleanValue;
    ColumnInfo(AssModuleNumber, ColumnID, AssBsLnLastColumn,
                ColumnFormatType, Width, AssgColumnInfo, ValueRecord);
    FormatType   := ValueRecord.CardinalValue;

    IF (GetAssValue( Assignment, Task, ColumnID, ValueRecord )) THEN

        FormatAssValue( ColumnID,
                        Width,
                        MinDecimals,
                        MaxDecimals,
                        RightJustify,
                        FormatType,
                        ValueRecord );
    ELSE
        SetLengthOf(Value, 0);
        RETURN FALSE;
    END;

    Copy( ValueRecord.StringValue, Value );

    RETURN TRUE;

END XGetAssString;


























BEGIN
    GetAssInfo     := XGetAssInfo;
    GetAssValue    := XGetAssValue;
    FormatAssValue := XFormatAssValue;
    GetAssString   := XGetAssString;
END AssFormat.
