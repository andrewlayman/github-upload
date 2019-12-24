MODULE TLXDB3;

(*
    Modification History:

     8-May-89  MWP  Strip trailinfg spaces from Column names, so they
                    will not be turned into the Replace character.
     9-Aug-89  KKC  Add copyright message.
    23-Aug-89  MWP  Force percentage fields to decimal places.
     6-Sep-89  MWP  Write out true null fields. ( i.e space filled. )
    22-Sep-89  MWP  Call Start and End date export procs directly from
                    here. Circumvent WriteCardinal which was erroneously
                    directing some milestone tasks to the wrong date
                    proc.
    30-Mar-90  RSC  Made Timeu to Timei/TimeForm conversions.
*)

FROM BigTimeU               IMPORT
    (* PROC *)                  BigTimeToTime;

FROM dBaseOut               IMPORT
    (* TYPE *)                  AColumnType,
    (* PROC *)                  DefineFile, DefineColumn, DefineDefault,
                                StartFile, EndFile, StartRecord,
                                WriteField, WriteCardinal, WriteReal,
                                WriteBoolean, WriteBigTime, WriteNullField,
                                WriteOutDateRecord;


FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Foreign                IMPORT
    (* TYPE *)                  ACharacterConversionTable,
    (* PROC *)                  DoDash, ConvertString;

FROM IntFileIO              IMPORT
    (* CONST *)                 TextType, RealNumberType, IntegerType,
                                CardinalType, BooleanType,
                                BigStartTimeType, BigEndTimeType,
                                StartDateType, EndDateType,
                                EnumeratedType,
    (* TYPE *)                  ADataType,
                                AnIntDataRecord, AFormat,
                                AFormatType;

FROM LStrings               IMPORT
    (* PROC *)                  SetLengthOf, Fill, LengthOf, Remove,
                                TrimRear;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM NormalExport           IMPORT
    (* TYPE *)                  AnOpenFileProc, ACloseFileProc,
                                ABeginRecordProc, AnEndRecordProc,
                                ADefineColumnProc, AWriteDataProc,
                                AWriteNullProc,
    (* VAR *)                   ErrorFlag,
    (* PROC *)                  ExportNormalData;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate;



CONST
    Zero            = 0.0;
    ModuleNumber    = 24300;

VAR
    StartedFlag         : BOOLEAN;
    CharTable           : ACharacterConversionTable;


PROCEDURE OpenFile( VAR Name    : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
    DefineFile (0, Name);
    RETURN TRUE;
END OpenFile;



PROCEDURE CloseFile();
BEGIN
    IF (NOT StartedFlag) THEN
        StartedFlag := TRUE;
        IF (NOT StartFile()) THEN
            ErrorFlag := TRUE;
            RETURN;
        END;
    END;
    EndFile();
END CloseFile;



PROCEDURE BeginRecord();
BEGIN
    IF (NOT StartedFlag) THEN
        StartedFlag := TRUE;
        IF (NOT StartFile()) THEN
            ErrorFlag := TRUE;
            RETURN;
        END;
    END;
    IF (NOT StartRecord()) THEN
        ErrorFlag := TRUE;
    END;
END BeginRecord;



PROCEDURE EndRecord();
BEGIN
END EndRecord;



PROCEDURE NewType (InType   : CARDINAL;
                   Format   : AFormat   ) : AColumnType;
BEGIN
    CASE InType OF
        TextType, EnumeratedType :
            RETURN Alpha;
    |   BooleanType :
            RETURN Boolean;
    |   RealNumberType:
            CASE Format.FormatType OF
                FNumeric, FPercent :
                    RETURN Real;
            |   FCurrency :
                    RETURN Currency;
            ELSE
                    FatalError();
            END;
    |   IntegerType, CardinalType :
            RETURN Cardinal;
    |   BigStartTimeType, StartDateType :
            RETURN StartDate;
    |   BigEndTimeType, EndDateType :
            RETURN EndDate;
    ELSE
            FatalError();
    END;
END NewType;




PROCEDURE DefineDBColumn( VAR Name    : ARRAY OF CHAR;
                              Type    : ADataType;
                              Format  : AFormat;
                              Width   : CARDINAL      );
CONST
    RealWidth           = 12;

BEGIN

    TrimRear ( Name );
    ConvertString (Name, CharTable);

    IF (NewType(Type,Format) = Alpha) THEN
        DefineColumn (Name, Width, 0, Alpha);
    ELSIF (Type = RealNumberType) AND (Format.FormatType = FNumeric) THEN
        DefineColumn (Name, RealWidth, ORD(Format.DecimalDigits), Real);
    ELSIF (Type = RealNumberType) AND (Format.FormatType = FPercent) THEN
        DefineColumn (Name, RealWidth, 4, Real);                  (* 21-Aug-89 MWP *)
    ELSE
        DefineDefault (Name, NewType(Type,Format));
    END;

END DefineDBColumn;





PROCEDURE WriteData(     Type       : ADataType;
                     VAR Data       : AnIntDataRecord;
                         Format     : AFormat         );
VAR
    Date            : ADate;

BEGIN
    CASE NewType(Type,Format) OF
        Alpha :
            WriteField (Data.LString);
    |   Cardinal, Numeric, Duration :
            WriteCardinal (Data.Cardinal);
    |   StartDate :
            IF (Type = BigStartTimeType) THEN
                WriteBigTime (Data.BigTime);
            ELSE
                WriteOutDateRecord ( Data.Date, StartDate );            (* 22-Sep-89 MWP *)
            END;
    |   EndDate :
            IF (Type = BigEndTimeType) THEN
                WriteBigTime (Data.BigTime);
            ELSE
                WriteOutDateRecord ( Data.Date, EndDate );            (* 22-Sep-89 MWP *)
            END;
    |   Boolean :
            WriteBoolean (Data.Boolean);
    |   Currency, Real :
            WriteReal (Data.Real);
    ELSE
        FatalError();
    END;
END WriteData;



PROCEDURE WriteNull(     Type       : ADataType;
                         Format     : AFormat         );
BEGIN
    WriteNullField ();                                            (* 6-Sep-89 MWP *)

END WriteNull;




PROCEDURE SetupTranslation();
VAR
    i                   : CARDINAL;
    s                   : ARRAY [0..40] OF CHAR;
    s2                  : ARRAY [0..99] OF CHAR;
    ReplaceChar         : CHAR;
    Copyright           : ARRAY[0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    GetMessage (ModuleNumber+1, s);     (* The string of legal characters *)
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

    StartedFlag := FALSE;

    SetupTranslation();

    ExportNormalData (OpenFile, CloseFile, BeginRecord, EndRecord,
                      DefineDBColumn, WriteData, WriteNull);

END TLXDB3.
