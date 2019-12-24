IMPLEMENTATION MODULE IntFileIO;

(*
    This module provides definitions of, as well as procedures for reading
    and writing of, the elements of an intermediate file used by reports
    and exporters to spreadsheet products.

    Modification History:

    21-Mar-89  RSC  Added common handling of translations between Captions
                    modules and Intermediate File procedures.

    20-May-89  RSC  Accomidated new WorkHours module.
    31-May-89  KKC  Copy StringValue, DataRecord.LString for BOOLEAN type in
                    ConvertCaptionsToIntermediate
    14-Jun-89  MWP  Added field to IntDataRecord to discern the contents of
                    the record type.
    21-Jun-89  KKC  Set StringValue, DataRecord.LString for BOOLEAN type in
                    ConvertCaptionsToIntermediate.
    17-Sep-89  MWP  Place Milestone End Data types in Date field of int
                    record, not in Cardinal field. All milestone data types
                    are changed to be of type IsStartDate, so all clients
                    will expect the value to be in the Date field.
    27-Nov-89  EGK  Have ReadIntData check the status of the intermediate
                    file before attempting to interpret what was read.  Among
                    other things, this solves the problem of intermediate-
                    file reports producing internal errors if the critical
                    error flag is set.
    30-Mar-90  RSC  Made Timeu to Timei/TimeForm conversions.
    15-Oct-90  PFG  Added handling for IsBigStart and IsBigEnd to 
                    ConvertCaptionsToIntermediate.

    22-Jan-91  RSC  Import LongDurationToString from LongDuration rather
                    than from TimeFormat.
     6-Apr-92 TGS   Interface to LongDurationToString was changed to return
                    position of last numeric character.
*)

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnDataRecord,
    (* PROC *)                  GetCurrencyScale;

FROM Dialog                 IMPORT
    (* PROCS *)                 FatalError;

FROM ExportLinkage          IMPORT
    (* VAR *)                   InterFile;

FROM FileAux                IMPORT
    (* PROC *)                  CheckIO;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response;

FROM LStrings               IMPORT
    (* PROC *)                  Copy;

FROM MagicNum               IMPORT
    (* CONST *)
                                IsStringValue,
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

FROM   MsgFile              IMPORT
    (* PROCS *)                 GetMessage;

FROM RecordIO               IMPORT
    (* PROCS *)                 WriteRecord,
                                ReadRecordPreface, ReadRecordBody;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADR, ADDRESS, TSIZE, BYTE;

FROM LongDuration           IMPORT
    (* PROCS *)                 LongDurationToString;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate;

FROM WorkHours               IMPORT
    (* PROC *)                  WorkHoursToRealTime;



CONST
    ModuleNumber = 7400;          (* For GetMessage  *)




    (* Updated by EGK sometime in May. *)


PROCEDURE WriteIntData (    Type       : CARDINAL;
                        VAR DataRecord : AnIntDataRecord );
VAR
    Length                   : CARDINAL;

    Data                     : ARRAY [1..512] OF CHAR;

    PROCEDURE AddIn( A : ADDRESS; Len : CARDINAL );
    VAR
       i : CARDINAL;
       P : POINTER TO ARRAY [1..255] OF CHAR;
    BEGIN
        P := A;
        i := 0;
        WHILE (Length < HIGH( Data )) AND (i < Len) DO
            INC( Length );
            INC( i );
            Data[ Length ] := P^[ i ];
        END;
    END AddIn;

BEGIN
    Length := 0;

    WITH DataRecord DO
        AddIn( ADR(Font), TSIZE(AFont) );
        CASE Type OF
            TextType       : AddIn( ADR(LString[1]), ORD(LString[0]) );
          | RealNumberType : AddIn( ADR(Real    ),   TSIZE(REAL    ) );
          | IntegerType    : AddIn( ADR(Integer ),   TSIZE(INTEGER ) );
          | CardinalType   : AddIn( ADR(Cardinal),   TSIZE(CARDINAL) );
          | BooleanType    : AddIn( ADR(Boolean ),   TSIZE(BOOLEAN ) );
                             AddIn( ADR(LString[1]), ORD(LString[0]) );
          | BigStartTimeType,
            BigEndTimeType      : AddIn( ADR(Cardinal),   TSIZE(CARDINAL) );
                                  AddIn( ADR(BigTime ),   TSIZE(ABigTime) );
          | StartDateType,
            EndDateType         : AddIn( ADR(Cardinal),   TSIZE(CARDINAL) );
                                  AddIn( ADR(Date    ),   TSIZE(ADate   ) );
          | EnumeratedType      : AddIn( ADR(Cardinal),   TSIZE(CARDINAL) );
                                  AddIn( ADR(LString[1]), ORD(LString[0]) );
          | SkipRecordType,
            RepeatRecordType    :   (* No data, but allow the font *)
        ELSE
            FatalError();
        END;
    END;
    WriteRecord( InterFile, Type, ADR( Data ), Length );

END WriteIntData;









 (* Read data from the interpass file.

        Preconditions  - Interpass file open and proper subfile started.
        Postconditions - Type  is the data type (see constants in def)
                         DataRecord is the data.
 *)
PROCEDURE ReadIntData  (VAR Type       : CARDINAL;
                        VAR DataRecord : AnIntDataRecord );
VAR
    j,
    Length,
    Position                 : CARDINAL;

    Data                     : ARRAY [1..512] OF CHAR;

    PROCEDURE GetFrom( A : ADDRESS; Len : CARDINAL );
    VAR
       i : CARDINAL;
       P : POINTER TO ARRAY [1..255] OF CHAR;
    BEGIN
        P := A;
        i := 0;
        WHILE (Position < Length) AND (i < Len) DO
            INC( Position );
            INC( i );
            P^[ i ] := Data[ Position ];
        END;
    END GetFrom;

BEGIN
    Position := 0;

    ReadRecordPreface( InterFile, Type, Length );
    ReadRecordBody   ( InterFile, Length, ADR( Data ), HIGH( Data ) );
    IF (CheckIO(InterFile) <> done) THEN
        Type := 0FFH;                       (* 11/27/89 EGK *)
    END;

    WITH DataRecord DO
        GetFrom( ADR(Font), TSIZE(AFont) );
        CASE Type OF
            TextType       : j := (Length - 1);
                             GetFrom( ADR(LString[1]), j);
                             LString[0] := CHR(j);
                             IntDataField := ASetOfIntDataFields{LStringUsed};

          | RealNumberType : GetFrom( ADR(Real    ),   TSIZE(REAL    ) );
                             IntDataField := ASetOfIntDataFields{RealUsed};

          | IntegerType    : GetFrom( ADR(Integer ),   TSIZE(INTEGER ) );
                             IntDataField := ASetOfIntDataFields{IntegerUsed};
          | CardinalType   : GetFrom( ADR(Cardinal),   TSIZE(CARDINAL) );
                             IntDataField := ASetOfIntDataFields{CardinalUsed};
          | BooleanType    : GetFrom( ADR(Boolean ),   TSIZE(BOOLEAN ) );
                             j := (Length - 1) - TSIZE(BOOLEAN);
                             GetFrom( ADR(LString[1]),  j );
                             LString[0] := CHR(j);
                             IntDataField := ASetOfIntDataFields{BooleanUsed};
          | BigStartTimeType,
            BigEndTimeType      : GetFrom( ADR(Cardinal),   TSIZE(CARDINAL) );
                                  GetFrom( ADR(BigTime ),   TSIZE(ABigTime) );
                                  IntDataField := ASetOfIntDataFields{BigTimeUsed};
          | StartDateType,
            EndDateType         : GetFrom( ADR(Cardinal),   TSIZE(CARDINAL) );
                                  GetFrom( ADR(Date    ),   TSIZE(ADate   ) );
                                  IntDataField := ASetOfIntDataFields{DateUsed};

          | EnumeratedType : GetFrom( ADR(Cardinal),   TSIZE(CARDINAL) );
                             j := (Length - 1) - TSIZE(CARDINAL);
                             GetFrom( ADR(LString[1]),  j );
                             LString[0] := CHR(j);
                             IntDataField := ASetOfIntDataFields{EnumUsed};
          | SkipRecordType,
            RepeatRecordType    : (* Allow these, but no data comes in *)

          | 0FFH :  (* End of file! *)
        ELSE
            FatalError();
        END;
    END;

END ReadIntData;







(*  Export Data Type

    Given a data type from Captions (A GetxxxxInfo procedure), return the
    appropriate data type for the intermediate file record.

*)
PROCEDURE ExportDataType(    DataType       : CARDINAL): CARDINAL;
BEGIN

    CASE DataType OF
        IsDuration,
        IsEffort,
        IsSlack,
        IsRealValue,
        IsCurrency :
                DataType := RealNumberType;

    |   IsIntValue :
                DataType := IntegerType;

    |   IsEnumValue :
                DataType := EnumeratedType;

    |   IsCardValue :
                DataType := CardinalType;

    |   IsBigStart  :
                DataType := BigStartTimeType;

    |   IsBigEnd  :
                DataType := BigEndTimeType;

    |   IsBoolValue :
                DataType := BooleanType;

    |   IsStartDate,
        IsMilestoneEnd :
                DataType := StartDateType;

    |   IsEndDate :
                DataType := EndDateType;

    |   IsDurationUnits,
        IsEffortUnits,
        IsTruncatedString,
        IsStringValue :
                DataType := TextType;
    ELSE
        FatalError();   (* New type added? *)
    END;

    RETURN DataType;

END ExportDataType;





(* Convert Captions To Intermediate

    Converts a Captions data record into an intermediate file data record.

    Preconditions:

        Value       is a data record returned from a Captions routine.
        ColumnWidth is the width of a returned string, used in some real
                       number formatting.

    Postconditions:

        LDataType   is the intermediate file data type.
        DataRecord  is the filled-in intermediate file data record.
*)
PROCEDURE ConvertCaptionsToIntermediate( VAR Value       : AColumnDataRecord;
                                             ColumnWidth : CARDINAL;
                                         VAR LDataType   : CARDINAL;
                                         VAR DataRecord  : AnIntDataRecord
                                        );
VAR
    i   : CARDINAL;
BEGIN
    WITH Value DO
        LDataType := ExportDataType(DataType);
        CASE DataType OF
            IsStringValue, IsTruncatedString, IsEnumValue :
                Copy(StringValue, DataRecord.LString);

        |   IsRealValue :
                DataRecord.Real := RealValue;

        |   IsIntValue :
                DataRecord.Integer := IntegerValue;

        |   IsCardValue :
                DataRecord.Cardinal := CardinalValue;

        |   IsStartDate, IsEndDate :
                DataRecord.Date := DateValue;

        |   IsBigStart, IsBigEnd :
                DataRecord.BigTime := BigTimeValue;      

        |   IsBoolValue :
                DataRecord.Boolean := BooleanValue;
                IF ( DataRecord.Boolean ) THEN
                    GetMessage( ModuleNumber + 1, DataRecord.LString); (* "T" *)
                ELSE
                    GetMessage( ModuleNumber + 2, DataRecord.LString); (* "F" *)
                END;

        |   IsDuration, IsEffort, IsSlack :
                DataRecord.Real
                           := WorkHoursToRealTime(RealValue,TimeUnitValue);

        |   IsDurationUnits, IsEffortUnits :
                LongDurationToString(RealValue, TimeUnitValue,
                                     1, 1, ColumnWidth,
                                     StringValue, i );
                Copy(StringValue, DataRecord.LString);

        |   IsCurrency :
                IF (GetCurrencyScale() <> 1.0) THEN           (* 22-Dec-88 LAA *)
                    RealValue := RealValue / GetCurrencyScale();
                END;
                DataRecord.Real := RealValue;

        |   IsMilestoneEnd :
(***
                DataRecord.Cardinal := DateValue;
***)
                DataRecord.Date := DateValue;                     (* 17-Sep-89 MWP *)
        ELSE
            FatalError();    (* New type added? *)
        END;
    END;

END ConvertCaptionsToIntermediate;




END IntFileIO.

