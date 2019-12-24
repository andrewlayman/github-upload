IMPLEMENTATION MODULE EditCommon;


(* Edit Common  - Support routines for TaskEdit, RsrcEdit, AssEdit,
                  and EdgeEdit.


    Modification History:

        21-Feb-89  RSC  Initial Version.
        31-Mar-89  MWP  Changed comparsions of Column Name strings to compare at
                        most 10 characters, so as to allow correct comparisons
                        of Names for dBase format.
        10-Apr-89  RSC  Added capability to parse formulas.
         4-May-89  RSC  Allow 0 byte string fields on input from non-intermediate
                        file records, so you can use the spreadsheet view to
                        blank out names, wbs numbers, etc.  Edit boolean values
                        when not from intermediate file records.  Removed the
                        ever-present "MattString"s, used by matt for debugging
                        and left behind to take up space.
        17-May-89  WKH
                   RSC  Yet again fixed this module for new WBS scheme.
        20-May-89  RSC  Accomidated new WorkHours module.
        25-May-89  EGK  Import "WBSLen" from Allocs instead of hard-coding
                        "15" for the WBS length.
         1-Jun-89  RSC  Entering "1 minute" took it as 1 HOUR due to a phrase
                        numbering problem.
        21-Jun-89  AJL  Added the ability to look at the format of a column
                        in DigestString and IntDigestString to compensate
                        for the scaling effect of percentage columns.
        26-Jun-89  KKC  Import RealToLStrings from Num2Str.
        27-Jun-89  KKC  Import RealToLStrings from RealFormat.
         1-Jul-89  MWP  Fixed importing Duration values to recognize the correct
                        time unit value.
         9-Jul-89  MWP  If duration is equal to 0, then no particular time unit
                        value needs to be associated with it. ( eg. 1 day or
                        4 hours. ) If we detect a duration value of 0 and
                        no time unit, we should not cause an warning message
                        to be logged to the import journal.
        22-Jul-89  MWP  When calling RetrieveString for a boolean value, assume
                        the boolean value is stored as a string value. If
                        lengthof stringvalue is zero, do not log an
                        error message, but rather assume a FALSE value.
        29-Jul-89 MWP   When editing Duration or Effort columns, do not scale
                        the value by units.
        27-Aug-89 MWP   For the purposes of importers, in DigestAIntString, if
                        a date string is of zero length, do not log an error.
                        There are lots of times when a date is not applicable,
                        and a blank value is supplied ( as in 123 format ).
        31-Aug-89 LAA   Added a parameter to ParseAmountToReal.
        12-Sep-89 MWP   Call RetrieveReal when getting a real value in
                        DigestAIntString.
        17-Sep-89 MWP   If a duration field does not have a time unit associated
                        with it, and the value is not zero, log an error message.
        19-Sep-89 RSC   Give a suggested start date to StoEndDate;
        22-Sep-89 MWP   Allow various Retrieve????? procs to report to client
                        on their success.
         6-Oct-89 MWP   Fixed problem with giving suggested start dates. The
                        wrong time format proc was being called ( TimeuToT
                        instead of TtoTimeU ) and the parameter order was
                        incorrect for the call to boot. This little problem
                        generated about half a dozen bug reports. Allright!
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        25-Jun-91 RSC   Bug # 4646, importing trimmed durations (like
                        "h" for "hours") didn't work.
*)

FROM Allocs         IMPORT
    (* CONST *)         WBSLine, WBSLen,
    (* TYPE *)          ATaskPtr,
    (* VAR  *)          TaskTree,
    (* PROC *)          GetCodingField;

FROM BigTimeU       IMPORT
    (* PROC *)          TimeToBigTime;

FROM Captions       IMPORT
    (* TYPE *)          AColumnDataRecord, AColumnInfoChoice,
                        AColumnDataField,  ASetOfColumnDataFields,
    (* PROC *)          GetCurrencyScale;

FROM Clock          IMPORT
    (* TYPE *)          ASystemTime,
    (* PROC *)          GetDateAndTime;

FROM EditError      IMPORT
    (* TYPE *)          AnErrorHandlerProc, AnErrorSeverity, AKindOfError;

FROM EvalReal       IMPORT
    (* PROC *)          EvaluateRealExpression;

FROM Foreign        IMPORT
    (* TYPE *)          ACharacterConversionTable,
    (* PROC *)          DoDash, ConvertString;

FROM IntFileIO      IMPORT
                        AFormatType,
                        AnIntDataRecord,
                        TextType,
                        RealNumberType,
                        IntegerType,
                        CardinalType,
                        BooleanType,
                        EnumeratedType,
                        BigStartTimeType,
                        BigEndTimeType,
                        StartDateType,
                        EndDateType;

FROM LStrings       IMPORT
    (* PROCS *)         TrimFront, TrimRear, Copy, SetLengthOf, StringsEqual,
                        StoC, LengthOf,  Upshift, SetString, Remove, Fill,
                        LStringToTString,ConcatLS, ConcatS, CtoS,
                        TStringToLString;

FROM MagicNum       IMPORT
    (* CONST *)         IsStringValue,
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

FROM Matches        IMPORT
    (* PROCS *)         MatchBoolean;

FROM MsgFile        IMPORT
    (* PROCS *)         GetMessage;

FROM NumberConversion IMPORT
                        StringToInt, IntToString;

FROM ParseReal      IMPORT
    (* PROC *)          ParseAmountToReal;

FROM ParseTime      IMPORT
    (* PROC *)          StoTimeU, StoD, StoEndTimeU, StoEndD;

FROM RealFormat     IMPORT
    (* TYPE *)          AnAmountFormat,
    (* VARS *)          DefaultAmountFormat,
    (* PROC *)          RealToLStrings;


FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS, ADR;

FROM Timei          IMPORT
    (* TYPE *)          ADurationUnit, ATimeInfo,
    (* PROC *)          TtoTimeU, SystemTimeToTime;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATreeNode, ATreeOrder;

FROM Words          IMPORT
    (* PROC *)          ParseString;

FROM WorkHours       IMPORT
    (* PROCS *)         RealTimeToWorkHours;





CONST
    Zero        = 0.0;
    One         = 1.0;
    OneHundred  = 100.0;
    MAXCARDINAL  = 65535;

    CaptionsModuleNumber = 19100;  (* FROM CAPTIONS *)




VAR
    GlobalWBS       : ARRAY [0..WBSLen] OF CHAR;
    NilString       : ARRAY [0..1] OF CHAR;
    CharTable       : ACharacterConversionTable;




(* Squeeze  - Squish off front and rear spaces from a string and upshift it. *)

PROCEDURE Squeeze(  VAR TheString : ARRAY OF CHAR );
BEGIN
    TrimRear(  TheString );
    TrimFront( TheString );
    Upshift(   TheString );
END Squeeze;








(*
    Get A Column ID

        Preconditions
                        > "ColumnName" is an LString containing the FORMAL
                          NAME of a column.
                          The caller must resolve any differences between
                          the name read in from a file and the "official"
                          formal name.  For example, DBase translates some
                          charactors.

                        > "GetInfoProc" is the procedure that supplies
                          information about columns.  Typicaly, these come
                          from "XXXXFormat" modules.

        Postconditions
                        > Returns TRUE if the ColumnName is a known
                          column name, or FALSE if it is unknown.

                        > ColumnID is the internal number to use for
                          changing the data, if TRUE is returned.
        Notes:
                        > Because of the fact that we may be receiving formal
                          names from differant file formats such as CSV or
                          dBase, we cannot depend upon the facct that the whole
                          formal name will be  available. e.g. dBase names are
                          truncated to a maximum of 10 characters. Because of
                          this, we will truncate the incoming formal name to
                          10 char's, and each retrieved name to 10 char's
                          before any comparisons are performed. Fortunately,
                          all formal names appear to be unique even at 10
                          character width.
*)
PROCEDURE GetAColumnID(     GetInfoProc      : AGetInfoProc;
                        VAR ColumnName       : ARRAY OF CHAR;
                        VAR ColumnID         : CARDINAL ) : BOOLEAN;
VAR
    InfoValue       : AColumnDataRecord;
    LocalColumnName : ARRAY [0..99] OF CHAR;
BEGIN

    Copy( ColumnName, LocalColumnName );
    Squeeze( LocalColumnName );

    IF ( LengthOf ( LocalColumnName ) > 10 ) THEN                      (* MWP 31-Mar-89 *)
        SetLengthOf ( LocalColumnName, 10 );
    END;

    ConvertString ( LocalColumnName, CharTable);

    ColumnID := 1;
    WHILE (GetInfoProc( ColumnID, ColumnFormalName, 255, InfoValue )) DO
        WITH InfoValue DO

            Squeeze( StringValue );

            IF ( LengthOf ( StringValue ) > 10 ) THEN                  (* MWP 31-Mar-89 *)
               SetLengthOf ( StringValue, 10 );
            END;

            ConvertString ( StringValue, CharTable);

            IF (StringsEqual( StringValue, LocalColumnName )) THEN
                RETURN TRUE;
            END;
        END;
        INC(ColumnID);
    END;

    RETURN FALSE;

END GetAColumnID;







    (* AdjustForFormatScale -- Some columns (e.g PercentAchieved)
                               are printed as though
                               they are 100 * their real value.   The
                               user will edit the column in that format and
                               we must unscale it. *)


PROCEDURE AdjustForFormatScale(       GetInfoProc      : AGetInfoProc;
                                      ColumnId   : CARDINAL;
                                  VAR ColumnData : AColumnDataRecord);
VAR
    InfoValue   : AColumnDataRecord;
    ok : BOOLEAN;
BEGIN
        (* Ask what the format is of this ColumnData *)

    IF GetInfoProc( ColumnId, ColumnFormatType, 0, InfoValue ) THEN
        IF (InfoValue.CardinalValue = ORD(FPercent)) THEN
            ColumnData.RealValue := ColumnData.RealValue / OneHundred;
        END;
    END;

END AdjustForFormatScale;








(*
    Digest A String

        Convert a text string into the internal data record format.

        Preconditions
                        > "GetInfoProc" is the proc that returns information
                          about the columns in question.

                        > "ColumnID" is a valid column id for the InfoProc.

                        > "TextString" is the string to be digested into
                          "ColumnData".  It is not modified (VAR only for
                          efficiency).

                        > "Amount Format" is the real number format to use
                          in analizing REAL numbers.  It is not altered.
                          VAR is just for efficiency.

                        > Some columns may allow a "Null" value.  This is
                          handled here by an empty text string.
                          This is not allowed for all columns.

        Postconditions
                        > "ColumnData" is the data to be applied to the
                          assignment.

                        > The text is checked within the context of the
                          column in question, and the "ColumnData" record
                          is filled in appropriately.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error that is fixable can be fixed,
                          at the discresion of the error handler.  A fix that
                          means "Ignore" will return ColumnData filled out as
                          if an empty string was passed.

                        > Returns TRUE if there were no formatting errors,
                          FALSE if there were, and were not fixed.
*)
PROCEDURE DigestAString(     GetInfoProc      : AGetInfoProc;
                             ColumnID         : CARDINAL;
                         VAR TextString       : ARRAY OF CHAR;
                         VAR AmountFormat     : AnAmountFormat;
                         VAR ColumnData       : AColumnDataRecord;
                             ErrorHandler     : AnErrorHandlerProc;
                             HandlersContext  : ADDRESS
                         ) : BOOLEAN;
VAR
    CurrencyScale    : REAL;
    TimeInfo         : ATimeInfo;
    SystemTime       : ASystemTime;
    i,
    StoppedAt        : CARDINAL;
    InfoValue        : AColumnDataRecord;
    Fix,
    ok               : BOOLEAN;



    PROCEDURE FieldsFromType(     TypeOfValue : CARDINAL;
                              VAR DataFields  : ASetOfColumnDataFields );
    BEGIN

    (* Formatters may use additional fields as temp values.  For example,
       they may set CardinalValue := ORD(IntegerValue)
    *)
        CASE TypeOfValue OF
            IsStringValue,
            IsTruncatedString,
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
    END FieldsFromType;




    PROCEDURE GetReal();
    VAR
        ErrorFlag   : BOOLEAN;
    BEGIN

        StoppedAt := 1;
        EvaluateRealExpression( TextString,
                                StoppedAt,
                                ColumnData.RealValue,
                                DefaultAmountFormat,
                                ErrorFlag );

        ok := (NOT ErrorFlag);

        IF (ok) THEN
            AdjustForFormatScale( GetInfoProc, ColumnID, ColumnData);
        ELSE
            Fix := ErrorHandler( FormatError,
                                 NotANumber,
                                 ColumnID, NilString,
                                 HandlersContext );
        END;

    END GetReal;


    PROCEDURE GetTimeUnit( StartHere : CARDINAL );
    VAR
        TimeUnit  : ADurationUnit;
        TimeString,
        Regular,
        Plural    : ARRAY [0..99] OF CHAR;
    BEGIN

        ParseString( TextString, StartHere, TimeString );
        Squeeze( TimeString );

        FOR TimeUnit := Minutes TO Years DO

            GetMessage(CaptionsModuleNumber+ 1+ORD(TimeUnit), Regular );
            GetMessage(CaptionsModuleNumber+11+ORD(TimeUnit), Plural  );

            Squeeze( Regular );
            Squeeze( Plural  );

            IF (StringsEqual( TimeString, Regular ))  OR
               (StringsEqual( TimeString, Plural  ))  THEN
                ColumnData.TimeUnitValue := TimeUnit;
                RETURN;
            END;
        END;

        Fix := ErrorHandler( FormatError,
                             BadTimeUnit,
                             ColumnID, NilString,
                             HandlersContext );
        ok  := FALSE;

    END GetTimeUnit;




BEGIN       (*  DigestAString  *)


    (* What kind of data is it?  Oh, this also validates the column id. *)

    ok  := GetInfoProc( ColumnID, ColumnDataType, 0, InfoValue );

    TrimFront( TextString );
    TrimRear(  TextString );

    WITH ColumnData DO
        IF (ok) THEN
            DataType := InfoValue.CardinalValue;
            FieldsFromType( DataType, DataFields );

            IF (LengthOf( TextString ) = 0)     AND
               (DataType <> IsStringValue)      AND
               (DataType <> IsTruncatedString)  THEN
                DataFields := ASetOfColumnDataFields{};
                DataType   := 0;
            ELSE
                CASE DataType OF
                      0 :  (* Do nothing. *)

                    | IsStringValue,
                      IsTruncatedString  :

                        Copy( TextString, StringValue );

                    | IsEnumValue   : (* Translation left to client *)

                        Upshift( TextString );
                        Copy( TextString, StringValue );

                    | IsBoolValue   :

                        Upshift( TextString );
                        ok := MatchBoolean( TextString, 1, BooleanValue, TimeInfo.tiYear );

                        IF (NOT ok) THEN
                            ok := ErrorHandler( FormatError,
                                                 BooleanWrong,
                                                 ColumnID, NilString,
                                                 HandlersContext );

                        END;

                    | IsRealValue   :

                        GetReal();

                    | IsIntValue    :  (* Treat ints as reals to parse
                                          negitive values.
                                       *)
                        GetReal();
                        IF (ok) THEN
                            ok := (RealValue >= -32768.0) AND (RealValue <= 32767.0);
                            IF (ok) THEN
                                IF (RealValue >= Zero) THEN
                                    IntegerValue := INTEGER(TRUNC(RealValue));
                                ELSE
                                    IntegerValue := 0 - INTEGER(TRUNC(ABS(RealValue)));
                                END;
                            ELSE
                                IF (ErrorHandler( FormatError,
                                                  NumberOutOfRange,
                                                  ColumnID, NilString,
                                                  HandlersContext )) THEN
                                    IF (RealValue > Zero) THEN
                                        IntegerValue :=  32767; (* MAXINT *)
                                    ELSE
                                        IntegerValue := -32768; (* MININT *)
                                    END;
                                    ok := TRUE;
                                END;
                            END;
                        END;

                    | IsCurrency    :   (* Won't work if "$" is included,
                                           but we don't output it that way.
                                        *)
                        GetReal();

                        IF (ok) THEN
                            CurrencyScale   := GetCurrencyScale();
                            IF (CurrencyScale <> One) THEN
                                RealValue   := RealValue * CurrencyScale;
                            END;
                        END;

                    | IsDuration,
                      IsEffort,
                      IsSlack       :

                        (* DANGER!!  These numbers are not scaled by the time
                                     unit value as they should be, so 1 day
                                     is represented here as 1, not 8 hours.
                                     The client must resolve this on the basis
                                     of the column id.
                        *)
                        GetReal();

                    | IsDurationUnits,
                      IsEffortUnits :

                        GetReal();
                        IF (ok) THEN
                            GetTimeUnit( StoppedAt ); (* StoppedAt is set by GetReal *)
                        END;

                    | IsCardValue   :

                        i             := 1;
                        CardinalValue := StoC( TextString, i );
                        ok            := (i > 1);  (* Ok not to grab
                                                      decimals *)
                        IF (NOT ok) THEN
                            ok := ErrorHandler( FormatError,
                                                 NotANumber,
                                                 ColumnID, NilString,
                                                 HandlersContext );
                        END;

                    | IsStartDate,
                      IsMilestoneEnd :

                        GetDateAndTime( SystemTime );
                        SystemTimeToTime( SystemTime, TimeInfo );

                        ok := TtoTimeU ( TimeInfo, DateValue ); (* 6-Oct-89 MWP *)

                        ok := ( ok AND StoTimeU( TextString, DateValue ) ); (* 6-Oct-89 MWP *)

                        IF (NOT ok) THEN
                            ok := ErrorHandler( FormatError,
                                                 DateFormat,
                                                 ColumnID, NilString,
                                                 HandlersContext );
                        END;

                    | IsEndDate      :

                        GetDateAndTime( SystemTime );
                        SystemTimeToTime( SystemTime, TimeInfo );

                        ok := TtoTimeU ( TimeInfo, DateValue );  (* 6-Oct-89 MWP *)

                        ok := ( ok AND StoEndTimeU( TextString, DateValue ) );

                        IF (NOT ok) THEN
                            ok := ErrorHandler( FormatError,
                                                 DateFormat,
                                                 ColumnID, NilString,
                                                 HandlersContext );
                        END;

                    | IsBigStart     :

                        GetDateAndTime( SystemTime );
                        SystemTimeToTime( SystemTime, TimeInfo );

                        ok := TtoTimeU ( TimeInfo, DateValue ); (* 6-Oct-89 MWP *)

                        ok := ( ok AND StoD( TextString, TimeInfo ) );

                        IF (ok) THEN
                            TimeToBigTime
                            (
                                TimeInfo.tiYear,
                                TimeInfo.tiMonth,
                                TimeInfo.tiDay,
                                TimeInfo.tiHour,
                                TimeInfo.tiMinute,
                                0,
                                BigTimeValue
                            );
                        ELSE
                            ok := ErrorHandler( FormatError,
                                                 DateFormat,
                                                 ColumnID, NilString,
                                                 HandlersContext );
                        END;

                    | IsBigEnd       :

                        GetDateAndTime( SystemTime );
                        SystemTimeToTime( SystemTime, TimeInfo );

                        ok := TtoTimeU ( TimeInfo, DateValue ); (* 6-Oct-89 MWP *)

                        ok := ( StoEndD( TextString, TimeInfo ) );

                        IF (ok) THEN
                            TimeToBigTime
                            (
                                TimeInfo.tiYear,
                                TimeInfo.tiMonth,
                                TimeInfo.tiDay,
                                TimeInfo.tiHour,
                                TimeInfo.tiMinute,
                                0,
                                BigTimeValue
                            );
                        ELSE
                            ok := ErrorHandler( FormatError,
                                                 DateFormat,
                                                 ColumnID, NilString,
                                                 HandlersContext );
                        END;

                ELSE
                    ok := ErrorHandler( FormatError, UnknownDataType,
                                         ColumnID, NilString, HandlersContext );
                END;
            END;
        END;


        IF (NOT ok) THEN
            DataFields := ASetOfColumnDataFields{};
            DataType   := 0;
        END;
    END;

    RETURN ok;

END DigestAString;




PROCEDURE DigestAIntString(     GetInfoProc      : AGetInfoProc;
                                ColumnID         : CARDINAL;
                                Type             : CARDINAL;
                            VAR Data             : AnIntDataRecord;
                            VAR AmountFormat     : AnAmountFormat;
                            VAR ColumnData       : AColumnDataRecord;
                                ErrorHandler     : AnErrorHandlerProc;
                                HandlersContext  : ADDRESS
                         ) : BOOLEAN;
VAR
    CurrencyScale    : REAL;
    LargestWeight,
    RegularWeight,
    PluralWeight,
    WeightThisPhrase : CARDINAL;
    TimeInfo         : ATimeInfo;
    SystemTime       : ASystemTime;
    i,
    StoppedAt        : CARDINAL;
    InfoValue        : AColumnDataRecord;
    Fix,
    ok               : BOOLEAN;



    PROCEDURE FieldsFromType(     TypeOfValue : CARDINAL;
                              VAR DataFields  : ASetOfColumnDataFields );
    BEGIN

    (* Formatters may use additional fields as temp values.  For example,
       they may set CardinalValue := ORD(IntegerValue)
    *)
        CASE TypeOfValue OF
            IsStringValue,
            IsTruncatedString,
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
    END FieldsFromType;




    PROCEDURE GetTextReal( VAR StringValue : ARRAY OF CHAR );

    BEGIN

        ParseAmountToReal(StringValue, AmountFormat, ColumnData.RealValue, ok,
                          StoppedAt);

        IF (ok) THEN
            AdjustForFormatScale( GetInfoProc, ColumnID, ColumnData);
        ELSE
            Fix := ErrorHandler( FormatError,
                                 NotANumber,
                                 ColumnID, NilString,
                                 HandlersContext );
        END;
    END GetTextReal;


    PROCEDURE GetTimeUnit(    StartHere   : CARDINAL;
                          VAR StringValue : ARRAY OF CHAR;
                              Value       : REAL );
    VAR
        TimeUnit  : ADurationUnit;
        TimeString,
        Regular,
        Plural    : ARRAY [0..99] OF CHAR;


        PROCEDURE Max( A, B : CARDINAL ) : CARDINAL;
        BEGIN
            IF (A < B) THEN RETURN B; ELSE RETURN A; END;
        END Max;


        PROCEDURE Min( A, B : CARDINAL ) : CARDINAL;
        BEGIN
            IF (A > B) THEN RETURN B; ELSE RETURN A; END;
        END Min;


        PROCEDURE Equalness( VAR A, B : ARRAY OF CHAR ) : CARDINAL;
        VAR
            Limit,
            BytesTheSame    : CARDINAL;
        BEGIN
            Limit        := Min(LengthOf(A),LengthOf(B));
            BytesTheSame := 1;

            WHILE (BytesTheSame   <= Limit) AND
                  (A[BytesTheSame] = B[BytesTheSame])  DO
                INC( BytesTheSame );
            END;

            RETURN (BytesTheSame - 1);

        END Equalness;


    BEGIN
        ParseString( StringValue, StartHere, TimeString );
        Squeeze( TimeString );

        ColumnData.TimeUnitValue := Hours;
        LargestWeight            := 0;

        IF ( LengthOf ( TimeString ) > 0 ) THEN
            FOR TimeUnit := Minutes TO Years DO

               GetMessage(CaptionsModuleNumber+1   +ORD(TimeUnit), Regular );  (* 1-Jul-89 MWP *)
               GetMessage(CaptionsModuleNumber+11  +ORD(TimeUnit), Plural  );  (* 1-Jul-89 MWP *)

               Squeeze( Regular );
               Squeeze( Plural  );

                (* 25-Jun-91 RSC Come up with the "best" answer.
                                 If two match, take the first (most precise)
                *)
               RegularWeight := Equalness( TimeString, Regular );
               PluralWeight  := Equalness( TimeString, Plural  );

               WeightThisPhrase := Max( RegularWeight, PluralWeight );
               IF (WeightThisPhrase > LargestWeight) THEN
                   ColumnData.TimeUnitValue := TimeUnit;
                   LargestWeight            := WeightThisPhrase;
               END;
            END;
            IF (LargestWeight > 0) THEN
                RETURN;
            END;
        ELSE
           IF ( Value <> 0.0 ) THEN                               (* 17-Sep-89 MWP *)
               Fix := ErrorHandler( FormatError,
                                    BadTimeUnit,
                                    ColumnID, NilString,
                                    HandlersContext );
                ok  := FALSE;
           ELSE
                ColumnData.TimeUnitValue := Days;
           END;
        END;

        IF ( Value <> 0.0 ) THEN
           Fix := ErrorHandler( FormatError,
                                BadTimeUnit,
                                ColumnID, NilString,
                                HandlersContext );
           ok  := FALSE;
        END;

    END GetTimeUnit;


BEGIN       (*  DigestAString  *)


    (* What kind of data is it?  Oh, this also validates the column id. *)

    ok  := GetInfoProc( ColumnID, ColumnDataType, 0, InfoValue );
    Fix := FALSE;

    WITH ColumnData DO
        IF (ok) THEN
            DataType := InfoValue.CardinalValue;

            FieldsFromType( DataType, DataFields );

            CASE DataType OF
                  0 :  (* Do nothing. *)

                | IsStringValue,
                  IsTruncatedString :

                    RetrieveString ( Data, Type, StringValue );

                | IsEnumValue   : (* Translation left to client *)

                    RetrieveString ( Data, Type, StringValue );
                    Upshift( StringValue );

                | IsBoolValue   :                               (* 22-Jul-89 MWP *)

                    RetrieveString ( Data, Type, StringValue );
                    Upshift( StringValue );
                    IF ( LengthOf ( StringValue ) > 0 ) THEN

                        IF ( StringValue[1] = 'T' ) THEN
                            BooleanValue := TRUE;
                        ELSIF ( StringValue[1] = 'F' ) THEN
                            BooleanValue := FALSE;
                        ELSE
                            ok := MatchBoolean( StringValue, 1, BooleanValue, TimeInfo.tiYear );
                        END;

                        IF ( NOT ok ) THEN
                           Fix := ErrorHandler(  FormatError,
                                                BooleanWrong,
                                                ColumnID, StringValue,
                                                HandlersContext );
                        END;
                    ELSE
                       BooleanValue := FALSE;
                    END;

                | IsRealValue   :
                    ok := RetrieveReal ( Data, Type, RealValue );  (* 20-Sep-89 MWP *)

                    IF ( NOT ok ) THEN
                       Fix := ErrorHandler( FormatError,
                                            NumberOutOfRange,
                                            ColumnID, NilString,
                                            HandlersContext );
                    END;

                | IsIntValue    :  (* Treat ints as reals to parse
                                      negitive values.
                                   *)
                    ok := RetrieveInteger ( Data, Type, IntegerValue );

                    IF ( NOT ok ) THEN
                       Fix := ErrorHandler( FormatError,
                                            NumberOutOfRange,
                                            ColumnID, NilString,
                                            HandlersContext );
                    END;

                | IsCurrency    :   (* Won't work if "$" is included,
                                       but we don't output it that way.
                                    *)
                    ok := RetrieveReal ( Data, Type, RealValue );

                    IF ( NOT ok ) THEN
                       Fix := ErrorHandler( FormatError,
                                            NumberOutOfRange,
                                            ColumnID, NilString,
                                            HandlersContext );
                    ELSE
                       CurrencyScale   := GetCurrencyScale();
                       IF (CurrencyScale <> One) THEN
                           RealValue   := RealValue * CurrencyScale;
                       END;
                    END;


                | IsDuration,
                  IsEffort,
                  IsSlack       :

                    (* DANGER!!  These numbers are not scaled by the time
                                 unit value as they should be, so 1 day
                                 is represented here as 1, not 8 hours.
                                 The client must resolve this on the basis
                                 of the column id.
                    *)

                    ok := RetrieveReal ( Data, Type, RealValue );

                    IF ( NOT ok ) THEN
                       Fix := ErrorHandler( FormatError,
                                            NumberOutOfRange,
                                            ColumnID, NilString,
                                            HandlersContext );
                    END;

                | IsDurationUnits,
                  IsEffortUnits :

                    RetrieveString ( Data, Type, StringValue );

                    GetTextReal ( StringValue );

                    IF (ok) THEN
                        GetTimeUnit( StoppedAt, StringValue, ColumnData.RealValue );
                    END;

                | IsCardValue   :

                    ok := RetrieveCardinal ( Data, Type, CardinalValue );

                    IF ( NOT ok ) THEN
                       Fix := ErrorHandler( FormatError,
                                            NumberOutOfRange,
                                            ColumnID, NilString,
                                            HandlersContext );
                    END;

                | IsStartDate,
                  IsMilestoneEnd :

                    RetrieveString ( Data, Type, StringValue );
                    IF ( LengthOf ( StringValue ) <> 0 ) AND      (* 27-Aug-89 MWP *)
                       ( StringValue[1] <> '*' ) THEN

                        GetDateAndTime( SystemTime );
                        SystemTimeToTime( SystemTime, TimeInfo );

                        ok := TtoTimeU ( TimeInfo, DateValue ); (* 6-Oct-89 MWP *)

                        ok := ( ok AND StoTimeU(  StringValue, DateValue ) );
                    ELSE
                        ok := FALSE;
                    END;

                    IF (NOT ok) THEN
                        Fix := ErrorHandler( FormatError,
                                             DateFormat,
                                             ColumnID, NilString,
                                             HandlersContext );
                    END;

                | IsEndDate      :

                    RetrieveString ( Data, Type, StringValue );

                    IF ( LengthOf ( StringValue ) <> 0 ) AND      (* 27-Aug-89 MWP *)
                       ( StringValue[1] <> '*' ) THEN

                        GetDateAndTime( SystemTime );
                        SystemTimeToTime( SystemTime, TimeInfo );

                        ok := TtoTimeU ( TimeInfo, DateValue ); (* 6-Oct-89 MWP *)

                        ok := ( ok AND StoEndTimeU( StringValue, DateValue ) );
                    ELSE
                        ok := FALSE;
                    END;

                    IF (NOT ok) THEN
                        Fix := ErrorHandler( FormatError,
                                             DateFormat,
                                             ColumnID, NilString,
                                             HandlersContext );
                    END;



                | IsBigStart     :
                    RetrieveString ( Data, Type, StringValue );

                    IF ( LengthOf ( StringValue ) <> 0 ) AND      (* 27-Aug-89 MWP *)
                       ( StringValue[1] <> '*' ) THEN

                        GetDateAndTime( SystemTime );
                        SystemTimeToTime( SystemTime, TimeInfo );

                        ok := TtoTimeU ( TimeInfo, DateValue ); (* 6-Oct-89 MWP *)

                        ok := (ok AND StoD( StringValue, TimeInfo ) );

                        IF (ok) THEN
                            TimeToBigTime
                            (
                                TimeInfo.tiYear,
                                TimeInfo.tiMonth,
                                TimeInfo.tiDay,
                                TimeInfo.tiHour,
                                TimeInfo.tiMinute,
                                0,
                                BigTimeValue
                            );
                        END;
                    ELSE
                        ok := FALSE;
                    END;

                    IF (NOT ok) THEN
                        Fix := ErrorHandler( FormatError,
                                             DateFormat,
                                             ColumnID, NilString,
                                             HandlersContext );
                    END;



                | IsBigEnd       :

                    RetrieveString ( Data, Type, StringValue );

                    IF ( LengthOf ( StringValue ) <> 0 ) AND      (* 27-Aug-89 MWP *)
                       ( StringValue[1] <> '*' ) THEN

                        GetDateAndTime( SystemTime );
                        SystemTimeToTime( SystemTime, TimeInfo );

                        ok := TtoTimeU ( TimeInfo, DateValue ); (* 6-Oct-89 MWP *)

                        ok := ( ok AND StoEndD  ( StringValue, TimeInfo ) );

                        IF (ok) THEN
                            TimeToBigTime
                            (
                                TimeInfo.tiYear,
                                TimeInfo.tiMonth,
                                TimeInfo.tiDay,
                                TimeInfo.tiHour,
                                TimeInfo.tiMinute,
                                0,
                                BigTimeValue
                            );
                        END;
                    ELSE
                        ok := FALSE;
                    END;

                    IF (NOT ok) THEN
                        Fix := ErrorHandler( FormatError,
                                             DateFormat,
                                             ColumnID, NilString,
                                             HandlersContext );
                    END;

            ELSE
                Fix := ErrorHandler( FormatError, UnknownDataType,
                                     ColumnID, NilString, HandlersContext );
                ok  := FALSE;
            END;
        END;

        IF (Fix) THEN
            DataFields := ASetOfColumnDataFields{};
            DataType   := 0;
            ok         := TRUE;
        END;
    END;

    RETURN ok;

END DigestAIntString;


PROCEDURE  RetrieveReal( VAR Data             : AnIntDataRecord;
                             Type             : CARDINAL;
                         VAR RealValue        : REAL ) : BOOLEAN;
VAR
    ok                      : BOOLEAN;
    i                       : CARDINAL;
    StoppedAt               : CARDINAL;
BEGIN
    RealValue := 0.0;
    ok := TRUE;

    CASE Type OF
        TextType          :
                          IF ( LengthOf ( Data.LString ) > 0 ) THEN
                             ParseAmountToReal(Data.LString, DefaultAmountFormat,
                                               RealValue, ok, StoppedAt );
                          ELSE
                             RealValue := 0.0;
                          END;
     |  RealNumberType    :
                          RealValue := Data.Real;
     |  IntegerType       :
                          i := CARDINAL(Data.Integer);
                          IF ( Data.Integer < 0 ) THEN
                             RealValue := 0.0 - FLOAT(i);
                          ELSE
                             RealValue := FLOAT(i);
                          END;
     |  CardinalType      :
                          RealValue := FLOAT(Data.Cardinal);
     ELSE (* Not allowed as a integer representation *)
        ok := FALSE;
     END;

     RETURN ( ok );

END RetrieveReal;


PROCEDURE  RetrieveCardinal( VAR Data             : AnIntDataRecord;
                                 Type             : CARDINAL;
                             VAR CardinalValue    : CARDINAL ) : BOOLEAN;
VAR
    ok                      : BOOLEAN;
    i                       : CARDINAL;
BEGIN
    CardinalValue := MAXCARDINAL;
    ok := TRUE;

    CASE Type OF
        TextType          :
                          IF ( LengthOf ( Data.LString ) > 0 ) THEN
                              i := 1;
                              CardinalValue := StoC ( Data.LString, i );
                              IF ( i <= 1 ) THEN
                                 ok := FALSE;
                              END;
                          ELSE
                              CardinalValue := 0;
                          END;

     |  RealNumberType    :

                           ok := (Data.Real >= 0.0) AND
                                 (Data.Real <=  65536.0 );
                           IF ( ok ) THEN
                               CardinalValue := CARDINAL(TRUNC(ABS(Data.Real)));
                           ELSE
                               ok := FALSE;
                           END;

     |  IntegerType       :
                           ok := Data.Integer > 0;
                           IF ( ok ) THEN
                              CardinalValue := CARDINAL(Data.Integer);
                           END;

     |  CardinalType      :
                           CardinalValue := Data.Cardinal;
     ELSE
        ok := FALSE;
     END;

     RETURN ( ok );

END RetrieveCardinal;


PROCEDURE  RetrieveInteger ( VAR Data            : AnIntDataRecord;
                                Type             : CARDINAL;
                            VAR IntegerValue     : INTEGER ) : BOOLEAN;
VAR
    Temp                    : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
    RealValue               : REAL;
BEGIN
    IntegerValue := 0;
    ok := TRUE;

    CASE Type OF
        TextType          :
                           IF ( LengthOf ( Data.LString ) > 0 ) THEN
                              LStringToTString ( Data.LString, Temp );
                              StringToInt ( Temp, IntegerValue, ok );
                           ELSE
                              IntegerValue := 0;
                           END;
     |  RealNumberType    :
                           RealValue := Data.Real;
                           ok := (RealValue >= -32768.0) AND
                                 (RealValue <= 32767.0);

                           IF (ok) THEN
                               IF (RealValue >= Zero) THEN
                                   IntegerValue := INTEGER(TRUNC(RealValue));
                               ELSE
                                   IntegerValue := 0 - INTEGER(TRUNC(ABS(RealValue)));
                               END;
                           ELSE
                               IF (RealValue > Zero) THEN
                                   IntegerValue :=  32767; (* MAXINT *)
                               ELSE
                                   IntegerValue := -32768; (* MININT *)
                               END;
                               ok := FALSE;
                           END;
     |  IntegerType       :
                           IntegerValue := Data.Integer;
     |  CardinalType      :
                           IntegerValue := INTEGER(Data.Cardinal);
     ELSE
        ok := FALSE;
     END;

     RETURN ( ok );

END RetrieveInteger;


PROCEDURE  RetrieveString ( VAR Data             : AnIntDataRecord;
                                Type             : CARDINAL;
                            VAR StringValue      : ARRAY OF CHAR );
VAR
    Leading, Trailing : ARRAY [0..25] OF CHAR;
BEGIN
    SetLengthOf ( StringValue, 0 );

    CASE Type OF
        TextType          :
                    Copy( Data.LString, StringValue );
     |  RealNumberType    :
                    RealToLStrings( Data.Real, 2, 25,
                                    Leading, Trailing );
                    ConcatLS ( StringValue, Leading);

                    IF ( Trailing[0] > 0C ) THEN
                        ConcatS( StringValue, "." );
                        ConcatLS ( StringValue, Trailing );
                    END;

     |  IntegerType       :
                    IntToString ( Data.Integer, StringValue, 7);
                    TStringToLString( StringValue, StringValue );
                    TrimFront ( StringValue );
                    TrimRear ( StringValue );

     |  CardinalType      :
                    CtoS (  Data.Cardinal, StringValue );

     |  BooleanType       :                                     (* 22-Jul-89 MWP *)
                    Copy( Data.LString, StringValue );

     |  EnumeratedType    :
                    Upshift( Data.LString );
                    Copy( Data.LString, StringValue );
     ELSE
     END;


END RetrieveString;




  (* In version 4, task and resource names cannot have these charactors:

           \, ^, *, ], or [.

  *)
PROCEDURE AjustName( VAR NewName : ARRAY OF CHAR );
VAR
    Loop : CARDINAL;
    C    : CHAR;
BEGIN
    FOR Loop := 1 TO ORD(NewName[0]) DO
        C := NewName[ Loop ];
        IF ((C = "\") OR
            (C = "^") OR
            (C = "*") OR
            (C = "]") OR
            (C = "["))  THEN
            NewName[ Loop ] := "-";    (* Give 'em a replacement char. *)
        END;
    END;
END AjustName;











(*
    Match WBS - Search the entire task tree looking for a task with the same
                WBS number as the global one.  Context points to the "Found"
                TreeNode.  If NIL, it still has not been found.
*)
PROCEDURE MatchWBS( VAR TaskNode : ATreeNode;
                        Context  : ADDRESS );
VAR
    FoundNode   : POINTER TO ATreeNode;
    LocalWBS    : ARRAY [0..WBSLen] OF CHAR;
    TaskPtr     : ATaskPtr;
BEGIN
    FoundNode := Context;
    IF (FoundNode^ = NIL) THEN  (* Have we already found it? *)
        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        GetCodingField (TaskPtr^, WBSLine, LocalWBS); (* 5/17/89 WKH & RSC *)
        Squeeze( LocalWBS );

        IF (StringsEqual( LocalWBS, GlobalWBS )) THEN
            FoundNode^ := TaskNode;
        END;
        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
    END;
END MatchWBS;




(*
    Find Task With WBS

        Preconditions
                        > WBSToMatch   is the WBS to find.  It is passed as a
                                       VAR only for effeciency, it is not
                                       altered.

        Postconditions
                        > TaskNode     is the found task node.  If NIL, no
                                       matching task was found.  If not NIL,
                                       it is the found task node.
*)
PROCEDURE FindTaskWithWBS( VAR WBSToMatch   : ARRAY OF CHAR;
                           VAR TaskNode     : ATreeNode );
BEGIN

    Copy( WBSToMatch, GlobalWBS );
    Squeeze( GlobalWBS );

    TaskNode := ATreeNode(NIL);

    TaskTree^.Methods^.TraverseTree( TaskTree,
                                     ParentAfterChild,
                                     999,
                                     MatchWBS,
                                     ADR(TaskNode) );
END FindTaskWithWBS;


PROCEDURE SetupTranslation();
CONST
    CModuleNumber    = 24300;
VAR
    i                   : CARDINAL;
    s                   : ARRAY [0..40] OF CHAR;
    s2                  : ARRAY [0..99] OF CHAR;
    ReplaceChar         : CHAR;

BEGIN
    GetMessage (CModuleNumber+1, s);     (* The string of legal characters *)
    ReplaceChar := s[1];
    Remove (s, 1, 1);                   (* Parse out the replace character *)
    i := 1;
    DoDash (s, s2, i);
    SetLengthOf (s2, i-1);
    Fill (CharTable, ReplaceChar, 255);
    FOR i := 1 TO LengthOf(s2) DO
        CharTable[ORD(s2[i])] := s2[i];
    END;
END SetupTranslation;





BEGIN
    SetLengthOf( NilString, 0 );
    SetupTranslation ();
END EditCommon.

