IMPLEMENTATION MODULE RsrcFormat;

(*  =========================================================================
    Last Edit : September 26, 1990 5:37PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 

    Rsrc Format - Format Resource Information

        This module is intended to do for resources what Captions does for
        tasks.  That is, given a column ID, return information about a
        resource.

        At this time, only the information about a resource COLUMN is
        returned, not information about a specific resource.

    MODIFICATION HISTORY:

        20-Feb-89 RSC First version - information only.
        17-Mar-89 RSC Added support for better reports.
         3-Apr-89 RSC Fixed bugs in getting messages.
         1-May-89 MWP Fixed phrases file offsets.
        16-May-89 KKC Set output buffer to NULL for Notes Field
                      if there are no notes in GetRsrcValue.
        20-May-89 RSC Accomidated new WorkHours module.
        31-Aug-89 EGK Changed DefaultPercent and LevelingPercent to be
                      real-valued percentage columns.
         1-Sep-89 EGK Added FormatType parameter to FormatRsrcValue.
         2-Oct-89 MWP When outputting UnitOfMeasure values, we
                      are outputting the value "Units" for all
                      resource types other than Units. Corrected
                      to output the correct values.
        10-Oct-89 KKC Set BooleanValue in XGetRsrcValue for RsrcLevelingPermitted 
        15-Dec-89 MWP When exporting resource baseline rates, if the resource type
                      is unit cost or fixed, then export a rate of 1 instead
                      of nothing. This allows us to adjust the assignment
                      costs correctly on a recalc.
        26-Sep-90 PFG Added ColumnType parameter to ColumnInfo for 
                      user-defined column headings.
        17-Oct-90 AJL   Added RsrcSequenceNumber.
         7-May-91 TGS Added RsrcVacationCalExists..RsrcOvertimeMultiplier.
        20-May-91 TGS Remove RsrcOvertimeMultiplier.
        21-May-91 AJL -Only report "people" resource columns for resources.
                       We had been reporting them for variable costs as well.
                      -Report the levelling limit and percent as the first
                       entry in the list, not the unused LevellingLimit
                       fields.
                      -If the Availability list is nil, use the default amounts.
                      -If a resource full name is blank, use the short name.
                      -Made the rules the same for Resource current and baseline
                       rates (we only show them if the CostStyle is CAmountRateTime).
                      -No longer use AverageResourceRate.  Show the first rate
                       on the list instead.

    =========================================================================
  *)

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* PROC *)                  FormatColumnValue;

FROM ColData                IMPORT
    (* TYPE  *)                 AColumnType;

FROM DateLists              IMPORT 
    (* TYPE *)                  ADateList,
    (* PROC *)                  GetDateListEntry, NumberOfDatesInList;

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
                                SetLengthOf, LengthOf;

FROM MagicNum               IMPORT
    (* CONST *)                 RsrcModuleNumber,

                                RsrcName,               RsrcFullName,
                                RsrcKeyword,            RsrcNotes,
                                RsrcType,               RsrcDefaultLimit,
                                RsrcDefaultPercent,     RsrcLevelingLimit,
                                RsrcLevelingPercent,    RsrcRate,
                                RsrcUnitCost,           RsrcUnitOfMeasure,
                                RsrcBaselineRate,       RsrcLevelingPermitted,
                                RsrcSeqNumColumn,

                                (* 7-May-91 TGS *)
                                RsrcVacationCalExists,  RsrcBslnVacationCalExists,
                                RsrcVaryingRatesExist,  RsrcBslnVaryingRatesExist,
                                RsrcVaryingAvailsExist, RsrcBslnVaryingAvailsExist,
                                (* 20-May-91 TGS
                                RsrcOvertimeMultiplier,
                                *)
                                RsrcLastColumn;

FROM MsgFile                IMPORT
    (* PROC *)                  ConcatMessage;

FROM RateLists              IMPORT 
    (* TYPE *)                  ARateList,
    (* PROC *)                  GetRateListEntry,
    (* PROC *)                  NumberOfRatesInList;

FROM RealFormat             IMPORT
    (* TYPE *)                  DefaultCurrencyFormat,
    (* PROC *)                  FormatAsCurrency;

FROM ResCalUI               IMPORT
    (* TYPE *)                  AnAvailabilityRate, AResourceCalendarPointer;
    
FROM RsrcMod                IMPORT
    (* CONST *)                 DefaultCostRate, DefaultAvailabilityAmount,
                                DefaultAvailabilityPercent,
    (* TYPE *)                  AResourcePointer, ACostStyle, AResourceType;

FROM SYSTEM                 IMPORT
    (* PROC *)                  TSIZE;

FROM Text                   IMPORT
    (* PROC *)                  LineExists, CopyLine;

FROM Timei                  IMPORT
    (* CONST *)                 MaxDate, MinDate;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM WorkHours               IMPORT
    (* PROC *)                  RealTimeToWorkHours;





CONST
    OneHundred      = 100.0;






(*
    Get Rsrc Info

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
PROCEDURE XGetRsrcInfo(     ColumnID      : CARDINAL;
                            InfoChoice    : AColumnInfoChoice;
                            Length        : CARDINAL;
                        VAR InfoValue     : AColumnDataRecord) : BOOLEAN;
BEGIN
    IF (ColumnID > RsrcLastColumn) THEN
        RETURN FALSE;
    ELSE
        ColumnInfo( RsrcModuleNumber,
                    ColumnID,
                    RsrcLastColumn,
                    InfoChoice, 
                    Length, 
                    RsrcColumnInfo,         (* 26-Sep-90 PFG *)
                    InfoValue );
        RETURN TRUE;
    END;
END XGetRsrcInfo;




PROCEDURE GetAmountAndPercent(     Availability : ADateList;
                               VAR Amount       : CARDINAL;
                               VAR Percent      : REAL );
VAR
    AvailabilityRate  : AnAvailabilityRate;
    AvailabilityStart,
    AvailabilityEnd   : ABigTime;
BEGIN
    IF (Availability <> ADateList(NIL)) AND
       GetDateListEntry(Availability,
                        1,
                        AvailabilityStart, AvailabilityEnd,
                        AvailabilityRate ) THEN
        Amount  := AvailabilityRate.Amount;
        Percent := FLOAT(AvailabilityRate.Percent) / 100.0;
    ELSE
        Percent := FLOAT(DefaultAvailabilityPercent) / 100.0;
        Amount  := DefaultAvailabilityAmount;
    END;
END GetAmountAndPercent;








  (* InitialResourceRate - Return the initial rate from this list.

  *)

PROCEDURE InitialResourceRate( RateList : ARateList
                             ) : REAL;
VAR
    PeriodStartDate, PeriodThruDate : ABigTime;
    Amount           : REAL;
BEGIN

    IF (RateList <> ARateList(NIL)) AND
       (GetRateListEntry( RateList, 1, PeriodStartDate, PeriodThruDate,
                          Amount )) THEN
    ELSE
        Amount := DefaultCostRate;
    END;

    RETURN Amount;

END InitialResourceRate;




(*
    Get Rsrc Value

        Preconditions
                        > RsrcNode  is the resource's tree node.

                        > ColumnID  is the column to return information about.

        Postconditions
                        > If TRUE, Value contains the desired information.

                        > If FALSE, The column data is not applicable.
*)
PROCEDURE XGetRsrcValue(    RsrcNode     : ATreeNode;
                            ColumnID     : CARDINAL;
                        VAR Value        : AColumnDataRecord)
                                                              : BOOLEAN;
VAR
    Resource : AResourcePointer;
    DummyCardinal    : CARDINAL;
    DummyReal        : REAL;
    ok       : BOOLEAN;
BEGIN

    ok       := TRUE;

    Resource := RsrcNode^.Methods^.GetDataObject( RsrcNode );

    WITH Resource^ DO
        WITH Value DO
            GetValueInfo( RsrcModuleNumber + ColumnID, DataType, DataFields );
            CASE ColumnID OF
                RsrcName:
                    Copy( Name, StringValue );

              | RsrcFullName:
                    Copy( LongName, StringValue );
                    TrimRear(StringValue);
                    IF (LengthOf(StringValue)=0) THEN
                        Copy( Name, StringValue );
                    END;

              | RsrcKeyword:
                    Copy( Keyword, StringValue );

              | RsrcNotes:
                    IF (LineExists(Notes, 0)) THEN
                        CopyLine( Notes, 0, StringValue );
                    ELSE                (* KKC May 16, 1989 *)
                        SetLengthOf ( StringValue, 0);
                    END;

              | RsrcType:
                    CardinalValue := ORD(CostStyle) + 1;
                    IF (Type = Employable) THEN
                        CardinalValue := 0;  (* "Rsrc,Fixed,Unit,Var" *)
                    END;
                    GetMessageWord( RsrcModuleNumber - 8, CardinalValue, StringValue );

              | RsrcDefaultLimit:
                    ok   := (Type <> AccountingOnly);
                    CardinalValue := TRUNC(Limit / FLOAT(Percent));

              | RsrcDefaultPercent:
                    ok   := (Type <> AccountingOnly);
                    RealValue     := FLOAT(Percent) / OneHundred;       (* 8/31/89 EGK *)

              | RsrcLevelingLimit:
                    ok   := (Type <> AccountingOnly);
                    GetAmountAndPercent(Availability,
                                        CardinalValue,
                                        DummyReal);

              | RsrcLevelingPercent:
                    ok   := (Type <> AccountingOnly);
                    GetAmountAndPercent(Availability,
                                        DummyCardinal,
                                        RealValue);

              | RsrcRate:
                    ok := (CostStyle = CAmountRateTime);
                    RealValue     := InitialResourceRate( ActualRates );

              | RsrcUnitCost:
                    ok            := (CostStyle <> CAmount);
                    RealValue     := InitialResourceRate( ActualRates );

                    IF (CostStyle  = CAmountRateTime) THEN
                        CardinalValue  := ORD(Units);
                        RealValue      := RealValue * RealTimeToWorkHours( 1.00, Units );
                    END;
                    FormatAsCurrency( RealValue, DefaultCurrencyFormat,
                                      StringValue, HIGH(StringValue),
                                      FALSE, TRUE, TRUE );
                    TrimFront( StringValue );
                    TrimRear(  StringValue );
                    ConcatMessage( StringValue, RsrcModuleNumber - 9 ); (* " per " *)
                    IF (CostStyle = CAmountRateTime) THEN
                        ConcatMessageWord( RsrcModuleNumber - 7, CardinalValue, StringValue );
                            (* "Minutes,Hours,Days,Weeks,Months,Years" *)
                    ELSE
                        ConcatLS( StringValue, UnitOfMeasure );
                    END;

              | RsrcUnitOfMeasure:
                    ok            := (CostStyle <> CAmount);
                    SetLengthOf ( StringValue, 0 );

                    IF (CostStyle = CAmountRateTime) THEN
                        GetMessageWord( RsrcModuleNumber - 7, ORD(Units), StringValue );
                        (* "Minutes,Hours,Days,Weeks,Months,Years" *)
                    ELSE
                       IF (CostStyle = CAmountRate ) THEN
                           Copy( UnitOfMeasure, StringValue );
                       END;
                    END;

                    TrimFront ( StringValue );
                    TrimRear ( StringValue );

              | RsrcBaselineRate:
                    ok := (CostStyle = CAmountRateTime);
                    RealValue     := InitialResourceRate( BaseLineRates );

              | RsrcLevelingPermitted:
                    ok            := (Type <> AccountingOnly);

                    IF ( ok ) THEN
                       BooleanValue := LevelThisResource;
                       CardinalValue := ORD(LevelThisResource);
                       GetMessageWord( RsrcModuleNumber - 6, CardinalValue, StringValue );
                                    (* "No,Yes" *)
                    END;


              | RsrcSeqNumColumn:
                    CardinalValue := Resource^.SequenceNumber;

              | RsrcVacationCalExists     :
                  BooleanValue := (Calendar <> AResourceCalendarPointer(NIL));
                  CardinalValue:= ORD(BooleanValue);
  
              | RsrcBslnVacationCalExists :
                  BooleanValue := (BaselineCalendar <> AResourceCalendarPointer(NIL));
                  CardinalValue:= ORD(BooleanValue);
  
              | RsrcVaryingRatesExist     :
                  BooleanValue := (1 < NumberOfRatesInList(ActualRates));
  
              | RsrcBslnVaryingRatesExist :
                  BooleanValue := (1 < NumberOfRatesInList(BaseLineRates));
  
              | RsrcVaryingAvailsExist    :
                  BooleanValue := (1 < NumberOfDatesInList(Availability, TSIZE(AnAvailabilityRate)));
  
              | RsrcBslnVaryingAvailsExist:
                  BooleanValue := (1 < NumberOfDatesInList(BaselineAvailability, TSIZE(AnAvailabilityRate)));
  
              (* 20-May-91 TGS
              | RsrcOvertimeMultiplier    :
                  RealValue   := OvertimeMultiplier;
              *)
  
            ELSE
                FatalError();
            END;
        END;
    END;

    RETURN ok;

END XGetRsrcValue;









(*
    Format Rsrc Value

        Preconditions
                        > ColumnID  is the column to return information about.

                        > Width     is how wide the data is.

                        > MinDecimals  is the min decimals to use for REALs.

                        > MaxDecimals  is the max decimals to use for REALs.

                        > RightJust    is wether to right justify the string.

        Postconditions
                        > Value contains the desired string.

*)
PROCEDURE XFormatRsrcValue(    ColumnID     : CARDINAL;
                               Width        : CARDINAL;
                               MinDecimals  : CARDINAL;
                               MaxDecimals  : CARDINAL;
                               RightJust    : BOOLEAN;
                               FormatType   : CARDINAL;
                           VAR Value        : AColumnDataRecord);
BEGIN
    FormatDataValue ( Width, MinDecimals, MaxDecimals,
                      RightJust, FormatType, Value      );
END XFormatRsrcValue;










(*
    Get Rsrc String

        Preconditions
                        > RsrcNode  is the resource's tree node.

                        > ColumnID  is the column to return information about.

                        > Width     is how wide the data is.

        Postconditions
                        > If TRUE, Value contains the desired string.

                        > If FALSE, The column data is not applicable.
*)
PROCEDURE XGetRsrcString(    RsrcNode       : ATreeNode;
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

    IF (GetRsrcValue( RsrcNode, ColumnID, ValueRecord )) THEN
        GetFormattingInfo( RsrcModuleNumber + ColumnID,
                           MinDecimals,
                           MaxDecimals,
                           RightJustify,
                           FormatType   );
        FormatRsrcValue( ColumnID,
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

END XGetRsrcString;


























BEGIN
    GetRsrcInfo     := XGetRsrcInfo;
    GetRsrcValue    := XGetRsrcValue;
    FormatRsrcValue := XFormatRsrcValue;
    GetRsrcString   := XGetRsrcString;
END RsrcFormat.

